-- =====================================================================
-- export_v2.splanopgto — Planos de pagamento (2021-2026)
-- =====================================================================
-- Estratégia v2: derivar planos de (ano, filial, segmento canônico)
-- a partir das turmas reais (sturma). 1 plano por combinação distinta.
--
-- Segmentos canônicos:
--   UN1: EF1 3º/5º ANO | EF2 6º/9º ANO | EM 1º/3º ANO
--   UN2: EI INTEGRAL K1/K2 | EI INTEGRAL N2/N3
--        EI MEIO PERIODO K1/K2 | EI MEIO PERIODO N2/N3
--        EF1 1º ANO | EF1 2º ANO
--
-- Codificação CODPLANOPGTO: {AA}{F}{NNN}
--   211001 = 2021 UN1 plano 001
--   261006 = 2026 UN2 plano 006
-- =====================================================================

DROP VIEW IF EXISTS export_v2.splanopgto CASCADE;

CREATE OR REPLACE VIEW export_v2.splanopgto AS
WITH segmentos_base AS (
    SELECT DISTINCT
        e.academic_calendar AS ano,
        CASE inst.code WHEN 'un1' THEN 1 ELSE 2 END AS codfilial,
        CASE
            -- UN1 (filial 1)
            WHEN inst.code = 'un1' AND st."CODCURSO" = 'EF1' THEN 'EF1 3º / 5º ANO'
            WHEN inst.code = 'un1' AND st."CODCURSO" = 'EF2' THEN 'EF2 6º / 9º ANO'
            WHEN inst.code = 'un1' AND st."CODCURSO" = 'EM'  THEN 'EM 1º / 3º ANO'
            -- UN2 (filial 2) - EI
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" = 'Integral'
                 AND st."CODHABILITACAO"::int >= 3 THEN 'EI INTEGRAL K1, K2'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" = 'Integral'
                 AND st."CODHABILITACAO"::int <= 2 THEN 'EI INTEGRAL N2, N3'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" IN ('Manha','Tarde')
                 AND st."CODHABILITACAO"::int >= 3 THEN 'EI MEIO PERIODO K1, K2'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EI'
                 AND st."TURNO" IN ('Manha','Tarde')
                 AND st."CODHABILITACAO"::int <= 2 THEN 'EI MEIO PERIODO N2, N3'
            -- UN2 - EF1
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EF1'
                 AND st."CODHABILITACAO" = '1' THEN 'EF1 1º ANO'
            WHEN inst.code = 'un2' AND st."CODCURSO" = 'EF1'
                 AND st."CODHABILITACAO" = '2' THEN 'EF1 2º ANO'
        END AS segmento_nome
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
    JOIN export.sturma          st   ON st."CODTURMA"        = e.class_name
                                     AND st."CODPERLET"       = e.academic_calendar
    WHERE inst.code IN ('un1','un2')
      AND e.academic_calendar IS NOT NULL
      AND e.academic_calendar >= '2021'
),
-- distinct planos para evitar duplicar quando há múltiplas turmas no mesmo segmento
planos_distinct AS (
    SELECT DISTINCT ano, codfilial, segmento_nome
    FROM segmentos_base
    WHERE segmento_nome IS NOT NULL
),
-- adicionar 2026 vindo de items API (não existe em sturma local pois dump < 2026)
-- segmento canônico (mesma nomenclatura usada em sh-based)
planos_2026 AS (
    SELECT
        substring(ai.description from '^(\d{4})')::text AS ano,
        CASE WHEN ai.id_institution = 320 THEN 1 ELSE 2 END AS codfilial,
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
            WHEN ai.id_institution = 321 AND ai.description ~* '\m(1.{0,3}\s*ANO|FUND\s*1\s*-?\s*1)\M'  THEN 'EF1 1º ANO'
            WHEN ai.id_institution = 321 AND ai.description ~* '\m(2.{0,3}\s*ANO|FUND\s*1\s*-?\s*2)\M'  THEN 'EF1 2º ANO'
        END AS segmento_nome
    FROM gennera_stg.api_items ai
    WHERE ai.description ~ '^2026\s+MENS\s+'
      AND ai.description NOT ILIKE '%ANUID%'
      AND ai.description !~* '^2026\s+1\s*[º°.ª]?\s*MENS'
),
unificado AS (
    SELECT ano, codfilial, segmento_nome FROM planos_distinct
    UNION
    SELECT ano, codfilial, segmento_nome FROM planos_2026
),
ranked AS (
    SELECT u.*,
           ROW_NUMBER() OVER (PARTITION BY ano, codfilial ORDER BY segmento_nome) AS seq
    FROM unificado u
)
SELECT
    1                                                                AS "CODCOLIGADA",
    r.ano::varchar(10)                                               AS "CODPERLET",
    (RIGHT(r.ano, 2) || r.codfilial::text || LPAD(r.seq::text, 3, '0'))::varchar(10)
                                                                     AS "CODPLANOPGTO",
    LEFT(r.segmento_nome || ' ' || r.ano, 60)::varchar(60)           AS "DESCRICAO",
    LEFT(r.segmento_nome || ' ' || r.ano, 60)::varchar(60)           AS "NOME",
    (r.ano || '-01-01')::date                                        AS "DTINICIO",
    (r.ano || '-12-31')::date                                        AS "DTFIM",
    0::numeric(10,4)                                                 AS "DESCONTO",
    1                                                                AS "CODTIPOCURSO",
    r.codfilial                                                      AS "CODFILIAL",
    'N'::varchar(1)                                                  AS "MATRICULALIVRE",
    NULL::varchar(1)                                                 AS "TIPOBLOQUEIOVLRBASEPERSONALIZ"
FROM ranked r
ORDER BY r.ano, r.codfilial, r.seq;
