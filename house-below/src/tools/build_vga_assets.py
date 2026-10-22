"""Reproducible VGA exports. Python 3 + Pillow; no network access required."""
from pathlib import Path
from PIL import Image, ImageEnhance
from build_vga_characters import export_characters
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'VGA'
OUT.mkdir(exist_ok=True)
atlas = Image.open(ROOT / 'ART' / 'visions-atlas.png').convert('RGB')
# Reserve sixteen stable ink/UI/sprite colors; all rooms share the other 240.
ui = [(8,10,17),(19,25,32),(42,48,53),(76,79,77),(119,119,104),
      (161,149,119),(204,181,133),(242,222,175),(68,29,31),(125,49,42),
      (42,70,85),(78,128,149),(118,174,180),(42,65,49),(87,114,65),(198,136,61)]
master = atlas.quantize(colors=240, method=Image.Quantize.MEDIANCUT)
palette = master.getpalette()[:720] + [v for c in ui for v in c]
pal = Image.new('P',(1,1)); pal.putpalette(palette)
rooms=[]
for n in range(16):
    col,row=n%4,n//4
    box=(round(col*atlas.width/4)+2,round(row*atlas.height/4)+2,
         round((col+1)*atlas.width/4)-2,round((row+1)*atlas.height/4)-2)
    im=atlas.crop(box).resize((320,184),Image.Resampling.LANCZOS)
    im=ImageEnhance.Brightness(im).enhance(1.16)
    im=im.quantize(palette=pal,dither=Image.Dither.FLOYDSTEINBERG)
    im.save(OUT/f'RM{n+1:02}.BMP')
    rooms.append(im.convert('RGB'))
sheet=Image.new('RGB',(1280,736))
for n,im in enumerate(rooms): sheet.paste(im,((n%4)*320,(n//4)*184))
sheet.save(ROOT/'ART'/'vga-contact-sheet.png')
# Preserve the original game's compact, hand-edited seven-pixel font.
tokens=[s.strip() for s in (ROOT.parents[1]/'src'/'font.txt').read_text().splitlines() if s.strip() and not s.startswith('#')]
height=int(tokens.pop(0)); glyphs={32:(3,[0]*7)}
while tokens:
    code=int(tokens.pop(0)); width=int(tokens.pop(0))
    rows=[int(tokens.pop(0),2) for _ in range(height)]
    glyphs[code]=(width,rows)
with (OUT/'FONT.DAT').open('w') as f:
    for code in range(32,127):
        width,rows=glyphs.get(code,glyphs.get(63,(3,[0]*7)))
        f.write(','.join(map(str,[width]+rows))+'\n')
assert all(Image.open(OUT/f'RM{n:02}.BMP').mode=='P' for n in range(1,17))
export_characters(palette)
if (ROOT/'ART'/'portraits'/'portrait-00.png').exists():
    import build_vga_portraits
print('Exported sixteen 320x184 indexed backgrounds, one shared 256-color palette, and font.')
