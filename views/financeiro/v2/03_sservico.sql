-- =====================================================================
-- export_v2.sservico — Catálogo de serviços TOTVS
-- =====================================================================
-- Estrutura nova (recomendação Lucas, consultor TOTVS):
--   • 4 itens FIXOS genéricos (valor=0; o valor real vai em SPARCPLANO)
--       1. 1ª mensalidade
--       2. Mensalidade
--       3. Material Didático
--       4. Alimentação
--   • N itens VARIÁVEIS (eventos, formaturas, English Camp, taxas etc)
--       um SSERVICO por DESCRIPTION distinta vinda do Gennera com VALOR
--       efetivo (mode dos preços históricos)
--
-- Caixa: CODCOLCXA=1 / CODCXA=237 (Bradesco)
-- Natureza financeira: CODCOLNATFINANCEIRA=1 / NATFINANCEIRA=111.111
-- Aceita cartão débito e crédito.
-- =====================================================================

DROP VIEW IF EXISTS export_v2.sservico CASCADE;

CREATE OR REPLACE VIEW export_v2.sservico AS
WITH fixos AS (
    -- 4 SSERVICOs fixos (valor=0; SPARCPLANO define valor real)
    SELECT * FROM (VALUES
        ('1ª mensalidade'::varchar(60),    0::numeric(10,4)),
        ('Mensalidade'::varchar(60),       0::numeric(10,4)),
        ('Material Didático'::varchar(60), 0::numeric(10,4)),
        ('Alimentação'::varchar(60),       0::numeric(10,4))
    ) AS t(nome, valor)
),
variaveis AS (
    -- Itens variáveis: 1 SSERVICO por description distinta com valor mode
    SELECT
        LEFT(description, 60)::varchar(60) AS nome,
        (mode() WITHIN GROUP (ORDER BY price))::numeric(10,4) AS valor
    FROM gennera_stg.item_to_sservico
    WHERE sservico_nome = 'Variável'
      AND description IS NOT NULL
      AND TRIM(description) <> ''
    GROUP BY LEFT(description, 60)
),
-- Items legacy do servicos_historico que NÃO existem em api_items
-- (ex: OUTROS RECEBIMENTOS, PROJETO ADOTE, etc.)
servicos_historico_extras AS (
    SELECT
        LEFT(TRIM(sh.item), 60)::varchar(60) AS nome,
        (mode() WITHIN GROUP (
            ORDER BY NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(sh.valor_bruto,''),'$',''),'.',''),',','.'),'')::numeric
        ))::numeric(10,4) AS valor
    FROM gennera_stg.servicos_historico sh
    WHERE sh.item IS NOT NULL
      AND TRIM(sh.item) <> ''
      -- só items que NÃO casam com nenhum padrão dos 4 fixos
      AND sh.item !~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
      AND sh.item !~* 'matr.cula'
      AND sh.item NOT ILIKE '%ANUID%'
      AND sh.item NOT ILIKE '%MENS%'
      AND sh.item NOT ILIKE '%ALIM%'
      AND sh.item NOT ILIKE '%MATERIAL%'
      AND sh.item NOT ILIKE '%MATERIAIS%'
      AND sh.item NOT ILIKE '%MAT%DIDAT%'
      AND sh.item NOT ILIKE '%MDIDAT%'
      AND sh.item NOT ILIKE '%MDIAT%'
      AND sh.item !~* '\mMD\M'
      AND sh.item !~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'
      -- só anos cobertos
      AND sh.calendario_academico >= '2021'
    GROUP BY LEFT(TRIM(sh.item), 60)
),
unificado AS (
    SELECT nome, valor FROM fixos
    UNION ALL
    SELECT nome, valor FROM variaveis
    UNION ALL
    SELECT nome, valor FROM servicos_historico_extras
    WHERE NOT EXISTS (
        SELECT 1 FROM variaveis v WHERE v.nome = servicos_historico_extras.nome
    )
)
SELECT
    1                                       AS "CODCOLIGADA",
    nome                                    AS "NOME",
    valor                                   AS "VALOR",
    1                                       AS "CODTIPOCURSO",
    1                                       AS "CODCOLCXA",
    '237'::varchar(10)                      AS "CODCXA",
    'N'::varchar(1)                         AS "VERIFICAINADIMPLENCIA",
    NULL::integer                           AS "TIPOCONTABILLAN",
    NULL::varchar(10)                       AS "CODTDO",
    1                                       AS "CODCOLNATFINANCEIRA",
    '111.111'::varchar(40)                  AS "NATFINANCEIRA",
    'N'::varchar(1)                         AS "PERMITEACORDO",
    NULL::varchar(1)                        AS "APROVEITACONTACORRENTE",
    NULL::varchar(1)                        AS "CONSIDERAPARCELAFIXA",
    NULL::varchar(1)                        AS "DISPONIVELEXTENSAO",
    NULL::varchar(1)                        AS "DESCONSIDERACREDITORETROATIVO",
    'S'::varchar(1)                         AS "PGCARTAODEBITO",
    'S'::varchar(1)                         AS "PGCARTAOCREDITO",
    NULL::varchar(1)                        AS "CONSIDERADESCANTECIPACAO"
FROM unificado
ORDER BY
    CASE nome
        WHEN '1ª mensalidade'    THEN 1
        WHEN 'Mensalidade'       THEN 2
        WHEN 'Material Didático' THEN 3
        WHEN 'Alimentação'       THEN 4
        ELSE 99
    END,
    nome;
