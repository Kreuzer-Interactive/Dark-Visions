"""B4 name-placement options (the folder tab on the inner side was judged bad).
 N1: name INSIDE the panel, as a small dark pill at the panel's top-left (same spot every time)
 N2: name tab centred directly UNDER the speaker's face, standing on the panel edge; it replaces the tail
 N3: name tab flush at the panel's OUTER top corner (under the speaker's shoulder), tail kept"""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mock_b4 import *


def tail(im, tipx, fill):
    for k in range(10):
        half = k * 3 // 4 + 1; y = PY0 - 9 + k
        for x in range(tipx - half, tipx + half + 1):
            edge = abs(x - tipx) >= half - 1 or k == 0
            im.putpixel((x, y), col(NAVY if edge else fill))
    hline(im, tipx - 7, tipx + 7, PY0, fill); hline(im, tipx - 7, tipx + 7, PY0 + 1, fill)


def speech_n(mode, n, title, who, speaker, npc, body):
    im = base3(n, title); busts(im, npc)
    mine = speaker == 'you'; fill = PALE if mine else PAPER
    panel(im, fill, PALE_IN if mine else HAIR)
    w = tw(who) + 12
    cx = 44 if mine else 270
    top = 0
    if mode == 1:
        tail(im, cx, fill)
        rect(im, PX0 + 8, PY0 + 5, PX0 + 8 + tw(who) + 7, PY0 + 15, NAVY)
        txt(im, PX0 + 12, PY0 + 7, who, PAPER if not mine else PALE)
        top = 9
    elif mode == 2:
        tab(im, cx - w // 2, cx + w // 2, fill, who)         # the tab is the pointer, no tail
    else:
        tail(im, cx, fill)
        if mine: tab(im, PX0 + 1, PX0 + 1 + w, fill, who)
        else: tab(im, PX1 - 1 - w, PX1 - 1, fill, who)
    lines = wrap(body, 272); nl = len(lines)
    ty = PY0 + 5 + top + (PY1 - PY0 - 8 - top - (nl * 9 - 2)) // 2 if mode == 1 else PY0 + (PY1 - PY0 + 1 - (nl * 9 - 2)) // 2
    for i, l in enumerate(lines): txt(im, PX0 + 11, ty + i * 9, l, NAVY)
    more(im, PX1 - 14, PY1 - 8, RED)
    return im


T = 'THE ENTRANCE HALL'
S = Image.new('RGB', (1300, 1500), (30, 30, 34))
from PIL import ImageDraw
d = ImageDraw.Draw(S)
caps = {1: 'N1 name inside the panel (top-left pill)', 2: 'N2 name tab centred under the speaker, replaces the tail',
        3: 'N3 name tab at the outer corner, under the shoulder'}
for r, mode in enumerate((1, 2, 3)):
    for c, (who, spk, body) in enumerate((('YOU', 'you', YOU_SAYS), ('JAMES', 'npc', JAMES))):
        f = speech_n(mode, 2, T, who, spk, 'P11A.BMP', body).resize((640, 480), Image.NEAREST)
        S.paste(f, (10 + c * 650, 10 + r * 500))
    d.text((10, 10 + r * 500 + 482), caps[mode], fill=(230, 225, 200))
S.save(OUT / 'direction-b4-names.png'); print(OUT / 'direction-b4-names.png')
