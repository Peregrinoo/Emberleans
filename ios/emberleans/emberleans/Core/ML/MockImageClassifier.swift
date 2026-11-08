import Foundation

/// ⚠️ Implementação SIMULADA do classificador.
///
/// Usada somente em SwiftUI Previews e, em builds DEBUG, quando o `EmberLens.mlmodelc`
/// não está no bundle. Os resultados saem com `source == .simulated`, e a interface
/// identifica isso explicitamente. Nunca representa uma inferência real.
nonisolated final class MockImageClassifier: ImageClassifying, @unchecked Sendable {
    private let scores: [String: Double]

    init(scores: [String: Double] = MockImageClassifier.sampleScores) {
        self.scores = scores
    }

    func classify(_ input: ClassifierInput) async throws -> ClassificationResult {
        try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .simulated)
    }

    static let sampleScores: [String: Double] = [
        "Burn": 0.72, "Abrasion": 0.14, "Bruise": 0.03, "Laceration": 0.09, "Normal Skin": 0.02,
    ]
}

/// Classificador usado em builds de release quando o modelo não pode ser carregado:
/// toda análise falha com o erro original, exibido como "modelo indisponível".
nonisolated final class UnavailableImageClassifier: ImageClassifying, @unchecked Sendable {
    private let error: ClassifierError

    init(error: ClassifierError) {
        self.error = error
    }

    func classify(_ input: ClassifierInput) async throws -> ClassificationResult {
        throw error
    }
}
