# Base de Conhecimento Gennera - README

Criado: 2026-05-19
Versao: 1.0
Proposito: Referencia persistente sobre o sistema Gennera (origem migracao TOTVS RM)

---

## Como Usar Esta Base

### Para entender a ARQUITETURA geral:
Leia `01_arquitetura.md`
- O que é Gennera
- Por que estamos saindo
- Hierarquia de dados
- Entidades principais

### Para fazer chamadas A API:
Leia `02_api_endpoints.md`
- Autenticacao com JWT
- Catalogo de endpoints confirmados
- Exemplos curl
- Endpoints que NAO existem

### Para conhecer as TABELAS do banco:
Leia `03_modelo_dados.md`
- 57 tabelas do schema gennera_stg
- Chaves primarias e estrangeiras
- Contagens de linhas
- Diagrama de relacionamentos

### Para implementar REGRAS DE NEGOCIO:
Leia `04_regras_negocio.md`
- RA canonico (YYYYNNNNNN)
- Status de contrato/pagamento
- Servicos por aluno (1:N)
- Bolsas e descontos
- Calendarios academicos
- Multi-instituicao (320=UN1, 321=UN2)

### Para evitar ERROS COMUNS:
Leia `05_pitfalls.md`
- LATIN1 encoding word boundary
- Valores BRL com formato "$1.234,56"
- Datas heterogeneas
- id_person namespacing (banco vs API)
- Dados 2026 incompletos
- 48% sem CPF
- Tentativas recusadas nao expostas

### Para contornar LIMITACOES da API:
Leia `06_limitacoes_api.md`
- Tentativas recusadas nao aparecem na API
- Endpoint /invoices precisa parametro desconhecido
- Sem paginacao
- Sem batch requests
- recurringPayment nao tem historico

---

## Dados de Referencia Rapida

### Instituicoes
- 320 = UN1 (Unidade I)
- 321 = UN2 (Unidade II)
- 873 = teste

### Contagens (conforme banco dez/2025)
- Pessoas: 9.166
- Matriculas: 3.290
- Contratos: 13.283
- Parcelas/invoices: 99.408
- Pagamentos: 63.266
- Linhas servicos_historico: 125.849

### Periodos cobertos
- Banco: 2018-2025 (cutoff dez/2025)
- API: Inclui 2026 (dados vivos)

### Acessos (paralelos)
- PostgreSQL gennera_stg: 192.168.1.91:5432 (LATIN1)
- API Gennera: api2.gennera.com.br (JWT header)

---

## Descobertas Importantes

### Gaps Criticos
1. Tentativas de cobranca recusadas NAO aparecem na API (ficam no painel admin)
2. Dados 2026 no banco sao incompletos; usar API live
3. 48% das pessoas nao tem CPF (sao menores de idade)
4. ID person namespaced diferente: banco local (1-9173) vs API global (355k-3M)

### Pitfalls Frequentes
1. Usar PGCLIENTENCODING=LATIN1 em QUALQUER psql
2. Valores BRL com formato "$1.234,56" requerem conversao
3. 12 invoices com year=5021 (typo para 2021)
4. Nao fazer JOIN direto entre servicos_historico e person_fisica

### Oportunidades
1. recurringPayment e gatewayTransactions SO via API (nao no banco)
2. RA canonico em student_code_unico.code_unif (fonte unica verdade)
3. API tem 8 endpoints confirmados, cobertura ~95% funcional

---

## Manutencao Desta Base

### Se descobrir nova informacao:
1. Atualizar arquivo relevante
2. Manter estrutura markdown consistente
3. Nao adicionar PII (CPF real, nome de aluno, email)
4. Documenter data de descoberta em comentario

### Se API mudar:
1. Testar novamente com novo JWT
2. Atualizar 02_api_endpoints.md com novos endpoints
3. Notar mudancas no git

### Se encontrar ERRO em qualquer arquivo:
1. Corrigir na sessao corrente
2. Notificar Guilherme se for descoberta importante

---

## Seguranca

Nenhum arquivo contem:
- JWT inteiros
- Senhas ou credenciais
- CPF de pessoas individuais
- Nomes de alunos reais
- Dados sensiveis nao-anonimizados

Estes arquivos podem ser compartilhados com equipe tecnica.

---

## Referencia Cruzada

Se tiver duvida sobre X:
- "Qual eh o RA do aluno?" -> Ver 04_regras_negocio.md secao RA
- "Como faço call na API?" -> Ver 02_api_endpoints.md
- "Por que falha LATIN1?" -> Ver 05_pitfalls.md secao 1
- "Qual eh a tabela X?" -> Ver 03_modelo_dados.md
- "Pode fazer requisicao em batch?" -> Ver 06_limitacoes_api.md secao 14

---

Boa sorte na migracao!
