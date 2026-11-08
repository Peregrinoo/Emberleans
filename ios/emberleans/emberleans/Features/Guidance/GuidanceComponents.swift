import SwiftUI

/// Ligação para o SAMU 192. Em `prominent`, é um botão vermelho de largura total;
/// em `inline`, um link discreto.
struct EmergencyCallLink: View {
    enum Style { case prominent, inline }
    var style: Style = .prominent

    var body: some View {
        switch style {
        case .prominent:
            Link(destination: GuidanceContentInfo.emergencyCallURL) {
                Label("Ligar para o SAMU 192", systemImage: "phone.fill")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                    .padding(.horizontal, Spacing.md)
                    .foregroundStyle(.white)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .accessibilityHint("Abre o discador do telefone")
        case .inline:
            Link(destination: GuidanceContentInfo.emergencyCallURL) {
                Label("Em uma emergência, ligue 192 (SAMU)", systemImage: "phone")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
            }
            .accessibilityHint("Abre o discador do telefone")
        }
    }
}

/// Faixa de urgência no topo da orientação.
struct UrgencyBanner: View {
    let urgency: UrgencyLevel

    var body: some View {
        if let content {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: content.icon)
                    .foregroundStyle(content.tint)
                    .accessibilityHidden(true)
                Text(content.text)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, 14)
            .background(content.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.notice, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var content: (text: String, icon: String, tint: Color)? {
        switch urgency {
        case .callEmergency:
            ("Situação de emergência: peça ajuda agora.", "exclamationmark.triangle.fill", Color.red)
        case .urgentCare:
            ("Procure atendimento médico imediatamente.", "exclamationmark.triangle.fill", Color.red)
        case .professionalEvaluation:
            ("Recomenda-se avaliação de um profissional de saúde.", "stethoscope", Palette.emberText)
        case .observe:
            nil
        }
    }
}

/// Passo numerado: número grande, ícone, título curto e descrição.
/// Em tamanhos de acessibilidade, o número fica acima do texto.
struct GuidanceStepRow: View {
    let index: Int
    let step: GuidanceStep
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.md))

        layout {
            Text(String(format: "%02d", index))
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Palette.emberText)
                .frame(minWidth: 44, alignment: .leading)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(step.title).font(.headline)
                    Image(systemName: step.systemImage)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Passo \(index): \(step.title). \(step.detail)")
    }
}

/// Lista com marcadores discretos.
struct GuidanceBulletList: View {
    let items: [GuidanceItem]
    var systemImage = "minus"
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(minWidth: 16)
                        .accessibilityHidden(true)
                    Text(item.text)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Área secundária com as fontes das orientações exibidas (folha modal).
struct GuidanceSourcesSheet: View {
    let sources: [GuidanceSource]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sources) { source in
                        sourceRow(source)
                    }
                } footer: {
                    Text("As orientações partem das suas respostas e destas fontes. Conteúdo revisado em \(GuidanceContentInfo.reviewedOn).")
                }
            }
            .navigationTitle("Fontes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                        .tint(Palette.emberText)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func sourceRow(_ source: GuidanceSource) -> some View {
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(source.organization).font(.subheadline.weight(.semibold))
            Text(source.title).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let url = source.url {
            Link(destination: url) {
                HStack(alignment: .firstTextBaseline) {
                    text.foregroundStyle(.primary)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.emberText)
                        .accessibilityHidden(true)
                }
            }
        } else {
            text
        }
    }
}
