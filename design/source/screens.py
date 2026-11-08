"""Gera os mockups do EmberLens (HTML -> PNG via Chrome headless).

Fonte: Inter / Inter Display como substitutas do SF Pro Text / SF Pro Display
(o SF Pro não pode ser redistribuído; no app, usar a fonte do sistema).
Ícones de interface: desenhos simplificados que REPRESENTAM SF Symbols; no app,
usar os SF Symbols nomeados na documentação.
"""
import base64, json, os, subprocess, sys
from symbol import geom

OUT = sys.argv[1] if len(sys.argv) > 1 else "out/screens"
W, H = 393, 852
PHOTO = base64.b64encode(open("photo-portrait.jpg", "rb").read()).decode()  # 3:4 retrato, ilustrativa

TOKENS = {
    "light": {
        "bg": "#FFFFFF", "surface": "#F2F2F7", "elevated": "#FFFFFF",
        "label": "#000000", "label2": "rgba(60,60,67,.60)", "label3": "rgba(60,60,67,.30)",
        "separator": "rgba(60,60,67,.29)", "fill": "rgba(120,120,128,.20)", "fill4": "rgba(116,116,128,.08)",
        "accent": "#C4532C", "accentText": "#C4532C", "onAccent": "#FFFFFF", "accentSoft": "rgba(196,83,44,.10)",
        "barNeutral": "#C7C7CC", "error": "#FF3B30", "success": "#34C759",
        "disabledBg": "rgba(120,120,128,.12)", "disabledText": "rgba(60,60,67,.30)",
        "lensFill": "#F1ECE6", "ray": "rgba(60,60,67,.22)", "ink": "#151312", "scrim": "rgba(0,0,0,.20)",
        "sheet": "#F2F2F7", "group": "#FFFFFF", "alert": "rgba(242,242,242,.97)",
    },
    "dark": {
        "bg": "#000000", "surface": "#1C1C1E", "elevated": "#1C1C1E",
        "label": "#FFFFFF", "label2": "rgba(235,235,245,.60)", "label3": "rgba(235,235,245,.30)",
        "separator": "rgba(84,84,88,.65)", "fill": "rgba(120,120,128,.36)", "fill4": "rgba(118,118,128,.18)",
        "accent": "#C4532C", "accentText": "#EC8157", "onAccent": "#FFFFFF", "accentSoft": "rgba(236,129,87,.14)",
        "barNeutral": "#48484A", "error": "#FF453A", "success": "#30D158",
        "disabledBg": "rgba(120,120,128,.24)", "disabledText": "rgba(235,235,245,.30)",
        "lensFill": "#1E1B19", "ray": "rgba(235,235,245,.20)", "ink": "#F5F2EE", "scrim": "rgba(0,0,0,.48)",
        "sheet": "#1C1C1E", "group": "#2C2C2E", "alert": "rgba(44,44,46,.97)",
    },
}

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:393px;background:var(--bg)}
body{font-family:'Inter',sans-serif;color:var(--label);-webkit-font-smoothing:antialiased;font-feature-settings:'cv05','ss03'}
.screen{position:relative;width:393px;min-height:852px;background:var(--bg);overflow:hidden;display:flex;flex-direction:column}
.disp{font-family:'Inter Display','Inter',sans-serif}
.lt{font:700 34px/41px 'Inter Display';letter-spacing:-.02em}
.t1{font:700 28px/34px 'Inter Display';letter-spacing:-.018em}
.t2{font:700 22px/28px 'Inter Display';letter-spacing:-.012em}
.t3{font:600 20px/25px 'Inter Display';letter-spacing:-.01em}
.hl{font:600 17px/22px 'Inter';letter-spacing:-.022em}
.body{font:400 17px/22px 'Inter';letter-spacing:-.022em}
.callout{font:400 16px/21px 'Inter';letter-spacing:-.02em}
.sub{font:400 15px/20px 'Inter';letter-spacing:-.015em}
.fn{font:400 13px/18px 'Inter';letter-spacing:-.005em}
.c1{font:400 12px/16px 'Inter'}
.c2{font:500 11px/13px 'Inter';letter-spacing:.06em;text-transform:uppercase}
.num{font-feature-settings:'tnum','cv05';}
.l2{color:var(--label2)}.l3{color:var(--label3)}.acc{color:var(--accentText)}
.status{height:59px;display:flex;align-items:center;justify-content:space-between;padding:0 30px 0 50px;position:relative;flex:none}
.status .time{font:600 17px/22px 'Inter';letter-spacing:-.02em}
.island{position:absolute;left:50%;top:11px;width:126px;height:37px;margin-left:-63px;background:#000;border-radius:20px}
.home-ind{position:absolute;bottom:8px;left:50%;width:139px;height:5px;margin-left:-69.5px;border-radius:3px;background:var(--label)}
.nav{height:44px;display:flex;align-items:center;justify-content:space-between;padding:0 8px 0 8px;position:relative;flex:none}
.nav .title{position:absolute;left:0;right:0;text-align:center;pointer-events:none}
.navbtn{height:44px;min-width:44px;display:flex;align-items:center;justify-content:center;color:var(--accentText);gap:4px}
.back{padding-left:6px;justify-content:flex-start}
.btn{height:52px;border-radius:14px;display:flex;align-items:center;justify-content:center;gap:8px;font:600 17px/22px 'Inter';letter-spacing:-.022em;width:100%}
.btn.primary{background:var(--accent);color:var(--onAccent)}
.btn.secondary{background:var(--fill4);color:var(--accentText);background:var(--accentSoft)}
.btn.plain{color:var(--accentText)}
.btn.disabled{background:var(--disabledBg);color:var(--disabledText)}
.pad{padding:0 20px}
.hair{height:.5px;background:var(--separator)}
.bar{height:6px;border-radius:3px;background:var(--fill4);overflow:hidden}
.bar>i{display:block;height:100%;border-radius:3px;background:var(--barNeutral)}
.bar.top>i{background:var(--accentText)}
.notice{display:flex;gap:10px;padding:12px 14px;border-radius:12px;background:var(--fill4);align-items:flex-start}
.photo{border-radius:16px;overflow:hidden;background:var(--surface)}
.photo{display:flex;align-items:center;justify-content:center;background:var(--fill4)}
.photo img{display:block;max-width:100%;max-height:100%;width:auto;height:100%;object-fit:contain;border-radius:inherit}
.scrim{position:absolute;inset:0;background:var(--scrim)}
.sheet{position:absolute;left:0;right:0;bottom:0;background:var(--sheet);border-radius:28px 28px 0 0;padding:8px 16px 42px}
.grab{width:36px;height:5px;border-radius:3px;background:var(--label3);margin:0 auto 14px}
.group{background:var(--group);border-radius:12px;overflow:hidden}
.row{display:flex;align-items:center;gap:14px;padding:0 16px;min-height:60px}
.rowsep{height:.5px;background:var(--separator);margin-left:58px}
.alert{position:absolute;left:50%;top:50%;width:270px;transform:translate(-50%,-50%);border-radius:14px;background:var(--alert);overflow:hidden;text-align:center;backdrop-filter:blur(20px)}
.alert .hd{padding:19px 16px 15px}
.alert .ab{height:44px;display:flex;align-items:center;justify-content:center;border-top:.5px solid var(--separator);font:400 17px/22px 'Inter';color:var(--accentText);letter-spacing:-.022em}
.alert .ab.b{font-weight:600}
.kv{display:flex;justify-content:space-between;align-items:baseline;padding:11px 0;gap:16px}
.spin{width:20px;height:20px}
"""

def tokens_css(mode):
    return ":root{" + ";".join(f"--{k}:{v}" for k, v in TOKENS[mode].items()) + "}"

# ---------------- ícones (representações simplificadas de SF Symbols) ----------------
def ico(name, size=22, color="currentColor", w=1.7):
    s = f'width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"'
    P = {
        "info.circle": '<circle cx="12" cy="12" r="9.5"/><path d="M12 11v5.5"/><circle cx="12" cy="7.6" r=".6" fill="{c}" stroke="none"/>',
        "chevron.left": '<path d="M15 4.5 7.5 12 15 19.5" stroke-width="2.4"/>',
        "chevron.right": '<path d="M9.5 6 15.5 12 9.5 18" stroke-width="2"/>',
        "camera": '<path d="M3 8.5a2 2 0 0 1 2-2h2.2l1.5-2h6.6l1.5 2H19a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><circle cx="12" cy="12.6" r="3.6"/>',
        "photo.on.rectangle": '<rect x="6.5" y="3.5" width="14" height="11" rx="2"/><path d="M3.5 7.5v9a3 3 0 0 0 3 3h10"/><path d="m8.5 13 3-3 2.5 2.5 1.5-1.5 3.5 3.5"/><circle cx="16.2" cy="7.2" r="1" fill="{c}" stroke="none"/>',
        "iphone": '<rect x="6.5" y="2" width="11" height="20" rx="3"/><rect x="10" y="4.3" width="4" height="1.4" rx=".7" fill="{c}" stroke="none"/>',
        "lock": '<rect x="5.5" y="10.5" width="13" height="10" rx="2.2"/><path d="M8.5 10.5V7.8a3.5 3.5 0 0 1 7 0v2.7"/>',
        "exclamationmark.triangle": '<path d="M12 3.8 2.8 19.5h18.4z"/><path d="M12 9.8v4.6"/><circle cx="12" cy="17" r=".5" fill="{c}" stroke="none"/>',
        "photo.badge.exclamationmark": '<rect x="3" y="5" width="15" height="13" rx="2"/><path d="m3.5 15 4-4 3 3 2-2 3 3"/><circle cx="18.5" cy="6.5" r="4.2" fill="{c}" stroke="none"/><path d="M18.5 4.5v2.4" stroke="var(--bg)"/><circle cx="18.5" cy="8.6" r=".45" fill="var(--bg)" stroke="none"/>',
        "arrow.up.right": '<path d="M7 17 17 7M8.5 7H17v8.5"/>',
        "arrow.clockwise": '<path d="M19 12a7 7 0 1 1-2.1-5"/><path d="M19 4.5V8h-3.5"/>',
        "cpu": '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9.5 3v3M14.5 3v3M9.5 18v3M14.5 18v3M3 9.5h3M3 14.5h3M18 9.5h3M18 14.5h3"/>',
        "camera.slash": '<path d="M3 8.5a2 2 0 0 1 2-2h2.2l1.5-2h6.6l1.5 2H19a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M3.5 3.5l17 17"/>',
    }[name].replace("{c}", color if color != "currentColor" else "currentColor")
    return f'<svg {s}>{P}</svg>'

def spinner(color):
    bars = "".join(
        f'<rect x="11" y="2" width="2" height="5.5" rx="1" fill="{color}" opacity="{0.25 + 0.75 * i / 7:.2f}" transform="rotate({i * 45} 12 12)"/>'
        for i in range(8))
    return f'<svg class="spin" viewBox="0 0 24 24">{bars}</svg>'

def status(mode):
    c = "#000" if mode == "light" else "#fff"
    sig = "".join(f'<rect x="{i*4.6}" y="{8-i*2.3}" width="3.2" height="{3.4+i*2.3}" rx=".8" fill="{c}"/>' for i in range(4))
    wifi = f'<path d="M1 4.2a10 10 0 0 1 14 0M3.6 6.9a6.2 6.2 0 0 1 8.8 0M6.2 9.6a2.4 2.4 0 0 1 3.6 0" stroke="{c}" stroke-width="1.7" fill="none" stroke-linecap="round"/>'
    bat = f'<rect x=".5" y=".5" width="24" height="12" rx="3.6" fill="none" stroke="{c}" stroke-opacity=".4"/><rect x="2.5" y="2.5" width="20" height="8" rx="2" fill="{c}"/><rect x="25.6" y="4.3" width="1.6" height="4.4" rx=".8" fill="{c}" fill-opacity=".4"/>'
    return (f'<div class="status"><span class="time num">9:41</span><div class="island"></div>'
            f'<span style="display:flex;gap:6px;align-items:center"><svg width="17" height="12" viewBox="0 0 17 12">{sig}</svg>'
            f'<svg width="16" height="12" viewBox="0 0 16 12">{wifi}</svg><svg width="28" height="13" viewBox="0 0 28 13">{bat}</svg></span></div>')

def symbol_svg(height, lens, dot, extra=""):
    g = geom(d=60, r=16, gap=13)
    x0 = g['lx'] - g['w'] / 2; y0 = g['cy'] - g['h'] / 2
    bw = g['dx'] + g['r'] - x0; sc = height / g['h']
    return (f'<svg width="{bw*sc:.1f}" height="{height}" viewBox="{x0:.2f} {y0:.2f} {bw:.2f} {g["h"]:.2f}" {extra}>'
            f'<path d="M{g["lx"]:.2f} {y0:.2f}A60 60 0 0 1 {g["lx"]:.2f} {y0+g["h"]:.2f}A60 60 0 0 1 {g["lx"]:.2f} {y0:.2f}Z" fill="{lens}"/>'
            f'<circle cx="{g["dx"]:.2f}" cy="{g["cy"]:.2f}" r="{g["r"]}" fill="{dot}"/></svg>')

def wordmark(mode, size=17):
    return (f'<span style="display:flex;align-items:center;gap:8px">{symbol_svg(size*1.25, "var(--ink)", "var(--accent)")}'
            f'<span class="disp" style="font-weight:600;font-size:{size+1}px;letter-spacing:-.015em">EmberLens</span></span>')

def nav(title=None, back=True, right=None, left=None):
    l = left or (f'<div class="navbtn back">{ico("chevron.left", 24)}<span class="body">Voltar</span></div>' if back else '<div></div>')
    t = f'<div class="title hl">{title}</div>' if title else ""
    return f'<div class="nav">{t}{l}{right or "<div></div>"}</div>'

def photo(h, radius=16):
    # preserva a proporção original: a imagem é encaixada (aspect fit) no quadro, sem corte
    return f'<div class="photo" style="height:{h}px;border-radius:{radius}px"><img src="data:image/jpeg;base64,{PHOTO}" style="border-radius:{radius}px"></div>'

# ---------------- gráfico proprietário da Home ----------------
def hero(mode, w=393, h=300):
    t = TOKENS[mode]
    g = geom(d=60, r=16, gap=13)
    lens_h = 190; sc = lens_h / g['h']
    cx = 150; cy = h / 2 + 4
    lx = cx; top = cy - lens_h / 2; bot = cy + lens_h / 2; R = 60 * sc
    half_w = g['w'] / 2 * sc
    fx = lx + (g['dx'] - g['lx']) * sc + 6; fr = g['r'] * sc * 0.62
    rays = ""
    for k, yy in enumerate((-0.36, -0.18, 0.0, 0.18, 0.36)):
        y = cy + yy * lens_h
        # entrada paralela até a borda esquerda da lente
        import math
        dyy = y - cy; xl = lx - (math.sqrt(max(R * R - dyy * dyy, 0)) - (R - half_w))
        xr = lx + (math.sqrt(max(R * R - dyy * dyy, 0)) - (R - half_w))
        rays += f'<line x1="0" y1="{y:.1f}" x2="{xl:.1f}" y2="{y:.1f}" stroke="{t["ray"]}" stroke-width="1"/>'
        rays += f'<line x1="{xr:.1f}" y1="{y:.1f}" x2="{fx:.1f}" y2="{cy:.1f}" stroke="{t["ray"]}" stroke-width="1"/>'
    axis = f'<line x1="{fx+fr+10:.1f}" y1="{cy:.1f}" x2="{w}" y2="{cy:.1f}" stroke="{t["ray"]}" stroke-width="1" stroke-dasharray="2 4"/>'
    lens = f'<path d="M{lx:.1f} {top:.1f}A{R:.1f} {R:.1f} 0 0 1 {lx:.1f} {bot:.1f}A{R:.1f} {R:.1f} 0 0 1 {lx:.1f} {top:.1f}Z" fill="{t["lensFill"]}"/>'
    dot = f'<circle cx="{fx:.1f}" cy="{cy:.1f}" r="{fr:.1f}" fill="{t["accent"]}"/>'
    tick = f'<text x="{fx:.1f}" y="{cy+fr+22:.1f}" text-anchor="middle" font-family="Inter" font-size="11" font-style="italic" fill="{t["label3"]}">f</text>'
    return f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" style="display:block">{rays}{lens}{axis}{dot}{tick}</svg>'

# ---------------- telas ----------------
def page(mode, inner, overlay="", min_h=H, home=True):
    return (f'<!DOCTYPE html><html><head><meta charset="utf-8"><style>{tokens_css(mode)}{CSS}</style></head>'
            f'<body><div class="screen" style="min-height:{min_h}px">{status(mode)}{inner}{overlay}'
            f'{"<div class=home-ind></div>" if home else ""}</div></body></html>')

def home_inner(mode):
    info = f'<div class="navbtn" style="color:var(--label2)">{ico("info.circle", 23)}</div>'
    return (nav(left=f'<div style="padding-left:12px">{wordmark(mode)}</div>', right=info)
            + f'<div style="flex:none">{hero(mode)}</div>'
            + '<div class="pad" style="flex:1;display:flex;flex-direction:column">'
              '<h1 class="lt" style="margin-top:8px">Observe além<br>da imagem.</h1>'
              '<p class="body l2" style="margin-top:12px">Explore a classificação visual de imagens de pele com inteligência artificial executada diretamente no seu iPhone.</p>'
              '<div style="flex:1"></div>'
              '<div class="btn primary">Analisar imagem</div>'
              f'<div style="display:flex;gap:10px;justify-content:center;align-items:flex-start;margin:20px 0 46px">'
              f'<span class="l2" style="margin-top:1px">{ico("iphone", 17)}</span>'
              '<div class="fn"><div style="font-weight:600">Processamento local</div><div class="l2">Suas imagens não são enviadas para servidores.</div></div></div>'
              '</div>')

def source_sheet(mode, title="Analisar imagem"):
    row = lambda icon, t, s: (f'<div class="row"><span class="acc" style="width:28px;display:flex;justify-content:center">{ico(icon, 26)}</span>'
                              f'<div style="flex:1"><div class="body">{t}</div><div class="fn l2">{s}</div></div>'
                              f'<span class="l3">{ico("chevron.right", 16)}</span></div>')
    return ('<div class="scrim"></div><div class="sheet"><div class="grab"></div>'
            f'<div style="text-align:center;margin-bottom:18px"><div class="hl">{title}</div><div class="fn l2" style="margin-top:2px">Escolha a origem da imagem</div></div>'
            '<div class="group">' + row("camera", "Tirar foto", "Use a câmera do iPhone") + '<div class="rowsep"></div>'
            + row("photo.on.rectangle", "Escolher da Fototeca", "Selecione uma foto existente") + '</div>'
            '<div class="group" style="margin-top:12px"><div class="row" style="justify-content:center;min-height:54px"><span class="body acc" style="font-weight:600">Cancelar</span></div></div>'
            '</div>')

def preview_inner(mode, state="ready"):
    if state == "error":
        img = (f'<div style="height:440px;border-radius:16px;background:var(--fill4);display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 36px">'
               f'<span class="l2">{ico("photo.badge.exclamationmark", 44, w=1.5)}</span>'
               '<div class="t3" style="margin-top:16px">Não foi possível carregar a imagem</div>'
               '<div class="sub l2" style="margin-top:6px">O arquivo pode estar corrompido ou em um formato incompatível.</div></div>')
        status_txt = ""
        actions = '<div class="btn primary">Escolher outra imagem</div>'
    else:
        img = photo(440)
        if state == "processing":
            status_txt = (f'<div style="display:flex;align-items:center;gap:8px;margin-top:20px">{spinner(TOKENS[mode]["label2"])}'
                          '<span class="hl">Analisando no dispositivo…</span></div>'
                          '<p class="sub l2" style="margin-top:4px">Isso costuma levar menos de um segundo.</p>')
            actions = (f'<div class="btn disabled">Analisar imagem</div>'
                       '<div class="btn plain" style="margin-top:6px;opacity:.35">Escolher outra imagem</div>')
        else:
            status_txt = ('<div class="hl" style="margin-top:20px">Pronto para analisar</div>'
                          '<p class="sub l2" style="margin-top:4px">A imagem será processada diretamente neste dispositivo.</p>')
            actions = ('<div class="btn primary">Analisar imagem</div>'
                       '<div class="btn plain" style="margin-top:6px">Escolher outra imagem</div>')
    return (nav("Nova análise")
            + '<div class="pad" style="flex:1;display:flex;flex-direction:column">'
              '<h2 class="t2" style="margin:8px 0 14px">Imagem selecionada</h2>'
            + img + status_txt + '<div style="flex:1"></div>' + f'<div style="margin-bottom:42px">{actions}</div></div>')

CLASSES = [("Queimadura", 72), ("Abrasão", 14), ("Hematoma", 3), ("Laceração", 9), ("Pele normal", 2)]

def result_inner(mode, scroll_full=True):
    top = max(CLASSES, key=lambda c: c[1])
    bars = ""
    for name, v in CLASSES:
        is_top = (name, v) == top
        bars += (f'<div style="margin-top:14px"><div style="display:flex;justify-content:space-between;align-items:baseline">'
                 f'<span class="sub" style="{"font-weight:600" if is_top else ""}">{name}</span>'
                 f'<span class="sub num {"acc" if is_top else "l2"}" style="{"font-weight:600" if is_top else ""}">{v}%</span></div>'
                 f'<div class="bar {"top" if is_top else ""}" style="margin-top:6px"><i style="width:{max(v,1)}%"></i></div></div>')
    kv = lambda k, v: f'<div class="kv fn"><span class="l2">{k}</span><span class="num" style="text-align:right">{v}</span></div><div class="hair"></div>'
    return (nav("Resultado")
            + '<div class="pad" style="flex:1;display:flex;flex-direction:column;padding-bottom:42px">'
            + f'<div style="margin-top:8px">{photo(300)}</div>'
              '<div style="margin-top:22px;display:flex;align-items:center;gap:7px">'
              '<span style="width:7px;height:7px;border-radius:50%;background:var(--accent)"></span>'
              '<span class="c2 l2">Classificação experimental</span></div>'
              f'<h1 class="lt" style="margin-top:6px">{top[0]}</h1>'
              f'<p class="callout l2" style="margin-top:4px">Pontuação do modelo: <span class="num" style="color:var(--label);font-weight:600">{top[1]}%</span></p>'
              '<div class="hair" style="margin:22px 0 4px"></div>'
              '<h3 class="hl" style="margin-top:14px">Distribuição das classificações</h3>'
            + bars +
              '<p class="fn l3" style="margin-top:12px">Pontuações do modelo para cada categoria (softmax). Somam 100%.</p>'
              '<h3 class="c2 l2" style="margin-top:28px;margin-bottom:2px">Informações técnicas</h3><div class="hair"></div>'
            + kv("Modelo", "MobileNetV3 Small") + kv("Framework", "Core ML") + kv("Execução", "Processamento local") + kv("Tempo de inferência", "18 ms") +
              f'<div class="notice" style="margin-top:22px"><span class="l2" style="margin-top:1px">{ico("info.circle", 18)}</span>'
              '<span class="fn l2">Esta classificação é experimental e não constitui um diagnóstico médico.</span></div>'
              '<div class="btn primary" style="margin-top:26px">Analisar outra imagem</div>'
              '</div>')

def result_error_inner(mode):
    return (nav("Resultado")
            + '<div class="pad" style="flex:1;display:flex;flex-direction:column;padding-bottom:42px">'
            + f'<div style="margin-top:8px;opacity:.55">{photo(250)}</div>'
              f'<div style="margin-top:28px;color:var(--error)">{ico("exclamationmark.triangle", 30, w=1.8)}</div>'
              '<h1 class="t1" style="margin-top:10px">Não foi possível analisar a imagem</h1>'
              '<p class="body l2" style="margin-top:8px">Ocorreu um erro durante o processamento no dispositivo. Nenhuma classificação foi gerada.</p>'
              '<p class="fn l3" style="margin-top:10px">Código: inferenceFailed</p>'
              '<div style="flex:1"></div>'
              f'<div class="btn primary">{ico("arrow.clockwise", 19, w=2.2)}Tentar novamente</div>'
              '<div class="btn plain" style="margin-top:6px">Escolher outra imagem</div></div>')

def about_inner(mode):
    sec = lambda t: f'<h3 class="c2 l2" style="margin-top:36px;margin-bottom:2px">{t}</h3><div class="hair"></div>'
    kv = lambda k, v: f'<div class="kv sub"><span class="l2">{k}</span><span class="num">{v}</span></div><div class="hair"></div>'
    stat = lambda v, l: f'<div style="flex:1"><div class="t1 num">{v}</div><div class="fn l2" style="margin-top:2px">{l}</div></div>'
    lim = lambda t: f'<div style="display:flex;gap:12px;padding:10px 0"><span class="l3 sub">—</span><span class="sub">{t}</span></div>'
    return (nav("Sobre o EmberLens")
            + '<div class="pad" style="padding-bottom:46px">'
            + f'<div style="display:flex;align-items:center;gap:14px;margin-top:18px">{symbol_svg(46, "var(--ink)", "var(--accent)")}'
              '<div><div class="t3">EmberLens</div><div class="fn l2">Classificação experimental de imagens de pele</div></div></div>'
              '<h1 class="t1" style="margin-top:30px">Inteligência que funciona no dispositivo.</h1>'
              '<p class="body l2" style="margin-top:12px">O EmberLens explora o uso de redes neurais compactas para classificação visual de imagens, executando o processamento diretamente no iPhone.</p>'
            + sec("Modelo de inteligência artificial")
            + kv("Arquitetura", "MobileNetV3 Small") + kv("Treinamento", "PyTorch") + kv("Inferência", "Core ML")
            + kv("Entrada", "224 × 224 pixels") + kv("Categorias", "5") + kv("Execução", "No dispositivo")
            + sec("Resultados experimentais")
            + '<div style="display:flex;gap:12px;margin-top:16px">' + stat("84%", "Accuracy") + stat("0,767", "Macro F1") + stat("68%", "Recall de<br>queimaduras") + '</div>'
              '<p class="fn l2" style="margin-top:14px">Obtidos em um conjunto de teste limitado (187 imagens). Não representam desempenho clínico validado.</p>'
            + sec("Limitações")
            + lim("O modelo foi treinado com um dataset público de imagens coletadas da web.")
            + lim("As imagens não possuem validação clínica suficiente.")
            + lim("O desempenho em fotos reais de iPhone não foi medido; há limitações de generalização.")
            + lim("As classificações não são diagnósticos e não substituem uma avaliação profissional.")
            + sec("Inspiração")
            + '<p class="sub" style="margin-top:12px">Pelis, pesquisa desenvolvida na Universidade de Fortaleza (Unifor), investigou o uso de inteligência artificial para classificação e auxílio na terapia tópica de queimaduras.</p>'
              '<p class="fn l2" style="margin-top:10px">AGUIAR, G. A. F. et al. Inteligência artificial para classificação e auxílio na terapia tópica de queimaduras em tempo real. <i>Enfermagem em Foco</i>, v. 10, n. 5, 2019.</p>'
            + '<div class="hair" style="margin-top:36px"></div>'
            + f'<div class="kv sub"><span>Código-fonte no GitHub</span><span class="acc" style="display:flex;align-items:center;gap:4px">emberlens {ico("arrow.up.right", 15, w=2)}</span></div><div class="hair"></div>'
            + kv("Versão", "1.0 (1)")
            + '<p class="fn l2" style="margin-top:16px">Dataset: Basic Wound Classify (Roboflow Universe, CC BY 4.0). Pesos iniciais: MobileNetV3 Small ImageNet (torchvision).</p>'
              '<p class="fn l3" style="margin-top:10px">EmberLens é um projeto experimental de portfólio. Não é um dispositivo médico.</p>'
              '</div>')

def alert(title, msg, buttons):
    b = "".join(f'<div class="ab {"b" if bold else ""}">{t}</div>' for t, bold in buttons)
    return (f'<div class="scrim" style="background:rgba(0,0,0,.25)"></div><div class="alert"><div class="hd">'
            f'<div class="hl">{title}</div><div class="fn" style="margin-top:4px">{msg}</div></div>{b}</div>')

ALERTS = {
    "camera-permission-denied": ("Acesso à câmera desativado",
        "Para tirar fotos, permita o acesso à câmera nos Ajustes. Você também pode escolher uma imagem da Fototeca.",
        [("Abrir Ajustes", True), ("Escolher da Fototeca", False), ("Cancelar", False)]),
    "camera-unavailable": ("Câmera indisponível",
        "Não há uma câmera disponível neste dispositivo no momento. Escolha uma imagem da Fototeca.",
        [("Escolher da Fototeca", True), ("OK", False)]),
    "camera-capture-error": ("Não foi possível capturar a foto",
        "Ocorreu um erro ao salvar a captura. Tente novamente.",
        [("Tentar novamente", True), ("Cancelar", False)]),
    "library-load-failed": ("Não foi possível carregar a imagem",
        "A foto selecionada não pôde ser lida. Ela pode estar no iCloud sem conexão ou em um formato incompatível.",
        [("Escolher outra imagem", True), ("OK", False)]),
}

def render(html, path, height=H):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path.replace(".png", ".html")
    open(tmp, "w").write(html)
    subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=3",
                    f"--window-size={W},{height}", f"--screenshot={path}", f"file://{os.path.abspath(tmp)}"],
                   stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, check=True)
    os.remove(tmp)

def build():
    for m in ("light", "dark"):
        render(page(m, home_inner(m)), f"{OUT}/home/home-{m}.png")
        render(page(m, home_inner(m), overlay=source_sheet(m)), f"{OUT}/image-selection/source-sheet-{m}.png")
        render(page(m, preview_inner(m, "ready")), f"{OUT}/preview/preview-ready-{m}.png")
        render(page(m, preview_inner(m, "processing")), f"{OUT}/preview/preview-processing-{m}.png")
        render(page(m, preview_inner(m, "error")), f"{OUT}/preview/preview-load-error-{m}.png")
        render(page(m, result_inner(m), min_h=1300), f"{OUT}/result/result-full-{m}.png", height=1300)
        render(page(m, result_inner(m)), f"{OUT}/result/result-viewport-{m}.png")
        render(page(m, result_error_inner(m)), f"{OUT}/result/result-inference-error-{m}.png")
        render(page(m, about_inner(m), min_h=1620), f"{OUT}/about/about-full-{m}.png", height=1620)
        render(page(m, about_inner(m)), f"{OUT}/about/about-viewport-{m}.png")
        render(page(m, preview_inner(m, "ready"), overlay=source_sheet(m, "Escolher outra imagem")), f"{OUT}/image-selection/source-sheet-from-preview-{m}.png")
        for k, (t, msg, b) in ALERTS.items():
            base = home_inner(m) if k.startswith("camera") else preview_inner(m, "ready") if k == "x" else home_inner(m)
            render(page(m, base, overlay=alert(t, msg, b)), f"{OUT}/image-selection/{k}-{m}.png")

if __name__ == "__main__":
    build()
