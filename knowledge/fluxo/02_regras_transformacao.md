# 02 - Regras de Transformacao Gennera -> TOTVS RM

> Para cada dimensao de dado (identificadores, encoding, valores, datas,
> granularidade, status), a regra concreta de conversao com formula/codigo.

---

## 1. Identificadores

### 1.1 RA (Registro Academico)

**Origem:** `gennera_stg.student_code_unico.code_unif` (texto VARCHAR(50), formato YYYYNNNNNN)
**Destino:** `SALUNO.RA` (varchar) — passa direto, sem transformacao.

```sql
-- Gennera
SELECT scu.code_unif AS RA, pf.name
FROM gennera_stg.student_code_unico scu
JOIN gennera_stg.person_fisica pf USING (id_person)
WHERE scu.code_unif = '20142166';
```

**NUNCA usar** `enrollment.code` ou `id_person` como RA - eles tem semantica diferente. RA canonico SO em `student_code_unico.code_unif`.

### 1.2 CODCFO (Cliente/Fornecedor)

**Origem:** `gennera_stg.cliente_fornecedor.codcfo` (varchar 5) + `person_fisica.codcfo`
**Destino:** `FCFO.CODCFO` (zero-padded LPAD 6 digitos para algumas tabelas, sem padding em outras - depende do contexto)

```sql
-- Caso Gennera codcfo='1645' (Joselia)
SELECT LPAD(pf.codcfo, 6, '0') AS CODCFO_PAD, pf.codcfo AS CODCFO_RAW
FROM gennera_stg.person_fisica pf
WHERE pf.cpf = '10743729803';
-- Resultado: '001645' (pad) / '1645' (raw)
```

Se aluno nao tem CODCFO ainda (responsavel novo): criar PPESSOA + FCFO no TOTVS antes do SCONTRATO.

### 1.3 IDPERLET (ID Periodo Letivo)

**Origem:** `enrollment.academic_calendar` (texto "2021"..."2026")
**Destino:** `SCONTRATO.IDPERLET` (int, INDEX automatico do RM, NAO o ano)

**Mapping confirmado no RM HOMOLOG:**

| Ano letivo | IDPERLET RM | Observacao |
|------------|-------------|------------|
| 2023 | 15 | EF + EM |
| 2024 | 18 | EF1 |
| 2024 | 19 | EM (Maria Valentina) |
| 2026 | 1, 2 | testes |
| **2022** | **NAO EXISTE** | precisa criar SPLETIVO 2022 antes |

```javascript
const IDPERLET_MAP = {
  '2023': 15,
  '2024-EF': 18,
  '2024-EM': 19,
  '2026': 2,  // ou 1 dependendo
};

function getIdPerlet(ano, curso) {
  if (ano === '2024' && curso.startsWith('EM')) return 19;
  if (ano === '2024' && curso.startsWith('EF')) return 18;
  return IDPERLET_MAP[ano] || null;
}
```

Para anos nao mapeados (2022): chamar `SaveRecord(EduPLetivoData)` antes de tudo, capturar IDPERLET retornado e cachear.

### 1.4 IDHABILITACAOFILIAL

**Origem:** derivada (CODCURSO + CODHABILITACAO + CODFILIAL + IDPERLET)
**Destino:** `SCONTRATO.IDHABILITACAOFILIAL` (int, INDEX automatico)

**Mapping confirmado:**

| Curso | Habilitacao | Filial | Ano | IDHABILITACAOFILIAL |
|-------|-------------|--------|-----|---------------------|
| EM | 3 (3a serie) | UN1 (1) | 2024 | 7 |
| EF1 | 1 (1o ano) | UN1 (1) | 2024 | 49 |
| ... | ... | ... | ... | ... |

Quando nao existir, criar via SaveRecord no DataServer apropriado.

---

## 2. Encoding (LATIN1 -> UTF-8)

**Banco Gennera (PostgreSQL):** LATIN1
**API Gennera (REST):** UTF-8 (JSON)
**TOTVS RM (SOAP):** UTF-8 (XML)
**TXT posicional FLAN:** ANSI Windows-1252

**Regra:**

1. Sempre rodar psql com `PGCLIENTENCODING=LATIN1` para ler corretamente
2. Aplicar `.sql` no banco com `-c "SET CLIENT_ENCODING TO 'UTF8'"` se o arquivo tem caracteres especiais
3. Saidas para TOTVS SOAP: UTF-8 puro
4. Saidas para TXT posicional: converter para Windows-1252 (`iconv -f UTF-8 -t WINDOWS-1252//TRANSLIT`)

```javascript
// Node.js: ler arquivo LATIN1 e escrever UTF-8
const buf = fs.readFileSync(path);
const text = iconv.decode(buf, 'latin1');
fs.writeFileSync(out, text, 'utf8');
```

---

## 3. Valores monetarios

**Origem Gennera (banco):** texto BRL `"$1.234,56"` (ponto = separador milhares, virgula = decimal)
**Origem Gennera (API):** numeric direto `1234.56`
**Destino TOTVS (XML SOAP):** numeric em formato BR `"5658,00"` (4 decimais opcional)
**Destino TOTVS (TXT posicional):** NUMERICO(18,4) = inteiro com 4 decimais embedded, LPAD com zeros

### Conversao banco BRL -> numeric

```sql
-- Gennera "$1.234,56" -> 1234.56
SELECT REPLACE(REPLACE(REPLACE(valor_bruto, '$', ''), '.', ''), ',', '.')::numeric
FROM gennera_stg.servicos_historico
WHERE valor_bruto IS NOT NULL;
```

### Conversao numeric -> string BR (para XML)

```javascript
function brl(value) {
  return Number(value).toFixed(2).replace('.', ',');
}
// 5658 -> "5658,00"
// 1234.56 -> "1234,56"
```

### Conversao numeric -> NUMERICO 18,4 LPAD (para TXT posicional)

```javascript
function posicional18_4(value) {
  const inteiro = Math.round(Number(value) * 10000);
  return String(inteiro).padStart(18, '0');
}
// 5658 -> "000000000056580000"
// 1234.56 -> "000000000012345600"
```

---

## 4. Datas

**Origem Gennera:**
- Banco: texto, podem estar ISO (`"2025-01-15T12:00:00.000Z"`) ou BR (`"15/01/2025"`)
- API: ISO timestamp (`"2026-05-11T12:00:32.239Z"`)

**Destino TOTVS:**
- SOAP XML: ISO sem timezone (`"2026-05-11T00:00:00"`)
- TXT posicional: AAAAMMDD (`"20260511"`)

### Conversao

```sql
-- Banco Gennera misto -> ISO
SELECT
  CASE
    WHEN data_vencimento ~ '^\d{4}-\d{2}-\d{2}' THEN data_vencimento::date
    WHEN data_vencimento ~ '^\d{2}/\d{2}/\d{4}' THEN TO_DATE(data_vencimento, 'DD/MM/YYYY')
  END AS dt_iso
FROM gennera_stg.servicos_historico;
```

```javascript
// API Gennera ISO -> TOTVS XML
function isoFromGennera(iso) {
  return new Date(iso).toISOString().substring(0, 19);
  // "2026-05-11T12:00:32"
}

// Para TXT posicional
function posDate(iso) {
  return iso.substring(0, 10).replace(/-/g, '');
  // "20260511"
}
```

---

## 5. Granularidade SCONTRATO

**Origem Gennera (4 contratos por aluno/ano):**

```
contract 94358788391019404110 - REMATRICULA - R$ 4.271,00 - 1 parcela
contract 94076381793873341801 - MENSALIDADE - R$ 51.252,00 - 12 parcelas
contract 18636611836559665614 - ALIMENTACAO - R$ 10.680,00 - 12 parcelas
contract 32085002157728272358 - MATERIAL    - R$ 4.164,00 - 12 parcelas
```

**Destino TOTVS (1 SCONTRATO consolidado):**

```xml
<SCONTRATO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCONTRATO>{seq_gerado}</CODCONTRATO>
  <RA>20142166</RA>
  <IDPERLET>{IDPERLET_2022}</IDPERLET>
  <IDHABILITACAOFILIAL>{IDHABFIL_EF2_8ano_UN1_2022}</IDHABILITACAOFILIAL>
  <CODFILIAL>1</CODFILIAL>
  <CODCFO>1645</CODCFO>  <!-- Joselia, responsavel financeiro -->
  <CODPLANOPGTO>222001</CODPLANOPGTO>  <!-- 2022 + UN1 + EFII 8 ano -->
  <DTCONTRATO>2021-10-21T00:00:00</DTCONTRATO>
  <TIPOCONTRATO>S</TIPOCONTRATO>
  ...
</SCONTRATO>
```

Mais 37 SPARCELAs (1 REMATRIC + 12 MENS + 12 ALIM + 12 MAT) apontando para esse CODCONTRATO unico.

```javascript
function consolidarContratos(gennera_contratos) {
  // Agrupa por aluno + ano academico
  return {
    SCONTRATO: {
      // dados do contrato master (data, plano, FCFO, IDPERLET)
    },
    SPARCELAs: gennera_contratos.flatMap(c =>
      c.invoices.map((inv, idx) => ({
        CODSERVICO: mapServico(c.item),  // MENS, ALIM, MAT, REMATRIC
        PARCELA: idx + 1,
        VALOR: inv.amount,
        DTVENCIMENTO: inv.due_date,
        DTCOMPETENCIA: `${inv.year}-${String(inv.month).padStart(2,'0')}-01`,
      }))
    )
  };
}
```

---

## 6. Status de pagamento

| Gennera (`payment.status`) | TOTVS FLAN.STATUS | Acao |
|---------------------------|-------------------|------|
| `paid` | `Q` (quitado) | Baixar com `wsFin.BaixaLancamento` ou apenas registrar como pago |
| `pending` (paymentDate FUTURA) | `A` (aberto) | Normal - aguardando D+30/D+45 do gateway |
| `pending` (paymentDate PASSADA) | `A` ou alerta | Investigar - possivel travamento |
| `cancelled` | `C` (cancelado) | Registrar cancelamento explicito |

**Atencao:** o status `pending` no Gennera NAO significa erro - usualmente significa "PJBank aguardando processar D+30 normal". Confirmar pelo `paymentDate` antes de tratar como problema.

---

## 7. Servicos

Mapeamento Gennera item -> TOTVS CODSERVICO:

| Padrao Gennera item | TOTVS CODSERVICO | NOME SSERVICO |
|---------------------|-------------------|----------------|
| contem "MENS" e nao "1" | `MENS` | Mensalidade |
| contem "ALIM" | `ALIM` | Alimentacao |
| contem "MAT", "MDIDAT", "MATERIAIS" | `MAT` | Material Didatico |
| contem "1" antes de "MENS" ou "PARC" | `1aMENS` ou `REMATRIC` | 1a Mensalidade (Rematric) |
| contem "ANUID" ou "ANUIDADE" | `ANUIDADE` | Anuidade |

**Atencao encoding LATIN1:** o "o" ordinal (1o, 2o, 3o) quebra word boundary do PostgreSQL com locale PT-BR.

```sql
-- ERRADO (\m, \M nao funcionam com 'o' em LATIN1):
WHERE item ~* '\m1.*\m(MENS|PARC)\M'

-- CERTO:
WHERE item ~* '1[^[:space:]]{0,3}\s*(MENS|PARC)'
```

---

## 8. Filial

```javascript
const FILIAL_MAP = {
  320: 1,  // UN1
  321: 2,  // UN2
  873: null,  // teste - nao migrar
};

function getCodFilial(idInstitution) {
  return FILIAL_MAP[idInstitution];
}
```

Regra de negocio EDF (memoria persistente):
- UN1 = EF1(3o-5o) + EF2 + EM Integral
- UN2 = EI (3 turnos: Integral, Manha, Tarde) + EF1(1o-2o)

---

## 9. Pessoas (PPESSOA)

Mapeamento de `person_fisica` -> `PPESSOA`:

| Gennera | TOTVS PPESSOA | Tipo |
|---------|---------------|------|
| `cpf` | `CGCCFO` (sem mascara, 11 digitos) | string |
| `name` | `NOME` | string upper trim |
| `email` | `EMAIL` | string lower |
| `mobile_phone_number_normalized` | `FONE1` | string |
| `telephone_number_normalized` | `FONE2` | string |
| `birthdate` (texto/timestamp) | `DTNASCIMENTO` (date) | conversao |
| `street + street_number` | `RUA` | concatenacao |
| `zipcode` | `CEP` | string sem mascara |
| `city` | `CIDADE` | string |
| `state` | `ESTADO` | string 2 chars |
| `neighborhood` | `BAIRRO` | string |
| `gender` (M/F texto) | `SEXO` | conversao char |

**Pessoas sem CPF (48% do total)**: usar CPF do responsavel financeiro OU gerar CPF temporario `99{idPerson}{checkdigit}` - decisao com financeiro EDF.

---

## 10. Validacao das transformacoes

Sempre apos transformar, validar:

```javascript
function validar(SCONTRATO) {
  const erros = [];
  if (!SCONTRATO.RA?.match(/^\d{10}$/)) erros.push('RA invalido');
  if (!SCONTRATO.IDPERLET) erros.push('IDPERLET vazio');
  if (!SCONTRATO.IDHABILITACAOFILIAL) erros.push('IDHABILITACAOFILIAL vazio');
  if (!SCONTRATO.CODCFO) erros.push('CODCFO vazio - responsavel financeiro nao cadastrado');
  if (SCONTRATO.VALOR_TOTAL <= 0) erros.push('Valor invalido');
  return erros;
}
```

---

## Referencias

- `knowledge/gennera/05_pitfalls.md` - encoding, BRL, datas
- `knowledge/totvs/04_regras_negocio.md` - regras RM
- `views/financeiro/v2/03_sservico.sql` - exemplo concreto de mapeamento de servico
- `views/financeiro/v2/07_scontrato.sql` - logica de consolidacao
