"""Validação numérica do EmberLens.mlpackage com o runtime nativo do Core ML (somente macOS).

Compara as probabilidades do Core ML com as do PyTorch (FP32) nas imagens de
VALIDAÇÃO e mede latência. Não usa o conjunto de teste.

Referência PyTorch:
  - se torch/torchvision estiverem instalados, recalcula com best_model.pt;
  - senão, usa reports/val/predictions.csv (probabilidades com 4 casas decimais).

A entrada do Core ML é gerada com PIL (resize lado menor 256 + center crop 256),
igual ao pipeline de treino. No app, o Vision fará esse passo com outro
interpolador; essa diferença deve ser verificada depois, no próprio app.

Uso (macOS 12+, Python 3.10–3.12):
    pip install -r requirements-coreml.txt
    python src/validate_coreml_macos.py
    python src/validate_coreml_macos.py --compute-units CPU_ONLY
Saída: exports/coreml_validation_macos_<compute_units>.json
"""
import argparse
import csv
import json
import platform
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CLASSES = ["Abrasion", "Bruise", "Burn", "Laceration", "Normal Skin"]


def app_input(img: Image.Image, size=256) -> Image.Image:
    # mesma regra do torchvision.transforms.Resize(256): lado menor = 256, lado maior truncado
    w, h = img.size
    if w <= h:
        nw, nh = size, int(size * h / w)
    else:
        nw, nh = int(size * w / h), size
    img = img.resize((nw, nh), Image.BILINEAR)
    w, h = img.size
    left, top = int(round((w - size) / 2.0)), int(round((h - size) / 2.0))
    return img.crop((left, top, left + size, top + size))


def macro_f1(y, p, k=len(CLASSES)):
    f = []
    for c in range(k):
        tp = ((p == c) & (y == c)).sum()
        fp = ((p == c) & (y != c)).sum()
        fn = ((p != c) & (y == c)).sum()
        f.append(0.0 if tp == 0 else 2 * tp / (2 * tp + fp + fn))
    return float(np.mean(f))


def main():
    if sys.platform != "darwin":
        sys.exit("Este script exige macOS (runtime do Core ML). No Linux/Windows use src/validate_conversion.py.")
    ap = argparse.ArgumentParser()
    ap.add_argument("--mlpackage", default=str(ROOT / "exports" / "EmberLens.mlpackage"))
    ap.add_argument("--splits", default=str(ROOT / "dataset" / "splits.csv"))
    ap.add_argument("--raw", default=str(ROOT / "dataset" / "raw"))
    ap.add_argument("--compute-units", default="ALL", choices=["ALL", "CPU_ONLY", "CPU_AND_GPU", "CPU_AND_NE"])
    ap.add_argument("--tol-prob", type=float, default=0.05, help="tolerância de |Δprob| aceitável para FP16")
    args = ap.parse_args()

    import coremltools as ct
    model = ct.models.MLModel(args.mlpackage, compute_units=getattr(ct.ComputeUnit, args.compute_units))

    with open(args.splits) as fh:
        rows = [r for r in csv.DictReader(fh) if r["split"] == "val"]
    y = np.array([CLASSES.index(r["label"]) for r in rows])

    # referência PyTorch
    ref_source = "reports/val/predictions.csv"
    try:
        import torch
        sys.path.insert(0, str(ROOT / "src"))
        from common import eval_transform, load_trained
        net, meta = load_trained(ROOT / "models", "cpu")
        tf = eval_transform(meta["preprocess"])
        ref = []
        with torch.no_grad():
            for r in rows:
                with Image.open(Path(args.raw) / r["path"]) as im:
                    ref.append(torch.softmax(net(tf(im.convert("RGB")).unsqueeze(0)), 1)[0].numpy())
        P_ref = np.stack(ref)
        ref_source = f"PyTorch {torch.__version__} (best_model.pt, FP32)"
    except ImportError:
        with open(ROOT / "reports" / "val" / "predictions.csv") as fh:
            saved = {r["path"]: [float(r[f"p_{c}"]) for c in CLASSES] for r in csv.DictReader(fh)}
        P_ref = np.array([saved[r["path"]] for r in rows])

    P_cm, times, labels = [], [], []
    for r in rows:
        with Image.open(Path(args.raw) / r["path"]) as im:
            x = app_input(im.convert("RGB"))
        t = time.perf_counter()
        out = model.predict({"image": x})
        times.append(time.perf_counter() - t)
        probs = out["classLabel_probs"]
        P_cm.append([probs[c] for c in CLASSES])
        labels.append(out["classLabel"])
    P_cm = np.array(P_cm)

    d = np.abs(P_cm - P_ref)
    top1 = float((P_cm.argmax(1) == P_ref.argmax(1)).mean())
    label_consistent = all(lab == CLASSES[i] for lab, i in zip(labels, P_cm.argmax(1)))
    report = {
        "platform": platform.platform(), "machine": platform.machine(),
        "coremltools": ct.__version__, "compute_units": args.compute_units,
        "reference": ref_source, "split_used": "val", "n_images": len(rows),
        "max_abs_diff_prob": float(d.max()), "mean_abs_diff_prob": float(d.mean()),
        "top1_agreement_with_pytorch": top1,
        "classLabel_consistent_with_probs": label_consistent,
        "val_accuracy_coreml": float((P_cm.argmax(1) == y).mean()),
        "val_accuracy_pytorch": float((P_ref.argmax(1) == y).mean()),
        "val_macro_f1_coreml": macro_f1(y, P_cm.argmax(1)),
        "val_macro_f1_pytorch": macro_f1(y, P_ref.argmax(1)),
        "latency_ms_median": float(np.median(times[5:]) * 1000) if len(times) > 5 else None,
        "disagreements": [{"path": rows[i]["path"], "pytorch": CLASSES[P_ref[i].argmax()],
                           "coreml": CLASSES[P_cm[i].argmax()]}
                          for i in np.nonzero(P_cm.argmax(1) != P_ref.argmax(1))[0]],
    }
    report["passed"] = bool(d.max() <= args.tol_prob and top1 >= 0.98 and label_consistent)
    out = ROOT / "exports" / f"coreml_validation_macos_{args.compute_units.lower()}.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print(json.dumps(report, indent=2, ensure_ascii=False))
    sys.exit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
