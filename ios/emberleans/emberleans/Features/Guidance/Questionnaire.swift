import Foundation

// Respostas do questionário. Elas são a ÚNICA entrada das regras de orientação:
// a categoria prevista pela análise visual nunca participa dessas decisões.

/// Pergunta 1: como a lesão aconteceu.
nonisolated enum InjuryCause: String, CaseIterable, Identifiable, Sendable {
    case heat
    case cutOrScrape
    case impact
    case chemical
    case electricity
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heat: "Calor ou líquido quente"
        case .cutOrScrape: "Corte ou arranhão"
        case .impact: "Pancada"
        case .chemical: "Produto químico"
        case .electricity: "Eletricidade"
        case .unknown: "Não sei informar"
        }
    }

    var systemImage: String {
        switch self {
        case .heat: "flame"
        case .cutOrScrape: "bandage"
        case .impact: "hand.raised"
        case .chemical: "flask"
        case .electricity: "bolt"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Pergunta 2: onde a lesão está.
nonisolated enum BodyLocation: String, CaseIterable, Identifiable, Sendable {
    case handsOrFeet
    case faceOrNeck
    case trunk
    case armsOrLegs
    case intimate
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .handsOrFeet: "Mãos ou pés"
        case .faceOrNeck: "Rosto ou pescoço"
        case .trunk: "Tronco"
        case .armsOrLegs: "Braços ou pernas"
        case .intimate: "Região íntima"
        case .other: "Outra região"
        }
    }

    var systemImage: String {
        switch self {
        case .handsOrFeet: "hand.raised.fingers.spread"
        case .faceOrNeck: "face.smiling"
        case .trunk: "figure.stand"
        case .armsOrLegs: "figure.walk"
        case .intimate: "lock"
        case .other: "circle.dashed"
        }
    }

    /// Regiões que pedem avaliação profissional (NHS, burns and scalds; regra conservadora do app).
    var isSensitive: Bool {
        switch self {
        case .handsOrFeet, .faceOrNeck, .intimate: true
        case .trunk, .armsOrLegs, .other: false
        }
    }
}

/// Sinais de alerta da pergunta 3.
nonisolated enum WarningSign: String, CaseIterable, Identifiable, Sendable {
    case breathingDifficulty
    case heavyBleeding
    case severePain
    case lossOfSensation
    case extensiveOrDeep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathingDifficulty: "Dificuldade para respirar"
        case .heavyBleeding: "Sangramento intenso"
        case .severePain: "Dor intensa"
        case .lossOfSensation: "Perda de sensibilidade"
        case .extensiveOrDeep: "Lesão extensa ou aparentemente profunda"
        }
    }

    var systemImage: String {
        switch self {
        case .breathingDifficulty: "lungs"
        case .heavyBleeding: "drop"
        case .severePain: "exclamationmark.circle"
        case .lossOfSensation: "hand.point.up.braille"
        case .extensiveOrDeep: "square.dashed"
        }
    }
}

/// Resposta da pergunta 3. "Não sei informar" é diferente de "Nenhum desses":
/// a falta de informação nunca é tratada como ausência de risco.
nonisolated enum WarningSignsAnswer: Hashable, Sendable {
    case sign(WarningSign)
    case noneOfThese
    case unknown

    var title: String {
        switch self {
        case .sign(let sign): sign.title
        case .noneOfThese: "Nenhum desses"
        case .unknown: "Não sei informar"
        }
    }

    var systemImage: String {
        switch self {
        case .sign(let sign): sign.systemImage
        case .noneOfThese: "checkmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    static var allOptions: [WarningSignsAnswer] {
        WarningSign.allCases.map { .sign($0) } + [.noneOfThese, .unknown]
    }
}

/// Pergunta 4: quando a lesão aconteceu.
nonisolated enum InjuryOnset: String, CaseIterable, Identifiable, Sendable {
    case justNow
    case today
    case daysAgo
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .justNow: "Agora há pouco"
        case .today: "Hoje"
        case .daysAgo: "Há alguns dias"
        case .unknown: "Não sei informar"
        }
    }

    var systemImage: String {
        switch self {
        case .justNow: "clock.badge.exclamationmark"
        case .today: "sun.max"
        case .daysAgo: "calendar"
        case .unknown: "questionmark.circle"
        }
    }
}

/// As quatro perguntas, na ordem de apresentação.
nonisolated enum Question: Int, CaseIterable, Comparable, Sendable {
    case cause
    case location
    case warningSigns
    case onset

    var title: String {
        switch self {
        case .cause: "Como aconteceu a lesão?"
        case .location: "Onde está localizada?"
        case .warningSigns: "Existe algum sinal de alerta?"
        case .onset: "Quando aconteceu?"
        }
    }

    var number: Int { rawValue + 1 }

    var next: Question? { Question(rawValue: rawValue + 1) }
    var previous: Question? { Question(rawValue: rawValue - 1) }

    static func < (lhs: Question, rhs: Question) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Respostas fornecidas pelo usuário. Campos `nil` ainda não foram respondidos.
nonisolated struct QuestionnaireAnswers: Equatable, Sendable {
    var cause: InjuryCause?
    var location: BodyLocation?
    var warningSigns: WarningSignsAnswer?
    var onset: InjuryOnset?

    func isAnswered(_ question: Question) -> Bool {
        switch question {
        case .cause: cause != nil
        case .location: location != nil
        case .warningSigns: warningSigns != nil
        case .onset: onset != nil
        }
    }

    /// Primeira pergunta ainda sem resposta.
    var firstUnanswered: Question? {
        Question.allCases.first { !isAnswered($0) }
    }

    var isComplete: Bool { firstUnanswered == nil }

    /// Texto curto da resposta, para o resumo da orientação.
    func answerTitle(for question: Question) -> String? {
        switch question {
        case .cause: cause?.title
        case .location: location?.title
        case .warningSigns: warningSigns?.title
        case .onset: onset?.title
        }
    }
}
