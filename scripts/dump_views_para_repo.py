"""
Extrai DDL de todas as views relevantes em export.* e export_v2.* e salva
como arquivos .sql no repo, com header padrão explicando o uso pelo
Importador TOTVS Educacional.

Objetivo: ter as views versionadas no git como "snapshot do que está em produção"
e documentar a regra dos lookups (cod humano vs ID interno).

Uso: python scripts/dump_views_para_repo.py
"""
import os
import subprocess
from pathlib import Path

PROJ = Path(__file__).resolve().parent.parent

# Categorização: pasta destino por view
ACADEMICAS = {
    "scurso", "shabilitacao", "sgrade", "sdisciplina", "sdiscgrade",
    "spletivo", "sperido", "sinstituicao",
    "shabilitacaofilial", "shabilitacaofilialpl",
    "sturma", "sturmadisc",
    "shabilitacaoaluno", "smatricpl", "smatricula",
    "sfrequencia", "shistalunocol", "shistdisccol",
    "shorario", "sprofessor", "splanoaula", "speriodo",
    "setapas", "sprovas", "ppessoa",
    # Matviews/views aplicadas pelo Isaac direto no live (baseline 2026-06-11)
    "saluno", "sprofessorturma", "shorarioturma", "shorarioprofessor",
    "snotaetapa", "v_matrix_source", "professor_qh_enriquecido",
    "dim_pessoa_unica",
}

FINANCEIRAS = {
    "sbolsa", "sbolsaaluno", "sbolsapletivo",
    "scontrato", "scontrato_nova",
    "sparcela", "sparcplano",
    "splanopgto", "shabmodelopgto",
    "sservico", "fcfo", "flan",
}

V2_FINANCEIRAS = {
    "sservico", "splanopgto", "sparcplano", "shabmodelopgto",
    "scontrato", "sparcela", "sbolsaaluno",
    "slan", "flan", "fcfo",
}


def _psql(query, encoding="latin-1"):
    local_md = (PROJ / "CLAUDE.local.md").read_text(encoding="utf-8")
    sec = local_md.split("## 1.")[1].split("## 2.")[0]
    pwd = [ln for ln in sec.split("\n") if "Password:" in ln][0].split("**")[2].strip()
    env = os.environ.copy()
    env["PGCLIENTENCODING"] = "LATIN1"
    env["PGPASSWORD"] = pwd
    psql = r'C:\Program Files\PostgreSQL\18\bin\psql.exe'
    cmd = [psql, "-h", "192.168.1.91", "-U", "postgres", "-d", "Edf_bd_legado",
           "-A", "-t", "-c", query]
    out = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding=encoding)
    if out.returncode != 0:
        return None
    return out.stdout.strip().replace("\r", "")


def psql_get_viewdef(schema, view_name):
    """Extrai DDL de view/matview via pg_get_viewdef. Retorna (ddl, relkind)."""
    kind = _psql(
        f"SELECT c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        f"WHERE n.nspname='{schema}' AND c.relname='{view_name}'"
    )
    if not kind:
        return None, None
    ddl = _psql(f"SELECT pg_get_viewdef('{schema}.{view_name}'::regclass, true);")
    if not ddl:
        return None, None
    return ddl, kind.strip()  # 'v' = view, 'm' = matview


HEADER_TEMPLATE = """-- ============================================================================
-- View: {schema}.{view_name}
-- Esquema destino TOTVS: {table_upper}
-- ============================================================================
-- Snapshot do DDL em {date} (dump automatico via scripts/dump_views_para_repo.py)
--
-- USO COMO FONTE PARA IMPORTADOR TOTVS EDUCACIONAL
-- ------------------------------------------------------------------
-- O Importador (Executar -> Importador -> TOTVS Educacional) consome
-- arquivos .csv ANSI/LATIN-1 com separador ';' baseados nesta view.
--
-- REGRA CRITICA (ver knowledge/totvs/13_importador_layout_e_lookups.md):
-- Colunas com sintaxe COLUNA$X.TABELA$S$X$T.CAMPOBUSCA.FK1$FK1...
-- querem o CAMPOBUSCA (codigo humano), nao o ID literal.
--
-- Exemplos pro RM Educacional:
--   IDHABILITACAOFILIAL  -> passar CODHABILITACAO (ex: '8')
--   IDPERLET             -> passar CODPERLET (ex: '2022')
--   IDTURMADISC          -> passar CODDISC (ex: '7')
--   CODTURNO             -> passar NOME (ex: 'Integral')
--   CODSTATUS/RES        -> passar DESCRICAO (ex: 'Ativo', 'Aprovado')
--
-- Por isso esta view retorna sempre os CODIGOS HUMANOS, NUNCA os IDs
-- sequenciais (IDPERLET, IDHABFIL, IDTURMADISC). O Importador resolve
-- IDs internos via lookup, e o mesmo CSV migra entre instancias.
--
-- WORKFLOW para usar:
-- 1. Gerar CSV "isca" com header minimo -> Importador imprime "Layout esperado:"
-- 2. Capturar Layout esperado: literal e usar como header EXATO
-- 3. Script em scripts/gera_*_importador_totvs.py mapeia colunas da view -> layout
-- 4. Importar via TOTVS Educacional
-- ============================================================================

CREATE OR REPLACE VIEW {schema}.{view_name} AS
{ddl};
"""


def dump_view(schema, view_name, dest_dir):
    ddl, kind = psql_get_viewdef(schema, view_name)
    if not ddl:
        return False
    # Limpa whitespace inicial de cada linha
    cleaned = "\n".join(ln.rstrip() for ln in ddl.split("\n"))
    from datetime import date
    content = HEADER_TEMPLATE.format(
        schema=schema,
        view_name=view_name,
        table_upper=view_name.upper(),
        date=date.today().isoformat(),
        ddl=cleaned,
    )
    if kind == "m":
        # Matview: CREATE OR REPLACE VIEW nao existe pra matview — corrigir DDL
        content = content.replace(
            f"CREATE OR REPLACE VIEW {schema}.{view_name} AS",
            f"-- MATERIALIZED VIEW (refresh: REFRESH MATERIALIZED VIEW [CONCURRENTLY] {schema}.{view_name})\n"
            f"-- Recriar exige: DROP MATERIALIZED VIEW {schema}.{view_name}; (+ reindexar UNIQUE INDEX)\n"
            f"CREATE MATERIALIZED VIEW {schema}.{view_name} AS",
        )
        idx = _psql(
            f"SELECT indexdef FROM pg_indexes WHERE schemaname='{schema}' AND tablename='{view_name}'"
        )
        if idx:
            content += "\n-- Indices existentes:\n" + "\n".join(
                f"-- {ln};" for ln in idx.split("\n") if ln.strip()
            ) + "\n"
    out_path = dest_dir / f"{view_name}.sql"
    out_path.write_text(content, encoding="utf-8", newline="\r\n")
    return True


print("=== Dumping views academicas (export.*) ===")
acad_dir = PROJ / "views" / "academico"
acad_dir.mkdir(parents=True, exist_ok=True)
acad_ok, acad_fail = 0, 0
for v in sorted(ACADEMICAS):
    if dump_view("export", v, acad_dir):
        print(f"  OK views/academico/{v}.sql")
        acad_ok += 1
    else:
        print(f"  SKIP {v} (view nao existe ou erro)")
        acad_fail += 1
print(f"Academicas: {acad_ok} OK, {acad_fail} skip\n")

print("=== Dumping views financeiras (export.*) ===")
fin_dir = PROJ / "views" / "financeiro"
fin_dir.mkdir(parents=True, exist_ok=True)
fin_ok, fin_fail = 0, 0
for v in sorted(FINANCEIRAS):
    if dump_view("export", v, fin_dir):
        print(f"  OK views/financeiro/{v}.sql")
        fin_ok += 1
    else:
        print(f"  SKIP {v}")
        fin_fail += 1
print(f"Financeiras: {fin_ok} OK, {fin_fail} skip\n")

print("=== Dumping snapshots v2 (export_v2.*) ===")
# Os arquivos 01-13 originais em views/financeiro/v2/ sao SCRIPTS DE SETUP
# (CREATE OR REPLACE com transformacoes). Os snapshots aqui sao a saida atual
# do pg_get_viewdef — fica como referencia de "o que esta no banco" agora.
v2_dir = PROJ / "views" / "financeiro" / "v2" / "snapshots"
v2_dir.mkdir(parents=True, exist_ok=True)
v2_ok, v2_fail = 0, 0
for v in sorted(V2_FINANCEIRAS):
    # Renomeia pra _snapshot_<v>.sql pra deixar claro
    saved = dump_view("export_v2", v, v2_dir)
    if saved:
        # renomeia o arquivo gerado
        original = v2_dir / f"{v}.sql"
        if original.exists():
            print(f"  OK views/financeiro/v2/snapshots/{v}.sql")
            v2_ok += 1
        else:
            v2_fail += 1
    else:
        print(f"  SKIP export_v2.{v}")
        v2_fail += 1
print(f"V2 snapshots: {v2_ok} OK, {v2_fail} skip\n")

print("DONE.")
