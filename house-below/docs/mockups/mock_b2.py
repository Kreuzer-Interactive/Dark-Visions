"""Direction B2 - 'Balloons & Tickets', lighter: no black strip (warm leather band or a mirrored
floor extension), parchment tickets, pale-blue player balloon. Palette entries only."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *
from mock_b_funcs import rr, balloon, tag, more


def nearest(rgb):
    return min(range(256), key=lambda i: sum((pal[i*3+j]-rgb[j])**2 for j in range(3)))

BROWN = nearest((88, 56, 38))      # leather band
BROWN_D = nearest((52, 32, 24))    # soft shadow
PALEBLUE = 252


def base2(n, title, band):
    im = Image.new('RGB', (320, 200), col(BROWN))
    art = room(n)
    im.paste(art, (0, 0))
    if band == 'mirror':   # reflect the floor into the lower 46 rows, darkened by a checker dither
        for y in range(154, 200):
            src = 153 - (y - 154) * 154 // 154
            row = art.crop((0, src, 320, src + 1))
            im.paste(row, (0, y))
        dither(im, 0, 154, 319, 199, BROWN_D, 0)
    else:                  # warm leather band with a gold rule and a faint dither
        dither(im, 0, 154, 319, 199, nearest((70, 44, 30)), 0)
        hline(im, 0, 319, 154, GOLDM); hline(im, 0, 319, 155, BROWN_D)
    rect(im, 0, 0, 319, 9, NAVY)
    txt(im, 5, 2, title, GOLD); txt(im, 269, 2, 'J  M  H', G3)
    return im


def speech(n, title, who, side, port, body, band, mine=False):
    im = base2(n, title, band)
    lines = wrap(body, 190)
    h = len(lines) * 9 + 15
    y1 = 193; y0 = y1 - h
    if side == 'R':
        bust(im, port, 224, 125); x0, x1 = 8, 214
    else:
        bust(im, port, 0, 125); x0, x1 = 106, 306
    fill = PALEBLUE if mine else CREAM
    balloon(im, x0, y0, x1, y1, fill, NAVY, 172, side, 12 if mine else 16)
    tag(im, x0 + 8, y0 - 6, who, fill=(TEAL if mine else GOLD), ink=(CREAM if mine else NAVY))
    for i, l in enumerate(lines):
        txt(im, x0 + 8, y0 + 9 + i * 9, l, NAVY)
    more(im, x1 - 12, y1 - 6, RED)
    return im


def card(im, x, y, w, num, label, hover):
    rect(im, x + 1, y + 1, x + w, y + 13, BROWN_D)
    if hover:
        x -= 8
        rect(im, x, y, x + w, y + 12, CREAM, NAVY)
        rect(im, x + 1, y + 1, x + 15, y + 11, RED)
        nc = CREAM
    else:
        rect(im, x, y, x + w, y + 12, GOLD, NAVY)
        rect(im, x + 1, y + 1, x + 15, y + 11, GOLDM)
        nc = NAVY
    for yy in range(y + 1, y + 12, 2): dot(im, x + 16, yy, NAVY)
    txt(im, x + 7, y + 3, num, nc); txt(im, x + 21, y + 3, label, NAVY)


def menu(n, title, rows, band, hover=None, port='P00A.BMP'):
    im = base2(n, title, band)
    bust(im, port, 0, 125)
    nr = len(rows); y = 196 - 13 - (nr + 1) * 14 + 1
    for i, r in enumerate(rows):
        card(im, 102, y, 212, str(i + 1), r, hover == i); y += 14
    lx = 252; hv = hover == nr
    rect(im, lx + 1, y + 1, 315, y + 13, BROWN_D)
    rect(im, lx - (8 if hv else 0), y, 314 - (8 if hv else 0), y + 12, CREAM if hv else GOLD, NAVY)
    txt(im, lx + 12 - (8 if hv else 0), y + 3, 'Leave', NAVY)
    return im


T = 'THE ENTRANCE HALL'
for band in ('warm', 'mirror'):
    f1 = menu(2, T, MENU4, band, hover=1)
    f2 = speech(2, T, 'YOU', 'L', 'P00A.BMP', YOU_SAYS, band, mine=True)
    f3 = speech(2, T, 'JAMES', 'R', 'P11A.BMP', JAMES, band)
    f4 = speech('CAR', 'THE CAR', 'COACHMAN', 'R', 'P81A.BMP', COACH, band)
    sheet([f1, f2, f3, f4], ['B2 menu: parchment tickets', 'B2 you speak: pale-blue balloon',
                             'B2 James: cream balloon', 'B2 car scene'], str(OUT / f'direction-b2-{band}.png'))
