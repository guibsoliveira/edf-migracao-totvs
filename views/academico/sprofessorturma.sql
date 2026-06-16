-- ============================================================================
-- View: export.sprofessorturma
-- Esquema destino TOTVS: SPROFESSORTURMA
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

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.sprofessorturma)
-- Recriar exige: DROP MATERIALIZED VIEW export.sprofessorturma; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.sprofessorturma AS
WITH quadro_agregado AS (
         SELECT TRIM(BOTH FROM qh."CALENDARIO"::text) AS ano,
            upper(regexp_replace(TRIM(BOTH FROM qh."TURMA"::text), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) AS turma_key,
            regexp_replace(lower(TRIM(BOTH FROM qh."DISCIPLINA"::text)), '\s+'::text, ' '::text, 'g'::text) AS disc_norm,
            regexp_replace(translate(lower(TRIM(BOTH FROM qh."PROFESSOR"::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS prof_norm,
            TRIM(BOTH FROM qh."PROFESSOR"::text) AS prof_nome_raw,
            NULLIF(regexp_replace(TRIM(BOTH FROM qh.cpf_professor::text), '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_qh,
            count(DISTINCT qh."DIA")::integer AS aulas_semanais_prof
           FROM gennera_stg.professor_quadro_horarios qh
          WHERE qh."CALENDARIO" IS NOT NULL AND qh."TURMA" IS NOT NULL AND qh."DISCIPLINA" IS NOT NULL AND qh."PROFESSOR" IS NOT NULL
          GROUP BY qh."CALENDARIO", qh."TURMA", qh."DISCIPLINA", qh."PROFESSOR", qh.cpf_professor
        ), disc_map AS (
         SELECT DISTINCT regexp_replace(lower(TRIM(BOTH FROM d.discipline_name::text)), '\s+'::text, ' '::text, 'g'::text) AS disc_norm,
            d.discipline_code::text AS coddisc
           FROM gennera_stg.disciplina d
        ), turma_ctx AS (
         SELECT DISTINCT t."CODCOLIGADA" AS codcoligada,
            t."CODCURSO" AS codcurso,
            t."CODHABILITACAO"::text AS codhabilitacao,
            t."CODGRADE"::text AS codgrade,
            t."TURNO" AS turno,
            t."CODFILIAL" AS codfilial,
            t."CODTIPOCURSO" AS codtipocurso,
            t."CODPERLET" AS codperlet,
            upper(regexp_replace(TRIM(BOTH FROM t."CODTURMA"), '[^0-9A-Za-z]'::text, ''::text, 'g'::text)) AS turma_key
           FROM export.sturma t
        ), disc_validas AS (
         SELECT DISTINCT sd."CODCOLIGADA" AS codcoligada,
            sd."CODCURSO"::text AS codcurso,
            sd."CODHABILITACAO"::text AS codhabilitacao,
            sd."CODGRADE"::text AS codgrade,
            sd."CODDISC"::text AS coddisc
           FROM export.sturmadisc sd
        ), prof_rm_map AS (
         SELECT prm."Codigo do Professor"::text AS codprof_rm,
            NULLIF(regexp_replace(prm."CPF"::text, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_rm,
            regexp_replace(translate(lower(TRIM(BOTH FROM prm."Nome"::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS prof_norm_rm,
            lower(TRIM(BOTH FROM prm."E-Mail"::text)) AS email_rm
           FROM gennera_stg.tabela_professor_rm prm
          WHERE prm."Codigo do Professor" IS NOT NULL
        ), prof_enriquecido_map AS (
         SELECT regexp_replace(translate(lower(pqh.prof_norm), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS prof_norm,
            pqh.id_person,
            pqh.cpf_final,
            pqh.email_final
           FROM export.professor_qh_enriquecido pqh
        ), prof_matching AS (
         SELECT q.prof_norm,
                CASE
                    WHEN pr.prof_norm_rm = q.prof_norm AND pr.cpf_rm = q.cpf_qh AND pr.cpf_rm IS NOT NULL AND q.cpf_qh IS NOT NULL AND pr.email_rm = (( SELECT prof_enriquecido_map.email_final
                       FROM prof_enriquecido_map
                      WHERE prof_enriquecido_map.prof_norm = q.prof_norm)) THEN pr.codprof_rm
                    WHEN pr.prof_norm_rm = q.prof_norm AND pr.cpf_rm = q.cpf_qh AND pr.cpf_rm IS NOT NULL AND q.cpf_qh IS NOT NULL THEN pr.codprof_rm
                    WHEN pr.prof_norm_rm = q.prof_norm AND pr.email_rm = (( SELECT prof_enriquecido_map.email_final
                       FROM prof_enriquecido_map
                      WHERE prof_enriquecido_map.prof_norm = q.prof_norm)) AND pr.email_rm IS NOT NULL THEN pr.codprof_rm
                    WHEN pr.prof_norm_rm IS NOT NULL THEN pr.codprof_rm
                    WHEN q.cpf_qh IS NOT NULL THEN ( SELECT prc.codprof_rm
                       FROM prof_rm_map prc
                      WHERE prc.cpf_rm = q.cpf_qh
                     LIMIT 1)
                    ELSE ( SELECT prof_enriquecido_map.id_person::text AS id_person
                       FROM prof_enriquecido_map
                      WHERE prof_enriquecido_map.prof_norm = q.prof_norm)
                END AS codprof_final
           FROM quadro_agregado q
             LEFT JOIN prof_rm_map pr ON pr.prof_norm_rm = q.prof_norm
        ), final_select AS (
         SELECT q.ano,
            q.turma_key,
            q.disc_norm,
            q.prof_norm,
            q.aulas_semanais_prof,
            COALESCE(pm.codprof_final, ( SELECT prof_enriquecido_map.id_person::text AS id_person
                   FROM prof_enriquecido_map
                  WHERE prof_enriquecido_map.prof_norm = q.prof_norm)) AS codprof_final
           FROM quadro_agregado q
             LEFT JOIN prof_matching pm ON pm.prof_norm = q.prof_norm
        )
 SELECT DISTINCT tc.codcoligada AS "CODCOLIGADA",
    tc.codcurso AS "CODCURSO",
    tc.codhabilitacao AS "CODHABILITACAO",
    tc.codgrade AS "CODGRADE",
    tc.turno AS "TURNO",
    tc.codfilial AS "CODFILIAL",
    tc.codtipocurso AS "CODTIPOCURSO",
    tc.codperlet AS "CODPERLET",
    tc.turma_key AS "CODTURMA",
    dv.coddisc AS "CODDISC",
    fs.codprof_final::character varying(20) AS "CODPROF",
        CASE
            WHEN tc.codperlet ~ '^\d{4}$'::text THEN to_date('01/01/'::text || tc.codperlet, 'DD/MM/YYYY'::text)
            ELSE NULL::date
        END AS "DTINICIO",
        CASE
            WHEN tc.codperlet ~ '^\d{4}$'::text THEN to_date('31/12/'::text || tc.codperlet, 'DD/MM/YYYY'::text)
            ELSE NULL::date
        END AS "DTFIM",
    NULL::numeric(10,4) AS "VALORHORA",
    fs.aulas_semanais_prof AS "AULASSEMANAISPROF",
    NULL::numeric(10,4) AS "VALORFIXO",
    'T'::character varying(1) AS "TIPOPROF",
    'S'::character varying(1) AS "DESCONSIDERAPONTO",
    NULL::numeric(10,4) AS "PERCENTFATURAMENTO",
    NULL::character varying(1) AS "COMPOESALARIO",
    NULL::character varying(10) AS "CODTIPOPART",
    NULL::character varying(1) AS "STATUS"
   FROM final_select fs
     JOIN disc_map dm ON dm.disc_norm = fs.disc_norm
     JOIN turma_ctx tc ON tc.codgrade = fs.ano AND tc.turma_key = fs.turma_key
     JOIN disc_validas dv ON dv.codcoligada = tc.codcoligada AND dv.codcurso = tc.codcurso AND dv.codhabilitacao = tc.codhabilitacao AND dv.codgrade = tc.codgrade AND dv.coddisc = dm.coddisc;;

-- Indices existentes:
-- CREATE UNIQUE INDEX sprofessorturma_uk ON export.sprofessorturma USING btree ("CODCOLIGADA", "CODCURSO", "CODHABILITACAO", "CODGRADE", "TURNO", "CODFILIAL", "CODTIPOCURSO", "CODPERLET", "CODTURMA", "CODDISC", "CODPROF");
