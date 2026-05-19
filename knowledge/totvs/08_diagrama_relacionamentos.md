# 08 - Diagrama de Relacionamentos - Tabelas Principais

**Versao:** 1.0 | **Data:** 2026-05-19

---

## Hierarquia Academica

`
SCOLIGADA (1 = Escolado Futuro)
  |
  GFILIAL (1 = Filial Padrao)
  |
  SCURSO (ex: FUNDAMENTAL, MEDIO)
  |
  SHABILITACAO (ex: EF1, EF2, EM1, EM2, EM3)
    |
    SGRADE (Matriz Curricular)
    |
    STURMA (ex: 6A, 7B, 1A-Med)
    |
    SMATRICULA (Aluno em turma, periodo letivo)
      |
      SMATRICPL (Aluno + Disciplina)
      |
      SNOTAS (Avaliacao)

SPLETIVO (Periodo Letivo: 2023, 2024, 2026)
  |
  IDPERLET (15 para 2023, 18/19 para 2024, 1/2 para 2026)
  |
  SMODETAPAPLETIVO (Etapas de avaliacao)
    |
    SPROVAS (Provas)
    |
    SNOTAS (Notas aluno)
    |
    SNOTAETAPA (Consolidacao etapa)
`

### Cardinalidade

`
1 COLIGADA : N FILIAL
1 FILIAL : N CURSO
1 CURSO : N HABILITACAO
1 HABILITACAO : N GRADE
1 HABILITACAO : N TURMA (via TURNO)
1 TURMA : N SMATRICULA (aluno)
1 SMATRICULA : N SMATRICPL (disciplina)
1 SMATRICPL : N SNOTAS
`

### Tabelas Edu* (com DataServer SOAP)

- [ ] SCURSO (ReadView bloqueado, usar view export_v2)
- [x] SHABILITACAO (ReadView bloqueado, usar view export_v2)
- [x] SGRADE (ReadView bloqueado, usar view export_v2)
- [x] STURMA (ReadView bloqueado, usar view export_v2)
- [ ] SALUNO (ReadView bloqueado, usar view export_v2)
- [x] SMATRICULA (ReadView bloqueado, usar view export_v2)
- [x] SMATRICPL (EduMatricPLData funciona - SaveRecord OK)
- [ ] SDISCIPLINA (ReadView bloqueado, usar view export_v2)
- [x] SPLETIVO (ReadView bloqueado, usar view export_v2)

---

## Hierarquia Financeira - Contratos + Parcelas

`
SSERVICO (MENS, ALIM, MAT)
  |
  [1 servico para N parcelas]
  |
SPLANOPGTO (Plano pagamento: 241003 = EM 2024)
  |
  SHABMODELOPGTO (Liga plano a habilitacao/turno)
  |
  [para cada aluno na habilitacao]
  |
SCONTRATO (1 por aluno + ano + habilitacao)
  [IDPERLET: 18=2024-EF, 19=2024-EM]
  |
  SPARCELA (1..36 parcelas = MENS(1-12) + ALIM(1-12) + MAT(1-12))
    |
    [cada parcela gera automaticamente]
    |
    SLAN (Lancamento financeiro)
`

### Cardinalidade

`
1 SSERVICO : N SPARCELA (por contrato)
1 SPLANOPGTO : N SHABMODELOPGTO
1 SHABMODELOPGTO : N SCONTRATO (alunos matriculados)
1 SCONTRATO : N SPARCELA
1 SPARCELA : 1 SLAN (gerado automatico)
1 SSERVICO : 1 valor padrao
`

### FK Criticas

`
SPARCELA.CODCONTRATO -> SCONTRATO.CODCONTRATO (obrigatorio)
SPARCELA.SERVICO -> SSERVICO.NOME (obrigatorio)
SPARCELA.CODCOLCFO -> GCOLIGADA (obrigatorio)
SPARCELA.CODCFO -> FCFO.CODFFO (obrigatorio)

SCONTRATO.RA -> SALUNO.RA (obrigatorio)
SCONTRATO.CODCURSO -> SCURSO.CODCURSO (obrigatorio)
SCONTRATO.CODHABILITACAO -> SHABILITACAO.CODHABILITACAO (obrigatorio)
SCONTRATO.CODGRADE -> SGRADE.CODGRADE (obrigatorio)
SCONTRATO.CODPERLET -> SPLETIVO.CODPERLET (obrigatorio)
SCONTRATO.CODPLANOPGTO -> SPLANOPGTO.CODPLANOPGTO (opcional)

SPLANOPGTO.CODPERLET -> SPLETIVO.CODPERLET (obrigatorio)
SPLANOPGTO.CODTIPOCURSO -> STIPOCURSO.CODTIPOCURSO (obrigatorio)

SHABMODELOPGTO.CODPLANOPGTO -> SPLANOPGTO.CODPLANOPGTO (obrigatorio)
SHABMODELOPGTO.CODCURSO -> SCURSO.CODCURSO (obrigatorio)
SHABMODELOPGTO.CODHABILITACAO -> SHABILITACAO.CODHABILITACAO (obrigatorio)
`

---

## Hierarquia Financeira - Lancamentos (Legacy FLAN)

`
FCFO (Responsavel Financeiro - tabela LEGACY)
  |
  [opcional, pode usar PPESSOA]
  |
FLAN (Lancamento Contabil - gerado automatico)
  |
  [posicional ou wsFin.SaveLancamento]
  |
  RESULTADO: Contabilidade processada
`

### Formato FLAN

FLAN segue layout posicional (NUNCA usar SaveRecord):

`
Pos 1-6:   Coligada
Pos 7-8:   Tipo Documento
Pos 9-25:  Numero
Pos 26-28: Parcela
Pos 29-32: Serie
...
`

**Alternativa:** wsFin.SaveLancamento (SOAP)

---

## Hierarquia Pessoas

`
PPESSOA (Pessoa - aluno, professor, responsavel)
  |
  +-- SALUNO (quando e aluno)
  |     |
  |     SMATRICULA (matricula academica)
  |
  +-- SPROFESSOR (quando e professor)
  |     |
  |     SPROFESSORTURMA (professor na turma)
  |
  +-- SRESPONSAVEL (quando e responsavel)
  |     |
  |     [link financeiro opcional]
  |
  +-- FCFO (quando e CPF financeiro - LEGACY)
`

### Cardinalidade

`
1 PPESSOA : 1 SALUNO (opcional)
1 PPESSOA : N SMATRICULA
1 PPESSOA : 1 SPROFESSOR (opcional)
1 PPESSOA : 1 FCFO (opcional, LEGACY)
`

### FK Criticas

`
SALUNO.CODPESSOA -> PPESSOA.CODPESSOA (obrigatorio)
SPROFESSOR.CODPESSOA -> PPESSOA.CODPESSOA (obrigatorio)
SMATRICULA.RA -> SALUNO.RA (obrigatorio)
SPROFESSORTURMA.CODPROFESSOR -> ... (obrigatorio)
FCFO.CODPESSOA -> PPESSOA.CODPESSOA (opcional)
`

---

## Hierarquia Avaliacao

`
SPLETIVO (Periodo Letivo)
  |
  SETAPAS (Etapas de avaliacao: 1, 2, 3)
    |
    SMODETAPAPLETIVO (Modelo etapa - tipo avaliacao)
      |
      SPROVAS (Provas aplicadas)
        |
        SNOTAS (Notas aluno x prova)
          |
          SNOTAETAPA (Consolidacao etapa - media)
`

### Cardinalidade

`
1 SPLETIVO : N SETAPAS
1 SETAPAS : N SMODETAPAPLETIVO
1 SMODETAPAPLETIVO : N SPROVAS
1 SPROVAS : N SNOTAS (por aluno)
1 SETAPAS : N SNOTAETAPA (por aluno)
`

---

## Mapeamento IDPERLET (Critico)

| Ano | Tipo | IDPERLET | CODPERLET | Status |
|-----|------|----------|-----------|--------|
| 2023 | Todos | 15 | 2023 | OK |
| 2024 | EF | 18 | 2024 | OK (Maria) |
| 2024 | EM | 19 | 2024 | OK (Maria) |
| 2026 | Teste 1 | 1 | 2026 | OK |
| 2026 | Teste 2 | 2 | 2026 | OK |
| 2022 | - | NAO EXISTE | 2022 | Nao criar |

**Acao:** Usar CODPERLET para lookup de IDPERLET via SPLETIVO.

---

## Tabelas Bloqueadas por Filtro Perfil

Estas retornam COUNT=0 mesmo com dados existentes:

`
EduAlunoData (SALUNO)
EduCursoData (SCURSO)
EduHabilitacaoData (SHABILITACAO)
EduGradeData (SGRADE)
EduPLetivoData (SPLETIVO)
EduServicoData (SSERVICO)
EduTurmaData (STURMA)
EduFilialData (GFILIAL)
EduPessoaData (PPESSOA)
EduTurmaDiscData (STURMADISC)
EduTipoCursoData (STIPOCURSO)
EduSubTurmaData (SSUBURMA)
EduResponsavelContratoData (NAO existe)
`

**Solucao:** Usar views export_v2 via PostgreSQL ou fallback para ReadView em DataServers que funcionam.

---

## Tabelas Funcionais (Sem Bloqueio)

`
EduContratoData (SCONTRATO) ✓
EduParcelaData (SPARCELA) ✓
EduResponsavelData (SRESPFINANCEIRO) ✓
EduMatricPLData (SMATRICPL) ✓
EduPlanoPgtoData (SPLANOPGTO) ✓
EduHabModeloPgtoData (SHABMODELOPGTO) ✓
EduBolsaAlunoData (SBOLSAALUNO) ✓
EduBolsaData (SBOLSA) ✓
`

Estas podem ser usadas normalmente via ReadView e SaveRecord.

---

## Ordem de Dependencia para Importacao

**Fase 1: Mestres base (pre-requisito)**
`
1. SPLETIVO (periodo letivo - IDPERLET fixo)
2. SSERVICO (servicos: MENS, ALIM, MAT)
3. SPLANOPGTO (planos pagamento)
`

**Fase 2: Ligacoes (mapeam mestres)**
`
4. SHABMODELOPGTO (liga plano a habilitacao)
5. SBOLSA (tipos bolsa)
`

**Fase 3: Contratos (dependem de mestres)**
`
6. SCONTRATO (1 por aluno+ano)
7. SPARCELA (parcelas - depende SCONTRATO)
8. SBOLSAALUNO (bolsas aluno - depende SPARCELA)
`

**Fase 4: Lancamentos (gerados automatico)**
`
9. SLAN (auto-gerado por SPARCELA ou via wsFin)
10. FLAN (auto-gerado ou via TXT posicional)
`

---

## Mermaid: Fluxo Completo (Texto)

`
GCOLIGADA --[1:N]--> GFILIAL
GFILIAL --[1:N]--> SCURSO
SCURSO --[1:N]--> SHABILITACAO
SHABILITACAO --[1:N]--> SGRADE
SGRADE --[1:N]--> STURMA

SPLETIVO --[1:N]--> SCONTRATO
SSERVICO --[1:N]--> SPARCELA
SPLANOPGTO --[1:N]--> SCONTRATO
SCONTRATO --[1:N]--> SPARCELA
SPARCELA --[1:1]--> SLAN

SHABMODELOPGTO --[M:N]--> SPLANOPGTO
SHABMODELOPGTO --[M:N]--> SHABILITACAO

SBOLSAALUNO --[M:1]--> SCONTRATO
SBOLSAALUNO --[M:1]--> SPARCELA

PPESSOA --[1:N]--> SALUNO
SALUNO --[1:N]--> SMATRICULA
SMATRICULA --[1:N]--> SMATRICPL
`

---

## Notas Importantes

1. **IDPERLET nao é auto-incrementado** - valores fixos por ano
2. **SABILITACAOFILIAL precisa existir** antes de SMATRICULA (nao é SaveRecord direto)
3. **Filtro perfil bloqueia leitura de mestres** - usar views export_v2
4. **SaveRecord SPARCELA pode gerar SLAN automaticamente** (verificar com consultor)
5. **FCFO é legacy** - preferir PPESSOA como responsavel financeiro
6. **FLAN gerado automaticamente** - nao importar manualmente (deixar RM gerar)

---

**Proximos:** 09_dicionario_campos.md, 10_scripts_chamadas_soap.md, 11_estrategia_filtro_perfil.md

