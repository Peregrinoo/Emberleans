# EmberLens

**On-device skin lesion image classification using MobileNetV3, PyTorch and Apple Core ML.**

EmberLens é uma prova de conceito de visão computacional que classifica fotografias de pele em cinco categorias
(**Burn**, **Abrasion**, **Bruise**, **Laceration** e **Normal Skin**) com uma MobileNetV3 Small treinada por
transfer learning em PyTorch e exportada para Core ML. O modelo foi preparado para execução local num futuro app
iOS em SwiftUI.

> ⚠️ **EmberLens não é um dispositivo médico e não é uma ferramenta de diagnóstico.** É um projeto experimental e
> educacional, treinado com cerca de 1.100 fotos distintas coletadas da web e com rótulos sem verificação clínica.
> Suas saídas não devem orientar decisões de saúde.

## Objetivo

Verificar experimentalmente se uma rede leve, adequada para dispositivos móveis, consegue distinguir características
visuais de queimaduras e de outras lesões de pele, e deixar o pipeline completo reproduzível do dataset ao modelo
on-device: inspeção dos dados, treino, avaliação, interpretabilidade e conversão.

## Tecnologias

| área | ferramentas |
|---|---|
| treino e avaliação | Python 3.12, PyTorch 2.14, torchvision, scikit-learn, matplotlib |
| interpretabilidade | Grad-CAM (implementação própria com hooks) |
| conversão | coremltools 9.0, PyTorch 2.7 (TorchScript → ML Program) |
| on-device (próxima etapa) | Core ML, Vision, SwiftUI, iOS 15+ |

## Arquitetura

`torchvision.models.mobilenet_v3_small` com pesos ImageNet (`IMAGENET1K_V1`) e o último layer substituído por
`Linear(1024, 5)`, totalizando 1,52 M de parâmetros. O treino ocorreu em duas fases: primeiro só o classificador, com
o backbone congelado; depois o fine-tuning parcial dos últimos 4 blocos de `features`, com LR menor. O checkpoint foi
escolhido pelo macro F1 de validação, com early stopping.

## Dataset e procedência

[Basic Wound Classify](https://universe.roboflow.com/mahrukh-qmtw8/basic-wound-classify-mpoys-rlpoq/dataset/1)
(Roboflow Universe, v1), licença **CC BY 4.0**, com 1.515 arquivos em cinco classes. As imagens foram coletadas da web
pelo autor do dataset e incluem fotos de banco de imagens e capturas de vídeo. **As imagens não são redistribuídas
neste repositório.** Para reproduzir o treino, baixe o export em `ml/dataset/raw/`.

A inspeção encontrou problemas que mudaram a forma de avaliar o modelo:

* **Duplicatas:** 225 grupos de cópias quase idênticas (366 cópias extras), entre reexportações, espelhamentos,
  rotações, recortes e alterações de cor, concentrados em Burn.
* **Vazamento:** 105 desses grupos (295 imagens) tinham cópias em mais de um split original (train/valid/test). O
  split foi **refeito em 70/15/15 por grupo**, estratificado por classe. Nenhum grupo atravessa splits, e na validação
  e no teste cada foto conta uma vez.
* **Rotulagem:** a mesma foto aparece como Abrasion e como Laceration (6 imagens removidas), e 15 imagens não tinham
  rótulo.

Resultado: **1.421 imagens usadas**, estimadas em **1.131 fotos distintas**. Detalhes em
[`docs/methodology.md`](docs/methodology.md).

| classe | treino | validação | teste |
|---|---|---|---|
| Abrasion | 75 | 15 | 15 |
| Bruise | 137 | 30 | 29 |
| Burn | 280 (94 fotos distintas) | 24 | 25 |
| Laceration | 137 | 30 | 29 |
| Normal Skin | 417 | 89 | 89 |

## Pipeline de treinamento

```
inspect_dataset → build_splits → train (head) → train (finetune últimos 4 blocos)
→ evaluate (val; test uma única vez) → report (galeria + Grad-CAM) → export_coreml → validate_conversion
```

O pré-processamento é o padrão dos pesos ImageNet: `Resize(256) → CenterCrop(224) → Normalize`. No treino há
augmentation on-the-fly (crop aleatório, flip, rotação ±15°, jitter leve, sem alterar o matiz). A loss é
cross-entropy com pesos por classe e label smoothing 0,05, com otimizador AdamW e cosine LR.

## Metodologia de avaliação

As escolhas de modelo usaram apenas a validação. O teste independente foi avaliado **uma única vez**, ao final, e há
um bloqueio no script contra reavaliações. As métricas reportadas são accuracy, precision/recall/F1 por classe, macro
F1, recall de Burn, matriz de confusão e intervalos de confiança de 95% por bootstrap.

## Resultados

Modelo PyTorch FP32 (`ml/models/best_model.pt`):

| métrica | validação (n = 188) | **teste (n = 187)** | IC 95% teste |
|---|---|---|---|
| accuracy | 0,872 | **0,840** | 0,79 – 0,89 |
| macro F1 | 0,808 | **0,767** | 0,69 – 0,83 |
| recall Burn | 0,750 | **0,680** (17/25) | 0,48 – 0,86 |

<p>
  <img src="ml/reports/test/confusion_matrix.png" alt="Matriz de confusão do teste" width="420">
</p>

![Curvas de treinamento](ml/reports/training_curves.png)

Principais erros: queimaduras graves classificadas como Abrasion ou Laceration, confusão entre Abrasion e
Laceration, e hematomas classificados como Burn. O **Grad-CAM revelou atalhos visuais**: em capturas de vídeo de
Burn, a ativação fica na barra preta do player, e há casos influenciados por uma sombra ou por uma marca d'água.
Análise completa em [`docs/model-evaluation.md`](docs/model-evaluation.md).

## Conversão para Core ML

`ml/exports/EmberLens.mlpackage`: ML Program, **FP16**, **iOS 15+**, **3,15 MB**. A entrada é uma imagem RGB
256 × 256, e o recorte central 224 × 224 e a normalização ImageNet estão incorporados ao modelo. As saídas são
`classLabel` e `classLabel_probs`. No app, o Vision com `.centerCrop` fornece a entrada esperada.

As verificações executadas em Linux passaram: arquitetura, carregamento estrito, ordem das classes,
pré-processamento (Δ = 0), PyTorch vs TorchScript (Δ = 0) e estrutura do `.mlpackage`. **A inferência com o runtime
do Core ML ainda não foi executada**, porque exige macOS, e por isso a equivalência numérica PyTorch ↔ Core ML ainda
não está declarada. Detalhes e passos pendentes em [`docs/coreml-conversion.md`](docs/coreml-conversion.md).

## Estrutura do repositório

```
emberlens/
├── README.md · LICENSE · .gitignore · .gitattributes
├── ml/
│   ├── README.md                      # comandos do pipeline
│   ├── requirements.txt               # treino/avaliação
│   ├── requirements-coreml.txt        # conversão (torch 2.7 + coremltools 9.0)
│   ├── src/                           # dataset, treino, avaliação, Grad-CAM, inferência, Core ML
│   ├── configs/                       # model_config, class_mapping, preprocessing
│   ├── models/                        # best_model.pt (LFS) + runs/ (históricos e logs)
│   ├── exports/                       # EmberLens.mlpackage (LFS) + relatório de validação
│   ├── dataset/                       # splits.csv e relatórios de inspeção (sem imagens)
│   └── reports/                       # métricas, matrizes de confusão, curvas, predições
├── docs/
│   ├── methodology.md
│   ├── model-evaluation.md
│   └── coreml-conversion.md
└── ios/
    └── README.md                      # plano de integração SwiftUI (sem código ainda)
```

## Reprodução

```bash
git clone https://github.com/<usuario>/emberlens.git && cd emberlens
git lfs pull                                   # baixa best_model.pt e EmberLens.mlpackage
cd ml
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

python src/predict.py foto.jpg --cam foto_gradcam.jpg        # inferência com o modelo treinado
```

Treino, avaliação e conversão completos estão em [`ml/README.md`](ml/README.md). No Windows, a conversão para Core ML
deve ser feita via WSL2, como descrito em [`docs/coreml-conversion.md`](docs/coreml-conversion.md#executar-a-conversão-no-windows).

## Limitações conhecidas

* Dataset pequeno: 94 fotos distintas de Burn no treino e 25 no teste, o que gera intervalos de confiança largos.
* A accuracy é inflada por Normal Skin, que tem 48% do teste e é composta de close-ups de textura.
* Imagens da web com vieses de enquadramento, marcas d'água e capturas de vídeo; o modelo aprendeu parte desses
  atalhos.
* Rótulos sem verificação clínica, sem grau de queimadura, e com ambiguidade entre Abrasion e Laceration.
* Generalização para fotos reais de câmera de iPhone **não medida**.
* Nenhuma validação clínica. Não é dispositivo médico.
* Equivalência PyTorch ↔ Core ML ainda não medida no runtime nativo (macOS).

## Próximos passos (SwiftUI)

1. Rodar `ml/src/validate_coreml_macos.py` num Mac e registrar a equivalência numérica.
2. Criar o app SwiftUI em `ios/` com Vision + Core ML (`.centerCrop`, orientação EXIF), exibindo as cinco
   probabilidades e um aviso de uso experimental.
3. Medir latência no dispositivo e comparar Neural Engine e CPU.
4. Em paralelo, ampliar o dataset de queimaduras com fotos distintas e avaliar com um conjunto externo.

Plano detalhado em [`ios/README.md`](ios/README.md).

## Publicação dos artefatos

`ml/models/best_model.pt` (6,2 MB) e `ml/exports/EmberLens.mlpackage` (3,1 MB) são rastreados por **Git LFS**
(`.gitattributes`). Se o LFS não estiver disponível, publique os dois como anexos de um **GitHub Release**
(ex.: `v1.0.0-ml`) e registre o SHA-256 de cada arquivo nas notas.

## Licença e atribuição

Código e documentação: [MIT](LICENSE). O dataset *Basic Wound Classify*, de Mahrukh (Roboflow Universe), é licenciado
sob CC BY 4.0 e não é redistribuído aqui. Os pesos iniciais são os da MobileNetV3 Small ImageNet do torchvision.
