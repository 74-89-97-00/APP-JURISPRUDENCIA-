# -*- coding: utf-8 -*-
"""Atualização INCREMENTAL de data/stf-sumulas.js (súmulas comuns/não vinculantes).

Fonte: compilação oficial "Súmula do STF — Versão Resumida" (enunciados 1 a 736).
O STF praticamente não edita mais súmulas COMUNS (as novas viram Súmulas
Vinculantes), então este parser é essencialmente uma rede de segurança: roda
todo mês e, na imensa maioria das vezes, não acrescenta nada.

Importante: a base do app traz `situação` curada à mão (320 "Superada", além de
"Alterada"/"Cancelada"/"Revogada") que NÃO existe nesta versão resumida. Por
isso o parser é NÃO-DESTRUTIVO: só ANEXA números que ainda não existem; nunca
reescreve as linhas curadas (senão 319 "Superada" virariam "Vigente").
"""
import os
import re
import sys

import comum

URL = ("https://www.stf.jus.br/arquivo/cms/jurisprudenciaSumula/anexo/"
       "Enunciados_Sumulas_STF_1_a_736_Resumido.pdf")
ALVO = os.path.join("data", "stf-sumulas.js")

# Marcador do corpo: "SÚMULA <N>" sozinho na linha (centralizado). Exigir a
# linha "só com o número" descarta as entradas do SUMÁRIO ("SÚMULA 1 __ 14").
MARCADOR = re.compile(r'^[ \t\f]*SÚMULA\s+(\d+)[ \t]*$')
# Ruído: números de página soltos e cabeçalho corrido da publicação.
RUIDO = re.compile(r'^[ \t\f]*(\d+|SÚMULA DO STF|Versão Resumida)[ \t]*$', re.I)
STATUS = re.compile(
    r'\(\s*(Superad[ao]|Cancelad[ao]|Revogad[ao]|Prejudicad[ao]|Alterad[ao])\s*\)',
    re.I)
CANON = {"superad": "Superada", "cancelad": "Cancelada", "revogad": "Revogada",
         "prejudicad": "Prejudicada", "alterad": "Alterada"}


def parsear(texto):
    """Devolve {numero(int): (situacao, texto)}."""
    itens = {}
    num = None
    buf = []
    iniciou = False
    for ln in texto.split("\n"):
        ln = ln.replace("\r", "")
        m = MARCADOR.match(ln)
        if m:
            if num is not None:
                itens[num] = buf
            num = int(m.group(1))
            buf = []
            iniciou = True
            continue
        if num is None or RUIDO.match(ln):
            continue
        buf.append(ln)
    if num is not None:
        itens[num] = buf
    if not iniciou:
        return {}

    out = {}
    for n, linhas in itens.items():
        bruto = comum.colapsar(" ".join(linhas))
        if not bruto:
            continue
        situ = "Vigente"
        ms = STATUS.search(bruto)
        if ms:
            chave = ms.group(1)[:-1].lower()  # remove última letra (a/o) p/ casar
            situ = CANON.get(chave, "Vigente")
        texto_s = comum.colapsar(STATUS.sub("", bruto))
        if texto_s:
            out[n] = (situ, texto_s)
    return out


def main():
    pdf = comum.tmp("stf.pdf")
    txt = comum.tmp("stf.txt")
    comum.baixar(URL, pdf, min_bytes=400_000, tipo="pdf")
    texto = comum.pdf_para_texto(pdf, txt)
    sumulas = parsear(texto)
    if not sumulas:
        sys.exit("[STF] ERRO: 0 súmulas extraídas — fonte fora do ar ou layout "
                 "mudou. Abortando sem alterar o arquivo.")

    existentes = comum.numeros_de_dados(ALVO)
    novos = {}
    for n, (situ, txt_s) in sumulas.items():
        if str(n) in existentes:
            continue
        campos = [str(n), situ, txt_s]  # numero, situacao, texto
        novos[n] = "[" + ",".join('"' + comum.js_str(c) + '"' for c in campos) + "]"

    print("[STF] PDF: %d súmulas; base: %d; novas: %d."
          % (len(sumulas), len(existentes), len(novos)))
    comum.inserir_ordenado(ALVO, "STF", novos)


if __name__ == "__main__":
    main()
