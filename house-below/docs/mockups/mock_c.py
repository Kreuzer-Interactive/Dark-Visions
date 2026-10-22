"""Direction C - 'The Black Strip': CGA-heritage letterbox.  Everything lives in the
46px black band under the 154px room picture, so the scene is 100% visible.
Two cameos (you left, NPC right): the speaker is lit and framed in gold, the listener dimmed."""
import sys
sys.path.insert(0, r'C:\Code\Dark-Visions\house-below\docs\mockups')
from mocklib import *

SY = 154                     # strip top
CROP = (14, 3, 58, 39)       # 44x36 head window out of the 72x55 listener portrait
DIAMOND = ['....3....', '...323...', '..32123..', '...323...', '....3....']
DC = {'1': CREAM, '2': GOLD, '3': GOLDM}


def strip(im):
    rect(im, 0, SY + 1, 319, 199, PANEL)
    hline(im, 0, 319, SY, GOLD)
    hline(im, 0, 319, SY + 1, GOLDM)
    hline(im, 0, 319, SY + 3, G2)
    glyph(im, 155, SY - 2, DIAMOND, DC)


def crop_for(port):
    p = Image.open(V / port)
    m = Image.frombytes('L', p.size, bytes(0 if i == 227 else 255 for i in p.tobytes()))
    b = m.getbbox()                    # (offline: 4 bytes per portrait go in a table)
    cx = (b[0] + b[2]) // 2
    return (cx - 22, b[1], cx + 22, b[1] + 36)


def cam(im, side, port, lit):
    CROP = crop_for(port)
    x = 4 if side == 'L' else 268
    y = SY + 5
    if lit:
        rect(im, x, y, x + 47, y + 39, TEAL_D, GOLD)
        bust(im, port, x + 2, y + 2, CROP)
        hline(im, x + 1, x + 46, y + 1, CREAM)          # bevel
        vline(im, x + 1, y + 1, y + 38, CREAM)
        hline(im, x + 1, x + 46, y + 38, GOLDM)
        vline(im, x + 46, y + 2, y + 38, GOLDM)
        # re-blit so the bevel does not cover the picture edge
        bust(im, port, x + 2, y + 2, CROP)
    else:
        rect(im, x, y, x + 47, y + 39, NAVY, G2)
        bust(im, port, x + 2, y + 2, CROP)
        dither(im, x + 2, y + 2, x + 45, y + 37, NAVY)


def tab(im, x, name, c=CREAM, edge=GOLD, hov=False):
    w = tw(name) + 12
    rect(im, x, SY - 6, x + w - 1, SY + 4, TEAL_D if hov else PANEL, TEAL_L if hov else edge)
    # open the bottom edge so the tab merges with the strip
    hline(im, x + 1, x + w - 2, SY + 4, TEAL_D if hov else PANEL)
    txt(im, x + 6, SY - 3, name, c)
    return w


def frame_base(n, title, speaker, port_npc, port_you='P00A.BMP'):
    im = base(n, title)
    strip(im)
    cam(im, 'L', port_you.replace('A.','L.'), speaker == 'you')
    cam(im, 'R', port_npc.replace('A.','L.'), speaker == 'npc')
    return im


def speech(n, title, speaker, name, port_npc, body):
    im = frame_base(n, title, speaker, port_npc)
    if speaker == 'you':
        tab(im, 60, name)
        tx = 60
    else:
        w = tw(name) + 12
        tab(im, 260 - w, name)
        tx = 62
    for i, l in enumerate(wrap(body, 192)):
        txt(im, tx, SY + 6 + i * 9, l, CREAM)
    glyph(im, 250, 190, ['333333', '.3333.', '..33..'], {'3': GOLD})
    return im


def menu(n, title, rows, hover=None, port_npc='P11A.BMP'):
    im = frame_base(n, title, 'you', port_npc)
    nr = len(rows)
    y = SY + 7 + (4 - nr) * 9 // 2
    for i, r in enumerate(rows):
        hv = hover == i
        if hv:
            rect(im, 60, y - 1, 258, y + 7, TEAL_D)
            rect(im, 60, y - 1, 61, y + 7, TEAL_L)
        txt(im, 66, y, str(i + 1), CREAM if hv else G3)
        txt(im, 76, y, r, CREAM if hv else GOLD)
        y += 9
    lw = tw('LEAVE') + 12
    tab(im, 260 - lw, 'LEAVE', c=G3 if hover != nr else CREAM, edge=G2 if hover != nr else GOLD, hov=hover == nr)
    return im


T = 'THE ENTRANCE HALL'
f1 = menu(2, T, MENU4, hover=1)
f2 = speech(2, T, 'you', 'YOU', 'P11A.BMP', YOU_SAYS)
f3 = speech(2, T, 'npc', 'JAMES', 'P11A.BMP', JAMES)
f4 = speech('CAR', 'THE CAR', 'npc', 'COACHMAN', 'P81A.BMP', COACH)
sheet([f1, f2, f3, f4], [
    'C1. choice menu in the strip, hover = teal band, LEAVE is a tab on the rule',
    'C2. YOU speak: your cameo lit, James dimmed',
    'C3. James replies: his cameo lit, text 4 lines, scene untouched',
    'C4. car scene, coachman'], str(OUT / 'direction-c.png'))
