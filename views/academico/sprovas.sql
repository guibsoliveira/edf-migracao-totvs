-- ============================================================================
-- View: export.sprovas
-- Esquema destino TOTVS: SPROVAS
-- ============================================================================
-- Snapshot do DDL em 2026-06-11 (dump automatico via scripts/dump_views_para_repo.py)
--
-- USO COMO FONTE PARA IMPORTADOR TOTVS EDUCACIONAL
-- ------------------------------------------------------------------
-- O Importador (Executar -> Importador -> TOTVS Educacional) consome
-- arquivos .csv ANSI/LATIN-1 com separador ';' baseados nesta view.
--
-- REGRA CRITICA (ver knowledge/totvs/13_importador_layout_e_lookups.md):
-- Colunas com sintaxe COLUNA$X.TABELA$S$X$T.CAMPOBUSCA.FK1$FK1...
-- querem o CAMPOBUSCA (codigo humano), nao o ID literal.
--
-- Exemplos pro RM Educacional:
--   IDHABILITACAOFILIAL  -> passar CODHABILITACAO (ex: '8')
--   IDPERLET             -> passar CODPERLET (ex: '2022')
--   IDTURMADISC          -> passar CODDISC (ex: '7')
--   CODTURNO             -> passar NOME (ex: 'Integral')
--   CODSTATUS/RES        -> passar DESCRICAO (ex: 'Ativo', 'Aprovado')
--
-- Por isso esta view retorna sempre os CODIGOS HUMANOS, NUNCA os IDs
-- sequenciais (IDPERLET, IDHABFIL, IDTURMADISC). O Importador resolve
-- IDs internos via lookup, e o mesmo CSV migra entre instancias.
--
-- WORKFLOW para usar:
-- 1. Gerar CSV "isca" com header minimo -> Importador imprime "Layout esperado:"
-- 2. Capturar Layout esperado: literal e usar como header EXATO
-- 3. Script em scripts/gera_*_importador_totvs.py mapeia colunas da view -> layout
-- 4. Importar via TOTVS Educacional
-- ============================================================================

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.sprovas)
-- Recriar exige: DROP MATERIALIZED VIEW export.sprovas; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.sprovas AS
WITH etapa_map(period, codetapa) AS (
         VALUES ('Período I'::text,1), ('Período II'::text,2), ('Período III'::text,3), ('Recuperação Anual'::text,4)
        ), exams_com_ano AS (
         SELECT DISTINCT g.academic_calendar,
            g.class_name,
            g.subject_name,
            g.course_name,
            g.module_name,
            g.period_name,
            g.exam_name,
            e.max_grade,
                CASE
                    WHEN g.course_name ~~* '%fundamental ii%'::text OR g.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                    WHEN g.course_name ~~* '%fundamental i%'::text OR g.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                    WHEN g.course_name ~~* '%médio%'::text OR g.course_name ~~* '%medio%'::text THEN 'EM'::text
                    ELSE NULL::text
                END AS codcurso
           FROM gennera_stg.grade g
             JOIN gennera_stg.exam e ON e.class = g.class_name AND e.subject = g.subject_name AND e.period = g.period_name AND e.name = g.exam_name
          WHERE (g.class_name <> ALL (ARRAY['Módulo 1'::text, 'Módulo 2'::text, 'TEMP'::text])) AND g.course_name !~~* '%infantil%'::text AND g.subject_name <> 'Desenvolvimento Infantil'::text AND g.academic_calendar IS NOT NULL AND TRIM(BOTH FROM g.academic_calendar) <> ''::text AND (g.period_name = ANY (ARRAY['Período I'::text, 'Período II'::text, 'Período III'::text, 'Recuperação Anual'::text]))
        )
 SELECT 1 AS "CODCOLIGADA",
    ex.codcurso::character varying(10) AS "CODCURSO",
    a.code_module::character varying(10) AS "CODHABILITACAO",
    ex.academic_calendar::character varying(10) AS "CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    1 AS "CODTIPOCURSO",
    ex.academic_calendar::character varying(10) AS "CODPERLET",
    ex.class_name::character varying(20) AS "CODTURMA",
    d.discipline_code::character varying(20) AS "CODDISC",
    em.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
    row_number() OVER (PARTITION BY ex.class_name, d.discipline_code, em.codetapa, ex.academic_calendar ORDER BY ex.exam_name)::integer AS "CODPROVA",
    ex.exam_name::character varying(100) AS "DESCRICAO",
    ex.max_grade::numeric(10,4) AS "VALOR",
    NULL::numeric(10,4) AS "MEDIA",
    NULL::date AS "DTPREVISTA",
    NULL::date AS "DTPROVA",
    NULL::integer AS "NUMQUESTOES",
    NULL::date AS "DTDEVOLUCAOAVALIACAO",
    NULL::date AS "DTLIMITEENTREGAAVAL",
    NULL::character varying(1) AS "PERMITEENTREGAWEB",
    NULL::character varying(1) AS "DISPONIVELALUNOS",
    NULL::character varying(65) AS "CODPROVATESTIS"
   FROM exams_com_ano ex
     JOIN etapa_map em ON em.period = ex.period_name
     JOIN gennera_stg.disciplina d ON TRIM(BOTH FROM d.discipline_name) = TRIM(BOTH FROM ex.subject_name)
     LEFT JOIN ( SELECT DISTINCT academic.module_name,
            academic.course_code,
            academic.code_module
           FROM gennera_stg.academic) a ON a.module_name = ex.module_name AND a.course_code = ex.codcurso
     LEFT JOIN export.sturma s ON s."CODTURMA" = ex.class_name AND s."CODGRADE"::text = ex.academic_calendar
  WHERE d.discipline_code IS NOT NULL AND ex.codcurso IS NOT NULL;;

-- Indices existentes:
-- CREATE UNIQUE INDEX sprovas_uk ON export.sprovas USING btree ("CODCOLIGADA", "CODCURSO", "CODHABILITACAO", "CODGRADE", "CODFILIAL", "CODTIPOCURSO", "CODPERLET", "CODTURMA", "CODDISC", "CODETAPA", "CODPROVA");
