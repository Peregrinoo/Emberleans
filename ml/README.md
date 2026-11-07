# EmberLens · ml/

Pipeline de Machine Learning do EmberLens: inspeção do dataset, divisão sem vazamento, treino da MobileNetV3 Small,
avaliação, Grad-CAM, inferência e exportação para Core ML. Todos os comandos abaixo são executados **a partir de
`ml/`**.

> Prova de conceito experimental. Não é um dispositivo médico e não faz diagnóstico.

## Conteúdo

```
ml/
├── requirements.txt            # ambiente de treino/avaliação
├── requirements-coreml.txt     # ambiente de conversão Core ML (torch 2.7 + coremltools 9.0)
├── src/
│   ├── common.py               # classes, pré-processamento, construção do modelo, dataset
│   ├── download_dataset.py     # Roboflow (ROBOFLOW_API_KEY) + pesos ImageNet
│   ├── inspect_dataset.py      # corrompidas, duplicatas, nomes de origem, vazamento
│   ├── build_splits.py         # agrupamento de imagens relacionadas + split 70/15/15
│   ├── train.py                # fase head / fase finetune, early stopping, checkpoint
│   ├── evaluate.py             # métricas, matriz de confusão, curvas (teste roda 1 vez)
│   ├── gradcam.py              # Grad-CAM (última camada convolucional)
│   ├── report.py               # galeria HTML com scores e Grad-CAM
│   ├── predict.py              # classificar uma imagem individual
│   ├── export_coreml.py        # PyTorch -> EmberLens.mlpackage
│   ├── validate_conversion.py  # verificações da conversão (Linux/WSL/macOS)
│   └── validate_coreml_macos.py# equivalência numérica com o runtime Core ML (macOS)
├── configs/
│   ├── model_config.json       # arquitetura, classes, pré-processamento, hiperparâmetros, fases
│   ├── class_mapping.json      # {"Abrasion":0, "Bruise":1, "Burn":2, "Laceration":3, "Normal Skin":4}
│   └── preprocessing.json      # resize 256 -> center crop 224 -> normalização ImageNet
├── models/
│   ├── best_model.pt           # state_dict final (Git LFS)
│   └── runs/{head,finetune_last4,finetune_last8}/   # histórico, métricas de validação e logs
├── exports/
│   ├── EmberLens.mlpackage     # modelo Core ML, FP16, iOS 15+ (Git LFS)
│   └── conversion_validation_linux.json
├── dataset/
│   ├── splits.csv              # divisão usada (caminho, rótulo, split, grupo)
│   ├── splits_summary.json
│   ├── inspection/             # relatórios da inspeção (sem imagens)
│   └── raw/                    # imagens do Roboflow: NÃO versionadas (.gitignore)
└── reports/
    ├── training_curves.png
    ├── val/   test/            # metrics.json, classification_report.txt, predictions.csv, confusion_matrix.png
    └── */gallery*.html         # geradas localmente; não versionadas (contêm imagens do dataset)
```

## Ambientes

```bash
# treino / avaliação (macOS usa MPS automaticamente)
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# conversão Core ML (WSL2 Ubuntu ou macOS; coremltools não tem wheels para Windows)
python3.12 -m venv .venv-coreml && source .venv-coreml/bin/activate
pip install -r requirements-coreml.txt
```

## Reproduzir

```bash
# 1. dados: export "Folder Structure" v1 do Roboflow em dataset/raw/ (train/ valid/ test/)
export ROBOFLOW_API_KEY=...            # não grave a chave em arquivo
python src/download_dataset.py

# 2. inspeção e divisão sem vazamento (determinística, seed 42)
python src/inspect_dataset.py
python src/build_splits.py

# 3. treino: classificador -> fine-tuning parcial dos últimos 4 blocos
python src/train.py --phase head --out models/runs/head
python src/train.py --phase finetune --init models/runs/head/best_model.pt \
    --unfreeze-blocks 4 --out models/runs/finetune_last4
cp models/runs/finetune_last4/best_model.pt models/best_model.pt

# 4. avaliação (validação livre; teste uma única vez: reports/test/.EVALUATED)
python src/evaluate.py --split val  --histories models/runs/head/history.json models/runs/finetune_last4/history.json
python src/evaluate.py --split test --histories models/runs/head/history.json models/runs/finetune_last4/history.json
python src/report.py --split test      # reports/test/gallery.html

# 5. imagem individual
python src/predict.py foto.jpg --cam foto_gradcam.jpg

# 6. Core ML (ambiente requirements-coreml.txt)
python src/export_coreml.py            # exports/EmberLens.mlpackage
python src/validate_conversion.py      # exports/conversion_validation_linux.json
python src/validate_coreml_macos.py    # somente macOS
```

`configs/model_config.json` é o `model_config.json` da execução escolhida (`finetune_last4`), com as três execuções
candidatas resumidas em `training_phases` / `candidates_on_val`.

A metodologia e os resultados estão em [`../docs/`](../docs/).
