# 09 - Dicionario de Campos - Tabelas Chave

**Versao:** 1.0 | **Data:** 2026-05-19 | **Fonte:** docs/Lista de tabelas/ HTML templates

---

## SCONTRATO (Contrato Aluno)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada (empresa) | GCOLIGADA.CODCOLIGADA (1) |
| 2 | CODCURSO | TEXTO | 10 | NAO | SIM | Codigo curso | SCURSO.CODCURSO (FUNDAMENTAL, MEDIO) |
| 3 | CODHABILITACAO | TEXTO | 10 | NAO | SIM | Codigo habilitacao (serie) | SHABILITACAO.CODHABILITACAO (EF1, EM1) |
| 4 | CODGRADE | TEXTO | 10 | NAO | SIM | Codigo grade/matriz curricular | SGRADE.CODGRADE (GRADE_EF1) |
| 5 | TURNO | TEXTO | 15 | NAO | SIM | Turno escolar | STURNO.DESCRICAO (MATUTINO, VESPERTINO) |
| 6 | CODFILIAL | INTEIRO | - | NAO | SIM | Codigo filial | GFILIAL.CODFILIAL (1) |
| 7 | CODTIPOCURSO | INTEIRO | - | NAO | SIM | Codigo tipo curso (nivel ensino) | STIPOCURSO.CODTIPOCURSO (1=Basico) |
| 8 | RA | TEXTO | 20 | NAO | SIM | Registro academico aluno | SALUNO.RA (20101529) |
| 9 | CODPERLET | TEXTO | 10 | NAO | SIM | Codigo periodo letivo (ano) | SPLETIVO.CODPERLET (2024) |
| 10 | CODCONTRATO | TEXTO | 20 | NAO | SIM | Codigo unico contrato | PK (7572, 7573) |
| 11 | CODPLANOPGTO | TEXTO | 10 | SIM | NAO | Codigo plano pagamento | SPLANOPGTO.CODPLANOPGTO (241003) |
| 12 | DTCONTRATO | DATA | - | NAO | SIM | Data criacao contrato | Formato AAAA-MM-DD |
| 13 | DTASSINATURA | DATA | - | NAO | SIM | Data assinatura contrato | >= DTCONTRATO |
| 14 | DIAFIXO | TEXTO | 1 | SIM | NAO | Dia fixo vencimento | S/N (padrao: N) |
| 15 | DIAVENCIMENTO | INTEIRO | - | SIM | NAO | Dia mes vencimento | 1-31 (padrao: 10) |
| 16 | TIPOCONTRATO | TEXTO | 1 | NAO | SIM | Tipo contrato | P=Plano, S=Servico |
| 17 | TIPOBOLSA | TEXTO | 1 | NAO | SIM | Modo aplicacao bolsas | S=Somar, C=Cascata, M=Maior |
| 18 | CODCCUSTO | TEXTO | 25 | SIM | NAO | Centro de custo | GCCUSTO.CODCCUSTO |
| 19 | ASSINADO | TEXTO | 1 | SIM | NAO | Contrato assinado | S/N (padrao: S) |
| 20 | STATUS | TEXTO | 1 | NAO | SIM | Status contrato | N=Normal, S=Cancelado |
| 21 | DTCANCELAMENTO | DATA | - | SIM | NAO | Data cancelamento | Obrigatorio se STATUS=S |

**View source:** export_v2.scontrato

---

## SPARCELA (Parcela Contrato)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada | GCOLIGADA (1) |
| 2 | CODCURSO | TEXTO | 10 | NAO | SIM | Codigo curso | = SCONTRATO |
| 3 | CODHABILITACAO | TEXTO | 10 | NAO | SIM | Codigo habilitacao | = SCONTRATO |
| 4 | CODGRADE | TEXTO | 10 | NAO | SIM | Codigo grade | = SCONTRATO |
| 5 | TURNO | TEXTO | 15 | NAO | SIM | Turno | = SCONTRATO |
| 6 | CODFILIAL | INTEIRO | - | NAO | SIM | Codigo filial | = SCONTRATO |
| 7 | CODTIPOCURSO | INTEIRO | - | NAO | SIM | Tipo curso | = SCONTRATO |
| 8 | RA | TEXTO | 20 | NAO | SIM | Registro academico | = SCONTRATO |
| 9 | CODPERLET | TEXTO | 10 | NAO | SIM | Periodo letivo | = SCONTRATO |
| 10 | CODCONTRATO | TEXTO | 20 | NAO | SIM | Codigo contrato | FK SCONTRATO (7572) |
| 11 | SERVICO | TEXTO | 60 | NAO | SIM | Nome servico | SSERVICO.NOME (MENS, ALIM, MAT) |
| 12 | PARCELA | INTEIRO | - | NAO | SIM | Numero parcela | 1-12 por servico |
| 13 | COTA | INTEIRO | - | NAO | SIM | Numero cota | Sempre 1 |
| 14 | VALOR | NUMERICO | 10,4 | NAO | SIM | Valor parcela | Formato virgula (1500,00) |
| 15 | DTVENCIMENTO | DATA | - | NAO | SIM | Data vencimento | AAAA-MM-DD |
| 16 | DESCONTO | NUMERICO | 10,4 | NAO | SIM | Valor desconto | Formato virgula |
| 17 | TIPODESC | TEXTO | 1 | NAO | SIM | Tipo desconto | V=Valor, P=Percentual |
| 18 | TIPOPARCELA | TEXTO | 1 | NAO | SIM | Tipo parcela | P=Plano, E=Extra, A=Adicional |
| 19 | VALORAUTOMATICO | TEXTO | 1 | NAO | SIM | Calculado por creditos | S/N (padrao: N) |
| 20 | DTCOMPETENCIA | DATA | - | SIM | NAO | Data competencia | Dia 1 fixo (2024-02-01) |
| 21 | CODCOLCFO | INTEIRO | - | NAO | SIM | Coligada responsavel financeiro | GCOLIGADA (1) |
| 22 | CODCFO | TEXTO | 25 | NAO | SIM | Codigo responsavel financeiro | FCFO.CODFFO (1) |

**View source:** export_v2.sparcela

**Nota importante:** VALOR aceita NUMERICO(10,4) com formato virgula em XML, NAO ponto.

---

## SSERVICO (Servico/Item)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada | GCOLIGADA (1) |
| 2 | NOME | TEXTO | 60 | NAO | SIM | Nome servico | MENS, ALIM, MAT |
| 3 | VALOR | NUMERICO | 10,4 | NAO | SIM | Valor padrao | Formato virgula |
| 4 | CODTIPOCURSO | INTEIRO | - | NAO | SIM | Tipo curso | STIPOCURSO (1) |
| 5 | CODCOLCXA | INTEIRO | - | SIM | NAO | Coligada conta caixa | GCOLIGADA |
| 6 | CODCXA | TEXTO | 10 | SIM | NAO | Codigo conta caixa | FCXA.CODCXA |
| 7 | VERIFICAINADIMPLENCIA | TEXTO | 1 | SIM | NAO | Verifica inadimplencia | S/N |
| 8 | TIPOCONTABILLAN | INTEIRO | - | SIM | NAO | Tipo contabil | 0=Nao, 1=Sim, 2=Baixa, 3=A contabilizar |
| 9 | CODTDO | TEXTO | 10 | SIM | NAO | Tipo documento | FTDO.CODTDO |
| 10 | CODCOLNATFINANCEIRA | INTEIRO | - | SIM | NAO | Coligada natureza financeira | GCOLIGADA |
| 11 | NATFINANCEIRA | TEXTO | 40 | SIM | NAO | Natureza financeira | TTBORCAMENTO |
| 12 | PERMITEACORDO | TEXTO | 1 | NAO | SIM | Permite acordos | S/N |
| 13 | APROVEITACONTACORRENTE | TEXTO | 1 | SIM | NAO | Aproveita conta corrente | S/N |
| 14 | CONSIDERAPARCELAFIXA | TEXTO | 1 | SIM | NAO | Considera parcela fixa | S/N |
| 15 | DISPONIVELEXTENSAO | TEXTO | 1 | SIM | NAO | Disponivel extensao | S/N |
| 16 | DESCONSIDERACREDITORETROATIVO | TEXTO | 1 | SIM | NAO | Desconsidera credito retroativo | S/N |
| 17 | PGCARTAODEBITO | TEXTO | 1 | NAO | SIM | Pagavel cartao debito | S/N |
| 18 | PGCARTAOCREDITO | TEXTO | 1 | NAO | SIM | Pagavel cartao credito | S/N |
| 19 | CONSIDERADESCANTECIPACAO | TEXTO | 1 | SIM | NAO | Considera desconto antecipacao | S/N |

**View source:** export_v2.sservico

---

## SPLANOPGTO (Plano Pagamento)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada | GCOLIGADA (1) |
| 2 | CODPERLET | TEXTO | 10 | NAO | SIM | Codigo periodo letivo | SPLETIVO.CODPERLET (2024) |
| 3 | CODPLANOPGTO | TEXTO | 10 | NAO | SIM | Codigo plano | PK unico (241003) |
| 4 | DESCRICAO | TEXTO | 60 | NAO | SIM | Descricao texto | "Plano 12 parcelas EM 2024" |
| 5 | NOME | TEXTO | 60 | NAO | SIM | Nome plano | "PLANO_EM_2024" |
| 6 | DTINICIO | DATA | - | SIM | NAO | Data inicio validade | AAAA-MM-DD |
| 7 | DTFIM | DATA | - | SIM | NAO | Data fim validade | AAAA-MM-DD |
| 8 | DESCONTO | NUMERICO | 10,4 | NAO | SIM | Desconto padrao | Formato virgula |
| 9 | CODTIPOCURSO | INTEIRO | - | NAO | SIM | Tipo curso | STIPOCURSO (1) |
| 10 | CODFILIAL | INTEIRO | - | NAO | SIM | Codigo filial | GFILIAL (1) |
| 11 | MATRICULALIVRE | TEXTO | 1 | NAO | SIM | Matricula livre | S/N |
| 12 | TIPOBLOQUEIOVLRBASEPERSONALIZ | TEXTO | 1 | SIM | NAO | Bloqueia personalizacao | S/N |

**View source:** export_v2.splanopgto

---

## SHABMODELOPGTO (Ligacao Plano + Habilitacao)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada | GCOLIGADA (1) |
| 2 | CODPERLET | TEXTO | 10 | NAO | SIM | Codigo periodo letivo | SPLETIVO.CODPERLET (2024) |
| 3 | CODPLANOPGTO | TEXTO | 10 | NAO | SIM | Codigo plano | SPLANOPGTO.CODPLANOPGTO |
| 4 | CODTIPOCURSO | INTEIRO | - | NAO | SIM | Tipo curso | STIPOCURSO (1) |
| 5 | CODCURSO | TEXTO | 10 | NAO | SIM | Codigo curso | SCURSO.CODCURSO |
| 6 | CODHABILITACAO | TEXTO | 10 | NAO | SIM | Codigo habilitacao | SHABILITACAO.CODHABILITACAO |
| 7 | CODGRADE | TEXTO | 10 | NAO | SIM | Codigo grade | SGRADE.CODGRADE |
| 8 | TURNO | TEXTO | 15 | NAO | SIM | Turno | STURNO.DESCRICAO |
| 9 | CODFILIAL | INTEIRO | - | NAO | SIM | Codigo filial | GFILIAL (1) |

**View source:** export_v2.shabmodelopgto

---

## SBOLSAALUNO (Bolsa Aluno)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada | GCOLIGADA (1) |
| 2 | CODCURSO | TEXTO | 10 | NAO | SIM | Codigo curso | = SCONTRATO |
| 3 | CODHABILITACAO | TEXTO | 10 | NAO | SIM | Codigo habilitacao | = SCONTRATO |
| 4 | CODGRADE | TEXTO | 10 | NAO | SIM | Codigo grade | = SCONTRATO |
| 5 | TURNO | TEXTO | 15 | NAO | SIM | Turno | = SCONTRATO |
| 6 | CODFILIAL | INTEIRO | - | NAO | SIM | Codigo filial | = SCONTRATO |
| 7 | CODTIPOCURSO | INTEIRO | - | NAO | SIM | Tipo curso | = SCONTRATO |
| 8 | RA | TEXTO | 20 | NAO | SIM | Registro academico | = SCONTRATO |
| 9 | CODPERLET | TEXTO | 10 | NAO | SIM | Periodo letivo | = SCONTRATO |
| 10 | CODCONTRATO | TEXTO | 20 | NAO | SIM | Codigo contrato | FK SCONTRATO |
| 11 | NOMEBOLSA | TEXTO | 60 | NAO | SIM | Nome bolsa | SBOLSA.NOME (BOLSA_MEIA) |
| 12 | SERVICO | TEXTO | 60 | NAO | SIM | Nome servico | SSERVICO.NOME (MENS) |
| 13 | DTINICIO | DATA | - | Condicional | SIM/NAO | Data inicio bolsa | Se validade por data |
| 14 | DTFIM | DATA | - | Condicional | SIM/NAO | Data fim bolsa | Se validade por data |
| 15 | DESCONTO | NUMERICO | 10,4 | NAO | SIM | Valor desconto | Formato virgula |
| 16 | TIPODESC | TEXTO | 1 | NAO | SIM | Tipo desconto | V=Valor, P=Percentual |
| 17 | OBS | TEXTO | Livre | SIM | NAO | Observacao | Texto livre |
| 18 | PARCELAINICIAL | INTEIRO | - | Condicional | SIM/NAO | Parcela inicial | Se validade por parcela |
| 19 | PARCELAFINAL | INTEIRO | - | Condicional | SIM/NAO | Parcela final | Se validade por parcela |
| 20 | CODUSUARIO | TEXTO | 20 | NAO | SIM | Codigo usuario criador | GUSUARIO (SISTEMA) |
| 21 | ORDEMBOLSA | INTEIRO | - | SIM | NAO | Ordem aplicacao | 1, 2, 3... |
| 22 | DATACONCESSAO | DATA | - | SIM | NAO | Data concessao | AAAA-MM-DD |
| 23 | DATAAUTORIZACAO | DATA | - | SIM | NAO | Data autorizacao | AAAA-MM-DD |
| 24 | TETOVALOR | NUMERICO | 10,4 | SIM | NAO | Teto desconto % | Formato virgula |
| 25 | ATIVA | TEXTO | 1 | NAO | SIM | Bolsa ativa | S/N |
| 26 | DATACANCELAMENTO | DATA | - | SIM | NAO | Data cancelamento | Se cancelada |
| 27 | CODUSUARIOCANCEL | TEXTO | 20 | SIM | NAO | Usuario cancelamento | GUSUARIO |
| 28 | MOTIVOCANCELAMENTO | TEXTO | 60 | SIM | NAO | Motivo cancelamento | Texto livre |

**View source:** export_v2.sbolsaaluno

---

## SLAN (Lancamento Financeiro)

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao | Dominio |
|---|-------|------|---------|------|------------|-----------|---------|
| 1 | CODCOLIGADA | INTEIRO | - | NAO | SIM | Codigo coligada | GCOLIGADA (1) |
| 2 | IDLAN | INTEIRO | - | NAO | SIM | ID lancamento | Auto-gerado, PK |
| 3 | CODCONTRATO | TEXTO | 20 | SIM | NAO | Codigo contrato | SCONTRATO.CODCONTRATO (FK) |
| 4 | IDPARCELA | INTEIRO | - | SIM | NAO | ID parcela | SPARCELA.IDPARCELA (FK) |
| 5 | DTDOCUMENTO | DATA | - | NAO | SIM | Data documento | AAAA-MM-DD |
| 6 | VALOR | NUMERICO | 18,4 | NAO | SIM | Valor lancamento | **Atencao: 18,4 NAO 10,4** |
| 7 | TIPODOCUMENTO | TEXTO | 2 | NAO | SIM | Tipo documento | AR (Recebimento) |
| 8 | ... | ... | ... | ... | ... | ... | ... |

**View source:** export_v2.slan

**CRITICA:** Campo VALOR em SLAN tem precisao NUMERICO(18,4) - maior que SPARCELA!

---

## FLAN (Lancamento Contabil) [LEGACY]

Layout posicional - NUNCA usar SaveRecord.

| Pos | Campo | Tipo | Tamanho | Descricao |
|-----|-------|------|---------|-----------|
| 1-6 | CODCOLIGADA | INTEIRO | 6 | Codigo coligada |
| 7-8 | TIPODOCUMENTO | TEXTO | 2 | Tipo documento |
| 9-25 | NUMERO | INTEIRO | 17 | Numero documento |
| 26-28 | PARCELA | INTEIRO | 3 | Numero parcela |
| 29-32 | SERIE | TEXTO | 4 | Serie documento |
| ... | ... | ... | ... | ... |

**Alternativa:** wsFin.SaveLancamento (SOAP) ou deixar RM gerar automatico.

---

## FCFO (Responsavel Financeiro) [LEGACY]

Tabela posicional - NUNCA usar SaveRecord. Layout complexo com 130+ campos.

**Alternativa:** Usar PPESSOA como responsavel, FCFO pode ser ignorado na migracao.

---

## PPESSOA (Pessoa)

Campos principais (lista parcial):

| # | Campo | Tipo | Tamanho | NULL | Obrigatorio | Descricao |
|---|-------|------|---------|------|------------|-----------|
| 1 | CODPESSOA | INTEIRO | - | NAO | SIM | ID pessoa | PK |
| 2 | NOME | TEXTO | 80 | NAO | SIM | Nome completo | Anonimizar em logs |
| 3 | CPF | TEXTO | 11 | SIM | NAO | CPF sem mascara | Anonimizar em logs |
| 4 | CNPJ | TEXTO | 14 | SIM | NAO | CNPJ sem mascara | Anonimizar em logs |
| ... | ... | ... | ... | ... | ... | ... |

**Nota:** PPESSOA tem muitos campos. Usar export_v2.spessoa para ver estrutura esperada.

**Seguranca:** NAO logar CPF, nome ou email de pessoas.

---

## Notas Gerais sobre Tipos de Dados

### NUMERICO(10,4) vs NUMERICO(18,4)

`
SPARCELA.VALOR = NUMERICO(10,4)  (max 999.999,9999)
SLAN.VALOR = NUMERICO(18,4)      (max 99.999.999,9999)
FLAN.VALOR = Posicional           (verifique docs)
`

### Formato Decimal Brasil

Em XML SaveRecord, sempre:
`
CORRETO:  <VALOR>1500,00</VALOR>
ERRADO:   <VALOR>1500.00</VALOR>
`

RM retorna erro se usar ponto em vez de virgula.

### DATA

Sempre AAAA-MM-DD:
`
2024-02-10 = Correto
02/02/2024 = Errado
2024-02-10T00:00:00 = Errado
`

### TEXTO vs INTEIRO

`
CODCURSO = TEXTO (10) -> '  FUNDAMENTAL  ' (pode ter espacos)
CODTIPOCURSO = INTEIRO -> 1 (sem aspas)
`

---

## Checklist Campo-a-Campo

Antes de SaveRecord:

- [ ] CODCOLIGADA = 1 (fixo EDF)
- [ ] CODFILIAL = 1 (fixo EDF)
- [ ] CODPERLET existe em SPLETIVO
- [ ] RA existe em SALUNO
- [ ] CODCFO existe em FCFO
- [ ] VALOR >= 0 em NUMERICO(10,4) formato virgula
- [ ] DTVENCIMENTO >= DTCOMPETENCIA
- [ ] CODTIPOCURSO = 1 (EDF so tem basico)
- [ ] STATUS = N ou S
- [ ] Data fields em AAAA-MM-DD
- [ ] FK nao vazio (nao deletado)

---

**Proximos:** 10_scripts_chamadas_soap.md, 11_estrategia_filtro_perfil.md

