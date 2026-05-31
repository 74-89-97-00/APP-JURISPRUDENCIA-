#!/usr/bin/perl
# Gera data/tst-ojs.js — Orientações Jurisprudenciais do TST (SDI-1, SDI-2,
# SDI-1 Transitória, SDC, Tribunal Pleno/OE) a partir do livro oficial.
#
# Uso: produza o texto do PDF e passe o caminho como argumento:
#   pdftotext -layout -enc UTF-8 Livro-Internet.pdf tst.txt
#   perl scripts/gerar_tst_ojs.pl tst.txt
#
# Extração best-effort: de-hifeniza quebras de linha, descarta cabeçalhos de
# página e o bloco "Histórico:", remove parênteses editoriais e citações de
# resolução. Revise antes de usar em peça.
use strict;
use warnings;
use utf8;

my $TXT = $ARGV[0] or die "uso: perl gerar_tst_ojs.pl <arquivo.txt>\n";
my $SAIDA = "data/tst-ojs.js";
my $FONTE = "https://www.tst.jus.br/ojs";

open my $fh, '<:encoding(UTF-8)', $TXT or die "não abriu $TXT: $!";
my @lines = <$fh>; close $fh;

my $MARK = qr{^[ \t\f]*OJ-(SDI1T|SDI2|SDI1|SDC|TP/OE|TP)-(\d+)\b(.*)$};
my %SEC  = ("SDI1"=>"SDI-1","SDI1T"=>"SDI-1 Transitória","SDI2"=>"SDI-2",
            "SDC"=>"SDC","TP/OE"=>"Tribunal Pleno/OE","TP"=>"Tribunal Pleno/OE");
my %SLUG = ("SDI1"=>"sdi1","SDI1T"=>"sdi1t","SDI2"=>"sdi2","SDC"=>"sdc",
            "TP/OE"=>"tp","TP"=>"tp");

sub dehyph {
  my ($s) = @_;
  $s =~ s{(\p{L})-[ \t]*\n[ \t\f]*(\p{L})}{
    my ($a,$b)=($1,$2);
    ($a =~ /\p{Ll}/ && $b =~ /\p{Lu}/) ? "$a-$b" : "$a$b"
  }ge;
  return $s;
}
sub limpa {
  my ($t) = @_;
  # parênteses editoriais (palavras-chave em minúsculas -> /i ok)
  $t =~ s/\((?:inserid[ao]|cancelad[ao]|revogad[ao]|alterad[ao]|republicad[ao]|nova\s+redação|redação|convertid[ao]|incorporad[ao]|ex-OJs?|DJ|DEJT)[^)]*\)//gi;
  # citação de resolução: para no primeiro caractere MAIÚSCULO (sem /i!)
  $t =~ s/[-–—]?\s*Res\.?\s*\d+\/\d+[^A-ZÀ-Ý]*?(?:DJ|DEJT)\b[^A-ZÀ-Ý]*?\d{4}[^A-ZÀ-Ý]*//g;
  $t =~ s/\s+/ /g;
  $t =~ s/\s+([.,;:])/$1/g;
  $t =~ s/^\s+|\s+$//g;
  return $t;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

my (@itens,$cur,$started,$hist);
for my $ln (@lines) {
  $ln =~ s/\r?\n$//;
  last if $ln =~ /^\s*ÍNDICE REMISSIVO/;
  if ($ln =~ $MARK) {
    push @itens, $cur if $cur;
    $cur = { sec=>$SEC{$1}, slug=>$SLUG{$1}, num=>$2, buf=>[ $3 ] };
    $started=1; $hist=0; next;
  }
  next unless $started && $cur;
  if ($ln =~ /^\s*Histórico\s*:/i) { $hist=1; next; }
  next if $hist;
  next if $ln =~ /^\s*$/;
  next if $ln =~ /^\s*[A-Z]-\d+\s*$/;                       # número de página (C-4)
  next if $ln =~ /^\s*Orientaç(?:ão|ões)\s+Jurisprudencial/i; # cabeçalho corrido
  next if $ln =~ /^\s*(SBDI\s*-\s*(?:I|II)|SDC\b|Tribunal Pleno|Órgão Especial|Seção)/;
  push @{$cur->{buf}}, $ln;
}
push @itens, $cur if $cur;

my @out;
my %visto;
for my $i (@itens) {
  my $raw  = dehyph(join("\n", @{$i->{buf}}));
  my $head = lc(substr($raw, 0, 300));
  my $situ = $head =~ /cancelad/    ? "Cancelada"
           : $head =~ /convertid/   ? "Convertida"
           : "Vigente";
  my $texto = limpa($raw);
  next if $texto eq "";
  my $id = "tst-oj-$i->{slug}-$i->{num}";
  next if $visto{$id}++;
  push @out, { id=>$id, sec=>$i->{sec}, num=>$i->{num}, situ=>$situ, texto=>$texto };
}

open my $o, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Orientações Jurisprudenciais do TST (SDI-1, SDI-2, SDI-1 Transitória, SDC, Tribunal Pleno/OE).\n";
print $o "// Extraídas do livro oficial (Livro-Internet.pdf) — texto best-effort; confira no portal do TST.\n";
print $o "window.ENTRIES = (window.ENTRIES || []).concat([\n";
for my $e (@out) {
  printf $o "  { id: \"%s\", tribunal: \"TST\", tipo: \"Orientação Jurisprudencial\", secao: \"%s\", numero: \"%s\", situacao: \"%s\", fonte: \"%s\",\n    texto: \"%s\" },\n",
    js_str($e->{id}), js_str($e->{sec}), js_str($e->{num}), js_str($e->{situ}), $FONTE, js_str($e->{texto});
}
print $o "]);\n";
close $o;

my %cnt; $cnt{$_->{sec}}++ for @out;
print "[OJ] $SAIDA: ", scalar(@out), " OJs (";
print join(", ", map { "$_: $cnt{$_}" } sort keys %cnt);
print ").\n";
