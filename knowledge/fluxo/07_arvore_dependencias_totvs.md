# 07 - Arvore de Dependencias TOTVS RM

> A logica de FK do RM Educacional: o que precisa existir ANTES do que.
> Esta a chave para nao perder tempo: antes de tentar criar X, garantir que TODO seu pai existe.

---

## Principio fundamental

Cada entidade no RM tem uma cadeia de "pais" que precisam existir antes. Se voce tentar criar a filha sem o pai = "fk_violation" / "ORA-02291" / "There is no row at position 0".

**Regra de ouro:** sempre subir a arvore ate as raizes, criar de cima pra baixo.

---

## Mapa visual (top-down)

```
                                  GCOLIGADA (1=EDF, ja existe)
                                  GFILIAL (1=UN1, 2=UN2, ja existe)
                                  STIPOCURSO (1=Educacao Basica)
                                  GCCUSTO (centro de custo)
                                            |
                                            v
                                  ---------- SCURSO ----------
                                  (EI, EF1, EF2, EM)
                                            |
                                            v
                                  ---------- SHABILITACAO ----------
                                  (K1, K2, 1-9 ano, 1-3 serie)
                                            |
                                            v
                                  SGRADE (matriz por ano: 2022, 2023...)
                                  SDISCIPLINA (catalogo: PORT, MAT...)
                                            |
                                            v
                                  SPLETIVO (periodo letivo do ano)
                                            |
                                            v
                                  ---------- SHABILITACAOFILIAL ----------
                                  (combinacao curso+hab+filial+grade+turno)
                                  → gera IDHABILITACAOFILIAL
                                            |
                                            +-----------------+
                                            v                 v
                                  STURMA                SHABILITACAOFILIALPL
                                  (8A, 8B...)          (vinculo com plano pgto)
                                            |
                                            +---- SDISCIPLINA
                                            v
                                  STURMADISC
                                  → gera IDTURMADISC
                                            |
                                            v
                                  SMATRICPL (aluno x disciplina) ← exige IDTURMADISC
                                  SMATRICULA (aluno na turma)
                                            ↑
                                  SHABILITACAOALUNO (aluno na habilitacao)
                                  SALUNO (aluno cadastrado)
                                  PPESSOA (pessoa cadastrada)
```

---

## Cadeia ACADEMICA - de onde vem cada FK

| Filha | Precisa de | Onde achar na view |
|-------|-----------|--------------------|
| **SCURSO** | STIPOCURSO | `export.scurso` (CODTIPOCURSO) |
| **SHABILITACAO** | SCURSO | `export.shabilitacao` (CODCURSO + CODHABILITACAO) |
| **SGRADE** | SCURSO + SHABILITACAO | `export.sgrade` (CODCURSO + CODHABILITACAO + CODGRADE) |
| **SDISCIPLINA** | (nao depende) | `export.sdisciplina` (CODDISCIPLINA) |
| **SDISCGRADE** | SGRADE + SDISCIPLINA | `export.sdiscgrade` |
| **SPLETIVO** | STIPOCURSO + GFILIAL | `export.spletivo` (CODFILIAL + CODTIPOCURSO + CODPERLET) |
| **SHABILITACAOFILIAL** | SCURSO + SHABILITACAO + SGRADE + GFILIAL + CODTURNO | `export.shabilitacaofilial` → gera IDHABILITACAOFILIAL |
| **SHABILITACAOFILIALPL** | SHABILITACAOFILIAL + SPLETIVO | `export.shabilitacaofilialpl` |
| **STURMA** | SHABILITACAOFILIAL + SPLETIVO (CODPERLET) | `export.sturma` |
| **STURMADISC** | STURMA + SDISCIPLINA | `export.sturmadisc` → gera IDTURMADISC |
| **SHORARIO** | (independente) | `export.shorario` |
| **SHORARIOTURMA** | STURMA + SHORARIO | n/a |
| **PPESSOA** | (independente cross-coligada) | `export.ppessoa` (CODPESSOA) |
| **SALUNO** | PPESSOA | (via PPESSOA + RA) |
| **SHABILITACAOALUNO** | SALUNO + SHABILITACAOFILIAL | `export.shabilitacaoaluno` |
| **SMATRICULA** | SALUNO + STURMA + STURMADISC (IDTURMADISC) | `export.smatricpl` (na view trocada!) |
| **SMATRICPL** | SMATRICULA + SDISCIPLINA | `export.smatricula` (trocado!) |
| **SETAPAS** | (config geral) | `export.setapas` |
| **SPROVAS** | SMATRICPL + SETAPAS | `export.sprovas` |
| **SNOTAS** | SPROVAS + SALUNO | `export.snotas` (via shistdisccol) |

---

## Cadeia FINANCEIRA - de onde vem cada FK

| Filha | Precisa de | Onde achar na view |
|-------|-----------|--------------------|
| **SSERVICO** | STIPOCURSO | `export_v2.sservico` |
| **SBOLSA** | (independente) | `export.sbolsa` |
| **SBOLSAPLETIVO** | SBOLSA + SPLETIVO | `export.sbolsapletivo` |
| **SPLANOPGTO** | SPLETIVO (IDPERLET + CODPERLET) | `export_v2.splanopgto` |
| **SPARCPLANO** | SPLANOPGTO + SSERVICO | `export_v2.sparcplano` (CANCELADA no roadmap!) |
| **SHABMODELOPGTO** | SPLANOPGTO + SHABILITACAO + SHABILITACAOFILIAL | `export_v2.shabmodelopgto` |
| **FCFO** | (independente, legacy) | `export.fcfo` |
| **SCONTRATO** | SALUNO + SHABILITACAOFILIAL + SPLETIVO + SPLANOPGTO + FCFO + SHABMODELOPGTO | `export_v2.scontrato` |
| **SPARCELA** | SCONTRATO + SSERVICO + FCFO (CODCFO + CODCOLCFO) | `export_v2.sparcela` |
| **SBOLSAALUNO** | SCONTRATO + SBOLSA + SSERVICO | `export_v2.sbolsaaluno` |
| **SLAN** | SCONTRATO + SPARCELA | `export_v2.slan` (auto-gerado pelo RM?) |
| **FLAN** | FCFO (legacy) | `export_v2.flan` (posicional) |

---

## Erros conhecidos e o que significam

| Erro | Causa | Como resolver |
|------|-------|---------------|
| `fk_violation` / `ORA-02291` | Alguma FK no XML aponta para registro que nao existe | Criar a dependencia primeiro |
| `There is no row at position 0` | RM espera child rows no DataSet (ex: SPLANOPGTO espera SPARCPLANO) | Enviar XML com pai + child no mesmo DataSet |
| `Column 'X' does not belong to table` | Campo X precisa estar no XML mesmo que vazio/0 | Adicionar `<X>0</X>` |
| `Contexto informado no XML e diferente do contexto da requisicao` | Conflito entre Contexto SOAP e tag XML | Sincronizar valores OU registro ja existe com chave diferente |
| `Chave duplicada` | Registro ja existe = SUCESSO (idempotencia) | Tratar como ok |
| `Voce nao esta autorizado a inserir registros` | Permissao de perfil bloqueia escrita | Pedir consultor TOTVS ou usar outro user |
| `Nivel de Ensino -1` | CODSISTEMA=S quebrou contexto | OMITIR CODSISTEMA no Contexto SOAP |

---

## Estado real RM HOMOLOG mai/2026 (Diego 2022)

### O que JA EXISTE confirmado via SaveRecord (atualizado 2026-05-19 final)

- SCURSO EF2 ✓
- SHABILITACAO 8 ✓
- SGRADE EF2-8-2022 ✓
- SDISCIPLINA x 13 (codigos 7,19,21,32,49,51,55,62,67,76,84,85,104) ✓
- SPLETIVO 2022 ✓ → **IDPERLET=12 (Filial 1)** / 14 (Filial 2)
- SHABILITACAOFILIAL EF2-8-UN1-2022 ✓ → **IDHABILITACAOFILIAL=24**
- **SHABILITACAOFILIALPL EF2-8-UN1-2022** ✓ (criado hoje, DataServer **EduHabilitacaoFilialPlData**)
- **STURMA 8A 2022** ✓ (criado hoje, PK: 1;1;12;8A)
- **STURMADISC x 13** ✓ → IDTURMADISC=187,188,189,...,199
- SALUNO Diego (RA 20142166) ✓
- **SHABILITACAOALUNO Diego EF2-8-2022** ✓ (PK: 1;24;20142166)

### O que JA EXISTE financeiro Diego 2022

- SPLANOPGTO **221002** (não 221003 — esse é EM) → IDPERLET=12, CODPERLET=2022, "EF2 6/9 ANO 2022"
- SHABMODELOPGTO 221002 ↔ IDHABFIL=24 ✓
- SPARCPLANO × 37 (plano 221002) — ⚠️ apontando pros SSERVICO 279-282 errados, a corrigir pros COD 1-4 originais

### O que FALTA criar (BLOQUEADO)

- **SMATRICPL Diego 2022** → 🔒 BLOQUEADO em `EduMatricPLData.ValidateInsertRecordSecurity()` (resposta literal: "Você não está autorizado a inserir registros"). Reproduzido com user goliveira E com user consultor (10042327644) via Postman direto — confirma que é config global do DataServer, não perfil.
- **SMATRICULA × 13** → 🔒 BLOQUEADO em cascata (`EduMatriculaDiscEnsSuperiorObj.IncluirMatriculaDisc` chama SMATRICPL internamente)
- SCONTRATO × 4 (CODCONTRATO 2473, 2474, 2475, 2636) → aguarda destravar matrícula
- SPARCELA × 37 → aguarda SCONTRATO
- SBOLSAALUNO × 4 (todas 100% — filho de funcionário) → aguarda SCONTRATO
- SPROVAS / SNOTAS → aguarda matrícula

### Aprendizados consolidados (2026-05-19 — atualizado tarde)

1. **REGEX CASE-SENSITIVE BUG (corrigido):** RM retorna tabela em PascalCase (`<SCurso>`, `<FCfo>`, `<SServico>`). Cliente Node contava com `<SCURSO>` UPPERCASE — sempre dava 0. Não havia bloqueio de leitura. Helpers `countTable` e `extractRows` no `smart_saver.js` agora usam regex case-insensitive. Detalhes em [../totvs/12_descoberta_regex_bug_e_bloqueios_reais.md](../totvs/12_descoberta_regex_bug_e_bloqueios_reais.md).
2. **IDPERLET REAL para 2022** = 12 (Filial 1), 14 (Filial 2). ReadView `EduPLetivoData` funciona quando passa filtro válido (não vazio).
3. **SHABILITACAOFILIALPL** usa DataServer **EduHabilitacaoFilialPlData** (com 'Pl' no fim, não confundir com EduHabilitacaoFilialData).
4. **Padrão PK auto-gerada**: campos como IDPERLET, IDHABILITACAOFILIAL, IDTURMADISC devem ser `<X>0</X>` no XML SaveRecord; RM gera e retorna na resposta como `1;X;Y` separado por `;`.
5. **Resposta de sucesso SaveRecord**: formato `1;PK1;PK2;...` (só a primary key, sem mensagens). Erros trazem stack trace.
6. **Quando FK violation aparece**: significa que um dos FOREIGN KEYs no XML aponta para registro que não existe. Subir a árvore e criar a dependência primeiro.
7. **CODTURNO=4** = Integral (numérico, não texto).
8. **CODPERLET (texto) vs IDPERLET (numero)**: a view export usa CODPERLET (=ano) mas RM usa IDPERLET internamente. Sempre fornecer ambos.
9. **CODSERVICO duplicados:** RM EDF tem CODs baixos (1-4) e altos (268-271) com mesmos nomes. Consultor sugere padrão "serviço genérico" — usar SEMPRE os COD baixos (1=1ªMens, 2=Mens, 3=Material, 4=Alimentação), sem ano/segmento no nome.
10. **ValidateInsertRecordSecurity é dependente de dados completos:** Probe com XML mínimo passa pela security; XML completo dispara o bloqueio (quando há). Isso confirma que o RM faz security AFTER field validation.
11. **Encoding shell Windows + psql:** `psql.exe` retorna linhas com `\r` no final. Em arrays `split('|')`, o `\r` cola na última coluna. Sempre `.replace(/\r/g, '')` em cada célula.
12. **DeleteRecord PrimaryKey:** formato `;`-separado mas o XML aceito pelo RM tem um detalhe específico ainda não totalmente mapeado (`Falha ao salvar XML` ao tentar). Pra ser confirmado.

---

## Árvore de dependências para 1 aluno (versão definitiva 2026-05-21)

> Reescrita após auditoria de profs Gennera (88 reais vs 155 lixo na view antiga) e decisão de **cancelar SNOTAS/SPROVAS/SFREQUENCIA** em favor do histórico consolidado (`SHISTDISCCOL` + `SHISTALUNOCOL`).

```
NÍVEL 0 — MESTRES GLOBAIS (uma vez por instância)
  STIPOCURSO (1 = Educação Básica)
  GCOLIGADA (1 = EDF)
  GFILIAL (1 = UN1, 2 = UN2)
  GCCUSTO (centros de custo)
  SCURSO (EI, EF1, EF2, EM)
  SHABILITACAO (17 séries/habilitações)
  SGRADE (matriz por ano: 2021-2026)
  SDISCIPLINA (catálogo: PORT, MAT, etc — 126 no RM)
  SDISCGRADE (vínculo disciplina↔grade)
  SETAPAS (config etapas: 1°/2°/3° Trimestre + Recuperação Anual)

NÍVEL 1 — PROFESSORES (uma vez, antes de qualquer turma operacional)
  PPESSOA (do professor — 1 por id_person canônico)
  SPROFESSOR (cadastro mestre — usar APENAS profs em
              gennera_stg.professor_quadro_horarios, excluir placeholders
              "Professor Substituto*" e "Professor teste*")
              → 88 distintos no Gennera (NÃO os 155 da view antiga
              que inclui staff @edf.pro.br)

NÍVEL 2 — ESTRUTURA DO ANO LETIVO (por filial/ano)
  SPLETIVO → captura IDPERLET (ex: 2022 F1 = 12, F2 = 14)
  SHABILITACAOFILIAL → captura IDHABFIL (ex: EF2-8-UN1-2022 = 24)
  SHABILITACAOFILIALPL (via EduHabilitacaoFilialPlData, com 'Pl')
  STURMA (turmas reais do ano, ex: 8A, 8B...)
  STURMADISC × N disciplinas → captura IDTURMADISC (ex: 187-199)

NÍVEL 3 — VÍNCULOS PROF↔TURMA (depende de STURMA + STURMADISC + SPROFESSOR)
  SPROFESSORTURMA × N (prof leciona disciplina X na turma Y do ano Z)
                       → fonte: gennera_stg.professor_quadro_horarios
  SHORARIOTURMA × N (horários reais das aulas)
                    → fonte: professor_quadro_horarios (DIA + INICIO + FIM + TURNO)

NÍVEL 4 — ALUNO NA TURMA
  PPESSOA do aluno (cross-coligada)
  SALUNO (aluno + RA)
  SHABILITACAOALUNO (aluno ↔ habilitação no ano)
  SMATRICPL (matrícula no período letivo — 1 row/aluno/ano)
            via IMPORTADOR TOTVS (CSV) — EduMatricPLData.SaveRecord bloqueado
  SMATRICULA × N (matrícula em disciplina — 13 rows/aluno/ano EF2)
                  via IMPORTADOR TOTVS (CSV)

NÍVEL 5 — HISTÓRICO ESCOLAR (consolidação anual — CANCELA SNOTAS/SPROVAS)
  SHISTALUNOCOL (1 row/aluno/ano = status APPROVED/IN_PROGRESS/FAILED)
                 → fonte: gennera_stg.enrollment.status + enrollment_record agregado
                 → contém: status, % freq, faltas totais, dias letivos
  SHISTDISCCOL (1 row/aluno/disciplina/ano = nota final + faltas + CH)
                → fonte: gennera_stg.grade agregada + enrollment_record
                → contém: NOTA (média final), FALTAS, CARGAHORARIA, POSICAO

  >> DECISÃO 2026-05-21: NÃO migrar SNOTAS/SPROVAS/SFREQUENCIA detalhadas
  >> Razão: SHISTDISCCOL já tem média + faltas consolidados, suficiente pra
  >> histórico oficial emitível. View export.snotas está inflada (3919 rows
  >> Diego 2022 = junção cartesiana). Apenas anos correntes precisarão de
  >> SNOTAS/SPROVAS pra portal funcionar — fora do escopo da migração histórica.

NÍVEL 6 — FINANCEIRO (paralelo a Níveis 2-4)
  SSERVICO (genérico, sem ano/segmento — usar CODs baixos 1-4)
  SPLANOPGTO (por ano + curso + filial — código {AA}{F}{NNN})
  SPARCPLANO × N (parcelas do plano — 37 = 12 MENS + 12 ALIM + 12 MAT + 1 1ªMens)
  SHABMODELOPGTO (vincula plano ↔ habilitação filial)
  FCFO (responsáveis financeiros — cadastro mestre)
  SBOLSA (tipos de bolsa)
  SBOLSAPLETIVO (bolsa ↔ período letivo)
  SCONTRATO × N (contrato do aluno × serviço × responsável)
  SPARCELA × N (cobranças reais — 37 por aluno/ano)
  SBOLSAALUNO × N (bolsa aplicada por aluno por contrato)
  FLAN / SLAN (lançamentos contábeis — última etapa)
```

### Estado real Diego 2022 (auditado 2026-05-21)

| Nível | Item | Status |
|-------|------|--------|
| 0 | Todos mestres globais | ✅ existem no RM |
| 1 | SPROFESSOR (88 reais) | ❌ ZERO no RM (próxima prioridade) |
| 2 | SPLETIVO/SHABFIL/STURMA/STURMADISC 2022 | ✅ |
| 3 | SPROFESSORTURMA × 13 (8A 2022) | ❌ |
| 3 | SHORARIOTURMA (8A 2022) | ❌ |
| 4 | SALUNO/SHABILITACAOALUNO Diego | ✅ |
| 4 | SMATRICPL + SMATRICULA × 13 Diego | ✅ (importado 2026-05-20 via CSV) |
| 5 | SHISTALUNOCOL × 11 anos (2015-2025) | ❌ (dados prontos em export.shistalunocol) |
| 5 | SHISTDISCCOL × 13 anos × disc | ❌ (dados prontos em export.shistdisccol) |
| 6 | SSERVICO + SPLANOPGTO 221002 + 37 SPARCPLANO + SHABMODELOPGTO | ✅ |
| 6 | FCFO Joselia (1645) | ✅ no Gennera, status no RM a confirmar |
| 6 | SCONTRATO × 4 + SPARCELA × 37 + SBOLSAALUNO × 4 | ❌ |
| 6 | FLAN | ❌ |

---

## Lições aprendidas (atualizado 2026-05-19 tarde)

1. **Elemento root XML no SAVE**: aceita uppercase (`<SPLETIVO>`, `<SGRADE>`). No READ vem PascalCase (`<SPLetivo>`, `<SGrade>`). Em case-insensitive os dois funcionam pra match, mas use PascalCase nas funções helper pra ficar explícito.
2. **Campos PK auto-gerados** ainda precisam aparecer no XML como `<X>0</X>` para o RM ler de volta a PK.
3. **SmartSaver** com auto-corrige `missing_field_in_xml` adicionando `<X>0</X>` (loop até 6 tentativas).
4. **NÃO existe "filtro de perfil bloqueando leitura"** dos cadastros mestres — era bug de regex case-sensitive do cliente. ReadView retorna dados normalmente em TODOS os DataServers Edu*. Detalhes em [../totvs/12_descoberta_regex_bug_e_bloqueios_reais.md](../totvs/12_descoberta_regex_bug_e_bloqueios_reais.md).
5. **Bloqueio REAL conhecido:** `EduMatricPLData.SaveRecord` rejeita com "Você não está autorizado a inserir registros" — reproduzido com user goliveira E com user consultor. Não é perfil, é config global do DataServer.
6. **Resposta "1;X;Y;..." (só PK)** = sucesso, registro foi criado OU já existia (idempotência).
7. **Antes de afirmar "DS bloqueia"**: validar via Postman direto + XML cru visível, comparar count esperado vs retornado. Não confiar apenas no parsing do cliente.
