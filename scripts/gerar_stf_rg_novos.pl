#!/usr/bin/perl
# Gera data/stf-rg-novos.js — Temas de Repercussão Geral do STF que NÃO estão na
# planilha oficial (gap de temas <=1100 julgados após 2020 + temas recentes
# >1100), raspados um a um do portal (listarProcesso.asp?numeroTemaInicial=N),
# que é a única forma confiável (o portal capa buscas em lote).
#
# Uso: arg1 = HTML concatenado das respostas; arg2 = data/stf-rg.js (p/ excluir
# os temas que a planilha já cobre, preservando o ramo do direito daqueles).
#   for n in $(seq 1 1550); do
#     curl ... "listarProcesso.asp?numeroTemaInicial=$n" >> stf-portal.html; done
#   perl scripts/gerar_stf_rg_novos.pl stf-portal.html data/stf-rg.js
#
# Best-effort. Só inclui temas com tese. Confira no portal do STF.
use strict;
use warnings;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

my $HTML = $ARGV[0] or die "uso: perl gerar_stf_rg_novos.pl <html> [stf-rg.js]\n";
my $BASE = $ARGV[1];   # opcional: stf-rg.js para excluir temas já cobertos
my $SAIDA = "data/stf-rg-novos.js";

my %exclui;
if ($BASE && -e $BASE) {
  open my $b, "<:encoding(UTF-8)", $BASE or die;
  while (my $l = <$b>) { $exclui{$1} = 1 while $l =~ /stf-rg-(\d+)"/g; }
  close $b;
}

open my $fh, "<:encoding(UTF-8)", $HTML or die "não abriu $HTML: $!";
local $/; my $t = <$fh>; close $fh;

sub limpa_html {
  my ($s) = @_; $s //= "";
  $s =~ s/<[^>]+>/ /g;
  $s =~ s/&nbsp;/ /g;
  $s =~ s/&amp;/&/g; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&#(\d+);/chr($1)/ge;
  $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
  return $s;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g; return $s; }

my @out; my %visto;
while ($t =~ /<tr[^>]*>(.*?)<\/tr>/gs) {
  my $row = $1;
  my @td = ($row =~ /<td[^>]*>(.*?)<\/td>/gs);
  next unless @td >= 6;
  my ($num) = $row =~ /numeroTema=(\d+)/;
  next unless defined $num;
  next if $exclui{$num};            # já está na planilha (preserva o ramo de lá)
  next if $visto{$num}++;

  my $titulo = limpa_html($td[1]);
  $titulo =~ s/\s*Ver Descrição.*$//s;        # tira o "Ver Descrição" + descrição
  my $sit = limpa_html($td[4]);
  my $tese = limpa_html($td[5]);
  $tese =~ s/^\s*\d{2}\/\d{2}\/\d{4}\s*//;     # tira a data inicial
  next unless length($tese) > 40;             # só com tese

  my $situ = $sit =~ /cancelad/i ? "Cancelada" : "Vigente";
  push @out, { num => $num, titulo => js_str($titulo), tese => js_str($tese), situ => $situ };
}
@out = sort { $a->{num} <=> $b->{num} } @out;

# Trava: a raspagem pode falhar/vir parcial. Não sobrescreve o complemento bom.
die "[RG-novos] poucos temas (" . scalar(@out) . "); abortando para não sobrescrever.\n" if @out < 200;

open my $o, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Temas de Repercussão Geral do STF não cobertos pela planilha de 2020\n";
print $o "// (julgados após 2020), raspados do portal do STF. Best-effort; confira no portal.\n";
print $o "window.ENTRIES = (window.ENTRIES || []).concat([\n";
for my $e (@out) {
  my $fonte = "https://portal.stf.jus.br/jurisprudenciaRepercussao/tema.asp?num=$e->{num}";
  printf $o "  { id: \"stf-rg-%s\", tribunal: \"STF\", tipo: \"Repercussão Geral\", numero: \"%s\", situacao: \"%s\", titulo: \"%s\", fonte: \"%s\",\n    texto: \"%s\" },\n",
    $e->{num}, $e->{num}, $e->{situ}, $e->{titulo}, $fonte, $e->{tese};
}
print $o "]);\n";
close $o;
print "[RG-novos] $SAIDA: ", scalar(@out), " temas de complemento (não cobertos pela planilha).\n";
