#!/usr/bin/perl
# Gera/atualiza data/stf-rg-novos.js — Temas de Repercussão Geral do STF que NÃO
# estão na planilha oficial (gap de temas <=1100 julgados após 2020 + temas
# recentes >1100), raspados um a um do portal (listarProcesso.asp?numeroTemaInicial=N).
#
# INCREMENTAL: preserva os temas já gravados e só MESCLA os que vierem no HTML
# desta vez (acrescenta novos da fronteira e atualiza os raspados). Assim o
# workflow só precisa raspar a JANELA recente (~últimas centenas), não 1..1550.
# Temas antigos (<=~1456) já estão firmados e não mudam.
#
# Uso: arg1 = HTML concatenado das respostas; arg2 = data/stf-rg.js (p/ excluir
# os temas que a planilha já cobre, preservando o ramo do direito daqueles).
#   MAX=$(maior tema conhecido); for n in $(seq $((MAX-40)) $((MAX+120))); do
#     curl ... "listarProcesso.asp?numeroTemaInicial=$n" >> stf-portal.html; done
#   perl scripts/gerar_stf_rg_novos.pl stf-portal.html data/stf-rg.js
#
# Best-effort. Só inclui temas com tese. Confira no portal do STF.
use strict;
use warnings;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

my $HTML  = $ARGV[0] or die "uso: perl gerar_stf_rg_novos.pl <html> [stf-rg.js]\n";
my $BASE  = $ARGV[1];   # opcional: stf-rg.js para excluir temas já cobertos
my $SAIDA = "data/stf-rg-novos.js";

my %exclui;
if ($BASE && -e $BASE) {
  open my $b, "<:encoding(UTF-8)", $BASE or die;
  while (my $l = <$b>) { $exclui{$1} = 1 while $l =~ /stf-rg-(\d+)"/g; }
  close $b;
}

sub limpa_html {
  my ($s) = @_; $s //= "";
  $s =~ s/<[^>]+>/ /g;
  $s =~ s/&nbsp;/ /g;
  $s =~ s/&amp;/&/g; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&#(\d+);/chr($1)/ge;
  $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
  return $s;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g; return $s; }

sub bloco {
  my ($num, $situ, $titulo, $tese) = @_;
  my $fonte = "https://portal.stf.jus.br/jurisprudenciaRepercussao/tema.asp?num=$num";
  return sprintf(
    "  { id: \"stf-rg-%s\", tribunal: \"STF\", tipo: \"Repercussão Geral\", numero: \"%s\", situacao: \"%s\", titulo: \"%s\", fonte: \"%s\",\n    texto: \"%s\" }",
    $num, $num, $situ, $titulo, $fonte, $tese);
}

# 1) Preserva o que já existe (incremental). Guarda o bloco bruto por número.
my %entries;   # num => bloco (sem vírgula final)
if (-e $SAIDA) {
  open my $s, "<:encoding(UTF-8)", $SAIDA or die "não abriu $SAIDA: $!";
  local $/; my $cont = <$s>; close $s;
  while ($cont =~ /(  \{ id: "stf-rg-(\d+)",.*?\n    texto: "(?:[^"\\]|\\.)*" \})/gs) {
    $entries{$2} = $1;
  }
}
my $antes = scalar keys %entries;

# 2) Mescla os temas vindos no HTML desta raspagem (acrescenta/atualiza).
open my $fh, "<:encoding(UTF-8)", $HTML or die "não abriu $HTML: $!";
local $/; my $t = <$fh>; close $fh;

my $mesclados = 0;
while ($t =~ /<tr[^>]*>(.*?)<\/tr>/gs) {
  my $row = $1;
  my @td = ($row =~ /<td[^>]*>(.*?)<\/td>/gs);
  next unless @td >= 6;
  my ($num) = $row =~ /numeroTema=(\d+)/;
  next unless defined $num;
  next if $exclui{$num};            # já está na planilha (preserva o ramo de lá)

  my $titulo = limpa_html($td[1]);
  $titulo =~ s/\s*Ver Descrição.*$//s;        # tira o "Ver Descrição" + descrição
  my $sit = limpa_html($td[4]);
  my $tese = limpa_html($td[5]);
  $tese =~ s/^\s*\d{2}\/\d{2}\/\d{4}\s*//;     # tira a data inicial
  next unless length($tese) > 40;             # só com tese

  my $situ = $sit =~ /cancelad/i ? "Cancelada" : "Vigente";
  $entries{$num} = bloco($num, $situ, js_str($titulo), js_str($tese));
  $mesclados++;
}

my $total = scalar keys %entries;

# Travas: nunca encolher (a mescla só acrescenta/atualiza), e sanidade mínima.
die "[RG-novos] ERRO: total $total < $antes — encolheu? Abortando.\n" if $antes && $total < $antes;
die "[RG-novos] poucos temas ($total < 200); raspagem falhou e não há base. Abortando.\n" if $total < 200;

# 3) Reemite tudo, ordenado.
open my $o, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Temas de Repercussão Geral do STF não cobertos pela planilha de 2020\n";
print $o "// (julgados após 2020), raspados do portal do STF. Best-effort; confira no portal.\n";
print $o "window.ENTRIES = (window.ENTRIES || []).concat([\n";
my @nums = sort { $a <=> $b } keys %entries;
for my $i (0 .. $#nums) {
  print $o $entries{$nums[$i]} . ($i < $#nums ? ",\n" : "\n");
}
print $o "]);\n";
close $o;
print "[RG-novos] $SAIDA: $total temas ($antes preservados, $mesclados vistos nesta raspagem).\n";
