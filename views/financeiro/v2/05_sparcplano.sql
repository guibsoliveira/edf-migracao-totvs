-- =====================================================================
-- export_v2.sparcplano — Parcelas dos planos de pagamento (2021-2026)
-- =====================================================================
-- Para cada plano gera EXATAMENTE 37 parcelas:
--   1× '1ª mensalidade' (parcela 1)
--   12× 'Mensalidade'   (parcelas 1-12)
--   12× 'Alimentação'   (parcelas 1-12)
--   12× 'Material Didático' (parcelas 1-12)
--
-- Fonte de valor (priorizada):
--   1) API Gennera (gennera_stg.api_items) — assertiva, valor oficial
--   2) Histórico de cobrança (gennera_stg.servicos_historico) — fallback
--      para 2021-2022 ou casos onde API não tem
--
-- Mapping description → segmento canônico cobre as 4 variações de nome
-- usadas pelo financeiro ao longo dos anos (EM/F1/F2 → EF1/EF2/EM →
-- FUND 1 / FUND 2 / EM - 1º / 3º ANO).
-- =====================================================================

DROP VIEW IF EXISTS export_v2.sparcplano CASCADE;

CREATE OR REPLACE VIEW export_v2.sparcplano AS
WITH
-- 1. Planos com chave (ano, filial, segmento canônico)
planos AS (
    SELECT
        sp."CODCOLIGADA",
        sp."CODPERLET"::text AS ano,
        sp."CODPLANOPGTO",
        sp."CODFILIAL"::int  AS codfilial,
        regexp_replace(sp."NOME", '\s+\d{4}\s*$', '') AS segmento
    FROM export_v2.splanopgto sp
),
-- 2. Mapping items da API → (ano, filial, segmento, tipo_servico, valor_mensal)
api_norm AS (
    SELECT
        substring(ai.description from '^(\d{4})')::text AS ano,
        CASE WHEN ai.id_institution = 320 THEN 1 ELSE 2 END AS codfilial,
        -- segmento canônico (independente do formato textual do ano)
        CASE
            -- UN1
            WHEN ai.id_institution = 320 AND ai.description ~* '\m(EM|ENSINO\s*M.DIO)\M'      THEN 'EM 1º / 3º ANO'
            WHEN ai.id_institution = 320 AND ai.description ~* '\m(F2|EF2|FUND.*\s*2)\M'      THEN 'EF2 6º / 9º ANO'
            WHEN ai.id_institution = 320 AND ai.description ~* '\m(F1|EF1|FUND.*\s*1)\M'      THEN 'EF1 3º / 5º ANO'
            -- UN2
            WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*INTEGRAL\s*K1'           THEN 'EI INTEGRAL K1, K2'
            WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*INTEGRAL\s*N2'           THEN 'EI INTEGRAL N2, N3'
            WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*MEIO\s*PERIODO\s*K1'      THEN 'EI MEIO PERIODO K1, K2'
            WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*MEIO\s*PERIODO\s*N2'      THEN 'EI MEIO PERIODO N2, N3'
            -- UN2 antigos (sem distinção K1/K2 vs N2/N3) — não usados pois 2021-2025 UN2 só tem EF1
            WHEN ai.id_institution = 321 AND ai.description ~* '\m(1.{0,3}\s*ANO|FUND\s*1\s*-?\s*1)\M'  THEN 'EF1 1º ANO'
            WHEN ai.id_institution = 321 AND ai.description ~* '\m(2.{0,3}\s*ANO|FUND\s*1\s*-?\s*2)\M'  THEN 'EF1 2º ANO'
        END AS segmento,
        -- tipo_servico
        CASE
            WHEN ai.description ~* '^\d{4}\s+1\s*[º°.ª]?\s*(MENS|PARC|MEN)' THEN '1ª mensalidade'
            WHEN ai.description ~* '^\d{4}\s+(MENS|MENSALIDADE)\s' AND ai.description !~* 'ANUID' THEN 'Mensalidade'
            WHEN ai.description ~* '^\d{4}\s+ALIM(ENT)?'                    THEN 'Alimentação'
            WHEN ai.description ~* '^\d{4}\s+(MATERIA|MAT\s*DIDAT|MDIDAT|MDIAT|MD\s*\d|MAT\s+(EF|EM|F[12]))' THEN 'Material Didático'
        END AS tipo_servico,
        -- Valor mensal: 1ª mens já mensal; mens/alim/mat são ANUAIS (÷ 12)
        CASE
            WHEN ai.description ~* '^\d{4}\s+1\s*[º°.ª]?\s*(MENS|PARC|MEN)' THEN ai.price
            ELSE ai.price / 12
        END AS valor_mensal
    FROM gennera_stg.api_items ai
    WHERE ai.status = 'active'
      AND ai.description ~ '^\d{4}\s'
      AND ai.description NOT ILIKE '%ANUID%'
      -- só tipos que vão pra 4 fixos
      AND (ai.description ~* '^\d{4}\s+(1\s*[º°.ª]?\s*(MENS|PARC|MEN)|MENS|MENSALIDADE|ALIM(ENT)?|MATERIA|MAT\s*DIDAT|MDIDAT|MDIAT|MD\s*\d|MAT\s+(EF|EM|F[12]))')
),
-- agregar por chave (alguns items duplicam com preços diferentes — pegar mode)
api_chave AS (
    SELECT ano, codfilial, segmento, tipo_servico,
           (mode() WITHIN GROUP (ORDER BY valor_mensal))::numeric AS valor_mensal
    FROM api_norm
    WHERE segmento IS NOT NULL AND tipo_servico IS NOT NULL AND valor_mensal > 0
    GROUP BY ano, codfilial, segmento, tipo_servico
),
-- 3. Histórico de cobranças (fallback para 2021-2022 e gaps na API)
sh_norm AS (
    SELECT
        sh.calendario_academico AS ano,
        CASE inst.code WHEN 'un1' THEN 1 ELSE 2 END AS codfilial,
        CASE
            WHEN inst.code = 'un1' AND st."CODCURSO" = 'EF1' THEN 'EF1 3º / 5º ANO'
            WHEN inst.code = 'un1' AND st."CODCURSO" = 'EF2' THEN 'EF2 6º / 9º ANO'
            WHEN inst.code = 'un1' AND st."CODCURSO" = 'EM'  THEN 'EM 1º / 3º ANO'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" = 'Integral' AND st."CODHABILITACAO"::int >= 3 THEN 'EI INTEGRAL K1, K2'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" = 'Integral' AND st."CODHABILITACAO"::int <= 2 THEN 'EI INTEGRAL N2, N3'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" IN ('Manha','Tarde') AND st."CODHABILITACAO"::int >= 3 THEN 'EI MEIO PERIODO K1, K2'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" IN ('Manha','Tarde') AND st."CODHABILITACAO"::int <= 2 THEN 'EI MEIO PERIODO N2, N3'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EF1' AND st."CODHABILITACAO" = '1' THEN 'EF1 1º ANO'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EF1' AND st."CODHABILITACAO" = '2' THEN 'EF1 2º ANO'
        END AS segmento,
        CASE
            WHEN sh.item ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
                 AND sh.item !~* '^\s*(MENS|PARC)'           THEN '1ª mensalidade'
            WHEN sh.item ILIKE '%ANUID%'                      THEN NULL  -- ignora anuidades em fallback
            WHEN sh.item ILIKE '%MENS%'                       THEN 'Mensalidade'
            WHEN sh.item ILIKE '%ALIM%'                       THEN 'Alimentação'
            WHEN sh.item ILIKE '%MATERIAL%' OR sh.item ILIKE '%MATERIAIS%' OR sh.item ILIKE '%MAT%DIDAT%'
              OR sh.item ILIKE '%MDIDAT%'   OR sh.item ILIKE '%MDIAT%'
              OR sh.item ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'    OR sh.item ~* '\mMD\M' THEN 'Material Didático'
        END AS tipo_servico,
        NULLIF(REPLACE(REPLACE(REPLACE(COALESCE(sh.valor_bruto, ''), '$', ''),
                               '.', ''), ',', '.'), '')::numeric AS valor
    FROM gennera_stg.servicos_historico sh
    JOIN gennera_stg.person_fisica pf ON pf.name = sh.aluno
    JOIN gennera_stg.enrollment    e  ON e.id_person = pf.id_person
                                       AND e.academic_calendar = sh.calendario_academico
    JOIN gennera_stg.institution   inst ON inst.id_institution = e.id_institution
    JOIN export.sturma             st   ON st."CODTURMA"  = e.class_name
                                         AND st."CODPERLET" = e.academic_calendar
    WHERE sh.item IS NOT NULL
      AND sh.valor_bruto IS NOT NULL
      AND COALESCE(sh.status, '') NOT IN ('cancelado')
      AND inst.code IN ('un1','un2')
      AND sh.calendario_academico BETWEEN '2021' AND '2025'
),
sh_chave AS (
    SELECT ano, codfilial, segmento, tipo_servico,
           (mode() WITHIN GROUP (ORDER BY valor))::numeric AS valor_mensal
    FROM sh_norm
    WHERE segmento IS NOT NULL AND tipo_servico IS NOT NULL AND valor > 0
    GROUP BY ano, codfilial, segmento, tipo_servico
),
-- 4. Preço final: API tem prioridade, sh é fallback
preco_final AS (
    SELECT
        COALESCE(a.ano, h.ano)               AS ano,
        COALESCE(a.codfilial, h.codfilial)   AS codfilial,
        COALESCE(a.segmento, h.segmento)     AS segmento,
        COALESCE(a.tipo_servico, h.tipo_servico) AS tipo_servico,
        COALESCE(a.valor_mensal, h.valor_mensal) AS valor_mensal
    FROM api_chave a
    FULL OUTER JOIN sh_chave h
      ON h.ano = a.ano AND h.codfilial = a.codfilial
     AND h.segmento = a.segmento AND h.tipo_servico = a.tipo_servico
),
-- 5. Expandir cada plano em 37 parcelas
expandido AS (
    -- 1ª mensalidade (parcela 1 só)
    SELECT p."CODCOLIGADA", p.ano, p."CODPLANOPGTO", p.codfilial, p.segmento,
           '1ª mensalidade'::text AS tipo_servico, 1 AS parcela, pf.valor_mensal AS valor
    FROM planos p
    LEFT JOIN preco_final pf
      ON pf.ano = p.ano AND pf.codfilial = p.codfilial
     AND pf.segmento = p.segmento AND pf.tipo_servico = '1ª mensalidade'
    UNION ALL
    -- Mensalidade, Alimentação, Material (12 parcelas cada)
    SELECT p."CODCOLIGADA", p.ano, p."CODPLANOPGTO", p.codfilial, p.segmento,
           tp.tipo_servico, m AS parcela, pf.valor_mensal
    FROM planos p
    CROSS JOIN (VALUES ('Mensalidade'), ('Alimentação'), ('Material Didático')) tp(tipo_servico)
    CROSS JOIN generate_series(1, 12) m
    LEFT JOIN preco_final pf
      ON pf.ano = p.ano AND pf.codfilial = p.codfilial
     AND pf.segmento = p.segmento AND pf.tipo_servico = tp.tipo_servico
)
SELECT
    e."CODCOLIGADA",
    e.ano::varchar(10)                                  AS "CODPERLET",
    1                                                    AS "CODTIPOCURSO",
    e."CODPLANOPGTO",
    e.parcela                                            AS "PARCELA",
    1                                                    AS "COTA",
    LEFT(e.tipo_servico, 60)::varchar(60)                AS "NOMESERVICO",
    COALESCE(e.valor, 0)::numeric(10,4)                  AS "VALOR",
    MAKE_DATE(e.ano::int, e.parcela, 5)::date            AS "DTVENCIMENTO",
    0::numeric(10,4)                                     AS "DESCONTO",
    'V'::varchar(1)                                      AS "TIPODESC",
    'N'::varchar(1)                                      AS "VALORAUTOMATICO",
    MAKE_DATE(e.ano::int, e.parcela, 1)::date            AS "DTCOMPETENCIA",
    'P'::varchar(1)                                      AS "TIPOPARCELA",
    e.codfilial                                          AS "CODFILIAL",
    'N'::varchar(1)                                      AS "DTVENCIMENTOFLEXIVEL"
FROM expandido e
ORDER BY e."CODPLANOPGTO",
    CASE e.tipo_servico
        WHEN '1ª mensalidade'    THEN 1
        WHEN 'Mensalidade'       THEN 2
        WHEN 'Alimentação'       THEN 3
        WHEN 'Material Didático' THEN 4
    END,
    e.parcela;
