# 99 - Perguntas Pendentes / Decisoes Necessarias

> Lacunas que o agente Ponte identificou e que precisam ser resolvidas
> antes de escalar a migracao do Diego para producao em massa.

---

## CRITICAS (bloqueiam piloto)

### 1. Bug `export_v2.sparcela` perde ALIM/MAT

**Status:** confirmado bug em sessao anterior. View retorna so MENS, perdendo ALIM e MAT.
**Impacto:** sem isso, Fase 7 (SPARCELAs) gera so 12 de 37 parcelas do Diego.
**Acao:** investigar a view, corrigir, reaplicar. Idealmente o agente Isac sabe disso.

### 2. SPLETIVO 2022 confirmado nao existe em RM HOMOLOG

**Status:** confirmado por ReadView (somente 2023=15, 2024=18/19, 2026=1/2 existem).
**Impacto:** sem SPLETIVO 2022, nenhuma entidade 2022 pode ser criada.
**Acao:** primeira chamada Fase 1 deve ser SaveRecord(EduPLetivoData) para criar 2022.

### 3. Filtro de perfil bloqueia leitura de SCURSO, SHABILITACAO, SGRADE etc.

**Status:** confirmado. Cadastros mestres retornam count=0 mesmo existindo.
**Impacto:** nao consigo VERIFICAR pelo API que EF2 e habilitacao 8 existem. Tenho que confiar na UI.
**Acao:**
- Opcao A: consultor TOTVS configurar parametros do Educacional para `goliveira` no perfil RM
- Opcao B: criar usuario tecnico `api_migracao@escoladofuturo.com.br` com perfil sem filtro
- Opcao C: confiar na UI e testar SaveRecord (escrita pode nao ter o mesmo filtro)

---

## ALTAS (impactam decisao de fluxo)

### 4. SaveRecord nao foi testado ainda

**Status:** so testamos ReadView. Nunca chamamos SaveRecord ate hoje.
**Impacto:** se SaveRecord tiver o mesmo filtro de perfil ou validacoes nao previstas, todo o plano trava.
**Acao:** **TESTE PILOTO: 1 SaveRecord de teste em entidade descartavel** (SPLETIVO 2022 ou SPLANOPGTO de teste) para validar antes de seguir com o Diego inteiro.

### 5. FCFO Joselia existe?

**Status:** Joselia tem `codcfo=1645` no Gennera (snapshot da tabela `cliente_fornecedor`). Mas nao confirmei que esse CODCFO existe DE VERDADE no FCFO do TOTVS HOMOLOG.
**Impacto:** se nao existir, SCONTRATO falhara com ORA-02291 (FK violation).
**Acao:** ReadView de EduResponsavelData com filtro CGCCFO Joselia, ou pedir confirmacao via UI.

### 6. Throughput e timeout do SOAP

**Status:** desconhecido. Nao testamos com SaveRecord ainda.
**Impacto:** se latencia for >5s por SaveRecord, 37 SPARCELAs do Diego levam 3+ min. Para 14k alunos, dias.
**Acao:** medir empiricamente no piloto, planejar paralelismo (pool 5 conexoes).

---

## MEDIAS (otimizacao / pos-piloto)

### 7. FLAN/SLAN: geracao automatica ou manual?

**Status:** assumimos que RM gera automaticamente apos SaveRecord SPARCELA. NAO confirmado.
**Impacto:** se nao gera, precisamos chamar `wsFin.SaveLancamento` explicitamente.
**Acao:** apos piloto Fase 7, conferir se FLAN e SLAN aparecem automaticamente.

### 8. Decisao FCFO obrigatorio?

**Status:** consultor TOTVS sugeriu pular FCFO (manter CODCFO=1 default), mas nao testamos.
**Impacto:** se obrigatorio, todas as 9k pessoas Gennera viram FCFOs. Se opcional, simplifica.
**Acao:** discussao com consultor + teste.

### 9. Pessoas sem CPF (48%) - politica

**Status:** definicao pendente. 4.389 pessoas (48%) nao tem CPF no Gennera.
**Impacto:** TOTVS pode exigir CPF para criar PPESSOA. 3 opcoes:
- A: usar CPF do responsavel financeiro
- B: gerar CPF temporario `99{idPerson}{checkdigit}`
- C: bloquear migracao sem CPF
**Acao:** decisao do financeiro EDF (Ailton).

### 10. invoice.year=5021 (typo 2021)

**Status:** 12 linhas no banco com year=5021, R$ 41k.
**Impacto:** se nao tratar, parcelas com data invalida geram erro no RM.
**Acao:** `CASE WHEN year=5021 THEN 2021` na view de migracao.

---

## BAIXAS (depois)

### 11. SPARCPLANO importar ou pular?

Consultor TOTVS sugeriu pular. Mantemos a view por baixo custo, mas decidir se gera SaveRecord ou nao.

### 12. Mapeamento de disciplinas Gennera (numerico) -> TOTVS (texto 4 chars)

Tabela de equivalencia precisa ser criada. So fica critico se importar SDISCGRADE, SMATRICPL com disciplina detalhada.

### 13. Avaliacao (notas, frequencia, provas) - escopo

Volume gigante (796k notas, 296k frequencias). Fora do piloto inicial. Decidir se entra em segundo round ou fica.

### 14. SDOCALUNO (documentos exigidos)

Tabela existe mas nao mapeada. Fora do escopo inicial.

---

## Acoes para o usuario (Guilherme)

| Pergunta | Recomendado |
|----------|-------------|
| Configurar perfil `goliveira` no RM ou criar usuario tecnico? | **B (usuario tecnico)** - melhor pratica |
| FCFO obrigatorio? | Confirmar com consultor TOTVS |
| Politica para sem-CPF (48%) | Discutir com Ailton (financeiro) |
| Bug `export_v2.sparcela` | Falar com Isac |
| SPLETIVO 2022 criar agora? | Sim, ja na proxima sessao de piloto |
| Teste SaveRecord descartavel antes do Diego? | **SIM** - recomendado obrigatoriamente |

---

## Status para liberar Diego em producao

- [ ] Bug sparcela_v2 corrigido OU contorno feito
- [ ] Teste SaveRecord descartavel OK
- [ ] FCFO Joselia confirmado existente
- [ ] SPLETIVO 2022 criado e IDPERLET capturado
- [ ] Plano de rollback testado
- [ ] Aprovacao Ailton para política sem-CPF (Diego tem CPF, mas para futuro)
- [ ] Latencia SaveRecord medida (target <2s)

Quando todos `[x]`, Diego entra em producao no HOMOLOG. Validar tudo. Soh entao escalar para massa.
