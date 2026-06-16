"""
Gera SMATRICULA.txt no formato do Importador TOTVS Educacional, seguindo o
mesmo padrão observado no log de SMATRICPL (2026-05-20 10:35:54): headers com
sintaxe composta `$Tabela$S$Chave$T.Campo.FK$FK...$LookupOnly`.

Layout inferido a partir do padrão SMATRICPL + campos da tabela SMATRICULA
(GetSchema EduMatriculaData) + view export.smatricula.

Se o Importador rejeitar com "X campos requeridos e Y encontrados", capturar
o "Layout esperado:" do log e atualizar o header HEADER_RAW abaixo.
"""
import os
import subprocess
from pathlib import Path

PROJ = Path(__file__).resolve().parent.parent
OUT = PROJ / "data" / "exportacoes" / "2026-05-20"
OUT.mkdir(parents=True, exist_ok=True)


def psql_query(query):
    local_md = (PROJ / "CLAUDE.local.md").read_text(encoding="utf-8")
    sec = local_md.split("## 1.")[1].split("## 2.")[0]
    pwd = [ln for ln in sec.split("\n") if "Password:" in ln][0].split("**")[2].strip()
    env = os.environ.copy()
    env["PGCLIENTENCODING"] = "LATIN1"
    env["PGPASSWORD"] = pwd
    psql = r'C:\Program Files\PostgreSQL\18\bin\psql.exe'
    cmd = [psql, "-h", "192.168.1.91", "-U", "postgres", "-d", "Edf_bd_legado",
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


# Header EXATO do log de erro 2026-05-20 10:57:55 (capturado pelo importador)
# 27 colunas. NÃO MODIFICAR sem novo log.
HEADER_RAW = (
    "CODCOLIGADA,"
    "CODCURSO$LookupOnly,"
    "IDHABILITACAOFILIAL$IDHABILITACAOFILIAL.SHABILITACAOFILIAL$S$IDHABILITACAOFILIAL$T.CODHABILITACAO.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL.CODTIPOCURSO$CODTIPOCURSO.CODTURNO$CODTURNO.CODCURSO$CODCURSO.CODGRADE$CODGRADE,"
    "CODGRADE$LookupOnly,"
    "CODTURNO$CODTURNO.STURNO$S$CODTURNO$T.NOME.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL.CODTIPOCURSO$CODTIPOCURSO$LookupOnly,"
    "CODFILIAL$LookupOnly,"
    "CODTIPOCURSO$LookupOnly,"
    "CODTURMA$LookupOnly,"
    "IDPERLET$IDPERLET.SPLETIVO$S$IDPERLET$T.CODPERLET.CODCOLIGADA$CODCOLIGADA.CODFILIAL$CODFILIAL.CODTIPOCURSO$CODTIPOCURSO,"
    "IDTURMADISC$IDTURMADISC.STURMADISC$S$IDTURMADISC$T.CODDISC.IDPERLET$IDPERLET.CODTURMA$CODTURMA.CODFILIAL$CODFILIAL.CODCOLIGADA$CODCOLIGADA,"
    "RA,"
    "CODSTATUSRES$CODSTATUS.SSTATUS$S$CODSTATUS$T.DESCRICAO.CODCOLIGADA$CODCOLIGADA.CODTIPOCURSO$CODTIPOCURSO,"
    "CODSTATUS$CODSTATUS.SSTATUS$S$CODSTATUS$T.DESCRICAO.CODCOLIGADA$CODCOLIGADA.CODTIPOCURSO$CODTIPOCURSO,"
    "NUMDIARIO,"
    "DTMATRICULA,"
    "OBSHISTORICO,"
    "TIPOMAT$CODTIPOMAT.STIPOMATRICULA$S$CODTIPOMAT$T.DESCRICAO.CODCOLIGADA$CODCOLIGADA.CODTIPOCURSO$CODTIPOCURSO,"
    "TIPODISCIPLINA,"
    "DTALTERACAO,"
    "DTALTERACAOSIST,"
    "CODSUBTURMA,"
    "NUMCREDITOSCOB,"
    "COBPOSTERIORMATRIC,"
    "CODTURMAORIGEM$LookupOnly,"
    "IDTURMADISCORIGEM$IDTURMADISC.STURMADISC$S$IDTURMADISC$T.CODDISC.IDPERLET$IDPERLET.CODFILIAL$CODFILIAL.CODCOLIGADA$CODCOLIGADA.CODTURMAORIGEM$CODTURMA,"
    "CODTURMAPRINCIPAL$LookupOnly,"
    "IDTURMADISCPRINCIPAL$IDTURMADISC.STURMADISC$S$IDTURMADISC$T.CODDISC.IDPERLET$IDPERLET.CODFILIAL$CODFILIAL.CODCOLIGADA$CODCOLIGADA.CODTURMAPRINCIPAL$CODTURMA"
)
HEADER = HEADER_RAW.replace(",", ";")
NUM_COLS = HEADER.count(";") + 1
print(f"Header tem {NUM_COLS} colunas")


def fmt_date(s):
    """Converte 2021-10-21[ HH:MM:SS] -> 21/10/2021 (padrao BR Importador)."""
    if not s:
        return ""
    d = s.split(" ")[0].split("T")[0]
    parts = d.split("-")
    if len(parts) == 3:
        return f"{parts[2]}/{parts[1]}/{parts[0]}"
    return s


# Mapping CODDISC -> IDTURMADISC (criados no RM nesta sessão 2026-05-19)
IDTURMADISC_MAP = {
    "7": "188", "19": "189", "21": "190", "32": "191",
    "49": "192", "51": "193", "55": "194", "62": "195",
    "67": "196", "76": "197", "84": "198", "85": "199",
    "104": "187",
}

print("\n=== SMATRICULA Diego 2022 (13 disciplinas) ===")
rows = psql_query(
    "SELECT * FROM export.smatricula "
    "WHERE \"RA\"='20142166' AND \"CODPERLET\"='2022' "
    "ORDER BY \"CODDISC\"::int"
)
print(f"Rows view: {len(rows)}")

data_lines = []
for r in rows:
    cod_disc = r.get("CODDISC", "")
    id_turmadisc = IDTURMADISC_MAP.get(cod_disc, "")
    # IMPORTANTE: colunas com sintaxe COLUNA$ID.TABELA$S$ID$T.CAMPO_BUSCA querem o CAMPO_BUSCA,
    # não o ID literal. Importador faz lookup pra converter.
    # Layout EXATO do log 2026-05-20 10:57:55 — 27 colunas
    values = [
        "1",                                            # 1. CODCOLIGADA
        "EF2",                                          # 2. CODCURSO$LookupOnly
        "8",                                            # 3. IDHABILITACAOFILIAL → lookup por CODHABILITACAO
        "2022",                                         # 4. CODGRADE$LookupOnly
        "Integral",                                     # 5. CODTURNO → lookup por NOME em STURNO
        "1",                                            # 6. CODFILIAL$LookupOnly
        "1",                                            # 7. CODTIPOCURSO$LookupOnly
        "8A",                                           # 8. CODTURMA$LookupOnly
        "2022",                                         # 9. IDPERLET → lookup por CODPERLET
        cod_disc,                                       # 10. IDTURMADISC → lookup por CODDISC
        "20142166",                                     # 11. RA
        r.get("STATUSRES") or "Aprovado",               # 12. CODSTATUSRES → lookup por DESCRICAO
        r.get("STATUS") or "Aprovado",                  # 13. CODSTATUS → lookup por DESCRICAO
        r.get("NUMDIARIO", ""),                         # 14. NUMDIARIO
        fmt_date(r.get("DTMATRICULA", "")),             # 15. DTMATRICULA
        r.get("OBSHISTORICO", ""),                      # 16. OBSHISTORICO
        r.get("TIPOMAT", ""),                           # 17. TIPOMAT → lookup por DESCRICAO em STIPOMATRICULA (vazio = default)
        r.get("TIPODISCIPLINA", "N"),                   # 18. TIPODISCIPLINA
        fmt_date(r.get("DTALTERACAO", "")),             # 19. DTALTERACAO
        fmt_date(r.get("DTALTERACAOSIST", "")),         # 20. DTALTERACAOSIST
        r.get("CODSUBTURMA", ""),                       # 21. CODSUBTURMA
        r.get("NUMCREDITOSCOB", ""),                    # 22. NUMCREDITOSCOB
        r.get("COBPOSTERIORMATRIC", "N"),               # 23. COBPOSTERIORMATRIC
        "",                                             # 24. CODTURMAORIGEM$LookupOnly (sem turma origem)
        "",                                             # 25. IDTURMADISCORIGEM lookup (sem turma origem → vazio)
        "",                                             # 26. CODTURMAPRINCIPAL$LookupOnly (sem turma principal)
        "",                                             # 27. IDTURMADISCPRINCIPAL lookup (sem turma principal → vazio)
    ]
    assert len(values) == NUM_COLS, f"Row com {len(values)} valores, esperado {NUM_COLS}"
    data_lines.append(";".join(values))

out_path = OUT / "SMATRICULA.csv"
content = HEADER + "\r\n" + "\r\n".join(data_lines) + "\r\n"
with open(out_path, "w", encoding="latin-1", newline="", errors="replace") as f:
    f.write(content)
print(f"  OK {out_path.relative_to(PROJ)} ({len(data_lines)} linhas + header)")

print("\n--- Sample data (3 primeiros) ---")
for line in data_lines[:3]:
    print(f"  {line}")
print("...")
