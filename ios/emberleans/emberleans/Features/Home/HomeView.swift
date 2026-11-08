import SwiftUI

/// Tela 01: apresentação e início da análise.
struct HomeView: View {
    let onAnalyze: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HeroOpticsGraphic()
                    .frame(height: 300)

                Text("Observe além da imagem.")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xs)
                    .padding(.horizontal, Spacing.screenMargin)

                Text("Explore a classificação visual de imagens de pele com inteligência artificial executada diretamente no seu iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.sm)
                    .padding(.horizontal, Spacing.screenMargin)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.lg) {
                Button("Analisar imagem", action: onAnalyze)
                    .buttonStyle(.emberPrimary)

                LocalProcessingFooter()
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .background(.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BrandMark()
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.about) {
                    Image(systemName: "info.circle")
                }
                .tint(.secondary)
                .accessibilityLabel("Sobre o EmberLens")
            }
        }
    }
}

/// Rodapé "Processamento local". O app não realiza nenhuma chamada de rede: a afirmação
/// abaixo só pode continuar aqui enquanto isso for verdade.
private struct LocalProcessingFooter: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "iphone")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Processamento local")
                    .fontWeight(.semibold)
                Text("Suas imagens não são enviadas para servidores.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeView(onAnalyze: {})
    }
}
