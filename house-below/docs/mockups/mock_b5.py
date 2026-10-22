"""Direction B5 - 'Cameos': the busts leave the room and move INTO a fixed parchment strip, so the
whole room stays clear above y 138 (no bust ever covers the scene).  Left cameo = you, right cameo
= the other person (mirrored, so both look inward).  The centre column is the balloon / ticket tray.
Speaker = gold frame + bright plate + pointer; the listener keeps a grey frame and plate.  Names are always shown on the plates."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *
from mock_b_funcs import rr, more
from mock_b4 import (nearest, BROWN_D, BROWN, PALE, PALE_IN, PAPER, HAIR, base3, ticket as _t, bust_flip)
from PIL import ImageOps

QX0, QX1, QY0, QY1 = 4, 315, 138, 196          # strip
WX = (9, 251)                                  # cameo windows (x), width 60
WY0, WY1 = 142, 186
CX0, CX1 = 73, 246                             # centre column
DIM = nearest((58, 40, 30))


def cameo(im, side, npc, lit, who):
    x0 = WX[0] if side == 'L' else WX[1]; x1 = x0 + 59
    rect(im, x0, WY0, x1, WY1, BROWN_D)
    p = Image.open(V / ('P00A.BMP' if side == 'L' else npc)).convert('RGB')
    m = Image.frombytes('L', (96, 75), bytes(0 if i == 227 else 255 for i in Image.open(V / ('P00A.BMP' if side == 'L' else npc)).tobytes()))
    if side == 'R':
        p, m = ImageOps.mirror(p), ImageOps.mirror(m)
    box = (18, 17, 78, 17 + (WY1 - WY0 - 1))
    im.paste(p.crop(box), (x0, WY0 + 1), m.crop(box))
    frame(im, x0, WY0, x1, WY1, NAVY)
    fc = GOLD if lit else G2
    frame(im, x0 + 1, WY0 + 1, x1 - 1, WY1 - 1, fc)
    # plate
    py = WY1 - 3
    rect(im, x0 - 1, py, x1 + 1, py + 10, GOLD if lit else G1, NAVY)
    txt(im, x0 + 30 - tw(who) // 2, py + 2, who, NAVY if lit else G3)


def strip(im, hair_col=GOLDM):
    rr(im, QX0 + 1, QY0 + 2, QX1 + 1, QY1 + 2, BROWN_D)
    rr(im, QX0, QY0, QX1, QY1, NAVY)
    rr(im, QX0 + 1, QY0 + 1, QX1 - 1, QY1 - 1, BROWN)
    hline(im, QX0 + 3, QX1 - 3, QY0 + 2, GOLDM)


def pointer(im, side, fill, lit_y=166):
    """small wedge from the balloon edge toward the speaker's cameo"""
    for k in range(7):
        h = 6 - k
        for dy in range(-h, h + 1):
            edge = abs(dy) == h or k == 0
            x = (CX0 - k) if side == 'L' else (CX1 + k)
            im.putpixel((x, lit_y + dy), col(NAVY if edge else fill))
    x = CX0 if side == 'L' else CX1
    vline(im, x, lit_y - 5, lit_y + 5, fill)


def column(im, fill, hair):
    rr(im, CX0 + 1, WY0 - 1 + 2, CX1 + 1, QY1 - 3 + 2, BROWN_D)
    rr(im, CX0, WY0 - 1, CX1, QY1 - 3, NAVY)
    rr(im, CX0 + 1, WY0, CX1 - 1, QY1 - 4, fill)
    if hair is not None:
        hline(im, CX0 + 5, CX1 - 5, WY0 + 2, hair); hline(im, CX0 + 5, CX1 - 5, QY1 - 6, hair)
        vline(im, CX0 + 3, WY0 + 5, QY1 - 9, hair); vline(im, CX1 - 3, WY0 + 5, QY1 - 9, hair)


def speech(n, title, who, speaker, npc, body, whoyou='YOU'):
    im = base3(n, title)
    mine = speaker == 'you'
    strip(im)
    fill = PALE if mine else PAPER
    column(im, fill, PALE_IN if mine else HAIR)
    cameo(im, 'L', npc, mine, whoyou)
    cameo(im, 'R', npc, not mine, who)
    pointer(im, 'L' if mine else 'R', fill, (WY0 + WY1) // 2 - 4)
    lines = wrap(body, 150)
    top, bot = WY0 + 3, QY1 - 8
    ty = top + (bot - top - (len(lines) * 9 - 2)) // 2
    for i, l in enumerate(lines):
        txt(im, CX0 + 9, ty + i * 9, l, NAVY)
    more(im, CX1 - 13, QY1 - 14, RED)
    return im


def ticket(im, y, num, label, hover):
    x0, x1 = CX0 + 4, CX1 - 4
    if hover:
        rect(im, x0, y, x1, y + 10, PAPER, NAVY)
        rect(im, x0 + 1, y + 1, x0 + 13, y + 9, RED); nc = PAPER
        for yy in range(y + 1, y + 10, 2): dot(im, x0 + 14, yy, NAVY)
        glyph(im, x1 - 6, y + 2, ['3..', '33.', '333', '33.', '3..'], {'3': RED})
    else:
        rect(im, x0, y, x1, y + 10, GOLD, NAVY)
        rect(im, x0 + 1, y + 1, x0 + 13, y + 9, GOLDM); nc = NAVY
        for yy in range(y + 1, y + 10, 2): dot(im, x0 + 14, yy, NAVY)
    txt(im, x0 + 6, y + 2, num, nc); txt(im, x0 + 18, y + 2, label, NAVY)


def menu(n, title, rows, npc, who, hover=None):
    im = base3(n, title)
    strip(im)
    column(im, PALE, None)
    cameo(im, 'L', npc, True, 'YOU')
    cameo(im, 'R', npc, False, who)
    for i, r in enumerate(rows):
        ticket(im, WY0 + 4 + i * 11, str(i + 1), r, hover == i)
    hv = hover == len(rows)                       # 'Leave' = tab on the column's top edge (same slot as a name tab)
    w = tw('Leave') + 12; x1 = CX1 - 4; x0 = x1 - w; ty0 = WY0 - 10
    rr(im, x0 + 1, ty0 + 1, x1 + 1, WY0 + 1, BROWN_D)
    rr(im, x0, ty0, x1, WY0 + 1, NAVY)
    rr(im, x0 + 1, ty0 + 1, x1 - 1, WY0 + 1, PAPER if hv else GOLD)
    hline(im, x0 + 1, x1 - 1, WY0 - 1, PALE); hline(im, x0 + 1, x1 - 1, WY0, PALE)
    txt(im, x0 + 6, ty0 + 2, 'Leave', RED if hv else NAVY)
    return im


if __name__ == '__main__':
    T = 'THE ENTRANCE HALL'
    f1 = menu(2, T, MENU4, 'P11A.BMP', 'JAMES', hover=1)
    f2 = speech(2, T, 'JAMES', 'you', 'P11A.BMP', YOU_SAYS)
    f3 = speech(2, T, 'JAMES', 'npc', 'P11A.BMP', JAMES)
    f4 = speech('CAR', 'THE CAR', 'COACHMAN', 'npc', 'P81A.BMP', COACH)
    sheet([f1, f2, f3, f4], ['B5 cameos: menu, hovered row 2', 'B5 you speak', 'B5 James replies', 'B5 car: coachman'],
          str(OUT / 'direction-b5.png'))
