-- ============================================================================
-- View: export.sbolsa
-- Esquema destino TOTVS: SBOLSA
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

CREATE OR REPLACE VIEW export.sbolsa AS
WITH base AS (
         SELECT
                CASE
                    WHEN bd.desconto_descricao::text ~~* 'desconto comercial %'::text THEN 'DESCONTO COMERCIAL VARIAVEL'::text
                    ELSE upper(TRIM(BOTH FROM bd.desconto_descricao))
                END AS nome_norm,
                CASE
                    WHEN bd.desconto_forma_calculo::text = 'relativo'::text THEN NULLIF(TRIM(BOTH FROM bd.desconto_percentual), ''::text)::numeric
                    ELSE NULL::numeric
                END AS percentual,
            bd.desconto_forma_calculo AS forma,
            bd.categoria_desconto AS categoria,
            bd.desconto_tipo_fiscal AS tipo_fiscal,
            bd.desconto_descricao AS desc_original
           FROM gennera_stg.bolsas_descontos bd
          WHERE bd.desconto_descricao IS NOT NULL AND TRIM(BOTH FROM bd.desconto_descricao) <> ''::text
        ), catalogo AS (
         SELECT base.nome_norm AS nome,
            COALESCE(mode() WITHIN GROUP (ORDER BY base.percentual), 0::numeric) AS valor_percentual,
            mode() WITHIN GROUP (ORDER BY base.forma) AS forma,
            mode() WITHIN GROUP (ORDER BY base.categoria) AS classificacao,
            bool_or(base.categoria::text ~~* '%funcion%'::text OR base.nome_norm ~~ '%FUNCION%'::text OR base.nome_norm ~~ '%FOLHA FF%'::text OR base.nome_norm = 'FF'::text) AS is_bolsa_func,
            bool_or(base.nome_norm ~~ 'BOLSA %'::text OR base.categoria::text ~~* '%bolsa%'::text) AS is_bolsa,
            count(*) AS aplicacoes
           FROM base
          GROUP BY base.nome_norm
        )
 SELECT 1 AS "CODCOLIGADA",
    NULL::integer AS "CODCOLCFO",
    NULL::character varying(25) AS "CODCFO",
    "left"(nome, 60)::character varying(60) AS "NOME",
    valor_percentual::numeric(10,4) AS "VALOR",
    1 AS "CODTIPOCURSO",
    '1'::character varying(1) AS "RENOVACAOAUTOMATICA",
    '0'::character varying(1) AS "VALIDADELIMITADA",
    '0'::character varying(1) AS "FIES",
        CASE
            WHEN is_bolsa_func THEN '1'::text
            ELSE '0'::text
        END::character varying(1) AS "BOLSAFUNC",
    NULL::integer AS "ORDEMPERDA",
    'N'::character varying(1) AS "TIPOSAC",
    'S'::character varying(1) AS "ATIVA",
    'S'::character varying(1) AS "PERMITEALTERARVALOR",
        CASE
            WHEN forma::text = 'relativo'::text THEN 'P'::text
            ELSE 'V'::text
        END::character varying(1) AS "TIPODESC",
    "left"(classificacao::text, 60)::character varying(60) AS "CLASSIFICACAOBOLSA",
    'N'::character varying(1) AS "VERIFICAINADIMPLENCIA"
   FROM catalogo
  ORDER BY nome;;
