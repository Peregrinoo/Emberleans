import Foundation
import os

/// Composição das dependências concretas do app (injeção por inicializador).
struct AppDependencies {
    let classifier: any ImageClassifying
    let camera: any CameraAccessProviding
    let photoLoader: any PhotoLibraryLoading

    private static let logger = Logger(subsystem: "xyz.chaaves.emberlens", category: "App")

    /// Dependências reais. Se o modelo não estiver no bundle, builds DEBUG usam o
    /// classificador simulado (identificado na interface); builds de release falham de
    /// forma explícita em cada análise.
    static func live(bundle: Bundle = .main) -> AppDependencies {
        let classifier: any ImageClassifying
        if let url = CoreMLImageClassifier.bundledModelURL(in: bundle) {
            classifier = CoreMLImageClassifier(modelURL: url)
        } else {
            logger.error("EmberLens.mlmodelc não encontrado no bundle.")
            #if DEBUG
            classifier = MockImageClassifier()
            #else
            classifier = UnavailableImageClassifier(error: .modelNotFound)
            #endif
        }
        return AppDependencies(
            classifier: classifier,
            camera: SystemCameraAccess(),
            photoLoader: SystemPhotoLibraryLoader()
        )
    }

    /// Dependências para SwiftUI Previews (classificador simulado).
    static var preview: AppDependencies {
        AppDependencies(
            classifier: MockImageClassifier(),
            camera: SystemCameraAccess(),
            photoLoader: SystemPhotoLibraryLoader()
        )
    }
}
