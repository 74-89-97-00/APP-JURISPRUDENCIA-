# -*- coding: utf-8 -*-
"""Atualização INCREMENTAL de data/tst-sumulas.js a partir do livro oficial.

Fonte: Livro-Internet.pdf (TST), que reúne Súmulas + Orientações
Jurisprudenciais + Precedentes Normativos. Aqui só interessa a seção de
SÚMULAS, no início do livro, com verbetes marcados por `SUM-<N> <TÍTULO>`.

O texto do livro é "sujo" para reaproveitar como dado: palavras hifenizadas na
quebra de linha, cabeçalhos/rodapés de página e um bloco `Histórico:` com as
redações antigas ao fim de cada verbete. Por isso este parser é
NÃO-DESTRUTIVO e best-effort: apenas ANEXA súmulas cujo número ainda não existe
no arquivo (em ordem numérica), faz de-hifenização e remove Histórico + citações
de resolução. As linhas já curadas à mão são preservadas. O texto das súmulas
novas é melhor esforço — revise no PR antes de mesclar.
"""
import os
import re

import comum

URL = "http://www.tst.jus.br/documents/10157/63003/Livro-Internet.pdf"
ALVO = os.path.join("data", "tst-sumulas.js")

# Verbete: SUM-<N> seguido de TÍTULO em maiúsculas (evita o índice final, que
# usa títulos em caixa mista).
MARCADOR = re.compile(r'^[ \t\f]*SUM-(\d+)\s+([A-ZÀ-Ý].*)$')
# Fim da seção de súmulas: começam os VERBETES de Orientações (OJ-SDI/OJ-SDC) ou
# Precedentes (PN-<n>). Exige o hífen para não casar com referências inline do
# tipo "OJ nº 292 da SBDI-I" que aparecem dentro do texto das súmulas.
FIM_SECAO = re.compile(r'^[ \t\f]*(OJ-S|PN-\d)', re.I)
HISTORICO = re.compile(r'^[ \t\f]*Histórico:', re.I)
# Ruído de página: cabeçalho corrido e número de página (ex.: "A-83").
RUIDO = re.compile(
    r'^[ \t\f]*(SÚMULAS\b|Súmulas\s+SÚMULAS|[A-Z]-\d+\s*$|\d+\s*$)')

# Marcas editoriais de situação no título e citações de resolução a remover.
# Parêntese editorial logo após o título: "(mantida)", "(cancelada)",
# "(nova redação para o item I ...)". Cada palavra-chave pode ser seguida de
# texto até o ")" que fecha (ex.: "(nova redação para o item I e acrescidos...)").
SITU_TAG = re.compile(
    r'\(\s*(cancelad[oa]|revogad[oa]|mantida|nova\s+redação|redação|'
    r'convertid[oa]|incorporad[oa]|atualizad[oa]|alterad[oa]|inserid[oa])'
    r'[^)]*\)', re.I)
# "- Res. 121/2003, DJ 19, 20 e 21.11.2003" / "Res. 207/2016, DEJT divulgado em
# 18, 19 e 20.04.2016" — para no primeiro caractere MAIÚSCULO (início do
# enunciado, ex.: "O trabalhador..."/"I - ...").
CITACAO = re.compile(
    r'[-–—]?\s*Res\.?\s*\d+/\d+[^A-ZÀ-Ý]*?(?:DJ|DEJT)\b[^A-ZÀ-Ý]*?\d{4}[^A-ZÀ-Ý]*',
    re.I)


def parsear(texto):
    """Devolve {numero(int): (situacao, texto)} da seção de súmulas."""
    itens = {}
    num = None
    buf = []
    hist = False
    iniciou = False
    for ln in texto.split("\n"):
        ln = ln.replace("\r", "")
        if num is not None and FIM_SECAO.match(ln):
            itens[num] = buf
            num = None
            break  # acabou a seção de súmulas
        m = MARCADOR.match(ln)
        if m:
            if num is not None:
                itens[num] = buf
            num = int(m.group(1))
            buf = [m.group(2)]
            hist = False
            iniciou = True
            continue
        if num is None:
            continue
        if HISTORICO.match(ln):
            hist = True
            continue
        if hist or RUIDO.match(ln):
            continue
        buf.append(ln)
    if num is not None:
        itens[num] = buf
    if not iniciou:
        return {}

    out = {}
    for n, linhas in itens.items():
        bruto = comum.dehifenizar("\n".join(linhas))
        bruto = comum.colapsar(bruto)
        if not bruto:
            continue
        cabeca = bruto[:300].lower()
        if re.search(r'\(cancelad', cabeca):
            situ = "Cancelada"
        elif re.search(r'\(revogad', cabeca):
            situ = "Revogada"
        else:
            situ = "Vigente"
        texto_s = CITACAO.sub("", SITU_TAG.sub("", bruto))
        texto_s = comum.colapsar(texto_s)
        out[n] = (situ, texto_s)
    return out


def main():
    pdf = comum.tmp("tst.pdf")
    txt = comum.tmp("tst.txt")
    # min_bytes alto + tipo="pdf": o TST barra o IP do runner (só o proxy
    # alcança) e o proxy às vezes trunca; só aceita o livro COMPLETO (~3,5 MB).
    comum.baixar(URL, pdf, min_bytes=3_400_000, tipo="pdf")
    texto = comum.pdf_para_texto(pdf, txt)
    sumulas = parsear(texto)
    if not sumulas:
        import sys
        sys.exit("[TST] ERRO: 0 súmulas extraídas — fonte fora do ar ou layout "
                 "mudou. Abortando sem alterar o arquivo.")

    existentes = comum.numeros_de_dados(ALVO)
    novos = {}
    for n, (situ, txt_s) in sumulas.items():
        if str(n) in existentes or not txt_s:
            continue
        campos = [str(n), situ, txt_s]  # numero, situacao, texto
        novos[n] = "[" + ",".join('"' + comum.js_str(c) + '"' for c in campos) + "]"

    print("[TST] livro: %d súmulas; base: %d; novas: %d."
          % (len(sumulas), len(existentes), len(novos)))
    comum.inserir_ordenado(ALVO, "TST", novos)


if __name__ == "__main__":
    main()
