import Foundation

/// Erros da camada de inferência.
nonisolated enum ClassifierError: Error, Equatable, Sendable {
    /// O pacote `EmberLens.mlmodelc` não está no bundle do app.
    case modelNotFound
    /// O Core ML não conseguiu carregar o modelo.
    case modelLoadFailed(String)
    /// As classes declaradas pelo modelo não são as cinco esperadas.
    case unexpectedModelClasses(found: [String])
    /// A entrada do modelo não corresponde ao contrato de pré-processamento.
    case unexpectedModelInput(String)
    /// A imagem não pôde ser convertida para a entrada do modelo.
    case invalidImage
    /// A requisição Vision/Core ML falhou.
    case inferenceFailed(String)
    /// A saída do modelo não pôde ser interpretada.
    case unexpectedOutput(String)
}
