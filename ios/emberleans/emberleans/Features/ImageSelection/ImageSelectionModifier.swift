import PhotosUI
import SwiftUI

/// Conecta o `ImageSelectionModel` às apresentações nativas: sheet de origem, câmera,
/// `PhotosPicker` e alertas. Aplicado uma vez, na raiz da navegação.
struct ImageSelectionPresenter: ViewModifier {
    @Bindable var model: ImageSelectionModel
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: binding(for: .sourceSheet), onDismiss: {
                Task { await model.sourceSheetDidDismiss() }
            }) {
                ImageSourceSheet(
                    title: model.sheetTitle,
                    onSelect: { model.choose($0) },
                    onCancel: { model.cancelSourceSheet() }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: binding(for: .camera)) {
                CameraPicker(
                    onCapture: { model.cameraDidCapture($0) },
                    onCancel: { model.cameraDidCancel() }
                )
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: Binding(
                    get: { model.isPresenting(.photoLibrary) },
                    set: { model.photoLibraryPresentationChanged(isPresented: $0) }
                ),
                selection: $model.photoPickerItem,
                matching: .images,
                preferredItemEncoding: .automatic
            )
            .onChange(of: model.photoPickerItem) { _, item in
                guard let item else { return }
                Task { await model.loadPhotoLibraryItem(item) }
            }
            .alert(
                alertTitle,
                isPresented: Binding(
                    get: { model.alert != nil },
                    set: { if !$0 { model.alert = nil } }
                ),
                presenting: model.alert
            ) { alert in
                alertActions(for: alert)
            } message: { alert in
                Text(alertMessage(for: alert))
            }
    }

    private func binding(for presentation: ImageSelectionModel.Presentation) -> Binding<Bool> {
        Binding(
            get: { model.isPresenting(presentation) },
            set: { if !$0 { model.dismiss(presentation) } }
        )
    }

    private var alertTitle: String {
        switch model.alert {
        case .cameraPermissionDenied: "Acesso à câmera desativado"
        case .cameraUnavailable: "Câmera indisponível"
        case .captureFailed: "Não foi possível capturar a foto"
        case .libraryLoadFailed: "Não foi possível carregar a imagem"
        case nil: ""
        }
    }

    private func alertMessage(for alert: ImageSelectionModel.Alert) -> String {
        switch alert {
        case .cameraPermissionDenied:
            "Para tirar fotos, permita o acesso à câmera nos Ajustes. Você também pode escolher uma imagem da Fototeca."
        case .cameraUnavailable:
            "Não há uma câmera disponível neste dispositivo no momento. Escolha uma imagem da Fototeca."
        case .captureFailed:
            "O sistema não entregou a foto capturada. Tente novamente."
        case .libraryLoadFailed:
            "A foto selecionada não pôde ser lida. Ela pode estar no iCloud sem conexão ou em um formato incompatível."
        }
    }

    @ViewBuilder
    private func alertActions(for alert: ImageSelectionModel.Alert) -> some View {
        switch alert {
        case .cameraPermissionDenied:
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .keyboardShortcut(.defaultAction)
            Button("Escolher da Fototeca") { model.openPhotoLibrary() }
            Button("Cancelar", role: .cancel) {}
        case .cameraUnavailable:
            Button("Escolher da Fototeca") { model.openPhotoLibrary() }
                .keyboardShortcut(.defaultAction)
            Button("OK", role: .cancel) {}
        case .captureFailed:
            Button("Tentar novamente") { Task { await model.openCamera() } }
                .keyboardShortcut(.defaultAction)
            Button("Cancelar", role: .cancel) {}
        case .libraryLoadFailed:
            Button("Escolher outra imagem") { model.openPhotoLibrary() }
                .keyboardShortcut(.defaultAction)
            Button("OK", role: .cancel) {}
        }
    }
}

extension View {
    func imageSelection(_ model: ImageSelectionModel) -> some View {
        modifier(ImageSelectionPresenter(model: model))
    }
}
