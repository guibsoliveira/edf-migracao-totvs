# 04 - Regras de Negocio TOTVS RM

Data: 2026-05-19

## 1. IDPERLET (Periodo Letivo)

Cada ano/semestre tem ID numerico FIXO no RM:

2023 = IDPERLET 15
2024 = IDPERLET 18 (Fundamental) ou 19 (Medio)
2026 = IDPERLET 1 ou 2 (testes homolog)
2022 = NAO EXISTE (precisaria criar SPLETIVO se migrasse)

- NAO gerado automaticamente
- Mapeado em SPLETIVO.IDPERLET
- Critico em SCONTRATO, SPARCELA, SPLANOPGTO

**Validacao:** Confirmar IDPERLET antes de SaveRecord

## 2. IDHABILITACAOFILIAL

Combinacao unica: (CODCOLIGADA + CODFILIAL + CODCURSO + CODHABILITACAO)

- Precisa estar pre-cadastrado em SHABILITACAOFILIAL
- FK em SMATRICULA, SCONTRATO (indiretamente via SCURSO+CODHABILITACAO)
- Gerado pelo RM ao criar SHABILITACAOFILIAL

**Validacao:** Verificar se SHABILITACAOFILIAL existe antes de SMATRICULA

## 3. CODSISTEMA (Educacional vs Financeiro)

- S = Educacional
- G ou F = Financeiro classico
- NAO passa no Contexto SOAP (quebra Nivel -1)
- Usa-se SO em queries SQL diretas no Postgres

**Armadilha:** Remover CODSISTEMA= do Contexto wsDataServer

## 4. CODNIVELENSINO (Nivel de Ensino)

- 1 = Basico (EDF padrão)
- 2 = Fundamental
- 3 = Medio
- Vinculado a STIPOCURSO
- Obrigatorio em Contexto SOAP

**Validacao:** Manter sempre = 1 para EDF

## 5. Granularidade de SCONTRATO

EDF usa: 1 SCONTRATO consolidado por aluno+ano

Nao faz:
- 1 contrato por servico (evitar duplicacao)
- 1 contrato por aluno+filial+turma (usar aluno+ano so)

**Resultado:** Maria 2024 = 1 SCONTRATO, N SPARCELAS (MENS, ALIM, MAT)

## 6. SPARCELA - Ordem e Numeracao

Parcelas numeradas por CODSERVICO:

MENS 1, MENS 2, ..., MENS 12
ALIM 1, ALIM 2, ..., ALIM 12
MAT 1, MAT 2, ..., MAT 12

- PARCELA = numero da parcela (1-12 ou 1-36)
- COTA = numero da cota (sempre 1)
- CODSERVICO = referencia ao servico

**Validacao:** Nao permitir PARCELA > 12 sem CODSERVICO diferente

## 7. SBOLSAALUNO (Bolsa por Aluno)

Desconto individual:
- DESCONTO = valor ou percentual
- TIPODESC = V (valor) ou P (percentual)
- CODSERVICO = aplica-se a qual servico
- PARCELAINICIAL/PARCELAFINAL = em qual intervalo

**Regra:** Bolsa se aplica a SERVICO especifico, nao ao CONTRATO todo

## 8. FCFO (Responsavel Financeiro) - Optional

Se nao usar FCFO separado:
- Deixar CODCFO = 1 (responsavel padrao)
- Ou linkar PPESSOA como responsavel

**Consultor TOTVS sugeriu:** Pular FCFO na migracao, usar PPESSOA

## 9. SPARCPLANO (Optional)

Tabela opcional que liga SPLANOPGTO + SSERVICO

- Consultor TOTVS sugeriu: PULAR
- Se nao preencher, deixar vazio (nao é obrigatorio)

## 10. Validacoes Automáticas do RM

SaveRecord falha se:

[ ] CODCOLIGADA NAO existe em GCOLIGADA
[ ] CODFILIAL NAO existe em GFILIAL
[ ] RA NAO existe em SALUNO
[ ] CODCONTRATO NAO existe em SCONTRATO (quando SaveRecord SPARCELA)
[ ] CODSERVICO NAO existe em SSERVICO
[ ] CODCFO NAO existe em FCFO
[ ] IDPERLET NAO existe em SPLETIVO
[ ] DTVENCIMENTO < DTCOMPETENCIA
[ ] VALOR negativo (precisa desconto separado)

**Erro retorna:** ORA-02291 (FK nao existe) ou ORA-01400 (NOT NULL falta)

## 11. Tipos de Layout Posicional (FLAN, FCFO)

Nao use SaveRecord em FCFO.

Se precisar importar FLAN:
- Usar TXT posicional (De/Ate)
- Encoding: ANSI Windows-1252 obrigatorio
- Ou usar wsFin.SaveLancamento (SOAP)

FLAN: NAO importar manualmente. Deixar RM gerar via SPARCELA.

## 12. Ordem de Importacao Obrigatoria

Fase 1: SPLETIVO (tudo depende de IDPERLET)
Fase 2: SSERVICO (dependencia de SPLETIVO)
Fase 3: SPLANOPGTO (dependencia de SPLETIVO)
Fase 4: SHABMODELOPGTO (dependencia acima)
Fase 5: SCONTRATO (dependencia de SPLANOPGTO)
Fase 6: SPARCELA (dependencia de SCONTRATO)
Fase 7: SBOLSAALUNO (dependencia de SPARCELA)
Fase 8: FLAN (gerado automaticamente, opcionalmente wsFin)

## 13. Validacao Pre-Importacao

Antes de SaveRecord em massa:

1. ReadView em SCONTRATO para ver o que ja existe
2. ReadView em SPARCELA para evitar duplicatas
3. Verificar IDPERLET da view export_v2.spletivo
4. Confirmar CODSERVICO em export_v2.sservico
5. Confirmar CODCFO em export_v2.fcfo

## 14. Cross-Check Pos-Importacao

Apos SaveRecord:
- ReadView mesma tabela para confirmar insercao
- Contar registros inseridos vs esperado
- Verificar FK orphans (select com LEFT JOIN)
- Verificar soma de VALOR vs esperado

---

**LEMBRETE:** Documentacao completa: templates TOTVS em docs/Lista de tabelas/

