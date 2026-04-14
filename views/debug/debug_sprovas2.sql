-- Duplicatas em academic por (module_name, course_code)
SELECT module_name, course_code, COUNT(*) AS qtd
FROM gennera_stg.academic
GROUP BY module_name, course_code
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 15;

-- Amostra: o que academic tem para "6º Ano" + "EF2"
SELECT module_name, course_code, code_module
FROM gennera_stg.academic
WHERE module_name = E'6\u00BA Ano' AND course_code = 'EF2'
ORDER BY code_module
LIMIT 10;

-- Contagem esperada se academic fosse 1:1
SELECT COUNT(*) FROM (
    SELECT DISTINCT
        ex.academic_calendar, ex.class_name, ex.subject_name,
        ex.period_name, ex.exam_name
    FROM export.sprovas ex
) sub;
