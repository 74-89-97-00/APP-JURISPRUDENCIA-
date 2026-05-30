# -*- coding: utf-8 -*-
"""Utilitários comuns dos parsers de súmulas.

Roda no runner Linux do GitHub Actions (Python 3 + poppler-utils + requests).
Gera arquivos data/<tribunal>-sumulas.js no MESMO formato dos arquivos atuais.
"""
import os
import re
import subprocess
import sys
import tempfile

import requests

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120 Safari/537.36")


def tmp(nome):
    return os.path.join(tempfile.gettempdir(), nome)


def baixar(url, destino):
    """Baixa um arquivo (segue redirecionamentos). Erro vira exceção."""
    r = requests.get(url, headers={"User-Agent": UA}, timeout=120, allow_redirects=True)
    r.raise_for_status()
    with open(destino, "wb") as f:
        f.write(r.content)
    return destino


def pdf_para_texto(pdf, txt):
    """Roda pdftotext -layout e devolve o texto UTF-8."""
    subprocess.run(
        ["pdftotext", "-layout", "-enc", "UTF-8", pdf, txt],
        check=True,
    )
    with open(txt, encoding="utf-8") as f:
        return f.read()


def colapsar(s):
    """Colapsa qualquer sequência de espaços/quebras em um único espaço."""
    return re.sub(r"\s+", " ", s or "").strip()


def js_str(s):
    """Escapa uma string para literal JS entre aspas duplas."""
    return (s or "").replace("\\", "\\\\").replace('"', '\\"')


def _contar_linhas_dados(caminho):
    """Conta as linhas de dados (que começam com `["`) do arquivo atual."""
    if not os.path.exists(caminho):
        return 0
    with open(caminho, encoding="utf-8") as f:
        return sum(1 for ln in f if re.match(r'\s*\["', ln))


def checar_sanidade(nome, qtd, caminho, tol=0.2):
    """Aborta o job se a extração vier vazia ou cair demais vs. o arquivo atual."""
    antigo = _contar_linhas_dados(caminho)
    if qtd == 0:
        sys.exit("[%s] ERRO: 0 súmulas extraídas — fonte fora do ar ou layout "
                 "mudou. Abortando sem alterar o arquivo." % nome)
    if antigo and qtd < antigo * (1 - tol):
        sys.exit("[%s] ERRO: queda suspeita %d -> %d (> %d%%). Provável quebra "
                 "de parsing. Abortando." % (nome, antigo, qtd, int(tol * 100)))
    print("[%s] OK: %d súmulas (anterior: %d)." % (nome, qtd, antigo))


def escrever_dados(caminho, header, fonte, linhas, map_body):
    """Grava o arquivo data/*.js no formato exato (UTF-8, LF, sem BOM).

    linhas: lista de listas de strings já na ordem final (ex.: [["1","Vigente","texto"], ...]).
    map_body: corpo do `data.map(function (r) { ... })` (uma linha 'return {...};').
    """
    out = [header, "(function () {", '  var F = "%s";' % js_str(fonte), "  var data = ["]
    for r in linhas:
        campos = ",".join('"' + js_str(c) + '"' for c in r)
        out.append("    [%s]," % campos)
    if linhas:
        out[-1] = out[-1].rstrip(",")  # última linha sem vírgula
    out.append("  ];")
    out.append("  var out = data.map(function (r) {")
    out.append("    " + map_body)
    out.append("  });")
    out.append("  window.ENTRIES = (window.ENTRIES || []).concat(out);")
    out.append("})();")
    texto = "\n".join(out) + "\n"
    with open(caminho, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    print("[%s] gravado: %s" % (os.path.basename(caminho), caminho))
