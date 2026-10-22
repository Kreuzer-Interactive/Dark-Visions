"""Export the original character master at the game's maximum display size."""
from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
SIZE = (48, 88)


def export_characters(palette):
    characters = Image.open(ROOT/'ART'/'visions-characters.png').convert('RGBA')
    bounds = [0,270,525,775,1030,1320,1580,1880,characters.width]
    pal = Image.new('P', (1,1)); pal.putpalette(palette)
    target = palette[227*3:227*3+3]
    replacement = min((i for i in range(256) if i != 227),
        key=lambda i: sum((palette[i*3+j]-target[j])**2 for j in range(3)))
    for n in range(8):
        sprite = characters.crop((bounds[n],0,bounds[n+1],characters.height))
        # Faint alpha specks outside the body must not shrink the figure or
        # leave invisible space beneath its shoes after DOS mask conversion.
        solid = sprite.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        sprite = sprite.crop(solid.getbbox())
        sprite.thumbnail(SIZE, Image.Resampling.LANCZOS)
        rgb = ImageEnhance.Brightness(sprite.convert('RGB')).enhance(1.4)
        rgb = rgb.quantize(palette=pal, dither=Image.Dither.NONE)
        # uGL index 227 is transparent; keep that index out of opaque pixels.
        rgb = rgb.point([replacement if i == 227 else i for i in range(256)])
        canvas = Image.new('P', SIZE, 227); canvas.putpalette(palette)
        mask = sprite.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        canvas.paste(rgb, ((SIZE[0]-sprite.width)//2,SIZE[1]-sprite.height), mask)
        canvas.save(ROOT/'VGA'/f'CHAR{n:02}.BMP')
    print('Exported 8 indexed 48x88 character masters for room-specific scaling.')


if __name__ == '__main__':
    export_characters(Image.open(ROOT/'VGA'/'RM01.BMP').getpalette())
