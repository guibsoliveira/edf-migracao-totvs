# Fluxo Completo de Migracao - Gennera para TOTVS RM

**Projeto:** Escola do Futuro (EDF) - Migracao de Sistema Academico  
**Data:** 2026-04-16  
**Versao:** 1.0

---

## 1. Visao Geral

### O que estamos fazendo?

Migrar TODOS os dados da Escola do Futuro do sistema **Gennera** (sistema academico atual) 
para o **TOTVS RM Educacional** (novo sistema).

Isso inclui:
- **Dados de pessoas** (alunos, responsaveis, professores)
- **Dados academicos** (cursos, turmas, matriculas, notas, frequencia)
- **Dados financeiros** (contratos, parcelas, boletos, bolsas, descontos)

### Sistemas envolvidos

```
GENNERA (sistema atual)
    |
    |--- API REST (api2.gennera.com.br) ---> dados VIVOS e atualizados
    |
    |--- Banco PostgreSQL (gennera_stg) ---> dump historico importado
    |
    v
BANCO INTERMEDIARIO (PostgreSQL - Edf_bd_legado)
    |
    |--- Schema gennera_stg: dados brutos do Gennera
    |--- Schema export: views que transformam para formato TOTVS
    |
    v
TOTVS RM (novo sistema - Oracle)
    |--- Importador TOTVS le as views do schema export
    |--- Carrega no Oracle seguindo as templates
```

### Estrutura da Escola

| Unidade | API ID | Cursos | Turnos |
|---------|--------|--------|--------|
| UN1 (Filial 1) | 320 | EF1 (3o-5o Ano), EF2 (6o-9o Ano), EM (1a-3a Serie) | Tudo Integral |
| UN2 (Filial 2) | 321 | EI (N2, N3, K1, K2), EF1 (1o-2o Ano) | EF1=Integral, EI=Integral/Manha/Tarde |
| Base Teste | 873 | - | - |

**Periodos letivos disponíveis:** 2021, 2022, 2023, 2024, 2025, 2026

---

## 2. Fontes de Dados

### 2.1 API Gennera (FONTE PRIMARIA - dados vivos)

A API retorna dados em tempo real do Gennera. Autenticacao via header `x-access-token` com JWT.

**Vantagens:**
- Dados sempre atualizados
- Inclui 2026 (que pode nao estar no dump do banco)
- Estrutura limpa e bem organizada
- IDs consistentes entre endpoints

**Limitacoes:**
- Precisa de internet/conexao
- Algumas consultas retornam muitos dados (11k+ contratos)
- Token expira e precisa ser renovado

### 2.2 Banco PostgreSQL gennera_stg (FONTE SECUNDARIA - dump historico)

Tabelas importadas por CSV/dump do Gennera. Contém o historico completo mas pode estar desatualizado.

**Vantagens:**
- Consultas rapidas via SQL
- Historico completo (2021-2025)
- Ja possui as views do schema export funcionando

**Limitacoes:**
- Dados podem estar defasados vs Gennera real
- Usa IDs diferentes em algumas tabelas (enrollment vs servicos_historico)
- Nomenclatura inconsistente entre anos (resolvido via regex nas views)

### 2.3 Relacao entre os IDs

| Campo | Fonte | Range | Exemplo |
|-------|-------|-------|---------|
| API persons.idPerson | API | 355k-3M | 1027818 (Manuela) |
| servicos_historico.id_pessoa | DB | 355k-3M | 1027818 (Manuela) |
| API enrollments.idEnrollment | API | 356k-1.2M | 1004311 |
| servicos_historico.id_matricula | DB | mesma faixa | 1004311 |
| enrollment.id_person (DB) | DB dump antigo | 1k-9k | 8259 |
| enrollment.id_enrollment (DB) | DB dump antigo | 438-9160 | 3202 |
| student_code_unico.code_unif | DB | formato YYYYNNNNNN | 2022000211 = RA |

**IMPORTANTE:** 
- `API.idPerson` = `servicos_historico.id_pessoa` (MESMO namespace)
- `API.idEnrollment` = `servicos_historico.id_matricula` (MESMO namespace)
- `enrollment.id_person` do DB != API.idPerson (namespaces DIFERENTES - exports distintos)
- O **RA** (Registro Academico) vem de `student_code_unico.code_unif`

---

## 3. Catalogo de Endpoints da API

### 3.1 Estrutura Institucional

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions` | Lista todas as unidades | 3 | Mapear filiais (320=UN1, 321=UN2, 873=teste) |
| `GET /institutions/:id` | Detalhe de uma unidade (CNPJ, endereco) | 1 | Dados de SINSTITUICAO |
| `GET /institutions/:id/campuses` | Polos da unidade | ? | Verificar se ha polos |
| `GET /institutions/:id/courses` | Cursos da unidade | 2-3 | Validar SCURSO (UN1: EM/EF1/EF2, UN2: EI/EF1) |
| `GET /institutions/:id/courses/:id/curriculums` | Grades curriculares | ? | Validar SGRADE |
| `GET /institutions/:id/courses/:id/curriculums/:id/modules` | Modulos/series | ? | Validar SHABILITACAO |
| `GET /institutions/:id/courses/:id/curriculums/:id/modules/:id/subjects` | Disciplinas | ? | Validar SDISCIPLINA |

### 3.2 Calendario e Periodos

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/academicCalendars` | Calendarios academicos | 6 (2021-2026) | Validar SPLETIVO |
| `GET /institutions/:id/academicCalendars/:id/periods` | Periodos (trimestres, bimestres) | ? | Validar SPERIODO, SETAPAS |
| `GET /institutions/:id/academicCalendars/:id/averageDefinitions` | Regras de media | ? | Validar config de avaliacao |
| `GET /institutions/:id/academicCalendars/:id/curriculumOffers` | Ofertas curriculares | ? | Grade x periodo |

### 3.3 Turmas e Aulas

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/curriculumOffers/:id/classes` | Turmas de uma oferta | ? | Validar STURMA |
| `GET /institutions/:id/classes/:id` | Detalhe de uma turma | 1 | Validar dados de turma |
| `GET /institutions/:id/classes/:id/students` | Alunos de uma turma | ~20-30 | Validar SMATRICULA |
| `GET /institutions/:id/classes/:id/professors` | Professores de uma turma | ? | Validar SPROFESSORTURMA |
| `GET /institutions/:id/classes/:id/diaries` | Diarios de uma turma | ? | Validar STURMADISC |
| `GET /institutions/:id/classes/:id/timetables` | Horarios de aula | ? | Validar SHORARIO |

### 3.4 Diarios e Notas

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/diaries/:id` | Detalhe de um diario | 1 | Detalhes da disciplina |
| `GET /institutions/:id/diaries/:id/students` | Alunos do diario | ~20-30 | Lista de matriculados |
| `GET /institutions/:id/diaries/:id/exams` | Avaliacoes | ? | Validar SPROVAS |
| `GET /institutions/:id/diaries/:id/grades` | Notas do diario | ? | Validar SNOTAS |
| `GET /institutions/:id/diaries/:id/students/:id/grades` | Notas de 1 aluno | ? | Detalhe individual |
| `GET /institutions/:id/diaries/:id/students/:id/periodAverages` | Medias por periodo | ? | Validar SNOTAETAPA |
| `GET /institutions/:id/diaries/:id/students/:id/averages` | Medias finais | ? | Resultado final |
| `GET /institutions/:id/diaries/:id/attendances` | Frequencia do diario | ? | Validar SFREQUENCIA |
| `GET /institutions/:id/diaries/:id/lessons` | Aulas registradas | ? | Validar SPLANOAULA |
| `GET /institutions/:id/diaries/:id/contents` | Conteudos ministrados | ? | Historico de aulas |
| `GET /institutions/:id/diaries/:id/freeAssessments` | Pareceres descritivos | ? | Avaliacao qualitativa |

### 3.5 Matriculas

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/campaigns` | Campanhas de matricula | ~16/unidade | Matrículas/Rematrículas por ano |
| `GET /institutions/:id/campaigns/:id/enrollments` | Matriculas de campanha | ~200-600 | Lote de matriculas |
| `GET /institutions/:id/enrollments/:id` | Detalhe de matricula | 1 | Dados individuais |
| `GET /institutions/:id/enrollments/:id/contracts` | Contratos da matricula | 2-5 | Liga matricula a contrato |
| `GET /institutions/:id/enrollments/:id/subjects` | Disciplinas da matricula | ? | Grade do aluno |
| `GET /institutions/:id/persons/:id/enrollments` | Matriculas de uma pessoa | 1-5 | Historico do aluno |
| `GET /institutions/:id/enrollmentRecords` | Todos registros academicos | grande | Cross-check de notas |
| `GET /institutions/:id/persons/:id/enrollmentRecords` | Registros academicos de pessoa | ? | Historico individual |

### 3.6 Pessoas

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/persons` | Todas as pessoas | ~9.300/unidade | Validar PPESSOA, FCFO |
| `GET /institutions/:id/persons/:id` | Detalhe de pessoa | 1 | Dados completos (CPF, endereco, etc.) |
| `GET /institutions/:id/persons/:id/relationships` | Relacionamentos (pais, responsaveis) | ? | Validar vinculos familiares |

### 3.7 Financeiro (CRITICO para migracao)

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/contracts` | Todos contratos | ~11k UN1, ~3.8k UN2 | **SCONTRATO** |
| `GET /institutions/:id/contracts/:id` | Contrato simples | 1 | Dados basicos |
| `GET /institutions/:id/contracts/:id/detailed` | Contrato com compras | 1 | **Purchases = itens do contrato** |
| `GET /institutions/:id/contracts/:id/invoices` | Faturas do contrato | 10-12 | **SPARCELA** (parcelas reais) |
| `GET /institutions/:id/contracts/:id/invoices/:id/payments` | Pagamentos de fatura | ? | Status de pagamento |
| `GET /institutions/:id/contracts/:id/invoices/:id/gatewayTransactions` | Transacoes gateway | ? | Detalhes de cobranca |
| `GET /institutions/:id/invoices?cycleStart=MM/YYYY&cycleEnd=MM/YYYY` | Faturas por periodo | ~600/mes | Visao mensal |
| `GET /institutions/:id/payments` | Todos pagamentos | ~18k/unidade | Reconciliacao financeira |
| `GET /institutions/:id/payments/:id` | Pagamento detalhado | 1 | Detalhe individual |
| `GET /institutions/:id/items` | Catalogo de servicos | ~347/unidade | **SSERVICO** (validacao) |
| `GET /institutions/:id/discounts` | Catalogo de descontos | ~233/unidade | **SBOLSA** (validacao) |
| `GET /institutions/:id/campaigns/:id/plans` | Planos de campanha | ? | **SPLANOPGTO** (validacao) |

### 3.8 Outros

| Endpoint | O que retorna | Volume | Uso na migracao |
|----------|---------------|--------|-----------------|
| `GET /institutions/:id/incidents` | Ocorrencias | ? | Nao usado na migracao |
| `GET /institutions/:id/fiscalInvoices?cycleStart=&cycleEnd=` | Notas fiscais | ? | Validacao fiscal |
| `GET /institutions/:id/academicCalendars/:id/professors` | Docentes por calendario | ? | Validar SPROFESSOR |
| `GET /institutions/:id/academicCalendars/:id/timetables` | Horarios por calendario | ? | Validar SHORARIO |

---

## 4. Estado Atual da Migracao

### 4.1 Views ja criadas (schema export) - 43 views

**Modulo Pessoas (OK):**
- `ppessoa` - Cadastro de pessoas (alunos, responsaveis)
- `fcfo` / `fcfo_totvs_xml` - Clientes/Fornecedores
- `dim_pessoa_unica` - Deduplicacao de pessoas

**Modulo Academico (OK - maioria ja funcional):**
- `scurso` - Cursos (EI, EF1, EF2, EM)
- `shabilitacao` - Habilitacoes (series/anos)
- `sgrade` - Grades curriculares
- `sdisciplina` - Disciplinas
- `sturma` / `sturmadisc` - Turmas e disciplinas
- `spletivo` - Periodos letivos (2021-2026)
- `smatricula` / `smatricpl` - Matriculas
- `sprovas` / `setapas` - Provas e etapas
- `snotas` / `snotaetapa` - Notas
- `sfrequencia` - Frequencia
- `sprofessor` / `sprofessorturma` - Professores
- `shorario` / `shorarioturma` / `shorarioprofessor` - Horarios
- `speriodo` - Periodos
- `splanoaula` - Plano de aula
- `shabilitacaofilial` / `shabilitacaofilialpl` - Habilitacoes por filial
- `shabilitacaoaluno` - Habilitacao do aluno
- `shistalunocol` / `shistdisccol` - Historico
- `sinstituicao` - Instituicao
- `saude` - Dados de saude
- `v_matrix_source` - Fonte auxiliar

**Modulo Financeiro (EM PROGRESSO):**

| # | View | Status | Descricao |
|---|------|--------|-----------|
| 37 | `sbolsa` | APLICADA | Catalogo de bolsas/descontos |
| 37b | `sbolsapletivo` | APLICADA | Bolsas disponiveis por periodo |
| 38 | `sservico` | APLICADA | Catalogo de servicos (MENS, ALIM, MAT) |
| 39 | `splanopgto` | APLICADA | Planos de pagamento (62 planos) |
| 40 | `sparcplano` | APLICADA | Parcelas do plano (pode ser descartada) |
| 41 | `shabmodelopgto` | APLICADA | Ponte plano x curso/serie (175 combos) |
| 42 | `scontrato` | **PRECISA REESCREVER** | Contratos por aluno (view antiga sem filtros) |
| 43 | `sparcela` | **PENDENTE** | Parcelas reais cobradas |
| 44 | `sbolsaaluno` | **PRECISA VALIDAR** | Bolsas aplicadas por aluno |

---

## 5. Fluxo de Migracao Proposto

### Fase 1: Validacao de Dados (AGORA)

**Objetivo:** Garantir que os dados no banco intermediario estao corretos antes de gerar as views.

```
API Gennera -----> Comparar com -----> gennera_stg (banco)
                                            |
                                      Corrigir divergencias
```

**Acoes:**
1. **Validar pessoas:** Comparar API `/persons` com `gennera_stg.person_fisica`
   - Verificar se todos os alunos existem
   - Verificar CPFs, nomes, dados de contato
   
2. **Validar matriculas:** Comparar API `/enrollments` com `gennera_stg.enrollment`
   - Atentar que os IDs sao de namespaces diferentes!
   - Usar nome + turma + ano como chave de cruzamento
   
3. **Validar contratos:** Comparar API `/contracts` com `gennera_stg.servicos_historico`
   - Aqui os IDs BATEM (hash = contrato)
   - Verificar se todos os contratos ativos estao no banco
   
4. **Validar catalogo:** Comparar API `/items` com `gennera_stg.servicos_historico.item`
   - Garantir que todos os itens estao mapeados

### Fase 2: Atualizar Banco com Dados da API (OPCIONAL mas recomendado)

**Objetivo:** Trazer dados atualizados de 2026 e corrigir gaps.

```
API Gennera ---(script Python/SQL)---> gennera_stg atualizado
```

**O que podemos extrair via API para atualizar o banco:**

| Dado | Endpoint | Tabela destino | Prioridade |
|------|----------|----------------|------------|
| Contratos 2026 | `/contracts` | servicos_historico (complementar) | ALTA |
| Matriculas 2026 | `/campaigns/:id/enrollments` | enrollment | ALTA |
| Pessoas atualizadas | `/persons` | person_fisica | MEDIA |
| Catalogo de servicos | `/items` | servicos (novo) | MEDIA |
| Bolsas/descontos | `/discounts` | bolsas_descontos | MEDIA |
| Faturas detalhadas | `/contracts/:id/invoices` | invoice (novo) | PARA SPARCELA |

### Fase 3: Gerar/Corrigir Views Financeiras (PROXIMO PASSO)

**Objetivo:** Completar as views financeiras pendentes.

```
gennera_stg (dados corretos)
    |
    v
Views export (schema export)
    |
    |--- scontrato (REESCREVER - 1 contrato por aluno por periodo)
    |--- sparcela (CRIAR - parcelas reais com valores e datas)
    |--- sbolsaaluno (VALIDAR - bolsas por aluno)
    |
    v
TOTVS RM Importador
```

**Ordem de execucao das views financeiras:**
1. `scontrato` - precisa existir antes de sparcela
2. `sparcela` - depende de scontrato
3. `sbolsaaluno` - pode ser feita em paralelo

### Fase 4: Importar no TOTVS RM

**Objetivo:** Carregar os dados no Oracle via importador TOTVS.

**Pre-requisitos no TOTVS (cadastros que precisam existir ANTES):**
1. SPLETIVO (periodos letivos) - ja importado
2. SHABILITACAOFILIAL (habilitacoes por filial) - precisa reimportar com turnos EI
3. SCURSO, SHABILITACAO, SGRADE - ja importados
4. STURMA, STURMADISC - ja importados
5. SMATRICULA - ja importada
6. SSERVICO - ja importado
7. SPLANOPGTO - ja importado
8. SHABMODELOPGTO - precisa reimportar apos SHABILITACAOFILIAL

**Ordem de importacao financeira:**
```
SHABILITACAOFILIAL (reimportar com turnos Manha/Tarde para EI)
    |
    v
SHABMODELOPGTO (reimportar - depende de SHABILITACAOFILIAL)
    |
    v
SCONTRATO (importar - depende de tudo acima)
    |
    v
SPARCELA (importar - depende de SCONTRATO)
    |
    v
SBOLSAALUNO (importar - depende de SCONTRATO e SBOLSA)
```

### Fase 5: Validacao Final

**Objetivo:** Garantir que os dados no TOTVS batem com o Gennera.

```
TOTVS RM (Oracle) <--- comparar ---> API Gennera
```

**Checklist de validacao:**
- [ ] Total de alunos por ano/filial bate?
- [ ] Total de contratos por ano bate?
- [ ] Valores totais por periodo batem?
- [ ] Todas as bolsas/descontos estao aplicados?
- [ ] Parcelas com status correto (pago/pendente/cancelado)?

---

## 6. Mapeamento API -> Views TOTVS

### Como cada view TOTVS se alimenta dos dados

| View TOTVS | Fonte DB (atual) | Endpoint API (validacao/atualizacao) |
|------------|-------------------|--------------------------------------|
| PPESSOA | person_fisica | `GET /persons/:id` |
| FCFO | person_fisica + relationship | `GET /persons/:id` + `/relationships` |
| SCURSO | academic | `GET /courses` |
| SHABILITACAO | academic | `GET /courses/:id/curriculums/:id/modules` |
| SGRADE | academic, enrollment | `GET /academicCalendars` |
| SDISCIPLINA | matrix_subjects | `GET /courses/:id/curriculums/:id/modules/:id/subjects` |
| STURMA | enrollment, class | `GET /classes/:id` |
| STURMADISC | enrollment_record | `GET /classes/:id/diaries` |
| SPLETIVO | enrollment | `GET /academicCalendars` |
| SMATRICULA | enrollment, enrollment_record | `GET /enrollments/:id` + `/subjects` |
| SPROVAS | exam | `GET /diaries/:id/exams` |
| SNOTAS | grade | `GET /diaries/:id/grades` |
| SNOTAETAPA | period_average | `GET /diaries/:id/students/:id/periodAverages` |
| SFREQUENCIA | attendance | `GET /diaries/:id/attendances` |
| SPROFESSOR | person_fisica (professor) | `GET /academicCalendars/:id/professors` |
| SSERVICO | servicos_historico | `GET /items` |
| SPLANOPGTO | servicos_historico (derivado) | `GET /campaigns/:id/plans` |
| SHABMODELOPGTO | splanopgto + shabilitacao | derivado internamente |
| **SCONTRATO** | **servicos_historico + enrollment** | **`GET /contracts` + `/detailed`** |
| **SPARCELA** | **servicos_historico** | **`GET /contracts/:id/invoices`** |
| SBOLSA | bolsas_descontos | `GET /discounts` |
| SBOLSAPLETIVO | sbolsa x spletivo | derivado internamente |
| **SBOLSAALUNO** | **bolsas_descontos** | **`GET /contracts/:id/detailed` (purchases.discounts)** |

---

## 7. O que a API pode resolver que o banco nao resolve

### 7.1 Dados de 2026
O banco tem dados limitados de 2026 (apenas rematriculas no servicos_historico).
A API pode ter matriculas e contratos mais completos de 2026.

### 7.2 Contratos detalhados (SCONTRATO)
A API `/contracts/:id/detailed` retorna:
- Quem e o aluno (`consumers`)
- Quem e o responsavel financeiro (`person`)
- Quais servicos compoe o contrato (`purchases`)
- Dia de vencimento (`dueDate`)
- Status real (`status`: active/deleted)

Isso e MUITO mais rico que o servicos_historico, que so tem linhas de cobranca.

### 7.3 Faturas reais (SPARCELA)
A API `/contracts/:id/invoices` retorna cada fatura/parcela com:
- Data de vencimento
- Valor total (compras - descontos)
- Status (paid/pending/cancelled)
- Detalhes de pagamento

Isso substitui a necessidade de calcular parcelas a partir do servicos_historico.

### 7.4 Bolsas por aluno (SBOLSAALUNO)
O contrato detalhado mostra os descontos aplicados em cada compra (`purchases`).
Isso da a bolsa real por aluno, nao apenas o catalogo.

### 7.5 Reconciliacao de IDs
Usando a API, podemos criar uma tabela de mapeamento:
- API idPerson (= servicos_historico.id_pessoa) -> student_code_unico.code_unif (RA)
- Isso resolve o gap de IDs entre servicos_historico e enrollment

---

## 8. Proximos Passos Recomendados

### Imediato (esta semana)
1. **Decidir:** Vamos usar a API como fonte complementar ou reescrever as views usando API?
2. **Reimportar no TOTVS:** SHABILITACAOFILIAL (com turnos Manha/Tarde para EI UN2)
3. **Reimportar:** SHABMODELOPGTO (depende do item acima)

### Curto prazo (proximas 2 semanas)
4. **Reescrever SCONTRATO** usando dados do banco + validacao API
5. **Criar SPARCELA** usando faturas do banco (ou da API)
6. **Validar SBOLSAALUNO** contra descontos da API

### Medio prazo (apos views prontas)
7. **Importar financeiro** no TOTVS na ordem correta
8. **Validar** dados importados contra API
9. **Documentar** divergencias para ajuste manual

---

## 9. Glossario para Referencia Rapida

| Termo | Significado |
|-------|-------------|
| MENS / MENSALIDADE | Mensalidade escolar (12 parcelas, unica dedutivel no IR) |
| ALIM / ALIMENTACAO | Servico de alimentacao (12 parcelas) |
| MAT / MDIDAT | Material didatico (12 parcelas) |
| 1oPARC / 1oMENS | Rematricula (1a parcela do ciclo, paga antes do ano comecar) |
| ANUID / ANUIDADE | Mensalidade paga de uma vez (valor anual em parcela unica) |
| RA | Registro Academico - numero unico do aluno |
| CODPLANOPGTO | Codigo do plano de pagamento no TOTVS |
| CODCONTRATO | Codigo do contrato no TOTVS |
| Coligada | Sempre 1 (Escola do Futuro tem 1 coligada) |
| CODTIPOCURSO | Sempre 1 |
| hash (API) | Identificador unico do contrato no Gennera = campo `contrato` no servicos_historico |
| idPerson (API) | ID da pessoa no Gennera = campo `id_pessoa` no servicos_historico |
| idEnrollment (API) | ID da matricula no Gennera = campo `id_matricula` no servicos_historico |
