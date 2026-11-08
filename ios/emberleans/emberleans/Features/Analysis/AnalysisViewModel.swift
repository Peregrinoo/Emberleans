import Observation
import UIKit

/// Coordena uma análise: seleção da imagem, inferência e resultado.
@MainActor
@Observable
final class AnalysisViewModel {
    private(set) var state: AnalysisState = .idle

    private let classifier: any ImageClassifying

    init(classifier: any ImageClassifying) {
        self.classifier = classifier
    }

    var canAnalyze: Bool {
        state.image != nil && !state.isProcessing
    }

    /// Recebe uma nova imagem; descarta qualquer resultado anterior.
    func select(_ image: SelectedImage) {
        state = .imageSelected(image)
    }

    /// A seleção foi concluída, mas o arquivo não é uma imagem válida.
    func selectionFailed() {
        state = .failure(AnalysisFailure(image: nil, error: .invalidImage))
    }

    /// Executa a inferência da imagem atual. Ignorada se não houver imagem ou se já
    /// houver uma análise em andamento.
    func analyze() async {
        guard canAnalyze, let image = state.image else { return }
        state = .processing(image)

        guard let input = ClassifierInput(image: image.image) else {
            state = .failure(AnalysisFailure(image: image, error: .invalidImage))
            return
        }

        do {
            let result = try await classifier.classify(input)
            guard isStillProcessing(image) else { return }
            state = .success(image, result)
        } catch {
            guard isStillProcessing(image) else { return }
            state = .failure(AnalysisFailure(image: image, error: AnalysisError(error)))
        }
    }

    func reset() {
        state = .idle
    }

    /// Evita que o resultado de uma imagem antiga sobrescreva uma seleção mais recente.
    private func isStillProcessing(_ image: SelectedImage) -> Bool {
        if case .processing(let current) = state, current.id == image.id { return true }
        return false
    }
}
