import UIKit

/// Imagem escolhida pelo usuário para análise.
///
/// A identidade é dada por `id`: duas seleções da mesma foto são análises diferentes.
nonisolated struct SelectedImage: Identifiable, Equatable {
    enum Source: Equatable, Sendable {
        case camera
        case photoLibrary
    }

    let id: UUID
    let image: UIImage
    let source: Source

    init(id: UUID = UUID(), image: UIImage, source: Source) {
        self.id = id
        self.image = image
        self.source = source
    }

    static func == (lhs: SelectedImage, rhs: SelectedImage) -> Bool {
        lhs.id == rhs.id
    }
}
