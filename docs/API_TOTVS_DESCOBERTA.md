# API TOTVS RM WebService TBC - Descoberta e Mapeamento

**Data:** 2026-05-13
**Servidor:** `associacaoescola200767.rm.cloudtotvs.com.br:10207`
**Autenticacao:** Basic Auth HTTPS (cert publico valido)

---

## 1. Servicos Disponiveis (12 servicos confirmados)

| Servico | Endpoint | Funcoes principais |
|---------|----------|--------------------|
| **wsConsultaSQL** | `/wsConsultaSQL/IwsConsultaSQL` | `RealizarConsultaSQL` (precisa sentenca pre-cadastrada) |
| **wsDataServer** | `/wsDataServer/IwsDataServer` | `ReadView`, `ReadRecord`, `SaveRecord`, `DeleteRecord`, `GetSchema` |
| **wsFin** | `/wsFin/IwsFin` | `SaveLancamento`, `BaixaLancamento`, `ValorLiquido` (substitui macro Excel!) |
| **wsEdu** | `/wsEdu/IwsEdu` | `ListarBoletos`, `ImprimeBoleto`, `SimularValoresPlanoPgtoTurmaDisc` |
| **wsBase** | `/{svc}/IwsBase` | `AutenticaAcesso` |

---

## 2. Autenticacao - Formato correto (POST)

```
POST /wsConsultaSQL/IwsBase HTTP/1.1
Host: associacaoescola200767.rm.cloudtotvs.com.br:10207
Authorization: Basic Z29saXZlaXJh... (user:senha base64)
Content-Type: text/xml; charset=utf-8
SOAPAction: "http://www.totvs.com/IwsBase/AutenticaAcesso"

<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tot="http://www.totvs.com/">
  <s:Body>
    <tot:AutenticaAcesso>
      <tot:user>goliveira@escoladofuturo.com.br</tot:user>
      <tot:senha>SENHA</tot:senha>
    </tot:AutenticaAcesso>
  </s:Body>
</s:Envelope>
```

Resposta: `<AutenticaAcessoResult>1</AutenticaAcessoResult>` = sucesso.

**IMPORTANTE:** soapAction deve ter PATH completo (`/IwsBase/AutenticaAcesso`), nao so o nome.
HTTP 202 com body vazio = soapAction incorreto.

---

## 3. DataServers Validos para EDU (21 mapeados)

| DataServer TOTVS | Tabela RM | View no projeto |
|------------------|-----------|------------------|
| EduFilialData | GFILIAL | (referencia) |
| EduTipoCursoData | STIPOCURSO | (referencia) |
| EduCursoData | SCURSO | scurso |
| EduHabilitacaoData | SHABILITACAO | shabilitacao |
| EduGradeData | SGRADE | sgrade |
| EduTurmaData | STURMA | sturma |
| EduTurmaDiscData | STURMADISC | sturmadisc |
| EduSubTurmaData | SSUBTURMA | - |
| EduPLetivoData | SPLETIVO | spletivo |
| EduAlunoData | SALUNO | salunos |
| EduPessoaData | PPESSOA | ppessoa |
| EduResponsavelData | SRESPFINANCEIRO | (parte de fcfo2) |
| EduResponsavelContratoData | (n/d via WS) | - |
| EduServicoData | SSERVICO | sservico |
| EduPlanoPgtoData | SPLANOPGTO | splanopgto |
| EduHabModeloPgtoData | SHABMODELOPGTO | shabmodelopgto |
| EduContratoData | SCONTRATO | scontrato |
| EduParcelaData | SPARCELA | sparcela |
| EduBolsaData | SBOLSA | sbolsa |
| EduBolsaAlunoData | SBOLSAALUNO | sbolsaaluno |
| EduMatricPLData | SMATRICPL | smatricpl |

DataServers do FINANCEIRO classico (FLAN, FCFO) precisam de outro prefixo - investigar.

---

## 4. Contexto Padrao para qualquer chamada

```
CODCOLIGADA=1;CODSISTEMA=S;CODUSUARIO=goliveira@escoladofuturo.com.br;CODFILIAL=1;CODNIVELENSINO=1
```

- `CODSISTEMA=S` para Educacional (`F` para Financeiro classico)
- `CODNIVELENSINO=1` obrigatorio em ReadView de SALUNO

---

## 5. Validacao ao vivo - Maria Valentina (RA 20101529)

Estado atual no TOTVS RM apos teste piloto:

| Entidade | DataServer | Resultado |
|----------|------------|-----------|
| SCONTRATO | EduContratoData | **2 contratos** (CODCONTRATO 7572, 7573) - IDPERLET=19, plano 241003 |
| SPLANOPGTO 241003 | EduPlanoPgtoData | **1 plano** importado (EM 1o/3o ANO 2024) |
| SHABMODELOPGTO IDPERLET=19 | EduHabModeloPgtoData | **1 ligacao** plano-habilitacao 7 |
| SPARCELA Maria | EduParcelaData | **0 parcelas** - NAO IMPORTADAS |
| SBOLSAALUNO Maria | EduBolsaAlunoData | **0 bolsas** - NAO IMPORTADAS |

**Conclusao:** o teste piloto importou SOMENTE ate SCONTRATO. SPARCELA e SBOLSAALUNO ficaram pendentes (provavelmente porque a view sparcela_v2 perdia ALIM/MAT e a importacao falhou).

---

## 6. ReadView - filtro obrigatorio

`ReadView` exige filtro nao-vazio. Usar:
```xml
<tot:Filtro>SCONTRATO.CODCOLIGADA=1</tot:Filtro>
```

Filtros aceitam SQL WHERE comum:
- `SCONTRATO.RA='20101529'`
- `SPARCELA.RA='20101529' AND SPARCELA.IDPERLET=19`

---

## 7. SaveRecord (XML) - SUBSTITUI TXT POSICIONAL

Esquema SaveRecord:
```xml
<tot:SaveRecord>
  <tot:DataServerName>EduParcelaData</tot:DataServerName>
  <tot:XML><![CDATA[
    <SPARCELA>
      <CODCOLIGADA>1</CODCOLIGADA>
      <IDPARCELA>0</IDPARCELA>
      <RA>20101529</RA>
      <CODCONTRATO>7572</CODCONTRATO>
      <IDPERLET>19</IDPERLET>
      <CODSERVICO>MENS</CODSERVICO>
      <PARCELA>1</PARCELA>
      <COTA>1</COTA>
      <VALOR>5658.00</VALOR>
      <DTVENCIMENTO>2024-01-10T00:00:00</DTVENCIMENTO>
      <DTCOMPETENCIA>2024-01-01T00:00:00</DTCOMPETENCIA>
    </SPARCELA>
  ]]></tot:XML>
  <tot:Contexto>CODCOLIGADA=1;CODSISTEMA=S;CODUSUARIO=...</tot:Contexto>
</tot:SaveRecord>
```

Beneficios sobre TXT posicional:
- Sem padding manual (LPAD/RPAD)
- Sem encoding ANSI Windows-1252 (UTF-8 puro)
- Validacao server-side imediata
- Erros retornados com detalhe (faultstring)
- Suporta transacao (multiplos records em lote)

---

## 8. Proximos passos sugeridos

1. **Importar SPARCELA + SBOLSAALUNO da Maria via SaveRecord** (sem TXT)
2. **Reescrever pipeline:** view PostgreSQL -> XML -> SaveRecord direto
3. **Cross-check pre-importacao:** ReadView para detectar duplicatas
4. **wsFin.SaveLancamento:** investigar se substitui macro Excel completamente para FLAN
5. **wsConsultaSQL:** cadastrar sentencas reutilizaveis no RM (00.001, 00.002...) para validacao em massa
