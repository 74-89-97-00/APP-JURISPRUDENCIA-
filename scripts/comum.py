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
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")

# Conjunto de cabeçalhos que imita um navegador real. O WAF do STF responde 403
# a requisições "cruas" (curl/proxies com poucos headers), mas LIBERA quando vê
# um navegador — daí o leque abaixo (descoberto em 2026-05-31). Não atrapalha
# as demais fontes.
HEADERS_NAVEGADOR = [
    "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,"
          "image/avif,image/webp,*/*;q=0.8",
    "-H", "Accept-Language: pt-BR,pt;q=0.9,en;q=0.8",
    "-H", 'sec-ch-ua: "Chromium";v="124", "Google Chrome";v="124", '
          '"Not-A.Brand";v="99"',
    "-H", 'sec-ch-ua-mobile: ?0',
    "-H", 'sec-ch-ua-platform: "Windows"',
    "-H", "Sec-Fetch-Dest: document",
    "-H", "Sec-Fetch-Mode: navigate",
    "-H", "Sec-Fetch-Site: none",
    "-H", "Sec-Fetch-User: ?1",
    "-H", "Upgrade-Insecure-Requests: 1",
]


def tmp(nome):
    return os.path.join(tempfile.gettempdir(), nome)


# Proxy público (fetch server-side por IP não bloqueado). Usado como recurso
# quando a fonte bloqueia IPs de datacenter — caso do TST no GitHub Actions.
PROXY = "https://api.codetabs.com/v1/proxy/?quest="


def _curl(url, destino):
    cmd = ["curl", "-sSL", "--fail", "--retry", "2", "--retry-delay", "3",
           "-m", "300", "--compressed",
           "-A", UA] + HEADERS_NAVEGADOR + ["-o", destino, url]
    r = subprocess.run(cmd)
    if r.returncode == 60:
        # curl 60 = cadeia de certificado incompleta no runner. Repete sem
        # verificar o certificado (arquivo público, somente leitura).
        r = subprocess.run(cmd + ["-k"])
    return r.returncode


def _integro(caminho, min_bytes=0, tipo=None):
    """Valida o arquivo baixado: existe, tem tamanho mínimo e, se for PDF, traz
    o header %PDF (proxies às vezes truncam ou devolvem uma página HTML)."""
    if not os.path.exists(caminho) or os.path.getsize(caminho) < min_bytes:
        return False
    if tipo == "pdf":
        try:
            with open(caminho, "rb") as f:
                if f.read(4) != b"%PDF":
                    return False
        except OSError:
            return False
    return True


def baixar(url, destino, min_bytes=0, tipo=None, tentativas=3):
    """Baixa um arquivo de forma resiliente. Tenta direto (curl) e, se a fonte
    bloquear o IP do runner (caso do TST), via proxy público (codetabs) — com
    algumas TENTATIVAS por fonte e VALIDAÇÃO de integridade (tamanho mínimo e,
    para PDF, o header %PDF). Isso cobre o proxy que esporadicamente trunca ou
    devolve HTML. Esgotadas as tentativas sem um arquivo íntegro, lança exceção.

    Usamos curl e não requests de propósito: alguns WAFs (STF) barram o requests
    pela impressão digital TLS mas deixam o curl passar.
    """
    ultimo = -1
    for fonte in (url, PROXY + url):
        for _ in range(max(1, tentativas)):
            ultimo = _curl(fonte, destino)
            if ultimo == 0 and _integro(destino, min_bytes, tipo):
                return destino
            if ultimo != 0:
                break  # fonte indisponível/bloqueada: não insiste, vai ao proxy
    raise RuntimeError(
        "falha ao baixar %s (curl %d / integridade)" % (url, ultimo))


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


def dehifenizar(s):
    """Junta palavras quebradas por hífen no fim da linha (livros em PDF).

    'tare-\\nfas' -> 'tarefas'; 'APOSEN-\\nTADORIA' -> 'APOSENTADORIA'. Mantém o
    hífen apenas na fronteira de composto minúscula→Maiúscula, p.ex.
    '(ex-\\nSúmula' -> '(ex-Súmula' — evitando manter hífen em palavra toda
    maiúscula só por causa da quebra de linha."""
    def junta(m):
        prev, nxt = m.group(1), m.group(2)
        sep = "-" if (prev.islower() and nxt.isupper()) else ""
        return prev + sep + nxt
    return re.sub(r'(\w)-[ \t]*\n[ \t\f]*(\w)', junta, s or "")


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


def numeros_de_dados(caminho, col=0):
    """Devolve o conjunto de números (campo `col`) das linhas de dados atuais.

    Usado pelos parsers INCREMENTAIS para saber quais súmulas já existem e não
    devem ser reescritas (preservando tema/data curados à mão)."""
    nums = set()
    if not os.path.exists(caminho):
        return nums
    with open(caminho, encoding="utf-8") as f:
        for ln in f:
            m = re.match(r'\s*\[' + r'\s*,'.join([r'"([^"]*)"'] * (col + 1)), ln)
            if m:
                nums.add(m.group(col + 1))
    return nums


def _numero_da_linha(linha):
    m = re.match(r'\s*\["(\d+)"', linha)
    return int(m.group(1)) if m else None


def inserir_ordenado(caminho, nome, novos):
    """Mescla súmulas NOVAS num arquivo data/*.js preservando as linhas atuais.

    `novos` é um dict {numero(int): literal} onde literal é o conteúdo da linha
    sem indentação nem vírgula, ex.: '["464","Vigente","texto"]'. Só entram
    números que ainda não existem no arquivo. A ordem (crescente/decrescente) é
    detectada das linhas atuais e mantida; as linhas existentes têm o conteúdo
    preservado byte a byte (só a vírgula final é renormalizada). Devolve True se
    houve mudança."""
    with open(caminho, encoding="utf-8") as f:
        texto = f.read()
    abre = "var data = [\n"
    i0 = texto.find(abre)
    if i0 < 0:
        sys.exit("[%s] ERRO: 'var data = [' não encontrado em %s." % (nome, caminho))
    ini = i0 + len(abre)
    fim = texto.find("];", ini)
    if fim < 0:
        sys.exit("[%s] ERRO: fim do array '];' não encontrado em %s." % (nome, caminho))
    # recua até o início da linha que contém '];'
    fim_linha = texto.rfind("\n", ini, fim) + 1

    atuais = [l for l in texto[ini:fim_linha].split("\n") if l.strip()]
    existentes = {_numero_da_linha(l) for l in atuais}
    novos = {n: v for n, v in novos.items() if n not in existentes}
    if not novos:
        print("[%s] nenhuma súmula nova; arquivo inalterado." % nome)
        return False

    nums = [_numero_da_linha(l) for l in atuais]
    desc = len(nums) >= 2 and (nums[0] or 0) > (nums[-1] or 0)

    comb = [(_numero_da_linha(l), l.rstrip().rstrip(",")) for l in atuais]
    for n, v in sorted(novos.items()):
        comb.append((n, "    " + v))
    comb.sort(key=lambda t: (t[0] is None, t[0]), reverse=desc)

    corpo = ",\n".join(l for _, l in comb) + "\n"
    novo = texto[:ini] + corpo + texto[fim_linha:]
    with open(caminho, "w", encoding="utf-8", newline="\n") as f:
        f.write(novo)
    print("[%s] inseridas %d súmulas novas: %s"
          % (nome, len(novos), ", ".join(str(n) for n in sorted(novos))))
    return True


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
