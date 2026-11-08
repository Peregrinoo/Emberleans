W,H=1440,820
EMB="#C4532C"; INK="#151312"; G="#8A847F"; RED="#FF3B30"
els=[]
def node(x,y,w,h,title,sub="",kind="screen"):
    st={"screen":f'fill="#fff" stroke="{INK}" stroke-width="1.5"',"system":f'fill="#F5F2EE" stroke="{G}" stroke-width="1.2" stroke-dasharray="5 4"',
        "process":f'fill="{EMB}"',"error":f'fill="#fff" stroke="{RED}" stroke-width="1.2"',"modal":f'fill="#fff" stroke="{EMB}" stroke-width="1.6"'}[kind]
    tc="#fff" if kind=="process" else INK; sc="#fff" if kind=="process" else G
    els.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" {st}/>')
    els.append(f'<text x="{x+w/2}" y="{y+h/2-(5 if sub else -5)}" text-anchor="middle" font-family="Inter" font-weight="600" font-size="15" fill="{tc}">{title}</text>')
    if sub: els.append(f'<text x="{x+w/2}" y="{y+h/2+14}" text-anchor="middle" font-family="Inter" font-size="12" fill="{sc}">{sub}</text>')
def path(pts,color=INK,dash=False):
    d="M"+" L".join(f"{x} {y}" for x,y in pts)
    els.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="1.4" stroke-linejoin="round" {"stroke-dasharray=\"5 4\"" if dash else ""} marker-end="url(#{"ar" if color==RED else "ag" if color==G else "a"})"/>')
def label(x,y,t,anchor="middle",color=G):
    els.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Inter" font-size="12" fill="{color}" stroke="#fff" stroke-width="5" paint-order="stroke">{t}</text>')
node(40,268,150,64,"Home","tela 01")
node(40,470,150,64,"Sobre o EmberLens","tela 04")
node(250,268,170,64,"Origem da imagem","sheet",kind="modal")
node(500,150,190,64,"Câmera","interface do sistema",kind="system")
node(500,420,190,64,"Fototeca","PhotosPicker · 1 imagem",kind="system")
node(780,268,160,64,"Prévia","tela 02 · Nova análise")
node(1000,268,170,64,"Inferência local","Vision + Core ML",kind="process")
node(1230,268,160,64,"Resultado","tela 03")
node(380,30,215,50,"Permissão negada","alerta → Ajustes / Fototeca",kind="error")
node(615,30,195,50,"Câmera indisponível","alerta → Fototeca",kind="error")
node(830,30,190,50,"Erro de captura","alerta → tentar novamente",kind="error")
node(490,560,210,50,"Falha ao carregar","alerta → escolher outra",kind="error")
node(820,430,190,50,"Imagem inválida","estado de erro na prévia",kind="error")
node(1180,430,210,50,"Erro de inferência","tentar novamente / outra",kind="error")
# caminho principal
path([(190,300),(250,300)]); label(220,290,"Analisar")
path([(115,332),(115,470)]); label(125,405,"ícone ⓘ","start")
path([(420,290),(460,290),(460,182),(500,182)]); label(452,240,"Tirar foto","end")
path([(420,310),(460,310),(460,452),(500,452)]); label(452,372,"Escolher da","end"); label(452,387,"Fototeca","end")
path([(690,182),(735,182),(735,290),(780,290)]); label(742,240,"foto confirmada","start")
path([(690,452),(735,452),(735,310),(780,310)]); label(742,392,"imagem carregada","start")
path([(940,300),(1000,300)]); label(970,290,"Analisar")
path([(1170,300),(1230,300)]); label(1200,290,"concluída")
path([(1310,268),(1310,118),(335,118),(335,268)]); label(1000,111,"Analisar outra imagem",color=INK)
path([(800,332),(800,690),(300,690),(300,332)]); label(560,683,"Escolher outra imagem",color=INK)
path([(500,468),(362,468),(362,332)],color=G,dash=True); label(372,500,"seleção cancelada: volta","start")
# erros
path([(560,150),(487,80)],RED,True); path([(595,150),(712,80)],RED,True); path([(630,150),(925,80)],RED,True)
path([(595,484),(595,560)],RED,True)
path([(860,332),(915,430)],RED,True)
path([(1085,332),(1285,430)],RED,True)
label(40,750,"Sem Tab Bar: NavigationStack (Home → Prévia → Resultado; Home → Sobre). “Origem da imagem” é um sheet próprio; Câmera e Fototeca são interfaces do sistema.","start")
legend=[("Tela própria",f'fill="#fff" stroke="{INK}" stroke-width="1.5"'),("Modal próprio",f'fill="#fff" stroke="{EMB}" stroke-width="1.5"'),
        ("Interface do sistema",f'fill="#F5F2EE" stroke="{G}" stroke-dasharray="5 4"'),("Processamento",f'fill="{EMB}"'),("Erro / permissão",f'fill="#fff" stroke="{RED}"')]
for i,(t,st) in enumerate(legend):
    x=40+i*200; els.append(f'<rect x="{x}" y="774" width="26" height="18" rx="5" {st}/><text x="{x+36}" y="788" font-family="Inter" font-size="12" fill="{INK}">{t}</text>')
mk=lambda i,c: f'<marker id="{i}" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto"><path d="M0 0 10 5 0 10z" fill="{c}"/></marker>'
svg=(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}"><rect width="{W}" height="{H}" fill="#fff"/>'
     f'<defs>{mk("a",INK)}{mk("ar",RED)}{mk("ag",G)}</defs>' + "".join(els) + '</svg>')
import os; os.makedirs("out/flow",exist_ok=True); open("out/flow/navigation-flow.svg","w").write(svg)
