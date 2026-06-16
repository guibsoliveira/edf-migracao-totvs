-- ============================================================================
-- View: export.splanopgto
-- Esquema destino TOTVS: SPLANOPGTO
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

CREATE OR REPLACE VIEW export.splanopgto AS
WITH base_itens AS (
         SELECT sh.calendario_academico AS ano,
            sh.item
           FROM gennera_stg.servicos_historico sh
          WHERE sh.calendario_academico IS NOT NULL AND TRIM(BOTH FROM sh.calendario_academico) <> ''::text AND sh.calendario_academico >= '2021'::text AND sh.item IS NOT NULL AND TRIM(BOTH FROM sh.item) <> ''::text AND sh.item::text ~* '(MENS|MENSALIDADE|ALIMENTA|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUID|1\S{0,3}\s*PARC)'::text AND NOT (sh.item::text ~ '^20[0-9]{2}\s'::text AND "substring"(sh.item::text, '^(20[0-9]{2})'::text) <> sh.calendario_academico) AND ((sh.calendario_academico, sh.item::text) IN ( SELECT x.calendario_academico,
                    x.item
                   FROM gennera_stg.servicos_historico x
                  WHERE x.calendario_academico >= '2021'::text AND x.item IS NOT NULL AND TRIM(BOTH FROM x.item) <> ''::text AND x.id_pessoa IS NOT NULL AND TRIM(BOTH FROM x.id_pessoa) <> ''::text
                  GROUP BY x.calendario_academico, x.item
                 HAVING count(DISTINCT x.id_pessoa) >= 5 AND count(*) FILTER (WHERE x.status::text = ANY (ARRAY['pago'::character varying, 'pago a maior'::character varying, 'atrasado'::character varying, 'renegociado'::character varying]::text[])) >= 10))
        ), pass1 AS (
         SELECT base_itens.ano,
            regexp_replace(base_itens.item::text, '^20[0-9]{2}\s*'::text, ''::text, 'g'::text) AS txt
           FROM base_itens
        ), pass2 AS (
         SELECT pass1.ano,
            regexp_replace(pass1.txt, '^(1\S{0,3}\s*MENSALIDADE|1\S{0,3}\s*MENS|1\S{0,3}\s*PARC|MENSALIDADE|MENS|ALIMENTA\S*|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE|ANUID\S*|MAT)\s*'::text, ''::text, 'g'::text) AS txt
           FROM pass1
        ), pass3 AS (
         SELECT pass2.ano,
            regexp_replace(pass2.txt, '^(1\S{0,3}\s*MENSALIDADE|1\S{0,3}\s*MENS|1\S{0,3}\s*PARC|MENSALIDADE|MENS|ALIMENTA\S*|MATERIAIS|MAT\s+DIDAT|MDIDAT|MDIAT|MD\s+20[0-9]{2}|ANUIDADE|ANUID\S*|MAT)\s*'::text, ''::text, 'g'::text) AS txt
           FROM pass2
        ), pass4 AS (
         SELECT pass3.ano,
            regexp_replace(pass3.txt, '\s+UN[12]\s*$'::text, ''::text, 'g'::text) AS txt
           FROM pass3
        ), pass5 AS (
         SELECT pass4.ano,
            TRIM(BOTH FROM regexp_replace(regexp_replace(pass4.txt, '\s+,'::text, ','::text, 'g'::text), '\s+'::text, ' '::text, 'g'::text)) AS segmento
           FROM pass4
        ), segmentos_filtrados AS (
         SELECT DISTINCT pass5.ano,
            pass5.segmento
           FROM pass5
          WHERE pass5.segmento <> ''::text AND length(pass5.segmento) >= 2 AND pass5.segmento !~* '^UN[12]$'::text AND pass5.segmento !~~* '%Formatura%'::text AND pass5.segmento !~~* '%Bicho%'::text AND pass5.segmento !~~* '%Museu%'::text AND pass5.segmento !~~* '%Parque%'::text AND pass5.segmento !~~* '%Passeio%'::text AND pass5.segmento !~~* '%English%'::text AND pass5.segmento !~~* '%Summer%'::text AND pass5.segmento !~~* '%Vacation%'::text AND pass5.segmento !~~* '%Curso de F%'::text AND pass5.segmento !~~* '%PROJETO%'::text AND pass5.segmento !~~* '%OUTROS%'::text AND pass5.segmento !~~* '%ADICIONAL%'::text AND pass5.segmento !~~* '%Avulso%'::text AND pass5.segmento !~~* '%Histórico%'::text AND pass5.segmento !~~* '%Historico%'::text AND pass5.segmento !~~* '%Substituti%'::text AND pass5.segmento !~~* '%OVER%'::text AND pass5.segmento !~~* '%HORAS%'::text
        ), segmentos_deduplicados AS (
         SELECT x.ano,
            ( SELECT sf.segmento
                   FROM segmentos_filtrados sf
                  WHERE sf.ano = x.ano AND upper(regexp_replace(regexp_replace(regexp_replace(sf.segmento, '(^|\s)ANOS?(\s|$)'::text, ' '::text, 'ig'::text), '[^A-Za-z0-9/]'::text, ''::text, 'g'::text), '\s+'::text, ''::text, 'g'::text)) = x.chave_norm
                  ORDER BY (length(sf.segmento)), sf.segmento
                 LIMIT 1) AS segmento
           FROM ( SELECT DISTINCT segmentos_filtrados.ano,
                    upper(regexp_replace(regexp_replace(regexp_replace(segmentos_filtrados.segmento, '(^|\s)ANOS?(\s|$)'::text, ' '::text, 'ig'::text), '[^A-Za-z0-9/]'::text, ''::text, 'g'::text), '\s+'::text, ''::text, 'g'::text)) AS chave_norm
                   FROM segmentos_filtrados
                  WHERE length(regexp_replace(segmentos_filtrados.segmento, '[^A-Za-z0-9/]'::text, ''::text, 'g'::text)) >= 2) x
        ), filiais AS (
         SELECT 1 AS codfilial
        UNION ALL
         SELECT 2
        ), seg_class AS (
         SELECT sd.ano,
            sd.segmento,
                CASE
                    WHEN sd.segmento ~* '(M.DIO|(^|\s)EM(\s|$|-)|1\S{0,3}\s*EM|3\S{0,3}\s*EM)'::text THEN 'EM'::text
                    WHEN sd.segmento ~* '(FUND(AMENTAL)?\s*(II|2)|(^|\s)(F2|EF2)(\s|$)|6\S{0,3}\s*(a|ao|/)\s*9)'::text THEN 'EF2'::text
                    WHEN sd.segmento ~* '(3\S{0,3}\s*(a|ao|/)\s*5|1\S{0,3}\s*(a|ao)\s*5)'::text THEN 'EF1_35'::text
                    WHEN sd.segmento ~* '(1\S{0,3}\s*ANO|2\S{0,3}\s*ANO|1\S{0,3}\s*(e|E)\s*2)'::text AND sd.segmento ~* '(FUND|F1|EF1)'::text THEN 'EF1_12'::text
                    WHEN sd.segmento ~* '(FUND(AMENTAL)?\s*(I\s|1|$)|(^|\s)(F1|EF1)(\s|$))'::text THEN 'EF1'::text
                    WHEN sd.segmento ~* 'INFANTIL|(^|\s)EI(\s|$)'::text THEN 'EI'::text
                    WHEN sd.segmento ~* '(^|\s)(INTEGRAL|INT|1/2|MEIO\s*PER)(\s|$)'::text AND sd.segmento !~* '(FUND|F1|F2|EF|EM|M.DIO)'::text THEN 'EI'::text
                    ELSE 'OUTRO'::text
                END AS classe
           FROM segmentos_deduplicados sd
        ), base AS (
         SELECT sc.ano,
            sc.segmento,
            f.codfilial,
            row_number() OVER (PARTITION BY sc.ano, f.codfilial ORDER BY sc.segmento) AS seq
           FROM seg_class sc
             JOIN filiais f ON f.codfilial = 1 AND (sc.classe = ANY (ARRAY['EM'::text, 'EF2'::text, 'EF1_35'::text, 'EF1'::text, 'OUTRO'::text])) OR f.codfilial = 2 AND (sc.classe = ANY (ARRAY['EI'::text, 'EF1_12'::text, 'EF1'::text, 'OUTRO'::text]))
        )
 SELECT 1 AS "CODCOLIGADA",
    ano::character varying(10) AS "IDPERLET",
    ((("right"(ano, 2) || codfilial::text) || lpad(seq::text, 3, '0'::text)))::character varying(10) AS "CODPLANOPGTO",
    "left"(translate((((('Plano '::text || segmento) || ' '::text) || ano) || ' - Filial '::text) || codfilial::text, 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüçº°ª'::text, 'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuucooa'::text), 60)::character varying(60) AS "DESCRICAO",
    "left"(translate((segmento || ' '::text) || ano, 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüçº°ª'::text, 'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuucooa'::text), 60)::character varying(60) AS "NOME",
    (ano || '-01-01'::text)::date AS "DTINICIO",
    (ano || '-12-31'::text)::date AS "DTFIM",
    0::numeric(10,4) AS "DESCONTO",
    1 AS "CODTIPOCURSO",
    codfilial AS "CODFILIAL",
    'N'::character varying(1) AS "MATRICULALIVRE",
    NULL::character varying(1) AS "TIPOBLOQUEIOVLRBASEPERSONALIZ"
   FROM base
  ORDER BY ano, codfilial, seq;;
