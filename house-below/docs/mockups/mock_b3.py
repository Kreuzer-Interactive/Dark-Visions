"""Direction B3 - lighter 'Balloons & Tickets' with a fixed conversation layout:
you always on the LEFT, the other person always on the RIGHT, both busts visible; the speaker's
bust is large/bright, the listener's small/dim; balloon or tickets run full width below with the
tail pointing up at whoever speaks."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *
from mock_b_funcs import rr, tag, more
from mock_b2 import base2, nearest, BROWN_D, PALEBLUE
from PIL import ImageOps


def bust_flip(im, name, x, y):
    """the NPC always faces left, toward you (the game uses uglPutMskFlip with UGL.HFLIP)"""
    p = Image.open(V / name); rgb = ImageOps.mirror(p.convert('RGB'))
    m = ImageOps.mirror(Image.frombytes('L', p.size, bytes(0 if i == 227 else 255 for i in p.tobytes())))
    im.paste(rgb, (x, y), m)



def busts(im, npc, speaker, top):
    """speaker: 'you' or 'npc' (or None while choosing: you big). Bottoms tuck behind the panel top."""
    big_you = speaker in ('you', None)
    if big_you:
        bust(im, 'P00A.BMP', 0, top - 75);  bust_flip(im, npc[:-5] + 'L.BMP', 248, top - 55)
    else:
        bust(im, 'P00L.BMP', 8, top - 55); bust_flip(im, npc, 224, top - 75)


def tail_up(im, tipx, y0, fill, line, h=11):
    """wedge rising from the balloon's top edge: apex at y0-h, widest at the balloon edge"""
    for k in range(h + 1):
        half = k * 3 // 4
        y = y0 - h + k
        for x in range(tipx - half, tipx + half + 1):
            im.putpixel((x, y), col(line) if (abs(x - tipx) >= half - 1 or k == 0) else col(fill))
    hline(im, tipx - h * 3 // 4 + 1, tipx + h * 3 // 4 - 1, y0, fill)   # open the balloon outline under the tail


def balloon_box(im, x0, y0, x1, y1, fill, line):
    rr(im, x0 + 1, y0 + 2, x1 + 1, y1 + 2, BROWN_D)
    rr(im, x0, y0, x1, y1, line)
    rr(im, x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)


def speech(n, title, who, speaker, npc, body):
    im = base2(n, title, 'warm')
    lines = wrap(body, 288)
    h = len(lines) * 9 + 15
    y1 = 195; y0 = y1 - h; x0, x1 = 6, 313
    busts(im, npc, speaker, y0)
    mine = speaker == 'you'
    fill = PALEBLUE if mine else CREAM
    balloon_box(im, x0, y0, x1, y1, fill, NAVY)
    tipx = 48 if mine else 272
    tail_up(im, tipx, y0, fill, NAVY)
    # name tag sits on the balloon's top edge on the speaker's side
    w = tw(who) + 10
    tx = 70 if mine else 240 - w
    rect(im, tx + 1, y0 - 4, tx + w, y0 + 8, BROWN_D)
    rect(im, tx, y0 - 6, tx + w - 1, y0 + 4, TEAL if mine else GOLD, NAVY)
    txt(im, tx + 5, y0 - 4, who, CREAM if mine else NAVY)
    for i, l in enumerate(lines): txt(im, x0 + 8, y0 + 9 + i * 9, l, NAVY)
    more(im, x1 - 12, y1 - 6, RED)
    return im


def card(im, x, y, w, num, label, hover):
    rect(im, x + 1, y + 1, x + w, y + 13, BROWN_D)
    if hover:
        x -= 8
        rect(im, x, y, x + w, y + 12, CREAM, NAVY); rect(im, x + 1, y + 1, x + 15, y + 11, RED); nc = CREAM
    else:
        rect(im, x, y, x + w, y + 12, GOLD, NAVY); rect(im, x + 1, y + 1, x + 15, y + 11, GOLDM); nc = NAVY
    for yy in range(y + 1, y + 12, 2): dot(im, x + 16, yy, NAVY)
    txt(im, x + 7, y + 3, num, nc); txt(im, x + 21, y + 3, label, NAVY)


def menu(n, title, rows, npc, hover=None):
    im = base2(n, title, 'warm')
    nr = len(rows); top = 196 - 13 - (nr + 1) * 14 + 1
    busts(im, npc, None, top)
    y = top
    for i, r in enumerate(rows):
        card(im, 14, y, 292, str(i + 1), r, hover == i); y += 14
    hv = hover == nr; lx = 252
    rect(im, lx + 1, y + 1, 307, y + 13, BROWN_D)
    rect(im, lx - (8 if hv else 0), y, 306 - (8 if hv else 0), y + 12, CREAM if hv else GOLD, NAVY)
    txt(im, lx + 12 - (8 if hv else 0), y + 3, 'Leave', NAVY)
    return im


T = 'THE ENTRANCE HALL'
f1 = menu(2, T, MENU4, 'P11A.BMP', hover=1)
f2 = speech(2, T, 'YOU', 'you', 'P11A.BMP', YOU_SAYS)
f3 = speech(2, T, 'JAMES', 'npc', 'P11A.BMP', JAMES)
f4 = speech('CAR', 'THE CAR', 'COACHMAN', 'npc', 'P81A.BMP', COACH)
sheet([f1, f2, f3, f4], ['B3 menu: you left, James right, tickets full width',
                         'B3 you speak: tail up to you', 'B3 James replies: tail up to him', 'B3 car: coachman replies'],
      str(OUT / 'direction-b3.png'))
