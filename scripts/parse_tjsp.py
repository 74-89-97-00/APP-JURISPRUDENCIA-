# -*- coding: utf-8 -*-
"""Regenera data/tjsp-sumulas.js a partir do PDF consolidado do TJSP.

Layout do PDF (validado): cada súmula começa em início de linha com
    Súmula <N>: <texto...>   (ou "Súmula <N> - <texto>")
O texto pode quebrar em várias linhas até o próximo marcador. Rodapés de
página no formato "-N-" são descartados. Revogadas têm corpo "REVOGADA (...)".
"""
import os
import re

import comum

URL = ("https://www.tjsp.jus.br/Download/Portal/Biblioteca/Biblioteca/"
       "Legislacao/SumulasTJSP.pdf")
HEADER = ("// Súmulas do TJSP. Situação conforme fonte; conferir no portal do "
          "TJSP antes de citar.")
ALVO = os.path.join("data", "tjsp-sumulas.js")
MAP_BODY = ('return { id: "tjsp-sumula-" + r[0], tribunal: "TJSP", tipo: '
            '"Súmula", numero: r[0], data: "", tema: "", situacao: r[1], '
            'texto: r[2], fonte: F };')

MARCADOR = re.compile(r'^[ \t\f]*Súmula\s+(\d+)\s*[:\-–—]\s*(.*)$')
RODAPE = re.compile(r'^\s*-\d+-\s*$')

# Cabeçalho/rodapé que se repete em toda página do PDF e pode cair no meio de
# uma súmula que atravessa a quebra de página. Comparado com a linha já "strip".
BOILERPLATE = {
    "TRIBUNAL DE JUSTIÇA DO ESTADO DE SÃO PAULO",
    "Serviço de Gestão de Legislação",
    "PODER JUDICIÁRIO",
    "Diretoria de Gestão do Conhecimento Judiciário",
}


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
            if RODAPE.match(ln) or ln.strip() in BOILERPLATE:
                continue
            buf.append(ln)
    if num is not None:
        itens[num] = buf

    linhas = []
    for n in sorted(itens):
        texto_s = comum.colapsar(" ".join(itens[n]))
        situ = "Revogada" if re.match(r'REVOGAD', texto_s, re.I) else "Vigente"
        linhas.append([str(n), situ, texto_s])
    return linhas


def main():
    pdf = comum.tmp("tjsp.pdf")
    txt = comum.tmp("tjsp.txt")
    comum.baixar(URL, pdf)
    texto = comum.pdf_para_texto(pdf, txt)
    linhas = parsear(texto)
    comum.checar_sanidade("TJSP", len(linhas), ALVO)
    comum.escrever_dados(ALVO, HEADER, URL, linhas, MAP_BODY)


if __name__ == "__main__":
    main()
