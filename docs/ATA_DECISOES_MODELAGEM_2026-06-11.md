# ATA — Decisões de Modelagem da Migração Gennera → TOTVS RM

**Data:** 2026-06-11
**Participantes:** Guilherme Oliveira (analista sênior — decisor), Isaac Barbosa Soares (assistente — confirmou D1 por telefone)
**Pendente de ciência:** Consultor TOTVS (itens P1-P3 abaixo)
**Contexto:** auditoria tripla do piloto 1MA/1MB 2024 (docs/ANALISE_MIGRACAO_PILOTO_2024.md) + consolidação das duas frentes de trabalho (knowledge/fluxo/08_fluxo_definitivo_migracao.md)

---

## Decisões CONGELADAS

**D1 — SSERVICO genérico.** Catálogo de serviços usa APENAS os códigos genéricos 1-4 (1=1ª Mensalidade, 2=Mensalidade, 3=Material Didático, 4=Alimentação), **sem ano nem segmento no nome**, com **VALOR=0 no SSERVICO** — o valor real de cada cobrança vai na SPARCELA. Confirmado por telefone Guilherme↔Isaac em 11/06. *Revoga:* o padrão por ano/segmento usado no piloto 2024 (CODs 292-306) e a proposta de canônico por série do doc de consolidação de 07/05. Serviços novos legítimos (ex: Material de Artes, 310) seguem o mesmo princípio: genérico, valor zero.

**D2 — SCONTRATO consolidado.** 1 contrato por aluno × período letivo no RM. Fundamentação de negócio: a própria EDF unificou a cobrança (boletos separados de Alimentação/Material/Mensalidade → boleto único "Mensalidade" por responsável; 1ª Mensalidade fora; anuidade caso à parte). Os hashes dos contratos Gennera originais ficam preservados em mapa JSON de rastreio para auditoria.

**D3 — Baixas obrigatórias.** O status de cada parcela/lançamento no RM deve espelhar o status REAL do Gennera (pago→baixado, atrasado→em aberto, etc.). Critério de aceite de qualquer lote: soma baixada no RM == soma paga no Gennera, parcela a parcela. Nenhum cutover para PROD com boletos "vencidos em aberto" que já foram pagos.

**D4 — Carga dual (WS + Importador UI).** O que o WS SaveRecord aceita → automatizado (Claude). O que está bloqueado (SMATRICPL/SMATRICULA) → Claude gera o arquivo no layout exato e Guilherme importa manualmente na UI do Importador TOTVS. Etapa manual é parte oficial do fluxo, com manifesto de carga registrado.

**D5 — Histórico em 2 camadas.** Anos FECHADOS (2015-2025): SHISTDISCCOL + SHISTALUNOCOL (com DIASLETIVOS preenchido) — sem notas detalhadas (mantém decisão de 21/05 de não migrar SNOTAS/SPROVAS/SFREQUENCIA). Ano CORRENTE/portal ativo: SNOTAETAPA (nota por etapa). SNOTAETAPA não entra em ano fechado.

**D6 — SLAN obrigatória na sequência.** SLAN é o vínculo acadêmico↔financeiro (SPARCELA↔FLAN). Entra em toda carga após FLAN, antes da validação de baixas. (Registrada após correção do Guilherme em 11/06 — a sequência inicial a havia omitido.)

## Pendências com o CONSULTOR TOTVS

- **P1:** SPARCPLANO pode ser totalmente descartada com D1 (valor na SPARCELA)? Ou o SPLANOPGTO/Importador exige SPARCPLANO mínima (child rows — erro "There is no row at position 0")?
- **P2:** SBOLSAALUNO + desconto inline na parcela (TIPODESC): qual a forma canônica para não gerar duplo abatimento? Bolsa cadastral + desconto zerado na parcela, ou só desconto na parcela sem bolsa mestre?
- **P3:** Destravamento de `EduMatricPLData.SaveRecord` (bloqueio global do DataServer, reproduzido com 2 usuários) — chamado formal.

## Ações decorrentes já executadas (11/06)

- Fix v3.2 da `export_v2.sparcela` aplicado (fallback ALIM/Material→contrato Mensalidade) — regressão PASS (RAs 20152214: 41/R$93.498, 20121769: 28, 20121794: 46, Diego 2022: 37 mantidas)
- Baseline das 53 views do banco live versionada no repo (incl. matviews do Isaac e slan)
- `Isac/` adicionado ao .gitignore (credenciais/PII)

## Higiene HOMOLOG (a executar COORDENADO — Isaac tem carga em andamento)

Parcela espúria IDPARCELA 12752 · resíduo turma 3M (RA 20101529) · serviços de teste 271-273/279-282/300 e destino dos 292-306 · bolsas duplicadas por mojibake · 11-13 CODPROF órfãos · contratos órfãos 7/7572 · SNOTAETAPA em ano fechado.

---
*Assinaturas/ciência: Guilherme ____ · Isaac ____ · Consultor ____*
