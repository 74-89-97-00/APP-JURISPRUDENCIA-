# -*- coding: utf-8 -*-
"""Atualização INCREMENTAL de data/stj-sumulas.js.

A base do app (676..1) é curada à mão, com `tema` e `data` preenchidos. A fonte
oficial em PDF (VerbetesSTJ.pdf) traz apenas número + texto e costuma estar
atrasada em relação à base. Por isso este parser é NÃO-DESTRUTIVO: apenas ANEXA
súmulas cujo número ainda não existe no arquivo, no topo do array (ordem
decrescente). As linhas já curadas são preservadas byte a byte — nada de
sobrescrever tema/data/situação trabalhados à mão.

Como hoje o PDF está na 673 < 676 (base do app), a primeira execução não
adiciona nada — comportamento esperado e seguro.
"""
import os
import re
import sys

import comum

URL = "https://scon.stj.jus.br/docs_internet/VerbetesSTJ.pdf"
ALVO = os.path.join("data", "stj-sumulas.js")

# Marcador só com SÚMULA maiúsculo no início da linha (após espaços/quebra de
# página), para não casar com referências internas em minúsculas.
MARCADOR = re.compile(r'^[ \t\f]*SÚMULA\s+(\d+)\s*(.*)$')


def parsear(texto):
    """Devolve {numero(int): texto} extraído do PDF."""
    itens = {}
    num = None
    buf = []
    for ln in texto.split("\n"):
        ln = ln.replace("\r", "")
        m = MARCADOR.match(ln)
        if m:
            if num is not None:
                itens[num] = buf
            num = int(m.group(1))
            buf = [m.group(2)]
        elif num is not None:
            buf.append(ln)
    if num is not None:
        itens[num] = buf

    out = {}
    for n, linhas in itens.items():
        texto_s = comum.colapsar(" ".join(linhas))
        # "VEJA MAIS" marca o link de jurisprudência ao fim do verbete: corta.
        texto_s = re.split(r'VEJA\s+MAIS', texto_s, maxsplit=1, flags=re.I)[0].strip()
        if texto_s:
            out[n] = texto_s
    return out


def main():
    pdf = comum.tmp("stj.pdf")
    txt = comum.tmp("stj.txt")
    comum.baixar(URL, pdf)
    texto = comum.pdf_para_texto(pdf, txt)
    sumulas = parsear(texto)
    if not sumulas:
        sys.exit("[STJ] ERRO: 0 súmulas extraídas — fonte fora do ar ou layout "
                 "mudou. Abortando sem alterar o arquivo.")

    existentes = comum.numeros_de_dados(ALVO)
    novos = {}
    for n, txt in sumulas.items():
        if str(n) in existentes:
            continue
        situ = "Cancelada" if re.match(r'CANCELAD', txt, re.I) else "Vigente"
        campos = [str(n), "", "", situ, txt]  # numero, data, tema, situacao, texto
        novos[n] = "[" + ",".join('"' + comum.js_str(c) + '"' for c in campos) + "]"

    print("[STJ] PDF: %d súmulas; base: %d; novas: %d."
          % (len(sumulas), len(existentes), len(novos)))
    comum.inserir_ordenado(ALVO, "STJ", novos)


if __name__ == "__main__":
    main()
