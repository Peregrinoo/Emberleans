import SwiftUI

/// Sheet de escolha da origem da imagem: câmera e Fototeca, com o mesmo peso visual.
struct ImageSourceSheet: View {
    let title: String
    let onSelect: (ImageSelectionModel.Source) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Escolha a origem da imagem")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, Spacing.lg)

            VStack(spacing: 0) {
                SourceRow(
                    systemImage: "camera",
                    title: "Tirar foto",
                    subtitle: "Use a câmera do iPhone"
                ) { onSelect(.camera) }

                Divider().padding(.leading, 58)

                SourceRow(
                    systemImage: "photo.on.rectangle",
                    title: "Escolher da Fototeca",
                    subtitle: "Selecione uma foto existente"
                ) { onSelect(.photoLibrary) }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: onCancel) {
                Text("Cancelar")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Palette.emberText)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct SourceRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Palette.emberText)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ImageSourceSheet(title: "Analisar imagem", onSelect: { _ in }, onCancel: {})
            .presentationDetents([.height(320)])
    }
}
