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
  # Parênteses editoriais: por palavra-chave inicial...
  $t =~ s/\((?:inserid[ao]|cancelad[ao]|revogad[ao]|alterad[ao]|republicad[ao]|nova\s+redação|redação|convertid[ao]|incorporad[ao]|ex-OJs?|ex-Súmula|DJ|DEJT)[^)]*\)//gi;
  # ...ou contendo proveniência (ex-OJ / "inserida em") em qualquer posição.
  $t =~ s/\([^)]*(?:ex-OJs?|ex-Súmula|inserid[ao]\s+em)[^)]*\)//gi;
  # Parêntese editorial NÃO fechado (o ")" caiu numa linha de cabeçalho removida):
  # "(redação alterada na sessão do ... divulgado em 25, 26 e 27.09.2012".
  $t =~ s/\((?:redação|nova\s+redação|mantid[ao]|alterad[ao]|inserid[ao]|cancelad[ao]|convertid[ao])[^)]*?divulgad[ao]\s+em\s+[\d.,\seEº°]*?\d{4}//gi;
  # Citações de resolução em qualquer caixa: "Res. 129/2005, DJ 20, 22 e 25.04.2005".
  $t =~ s/[-–—]?\s*Res\.?\s*\d+\/\d+[\s,;]*(?:(?:DJ|DEJT)\b[\d.,\seEº°]*?\d{4})?[.\s]*//gi;
  # "Republicada DJ 08, 09 e 10.07.2008".
  $t =~ s/\bRepublicad[ao]\b(?:[\s,;]*(?:DJ|DEJT)\b[\d.,\seEº°]*?\d{4})?[.\s]*//gi;
  # Notas "inserida/cancelada/alterada em 27.03.1998".
  $t =~ s/\b(?:inserid[ao]|cancelad[ao]|alterad[ao]|republicad[ao]|revogad[ao])\s+em\s+\d{1,2}\.\d{1,2}\.\d{2,4}//gi;
  # "DEJT/DJ divulgado em 27, 30 e 31.05.2011" (às vezes colado: "...INSTRUMENTODEJT").
  $t =~ s/[-–—]?\s*(?:DJ|DEJT)\s+divulgad[ao]\s+em\s+[\d.,\seEº°]*?\d{4}//gi;
  # Publicação solta "DJ 13.10.2000" / "- DEJT 01.06.2016".
  $t =~ s/[-–—]?\s*\b(?:DJ|DEJT)\b\s+\d[\d.,\seEº°]*?\d{4}\b//gi;
  # Parêntese editorial aberto e não fechado até o fim do texto: "(ex-OJ nº 231 da".
  $t =~ s/\(\s*(?:ex-OJs?|ex-Súmula|inserid[ao]|redação|nova\s+redação|mantid[ao]|alterad[ao]|cancelad[ao]|convertid[ao])[^)]*$//i;
  $t =~ s/\s+/ /g;
  $t =~ s/\s+([.,;:])/$1/g;
  $t =~ s/\s*[-–—]\s*$//;     # hífen/traço solto no fim
  $t =~ s/^\s+|\s+$//g;
  return $t;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

my (@itens,$cur,$started,$hist,%secmax);
for my $ln (@lines) {
  $ln =~ s/\r?\n$//;
  last if $ln =~ /^\s*ÍNDICE REMISSIVO/;
  last if $ln =~ /^[ \t\f]*PN-\d/;   # fim das OJs: começam os Precedentes Normativos
  if ($ln =~ $MARK) {
    my ($tag,$num,$rest) = ($1,$2,$3);
    # Robustez a versões diferentes do pdftotext: marcadores de OJ também
    # aparecem em REFERÊNCIAS CRUZADAS no meio do texto (ex.: "OJ-SDI1-123 da
    # SBDI-I ..."). As OJs REAIS surgem em ordem CRESCENTE por seção; um número
    # que não avança o máximo da seção é referência cruzada — vira texto da OJ
    # atual, não uma OJ nova. (Sem isso, o poppler do runner do CI inventava
    # ~6 OJs falsas: 709 em vez de 703.)
    if ($started && $cur && defined $secmax{$tag} && $num <= $secmax{$tag}) {
      push @{$cur->{buf}}, $ln unless $hist;
      next;
    }
    push @itens, $cur if $cur;
    $cur = { sec=>$SEC{$tag}, slug=>$SLUG{$tag}, num=>$num, buf=>[ $rest ] };
    $secmax{$tag} = $num;
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

die "[OJ] poucas OJs (" . scalar(@out) . "); abortando para não sobrescrever.\n" if @out < 300;

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
