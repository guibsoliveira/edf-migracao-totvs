-- ============================================================================
-- View: export.sdiscgrade
-- Esquema destino TOTVS: SDISCGRADE
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

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.sdiscgrade)
-- Recriar exige: DROP MATERIALIZED VIEW export.sdiscgrade; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.sdiscgrade AS
SELECT DISTINCT ON (att.academic_calendar, a.course_code, a.subject_name, a.code_module) '1'::text AS "CODCOLIGADA",
    COALESCE(a.course_code, src.course_code) AS "CODCURSO",
    COALESCE(a.code_module::text, src.code_module::text) AS "CODHABILITACAO",
    COALESCE(att.academic_calendar, src.ref_year::text) AS "CODGRADE",
        CASE
            WHEN COALESCE(a.subject_name, src.academic_subject_name, src.subject_name) = ANY (ARRAY['Eletiva - Espanhol'::text, 'Eletiva - Japonês'::text]) THEN '0'::text
            ELSE '1'::text
        END AS "CODPERIODO",
    COALESCE(a.subject_code::text, a.subject_code_gennera::text, src.disc_code_text) AS "CODDISC",
    NULL::text AS "CODGRPDISC",
    NULL::text AS "PREREQCRED",
    COALESCE(a.subject_name, src.academic_subject_name, src.subject_name) AS "DESCRICAO",
    '1'::text AS "POSHIST",
    COALESCE(floor(src.subject_workload)::integer::text) AS "CH",
    NULL::text AS "NUMCREDITOSCOB",
    NULL::text AS "VALORCREDITO",
    NULL::text AS "OBJETIVO",
    NULL::text AS "PERCAULASNAOPRES",
    NULL::text AS "PRIORIDADEMATRICULA",
    '2'::text AS "DECIMAIS",
    '1'::text AS "ATIVIDADE",
    'N'::text AS "CALCMEDIAGLOBAL",
    'S'::text AS "DESEMPENHOALUNO",
    'S'::text AS "IMPBOLETIM",
    'N'::text AS "TIPONOTA",
    NULL::text AS "NUMMINDISC",
    NULL::text AS "CHDISC",
        CASE
            WHEN COALESCE(a.subject_name, src.academic_subject_name, src.subject_name) = ANY (ARRAY['Eletiva - Espanhol'::text, 'Eletiva - Japonês'::text]) THEN 'E'::text
            WHEN src.is_lang_choice_elective THEN 'E'::text
            ELSE 'B'::text
        END AS "TIPODISC",
    NULL::text AS "APLICACAO",
    NULL::text AS "CODFORMULACO",
    NULL::text AS "CODFORMULAPRE"
   FROM export.v_matrix_source src
     LEFT JOIN gennera_stg.academic a ON NULLIF(TRIM(BOTH FROM a.course_name), ''::text) = NULLIF(TRIM(BOTH FROM src.course_name), ''::text) AND NULLIF(TRIM(BOTH FROM a.module_name), ''::text) = NULLIF(TRIM(BOTH FROM src.module_name), ''::text) AND NOT NULLIF(TRIM(BOTH FROM a.curriculum_name), ''::text) IS DISTINCT FROM NULLIF(TRIM(BOTH FROM src.curriculum_name), ''::text) AND (COALESCE(a.subject_code::text, a.subject_code_gennera::text) = src.disc_code_text OR a.subject_name IS NOT NULL AND src.subject_name IS NOT NULL AND lower(a.subject_name) = lower(src.subject_name))
     LEFT JOIN gennera_stg.attendance att ON att.academic_calendar = src.ref_year::text;;
