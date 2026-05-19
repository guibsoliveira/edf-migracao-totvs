# 11 - Scripts de Extracao Node.js

Scripts prontos para extrair em batch da API live com pool de conexoes e retry.

## 1. API Client Basico

Arquivo: api_client.js

Wrapper reutilizavel para requisicoes da API Gennera com retry exponencial.

Parametros do construtor:
- jwtToken: token JWT (ler de C:/Users/Guilherme/AppData/Local/Temp/_gen_token)
- maxRetries: 3 (default)
- retryDelay: 1000ms (exponencial)

Metodos principais:
- getPersons(institutionId)
- getContracts(institutionId)
- getContractDetailed(institutionId, contractId)
- getPayments(institutionId, startDate, endDate)
- request(method, path, params)

Tratamento de erros:
- 401 Unauthorized: JWT expirado - renovar token
- 404 Not Found: ID invalido
- 422 Unprocessable Entity: parametro obrigatorio faltando
- 500: Erro servidor - retry automatico

Timeout: 30s por requisicao

---

## 2. Script Varrer Pessoas

Arquivo: script_pessoas.js

Proposito: Paginar e armazenar TODAS pessoas de uma instituicao

Procedimento:
1. Ler JWT de /c/Users/Guilherme/AppData/Local/Temp/_gen_token
2. Para cada instituicao (320, 321):
   a. Chamar api.getPersons(institutionId)
   b. Salvar em data/exportacoes/AAAA-MM-DD/pessoas_{institutionId}.json
   c. Log: quantidade de pessoas

Output esperado:
- data/exportacoes/2026-05-19/pessoas_320.json (9.347 pessoas)
- data/exportacoes/2026-05-19/pessoas_321.json (X pessoas)

Como rodar:
node script_pessoas.js

---

## 3. Script Contratos com Detalhado (Pool)

Arquivo: script_contratos_detailed.js

Proposito: Pegar TODOS contratos com detalhado (invoices, pagamentos, recurringPayment)

Pool de 10 requisicoes simultaneas com retry e rate limiting

Procedimento:
1. Chamar api.getContracts(institutionId) para lista plana
2. Para cada contract ID:
   a. Agendar task em pool: api.getContractDetailed(inst, contractId)
   b. Pool executa ate 10 simultaneas
   c. Salvar resultado no array
3. Escrever JSON com todos os detailed

Output esperado:
- data/exportacoes/2026-05-19/contratos_320.json (11.432 contratos)
- Cada contrato contem: invoices[], recurringPayment{}, gatewayTransactions[]

Tempo estimado: 30-60 minutos (11k contratos * 1-2s com pool 10)

Monitoramento:
- Log a cada 100 processados
- Log de erros com contract ID
- Total success/failed ao final

Como rodar:
node script_contratos_detailed.js

---

## 4. Script Pagamentos por Periodo

Arquivo: script_pagamentos.js

Proposito: Extrair pagamentos de um periodo especifico

Procedimento:
1. Definir startDate, endDate (ISO YYYY-MM-DD)
2. Para cada instituicao (320, 321):
   a. Chamar api.getPayments(inst, startDate, endDate)
   b. Salvar em data/exportacoes/AAAA-MM-DD/pagamentos_{institutionId}.json

Nota importante:
- Filtro usa paymentDate (data processamento), NAO data vencimento
- Se usar include=gatewayTransactions na request, retorna TODOS (sem filtro data)
- Neste script, usar com data range para ter subset managavel

Output esperado:
- data/exportacoes/2026-05-19/pagamentos_320.json (18k pagamentos aprox)
- Cada payment: id, amount, paymentDate, status, method

Como rodar:
node script_pagamentos.js

---

## 5. Script Validacao Drift (Banco vs API)

Arquivo: script_validacao_drift.js

Proposito: Comparar banco local com API live para detectar divergencias

Procedimento:
1. Conectar a PostgreSQL em 192.168.1.91:5432
2. Chamar API para pessoas, contratos, pagamentos
3. Comparar contagens:
   - SELECT COUNT(*) FROM person_fisica
   - SELECT COUNT(*) FROM contract
   - SELECT COUNT(*) FROM invoice
   - vs API responses
4. Gerar relatorio de divergencias

Queries SQL:
```
PGCLIENTENCODING=LATIN1 PGPASSWORD="$DB_PASS" psql -h $DB_HOST -U $DB_USER -d Edf_bd_legado
# Credenciais em CLAUDE.local.md (gitignored)
SELECT COUNT(*) FROM gennera_stg.person_fisica;
SELECT COUNT(*) FROM gennera_stg.contract WHERE id_institution = 320;
SELECT COUNT(*) FROM gennera_stg.invoice WHERE year IN (2024, 2025);
```

Output:
- arquivo: data/exportacoes/AAAA-MM-DD/validacao_drift.txt
- Formato: Pessoas/Contratos/Invoices/Pagamentos: API=X DB=Y Status=OK/DIVERGENCIA

Como rodar:
npm install pg
node script_validacao_drift.js

---

## 6. Estrutura de Saida

Todos JSONs e logs em data/exportacoes/AAAA-MM-DD/ (gitignored, contem PII)

Arquivos tipicos:
- pessoas_320.json (9.347 pessoas - CPF/email/endereco)
- pessoas_321.json (X pessoas)
- contratos_320.json (11.432 contratos com detalhe completo)
- contratos_321.json (X contratos)
- pagamentos_320.json (18k pagamentos aprox)
- pagamentos_321.json (X pagamentos)
- validacao_drift.txt (relatorio comparativo)

Apagar apos auditoria (dentro de 30 dias per SECURITY.md).
Use cipher /w:caminho no Windows para apagamento seguro.

---

## 7. Mascaramento em Logs

Nunca logar:
- JWT completo: mascarar como eyJ0eXAi...XXXX (primeiros 8 + ... + ultimos 4)
- CPF individual: mascarar como XXX.XXX.XXX-XX (no log)
- Nome aluno: trocar por STUDENT_N ou ALUNO_1234

Permitido logar:
- Quantidade de registros (9.347 pessoas, 11.432 contratos)
- IDs genericos (contract ID 7572 ok; mas nao com CPF junto)
- Status de processamento (success/failed counters)

---

## 8. Configuracoes Recomendadas

Pool size: 10 (conservador; pode aumentar para 20 se servidor aguenta)
Retry attempts: 3
Retry delay: 1000ms exponencial (1s, 2s, 4s)
Request timeout: 30s
Rate limit local: 1 requisicao/2s entre batches

JWT renewal: Check token expiration apos 20h de execucao

---

## 9. Notas Criticas

1. JWT expira em 24h. Se script rodar > 24h, renovar token em CLAUDE.local.md
2. API NAO tem paginacao - retorna tudo em 1 request (pode ser lento ~30-120s)
3. Tentativas recusadas (cod 05, 96) NAO aparecem na API - usar painel admin export XLSX
4. Dados 2026 SO estao na API, nao no banco local
5. recurringPayment NAO existe no banco - guardar em auditoria local
6. NUNCA commitar JSONs com PII - apagar apos uso
7. Diff entre banco local (id_person 1-9173) e API (id 355k-3M) - usar CPF como chave
8. servicos_historico.contrato eh TEXT - CAST para int para JOIN com contract

---

## 10. Dependencias NPM

npm install pg (para conexao PostgreSQL)
npm install dotenv (para variaves .env, opcional)

Node.js: v14+ (async/await nativo)

