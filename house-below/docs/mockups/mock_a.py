"""Direction A - 'The Cartouche': ornate Victorian frame, portrait cameo, hanging nameplate."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *

CORNER = ['2222221.',
          '2111111.',
          '21......',
          '21.3....',
          '21..3...',
          '21......',
          '1.......']
CC = {'1': GOLDM, '2': CREAM, '3': GOLD}
CHEV = ['3333333',
        '.33333.',
        '..333..',
        '...3...']
CROP = (20, 2, 76, 58)          # 56x56 face window out of the 96x75 portrait
PX0, PX1, PBOT = 4, 315, 197


def panel(im, top):
    rect(im, PX0, top, PX1, PBOT, PANEL, GOLDM)             # fill + outer rule
    frame(im, PX0 + 3, top + 3, PX1 - 3, PBOT - 3, G2)      # inner hairline
    glyph(im, PX0 - 1, top - 1, CORNER, CC)
    glyph(im, PX1 - 6, top - 1, CORNER, CC, flipx=True)
    glyph(im, PX0 - 1, PBOT - 5, CORNER, CC, flipy=True)
    glyph(im, PX1 - 6, PBOT - 5, CORNER, CC, flipx=True, flipy=True)


def cameo(im, side, port, name, lit=True):
    x = 10 if side == 'L' else 250
    y = 121
    rect(im, x, y, x + 59, y + 59, NAVY, GOLD)              # frame
    frame(im, x + 1, y + 1, x + 58, y + 58, G2)
    rect(im, x + 2, y + 2, x + 57, y + 57, TEAL_D)           # backdrop
    bust(im, port, x + 2, y + 2, CROP)
    for cx, cy in ((x, y), (x + 59, y), (x, y + 59), (x + 59, y + 59)):
        dot(im, cx, cy, CREAM)
    # hanging nameplate
    py = y + 61
    rect(im, x - 2, py, x + 61, py + 10, PANEL, GOLD)
    w = tw(name)
    nx = x + 30 - w // 2
    txt(im, nx, py + 2, name, CREAM)
    dot(im, nx - 5, py + 5, GOLD)
    dot(im, nx - 6, py + 5, GOLD)
    dot(im, nx + w + 3, py + 5, GOLD)
    dot(im, nx + w + 4, py + 5, GOLD)
    return x


def speech(n, title, who, side, port, body, show_you=True):
    im = base(n, title)
    panel(im, 132)
    cameo(im, side, port, who)
    tx = 80 if side == 'L' else 14
    for i, l in enumerate(wrap(body, 212)):
        txt(im, tx, 141 + i * 10, l, CREAM)
    mx = 296 if side == 'L' else 232                         # 'more' marker
    glyph(im, 300 if side == 'L' else 238, 186, CHEV, CC)
    return im


def menu(n, title, rows, hover=None, port='P00A.BMP'):
    im = base(n, title)
    nr = len(rows) + 1
    top = PBOT - 14 - nr * 12
    panel(im, top)
    cameo(im, 'L', port, 'YOU')
    x0, x1 = 78, 307
    y = top + 7
    for i in range(nr):
        hv = hover == i
        leave = i == nr - 1
        if hv:
            rect(im, x0, y, x1, y + 10, RED, GOLDM)
            glyph(im, x0 + 2, y + 2, FLAME, FLAME_C)
        else:
            hline(im, x0 + 2, x1 - 2, y + 11, G2)
        label = 'Leave' if leave else rows[i]
        if not leave:
            txt(im, x0 + 10, y + 2, str(i + 1), GOLD if hv else G3)
            txt(im, x0 + 19, y + 2, label, CREAM if hv else GOLD)
        else:
            txt(im, x0 + 10, y + 2, label, CREAM if hv else G3)
        y += 12
    return im


T = 'THE ENTRANCE HALL'
f1 = menu(2, T, MENU4, hover=1)
f2 = speech(2, T, 'YOU', 'L', 'P00A.BMP', YOU_SAYS)
f3 = speech(2, T, 'JAMES', 'R', 'P11A.BMP', JAMES)
f4 = speech('CAR', 'THE CAR', 'COACHMAN', 'R', 'P81A.BMP', COACH)
sheet([f1, f2, f3, f4], [
    'A1. choice menu, 4 rows + Leave, hover = red band + flame',
    'A2. YOU speak: cameo + plaque on the left',
    'A3. James replies: cameo flips to his side, 4 lines',
    'A4. car scene, coachman'], str(OUT / 'direction-a.png'))
