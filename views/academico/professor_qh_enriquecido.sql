-- ============================================================================
-- View: export.professor_qh_enriquecido
-- Esquema destino TOTVS: PROFESSOR_QH_ENRIQUECIDO
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

CREATE OR REPLACE VIEW export.professor_qh_enriquecido AS
WITH qh_norm AS (
         SELECT DISTINCT regexp_replace(lower(TRIM(BOTH FROM qh."PROFESSOR"::text)), '\s+'::text, ' '::text, 'g'::text) AS prof_norm,
            qh."PROFESSOR" AS prof_nome
           FROM gennera_stg.professor_quadro_horarios qh
          WHERE qh."PROFESSOR" IS NOT NULL AND TRIM(BOTH FROM qh."PROFESSOR"::text) <> ''::text
        ), temp_norm AS (
         SELECT regexp_replace(lower(TRIM(BOTH FROM pct.nome::text)), '\s+'::text, ' '::text, 'g'::text) AS prof_norm,
            NULLIF(regexp_replace(pct.cpf::text, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_temp,
            lower(TRIM(BOTH FROM pct.email::text)) AS email_temp
           FROM gennera_stg.professor_cpf_temp pct
        ), pf_any_norm AS (
         SELECT pf.id_person,
            regexp_replace(lower(TRIM(BOTH FROM pf.name)), '\s+'::text, ' '::text, 'g'::text) AS prof_norm,
            NULLIF(regexp_replace(pf.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_pf,
            lower(TRIM(BOTH FROM pf.email)) AS email_pf,
                CASE
                    WHEN lower(pf.email) ~~ '%@edf.pro.br'::text THEN 0
                    ELSE 1
                END AS prioridade_email
           FROM gennera_stg.person_fisica pf
        ), pcm_norm AS (
         SELECT x.prof_norm,
            x.cpf_map,
            x.cpf_orig,
            x.cpf_temp_map
           FROM ( SELECT regexp_replace(lower(TRIM(BOTH FROM pcm.name_norm)), '\s+'::text, ' '::text, 'g'::text) AS prof_norm,
                    NULLIF(regexp_replace(pcm.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_map,
                    NULLIF(regexp_replace(pcm.cpf_original::text, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_orig,
                    NULLIF(regexp_replace(pcm.cpf_temporario::text, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_temp_map,
                    row_number() OVER (PARTITION BY (regexp_replace(lower(TRIM(BOTH FROM pcm.name_norm)), '\s+'::text, ' '::text, 'g'::text)) ORDER BY pcm.criado_em DESC) AS rn
                   FROM gennera_stg.person_cpf_mapping pcm) x
          WHERE x.rn = 1
        ), temp_pf_candidates AS (
         SELECT t.prof_norm,
            t.cpf_temp,
            t.email_temp,
            pf.id_person,
            pf.cpf_pf,
            pf.email_pf,
            pf.prioridade_email,
            row_number() OVER (PARTITION BY t.prof_norm ORDER BY pf.prioridade_email, pf.id_person) AS rn
           FROM temp_norm t
             JOIN pf_any_norm pf ON t.email_temp IS NOT NULL AND t.email_temp = pf.email_pf OR t.cpf_temp IS NOT NULL AND t.cpf_temp = pf.cpf_pf
        ), temp_pf_match AS (
         SELECT temp_pf_candidates.prof_norm,
            temp_pf_candidates.cpf_temp,
            temp_pf_candidates.email_temp,
            temp_pf_candidates.id_person,
            temp_pf_candidates.cpf_pf,
            temp_pf_candidates.email_pf
           FROM temp_pf_candidates
          WHERE temp_pf_candidates.rn = 1
        ), qh_join_temp AS (
         SELECT q.prof_norm,
            q.prof_nome,
            tm.cpf_temp,
            tm.email_temp,
            tm.id_person AS id_person_temp,
            tm.cpf_pf AS cpf_pf_temp,
            tm.email_pf AS email_pf_temp
           FROM qh_norm q
             LEFT JOIN temp_pf_match tm ON tm.prof_norm = q.prof_norm
        ), qh_pf_candidates AS (
         SELECT q.prof_norm,
            q.prof_nome,
            pf.id_person,
            pf.cpf_pf,
            pf.email_pf,
            pf.prioridade_email,
            row_number() OVER (PARTITION BY q.prof_norm ORDER BY pf.prioridade_email, pf.id_person) AS rn
           FROM qh_norm q
             JOIN pf_any_norm pf ON pf.prof_norm = q.prof_norm
        ), qh_pf_direct AS (
         SELECT qh_pf_candidates.prof_norm,
            qh_pf_candidates.prof_nome,
            qh_pf_candidates.id_person AS id_person_pf,
            qh_pf_candidates.cpf_pf AS cpf_pf_direct,
            qh_pf_candidates.email_pf AS email_pf_direct
           FROM qh_pf_candidates
          WHERE qh_pf_candidates.rn = 1
        ), final_match AS (
         SELECT q.prof_norm,
            q.prof_nome,
            COALESCE(q.id_person_temp, p.id_person_pf) AS id_person_final,
            COALESCE(q.cpf_temp, q.cpf_pf_temp, p.cpf_pf_direct, pcm.cpf_map, pcm.cpf_orig, pcm.cpf_temp_map) AS cpf_final,
            COALESCE(q.email_temp, q.email_pf_temp, p.email_pf_direct) AS email_final
           FROM qh_join_temp q
             LEFT JOIN qh_pf_direct p ON p.prof_norm = q.prof_norm
             LEFT JOIN pcm_norm pcm ON pcm.prof_norm = q.prof_norm
        )
 SELECT prof_norm,
    prof_nome,
    id_person_final AS id_person,
    cpf_final,
    email_final
   FROM final_match;;
