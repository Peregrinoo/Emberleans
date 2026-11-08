"""Folhas de documentação visual: componentes, cores e tipografia (HTML -> PNG)."""
import os, subprocess
import screens as S

OUT = "out"

def lum(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def cr(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True); return (la + 0.05) / (lb + 0.05)

def shot(html, path, w, h):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path.replace(".png", ".html"); open(tmp, "w").write(html)
    subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=2",
                    f"--window-size={w},{h}", f"--screenshot={path}", f"file://{os.path.abspath(tmp)}"],
                   stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, check=True)
    os.remove(tmp)

BOARD_CSS = """
html,body{width:auto!important}
.board{padding:48px 56px;background:var(--bg);color:var(--label);min-height:100vh}
.board h1{font:700 30px/36px 'Inter Display';letter-spacing:-.02em}
.board h2{font:600 13px/16px 'Inter';letter-spacing:.08em;text-transform:uppercase;color:var(--label2);margin:40px 0 14px}
.grid{display:grid;gap:20px}
.spec{font:400 12px/16px 'Inter';color:var(--label2);margin-top:8px}
.cell{display:flex;flex-direction:column}
"""

def board(mode, inner, title):
    return (f'<!DOCTYPE html><html><head><meta charset="utf-8"><style>{S.tokens_css(mode)}{S.CSS}{BOARD_CSS}</style></head>'
            f'<body><div class="board"><h1>{title}</h1>{inner}</div></body></html>')

def components(mode):
    t = S.TOKENS[mode]
    c = lambda inner, spec, w=320: f'<div class="cell" style="width:{w}px">{inner}<div class="spec">{spec}</div></div>'
    btns = ('<div class="grid" style="grid-template-columns:repeat(3,320px)">'
            + c('<div class="btn primary">Analisar imagem</div>', 'Primário · padrão<br>altura 52 · raio 14 contínuo · Headline · fill <b>accent</b>')
            + c('<div class="btn primary" style="filter:brightness(.86)">Analisar imagem</div>', 'Primário · pressionado<br>escurecimento do sistema (≈ −14%)')
            + c('<div class="btn disabled">Analisar imagem</div>', 'Primário · desabilitado<br>fill quaternário · texto <b>disabled</b>')
            + c(f'<div class="btn disabled" style="gap:10px">{S.spinner(t["label2"])}Analisando…</div>', 'Primário · processando<br>ProgressView + rótulo; não clicável')
            + c('<div class="btn secondary">Escolher outra imagem</div>', 'Secundário · tinted<br>fill accent 10–14% · texto <b>accentText</b>')
            + c('<div class="btn plain">Escolher outra imagem</div>', 'Terciário · plain<br>usado abaixo do primário')
            + '</div>')
    icons = ('<div class="grid" style="grid-template-columns:260px 393px 393px">'
             + c(f'<div style="display:flex;gap:18px;align-items:center"><div class="navbtn" style="color:var(--label2);outline:1px dashed var(--label3)">{S.ico("info.circle",23)}</div>'
                 f'<div class="navbtn" style="outline:1px dashed var(--label3)">{S.ico("chevron.left",24)}</div></div>',
                 'Botão de ícone · área de toque 44 × 44 (tracejado)<br>info.circle (secondary) · chevron.left (accentText)', 260)
             + c(f'<div style="background:var(--bg);border:.5px solid var(--separator);border-radius:12px;overflow:hidden">{S.nav("Resultado")}</div>',
                 'Barra de navegação · inline<br>44 pt · título Headline centralizado · voltar nativo', 393)
             + c(f'<div style="background:var(--bg);border:.5px solid var(--separator);border-radius:12px;overflow:hidden">'
                 f'{S.nav(left="<div style=padding-left:12px>"+S.wordmark(mode)+"</div>", right="<div class=navbtn style=color:var(--label2)>"+S.ico("info.circle",23)+"</div>")}</div>',
                 'Barra da Home · marca à esquerda (símbolo 21 pt + nome)<br>sem título; ícone de informações à direita', 393)
             + '</div>')
    sheet_html = ('<div style="position:relative;height:330px;width:393px;border-radius:16px;overflow:hidden;background:var(--bg)">'
                  + S.source_sheet(mode) + '</div>')
    al = S.ALERTS["camera-permission-denied"]
    alert_html = ('<div style="position:relative;height:330px;width:393px;border-radius:16px;overflow:hidden;background:var(--bg)">'
                  + S.alert(*al) + '</div>')
    modals = ('<div class="grid" style="grid-template-columns:repeat(2,420px)">'
              + c(sheet_html, 'Modal de seleção da origem · sheet com detent de altura (~300 pt)<br>grabber · título + subtítulo · lista inset agrupada · Cancelar', 393)
              + c(alert_html, 'Alerta / action sheet do sistema · UIAlertController / .alert<br>ação preferida em negrito · usado para permissões e falhas', 393)
              + '</div>')
    top = '<div style="margin-top:0">' + ''.join([
        f'<div style="display:flex;justify-content:space-between"><span class="sub" style="font-weight:600">Queimadura</span><span class="sub num acc" style="font-weight:600">72%</span></div><div class="bar top" style="margin-top:6px"><i style="width:72%"></i></div>',
        f'<div style="display:flex;justify-content:space-between;margin-top:14px"><span class="sub">Abrasão</span><span class="sub num l2">14%</span></div><div class="bar" style="margin-top:6px"><i style="width:14%"></i></div>']) + '</div>'
    result_hdr = ('<div><div style="display:flex;align-items:center;gap:7px"><span style="width:7px;height:7px;border-radius:50%;background:var(--accent)"></span>'
                  '<span class="c2 l2">Classificação experimental</span></div><div class="lt" style="margin-top:6px">Queimadura</div>'
                  '<div class="callout l2" style="margin-top:4px">Pontuação do modelo: <b class="num" style="color:var(--label)">72%</b></div></div>')
    data = ('<div class="grid" style="grid-template-columns:repeat(3,320px)">'
            + c(result_hdr, 'Componente de resultado<br>rótulo Caption2 caps + ponto Ember 7 pt · classe em Large Title · pontuação Callout')
            + c(top, 'Barras de distribuição<br>altura 6 · raio 3 · trilho fill quaternário · maior classe: accentText + semibold + valor em destaque (não depende só da cor)')
            + c(f'<div style="display:flex;align-items:center;gap:10px">{S.spinner(t["label2"])}<span class="hl">Analisando no dispositivo…</span></div>'
                '<p class="sub l2" style="margin-top:4px">Isso costuma levar menos de um segundo.</p>',
                'Indicador de processamento<br>ProgressView circular padrão · sem barra de progresso falsa, sem animação de escaneamento')
            + '</div>')
    notices = ('<div class="grid" style="grid-template-columns:repeat(3,320px)">'
               + c(f'<div class="notice"><span class="l2" style="margin-top:1px">{S.ico("info.circle",18)}</span><span class="fn l2">Esta classificação é experimental e não constitui um diagnóstico médico.</span></div>',
                   'Aviso informativo<br>fill quaternário · raio 12 · Footnote secondary · ícone info.circle')
               + c(f'<div><div style="color:var(--error)">{S.ico("exclamationmark.triangle",28,w=1.8)}</div><div class="t3" style="margin-top:8px">Não foi possível analisar a imagem</div>'
                   '<div class="sub l2" style="margin-top:4px">Nenhuma classificação foi gerada.</div></div>',
                   'Mensagem de erro (em tela)<br>ícone systemRed + Title3 + Subheadline; ação de recuperação abaixo')
               + c(f'<div style="height:200px;border-radius:16px;background:var(--fill4);display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 24px">'
                   f'<span class="l2">{S.ico("photo.badge.exclamationmark",38,w=1.5)}</span><div class="hl" style="margin-top:12px">Não foi possível carregar a imagem</div>'
                   '<div class="fn l2" style="margin-top:4px">Escolha outra imagem para continuar.</div></div>',
                   'Estado vazio / indisponível<br>ícone 38–44 pt secondary · Headline · Footnote · ocupa a área da foto')
               + '</div>')
    return board(mode, '<h2>Botões</h2>' + btns + '<h2>Ícones e navegação</h2>' + icons + '<h2>Modais</h2>' + modals
                 + '<h2>Resultado e processamento</h2>' + data + '<h2>Avisos, erros e estados vazios</h2>' + notices,
                 f'EmberLens · Componentes ({"Light" if mode == "light" else "Dark"} Mode)')

def colors():
    ember = [("Ember 50", "#FBEEE8"), ("Ember 100", "#F6D9CC"), ("Ember 300", "#EC8157"), ("Ember 500 · ref.", "#D96B45"),
             ("Ember 600 · primária", "#C4532C"), ("Ember 700", "#A3421F"), ("Ember 900", "#4A1D0E")]
    neutral = [("Ink", "#151312"), ("Graphite", "#2A2624"), ("Stone", "#8A847F"), ("Mist", "#E7E2DC"), ("Paper", "#F5F2EE"), ("White", "#FFFFFF")]
    sw = lambda n, h: (f'<div style="width:150px"><div style="height:96px;border-radius:12px;background:{h};border:.5px solid rgba(0,0,0,.08)"></div>'
                       f'<div class="fn" style="font-weight:600;margin-top:8px">{n}</div><div class="c1 num l2">{h} · branco {cr(h,"#FFFFFF"):.2f} · preto {cr(h,"#000000"):.2f}</div></div>')
    rows = [
        ("background", "systemBackground", "#FFFFFF", "#000000"),
        ("surface", "secondarySystemBackground", "#F2F2F7", "#1C1C1E"),
        ("surfaceElevated (sheet/grupo)", "secondarySystemBackground / tertiary", "#F2F2F7 · #FFFFFF", "#1C1C1E · #2C2C2E"),
        ("textPrimary", "label", "#000000", "#FFFFFF"),
        ("textSecondary", "secondaryLabel", "#3C3C43 @ 60%", "#EBEBF5 @ 60%"),
        ("textTertiary", "tertiaryLabel", "#3C3C43 @ 30%", "#EBEBF5 @ 30%"),
        ("accent (fill de botões)", "AccentColor (asset)", "#C4532C", "#C4532C"),
        ("accentText (texto/tint/barra)", "EmberText (asset)", "#C4532C", "#EC8157"),
        ("onAccent", "white", "#FFFFFF", "#FFFFFF"),
        ("border / separator", "separator", "#3C3C43 @ 29%", "#545458 @ 65%"),
        ("disabled", "quaternarySystemFill + tertiaryLabel", "#787880 @ 12%", "#787880 @ 24%"),
        ("error", "systemRed", "#FF3B30", "#FF453A"),
        ("success", "systemGreen", "#34C759", "#30D158"),
        ("barTrack", "quaternarySystemFill", "#747480 @ 8%", "#767680 @ 18%"),
        ("barNeutral", "systemGray3", "#C7C7CC", "#48484A"),
        ("lensFill (gráfico da Home)", "LensFill (asset)", "#F1ECE6", "#1E1B19"),
    ]
    def chip(v):
        hexes = [p for p in v.replace("·", " ").split() if p.startswith("#")]
        h = hexes[0] if hexes else "#FFFFFF"
        op = 1.0
        if "@" in v: op = int(v.split("@")[1].strip().rstrip("%")) / 100
        return f'<span style="display:inline-block;width:18px;height:18px;border-radius:5px;background:{h};opacity:{op};border:.5px solid rgba(0,0,0,.15);vertical-align:middle;margin-right:8px"></span>'
    tr = "".join(f'<tr><td class="fn" style="font-weight:600">{a}</td><td class="fn l2">{b}</td><td class="fn num">{chip(l)}{l}</td>'
                 f'<td class="fn num" style="background:#111;color:#eee">{chip(d)}{d}</td></tr>' for a, b, l, d in rows)
    checks = [("Branco sobre Ember 600 (botão)", cr("#FFFFFF", "#C4532C")), ("Ember 600 sobre branco (texto light)", cr("#C4532C", "#FFFFFF")),
              ("Ember 300 sobre #000 (texto dark)", cr("#EC8157", "#000000")), ("Ember 300 sobre #1C1C1E (texto dark em superfície)", cr("#EC8157", "#1C1C1E")),
              ("Ember 600 sobre #000 (botão no dark, contraste de componente)", cr("#C4532C", "#000000")), ("Referência #D96B45: branco sobre ela", cr("#FFFFFF", "#D96B45"))]
    ck = "".join(f'<tr><td class="fn" style="padding-right:32px">{n}</td><td class="fn num" style="font-weight:600;padding-right:24px">{v:.2f}:1</td><td class="fn">{"AA texto" if v>=4.5 else "AA grande/componente" if v>=3 else "reprovado"}</td></tr>' for n, v in checks)
    inner = ('<h2>Ember · acento</h2><div style="display:flex;gap:14px;flex-wrap:wrap">' + "".join(sw(*e) for e in ember) + '</div>'
             '<h2>Neutros da marca (uso em marca/ícone; a interface usa as cores semânticas do iOS)</h2><div style="display:flex;gap:14px;flex-wrap:wrap">' + "".join(sw(*n) for n in neutral) + '</div>'
             '<h2>Tokens semânticos</h2><table style="border-collapse:collapse;width:1180px" cellpadding="9">'
             '<tr><th class="c2 l2" align="left">token</th><th class="c2 l2" align="left">iOS</th><th class="c2 l2" align="left">light</th><th class="c2 l2" align="left">dark</th></tr>'
             + tr + '</table><h2>Contraste (WCAG 2.x)</h2><table style="border-collapse:collapse" cellpadding="7">' + ck + '</table>')
    return board("light", inner, "EmberLens · Cores")

def typography():
    styles = [("Large Title", ".largeTitle", "34 / 41", "Bold", "lt", "Queimadura"),
              ("Title", ".title", "28 / 34", "Bold", "t1", "Inteligência que funciona no dispositivo."),
              ("Title 2", ".title2", "22 / 28", "Bold", "t2", "Imagem selecionada"),
              ("Title 3", ".title3", "20 / 25", "Semibold", "t3", "Não foi possível carregar a imagem"),
              ("Headline", ".headline", "17 / 22", "Semibold", "hl", "Distribuição das classificações"),
              ("Body", ".body", "17 / 22", "Regular", "body", "Explore a classificação visual de imagens de pele."),
              ("Callout", ".callout", "16 / 21", "Regular", "callout", "Pontuação do modelo: 72%"),
              ("Subheadline", ".subheadline", "15 / 20", "Regular", "sub", "A imagem será processada neste dispositivo."),
              ("Footnote", ".footnote", "13 / 18", "Regular", "fn", "Esta classificação é experimental."),
              ("Caption", ".caption", "12 / 16", "Regular", "c1", "Pontuações do modelo para cada categoria."),
              ("Label (caps)", ".caption2.weight(.medium) + tracking", "11 / 13", "Medium · +6%", "c2", "Classificação experimental"),
              ("Valores numéricos", ".monospacedDigit()", "herda o estilo", "—", "t1 num", "84%  0,767  72%  18 ms"),
              ("Informação técnica", ".footnote + .monospacedDigit()", "13 / 18", "Regular", "fn num", "MobileNetV3 Small · Core ML · 18 ms")]
    rows = "".join(f'<tr><td style="width:190px" class="fn"><b>{n}</b><div class="c1 l2">{sw}</div></td><td class="c1 l2 num" style="width:130px">{sz} pt<br>{wt}</td>'
                   f'<td><div class="{cls}">{ex}</div></td></tr>' for n, sw, sz, wt, cls, ex in styles)
    inner = ('<p class="sub l2" style="max-width:900px;margin-top:10px">Fonte do sistema (SF Pro Text / SF Pro Display), sempre por estilos semânticos com Dynamic Type. '
             'Tamanhos de referência no tamanho padrão (Large). Nesta folha, a fonte exibida é Inter/Inter Display, substituta usada apenas na geração das imagens. '
             'A marca usa Inter Display Semibold apenas no logotipo (convertido em curvas).</p>'
             '<table style="border-collapse:collapse;margin-top:24px" cellpadding="12">' + rows + '</table>')
    return board("light", inner, "EmberLens · Tipografia")

if __name__ == "__main__":
    for m in ("light", "dark"):
        shot(components(m), f"{OUT}/components/components-{m}.png", 1180, 1600)
    shot(colors(), f"{OUT}/colors/color-palette.png", 1300, 1340)
    shot(typography(), f"{OUT}/typography/type-scale.png", 1200, 1040)
