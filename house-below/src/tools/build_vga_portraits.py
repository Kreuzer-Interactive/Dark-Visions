"""Export generated portrait masters to the existing DOS palette and native sizes."""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
palette = Image.open(ROOT / 'VGA' / 'RM01.BMP').getpalette()
swatch = Image.new('P', (1, 1)); swatch.putpalette(palette)
names = ['You', 'James', 'Elias Hart', 'Ada Finch', 'Clara Vale', 'Thomas Reed', 'Miriam Bell']
sheet = Image.new('RGB', (7 * 168, 218), (8, 10, 17))
draw = ImageDraw.Draw(sheet)
for n, name in enumerate(names):
    master = Image.open(ROOT / 'ART' / 'portraits' / f'portrait-{n:02}.png').convert('RGB')
    face = ImageOps.fit(master, (80, 96), Image.Resampling.LANCZOS)
    face = face.quantize(palette=swatch, dither=Image.Dither.NONE)
    face.save(ROOT / 'VGA' / f'FACE{n:02}.BMP')
    sheet.paste(face.convert('RGB').resize((160, 192), Image.Resampling.NEAREST), (n * 168 + 4, 4))
    draw.text((n * 168 + 5, 202), name, fill=(204, 181, 133))
    if n == 0:
        small = ImageOps.fit(master, (48, 64), Image.Resampling.LANCZOS)
        small.quantize(palette=swatch, dither=Image.Dither.NONE).save(ROOT / 'VGA' / 'YOU.BMP')
sheet.save(ROOT / 'ART' / 'portraits' / 'native-contact-sheet.png')
print('Exported 7 indexed 80x96 portraits and the 48x64 player portrait.')
if (ROOT / 'ART' / 'portraits' / 'expressions-00.png').exists():
    from build_vga_expressions import export_expressions
    export_expressions(palette)
