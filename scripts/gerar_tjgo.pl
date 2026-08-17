#!/usr/bin/perl
# Gera data/tjgo-sumulas.js — Súmulas do TJGO. A fonte é o sistema de documentos
# do tribunal (tjdocs): a pasta 1474 lista ~85 arquivos (ODT/PDF), um por súmula.
# Cada arquivo traz "ENUNCIADO:", "DATA DA APROVAÇÃO:" e "PRECEDENTES:". O número
# e o cancelamento ("CANCELADA") vêm no campo "nome" da listagem.
#
# Este script NÃO baixa: recebe a listagem JSON e uma pasta com os arquivos já
# baixados, nomeados <id>.<ext> (o download fica no wrapper bash, p/ usar o mesmo
# curl no local e no CI). Extrai ODT via `unzip -p` e PDF via `pdftotext`.
#
# Uso: perl scripts/gerar_tjgo.pl <listagem.json> <pasta_arquivos>
# Best-effort; confira no portal do TJGO antes de citar.
use strict;
use warnings;
use utf8;
use JSON::PP;
binmode(STDOUT, ":encoding(UTF-8)");

my ($JSON, $DIR) = @ARGV;
die "uso: perl gerar_tjgo.pl <listagem.json> <pasta_arquivos>\n" unless $JSON && $DIR;
my $SAIDA = "data/tjgo-sumulas.js";
my $FONTE = "https://www.tjgo.jus.br/index.php/institucional/jurisprudencia/sumulas";

# pdftotext: no CI é 'pdftotext' no PATH; no Git-Bash local é o do mingw.
my $PDFTOTEXT = "pdftotext";
for my $c ("/c/Program Files/Git/mingw64/bin/pdftotext.exe", "pdftotext") {
  if ($c eq "pdftotext" || -x $c) { $PDFTOTEXT = $c; last; }
}

sub limpa { my ($t)=@_; $t//=""; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; return $t; }
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s; }

# Extrai o texto plano de um arquivo ODT ou PDF.
sub texto_de {
  my ($path, $ext) = @_;
  my $txt = "";
  if ($ext eq "odt") {
    open my $p, "-|:encoding(UTF-8)", "unzip", "-p", $path, "content.xml" or return "";
    local $/; my $xml = <$p>; close $p;
    return "" unless defined $xml;
    $xml =~ s/<text:tab\/>/ /g;
    $xml =~ s/<text:s\b[^>]*\/>/ /g;
    $xml =~ s/<[^>]+>/ /g;
    $xml =~ s/&amp;/\&/g; $xml =~ s/&lt;/</g; $xml =~ s/&gt;/>/g;
    $xml =~ s/&apos;/'/g; $xml =~ s/&quot;/"/g; $xml =~ s/&#(\d+);/chr($1)/ge;
    $txt = $xml;
  } else {
    open my $p, "-|", $PDFTOTEXT, "-layout", "-enc", "UTF-8", $path, "-" or return "";
    binmode($p, ":encoding(UTF-8)"); local $/; $txt = <$p>; close $p;
    $txt //= "";
  }
  $txt =~ s/\s+/ /g;
  return $txt;
}

# Recorta enunciado e data de aprovação do texto plano.
sub enunciado_de {
  my ($txt) = @_;
  my ($e) = $txt =~ /ENUNCIADO\s*:?\s*(.*?)\s*(?:DATA\s+DA\s+APROVA|PRECEDENTES|REFER[ÊE]NCIA\s+LEGISL|Desembargador|Presidente|$)/si;
  # Sem marcador "ENUNCIADO" (súmulas antigas): o enunciado vem depois do
  # cabeçalho "SÚMULA Nº N, DE ... (Resultante ... realizada em DD/MM/AAAA)."
  if (!defined $e || length(limpa($e)) < 15) {
    my $t = $txt;
    unless ($t =~ s/^.*?realizada\s+em\s+\d{1,2}\/\d{1,2}\/\d{4}\s*\)\.?\s*//si) {
      $t =~ s/^.*?S[ÚU]MULA\s+N[º°o.]*\s*[\dA-Za-z-]+\s*(?:,\s*DE\s+.*?\bDE\s+\d{4})?\s*//si;
    }
    ($e) = $t =~ /(.*?)\s*(?:DATA\s+DA\s+APROVA|PRECEDENTES|$)/si;
  }
  $e //= "";
  # Tira ruídos de cabeçalho que às vezes entram no início do enunciado.
  $e =~ s/^\s*REVIS[ÃA]O\s+DE\s+TESE\s*(?:[-–]?\s*S[ÚU]MULA\s*N?[º°o.]*\s*[\dA-Z-]+)?\s*[-–:.]?\s*//i;
  $e =~ s/^\s*S[ÚU]MULA\s+N[º°o.]*\s*[\dA-Z-]+\s*[-–:]\s*//i;
  # Data: do bloco "DATA DA APROVAÇÃO" ou do "realizada em DD/MM/AAAA" (antigas).
  my ($dt) = $txt =~ /DATA\s+DA\s+APROVA.{0,60}?(\d{1,2})\s*\/\s*(\d{1,2})\s*\/\s*(\d{4})/si
    ? sprintf("%02d/%02d/%s", $1, $2, $3)
    : $txt =~ /realizada\s+em\s+(\d{1,2})\/(\d{1,2})\/(\d{4})/si
    ? sprintf("%02d/%02d/%s", $1, $2, $3) : "";
  return (limpa($e), $dt);
}

# ---- Lê a listagem ----
open my $fh, "<:raw", $JSON or die "não abriu $JSON: $!";
local $/; my $raw = <$fh>; close $fh;
my $data = decode_json($raw);
my $docs = $data->{_embedded}{documentos} || $data->{documentos}
  or die "[TJGO] listagem sem documentos\n";

my (%vis, @out, @dups);
for my $d (@$docs) {
  my $nome = $d->{nome} // "";
  my $id   = $d->{id}   // next;
  my $ext  = lc($d->{extensao} // "");
  next unless $ext eq "odt" || $ext eq "pdf";
  # Número: "Súmula nº 15", "01-A", "27-" (typo), "SÚMULA Nº 01". O sufixo de
  # letra ("-A") só conta quando COLADO ao número (sem espaço) e seguido de
  # não-letra; "02 - Médico" tem espaços e a letra inicia a descrição, logo o
  # dash não gruda no dígito e NÃO vira sufixo.
  next unless $nome =~ /S[ÚU]MULA\s+N[º°o.]*\s*0*(\d+)(?:-([A-Z])(?!\p{L}))?/i;
  my $num = $1; $num .= "-" . uc($2) if $2;
  my $situ = $nome =~ /cancelad/i ? "Cancelada"
           : $nome =~ /revogad/i  ? "Revogada"
           : "Vigente";
  my $file = "$DIR/$id.$ext";
  unless (-s $file) { warn "[TJGO] falta arquivo $file ($nome)\n"; next; }
  my ($texto, $dt) = enunciado_de(texto_de($file, $ext));
  next if length($texto) < 15;
  # dedup por número normalizado (mantém o primeiro; anota o conflito).
  if ($vis{$num}++) { push @dups, $num; next; }
  push @out, [ $num, $dt, $situ, $texto ];
}

# Ordena por número (parte inteira) e sufixo.
@out = sort {
  my ($an) = $a->[0] =~ /(\d+)/; my ($bn) = $b->[0] =~ /(\d+)/;
  ($an||0) <=> ($bn||0) || $a->[0] cmp $b->[0]
} @out;

die "[TJGO] poucas súmulas (" . scalar(@out) . "); abortando p/ não sobrescrever.\n" if @out < 60;

open my $o, ">:encoding(UTF-8)", $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Súmulas do TJGO. Situação conforme fonte; conferir no portal do TJGO antes de citar.\n";
print $o "(function () {\n";
print $o "  var F = \"$FONTE\";\n";
print $o "  var data = [\n";
for my $r (@out) {
  printf $o "    [\"%s\",\"%s\",\"%s\",\"%s\"],\n",
    js_str($r->[0]), js_str($r->[1]), js_str($r->[2]), js_str($r->[3]);
}
print $o "  ];\n";
print $o "  var out = data.map(function (r) {\n";
print $o "    return { id: \"tjgo-sumula-\" + r[0], tribunal: \"TJGO\", tipo: \"Súmula\", numero: r[0], data: r[1], tema: \"\", situacao: r[2], texto: r[3], fonte: F };\n";
print $o "  });\n";
print $o "  window.ENTRIES = (window.ENTRIES || []).concat(out);\n";
print $o "})();\n";
close $o;

my %c; $c{$_->[2]}++ for @out;
print "[TJGO] $SAIDA: ", scalar(@out), " súmulas (", join(", ", map {"$_: $c{$_}"} sort keys %c), ").\n";
print "[TJGO] números duplicados ignorados: ", join(", ", @dups), "\n" if @dups;
