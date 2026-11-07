"""Baixa o Basic Wound Classify (v1, formato folder) pelo SDK oficial do Roboflow
e os pesos ImageNet da MobileNetV3 Small (torchvision).

Requer a variável de ambiente ROBOFLOW_API_KEY:
    export ROBOFLOW_API_KEY=...
    python src/download_dataset.py

Alternativa manual: baixe o zip "Folder Structure" em
https://universe.roboflow.com/mahrukh-qmtw8/basic-wound-classify-mpoys-rlpoq/dataset/1
e extraia em dataset/raw/ (pastas train/ valid/ test/).
"""
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    raw = ROOT / "dataset" / "raw"
    if not (raw / "train").exists():
        key = os.environ.get("ROBOFLOW_API_KEY")
        if not key:
            sys.exit("Defina ROBOFLOW_API_KEY (export ROBOFLOW_API_KEY=...) ou extraia o zip manualmente em dataset/raw/")
        from roboflow import Roboflow
        rf = Roboflow(api_key=key)
        proj = rf.workspace("mahrukh-qmtw8").project("basic-wound-classify-mpoys-rlpoq")
        ds = proj.version(1).download("folder", location=str(ROOT / "dataset" / "_download"))
        shutil.move(ds.location, raw)
    print("dataset em", raw)

    wfile = ROOT / "models" / "mobilenet_v3_small-047dcff4.pth"
    if not wfile.exists():
        import torch
        wfile.parent.mkdir(exist_ok=True)
        torch.hub.download_url_to_file(
            "https://download.pytorch.org/models/mobilenet_v3_small-047dcff4.pth", str(wfile), hash_prefix="047dcff4")
    print("pesos ImageNet em", wfile)


if __name__ == "__main__":
    main()
