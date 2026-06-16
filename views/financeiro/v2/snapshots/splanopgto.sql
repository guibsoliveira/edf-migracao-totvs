-- ============================================================================
-- View: export_v2.splanopgto
-- Esquema destino TOTVS: SPLANOPGTO
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

CREATE OR REPLACE VIEW export_v2.splanopgto AS
WITH segmentos_base AS (
         SELECT DISTINCT e.academic_calendar AS ano,
                CASE inst.code
                    WHEN 'un1'::text THEN 1
                    ELSE 2
                END AS codfilial,
                CASE
                    WHEN inst.code = 'un1'::text AND st."CODCURSO" = 'EF1'::text THEN 'EF1 3º / 5º ANO'::text
                    WHEN inst.code = 'un1'::text AND st."CODCURSO" = 'EF2'::text THEN 'EF2 6º / 9º ANO'::text
                    WHEN inst.code = 'un1'::text AND st."CODCURSO" = 'EM'::text THEN 'EM 1º / 3º ANO'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND st."TURNO" = 'Integral'::text AND st."CODHABILITACAO" >= 3 THEN 'EI INTEGRAL K1, K2'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND st."TURNO" = 'Integral'::text AND st."CODHABILITACAO" <= 2 THEN 'EI INTEGRAL N2, N3'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND (st."TURNO" = ANY (ARRAY['Manha'::text, 'Tarde'::text])) AND st."CODHABILITACAO" >= 3 THEN 'EI MEIO PERIODO K1, K2'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND (st."TURNO" = ANY (ARRAY['Manha'::text, 'Tarde'::text])) AND st."CODHABILITACAO" <= 2 THEN 'EI MEIO PERIODO N2, N3'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EF1'::text AND st."CODHABILITACAO" = 1 THEN 'EF1 1º ANO'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EF1'::text AND st."CODHABILITACAO" = 2 THEN 'EF1 2º ANO'::text
                    ELSE NULL::text
                END AS segmento_nome
           FROM gennera_stg.enrollment e
             JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
             JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
          WHERE (inst.code = ANY (ARRAY['un1'::text, 'un2'::text])) AND e.academic_calendar IS NOT NULL AND e.academic_calendar >= '2021'::text
        ), planos_distinct AS (
         SELECT DISTINCT segmentos_base.ano,
            segmentos_base.codfilial,
            segmentos_base.segmento_nome
           FROM segmentos_base
          WHERE segmentos_base.segmento_nome IS NOT NULL
        ), planos_2026 AS (
         SELECT "substring"(ai.description, '^(\d{4})'::text) AS ano,
                CASE
                    WHEN ai.id_institution = 320 THEN 1
                    ELSE 2
                END AS codfilial,
                CASE
                    WHEN ai.id_institution = 320 AND ai.description ~* '\m(EM|ENSINO\s*M.DIO)\M'::text THEN 'EM 1º / 3º ANO'::text
                    WHEN ai.id_institution = 320 AND ai.description ~* '\m(F2|EF2|FUND.*\s*2)\M'::text THEN 'EF2 6º / 9º ANO'::text
                    WHEN ai.id_institution = 320 AND ai.description ~* '\m(F1|EF1|FUND.*\s*1)\M'::text THEN 'EF1 3º / 5º ANO'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*INTEGRAL\s*K1'::text THEN 'EI INTEGRAL K1, K2'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*INTEGRAL\s*N2'::text THEN 'EI INTEGRAL N2, N3'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*MEIO\s*PERIODO\s*K1'::text THEN 'EI MEIO PERIODO K1, K2'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*MEIO\s*PERIODO\s*N2'::text THEN 'EI MEIO PERIODO N2, N3'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* '\m(1.{0,3}\s*ANO|FUND\s*1\s*-?\s*1)\M'::text THEN 'EF1 1º ANO'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* '\m(2.{0,3}\s*ANO|FUND\s*1\s*-?\s*2)\M'::text THEN 'EF1 2º ANO'::text
                    ELSE NULL::text
                END AS segmento_nome
           FROM gennera_stg.api_items ai
          WHERE ai.description ~ '^2026\s+MENS\s+'::text AND ai.description !~~* '%ANUID%'::text AND ai.description !~* '^2026\s+1\s*[º°.ª]?\s*MENS'::text
        ), unificado AS (
         SELECT planos_distinct.ano,
            planos_distinct.codfilial,
            planos_distinct.segmento_nome
           FROM planos_distinct
        UNION
         SELECT planos_2026.ano,
            planos_2026.codfilial,
            planos_2026.segmento_nome
           FROM planos_2026
        ), ranked AS (
         SELECT u.ano,
            u.codfilial,
            u.segmento_nome,
            row_number() OVER (PARTITION BY u.ano, u.codfilial ORDER BY u.segmento_nome) AS seq
           FROM unificado u
        )
 SELECT 1 AS "CODCOLIGADA",
    ano::character varying(10) AS "CODPERLET",
    ((("right"(ano, 2) || codfilial::text) || lpad(seq::text, 3, '0'::text)))::character varying(10) AS "CODPLANOPGTO",
    "left"((segmento_nome || ' '::text) || ano, 60)::character varying(60) AS "DESCRICAO",
    "left"((segmento_nome || ' '::text) || ano, 60)::character varying(60) AS "NOME",
    (ano || '-01-01'::text)::date AS "DTINICIO",
    (ano || '-12-31'::text)::date AS "DTFIM",
    0::numeric(10,4) AS "DESCONTO",
    1 AS "CODTIPOCURSO",
    codfilial AS "CODFILIAL",
    'N'::character varying(1) AS "MATRICULALIVRE",
    NULL::character varying(1) AS "TIPOBLOQUEIOVLRBASEPERSONALIZ"
   FROM ranked r
  ORDER BY ano, codfilial, seq;;
