"""Inspeciona o dataset bruto exportado do Roboflow (formato folder).

Verifica:
  - imagens corrompidas / ilegíveis
  - duplicatas exatas (MD5 dos pixels decodificados e do arquivo)
  - quase-duplicatas (dHash 64 bits, distância de Hamming <= limiar)
  - mesmo arquivo de origem reexportado (nome antes de ".rf.<hash>")
  - conflitos de rótulo (mesmo grupo em classes diferentes)
  - vazamento entre train/valid/test (mesmo grupo em splits diferentes)

Saída: dataset/inspection/images.csv e dataset/inspection/summary.json

Uso:
    python src/inspect_dataset.py --raw dataset/raw --out dataset/inspection
"""
import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

SPLITS = ["train", "valid", "test"]
CLASS_MAP = {  # pasta do Roboflow -> nome canônico
    "abrasion": "Abrasion",
    "bruise": "Bruise",
    "burn": "Burn",
    "laceration": "Laceration",
    "normal skin": "Normal Skin",
}
RF_SUFFIX = re.compile(r"\.rf\.[0-9a-f]{32}$")


def source_stem(path: Path) -> str:
    """Nome original antes do sufixo de exportação do Roboflow."""
    stem = RF_SUFFIX.sub("", path.stem)
    return stem.lower()


def dhash(img: Image.Image, size: int = 8) -> int:
    g = img.convert("L").resize((size + 1, size), Image.BILINEAR)
    a = np.asarray(g, dtype=np.int16)
    bits = (a[:, 1:] > a[:, :-1]).flatten()
    return int("".join("1" if b else "0" for b in bits), 2)


class UnionFind:
    def __init__(self, n):
        self.p = list(range(n))

    def find(self, x):
        while self.p[x] != x:
            self.p[x] = self.p[self.p[x]]
            x = self.p[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[max(ra, rb)] = min(ra, rb)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default="dataset/raw")
    ap.add_argument("--out", default="dataset/inspection")
    ap.add_argument("--hamming", type=int, default=4,
                    help="distância máxima de dHash para considerar quase-duplicata")
    args = ap.parse_args()
    raw, out = Path(args.raw), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    rows = []
    for split in SPLITS:
        for cdir in sorted((raw / split).iterdir()):
            if not cdir.is_dir():
                continue
            for f in sorted(cdir.iterdir()):
                if not f.is_file():
                    continue
                r = {"path": str(f.relative_to(raw)), "split": split,
                     "folder": cdir.name, "label": CLASS_MAP.get(cdir.name, ""),
                     "source": source_stem(f), "file_md5": hashlib.md5(f.read_bytes()).hexdigest(),
                     "ok": True, "error": "", "w": 0, "h": 0, "mode": "", "pix_md5": "", "dhash": ""}
                try:
                    with Image.open(f) as im:
                        im.verify()
                    with Image.open(f) as im:
                        im.load()
                        r["w"], r["h"], r["mode"] = im.width, im.height, im.mode
                        rgb = im.convert("RGB")
                        r["pix_md5"] = hashlib.md5(rgb.tobytes()).hexdigest()
                        r["dhash"] = f"{dhash(rgb):016x}"
                        if min(im.size) < 32:
                            r["ok"], r["error"] = False, "imagem muito pequena"
                except Exception as e:  # noqa: BLE001
                    r["ok"], r["error"] = False, f"{type(e).__name__}: {e}"
                rows.append(r)

    # --- agrupamento de imagens relacionadas ---
    n = len(rows)
    uf = UnionFind(n)
    by_key = defaultdict(list)
    for i, r in enumerate(rows):
        if not r["ok"]:
            continue
        by_key[("src", r["source"])].append(i)
        by_key[("md5", r["pix_md5"])].append(i)
    reasons = Counter()
    for (kind, _), idx in by_key.items():
        for j in idx[1:]:
            if uf.find(idx[0]) != uf.find(j):
                reasons[kind] += 1
            uf.union(idx[0], j)
    valid_idx = [i for i, r in enumerate(rows) if r["ok"]]
    hashes = np.array([int(rows[i]["dhash"], 16) for i in valid_idx], dtype=np.uint64)
    near_pairs = []
    for a in range(len(valid_idx)):
        x = np.bitwise_xor(hashes[a + 1:], hashes[a])
        d = np.array([bin(int(v)).count("1") for v in x]) if len(x) else np.array([])
        for off in np.nonzero(d <= args.hamming)[0]:
            i, j = valid_idx[a], valid_idx[a + 1 + off]
            near_pairs.append((i, j, int(d[off])))
            if uf.find(i) != uf.find(j):
                reasons["dhash"] += 1
            uf.union(i, j)

    for i, r in enumerate(rows):
        r["group"] = f"g{uf.find(i):05d}"

    groups = defaultdict(list)
    for i, r in enumerate(rows):
        if r["ok"]:
            groups[r["group"]].append(i)

    label_conflicts, leaks, dup_groups = [], [], []
    for g, idx in groups.items():
        labels = {rows[i]["label"] for i in idx}
        splits = {rows[i]["split"] for i in idx}
        if len(idx) > 1:
            dup_groups.append(g)
        if len(labels) > 1:
            label_conflicts.append({"group": g, "labels": sorted(labels),
                                    "files": [rows[i]["path"] for i in idx]})
        if len(splits) > 1:
            leaks.append({"group": g, "splits": sorted(splits), "labels": sorted(labels),
                          "files": [rows[i]["path"] for i in idx]})

    with open(out / "images.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    with open(out / "near_duplicate_pairs.csv", "w", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["a", "b", "hamming", "label_a", "label_b", "split_a", "split_b"])
        for i, j, d in near_pairs:
            w.writerow([rows[i]["path"], rows[j]["path"], d, rows[i]["label"], rows[j]["label"],
                        rows[i]["split"], rows[j]["split"]])

    summary = {
        "total_files": n,
        "corrupted": [r["path"] + " | " + r["error"] for r in rows if not r["ok"]],
        "unlabeled": sum(1 for r in rows if r["label"] == ""),
        "counts_by_split_folder": {f"{s}/{c}": v for (s, c), v in
                                   sorted(Counter((r["split"], r["folder"]) for r in rows).items())},
        "exact_pixel_duplicate_extra_copies": sum(len(v) - 1 for (k, _), v in by_key.items() if k == "md5"),
        "same_source_extra_copies": sum(len(v) - 1 for (k, _), v in by_key.items() if k == "src"),
        "near_duplicate_pairs": len(near_pairs),
        "merge_reasons": dict(reasons),
        "n_groups": len(groups),
        "groups_with_more_than_one_image": len(dup_groups),
        "label_conflict_groups": label_conflicts,
        "cross_split_leak_groups": leaks,
        "image_sizes": dict(Counter(f"{r['w']}x{r['h']}" for r in rows if r["ok"]).most_common(10)),
        "modes": dict(Counter(r["mode"] for r in rows if r["ok"])),
    }
    (out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    s = dict(summary)
    s["label_conflict_groups"] = len(label_conflicts)
    s["cross_split_leak_groups"] = len(leaks)
    print(json.dumps(s, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
