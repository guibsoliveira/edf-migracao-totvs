# 12 - Descoberta do regex bug e bloqueios REAIS

**Data:** 2026-05-19 (tarde) | **Status:** VALIDADO em homolog (Postman direto + cliente Node)

> Este documento corrige a premissa do `11_estrategia_filtro_perfil.md` (que estava errada) e estabelece o que de fato funciona/bloqueia no RM TBC.

---

## 1. O bug que distorceu o diagnóstico anterior

### Sintoma observado (antes de descobrir o bug)

ReadView em cadastros mestres (EduCursoData, EduServicoData, EduResponsavelData, etc) parecia **retornar sempre 0 registros**, mesmo com dados conhecidamente existentes no banco RM.

### Causa real

JavaScript regex é **case-sensitive por padrão**. O cliente Node contava registros com `xml.match(/<SCURSO>/g)` (UPPERCASE). Mas o RM retorna a tag de tabela em **PascalCase**: `<SCurso>`, `<FCfo>`, `<SServico>`, etc — enquanto os **campos** vêm em UPPERCASE (`<CODCURSO>`, `<NOME>`, `<CGCCFO>`).

Resultado: `count = 0` sempre, mesmo com XML cheio de registros.

### Validação da correção

Teste manual no Postman SOAP direto contra EduCursoData retornou:

```xml
<SCurso>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCURSO>EF1</CODCURSO>
  <NOME>Ensino Fundamental I</NOME>
  ...
</SCurso>
<SCurso>
  <CODCURSO>EF2</CODCURSO>
  <NOME>Ensino Fundamental II</NOME>
  ...
</SCurso>
... (4 cursos no total)
```

### Fix aplicado em `scripts/smart_saver.js`

Adicionadas helpers case-insensitive:

```js
function countTable(xml, table) {
    if (!xml || !table) return 0;
    return (xml.match(new RegExp(`<${table}>`, 'gi')) || []).length;
}

function extractRows(xml, table) {
    if (!xml || !table) return [];
    const re = new RegExp(`<${table}>([\\s\\S]*?)</${table}>`, 'gi');
    const rows = [];
    let m;
    while ((m = re.exec(xml)) !== null) {
        const obj = {};
        const fieldRe = /<([A-Z][A-Z0-9_]+)>([\s\S]*?)<\/\1>/g;
        let f;
        while ((f = fieldRe.exec(m[1])) !== null) obj[f[1]] = f[2];
        rows.push(obj);
    }
    return rows;
}

module.exports = { smartSave, rv, rawSave, diagnose, countTable, extractRows };
```

**Regra de uso:** sempre passar a tabela em PascalCase: `countTable(xml, 'SCurso')`, não `'SCURSO'`. Como o regex tem flag `i`, ambos funcionam, mas PascalCase deixa explícito o formato real.

---

## 2. Lição metodológica (importante)

Antes de afirmar "DataServer X não retorna dados" ou "permissão Y bloqueia":

1. **Print o XML cru** da resposta SOAP (não só o count parseado pelo cliente).
2. **Compare contagem esperada vs observada** — se SCURSO deveria retornar 4 cursos conhecidos e retorna 0, é mais provável bug do cliente do que bug do servidor.
3. **Reproduza no Postman direto** antes de pedir intervenção do consultor — elimina variável do cliente.

A premissa "filtro de perfil bloqueia leitura" foi sustentada por horas sem essa verificação básica.

---

## 3. Estado real ReadView vs SaveRecord (validado 2026-05-19)

### ReadView — TODOS funcionam

| DataServer | Tabela retornada (PascalCase) | Status |
|---|---|---|
| EduCursoData | `<SCurso>` | ✅ OK (4 cursos) |
| EduHabilitacaoData | `<SHabilitacao>` | ✅ OK (17 hab.) |
| EduGradeData | `<SGrade>` | ✅ OK (81 grades) |
| EduDisciplinaData | `<SDisciplina>` | ✅ OK (126 disc.) |
| EduPLetivoData | `<SPLetivo>` | ✅ OK |
| EduHabilitacaoFilialData | `<SHabilitacaoFilial>` | ✅ OK |
| EduServicoData | `<SServico>` | ✅ OK (16 serviços) |
| EduResponsavelData | `<SResponsavel>` | ✅ OK (relaciona responsável↔parcela; não é cadastro mestre FCFO) |
| EduPlanoPgtoData | `<SPlanoPgto>` | ✅ OK |
| EduHabModeloPgtoData | `<SHabModeloPgto>` | ✅ OK |
| EduParcPlanoData | `<SParcPlano>` | ✅ OK |
| EduTurmaData | `<STurma>` | ✅ OK |
| EduTurmaDiscData | `<STurmaDisc>` | ✅ OK |
| EduAlunoData | `<SAluno>` | ✅ OK |
| EduMatriculaData | `<SMatricula>` | ✅ OK |
| EduMatricPLData | `<SMatricPL>` | ✅ OK |
| EduEtapasData | `<SEtapas>` | ✅ OK (48 etapas) |
| EduNotasData | `<SNotas>` | ✅ OK |

### SaveRecord — passa em quase tudo, EXCETO matrícula

Probe sistemático com XML mínimo (apenas `<CODCOLIGADA>1</CODCOLIGADA>`) chega no `ValidateInsertRecordSecurity` em todos os DataServers e segue pra validação de campos — ou seja, **não há bloqueio de perfil de SaveRecord nesse usuário**.

Mas com XML completo de SMATRICPL para o Diego 2022, retorna:

```
Você não está autorizado a inserir registros!
   at RM.Lib.Server.RMSDataServer.ValidateInsertRecordSecurity()
```

E **a mesma resposta acontece com o login do consultor** (testado pelo Postman). Logo o bloqueio NÃO é por perfil — é configuração global do DataServer ou do ambiente.

### Por que o probe mínimo passou e o XML completo não?

A ordem interna de validação do RM é:

1. Parse XML
2. Validar campos obrigatórios (Column does not belong, ORA-01400)
3. **`ValidateInsertRecordSecurity()`** ← só chega aqui se 1 e 2 passaram
4. Insert na tabela (FK, UK, validações de domínio)

Com XML mínimo, a falha vem no passo 2 ("falta IDPERLET"). Com XML completo, chega no 3 e dispara. Isso confirmou que a checagem de segurança é **dependente de dados completos**, não uma simples flag por usuário.

---

## 4. Bloqueio REAL identificado

| DataServer | Operação | Status | Evidência |
|---|---|---|---|
| `EduMatricPLData` | SaveRecord (XML completo) | 🔒 **BLOQUEADO** | "Você não está autorizado a inserir registros!" — reproduzido com goliveira E com user do consultor |
| `EduMatriculaData` | SaveRecord (XML completo) | 🔒 **BLOQUEADO** (cascateia) | "FK violation em IncluirMatriculaDisc" — internamente tenta criar SMATRICPL e bate no mesmo bloqueio |

### Hipóteses do bloqueio

1. **DataServer com inserção desabilitada globalmente** no TBC dessa instância
2. **Matrícula deve ir por outro caminho:** workflow "Processo de Matrícula" do RM cliente, importação Excel/template, ou portal acadêmico
3. **Algum DataServer alternativo** que orquestra a matrícula (a investigar com consultor)

Pendente de resposta do consultor (mensagem mandada 2026-05-19 tarde).

---

## 5. Implicações para a migração

### Para qualquer operação

- **Antes de afirmar "DS bloqueia X"**, validar via Postman direto com XML cru.
- **PK retornada** em SaveRecord vem no formato `1;PK1;PK2;...` (string separada por `;`). Capturar e usar pra próximas operações.
- **Idempotência:** "Chave duplicada" no SaveRecord = sucesso (registro já existe com mesma PK). smart_saver já trata.

### Para o caso Diego 2022

- ✅ **Cadastros estruturais criados:** SCURSO/SHABILITACAO/SGRADE/SDISCIPLINA/SDISCGRADE × 13/SPLETIVO/SHABILITACAOFILIAL (IDHABFIL=24)/SHABILITACAOFILIALPL/STURMA 8A/STURMADISC × 13 (IDTURMADISC 187–199)/SHABILITACAOALUNO Diego.
- ✅ **Financeiro estrutural criado:** SPLANOPGTO 221002 + SPARCPLANO × 37 + SHABMODELOPGTO (mas SPARCPLANO aponta para SSERVICO `Migracao 2022` 279–282 — DEVE SER CORRIGIDO pra apontar pros SSERVICO genéricos `1`, `2`, `3`, `4`).
- ❌ **Matrícula:** bloqueada (SMATRICPL/SMATRICULA).
- ❌ **Contrato:** pendente (depende de matrícula).
- ❌ **Notas/Frequência:** pendentes (dependem de matrícula).

---

## 6. Próximos passos

1. **Aguardar consultor** liberar EduMatricPLData OU indicar caminho alternativo.
2. **Fix SSERVICO duplicados** (apos consultor confirmar padrão "serviço genérico"): apontar 37 SPARCPLANO pros COD 1-4 originais, deletar SSERVICO 279–282.
3. **Refatorar `scripts/smart_saver.js`** se necessário pra incluir helper de upsert idempotente.

---

## Referências cruzadas

- [11_estrategia_filtro_perfil.md](./11_estrategia_filtro_perfil.md) — DEPRECATED (premissa do regex bug)
- [06_estado_atual.md](./06_estado_atual.md) — Estado RM HOMOLOG
- [../fluxo/05_caso_piloto_diego.md](../fluxo/05_caso_piloto_diego.md) — Caso Diego completo
- [../fluxo/07_arvore_dependencias_totvs.md](../fluxo/07_arvore_dependencias_totvs.md) — Árvore FK do RM
- `scripts/smart_saver.js` — cliente Node com helpers corrigidos
