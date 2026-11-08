import SwiftUI

/// Destinos da navegação hierárquica (sem Tab Bar).
enum AppRoute: Hashable {
    case preview
    case result
    case about
}

/// Raiz do app: `NavigationStack` e ligação entre a seleção de imagem e a análise.
struct RootView: View {
    @State private var path: [AppRoute] = []
    @State private var selection: ImageSelectionModel
    @State private var analysis: AnalysisViewModel
    @State private var guidance = GuidanceViewModel()

    init(dependencies: AppDependencies) {
        _selection = State(initialValue: ImageSelectionModel(
            camera: dependencies.camera,
            photoLoader: dependencies.photoLoader
        ))
        _analysis = State(initialValue: AnalysisViewModel(classifier: dependencies.classifier))
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onAnalyze: { selection.begin(title: "Analisar imagem") })
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .imageSelection(selection)
        .onChange(of: selection.completion) { _, completion in
            guard let completion else { return }
            switch completion.outcome {
            case .image(let image): analysis.select(image)
            case .invalidImage: analysis.selectionFailed()
            }
            // Nova imagem: as respostas anteriores não valem para outra lesão.
            guidance.reset()
            path = [.preview]
        }
    }

    /// Executa a análise iniciada na Prévia e abre o Resultado quando ela termina.
    /// A navegação é explícita: não depende de a interface observar o estado intermediário
    /// `processing`, que pode nem ser renderizado quando a inferência é muito rápida.
    private func analyzeAndShowResult() async {
        await analysis.analyze()
        if analysis.state.hasFinishedAnalysis, path.last != .result {
            path.append(.result)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .preview:
            PreviewView(
                analysis: analysis,
                onAnalyze: { Task { await analyzeAndShowResult() } },
                onChooseAnother: { selection.begin(title: "Escolher outra imagem") }
            )
        case .result:
            ResultView(analysis: analysis, guidance: guidance, onAnalyzeAnother: {
                selection.begin(title: "Analisar outra imagem")
            })
        case .about:
            AboutView()
        }
    }
}

#Preview {
    RootView(dependencies: .preview)
}
