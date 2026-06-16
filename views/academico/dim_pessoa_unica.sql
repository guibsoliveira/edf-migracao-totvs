-- ============================================================================
-- View: export.dim_pessoa_unica
-- Esquema destino TOTVS: DIM_PESSOA_UNICA
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
  WHERE ordem = 1;;
