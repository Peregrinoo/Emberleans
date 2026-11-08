import Foundation
import Observation

/// Estado da experiência de orientação.
enum GuidanceState: Equatable {
    /// O questionário ainda não começou.
    case notStarted
    /// Questionário em andamento.
    case inProgress(Question)
    /// Orientação inicial disponível.
    case guidanceAvailable(Guidance)
    /// Faltam informações para orientações específicas.
    case insufficientInformation(Guidance)
    /// Uma resposta indicou sinal de alerta ou emergência.
    case alert(Guidance)

    var guidance: Guidance? {
        switch self {
        case .guidanceAvailable(let guidance), .insufficientInformation(let guidance), .alert(let guidance): guidance
        case .notStarted, .inProgress: nil
        }
    }
}

/// Conduz o questionário e expõe a orientação calculada por `GuidanceEngine`.
/// Não conhece a análise visual: nenhuma dependência de classificador ou resultado.
@Observable
final class GuidanceViewModel {
    private enum Phase: Equatable {
        case notStarted
        case answering(Question)
        case finished
    }

    private(set) var answers = QuestionnaireAnswers()
    private var phase: Phase = .notStarted

    var state: GuidanceState {
        switch phase {
        case .notStarted:
            return .notStarted
        case .answering(let question):
            return .inProgress(question)
        case .finished:
            switch GuidanceEngine.evaluate(answers) {
            case .incomplete(let next):
                return .inProgress(next)
            case .guidance(let guidance):
                switch guidance.kind {
                case .emergency: return .alert(guidance)
                case .insufficientInformation: return .insufficientInformation(guidance)
                case .standard: return .guidanceAvailable(guidance)
                }
            }
        }
    }

    var canGoBack: Bool {
        if case .answering(let question) = phase { return question.previous != nil }
        return false
    }

    func start() {
        phase = .answering(.cause)
    }

    func answer(cause: InjuryCause) {
        answers.cause = cause
        advance(from: .cause)
    }

    func answer(location: BodyLocation) {
        answers.location = location
        advance(from: .location)
    }

    func answer(warningSigns: WarningSignsAnswer) {
        answers.warningSigns = warningSigns
        advance(from: .warningSigns)
    }

    func answer(onset: InjuryOnset) {
        answers.onset = onset
        advance(from: .onset)
    }

    func goBack() {
        guard case .answering(let question) = phase, let previous = question.previous else { return }
        phase = .answering(previous)
    }

    /// Volta ao início do questionário mantendo as respostas, para revisão.
    func reviewAnswers() {
        phase = .answering(.cause)
    }

    /// Descarta tudo (nova imagem).
    func reset() {
        answers = QuestionnaireAnswers()
        phase = .notStarted
    }

    /// Avança para a próxima pergunta ou encerra imediatamente se uma resposta
    /// acionar a regra de emergência.
    private func advance(from question: Question) {
        if GuidanceEngine.emergencyGuidance(for: answers) != nil {
            phase = .finished
            return
        }
        if let next = question.next {
            phase = .answering(next)
        } else if let unanswered = answers.firstUnanswered {
            // Revisão após uma emergência anterior: completa o que falta.
            phase = .answering(unanswered)
        } else {
            phase = .finished
        }
    }
}
