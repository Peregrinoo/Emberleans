import Foundation

/// Pontuação do modelo para uma categoria.
nonisolated struct ClassScore: Identifiable, Equatable, Sendable {
    let lesionClass: LesionClass
    /// Probabilidade (softmax), entre 0 e 1.
    let probability: Double

    var id: LesionClass { lesionClass }
}

/// Resultado estruturado de uma classificação.
nonisolated struct ClassificationResult: Equatable, Sendable {
    /// Origem do resultado. `.simulated` nunca deve ser apresentado como inferência real.
    enum Source: Equatable, Sendable {
        case coreML
        case simulated
    }

    /// Pontuações das cinco categorias, na ordem de exibição (`LesionClass.allCases`).
    let scores: [ClassScore]
    /// Categoria com a maior pontuação.
    let topClass: LesionClass
    /// Tempo medido da execução da requisição Vision + Core ML.
    let inferenceDuration: Duration
    let source: Source

    var topProbability: Double {
        probability(for: topClass)
    }

    func probability(for lesionClass: LesionClass) -> Double {
        scores.first { $0.lesionClass == lesionClass }?.probability ?? 0
    }
}
