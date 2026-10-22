"""Export the original character master at the game's maximum display size."""
from pathlib import Path
from PIL import Image, ImageEnhance
from vga_common import placed, squash, to_indexed

ROOT = Path(__file__).resolve().parents[1]
SIZE = (48, 88)      # master canvas before the 5/6 vertical squash
OUT = (48, 73)       # shipped 13h size; PrepareActors samples it with sy = y * 73 \ height


def export_characters(palette):
    characters = Image.open(ROOT/'ART'/'visions-characters.png').convert('RGBA')
    bounds = [0,270,525,775,1030,1320,1580,1880,characters.width]
    for n in range(8):
        sprite = characters.crop((bounds[n],0,bounds[n+1],characters.height))
        # Faint alpha specks outside the body must not shrink the figure or
        # leave invisible space beneath its shoes after DOS mask conversion.
        solid = sprite.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        sprite = sprite.crop(solid.getbbox())
        sprite.thumbnail(SIZE, Image.Resampling.LANCZOS)
        rgb = ImageEnhance.Brightness(sprite.convert('RGB')).enhance(1.4)
        full = placed(rgb, sprite.getchannel('A'), SIZE, ((SIZE[0]-sprite.width)//2, SIZE[1]-sprite.height))
        # uGL index 227 is transparent; to_indexed keeps that index out of opaque pixels.
        canvas = to_indexed(squash(full), palette)
        assert canvas.size == OUT
        canvas.save(ROOT/'VGA'/f'CHAR{n:02}.BMP')
    print('Exported 8 indexed 48x73 character masters for room-specific scaling.')


if __name__ == '__main__':
    export_characters(Image.open(ROOT/'VGA'/'RM01.BMP').getpalette())
