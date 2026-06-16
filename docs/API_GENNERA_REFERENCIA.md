# API Gennera — Referência completa

**Auditado:** 2026-06-10 (em produção live, `mode=prod`)
**Para:** consumo direto do `api2.gennera.com.br`
**Tipo:** REST sobre HTTPS, retorno JSON

---

## 1. Autenticação

- **Host:** `api2.gennera.com.br` (HTTPS 443)
- **Mecanismo:** header `x-access-token: <JWT>`
- **User de sistema atual:** `api@escoladofuturo.com.br`
  - `idUser`: 13512105
  - `idCustomer`: 1592
  - `mode`: prod
- **Expiração:** o JWT atual **não tem campo `exp`** — fica válido até o servidor invalidar manualmente.
- **Sem token / token errado:** todo endpoint REST retorna **HTTP 401**.
- **Hash de usuário** (em `CLAUDE.local.md`, gitignored) sozinho **NÃO autentica** — precisa do JWT completo.

### Como obter um JWT novo (quando expirar)

1. Painel admin Gennera (logado como user com permissão API), F12 → Network
2. Faz qualquer ação que dispare request REST
3. Copia o valor do header `x-access-token` de alguma request
4. Salva em arquivo local seguro (não commitar)

---

## 2. Identificadores canônicos

### 2.1 Instituições (`/institutions`)

| `idInstitution` | Nome | Uso |
|---|---|---|
| 320 | Escola do Futuro - Unidade 1 | UN1 (EF1 3-5, EF2, EM) |
| 321 | Escola do Futuro - Unidade 2 | UN2 (EI, EF1 1-2) |
| 873 | EDF - Base de Testes | testes |

### 2.2 Calendários acadêmicos por instituição (`/institutions/{inst}/academicCalendars`)

**⚠️ Importante:** UN1 e UN2 têm IDs DIFERENTES para o mesmo ano. Não hardcode — descubra em runtime.

| Ano | UN1 (320) | UN2 (321) |
|---|---|---|
| 2021 | 3013 | 3014 |
| 2022 | 4009 | 4198 |
| 2023 | 5544 | 5922 |
| 2024 | 7356 | 7525 |
| 2025 | 8804 | 8796 |
| 2026 | 9622 | 9624 |

### 2.3 Gateway PJBank (no Gennera)

- `idGateway` = 315
- `idAccount` 478 = PJBank UN1
- `idAccount` 479 = PJBank UN2
- Status de payment possíveis: `paid`, `cancelled`, `pending`
- ⚠️ Tentativas recusadas pelo emissor (cod 05, 96) **não** aparecem via REST — só no painel admin Gennera

---

## 3. Endpoints REST confirmados (que retornam JSON)

Todos com header `x-access-token: <JWT>`. Resposta sempre `application/json`.

### 3.1 `GET /institutions`

Lista as 3 instituições do customer.

```json
[
  {"idInstitution": 320, "name": "Escola do Futuro - Unidade 1", ...},
  {"idInstitution": 321, "name": "Escola do Futuro - Unidade 2", ...},
  {"idInstitution": 873, "name": "EDF - Base de Testes", ...}
]
```

### 3.2 `GET /institutions/{idInst}/persons`

Lista TODAS as 9.347 pessoas (alunos, profs, responsáveis, staff). **Base única compartilhada entre UN1 e UN2** — `/institutions/320/persons` retorna IGUAL a `/institutions/321/persons`.

Campos relevantes por pessoa:

```json
{
  "idPerson": 356300,
  "idCustomer": 1592,
  "idPersonType": 1,
  "idUser": 170057,
  "active": true,
  "profiles": [{"idProfile": 1, "profile": "Professor"}],
  "name": "Luiz Claudio Barbosa Stopa",
  "cpf": "60171049934",
  "rg": "148202524",
  "email": "lstopa@edf.pro.br",
  "gender": "Masculino",
  "birthdate": "1965-04-15",
  "birthState": "SP",
  "birthplace": "São Paulo",
  "city": "Santana de Parnaíba",
  "state": "SP",
  "street": "...",
  "zipcode": "...",
  "nationality": "Brasileira",
  "civilStatus": "Casado",
  "telephoneNumber": "...",
  "mobilePhoneNumber": "...",
  "createdAt": null,
  "updatedAt": null
}
```

**Profile types observados:**

| `profile` | Quantidade UN1 |
|---|---|
| (vazio) | 6.632 (provavelmente responsáveis/pais) |
| Student | 2.484 |
| Professor | 191 (cadastros — não é critério de "professor ativo") |
| Funcionário | 33 |
| Institution | 3 |
| Funcionário+Professor | 2 |
| Professor+Funcionário | 1 |
| Student+Professor | 1 |

⚠️ **Filtro `?type=teacher` e `?role=teacher` são IGNORADOS** — retornam o array completo. Filtrar client-side por `profiles[]`.

### 3.3 `GET /institutions/{idInst}/academicCalendars`

```json
[
  {"idAcademicCalendar": 3013, "name": "2021", "code": "2021",
   "startDate": "2021-01-01T03:00:00.000Z", "endDate": "2021-12-31T03:00:00.000Z"}
]
```

### 3.4 `GET /institutions/{idInst}/academicCalendars/{idCal}/professors`

**Professores ATIVOS no calendário** (este é o critério canônico — não a flag `Professor` em `/persons`).

```json
[
  {
    "idUser": 170057,
    "idPerson": 356300,
    "name": "Luiz Claudio Barbosa Stopa",
    "username": "lstopa@edf.pro.br",
    "email": "lstopa@edf.pro.br",
    "academicTitle": null
  }
]
```

**Cobertura auditada (2026-06-10):**

| Ano | UN1 (`/inst/320/.../{idCal}/professors`) | UN2 (`/inst/321/.../{idCal}/professors`) |
|---|---|---|
| 2021 | 35 | 10 |
| 2022 | 33 | 11 |
| 2023 | 37 | 13 |
| 2024 | 44 | 15 |
| 2025 | 43 | 19 |
| 2026 | 41 | 15 |

**Universo total distintos por idPerson (2021–2026, UN1+UN2):** 91 professores.

⚠️ Este endpoint **NÃO retorna CPF**. Pra ter CPF, cruzar via `/persons` (campo `cpf`).

### 3.5 `GET /institutions/{idInst}/items`

Lista serviços/disciplinas/itens vendáveis (~349 itens).

```json
{
  "idItem": 84058,
  "idInstitution": 320,
  "description": "English Camp - 2024",
  "type": "service",
  "period": 1,
  "price": 280,
  "status": "active",
  "costCenter": null
}
```

Filtro `?type=subject|service|lesson|class|group` funciona.

### 3.6 `GET /institutions/{idInst}/contracts`

Lista todos os contratos da instituição. Cuidado: pode ser pesado (UN1 = 11.432 contratos).

Filtros típicos client-side: `idPerson`, `idAcademicCalendar`, `idItem`.

### 3.7 `GET /institutions/{idInst}/contracts/{idContract}/detailed`

**Contrato completo** com purchases, invoices, recurringPayment, paymentMethods, gatewayTransactions.

### 3.8 `GET /institutions/{idInst}/contracts/{idContract}/invoices`

Apenas as faturas (parcelas) do contrato.

### 3.9 `GET /institutions/{idInst}/payments`

Pagamentos por período. **Dois modos de uso:**

- `?startDate=2026-06-01&endDate=2026-06-09` — filtra por `paymentDate`, retorna só `paid`/`cancelled` no range.
- `?include=gatewayTransactions` — **sem filtro de data**, retorna TUDO incluindo `pending`. Filtrar local por `date`.

```json
{
  "date": "2026-06-05T03:00:00.000Z",
  "value": 5278.00,
  "status": "paid",
  "idGateway": 315,
  "idAccount": 478,
  ...
}
```

---

## 4. Endpoints que NÃO funcionam (HTML do SPA)

Esses retornam HTTP 200 mas com HTML do front-end (não são API REST):

- `GET /persons/{idPerson}` (individual)
- `GET /users/{idUser}/timetable`
- `GET /institutions/{id}/teachers`
- `GET /institutions/{id}/timetable`
- `GET /institutions/{id}/classes`
- `GET /institutions/{id}/disciplines`
- `GET /institutions/{id}/subjects`
- `GET /reports`, `/customReports`, `/dashboards`

Regra: qualquer path que retorne `<!DOCTYPE html>` é falso positivo (200 OK mas SPA).

---

## 5. Limitações conhecidas

1. **CPF parcial em `academicCalendars/.../professors`** — retorna apenas `idUser, idPerson, name, username, email`. Pra ter CPF: cruzar com `/persons`. Mesmo assim, **~52%** dos profs (47/91) têm CPF preenchido na base.

2. **Quadro de horários detalhado (timetable: disc/turma/dia/horário) não tem endpoint REST público.** No painel Gennera há relatório "Professor x Disciplina x Turma" gerado server-side, mas o JS dele itera `data.professors[].subjects[].timetable[]` — esse `data` não é exposto via endpoint REST direto.
   - **Workaround:** usar o relatório do painel (exporta CSV) ou consumir do banco staging local `gennera_stg.professor_quadro_horarios`.

3. **Profile "Professor" é sticky/cosmético** — 191 cadastros com profile=Professor em UN1, mas apenas 33–44 ativos por ano via `academicCalendars/.../professors`. A flag não é critério operacional.

4. **`/institutions/320/persons` retorna IGUAL ao `/institutions/321/persons`** — 9.347 em ambos. Base de pessoas é única (compartilhada), separada apenas por institution_id no contexto de vinculação (turma, contrato, pagamento).

5. **Tentativas recusadas pelo emissor (cartão)** ficam só no painel admin Gennera — não expostas via REST.

---

## 6. Cliente Node mínimo

```javascript
const https = require('https');
const fs = require('fs');

// JWT salvo em arquivo local (NUNCA commitar)
const token = fs.readFileSync('./_gen_token', 'utf8').trim();

function get(path) {
    return new Promise((resolve, reject) => {
        const opts = {
            hostname: 'api2.gennera.com.br',
            port: 443,
            path,
            method: 'GET',
            headers: {
                'x-access-token': token,
                'accept': 'application/json'
            }
        };
        const req = https.request(opts, res => {
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => {
                if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}: ${d.substring(0,200)}`));
                try { resolve(JSON.parse(d)); }
                catch (e) { reject(new Error('Não é JSON: ' + d.substring(0,150))); }
            });
        });
        req.on('error', reject);
        req.end();
    });
}

// Exemplo: listar profs ativos do ano 2022 UN1+UN2 com CPF cruzado
(async () => {
    const profsUN1 = await get('/institutions/320/academicCalendars/4009/professors');
    const profsUN2 = await get('/institutions/321/academicCalendars/4198/professors');
    const personsUN1 = await get('/institutions/320/persons');
    const cpfByIdPerson = new Map(personsUN1.map(p => [p.idPerson, p.cpf]));

    const ativosUnicos = new Map();
    [...profsUN1, ...profsUN2].forEach(p => {
        if (!ativosUnicos.has(p.idPerson)) {
            ativosUnicos.set(p.idPerson, {
                ...p,
                cpf: cpfByIdPerson.get(p.idPerson) || null
            });
        }
    });

    console.log(`Profs ativos 2022 (UN1+UN2): ${ativosUnicos.size}`);
    for (const p of ativosUnicos.values()) {
        console.log(`  ${p.idPerson} | ${p.name} | ${p.cpf || '(sem CPF)'}`);
    }
})().catch(e => console.error('ERR:', e.message));
```

---

## 7. Queries práticas comuns

### 7.1 Listar todos os professores ativos em algum momento (2021–2026)

```javascript
const CALENDARS = {
    '2021': [3013, 3014], '2022': [4009, 4198], '2023': [5544, 5922],
    '2024': [7356, 7525], '2025': [8804, 8796], '2026': [9622, 9624]
};

const universo = new Map();
for (const [ano, [calUN1, calUN2]] of Object.entries(CALENDARS)) {
    const u1 = await get(`/institutions/320/academicCalendars/${calUN1}/professors`);
    const u2 = await get(`/institutions/321/academicCalendars/${calUN2}/professors`);
    [...u1, ...u2].forEach(p => {
        if (!universo.has(p.idPerson)) universo.set(p.idPerson, { ...p, anos: new Set() });
        universo.get(p.idPerson).anos.add(ano);
    });
}
// universo.size === 91 (auditado)
```

### 7.2 Pegar pagamentos de um período + status `pending`

```javascript
// /payments?startDate&endDate filtra paid/cancelled apenas (NÃO inclui pending)
// pra incluir pending, usar include=gatewayTransactions:
const allPayments = await get('/institutions/320/payments?include=gatewayTransactions');
const periodo = allPayments.filter(p => p.date >= '2026-06-01' && p.date < '2026-07-01');
```

### 7.3 Identificar duplicações por id_person + ano + item

(este é o problema do `gennera_stg.servicos_historico` que tem rows duplicadas — ver documento auditoria sparcela)

```javascript
const contracts = await get('/institutions/320/contracts');
const diego = contracts.filter(c => c.idPerson === 1490 && c.idAcademicCalendar === 4009);
// Diego 2022: deve retornar 4 contratos (idContract 2473, 2474, 2475, 2636)
```

---

## 8. Anomalias auditadas (importantes pra modelagem)

1. **Cadastros duplicados de prof** — uma pessoa pode estar em `/persons` com `profiles=[Professor, Funcionário]` ou `[Student, Professor]`. Critério canônico de "é professor" = aparecer em `academicCalendars/.../professors` em pelo menos 1 ano.

2. **Contratos Gennera 2022 — campo `details`** — em 2022 a Gennera rotulava o contrato MENS como **"Rematrícula 2022"**, não "Mensalidade 2022". A partir de 2023, virou "Mensalidade YYYY". Isso afeta qualquer view/join que dependa do texto de `details`.

3. **`servicos_historico` com 2 contratos para mesma parcela** — observado caso onde o financeiro Gennera abriu 2 contratos do mesmo serviço (ALIM) para mesmo aluno/ano, um "limpo" (todas parcelas `pago`) e outro "sujo" (mix `pago + cancelado`). Tratar como erro operacional do financeiro.

4. **`MATERIAL DE ARTES` vs `MATERIAL DIDÁTICO`** — são produtos distintos no negócio (568 ocorrências de Material de Artes ao longo dos anos). Padrões textuais amplos como `ILIKE '%MATERIAL%'` colapsam erradamente.

5. **Status `pago a maior` (308 ocorrências)** — aluno pagou mais que `valor_bruto`. Preservar `valor_bruto` e `valor_pagamento` separados.

6. **Status `renegociado` (10 ocorrências)** — quando contrato é renegociado, o financeiro pode gerar um NOVO contrato que contempla o antigo. Migrar ambas linhas com flag de histórico.

---

## 9. Mapas de campos importantes (banco staging vs API)

`gennera_stg.servicos_historico` (snapshot dez/2025) tem 48 colunas. Equivalência aproximada com API:

| Banco | API equivalente |
|---|---|
| `id_pessoa` | `idPerson` |
| `aluno` | `name` (em /persons) |
| `cpf_responsavel_financeiro` | `cpf` do responsável (cruzamento) |
| `calendario_academico` | `academicCalendar` |
| `contrato` (hash) | `idContract` (mas mapeamento é texto→int, indireto) |
| `item` | `description` em /items |
| `valor_bruto`, `valor_pagamento` | `total`, `paid` em /contracts/detailed |
| `data_vencimento` | `dueDate` em invoices |
| `data_pagamento` | `paymentDate` em payments |
| `status` (pago/atrasado/cancelado/renegociado/pago a maior) | `status` em payments (paid/cancelled/pending) |

---

## 10. Universo total auditado (números)

| Recurso | Total |
|---|---|
| Pessoas em `/persons` (base única) | 9.347 |
| Contratos UN1 | ~11.432 |
| Pessoas com flag `Professor` | 195 |
| **Profs ATIVOS 2021-2026 (UN1+UN2)** | **91** |
| Linhas em `gennera_stg.servicos_historico` | ~125.847 |
| Items/serviços em `/items` | ~349 |
| Calendars (6 anos × 2 unidades) | 12 |

---

## 11. Que NÃO foi localizado (lacunas)

- Endpoint REST de quadro de horários detalhado (disc/turma/dia/horário)
- `/persons/{id}` individual (só retorna HTML)
- Endpoint de "matrícula" individual
- Documentação OpenAPI/Swagger pública
- Endpoint de "histórico escolar" detalhado (notas por etapa)

Para esses, usar relatórios server-side do painel Gennera ou consumir do banco staging local.

---

## 12. Contato

Em caso de dúvida sobre comportamento de algum endpoint, comparar com:
- Banco staging local `gennera_stg.*` (snapshot dez/2025)
- Painel admin Gennera (`apps.gennera.com.br`)

**Token JWT:** mantido em `C:/Users/Guilherme/AppData/Local/Temp/_gen_token` no ambiente de migração (não commitado, não exposto).
