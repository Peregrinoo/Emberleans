import SwiftUI

/// Tela 02: prévia da imagem e início da análise.
struct PreviewView: View {
    let analysis: AnalysisViewModel
    let onAnalyze: () -> Void
    let onChooseAnother: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Imagem selecionada")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, 14)

                if let image = analysis.state.image {
                    PhotoFrame(image: image.image, height: Metrics.previewPhotoHeight)
                    status
                        .padding(.top, Spacing.lg)
                } else {
                    UnavailableImageView(
                        title: "Não foi possível carregar a imagem",
                        message: "O arquivo pode estar corrompido ou em um formato incompatível."
                    )
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            actions
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.xs)
                .background(.background)
        }
        .navigationTitle("Nova análise")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: analysis.state.isProcessing) { _, isProcessing in
            if isProcessing {
                AccessibilityNotification.Announcement("Analisando no dispositivo").post()
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if analysis.state.isProcessing {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                    Text("Analisando no dispositivo…")
                        .font(.headline)
                }
                Text("Isso costuma levar menos de um segundo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Pronto para analisar")
                    .font(.headline)
                Text("A imagem será processada diretamente neste dispositivo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if analysis.state.image != nil {
            VStack(spacing: 6) {
                Button("Analisar imagem", action: onAnalyze)
                .buttonStyle(.emberPrimary(isLoading: analysis.state.isProcessing))
                .disabled(!analysis.canAnalyze)

                Button("Escolher outra imagem", action: onChooseAnother)
                    .buttonStyle(.emberPlain)
                    .disabled(analysis.state.isProcessing)
            }
        } else {
            Button("Escolher outra imagem", action: onChooseAnother)
                .buttonStyle(.emberPrimary)
        }
    }
}
