"""Shared helpers for the dialog-box mockups (Pillow).  Everything drawn here is
something the real engine can do: filled rects, 1px lines, single pixels, small
glyph bitmaps, masked blits of the game's own portraits, the game's 7px font,
and only palette entries 0-255 of RM01.BMP."""
from PIL import Image, ImageDraw
from pathlib import Path

V = Path(r'C:\Code\Dark-Visions\house-below\src\VGA')
OUT = Path(r'C:\Code\Dark-Visions\house-below\docs\mockups')
pal = Image.open(V / 'RM01.BMP').getpalette()


def col(i):
    return tuple(pal[i * 3:i * 3 + 3])


fw, bits = {}, {}
for code, line in zip(range(32, 127), (V / 'FONT.DAT').read_text().splitlines()):
    v = [int(x) for x in line.split(',')]
    fw[code] = v[0]
    bits[code] = v[1:]

NAVY, PANEL, G1, G2, G3, GOLDM, GOLD, CREAM = 240, 241, 242, 243, 244, 245, 246, 247
RED_D, RED, TEAL_D, TEAL, TEAL_L, AMBER = 248, 249, 250, 250, 252, 255
TEAL_D = 250


def room(n):
    if n == 'CAR':
        return Image.open(V / 'CAR.BMP').convert('RGB')
    return Image.open(V / f'RM{n:02}.BMP').convert('RGB')


def tw(s):
    return sum(fw[ord(c)] + 1 for c in s)


def txt(im, x, y, s, c):
    px = im.load()
    cc = col(c)
    for ch in s:
        a = ord(ch)
        for r in range(7):
            for k in range(fw[a]):
                if bits[a][r] & (1 << (fw[a] - 1 - k)):
                    px[x + k, y + r] = cc
        x += fw[a] + 1


def wrap(s, wide):
    lines, cur = [], ''
    for w in s.split(' '):
        if tw((cur + ' ' + w).strip()) > wide and cur:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + ' ' + w).strip()
    return lines + [cur]


def rect(im, x0, y0, x1, y1, fill, border=None):
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            px[x, y] = col(border) if (border is not None and edge) else col(fill)


def frame(im, x0, y0, x1, y1, c):
    px = im.load()
    for x in range(x0, x1 + 1):
        px[x, y0] = col(c)
        px[x, y1] = col(c)
    for y in range(y0, y1 + 1):
        px[x0, y] = col(c)
        px[x1, y] = col(c)


def hline(im, x0, x1, y, c):
    px = im.load()
    for x in range(x0, x1 + 1):
        px[x, y] = col(c)


def vline(im, x, y0, y1, c):
    px = im.load()
    for y in range(y0, y1 + 1):
        px[x, y] = col(c)


def dot(im, x, y, c):
    im.putpixel((x, y), col(c))


def glyph(im, x, y, rows, cmap, flipx=False, flipy=False):
    """small hand-drawn bitmap; '.' = transparent"""
    if flipy:
        rows = rows[::-1]
    for j, r in enumerate(rows):
        if flipx:
            r = r[::-1]
        for i, ch in enumerate(r):
            if ch != '.':
                im.putpixel((x + i, y + j), col(cmap[ch]))


def dither(im, x0, y0, x1, y1, c, phase=0):
    """checkerboard of one palette colour (poor man's translucency)"""
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + y + phase) & 1 == 0:
                px[x, y] = col(c)


def bust(im, name, x, y, crop=None):
    """masked blit of a portrait (index 227 = transparent), optional crop box"""
    p = Image.open(V / name)
    rgb = p.convert('RGB')
    m = Image.frombytes('L', p.size, bytes(0 if i == 227 else 255 for i in p.tobytes()))
    if crop:
        rgb, m = rgb.crop(crop), m.crop(crop)
    im.paste(rgb, (x, y), m)


def base(n, title, hdr=True):
    im = Image.new('RGB', (320, 200), col(NAVY))
    im.paste(room(n), (0, 0))
    if hdr:
        rect(im, 0, 0, 319, 9, NAVY)
        txt(im, 5, 2, title, GOLD)
        txt(im, 269, 2, 'J  M  H', G3)
    return im


FLAME = ['..2..',
         '.232.',
         '.2332',
         '23332',
         '23332',
         '.222.',
         '..2..']
FLAME_C = {'2': AMBER, '3': CREAM}


def sheet(frames, caps, out):
    S = Image.new('RGB', (1300, 1000), (30, 30, 34))
    d = ImageDraw.Draw(S)
    for i, (f, cap) in enumerate(zip(frames, caps)):
        g = f.resize((640, 480), Image.NEAREST)  # 2x wide, 2.4x tall = 1.2 pixel aspect
        x, y = 10 + (i % 2) * 650, 10 + (i // 2) * 500
        S.paste(g, (x, y))
        d.text((x, y + 482), cap, fill=(230, 225, 200))
    S.save(out)
    print(out)


# ---- shared sample content -------------------------------------------------
MENU4 = ['Why have you stayed here, James?', 'Where does this path lead?',
         'What keeps you busy?', 'Who winds the clock upstairs?']
YOU_SAYS = 'Where does this path lead? Not to the lake alone, I think.'
JAMES = ('Down to the lake, sir, and then nowhere you would care to walk after dark. '
         'The rest of the grounds are kept for the doctor alone, and he receives no one.')
COACH = ('Mind the road, sir. The rain has swallowed the lane twice this week, '
         'and the lamps will not reach the gate before nightfall.')
