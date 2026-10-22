"""Slice transparent generated sheets into small DOS-ready expression assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'ART' / 'portraits'
NAMES = ['You', 'James', 'Elias Hart', 'Ada Finch', 'Clara Vale', 'Thomas Reed', 'Miriam Bell']
MOODS = ['Attentive', 'Troubled', 'Determined', 'Warm']


def export_expressions(palette):
    swatch = Image.new('P', (1, 1)); swatch.putpalette(palette)
    target = palette[227*3:227*3+3]
    replacement = min((i for i in range(256) if i != 227),
                      key=lambda i: sum((palette[i*3+j]-target[j])**2 for j in range(3)))
    sheet = Image.new('RGB', (7*200, 4*236), (13, 19, 23))
    draw = ImageDraw.Draw(sheet)
    for person, name in enumerate(NAMES):
        master = Image.open(ART / f'expressions-{person:02}.png').convert('RGBA')
        assert master.getchannel('A').getextrema()[0] == 0, 'Real transparency required'
        cells = [master.crop((col*master.width//2, row*master.height//2,
                             (col+1)*master.width//2, (row+1)*master.height//2))
                 for row in range(2) for col in range(2)]
        boxes = [cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox() for cell in cells]
        assert all(boxes), name
        # A shared crop retains the same head scale across every expression.
        bounds = (min(b[0] for b in boxes), min(b[1] for b in boxes),
                  max(b[2] for b in boxes), max(b[3] for b in boxes))
        for mood, cell in enumerate(cells):
            for state, size, brightness in [('A', (96, 104), 1.08), ('L', (72, 80), 0.65)]:
                bust = cell.crop(bounds)
                bust.thumbnail((size[0]-4, size[1]-2), Image.Resampling.LANCZOS)
                rgb = ImageEnhance.Brightness(bust.convert('RGB')).enhance(brightness)
                indexed = rgb.quantize(palette=swatch, dither=Image.Dither.NONE)
                indexed = indexed.point([replacement if i == 227 else i for i in range(256)])
                mask = bust.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
                canvas = Image.new('P', size, 227); canvas.putpalette(palette)
                canvas.paste(indexed, ((size[0]-bust.width)//2, size[1]-bust.height), mask)
                canvas.save(ROOT / 'VGA' / f'P{person}{mood}{state}.BMP')
                if state == 'A':
                    shown = canvas.convert('RGBA')
                    shown.putalpha(Image.frombytes('L', canvas.size, bytes(0 if i == 227 else 255 for i in canvas.tobytes())))
                    shown = shown.resize((192, 208), Image.Resampling.NEAREST)
                    sheet.paste(shown, (person*200+4, mood*236+4), shown)
                    draw.text((person*200+5, mood*236+216), f'{name} / {MOODS[mood]}', fill=(215, 191, 145))
    sheet.save(ART / 'expression-contact-sheet.png')
    print('Exported 28 expressions, each with bright 96x104 and dim 72x80 variants (56 masked BMPs).')


if __name__ == '__main__':
    export_expressions(Image.open(ROOT / 'VGA' / 'RM01.BMP').getpalette())
