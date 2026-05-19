-- =====================================================================
-- Health check completo da cadeia financeira v2
-- Simula validação que o TOTVS faria durante importação em cascata
-- =====================================================================

\echo '=== 1. Contagens ==='
SELECT 'sservico v2'                AS view, COUNT(*) FROM export_v2.sservico
UNION ALL SELECT 'splanopgto v2',          COUNT(*) FROM export_v2.splanopgto
UNION ALL SELECT 'sparcplano v2',          COUNT(*) FROM export_v2.sparcplano
UNION ALL SELECT 'shabmodelopgto v2',      COUNT(*) FROM export_v2.shabmodelopgto
UNION ALL SELECT 'scontrato v2',           COUNT(*) FROM export_v2.scontrato
UNION ALL SELECT 'sparcela v2',            COUNT(*) FROM export_v2.sparcela
UNION ALL SELECT 'sbolsaaluno v2',         COUNT(*) FROM export_v2.sbolsaaluno;

\echo ''
\echo '=== 2. FK orphans SPARCPLANO -> SSERVICO (NOMESERVICO) ==='
SELECT COUNT(*) AS orphan
FROM export_v2.sparcplano sp
WHERE NOT EXISTS (
    SELECT 1 FROM export_v2.sservico s WHERE s."NOME" = sp."NOMESERVICO"
);

\echo ''
\echo '=== 3. FK orphans SPARCPLANO -> SPLANOPGTO ==='
SELECT COUNT(*) AS orphan
FROM export_v2.sparcplano sp
WHERE NOT EXISTS (
    SELECT 1 FROM export_v2.splanopgto p WHERE p."CODPLANOPGTO" = sp."CODPLANOPGTO"
);

\echo ''
\echo '=== 4. FK orphans SHABMODELOPGTO -> SPLANOPGTO ==='
SELECT COUNT(*) AS orphan
FROM export_v2.shabmodelopgto h
WHERE NOT EXISTS (
    SELECT 1 FROM export_v2.splanopgto p WHERE p."CODPLANOPGTO" = h."CODPLANOPGTO"
);

\echo ''
\echo '=== 5. FK orphans SCONTRATO -> SPLANOPGTO (apenas quando preenchido) ==='
SELECT COUNT(*) AS orphan
FROM export_v2.scontrato c
WHERE c."CODPLANOPGTO" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM export_v2.splanopgto p WHERE p."CODPLANOPGTO" = c."CODPLANOPGTO"
  );

\echo ''
\echo '=== 6. FK orphans SPARCELA -> SSERVICO ==='
SELECT COUNT(*) AS orphan
FROM export_v2.sparcela sp
WHERE NOT EXISTS (
    SELECT 1 FROM export_v2.sservico s WHERE s."NOME" = sp."SERVICO"
);

\echo ''
\echo '=== 7. FK orphans SPARCELA -> SCONTRATO ==='
SELECT COUNT(*) AS orphan
FROM export_v2.sparcela sp
WHERE sp."CODCONTRATO" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM export_v2.scontrato c WHERE c."CODCONTRATO" = sp."CODCONTRATO"
  );

\echo ''
\echo '=== 8. FK orphans SBOLSAALUNO -> SSERVICO ==='
SELECT COUNT(*) AS orphan
FROM export_v2.sbolsaaluno sb
WHERE NOT EXISTS (
    SELECT 1 FROM export_v2.sservico s WHERE s."NOME" = sb."SERVICO"
);

\echo ''
\echo '=== 9. FK orphans SBOLSAALUNO -> SCONTRATO ==='
SELECT COUNT(*) AS orphan
FROM export_v2.sbolsaaluno sb
WHERE NOT EXISTS (
    SELECT 1 FROM export_v2.scontrato c WHERE c."CODCONTRATO" = sb."CODCONTRATO"
);

\echo ''
\echo '=== 10. SPARCPLANO valor anual por plano (deve bater planilha) ==='
SELECT
    sp."CODPLANOPGTO",
    p."NOME"                                                       AS plano,
    SUM(sp."VALOR") FILTER (WHERE sp."NOMESERVICO"='Mensalidade')  AS mens_anual,
    SUM(sp."VALOR") FILTER (WHERE sp."NOMESERVICO"='Alimentação')  AS alim_anual,
    SUM(sp."VALOR") FILTER (WHERE sp."NOMESERVICO"='Material Didático') AS mat_anual,
    SUM(sp."VALOR") FILTER (WHERE sp."NOMESERVICO"='1ª mensalidade') AS prim_mens,
    SUM(sp."VALOR")::numeric(12,2)                                  AS total_anual
FROM export_v2.sparcplano sp
JOIN export_v2.splanopgto p ON p."CODPLANOPGTO" = sp."CODPLANOPGTO"
GROUP BY sp."CODPLANOPGTO", p."NOME"
ORDER BY sp."CODPLANOPGTO";
