# 06 - Estado Atual do RM HOMOLOGACAO

**Versão:** 2.0 | **Última atualização:** 2026-05-19 (tarde) | **Sessão:** Diego 2022 piloto

> Esta versão substitui a 1.0 que continha estimativas baseadas em testes Maria 2024. Conteúdo atualizado com auditoria sistemática via Postman + cliente Node corrigido.

---

## 1. Resumo Executivo

| Item | Valor |
|---|---|
| Instância | HOMOLOGAÇÃO (não-produção) |
| Host | `associacaoescola200767.rm.cloudtotvs.com.br:10207` |
| Versão RM | 12.1.2602.140 (relatório TOTVS) |
| Endpoints SOAP | `/wsBase`, `/wsDataServer`, `/wsFin`, `/wsEdu` |
| Auth | Basic HTTPS (cert público válido) |
| Coligada padrão | 1 |
| Filiais | 1 (UN1), 2 (UN2) |
| Nível ensino | 1 (Básica) |
| Piloto atual | Diego (RA 20142166), ano 2022, EFII 8ª série turma 8A, UN1 |

---

## 2. Bug histórico (importante para futuro)

Antes da sessão 2026-05-19 tarde, havia premissa falsa de que **"o perfil do usuário bloqueava leitura via WS"** (documentada em `11_estrategia_filtro_perfil.md`, agora DEPRECATED). 

Causa real: regex case-sensitive no cliente Node não casava `<SCURSO>` com o que o RM retorna (`<SCurso>` em PascalCase). Resultado: ReadView aparentava retornar 0 registros mesmo com dados. Fix em `scripts/smart_saver.js` (helpers `countTable` e `extractRows` case-insensitive). Detalhes em `12_descoberta_regex_bug_e_bloqueios_reais.md`.

---

## 3. ReadView — todos os DataServers funcionam

Estado pós-fix (registros confirmados na coligada 1):

| DataServer | Tabela | Count |
|---|---|---|
| EduCursoData | SCurso | 4 (EI, EF1, EF2, EM) |
| EduHabilitacaoData | SHabilitacao | 17 |
| EduGradeData | SGrade | 81 |
| EduDisciplinaData | SDisciplina | 126 |
| EduPLetivoData | SPLetivo | (2 por ano: F1 e F2) |
| EduHabilitacaoFilialData | SHabilitacaoFilial | depende ano |
| EduTurmaData | STurma | (depende ano) |
| EduTurmaDiscData | STurmaDisc | (depende turma) |
| EduDiscGradeData | SDiscGrade | (depende grade) |
| EduServicoData | SServico | 16 |
| EduPlanoPgtoData | SPlanoPgto | (depende ano) |
| EduParcPlanoData | SParcPlano | (depende plano) |
| EduHabModeloPgtoData | SHabModeloPgto | (depende plano) |
| EduAlunoData | SAluno | (depende cohort) |
| EduResponsavelData | SResponsavel | 42 (relacionamento responsável↔parcela) |
| EduMatriculaData | SMatricula | 0 (Diego 2022) |
| EduMatricPLData | SMatricPL | 0 (Diego 2022) |
| EduEtapasData | SEtapas | 48 |
| EduNotasData | SNotas | 0 |

Filtro padrão funcional: `<Tabela>.<Campo>='<valor>' AND <Tabela>.CODCOLIGADA=1`. **Filtro vazio** (`<tot:Filtro></tot:Filtro>`) volta erro "Filtro inválido" — sempre passar algo.

---

## 4. SaveRecord — bloqueio único identificado

| DataServer | Status SaveRecord | Observação |
|---|---|---|
| EduCursoData, EduHabilitacaoData, EduGradeData, EduDisciplinaData, EduDiscGradeData | ✅ Funciona | Cadastros mestres |
| EduPLetivoData, EduHabilitacaoFilialData, EduHabilitacaoFilialPlData | ✅ Funciona | (use **EduHabilitacaoFilialPlData**, com 'Pl', para SHABILITACAOFILIALPL — não `EduHabilitacaoFilialData`) |
| EduTurmaData, EduTurmaDiscData | ✅ Funciona | |
| EduHabilitacaoAlunoData | ✅ Funciona | |
| EduServicoData, EduPlanoPgtoData, EduParcPlanoData, EduHabModeloPgtoData | ✅ Funciona | Financeiro |
| EduResponsavelData | ⚠ Não cria FCFO mestre | Tabela retornada é SResponsavel (vínculo parcela↔CFO), não FCFO. Pra criar FCFO mestre: caminho ainda a definir |
| **EduMatricPLData** | 🔒 **BLOQUEADO** | "Você não está autorizado a inserir registros" em `ValidateInsertRecordSecurity()`. Reproduz com user goliveira E user consultor. Não é perfil, é config global. |
| **EduMatriculaData** | 🔒 **BLOQUEADO em cascata** | Internamente chama `EduMatriculaDiscEnsSuperiorObj.IncluirMatriculaDisc` que tenta criar SMATRICPL → bate no mesmo bloqueio |
| EduContratoData, EduParcelaData, EduBolsaData, EduBolsaAlunoData | ❓ Não testado ainda | (bloqueado pela cadeia: precisa matrícula primeiro) |

### O bloqueio é dependente de dados completos

O `ValidateInsertRecordSecurity()` só dispara quando o XML passa validação de campos obrigatórios. Probe com XML mínimo (só `<CODCOLIGADA>1</CODCOLIGADA>`) chega na validação de campos antes; com XML completo, dispara o bloqueio.

---

## 5. IDs mestres conhecidos (RM HOMOLOG)

### IDPERLET por ano

| CODPERLET (ano) | Filial 1 (UN1) | Filial 2 (UN2) |
|---|---|---|
| 2022 | **12** | **14** |
| 2023 | 15 | (não confirmado) |
| 2024 | 18 (EF1) / 19 (EM) | (não confirmado) |
| 2026 | 1 | 2 |

### IDHABILITACAOFILIAL (Diego 2022)

| Ano | IDHABFIL | Curso | Hab | Filial | Turno |
|---|---|---|---|---|---|
| 2022 | 24 | EF2 | 8 | 1 | 4 (Integral) |

### IDTURMADISC (Diego 8A 2022)

187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199 (13 disciplinas).

### CODSERVICO disponíveis (coligada 1)

| COD | NOME |
|---|---|
| 1 | 1ª mensalidade |
| 2 | Mensalidade |
| 3 | Material Didático |
| 4 | Alimentação |
| 268 | 1ª mensalidade (duplicata legado) |
| 269 | Alimentação (duplicata) |
| 270 | Material Didático (duplicata) |
| 271 | Mensalidade (duplicata) |
| 8 | Histórico Escolar |
| 9 | Transcript / 2ª Via |
| 272 | OUTROS RECEBIMENTOS |
| 273 | PROJETO ADOTE IVN |
| 279, 280, 281, 282 | "Migracao 2022" — criados por erro, pendente delete |

**Regra (consultor):** usar serviços genéricos (sem ano/segmento no nome). Padrão atual: `MENS=2`, `MAT=3`, `ALIM=4`, `1ªMens=1`. Os COD 268–271 são duplicatas legadas; preferir 1–4.

---

## 6. Estado dados Diego 2022 (piloto)

### Já criado no RM

- ✅ SCURSO EF2, SHABILITACAO 8, SGRADE EF2-8-2022 (mestres)
- ✅ SDISCIPLINA × 13 (códigos 7, 19, 21, 32, 49, 51, 55, 62, 67, 76, 84, 85, 104)
- ✅ SDISCGRADE × 13 (matriz curricular EF2-8-2022)
- ✅ SPLETIVO 2022 (IDPERLET=12 F1, =14 F2)
- ✅ SHABILITACAOFILIAL EF2-8-UN1-2022 (IDHABFIL=24)
- ✅ SHABILITACAOFILIALPL (via `EduHabilitacaoFilialPlData`)
- ✅ STURMA 8A 2022 (CODTURMA=8A, IDPERLET=12)
- ✅ STURMADISC × 13 (IDTURMADISC=187–199)
- ✅ SALUNO Diego (RA 20142166, CODPESSOA=1490)
- ✅ SHABILITACAOALUNO Diego EF2-8-2022 (PK: 1;24;20142166)
- ✅ SPLANOPGTO 221002 (EF2 6/9 ANO 2022, IDPERLET=12)
- ✅ SHABMODELOPGTO 221002↔IDHABFIL=24
- ✅ SPARCPLANO × 37 (apontando pros SSERVICO 279–282 — **a corrigir** pros 1–4)

### Bloqueado / pendente

- 🔒 SMATRICPL Diego 2022 (bloqueio global EduMatricPLData)
- 🔒 SMATRICULA × 13 (cascata do bloqueio acima)
- ❓ SCONTRATO × 4 (CODCONTRATO 2473, 2474, 2475, 2636) — depende SMATRICPL
- ❓ SPARCELA × 37 — depende SCONTRATO
- ❓ SBOLSAALUNO × 4 — depende SCONTRATO + SBOLSA
- ❓ SPROVAS × 52 + SNOTAS × 316 — depende SMATRICULA
- ❓ FLAN — depende SPARCELA

---

## 7. Dados Gennera (fonte) — Diego 2022

| Sistema | ID Diego |
|---|---|
| Gennera `id_person` | 1490 |
| TOTVS `CODPESSOA` | 1490 |
| TOTVS `RA` | 20142166 |
| INEP | 123263953604 |
| CPF | 48497447883 |
| Email | diego.sousa@edf.g12.br |
| Nascimento | 2009-04-15 |

### Tabelas Gennera com dados Diego 2022 (resumo)

- `enrollment` (id_enrollment=547)
- `enrollment_contract` (4 contratos: 2473, 2474, 2475, 2636)
- `contract` (4 contratos, mãe id_person=65 / pai id_person=66)
- `servicos_historico` (36 rows = 12 meses × 3 itens MENS/ALIM/MAT)
- `bolsas_descontos` (36 rows, todas 100% — filho de funcionário + folha FF)
- `grade` (316 rows de notas em 13 disciplinas)
- `attendance` (~78 + ruído de listas gerais)

### Responsável financeiro

- Mãe Joselia (CODCFO=1645, CGCCFO=10743729803, CGCCFO=mãe id_person=65). Já cadastrada no RM (mas a tabela FCFO mestre não é exposta via DataServer Edu* SOAP; verificar caminho com consultor se precisar criar novos).

---

## 8. Views PostgreSQL — uso atual

### export_v2 (refatorações recentes — preferir)

| View | Status | Observação |
|---|---|---|
| sservico | ✅ | Não tem CODSERVICO (consolidação por nome) |
| splanopgto | ✅ | 112 planos (56 únicos × 2 filiais) |
| sparcplano | ✅ | (Consultor sugeriu descartar, SPARCELA substitui) |
| shabmodelopgto | ✅ | 348 vínculos |
| scontrato | ✅ | Diego: 19 contratos (4 são 2022) |
| sparcela | ⚠️ | Diego: 25 rows (perdeu contrato 2636 da MENS principal) |
| sbolsaaluno | ✅ | Diego: 2 (faltam 2 bolsas — MENS principal + MAT) |
| slan | ❓ | Não usada ainda |
| flan | ❓ | Layout posicional |
| fcfo | ✅ | Diego: mãe Joselia 1645 |

### export (legacy, ainda em uso)

| View | Status |
|---|---|
| smatricula | ✅ (13 rows Diego 2022) |
| smatricpl | ✅ (1 row Diego 2022) — `STATUSRES` vazio |
| sturma, sturmadisc | ✅ |
| sdiscgrade | ✅ (13 rows EF2-8-2022) |
| shabilitacaofilialpl | ⚠️ várias colunas vazias |
| setapas | ⚠️ (PONTDIST/MEDIA/FREQMIN vazios) |
| snotas | ⚠️ inflada (3919 rows = junção cartesiana com sprovas, revisar) |
| sfrequencia | ⚠️ PRESENCA vazio |
| shabilitacaoaluno | ✅ |
| ppessoa | ✅ |

---

## 9. Próximos passos

### Imediatos (aguardando consultor)

1. Consultor liberar `EduMatricPLData` (config global de inserção) OU indicar workflow alternativo (importação Excel, "Processo de Matrícula", outro DataServer).

### Após desbloqueio (sequência Diego)

2. SaveRecord SMATRICPL Diego 2022 (1 row).
3. SaveRecord SMATRICULA × 13 (uma por disciplina, com IDTURMADISC 187–199).
4. Validar (ReadView) cadeia matrícula.
5. SaveRecord SCONTRATO × 4 (CODCONTRATO 2473, 2474, 2475, 2636) com SResponsavelContrato child (CODCFO=1645).
6. SaveRecord SPARCELA × 37.
7. SaveRecord SBOLSAALUNO × 2 (ou 4 — revisar view; faltam MENS principal + MAT).
8. Notas/etapas (após revisar view export.snotas inflada).
9. FLAN via wsFin se necessário.

### Refatoração paralela

10. Corrigir SPARCPLANO 221002 apontando pros CODSERVICO 1–4 (em vez de 279–282), deletar SSERVICO "Migracao 2022".
11. Padrão "serviço genérico" (sem ano/segmento) — refatorar views financeiras se necessário.

---

## 10. Referências cruzadas

- [11_estrategia_filtro_perfil.md](./11_estrategia_filtro_perfil.md) — DEPRECATED
- [12_descoberta_regex_bug_e_bloqueios_reais.md](./12_descoberta_regex_bug_e_bloqueios_reais.md) — análise definitiva
- [../fluxo/05_caso_piloto_diego.md](../fluxo/05_caso_piloto_diego.md) — caso Diego
- [../fluxo/07_arvore_dependencias_totvs.md](../fluxo/07_arvore_dependencias_totvs.md) — árvore FK
- `scripts/smart_saver.js` — cliente Node corrigido
- `CLAUDE.local.md` — credenciais (gitignored)

---

**FIM** — v2.0 baseada em auditoria sistemática Diego 2022 + Postman direto.
