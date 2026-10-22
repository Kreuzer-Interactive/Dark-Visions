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


