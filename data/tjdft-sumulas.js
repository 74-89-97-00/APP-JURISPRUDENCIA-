// Súmulas do TJDFT (tjdft-sumula). Situação conforme fonte; conferir no portal antes de citar.
(function () {
  var F = "https://www.tjdft.jus.br/consultas/jurisprudencia/sumulas/sumulas-do-tjdft";
  var T = "";
  var P = "tjdft-sumula";
  var data = [
    ["1","Substituída","Nos concursos públicos para ingresso na carreira policial civil do Distrito Federal, reveste-se de legalidade a exigência de exame psicotécnico, mas para a sua validade deve ser adotado método que permita a fundamentação do resultado e o seu conhecimento pelo candidato, com previsão de recurso administrativo. Concedido mandado de segurança para anular o exame psicotécnico realizado sem os requisitos exigidos, o candidato poderá prosseguir nas demais fases do concurso independentemente de submeter-se a novo exame psicotécnico, devendo a apuração dos requisitos previstos em lei ser efetuado durante o estágio probatório."],
    ["2","Vigente","A conversão de cruzeiros reais para a unidade real de valor há de ser feita pela URV da data do efetivo pagamento e não pelo do último dia do mês de competência (art. 22 da lei 8.880/94)."],
    ["3","Vigente","A apresentação de diploma, quando exigido para o ingresso em carreira do serviço público é obrigatória, apenas, na data da posse."],
    ["4","Vigente","A aprovação em concurso público gera para o candidato mera expectativa de direito à nomeação. Contudo, diante da abertura de novo concurso, válido ainda o anterior, assegura-se ao candidato nomeação precedente em relação aos novos concursados."],
    ["5","Cancelada","É legal a exigência editalícia de comprovação de dois anos de bacharelado em direito por parte do candidato ao cargo de promotor de justiça adjunto do Ministério Público do Distrito Federal e Territórios."],
    ["6","Vigente","A acumulação de cargos prevista no art. 37, XVI, \"b\" da Constituição Federal só é possível quando o cargo dito técnico exigir prévio domínio de determinado e específico campo de conhecimento."],
    ["7","Vigente","Para o advogado postular em juízo exceção de suspeição de magistrado, mister se faz procuração com poderes especiais."],
    ["8","Vigente","Para configurar-se a causa especial de aumento de pena prevista no inciso III do art. 18 da lei nº 6.368/76, é bastante que haja a associação, ainda que esporádica ou eventual."],
    ["9","Cancelada","É cabível a prisão civil de devedor que não efetua a entrega do bem alienado fiduciariamente."],
    ["10","Vigente","O controle externo da atividade policial é função institucional do Ministério Público, podendo este requerer informações e documentos em delegacias de polícia para instrução de procedimento administrativo, sendo ilegal a recusa em fornecê-los."],
    ["11","Cancelada","O emprego de arma de fogo ineficiente, descarregada ou de brinquedo, quando ignorada tal circunstância pela vítima, constitui, também, causa especial de aumento de pena na prática do roubo, posto que capazes de causar a intimidação."],
    ["12","Cancelada","O réu condenado a regime integralmente fechado pela prática de crime hediondo, tráfico e terrorismo não será beneficiado com a progressão de regime prisional sob a invocação de analogia com o tratamento dado ao crime de tortura."],
    ["13","Vigente","É nula a decisão que acarreta a regressão definitiva de regime prisional quando não há oitiva pessoal do sentenciado por ferir o princípio da ampla defesa."],
    ["14","Vigente","Deferido requerimento de exame de dependência toxicológica, em se tratando do delito previsto no art. 12 da lei de tóxicos, o prazo para a formação da culpa é contado em dobro."],
    ["15","Vigente","O Habeas Corpus não é o meio adequado para verificação de pedido de progressão de regime prisional, por depender de produção e valoração de provas pelo juízo das execuções penais."],
    ["16","Vigente","Para a caracterização do delito previsto no art. 35, da Lei nº 11.343/2006, é imprescindível a demonstração do dolo de associação em caráter permanente e estável."],
    ["17","Vigente","O processamento do recurso de agravo em execução penal segue o rito do recurso em sentido estrito previsto no Código de Processo Penal."],
    ["18","Substituída","O ato praticado por autoridade apontada como coatora, sem privilégio de foro, ainda que em obediência a ordens de superior hierárquico, há de ser analisado em sede de mandado de segurança pelo juízo da Vara de Fazenda Pública."],
    ["19","Cancelada","O preparo do recurso há de ser comprovado no momento de sua interposição, ainda que remanesça parte do prazo para seu exercitamento, sob pena de deserção."],
    ["20","Vigente","A validade do exame psicotécnico está condicionada à previsão legal, à exigência de critérios objetivos e à garantia de recurso administrativo."],
    ["21","Cancelada","A indicação errônea da autoridade coatora importa na extinção do processo."],
    ["22","Vigente","É prescindível a apreensão da arma utilizada na prática do roubo para o reconhecimento da causa de aumento de seu emprego, quando restar demonstrada por outros meios."],
    ["23","Vigente","Em ação proposta por consumidor, o juiz não pode declinar de ofício da competência territorial."],
    ["24","Vigente","A competência para julgamento da ação de usucapião, fundada no art. 1.240-A do Código Civil, é do Juízo Cível."],
    ["25","Vigente","A prévia oitiva informal de adolescente não é condição de procedibilidade para o oferecimento de representação no processo de apuração de ato infracional."],
    ["26","Vigente","Compete ao juiz da execução penal examinar e decidir pedido de gratuidade de justiça do condenado."],
    ["27","Vigente","Presentes duas ou mais qualificadoras no delito, uma deve ser utilizada para fins de tipificação do crime qualificado e as demais na dosimetria da pena, seja na pena-base, seja como circunstância agravante, se prevista legalmente como tal, vedado o bis in idem ."],
    ["28","Vigente","A isenção de custas previstas nos artigos 1º do Decreto-Lei 500/1969 e 4º, inciso I, da Lei 9.289/1996, abrange o cumprimento de sentença requerido pelo Distrito Federal que tem por objeto honorários de sucumbência."],
    ["29","Vigente","Na ação de busca e apreensão não podem ser impostas restrições ou condições para a alienação do veículo automotor depois da consolidação da sua propriedade no patrimônio do credor fiduciário, constante a inteligência dos artigos 2º e 3º, §§ 1º e 2º, do Decreto-Lei 911/1969."],
  ];
  var out = data.map(function (r) {
    return { id: P + "-" + r[0], tribunal: "TJDFT", tipo: "Súmula", numero: r[0], data: "", tema: T, situacao: r[1], texto: r[2], fonte: F };
  });
  window.ENTRIES = (window.ENTRIES || []).concat(out);
})();
