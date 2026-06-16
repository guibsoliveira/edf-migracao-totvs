-- ============================================================================
-- View: export_v2.flan
-- Esquema destino TOTVS: FLAN
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

CREATE OR REPLACE VIEW export_v2.flan AS
SELECT "CODCFO",
    lpad(row_number() OVER (ORDER BY ("CODCONTRATO"::integer), ("DTCOMPETENCIA"::date), "SERVICO", "PARCELA")::text, 8, '0'::text)::character varying(8) AS "NUMERODOCUMENTO",
    '0000000001'::character varying(25) AS "CODCCUSTO",
    "left"(((("SERVICO"::text || ' '::text) || to_char("DTCOMPETENCIA"::date::timestamp with time zone, 'MM/YYYY'::text)) || ' - RA '::text) || "RA"::text, 255)::character varying(255) AS "HISTORICO",
    "DTVENCIMENTO" AS "DATAVENCIMENTO",
    to_char(("DTVENCIMENTO"::date - '30 days'::interval)::date::timestamp with time zone, 'YYYY-MM-DD'::text)::character varying(10) AS "DATAEMISSAO",
    replace("VALOR", ','::text, '.'::text)::numeric(12,2) AS "VALOROPERACAO",
    0::numeric(12,2) AS "VALORJUROS",
    replace(COALESCE("DESCONTO", '0,00'::text), ','::text, '.'::text)::numeric(12,2) AS "VALORDESCONTO",
    0::numeric(12,2) AS "VALORMULTA",
    '237'::character varying(10) AS "CODCXA",
    'BOLETO'::character varying(10) AS "CODTDO",
    '@@@'::character varying(8) AS "SERIEDOC",
    1 AS "PAGREC",
    "CODFILIAL",
    '111.111'::character varying(40) AS "NATFINANCEIRA",
    "RA",
    "CODCONTRATO",
    "CODPERLET",
    "SERVICO",
    "PARCELA"
   FROM export_v2.sparcela sp
  WHERE "CODCFO" IS NOT NULL;;
