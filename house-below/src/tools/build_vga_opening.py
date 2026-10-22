"""Export generated opening backgrounds and approved coachman cutouts to DOS assets.

Creative artwork and alpha extraction are from built-in image_gen. This step
only crops the sprite sheet, sizes assets and maps them to the existing palette.
"""
from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
PAL = Image.open(ROOT / 'VGA/RM02.BMP').getpalette()
SWATCH = Image.new('P', (1, 1)); SWATCH.putpalette(PAL)
replacement = min((i for i in range(256) if i != 227),
                  key=lambda i: sum((PAL[i*3+j]-PAL[227*3+j])**2 for j in range(3)))


def cutout(cell, size, brightness=1.08, bounds=None):
    bounds = bounds or cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
    assert bounds, 'Empty cutout'
    cell = cell.crop(bounds)
    cell.thumbnail((size[0]-4, size[1]-2), Image.Resampling.LANCZOS)
    rgb = ImageEnhance.Brightness(cell.convert('RGB')).enhance(brightness)
    indexed = rgb.quantize(palette=SWATCH, dither=Image.Dither.NONE)
    indexed = indexed.point([replacement if i == 227 else i for i in range(256)])
    mask = cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
    canvas = Image.new('P', size, 227); canvas.putpalette(PAL)
    canvas.paste(indexed, ((size[0]-cell.width)//2, size[1]-cell.height), mask)
    return canvas


for source, target in [('car-interior.png', 'CAR.BMP'), ('exterior-car.png', 'RM01.BMP')]:
    master = Image.open(ROOT / 'ART/opening' / source).convert('RGB')
    master.resize((320, 184), Image.Resampling.LANCZOS).quantize(
        palette=SWATCH, dither=Image.Dither.FLOYDSTEINBERG).save(ROOT / 'VGA' / target)

master = Image.open(ROOT / 'ART/coachman/coachman-cutouts.png').convert('RGBA')
assert master.getpixel((0, 0))[3] == 0
# Production sheet keeps four full figures above four expressions.
width, height = master.size
cutout(master.crop((width//4, 0, width//2, height*61//100)), (48, 88), 1.3).save(ROOT / 'VGA/CHAR08.BMP')
cells = [master.crop((i*width//4, height*61//100, (i+1)*width//4, height)) for i in range(4)]
boxes = [cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox() for cell in cells]
bounds = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
for mood, cell in enumerate(cells):
    for state, size, brightness in [('A', (96, 104), 1.08), ('L', (72, 80), .65)]:
        cutout(cell, size, brightness, bounds).save(ROOT / 'VGA' / f'P8{mood}{state}.BMP')
print('Exported CAR.BMP, revised RM01.BMP, CHAR08.BMP and eight coachman portraits.')
