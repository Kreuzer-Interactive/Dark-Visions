"""B4 with the original tails and NO name tab. Three name placements:
 T1 header line inside the panel on the speaker's side + thin rule, text below
 T2 inline prefix 'JAMES' in a deep-red ink on the first text line (screenplay style)
 T3 name set into the panel's top border beside the tail (legend style: border gap, text sits on the edge)"""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mock_b4 import *
from mock_b4n import tail

INK_NAME = RED_D if False else 249   # brick red (125,49,42): reads on both cream and pale blue


def speech_t(mode, n, title, who, speaker, npc, body):
    im = base3(n, title); busts(im, npc)
    mine = speaker == 'you'; fill = PALE if mine else PAPER
    hair = PALE_IN if mine else HAIR
    panel(im, fill, hair)
    tail(im, 44 if mine else 276, fill)
    nm = who
    if mode == 1:
        nx = PX0 + 11 if mine else PX1 - 11 - tw(nm)
        txt(im, nx, PY0 + 6, nm, INK_NAME)
        hline(im, nx, nx + tw(nm) - 1, PY0 + 15, hair)
        lines = wrap(body, 272); y0 = PY0 + 20
        for i, l in enumerate(lines): txt(im, PX0 + 11, y0 + i * 9, l, NAVY)
    elif mode == 2:
        ind = tw(nm + '  ')
        words = body.split(' '); lines = []; cur = ''; limit = 272 - ind
        for w_ in words:
            if tw((cur + ' ' + w_).strip()) > limit and cur:
                lines.append(cur); cur = w_; limit = 272
            else: cur = (cur + ' ' + w_).strip()
        lines.append(cur); nl = len(lines)
        y0 = PY0 + (PY1 - PY0 + 1 - (nl * 9 - 2)) // 2
        txt(im, PX0 + 11, y0, nm, INK_NAME)
        for i, l in enumerate(lines):
            txt(im, PX0 + 11 + (ind if i == 0 else 0), y0 + i * 9, l, NAVY)
    else:
        w = tw(nm) + 6
        nx = (PX0 + 66) if mine else (PX1 - 66 - w)
        rect(im, nx - 2, PY0 - 2, nx + w + 1, PY0 + 2, fill)      # gap in the outline, same fill
        txt(im, nx + 2, PY0 - 3, nm, INK_NAME)
        lines = wrap(body, 272); nl = len(lines)
        y0 = PY0 + (PY1 - PY0 + 1 - (nl * 9 - 2)) // 2
        for i, l in enumerate(lines): txt(im, PX0 + 11, y0 + i * 9, l, NAVY)
    more(im, PX1 - 14, PY1 - 8, RED)
    return im


T = 'THE ENTRANCE HALL'
S = Image.new('RGB', (1300, 1500), (30, 30, 34))
from PIL import ImageDraw
d = ImageDraw.Draw(S)
caps = {1: 'T1 name as a header line inside the panel (speaker side) + rule', 2: 'T2 name as an inline prefix on the first line',
        3: 'T3 name set into the top border beside the tail'}
for r, v in enumerate((1, 2, 3)):
    for c, (who, spk, body) in enumerate((('YOU', 'you', YOU_SAYS), ('JAMES', 'npc', JAMES))):
        f = speech_t(v, 2, T, who, spk, 'P11A.BMP', body).resize((640, 480), Image.NEAREST)
        S.paste(f, (10 + c * 650, 10 + r * 500))
    d.text((10, 10 + r * 500 + 482), caps[v], fill=(230, 225, 200))
S.save(OUT / 'direction-b4-tails.png'); print(OUT / 'direction-b4-tails.png')
