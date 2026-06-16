-- ============================================================================
-- View: export.ppessoa
-- Esquema destino TOTVS: PPESSOA
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

CREATE OR REPLACE VIEW export.ppessoa AS
SELECT id_person::text AS "CODIGO",
    name AS "NOME",
    social_name AS "APELIDO",
    COALESCE(NULLIF(birthdate, ''::text)::date, '0001-01-01'::date)::text AS "DTNASCIMENTO",
        CASE
            WHEN civil_status = 'Casado'::text THEN 'C'::text
            WHEN civil_status = 'Desquitado'::text THEN 'D'::text
            WHEN civil_status = 'Separado'::text THEN 'D'::text
            WHEN civil_status = 'Divorciado'::text THEN 'I'::text
            WHEN civil_status = 'Outros'::text THEN 'O'::text
            WHEN civil_status = 'Solteiro'::text THEN 'S'::text
            WHEN civil_status = 'Viúvo'::text THEN 'V'::text
            ELSE NULL::text
        END AS "ESTADOCIVIL",
        CASE
            WHEN gender = 'Masculino'::text THEN 'M'::text
            WHEN gender = 'Feminino'::text THEN 'F'::text
            ELSE NULL::text
        END AS "SEXO",
    'Não Informado'::text AS "NATURALIDADE",
    '--'::text AS "ESTADONATAL",
    cod_nationality AS "NACIONALIDADE",
    NULL::text AS "GRAUINSTRUCAO",
    NULL::text AS "CODTIPORUA",
    street AS "RUA",
    street_number AS "NUMERO",
    complement AS "COMPLEMENTO",
    NULL::text AS "CODTIPOBAIRRO",
    neighborhood AS "BAIRRO",
    state AS "ESTADO",
    city AS "CIDADE",
    replace(zipcode, '-'::text, ''::text) AS "CEP",
    birth_country AS "PAIS",
    NULL::text AS "REGPROFISSIONAL",
    regexp_replace(cpf, '[^0-9]'::text, ''::text, 'g'::text) AS "CPF",
    regexp_replace(telephone_number, '[^0-9]'::text, ''::text, 'g'::text) AS "TELEFONE1",
    regexp_replace(mobile_phone_number, '[^0-9]'::text, ''::text, 'g'::text) AS "TELEFONE2",
    regexp_replace(commercial_phone_number, '[^0-9]'::text, ''::text, 'g'::text) AS "TELEFONE3",
    regexp_replace(fax_number, '[^0-9]'::text, ''::text, 'g'::text) AS "FAX",
    email AS "EMAIL",
    rg AS "CARTIDENTIDADE",
    rg_issuing_state AS "UFCARTIDENT",
    rg_issuing_agency AS "ORGEMISSORIDENT",
    rg_issue_date AS "DTEMISSAOIDENT",
    voter_document AS "TITULOELEITOR",
    voter_document_zone AS "ZONATITELEITOR",
    voter_document_section AS "SECAOTITELEITOR",
        CASE
            WHEN NULLIF(voter_document_issue_date, ''::text) IS NOT NULL THEN NULLIF(voter_document_issue_date, ''::text)::date::text
            ELSE NULL::text
        END AS "DTTITELEITOR",
    voter_document_state AS "ESTELEIT",
    NULL::text AS "CARTEIRATRAB",
    NULL::text AS "SERIECARTTRAB",
    NULL::text AS "UFCARTTRAB",
    NULL::text AS "DTCARTTRAB",
    '0'::text AS "NIT",
    NULL::text AS "CARTMOTORISTA",
    NULL::text AS "TIPOCARTHABILIT",
    NULL::text AS "DTVENCHABILIT",
    NULL::text AS "SITMILITAR",
    NULL::text AS "CERTIFRESERV",
    NULL::text AS "CATEGMILITAR",
    NULL::text AS "CSM",
    NULL::text AS "DTEXPCML",
    NULL::text AS "EXPED",
    NULL::text AS "RM",
    NULL::text AS "NROREGGERAL",
    NULL::text AS "NPASSAPORTE",
    NULL::text AS "PAISORIGEM",
    NULL::text AS "DTEMISSPASSAPORTE",
    NULL::text AS "DTVALPASSAPORTE",
        CASE
            WHEN ethnicity = 'Indígena'::text THEN '0'::text
            WHEN ethnicity = 'Branca'::text THEN '2'::text
            WHEN ethnicity = 'Preta'::text THEN '4'::text
            WHEN ethnicity = 'Amarela'::text THEN '6'::text
            WHEN ethnicity = 'Parda'::text THEN '8'::text
            ELSE NULL::text
        END AS "CORRACA",
        CASE
            WHEN special_needs::jsonb ? 'Deficiência Física'::text AND ((special_needs::jsonb ->> 'Deficiência Física'::text)::boolean) = true THEN '1'::text
            WHEN special_needs::jsonb ? 'Deficiência Múltipla'::text AND ((special_needs::jsonb ->> 'Deficiência Múltipla'::text)::boolean) = true THEN '1'::text
            ELSE '0'::text
        END AS "DEFICIENTEFISICO",
        CASE
            WHEN special_needs::jsonb ? 'Deficiência auditiva'::text AND ((special_needs::jsonb ->> 'Deficiência auditiva'::text)::boolean) = true THEN '2'::text
            WHEN special_needs::jsonb ? 'Surdez'::text AND ((special_needs::jsonb ->> 'Surdez'::text)::boolean) = true THEN '2'::text
            WHEN special_needs::jsonb ? 'Surdocegueira'::text AND ((special_needs::jsonb ->> 'Surdocegueira'::text)::boolean) = true THEN '2'::text
            ELSE '0'::text
        END AS "DEFICIENTEAUDITIVO",
    '0'::text AS "DEFICIENTEFALA",
        CASE
            WHEN special_needs::jsonb ? 'Baixa visão'::text AND ((special_needs::jsonb ->> 'Baixa visão'::text)::boolean) = true THEN '4'::text
            WHEN special_needs::jsonb ? 'Surdocegueira'::text AND ((special_needs::jsonb ->> 'Surdocegueira'::text)::boolean) = true THEN '4'::text
            ELSE '0'::text
        END AS "DEFICIENTEVISUAL",
        CASE
            WHEN special_needs::jsonb ? 'Deficiência Intelectual'::text AND ((special_needs::jsonb ->> 'Deficiência Intelectual'::text)::boolean) = true THEN '5'::text
            WHEN special_needs::jsonb ? 'Transtorno do espectro autista (TEA)'::text AND ((special_needs::jsonb ->> 'Transtorno do espectro autista (TEA)'::text)::boolean) = true THEN '5'::text
            WHEN special_needs::jsonb ? 'Síndrome de Asperger'::text AND ((special_needs::jsonb ->> 'Síndrome de Asperger'::text)::boolean) = true THEN '5'::text
            WHEN special_needs::jsonb ? 'Transtorno desintegrativo da infância'::text AND ((special_needs::jsonb ->> 'Transtorno desintegrativo da infância'::text)::boolean) = true THEN '5'::text
            WHEN special_needs::jsonb ? 'Síndrome de Rett'::text AND ((special_needs::jsonb ->> 'Síndrome de Rett'::text)::boolean) = true THEN '5'::text
            WHEN special_needs::jsonb ? 'Altas habilidades/Superdotação'::text AND ((special_needs::jsonb ->> 'Altas habilidades/Superdotação'::text)::boolean) = true THEN '5'::text
            ELSE '0'::text
        END AS "DEFICIENTEMENTAL",
    NULL::text AS "RECURSOREALIZACAOTRAB",
    NULL::text AS "RECURSOACESSIBILIDADE",
    NULL::text AS "PROFISSAO",
    NULL::text AS "EMPRESA",
    NULL::text AS "OCUPACAO",
    COALESCE(( SELECT string_agg(h.tiposang::text, '; '::text ORDER BY h.prioridade, (h.tiposang::text)) AS string_agg
           FROM ( SELECT u1."Aluno" AS aluno,
                    u1."Turma" AS turma,
                    u1.tiposang,
                    1 AS prioridade
                   FROM gennera_stg.un1health2025 u1
                UNION ALL
                 SELECT u2."Aluno" AS aluno,
                    u2."Turma" AS turma,
                    u2.tiposang,
                    2 AS prioridade
                   FROM gennera_stg.un2health2025 u2) h
          WHERE upper(TRIM(BOTH FROM pf.name)) = upper(TRIM(BOTH FROM h.aluno)) AND (EXISTS ( SELECT 1
                   FROM gennera_stg.enrollment e
                  WHERE e.id_person = pf.id_person AND e.class_name = h.turma::text))), NULL::text) AS "TIPOSANG",
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM gennera_stg.enrollment e
              WHERE e.id_person = pf.id_person)) THEN '1'::text
            ELSE '0'::text
        END AS "ALUNO",
        CASE
            WHEN email ~~* '%@edf.pro.br'::text THEN '1'::text
            ELSE '0'::text
        END AS "PROFESSOR",
    '0'::text AS "USUARIOBIBLIOS",
    '0'::text AS "FUNCIONARIO",
    '0'::text AS "EXFUNCIONARIO",
    '0'::text AS "CANDIDATO",
        CASE
            WHEN deceased IS NULL THEN '0'::text
            WHEN deceased = 'true'::text OR deceased = '1'::text OR upper(deceased) = 'SIM'::text THEN '1'::text
            ELSE '0'::text
        END AS "FALECIDO",
    NULL::text AS "DATAOBITO",
    NULL::text AS "MATRICULAOBITO",
    social_name AS "NOMESOCIAL"
   FROM gennera_stg.person_fisica pf;;
