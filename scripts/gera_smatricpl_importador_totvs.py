"""
Gera SMATRICPL.txt no formato EXATO esperado pelo Importador TOTVS Educacional
(ferramenta interna do RM, acessada via Executar -> Importador -> TOTVS Educacional).

Layout extraído do log de erro 2026-05-20 10:35:54:
- 27 colunas
- Separador ;
- Headers com sintaxe composta ($Tabela$S$Chave$T.Campo.FK$FK...)
- Encoding LATIN1
- Nome do arquivo = nome da tabela (SMATRICPL.txt)
"""
import os
import subprocess
from pathlib import Path
from datetime import date

PROJ = Path(__file__).resolve().parent.parent
OUT = PROJ / "data" / "exportacoes" / "2026-05-20"
OUT.mkdir(parents=True, exist_ok=True)


def psql_query(query):
    """Executa query e retorna lista de dicts."""
    local_md = (PROJ / "CLAUDE.local.md").read_text(encoding="utf-8")
    sec = local_md.split("## 1.")[1].split("## 2.")[0]
    pwd = [ln for ln in sec.split("\n") if "Password:" in ln][0].split("**")[2].strip()
    host = "192.168.1.91"
    user = "postgres"
    psql = r'C:\Program Files\PostgreSQL\18\bin\psql.exe'

    env = os.environ.copy()
    env["PGCLIENTENCODING"] = "LATIN1"
    env["PGPASSWORD"] = pwd

    cmd = [psql, "-h", host, "-U", user, "-d", "Edf_bd_legado",
           "-A", "-F", "|", "-c", query]
    out = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="latin-1")
    lines = [l.replace("\r", "") for l in out.stdout.strip().split("\n") if l.strip()]
    if len(lines) < 2:
        return []
    header = lines[0].split("|")
    rows = []
    for line in lines[1:]:
        if line.startswith("(") and "linha" in line:
            break
        cells = line.split("|")
        if len(cells) == len(header):
            rows.append(dict(zip(header, cells)))
    return rows


# Header EXATO do log de erro 2026-05-20 (27 colunas)
HEADER_RAW = (
    "CODCOLIGADA,"
    "CODCURSO$LookupOnly,"
    "IDHABILITACAOFILIAL$IDHABILITACAOFILIAL.SHABILITACAOFILIAL$S$IDHABILITACAOFILIAL$T.CODHABILITACAO.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL.CODTIPOCURSO$CODTIPOCURSO.CODTURNO$CODTURNO.CODCURSO$CODCURSO.CODGRADE$CODGRADE,"
    "CODGRADE$LookupOnly,"
    "CODTURNO$CODTURNO.STURNO$S$CODTURNO$T.NOME.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL.CODTIPOCURSO$CODTIPOCURSO$LookupOnly,"
    "CODFILIAL,"
    "CODTIPOCURSO$LookupOnly,"
    "CODTURMA,"
    "IDPERLET$IDPERLET.SPLETIVO$S$IDPERLET$T.CODPERLET.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL.CODTIPOCURSO$CODTIPOCURSO,"
    "RA,"
    "CODSTATUSRES$CODSTATUS.SSTATUS$S$CODSTATUS$T.DESCRICAO.CODCOLIGADA$CODCOLIGADA.CODTIPOCURSO$CODTIPOCURSO,"
    "CODSTATUS$CODSTATUS.SSTATUS$S$CODSTATUS$T.DESCRICAO.CODCOLIGADA$CODCOLIGADA.CODTIPOCURSO$CODTIPOCURSO,"
    "DTMATRICULA,"
    "DTRESULTADO,"
    "IDENTIFICADOR,"
    "NUMCARTEIRA,"
    "CARTEIRAEMITIDA,"
    "VIACARTEIRA,"
    "PERIODO,"
    "NUMALUNO,"
    "CODTIPOMAT$CODTIPOMAT.STIPOMATRICULA$S$CODTIPOMAT$T.DESCRICAO.CODCOLIGADA$CODCOLIGADA.CODTIPOCURSO$CODTIPOCURSO,"
    "SELINSTENADE,"
    "SELMECENADE,"
    "DTPROVAENADE,"
    "COMPARECEUENADE,"
    "OBSENADE,"
    "DTMATRICULAENCERRA"
)

# Trocar virgula por ponto-e-virgula pra separador esperado
HEADER = HEADER_RAW.replace(",", ";")
NUM_COLS = HEADER.count(";") + 1
print(f"Header tem {NUM_COLS} colunas (esperado 27)")
assert NUM_COLS == 27, f"Header com {NUM_COLS} colunas, esperado 27"


def fmt_date(s):
    """Converte 2021-10-21 [00:00:00] -> 21/10/2021 (padrao BR usado pelo Importador)."""
    if not s:
        return ""
    d = s.split(" ")[0].split("T")[0]
    parts = d.split("-")
    if len(parts) == 3:
        return f"{parts[2]}/{parts[1]}/{parts[0]}"
    return s


print("\n=== SMATRICPL Diego 2022 ===")
rows = psql_query(
    "SELECT * FROM export.smatricpl "
    "WHERE \"RA\"='20142166' AND \"CODPERLET\"='2022'"
)
print(f"Rows view: {len(rows)}")

# Construir cada linha com EXATAMENTE 27 colunas
# Valores para Diego 2022 (use IDs já existentes no RM)
data_lines = []
for r in rows:
    # IMPORTANTE: colunas com lookup querem o valor de BUSCA, não o ID literal.
    # Sintaxe: COLUNA$ID.TABELA$S$ID$T.CAMPO_BUSCA → passar o CAMPO_BUSCA.
    # Ex coluna 9: "IDPERLET$IDPERLET.SPLETIVO$S$IDPERLET$T.CODPERLET" → passar CODPERLET (2022), não IDPERLET (12).
    # Importador faz lookup em SPLETIVO WHERE CODPERLET=2022 AND CODCOLIGADA=1 AND CODFILIAL=1 AND CODTIPOCURSO=1 → resolve IDPERLET=12.
    values = [
        "1",                          # 1. CODCOLIGADA
        "EF2",                        # 2. CODCURSO (lookup direto)
        "8",                          # 3. IDHABILITACAOFILIAL lookup por CODHABILITACAO em SHABILITACAOFILIAL
        "2022",                       # 4. CODGRADE (lookup direto)
        "Integral",                   # 5. CODTURNO lookup pelo NOME em STURNO
        "1",                          # 6. CODFILIAL
        "1",                          # 7. CODTIPOCURSO (lookup direto)
        "8A",                         # 8. CODTURMA
        "2022",                       # 9. IDPERLET lookup por CODPERLET em SPLETIVO
        "20142166",                   # 10. RA
        "",                           # 11. CODSTATUSRES (export tem vazio)
        "Ativo",                      # 12. CODSTATUS (lookup pelo DESCRICAO em SSTATUS)
        fmt_date(r.get("DTMATRICULA", "")),  # 13. DTMATRICULA
        "",                           # 14. DTRESULTADO
        "",                           # 15. IDENTIFICADOR
        "",                           # 16. NUMCARTEIRA
        "",                           # 17. CARTEIRAEMITIDA
        "",                           # 18. VIACARTEIRA
        "1",                          # 19. PERIODO
        "",                           # 20. NUMALUNO
        "",                           # 21. CODTIPOMAT (lookup) — vazio = importador usa default
        "",                           # 22. SELINSTENADE
        "",                           # 23. SELMECENADE
        "",                           # 24. DTPROVAENADE
        "",                           # 25. COMPARECEUENADE
        "",                           # 26. OBSENADE
        "",                           # 27. DTMATRICULAENCERRA
    ]
    assert len(values) == 27, f"Row com {len(values)} valores, esperado 27"
    data_lines.append(";".join(values))

# Escreve arquivo (LATIN1, separador ;, CRLF padrão Windows)
out_path = OUT / "SMATRICPL.csv"
content = HEADER + "\r\n" + "\r\n".join(data_lines) + "\r\n"
with open(out_path, "w", encoding="latin-1", newline="", errors="replace") as f:
    f.write(content)
print(f"  OK {out_path.relative_to(PROJ)} ({len(data_lines)} linhas + header)")

# Print sample pra conferencia visual
print("\n--- Sample header (primeiras 3 colunas) ---")
print(";".join(HEADER.split(";")[:3]) + ";...")
print("\n--- Sample data ---")
for line in data_lines:
    cells = line.split(";")
    print(f"  {len(cells)} valores: {';'.join(cells)}")
