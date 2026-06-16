-- ============================================================================
-- View: export.saluno
-- Esquema destino TOTVS: SALUNO
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

-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] export.saluno)
-- Recriar exige: DROP MATERIALIZED VIEW export.saluno; (+ reindexar UNIQUE INDEX)
CREATE MATERIALIZED VIEW export.saluno AS
WITH base AS (
         SELECT DISTINCT ON (er.id_person) pf.name AS nome,
            NULL::text AS sobrenome,
            COALESCE(pf.birthdate::date::text, '0001-01-01'::text) AS dtnascimento,
            NULLIF(regexp_replace(pf.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf,
            pf.rg AS cartidentidade,
            pf.rg_issuing_state AS ufcartident,
            NULL::text AS carteiratrab,
            NULL::text AS seriecarttrab,
            NULL::text AS ufcarttrab,
            NULL::text AS empresanome,
            NULL::text AS empresarua,
            NULL::text AS empresanumero,
            NULL::text AS empresacomplemento,
            NULL::text AS empresabairro,
            NULL::text AS empresacep,
            NULL::text AS empresacidade,
            NULL::text AS empresauf,
            NULL::text AS empresatelefone,
            NULL::text AS empresahorario,
            NULL::text AS tipocertidao,
            NULL::text AS certnumero,
            NULL::text AS certcartorio,
            NULL::text AS certcomarca,
            NULL::text AS certdata,
            NULL::text AS certfolha,
            NULL::text AS certlivro,
            NULL::text AS certdistrito,
            NULL::text AS certuf,
            pf_pai.name AS nomepai,
            COALESCE(pf_pai.birthdate::date::text, '0001-01-01'::text) AS dtnascimentopai,
            NULLIF(regexp_replace(pf_pai.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpfpai,
            pf_pai.rg AS rgpai,
            pf_mae.name AS nomemae,
            COALESCE(pf_mae.birthdate::date::text, '0001-01-01'::text) AS dtnascimentomae,
            NULLIF(regexp_replace(pf_mae.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpfmae,
            pf_mae.rg AS rgmae,
            '1'::text AS codcoligada,
            scu.code_unif::text AS ra,
            NULL::text AS tipoaluno,
            NULL::text AS instdestino,
            NULL::text AS instorigem,
            NULL::text AS codcurhist,
            NULL::text AS codseriehist,
                CASE
                    WHEN (( SELECT cf.codcfo::text AS codcfo
                       FROM gennera_stg.cliente_fornecedor cf
                         JOIN gennera_stg.person_fisica pf_fin ON pf_fin.cpf = cf.cgccfo::text
                      WHERE pf_fin.id_person = e.id_financial_responsible
                     LIMIT 1)) IS NOT NULL THEN '1'::text
                    WHEN (( SELECT cf.codcfo::text AS codcfo
                       FROM gennera_stg.cliente_fornecedor cf
                         JOIN gennera_stg.person_fisica pf_fin ON pf_fin.id_person = e.id_financial_responsible
                      WHERE cf.nomefantasia::text ~~* pf_fin.name
                     LIMIT 1)) IS NOT NULL THEN '1'::text
                    ELSE NULL::text
                END AS codcolcfo,
            lpad(COALESCE(( SELECT cf.codcfo::text AS codcfo
                   FROM gennera_stg.cliente_fornecedor cf
                     JOIN gennera_stg.person_fisica pf_fin ON pf_fin.cpf = cf.cgccfo::text
                  WHERE pf_fin.id_person = e.id_financial_responsible
                 LIMIT 1), ( SELECT cf.codcfo::text AS codcfo
                   FROM gennera_stg.cliente_fornecedor cf
                     JOIN gennera_stg.person_fisica pf_fin ON pf_fin.id_person = e.id_financial_responsible
                  WHERE cf.nomefantasia::text ~~* pf_fin.name
                 LIMIT 1), NULL::text), 6, '0'::text) AS codcfo,
            NULL::text AS codparentcfo,
            pf_acad.name AS nomerespacad,
            COALESCE(pf_acad.birthdate::date::text, '0001-01-01'::text) AS dtnascimentorespacad,
            NULLIF(regexp_replace(pf_acad.cpf, '\D'::text, ''::text, 'g'::text), ''::text) AS cpfrespacad,
            pf_acad.rg AS rgrespacad,
            NULL::text AS codparentraca,
            NULL::text AS obshist,
            NULL::text AS identificador2,
            NULL::text AS identificador3,
            NULL::text AS anoingresso,
            NULL::text AS anotacoes,
            '1'::text AS codtipocurso,
            NULL::text AS codinstorigem,
            NULL::text AS codinstdestino,
            COALESCE(
                CASE
                    WHEN pf.birthplace IS NULL OR TRIM(BOTH FROM pf.birthplace) = ''::text THEN NULL::text
                    WHEN TRIM(BOTH FROM pf.birthplace) ~ '^\d{1,2}[/\-]'::text OR TRIM(BOTH FROM pf.birthplace) ~ '^\d{4}-'::text THEN NULL::text
                    WHEN upper(TRIM(BOTH FROM pf.birthplace)) = ANY (ARRAY['SOLTEIRO'::text, 'SOLTEIRA'::text, 'N/A'::text, 'NA'::text, '--'::text, 'NAO INFORMADO'::text, 'NÃO INFORMADO'::text]) THEN NULL::text
                    ELSE "left"(initcap(TRIM(BOTH FROM pf.birthplace)), 32)
                END, 'Não Informado'::text) AS naturalidade,
                CASE
                    WHEN pf.birth_state IS NULL OR TRIM(BOTH FROM pf.birth_state) = ''::text THEN '--'::text
                    WHEN upper(TRIM(BOTH FROM pf.birth_state)) = ANY (ARRAY['AC'::text, 'AL'::text, 'AM'::text, 'AP'::text, 'BA'::text, 'CE'::text, 'DF'::text, 'ES'::text, 'GO'::text, 'MA'::text, 'MG'::text, 'MS'::text, 'MT'::text, 'PA'::text, 'PB'::text, 'PE'::text, 'PI'::text, 'PR'::text, 'RJ'::text, 'RN'::text, 'RO'::text, 'RR'::text, 'RS'::text, 'SC'::text, 'SE'::text, 'SP'::text, 'TO'::text, 'US'::text, '--'::text]) THEN upper(TRIM(BOTH FROM pf.birth_state))
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'são paulo%'::text OR TRIM(BOTH FROM pf.birth_state) ~~* 'sao paulo%'::text THEN 'SP'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'minas gerais%'::text THEN 'MG'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'rio de janeiro%'::text THEN 'RJ'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'distrito federal%'::text THEN 'DF'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'santa catarina%'::text THEN 'SC'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'rio grande do sul%'::text THEN 'RS'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'bahi%'::text THEN 'BA'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'cear%'::text THEN 'CE'::text
                    WHEN TRIM(BOTH FROM pf.birth_state) ~~* 'paran%'::text THEN 'PR'::text
                    ELSE '--'::text
                END AS estadonatal,
            COALESCE(
                CASE
                    WHEN pf_pai.birthplace IS NULL OR TRIM(BOTH FROM pf_pai.birthplace) = ''::text THEN NULL::text
                    WHEN TRIM(BOTH FROM pf_pai.birthplace) ~ '^\d{1,2}[/\-]'::text OR TRIM(BOTH FROM pf_pai.birthplace) ~ '^\d{4}-'::text THEN NULL::text
                    WHEN upper(TRIM(BOTH FROM pf_pai.birthplace)) = ANY (ARRAY['SOLTEIRO'::text, 'SOLTEIRA'::text, 'N/A'::text, 'NA'::text, '--'::text, 'NAO INFORMADO'::text, 'NÃO INFORMADO'::text]) THEN NULL::text
                    ELSE "left"(initcap(TRIM(BOTH FROM pf_pai.birthplace)), 32)
                END, NULL::text) AS naturalidadepai,
                CASE
                    WHEN pf_pai.birth_state IS NULL OR TRIM(BOTH FROM pf_pai.birth_state) = ''::text THEN NULL::text
                    WHEN upper(TRIM(BOTH FROM pf_pai.birth_state)) = ANY (ARRAY['AC'::text, 'AL'::text, 'AM'::text, 'AP'::text, 'BA'::text, 'CE'::text, 'DF'::text, 'ES'::text, 'GO'::text, 'MA'::text, 'MG'::text, 'MS'::text, 'MT'::text, 'PA'::text, 'PB'::text, 'PE'::text, 'PI'::text, 'PR'::text, 'RJ'::text, 'RN'::text, 'RO'::text, 'RR'::text, 'RS'::text, 'SC'::text, 'SE'::text, 'SP'::text, 'TO'::text, 'US'::text, '--'::text]) THEN upper(TRIM(BOTH FROM pf_pai.birth_state))
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'são paulo%'::text OR TRIM(BOTH FROM pf_pai.birth_state) ~~* 'sao paulo%'::text THEN 'SP'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'minas gerais%'::text THEN 'MG'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'rio de janeiro%'::text THEN 'RJ'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'distrito federal%'::text THEN 'DF'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'santa catarina%'::text THEN 'SC'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'rio grande do sul%'::text THEN 'RS'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'bahi%'::text THEN 'BA'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'cear%'::text THEN 'CE'::text
                    WHEN TRIM(BOTH FROM pf_pai.birth_state) ~~* 'paran%'::text THEN 'PR'::text
                    ELSE NULL::text
                END AS estadonatalpai,
            COALESCE(
                CASE
                    WHEN pf_mae.birthplace IS NULL OR TRIM(BOTH FROM pf_mae.birthplace) = ''::text THEN NULL::text
                    WHEN TRIM(BOTH FROM pf_mae.birthplace) ~ '^\d{1,2}[/\-]'::text OR TRIM(BOTH FROM pf_mae.birthplace) ~ '^\d{4}-'::text THEN NULL::text
                    WHEN upper(TRIM(BOTH FROM pf_mae.birthplace)) = ANY (ARRAY['SOLTEIRO'::text, 'SOLTEIRA'::text, 'N/A'::text, 'NA'::text, '--'::text, 'NAO INFORMADO'::text, 'NÃO INFORMADO'::text]) THEN NULL::text
                    ELSE "left"(initcap(TRIM(BOTH FROM pf_mae.birthplace)), 32)
                END, NULL::text) AS naturalidademae,
                CASE
                    WHEN pf_mae.birth_state IS NULL OR TRIM(BOTH FROM pf_mae.birth_state) = ''::text THEN NULL::text
                    WHEN upper(TRIM(BOTH FROM pf_mae.birth_state)) = ANY (ARRAY['AC'::text, 'AL'::text, 'AM'::text, 'AP'::text, 'BA'::text, 'CE'::text, 'DF'::text, 'ES'::text, 'GO'::text, 'MA'::text, 'MG'::text, 'MS'::text, 'MT'::text, 'PA'::text, 'PB'::text, 'PE'::text, 'PI'::text, 'PR'::text, 'RJ'::text, 'RN'::text, 'RO'::text, 'RR'::text, 'RS'::text, 'SC'::text, 'SE'::text, 'SP'::text, 'TO'::text, 'US'::text, '--'::text]) THEN upper(TRIM(BOTH FROM pf_mae.birth_state))
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'são paulo%'::text OR TRIM(BOTH FROM pf_mae.birth_state) ~~* 'sao paulo%'::text THEN 'SP'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'minas gerais%'::text THEN 'MG'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'rio de janeiro%'::text THEN 'RJ'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'distrito federal%'::text THEN 'DF'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'santa catarina%'::text THEN 'SC'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'rio grande do sul%'::text THEN 'RS'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'bahi%'::text THEN 'BA'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'cear%'::text THEN 'CE'::text
                    WHEN TRIM(BOTH FROM pf_mae.birth_state) ~~* 'paran%'::text THEN 'PR'::text
                    ELSE NULL::text
                END AS estadonatalmae,
            COALESCE(
                CASE
                    WHEN pf_acad.birthplace IS NULL OR TRIM(BOTH FROM pf_acad.birthplace) = ''::text THEN NULL::text
                    WHEN TRIM(BOTH FROM pf_acad.birthplace) ~ '^\d{1,2}[/\-]'::text OR TRIM(BOTH FROM pf_acad.birthplace) ~ '^\d{4}-'::text THEN NULL::text
                    WHEN upper(TRIM(BOTH FROM pf_acad.birthplace)) = ANY (ARRAY['SOLTEIRO'::text, 'SOLTEIRA'::text, 'N/A'::text, 'NA'::text, '--'::text, 'NAO INFORMADO'::text, 'NÃO INFORMADO'::text]) THEN NULL::text
                    ELSE "left"(initcap(TRIM(BOTH FROM pf_acad.birthplace)), 32)
                END, 'Não Informado'::text) AS naturalidadeacad,
                CASE
                    WHEN pf_acad.birth_state IS NULL OR TRIM(BOTH FROM pf_acad.birth_state) = ''::text THEN '--'::text
                    WHEN upper(TRIM(BOTH FROM pf_acad.birth_state)) = ANY (ARRAY['AC'::text, 'AL'::text, 'AM'::text, 'AP'::text, 'BA'::text, 'CE'::text, 'DF'::text, 'ES'::text, 'GO'::text, 'MA'::text, 'MG'::text, 'MS'::text, 'MT'::text, 'PA'::text, 'PB'::text, 'PE'::text, 'PI'::text, 'PR'::text, 'RJ'::text, 'RN'::text, 'RO'::text, 'RR'::text, 'RS'::text, 'SC'::text, 'SE'::text, 'SP'::text, 'TO'::text, 'US'::text, '--'::text]) THEN upper(TRIM(BOTH FROM pf_acad.birth_state))
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'são paulo%'::text OR TRIM(BOTH FROM pf_acad.birth_state) ~~* 'sao paulo%'::text THEN 'SP'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'minas gerais%'::text THEN 'MG'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'rio de janeiro%'::text THEN 'RJ'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'distrito federal%'::text THEN 'DF'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'santa catarina%'::text THEN 'SC'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'rio grande do sul%'::text THEN 'RS'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'bahi%'::text THEN 'BA'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'cear%'::text THEN 'CE'::text
                    WHEN TRIM(BOTH FROM pf_acad.birth_state) ~~* 'paran%'::text THEN 'PR'::text
                    ELSE '--'::text
                END AS estadonatalacad,
            NULL::text AS codsistec,
            NULL::text AS codinst2grau,
            NULL::text AS grauultimainst,
            NULL::text AS anoultimainst,
            NULL::text AS codetnia
           FROM gennera_stg.enrollment_record er
             LEFT JOIN gennera_stg.person_fisica pf ON pf.id_person = er.id_person
             LEFT JOIN gennera_stg.student_code_unico scu ON scu.id_person = er.id_person
             LEFT JOIN LATERAL ( SELECT e1.id_enrollment,
                    e1.id_institution,
                    e1.id_parent_enrollment,
                    e1.id_person,
                    e1.id_academic_responsible,
                    e1.id_financial_responsible,
                    e1.cod_col,
                    e1.code,
                    e1.status,
                    e1.date,
                    e1.campaign_name,
                    e1.academic_calendar,
                    e1.curriculum_name,
                    e1.course_name,
                    e1.module_name,
                    e1.class_name,
                    e1.cancellation_reason,
                    e1.blocked
                   FROM gennera_stg.enrollment e1
                  WHERE e1.id_person = er.id_person AND e1.id_institution <> 3
                  ORDER BY (e1.id_financial_responsible IS NULL), (e1.academic_calendar::integer) DESC
                 LIMIT 1) e ON true
             LEFT JOIN ( SELECT DISTINCT ON (r.id_target) r.id_target,
                    r.id_owner
                   FROM gennera_stg.relationship r
                  WHERE r.type = 'FATHER'::text
                  ORDER BY r.id_target, r.id_owner) rel_pai ON rel_pai.id_target = er.id_person
             LEFT JOIN gennera_stg.person_fisica pf_pai ON pf_pai.id_person = rel_pai.id_owner
             LEFT JOIN ( SELECT DISTINCT ON (r.id_target) r.id_target,
                    r.id_owner
                   FROM gennera_stg.relationship r
                  WHERE r.type = 'MOTHER'::text
                  ORDER BY r.id_target, r.id_owner) rel_mae ON rel_mae.id_target = er.id_person
             LEFT JOIN gennera_stg.person_fisica pf_mae ON pf_mae.id_person = rel_mae.id_owner
             LEFT JOIN gennera_stg.person_fisica pf_acad ON pf_acad.id_person = e.id_academic_responsible
          ORDER BY er.id_person
        )
 SELECT DISTINCT ON (ra) nome,
    sobrenome,
    dtnascimento,
    cpf,
    cartidentidade,
    ufcartident,
    carteiratrab,
    seriecarttrab,
    ufcarttrab,
    empresanome,
    empresarua,
    empresanumero,
    empresacomplemento,
    empresabairro,
    empresacep,
    empresacidade,
    empresauf,
    empresatelefone,
    empresahorario,
    tipocertidao,
    certnumero,
    certcartorio,
    certcomarca,
    certdata,
    certfolha,
    certlivro,
    certdistrito,
    certuf,
    nomepai,
    dtnascimentopai,
    cpfpai,
    rgpai,
    nomemae,
    dtnascimentomae,
    cpfmae,
    rgmae,
    codcoligada,
    ra,
    tipoaluno,
    instdestino,
    instorigem,
    codcurhist,
    codseriehist,
    codcolcfo,
    codcfo,
    codparentcfo,
    nomerespacad,
    dtnascimentorespacad,
    cpfrespacad,
    rgrespacad,
    codparentraca,
    obshist,
    identificador2,
    identificador3,
    anoingresso,
    anotacoes,
    codtipocurso,
    codinstorigem,
    codinstdestino,
    naturalidade,
    estadonatal,
    naturalidadepai,
    estadonatalpai,
    naturalidademae,
    estadonatalmae,
    naturalidadeacad,
    estadonatalacad,
    codsistec,
    codinst2grau,
    grauultimainst,
    anoultimainst,
    codetnia
   FROM base
  WHERE nome IS NOT NULL AND ra IS NOT NULL
  ORDER BY ra, (cpf IS NULL), cpf;;

-- Indices existentes:
-- CREATE UNIQUE INDEX saluno_ra_unique_idx ON export.saluno USING btree (ra);
