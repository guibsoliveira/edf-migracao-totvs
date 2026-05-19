# 01 - Mapeamento de Entidades Gennera <-> TOTVS RM

> Tabela de-para COMPLETA. Cada linha mostra como uma entidade do Gennera
> vira uma entidade no TOTVS RM Educacional, com cardinalidade, view
> existente e regra de negocio que conecta os dois.

**Legenda views:**
- ✓ = view ja existe e funciona (`export.*` ou `export_v2.*`)
- ⚠ = view existe mas tem bug conhecido
- 🔧 = view existe em v1, refatoracao v2 em andamento (Isac)

---

## 1. Pessoas e identificadores

| Entidade conceitual | Gennera (origem) | TOTVS RM (destino) | Card. | View | Trigger | Regra |
|----------------------|-------------------|---------------------|-------|------|---------|-------|
| Aluno | `person_fisica` + `student_code_unico.code_unif` (RA YYYYNNNNNN) | `SALUNO` (PK = CODCOLIGADA+RA) | 1:1 | ✓ `export.ppessoa` 🔧 | Inscricao novo aluno | RA Gennera (code_unif) copia direto para SALUNO.RA. 48% sem CPF (menores) - usar CPF do responsavel financeiro |
| Responsavel financeiro | `cliente_fornecedor` (codcfo) + `person_fisica` (CPF) | `FCFO` (PK = CODCOLIGADA+CODCFO) | N:1 | ✓ `export.fcfo` / `export_v2.fcfo` | Novo contrato | CODCFO Gennera mapeia 1:1 para FCFO.CODCFO. Quando ja existe (752 de 9.166 pessoas tem codcfo), nao recriar |
| Responsavel academico | `enrollment.id_academic_responsible` -> `person_fisica` | `PPESSOA` (referenciado em SHABILITACAOALUNO) | 1:N | 🔧 `export.ppessoa` | Matricula nova | Pode ser o mesmo do financeiro. Se Gennera nao tem, usar resp.financeiro como fallback |

---

## 2. Estrutura academica (mestres)

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| Coligada | (constante EDF) | `GCOLIGADA` (CODCOLIGADA=1) | - | - | Fixo | Sempre 1, ja cadastrado |
| Filial | `enrollment.id_institution` (320 ou 321) | `GFILIAL` (CODFILIAL=1 ou 2) | 1:1 | (cadastro manual) | Fixo | 320 = UN1 = CODFILIAL 1; 321 = UN2 = CODFILIAL 2 |
| Periodo letivo | `enrollment.academic_calendar` (texto "2021"-"2026") | `SPLETIVO` (CODPERLET + IDPERLET interno) | 1:1 | 🔧 `export.spletivo` | Novo ano | Ja mapeado em RM: 2023=15, 2024=18 (EF) / 19 (EM), 2026=1/2. **2022 NAO EXISTE - criar antes** |
| Curso | `enrollment.degree_type` (texto) | `SCURSO` (CODCURSO: EI, EF1, EF2, EM) | N:1 | ✓ `export.scurso` | Cadastro inicial | 4 cursos EDF: EI, EF1, EF2, EM. Mapping por parsing de nome |
| Habilitacao | inference via `class.degree_name` / `enrollment` | `SHABILITACAO` (CODHABILITACAO: 1,2,3,4,...) | 1:N | ✓ `export.shabilitacao` | Estrutura academica | 16 habilitacoes (K1,K2,N2,N3 + 1-5 EF1 + 6-9 EF2 + 1-3 EM) |
| Grade curricular | inferida (class + enrollment_record) | `SGRADE` (CODGRADE = ano letivo geralmente) | 1:1 | ✓ `export.sgrade` | Novo ano | Grade = ano letivo no padrao EDF (2022, 2023...) |
| Disciplina | `academic.subject_code_gennera` (numerico) | `SDISCIPLINA` (CODDISCIPLINA texto, 4 chars) | 1:1 | ✓ `export.sdisciplina` | Definicao grade | Mapeamento numerico Gennera -> codigo texto TOTVS. Tabela lookup necessaria |
| Habilitacao + Filial | derivada (curso+hab+filial+ano) | `SHABILITACAOFILIAL` (IDHABILITACAOFILIAL auto) | 1:1 | ✓ `export.shabilitacaofilial` | Pre-requisito SMATRICULA | Combinacao critica. Maria 2024 EM 3a Serie UN1 -> IDHABILITACAOFILIAL=7 |
| Etapas avaliativas | sistema implicito (P1/P2/P3/REC) | `SETAPAS` + `SMODETAPAPLETIVO` | 1:N | ✓ `export.setapas` | Inicio ano | 3 a 4 etapas por ano por habilitacao |

---

## 3. Turmas

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| Turma | `class` (id_class, name "6A"/"7B"/"3M") | `STURMA` (CODTURMA) | 1:1 | ✓ `export.sturma` | Novo ano letivo | Nome classe Gennera -> CODTURMA. Sufixos UN2 EI: IA=Integral, MB=Manha, TC=Tarde |
| Turma + Disciplina | implicit via enrollment_record | `STURMADISC` (CODTURMA + CODDISCIPLINA + CODPROFESSOR) | 1:N | ✓ `export.sturmadisc` | Definicao grade horaria | Quais disciplinas a turma tem + professor de cada |

---

## 4. Financeiro - planos

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| Servico | `servicos.item` distinct + `/items` API | `SSERVICO` (CODSERVICO + NOME) | 1:1 | ✓ `export_v2.sservico` | Cadastro inicial | Padrao EDF: MENS, ALIM, MAT, 1aMENS, ANUIDADE, REMATRIC. Valores fixos no mestre. |
| Plano de pagamento | inference do `contract` + servico + ano | `SPLANOPGTO` (CODPLANOPGTO: AAANN, ex "241003") | 1:N | ✓ `export_v2.splanopgto` | Novo ano/curso | Codigo: {ano2}{filial}{seq3}. Ex: 2024 + Filial 1 + EM3 = 241003. 112 planos historicos. |
| Parcela do plano | inferido (parcelas padrao MENS x12, ALIM x12, etc.) | `SPARCPLANO` (CODSERVICO + numero parcela) | 1:N | ✓ `export_v2.sparcplano` | Estrutural | Consultor TOTVS sugeriu pular. Mantido por baixo custo. |
| Habilitacao + Plano | derivada (qual plano para qual habilitacao) | `SHABMODELOPGTO` | 1:N | ✓ `export_v2.shabmodelopgto` | Plano novo | Pre-requisito CRITICO para SCONTRATO. 9 registros em RM homolog. |
| Bolsa (catalogo) | `servicos.DescBolsas` distinct | `SBOLSA` (NOMEBOLSA) | 1:1 | ✓ `export.sbolsa_nova` | Cadastro inicial | Catalogo de tipos de bolsa (Integral, 50%, Funcionario, etc.) |
| Bolsa + Periodo | derivada | `SBOLSAPLETIVO` (NOMEBOLSA + CODPERLET) | 1:N | ✓ `export.sbolsapletivo_nova` | Bolsa em vigor | Vigencia da bolsa por periodo letivo |

---

## 5. Vinculos academicos

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| Matricula | `enrollment` (id_enrollment) | `SMATRICULA` (RA + IDPERLET + CODCURSO + CODHABILITACAO) | 1:N (1 aluno tem N matriculas em anos diferentes) | ✓ `export.smatricula` | Inscricao | RA + ano letivo. Status: active/cancelled/transfer |
| Matricula em plano | derivada (matricula + plano) | `SMATRICPL` (PK composto) | 1:N | ✓ `export.smatricpl` | Confirmacao plano | Liga matricula academica ao plano de pagamento. Ponte critica entre acad e financeiro |
| Habilitacao + Aluno | derivada | `SHABILITACAOALUNO` (RA + IDHABILITACAOFILIAL) | 1:N (aluno pode estar em multiplas habilitacoes ao longo dos anos) | ✓ `export.shabilitacaoaluno` | Novo ano | Registro do percurso academico do aluno |

---

## 6. Financeiro - contratos e parcelas

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| Contrato | `contract` (id_contract) - 13.283 contratos | `SCONTRATO` (CODCONTRATO + CODCOLIGADA) | **4:1** (decisao EDF: consolidar) | ✓ `export.scontrato` / `export_v2.scontrato` | Contrato assinado | Gennera tem 4 contratos por aluno/ano (REMATRIC, MENS, ALIM, MAT). TOTVS: 1 SCONTRATO consolidado com N parcelas. Decisao tomada (consultor + EDF). |
| Parcela | `invoice` (id_invoice) - 99.408 | `SPARCELA` (IDPARCELA + FK CODCONTRATO+CODSERVICO+PARCELA) | 1:1 | ⚠ `export_v2.sparcela` (BUG: perde ALIM/MAT) | Contrato criado | Cada invoice Gennera = 1 SPARCELA. Diego 2022: 37 SPARCELAs (1 REMATRIC + 12 MENS + 12 ALIM + 12 MAT) |
| Bolsa do aluno | `servicos` (DescBolsas por aluno+servico) | `SBOLSAALUNO` (RA + CODCONTRATO + NOMEBOLSA + CODSERVICO) | 1:N | ✓ `export_v2.sbolsaaluno` | Bolsa concedida | UNICA fonte detalhada (servicos = 545 linhas, nao contract.discounts) |

---

## 7. Lancamentos (legacy / financeiro classico)

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| FLAN | nao existe diretamente (derivado de invoice) | `FLAN` (CODLAN, formato posicional 130 campos) | 1:1 | ✓ `export_v2.flan` (posicional) | SaveRecord SPARCELA | Idealmente gerado AUTOMATICAMENTE pelo RM apos SPARCELA. Plano B: `wsFin.SaveLancamento` |
| SLAN | `payment` (63.266) + invoice | `SLAN` (IDLAN + FK CODCONTRATO+IDPARCELA) | 1:1 ou 1:N por parcela | ✓ `export_v2.slan` | Pagamento recebido | Detalhe de quitacao. Tambem gerado auto pelo RM. Para baixa de pagamento usar `wsFin.BaixaLancamento` |

---

## 8. Avaliacao (escopo secundario - opcional para piloto)

| Entidade | Gennera | TOTVS | Card. | View | Trigger | Regra |
|----------|---------|-------|-------|------|---------|-------|
| Provas | `exam` (59.882) | `SPROVAS` | 1:1 | ✓ `export.sprovas` | Avaliacao lancada | Padrao tipo: P1, P2, P3, REC |
| Notas | `grade` (796.228, texto) | `SNOTAS` (numerico 0-10) | 1:1 | ✓ `export.snotas` (via shistdisccol) | Nota lancada | Texto Gennera "8.5" / "A" / "---" -> numeric. Conversao por regex |
| Frequencia | `attendance` (296.054) | `SFREQUENCIA` | 1:1 | ✓ `export.sfrequencia` | Chamada diaria | Opcional 1a fase. Volume alto |
| Historico aluno | `enrollment_record` (154.826) | `SHISTALUNOCOL` / `SHISTDISCCOL` | 1:1 | ✓ `export.shistalunocol`, `export.shistdisccol` | Fim de ano | Consolidado por disciplina e por aluno |

---

## Resumo de cobertura

**Total: ~27 entidades mapeadas**

| Status | Quantidade |
|--------|-----------|
| ✓ View pronta e funcional | 23 |
| 🔧 View em refatoracao (Isac) | 3 (ppessoa, spletivo, possivelmente outros) |
| ⚠ View com bug conhecido | 1 (sparcela_v2 perde ALIM/MAT) |
| Faltando | 0 |

**Decisoes ja tomadas:**

1. **Granularidade SCONTRATO:** 1 consolidado por aluno+ano (NAO replicar os 4 do Gennera)
2. **SPARCPLANO:** manter view mas pode pular import (consultor disse opcional)
3. **FLAN/SLAN:** preferir geracao automatica pelo RM apos SPARCELA SaveRecord (plano B `wsFin.SaveLancamento`)
4. **Avaliacao (notas/frequencia):** fora do escopo do primeiro piloto

**Pendentes:**

1. Bug `export_v2.sparcela` perdendo ALIM/MAT - investigar e corrigir
2. View PPESSOA v2 (Isac em andamento)
3. Bandeiras de Visa/Master/etc. nao mapeadas em TOTVS (so na recorrencia)

---

## Referencias

- `knowledge/gennera/03_modelo_dados.md` - estrutura origem
- `knowledge/totvs/03_modelo_dados.md` - estrutura destino
- `knowledge/totvs/06_estado_atual.md` - o que ja esta no RM homolog
- `views/financeiro/v2/*.sql` - codigo de transformacao ja implementado
