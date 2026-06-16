"""
Gera FLAN.txt posicional do Diego (RA 20142166) usando o arquivo Maria 2024
(data/exportacoes/2026-05-08/flan.txt) como TEMPLATE.

Estratégia: manter posições fixas, substituir apenas campos variáveis:
- L: CODCFO, NUMERODOCUMENTO, NUMEROLANCAMENTO, DTVENC, DTEMISSAO, DTCOMP,
     VALOR, DESCONTO, SERIEDOC, HISTORICO
- U: CODCOLIGADA+IDLAN, VALOR

Saída: data/exportacoes/2026-05-21/FLAN.txt em ANSI/LATIN-1 com CRLF.

Uso: python scripts/gera_flan_diego.py
"""
import os
import subprocess
from pathlib import Path
from datetime import date

PROJ = Path(__file__).resolve().parent.parent
OUT_DIR = PROJ / "data" / "exportacoes" / "2026-05-21"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def psql_rows(query):
    local = (PROJ / "CLAUDE.local.md").read_text(encoding="utf-8")
    sec = local.split("## 1.")[1].split("## 2.")[0]
    pwd = [ln for ln in sec.split("\n") if "Password:" in ln][0].split("**")[2].strip()
    env = os.environ.copy()
    env["PGCLIENTENCODING"] = "LATIN1"
    env["PGPASSWORD"] = pwd
    psql = r'C:\Program Files\PostgreSQL\18\bin\psql.exe'
    cmd = [psql, "-h", "192.168.1.91", "-U", "postgres", "-d", "Edf_bd_legado",
           "-A", "-F", "|", "-t", "-c", query]
    out = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="latin-1")
    lines = [l.replace("\r", "") for l in out.stdout.strip().split("\n") if l.strip()]
    rows = []
    for line in lines:
        if line.startswith("(") and "linha" in line:
            break
        cells = line.split("|")
        rows.append(cells)
    return rows


# 1. Carregar template L+U da Maria
TEMPLATE_PATH = PROJ / "data" / "exportacoes" / "2026-05-08" / "flan.txt"
with open(TEMPLATE_PATH, "rb") as f:
    raw = f.read()
lines = [l for l in raw.split(b"\r\n") if l]
L_template = lines[0].decode("latin-1")
U_template = lines[1].decode("latin-1")
print(f"Template L len={len(L_template)} U len={len(U_template)}")
assert len(L_template) == 1967, f"L template inesperado: {len(L_template)}"
assert len(U_template) == 349, f"U template inesperado: {len(U_template)}"


def replace_at(line, pos, value, width):
    """Substitui line[pos:pos+width] por value (lpad/rpad conforme tipo)."""
    if pos < 0 or pos + width > len(line):
        raise ValueError(f"pos={pos} width={width} fora de len={len(line)}")
    return line[:pos] + str(value).ljust(width)[:width] + line[pos + width:]


def lpad_zero(value, width):
    """Pad zero à esquerda."""
    s = str(value).strip()
    return s.rjust(width, "0")[:width]


def fmt_brl_18(valor):
    """Decimal BR (4 casas) sem separadores, lpad 18 zeros.
    Ex: 565.80 -> '000000000000565800' (18 chars)
    """
    if not valor:
        return "0" * 18
    f = float(str(valor).replace(",", "."))
    inteiro4dec = round(f * 10000)
    return str(inteiro4dec).rjust(18, "0")[:18]


def fmt_date(d):
    """YYYY-MM-DD -> DDMMAA"""
    if not d:
        return "      "
    s = str(d).split(" ")[0].split("T")[0]
    y, m, dd = s.split("-")
    return f"{dd}{m}{y[-2:]}"


def replace_pos(line, pos_start, pos_end, value):
    width = pos_end - pos_start
    s = str(value)
    if len(s) > width:
        s = s[:width]
    elif len(s) < width:
        s = s.ljust(width)
    return line[:pos_start] + s + line[pos_end:]


def replace_lpad(line, pos_start, pos_end, value):
    width = pos_end - pos_start
    s = lpad_zero(value, width)
    return line[:pos_start] + s + line[pos_end:]


# 2. Buscar lançamentos Diego — ALL anos
print("\nBuscando FLAN Diego (RA 20142166)...")
rows = psql_rows(
    'SELECT "CODCFO","NUMERODOCUMENTO","CODCCUSTO","HISTORICO",'
    '"DATAVENCIMENTO","DATAEMISSAO","VALOROPERACAO","VALORDESCONTO",'
    '"CODCXA","CODTDO","CODFILIAL","NATFINANCEIRA","CODPERLET","PARCELA",'
    '"SERVICO" '
    'FROM export_v2.flan WHERE "RA"=\'20142166\' '
    'ORDER BY "DATAVENCIMENTO","NUMERODOCUMENTO"'
)
print(f"Total lançamentos Diego: {len(rows)}")


# 3. Gerar L+U pra cada lançamento
out_lines = []
contador = 1  # numeroLan sequencial dentro do arquivo

for row in rows:
    (CODCFO, NUMERODOCUMENTO, CODCCUSTO, HISTORICO,
     DATAVENCIMENTO, DATAEMISSAO, VALOROPERACAO, VALORDESCONTO,
     CODCXA, CODTDO, CODFILIAL, NATFINANCEIRA, CODPERLET, PARCELA, SERVICO) = row

    # ===== Linha L (1967 chars) =====
    L = L_template
    # pos 4-8: CODCOLIGADA (fixo 0001)
    L = replace_pos(L, 4, 8, "0001")
    # pos 8-14: CODCFO (6, lpad zeros)
    L = replace_pos(L, 8, 14, lpad_zero(CODCFO, 6))
    # pos 33-39: CODTDO (BOLETO, fixo)
    L = replace_pos(L, 33, 39, "BOLETO")
    # pos 43-51: NUMERODOCUMENTO (lpad8)
    L = replace_pos(L, 43, 51, lpad_zero(NUMERODOCUMENTO, 8))
    # pos 258-268: NUMEROLANCAMENTO sequencial (lpad10)
    L = replace_pos(L, 258, 268, lpad_zero(contador, 10))
    # pos 283-295: DTVENC(6) + DTEMISSAO(6)
    dt_v = fmt_date(DATAVENCIMENTO)
    dt_e = fmt_date(DATAEMISSAO)
    L = replace_pos(L, 283, 295, dt_v + dt_e)
    # pos 301-307: DTCOMPETENCIA = data vencimento
    L = replace_pos(L, 301, 307, dt_v)
    # pos 458-461: CODCXA (237)
    L = replace_pos(L, 458, 461, "237")
    # pos 468-486: VALOROPERACAO (18 chars com 4 decimais embedded)
    L = replace_pos(L, 468, 486, fmt_brl_18(VALOROPERACAO))
    # pos 522-540: VALORJUROS (zeros)
    L = replace_pos(L, 522, 540, "0" * 18)
    # pos 540-558: VALORDESCONTO
    L = replace_pos(L, 540, 558, fmt_brl_18(VALORDESCONTO))
    # pos 1581-1588: SERIEDOC (0001@@@)
    L = replace_pos(L, 1581, 1588, "0001@@@")
    # pos 1593-1660: HISTORICO (até 67 chars)
    historico = HISTORICO or f"{SERVICO} {PARCELA}/{CODPERLET} - RA 20142166"
    historico = historico[:67]
    L = replace_pos(L, 1593, 1593 + len(historico), historico)
    # Garantir tamanho exato 1967
    assert len(L) == 1967, f"L com {len(L)} chars (esperado 1967) - linha {contador}"

    # ===== Linha U (349 chars) =====
    U = U_template
    # pos 0-1: U (já está)
    # pos 1-5: CODCOLIGADA (0001)
    U = replace_pos(U, 1, 5, "0001")
    # pos 5-15: IDLAN/contador (mesmo do L pos 258-268)
    U = replace_pos(U, 5, 15, lpad_zero(contador, 10))
    # pos 30-48: VALOR rateio
    U = replace_pos(U, 30, 48, fmt_brl_18(VALOROPERACAO))
    # pos 303-312: NATFINANCEIRA (0 + 01 + 111.111)
    natfin = "0" + "01" + (NATFINANCEIRA or "111.111").ljust(6)[:6]
    natfin = natfin[:9]
    U = replace_pos(U, 303, 312, natfin)
    assert len(U) == 349, f"U com {len(U)} chars (esperado 349) - linha {contador}"

    out_lines.append(L)
    out_lines.append(U)
    contador += 1


# 4. Salvar
out_path = OUT_DIR / "FLAN.txt"
with open(out_path, "wb") as f:
    for ln in out_lines:
        f.write(ln.encode("latin-1", errors="replace") + b"\r\n")

print(f"\nOK: {out_path.relative_to(PROJ)}")
print(f"  Linhas: {len(out_lines)} ({len(out_lines)//2} lançamentos L+U)")
print(f"  Encoding: ANSI / LATIN-1, EOL: CRLF")

# 5. Sample primeira linha
print("\nSample linha 1 (L) — primeiros 200 chars:")
print(repr(out_lines[0][:200]))
print("\nSample linha 2 (U) — primeiros 200 chars:")
print(repr(out_lines[1][:200]))
