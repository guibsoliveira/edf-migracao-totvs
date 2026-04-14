# Relatório Consolidado — Migração Gennera → TOTVS RM

**Data**: 2026-04-08
**Conexão**: `192.168.1.91:5432 / Edf_bd_legado`
**Schemas**: `gennera_stg` (origem, 54 tabelas) → `export` (destino TOTVS, 42 views)

---

## 1. Panorama dos dados (gennera_stg)

### Tabelas financeiras críticas (as mais sensíveis)

| Tabela | Linhas | Papel | Qualidade |
|---|---:|---|---|
| `invoice` | 99.408 | Faturas/boletos por contrato | Boa — 10.490 com saldo > 0 |
| `contract` | 13.283 | Contratos (12.487 active / 796 deleted) | Status binário claro |
| `enrollment_contract` | 23.476 | Ponte matrícula↔contrato | 1 enrollment : N contracts |
| `invoice_payment` | 254.664 | Pagamentos das faturas | — |
| `payment` | 63.266 | Pagamentos | — |
| `servicos_historico` | 125.849 | Histórico consolidado de parcelas/boletos | **48 colunas denormalizadas** |
| `servicos` | 545 | Subset com **bolsas** detalhadas | Única fonte de desconto por parcela |
| `servicos_2018_2019` … `2024_2025` | 125.849 | Idêntico ao `historico`, segregado por ano | Redundante ao `servicos_historico` |
| `register_transaction` | 6.553 | Caixa/registradora | — |

### Tabelas de pessoas

| Tabela | Linhas | Observação |
|---|---:|---|
| `person` | 9.173 | Apenas id + tipo (PF/PJ) |
| `person_fisica` | 9.166 | **Só 752 têm `codcfo`** (8,2%) — bloqueio de FLAN |
| `person_juridica` | 8 | Raríssimas PJ |
| `person_estrangeiro` | 0 | Vazia |
| `person_cpf_mapping` | 5.310 | Deduplicação e normalização por CPF |
| `pessoa_sexo` | 2.764 | Lookup nome→gênero |
| `cliente_fornecedor` | 1.510 | Snapshot TOTVS atual (755 codcfo distintos) |

### Tabelas acadêmicas

| Tabela | Linhas | Observação |
|---|---:|---|
| `enrollment` | 3.290 | Matrículas (só até 2025, **zero em 2026**) |
| `enrollment_record` | 154.826 | Histórico acadêmico detalhado |
| `enrollment_document` | 6.049 | Documentos exigidos |
| `enrollment_code` | 5.366 | Códigos de matrícula legados |
| `academic` | 770 | Catálogo curso/disciplina/módulo |
| `class` | 7.447 | Turmas |
| `curriculum` | 770 | Grade curricular |
| `period` | 46 | Etapas (P1/P2/P3/REC/RECA) por ano |
| `institution` | 3 | UN1, UN2 e 1 admin |
| `disciplina` | 259 | Disciplinas canônicas |
| `matrix_subjects` | 919 | Matriz de disciplinas |
| `subject_code_main` | 1.540 | Mapeamento código disciplina |
| `student_code_unico` | 2.389 | **RA canônico** (fonte da verdade) |

### Notas, provas e frequência

| Tabela | Linhas |
|---|---:|
| `grade` | 796.228 |
| `exam` | 59.882 |
| `period_average` | 214.672 |
| `attendance` | 296.054 |
| `content` | 2.210 |

### Biblioteca (Escola do Futuro)

| Tabela | Linhas |
|---|---:|
| `library` | 2 |
| `catalog` | 2 |
| `template` | 20 (metadata JSONB) |
| `work` / `copy` / `work_field` / `copy_field` / `copy_subfield` | livros e exemplares |

### Professor pipeline

| Tabela | Linhas |
|---|---:|
| `professor_quadro_horarios` | 18.795 (90 professores distintos) |
| `tabela_professor_rm` | 111 |
| `professor_cpf_temp` | 37 |
| `professor_id_mapping` | 7 |

### Saúde / auxiliares

| Tabela | Linhas |
|---|---:|
| `un1health2025` | 894 |
| `un2health2025` | 306 |
| `relationship` | 7.873 (parentesco aluno↔responsável) |

---

## 2. Views já existentes (schema export)

### Status atual (42 views)

**Financeiro (5 views)**
- `flan` (4.720 linhas) — Lançamentos/boletos em aberto
- `scontrato` (11.645) — Contratos por matrícula
- `sservico` (67) — Catálogo de itens cobráveis (já usa `mode()` ✓)
- `sbolsa` (54) — Catálogo de bolsas (derivado de `invoice`, padrão criativo)
- `sbolsaaluno` (27) — Vínculo aluno↔bolsa por parcela
- `sbolsapletivo` (224) — Disponibilidade por período
- `splanopgto` — Planos de pagamento

**Pessoa (4 views)**
- `ppessoa` (9.166) — Dimensão pessoa consolidada
- `fcfo2` (753) — Clientes/fornecedores TOTVS
- `fcfo2_totvs_xml` / `fcfo2_totvs_xml_lote` — Exports XML
- `dim_pessoa_unica` — Deduplicação consolidada

**Acadêmico (17 views)**
- `sturma` (170), `sturmadisc`, `smatricula` (38.996), `smatricpl` (3.076)
- `scurso`, `sdisciplina`, `sgrade`, `sinstituicao`
- `shabilitacao`, `shabilitacaoaluno`, `shabilitacaofilial`, `shabilitacaofilialpl`
- `spletivo`, `speriodo`, `setapas`, `sprovas`
- `shistalunocol`, `shistdisccol`

**Notas e frequência (4 views)**
- `snotaetapa`, `snotas`, `sfrequencia`, `splanoaula`

**Professor e horário (4 views)**
- `sprofessor` (155), `sprofessorturma`, `shorario`, `shorarioturma`, `shorarioprofessor`
- `professor_qh_enriquecido` — CTE intermediária

**Diversos**
- `saude` (tipo sanguíneo), `v_matrix_source` (Escola do Futuro)

---

## 3. Problemas críticos identificados

### 3.1 Gap de cobertura na view `flan`

**Esperado**: todos os boletos abertos (10.490)
**Gerando hoje**: 4.720 linhas
**Perdidos**: 5.775 boletos (55% do total)

Causa-raiz:

| Motivo | Qtd invoices perdidos |
|---|---:|
| Contrato com `status='deleted'` | 3.651 |
| Responsável sem `codcfo` | 2.119 |
| Responsável é PJ (JOIN só em person_fisica) | 5 |

**Decisões de negócio pendentes**:
1. Incluir invoices de contratos deletados? Esses saldos existem fisicamente?
2. Os 99 responsáveis sem `codcfo` precisam ter codcfo gerado antes da migração
3. Adicionar JOIN com `person_juridica` na view

### 3.2 Cobertura pessoa física → codcfo

- **9.166 PF totais / 752 com codcfo (8,2%)**
- **4.389 PF sem CPF (48%)** — impede geração de codcfo
- Dos 545 responsáveis de contratos ativos com saldo aberto, **99 estão sem codcfo**

### 3.3 Qualidade em `servicos_historico` pré-2021

- 2018-2019: **id_pessoa é string vazia** (`''`, não NULL) — filtro `IS NOT NULL` falha
- Só 1 aluno distinto detectado em 2018 e 2019 → evidência de dados migrados em bloco, sem vínculo individual
- Correção atual (`calendario_academico >= '2021'`) mitiga isso na `sservico`

### 3.4 Anos inválidos em `invoice`

- 12 invoices com `year = 5021` (typo de 2021)
- 1 invoice com `year = 2032`
- **Total: R$ 41.328,00 afetados** (ano 5021)

### 3.5 Duplicatas na `smatricula`

- **26 grupos duplicados** `(CODTURMA, CODPERLET, RA, CODDISC)`
- Duplicatas são linhas **idênticas em todos os campos** → problema no SELECT sem DISTINCT

### 3.6 Enrollment 2026 vazio, mas servicos_historico 2026 existe

- 0 enrollments ativos em 2026
- 662 linhas em `servicos_historico` de 2026 (mensalidades pagas antecipadamente)
- Isso sugere que a rematrícula 2026 ainda não foi formalizada no Gennera mas os pagamentos já começaram

### 3.7 Catálogo de templates confunde escopo

- `gennera_stg.template` (20 linhas) é da **biblioteca** (Cinema, Drama, Filosofia, etc.)
- **NÃO é o catálogo TOTVS** — aqueles templates estão na Google Sheets (ainda inacessível)

---

## 4. Views TOTVS pendentes (não existem no export)

Baseado no padrão de nomes das views existentes e templates TOTVS comuns:

| Template TOTVS | Status | Observação |
|---|---|---|
| FLAN | ✅ Existe | Precisa de correção (gap de 55%) |
| **SLAN** | ❌ **Não existe** | Ponte FLAN↔parcela de SCONTRATO. Caminho validado: `invoice → contract → enrollment_contract → enrollment`. Sem fan-out cruzado (só 5 contratos multi-enrollment, todos no mesmo ano) |
| FCFO2 | ✅ Existe | Cobre só 753 pessoas |
| PPESSOA | ✅ Existe | Completo |
| SCONTRATO | ✅ Existe | Completo |
| SSERVICO | ✅ Existe | Já corrigido com `mode()` |
| SBOLSA/SBOLSAALUNO | ✅ Existe | Padrão criativo via invoice |
| Templates complementares (SCURSO, SDISCIPLINA, STURMA, etc.) | ✅ Existem | Validar integridade |

---

## 5. Estratégia de validação padrão (para cada view financeira)

Testes que devem rodar **antes e depois** de cada alteração:

```sql
-- 1. Contagem absoluta
SELECT COUNT(*) FROM export.<view>;

-- 2. Soma dos valores críticos (validação financeira)
SELECT SUM(<campo_valor>) FROM export.<view>;

-- 3. Zero duplicatas na chave primária TOTVS
SELECT <chave>, COUNT(*) FROM export.<view> GROUP BY <chave> HAVING COUNT(*) > 1;

-- 4. Zero NULLs em campos obrigatórios
SELECT COUNT(*) FROM export.<view> WHERE <campo_obrigatorio> IS NULL;

-- 5. Cruzamento com fonte (integridade referencial)
SELECT COUNT(*) FROM gennera_stg.<fonte> x
WHERE NOT EXISTS (SELECT 1 FROM export.<view> v WHERE v.<chave> = x.<chave>);
```

---

## 6. Próximos passos recomendados

### Prioridade 1 — Corrigir FLAN (financeiro crítico)
1. Decisão de negócio: incluir contratos deletados? Se não, documentar saldos perdidos
2. Gerar codcfo para os 99 responsáveis faltantes
3. Adicionar JOIN com `person_juridica` para os 5 casos PJ

### Prioridade 2 — Criar SLAN
Ponte FLAN↔SCONTRATO. Chave composta: `(id_contract, id_invoice)`. Validar que cada invoice aberta vira 1 linha SLAN referenciando a parcela do scontrato correspondente.

### Prioridade 3 — Higienizar dados fonte
- Corrigir anos inválidos em invoice (5021 → 2021, 2032 → ?)
- Remover duplicatas da smatricula (adicionar DISTINCT ou chave de deduplicação)
- Documentar os 2.119 invoices sem responsável mapeado

### Prioridade 4 — Acessar planilha de controle
A planilha Google Sheets contém a aba `ORDEM` com o status de cada view + abas ocultas com templates oficiais. Está 401 via WebFetch — precisa ser tornada pública ou acessada via browser com consentimento do usuário.

---

## 7. Inventário completo

- **54 tabelas** em `gennera_stg` (dump em `gennera_stg_schema.txt`, 772 linhas)
- **42 views** em `export` (dump em `all_export_views.sql`, 3.017 linhas)
- Total combinado: **~300 colunas mapeadas**

Esta é a base para criar validações automáticas e estratégias para as próximas views (SLAN prioritária).
