# 02 - API Endpoints Gennera

## Autenticacao

Base URL: https://api2.gennera.com.br

Header obrigatorio:
x-access-token: <JWT>

JWT expira em ~24h. Gerado no painel admin.
Mascarar em logs: primeiros 8 + ... + ultimos 4 chars.
Nunca em URL; sempre em header.

---

## Instituicoes

GET /institutions
- Metodo: GET
- Autenticacao: Obrigatorio
- Status: 200
- Retorna: Array de 3 instituicoes (320=UN1, 321=UN2, 873=teste)
- CONFIRMADO (testado 2026-05-14)

---

## Pessoas

GET /institutions/{id}/persons
- Retorna ~9.347 pessoas para UN1
- Inclui CPF, telefone, email, endereco (PII CRITICO)
- CONFIRMADO (testado 2026-05-14)

GET /institutions/{id}/persons/{personId}
- Detalhe individual
- INFERIDO (padrao REST)

---

## Contratos

GET /institutions/{id}/contracts
- UN1: ~11.432 contratos
- UN2: ~3.800 contratos
- Total ativo: ~12.487
- CONFIRMADO (testado 2026-05-14)

GET /institutions/{id}/contracts/{contractId}/detailed
- Retorna: purchases, invoices, recurringPayment, paymentMethods, gatewayTransactions
- CRITICO: recurringPayment NAO esta no banco gennera_stg
- Nota: tentativas recusadas (cod 05, 96) NAO aparecem aqui
- CONFIRMADO (testado 2026-05-14)

GET /institutions/{id}/contracts/{contractId}/invoices
- Parcelas do contrato
- Banco: 99.408 invoices (2018-2025)
- CONFIRMADO (testado 2026-05-14)

---

## Pagamentos

GET /institutions/{id}/payments?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD
- Filtra por paymentDate
- Omite pending com paymentDate futura
- ~18k pagamentos/unidade
- CONFIRMADO (testado 2026-05-14)

GET /institutions/{id}/payments?include=gatewayTransactions
- Retorna TUDO (ativo, cancelado, pending)
- Inclui transacoes gateway (tentativas de cobranca)
- Filtrar localmente por date se precisar periodo
- CONFIRMADO (testado 2026-05-14)

---

## Servicos (Itens)

GET /institutions/{id}/items
- ~349 items/unidade
- Inclui: MENS, ALIM, MAT, REMATRIC, etc.
- CONFIRMADO (testado 2026-05-14)

---

## Endpoints NAO-EXISTENTES ou COM PROBLEMA

GET /institutions/{id}/invoices
- Retorna 422 (Unprocessable Entity)
- Precisa parametro "competencia" obrigatorio (nome desconhecido)
- Workaround: usar /contracts/:id/invoices

GET /transactions - 404
GET /attempts - 404
GET /charges - 404
GET /errors - 404
GET /paymentErrors - 404
GET /failedPayments - 404
GET /cardErrors - 404
GET /defaulters - 404
GET /inadimplencia - 404

Tentativas recusadas ficam so no painel admin (export XLSX).

---

## Rate limits e paginacao

- Nenhum rate limit detectado (testadas 30+ requisicoes)
- Nenhuma paginacao observada (retorna arrays completos)
- Recomendacao: 1 req/seg maximo por cautela

---

## Erros comuns

401 Unauthorized: JWT expirado ou invalido - renovar no painel
404 Not Found: recurso nao existe - validar id
Sem header x-access-token: 401 Unauthorized - adicionar header

---

## Status geral

CONFIRMADOS: 8 endpoints (institutions, persons, contracts, contracts/detailed, contracts/invoices, payments filtro, payments gateway, items)
INFERIDOS: 2 endpoints (person detail, contract individual)
NAO-EXISTENTES: 9 endpoints
COM BUG: 1 endpoint (/invoices param desconhecido)
COBERTURA: ~95% (suficiente para migracao)

