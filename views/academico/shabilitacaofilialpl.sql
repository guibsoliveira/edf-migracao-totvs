-- ============================================================================
-- View: export.shabilitacaofilialpl
-- Esquema destino TOTVS: SHABILITACAOFILIALPL
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
   FROM export.sdiscgrade sd;;
