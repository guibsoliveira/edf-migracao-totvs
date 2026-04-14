-- =====================================================================
-- export.splanopgto  —  Planos de pagamento de mensalidades
-- =====================================================================
-- Contexto de negócio (Escola do Futuro / Gennera):
--   O Gennera NÃO possui cadastro explícito de "plano de pagamento".
--   Os planos existem apenas como agrupamentos implícitos no campo
--   `item` de gennera_stg.servicos_historico. Esta view DERIVA o
--   catálogo de planos extraindo o "segmento" do nome do item
--   (removendo prefixo de ano e tipo de cobrança) e agrupando por
--   ano letivo (calendario_academico) × filial.
--
-- Semântica dos tipos de cobrança no Gennera:
--   • 1ºPARC / 1ºMENS ....... rematrícula ou matrícula do aluno
--                             (primeira parcela do ciclo)
--   • MENS / MENSALIDADE .... mensalidade regular
--                             (ÚNICO item dedutível no IR)
--   • ANUID / ANUIDADE ...... mensalidade paga em parcela única anual
--   • MATERIAIS / MAT DIDAT
--     MDIDAT / MDIAT / MD .. material didático (valor separado,
--                             integrado ao contrato/boleto único)
--   • ALIMENTAÇÃO ........... alimentação (valor separado,
--                             integrado ao contrato/boleto único)
--
--   Os itens MENS + MAT + ALIM + ANUID compõem um CONTRATO/BOLETO
--   ÚNICO por aluno, cada um com seu valor individual. Apenas a
--   parcela MENS é dedutível no imposto de renda.
--
-- Estratégia de extração:
--   1. Filtra itens recorrentes do ciclo letivo (MENS/ALIM/MAT/ANUID/PARC)
--   2. Descarta "poluição cruzada" (itens cujo ano no nome diverge
--      do calendario_academico)
--   3. Remove prefixo de ano ("2025 ", "2026 "...)
--   4. Remove iterativamente o(s) tipo(s) de cobrança (2 passes
--      para cobrir casos como "ANUIDADE MENSALIDADE")
--   5. Remove sufixo " UN1"/" UN2" (indicador de unidade histórico)
--   6. Normaliza espaços — o que sobra é o SEGMENTO DO PLANO
--      (ex.: "FUND 1 - 3º / 5º ANO", "EM - 1º / 3º ANO")
--   7. Descarta ruído (segmentos vazios, curtos demais ou bogus)
--   8. Deduplica por forma normalizada (UPPER + espaços colapsados)
--   9. CROSS JOIN com as 2 filiais (planos disponíveis em ambas)
--
-- Convenções de nomenclatura:
--   • NOME         = "{SEGMENTO} {ANO}"                  (max 60)
--   • DESCRICAO    = "Plano {SEGMENTO} {ANO} - Filial N"  (max 60)
--   • CODPLANOPGTO = "{AA}{F}{NNN}"                       (6 chars)
--                    AA  = 2 últimos dígitos do ano
--                    F   = código da filial (1 ou 2)
--                    NNN = sequencial do plano dentro do (ano, filial)
--   • DTINICIO / DTFIM = 01/01 a 31/12 do ano
--   • DESCONTO     = 0  (Gennera não tem desconto por plano)
--   • CODTIPOCURSO = 1  (SPLETIVO usa sempre 1 na Escola do Futuro)
--   • MATRICULALIVRE = 'N'
--
-- NOTA sobre anos históricos (2021-2024):
--   A base Gennera tinha nomenclatura inconsistente antes de 2025.
--   Os segmentos extraídos refletem essa heterogeneidade histórica
--   (variações como "F1"/"EF1"/"ENSINO FUNDAMENTAL 1"). Isso é
--   INTENCIONAL para preservar rastreabilidade 1:1 com contratos
--   existentes. A partir de 2025 o catálogo ficou uniforme.
-- =====================================================================

DROP VIEW IF EXISTS export.splanopgto CASCADE;

CREATE OR REPLACE VIEW export.splanopgto AS
WITH base_itens AS (
    -- 1. Filtra itens recorrentes e descarta poluição cruzada de ano
    SELECT
        sh.calendario_academico AS ano,
        sh.item
    FROM gennera_stg.servicos_historico sh
    WHERE sh.calendario_academico IS NOT NULL
      AND TRIM(sh.calendario_academico) <> ''
      AND sh.calendario_academico >= '2021'
      AND sh.item IS NOT NULL
      AND TRIM(sh.item) <> ''
      AND sh.item ~* '(MENS|MENSALIDADE|ALIMENTA|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUID|1\S{0,3}\s*PARC)'
      -- descarta itens de outro ano bleeding into este calendario
      AND NOT (sh.item ~ '^20[0-9]{2}\s' AND SUBSTRING(sh.item FROM '^(20[0-9]{2})') <> sh.calendario_academico)
),
pass1 AS (
    -- 2. Remove prefixo de ano
    SELECT ano,
           regexp_replace(item, '^20[0-9]{2}\s*', '', 'g') AS txt
    FROM base_itens
),
pass2 AS (
    -- 3. Primeira passada: remove 1 tipo de cobrança no início
    --    (usa \s* para capturar também itens que são somente o tipo,
    --     que depois serão descartados como segmento vazio)
    SELECT ano,
           regexp_replace(
               txt,
               '^(1\S{0,3}\s*MENSALIDADE|1\S{0,3}\s*MENS|1\S{0,3}\s*PARC|MENSALIDADE|MENS|ALIMENTA\S*|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE|ANUID\S*|MAT)\s*',
               '',
               'g'
           ) AS txt
    FROM pass1
),
pass3 AS (
    -- 4. Segunda passada: captura casos tipo "ANUIDADE MENSALIDADE"
    SELECT ano,
           regexp_replace(
               txt,
               '^(1\S{0,3}\s*MENSALIDADE|1\S{0,3}\s*MENS|1\S{0,3}\s*PARC|MENSALIDADE|MENS|ALIMENTA\S*|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE|ANUID\S*|MAT)\s*',
               '',
               'g'
           ) AS txt
    FROM pass2
),
pass4 AS (
    -- 5. Remove sufixo " UN1"/" UN2" (indicador de unidade histórico)
    SELECT ano,
           regexp_replace(txt, '\s+UN[12]\s*$', '', 'g') AS txt
    FROM pass3
),
pass5 AS (
    -- 6. Normaliza espaços e vírgulas
    SELECT ano,
           TRIM(
               regexp_replace(
                   regexp_replace(txt, '\s+,', ',', 'g'),  -- remove espaço antes de vírgula
                   '\s+', ' ', 'g'                           -- colapsa múltiplos espaços
               )
           ) AS segmento
    FROM pass4
),
segmentos_filtrados AS (
    -- 7. Descarta ruído
    SELECT DISTINCT ano, segmento
    FROM pass5
    WHERE segmento <> ''
      AND LENGTH(segmento) >= 2
      AND segmento !~* '^UN[12]$'
      AND segmento NOT ILIKE '%Formatura%'
      AND segmento NOT ILIKE '%Bicho%'
      AND segmento NOT ILIKE '%Museu%'
      AND segmento NOT ILIKE '%Parque%'
      AND segmento NOT ILIKE '%Passeio%'
      AND segmento NOT ILIKE '%English%'
      AND segmento NOT ILIKE '%Summer%'
      AND segmento NOT ILIKE '%Vacation%'
      AND segmento NOT ILIKE '%Curso de F%'
      AND segmento NOT ILIKE '%PROJETO%'
      AND segmento NOT ILIKE '%OUTROS%'
      AND segmento NOT ILIKE '%ADICIONAL%'
      AND segmento NOT ILIKE '%Avulso%'
      AND segmento NOT ILIKE '%Histórico%'
      AND segmento NOT ILIKE '%Historico%'
      AND segmento NOT ILIKE '%Substituti%'
      AND segmento NOT ILIKE '%OVER%'
      AND segmento NOT ILIKE '%HORAS%'
),
segmentos_deduplicados AS (
    -- 8. Deduplica por forma canônica ignorando espaços, acentos e
    --    caracteres não-ASCII (artefatos de encoding). Preserva a
    --    grafia mais "limpa" como representativa (menor comprimento
    --    e alfabeticamente primeira).
    SELECT
        ano,
        (SELECT sf.segmento
         FROM segmentos_filtrados sf
         WHERE sf.ano = x.ano
           AND UPPER(regexp_replace(regexp_replace(sf.segmento, '[^A-Za-z0-9/]', '', 'g'), '\s+', '', 'g'))
             = x.chave_norm
         ORDER BY LENGTH(sf.segmento), sf.segmento
         LIMIT 1) AS segmento
    FROM (
        SELECT DISTINCT
            ano,
            UPPER(regexp_replace(regexp_replace(segmento, '[^A-Za-z0-9/]', '', 'g'), '\s+', '', 'g')) AS chave_norm
        FROM segmentos_filtrados
        WHERE LENGTH(regexp_replace(segmento, '[^A-Za-z0-9/]', '', 'g')) >= 2
    ) x
),
filiais AS (
    SELECT 1 AS codfilial UNION ALL SELECT 2
),
base AS (
    SELECT
        sd.ano,
        sd.segmento,
        f.codfilial,
        ROW_NUMBER() OVER (
            PARTITION BY sd.ano, f.codfilial
            ORDER BY sd.segmento
        ) AS seq
    FROM segmentos_deduplicados sd
    CROSS JOIN filiais f
)
SELECT
    1                                                               AS "CODCOLIGADA",
    ano::character varying(10)                                      AS "CODPERLET",
    (RIGHT(ano, 2) || codfilial::text || LPAD(seq::text, 3, '0'))::character varying(10)
                                                                    AS "CODPLANOPGTO",
    LEFT('Plano ' || segmento || ' ' || ano || ' - Filial ' || codfilial::text, 60)::character varying(60)
                                                                    AS "DESCRICAO",
    LEFT(segmento || ' ' || ano, 60)::character varying(60)         AS "NOME",
    (ano || '-01-01')::date                                         AS "DTINICIO",
    (ano || '-12-31')::date                                         AS "DTFIM",
    0::numeric(10,4)                                                AS "DESCONTO",
    1                                                               AS "CODTIPOCURSO",
    codfilial                                                       AS "CODFILIAL",
    'N'::character varying(1)                                       AS "MATRICULALIVRE"
FROM base
ORDER BY ano, codfilial, seq;
