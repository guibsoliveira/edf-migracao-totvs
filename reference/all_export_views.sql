-- ============================================================
-- VIEW: export.dim_pessoa_unica
-- ============================================================
CREATE OR REPLACE VIEW export.dim_pessoa_unica AS
 WITH cte_pessoa_base AS (
         SELECT pf.id_person,
            pf.name,
            upper(TRIM(BOTH FROM pf.name)) AS nome_normalizado,
            pf.cpf,
            pf.email,
            pf.academic_registration AS ra,
            lower(split_part(pf.email, '@'::text, 2)) AS email_dominio,
                CASE
                    WHEN pf.email ~~* '%@edf.g12.br'::text THEN 'Aluno'::text
                    WHEN pf.email ~~* '%@edf.pro.br'::text THEN 'Professor'::text
                    WHEN pf.email ~~* '%@escoladofuturo.com.br'::text THEN 'Funcionário'::text
                    WHEN pf.email IS NULL OR pf.email = ''::text THEN 'Sem email'::text
                    ELSE 'Pessoal'::text
                END AS tipo_email
           FROM gennera_stg.person_fisica pf
        ), cte_pessoa_vinculos AS (
         SELECT pb.id_person,
            pb.name,
            pb.nome_normalizado,
            pb.cpf,
            pb.email,
            pb.ra,
            pb.email_dominio,
            pb.tipo_email,
                CASE
                    WHEN (EXISTS ( SELECT 1
                       FROM gennera_stg.enrollment e
                      WHERE e.id_person = pb.id_person)) THEN 1
                    ELSE 0
                END AS tem_matricula,
                CASE
                    WHEN (EXISTS ( SELECT 1
                       FROM gennera_stg.enrollment_record er
                      WHERE er.id_person = pb.id_person)) THEN 1
                    ELSE 0
                END AS tem_historico,
                CASE
                    WHEN (EXISTS ( SELECT 1
                       FROM gennera_stg.relationship r
                      WHERE r.id_target = pb.id_person)) THEN 1
                    ELSE 0
                END AS tem_relacionamento_como_aluno,
                CASE
                    WHEN (EXISTS ( SELECT 1
                       FROM gennera_stg.relationship r
                      WHERE r.id_owner = pb.id_person)) THEN 1
                    ELSE 0
                END AS tem_relacionamento_como_responsavel
           FROM cte_pessoa_base pb
        ), cte_pessoa_tipos AS (
         SELECT pv.id_person,
            pv.name,
            pv.nome_normalizado,
            pv.cpf,
            pv.email,
            pv.ra,
            pv.email_dominio,
            pv.tipo_email,
            pv.tem_matricula,
            pv.tem_historico,
            pv.tem_relacionamento_como_aluno,
            pv.tem_relacionamento_como_responsavel,
                CASE
                    WHEN pv.tem_matricula = 1 OR pv.tem_historico = 1 OR pv.tem_relacionamento_como_aluno = 1 THEN 1
                    ELSE 0
                END AS eh_aluno,
                CASE
                    WHEN pv.tipo_email = 'Professor'::text THEN 1
                    ELSE 0
                END AS eh_professor,
                CASE
                    WHEN pv.tipo_email = 'Funcionário'::text THEN 1
                    ELSE 0
                END AS eh_funcionario,
                CASE
                    WHEN pv.tem_relacionamento_como_responsavel = 1 THEN 1
                    ELSE 0
                END AS eh_responsavel
           FROM cte_pessoa_vinculos pv
        ), cte_pessoa_prioridade AS (
         SELECT pt.id_person,
            pt.name,
            pt.nome_normalizado,
            pt.cpf,
            pt.email,
            pt.ra,
            pt.email_dominio,
            pt.tipo_email,
            pt.tem_matricula,
            pt.tem_historico,
            pt.tem_relacionamento_como_aluno,
            pt.tem_relacionamento_como_responsavel,
            pt.eh_aluno,
            pt.eh_professor,
            pt.eh_funcionario,
            pt.eh_responsavel,
            COALESCE(pt.cpf, lower(pt.email), pt.ra::text, pt.nome_normalizado) AS chave_pessoa,
            row_number() OVER (PARTITION BY (COALESCE(pt.cpf, lower(pt.email), pt.ra::text, pt.nome_normalizado)) ORDER BY (
                CASE
                    WHEN pt.tem_matricula = 1 OR pt.tem_historico = 1 THEN 1
                    ELSE 2
                END), (
                CASE
                    WHEN pt.ra IS NOT NULL THEN 1
                    ELSE 2
                END), (
                CASE
                    WHEN pt.tipo_email = ANY (ARRAY['Aluno'::text, 'Professor'::text, 'Funcionário'::text]) THEN 1
                    ELSE 2
                END), (
                CASE
                    WHEN pt.cpf IS NOT NULL THEN 1
                    ELSE 2
                END), pt.id_person) AS ordem
           FROM cte_pessoa_tipos pt
        )
 SELECT id_person,
    chave_pessoa,
    name,
    nome_normalizado,
    cpf,
    email,
    tipo_email,
    email_dominio,
    ra,
    tem_matricula,
    tem_historico,
    tem_relacionamento_como_aluno,
    tem_relacionamento_como_responsavel,
    eh_aluno,
    eh_professor,
    eh_funcionario,
    eh_responsavel
   FROM cte_pessoa_prioridade
  WHERE ordem = 1;

-- ============================================================
-- VIEW: export.fcfo2
-- ============================================================
CREATE OR REPLACE VIEW export.fcfo2 AS
 SELECT DISTINCT ON (pf.name) '00000'::character varying(5) AS codcoligada,
    pf.codcfo::character varying(25) AS codcfo,
    pf.name::character varying(60) AS nomefantasia,
    pf.name::character varying(60) AS nome,
    pf.cpf::character varying(20) AS cgccfo,
    NULL::character varying(20) AS inscrestadual,
    '3'::character varying(5) AS pagrec,
    NULL::character varying(100) AS rua,
    NULL::character varying(8) AS numero,
    NULL::character varying(20) AS complemento,
    NULL::character varying(30) AS bairro,
    NULL::character varying(60) AS cidade,
    pf.state::character varying(2) AS codetd,
    pf.zipcode::character varying(9) AS cep,
    replace(COALESCE(pf.telephone_number, ''::text), '-'::text, ''::text)::character varying(15) AS telefone,
    NULL::character varying(100) AS ruapgto,
    NULL::character varying(8) AS numeropgto,
    NULL::character varying(20) AS complementopgto,
    NULL::character varying(30) AS bairropgto,
    NULL::character varying(60) AS cidadepgto,
    NULL::character varying(2) AS codetdpgto,
    NULL::character varying(9) AS ceppgto,
    NULL::character varying(15) AS telefonepgto,
    NULL::character varying(100) AS ruaentrega,
    NULL::character varying(8) AS numeroentrega,
    NULL::character varying(20) AS complementrega,
    NULL::character varying(30) AS bairroentrega,
    NULL::character varying(60) AS cidadeentrega,
    NULL::character varying(2) AS codetdentrega,
    NULL::character varying(9) AS cepentrega,
    NULL::character varying(15) AS telefoneentrega,
    NULL::character varying(15) AS fax,
    NULL::character varying(15) AS telex,
    NULL::character varying(40) AS contato,
    NULL::character varying(25) AS codtcf,
    '1'::character varying(5) AS ativo,
    '0'::character varying(10) AS limitecredito,
    '0'::character varying(10) AS valorultimolan,
    NULL::character varying(5) AS tipoinscrcnab,
    NULL::character varying(5) AS simbmoedaindex,
    NULL::timestamp without time zone AS dataultalteracao,
    NULL::timestamp without time zone AS datacriacao,
    NULL::timestamp without time zone AS dataultmovimento,
    NULL::character varying(1) AS conteventocontab,
    NULL::character varying(40) AS campolivre,
    NULL::character varying(40) AS campoalfaop1,
    NULL::character varying(40) AS campoalfaop2,
    NULL::character varying(40) AS campoalfaop3,
    '0'::character varying(10) AS valorop1,
    '0'::character varying(10) AS valorop2,
    '0'::character varying(10) AS valorop3,
    NULL::date AS dataop1,
    NULL::date AS dataop2,
    NULL::date AS dataop3,
    NULL::character varying(10) AS codtra,
    NULL::character varying(16) AS chapa,
    NULL::character varying(5) AS statuscotacao,
    NULL::date AS dtinicatividades,
    '0'::character varying(10) AS patrimonio,
    '0'::character varying(10) AS numfuncionarios,
    NULL::character varying(5) AS codcolchavesestrang,
    '1'::character varying(5) AS codcoltcf,
    NULL::character varying(5) AS faxdedicado,
    NULL::character varying(20) AS codmunicipio,
    NULL::character varying(5) AS codcolcontager,
    NULL::character varying(25) AS codcontager,
    NULL::character varying(5) AS formapagamento,
    NULL::character varying(1) AS identporcnpj,
    NULL::character varying(20) AS inscrmunicipal,
    'F'::character varying(1) AS pessoafisoujur,
    NULL::character varying(40) AS contatopgto,
    NULL::character varying(40) AS contatoentrega,
    'Brasil'::character varying(20) AS pais,
    'Brasil'::character varying(20) AS paispagto,
    'Brasil'::character varying(20) AS paisentrega,
    NULL::character varying(20) AS ultimodocumento,
    '0'::character varying(1) AS contribuinte,
    '0'::character varying(1) AS cfoimob,
    NULL::character varying(5) AS tipodoc,
    NULL::character varying(5) AS codfinalidade,
    NULL::character varying(5) AS agrupcob,
    NULL::character varying(3) AS codcargo,
    NULL::character varying(1) AS codvinculo,
    NULL::character varying(1) AS endcobc,
    NULL::character varying(20) AS cidentidade,
    NULL::character varying(10) AS ci_orgao,
    NULL::character varying(2) AS ci_uf,
    NULL::character varying(10) AS codprof,
    NULL::character varying(5) AS codpagtogps,
    NULL::character varying(15) AS faxentrega,
    NULL::character varying(15) AS faxpgto,
    NULL::character varying(5) AS satisfacao,
    '0'::character varying(10) AS valfrete,
    '0'::character varying(5) AS tptomador,
    '0'::character varying(5) AS contribuinteiss,
    '0'::character varying(10) AS numdependentes,
    NULL::character varying(60) AS empresa,
    'C'::character varying(1) AS estadocivil,
    NULL::character varying(5) AS codcolcxa,
    NULL::character varying(10) AS codcxa,
    NULL::character varying(1) AS produtorrural,
    NULL::character varying(50) AS usuarioalteracao,
    NULL::character varying(14) AS suframa,
    NULL::character varying(20) AS codmunicipiopgto,
    NULL::character varying(20) AS codmunicipioentrega,
    '0'::character varying(5) AS orgaopublico,
    NULL::character varying(15) AS telefonecomercial,
    NULL::character varying(10) AS caixapostal,
    NULL::character varying(10) AS caixapostalentrega,
    NULL::character varying(10) AS caixapostalpagamento,
    NULL::character varying(5) AS categoriaautonomo,
    NULL::character varying(10) AS cboautonomo,
    NULL::character varying(11) AS ciautonomo,
    NULL::character varying(25) AS idcfo,
    NULL::character varying(15) AS codigoinss,
    '0'::character varying(10) AS vroutrasdeducoesirrf,
    NULL::character varying(10) AS codreceita,
    NULL::character varying(20) AS cei,
    '0'::character varying(5) AS optantepelosimples,
    '4'::character varying(5) AS tiporua,
    '1'::character varying(5) AS tipobairro,
    'N'::character varying(1) AS regimeiss,
    '0'::character varying(5) AS retencaoiss,
    NULL::timestamp with time zone AS dtnascimento,
    NULL::character varying(50) AS usuariocriacao,
    '3'::character varying(5) AS tipoopcombustivel,
    NULL::character varying(20) AS inscrestadualst,
    NULL::character varying(100) AS localidade,
    NULL::character varying(100) AS localidadepgto,
    NULL::character varying(100) AS localidadeentrega,
    '4'::character varying(5) AS tiporuapgto,
    '4'::character varying(5) AS tiporuaentrega,
    '1'::character varying(5) AS tipobairropgto,
    '1'::character varying(5) AS tipobairroentrega,
    '0'::character varying(5) AS porte,
    '0'::character varying(2) AS ramoativ,
    NULL::character varying(15) AS nit,
    NULL::character varying(9) AS cepcaixapostal,
    NULL::character varying(5) AS numdiasatraso,
    '1'::character varying(3) AS idpais,
    '1'::character varying(3) AS idpaispgto,
    '1'::character varying(3) AS idpaisentrega,
    NULL::character varying(5) AS tipocontribuinteinss,
    '0'::character varying(1) AS nacionalidade,
    NULL::character varying(5) AS codcolcfofiscal,
    NULL::character varying(25) AS idcfofiscal,
    NULL::character varying(60) AS emailfiscal,
    NULL::character varying(1) AS calculaavp,
    NULL::character varying(50) AS codusuarioacesso,
    NULL::character varying(50) AS reccreatedby,
    NULL::timestamp without time zone AS reccreatedon,
    NULL::character varying(50) AS recmodifiedby,
    NULL::timestamp without time zone AS recmodifiedon,
    NULL::character varying(50) AS idintegracao,
    NULL::character varying(1) AS usarcumulatretencaopagar,
    '0'::character varying(5) AS indnatret,
    NULL::character varying(30) AS nif,
    '0'::character varying(5) AS situacaonif,
    '000'::character varying(5) AS tiporendimento,
    '00'::character varying(2) AS formatributacao,
    NULL::character varying(50) AS tplotacao_old,
    NULL::character varying(50) AS documentoestrangeiro,
    '0'::character varying(1) AS inovar_auto,
    NULL::character varying(5) AS filialfinanceira,
    NULL::character varying(5) AS tomadorfolha,
    NULL::character varying(10) AS cnaeprep,
    NULL::character varying(10) AS percentacidtrab,
    NULL::character varying(5) AS codcolformula,
    NULL::character varying(50) AS formulavaldeducaovariavel,
    NULL::character varying(1) AS aplicformula,
    NULL::character varying(5) AS codcfocolintegracao,
    NULL::character varying(25) AS codcfointegracao,
    NULL::character varying(1) AS digverificdebautomatico,
    NULL::character varying(10) AS codloja,
    NULL::character varying(10) AS codfilialintegracao,
    NULL::character varying(50) AS codexterno,
    NULL::character varying(5) AS tipocliente,
    NULL::character varying(1) AS considerafilialobra,
    NULL::character varying(10) AS codfilialobra,
    NULL::character varying(5) AS tipocontroleponto,
    NULL::character varying(5) AS codcoligadafilialobra,
    NULL::character varying(1) AS obrapropria,
    '0'::character varying(1) AS entidadeexecutorapaa,
    NULL::character varying(5) AS fap,
    NULL::character varying(1) AS aposentadooupensionista,
    NULL::character varying(10) AS codcategoriaesocial,
    NULL::character varying(14) AS cnpjrural,
    pf.email::character varying(60) AS email,
    pf.email::character varying(60) AS emailentrega,
    pf.email::character varying(60) AS emailpgto,
    NULL::character varying(10) AS codigocaepf,
    NULL::character varying(1) AS isentotributos,
    NULL::character varying(1) AS sociocooperado,
    NULL::character varying(10) AS idnatrendimento
   FROM ( SELECT DISTINCT ON (e_1.id_financial_responsible) e_1.id_financial_responsible
           FROM gennera_stg.enrollment e_1
          WHERE e_1.id_financial_responsible IS NOT NULL) e
     JOIN gennera_stg.person_fisica pf ON pf.id_person = e.id_financial_responsible
  ORDER BY pf.name;

-- ============================================================
-- VIEW: export.fcfo2_totvs_xml
-- ============================================================
CREATE OR REPLACE VIEW export.fcfo2_totvs_xml AS
 SELECT nomefantasia,
    ('<?xml version="1.0" encoding="UTF-8"?>'::text || '
'::text) || XMLSERIALIZE(CONTENT XMLELEMENT(NAME "FinCFOImportacao", XMLATTRIBUTES('http://tempuri.org/FinCFOImportacao.xsd' AS xmlns), XMLELEMENT(NAME "FCFO", XMLFOREST(codcoligada AS "CODCOLIGADA", codcfo AS "CODCFO", nomefantasia AS "NOMEFANTASIA", nome AS "NOME", cgccfo AS "CGCCFO", pagrec AS "PAGREC", rua AS "RUA", numero AS "NUMERO", complemento AS "COMPLEMENTO", bairro AS "BAIRRO", codetd AS "CODETD", cep AS "CEP", telefone AS "TELEFONE", ruapgto AS "RUAPGTO", numeropgto AS "NUMEROPGTO", complementopgto AS "COMPLEMENTOPGTO", bairropgto AS "BAIRROPGTO", codetdpgto AS "CODETDPGTO", ceppgto AS "CEPPGTO", telefonepgto AS "TELEFONEPGTO", ruaentrega AS "RUAENTREGA", numeroentrega AS "NUMEROENTREGA", complementrega AS "COMPLEMENTREGA", bairroentrega AS "BAIRROENTREGA", codetdentrega AS "CODETDENTREGA", cepentrega AS "CEPENTREGA", telefoneentrega AS "TELEFONEENTREGA", email AS "EMAIL", ativo AS "ATIVO", limitecredito AS "LIMITECREDITO", valorop1 AS "VALOROP1", valorop2 AS "VALOROP2", valorop3 AS "VALOROP3", patrimonio AS "PATRIMONIO", numfuncionarios AS "NUMFUNCIONARIOS", pessoafisoujur AS "PESSOAFISOUJUR", pais AS "PAIS", paispagto AS "PAISPAGTO", paisentrega AS "PAISENTREGA", contribuinte AS "CONTRIBUINTE", cfoimob AS "CFOIMOB", emailentrega AS "EMAILENTREGA", emailpgto AS "EMAILPGTO", valfrete AS "VALFRETE", tptomador AS "TPTOMADOR", contribuinteiss AS "CONTRIBUINTEISS", numdependentes AS "NUMDEPENDENTES", estadocivil AS "ESTADOCIVIL", orgaopublico AS "ORGAOPUBLICO", vroutrasdeducoesirrf AS "VROUTRASDEDUCOESIRRF", optantepelosimples AS "OPTANTEPELOSIMPLES", tiporua AS "TIPORUA", tipobairro AS "TIPOBAIRRO", regimeiss AS "REGIMEISS", retencaoiss AS "RETENCAOISS",
        CASE
            WHEN dtnascimento IS NULL THEN NULL::text
            ELSE to_char(dtnascimento, 'YYYY-MM-DD"T"HH24:MI:SS'::text) || to_char(dtnascimento, 'TZH:TZM'::text)
        END AS "DTNASCIMENTO", ramoativ AS "RAMOATIV", idpais AS "IDPAIS", nacionalidade AS "NACIONALIDADE", tiporuapgto AS "TIPORUAPGTO", tipobairropgto AS "TIPOBAIRROPGTO", tiporuaentrega AS "TIPORUAENTREGA", tipobairroentrega AS "TIPOBAIRROENTREGA", idpaispgto AS "IDPAISPGTO", idpaisentrega AS "IDPAISENTREGA", entidadeexecutorapaa AS "ENTIDADEEXECUTORAPAA", inovar_auto AS "INOVAR_AUTO", formatributacao AS "FORMATRIBUTACAO", tiporendimento AS "TIPORENDIMENTO", tipoopcombustivel AS "TIPOOPCOMBUSTIVEL", porte AS "PORTE", situacaonif AS "SITUACAONIF")), XMLELEMENT(NAME "FCFOCOMPL", XMLFOREST(codcoligada AS "CODCOLIGADA", codcfo AS "CODCFO"))) AS text NO INDENT) AS xml_totvs
   FROM export.fcfo2 d;

-- ============================================================
-- VIEW: export.fcfo2_totvs_xml_lote
-- ============================================================
CREATE OR REPLACE VIEW export.fcfo2_totvs_xml_lote AS
 SELECT ('<?xml version="1.0" encoding="UTF-8"?>'::text || '
'::text) || XMLSERIALIZE(CONTENT XMLELEMENT(NAME "FinCFOImportacao", XMLATTRIBUTES('http://tempuri.org/FinCFOImportacao.xsd' AS xmlns), xmlagg(XMLCONCAT(XMLELEMENT(NAME "FCFO", XMLFOREST(codcoligada AS "CODCOLIGADA", codcfo AS "CODCFO", nomefantasia AS "NOMEFANTASIA", nome AS "NOME", cgccfo AS "CGCCFO", pagrec AS "PAGREC", NULLIF(rua::text, ''::text) AS "RUA", NULLIF(numero::text, ''::text) AS "NUMERO", NULLIF(complemento::text, ''::text) AS "COMPLEMENTO", NULLIF(bairro::text, ''::text) AS "BAIRRO", codetd AS "CODETD", cep AS "CEP", NULLIF(telefone::text, ''::text) AS "TELEFONE", NULLIF(ruapgto::text, ''::text) AS "RUAPGTO", NULLIF(numeropgto::text, ''::text) AS "NUMEROPGTO", NULLIF(complementopgto::text, ''::text) AS "COMPLEMENTOPGTO", NULLIF(bairropgto::text, ''::text) AS "BAIRROPGTO", NULLIF(codetdpgto::text, ''::text) AS "CODETDPGTO", NULLIF(ceppgto::text, ''::text) AS "CEPPGTO", NULLIF(telefonepgto::text, ''::text) AS "TELEFONEPGTO", NULLIF(ruaentrega::text, ''::text) AS "RUAENTREGA", NULLIF(numeroentrega::text, ''::text) AS "NUMEROENTREGA", NULLIF(complementrega::text, ''::text) AS "COMPLEMENTREGA", NULLIF(bairroentrega::text, ''::text) AS "BAIRROENTREGA", NULLIF(codetdentrega::text, ''::text) AS "CODETDENTREGA", NULLIF(cepentrega::text, ''::text) AS "CEPENTREGA", NULLIF(telefoneentrega::text, ''::text) AS "TELEFONEENTREGA", email AS "EMAIL", ativo AS "ATIVO", limitecredito AS "LIMITECREDITO", valorop1 AS "VALOROP1", valorop2 AS "VALOROP2", valorop3 AS "VALOROP3", patrimonio AS "PATRIMONIO", numfuncionarios AS "NUMFUNCIONARIOS", pessoafisoujur AS "PESSOAFISOUJUR", pais AS "PAIS", paispagto AS "PAISPAGTO", paisentrega AS "PAISENTREGA", contribuinte AS "CONTRIBUINTE", cfoimob AS "CFOIMOB", emailentrega AS "EMAILENTREGA", emailpgto AS "EMAILPGTO", valfrete AS "VALFRETE", tptomador AS "TPTOMADOR", contribuinteiss AS "CONTRIBUINTEISS", numdependentes AS "NUMDEPENDENTES", estadocivil AS "ESTADOCIVIL", orgaopublico AS "ORGAOPUBLICO", vroutrasdeducoesirrf AS "VROUTRASDEDUCOESIRRF", optantepelosimples AS "OPTANTEPELOSIMPLES", tiporua AS "TIPORUA", tipobairro AS "TIPOBAIRRO", regimeiss AS "REGIMEISS", retencaoiss AS "RETENCAOISS",
        CASE
            WHEN dtnascimento IS NULL THEN NULL::text
            ELSE to_char(dtnascimento, 'YYYY-MM-DD"T"HH24:MI:SSOF'::text)
        END AS "DTNASCIMENTO", ramoativ AS "RAMOATIV", idpais AS "IDPAIS", nacionalidade AS "NACIONALIDADE", tiporuapgto AS "TIPORUAPGTO", tipobairropgto AS "TIPOBAIRROPGTO", tiporuaentrega AS "TIPORUAENTREGA", tipobairroentrega AS "TIPOBAIRROENTREGA", idpaispgto AS "IDPAISPGTO", idpaisentrega AS "IDPAISENTREGA", entidadeexecutorapaa AS "ENTIDADEEXECUTORAPAA", inovar_auto AS "INOVAR_AUTO", formatributacao AS "FORMATRIBUTACAO", tiporendimento AS "TIPORENDIMENTO", tipoopcombustivel AS "TIPOOPCOMBUSTIVEL", porte AS "PORTE", situacaonif AS "SITUACAONIF")), XMLELEMENT(NAME "FCFOCOMPL", XMLFOREST(codcoligada AS "CODCOLIGADA", codcfo AS "CODCFO"))) ORDER BY nomefantasia)) AS text NO INDENT) AS xml_totvs
   FROM export.fcfo2 d;

-- ============================================================
-- VIEW: export.flan
-- ============================================================
CREATE OR REPLACE VIEW export.flan AS
 SELECT lpad(pf.codcfo::text, 6, '0'::text) AS "CODCFO",
    c.id_contract::character varying AS "NUMERODOCUMENTO",
    '0000000001'::character varying AS "CODCCUSTO",
    NULL::character varying AS "IDHISTORICO",
    to_char(i.due_date, 'DD/MM/YYYY'::text) AS "DATAEVENCIMENTO",
    to_char(c.date, 'DD/MM/YYYY'::text) AS "DATAEMISSAO",
    to_char(i.purchases, 'FM9999999990.00'::text) AS "VALORORIGINAL",
    to_char(c.interests, 'FM9999999990.00'::text) AS "VALORJUROS",
    to_char(c.discounts, 'FM9999999990.00'::text) AS "VALORDESCONTO",
    to_char(c.penalties, 'FM9999999990.00'::text) AS "VALORMULTA",
    '237'::character varying AS "CODCXA",
    'BOLETO'::character varying AS "CODTDO",
    '@@@'::character varying AS "SERIEDOCUMENTO",
    1::character varying AS "PAGREC",
    c.id_institution::character varying AS "CODFILIAL",
    '111.111'::character varying AS "CODNATFINANCEIRA"
   FROM gennera_stg.contract c
     JOIN gennera_stg.invoice i ON i.id_contract = c.id_contract
     JOIN gennera_stg.person_fisica pf ON pf.id_person = c.id_person
  WHERE c.status = 'active'::text AND i.balance > 0::numeric AND pf.codcfo IS NOT NULL AND pf.codcfo::text <> ''::text;

-- ============================================================
-- VIEW: export.ppessoa
-- ============================================================
CREATE OR REPLACE VIEW export.ppessoa AS
 SELECT id_person AS codigo,
    name::character varying(120) AS nome,
    social_name::character varying(40) AS apelido,
    COALESCE(NULLIF(birthdate, ''::text)::date, '0001-01-01'::date) AS dtnascimento,
        CASE
            WHEN civil_status = 'Casado'::text THEN 'C'::text
            WHEN civil_status = 'Desquitado'::text THEN 'D'::text
            WHEN civil_status = 'Divorciado'::text THEN 'I'::text
            WHEN civil_status = 'Outros'::text THEN 'O'::text
            WHEN civil_status = 'Solteiro'::text THEN 'S'::text
            WHEN civil_status = 'Viúvo'::text THEN 'V'::text
            ELSE NULL::text
        END::character varying(1) AS estadocivil,
        CASE
            WHEN gender = 'Masculino'::text THEN 'M'::text
            WHEN gender = 'Feminino'::text THEN 'F'::text
            ELSE NULL::text
        END::character varying(1) AS sexo,
    'Não Informado'::character varying(32) AS naturalidade,
    '--'::character varying(2) AS estadonatal,
    cod_nationality::character varying(3) AS nacionalidade,
    NULL::character varying(50) AS grauinstrucao,
    NULL::integer AS codtiporua,
    street::character varying(100) AS rua,
    street_number::character varying(8) AS numero,
    complement::character varying(30) AS complemento,
    NULL::integer AS codtipobairro,
    neighborhood::character varying(30) AS bairro,
    state::character varying(2) AS estado,
    city::character varying(32) AS cidade,
    replace(zipcode, '-'::text, ''::text)::character varying(9) AS cep,
    birth_country::character varying(16) AS pais,
    NULL::character varying(15) AS regprofissional,
    regexp_replace(cpf, '[^0-9]'::text, ''::text, 'g'::text)::character varying(11) AS cpf,
    regexp_replace(telephone_number, '[^0-9]'::text, ''::text, 'g'::text)::character varying(15) AS telefone1,
    regexp_replace(mobile_phone_number, '[^0-9]'::text, ''::text, 'g'::text)::character varying(15) AS telefone2,
    regexp_replace(commercial_phone_number, '[^0-9]'::text, ''::text, 'g'::text)::character varying(15) AS telefone3,
    regexp_replace(fax_number, '[^0-9]'::text, ''::text, 'g'::text)::character varying(15) AS fax,
    email,
    rg::character varying(15) AS cartidentidade,
    rg_issuing_state::character varying(2) AS ufcartident,
    rg_issuing_agency::character varying(15) AS orgemissorident,
    rg_issue_date::date AS dtemissaoident,
    voter_document::character varying(14) AS tituloeleitor,
    voter_document_zone::character varying(6) AS zonatiteleitor,
    voter_document_section::character varying(6) AS secaotiteleitor,
        CASE
            WHEN NULLIF(voter_document_issue_date, ''::text) IS NOT NULL THEN NULLIF(voter_document_issue_date, ''::text)::date
            ELSE NULL::date
        END AS dttiteleitor,
    voter_document_state::character varying(2) AS esteleit,
    NULL::character varying(10) AS carteiratrab,
    NULL::character varying(5) AS seriecarttrab,
    NULL::character varying(2) AS ufcarttrab,
    NULL::date AS dtcarttrab,
    0 AS nit,
    NULL::character varying(15) AS cartmotorista,
    NULL::character varying(5) AS tipocarthabilit,
    NULL::date AS dtvenchabilit,
    NULL::character varying(10) AS sitmilitar,
    NULL::character varying(40) AS certifreserv,
    NULL::character varying(10) AS categmilitar,
    NULL::character varying(10) AS csm,
    NULL::date AS dtexpcml,
    NULL::character varying(10) AS exped,
    NULL::character varying(10) AS rm,
    NULL::character varying(15) AS nroreggeral,
    NULL::character varying(15) AS npassaporte,
    NULL::character varying(20) AS paisorigem,
    NULL::date AS dtemisspassaporte,
    NULL::date AS dtvalpassaporte,
        CASE
            WHEN ethnicity = 'Indígena'::text THEN 0
            WHEN ethnicity = 'Branca'::text THEN 2
            WHEN ethnicity = 'Preta'::text THEN 4
            WHEN ethnicity = 'Amarela'::text THEN 6
            WHEN ethnicity = 'Parda'::text THEN 8
            ELSE NULL::integer
        END AS corraca,
        CASE
            WHEN special_needs::jsonb ? 'Deficiência Física'::text AND ((special_needs::jsonb ->> 'Deficiência Física'::text)::boolean) = true THEN 1
            WHEN special_needs::jsonb ? 'Deficiência Múltipla'::text AND ((special_needs::jsonb ->> 'Deficiência Múltipla'::text)::boolean) = true THEN 1
            ELSE 0
        END AS deficientefisico,
        CASE
            WHEN special_needs::jsonb ? 'Deficiência auditiva'::text AND ((special_needs::jsonb ->> 'Deficiência auditiva'::text)::boolean) = true THEN 2
            WHEN special_needs::jsonb ? 'Surdez'::text AND ((special_needs::jsonb ->> 'Surdez'::text)::boolean) = true THEN 2
            ELSE 0
        END AS deficienteauditivo,
    0 AS deficientefala,
        CASE
            WHEN special_needs::jsonb ? 'Baixa visão'::text AND ((special_needs::jsonb ->> 'Baixa visão'::text)::boolean) = true THEN 4
            ELSE 0
        END AS deficientevisual,
        CASE
            WHEN special_needs::jsonb ? 'Deficiência Intelectual'::text AND ((special_needs::jsonb ->> 'Deficiência Intelectual'::text)::boolean) = true THEN 5
            WHEN special_needs::jsonb ? 'Transtorno do espectro autista (TEA)'::text AND ((special_needs::jsonb ->> 'Transtorno do espectro autista (TEA)'::text)::boolean) = true THEN 5
            WHEN special_needs::jsonb ? 'Síndrome de Asperger'::text AND ((special_needs::jsonb ->> 'Síndrome de Asperger'::text)::boolean) = true THEN 5
            WHEN special_needs::jsonb ? 'Transtorno desintegrativo da infância'::text AND ((special_needs::jsonb ->> 'Transtorno desintegrativo da infância'::text)::boolean) = true THEN 5
            WHEN special_needs::jsonb ? 'Síndrome de Rett'::text AND ((special_needs::jsonb ->> 'Síndrome de Rett'::text)::boolean) = true THEN 5
            WHEN special_needs::jsonb ? 'Altas habilidades/Superdotação'::text AND ((special_needs::jsonb ->> 'Altas habilidades/Superdotação'::text)::boolean) = true THEN 5
            ELSE 0
        END AS deficientemental,
    NULL::character varying(120) AS recursorealizacaotrab,
    NULL::character varying(120) AS recursoacessibilidade,
    NULL::integer AS profissao,
    NULL::character varying(60) AS empresa,
    NULL::character varying(3) AS ocupacao,
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
                  WHERE e.id_person = pf.id_person AND e.class_name = h.turma::text))), NULL::text) AS tiposang,
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM gennera_stg.enrollment e
              WHERE e.id_person = pf.id_person)) THEN 1
            ELSE 0
        END AS aluno,
        CASE
            WHEN email ~~* '%@edf.pro.br'::text THEN 1
            ELSE 0
        END AS professor,
    0 AS usuariobiblios,
    0 AS funcionario,
    0 AS exfuncionario,
    0 AS candidato,
        CASE
            WHEN deceased IS NULL THEN 0
            WHEN deceased = 'true'::text OR deceased = '1'::text OR upper(deceased) = 'SIM'::text THEN 1
            ELSE 0
        END AS falecido,
    NULL::date AS dataobito,
    NULL::character varying(50) AS matriculaobito,
    social_name::character varying(120) AS nomesocial
   FROM gennera_stg.person_fisica pf;

-- ============================================================
-- VIEW: export.professor_qh_enriquecido
-- ============================================================
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
   FROM final_match;

-- ============================================================
-- VIEW: export.saude
-- ============================================================
CREATE OR REPLACE VIEW export.saude AS
 SELECT upper(TRIM(BOTH FROM un1health2025."Aluno")) AS nome_normalizado,
    un1health2025."Tipo Sanguíneo" AS tipo_sanguineo,
    'un1'::text AS fonte,
    un1health2025."Turma"::text AS turma
   FROM gennera_stg.un1health2025
UNION ALL
 SELECT upper(TRIM(BOTH FROM un2health2025."Aluno")) AS nome_normalizado,
    un2health2025."Tipo Sanguíneo" AS tipo_sanguineo,
    'un2'::text AS fonte,
    un2health2025."Turma"::text AS turma
   FROM gennera_stg.un2health2025;

-- ============================================================
-- VIEW: export.sbolsa
-- ============================================================
CREATE OR REPLACE VIEW export.sbolsa AS
 WITH descontos AS (
         SELECT round(i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric, 2) AS pct,
            count(DISTINCT i.id_contract) AS n_contratos
           FROM gennera_stg.invoice i
          WHERE i.discounts > 0::numeric AND i.purchases > 0::numeric AND i.discounts <= i.purchases AND (i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric) >= 1::numeric
          GROUP BY (round(i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric, 2))
         HAVING count(DISTINCT i.id_contract) >= 10
        )
 SELECT 1 AS "CODCOLIGADA",
    NULL::integer AS "CODCOLCFO",
    NULL::character varying(25) AS "CODCFO",
    ((('Bolsa '::text || pct::text) || '%'::text))::character varying(60) AS "NOME",
    replace(pct::numeric(10,4)::text, '.'::text, ','::text) AS "VALOR",
    1 AS "CODTIPOCURSO",
    '1'::character varying(1) AS "RENOVACAOAUTOMATICA",
    '0'::character varying(1) AS "VALIDADELIMITADA",
    '0'::character varying(1) AS "FIES",
    '0'::character varying(1) AS "BOLSAFUNC",
    NULL::integer AS "ORDEMPERDA",
    'N'::character varying(1) AS "TIPOSAC",
    'S'::character varying(1) AS "ATIVA",
    'S'::character varying(1) AS "PERMITEALTERARVALOR",
    'P'::character varying(1) AS "TIPODESC",
    NULL::character varying(60) AS "CLASSIFICACAOBOLSA",
    'N'::character varying(1) AS "VERIFICAINADIMPLENCIA"
   FROM descontos
  ORDER BY pct;

-- ============================================================
-- VIEW: export.sbolsaaluno
-- ============================================================
CREATE OR REPLACE VIEW export.sbolsaaluno AS
 WITH alunos_1b_2023 AS (
         SELECT DISTINCT ON (scu.id_person) scu.code_unif AS ra,
            e.id_enrollment,
            e.id_person
           FROM gennera_stg.enrollment e
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
          WHERE e.class_name = '1B'::text AND e.academic_calendar = '2023'::text
          ORDER BY scu.id_person, e.id_enrollment
        ), servicos_base AS (
         SELECT TRIM(BOTH FROM servicos." Matrícula.") AS ra,
            TRIM(BOTH FROM servicos." Item") AS servico_nome,
            EXTRACT(month FROM to_date(TRIM(BOTH FROM servicos."Competência"), 'DD/MM/YYYY'::text))::integer AS mes,
            round(replace(replace(replace(TRIM(BOTH FROM servicos." DescBolsas"), 'R$ '::text, ''::text), '.'::text, ''::text), ','::text, '.'::text)::numeric / NULLIF(replace(replace(replace(TRIM(BOTH FROM servicos." Compras"), 'R$ '::text, ''::text), '.'::text, ''::text), ','::text, '.'::text)::numeric, 0::numeric) * 100::numeric, 2) AS pct
           FROM gennera_stg.servicos
          WHERE (TRIM(BOTH FROM servicos." Matrícula.") IN ( SELECT alunos_1b_2023.ra
                   FROM alunos_1b_2023)) AND (TRIM(BOTH FROM servicos." Item") <> ALL (ARRAY['-'::text, 'Item'::text, ''::text])) AND (TRIM(BOTH FROM servicos." DescBolsas") <> ALL (ARRAY['R$ 0,00'::text, ''::text]))
        ), islands AS (
         SELECT t.ra,
            t.servico_nome,
            t.pct,
            min(t.mes) AS parcela_ini,
            max(t.mes) AS parcela_fim
           FROM ( SELECT servicos_base.ra,
                    servicos_base.servico_nome,
                    servicos_base.mes,
                    servicos_base.pct,
                    servicos_base.mes - row_number() OVER (PARTITION BY servicos_base.ra, servicos_base.servico_nome, servicos_base.pct ORDER BY servicos_base.mes) AS grp
                   FROM servicos_base) t
          GROUP BY t.ra, t.servico_nome, t.pct, t.grp
        ), base AS (
         SELECT 1 AS "CODCOLIGADA",
            st."CODCURSO"::character varying(10) AS "CODCURSO",
            st."CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
            st."CODGRADE"::character varying(10) AS "CODGRADE",
            st."TURNO"::character varying(15) AS "TURNO",
                CASE
                    WHEN inst.code = 'un1'::text THEN 1
                    WHEN inst.code = 'un2'::text THEN 2
                    ELSE NULL::integer
                END AS "CODFILIAL",
            1 AS "CODTIPOCURSO",
            a.ra::character varying(20) AS "RA",
            '2023'::character varying(10) AS "CODPERLET",
            ec.id_contract::character varying(20) AS "CODCONTRATO",
            ((('Bolsa '::text || isl.pct) || '%'::text))::character varying(60) AS "NOMEBOLSA",
            isl.servico_nome::character varying(60) AS "SERVICO",
            NULL::date AS "DTINICIO",
            NULL::date AS "DTFIM",
            isl.pct::numeric(10,4) AS "DESCONTO",
            'P'::character varying(1) AS "TIPODESC",
            NULL::text AS "OBS",
            isl.parcela_ini AS "PARCELAINICIAL",
            isl.parcela_fim AS "PARCELAFINAL",
            'mestre'::character varying(20) AS "CODUSUARIO",
            NULL::integer AS "ORDEMBOLSA",
            NULL::date AS "DATACONCESSAO",
            NULL::date AS "DATAAUTORIZACAO",
            NULL::numeric(10,4) AS "TETOVALOR",
            'S'::character varying(1) AS "ATIVA",
            NULL::date AS "DATACANCELAMENTO",
            NULL::character varying(20) AS "CODUSUARIOCANCEL",
            NULL::character varying(60) AS "MOTIVOCANCELAMENTO"
           FROM islands isl
             JOIN alunos_1b_2023 a ON a.ra::text = isl.ra
             JOIN gennera_stg.enrollment e ON e.id_enrollment = a.id_enrollment
             JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
             JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = a.id_enrollment
             JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
          WHERE (inst.code = ANY (ARRAY['un1'::text, 'un2'::text])) AND (isl.servico_nome ~ '^2023 MENS'::text AND ec.details ~~* '%ensalidade%'::text OR (isl.servico_nome ~~* '%ANUIDADE%'::text OR isl.servico_nome ~ '^2023 [0-9]'::text) AND ec.details ~~* '%atr%cula%'::text OR (isl.servico_nome ~~* '%ALIM%'::text OR isl.servico_nome ~~* '%MAT DIDAT%'::text) AND ec.details ~~* '%ervi%'::text)
        )
 SELECT DISTINCT ON ("CODCONTRATO", "NOMEBOLSA", "PARCELAINICIAL", "SERVICO") "CODCOLIGADA",
    "CODCURSO",
    "CODHABILITACAO",
    "CODGRADE",
    "TURNO",
    "CODFILIAL",
    "CODTIPOCURSO",
    "RA",
    "CODPERLET",
    "CODCONTRATO",
    "NOMEBOLSA",
    "SERVICO",
    "DTINICIO",
    "DTFIM",
    "DESCONTO",
    "TIPODESC",
    "OBS",
    "PARCELAINICIAL",
    "PARCELAFINAL",
    "CODUSUARIO",
    "ORDEMBOLSA",
    "DATACONCESSAO",
    "DATAAUTORIZACAO",
    "TETOVALOR",
    "ATIVA",
    "DATACANCELAMENTO",
    "CODUSUARIOCANCEL",
    "MOTIVOCANCELAMENTO"
   FROM base
  ORDER BY "CODCONTRATO", "NOMEBOLSA", "PARCELAINICIAL", "SERVICO";

-- ============================================================
-- VIEW: export.sbolsapletivo
-- ============================================================
CREATE OR REPLACE VIEW export.sbolsapletivo AS
 WITH sbolsa_pcts AS (
         SELECT round(i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric, 2) AS pct
           FROM gennera_stg.invoice i
          WHERE i.discounts > 0::numeric AND i.purchases > 0::numeric AND i.discounts <= i.purchases AND (i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric) >= 1::numeric
          GROUP BY (round(i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric, 2))
         HAVING count(DISTINCT i.id_contract) >= 10
        ), por_ano AS (
         SELECT DISTINCT
                CASE
                    WHEN inst.code = 'un1'::text THEN 1
                    WHEN inst.code = 'un2'::text THEN 2
                    ELSE NULL::integer
                END AS codfilial,
            i.year::text AS codperlet,
            round(i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric, 2) AS pct
           FROM gennera_stg.invoice i
             JOIN gennera_stg.enrollment_contract ec ON ec.id_contract = i.id_contract
             JOIN gennera_stg.enrollment e ON e.id_enrollment = ec.id_enrollment
             JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
          WHERE i.discounts > 0::numeric AND i.purchases > 0::numeric AND i.discounts <= i.purchases AND (i.discounts / NULLIF(i.purchases, 0::numeric) * 100::numeric) >= 1::numeric AND (inst.code = ANY (ARRAY['un1'::text, 'un2'::text]))
        )
 SELECT 1 AS "CODCOLIGADA",
    1 AS "CODTIPOCURSO",
    pa.codfilial AS "CODFILIAL",
    pa.codperlet::character varying(10) AS "CODPERLET",
    ((('Bolsa '::text || pa.pct::text) || '%'::text))::character varying(60) AS "NOMEBOLSA"
   FROM por_ano pa
     JOIN sbolsa_pcts sb ON sb.pct = pa.pct
  ORDER BY pa.codfilial, pa.codperlet, pa.pct;

-- ============================================================
-- VIEW: export.scontrato
-- ============================================================
CREATE OR REPLACE VIEW export.scontrato AS
 WITH ec_dedup AS (
         SELECT DISTINCT enrollment_contract.id_enrollment,
            enrollment_contract.id_contract,
            enrollment_contract.details
           FROM gennera_stg.enrollment_contract
        ), base AS (
         SELECT 1 AS "CODCOLIGADA",
            st."CODCURSO"::character varying(10) AS "CODCURSO",
            st."CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
            st."CODGRADE"::character varying(10) AS "CODGRADE",
            st."TURNO"::character varying(15) AS "TURNO",
                CASE
                    WHEN inst.code = 'un1'::text THEN 1
                    WHEN inst.code = 'un2'::text THEN 2
                    ELSE NULL::integer
                END AS "CODFILIAL",
            1 AS "CODTIPOCURSO",
            scu.code_unif::character varying(20) AS "RA",
            e.academic_calendar::character varying(10) AS "CODPERLET",
            ec.id_contract::character varying(20) AS "CODCONTRATO",
            NULL::character varying(10) AS "CODPLANOPGTO",
            to_char(c.date, 'YYYY-MM-DD'::text)::character varying(10) AS "DTCONTRATO",
            to_char(c.date, 'YYYY-MM-DD'::text)::character varying(10) AS "DTASSINATURA",
            'N'::character varying(1) AS "DIAFIXO",
            NULL::integer AS "DIAVENCIMENTO",
                CASE
                    WHEN ec.details IS NULL OR ec.details ~~* '%ensalidad%'::text OR ec.details ~~* '%atr%cula%'::text OR ec.details ~~* '%Contrato%'::text OR ec.details ~~* '%ari%vel%'::text THEN 'P'::text
                    ELSE 'S'::text
                END::character varying(1) AS "TIPOCONTRATO",
            'S'::character varying(1) AS "TIPOBOLSA",
            NULL::character varying(25) AS "CODCCUSTO",
                CASE
                    WHEN c.status = 'active'::text THEN 'S'::text
                    ELSE 'N'::text
                END::character varying(1) AS "ASSINADO",
                CASE
                    WHEN c.status = 'deleted'::text THEN 'S'::text
                    ELSE 'N'::text
                END::character varying(1) AS "STATUS",
            NULL::date AS "DTCANCELAMENTO"
           FROM ec_dedup ec
             JOIN gennera_stg.contract c ON c.id_contract = ec.id_contract
             JOIN gennera_stg.enrollment e ON e.id_enrollment = ec.id_enrollment
             JOIN gennera_stg.institution inst ON inst.id_institution = e.id_institution
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
             JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
          WHERE (inst.code = ANY (ARRAY['un1'::text, 'un2'::text])) AND scu.code_unif IS NOT NULL AND e.academic_calendar IS NOT NULL
        )
 SELECT DISTINCT ON ("CODCONTRATO") "CODCOLIGADA",
    "CODCURSO",
    "CODHABILITACAO",
    "CODGRADE",
    "TURNO",
    "CODFILIAL",
    "CODTIPOCURSO",
    "RA",
    "CODPERLET",
    "CODCONTRATO",
    "CODPLANOPGTO",
    "DTCONTRATO",
    "DTASSINATURA",
    "DIAFIXO",
    "DIAVENCIMENTO",
    "TIPOCONTRATO",
    "TIPOBOLSA",
    "CODCCUSTO",
    "ASSINADO",
    "STATUS",
    "DTCANCELAMENTO"
   FROM base
  ORDER BY "CODCONTRATO", "RA";

-- ============================================================
-- VIEW: export.scurso
-- ============================================================
CREATE OR REPLACE VIEW export.scurso AS
 SELECT DISTINCT ON (id_institution, course_name) '1'::text AS "CODCOLIGADA",
    1::text AS "CODTIPOCURSO",
    course_code AS "CODCURSO",
    course_name AS "NOME",
    NULL::text AS "DESCRICAO",
    NULL::text AS "COMPLEMENTO",
    NULL::text AS "CODCURINEP",
    NULL::text AS "DECRETO",
    NULL::text AS "REGCONTRATO",
    NULL::text AS "CFGMATRICULA",
    NULL::text AS "HABILITACAO",
    NULL::text AS "CAPES",
    'P'::text AS "CURPRESDIST",
    NULL::text AS "CODMODALIDADECURSO",
    NULL::text AS "ESCOLA",
    NULL::text AS "AREA",
    NULL::text AS "MASCARATURMA",
    NULL::text AS "CODEIXOTECNOLOGICO"
   FROM gennera_stg.academic a
  WHERE id_institution <> 3
  ORDER BY id_institution, course_name, course_code;

-- ============================================================
-- VIEW: export.sdisciplina
-- ============================================================
CREATE OR REPLACE VIEW export.sdisciplina AS
 SELECT 1 AS codcoligada,
    1 AS codtipocurso,
    discipline_code AS coddisc,
    NULL::character varying(30) AS coddischist,
    discipline_name AS nome,
    NULL::character varying(30) AS nomereduzido,
    NULL::character varying(255) AS complemento,
    NULL::character varying(1) AS cursolivre,
    NULL::character varying(1) AS tipoaula,
    NULL::character varying(1) AS tiponota,
    NULL::numeric(10,4) AS ch,
    NULL::numeric(10,4) AS chestagio,
    NULL::integer AS decimais,
    NULL::integer AS numcreditos,
    NULL::character varying(2000) AS objetivo,
    NULL::character varying(1) AS tipodiscprovao,
    NULL::numeric(10,4) AS chteorica,
    NULL::numeric(10,4) AS chpratica,
    NULL::numeric(10,4) AS chlaboratorial,
    NULL::character varying(10) AS codgrupocomplemento,
    NULL::character varying(1) AS estagio,
    NULL::numeric(15,4) AS chtrabalhocampo,
    NULL::numeric(15,4) AS chseminario,
    NULL::numeric(15,4) AS chorientacaotutorial,
    NULL::numeric(15,4) AS chteoricopratica
   FROM gennera_stg.disciplina d
  WHERE discipline_code::text !~~ '%E%'::text
  ORDER BY discipline_name;

-- ============================================================
-- VIEW: export.setapas
-- ============================================================
CREATE OR REPLACE VIEW export.setapas AS
 WITH etapas(codetapa, descricao) AS (
         VALUES (1,('1'::text || 'º'::text) || ' Trimestre'::text), (2,('2'::text || 'º'::text) || ' Trimestre'::text), (3,('3'::text || 'º'::text) || ' Trimestre'::text), (4,(('Recupera'::text || 'ç'::text) || 'ã'::text) || 'o Anual'::text)
        )
 SELECT COALESCE(sd."CODCOLIGADA", s."CODCOLIGADA") AS "CODCOLIGADA",
    s."CODCURSO",
    s."CODHABILITACAO",
    s."CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    s."CODPERLET",
    sd."CODTURMA",
    sd."CODDISC",
    e.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
    e.descricao::character varying(60) AS "DESCRICAO",
    NULL::numeric AS "PONTDIST",
    NULL::numeric AS "MEDIA",
    NULL::numeric AS "FREQMIN",
    NULL::date AS "DTINICIO",
    NULL::date AS "DTFIM",
    NULL::date AS "DTINICIODIGITACAO",
    NULL::date AS "DTLIMITEDIGITACAO",
    'N'::character varying(1) AS "DIGAULASDADAS",
    COALESCE(sp."EXIBIRPORTAL", 'S'::text)::character varying(1) AS "EXIBENANWEB",
    'N'::character varying(1) AS "ETAPAFINAL",
    NULL::text AS "TITULO",
    NULL::integer AS "AULASDADAS",
    NULL::integer AS "AULASPREVISTAS",
    NULL::character varying(1) AS "CONCEITOGRAFICO",
    NULL::character varying(1) AS "EXIBENOGRAFICO",
    NULL::date AS "DTLIMITECONTPREVISTO",
    NULL::date AS "DTLIMITECONTEFETIVO",
    NULL::character varying(1) AS "DISPONIVELALUNOS",
    NULL::character varying(1) AS "ETAPAENCERRADA"
   FROM export.sturmadisc sd
     JOIN export.sturma s ON s."CODTURMA" = sd."CODTURMA"::text AND s."CODPERLET" = sd."CODPERLET"::text
     LEFT JOIN export.spletivo sp ON sp."CODPERLET" = s."CODPERLET"
     CROSS JOIN etapas e;

-- ============================================================
-- VIEW: export.sfrequencia
-- ============================================================
CREATE OR REPLACE VIEW export.sfrequencia AS
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
        ), schedule AS (
         SELECT DISTINCT matchs.codcoligada AS "CODCOLIGADA",
                CASE
                    WHEN matchs.codfilial = 1 THEN 'Integral'::text
                    WHEN matchs.codfilial = 2 THEN
                    CASE substr(matchs.codturma, length(matchs.codturma) - 1, 1)
                        WHEN 'M'::text THEN 'Matutino'::text
                        WHEN 'T'::text THEN 'Vespertino'::text
                        WHEN 'I'::text THEN 'Integral'::text
                        ELSE COALESCE(matchs.turno, 'Integral'::text)
                    END
                    ELSE COALESCE(matchs.turno, 'Integral'::text)
                END AS turno,
            matchs.codfilial AS "CODFILIAL",
            matchs.codtipocurso AS "CODTIPOCURSO",
            matchs.codperlet AS "CODPERLET",
            matchs.codturma AS "CODTURMA",
            matchs.coddisc,
            matchs.diasemana,
            to_char(matchs.horainicial::interval, 'HH24:MI'::text) AS horainicial,
            to_char(matchs.horafinal::interval, 'HH24:MI'::text) AS horafinal,
                CASE
                    WHEN matchs.codperlet ~ '^\d{4}$'::text THEN to_date('01/01/'::text || matchs.codperlet, 'DD/MM/YYYY'::text)
                    ELSE NULL::date
                END AS datainicial,
                CASE
                    WHEN matchs.codperlet ~ '^\d{4}$'::text THEN to_date('31/12/'::text || matchs.codperlet, 'DD/MM/YYYY'::text)
                    ELSE NULL::date
                END AS datafinal
           FROM matchs
          WHERE matchs.rn = 1
        ), lesson AS (
         SELECT s."CODCOLIGADA",
            s.turno,
            s."CODFILIAL",
            s."CODTIPOCURSO",
            s."CODPERLET",
            s."CODTURMA",
            s.coddisc,
            s.diasemana,
            s.horainicial,
            s.horafinal,
            s.datainicial,
            s.datafinal,
            d.data,
            row_number() OVER (PARTITION BY s."CODCOLIGADA", s."CODTURMA", s."CODPERLET", s.coddisc ORDER BY d.data, s.horainicial)::integer AS aula_num
           FROM schedule s
             CROSS JOIN LATERAL ( SELECT generate_series(COALESCE(s.datainicial, (s."CODPERLET" || '-01-01'::text)::date)::timestamp with time zone, COALESCE(s.datafinal, (s."CODPERLET" || '-12-31'::text)::date)::timestamp with time zone, '1 day'::interval)::date AS data) d
          WHERE (EXTRACT(dow FROM d.data) + 1::numeric)::integer = s.diasemana
        ), matricula AS (
         SELECT DISTINCT sd."CODCOLIGADA",
            sd."CODTURMA",
            sd."CODPERLET",
            sd."CODDISC"::text AS coddisc,
            scu.code_unif::character varying(20) AS ra
           FROM gennera_stg.enrollment_record er
             JOIN gennera_stg.enrollment e ON e.id_enrollment = er.id_enrollment
             JOIN export.sturmadisc sd ON sd."CODTURMA"::text = e.class_name AND sd."CODPERLET"::text = e.academic_calendar AND sd."CODDISC"::text = er.disc_code
             JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
          WHERE (er.institution_name = ANY (ARRAY['Escola do Futuro'::text, 'Escola do Futuro - Unidade 1'::text, 'Escola do Futuro - Unidade 2'::text])) AND scu.code_unif IS NOT NULL AND er.disc_code IS NOT NULL
        )
 SELECT l."CODCOLIGADA",
    l."CODFILIAL",
    l."CODTIPOCURSO",
    l."CODTURMA",
    l.horainicial AS "HORAINICIAL",
    l.horafinal AS "HORAFINAL",
    l.turno::character varying(15) AS "NOMETURNO",
    l.diasemana AS "DIASEMANA",
    l.aula_num AS "AULA",
    l."CODPERLET",
    l.coddisc AS "CODDISC",
    m.ra AS "RA",
    to_char(l.data::timestamp with time zone, 'YYYY-MM-DD'::text)::character varying(10) AS "DATA",
    ''::character varying(1) AS "PRESENCA",
    NULL::character varying(1) AS "JUSTIFICADA",
    NULL::integer AS "IDJUSTIFICATIVAFALTA"
   FROM lesson l
     JOIN matricula m ON m."CODCOLIGADA" = l."CODCOLIGADA" AND m."CODTURMA"::text = l."CODTURMA" AND m."CODPERLET"::text = l."CODPERLET" AND m.coddisc = l.coddisc;

-- ============================================================
-- VIEW: export.sgrade
-- ============================================================
CREATE OR REPLACE VIEW export.sgrade AS
 SELECT DISTINCT 1 AS codcoligada,
    a.course_code::character varying(10) AS codcurso,
    a.code_module::character varying(10) AS codhabilitacao,
    att.academic_calendar::character varying(10) AS codgrade,
    a.module_name::character varying(60) AS descricao,
    NULL::date AS dtinicio,
    NULL::date AS dtfim,
    NULL::integer AS cargahoraria,
    '0'::character varying(1) AS controlevagas,
    '1'::character varying(1) AS status,
    NULL::character varying(10) AS codcursoprox,
    NULL::character varying(10) AS codhabilitacaoprox,
    NULL::character varying(10) AS codgradeprox,
    NULL::integer AS maxcredperiodo,
    NULL::integer AS mincredperiodo,
    'S'::character varying(1) AS regime,
    'H'::character varying(1) AS tipoatividadecurricular,
    'H'::character varying(1) AS tipoeletiva,
    'H'::character varying(1) AS tipooptativa,
    NULL::date AS dtdou,
    NULL::numeric(15,4) AS totalcreditos
   FROM gennera_stg.academic a
     LEFT JOIN gennera_stg.attendance att ON att.subject_name = a.subject_name AND att.course_name = a.course_name AND att.module_name = a.module_name
  WHERE a.id_institution <> 3 AND att.academic_calendar IS NOT NULL;

-- ============================================================
-- VIEW: export.shabilitacao
-- ============================================================
CREATE OR REPLACE VIEW export.shabilitacao AS
 SELECT DISTINCT ON (a.id_institution, a.course_code, a.code_module) '1'::text AS "CODCOLIGADA",
    a.course_code AS "CODCURSO",
    a.code_module AS "CODHABILITACAO",
    a.module_name AS "NOME",
    NULL::text AS "DESCRICAO",
    NULL::text AS "COMPLEMENTO",
    NULL::text AS "COMPLEMENTO2",
    NULL::integer AS "CODCURSOHIST",
    NULL::integer AS "CODSERIEHIST",
    NULL::text AS "TEXTOCONCLUSAO",
    NULL::text AS "DECRETO",
    NULL::numeric(10,4) AS "INTEGRALIZACAO",
    NULL::text AS "CODHABINEP",
    NULL::date AS "DTPROVAO",
    NULL::text AS "JURAMENTO"
   FROM gennera_stg.academic a
     LEFT JOIN gennera_stg.curriculum c ON a.course_name = c.course_name
  WHERE a.id_institution <> 3 AND (c.curriculum_name IS NULL OR c.curriculum_name <> 'Teste'::text)
  ORDER BY a.id_institution, a.course_code, a.code_module;

-- ============================================================
-- VIEW: export.shabilitacaoaluno
-- ============================================================
CREATE OR REPLACE VIEW export.shabilitacaoaluno AS
 SELECT DISTINCT ON (scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODPERLET") st."CODCOLIGADA",
    st."CODCURSO",
    st."CODHABILITACAO",
    st."CODGRADE",
    st."TURNO",
    st."CODFILIAL",
    st."CODTIPOCURSO",
    scu.code_unif::character varying(20) AS "RA",
    NULL::character varying(60) AS "INGRESSO",
    NULL::character varying(60) AS "INSTITUICAO",
        CASE
            WHEN e.status = 'cancelled'::text THEN 'Cancelado'::text
            WHEN e.academic_calendar::integer < EXTRACT(year FROM CURRENT_DATE)::integer THEN 'ConcluÃ­do'::text
            WHEN e.status = 'active'::text THEN 'Cursando'::text
            WHEN e.status = 'open'::text THEN 'Cursando'::text
            WHEN e.status = 'reserved'::text THEN 'Matriculado'::text
            WHEN e.status = 'closed'::text THEN 'ConcluÃ­do'::text
            ELSE 'Cursando'::text
        END::character varying(30) AS "STATUS",
    NULL::date AS "DTINGRESSO",
    NULL::character varying(10) AS "PONTOSVESTIBULAR",
    NULL::character varying(20) AS "CLASSIFICACAOVESTIBULAR",
    NULL::numeric(10,4) AS "MEDIAVESTIBULAR",
    NULL::date AS "DTCOLACAOGRAU",
    NULL::date AS "DTEMISDIPLOMA",
    NULL::character varying(10) AS "REGISTROCONCLUSAO",
    NULL::character varying(10) AS "LIVROREGISTRO",
    NULL::character varying(10) AS "PAGINAREGISTRO",
    NULL::date AS "DTCONCLUSAOCURSO",
    NULL::numeric(10,4) AS "CR",
    NULL::numeric(10,4) AS "MEDIAGLOBAL",
    NULL::date AS "DTPROVAO",
    NULL::character varying(20) AS "PROCESSOREGISTRO",
    NULL::character varying(60) AS "INSTITUICAODIPLOMA",
    NULL::character varying(1) AS "REALIZOUPROVAO",
    NULL::character varying(10) AS "CODCURSOTRANSF",
    NULL::character varying(10) AS "CODHABILITACAOTRANSF",
    NULL::character varying(10) AS "CODGRADETRANSF",
    NULL::character varying(15) AS "TURNOTRANSF",
    NULL::integer AS "CODTIPOCURSOTRANSF",
    NULL::integer AS "CODFILIALTRANSF",
    NULL::character varying(60) AS "MOTIVOTRANSF",
    NULL::numeric(10,4) AS "INDICECARENCIA",
    NULL::text AS "OBSERVACAO",
    NULL::integer AS "CODINSTITUICAO",
    NULL::integer AS "CODINSTTITUICAODIPLOMA",
    NULL::character varying(100) AS "CAMPUS",
    NULL::character varying(100) AS "LOCALIZACAOFISICA"
   FROM gennera_stg.enrollment e
     JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
  WHERE scu.code_unif IS NOT NULL
  ORDER BY scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODPERLET", (
        CASE e.status
            WHEN 'active'::text THEN 1
            WHEN 'open'::text THEN 2
            WHEN 'reserved'::text THEN 3
            WHEN 'cancelled'::text THEN 4
            WHEN 'closed'::text THEN 5
            ELSE 6
        END);

-- ============================================================
-- VIEW: export.shabilitacaofilial
-- ============================================================
CREATE OR REPLACE VIEW export.shabilitacaofilial AS
 SELECT row_number() OVER (ORDER BY (codgrade::integer), codcurso, codhabilitacao)::integer AS idhabilitacaofilial,
    codcoligada,
    codfilial,
    codtipocurso,
    codcurso,
    codhabilitacao,
    codgrade,
    codturno,
    codccusto,
    ativo,
    coddepartamento,
    emailcoordenacao,
    decretocurso,
    decretohabilitacao,
    descricaocurso,
    descricaohabilitacao
   FROM ( SELECT DISTINCT 1 AS codcoligada,
                CASE
                    WHEN a.id_institution = 1 THEN 1
                    WHEN a.id_institution = 2 THEN 2
                    ELSE 1
                END AS codfilial,
            1 AS codtipocurso,
            sd."CODCURSO"::character varying(10) AS codcurso,
            sd."CODHABILITACAO"::character varying(10) AS codhabilitacao,
            sd."CODGRADE"::character varying(10) AS codgrade,
            'Integral'::text AS codturno,
            '0000000001'::character varying(25) AS codccusto,
            'S'::character varying(1) AS ativo,
            NULL::character varying(25) AS coddepartamento,
            NULL::character varying(60) AS emailcoordenacao,
            NULL::text AS decretocurso,
            NULL::text AS decretohabilitacao,
            NULL::text AS descricaocurso,
            NULL::text AS descricaohabilitacao
           FROM export.sdiscgrade sd
             LEFT JOIN gennera_stg.academic a ON a.course_code = sd."CODCURSO" AND a.code_module::text = sd."CODHABILITACAO") base
  WHERE codhabilitacao IS NOT NULL AND codcurso IS NOT NULL;

-- ============================================================
-- VIEW: export.shabilitacaofilialpl
-- ============================================================
CREATE OR REPLACE VIEW export.shabilitacaofilialpl AS
 SELECT DISTINCT 1 AS "CODCOLIGADA",
    "CODGRADE" AS "CODPERLET",
    TRIM(BOTH FROM "CODCURSO") AS "CODCURSO",
        CASE
            WHEN "CODHABILITACAO" ~ '^\d+$'::text THEN "CODHABILITACAO"::integer
            ELSE NULL::integer
        END AS "CODHABILITACAO",
        CASE
            WHEN "CODGRADE" ~ '^\d+$'::text THEN "CODGRADE"::integer
            ELSE NULL::integer
        END AS "CODGRADE",
    'Integral'::text AS "TURNO",
        CASE
            WHEN TRIM(BOTH FROM "CODCURSO") = 'EF1'::text AND "CODHABILITACAO" ~ '^\d+$'::text AND ("CODHABILITACAO"::integer = ANY (ARRAY[1, 2])) AND (EXISTS ( SELECT 1
               FROM gennera_stg.academic a
              WHERE a.code_module::text = sd."CODHABILITACAO" AND (a.module_name = ANY (ARRAY['Jardim 2'::text, '1º Ano'::text, 'Maternal 3'::text, '2º Ano'::text, 'Jardim 1'::text, 'Maternal 2'::text])))) THEN 2
            WHEN TRIM(BOTH FROM "CODCURSO") = 'EI'::text AND (EXISTS ( SELECT 1
               FROM gennera_stg.academic a
              WHERE a.code_module::text = sd."CODHABILITACAO" AND (a.module_name = ANY (ARRAY['Jardim 2'::text, '1º Ano'::text, 'Maternal 3'::text, '2º Ano'::text, 'Jardim 1'::text, 'Maternal 2'::text])))) THEN 2
            ELSE 1
        END AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    NULL::date AS "DTNUMAUTOMATICA",
    NULL::date AS "DTINICIOMATRICULA",
    NULL::date AS "DTFINMATRICULA",
    NULL::time without time zone AS "HRINICIOMATRICULA",
    NULL::time without time zone AS "HRFINMATRICULA",
    NULL::numeric AS "PONTUACAOMINIMA",
    NULL::integer AS "MAXIMOAULAS",
    NULL::text AS "PLANO PAGAMENTO",
    NULL::text AS "PLANO PAGAMENTO POR SERVIÇO",
    NULL::date AS "DTINICIOALTERACAOPROGRAMA",
    NULL::date AS "DTFIMALTERACAOPROGRAMA",
    NULL::time without time zone AS "HRINICIOALTERACAOPROGRAMA",
    NULL::time without time zone AS "HRFIMALTERACAOPROGRAMA",
    NULL::date AS "DTINICIOAUTESPECIAL",
    NULL::date AS "DTFIMAUTESPECIAL",
    NULL::time without time zone AS "HRINICIOAUTESPECIAL",
    NULL::time without time zone AS "HRFIMAUTESPECIAL",
    NULL::date AS "DTLIMITETRANCAMENTO",
    NULL::integer AS "CODCOLCXA",
    NULL::integer AS "CODCXA",
    NULL::date AS "DTCOMPETENCIAINICIAL",
    NULL::date AS "DTCOMPETENCIAFINAL",
    NULL::date AS "DTCOMPETENCIAINICIALMOV",
    NULL::date AS "DTCOMPETENCIAFINALMOV",
    NULL::boolean AS "PERMITEMATFILIALDIF",
    NULL::boolean AS "USASUGESTAODISCIPLINACURSO",
    NULL::boolean AS "SUGESTTURMADIF",
    NULL::boolean AS "SUGESTTURNODIF",
    NULL::boolean AS "SUGESTGRADEDIF",
    NULL::boolean AS "SUGESTHABILITACAODIF",
    NULL::boolean AS "SUGESTCURSODIF",
    NULL::boolean AS "SELECTURMASLIVRES",
    NULL::boolean AS "MOSTRARDISCOPTELESDD",
    NULL::boolean AS "DESCONSIDERARREQDISC",
    NULL::boolean AS "FILIALDIFPRESENCIAL",
    NULL::boolean AS "FILIALDIFPORTAL",
    NULL::boolean AS "EXIBIRTURDISCEMCURSO",
    NULL::boolean AS "EXIBIREQUIVALENTE",
    NULL::boolean AS "EQUIVTURNOS",
    NULL::boolean AS "EQUIVMATRIZES",
    NULL::boolean AS "EQUIVCURSOS",
    NULL::boolean AS "EQUIVHABILITACOES"
   FROM export.sdiscgrade sd;

-- ============================================================
-- VIEW: export.shistalunocol
-- ============================================================
CREATE OR REPLACE VIEW export.shistalunocol AS
 SELECT DISTINCT ON (scu.code_unif, er.calendar_name) 1 AS codcoligada,
    scu.code_unif::character varying(20) AS ra,
    er.calendar_name::character varying(10) AS ano,
    er.course_name::character varying(60) AS cursohist,
    er.module_name::character varying(60) AS seriehist,
    er.institution_name::character varying(60) AS instituicao,
    er.status::character varying(30) AS status,
    0 AS diasletivos,
    er.workload_real AS cargahoraria,
    NULL::text AS obs,
    NULL::numeric(10,4) AS minaprov,
    NULL::character varying(60) AS diretor,
    1 AS codtipocurso,
    NULL::integer AS codinstituicao,
    NULL::character varying(10) AS codcursohistorico,
    NULL::integer AS codseriehistorico,
    NULL::character varying(10) AS faltas,
    NULL::numeric(10,4) AS percentfreq,
    NULL::character varying(10) AS minaprovconceito
   FROM gennera_stg.enrollment_record er
     JOIN gennera_stg.person_fisica pf ON pf.id_person = er.id_person
     LEFT JOIN gennera_stg.enrollment e ON e.id_person = er.id_person
     LEFT JOIN gennera_stg.student_code_unico scu ON pf.id_person = scu.id_person
  WHERE er.institution_name <> 'EDF - Base de Testes'::text AND er.course_name <> 'Educação Infantil'::text
  ORDER BY scu.code_unif, er.calendar_name, er.id_enrollment_record;

-- ============================================================
-- VIEW: export.shistdisccol
-- ============================================================
CREATE OR REPLACE VIEW export.shistdisccol AS
 SELECT 1 AS codcoligada,
    scu.code_unif::character varying(20) AS ra,
    er.calendar_name::character varying(10) AS ano,
    er.course_name::character varying(60) AS cursohist,
    er.module_name::character varying(60) AS seriehist,
    d.discipline_code::character varying(60) AS disciplina,
    NULL::character varying(60) AS partehistorico,
    ( SELECT COALESCE(sum(a.absence), 0::bigint)::character varying(8) AS "coalesce"
           FROM gennera_stg.attendance a
          WHERE a.id_person = er.id_person AND a.subject_name = er.subject_name AND a.academic_calendar = er.calendar_name) AS faltas,
    er.subject_average::character varying(6) AS nota,
    NULL::integer AS posicao,
    er.subject_workload::character varying(8) AS cargahoraria,
    er.status::character varying(30) AS status,
    1 AS codtipocurso,
    NULL::character varying(10) AS codcursohistorico,
    NULL::integer AS codseriehistorico,
    NULL::character varying(1) AS codpartehistorico,
    d.discipline_code::character varying(60) AS coddischistorico
   FROM gennera_stg.enrollment_record er
     JOIN gennera_stg.person_fisica pf ON pf.id_person = er.id_person
     LEFT JOIN gennera_stg.student_code_unico scu ON scu.id_person = pf.id_person
     LEFT JOIN gennera_stg.disciplina d ON d.discipline_name::character varying::text = er.subject_name::character varying::text;

-- ============================================================
-- VIEW: export.shorario
-- ============================================================
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
  ORDER BY codcoligada, codfilial, codtipocurso, nometurno, diasemana, horainicial;

-- ============================================================
-- VIEW: export.shorarioprofessor
-- ============================================================
CREATE OR REPLACE VIEW export.shorarioprofessor AS
 SELECT st."CODCOLIGADA",
    st."CODCURSO",
    st."CODHABILITACAO",
    st."CODGRADE",
    st."TURNO",
    st."CODFILIAL",
    st."CODTIPOCURSO",
    st."CODPERLET",
    st."CODTURMA",
    st."CODDISC",
    pt."CODPROF",
    st."DIASEMANA",
    st."HORAINICIAL",
    st."HORAFINAL",
    'S'::character varying(1) AS "DESCONSIDERAPONTO",
    NULL::date AS "DATAINICIAL",
    NULL::date AS "DATAFINAL"
   FROM export.shorarioturma st
     JOIN export.sprofessorturma pt ON pt."CODCOLIGADA" = st."CODCOLIGADA" AND pt."CODPERLET" = st."CODPERLET" AND pt."CODTURMA" = st."CODTURMA" AND pt."CODDISC" = st."CODDISC"
  WHERE pt."CODPROF" IS NOT NULL;

-- ============================================================
-- VIEW: export.shorarioturma
-- ============================================================
CREATE OR REPLACE VIEW export.shorarioturma AS
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
  WHERE rn = 1;

-- ============================================================
-- VIEW: export.sinstituicao
-- ============================================================
CREATE OR REPLACE VIEW export.sinstituicao AS
 SELECT
        CASE
            WHEN name = 'Escola do Futuro - Unidade 1'::text THEN 1
            WHEN name = 'Escola do Futuro - Unidade 2'::text THEN 2
            ELSE 3
        END AS codinst,
    name AS nome,
    NULL::character varying(255) AS nomefantasia,
    NULL::character varying(32) AS cidade,
    NULL::character varying(2) AS uf,
    NULL::character varying(80) AS diretor,
    NULL::character varying(1) AS conveniada,
    NULL::character varying(1) AS tipoinst,
    NULL::character varying(20) AS codemec,
    NULL::integer AS codinstmantenedora
   FROM gennera_stg.institution
  WHERE name IS NOT NULL;

-- ============================================================
-- VIEW: export.smatricpl
-- ============================================================
CREATE OR REPLACE VIEW export.smatricpl AS
 SELECT DISTINCT ON (scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODTURMA", st."CODPERLET") st."CODCOLIGADA",
    st."CODCURSO",
    st."CODHABILITACAO",
    st."CODGRADE",
    st."TURNO",
    st."CODFILIAL",
    st."CODTIPOCURSO",
    st."CODTURMA",
    st."CODPERLET",
    scu.code_unif::character varying(20) AS "RA",
    NULL::character varying(30) AS "CODSTATUSRES",
        CASE
            WHEN e.status = 'cancelled'::text THEN 'Cancelado'::text
            WHEN e.status = 'reserved'::text THEN 'Reservado'::text
            WHEN e.status = 'open'::text THEN 'Aberto'::text
            WHEN e.status = 'active'::text THEN 'Ativo'::text
            WHEN e.status = 'closed'::text THEN 'Ativo'::text
            ELSE 'Ativo'::text
        END::character varying(30) AS "CODSTATUS",
    e.date::date AS "DTMATRICULA",
    NULL::date AS "DTRESULTADO",
    NULL::character varying(15) AS "IDENTIFICADOR",
    NULL::character varying(20) AS "NUMCARTEIRA",
    NULL::character varying(1) AS "CARTEIRAEMITIDA",
    NULL::character varying(20) AS "VIACARTEIRA",
    1 AS "PERIODO",
    NULL::integer AS "NUMALUNO",
    NULL::character varying(60) AS "DESCTIPOMAT",
    NULL::character varying(1) AS "SELINSTENADE",
    NULL::character varying(1) AS "SELMECENADE",
    NULL::date AS "DTPROVAENADE",
    NULL::character varying(1) AS "COMPARECEUENADE",
    NULL::text AS "OBSENADE",
    NULL::date AS "DTMATRICULAENCERRA"
   FROM gennera_stg.enrollment e
     JOIN export.sturma st ON st."CODTURMA" = e.class_name AND st."CODPERLET" = e.academic_calendar
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
  WHERE scu.code_unif IS NOT NULL
  ORDER BY scu.code_unif, st."CODCOLIGADA", st."CODCURSO", st."CODHABILITACAO", st."CODGRADE", st."TURNO", st."CODFILIAL", st."CODTIPOCURSO", st."CODTURMA", st."CODPERLET", (
        CASE e.status
            WHEN 'active'::text THEN 1
            WHEN 'open'::text THEN 2
            WHEN 'reserved'::text THEN 3
            WHEN 'cancelled'::text THEN 4
            WHEN 'closed'::text THEN 5
            ELSE 6
        END);

-- ============================================================
-- VIEW: export.smatricula
-- ============================================================
CREATE OR REPLACE VIEW export.smatricula AS
 SELECT sd."CODCOLIGADA",
    sd."CODCURSO",
    sd."CODHABILITACAO",
    sd."CODGRADE",
    sd."TURNO",
    sd."CODFILIAL",
    sd."CODTIPOCURSO",
    sd."CODTURMA",
    sd."CODPERLET",
    sd."CODDISC",
    scu.code_unif::character varying(20) AS "RA",
        CASE er.subject_status
            WHEN 'APPROVED'::text THEN 'Aprovado'::text
            WHEN 'FAILED'::text THEN 'Reprovado'::text
            ELSE NULL::text
        END::character varying(30) AS "STATUSRES",
        CASE
            WHEN er.subject_status = 'CANCELLED'::text THEN 'Cancelado'::text
            WHEN er.subject_status = 'APPROVED'::text THEN 'Aprovado'::text
            WHEN er.subject_status = 'FAILED'::text THEN 'Reprovado'::text
            WHEN er.subject_status = 'IN PROGRESS'::text AND e.academic_calendar::integer < EXTRACT(year FROM CURRENT_DATE)::integer THEN 'Aprovado'::text
            WHEN er.subject_status = 'IN PROGRESS'::text THEN 'Ativo'::text
            ELSE 'Ativo'::text
        END::character varying(30) AS "STATUS",
    NULL::integer AS "NUMDIARIO",
    to_char((e.date AT TIME ZONE 'America/Sao_Paulo'::text), 'YYYY-MM-DD HH24:MI:SS'::text)::character varying(19) AS "DTMATRICULA",
    NULL::character varying(255) AS "OBSHISTORICO",
    NULL::character varying(60) AS "TIPOMAT",
    'N'::character varying(1) AS "TIPODISCIPLINA",
    NULL::character varying(10) AS "DTALTERACAO",
    NULL::character varying(10) AS "DTALTERACAOSIST",
    NULL::character varying(20) AS "CODSUBTURMA",
    NULL::numeric AS "NUMCREDITOSCOB",
    'N'::character varying(1) AS "COBPOSTERIORMATRIC",
    NULL::character varying(20) AS "CODTURMAORIGEM",
    NULL::character varying(20) AS "CODDISCORIGEM",
    NULL::character varying(20) AS "CODTURMAPRINCIPAL",
    NULL::character varying(20) AS "CODDISCPRINCIPAL"
   FROM gennera_stg.enrollment_record er
     JOIN gennera_stg.enrollment e ON e.id_enrollment = er.id_enrollment
     JOIN export.sturmadisc sd ON sd."CODTURMA"::text = e.class_name AND sd."CODPERLET"::text = e.academic_calendar AND sd."CODDISC"::text = er.disc_code
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = e.id_person
  WHERE (er.institution_name = ANY (ARRAY['Escola do Futuro'::text, 'Escola do Futuro - Unidade 1'::text, 'Escola do Futuro - Unidade 2'::text])) AND scu.code_unif IS NOT NULL AND er.disc_code IS NOT NULL;

-- ============================================================
-- VIEW: export.snotaetapa
-- ============================================================
CREATE OR REPLACE VIEW export.snotaetapa AS
 WITH etapa_map(period, codetapa) AS (
         VALUES ('Período I'::text,1), ('Período II'::text,2), ('Período III'::text,3), ('Recuperação Anual'::text,4)
        ), grade_dedup AS (
         SELECT DISTINCT ON (grade.id_person, grade.subject_name, grade.academic_calendar, grade.class_name, grade.period_name) grade.id_person,
            grade.subject_name,
            grade.academic_calendar,
            grade.class_name,
            grade.period_name,
            grade.module_name,
            grade.course_name,
            grade.grade
           FROM gennera_stg.grade
          WHERE (grade.class_name <> ALL (ARRAY['Módulo 1'::text, 'Módulo 2'::text, 'TEMP'::text])) AND grade.course_name !~~* '%infantil%'::text AND grade.subject_name <> 'Desenvolvimento Infantil'::text AND grade.academic_calendar IS NOT NULL AND TRIM(BOTH FROM grade.academic_calendar) <> ''::text AND (grade.period_name = ANY (ARRAY['Período I'::text, 'Período II'::text, 'Período III'::text, 'Recuperação Anual'::text])) AND grade.exam_name = 'Avaliação parcial'::text
          ORDER BY grade.id_person, grade.subject_name, grade.academic_calendar, grade.class_name, grade.period_name, grade.grade DESC NULLS LAST
        )
 SELECT 1 AS "CODCOLIGADA",
    s."CODCURSO",
    s."CODHABILITACAO",
    s."CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    scu.code_unif::character varying(20) AS "RA",
    g.class_name::character varying(20) AS "CODTURMA",
    g.academic_calendar::character varying(10) AS "CODPERLET",
    d.discipline_code::character varying(20) AS "CODDISC",
    em.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
        CASE
            WHEN NULLIF(TRIM(BOTH FROM g.grade), ''::text) ~ '^[0-9]+([.,][0-9]+)?$'::text THEN NULL::character varying(10)
            ELSE "left"(TRIM(BOTH FROM g.grade), 10)::character varying(10)
        END AS "CONCEITO",
        CASE
            WHEN NULLIF(TRIM(BOTH FROM g.grade), ''::text) ~ '^[0-9]+([.,][0-9]+)?$'::text THEN replace(TRIM(BOTH FROM g.grade), ','::text, '.'::text)::numeric(10,4)
            ELSE NULL::numeric
        END AS "NOTAFALTA",
    NULL::integer AS "AULASDADAS"
   FROM grade_dedup g
     JOIN etapa_map em ON em.period = g.period_name
     JOIN gennera_stg.disciplina d ON TRIM(BOTH FROM d.discipline_name) = TRIM(BOTH FROM g.subject_name)
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = g.id_person
     JOIN export.sturmadisc sd ON sd."CODTURMA"::text = g.class_name AND sd."CODPERLET"::text = g.academic_calendar AND sd."CODDISC"::text = d.discipline_code::text
     JOIN export.sturma s ON s."CODTURMA" = g.class_name AND s."CODGRADE"::text = g.academic_calendar
  WHERE d.discipline_code IS NOT NULL;

-- ============================================================
-- VIEW: export.snotas
-- ============================================================
CREATE OR REPLACE VIEW export.snotas AS
 WITH etapa_map(period, codetapa) AS (
         VALUES ('Período I'::text,1), ('Período II'::text,2), ('Período III'::text,3), ('Recuperação Anual'::text,4)
        ), grade_dedup AS (
         SELECT DISTINCT ON (g_1.id_person, g_1.subject_name, g_1.academic_calendar, g_1.class_name, g_1.period_name, g_1.exam_name) g_1.id_person,
            g_1.subject_name,
            g_1.academic_calendar,
            g_1.class_name,
            g_1.period_name,
            g_1.exam_name,
            g_1.grade,
            g_1.course_name,
            g_1.module_name
           FROM gennera_stg.grade g_1
          WHERE (g_1.class_name <> ALL (ARRAY['Módulo 1'::text, 'Módulo 2'::text, 'TEMP'::text])) AND g_1.course_name !~~* '%infantil%'::text AND g_1.subject_name <> 'Desenvolvimento Infantil'::text AND g_1.academic_calendar IS NOT NULL AND TRIM(BOTH FROM g_1.academic_calendar) <> ''::text AND (g_1.period_name = ANY (ARRAY['Período I'::text, 'Período II'::text, 'Período III'::text, 'Recuperação Anual'::text]))
          ORDER BY g_1.id_person, g_1.subject_name, g_1.academic_calendar, g_1.class_name, g_1.period_name, g_1.exam_name, g_1.grade DESC NULLS LAST
        ), provas_map AS (
         SELECT DISTINCT g_1.academic_calendar,
            g_1.class_name,
            d_1.discipline_code,
            em_1.codetapa,
            g_1.exam_name,
            row_number() OVER (PARTITION BY g_1.class_name, d_1.discipline_code, em_1.codetapa, g_1.academic_calendar ORDER BY g_1.exam_name) AS codprova
           FROM grade_dedup g_1
             JOIN etapa_map em_1 ON em_1.period = g_1.period_name
             JOIN gennera_stg.disciplina d_1 ON TRIM(BOTH FROM d_1.discipline_name) = TRIM(BOTH FROM g_1.subject_name)
          WHERE d_1.discipline_code IS NOT NULL
        )
 SELECT 1 AS "CODCOLIGADA",
    s."CODCURSO",
    s."CODHABILITACAO",
    s."CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    scu.code_unif::character varying(20) AS "RA",
    g.class_name::character varying(20) AS "CODTURMA",
    g.academic_calendar::character varying(10) AS "CODPERLET",
    d.discipline_code::character varying(20) AS "CODDISC",
    em.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
    pm.codprova::integer AS "CODPROVA",
        CASE
            WHEN NULLIF(TRIM(BOTH FROM g.grade), ''::text) ~ '^[0-9]+([.,][0-9]+)?$'::text THEN NULL::character varying(10)
            ELSE "left"(TRIM(BOTH FROM g.grade), 10)::character varying(10)
        END AS "CONCEITO",
        CASE
            WHEN NULLIF(TRIM(BOTH FROM g.grade), ''::text) ~ '^[0-9]+([.,][0-9]+)?$'::text THEN replace(TRIM(BOTH FROM g.grade), ','::text, '.'::text)::numeric(10,4)
            ELSE NULL::numeric
        END AS "NOTA",
    NULL::integer AS "NUMACERTOS"
   FROM grade_dedup g
     JOIN etapa_map em ON em.period = g.period_name
     JOIN gennera_stg.disciplina d ON TRIM(BOTH FROM d.discipline_name) = TRIM(BOTH FROM g.subject_name)
     JOIN gennera_stg.student_code_unico scu ON scu.id_person = g.id_person
     JOIN export.sturma s ON s."CODTURMA" = g.class_name AND s."CODGRADE"::text = g.academic_calendar
     JOIN provas_map pm ON pm.academic_calendar = g.academic_calendar AND pm.class_name = g.class_name AND pm.discipline_code::text = d.discipline_code::text AND pm.codetapa = em.codetapa AND pm.exam_name = g.exam_name
  WHERE d.discipline_code IS NOT NULL;

-- ============================================================
-- VIEW: export.speriodo
-- ============================================================
CREATE OR REPLACE VIEW export.speriodo AS
 SELECT 1 AS codcoligada,
    codcurso,
    codhabilitacao,
    codgrade,
    1 AS codperiodo,
    'Único'::character varying(50) AS descricao,
    NULL::numeric(10,4) AS valoreletiva,
    NULL::numeric(10,4) AS valoroptativa
   FROM export.sgrade sg;

-- ============================================================
-- VIEW: export.splanoaula
-- ============================================================
CREATE OR REPLACE VIEW export.splanoaula AS
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
         SELECT d_1.discipline_code::text AS coddisc,
            regexp_replace(translate(lower(TRIM(BOTH FROM d_1.discipline_name::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS disc_norm,
            regexp_replace(translate(lower(TRIM(BOTH FROM regexp_replace(d_1.discipline_name::text, '\s*\(.*\)\s*$'::text, ''::text, 'g'::text))), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS disc_clean_norm
           FROM gennera_stg.disciplina d_1
          WHERE d_1.discipline_code IS NOT NULL AND d_1.discipline_name IS NOT NULL AND TRIM(BOTH FROM d_1.discipline_name::text) <> ''::text
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
        ), schedule AS (
         SELECT DISTINCT matchs.codcoligada AS "CODCOLIGADA",
                CASE
                    WHEN matchs.codfilial = 1 THEN 'Integral'::text
                    WHEN matchs.codfilial = 2 THEN
                    CASE substr(matchs.codturma, length(matchs.codturma) - 1, 1)
                        WHEN 'M'::text THEN 'Matutino'::text
                        WHEN 'T'::text THEN 'Vespertino'::text
                        WHEN 'I'::text THEN 'Integral'::text
                        ELSE COALESCE(matchs.turno, 'Integral'::text)
                    END
                    ELSE COALESCE(matchs.turno, 'Integral'::text)
                END AS turno,
            matchs.codfilial AS "CODFILIAL",
            matchs.codtipocurso AS "CODTIPOCURSO",
            matchs.codperlet AS "CODPERLET",
            matchs.codturma AS "CODTURMA",
            matchs.coddisc,
            NULL::character varying(5) AS codpredio,
            NULL::character varying(10) AS codsala,
            NULL::text AS locacao,
            NULL::character varying(5) AS codbloco,
            matchs.diasemana,
            to_char(matchs.horainicial::interval, 'HH24:MI'::text) AS horainicial,
            to_char(matchs.horafinal::interval, 'HH24:MI'::text) AS horafinal,
                CASE
                    WHEN matchs.codperlet ~ '^\d{4}$'::text THEN to_date('01/01/'::text || matchs.codperlet, 'DD/MM/YYYY'::text)
                    ELSE NULL::date
                END AS datainicial,
                CASE
                    WHEN matchs.codperlet ~ '^\d{4}$'::text THEN to_date('31/12/'::text || matchs.codperlet, 'DD/MM/YYYY'::text)
                    ELSE NULL::date
                END AS datafinal
           FROM matchs
          WHERE matchs.rn = 1
        )
 SELECT s."CODCOLIGADA",
    s."CODFILIAL",
    s."CODTIPOCURSO",
    s."CODTURMA",
    s.horainicial AS "HORAINICIAL",
    s.horafinal AS "HORAFINAL",
    s.turno::character varying(15) AS "NOMETURNO",
    s."CODPERLET",
    s.coddisc AS "CODDISC",
    row_number() OVER (PARTITION BY s."CODCOLIGADA", s."CODTURMA", s."CODPERLET", s.coddisc ORDER BY d.data, s.horainicial)::integer AS "AULA",
    s.diasemana AS "DIASEMANA",
    NULL::integer AS "IDHORARIOTURMA",
    s.codpredio AS "CODPREDIO",
    s.codsala AS "CODSALA",
    pt."CODPROF",
    to_char(d.data::timestamp with time zone, 'YYYY-MM-DD'::text)::character varying(10) AS "DATA",
    NULL::text AS "CONTEUDO",
    s.locacao::character varying(50) AS "LOCACAO",
    NULL::character varying(2000) AS "CONTEUDOEFETIVO",
    NULL::character varying(10) AS "DATAEFETIVA",
    NULL::character varying(1) AS "REPOSICAO",
    NULL::character varying(1) AS "SUBSTITUTO",
    NULL::character varying(1) AS "PAGAMENTOPROF",
    NULL::character varying(1) AS "TIPOFALTA",
    s.codbloco AS "CODBLOCO",
    '1'::character varying(1) AS "FREQUENCIADISPWEB",
    NULL::text AS "LICAOCASA",
    NULL::text AS "OBSERVACAO",
    NULL::character varying(1) AS "CONFIRMADO",
    NULL::character varying(1) AS "TIPOAULA"
   FROM schedule s
     CROSS JOIN LATERAL ( SELECT generate_series(COALESCE(s.datainicial, (s."CODPERLET" || '-01-01'::text)::date)::timestamp with time zone, COALESCE(s.datafinal, (s."CODPERLET" || '-12-31'::text)::date)::timestamp with time zone, '1 day'::interval)::date AS data) d
     LEFT JOIN LATERAL ( SELECT sp."CODPROF"
           FROM export.sprofessorturma sp
          WHERE sp."CODCOLIGADA" = s."CODCOLIGADA" AND sp."CODTURMA" = s."CODTURMA" AND sp."CODPERLET" = s."CODPERLET" AND sp."CODDISC" = s.coddisc
         LIMIT 1) pt ON true
  WHERE (EXTRACT(dow FROM d.data) + 1::numeric)::integer = s.diasemana;

-- ============================================================
-- VIEW: export.splanopgto
-- ============================================================
CREATE OR REPLACE VIEW export.splanopgto AS
 SELECT 1 AS "CODCOLIGADA",
    p."CODPERLET",
    t.codplanopgto AS "CODPLANOPGTO",
    t.descricao AS "DESCRICAO",
    t.nome AS "NOME",
    p."DTINICIO",
    p."DTPREVISTA" AS "DTFIM",
    0::numeric(10,4) AS "DESCONTO",
    1 AS "CODTIPOCURSO",
    1 AS "CODFILIAL",
    'N'::character varying(1) AS "MATRICULALIVRE",
    NULL::character varying(1) AS "TIPOBLOQUEIOVLRBASEPERSONALIZ"
   FROM ( SELECT DISTINCT spletivo."CODPERLET",
            spletivo."DTINICIO",
            spletivo."DTPREVISTA"
           FROM export.spletivo
          WHERE spletivo."CODPERLET" ~ '^\d{4}$'::text) p
     CROSS JOIN ( VALUES ('ANUAL'::text,'Plano Anual'::text,'Anual'::text), ('MENSAL'::text,'Plano Mensal (12x)'::text,'Mensal'::text), ('SEMESTRAL'::text,'Plano Semestral (2x)'::text,'Semestral'::text)) t(codplanopgto, descricao, nome)
  ORDER BY p."CODPERLET", t.codplanopgto;

-- ============================================================
-- VIEW: export.spletivo
-- ============================================================
CREATE OR REPLACE VIEW export.spletivo AS
 SELECT DISTINCT 1 AS "CODCOLIGADA",
        CASE
            WHEN i.code = 'un1'::text THEN 1
            WHEN i.code = 'un2'::text THEN 2
            ELSE NULL::integer
        END AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    att.period_code AS "CODPERLET",
    att.period_name AS "DESCRICAO",
    NULL::integer AS "DIASLETIVOS",
    NULL::integer AS "CARGAHORARIA",
    NULL::text AS "OBS",
    'N'::text AS "ENCERRADO",
    NULL::date AS "DTINICIO",
    NULL::date AS "DTPREVISTA",
    NULL::date AS "DTFIM",
    NULL::text AS "CALENDARIO",
    NULL::text AS "CODPERLETANT",
    NULL::text AS "ENCERRADOPGTO",
    NULL::date AS "DTCOMPETENCIAINICIAL",
    NULL::date AS "DTCOMPETENCIAFINAL",
    NULL::date AS "DTCOMPETENCIAINICIALMOV",
    NULL::date AS "DTCOMPETENCIAFINALMOV",
    NULL::text AS "ENCERRADOCONTABIL",
    'N'::text AS "EXIBIRPORTAL",
    NULL::text AS "ENCERRADOFINANCEIRO",
    'N'::text AS "EXIBIRPORTALALUNO"
   FROM gennera_stg.attendance att
     LEFT JOIN gennera_stg.academic a ON a.subject_name = att.subject_name AND a.module_name = att.module_name AND a.course_name = att.course_name
     JOIN gennera_stg.institution i ON a.id_institution = i.id_institution
  WHERE att.period_code IS NOT NULL AND (i.code = ANY (ARRAY['un1'::text, 'un2'::text]))
UNION
 SELECT DISTINCT 1 AS "CODCOLIGADA",
    2 AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    p.reference_year AS "CODPERLET",
    p.reference_year AS "DESCRICAO",
    NULL::integer AS "DIASLETIVOS",
    NULL::integer AS "CARGAHORARIA",
    NULL::text AS "OBS",
    'N'::text AS "ENCERRADO",
    to_date(split_part(p.academic_calendar_start_date, 'T'::text, 1), 'YYYY-MM-DD'::text) AS "DTINICIO",
    to_date(split_part(p.academic_calendar_end_date, 'T'::text, 1), 'YYYY-MM-DD'::text) AS "DTPREVISTA",
    NULL::date AS "DTFIM",
    NULL::text AS "CALENDARIO",
    NULL::text AS "CODPERLETANT",
    NULL::text AS "ENCERRADOPGTO",
    NULL::date AS "DTCOMPETENCIAINICIAL",
    NULL::date AS "DTCOMPETENCIAFINAL",
    NULL::date AS "DTCOMPETENCIAINICIALMOV",
    NULL::date AS "DTCOMPETENCIAFINALMOV",
    NULL::text AS "ENCERRADOCONTABIL",
    'S'::text AS "EXIBIRPORTAL",
    NULL::text AS "ENCERRADOFINANCEIRO",
    'S'::text AS "EXIBIRPORTALALUNO"
   FROM gennera_stg.period p
  WHERE p.reference_year IS NOT NULL
  ORDER BY 2, 4;

-- ============================================================
-- VIEW: export.sprofessor
-- ============================================================
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
         SELECT regexp_replace(lower(TRIM(BOTH FROM base_unificado.name)), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            base_unificado.id_person,
            base_unificado.name,
            base_unificado.birthdate,
            base_unificado.birthplace,
            base_unificado.birth_state,
            base_unificado.cpf_by_id
           FROM base_unificado
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
            TRIM(BOTH FROM x.name)::character varying(120) AS "NOME",
            COALESCE(
                CASE
                    WHEN x.birthdate IS NOT NULL THEN to_char(x.birthdate::date::timestamp with time zone, 'DD/MM/YYYY'::text)
                    ELSE NULL::text
                END, '01/01/0001'::text)::character varying(10) AS "DTNASCIMENTO",
                CASE
                    WHEN x.cpf_final_digits IS NOT NULL THEN lpad(x.cpf_final_digits, 11, '0'::text)
                    WHEN x.id_person IS NOT NULL THEN '00000'::text || lpad(x.id_person::text, 6, '0'::text)
                    ELSE NULL::text
                END::character varying(11) AS "CPF",
            NULL::character varying(15) AS "CARTIDENTIDADE",
            NULL::character varying(2) AS "UFCARTIDENT",
            NULL::character varying(10) AS "CARTEIRATRAB",
            NULL::character varying(5) AS "SERIECARTTRAB",
            NULL::character varying(2) AS "UFCARTTRAB",
            1 AS "CODCOLIGADA",
            x.id_person::character varying(10) AS "CODPROF",
            NULL::character varying(16) AS "CHAPA",
            NULL::numeric(10,4) AS "VALORAULA",
            NULL::character varying(15) AS "TITULACAO",
            TRIM(BOTH FROM x.birthplace)::character varying(32) AS "NATURALIDADE",
            upper(TRIM(BOTH FROM x.birth_state))::character varying(2) AS "ESTADONATAL"
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
         SELECT p.codigo,
            p.nome,
            p.dtnascimento,
            p.naturalidade,
            p.estadonatal,
            p.professor,
            regexp_replace(lower(TRIM(BOTH FROM p.nome::text)), '\s+'::text, ' '::text, 'g'::text) AS nome_norm,
            NULLIF(regexp_replace(p.cpf::text, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_digits
           FROM export.ppessoa p
        ), cpf_por_nome AS (
         SELECT pessoa_norm.nome_norm,
            max(pessoa_norm.cpf_digits) AS cpf_preferido
           FROM pessoa_norm
          WHERE pessoa_norm.cpf_digits IS NOT NULL
          GROUP BY pessoa_norm.nome_norm
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
         SELECT pl.nome_norm,
            pl.nome,
            pl.dtnascimento,
            pl.cpf_final,
            pl.naturalidade,
            pl.estadonatal,
            pl.codigo
           FROM professores_legados_brutos pl
             LEFT JOIN sprof_unificado_dedup su ON su.nome_norm = pl.nome_norm
          WHERE su.nome_norm IS NULL
        ), sprof_legado_dedup AS (
         SELECT x.nome_norm,
            TRIM(BOTH FROM x.nome::text)::character varying(120) AS "NOME",
            COALESCE(
                CASE
                    WHEN x.dtnascimento IS NOT NULL THEN to_char(x.dtnascimento::timestamp with time zone, 'DD/MM/YYYY'::text)
                    ELSE NULL::text
                END, '01/01/0001'::text)::character varying(10) AS "DTNASCIMENTO",
                CASE
                    WHEN x.cpf_final IS NOT NULL THEN lpad(x.cpf_final, 11, '0'::text)
                    WHEN x.codigo IS NOT NULL THEN '00000'::text || lpad(x.codigo::text, 6, '0'::text)
                    ELSE NULL::text
                END::character varying(11) AS "CPF",
            NULL::character varying(15) AS "CARTIDENTIDADE",
            NULL::character varying(2) AS "UFCARTIDENT",
            NULL::character varying(10) AS "CARTEIRATRAB",
            NULL::character varying(5) AS "SERIECARTTRAB",
            NULL::character varying(2) AS "UFCARTTRAB",
            1 AS "CODCOLIGADA",
            x.codigo::character varying(10) AS "CODPROF",
            NULL::character varying(16) AS "CHAPA",
            NULL::numeric(10,4) AS "VALORAULA",
            NULL::character varying(15) AS "TITULACAO",
            TRIM(BOTH FROM x.naturalidade::text)::character varying(32) AS "NATURALIDADE",
            upper(TRIM(BOTH FROM x.estadonatal::text))::character varying(2) AS "ESTADONATAL"
           FROM ( SELECT pl.nome_norm,
                    pl.nome,
                    pl.dtnascimento,
                    pl.cpf_final,
                    pl.naturalidade,
                    pl.estadonatal,
                    pl.codigo,
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
   FROM sprof_legado_dedup;

-- ============================================================
-- VIEW: export.sprofessorturma
-- ============================================================
CREATE OR REPLACE VIEW export.sprofessorturma AS
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
         SELECT prm."Codigo"::text AS codprof_rm,
            NULLIF(regexp_replace(prm."CPF"::text, '\D'::text, ''::text, 'g'::text), ''::text) AS cpf_rm,
            regexp_replace(translate(lower(TRIM(BOTH FROM prm."Nome"::text)), 'áàãâäéèêëíìîïóòõôöúùûüç'::text, 'aaaaaeeeeiiiiooooouuuuc'::text), '\s+'::text, ' '::text, 'g'::text) AS prof_norm_rm,
            lower(TRIM(BOTH FROM prm."E-Mail"::text)) AS email_rm
           FROM gennera_stg.tabela_professor_rm prm
          WHERE prm."Codigo" IS NOT NULL
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
     JOIN disc_validas dv ON dv.codcoligada = tc.codcoligada AND dv.codcurso = tc.codcurso AND dv.codhabilitacao = tc.codhabilitacao AND dv.codgrade = tc.codgrade AND dv.coddisc = dm.coddisc;

-- ============================================================
-- VIEW: export.sprovas
-- ============================================================
CREATE OR REPLACE VIEW export.sprovas AS
 WITH etapa_map(period, codetapa) AS (
         VALUES ('Período I'::text,1), ('Período II'::text,2), ('Período III'::text,3), ('Recuperação Anual'::text,4)
        ), exams_com_ano AS (
         SELECT DISTINCT g.academic_calendar,
            g.class_name,
            g.subject_name,
            g.course_name,
            g.module_name,
            g.period_name,
            g.exam_name,
            e.max_grade,
                CASE
                    WHEN g.course_name ~~* '%fundamental ii%'::text OR g.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                    WHEN g.course_name ~~* '%fundamental i%'::text OR g.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                    WHEN g.course_name ~~* '%médio%'::text OR g.course_name ~~* '%medio%'::text THEN 'EM'::text
                    ELSE NULL::text
                END AS codcurso
           FROM gennera_stg.grade g
             JOIN gennera_stg.exam e ON e.class = g.class_name AND e.subject = g.subject_name AND e.period = g.period_name AND e.name = g.exam_name
          WHERE (g.class_name <> ALL (ARRAY['Módulo 1'::text, 'Módulo 2'::text, 'TEMP'::text])) AND g.course_name !~~* '%infantil%'::text AND g.subject_name <> 'Desenvolvimento Infantil'::text AND g.academic_calendar IS NOT NULL AND TRIM(BOTH FROM g.academic_calendar) <> ''::text AND (g.period_name = ANY (ARRAY['Período I'::text, 'Período II'::text, 'Período III'::text, 'Recuperação Anual'::text]))
        )
 SELECT 1 AS "CODCOLIGADA",
    ex.codcurso::character varying(10) AS "CODCURSO",
    a.code_module::character varying(10) AS "CODHABILITACAO",
    ex.academic_calendar::character varying(10) AS "CODGRADE",
    s."TURNO",
    s."CODFILIAL",
    1 AS "CODTIPOCURSO",
    ex.academic_calendar::character varying(10) AS "CODPERLET",
    ex.class_name::character varying(20) AS "CODTURMA",
    d.discipline_code::character varying(20) AS "CODDISC",
    em.codetapa AS "CODETAPA",
    'N'::character varying(1) AS "TIPOETAPA",
    row_number() OVER (PARTITION BY ex.class_name, d.discipline_code, em.codetapa, ex.academic_calendar ORDER BY ex.exam_name)::integer AS "CODPROVA",
    ex.exam_name::character varying(100) AS "DESCRICAO",
    ex.max_grade::numeric(10,4) AS "VALOR",
    NULL::numeric(10,4) AS "MEDIA",
    NULL::date AS "DTPREVISTA",
    NULL::date AS "DTPROVA",
    NULL::integer AS "NUMQUESTOES",
    NULL::date AS "DTDEVOLUCAOAVALIACAO",
    NULL::date AS "DTLIMITEENTREGAAVAL",
    NULL::character varying(1) AS "PERMITEENTREGAWEB",
    NULL::character varying(1) AS "DISPONIVELALUNOS",
    NULL::character varying(65) AS "CODPROVATESTIS"
   FROM exams_com_ano ex
     JOIN etapa_map em ON em.period = ex.period_name
     JOIN gennera_stg.disciplina d ON TRIM(BOTH FROM d.discipline_name) = TRIM(BOTH FROM ex.subject_name)
     LEFT JOIN ( SELECT DISTINCT academic.module_name,
            academic.course_code,
            academic.code_module
           FROM gennera_stg.academic) a ON a.module_name = ex.module_name AND a.course_code = ex.codcurso
     LEFT JOIN export.sturma s ON s."CODTURMA" = ex.class_name AND s."CODGRADE"::text = ex.academic_calendar
  WHERE d.discipline_code IS NOT NULL AND ex.codcurso IS NOT NULL;

-- ============================================================
-- VIEW: export.sservico
-- ============================================================
CREATE OR REPLACE VIEW export.sservico AS
 WITH por_aluno AS (
         SELECT TRIM(BOTH FROM sh.item) AS item,
            sh.id_pessoa,
            sh.fatura_ano,
            sum(replace(replace(replace(TRIM(BOTH FROM sh.valor_bruto), '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text)::numeric(10,4)) AS valor_aluno
           FROM gennera_stg.servicos_historico sh
          WHERE (sh.item::text ~~* '%mensali%'::text OR sh.item::text ~~* '%alimenta%'::text OR sh.item::text ~~* '%material%'::text OR sh.item::text ~~* '%anuidade%'::text) AND sh.valor_bruto IS NOT NULL AND (TRIM(BOTH FROM sh.valor_bruto) <> ALL (ARRAY['$0,00'::text, ''::text, '0'::text, '0,00'::text])) AND sh.calendario_academico IS NOT NULL AND TRIM(BOTH FROM sh.calendario_academico) >= '2021'::text
          GROUP BY (TRIM(BOTH FROM sh.item)), sh.id_pessoa, sh.fatura_ano
        )
 SELECT 1 AS "CODCOLIGADA",
    "left"(item, 60)::character varying(60) AS "NOME",
    mode() WITHIN GROUP (ORDER BY valor_aluno)::numeric(10,4) AS "VALOR",
    1 AS "CODTIPOCURSO",
    NULL::integer AS "CODCOLCXA",
    NULL::character varying(10) AS "CODCXA",
    'N'::character varying(1) AS "VERIFICAINADIMPLENCIA",
    NULL::integer AS "TIPOCONTABILLAN",
    NULL::character varying(10) AS "CODTDO",
    NULL::integer AS "CODCOLNATFINANCEIRA",
    NULL::character varying(40) AS "NATFINANCEIRA",
    'N'::character varying(1) AS "PERMITEACORDO",
    NULL::character varying(1) AS "APROVEITACONTACORRENTE",
    NULL::character varying(1) AS "CONSIDERAPARCELAFIXA",
    NULL::character varying(1) AS "DISPONIVELEXTENSAO",
    NULL::character varying(1) AS "DESCONSIDERACREDITORETROATIVO",
    'N'::character varying(1) AS "PGCARTAODEBITO",
    'N'::character varying(1) AS "PGCARTAOCREDITO",
    NULL::character varying(1) AS "CONSIDERADESCANTECIPACAO"
   FROM por_aluno pa
  GROUP BY item
  ORDER BY item;

-- ============================================================
-- VIEW: export.sturma
-- ============================================================
CREATE OR REPLACE VIEW export.sturma AS
 WITH turma_base AS (
         SELECT NULLIF(TRIM(BOTH FROM e.academic_calendar), ''::text)::integer AS codgrade,
            TRIM(BOTH FROM e.class_name) AS turma_nome,
            a.code_module::text AS codhabilitacao_txt,
                CASE
                    WHEN e.course_name ~~* '%infantil%'::text THEN 'EI'::text
                    WHEN e.course_name ~~* '%fundamental ii%'::text OR e.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                    WHEN e.course_name ~~* '%fundamental i%'::text OR e.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                    WHEN e.course_name ~~* '%médio%'::text OR e.course_name ~~* '%medio%'::text THEN 'EM'::text
                    ELSE NULL::text
                END AS codcurso_rm,
                CASE
                    WHEN (
                    CASE
                        WHEN e.course_name ~~* '%infantil%'::text THEN 'EI'::text
                        WHEN e.course_name ~~* '%fundamental ii%'::text OR e.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                        WHEN e.course_name ~~* '%fundamental i%'::text OR e.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                        WHEN e.course_name ~~* '%médio%'::text OR e.course_name ~~* '%medio%'::text THEN 'EM'::text
                        ELSE NULL::text
                    END = 'EF1'::text AND (a.code_module::text = ANY (ARRAY['1'::text, '2'::text])) OR
                    CASE
                        WHEN e.course_name ~~* '%infantil%'::text THEN 'EI'::text
                        WHEN e.course_name ~~* '%fundamental ii%'::text OR e.course_name ~~* '%fundamental 2%'::text THEN 'EF2'::text
                        WHEN e.course_name ~~* '%fundamental i%'::text OR e.course_name ~~* '%fundamental 1%'::text THEN 'EF1'::text
                        WHEN e.course_name ~~* '%médio%'::text OR e.course_name ~~* '%medio%'::text THEN 'EM'::text
                        ELSE NULL::text
                    END = 'EI'::text) AND (a.module_name = ANY (ARRAY['Jardim 2'::text, '1º Ano'::text, 'Maternal 3'::text, '2º Ano'::text, 'Jardim 1'::text, 'Maternal 2'::text])) THEN 2
                    ELSE 1
                END AS codfilial_calc
           FROM gennera_stg.enrollment e
             LEFT JOIN gennera_stg.academic a ON a.module_name = e.module_name
          WHERE e.academic_calendar IS NOT NULL AND NULLIF(TRIM(BOTH FROM e.academic_calendar), ''::text) ~ '^\d{4}$'::text AND e.class_name IS NOT NULL AND TRIM(BOTH FROM e.class_name) <> ''::text AND e.course_name IS NOT NULL
        ), turma_unificada AS (
         SELECT DISTINCT turma_base.codgrade,
            turma_base.codcurso_rm,
            turma_base.codhabilitacao_txt,
            turma_base.codfilial_calc,
            turma_base.turma_nome
           FROM turma_base
          WHERE turma_base.codcurso_rm IS NOT NULL AND turma_base.codhabilitacao_txt IS NOT NULL
        )
 SELECT DISTINCT h."CODCOLIGADA",
    h."CODCURSO",
    h."CODHABILITACAO",
    h."CODGRADE",
    h."TURNO",
    h."CODFILIAL",
    h."CODTIPOCURSO",
    h."CODPERLET",
    t.turma_nome AS "CODTURMA",
    NULL::text AS "CODDEPARTAMENTO",
    NULL::text AS "CODPREDIO",
    NULL::text AS "CODSALA",
    NULL::text AS "CODCCUSTO",
    "left"(t.turma_nome, 30) AS "NOMERED",
    t.turma_nome AS "NOME",
    9999 AS "MAXALUNOS",
    NULL::date AS "DTINICIAL",
    NULL::date AS "DTFINAL",
    NULL::integer AS "ALUNOSLABORE",
    NULL::date AS "DTALUNOSLABORE",
    NULL::text AS "CODTURMAPROX",
    NULL::text AS "CODCAMPUS",
    NULL::text AS "CODBLOCO",
    NULL::text AS "TIPOMEDIACAO"
   FROM export.shabilitacaofilialpl h
     JOIN turma_unificada t ON t.codgrade = h."CODGRADE" AND t.codcurso_rm = h."CODCURSO" AND t.codhabilitacao_txt = h."CODHABILITACAO"::text AND t.codfilial_calc = h."CODFILIAL"
  WHERE t.turma_nome <> 'TEMP'::text;

-- ============================================================
-- VIEW: export.sturmadisc
-- ============================================================
CREATE OR REPLACE VIEW export.sturmadisc AS
 SELECT DISTINCT 1 AS "CODCOLIGADA",
    sd."CODCURSO"::character varying(10) AS "CODCURSO",
    sd."CODHABILITACAO"::character varying(10) AS "CODHABILITACAO",
    sd."CODGRADE"::character varying(10) AS "CODGRADE",
    'Integral'::character varying(15) AS "TURNO",
        CASE
            WHEN a.id_institution = 1 THEN 1
            WHEN a.id_institution = 2 THEN 2
            ELSE 1
        END AS "CODFILIAL",
    1 AS "CODTIPOCURSO",
    sd."CODGRADE"::character varying(10) AS "CODPERLET",
    disc.discipline_code::character varying(20) AS "CODDISC",
    t."CODTURMA"::character varying(20) AS "CODTURMA",
    NULL::character varying(5) AS "CODPREDIO",
    NULL::character varying(10) AS "CODSALA",
    NULL::character varying(25) AS "CODCCUSTO",
    '101'::text AS "MAXALUNOS",
    NULL::integer AS "MINALUNOS",
    NULL::date AS "DTINICIAL",
    NULL::date AS "DTFINAL",
    NULL::integer AS "NUMAULASEM",
    NULL::integer AS "DURACAOAULA",
    NULL::numeric(10,4) AS "CUSTOMEDIO",
    NULL::character varying(60) AS "NOME",
    NULL::character varying(1) AS "TIPO",
    NULL::character varying(10) AS "CODCAMPUS",
    NULL::character varying(5) AS "CODBLOCO",
    NULL::character varying(1) AS "ADICIONALNOTURNO",
    NULL::character varying(1) AS "ADICIONALEXTRA",
    NULL::integer AS "VAGASCALOUROS",
    NULL::integer AS "NUMMAXALUNOOUTROSCURSOS",
    NULL::character varying(1) AS "DISPONIVELMATRICULA",
    NULL::numeric(10,4) AS "NUMCREDITOSCOB",
    NULL::integer AS "VAGASLISTAESPERA",
    NULL::numeric(10,4) AS "VALORCREDITO",
    NULL::date AS "DTINICIOMATPRES",
    NULL::date AS "DTFIMMATPRES",
    NULL::date AS "DTINICIOMATPORTAL",
    NULL::date AS "DTFIMMATPORTAL",
    NULL::character varying(1) AS "ATIVA",
    NULL::character varying(1) AS "GERENCIAL",
    NULL::character varying(15) AS "TURNOTURMADISC",
    NULL::integer AS "CODITINERARIOFORMATIVO"
   FROM export.sdiscgrade sd
     LEFT JOIN gennera_stg.academic a ON a.course_code = sd."CODCURSO" AND a.code_module::text = sd."CODHABILITACAO"
     LEFT JOIN gennera_stg.disciplina disc ON disc.discipline_code::text = sd."CODDISC"
     LEFT JOIN export.sturma t ON t."CODCURSO" = sd."CODCURSO" AND t."CODHABILITACAO"::text = sd."CODHABILITACAO" AND t."CODGRADE"::text = sd."CODGRADE";

-- ============================================================
-- VIEW: export.v_matrix_source
-- ============================================================
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
          WHERE er.institution_name ~~* '%Escola do futuro%'::text AND (regexp_match(er.calendar_name, '(\d{4})'::text))[1] IS NOT NULL AND (regexp_match(er.calendar_name, '(\d{4})'::text))[1]::integer >= 2021 AND (upper(TRIM(BOTH FROM COALESCE(er.subject_status, er.status))) = ANY (ARRAY['APPROVED'::text, 'IN PROGRESS'::text])) AND er.course_name IS NOT NULL AND er.module_name IS NOT NULL AND COALESCE(er.disc_code, er.subject_code::text, NULLIF(TRIM(BOTH FROM er.subject_name), ''::text)) IS NOT NULL
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
    a.course_code,
    a.code_module,
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
     LEFT JOIN academic_norm a ON a.course_name_norm = m.course_name AND a.module_name_norm = m.module_name AND NOT a.curriculum_name_norm IS DISTINCT FROM m.curriculum_name AND (a.academic_code_text IS NOT NULL AND m.disc_code_text IS NOT NULL AND a.academic_code_text = m.disc_code_text OR (a.academic_code_text IS NULL OR m.disc_code_text IS NULL) AND a.subject_name_norm IS NOT NULL AND a.subject_name_norm = m.subject_name);

