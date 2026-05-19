-- =====================================================================
-- export_v2.sparcela — Parcelas reais cobradas (v2 com SSERVICO genérico)
-- =====================================================================
-- Igual ao sparcela_view.sql original MAS com SERVICO mapeado para
-- SSERVICO genérico (4 fixos + variáveis), conforme nova estrutura.
--
-- Mapeamento item → SSERVICO.NOME:
--   "1ªMENS" / "1º MENS" / "1aMENS" / "1oPARC" / Matrícula → '1ª mensalidade'
--   "MENS" / "MENSALIDADE" / "ANUIDADE"                    → 'Mensalidade'
--   "ALIM" / "ALIMENTAÇÃO"                                 → 'Alimentação'
--   "MAT DIDAT" / "MATERIAIS" / "MD" / "MAT ARTES"          → 'Material Didático'
--   resto                                                   → description literal (SSERVICO variável)
--
-- CODCFO com LPAD 6 dígitos (compatível com FCFO já importada no TOTVS).
-- =====================================================================

DROP VIEW IF EXISTS export_v2.sparcela CASCADE;

CREATE OR REPLACE VIEW export_v2.sparcela AS
WITH
alunos AS (
    SELECT
        UPPER(TRIM(pf.name)) AS name_key,
        e.id_enrollment,
        e.id_person,
        e.academic_calendar,
        e.class_name,
        scu.code_unif AS ra,
        CASE inst.code WHEN 'un1' THEN 1 WHEN 'un2' THEN 2 END AS codfilial,
        st."CODCURSO",
        st."CODHABILITACAO",
        st."CODGRADE",
        st."TURNO"
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.institution        inst ON inst.id_institution = e.id_institution
    JOIN gennera_stg.person_fisica      pf   ON pf.id_person         = e.id_person
    JOIN gennera_stg.student_code_unico scu  ON scu.id_person         = e.id_person
    JOIN export.sturma                   st  ON st."CODTURMA"         = e.class_name
                                             AND st."CODPERLET"        = e.academic_calendar
    WHERE inst.code IN ('un1','un2')
      AND scu.code_unif IS NOT NULL
      AND e.academic_calendar IS NOT NULL
),
parcelas_raw AS (
    SELECT
        sh.calendario_academico,
        UPPER(TRIM(sh.aluno)) AS aluno_key,
        sh.item,
        sh.fatura_ano,
        COALESCE(NULLIF(sh.fatura_mes,'')::int, 1) AS parcela,
        NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(sh.valor_bruto,''), '$', ''),
                               '.', ''), ',', '.'), '')::numeric AS valor,
        COALESCE(
            NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(sh.valor_descontos,''), '$', ''),
                                   '.', ''), ',', '.'), '')::numeric,
            0
        ) AS desconto,
        CASE
            WHEN sh.data_vencimento ~ '^\d{2}/\d{2}/\d{4}$'
                THEN TO_DATE(sh.data_vencimento, 'DD/MM/YYYY')
            ELSE NULL
        END AS dt_vencimento,
        REGEXP_REPLACE(COALESCE(sh.cpf_responsavel_financeiro,''), '\D', '', 'g') AS cpf_resp,
        sh.contrato AS hash_contrato,
        sh.status AS status_gennera,
        -- Mapeamento para SSERVICO.NOME genérico v2 (regex + categoria + literal)
        CASE
            WHEN sh.item ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND sh.item !~* '^\s*(MENS|PARC)'           THEN '1ª mensalidade'
            WHEN sh.item ILIKE '%matr%cula%' AND sh.item !~* 'MENS' THEN '1ª mensalidade'
            WHEN sh.item ILIKE '%ANUID%'                      THEN 'Mensalidade'
            WHEN sh.item ILIKE '%MENS%'                       THEN 'Mensalidade'
            WHEN sh.item ILIKE '%ALIM%'                       THEN 'Alimentação'
            -- Material didático: cobre todas as variações
            WHEN sh.item ILIKE '%MATERIAL%'                   THEN 'Material Didático'
            WHEN sh.item ILIKE '%MATERIAIS%'                  THEN 'Material Didático'
            WHEN sh.item ILIKE '%MAT%DIDAT%'                  THEN 'Material Didático'
            WHEN sh.item ILIKE '%MDIDAT%'                     THEN 'Material Didático'
            WHEN sh.item ILIKE '%MDIAT%'                      THEN 'Material Didático'
            WHEN sh.item ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'    THEN 'Material Didático'
            WHEN sh.item ~* '\mMD\M'                          THEN 'Material Didático'
            ELSE TRIM(sh.item)
        END AS servico_nome,
        -- tipo (mantido p/ ligar SCONTRATO)
        CASE
            WHEN sh.item ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND sh.item !~* '^\s*(MENS|PARC)'           THEN 'REMATR'
            WHEN sh.item ILIKE '%ANUID%'                      THEN 'MENS'
            WHEN sh.item ILIKE '%MENS%'                       THEN 'MENS'
            WHEN sh.item ILIKE '%ALIM%'
              OR sh.item ILIKE '%MAT%DIDAT%'
              OR sh.item ILIKE '%MDIDAT%'
              OR sh.item ILIKE '%MDIAT%'
              OR sh.item ~* '^\s*MD\s'
              OR sh.item ILIKE '%MATERIAIS%'                 THEN 'SERVIC'
            ELSE 'SERVIC_EXTRA'
        END AS tipo
    FROM gennera_stg.servicos_historico sh
    WHERE sh.calendario_academico IS NOT NULL
      AND sh.aluno IS NOT NULL
      AND sh.item IS NOT NULL
      AND COALESCE(sh.status,'') NOT IN ('cancelado')
),
servicos_ranked AS (
    SELECT
        scu.code_unif AS ra,
        e.academic_calendar,
        c.id_contract,
        c.date,
        ROW_NUMBER() OVER (
            PARTITION BY scu.code_unif, e.academic_calendar
            ORDER BY c.date, c.id_contract
        ) AS rank
    FROM gennera_stg.enrollment           e
    JOIN gennera_stg.student_code_unico   scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract  ec  ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract             c   ON c.id_contract    = ec.id_contract
    WHERE COALESCE(ec.details,'') NOT ILIKE '%mensalidad%'
      AND COALESCE(ec.details,'') NOT ILIKE '%rematr%'
      AND COALESCE(ec.details,'') NOT ILIKE '%anuid%'
      AND COALESCE(ec.details,'') NOT ILIKE '%atr%cula%'
    GROUP BY scu.code_unif, e.academic_calendar, c.id_contract, c.date
),
c_mens AS (
    SELECT DISTINCT ON (scu.code_unif, e.academic_calendar)
        scu.code_unif AS ra, e.academic_calendar, c.id_contract
    FROM gennera_stg.enrollment           e
    JOIN gennera_stg.student_code_unico   scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract  ec  ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract             c   ON c.id_contract    = ec.id_contract
    WHERE ec.details ILIKE '%mensalidad%'
      AND ec.details !~* '1[^[:space:]]{0,3}'
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
c_rematr AS (
    SELECT DISTINCT ON (scu.code_unif, e.academic_calendar)
        scu.code_unif AS ra, e.academic_calendar, c.id_contract
    FROM gennera_stg.enrollment           e
    JOIN gennera_stg.student_code_unico   scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract  ec  ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract             c   ON c.id_contract    = ec.id_contract
    WHERE ec.details ILIKE '%rematr%'
       OR ec.details ILIKE '%matr%cula%'
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
contrato_por_tipo AS (
    SELECT ra, academic_calendar, 'MENS'::text AS tipo, id_contract FROM c_mens
    UNION ALL
    SELECT ra, academic_calendar, 'REMATR'::text, id_contract FROM c_rematr
    UNION ALL
    SELECT ra, academic_calendar, 'SERVIC'::text, id_contract
    FROM servicos_ranked WHERE rank = 1
    UNION ALL
    SELECT ra, academic_calendar, 'SERVIC_EXTRA'::text, id_contract
    FROM servicos_ranked WHERE rank = 2
    UNION ALL
    SELECT sr.ra, sr.academic_calendar, 'SERVIC_EXTRA'::text, sr.id_contract
    FROM servicos_ranked sr
    WHERE sr.rank = 1
      AND NOT EXISTS (
          SELECT 1 FROM servicos_ranked sr2
          WHERE sr2.ra = sr.ra
            AND sr2.academic_calendar = sr.academic_calendar
            AND sr2.rank = 2
      )
)
SELECT
    1                                                    AS "CODCOLIGADA",
    a."CODCURSO"::varchar(10)                            AS "CODCURSO",
    a."CODHABILITACAO"::varchar(10)                      AS "CODHABILITACAO",
    a."CODGRADE"::varchar(10)                            AS "CODGRADE",
    a."TURNO"::varchar(15)                               AS "TURNO",
    a.codfilial                                          AS "CODFILIAL",
    1                                                    AS "CODTIPOCURSO",
    a.ra::varchar(20)                                    AS "RA",
    a.academic_calendar::varchar(10)                     AS "CODPERLET",
    ct.id_contract::varchar(20)                          AS "CODCONTRATO",
    LEFT(p.servico_nome, 60)::varchar(60)                AS "SERVICO",
    p.parcela                                            AS "PARCELA",
    1                                                    AS "COTA",
    REPLACE(TO_CHAR(p.valor, 'FM9999999990.00'), '.', ',')
                                                          AS "VALOR",
    TO_CHAR(p.dt_vencimento, 'YYYY-MM-DD')::varchar(10)  AS "DTVENCIMENTO",
    REPLACE(TO_CHAR(p.desconto, 'FM9999999990.00'), '.', ',')
                                                          AS "DESCONTO",
    'V'::varchar(1)                                      AS "TIPODESC",
    'P'::varchar(1)                                      AS "TIPOPARCELA",
    'N'::varchar(1)                                      AS "VALORAUTOMATICO",
    TO_CHAR(
        MAKE_DATE(a.academic_calendar::int,
                  COALESCE(NULLIF(p.parcela,0), 1),
                  1),
        'YYYY-MM-DD'
    )::varchar(10)                                       AS "DTCOMPETENCIA",
    1                                                    AS "CODCOLCFO",
    LPAD(f."CODCFO", 6, '0')::varchar(25)                AS "CODCFO"
FROM parcelas_raw p
JOIN alunos a
  ON a.name_key = p.aluno_key
 AND a.academic_calendar = p.calendario_academico
LEFT JOIN contrato_por_tipo ct
       ON ct.ra                 = a.ra
      AND ct.academic_calendar  = p.calendario_academico
      AND ct.tipo               = p.tipo
LEFT JOIN export.fcfo f
       ON f."CGCCFO" = p.cpf_resp
WHERE p.valor IS NOT NULL
  AND p.dt_vencimento IS NOT NULL
  AND ct.id_contract IS NOT NULL;  -- exclui parcelas sem contrato (TOTVS exige FK)
