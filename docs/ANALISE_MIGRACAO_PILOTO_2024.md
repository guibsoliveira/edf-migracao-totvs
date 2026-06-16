# Auditoria Completa — Piloto de Migração 2024 (turmas 1MA/1MB)

**Data:** 2026-06-11
**Escopo:** ano letivo 2024, Filial 1 (IDPERLET=19 no RM HOMOLOG), turmas 1MA e 1MB (1ª série EM) importadas por Isaac + resíduo 3M de teste anterior.
**Método:** tripla verificação independente — API Gennera live (verdade) × banco staging/views PostgreSQL (transformação) × TOTVS RM (destino) — com DEPARA individual por aluno, verificação adversarial de causas-raiz e crítica de completude.
**Dados brutos:** `data/exportacoes/2026-06-11/*.json` (gitignored, contém PII).

---

## 1. Veredito executivo

| Elo da cadeia | Resultado |
|---|---|
| API Gennera ↔ staging (2024, ano fechado) | ✅ **100% fiel** — soma de purchases idêntica (R$ 4.584.004,00, diff 0), 111/111 contratos com match, 0 divergência de status |
| Staging ↔ RM (acadêmico) | ✅ **100% fiel** — 49/49 RAs idênticos, nomes iguais, 903 matrículas corretas, 2 cancelados da fonte corretamente ausentes |
| Staging ↔ RM (financeiro/parcelas) | ✅ **1:1 em contagem, soma e serviço** — exceto 1 parcela espúria de R$ 100 (resíduo de teste) |
| Staging ↔ RM (bolsas) | ✅ 64/64 no escopo 1MA/1MB |
| **Staging ↔ view `export_v2.sparcela`** | ❌ **BUG REAL** — a view descarta ~24 parcelas/aluno (ALIM+MDIDAT), ver §3 |
| Baixas de pagamento (FLAN) | ❌ **inexistente** — 3 baixas vs 1.287 parcelas pagas no Gennera |
| Professores / horários no piloto | ❌ zero (SPROFESSOR=0 no RM inteiro; SPROFESSORTURMA e SHORARIOTURMA=0 no IDPERLET=19) |
| Histórico escolar | ❌ SHISTALUNOCOL carregado (7.943 rows) mas **SHISTDISCCOL=0** e DIASLETIVOS=0 → RM não emite histórico |

**Nota de prontidão para "migrar direto com Claude": 4/10** — ferramental de transformar+validar maduro (~7/10 sozinho), mas matrículas exigem humano na UI (bloqueio global de WS), a view de parcelas tem bug não corrigido, e baixas+histórico não fazem parte do processo. Caminho para subir a nota no §7.

---

## 2. O que o piloto provou que FUNCIONA

1. **A cadeia Gennera → staging → RM preserva os dados.** Exemplo típico (RA 20152214): staging 41 cobranças R$ 93.498 = RM 41 parcelas R$ 93.498, serviço a serviço (MENS 12 + ALIM 12 + MDIDAT 12 + 1PARC 5).
2. **Estrutura financeira padrão EM 2024 por aluno:** 2 contratos Gennera (rematrícula R$ 5.658 + anuidade R$ 87.840) = R$ 93.498/ano; variações por itens extras ou renegociação.
3. **Integridade referencial no RM perfeita:** 50 RAs com SMATRICPL = 50 com SCONTRATO = 50 com SPARCELA; 49 CODCFO usados, 0 FK órfã no FCFO (658 cadastrados); 0 mojibake nos nomes.
4. **Reconciliação automatizável:** esta auditoria foi 100% via ReadView/ReadRecord + psql + API — pode virar gate automático pós-lote.

## 3. Bug crítico na view `export_v2.sparcela` (bloqueante para cargas futuras)

**Sintoma:** para ~48/50 alunos de 2024, a view emite só Mensalidade/1ª mensalidade (~17-22 parcelas, R$ 73.554) e descarta as ~24 de ALIM+MDIDAT (R$ 19.944/aluno). No lote 2024 F1 inteiro: **~1.289 parcelas pagas dropadas em 59/84 alunos**.

**Causa-raiz (confirmada por hash de contrato):** a Gennera **mudou de prática entre anos**:
- 2021-2022: contratos separados por serviço ("Contrato - Alimentação 2022" ×525, "Contrato - Material 2022" ×525) → CTE `servicos_ranked` resolve, piloto Diego funcionou.
- 2024: **ALIM/MD são faturados DENTRO do contrato "Mensalidade 2024"** (hash idêntico para MENS+ALIM+MD; zero contratos de serviço no ano). A CTE retorna vazio, `contrato_por_tipo` não tem linha SERVIC, e o `WHERE ct.id_contract IS NOT NULL` (linha ~278 do `08_sparcela_v3.sql`, idem snapshot v2 aplicado) **descarta silenciosamente** as parcelas.

**Por que o RM está certo mesmo assim:** a carga do Isaac NÃO passou por esse caminho da view.

**Fix proposto (não aplicado, aguardando OK):** no CTE `contrato_por_tipo`, fallback de SERVIC/SERVIC_EXTRA → contrato MENS do aluno (e na falta, REMATR) quando `servicos_ranked` não tiver rank — fiel à origem. Bugs menores adjacentes: ANUID colapsa em "Mensalidade" (RM distingue 296 vs 299); itens "MD" caem em SERVIC_EXTRA por falta do padrão `\mMD\M` no CASE do tipo.
**Validação pós-fix:** RAs 20152214/20121769/20121794 devem retornar 41/28/46 parcelas somando R$ 93.498 cada.

## 4. Divergências investigadas (e o que NÃO é problema)

| Classe (DEPARA) | Alunos | Conclusão adversarial |
|---|---|---|
| CONTRATO_FALTANTE_RM | 29 | **Falso positivo** — RM consolida 1 SCONTRATO/aluno (decisão de carga); view emite 1 linha por contrato Gennera (2-4). Diferença de granularidade, não dado perdido. Decidir modelo com consultor (§6). |
| VIEW_VS_STAGING | 27 | **Bug real da view** (§3). RM correto. |
| VALOR_DIVERGE / PARCELAS_EXTRAS_RM | 1 | **Parcela espúria** IDPARCELA=12752 (R$ 100, "OUTROS RECEBIMENTOS", RA 20121839): não existe em NENHUMA fonte Gennera. Resíduo do lote de teste 3M (bloco de IDs 12745-12953). Excluir via DeleteRecord (conferir boleto/IDLAN antes). As outras 3 parcelas do serviço 272 são legítimas (match exato no staging). |
| PARCELAS_FALTANTES_RM | 1 | RA 20101529 (resíduo 3M): 22 das 32 "faltantes" são canceladas excluídas por design; 10 pagas de ALIM/MD caem no bug §3. |
| BOLSA_DIVERGE | 1 | RA 20101529: bolsa DESCONTO 30% real no Gennera, presente na view, ausente no RM (lote de bolsas não incluiu o aluno do teste 3M). Líquido não distorcido (desconto inline na parcela). ⚠️ Se inserir SBOLSAALUNO sem zerar o desconto da parcela → duplo abatimento. |

**Cross de RAs fechado:** o "50 vs 84 vs 49" se explica — fonte 1MA/1MB = 49 alunos (todos no RM), o 50º do RM é o resíduo 3M (RA 20101529); os 35 da 3M na fonte nunca foram alvo do lote.

## 5. Processo do Isaac (reconstruído por forense de auditoria)

Pipeline confirmado: **views PostgreSQL → CSV LATIN-1 `;` → Importador TOTVS Educacional (UI)** para matrículas; **SPARCELA em massa sob o login pessoal dele** (CPF 47376941851, ~3 rows/seg, 2026-05-20/21 — processo automatizado, parte ORIGEM=PP "gerar parcelas do plano", parte MN); **FLAN carregado em 2026-06-11** (durante esta auditoria: 1.623 lançamentos).

Evidências: SPARCELA tem trilha via ReadRecord (RECCREATEDBY 'IMPORTADOR' nos lotes CSV; CPF do Isaac nos massivos); SMATRICPL/SCONTRATO/SMATRICULA **não expõem REC*** (inauditáveis); kit Maria 2026-05-08 correlaciona com datas.

Fricções mapeadas: `EduMatricPLData.SaveRecord` bloqueado global (matrícula só via UI); layouts do Importador descobertos por tentativa-e-erro (só SMATRICPL/SMATRICULA versionados); lookups exigem código humano, não ID; IDs internos (IDPERLET etc.) diferem entre HOMOLOG/PROD; sem manifesto de carga → banco inauditável.

## 6. Decisões de modelagem ABERTAS (fechar antes de replicar)

1. **Contrato:** 1 consolidado/aluno-perlet (como o RM está) × multi-contrato espelhando o Gennera (como a view emite). Validar com consultor se o Importador aceita múltiplos.
2. **Serviços:** por ano/segmento 292-306 (padrão Isaac 2024) × genérico 1-4 (recomendação do consultor, usado no Diego 2022). Hoje os dois padrões coexistem no HOMOLOG (+ resíduos 271-273, 279-282 a limpar, 310 novo).
3. **Bolsa × desconto inline:** desconto já vem na parcela (TIPODESC); definir se SBOLSAALUNO mestre entra junto e como evitar duplo abatimento.

## 7. Plano de ação priorizado

1. **(bloqueante)** Corrigir `export_v2.sparcela` (fallback SERVIC→MENS) + teste de regressão staging→view por RA/serviço.
2. **(bloqueante)** Fechar com consultor+Isaac as decisões do §6 e congelar por escrito.
3. **Baixas:** incluir no processo (wsFin.BaixaLancamento ou baixa em lote) usando STATUSGENNERA/VALORPAGO/DATAPAGAMENTO; aceite = soma baixada RM == soma paga Gennera. **Nunca ir a PROD com 1.663 boletos vencidos em aberto.**
4. **Chamado TOTVS** para destravar EduMatricPLData/EduMatriculaData.SaveRecord; enquanto isso, industrializar o Importador (capturar e versionar TODOS os "Layout esperado:", geradores parametrizados sem ID hardcoded).
5. **Histórico:** migrar SHISTDISCCOL (view pronta com 154.693 rows) + preencher DIASLETIVOS — sem isso o RM não emite histórico e o cancelamento de SNOTAS não se sustenta.
6. **Operacional acadêmico:** SPROFESSOR (91 canônicos), SPROFESSORTURMA, SHORARIOTURMA no piloto; limpar 11 CODPROF órfãos.
7. **Higiene HOMOLOG:** excluir parcela 12752; decidir expurgo do resíduo 3M; limpar serviços de teste; criar SPLETIVO F1 faltantes (2019/2020/2023/**2025**).
8. **Governança de carga:** janela de congelamento durante auditorias; manifesto por lote (arquivos, contagens, somas, operador, timestamp) versionado; logs do Importador copiados ao repo.
9. **Gate automático pós-lote:** script único de reconciliação (RAs, matrículas, parcelas por serviço, bolsas, FLAN+baixas — RM × staging × API) com aprovação bloqueante.
10. **Plano de corte 2026:** anos fechados do staging; ano corrente e pagamentos SEMPRE da API live com re-sync D-1; política para hard-deletes (24 contratos já sumiram da API).

## 8. Descobertas técnicas (para o ferramental)

- `SPARCELA.VALOR` via ReadView vem **em centavos** (565800 = R$ 5.658,00).
- ReadView **não expõe campos REC*** — auditoria exige **ReadRecord** com PK (PKs: SMATRICPL=`CODCOLIGADA;IDPERLET;IDHABILITACAOFILIAL;RA`; SCONTRATO=`CODCOLIGADA;RA;IDPERLET;CODCONTRATO`; SMATRICULA=`CODCOLIGADA;IDTURMADISC;RA`; SPARCELA=`CODCOLIGADA;IDPARCELA`).
- EduParcelaData **não expõe status de pagamento** — vive no FLAN (`FinLanDataBR`; sufixo BR obrigatório, idem `FinCFODataBR`).
- SCONTRATO via ReadView não expõe CODCFO — obter via `EduResponsavelData` (SRESPONSAVEL).
- Mapeamento RA↔Gennera: `gennera_stg.student_code_unico` (code_unif=RA canônico; 4 alunos rematriculados têm RA novo remapeado). IDs do staging ≠ IDs da API live; contratos na API pertencem ao **responsável financeiro**; ponte financeira = `contract.hash` ↔ `servicos_*.contrato`.
- `/institutions/{id}/contracts` não expõe idAcademicCalendar — vincular ano via `enrollment_contract` no staging.
- `export_v2` tem **9 views** (sbolsaaluno só existe em `export`); `export_v2.sparcela` filtrada por 84 RAs = 4min09s (materializar antes do full).
- Eletivas: 1ª série EM tem 19 disciplinas na grade, alunos cursam 18 (1 eletiva); 4 alunos com as 2 eletivas (confirmar no Gennera caso a caso).
