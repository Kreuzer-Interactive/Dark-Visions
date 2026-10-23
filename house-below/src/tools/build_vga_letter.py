"""Scale the generated lap close-up to VGA with four pixels of shake overscan.

Only exports LETTER.BMP; leaves the existing car, rooms and characters untouched.
"""
from pathlib import Path
from PIL import Image
from vga_common import SCENE

ROOT = Path(__file__).resolve().parents[1]
palette = Image.open(ROOT / 'VGA/RM02.BMP').getpalette()
swatch = Image.new('P', (1, 1))
swatch.putpalette(palette)
master = Image.open(ROOT / 'ART/opening/letter-lap.png').convert('RGB')
size = (SCENE[0] + 8, SCENE[1] + 8)
master.resize(size, Image.Resampling.LANCZOS).quantize(
    palette=swatch, dither=Image.Dither.FLOYDSTEINBERG
).save(ROOT / 'VGA/LETTER.BMP')
print(f'Exported LETTER.BMP: {size[0]}x{size[1]}, shared 256-color palette.')
