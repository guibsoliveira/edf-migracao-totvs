-- ============================================================================
-- View: export.snotaetapa
-- Esquema destino TOTVS: SNOTAETAPA
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

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.snotaetapa)
-- Recriar exige: DROP MATERIALIZED VIEW export.snotaetapa; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.snotaetapa AS
WITH etapa_map(period, codetapa) AS (
         VALUES ('Período I'::text,1), ('Período II'::text,2), ('Período III'::text,3), ('Recuperação Anual'::text,4)
        ), grade_dedup AS (
         SELECT DISTINCT ON (grade.id_person, grade.subject_name, grade.academic_calendar, grade.class_name, grade.period_name) grade.id_person,
            grade.subject_name,
            grade.academic_calendar,
            grade.class_name,
            grade.period_name,
            grade.module_name,
            grade.course_name,
            grade.grade
           FROM gennera_stg.grade
          WHERE (grade.class_name <> ALL (ARRAY['Módulo 1'::text, 'Módulo 2'::text, 'TEMP'::text])) AND grade.course_name !~~* '%infantil%'::text AND grade.subject_name <> 'Desenvolvimento Infantil'::text AND grade.academic_calendar IS NOT NULL AND TRIM(BOTH FROM grade.academic_calendar) <> ''::text AND (grade.period_name = ANY (ARRAY['Período I'::text, 'Período II'::text, 'Período III'::text, 'Recuperação Anual'::text])) AND grade.exam_name = 'Avaliação parcial'::text
          ORDER BY grade.id_person, grade.subject_name, grade.academic_calendar, grade.class_name, grade.period_name, grade.grade DESC NULLS LAST
        )
 SELECT 1 AS "CODCOLIGADA",
    s."CODCURSO",
    s."CODHABILITACAO",
    s."CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    scu.code_unif::character varying(20) AS "RA",
    g.class_name::character varying(20) AS "CODTURMA",
    g.academic_calendar::character varying(10) AS "CODPERLET",
    d.discipline_code::character varying(20) AS "CODDISC",
    em.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
        CASE
            WHEN NULLIF(TRIM(BOTH FROM g.grade), ''::text) ~ '^[0-9]+([.,][0-9]+)?$'::text THEN NULL::character varying(10)
            ELSE "left"(TRIM(BOTH FROM g.grade), 10)::character varying(10)
        END AS "CONCEITO",
        CASE
            WHEN NULLIF(TRIM(BOTH FROM g.grade), ''::text) ~ '^[0-9]+([.,][0-9]+)?$'::text THEN replace(TRIM(BOTH FROM g.grade), ','::text, '.'::text)::numeric(10,4)
            ELSE NULL::numeric
        END AS "NOTAFALTA",
    NULL::integer AS "AULASDADAS"
   FROM grade_dedup g
     JOIN etapa_map em ON em.period = g.period_name
     JOIN gennera_stg.disciplina d ON TRIM(BOTH FROM d.discipline_name) = TRIM(BOTH FROM g.subject_name)
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = g.id_person
     JOIN export.sturmadisc sd ON sd."CODTURMA"::text = g.class_name AND sd."CODPERLET"::text = g.academic_calendar AND sd."CODDISC"::text = d.discipline_code::text
     JOIN export.sturma s ON s."CODTURMA" = g.class_name AND s."CODGRADE"::text = g.academic_calendar
  WHERE d.discipline_code IS NOT NULL;;

-- Indices existentes:
-- CREATE UNIQUE INDEX snotaetapa_uk ON export.snotaetapa USING btree ("CODCOLIGADA", "CODCURSO", "CODHABILITACAO", "CODGRADE", "CODFILIAL", "CODTIPOCURSO", "CODPERLET", "CODTURMA", "CODDISC", "RA", "CODETAPA");
