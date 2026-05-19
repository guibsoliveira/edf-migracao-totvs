# 02 - API SOAP TBC

Data: 2026-05-19

## 1. Autenticacao

POST /{svc}/IwsBase
Authorization: Basic {base64(user:senha)}
SOAPAction: http://www.totvs.com/IwsBase/AutenticaAcesso

Payload:
- AutenticaAcesso retorna 1 = OK

## 2. Servicos (5)

- wsBase: /{svc}/IwsBase (AutenticaAcesso)
- wsDataServer: /wsDataServer/IwsDataServer (Read/Save/Delete)
- wsConsultaSQL: /wsConsultaSQL/IwsConsultaSQL (pre-cadastrada)
- wsFin: /wsFin/IwsFin (SaveLancamento, BaixaLancamento)
- wsEdu: /wsEdu/IwsEdu (ListarBoletos, Simular valores)

## 3. Contexto SOAP (OBRIGATORIO)

CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1

CRITICO: NAO incluir CODSISTEMA=S (quebra nivel ensino -1)

## 4. SoapAction (PATH COMPLETO)

Erro: HTTP 202 vazio = soapAction incorreto

Exemplos corretos:
- http://www.totvs.com/IwsBase/AutenticaAcesso
- http://www.totvs.com/IwsDataServer/ReadView
- http://www.totvs.com/IwsDataServer/SaveRecord

## 5. DataServers Edu* (21)

FUNCIONAM (sem filtro):
- EduContratoData (SCONTRATO)
- EduParcelaData (SPARCELA)
- EduResponsavelData (SRESPFINANCEIRO)
- EduMatricPLData (SMATRICPL)
- EduPlanoPgtoData (SPLANOPGTO)
- EduHabModeloPgtoData (SHABMODELOPGTO)
- EduBolsaAlunoData (SBOLSAALUNO)
- EduBolsaData (SBOLSA)

BLOQUEADOS (retornam 0):
- EduAlunoData, EduCursoData, EduHabilitacaoData, EduGradeData
- EduPLetivoData, EduServicoData, EduTurmaData, EduFilialData
- EduPessoaData, EduTurmaDiscData, EduTipoCursoData, EduSubTurmaData
- EduResponsavelContratoData (nao existe)

## 6. ReadView (leitura com filtro)

Filtro obrigatorio (nao vazio)
Exemplo: SCONTRATO.RA='20101529'
Retorna: XML com registros encontrados

## 7. SaveRecord (insercao/atualizacao)

XML puro (UTF-8)
Tag raiz = nome tabela (ex: <SPARCELA>)
Sem padding manual
Validacao server-side imediata
Retorna IDPARCELA (ou ID gerado)

## 8. DeleteRecordByKey

PrimaryKey: CODCOLIGADA,CODIGO
Exemplo: 1,12345

## 9. Erros Comuns

HTTP 202 vazio = soapAction incorreto
"Filtro invalido" = filtro vazio
"Contexto invalido" = falta CODNIVELENSINO
ORA-01400 = coluna NOT NULL faltando
ORA-02291 = FK nao existe

## 10. Maria Valentina (RA 20101529) - Estado maio 2026

- SCONTRATO: 2 contratos (7572, 7573) OK
- SPLANOPGTO: 1 plano OK
- SHABMODELOPGTO: 1 ligacao OK
- SPARCELA: 0 parcelas PENDENTE
- SBOLSAALUNO: 0 bolsas PENDENTE

