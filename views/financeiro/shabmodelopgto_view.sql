-- =====================================================================
-- export.shabmodelopgto  —  Modelo de pagamento por habilitação
-- =====================================================================
-- Liga cada plano de pagamento (SPLANOPGTO) às combinações
-- curso/série/grade/turno a que se aplica.
--
-- Integridade referencial:
--   CODPLANOPGTO  → export.splanopgto
--   CODPERLET     → export.spletivo
--   CODCURSO      → export.scurso
--   CODHABILITACAO→ export.shabilitacao
--   CODGRADE      → export.sgrade
--
-- Regras de turno:
--   UN1 (Filial 1): sempre Integral
--   UN2 (Filial 2): EF1/EF2/EM = Integral
--                    EI = Integral | Manhã | Tarde conforme segmento
--     - Planos "EI INTEGRAL" → Integral
--     - Planos "EI MEIO PERIODO" / "1/2" → Manhã + Tarde
-- =====================================================================

DROP VIEW IF EXISTS export.shabmodelopgto CASCADE;

CREATE OR REPLACE VIEW export.shabmodelopgto AS
WITH
-- ─── 1. Extrair curso, range de hab e tipo de turno de cada plano ────
plan_parsed AS (
    SELECT
        sp."CODCOLIGADA",
        sp."IDPERLET",
        sp."CODPLANOPGTO",
        sp."CODTIPOCURSO",
        sp."CODFILIAL",
        TRIM(regexp_replace(sp."NOME",
            '\s+' || sp."IDPERLET" || '\s*$', '')) AS seg,

        -- ── CODCURSO ──
        CASE
            WHEN sp."NOME" ~* 'INFANTIL' THEN 'EI'
            WHEN sp."NOME" ~* '(^|\s)(EI)(\s|$)'  THEN 'EI'
            WHEN sp."NOME" ~* '(^|\s)(INT|INTEGRAL|1/2|MEIO)(\s|$)'
                 AND sp."NOME" !~* '(FUND|FUNDAMENTAL|EF[12]|EM|MEDIO)' THEN 'EI'
            WHEN sp."NOME" ~* '(FUNDAMENTAL\s*(I\s|1)|FUND\s*1)' THEN 'EF1'
            WHEN sp."NOME" ~* '(^|\s)(EF1|F1)(\s|$)' THEN 'EF1'
            WHEN sp."NOME" ~* '(FUNDAMENTAL\s*(II|2)|FUND\s*2)' THEN 'EF2'
            WHEN sp."NOME" ~* '(^|\s)(EF2|F2)(\s|$)' THEN 'EF2'
            WHEN sp."NOME" ~* '(M.DIO)' THEN 'EM'
            WHEN sp."NOME" ~* '(^|\s)EM(\s|$|-)' THEN 'EM'
            -- fallback por faixa numérica
            WHEN sp."NOME" ~ '3.{0,5}5' AND sp."NOME" !~ '[6-9]' THEN 'EF1'
            WHEN sp."NOME" ~ '6.{0,5}9' THEN 'EF2'
            WHEN sp."NOME" ~ '1.{0,3}EM' THEN 'EM'
            WHEN sp."NOME" ~ '(1|2).{0,3}ANO' THEN 'EF1'
        END AS codcurso,

        -- ── HAB RANGE START ──
        CASE
            -- EI: K1/K2 → hab 3-4; N2/N3 → hab 1-2
            WHEN sp."NOME" ~* 'K[12]' AND sp."NOME" !~* 'N[23]' THEN 3
            WHEN sp."NOME" ~* 'N[23]' AND sp."NOME" !~* 'K[12]' THEN 1
            -- EI genérico (cobre tudo)
            WHEN sp."NOME" ~* '(INFANTIL|(\s|^)EI(\s|$))' THEN 1
            WHEN sp."NOME" ~* '(^|\s)(INT|INTEGRAL|1/2|MEIO)(\s|$)'
                 AND sp."NOME" !~* '(FUND|EF|EM|MEDIO)' THEN 1
            -- EF1 específico
            WHEN sp."NOME" ~ '1.{0,3}ANO' AND sp."NOME" ~* '(FUND|EF1|F1)' THEN 1
            WHEN sp."NOME" ~ '2.{0,3}ANO' AND sp."NOME" ~* '(FUND|EF1|F1)' THEN 2
            WHEN sp."NOME" ~ '1.{0,3}(e|E).{0,3}2' AND sp."NOME" ~* '(FUND|EF1|F1)' THEN 1
            -- Ranges numéricos
            WHEN sp."NOME" ~ '3.{0,5}5' AND sp."NOME" !~ '[6-9]' THEN 3
            WHEN sp."NOME" ~ '6.{0,5}9' THEN 6
            WHEN sp."NOME" ~ '1.{0,5}3.{0,3}(ANO|EM|S)' AND sp."NOME" ~* '(EM|MEDIO)' THEN 1
            -- Sem range especificado → NULL = todas do curso
            ELSE NULL
        END AS hab_start,

        -- ── HAB RANGE END ──
        CASE
            WHEN sp."NOME" ~* 'K[12]' AND sp."NOME" !~* 'N[23]' THEN 4
            WHEN sp."NOME" ~* 'N[23]' AND sp."NOME" !~* 'K[12]' THEN 2
            WHEN sp."NOME" ~* '(INFANTIL|(\s|^)EI(\s|$))' THEN 4
            WHEN sp."NOME" ~* '(^|\s)(INT|INTEGRAL|1/2|MEIO)(\s|$)'
                 AND sp."NOME" !~* '(FUND|EF|EM|MEDIO)' THEN 4
            WHEN sp."NOME" ~ '1.{0,3}ANO' AND sp."NOME" ~* '(FUND|EF1|F1)' THEN 1
            WHEN sp."NOME" ~ '2.{0,3}ANO' AND sp."NOME" ~* '(FUND|EF1|F1)' THEN 2
            WHEN sp."NOME" ~ '1.{0,3}(e|E).{0,3}2' AND sp."NOME" ~* '(FUND|EF1|F1)' THEN 2
            WHEN sp."NOME" ~ '3.{0,5}5' AND sp."NOME" !~ '[6-9]' THEN 5
            WHEN sp."NOME" ~ '6.{0,5}9' THEN 9
            WHEN sp."NOME" ~ '1.{0,5}3.{0,3}(ANO|EM|S)' AND sp."NOME" ~* '(EM|MEDIO)' THEN 3
            ELSE NULL
        END AS hab_end,

        -- ── TIPO DE TURNO ──
        CASE
            -- Filial 1: TUDO Integral
            WHEN sp."CODFILIAL" = 1 THEN 'INTEGRAL'
            -- Filial 2: EI diferencia
            WHEN sp."NOME" ~* '(INFANTIL|(\s|^)EI(\s|$))' AND sp."NOME" ~* 'INTEGRAL' THEN 'INTEGRAL'
            WHEN sp."NOME" ~* '(INFANTIL|(\s|^)EI(\s|$))' AND sp."NOME" ~* '(MEIO|1/2)' THEN 'MEIO'
            WHEN sp."NOME" ~* '(^|\s)(INT|INTEGRAL)(\s|$)' AND sp."NOME" !~* '(FUND|EF|EM)' THEN 'INTEGRAL'
            WHEN sp."NOME" ~* '(^|\s)(1/2|MEIO)(\s|$)' AND sp."NOME" !~* '(FUND|EF|EM)' THEN 'MEIO'
            ELSE 'INTEGRAL'
        END AS turno_tipo

    FROM export.splanopgto sp
),

-- ─── 2. Turnos disponíveis ──────────────────────────────────────────
turnos(turno) AS (
    VALUES ('Integral'), ('Manhã'), ('Tarde')
),

-- ─── 3. Expansão: cada plano × habilitações × turno(s) ─────────────
expanded AS (
    SELECT
        pp."CODCOLIGADA",
        pp."IDPERLET",
        pp."CODPLANOPGTO",
        pp."CODTIPOCURSO",
        pp.codcurso,
        h."CODHABILITACAO",
        t.turno,
        pp."CODFILIAL"
    FROM plan_parsed pp
    JOIN export.shabilitacao h
        ON h."CODCURSO" = pp.codcurso
        AND (pp.hab_start IS NULL
             OR (h."CODHABILITACAO"::integer >= pp.hab_start
                 AND h."CODHABILITACAO"::integer <= pp.hab_end))
    JOIN turnos t ON
        (pp.turno_tipo = 'INTEGRAL' AND t.turno = 'Integral')
        OR (pp.turno_tipo = 'MEIO' AND t.turno IN ('Manhã', 'Tarde'))
    WHERE pp.codcurso IS NOT NULL
)

-- ─── SELECT FINAL ───────────────────────────────────────────────────
SELECT
    e."CODCOLIGADA",
    e."IDPERLET"::character varying(10)            AS "IDPERLET",
    e."CODPLANOPGTO"::character varying(10)        AS "CODPLANOPGTO",
    e."CODTIPOCURSO",
    e.codcurso::character varying(10)              AS "CODCURSO",
    e."CODHABILITACAO"::character varying(10)      AS "CODHABILITACAO",
    g.codgrade::character varying(10)              AS "CODGRADE",
    e.turno::character varying(15)                 AS "TURNO",
    e."CODFILIAL"
FROM expanded e
JOIN export.sgrade g
    ON g.codcurso = e.codcurso
    AND g.codhabilitacao::text = e."CODHABILITACAO"::text
    AND g.codgrade = e."IDPERLET"
ORDER BY e."IDPERLET", e."CODFILIAL", e."CODPLANOPGTO",
         e."CODHABILITACAO", e.turno;
