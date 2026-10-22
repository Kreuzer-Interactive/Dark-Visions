"""Slice transparent generated sheets into small DOS-ready expression assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
from vga_common import PORTRAIT_CROP, placed, squash, to_indexed

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'ART' / 'portraits'
NAMES = ['You', 'James', 'Elias Hart', 'Ada Finch', 'Clara Vale', 'Thomas Reed', 'Miriam Bell']
MOODS = ['Attentive', 'Troubled', 'Determined', 'Warm']


def export_expressions(palette):
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
            for state, size, brightness in [('A', (96, 104), 1.08)]:
                bust = cell.crop(bounds)
                bust.thumbnail((size[0]-4, size[1]-2), Image.Resampling.LANCZOS)
                rgb = ImageEnhance.Brightness(bust.convert('RGB')).enhance(brightness)
                full = placed(rgb, bust.getchannel('A'), size, ((size[0]-bust.width)//2, size[1]-bust.height))
                # 5/6 vertical squash for mode 13h, then drop the bottom rows (speech-tail zone).
                canvas = to_indexed(squash(full, PORTRAIT_CROP), palette)
                canvas.save(ROOT / 'VGA' / f'P{person}{mood}{state}.BMP')
                if state == 'A':
                    shown = canvas.convert('RGBA')
                    shown.putalpha(Image.frombytes('L', canvas.size, bytes(0 if i == 227 else 255 for i in canvas.tobytes())))
                    shown = shown.resize((canvas.width*2, canvas.height*2), Image.Resampling.NEAREST)
                    sheet.paste(shown, (person*200+4, mood*236+4), shown)
                    draw.text((person*200+5, mood*236+216), f'{name} / {MOODS[mood]}', fill=(215, 191, 145))
    sheet.save(ART / 'expression-contact-sheet.png')
    print('Exported 28 expressions at 96x75 (28 masked BMPs; both busts are full size in conversations).')


if __name__ == '__main__':
    export_expressions(Image.open(ROOT / 'VGA' / 'RM01.BMP').getpalette())
