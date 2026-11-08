import SwiftUI

/// Botão primário: preenchimento Ember, Headline, 52 pt de altura, raio contínuo de 14 pt.
struct EmberPrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            if isLoading {
                ProgressView()
                    .tint(.secondary)
            }
            configuration.label
        }
        .font(.headline)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
        .padding(.horizontal, Spacing.md)
        .foregroundStyle(isEnabled ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
        .background(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .fill(isEnabled ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.quaternarySystemFill)))
        )
        .brightness(configuration.isPressed ? -0.08 : 0)
        .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

/// Ação secundária sem preenchimento ("Escolher outra imagem").
struct EmberPlainButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Palette.emberText)
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.35)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == EmberPrimaryButtonStyle {
    static var emberPrimary: EmberPrimaryButtonStyle { EmberPrimaryButtonStyle() }
    static func emberPrimary(isLoading: Bool) -> EmberPrimaryButtonStyle { EmberPrimaryButtonStyle(isLoading: isLoading) }
}

extension ButtonStyle where Self == EmberPlainButtonStyle {
    static var emberPlain: EmberPlainButtonStyle { EmberPlainButtonStyle() }
}
