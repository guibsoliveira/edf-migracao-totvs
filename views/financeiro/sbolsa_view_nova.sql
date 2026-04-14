-- =============================================================
-- VIEW: export.sbolsa
-- Template TOTVS RM — Catálogo de Bolsas e Descontos
-- Fonte: gennera_stg.bolsas_descontos
--
-- Correção: versão anterior calculava percentuais artificiais via
--           (invoice.discounts / invoice.purchases) * 100 e não
--           distinguia BOLSA de DESCONTO. Agora usa a tabela real
--           de bolsas/descontos importada do Gennera.
--
-- Regras de mapeamento:
--   NOME:                 normalização uppercase + agrupamento de
--                         "desconto comercial X%" (ruído) em genérico
--   VALOR:                desconto_percentual quando relativo; 0 manual
--   CODTIPOCURSO:         1 (Educação Básica — única para Escola)
--   RENOVACAOAUTOMATICA:  '1' (padrão: renova)
--   VALIDADELIMITADA:     '0' (concede mesmo após vencimento)
--   FIES:                 '0' (escola básica não tem FIES)
--   BOLSAFUNC:            '1' se categoria contém "Funcion" ou nome
--                         contém "FF"/"FILHO DE FUNCIONARIO"
--   TIPOSAC:              'N' (sem outro responsável sacado)
--   ATIVA:                'S'
--   PERMITEALTERARVALOR:  'S' (manual permite ajuste)
--   TIPODESC:             'P' percentual (relativo) / 'V' valor (manual)
--   CLASSIFICACAOBOLSA:   categoria_desconto (mode — resolve colisões)
--   VERIFICAINADIMPLENCIA:'N'
-- =============================================================

CREATE OR REPLACE VIEW export.sbolsa AS
WITH base AS (
    SELECT
        -- Normaliza nome: agrupa "desconto comercial X%" em genérico
        CASE
            WHEN bd.desconto_descricao ILIKE 'desconto comercial %'
                THEN 'DESCONTO COMERCIAL VARIAVEL'
            ELSE UPPER(TRIM(bd.desconto_descricao))
        END AS nome_norm,

        -- Percentual: só tem sentido quando forma=relativo
        CASE
            WHEN bd.desconto_forma_calculo = 'relativo'
                THEN NULLIF(TRIM(bd.desconto_percentual), '')::numeric
            ELSE NULL
        END AS percentual,

        bd.desconto_forma_calculo      AS forma,
        bd.categoria_desconto          AS categoria,
        bd.desconto_tipo_fiscal        AS tipo_fiscal,
        bd.desconto_descricao          AS desc_original
    FROM gennera_stg.bolsas_descontos bd
    WHERE bd.desconto_descricao IS NOT NULL
      AND TRIM(bd.desconto_descricao) <> ''
),
catalogo AS (
    SELECT
        nome_norm                                                   AS nome,
        -- Percentual canônico (moda — imune a ruído)
        COALESCE(
            mode() WITHIN GROUP (ORDER BY percentual),
            0
        )                                                           AS valor_percentual,
        -- Forma canônica
        mode() WITHIN GROUP (ORDER BY forma)                        AS forma,
        -- Classificação canônica (moda — resolve colisões)
        mode() WITHIN GROUP (ORDER BY categoria)                    AS classificacao,
        -- Detecta bolsa de funcionário
        BOOL_OR(
            categoria ILIKE '%funcion%'
            OR nome_norm LIKE '%FUNCION%'
            OR nome_norm LIKE '%FOLHA FF%'
            OR nome_norm = 'FF'
        )                                                           AS is_bolsa_func,
        -- Detecta se é bolsa propriamente dita (no sentido TOTVS)
        BOOL_OR(
            nome_norm LIKE 'BOLSA %'
            OR categoria ILIKE '%bolsa%'
        )                                                           AS is_bolsa,
        COUNT(*)                                                    AS aplicacoes
    FROM base
    GROUP BY nome_norm
)
SELECT
    1                                                       AS "CODCOLIGADA",
    NULL::integer                                           AS "CODCOLCFO",
    NULL::character varying(25)                             AS "CODCFO",
    LEFT(nome, 60)::character varying(60)                   AS "NOME",
    valor_percentual::numeric(10,4)                         AS "VALOR",
    1                                                       AS "CODTIPOCURSO",
    '1'::character varying(1)                               AS "RENOVACAOAUTOMATICA",
    '0'::character varying(1)                               AS "VALIDADELIMITADA",
    '0'::character varying(1)                               AS "FIES",
    CASE WHEN is_bolsa_func THEN '1' ELSE '0' END
        ::character varying(1)                              AS "BOLSAFUNC",
    NULL::integer                                           AS "ORDEMPERDA",
    'N'::character varying(1)                               AS "TIPOSAC",
    'S'::character varying(1)                               AS "ATIVA",
    'S'::character varying(1)                               AS "PERMITEALTERARVALOR",
    CASE
        WHEN forma = 'relativo' THEN 'P'
        ELSE 'V'
    END::character varying(1)                               AS "TIPODESC",
    LEFT(classificacao, 60)::character varying(60)          AS "CLASSIFICACAOBOLSA",
    'N'::character varying(1)                               AS "VERIFICAINADIMPLENCIA"
FROM catalogo
ORDER BY nome;
