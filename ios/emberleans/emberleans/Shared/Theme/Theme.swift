import SwiftUI

/// Cores da marca (Assets.xcassets). A interface usa as cores semânticas do sistema para
/// fundos e textos; a cor de destaque é o `AccentColor` (Ember 600, #C4532C).
enum Palette {
    /// Ember para textos, tint e barras: #C4532C (claro) e #EC8157 (escuro).
    static let emberText = Color("EmberText")
    /// Lente da marca: Ink #151312 (claro) e Paper #F5F2EE (escuro).
    static let brandInk = Color("BrandInk")
    /// Preenchimento da lente no gráfico da Home.
    static let lensFill = Color("LensFill")
    /// Linhas de raio do gráfico da Home.
    static let rayLine = Color("RayLine")
}

/// Escala de espaçamento (múltiplos de 4 pt), definida em `design/documentation/design-system.md`.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Margem lateral das telas.
    static let screenMargin: CGFloat = 20
}

enum Radius {
    static let photo: CGFloat = 16
    static let button: CGFloat = 14
    static let notice: CGFloat = 12
    static let bar: CGFloat = 3
}

enum Metrics {
    static let buttonHeight: CGFloat = 52
    static let barHeight: CGFloat = 6
    static let previewPhotoHeight: CGFloat = 440
    static let resultPhotoHeight: CGFloat = 300
}

extension View {
    /// Rótulo em caixa alta (Caption 2 Medium, tracking +6%), usado em cabeçalhos de seção.
    func sectionLabelStyle() -> some View {
        font(.caption2.weight(.medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}
