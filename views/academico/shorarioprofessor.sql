-- ============================================================================
-- View: export.shorarioprofessor
-- Esquema destino TOTVS: SHORARIOPROFESSOR
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

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.shorarioprofessor)
-- Recriar exige: DROP MATERIALIZED VIEW export.shorarioprofessor; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.shorarioprofessor AS
SELECT st."CODCOLIGADA",
    st."CODCURSO",
    st."CODHABILITACAO",
    st."CODGRADE",
    st."TURNO",
    st."CODFILIAL",
    st."CODTIPOCURSO",
    st."CODPERLET",
    st."CODTURMA",
    st."CODDISC",
    pt."CODPROF",
    st."DIASEMANA",
    st."HORAINICIAL",
    st."HORAFINAL",
    'S'::character varying(1) AS "DESCONSIDERAPONTO",
    NULL::date AS "DATAINICIAL",
    NULL::date AS "DATAFINAL"
   FROM export.shorarioturma st
     JOIN export.sprofessorturma pt ON pt."CODCOLIGADA" = st."CODCOLIGADA" AND pt."CODCURSO" = st."CODCURSO" AND pt."CODHABILITACAO" = st."CODHABILITACAO" AND pt."CODGRADE" = st."CODGRADE" AND pt."TURNO" = st."TURNO" AND pt."CODFILIAL" = st."CODFILIAL" AND pt."CODTIPOCURSO" = st."CODTIPOCURSO" AND pt."CODPERLET" = st."CODPERLET" AND pt."CODTURMA" = st."CODTURMA" AND pt."CODDISC" = st."CODDISC";;

-- Indices existentes:
-- CREATE UNIQUE INDEX shorarioprofessor_uk ON export.shorarioprofessor USING btree ("CODCOLIGADA", "CODCURSO", "CODHABILITACAO", "CODGRADE", "TURNO", "CODFILIAL", "CODTIPOCURSO", "CODPERLET", "CODTURMA", "CODDISC", "CODPROF", "DIASEMANA", "HORAINICIAL", "HORAFINAL");
