-- ============================================================================
-- View: export.v_matrix_source
-- Esquema destino TOTVS: V_MATRIX_SOURCE
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

CREATE OR REPLACE VIEW export.v_matrix_source AS
WITH er_filtered AS (
         SELECT er.id_enrollment_record,
            er.id_enrollment,
            er.id_person,
            er.institution_name,
            er.institution_city,
            er.institution_state,
            er.calendar_name,
            er.course_name,
            er.module_name,
            er.attendance,
            er.workload,
            er.status,
            er.observation,
            er.finished,
            er.finish_date,
            er.cancellation_reason,
            er.course_type,
            er.course_level,
            er.complementary_status,
            er.curriculum_name,
            er.subject_name,
            er.subject_type,
            er.subject_workload,
            er.subject_attendance,
            er.subject_average,
            er.subject_status,
            er.subject_observation,
            er.subject_failure_reason,
            er.subject_dismissed,
            er.subject_dismissal_reason,
            er.subject_reference_year,
            er.subject_cancellation_reason,
            er.subject_group_name,
            er.subject_complementary_status,
            er.subject_letter_grade,
            er.professors,
            er.subject_code,
            er.workload_real,
            er.disc_code,
            (regexp_match(er.calendar_name, '(\d{4})'::text))[1]::integer AS ref_year,
            er.module_name AS serie,
            upper(TRIM(BOTH FROM COALESCE(er.subject_status, er.status))) AS status_norm,
            NULLIF(TRIM(BOTH FROM er.course_name), ''::text) AS course_name_norm,
            NULLIF(TRIM(BOTH FROM er.module_name), ''::text) AS module_name_norm,
            NULLIF(TRIM(BOTH FROM er.curriculum_name), ''::text) AS curriculum_name_norm,
            NULLIF(TRIM(BOTH FROM er.subject_name), ''::text) AS subject_name_norm,
            COALESCE(er.disc_code, er.subject_code::text) AS disc_code_text,
            COALESCE(er.disc_code, er.subject_code::text, NULLIF(TRIM(BOTH FROM er.subject_name), ''::text)) AS disc_key,
            COALESCE(er.course_level, ''::text) ~~* '%médio%'::text OR COALESCE(er.course_level, ''::text) ~~* '%medio%'::text OR COALESCE(er.course_level, ''::text) ~~* '%EM%'::text AS is_high_school,
            (COALESCE(er.course_level, ''::text) ~~* '%médio%'::text OR COALESCE(er.course_level, ''::text) ~~* '%medio%'::text OR COALESCE(er.course_level, ''::text) ~~* '%EM%'::text) AND (er.subject_name ~~* '%espan%'::text OR er.subject_name ~~* '%japon%'::text) AS is_lang_choice_elective
           FROM gennera_stg.enrollment_record er
          WHERE er.institution_name ~~* '%Escola do futuro%'::text AND (regexp_match(er.calendar_name, '(\d{4})'::text))[1] IS NOT NULL AND (regexp_match(er.calendar_name, '(\d{4})'::text))[1]::integer >= 2021 AND (upper(TRIM(BOTH FROM COALESCE(er.subject_status, er.status))) = ANY (ARRAY['APPROVED'::text, 'IN PROGRESS'::text])) AND er.course_name IS NOT NULL AND er.module_name IS NOT NULL AND COALESCE(er.disc_code, er.subject_code::text, NULLIF(TRIM(BOTH FROM er.subject_name), ''::text)) IS NOT NULL AND er.course_name <> 'Educação Infantil'::text
        ), student_core_disc_count AS (
         SELECT b.ref_year,
            b.serie,
            b.course_name_norm AS course_name,
            b.curriculum_name_norm AS curriculum_name,
            b.id_person,
            count(DISTINCT b.disc_key) FILTER (WHERE NOT b.is_lang_choice_elective) AS core_disc_cnt
           FROM er_filtered b
          GROUP BY b.ref_year, b.serie, b.course_name_norm, b.curriculum_name_norm, b.id_person
        ), picked_student AS (
         SELECT x.ref_year,
            x.serie,
            x.course_name,
            x.curriculum_name,
            x.id_person,
            x.core_disc_cnt,
            x.rn
           FROM ( SELECT s.ref_year,
                    s.serie,
                    s.course_name,
                    s.curriculum_name,
                    s.id_person,
                    s.core_disc_cnt,
                    row_number() OVER (PARTITION BY s.ref_year, s.serie, s.course_name, s.curriculum_name ORDER BY s.core_disc_cnt DESC, s.id_person) AS rn
                   FROM student_core_disc_count s) x
          WHERE x.rn = 1
        ), matrix_base AS (
         SELECT DISTINCT b.ref_year,
            b.serie,
            b.course_name_norm AS course_name,
            b.module_name_norm AS module_name,
            b.curriculum_name_norm AS curriculum_name,
            b.id_person AS example_id_person,
            b.disc_key,
            b.disc_code_text,
            b.disc_code,
            b.subject_code,
            b.subject_name_norm AS subject_name,
            b.subject_group_name,
            b.subject_type,
            b.subject_workload,
            b.is_high_school,
            b.is_lang_choice_elective
           FROM er_filtered b
             JOIN picked_student p ON p.ref_year = b.ref_year AND p.serie = b.serie AND p.course_name = b.course_name_norm AND NOT p.curriculum_name IS DISTINCT FROM b.curriculum_name_norm AND p.id_person = b.id_person
        ), matrix_lang_electives AS (
         SELECT DISTINCT b.ref_year,
            b.serie,
            b.course_name_norm AS course_name,
            b.module_name_norm AS module_name,
            b.curriculum_name_norm AS curriculum_name,
            NULL::bigint AS example_id_person,
            b.disc_key,
            b.disc_code_text,
            b.disc_code,
            b.subject_code,
            b.subject_name_norm AS subject_name,
            b.subject_group_name,
            b.subject_type,
            b.subject_workload,
            b.is_high_school,
            b.is_lang_choice_elective
           FROM er_filtered b
          WHERE b.is_lang_choice_elective
        ), matrix_union AS (
         SELECT matrix_base.ref_year,
            matrix_base.serie,
            matrix_base.course_name,
            matrix_base.module_name,
            matrix_base.curriculum_name,
            matrix_base.example_id_person,
            matrix_base.disc_key,
            matrix_base.disc_code_text,
            matrix_base.disc_code,
            matrix_base.subject_code,
            matrix_base.subject_name,
            matrix_base.subject_group_name,
            matrix_base.subject_type,
            matrix_base.subject_workload,
            matrix_base.is_high_school,
            matrix_base.is_lang_choice_elective
           FROM matrix_base
        UNION ALL
         SELECT matrix_lang_electives.ref_year,
            matrix_lang_electives.serie,
            matrix_lang_electives.course_name,
            matrix_lang_electives.module_name,
            matrix_lang_electives.curriculum_name,
            matrix_lang_electives.example_id_person,
            matrix_lang_electives.disc_key,
            matrix_lang_electives.disc_code_text,
            matrix_lang_electives.disc_code,
            matrix_lang_electives.subject_code,
            matrix_lang_electives.subject_name,
            matrix_lang_electives.subject_group_name,
            matrix_lang_electives.subject_type,
            matrix_lang_electives.subject_workload,
            matrix_lang_electives.is_high_school,
            matrix_lang_electives.is_lang_choice_elective
           FROM matrix_lang_electives
        ), matrix AS (
         SELECT DISTINCT ON (matrix_union.ref_year, matrix_union.serie, matrix_union.course_name, matrix_union.curriculum_name, matrix_union.disc_key) matrix_union.ref_year,
            matrix_union.serie,
            matrix_union.course_name,
            matrix_union.module_name,
            matrix_union.curriculum_name,
            matrix_union.example_id_person,
            matrix_union.disc_key,
            matrix_union.disc_code_text,
            matrix_union.disc_code,
            matrix_union.subject_code,
            matrix_union.subject_name,
            matrix_union.subject_group_name,
            matrix_union.subject_type,
            matrix_union.subject_workload,
            matrix_union.is_high_school,
            matrix_union.is_lang_choice_elective
           FROM matrix_union
          ORDER BY matrix_union.ref_year, matrix_union.serie, matrix_union.course_name, matrix_union.curriculum_name, matrix_union.disc_key, (matrix_union.example_id_person IS NULL), matrix_union.example_id_person
        ), academic_norm AS (
         SELECT a_1.id_academic,
            a_1.id_institution,
            a_1.course_name,
            a_1.course_code,
            a_1.module_name,
            a_1.curriculum_name,
            a_1.subject_name,
            a_1.workload_duration,
            a_1.min_duration_enrollment,
            a_1.max_duration_enrollment,
            a_1.min_workload_required,
            a_1.min_workload_optional,
            a_1.min_workload_elective,
            a_1.min_workload_enrollment,
            a_1.max_workload_enrollment,
            a_1.subject_code_gennera,
            a_1.subject_code,
            a_1.code_module,
            NULLIF(TRIM(BOTH FROM a_1.course_name), ''::text) AS course_name_norm,
            NULLIF(TRIM(BOTH FROM a_1.module_name), ''::text) AS module_name_norm,
            NULLIF(TRIM(BOTH FROM a_1.curriculum_name), ''::text) AS curriculum_name_norm,
            NULLIF(TRIM(BOTH FROM a_1.subject_name), ''::text) AS subject_name_norm,
            COALESCE(a_1.subject_code::text, a_1.subject_code_gennera::text) AS academic_code_text
           FROM gennera_stg.academic a_1
        )
 SELECT m.ref_year,
    m.serie,
    m.course_name,
    m.module_name,
    m.curriculum_name,
    m.example_id_person,
    m.disc_key,
    m.disc_code_text,
    m.disc_code,
    m.subject_code,
    m.subject_name,
    m.subject_group_name,
    m.subject_type,
    m.subject_workload,
    m.is_high_school,
    m.is_lang_choice_elective,
    a.id_academic,
    a.id_institution,
    COALESCE(a.course_code,
        CASE m.course_name
            WHEN 'Ensino Fundamental I'::text THEN 'EF1'::text
            WHEN 'Ensino Fundamental II'::text THEN 'EF2'::text
            WHEN 'Ensino Médio'::text THEN 'EM'::text
            ELSE NULL::text
        END) AS course_code,
    COALESCE(a.code_module, NULLIF(regexp_replace(m.module_name, '[^0-9]'::text, ''::text, 'g'::text), ''::text)::integer) AS code_module,
    a.workload_duration,
    a.min_duration_enrollment,
    a.max_duration_enrollment,
    a.min_workload_required,
    a.min_workload_optional,
    a.min_workload_elective,
    a.min_workload_enrollment,
    a.max_workload_enrollment,
    a.subject_code AS academic_subject_code,
    a.subject_code_gennera AS academic_subject_code_gennera,
    a.subject_name_norm AS academic_subject_name
   FROM matrix m
     LEFT JOIN academic_norm a ON a.course_name_norm = m.course_name AND a.module_name_norm = m.module_name AND NOT a.curriculum_name_norm IS DISTINCT FROM m.curriculum_name AND (a.academic_code_text IS NOT NULL AND m.disc_code_text IS NOT NULL AND a.academic_code_text = m.disc_code_text OR (a.academic_code_text IS NULL OR m.disc_code_text IS NULL) AND a.subject_name_norm IS NOT NULL AND a.subject_name_norm = m.subject_name);;
