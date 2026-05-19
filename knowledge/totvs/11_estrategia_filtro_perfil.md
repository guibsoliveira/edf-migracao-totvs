# 11 - Estrategia de Contorno ao Filtro de Perfil

> ⚠️ **DEPRECATED 2026-05-19 (tarde).** A premissa deste documento (que existe "filtro de perfil" bloqueando leitura) está INCORRETA. Veja `12_descoberta_regex_bug_e_bloqueios_reais.md` para a explicação correta. Os DataServers listados aqui como "bloqueados na leitura" na verdade RETORNAM dados normalmente — o bug era do cliente Node (regex case-sensitive entre `<SCURSO>` vs `<SCurso>`).
>
> Este arquivo é mantido por contexto histórico — **não use as recomendações** abaixo.

---

**Versao:** 1.0 | **Data:** 2026-05-19 | **Status:** OBSOLETO

---

## Problema (premissa INCORRETA)

DataServers Educacionais **retornam COUNT=0** mesmo com dados existentes:

`
ReadView EduAlunoData -> 0 registros (mas SALUNO tem dados)
ReadView EduCursoData -> 0 registros (mas SCURSO tem dados)
ReadView EduServicoData -> 0 registros (mas SSERVICO tem dados)
`

**Causa:** Filtro de perfil do usuario goliveira@escoladofuturo.com.br restringe acesso de leitura a mestres academicos.

---

## DataServers Bloqueados (Testados)

| DataServer | Tabela | Bloqueio | Fallback | Status |
|-----------|--------|----------|----------|--------|
| EduAlunoData | SALUNO | READ=0 | view export_v2.salunos | CONFIRMADO |
| EduCursoData | SCURSO | READ=0 | view export_v2.scurso | CONFIRMADO |
| EduHabilitacaoData | SHABILITACAO | READ=0 | view export_v2.shabilitacao | CONFIRMADO |
| EduGradeData | SGRADE | READ=0 | view export_v2.sgrade | CONFIRMADO |
| EduPLetivoData | SPLETIVO | READ=0 | view export_v2.spletivo | CONFIRMADO |
| EduServicoData | SSERVICO | READ=0 | view export_v2.sservico | CONFIRMADO |
| EduTurmaData | STURMA | READ=0 | view export_v2.sturma | CONFIRMADO |
| EduFilialData | GFILIAL | READ=0 | view export_v2.gfilial | CONFIRMADO |
| EduPessoaData | PPESSOA | READ=0 | view export_v2.ppessoa | CONFIRMADO |
| EduTurmaDiscData | STURMADISC | READ=0 | view export_v2.sturmadisc | CONFIRMADO |
| EduTipoCursoData | STIPOCURSO | READ=0 | view export_v2.stipocurso | CONFIRMADO |
| EduSubTurmaData | SSUBURMA | READ=0 | view export_v2.ssuburma | CONFIRMADO |
| EduResponsavelContratoData | - | READ=0 | NAO EXISTE | CONFIRMADO |

---

## DataServers Funcionais (Sem Bloqueio)

Estes funcionam NORMALMENTE com ReadView:

`
EduContratoData (SCONTRATO)       ✓ Funciona (teste maria: 2 contratos)
EduParcelaData (SPARCELA)         ✓ Funciona (0 registros - esperado, nao importamos)
EduResponsavelData (SRESPFINANCEIRO) ✓ Funciona
EduMatricPLData (SMATRICPL)       ✓ Funciona
EduPlanoPgtoData (SPLANOPGTO)     ✓ Funciona (teste: 1 plano 241003)
EduHabModeloPgtoData (SHABMODELOPGTO) ✓ Funciona (teste: 1 ligacao)
EduBolsaAlunoData (SBOLSAALUNO)   ✓ Funciona (0 registros - esperado)
EduBolsaData (SBOLSA)             ✓ Funciona
`

---

## Estrategia por Tabela

### 1. SALUNO (Alunos)

**Problema:** EduAlunoData ReadView retorna 0

**Solucao Principal:**
`sql
-- PostgreSQL export_v2.salunos
SELECT RA, CODPESSOA, CODCURSO, CODHABILITACAO, CODGRADE, DTMATRICULACAO
FROM export_v2.salunos
WHERE RA LIKE '%2010%'
LIMIT 100;
`

**Validacao:** Confirmar que RA existe antes de usar em SCONTRATO.

**Alternativa:** Se precisar dados em tempo real (nao cutoff dez 2025), usar API Gennera:
`
GET /institutions/{id}/persons (retorna alunos com ID externo)
Mapear ID Gennera -> RA TOTVS
`

### 2. SCURSO (Cursos)

**Problema:** EduCursoData ReadView retorna 0

**Solucao Principal:** Usar lista fixa conhecida
`
Cursos na EDF (imutavel):
- FUNDAMENTAL (6o-8o ano)
- MEDIO (1o-3o ano EM)
- (HA MAIS? Verificar export_v2.scurso)
`

**Query fallback:**
`sql
SELECT CODCURSO, NOME
FROM export_v2.scurso
WHERE CODCOLIGADA = 1;
`

**Hardcode permitido:** Cursos sao mestres staticos, pode colocar em config:
`javascript
const CURSOS = ['FUNDAMENTAL', 'MEDIO'];
`

### 3. SPLETIVO (Periodos Letivos)

**Problema:** EduPLetivoData ReadView retorna 0

**Solucao Principal:**
`sql
SELECT CODPERLET, IDPERLET, DESCRICAO
FROM export_v2.spletivo
WHERE CODCOLIGADA = 1
ORDER BY IDPERLET DESC;
`

**Mapeamento CRITICO:**
`
CODPERLET=2024 -> IDPERLET=18 ou 19 (depende EF vs EM)
CODPERLET=2023 -> IDPERLET=15
CODPERLET=2026 -> IDPERLET=1 ou 2 (teste)
`

**Nunca adivinhar IDPERLET** - sempre fazer lookup em SPLETIVO.

### 4. SSERVICO (Servicos)

**Problema:** EduServicoData ReadView retorna 0

**Solucao Principal:** Usar lista conhecida
`
MENS (Mensalidade)
ALIM (Alimentacao)
MAT (Material Didatico)
`

**Query fallback:**
`sql
SELECT NOME, VALOR, CODTIPOCURSO
FROM export_v2.sservico
WHERE CODCOLIGADA = 1
ORDER BY NOME;
`

### 5. SHABILITACAO (Habilitacoes/Series)

**Problema:** EduHabilitacaoData ReadView retorna 0

**Solucao Principal:**
`sql
SELECT CODHABILITACAO, NOME, CODCURSO
FROM export_v2.shabilitacao
WHERE CODCOLIGADA = 1
AND CODCURSO IN ('FUNDAMENTAL', 'MEDIO');
`

**Estrutura esperada:**
`
CODCURSO=FUNDAMENTAL:
  - EF1 (6o ano)
  - EF2 (7o ano)
  - EF3 (8o ano)

CODCURSO=MEDIO:
  - EM1 (1o ano)
  - EM2 (2o ano)
  - EM3 (3o ano)
`

### 6. SGRADE (Grades Curriculares)

**Problema:** EduGradeData ReadView retorna 0

**Solucao Principal:**
`sql
SELECT CODGRADE, NOME, CODCURSO, CODHABILITACAO
FROM export_v2.sgrade
WHERE CODCOLIGADA = 1;
`

**Validacao:** Cada HABILITACAO precisa ter SGRADE linkada.

---

## Decisoes Criticas: SaveRecord com Filtro?

### Pergunta: SaveRecord sofre o mesmo filtro de perfil?

**Resposta:** DESCONHECIDO (nao testado em homolog)

**Recomendacao:**
`
1. Para tabelas bloqueadas (SALUNO, SCURSO, etc):
   NAO tentar SaveRecord
   (RM pode rejeitar, nao ha certeza)

2. Para tabelas funcionais (SCONTRATO, SPARCELA):
   SaveRecord FUNCIONA normalmente (testado)

3. Tabelas auxiliares (SGRADE, SHABILITACAO):
   TESTAR SaveRecord antes de usar em producao
`

### Plan de Teste

`
Dia 1: ReadView em EduGradeData (esperado 0, confirmado)
Dia 1: SaveRecord EduGradeData nova grade teste (resultado desconhecido)
  Se OK: liberar para producao
  Se ERRO: usar fallback (importar via SQL, nao recomendado)
  Se VAZIO: talvez OK mas sem confirmacao, investigar

Dia 2: ReadView em EduServicoData (esperado 0, confirmado)
Dia 2: SaveRecord EduServicoData novo servico teste (resultado desconhecido)
  Se OK: liberar para producao
  Se ERRO: usar fallback (query Postgres)
`

---

## Lista DEFINITIVA de Workarounds

| Tabela | Bloqueio | Leitura | Escrita | Fallback |
|--------|----------|---------|---------|----------|
| SALUNO | READ=0 | view export_v2 | ??? | Use RA conhecido |
| SCURSO | READ=0 | view export_v2 | ??? | Hardcode FUNDAMENTAL, MEDIO |
| SHABILITACAO | READ=0 | view export_v2 | ??? | Query Postgres |
| SGRADE | READ=0 | view export_v2 | TESTAR | Query Postgres |
| SPLETIVO | READ=0 | view export_v2 | NAO USAR | Query Postgres para IDPERLET |
| SSERVICO | READ=0 | view export_v2 | TESTAR | Hardcode MENS, ALIM, MAT |
| STURMA | READ=0 | view export_v2 | ??? | Query Postgres |
| GFILIAL | READ=0 | view export_v2 | ??? | Hardcode 1 |
| PPESSOA | READ=0 | view export_v2 | ??? | Query Postgres |

---

## Solucao em Producao: Pedido ao Consultor TOTVS

**Texto a enviar ao consultor TOTVS (via email/ticket):**

`
Assunto: Desbloqueio de Perfil - DataServers Educacionais

Prezados,

Durante a migracao Gennera -> TOTVS RM, identificamos que o usuario tecnico 
(goliveira@escoladofuturo.com.br) tem filtro de perfil que bloqueia leitura 
via ReadView dos seguintes DataServers:

- EduAlunoData
- EduCursoData
- EduHabilitacaoData
- EduGradeData
- EduPLetivoData
- EduServicoData
- EduTurmaData
- EduFilialData
- EduPessoaData

Pergunta: qual configuracao de perfil ou grupo de acesso permite acesso 
READ nestes DataServers?

Necessario para:
1. Validacao pre-importacao (confirmar dados existem)
2. Cross-check pos-importacao (auditar integridade)

Alternativa aceita: se nao for possivel liberar, confirmar que SaveRecord 
tambem sofre bloqueio, para saber se precisamos importar via SQL direto.

Atenciosamente,
Equipe Migracao EDF
`

---

## Contingencia: Acesso SQL Direto (Nao Recomendado)

Se TOTVS disser que SaveRecord TAMBEM sofre bloqueio e nao conseguir liberar:

`sql
-- APENAS EM ULTIMO RECURSO
-- Conectar como usuario com acesso SUPERUSER (nao recomendado em producao)

INSERT INTO SSERVICO (CODCOLIGADA, NOME, VALOR, CODTIPOCURSO, ...)
SELECT 1, 'MENS', 1500.00, 1, ... FROM DUAL;

-- Problema: perde validacoes RM (constraints, triggers, sequencias)
-- Solucao: validar manualmente apos insert
`

**NAO fazer isto em PRODUCAO sem supervisao TOTVS.**

---

## Checklist - Antes de Importacao em Massa

- [ ] Confirmado que ReadView EduContratoData funciona
- [ ] Confirmado que ReadView EduParcelaData funciona (mesmo que 0 registros)
- [ ] Confirmado que SaveRecord EduContratoData funciona
- [ ] Confirmado que SaveRecord EduParcelaData funciona
- [ ] Mapeado IDPERLET para cada CODPERLET (2023=15, 2024=18/19, 2026=1/2)
- [ ] Lista de cursos confirmada em export_v2.scurso
- [ ] Lista de servicos confirmada em export_v2.sservico
- [ ] Testar SaveRecord em EduGradeData (se usar ese tablela)
- [ ] Testar SaveRecord em EduServicoData (se precisar criar servicos novos)
- [ ] Se bloqueio persiste: esclarecer com TOTVS sobre perfil

---

## Resumo Executivo

1. **Leitura de mestres bloqueada** por filtro perfil
2. **Fallback:** Views PostgreSQL export_v2 (dados sempre disponivel)
3. **Escrita (SaveRecord):** Funciona em EduContratoData e EduParcelaData, testar outras
4. **IDPERLET:** CRITICO - sempre fazer lookup, nao adivinhar
5. **Contingencia:** Contato TOTVS se bloqueio persistir pos-producao

---

## Arquivos de Referencia

- 01_arquitetura.md - Hierarquias
- 02_api_soap_tbc.md - Endpoints
- 03_modelo_dados.md - Schemas
- 09_dicionario_campos.md - Detalhes campos
- CLAUDE.local.md - Credenciais PostgreSQL

---

**FIM do conhecimento base TOTVS RM - Round 2**

