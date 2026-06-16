-- ============================================================================
-- View: export.shabilitacaofilial
-- Esquema destino TOTVS: SHABILITACAOFILIAL
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

CREATE OR REPLACE VIEW export.shabilitacaofilial AS
SELECT row_number() OVER (ORDER BY (codgrade::integer), codcurso, codhabilitacao, codfilial, codturno)::integer AS idhabilitacaofilial,
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
            t.turno AS codturno,
            '0000000001'::character varying(25) AS codccusto,
            'S'::character varying(1) AS ativo,
            NULL::character varying(25) AS coddepartamento,
            NULL::character varying(60) AS emailcoordenacao,
            NULL::text AS decretocurso,
            NULL::text AS decretohabilitacao,
            NULL::text AS descricaocurso,
            NULL::text AS descricaohabilitacao
           FROM export.sdiscgrade sd
             LEFT JOIN gennera_stg.academic a ON a.course_code = sd."CODCURSO" AND a.code_module::text = sd."CODHABILITACAO"
             CROSS JOIN ( VALUES ('Integral'::text), ('Manha'::text), ('Tarde'::text)) t(turno)
          WHERE
                CASE
                    WHEN a.id_institution = 2 THEN 2
                    ELSE 1
                END = 2 AND sd."CODCURSO" = 'EI'::text OR t.turno = 'Integral'::text) base
  WHERE codhabilitacao IS NOT NULL AND codcurso IS NOT NULL;;
