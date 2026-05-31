#!/usr/bin/perl
# Gera data/stf-rg.js — Temas de Repercussão Geral do STF (com tese firmada),
# a partir da planilha oficial temasrg.xlsx.
#
# Uso:
#   curl -sL -o temasrg.xlsx "https://www.stf.jus.br/arquivo/cms/publicacaoBOInternet/anexo/temasrg.xlsx"
#   perl scripts/gerar_stf_rg.pl temasrg.xlsx
#
# Colunas: A=Num Tema, G=Título do Tema, H=Tese Tema, I=Ramo do direito.
# Inclui apenas temas COM tese firmada. Best-effort; confira no portal do STF.
use strict;
use warnings;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

my $XLSX = $ARGV[0] or die "uso: perl gerar_stf_rg.pl <temasrg.xlsx>\n";
my $SAIDA = "data/stf-rg.js";

sub unents {
  my ($s) = @_; $s //= "";
  $s =~ s/&#x([0-9a-fA-F]+);/chr(hex($1))/ge;
  $s =~ s/&#(\d+);/chr($1)/ge;
  $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&apos;/'/g;
  $s =~ s/&amp;/&/g;
  return $s;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g; return $s; }

# ---- sharedStrings ----
my $ss_xml = `unzip -p "$XLSX" xl/sharedStrings.xml`;
utf8::decode($ss_xml);
my @ss;
while ($ss_xml =~ /<si>(.*?)<\/si>/gs) {
  my $si = $1; my $txt = "";
  while ($si =~ /<t[^>]*>(.*?)<\/t>/gs) { $txt .= $1; }
  push @ss, unents($txt);
}

# ---- planilha ----
my $sheet = `unzip -p "$XLSX" xl/worksheets/sheet1.xml`;
utf8::decode($sheet);
my @rows;
while ($sheet =~ /<row[^>]*\br="(\d+)"[^>]*>(.*?)<\/row>/gs) {
  my ($rn, $cells) = ($1, $2);
  my %r;
  while ($cells =~ /<c\s+r="([A-Z]+)\d+"([^>]*?)(?:\/>|>(.*?)<\/c>)/gs) {
    my ($col, $attrs, $inner) = ($1, $2, $3);
    next unless defined $inner;
    my $is_s = $attrs =~ /t="s"/;
    my ($v) = $inner =~ /<v>(.*?)<\/v>/s;
    my $val;
    if (defined $v) { $val = $is_s ? ($ss[$v] // "") : unents($v); }
    else { my ($it) = $inner =~ /<t[^>]*>(.*?)<\/t>/s; $val = defined $it ? unents($it) : ""; }
    $r{$col} = $val;
  }
  $rows[$rn] = \%r;
}

# ---- monta entradas (pula cabeçalho linha 1) ----
my @out;
for my $rn (2 .. $#rows) {
  my $r = $rows[$rn] or next;
  my $num   = $r->{A} // "";
  my $tit   = $r->{G} // "";
  my $tese  = $r->{H} // "";
  my $ramo  = $r->{I} // "";
  next unless $num =~ /^\d+$/;
  next unless $tese =~ /\S/;                 # só temas com tese firmada
  push @out, {
    num => $num, titulo => js_str($tit), tese => js_str($tese), ramo => js_str($ramo),
  };
}
@out = sort { $a->{num} <=> $b->{num} } @out;

open my $o, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Temas de Repercussão Geral do STF (com tese firmada).\n";
print $o "// Fonte: planilha oficial temasrg.xlsx do STF. Best-effort; confira no portal do STF.\n";
print $o "window.ENTRIES = (window.ENTRIES || []).concat([\n";
for my $e (@out) {
  my $fonte = "https://portal.stf.jus.br/jurisprudenciaRepercussao/tema.asp?num=$e->{num}";
  printf $o "  { id: \"stf-rg-%s\", tribunal: \"STF\", tipo: \"Repercussão Geral\", numero: \"%s\", situacao: \"Vigente\", tema: \"%s\", titulo: \"%s\", fonte: \"%s\",\n    texto: \"%s\" },\n",
    $e->{num}, $e->{num}, $e->{ramo}, $e->{titulo}, $fonte, $e->{tese};
}
print $o "]);\n";
close $o;

print "[RG] $SAIDA: ", scalar(@out), " temas com tese firmada.\n";
