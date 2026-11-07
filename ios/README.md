# EmberLens · ios/

Esta pasta receberá o aplicativo **SwiftUI** do EmberLens. Ainda **não há código iOS**: este documento registra o
contrato do modelo e o plano de integração.

## Modelo a integrar

`../ml/exports/EmberLens.mlpackage` (Core ML ML Program, FP16, iOS 15+, 3,15 MB). Ao ser adicionado a um target do
Xcode, gera a classe Swift `EmberLens`.

| | |
|---|---|
| entrada | `image`: `CVPixelBuffer` RGB 256 × 256 |
| saída `classLabel` | `String`: classe mais provável |
| saída `classLabel_probs` | `[String: Double]`: probabilidade por classe |
| classes | `Abrasion`, `Bruise`, `Burn`, `Laceration`, `Normal Skin` |

O recorte central 224 × 224 e a normalização ImageNet já estão **dentro** do modelo. O app só precisa entregar a
imagem redimensionada pelo lado menor para 256 e recortada no centro em 256 × 256. Detalhes em
[`../docs/coreml-conversion.md`](../docs/coreml-conversion.md).

## Plano de integração

1. **Projeto Xcode.** Criar o app SwiftUI nesta pasta (`ios/EmberLens/`), com deployment target iOS 15 ou superior, e
   adicionar `EmberLens.mlpackage` ao target.
2. **Validação prévia no Mac.** Antes de escrever a UI, rodar `ml/src/validate_coreml_macos.py` e confirmar a
   equivalência numérica com o PyTorch.
3. **Inferência.** Usar Vision (`VNCoreMLModel` + `VNCoreMLRequest`) com
   `imageCropAndScaleOption = .centerCrop`, passando a orientação correta da imagem (`CGImagePropertyOrientation`) e
   lendo `VNClassificationObservation` para as 5 classes. Executar fora da main thread.
4. **Entrada de imagem.** Usar `PhotosPicker` (iOS 16+) ou `PHPickerViewController` (iOS 15), além da câmera. Tratar
   a orientação EXIF.
5. **Apresentação.** Mostrar as cinco probabilidades, não apenas a classe vencedora, e um aviso permanente de que o
   resultado é experimental e **não é diagnóstico**. Não usar linguagem clínica (ex.: "você tem uma queimadura").
6. **Verificações no dispositivo.** Medir a latência (Xcode *Performance* report / Instruments), comparar `ALL` e
   `CPU_ONLY`, e conferir que o resultado no app para algumas imagens de validação coincide com o do script de
   macOS. Isso detecta diferenças no interpolador do Vision e na orientação.
7. **Privacidade.** Toda a inferência é on-device. Não enviar imagens para servidores e declarar o uso de câmera e
   fotos no `Info.plist`.

## Fora do escopo atual

Interface, câmera, histórico, exportação de resultados e qualquer funcionalidade mobile ainda não foram
implementados.
