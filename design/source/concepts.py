# Gera os 3 conceitos de símbolo como SVG (viewBox 120x120) + folha de comparação
EMB="#C8532C"; INK="#151312"
def focal(fg=INK, acc=EMB):
    # lente biconvexa (interseção de 2 círculos R=60, d=72): w=48, h=96 ; ponto focal r=12
    cx, cy = 44, 60
    lens=f'<path d="M{cx} {cy-48} A60 60 0 0 1 {cx} {cy+48} A60 60 0 0 1 {cx} {cy-48}Z" fill="{fg}"/>'
    dot=f'<circle cx="{cx+52}" cy="{cy}" r="12" fill="{acc}"/>'
    return lens+dot
def nucleo(fg=INK, acc=EMB):
    return f'<circle cx="60" cy="60" r="41" fill="none" stroke="{fg}" stroke-width="13"/><circle cx="68" cy="52" r="15" fill="{acc}"/>'
def intersec(fg=INK, acc=EMB):
    return (f'<circle cx="44" cy="60" r="33" fill="none" stroke="{fg}" stroke-width="9"/>'
            f'<circle cx="76" cy="60" r="33" fill="none" stroke="{fg}" stroke-width="9"/>'
            f'<path d="M60 32.3 A33 33 0 0 1 60 87.7 A33 33 0 0 1 60 32.3Z" fill="{acc}"/>')
C={"focal":focal,"nucleo":nucleo,"intersec":intersec}
for k,f in C.items():
    open(f"concept-{k}.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">{f()}</svg>')
# folha
rows=""
for k,f in C.items():
    cells=""
    for bg,fg in (("#FFFFFF",INK),("#000000","#F5F2EE")):
        for s in (160,48,29,16):
            cells+=f'<div style="background:{bg};width:180px;height:180px;display:flex;align-items:center;justify-content:center"><svg width="{s}" height="{s}" viewBox="0 0 120 120">{f(fg)}</svg></div>'
    rows+=f'<div style="display:flex;gap:4px;margin-bottom:4px">{cells}</div>'
open("concepts.html","w").write(f'<html><body style="margin:0;background:#888">{rows}</body></html>')
