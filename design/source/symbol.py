import math
EMB="#C4532C"; INK="#151312"
def geom(R=60,d=64,r=15,gap=14,box=120):
    w=2*R-d; h=2*math.sqrt(R*R-(d/2)**2)
    total=w+gap+2*r
    x0=(box-total)/2
    lx=x0+w/2; cy=box/2
    return dict(R=R,w=w,h=h,lx=lx,cy=cy,dx=lx+w/2+gap+r,r=r)
def symbol(fg=INK,acc=EMB,**k):
    g=geom(**k); lx,cy,h,R=g['lx'],g['cy'],g['h'],g['R']
    return (f'<path d="M{lx:.2f} {cy-h/2:.2f}A{R} {R} 0 0 1 {lx:.2f} {cy+h/2:.2f}A{R} {R} 0 0 1 {lx:.2f} {cy-h/2:.2f}Z" fill="{fg}"/>'
            f'<circle cx="{g["dx"]:.2f}" cy="{cy:.2f}" r="{g["r"]}" fill="{acc}"/>')
if __name__=="__main__":
    vars_=[dict(),dict(d=60,r=16,gap=13),dict(d=56,r=16,gap=14)]
    rows=""
    for v in vars_:
        cells=""
        for bg,fg in (("#FFFFFF",INK),("#000000","#F5F2EE")):
            for s in (160,48,29,16):
                cells+=f'<div style="background:{bg};width:180px;height:180px;display:flex;align-items:center;justify-content:center"><svg width="{s}" height="{s}" viewBox="0 0 120 120">{symbol(fg,**v)}</svg></div>'
        rows+=f'<div style="display:flex;gap:4px;margin-bottom:4px">{cells}</div>'
    open("sym.html","w").write(f'<html><body style="margin:0;background:#888">{rows}</body></html>')
