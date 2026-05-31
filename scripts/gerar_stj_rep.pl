#!/usr/bin/perl
# Gera data/stj-rep.js — Recursos Repetitivos do STJ (com tese firmada),
# a partir do CSV oficial de Dados Abertos do STJ (temas.csv).
#
# Uso (o download exige cookie+referer por causa do WAF):
#   B="https://dadosabertos.web.stj.jus.br/dataset/4238da2f-c07b-4c1a-b345-4402accacdcf"
#   R="df29da13-7d6b-41ba-ad96-cd1a5bbd191c"
#   curl -s -c jar "$B" -o /dev/null
#   curl -s -b jar -e "$B" "$B/resource/$R/download/temas.csv" -o stj-temas.csv
#   perl scripts/gerar_stj_rep.pl stj-temas.csv
#
# Inclui apenas tipo "Recurso Repetitivo" COM tese firmada. Best-effort.
use strict;
use warnings;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

my $CSV = $ARGV[0] or die "uso: perl gerar_stj_rep.pl <temas.csv>\n";
my $SAIDA = "data/stj-rep.js";
my $FONTE = "https://processo.stj.jus.br/repetitivos/temas_repetitivos/";

open my $fh, "<:encoding(UTF-8)", $CSV or die "não abriu $CSV: $!";
local $/; my $t = <$fh>; close $fh;
$t =~ s/\r\n/\n/g; $t =~ s/\r/\n/g;

# Parser CSV rápido (regex \G). Campos com aspas, vírgulas e quebras internas.
sub parse_csv {
  my ($txt) = @_;
  my @rows; my @row;
  while ($txt =~ /\G(?:"((?:[^"]|"")*)"|([^",\n]*))(,|\n|\z)/gc) {
    my $f = defined $1 ? do { my $x = $1; $x =~ s/""/"/g; $x } : (defined $2 ? $2 : "");
    push @row, $f;
    my $d = $3;
    next if $d eq ',';
    push @rows, [@row]; @row = ();
    last if $d eq "" && pos($txt) >= length($txt);
  }
  return @rows;
}
sub js_str { my ($s)=@_; $s//=""; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g; return $s; }

my @rows = parse_csv($t);
my $hdr = shift @rows;
my %col; $col{$hdr->[$_]} = $_ for 0 .. $#$hdr;
for my $need (qw(tipoPrecedente numeroPrecedente teseFirmada situacao Assuntos)) {
  die "coluna ausente: $need\n" unless exists $col{$need};
}

my %tipo;
my @out; my %visto;
for my $r (@rows) {
  my $tp   = $r->[$col{tipoPrecedente}]  // "";
  $tipo{$tp}++ if $tp =~ /\S/;
  next unless $tp eq "Tema";   # "Tema" = Recurso Repetitivo no STJ
  my $tese = $r->[$col{teseFirmada}] // "";
  next unless $tese =~ /\S/;
  my $num  = $r->[$col{numeroPrecedente}] // "";
  next unless $num =~ /^\d+$/;
  my $id = "stj-rep-$num";
  next if $visto{$id}++;
  my $sit  = ($r->[$col{situacao}] // "") =~ /cancelad/i ? "Cancelada" : "Vigente";
  my $ramo = $r->[$col{Assuntos}] // "";
  $ramo =~ s/^\s*\d+\s*-\s*//;            # tira o código do assunto (ex.: "8826- ")
  $ramo =~ s/\s*[,;].*$//s;               # mantém só o ramo principal
  push @out, {
    num => $num, tese => js_str($tese),
    ramo => js_str($ramo), sit => $sit,
  };
}
@out = sort { $a->{num} <=> $b->{num} } @out;

open my $o, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $o "// Recursos Repetitivos do STJ (temas com tese firmada).\n";
print $o "// Fonte: Dados Abertos do STJ (temas.csv). Best-effort; confira no portal do STJ.\n";
print $o "window.ENTRIES = (window.ENTRIES || []).concat([\n";
for my $e (@out) {
  printf $o "  { id: \"stj-rep-%s\", tribunal: \"STJ\", tipo: \"Recurso Repetitivo\", numero: \"%s\", situacao: \"%s\", tema: \"%s\", fonte: \"%s\",\n    texto: \"%s\" },\n",
    $e->{num}, $e->{num}, $e->{sit}, $e->{ramo}, $FONTE, $e->{tese};
}
print $o "]);\n";
close $o;

print STDERR "tipos no CSV: ", join(", ", map {"$_=$tipo{$_}"} sort {$tipo{$b}<=>$tipo{$a}} keys %tipo), "\n";
print "[REP] $SAIDA: ", scalar(@out), " repetitivos com tese.\n";
