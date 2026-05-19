-- =====================================================================
-- export_v2.sbolsaaluno — Bolsas/descontos por aluno (v2 SSERVICO genérico)
-- =====================================================================
-- Mesma lógica de sbolsaaluno_view.sql MAS com SERVICO mapeado para
-- SSERVICO genérico (4 fixos + variáveis).
-- =====================================================================

DROP VIEW IF EXISTS export_v2.sbolsaaluno CASCADE;

CREATE OR REPLACE VIEW export_v2.sbolsaaluno AS
WITH
alunos AS (
    SELECT
        UPPER(TRIM(pf.name)) AS name_key,
        e.id_enrollment,
        e.id_person,
        e.academic_calendar,
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
bolsas_raw AS (
    SELECT
        bd.calendario_academico,
        UPPER(TRIM(bd.aluno)) AS aluno_key,
        bd.item_descricao AS servico_original,
        -- Mapeamento item → SSERVICO.NOME genérico
        CASE
            WHEN bd.item_descricao ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND bd.item_descricao !~* '^\s*(MENS|PARC)' THEN '1ª mensalidade'
            WHEN bd.item_descricao ILIKE '%ANUID%'            THEN 'Mensalidade'
            WHEN bd.item_descricao ILIKE '%MENS%'             THEN 'Mensalidade'
            WHEN bd.item_descricao ILIKE '%ALIM%'             THEN 'Alimentação'
            WHEN bd.item_descricao ILIKE '%MAT%DIDAT%'
              OR bd.item_descricao ILIKE '%MDIDAT%'
              OR bd.item_descricao ILIKE '%MDIAT%'
              OR bd.item_descricao ~* '^\s*MD\s'
              OR bd.item_descricao ILIKE '%MATERIAIS%'        THEN 'Material Didático'
            ELSE TRIM(bd.item_descricao)
        END AS servico_nome,
        -- normalizacao do nome da bolsa (igual export.sbolsa)
        CASE
            WHEN bd.desconto_descricao ILIKE 'desconto comercial %'
                THEN 'DESCONTO COMERCIAL VARIAVEL'
            ELSE UPPER(TRIM(bd.desconto_descricao))
        END AS nome_bolsa,
        bd.desconto_forma_calculo AS forma,
        COALESCE(NULLIF(TRIM(bd.fatura_mes), '')::int, 1) AS parcela,
        NULLIF(TRIM(bd.desconto_percentual), '')::numeric AS percentual,
        NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(bd.valor_aplicado,''), '$',''),
                               '.', ''), ',', '.'), '')::numeric AS valor_aplicado,
        bd.categoria_desconto,
        CASE
            WHEN bd.item_descricao ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND bd.item_descricao !~* '^\s*(MENS|PARC)' THEN 'REMATR'
            WHEN bd.item_descricao ILIKE '%ANUID%'            THEN 'MENS'
            WHEN bd.item_descricao ILIKE '%MENS%'             THEN 'MENS'
            WHEN bd.item_descricao ILIKE '%ALIM%'
              OR bd.item_descricao ILIKE '%MAT%DIDAT%'
              OR bd.item_descricao ILIKE '%MDIDAT%'
              OR bd.item_descricao ILIKE '%MDIAT%'
              OR bd.item_descricao ~* '^\s*MD\s'
              OR bd.item_descricao ILIKE '%MATERIAIS%'        THEN 'SERVIC'
            ELSE 'SERVIC_EXTRA'
        END AS tipo
    FROM gennera_stg.bolsas_descontos bd
    WHERE bd.calendario_academico IS NOT NULL
      AND bd.aluno IS NOT NULL
      AND bd.item_descricao IS NOT NULL
      AND bd.desconto_descricao IS NOT NULL
      AND COALESCE(bd.situacao, '') = 'aplicado'
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
),
bolsas_validas AS (
    SELECT b.* FROM bolsas_raw b
    WHERE EXISTS (SELECT 1 FROM export_v2.sservico s WHERE s."NOME" = b.servico_nome)
      AND EXISTS (SELECT 1 FROM export.sbolsa  sb WHERE sb."NOME" = b.nome_bolsa)
),
bolsas_agg AS (
    SELECT
        a.codfilial,
        a."CODCURSO", a."CODHABILITACAO", a."CODGRADE", a."TURNO",
        a.ra, a.academic_calendar, ct.id_contract,
        b.servico_nome, b.nome_bolsa, b.forma,
        MIN(b.parcela)        AS parcela_inicial,
        MAX(b.parcela)        AS parcela_final,
        MIN(b.percentual)     AS percentual_val,
        MIN(b.valor_aplicado) AS valor_val,
        MIN(b.categoria_desconto) AS categoria
    FROM bolsas_validas b
    JOIN alunos a
      ON a.name_key = b.aluno_key
     AND a.academic_calendar = b.calendario_academico
    JOIN contrato_por_tipo ct
      ON ct.ra                = a.ra
     AND ct.academic_calendar = b.calendario_academico
     AND ct.tipo              = b.tipo
    GROUP BY a.codfilial, a."CODCURSO", a."CODHABILITACAO", a."CODGRADE",
             a."TURNO", a.ra, a.academic_calendar, ct.id_contract,
             b.servico_nome, b.nome_bolsa, b.forma
)
SELECT
    1                                                    AS "CODCOLIGADA",
    "CODCURSO"::varchar(10)                              AS "CODCURSO",
    "CODHABILITACAO"::varchar(10)                        AS "CODHABILITACAO",
    "CODGRADE"::varchar(10)                              AS "CODGRADE",
    "TURNO"::varchar(15)                                 AS "TURNO",
    codfilial                                            AS "CODFILIAL",
    1                                                    AS "CODTIPOCURSO",
    ra::varchar(20)                                      AS "RA",
    academic_calendar::varchar(10)                       AS "CODPERLET",
    id_contract::varchar(20)                             AS "CODCONTRATO",
    LEFT(nome_bolsa, 60)::varchar(60)                    AS "NOMEBOLSA",
    LEFT(servico_nome, 60)::varchar(60)                  AS "SERVICO",
    NULL::date                                           AS "DTINICIO",
    NULL::date                                           AS "DTFIM",
    REPLACE(
        TO_CHAR(
            CASE
                WHEN forma = 'relativo' THEN COALESCE(percentual_val, 0)
                ELSE COALESCE(valor_val, 0)
            END,
            'FM9999999990.0000'
        ),
        '.', ','
    )::varchar(20)                                       AS "DESCONTO",
    CASE WHEN forma = 'relativo' THEN 'P' ELSE 'V' END::varchar(1) AS "TIPODESC",
    LEFT(COALESCE(categoria, ''), 200)                   AS "OBS",
    parcela_inicial                                      AS "PARCELAINICIAL",
    parcela_final                                        AS "PARCELAFINAL",
    'mestre'::varchar(20)                                AS "CODUSUARIO",
    1                                                    AS "ORDEMBOLSA",
    NULL::date                                           AS "DATACONCESSAO",
    NULL::date                                           AS "DATAAUTORIZACAO",
    NULL::numeric(10,4)                                  AS "TETOVALOR",
    'S'::varchar(1)                                      AS "ATIVA",
    NULL::date                                           AS "DATACANCELAMENTO",
    NULL::varchar(20)                                    AS "CODUSUARIOCANCEL",
    NULL::varchar(60)                                    AS "MOTIVOCANCELAMENTO"
FROM bolsas_agg;
