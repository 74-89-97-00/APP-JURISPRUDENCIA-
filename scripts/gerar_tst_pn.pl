#!/usr/bin/perl
# Gera data/tst-pn.js — Precedentes Normativos do TST (PN-1 ...), do livro oficial.
#
# Usa o texto SEM -layout (ordem de leitura), bem mais limpo para os PNs:
#   pdftotext -enc UTF-8 Livro-Internet.pdf tst-raw.txt
#   perl scripts/gerar_tst_pn.pl tst-raw.txt
#
# Best-effort: remove parênteses editoriais (cancelado/homologação/Res./DJ) e
# cabeçalhos de página; mantém "(negativo)"/"(positivo)" (substantivo).
# Para ao entrar no índice (quando o número do marcador decresce).
use strict;
use warnings;
use utf8;

my $TXT = $ARGV[0] or die "uso: perl gerar_tst_pn.pl <arquivo-raw.txt>\n";
my $SAIDA = "data/tst-pn.js";
my $FONTE = "https://www.tst.jus.br/precedentes-normativos";

open my $fh, '<:encoding(UTF-8)', $TXT or die "não abriu $TXT: $!";
my @lines = <$fh>; close $fh;

my $MARK = qr{^PN-(\d+)\s*(.*)$};   # título às vezes vem colado: "PN-100FÉRIAS..."

sub limpa {
  my ($t) = @_;
  $t =~ s/\((?:inserid[ao]|cancelad[ao]|revogad[ao]|alterad[ao]|republicad[ao]|nova\s+redação|redação|convertid[ao]|incorporad[ao]|mantid[ao]|homolog[^)]*|ex-OJs?|ex-Súmula|DJ|DEJT)[^)]*\)//gi;
  $t =~ s/[-–—]?\s*Res\.?\s*\d+\/\d+[\s,;]*(?:(?:DJ|DEJT)\b[\d.,\seEº°]*?\d{4})?[.\s]*//gi;
  $t =~ s/[-–—]?\s*(?:DJ|DEJT)\s+divulgad[ao]\s+em\s+[\d.,\seEº°]*?\d{4}//gi;
  $t =~ s/\bPrecedentes\s+Normativos\b//gi;
  $t =~ s/\s+/ /g;
  $t =~ s/\s+([.,;:])/$1/g;
  $t =~ s/\(\s*\)//g;
  $t =~ s/\s*[-–—]\s*$//;
  $t =~ s/^\s+|\s+$//g;
  return $t;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

my (@itens, $cur, $started, $max);
$max = 0;
for my $ln (@lines) {
  $ln =~ s/\r?\n$//;
  $ln =~ s/^\f+//;                       # form-feed (quebra de página) antes do marcador
  # marcador colado ao cabeçalho: "Precedentes Normativos PN-109 ..."
  $ln =~ s/^\s*(?:Precedentes\s+Normativos|PRECEDENTES\s+NORMATIVOS)\s+(?=PN-\d)//i;
  if ($ln =~ $MARK) {
    my ($num, $rest) = ($1, $2);
    last if $started && $num < $max;     # números voltam a cair => índice
    push @itens, $cur if $cur;
    $cur = { num => $num, buf => [ $rest ] };
    $started = 1;
    $max = $num if $num > $max;
    next;
  }
  next unless $started && $cur;
  next if $ln =~ /^\s*$/;
  next if $ln =~ /^PRECEDENTES\s+NORMATIVOS\s*$/i;
  next if $ln =~ /^Precedentes\s+Normativos\s*$/i;
  next if $ln =~ /^[A-Z]-\d+\s*$/;       # número de página (G-1, H-1)
  next if $ln =~ /^\d+\s*$/;
  push @{$cur->{buf}}, $ln;
}
push @itens, $cur if $cur;

my @out; my %visto;
for my $i (@itens) {
  my $raw = join(" ", @{$i->{buf}});
  my $situ = lc(substr($raw, 0, 200)) =~ /cancelad/ ? "Cancelada" : "Vigente";
  my $texto = limpa($raw);
  next if $texto eq "";
  my $id = "tst-pn-$i->{num}";
  next if $visto{$id}++;
  push @out, { id => $id, num => $i->{num}, situ => $situ, texto => $texto };
}
@out = sort { $a->{num} <=> $b->{num} } @out;

die "[PN] poucos precedentes (" . scalar(@out) . "); abortando para não sobrescrever.\n" if @out < 80;

open my $o, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Precedentes Normativos do TST (dissídio coletivo).\n";
print $o "// Extraídos do livro oficial (Livro-Internet.pdf) — texto best-effort; confira no portal do TST.\n";
print $o "window.ENTRIES = (window.ENTRIES || []).concat([\n";
for my $e (@out) {
  printf $o "  { id: \"%s\", tribunal: \"TST\", tipo: \"Precedente Normativo\", numero: \"%s\", situacao: \"%s\", fonte: \"%s\",\n    texto: \"%s\" },\n",
    js_str($e->{id}), js_str($e->{num}), js_str($e->{situ}), $FONTE, js_str($e->{texto});
}
print $o "]);\n";
close $o;

my $canc = grep { $_->{situ} eq "Cancelada" } @out;
print "[PN] $SAIDA: ", scalar(@out), " precedentes (", $canc, " cancelados).\n";
