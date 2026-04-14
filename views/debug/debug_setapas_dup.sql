-- Quantas vezes CODDISC=17 aparece para 1A (sem filtro de ano)
SELECT "CODPERLET","CODTURMA","CODDISC","CODETAPA","DESCRICAO"
FROM export.setapas
WHERE "CODTURMA"='1A' AND "CODDISC"=17
ORDER BY "CODPERLET","CODETAPA";

-- Contagem por (CODTURMA, CODDISC) sem filtrar ano
SELECT "CODTURMA", "CODDISC", COUNT(*) AS total_linhas, COUNT(DISTINCT "CODPERLET") AS anos_distintos
FROM export.setapas
WHERE "CODTURMA"='1A'
GROUP BY "CODTURMA","CODDISC"
ORDER BY total_linhas DESC
LIMIT 10;
