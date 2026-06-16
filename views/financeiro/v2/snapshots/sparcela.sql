-- ============================================================================
-- View: export_v2.sparcela
-- Esquema destino TOTVS: SPARCELA
-- ============================================================================
-- Snapshot do DDL em 2026-06-11 (dump automatico via scripts/dump_views_para_repo.py)
--
-- USO COMO FONTE PARA IMPORTADOR TOTVS EDUCACIONAL
-- ------------------------------------------------------------------
-- O Importador (Executar -> Importador -> TOTVS Educacional) consome
-- arquivos .csv ANSI/LATIN-1 com separador ';' baseados nesta view.
--
-- REGRA CRITICA (ver knowledge/totvs/13_importador_layout_e_lookups.md):
-- Colunas com sintaxe COLUNA$X.TABELA$S$X$T.CAMPOBUSCA.FK1$FK1...
-- querem o CAMPOBUSCA (codigo humano), nao o ID literal.
--
-- Exemplos pro RM Educacional:
--   IDHABILITACAOFILIAL  -> passar CODHABILITACAO (ex: '8')
--   IDPERLET             -> passar CODPERLET (ex: '2022')
--   IDTURMADISC          -> passar CODDISC (ex: '7')
--   CODTURNO             -> passar NOME (ex: 'Integral')
--   CODSTATUS/RES        -> passar DESCRICAO (ex: 'Ativo', 'Aprovado')
--
-- Por isso esta view retorna sempre os CODIGOS HUMANOS, NUNCA os IDs
-- sequenciais (IDPERLET, IDHABFIL, IDTURMADISC). O Importador resolve
-- IDs internos via lookup, e o mesmo CSV migra entre instancias.
--
-- WORKFLOW para usar:
-- 1. Gerar CSV "isca" com header minimo -> Importador imprime "Layout esperado:"
-- 2. Capturar Layout esperado: literal e usar como header EXATO
-- 3. Script em scripts/gera_*_importador_totvs.py mapeia colunas da view -> layout
-- 4. Importar via TOTVS Educacional
-- ============================================================================

CREATE OR REPLACE VIEW export_v2.sparcela AS
WITH alunos AS (
         SELECT upper(TRIM(BOTH FROM pf.name)) AS name_key,
            e.id_enrollment,
            e.id_person,
            e.academic_calendar,
            e.class_name,
            scu.code_unif AS ra,
                CASE inst.code
                    WHEN 'un1'::text THEN 1
                    WHEN 'un2'::text THEN 2
                    ELSE NULL::integer
                END AS codfilial,
            st."CODCURSO",
            st."CODHABILITACAO",
            st."CODGRADE",
            st."TURNO"
           FROM gennera_stg.enrollment e
             JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
             JOIN gennera_stg.person_fisica pf ON pf.id_person = e.id_person
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
             JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
          WHERE (inst.code = ANY (ARRAY['un1'::text, 'un2'::text])) AND scu.code_unif IS NOT NULL AND e.academic_calendar IS NOT NULL
        ), parcelas_raw AS (
         SELECT sh.calendario_academico,
            upper(TRIM(BOTH FROM sh.aluno)) AS aluno_key,
            sh.item,
            sh.fatura_ano,
            COALESCE(NULLIF(sh.fatura_mes, ''::text)::integer, 1) AS parcela,
            NULLIF(replace(replace(replace(COALESCE(sh.valor_bruto, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric AS valor_bruto,
            COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_pagamento, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric, 0::numeric) AS valor_pagamento,
            COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_descontos, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric, 0::numeric) AS valor_desconto,
            COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_juros, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric, 0::numeric) AS valor_juros,
            COALESCE(NULLIF(replace(replace(replace(COALESCE(sh.valor_multa, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric, 0::numeric) AS valor_multa,
                CASE
                    WHEN sh.data_vencimento::text ~ '^\d{2}/\d{2}/\d{4}$'::text THEN to_date(sh.data_vencimento::text, 'DD/MM/YYYY'::text)
                    ELSE NULL::date
                END AS dt_vencimento,
                CASE
                    WHEN sh.data_pagamento::text ~ '^\d{2}/\d{2}/\d{4}$'::text THEN to_date(sh.data_pagamento::text, 'DD/MM/YYYY'::text)
                    ELSE NULL::date
                END AS dt_pagamento,
            regexp_replace(COALESCE(sh.cpf_responsavel_financeiro, ''::text), '\D'::text, ''::text, 'g'::text) AS cpf_resp,
            sh.contrato AS hash_contrato,
            sh.status AS status_gennera,
                CASE
                    WHEN sh.item::text ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'::text AND sh.item::text !~* '^\s*(MENS|PARC)'::text THEN '1ª mensalidade'::text
                    WHEN sh.item::text ~~* '%matr%cula%'::text AND sh.item::text !~* 'MENS'::text THEN '1ª mensalidade'::text
                    WHEN sh.item::text ~~* '%ANUID%'::text THEN 'Mensalidade'::text
                    WHEN sh.item::text ~~* '%MENS%'::text THEN 'Mensalidade'::text
                    WHEN sh.item::text ~~* '%ALIM%'::text THEN 'Alimentação'::text
                    WHEN sh.item::text ~~* '%MATERIAL%ARTE%'::text THEN 'Material de Artes'::text
                    WHEN sh.item::text ~~* '%MATERIAL%DIDAT%'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~~* '%MATERIAL%DIDÁT%'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~~* '%MATERIAL DID%'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~~* '%MATERIAIS%'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~~* '%MDIDAT%'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~~* '%MDIAT%'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'::text THEN 'Material Didático'::text
                    WHEN sh.item::text ~* '\mMD\M'::text THEN 'Material Didático'::text
                    ELSE TRIM(BOTH FROM sh.item)
                END AS servico_nome,
                CASE
                    WHEN sh.item::text ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'::text AND sh.item::text !~* '^\s*(MENS|PARC)'::text THEN 'REMATR'::text
                    WHEN sh.item::text ~~* '%ANUID%'::text THEN 'MENS'::text
                    WHEN sh.item::text ~~* '%MENS%'::text THEN 'MENS'::text
                    WHEN sh.item::text ~~* '%ALIM%'::text OR sh.item::text ~~* '%MAT%DIDAT%'::text OR sh.item::text ~~* '%MATERIAL%DIDÁT%'::text OR sh.item::text ~~* '%MATERIAL DID%'::text OR sh.item::text ~~* '%MATERIAL%ARTE%'::text OR sh.item::text ~~* '%MDIDAT%'::text OR sh.item::text ~~* '%MDIAT%'::text OR sh.item::text ~* '^\s*MD\s'::text OR sh.item::text ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'::text OR sh.item::text ~* '\mMD\M'::text OR sh.item::text ~~* '%MATERIAIS%'::text THEN 'SERVIC'::text
                    ELSE 'SERVIC_EXTRA'::text
                END AS tipo
           FROM gennera_stg.servicos_historico sh
          WHERE sh.calendario_academico IS NOT NULL AND sh.aluno IS NOT NULL AND sh.item IS NOT NULL AND COALESCE(sh.status, ''::character varying)::text <> 'cancelado'::text
        ), parcelas_classificadas AS (
         SELECT pr.calendario_academico,
            pr.aluno_key,
            pr.item,
            pr.fatura_ano,
            pr.parcela,
            pr.valor_bruto,
            pr.valor_pagamento,
            pr.valor_desconto,
            pr.valor_juros,
            pr.valor_multa,
            pr.dt_vencimento,
            pr.dt_pagamento,
            pr.cpf_resp,
            pr.hash_contrato,
            pr.status_gennera,
            pr.servico_nome,
            pr.tipo,
            pr.servico_nome = ANY (ARRAY['Mensalidade'::text, '1ª mensalidade'::text, 'Alimentação'::text, 'Material Didático'::text, 'Material de Artes'::text]) AS eh_recorrente,
                CASE pr.status_gennera
                    WHEN 'pago'::text THEN 1
                    WHEN 'pago a maior'::text THEN 2
                    WHEN 'renegociado'::text THEN 3
                    WHEN 'atrasado'::text THEN 4
                    WHEN 'aberto'::text THEN 5
                    ELSE 9
                END AS status_priority
           FROM parcelas_raw pr
        ), parcelas_dedup AS (
         SELECT x.calendario_academico,
            x.aluno_key,
            x.item,
            x.fatura_ano,
            x.parcela,
            x.valor_bruto,
            x.valor_pagamento,
            x.valor_desconto,
            x.valor_juros,
            x.valor_multa,
            x.dt_vencimento,
            x.dt_pagamento,
            x.cpf_resp,
            x.hash_contrato,
            x.status_gennera,
            x.servico_nome,
            x.tipo,
            x.eh_recorrente,
            x.status_priority,
            x.rn_dedup
           FROM ( SELECT pc.calendario_academico,
                    pc.aluno_key,
                    pc.item,
                    pc.fatura_ano,
                    pc.parcela,
                    pc.valor_bruto,
                    pc.valor_pagamento,
                    pc.valor_desconto,
                    pc.valor_juros,
                    pc.valor_multa,
                    pc.dt_vencimento,
                    pc.dt_pagamento,
                    pc.cpf_resp,
                    pc.hash_contrato,
                    pc.status_gennera,
                    pc.servico_nome,
                    pc.tipo,
                    pc.eh_recorrente,
                    pc.status_priority,
                    row_number() OVER (PARTITION BY pc.aluno_key, pc.calendario_academico, pc.fatura_ano, pc.parcela, pc.servico_nome, pc.valor_bruto, pc.dt_vencimento ORDER BY pc.status_priority, pc.hash_contrato) AS rn_dedup
                   FROM parcelas_classificadas pc
                  WHERE pc.eh_recorrente) x
          WHERE x.rn_dedup = 1
        UNION ALL
         SELECT pc.calendario_academico,
            pc.aluno_key,
            pc.item,
            pc.fatura_ano,
            pc.parcela,
            pc.valor_bruto,
            pc.valor_pagamento,
            pc.valor_desconto,
            pc.valor_juros,
            pc.valor_multa,
            pc.dt_vencimento,
            pc.dt_pagamento,
            pc.cpf_resp,
            pc.hash_contrato,
            pc.status_gennera,
            pc.servico_nome,
            pc.tipo,
            pc.eh_recorrente,
            pc.status_priority,
            1 AS rn_dedup
           FROM parcelas_classificadas pc
          WHERE NOT pc.eh_recorrente
        ), parcelas_marcadas AS (
         SELECT pd.calendario_academico,
            pd.aluno_key,
            pd.item,
            pd.fatura_ano,
            pd.parcela,
            pd.valor_bruto,
            pd.valor_pagamento,
            pd.valor_desconto,
            pd.valor_juros,
            pd.valor_multa,
            pd.dt_vencimento,
            pd.dt_pagamento,
            pd.cpf_resp,
            pd.hash_contrato,
            pd.status_gennera,
            pd.servico_nome,
            pd.tipo,
            pd.eh_recorrente,
            pd.status_priority,
            pd.rn_dedup,
                CASE
                    WHEN pd.status_gennera::text = 'pago a maior'::text THEN (('Pago a maior. Bruto: R$ '::text || replace(to_char(pd.valor_bruto, 'FM9999999990.00'::text), '.'::text, ','::text)) || ' Pago: R$ '::text) || replace(to_char(pd.valor_pagamento, 'FM9999999990.00'::text), '.'::text, ','::text)
                    WHEN pd.status_gennera::text = 'renegociado'::text THEN 'Renegociado - acordo gerou novo contrato'::text
                    WHEN pd.status_gennera::text = 'atrasado'::text THEN 'Em atraso'::text
                    ELSE NULL::text
                END AS obsparc
           FROM parcelas_dedup pd
        ), servicos_ranked AS (
         SELECT scu.code_unif AS ra,
            e.academic_calendar,
            c.id_contract,
            c.date,
            row_number() OVER (PARTITION BY scu.code_unif, e.academic_calendar ORDER BY c.date, c.id_contract) AS rank
           FROM gennera_stg.enrollment e
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
             JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
             JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
          WHERE COALESCE(ec.details, ''::text) !~~* '%mensalidad%'::text AND COALESCE(ec.details, ''::text) !~~* '%rematr%'::text AND COALESCE(ec.details, ''::text) !~~* '%anuid%'::text AND COALESCE(ec.details, ''::text) !~~* '%atr%cula%'::text
          GROUP BY scu.code_unif, e.academic_calendar, c.id_contract, c.date
        ), c_mens AS (
         SELECT DISTINCT ON (scu.code_unif, e.academic_calendar) scu.code_unif AS ra,
            e.academic_calendar,
            c.id_contract
           FROM gennera_stg.enrollment e
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
             JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
             JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
          WHERE ec.details ~~* '%mensalidad%'::text AND ec.details !~* '1[^[:space:]]{0,3}'::text
          ORDER BY scu.code_unif, e.academic_calendar, c.date
        ), c_rematr AS (
         SELECT DISTINCT ON (scu.code_unif, e.academic_calendar) scu.code_unif AS ra,
            e.academic_calendar,
            c.id_contract
           FROM gennera_stg.enrollment e
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
             JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
             JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
          WHERE ec.details ~~* '%rematr%'::text OR ec.details ~~* '%matr%cula%'::text
          ORDER BY scu.code_unif, e.academic_calendar, c.date
        ), contrato_por_tipo AS (
         SELECT c_mens.ra,
            c_mens.academic_calendar,
            'MENS'::text AS tipo,
            c_mens.id_contract
           FROM c_mens
        UNION ALL
         SELECT cr.ra,
            cr.academic_calendar,
            'MENS'::text,
            cr.id_contract
           FROM c_rematr cr
          WHERE NOT (EXISTS ( SELECT 1
                   FROM c_mens cm
                  WHERE cm.ra::text = cr.ra::text AND cm.academic_calendar = cr.academic_calendar))
        UNION ALL
         SELECT c_rematr.ra,
            c_rematr.academic_calendar,
            'REMATR'::text,
            c_rematr.id_contract
           FROM c_rematr
        UNION ALL
         SELECT servicos_ranked.ra,
            servicos_ranked.academic_calendar,
            'SERVIC'::text,
            servicos_ranked.id_contract
           FROM servicos_ranked
          WHERE servicos_ranked.rank = 1
        UNION ALL
         SELECT servicos_ranked.ra,
            servicos_ranked.academic_calendar,
            'SERVIC_EXTRA'::text,
            servicos_ranked.id_contract
           FROM servicos_ranked
          WHERE servicos_ranked.rank = 2
        UNION ALL
         SELECT sr.ra,
            sr.academic_calendar,
            'SERVIC_EXTRA'::text,
            sr.id_contract
           FROM servicos_ranked sr
          WHERE sr.rank = 1 AND NOT (EXISTS ( SELECT 1
                   FROM servicos_ranked sr2
                  WHERE sr2.ra::text = sr.ra::text AND sr2.academic_calendar = sr.academic_calendar AND sr2.rank = 2))
        UNION ALL
         SELECT cm.ra,
            cm.academic_calendar,
            'SERVIC'::text,
            cm.id_contract
           FROM c_mens cm
          WHERE NOT (EXISTS ( SELECT 1
                   FROM servicos_ranked sr
                  WHERE sr.ra::text = cm.ra::text AND sr.academic_calendar = cm.academic_calendar AND sr.rank = 1))
        UNION ALL
         SELECT cr.ra,
            cr.academic_calendar,
            'SERVIC'::text,
            cr.id_contract
           FROM c_rematr cr
          WHERE NOT (EXISTS ( SELECT 1
                   FROM c_mens cm
                  WHERE cm.ra::text = cr.ra::text AND cm.academic_calendar = cr.academic_calendar)) AND NOT (EXISTS ( SELECT 1
                   FROM servicos_ranked sr
                  WHERE sr.ra::text = cr.ra::text AND sr.academic_calendar = cr.academic_calendar AND sr.rank = 1))
        UNION ALL
         SELECT cm.ra,
            cm.academic_calendar,
            'SERVIC_EXTRA'::text,
            cm.id_contract
           FROM c_mens cm
          WHERE NOT (EXISTS ( SELECT 1
                   FROM servicos_ranked sr
                  WHERE sr.ra::text = cm.ra::text AND sr.academic_calendar = cm.academic_calendar))
        UNION ALL
         SELECT cr.ra,
            cr.academic_calendar,
            'SERVIC_EXTRA'::text,
            cr.id_contract
           FROM c_rematr cr
          WHERE NOT (EXISTS ( SELECT 1
                   FROM c_mens cm
                  WHERE cm.ra::text = cr.ra::text AND cm.academic_calendar = cr.academic_calendar)) AND NOT (EXISTS ( SELECT 1
                   FROM servicos_ranked sr
                  WHERE sr.ra::text = cr.ra::text AND sr.academic_calendar = cr.academic_calendar))
        )
 SELECT 1 AS "CODCOLIGADA",
    a."CODCURSO"::character varying(10) AS "CODCURSO",
    a."CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
    a."CODGRADE"::character varying(10) AS "CODGRADE",
    a."TURNO"::character varying(15) AS "TURNO",
    a.codfilial AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    a.ra::character varying(20) AS "RA",
    a.academic_calendar::character varying(10) AS "CODPERLET",
    ct.id_contract::character varying(20) AS "CODCONTRATO",
    "left"(p.servico_nome, 60)::character varying(60) AS "SERVICO",
    p.parcela AS "PARCELA",
    1 AS "COTA",
    replace(to_char(p.valor_bruto, 'FM9999999990.00'::text), '.'::text, ','::text) AS "VALOR",
    to_char(p.dt_vencimento::timestamp with time zone, 'YYYY-MM-DD'::text)::character varying(10) AS "DTVENCIMENTO",
    replace(to_char(p.valor_desconto, 'FM9999999990.00'::text), '.'::text, ','::text) AS "DESCONTO",
    'V'::character varying(1) AS "TIPODESC",
    'P'::character varying(1) AS "TIPOPARCELA",
    'N'::character varying(1) AS "VALORAUTOMATICO",
    to_char(make_date(a.academic_calendar::integer, COALESCE(NULLIF(p.parcela, 0), 1), 1)::timestamp with time zone, 'YYYY-MM-DD'::text)::character varying(10) AS "DTCOMPETENCIA",
    1 AS "CODCOLCFO",
    lpad(f."CODCFO", 6, '0'::text)::character varying(25) AS "CODCFO",
    p.status_gennera::character varying(20) AS "STATUSGENNERA",
    replace(to_char(p.valor_pagamento, 'FM9999999990.00'::text), '.'::text, ','::text) AS "VALORPAGO",
    replace(to_char(p.valor_juros, 'FM9999999990.00'::text), '.'::text, ','::text) AS "VALORJUROS",
    replace(to_char(p.valor_multa, 'FM9999999990.00'::text), '.'::text, ','::text) AS "VALORMULTA",
    to_char(p.dt_pagamento::timestamp with time zone, 'YYYY-MM-DD'::text)::character varying(10) AS "DATAPAGAMENTO",
    p.hash_contrato::character varying(32) AS "HASHCONTRATO_ORIG",
    p.obsparc::character varying(255) AS "OBSPARC"
   FROM parcelas_marcadas p
     JOIN alunos a ON a.name_key = p.aluno_key AND a.academic_calendar = p.calendario_academico
     LEFT JOIN contrato_por_tipo ct ON ct.ra::text = a.ra::text AND ct.academic_calendar = p.calendario_academico AND ct.tipo = p.tipo
     LEFT JOIN export.fcfo f ON f."CGCCFO" = p.cpf_resp
  WHERE p.valor_bruto IS NOT NULL AND p.dt_vencimento IS NOT NULL AND ct.id_contract IS NOT NULL;;
