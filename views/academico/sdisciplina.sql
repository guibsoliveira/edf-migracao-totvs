-- ============================================================================
-- View: export.sdisciplina
-- Esquema destino TOTVS: SDISCIPLINA
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

CREATE OR REPLACE VIEW export.sdisciplina AS
SELECT '1'::text AS "CODCOLIGADA",
    '1'::text AS "CODTIPOCURSO",
    discipline_code::text AS "CODDISC",
    NULL::text AS "CODDISCHIST",
    discipline_name::text AS "NOME",
    NULL::text AS "NOMEREDUZIDO",
    NULL::text AS "COMPLEMENTO",
    NULL::text AS "CURSOLIVRE",
    NULL::text AS "TIPOAULA",
    NULL::text AS "TIPONOTA",
    NULL::text AS "CH",
    NULL::text AS "CHESTAGIO",
    NULL::text AS "DECIMAIS",
    NULL::text AS "NUMCREDITOS",
    NULL::text AS "OBJETIVO",
    NULL::text AS "TIPODISCPROVAO",
    NULL::text AS "CHTEORICA",
    NULL::text AS "CHPRATICA",
    NULL::text AS "CHLABORATORIAL",
    NULL::text AS "CODGRUPOCOMPLEMENTO",
    NULL::text AS "ESTAGIO",
    NULL::text AS "CHTRABALHOCAMPO",
    NULL::text AS "CHSEMINARIO",
    NULL::text AS "CHORIENTACAOTUTORIAL",
    NULL::text AS "CHTEORICOPRATICA"
   FROM gennera_stg.disciplina d
  WHERE discipline_code::text !~~ '%E%'::text;;
