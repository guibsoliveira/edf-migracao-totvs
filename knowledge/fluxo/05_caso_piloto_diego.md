# 05 - Caso Piloto: Diego Silva Pereira de Sousa (2022)

> Fluxo INTEIRO de migracao para 1 aluno como referencia executavel.
> Diego e o piloto oficial para validar todo o fluxo Gennera -> TOTVS RM
> antes de escalar para massa.

---

## Identificacao

| Campo | Valor |
|-------|-------|
| **Aluno** | Diego Silva Pereira de Sousa |
| **RA** | 20142166 (canonico em `student_code_unico.code_unif`) |
| **id_person Gennera** | 1490 |
| **CPF** | 48497447883 |
| **Email** | diego.sousa@edf.g12.br |
| **Nascimento** | 2009-04-15 |
| **Ano alvo** | 2022 |
| **Curso/Habilitacao** | EFII / 8 ano |
| **Turma** | 8A |
| **Filial** | UN1 |

## Responsaveis

| Papel | Nome | id_person | CPF | CODCFO Gennera |
|-------|------|-----------|-----|----------------|
| Financeiro | Joselia dos Santos Silva de Sousa | 65 | 10743729803 | **1645** (ja existe) |
| Academico | Vanderlei Pereira de Sousa | 66 | 07213852817 | (sem - opcional criar) |

## Dados financeiros 2022

| # | Contrato Gennera | Servico | Parcelas | Valor unit | Total | Status |
|---|------------------|---------|---------:|-----------:|------:|--------|
| 1 | `94358788391019404110` | 1 MENS (Rematric) | 1 | R$ 4.271,00 | R$ 4.271,00 | pago |
| 2 | `94076381793873341801` | MENS | 12 | R$ 4.271,00 | R$ 51.252,00 | pago |
| 3 | `18636611836559665614` | ALIM | 12 | R$ 890,00 | R$ 10.680,00 | pago |
| 4 | `32085002157728272358` | MAT | 12 | R$ 347,00 | R$ 4.164,00 | pago |
| **Total** | | | **37** | | **R$ 70.367,00** | **100% pago** |

Sem bolsa. Sem desconto.

## Estado atual no TOTVS RM HOMOLOG (atualizado 2026-05-19 tarde)

| Entidade | Status |
|----------|--------|
| SCURSO EF2 / SHABILITACAO 8 / SGRADE 2022 | ✅ EXISTE (cadastro mestre) |
| SDISCIPLINA × 13 (codigos 7,19,21,32,49,51,55,62,67,76,84,85,104) | ✅ EXISTE |
| SDISCGRADE × 13 (matriz EF2-8-2022) | ✅ CRIADO nesta sessao |
| SPLETIVO 2022 | ✅ **IDPERLET=12** (Filial 1), **=14** (Filial 2) |
| SHABILITACAOFILIAL EF2-8-UN1-2022 | ✅ **IDHABILITACAOFILIAL=24** |
| SHABILITACAOFILIALPL EF2-8-UN1-2022 | ✅ (via `EduHabilitacaoFilialPlData`, NÃO `EduHabilitacaoFilialData`) |
| STURMA 8A 2022 | ✅ (PK: 1;1;12;8A) |
| STURMADISC × 13 | ✅ **IDTURMADISC=187–199** |
| SALUNO (Diego, RA 20142166) | ✅ EXISTE (CODPESSOA=1490) |
| SHABILITACAOALUNO Diego | ✅ (PK: 1;24;20142166) |
| SPLANOPGTO **221002** ("EF2 6/9 ANO 2022") | ✅ EXISTE (não 222001 como rascunho previa) |
| SPARCPLANO × 37 (plano 221002) | ⚠️ CRIADO mas apontando pros SSERVICO 279–282 errados (a corrigir pros 1–4) |
| SHABMODELOPGTO 221002 ↔ IDHABFIL=24 | ✅ |
| **SMATRICPL Diego 2022** | 🔒 **BLOQUEADO** ("Você não está autorizado" em `EduMatricPLData.ValidateInsertRecordSecurity()`) |
| **SMATRICULA × 13 Diego 2022** | 🔒 **BLOQUEADO em cascata** (`EduMatriculaDiscEnsSuperiorObj.IncluirMatriculaDisc` chama SMATRICPL internamente) |
| SCONTRATO × 4 (CODCONTRATO 2473, 2474, 2475, 2636) | ⏳ Aguarda destravar matrícula |
| SPARCELA × 37 | ⏳ Aguarda SCONTRATO |
| SBOLSAALUNO × 4 (todas bolsa 100% — filho de funcionário) | ⏳ Aguarda SCONTRATO |
| SPROVAS / SNOTAS | ⏳ Pós-matrícula (revisar view export.snotas inflada 3919 rows = junção cartesiana) |
| FLAN | ⏳ Pós-SPARCELA |

### Bug histórico corrigido nesta sessão

Antes acreditávamos que "filtro de perfil bloqueava leitura" dos cadastros mestres. Causa real: regex case-sensitive no cliente Node não casava `<SCURSO>` com `<SCurso>` (PascalCase do retorno). Detalhes em [knowledge/totvs/12_descoberta_regex_bug_e_bloqueios_reais.md](../totvs/12_descoberta_regex_bug_e_bloqueios_reais.md).

### Bloqueio real único

`EduMatricPLData.SaveRecord` retorna `Você não está autorizado a inserir registros!`. Reproduzido com user **goliveira** E com user **consultor** (10042327644) via Postman direto — não é perfil de usuário, é configuração do DataServer no ambiente. Pendente resolução com consultor (mensagem enviada 2026-05-19).

### Bolsas — atenção

Diego TEM bolsa 100% em 2022 (`DESCONTO FILHO DE FUNCIONÁRIO 100%` em MENS+ALIM, `DESCONTO FOLHA FF` em MAT). O rascunho original do piloto dizia "Sem bolsa". Corrigir: **vai precisar criar 4 SBOLSAALUNO** (um por contrato) ou usar a view sbolsaaluno (que tem 2 — faltam MENS principal 2636 e MAT 2475).

### Joselia FCFO

Mãe **CODCFO=1645** já cadastrada no RM (confirmado via `EduResponsavelData` — mas atenção: esse DS retorna `<SResponsavel>` que é vínculo responsável↔parcela, não cadastro mestre FCFO). Caminho para criar FCFO mestre via WS ainda não está definido — verificar com consultor se necessário criar novos.

---

## Plano de migracao (Fase a Fase)

### Fase 0 - Verificacao estrutural

```javascript
// 1. AutenticaAcesso
await soap('/wsConsultaSQL/IwsBase', 'http://www.totvs.com/IwsBase/AutenticaAcesso',
  `<tot:AutenticaAcesso><tot:user>${USER}</tot:user><tot:senha>${PASS}</tot:senha></tot:AutenticaAcesso>`);
// Esperado: <AutenticaAcessoResult>1</AutenticaAcessoResult>

// 2. SCONTRATO Diego nao deve existir
const r = await rv('EduContratoData', `SCONTRATO.RA='20142166'`);
// Esperado: count = 0

// 3. SPLETIVO 2022 existe?
const p = await rv('EduPLetivoData', `SPLETIVO.CODPERLET='2022'`);
// Provavelmente: count = 0 (bloqueado a Fase 1 para criar)

// 4. SCURSO EF2 existe? (provavelmente sim, mas ReadView bloqueia)
//    Confirmar via UI.
```

### Fase 1 - Estrutura academica 2022 (se faltar)

Se SPLETIVO 2022 nao existe:

```xml
<!-- SaveRecord EduPLetivoData -->
<tot:SaveRecord>
  <tot:DataServerName>EduPLetivoData</tot:DataServerName>
  <tot:XML><![CDATA[
    <SPLETIVO>
      <CODCOLIGADA>1</CODCOLIGADA>
      <CODPERLET>2022</CODPERLET>
      <DTINICIO>2022-01-01T00:00:00</DTINICIO>
      <DTFIM>2022-12-31T00:00:00</DTFIM>
      <NOMEPL>Ano Letivo 2022</NOMEPL>
      <STATUS>A</STATUS>
    </SPLETIVO>
  ]]></tot:XML>
  <tot:Contexto>CODCOLIGADA=1;CODFILIAL=1;CODNIVELENSINO=1</tot:Contexto>
</tot:SaveRecord>
```

**Captura:** IDPERLET retornado (vai ser proximo na sequencia, talvez 20 ou 21).

### Fase 2 - SHABILITACAOFILIAL EF2-8ano-UN1-2022

Se nao existir:

```xml
<SHABILITACAOFILIAL>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODFILIAL>1</CODFILIAL>
  <IDPERLET>{IDPERLET_2022}</IDPERLET>
  <ATIVO>S</ATIVO>
</SHABILITACAOFILIAL>
```

**Captura:** IDHABILITACAOFILIAL retornado.

### Fase 3 - Pessoas

**Joselia (CODCFO 1645) provavelmente ja existe no FCFO.** Verificar via:

```javascript
const r = await rv('EduResponsavelData', `SRESPONSAVEL.CGCCFO='10743729803'`);
// Se conta > 0, ja existe. Usar CODCFO=1645.
```

Se Diego nao tem PPESSOA completa (so SALUNO criado por outro processo): criar PPESSOA.

```xml
<PPESSOA>
  <CODCOLIGADA>0</CODCOLIGADA>  <!-- pessoa e cross-coligada -->
  <NOME>DIEGO SILVA PEREIRA DE SOUSA</NOME>
  <CGCCFO>48497447883</CGCCFO>
  <EMAIL>diego.sousa@edf.g12.br</EMAIL>
  <DTNASCIMENTO>2009-04-15T00:00:00</DTNASCIMENTO>
  <SEXO>M</SEXO>
</PPESSOA>
```

### Fase 4 - Vinculos academicos

```xml
<SHABILITACAOALUNO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <RA>20142166</RA>
  <IDHABILITACAOFILIAL>{Fase 2}</IDHABILITACAOFILIAL>
  <DTINICIO>2021-10-21T00:00:00</DTINICIO>
  <STATUS>A</STATUS>
</SHABILITACAOALUNO>
```

```xml
<SMATRICULA>
  <CODCOLIGADA>1</CODCOLIGADA>
  <RA>20142166</RA>
  <IDPERLET>{Fase 1}</IDPERLET>
  <CODCURSO>EF2</CODCURSO>
  <CODHABILITACAO>8</CODHABILITACAO>
  <CODTURMA>8A</CODTURMA>
  <DTMATRICULA>2021-10-21T00:00:00</DTMATRICULA>
  <STATUS>N</STATUS>
</SMATRICULA>
```

### Fase 5 - Plano financeiro

**SSERVICO** (MENS, ALIM, MAT, 1aMENS) provavelmente ja existe. Confirmar.

**SPLANOPGTO 222001** (8 ano EFII 2022 - codigo {AA}{F}{NNN} = 22 + 1 + 001):

```xml
<SPLANOPGTO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODPLANOPGTO>222001</CODPLANOPGTO>
  <IDPERLET>{Fase 1}</IDPERLET>
  <CODPERLET>2022</CODPERLET>
  <DESCRICAO>EFII 8 ANO 2022</DESCRICAO>
  <NOME>EFII 8 ANO 2022</NOME>
  <DTINICIO>2022-01-01T00:00:00</DTINICIO>
  <DTFIM>2022-12-31T00:00:00</DTFIM>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <DESCONTO>0</DESCONTO>
</SPLANOPGTO>
```

**SHABMODELOPGTO** (liga plano a habilitacao):

```xml
<SHABMODELOPGTO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <IDPERLET>{Fase 1}</IDPERLET>
  <CODPLANOPGTO>222001</CODPLANOPGTO>
  <IDHABILITACAOFILIAL>{Fase 2}</IDHABILITACAOFILIAL>
</SHABMODELOPGTO>
```

### Fase 6 - SCONTRATO consolidado

```xml
<SCONTRATO>
  <CODCOLIGADA>1</CODCOLIGADA>
  <CODCONTRATO>{auto}</CODCONTRATO>
  <RA>20142166</RA>
  <IDPERLET>{Fase 1}</IDPERLET>
  <IDHABILITACAOFILIAL>{Fase 2}</IDHABILITACAOFILIAL>
  <CODFILIAL>1</CODFILIAL>
  <CODTIPOCURSO>1</CODTIPOCURSO>
  <CODCFO>1645</CODCFO>
  <CODCOLCFO>1</CODCOLCFO>
  <CODPLANOPGTO>222001</CODPLANOPGTO>
  <DTCONTRATO>2021-10-21T00:00:00</DTCONTRATO>
  <DTASSINATURA>2021-10-21T00:00:00</DTASSINATURA>
  <DIAVENCIMENTO>5</DIAVENCIMENTO>
  <TIPOCONTRATO>S</TIPOCONTRATO>
  <ASSINADO>S</ASSINADO>
  <STATUS>N</STATUS>
  <DIAFIXO>N</DIAFIXO>
  <PERIODOCONTABIL>A</PERIODOCONTABIL>
</SCONTRATO>
```

**Captura:** CODCONTRATO retornado (sera usado em todas as 37 SPARCELAs).

### Fase 7 - 37 SPARCELAs

Para cada parcela, gerar:

```xml
<SPARCELA>
  <CODCOLIGADA>1</CODCOLIGADA>
  <RA>20142166</RA>
  <CODCONTRATO>{Fase 6}</CODCONTRATO>
  <IDPERLET>{Fase 1}</IDPERLET>
  <CODSERVICO>{MENS|ALIM|MAT|1aMENS}</CODSERVICO>
  <PARCELA>{1..12}</PARCELA>
  <COTA>1</COTA>
  <VALOR>{4271,00 | 890,00 | 347,00}</VALOR>
  <DTVENCIMENTO>{2022-MM-05}</DTVENCIMENTO>
  <DTCOMPETENCIA>{2022-MM-01}</DTCOMPETENCIA>
  <TIPOPARCELA>N</TIPOPARCELA>
  <VALORAUTOMATICO>S</VALORAUTOMATICO>
</SPARCELA>
```

37 chamadas SOAP em loop (pode paralelizar com pool de 5).

### Fase 8 - Bolsas

Diego nao tem bolsa em 2022. **Pular.**

### Fase 9 - Avaliacao

**Fora do escopo do piloto.** Diego ja foi aprovado em todas as 13 disciplinas no Gennera, mas vamos importar so a estrutura academica/financeira agora.

---

## Validacao pos-piloto

```javascript
// 1. SCONTRATO existe e correto
const c = await rv('EduContratoData', `SCONTRATO.RA='20142166'`);
assert((c.xml.match(/<SCONTRATO>/g) || []).length === 1);

// 2. 37 SPARCELAs criadas
const p = await rv('EduParcelaData', `SPARCELA.RA='20142166'`);
const parcelas = [...p.xml.matchAll(/<SPARCELA>([\s\S]*?)<\/SPARCELA>/g)];
assert(parcelas.length === 37);

// 3. Soma de valores
const total = parcelas.reduce((sum, t) => {
  const v = t[1].match(/<VALOR>([\d,.]+)<\/VALOR>/);
  return sum + parseFloat(v[1].replace(',', '.'));
}, 0);
assert(Math.abs(total - 70367) < 0.10);

// 4. CODCFO correto (Joselia)
const codcfo = c.xml.match(/<CODCFO>(\d+)<\/CODCFO>/);
assert(codcfo[1] === '1645');

// 5. Quantidade por servico
const porServico = {};
parcelas.forEach(t => {
  const s = t[1].match(/<CODSERVICO>(\w+)<\/CODSERVICO>/)[1];
  porServico[s] = (porServico[s] || 0) + 1;
});
assert(porServico.MENS === 12);
assert(porServico.ALIM === 12);
assert(porServico.MAT === 12);
assert(porServico['1aMENS'] === 1);
```

---

## Rollback testado

Antes de escalar, testar rollback completo:

```javascript
// 1. Apos SCONTRATO criado, deletar 1 SPARCELA, conferir que deleta limpo
await deleteRecord('EduParcelaData', IDPARCELA_TESTE);

// 2. Recriar e seguir
// 3. No final, ter capacidade de DELETAR TUDO do Diego se necessario:
await deleteRecord('EduParcelaData', ...);  // 37 vezes
await deleteRecord('EduContratoData', CODCONTRATO);
// Estrutura (SPLETIVO, SHABILITACAOFILIAL, SPLANOPGTO) mantida porque pode servir para outros
```

---

## Estimativa de tempo

| Fase | Operacoes | Tempo (serial) |
|------|-----------|----------------|
| 0 | 4 ReadViews | 30s |
| 1 | 1 SaveRecord (SPLETIVO) | 10s |
| 2 | 1 SaveRecord (SHABILITACAOFILIAL) | 10s |
| 3 | 0-3 SaveRecords (pessoas) | 30s |
| 4 | 3 SaveRecords | 30s |
| 5 | 6 SaveRecords | 1 min |
| 6 | 1 SaveRecord (SCONTRATO) | 10s |
| 7 | 37 SaveRecords (SPARCELA) | 5-10 min |
| 8 | 0 (sem bolsa) | - |
| **TOTAL** | **~55 chamadas SOAP** | **~15 min** |

Com pool de 5 paralelo: ~5 minutos.

---

## O que monitorar

1. **Latencia por SaveRecord** - target <2s
2. **Erros (fault)** - 0 tolerado
3. **Memoria RM** - se latencia subir, RM pode estar sobrecarregado
4. **Saldo conta TOTVS** - se houver limites de API por hora/dia
5. **Logs estruturados** em `data/audit/AAAA-MM-DD-piloto-diego.jsonl`

---

## Replicacao para massa

Apos Diego validado, template generico:

```javascript
async function migrarAluno(ra, anoLetivo) {
  const dados = await fetchGenneraAluno(ra, anoLetivo);

  // Fase 0: verificar SCONTRATO ja existe (idempotencia)
  const existe = await rv('EduContratoData', `SCONTRATO.RA='${ra}' AND IDPERLET=${idPerlet(anoLetivo)}`);
  if (existe.count > 0) {
    log.warn({ ra, anoLetivo, msg: 'ja migrado' });
    return;
  }

  // Fase 1-2: estrutura (usualmente ja existe, skip se ja criado)
  await ensureSPletivo(anoLetivo);
  await ensureSHabilitacaoFilial(dados.curso, dados.habilitacao, dados.filial, anoLetivo);

  // Fase 3: pessoas
  await ensurePPessoa(dados.aluno);
  await ensureFCFO(dados.responsavelFinanceiro);

  // Fase 4: vinculos
  await ensureSHabilitacaoAluno(ra, dados.idHabilitacaoFilial);
  await ensureSMatricula(ra, dados.idPerlet, dados.turma);
  await ensureSMatricPL(ra, dados.codPlanoPgto);

  // Fase 5: plano
  await ensureSPlanoPgto(dados.ano, dados.filial, dados.habilitacao);
  await ensureSHabModeloPgto(dados.codPlanoPgto, dados.idHabilitacaoFilial);

  // Fase 6: SCONTRATO
  const codContrato = await criarSContrato(ra, dados);

  // Fase 7: SPARCELAs (paralelo)
  await Promise.all(dados.parcelas.map(p =>
    criarSParcela(codContrato, ra, p)
  ));

  // Fase 8: bolsas (se houver)
  if (dados.bolsas?.length) {
    await Promise.all(dados.bolsas.map(b =>
      criarSBolsaAluno(ra, codContrato, b)
    ));
  }

  // Validacao
  await validar(ra, dados);
}
```

Para 14k alunos: pool 5 conexoes simultaneas, paginado por turma. Estimativa 6 dias.

---

## Referencias

- `knowledge/fluxo/02_regras_transformacao.md` - regras de conversao
- `knowledge/fluxo/03_ordem_importacao.md` - fases
- `knowledge/fluxo/04_validacoes_cross_system.md` - validacoes
- `knowledge/totvs/07_exemplos_xml_saverecord.md` - templates XML detalhados
