"""Constrói divisões train/val/test reproduzíveis, sem vazamento.

Etapas:
 1. Lê dataset/inspection/images.csv (gerado por inspect_dataset.py).
 2. Descarta imagens corrompidas e a pasta "Unlabeled" do Roboflow.
 3. Liga imagens relacionadas (grafo + componentes conexos):
      a) mesmo arquivo de origem (nome antes de ".rf.<hash>")
      b) correlação de miniatura 32x32 >= --thumb-thr, máximo entre as 8
         rotações/espelhamentos (pega cópias espelhadas/rotacionadas)
      c) similaridade de cosseno de embeddings ImageNet (MobileNetV3 Small,
         sem fine-tuning, após remover barras pretas) >= --emb-thr
         (pega recortes/variações de cor)
    Ligações só dentro da mesma classe; Normal Skin usa limiares mais
    estritos (texturas uniformes). Limiares calibrados por inspeção visual.
 4. Conflitos de rótulo: a mesma foto (limiar estrito) em classes diferentes
    -> todas as cópias dessa foto são removidas.
 5. Divide os componentes em 70/15/15, estratificado pela classe, com seed.
 6. Em val/test mantém só 1 imagem por cluster de quase-duplicatas visuais,
    para não contar a mesma foto duas vezes na métrica. Train mantém todas.

Saída: dataset/splits.csv e dataset/splits_summary.json

Uso:
    python src/build_splits.py
"""
import argparse
import csv
import json
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CLASSES, IMAGENET_WEIGHTS_FILE, ROOT, build_model, eval_transform  # noqa: E402


def crop_content(img):
    """Remove bordas quase pretas (barras de vídeo / prints de celular) para comparar o conteúdo."""
    a = np.asarray(img.convert("L"), dtype=np.float32)
    dark = a < 35
    rows = np.nonzero(dark.mean(1) < 0.85)[0]
    cols = np.nonzero(dark.mean(0) < 0.85)[0]
    if len(rows) < 16 or len(cols) < 16:
        return img
    # descarta faixas de UI: mantém o maior bloco contínuo de linhas "claras"
    splits = np.split(rows, np.nonzero(np.diff(rows) > 3)[0] + 1)
    rows = max(splits, key=len)
    return img.crop((int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1))


def thumb_vecs(img):
    out = []
    ts = [img, img.transpose(Image.FLIP_LEFT_RIGHT)]
    ts = [t.rotate(a, expand=True) for t in ts for a in (0, 90, 180, 270)]
    for t in ts:
        a = np.asarray(t.convert("L").resize((32, 32), Image.BILINEAR), dtype=np.float32).ravel()
        a -= a.mean()
        out.append(a / (np.linalg.norm(a) + 1e-6))
    return np.stack(out)


def screenshot_score(img):
    """Fração de linhas quase pretas nas faixas superior+inferior (barras de vídeo/print)."""
    a = np.asarray(img.convert("L").resize((128, 128)), dtype=np.float32)
    rows = a.mean(1) < 18
    band = np.r_[rows[:24], rows[-24:]]
    return float(band.mean())


def embeddings(paths, raw):
    import torch
    model = build_model(imagenet_weights=ROOT / "models" / IMAGENET_WEIGHTS_FILE).eval()
    model.classifier = torch.nn.Identity()
    tf = eval_transform()
    feats = []
    with torch.no_grad():
        for i in range(0, len(paths), 64):
            xs = []
            for p in paths[i:i + 64]:
                with Image.open(raw / p) as im:
                    xs.append(tf(crop_content(im.convert("RGB"))))
            x = torch.stack(xs)
            f = model.avgpool(model.features(x)).flatten(1)
            f2 = model.avgpool(model.features(torch.flip(x, dims=[3]))).flatten(1)
            feats.append(((f + f2) / 2).numpy())
    f = np.concatenate(feats)
    return f / np.linalg.norm(f, axis=1, keepdims=True)


class UF:
    def __init__(self, n):
        self.p = list(range(n))

    def find(self, x):
        while self.p[x] != x:
            self.p[x] = self.p[self.p[x]]
            x = self.p[x]
        return x

    def union(self, a, b):
        a, b = self.find(a), self.find(b)
        if a != b:
            self.p[max(a, b)] = min(a, b)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=str(ROOT / "dataset" / "raw"))
    ap.add_argument("--inspection", default=str(ROOT / "dataset" / "inspection"))
    ap.add_argument("--out", default=str(ROOT / "dataset"))
    ap.add_argument("--thumb-thr", type=float, default=0.97)
    ap.add_argument("--emb-thr", type=float, default=0.82)
    ap.add_argument("--normal-thumb-thr", type=float, default=0.99)
    ap.add_argument("--normal-emb-thr", type=float, default=0.98)
    ap.add_argument("--stem-min-sim", type=float, default=0.80)
    ap.add_argument("--conflict-emb-thr", type=float, default=0.92)
    ap.add_argument("--ratios", type=float, nargs=3, default=[0.70, 0.15, 0.15])
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    raw, insp, out = Path(args.raw), Path(args.inspection), Path(args.out)

    with open(insp / "images.csv") as fh:
        allrows = list(csv.DictReader(fh))
    removed = Counter()
    rows = []
    for r in allrows:
        if r["ok"] != "True":
            removed["corrompida"] += 1
        elif r["label"] not in CLASSES:
            removed["sem_rotulo (Unlabeled)"] += 1
        else:
            rows.append(r)
    n = len(rows)
    print(f"{n} imagens rotuladas e legíveis")

    T, shots = [], []
    for r in rows:
        with Image.open(raw / r["path"]) as im:
            im = im.convert("RGB")
            T.append(thumb_vecs(crop_content(im)))
            shots.append(screenshot_score(im))
    T = np.stack(T)
    S = np.einsum("id,jkd->ijk", T[:, 0], T).max(2)
    S = np.maximum(S, S.T)
    np.fill_diagonal(S, -1)

    E = embeddings([r["path"] for r in rows], raw)
    C = E @ E.T
    np.fill_diagonal(C, -1)
    np.save(insp / "thumb_sim.npy", S.astype(np.float16))
    np.save(insp / "emb_sim.npy", C.astype(np.float16))

    # Limiar por tipo de par (calibrado por inspeção visual, ver README):
    # pele normal é textura quase uniforme -> similaridade alta entre fotos
    # diferentes, então exige limiar mais estrito para evitar encadeamento.
    labels = np.array([r["label"] for r in rows])
    same_label = labels[:, None] == labels[None, :]
    both_normal = (labels[:, None] == "Normal Skin") & (labels[None, :] == "Normal Skin")
    vis_generic = (S >= args.thumb_thr) | (C >= args.emb_thr)
    vis_normal = (S >= args.normal_thumb_thr) | (C >= args.normal_emb_thr)
    # ligações dentro da mesma classe
    link = same_label & np.where(both_normal, vis_normal, vis_generic)
    # mesmo arquivo de origem, desde que visualmente relacionado
    # (nomes genéricos como "133_jpg" correspondem a fotos diferentes)
    src = np.array([r["source"] for r in rows])
    link |= same_label & (src[:, None] == src[None, :]) & (np.maximum(S, C) >= args.stem_min_sim)
    np.fill_diagonal(link, False)
    # entre classes: limiar mais estrito, só para detectar conflito
    conflict_m = ~same_label & ((S >= args.thumb_thr) | (C >= args.conflict_emb_thr))
    vis_pairs = np.argwhere(np.triu(link))

    # agrupamento conservador (unidade de split)
    uf_vis = UF(n)
    for i, j in vis_pairs:
        uf_vis.union(int(i), int(j))
    # clusters de cópias quase idênticas (critério estrito): usados para
    # propagar conflitos e deduplicar val/test sem colapsar fotos diferentes
    strict = same_label & np.where(both_normal, vis_normal,
                                   (S >= args.thumb_thr) | (C >= args.conflict_emb_thr))
    strict |= same_label & (src[:, None] == src[None, :]) & (np.maximum(S, C) >= args.stem_min_sim)
    np.fill_diagonal(strict, False)
    uf_dup = UF(n)
    for i, j in np.argwhere(np.triu(strict)):
        uf_dup.union(int(i), int(j))

    # 4. conflitos de rótulo: a mesma foto em duas classes -> remove todas
    #    as cópias quase idênticas dessa foto, dos dois lados
    conflict_pairs, bad_clusters = [], set()
    for i, j in np.argwhere(np.triu(conflict_m)):
        bad_clusters.update([uf_dup.find(int(i)), uf_dup.find(int(j))])
        conflict_pairs.append({"a": rows[i]["path"], "b": rows[j]["path"],
                               "label_a": rows[i]["label"], "label_b": rows[j]["label"],
                               "thumb_sim": round(float(S[i, j]), 3), "emb_sim": round(float(C[i, j]), 3)})
    conflict = {i for i in range(n) if uf_dup.find(i) in bad_clusters}
    keep = [i for i in range(n) if i not in conflict]
    removed["conflito_de_rotulo"] = len(conflict)
    uf_all = uf_vis

    comps = defaultdict(list)
    for i in keep:
        comps[uf_all.find(i)].append(i)
    comp_sizes = Counter(len(v) for v in comps.values())

    # 5. split estratificado por grupo
    rng = random.Random(args.seed)
    by_label = defaultdict(list)
    for cid, idx in comps.items():
        lab = Counter(rows[i]["label"] for i in idx).most_common(1)[0][0]
        by_label[lab].append(cid)
    names = ["train", "val", "test"]
    assign = {}
    for lab in CLASSES:
        cids = sorted(by_label[lab])
        rng.shuffle(cids)
        cids.sort(key=lambda c: -len(comps[c]))  # grandes primeiro (estável após shuffle)
        total = sum(len(comps[c]) for c in cids)
        got = dict.fromkeys(names, 0)
        for c in cids:
            deficit = {s: args.ratios[k] * total - got[s] for k, s in enumerate(names)}
            s = max(names, key=lambda s: deficit[s])
            assign[c] = s
            got[s] += len(comps[c])

    # 6. dedup em val/test
    out_rows, dedup_dropped = [], 0
    seen_vis = set()
    for i in keep:
        r = rows[i]
        split = assign[uf_all.find(i)]
        vcl = uf_dup.find(i)
        if split != "train":
            if vcl in seen_vis:
                dedup_dropped += 1
                continue
            seen_vis.add(vcl)
        out_rows.append({"path": r["path"], "label": r["label"], "split": split,
                         "orig_split": r["split"], "group": f"c{uf_all.find(i):05d}",
                         "vis_cluster": f"v{vcl:05d}", "screenshot_score": round(shots[i], 3)})
    removed["duplicata_removida_de_val_test"] = dedup_dropped

    out_rows.sort(key=lambda r: (r["split"], r["label"], r["path"]))
    with open(out / "splits.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out_rows[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(out_rows)
    with open(insp / "label_conflicts.csv", "w", newline="") as fh:
        if conflict_pairs:
            w = csv.DictWriter(fh, fieldnames=list(conflict_pairs[0].keys()), lineterminator="\n")
            w.writeheader()
            w.writerows(conflict_pairs)

    # vazamento: checagem final
    grp_splits = defaultdict(set)
    for r in out_rows:
        grp_splits[r["group"]].add(r["split"])
    leaks = sum(len(v) > 1 for v in grp_splits.values())
    # vazamento residual por similaridade (abaixo dos limiares) — diagnóstico
    pos = {r["path"]: k for k, r in enumerate(rows)}
    idx_split = defaultdict(list)
    for r in out_rows:
        idx_split[r["split"]].append(pos[r["path"]])
    max_cross = {}
    for a in ("val", "test"):
        ia, it = idx_split[a], idx_split["train"]
        max_cross[f"{a}_vs_train_max_thumb_sim"] = round(float(S[np.ix_(ia, it)].max()), 3)
        max_cross[f"{a}_vs_train_max_emb_sim"] = round(float(C[np.ix_(ia, it)].max()), 3)

    counts = Counter((r["split"], r["label"]) for r in out_rows)
    shot_by_class = {c: round(float(np.mean([r["screenshot_score"] > 0.5 for r in out_rows if r["label"] == c])), 3)
                     for c in CLASSES}
    summary = {
        "params": vars(args),
        "input_files": len(allrows),
        "removed": dict(removed),
        "used_images": len(out_rows),
        "by_split": {s: {c: counts[(s, c)] for c in CLASSES} | {"total": sum(counts[(s, c)] for c in CLASSES)}
                     for s in names},
        "by_class": {c: sum(counts[(s, c)] for s in names) for c in CLASSES},
        "n_groups": len(comps),
        "group_size_hist": dict(sorted(comp_sizes.items())),
        "visual_duplicate_pairs": int(len(vis_pairs)),
        "label_conflict_pairs": len(conflict_pairs),
        "groups_crossing_splits_after_fix": leaks,
        "residual_similarity": max_cross,
        "screenshot_like_fraction_by_class": shot_by_class,
    }
    (out / "splits_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
