# 01 - Arquitetura Gennera

## O que é o Gennera

O Gennera é um sistema legado de gestão educacional baseado em PostgreSQL (schema `gennera_stg`) com API REST live em `api2.gennera.com.br`. Centraliza dados de 2 instituições (Unidade I e II) desde 2018, abrangendo:

- **Academico:** matrículas, turmas, grades curriculares, disciplinas, períodos letivos
- **Financeiro:** contratos (mensalidade, alimentação, material), parcelas, pagamentos, bolsas, descontos
- **Pessoas:** alunos (menores de idade), responsáveis financeiros/acadêmicos, professores
- **Avaliação:** notas, frequência, médias por período

**Encoding:** PostgreSQL em LATIN1 (CRÍTICO usar `PGCLIENTENCODING=LATIN1` em todo acesso)

---

## Por que estamos saindo

A EDF está migrando para **TOTVS RM Educacional** (destino em Oracle via WebService SOAP) para:
- Consolidar 2 unidades num sistema unificado
- Eliminar dependência de banco legado PostgreSQL
- Ganhar suporte TOTVS oficial para financeiro educacional
- Integrar com folha de pagamento Protheus

**Status:** Em migração (cutoff dados: dez/2025 no banco; 2026 requer API live)

---

## Hierarquia institucional

```
idCustomer (1592 EDF global)
    |
    +-- idInstitution
            | 320 = UN1 (Unidade I)
            | 321 = UN2 (Unidade II)
            | 873 = teste
            |
            +-- idPerson (aluno/responsável)
                    |
                    +-- enrollments (matrículas)
                            |
                            +-- contracts (contratos de serviço)
                                    |
                                    +-- invoices (parcelas/boletos)
                                            |
                                            +-- payments (pagamentos, recorrências)
```

---

## Entidades principais e relacionamentos

### Pessoas (Física/Jurídica)

| Tabela | Linhas | Propósito | Chave |
|--------|--------|-----------|-------|
| `person_fisica` | 9.166 | Mestre de alunos/responsáveis | `id_person` (int PK) |
| `person_juridica` | 8 | Raro; PJ que pode ter contrato | `id_person` (int PK) |
| `person_cpf_mapping` | 5.310 | Dedup por CPF; 8% com CPF temporário | `id_person_principal` |
| `cliente_fornecedor` | 1.510 | Snapshot FCFO do TOTVS (~755 unicos) | `codcfo` |

**Nota LGPD:** `person_fisica` contém CPF (4.389 sem preenchimento = 48%), telefone, endereço. API expõe tudo; banco local é source primária.

### Matrículas e Cursos

| Tabela | Linhas | Propósito | Chave |
|--------|--------|-----------|-------|
| `enrollment` | 3.290 | Matrículas 2021-2025 | `id_enrollment` (int PK) |
| `student_code_unico` | 2.389 | RA CANÔNICO em formato YYYYNNNNNN | `id_person` + `source` |
| `enrollment_record` | 154.826 | Histórico acad (granularidade: aluno+disciplina) | Sem PK |
| `class` | 7.447 | Turmas (sufixos UN2 EI: IA=integral, MB=manhã, TC=tarde) | `id_class` (int PK) |
| `academic` | 770 | Disciplinas em grade (subject_code_gennera ≠ subject_code TOTVS) | `id_academic` (int PK) |

### Avaliação

| Tabela | Linhas | Propósito |
|--------|--------|-----------|
| `grade` | 796.228 | Notas (texto: "8.5", "A", "---") |
| `period_average` | 214.672 | Médias por período (P1/P2/P3/REC) |
| `attendance` | 296.054 | Frequência |
| `exam` | 59.882 | Provas; `weight` nem sempre soma 100 |

### Financeiro (CRÍTICO)

| Tabela | Linhas | Propósito | Chave |
|--------|--------|-----------|-------|
| `servicos_historico` | 125.849 | **MESTRE** (48 cols denormalizadas) | Sem PK, granularidade: contrato+período |
| `contract` | 13.283 | Contratos (12.487 ativos / 796 cancelados) | `id_contract` (int PK) |
| `invoice` | 99.408 | Parcelas/boletos | `id_invoice` (int PK) |
| `servicos` | 545 | Subset com bolsas detalhadas (ÚNICA fonte de desconto por parcela) | Sem PK |
| `enrollment_contract` | 23.476 | Ponte matrícula ↔ contrato (1:N) | Chave composta |
| `payment` | 63.266 | Pagamentos (3 cenários: cartão OK, cartão erro, recorrência ativa) | `id_payment` (int PK) |
| `invoice_payment` | N/A | Ponte invoice ↔ payment | Chave composta |

---

## Modelos de negócio implícito

### Status de contrato e pagamento
- **Contrato:** active, cancelled, pending, etc.
- **Pagamento:** `paid` (processado), `pending` (D+30 normal, não erro), `cancelled` (recusado)

### Serviços por contrato
Um aluno pode ter múltiplos contratos: 1 por serviço (REMATRIC, MENS, ALIM, MAT). Consolidação é lógica, não física.

### Recorrência (recurringPayment na API)
- `retryCount`, `maxRetries`, `lastCharge`
- Exposto na API `GET /contracts/:id/detailed` mas NÃO no banco `gennera_stg`

### Bolsas
Campo `mode()` em `servicos_historico` pode ser contaminado por parcelamentos; conferir com `servicos.DescBolsas`.

### Calendários
`academic_calendar` é string (formato: "2021", "2022", etc.) vs. API retorna estrutura de período.

---

## Dados 2026

**Banco (gennera_stg):** Vazio ou mínimo (cutoff dez/2025)
**API live:** Dados ao vivo (requer JWT válido, ~24h de duração)

Qualquer consulta sobre 2026 deve ir direto para a API, não para o banco.

---

## Dois acessos paralelos

```
┌─────────────────────────────────────┐
│   GENNERA API live (REST JSON)      │
│   api2.gennera.com.br               │
│   Header: x-access-token: <JWT>     │
│   - Inclui 2026                     │
│   - Atualizado em tempo real        │
│   - Sem tentativas recusadas (gap)  │
└─────────────────────────────────────┘
                    ↓
       (Ler dados históricos + 2026)
                    ↓
┌─────────────────────────────────────┐
│  PostgreSQL gennera_stg (LATIN1)    │
│  192.168.1.91:5432                  │
│  - 2018-2025 (cutoff dez/2025)      │
│  - 57 tabelas                       │
│  - Source primária para validação   │
└─────────────────────────────────────┘
```

Ambos devem ser consultados para cobertura completa.

