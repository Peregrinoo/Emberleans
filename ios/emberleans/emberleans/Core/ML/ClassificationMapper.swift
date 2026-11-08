import Foundation

/// Converte a saída bruta do modelo (rótulo → probabilidade) em um `ClassificationResult`.
///
/// Não presume a ordem das saídas: cada rótulo é mapeado explicitamente para uma
/// `LesionClass`. Rótulos desconhecidos, classes ausentes ou probabilidades
/// inválidas são tratados como erro, em vez de produzir um resultado silenciosamente errado.
nonisolated enum ClassificationMapper {
    /// Tolerância para a soma das probabilidades (o modelo roda em FP16).
    static let sumTolerance = 0.02

    static func makeResult(
        from labelScores: [String: Double],
        inferenceDuration: Duration,
        source: ClassificationResult.Source
    ) throws -> ClassificationResult {
        var probabilities: [LesionClass: Double] = [:]

        for (label, value) in labelScores {
            guard let lesionClass = LesionClass(modelLabel: label) else {
                throw ClassifierError.unexpectedOutput("Rótulo desconhecido: \(label)")
            }
            guard value.isFinite, value >= 0, value <= 1 + sumTolerance else {
                throw ClassifierError.unexpectedOutput("Probabilidade inválida para \(label): \(value)")
            }
            probabilities[lesionClass] = min(value, 1)
        }

        let missing = LesionClass.allCases.filter { probabilities[$0] == nil }
        guard missing.isEmpty else {
            let labels = missing.map(\.modelLabel).joined(separator: ", ")
            throw ClassifierError.unexpectedOutput("Classes ausentes na saída: \(labels)")
        }

        let total = probabilities.values.reduce(0, +)
        guard abs(total - 1) <= sumTolerance else {
            throw ClassifierError.unexpectedOutput("As probabilidades somam \(total), esperado 1")
        }

        let scores = LesionClass.allCases.map { ClassScore(lesionClass: $0, probability: probabilities[$0] ?? 0) }
        // Comparação estrita: em caso de empate, prevalece a primeira classe na ordem de exibição.
        let top = scores.reduce(scores[0]) { best, candidate in
            candidate.probability > best.probability ? candidate : best
        }

        return ClassificationResult(
            scores: scores,
            topClass: top.lesionClass,
            inferenceDuration: inferenceDuration,
            source: source
        )
    }
}
