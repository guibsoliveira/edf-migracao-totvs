# Escola do Futuro - Migracao Gennera para TOTVS RM

## Projeto

Migracao de dados do sistema legado **Gennera** para **TOTVS RM Educacional** da **Escola do Futuro (EDF)**.
O trabalho consiste em criar views PostgreSQL no schema `export` que transformam dados do schema `gennera_stg` no formato esperado pelo importador TOTVS RM.

**Responsavel:** Guilherme Oliveira (GitHub: `guibsoliveira`)
**Cliente:** Escola do Futuro (EDF) - Educacao Basica (EI, EF1, EF2, EM)
**Consultor TOTVS:** orienta sobre templates e regras do RM

---

## Banco de Dados

- **Host:** (configurar via variavel de ambiente `DB_HOST`)
- **Database:** Edf_bd_legado
- **User:** (configurar via variavel de ambiente `DB_USER`)
- **Password:** (configurar via variavel de ambiente `DB_PASS`)
- **Encoding:** LATIN1 (OBRIGATORIO usar `PGCLIENTENCODING=LATIN1` em todo comando psql)

### Schemas
- `gennera_stg` - dados brutos importados do Gennera
- `export` - views de saida no formato TOTVS RM

### Comando padrao psql
```bash
PGCLIENTENCODING=LATIN1 PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d Edf_bd_legado
```

---

## Estrutura do Projeto

```
edf-migracao-totvs/
  views/
    financeiro/     # Views do modulo financeiro
    academico/      # Views do modulo academico (etapas, provas)
    debug/          # Queries auxiliares de depuracao
  docs/             # Relatorios e documentacao
  scripts/          # Scripts utilitarios (Python, SQL)
  data/             # CSVs de qualidade cadastral
  reference/        # Schema fonte, dump de views, nomes
```

---

## Views Criadas (schema export)

### Modulo Financeiro (este projeto)

| Ordem | View | Arquivo | Status | Rows |
|-------|------|---------|--------|------|
| 37 | SBOLSA | views/financeiro/sbolsa_view_nova.sql | APLICADA | ~variavel |
| 37b | SBOLSAPLETIVO | views/financeiro/sbolsapletivo_view_nova.sql | APLICADA | ~variavel |
| 38 | SSERVICO | views/financeiro/sservico_view.sql | APLICADA | 161 |
| 39 | SPLANOPGTO | views/financeiro/splanopgto_view_nova.sql | APLICADA | 112 |
| 40 | SPARCPLANO | views/financeiro/sparcplano_view_nova.sql | APLICADA (pode ser descartada - consultor disse que SPARCELA substitui) | 1782 |
| 41 | SHABMODELOPGTO | views/financeiro/shabmodelopgto_view.sql | APLICADA | 348 |
| 42 | SCONTRATO | - | PENDENTE | - |
| 43 | SPARCELA | - | PENDENTE | - |
| 44 | SBOLSAALUNO | - | PENDENTE | - |

### Modulo Academico (ja existiam antes deste projeto)

43 views no total no schema `export`, incluindo: scurso, shabilitacao, sgrade, sturma, sturmadisc, spletivo, smatricula, snotas, sprovas, setapas, ppessoa, fcfo2, flan, etc.

---

## Regras de Negocio Importantes

### Estrutura academica EDF
- **4 cursos:** EI (Educacao Infantil), EF1 (Fundamental I), EF2 (Fundamental II), EM (Ensino Medio)
- **16 habilitacoes:** EI(1-4: N2,N3,K1,K2), EF1(1-5: 1o-5o Ano), EF2(6-9: 6o-9o Ano), EM(1-3: 1a-3a Serie)
- **2 filiais:** Filial 1 (UN1), Filial 2 (UN2)
- **Coligada:** sempre 1

### Turnos
- **UN1 (Filial 1):** TUDO Integral
- **UN2 (Filial 2):** EF1/EF2/EM = Integral; EI diferencia (Integral, Manha, Tarde)
- Turma EI usa sufixos: IA=Integral, MB=Matutino(Manha), TC=Vespertino(Tarde)

### Servicos e cobranca
- **MENS** = mensalidade (12 parcelas, unica dedutivel no IR)
- **ALIM** = alimentacao (12 parcelas)
- **MAT/MDIDAT/MDIAT** = materiais didaticos (12 parcelas)
- **1oPARC** = rematricula (1 parcela, valor = 1 mensalidade)
- **ANUIDADE/ANUID** = mensalidade anual em parcela unica (valor = MENS x 12)
- MENS e ANUIDADE sao mutuamente exclusivos (pai escolhe um ou outro)
- MENS + ALIM + MAT vao no mesmo boleto, so MENS e dedutivel

### SSERVICO
- VALOR = valor integral/anual do servico (nao mensal)
- Caixa: CODCOLCXA=1, CODCXA=237 (Bradesco)
- Natureza financeira: CODCOLNATFINANCEIRA=1, NATFINANCEIRA=111.111
- Aceita cartao: PGCARTAODEBITO=S, PGCARTAOCREDITO=S

### SPLANOPGTO
- Codigo: {AA}{F}{NNN} = ultimos 2 digitos do ano + filial + sequencial 3 digitos
- Exemplo: 251001 = 2025, filial 1, plano 001
- 112 planos: 56 unicos x 2 filiais (2021-2026)

### SPARCPLANO (pode ser descartada)
- Consultor TOTVS informou que SPARCELA substitui esta view
- Se mantida: usa CTE valores_unicos para itens de pagamento unico (ANUID/1PARC)
  que reconstitui valor total via SUM por aluno (pais parcelam em 3x, 10x etc)

### SHABMODELOPGTO
- Tabela ponte: liga plano de pagamento a curso/serie/grade/turno
- Segmento do plano e parseado via regex para extrair CODCURSO e range de habilitacoes
- CODGRADE = ano letivo (SGRADE so tem ate 2025, entao 2026 fica de fora)

---

## Problemas Conhecidos e Solucoes

### Encoding Latin1 e word boundaries
- PostgreSQL `\m`/`\M` (word boundary) FALHA com caractere `o` (ordinal) no locale PT-BR
- O `o` e tratado como caractere de palavra, entao `\m` nao detecta fronteira entre `1o` e `MENS`
- **Solucao:** usar `1[^[:space:]]{0,3}\s*(PARC|MENS)` em vez de `1\S{0,3}\s*\m(PARC|MENS)\M`

### Nomenclatura heterogenea entre anos
- 2021: nomes completos ("ENSINO FUNDAMENTAL 1 (1o ao 5o)")
- 2022: abreviacoes ("F1", "3oao5o", "INT")
- 2023: misto ("1o ANO", "MEIO PERIODO", "F1")
- 2024: semi-padronizado ("EF1", "EF1 1oANO", "EI INTEGRAL")
- 2025-2026: padronizado ("FUND 1 - 1o ANO", "EI INTEGRAL K1, K2")
- Views usam regex multi-pattern para cobrir todas as variantes

### mode() contaminado por parcelamentos
- Pais parcelam anuidade em 3x ou rematricula em 10x
- mode() dos valores individuais pega a parcela, nao o total
- **Solucao SPARCPLANO:** CTE `valores_unicos` faz SUM por aluno para ANUID/1PARC, depois mode() do total
- **SSERVICO nao tem esse problema:** ja faz SUM por aluno (valor integral anual)

---

## Tabela de Referencia - Fonte Gennera

### servicos_historico (tabela principal de cobrancas)
Colunas relevantes: calendario_academico, item, id_pessoa, fatura_ano, fatura_mes, valor_bruto
- Headers na linha 3, dados a partir da linha 4
- valor_bruto formato BRL: "$1.234,56" (precisa REPLACE para numeric)
- item contem nome do servico com segmento (ex: "2025 MENS EI INTEGRAL K1, K2")

---

## Google Sheets (planilha de controle)
- **Templates TOTVS:** https://docs.google.com/spreadsheets/d/1ZvV3NKtB29EJsa6eQUDVlH0Xy05C11rEfFCXKsFlmrY/
- **Spreadsheet principal EDF:** ID `1VVLzeF4GUyrkSi9KBEYVMdmkRKcZCfRlvLloNO-injA`

---

## Proximas Views Pendentes

1. **SCONTRATO** (ordem 42) - Contratos de alunos (liga aluno a plano de pagamento)
2. **SPARCELA** (ordem 43) - Parcelas reais cobradas (substitui SPARCPLANO)
3. **SBOLSAALUNO** (ordem 44) - Bolsas aplicadas por aluno

---

## Convencoes de Desenvolvimento

- Comunicacao em portugues do Brasil
- Sem referencias a IA/Claude nas saidas visiveis ao cliente
- Sempre usar `PGCLIENTENCODING=LATIN1` em comandos psql
- Testar integridade referencial (0 orphans) apos cada view
- Health check padrao: total rows, FK orphans, zero-value rows
- Views no schema `export`, dados fonte no schema `gennera_stg`
