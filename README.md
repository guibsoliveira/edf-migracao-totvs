# EDF — Migração Gennera → TOTVS RM

Projeto de migração de dados do sistema legado **Gennera** para o **TOTVS RM Educacional** da **Escola do Futuro (EDF)**.

O trabalho consiste em criar views PostgreSQL no schema `export` que transformam dados do schema `gennera_stg` para o formato esperado pelo importador TOTVS RM.

---

## Estrutura do Repositório

```
edf-migracao-totvs/
├── views/
│   ├── financeiro/     # Views do módulo financeiro (SSERVICO, SBOLSA, SPLANOPGTO, etc.)
│   ├── academico/      # Views do módulo acadêmico (SETAPAS, SPROVAS)
│   └── debug/          # Queries auxiliares de depuração
├── docs/               # Relatórios e documentação do projeto
├── scripts/            # Scripts utilitários (Python, SQL)
├── data/               # CSVs de qualidade cadastral
└── reference/          # Schema fonte, dump de views, nomes de referência
```

---

## Banco de Dados

| Parâmetro | Valor |
|-----------|-------|
| Database | `Edf_bd_legado` |
| Schema origem | `gennera_stg` (54 tabelas) |
| Schema destino | `export` (views no formato TOTVS) |
| Encoding | LATIN1 |

> Credenciais configuradas via variáveis de ambiente. Ver `CLAUDE.md` para detalhes.

---

## Views Financeiras

| Ordem | View | Status |
|-------|------|--------|
| 37 | SBOLSA | Aplicada |
| 37b | SBOLSAPLETIVO | Aplicada |
| 38 | SSERVICO | Aplicada |
| 39 | SPLANOPGTO | Aplicada |
| 40 | SPARCPLANO | Aplicada (descontinuada — SPARCELA substitui) |
| 41 | SHABMODELOPGTO | Aplicada |
| 42 | SCONTRATO | Em andamento |
| 43 | SPARCELA | Em andamento |
| 44 | SBOLSAALUNO | Em andamento |
| 45 | SLAN | Em andamento |
| 46 | FLAN | Em andamento (correção de cobertura) |

---

## Responsável

**Guilherme Oliveira** — [github.com/guibsoliveira](https://github.com/guibsoliveira)
