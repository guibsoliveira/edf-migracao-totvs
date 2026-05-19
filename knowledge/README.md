# Knowledge Base - Migracao Gennera -> TOTVS RM

> Conhecimento PROFUNDO e ESTRUTURADO dos dois sistemas. Esta pasta e a fonte
> primaria que a IA deve consultar antes de qualquer trabalho serio com
> Gennera ou TOTVS RM.
>
> Memorias persistentes (em ~/.claude/projects/.../memory/) contem REGRAS
> curtas. Esta pasta contem REFERENCIA detalhada.

---

## Estrutura

```
knowledge/
  gennera/           - Tudo sobre o sistema origem (Gennera)
    01_arquitetura.md       - visao geral, modulos, hierarquia
    02_api_endpoints.md     - catalogo completo de endpoints REST
    03_modelo_dados.md      - tabelas/entidades, FKs, relacionamentos
    04_regras_negocio.md    - regras que o sistema impoe
    05_pitfalls.md          - armadilhas conhecidas
    06_limitacoes_api.md    - o que NAO esta exposto

  totvs/             - Tudo sobre o sistema destino (TOTVS RM Educacional)
    01_arquitetura.md       - RM modulos, hierarquia academica + financeira
    02_api_soap_tbc.md      - WSDL, DataServers Edu*, soapActions
    03_modelo_dados.md      - tabelas SXxx, FKs, hierarquia
    04_regras_negocio.md    - regras que o RM impoe (IDPERLET, IDHABILITACAOFILIAL)
    05_pitfalls.md          - armadilhas (CODSISTEMA=S, filtro perfil)
    06_estado_atual.md      - o que esta cadastrado hoje na HOMOLOG

  fluxo/             - Mapeamento Gennera <-> TOTVS e regras de transformacao
    01_mapeamento_entidades.md    - de para entidade por entidade
    02_regras_transformacao.md    - encoding, formato, datas, valores
    03_ordem_importacao.md        - sequencia e dependencias FK
    04_validacoes.md              - cross-checks antes/depois
```

## Como usar

**A IA deve:**
1. Ao iniciar trabalho com Gennera: `Read knowledge/gennera/*.md` (ou o subset relevante)
2. Ao iniciar trabalho com TOTVS: `Read knowledge/totvs/*.md`
3. Ao planejar fluxo de migracao: `Read knowledge/fluxo/*.md`
4. Atualizar os arquivos sempre que descobrir algo NOVO sobre um dos sistemas
5. Memoria persistente (memory/) recebe apenas APONTADORES curtos para essa pasta

**Voce (humano) deve:**
- Corrigir/anotar nos arquivos quando vir IA dizer algo errado
- Tratar essa pasta como referencia viva, nao documentacao estatica

---

## Status atual

| Documento | Status | Atualizado em |
|-----------|--------|---------------|
| gennera/* | em construcao (agente especialista populando) | - |
| totvs/* | em construcao (agente especialista populando) | - |
| fluxo/* | aguarda gennera + totvs prontos | - |
