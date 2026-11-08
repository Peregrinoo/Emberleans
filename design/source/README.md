# design/source

Scripts que geram **todos** os artefatos visuais desta pasta. São a fonte editável: mude um token, uma medida ou um
texto e gere de novo.

| script | gera |
|---|---|
| `symbol.py` | geometria do símbolo (lente biconvexa + ponto focal) |
| `concepts.py` | os 3 conceitos de símbolo |
| `brand.py` | logotipos SVG (símbolo, horizontal, vertical × 5 variantes), com o nome convertido em curvas via HarfBuzz/fontTools |
| `icon.py` | App Icon SVG (light, dark, dark-preview, tinted) |
| `gen_photo.py` | fotografia ilustrativa procedural (sem lesão, sem foto real) |
| `screens.py` | mockups das telas, light/dark (HTML → PNG @3x) e tokens de cor usados neles |
| `sheets.py` | folhas de componentes, cores e tipografia |
| `boards.py` | pranchas de conceitos e do logotipo final |
| `flow.py` | fluxograma de navegação (SVG) |

## Requisitos

Python 3.11+, `numpy`, `pillow`, `fonttools`, `uharfbuzz`, Google Chrome (headless), `rsvg-convert` e ImageMagick.
Também são necessárias as fontes **Inter** e **Inter Display** (OFL) instaladas, em `InterDisplay-SemiBold.otf`
(caminho configurado em `brand.py`).

```bash
python gen_photo.py
python concepts.py && python brand.py && python icon.py
python screens.py out/screens && python sheets.py && python boards.py && python flow.py
```

Os scripts foram escritos para o ambiente em que os artefatos foram gerados (Linux). No macOS, ajuste o caminho da
fonte em `brand.py` e o executável do Chrome
(`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`) em `screens.py` e `sheets.py`.
