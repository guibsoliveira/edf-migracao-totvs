-- ============================================================================
-- View: export.shabilitacaoaluno
-- Esquema destino TOTVS: SHABILITACAOALUNO
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

CREATE OR REPLACE VIEW export.shabilitacaoaluno AS
SELECT DISTINCT ON (scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODPERLET") st."CODCOLIGADA",
    st."CODCURSO",
    st."CODHABILITACAO",
    st."CODGRADE",
    st."TURNO",
    st."CODFILIAL",
    st."CODTIPOCURSO",
    scu.code_unif::character varying(20) AS "RA",
    NULL::character varying(60) AS "INGRESSO",
    NULL::character varying(60) AS "INSTITUICAO",
        CASE
            WHEN e.status = 'cancelled'::text THEN 'Cancelado'::text
            WHEN e.academic_calendar::integer < EXTRACT(year FROM CURRENT_DATE)::integer THEN 'ConcluÃ­do'::text
            WHEN e.status = 'active'::text THEN 'Cursando'::text
            WHEN e.status = 'open'::text THEN 'Cursando'::text
            WHEN e.status = 'reserved'::text THEN 'Matriculado'::text
            WHEN e.status = 'closed'::text THEN 'ConcluÃ­do'::text
            ELSE 'Cursando'::text
        END::character varying(30) AS "STATUS",
    NULL::date AS "DTINGRESSO",
    NULL::character varying(10) AS "PONTOSVESTIBULAR",
    NULL::character varying(20) AS "CLASSIFICACAOVESTIBULAR",
    NULL::numeric(10,4) AS "MEDIAVESTIBULAR",
    NULL::date AS "DTCOLACAOGRAU",
    NULL::date AS "DTEMISDIPLOMA",
    NULL::character varying(10) AS "REGISTROCONCLUSAO",
    NULL::character varying(10) AS "LIVROREGISTRO",
    NULL::character varying(10) AS "PAGINAREGISTRO",
    NULL::date AS "DTCONCLUSAOCURSO",
    NULL::numeric(10,4) AS "CR",
    NULL::numeric(10,4) AS "MEDIAGLOBAL",
    NULL::date AS "DTPROVAO",
    NULL::character varying(20) AS "PROCESSOREGISTRO",
    NULL::character varying(60) AS "INSTITUICAODIPLOMA",
    NULL::character varying(1) AS "REALIZOUPROVAO",
    NULL::character varying(10) AS "CODCURSOTRANSF",
    NULL::character varying(10) AS "CODHABILITACAOTRANSF",
    NULL::character varying(10) AS "CODGRADETRANSF",
    NULL::character varying(15) AS "TURNOTRANSF",
    NULL::integer AS "CODTIPOCURSOTRANSF",
    NULL::integer AS "CODFILIALTRANSF",
    NULL::character varying(60) AS "MOTIVOTRANSF",
    NULL::numeric(10,4) AS "INDICECARENCIA",
    NULL::text AS "OBSERVACAO",
    NULL::integer AS "CODINSTITUICAO",
    NULL::integer AS "CODINSTTITUICAODIPLOMA",
    NULL::character varying(100) AS "CAMPUS",
    NULL::character varying(100) AS "LOCALIZACAOFISICA"
   FROM gennera_stg.enrollment e
     JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
  WHERE scu.code_unif IS NOT NULL
  ORDER BY scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODPERLET", (
        CASE e.status
            WHEN 'active'::text THEN 1
            WHEN 'open'::text THEN 2
            WHEN 'reserved'::text THEN 3
            WHEN 'cancelled'::text THEN 4
            WHEN 'closed'::text THEN 5
            ELSE 6
        END);;
