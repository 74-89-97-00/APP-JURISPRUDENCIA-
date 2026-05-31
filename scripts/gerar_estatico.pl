#!/usr/bin/perl
# Gera dados.html: uma página ESTÁTICA, em texto puro (sem JavaScript), com
# todas as súmulas. Serve para leitura por IA (Claude etc.), buscadores,
# prévias de link e impressão — coisas que não executam o app.js.
#
# Lê os mesmos arquivos data/*.js que o app usa e escreve dados.html na raiz.
# Roda localmente (perl scripts/gerar_estatico.pl) e no GitHub Actions.
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":encoding(UTF-8)");

my $DATA = "data";
my $SAIDA = "dados.html";

# Configuração por arquivo. mode=arr: `var data=[["c1","c2",...]]`; cols dá a
# ordem das colunas. mode=obj: objetos { numero:"", situacao:"", ... }.
my @FONTES = (
  { path => "stf-vinculantes.js", mode => "obj",
    secao => "Súmulas Vinculantes do STF", anchor => "stf-sv", sigla => "STF",
    rotulo => "Súmula Vinculante" },
  { path => "stf-sumulas.js", mode => "arr",
    secao => "Súmulas do STF", anchor => "stf", sigla => "STF", rotulo => "Súmula",
    cols => [qw(numero situacao texto)] },
  { path => "stj-sumulas.js", mode => "arr",
    secao => "Súmulas do STJ", anchor => "stj", sigla => "STJ", rotulo => "Súmula",
    cols => [qw(numero data tema situacao texto)] },
  { path => "tst-sumulas.js", mode => "arr",
    secao => "Súmulas do TST", anchor => "tst", sigla => "TST", rotulo => "Súmula",
    cols => [qw(numero situacao texto)] },
  { path => "tst-ojs.js", mode => "obj",
    secao => "Orientações Jurisprudenciais do TST", anchor => "tst-oj", sigla => "TST",
    rotulo => "Orientação Jurisprudencial" },
  { path => "tst-pn.js", mode => "obj",
    secao => "Precedentes Normativos do TST", anchor => "tst-pn", sigla => "TST",
    rotulo => "Precedente Normativo" },
  { path => "tjsp-sumulas.js", mode => "arr",
    secao => "Súmulas do TJSP", anchor => "tjsp", sigla => "TJSP", rotulo => "Súmula",
    cols => [qw(numero situacao texto)] },
  { path => "tjrj-sumulas.js", mode => "arr",
    secao => "Súmulas do TJRJ", anchor => "tjrj", sigla => "TJRJ", rotulo => "Súmula",
    cols => [qw(numero situacao texto)] },
);

sub slurp {
  my ($p) = @_;
  open my $fh, '<:encoding(UTF-8)', $p or die "não abriu $p: $!";
  local $/; my $c = <$fh>; close $fh; return $c;
}

# Desfaz o escape de string JS: \" -> "  e  \\ -> \
sub unesc { my ($s) = @_; $s //= ""; $s =~ s/\\(["\\])/$1/g; return $s; }

# Escapa para HTML.
sub h {
  my ($s) = @_; $s //= "";
  $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g;
  return $s;
}

# Captura todas as strings entre aspas de uma linha de registro de array.
sub campos_array {
  my ($linha) = @_;
  my @vals;
  while ($linha =~ /"((?:[^"\\]|\\.)*)"/g) { push @vals, unesc($1); }
  return @vals;
}

sub fonte_de {
  my ($conteudo) = @_;
  return $1 if $conteudo =~ /var\s+F\s*=\s*"((?:[^"\\]|\\.)*)"/;
  return "";
}

sub parse_arr {
  my ($conf) = @_;
  my $c = slurp("$DATA/$conf->{path}");
  my $fonte = fonte_de($c);
  my @cols = @{ $conf->{cols} };
  my @itens;
  # Recorta do "var data = [" até o "];".
  if ($c =~ /var\s+data\s*=\s*\[(.*?)\];/s) {
    my $bloco = $1;
    for my $linha (split /\n/, $bloco) {
      next unless $linha =~ /\[\s*"/;       # só linhas de registro
      my @vals = campos_array($linha);
      next unless @vals;
      my %e = (tribunal => $conf->{sigla}, tipo => $conf->{rotulo}, fonte => $fonte);
      for my $i (0 .. $#cols) { $e{ $cols[$i] } = $vals[$i] // ""; }
      push @itens, \%e;
    }
  }
  return @itens;
}

sub parse_obj {
  my ($conf) = @_;
  my $c = slurp("$DATA/$conf->{path}");
  my @itens;
  # Cada entrada é um objeto { ... } sem chaves aninhadas no texto.
  while ($c =~ /\{(.*?)\}/gs) {
    my $b = $1;
    next unless $b =~ /numero\s*:/;
    my %e = (tribunal => $conf->{sigla}, tipo => $conf->{rotulo});
    for my $campo (qw(numero situacao texto data tema fonte tipo secao)) {
      if ($b =~ /\b$campo\s*:\s*"((?:[^"\\]|\\.)*)"/) { $e{$campo} = unesc($1); }
    }
    next unless defined $e{numero} && length $e{numero};
    push @itens, \%e;
  }
  return @itens;
}

sub data_updated {
  my $c = slurp("$DATA/stf-vinculantes.js");
  return $1 if $c =~ /window\.DATA_UPDATED\s*=\s*"([^"]*)"/;
  return "";
}

# ---- Monta o HTML ----
my @secoes;
my $total = 0;
for my $conf (@FONTES) {
  my @itens = $conf->{mode} eq "obj" ? parse_obj($conf) : parse_arr($conf);
  # Ordena por seção (quando houver, caso das OJs) e depois por número.
  @itens = sort {
    ($a->{secao} || "") cmp ($b->{secao} || "")
      || (($a->{numero} || 0) <=> ($b->{numero} || 0))
  } @itens;
  $total += scalar @itens;
  push @secoes, { conf => $conf, itens => \@itens };
}

my $atualizado = data_updated();
my $toc = join("\n", map {
  sprintf('      <li><a href="#%s">%s</a> (%d)</li>',
    $_->{conf}{anchor}, h($_->{conf}{secao}), scalar @{ $_->{itens} })
} @secoes);

my $corpo = "";
for my $s (@secoes) {
  my $conf = $s->{conf};
  $corpo .= sprintf("\n    <section id=\"%s\">\n      <h2>%s</h2>\n",
    $conf->{anchor}, h($conf->{secao}));
  for my $e (@{ $s->{itens} }) {
    my $cab = $e->{secao}
      ? sprintf("%s nº %s (%s) do %s", $conf->{rotulo}, $e->{numero}, $e->{secao}, $e->{tribunal})
      : sprintf("%s %s do %s", $conf->{rotulo}, $e->{numero}, $e->{tribunal});
    my $situ = $e->{situacao} && $e->{situacao} ne "Vigente"
      ? sprintf(' <span class="situ">(%s)</span>', h($e->{situacao})) : "";
    my @meta;
    push @meta, h($e->{tema}) if $e->{tema};
    push @meta, h($e->{data}) if $e->{data};
    if ($e->{fonte}) {
      push @meta, sprintf('<a href="%s" rel="noopener">fonte</a>', h($e->{fonte}));
    }
    my $meta = @meta ? sprintf('      <p class="meta">%s</p>%s', join(" · ", @meta), "\n") : "";
    $corpo .= sprintf(
      "      <article id=\"%s-%s\">\n        <h3>%s%s</h3>\n        <p>%s</p>\n%s      </article>\n",
      $conf->{anchor}, h($e->{numero}), h($cab), $situ, h($e->{texto}), $meta);
  }
  $corpo .= "    </section>\n";
}

my $html = <<"HTML";
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Súmulas (versão em texto) — Jurisprudência</title>
<meta name="description" content="Lista completa de súmulas (STF, STJ, TST, TJSP, TJRJ) em texto puro, sem JavaScript." />
<style>
  body { max-width: 820px; margin: 0 auto; padding: 24px 16px 60px;
    font-family: Georgia, "Times New Roman", serif; line-height: 1.5; color: #1b1f27; }
  h1 { font-size: 1.6rem; }
  h2 { margin-top: 2rem; border-bottom: 2px solid #ccc; padding-bottom: 4px; }
  h3 { font-size: 1rem; margin: 1.2rem 0 0.3rem; }
  article p { margin: 0.3rem 0; }
  .meta { color: #666; font-size: 0.85rem; }
  .situ { color: #b00; font-weight: normal; }
  .intro { color: #444; }
  nav ul { columns: 2; }
  a { color: #1a4fa0; }
</style>
</head>
<body>
  <h1>Súmulas — versão em texto</h1>
  <p class="intro">Lista completa em texto puro (sem JavaScript), para leitura por
  IA, busca e impressão. Total: $total súmulas${\ ($atualizado ? " · atualizado em $atualizado" : "")}.
  Versão interativa: <a href="./">app de consulta</a>.</p>
  <p class="intro">Dados de fontes públicas. Confira sempre o texto oficial no
  portal do tribunal antes de usar em peça.</p>
  <nav>
    <ul>
$toc
    </ul>
  </nav>
$corpo
</body>
</html>
HTML

open my $out, '>:encoding(UTF-8)', $SAIDA or die "não escreveu $SAIDA: $!";
print $out $html;
close $out;

print "[estatico] $SAIDA gerado: $total súmulas.\n";
