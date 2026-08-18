// Súmulas do TJMT (Tribunal Pleno). Conferir no portal do TJMT antes de citar.
(function () {
  var F = "https://jurisprudencia.tjmt.jus.br/sumulas";
  var data = [
    ["1","Vigente","A execução de sentença proferida em Ação Civil Coletiva, com efeito \"erga omnes\", obedecerá a livre distribuição."],
    ["2","Vigente","Sem que date de mais de cinco anos antes da promulgação da Constituição em vigor, ou que, depois disso, tenha o servidor obtido aprovação em concurso, não há qualquer direito, menos ainda líquido e certo, que ampare a pretensão de estabilidade, mesmo quando, por longo período, perdure o vinculo funcional temporário."],
  ];
  var out = data.map(function (r) {
    return { id: "tjmt-sumula-" + r[0], tribunal: "TJMT", tipo: "Súmula", numero: r[0], data: "", tema: "", situacao: r[1], texto: r[2], fonte: F };
  });
  window.ENTRIES = (window.ENTRIES || []).concat(out);
})();
