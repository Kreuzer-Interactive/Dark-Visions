"""Direction B - 'Balloons & Tickets': comic speech balloons beside the speaker's bust,
menu as a stack of paper tickets.  Lives almost entirely in the black strip under the room."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *


def rr(im, x0, y0, x1, y1, c):
    """pixel-art rounded rectangle (2px corner cut)"""
    hline(im, x0 + 2, x1 - 2, y0, c)
    hline(im, x0 + 1, x1 - 1, y0 + 1, c)
    hline(im, x0 + 1, x1 - 1, y1 - 1, c)
    hline(im, x0 + 2, x1 - 2, y1, c)
    for y in range(y0 + 2, y1 - 1):
        hline(im, x0, x1, y, c)


def balloon(im, x0, y0, x1, y1, fill, line, tail_y, tail_dir, L=16):
    rr(im, x0 + 1, y0 + 2, x1 + 1, y1 + 2, NAVY)          # hard drop shadow
    rr(im, x0, y0, x1, y1, line)
    rr(im, x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
    # tail: tapering wedge that slants down towards the speaker
    x = x1 if tail_dir == 'R' else x0
    d = 1 if tail_dir == 'R' else -1
    for k in range(L + 1):
        h = max(0, (L - k) // 2)
        cy = tail_y + k // 4
        for yy in range(cy - h, cy + h + 1):
            im.putpixel((x + d * k, yy), col(line))
    for k in range(L):
        h = max(0, (L - k) // 2) - 1
        cy = tail_y + k // 4
        for yy in range(cy - h, cy + h + 1):
            im.putpixel((x + d * k, yy), col(fill))


def tag(im, x, y, name, fill=GOLD, ink=NAVY, line=NAVY):
    w = tw(name) + 10
    rect(im, x + 1, y + 2, x + w, y + 12, NAVY)                # shadow
    rect(im, x, y, x + w - 1, y + 10, fill, line)
    txt(im, x + 5, y + 2, name, ink)


def more(im, x, y, c):
    glyph(im, x, y, ['333333', '.3333.', '..33..'], {'3': c})


def speech(n, title, who, side, port, body, mine=False):
    im = base(n, title)
    lines = wrap(body, 190)
    h = len(lines) * 9 + 15
    y1 = 193
    y0 = y1 - h
    if side == 'R':
        bust(im, port, 224, 125)
        x0, x1 = 8, 214
    else:
        bust(im, port, 0, 125)
        x0, x1 = 106, 306
    if mine:      # your own words: inverted (ink) balloon
        balloon(im, x0, y0, x1, y1, PANEL, GOLD, 172, side, 12)
        ink = CREAM
        tag(im, x0 + 8, y0 - 6, who, fill=PANEL, ink=GOLD, line=GOLD)
    else:
        balloon(im, x0, y0, x1, y1, CREAM, NAVY, 172, side)
        ink = NAVY
        tag(im, x0 + 8, y0 - 6, who)
    for i, l in enumerate(lines):
        txt(im, x0 + 8, y0 + 9 + i * 9, l, ink)
    more(im, x1 - 12, y1 - 6, GOLDM if mine else RED)
    return im


def card(im, x, y, w, num, label, hover):
    rect(im, x + 1, y + 1, x + w, y + 13, NAVY)                # shadow
    if hover:
        x -= 8
        rect(im, x, y, x + w, y + 12, CREAM, NAVY)
        rect(im, x + 1, y + 1, x + 15, y + 11, RED)
        tc, nc = NAVY, CREAM
    else:
        rect(im, x, y, x + w, y + 12, GOLDM, NAVY)
        rect(im, x + 1, y + 1, x + 15, y + 11, G3)
        tc, nc = NAVY, NAVY
    for yy in range(y + 1, y + 12, 2):                         # perforation
        dot(im, x + 16, yy, NAVY)
    if num:
        txt(im, x + 7, y + 3, num, nc)
    txt(im, x + 21, y + 3, label, tc)


def menu(n, title, rows, hover=None, port='P00A.BMP'):
    im = base(n, title)
    bust(im, port, 0, 125)
    nr = len(rows)
    y = 196 - 13 - (nr + 1) * 14 + 1
    for i, r in enumerate(rows):
        card(im, 102, y, 212, str(i + 1), r, hover == i)
        y += 14
    # leave: a small dark stub, right aligned
    lx = 314 - 62
    hv = hover == nr
    rect(im, lx + 1, y + 1, 314 + 1, y + 13, NAVY)
    rect(im, lx - (8 if hv else 0), y, 314 - (8 if hv else 0), y + 12, PANEL, GOLD if hv else GOLDM)
    txt(im, lx + 12 - (8 if hv else 0), y + 3, 'Leave', CREAM if hv else G3)
    return im


T = 'THE ENTRANCE HALL'
f1 = menu(2, T, MENU4, hover=1)
f2 = speech(2, T, 'YOU', 'L', 'P00A.BMP', YOU_SAYS, mine=True)
f3 = speech(2, T, 'JAMES', 'R', 'P11A.BMP', JAMES)
f4 = speech('CAR', 'THE CAR', 'COACHMAN', 'R', 'P81A.BMP', COACH)
sheet([f1, f2, f3, f4], [
    'B1. choice menu: bust + stack of tickets, hover = lifted cream ticket',
    'B2. YOU speak: inverted ink balloon, tail to your bust',
    'B3. James replies: cream balloon, name tag, tail to his bust',
    'B4. car scene, coachman'], str(OUT / 'direction-b.png'))
