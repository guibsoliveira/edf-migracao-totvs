# 04 - Validacoes Cross-System (Gennera <-> TOTVS RM)

> Validacoes em 3 momentos: ANTES de importar (qualidade da fonte),
> DURANTE (cada chamada SOAP) e DEPOIS (reconciliacao). Para cada
> validacao: como executar, tolerancia aceita, acao se falhar.

---

## A. Validacoes PRE-IMPORTACAO (qualidade da fonte Gennera)

### A.1 Pessoas

```sql
-- Quantas pessoas tem CPF?
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE cpf IS NULL OR cpf='') AS sem_cpf,
  COUNT(*) FILTER (WHERE LENGTH(cpf)=11 AND cpf ~ '^\d{11}$') AS cpf_valido_formato
FROM gennera_stg.person_fisica;
-- Esperado: ~48% sem cpf (menores). Acao: usar CPF responsavel
```

```sql
-- CPFs duplicados em person_fisica?
SELECT cpf, COUNT(*) AS qtd, STRING_AGG(name, '; ')
FROM gennera_stg.person_fisica
WHERE cpf IS NOT NULL AND cpf != ''
GROUP BY cpf
HAVING COUNT(*) > 1;
-- Tolerancia: zero duplicatas. Se houver, escalar
```

### A.2 Contratos / Matriculas

```sql
-- Alunos com matricula mas sem contrato?
SELECT e.id_enrollment, e.id_person, e.code
FROM gennera_stg.enrollment e
LEFT JOIN gennera_stg.enrollment_contract ec ON ec.id_enrollment = e.id_enrollment
WHERE ec.id_contract IS NULL AND e.status='active';
-- Tolerancia: zero orfanos. Se houver, decidir se cria contrato fictico ou pula
```

```sql
-- Contratos sem invoices (sem cobranca emitida)?
SELECT c.id_contract, c.status
FROM gennera_stg.contract c
LEFT JOIN gennera_stg.invoice i ON i.id_contract = c.id_contract
WHERE i.id_invoice IS NULL AND c.status='active';
-- Tolerancia baixa, investigar caso a caso
```

### A.3 Valores monetarios

```sql
-- Valores zerados ou negativos quando deveriam ter valor?
SELECT COUNT(*) AS suspeitos
FROM gennera_stg.servicos_historico
WHERE (
  REPLACE(REPLACE(REPLACE(COALESCE(valor_bruto,'0'), '$', ''), '.', ''), ',', '.')::numeric
) <= 0
AND item ILIKE ANY (ARRAY['%MENS%', '%ALIM%', '%MAT%']);
-- Tolerancia: <1%. Itens com valor zero geralmente sao bolsa 100% ou pula
```

### A.4 Datas

```sql
-- invoice.year com valor invalido (5021, etc.)?
SELECT year, COUNT(*), SUM(total) AS exposto
FROM gennera_stg.invoice
WHERE year NOT BETWEEN 2018 AND 2030
GROUP BY year;
-- Conhecido: 12 linhas year=5021 (R$ 41k - typo 2021), 1 com year=2032
-- Acao: CASE WHEN year=5021 THEN 2021 antes de importar
```

### A.5 Ano 2026 (especial - banco vazio)

```sql
-- 2026 esta no dump?
SELECT COUNT(*) FROM gennera_stg.enrollment WHERE academic_calendar='2026';
-- Esperado: 0 (banco esta vazio para 2026)
-- Acao: para qualquer migracao 2026, ir DIRETO na API live
```

---

## B. Validacoes DURANTE importacao

### B.1 Cada SaveRecord retorna PK?

```javascript
async function saveAndCheck(ds, xml) {
  const r = await saveRecord(ds, xml);
  if (r.fault) {
    log.error({ ds, fault: r.fault });
    throw new Error(`SaveRecord ${ds} falhou: ${r.fault}`);
  }
  if (!r.pk) {
    log.error({ ds, response: r.body });
    throw new Error(`SaveRecord ${ds} sem PK na resposta`);
  }
  return r.pk;
}
```

### B.2 Interpretacao de faults

| Fault contem | Significado | Acao |
|--------------|-------------|------|
| `ORA-01400` | Campo NOT NULL faltando | Verificar XML, adicionar campo |
| `ORA-02291` | FK violation - cadastro pai faltando | Voltar uma fase, criar dependencia |
| `ORA-00001` | UNIQUE constraint (registro ja existe) | Skip ou tratar como UPDATE |
| `Contexto invalido` / `Nivel de Ensino -1` | CODSISTEMA=S quebrou contexto | Remover CODSISTEMA do Contexto |
| `Classe nao encontrada` | DataServerName errado | Conferir lista de Edu* validos |
| `Filtro invalido` | Filtro vazio em ReadView | Usar `CODCOLIGADA=1` no minimo |

### B.3 Timeout e retry

```javascript
async function saveWithRetry(ds, xml, attempts=3) {
  for (let i = 1; i <= attempts; i++) {
    try {
      const r = await saveRecord(ds, xml);
      if (r.fault?.includes('timeout')) throw new Error('timeout');
      return r;
    } catch (e) {
      if (i === attempts) throw e;
      await sleep(2 ** i * 1000);  // backoff 2s, 4s, 8s
    }
  }
}
```

### B.4 Log estruturado por SaveRecord

```javascript
log.info({
  fase: 7,
  ds: 'EduParcelaData',
  ra: '20142166',
  codcontrato: SCONTRATO_ID,
  servico: 'MENS',
  parcela: 1,
  status: 'OK',
  pk: returnedIdParcela,
  ms: tookMs,
});
```

Salvar em `data/audit/AAAA-MM-DD-piloto-diego.jsonl`.

---

## C. Validacoes POS-IMPORTACAO

### C.1 Quantidade

Para cada entidade migrada, conferir quantidade no destino vs origem:

```javascript
// Diego 2022: esperado 37 SPARCELA
const r = await rv('EduParcelaData', `SPARCELA.RA='20142166'`);
const count = (r.xml.match(/<SPARCELA>/g) || []).length;
if (count !== 37) throw new Error(`SPARCELA count = ${count}, esperado 37`);
```

### C.2 Soma de valores

```javascript
// Soma SPARCELA.VALOR Diego 2022 deve bater Gennera
const tagsParcela = [...r.xml.matchAll(/<SPARCELA>([\s\S]*?)<\/SPARCELA>/g)];
const totalRm = tagsParcela.reduce((sum, t) => {
  const v = t[1].match(/<VALOR>([\d,.]+)<\/VALOR>/);
  return sum + parseFloat(v[1].replace(',', '.'));
}, 0);

// Gennera
const totalGennera = await psql(`
  SELECT SUM(REPLACE(REPLACE(REPLACE(valor_bruto,'$',''),'.',''),',','.'_)::numeric)
  FROM gennera_stg.servicos_historico
  WHERE aluno='Diego Silva Pereira de Sousa' AND calendario_academico='2022'
`);

if (Math.abs(totalRm - totalGennera) > 0.10) {  // tolerancia 10 centavos (arredondamento)
  throw new Error(`Discrepancia valor: RM=${totalRm} vs Gennera=${totalGennera}`);
}
```

### C.3 Integridade FK (no destino)

```javascript
// Cada SPARCELA aponta para um SCONTRATO que existe?
const sparcelas = await rv('EduParcelaData', `SPARCELA.RA='20142166'`);
const contratos = await rv('EduContratoData', `SCONTRATO.RA='20142166'`);

const codContratosNaSparcela = new Set(
  [...sparcelas.xml.matchAll(/<CODCONTRATO>(\d+)<\/CODCONTRATO>/g)].map(m => m[1])
);
const codContratosNoSContrato = new Set(
  [...contratos.xml.matchAll(/<CODCONTRATO>(\d+)<\/CODCONTRATO>/g)].map(m => m[1])
);

for (const c of codContratosNaSparcela) {
  if (!codContratosNoSContrato.has(c)) {
    throw new Error(`SPARCELA aponta para CODCONTRATO ${c} que nao existe em SCONTRATO`);
  }
}
```

### C.4 Cross-check Gennera vs TOTVS (amostra 5%)

Para 5% dos alunos importados, conferir manualmente:
- Soma de parcelas
- Numero de matriculas
- CODCFO correto (responsavel financeiro bate)
- Status (paid/aberto bate)

```javascript
async function reconciliar(ra) {
  const gennera = await fetchGenneraAluno(ra);  // via API
  const totvs = await readTotvsAluno(ra);  // via SOAP

  return {
    ra,
    parcelas: { gennera: gennera.invoices.length, totvs: totvs.sparcelas.length },
    valor_total: { gennera: gennera.total, totvs: totvs.total },
    codcfo: { gennera: gennera.responsavel.codcfo, totvs: totvs.codcfo },
    delta_valor: Math.abs(gennera.total - totvs.total),
    OK: Math.abs(gennera.total - totvs.total) < 0.10
       && gennera.invoices.length === totvs.sparcelas.length,
  };
}
```

### C.5 Negativos esperados

Coisas que NAO deveriam estar no RM apos migracao:
- Parcelas duplicadas (mesma combinacao RA + CODSERVICO + PARCELA + IDPERLET)
- SPARCELAs com VALOR <= 0 (exceto bolsas integrais)
- SCONTRATOs com CODCFO = 0 ou NULL
- SCONTRATOs sem IDPERLET

```sql
-- Pesquisa no RM (via wsConsultaSQL.RealizarConsultaSQL se cadastrar sentenca)
-- ou export-and-validate Gennera-side
```

---

## D. Tolerancias aceitas

| Validacao | Tolerancia | Justificativa |
|-----------|-----------|---------------|
| Soma valor SPARCELA vs Gennera | ±R$ 0,10 | Arredondamento decimais |
| Contagem SPARCELA vs invoice | exato | Sem tolerancia |
| Datas (DTVENCIMENTO) | exato | Sem tolerancia |
| CPF responsavel | exato | Sem tolerancia (CPF e PK no FCFO) |
| Status (Q/A/C) | exato | Sem tolerancia |
| Latencia SOAP | <2s por SaveRecord | Maior = investigar |
| Taxa de erro batch | <0.5% | Maior = parar e investigar |

---

## E. Acao se validacao falhar

### Severidades

**CRITICA (parar tudo, investigar):**
- Taxa de fault > 0.5% em SaveRecords
- Discrepancia financeira > R$ 1
- FK violation persistente
- ORA-XXXXX inesperado

**ALTA (pausar batch, escalar):**
- Algum SCONTRATO com valor zero
- ContaSparcelas != ContaInvoices para algum aluno
- CODCFO faltante quando responsavel tem CPF

**MEDIA (logar e continuar):**
- Latencia individual >2s
- Cancelados antigos (paid->cancelled no Gennera) - cancelar tambem no RM ou ignorar?

**BAIXA (so logar):**
- Discrepancia <R$ 0,10
- Datas em zona limítrofe (1 dia)

---

## F. Procedimento de rollback

Se validacao critica falhar APOS importacao parcial:

```javascript
async function rollback(idsCriados) {
  for (const { ds, pk } of idsCriados.reverse()) {  // ordem inversa
    try {
      await deleteRecord(ds, pk);
      log.info({ rolled_back: ds, pk });
    } catch (e) {
      log.error({ failed_to_delete: ds, pk, error: e.message });
    }
  }
}
```

**Sempre logar PK retornada de cada SaveRecord** para permitir rollback ordenado.

---

## Referencias

- `knowledge/totvs/05_pitfalls.md` - faults conhecidos
- `knowledge/gennera/06_limitacoes_api.md` - o que API origem nao tem
- `knowledge/fluxo/03_ordem_importacao.md` - fases e dependencias
