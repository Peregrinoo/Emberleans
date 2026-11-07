"""Validação da conversão para Core ML que pode rodar em Linux/WSL (sem runtime Core ML).

Verifica:
  1. carregamento estrito dos pesos e correspondência da arquitetura
  2. ordem das classes (config, código, Core ML)
  3. pré-processamento: pipeline de treino (torchvision) vs pipeline do app
     (resize 256 + center crop 256 -> recorte/normalização dentro do modelo)
  4. PyTorch vs TorchScript (o grafo efetivamente convertido)
  5. reprodução das probabilidades salvas em reports/val/predictions.csv
     (geradas com o PyTorch do treinamento)
  6. integridade estrutural do .mlpackage (spec, entradas, saídas, rótulos,
     iOS 15, pesos FP16, operações de pré-processamento no programa MIL)
  7. ESTIMATIVA do efeito de FP16 executando o modelo em half no PyTorch
     (não é Core ML; serve apenas como ordem de grandeza)

Usa o conjunto de VALIDAÇÃO (não o de teste). A equivalência numérica com o
Core ML só pode ser medida no macOS: src/validate_coreml_macos.py.

Uso:
    python src/validate_conversion.py
Saída: exports/conversion_validation_linux.json
"""
import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torchvision import models
from torchvision.transforms import functional as TF

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CLASSES, ROOT, eval_transform  # noqa: E402
from export_coreml import MODEL_INPUT_SIZE, load_inference_module  # noqa: E402


def app_input(img: Image.Image, size: int = MODEL_INPUT_SIZE) -> torch.Tensor:
    """Simula o pré-processamento do app: resize do lado menor + center crop 256, valores em [0,1]."""
    img = TF.resize(img, size)          # bilinear + antialias (mesmo do treino)
    img = TF.center_crop(img, size)
    return TF.to_tensor(img).unsqueeze(0)


def check(name, ok, detail, results):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print(f"[{'OK ' if ok else 'FALHA'}] {name}: {detail}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--weights", default=str(ROOT / "models" / "best_model.pt"))
    ap.add_argument("--config", default=str(ROOT / "configs" / "model_config.json"))
    ap.add_argument("--mlpackage", default=str(ROOT / "exports" / "EmberLens.mlpackage"))
    ap.add_argument("--splits", default=str(ROOT / "dataset" / "splits.csv"))
    ap.add_argument("--raw", default=str(ROOT / "dataset" / "raw"))
    ap.add_argument("--out", default=str(ROOT / "exports" / "conversion_validation_linux.json"))
    args = ap.parse_args()
    results = []
    config = json.loads(Path(args.config).read_text())
    torch.manual_seed(0)

    # 1. pesos e arquitetura
    state = torch.load(args.weights, map_location="cpu", weights_only=True)
    ref = models.mobilenet_v3_small(weights=None)
    ref.classifier[3] = torch.nn.Linear(1024, len(CLASSES))
    ref_shapes = {k: tuple(v.shape) for k, v in ref.state_dict().items()}
    got_shapes = {k: tuple(v.shape) for k, v in state.items()}
    check("arquitetura: chaves e formas do state_dict", ref_shapes == got_shapes,
          f"{len(got_shapes)} tensores; mismatches={sum(ref_shapes.get(k) != s for k, s in got_shapes.items())}",
          results)
    wrapper = load_inference_module(Path(args.weights), config)  # load_state_dict(strict=True)
    n_params = sum(p.numel() for p in wrapper.model.parameters())
    check("carregamento estrito dos pesos", True, f"strict=True, {n_params:,} parâmetros, dtype={next(iter(state.values())).dtype}",
          results)

    # 2. classes
    mapping = json.loads((ROOT / "configs" / "class_mapping.json").read_text())
    order_ok = config["classes"] == CLASSES and [k for k, _ in sorted(mapping.items(), key=lambda t: t[1])] == CLASSES
    check("ordem das classes (config/código/mapping)", order_ok, CLASSES, results)

    # dados de validação
    with open(args.splits) as fh:
        rows = [r for r in csv.DictReader(fh) if r["split"] == "val"]
    raw = Path(args.raw)
    tf = eval_transform(config["preprocess"])
    traced = torch.jit.trace(wrapper, torch.rand(1, 3, MODEL_INPUT_SIZE, MODEL_INPUT_SIZE))

    p_train, p_app, p_ts, p_half = [], [], [], []
    half_ok = True
    try:
        wrapper_half = load_inference_module(Path(args.weights), config).half()
    except Exception:  # noqa: BLE001
        half_ok = False
    with torch.no_grad():
        for r in rows:
            with Image.open(raw / r["path"]) as im:
                im = im.convert("RGB")
                x_train = tf(im).unsqueeze(0)
                x_app = app_input(im)
            p_train.append(torch.softmax(wrapper.model(x_train), 1)[0].numpy())
            p_app.append(wrapper(x_app)[0].numpy())
            p_ts.append(traced(x_app)[0].numpy())
            if half_ok:
                try:
                    p_half.append(wrapper_half(x_app.half())[0].float().numpy())
                except Exception:  # noqa: BLE001
                    half_ok = False
    P_train, P_app, P_ts = map(np.stack, (p_train, p_app, p_ts))
    y = np.array([CLASSES.index(r["label"]) for r in rows])

    # 3. pré-processamento
    d = np.abs(P_train - P_app)
    agree = (P_train.argmax(1) == P_app.argmax(1)).mean()
    check("pré-processamento: treino (Resize256+CenterCrop224+Normalize) vs entrada 256 com recorte/normalização no modelo",
          agree == 1.0 and d.max() < 0.05,
          f"n={len(rows)}, top-1 igual em {agree:.1%}, max |Δprob|={d.max():.2e}, média={d.mean():.2e}", results)

    # 4. TorchScript
    d_ts = np.abs(P_app - P_ts)
    check("PyTorch vs TorchScript (grafo convertido)", d_ts.max() < 1e-5,
          f"max |Δprob|={d_ts.max():.2e}, top-1 igual em {(P_app.argmax(1) == P_ts.argmax(1)).mean():.1%}", results)

    # 5. reprodução das predições salvas (PyTorch do treinamento)
    saved = {}
    with open(ROOT / "reports" / "val" / "predictions.csv") as fh:
        for r in csv.DictReader(fh):
            saved[r["path"]] = np.array([float(r[f"p_{c}"]) for c in CLASSES])
    S = np.stack([saved[r["path"]] for r in rows])
    d_s = np.abs(S - P_train)
    acc = (P_train.argmax(1) == y).mean()
    check("reprodução de reports/val/predictions.csv (ambiente de conversão vs treino)",
          d_s.max() < 1e-3 and (S.argmax(1) == P_train.argmax(1)).all(),
          f"max |Δprob|={d_s.max():.2e} (CSV com 4 casas), accuracy val={acc:.4f}", results)
    acc_app = (P_app.argmax(1) == y).mean()

    # 6. estrutura do Core ML
    import coremltools as ct
    spec = ct.utils.load_spec(args.mlpackage)
    desc = spec.description
    inp = desc.input[0]
    it = inp.type.imageType
    labels = json.loads(desc.metadata.userDefined["classes"])  # metadados gravados na exportação
    # rótulos do classificador: no ML Program ficam como valor imediato da op `classify`
    fn0 = spec.mlProgram.functions["main"]
    cls_op = [o for o in fn0.block_specializations[fn0.opset].operations if o.type == "classify"]
    cls_labels = []
    if cls_op:
        lst = cls_op[0].inputs["classes"].arguments[0].value.immediateValue.list.values
        cls_labels = [v.immediateValue.tensor.strings.values[0] for v in lst]
    check("Core ML: tipo de modelo", spec.WhichOneof("Type") == "mlProgram",
          f"{spec.WhichOneof('Type')}, specificationVersion={spec.specificationVersion}", results)
    check("Core ML: compatibilidade mínima iOS 15", spec.specificationVersion == 6,
          f"specificationVersion={spec.specificationVersion} (6 = iOS 15 / macOS 12)", results)
    check("Core ML: entrada", inp.name == "image" and it.width == 256 and it.height == 256
          and ct.proto.FeatureTypes_pb2.ImageFeatureType.ColorSpace.Name(it.colorSpace) == "RGB",
          f"{inp.name}: imagem {it.width}x{it.height} "
          f"{ct.proto.FeatureTypes_pb2.ImageFeatureType.ColorSpace.Name(it.colorSpace)}", results)
    outs = {o.name: o.type.WhichOneof("Type") for o in desc.output}
    check("Core ML: saídas", outs.get("classLabel") == "stringType" and outs.get("classLabel_probs") == "dictionaryType",
          outs, results)
    check("Core ML: rótulos do classificador na ordem do treino", cls_labels == CLASSES and labels == CLASSES,
          cls_labels, results)

    fn = spec.mlProgram.functions["main"]
    block = fn.block_specializations[fn.opset]
    ops = list(block.operations)
    counts = Counter(o.type for o in ops)
    const_dtypes = Counter()
    for o in ops:
        if o.type == "const":
            for out in o.outputs:
                if out.type.WhichOneof("type") == "tensorType":
                    const_dtypes[ct.proto.MIL_pb2.DataType.Name(out.type.tensorType.dataType)] += 1
    first = [o.type for o in ops if o.type != "const"][:8]
    check("Core ML: pesos em FP16", const_dtypes.get("FLOAT16", 0) > 0 and fn.opset in ("CoreML5", "CoreML6", "CoreML7", "CoreML8"),
          f"opset={fn.opset}, constantes por tipo={dict(const_dtypes)}", results)
    check("Core ML: pré-processamento embutido no programa",
          counts.get("slice_by_index", 0) >= 1 and counts.get("softmax", 0) == 1,
          f"primeiras operações: {first}; conv={counts.get('conv', 0)}, softmax={counts.get('softmax', 0)}, "
          f"total={len(ops)} ops; escala da entrada=1/255 (ImageType)", results)

    # 7. estimativa FP16 (PyTorch half, não Core ML)
    fp16 = None
    if half_ok and p_half:
        P_h = np.stack(p_half)
        fp16 = {"max_abs_diff_prob": float(np.abs(P_h - P_app).max()),
                "top1_agreement": float((P_h.argmax(1) == P_app.argmax(1)).mean())}
        print(f"[info] estimativa FP16 (PyTorch half em CPU, NÃO é Core ML): max |Δprob|={fp16['max_abs_diff_prob']:.2e}, "
              f"top-1 igual em {fp16['top1_agreement']:.1%}")

    size = sum(f.stat().st_size for f in Path(args.mlpackage).rglob("*") if f.is_file())
    report = {
        "environment": {"torch": torch.__version__, "coremltools": ct.__version__, "python": sys.version.split()[0],
                        "platform": sys.platform},
        "split_used": "val", "n_images": len(rows),
        "val_accuracy_pytorch_train_pipeline": float(acc),
        "val_accuracy_pytorch_app_pipeline": float(acc_app),
        "mlpackage_size_bytes": size,
        "checks": results,
        "fp16_estimate_pytorch_half": fp16,
        "coreml_runtime_inference": "NÃO executada: o runtime do Core ML só existe no macOS. "
                                    "Rode src/validate_coreml_macos.py em um Mac.",
        "all_passed": all(r["ok"] for r in results),
    }
    Path(args.out).write_text(json.dumps(report, indent=2, ensure_ascii=False, default=str))
    print(f"\n{'TODAS AS VERIFICAÇÕES PASSARAM' if report['all_passed'] else 'HÁ FALHAS'} -> {args.out}")
    sys.exit(0 if report["all_passed"] else 1)


if __name__ == "__main__":
    main()
