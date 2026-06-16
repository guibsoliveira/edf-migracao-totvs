-- ============================================================================
-- View: export_v2.sparcplano
-- Esquema destino TOTVS: SPARCPLANO
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

CREATE OR REPLACE VIEW export_v2.sparcplano AS
WITH planos AS (
         SELECT sp."CODCOLIGADA",
            sp."CODPERLET"::text AS ano,
            sp."CODPLANOPGTO",
            sp."CODFILIAL" AS codfilial,
            regexp_replace(sp."NOME"::text, '\s+\d{4}\s*$'::text, ''::text) AS segmento
           FROM export_v2.splanopgto sp
        ), api_norm AS (
         SELECT "substring"(ai.description, '^(\d{4})'::text) AS ano,
                CASE
                    WHEN ai.id_institution = 320 THEN 1
                    ELSE 2
                END AS codfilial,
                CASE
                    WHEN ai.id_institution = 320 AND ai.description ~* '\m(EM|ENSINO\s*M.DIO)\M'::text THEN 'EM 1º / 3º ANO'::text
                    WHEN ai.id_institution = 320 AND ai.description ~* '\m(F2|EF2|FUND.*\s*2)\M'::text THEN 'EF2 6º / 9º ANO'::text
                    WHEN ai.id_institution = 320 AND ai.description ~* '\m(F1|EF1|FUND.*\s*1)\M'::text THEN 'EF1 3º / 5º ANO'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*INTEGRAL\s*K1'::text THEN 'EI INTEGRAL K1, K2'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*INTEGRAL\s*N2'::text THEN 'EI INTEGRAL N2, N3'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*MEIO\s*PERIODO\s*K1'::text THEN 'EI MEIO PERIODO K1, K2'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* 'EI\s*MEIO\s*PERIODO\s*N2'::text THEN 'EI MEIO PERIODO N2, N3'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* '\m(1.{0,3}\s*ANO|FUND\s*1\s*-?\s*1)\M'::text THEN 'EF1 1º ANO'::text
                    WHEN ai.id_institution = 321 AND ai.description ~* '\m(2.{0,3}\s*ANO|FUND\s*1\s*-?\s*2)\M'::text THEN 'EF1 2º ANO'::text
                    ELSE NULL::text
                END AS segmento,
                CASE
                    WHEN ai.description ~* '^\d{4}\s+1\s*[º°.ª]?\s*(MENS|PARC|MEN)'::text THEN '1ª mensalidade'::text
                    WHEN ai.description ~* '^\d{4}\s+(MENS|MENSALIDADE)\s'::text AND ai.description !~* 'ANUID'::text THEN 'Mensalidade'::text
                    WHEN ai.description ~* '^\d{4}\s+ALIM(ENT)?'::text THEN 'Alimentação'::text
                    WHEN ai.description ~* '^\d{4}\s+(MATERIA|MAT\s*DIDAT|MDIDAT|MDIAT|MD\s*\d|MAT\s+(EF|EM|F[12]))'::text THEN 'Material Didático'::text
                    ELSE NULL::text
                END AS tipo_servico,
                CASE
                    WHEN ai.description ~* '^\d{4}\s+1\s*[º°.ª]?\s*(MENS|PARC|MEN)'::text THEN ai.price
                    ELSE ai.price / 12::numeric
                END AS valor_mensal
           FROM gennera_stg.api_items ai
          WHERE ai.status = 'active'::text AND ai.description ~ '^\d{4}\s'::text AND ai.description !~~* '%ANUID%'::text AND ai.description ~* '^\d{4}\s+(1\s*[º°.ª]?\s*(MENS|PARC|MEN)|MENS|MENSALIDADE|ALIM(ENT)?|MATERIA|MAT\s*DIDAT|MDIDAT|MDIAT|MD\s*\d|MAT\s+(EF|EM|F[12]))'::text
        ), api_chave AS (
         SELECT api_norm.ano,
            api_norm.codfilial,
            api_norm.segmento,
            api_norm.tipo_servico,
            mode() WITHIN GROUP (ORDER BY api_norm.valor_mensal) AS valor_mensal
           FROM api_norm
          WHERE api_norm.segmento IS NOT NULL AND api_norm.tipo_servico IS NOT NULL AND api_norm.valor_mensal > 0::numeric
          GROUP BY api_norm.ano, api_norm.codfilial, api_norm.segmento, api_norm.tipo_servico
        ), sh_norm AS (
         SELECT sh.calendario_academico AS ano,
                CASE inst.code
                    WHEN 'un1'::text THEN 1
                    ELSE 2
                END AS codfilial,
                CASE
                    WHEN inst.code = 'un1'::text AND st."CODCURSO" = 'EF1'::text THEN 'EF1 3º / 5º ANO'::text
                    WHEN inst.code = 'un1'::text AND st."CODCURSO" = 'EF2'::text THEN 'EF2 6º / 9º ANO'::text
                    WHEN inst.code = 'un1'::text AND st."CODCURSO" = 'EM'::text THEN 'EM 1º / 3º ANO'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND st."TURNO" = 'Integral'::text AND st."CODHABILITACAO" >= 3 THEN 'EI INTEGRAL K1, K2'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND st."TURNO" = 'Integral'::text AND st."CODHABILITACAO" <= 2 THEN 'EI INTEGRAL N2, N3'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND (st."TURNO" = ANY (ARRAY['Manha'::text, 'Tarde'::text])) AND st."CODHABILITACAO" >= 3 THEN 'EI MEIO PERIODO K1, K2'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EI'::text AND (st."TURNO" = ANY (ARRAY['Manha'::text, 'Tarde'::text])) AND st."CODHABILITACAO" <= 2 THEN 'EI MEIO PERIODO N2, N3'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EF1'::text AND st."CODHABILITACAO" = 1 THEN 'EF1 1º ANO'::text
                    WHEN inst.code = 'un2'::text AND st."CODCURSO" = 'EF1'::text AND st."CODHABILITACAO" = 2 THEN 'EF1 2º ANO'::text
                    ELSE NULL::text
                END AS segmento,
                CASE
                    WHEN sh.item::text ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'::text AND sh.item::text !~* '^\s*(MENS|PARC)'::text THEN '1ª mensalidade'::text
                    WHEN sh.item::text ~~* '%ANUID%'::text THEN NULL::text
                    WHEN sh.item::text ~~* '%MENS%'::text THEN 'Mensalidade'::text
                    WHEN sh.item::text ~~* '%ALIM%'::text THEN 'Alimentação'::text
                    WHEN sh.item::text ~~* '%MATERIAL%'::text OR sh.item::text ~~* '%MATERIAIS%'::text OR sh.item::text ~~* '%MAT%DIDAT%'::text OR sh.item::text ~~* '%MDIDAT%'::text OR sh.item::text ~~* '%MDIAT%'::text OR sh.item::text ~* '\mMAT\M\s+(F[12]|EM|FUND|EI)'::text OR sh.item::text ~* '\mMD\M'::text THEN 'Material Didático'::text
                    ELSE NULL::text
                END AS tipo_servico,
            NULLIF(replace(replace(replace(COALESCE(sh.valor_bruto, ''::character varying)::text, '$'::text, ''::text), '.'::text, ''::text), ','::text, '.'::text), ''::text)::numeric AS valor
           FROM gennera_stg.servicos_historico sh
             JOIN gennera_stg.person_fisica pf ON pf.name = sh.aluno::text
             JOIN gennera_stg.enrollment e_1 ON e_1.id_person = pf.id_person AND e_1.academic_calendar = sh.calendario_academico
             JOIN gennera_stg.institution inst ON inst.id_institution = e_1.id_institution
             JOIN export.sturma st ON st."CODTURMA" = e_1.class_name AND st."CODPERLET" = e_1.academic_calendar
          WHERE sh.item IS NOT NULL AND sh.valor_bruto IS NOT NULL AND COALESCE(sh.status, ''::character varying)::text <> 'cancelado'::text AND (inst.code = ANY (ARRAY['un1'::text, 'un2'::text])) AND sh.calendario_academico >= '2021'::text AND sh.calendario_academico <= '2025'::text
        ), sh_chave AS (
         SELECT sh_norm.ano,
            sh_norm.codfilial,
            sh_norm.segmento,
            sh_norm.tipo_servico,
            mode() WITHIN GROUP (ORDER BY sh_norm.valor) AS valor_mensal
           FROM sh_norm
          WHERE sh_norm.segmento IS NOT NULL AND sh_norm.tipo_servico IS NOT NULL AND sh_norm.valor > 0::numeric
          GROUP BY sh_norm.ano, sh_norm.codfilial, sh_norm.segmento, sh_norm.tipo_servico
        ), preco_final AS (
         SELECT COALESCE(a.ano, h.ano) AS ano,
            COALESCE(a.codfilial, h.codfilial) AS codfilial,
            COALESCE(a.segmento, h.segmento) AS segmento,
            COALESCE(a.tipo_servico, h.tipo_servico) AS tipo_servico,
            COALESCE(a.valor_mensal, h.valor_mensal) AS valor_mensal
           FROM api_chave a
             FULL JOIN sh_chave h ON h.ano = a.ano AND h.codfilial = a.codfilial AND h.segmento = a.segmento AND h.tipo_servico = a.tipo_servico
        ), expandido AS (
         SELECT p."CODCOLIGADA",
            p.ano,
            p."CODPLANOPGTO",
            p.codfilial,
            p.segmento,
            '1ª mensalidade'::text AS tipo_servico,
            1 AS parcela,
            pf.valor_mensal AS valor
           FROM planos p
             LEFT JOIN preco_final pf ON pf.ano = p.ano AND pf.codfilial = p.codfilial AND pf.segmento = p.segmento AND pf.tipo_servico = '1ª mensalidade'::text
        UNION ALL
         SELECT p."CODCOLIGADA",
            p.ano,
            p."CODPLANOPGTO",
            p.codfilial,
            p.segmento,
            tp.tipo_servico,
            m.m AS parcela,
            pf.valor_mensal
           FROM planos p
             CROSS JOIN ( VALUES ('Mensalidade'::text), ('Alimentação'::text), ('Material Didático'::text)) tp(tipo_servico)
             CROSS JOIN generate_series(1, 12) m(m)
             LEFT JOIN preco_final pf ON pf.ano = p.ano AND pf.codfilial = p.codfilial AND pf.segmento = p.segmento AND pf.tipo_servico = tp.tipo_servico
        )
 SELECT "CODCOLIGADA",
    ano::character varying(10) AS "CODPERLET",
    1 AS "CODTIPOCURSO",
    "CODPLANOPGTO",
    parcela AS "PARCELA",
    1 AS "COTA",
    "left"(tipo_servico, 60)::character varying(60) AS "NOMESERVICO",
    COALESCE(valor, 0::numeric)::numeric(10,4) AS "VALOR",
    make_date(ano::integer, parcela, 5) AS "DTVENCIMENTO",
    0::numeric(10,4) AS "DESCONTO",
    'V'::character varying(1) AS "TIPODESC",
    'N'::character varying(1) AS "VALORAUTOMATICO",
    make_date(ano::integer, parcela, 1) AS "DTCOMPETENCIA",
    'P'::character varying(1) AS "TIPOPARCELA",
    codfilial AS "CODFILIAL",
    'N'::character varying(1) AS "DTVENCIMENTOFLEXIVEL"
   FROM expandido e
  ORDER BY "CODPLANOPGTO", (
        CASE tipo_servico
            WHEN '1ª mensalidade'::text THEN 1
            WHEN 'Mensalidade'::text THEN 2
            WHEN 'Alimentação'::text THEN 3
            WHEN 'Material Didático'::text THEN 4
            ELSE NULL::integer
        END), parcela;;
