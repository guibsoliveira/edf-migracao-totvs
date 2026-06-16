-- ============================================================================
-- View: export.shabmodelopgto
-- Esquema destino TOTVS: SHABMODELOPGTO
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

CREATE OR REPLACE VIEW export.shabmodelopgto AS
WITH plan_parsed AS (
         SELECT sp."CODCOLIGADA",
            sp."IDPERLET",
            sp."CODPLANOPGTO",
            sp."CODTIPOCURSO",
            sp."CODFILIAL",
            TRIM(BOTH FROM regexp_replace(sp."NOME"::text, ('\s+'::text || sp."IDPERLET"::text) || '\s*$'::text, ''::text)) AS seg,
                CASE
                    WHEN sp."NOME"::text ~* 'INFANTIL'::text THEN 'EI'::text
                    WHEN sp."NOME"::text ~* '(^|\s)(EI)(\s|$)'::text THEN 'EI'::text
                    WHEN sp."NOME"::text ~* '(^|\s)(INT|INTEGRAL|1/2|MEIO)(\s|$)'::text AND sp."NOME"::text !~* '(FUND|FUNDAMENTAL|EF[12]|EM|MEDIO)'::text THEN 'EI'::text
                    WHEN sp."NOME"::text ~* '(FUNDAMENTAL\s*(I\s|1)|FUND\s*1)'::text THEN 'EF1'::text
                    WHEN sp."NOME"::text ~* '(^|\s)(EF1|F1)(\s|$)'::text THEN 'EF1'::text
                    WHEN sp."NOME"::text ~* '(FUNDAMENTAL\s*(II|2)|FUND\s*2)'::text THEN 'EF2'::text
                    WHEN sp."NOME"::text ~* '(^|\s)(EF2|F2)(\s|$)'::text THEN 'EF2'::text
                    WHEN sp."NOME"::text ~* '(M.DIO)'::text THEN 'EM'::text
                    WHEN sp."NOME"::text ~* '(^|\s)EM(\s|$|-)'::text THEN 'EM'::text
                    WHEN sp."NOME"::text ~ '3.{0,5}5'::text AND sp."NOME"::text !~ '[6-9]'::text THEN 'EF1'::text
                    WHEN sp."NOME"::text ~ '6.{0,5}9'::text THEN 'EF2'::text
                    WHEN sp."NOME"::text ~ '1.{0,3}EM'::text THEN 'EM'::text
                    WHEN sp."NOME"::text ~ '(1|2).{0,3}ANO'::text THEN 'EF1'::text
                    ELSE NULL::text
                END AS codcurso,
                CASE
                    WHEN sp."NOME"::text ~* 'K[12]'::text AND sp."NOME"::text !~* 'N[23]'::text THEN 3
                    WHEN sp."NOME"::text ~* 'N[23]'::text AND sp."NOME"::text !~* 'K[12]'::text THEN 1
                    WHEN sp."NOME"::text ~* '(INFANTIL|(\s|^)EI(\s|$))'::text THEN 1
                    WHEN sp."NOME"::text ~* '(^|\s)(INT|INTEGRAL|1/2|MEIO)(\s|$)'::text AND sp."NOME"::text !~* '(FUND|EF|EM|MEDIO)'::text THEN 1
                    WHEN sp."NOME"::text ~ '1.{0,3}ANO'::text AND sp."NOME"::text ~* '(FUND|EF1|F1)'::text THEN 1
                    WHEN sp."NOME"::text ~ '2.{0,3}ANO'::text AND sp."NOME"::text ~* '(FUND|EF1|F1)'::text THEN 2
                    WHEN sp."NOME"::text ~ '1.{0,3}(e|E).{0,3}2'::text AND sp."NOME"::text ~* '(FUND|EF1|F1)'::text THEN 1
                    WHEN sp."NOME"::text ~ '3.{0,5}5'::text AND sp."NOME"::text !~ '[6-9]'::text THEN 3
                    WHEN sp."NOME"::text ~ '6.{0,5}9'::text THEN 6
                    WHEN sp."NOME"::text ~ '1.{0,5}3.{0,3}(ANO|EM|S)'::text AND sp."NOME"::text ~* '(EM|MEDIO)'::text THEN 1
                    ELSE NULL::integer
                END AS hab_start,
                CASE
                    WHEN sp."NOME"::text ~* 'K[12]'::text AND sp."NOME"::text !~* 'N[23]'::text THEN 4
                    WHEN sp."NOME"::text ~* 'N[23]'::text AND sp."NOME"::text !~* 'K[12]'::text THEN 2
                    WHEN sp."NOME"::text ~* '(INFANTIL|(\s|^)EI(\s|$))'::text THEN 4
                    WHEN sp."NOME"::text ~* '(^|\s)(INT|INTEGRAL|1/2|MEIO)(\s|$)'::text AND sp."NOME"::text !~* '(FUND|EF|EM|MEDIO)'::text THEN 4
                    WHEN sp."NOME"::text ~ '1.{0,3}ANO'::text AND sp."NOME"::text ~* '(FUND|EF1|F1)'::text THEN 1
                    WHEN sp."NOME"::text ~ '2.{0,3}ANO'::text AND sp."NOME"::text ~* '(FUND|EF1|F1)'::text THEN 2
                    WHEN sp."NOME"::text ~ '1.{0,3}(e|E).{0,3}2'::text AND sp."NOME"::text ~* '(FUND|EF1|F1)'::text THEN 2
                    WHEN sp."NOME"::text ~ '3.{0,5}5'::text AND sp."NOME"::text !~ '[6-9]'::text THEN 5
                    WHEN sp."NOME"::text ~ '6.{0,5}9'::text THEN 9
                    WHEN sp."NOME"::text ~ '1.{0,5}3.{0,3}(ANO|EM|S)'::text AND sp."NOME"::text ~* '(EM|MEDIO)'::text THEN 3
                    ELSE NULL::integer
                END AS hab_end,
                CASE
                    WHEN sp."CODFILIAL" = 1 THEN 'INTEGRAL'::text
                    WHEN sp."NOME"::text ~* '(INFANTIL|(\s|^)EI(\s|$))'::text AND sp."NOME"::text ~* 'INTEGRAL'::text THEN 'INTEGRAL'::text
                    WHEN sp."NOME"::text ~* '(INFANTIL|(\s|^)EI(\s|$))'::text AND sp."NOME"::text ~* '(MEIO|1/2)'::text THEN 'MEIO'::text
                    WHEN sp."NOME"::text ~* '(^|\s)(INT|INTEGRAL)(\s|$)'::text AND sp."NOME"::text !~* '(FUND|EF|EM)'::text THEN 'INTEGRAL'::text
                    WHEN sp."NOME"::text ~* '(^|\s)(1/2|MEIO)(\s|$)'::text AND sp."NOME"::text !~* '(FUND|EF|EM)'::text THEN 'MEIO'::text
                    ELSE 'INTEGRAL'::text
                END AS turno_tipo
           FROM export.splanopgto sp
        ), turnos(turno) AS (
         VALUES ('Integral'::text), ('Manha'::text), ('Tarde'::text)
        ), expanded AS (
         SELECT pp."CODCOLIGADA",
            pp."IDPERLET",
            pp."CODPLANOPGTO",
            pp."CODTIPOCURSO",
            pp.codcurso,
            h."CODHABILITACAO",
            t.turno,
            pp."CODFILIAL"
           FROM plan_parsed pp
             JOIN export.shabilitacao h ON h."CODCURSO" = pp.codcurso AND (pp.hab_start IS NULL OR h."CODHABILITACAO"::integer >= pp.hab_start AND h."CODHABILITACAO"::integer <= pp.hab_end)
             JOIN turnos t ON pp.turno_tipo = 'INTEGRAL'::text AND t.turno = 'Integral'::text OR pp.turno_tipo = 'MEIO'::text AND (t.turno = ANY (ARRAY['Manha'::text, 'Tarde'::text]))
          WHERE pp.codcurso IS NOT NULL AND NOT (pp."CODFILIAL" = 1 AND pp.codcurso = 'EI'::text) AND NOT (pp."CODFILIAL" = 1 AND pp.codcurso = 'EF1'::text AND h."CODHABILITACAO"::integer < 3) AND NOT (pp."CODFILIAL" = 2 AND (pp.codcurso = ANY (ARRAY['EF2'::text, 'EM'::text]))) AND NOT (pp."CODFILIAL" = 2 AND pp.codcurso = 'EF1'::text AND h."CODHABILITACAO"::integer > 2)
        )
 SELECT e."CODCOLIGADA",
    e."IDPERLET",
    e."CODPLANOPGTO",
    e."CODTIPOCURSO",
    e.codcurso::character varying(10) AS "CODCURSO",
    e."CODHABILITACAO"::character varying(10) AS "IDHABILITACAOFILIAL",
    COALESCE(g.codgrade, e."IDPERLET"::text)::character varying(10) AS "CODGRADE",
    e.turno::character varying(15) AS "CODTURNO",
    e."CODFILIAL"
   FROM expanded e
     LEFT JOIN export.sgrade g ON g.codcurso = e.codcurso AND g.codhabilitacao = e."CODHABILITACAO" AND g.codgrade = e."IDPERLET"::text
  ORDER BY e."IDPERLET", e."CODFILIAL", e."CODPLANOPGTO", e."CODHABILITACAO", e.turno;;
