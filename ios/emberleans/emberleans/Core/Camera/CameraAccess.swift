import AVFoundation
import UIKit

/// Estado de autorização da câmera, independente do AVFoundation (facilita os testes).
enum CameraAuthorization: Equatable {
    case authorized
    case notDetermined
    case denied
    case restricted
}

/// Abstração do acesso à câmera do sistema.
protocol CameraAccessProviding {
    var isCameraAvailable: Bool { get }
    func authorizationStatus() -> CameraAuthorization
    func requestAccess() async -> Bool
}

/// Implementação real, baseada em `UIImagePickerController` e `AVCaptureDevice`.
struct SystemCameraAccess: CameraAccessProviding {
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func authorizationStatus() -> CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
