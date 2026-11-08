import Foundation

/// Estado explícito da análise. Os casos são mutuamente exclusivos.
enum AnalysisState: Equatable {
    case idle
    case imageSelected(SelectedImage)
    case processing(SelectedImage)
    case success(SelectedImage, ClassificationResult)
    case failure(AnalysisFailure)

    /// Imagem associada ao estado, se houver.
    var image: SelectedImage? {
        switch self {
        case .idle: nil
        case .imageSelected(let image), .processing(let image), .success(let image, _): image
        case .failure(let failure): failure.image
        }
    }

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }

    /// Verdadeiro quando a análise terminou (com ou sem sucesso) para uma imagem válida.
    var hasFinishedAnalysis: Bool {
        switch self {
        case .success: true
        case .failure(let failure): failure.image != nil
        default: false
        }
    }
}

struct AnalysisFailure: Equatable {
    /// `nil` quando a própria seleção era inválida.
    let image: SelectedImage?
    let error: AnalysisError
}

/// Erros apresentados ao usuário.
enum AnalysisError: Error, Equatable {
    case invalidImage
    case modelUnavailable
    case inferenceFailed
    case unexpectedOutput

    init(_ error: any Error) {
        guard let classifierError = error as? ClassifierError else {
            self = .inferenceFailed
            return
        }
        switch classifierError {
        case .modelNotFound, .modelLoadFailed, .unexpectedModelClasses, .unexpectedModelInput:
            self = .modelUnavailable
        case .invalidImage:
            self = .invalidImage
        case .inferenceFailed:
            self = .inferenceFailed
        case .unexpectedOutput:
            self = .unexpectedOutput
        }
    }

    var title: String {
        switch self {
        case .invalidImage: "Esta imagem não pôde ser analisada"
        case .modelUnavailable: "Modelo indisponível"
        case .inferenceFailed, .unexpectedOutput: "Não foi possível analisar a imagem"
        }
    }

    var message: String {
        switch self {
        case .invalidImage:
            "O arquivo pode estar corrompido ou em um formato incompatível. Escolha outra imagem."
        case .modelUnavailable:
            "O modelo de classificação não pôde ser carregado neste dispositivo. Nenhuma classificação foi gerada."
        case .inferenceFailed, .unexpectedOutput:
            "Ocorreu um erro durante o processamento no dispositivo. Nenhuma classificação foi gerada."
        }
    }

    /// Código técnico discreto, exibido para diagnóstico.
    var code: String {
        switch self {
        case .invalidImage: "invalidImage"
        case .modelUnavailable: "modelUnavailable"
        case .inferenceFailed: "inferenceFailed"
        case .unexpectedOutput: "unexpectedOutput"
        }
    }

    /// Tentar de novo só faz sentido quando a falha não é da imagem.
    var isRetryable: Bool {
        self != .invalidImage
    }
}
