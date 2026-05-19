-- =====================================================================
-- Double check completo cadeia financeira v2 (auditoria pré-FLAN/SLAN)
-- =====================================================================

\echo '=== A. Contagens ==='
SELECT 'sservico'       AS view, COUNT(*) FROM export_v2.sservico
UNION ALL SELECT 'splanopgto',     COUNT(*) FROM export_v2.splanopgto
UNION ALL SELECT 'sparcplano',     COUNT(*) FROM export_v2.sparcplano
UNION ALL SELECT 'shabmodelopgto', COUNT(*) FROM export_v2.shabmodelopgto
UNION ALL SELECT 'scontrato',      COUNT(*) FROM export_v2.scontrato
UNION ALL SELECT 'sparcela',       COUNT(*) FROM export_v2.sparcela
UNION ALL SELECT 'sbolsaaluno',    COUNT(*) FROM export_v2.sbolsaaluno;

\echo ''
\echo '=== B. FK orphans (deve ser 0 em tudo) ==='
SELECT 'sparcplano->sservico' AS check, COUNT(*) FROM export_v2.sparcplano sp
WHERE NOT EXISTS (SELECT 1 FROM export_v2.sservico s WHERE s."NOME"=sp."NOMESERVICO")
UNION ALL SELECT 'sparcplano->splanopgto', COUNT(*) FROM export_v2.sparcplano sp
WHERE NOT EXISTS (SELECT 1 FROM export_v2.splanopgto p WHERE p."CODPLANOPGTO"=sp."CODPLANOPGTO")
UNION ALL SELECT 'shabmodelopgto->splanopgto', COUNT(*) FROM export_v2.shabmodelopgto h
WHERE NOT EXISTS (SELECT 1 FROM export_v2.splanopgto p WHERE p."CODPLANOPGTO"=h."CODPLANOPGTO")
UNION ALL SELECT 'scontrato->splanopgto', COUNT(*) FROM export_v2.scontrato c
WHERE c."CODPLANOPGTO" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM export_v2.splanopgto p WHERE p."CODPLANOPGTO"=c."CODPLANOPGTO")
UNION ALL SELECT 'sparcela->sservico', COUNT(*) FROM export_v2.sparcela sp
WHERE NOT EXISTS (SELECT 1 FROM export_v2.sservico s WHERE s."NOME"=sp."SERVICO")
UNION ALL SELECT 'sparcela->scontrato', COUNT(*) FROM export_v2.sparcela sp
WHERE NOT EXISTS (SELECT 1 FROM export_v2.scontrato c WHERE c."CODCONTRATO"=sp."CODCONTRATO")
UNION ALL SELECT 'sparcela->fcfo', COUNT(*) FROM export_v2.sparcela sp
WHERE sp."CODCFO" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM export.fcfo f WHERE f."CODCFO"=sp."CODCFO")
UNION ALL SELECT 'sbolsaaluno->sservico', COUNT(*) FROM export_v2.sbolsaaluno sb
WHERE NOT EXISTS (SELECT 1 FROM export_v2.sservico s WHERE s."NOME"=sb."SERVICO")
UNION ALL SELECT 'sbolsaaluno->scontrato', COUNT(*) FROM export_v2.sbolsaaluno sb
WHERE NOT EXISTS (SELECT 1 FROM export_v2.scontrato c WHERE c."CODCONTRATO"=sb."CODCONTRATO")
UNION ALL SELECT 'sbolsaaluno->sbolsa', COUNT(*) FROM export_v2.sbolsaaluno sb
WHERE NOT EXISTS (SELECT 1 FROM export.sbolsa b WHERE b."NOME"=sb."NOMEBOLSA");

\echo ''
\echo '=== C. Contratos por ano (todos com CODPLANOPGTO) ==='
SELECT "CODPERLET", COUNT(*) AS total, COUNT("CODPLANOPGTO") AS com_plano
FROM export_v2.scontrato GROUP BY 1 ORDER BY 1;

\echo ''
\echo '=== D. SPARCPLANO: 37 parcelas por plano ==='
SELECT "CODPLANOPGTO", COUNT(*) AS parc
FROM export_v2.sparcplano GROUP BY 1 HAVING COUNT(*) != 37;

\echo ''
\echo '=== E. SPARCPLANO valores por plano (validação anual) ==='
SELECT "CODPLANOPGTO", SUM("VALOR")::numeric(12,2) AS anual
FROM export_v2.sparcplano GROUP BY 1 ORDER BY 1;

\echo ''
\echo '=== F. SPARCELA - parcelas por ano (filtrado NULL) ==='
SELECT "CODPERLET", COUNT(*) FROM export_v2.sparcela GROUP BY 1 ORDER BY 1;

\echo ''
\echo '=== G. SBOLSAALUNO - bolsas por ano ==='
SELECT "CODPERLET", COUNT(*) FROM export_v2.sbolsaaluno GROUP BY 1 ORDER BY 1;

\echo ''
\echo '=== H. Aluno teste 2024 - amostra ==='
SELECT c."RA", pf.name AS aluno, c."CODCURSO", c."CODHABILITACAO", c."CODFILIAL",
       COUNT(*) AS contratos, COUNT(DISTINCT c."CODPLANOPGTO") AS planos_distintos
FROM export_v2.scontrato c
JOIN gennera_stg.student_code_unico scu ON scu.code_unif = c."RA"
JOIN gennera_stg.person_fisica pf ON pf.id_person = scu.id_person
WHERE c."CODPERLET" = '2024'
GROUP BY 1,2,3,4,5
HAVING COUNT(*) >= 3
ORDER BY contratos DESC LIMIT 5;
