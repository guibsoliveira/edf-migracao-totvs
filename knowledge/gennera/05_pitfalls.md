# 05 - Pitfalls Criticos Gennera

## 1. LATIN1 Encoding e Word Boundary

Problema: PostgreSQL com encoding LATIN1 + locale PT-BR quebra regex com `\m` quando encontra caracteres acentuados ou ordinal "o".

Sintoma: Query falha ou retorna resultados inesperados

Solucao:
1. SEMPRE usar PGCLIENTENCODING=LATIN1 ao conectar
2. Evitar regex word boundary com caracteres especiais
3. Usar: `1[^[:space:]]{0,3}\s*(PARC|MENS)` em vez de `\m1.*PARC\M`
4. Ou: fazer UPPER() antes do match

Comando correto:
PGCLIENTENCODING=LATIN1 PGPASSWORD=$DB_PASS "/c/Program Files/PostgreSQL/18/bin/psql.exe" -h $DB_HOST -U $DB_USER -d Edf_bd_legado -c "SELECT ..."
# Credenciais em CLAUDE.local.md (gitignored)

---

## 2. Valores Monetarios BRL

Problema: Banco armazena valores em formato BRL: "$1.234,56"
- $ = prefixo de moeda
- . = separador de milhares
- , = separador de decimais

Conversao ingenua falha. Solucao:
REPLACE(REPLACE(REPLACE(valor_bruto, '$', ''), '.', ''), ',', '.')::numeric

Resultado: 1234.56 (tipo numeric)

---

## 3. Datas Heterogeneas

Formatos encontrados:
- ISO 8601: 2025-01-15 (em date)
- BR text: 15/01/2025 (em varchar)
- Timestamp ISO: 2025-01-15T10:30:00Z (em API)
- String ano: 2025 (em academic_calendar)

Necessario detectar formato via regex e converter para ISO 8601 ou date.

---

## 4. Campos camelCase (API) vs snake_case (Banco)

API REST Gennera retorna JSON camelCase.
Banco PostgreSQL usa snake_case.

Ao fazer JOINs entre API e banco, mapear explicitamente.
Usar alias em SELECT para documentar mapping.

---

## 5. id_person Namespacing (Banco local vs API global)

PROBLEMA CRITICO:
- Banco (gennera_stg): id_person local por instituicao (1-9173 em UN1)
- API Gennera: id_person global (355k-3M)
- servicos_historico: Usa namespacing API (355k-3M)

NAO pode fazer JOIN direto entre servicos_historico.id_pessoa e person_fisica.id_person

Solucao: Usar person_cpf_mapping como chave intermediaria (CPF)

---

## 6. Dados 2018-2019 com id_pessoa vazio

Algumas linhas em servicos_historico (2018-2019) tem id_pessoa = '' (string vazia).
Nao podem ser JOINs.

Solucao: Filtrar no WHERE com id_pessoa != ''
Ou validar com aluno/responsavel via outros campos (nome, data nascimento)

---

## 7. invoice.year = 5021 (Typo 2021)

12 linhas em invoice tem year = 5021 (provavelmente typo para 2021).
Total: ~R$ 41k afetado.

Deteccao:
SELECT id_invoice, year, total FROM invoice
WHERE year NOT IN (2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025);

Solucao: Corrigir manualmente ou em lote, confirmando com usuario final.

---

## 8. invoice.year = 2032 (Futuro)

1 linha em invoice tem year = 2032 (futuro impossivel).

Solucao: Investigar manualmente. Pode ser typo (2022?) ou erro de entrada.

---

## 9. Dados 2026 no Banco Sao Incompletos

- enrollment tabela 2026: VAZIO
- servicos_historico 2026: 662 linhas SEM enrollment correspondente

Para qualquer consulta sobre 2026, USE API LIVE, nao banco.

---

## 10. Pessoas sem CPF (48%)

4.389 de 9.166 (48%) em person_fisica tem cpf = NULL ou vazio.

Razao: Menores de idade ainda nao emitiram CPF.

TOTVS RM pode exigir CPF em SPESSOA ou SALUNO.

Solucao:
1. Usar CPF do responsavel financeiro (via enrollment_contract)
2. Gerar CPF temporario (formato 00.000.000/0001-XX para menores)
3. Validar com LGPD/juridico da EDF

---

## 11. Bandeiras de Cartao: Visa, MasterCard, Elo, AmEx

payment.payment_method pode conter varias bandeiras (216+ paises com recorrencia).

Se precisar rastrear tentativas recusadas por bandeira:
- Dados disponivel: gatewayTransactions na API (ultimo resultado)
- Dados NAO disponivel: tentativas recusadas (codigo 05, 96)

---

## 12. Contaminacao de mode() por Parcelamento

Campo mode() em servicos_historico pode estar contaminado por parcelamentos.

SEMPRE validar contra servicos.DescBolsas

---

## 13. Ordinal "o" nao eh letra "o"

Em LATIN1, o caractere ordinal 'º' (U+00BA) nao eh letra em regex PT-BR.

Solucao:
1. Remover diacriticos: SELECT * FROM class WHERE unaccent(name) ~ 'Ano Letivo';
2. Ou comparar explicitamente: UPPER(name) LIKE '%1O %' OR UPPER(name) LIKE '%1º %'

---

## 14. Recorrencia lastCharge Guarda Somente Ultima Tentativa

Campo recurringPayment.lastCharge na API guarda APENAS ultima tentativa.
Nao guarda historico de tentativas anteriores.

Se precisar historico: Contatar suporte Gennera para export XLSX

---

## 15. gatewayTransactions Nao Inclui Tentativas Recusadas

PROBLEMA CRITICO: Tentativas recusadas pelo emissor (codigo 05, 96) NAO sao expostas.

Solucao:
1. Exportar XLSX do painel admin Gennera
2. Implementar webhook customizado (se disponivel)
3. Documentar gap na migracao

---

## 16. Calendarios em String vs Int

Algumas tabelas usam string para ano: academic_calendar (string "2025")
Outras usam int: fatura_ano (int 2025)

Nao pode fazer JOIN direto sem CAST.

Solucao: CAST(academic_calendar AS int) = fatura_ano

---

## 17. Tipografia em Nomes de Campos

Alguns campos tem espacos no nome (incomum em SQL):
servicos_2018_2019: " Contrato", " Data de Vencimento", " Item"
(note o espaco no inicio)

Solucao:
1. Validar com \d servicos_2018_2019 para listar campos exatos
2. Usar quotes duplas: SELECT " Contrato" FROM servicos_2018_2019;
3. Renomear em views se for usar em JOIN complexo

---

## 18. Valores Null vs String Vazia

Alguns campos podem estar como NULL, outros como string vazia ''.

Solucao: Ser explicito
WHERE COALESCE(cpf, '') NOT IN ('', NULL)

---

## 19. Alunos Menores de Idade Com Dados Sensiveis (LGPD)

person_fisica contem nomes e enderecos de menores de idade.

Qualquer export precisa cumprir LGPD.

Solucao:
1. Nao exportar para servicos externos
2. Anonimizar dados antes de salvar em relatorios
3. Documentar em auditoria se manipular em massa
4. Notificar Guilherme se descobrir vazamento
