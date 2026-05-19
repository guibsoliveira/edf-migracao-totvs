-- =====================================================================
-- export.scontrato_nova  —  Contrato do aluno (1 por contrato Gennera)
-- =====================================================================
-- Layout TOTVS RM:
--
--  Regra: CADA contrato Gennera vira um SCONTRATO.
--  Um aluno pode ter multiplos (1a Mensalidade, Mensalidade, Servicos, etc).
--  Ate 4 contratos por aluno em alguns anos.
--
--  Diferencas para a view antiga (export.scontrato, 11645 rows):
--   - CODPLANOPGTO agora preenchido via SHABMODELOPGTO (antes era NULL)
--   - TIPOCONTRATO refletido no details (Mensalidade=P, Servico=S)
--   - Deduplicacao no enrollment_contract
--
-- Nao substitui export.scontrato original.
-- =====================================================================

DROP VIEW IF EXISTS export.scontrato_nova CASCADE;

CREATE OR REPLACE VIEW export.scontrato_nova AS
WITH
-- 1. Deduplicar enrollment_contract (tem duplicatas naturais)
ec_dedup AS (
    SELECT DISTINCT id_enrollment, id_contract, details
    FROM gennera_stg.enrollment_contract
),
-- 2. Para cada id_contract pegar o details mais representativo
-- (se tem 'Mensalidade' e 'Servicos' para o mesmo id_contract, prioriza Mensalidade)
contratos_dedup AS (
    SELECT DISTINCT ON (ec.id_contract)
        ec.id_enrollment,
        ec.id_contract,
        ec.details,
        c.date,
        c.status
    FROM ec_dedup ec
    JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
    ORDER BY ec.id_contract,
             CASE
                 WHEN ec.details ILIKE '%mensalidad%' THEN 1
                 WHEN ec.details ILIKE '%rematr%'     THEN 2
                 WHEN ec.details ILIKE '%servi%'      THEN 3
                 WHEN ec.details ILIKE '%aliment%'    THEN 4
                 WHEN ec.details ILIKE '%material%'   THEN 5
                 WHEN ec.details ILIKE '%contrato%'   THEN 6
                 ELSE 9
             END,
             ec.details
),
-- 3. Resolver dados do aluno + turma via enrollment + sturma
alunos AS (
    SELECT
        e.id_enrollment,
        e.id_person,
        e.academic_calendar,
        e.class_name,
        scu.code_unif,
        CASE inst.code WHEN 'un1' THEN 1 WHEN 'un2' THEN 2 END AS codfilial,
        st."CODCURSO",
        st."CODHABILITACAO",
        st."CODGRADE",
        st."TURNO"
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.institution        inst ON inst.id_institution = e.id_institution
    JOIN gennera_stg.student_code_unico scu  ON scu.id_person        = e.id_person
    JOIN export.sturma                   st  ON st."CODTURMA"        = e.class_name
                                             AND st."CODPERLET"       = e.academic_calendar
    WHERE inst.code IN ('un1','un2')
      AND scu.code_unif IS NOT NULL
      AND e.academic_calendar IS NOT NULL
),
-- 4. Ranqueie cada plano pela especificidade (menor cobertura = mais especifico)
plano_ranking AS (
    SELECT
        "CODPLANOPGTO",
        "CODFILIAL",
        "CODCURSO",
        "IDHABILITACAOFILIAL",
        "CODGRADE",
        "CODTURNO",
        "IDPERLET",
        COUNT(*) OVER (PARTITION BY "CODPLANOPGTO") AS cobertura
    FROM export.shabmodelopgto
),
-- 5. Escolher 1 plano por (filial+curso+hab+grade+turno+ano) - o mais especifico
plano_por_combo AS (
    SELECT DISTINCT ON ("CODFILIAL","CODCURSO","IDHABILITACAOFILIAL","CODGRADE","CODTURNO","IDPERLET")
        "CODFILIAL",
        "CODCURSO",
        "IDHABILITACAOFILIAL",
        "CODGRADE",
        "CODTURNO",
        "IDPERLET",
        "CODPLANOPGTO"
    FROM plano_ranking
    ORDER BY "CODFILIAL","CODCURSO","IDHABILITACAOFILIAL","CODGRADE","CODTURNO","IDPERLET",
             cobertura NULLS LAST,
             "CODPLANOPGTO"
)
-- 6. Montar SELECT final
SELECT
    1                                                   AS "CODCOLIGADA",
    a."CODCURSO"::character varying(10)                 AS "CODCURSO",
    a."CODHABILITACAO"::character varying(10)           AS "CODHABILITACAO",
    a."CODGRADE"::character varying(10)                 AS "CODGRADE",
    a."TURNO"::character varying(15)                    AS "TURNO",
    a.codfilial                                         AS "CODFILIAL",
    1                                                   AS "CODTIPOCURSO",
    a.code_unif::character varying(20)                  AS "RA",
    a.academic_calendar::character varying(10)          AS "CODPERLET",
    cd.id_contract::character varying(20)               AS "CODCONTRATO",
    pc."CODPLANOPGTO"::character varying(10)            AS "CODPLANOPGTO",
    to_char(cd.date, 'YYYY-MM-DD')::character varying(10) AS "DTCONTRATO",
    to_char(cd.date, 'YYYY-MM-DD')::character varying(10) AS "DTASSINATURA",
    'N'::character varying(1)                           AS "DIAFIXO",
    10::integer                                         AS "DIAVENCIMENTO",
    -- TIPOCONTRATO: P=Plano (mensalidade/rematricula), S=Servico
    CASE
        WHEN cd.details ILIKE '%mensalidad%'
          OR cd.details ILIKE '%rematr%'
          OR cd.details ILIKE '%contrato%'   THEN 'P'
        ELSE 'S'
    END::character varying(1)                           AS "TIPOCONTRATO",
    'S'::character varying(1)                           AS "TIPOBOLSA",
    NULL::character varying(25)                         AS "CODCCUSTO",
    'S'::character varying(1)                           AS "ASSINADO",
    CASE WHEN cd.status = 'deleted' THEN 'S' ELSE 'N' END
        ::character varying(1)                          AS "STATUS",
    NULL::date                                          AS "DTCANCELAMENTO"
FROM alunos a
JOIN contratos_dedup cd ON cd.id_enrollment = a.id_enrollment
LEFT JOIN plano_por_combo pc
       ON pc."CODFILIAL"                 = a.codfilial
      AND pc."CODCURSO"::text            = a."CODCURSO"
      AND pc."IDHABILITACAOFILIAL"::text = a."CODHABILITACAO"::text
      AND pc."CODGRADE"::text            = a."CODGRADE"::text
      AND pc."CODTURNO"::text            = a."TURNO"
      AND pc."IDPERLET"::text            = a.academic_calendar;
