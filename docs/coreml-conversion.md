# Conversão para Core ML

Script: [`ml/src/export_coreml.py`](../ml/src/export_coreml.py) · Artefato: `ml/exports/EmberLens.mlpackage`

## Resultado

| item | valor |
|---|---|
| formato | ML Program (`.mlpackage`), opset `CoreML5` |
| precisão | FP16 (`compute_precision=FLOAT16`) |
| compatibilidade mínima | iOS 15 / macOS 12 (`minimum_deployment_target=iOS15`, specificationVersion 6) |
| tamanho | 3,15 MB (3.150.714 bytes); variante FP32 de referência: 6,17 MB, não versionada |
| entrada | `image`: imagem RGB 256 × 256 |
| saídas | `classLabel` (String) e `classLabel_probs` (Dictionary String → Double) |
| classes | `Abrasion`, `Bruise`, `Burn`, `Laceration`, `Normal Skin` (mesma ordem do treino) |
| origem | `ml/models/best_model.pt` (SHA-256 `9674c32117a88905…`, registrado nos metadados) |
| ferramentas | Python 3.12.16, torch 2.7.0, torchvision 0.22.0, coremltools 9.0 |

## Pré-processamento incorporado

O pré-processamento de avaliação do treinamento é:

```
Resize(256, lado menor, bilinear) → CenterCrop(224) → ToTensor [0,1] → Normalize(mean, std)
mean = (0.485, 0.456, 0.406)   std = (0.229, 0.224, 0.225)
```

Core ML aceita escala e bias por canal na `ImageType`, mas não divisão por desvio padrão diferente por canal. Por isso
o modelo exportado é um *wrapper* (`EmberLensInference`) que incorpora no grafo tudo o que vem depois do resize:

```
image (RGB 256×256, 0–255)
  → × 1/255                     (ImageType.scale)
  → recorte central 224×224     (slice_by_index, offset 16)
  → (x − mean) / std            (sub, mul)
  → MobileNetV3 Small → softmax → classify (5 rótulos)
```

**Contrato de entrada para o app:** redimensionar a imagem pelo **lado menor para 256** e recortar o **centro
256 × 256**. No Vision isso corresponde a `VNCoreMLRequest.imageCropAndScaleOption = .centerCrop`. Somado ao recorte
interno, o resultado é `Resize(256) + CenterCrop(224)`, como no treino.

Na validação abaixo, esse caminho reproduziu o pipeline de treino com diferença **exatamente 0** nas 188 imagens de
validação, executado em PyTorch. O interpolador do Vision é diferente do bilinear com antialias do PIL usado no
treino. O efeito disso não foi medido e precisa ser verificado no app.

## Validação executada (Linux, sem runtime Core ML)

`python src/validate_conversion.py` → [`ml/exports/conversion_validation_linux.json`](../ml/exports/conversion_validation_linux.json).
Conjunto de **validação** (n = 188); o teste não foi usado.

| verificação | resultado |
|---|---|
| arquitetura: chaves e formas do `state_dict` vs `mobilenet_v3_small` + `Linear(1024,5)` | ✅ 244 tensores, 0 divergências |
| carregamento estrito dos pesos | ✅ `strict=True`, 1.522.981 parâmetros, FP32 |
| ordem das classes (config, código, mapping) | ✅ |
| pré-processamento do treino vs entrada 256 + recorte/normalização no modelo | ✅ top-1 igual em 100%, max \|Δprob\| = 0 |
| PyTorch vs TorchScript (grafo convertido) | ✅ max \|Δprob\| = 0 |
| reprodução das probabilidades do treino (torch 2.14.1 → 2.7.0) | ✅ max \|Δprob\| = 4,97e-05 (CSV com 4 casas); accuracy val 0,8723 |
| Core ML: tipo e versão do spec | ✅ `mlProgram`, specificationVersion 6 (iOS 15) |
| Core ML: entrada | ✅ `image` 256 × 256 RGB |
| Core ML: saídas | ✅ `classLabel` (string), `classLabel_probs` (dicionário) |
| Core ML: rótulos do classificador na ordem do treino | ✅ |
| Core ML: pesos em FP16 | ✅ 185 constantes FLOAT16 |
| Core ML: pré-processamento no programa | ✅ `mul → cast → slice_by_index ×2 → sub → mul → conv…`; 52 conv, 1 softmax |

**Estimativa do efeito do FP16:** o modelo foi executado em `half` no PyTorch, em CPU. **Isso não é o Core ML** e
serve apenas como ordem de grandeza: max |Δprob| = 0,041 e top-1 igual em 99,5% (1 de 188 imagens mudou de classe).

### O que **não** foi verificado

A inferência com o runtime nativo do Core ML não foi executada: ele só existe no macOS, e o coremltools no Linux
roda sem `libcoremlpython`. **Portanto, a equivalência funcional entre PyTorch e o `EmberLens.mlpackage` não está
declarada.**

## Validação pendente no macOS

```bash
cd ml
python3.12 -m venv .venv-coreml && source .venv-coreml/bin/activate
pip install -r requirements-coreml.txt
# dataset/raw/ com o export do Roboflow é necessário (imagens de validação)
python src/validate_coreml_macos.py                       # compute units ALL
python src/validate_coreml_macos.py --compute-units CPU_ONLY
```

O script compara as probabilidades do Core ML com as do PyTorch FP32 nas 188 imagens de validação e registra:
max/média de |Δprob|, concordância top-1, coerência entre `classLabel` e as probabilidades, accuracy e macro F1 de
validação dos dois modelos, latência mediana e as imagens com predições divergentes. O critério de aprovação é
|Δprob| ≤ 0,05 e concordância top-1 ≥ 98%. A saída fica em `exports/coreml_validation_macos_<units>.json`.

Também falta verificar no macOS ou no iPhone:

* abrir o `.mlpackage` no Xcode (aba *Preview* / *Performance*) e confirmar a compilação para `.mlmodelc`;
* executar no Neural Engine (`ALL`) e em `CPU_ONLY`. Diferenças entre unidades de computação em FP16 são esperadas e
  devem ser medidas;
* verificar a orientação EXIF no app (`CGImagePropertyOrientation`) e o interpolador do Vision.

## Executar a conversão no Windows

O coremltools não publica wheels para Windows. Use WSL2 com Ubuntu:

```powershell
wsl --install -d Ubuntu          # PowerShell como administrador; reinicie se solicitado
```

```bash
# dentro do Ubuntu (WSL)
sudo apt update && sudo apt install -y python3.12 python3.12-venv git git-lfs
cd /mnt/c/Users/<usuario>/<caminho>/emberlens/ml   # ou clone dentro do WSL (~/), que é mais rápido
python3.12 -m venv .venv-coreml && source .venv-coreml/bin/activate
pip install -r requirements-coreml.txt
python src/export_coreml.py
python src/validate_conversion.py
```

Se o Ubuntu não tiver `python3.12`, instale-o pelo PPA `deadsnakes` ou use o micromamba
(`micromamba create -p ./.env-coreml -c conda-forge python=3.12 pytorch=2.7.0 torchvision=0.22`, seguido de
`pip install coremltools==9.0`). Foi esse o caminho usado neste experimento, em Linux.

## Reprodutibilidade

`export_coreml.py` é determinístico dado o mesmo `best_model.pt`, o `model_config.json` e as mesmas versões do
torch e do coremltools. Numa reexportação de verificação, `weight.bin` saiu idêntico byte a byte. `model.mlmodel`
teve descrição e programa ML idênticos, diferindo apenas na ordem de serialização do mapa de metadados do protobuf. O hash dos pesos de origem fica em `user_defined_metadata["source_weights_sha256"]` do modelo
exportado. Para gerar a variante FP32 de comparação, use
`python src/export_coreml.py --precision fp32 --out exports/EmberLens_fp32.mlpackage` (ignorada pelo Git).
