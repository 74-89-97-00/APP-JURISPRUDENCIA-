#!/usr/bin/perl
# Gera data/tjrs-sumulas.js — Súmulas do Tribunal de Justiça do RS, do PDF oficial
# "Súmulas do Tribunal de Justiça" (jurisprudencia-e-legislacao/.../sumulas/).
#
# Uso:  pdftotext -layout -enc UTF-8 Sumulas_TJ.pdf tjrs.txt
#       perl scripts/gerar_tjrs.pl tjrs.txt
#
# Cada súmula: "NN. <enunciado...>" (número + ponto), o texto até "Referência:",
# e então os metadados. Status editoriais em CAIXA ALTA depois (REVOGADA,
# SUBSTITUÍDA, CANCELADA). Best-effort; confira no portal do TJRS.
use strict;
use warnings;
use utf8;

my $TXT = $ARGV[0] or die "uso: perl gerar_tjrs.pl <arquivo.txt>\n";
my $SAIDA = "data/tjrs-sumulas.js";
my $FONTE = "https://www.tjrs.jus.br/novo/jurisprudencia-e-legislacao/jurisprudencia/sumulas/";

open my $fh, "<:encoding(UTF-8)", $TXT or die "não abriu $TXT: $!";
my @lines = <$fh>; close $fh;

sub dehyph {
  my ($s) = @_;
  $s =~ s/(\p{Ll})-[ \t]*\n[ \t]*(\p{L})/$1$2/g;
  return $s;
}
sub limpa { my ($t)=@_; $t//=""; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; return $t; }
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

# Coleta cada bloco: marcador "NN." com número ASCENDENTE (evita falso positivo
# de números no meio do texto/referência).
my (%blk, $cur, @buf, $max);
$max = 0;
for my $ln (@lines) {
  $ln =~ s/\r?\n$//;
  if ($ln =~ /^\s*(\d{1,3})\.\s+(\S.*)$/ && $1 > $max) {
    $blk{$cur} = join("\n", @buf) if defined $cur;
    $cur = $1; @buf = ($2); $max = $1;
    next;
  }
  next unless defined $cur;
  next if $ln =~ /^\s*$/;
  push @buf, $ln;
}
$blk{$cur} = join("\n", @buf) if defined $cur;

my @out;
for my $n (sort { $a <=> $b } keys %blk) {
  my $raw = $blk{$n};
  # situação: status editorial em CAIXA ALTA (não casa texto do enunciado, que é caixa mista).
  my $situ = $raw =~ /\bREVOGADA\b/         ? "Revogada"
           : $raw =~ /\bSUBSTITU[IÍ]DA\b/    ? "Substituída"
           : $raw =~ /\bCANCELADA\b/         ? "Cancelada"
           : $raw =~ /\bPREJUDICADA\b/       ? "Prejudicada"
           : "Vigente";
  my $texto = dehyph($raw);
  $texto =~ s/\s*Referência\s*:.*//s;   # corta a referência e o que vier depois
  $texto = limpa($texto);
  next if length($texto) < 15;
  push @out, [ int($n), $situ, $texto ];   # int() tira zero à esquerda (01 -> 1)
}

die "[TJRS] poucas súmulas (" . scalar(@out) . "); abortando para não sobrescrever.\n" if @out < 30;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJRS. Situação conforme fonte; conferir no portal do TJRS antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\"],\n", js_str($r->[0]), js_str($r->[1]), js_str($r->[2]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjrs-sumula-\" + r[0], tribunal: \"TJRS\", tipo: \"Súmula\", numero: r[0], data: \"\", tema: \"\", situacao: r[1], texto: r[2], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$_->[1]}++ for @out;
print "[TJRS] $SAIDA: ", scalar(@out), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
