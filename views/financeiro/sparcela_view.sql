-- =====================================================================
-- export.sparcela  —  Parcelas dos contratos dos alunos
-- =====================================================================
-- Layout TOTVS RM (22 campos):
--
--  Fonte: gennera_stg.servicos_historico (parcelas cobradas no Gennera)
--
--  Regras:
--   - Uma linha por parcela cobrada (12 por ano para mensalidades,
--     1 por ano para rematricula/anuidade, N para extras)
--   - SERVICO = item do Gennera (match direto com SSERVICO.NOME no TOTVS)
--   - CODCONTRATO ligado via (aluno+ano+tipo):
--       1aMENS/ANUID             → contrato Rematricula
--       MENS regular             → contrato Mensalidade
--       ALIM/MAT/MDIDAT          → contrato Servicos (primario, por data)
--       Outros items (OUTROS...) → contrato Servicos adicional (2o por data)
--   - VALOR   = valor bruto
--   - DESCONTO= valor dos descontos (V = valor absoluto)
--   - CODCFO  = responsavel financeiro via CPF
--
--  Mapeamento aluno: servicos_historico.aluno (nome)
--                    -> person_fisica.name
--                    -> enrollment -> code_unif (RA)
-- =====================================================================

DROP VIEW IF EXISTS export.sparcela CASCADE;

CREATE OR REPLACE VIEW export.sparcela AS
WITH
-- 1. Dados do aluno (1 linha por aluno+ano)
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
-- 2. Parcelas com parseamento de valor, desconto e data
parcelas_raw AS (
    SELECT
        sh.calendario_academico,
        UPPER(TRIM(sh.aluno)) AS aluno_key,
        sh.item,
        sh.fatura_ano,
        COALESCE(NULLIF(sh.fatura_mes,'')::int, 1) AS parcela,
        -- parse '$4.677,00' -> 4677.00
        NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(sh.valor_bruto,''), '$', ''),
                               '.', ''), ',', '.'), '')::numeric AS valor,
        -- parse valor_descontos '$935,40' -> 935.40
        COALESCE(
            NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(sh.valor_descontos,''), '$', ''),
                                   '.', ''), ',', '.'), '')::numeric,
            0
        ) AS desconto,
        -- parse 'DD/MM/AAAA' -> DATE
        CASE
            WHEN sh.data_vencimento ~ '^\d{2}/\d{2}/\d{4}$'
                THEN TO_DATE(sh.data_vencimento, 'DD/MM/YYYY')
            ELSE NULL
        END AS dt_vencimento,
        REGEXP_REPLACE(COALESCE(sh.cpf_responsavel_financeiro,''), '\D', '', 'g') AS cpf_resp,
        sh.contrato AS hash_contrato,
        sh.status AS status_gennera,
        -- tipo do item para ligar com SCONTRATO
        CASE
            -- 1aMens / 1oPARC -> REMATR (contrato de Rematricula ou Matricula)
            WHEN sh.item ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND sh.item !~* '^\s*(MENS|PARC)'         THEN 'REMATR'
            -- ANUIDADE -> MENS (anuidade e mensalidade paga em uma vez, vai pro contrato Mensalidade)
            WHEN sh.item ILIKE '%ANUID%'                    THEN 'MENS'
            -- MENS regular -> MENS
            WHEN sh.item ILIKE '%MENS%'                     THEN 'MENS'
            -- items padrao de servicos (ALIM, MAT DIDAT, MDIDAT, MD)
            WHEN sh.item ILIKE '%ALIM%'
              OR sh.item ILIKE '%MAT%DIDAT%'
              OR sh.item ILIKE '%MDIDAT%'
              OR sh.item ILIKE '%MDIAT%'
              OR sh.item ~* '^\s*MD\s'
              OR sh.item ILIKE '%MATERIAIS%'               THEN 'SERVIC'
            -- items extras (OUTROS RECEBIMENTOS, passeios, eventos)
            ELSE 'SERVIC_EXTRA'
        END AS tipo
    FROM gennera_stg.servicos_historico sh
    WHERE sh.calendario_academico IS NOT NULL
      AND sh.aluno IS NOT NULL
      AND sh.item IS NOT NULL
      AND COALESCE(sh.status,'') NOT IN ('cancelado')  -- exclui cancelados
),
-- 3. Contratos de SERVICOS rankeados por data
-- (tudo que nao for Mensalidade nem Rematricula/Anuidade/Matricula entra aqui)
-- (inclui "Servicos 2023", "Variavel", "Toca da Raposa", "English Camp", details vazio, etc)
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
      AND COALESCE(ec.details,'') NOT ILIKE '%atr%cula%'  -- exclui Matricula tambem (primeira parcela)
    GROUP BY scu.code_unif, e.academic_calendar, c.id_contract, c.date
),
-- 4a. Contratos MENS (mensalidade regular, nao 1a)
c_mens AS (
    SELECT DISTINCT ON (scu.code_unif, e.academic_calendar)
        scu.code_unif AS ra,
        e.academic_calendar,
        c.id_contract
    FROM gennera_stg.enrollment           e
    JOIN gennera_stg.student_code_unico   scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract  ec  ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract             c   ON c.id_contract    = ec.id_contract
    WHERE ec.details ILIKE '%mensalidad%'
      AND ec.details !~* '1[^[:space:]]{0,3}'
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
-- 4b. Contratos REMATR (rematricula, matricula de aluno novo)
-- "Rematricula 2023" para alunos antigos / "Matricula 2023" para alunos novos
c_rematr AS (
    SELECT DISTINCT ON (scu.code_unif, e.academic_calendar)
        scu.code_unif AS ra,
        e.academic_calendar,
        c.id_contract
    FROM gennera_stg.enrollment           e
    JOIN gennera_stg.student_code_unico   scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract  ec  ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract             c   ON c.id_contract    = ec.id_contract
    WHERE ec.details ILIKE '%rematr%'
       OR ec.details ILIKE '%matr%cula%'  -- pega "Matricula 2023" tambem
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
-- 4c. Consolida tipos num CTE unificado
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
-- 5. SELECT final no layout SPARCELA TOTVS
SELECT
    1                                                    AS "CODCOLIGADA",
    a."CODCURSO"::character varying(10)                  AS "CODCURSO",
    a."CODHABILITACAO"::character varying(10)            AS "CODHABILITACAO",
    a."CODGRADE"::character varying(10)                  AS "CODGRADE",
    a."TURNO"::character varying(15)                     AS "TURNO",
    a.codfilial                                          AS "CODFILIAL",
    1                                                    AS "CODTIPOCURSO",
    a.ra::character varying(20)                          AS "RA",
    a.academic_calendar::character varying(10)           AS "CODPERLET",
    ct.id_contract::character varying(20)                AS "CODCONTRATO",
    p.item::character varying(60)                        AS "SERVICO",
    p.parcela                                            AS "PARCELA",
    1                                                    AS "COTA",
    -- VALOR/DESCONTO em formato BR puro ("934,00") evita interpretacao
    -- errada do cliente CSV que reaproveita "." como separador de milhar
    REPLACE(TO_CHAR(p.valor, 'FM9999999990.00'), '.', ',')
                                                          AS "VALOR",
    TO_CHAR(p.dt_vencimento, 'YYYY-MM-DD')::character varying(10) AS "DTVENCIMENTO",
    REPLACE(TO_CHAR(p.desconto, 'FM9999999990.00'), '.', ',')
                                                          AS "DESCONTO",
    'V'::character varying(1)                            AS "TIPODESC",
    'P'::character varying(1)                            AS "TIPOPARCELA",
    'N'::character varying(1)                            AS "VALORAUTOMATICO",
    TO_CHAR(
      MAKE_DATE(a.academic_calendar::int,
                COALESCE(NULLIF(p.parcela,0), 1),
                1),
      'YYYY-MM-DD'
    )::character varying(10)                             AS "DTCOMPETENCIA",
    1                                                    AS "CODCOLCFO",
    LPAD(f."CODCFO", 6, '0')::character varying(25)      AS "CODCFO"
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
  AND p.dt_vencimento IS NOT NULL;
