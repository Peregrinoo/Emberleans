import Foundation

/// Fontes públicas que fundamentam cada orientação. Toda orientação exibida
/// referencia ao menos uma fonte (ou a regra conservadora do próprio app),
/// para que o conteúdo possa ser revisado.
///
/// Mapeamento completo regra → fonte: `docs/guidance-sources.md`.
nonisolated enum GuidanceSource: String, CaseIterable, Identifiable, Sendable {
    case nhsBurns
    case nhsCuts
    case britishRedCrossBurns
    case americanBurnAssociation
    case healthdirectChemicalBurns
    case healthwiseChemicalBurns
    case stJohnElectricShock
    case medlinePlusBruises
    case healthNZBruises
    /// Regra conservadora definida pelo EmberLens (não é uma fonte externa).
    case emberLensConservativeRule

    var id: String { rawValue }

    var organization: String {
        switch self {
        case .nhsBurns, .nhsCuts: "NHS (Reino Unido)"
        case .britishRedCrossBurns: "Cruz Vermelha Britânica"
        case .americanBurnAssociation: "American Burn Association"
        case .healthdirectChemicalBurns: "healthdirect (Governo da Austrália)"
        case .healthwiseChemicalBurns: "Healthwise / Cigna"
        case .stJohnElectricShock: "St John Ambulance Australia"
        case .medlinePlusBruises: "MedlinePlus (NIH, EUA)"
        case .healthNZBruises: "Health New Zealand"
        case .emberLensConservativeRule: "EmberLens"
        }
    }

    var title: String {
        switch self {
        case .nhsBurns: "Burns and scalds"
        case .nhsCuts: "Cuts and grazes"
        case .britishRedCrossBurns: "First aid for burns"
        case .americanBurnAssociation: "First Aid for Minor Burns (ficha informativa, 2020)"
        case .healthdirectChemicalBurns: "Chemical burns"
        case .healthwiseChemicalBurns: "First Aid for Chemical Burns"
        case .stJohnElectricShock: "Electric shock (ficha de primeiros socorros)"
        case .medlinePlusBruises: "Bruises"
        case .healthNZBruises: "Bruises"
        case .emberLensConservativeRule: "Regra conservadora: na dúvida, recomendar avaliação profissional"
        }
    }

    var url: URL? {
        let string: String? = switch self {
        case .nhsBurns: "https://www.nhs.uk/conditions/burns-and-scalds/"
        case .nhsCuts: "https://www.nhs.uk/conditions/cuts-and-grazes/"
        case .britishRedCrossBurns: "https://www.redcross.org.uk/first-aid/learn-first-aid/burns"
        case .americanBurnAssociation: "https://ameriburn.org/"
        case .healthdirectChemicalBurns: "https://www.healthdirect.gov.au/chemical-burns"
        case .healthwiseChemicalBurns: "https://www.cigna.com/knowledge-center/hw/first-aid-for-chemical-burns-sig256946"
        case .stJohnElectricShock: "https://stjohn.org.au/app/uploads/2025/08/Fact-sheets_electric-shock.pdf"
        case .medlinePlusBruises: "https://medlineplus.gov/ency/article/007213.htm"
        case .healthNZBruises: "https://info.health.nz/conditions-treatments/emergencies-and-first-aid/bruises"
        case .emberLensConservativeRule: nil
        }
        return string.flatMap(URL.init(string:))
    }
}

/// Data da última revisão do conteúdo educativo, exibida na tela.
nonisolated enum GuidanceContentInfo {
    static let reviewedOn = "novembro de 2026"
    static let emergencyNumber = "192"
    static let emergencyServiceName = "SAMU"
    static let emergencyCallURL = URL(string: "tel:192")!
}
