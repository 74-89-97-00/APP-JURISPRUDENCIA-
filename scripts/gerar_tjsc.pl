#!/usr/bin/perl
# Gera data/tjsc-sumulas.js — Súmulas do TJSC, da página oficial
# (tjsc.jus.br/web/jurisprudencia/sumulas-do-tjsc). O conteúdo é HTML inline
# (Liferay JournalContent): cada súmula é um link "Súmula N" seguido de um <p>
# com o enunciado. A página lista as VIGENTES (as antigas ficam em outra página).
#
# Uso: perl scripts/gerar_tjsc.pl sumulas-do-tjsc.html
#
# Best-effort; confira no portal do TJSC antes de citar.
use strict;
use warnings;
use utf8;

my $HTML = $ARGV[0] or die "uso: perl gerar_tjsc.pl <pagina.html>\n";
my $SAIDA = "data/tjsc-sumulas.js";
my $FONTE = "https://www.tjsc.jus.br/web/jurisprudencia/sumulas-do-tjsc";

open my $fh, "<:encoding(UTF-8)", $HTML or die "não abriu $HTML: $!";
local $/; my $h = <$fh>; close $fh;

# HTML -> texto com quebras nos blocos.
$h =~ s/<script.*?<\/script>//gis;
$h =~ s/<style.*?<\/style>//gis;
$h =~ s/<\/(p|div|td|tr|li|h[1-6])>/\n/gi;
$h =~ s/<br[^>]*>/\n/gi;
$h =~ s/<[^>]+>/ /g;
$h =~ s/&nbsp;|&#160;/ /g;
$h =~ s/&#(\d+);/chr($1)/ge;
$h =~ s/&amp;/\&/g; $h =~ s/&lt;/</g; $h =~ s/&gt;/>/g; $h =~ s/&quot;/"/g;
$h =~ s/[ \t]+/ /g;

sub limpa { my ($t)=@_; $t//=""; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; return $t; }
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

# Fim da lista de súmulas (começa o rodapé/menu). "Oculto" é o rótulo Liferay
# logo após a última súmula; os demais são itens de navegação.
my $FIM = qr/^(Oculto|Atendimento e Contatos|Mapa do Site|Voltar|Compartilhar)\b/i;

my (%sum, $cur, @buf);
for my $ln (split /\n/, $h) {
  $ln = limpa($ln);
  next if $ln eq "";
  # Marcador: "Súmula N" sozinho na linha, com status opcional
  # "Súmula N (Revogada)". O âncora de fim de linha ($) descarta as CITAÇÕES
  # do tipo "Súmula n. 580 do STJ" (que ficam no meio da frase, não sozinhas).
  if ($ln =~ /^S[úu]mula\s+(\d+)(?:\s*\(\s*(Revogad[ao]|Cancelad[ao]|Substitu[íi]da|Prejudicad[ao])\s*\))?\s*$/) {
    $sum{$cur}{texto} = join(" ", @buf) if defined $cur;
    $cur = $1;
    my $st = $2 // "";
    $sum{$cur}{situ} = $st =~ /Revog/i     ? "Revogada"
                     : $st =~ /Cancel/i    ? "Cancelada"
                     : $st =~ /Substitu/i  ? "Substituída"
                     : $st =~ /Prejudic/i  ? "Prejudicada"
                     : "Vigente";
    @buf = ();
    next;
  }
  next unless defined $cur;
  if ($ln =~ $FIM) { $sum{$cur}{texto} = join(" ", @buf); $cur = undef; last; }
  push @buf, $ln;
}
$sum{$cur}{texto} = join(" ", @buf) if defined $cur;

my @out;
for my $n (sort { $a <=> $b } keys %sum) {
  my $texto = limpa($sum{$n}{texto});
  next if length($texto) < 15;
  push @out, [ $n, $sum{$n}{situ} || "Vigente", $texto ];
}

die "[TJSC] poucas súmulas (" . scalar(@out) . "); abortando para não sobrescrever.\n" if @out < 30;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJSC. Situação conforme fonte; conferir no portal do TJSC antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\"],\n", js_str($r->[0]), js_str($r->[1]), js_str($r->[2]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjsc-sumula-\" + r[0], tribunal: \"TJSC\", tipo: \"Súmula\", numero: r[0], data: \"\", tema: \"\", situacao: r[1], texto: r[2], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$_->[1]}++ for @out;
print "[TJSC] $SAIDA: ", scalar(@out), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
