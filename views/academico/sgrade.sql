-- ============================================================================
-- View: export.sgrade
-- Esquema destino TOTVS: SGRADE
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

CREATE OR REPLACE VIEW export.sgrade AS
SELECT DISTINCT '1'::text AS codcoligada,
    a.course_code AS codcurso,
    a.code_module::text AS codhabilitacao,
    er.calendar_name AS codgrade,
    a.module_name AS descricao,
    NULL::text AS dtinicio,
    NULL::text AS dtfim,
    NULL::text AS cargahoraria,
    '0'::text AS controlevagas,
    '0'::text AS status,
    NULL::text AS codcursoprox,
    NULL::text AS codhabilitacaoprox,
    NULL::text AS codgradeprox,
    NULL::text AS maxcredperiodo,
    NULL::text AS mincredperiodo,
    'S'::text AS regime,
    'H'::text AS tipoatividadecurricular,
    'H'::text AS tipoeletiva,
    'H'::text AS tipooptativa,
    NULL::text AS dtdou,
    NULL::text AS totalcreditos
   FROM gennera_stg.enrollment_record er
     JOIN gennera_stg.academic a ON a.course_name = er.course_name AND a.module_name = er.module_name
  WHERE er.institution_name <> 'EDF - Base de Testes'::text AND er.course_name <> 'Educação Infantil'::text AND a.id_institution <> 3;;
