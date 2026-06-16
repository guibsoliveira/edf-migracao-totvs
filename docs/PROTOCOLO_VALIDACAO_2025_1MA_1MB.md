# Protocolo de Validação — Piloto EM 1MA/1MB 2025 (Filial 1)

> Double-check independente da carga do Isac. A cada camada importada, comparo
> RM (destino) × baseline esperado (nossas views + staging) × Gennera API live.
> Baseline de referência: data/exportacoes/2026-06-11/baseline_2025_1MA_1MB.json

## Pré-requisito CRÍTICO (bloqueante)
- [ ] **SPLETIVO 2025 Filial 1 criado** — NÃO existe hoje no RM (só F2=IDPERLET 3).
  Sem ele nada de 2025 F1 entra. Capturar o IDPERLET gerado (será novo, ≠ dos
  outros anos). Validação: ReadView EduPLetivoData CODPERLET=2025 CODFILIAL=1.

## Ordem de validação (a cada "Isac importou X", eu checo X)

| # | Camada | O que comparo | Critério de PASS |
|---|--------|---------------|------------------|
| 1 | SPLETIVO/SHABFILIAL/STURMA/STURMADISC | estrutura 1MA/1MB existe; IDs gerados | turmas 1MA+1MB presentes; STURMADISC = nº disciplinas da grade |
| 2 | PPESSOA/SALUNO | todo RA do baseline tem SALUNO; nome sem mojibake | 100% dos RAs; 0 acento corrompido |
| 3 | SHABILITACAOALUNO | vínculo aluno↔habilitação | 1 por aluno |
| 4 | **SMATRICPL** (Importador UI) | nº de matrículas-período = nº alunos baseline | RM == baseline (por turma) |
| 5 | **SMATRICULA** (Importador UI) | nº disciplinas por RA = baseline | por RA, RM == baseline |
| 6 | SPROFESSOR/SPROFESSORTURMA/SHORARIO* | profs e horários da turma | vínculos presentes (se no escopo) |
| 7 | SSERVICO | **genéricos 1-4, VALOR=0** (D1) | NÃO usar 29X/279-282; valor zero |
| 8 | SPLANOPGTO/SHABMODELOPGTO | plano do ano + ponte habilitação | plano 25XXXX; habmodelo vinculado |
| 9 | **SCONTRATO** | 1 consolidado/aluno (D2) | RM 1/aluno; todo RA com contrato |
| 10 | **SPARCELA** ⚠️ | nº + soma bruta por RA e por serviço; VALOR em centavos no ReadView | RM == baseline parcela-a-parcela (fingerprint CODSERVICO+PARCELA+VALOR+DTVENC) |
| 11 | **SBOLSAALUNO** | bolsas por RA; cuidado duplo abatimento c/ desconto inline | RM == baseline; desconto não dobrado |
| 12 | **FLAN** | lançamentos por CFO; escala de valor calibrada | soma FLAN == soma SPARCELA do CFO |
| 13 | **SLAN** | vínculo SPARCELA↔FLAN (IDLAN) | toda parcela financeira com lançamento ligado |
| 14 | **BAIXAS** (D3) | status RM espelha Gennera | soma baixada RM == soma paga Gennera; 0 boleto pago em aberto |
| 15 | SHISTDISCCOL/SHISTALUNOCOL | histórico (se no escopo) | nota/falta/CH por disciplina; DIASLETIVOS≠0 |

## Foco redobrado no FINANCEIRO (10-14)
- Comparo nas **3 fontes**: RM (ReadView) × nossa view × Gennera API live (/contracts/detailed).
- Lembrar: `SPARCELA.VALOR` no ReadView vem em **centavos** (÷100).
- Reconciliação por **fingerprint multiset** por RA — detecta faltante E sobra.
- Pagamentos pós-cutoff dez/2025: 2025 é ano fechado, mas pagamento de inadimplente
  recebido em 2026 só está na **API live** — usar API, não staging, para status final.
- Serviço genérico: o TXT manda NOME; conferir que o lookup resolve pro COD certo.

## Saída de cada checagem
Para cada camada: veredito (ESPELHO_OK / DIVERGENTE / BLOQUEIO), números lado-a-lado,
e — se divergir — causa provável (gap de carga × bug view × erro origem × modelagem)
e ação. Dados brutos em data/exportacoes/.
