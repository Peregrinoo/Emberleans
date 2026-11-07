"""Utilitários compartilhados: classes, transformações, modelo, dispositivo e dataset."""
import csv
import json
import random
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torch import nn
from torch.utils.data import Dataset
from torchvision import models, transforms

ROOT = Path(__file__).resolve().parents[1]
CLASSES = ["Abrasion", "Bruise", "Burn", "Laceration", "Normal Skin"]

# Parâmetros compatíveis com MobileNet_V3_Small_Weights.IMAGENET1K_V1 (torchvision)
PREPROCESS = {
    "input_size": 224,
    "resize": 256,
    "mean": [0.485, 0.456, 0.406],
    "std": [0.229, 0.224, 0.225],
    "interpolation": "bilinear",
    "color": "RGB",
}
IMAGENET_WEIGHTS_FILE = "mobilenet_v3_small-047dcff4.pth"


def seed_everything(seed: int = 42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


def get_device() -> torch.device:
    if torch.backends.mps.is_available():
        return torch.device("mps")
    if torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")


def eval_transform(p=PREPROCESS):
    return transforms.Compose([
        transforms.Resize(p["resize"]),
        transforms.CenterCrop(p["input_size"]),
        transforms.ToTensor(),
        transforms.Normalize(p["mean"], p["std"]),
    ])


def train_transform(p=PREPROCESS):
    # Augmentation geométrica/fotométrica leve, aplicada on-the-fly.
    # Sem alteração de matiz: cor é informativa para queimadura/hematoma.
    return transforms.Compose([
        transforms.RandomResizedCrop(p["input_size"], scale=(0.6, 1.0), ratio=(0.8, 1.25)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.1),
        transforms.ToTensor(),
        transforms.Normalize(p["mean"], p["std"]),
    ])


def denormalize(t: torch.Tensor, p=PREPROCESS) -> np.ndarray:
    m = torch.tensor(p["mean"]).view(3, 1, 1)
    s = torch.tensor(p["std"]).view(3, 1, 1)
    x = (t.cpu() * s + m).clamp(0, 1)
    return (x.permute(1, 2, 0).numpy() * 255).astype(np.uint8)


def build_model(num_classes=len(CLASSES), imagenet_weights: Path | None = None) -> nn.Module:
    """MobileNetV3 Small com pesos ImageNet e classificador para `num_classes`."""
    model = models.mobilenet_v3_small(weights=None)
    if imagenet_weights is not None:
        if Path(imagenet_weights).exists():
            sd = torch.load(imagenet_weights, map_location="cpu", weights_only=True)
            model.load_state_dict(sd)
        else:  # download oficial pelo torchvision
            w = models.MobileNet_V3_Small_Weights.IMAGENET1K_V1
            model = models.mobilenet_v3_small(weights=w)
    in_f = model.classifier[3].in_features
    model.classifier[3] = nn.Linear(in_f, num_classes)
    return model


def load_config(model_dir: Path | None = None) -> dict:
    """Lê model_config.json do diretório do modelo ou, se ausente, de ml/configs/."""
    for p in ([Path(model_dir) / "model_config.json"] if model_dir else []) + [ROOT / "configs" / "model_config.json"]:
        if p.exists():
            return json.loads(p.read_text())
    raise FileNotFoundError("model_config.json não encontrado")


def load_trained(model_dir: Path, device="cpu"):
    model_dir = Path(model_dir)
    meta = load_config(model_dir)
    model = build_model(len(meta["classes"]))
    sd = torch.load(model_dir / "best_model.pt", map_location="cpu", weights_only=True)
    model.load_state_dict(sd)
    model.to(device).eval()
    return model, meta


class SplitDataset(Dataset):
    """Lê dataset/splits.csv (colunas: path, label, split, ...)."""

    def __init__(self, csv_path, split, transform, root=None):
        root = Path(root or ROOT / "dataset" / "raw")
        with open(csv_path) as fh:
            rows = [r for r in csv.DictReader(fh) if r["split"] == split]
        self.items = [(root / r["path"], CLASSES.index(r["label"])) for r in rows]
        self.rows = rows
        self.transform = transform

    def __len__(self):
        return len(self.items)

    def __getitem__(self, i):
        path, y = self.items[i]
        with Image.open(path) as im:
            x = self.transform(im.convert("RGB"))
        return x, y, i
