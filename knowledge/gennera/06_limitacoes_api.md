# 06 - Limitacoes da API Gennera

## 1. Tentativas Recusadas NAO Sao Expostas

### Problema CRITICO

Quando uma cobranca recorrente falha (cartao recusado, limite excedido, etc.), a tentativa eh registrada NO GATEWAY (PJBank) e no painel admin do Gennera, MAS NAO aparece via API REST.

### Codigos de Resultado que Desaparecem
- 05: Limite de credito excedido
- 96: Erro no processamento
- Outros: Falhas de comunicacao com bandeira

### Onde aparecem
- Painel admin Gennera: Menu "Erros de Pagamento" (visao do operador)
- Gateway PJBank: Logs internos
- API REST: NAO APARECEM

### Impacto na Migracao

Se for preciso rastrear por que uma cobranca falhou:
- Nao consegue via API
- Precisa exportar XLSX do painel admin
- Ou implementar webhook customizado (contatar Gennera)

### Workaround
```bash
# 1. Acessar painel admin: https://api2.gennera.com.br/admin
# 2. Menu: Relatorios > Erros de Pagamento
# 3. Filtrar por periodo
# 4. Exportar XLSX
# 5. Processar localmente
```

---

## 2. GET /institutions/{id}/invoices Precisa Parametro Desconhecido

### Problema

Endpoint `/institutions/{id}/invoices` retorna 422 (Unprocessable Entity).

### Erro Observado
```
POST /institutions/320/invoices HTTP/1.1
Response: 422 Unprocessable Entity
{
  "error": "Required parameter missing: competencia"
}
```

### Parametro Desconhecido
Nome exato do parametro NAO foi descoberto:
- `competencia`? (em PT-BR: mes/ano de faturamento)
- `period`?
- `month` e `year` separados?
- Formato esperado: "2025/01"? "2025-01"? "01"?

### Workaround
Usar endpoint alternativo:
```
GET /institutions/{id}/contracts/{contractId}/invoices
```

Esse retorna TODAS as parcelas do contrato, entao eh necessario iterar sobre contracts.

Ou: Contatar suporte Gennera para documentacao do parametro de competencia.

---

## 3. Sem Paginacao (Todos os Endpoints)

### Problema

Nenhum endpoint observado suporta paginacao (limit, offset, page, pageSize, etc.).

### Implicacao

- GET /institutions/{id}/persons: Retorna ~9.347 pessoas EM UMA REQUISICAO
- GET /institutions/{id}/contracts: Retorna ~11.432 contratos EM UMA REQUISICAO
- GET /institutions/{id}/payments?include=gatewayTransactions: Retorna TUDO incluindo pendentes

### Risco de Performance

- Request pode exceder 30 segundos
- Response payload pode exceder 100 MB
- Cliente HTTP pode timeout

### Recomendacoes

1. Use timeout agressivo: `curl --connect-timeout 60 --max-time 120`
2. Considere rate limiting local: 1 requisicao a cada 2-5 segundos
3. Armazene resposta em disco se muito grande
4. Contatar suporte Gennera para implementacao de paginacao em API v2

### Alternativa

Se performance for bloqueador:
- Importar dados em lote usando arquivo CSV/XML da Gennera (se houver export mensal)
- Usar cron job noturno para sincronizar dados ao inves de queries ad-hoc

---

## 4. Rate Limits NAO Detectados (Mas Presumivelmente Existem)

### Observacao

Testadas 30+ requisicoes sucessivas sem throttling observado.

### Presumpcao

Gennera provavelmente tem rate limits silenciosos:
- Por IP
- Por token JWT
- Por endpoint

Que aparecem quando escalas realistas sao atingidas.

### Recomendacoes

1. Implementar backoff exponencial em scripts
2. Usar rate limiter local: 1 requisicao/seg maximo
3. Validar com suporte Gennera antes de fazer sync em massa

---

## 5. Estrutura recurringPayment Nao Guarda Historico

### Problema

Campo `recurringPayment.lastCharge` SO guarda TIMESTAMP da ultima tentativa.

Nao inclui:
- Data/resultado da 1a tentativa
- Data/resultado da 2a tentativa
- Sequencia de tentativas

### Exemplo

Cobranca com 3 tentativas (2 falhas, 1 sucesso):
- 1a tentativa (2025-01-15): recusado (limite excedido)
- 2a tentativa (2025-01-22): recusado (problema comunicacao)
- 3a tentativa (2025-01-29): SUCESSO

API retorna:
```json
{
  "recurringPayment": {
    "active": false,
    "retryCount": 3,
    "maxRetries": 3,
    "lastCharge": "2025-01-29T10:30:00Z"
  }
}
```

Dados das 2 falhas: PERDIDOS.

### Impacto

Se precisar relatorio "quantas vezes tentamos cobrar este cliente":
- Consegue quantidade total (retryCount)
- Mas nao consegue datas/motivos das falhas anteriores

### Workaround

1. Armazenar localmente cada estado de recurringPayment em tabela de auditoria
2. Consultar painel admin > Erros de Pagamento para detalhes de falhas
3. Implementar webhook se disponivel (contatar Gennera)

---

## 6. gatewayTransactions SO Inclui Resultado Final

### Problema

Campo `gatewayTransactions` na resposta de GET /contracts/{id}/detailed retorna array com transacoes, MAS:
- SO inclui transacao FINAL
- Nao inclui tentativas intermediarias recusadas

### Exemplo

Transacao que teve 3 tentativas no gateway:
- 1a tentativa: recusado
- 2a tentativa: recusado
- 3a tentativa: processada (sucesso ou cancelamento final)

API retorna: SO a 3a (se sucesso) ou 1a (se cancelada).
Tentativas intermediarias: DESAPARECIDAS.

### Diferenca com recurringPayment

- `recurringPayment.retryCount`: Sabe que teve 3 tentativas
- `gatewayTransactions`: So ve resultado final
- Historico detalhado: NAO DISPONIVEL

---

## 7. Filtro de Data em GET /payments com startDate/endDate

### Comportamento

```
GET /institutions/{id}/payments?startDate=2025-01-01&endDate=2025-01-31
```

Filtra por `paymentDate` (data de processamento), NAO data de vencimento ou emissao.

### Implicacao

- Boleto emitido em 2024-12-15 com vencimento 2025-01-15 e pago em 2025-01-15: INCLUSO
- Boleto emitido em 2025-01-01 com vencimento 2025-01-15 e pago em 2025-02-01: EXCLUIDO (pago fora do periodo)

### Pendentes Futuros

Boletos com `paymentDate` no futuro (ex: agendado para 2025-02-15):
- Quando usam `?startDate/endDate`: OMITIDOS
- Quando usam `?include=gatewayTransactions`: INCLUSOS

Necessario filtrar localmente por `status=pending` e `date` se quiser pegar pendentes.

---

## 8. Nenhum Endpoint para Transacoes de Erro Diretamente

### Endpoints NAO-EXISTENTES

| Endpoint | Motivo |
|----------|--------|
| GET /transactions | Nao existe (use /payments) |
| GET /attempts | Nao existe (use /payments + admin) |
| GET /charges | Nao existe (use /invoices) |
| GET /errors | Nao existe (use admin panel) |
| GET /paymentErrors | Nao existe (use admin panel) |
| GET /failedPayments | Nao existe (use admin panel) |
| GET /cardErrors | Nao existe (use admin panel) |
| GET /defaulters | Nao existe (use admin) |
| GET /inadimplencia | Nao existe (use admin) |

### Workaround

Todos os "erros" e "falhas" ficam no painel admin:
- Menu: Relatorios > Erros de Pagamento
- Export: XLSX manual

---

## 9. Sem Suporte para Filtro de Status em GET /payments

### Observacao

```
GET /institutions/{id}/payments?status=paid
```

NAO funciona (ou nao retorna resultado diferente).

### Workaround

1. Buscar TODOS os pagamentos
2. Filtrar localmente por status em aplicacao

---

## 10. Sem Suporte para Filtro de Bandeira ou Metodo de Pagamento

### Problema

Nao consegue retornar SO pagamentos com cartao de credito, ou SO Visa, etc.

### Workaround

1. Buscar todos os payments
2. Filtrar localmente por `payment_method` / `card_brand`

---

## 11. Sem Sincronizacao em Tempo Real

### Observacao

Dados da API podem estar em cache (delay desconhecido).

### Recomendacao

Nao assumir que mudanca em painel admin apareca imediatamente na API.

Testar com intervalo de 5-10 minutos antes de investigar "porque nao apareceu".

---

## 12. HTTPS Obrigatorio, Sem Fallback HTTP

### Observacao

Todos os endpoints exigem HTTPS.

Certificado SSL eh valido (cloudtotvs, nao auto-assinado).

### Implicacao

NAO usar `--insecure` ou `rejectUnauthorized: false` em requests.

Se houver erro SSL, problema eh conexao ou certificado local (nao endpoint).

---

## 13. Sem WebSocket ou Server-Sent Events

### Observacao

API eh REST puro (request-response).

Sem suporte para updates em tempo real.

### Implicacao

Para manter dados sincronizados:
- Polling a cada N minutos (recomendacao: 15-30 min)
- Ou webhook customizado (contatar Gennera se disponivel)

---

## 14. Sem Suporte para Batch Requests

### Problema

Nao consegue fazer:
```
POST /institutions/320/contracts/batch?ids=7572,7573,7574
```

Precisa fazer requests individuais:
```
GET /institutions/320/contracts/7572
GET /institutions/320/contracts/7573
GET /institutions/320/contracts/7574
```

### Implicacao

Se tiver 11k contratos, vai dar 11k requests (lento).

### Recomendacao

Cache resultados em banco local (gennera_stg).

Atualizar via cron job noturno, nao ad-hoc.

---

## 15. Sem Suporte para Expand/Include de Relacionamentos Aninhados

### Observacao

```
GET /institutions/320/contracts?include=invoices,payments
```

NAO funciona (ou nao faz nada).

Precisa fazer requests separados.

### Implicacao

Para cada contrato, fazer request separado para invoices e payments.

11k contratos * 2 sub-requests = 33k requests (muitoooooo lento).

### Recomendacao

Usar `/institutions/{id}/contracts/{id}/detailed` que já inclui tudo.

Ou: Cache + cron job noturno.

---

## 16. Sem Auditoria de Acessos via API

### Observacao

Nao ha endpoint para listar "quem acessou quais dados quando".

### Implicacao

LGPD: Se alguém acessar dados de um aluno, nao consegue auditar quem foi.

### Recomendacao

1. Logar todos os requests localmente (incluindo JWT + IP + timestamp)
2. Manter logs por 6 meses minimo
3. Notificar Guilherme se suspeitar de acesso nao-autorizado

---

## Resumo de Gaps Identificados

| Gap | Severidade | Impacto | Workaround |
|-----|-----------|--------|-----------|
| Tentativas recusadas NAO expostas | CRITICO | Nao consegue rastrear erros de cobranca | Export admin XLSX |
| /invoices precisa parametro desconhecido | MEDIO | Nao consegue listar faturas por competencia | Usar /contracts/{id}/invoices |
| Sem paginacao | MEDIO | Requests lentos para grandes volumes | Cache + polling noturno |
| recurringPayment sem historico | BAIXO | Nao sabe detalhes de tentativas intermediarias | Armazenar localmente + admin |
| gatewayTransactions SO resultado final | BAIXO | Nao ve tentativas intermediarias | Admin panel |
| Sem suporte para filtros (status, bandeira) | BAIXO | Precisa filtrar localmente | Aplicacao cliente |
| Sem batch requests | MEDIO | 11k requests = lento | Cache + cron noturno |
| Sem auditoria de acessos | MEDIO | LGPD: nao consegue rastrear quem viu o quê | Log local + notificacao |
