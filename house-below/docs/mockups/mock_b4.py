"""Direction B4 - B3 refined.  ONE fixed panel (y 145..196) for menu AND speech, so nothing ever
moves between frames: both busts are always full size at fixed spots (you left, the other
person right and flipped), tucked behind the panel's top edge.
 - colour = who: pale-blue = you (menu tray is blue too, you are choosing), cream = them
 - folder-tab name plate sits ABOVE the panel edge on the inner side (never on the tail);
   in the menu the same slot holds the 'Leave' tab
 - tail rises from the panel into the speaker's chin
 - inner hairline + corner studs; fixed-height panel with vertically centred text
Palette entries only; primitives only."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *
from mock_b_funcs import rr, more
from PIL import ImageOps


def nearest(rgb):
    return min(range(256), key=lambda i: sum((pal[i * 3 + j] - rgb[j]) ** 2 for j in range(3)))


BROWN_D = nearest((55, 34, 21))
PALE = 3            # (173,192,204) real pale blue already in the shared palette
PALE_IN = 252       # hairline on pale blue
PAPER = 0           # (243,238,205) paper cream
HAIR = GOLD         # hairline on cream

PX0, PX1, PY0, PY1 = 5, 314, 145, 196
LX = 2              # you
RX = 222            # them


BROWN = nearest((81, 56, 39))


def base3(n, title):
    im = Image.new('RGB', (320, 200), col(BROWN))      # the room art is only 154 rows: the rest is the old UI strip
    im.paste(room(n), (0, 0))
    dither(im, 0, 154, 319, 199, nearest((70, 44, 30)), 0)
    hline(im, 0, 319, 154, GOLDM); hline(im, 0, 319, 155, BROWN_D)
    rect(im, 0, 0, 319, 9, NAVY)
    txt(im, 5, 2, title, GOLD); txt(im, 269, 2, 'J  M  H', G3)
    return im


def bust_flip(im, name, x, y):
    p = Image.open(V / name); rgb = ImageOps.mirror(p.convert('RGB'))
    m = ImageOps.mirror(Image.frombytes('L', p.size, bytes(0 if i == 227 else 255 for i in p.tobytes())))
    im.paste(rgb, (x, y), m)


def busts(im, npc):
    bust(im, 'P00A.BMP', LX, PY0 - 70)
    bust_flip(im, npc, RX, PY0 - 70)


def panel(im, fill, hair, studs=True):
    rr(im, PX0 + 1, PY0 + 2, PX1 + 1, PY1 + 2, BROWN_D)
    rr(im, PX0, PY0, PX1, PY1, NAVY)
    rr(im, PX0 + 1, PY0 + 1, PX1 - 1, PY1 - 1, fill)
    if hair is not None:
        x0, y0, x1, y1 = PX0 + 3, PY0 + 3, PX1 - 3, PY1 - 3
        hline(im, x0 + 3, x1 - 3, y0, hair); hline(im, x0 + 3, x1 - 3, y1, hair)
        vline(im, x0, y0 + 3, y1 - 3, hair); vline(im, x1, y0 + 3, y1 - 3, hair)
        for (cx, cy, dx, dy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
            dot(im, cx + dx, cy + dy * 2, hair); dot(im, cx + dx * 2, cy + dy, hair); dot(im, cx + dx, cy + dy, hair)


def tab(im, x0, x1, fill, label, ink=NAVY, chip=None):
    """folder tab standing on the panel's top edge, same fill as what it names"""
    y0 = PY0 - 10
    rr(im, x0 + 1, y0 + 1, x1 + 1, PY0 + 1, BROWN_D)
    rr(im, x0, y0, x1, PY0 + 1, NAVY)
    rr(im, x0 + 1, y0 + 1, x1 - 1, PY0 + 1, fill)
    hline(im, x0 + 1, x1 - 1, PY0, fill); hline(im, x0 + 1, x1 - 1, PY0 + 1, fill)
    txt(im, x0 + 6, y0 + 2, label, ink)


def speech(n, title, who, speaker, npc, body):
    im = base3(n, title)
    busts(im, npc)
    mine = speaker == 'you'
    fill = PALE if mine else PAPER
    lines = wrap(body, 272)
    panel(im, fill, PALE_IN if mine else HAIR)
    tipx = 44 if mine else 276
    for k in range(10):                      # tail wedge, apex up
        half = k * 3 // 4 + 1
        y = PY0 - 9 + k
        for x in range(tipx - half, tipx + half + 1):
            edge = abs(x - tipx) >= half - 1 or k == 0
            im.putpixel((x, y), col(NAVY if edge else fill))
    hline(im, tipx - 7, tipx + 7, PY0, fill); hline(im, tipx - 7, tipx + 7, PY0 + 1, fill)
    w = tw(who) + 12
    if mine:
        tab(im, 104, 104 + w, fill, who)
    else:
        tab(im, 216 - w, 216, fill, who)
    n_l = len(lines)
    ty = PY0 + (PY1 - PY0 + 1 - (n_l * 9 - 2)) // 2
    for i, l in enumerate(lines):
        txt(im, PX0 + 11, ty + i * 9, l, NAVY)
    more(im, PX1 - 14, PY1 - 8, RED)
    return im


def ticket(im, y, num, label, hover):
    x0, x1 = 10, 309
    if hover:
        rect(im, x0, y, x1, y + 10, PAPER, NAVY)
        rect(im, x0 + 1, y + 1, x0 + 15, y + 9, RED); nc = PAPER
        for yy in range(y + 1, y + 10, 2): dot(im, x0 + 16, yy, NAVY)
        glyph(im, x1 - 8, y + 2, ['3..', '33.', '333', '33.', '3..'], {'3': RED})
    else:
        rect(im, x0, y, x1, y + 10, GOLD, NAVY)
        rect(im, x0 + 1, y + 1, x0 + 15, y + 9, GOLDM); nc = NAVY
        for yy in range(y + 1, y + 10, 2): dot(im, x0 + 16, yy, NAVY)
    txt(im, x0 + 7, y + 2, num, nc); txt(im, x0 + 21, y + 2, label, NAVY)


def menu(n, title, rows, npc, hover=None):
    im = base3(n, title)
    busts(im, npc)
    panel(im, PALE, None)
    for i, r in enumerate(rows):
        ticket(im, PY0 + 3 + i * 12, str(i + 1), r, hover == i)
    hv = hover == len(rows)
    x1 = 216; w = tw('Leave') + 12
    tab(im, x1 - w, x1, PAPER if hv else GOLD, 'Leave')
    if hv:
        rect(im, x1 - w + 2, PY0 - 8, x1 - w + 4, PY0 - 6, RED)
    return im


if __name__ == '__main__':
    T = 'THE ENTRANCE HALL'
    f1 = menu(2, T, MENU4, 'P11A.BMP', hover=1)
    f2 = speech(2, T, 'YOU', 'you', 'P11A.BMP', YOU_SAYS)
    f3 = speech(2, T, 'JAMES', 'npc', 'P11A.BMP', JAMES)
    f4 = speech('CAR', 'THE CAR', 'COACHMAN', 'npc', 'P81A.BMP', COACH)
    sheet([f1, f2, f3, f4], ['B4 menu: hovered row 2, fixed panel', 'B4 you speak', 'B4 James replies (3 lines)',
                             'B4 car: coachman replies'], str(OUT / 'direction-b4.png'))
