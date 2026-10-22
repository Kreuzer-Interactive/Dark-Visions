"""Export the generated portrait masters to the shared DOS palette (mode 13h sizes).

The boxed FACE/YOU bitmaps of the first prototype are gone: conversations use the transparent
expression busts only (see build_vga_expressions.py).
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
palette = Image.open(ROOT / 'VGA' / 'RM01.BMP').getpalette()
if (ROOT / 'ART' / 'portraits' / 'expressions-00.png').exists():
    from build_vga_expressions import export_expressions
    export_expressions(palette)
