import Foundation

/// Conteúdo da tela Sobre. As métricas vêm de `ml/reports/test/metrics.json`
/// (conjunto de teste, n = 187, avaliado uma única vez, modelo PyTorch FP32).
enum AboutContent {
    struct Fact: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    struct Metric: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    static let modelFacts: [Fact] = [
        Fact(title: "Arquitetura", value: "MobileNetV3 Small"),
        Fact(title: "Treinamento", value: "PyTorch"),
        Fact(title: "Inferência", value: "Core ML"),
        Fact(title: "Entrada", value: "224 × 224 pixels"),
        Fact(title: "Categorias", value: "\(LesionClass.allCases.count)"),
        Fact(title: "Execução", value: "No dispositivo"),
    ]

    static let testMetrics: [Metric] = [
        Metric(value: "84%", label: "Accuracy"),
        Metric(value: "0,767", label: "Macro F1"),
        Metric(value: "68%", label: "Recall de queimaduras"),
    ]

    static let testSetSize = 187

    static let limitations = [
        "O modelo foi treinado com um dataset público de imagens coletadas da web.",
        "As imagens não possuem validação clínica suficiente.",
        "O desempenho em fotos reais de iPhone não foi medido; há limitações de generalização.",
        "As classificações não são diagnósticos e não substituem uma avaliação profissional.",
    ]

    static let inspiration = "Pelis, pesquisa desenvolvida na Universidade de Fortaleza (Unifor), investigou o uso de inteligência artificial para classificação e auxílio na terapia tópica de queimaduras."

    static let reference = "AGUIAR, G. A. F. et al. Inteligência artificial para classificação e auxílio na terapia tópica de queimaduras em tempo real. Enfermagem em Foco, v. 10, n. 5, 2019."

    static let repositoryURL = URL(string: "https://github.com/Peregrinoo/Emberleans")!

    static let credits = "Dataset: Basic Wound Classify (Roboflow Universe, CC BY 4.0). Pesos iniciais: MobileNetV3 Small ImageNet (torchvision)."

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
