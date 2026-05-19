# 01 - Arquitetura TOTVS RM Educacional

**Versao:** 1.0 | **Data:** 2026-05-19 | **Projeto:** EDF Migracao Gennera -> TOTVS RM

---

## 1. Visao Geral do TOTVS RM Educacional

TOTVS RM e um ERP modular para gestao de instituicoes educacionais. A migracao EDF utiliza:

- **Modulo Educacional (Academico):** matriculas, turmas, cursos, disciplinas, notas, frequencia
- **Modulo Financeiro Educacional:** contratos, planos de pagamento, parcelas, bolsas, servicos
- **Modulo Financeiro Classico (legacy):** lancamentos contabeis via FLAN e cadastro de responsaveis via FCFO

A instancia EDF esta em **HOMOLOGACAO** no servidor:
- Host: `associacaoescola200767.rm.cloudtotvs.com.br:10207`
- Auth: Basic Auth HTTPS (certificado valido)

---

## 2. Hierarquia Academica

```
COLIGADA (1)
  |
  +-- FILIAL (1)
       |
       +-- CURSO (ex: Basico, Fundamental, Medio)
            |
            +-- HABILITACAO (ex: EF1, EF2, EM1, EM2, EM3)
                 |
                 +-- GRADE (Matriz curricular)
                      |
                      +-- TURMA (ex: 6A, 7B, 1A-Med)
                           |
                           +-- ALUNO (matriculado)
```

**Conceitos chave:**

- **CODCOLIGADA:** Identificador da empresa (1 = Escolado Futuro)
- **CODFILIAL:** Filial da coligada (1 = padrão)
- **CODCURSO:** Codigo texto do curso (ex: "BASICO", "FUNDAMENTAL")
- **CODHABILITACAO:** Codigo texto da habilitacao (ex: "EF1", "EM1")
- **CODGRADE:** Codigo texto da grade curricular
- **CODTURMA:** Identificador único da turma
- **RA:** Registro Academico do aluno (chave em SALUNO, SMATRICULA, etc.)

---

## 3. Hierarquia Financeira - Contrato + Parcelas

```
SSERVICO (Servico: MENS, ALIM, MAT)
  |
SPLANOPGTO (Plano de Pagamento)
  |
  +-- SHABMODELOPGTO (Ligacao Habilitacao + Plano)
       |
SCONTRATO (1 consolidado por aluno+curso+habilitacao+ano)
  |
  +-- SPARCELA (PARCELA 1..12 ou 1..36)
       |
       +-- SLAN (Lancamento financeiro, se gerado via SaveRecord/wsFin)

         Para cada PARCELA:
           - CODCOLIGADA, RA, CODCONTRATO (FK)
           - IDPERLET (periodo letivo = ano letivo)
           - CODSERVICO (ref SSERVICO)
           - PARCELA (1, 2, 3, ..., 12 ou 36)
           - COTA (sempre 1 ate agora)
           - VALOR (montante da parcela)
           - DTVENCIMENTO (data due date)
           - DTCOMPETENCIA (mes de competencia)
           - CODCFO (responsavel financeiro FCFO)
```

**Conceitos chave:**

- **IDPERLET:** Identificador numerico do periodo letivo:
  - 2023 -> 15
  - 2024 -> 18 (EF1) / 19 (EM)
  - 2026 -> 1 / 2 (testes homolog)
  - Mapeado em SPLETIVO (tabela de periodos)

- **IDHABILITACAOFILIAL:** Identificador composto de (CODCOLIGADA, CODFILIAL, CODCURSO, CODHABILITACAO)
  - Precisa estar cadastrado antes de SMATRICULA

- **SCONTRATO:** Consolidado por (RA, CODCURSO, CODHABILITACAO, IDPERLET)
  - 1 contrato = N parcelas (MENS, ALIM, MAT)
  - Nao duplica por servico na EDF

- **SPARCELA:** Granularidade de 1 parcela = 1 servico x 1 numero
  - Maria 2024 (EM): ~36 parcelas (MENS 1-12, ALIM 1-12, MAT 1-12)

- **SBOLSAALUNO:** Descontos individuais (bolsa integral, bolsa 50%, etc.)
  - FK: CODCOLIGADA, RA, CODCONTRATO, NOMEBOLSA, CODSERVICO
  - DESCONTO (valor ou percentual)

---

## 4. Hierarquia Financeira - Lancamentos (FLAN) [Legacy]

```
FCFO (Responsavel Financeiro = PPESSOA)
  |
FLAN (Lancamento Contabil)
  |
  Campos posicionais (De/Ate):
    - Coligada (pos 1-6)
    - Tipo documento (7-8)
    - Numero (9-25)
    - Parcela (26-28)
    - Serie (29-32)
    - etc.
```

FLAN nao precisa ser importado se usar `wsFin.SaveLancamento` (SOAP) em vez de arquivo posicional.

---

## 5. Tabelas Mestres Obrigatorias (ordem importacao)

### Fase 1: Infraestrutura
1. **SINSTITUICAO** - Instituicao/Unidade

### Fase 2: Estrutura Academica
2. **SCURSO** - Curso
3. **SPLETIVO** - Periodo letivo (ano, semestre)
4. **SPERIODO** - Periodo (bimestre, trimestre)
5. **SGRADE** - Grade curricular
6. **SDISCIPLINA** - Disciplina
7. **SHABILITACAO** - Habilitacao/Serie

### Fase 3: Pessoas
8. **PPESSOA** - Pessoa (aluno, professor, responsavel)

### Fase 4: Matriculas
9. **SMATRICULA** - Matricula academica
10. **SMATRICPL** - Matricula em disciplina

### Fase 5: Professores + Turmas
11. **STURMA** - Turma
12. **STURMADISC** - Disciplina na turma
13. **SPROFESSORTURMA** - Professor na turma

### Fase 6: Financeiro - Mestres
14. **SSERVICO** - Servico (MENS, ALIM, MAT)
15. **SPLANOPGTO** - Plano de pagamento
16. **SHABMODELOPGTO** - Ligacao plano-habilitacao
17. **FCFO** - Responsavel financeiro (opcional, pode vir de PPESSOA)

### Fase 7: Financeiro - Contratos
18. **SCONTRATO** - Contrato de aluno
19. **SPARCELA** - Parcelas

### Fase 8: Bolsas (opcional)
20. **SBOLSA** - Tipo de bolsa
21. **SBOLSAALUNO** - Bolsa por aluno

---

## 6. Diferenca: Tabelas "Edu*" vs Posicionais vs DataServers

### Tabelas TOTVS (Oracle backend):
- **S*** = Tabelas do Educacional (SCURSO, SMATRICULA, SPARCELA, etc.)
- **F*** = Tabelas do Financeiro classico (FLAN, FCFO, etc.)
- **G*** = Tabelas de Referencia (GCOLIGADA, GFILIAL, etc.)
- **P*** = Pessoa (PPESSOA, PSALDO, etc.)

### DataServers SOAP (wrappers para SQL):
- **Edu{Tabela}Data** = Interface SOAP para tabela S* educacional
  - Exemplo: `EduContratoData` -> SCONTRATO
  - Operacoes: ReadView, ReadRecord, SaveRecord, DeleteRecord
  - Status: alguns sofrem filtro de perfil (Edu AlunoData retorna 0 mesmo com dados)

### Formato de entrada em SaveRecord:
- **XML puro** (UTF-8)
- Tag raiz = nome da tabela (ex: `<SPARCELA>`)
- Sem padding manual, sem encoding ANSI

---

## 7. Contexto SOAP Obrigatorio

Toda chamada SOAP precisa do Contexto:

```
CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1
```

**Armadilha critica:** NUNCA passar `CODSISTEMA=S` no Contexto de chamadas SOAP - quebra o nivel ensino e força -1, causando erro.

Usar `CODSISTEMA` SO na view/query SQL se necessario, nao em Contexto SOAP.

---

## 8. Conceitos Associados

### IDPERLET (Index de Periodo Letivo)
Cada ano/semestre tem ID numerico no RM:
- Nao é CODPERLET (texto)
- Usado como FK em SPARCELA, SCONTRATO, etc.
- Mapeado via SPLETIVO.IDPERLET

### IDHABILITACAOFILIAL
Combinacao unica de (CODCOLIGADA, CODFILIAL, CODCURSO, CODHABILITACAO).
- Precisa estar criada antes de qualquer SMATRICULA dessa habilitacao
- FK em SMATRICULA, SHABILITACAOFILIAL, etc.

### CODNIVELENSINO
Nivel de ensino (1=Basico, 2=Fundamental, 3=Medio, etc.).
- Vinculado a STIPOCURSO
- Obrigatorio em Contexto para algumas operacoes

### STATUS no SCONTRATO
- N = Normal (nao cancelado)
- S = Cancelado

---

## 9. Documentos de Referencia

- **Templates TOTVS:** `docs/Lista de tabelas/` (48 HTML com schema completo)
- **API Descoberta:** `docs/API_TOTVS_DESCOBERTA.md` (endpoints, DataServers, exemplos)
- **Estudo de API:** `data/estudo/04_totvs_api_e_docs.md` (mapeamento de operacoes SOAP)
- **Este documento:** sao de verdade

---

## 10. Legenda de Siglas

| Sigla | Significado |
|-------|------------|
| RM | TOTVS RM (ERP) |
| EDF | Escola do Futuro |
| TBC | TOTVS Business Cloud |
| SOAP | Simple Object Access Protocol (WebService XML) |
| WS | WebService |
| API | Application Programming Interface |
| DataServer | Wrapper SOAP para leitura/escrita de tabelas |
| PK | Primary Key (chave primaria) |
| FK | Foreign Key (chave estrangeira) |
| IDPERLET | ID do Periodo Letivo |
| IDHABFILIAL | ID da Habilitacao + Filial |
| RA | Registro Academico (aluno) |
| MENS | Mensalidade |
| ALIM | Alimentacao |
| MAT | Material didatico |

---

**Proximos arquivos:** 02_api_soap_tbc.md, 03_modelo_dados.md, etc.
