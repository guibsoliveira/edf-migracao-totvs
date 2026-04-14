-- =====================================================================
-- export.sparcplano  —  Parcelas dos planos de pagamento
-- =====================================================================
-- Ligações com outras views (integridade referencial):
--   CODPLANOPGTO → export.splanopgto.CODPLANOPGTO  (FK obrigatória)
--   NOMESERVICO  → export.sservico.NOME             (FK obrigatória)
--   CODPERLET    → export.spletivo.CODPERLET        (FK obrigatória)
--
-- Regras de negócio aplicadas:
--   • MENS / ALIM / MAT ..... 12 parcelas (janeiro a dezembro)
--   • 1ºPARC (rematrícula) .. 1 parcela (mês 1 do ano letivo)
--                             Parcelamento individual fica em SCONTRATO
--   • ANUIDADE .............. 1 parcela (mês 1 do ano letivo)
--   • DTVENCIMENTO .......... dia 5 de cada mês (modal observado no
--                             histórico de cobranças Gennera)
--   • DTCOMPETENCIA ......... 01/MM/AAAA (dia 01 fixo, conforme template)
--   • VALOR ................. mode() dos valores reais por (item, parcela)
--                             — valor mais frequente cobrado naquele mês
--   • COTA .................. 1 (padrão TOTVS RM)
--   • DESCONTO .............. 0 (descontos gerenciados via SBOLSA)
--   • TIPODESC .............. P (percentual, consistente com SBOLSA)
--   • TIPOPARCELA ........... P (parcela do plano)
--   • VALORAUTOMATICO ....... N
--   • DTVENCIMENTOFLEXIVEL .. N
-- =====================================================================

DROP VIEW IF EXISTS export.sparcplano CASCADE;

CREATE OR REPLACE VIEW export.sparcplano AS
WITH
-- ─── 1. Catálogo de planos com segmento extraído ──────────────────────
plan_catalog AS (
    SELECT
        sp."CODPLANOPGTO",
        sp."CODPERLET"     AS ano,
        sp."CODFILIAL",
        sp."CODTIPOCURSO",
        -- extrai segmento removendo o ano do final do NOME
        TRIM(regexp_replace(sp."NOME",
            '\s+' || sp."CODPERLET" || '\s*$', '')) AS segmento
    FROM export.splanopgto sp
),

-- ─── 2. Normalização de itens do histórico ───────────────────────────
-- (mesma lógica de extração de segmento usada em splanopgto)
itens_norm AS (
    SELECT DISTINCT
        sh.calendario_academico                         AS ano,
        TRIM(sh.item)                                   AS item,
        -- tipo de cobrança
        CASE
            WHEN TRIM(sh.item) ~* '1[^[:space:]]{0,3}\s*(PARC|MENS)' THEN '1PARC'
            WHEN TRIM(sh.item) ~* '(ANUIDADE|ANUID)'              THEN 'ANUID'
            WHEN TRIM(sh.item) ~* '(ALIMENTA)'                    THEN 'ALIM'
            WHEN TRIM(sh.item) ~* '(MATERIAIS|MAT\s*DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2})' THEN 'MAT'
            WHEN TRIM(sh.item) ~* '(MENS|MENSALIDADE)'            THEN 'MENS'
            ELSE 'OUTRO'
        END AS tipo_item,
        -- segmento (mesma pipeline de splanopgto)
        UPPER(regexp_replace(regexp_replace(
            TRIM(
                regexp_replace(
                    regexp_replace(
                        regexp_replace(sh.item, '^20[0-9]{2}\s*', '', 'g'),
                        '^(1\S{0,3}\s*MENSALIDADE|1\S{0,3}\s*MENS|1\S{0,3}\s*PARC'
                        '|MENSALIDADE|MENS|ALIMENTA\S*|MATERIAIS|MAT\s+DIDAT'
                        '|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE|ANUID\S*|MAT)\s*',
                        '', 'g'
                    ),
                    '\s+', ' ', 'g'
                )
            ),
        '[^A-Za-z0-9/]', '', 'g'), '\s+', '', 'g')) AS segmento_norm
    FROM gennera_stg.servicos_historico sh
    WHERE sh.calendario_academico >= '2021'
      AND TRIM(sh.calendario_academico) <> ''
      AND sh.item IS NOT NULL AND TRIM(sh.item) <> ''
      AND sh.item ~* '(MENS|MENSALIDADE|ALIMENTA|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|ANUID|1\S{0,3}\s*PARC)'
      -- descarta poluição cruzada de ano
      AND NOT (sh.item ~ '^20[0-9]{2}\s'
               AND SUBSTRING(sh.item FROM '^(20[0-9]{2})') <> sh.calendario_academico)
),

-- ─── 3. Valores modais por (ano, item, parcela_num) ──────────────────
-- Para itens mensais (MENS, ALIM, MAT): mode() do valor individual por mês
valores_modal AS (
    SELECT
        sh.calendario_academico                         AS ano,
        TRIM(sh.item)                                   AS item,
        sh.fatura_mes::int                              AS parcela_num,
        mode() WITHIN GROUP (ORDER BY
            REPLACE(REPLACE(REPLACE(TRIM(sh.valor_bruto),
                '$',''),'.',''),',','.')::numeric(10,4)
        )                                               AS valor_modal
    FROM gennera_stg.servicos_historico sh
    WHERE sh.calendario_academico >= '2021'
      AND sh.item ~* '(MENS|MENSALIDADE|ALIMENTA|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|ANUID|1\S{0,3}\s*(PARC|MENS))'
      AND sh.fatura_mes IS NOT NULL AND sh.fatura_mes ~ '^\d+$'
      AND sh.valor_bruto IS NOT NULL
      AND TRIM(sh.valor_bruto) NOT IN ('$0,00','','0','0,00')
    GROUP BY sh.calendario_academico, TRIM(sh.item), sh.fatura_mes::int
),

-- ─── 3b. Valor integral para itens de pagamento único (ANUID, 1ºPARC) ─
-- Pais podem parcelar anuidade/rematrícula (ex: 3×, 10×), então
-- SUM por aluno reconstitui o valor total; mode() do total = valor correto.
valores_unicos AS (
    SELECT
        sub.ano,
        sub.item,
        mode() WITHIN GROUP (ORDER BY sub.total_aluno) AS valor_total
    FROM (
        SELECT
            sh.calendario_academico                     AS ano,
            TRIM(sh.item)                               AS item,
            sh.id_pessoa,
            SUM(
                REPLACE(REPLACE(REPLACE(TRIM(sh.valor_bruto),
                    '$',''),'.',''),',','.')::numeric(10,4)
            )                                           AS total_aluno
        FROM gennera_stg.servicos_historico sh
        WHERE sh.calendario_academico >= '2021'
          AND (sh.item ~* '(ANUIDADE|ANUID)' OR sh.item ~* '1[^[:space:]]{0,3}\s*(PARC|MENS)')
          AND sh.valor_bruto IS NOT NULL
          AND TRIM(sh.valor_bruto) NOT IN ('$0,00','','0','0,00')
        GROUP BY sh.calendario_academico, TRIM(sh.item), sh.id_pessoa
    ) sub
    GROUP BY sub.ano, sub.item
),

-- ─── 4. Valor representativo por item (mode global, fallback) ────────
valor_geral AS (
    SELECT
        vm.ano,
        vm.item,
        mode() WITHIN GROUP (ORDER BY vm.valor_modal) AS valor_rep
    FROM valores_modal vm
    GROUP BY vm.ano, vm.item
),

-- ─── 5. Série de parcelas: 12 para MENS/ALIM/MAT, 1 para 1PARC/ANUID
parcelas_serie AS (
    SELECT
        pc."CODPLANOPGTO",
        pc.ano,
        pc."CODFILIAL",
        pc."CODTIPOCURSO",
        it.item,
        it.tipo_item,
        gs.n AS parcela_num
    FROM plan_catalog pc
    JOIN itens_norm it
      ON it.ano = pc.ano
      -- join via chave normalizada (sem acentos/espaços/pontuação)
      AND UPPER(regexp_replace(regexp_replace(it.segmento_norm,
              '[^A-Za-z0-9/]', '', 'g'), '\s+', '', 'g'))
        = UPPER(regexp_replace(regexp_replace(
              TRIM(regexp_replace(regexp_replace(
                  regexp_replace(
                      pc.segmento, '[^A-Za-z0-9/]', '', 'g'),
                  '\s+', '', 'g'), ' ', '', 'g')),
              '[^A-Za-z0-9/]', '', 'g'), '\s+', '', 'g'))
    JOIN LATERAL (
        -- 12 parcelas para ciclo mensal; 1 para entrada/anuidade
        SELECT generate_series(1,
            CASE WHEN it.tipo_item IN ('1PARC','ANUID') THEN 1 ELSE 12 END
        ) AS n
    ) gs ON TRUE
    WHERE it.tipo_item <> 'OUTRO'
)

-- ─── SELECT FINAL ─────────────────────────────────────────────────────
SELECT
    1                                                   AS "CODCOLIGADA",
    ps.ano::character varying(10)                       AS "CODPERLET",
    ps."CODTIPOCURSO"                                   AS "CODTIPOCURSO",
    ps."CODPLANOPGTO"::character varying(10)            AS "CODPLANOPGTO",
    ps.parcela_num                                      AS "PARCELA",
    1                                                   AS "COTA",
    LEFT(ps.item, 60)::character varying(60)            AS "NOMESERVICO",
    COALESCE(vu.valor_total, vm.valor_modal, vg.valor_rep, 0)::numeric(10,4)
                                                        AS "VALOR",
    -- dia 5 do mês referente à parcela
    (ps.ano || '-' || LPAD(ps.parcela_num::text, 2, '0') || '-05')::date
                                                        AS "DTVENCIMENTO",
    0::numeric(10,4)                                    AS "DESCONTO",
    'P'::character varying(1)                           AS "TIPODESC",
    'N'::character varying(1)                           AS "VALORAUTOMATICO",
    -- competência: dia 01 fixo, mesmo mês/ano da parcela
    (ps.ano || '-' || LPAD(ps.parcela_num::text, 2, '0') || '-01')::date
                                                        AS "DTCOMPETENCIA",
    'P'::character varying(1)                           AS "TIPOPARCELA",
    ps."CODFILIAL"                                      AS "CODFILIAL",
    'N'::character varying(1)                           AS "DTVENCIMENTOFLEXIVEL"
FROM parcelas_serie ps
LEFT JOIN valores_unicos vu
  ON vu.ano = ps.ano AND vu.item = ps.item
LEFT JOIN valores_modal vm
  ON vm.ano = ps.ano AND vm.item = ps.item AND vm.parcela_num = ps.parcela_num
LEFT JOIN valor_geral vg
  ON vg.ano = ps.ano AND vg.item = ps.item
ORDER BY ps."CODPLANOPGTO", ps.item, ps.parcela_num;
