#!/usr/bin/perl
# Gera data/tjmt-sumulas.js — Súmulas do TJMT (Tribunal Pleno). São apenas 2, e
# a fonte é peculiar: o texto está "chumbado" dentro de um bundle JavaScript do
# portal de jurisprudência (jurisprudencia.tjmt.jus.br/sumulas), como literais
# `this.texto1="..."` / `this.texto2="..."`. O número segue a ordem (texto1 =>
# Súmula 1, texto2 => Súmula 2).
#
# Uso: perl scripts/gerar_tjmt.pl <chunk.js>
# Best-effort; confira no portal do TJMT antes de citar.
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":encoding(UTF-8)");

my $CHUNK = $ARGV[0] or die "uso: perl gerar_tjmt.pl <chunk.js>\n";
my $SAIDA = "data/tjmt-sumulas.js";
my $FONTE = "https://jurisprudencia.tjmt.jus.br/sumulas";

open my $fh, "<:encoding(UTF-8)", $CHUNK or die "não abriu $CHUNK: $!";
local $/; my $js = <$fh>; close $fh;

sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

# Desfaz escapes JS: \uXXXX, \", \\, \n, e normaliza aspas curvas.
sub decode_js {
  my ($s) = @_;
  $s =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
  $s =~ s/\\x([0-9a-fA-F]{2})/chr(hex($1))/ge;   # \xE7 (byte Latin-1) -> ç
  $s =~ s/\\"/"/g;
  $s =~ s/\\'/'/g;
  $s =~ s/\\n/ /g;
  $s =~ s/\\\\/\\/g;
  $s =~ s/[\x{201c}\x{201d}]/"/g;   # “ ” -> "
  $s =~ s/[\x{2018}\x{2019}]/'/g;   # ‘ ’ -> '
  $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
  return $s;
}

my %sum;
my $dq = chr(34);   # aspas duplas, p/ evitar escapes no shell
while ($js =~ /this\.texto(\d+)\s*=\s*$dq((?:[^$dq\\]|\\.)*)$dq/g) {
  my ($n, $s) = ($1, $2);
  my $t = decode_js($s);
  $sum{$n} = $t if length($t) >= 15;
}

my @out;
for my $n (sort { $a <=> $b } keys %sum) {
  push @out, [ $n, "Vigente", $sum{$n} ];
}

die "[TJMT] nenhuma súmula extraída; abortando.\n" if @out < 1;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJMT (Tribunal Pleno). Conferir no portal do TJMT antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\"],\n", js_str($r->[0]), js_str($r->[1]), js_str($r->[2]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjmt-sumula-\" + r[0], tribunal: \"TJMT\", tipo: \"Súmula\", numero: r[0], data: \"\", tema: \"\", situacao: r[1], texto: r[2], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

print "[TJMT] $SAIDA: ", scalar(@out), " súmulas.\n";
