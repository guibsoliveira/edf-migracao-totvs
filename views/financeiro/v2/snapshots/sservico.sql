-- ============================================================================
-- View: export_v2.sservico
-- Esquema destino TOTVS: SSERVICO
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

CREATE OR REPLACE VIEW export_v2.sservico AS
WITH fixos AS (
         SELECT t.nome,
            t.valor
           FROM ( VALUES ('1ª mensalidade'::character varying(60),0::numeric(10,4)), ('Mensalidade'::character varying(60),0::numeric(10,4)), ('Material Didático'::character varying(60),0::numeric(10,4)), ('Alimentação'::character varying(60),0::numeric(10,4))) t(nome, valor)
        ), variaveis AS (
         SELECT "left"(item_to_sservico.description, 60)::character varying(60) AS nome,
            mode() WITHIN GROUP (ORDER BY item_to_sservico.price)::numeric(10,4) AS valor
           FROM gennera_stg.item_to_sservico
          WHERE item_to_sservico.sservico_nome = 'Variável'::text AND item_to_sservico.description IS NOT NULL AND TRIM(BOTH FROM item_to_sservico.description) <> ''::text
          GROUP BY ("left"(item_to_sservico.description, 60))
        ), servicos_historico_extras AS (
         SELECT "left"(TRIM(BOTH FROM sh.item), 60)::character varying(60) AS nome,
            mode() WITHIN GROUP (ORDER BY (NULLIF(replace(replace(replace(COALESCE(sh.valor_bruto, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric))::numeric(10,4) AS valor
           FROM gennera_stg.servicos_historico sh
          WHERE sh.item IS NOT NULL AND TRIM(BOTH FROM sh.item) <> ''::text AND sh.item::text !~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'::text AND sh.item::text !~* 'matr.cula'::text AND sh.item::text !~~* '%ANUID%'::text AND sh.item::text !~~* '%MENS%'::text AND sh.item::text !~~* '%ALIM%'::text AND sh.item::text !~~* '%MATERIAL%'::text AND sh.item::text !~~* '%MATERIAIS%'::text AND sh.item::text !~~* '%MAT%DIDAT%'::text AND sh.item::text !~~* '%MDIDAT%'::text AND sh.item::text !~~* '%MDIAT%'::text AND sh.item::text !~* '\mMD\M'::text AND sh.item::text !~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'::text AND sh.calendario_academico >= '2021'::text
          GROUP BY ("left"(TRIM(BOTH FROM sh.item), 60))
        ), unificado AS (
         SELECT fixos.nome,
            fixos.valor
           FROM fixos
        UNION ALL
         SELECT variaveis.nome,
            variaveis.valor
           FROM variaveis
        UNION ALL
         SELECT servicos_historico_extras.nome,
            servicos_historico_extras.valor
           FROM servicos_historico_extras
          WHERE NOT (EXISTS ( SELECT 1
                   FROM variaveis v
                  WHERE v.nome::text = servicos_historico_extras.nome::text))
        )
 SELECT 1 AS "CODCOLIGADA",
    nome AS "NOME",
    valor AS "VALOR",
    1 AS "CODTIPOCURSO",
    1 AS "CODCOLCXA",
    '237'::character varying(10) AS "CODCXA",
    'N'::character varying(1) AS "VERIFICAINADIMPLENCIA",
    NULL::integer AS "TIPOCONTABILLAN",
    NULL::character varying(10) AS "CODTDO",
    1 AS "CODCOLNATFINANCEIRA",
    '111.111'::character varying(40) AS "NATFINANCEIRA",
    'N'::character varying(1) AS "PERMITEACORDO",
    NULL::character varying(1) AS "APROVEITACONTACORRENTE",
    NULL::character varying(1) AS "CONSIDERAPARCELAFIXA",
    NULL::character varying(1) AS "DISPONIVELEXTENSAO",
    NULL::character varying(1) AS "DESCONSIDERACREDITORETROATIVO",
    'S'::character varying(1) AS "PGCARTAODEBITO",
    'S'::character varying(1) AS "PGCARTAOCREDITO",
    NULL::character varying(1) AS "CONSIDERADESCANTECIPACAO"
   FROM unificado
  ORDER BY (
        CASE nome
            WHEN '1ª mensalidade'::text THEN 1
            WHEN 'Mensalidade'::text THEN 2
            WHEN 'Material Didático'::text THEN 3
            WHEN 'Alimentação'::text THEN 4
            ELSE 99
        END), nome;;
