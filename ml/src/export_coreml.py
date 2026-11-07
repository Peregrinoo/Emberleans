"""Converte a MobileNetV3 Small treinada (PyTorch) para Core ML: EmberLens.mlpackage.

O pré-processamento de avaliação usado no treinamento é

    Resize(256, lado menor, bilinear) -> CenterCrop(224) -> ToTensor ([0,1])
    -> Normalize(mean=ImageNet, std=ImageNet)

O modelo Core ML recebe uma imagem RGB de 256x256 e incorpora o restante:

    pixel/255 (ImageType.scale)  ->  recorte central 224x224  ->  (x-mean)/std
    -> MobileNetV3 Small  ->  softmax  ->  classifier (5 rótulos)

No iOS, o Vision com VNImageCropAndScaleOption.centerCrop redimensiona a imagem
pelo lado menor para 256 e recorta o centro em 256x256, o que, somado ao recorte
interno, equivale a Resize(256) + CenterCrop(224).

Uso (ambiente de conversão, ver ml/requirements-coreml.txt):
    python src/export_coreml.py
    python src/export_coreml.py --precision fp32   # variante FP32, para comparação
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CLASSES, ROOT, build_model, load_config  # noqa: E402

MODEL_INPUT_SIZE = 256  # tamanho da imagem recebida pelo Core ML (lado após o resize)


class EmberLensInference(nn.Module):
    """MobileNetV3 Small + pré-processamento de avaliação + softmax.

    Entrada: tensor 1x3x256x256 em [0, 1] (RGB). Saída: probabilidades 1x5.
    """

    def __init__(self, model: nn.Module, mean, std, resize: int, crop: int):
        super().__init__()
        self.model = model
        self.register_buffer("mean", torch.tensor(mean, dtype=torch.float32).view(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor(std, dtype=torch.float32).view(1, 3, 1, 1))
        self.off = (resize - crop) // 2
        self.crop = crop

    def forward(self, x):
        x = x[:, :, self.off:self.off + self.crop, self.off:self.off + self.crop]
        x = (x - self.mean) / self.std
        return torch.softmax(self.model(x), dim=1)


def load_inference_module(weights: Path, config: dict) -> EmberLensInference:
    p = config["preprocess"]
    assert config["classes"] == CLASSES, "ordem das classes diverge de common.CLASSES"
    model = build_model(len(config["classes"]))
    state = torch.load(weights, map_location="cpu", weights_only=True)
    model.load_state_dict(state, strict=True)  # falha se a arquitetura não corresponder
    wrapper = EmberLensInference(model, p["mean"], p["std"], p["resize"], p["input_size"])
    return wrapper.eval()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--weights", default=str(ROOT / "models" / "best_model.pt"))
    ap.add_argument("--config", default=str(ROOT / "configs" / "model_config.json"))
    ap.add_argument("--out", default=str(ROOT / "exports" / "EmberLens.mlpackage"))
    ap.add_argument("--precision", choices=["fp16", "fp32"], default="fp16")
    ap.add_argument("--version", default="1.0.0")
    args = ap.parse_args()

    import coremltools as ct

    config = json.loads(Path(args.config).read_text()) if args.config else load_config()
    p = config["preprocess"]
    assert p["resize"] == MODEL_INPUT_SIZE
    wrapper = load_inference_module(Path(args.weights), config)

    example = torch.rand(1, 3, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE)
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, example)
        diff = (traced(example) - wrapper(example)).abs().max().item()
    print(f"TorchScript vs PyTorch (entrada aleatória): max |Δ| = {diff:.2e}")

    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[ct.ImageType(name="image", shape=(1, 3, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE),
                             scale=1 / 255.0, bias=[0.0, 0.0, 0.0], color_layout=ct.colorlayout.RGB)],
        classifier_config=ct.ClassifierConfig(class_labels=config["classes"],
                                              predicted_feature_name="classLabel"),
        compute_precision=ct.precision.FLOAT16 if args.precision == "fp16" else ct.precision.FLOAT32,
        minimum_deployment_target=ct.target.iOS15,
    )

    # metadados
    mlmodel.short_description = ("EmberLens: classificação experimental de imagens de lesões de pele "
                                 "(Abrasion, Bruise, Burn, Laceration, Normal Skin). Prova de conceito; "
                                 "não é dispositivo médico nem ferramenta de diagnóstico.")
    mlmodel.author = "EmberLens"
    mlmodel.license = "Código: MIT. Dataset de treino: Basic Wound Classify (Roboflow Universe), CC BY 4.0."
    mlmodel.version = args.version
    mlmodel.input_description["image"] = (
        "Imagem RGB 256x256. Obtenha redimensionando pelo lado menor para 256 e recortando o centro "
        "(Vision: VNImageCropAndScaleOption.centerCrop). O modelo recorta 224x224 e normaliza internamente.")
    out_names = [o.name for o in mlmodel.get_spec().description.output]
    prob_name = [n for n in out_names if n != "classLabel"][0]
    mlmodel.output_description["classLabel"] = "Classe com maior probabilidade."
    mlmodel.output_description[prob_name] = "Probabilidade (softmax) de cada uma das 5 classes."
    md = mlmodel.user_defined_metadata
    md["classes"] = json.dumps(config["classes"])
    md["preprocessing"] = json.dumps({"input": "RGB 256x256 (resize lado menor 256 + center crop 256)",
                                      "in_model": "x/255 -> center crop 224 -> (x-mean)/std",
                                      "mean": p["mean"], "std": p["std"]})
    md["architecture"] = "torchvision mobilenet_v3_small, classifier[3]=Linear(1024,5)"
    md["source_weights_sha256"] = sha256(Path(args.weights))
    md["test_metrics"] = "accuracy=0.840, macro_f1=0.767, burn_recall=0.680 (n=187, PyTorch FP32)"
    md["disclaimer"] = "Experimental. Not a medical device. Not for diagnosis."
    md["precision"] = args.precision

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(out))
    size = sum(f.stat().st_size for f in out.rglob("*") if f.is_file())
    print(f"salvo: {out} ({size / 1e6:.2f} MB) | saídas: {out_names}")


if __name__ == "__main__":
    main()
