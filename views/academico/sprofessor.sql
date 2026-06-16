-- ============================================================================
-- View: export.sprofessor
-- Esquema destino TOTVS: SPROFESSOR
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

CREATE OR REPLACE VIEW export.sprofessor AS
WITH prof_qh AS (
         SELECT DISTINCT q.id_person,
            q.cpf_final
           FROM export.professor_qh_enriquecido q
          WHERE q.id_person IS NOT NULL
        ), pf AS (
         SELECT pf.id_person,
            pf.name,
            pf.birthdate,
            pf.birthplace,
            pf.birth_state,
            NULLIF(regexp_replace(pf.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_pf,
            lower(TRIM(BOTH FROM pf.email)) AS email_pf
           FROM gennera_stg.person_fisica pf
        ), prof_ids AS (
         SELECT prof_qh.id_person
           FROM prof_qh
        UNION
         SELECT pf.id_person
           FROM pf
          WHERE pf.email_pf ~~ '%@edf.pro.br'::text
        ), base_unificado AS (
         SELECT DISTINCT p.id_person,
            p.name,
            p.birthdate,
            p.birthplace,
            p.birth_state,
            COALESCE(p.cpf_pf, NULLIF(regexp_replace(q.cpf_final, '\D'::text, ''::text, 'g'::text), ''::text)) AS cpf_by_id
           FROM pf p
             JOIN prof_ids pi ON pi.id_person = p.id_person
             LEFT JOIN prof_qh q ON q.id_person = p.id_person
        ), unif_norm AS (
         SELECT regexp_replace(lower(TRIM(BOTH FROM b.name)), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            b.id_person,
            b.name,
            b.birthdate,
            b.birthplace,
            b.birth_state,
            b.cpf_by_id
           FROM base_unificado b
        ), pf_global AS (
         SELECT regexp_replace(lower(TRIM(BOTH FROM pf.name)), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            max(NULLIF(regexp_replace(pf.cpf, '\D'::text, ''::text, 'g'::text), ''::text)) AS cpf_pf_any
           FROM gennera_stg.person_fisica pf
          GROUP BY (regexp_replace(lower(TRIM(BOTH FROM pf.name)), '\s+'::text, ' '::text, 'g'::text))
        ), temp_global AS (
         SELECT regexp_replace(lower(TRIM(BOTH FROM pct.nome::text)), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            max(NULLIF(regexp_replace(pct.cpf::text, '\D'::text, ''::text, 'g'::text), ''::text)) AS cpf_temp_any
           FROM gennera_stg.professor_cpf_temp pct
          GROUP BY (regexp_replace(lower(TRIM(BOTH FROM pct.nome::text)), '\s+'::text, ' '::text, 'g'::text))
        ), map_global AS (
         SELECT regexp_replace(lower(TRIM(BOTH FROM pcm.name_norm)), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            max(NULLIF(regexp_replace(pcm.cpf, '\D'::text, ''::text, 'g'::text), ''::text)) AS cpf_map_any,
            max(NULLIF(regexp_replace(pcm.cpf_original::text, '\D'::text, ''::text, 'g'::text), ''::text)) AS cpf_orig_any,
            max(NULLIF(regexp_replace(pcm.cpf_temporario::text, '\D'::text, ''::text, 'g'::text), ''::text)) AS cpf_temp_map_any
           FROM gennera_stg.person_cpf_mapping pcm
          GROUP BY (regexp_replace(lower(TRIM(BOTH FROM pcm.name_norm)), '\s+'::text, ' '::text, 'g'::text))
        ), cpf_global AS (
         SELECT COALESCE(p.nome_norm, t.nome_norm, m.nome_norm) AS nome_norm,
            COALESCE(p.cpf_pf_any, t.cpf_temp_any, m.cpf_map_any, m.cpf_orig_any, m.cpf_temp_map_any) AS cpf_any
           FROM pf_global p
             FULL JOIN temp_global t ON t.nome_norm = p.nome_norm
             FULL JOIN map_global m ON m.nome_norm = COALESCE(p.nome_norm, t.nome_norm)
        ), unif_with_cpf_any AS (
         SELECT u.nome_norm,
            u.id_person,
            u.name,
            u.birthdate,
            u.birthplace,
            u.birth_state,
            COALESCE(u.cpf_by_id, cg.cpf_any) AS cpf_final_digits
           FROM unif_norm u
             LEFT JOIN cpf_global cg ON cg.nome_norm = u.nome_norm
        ), sprof_unificado_dedup AS (
         SELECT x.nome_norm,
            TRIM(BOTH FROM x.name) AS "NOME",
            COALESCE(
                CASE
                    WHEN x.birthdate IS NOT NULL THEN to_char(x.birthdate::date::timestamp with time zone, 'DD/MM/YYYY'::text)
                    ELSE NULL::text
                END, '01/01/0001'::text) AS "DTNASCIMENTO",
                CASE
                    WHEN x.cpf_final_digits IS NOT NULL THEN lpad(x.cpf_final_digits, 11, '0'::text)
                    WHEN x.id_person IS NOT NULL THEN '00000'::text || lpad(x.id_person::text, 6, '0'::text)
                    ELSE NULL::text
                END AS "CPF",
            NULL::text AS "CARTIDENTIDADE",
            NULL::text AS "UFCARTIDENT",
            NULL::text AS "CARTEIRATRAB",
            NULL::text AS "SERIECARTTRAB",
            NULL::text AS "UFCARTTRAB",
            '1'::text AS "CODCOLIGADA",
            x.id_person::text AS "CODPROF",
            NULL::text AS "CHAPA",
            NULL::text AS "VALORAULA",
            NULL::text AS "TITULACAO",
            TRIM(BOTH FROM x.birthplace) AS "NATURALIDADE",
            upper(TRIM(BOTH FROM x.birth_state)) AS "ESTADONATAL"
           FROM ( SELECT u.nome_norm,
                    u.id_person,
                    u.name,
                    u.birthdate,
                    u.birthplace,
                    u.birth_state,
                    u.cpf_final_digits,
                    row_number() OVER (PARTITION BY u.nome_norm ORDER BY (
                        CASE
                            WHEN u.cpf_final_digits IS NOT NULL THEN 0
                            ELSE 1
                        END), u.id_person) AS rn
                   FROM unif_with_cpf_any u) x
          WHERE x.rn = 1
        ), pessoa_norm AS (
         SELECT p."CODIGO" AS codigo,
            p."NOME" AS nome,
            p."DTNASCIMENTO"::date AS dtnascimento,
            p."NATURALIDADE" AS naturalidade,
            p."ESTADONATAL" AS estadonatal,
            p."PROFESSOR"::integer AS professor,
            regexp_replace(lower(TRIM(BOTH FROM p."NOME")), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            NULLIF(regexp_replace(p."CPF", '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_digits
           FROM export.ppessoa p
        ), cpf_por_nome AS (
         SELECT pn.nome_norm,
            max(pn.cpf_digits) AS cpf_preferido
           FROM pessoa_norm pn
          WHERE pn.cpf_digits IS NOT NULL
          GROUP BY pn.nome_norm
        ), professores_legados_brutos AS (
         SELECT pn.nome,
            pn.dtnascimento,
            COALESCE(pn.cpf_digits, cpn.cpf_preferido) AS cpf_final,
            pn.naturalidade,
            pn.estadonatal,
            pn.codigo,
            pn.nome_norm
           FROM pessoa_norm pn
             LEFT JOIN cpf_por_nome cpn ON cpn.nome_norm = pn.nome_norm
          WHERE pn.professor = 1
        ), professores_legados_filtrados AS (
         SELECT pl.nome,
            pl.dtnascimento,
            pl.cpf_final,
            pl.naturalidade,
            pl.estadonatal,
            pl.codigo,
            pl.nome_norm
           FROM professores_legados_brutos pl
             LEFT JOIN sprof_unificado_dedup su ON su.nome_norm = pl.nome_norm
          WHERE su.nome_norm IS NULL
        ), sprof_legado_dedup AS (
         SELECT x.nome_norm,
            TRIM(BOTH FROM x.nome) AS "NOME",
            COALESCE(
                CASE
                    WHEN x.dtnascimento IS NOT NULL THEN to_char(x.dtnascimento::timestamp with time zone, 'DD/MM/YYYY'::text)
                    ELSE NULL::text
                END, '01/01/0001'::text) AS "DTNASCIMENTO",
                CASE
                    WHEN x.cpf_final IS NOT NULL THEN lpad(x.cpf_final, 11, '0'::text)
                    WHEN x.codigo IS NOT NULL THEN '00000'::text || lpad(x.codigo, 6, '0'::text)
                    ELSE NULL::text
                END AS "CPF",
            NULL::text AS "CARTIDENTIDADE",
            NULL::text AS "UFCARTIDENT",
            NULL::text AS "CARTEIRATRAB",
            NULL::text AS "SERIECARTTRAB",
            NULL::text AS "UFCARTTRAB",
            '1'::text AS "CODCOLIGADA",
            x.codigo AS "CODPROF",
            NULL::text AS "CHAPA",
            NULL::text AS "VALORAULA",
            NULL::text AS "TITULACAO",
            TRIM(BOTH FROM x.naturalidade) AS "NATURALIDADE",
            upper(TRIM(BOTH FROM x.estadonatal)) AS "ESTADONATAL"
           FROM ( SELECT pl.nome,
                    pl.dtnascimento,
                    pl.cpf_final,
                    pl.naturalidade,
                    pl.estadonatal,
                    pl.codigo,
                    pl.nome_norm,
                    row_number() OVER (PARTITION BY pl.nome_norm ORDER BY (
                        CASE
                            WHEN pl.cpf_final IS NOT NULL THEN 0
                            ELSE 1
                        END), pl.codigo) AS rn
                   FROM professores_legados_filtrados pl) x
          WHERE x.rn = 1
        )
 SELECT sprof_unificado_dedup."NOME",
    sprof_unificado_dedup."DTNASCIMENTO",
    sprof_unificado_dedup."CPF",
    sprof_unificado_dedup."CARTIDENTIDADE",
    sprof_unificado_dedup."UFCARTIDENT",
    sprof_unificado_dedup."CARTEIRATRAB",
    sprof_unificado_dedup."SERIECARTTRAB",
    sprof_unificado_dedup."UFCARTTRAB",
    sprof_unificado_dedup."CODCOLIGADA",
    sprof_unificado_dedup."CODPROF",
    sprof_unificado_dedup."CHAPA",
    sprof_unificado_dedup."VALORAULA",
    sprof_unificado_dedup."TITULACAO",
    sprof_unificado_dedup."NATURALIDADE",
    sprof_unificado_dedup."ESTADONATAL"
   FROM sprof_unificado_dedup
UNION ALL
 SELECT sprof_legado_dedup."NOME",
    sprof_legado_dedup."DTNASCIMENTO",
    sprof_legado_dedup."CPF",
    sprof_legado_dedup."CARTIDENTIDADE",
    sprof_legado_dedup."UFCARTIDENT",
    sprof_legado_dedup."CARTEIRATRAB",
    sprof_legado_dedup."SERIECARTTRAB",
    sprof_legado_dedup."UFCARTTRAB",
    sprof_legado_dedup."CODCOLIGADA",
    sprof_legado_dedup."CODPROF",
    sprof_legado_dedup."CHAPA",
    sprof_legado_dedup."VALORAULA",
    sprof_legado_dedup."TITULACAO",
    sprof_legado_dedup."NATURALIDADE",
    sprof_legado_dedup."ESTADONATAL"
   FROM sprof_legado_dedup;;
