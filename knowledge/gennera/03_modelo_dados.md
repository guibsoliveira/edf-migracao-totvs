# 03 - Modelo de Dados Gennera

## Schema: gennera_stg (PostgreSQL 18)

Encoding: LATIN1 (OBRIGATORIO usar PGCLIENTENCODING=LATIN1)
57 tabelas mapeadas (inclui views e tabelas de auditoria)
Periodo: 2018-2025 (cutoff dezembro/2025; 2026 vazio no banco)

---

## PESSOAS (5 tabelas principais)

### person (tabela raiz)
- PK: id_person (int)
- Linhas: 9.166+
- Campos: id_person, person_type (student/responsible/other)
- Proposito: Mestre de todas as pessoas
- Nota: Sem outro dado aqui; tudo em person_fisica/juridica

### person_fisica
- PK: id_person (int, FK -> person)
- Linhas: 9.166
- Campos criticos: id_person, name, cpf, email, birthdate, gender, address
- Pitfall: 4.389 SEM CPF (48%); 752 com codcfo (8.2%); LATIN1 word boundary quebra
- LGPD: Contém CPF, telefone, endereco de menores (CRITICO)

### person_juridica
- PK: id_person (int, FK -> person)
- Linhas: 8
- Campos: id_person, cnpj, legal_name, representative, address
- Uso: Raro; aproximadamente 5 contratos podem ser PJ

### person_cpf_mapping
- PK: cpf (composite)
- Linhas: 5.310
- Campos: cpf, name_norm, id_person_principal, id_person_todos (array JSON)
- Proposito: Dedup por CPF
- Pitfall: 8% com cpf_temporario=true

### cliente_fornecedor
- PK: codcfo (int)
- Linhas: 1.510
- Proposito: Snapshot FCFO do TOTVS

---

## ACADEMICO (11 tabelas)

### enrollment
- PK: id_enrollment (int)
- Linhas: 3.290
- Periodo: 2021-2025 (2026 VAZIO)
- FK: id_institution, id_person, id_academic_responsible, id_financial_responsible
- Proposito: Matriculas

### student_code_unico
- PK: id_person + source
- Linhas: 2.389
- IMPORTANTE: code_unif em formato YYYYNNNNNN (RA CANONICO)
- Fonte unica da verdade para RA

### enrollment_record
- Linhas: 154.826
- Granularidade: aluno + disciplina + periodo
- Proposito: Historico academico detalhado

### class
- PK: id_class (int)
- Linhas: 7.447
- Pitfall: UN2 EI tem sufixos (IA=integral, MB=manha, TC=tarde)

### academic
- PK: id_academic (int)
- Linhas: 770
- CRITICO: subject_code_gennera (numero) != subject_code TOTVS (4 chars)

---

## AVALIACAO (4 tabelas)

### grade
- Linhas: 796.228
- Notas em texto ("8.5", "A", "---")

### period_average
- Linhas: 214.672

### attendance
- Linhas: 296.054

### exam
- Linhas: 59.882

---

## FINANCEIRO (8 tabelas CRITICAS)

### servicos_historico
- Linhas: 125.849
- Campos: 48 (denormalizados)
- Granularidade: contrato + periodo
- MESTRE para reconciliacao
- Pitfall: valores BRL ".234,56" requerem conversao
- Pitfall: 662 linhas 2026 SEM enrollment
- Pitfall: 2018-2019 com id_pessoa='' (vazio)

### contract
- PK: id_contract (int)
- Linhas: 13.283 (12.487 ativos, 796 cancelados)
- FK: id_institution, id_person
- 1 aluno pode ter multiplos contratos (REMATRIC, MENS, ALIM, MAT)

### invoice
- PK: id_invoice (int)
- Linhas: 99.408
- FK: id_contract
- Pitfall: 10.490 com saldo > 0 (aberto)
- Pitfall: 12 com year=5021 (typo)
- Proposito: Parcelas/boletos

### servicos
- Linhas: 545
- UNICA fonte de desconto por parcela

### enrollment_contract
- Linhas: 23.476
- Ponte matricula <-> contrato (1:N)

### payment
- PK: id_payment (int)
- Linhas: 63.266
- Status: paid/cancelled/pending

### invoice_payment
- Ponte invoice <-> payment (N:M)

---

## TABELAS NA API MAS NAO NO BANCO

### recurringPayment
- Campos: active, retryCount, maxRetries, lastCharge
- Localizacao: GET /contracts/:id/detailed
- Banco: NAO EXISTE
- Proposito: Rastreamento de cobranças recorrentes (cartao com retry)

### gatewayTransactions
- Campos: id, attemptNumber, status, resultCode, resultMessage, chargeDate
- Localizacao: GET /contracts/:id/detailed
- Banco: NAO EXISTE
- Proposito: Historico de tentativas no gateway PJBank
- Pitfall: So guarda transacao FINAL, nao recusadas (codigo 05, 96)

---

## DIAGRAMA DE RELACIONAMENTOS

enrollment -> enrollment_record (detalhe acad)
enrollment -> enrollment_contract -> contract
contract -> invoice -> invoice_payment -> payment
contract -> servicos (detalhe bolsa)
person_fisica -> student_code_unico (RA)
person_fisica -> grade, attendance, payment

---

## ENCODING E CONVERSOES

LATIN1 em postgres -> UTF-8 em memoria/TOTVS
Valores BRL: ".234,56" -> conversao + formato BR
Datas: heterogeneas (BR vs ISO)
CPF: normalizacao necessaria
Notas: texto -> numeric + classificacao
