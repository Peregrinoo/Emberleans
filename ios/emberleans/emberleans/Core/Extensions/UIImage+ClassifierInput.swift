import ImageIO
import UIKit

extension ClassifierInput {
    /// Prepara a entrada do classificador a partir de uma `UIImage`.
    ///
    /// Usa o `CGImage` original com a orientação EXIF. Se a imagem não tiver `CGImage`
    /// (por exemplo, quando vem de um `CIImage`), ela é renderizada uma vez já orientada.
    init?(image: UIImage) {
        if let cgImage = image.cgImage {
            self.init(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
            return
        }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let rendered = UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = rendered.cgImage else { return nil }
        self.init(cgImage: cgImage, orientation: .up)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
