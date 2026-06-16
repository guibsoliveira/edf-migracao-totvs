-- ============================================================================
-- View: export.smatricula
-- Esquema destino TOTVS: SMATRICULA
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

CREATE OR REPLACE VIEW export.smatricula AS
SELECT DISTINCT sd."CODCOLIGADA",
    sd."CODCURSO",
    sd."CODHABILITACAO",
    sd."CODGRADE",
    sd."TURNO",
    sd."CODFILIAL",
    sd."CODTIPOCURSO",
    sd."CODTURMA",
    sd."CODPERLET",
    sd."CODDISC",
    scu.code_unif::character varying(20) AS "RA",
        CASE er.subject_status
            WHEN 'APPROVED'::text THEN 'Aprovado'::text
            WHEN 'FAILED'::text THEN 'Reprovado'::text
            ELSE NULL::text
        END::character varying(30) AS "STATUSRES",
        CASE
            WHEN er.subject_status = 'CANCELLED'::text THEN 'Cancelado'::text
            WHEN er.subject_status = 'APPROVED'::text THEN 'Aprovado'::text
            WHEN er.subject_status = 'FAILED'::text THEN 'Reprovado'::text
            WHEN er.subject_status = 'IN PROGRESS'::text AND e.academic_calendar::integer < EXTRACT(year FROM CURRENT_DATE)::integer THEN 'Aprovado'::text
            WHEN er.subject_status = 'IN PROGRESS'::text THEN 'Ativo'::text
            ELSE 'Ativo'::text
        END::character varying(30) AS "STATUS",
    NULL::integer AS "NUMDIARIO",
    to_char((e.date AT TIME ZONE 'America/Sao_Paulo'::text), 'YYYY-MM-DD HH24:MI:SS'::text)::character varying(19) AS "DTMATRICULA",
    NULL::character varying(255) AS "OBSHISTORICO",
    NULL::character varying(60) AS "TIPOMAT",
    'N'::character varying(1) AS "TIPODISCIPLINA",
    NULL::character varying(10) AS "DTALTERACAO",
    NULL::character varying(10) AS "DTALTERACAOSIST",
    NULL::character varying(20) AS "CODSUBTURMA",
    NULL::numeric AS "NUMCREDITOSCOB",
    'N'::character varying(1) AS "COBPOSTERIORMATRIC",
    NULL::character varying(20) AS "CODTURMAORIGEM",
    NULL::character varying(20) AS "CODDISCORIGEM",
    NULL::character varying(20) AS "CODTURMAPRINCIPAL",
    NULL::character varying(20) AS "CODDISCPRINCIPAL"
   FROM gennera_stg.enrollment_record er
     JOIN gennera_stg.enrollment e ON e.id_enrollment = er.id_enrollment
     JOIN export.sturmadisc sd ON sd."CODTURMA"::text = e.class_name AND sd."CODPERLET"::text = e.academic_calendar AND sd."CODDISC"::text = er.disc_code
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
  WHERE (er.institution_name = ANY (ARRAY['Escola do Futuro'::text, 'Escola do Futuro - Unidade 1'::text, 'Escola do Futuro - Unidade 2'::text])) AND scu.code_unif IS NOT NULL AND er.disc_code IS NOT NULL;;
