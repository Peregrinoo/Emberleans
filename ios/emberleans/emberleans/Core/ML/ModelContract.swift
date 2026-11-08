import CoreML
import Foundation

/// Contrato entre o app e o `EmberLens.mlpackage` exportado por `ml/src/export_coreml.py`.
///
/// O modelo recebe uma imagem RGB 256 × 256 e incorpora o restante do pré-processamento
/// de avaliação do treino (recorte central 224 × 224 e normalização ImageNet). O app só
/// precisa entregar a imagem redimensionada pelo lado menor e recortada no centro, o que
/// o Vision faz com `VNImageCropAndScaleOption.centerCrop`.
nonisolated enum ModelContract {
    static let resourceName = "EmberLens"
    static let inputName = "image"
    static let inputSize = 256

    /// Valores lidos da descrição real do modelo, sem depender de Core ML para testar.
    struct Description: Equatable, Sendable {
        var classLabels: [String]
        /// JSON gravado em `user_defined_metadata["classes"]` durante a exportação, se houver.
        var metadataClassesJSON: String?
        var inputWidth: Int?
        var inputHeight: Int?
    }

    /// Valida que o modelo carregado é o que o app espera.
    static func validate(_ description: Description) throws {
        let labels = Set(description.classLabels)
        guard labels == LesionClass.expectedModelLabels, description.classLabels.count == labels.count else {
            throw ClassifierError.unexpectedModelClasses(found: description.classLabels)
        }

        if let json = description.metadataClassesJSON {
            guard let data = json.data(using: .utf8),
                  let metadataClasses = try? JSONDecoder().decode([String].self, from: data),
                  Set(metadataClasses) == labels else {
                throw ClassifierError.unexpectedModelClasses(found: description.classLabels)
            }
        }

        if let width = description.inputWidth, let height = description.inputHeight,
           width != inputSize || height != inputSize {
            throw ClassifierError.unexpectedModelInput("Entrada \(width)×\(height); esperado \(inputSize)×\(inputSize)")
        }
    }
}

nonisolated extension ModelContract.Description {
    /// Extrai a descrição de um `MLModelDescription` real.
    init(_ modelDescription: MLModelDescription) {
        let userDefined = modelDescription.metadata[.creatorDefinedKey] as? [String: String]
        let constraint = modelDescription.inputDescriptionsByName[ModelContract.inputName]?.imageConstraint
        self.init(
            classLabels: (modelDescription.classLabels as? [String]) ?? [],
            metadataClassesJSON: userDefined?["classes"],
            inputWidth: constraint?.pixelsWide,
            inputHeight: constraint?.pixelsHigh
        )
    }
}
