"""Black speech bubble with a white outline (B4 layout, T1 names). Palette entries only.
Variant 1: white outline for both speakers.  Variant 2: your bubble is outlined pale blue, theirs white."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mock_b4 import *

BLACK = 240          # (8,10,17) near-black navy
WHITE = 254          # (243,238,205) paper white
PALEB = 253          # (173,192,204)
NAME = 246           # gold
INK = 254


def panel_black(im, line):
    rr(im, PX0 + 1, PY0 + 2, PX1 + 1, PY1 + 2, BROWN_D)
    rr(im, PX0, PY0, PX1, PY1, line)
    rr(im, PX0 + 2, PY0 + 2, PX1 - 2, PY1 - 2, BLACK)     # 2px outline
    rr(im, PX0 + 1, PY0 + 1, PX1 - 1, PY1 - 1, line)
    rr(im, PX0 + 2, PY0 + 2, PX1 - 2, PY1 - 2, BLACK)


def tail_black(im, tipx, line):
    for k in range(10):
        half = k * 3 // 4 + 1
        y = PY0 - 9 + k
        for x in range(tipx - half, tipx + half + 1):
            edge = abs(x - tipx) >= half - 1 or k == 0
            im.putpixel((x, y), col(line if edge else BLACK))
    hline(im, tipx - 6, tipx + 6, PY0, BLACK); hline(im, tipx - 6, tipx + 6, PY0 + 1, BLACK)
    hline(im, tipx - 6, tipx + 6, PY0 + 2, BLACK)


def speech_b(variant, n, title, who, speaker, npc, body):
    im = base3(n, title); busts(im, npc)
    mine = speaker == 'you'
    line = PALEB if (variant == 2 and mine) else WHITE
    panel_black(im, line)
    tail_black(im, 44 if mine else 276, line)
    nx = PX0 + 11 if mine else PX1 - 11 - tw(who)
    txt(im, nx, PY0 + 6, who, NAME)
    hline(im, nx, nx + tw(who) - 1, PY0 + 15, G3)
    lines = wrap(body, 272); y0 = PY0 + 20
    for i, l in enumerate(lines): txt(im, PX0 + 11, y0 + i * 10, l, INK)
    more(im, PX1 - 14, PY1 - 8, GOLD)
    return im


def menu_b(variant, n, title, rows, npc, hover=1):
    im = base3(n, title); busts(im, npc)
    line = PALEB if variant == 2 else WHITE
    panel_black(im, line)
    tail_black(im, 44, line)
    txt(im, PX0 + 11, PY0 + 6, 'YOU', NAME)
    hline(im, PX0 + 11, PX0 + 10 + tw('YOU'), PY0 + 15, G3)
    lv = 'Leave [Esc]'
    txt(im, PX1 - 11 - tw(lv), PY0 + 6, lv, G3)
    for i, r in enumerate(rows):
        y = PY0 + 17 + i * 11; x0, x1 = 10, 309
        if i == hover:
            rect(im, x0, y, x1, y + 9, WHITE, line)
            rect(im, x0 + 1, y + 1, x0 + 15, y + 8, RED); nc = WHITE
            glyph(im, x1 - 8, y + 2, ['3..', '33.', '333', '33.', '3..'], {'3': RED})
            tc = BLACK
        else:
            rect(im, x0, y, x1, y + 9, G2, G3)
            rect(im, x0 + 1, y + 1, x0 + 15, y + 8, G1); nc = NAME
            tc = INK
        for yy in range(y + 1, y + 9, 2): dot(im, x0 + 16, yy, BLACK)
        txt(im, x0 + 6, y + 2, str(i + 1), nc); txt(im, x0 + 21, y + 2, r, tc)
    return im


T = 'THE ENTRANCE HALL'
S = Image.new('RGB', (1300, 1500), (30, 30, 34))
from PIL import ImageDraw
d = ImageDraw.Draw(S)
for r, v in enumerate((1, 2)):
    frames = [menu_b(v, 2, T, MENU4[:3], 'P11A.BMP'),
              speech_b(v, 2, T, 'YOU', 'you', 'P11A.BMP', YOU_SAYS),
              speech_b(v, 2, T, 'JAMES', 'npc', 'P11A.BMP', JAMES)]
    for c, f in enumerate(frames[:2] if False else frames):
        pass
    S.paste(frames[0].resize((640, 480), Image.NEAREST), (10, 10 + r * 750 - 0))
    S.paste(frames[1].resize((640, 480), Image.NEAREST), (660, 10 + r * 750))
    S.paste(frames[2].resize((640, 480), Image.NEAREST), (10, 10 + r * 750 + 0 + 0)) if False else None
    d.text((10, 10 + r * 750 + 482), ('Variant 1: white outline for both' if v == 1 else 'Variant 2: your bubble outlined pale blue, theirs white') + ' - menu | you speak', fill=(230, 225, 200))
    S.paste(frames[2].resize((640, 480), Image.NEAREST), (10, 10 + r * 750 + 500)) if False else None
S2 = Image.new('RGB', (1300, 1500), (30, 30, 34))
d2 = ImageDraw.Draw(S2)
for r, v in enumerate((1, 2)):
    fr = [menu_b(v, 2, T, MENU4[:3], 'P11A.BMP'), speech_b(v, 2, T, 'YOU', 'you', 'P11A.BMP', YOU_SAYS),
          speech_b(v, 2, T, 'JAMES', 'npc', 'P11A.BMP', JAMES)]
    xs = [10, 440, 870]
    for c, f in enumerate(fr):
        S2.paste(f.resize((420, 315), Image.NEAREST), (xs[c], 10 + r * 340))
    d2.text((10, 10 + r * 340 + 318), 'Variant %d: %s' % (v, 'white outline for both' if v == 1 else 'you = pale-blue outline, them = white outline'), fill=(230, 225, 200))
S2 = S2.crop((0, 0, 1300, 700))
big = Image.new('RGB', (1300, 1000), (30, 30, 34))
big.paste(S2, (0, 0))
# full-size look at the two speech frames of variant 1 and 2 (James reply)
for i, v in enumerate((1, 2)):
    big.paste(speech_b(v, 2, T, 'JAMES', 'npc', 'P11A.BMP', JAMES).resize((640, 300), Image.NEAREST), (10 + i * 650, 700))
out = OUT / 'direction-black.png'
big.save(out); print(out)
