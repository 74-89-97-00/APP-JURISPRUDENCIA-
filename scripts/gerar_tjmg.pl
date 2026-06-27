#!/usr/bin/perl
# Gera data/tjmg-sumulas.js — Súmulas (Enunciados) do TJMG, do PDF oficial
# "Todos os enunciados" (consulta-de-jurisprudencia/lista-de-sumulas.htm).
#
# Uso:  pdftotext -layout -enc UTF-8 enunciados.pdf tjmg.txt
#       perl scripts/gerar_tjmg.pl tjmg.txt
#
# Cada verbete: "ENUNCIADO N" (ou "ENUNCIADO N - CANCELADO") numa linha, o TEXTO
# do enunciado em seguida, e então os metadados (Órgão Julgador, Data...). O
# índice no início (linhas com pontos "....") não casa o marcador (exige fim de
# linha após o número/CANCELADO). Best-effort; confira no portal do TJMG.
use strict;
use warnings;
use utf8;

my $TXT = $ARGV[0] or die "uso: perl gerar_tjmg.pl <arquivo.txt>\n";
my $SAIDA = "data/tjmg-sumulas.js";
my $FONTE = "https://www.tjmg.jus.br/portal-tjmg/jurisprudencia/consulta-de-jurisprudencia/lista-de-sumulas.htm";

open my $fh, "<:encoding(UTF-8)", $TXT or die "não abriu $TXT: $!";
my @lines = <$fh>; close $fh;

my $MARK = qr{^\s*ENUNCIADO\s+(\d+)\s*(?:[-–]\s*([A-Za-zÀ-ÿ]+))?\s*$};
my $META = qr{^\s*(Órgão\s+Julgador|Data\s+do\s+Julgamento|Data\s+da\s+Publica|Referência\s+legislativa|Precedente|Observaç|Vide\b|Doutrina\b)}i;

sub dehyph {
  my ($s) = @_;
  $s =~ s/(\p{Ll})-[ \t]*\n[ \t]*(\p{L})/$1$2/g;   # junta palavra quebrada por hífen
  return $s;
}
sub limpa { my ($t)=@_; $t//=""; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; return $t; }
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

my (%sum, $cur, $capt);
for my $ln (@lines) {
  $ln =~ s/\r?\n$//;
  if ($ln =~ $MARK) {
    $cur = $1;
    # status após o traço: CANCELADO -> Cancelada, REVOGADO -> Revogada;
    # ALTERADO (e qualquer outro) é a versão vigente atual -> Vigente.
    my $tag = $2 ? uc $2 : "";
    my $situ = $tag =~ /CANCEL/ ? "Cancelada" : $tag =~ /REVOG/ ? "Revogada" : "Vigente";
    $sum{$cur} = { situ => $situ, buf => [] };
    $capt = 1;
    next;
  }
  next unless defined $cur && $capt;
  if ($ln =~ $META) { $capt = 0; next; }      # acabou o texto: começou o metadado
  next if $ln =~ /^\s*$/;
  next if $ln =~ /^\s*\d+\s*$/;                # número de página solto
  next if $ln =~ /TRIBUNAL DE JUSTIÇA/i;       # cabeçalho de página
  push @{$sum{$cur}{buf}}, $ln;
}

my @nums = sort { $a <=> $b } keys %sum;
my @out;
for my $n (@nums) {
  my $texto = limpa(dehyph(join("\n", @{$sum{$n}{buf}})));
  next if $texto eq "";
  push @out, [$n, $sum{$n}{situ}, $texto];
}

die "[TJMG] poucas súmulas (" . scalar(@out) . "); abortando para não sobrescrever.\n" if @out < 40;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas (Enunciados) do TJMG. Situação conforme fonte; conferir no portal do TJMG antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\"],\n", js_str($r->[0]), js_str($r->[1]), js_str($r->[2]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjmg-sumula-\" + r[0], tribunal: \"TJMG\", tipo: \"Súmula\", numero: r[0], data: \"\", tema: \"\", situacao: r[1], texto: r[2], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$_->[1]}++ for @out;
print "[TJMG] $SAIDA: ", scalar(@out), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
