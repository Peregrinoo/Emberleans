"""Gera galeria HTML local com predições, pontuações por classe e Grad-CAM.

Lê reports/<split>/predictions.csv e metrics.json (gerados por evaluate.py).

Uso:
    python src/report.py --split test
Abre: reports/test/gallery.html
"""
import argparse
import csv
import html
import json
import sys
from pathlib import Path

import torch
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CLASSES, ROOT, denormalize, eval_transform, get_device, load_trained  # noqa: E402
from gradcam import GradCAM, overlay  # noqa: E402

COLORS = {"Abrasion": "#c47f2c", "Bruise": "#6a4fb3", "Burn": "#d1422f", "Laceration": "#1f7a8c",
          "Normal Skin": "#5a8f3d"}

CSS = """
*{box-sizing:border-box}body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#f6f5f2;color:#1d1d1f}
header{padding:24px 32px;background:#fff;border-bottom:1px solid #ddd}
h1{margin:0 0 6px;font-size:22px}h2{font-size:17px;margin:28px 32px 10px}
.note{color:#8a3b12;background:#fff4e5;border:1px solid #f0c890;padding:8px 12px;border-radius:6px;font-size:13px;margin-top:10px}
.kpis{display:flex;gap:12px;flex-wrap:wrap;margin-top:14px}
.kpi{background:#f6f5f2;border-radius:8px;padding:10px 14px;min-width:120px}
.kpi b{display:block;font-size:20px}.kpi span{font-size:12px;color:#555}
.figs{display:flex;gap:16px;flex-wrap:wrap;padding:0 32px}.figs img{max-width:100%;background:#fff;border:1px solid #ddd;border-radius:6px}
table.pc{border-collapse:collapse;margin:0 32px;font-size:13px;background:#fff}
table.pc td,table.pc th{border:1px solid #ddd;padding:5px 10px;text-align:right}table.pc td:first-child{text-align:left}
.bar{position:sticky;top:0;background:#fffffff0;padding:10px 32px;border-bottom:1px solid #ddd;z-index:2;display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.bar button{border:1px solid #bbb;background:#fff;border-radius:14px;padding:4px 12px;cursor:pointer;font-size:13px}
.bar button.on{background:#1d1d1f;color:#fff;border-color:#1d1d1f}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:14px;padding:16px 32px 40px}
.card{background:#fff;border-radius:10px;border:2px solid #ddd;padding:10px;font-size:13px}
.card.wrong{border-color:#d1422f}.card.right{border-color:#9cc59a}
.imgs{display:flex;gap:6px}.imgs figure{margin:0;flex:1}.imgs img{width:100%;border-radius:6px;display:block}
figcaption{font-size:11px;color:#666;text-align:center}
.lbl{margin:8px 0 6px;display:flex;justify-content:space-between}
.row{display:flex;align-items:center;gap:6px;margin:2px 0}.row .n{width:84px;font-size:12px}
.row .t{flex:1;background:#eee;height:10px;border-radius:5px;overflow:hidden}.row .t div{height:100%}
.row .v{width:44px;text-align:right;font-variant-numeric:tabular-nums;font-size:12px}
.path{font-size:10px;color:#999;word-break:break-all;margin-top:6px}
.tag{font-size:10px;background:#333;color:#fff;border-radius:4px;padding:1px 5px;margin-left:4px}
"""

JS = """
let st={res:'all',cls:'all'};
function f(k,v,b){st[k]=v;document.querySelectorAll('[data-k='+k+']').forEach(x=>x.classList.toggle('on',x===b));
document.querySelectorAll('.card').forEach(c=>{let ok=(st.res==='all'||c.dataset.res===st.res)&&(st.cls==='all'||c.dataset.true===st.cls||c.dataset.pred===st.cls);c.style.display=ok?'':'none'});
document.getElementById('cnt').textContent=[...document.querySelectorAll('.card')].filter(c=>c.style.display!=='none').length+' imagens';}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", default=str(ROOT / "models"))
    ap.add_argument("--split", choices=["val", "test"], default="test")
    ap.add_argument("--reports", default=str(ROOT / "reports"))
    args = ap.parse_args()
    rdir = Path(args.reports) / args.split
    imgdir = rdir / "gallery_images"
    imgdir.mkdir(parents=True, exist_ok=True)

    device = torch.device("cpu") if get_device().type == "mps" else get_device()  # hooks + backward: CPU é suficiente
    model, meta = load_trained(args.model_dir, device)
    cam = GradCAM(model)
    tf = eval_transform()
    raw = ROOT / "dataset" / "raw"

    with open(rdir / "predictions.csv") as fh:
        preds = list(csv.DictReader(fh))
    metrics = json.loads((rdir / "metrics.json").read_text())

    cards = []
    for k, r in enumerate(preds):
        with Image.open(raw / r["path"]) as im:
            x = tf(im.convert("RGB")).unsqueeze(0).to(device)
        rgb = denormalize(x[0])
        name = f"{k:04d}"
        Image.fromarray(rgb).save(imgdir / f"{name}_in.jpg", quality=85)
        c_pred, probs, ip = cam(x)
        overlay(rgb, c_pred).save(imgdir / f"{name}_cam_pred.jpg", quality=85)
        figs = [(f"{name}_in.jpg", "entrada 224×224"), (f"{name}_cam_pred.jpg", f"Grad-CAM → {CLASSES[ip]}")]
        if r["true"] != r["pred"]:
            c_true, _, _ = cam(x, CLASSES.index(r["true"]))
            overlay(rgb, c_true).save(imgdir / f"{name}_cam_true.jpg", quality=85)
            figs.append((f"{name}_cam_true.jpg", f"Grad-CAM → {r['true']} (verdadeira)"))
        cards.append((r, probs, figs))

    # incorretos primeiro (mais confiantes primeiro), depois corretos por classe
    cards.sort(key=lambda c: (c[0]["correct"] == "1", -max(c[1]) if c[0]["correct"] == "0" else 0,
                              c[0]["true"]))

    m = metrics
    pcs = "".join(
        f"<tr><td>{c}</td><td>{v['precision']:.3f}</td><td>{v['recall']:.3f}</td><td>{v['f1']:.3f}</td>"
        f"<td>{v['support']}</td></tr>" for c, v in m["per_class"].items())
    bs = m.get("bootstrap", {})
    ci = lambda key: (f" <span>IC95% {bs[key][0]:.2f}–{bs[key][1]:.2f}</span>" if key in bs else "")  # noqa: E731
    parts = [f"<!DOCTYPE html><html lang='pt-BR'><head><meta charset='utf-8'><title>Galeria — {args.split}</title>"
             f"<style>{CSS}</style></head><body><header>"
             f"<h1>MobileNetV3 Small — lesões de pele — conjunto de {'teste' if args.split == 'test' else 'validação'}</h1>"
             f"<div>Modelo: {html.escape(str(meta.get('train_args', {}).get('phase')))} · melhor época "
             f"{meta.get('best_epoch')} · n={m['n']}</div>"
             "<div class='note'>Experimento de visão computacional. As classificações <b>não são diagnósticos "
             "médicos</b>; o dataset é pequeno, coletado da web e com rótulos não verificados clinicamente.</div>"
             "<div class='kpis'>"
             f"<div class='kpi'><b>{m['accuracy']:.3f}</b><span>accuracy</span>{ci('accuracy_95ci')}</div>"
             f"<div class='kpi'><b>{m['macro_f1']:.3f}</b><span>macro F1</span>{ci('macro_f1_95ci')}</div>"
             f"<div class='kpi'><b>{m['burn_recall']:.3f}</b><span>recall Burn</span>{ci('burn_recall_95ci')}</div>"
             f"<div class='kpi'><b>{m['burn_precision']:.3f}</b><span>precision Burn</span></div>"
             "</div></header>",
             "<h2>Métricas por classe</h2><table class='pc'><tr><th>classe</th><th>precision</th><th>recall</th>"
             f"<th>F1</th><th>suporte</th></tr>{pcs}</table>",
             "<h2>Matriz de confusão e curvas</h2><div class='figs'><img src='confusion_matrix.png'>"]
    for curves in (rdir / "training_curves.png", rdir.parent / "training_curves.png"):
        if curves.exists():
            parts.append(f"<img src='{Path('..') / curves.name if curves.parent != rdir else curves.name}'>")
            break
    parts.append("</div><h2>Galeria</h2><div class='bar'>")
    for v, lab in (("all", "todas"), ("0", "incorretas"), ("1", "corretas")):
        parts.append(f"<button data-k='res' class='{'on' if v == 'all' else ''}' onclick=\"f('res','{v}',this)\">{lab}</button>")
    parts.append("<span style='width:14px'></span>")
    for c in ["all"] + CLASSES:
        parts.append(f"<button data-k='cls' class='{'on' if c == 'all' else ''}' onclick=\"f('cls','{c}',this)\">"
                     f"{'todas as classes' if c == 'all' else c}</button>")
    parts.append(f"<span id='cnt' style='margin-left:auto;font-size:13px'>{len(cards)} imagens</span></div><div class='grid'>")
    for r, probs, figs in cards:
        ok = r["correct"] == "1"
        rows = "".join(
            f"<div class='row'><span class='n'>{'<b>' if c == r['pred'] else ''}{c}{'</b>' if c == r['pred'] else ''}</span>"
            f"<span class='t'><div style='width:{probs[k]*100:.1f}%;background:{COLORS[c]}'></div></span>"
            f"<span class='v'>{probs[k]*100:.1f}%</span></div>" for k, c in enumerate(CLASSES))
        imgs = "".join(f"<figure><img loading='lazy' src='gallery_images/{fn}'><figcaption>{html.escape(cap)}</figcaption></figure>"
                       for fn, cap in figs)
        shot = "<span class='tag'>print/vídeo</span>" if float(r["screenshot_score"]) > 0.5 else ""
        parts.append(
            f"<div class='card {'right' if ok else 'wrong'}' data-res='{r['correct']}' data-true='{r['true']}' "
            f"data-pred='{r['pred']}'><div class='imgs'>{imgs}</div>"
            f"<div class='lbl'><span>verdadeira: <b>{r['true']}</b>{shot}</span>"
            f"<span>{'✓' if ok else '✗'} prevista: <b style='color:{COLORS[r['pred']]}'>{r['pred']}</b></span></div>"
            f"{rows}<div class='path'>arquivo original (pasta do Roboflow): {html.escape(r['path'])}</div></div>")
    parts.append(f"</div><script>{JS}</script></body></html>")
    page = "".join(parts)
    (rdir / "gallery.html").write_text(page, encoding="utf-8")
    print(f"galeria: {rdir / 'gallery.html'} ({len(cards)} imagens)")

    # versão autocontida (imagens embutidas em base64) para abrir/compartilhar sem a pasta
    import base64
    import re

    def inline(m):
        src = m.group(1)
        f = (rdir / src).resolve()
        if not f.exists():
            return m.group(0)
        mime = "image/png" if f.suffix == ".png" else "image/jpeg"
        return f"src='data:{mime};base64,{base64.b64encode(f.read_bytes()).decode()}'"
    standalone = re.sub(r"src='([^']+\.(?:jpg|png))'", inline, page)
    (rdir / "gallery_standalone.html").write_text(standalone, encoding="utf-8")


if __name__ == "__main__":
    main()
