# -*- coding: utf-8 -*-
"""Regenera data/tjrj-sumulas.js a partir do PDF de súmulas do TJRJ.

Layout do PDF (validado): cada verbete começa em início de linha (às vezes
precedido por form-feed de quebra de página) com:
    Nº. <N> "<verbete...>"
seguido por uma linha "Referência: ...". O verbete termina antes de
"Referência". Cancelamentos aparecem como "VERBETE SUMULAR CANCELADO ...".
As referências internas usam "nº." minúsculo, então o marcador exige "Nº"
maiúsculo para não dar falso positivo.
"""
import os
import re

import comum

URL = "https://www.tjrj.jus.br/documents/10136/4837891/sumulas.pdf"
HEADER = ("// Súmulas do TJRJ (Súmula da Jurisprudência Predominante). Situação "
          "conforme fonte; conferir no portal do TJRJ antes de citar.")
ALVO = os.path.join("data", "tjrj-sumulas.js")
MAP_BODY = ('return { id: "tjrj-sumula-" + r[0], tribunal: "TJRJ", tipo: '
            '"Súmula", numero: r[0], data: "", tema: "", situacao: r[1], '
            'texto: r[2], fonte: F };')

MARCADOR = re.compile(r'^[ \t\f]*Nº\.?\s*(\d+)\s+(.*)$')
ASPAS_INI = '“"\'' + " "
ASPAS_FIM = '”"\'' + " "


def parsear(texto):
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

    linhas = []
    for n in sorted(itens):
        bloco = comum.colapsar(" ".join(itens[n]))
        cancelada = "VERBETE SUMULAR CANCELADO" in bloco.upper()
        # verbete = tudo antes de "Referência" (e antes de eventual nota de cancelamento)
        verbete = re.split(r'Referência', bloco, maxsplit=1)[0]
        verbete = re.split(r'VERBETE SUMULAR CANCELADO', verbete, maxsplit=1)[0]
        verbete = verbete.strip().lstrip(ASPAS_INI).rstrip(ASPAS_FIM).strip()
        situ = "Cancelada" if cancelada else "Vigente"
        linhas.append([str(n), situ, verbete])
    return linhas


def main():
    pdf = comum.tmp("tjrj.pdf")
    txt = comum.tmp("tjrj.txt")
    comum.baixar(URL, pdf)
    texto = comum.pdf_para_texto(pdf, txt)
    linhas = parsear(texto)
    comum.checar_sanidade("TJRJ", len(linhas), ALVO)
    comum.escrever_dados(ALVO, HEADER, URL, linhas, MAP_BODY)


if __name__ == "__main__":
    main()
