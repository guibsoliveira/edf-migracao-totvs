-- =====================================================================
-- export_v2.slan — Vínculo Acadêmico ↔ Financeiro
-- =====================================================================
-- SLAN é a ponte entre o lançamento financeiro (FLAN) e o registro
-- acadêmico do aluno (RA, contrato, serviço, parcela).
--
-- 1 linha por SPARCELA (mesma granularidade do FLAN).
-- Layout TOTVS RM (15 campos):
--   CODCOLIGADA, CODCURSO, CODHABILITACAO, CODGRADE, TURNO, CODFILIAL,
--   CODTIPOCURSO, RA, CODPERLET, CODCONTRATO, SERVICO, PARCELA, COTA,
--   NUMERODOCUMENTO (chave para FLAN), CODCOLCFO, CODCFO
-- =====================================================================

DROP VIEW IF EXISTS export_v2.slan CASCADE;

CREATE OR REPLACE VIEW export_v2.slan AS
SELECT
    1                                                                          AS "CODCOLIGADA",
    sp."CODCURSO",
    sp."CODHABILITACAO",
    sp."CODGRADE",
    sp."TURNO",
    sp."CODFILIAL",
    1                                                                          AS "CODTIPOCURSO",
    sp."RA",
    sp."CODPERLET",
    sp."CODCONTRATO",
    sp."SERVICO",
    sp."PARCELA",
    1                                                                          AS "COTA",
    -- NUMERODOCUMENTO igual ao do FLAN (chave de ligação)
    -- 8 chars (exigência TOTVS), sequencial determinístico
    LPAD(
        (ROW_NUMBER() OVER (
            ORDER BY sp."CODCONTRATO"::int, sp."DTCOMPETENCIA"::date,
                     sp."SERVICO", sp."PARCELA"
        ))::text, 8, '0'
    )::varchar(8)                                                              AS "NUMERODOCUMENTO",
    1                                                                          AS "CODCOLCFO",
    sp."CODCFO"
FROM export_v2.sparcela sp
WHERE sp."CODCFO" IS NOT NULL;
