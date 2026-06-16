-- ============================================================================
-- View: export.scontrato
-- Esquema destino TOTVS: SCONTRATO
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

CREATE OR REPLACE VIEW export.scontrato AS
WITH ec_dedup AS (
         SELECT DISTINCT enrollment_contract.id_enrollment,
            enrollment_contract.id_contract,
            enrollment_contract.details
           FROM gennera_stg.enrollment_contract
        ), contratos_dedup AS (
         SELECT DISTINCT ON (ec.id_contract) ec.id_enrollment,
            ec.id_contract,
            ec.details,
            c.date,
            c.status
           FROM ec_dedup ec
             JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
          ORDER BY ec.id_contract, (
                CASE
                    WHEN ec.details ~~* '%mensalidad%'::text THEN 1
                    WHEN ec.details ~~* '%rematr%'::text THEN 2
                    WHEN ec.details ~~* '%servi%'::text THEN 3
                    WHEN ec.details ~~* '%aliment%'::text THEN 4
                    WHEN ec.details ~~* '%material%'::text THEN 5
                    WHEN ec.details ~~* '%contrato%'::text THEN 6
                    ELSE 9
                END), ec.details
        ), alunos AS (
         SELECT e.id_enrollment,
            e.id_person,
            e.academic_calendar,
            e.class_name,
            scu.code_unif,
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
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
             JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
          WHERE (inst.code = ANY (ARRAY['un1'::text, 'un2'::text])) AND scu.code_unif IS NOT NULL AND e.academic_calendar IS NOT NULL
        ), plano_ranking AS (
         SELECT shabmodelopgto."CODPLANOPGTO",
            shabmodelopgto."CODFILIAL",
            shabmodelopgto."CODCURSO",
            shabmodelopgto."IDHABILITACAOFILIAL",
            shabmodelopgto."CODGRADE",
            shabmodelopgto."CODTURNO",
            shabmodelopgto."IDPERLET",
            count(*) OVER (PARTITION BY shabmodelopgto."CODPLANOPGTO") AS cobertura
           FROM export.shabmodelopgto
        ), plano_por_combo AS (
         SELECT DISTINCT ON (plano_ranking."CODFILIAL", plano_ranking."CODCURSO", plano_ranking."IDHABILITACAOFILIAL", plano_ranking."CODGRADE", plano_ranking."CODTURNO", plano_ranking."IDPERLET") plano_ranking."CODFILIAL",
            plano_ranking."CODCURSO",
            plano_ranking."IDHABILITACAOFILIAL",
            plano_ranking."CODGRADE",
            plano_ranking."CODTURNO",
            plano_ranking."IDPERLET",
            plano_ranking."CODPLANOPGTO"
           FROM plano_ranking
          ORDER BY plano_ranking."CODFILIAL", plano_ranking."CODCURSO", plano_ranking."IDHABILITACAOFILIAL", plano_ranking."CODGRADE", plano_ranking."CODTURNO", plano_ranking."IDPERLET", plano_ranking.cobertura, plano_ranking."CODPLANOPGTO"
        )
 SELECT 1 AS "CODCOLIGADA",
    a."CODCURSO"::character varying(10) AS "CODCURSO",
    a."CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
    a."CODGRADE"::character varying(10) AS "CODGRADE",
    a."TURNO"::character varying(15) AS "TURNO",
    a.codfilial AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    a.code_unif::character varying(20) AS "RA",
    a.academic_calendar::character varying(10) AS "CODPERLET",
    cd.id_contract::character varying(20) AS "CODCONTRATO",
    pc."CODPLANOPGTO",
    to_char(cd.date, 'YYYY-MM-DD'::text)::character varying(10) AS "DTCONTRATO",
    to_char(cd.date, 'YYYY-MM-DD'::text)::character varying(10) AS "DTASSINATURA",
    'N'::character varying(1) AS "DIAFIXO",
    10 AS "DIAVENCIMENTO",
        CASE
            WHEN cd.details ~~* '%mensalidad%'::text OR cd.details ~~* '%rematr%'::text OR cd.details ~~* '%contrato%'::text THEN 'P'::text
            ELSE 'S'::text
        END::character varying(1) AS "TIPOCONTRATO",
    'S'::character varying(1) AS "TIPOBOLSA",
    NULL::character varying(25) AS "CODCCUSTO",
    'S'::character varying(1) AS "ASSINADO",
        CASE
            WHEN cd.status = 'deleted'::text THEN 'S'::text
            ELSE 'N'::text
        END::character varying(1) AS "STATUS",
    NULL::date AS "DTCANCELAMENTO"
   FROM alunos a
     JOIN contratos_dedup cd ON cd.id_enrollment = a.id_enrollment
     LEFT JOIN plano_por_combo pc ON pc."CODFILIAL" = a.codfilial AND pc."CODCURSO"::text = a."CODCURSO" AND pc."IDHABILITACAOFILIAL"::text = a."CODHABILITACAO"::text AND pc."CODGRADE"::text = a."CODGRADE"::text AND pc."CODTURNO"::text = a."TURNO" AND pc."IDPERLET"::text = a.academic_calendar;;
