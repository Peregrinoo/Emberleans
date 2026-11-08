import PhotosUI
import SwiftUI

/// Carrega os dados de uma foto escolhida no seletor nativo.
///
/// O `PhotosPicker` roda fora do processo do app e não exige permissão de acesso à
/// Fototeca: o app recebe somente a imagem que o usuário escolheu.
protocol PhotoLibraryLoading {
    func loadImageData(from item: PhotosPickerItem) async throws -> Data?
}

struct SystemPhotoLibraryLoader: PhotoLibraryLoading {
    func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        try await item.loadTransferable(type: Data.self)
    }
}
