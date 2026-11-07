"""Grad-CAM para MobileNetV3 Small (última camada convolucional de `features`)."""
import numpy as np
import torch
import torch.nn.functional as F
from matplotlib import colormaps
from PIL import Image


class GradCAM:
    def __init__(self, model, target_layer=None):
        self.model = model
        self.layer = target_layer if target_layer is not None else model.features[-1]
        self.acts = None
        self.grads = None
        self.h1 = self.layer.register_forward_hook(self._fwd)

    def _fwd(self, _m, _i, out):
        self.acts = out
        out.register_hook(self._bwd)

    def _bwd(self, g):
        self.grads = g

    def __call__(self, x, class_idx=None):
        """x: tensor 1x3xHxW normalizado. Retorna (cam HxW em [0,1], probs, class_idx)."""
        self.model.eval()
        x = x.clone().requires_grad_(True)  # garante grafo mesmo com backbone congelado
        logits = self.model(x)
        probs = torch.softmax(logits, 1)[0].detach().cpu().numpy()
        if class_idx is None:
            class_idx = int(probs.argmax())
        self.model.zero_grad(set_to_none=True)
        logits[0, class_idx].backward()
        w = self.grads.mean(dim=(2, 3), keepdim=True)
        cam = F.relu((w * self.acts).sum(1, keepdim=True))
        cam = F.interpolate(cam, size=x.shape[-2:], mode="bilinear", align_corners=False)[0, 0]
        cam = cam.detach().cpu().numpy()
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        return cam, probs, class_idx

    def remove(self):
        self.h1.remove()


def overlay(rgb_uint8: np.ndarray, cam: np.ndarray, alpha=0.45) -> Image.Image:
    heat = (colormaps["jet"](cam)[..., :3] * 255).astype(np.float32)
    out = rgb_uint8.astype(np.float32) * (1 - alpha) + heat * alpha
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))
