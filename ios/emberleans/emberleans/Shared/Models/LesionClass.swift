import Foundation

/// As cinco categorias reconhecidas pelo modelo.
///
/// A ordem de declaração é a ordem de exibição definida no design
/// (Queimadura, Abrasão, Hematoma, Laceração, Pele normal). Ela não depende
/// da ordem das saídas do modelo: o mapeamento é feito pelo rótulo textual.
nonisolated enum LesionClass: String, CaseIterable, Identifiable, Hashable, Sendable {
    case burn = "Burn"
    case abrasion = "Abrasion"
    case bruise = "Bruise"
    case laceration = "Laceration"
    case normalSkin = "Normal Skin"

    var id: String { rawValue }

    /// Rótulo exato produzido pelo modelo Core ML (`classLabel`).
    var modelLabel: String { rawValue }

    /// Nome exibido na interface (pt-BR).
    var displayName: String {
        switch self {
        case .burn: "Queimadura"
        case .abrasion: "Abrasão"
        case .bruise: "Hematoma"
        case .laceration: "Laceração"
        case .normalSkin: "Pele normal"
        }
    }

    init?(modelLabel: String) {
        self.init(rawValue: modelLabel)
    }

    /// Conjunto de rótulos que o modelo precisa declarar.
    static var expectedModelLabels: Set<String> {
        Set(allCases.map(\.modelLabel))
    }
}
