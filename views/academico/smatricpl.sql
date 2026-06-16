-- ============================================================================
-- View: export.smatricpl
-- Esquema destino TOTVS: SMATRICPL
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

CREATE OR REPLACE VIEW export.smatricpl AS
SELECT DISTINCT ON (scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODTURMA", st."CODPERLET") st."CODCOLIGADA",
    st."CODCURSO",
    st."CODHABILITACAO",
    st."CODGRADE",
    st."TURNO",
    st."CODFILIAL",
    st."CODTIPOCURSO",
    st."CODTURMA",
    st."CODPERLET",
    scu.code_unif::character varying(20) AS "RA",
    NULL::character varying(30) AS "STATUSRES",
        CASE
            WHEN e.status = 'cancelled'::text THEN 'Cancelado'::text
            WHEN e.status = 'reserved'::text THEN 'Reservado'::text
            WHEN e.status = 'open'::text THEN 'Aberto'::text
            WHEN e.status = 'active'::text THEN 'Ativo'::text
            WHEN e.status = 'closed'::text THEN 'Ativo'::text
            ELSE 'Ativo'::text
        END::character varying(30) AS "STATUS",
    e.date::date AS "DTMATRICULA",
    NULL::date AS "DTRESULTADO",
    NULL::character varying(15) AS "IDENTIFICADOR",
    NULL::character varying(20) AS "NUMCARTEIRA",
    NULL::character varying(1) AS "CARTEIRAEMITIDA",
    NULL::character varying(20) AS "VIACARTEIRA",
    1 AS "PERIODO",
    NULL::integer AS "NUMALUNO",
    NULL::character varying(60) AS "DESCTIPOMAT",
    NULL::character varying(1) AS "SELINSTENADE",
    NULL::character varying(1) AS "SELMECENADE",
    NULL::date AS "DTPROVAENADE",
    NULL::character varying(1) AS "COMPARECEUENADE",
    NULL::text AS "OBSENADE",
    NULL::date AS "DTMATRICULAENCERRA"
   FROM gennera_stg.enrollment e
     JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
  WHERE scu.code_unif IS NOT NULL
  ORDER BY scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODTURMA", st."CODPERLET", (
        CASE e.status
            WHEN 'active'::text THEN 1
            WHEN 'open'::text THEN 2
            WHEN 'reserved'::text THEN 3
            WHEN 'cancelled'::text THEN 4
            WHEN 'closed'::text THEN 5
            ELSE 6
        END);;
