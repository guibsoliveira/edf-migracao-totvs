-- ============================================================================
-- View: export.sturmadisc
-- Esquema destino TOTVS: STURMADISC
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

CREATE OR REPLACE VIEW export.sturmadisc AS
SELECT DISTINCT 1 AS "CODCOLIGADA",
    sd."CODCURSO"::character varying(10) AS "CODCURSO",
    sd."CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
    sd."CODGRADE"::character varying(10) AS "CODGRADE",
    'Integral'::character varying(15) AS "TURNO",
        CASE
            WHEN a.id_institution = 1 THEN 1
            WHEN a.id_institution = 2 THEN 2
            ELSE 1
        END AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    sd."CODGRADE"::character varying(10) AS "CODPERLET",
    disc.discipline_code::character varying(20) AS "CODDISC",
    t."CODTURMA"::character varying(20) AS "CODTURMA",
    NULL::character varying(5) AS "CODPREDIO",
    NULL::character varying(10) AS "CODSALA",
    NULL::character varying(25) AS "CODCCUSTO",
    '101'::text AS "MAXALUNOS",
    NULL::integer AS "MINALUNOS",
    NULL::date AS "DTINICIAL",
    NULL::date AS "DTFINAL",
    NULL::integer AS "NUMAULASEM",
    NULL::integer AS "DURACAOAULA",
    NULL::numeric(10,4) AS "CUSTOMEDIO",
    NULL::character varying(60) AS "NOME",
    NULL::character varying(1) AS "TIPO",
    NULL::character varying(10) AS "CODCAMPUS",
    NULL::character varying(5) AS "CODBLOCO",
    NULL::character varying(1) AS "ADICIONALNOTURNO",
    NULL::character varying(1) AS "ADICIONALEXTRA",
    NULL::integer AS "VAGASCALOUROS",
    NULL::integer AS "NUMMAXALUNOOUTROSCURSOS",
    NULL::character varying(1) AS "DISPONIVELMATRICULA",
    NULL::numeric(10,4) AS "NUMCREDITOSCOB",
    NULL::integer AS "VAGASLISTAESPERA",
    NULL::numeric(10,4) AS "VALORCREDITO",
    NULL::date AS "DTINICIOMATPRES",
    NULL::date AS "DTFIMMATPRES",
    NULL::date AS "DTINICIOMATPORTAL",
    NULL::date AS "DTFIMMATPORTAL",
    NULL::character varying(1) AS "ATIVA",
    NULL::character varying(1) AS "GERENCIAL",
    NULL::character varying(15) AS "TURNOTURMADISC",
    NULL::integer AS "CODITINERARIOFORMATIVO"
   FROM export.sdiscgrade sd
     LEFT JOIN gennera_stg.academic a ON a.course_code = sd."CODCURSO" AND a.code_module::text = sd."CODHABILITACAO"
     LEFT JOIN gennera_stg.disciplina disc ON disc.discipline_code::text = sd."CODDISC"
     LEFT JOIN export.sturma t ON t."CODCURSO" = sd."CODCURSO" AND t."CODHABILITACAO"::text = sd."CODHABILITACAO" AND t."CODGRADE"::text = sd."CODGRADE";;
