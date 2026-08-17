#!/usr/bin/perl
# Gera data/tjdft-*.js — Súmulas do TJDFT, das páginas oficiais (Plone, HTML
# inline, texto direto na página):
#   Pleno:    /consultas/jurisprudencia/sumulas/sumulas-do-tjdft
#   Juizados: /consultas/jurisprudencia/sumulas/sumulas-do-juizado-especial
#
# Cada súmula é um cabeçalho "Súmula nº N" seguido do enunciado. O status vem
# junto do cabeçalho: entre parênteses no Pleno ("(cancelada)", "(alterada)")
# ou após traço nos Juizados ("Súmula nº 2 – Cancelada"). Linhas "Observação :"
# trazem a nota de cancelamento/alteração e não entram no enunciado.
#
# Uso: perl scripts/gerar_tjdft.pl <pagina.html> <saida.js> <FONTE> <idprefix> [tema]
# Best-effort; confira no portal do TJDFT antes de citar.
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":encoding(UTF-8)");

my ($HTML, $SAIDA, $FONTE, $IDPREF, $TEMA) = @ARGV;
die "uso: perl gerar_tjdft.pl <pagina.html> <saida.js> <FONTE> <idprefix> [tema]\n"
  unless $HTML && $SAIDA && $FONTE && $IDPREF;
$TEMA //= "";

open my $fh, "<:encoding(UTF-8)", $HTML or die "não abriu $HTML: $!";
local $/; my $h = <$fh>; close $fh;

# HTML -> texto, com quebra de linha ANTES e DEPOIS de cada bloco (os títulos
# ficam em <h2>/<h3> que podem vir grudados no texto anterior).
$h =~ s/<script.*?<\/script>//gis;
$h =~ s/<style.*?<\/style>//gis;
$h =~ s/<(p|div|h[1-6]|li|tr|section)[^>]*>/\n/gi;
$h =~ s/<\/(p|div|h[1-6]|li|tr|section)>/\n/gi;
$h =~ s/<br[^>]*>/\n/gi;
$h =~ s/<[^>]+>/ /g;
$h =~ s/&nbsp;|&#160;/ /g;
$h =~ s/&#(\d+);/chr($1)/ge;
$h =~ s/&amp;/\&/g; $h =~ s/&lt;/</g; $h =~ s/&gt;/>/g; $h =~ s/&quot;/"/g; $h =~ s/&#39;/'/g;
$h =~ s/[ \t]+/ /g;

sub limpa { my ($t)=@_; $t//=""; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; return $t; }
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

# Rodapé/menu institucional que aparece depois da última súmula.
my $FIM = qr/^(Precedentes Qualificados|Di[áa]rio de Justi[çc]a|Compartilh|Fale com|
  Voltar|Mapa do [Ss]ite|Este conte[úu]do|Navega[çc][ãa]o|Acesso [àa]|Institucional|
  Servi[çc]os|Transpar[êe]ncia|Corregedoria|Ouvidoria|Portal|Reda[çc][ãa]o dada|
  P[áa]gina inicial)\b/xi;

my (%sum, @ordem, $cur, @buf);
my $started = 0;
for my $ln (split /\n/, $h) {
  $ln = limpa($ln);
  next if $ln eq "";
  # Marcador de súmula. Status opcional entre parênteses OU após "–"/"-".
  if ($ln =~ /^S[úu]mula\s+n[º°.o]*\s*(\d+)\s*(?:\(\s*(.*?)\s*\)|[–-]\s*(.*?))?\s*$/i) {
    $sum{$cur}{texto} = join(" ", @buf) if defined $cur;
    $cur = $1;
    push @ordem, $cur unless exists $sum{$cur};
    my $st = limpa(($2 // "") . " " . ($3 // ""));
    # "alterada - vd. súmula 20" / "vd. súmula 21": renumerada -> Substituída
    # (não vigente). "alterada" sozinha: é a versão em vigor atualizada -> Vigente.
    my $alt_ref = ($st =~ /alterad/i && $st =~ /(vd|s[úu]mula\s*\d+|n[úu]mero\s*\d+)/i);
    $sum{$cur}{situ} =
        $st =~ /cancel/i    ? "Cancelada"
      : $st =~ /revog/i     ? "Revogada"
      : $st =~ /prejudic/i  ? "Prejudicada"
      : $alt_ref            ? "Substituída"
      : $st =~ /substitu/i  ? "Substituída"
      : "Vigente";
    @buf = ();
    $started = 1;
    next;
  }
  next unless $started && defined $cur;
  last if $ln =~ $FIM;            # começou o rodapé: encerra
  next if $ln =~ /^Observa[çc][ãa]o\s*:/i;   # nota de status, não é enunciado
  push @buf, $ln;
}
$sum{$cur}{texto} = join(" ", @buf) if defined $cur;

my @out;
for my $n (@ordem) {
  my $texto = limpa($sum{$n}{texto} // "");
  next if length($texto) < 15;   # cancelada sem texto: descarta
  push @out, [ $n, $sum{$n}{situ} || "Vigente", $texto ];
}

die "[TJDFT:$IDPREF] poucas súmulas (" . scalar(@out) . "); abortando.\n" if @out < 3;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJDFT ($IDPREF). Situação conforme fonte; conferir no portal antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var T = \"" . js_str($TEMA) . "\";\n";
print $o "  var P = \"$IDPREF\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\"],\n", js_str($r->[0]), js_str($r->[1]), js_str($r->[2]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: P + \"-\" + r[0], tribunal: \"TJDFT\", tipo: \"Súmula\", numero: r[0], data: \"\", tema: T, situacao: r[1], texto: r[2], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$_->[1]}++ for @out;
print "[TJDFT:$IDPREF] $SAIDA: ", scalar(@out), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
