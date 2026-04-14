CREATE OR REPLACE VIEW export.sprovas AS
WITH
-- Mapeamento período → etapa
etapa_map (period, codetapa) AS (
    VALUES
        (E'Per\u00EDodo I',           1),
        (E'Per\u00EDodo II',          2),
        (E'Per\u00EDodo III',         3),
        (E'Recupera\u00E7\u00E3o Anual',  4)
),
-- Exames distintos com ano (cruzando grade + exam) + CODCURSO derivado
exams_com_ano AS (
    SELECT DISTINCT
        g.academic_calendar,
        g.class_name,
        g.subject_name,
        g.course_name,
        g.module_name,
        g.period_name,
        g.exam_name,
        e.max_grade,
        CASE
            WHEN g.course_name ILIKE '%fundamental ii%'
              OR g.course_name ILIKE '%fundamental 2%'      THEN 'EF2'
            WHEN g.course_name ILIKE '%fundamental i%'
              OR g.course_name ILIKE '%fundamental 1%'      THEN 'EF1'
            WHEN g.course_name ILIKE E'%m\u00E9dio%'
              OR g.course_name ILIKE '%medio%'              THEN 'EM'
        END AS codcurso
    FROM gennera_stg.grade g
    JOIN gennera_stg.exam e
        ON  e.class   = g.class_name
        AND e.subject  = g.subject_name
        AND e.period   = g.period_name
        AND e.name     = g.exam_name
    WHERE g.class_name NOT IN (E'M\u00F3dulo 1', E'M\u00F3dulo 2', 'TEMP')
      AND g.course_name NOT ILIKE '%infantil%'
      AND g.subject_name <> 'Desenvolvimento Infantil'
      AND g.academic_calendar IS NOT NULL
      AND TRIM(g.academic_calendar) <> ''
      AND g.period_name IN (
            E'Per\u00EDodo I',
            E'Per\u00EDodo II',
            E'Per\u00EDodo III',
            E'Recupera\u00E7\u00E3o Anual'
      )
)
SELECT
    1                                                       AS "CODCOLIGADA",
    ex.codcurso::character varying(10)                      AS "CODCURSO",
    (a.code_module)::character varying(10)                  AS "CODHABILITACAO",
    ex.academic_calendar::character varying(10)             AS "CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    1                                                       AS "CODTIPOCURSO",
    ex.academic_calendar::character varying(10)             AS "CODPERLET",
    ex.class_name::character varying(20)                    AS "CODTURMA",
    (d.discipline_code)::character varying(20)              AS "CODDISC",
    em.codetapa                                             AS "CODETAPA",
    'N'::character varying(1)                               AS "TIPOETAPA",
    (row_number() OVER (
        PARTITION BY ex.class_name, d.discipline_code,
                     em.codetapa, ex.academic_calendar
        ORDER BY ex.exam_name
    ))::integer                                             AS "CODPROVA",
    ex.exam_name::character varying(100)                    AS "DESCRICAO",
    ex.max_grade::numeric(10,4)                             AS "VALOR",
    NULL::numeric(10,4)                                     AS "MEDIA",
    NULL::date                                              AS "DTPREVISTA",
    NULL::date                                              AS "DTPROVA",
    NULL::integer                                           AS "NUMQUESTOES",
    NULL::date                                              AS "DTDEVOLUCAOAVALIACAO",
    NULL::date                                              AS "DTLIMITEENTREGAAVAL",
    NULL::character varying(1)                              AS "PERMITEENTREGAWEB",
    NULL::character varying(1)                              AS "DISPONIVELALUNOS",
    NULL::character varying(65)                             AS "CODPROVATESTIS"
FROM exams_com_ano ex
JOIN etapa_map em
    ON em.period = ex.period_name
JOIN gennera_stg.disciplina d
    ON TRIM(d.discipline_name) = TRIM(ex.subject_name)
LEFT JOIN (
    SELECT DISTINCT module_name, course_code, code_module
    FROM gennera_stg.academic
) a
    ON  a.module_name  = ex.module_name
    AND a.course_code  = ex.codcurso
LEFT JOIN export.sturma s
    ON  s."CODTURMA" = ex.class_name
    AND (s."CODGRADE")::text = ex.academic_calendar
WHERE d.discipline_code IS NOT NULL
  AND ex.codcurso IS NOT NULL;
