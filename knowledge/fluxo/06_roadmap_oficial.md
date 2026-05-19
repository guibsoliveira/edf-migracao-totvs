# 06 - Roadmap Oficial de Importacao TOTVS RM

> Ordem OFICIAL de importacao (compartilhada pelo cliente em 2026-05-19).
> Esta e a sequencia que respeita TODAS as dependencias FK. Substitui
> qualquer ordenacao anterior que eu tenha proposto.

---

## Modulo ACADEMICO (1-35)

### Estruturas mestre globais

| # | Tabela | DataServer (suposto) | Status piloto |
|---|--------|----------------------|----------------|
| 1 | SINSTITUICAO | EduInstituicaoData | ✓ |
| 2 | SHORARIO | EduHorarioData | ✓ |
| 3 | SCURSO | EduCursoData | ✓ |
| 4 | SHABILITACAO | EduHabilitacaoData | ✓ |
| 5 | SPLETIVO | EduPLetivoData | ✓ |
| 6 | SDISCIPLINA | EduDisciplinaData | ✓ |

### Pessoas

| # | Tabela | DataServer | Status piloto |
|---|--------|------------|----------------|
| 7 | PPESSOA | EduPessoaData | ✓ |
| 8 | SALUNO | EduAlunoData | ✓ |
| 9 | FCFO | (FCFOData?) | ✓ |

### Historico (lancado antes de matricula?)

| # | Tabela | DataServer | Status |
|---|--------|------------|--------|
| 10 | SHISTALUNOCOL | EduHistAlunoColData | ✓ |
| 11 | SHISTDISCCOL | EduHistDiscColData | ✓ |

### Centro de custo + lancamento contabil base

| # | Tabela | DataServer | Status |
|---|--------|------------|--------|
| 12 | GCCUSTO | GCcustoData | ✓ |
| 13 | FLAN (estrutura base) | (Wsfin?) | ✓ |

### Estrutura curricular detalhada

| # | Tabela | DataServer | Status |
|---|--------|------------|--------|
| 14 | SGRADE | EduGradeData | ✓ |
| 15 | SPERIODO | EduPeriodoData | ✓ |
| 16 | SDISCGRADE | EduDiscGradeData | ✓ |
| 17 | SHABILITACAOFILIAL | EduHabilitacaoFilialData | ✓ |
| 18 | SHABILITACAOFILIALPL | EduHabilitacaoFilialPLData | ✓ |
| 19 | SDOCEXIGIDOS | EduDocExigidosData | ✓ |
| 20 | SDOCALUNO | EduDocAlunoData | ✓ |

### Professores e turmas

| # | Tabela | DataServer | Status |
|---|--------|------------|--------|
| 21 | SPROFESSOR | EduProfessorData | ✓ |
| 22 | STURMA | EduTurmaData | ✓ |
| 23 | STURMADISC | EduTurmaDiscData | ✓ |
| 24 | SPROFESSORTURMA | EduProfessorTurmaData | ✓ |
| 25 | SHORARIOTURMA | EduHorarioTurmaData | ✓ |
| 26 | SHORARIOPROFESSOR | EduHorarioProfessorData | ✓ |

### Avaliacao

| # | Tabela | DataServer | Status |
|---|--------|------------|--------|
| 27 | SETAPAS | EduEtapasData | ✓ |
| 28 | SPROVAS | EduProvasData | ✓ |
| 29 | SHABILITACAOALUNO | EduHabilitacaoAlunoData | ✓ |
| 30 | SMATRICPL | EduMatricPLData | ✓ |
| 31 | SMATRICULA | EduMatriculaData | ✓ |
| 32 | SNOTAETAPA | EduNotaEtapaData | ✓ |
| 33 | SNOTAS | EduNotasData | ✓ |
| 34 | SPLANOAULA | EduPlanoAulaData | ✓ |
| 35 | SFREQUENCIA | EduFrequenciaData | ✓ |

---

## Modulo FINANCEIRO (36-46)

| # | Tabela | DataServer | Status |
|---|--------|------------|--------|
| 36 | SSERVICO | EduServicoData | ✓ |
| 37 | SBOLSA | EduBolsaData | ✓ |
| 38 | SBOLSAPLETIVO | EduBolsaPLetivoData | ✓ |
| 39 | SPLANOPGTO | EduPlanoPgtoData | ✓ |
| 40 | **SPARCPLANO** | (sem DS) | **CANCELADA** (nao usar) |
| 41 | SHABMODELOPGTO | EduHabModeloPgtoData | ✓ |
| 42 | SCONTRATO | EduContratoData | ✓ |
| 43 | SPARCELA | EduParcelaData | ✓ |
| 44 | SBOLSAALUNO | EduBolsaAlunoData | ✓ |
| 45 | SLAN | (EduLanData?) | ✓ |
| 46 | FLAN (lancamentos finais) | wsFin.SaveLancamento | ✓ |

---

## Notas tecnicas (das exploracoes do dia)

1. **SPARCPLANO eh CANCELADA** - nao tentar criar
2. **PPESSOA antes de SALUNO antes de FCFO** - ordem 7→8→9
3. **STURMA antes de SMATRICULA** - ordem 22→31
4. **SHABILITACAOALUNO antes de SMATRICPL e SMATRICULA** - ordem 29→30→31
5. **SETAPAS+SPROVAS antes de SNOTAS** - ordem 27→28→33
6. **SSERVICO+SBOLSA+SPLANOPGTO antes de SCONTRATO** - ordem 36→37→39→42
7. **SCONTRATO antes de SPARCELA e SBOLSAALUNO** - ordem 42→43→44
8. **SLAN+FLAN sao os ultimos** - ordem 45→46

### Confirmado por API

- `SHABILITACAOFILIAL EF2-8-UN1-2022` ja existe no RM: **IDHABFIL=24**
- `SPLETIVO 2022` ja existe no RM (filial 1 e 2)
- O elemento root XML pode ser camelCase (`<SHabilitacaoFilial>`) ou uppercase (`<SPLANOPGTO>`) dependendo do DataServer
- ReadView de `EduHabilitacaoFilialData` FUNCIONA (sem filtro de perfil)
- Validacao SHABILITACAOFILIAL: `EduHabilitacaoFilialObj.ValidaContextoETurno`
- Validacao SPLANOPGTO: `EduPlanoPgtoObj.validaPlanoPgto` - exige child tables (formato exato ainda nao descoberto)

---

## Aplicacao para piloto Diego 2022

Diego ja tem SALUNO criado. Para o ano inteiro 2022:

**Itens da estrutura GERAL ja prontos (cf. roadmap "concluido"):**
1-9, 12, 14-18, 21-26 — supostamente ja importados pelo Isac, ConFIRMAR via ReadView

**Itens especificos do Diego que faltam:**
- 7,8 PPESSOA/SALUNO Diego (confirmar via SaveRecord -> Chave duplicada)
- 19,20 SDOCEXIGIDOS/SDOCALUNO Diego (opcional - documentos)
- 29 SHABILITACAOALUNO Diego 2022 (vincular ao IDHABFIL=24)
- 30 SMATRICPL Diego 2022 (disciplinas)
- 31 SMATRICULA Diego 2022 (turma 8A)
- 32,33 SNOTAETAPA/SNOTAS Diego 2022 (opcional avaliativo)
- 35 SFREQUENCIA Diego 2022 (opcional)

**Itens financeiros faltantes para Diego:**
- 39 SPLANOPGTO 221003 (8 ano 2022) ← BLOQUEIO ATUAL (There is no row at position 0)
- 41 SHABMODELOPGTO 221003→IDHABFIL=24
- 42 SCONTRATO Diego (4 contratos)
- 43 SPARCELA Diego (37 parcelas)
- 44 SBOLSAALUNO (Diego nao tem bolsa)
- 45,46 SLAN/FLAN (gerados pelo RM ou wsFin)
