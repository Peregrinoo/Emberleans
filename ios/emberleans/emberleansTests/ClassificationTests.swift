import Foundation
import Testing
@testable import emberleans

@Suite("LesionClass")
struct LesionClassTests {
    @Test func displayOrderFollowsDesign() {
        #expect(LesionClass.allCases.map(\.displayName) == ["Queimadura", "Abrasão", "Hematoma", "Laceração", "Pele normal"])
    }

    @Test func modelLabelsMatchExportedModel() {
        #expect(LesionClass.expectedModelLabels == Set(Fixtures.exportedLabels))
    }

    @Test(arguments: ["burn", "Burns", "", "normal skin"])
    func unknownLabelsAreRejected(label: String) {
        #expect(LesionClass(modelLabel: label) == nil)
    }
}

@Suite("ClassificationMapper")
struct ClassificationMapperTests {
    @Test func mapsLabelsIndependentlyOfOutputOrder() throws {
        let result = try ClassificationMapper.makeResult(
            from: Fixtures.burnScores, inferenceDuration: .milliseconds(18), source: .coreML
        )
        #expect(result.scores.map(\.lesionClass) == LesionClass.allCases)
        #expect(result.topClass == .burn)
        #expect(result.topProbability == 0.72)
        #expect(result.probability(for: .laceration) == 0.09)
        #expect(result.inferenceDuration == .milliseconds(18))
        #expect(result.source == .coreML)
    }

    @Test func rejectsUnknownLabel() {
        var scores = Fixtures.burnScores
        scores["Scald"] = scores.removeValue(forKey: "Burn")
        #expect(throws: ClassifierError.self) {
            try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .coreML)
        }
    }

    @Test func rejectsMissingClass() {
        var scores = Fixtures.burnScores
        scores.removeValue(forKey: "Bruise")
        scores["Burn"] = 0.75
        #expect(throws: ClassifierError.self) {
            try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .coreML)
        }
    }

    @Test func rejectsProbabilitiesThatDoNotSumToOne() {
        var scores = Fixtures.burnScores
        scores["Burn"] = 0.30
        #expect(throws: ClassifierError.self) {
            try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .coreML)
        }
    }

    @Test(arguments: [Double.nan, -0.1, 1.5])
    func rejectsInvalidProbability(value: Double) {
        var scores = Fixtures.burnScores
        scores["Normal Skin"] = value
        #expect(throws: ClassifierError.self) {
            try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .coreML)
        }
    }

    @Test func acceptsSmallFP16RoundingError() throws {
        var scores = Fixtures.burnScores
        scores["Burn"] = 0.7105 // soma 0,9905
        let result = try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .coreML)
        #expect(result.topClass == .burn)
    }

    @Test func tieUsesDisplayOrder() throws {
        let scores = ["Burn": 0.4, "Abrasion": 0.4, "Bruise": 0.1, "Laceration": 0.05, "Normal Skin": 0.05]
        let result = try ClassificationMapper.makeResult(from: scores, inferenceDuration: .zero, source: .coreML)
        #expect(result.topClass == .burn)
    }

    @Test func keepsSimulatedSource() throws {
        let result = try ClassificationMapper.makeResult(from: Fixtures.burnScores, inferenceDuration: .zero, source: .simulated)
        #expect(result.source == .simulated)
    }
}

@Suite("ModelContract")
struct ModelContractTests {
    private func description(
        labels: [String] = Fixtures.exportedLabels,
        metadata: String? = #"["Abrasion", "Bruise", "Burn", "Laceration", "Normal Skin"]"#,
        width: Int? = 256,
        height: Int? = 256
    ) -> ModelContract.Description {
        ModelContract.Description(classLabels: labels, metadataClassesJSON: metadata, inputWidth: width, inputHeight: height)
    }

    @Test func acceptsExportedModel() throws {
        try ModelContract.validate(description())
    }

    @Test func acceptsModelWithoutCustomMetadata() throws {
        try ModelContract.validate(description(metadata: nil))
    }

    @Test func rejectsMissingClass() {
        #expect(throws: ClassifierError.self) {
            try ModelContract.validate(description(labels: Array(Fixtures.exportedLabels.dropLast()), metadata: nil))
        }
    }

    @Test func rejectsDuplicatedLabel() {
        #expect(throws: ClassifierError.self) {
            try ModelContract.validate(description(labels: Fixtures.exportedLabels + ["Burn"], metadata: nil))
        }
    }

    @Test func rejectsMetadataThatDisagreesWithLabels() {
        #expect(throws: ClassifierError.self) {
            try ModelContract.validate(description(metadata: #"["A", "B", "C", "D", "E"]"#))
        }
    }

    @Test func rejectsUnexpectedInputSize() {
        #expect(throws: ClassifierError.unexpectedModelInput("Entrada 224×224; esperado 256×256")) {
            try ModelContract.validate(description(width: 224, height: 224))
        }
    }
}

@Suite("ResultFormatting")
struct ResultFormattingTests {
    @Test(arguments: [
        (0.72, "72%"), (1.0, "100%"), (0.0, "0%"), (0.004, "<1%"), (0.005, "1%"), (0.995, "100%"),
    ])
    func percent(value: Double, expected: String) {
        #expect(ResultFormatting.percent(value) == expected)
    }

    @Test func milliseconds() {
        #expect(ResultFormatting.milliseconds(.milliseconds(18)) == "18 ms")
        #expect(ResultFormatting.milliseconds(.microseconds(18_600)) == "19 ms")
        #expect(ResultFormatting.milliseconds(.microseconds(300)) == "<1 ms")
        #expect(ResultFormatting.milliseconds(.seconds(1)) == "1000 ms")
    }
}

@Suite("AnalysisError")
struct AnalysisErrorTests {
    @Test func mapsClassifierErrors() {
        #expect(AnalysisError(ClassifierError.modelNotFound) == .modelUnavailable)
        #expect(AnalysisError(ClassifierError.modelLoadFailed("x")) == .modelUnavailable)
        #expect(AnalysisError(ClassifierError.unexpectedModelClasses(found: [])) == .modelUnavailable)
        #expect(AnalysisError(ClassifierError.unexpectedModelInput("x")) == .modelUnavailable)
        #expect(AnalysisError(ClassifierError.invalidImage) == .invalidImage)
        #expect(AnalysisError(ClassifierError.inferenceFailed("x")) == .inferenceFailed)
        #expect(AnalysisError(ClassifierError.unexpectedOutput("x")) == .unexpectedOutput)
    }

    @Test func mapsUnknownErrorsToInferenceFailure() {
        struct Other: Error {}
        #expect(AnalysisError(Other()) == .inferenceFailed)
    }

    @Test func invalidImageIsNotRetryable() {
        #expect(!AnalysisError.invalidImage.isRetryable)
        #expect(AnalysisError.inferenceFailed.isRetryable)
    }
}
