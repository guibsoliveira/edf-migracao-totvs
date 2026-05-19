-- =====================================================================
-- export_v2.shabmodelopgto — Plano × Habilitação × Turno
-- =====================================================================
-- Liga cada SPLANOPGTO às combinações (curso, série, grade, turno) que
-- ele cobre. Usa nomes dos planos v2 (vindos da API Gennera).
--
-- Regras de turno EDF:
--   UN1 (Filial 1): tudo Integral
--   UN2 (Filial 2): EF1/EF2/EM = Integral; EI segue modalidade do plano:
--       Plano "EI INTEGRAL ..."     → Integral
--       Plano "EI MEIO PERIODO ..." → Manhã + Tarde
--
-- Mapeamento habilitação por plano v2 (nome):
--   "EM - 1º / 3º ANO"      → hab 1-3 (EM)
--   "FUND 1 - 3º / 5º ANO"  → hab 3-5 (EF1)
--   "FUND 1 - 1º ANO"       → hab 1 (EF1)
--   "FUND 1 - 2º ANO"       → hab 2 (EF1)
--   "FUND 2 - 6º / 9º ANO"  → hab 6-9 (EF2)
--   "EI ... K1, K2"         → hab 3-4 (K1=3, K2=4)
--   "EI ... N2, N3"         → hab 1-2 (N2=1, N3=2)
-- =====================================================================

DROP VIEW IF EXISTS export_v2.shabmodelopgto CASCADE;

CREATE OR REPLACE VIEW export_v2.shabmodelopgto AS
WITH plan_parsed AS (
    SELECT
        sp."CODCOLIGADA",
        sp."CODPERLET",
        sp."CODPLANOPGTO",
        sp."CODTIPOCURSO",
        sp."CODFILIAL",
        sp."NOME",
        -- ── CODCURSO ── (nomes canônicos: EI, EM, EF1, EF2)
        CASE
            WHEN sp."NOME" ILIKE 'EI %'   THEN 'EI'
            WHEN sp."NOME" ILIKE 'EM %'   THEN 'EM'
            WHEN sp."NOME" ILIKE 'EF1 %'  THEN 'EF1'
            WHEN sp."NOME" ILIKE 'EF2 %'  THEN 'EF2'
        END AS codcurso,
        -- ── HAB START ──
        CASE
            WHEN sp."NOME" ILIKE 'EI %K1%'           THEN 3
            WHEN sp."NOME" ILIKE 'EI %N2%'           THEN 1
            WHEN sp."NOME" ILIKE 'EM %1º%/%3º%'      THEN 1
            WHEN sp."NOME" ILIKE 'EF1 %3º%/%5º%'     THEN 3
            WHEN sp."NOME" ILIKE 'EF1 %1º ANO%'      THEN 1
            WHEN sp."NOME" ILIKE 'EF1 %2º ANO%'      THEN 2
            WHEN sp."NOME" ILIKE 'EF2 %6º%/%9º%'     THEN 6
        END AS hab_start,
        -- ── HAB END ──
        CASE
            WHEN sp."NOME" ILIKE 'EI %K1%'           THEN 4
            WHEN sp."NOME" ILIKE 'EI %N2%'           THEN 2
            WHEN sp."NOME" ILIKE 'EM %1º%/%3º%'      THEN 3
            WHEN sp."NOME" ILIKE 'EF1 %3º%/%5º%'     THEN 5
            WHEN sp."NOME" ILIKE 'EF1 %1º ANO%'      THEN 1
            WHEN sp."NOME" ILIKE 'EF1 %2º ANO%'      THEN 2
            WHEN sp."NOME" ILIKE 'EF2 %6º%/%9º%'     THEN 9
        END AS hab_end,
        -- ── TIPO DE TURNO ──
        CASE
            WHEN sp."CODFILIAL" = 1                      THEN 'INTEGRAL'
            WHEN sp."NOME" ILIKE 'EI%MEIO%'              THEN 'MEIO'
            ELSE                                              'INTEGRAL'
        END AS turno_tipo
    FROM export_v2.splanopgto sp
),
turnos(turno) AS (
    VALUES ('Integral'), ('Manha'), ('Tarde')
),
expanded AS (
    SELECT
        pp."CODCOLIGADA",
        pp."CODPERLET",
        pp."CODPLANOPGTO",
        pp."CODTIPOCURSO",
        pp.codcurso,
        h."CODHABILITACAO",
        t.turno,
        pp."CODFILIAL"
    FROM plan_parsed pp
    JOIN export.shabilitacao h
      ON h."CODCURSO" = pp.codcurso
     AND h."CODHABILITACAO"::integer >= pp.hab_start
     AND h."CODHABILITACAO"::integer <= pp.hab_end
    JOIN turnos t
      ON (pp.turno_tipo = 'INTEGRAL' AND t.turno = 'Integral')
      OR (pp.turno_tipo = 'MEIO'     AND t.turno IN ('Manha','Tarde'))
    WHERE pp.codcurso IS NOT NULL
      -- Regras EDF:
      --   UN1: SEM EI, SEM EF1 1º-2º
      --   UN2: SEM EF2/EM, SEM EF1 3º-5º
      AND NOT (pp."CODFILIAL" = 1 AND pp.codcurso = 'EI')
      AND NOT (pp."CODFILIAL" = 1 AND pp.codcurso = 'EF1' AND h."CODHABILITACAO"::integer < 3)
      AND NOT (pp."CODFILIAL" = 2 AND pp.codcurso IN ('EF2','EM'))
      AND NOT (pp."CODFILIAL" = 2 AND pp.codcurso = 'EF1' AND h."CODHABILITACAO"::integer > 2)
)
SELECT
    e."CODCOLIGADA",
    e."CODPERLET"::varchar(10)                  AS "IDPERLET",
    e."CODPLANOPGTO"::varchar(10),
    e."CODTIPOCURSO",
    e.codcurso::varchar(10)                     AS "CODCURSO",
    e."CODHABILITACAO"::varchar(10)             AS "IDHABILITACAOFILIAL",
    COALESCE(g.codgrade, e."CODPERLET")::varchar(10) AS "CODGRADE",
    e.turno::varchar(15)                        AS "CODTURNO",
    e."CODFILIAL"
FROM expanded e
LEFT JOIN export.sgrade g
       ON g.codcurso = e.codcurso
      AND g.codhabilitacao::text = e."CODHABILITACAO"::text
      AND g.codgrade = e."CODPERLET"
ORDER BY e."CODPERLET", e."CODFILIAL", e."CODPLANOPGTO",
         e."CODHABILITACAO", e.turno;
