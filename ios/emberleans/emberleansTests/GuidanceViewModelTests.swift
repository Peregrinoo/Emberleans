import Foundation
import Testing
@testable import emberleans

@MainActor
@Suite("GuidanceViewModel")
struct GuidanceViewModelTests {
    @Test func startsNotStarted() {
        let viewModel = GuidanceViewModel()
        #expect(viewModel.state == .notStarted)
        #expect(viewModel.state.guidance == nil)
    }

    @Test func startShowsTheFirstQuestion() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        #expect(viewModel.state == .inProgress(.cause))
        #expect(!viewModel.canGoBack)
    }

    @Test func answeringAdvancesThroughAllQuestions() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .heat)
        #expect(viewModel.state == .inProgress(.location))
        viewModel.answer(location: .armsOrLegs)
        #expect(viewModel.state == .inProgress(.warningSigns))
        viewModel.answer(warningSigns: .noneOfThese)
        #expect(viewModel.state == .inProgress(.onset))
        viewModel.answer(onset: .justNow)

        guard case .guidanceAvailable(let guidance) = viewModel.state else {
            Issue.record("Esperava orientação disponível, obtido \(viewModel.state)")
            return
        }
        #expect(guidance.steps.first == GuidanceContent.heatCool)
    }

    @Test func warningSignShowsAlertWithoutFinishingTheQuestionnaire() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .cutOrScrape)
        viewModel.answer(location: .trunk)
        viewModel.answer(warningSigns: .sign(.heavyBleeding))

        guard case .alert(let guidance) = viewModel.state else {
            Issue.record("Esperava alerta, obtido \(viewModel.state)")
            return
        }
        #expect(guidance.urgency == .callEmergency)
        #expect(viewModel.answers.onset == nil)
    }

    @Test func electricityShowsAlertAfterTheFirstAnswer() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .electricity)
        guard case .alert = viewModel.state else {
            Issue.record("Esperava alerta, obtido \(viewModel.state)")
            return
        }
    }

    @Test func unknownCauseEndsInInsufficientInformation() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .unknown)
        viewModel.answer(location: .other)
        viewModel.answer(warningSigns: .noneOfThese)
        viewModel.answer(onset: .unknown)
        guard case .insufficientInformation(let guidance) = viewModel.state else {
            Issue.record("Esperava informação insuficiente, obtido \(viewModel.state)")
            return
        }
        #expect(guidance.steps.isEmpty)
    }

    @Test func goBackReturnsToThePreviousQuestion() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .impact)
        #expect(viewModel.canGoBack)
        viewModel.goBack()
        #expect(viewModel.state == .inProgress(.cause))
        #expect(viewModel.answers.cause == .impact)
    }

    @Test func reviewingAfterAnAlertCompletesTheMissingAnswers() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .chemical)
        viewModel.reviewAnswers()
        #expect(viewModel.state == .inProgress(.cause))

        viewModel.answer(cause: .heat)
        #expect(viewModel.state == .inProgress(.location))
        viewModel.answer(location: .trunk)
        viewModel.answer(warningSigns: .noneOfThese)
        viewModel.answer(onset: .today)
        guard case .guidanceAvailable = viewModel.state else {
            Issue.record("Esperava orientação disponível, obtido \(viewModel.state)")
            return
        }
    }

    @Test func resetDiscardsAnswers() {
        let viewModel = GuidanceViewModel()
        viewModel.start()
        viewModel.answer(cause: .heat)
        viewModel.reset()
        #expect(viewModel.state == .notStarted)
        #expect(viewModel.answers == QuestionnaireAnswers())
    }
}
