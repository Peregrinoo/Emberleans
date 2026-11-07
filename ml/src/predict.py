"""Classifica uma imagem individual e (opcional) salva o Grad-CAM.

Uso:
    python src/predict.py caminho/da/imagem.jpg
    python src/predict.py caminho/da/imagem.jpg --cam saida_gradcam.jpg

Resultado experimental — não é diagnóstico médico.
"""
import argparse
import sys
from pathlib import Path

import torch
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, denormalize, eval_transform, load_trained  # noqa: E402
from gradcam import GradCAM, overlay  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--model-dir", default=str(ROOT / "models"))
    ap.add_argument("--cam", default=None, help="caminho para salvar a sobreposição Grad-CAM")
    args = ap.parse_args()

    model, meta = load_trained(args.model_dir, "cpu")
    with Image.open(args.image) as im:
        x = eval_transform(meta["preprocess"])(im.convert("RGB")).unsqueeze(0)
    if args.cam:
        cam, probs, idx = GradCAM(model)(x)
        overlay(denormalize(x[0]), cam).save(args.cam)
    else:
        with torch.no_grad():
            probs = torch.softmax(model(x), 1)[0].numpy()
        idx = int(probs.argmax())
    classes = meta["classes"]
    print(f"Classe prevista: {classes[idx]} ({probs[idx]*100:.1f}%)")
    for c, p in sorted(zip(classes, probs), key=lambda t: -t[1]):
        print(f"  {c:<12} {p*100:6.2f}%  {'█' * int(p * 40)}")
    if args.cam:
        print(f"Grad-CAM salvo em {args.cam}")
    print("Aviso: saída de um modelo experimental, não é diagnóstico médico.")


if __name__ == "__main__":
    main()
