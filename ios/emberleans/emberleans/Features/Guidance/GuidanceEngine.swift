import Foundation

/// Regras de orientação: funções puras, determinísticas e testáveis.
///
/// A única entrada é `QuestionnaireAnswers`. O resultado da análise visual não é
/// um parâmetro e, portanto, não pode influenciar nenhuma orientação.
///
/// Princípios aplicados:
/// - Sinais de emergência são avaliados primeiro e funcionam com respostas parciais.
/// - Sem saber a causa, nenhum cuidado específico é apresentado.
/// - "Não sei informar" nunca é tratado como ausência de risco.
/// - Nenhuma regra conclui que a lesão é leve ou dispensa atendimento.
nonisolated enum GuidanceEngine {

    static func evaluate(_ answers: QuestionnaireAnswers) -> GuidanceEvaluation {
        if let emergency = emergencyGuidance(for: answers) {
            return .guidance(emergency)
        }
        if let next = answers.firstUnanswered {
            return .incomplete(next: next)
        }
        guard let cause = answers.cause, cause != .unknown else {
            return .guidance(insufficientInformation(for: answers))
        }
        return .guidance(standardGuidance(cause: cause, answers: answers))
    }

    // MARK: - Emergência

    /// Retorna orientação de emergência assim que uma resposta a justificar,
    /// sem exigir que o questionário esteja completo.
    static func emergencyGuidance(for answers: QuestionnaireAnswers) -> Guidance? {
        var rules: [GuidanceRule] = []
        var reasons: [String] = []
        var urgency = UrgencyLevel.urgentCare

        if case .sign(let sign) = answers.warningSigns {
            rules.append(.emergencyWarningSign)
            reasons.append(sign.title)
            if sign == .breathingDifficulty || sign == .heavyBleeding {
                urgency = .callEmergency
            }
        }
        if answers.cause == .electricity {
            rules.append(.emergencyElectricity)
            reasons.append("Lesão causada por eletricidade")
            urgency = .callEmergency
        }
        if answers.cause == .chemical {
            rules.append(.emergencyChemical)
            reasons.append("Lesão causada por produto químico")
        }
        guard !rules.isEmpty else { return nil }

        var steps: [GuidanceStep] = []
        var avoid: [GuidanceItem] = []

        // A segurança de quem ajuda vem antes de tudo no caso da eletricidade.
        if answers.cause == .electricity {
            steps.append(GuidanceContent.electricitySafety)
            avoid.append(GuidanceContent.avoidTouchingLiveVictim)
        }
        steps.append(GuidanceContent.emergencyCall)

        switch answers.cause {
        case .chemical:
            steps += [GuidanceContent.chemicalRinse, GuidanceContent.chemicalRemoveClothing, GuidanceContent.chemicalBringContainer]
            avoid += [GuidanceContent.avoidChemicalContact, GuidanceContent.avoidStuckClothing]
        case .heat:
            steps += [GuidanceContent.heatCoolIfRecent, GuidanceContent.keepWarm]
            avoid += [GuidanceContent.avoidIce, GuidanceContent.avoidHomeRemedies, GuidanceContent.avoidStuckClothing]
        default:
            break
        }
        if answers.warningSigns == .sign(.heavyBleeding) {
            steps.append(GuidanceContent.bleedingPressure)
            avoid.append(GuidanceContent.avoidPressingObject)
        }

        let headline = urgency == .callEmergency
            ? "Ligue agora para o SAMU 192"
            : "Procure atendimento médico imediatamente"

        return Guidance(
            kind: .emergency,
            urgency: urgency,
            headline: headline,
            summary: "Uma das suas respostas indica uma situação que precisa de atendimento profissional. Não espere a lesão piorar e não use o aplicativo para avaliar a gravidade.",
            emergencyReasons: reasons,
            notices: [],
            steps: steps,
            avoid: avoid,
            seekCare: GuidanceContent.baseSeekCare,
            appliedRules: rules
        )
    }

    // MARK: - Informação insuficiente

    static func insufficientInformation(for answers: QuestionnaireAnswers) -> Guidance {
        var rules: [GuidanceRule] = [.insufficientUnknownCause]
        var notices: [GuidanceItem] = []
        if answers.warningSigns == .unknown {
            rules.append(.warningSignsUnknown)
            notices.append(GuidanceContent.noticeWarningSignsUnknown)
        }
        return Guidance(
            kind: .insufficientInformation,
            urgency: .professionalEvaluation,
            headline: "Informações insuficientes para orientações específicas",
            summary: "Sem saber como a lesão aconteceu, o EmberLens não apresenta cuidados específicos. A análise visual não substitui essa informação. Procure orientação de um profissional de saúde e confira os sinais abaixo.",
            emergencyReasons: [],
            notices: notices,
            steps: [],
            avoid: [],
            seekCare: GuidanceContent.baseSeekCare + [GuidanceContent.seekWhenUnsure],
            appliedRules: rules
        )
    }

    // MARK: - Orientação padrão

    static func standardGuidance(cause: InjuryCause, answers: QuestionnaireAnswers) -> Guidance {
        var rules: [GuidanceRule] = []
        var notices: [GuidanceItem] = []
        var urgency = UrgencyLevel.observe

        let onset = answers.onset ?? .unknown
        let isOlder = onset == .daysAgo

        if answers.location?.isSensitive == true {
            rules.append(.sensitiveLocation)
            notices.append(GuidanceContent.noticeSensitiveLocation)
            urgency = max(urgency, .professionalEvaluation)
        }
        if answers.warningSigns == .unknown {
            rules.append(.warningSignsUnknown)
            notices.append(GuidanceContent.noticeWarningSignsUnknown)
            urgency = max(urgency, .professionalEvaluation)
        }
        if onset == .unknown {
            rules.append(.onsetUnknown)
            notices.append(GuidanceContent.noticeOnsetUnknown)
        }

        let headline: String
        var steps: [GuidanceStep]
        var avoid: [GuidanceItem]
        var extraSeekCare: [GuidanceItem]

        switch cause {
        case .heat:
            headline = "Lesão por calor ou líquido quente"
            if isOlder {
                rules.append(.heatOlderCare)
                steps = [GuidanceContent.heatCoverOlder, GuidanceContent.observeInfection]
                avoid = [GuidanceContent.avoidBlisters, GuidanceContent.avoidHomeRemedies]
            } else {
                rules.append(.heatRecentFirstAid)
                let cool = onset == .justNow ? GuidanceContent.heatCool : GuidanceContent.heatCoolIfRecent
                steps = [cool, GuidanceContent.heatRemoveJewellery, GuidanceContent.heatCover,
                         GuidanceContent.keepWarm, GuidanceContent.observeSigns]
                avoid = [GuidanceContent.avoidIce, GuidanceContent.avoidHomeRemedies,
                         GuidanceContent.avoidBlisters, GuidanceContent.avoidStuckClothing]
            }
            extraSeekCare = [GuidanceContent.seekChildBurn]

        case .cutOrScrape:
            headline = "Corte ou arranhão"
            if isOlder {
                rules.append(.cutOlderCare)
                steps = [GuidanceContent.cutKeepClean, GuidanceContent.observeInfection]
                avoid = [GuidanceContent.avoidPressingObject]
            } else {
                rules.append(.cutRecentFirstAid)
                steps = [GuidanceContent.cutPressure, GuidanceContent.cutClean,
                         GuidanceContent.cutCover, GuidanceContent.observeSigns]
                avoid = [GuidanceContent.avoidPressingObject]
            }
            extraSeekCare = [GuidanceContent.seekDirtyWound]

        case .impact:
            headline = "Lesão por pancada"
            if isOlder {
                rules.append(.impactOlderCare)
                steps = [GuidanceContent.observeSigns]
                avoid = []
            } else {
                rules.append(.impactRecentFirstAid)
                steps = [GuidanceContent.impactCold, GuidanceContent.impactElevate,
                         GuidanceContent.impactRest, GuidanceContent.observeSigns]
                avoid = [GuidanceContent.avoidDirectIce]
            }
            extraSeekCare = [GuidanceContent.seekBruiseWorse]

        case .chemical, .electricity, .unknown:
            // Tratados antes (emergência ou informação insuficiente).
            preconditionFailure("Causa \(cause) deve ser tratada por outra regra.")
        }

        let summary = urgency >= .professionalEvaluation
            ? "Orientações iniciais com base nas suas respostas. Pelas informações fornecidas, recomenda-se também a avaliação de um profissional de saúde."
            : "Orientações iniciais com base nas suas respostas. Elas não substituem a avaliação de um profissional de saúde."

        return Guidance(
            kind: .standard,
            urgency: urgency,
            headline: headline,
            summary: summary,
            emergencyReasons: [],
            notices: notices,
            steps: steps,
            avoid: avoid,
            seekCare: GuidanceContent.baseSeekCare + extraSeekCare + [GuidanceContent.seekWhenUnsure],
            appliedRules: rules
        )
    }
}
