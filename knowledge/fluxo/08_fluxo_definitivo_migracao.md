# 08 — Fluxo Definitivo de Migração Gennera → TOTVS RM

> Consolidado em 2026-06-11 a partir de: auditoria tripla do piloto 1MA/1MB 2024
> (docs/ANALISE_MIGRACAO_PILOTO_2024.md), leitura profunda dos 3 projetos do Isaac
> (Clauwork, gennera-totvs, gennera-totvs-clean) e decisões de negócio fechadas
> pelo Guilherme (analista sênior) por telefone com o Isaac.
> Detalhes brutos: data/exportacoes/2026-06-11/ (gitignored).

---

## 1. Decisões CONGELADAS (2026-06-11)

| # | Decisão | Detalhe |
|---|---------|---------|
| D1 | **Serviços GENÉRICOS** | CODs 1-4 (1=1ªMens, 2=Mens, 3=Material, 4=Alimentação). SSERVICO com **VALOR=0**; valor real vai na SPARCELA. Confirmado por telefone Guilherme↔Isaac. Substitui o padrão por ano/segmento (292-306) usado no piloto 2024 e o doc antigo do Isaac (analise_consolidacao_codservico, 05/07) que propunha canônico por série. |
| D2 | **Contrato CONSOLIDADO** | 1 SCONTRATO por aluno/período letivo. Reflete decisão de negócio da EDF (não da Gennera): boletos separados (ALIM/Material/Mensalidade) foram unificados em boleto/contrato único "Mensalidade" por responsável; 1ª Mensalidade fica fora; anuidade é caso à parte. Hashes Gennera originais preservados em mapa JSON de rastreio. Validar com consultor cenário de renegociação. |
| D3 | **Baixas OBRIGATÓRIAS** | Status da parcela no RM deve espelhar o status real do Gennera (pago=baixado, etc.). Critério de aceite: soma baixada RM == soma paga Gennera, parcela a parcela. |
| D4 | **Importação manual ACEITA** | Para o que o WS bloqueia (SMATRICPL/SMATRICULA): Claude gera o arquivo perfeito, Guilherme importa na UI do Importador TOTVS. Não é gargalo, é etapa desenhada. |
| D5 | **Histórico em 2 camadas** | Anos fechados (2015-2025): SHISTDISCCOL + SHISTALUNOCOL (+DIASLETIVOS). Ano corrente/portal: SNOTAETAPA (trabalho do Isaac, manter). NÃO migrar SNOTAS/SPROVAS/SFREQUENCIA detalhadas (decisão 2026-05-21 mantida). |

**Regra de autoridade:** regra de negócio = Guilherme decide. Material técnico do Isaac = adotar quando comprovado; regra de negócio em doc dele = validar antes.

---

## 2. Papéis no fluxo

```
CLAUDE (automatizado)          GUILHERME (manual)           ISAAC (coordenar)
─────────────────────          ──────────────────           ─────────────────
1. Valida views (gate)         4. Importa TXT na UI         Cargas em andamento
2. Gera TXT/CSV + manifesto       (SMATRICPL/SMATRICULA     (FLAN 1MA/1MB hoje);
3. Carrega via WS o que dá         e massas validadas)      avisar antes de
5. Baixas em massa             6. Aprova gate de            qualquer escrita
7. Reconcilia 3 fontes            reconciliação             em massa
```

---

## 3. Pipeline padrão por lote (ano × filial × turma(s))

### FASE 0 — Pré-condições (uma vez)
- [ ] Fix `export_v2.sparcela` aplicado (2 bugs: fallback SERVIC→MENS→REMATR + dedup 173 UK do achado Isaac 19/05) e **materializado** (matview + UNIQUE INDEX + REFRESH CONCURRENTLY — padrão Isaac; 4min/84 RAs como view é inviável em lote)
- [ ] Views regeradas emitindo **NOME genérico** (lookup do Importador é por NOME literal: se o TXT disser "2024 MENS EM" o RM resolve pro 299, não pro 2)
- [ ] De-para legado→genérico construído (~200-300 nomes; base: doc consolidação do Isaac)
- [ ] Dump baseline do schema export/export_v2 live no repo (Isaac aplicou ~20 fixes direto no live que não estão em repo nenhum)
- [ ] Higiene HOMOLOG coordenada com Isaac (§6)

### FASE 1 — Estrutura (Claude via WS SaveRecord)
SPLETIVO (criar F1 2019/2020/2023/2025 faltantes) → SHABILITACAOFILIAL → SHABILITACAOFILIALPL → STURMA → STURMADISC → SSERVICO genéricos → SPLANOPGTO → SHABMODELOPGTO → SBOLSA/SBOLSAPLETIVO → FCFO (XML FinCFOImportacao em massa ou CODCFO=-1 via FinCFODataBR)

### FASE 2 — Gate PRÉ-import (Claude, BLOQUEIA se FAIL)
Por view do lote: duplicatas por chave natural, nulos críticos, cardinalidade por CODPERLET/CODTURMA, soma por serviço vs `servicos_historico` cru, encoding (`\xef\xbf\xbd` check). Modelo: audit_view.py do Isaac (8 seções).

### FASE 3 — Pessoas + Matrículas (Claude gera, Guilherme importa)
PPESSOA/SALUNO/SHABILITACAOALUNO (WS) → **SMATRICPL.txt → SMATRICULA.txt** (Importador UI; ordem obrigatória; layouts na biblioteca §7). Capturar e versionar o log do Importador ("Layout esperado:") a cada tabela nova.

### FASE 4 — Professores + Horários (lógica Isaac + fonte nossa)
SPROFESSOR mestre (91 canônicos da API live; NÃO usar tabela_professor_rm corrompida) → refresh matviews dele (matching 5 níveis) → SPROFESSORTURMA → SHORARIOTURMA/SHORARIOPROFESSOR. Antes: limpar 11-13 CODPROF órfãos.

### FASE 5 — Financeiro (Claude gera, Guilherme importa o massivo)
SCONTRATO (consolidado, plano do ano) → SPARCELA (serviço GENÉRICO, valor real, desconto inline TIPODESC) → SBOLSAALUNO (regra anti-duplo-abatimento: se desconto já está na parcela, bolsa entra só cadastral — fechar com consultor) → FLAN via `flan_txt.py` do Isaac (porte fiel da macro VBA; **calibrar escala com 1 registro por ambiente** — DEV interpretou x10000)

### FASE 5b — SLAN (⚠️ NÃO ESQUECER — é o vínculo acadêmico↔financeiro)
**SLAN liga a SPARCELA (Educacional) ao FLAN (Financeiro) via IDLAN.** Sem ela: boleto não aparece pro aluno/portal, baixa não reflete no acadêmico, e os dois módulos ficam órfãos um do outro. Depende de: SPARCELA + FLAN já carregados. Fontes: view `export_v2.slan` (depende da sparcela — atenção em DROP CASCADE!), layout em `data/exportacoes/2026-05-08/slan.txt` e `09_slan.txt` (kit Maria), template em `docs/Lista de tabelas/SLAN.html`. Correção do Guilherme em 2026-06-11: a primeira versão deste fluxo havia omitido a SLAN.

### FASE 6 — Baixas (A CONSTRUIR — ninguém tem)
Fonte: STATUSGENNERA/VALORPAGO/DATAPAGAMENTO (staging anos fechados; API live ano corrente). Caminhos a testar em ordem: (1) wsFin.BaixaLancamento; (2) FLAN nascendo baixado (XML FinLAN dos logs do Isaac tem VALORBAIXADO/BAIXAAUTORIZADA); (3) baixa em lote na UI. Após baixa: conferir reflexo via SLAN no lado acadêmico.

### FASE 7 — Histórico
SHISTDISCCOL (view pronta, 154.693 rows) + DIASLETIVOS no SHISTALUNOCOL já carregado.

### FASE 8 — Gate PÓS-import (Claude, aprovação bloqueante)
Reconciliação por **fingerprint multiset** (CODSERVICO, PARCELA, COTA, VALOR, DTVENC) por RA — detecta faltantes E sobras — nas 3 fontes (API live × staging × RM). Lembrar: SPARCELA.VALOR no ReadView vem em **centavos**. Persistir mapas nome→ID RM em JSON (padrão logs/mapa_*.json do Isaac). Gravar manifesto do lote (arquivos, hashes, contagens, somas, operador, timestamp) em data/audit/. Só então marcar "Concluído" na planilha ORDEM.

---

## 4. Novo piloto "da maneira correta" (proposta)

Cobrir o que NENHUM piloto anterior cobriu: **1 turma pequena de UN2 (Filial 2 — ex.: EI com turnos Manhã/Tarde) + ano fechado**, com:
serviços genéricos 1-4 ✓ contrato consolidado ✓ baixas espelhando Gennera ✓ SHISTDISCCOL+DIASLETIVOS ✓ professores/horários ✓ manifesto desde o início ✓ views congeladas por tag git ✓
Gate final: zero divergência inexplicada nas 3 fontes → fluxo vira linha de produção pros demais anos/turmas.

---

## 5. Perguntas pendentes (1 resposta cada)

1. **Isaac:** o "TOTVS DEV" `192.168.1.91:8051` (HTTP, mestre:integracao) é o MESMO banco do cloud `associacaoescola200767:10207`? (teste: criar registro inócuo no 8051, ler no cloud). Se não for, há um 2º ambiente não auditado.
2. **Isaac:** qual ferramenta usou nas ~2.700 SPARCELA a 3/seg (20-21/05)? ("gerar parcelas do plano" ORIGEM=PP × script próprio × conversor)
3. **Isaac:** a parcela R$ 100 (IDPARCELA 12752) — ele já investigava (_verifica_r100); alinhar antes do DeleteRecord.
4. **Isaac:** pedir o **vault Obsidian** (198 notas + 3 canvas, citado no SETUP.md dele como doc central — não veio na pasta).
5. **Consultor:** SPLANOPGTO precisa de SPARCPLANO esqueleto (child rows) pro Importador/UI aceitarem SCONTRATO/SPARCELA? Se não → descartar SPARCPLANO de vez.
6. **Consultor:** SBOLSAALUNO + desconto inline na parcela = duplo abatimento? Qual a forma canônica?
7. **Consultor/TOTVS:** chamado formal pra destravar EduMatricPLData.SaveRecord (plano B: wsProcess/EduMatriculaProcData — schema em logs do Isaac).

---

## 6. Higiene HOMOLOG (coordenar com Isaac ANTES — ele tem carga em andamento)

Pré-requisito: consolidar logs/mapa_*.json dele no nosso repo (única trilha de auditoria dos pilotos).
- Parcela espúria IDPARCELA 12752 (R$ 100, RA 20121839)
- Resíduo turma 3M (RA 20101529: SMATRICPL/SCONTRATO 7572-7573/5 SPARCELA/SNOTAETAPA de ano fechado)
- Serviços de teste: 271-273, 279-282, 300, e destino dos 292-306 (não reusar)
- ~180 CODBOLSA com duplicatas por mojibake (risco: lookup por NOME resolve pro código errado em silêncio)
- 11-13 CODPROF órfãos em SPROFESSORTURMA
- Contratos órfãos de parcela (7, 7572)

## 7. Ativos adotados do projeto Isaac (onde estão)

| Ativo | Origem | Destino |
|---|---|---|
| Biblioteca de layouts (35 tabelas: header, separador, encoding) | data/exports/csv dele | `data/exportacoes/2026-06-11/isac-layouts.json` → versionar resumo em knowledge/totvs/13 |
| Convenções TXT Importador | comprovadas nos imports dele | cp1252/latin-1, `;`, SEM header, CRLF, sem BOM, sem aspas, nome=view minúsculo |
| `flan_txt.py` (gerador FLAN posicional fiel à macro) | gennera-totvs/src/export/ | copiar p/ scripts/ |
| Macro oficial FLAN .xlsm + fcfo_layout.csv | data/reference dele | knowledge/totvs/ |
| logs/mapa_*.json (de-para nome→ID dos pilotos) | gennera-totvs/logs/ | data/ (trilha de auditoria) |
| Matviews que não temos: saluno, sdiscgrade, shorarioturma, shorarioprofessor, sprofessor live | aplicadas no banco live | re-dumpar DDL pro repo |
| totvs_api_reference.md (16 DataServers, PKs, obrigatórios) | data/reference dele | merge em knowledge/totvs/09 |
| Dicionário SHORARIO* oficial | Clauwork/data/ | knowledge/totvs/ |
| Padrão CDP (Chrome 9222 + connect_over_cdp) p/ painel Gennera | automation/ | extrair "Erros de Pagamento" PJBank (API não expõe) |
| Salvaguardas de automação (DRY_RUN, alvo único, screenshot/passo) | museu_cafe.py | checklist padrão |
| professores_funcionarios.csv (154) + Talvez_Bolsas.csv (14.909 descontos/fatura) | data/reference dele | insumo SPROFESSOR/validação bolsas |

**NÃO usar:** repo "clean" do GitHub como referência (snapshot stale com layouts errados); tabela_professor_rm (corrompida); doc de consolidação por série (superado pela D1); CODFILIAL=1 fixo (EDF tem 2 filiais).

## 8. Governança

- `Isac/` no .gitignore (FEITO 2026-06-11) — contém credenciais reais e PII
- Repo = fonte de verdade das views; quem altera o live commita o DDL no mesmo dia; avisar antes de DROP CASCADE
- Janela de congelamento: nenhuma carga durante auditoria/medição
- Toda carga gera manifesto + mapa JSON pós-import
- Backup pg_dump→Drive: formalizar agendamento (BACKUP42 em 10/06 foi manual)
- JWT da API Gennera atual NÃO expira (sem campo exp) — confirmado 2026-06-10/11 nas duas frentes; atualizar protocolo de guarda
