-- ============================================================================
-- View: export.spletivo
-- Esquema destino TOTVS: SPLETIVO
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

CREATE OR REPLACE VIEW export.spletivo AS
WITH anos AS (
         SELECT period.reference_year,
            min(period.academic_calendar_start_date) AS dt_ini,
            max(period.academic_calendar_end_date) AS dt_fim
           FROM gennera_stg.period
          WHERE period.reference_year IS NOT NULL
          GROUP BY period.reference_year
        ), filiais(filial) AS (
         VALUES ('1'::text), ('2'::text)
        )
 SELECT '1'::text AS "CODCOLIGADA",
    f.filial AS "CODFILIAL",
    '1'::text AS "CODTIPOCURSO",
    a.reference_year AS "CODPERLET",
    a.reference_year AS "DESCRICAO",
    NULL::text AS "DIASLETIVOS",
    NULL::text AS "CARGAHORARIA",
    NULL::text AS "OBS",
    'N'::text AS "ENCERRADO",
    to_char(to_date(split_part(a.dt_ini, 'T'::text, 1), 'YYYY-MM-DD'::text)::timestamp with time zone, 'YYYY-MM-DD'::text) AS "DTINICIO",
    to_char(to_date(split_part(a.dt_fim, 'T'::text, 1), 'YYYY-MM-DD'::text)::timestamp with time zone, 'YYYY-MM-DD'::text) AS "DTPREVISTA",
    NULL::text AS "DTFIM",
    NULL::text AS "CALENDARIO",
    NULL::text AS "CODPERLETANT",
    NULL::text AS "ENCERRADOPGTO",
    NULL::text AS "DTCOMPETENCIAINICIAL",
    NULL::text AS "DTCOMPETENCIAFINAL",
    NULL::text AS "DTCOMPETENCIAINICIALMOV",
    NULL::text AS "DTCOMPETENCIAFINALMOV",
    NULL::text AS "ENCERRADOCONTABIL",
    'S'::text AS "EXIBIRPORTAL",
    NULL::text AS "ENCERRADOFINANCEIRO",
    'S'::text AS "EXIBIRPORTALALUNO"
   FROM anos a
     CROSS JOIN filiais f
  ORDER BY f.filial, a.reference_year;;
