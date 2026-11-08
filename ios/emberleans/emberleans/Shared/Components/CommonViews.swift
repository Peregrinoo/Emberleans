import SwiftUI

/// Fotografia em quadro neutro, com a proporção original preservada (aspect fit, sem corte).
struct PhotoFrame: View {
    let image: UIImage
    var height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.photo, style: .continuous)
                .fill(Color(.quaternarySystemFill))
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Imagem selecionada")
        .accessibilityAddTraits(.isImage)
    }
}

/// Aviso informativo discreto (ícone info.circle + Footnote secundário).
struct NoticeView: View {
    let text: LocalizedStringKey
    var systemImage = "info.circle"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, 14)
        .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: Radius.notice, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Cabeçalho de seção em caixa alta, seguido de divisória.
struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .sectionLabelStyle()
                .accessibilityAddTraits(.isHeader)
            Divider()
        }
    }
}

/// Linha chave-valor com divisória. Em tamanhos de acessibilidade, empilha os textos.
struct KeyValueRow: View {
    let title: LocalizedStringKey
    let value: String
    var font: Font = .subheadline

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    titleText
                    Spacer(minLength: Spacing.md)
                    valueText.multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    valueText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            Divider()
        }
        .font(font)
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(title).foregroundStyle(.secondary)
    }

    private var valueText: some View {
        Text(value).monospacedDigit()
    }
}

/// Estado vazio / indisponível na área da foto.
struct UnavailableImageView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var height: CGFloat = Metrics.previewPhotoHeight

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
