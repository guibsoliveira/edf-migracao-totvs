-- ============================================================================
-- View: export.shorarioturma
-- Esquema destino TOTVS: SHORARIOTURMA
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

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.shorarioturma)
-- Recriar exige: DROP MATERIALIZED VIEW export.shorarioturma; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.shorarioturma AS
WITH qh AS (
         SELECT DISTINCT TRIM(BOTH FROM qh."CALENDARIO"::text) AS ano,
            upper(regexp_replace(TRIM(BOTH FROM qh."TURMA"::text), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) AS turma_key,
                CASE translate(lower(TRIM(BOTH FROM qh."DIA"::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text)
                    WHEN 'domingo'::text THEN 1
                    WHEN 'sunday'::text THEN 1
                    WHEN 'segunda'::text THEN 2
                    WHEN 'segunda-feira'::text THEN 2
                    WHEN 'monday'::text THEN 2
                    WHEN 'terca'::text THEN 3
                    WHEN 'terca-feira'::text THEN 3
                    WHEN 'tuesday'::text THEN 3
                    WHEN 'quarta'::text THEN 4
                    WHEN 'quarta-feira'::text THEN 4
                    WHEN 'wednesday'::text THEN 4
                    WHEN 'quinta'::text THEN 5
                    WHEN 'quinta-feira'::text THEN 5
                    WHEN 'thursday'::text THEN 5
                    WHEN 'sexta'::text THEN 6
                    WHEN 'sexta-feira'::text THEN 6
                    WHEN 'friday'::text THEN 6
                    WHEN 'sabado'::text THEN 7
                    WHEN 'saturday'::text THEN 7
                    ELSE NULL::integer
                END AS diasemana,
            TRIM(BOTH FROM qh."INICIO"::text)::time without time zone AS horainicial,
            TRIM(BOTH FROM qh."FIM"::text)::time without time zone AS horafinal,
            regexp_replace(translate(lower(TRIM(BOTH FROM qh."DISCIPLINA"::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS disc_norm,
            regexp_replace(translate(lower(TRIM(BOTH FROM regexp_replace(qh."DISCIPLINA"::text, '\s*\(.*\)\s*$'::text, ''::text, 'g'::text))), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS disc_clean_norm
           FROM gennera_stg.professor_quadro_horarios qh
          WHERE qh."CALENDARIO" IS NOT NULL AND qh."TURMA" IS NOT NULL AND qh."DISCIPLINA" IS NOT NULL AND qh."DIA" IS NOT NULL AND qh."INICIO" IS NOT NULL AND qh."FIM" IS NOT NULL AND TRIM(BOTH FROM qh."CALENDARIO"::text) <> ''::text AND TRIM(BOTH FROM qh."TURMA"::text) <> ''::text AND TRIM(BOTH FROM qh."DISCIPLINA"::text) <> ''::text AND upper(regexp_replace(TRIM(BOTH FROM qh."TURMA"::text), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) <> 'TEMP'::text
        ), turma_ctx AS (
         SELECT DISTINCT t."CODCOLIGADA" AS codcoligada,
            t."CODCURSO" AS codcurso,
            t."CODHABILITACAO"::text AS codhabilitacao,
            t."CODGRADE"::text AS codgrade,
            t."TURNO" AS turno,
            t."CODFILIAL" AS codfilial,
            t."CODTIPOCURSO" AS codtipocurso,
            t."CODPERLET" AS codperlet,
            upper(regexp_replace(TRIM(BOTH FROM t."CODTURMA"), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) AS turma_key,
            t."CODTURMA" AS codturma
           FROM export.sturma t
          WHERE t."CODTURMA" IS NOT NULL AND upper(regexp_replace(TRIM(BOTH FROM t."CODTURMA"), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) <> 'TEMP'::text
        ), disc_validas AS (
         SELECT DISTINCT sd."CODCOLIGADA" AS codcoligada,
            sd."CODCURSO"::text AS codcurso,
            sd."CODHABILITACAO"::text AS codhabilitacao,
            sd."CODGRADE"::text AS codgrade,
            sd."TURNO"::text AS turno,
            sd."CODFILIAL" AS codfilial,
            sd."CODTIPOCURSO" AS codtipocurso,
            sd."CODPERLET"::text AS codperlet,
            sd."CODDISC"::text AS coddisc
           FROM export.sturmadisc sd
          WHERE sd."CODDISC" IS NOT NULL
        ), disc_idx AS (
         SELECT d.discipline_code::text AS coddisc,
            regexp_replace(translate(lower(TRIM(BOTH FROM d.discipline_name::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS disc_norm,
            regexp_replace(translate(lower(TRIM(BOTH FROM regexp_replace(d.discipline_name::text, '\s*\(.*\)\s*$'::text, ''::text, 'g'::text))), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS disc_clean_norm
           FROM gennera_stg.disciplina d
          WHERE d.discipline_code IS NOT NULL AND d.discipline_name IS NOT NULL AND TRIM(BOTH FROM d.discipline_name::text) <> ''::text
        ), matchs AS (
         SELECT tc.codcoligada,
            tc.codcurso,
            tc.codhabilitacao,
            tc.codgrade,
            tc.turno,
            tc.codfilial,
            tc.codtipocurso,
            tc.codperlet,
            tc.codturma,
            q.diasemana,
            q.horainicial,
            q.horafinal,
            dv.coddisc,
                CASE
                    WHEN di.disc_norm = q.disc_norm THEN 0
                    WHEN di.disc_clean_norm = q.disc_clean_norm THEN 1
                    ELSE 9
                END AS match_rank,
            row_number() OVER (PARTITION BY tc.codcoligada, tc.codcurso, tc.codhabilitacao, tc.codgrade, tc.turno, tc.codfilial, tc.codtipocurso, tc.codperlet, tc.codturma, q.diasemana, q.horainicial, q.horafinal ORDER BY (
                CASE
                    WHEN di.disc_norm = q.disc_norm THEN 0
                    WHEN di.disc_clean_norm = q.disc_clean_norm THEN 1
                    ELSE 9
                END), dv.coddisc) AS rn
           FROM qh q
             JOIN turma_ctx tc ON tc.codgrade = q.ano AND tc.turma_key = q.turma_key
             JOIN disc_idx di ON di.disc_norm = q.disc_norm OR di.disc_clean_norm = q.disc_clean_norm
             JOIN disc_validas dv ON dv.codcoligada = tc.codcoligada AND dv.codcurso = tc.codcurso AND dv.codhabilitacao = tc.codhabilitacao AND dv.codgrade = tc.codgrade AND dv.turno = tc.turno AND dv.codfilial = tc.codfilial AND dv.codtipocurso = tc.codtipocurso AND dv.codperlet = tc.codperlet AND dv.coddisc = di.coddisc
          WHERE q.diasemana IS NOT NULL
        )
 SELECT DISTINCT codcoligada AS "CODCOLIGADA",
    codcurso AS "CODCURSO",
    codhabilitacao AS "CODHABILITACAO",
    codgrade AS "CODGRADE",
        CASE
            WHEN codfilial = 1 THEN 'Integral'::text
            WHEN codfilial = 2 THEN
            CASE substr(codturma, length(codturma) - 1, 1)
                WHEN 'M'::text THEN 'Matutino'::text
                WHEN 'T'::text THEN 'Vespertino'::text
                WHEN 'I'::text THEN 'Integral'::text
                ELSE COALESCE(turno, 'Integral'::text)
            END
            ELSE COALESCE(turno, 'Integral'::text)
        END AS "TURNO",
    codfilial AS "CODFILIAL",
    codtipocurso AS "CODTIPOCURSO",
    codperlet AS "CODPERLET",
    codturma AS "CODTURMA",
    coddisc AS "CODDISC",
    NULL::character varying(5) AS "CODPREDIO",
    NULL::character varying(10) AS "CODSALA",
    diasemana AS "DIASEMANA",
    to_char(horainicial::interval, 'HH24:MI'::text) AS "HORAINICIAL",
    to_char(horafinal::interval, 'HH24:MI'::text) AS "HORAFINAL",
        CASE
            WHEN codperlet ~ '^\d{4}$'::text THEN to_date('01/01/'::text || codperlet, 'DD/MM/YYYY'::text)
            ELSE NULL::date
        END AS "DATAINICIAL",
        CASE
            WHEN codperlet ~ '^\d{4}$'::text THEN to_date('31/12/'::text || codperlet, 'DD/MM/YYYY'::text)
            ELSE NULL::date
        END AS "DATAFINAL",
    NULL::text AS "LOCACAO",
    NULL::character varying(5) AS "CODBLOCO",
    NULL::text AS "TIPO SALA"
   FROM matchs
  WHERE rn = 1;;

-- Indices existentes:
-- CREATE UNIQUE INDEX shorarioturma_uk ON export.shorarioturma USING btree ("CODCOLIGADA", "CODCURSO", "CODHABILITACAO", "CODGRADE", "TURNO", "CODFILIAL", "CODTIPOCURSO", "CODPERLET", "CODTURMA", "CODDISC", "DIASEMANA", "HORAINICIAL", "HORAFINAL");
