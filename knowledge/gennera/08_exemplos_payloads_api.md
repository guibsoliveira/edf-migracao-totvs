# 08 - Exemplos de Payloads API Gennera

Exemplos COMPLETOS de chamadas API com requests reais e responses anonimizadas.

## Autenticacao

Base URL: https://api2.gennera.com.br
Header: x-access-token: eyJ0eXAi...XXXX (JWT mascarado, 24h)

## 1. GET /institutions

Listar instituicoes (UN1, 320), (UN2, 321), (Teste, 873).

Request:
```bash
curl -X GET https://api2.gennera.com.br/institutions \
  -H 'x-access-token: eyJ0eXAi...XXXX'
```

Response (200 OK):
```
id: 320, name: Unidade I
id: 321, name: Unidade II
id: 873, name: Teste
```

## 2. GET /institutions/{id}/persons

Listar pessoas (9.347 em UN1).

Request:
```bash
curl -X GET https://api2.gennera.com.br/institutions/320/persons \
  -H 'x-access-token: eyJ0eXAi...XXXX'
```

Response array com: id (355k-3M global), name, cpf, birthDate, studentCode (RA YYYYNNNNNN)

## 3. GET /institutions/{id}/contracts

Listar contratos (11.432 em UN1).

Request:
```bash
curl -X GET https://api2.gennera.com.br/institutions/320/contracts \
  -H 'x-access-token: eyJ0eXAi...XXXX'
```

Response array com: id, personId, itemName (MENS/ALIM/MAT/REMATRIC), total, balance, status

## 4. GET /institutions/{id}/contracts/{contractId}/detailed

Contrato detalhado (invoices, recurringPayment, gatewayTransactions).

Key fields:
- recurringPayment: active, retryCount, maxRetries, lastCharge (NAO no banco)
- gatewayTransactions: array com transacoes (SO resultado FINAL)
- invoices: array de parcelas

## 5. GET /institutions/{id}/contracts/{contractId}/invoices

Faturas/parcelas de contrato.

Response array: id, month, year, dueDate, total, balance, status (OPEN/PAID)

## 6. GET /institutions/{id}/payments

Pagamentos por intervalo (filtra por paymentDate, NAO vencimento).

Request:
```bash
curl -X GET 'https://api2.gennera.com.br/institutions/320/payments?startDate=2026-01-01&endDate=2026-05-19' \
  -H 'x-access-token: eyJ0eXAi...XXXX'
```

Response: id, amount, paymentDate, status (PAID/PENDING), method (CREDIT_CARD/BOLETO)

## 7. GET /institutions/{id}/items

Servicos (349 em UN1): REMATRIC, MENS, ALIM, MAT.

## Node.js Snippet

```javascript
const https = require('https');
const fs = require('fs');

class GeneraAPI {
  constructor(token) {
    this.token = token;
    this.baseURL = 'api2.gennera.com.br';
  }

  async request(method, path, params = null) {
    return new Promise((resolve, reject) => {
      const options = {
        hostname: this.baseURL,
        port: 443,
        path: params ? path + '?' + new URLSearchParams(params).toString() : path,
        method: method,
        headers: {
          'x-access-token': this.token,
          'Accept': 'application/json'
        }
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          resolve(JSON.parse(data));
        });
      });

      req.on('error', reject);
      req.end();
    });
  }

  async getContracts(institutionId) {
    return this.request('GET', '/institutions/' + institutionId + '/contracts');
  }

  async getContractDetailed(institutionId, contractId) {
    return this.request('GET', '/institutions/' + institutionId + '/contracts/' + contractId + '/detailed');
  }

  async getPayments(institutionId, startDate, endDate) {
    return this.request('GET', '/institutions/' + institutionId + '/payments', {
      startDate: startDate,
      endDate: endDate
    });
  }
}

// Uso
async function main() {
  const token = fs.readFileSync('/c/Users/Guilherme/AppData/Local/Temp/_gen_token', 'utf-8').trim();
  const api = new GeneraAPI(token);

  const contracts = await api.getContracts(320);
  console.log('Contratos:', contracts.length);

  const detail = await api.getContractDetailed(320, 7572);
  console.log('Saldo:', detail.balance);
}

main().catch(console.error);
```

## Mascaramento de Logs

Nunca logar token completo. Mascarar como: eyJ0eXAi...XXXX
