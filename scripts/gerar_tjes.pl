#!/usr/bin/perl
# Gera data/tjes-sumulas.js — Súmulas do TJES (Espírito Santo). As súmulas são
# posts WordPress; o índice fica em https://www.tjes.jus.br/sumulas/ e cada post
# tem o enunciado. O workflow baixa os posts pela API wp-json (endpoint
# ?include=<ids>) num único JSON e passa o arquivo aqui.
#
# Uso: perl scripts/gerar_tjes.pl tjes-posts.json
#
# Cada post: title "Súmula NN"; content com "... Enunciado <texto> Referência
# Legislativa ...". Best-effort; confira no portal do TJES.
use strict;
use warnings;
use utf8;
use JSON::PP;

my $JSON = $ARGV[0] or die "uso: perl gerar_tjes.pl <posts.json>\n";
my $SAIDA = "data/tjes-sumulas.js";
my $FONTE = "https://www.tjes.jus.br/sumulas/";

open my $f, "<:raw", $JSON or die "não abriu $JSON: $!";
local $/; my $arr = JSON::PP->new->utf8->decode(<$f>); close $f;
die "[TJES] resposta não é lista de posts.\n" unless ref $arr eq "ARRAY";

sub destag {
  my ($s) = @_; $s //= "";
  $s =~ s/<[^>]+>/ /g;
  $s =~ s/&#8220;|&#8221;|&#171;|&#187;|&quot;/"/g;
  $s =~ s/&#8217;|&#8216;|&#039;/'/g;
  $s =~ s/&#8211;|&#8212;/-/g;
  $s =~ s/&#176;|&ordm;/º/g;
  $s =~ s/&nbsp;/ /g; $s =~ s/&amp;/&/g; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g;
  $s =~ s/&#(\d+);/chr($1)/ge;
  $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
  return $s;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

my %sum;
for my $p (@$arr) {
  my $titulo = destag($p->{title}{rendered} // "");
  my ($num) = $titulo =~ /s[úu]mula\s+(?:n[ºo°.]*\s*)?0*(\d+)/i;
  next unless defined $num;
  my $corpo = destag($p->{content}{rendered} // "");

  # Dois formatos: posts antigos (súmulas 1-10) trazem "... Enunciado <texto>
  # Referência ..."; posts novos (11-23) trazem só o enunciado direto.
  my $texto;
  if ($corpo =~ /\bEnunciado\b\s*(.*?)\s*(?:Referência|Observaç|Precedente|Vide\b)/si) {
    $texto = $1;
  } else {
    $texto = $corpo;
  }
  $texto =~ s/^\s*s[úu]mula\s+(?:n[ºo°.]*\s*)?\d+\s*//i;   # tira "Súmula NN" repetido
  $texto =~ s/^[“”„"'«»\s]+//;                              # aspas curvas/retas à esquerda
  $texto =~ s/[“”„"'«»\s]+$//;                              # e à direita
  next if length($texto) < 15;

  my $situ = $corpo =~ /cancelad[ao]/i ? "Cancelada" : "Vigente";
  $sum{$num} = [$situ, $texto];
}

my @nums = sort { $a <=> $b } keys %sum;
die "[TJES] poucas súmulas (" . scalar(@nums) . "); abortando para não sobrescrever.\n" if @nums < 10;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJES. Situação conforme fonte; conferir no portal do TJES antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $n (@nums) {
  printf $o "    [\"%s\",\"%s\",\"%s\"],\n", $n, js_str($sum{$n}[0]), js_str($sum{$n}[1]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjes-sumula-\" + r[0], tribunal: \"TJES\", tipo: \"Súmula\", numero: r[0], data: \"\", tema: \"\", situacao: r[1], texto: r[2], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$sum{$_}[0]}++ for @nums;
print "[TJES] $SAIDA: ", scalar(@nums), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
