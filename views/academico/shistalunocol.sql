-- ============================================================================
-- View: export.shistalunocol
-- Esquema destino TOTVS: SHISTALUNOCOL
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

CREATE OR REPLACE VIEW export.shistalunocol AS
SELECT DISTINCT ON (scu.code_unif, er.calendar_name) '1'::text AS codcoligada,
    scu.code_unif::text AS ra,
    er.calendar_name AS ano,
    er.course_name AS cursohist,
    er.module_name AS seriehist,
    er.institution_name AS instituicao,
    er.status,
    '0'::text AS diasletivos,
    er.workload_real::text AS cargahoraria,
    NULL::text AS obs,
    NULL::text AS minaprov,
    NULL::text AS diretor,
    '1'::text AS codtipocurso,
    NULL::text AS codinstituicao,
    NULL::text AS codcursohistorico,
    NULL::text AS codseriehistorico,
    NULL::text AS faltas,
    NULL::text AS percentfreq,
    NULL::text AS minaprovconceito
   FROM gennera_stg.enrollment_record er
     JOIN gennera_stg.person_fisica pf ON pf.id_person = er.id_person
     LEFT JOIN gennera_stg.enrollment e ON e.id_person = er.id_person
     LEFT JOIN gennera_stg.student_code_unico scu ON pf.id_person = scu.id_person
  WHERE er.institution_name <> 'EDF - Base de Testes'::text AND er.course_name <> 'Educação Infantil'::text
  ORDER BY scu.code_unif, er.calendar_name, er.id_enrollment_record;;
