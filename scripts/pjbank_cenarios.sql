-- =====================================================================
-- PJBANK fora do ar — 3 cenarios de responsaveis financeiros
-- =====================================================================
-- Fonte: gennera_stg (dump local, ate 2025-12-19)
-- Dados em tempo real (atual) requerem API Gennera (ver doc final).
--
-- ATENCAO: dump tem 5 meses de defasagem (corte 2025-12-19).
-- Pessoas que comecaram cartao APOS dezembro/2025 nao aparecem aqui.
--
-- Os 3 cenarios sao baseados em proxies a partir do dump:
--
--  Cenario 1: PAGANDO COM CARTAO
--    Quem tem ao menos 1 pagamento creditCard 'paid' em 2025 (semestre 2)
--
--  Cenario 2: ERRO DE CARTAO (proxy)
--    Quem teve creditCard com status 'pending' ou 'cancelled'
--    nos ultimos meses do dump. CreditCard normalmente e' instantaneo —
--    pending = anomalia (gateway falhou, cartao recusado, etc).
--
--  Cenario 3: RECORRENCIA ATIVA (proxy forte)
--    Quem pagou creditCard em >=3 meses distintos em 2025.
--    Padrao classico de cartao salvo pra cobranca recorrente.
-- =====================================================================

DROP VIEW IF EXISTS export.pjbank_pagantes_cartao;
DROP VIEW IF EXISTS export.pjbank_erros_cartao;
DROP VIEW IF EXISTS export.pjbank_recorrencia_ativa;

-- =====================================================================
-- CENARIO 1: PAGANDO COM CARTAO (universo)
-- =====================================================================
CREATE OR REPLACE VIEW export.pjbank_pagantes_cartao AS
WITH cartao_recente AS (
    SELECT
        p.id_person,
        COUNT(*) FILTER (WHERE p.status='paid')      AS pgtos_pagos,
        COUNT(*) FILTER (WHERE p.status='pending')   AS pgtos_pendentes,
        COUNT(*) FILTER (WHERE p.status='cancelled') AS pgtos_cancelados,
        SUM(p.amount) FILTER (WHERE p.status='paid') AS valor_total_pago,
        MIN(p.date) AS primeiro_pgto,
        MAX(p.date) AS ultimo_pgto
    FROM gennera_stg.payment p
    WHERE p.payment_method = 'creditCard'
      AND p.date >= '2025-06-01'
    GROUP BY p.id_person
),
filhos AS (
    SELECT
        r.id_owner,
        STRING_AGG(DISTINCT pf.name, ' | ' ORDER BY pf.name) AS filhos
    FROM gennera_stg.relationship r
    JOIN gennera_stg.person_fisica pf ON pf.id_person = r.id_target
    WHERE r.type IN ('MOTHER','FATHER','RESPONSIBLE','GRANDFATHER','GRANDMOTHER','OTHER')
    GROUP BY r.id_owner
)
SELECT
    pf.cpf                                  AS cpf,
    pf.name                                 AS responsavel,
    pf.email                                AS email,
    pf.mobile_phone_number_normalized       AS celular,
    c.pgtos_pagos                           AS qtd_pagos,
    c.pgtos_pendentes                       AS qtd_pendentes,
    c.pgtos_cancelados                      AS qtd_cancelados,
    c.valor_total_pago                      AS valor_pago,
    LEFT(c.primeiro_pgto, 10)               AS primeiro_pgto,
    LEFT(c.ultimo_pgto, 10)                 AS ultimo_pgto,
    f.filhos                                AS filhos_alunos
FROM cartao_recente c
JOIN gennera_stg.person_fisica pf ON pf.id_person = c.id_person
LEFT JOIN filhos f ON f.id_owner = c.id_person
ORDER BY c.pgtos_pagos DESC, pf.name;

-- =====================================================================
-- CENARIO 2: ERRO DE CARTAO (proxy: pending/cancelled)
-- =====================================================================
CREATE OR REPLACE VIEW export.pjbank_erros_cartao AS
WITH erros AS (
    SELECT
        p.id_person,
        COUNT(*) FILTER (WHERE p.status='pending')   AS pendentes,
        COUNT(*) FILTER (WHERE p.status='cancelled') AS cancelados,
        COUNT(*) FILTER (WHERE p.status='paid')      AS pagos,
        SUM(p.amount) FILTER (WHERE p.status IN ('pending','cancelled')) AS valor_em_erro,
        MAX(p.date) FILTER (WHERE p.status IN ('pending','cancelled')) AS ultimo_erro
    FROM gennera_stg.payment p
    WHERE p.payment_method = 'creditCard'
      AND p.date >= '2025-06-01'
    GROUP BY p.id_person
    HAVING COUNT(*) FILTER (WHERE p.status IN ('pending','cancelled')) > 0
),
filhos AS (
    SELECT
        r.id_owner,
        STRING_AGG(DISTINCT pf.name, ' | ' ORDER BY pf.name) AS filhos
    FROM gennera_stg.relationship r
    JOIN gennera_stg.person_fisica pf ON pf.id_person = r.id_target
    WHERE r.type IN ('MOTHER','FATHER','RESPONSIBLE','GRANDFATHER','GRANDMOTHER','OTHER')
    GROUP BY r.id_owner
)
SELECT
    pf.cpf                                  AS cpf,
    pf.name                                 AS responsavel,
    pf.email                                AS email,
    pf.mobile_phone_number_normalized       AS celular,
    e.pendentes                             AS qtd_pending,
    e.cancelados                            AS qtd_cancelled,
    e.pagos                                 AS qtd_pagos_ok,
    e.valor_em_erro                         AS valor_em_erro,
    LEFT(e.ultimo_erro, 10)                 AS ultimo_erro_data,
    f.filhos                                AS filhos_alunos
FROM erros e
JOIN gennera_stg.person_fisica pf ON pf.id_person = e.id_person
LEFT JOIN filhos f ON f.id_owner = e.id_person
ORDER BY e.pendentes + e.cancelados DESC, pf.name;

-- =====================================================================
-- CENARIO 3: RECORRENCIA ATIVA (proxy: 3+ meses pagos com cartao)
-- =====================================================================
CREATE OR REPLACE VIEW export.pjbank_recorrencia_ativa AS
WITH meses_cartao AS (
    SELECT
        p.id_person,
        COUNT(DISTINCT LEFT(p.date, 7))                                 AS meses_distintos,
        COUNT(*) FILTER (WHERE p.status='paid')                         AS pgtos_ok,
        COUNT(*) FILTER (WHERE p.status IN ('pending','cancelled'))     AS pgtos_erro,
        SUM(p.amount) FILTER (WHERE p.status='paid')                    AS valor_total,
        MIN(p.date)                                                     AS desde,
        MAX(p.date)                                                     AS ultimo
    FROM gennera_stg.payment p
    WHERE p.payment_method = 'creditCard'
      AND p.status = 'paid'
      AND p.date >= '2025-01-01'
    GROUP BY p.id_person
    HAVING COUNT(DISTINCT LEFT(p.date, 7)) >= 3
),
filhos AS (
    SELECT
        r.id_owner,
        STRING_AGG(DISTINCT pf.name, ' | ' ORDER BY pf.name) AS filhos
    FROM gennera_stg.relationship r
    JOIN gennera_stg.person_fisica pf ON pf.id_person = r.id_target
    WHERE r.type IN ('MOTHER','FATHER','RESPONSIBLE','GRANDFATHER','GRANDMOTHER','OTHER')
    GROUP BY r.id_owner
)
SELECT
    pf.cpf                                  AS cpf,
    pf.name                                 AS responsavel,
    pf.email                                AS email,
    pf.mobile_phone_number_normalized       AS celular,
    m.meses_distintos                       AS meses_pagos_cartao,
    m.pgtos_ok                              AS qtd_ok,
    m.pgtos_erro                            AS qtd_erro,
    m.valor_total                           AS valor_total,
    LEFT(m.desde, 10)                       AS desde,
    LEFT(m.ultimo, 10)                      AS ultimo_pgto,
    f.filhos                                AS filhos_alunos
FROM meses_cartao m
JOIN gennera_stg.person_fisica pf ON pf.id_person = m.id_person
LEFT JOIN filhos f ON f.id_owner = m.id_person
ORDER BY m.meses_distintos DESC, m.valor_total DESC;
