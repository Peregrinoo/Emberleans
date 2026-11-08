import CoreGraphics
import ImageIO

/// Entrada do classificador: a imagem e sua orientação EXIF.
///
/// A orientação é repassada ao Vision em vez de rotacionar os pixels, preservando a
/// imagem original.
nonisolated struct ClassifierInput: @unchecked Sendable {
    let cgImage: CGImage
    let orientation: CGImagePropertyOrientation
}

/// Abstração do serviço de classificação. As Views e os ViewModels dependem apenas
/// deste protocolo; a implementação Core ML pode ser substituída por dublês nos testes.
nonisolated protocol ImageClassifying: Sendable {
    func classify(_ input: ClassifierInput) async throws -> ClassificationResult
}
