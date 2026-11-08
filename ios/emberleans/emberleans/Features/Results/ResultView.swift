import SwiftUI

/// Tela 03: resultado.
///
/// Durante o questionário, a tela mostra uma pergunta por vez. Concluído o questionário,
/// a hierarquia é: [alerta de emergência, se houver] → fotografia → classificação →
/// pontuações → o que fazer agora → o que evitar → quando procurar atendimento → nova análise.
///
/// As orientações vêm de `GuidanceViewModel` (respostas do usuário) e não dependem
/// da classificação. Fontes ficam em uma folha secundária; detalhes técnicos, na tela Sobre.
struct ResultView: View {
    let analysis: AnalysisViewModel
    let guidance: GuidanceViewModel
    let onAnalyzeAnother: () -> Void

    var body: some View {
        content
            .navigationTitle("Resultado")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch analysis.state {
        case .success(let image, let result):
            ResultExperienceView(
                image: image,
                finding: .result(result),
                guidance: guidance,
                onRetryAnalysis: {},
                onAnalyzeAnother: onAnalyzeAnother
            )
        case .failure(let failure):
            if let image = failure.image {
                ResultExperienceView(
                    image: image,
                    finding: .failure(failure.error),
                    guidance: guidance,
                    onRetryAnalysis: { Task { await analysis.analyze() } },
                    onAnalyzeAnother: onAnalyzeAnother
                )
            } else {
                Color.clear
            }
        case .processing(let image):
            ResultExperienceView(
                image: image,
                finding: .processing,
                guidance: guidance,
                onRetryAnalysis: {},
                onAnalyzeAnother: onAnalyzeAnother
            )
        case .idle, .imageSelected:
            // Estados transitórios: a navegação só chega aqui após uma análise.
            Color.clear
        }
    }
}

/// Situação da análise da imagem.
enum VisualFinding: Equatable {
    case result(ClassificationResult)
    case failure(AnalysisError)
    case processing
}

private struct ResultExperienceView: View {
    let image: SelectedImage
    let finding: VisualFinding
    let guidance: GuidanceViewModel
    let onRetryAnalysis: () -> Void
    let onAnalyzeAnother: () -> Void

    @State private var showsSources = false
    private let topID = "top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id(topID)

                    switch guidance.state {
                    case .notStarted:
                        QuestionnaireIntroView(onStart: { withAnimation(.snappy) { guidance.start() } })
                            .padding(.top, Spacing.xs)
                    case .inProgress(let question):
                        QuestionCardView(question: question, guidance: guidance)
                            .padding(.top, Spacing.xs)
                            .id(question)
                            .transition(.opacity)
                    case .guidanceAvailable(let result), .insufficientInformation(let result), .alert(let result):
                        completedResult(result)
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.xl)
            }
            .onChange(of: guidance.state) { _, _ in
                proxy.scrollTo(topID, anchor: .top)
            }
        }
        .toolbar {
            if guidance.state.guidance != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { guidance.reviewAnswers() }
                    } label: {
                        Label("Revisar respostas", systemImage: "arrow.uturn.backward")
                    }
                    .tint(Palette.emberText)
                }
            }
        }
        .sheet(isPresented: $showsSources) {
            GuidanceSourcesSheet(sources: guidance.state.guidance?.sources ?? [])
        }
        .sensoryFeedback(trigger: guidance.state) { _, newState in
            if case .alert = newState { return .warning }
            return nil
        }
    }

    @ViewBuilder
    private func completedResult(_ result: Guidance) -> some View {
        if result.kind == .emergency {
            EmergencyAlertBlock(guidance: result)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)
        }

        ResultPhoto(image: image.image)
            .padding(.top, result.kind == .emergency ? 0 : Spacing.xs)

        ImageAnalysisSection(finding: finding, onRetry: onRetryAnalysis)
            .padding(.top, Spacing.xl)

        WhatToDoSection(guidance: result)
            .padding(.top, 40)

        if !result.avoid.isEmpty {
            WhatToAvoidSection(items: result.avoid)
                .padding(.top, 36)
        }

        SeekCareSection(guidance: result)
            .padding(.top, 36)

        Button("Analisar outra imagem", action: onAnalyzeAnother)
            .buttonStyle(.emberPrimary)
            .padding(.top, 40)

        footer
            .padding(.top, Spacing.lg)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("A análise da imagem não substitui uma avaliação profissional.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Fontes das orientações") { showsSources = true }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.emberText)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Emergência

/// Alerta de emergência: sempre antes dos demais conteúdos, com a ação de pedir ajuda visível.
private struct EmergencyAlertBlock: View {
    let guidance: Guidance

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label {
                Text(guidance.headline)
                    .font(.title3.bold())
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityAddTraits(.isHeader)

            if !guidance.emergencyReasons.isEmpty {
                Text(guidance.emergencyReasons.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            EmergencyCallLink()
                .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.photo, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Fotografia

/// Fotografia protagonista: largura total, proporção original, cantos discretos, sem moldura.
private struct ResultPhoto: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: Radius.notice, style: .continuous))
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Fotografia analisada")
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Análise da imagem

private struct ImageAnalysisSection: View {
    let finding: VisualFinding
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xs) {
                Text("Análise da imagem")
                    .sectionLabelStyle()
                if case .result(let result) = finding, result.source == .simulated {
                    Text("Simulado")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.quaternarySystemFill), in: Capsule())
                        .accessibilityLabel("Resultado simulado, não vem do modelo real")
                }
            }

            switch finding {
            case .result(let result):
                VStack(alignment: .leading, spacing: 0) {
                    Text(result.topClass.displayName)
                        .font(.largeTitle.bold())
                        .padding(.top, Spacing.xxs)
                    Text(ResultFormatting.percent(result.topProbability))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.emberText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Classificação visual: \(result.topClass.displayName), pontuação \(ResultFormatting.percent(result.topProbability))")

                VStack(spacing: 14) {
                    ForEach(result.scores) { score in
                        DistributionRow(score: score, isTop: score.lesionClass == result.topClass)
                    }
                }
                .padding(.top, Spacing.lg)

            case .failure(let error):
                Text("Análise indisponível")
                    .font(.title2.bold())
                    .padding(.top, Spacing.xxs)
                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xxs)
                if error.isRetryable {
                    Button(action: onRetry) {
                        Label("Tentar novamente", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.emberText)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                }

            case .processing:
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                    Text("Analisando no dispositivo…").font(.headline)
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Orientações

private struct WhatToDoSection: View {
    let guidance: Guidance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("O que fazer agora")

            if guidance.steps.isEmpty {
                Text("Sem saber como a lesão aconteceu, não há cuidados específicos. Toque em Revisar respostas se puder informar a causa.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xs)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(guidance.steps.enumerated()), id: \.element.id) { index, step in
                        GuidanceStepRow(index: index + 1, step: step)
                        if index < guidance.steps.count - 1 { Divider() }
                    }
                }
                .padding(.top, Spacing.xxs)
            }
        }
    }
}

private struct WhatToAvoidSection: View {
    let items: [GuidanceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("O que evitar")
            GuidanceBulletList(items: items, systemImage: "xmark", tint: .secondary)
        }
    }
}

private struct SeekCareSection: View {
    let guidance: Guidance

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("Quando procurar atendimento")

            // Avisos de contexto e urgência (fora da emergência, que já tem o alerta no topo).
            if guidance.kind != .emergency {
                UrgencyBanner(urgency: guidance.urgency)
                if !guidance.notices.isEmpty {
                    GuidanceBulletList(items: guidance.notices, systemImage: "info.circle", tint: Palette.emberText)
                }
            }

            GuidanceBulletList(items: guidance.seekCare, systemImage: "exclamationmark.circle", tint: Palette.emberText)

            if guidance.kind == .emergency {
                EmergencyCallLink(style: .inline)
                    .padding(.top, Spacing.xxs)
            } else {
                EmergencyCallLink()
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

/// Título de seção (Title 3 Bold), consistente em toda a tela.
private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Pontuações

/// Linha de pontuação: rótulo, valor alinhado à direita e barra horizontal.
/// A classe principal se destaca pela cor Ember e pelo peso semibold (não apenas pela cor).
struct DistributionRow: View {
    let score: ClassScore
    let isTop: Bool

    var body: some View {
        let percent = ResultFormatting.percent(score.probability)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(score.lesionClass.displayName)
                    .foregroundStyle(isTop ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                Spacer(minLength: Spacing.sm)
                Text(percent)
                    .monospacedDigit()
                    .foregroundStyle(isTop ? AnyShapeStyle(Palette.emberText) : AnyShapeStyle(.secondary))
            }
            .font(.subheadline.weight(isTop ? .semibold : .regular))

            ScoreBar(value: score.probability, isHighlighted: isTop)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.lesionClass.displayName)
        .accessibilityValue(isTop ? "\(percent), maior pontuação do classificador" : percent)
    }
}

private struct ScoreBar: View {
    let value: Double
    let isHighlighted: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.quaternarySystemFill))
                Capsule()
                    .fill(isHighlighted ? Palette.emberText : Color(.systemGray3))
                    .frame(width: max(proxy.size.width * min(max(value, 0), 1), value > 0 ? Metrics.barHeight : 0))
            }
        }
        .frame(height: Metrics.barHeight)
    }
}
