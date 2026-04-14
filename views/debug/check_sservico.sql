-- Verificar os dois casos problemáticos
SELECT "NOME", "VALOR"
FROM export.sservico
WHERE "NOME" ILIKE '%anuidade%fundamental 2%'
   OR "NOME" ILIKE '%1%mensalidade%médio%'
ORDER BY "NOME";

-- Total de itens
SELECT COUNT(*) AS total FROM export.sservico;

-- Duplicatas
SELECT "NOME", COUNT(*) FROM export.sservico GROUP BY "NOME" HAVING COUNT(*) > 1;

-- Amostra geral
SELECT "NOME", "VALOR" FROM export.sservico ORDER BY "NOME" LIMIT 20;
