-- ============================================================================
-- View: export.shorario
-- Esquema destino TOTVS: SHORARIO
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

CREATE OR REPLACE VIEW export.shorario AS
WITH phq AS (
         SELECT TRIM(BOTH FROM qh."CALENDARIO"::text) AS ano,
            upper(regexp_replace(TRIM(BOTH FROM qh."TURMA"::text), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) AS turma_key,
            qh."TURMA" AS turma_raw,
            qh."DIA" AS dia_raw,
            TRIM(BOTH FROM qh."INICIO"::text) AS hora_inicio_raw,
            TRIM(BOTH FROM qh."FIM"::text) AS hora_fim_raw
           FROM gennera_stg.professor_quadro_horarios qh
          WHERE qh."CALENDARIO" IS NOT NULL AND qh."TURMA" IS NOT NULL AND qh."DISCIPLINA" IS NOT NULL AND qh."PROFESSOR" IS NOT NULL AND TRIM(BOTH FROM qh."CALENDARIO"::text) <> ''::text AND TRIM(BOTH FROM qh."TURMA"::text) <> ''::text AND TRIM(BOTH FROM qh."DISCIPLINA"::text) <> ''::text AND TRIM(BOTH FROM qh."PROFESSOR"::text) <> ''::text
        ), turma_ctx AS (
         SELECT DISTINCT st."CODCOLIGADA" AS codcoligada,
            st."CODCURSO" AS codcurso,
            st."CODHABILITACAO"::text AS codhabilitacao,
            st."CODGRADE"::text AS codgrade,
            st."TURNO" AS turno_st,
            st."CODFILIAL" AS codfilial,
            st."CODTIPOCURSO" AS codtipocurso,
            st."CODPERLET" AS codperlet,
            upper(regexp_replace(TRIM(BOTH FROM st."CODTURMA"), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) AS turma_key,
            st."CODTURMA" AS codturma_raw
           FROM export.sturma st
          WHERE st."CODTURMA" IS NOT NULL
        ), slots AS (
         SELECT DISTINCT tc.codcoligada,
            tc.codfilial,
            tc.codtipocurso,
                CASE
                    WHEN tc.codfilial = 1 THEN 'Integral'::text
                    WHEN tc.codfilial = 2 THEN
                    CASE
                        WHEN substr(tc.codturma_raw, length(tc.codturma_raw) - 1, 1) = 'M'::text THEN 'Matutino'::text
                        WHEN substr(tc.codturma_raw, length(tc.codturma_raw) - 1, 1) = 'T'::text THEN 'Vespertino'::text
                        WHEN substr(tc.codturma_raw, length(tc.codturma_raw) - 1, 1) = 'I'::text THEN 'Integral'::text
                        ELSE COALESCE(tc.turno_st, 'Integral'::text)
                    END
                    ELSE COALESCE(tc.turno_st, 'Integral'::text)
                END AS nometurno,
                CASE lower(p.dia_raw::text)
                    WHEN 'sunday'::text THEN 1
                    WHEN 'monday'::text THEN 2
                    WHEN 'tuesday'::text THEN 3
                    WHEN 'wednesday'::text THEN 4
                    WHEN 'thursday'::text THEN 5
                    WHEN 'friday'::text THEN 6
                    WHEN 'saturday'::text THEN 7
                    ELSE NULL::integer
                END AS diasemana,
            "left"(p.hora_inicio_raw, 5) AS horainicial,
            "left"(p.hora_fim_raw, 5) AS horafinal
           FROM phq p
             JOIN turma_ctx tc ON tc.codgrade = p.ano AND tc.turma_key = p.turma_key
        ), slots_numerados AS (
         SELECT s.codcoligada,
            s.codfilial,
            s.codtipocurso,
            s.nometurno,
            s.diasemana,
            s.horainicial,
            s.horafinal,
            lpad(row_number() OVER (PARTITION BY s.codcoligada, s.codfilial, s.codtipocurso, s.nometurno, s.diasemana ORDER BY s.horainicial)::text, 3, '0'::text) AS aula
           FROM slots s
        )
 SELECT codcoligada AS "CODCOLIGADA",
    codfilial AS "CODFILIAL",
    codtipocurso AS "CODTIPOCURSO",
    nometurno AS "NOMETURNO",
    diasemana AS "DIASEMANA",
    horainicial AS "HORAINICIAL",
    horafinal AS "HORAFINAL",
    aula AS "AULA"
   FROM slots_numerados
  ORDER BY codcoligada, codfilial, codtipocurso, nometurno, diasemana, horainicial;;
