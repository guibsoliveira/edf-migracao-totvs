# 07 - Queries Uteis para Gennera

Queries SQL prontas para consultas frequentes no banco gennera_stg durante migracao.
Todas testadas com PGCLIENTENCODING=LATIN1.

## 1. Lookup Pessoa por CPF

Encontra pessoa por CPF sem mascara.

Query:
SELECT pf.id_person, pf.name, pf.cpf, pf.birthdate, pf.email
FROM gennera_stg.person_fisica pf
WHERE pf.cpf = :cpf_param LIMIT 10;

Parametros: cpf_param = CPF sem mascara (ex: XXXXXXXXXXXXX)
Output: 1 linha se unico; 0 se nao existe; 2+ se duplicata
Notas: Case-insensitive; 4.389 pessoas SEM CPF (48%); usar person_cpf_mapping para dedup

## 2. Lookup Pessoa por Nome

Busca por nome usando LIKE parcial.

Query:
SELECT pf.id_person, pf.name, pf.cpf, sc.code_unif as ra_canonico
FROM gennera_stg.person_fisica pf
LEFT JOIN gennera_stg.student_code_unico sc ON pf.id_person = sc.id_person
WHERE UPPER(pf.name) LIKE UPPER(:name_param)
ORDER BY pf.name LIMIT 20;

Parametros: name_param = nome com wildcards (ex: %STUDENT_NAME%)
Output: Array de matching persons com RA canonico
Notas: UPPER() normaliza; aumentar LIMIT se > 20 resultados

## 3. Lookup Pessoa por ID (Namespacing Critico)

AVISO: id_person eh LOCAL no banco (1-9173 por instituicao), API usa GLOBAL (355k-3M).

Query:
SELECT pf.id_person, pf.name, pf.cpf, 
       CASE WHEN en.id_institution = 320 THEN "UN1" ELSE "UN2" END as filial
FROM gennera_stg.person_fisica pf
LEFT JOIN gennera_stg.enrollment en ON pf.id_person = en.id_person
WHERE pf.id_person = :id_person_local LIMIT 1;

Parametros: id_person_local = int (ex: 1234)
Output: 1 linha com filiacao
Notas: NAO fazer JOIN com servicos_historico.id_pessoa; usar CPF como chave

## 4. Contratos Correntes por Filial

Contratos ativos com resumo financeiro.

Query:
SELECT c.id_contract, pf.name, pf.cpf,
       CASE c.id_institution WHEN 320 THEN "UN1" WHEN 321 THEN "UN2" END as filial,
       c.status, c.total, c.payments, c.balance,
       COUNT(i.id_invoice) as qtd_parcelas
FROM gennera_stg.contract c
JOIN gennera_stg.person_fisica pf ON c.id_person = pf.id_person
LEFT JOIN gennera_stg.invoice i ON c.id_contract = i.id_contract
WHERE c.id_institution = :institution_id AND c.status = "active"
GROUP BY c.id_contract, pf.name, pf.cpf, c.id_institution, c.status, c.total, c.payments, c.balance
ORDER BY c.balance DESC LIMIT 100;

Parametros: institution_id = 320 (UN1) ou 321 (UN2)
Output: Contratos por saldo devedor descendente
Notas: balance = total - payments; GROUP BY para agrupar invoices

## 5. Parcelas em Aberto por Aluno

TODAS as parcelas nao-pagas de um aluno.

Query:
SELECT c.id_contract, i.month, i.year, i.due_date::date as vencimento,
       i.total as valor_bruto, i.balance as saldo_aberto,
       CASE WHEN i.balance > 0 AND i.due_date::date < CURRENT_DATE THEN "VENCIDO"
            WHEN i.balance > 0 THEN "PENDENTE" ELSE "PAGO" END as status
FROM gennera_stg.invoice i
JOIN gennera_stg.contract c ON i.id_contract = c.id_contract
WHERE c.id_person = :id_person AND i.balance > 0
ORDER BY i.due_date ASC;

Parametros: id_person = id_person local (ex: 1234)
Output: Array parcelas nao-pagas por vencimento
Notas: Filtro i.balance > 0; due_date em timestamp

## 6. Resumo Financeiro de Aluno

Dashboard: quanto faturado, pago, deve.

Query:
SELECT pf.name, COUNT(DISTINCT c.id_contract) as qtd_contratos,
       SUM(c.total)::numeric(12,2) as total_faturado,
       SUM(c.payments)::numeric(12,2) as total_pago,
       SUM(c.balance)::numeric(12,2) as saldo_devedor,
       ROUND(100.0 * SUM(c.payments) / NULLIF(SUM(c.total), 0), 2) as pct_pago
FROM gennera_stg.person_fisica pf
LEFT JOIN gennera_stg.contract c ON pf.id_person = c.id_person
WHERE pf.id_person = :id_person
GROUP BY pf.id_person, pf.name;

Parametros: id_person = id_person local
Output: 1 linha com agregados
Notas: NULLIF protege divisao por zero; pct_pago = (pago/faturado)*100

## 7. Disciplinas + Notas + Frequencia

Historico academico detalhado de aluno em ano.

Query:
SELECT er.code_unif as ra, er.year, er.discipline_name,
       er.grade as nota, er.average as media, er.attendance_percentage as frequencia,
       CASE WHEN er.average >= 7 AND er.attendance_percentage >= 75 THEN "APROVADO"
            WHEN er.average < 7 THEN "REPROVADO"
            WHEN er.attendance_percentage < 75 THEN "FALTAS"
            ELSE "PENDENTE" END as situacao
FROM gennera_stg.enrollment_record er
WHERE er.code_unif = :code_unif AND er.year = :ano_letivo;

Parametros: code_unif = RA (ex: 20211234567); ano_letivo = int (ex: 2024)
Output: Array disciplinas com notas e frequencia
Notas: enrollment_record = 154.826 linhas totais; granularidade aluno+disciplina

## 8. Identificar Duplicatas (2+ Filiais)

Pessoas em UN1 + UN2 simultaneamente.

Query:
SELECT pcm.id_person_principal, pf.cpf, pf.name,
       STRING_AGG(DISTINCT CASE WHEN en.id_institution = 320 THEN "UN1"
                               WHEN en.id_institution = 321 THEN "UN2" END, ", ") as filiadas,
       COUNT(DISTINCT en.id_enrollment) as matriculas
FROM gennera_stg.person_cpf_mapping pcm
JOIN gennera_stg.person_fisica pf ON pf.id_person = pcm.id_person_principal
LEFT JOIN gennera_stg.enrollment en ON pf.id_person = en.id_person
WHERE pcm.cpf_temporario = false
GROUP BY pcm.id_person_principal, pf.cpf, pf.name
HAVING COUNT(DISTINCT en.id_institution) > 1;

Parametros: Nenhum
Output: Pessoas em multiplas filiais
Notas: person_cpf_mapping = 5.310 linhas; cpf_temporario=true = 8%

## 9. Cross-Check: Reconciliacao Invoice vs Contract

Validacao sum(invoice.total) = contract.total.

Query:
SELECT c.id_contract, pf.name, SUM(i.total)::numeric(12,2) as total_invoices,
       c.total::numeric(12,2) as total_contract,
       CASE WHEN ABS(SUM(i.total)::numeric - c.total::numeric) < 0.01 THEN "OK"
            ELSE "DIVERGENCIA" END as status
FROM gennera_stg.contract c
JOIN gennera_stg.person_fisica pf ON c.id_person = pf.id_person
LEFT JOIN gennera_stg.invoice i ON c.id_contract = i.id_contract
WHERE c.id_institution = :institution_id
GROUP BY c.id_contract, pf.name, c.total
HAVING ABS(SUM(i.total)::numeric - c.total::numeric) >= 0.01;

Parametros: institution_id = 320 ou 321
Output: Contratos com divergencia
Notas: ABS() < 0.01 tolera centavos; servicos_historico.contrato = TEXT (CAST)

## 10. TOP 20 Inadimplentes

Maiores devedores para cobranca.

Query:
SELECT c.id_contract, pf.name, pf.cpf, pf.email, pf.city,
       c.total::numeric(12,2) as faturado, c.balance::numeric(12,2) as devedor,
       MAX(i.due_date)::date as ultima_parcela,
       CAST((CURRENT_DATE - MAX(i.due_date)::date) AS int) as dias_vencidos
FROM gennera_stg.contract c
JOIN gennera_stg.person_fisica pf ON c.id_person = pf.id_person
LEFT JOIN gennera_stg.invoice i ON c.id_contract = i.id_contract AND i.balance > 0
WHERE c.balance > 0
GROUP BY c.id_contract, pf.name, pf.cpf, pf.email, pf.city, c.total, c.balance
ORDER BY c.balance DESC LIMIT 20;

Parametros: Nenhum
Output: 20 maiores devedores
Notas: dias_vencidos = dias desde ultima parcela; NULL se futuras

## Conexao + Conversoes

Conexao padrao:
PGCLIENTENCODING=LATIN1 PGPASSWORD="$DB_PASS" "/c/Program Files/PostgreSQL/18/bin/psql.exe" -h $DB_HOST -U $DB_USER -d Edf_bd_legado
# Credenciais em CLAUDE.local.md (gitignored)

Conversoes Tipicas:
-- BRL para numeric
REPLACE(REPLACE(REPLACE(campo, "$", ""), ".", ""), ",", ".")::numeric

-- Datas
CAST(campo AS date)
TO_DATE(campo, "DD/MM/YYYY")

-- CPF normalizacao
REGEXP_REPLACE(cpf, "[^0-9]", "", "g")

Indices Uteis:
- person_fisica(cpf) lookup CPF
- contract(id_person, id_institution) contratos
- invoice(id_contract) parcelas
- student_code_unico(id_person) RA canonico
