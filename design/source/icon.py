from symbol import geom
SYM=dict(d=60,r=16,gap=13)
INK="#151312"; PAPER="#F5F2EE"; EMB="#C4532C"
def sym(scale, ox, oy, lens_fill, dot_fill):
    g=geom(**SYM); lx,cy,h,R,w=g['lx'],g['cy'],g['h'],g['R'],g['w']
    x0=lx-w/2; y0=cy-h/2
    T=lambda x,y:(ox+(x-x0)*scale, oy+(y-y0)*scale)
    a=T(lx,cy-h/2); b=T(lx,cy+h/2); Rs=R*scale; dx,dy=T(g['dx'],cy)
    bw=(g['dx']+g['r']-x0)*scale; bh=h*scale
    return (f'<path id="lens" d="M{a[0]:.1f} {a[1]:.1f}A{Rs:.1f} {Rs:.1f} 0 0 1 {b[0]:.1f} {b[1]:.1f}A{Rs:.1f} {Rs:.1f} 0 0 1 {a[0]:.1f} {a[1]:.1f}Z" fill="{lens_fill}"/>',
            f'<circle id="focal-point" cx="{dx:.1f}" cy="{dy:.1f}" r="{g["r"]*scale:.1f}" fill="{dot_fill}"/>', bw, bh)
def icon(variant, S=1024, width_ratio=0.56, optical_dx=0.022):
    g=geom(**SYM); bw0=(g['dx']+g['r']-(g['lx']-g['w']/2)); sc=S*width_ratio/bw0
    bw=bw0*sc; bh=g['h']*sc
    ox=(S-bw)/2+S*optical_dx; oy=(S-bh)/2
    defs='''<defs>
<linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FAF8F5"/><stop offset="1" stop-color="#EEE9E3"/></linearGradient>
<linearGradient id="ink" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#211C1A"/><stop offset="1" stop-color="#110F0E"/></linearGradient>
<radialGradient id="ember" cx="0.38" cy="0.34" r="0.75"><stop offset="0" stop-color="#E2774D"/><stop offset="1" stop-color="#C4532C"/></radialGradient>
<radialGradient id="emberDark" cx="0.38" cy="0.34" r="0.75"><stop offset="0" stop-color="#F08A62"/><stop offset="1" stop-color="#D45F36"/></radialGradient>
</defs>'''
    if variant=="light":
        bg=f'<rect id="background" width="{S}" height="{S}" fill="url(#paper)"/>'; lens,dot,_,_=sym(sc,ox,oy,INK,"url(#ember)")
    elif variant=="dark":  # fundo transparente: o sistema aplica o fundo escuro (iOS 18+)
        bg=""; lens,dot,_,_=sym(sc,ox,oy,PAPER,"url(#emberDark)")
    elif variant=="dark-preview":  # mesma arte sobre o fundo escuro, para apresentação
        bg=f'<rect id="background" width="{S}" height="{S}" fill="url(#ink)"/>'; lens,dot,_,_=sym(sc,ox,oy,PAPER,"url(#emberDark)")
    elif variant=="tinted":  # escala de cinza sobre transparente; o sistema aplica a cor
        bg=""; lens,dot,_,_=sym(sc,ox,oy,"#BDBDBD","#FFFFFF")
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}" width="{S}" height="{S}">{defs}{bg}<g id="symbol">{lens}{dot}</g></svg>\n'
if __name__=="__main__":
    import os; os.makedirs("out/icon",exist_ok=True)
    for v in ("light","dark","dark-preview","tinted"):
        open(f"out/icon/AppIcon-{v}.svg","w").write(icon(v))
