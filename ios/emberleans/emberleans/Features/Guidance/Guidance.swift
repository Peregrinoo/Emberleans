import Foundation

/// Identificadores das regras aplicadas. Permitem rastrear por que cada orientação
/// apareceu (testes e `docs/guidance-sources.md` usam os mesmos identificadores).
nonisolated enum GuidanceRule: String, CaseIterable, Sendable {
    // Emergência (avaliadas antes de qualquer outra regra, com respostas parciais).
    case emergencyWarningSign
    case emergencyElectricity
    case emergencyChemical
    // Informação insuficiente.
    case insufficientUnknownCause
    // Primeiros cuidados por causa informada pelo usuário.
    case heatRecentFirstAid
    case heatOlderCare
    case cutRecentFirstAid
    case cutOlderCare
    case impactRecentFirstAid
    case impactOlderCare
    // Avisos de contexto.
    case sensitiveLocation
    case warningSignsUnknown
    case onsetUnknown
}

/// Nível de urgência comunicado no topo da orientação.
nonisolated enum UrgencyLevel: Int, Comparable, Sendable {
    /// Orientações iniciais; procurar atendimento se surgir algum sinal da lista.
    case observe
    /// Recomenda-se avaliação por um profissional de saúde.
    case professionalEvaluation
    /// Procurar atendimento médico imediatamente.
    case urgentCare
    /// Ligar agora para o serviço de emergência (SAMU 192).
    case callEmergency

    static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Passo numerado de "O que fazer agora".
nonisolated struct GuidanceStep: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let sources: [GuidanceSource]
}

/// Item simples de lista ("O que evitar", "Quando procurar atendimento", avisos).
nonisolated struct GuidanceItem: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let sources: [GuidanceSource]
}

/// Orientação completa, montada exclusivamente a partir das respostas do usuário.
nonisolated struct Guidance: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case standard
        case insufficientInformation
        case emergency
    }

    let kind: Kind
    let urgency: UrgencyLevel
    let headline: String
    let summary: String
    /// Motivos que levaram à emergência, nas palavras das respostas do usuário.
    let emergencyReasons: [String]
    /// Avisos de contexto (região sensível, sinais não informados etc.).
    let notices: [GuidanceItem]
    let steps: [GuidanceStep]
    let avoid: [GuidanceItem]
    let seekCare: [GuidanceItem]
    let appliedRules: [GuidanceRule]

    /// Todas as fontes citadas, sem repetição, na ordem em que aparecem.
    var sources: [GuidanceSource] {
        var seen = Set<GuidanceSource>()
        let all = notices.flatMap(\.sources) + steps.flatMap(\.sources)
            + avoid.flatMap(\.sources) + seekCare.flatMap(\.sources)
        return all.filter { seen.insert($0).inserted }
    }

    /// Todos os textos exibidos (usado nos testes de linguagem proibida).
    var allTexts: [String] {
        [headline, summary] + emergencyReasons + notices.map(\.text)
            + steps.flatMap { [$0.title, $0.detail] } + avoid.map(\.text) + seekCare.map(\.text)
    }
}

/// Resultado da avaliação das regras.
nonisolated enum GuidanceEvaluation: Equatable, Sendable {
    /// Ainda faltam respostas e nenhuma regra de emergência foi acionada.
    case incomplete(next: Question)
    case guidance(Guidance)
}
