"""Shared helpers for the mode 13h (320x200) exports.

A 4:3 monitor stretches 200 lines to full height, so pictures keep their width and their height is
scaled. Scenes are 320x154 (the original 320x184 scene area x 154/184). Sprites and portraits that
were authored for the old 320x240 layout are scaled vertically by 5/6.
"""
from PIL import Image

SCENE = (320, 154)
YS = 5 / 6
PORTRAIT_CROP = 12   # rows removed from a portrait's bottom: the speech-panel tail sits there


def squash(rgba, crop_bottom=0):
    """Scale an RGBA canvas vertically by YS (width unchanged), then drop rows from the bottom."""
    w, h = rgba.size
    nh = round(h * YS)
    out = rgba.resize((w, nh), Image.Resampling.LANCZOS)
    return out.crop((0, 0, w, nh - crop_bottom))


def placed(rgb_or_rgba, alpha, size, pos):
    """Return an RGBA canvas of `size` with the picture (and its alpha) pasted at `pos`."""
    pic = rgb_or_rgba.convert('RGBA')
    pic.putalpha(alpha)
    full = Image.new('RGBA', size, (0, 0, 0, 0))
    full.paste(pic, pos)
    return full


def to_indexed(rgba, palette):
    """Quantize to the shared palette; alpha < 128 becomes the uGL mask index 227 (never used opaque)."""
    swatch = Image.new('P', (1, 1)); swatch.putpalette(palette)
    target = palette[227*3:227*3+3]
    replacement = min((i for i in range(256) if i != 227),
                      key=lambda i: sum((palette[i*3+j]-target[j])**2 for j in range(3)))
    indexed = rgba.convert('RGB').quantize(palette=swatch, dither=Image.Dither.NONE)
    indexed = indexed.point([replacement if i == 227 else i for i in range(256)])
    mask = rgba.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
    canvas = Image.new('P', rgba.size, 227); canvas.putpalette(palette)
    canvas.paste(indexed, (0, 0), mask)
    return canvas
