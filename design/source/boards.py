"""Pranchas de marca: conceitos de logotipo e logotipo final (HTML -> PNG)."""
import base64, os
import concepts, symbol
from sheets import shot
from brand import build, VARIANTS
INK="#151312"; EMB="#C4532C"
def svg_inline(body, s=150): return f'<svg width="{s}" height="{s}" viewBox="0 0 120 120">{body}</svg>'
CSS="""body{margin:0;font-family:Inter;color:#151312;background:#fff}.b{padding:56px}
h1{font:700 30px/36px 'Inter Display';letter-spacing:-.02em;margin:0}
h2{font:600 20px/26px 'Inter Display';margin:0 0 6px}
.lab{font:600 12px Inter;letter-spacing:.08em;text-transform:uppercase;color:#8a847f}
p{font:400 14px/20px Inter;color:#55504c;margin:6px 0 0}
.tile{display:flex;align-items:center;justify-content:center;border-radius:14px}
"""
def concepts_board():
    items=[("01 · Ponto focal — selecionado", symbol.symbol(INK,EMB,d=60,r=16,gap=13), symbol.symbol("#F5F2EE",EMB,d=60,r=16,gap=13),
            "Lente biconvexa (interseção de dois círculos) e o ponto onde a luz converge. Uma lente concentrando luz é literalmente como se acende uma brasa: o nome inteiro em dois sólidos geométricos. Silhueta única, legível a 29 px, sem chama nem olho.", True),
           ("02 · Núcleo", concepts.nucleo(INK,EMB), concepts.nucleo("#F5F2EE",EMB),
            "Anel de lente com um núcleo incandescente. Simples, mas genérico: lê-se como botão de gravação, alvo ou olho, e não diferencia o app de câmeras e scanners.", False),
           ("03 · Interseção", concepts.intersec(INK,EMB), concepts.intersec("#F5F2EE",EMB),
            "Dois anéis cuja interseção forma a lente. Conceito óptico correto, porém mais elementos, traços finos que somem em tamanhos pequenos e semelhança com a marca de uma bandeira de cartão.", False)]
    cols=""
    for t,l,d,txt,sel in items:
        border="2px solid #C4532C" if sel else "1px solid #e7e2dc"
        small="".join(f'<svg width="{s}" height="{s}" viewBox="0 0 120 120" style="margin-right:14px">{l}</svg>' for s in (48,29,16))
        cols+=(f'<div style="flex:1;border:{border};border-radius:18px;padding:22px">'
               f'<div style="display:flex;gap:10px"><div class="tile" style="background:#fff;border:1px solid #eee;width:50%;height:200px">{svg_inline(l)}</div>'
               f'<div class="tile" style="background:#000;width:50%;height:200px">{svg_inline(d)}</div></div>'
               f'<div style="margin-top:14px;display:flex;align-items:center">{small}</div>'
               f'<h2 style="margin-top:16px">{t}</h2><p>{txt}</p></div>')
    html=f'<html><head><style>{CSS}</style></head><body><div class="b"><div class="lab">EmberLens · Identidade</div><h1>Três conceitos de símbolo</h1><div style="display:flex;gap:20px;margin-top:28px">{cols}</div></div></body></html>'
    shot(html,"out/logo-boards/logo-concepts.png",1500,820)
def final_board():
    out=build("out/logo")
    def tile(name,bg,h=110,w="100%"):
        data=base64.b64encode(open(f"out/logo/{name}","rb").read()).decode()
        return f'<div class="tile" style="background:{bg};height:220px;border:1px solid #eee"><img src="data:image/svg+xml;base64,{data}" style="max-height:{h}px;max-width:80%"></div>'
    grid=lambda items: '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:12px">'+"".join(f'<div>{tile(n,b,h)}<p>{c}</p></div>' for n,b,h,c in items)+'</div>'
    import math
    g=symbol.geom(d=60,r=16,gap=13)
    xa=g["lx"]-92; xb=g["lx"]+92
    constr=(f'<svg width="520" height="300" viewBox="{xa:.1f} -4 {xb-xa:.1f} 138"><g fill="none" stroke="#C4532C" stroke-width=".4" stroke-dasharray="1.5 1.5">'
            f'<circle cx="{g["lx"]-30}" cy="60" r="60"/><circle cx="{g["lx"]+30}" cy="60" r="60"/>'
            f'<line x1="{xa:.1f}" y1="60" x2="{xb:.1f}" y2="60"/><circle cx="{g["dx"]}" cy="60" r="{g["r"]}"/></g>'
            f'{symbol.symbol(INK+"cc","#C4532C",d=60,r=16,gap=13)}'
            f'<text x="{g["lx"]}" y="131" font-size="4.5" text-anchor="middle" font-family="Inter" fill="#8a847f">R = 60 · d = 60 · lente {g["w"]:.0f} × {g["h"]:.0f}</text>'
            f'<text x="{g["dx"]}" y="84" font-size="4.5" text-anchor="middle" font-family="Inter" fill="#8a847f">r = 16</text></svg>')
    html=(f'<html><head><style>{CSS}</style></head><body><div class="b"><div class="lab">EmberLens · Identidade</div><h1>Logotipo final: Ponto focal</h1>'
          f'<div style="display:flex;gap:40px;align-items:center;margin-top:20px"><div>{constr}</div><div style="max-width:620px"><h2>Construção</h2>'
          f'<p>Lente: interseção de dois círculos de raio 60 com centros a 60 unidades. Ponto focal: círculo r = 16, alinhado ao eixo óptico, a 13 unidades da lente. '
          f'Nome em Inter Display Semibold, convertido em curvas, tracking −1%. Área de proteção: altura do ponto focal (2r) em todos os lados. '
          f'Tamanho mínimo: símbolo 16 px; logotipo horizontal 96 px de largura.</p></div></div>'
          + '<h2 style="margin-top:34px">Horizontal</h2>' + grid([("emberlens-logo-horizontal-color.svg","#fff",90,"Cor · fundos claros"),("emberlens-logo-horizontal-negative.svg","#000",90,"Negativa · fundos escuros"),("emberlens-logo-horizontal-accent.svg","#fff",90,"Cor de destaque")])
          + '<h2 style="margin-top:28px">Vertical e símbolo</h2>' + grid([("emberlens-logo-vertical-color.svg","#fff",160,"Vertical · cor"),("emberlens-symbol-mono-black.svg","#fff",120,"Símbolo · monocromático"),("emberlens-symbol-mono-white.svg","#C4532C",120,"Símbolo · monocromático branco sobre Ember")])
          + '</div></body></html>')
    shot(html,"out/logo-boards/logo-final.png",1500,1260)
if __name__=="__main__":
    concepts_board(); final_board()
