-- =====================================================================
-- export_v2.fcfo — Cli/For com CODCFO normalizado para 6 dígitos
-- =====================================================================
-- TOTVS armazena CODCFO com zero-padding a 6 dígitos. Esta view
-- garante consistência com export_v2.sparcela.CODCFO (LPAD aplicado).
-- =====================================================================

DROP VIEW IF EXISTS export_v2.fcfo CASCADE;

CREATE OR REPLACE VIEW export_v2.fcfo AS
SELECT
    f.*,
    LPAD(f."CODCFO", 6, '0')::varchar(25) AS "CODCFO_6"
FROM export.fcfo f;
