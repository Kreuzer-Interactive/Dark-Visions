"""N3 refinements: calmer tab (no drop shadow, chamfered folder-tab shape that continues the panel
outline), optional tail, optional inner hairline."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mock_b4 import *
from mock_b4n import tail


def folder_tab(im, side, w, fill, label, chamfer=True):
    """tab standing on the panel's top edge at the outer corner; the inner end slants down 3px"""
    h = 9
    if side == 'L': x0, x1 = PX0, PX0 + w
    else: x0, x1 = PX1 - w, PX1
    y0 = PY0 - h
    for y in range(y0, PY0 + 2):
        for x in range(x0, x1 + 1):
            cut = 0
            if y - y0 < 3:   # outer top corner rounded 1-2px, inner end chamfered
                cut = 3 - (y - y0)
            inner = (x1 - x) if side == 'L' else (x - x0)
            outer = (x - x0) if side == 'L' else (x1 - x)
            if chamfer and inner < cut: continue
            if outer < (2 - (y - y0)) and y - y0 < 2: continue
            im.putpixel((x, y), col(fill))
    # outline: top, outer side, slanted inner side
    for x in range(x0 + 2, x1 - 2): im.putpixel((x, y0), col(NAVY))
    for y in range(y0 + 2, PY0 + 1): im.putpixel((x0 if side == 'L' else x1, y), col(NAVY))
    for k in range(3):
        xx = (x1 - 2 + k) if side == 'L' else (x0 + 2 - k)
        im.putpixel((xx, y0 + k), col(NAVY)) if chamfer else None
    inner_x = x1 if side == 'L' else x0
    for y in range(y0 + 3, PY0): im.putpixel((inner_x, y), col(NAVY))
    for dx in (0, 1): im.putpixel(((x0 + dx) if side == 'L' else (x1 - dx), y0 + 1 - dx), col(NAVY))
    txt(im, x0 + 5, y0 + 2, label, NAVY)


def speech_r(variant, n, title, who, speaker, npc, body):
    im = base3(n, title); busts(im, npc)
    mine = speaker == 'you'; fill = PALE if mine else PAPER
    hair = None if variant == 2 else (PALE_IN if mine else HAIR)
    panel(im, fill, hair)
    w = tw(who) + 11
    if variant in (1,):                       # no tail: the tab under the shoulder + colour says who
        folder_tab(im, 'L' if mine else 'R', w, fill, who)
    elif variant == 2:
        folder_tab(im, 'L' if mine else 'R', w, fill, who)
    else:                                     # tab + a smaller tail at the face
        folder_tab(im, 'L' if mine else 'R', w, fill, who)
        tail(im, 66 if mine else 250, fill)
    lines = wrap(body, 272); nl = len(lines)
    ty = PY0 + (PY1 - PY0 + 1 - (nl * 9 - 2)) // 2
    for i, l in enumerate(lines): txt(im, PX0 + 11, ty + i * 9, l, NAVY)
    more(im, PX1 - 14, PY1 - 8, RED)
    return im


T = 'THE ENTRANCE HALL'
S = Image.new('RGB', (1300, 1500), (30, 30, 34))
from PIL import ImageDraw
d = ImageDraw.Draw(S)
caps = {1: 'R1 slim chamfered tab, no tail, hairline kept', 2: 'R2 same, hairline removed (cleaner panel)',
        3: 'R3 tab + small tail, hairline kept'}
for r, v in enumerate((1, 2, 3)):
    for c, (who, spk, body) in enumerate((('YOU', 'you', YOU_SAYS), ('JAMES', 'npc', JAMES))):
        f = speech_r(v, 2, T, who, spk, 'P11A.BMP', body).resize((640, 480), Image.NEAREST)
        S.paste(f, (10 + c * 650, 10 + r * 500))
    d.text((10, 10 + r * 500 + 482), caps[v], fill=(230, 225, 200))
S.save(OUT / 'direction-b4-refined.png'); print(OUT / 'direction-b4-refined.png')
