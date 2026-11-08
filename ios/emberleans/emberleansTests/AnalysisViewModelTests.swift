import Foundation
import Testing
@testable import emberleans

@MainActor
@Suite("AnalysisViewModel")
struct AnalysisViewModelTests {
    @Test func startsIdle() {
        let viewModel = AnalysisViewModel(classifier: StubClassifier(.success(Fixtures.result())))
        #expect(viewModel.state == .idle)
        #expect(!viewModel.canAnalyze)
    }

    @Test func selectingAnImageEnablesAnalysis() {
        let viewModel = AnalysisViewModel(classifier: StubClassifier(.success(Fixtures.result())))
        let image = Fixtures.selectedImage()
        viewModel.select(image)
        #expect(viewModel.state == .imageSelected(image))
        #expect(viewModel.canAnalyze)
    }

    @Test func successfulAnalysisPublishesResult() async {
        let expected = Fixtures.result()
        let classifier = StubClassifier(.success(expected))
        let viewModel = AnalysisViewModel(classifier: classifier)
        let image = Fixtures.selectedImage()
        viewModel.select(image)

        await viewModel.analyze()

        #expect(viewModel.state == .success(image, expected))
        #expect(viewModel.state.hasFinishedAnalysis)
        #expect(classifier.callCount == 1)
    }

    @Test(arguments: [
        (ClassifierError.inferenceFailed("x"), AnalysisError.inferenceFailed),
        (ClassifierError.modelNotFound, AnalysisError.modelUnavailable),
        (ClassifierError.unexpectedOutput("x"), AnalysisError.unexpectedOutput),
    ])
    func failedAnalysisKeepsImageAndMapsError(thrown: ClassifierError, expected: AnalysisError) async {
        let viewModel = AnalysisViewModel(classifier: StubClassifier(.failure(thrown)))
        let image = Fixtures.selectedImage()
        viewModel.select(image)

        await viewModel.analyze()

        #expect(viewModel.state == .failure(AnalysisFailure(image: image, error: expected)))
        #expect(viewModel.state.hasFinishedAnalysis)
        #expect(viewModel.canAnalyze, "deve permitir tentar novamente")
    }

    @Test func exposesProcessingStateAndIgnoresDuplicateRequests() async {
        let classifier = SuspendingClassifier()
        let viewModel = AnalysisViewModel(classifier: classifier)
        let image = Fixtures.selectedImage()
        viewModel.select(image)

        let task = Task { await viewModel.analyze() }
        await classifier.waitForPendingCalls()

        #expect(viewModel.state == .processing(image))
        #expect(!viewModel.canAnalyze)

        await viewModel.analyze() // ignorada: já existe uma análise em andamento
        #expect(classifier.callCount == 1)

        classifier.resumeNext(with: .success(Fixtures.result()))
        await task.value
        #expect(viewModel.state == .success(image, Fixtures.result()))
    }

    @Test func staleResultDoesNotOverwriteNewSelection() async {
        let classifier = SuspendingClassifier()
        let viewModel = AnalysisViewModel(classifier: classifier)
        viewModel.select(Fixtures.selectedImage())

        let task = Task { await viewModel.analyze() }
        await classifier.waitForPendingCalls()

        let newImage = Fixtures.selectedImage(source: .camera)
        viewModel.select(newImage)

        classifier.resumeNext(with: .success(Fixtures.result()))
        await task.value
        #expect(viewModel.state == .imageSelected(newImage))
    }

    @Test func analyzeWithoutImageDoesNothing() async {
        let classifier = StubClassifier(.success(Fixtures.result()))
        let viewModel = AnalysisViewModel(classifier: classifier)

        await viewModel.analyze()

        #expect(viewModel.state == .idle)
        #expect(classifier.callCount == 0)
    }

    @Test func invalidSelectionIsAFailureWithoutImage() async {
        let classifier = StubClassifier(.success(Fixtures.result()))
        let viewModel = AnalysisViewModel(classifier: classifier)

        viewModel.selectionFailed()

        #expect(viewModel.state == .failure(AnalysisFailure(image: nil, error: .invalidImage)))
        #expect(!viewModel.state.hasFinishedAnalysis)
        #expect(!viewModel.canAnalyze)
        await viewModel.analyze()
        #expect(classifier.callCount == 0)
    }

    @Test func resetReturnsToIdle() {
        let viewModel = AnalysisViewModel(classifier: StubClassifier(.success(Fixtures.result())))
        viewModel.select(Fixtures.selectedImage())
        viewModel.reset()
        #expect(viewModel.state == .idle)
    }
}
