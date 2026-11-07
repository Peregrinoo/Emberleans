# Metodologia

## Objetivo

Verificar experimentalmente se uma rede leve, adequada para execução on-device (MobileNetV3 Small), consegue
distinguir características visuais de queimaduras e de outras lesões de pele em fotografias. O trabalho é de caráter
exploratório e educacional.

## Dataset

**Basic Wound Classify** (Roboflow Universe, workspace `mahrukh-qmtw8`, projeto `basic-wound-classify-mpoys-rlpoq`,
versão 1, export *Folder Structure*), licença **CC BY 4.0**. Cinco classes: Abrasion, Bruise, Burn, Laceration e
Normal Skin. O export contém 1.515 arquivos divididos pelo Roboflow em train/valid/test, além de uma pasta
`Unlabeled`.

As imagens foram coletadas da web pelo autor do dataset (há fotos de banco de imagens com marca d'água e capturas de
tela de vídeo) e os rótulos **não têm verificação clínica**. Por isso as imagens não são redistribuídas neste
repositório.

## Inspeção (`inspect_dataset.py`, `build_splits.py`)

| verificação | resultado |
|---|---|
| imagens corrompidas ou ilegíveis | 0 |
| sem rótulo (`Unlabeled`) | 15 (removidas) |
| cópias exatas em pixels | 0 |
| grupos de cópias quase idênticas | 225 grupos, 366 cópias extras |
| grupos com cópias em mais de um split original | 105 grupos (295 imagens) |
| conflito de rótulo (mesma foto em duas classes) | 6 imagens (removidas) |

As cópias são reexportações do mesmo arquivo de origem (`nome_jpg.rf.<hash>`) e versões espelhadas, rotacionadas,
recortadas ou com cor alterada, concentradas em Burn. O README do export afirma que não houve augmentation, mas a
inspeção visual mostra o contrário. Os conflitos de rótulo envolvem a mesma foto de incisão marcada como Abrasion e
como Laceration.

### Detecção de imagens relacionadas

As imagens são ligadas num grafo e os componentes conexos formam a unidade de divisão:

1. **mesmo arquivo de origem** e visualmente relacionadas (similaridade ≥ 0,80). Nomes genéricos como `133_jpg`
   correspondem a fotos diferentes e não bastam sozinhos;
2. **correlação de miniatura** 32×32 em tons de cinza ≥ 0,97, com o máximo entre as 8 rotações/espelhamentos;
3. **similaridade de cosseno** entre embeddings ImageNet da própria MobileNetV3 Small (sem fine-tuning) ≥ 0,82,
   calculada depois de remover barras pretas.

Pares de Normal Skin, que são texturas de pele quase uniformes, usam limiares mais estritos (0,99 / 0,98) para evitar
encadear fotos diferentes. Todos os limiares foram calibrados por inspeção visual de pares. Conflitos entre classes
usam um critério estrito (miniatura ≥ 0,97 ou embedding ≥ 0,92) e removem todas as cópias da foto envolvida.

### Divisão

O split original **não foi preservado**, por causa do vazamento. A nova divisão é 70/15/15 por grupo, estratificada
pela classe, com seed 42. Na validação e no teste, cada foto quase idêntica aparece uma única vez. No treino, as cópias
são mantidas e funcionam como augmentation adicional. Após a divisão, **nenhum grupo atravessa splits**. Rodar o
script de novo produz um `splits.csv` idêntico.

| classe | treino (imagens / fotos distintas) | validação | teste | total |
|---|---|---|---|---|
| Abrasion | 75 / 48 | 15 | 15 | 105 |
| Bruise | 137 / 131 | 30 | 29 | 196 |
| Burn | 280 / 94 | 24 | 25 | 329 |
| Laceration | 137 / 117 | 30 | 29 | 196 |
| Normal Skin | 417 / 366 | 89 | 89 | 595 |
| **total** | **1.046** | **188** | **187** | **1.421** (≈ 1.131 fotos distintas) |

## Modelo

* `torchvision.models.mobilenet_v3_small`, pesos `IMAGENET1K_V1` (`mobilenet_v3_small-047dcff4.pth`).
* Último layer substituído: `classifier[3] = Linear(1024, 5)`. São 1.522.981 parâmetros no total.
* Ordem das classes (índices de saída): `0 Abrasion, 1 Bruise, 2 Burn, 3 Laceration, 4 Normal Skin`.

## Pré-processamento

| etapa | avaliação / inferência | treino |
|---|---|---|
| geometria | `Resize(256)` (lado menor, bilinear, antialias) → `CenterCrop(224)` | `RandomResizedCrop(224, scale 0,6–1,0, ratio 0,8–1,25)`, flip horizontal, rotação ±15° |
| cor | — | `ColorJitter(brilho 0,15, contraste 0,15, saturação 0,1)`, sem alterar matiz |
| tensor | RGB, valores em [0, 1] | idem |
| normalização | média (0,485; 0,456; 0,406), desvio (0,229; 0,224; 0,225) | idem |

A augmentation é aplicada on-the-fly. Nenhuma imagem sintética foi adicionada ao dataset.

## Treinamento

* Loss: cross-entropy com pesos inversamente proporcionais à frequência da classe e label smoothing 0,05.
* Otimizador AdamW (weight decay 1e-4), cosine annealing, batch 32, seed 42.
* Seleção de checkpoint pelo **macro F1 de validação**; early stopping com paciência de 7 épocas.

| execução | parte treinável | parâmetros treináveis | LR | épocas (melhor) | val macro F1 |
|---|---|---|---|---|---|
| `head` | só o classificador | 595.973 | 1e-3 | 16 (9) | 0,768 |
| **`finetune_last4`** ✅ | classificador + últimos 4 blocos de `features` | 1.332.461 | 2e-4 | 10 (3) | **0,808** |
| `finetune_last8` | classificador + últimos 8 blocos | 1.498.757 | 1e-4 | 9 (2) | 0,783 |

Com o backbone congelado, a accuracy de treino chegou a ~99% e a validação estabilizou. O fine-tuning parcial reduziu
a loss de validação de 0,50 para 0,43 e elevou o macro F1. As durações foram de 1,9 min, 1,8 min e 2,2 min em CPU de
2 núcleos (PyTorch 2.14.1). Os históricos estão em `ml/models/runs/`.

## Avaliação

* Escolhas de modelo e hiperparâmetros feitas **somente com a validação**.
* Teste avaliado uma única vez, ao final (`ml/reports/test/.EVALUATED` bloqueia reavaliações).
* Métricas: accuracy, precision/recall/F1 por classe, macro F1, recall de Burn, matriz de confusão e intervalos de
  confiança de 95% por bootstrap (2.000 reamostragens).
* Interpretabilidade: Grad-CAM na última camada convolucional (`features[-1]`).

Resultados em [`model-evaluation.md`](model-evaluation.md).
