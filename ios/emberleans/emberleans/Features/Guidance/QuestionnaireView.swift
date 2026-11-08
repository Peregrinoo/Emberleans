import SwiftUI

/// Apresentação inicial do questionário (estado "não iniciado").
struct QuestionnaireIntroView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Orientação inicial")
                .sectionLabelStyle()

            Text("Antes das orientações, conte como a lesão aconteceu")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.xs)

            Text("São 4 perguntas rápidas. As orientações partem das suas respostas e de regras conservadoras de primeiros socorros, não da fotografia.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.xs)

            Button("Começar", action: onStart)
                .buttonStyle(.emberPrimary)
                .padding(.top, Spacing.lg)

            EmergencyCallLink(style: .inline)
                .padding(.top, Spacing.md)
        }
    }
}

/// Uma pergunta por vez, com seleção rápida: tocar em uma opção já responde e avança.
struct QuestionCardView: View {
    let question: Question
    let guidance: GuidanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progress

            Text(question.title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.md)

            if question == .warningSigns {
                Text("Se houver mais de um, escolha qualquer um deles: um único sinal já basta para indicar atendimento.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xs)
            }

            options
                .padding(.top, Spacing.md)

            if guidance.canGoBack {
                Button {
                    withAnimation(.snappy) { guidance.goBack() }
                } label: {
                    Label("Voltar", systemImage: "chevron.left")
                }
                .buttonStyle(.emberPlain)
                .padding(.top, Spacing.sm)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Pergunta \(question.number) de \(Question.allCases.count)")
                .sectionLabelStyle()
            ProgressView(value: Double(question.number), total: Double(Question.allCases.count))
                .tint(.accentColor)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var options: some View {
        VStack(spacing: Spacing.xs) {
            switch question {
            case .cause:
                ForEach(InjuryCause.allCases) { cause in
                    option(cause.title, cause.systemImage, isSelected: guidance.answers.cause == cause) {
                        guidance.answer(cause: cause)
                    }
                }
            case .location:
                ForEach(BodyLocation.allCases) { location in
                    option(location.title, location.systemImage, isSelected: guidance.answers.location == location) {
                        guidance.answer(location: location)
                    }
                }
            case .warningSigns:
                ForEach(WarningSign.allCases) { sign in
                    let answer = WarningSignsAnswer.sign(sign)
                    option(answer.title, answer.systemImage, isSelected: guidance.answers.warningSigns == answer, isWarning: true) {
                        guidance.answer(warningSigns: answer)
                    }
                }
                Divider().padding(.vertical, Spacing.xxs)
                ForEach([WarningSignsAnswer.noneOfThese, .unknown], id: \.self) { answer in
                    option(answer.title, answer.systemImage, isSelected: guidance.answers.warningSigns == answer) {
                        guidance.answer(warningSigns: answer)
                    }
                }
            case .onset:
                ForEach(InjuryOnset.allCases) { onset in
                    option(onset.title, onset.systemImage, isSelected: guidance.answers.onset == onset) {
                        guidance.answer(onset: onset)
                    }
                }
            }
        }
    }

    private func option(
        _ title: String,
        _ systemImage: String,
        isSelected: Bool,
        isWarning: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            OptionRow(title: title, systemImage: systemImage, isSelected: isSelected, isWarning: isWarning)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isWarning ? "Mostra imediatamente as orientações de atendimento" : "")
    }
}

/// Linha de opção com alvo de toque amplo (mínimo de 52 pt) e suporte a Dynamic Type.
private struct OptionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let isWarning: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(isWarning ? AnyShapeStyle(.red) : AnyShapeStyle(Palette.emberText))
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? AnyShapeStyle(Palette.emberText) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Metrics.buttonHeight)
        .background(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(isSelected ? Palette.emberText : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}
