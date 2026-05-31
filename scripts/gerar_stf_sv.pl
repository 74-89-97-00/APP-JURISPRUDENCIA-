#!/usr/bin/perl
# Atualiza data/stf-vinculantes.js com Súmulas Vinculantes NOVAS do STF.
#
# Fonte: artigo "Lista de súmulas vinculantes editadas pelo STF" da Wikipédia
# em português, obtido pela API MediaWiki (action=parse&prop=wikitext). É uma
# fonte ESTRUTURADA e SEM WAF — ao contrário do portal/arquivo do STF, que
# bloqueia curl/proxies até de IP residencial. As SVs comuns do STF estão
# congeladas; as VINCULANTES é que crescem (~1/ano), e este parser as capta.
#
# É INCREMENTAL: preserva byte a byte as entradas já curadas (com tema/área)
# e só acrescenta os números que ainda não existem no arquivo. Novas entradas
# vêm com tema vazio (a classificar) — o app já avisa para conferir a íntegra.
#
# Uso: perl gerar_stf_sv.pl wiki.json data/stf-vinculantes.js
use strict;
use warnings;
use utf8;
use JSON::PP;
binmode STDOUT, ":encoding(UTF-8)";

my $arq_json = shift @ARGV or die "uso: gerar_stf_sv.pl wiki.json data/stf-vinculantes.js\n";
my $alvo     = shift @ARGV || "data/stf-vinculantes.js";

open my $jf, "<:raw", $arq_json or die "abrir $arq_json: $!";
my $payload = do { local $/; <$jf> };
close $jf;
my $wiki = JSON::PP->new->utf8->decode($payload)->{parse}{wikitext}
    or die "JSON sem parse.wikitext (resposta da API inválida?)\n";

my %MES = (janeiro=>1, fevereiro=>2, "março"=>3, abril=>4, maio=>5, junho=>6,
           julho=>7, agosto=>8, setembro=>9, outubro=>10, novembro=>11, dezembro=>12);

sub limpa_data {
    my $d = shift // "";
    # "16 de dezembro de 2024" / "1º de dezembro de 2008" -> 16/12/2024
    if ($d =~ /(\d{1,2})\s*[º°]?\s*de\s+([a-zç]+)\s+de\s+(\d{4})/i) {
        my ($dia, $mes, $ano) = ($1, lc $2, $3);
        my $m = $MES{$mes} or return "";
        return sprintf("%02d/%02d/%04d", $dia, $m, $ano);
    }
    return "";
}

sub limpa_texto {
    my $t = shift // "";
    $t =~ s/<ref[^>]*\/>//gis;                 # <ref .../>
    $t =~ s/<ref[^>]*>.*?<\/ref>//gis;         # <ref>...</ref>
    1 while $t =~ s/\{\{[^{}]*\}\}//gs;          # {{templates}} (aninhados)
    $t =~ s/\[\[[^\]|]*\|([^\]]*)\]\]/$1/g;     # [[alvo|rótulo]] -> rótulo
    $t =~ s/\[\[([^\]]*)\]\]/$1/g;               # [[alvo]] -> alvo
    $t =~ s/'''?//g;                              # negrito/itálico
    $t =~ s/<br\s*\/?>/ /gi;                      # <br> -> espaço
    $t =~ s/<[^>]+>//g;                           # demais tags
    $t =~ s/&nbsp;/ /gi;
    $t =~ s/\s+/ /g;                              # colapsa
    $t =~ s/^\s+|\s+$//g;
    return $t;
}

# --- extrai as SVs da tabela wikitable ---
my %sv;   # num => { texto, data }
while ($wiki =~ /\n\|-\s*\n\|\s*(.*?)\s*\n\|\s*(?:width=\d+\s*\|\s*)?(.*?)\n\|\s*(?:width=\d+\s*\|\s*)?(.*?)\n/sg) {
    my ($cel_num, $cel_txt, $cel_data) = ($1, $2, $3);
    (my $num = $cel_num) =~ s/.*\|//;   # tira prefixo de wikilink [[x|11]]
    $num =~ s/\D//g;
    next unless length $num;
    my $texto = limpa_texto($cel_txt);
    next unless length($texto) > 20;     # linha de cabeçalho/ruído
    $sv{$num} = { texto => $texto, data => limpa_data($cel_data) };
}

my $achadas = scalar keys %sv;
die "[stf-sv] ERRO: só $achadas SVs extraídas da Wikipédia (< 55). Layout da "
  . "tabela mudou? Abortando sem alterar o arquivo.\n" if $achadas < 55;

# --- lê o arquivo atual e descobre o que já existe ---
open my $af, "<:encoding(UTF-8)", $alvo or die "abrir $alvo: $!";
my $txt = do { local $/; <$af> };
close $af;
my %existe;
$existe{$1} = 1 while $txt =~ /id:\s*"stf-sv-(\d+)"/g;

my @novas = sort { $a <=> $b } grep { !$existe{$_} } keys %sv;
if (!@novas) {
    print "[stf-sv] OK: $achadas SVs na fonte; nenhuma nova (arquivo já em dia).\n";
    exit 0;
}

# --- monta as entradas novas no formato exato do arquivo ---
my $FONTE = "https://portal.stf.jus.br/jurisprudencia/sumariosumulas.asp?base=26";
my @blocos;
for my $n (@novas) {
    my $texto = $sv{$n}{texto};
    $texto =~ s/\\/\\\\/g; $texto =~ s/"/\\"/g;
    # SV recém-editada é quase sempre Vigente; mapeia se a fonte sinalizar baixa.
    my $low = lc $sv{$n}{texto};
    my $situ = $low =~ /cancelad/ ? "Cancelada"
             : $low =~ /revogad/  ? "Revogada"
             : $low =~ /superad/  ? "Superada" : "Vigente";
    push @blocos,
        qq(  { id: "stf-sv-$n", tribunal: "STF", tipo: "Súmula Vinculante", numero: "$n", tema: "", data: "$sv{$n}{data}", situacao: "$situ", fonte: "$FONTE",\n)
      . qq(    texto: "$texto" });
}
my $insercao = join(",\n", @blocos);

# insere antes do fechamento "]);", colocando vírgula após a última entrada atual
$txt =~ s/\n\]\);\s*$//s or die "[stf-sv] ERRO: não achei o fechamento ']);' em $alvo.\n";
$txt =~ s/\s+$//s;
$txt .= ",\n" . $insercao . "\n]);\n";

# atualiza o carimbo de data, se existir
my @lt = localtime; my $hoje = sprintf("%02d/%02d/%04d", $lt[3], $lt[4]+1, $lt[5]+1900);
$txt =~ s/window\.DATA_UPDATED\s*=\s*"[^"]*";/window.DATA_UPDATED = "$hoje";/;

open my $of, ">:encoding(UTF-8)", $alvo or die "gravar $alvo: $!";
print $of $txt;
close $of;
print "[stf-sv] inseridas ", scalar(@novas), " SV(s) nova(s): ", join(", ", @novas), "\n";
