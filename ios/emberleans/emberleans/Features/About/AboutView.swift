import SwiftUI

/// Tela 04: informações sobre o EmberLens, o modelo e suas limitações.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identity
                    .padding(.top, 18)

                Text("Inteligência que funciona no dispositivo.")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 30)

                Text("O EmberLens explora o uso de redes neurais compactas para classificação visual de imagens, executando o processamento diretamente no iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.sm)

                section("Modelo de inteligência artificial") {
                    ForEach(AboutContent.modelFacts) { fact in
                        KeyValueRow(title: LocalizedStringKey(fact.title), value: fact.value)
                    }
                }

                section("Resultados experimentais") {
                    metrics.padding(.top, Spacing.md)
                    Text("Obtidos em um conjunto de teste limitado (\(AboutContent.testSetSize) imagens). Não representam desempenho clínico validado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                }

                section("Limitações") {
                    ForEach(AboutContent.limitations, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            Text("—").foregroundStyle(.tertiary).accessibilityHidden(true)
                            Text(item)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 10)
                    }
                }

                section("Inspiração") {
                    Text(AboutContent.inspiration)
                        .font(.subheadline)
                        .padding(.top, Spacing.sm)
                    Text(AboutContent.reference)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }

                footer
                    .padding(.top, 36)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, 46)
        }
        .navigationTitle("Sobre o EmberLens")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identity: some View {
        HStack(spacing: 14) {
            FocalMarkSymbol()
                .frame(height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("EmberLens")
                    .font(.title3.weight(.semibold))
                Text("Classificação experimental de imagens de pele")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.sm) { metricViews }
            VStack(alignment: .leading, spacing: Spacing.md) { metricViews }
        }
    }

    private var metricViews: some View {
        ForEach(AboutContent.testMetrics) { metric in
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.value)
                    .font(.title.bold())
                    .monospacedDigit()
                Text(metric.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Link(destination: AboutContent.repositoryURL) {
                HStack {
                    Text("Código-fonte no GitHub")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Emberleans")
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(Palette.emberText)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            Divider()
            KeyValueRow(title: "Versão", value: AboutContent.appVersion)
            Text(AboutContent.credits)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.md)
            Text("EmberLens é um projeto experimental de portfólio. Não é um dispositivo médico.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: title)
            content()
        }
        .padding(.top, 36)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
