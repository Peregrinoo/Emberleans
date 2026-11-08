import CoreML
import Foundation
import Vision

/// Classificador real: MobileNetV3 Small convertida para Core ML, executada localmente.
///
/// - O modelo é carregado sob demanda, na primeira classificação, fora da thread principal.
/// - Ao carregar, a descrição real do modelo é validada (`ModelContract`).
/// - Todo o trabalho acontece numa fila serial própria, que também protege o cache do modelo.
nonisolated final class CoreMLImageClassifier: ImageClassifying, @unchecked Sendable {
    private let modelURL: URL
    private let configuration: MLModelConfiguration
    private let queue = DispatchQueue(label: "xyz.chaaves.emberlens.inference", qos: .userInitiated)
    /// Acessado somente dentro de `queue`.
    private var cachedModel: VNCoreMLModel?

    init(modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) {
        self.modelURL = modelURL
        self.configuration = configuration
    }

    /// URL do modelo compilado (`EmberLens.mlmodelc`) dentro do bundle, se existir.
    static func bundledModelURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: ModelContract.resourceName, withExtension: "mlmodelc")
    }

    func classify(_ input: ClassifierInput) async throws -> ClassificationResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try self.performClassification(input) })
            }
        }
    }

    // MARK: - Execução (sempre em `queue`)

    private func performClassification(_ input: ClassifierInput) throws -> ClassificationResult {
        let model = try loadModelIfNeeded()

        let request = VNCoreMLRequest(model: model)
        // Redimensiona pelo lado menor e recorta o centro, como Resize(256) + CenterCrop no treino.
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: input.cgImage, orientation: input.orientation, options: [:])

        let clock = ContinuousClock()
        let start = clock.now
        do {
            try handler.perform([request])
        } catch {
            throw ClassifierError.inferenceFailed(error.localizedDescription)
        }
        let duration = clock.now - start

        guard let observations = request.results as? [VNClassificationObservation], !observations.isEmpty else {
            throw ClassifierError.unexpectedOutput("O modelo não retornou observações de classificação")
        }

        var scores: [String: Double] = [:]
        for observation in observations {
            scores[observation.identifier] = Double(observation.confidence)
        }
        return try ClassificationMapper.makeResult(from: scores, inferenceDuration: duration, source: .coreML)
    }

    private func loadModelIfNeeded() throws -> VNCoreMLModel {
        if let cachedModel { return cachedModel }

        let mlModel: MLModel
        do {
            mlModel = try MLModel(contentsOf: modelURL, configuration: configuration)
        } catch {
            throw ClassifierError.modelLoadFailed(error.localizedDescription)
        }

        try ModelContract.validate(ModelContract.Description(mlModel.modelDescription))

        let visionModel: VNCoreMLModel
        do {
            visionModel = try VNCoreMLModel(for: mlModel)
        } catch {
            throw ClassifierError.modelLoadFailed(error.localizedDescription)
        }
        cachedModel = visionModel
        return visionModel
    }
}
