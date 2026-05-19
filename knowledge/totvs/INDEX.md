# Knowledge Base TOTVS RM Educacional - Index

**Projeto:** Migracao EDF Gennera -> TOTVS RM  
**Data:** 2026-05-19  
**Status:** Round 2 - Aprofundamento + Producao-Ready

---

## Round 1 (Base - Maio 2026)

### 01_arquitetura.md
Visao geral do TOTVS RM Educacional, hierarquias academicas e financeiras, tabelas mestres, diferenca entre tabelas S*/F*/G*, conceitos IDPERLET/IDHABFILIAL, contexto SOAP obrigatorio.

**Usar para:** Entender estrutura geral do RM, hierarquias de dados, ordem de dependencia.

### 02_api_soap_tbc.md
API TBC endpoints (wsBase, wsDataServer, wsConsultaSQL, wsFin, wsEdu), autenticacao, contexto SOAP, DataServers bloqueados vs funcionais, IDPERLET mapeamento, estado janeiro 2026 Maria Valentina.

**Usar para:** Debug de chamadas SOAP, diagnosticar faults, saber quais endpoints funcionam.

### 03_modelo_dados.md
Quadro resumido tabelas criticas (SCONTRATO, SPARCELA, SSERVICO, etc), campos obrigatorios, views PostgreSQL correspondentes, ordem de FK, validacoes server-side RM.

**Usar para:** Checklist pre-importacao, validacoes obrigatorias, verificar existencia de dados.

### 04_regras_negocio.md
IDPERLET mapeamento fixo, IDHABFILIACAOFILIAL, CODSISTEMA nunca no contexto, CODNIVELENSINO obrigatorio, granularidade SCONTRATO (1 por aluno+ano), numeracao SPARCELA, SBOLSAALUNO, FCFO opcional, ordem importacao obrigatoria, validacoes.

**Usar para:** Entender regras migracao EDF, evitar erros de logica, garantir dados corretos.

### 05_pitfalls.md
Armadilhas criticas: CODSISTEMA=S quebra nivel -1, SoapAction incompleto HTTP 202, filtro vazio, GetSchema sem contexto, filtro perfil bloqueia maestres, ORA-01400/02291 sao normais, nivel -1 mysterioso, DataServer nao existe, duplicacao PK, encoding ANSI vs UTF-8, format decimal virgula, FK orphan, view nao dao auto-increment, atomicidade SaveRecord, consultor escalar.

**Usar para:** Debug de erros produzidos, diagnosticar faults SOAP, evitar armadilhas conhecidas.

### 06_estado_atual.md
Estado homologacao maio 2026: SCONTRATO 7 registros (Maria 2 contratos), SPARCELA 0 (pendente), SBOLSAALUNO 0 (pendente), SLAN 0 (pendente), views PostgreSQL 10/10 presentes, IDPERLET mapeado, bloqueadores conhecidos.

**Usar para:** Saber o que foi feito, o que falta, entender estado atual do RM.

---

## Round 2 (Aprofundamento + Producao-Ready - Maio 2026)

### 07_exemplos_xml_saverecord.md
Exemplos COMPLETOS de XML SaveRecord para 6 DataServers transacionais:
- EduContratoData (SCONTRATO)
- EduParcelaData (SPARCELA)
- EduBolsaAlunoData (SBOLSAALUNO)
- EduPlanoPgtoData (SPLANOPGTO)
- EduHabModeloPgtoData (SHABMODELOPGTO)
- EduMatricPLData (SMATRICPL)

Para cada: envelope XML completo, campos obrigatorios tabela, SoapAction/Headers corretos, resposta sucesso com ID gerado, resposta erro comum e diagnostico, checklist pre-SaveRecord, exemplo script Node.js.

**Usar para:** Copy-paste XML valido, testar SaveRecord imediatamente, entender resposta esperada.

### 08_diagrama_relacionamentos.md
Diagramas Mermaid (texto) das hierarquias:
- Academica: COLIGADA -> FILIAL -> CURSO -> HABILITACAO -> GRADE -> TURMA -> SMATRICULA -> SMATRICPL
- Financeira: SSERVICO -> SPLANOPGTO -> SHABMODELOPGTO -> SCONTRATO -> SPARCELA -> SLAN -> FLAN
- Pessoas: PPESSOA -> SALUNO/SPROFESSOR/FCFO
- Avaliacao: SPLETIVO -> SETAPAS -> SPROVAS -> SNOTAS

Cardinalidades, nomes FK, tabelas bloqueadas vs funcionais, mapeamento IDPERLET, ordem importacao, notas importantes.

**Usar para:** Visualizar relacionamentos, entender cardinalidade, debugar FK orphans.

### 09_dicionario_campos.md
Dicionario campo-a-campo tabelas chave (fonte: docs/Lista de tabelas/ HTML):
- SCONTRATO (21 campos)
- SPARCELA (22 campos)
- SSERVICO (19 campos)
- SPLANOPGTO (12 campos)
- SHABMODELOPGTO (9 campos)
- SBOLSAALUNO (28 campos)
- SLAN (16 campos)
- FLAN (posicional legacy)
- FCFO (legacy 130+ campos)
- PPESSOA (parcial)

Para cada: nome, tipo SQL, tamanho, NULL?, descricao, dominio/FK. Notas sobre NUMERICO(10,4) vs (18,4), formato decimal BR (virgula), DATA AAAA-MM-DD. Checklist campo-a-campo pre-SaveRecord.

**Usar para:** Validar tipos de dados, evitar erros de formato, entender dominios campos.

### 10_scripts_chamadas_soap.md
Scripts Node.js reutilizaveis:
- auth.js: autenticaAcesso(), getAuth()
- readview.js: readView() com tratamento erro
- saverecord.js: saveRecord() template
- deleterecord.js: deleteRecordByKey() rollback
- bulksaverecord.js: bulkSaveRecordParallel() pool conexoes
- crosscheck.js: verificaImportacao()
- audit.js: logAudit() estruturado data/audit/
- mask.js: maskSensitiveData() mascarar credenciais
- main.js: orquestracao completa
- validate.js: validateXML() pre-envio

Cada script: descricao, codigo completo comentado, como rodar, validacao. Credenciais SEMPRE via env vars (TOTVS_USER, TOTVS_PASS), nunca inline. Quick reference tabela.

**Usar para:** Copiar scripts prontos, testar importacoes, mascarar PII em logs.

### 11_estrategia_filtro_perfil.md
Documento sobre contorno do filtro de perfil que bloqueia leitura de cadastros mestres:
- Lista DEFINITIVA DataServers bloqueados (SALUNO, SCURSO, HABILITACAO, SGRADE, SPLETIVO, SSERVICO, STURMA, GFILIAL, PPESSOA, etc)
- Para cada bloqueado: estrategia fallback (view export_v2 ou hardcode ou query Postgres)
- DataServers funcionais (SCONTRATO, SPARCELA, etc) - nao sofrem bloqueio
- Decisao critica: SaveRecord sofre bloqueio? (DESCONHECIDO - requer teste)
- Plan de teste para validar SaveRecord em tabelas criticas
- Texto pronto para enviar ao consultor TOTVS (pedido desbloqueio perfil)
- Contingencia: acesso SQL direto se tudo falhar (nao recomendado)
- Checklist pre-importacao massa

**Usar para:** Entender bloqueios, saber workarounds, escalacoes com TOTVS.

---

## Mapa de Leitura Recomendado

### Para Iniciante (novo no projeto)
1. Ler 01_arquitetura.md (entender estrutura)
2. Ler 03_modelo_dados.md (tabelas criticas)
3. Ler 04_regras_negocio.md (validacoes)
4. Ler 08_diagrama_relacionamentos.md (ver relacionamentos)

### Para Implementador (vai fazer SaveRecord)
1. Ler 07_exemplos_xml_saverecord.md (copy-paste XML)
2. Ler 09_dicionario_campos.md (validar tipos)
3. Ler 10_scripts_chamadas_soap.md (rodar scripts)
4. Ler 05_pitfalls.md (evitar erros)

### Para Debugger (algo nao funciona)
1. Ler 05_pitfalls.md (diagnosticar)
2. Ler 02_api_soap_tbc.md (entender endpoints)
3. Ler 11_estrategia_filtro_perfil.md (se bloqueio)
4. Contatar consultor TOTVS (com texto pronto 11)

### Para Auditor (validar pos-importacao)
1. Ler 04_regras_negocio.md (o que deveria ser verdade)
2. Ler 08_diagrama_relacionamentos.md (FK relacionamentos)
3. Ler 10_scripts_chamadas_soap.md (script crosscheck)
4. Ler 06_estado_atual.md (estado linha base)

---

## Tabelas de Referencia Rapida

### DataServers Bloqueados
EduAlunoData, EduCursoData, EduHabilitacaoData, EduGradeData, EduPLetivoData, EduServicoData, EduTurmaData, EduFilialData, EduPessoaData, EduTurmaDiscData, EduTipoCursoData, EduSubTurmaData

### DataServers Funcionais
EduContratoData, EduParcelaData, EduResponsavelData, EduMatricPLData, EduPlanoPgtoData, EduHabModeloPgtoData, EduBolsaAlunoData, EduBolsaData

### IDPERLET Mapeamento
| Ano | IDPERLET | CODPERLET | Status |
|-----|----------|-----------|--------|
| 2023 | 15 | 2023 | OK |
| 2024 EF | 18 | 2024 | OK |
| 2024 EM | 19 | 2024 | OK |
| 2026 | 1,2 | 2026 | OK (teste) |

### Ordem Importacao
1. SPLETIVO
2. SSERVICO
3. SPLANOPGTO
4. SHABMODELOPGTO
5. SCONTRATO
6. SPARCELA
7. SBOLSAALUNO
8. SLAN (auto ou wsFin)
9. FLAN (auto)

### Contexto SOAP (CRITICO)
`
CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1
(SEM CODSISTEMA=S - quebra nivel -1)
`

---

## Arquivos Relacionados (Fora Knowledge Base)

- CLAUDE.local.md: credenciais PostgreSQL, TOTVS, Gennera (gitignored)
- SECURITY.md: guardrails seguranca, regras NUNCA/SEMPRE
- docs/Lista de tabelas/ (48 HTML): schema oficial TOTVS
- docs/API_TOTVS_DESCOBERTA.md: endpoints discovery
- data/estudo/04_totvs_api_e_docs.md: estudo anterior
- data/audit/: logs de importacao (gitignored)
- data/exportacoes/: dados exportados PII (gitignored)

---

## Cronologia de Producao

- **Maio 2026:** Round 1 (base) + Round 2 (aprofundamento)
- **Semana 1:** Testes unitarios SaveRecord (maria 1 parcela)
- **Semana 2:** Testes integracao (maria 36 parcelas)
- **Semana 3:** Escalada (5 alunos)
- **Semana 4:** Producao 2024 completo (~3k matriculas)
- **Pos-migracao:** Refresh 2026 via API Gennera live

---

## Validacao Checklist

- [ ] Todos 11 arquivos presentes (01-11)
- [ ] XMLs sem hardcode credenciais
- [ ] Scripts usam env vars TOTVS_USER/TOTVS_PASS
- [ ] Sem CPF/RA/nome real aluno em exemplos (anonimizados)
- [ ] Diagrama Mermaid valido (texto renderiza)
- [ ] Dicionario campos 100% preenchido (tabelas chave)
- [ ] IDPERLET mapeado completo (2023, 2024, 2026)
- [ ] Bloqueadores identificados e workarounds documentados
- [ ] Texto escalacao TOTVS pronto (11_estrategia_filtro_perfil.md)

---

## Sugestoes de Melhorias (Round 3+)

- [ ] Adicionar screenshots de resposta SOAP (FORBIDDEN para debugging)
- [ ] Exemplo video migracao (Maria 1 parcela passo-a-passo)
- [ ] Teste de performance: limite SaveRecord paralelos
- [ ] Contingencia: se RM derrubar conexao, retry logic
- [ ] Desempenho: benchmarking bulkSaveRecord vs serial
- [ ] Glossario: siglas (RA, IDPERLET, IDHABFILIAL, etc)

---

## Contatos / Escalacao

**Problema SOAP:** Consultor TOTVS (email em SECURITY.md)
**Problema PostgreSQL:** Isac (view designer, consultor)
**Problema Gennera API:** Suporte Gennera (JWT renewal)
**Problema Seguranca/PII:** Responsavel LGPD EDF (DPO)

---

**Versao:** 2.0 | **Atualizado:** 2026-05-19 | **Status:** Round 2 completo

