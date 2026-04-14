-- ============================================================
-- RELATÓRIO DE QUALIDADE DE DADOS — ALUNOS E RESPONSÁVEIS
-- Matrículas ATIVAS em 2024 / 2025 / 2026
-- Retorna somente registros com pelo menos 1 campo crítico faltando
-- ============================================================

SELECT
    e.academic_calendar                                                     AS ano,
    e.class_name                                                            AS turma,
    e.course_name                                                           AS curso,
    e.status                                                                AS status_matricula,

    -- Aluno
    aluno_pf.name                                                           AS aluno_nome,
    e.id_person                                                             AS aluno_id,
    aluno_pf.cpf                                                            AS aluno_cpf,
    CASE WHEN aluno_pf.cpf IS NULL THEN 'S' ELSE 'N' END                   AS aluno_sem_cpf,

    -- Responsável Acadêmico
    resp_acad_pf.name                                                       AS resp_acad_nome,
    resp_acad_pf.cpf                                                        AS resp_acad_cpf,
    CASE WHEN resp_acad_pf.cpf IS NULL THEN 'S' ELSE 'N' END               AS resp_acad_sem_cpf,

    -- Responsável Financeiro (PF ou PJ)
    COALESCE(resp_fin_pf.name,   resp_fin_pj.name)                         AS resp_fin_nome,
    COALESCE(resp_fin_pf.cpf,    resp_fin_pj.cnpj)                         AS resp_fin_cpf_cnpj,
    CASE WHEN resp_fin_pf.cpf IS NULL AND resp_fin_pj.cnpj IS NULL
         THEN 'S' ELSE 'N' END                                             AS resp_fin_sem_cpf_cnpj,
    resp_fin_pf.zipcode                                                     AS resp_fin_cep,
    resp_fin_pf.street                                                      AS resp_fin_rua,
    CASE WHEN (resp_fin_pf.zipcode IS NULL OR TRIM(resp_fin_pf.zipcode) = '')
          OR  (resp_fin_pf.street  IS NULL OR TRIM(resp_fin_pf.street)  = '')
         THEN 'S' ELSE 'N' END                                             AS resp_fin_sem_endereco

FROM gennera_stg.enrollment e

-- Aluno (pessoa física)
LEFT JOIN gennera_stg.person_fisica aluno_pf
    ON aluno_pf.id_person = e.id_person

-- Responsável Acadêmico (pessoa física)
LEFT JOIN gennera_stg.person_fisica resp_acad_pf
    ON resp_acad_pf.id_person = e.id_academic_responsible

-- Responsável Financeiro — PF
LEFT JOIN gennera_stg.person_fisica resp_fin_pf
    ON resp_fin_pf.id_person = e.id_financial_responsible

-- Responsável Financeiro — PJ (fallback)
LEFT JOIN gennera_stg.person_juridica resp_fin_pj
    ON resp_fin_pj.id_person = e.id_financial_responsible

WHERE e.academic_calendar IN ('2021', '2022', '2023', '2024', '2025', '2026')
  AND e.status = 'active'
  AND e.id_institution IN (1, 2)
  AND e.class_name NOT ILIKE '%módulo%'
  AND (
         aluno_pf.cpf IS NULL
      OR resp_acad_pf.cpf IS NULL
      OR (resp_fin_pf.cpf IS NULL AND resp_fin_pj.cnpj IS NULL)
      OR (resp_fin_pf.zipcode IS NULL OR TRIM(resp_fin_pf.zipcode) = '')
      OR (resp_fin_pf.street  IS NULL OR TRIM(resp_fin_pf.street)  = '')
  )

ORDER BY e.academic_calendar, e.class_name, aluno_pf.name;
