-- ============================================================================
-- View: export.sturma
-- Esquema destino TOTVS: STURMA
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

CREATE OR REPLACE VIEW export.sturma AS
WITH turma_base AS (
         SELECT NULLIF(TRIM(BOTH FROM e.academic_calendar), ''::text)::integer AS codgrade,
            TRIM(BOTH FROM e.class_name) AS turma_nome,
            a.code_module::text AS codhabilitacao_txt,
                CASE
                    WHEN e.course_name ~~* '%infantil%'::text THEN 'EI'::text
                    WHEN e.course_name ~~* '%fundamental ii%'::text OR e.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                    WHEN e.course_name ~~* '%fundamental i%'::text OR e.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                    WHEN e.course_name ~~* '%médio%'::text OR e.course_name ~~* '%medio%'::text THEN 'EM'::text
                    ELSE NULL::text
                END AS codcurso_rm,
                CASE
                    WHEN (
                    CASE
                        WHEN e.course_name ~~* '%infantil%'::text THEN 'EI'::text
                        WHEN e.course_name ~~* '%fundamental ii%'::text OR e.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                        WHEN e.course_name ~~* '%fundamental i%'::text OR e.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                        WHEN e.course_name ~~* '%médio%'::text OR e.course_name ~~* '%medio%'::text THEN 'EM'::text
                        ELSE NULL::text
                    END = 'EF1'::text AND (a.code_module::text = ANY (ARRAY['1'::text, '2'::text])) OR
                    CASE
                        WHEN e.course_name ~~* '%infantil%'::text THEN 'EI'::text
                        WHEN e.course_name ~~* '%fundamental ii%'::text OR e.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                        WHEN e.course_name ~~* '%fundamental i%'::text OR e.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                        WHEN e.course_name ~~* '%médio%'::text OR e.course_name ~~* '%medio%'::text THEN 'EM'::text
                        ELSE NULL::text
                    END = 'EI'::text) AND (a.module_name = ANY (ARRAY['Jardim 2'::text, '1º Ano'::text, 'Maternal 3'::text, '2º Ano'::text, 'Jardim 1'::text, 'Maternal 2'::text])) THEN 2
                    ELSE 1
                END AS codfilial_calc
           FROM gennera_stg.enrollment e
             LEFT JOIN gennera_stg.academic a ON a.module_name = e.module_name
          WHERE e.academic_calendar IS NOT NULL AND NULLIF(TRIM(BOTH FROM e.academic_calendar), ''::text) ~ '^\d{4}$'::text AND e.class_name IS NOT NULL AND TRIM(BOTH FROM e.class_name) <> ''::text AND e.course_name IS NOT NULL
        ), turma_unificada AS (
         SELECT DISTINCT turma_base.codgrade,
            turma_base.codcurso_rm,
            turma_base.codhabilitacao_txt,
            turma_base.codfilial_calc,
            turma_base.turma_nome
           FROM turma_base
          WHERE turma_base.codcurso_rm IS NOT NULL AND turma_base.codhabilitacao_txt IS NOT NULL
        )
 SELECT DISTINCT h."CODCOLIGADA",
    h."CODCURSO",
    h."CODHABILITACAO",
    h."CODGRADE",
    h."TURNO",
    h."CODFILIAL",
    h."CODTIPOCURSO",
    h."CODPERLET",
    t.turma_nome AS "CODTURMA",
    NULL::text AS "CODDEPARTAMENTO",
    NULL::text AS "CODPREDIO",
    NULL::text AS "CODSALA",
    NULL::text AS "CODCCUSTO",
    "left"(t.turma_nome, 30) AS "NOMERED",
    t.turma_nome AS "NOME",
    9999 AS "MAXALUNOS",
    NULL::date AS "DTINICIAL",
    NULL::date AS "DTFINAL",
    NULL::integer AS "ALUNOSLABORE",
    NULL::date AS "DTALUNOSLABORE",
    NULL::text AS "CODTURMAPROX",
    NULL::text AS "CODCAMPUS",
    NULL::text AS "CODBLOCO",
    NULL::text AS "TIPOMEDIACAO"
   FROM export.shabilitacaofilialpl h
     JOIN turma_unificada t ON t.codgrade = h."CODGRADE" AND t.codcurso_rm = h."CODCURSO" AND t.codhabilitacao_txt = h."CODHABILITACAO"::text AND t.codfilial_calc = h."CODFILIAL"
  WHERE t.turma_nome <> 'TEMP'::text;;
