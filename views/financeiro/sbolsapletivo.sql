-- ============================================================================
-- View: export.sbolsapletivo
-- Esquema destino TOTVS: SBOLSAPLETIVO
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

CREATE OR REPLACE VIEW export.sbolsapletivo AS
WITH periodos AS (
         SELECT DISTINCT COALESCE(NULLIF(TRIM(BOTH FROM bd.calendario_academico), ''::text), NULLIF(TRIM(BOTH FROM bd.fatura_ano), ''::text)) AS codperlet
           FROM gennera_stg.bolsas_descontos bd
          WHERE COALESCE(NULLIF(TRIM(BOTH FROM bd.calendario_academico), ''::text), NULLIF(TRIM(BOTH FROM bd.fatura_ano), ''::text)) >= '2021'::text
        ), filiais AS (
         SELECT 1 AS codfilial
        UNION ALL
         SELECT 2
        )
 SELECT 1 AS "CODCOLIGADA",
    1 AS "CODTIPOCURSO",
    f.codfilial AS "CODFILIAL",
    p.codperlet::character varying(10) AS "CODPERLET",
    sb."NOME" AS "NOMEBOLSA"
   FROM export.sbolsa sb
     CROSS JOIN filiais f
     CROSS JOIN periodos p
  ORDER BY f.codfilial, (p.codperlet::character varying(10)), sb."NOME";;
