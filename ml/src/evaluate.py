"""Avalia um modelo treinado em val ou test e salva métricas, predições e gráficos.

O teste é protegido: só roda uma vez (cria reports/test/.EVALUATED).
Use --force apenas se souber o que está fazendo (invalida o teste como
estimativa independente).

Uso:
    python src/evaluate.py --model-dir models --split val
    python src/evaluate.py --model-dir models --split test
"""
import argparse
import csv
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import torch  # noqa: E402
from sklearn.metrics import (classification_report, confusion_matrix, f1_score,  # noqa: E402
                             precision_recall_fscore_support)
from torch.utils.data import DataLoader  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CLASSES, ROOT, SplitDataset, eval_transform, get_device, load_trained  # noqa: E402


def metrics_from(y, p):
    pr, rc, f1, sup = precision_recall_fscore_support(y, p, labels=range(len(CLASSES)), zero_division=0)
    return {
        "n": int(len(y)),
        "accuracy": float((y == p).mean()),
        "macro_f1": float(f1_score(y, p, average="macro", labels=range(len(CLASSES)), zero_division=0)),
        "weighted_f1": float(f1_score(y, p, average="weighted", labels=range(len(CLASSES)), zero_division=0)),
        "burn_recall": float(rc[CLASSES.index("Burn")]),
        "burn_precision": float(pr[CLASSES.index("Burn")]),
        "per_class": {c: {"precision": float(pr[k]), "recall": float(rc[k]), "f1": float(f1[k]),
                          "support": int(sup[k])} for k, c in enumerate(CLASSES)},
        "confusion_matrix": confusion_matrix(y, p, labels=range(len(CLASSES))).tolist(),
    }


def bootstrap_ci(y, p, n=2000, seed=0):
    rng = np.random.default_rng(seed)
    acc, mf1, br = [], [], []
    b = CLASSES.index("Burn")
    for _ in range(n):
        i = rng.integers(0, len(y), len(y))
        yy, pp = y[i], p[i]
        acc.append((yy == pp).mean())
        mf1.append(f1_score(yy, pp, average="macro", labels=range(len(CLASSES)), zero_division=0))
        m = yy == b
        if m.any():
            br.append((pp[m] == b).mean())
    q = lambda a: [float(np.percentile(a, 2.5)), float(np.percentile(a, 97.5))]  # noqa: E731
    return {"accuracy_95ci": q(acc), "macro_f1_95ci": q(mf1), "burn_recall_95ci": q(br)}


def plot_cm(cm, title, path):
    cm = np.array(cm)
    norm = cm / cm.sum(1, keepdims=True).clip(min=1)
    fig, ax = plt.subplots(figsize=(6.4, 5.4))
    ax.imshow(norm, cmap="Blues", vmin=0, vmax=1)
    for i in range(len(CLASSES)):
        for j in range(len(CLASSES)):
            ax.text(j, i, f"{cm[i, j]}\n{norm[i, j]:.0%}", ha="center", va="center", fontsize=9,
                    color="white" if norm[i, j] > 0.6 else "#222")
    ax.set_xticks(range(len(CLASSES)), CLASSES, rotation=30, ha="right")
    ax.set_yticks(range(len(CLASSES)), CLASSES)
    ax.set_xlabel("Classe prevista")
    ax.set_ylabel("Classe verdadeira")
    ax.set_title(title)
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)


def plot_curves(history_files, path):
    hist, bounds = [], []
    for hf in history_files:
        h = json.loads(Path(hf).read_text())
        if hist:
            bounds.append(len(hist) + 0.5)
        hist += h
    ep = np.arange(1, len(hist) + 1)
    get = lambda k: [h[k] for h in hist]  # noqa: E731
    fig, axes = plt.subplots(1, 3, figsize=(14, 4))
    axes[0].plot(ep, get("train_loss"), label="treino (loss ponderada)")
    axes[0].plot(ep, get("val_loss"), label="validação")
    axes[0].set_title("Loss")
    axes[1].plot(ep, get("train_acc"), label="treino (com augmentation)")
    axes[1].plot(ep, get("val_acc"), label="validação")
    axes[1].set_title("Accuracy")
    axes[2].plot(ep, get("val_macro_f1"), label="val macro F1")
    axes[2].plot(ep, get("val_burn_recall"), label="val recall Burn")
    axes[2].set_title("Validação")
    for ax in axes:
        for b in bounds:
            ax.axvline(b, color="gray", ls="--", lw=1)
        ax.set_xlabel("época (linha tracejada = início do fine-tuning)" if bounds else "época")
        ax.grid(alpha=0.3)
        ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", default=str(ROOT / "models"))
    ap.add_argument("--split", choices=["val", "test"], required=True)
    ap.add_argument("--splits", default=str(ROOT / "dataset" / "splits.csv"))
    ap.add_argument("--out", default=None)
    ap.add_argument("--histories", nargs="*", default=[])
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    out = Path(args.out or ROOT / "reports" / args.split)
    out.mkdir(parents=True, exist_ok=True)
    lock = out / ".EVALUATED"
    if args.split == "test" and lock.exists() and not args.force:
        sys.exit(f"Teste já avaliado em {lock.read_text().strip()}. Use --force para reavaliar.")

    device = get_device()
    model, meta = load_trained(args.model_dir, device)
    ds = SplitDataset(args.splits, args.split, eval_transform())
    dl = DataLoader(ds, batch_size=32, shuffle=False, num_workers=2)
    probs = []
    with torch.no_grad():
        for x, _, _ in dl:
            probs.append(torch.softmax(model(x.to(device)), 1).cpu().numpy())
    P = np.concatenate(probs)
    y = np.array([lab for _, lab in ds.items])
    p = P.argmax(1)

    m = metrics_from(y, p)
    m["bootstrap"] = bootstrap_ci(y, p)
    shot = np.array([float(r["screenshot_score"]) > 0.5 for r in ds.rows])
    if shot.any() and (~shot).any():
        m["subset_without_screenshot_like"] = {k: v for k, v in metrics_from(y[~shot], p[~shot]).items()
                                               if k != "confusion_matrix"}
        m["subset_screenshot_like"] = {"n": int(shot.sum()), "accuracy": float((y[shot] == p[shot]).mean()),
                                       "labels": {c: int((y[shot] == k).sum()) for k, c in enumerate(CLASSES)}}
    m["model"] = {"dir": str(args.model_dir), "best_epoch": meta.get("best_epoch"),
                  "phase": meta.get("train_args", {}).get("phase")}
    (out / "metrics.json").write_text(json.dumps(m, indent=2, ensure_ascii=False))
    (out / "classification_report.txt").write_text(
        classification_report(y, p, labels=range(len(CLASSES)), target_names=CLASSES, digits=3, zero_division=0))

    with open(out / "predictions.csv", "w", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["path", "true", "pred", "correct", "screenshot_score"] + [f"p_{c}" for c in CLASSES])
        for k, r in enumerate(ds.rows):
            w.writerow([r["path"], CLASSES[y[k]], CLASSES[p[k]], int(y[k] == p[k]), r["screenshot_score"]]
                       + [f"{v:.4f}" for v in P[k]])

    plot_cm(m["confusion_matrix"], f"Matriz de confusão — {args.split} (n={len(y)})", out / "confusion_matrix.png")
    if args.histories:
        plot_curves(args.histories, out / "training_curves.png")

    if args.split == "test":
        import datetime
        lock.write_text(datetime.datetime.now().isoformat())
    print((out / "classification_report.txt").read_text())
    print(json.dumps({k: m[k] for k in ("n", "accuracy", "macro_f1", "burn_recall", "bootstrap")}, indent=2))


if __name__ == "__main__":
    main()
