"""Treinamento MobileNetV3 Small (transfer learning) com early stopping.

Fase 1 (head):     backbone congelado, treina apenas o classificador.
Fase 2 (finetune): parte do backbone descongelada (últimos N blocks de
                   `features`), LR menor, inicializado do melhor checkpoint
                   da fase 1.

O melhor checkpoint é escolhido pelo macro F1 na VALIDAÇÃO.
O conjunto de teste NÃO é usado aqui.

Uso:
    python src/train.py --phase head --out models/head
    python src/train.py --phase finetune --init models/head/best_model.pt \
        --unfreeze-blocks 4 --out models/finetune
"""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import f1_score, precision_recall_fscore_support
from torch import nn
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (CLASSES, IMAGENET_WEIGHTS_FILE, PREPROCESS, ROOT, SplitDataset,  # noqa: E402
                    build_model, eval_transform, get_device, seed_everything, train_transform)


def set_trainable(model, phase, unfreeze_blocks):
    for p in model.parameters():
        p.requires_grad = False
    for p in model.classifier.parameters():
        p.requires_grad = True
    if phase == "finetune":
        for blk in model.features[-unfreeze_blocks:]:
            for p in blk.parameters():
                p.requires_grad = True


def freeze_bn_of_frozen(model):
    """Mantém BatchNorm em eval nos blocos congelados (estatísticas ImageNet)."""
    for m in model.features.modules():
        if isinstance(m, nn.BatchNorm2d) and not any(p.requires_grad for p in m.parameters()):
            m.eval()


@torch.no_grad()
def evaluate(model, loader, device, criterion):
    model.eval()
    ys, ps, losses = [], [], []
    for x, y, _ in loader:
        x, y = x.to(device), y.to(device)
        logits = model(x)
        losses.append(criterion(logits, y).item() * len(y))
        ys.append(y.cpu().numpy())
        ps.append(logits.argmax(1).cpu().numpy())
    y, p = np.concatenate(ys), np.concatenate(ps)
    pr, rc, f1, sup = precision_recall_fscore_support(y, p, labels=range(len(CLASSES)), zero_division=0)
    return {
        "loss": float(np.sum(losses) / len(y)),
        "acc": float((y == p).mean()),
        "macro_f1": float(f1_score(y, p, average="macro", labels=range(len(CLASSES)), zero_division=0)),
        "burn_recall": float(rc[CLASSES.index("Burn")]),
        "per_class": {c: {"precision": float(pr[k]), "recall": float(rc[k]), "f1": float(f1[k]),
                          "support": int(sup[k])} for k, c in enumerate(CLASSES)},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phase", choices=["head", "finetune"], default="head")
    ap.add_argument("--init", default=None, help="checkpoint para iniciar (fase finetune)")
    ap.add_argument("--unfreeze-blocks", type=int, default=4)
    ap.add_argument("--splits", default=str(ROOT / "dataset" / "splits.csv"))
    ap.add_argument("--out", default=str(ROOT / "models" / "head"))
    ap.add_argument("--epochs", type=int, default=40)
    ap.add_argument("--patience", type=int, default=7)
    ap.add_argument("--batch-size", type=int, default=32)
    ap.add_argument("--lr", type=float, default=None)
    ap.add_argument("--weight-decay", type=float, default=1e-4)
    ap.add_argument("--label-smoothing", type=float, default=0.05)
    ap.add_argument("--class-weights", choices=["none", "inverse"], default="inverse")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    if args.lr is None:
        args.lr = 1e-3 if args.phase == "head" else 2e-4

    seed_everything(args.seed)
    device = get_device()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    print(f"device={device} phase={args.phase}")

    train_ds = SplitDataset(args.splits, "train", train_transform())
    val_ds = SplitDataset(args.splits, "val", eval_transform())
    g = torch.Generator().manual_seed(args.seed)
    train_dl = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True, num_workers=args.workers,
                          generator=g, persistent_workers=args.workers > 0)
    val_dl = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False, num_workers=args.workers,
                        persistent_workers=args.workers > 0)

    model = build_model(imagenet_weights=ROOT / "models" / IMAGENET_WEIGHTS_FILE)
    if args.init:
        model.load_state_dict(torch.load(args.init, map_location="cpu", weights_only=True))
    set_trainable(model, args.phase, args.unfreeze_blocks)
    model.to(device)

    counts = np.bincount([y for _, y in train_ds.items], minlength=len(CLASSES))
    if args.class_weights == "inverse":
        w = counts.sum() / (len(CLASSES) * counts)
        weight = torch.tensor(w, dtype=torch.float32, device=device)
    else:
        weight = None
    criterion = nn.CrossEntropyLoss(weight=weight, label_smoothing=args.label_smoothing)
    eval_criterion = nn.CrossEntropyLoss()  # loss de validação sem pesos, comparável entre runs

    params = [p for p in model.parameters() if p.requires_grad]
    n_train = sum(p.numel() for p in params)
    opt = torch.optim.AdamW(params, lr=args.lr, weight_decay=args.weight_decay)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=args.epochs)

    history, best, best_epoch, bad = [], -1.0, -1, 0
    t0 = time.time()
    for epoch in range(1, args.epochs + 1):
        te = time.time()
        model.train()
        freeze_bn_of_frozen(model)
        tl, tc, tn = 0.0, 0, 0
        for x, y, _ in train_dl:
            x, y = x.to(device), y.to(device)
            opt.zero_grad(set_to_none=True)
            logits = model(x)
            loss = criterion(logits, y)
            loss.backward()
            opt.step()
            tl += loss.item() * len(y)
            tc += (logits.argmax(1) == y).sum().item()
            tn += len(y)
        sched.step()
        v = evaluate(model, val_dl, device, eval_criterion)
        rec = {"epoch": epoch, "train_loss": tl / tn, "train_acc": tc / tn, "val_loss": v["loss"],
               "val_acc": v["acc"], "val_macro_f1": v["macro_f1"], "val_burn_recall": v["burn_recall"],
               "lr": sched.get_last_lr()[0], "seconds": round(time.time() - te, 1)}
        history.append(rec)
        improved = v["macro_f1"] > best + 1e-4
        if improved:
            best, best_epoch, bad = v["macro_f1"], epoch, 0
            torch.save(model.state_dict(), out / "best_model.pt")
            (out / "val_metrics_best.json").write_text(json.dumps(v | {"epoch": epoch}, indent=2))
        else:
            bad += 1
        print(f"ep {epoch:02d} | train loss {rec['train_loss']:.3f} acc {rec['train_acc']:.3f} | "
              f"val loss {v['loss']:.3f} acc {v['acc']:.3f} mF1 {v['macro_f1']:.3f} "
              f"burnR {v['burn_recall']:.3f} | {rec['seconds']}s {'*' if improved else ''}", flush=True)
        (out / "history.json").write_text(json.dumps(history, indent=2))
        if device.type == "mps":
            torch.mps.empty_cache()
        if bad >= args.patience:
            print(f"early stopping (sem melhora há {args.patience} épocas)")
            break

    total = time.time() - t0
    config = {
        "architecture": "torchvision.models.mobilenet_v3_small",
        "pretrained": "ImageNet1K_V1 (" + IMAGENET_WEIGHTS_FILE + ")",
        "classes": CLASSES,
        "class_to_idx": {c: i for i, c in enumerate(CLASSES)},
        "preprocess": PREPROCESS,
        "train_args": vars(args),
        "device": str(device),
        "trainable_params": n_train,
        "train_counts": dict(zip(CLASSES, counts.tolist())),
        "best_epoch": best_epoch,
        "best_val_macro_f1": best,
        "epochs_run": len(history),
        "train_seconds": round(total, 1),
        "torch": torch.__version__,
    }
    (out / "model_config.json").write_text(json.dumps(config, indent=2, ensure_ascii=False))
    print(f"melhor época {best_epoch} | val macro F1 {best:.4f} | {total/60:.1f} min")


if __name__ == "__main__":
    main()
