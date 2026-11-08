import Observation
import PhotosUI
import SwiftUI

/// Estado e regras do fluxo de escolha de imagem: sheet de origem, câmera, Fototeca,
/// permissões, cancelamentos e erros.
///
/// As apresentações são mutuamente exclusivas e representadas por um único enum.
@MainActor
@Observable
final class ImageSelectionModel {
    enum Presentation: Equatable {
        case sourceSheet
        case camera
        case photoLibrary
    }

    enum Source: Equatable {
        case camera
        case photoLibrary
    }

    enum Alert: Identifiable, Equatable {
        case cameraPermissionDenied
        case cameraUnavailable
        case captureFailed
        case libraryLoadFailed

        var id: Self { self }
    }

    /// Resultado de uma seleção concluída.
    enum Outcome: Equatable {
        case image(SelectedImage)
        /// O usuário escolheu um arquivo que não pôde ser decodificado como imagem.
        case invalidImage
    }

    struct Completion: Identifiable, Equatable {
        let id = UUID()
        let outcome: Outcome
    }

    private(set) var presentation: Presentation?
    var alert: Alert?
    /// Título do sheet: "Analisar imagem" (Home) ou "Escolher outra imagem".
    private(set) var sheetTitle = "Analisar imagem"
    private(set) var isLoadingLibraryImage = false
    /// Última seleção concluída; observada pela navegação.
    private(set) var completion: Completion?
    /// Item escolhido no `PhotosPicker` (binding).
    var photoPickerItem: PhotosPickerItem?

    private var pendingSource: Source?
    private let camera: any CameraAccessProviding
    private let photoLoader: any PhotoLibraryLoading

    init(camera: any CameraAccessProviding, photoLoader: any PhotoLibraryLoading) {
        self.camera = camera
        self.photoLoader = photoLoader
    }

    // MARK: - Sheet de origem

    func begin(title: String = "Analisar imagem") {
        sheetTitle = title
        pendingSource = nil
        presentation = .sourceSheet
    }

    /// Escolha feita no sheet. A apresentação seguinte acontece depois que o sheet fecha.
    func choose(_ source: Source) {
        pendingSource = source
        presentation = nil
    }

    func cancelSourceSheet() {
        pendingSource = nil
        presentation = nil
    }

    /// Chamado pelo `onDismiss` do sheet.
    func sourceSheetDidDismiss() async {
        if presentation == .sourceSheet { presentation = nil }
        guard let source = pendingSource else { return }
        pendingSource = nil
        switch source {
        case .camera: await openCamera()
        case .photoLibrary: openPhotoLibrary()
        }
    }

    // MARK: - Câmera

    func openCamera() async {
        guard camera.isCameraAvailable else {
            alert = .cameraUnavailable
            return
        }
        switch camera.authorizationStatus() {
        case .authorized:
            presentation = .camera
        case .notDetermined:
            if await camera.requestAccess() {
                presentation = .camera
            } else {
                alert = .cameraPermissionDenied
            }
        case .denied, .restricted:
            alert = .cameraPermissionDenied
        }
    }

    func cameraDidCapture(_ image: UIImage?) {
        presentation = nil
        guard let image else {
            alert = .captureFailed
            return
        }
        complete(.image(SelectedImage(image: image, source: .camera)))
    }

    func cameraDidCancel() {
        presentation = nil
    }

    // MARK: - Fototeca

    func openPhotoLibrary() {
        photoPickerItem = nil
        presentation = .photoLibrary
    }

    /// Chamado quando o binding de apresentação do `PhotosPicker` muda.
    func photoLibraryPresentationChanged(isPresented: Bool) {
        if !isPresented, presentation == .photoLibrary { presentation = nil }
    }

    func loadPhotoLibraryItem(_ item: PhotosPickerItem) async {
        presentation = nil
        isLoadingLibraryImage = true
        defer {
            isLoadingLibraryImage = false
            photoPickerItem = nil
        }
        do {
            guard let data = try await photoLoader.loadImageData(from: item) else {
                alert = .libraryLoadFailed
                return
            }
            if let image = UIImage(data: data) {
                complete(.image(SelectedImage(image: image, source: .photoLibrary)))
            } else {
                complete(.invalidImage)
            }
        } catch {
            alert = .libraryLoadFailed
        }
    }

    // MARK: - Apresentações derivadas

    func isPresenting(_ target: Presentation) -> Bool {
        presentation == target
    }

    func dismiss(_ target: Presentation) {
        if presentation == target { presentation = nil }
    }

    private func complete(_ outcome: Outcome) {
        completion = Completion(outcome: outcome)
    }
}
