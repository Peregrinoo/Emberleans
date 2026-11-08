import math, uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from symbol import geom

INK="#151312"; PAPER="#F5F2EE"; EMB="#C4532C"
SYM=dict(d=60,r=16,gap=13)
FONT="/usr/share/fonts/opentype/inter/InterDisplay-SemiBold.otf"

def text_path(text, size, tracking=-0.01, font=FONT):
    blob=hb.Blob.from_file_path(font); face=hb.Face(blob); f=hb.Font(face)
    buf=hb.Buffer(); buf.add_str(text); buf.guess_segment_properties(); hb.shape(f,buf,{"kern":True,"liga":True})
    tt=TTFont(font); gs=tt.getGlyphSet(); upem=tt['head'].unitsPerEm; order=tt.getGlyphOrder()
    sc=size/upem; x=0; d=""
    for info,pos in zip(buf.glyph_infos,buf.glyph_positions):
        name=order[info.codepoint]
        pen=SVGPathPen(gs)
        tp=TransformPen(pen,(sc,0,0,-sc,(x+pos.x_offset)*sc,0))
        gs[name].draw(tp); d+=pen.getCommands()
        x+=pos.x_advance+tracking*upem
    width=(x-tracking*upem)*sc
    cap=tt['OS/2'].sCapHeight*sc
    return d,width,cap

def symbol_paths(fg,acc,scale=1.0,ox=0,oy=0,tight=True):
    g=geom(**SYM)
    # coords em caixa 120; tight => remove margem
    lx,cy,h,R,w=g['lx'],g['cy'],g['h'],g['R'],g['w']
    x0=lx-w/2 if tight else 0; y0=cy-h/2 if tight else 0
    T=lambda x,y:(ox+(x-x0)*scale, oy+(y-y0)*scale)
    a=T(lx,cy-h/2); b=T(lx,cy+h/2); Rs=R*scale
    dx,dy=T(g['dx'],cy)
    lens=f'<path id="lens" d="M{a[0]:.2f} {a[1]:.2f}A{Rs:.2f} {Rs:.2f} 0 0 1 {b[0]:.2f} {b[1]:.2f}A{Rs:.2f} {Rs:.2f} 0 0 1 {a[0]:.2f} {a[1]:.2f}Z" fill="{fg}"/>'
    dot=f'<circle id="focal-point" cx="{dx:.2f}" cy="{dy:.2f}" r="{g["r"]*scale:.2f}" fill="{acc}"/>'
    bw=(g['dx']+g['r']-x0)*scale; bh=h*scale
    return f'<g id="symbol">{lens}{dot}</g>', bw, bh

VARIANTS={  # nome: (cor da lente/texto, cor do ponto, fundo de preview)
 "color":(INK,EMB,"#FFFFFF"),
 "negative":(PAPER,EMB,"#000000"),
 "mono-black":(INK,INK,"#FFFFFF"),
 "mono-white":("#FFFFFF","#FFFFFF","#000000"),
 "accent":(EMB,EMB,"#FFFFFF"),
}
def svg(w,h,body,title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h:.0f}" width="{w:.0f}" height="{h:.0f}">'
            f'<title>{title}</title>{body}</svg>\n')

def build(outdir):
    import os; os.makedirs(outdir,exist_ok=True)
    out={}
    for v,(fg,acc,bg) in VARIANTS.items():
        # símbolo (quadrado 120, com respiro)
        g=geom(**SYM)
        s,_,_=symbol_paths(fg,acc,tight=False)
        out[f"emberlens-symbol-{v}.svg"]=svg(120,120,s,"EmberLens symbol")
        # horizontal
        size=100; d,tw,cap=text_path("EmberLens",size)
        symh=cap*1.62; sc=symh/g['h']
        s,bw,bh=symbol_paths(fg,acc,scale=sc)
        pad=cap*0.5; gap=cap*0.62
        W=pad*2+bw+gap+tw; H=pad*2+bh
        ty=pad+bh/2+cap/2
        body=s.replace('<g id="symbol">',f'<g id="symbol" transform="translate({pad:.2f},{pad:.2f})">')+f'<path id="wordmark" transform="translate({pad+bw+gap:.2f},{ty:.2f})" d="{d}" fill="{fg}"/>'
        out[f"emberlens-logo-horizontal-{v}.svg"]=svg(W,H,body,"EmberLens logo horizontal")
        # vertical
        symh2=cap*2.45; sc2=symh2/g['h']
        s2,bw2,bh2=symbol_paths(fg,acc,scale=sc2)
        Wv=max(bw2,tw)+pad*2; vgap=cap*0.7
        Hv=pad*2+bh2+vgap+cap
        body=s2.replace('<g id="symbol">',f'<g id="symbol" transform="translate({(Wv-bw2)/2:.2f},{pad:.2f})">')+f'<path id="wordmark" transform="translate({(Wv-tw)/2:.2f},{pad+bh2+vgap+cap:.2f})" d="{d}" fill="{fg}"/>'
        out[f"emberlens-logo-vertical-{v}.svg"]=svg(Wv,Hv,body,"EmberLens logo vertical")
    for k,v in out.items(): open(os.path.join(outdir,k),"w").write(v)
    return out
if __name__=="__main__":
    out=build("out/logo")
    cells=""
    for k in sorted(out):
        v=k.split("-",3)[-1].replace(".svg","")
        bg=VARIANTS[[x for x in VARIANTS if k.endswith(x+".svg")][0]][2]
        cells+=f'<div style="background:{bg};padding:24px;display:flex;align-items:center;justify-content:center;height:160px"><img src="out/logo/{k}" style="max-height:110px;max-width:440px"></div>'
    open("logos.html","w").write(f'<html><body style="margin:0;background:#888;display:grid;grid-template-columns:repeat(3,1fr);gap:4px">{cells}</body></html>')
