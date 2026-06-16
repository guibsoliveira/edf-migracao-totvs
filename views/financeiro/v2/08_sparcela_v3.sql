-- ============================================================================
-- export_v2.sparcela — v3 (refatorada 2026-06-09 com 5 fixes confirmados)
-- ============================================================================
-- Mudanças vs v2 (snapshot 2026-05-20):
--
-- 1. [Cat A — dups idênticas com mesmo VALOR] DEDUP CONDICIONAL
--    Quando há 2+ linhas com (RA, calendar, parcela, servico, valor, dtvenc):
--    - Serviços RECORRENTES (Mensalidade, 1ª mens, Alimentação, Material
--      Didático, Material de Artes) → manter UMA via ROW_NUMBER ORDER BY
--      status_priority (pago > pago a maior > renegociado > atrasado > aberto).
--    - Serviços AVULSOS (Prova Substitutiva, Taxa, Almoço Avulso, Formatura,
--      passeios etc) → manter TODAS as ocorrências (são legítimas — aluno
--      pode comprar 2 provas substitutivas no mesmo mês).
--    Razão: user confirmou (2026-06-09) que dups com mesmo valor de
--    serviço recorrente = erro operacional do financeiro Gennera (caso
--    Gabriely Lopes Freitas: 2 contratos Alim 2021, um limpo e um sujo).
--
-- 2. [Cat C — Material Didático ≠ Material de Artes] CASE WHEN refinado
--    v2 colapsava `ILIKE '%MATERIAL%'` → 'Material Didático' agregando
--    "MATERIAL DE ARTES" (568 ocorrências) por engano. v3 separa em
--    serviço próprio "Material de Artes".
--
-- 3. [Cat E — Renegociações] MANTER ambas com flag
--    v2 filtrava só `status <> 'cancelado'` → trazia renegociada + nova
--    como dup. v3 mantém ambas e adiciona OBSPARC marcando a renegociada.
--    Razão: financeiro Gennera ao renegociar gera novo contrato que
--    contempla o antigo. Ambos são válidos no histórico.
--
-- 4. [Status 'pago a maior'] preservar VALORBRUTO + VALORPAGO separados
--    v2 só tinha VALOR (assumia bruto=pago). v3 tem VALOR (bruto) e
--    VALORPAGO (efetivo). Quando há "pago a maior" → OBSPARC marca.
--
-- 5. [Auditoria] colunas extras pra rastreio (não vão pro Importador):
--    STATUSGENNERA, VALORPAGO, VALORJUROS, VALORMULTA, DATAPAGAMENTO,
--    HASHCONTRATO_ORIG, OBSPARC.
--
-- v3.2 (2026-06-11 — auditoria piloto 1MA/1MB 2024, causa-raiz confirmada):
--
-- 6. [BUG ALIM/MDIDAT 2024+] FALLBACK SERVIC/SERVIC_EXTRA → contrato MENS
--    A EDF unificou os boletos (decisão da escola, não da Gennera): até
--    ~2022 ALIM/Material tinham contratos próprios ("Contrato - Alimentação
--    2022"); de 2023/2024 em diante são faturados DENTRO do contrato
--    "Mensalidade" (hash_contrato idêntico em servicos_historico — provado
--    no RA 20152214). Sem contrato avulso, servicos_ranked fica vazio e o
--    WHERE final (ct.id_contract IS NOT NULL) descartava em silêncio
--    ~24 parcelas/aluno (12 ALIM + 12 MDIDAT ≈ R$ 19.944) — 59/84 alunos
--    de 2024 F1, ~1.289 parcelas pagas. Fix: fallback do contrato de
--    SERVIC/SERVIC_EXTRA para c_mens (e na falta, c_rematr).
--
-- 7. [Consistência tipo × servico_nome] item "2024 MD 2024 EM" classificava
--    servico_nome='Material Didático' (padrão \mMD\M) mas tipo='SERVIC_EXTRA'
--    (padrão ausente no CASE do tipo). Adicionado \mMD\M ao ramo SERVIC.
--
-- Regressão obrigatória pós-aplicação (RM = staging = espelho esperado):
--    RA 20152214/2024 → 41 parcelas, R$ 93.498
--    RA 20121769/2024 → 28 parcelas, R$ 93.498 (ANUID 3x)
--    RA 20121794/2024 → 46 parcelas, R$ 93.498 (1PARC 10x)
--    RA 20142166/2022 (Diego) → 37 parcelas (não pode regredir)
-- ============================================================================

DROP VIEW IF EXISTS export_v2.sparcela CASCADE;

CREATE OR REPLACE VIEW export_v2.sparcela AS
WITH alunos AS (
    SELECT
        upper(trim(pf.name)) AS name_key,
        e.id_enrollment,
        e.id_person,
        e.academic_calendar,
        e.class_name,
        scu.code_unif AS ra,
        CASE inst.code WHEN 'un1' THEN 1 WHEN 'un2' THEN 2 ELSE NULL END AS codfilial,
        st."CODCURSO",
        st."CODHABILITACAO",
        st."CODGRADE",
        st."TURNO"
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
    JOIN gennera_stg.person_fisica pf ON pf.id_person = e.id_person
    JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
    JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
    WHERE inst.code IN ('un1','un2')
      AND scu.code_unif IS NOT NULL
      AND e.academic_calendar IS NOT NULL
),
-- 1. Parcelas brutas + classificação granular do serviço
parcelas_raw AS (
    SELECT
        sh.calendario_academico,
        upper(trim(sh.aluno)) AS aluno_key,
        sh.item,
        sh.fatura_ano,
        COALESCE(NULLIF(sh.fatura_mes,'')::int, 1) AS parcela,
        NULLIF(replace(replace(replace(COALESCE(sh.valor_bruto,'')::text, '$',''), '.',''), ',','.'),'')::numeric AS valor_bruto,
        COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_pagamento,'')::text, '$',''), '.',''), ',','.'),'')::numeric, 0) AS valor_pagamento,
        COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_descontos,'')::text, '$',''), '.',''), ',','.'),'')::numeric, 0) AS valor_desconto,
        COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_juros,'')::text, '$',''), '.',''), ',','.'),'')::numeric, 0) AS valor_juros,
        COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_multa,'')::text, '$',''), '.',''), ',','.'),'')::numeric, 0) AS valor_multa,
        CASE WHEN sh.data_vencimento::text ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(sh.data_vencimento::text, 'DD/MM/YYYY') ELSE NULL END AS dt_vencimento,
        CASE WHEN sh.data_pagamento::text ~ '^\d{2}/\d{2}/\d{4}$' THEN to_date(sh.data_pagamento::text, 'DD/MM/YYYY') ELSE NULL END AS dt_pagamento,
        regexp_replace(COALESCE(sh.cpf_responsavel_financeiro,''), '\D','','g') AS cpf_resp,
        sh.contrato AS hash_contrato,
        sh.status AS status_gennera,
        -- Classificação granular do SERVICO (NÃO colapsa Material de Artes)
        CASE
            -- 1ª mensalidade / rematrícula
            WHEN sh.item::text ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)' AND sh.item::text !~* '^\s*(MENS|PARC)' THEN '1ª mensalidade'
            WHEN sh.item::text ILIKE '%matr%cula%' AND sh.item::text !~* 'MENS' THEN '1ª mensalidade'
            -- Mensalidade / Anuidade
            WHEN sh.item::text ILIKE '%ANUID%' THEN 'Mensalidade'
            WHEN sh.item::text ILIKE '%MENS%' THEN 'Mensalidade'
            -- Alimentação
            WHEN sh.item::text ILIKE '%ALIM%' THEN 'Alimentação'
            -- Material de Artes (PRIMEIRO — antes do Material Didático genérico)
            WHEN sh.item::text ILIKE '%MATERIAL%ARTE%' THEN 'Material de Artes'
            -- Material Didático (todas as variantes — inclui DIDÁTICO com acento)
            WHEN sh.item::text ILIKE '%MATERIAL%DIDAT%' THEN 'Material Didático'
            WHEN sh.item::text ILIKE '%MATERIAL%DIDÁT%' THEN 'Material Didático'  -- com acento Á
            WHEN sh.item::text ILIKE '%MATERIAL DID%' THEN 'Material Didático'   -- pega MATERIAL DIDÁTICO geral
            WHEN sh.item::text ILIKE '%MATERIAIS%' THEN 'Material Didático'
            WHEN sh.item::text ILIKE '%MDIDAT%' THEN 'Material Didático'
            WHEN sh.item::text ILIKE '%MDIAT%' THEN 'Material Didático'
            WHEN sh.item::text ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)' THEN 'Material Didático'
            WHEN sh.item::text ~* '\mMD\M' THEN 'Material Didático'
            -- Demais ficam com o nome original (Prova Substitutiva, Taxa, Almoço Avulso, passeios, etc.)
            ELSE trim(sh.item)
        END AS servico_nome,
        -- Tipo do contrato (espelhado com servico_nome — fix v3.1: MAT F2 → SERVIC)
        CASE
            WHEN sh.item::text ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)' AND sh.item::text !~* '^\s*(MENS|PARC)' THEN 'REMATR'
            WHEN sh.item::text ILIKE '%ANUID%' THEN 'MENS'
            WHEN sh.item::text ILIKE '%MENS%' THEN 'MENS'
            WHEN sh.item::text ILIKE '%ALIM%'
                 OR sh.item::text ILIKE '%MAT%DIDAT%'
                 OR sh.item::text ILIKE '%MATERIAL%DIDÁT%'
                 OR sh.item::text ILIKE '%MATERIAL DID%'
                 OR sh.item::text ILIKE '%MATERIAL%ARTE%'
                 OR sh.item::text ILIKE '%MDIDAT%'
                 OR sh.item::text ILIKE '%MDIAT%'
                 OR sh.item::text ~* '^\s*MD\s'
                 OR sh.item::text ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'  -- fix v3.1: pega "2022 MAT F2"
                 OR sh.item::text ~* '\mMD\M'  -- fix v3.2: espelha servico_nome ("2024 MD 2024 EM")
                 OR sh.item::text ILIKE '%MATERIAIS%' THEN 'SERVIC'
            ELSE 'SERVIC_EXTRA'
        END AS tipo
    FROM gennera_stg.servicos_historico sh
    WHERE sh.calendario_academico IS NOT NULL
      AND sh.aluno IS NOT NULL
      AND sh.item IS NOT NULL
      AND COALESCE(sh.status,'')::text <> 'cancelado'  -- Cat E: mantém renegociado
),
-- 2. Adiciona flag recorrente + prioridade do status
parcelas_classificadas AS (
    SELECT
        pr.*,
        -- Flag pra dedup condicional
        (servico_nome IN ('Mensalidade', '1ª mensalidade', 'Alimentação', 'Material Didático', 'Material de Artes')) AS eh_recorrente,
        -- Prioridade: pago > pago_a_maior > renegociado > atrasado > aberto > outros
        CASE status_gennera
            WHEN 'pago'         THEN 1
            WHEN 'pago a maior' THEN 2
            WHEN 'renegociado'  THEN 3
            WHEN 'atrasado'     THEN 4
            WHEN 'aberto'       THEN 5
            ELSE 9
        END AS status_priority
    FROM parcelas_raw pr
),
-- 3. Dedup CONDICIONAL: serviços recorrentes deduplicados, avulsos preservados
parcelas_dedup AS (
    -- Recorrentes: pega só rn=1 quando há dups
    SELECT * FROM (
        SELECT pc.*,
            ROW_NUMBER() OVER (
                PARTITION BY aluno_key, calendario_academico, fatura_ano, parcela, servico_nome, valor_bruto, dt_vencimento
                ORDER BY status_priority, hash_contrato
            ) AS rn_dedup
        FROM parcelas_classificadas pc
        WHERE eh_recorrente
    ) x WHERE rn_dedup = 1
    UNION ALL
    -- Avulsos: mantém todas as ocorrências (dups são legítimas)
    SELECT pc.*, 1 AS rn_dedup
    FROM parcelas_classificadas pc
    WHERE NOT eh_recorrente
),
-- 4. Adiciona observação por status especial
parcelas_marcadas AS (
    SELECT pd.*,
        CASE
            WHEN status_gennera = 'pago a maior' THEN
                'Pago a maior. Bruto: R$ ' || replace(to_char(valor_bruto,'FM9999999990.00'),'.',',')
                || ' Pago: R$ ' || replace(to_char(valor_pagamento,'FM9999999990.00'),'.',',')
            WHEN status_gennera = 'renegociado' THEN 'Renegociado - acordo gerou novo contrato'
            WHEN status_gennera = 'atrasado' THEN 'Em atraso'
            ELSE NULL
        END AS obsparc
    FROM parcelas_dedup pd
),
-- 5. Resolve contratos (mantém estrutura da v2 — apenas mais tipos)
servicos_ranked AS (
    SELECT scu.code_unif AS ra, e.academic_calendar, c.id_contract, c.date,
        row_number() OVER (PARTITION BY scu.code_unif, e.academic_calendar ORDER BY c.date, c.id_contract) AS rank
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
    WHERE COALESCE(ec.details,'') !~~* '%mensalidad%'
      AND COALESCE(ec.details,'') !~~* '%rematr%'
      AND COALESCE(ec.details,'') !~~* '%anuid%'
      AND COALESCE(ec.details,'') !~~* '%atr%cula%'
    GROUP BY scu.code_unif, e.academic_calendar, c.id_contract, c.date
),
c_mens AS (
    SELECT DISTINCT ON (scu.code_unif, e.academic_calendar)
        scu.code_unif AS ra, e.academic_calendar, c.id_contract
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
    WHERE ec.details ILIKE '%mensalidad%' AND ec.details !~* '1[^[:space:]]{0,3}'
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
c_rematr AS (
    SELECT DISTINCT ON (scu.code_unif, e.academic_calendar)
        scu.code_unif AS ra, e.academic_calendar, c.id_contract
    FROM gennera_stg.enrollment e
    JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
    JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
    JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
    WHERE ec.details ILIKE '%rematr%' OR ec.details ILIKE '%matr%cula%'
    ORDER BY scu.code_unif, e.academic_calendar, c.date
),
contrato_por_tipo AS (
    -- MENS: prefere c_mens. Se faltar (ano 2022: Gennera rotulava como "Rematrícula"
    -- só), usa c_rematr como fallback. Fix v3.1 da regressão Diego 2022.
    SELECT ra, academic_calendar, 'MENS' AS tipo, id_contract FROM c_mens
    UNION ALL
    SELECT cr.ra, cr.academic_calendar, 'MENS', cr.id_contract
    FROM c_rematr cr
    WHERE NOT EXISTS (
        SELECT 1 FROM c_mens cm
        WHERE cm.ra::text = cr.ra::text AND cm.academic_calendar = cr.academic_calendar
    )
    UNION ALL
    SELECT ra, academic_calendar, 'REMATR', id_contract FROM c_rematr
    UNION ALL
    SELECT ra, academic_calendar, 'SERVIC', id_contract FROM servicos_ranked WHERE rank = 1
    UNION ALL
    SELECT ra, academic_calendar, 'SERVIC_EXTRA', id_contract FROM servicos_ranked WHERE rank = 2
    UNION ALL
    SELECT sr.ra, sr.academic_calendar, 'SERVIC_EXTRA', sr.id_contract
    FROM servicos_ranked sr
    WHERE sr.rank = 1 AND NOT EXISTS (
        SELECT 1 FROM servicos_ranked sr2
        WHERE sr2.ra::text = sr.ra::text AND sr2.academic_calendar = sr.academic_calendar AND sr2.rank = 2
    )
    -- ===== Fix v3.2: fallback p/ anos SEM contrato avulso de serviços =====
    -- (EDF unificou boletos 2023/2024+: ALIM/Material vivem DENTRO do contrato
    --  Mensalidade — hash idêntico. Sem este fallback, essas parcelas eram
    --  descartadas pelo WHERE final ct.id_contract IS NOT NULL.)
    UNION ALL
    SELECT cm.ra, cm.academic_calendar, 'SERVIC', cm.id_contract
    FROM c_mens cm
    WHERE NOT EXISTS (
        SELECT 1 FROM servicos_ranked sr
        WHERE sr.ra::text = cm.ra::text AND sr.academic_calendar = cm.academic_calendar AND sr.rank = 1
    )
    UNION ALL
    SELECT cr.ra, cr.academic_calendar, 'SERVIC', cr.id_contract
    FROM c_rematr cr
    WHERE NOT EXISTS (
        SELECT 1 FROM c_mens cm
        WHERE cm.ra::text = cr.ra::text AND cm.academic_calendar = cr.academic_calendar
    )
    AND NOT EXISTS (
        SELECT 1 FROM servicos_ranked sr
        WHERE sr.ra::text = cr.ra::text AND sr.academic_calendar = cr.academic_calendar AND sr.rank = 1
    )
    UNION ALL
    SELECT cm.ra, cm.academic_calendar, 'SERVIC_EXTRA', cm.id_contract
    FROM c_mens cm
    WHERE NOT EXISTS (
        SELECT 1 FROM servicos_ranked sr
        WHERE sr.ra::text = cm.ra::text AND sr.academic_calendar = cm.academic_calendar
    )
    UNION ALL
    SELECT cr.ra, cr.academic_calendar, 'SERVIC_EXTRA', cr.id_contract
    FROM c_rematr cr
    WHERE NOT EXISTS (
        SELECT 1 FROM c_mens cm
        WHERE cm.ra::text = cr.ra::text AND cm.academic_calendar = cr.academic_calendar
    )
    AND NOT EXISTS (
        SELECT 1 FROM servicos_ranked sr
        WHERE sr.ra::text = cr.ra::text AND sr.academic_calendar = cr.academic_calendar
    )
)
-- 6. Output final
SELECT
    1 AS "CODCOLIGADA",
    a."CODCURSO"::varchar(10)        AS "CODCURSO",
    a."CODHABILITACAO"::varchar(10)  AS "CODHABILITACAO",
    a."CODGRADE"::varchar(10)        AS "CODGRADE",
    a."TURNO"::varchar(15)           AS "TURNO",
    a.codfilial                      AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    a.ra::varchar(20)                AS "RA",
    a.academic_calendar::varchar(10) AS "CODPERLET",
    ct.id_contract::varchar(20)      AS "CODCONTRATO",
    left(p.servico_nome, 60)::varchar(60) AS "SERVICO",
    p.parcela AS "PARCELA",
    1 AS "COTA",
    replace(to_char(p.valor_bruto, 'FM9999999990.00'), '.', ',') AS "VALOR",
    to_char(p.dt_vencimento, 'YYYY-MM-DD')::varchar(10) AS "DTVENCIMENTO",
    replace(to_char(p.valor_desconto, 'FM9999999990.00'), '.', ',') AS "DESCONTO",
    'V'::varchar(1) AS "TIPODESC",
    'P'::varchar(1) AS "TIPOPARCELA",
    'N'::varchar(1) AS "VALORAUTOMATICO",
    to_char(make_date(a.academic_calendar::int, COALESCE(NULLIF(p.parcela,0),1), 1), 'YYYY-MM-DD')::varchar(10) AS "DTCOMPETENCIA",
    1 AS "CODCOLCFO",
    lpad(f."CODCFO", 6, '0')::varchar(25) AS "CODCFO",
    -- ===== Colunas EXTRAS pra auditoria (não vão pro Importador, mas preservam dados Gennera) =====
    p.status_gennera::varchar(20) AS "STATUSGENNERA",
    replace(to_char(p.valor_pagamento, 'FM9999999990.00'), '.', ',') AS "VALORPAGO",
    replace(to_char(p.valor_juros, 'FM9999999990.00'), '.', ',') AS "VALORJUROS",
    replace(to_char(p.valor_multa, 'FM9999999990.00'), '.', ',') AS "VALORMULTA",
    to_char(p.dt_pagamento, 'YYYY-MM-DD')::varchar(10) AS "DATAPAGAMENTO",
    p.hash_contrato::varchar(32) AS "HASHCONTRATO_ORIG",
    p.obsparc::varchar(255) AS "OBSPARC"
FROM parcelas_marcadas p
JOIN alunos a
    ON a.name_key = p.aluno_key
    AND a.academic_calendar = p.calendario_academico
LEFT JOIN contrato_por_tipo ct
    ON ct.ra::text = a.ra::text
    AND ct.academic_calendar = p.calendario_academico
    AND ct.tipo = p.tipo
LEFT JOIN export.fcfo f ON f."CGCCFO" = p.cpf_resp
WHERE p.valor_bruto IS NOT NULL
  AND p.dt_vencimento IS NOT NULL
  AND ct.id_contract IS NOT NULL;
