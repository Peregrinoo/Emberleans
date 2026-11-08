import Foundation
import PhotosUI
import SwiftUI
import UIKit
@testable import emberleans

// MARK: - Classificadores

/// Classificador que retorna (ou lança) um valor fixo e conta as chamadas.
nonisolated final class StubClassifier: ImageClassifying, @unchecked Sendable {
    private let lock = NSLock()
    private let outcome: Result<ClassificationResult, ClassifierError>
    private var _callCount = 0

    init(_ outcome: Result<ClassificationResult, ClassifierError>) {
        self.outcome = outcome
    }

    var callCount: Int { lock.withLock { _callCount } }

    func classify(_ input: ClassifierInput) async throws -> ClassificationResult {
        lock.withLock { _callCount += 1 }
        return try outcome.get()
    }
}

/// Classificador que fica suspenso até o teste liberar o resultado; permite observar o
/// estado `processing` e simular respostas fora de ordem.
nonisolated final class SuspendingClassifier: ImageClassifying, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<ClassificationResult, Error>] = []
    private var _callCount = 0

    var callCount: Int { lock.withLock { _callCount } }
    var pendingCount: Int { lock.withLock { continuations.count } }

    func classify(_ input: ClassifierInput) async throws -> ClassificationResult {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                _callCount += 1
                continuations.append(continuation)
            }
        }
    }

    func resumeNext(with result: Result<ClassificationResult, Error>) {
        let continuation = lock.withLock { continuations.isEmpty ? nil : continuations.removeFirst() }
        continuation?.resume(with: result)
    }

    /// Cede a execução até que haja `count` chamadas pendentes (ou o limite seja atingido).
    func waitForPendingCalls(_ count: Int = 1) async {
        for _ in 0..<1_000 where pendingCount < count {
            await Task.yield()
        }
    }
}

// MARK: - Câmera e Fototeca

@MainActor
final class StubCamera: CameraAccessProviding {
    var isCameraAvailable: Bool
    var status: CameraAuthorization
    var grantOnRequest: Bool
    private(set) var requestCount = 0

    init(available: Bool = true, status: CameraAuthorization = .authorized, grantOnRequest: Bool = true) {
        self.isCameraAvailable = available
        self.status = status
        self.grantOnRequest = grantOnRequest
    }

    func authorizationStatus() -> CameraAuthorization { status }

    func requestAccess() async -> Bool {
        requestCount += 1
        return grantOnRequest
    }
}

@MainActor
final class StubPhotoLoader: PhotoLibraryLoading {
    enum Behavior {
        case data(Data?)
        case failure
    }

    var behavior: Behavior

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    struct LoadError: Error {}

    func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        switch behavior {
        case .data(let data): return data
        case .failure: throw LoadError()
        }
    }
}

// MARK: - Fixtures

enum Fixtures {
    @MainActor
    static func image(color: UIColor = .orange, size: CGSize = CGSize(width: 8, height: 8)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    @MainActor
    static func selectedImage(source: SelectedImage.Source = .photoLibrary) -> SelectedImage {
        SelectedImage(image: image(), source: source)
    }

    static let exportedLabels = ["Abrasion", "Bruise", "Burn", "Laceration", "Normal Skin"]

    static let burnScores: [String: Double] = [
        "Abrasion": 0.14, "Bruise": 0.03, "Burn": 0.72, "Laceration": 0.09, "Normal Skin": 0.02,
    ]

    static func result(
        scores: [String: Double] = burnScores,
        source: ClassificationResult.Source = .coreML
    ) -> ClassificationResult {
        // Valores válidos por construção; falhar aqui indica erro no próprio fixture.
        try! ClassificationMapper.makeResult(from: scores, inferenceDuration: .milliseconds(18), source: source)
    }
}
