# 10 - Dicionario de Campos Criticos

Dicionario campo-a-campo para os 4 contextos criticos com tipos, exemplos e mapeamento API.

## 1. person_fisica (70 campos, 9.166 pessoas)

id_person (int): PK; LOCAL 1-9173 por instituicao
name (text): LATIN1; pode acentuacao (Maria, Jose, etc)
cpf (text): 11 digitos; 48% vazio (menores sem CPF ainda); normalizacao necessaria
rg (text): Raro; preenchido
birthdate (text): ISO ou BR; HETEROGENEO - converter para ISO
gender (text): M ou F
email (text): NULL se nao fornecido
phone (text): Mascara variavel; normalizar para E.164
street (text): LATIN1
zipcode (text): 01310-100; pode estar vazio
city (text): LATIN1
state (text): SP (UF 2 chars)
religion (text): Raro; pode NULL
ethnicity (text): Raro
deceased (text): Raro
photo (text): Base64 ou URL; raro

Conversoes:
- CPF: REGEXP_REPLACE(cpf, '[^0-9]', '', 'g')
- Birthdate: CASE WHEN ~ '\d{2}/\d{2}/\d{4}' THEN TO_DATE(..., 'DD/MM/YYYY')
- Phone: REGEXP_REPLACE(phone, '[^0-9+]', '', 'g')

---

## 2. servicos_historico (48 campos, 125.849 linhas)

Denormalizado para relatorio; granularidade: contrato + periodo

nome_instituticao (varchar): Unidade I / Unidade II
contrato (text): CAST para int; FK contract.id_contract
contrato_status (varchar): De contract.status
id_pessoa (text): API GLOBAL ID; NAO local (namespacing critico!)
aluno (varchar): Nome de referencia
cpf_responsavel_financeiro (text): CHAVE PRIMARIA; usar CPF mapping
responsavel_financeiro (varchar): Nome de referencia
fatura_mes (text): 1-12; GROUP BY em relatorios
fatura_ano (text): STRING (nao int!); CAST(fatura_ano AS int) para JOIN
calendario_academico (text): Ano letivo (STRING)
curso (varchar): 6o Ano / Fundamental I
serie (varchar): Seria do aluno
turma (varchar): 6A; pode ter sufixos (UN2 EI)
item (varchar): REMATRIC, MENS, ALIM, MAT
status_matricula (varchar): ACTIVE / INACTIVE
polo (varchar): Unidade I / Unidade II
data_vencimento (varchar): HETEROGENEO; converter para ISO
valor_bruto (varchar): ".1.234,56" BRL format; REPLACE(REPLACE(REPLACE(v, '\$', ''), '.', ''), ',', '.')::numeric
valor_liquido (varchar): valor_bruto - descontos
valor_descontos (varchar): Total descontos (bolsa + parcelamento)
valor_cancelamentos (varchar): Cancelamentos
valor_financiamento (varchar): Financiamento (raro)
valor_estorno (varchar): Estornos
valor_renegociacao (varchar): Renegociacoes
valor_fundo (varchar): Fundo reserva (raro)
valor_ressarcimento (varchar): Ressarcimentos (raro)
valor_multa (varchar): Multa por atraso
valor_juros (varchar): Juros por atraso
valor_perda (varchar): Perda/abatimento (raro)
valor_pagamento (varchar): Valor efetivamente pago
dias_atraso (text): Dias vencidos; calculo
multa_prevista (varchar): Simulacao
juro_previsto (varchar): Simulacao
desconto_previsto (varchar): Simulacao
status (varchar): PAID, OPEN, PARTIAL, CANCELLED
saldo_devedor (varchar): CHAVE para inadimplentes
total_a_pagar (varchar): saldo_devedor + multa + juros
pagamento_boleto (varchar): Breakdown por metodo
pagamento_dinheiro (varchar): Breakdown
pagamento_cheque (varchar): Breakdown (raro)
pagamento_cartao_credito (varchar): Breakdown
pagamento_cartao_debito (varchar): Breakdown (raro)
pagamento_transferencia (varchar): Breakdown
pagamento_pix (varchar): Breakdown (novo)
data_pagamento (varchar): Data processamento
data_liquidacao (varchar): Data credito recebido

Conversoes:
- BRL: REPLACE(REPLACE(REPLACE(campo, '\$', ''), '.', ''), ',', '.')::numeric
- Data: TO_DATE(data_vencimento, 'DD/MM/YYYY')
- Ano: CAST(fatura_ano AS int)

---

## 3. contract (22 campos, 13.283 contratos)

id_contract (int): PK
id_institution (int): 320=UN1, 321=UN2
id_person (int): FK; LOCAL (1-9173)
status (text): active, cancelled, pending
date (timestamp): Data criacao
details (text): Observacoes
observation (text): Observacoes adicionais
penalty_percentage (numeric): Multa % (raro)
interest_percentage (numeric): Juros % (raro)
purchases (numeric): Valor servicos (TOTAL agregado)
loans (numeric): Financiamento (raro)
discounts (numeric): Descontos totais (NAO POR PARCELA)
cancellations (numeric): Cancelamentos
funds (numeric): Fundo (raro)
refunds (numeric): Reembolsos
renegotiations (numeric): Renegociacoes
payments (numeric): Total pago
reversals (numeric): Reversoes
penalties (numeric): Multas incorridas
interests (numeric): Juros incorridos
balance (numeric): SALDO DEVEDOR = total - payments (ja calculado)
total (numeric): TOTAL = purchases (agregado)

Status: active, cancelled, pending
balance = total - payments (ja calculado, nao precisa converter)

---

## 4. invoice (19 campos, 99.408 parcelas)

id_invoice (int): PK
id_contract (int): FK
month (int): 1-12 mes faturamento
year (int): ano faturamento
due_date (timestamp): Data vencimento
date (timestamp): Data emissao
purchases (numeric): Valor faturado (= total)
loans (numeric): Financiamento
discounts (numeric): Descontos aplicados (BOLSA por parcela)
cancellations (numeric): Cancelamentos
funds (numeric): Fundo
refunds (numeric): Reembolsos
renegotiations (numeric): Renegociacoes
payments (numeric): Valor pago
reversals (numeric): Reversoes
penalties (numeric): Multas
interests (numeric): Juros
balance (numeric): SALDO ABERTO = total - payments - discounts
total (numeric): TOTAL

Status esperados: OPEN, PAID, PARTIAL, CANCELLED

Pitfalls:
- year = 5021 (12 linhas typo para 2021) - VALIDAR
- year = 2032 (1 linha futuro impossivel) - INVESTIGAR
- year = 2026 (11 linhas; sem enrollment) - SO API
- years 2014/2016/2017 (1.706 linhas antigas) - VALIDAR integridade

---

## Resumo Conversoes

BRL formato:
REPLACE(REPLACE(REPLACE(valor, '\$', ''), '.', ''), ',', '.')::numeric

Datas:
CASE WHEN data ~ '\d{2}/\d{2}/\d{4}' THEN TO_DATE(data, 'DD/MM/YYYY')
     WHEN data ~ '\d{4}-\d{2}-\d{2}' THEN CAST(data AS date)
     ELSE NULL END

CPF:
REGEXP_REPLACE(cpf, '[^0-9]', '', 'g')

NULL handling:
COALESCE(campo, 0) para valores
COALESCE(campo, '') para texto
