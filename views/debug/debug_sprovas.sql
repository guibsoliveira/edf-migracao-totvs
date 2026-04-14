-- Contagem do CTE exams_com_ano isolado
SELECT COUNT(*) AS exams_com_ano_count FROM (
    SELECT DISTINCT
        g.academic_calendar, g.class_name, g.subject_name,
        g.course_name, g.module_name, g.period_name, g.exam_name,
        e.max_grade
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
      AND g.period_name IN (E'Per\u00EDodo I', E'Per\u00EDodo II', E'Per\u00EDodo III', E'Recupera\u00E7\u00E3o Anual')
) sub;

-- Duplicatas por disciplina no disciplina table
SELECT discipline_name, COUNT(*) AS qtd
FROM gennera_stg.disciplina
GROUP BY discipline_name
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Duplicatas por module_name no academic
SELECT module_name, COUNT(*) AS qtd
FROM gennera_stg.academic
GROUP BY module_name
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Duplicatas por CODTURMA+CODGRADE no sturma
SELECT "CODTURMA", "CODGRADE"::text, COUNT(*) AS qtd
FROM export.sturma
GROUP BY "CODTURMA", "CODGRADE"
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Cursos distintos em grade para verificar EF2
SELECT DISTINCT course_name FROM gennera_stg.grade
WHERE course_name ILIKE '%fundamental%'
ORDER BY course_name;
