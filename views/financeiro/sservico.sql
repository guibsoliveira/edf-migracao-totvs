-- ============================================================================
-- View: export.sservico
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

CREATE OR REPLACE VIEW export.sservico AS
WITH por_aluno AS (
         SELECT TRIM(BOTH FROM sh.item) AS item,
            sh.id_pessoa,
            sh.fatura_ano,
            sum(replace(replace(replace(TRIM(BOTH FROM sh.valor_bruto), '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text)::numeric(10,4)) AS valor_aluno
           FROM gennera_stg.servicos_historico sh
          WHERE (sh.item::text ~* '(MENSALIDADE|ALIMENTA|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE)'::text OR sh.item::text ~* '\mMENS\M'::text OR sh.item::text ~* '\mANUID\M'::text OR sh.item::text ~* '\mALIM\M'::text OR sh.item::text ~* '1[^[:space:]]{0,3}\s*(PARC|MENS)'::text) AND sh.valor_bruto IS NOT NULL AND (TRIM(BOTH FROM sh.valor_bruto) <> ALL (ARRAY['$0,00'::text, ''::text, '0'::text, '0,00'::text])) AND sh.calendario_academico IS NOT NULL AND TRIM(BOTH FROM sh.calendario_academico) >= '2021'::text
          GROUP BY (TRIM(BOTH FROM sh.item)), sh.id_pessoa, sh.fatura_ano
        )
 SELECT 1 AS "CODCOLIGADA",
    "left"(item, 60)::character varying(60) AS "NOME",
    mode() WITHIN GROUP (ORDER BY valor_aluno)::numeric(10,4) AS "VALOR",
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
   FROM por_aluno pa
  GROUP BY item
  ORDER BY item;;
