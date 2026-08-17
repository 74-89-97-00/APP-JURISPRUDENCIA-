#!/usr/bin/perl
# Gera data/tjms-sumulas.js — Súmulas do TJMS, da página oficial
# (tjms.jus.br/sumulas). HTML inline (uma tabela): cada súmula é uma linha com
# "<b>Súmula N</b>", a data de julgamento, a publicação (DJMS), o enunciado e,
# por fim, o Incidente de Uniformização de origem.
#
# Uso: perl scripts/gerar_tjms.pl <pagina.html>
# Best-effort; confira no portal do TJMS antes de citar.
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":encoding(UTF-8)");

my $HTML = $ARGV[0] or die "uso: perl gerar_tjms.pl <pagina.html>\n";
my $SAIDA = "data/tjms-sumulas.js";
my $FONTE = "https://www.tjms.jus.br/sumulas";

open my $fh, "<:encoding(UTF-8)", $HTML or die "não abriu $HTML: $!";
local $/; my $h = <$fh>; close $fh;

# Isola o marcador "<b>Súmula N</b>" (fica inline dentro da célula) e quebra os
# blocos em linhas.
$h =~ s/<script.*?<\/script>//gis;
$h =~ s/<style.*?<\/style>//gis;
$h =~ s/<b>\s*(S[úu]mula\s*\d+)\s*<\/b>/\n===$1===\n/gis;
$h =~ s/<\/(td|tr|p|div|h[1-6]|li)>/\n/gi;
$h =~ s/<br[^>]*>/\n/gi;
$h =~ s/<[^>]+>/ /g;
$h =~ s/&nbsp;|&#160;/ /g;
$h =~ s/&#(\d+);/chr($1)/ge;
$h =~ s/&amp;/\&/g; $h =~ s/&lt;/</g; $h =~ s/&gt;/>/g; $h =~ s/&quot;/"/g; $h =~ s/&#39;/'/g;
$h =~ s/[ \t]+/ /g;

sub limpa { my ($t)=@_; $t//=""; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; return $t; }
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

# Rodapé institucional depois da última súmula.
my $FIM = qr/^(Tribunal de Justi[çc]a de Mato|Hor[áa]rio de Funcionamento|COMARCAS|
  Telefones|Balc[ãa]o Virtual|Termo de Uso|E-mail\s*:|Av\.\s*Mato Grosso)\b/xi;

my (%sum, @ordem, $cur, @buf, $fim_enunciado);
my $started = 0;
for my $ln (split /\n/, $h) {
  $ln = limpa($ln);
  next if $ln eq "";
  if ($ln =~ /^===S[úu]mula\s+(\d+)===$/) {
    $sum{$cur}{texto} = join(" ", @buf) if defined $cur;
    $cur = $1;
    push @ordem, $cur unless exists $sum{$cur};
    $sum{$cur}{situ} = "Vigente";
    @buf = (); $fim_enunciado = 0; $started = 1;
    next;
  }
  next unless $started && defined $cur;
  last if $ln =~ $FIM;
  # Data de julgamento.
  if ($ln =~ /^Julgamento\s+(\d{2}\/\d{2}\/\d{4})/) { $sum{$cur}{data} = $1; next; }
  next if $ln =~ /^DJMS\b/i || $ln =~ /^DJ\s/i;    # publicação: descarta
  # O Incidente de origem encerra o enunciado (fica fora do texto).
  if ($ln =~ /^Incidente de Uniformiza/i) { $fim_enunciado = 1; next; }
  next if $fim_enunciado;
  # Status raro (caso venha a existir marcação).
  $sum{$cur}{situ} = "Cancelada"  if $ln =~ /cancelad/i;
  $sum{$cur}{situ} = "Revogada"   if $ln =~ /revogad/i;
  push @buf, $ln;
}
$sum{$cur}{texto} = join(" ", @buf) if defined $cur;

my @out;
for my $n (@ordem) {
  my $texto = limpa($sum{$n}{texto} // "");
  next if length($texto) < 15;
  push @out, [ $n, $sum{$n}{data} || "", $sum{$n}{situ} || "Vigente", $texto ];
}

die "[TJMS] poucas súmulas (" . scalar(@out) . "); abortando.\n" if @out < 3;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJMS. Situação conforme fonte; conferir no portal do TJMS antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\",\"%s\"],\n",
    js_str($r->[0]), js_str($r->[1]), js_str($r->[2]), js_str($r->[3]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjms-sumula-\" + r[0], tribunal: \"TJMS\", tipo: \"Súmula\", numero: r[0], data: r[1], tema: \"\", situacao: r[2], texto: r[3], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$_->[2]}++ for @out;
print "[TJMS] $SAIDA: ", scalar(@out), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
