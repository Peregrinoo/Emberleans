import Foundation
import Testing
@testable import emberleans

@Suite("GuidanceEngine")
struct GuidanceEngineTests {

    private func answers(
        _ cause: InjuryCause? = nil,
        _ location: BodyLocation? = nil,
        _ signs: WarningSignsAnswer? = nil,
        _ onset: InjuryOnset? = nil
    ) -> QuestionnaireAnswers {
        QuestionnaireAnswers(cause: cause, location: location, warningSigns: signs, onset: onset)
    }

    private func guidance(_ answers: QuestionnaireAnswers) throws -> Guidance {
        guard case .guidance(let guidance) = GuidanceEngine.evaluate(answers) else {
            Issue.record("Esperava orientação para \(answers)")
            throw CancellationError()
        }
        return guidance
    }

    // MARK: - Questionário incompleto

    @Test func emptyAnswersAskTheFirstQuestion() {
        #expect(GuidanceEngine.evaluate(answers()) == .incomplete(next: .cause))
    }

    @Test func partialAnswersWithoutRedFlagsAskTheNextQuestion() {
        #expect(GuidanceEngine.evaluate(answers(.heat)) == .incomplete(next: .location))
        #expect(GuidanceEngine.evaluate(answers(.heat, .trunk)) == .incomplete(next: .warningSigns))
        #expect(GuidanceEngine.evaluate(answers(.heat, .trunk, .noneOfThese)) == .incomplete(next: .onset))
    }

    // MARK: - Emergência imediata (sem concluir o questionário)

    @Test(arguments: WarningSign.allCases)
    func anyWarningSignTriggersEmergencyImmediately(sign: WarningSign) throws {
        let result = try guidance(answers(.cutOrScrape, .armsOrLegs, .sign(sign)))
        #expect(result.kind == .emergency)
        #expect(result.urgency >= .urgentCare)
        #expect(result.appliedRules.contains(.emergencyWarningSign))
        #expect(result.emergencyReasons.contains(sign.title))
    }

    @Test func breathingDifficultyAndHeavyBleedingAskToCallNow() throws {
        #expect(try guidance(answers(.impact, .trunk, .sign(.breathingDifficulty))).urgency == .callEmergency)
        #expect(try guidance(answers(.cutOrScrape, .trunk, .sign(.heavyBleeding))).urgency == .callEmergency)
    }

    @Test func electricityTriggersEmergencyAtTheFirstAnswer() throws {
        let result = try guidance(answers(.electricity))
        #expect(result.kind == .emergency)
        #expect(result.urgency == .callEmergency)
        #expect(result.steps.first?.id == GuidanceContent.electricitySafety.id)
        #expect(result.avoid.contains(GuidanceContent.avoidTouchingLiveVictim))
    }

    @Test func chemicalTriggersEmergencyWithRinseStep() throws {
        let result = try guidance(answers(.chemical))
        #expect(result.kind == .emergency)
        #expect(result.appliedRules == [.emergencyChemical])
        #expect(result.steps.contains(GuidanceContent.chemicalRinse))
    }

    @Test func heavyBleedingIncludesPressureStep() throws {
        let result = try guidance(answers(.cutOrScrape, .armsOrLegs, .sign(.heavyBleeding)))
        #expect(result.steps.contains(GuidanceContent.bleedingPressure))
    }

    // MARK: - Informação insuficiente

    @Test func unknownCauseGivesNoSpecificSteps() throws {
        let result = try guidance(answers(.unknown, .trunk, .noneOfThese, .today))
        #expect(result.kind == .insufficientInformation)
        #expect(result.steps.isEmpty)
        #expect(result.avoid.isEmpty)
        #expect(result.urgency == .professionalEvaluation)
        #expect(!result.seekCare.isEmpty)
    }

    @Test func unknownCauseWithWarningSignIsStillAnEmergency() throws {
        #expect(try guidance(answers(.unknown, .trunk, .sign(.severePain))).kind == .emergency)
    }

    // MARK: - "Não sei informar" não é ausência de risco

    @Test func unknownWarningSignsRaiseUrgencyAndAddNotice() throws {
        let result = try guidance(answers(.impact, .trunk, .unknown, .today))
        #expect(result.kind == .standard)
        #expect(result.urgency == .professionalEvaluation)
        #expect(result.notices.contains(GuidanceContent.noticeWarningSignsUnknown))
    }

    @Test func noneOfTheseDoesNotRaiseUrgency() throws {
        let result = try guidance(answers(.impact, .trunk, .noneOfThese, .today))
        #expect(result.urgency == .observe)
    }

    // MARK: - Regras por causa e tempo

    @Test func recentHeatBurnStartsWithCoolingFor20Minutes() throws {
        let result = try guidance(answers(.heat, .armsOrLegs, .noneOfThese, .justNow))
        #expect(result.steps.first == GuidanceContent.heatCool)
        #expect(result.avoid.contains(GuidanceContent.avoidIce))
        #expect(result.avoid.contains(GuidanceContent.avoidHomeRemedies))
        #expect(result.avoid.contains(GuidanceContent.avoidBlisters))
        #expect(result.appliedRules.contains(.heatRecentFirstAid))
    }

    @Test func heatBurnTodayCoolingIsConditionedOnThreeHours() throws {
        let result = try guidance(answers(.heat, .armsOrLegs, .noneOfThese, .today))
        #expect(result.steps.first == GuidanceContent.heatCoolIfRecent)
    }

    @Test func olderHeatBurnDoesNotSuggestCooling() throws {
        let result = try guidance(answers(.heat, .armsOrLegs, .noneOfThese, .daysAgo))
        #expect(!result.steps.contains(GuidanceContent.heatCool))
        #expect(!result.steps.contains(GuidanceContent.heatCoolIfRecent))
        #expect(result.steps.contains(GuidanceContent.observeInfection))
    }

    @Test func recentCutStartsWithPressure() throws {
        let result = try guidance(answers(.cutOrScrape, .armsOrLegs, .noneOfThese, .justNow))
        #expect(result.steps.first == GuidanceContent.cutPressure)
        #expect(result.seekCare.contains(GuidanceContent.seekDirtyWound))
    }

    @Test func recentImpactUsesProtectedCold() throws {
        let result = try guidance(answers(.impact, .armsOrLegs, .noneOfThese, .justNow))
        #expect(result.steps.first == GuidanceContent.impactCold)
        #expect(result.avoid.contains(GuidanceContent.avoidDirectIce))
    }

    @Test(arguments: [BodyLocation.faceOrNeck, .handsOrFeet, .intimate])
    func sensitiveLocationsRecommendProfessionalEvaluation(location: BodyLocation) throws {
        let result = try guidance(answers(.heat, location, .noneOfThese, .justNow))
        #expect(result.urgency == .professionalEvaluation)
        #expect(result.appliedRules.contains(.sensitiveLocation))
    }

    @Test func unknownOnsetAddsNotice() throws {
        let result = try guidance(answers(.cutOrScrape, .trunk, .noneOfThese, .unknown))
        #expect(result.appliedRules.contains(.onsetUnknown))
    }

    // MARK: - Garantias gerais

    /// Todas as combinações completas de respostas.
    static var allCompleteAnswers: [QuestionnaireAnswers] {
        InjuryCause.allCases.flatMap { cause in
            BodyLocation.allCases.flatMap { location in
                WarningSignsAnswer.allOptions.flatMap { signs in
                    InjuryOnset.allCases.map { onset in
                        QuestionnaireAnswers(cause: cause, location: location, warningSigns: signs, onset: onset)
                    }
                }
            }
        }
    }

    @Test func everyCompleteCombinationProducesGuidanceWithCareSigns() throws {
        for combination in Self.allCompleteAnswers {
            let result = try guidance(combination)
            #expect(!result.seekCare.isEmpty, "Sem lista de atendimento para \(combination)")
            #expect(!result.appliedRules.isEmpty)
        }
    }

    @Test func everyStepAndItemCitesASource() throws {
        for combination in Self.allCompleteAnswers {
            let result = try guidance(combination)
            for step in result.steps { #expect(!step.sources.isEmpty, "\(step.id) sem fonte") }
            for item in result.avoid + result.seekCare + result.notices {
                #expect(!item.sources.isEmpty, "\(item.id) sem fonte")
            }
        }
    }

    @Test func forbiddenLanguageNeverAppears() throws {
        let forbidden = [
            "diagnóstico confirmado", "lesão identificada com certeza", "gravidade determinada",
            "não precisa procurar atendimento", "lesão é segura", "é segura", "sem risco",
            "pomada", "antibiótico", "paracetamol", "ibuprofeno", "mg",
        ]
        for combination in Self.allCompleteAnswers {
            let text = try guidance(combination).allTexts.joined(separator: " ").lowercased()
            for phrase in forbidden {
                #expect(!text.contains(" \(phrase)") && !text.hasPrefix(phrase), "\"\(phrase)\" em \(combination)")
            }
        }
    }

    @Test func evaluationIsDeterministic() {
        for combination in Self.allCompleteAnswers {
            #expect(GuidanceEngine.evaluate(combination) == GuidanceEngine.evaluate(combination))
        }
    }

    @Test func sourcesHaveValidLinksExceptTheAppRule() {
        for source in GuidanceSource.allCases {
            if source == .emberLensConservativeRule {
                #expect(source.url == nil)
            } else {
                #expect(source.url?.scheme == "https")
            }
        }
    }
}
