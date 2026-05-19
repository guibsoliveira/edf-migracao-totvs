# 03 - Modelo de Dados TOTVS RM (Completo)

> Cobertura de TODAS as ~48 tabelas relevantes do TOTVS RM para a migracao:
> Academico (33), Financeiro Educacional (10), Financeiro Classico (3),
> Pessoa (1), Compartilhado (1).

Fonte primaria: `docs/Lista de tabelas/*.html` (templates oficiais TOTVS).

---

## 1. Hierarquia geral

```
GCOLIGADA (1 = EDF)
  GFILIAL (1=UN1, 2=UN2)
    SINSTITUICAO
    STIPOCURSO (1 = Educacao Basica)
      SCURSO (4: EI, EF1, EF2, EM)
        SHABILITACAO (16: K1,K2,N2,N3, 1o-5o, 6o-9o, 1a-3a)
          SHABILITACAOFILIAL (combinacao curso+hab+filial+IDPERLET)
            STURMA -> STURMADISC -> SDISCIPLINA -> SDISCGRADE
            SMATRICULA -> SMATRICPL -> SHABILITACAOALUNO

SPLETIVO (1 por ano: 2021-2026)
  SETAPAS -> SMODETAPAPLETIVO
    SPROVAS -> SNOTAS -> SNOTAETAPA
    SFREQUENCIA

Financeiro:
SSERVICO -> SPLANOPGTO -> SHABMODELOPGTO -> SCONTRATO -> SPARCELA
SBOLSA -> SBOLSAPLETIVO -> SBOLSAALUNO
                            |
                            -> FLAN (auto) + SLAN (auto)

Pessoas:
PPESSOA -> SALUNO + SPROFESSOR + FCFO
```

---

## 2. MODULO ACADEMICO (33 tabelas)

### Estrutura curricular

#### SINSTITUICAO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, IDINSTITUICAO
- **Funcao:** registro da instituicao de ensino EDF
- **Campos:** 10
- **View:** `export.sinstituicao`
- **Layout:** SaveRecord (XML)
- **Obrigatorios principais:** CODCOLIGADA, NOME, CGC, ENDERECO

#### SCURSO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODCURSO
- **FK:** CODTIPOCURSO
- **Funcao:** catalogo de cursos (EDF: EI, EF1, EF2, EM)
- **Campos:** 18
- **View:** `export.scurso`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO por filtro de perfil (existem na base)

#### SHABILITACAO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODCURSO, CODHABILITACAO
- **FK:** SCURSO
- **Funcao:** habilitacoes do curso (16 totais EDF: K1, K2, N2, N3, 1o-5o ano, 6o-9o ano, 1a-3a serie)
- **Campos:** 15
- **View:** `export.shabilitacao`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

#### SHABILITACAOFILIAL
- **Modulo:** Academico
- **PK:** CODCOLIGADA, IDHABILITACAOFILIAL (auto)
- **FK:** SCURSO, SHABILITACAO, GFILIAL, SPLETIVO
- **Funcao:** combinacao (curso + habilitacao + filial + periodo letivo). PRE-REQUISITO de SMATRICULA e SCONTRATO.
- **Campos:** 17
- **View:** `export.shabilitacaofilial`
- **Layout:** SaveRecord (XML)
- **Exemplo conhecido:** Maria 2024 EM 3a serie UN1 -> IDHABILITACAOFILIAL=7

#### SHABILITACAOFILIALPL
- **Modulo:** Academico
- **PK:** CODCOLIGADA, IDHABILITACAOFILIAL, CODPLANOPGTO
- **Funcao:** Habilitacao+Filial vinculada a plano de pagamento
- **Campos:** 29
- **View:** `export.shabilitacaofilialpl`
- **Layout:** SaveRecord (XML)

#### SGRADE
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODCURSO, CODHABILITACAO, CODGRADE
- **FK:** SCURSO, SHABILITACAO
- **Funcao:** matriz curricular vigente em determinado ano (geralmente CODGRADE = ano letivo)
- **Campos:** 21
- **View:** `export.sgrade`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

#### SDISCIPLINA
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODDISCIPLINA
- **Funcao:** catalogo de disciplinas (Portugues, Matematica, Ingles...)
- **Campos:** 25
- **View:** `export.sdisciplina`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

#### SDISCGRADE
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODCURSO, CODHABILITACAO, CODGRADE, CODDISCIPLINA
- **FK:** SDISCIPLINA, SGRADE
- **Funcao:** disciplinas que compoem uma grade (qual disciplina pertence a qual ano-curso)
- **Campos:** 28
- **View:** `export.sdiscgrade`
- **Layout:** SaveRecord (XML)

### Periodo letivo e calendario

#### SPLETIVO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODFILIAL, CODTIPOCURSO, CODPERLET
- **Funcao:** periodo letivo (ano, semestre). Auto-gera IDPERLET interno.
- **Campos:** 23 (8 obrigatorios)
- **View:** `export.spletivo`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO
- **IDPERLET conhecidos:** 2023=15, 2024=18(EF)/19(EM), 2026=1/2(teste). 2022 NAO EXISTE.

#### SPERIODO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODPERIODO
- **Funcao:** periodos (semestres, bimestres) dentro de um periodo letivo
- **Campos:** 8
- **View:** `export.speriodo`
- **Layout:** SaveRecord (XML)

#### SETAPAS
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODCURSO, CODHABILITACAO, CODGRADE, IDETAPA
- **Funcao:** etapas avaliativas (P1, P2, P3, REC) por habilitacao
- **Campos:** 10
- **View:** `export.setapas`
- **Layout:** SaveRecord (XML)

#### SMODETAPAPLETIVO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODFILIAL, CODTIPOCURSO, CODPERLET, IDETAPA
- **FK:** SPLETIVO, SETAPAS
- **Funcao:** etapa avaliativa instanciada num periodo letivo especifico
- **Campos:** 23
- **View:** `export.smodetapapletivo`
- **Layout:** SaveRecord (XML)

### Turmas e horarios

#### STURMA
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODFILIAL, CODTIPOCURSO, CODCURSO, CODHABILITACAO, CODGRADE, CODPERLET, CODTURMA
- **Funcao:** turma (ex: "8A", "3M", "1A-Med")
- **Campos:** 24
- **View:** `export.sturma`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO
- **Convencao EDF:** UN2 EI usa sufixos IA=Integral, MB=Matutino, TC=Tarde

#### STURMADISC
- **Modulo:** Academico
- **PK:** CODCOLIGADA + STURMA chave + CODDISCIPLINA
- **FK:** STURMA, SDISCIPLINA, SPROFESSOR
- **Funcao:** disciplinas que a turma cursa, com professor responsavel
- **Campos:** 40
- **View:** `export.sturmadisc`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

#### SHORARIO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, IDHORARIO
- **Funcao:** horarios (dia da semana, hora inicio/fim)
- **Campos:** 8
- **View:** `export.shorario`
- **Layout:** SaveRecord (XML)

#### SHORARIOTURMA
- **Modulo:** Academico
- **PK:** CODCOLIGADA + STURMA chave + IDHORARIO + CODDISCIPLINA
- **FK:** STURMA, SHORARIO, SDISCIPLINA
- **Funcao:** grade horaria de cada turma
- **Campos:** 20
- **View:** `export.shorarioturma`
- **Layout:** SaveRecord (XML)

#### SHORARIOPROFESSOR
- **Modulo:** Academico
- **PK:** CODCOLIGADA + SPROFESSOR + IDHORARIO
- **Funcao:** horario do professor
- **Campos:** 17
- **View:** (sem view)
- **Layout:** SaveRecord (XML)

### Pessoas academicas

#### SALUNO
- **Modulo:** Academico
- **PK:** CODCOLIGADA, RA
- **FK:** PPESSOA via CODPESSOA
- **Funcao:** registro do aluno (estende PPESSOA com info academica)
- **Campos:** 72 (SPESSOA_e_SALUNO consolidado)
- **View:** `export.ppessoa` (Isac refatorando), `export.salunos`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO (mas existem na base - Diego, Maria, Gustavo confirmados)

#### SPROFESSOR
- **Modulo:** Academico
- **PK:** CODCOLIGADA, CODPROFESSOR
- **FK:** PPESSOA
- **Funcao:** registro de professor
- **Campos:** 15 (SPESSOA_e_SPROFESSOR consolidado)
- **View:** `export.sprofessor`
- **Layout:** SaveRecord (XML)

#### SPROFESSORTURMA
- **Modulo:** Academico
- **PK:** CODCOLIGADA + SPROFESSOR + STURMA chave + CODDISCIPLINA
- **FK:** SPROFESSOR, STURMA, SDISCIPLINA
- **Funcao:** atribuicao professor-turma-disciplina
- **Campos:** 22
- **View:** (em export.professor_qh_enriquecido)
- **Layout:** SaveRecord (XML)

### Matriculas e vinculos

#### SMATRICULA
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + IDPERLET + CODCURSO + CODHABILITACAO
- **FK:** SALUNO, SHABILITACAOFILIAL, SPLETIVO
- **Funcao:** matricula do aluno em um curso/habilitacao em um ano
- **Campos:** 27
- **View:** `export.smatricula`
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

#### SMATRICPL
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + IDPERLET + CODCURSO + CODHABILITACAO + CODDISCIPLINA
- **FK:** SMATRICULA, SDISCIPLINA
- **Funcao:** matricula em disciplina (detalhe do SMATRICULA - "Diego cursa Portugues em 2022")
- **Campos:** 27
- **View:** `export.smatricpl`
- **Layout:** SaveRecord (XML)
- **DataServer:** EduMatricPLData (FUNCIONA via API)

#### SHABILITACAOALUNO
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + IDHABILITACAOFILIAL
- **FK:** SALUNO, SHABILITACAOFILIAL
- **Funcao:** historico do aluno na habilitacao (data inicio/fim, status)
- **Campos:** 40
- **View:** `export.shabilitacaoaluno`
- **Layout:** SaveRecord (XML)

#### SDOCALUNO
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + CODDOC
- **FK:** SALUNO
- **Funcao:** documentos do aluno (RG, certidao, comprovantes)
- **Campos:** 13
- **View:** `export.sdocaluno`
- **Layout:** SaveRecord (XML)

#### SDOCEXIGIDOS
- **Modulo:** Academico
- **PK:** CODCOLIGADA + CODCURSO + CODHABILITACAO + CODDOC
- **Funcao:** documentos exigidos por habilitacao
- **Campos:** 12
- **View:** `export.sdocexigidos`
- **Layout:** SaveRecord (XML)

### Avaliacao e historico

#### SPROVAS
- **Modulo:** Academico
- **PK:** CODCOLIGADA + IDPROVA
- **FK:** SMATRICPL, SETAPAS
- **Funcao:** provas aplicadas em uma turma/disciplina/etapa
- **Campos:** 24
- **View:** `export.sprovas`
- **Layout:** SaveRecord (XML)

#### SNOTAS
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + IDPROVA
- **FK:** SPROVAS, SALUNO
- **Funcao:** nota do aluno em uma prova
- **Campos:** 17
- **View:** `export.snotas` (via shistdisccol)
- **Layout:** SaveRecord (XML)
- **Volume:** 796k notas no Gennera (texto "8.5" -> numeric)

#### SNOTAETAPA
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + IDETAPA + CODDISCIPLINA
- **Funcao:** nota consolidada por etapa (P1, P2, P3...)
- **Campos:** 16
- **View:** (via shistdisccol)
- **Layout:** SaveRecord (XML)

#### SFREQUENCIA
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + DATA + IDHORARIO
- **FK:** SALUNO, SHORARIO, SDISCIPLINA
- **Funcao:** presenca/falta do aluno por aula
- **Campos:** 16
- **View:** `export.sfrequencia`
- **Layout:** SaveRecord (XML)
- **Volume:** 296k linhas no Gennera

#### SHISTALUNOCOL
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + ANO + SEMESTRE
- **Funcao:** historico consolidado do aluno por periodo
- **Campos:** 19
- **View:** `export.shistalunocol`
- **Layout:** SaveRecord (XML)

#### SHISTDISCCOL
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + ANO + CODDISCIPLINA
- **Funcao:** historico do aluno por disciplina (nota final, frequencia, status)
- **Campos:** 17
- **View:** `export.shistdisccol`
- **Layout:** SaveRecord (XML)

#### SOCORRENCIAALUNO
- **Modulo:** Academico
- **PK:** CODCOLIGADA + RA + IDOCORRENCIA
- **FK:** SALUNO
- **Funcao:** ocorrencias disciplinares ou medicas do aluno
- **Campos:** 18
- **View:** (sem view)
- **Layout:** SaveRecord (XML)

#### SPLANOAULA
- **Modulo:** Academico
- **PK:** CODCOLIGADA + IDPLANOAULA
- **Funcao:** plano de aula do professor
- **Campos:** 12
- **View:** (sem view, opcional)
- **Layout:** SaveRecord (XML)

---

## 3. MODULO FINANCEIRO EDUCACIONAL (10 tabelas)

### Servicos e planos

#### SSERVICO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, NOME (ou CODSERVICO em algumas versoes)
- **FK:** CODTIPOCURSO, CODCOLCXA, CODCXA, CODTDO
- **Funcao:** catalogo de servicos (MENS, ALIM, MAT, 1aMENS)
- **Campos:** 19
- **View:** `export_v2.sservico` ✓
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

#### SPLANOPGTO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, CODPERLET, CODPLANOPGTO
- **FK:** SPLETIVO, STIPOCURSO
- **Funcao:** plano de pagamento (codigo {AA}{F}{NNN}, ex: 241003 = 2024+UN1+EM3)
- **Campos:** 12
- **View:** `export_v2.splanopgto` ✓
- **Layout:** SaveRecord (XML)
- **DataServer:** EduPlanoPgtoData (FUNCIONA)
- **Estado RM:** 15 planos cadastrados (1 TESTE + 2023, 2024, 2026)

#### SPARCPLANO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA + CODPERLET + CODPLANOPGTO + CODSERVICO + numero parcela
- **FK:** SPLANOPGTO, SSERVICO
- **Funcao:** parcelas padrao do plano (MENS 1-12, ALIM 1-12)
- **Campos:** 16
- **View:** `export_v2.sparcplano` ✓
- **Layout:** SaveRecord (XML)
- **Consultor TOTVS:** sugeriu pular (opcional)

#### SHABMODELOPGTO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, CODPERLET, CODPLANOPGTO, CODTIPOCURSO, CODCURSO, CODHABILITACAO
- **FK:** SPLANOPGTO, SHABILITACAO, SGRADE
- **Funcao:** liga plano de pagamento a habilitacao (pre-requisito SCONTRATO)
- **Campos:** 9
- **View:** `export_v2.shabmodelopgto` ✓
- **Layout:** SaveRecord (XML)
- **DataServer:** EduHabModeloPgtoData (FUNCIONA)
- **Estado RM:** 9 ligacoes cadastradas

### Contratos e parcelas

#### SCONTRATO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, CODCONTRATO
- **FK:** SCURSO, SHABILITACAO, SGRADE, SALUNO (RA), SPLETIVO (CODPERLET), SPLANOPGTO, FCFO
- **Funcao:** contrato consolidado do aluno num ano (NAO replicar os 4 do Gennera)
- **Campos:** 21
- **View:** `export_v2.scontrato` ✓
- **Layout:** SaveRecord (XML)
- **DataServer:** EduContratoData (FUNCIONA)
- **Estado RM:** 7 contratos cadastrados (Maria x2, Gustavo x3, 2 testes)

#### SPARCELA
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, IDPARCELA (auto)
- **FK:** SCONTRATO, SSERVICO, FCFO
- **Funcao:** parcela individual (1 invoice Gennera = 1 SPARCELA TOTVS)
- **Campos:** 22
- **View:** `export_v2.sparcela` ⚠ (BUG: perde ALIM/MAT)
- **Layout:** SaveRecord (XML)
- **DataServer:** EduParcelaData (FUNCIONA)
- **Granularidade:** 1 parcela = 1 servico x 1 numero (Diego 2022: 37 SPARCELAs)

### Bolsas

#### SBOLSA
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, NOMEBOLSA
- **Funcao:** catalogo de bolsas (Integral, 50%, Funcionario)
- **Campos:** 17
- **View:** `export.sbolsa_nova` ✓
- **Layout:** SaveRecord (XML)
- **DataServer:** EduBolsaData (FUNCIONA)

#### SBOLSAPLETIVO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA + NOMEBOLSA + CODPERLET
- **FK:** SBOLSA, SPLETIVO
- **Funcao:** vigencia da bolsa por periodo letivo
- **Campos:** 5
- **View:** `export.sbolsapletivo_nova` ✓
- **Layout:** SaveRecord (XML)

#### SBOLSAALUNO
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, RA, CODCONTRATO, NOMEBOLSA, CODSERVICO
- **FK:** SCONTRATO, SBOLSA, SSERVICO
- **Funcao:** bolsa concedida a um aluno especifico em um servico
- **Campos:** 28 (20 obrigatorios)
- **View:** `export_v2.sbolsaaluno` ✓
- **Layout:** SaveRecord (XML)
- **DataServer:** EduBolsaAlunoData (FUNCIONA)

### Lancamentos

#### SLAN
- **Modulo:** Financeiro Educacional
- **PK:** CODCOLIGADA, IDLAN
- **FK:** SCONTRATO, SPARCELA
- **Funcao:** lancamento financeiro (quitacao da parcela)
- **Campos:** 16 (100% obrigatorios)
- **View:** `export_v2.slan` ✓
- **Layout:** SaveRecord (XML) ou geracao automatica
- **Atencao:** geralmente o RM gera SLAN automaticamente apos SaveRecord SPARCELA

---

## 4. MODULO FINANCEIRO CLASSICO (3 tabelas - legacy)

#### FCFO
- **Modulo:** Financeiro Classico (legacy)
- **PK:** CODCOLIGADA, CODFFO (ou CODCFO)
- **FK:** PPESSOA (opcional)
- **Funcao:** cadastro de cliente/fornecedor (responsavel financeiro)
- **Campos:** 130
- **View:** `export.fcfo`, `export_v2.fcfo` ✓
- **Layout:** Posicional (NAO usar SaveRecord) OU via wsDataServer se houver DS valido
- **Estado:** consultor TOTVS sugeriu evitar criacao via API - migrar pelo importador classico

#### FLAN
- **Modulo:** Financeiro Classico (legacy)
- **PK:** CODCOLIGADA, CODLAN
- **FK:** FCFO
- **Funcao:** lancamento contabil (vinculo financeiro/contabilidade)
- **Campos:** ~130 posicionais
- **View:** `export_v2.flan` (posicional)
- **Layout:** Posicional OU `wsFin.SaveLancamento`
- **Atencao:** RM gera automaticamente quando SPARCELA e criada (esperado)

#### FDADOSPGTO
- **Modulo:** Financeiro Classico
- **PK:** CODCOLIGADA, CODLAN, IDDADOSPGTO
- **FK:** FLAN
- **Funcao:** dados de pagamento associados ao lancamento (boleto, transferencia)
- **Campos:** (posicional)
- **View:** (sem view)
- **Layout:** Posicional, gerado automatico

---

## 5. MODULO PESSOA (1 tabela)

#### PPESSOA
- **Modulo:** Pessoa (cross-coligada)
- **PK:** CODPESSOA (global, NAO scoped por coligada)
- **Funcao:** cadastro central de pessoa (aluno, professor, responsavel, fornecedor - todos sao PPESSOA com extensoes)
- **Campos:** 78
- **View:** `export.ppessoa` (Isac refatorando)
- **Layout:** SaveRecord (XML)
- **ReadView via API:** BLOQUEADO

---

## 6. MODULO COMPARTILHADO (1 tabela)

#### GCCUSTO
- **Modulo:** Compartilhado (Gerencial)
- **PK:** CODCOLIGADA, CODCCUSTO
- **Funcao:** centro de custo (usado em SSERVICO e contabilidade)
- **Campos:** (variavel)
- **View:** (sem view, geralmente pre-cadastrado)
- **Layout:** SaveRecord (XML)

---

## 7. Campos criticos transversais

### IDPERLET (Periodo Letivo - index numerico)

- NAO eh CODPERLET (que e texto)
- Gerado automaticamente pelo RM ao criar SPLETIVO
- **Mapping confirmado:**

| Ano | IDPERLET | Observacao |
|-----|----------|------------|
| 2023 | 15 | EF + EM |
| 2024 | 18 | EF1 |
| 2024 | 19 | EM (Maria Valentina) |
| 2026 | 1, 2 | testes |
| 2022 | **NAO EXISTE** | precisa criar |

### IDHABILITACAOFILIAL (Habilitacao + Filial - index numerico)

- Combinacao: (CODCOLIGADA + CODFILIAL + CODCURSO + CODHABILITACAO + IDPERLET)
- Pre-requisito de SMATRICULA, SCONTRATO, SHABILITACAOALUNO
- **Exemplo conhecido:** Maria 2024 EM 3a serie UN1 -> 7

### VALOR em SPARCELA / SSERVICO / SLAN

- Tipo: NUMERICO(10,4) em SPARCELA / NUMERICO(18,4) em FLAN
- Formato XML: `<VALOR>5658,00</VALOR>` (virgula decimal pt-BR)
- Conversao: numero JS 5658 -> string `"5658,00"` no XML

### DTCOMPETENCIA vs DTVENCIMENTO

- DTVENCIMENTO: data limite para pagar (ex: 2026-01-10)
- DTCOMPETENCIA: mes de competencia (ex: 2026-01-01, sempre dia 01)
- Ambos no formato ISO `YYYY-MM-DDTHH:MM:SS`

---

## 8. Cobertura por views PostgreSQL

| Tabela TOTVS | View export | View export_v2 | Status |
|--------------|-------------|----------------|--------|
| SCONTRATO | scontrato_nova | scontrato | v2 OK |
| SPARCELA | sparcela | sparcela | ⚠ bug ALIM/MAT |
| SPLANOPGTO | splanopgto_nova | splanopgto | v2 OK |
| SHABMODELOPGTO | shabmodelopgto | shabmodelopgto | v2 OK |
| SSERVICO | sservico | sservico | v2 OK |
| SBOLSA | sbolsa, sbolsa_nova | - | v1 OK |
| SBOLSAPLETIVO | sbolsapletivo, sbolsapletivo_nova | - | v1 OK |
| SBOLSAALUNO | sbolsaaluno | sbolsaaluno | v2 OK |
| SLAN | - | slan | v2 OK |
| FLAN | - | flan | v2 posicional |
| FCFO | fcfo | fcfo | v1/v2 OK |
| SCURSO | scurso | - | v1 OK |
| SHABILITACAO | shabilitacao | - | v1 OK |
| SHABILITACAOFILIAL | shabilitacaofilial | - | v1 OK |
| SHABILITACAOFILIALPL | shabilitacaofilialpl | - | v1 OK |
| SHABILITACAOALUNO | shabilitacaoaluno | - | v1 OK |
| SGRADE | sgrade | - | v1 OK |
| SDISCIPLINA | sdisciplina | - | v1 OK |
| SPLETIVO | spletivo | - | v1 OK |
| SPERIODO | speriodo | - | v1 OK |
| STURMA | sturma | - | v1 OK |
| STURMADISC | sturmadisc | - | v1 OK |
| SHORARIO | shorario | - | v1 OK |
| SMATRICULA | smatricula | - | v1 OK |
| SMATRICPL | smatricpl | - | v1 OK |
| SETAPAS | setapas | - | v1 OK |
| SPROVAS | sprovas | - | v1 OK |
| SFREQUENCIA | sfrequencia | - | v1 OK |
| SHISTALUNOCOL | shistalunocol | - | v1 OK |
| SHISTDISCCOL | shistdisccol | - | v1 OK |
| SINSTITUICAO | sinstituicao | - | v1 OK |
| SPLANOAULA | splanoaula | - | v1 OK |
| PPESSOA / SALUNO | ppessoa, salunos | - | refatorando |
| SPROFESSOR | sprofessor, professor_qh_enriquecido | - | v1 OK |

**Total: ~34 views existentes** cobrindo praticamente todas as tabelas TOTVS. O agente Isac esta refatorando algumas.

---

## 9. Ordem de dependencia FK (resumida)

```
Fase 1 - Mestres base:
  SINSTITUICAO, SCURSO, SHABILITACAO, SGRADE, SDISCIPLINA, SPLETIVO,
  SPERIODO, SETAPAS, SSERVICO, SBOLSA

Fase 2 - Recortes anuais:
  SHABILITACAOFILIAL, SDISCGRADE, STURMA, STURMADISC, SHORARIO,
  SMODETAPAPLETIVO, SBOLSAPLETIVO, SPLANOPGTO, SHABMODELOPGTO,
  SPARCPLANO

Fase 3 - Pessoas:
  PPESSOA -> SALUNO + SPROFESSOR + FCFO

Fase 4 - Vinculos:
  SHABILITACAOALUNO, SMATRICULA, SMATRICPL, SDOCALUNO, SDOCEXIGIDOS

Fase 5 - Financeiro:
  SCONTRATO -> SPARCELA (auto-gera FLAN, SLAN) -> SBOLSAALUNO

Fase 6 - Avaliacao:
  SPROVAS -> SNOTAS, SNOTAETAPA, SFREQUENCIA, SHISTALUNOCOL, SHISTDISCCOL
```

---

## 10. Tabelas com DataServer FUNCIONAL via API

Apenas estas suportam `ReadView` SOAP sem filtro de perfil:

- `EduContratoData` (SCONTRATO) ✓
- `EduParcelaData` (SPARCELA) ✓
- `EduResponsavelData` (SRESPFINANCEIRO) ✓
- `EduMatricPLData` (SMATRICPL) ✓
- `EduPlanoPgtoData` (SPLANOPGTO) ✓
- `EduHabModeloPgtoData` (SHABMODELOPGTO) ✓
- `EduBolsaAlunoData` (SBOLSAALUNO) ✓
- `EduBolsaData` (SBOLSA) ✓

Demais Edu* (EduAlunoData, EduCursoData, EduHabilitacaoData, EduGradeData, EduPLetivoData, EduServicoData, EduTurmaData, EduFilialData, EduPessoaData, EduTurmaDiscData, EduSubTurmaData, EduTipoCursoData) tem filtro de perfil que bloqueia leitura - **mas existem na base** (validado via UI). Para escrita (SaveRecord), provavelmente NAO tem o mesmo filtro - precisa teste piloto.

---

## Referencias

- `knowledge/totvs/01_arquitetura.md` - visao geral RM
- `knowledge/totvs/02_api_soap_tbc.md` - como chamar SaveRecord
- `knowledge/totvs/04_regras_negocio.md` - regras explicitas RM
- `knowledge/totvs/05_pitfalls.md` - armadilhas
- `knowledge/totvs/08_diagrama_relacionamentos.md` - diagramas
- `knowledge/totvs/09_dicionario_campos.md` - dicionario campo-a-campo
- `docs/Lista de tabelas/*.html` - templates oficiais TOTVS
