// Súmulas do TJMS. Situação conforme fonte; conferir no portal do TJMS antes de citar.
(function () {
  var F = "https://www.tjms.jus.br/sumulas";
  var data = [
    ["1","06/06/1990","Vigente","Nos casos de elisão de falência pelo deposito da quantia devida com a finalidade de efetuar o pagamento, cabe a condenação do devedor em honorários advocatícios bem como a atualização do débito mediante correção monetária, a partir do vencimento do titulo, na forma da Lei n. 6.899/81."],
    ["2","17/06/1991","Vigente","Quando a verba honorária for fixada em percentual sobre o valor dado à causa no inicio da ação, este já sofreu o efeito corrosivo da inflação, de maneira que aquela verba deve ser aplicada sobre o valor da ação, devidamente corrigido a partir do seu ajuizamento, sob pena de aviltamento dos honorários e distanciamento do real valor do litígio."],
    ["3","07/05/2015","Vigente","Nas revisões tarifárias de energia elétrica, o período de cobrança em excesso corresponde àquele compreendido entre abril de 2004 a dezembro de 2007."],
    ["4","25/04/2017","Vigente","Não há necessidade de prévio requerimento administrativo para o ajuizamento de demanda relativa à cobrança de seguro vinculado ao DPVAT."],
  ];
  var out = data.map(function (r) {
    return { id: "tjms-sumula-" + r[0], tribunal: "TJMS", tipo: "Súmula", numero: r[0], data: r[1], tema: "", situacao: r[2], texto: r[3], fonte: F };
  });
  window.ENTRIES = (window.ENTRIES || []).concat(out);
})();
