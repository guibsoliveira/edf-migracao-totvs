# 04 - Regras de Negocio Gennera

## RA (Registro de Aluno) - CANONICO

Formato: YYYYNNNNNN (10 digitos)
- YYYY: ano de matricula (2021, 2022, ..., 2025)
- NNNNNN: numero sequencial (6 digitos, zero-padded)

Exemplo: 20211234567 = aluno matriculado em 2021, numero 1234567

Fonte Unica da Verdade: tabela student_code_unico.code_unif
(nao usar enrollment.code que pode estar vazio ou inconsistente)

Exposicao:
- Banco: gennera_stg.student_code_unico
- API: GET /institutions/{id}/persons -> studentCode
- TOTVS RM: Campo RAMAT em SMATRICULA

---

## Status de Contrato

Estados observados:
- active: Contrato vigente, pode gerar parcelas
- cancelled: Cancelado (pode ter parcelas em aberto)
- pending: Aguardando ativacao (raro)

Implicacoes:
- Contratos cancelled ainda geram relatorio de saldo devedor
- Nao ha vencimento automatico
- Cancelamento pode ser total ou parcial (por servico)

---

## Servicos por Contrato (1:N logico)

Servicos padrao:
- REMATRIC: Taxa de rematricula anual
- MENS: Mensalidade escolar (12 parcelas/ano)
- ALIM: Servico de alimentacao (12 parcelas/ano)
- MAT: Material escolar/uniforme (variavel)

Regra: 1 aluno tem 1 contrato POR SERVICO
Um aluno tipicamente tem 4 contratos (REMATRIC, MENS, ALIM, MAT)

Consolidacao eh LOGICA (em SQL), nao fisica no banco.
Granularidade de armazenamento: 1 linha = 1 contrato

---

## Status de Pagamento

Estados:
- paid: Pagamento processado (credito recebido)
- cancelled: Pagamento cancelado/devolvido (recusado)
- pending: Aguardando processamento (D+30 ou D+45 normal, NAO erro)

INTERPRETACAO CRITICA de pending:
- NAO significa erro
- Significa que boleto foi gerado e prazo de credito nao venceu
- Tipicamente D+30 pos-emissao
- Isso eh NORMAL

Deteccao de Erro Real (recusado):
- Codigos de resultado: 05, 96 (emissor recusou)
- NAO APARECEM NA API REST (gap critico)
- Ficam apenas no painel admin Gennera
- Workaround: exportar XLSX do painel

---

## Recorrencia (recurringPayment na API)

Estrutura: active, retryCount, maxRetries, lastCharge

Interpretacao:
- active=true: Sistema tentara cobrar novamente automaticamente
- retryCount: Quantas tentativas ja foram feitas
- maxRetries: Limite de tentativas permitidas
- lastCharge: Data/hora da ultima tentativa

Banco vs API:
- Banco (gennera_stg): recurringPayment NAO EXISTE
- API: Campo completo recurringPayment

Se precisar rastrear recorrencia em 2026, DEVE vir da API, nao do banco.

---

## Competencia (Mes/Ano de Faturamento)

Formato no banco:
- servicos_historico.fatura_mes (int 1-12)
- servicos_historico.fatura_ano (int 2018-2025)

Formato na API:
- Embedded em invoice: month (1-12) + year (int) + dueDate (ISO)

Conversao: Mes/ano + dia de vencimento = data ISO

Periodicidade:
- Mensal (1 fatura/mes) para MENS, ALIM
- Anual (1 fatura/ano) para REMATRIC
- Variavel para MAT

---

## Bolsas e Descontos

UNICA fonte de verdade: servicos.DescBolsas (545 linhas)

Estrutura:
- servicos.DescBolsas = valor numerico de desconto
- servicos_historico.valor_descontos = agregado (pode incluir outros)

Pitfall: Contaminacao por Parcelamento
- Campo mode() em servicos_historico pode estar contaminado
- SEMPRE validar contra servicos.DescBolsas

Aplicacao: Desconto eh POR PARCELA, nao por contrato
Uma bolsa de R$ 100/mes = 12 parcelas de MENS com R$ 100 desconto cada

---

## Calendarios Academicos

Formato no banco: String "2021", "2022", ..., "2025"

Significado: Ano letivo (nao calendar civil)
Pode nao corresponder exatamente ao ano civil

Na API: Estrutura completa de periodo
- academicCalendarName
- academicCalendarCode
- academicCalendarStartDate (ISO)
- academicCalendarEndDate (ISO)

Uso em Migracao:
- TOTVS RM espera IDPERLET (id do periodo letivo)
- Mapping necessario: ano Gennera -> IDPERLET RM
- Confirmados: 2023->15, 2024->18/19, 2026->1/2 (testes)
- 2022: NAO EXISTE no RM (precisa criar SPLETIVO se migrar dados 2022)

---

## Multi-Instituicao (Filial)

Identificacao:
- idInstitution 320 = UN1 (Unidade I)
- idInstitution 321 = UN2 (Unidade II)
- idInstitution 873 = ambiente de teste

Regra de Filial:
- Pessoas sao INDEPENDENTES por instituicao
- Uma pessoa pode existir em ambas

id_person Namespacing:
- Banco local (gennera_stg): id_person eh LOCAL por instituicao (1-9173 em UN1)
- API Gennera: id_person eh GLOBAL (355k-3M)
- servicos_historico.id_pessoa: Segue namespacing API (355k-3M)

AVISO: NAO pode fazer JOIN direto entre servicos_historico.id_pessoa e person_fisica.id_person
Necessario ir pela API ou usar pessoa_cpf_mapping como chave intermediaria

---

## Anos e Cortes de Dados

Cobertura:
- 2018-2019: Banco incompleto, validar com API
- 2020-2025: Banco completo e API disponivel
- 2026: Banco vazio, USE API EXCLUSIVAMENTE

Pitfall: Dados 2026 no Banco
- 125.849 linhas em servicos_historico incluem 662 linhas de 2026 SEM enrollment
- Origem: provavelmente dados pre-gerados
- NAO confiar nessas 662 linhas

Pitfall: Anos Estranhos
- invoice.year = 5021: Typo para 2021 (12 linhas, R$ 41k)
- invoice.year = 2032: Futuro? (1 linha, verificar manualmente)

---

## Pessoas sem CPF

Escala: 4.389 de 9.166 (48%) SEM CPF

Motivo: Menores podem nao ter CPF ainda (dependem de responsavel)

Implicacao para Migracao:
- TOTVS RM pode exigir CPF
- Solucao: usar CPF do responsavel financeiro ou gerar CPF temporario
- Validacao com LGPD necessaria

---

## Encoding e Conversao de Valores

LATIN1 em PostgreSQL:
- OBRIGATORIO: PGCLIENTENCODING=LATIN1 em todo acesso psql
- Pitfall: word boundary regex com o ordinal em locale PT-BR

Valores Monetarios (BRL):
- Formato fonte: ".234,56" (ponto=milhar, virgula=decimal)
- Conversao: REPLACE(REPLACE(REPLACE(v, '$', ''), '.', ''), ',', '.')::numeric
- Resultado: 1234.56 (numeric)
- Re-exibir em BR: TO_CHAR(valor, '9.999,99')

Datas Heterogeneas:
- ISO: "2025-01-15"
- BR: "15/01/2025"
- Timestamp: "2025-01-15T10:30:00Z"
- Detectar por padrao regex e normalizar para ISO 8601 em TOTVS RM

---

## Pessoas Estrangeiras

Tabela: person_estrangeiro (rara)

Campos alternativos:
- passport, nationality, national_migration_registry em vez de CPF/RG

Uso: Alunos/responsaveis internacionais (ex: pais que trabalham para ONG)
