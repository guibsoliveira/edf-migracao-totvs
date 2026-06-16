# Prompt — Analise Completa da Migracao Gennera → TOTVS RM

> Copie o conteudo abaixo para usar como prompt em uma sessao Claude.

---

## CONTEXTO

Estamos migrando os dados da **Escola do Futuro (EDF)** do sistema legado **Gennera** para o **TOTVS RM Educacional**. A estrategia e: views PostgreSQL no schema `export` transformam dados do schema `gennera_stg` no formato que o importador TOTVS RM espera.

O Isac (consultor TOTVS) ja fez importacao de teste das turmas 1A e 1B de 2024 no RM usando os dados das nossas views (v2 financeiro), e esta funcionando bem — confirmacao que a estrutura esta correta.

## ACESSOS DISPONIVEIS

Voce tem acesso direto a:
1. **Banco PostgreSQL** (gennera_stg) — dados brutos exportados do Gennera
2. **API Gennera** — consulta de dados no sistema legado
3. **API TOTVS RM** — permite importacoes programaticas (Isac hoje faz pelo visual do RM, mas a API esta disponivel)

**Banco:**
- Host / Database / User / Password: ver `CLAUDE.local.md` (gitignored)
- OBRIGATORIO: `PGCLIENTENCODING=LATIN1` em todo comando psql
- Schemas: `gennera_stg` (fonte) e `export` (views de saida TOTVS)

## O QUE JA FOI FEITO

### Modulo Academico (43 views no schema export)
SCURSO, SHABILITACAO, SGRADE, STURMA, STURMADISC, SPLETIVO, SMATRICULA, SNOTAS, SPROVAS, SETAPAS, PPESSOA, FCFO2, FLAN, SHABILITACAOFILIAL, entre outras — todas ja aplicadas ao banco.

### Modulo Financeiro (6 views prontas)
| Ordem | View | Rows | Funcao |
|-------|------|------|--------|
| 37 | SBOLSA | var | Tipos de bolsa/desconto |
| 37b | SBOLSAPLETIVO | var | Bolsas por periodo letivo |
| 38 | SSERVICO | 161 | Catalogo de servicos financeiros (MENS, ALIM, MAT, ANUID, 1PARC) |
| 39 | SPLANOPGTO | 112 | Planos de pagamento (56 unicos x 2 filiais) |
| 40 | SPARCPLANO | 1782 | Parcelas do plano (DESCARTAVEL — consultor disse que SPARCELA substitui) |
| 41 | SHABMODELOPGTO | 348 | Ponte: plano ↔ curso/serie/grade/turno |

### Views financeiras PENDENTES
| Ordem | View | Descricao |
|-------|------|-----------|
| 42 | SCONTRATO | Contratos — liga cada aluno a seu plano de pagamento |
| 43 | SPARCELA | Parcelas reais cobradas por aluno (substitui SPARCPLANO) |
| 44 | SBOLSAALUNO | Bolsas efetivamente aplicadas por aluno |

## TAREFA

Faca uma **analise completa e consolidada** de toda a migracao, cobrindo modulo academico e financeiro. O objetivo final e: **tudo que existe no Gennera deve estar refletido no RM de forma integra e consistente**.

### 1. Inventario de dados Gennera
- Liste todas as tabelas em `gennera_stg` e seus volumes (row counts)
- Identifique quais tabelas ja estao cobertas por views no schema `export` e quais nao
- Destaque dados orfaos: tabelas/colunas do Gennera que NAO estao sendo migradas

### 2. Integridade referencial das views existentes
Para cada view no schema `export`, verifique:
- Contagem de registros
- Chaves estrangeiras: existem registros que referenciam IDs inexistentes em tabelas-pai?
- Valores nulos ou zerados em campos obrigatorios
- Duplicatas em campos que deveriam ser unicos

### 3. Cobertura academica
- Todos os alunos do Gennera aparecem nas matriculas do RM?
- Todas as turmas, disciplinas, notas e provas estao cobertas?
- Verificar anos letivos: 2021 a 2026 — algum ano esta incompleto?

### 4. Cobertura financeira
- Todos os tipos de cobranca (MENS, ALIM, MAT, 1PARC, ANUID) estao no SSERVICO?
- Os 112 planos de pagamento cobrem todos os segmentos/anos?
- SHABMODELOPGTO conecta corretamente cada plano ao curso/habilitacao/turno certo?
- Quais dados financeiros do Gennera ficam de fora sem as views SCONTRATO, SPARCELA e SBOLSAALUNO?

### 5. Gap analysis e riscos
- O que falta construir para a migracao estar 100%?
- Riscos de perda de dados ou inconsistencia
- Dados que existem no Gennera mas nao tem campo correspondente no RM
- Recomendacoes de prioridade para as views pendentes

### 6. Plano de acao
Com base na analise, proponha um plano ordenado e priorizado para completar a migracao, incluindo:
- Views SQL a criar (com dependencias entre elas)
- Validacoes a executar antes de cada importacao
- Sugestao de lotes de importacao (quais dados importar juntos)

## REGRAS DE NEGOCIO DA ESCOLA

### Estrutura academica
- 4 cursos: EI, EF1, EF2, EM
- 16 habilitacoes: EI(N2,N3,K1,K2), EF1(1o-5o), EF2(6o-9o), EM(1a-3a)
- 2 filiais (UN1, UN2), CODCOLIGADA sempre 1
- Turnos: UN1=tudo Integral; UN2: EF/EM=Integral, EI=Integral/Manha/Tarde

### Servicos financeiros
- MENS e ANUIDADE sao mutuamente exclusivos
- VALOR no SSERVICO = valor integral anual (NAO mensal)
- MENS + ALIM + MAT vao no mesmo boleto, so MENS e dedutivel no IR
- Vencimento padrao: dia 5; competencia: dia 01

### Codificacao SPLANOPGTO
- Formato: {AA}{F}{NNN} — ex: 251001 = ano 2025, filial 1, plano 001

## OUTPUT ESPERADO

Entregue um relatorio estruturado com:
1. Tabela de cobertura (Gennera → export) com status por entidade
2. Lista de problemas encontrados com severidade (critico/medio/baixo)
3. Lista de gaps (o que falta)
4. Plano de acao priorizado

Comunique em portugues do Brasil. Nao mencione IA ou Claude nas saidas.
