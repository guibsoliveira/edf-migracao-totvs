# 05 - Armadilhas e Erros Criticos TOTVS RM

Data: 2026-05-19

---

## 1. CODSISTEMA=S no Contexto SOAP (FATAL)

NUNCA fazer:

```
Contexto: CODCOLIGADA=1;CODSISTEMA=S;CODFILIAL=1;CODNIVELENSINO=1
```

**Resultado:** Nivel Ensino = -1, operacao falha com erro obscuro.

**Correto:**

```
Contexto: CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1
```

**Quando usar CODSISTEMA:**
- SO em SQL direto (queries export_v2)
- NAO em parametro SOAP Contexto
- Consultor confirmou: omitir em WebService

---

## 2. SoapAction Incompleto (HTTP 202 vazio)

ERRADO:
```
SOAPAction: /IwsBase/AutenticaAcesso
```

CORRETO:
```
SOAPAction: http://www.totvs.com/IwsBase/AutenticaAcesso
```

**Sintoma:** POST retorna HTTP 202 OK, mas body vazio, nenhum resultado.

**Solucao:** Sempre usar PATH COMPLETO com dominio.

---

## 3. Filtro Vazio em ReadView

ERRADO:
```xml
<tot:Filtro></tot:Filtro>
```

CORRETO:
```xml
<tot:Filtro>SCONTRATO.CODCOLIGADA=1</tot:Filtro>
```

**Erro:** "Filtro invalido" ou resultados inconsistentes.

**Nota:** Filtro é obrigatorio, nao pode ser vazio.

---

## 4. GetSchema Sem Contexto

ERRADO:
```xml
<tot:GetSchema>
  <tot:DataServerName>EduContratoData</tot:DataServerName>
</tot:GetSchema>
```

CORRETO:
```xml
<tot:GetSchema>
  <tot:DataServerName>EduContratoData</tot:DataServerName>
  <tot:Contexto>CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1</tot:Contexto>
</tot:GetSchema>
```

**Erro:** "Object reference not set" = XSD requer Contexto.

---

## 5. Filtro de Perfil - Cadastros Bloqueados

Estas operacoes retornam COUNT=0 mesmo com dados:

```
ReadView EduAlunoData -> 0 registros (dados existem!)
ReadView EduCursoData -> 0 registros
ReadView EduHabilitacaoData -> 0 registros
ReadView EduTurmaData -> 0 registros
ReadView EduGradeData -> 0 registros
ReadView EduPLetivoData -> 0 registros
ReadView EduServicoData -> 0 registros
ReadView EduFilialData -> 0 registros
ReadView EduPessoaData -> 0 registros
```

**SOLUCAO:** Use views PostgreSQL `export` ou `export_v2`

**NAO faça:** Assumir que dados nao existem so porque ReadView retorna 0.

---

## 6. ORA-01400 e ORA-02291 - NAO é bug

ORA-01400: coluna NOT NULL faltando
ORA-02291: FK nao existe (registro pai nao criado)

**NAO é bug do RM ou da view - é validacao esperada.**

**Solucao:**
1. Revisar template HTML da tabela
2. Confirmar que todos os campos obrigatorios estao preenchidos
3. Confirmar que FK existe (criar pai antes)

---

## 7. Nivel Ensino -1 Mysterioso

Sintoma: Todas as operacoes retornam erro, faultstring menciona "Nivel -1"

**Causa provavel:** Contexto com CODSISTEMA=S ou CODNIVELENSINO faltando

**Diagnostico:**
1. Verificar Contexto string
2. Confirmar CODNIVELENSINO=1
3. Remover CODSISTEMA se presente

---

## 8. DataServer NAO existe

Se tentar usar DataServer com nome errado:

```
<tot:DataServerName>FLANData</tot:DataServerName>  <- ERRADO
```

**Erro:** "Esse DataServer nao esta disponivel"

**Correto:** Use nomes mapeados (vide 02_api_soap_tbc.md, secao 5)

---

## 9. Duplicacao de PK em SaveRecord

Se tentar inserir SPARCELA com IDPARCELA ja existente:

**Erro:** ORA-00001 (unique constraint violation)

**Solucao:** Deixar IDPARCELA=0 (auto-gerado) em SaveRecord novo.

---

## 10. Encoding ANSI vs UTF-8

SaveRecord = UTF-8 puro (XML declaration)
TXT posicional = ANSI Windows-1252 obrigatorio

NUNCA misturar formatos.

---

## 11. Format Decimal - Virgula vs Ponto

Alguns campos aceitam SO BR:
```
ERRADO: <VALOR>5658.00</VALOR>
CORRETO: <VALOR>5658,00</VALOR>
```

Outros aceitam ponto. **Confirmar caso a caso** via SaveRecord (RM retorna erro).

---

## 12. FK Orphan - Ordem de Importacao

ERRADO:
```
1. SaveRecord SPARCELA (sem SCONTRATO pai)
```

CORRETO:
```
1. SaveRecord SCONTRATO
2. SaveRecord SPARCELA
```

**Erro:** ORA-02291 (referential integrity violation)

---

## 13. View export_v2 - Nao dao index autoincrement

Nao copiar IDPARCELA, IDLAN, etc. direto da view.

**Deixar em 0 no SaveRecord** para RM auto-gerar.

---

## 14. SaveRecord vs DeleteRecord Atomicidade

SaveRecord em lote:
```xml
<tot:SaveRecord>
  <tot:DataServerName>EduParcelaData</tot:DataServerName>
  <tot:XML>...</tot:XML>
  <tot:Contexto>...</tot:Contexto>
</tot:SaveRecord>
```

Cada chamada = 1 record atomico. Se falhar, esse nao entra. Precisar de rollback total? Usar DeleteRecordByKey manual.

---

## 15. Consultor TOTVS - Quando Escalar

Duvidas sobre:
- Comportamento exato de wsFin.SaveLancamento
- Se FCFO é obrigatorio ou pode pular
- Se SPARCPLANO precisa ser preenchido
- Qual encoding usar em FLAN posicional
- Se há outros DataServers bloqueados

**Escalar para consultor via email ou portal TOTVS.**

---

## 16. Performance - Limites Nao Documentados

- Default ReadView: ~1000 registros
- SaveRecord serial: ~100/min (estimado)
- SOAP timeout: 30s (confirmar)
- Conexoes simultaneas: ~5-10 (nao documentado)

Se precisa bulk import rapido, testar:
1. Paralelo SaveRecord (multiplas conexoes)
2. TXT posicional fallback (RM importador classico)
3. Batch API (se existir)

---

## 17. Respuesta Empty em SaveRecord

Se SaveRecord sucede mas retorna XML vazio:

**Causa:** Provavelmente sucesso, mas IDPARCELA nao retornou.

**Solucao:** ReadView para confirmar insercao.

---

## 18. Certificado SSL Invalido

NUNCA fazer:
```
rejectUnauthorized: false
```

**Motivo:** Certificado RM é valido. Bypass = vulneravel a MITM.

---

**Checklist Pre-Importacao:**

[ ] Contexto sem CODSISTEMA=S
[ ] SoapAction com URL completa
[ ] Filtro nao vazio em ReadView
[ ] GetSchema com Contexto
[ ] FK pai criado antes de dependente
[ ] NOT NULL preenchido
[ ] IDPARCELA/IDLAN deixado em 0 (auto-gerar)
[ ] Encoding correto (XML=UTF-8, TXT=ANSI)
[ ] ReadView pre-validacao sem duplicatas

