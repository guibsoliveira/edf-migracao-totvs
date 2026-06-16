-- ============================================================================
-- View: export.sbolsaaluno
-- Esquema destino TOTVS: SBOLSAALUNO
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

CREATE OR REPLACE VIEW export.sbolsaaluno AS
WITH alunos AS (
         SELECT upper(TRIM(BOTH FROM pf.name)) AS name_key,
            e.id_enrollment,
            e.id_person,
            e.academic_calendar,
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
        ), bolsas_raw AS (
         SELECT bd.calendario_academico,
            upper(TRIM(BOTH FROM bd.aluno)) AS aluno_key,
            bd.item_descricao AS servico,
                CASE
                    WHEN bd.desconto_descricao::text ~~* 'desconto comercial %'::text THEN 'DESCONTO COMERCIAL VARIAVEL'::text
                    ELSE upper(TRIM(BOTH FROM bd.desconto_descricao))
                END AS nome_bolsa,
            bd.desconto_forma_calculo AS forma,
            COALESCE(NULLIF(TRIM(BOTH FROM bd.fatura_mes), ''::text)::integer, 1) AS parcela,
            NULLIF(TRIM(BOTH FROM bd.desconto_percentual), ''::text)::numeric AS percentual,
            NULLIF(replace(replace(replace(COALESCE(bd.valor_aplicado, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric AS valor_aplicado,
            bd.categoria_desconto,
                CASE
                    WHEN bd.item_descricao::text ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'::text AND bd.item_descricao::text !~* '^\s*(MENS|PARC)'::text THEN 'REMATR'::text
                    WHEN bd.item_descricao::text ~~* '%ANUID%'::text THEN 'MENS'::text
                    WHEN bd.item_descricao::text ~~* '%MENS%'::text THEN 'MENS'::text
                    WHEN bd.item_descricao::text ~~* '%ALIM%'::text OR bd.item_descricao::text ~~* '%MAT%DIDAT%'::text OR bd.item_descricao::text ~~* '%MDIDAT%'::text OR bd.item_descricao::text ~~* '%MDIAT%'::text OR bd.item_descricao::text ~* '^\s*MD\s'::text OR bd.item_descricao::text ~~* '%MATERIAIS%'::text THEN 'SERVIC'::text
                    ELSE 'SERVIC_EXTRA'::text
                END AS tipo
           FROM gennera_stg.bolsas_descontos bd
          WHERE bd.calendario_academico IS NOT NULL AND bd.aluno IS NOT NULL AND bd.item_descricao IS NOT NULL AND bd.desconto_descricao IS NOT NULL AND COALESCE(bd.situacao, ''::character varying)::text = 'aplicado'::text
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
         SELECT c_rematr.ra,
            c_rematr.academic_calendar,
            'REMATR'::text AS text,
            c_rematr.id_contract
           FROM c_rematr
        UNION ALL
         SELECT servicos_ranked.ra,
            servicos_ranked.academic_calendar,
            'SERVIC'::text AS text,
            servicos_ranked.id_contract
           FROM servicos_ranked
          WHERE servicos_ranked.rank = 1
        UNION ALL
         SELECT servicos_ranked.ra,
            servicos_ranked.academic_calendar,
            'SERVIC_EXTRA'::text AS text,
            servicos_ranked.id_contract
           FROM servicos_ranked
          WHERE servicos_ranked.rank = 2
        UNION ALL
         SELECT sr.ra,
            sr.academic_calendar,
            'SERVIC_EXTRA'::text AS text,
            sr.id_contract
           FROM servicos_ranked sr
          WHERE sr.rank = 1 AND NOT (EXISTS ( SELECT 1
                   FROM servicos_ranked sr2
                  WHERE sr2.ra::text = sr.ra::text AND sr2.academic_calendar = sr.academic_calendar AND sr2.rank = 2))
        ), bolsas_validas AS (
         SELECT b.calendario_academico,
            b.aluno_key,
            b.servico,
            b.nome_bolsa,
            b.forma,
            b.parcela,
            b.percentual,
            b.valor_aplicado,
            b.categoria_desconto,
            b.tipo
           FROM bolsas_raw b
          WHERE (EXISTS ( SELECT 1
                   FROM export.sservico s
                  WHERE s."NOME"::text = b.servico::text)) AND (EXISTS ( SELECT 1
                   FROM export.sbolsa sb
                  WHERE sb."NOME"::text = b.nome_bolsa))
        ), bolsas_agg AS (
         SELECT a.codfilial,
            a."CODCURSO",
            a."CODHABILITACAO",
            a."CODGRADE",
            a."TURNO",
            a.ra,
            a.academic_calendar,
            ct.id_contract,
            b.servico,
            b.nome_bolsa,
            b.forma,
            min(b.parcela) AS parcela_inicial,
            max(b.parcela) AS parcela_final,
            min(b.percentual) AS percentual_val,
            min(b.valor_aplicado) AS valor_val,
            min(b.categoria_desconto::text) AS categoria,
            count(*) AS aplicacoes
           FROM bolsas_validas b
             JOIN alunos a ON a.name_key = b.aluno_key AND a.academic_calendar = b.calendario_academico
             JOIN contrato_por_tipo ct ON ct.ra::text = a.ra::text AND ct.academic_calendar = b.calendario_academico AND ct.tipo = b.tipo
          GROUP BY a.codfilial, a."CODCURSO", a."CODHABILITACAO", a."CODGRADE", a."TURNO", a.ra, a.academic_calendar, ct.id_contract, b.servico, b.nome_bolsa, b.forma
        )
 SELECT 1 AS "CODCOLIGADA",
    "CODCURSO"::character varying(10) AS "CODCURSO",
    "CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
    "CODGRADE"::character varying(10) AS "CODGRADE",
    "TURNO"::character varying(15) AS "TURNO",
    codfilial AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    ra::character varying(20) AS "RA",
    academic_calendar::character varying(10) AS "CODPERLET",
    id_contract::character varying(20) AS "CODCONTRATO",
    "left"(nome_bolsa, 60)::character varying(60) AS "NOMEBOLSA",
    "left"(servico::text, 60)::character varying(60) AS "SERVICO",
    NULL::date AS "DTINICIO",
    NULL::date AS "DTFIM",
    replace(to_char(
        CASE
            WHEN forma::text = 'relativo'::text THEN COALESCE(percentual_val, 0::numeric)
            ELSE COALESCE(valor_val, 0::numeric)
        END, 'FM9999999990.0000'::text), '.'::text, ','::text)::character varying(20) AS "DESCONTO",
        CASE
            WHEN forma::text = 'relativo'::text THEN 'P'::text
            ELSE 'V'::text
        END::character varying(1) AS "TIPODESC",
    "left"(COALESCE(categoria, ''::text), 200) AS "OBS",
    parcela_inicial AS "PARCELAINICIAL",
    parcela_final AS "PARCELAFINAL",
    'mestre'::character varying(20) AS "CODUSUARIO",
    1 AS "ORDEMBOLSA",
    NULL::date AS "DATACONCESSAO",
    NULL::date AS "DATAAUTORIZACAO",
    NULL::numeric(10,4) AS "TETOVALOR",
    'S'::character varying(1) AS "ATIVA",
    NULL::date AS "DATACANCELAMENTO",
    NULL::character varying(20) AS "CODUSUARIOCANCEL",
    NULL::character varying(60) AS "MOTIVOCANCELAMENTO"
   FROM bolsas_agg;;
