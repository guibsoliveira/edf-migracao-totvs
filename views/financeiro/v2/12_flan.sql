-- =====================================================================
-- export_v2.flan — Lançamentos financeiros (contas a receber)
-- =====================================================================
-- Formato compatível com a MACRO EXCEL da escola (16 colunas):
--   1. Código Cliente/Fornecedor (CODCFO 6 dígitos)
--   2. Numero Documento (único por lançamento — gerado determinístico)
--   3. Código Centro de Custo
--   4. Histórico (descrição do lançamento)
--   5. Data Vencimento
--   6. Data Emissão
--   7. Valor Original
--   8. Valor Juros (0)
--   9. Valor Desconto
--  10. Valor Multa (0)
--  11. Código da Conta Caixa (237 Bradesco)
--  12. Tipo de Documento (BOLETO)
--  13. Série Documento (@@@)
--  14. Pagar(2) ou Receber(1) — educacional sempre Receber=1
--  15. Código da Filial
--  16. Código Natureza Orçamentária Financeira (111.111)
--
-- 1 linha por parcela cobrada (= 1 linha por SPARCELA).
--
-- NUMERODOCUMENTO determinístico:
--   {idContract:8}{parcela:02}{tipo:3}{competencia:02}
--   ex: 00008488010MEN03 → contrato 8488, parcela 1, MENS, comp março
-- =====================================================================

DROP VIEW IF EXISTS export_v2.flan CASCADE;

CREATE OR REPLACE VIEW export_v2.flan AS
SELECT
    -- 1. Código Cliente/Fornecedor (já 6 dígitos)
    sp."CODCFO"                                                                AS "CODCFO",

    -- 2. Numero Documento (EXATAMENTE 8 chars — exigência TOTVS)
    --    Sequencial determinístico baseado em ordering estável de SPARCELA
    LPAD(
        (ROW_NUMBER() OVER (
            ORDER BY sp."CODCONTRATO"::int, sp."DTCOMPETENCIA"::date,
                     sp."SERVICO", sp."PARCELA"
        ))::text, 8, '0'
    )::varchar(8)                                                              AS "NUMERODOCUMENTO",

    -- 3. Código Centro de Custo
    '0000000001'::varchar(25)                                                  AS "CODCCUSTO",

    -- 4. Histórico
    LEFT(sp."SERVICO" || ' ' || TO_CHAR(sp."DTCOMPETENCIA"::date, 'MM/YYYY')
         || ' - RA ' || sp."RA", 255)::varchar(255)                            AS "HISTORICO",

    -- 5. Data Vencimento
    sp."DTVENCIMENTO"                                                          AS "DATAVENCIMENTO",

    -- 6. Data Emissão (= competência - 30 dias = boleto emitido mês anterior)
    TO_CHAR((sp."DTVENCIMENTO"::date - INTERVAL '30 days')::date, 'YYYY-MM-DD')::varchar(10)
                                                                               AS "DATAEMISSAO",

    -- 7. Valor Original (numérico, formato BR mantido text)
    REPLACE(sp."VALOR", ',', '.')::numeric(12,2)                               AS "VALOROPERACAO",

    -- 8. Valor Juros
    0::numeric(12,2)                                                           AS "VALORJUROS",

    -- 9. Valor Desconto
    REPLACE(COALESCE(sp."DESCONTO", '0,00'), ',', '.')::numeric(12,2)          AS "VALORDESCONTO",

    -- 10. Valor Multa
    0::numeric(12,2)                                                           AS "VALORMULTA",

    -- 11. Código da Conta Caixa (Bradesco)
    '237'::varchar(10)                                                         AS "CODCXA",

    -- 12. Tipo de Documento
    'BOLETO'::varchar(10)                                                      AS "CODTDO",

    -- 13. Série Documento
    '@@@'::varchar(8)                                                          AS "SERIEDOC",

    -- 14. Pagar(2)/Receber(1)
    1                                                                          AS "PAGREC",

    -- 15. Código da Filial
    sp."CODFILIAL"                                                             AS "CODFILIAL",

    -- 16. Código Natureza Orçamentária Financeira
    '111.111'::varchar(40)                                                     AS "NATFINANCEIRA",

    -- Campos extras úteis (não vão pro TXT mas ajudam debug)
    sp."RA"                                                                    AS "RA",
    sp."CODCONTRATO"                                                           AS "CODCONTRATO",
    sp."CODPERLET"                                                             AS "CODPERLET",
    sp."SERVICO"                                                               AS "SERVICO",
    sp."PARCELA"                                                               AS "PARCELA"
FROM export_v2.sparcela sp
WHERE sp."CODCFO" IS NOT NULL;
