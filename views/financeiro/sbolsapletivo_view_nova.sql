-- =============================================================
-- VIEW: export.sbolsapletivo
-- Template TOTVS RM — Disponibilidade Bolsa × Período Letivo × Filial
--
-- Fonte: export.sbolsa (catálogo canônico) × CROSS JOIN períodos × filiais
--
-- Semântica: sbolsapletivo representa o CADASTRO de quais bolsas
-- estão disponíveis para uso em cada período/filial — e não o
-- histórico de aplicação. Por isso o cross join: toda bolsa do
-- catálogo deve estar disponível em todos os anos e ambas filiais.
--
-- Template oficial (5 colunas, todas obrigatórias):
--   CODCOLIGADA   INTEIRO
--   CODTIPOCURSO  INTEIRO   (1 = educação básica)
--   CODFILIAL     INTEIRO   (1 = Unidade 1, 2 = Unidade 2)
--   CODPERLET     TEXTO(10) (ano letivo — FK para SPLETIVO)
--   NOMEBOLSA     TEXTO(60) (FK para SBOLSA.NOME)
--
-- Períodos são extraídos dinamicamente de bolsas_descontos (>=2021)
-- para que novos anos entrem automaticamente no catálogo.
-- =============================================================

CREATE OR REPLACE VIEW export.sbolsapletivo AS
WITH periodos AS (
    SELECT DISTINCT
        COALESCE(
            NULLIF(TRIM(bd.calendario_academico), ''),
            NULLIF(TRIM(bd.fatura_ano), '')
        ) AS codperlet
    FROM gennera_stg.bolsas_descontos bd
    WHERE COALESCE(
              NULLIF(TRIM(bd.calendario_academico), ''),
              NULLIF(TRIM(bd.fatura_ano), '')
          ) >= '2021'
),
filiais AS (
    SELECT 1 AS codfilial
    UNION ALL
    SELECT 2
)
SELECT
    1                                             AS "CODCOLIGADA",
    1                                             AS "CODTIPOCURSO",
    f.codfilial                                   AS "CODFILIAL",
    p.codperlet::character varying(10)            AS "CODPERLET",
    sb."NOME"                                     AS "NOMEBOLSA"
FROM export.sbolsa sb
CROSS JOIN filiais f
CROSS JOIN periodos p
ORDER BY 3, 4, 5;
