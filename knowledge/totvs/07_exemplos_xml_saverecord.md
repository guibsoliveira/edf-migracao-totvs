# 07 - Exemplos XML SaveRecord - DataServers Transacionais

**Versao:** 1.0 | **Data:** 2026-05-19 | **Status:** Producao-Ready

---

## Introducao

Este documento apresenta exemplos COMPLETOS de XML para SaveRecord nos DataServers transacionais criticos:
- EduContratoData (SCONTRATO)
- EduParcelaData (SPARCELA)
- EduBolsaAlunoData (SBOLSAALUNO)
- EduPlanoPgtoData (SPLANOPGTO)
- EduHabModeloPgtoData (SHABMODELOPGTO)
- EduMatricPLData (SMATRICPL)

Para cada: envelope XML, contexto correto, campos obrigatorios, validacoes RM, tratamento de faults, interpretacao de resposta.

---

## 1. EduContratoData (SCONTRATO) - Contrato Aluno

### Campos Obrigatorios

| Campo | Tipo | Exemplo | Validacao |
|-------|------|---------|-----------|
| CODCOLIGADA | INTEIRO | 1 | GCOLIGADA existe |
| CODCURSO | TEXTO | FUNDAMENTAL | SCURSO.CODCURSO |
| CODHABILITACAO | TEXTO | EF1 | SHABILITACAO |
| CODGRADE | TEXTO | GRADE_EF1 | SGRADE |
| TURNO | TEXTO | MATUTINO | STURNO |
| CODFILIAL | INTEIRO | 1 | GFILIAL |
| CODTIPOCURSO | INTEIRO | 1 | STIPOCURSO |
| RA | TEXTO | 20101529 | SALUNO.RA |
| CODPERLET | TEXTO | 2024 | SPLETIVO |
| CODCONTRATO | TEXTO | 7572 | PK unico |
| DTCONTRATO | DATA | 2024-01-15 | AAAA-MM-DD |
| DTASSINATURA | DATA | 2024-01-15 | >= DTCONTRATO |
| TIPOCONTRATO | TEXTO | P | P=PLANO, S=SERVICO |
| STATUS | TEXTO | N | N=Normal, S=Cancelado |

### XML Exemplo

`xml
<SCONTRATO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCURSO>FUNDAMENTAL</CODCURSO>
  <CODHABILITACAO>EF1</CODHABILITACAO>
  <CODGRADE>GRADE_EF1</CODGRADE>
  <RA>20101529</RA>
  <CODPERLET>2024</CODPERLET>
  <CODCONTRATO>7572</CODCONTRATO>
  <DTCONTRATO>2024-01-15</DTCONTRATO>
  <DTASSINATURA>2024-01-15</DTASSINATURA>
  <TIPOCONTRATO>P</TIPOCONTRATO>
  <STATUS>N</STATUS>
</SCONTRATO>
`

---

## 2. EduParcelaData (SPARCELA) - Parcela Contrato

### Campos Obrigatorios

| Campo | Tipo | Exemplo | Validacao |
|-------|------|---------|-----------|
| CODCOLIGADA | INTEIRO | 1 | = SCONTRATO |
| RA | TEXTO | 20101529 | = SCONTRATO |
| CODCONTRATO | TEXTO | 7572 | FK SCONTRATO |
| SERVICO | TEXTO | MENS | SSERVICO.NOME |
| PARCELA | INTEIRO | 1 | 1-12 por servico |
| COTA | INTEIRO | 1 | Sempre 1 |
| VALOR | NUMERICO | 1500,00 | Formato virgula |
| DTVENCIMENTO | DATA | 2024-02-10 | AAAA-MM-DD |
| TIPODESC | TEXTO | V | V=VALOR, P=PERCENTUAL |
| TIPOPARCELA | TEXTO | P | P=Plano, E=Extra |
| DTCOMPETENCIA | DATA | 2024-02-01 | Dia 1 fixo |
| CODCOLCFO | INTEIRO | 1 | GCOLIGADA |
| CODCFO | TEXTO | 1 | FCFO.CODFFO |

### XML Exemplo

`xml
<SPARCELA>
  <CODCOLIGADA>1</CODCOLIGADA>
  <RA>20101529</RA>
  <CODCONTRATO>7572</CODCONTRATO>
  <SERVICO>MENS</SERVICO>
  <PARCELA>1</PARCELA>
  <COTA>1</COTA>
  <VALOR>1500,00</VALOR>
  <DTVENCIMENTO>2024-02-10</DTVENCIMENTO>
  <DESCONTO>0,00</DESCONTO>
  <TIPODESC>V</TIPODESC>
  <TIPOPARCELA>P</TIPOPARCELA>
  <DTCOMPETENCIA>2024-02-01</DTCOMPETENCIA>
  <CODCOLCFO>1</CODCOLCFO>
  <CODCFO>1</CODCFO>
</SPARCELA>
`

### Resposta de Sucesso

`
HTTP 200 OK
IDPARCELA auto-gerado (registrar para audit)
`

### Erro Comum

`
ORA-02291: FK SCONTRATO nao existe
Solucao: Criar SCONTRATO antes
`

---

## 3. EduBolsaAlunoData (SBOLSAALUNO)

### Campos Obrigatorios

| Campo | Tipo | Exemplo | Validacao |
|-------|------|---------|-----------|
| CODCOLIGADA | INTEIRO | 1 | = SCONTRATO |
| RA | TEXTO | 20101529 | = SCONTRATO |
| CODCONTRATO | TEXTO | 7572 | FK SCONTRATO |
| NOMEBOLSA | TEXTO | BOLSA_MEIA | SBOLSA.NOME |
| SERVICO | TEXTO | MENS | SSERVICO.NOME |
| DESCONTO | NUMERICO | 50,00 | Valor ou % |
| TIPODESC | TEXTO | P | P=PERCENTUAL, V=VALOR |
| ATIVA | TEXTO | S | S=SIM, N=NAO |

### Validade: Escolher UMA

**Por Data:**
`xml
<DTINICIO>2024-02-01</DTINICIO>
<DTFIM>2024-12-31</DTFIM>
`

**Por Parcela:**
`xml
<PARCELAINICIAL>1</PARCELAINICIAL>
<PARCELAFINAL>12</PARCELAFINAL>
`

---

## 4. EduPlanoPgtoData (SPLANOPGTO)

### Campos Obrigatorios

| Campo | Tipo | Exemplo | Validacao |
|-------|------|---------|-----------|
| CODCOLIGADA | INTEIRO | 1 | GCOLIGADA |
| CODPERLET | TEXTO | 2024 | SPLETIVO |
| CODPLANOPGTO | TEXTO | 241003 | PK unico |
| DESCRICAO | TEXTO | Plano 12 ... | Texto |
| NOME | TEXTO | PLANO_EM | Unico |
| DESCONTO | NUMERICO | 0,00 | Valor |
| CODTIPOCURSO | INTEIRO | 1 | STIPOCURSO |
| CODFILIAL | INTEIRO | 1 | GFILIAL |
| MATRICULALIVRE | TEXTO | N | S ou N |

---

## 5. EduHabModeloPgtoData (SHABMODELOPGTO)

### Campos Obrigatorios

| Campo | Tipo | Exemplo | Validacao |
|-------|------|---------|-----------|
| CODCOLIGADA | INTEIRO | 1 | GCOLIGADA |
| CODPERLET | TEXTO | 2024 | SPLETIVO |
| CODPLANOPGTO | TEXTO | 241003 | SPLANOPGTO FK |
| CODTIPOCURSO | INTEIRO | 1 | STIPOCURSO |
| CODCURSO | TEXTO | FUNDAMENTAL | SCURSO |
| CODHABILITACAO | TEXTO | EF1 | SHABILITACAO |
| CODGRADE | TEXTO | GRADE_EF1 | SGRADE |
| TURNO | TEXTO | MATUTINO | STURNO |
| CODFILIAL | INTEIRO | 1 | GFILIAL |

---

## 6. EduMatricPLData (SMATRICPL)

### Campos Obrigatorios

| Campo | Tipo | Exemplo | Validacao |
|-------|------|---------|-----------|
| CODCOLIGADA | INTEIRO | 1 | GCOLIGADA |
| CODFILIAL | INTEIRO | 1 | GFILIAL |
| CODCURSO | TEXTO | FUNDAMENTAL | SCURSO |
| CODHABILITACAO | TEXTO | EF1 | SHABILITACAO |
| CODGRADE | TEXTO | GRADE_EF1 | SGRADE |
| CODPERLET | TEXTO | 2024 | SPLETIVO |
| RA | TEXTO | 20101529 | SALUNO |
| CODDISCIPLINA | TEXTO | PORT | SDISCIPLINA |
| STATUS | TEXTO | N | N=Normal, C=Cancelado |

---

## 7. Contexto SOAP Obrigatorio

`
CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1
`

**CRITICO:** NAO incluir CODSISTEMA=S (quebra nivel ensino -1)

---

## 8. SoapAction Correto

`
http://www.totvs.com/IwsDataServer/SaveRecord
`

Sempre URL completa, nao /caminho/relativo.

---

## 9. Validacoes RM (Erros Esperados)

| Erro | Causa | Solucao |
|------|-------|--------|
| ORA-01400 | Campo NOT NULL faltando | Verificar campos obrigatorios |
| ORA-02291 | FK nao existe | Criar pai primeiro (ordem importacao) |
| ORA-00001 | PK duplicada | Verificar se ja existe IDPARCELA |
| ORA-01722 | Tipo de dado invalido | VALOR deve ser numerico virgula |
| Filtro perfil | EduAlunoData retorna 0 | Usar view export_v2 |

---

## 10. Resposta Sucesso

`
HTTP 200 OK
Retorna registro completo com ID gerado (ex: IDPARCELA)
Registrar ID para possivel rollback
`

---

## 11. Script Node.js - Template

`javascript
const https = require('https');

const user = process.env.TOTVS_USER;
const pass = process.env.TOTVS_PASS;

if (!user || !pass) {
  console.error('TOTVS_USER/TOTVS_PASS nao definidas');
  process.exit(1);
}

const auth = Buffer.from(\:\).toString('base64');

// [XML SaveRecord aqui]

const options = {
  hostname: 'associacaoescola200767.rm.cloudtotvs.com.br',
  port: 10207,
  path: '/wsDataServer/IwsDataServer',
  method: 'POST',
  headers: {
    'Content-Type': 'text/xml; charset=UTF-8',
    'Authorization': Basic \,
    'SOAPAction': 'http://www.totvs.com/IwsDataServer/SaveRecord'
  }
};

https.request(options, (res) => {
  // Handle response
}).end();
`

Credenciais sempre via env vars, NUNCA inline.

---

## 12. Checklist Pre-SaveRecord

- [ ] Contexto correto (CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1)
- [ ] SoapAction URL completa
- [ ] XML UTF-8 encoding
- [ ] FKs existem (ordem dependencia)
- [ ] VALOR formato virgula (1500,00)
- [ ] Datas AAAA-MM-DD
- [ ] Campos obrigatorios preenchidos
- [ ] IDPARCELA omitido (auto-gerar)

---

**Proximos:** 08_diagrama_relacionamentos.md, 09_dicionario_campos.md
