-- =====================================================================
-- export_v2.scontrato — Contrato do aluno (v2 com plano genérico)
-- =====================================================================
-- Mesma lógica de scontrato_view_nova.sql, MAS:
--   • CODPLANOPGTO usa export_v2.splanopgto (somente 2026 por enquanto)
--   • Anos antigos (2021-2025) ficam com CODPLANOPGTO = NULL
--   • Lookup do plano via export_v2.shabmodelopgto
-- =====================================================================

DROP VIEW IF EXISTS export_v2.scontrato CASCADE;

CREATE OR REPLACE VIEW export_v2.scontrato AS
WITH
ec_dedup AS (
    SELECT DISTINCT id_enrollment, id_contract, details
    FROM gennera_stg.enrollment_contract
),
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
    JOIN gennera_stg.student_code_unico scu  ON scu.id_person       = e.id_person
    JOIN export.sturma                   st  ON st."CODTURMA"       = e.class_name
                                             AND st."CODPERLET"      = e.academic_calendar
    WHERE inst.code IN ('un1','un2')
      AND scu.code_unif IS NOT NULL
      AND e.academic_calendar IS NOT NULL
),
-- Lookup plano via export_v2.shabmodelopgto (somente 2026)
plano_por_combo AS (
    SELECT DISTINCT ON ("CODFILIAL","CODCURSO","IDHABILITACAOFILIAL","CODGRADE","CODTURNO","IDPERLET")
        "CODFILIAL","CODCURSO","IDHABILITACAOFILIAL","CODGRADE","CODTURNO","IDPERLET",
        "CODPLANOPGTO"
    FROM export_v2.shabmodelopgto
    ORDER BY "CODFILIAL","CODCURSO","IDHABILITACAOFILIAL","CODGRADE","CODTURNO","IDPERLET",
             "CODPLANOPGTO"
)
SELECT
    1                                                   AS "CODCOLIGADA",
    a."CODCURSO"::varchar(10)                           AS "CODCURSO",
    a."CODHABILITACAO"::varchar(10)                     AS "CODHABILITACAO",
    a."CODGRADE"::varchar(10)                           AS "CODGRADE",
    a."TURNO"::varchar(15)                              AS "TURNO",
    a.codfilial                                         AS "CODFILIAL",
    1                                                   AS "CODTIPOCURSO",
    a.code_unif::varchar(20)                            AS "RA",
    a.academic_calendar::varchar(10)                    AS "CODPERLET",
    cd.id_contract::varchar(20)                         AS "CODCONTRATO",
    pc."CODPLANOPGTO"::varchar(10)                      AS "CODPLANOPGTO",
    to_char(cd.date, 'YYYY-MM-DD')::varchar(10)         AS "DTCONTRATO",
    to_char(cd.date, 'YYYY-MM-DD')::varchar(10)         AS "DTASSINATURA",
    'N'::varchar(1)                                     AS "DIAFIXO",
    10::integer                                         AS "DIAVENCIMENTO",
    CASE
        WHEN cd.details ILIKE '%mensalidad%'
          OR cd.details ILIKE '%rematr%'
          OR cd.details ILIKE '%contrato%'   THEN 'P'
        ELSE 'S'
    END::varchar(1)                                     AS "TIPOCONTRATO",
    'S'::varchar(1)                                     AS "TIPOBOLSA",
    NULL::varchar(25)                                   AS "CODCCUSTO",
    'S'::varchar(1)                                     AS "ASSINADO",
    CASE WHEN cd.status = 'deleted' THEN 'S' ELSE 'N' END::varchar(1) AS "STATUS",
    NULL::date                                          AS "DTCANCELAMENTO"
FROM alunos a
JOIN contratos_dedup cd ON cd.id_enrollment = a.id_enrollment
LEFT JOIN plano_por_combo pc
       ON pc."CODFILIAL"            = a.codfilial
      AND pc."CODCURSO"::text       = a."CODCURSO"
      AND pc."IDHABILITACAOFILIAL"::text = a."CODHABILITACAO"::text
      AND pc."CODGRADE"::text       = a."CODGRADE"::text
      AND pc."CODTURNO"::text       = a."TURNO"
      AND pc."IDPERLET"::text       = a.academic_calendar;
