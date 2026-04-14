-- 1) Etapas disponíveis
SELECT DISTINCT "CODETAPA", "DESCRICAO" FROM export.setapas ORDER BY "CODETAPA";

-- 2) Duplicatas (deve retornar 0)
SELECT COUNT(*) AS duplicatas FROM (
  SELECT "CODTURMA","CODDISC","CODPERLET","CODETAPA", COUNT(*) AS qtd
  FROM export.setapas GROUP BY 1,2,3,4 HAVING COUNT(*)>1
) sub;

-- 3) Amostra 1A/2024 (cada CODDISC deve ter exatamente 4 etapas)
SELECT "CODPERLET","CODTURMA","CODDISC","CODETAPA","DESCRICAO"
FROM export.setapas
WHERE "CODTURMA"='1A' AND "CODPERLET"='2024'
ORDER BY "CODDISC","CODETAPA" LIMIT 12;
