import Foundation

/// Conteúdo educativo estático, escrito a partir das fontes citadas em cada item.
/// Nada aqui é gerado dinamicamente e nada depende da análise visual.
/// O conteúdo não indica medicamentos, não faz diagnóstico e não afirma que uma lesão é segura.
nonisolated enum GuidanceContent {

    // MARK: - Passos: queimadura por calor

    static let heatCool = GuidanceStep(
        id: "heat.cool",
        title: "Resfrie a região",
        detail: "Deixe água corrente fresca ou morna (nunca gelada) correr sobre a queimadura por 20 minutos, o quanto antes. O resfriamento é indicado até 3 horas depois. Sem água corrente, use água engarrafada fresca ou uma toalha molhada.",
        systemImage: "drop",
        sources: [.nhsBurns, .britishRedCrossBurns]
    )

    static let heatCoolIfRecent = GuidanceStep(
        id: "heat.coolIfRecent",
        title: "Resfrie, se foi há até 3 horas",
        detail: "Se a queimadura aconteceu há até 3 horas, deixe água corrente fresca ou morna (nunca gelada) correr sobre a região por 20 minutos. Sem água corrente, use água engarrafada fresca ou uma toalha molhada.",
        systemImage: "drop",
        sources: [.nhsBurns]
    )

    static let heatRemoveJewellery = GuidanceStep(
        id: "heat.removeJewellery",
        title: "Retire anéis e acessórios",
        detail: "Retire joias e roupas próximas da região, a menos que estejam grudadas na pele.",
        systemImage: "circle.circle",
        sources: [.nhsBurns]
    )

    static let heatCover = GuidanceStep(
        id: "heat.cover",
        title: "Proteja a pele",
        detail: "Depois de resfriar, cubra sem apertar com filme plástico ou com um pano limpo que não solte fiapos. Não use filme plástico no rosto.",
        systemImage: "bandage",
        sources: [.nhsBurns, .americanBurnAssociation]
    )

    static let heatCoverOlder = GuidanceStep(
        id: "heat.coverOlder",
        title: "Mantenha a região protegida",
        detail: "Mantenha a queimadura limpa e coberta sem apertar, com um curativo ou pano limpo que não solte fiapos.",
        systemImage: "bandage",
        sources: [.americanBurnAssociation]
    )

    static let keepWarm = GuidanceStep(
        id: "heat.keepWarm",
        title: "Mantenha a pessoa aquecida",
        detail: "Enquanto resfria a queimadura, mantenha o restante do corpo aquecido. Se a pessoa começar a tremer, interrompa o resfriamento.",
        systemImage: "thermometer.medium",
        sources: [.nhsBurns, .americanBurnAssociation]
    )

    // MARK: - Passos: corte ou arranhão

    static let cutPressure = GuidanceStep(
        id: "cut.pressure",
        title: "Pare o sangramento",
        detail: "Verifique se não há nada preso na ferida. Se não houver, pressione com um curativo ou pano limpo e dobrado por 10 minutos. Se possível, eleve a região. Se continuar sangrando, mantenha o primeiro pano, coloque outro por cima e pressione por mais 10 minutos.",
        systemImage: "hand.raised",
        sources: [.nhsCuts]
    )

    static let cutClean = GuidanceStep(
        id: "cut.clean",
        title: "Limpe a ferida",
        detail: "Quando o sangramento parar, enxágue a ferida com água da torneira ou engarrafada. Limpe a pele ao redor com água e sabão.",
        systemImage: "drop",
        sources: [.nhsCuts]
    )

    static let cutCover = GuidanceStep(
        id: "cut.cover",
        title: "Cubra a ferida",
        detail: "Cubra com um curativo adesivo ou uma compressa limpa para ajudar a evitar infecção.",
        systemImage: "bandage",
        sources: [.nhsCuts]
    )

    static let cutKeepClean = GuidanceStep(
        id: "cut.keepClean",
        title: "Mantenha limpo e coberto",
        detail: "Mantenha a ferida limpa e coberta com um curativo limpo.",
        systemImage: "bandage",
        sources: [.nhsCuts]
    )

    // MARK: - Passos: pancada

    static let impactCold = GuidanceStep(
        id: "impact.cold",
        title: "Aplique frio protegido",
        detail: "Coloque gelo ou uma compressa fria envolvida em um pano sobre a região, por até 15 minutos a cada hora. Não coloque o gelo direto na pele.",
        systemImage: "snowflake",
        sources: [.medlinePlusBruises]
    )

    static let impactElevate = GuidanceStep(
        id: "impact.elevate",
        title: "Eleve a região",
        detail: "Quando possível, mantenha a região atingida acima do nível do coração.",
        systemImage: "arrow.up",
        sources: [.medlinePlusBruises]
    )

    static let impactRest = GuidanceStep(
        id: "impact.rest",
        title: "Poupe a região",
        detail: "Evite esforçar a parte do corpo atingida enquanto ela se recupera.",
        systemImage: "pause.circle",
        sources: [.medlinePlusBruises]
    )

    // MARK: - Passos comuns

    static let observeSigns = GuidanceStep(
        id: "common.observe",
        title: "Observe sinais de alerta",
        detail: "Acompanhe a região nas próximas horas e dias. Se surgir algum sinal da lista \"Quando procurar atendimento\", procure um serviço de saúde.",
        systemImage: "eye",
        sources: [.emberLensConservativeRule]
    )

    static let observeInfection = GuidanceStep(
        id: "common.observeInfection",
        title: "Observe sinais de infecção",
        detail: "Inchaço, vermelhidão, dor que aumenta ou pus na região ou ao redor dela são motivos para procurar atendimento.",
        systemImage: "eye",
        sources: [.nhsCuts]
    )

    // MARK: - Passos de emergência

    static let emergencyCall = GuidanceStep(
        id: "emergency.call",
        title: "Peça ajuda agora",
        detail: "Ligue para o SAMU (192) ou procure um pronto-socorro. Siga as orientações de quem atender a ligação.",
        systemImage: "phone",
        sources: [.emberLensConservativeRule]
    )

    static let electricitySafety = GuidanceStep(
        id: "emergency.electricitySafety",
        title: "Garanta a sua segurança",
        detail: "Se possível, desligue a energia antes de ajudar. Não toque na pessoa enquanto ela estiver em contato com a corrente. Perto de fios de alta tensão, não se aproxime e aguarde o desligamento.",
        systemImage: "bolt.slash",
        sources: [.stJohnElectricShock]
    )

    static let chemicalRinse = GuidanceStep(
        id: "emergency.chemicalRinse",
        title: "Enxágue com água corrente",
        detail: "Lave a região com água corrente fresca por pelo menos 20 minutos e continue mesmo que o produto pareça ter saído. Se for um pó seco, retire o excesso com cuidado antes de molhar. Proteja-se para não ter contato com o produto.",
        systemImage: "drop",
        sources: [.healthdirectChemicalBurns, .healthwiseChemicalBurns]
    )

    static let chemicalRemoveClothing = GuidanceStep(
        id: "emergency.chemicalClothing",
        title: "Retire o que foi atingido",
        detail: "Retire roupas, calçados e acessórios atingidos pelo produto. Não tente remover o que estiver grudado na pele.",
        systemImage: "tshirt",
        sources: [.healthdirectChemicalBurns]
    )

    static let chemicalBringContainer = GuidanceStep(
        id: "emergency.chemicalContainer",
        title: "Leve a embalagem",
        detail: "Leve a embalagem ou o nome do produto para o atendimento.",
        systemImage: "shippingbox",
        sources: [.healthwiseChemicalBurns]
    )

    static let bleedingPressure = GuidanceStep(
        id: "emergency.bleedingPressure",
        title: "Pressione o local",
        detail: "Enquanto aguarda ajuda, pressione firmemente a ferida com um pano limpo ou curativo e, se possível, eleve a região. Se houver algo preso na ferida, não pressione sobre o objeto.",
        systemImage: "hand.raised",
        sources: [.nhsCuts]
    )

    // MARK: - O que evitar

    static let avoidIce = GuidanceItem(
        id: "avoid.ice",
        text: "Não aplique gelo nem água gelada na queimadura.",
        sources: [.nhsBurns, .americanBurnAssociation]
    )

    static let avoidHomeRemedies = GuidanceItem(
        id: "avoid.homeRemedies",
        text: "Não use receitas caseiras, como manteiga, pasta de dente, óleos ou cremes.",
        sources: [.nhsBurns, .britishRedCrossBurns, .americanBurnAssociation]
    )

    static let avoidBlisters = GuidanceItem(
        id: "avoid.blisters",
        text: "Não estoure bolhas.",
        sources: [.americanBurnAssociation]
    )

    static let avoidStuckClothing = GuidanceItem(
        id: "avoid.stuckClothing",
        text: "Não puxe roupas ou objetos grudados na pele.",
        sources: [.nhsBurns, .healthdirectChemicalBurns]
    )

    static let avoidTouchingLiveVictim = GuidanceItem(
        id: "avoid.touchingLiveVictim",
        text: "Não toque na pessoa enquanto ela estiver em contato com a eletricidade.",
        sources: [.stJohnElectricShock]
    )

    static let avoidChemicalContact = GuidanceItem(
        id: "avoid.chemicalContact",
        text: "Evite que o produto atinja a sua própria pele.",
        sources: [.healthdirectChemicalBurns]
    )

    static let avoidPressingObject = GuidanceItem(
        id: "avoid.pressingObject",
        text: "Não pressione nem retire objetos presos na ferida.",
        sources: [.nhsCuts]
    )

    static let avoidDirectIce = GuidanceItem(
        id: "avoid.directIce",
        text: "Não coloque gelo diretamente sobre a pele.",
        sources: [.medlinePlusBruises]
    )

    // MARK: - Quando procurar atendimento

    static let seekBreathing = GuidanceItem(
        id: "seek.breathing",
        text: "Dificuldade para respirar.",
        sources: [.emberLensConservativeRule]
    )

    static let seekBleeding = GuidanceItem(
        id: "seek.bleeding",
        text: "Sangramento intenso ou que não para com pressão.",
        sources: [.nhsCuts]
    )

    static let seekChemicalElectrical = GuidanceItem(
        id: "seek.chemicalElectrical",
        text: "Qualquer queimadura química ou elétrica.",
        sources: [.nhsBurns]
    )

    static let seekExtensive = GuidanceItem(
        id: "seek.extensive",
        text: "Lesão extensa ou que pareça profunda, como uma queimadura maior que a palma da mão ou com pele esbranquiçada ou escurecida.",
        sources: [.nhsBurns]
    )

    static let seekSensitiveRegions = GuidanceItem(
        id: "seek.sensitiveRegions",
        text: "Lesões no rosto, pescoço, mãos, pés ou região íntima.",
        sources: [.nhsBurns, .emberLensConservativeRule]
    )

    static let seekSensationMovement = GuidanceItem(
        id: "seek.sensationMovement",
        text: "Perda de sensibilidade ou dificuldade para mover a região.",
        sources: [.healthNZBruises, .emberLensConservativeRule]
    )

    static let seekInfection = GuidanceItem(
        id: "seek.infection",
        text: "Sinais de infecção: inchaço, vermelhidão, dor que aumenta ou pus.",
        sources: [.nhsCuts]
    )

    static let seekChildBurn = GuidanceItem(
        id: "seek.childBurn",
        text: "Queimadura em bebê ou criança, mesmo depois de resfriada.",
        sources: [.britishRedCrossBurns]
    )

    static let seekDirtyWound = GuidanceItem(
        id: "seek.dirtyWound",
        text: "Ferida com terra, pus ou que continua suja depois de limpa, ou mordida de pessoa ou animal.",
        sources: [.nhsCuts]
    )

    static let seekBruiseWorse = GuidanceItem(
        id: "seek.bruiseWorse",
        text: "Região muito inchada ou muito dolorida, ou uso de medicamento anticoagulante.",
        sources: [.healthNZBruises]
    )

    static let seekWhenUnsure = GuidanceItem(
        id: "seek.unsure",
        text: "Sempre que houver dúvida sobre a gravidade.",
        sources: [.emberLensConservativeRule]
    )

    /// Lista base, sempre exibida, independentemente das respostas.
    static let baseSeekCare: [GuidanceItem] = [
        seekBreathing,
        seekBleeding,
        seekChemicalElectrical,
        seekExtensive,
        seekSensitiveRegions,
        seekSensationMovement,
        seekInfection,
    ]

    // MARK: - Avisos de contexto

    static let noticeSensitiveLocation = GuidanceItem(
        id: "notice.sensitiveLocation",
        text: "Lesões nessa região merecem avaliação de um profissional de saúde.",
        sources: [.nhsBurns, .emberLensConservativeRule]
    )

    static let noticeWarningSignsUnknown = GuidanceItem(
        id: "notice.warningSignsUnknown",
        text: "Você não soube informar se há sinais de alerta. Isso não significa ausência de risco: confira a lista \"Quando procurar atendimento\" e, na dúvida, procure um serviço de saúde.",
        sources: [.emberLensConservativeRule]
    )

    static let noticeOnsetUnknown = GuidanceItem(
        id: "notice.onsetUnknown",
        text: "Sem saber quando a lesão aconteceu, algumas orientações dependem do tempo decorrido. Elas estão descritas com essa condição.",
        sources: [.emberLensConservativeRule]
    )
}
