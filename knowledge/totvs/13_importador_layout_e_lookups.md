# 13 - Importador TOTVS Educacional: layout e regra dos lookups

**Versão:** 1.0 | **Data:** 2026-05-20 | **Status:** validado em homolog (SMATRICPL Diego importou OK)

> Regra que faltou nas tentativas iniciais e custou 2 falhas no importador. Documentado pra valer em TODOS os arquivos de importação manual daqui pra frente.

---

## 1. O que é o Importador TOTVS Educacional

Ferramenta interna do RM (`Executar → Importador → TOTVS Educacional`) que aceita arquivos `.csv` (ou `.txt`) ANSI (LATIN-1) com separador `;`. Foi a saída quando `EduMatricPLData.SaveRecord` via WS está bloqueado pelo perfil de segurança (ver [12_descoberta_regex_bug_e_bloqueios_reais.md](12_descoberta_regex_bug_e_bloqueios_reais.md)).

**Características:**

- Insere direto no banco — **não aplica regras de negócio** do RM (sem hooks, sem validações de domínio)
- Aceita arquivo com nome igual ao da tabela (`SMATRICPL.csv`, `SMATRICULA.csv`)
- Linha 1 = header com sintaxe **composta** (ver §2)
- Linhas seguintes = dados, **na mesma ordem das colunas do header**
- Erros gerados em `\\10.114.71.251\CPNULO_200767_1\Processos\Not_Imported`
- Mensagem `Layout esperado:` do log mostra o header exato exigido — **sempre capturar essa string e usar 100% literal**

---

## 2. Sintaxe do header — a regra dos lookups

O importador usa nomes de coluna **compostos** que descrevem como ele deve resolver o valor. Há 3 padrões:

### 2.1 Coluna simples

```
CODFILIAL
RA
CODTURMA
DTMATRICULA
```

→ Valor entra **literal** no banco.

### 2.2 Coluna `$LookupOnly`

```
CODCURSO$LookupOnly
CODGRADE$LookupOnly
CODTIPOCURSO$LookupOnly
```

→ Valor entra literal, mas o importador faz validação cruzada (verifica que o valor passado existe no cadastro da tabela mãe).

### 2.3 Coluna com lookup composto

```
IDHABILITACAOFILIAL$IDHABILITACAOFILIAL.SHABILITACAOFILIAL$S$IDHABILITACAOFILIAL$T.CODHABILITACAO.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL...
```

Decifrando:

| Pedaço | Significado |
|---|---|
| `IDHABILITACAOFILIAL` | nome do campo na tabela destino |
| `$IDHABILITACAOFILIAL` | (redundante, indica que o ID literal é IDHABILITACAOFILIAL) |
| `.SHABILITACAOFILIAL$S` | tabela onde buscar (`$S` = source) |
| `$IDHABILITACAOFILIAL$T` | campo de retorno (`$T` = target field a ser inserido) |
| `.CODHABILITACAO` | **campo onde o valor do CSV vai ser buscado** |
| `.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL...` | colunas extras do **mesmo registro do CSV** usadas como condições adicionais |

Em SQL:

```sql
SELECT IDHABILITACAOFILIAL FROM SHABILITACAOFILIAL
WHERE CODHABILITACAO = <valor do CSV nesta coluna>
  AND CODCOLIGADA    = <valor da col CODCOLIGADA do mesmo CSV>
  AND CODFILIAL      = <valor da col CODFILIAL do mesmo CSV>
  AND ...
```

**Regra de ouro:** o valor que vai no CSV para colunas com lookup composto é o **campo logo após `$T.`** — não o ID literal.

### 2.4 Tabela de campos críticos do RM Educacional

| Nome de coluna no header (resumido) | Valor no CSV |
|---|---|
| `IDHABILITACAOFILIAL$...$T.CODHABILITACAO.CODCOLIGADA.CODFILIAL.CODTIPOCURSO.CODTURNO.CODCURSO.CODGRADE` | **CODHABILITACAO** (ex: `8`) |
| `IDPERLET$...$T.CODPERLET.CODCOLIGADA.CODFILIAL.CODTIPOCURSO` | **CODPERLET** (ex: `2022`) |
| `IDTURMADISC$...$T.CODDISC.CODCOLIGADA.CODFILIAL.CODTIPOCURSO.IDPERLET.CODTURMA.CODCURSO.CODHABILITACAO.CODGRADE.CODTURNO` | **CODDISC** (ex: `7`, `19`) |
| `CODTURNO$...$T.NOME.CODCOLIGADA.CODFILIAL.CODTIPOCURSO$LookupOnly` | **NOME do turno** (ex: `Integral`, `Manhã`, `Tarde`) |
| `CODSTATUS$...$T.DESCRICAO.CODCOLIGADA.CODTIPOCURSO` | **DESCRICAO** do status (ex: `Ativo`, `Aprovado`, `Reprovado`, `Trancado`) |
| `CODSTATUSRES$...$T.DESCRICAO.CODCOLIGADA.CODTIPOCURSO` | **DESCRICAO** do status reservado (idem acima) |
| `CODTIPOMAT$...$T.DESCRICAO.CODCOLIGADA.CODTIPOCURSO` | **DESCRICAO** do tipo de matrícula (ex: `Normal`, `Avulsa`, `Reservada`) |

---

## 3. Por que esse design

Razão histórica do RM:

- IDs internos (`IDPERLET`, `IDHABILITACAOFILIAL`, `IDTURMADISC`) são sequenciais auto-gerados, **diferentes entre instâncias** (homolog 2022 = IDPERLET 12; produção 2022 = pode ser outro número).
- Códigos "humanos" (`CODPERLET=2022`, `CODHABILITACAO=8`, `CODDISC=7`) são estáveis e definidos no negócio.
- Layout do importador permite que **o mesmo arquivo CSV migre entre instâncias** sem precisar trocar IDs. O importador resolve para o ID local de cada instância via lookup.

→ **Implicação:** scripts geradores de CSV nunca devem usar IDs sequenciais (IDPERLET, IDHABFIL, IDTURMADISC); devem usar sempre os códigos humanos.

---

## 4. Formato do arquivo

| Item | Valor |
|---|---|
| Encoding | **ANSI / LATIN-1 / Windows-1252** (NÃO UTF-8) |
| Separador | `;` (ponto-e-vírgula) |
| Quebra de linha | CRLF (`\r\n`) padrão Windows |
| Data | `DD/MM/AAAA` (BR), com ou sem hora |
| Booleanos | `S` ou `N` (algumas tabelas usam `0`/`1`) |
| Numéricos decimais | vírgula como separador decimal (`4820,33`) na maioria dos contextos; alguns aceitam ponto |
| Nome do arquivo | igual ao nome da tabela (`SMATRICPL.csv`) |

---

## 5. Erros comuns e diagnóstico

| Sintoma no log | Causa | Conserto |
|---|---|---|
| `X campos requeridos e Y campos encontrados` (com `Layout esperado:` no log) | header com nome simples ou número de colunas errado | copiar o `Layout esperado:` **literal** como header |
| `ORA-01400: não é possível inserir NULL em (...)` num campo de ID | passou o ID literal em coluna que faz lookup | passar o **campo após `$T.`** (geralmente o "código humano") |
| `Coluna em SQL ou Bind variable not found` | header com nome inválido (typo) | conferir contra o `Layout esperado:` |
| Importação silenciosamente importa 0 mas não dá erro | provavelmente lookup retorna NULL e o RM ignora a linha | conferir que o valor passado existe no cadastro mãe |

---

## 6. Como capturar o layout esperado (workflow padrão)

1. Gerar um CSV **tentativo** com header simples (`CODCOLIGADA;IDPERLET;RA;...`).
2. Tentar importar — vai falhar com `X campos requeridos e Y encontrados`.
3. O importador imprime `Layout esperado: <header_real>` no log.
4. Copiar essa string como header EXATO (trocar `,` por `;`).
5. Mapear cada coluna: simples vs `$LookupOnly` vs lookup composto (§2).
6. Pra cada coluna composta, identificar o "campo após `$T.`" — esse é o valor que vai no CSV.
7. Regerar o CSV com os valores certos.

---

## 7. Workflow recomendado para qualquer importação manual

1. **Cadastros mestres existentes:** sempre conferir antes de gerar CSV. Usar `ReadView` (cliente Node em [scripts/smart_saver.js](../../scripts/smart_saver.js) — helpers `countTable`/`extractRows` corrigidos pro PascalCase do RM).
2. **Códigos humanos canônicos:** ano = `CODPERLET=2022`; série = `CODHABILITACAO=8`; disciplina = `CODDISC=7`; etc.
3. **Mapas locais:** se algum cadastro permitir, manter um arquivo de `CODs vs IDs` para auditoria (ex: `IDTURMADISC=187→CODDISC=7`).
4. **Sempre gerar arquivo ANSI** — `python` com `encoding='latin-1'` quando salvar, e `.replace('\r','')` ao ler do psql (carriage return do Windows fica colado na última coluna).
5. **Datas em formato BR** `DD/MM/AAAA`.
6. **Quando der erro de NULL/lookup:** voltar pra §2 e checar o `$T.` da coluna correspondente.

---

## 8. Tabelas com layout do Importador já mapeadas

| Tabela | Layout capturado | Script gerador |
|---|---|---|
| SMATRICPL | ✅ (27 cols, log 2026-05-20 10:35) | `scripts/gera_smatricpl_importador_totvs.py` |
| SMATRICULA | ✅ (27 cols, log 2026-05-20 10:57) | `scripts/gera_smatricula_importador_totvs.py` |
| SHABILITACAOALUNO | ❌ não capturado | (a fazer) |
| SCONTRATO | ❌ não capturado | (preferir WS — SaveRecord libera) |
| SPARCELA | ❌ não capturado | (preferir WS) |
| SBOLSAALUNO | ❌ não capturado | (preferir WS) |
| SHISTDISCCOL | ❌ não capturado | (a fazer pra histórico) |
| SNOTAS | ❌ não capturado | (revisar view export.snotas — inflada) |

---

## 9. Referências cruzadas

- [12_descoberta_regex_bug_e_bloqueios_reais.md](12_descoberta_regex_bug_e_bloqueios_reais.md) — porque caímos no importador (bloqueio SaveRecord)
- [06_estado_atual.md](06_estado_atual.md) — estado dos cadastros mestres do RM HOMOLOG
- [../fluxo/05_caso_piloto_diego.md](../fluxo/05_caso_piloto_diego.md) — caso Diego 2022
- [`scripts/gera_smatricpl_importador_totvs.py`](../../scripts/gera_smatricpl_importador_totvs.py) — gerador SMATRICPL
- [`scripts/gera_smatricula_importador_totvs.py`](../../scripts/gera_smatricula_importador_totvs.py) — gerador SMATRICULA
