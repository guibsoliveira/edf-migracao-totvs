# 09 - Diagrama ER - Gennera

Relacionamentos entre entidades com cardinalidades e namespacing critico.

## PESSOAS (Banco Local)

person_fisica (1-9173 por instituicao)
  - id_person (PK)
  - name, cpf, email, birthdate, gender, address
  - Relaçoes: 1:N para contract, enrollment, student_code_unico

person_cpf_mapping (5.310 linhas)
  - cpf (PK)
  - id_person_principal (FK para person_fisica)
  - Proposito: dedup por CPF

student_code_unico (2.389)
  - id_person (FK) + source (PK)
  - code_unif (RA YYYYNNNNNN)
  - MESTRE da verdade para RA

person_juridica (8 linhas)
  - Raro; aproximadamente 5 contratos PJ

## ACADEMICO

enrollment (3.290)
  - id_enrollment (PK)
  - id_person, id_institution (FK)
  - status, academic_calendar
  - 1:N para enrollment_record, enrollment_contract, class

enrollment_record (154.826)
  - Granularidade: aluno + disciplina + periodo
  - Campos: code_unif, year, discipline_code, grade, average, attendance_percentage
  - Historico completo 2018-2025

academic (770)
  - id_academic (PK)
  - subject_code_gennera (numero) != subject_code TOTVS (4 chars)
  - 1:N para grade, period_average, attendance

class (7.447)
  - id_class (PK)
  - Turmas com sufixos (UN2 EI: IA=integral, MB=manha, TC=tarde)

grade (796.228)
  - Notas em texto ("8.5", "A", "---")

period_average (214.672)
  - Medias por periodo (P1/P2/P3/REC)

attendance (296.054)
  - Frequencia

## FINANCEIRO (CRITICO)

contract (13.283)
  - id_contract (PK)
  - id_person, id_institution (FK)
  - status (active, cancelled, pending)
  - total, payments, balance, discounts
  - 1:N para invoice, enrollment_contract, servicos

invoice (99.408)
  - id_invoice (PK)
  - id_contract (FK)
  - month, year, due_date
  - total, discounts, payments, balance
  - 1:N para invoice_payment, payment

payment (63.266)
  - id_payment (PK)
  - paymentDate, amount
  - status (paid, cancelled, pending)
  - payment_method, card_brand
  - N:M para invoice (via invoice_payment)

servicos_historico (125.849)
  - DENORMALIZADO para relatorio
  - Granularidade: contrato + periodo
  - Campos: 48 colunas (valor_bruto, desconto, saldo_devedor, etc)
  - Problema: contrato = TEXT (CAST para int para JOIN)
  - Problema: id_pessoa = API global ID (NAO pode JOIN direto com person_fisica.id_person local)
  - Solucao: Usar CPF (person_cpf_mapping) como chave intermediaria

servicos (545)
  - UNICA fonte de desconto por parcela (DescBolsas)
  - Relaçao: N:1 para contract (bolsa por contrato)

enrollment_contract (23.476)
  - Ponte N:M entre enrollment e contract
  - Um aluno tem 1 enrollment, mas multiplos contratos (MENS+ALIM+MAT+REMATRIC)

invoice_payment (N/A)
  - Ponte N:M entre invoice e payment
  - Uma parcela pode ter multiplos pagamentos (split)

## NAMESPACING CRITICO

### Banco Local (gennera_stg)
- id_person: 1-9173 POR INSTITUICAO
- Tabelas: person_fisica, contract, enrollment, enrollment_record, class, academic
- Escopo: LOCAL (UN1 independente de UN2)

### API Gennera (live)
- id: 355.000-3.000.000 GLOBAL
- Tabelas: personId em /persons, /contracts, servicos_historico.id_pessoa
- Escopo: GLOBAL (mesmo aluno em UN1 e UN2 = IDs diferentes)

### Impacto Migracao

CUIDADO: NAO fazer JOIN entre:
  servicos_historico.id_pessoa (API global)
  E
  person_fisica.id_person (banco local)

Solucao: Usar person_cpf_mapping.cpf como chave intermediaria
```sql
SELECT sh.id_pessoa, pf.id_person
FROM gennera_stg.servicos_historico sh
JOIN gennera_stg.person_cpf_mapping pcm ON sh.cpf_responsavel_financeiro = pcm.cpf
JOIN gennera_stg.person_fisica pf ON pcm.id_person_principal = pf.id_person
```

## TABELAS LIVE-ONLY (Banco NAO tem)

recurringPayment
  - Localizacao: GET /contracts/{id}/detailed
  - Campos: active, retryCount, maxRetries, lastCharge
  - Proposito: rastreamento de cobranças recorrentes
  - Impacto: Dados de 2026 SO vem via API

gatewayTransactions
  - Localizacao: GET /contracts/{id}/detailed
  - Campos: id, attemptNumber, status, resultCode, resultMessage, chargeDate
  - Proposito: historico de tentativas no gateway PJBank
  - Limitacao: SO guarda transacao FINAL, nao recusadas (cod 05, 96)

## TABELAS BANCO-ONLY (API NAO exponhe)

grade (796.228)
  - Notas em texto; NAO em API

period_average (214.672)
  - Medias; NAO em API

attendance (296.054)
  - Frequencia; NAO em API

exam (59.882)
  - Provas; NAO em API

enrollment_record (154.826)
  - Historico acad detalhado; NAO em API

## COBERTURA

Banco (gennera_stg): 2018-2025 completo, 2026 vazio
API Gennera: 2018-2026 ao vivo
Para 2026: USE EXCLUSIVAMENTE API

---

Indices Importantes (ja existem):
- person_fisica(cpf) lookup CPF
- contract(id_person, id_institution) contratos por aluno+filial
- invoice(id_contract) parcelas
- invoice(due_date) relatorios por vencimento
- student_code_unico(id_person, code_unif) RA canonico
- enrollment_record(code_unif, year) historico acad
