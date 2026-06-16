-- ============================================================================
-- View: export.flan
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

CREATE OR REPLACE VIEW export.flan AS
SELECT lpad(pf.codcfo::text, 6, '0'::text) AS "CODCFO",
    c.id_contract::text AS "NUMERODOCUMENTO",
    '0000000001'::text AS "CODCCUSTO",
    NULL::text AS "IDHISTORICO",
    to_char(i.due_date, 'DD/MM/YYYY'::text) AS "DATAEVENCIMENTO",
    to_char(c.date, 'DD/MM/YYYY'::text) AS "DATAEMISSAO",
    to_char(i.purchases, 'FM9999999990.00'::text) AS "VALORORIGINAL",
    to_char(c.interests, 'FM9999999990.00'::text) AS "VALORJUROS",
    to_char(c.discounts, 'FM9999999990.00'::text) AS "VALORDESCONTO",
    to_char(c.penalties, 'FM9999999990.00'::text) AS "VALORMULTA",
    '237'::text AS "CODCXA",
    'BOLETO'::text AS "CODTDO",
    '@@@'::text AS "SERIEDOCUMENTO",
    '2'::text AS "PAGREC",
    c.id_institution::text AS "CODFILIAL",
    '111.111'::text AS "CODNATFINANCEIRA"
   FROM gennera_stg.contract c
     JOIN gennera_stg.invoice i ON i.id_contract = c.id_contract
     JOIN gennera_stg.person_fisica pf ON pf.id_person = c.id_person
  WHERE c.status = 'active'::text AND i.balance > 0::numeric AND pf.codcfo IS NOT NULL AND pf.codcfo::text <> ''::text;;
