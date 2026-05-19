-- =====================================================================
-- export.sbolsaaluno  —  Bolsas/descontos aplicados por aluno+contrato
-- =====================================================================
-- Layout TOTVS RM (28 campos):
--
--  Fonte: gennera_stg.bolsas_descontos (1 linha por desconto x parcela)
--
--  Granularidade no TOTVS:
--    1 linha por (aluno, ano, contrato, servico, desconto)
--    PARCELAINICIAL = MIN(fatura_mes), PARCELAFINAL = MAX(fatura_mes)
--    Validade da bolsa = por parcela (DTINICIO/DTFIM ficam NULL)
--
--  Mapeamento:
--    NOMEBOLSA  -> normalizacao = SBOLSA (DESCONTO COMERCIAL X% -> generico)
--    SERVICO    -> bd.item_descricao (= SSERVICO.NOME)
--    CODCONTRATO-> via tipo do item (mesmo mapping de SPARCELA):
--                   MENS regular     -> contrato Mensalidade
--                   1aMENS/ANUID/MAT -> contrato Rematricula
--                   ALIM/MAT/MDIDAT  -> contrato Servicos primario
--                   Outros           -> contrato Servicos extra
--    DESCONTO   -> percentual (forma=relativo) | valor_aplicado (manual)
--    TIPODESC   -> 'P' | 'V'
--
--  Filtros:
--    - Apenas situacao = 'aplicado'
--    - Apenas itens que batem com SSERVICO.NOME (impede orphan FK)
--    - Apenas alunos com matricula (via mapping aluno->RA)
-- =====================================================================

DROP VIEW IF EXISTS export.sbolsaaluno CASCADE;

CREATE OR REPLACE VIEW export.sbolsaaluno AS
WITH
-- 1. Dados do aluno (mesmo CTE da SPARCELA)
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
-- 2. Bolsas brutas com normalizacao + classificacao do item (= SPARCELA)
bolsas_raw AS (
    SELECT
        bd.calendario_academico,
        UPPER(TRIM(bd.aluno)) AS aluno_key,
        bd.item_descricao AS servico,
        -- normalizacao igual SBOLSA (catalogo)
        CASE
            WHEN bd.desconto_descricao ILIKE 'desconto comercial %'
                THEN 'DESCONTO COMERCIAL VARIAVEL'
            ELSE UPPER(TRIM(bd.desconto_descricao))
        END AS nome_bolsa,
        bd.desconto_forma_calculo AS forma,
        COALESCE(NULLIF(TRIM(bd.fatura_mes), '')::int, 1) AS parcela,
        -- percentual (numero)
        NULLIF(TRIM(bd.desconto_percentual), '')::numeric AS percentual,
        -- valor aplicado parseado: '$200,00' -> 200.00
        NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(bd.valor_aplicado,''), '$',''),
                               '.', ''), ',', '.'), '')::numeric AS valor_aplicado,
        bd.categoria_desconto,
        -- tipo do item (mesma classificacao do SPARCELA)
        CASE
            WHEN bd.item_descricao ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND bd.item_descricao !~* '^\s*(MENS|PARC)'         THEN 'REMATR'
            WHEN bd.item_descricao ILIKE '%ANUID%'                    THEN 'MENS'
            WHEN bd.item_descricao ILIKE '%MENS%'                     THEN 'MENS'
            WHEN bd.item_descricao ILIKE '%ALIM%'
              OR bd.item_descricao ILIKE '%MAT%DIDAT%'
              OR bd.item_descricao ILIKE '%MDIDAT%'
              OR bd.item_descricao ILIKE '%MDIAT%'
              OR bd.item_descricao ~* '^\s*MD\s'
              OR bd.item_descricao ILIKE '%MATERIAIS%'               THEN 'SERVIC'
            ELSE 'SERVIC_EXTRA'
        END AS tipo
    FROM gennera_stg.bolsas_descontos bd
    WHERE bd.calendario_academico IS NOT NULL
      AND bd.aluno IS NOT NULL
      AND bd.item_descricao IS NOT NULL
      AND bd.desconto_descricao IS NOT NULL
      AND COALESCE(bd.situacao, '') = 'aplicado'
),
-- 3. Contratos de SERVICOS rankeados por data (= SPARCELA)
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
-- 4a. Contratos MENS (mensalidade regular)
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
-- 4b. Contratos REMATR (rematricula ou matricula nova)
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
       OR ec.details ILIKE '%matr%cula%'
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
-- 4c. Consolida tipos
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
-- 5. Pre-filtrar bolsas que tem servico+bolsa cadastrados (FK garantida)
bolsas_validas AS (
    SELECT b.*
    FROM bolsas_raw b
    WHERE EXISTS (SELECT 1 FROM export.sservico s WHERE s."NOME" = b.servico)
      AND EXISTS (SELECT 1 FROM export.sbolsa  sb WHERE sb."NOME" = b.nome_bolsa)
),
-- 6. Agregar por (aluno, ano, contrato, servico, desconto, forma)
-- Para a mesma chave, percentual/valor deveriam ser constantes,
-- entao MIN e' suficiente (e barato — sem ordenacao por grupo)
bolsas_agg AS (
    SELECT
        a.codfilial,
        a."CODCURSO",
        a."CODHABILITACAO",
        a."CODGRADE",
        a."TURNO",
        a.ra,
        a.academic_calendar,
        ct.id_contract,
        b.servico,
        b.nome_bolsa,
        b.forma,
        MIN(b.parcela)        AS parcela_inicial,
        MAX(b.parcela)        AS parcela_final,
        MIN(b.percentual)     AS percentual_val,
        MIN(b.valor_aplicado) AS valor_val,
        MIN(b.categoria_desconto) AS categoria,
        COUNT(*)              AS aplicacoes
    FROM bolsas_validas b
    JOIN alunos a
      ON a.name_key = b.aluno_key
     AND a.academic_calendar = b.calendario_academico
    JOIN contrato_por_tipo ct
      ON ct.ra                = a.ra
     AND ct.academic_calendar = b.calendario_academico
     AND ct.tipo              = b.tipo
    GROUP BY
        a.codfilial, a."CODCURSO", a."CODHABILITACAO",
        a."CODGRADE", a."TURNO", a.ra, a.academic_calendar,
        ct.id_contract, b.servico, b.nome_bolsa, b.forma
)
-- 6. SELECT final layout SBOLSAALUNO TOTVS (28 campos)
SELECT
    1                                                    AS "CODCOLIGADA",
    "CODCURSO"::character varying(10)                    AS "CODCURSO",
    "CODHABILITACAO"::character varying(10)              AS "CODHABILITACAO",
    "CODGRADE"::character varying(10)                    AS "CODGRADE",
    "TURNO"::character varying(15)                       AS "TURNO",
    codfilial                                            AS "CODFILIAL",
    1                                                    AS "CODTIPOCURSO",
    ra::character varying(20)                            AS "RA",
    academic_calendar::character varying(10)             AS "CODPERLET",
    id_contract::character varying(20)                   AS "CODCONTRATO",
    LEFT(nome_bolsa, 60)::character varying(60)          AS "NOMEBOLSA",
    LEFT(servico, 60)::character varying(60)             AS "SERVICO",
    NULL::date                                           AS "DTINICIO",
    NULL::date                                           AS "DTFIM",
    -- DESCONTO em formato BR ("20,00" / "934,00") evita CSV interpretar
    -- "." como separador de milhar (mesma regra de SPARCELA)
    REPLACE(
        TO_CHAR(
            CASE
                WHEN forma = 'relativo' THEN COALESCE(percentual_val, 0)
                ELSE COALESCE(valor_val, 0)
            END,
            'FM9999999990.0000'
        ),
        '.', ','
    )::character varying(20)                             AS "DESCONTO",
    CASE WHEN forma = 'relativo' THEN 'P' ELSE 'V' END
        ::character varying(1)                           AS "TIPODESC",
    LEFT(COALESCE(categoria, ''), 200)                   AS "OBS",
    parcela_inicial                                      AS "PARCELAINICIAL",
    parcela_final                                        AS "PARCELAFINAL",
    'mestre'::character varying(20)                      AS "CODUSUARIO",
    1                                                    AS "ORDEMBOLSA",
    NULL::date                                           AS "DATACONCESSAO",
    NULL::date                                           AS "DATAAUTORIZACAO",
    NULL::numeric(10,4)                                  AS "TETOVALOR",
    'S'::character varying(1)                            AS "ATIVA",
    NULL::date                                           AS "DATACANCELAMENTO",
    NULL::character varying(20)                          AS "CODUSUARIOCANCEL",
    NULL::character varying(60)                          AS "MOTIVOCANCELAMENTO"
FROM bolsas_agg;
