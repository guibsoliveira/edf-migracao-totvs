-- ============================================================================
-- View: export.setapas
-- Esquema destino TOTVS: SETAPAS
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

CREATE OR REPLACE VIEW export.setapas AS
WITH etapas(codetapa, descricao) AS (
         VALUES (1,'1º Trimestre'::text), (2,'2º Trimestre'::text), (3,'3º Trimestre'::text), (4,'Recuperação Anual'::text)
        )
 SELECT COALESCE(sd."CODCOLIGADA", s."CODCOLIGADA") AS "CODCOLIGADA",
    s."CODCURSO",
    s."CODHABILITACAO",
    s."CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    s."CODPERLET",
    sd."CODTURMA",
    sd."CODDISC",
    e.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
    e.descricao::character varying(60) AS "DESCRICAO",
    NULL::numeric AS "PONTDIST",
    NULL::numeric AS "MEDIA",
    NULL::numeric AS "FREQMIN",
    NULL::date AS "DTINICIO",
    NULL::date AS "DTFIM",
    NULL::date AS "DTINICIODIGITACAO",
    NULL::date AS "DTLIMITEDIGITACAO",
    'N'::character varying(1) AS "DIGAULASDADAS",
    COALESCE(sp."EXIBIRPORTAL", 'S'::text)::character varying(1) AS "EXIBENAWEB",
    'N'::character varying(1) AS "ETAPAFINAL",
    NULL::text AS "TITULO",
    NULL::integer AS "AULASDADAS",
    NULL::integer AS "AULASPREVISTAS",
    NULL::character varying(1) AS "CONCEITOGRAFICO",
    NULL::character varying(1) AS "EXIBENOGRAFICO",
    NULL::date AS "DTLIMITECONTPREVISTO",
    NULL::date AS "DTLIMITECONTEFETIVO",
    NULL::character varying(1) AS "DISPONIVELALUNOS",
    NULL::character varying(1) AS "ETAPAENCERRADA"
   FROM export.sturmadisc sd
     JOIN export.sturma s ON s."CODTURMA" = sd."CODTURMA"::text AND s."CODPERLET" = sd."CODPERLET"::text
     LEFT JOIN export.spletivo sp ON sp."CODPERLET" = s."CODPERLET" AND sp."CODFILIAL" = s."CODFILIAL"::text
     CROSS JOIN etapas e;;
