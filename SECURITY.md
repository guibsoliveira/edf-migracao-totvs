# Guardrails de Seguranca - Migracao Gennera -> TOTVS RM

> Este arquivo define regras OBRIGATORIAS para qualquer agente de IA, script
> ou colaborador trabalhando neste projeto. As regras se aplicam SEM EXCECAO.
> Em duvida, ESCALAR para o responsavel (Guilherme) antes de agir.

---

## 1. Dados sensiveis tratados neste projeto

Este projeto manipula simultaneamente:

| Categoria | Exemplos | Risco |
|-----------|----------|-------|
| Credenciais infra | senha PostgreSQL, senha TOTVS, JWT Gennera, basic auth gateway | Acesso indevido ao banco/RM/gateway |
| Dados pessoais (LGPD) | CPF/CNPJ dos responsaveis, nome dos alunos menores de idade, telefone, e-mail, endereco | Notificacao a ANPD em caso de vazamento |
| Dados financeiros | valores de mensalidade, bolsas, descontos individuais, status de inadimplencia | Reputacional + LGPD agravado |
| Identificadores internos | RA, CODCONTRATO, IDPERLET, IDHABILITACAOFILIAL | Pivotacao para outros dados |

**Premissa:** qualquer um desses isoladamente NAO pode aparecer em log, output,
commit, mensagem externa ou arquivo nao-criptografado fora do banco origem.

---

## 2. Regras NUNCA (proibidas em qualquer hipotese)

1. **NUNCA** commitar arquivos contendo:
   - Senha em plaintext (regex: `(senha|password|pass|pwd|secret|token)\s*[:=]\s*['"]?[A-Za-z0-9!@#$%^&*]{4,}`)
   - JWT (regex: `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`)
   - Basic Auth em URL (regex: `https?://[^:]+:[^@]+@`)
   - Connection string com senha (regex: `(postgres|mysql|jdbc):.*:[^@]+@`)
2. **NUNCA** imprimir credencial no terminal/log/output da IA. Mascarar sempre:
   - Senhas: `********` (sem revelar comprimento)
   - JWT: primeiros 8 chars + `...` + ultimos 4
   - CPF: `XXX.XXX.XXX-XX` no log; preservar so para queries
3. **NUNCA** enviar dados de alunos/responsaveis para servicos externos
   nao-whitelistados (ver secao 4). Web search, pastebin, gist, diagrama
   online, LLM externo (ChatGPT/Gemini) - PROIBIDO.
4. **NUNCA** executar `psql --command="..."` com a senha inline na URL ou
   parametro. Sempre via `PGPASSWORD` ambiente.
5. **NUNCA** usar `rejectUnauthorized: false` em chamada HTTPS para a TOTVS
   ou Gennera - certificados sao validos, bypass mascara MITM.
6. **NUNCA** deletar/truncar tabelas em `gennera_stg` (fonte unica de verdade).
7. **NUNCA** rodar comando destrutivo em `export`/`export_v2` sem confirmar
   com o usuario, mesmo que pareca obvio (DROP, TRUNCATE, DELETE sem WHERE).
8. **NUNCA** importar para o RM de PRODUCAO sem autorizacao explicita da
   sessao corrente. Default: pilotos vao para ambiente de teste.
9. **NUNCA** salvar credencial em `MEMORY.md` ou em qualquer memoria
   persistente. Memoria pode ser inspecionada em sessoes futuras por
   instancias da IA - tratar como semi-publica.
10. **NUNCA** anexar exports CSV/XLSX com nomes+CPF+valores a issues do
    GitHub, comentarios em PR, mensagens em canais publicos.

---

## 3. Regras SEMPRE (obrigatorias)

1. **SEMPRE** ler credenciais de variavel de ambiente. Em scripts Node/Python:
   ```js
   const USER = process.env.TOTVS_USER;
   if (!USER) { console.error('TOTVS_USER nao definido'); process.exit(1); }
   ```
2. **SEMPRE** manter `CLAUDE.local.md` no `.gitignore` (ja esta). Conferir
   `git status` antes de cada commit - se aparecer `CLAUDE.local.md` no
   staging, ABORTAR.
3. **SEMPRE** que gerar arquivo de export (CSV/TXT/XML) com dados pessoais:
   - Colocar em `data/exportacoes/AAAA-MM-DD/` (ja no gitignore)
   - NUNCA em `docs/` ou raiz
   - Renomear/deletar apos uso
4. **SEMPRE** que abrir conexao a banco/API, fechar explicitamente ao final.
5. **SEMPRE** validar input ANTES de injetar em SQL. Para queries dinamicas,
   usar `psql -v VAR=VALUE` ou parametros bind, NUNCA concatenacao string.
   Especialmente: dados vindos de planilha do cliente.
6. **SEMPRE** preferir `wsDataServer.SaveRecord(XML)` a `\copy` ou TXT
   posicional quando importar para o RM - validacao server-side reduz
   superficie de erro silencioso.
7. **SEMPRE** registrar no commit message quando manipular dados pessoais
   em massa (ex.: "gera lista de responsaveis para mensageria") para
   rastreabilidade LGPD.
8. **SEMPRE** rodar healthcheck pos-importacao: contagem, FK orphans,
   zero-value rows. Resultado anomalo = parar e investigar.

---

## 4. Whitelist de hosts externos permitidos

So estas origens/destinos sao autorizadas para troca de dados:

| Host | Uso autorizado | Direcao |
|------|----------------|---------|
| `192.168.1.91:5432` | PostgreSQL EDF | leitura/escrita |
| `associacaoescola200767.rm.cloudtotvs.com.br:10207` | TOTVS RM WS TBC | leitura/escrita |
| `api2.gennera.com.br` | API REST Gennera (JWT) | leitura |
| `cloudtotvs.com.br` (cert raiz) | TLS | - |
| `docs.google.com` (planilha controle) | template TOTVS | leitura humana |

**Tudo o que nao esta nessa lista exige aprovacao explicita.** Inclusive:
APIs publicas de tradutor, encurtador, IA externa, viewer XML, etc.

---

## 5. Rotacao de credenciais (gatilhos)

Trocar imediatamente se:
- Credencial apareceu em saida visivel (terminal, log, screenshot, chat)
- Credencial foi escrita em arquivo fora do escopo (qualquer lugar fora
  de `CLAUDE.local.md` e variaveis de ambiente)
- Commit acidental contendo credencial - rotacionar mesmo apos `git filter-branch`,
  pois o blob fica no reflog
- Acesso de pessoa que deixou o projeto
- A cada 90 dias para credencial de PRODUCAO

Procedimento:
1. TOTVS: solicitar troca via consultor/portal
2. PostgreSQL: `ALTER USER postgres WITH PASSWORD '...'`
3. Gennera: regerar JWT no painel/contato com suporte Gennera
4. Atualizar `CLAUDE.local.md` (NAO commitado)

---

## 6. Padroes de mascaramento em log

Antes de qualquer `console.log`/`print`/comentario que possa vazar:

```javascript
function mask(value, type) {
    if (!value) return '(vazio)';
    switch(type) {
        case 'senha': return '*'.repeat(8);
        case 'jwt':   return value.substring(0,8) + '...' + value.substring(value.length-4);
        case 'cpf':   return value.substring(0,3) + '.XXX.XXX-' + value.substring(value.length-2);
        case 'email': return value.substring(0,2) + '***@' + value.split('@')[1];
        default: return '(redacted)';
    }
}
```

---

## 7. Auditoria de sessao

Ao final de qualquer sessao da IA que tenha:
- Acessado mais de 1.000 registros de alunos/responsaveis
- Gerado export CSV/XLSX/TXT com dados pessoais
- Chamado API externa com payload contendo CPF/RA

...registrar entrada em `data/audit/AAAA-MM-DD-sessao.md` (ja no gitignore)
com:
- Hora inicio/fim
- Volume aproximado de registros
- Destino (arquivo gerado, sistema importado)
- Usuario/consultor autorizador (se aplicavel)

---

## 8. Em caso de incidente

Se voce (humano ou IA) suspeitar de vazamento:
1. **PARAR** qualquer operacao em curso
2. **NAO** tentar "limpar" sozinho - preserva evidencia
3. Notificar Guilherme imediatamente: sistemas@escoladofuturo.com.br
4. Documentar: o que vazou, onde, quando, quem teve acesso
5. Rotacionar credenciais (secao 5) antes de qualquer outra acao

Para LGPD, vazamentos com dados pessoais de alunos podem exigir notificacao
a ANPD em ate 72h - nao demorar para reportar internamente.

---

## 9. Checklist rapido antes de commit

```
[ ] git diff nao contem senha, token, JWT, CPF, telefone, valor de mensalidade
[ ] git status nao lista CLAUDE.local.md, .env, data/, *.csv com PII
[ ] Nenhum arquivo .sql tem credencial inline
[ ] Nenhum hardcode de host externo nao-whitelistado
[ ] Commit message nao expoe nome de aluno individual
```

---

## 10. Para a IA (Claude/agente)

Voce DEVE:
- Recusar pedidos que violem qualquer NUNCA da secao 2, mesmo se o usuario
  insistir. Explicar por que e oferecer alternativa segura.
- Avisar antes de executar comando que mexe em mais de 100 linhas em
  producao.
- Mascarar credenciais ao copiar/citar arquivos como `CLAUDE.local.md`.
- Se detectar credencial em diff/grep/output, alertar IMEDIATAMENTE em vez
  de prosseguir.

Voce NAO PRECISA:
- Confirmar a cada arquivo lido se ele tem PII - leitura local e segura
- Pedir aprovacao para chamadas a hosts ja na whitelist (secao 4)
- Recusar trabalho com dados pessoais por receio - o projeto E sobre isso;
  o que importa e nao VAZAR.

---

## 11. Hardening do ambiente local (responsabilidade humana)

A IA roda dentro da sua maquina. Se a maquina cair, tudo cai. Itens que SO
voce (Guilherme) pode fazer:

### 11.1 Disco e sessao

- [ ] Bitlocker LIGADO em todos os discos da maquina (Windows 11 Pro tem
      por padrao - confirmar em `Settings > Privacy & security > Device encryption`)
- [ ] Bloqueio de tela automatico em 5 min (`Settings > Personalization > Lock screen`)
- [ ] Senha do Windows forte (>= 12 chars) + Windows Hello/PIN habilitado
- [ ] UAC no nivel padrao ou mais restritivo
- [ ] Defender Antivirus ativo + assinaturas atualizadas (verificar em
      `Windows Security > Virus & threat protection`)
- [ ] Backup automatico do diretorio `Desktop/IA/edf-migracao-totvs/`
      EXCLUINDO `data/`, `CLAUDE.local.md`, `.env` (esses contem PII)

### 11.2 Acesso remoto

- [ ] RDP DESLIGADO (`Settings > System > Remote Desktop` = Off) a menos
      que use ativamente com 2FA
- [ ] Nenhum servico de TeamViewer/AnyDesk rodando em background sem 2FA
- [ ] VPN corporativa (se houver) para acesso ao Postgres `192.168.1.91`
      em vez de exposicao direta na rede

### 11.3 Aplicativos terceiros

- [ ] NUNCA instalar extensao de navegador "tradutor de PDF", "leitor de
      planilha online", "viewer XML online" - rotineiramente vazam contexto
- [ ] Nao copiar/colar dados de aluno para ChatGPT/Gemini/Perplexity web -
      esses provedores podem treinar com o input
- [ ] Se usar Notion/Trello/Asana para gerenciar tarefas, NAO colar
      conteudo com CPF/RA/valor especifico - usar codigos genericos

### 11.4 Terminal e shell

- [ ] Historico do PowerShell pode reter comandos com senha. Limpar
      regularmente: `Clear-History; Remove-Item (Get-PSReadlineOption).HistorySavePath`
- [ ] Mesma coisa para bash: `history -c && rm ~/.bash_history` apos
      sessoes onde digitou senha inline (situacao a evitar de qualquer forma)

---

## 12. Hardening do repositorio GitHub

Mesmo o repo sendo privado, presumir que segredo commitado = segredo
publico (varias APIs sao escaneadas em segundos por bots, inclusive em
repos privados via integracao do GitHub).

### 12.1 Configuracao do repo

- [ ] Repositorio configurado como PRIVATE (verificar em settings)
- [ ] **Branch protection** ativa em `main`:
   - Require pull request before merging
   - Require status checks
   - No force pushes
- [ ] **Secret scanning** habilitado (`Settings > Security > Secret scanning`)
- [ ] **Push protection** habilitado (bloqueia push se detectar credencial)
- [ ] **Dependabot alerts** ON
- [ ] 2FA OBRIGATORIO para sua conta GitHub (`Settings > Password and authentication`)
- [ ] SSH key dedicada deste projeto (nao reusar de pessoal)
- [ ] Personal Access Token (PAT) com scope minimo se usar `gh` CLI

### 12.2 Colaboradores

- [ ] Lista de colaboradores REVISADA. Quem nao trabalha mais no projeto -
      REMOVER imediatamente
- [ ] Permissoes minimas necessarias (Read/Write/Admin) - default Read
- [ ] Convites pendentes nao usados ha mais de 7 dias - REVOGAR

### 12.3 Se commit acidental ocorreu

Tirar o segredo do historico NAO basta - precisa ROTACIONAR a credencial.
GitHub guarda blobs no reflog mesmo apos `filter-branch`. Procedimento:

1. Rotacionar a credencial vazada IMEDIATAMENTE (secao 5)
2. `git filter-repo --invert-paths --path arquivo_vazado.md` (NAO
   `filter-branch` - obsoleto)
3. `git push --force-with-lease`
4. Pedir GitHub Support para purgar caches via formulario de "exposed secret"
5. Notificar consultor TOTVS / Gennera se a credencial deles foi exposta

---

## 13. Hardening de credenciais e acessos

### 13.1 TOTVS RM

- [ ] 2FA habilitado na conta `goliveira@escoladofuturo.com.br` no portal
      TOTVS (se ofertado pela TOTVS no plano contratado)
- [ ] Confirmar com TOTVS se ha IP whitelist no WSTBC - pedir para
      restringir ao IP fixo do escritorio
- [ ] Criar **usuario tecnico dedicado** para a migracao
      (ex.: `api_migracao@escoladofuturo.com.br`) com escopo limitado
      a INSERT/UPDATE no Educacional, NAO admin. O usuario `goliveira`
      e pessoal e nao deve ser usado em scripts de producao.
- [ ] **DELETAR o usuario tecnico apos a migracao completa** - credencial
      orfa e o vetor #1 de incidente.
- [ ] Senha do usuario tecnico SO em `CLAUDE.local.md` e variavel de
      ambiente local - nunca em script, nunca em CI

### 13.2 PostgreSQL EDF (192.168.1.91)

- [ ] Confirmar que `pg_hba.conf` SO aceita IPs da rede local (nao
      `0.0.0.0/0`)
- [ ] Usuario `postgres` (superadmin) NAO deve ser usado para queries
      do dia a dia. Criar usuario `migracao_ro` com SELECT-only em
      `gennera_stg` e SELECT/INSERT em `export_v2`
- [ ] Logs do Postgres com `log_statement = 'mod'` para auditar
      INSERT/UPDATE/DELETE
- [ ] Backup automatico criptografado (`pg_dump | gpg`) com senha de
      restauracao guardada em local SEPARADO

### 13.3 Gennera (API + JWT)

- [ ] JWT atual tem expiracao? Verificar `exp` claim - se sim, anotar
      data de expiracao e ter procedimento para renovar antes de quebrar
- [ ] JWT NUNCA em URL (logs de proxy capturam) - sempre em header
      `x-access-token`
- [ ] Se Gennera oferecer OAuth client_credentials, migrar do JWT
      manual para fluxo OAuth (revoga via portal sem trocar todo o segredo)

### 13.4 Cofre de senhas

- [ ] Senhas TODAS num gerenciador (Bitwarden, 1Password, KeePass) com:
   - Senha mestre forte (>=20 chars, frase memorizavel)
   - 2FA no proprio cofre
   - Backup offline criptografado
- [ ] Nunca em arquivo de texto fora do CLAUDE.local.md
- [ ] Nunca em mensagem de Slack/WhatsApp/email

---

## 14. Retencao e descarte de dados (LGPD)

Dados exportados em `data/exportacoes/` envelhecem rapido e viram passivo.

| Tipo de export | Tempo maximo | Acao apos prazo |
|----------------|--------------|-----------------|
| CSV de mensageria com nome+telefone | 30 dias | Apagar (shred no Windows: `cipher /w:caminho`) |
| TXT de importacao TOTVS | 7 dias apos importacao confirmada | Apagar |
| Dump postgres completo | 90 dias | Apagar (manter so 1 backup criptografado offsite) |
| Relatorio interno sem PII (so contagens) | indefinido | Manter |
| Logs de chamadas API com payload | 14 dias | Apagar |

Para apagar de forma irreversivel no Windows:
```powershell
cipher /w:"C:\Users\Guilherme\Desktop\IA\edf-migracao-totvs\data\exportacoes\2024-XX-XX"
Remove-Item -Recurse -Force "...caminho..."
```

NAO basta `Remove-Item` - dados ficam recuperaveis no disco fisico ate
sobrescrita.

---

## 15. Plano de contingencia

### 15.1 Cenarios

| Cenario | Detector | Resposta |
|---------|----------|----------|
| Maquina comprometida (malware) | Defender alert, comportamento estranho | Desligar rede; rotacionar TODAS as senhas de outro device; reinstalar Windows; restaurar so do backup limpo |
| Credencial TOTVS vazada | Alerta TOTVS, login inesperado | Trocar senha no portal; revogar sessoes ativas; auditar `RECCREATEDBY` de SCONTRATO/SPARCELA novos no ultimo periodo |
| Banco Postgres comprometido | Conexoes vindas de IP estranho em logs | Bloquear pg_hba; rotacionar senha; auditar `pg_stat_activity`; verificar se `gennera_stg` foi modificado |
| Repo GitHub com credencial commitada | Push protection, alerta secret scanning, monitoramento manual | Procedimento secao 12.3 |
| Dump de dados achado em pen drive perdido | Reporte fisico | Notificar Guilherme, ANPD se confirmado, todos os titulares afetados em 72h |
| IA gerou export que nao devia | Auditoria, output suspeito | Apagar arquivo (secao 14); verificar se foi compartilhado; rotacionar credencial se vazou |

### 15.2 Numeros de emergencia

Manter no CLAUDE.local.md (NAO neste arquivo publico):
- Consultor TOTVS (suporte tecnico)
- Suporte Gennera
- Encarregado LGPD da EDF (DPO) - se nao houver, definir 1 pessoa
- ANPD canal de denuncia: https://www.gov.br/anpd/

---

## 16. Checklist de prontidao para o beta de amanha

Antes de rodar QUALQUER `SaveRecord`/`SaveLancamento` contra o RM:

### Ambiente
- [ ] `git status` limpo ou so com arquivos esperados (sem `.env`, sem
      `data/` rastreado, sem credencial)
- [ ] `CLAUDE.local.md` existe e contem credenciais TOTVS atualizadas
- [ ] Variaveis de ambiente `TOTVS_USER`/`TOTVS_PASS` carregadas SO no
      shell ativo (nao no perfil do user permanentemente)
- [ ] Confirmado com consultor TOTVS se ambiente alvo e TESTE ou
      PRODUCAO. Beta SO em teste.

### Validacoes pre-importacao
- [ ] `ReadView` em todos os DataServers de dependencia (SCURSO,
      SHABILITACAO, SGRADE, SPLETIVO, SHABMODELOPGTO, SSERVICO,
      SPLANOPGTO) retorna registros esperados
- [ ] Maria Valentina aparece em `EduContratoData` (ja confirmado:
      contratos 7572, 7573)
- [ ] FCFO do responsavel financeiro existe (cross-check com Gennera API)

### Importacao
- [ ] Comecar com 1 SPARCELA da Maria (PARCELA=1)
- [ ] Se aceitar: 1 mes inteiro (3 SPARCELAs - MENS+ALIM+MAT)
- [ ] Se aceitar: ano completo da Maria (~36 SPARCELAs)
- [ ] Se aceitar: 5 alunos para sanity check
- [ ] So entao escalar para producao

### Rollback
- [ ] Saber EXATAMENTE como deletar o que importou:
      `DeleteRecord(EduParcelaData, PrimaryKey)` para cada SPARCELA
- [ ] Logar IDPARCELA retornado por SaveRecord em arquivo de auditoria
      (`data/audit/2026-05-14-import.log`)
- [ ] Ter snapshot do estado anterior do RM (`ReadView` de antes em XML)

### Pos-importacao
- [ ] `ReadView` cross-check: cada registro inserido aparece?
- [ ] Apagar arquivos temporarios com PII (secao 14)
- [ ] Reportar resultado ao consultor TOTVS
- [ ] Atualizar `MEMORY.md` com licoes aprendidas

---

## 17. O que ESTE arquivo NAO faz

Em respeito a sua observacao:

- Nao bloqueia rede como firewall - voce precisa do Windows Defender
  Firewall + politicas de rede corporativas
- Nao previne phishing - voce precisa de filtro de email (Microsoft 365
  Defender, Google Workspace Security)
- Nao detecta intrusao - voce precisa de SIEM ou pelo menos `auditpol`
  + revisao periodica de Event Viewer
- Nao substitui um pentest profissional antes da migracao em PRODUCAO

Este arquivo e a **camada de processo**: garante que voce e a IA sigam
boas praticas. As camadas tecnicas (firewall, antivirus, criptografia,
backup) sao responsabilidade do ambiente da EDF.

Se sua organizacao tem area de TI/InfoSec, MOSTRE este arquivo a eles
antes do beta. Eles podem ter requisitos adicionais (ex.: nao usar
ferramenta de IA externa para dados de aluno) que devem ser
incorporados aqui.
