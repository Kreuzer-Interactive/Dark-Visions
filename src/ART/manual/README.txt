DARK VISIONS - MANUAL MASTERS (full colour, full resolution)
============================================================

These are the composed in-game manual VIEWS at master quality, for hand-tuning the
colour reduction and downscaling yourself. Same layout as the shipped game pages,
but 2x the size and NOT palette-reduced.

  Format      : uncompressed 24-bit BMP (true colour, ~5.76 MB each)
  Resolution  : 1600 x 1200  (exactly 2x the 800 x 600 view the game draws)
  Colour      : full RGB (the game versions are 8-bit / 256-colour indexed)

Pages render at ~1520 px wide here, which is about the native resolution of the art
embedded in the source PDF (~1440-1728 px), so this is genuinely full detail - going
larger than 1600x1200 would only upscale.

FILE MAP
--------
  MANP00.BMP   front cover (centred)
  MANP01.BMP   printed page 2   (left page, next page peeking on the right)
  MANP02.BMP   printed page 3   (right page, previous page peeking on the left)
  MANP03.BMP   printed page 4
  MANP04.BMP   printed page 5
  MANP05.BMP   printed page 6
  MANP06.BMP   printed page 7
  MANP07.BMP   printed page 8
  MANP08.BMP   printed page 9
  MANP09.BMP   back cover (centred, generated in-style; no logo)

Inside pages alternate the book layout: even printed numbers sit on the LEFT with the
next page peeking right; odd printed numbers sit on the RIGHT with the previous page
peeking left. A soft binding crease is drawn at the seam. Cover and back cover are
centred alone. "Previous / Next" hints are baked into the bottom corners.

MAKING THE GAME FILES FROM THESE
--------------------------------
The game loads 8-bit BMPs at 800 x 600 (MANP00..MANP09 in src\ and QA\current\).
To regenerate one from a master, downscale to the target size and index it:

  src\tools\img2bmp8.ps1  MANP02.BMP  ..\..\MANP02.BMP  -Width 800 -Height 600 -Reserve 0

-Reserve 0 keeps all 256 palette slots for the image; use a smaller -Width/-Height to
experiment with a lower resolution, or drop to fewer colours in your own tool before
running it. The current shipped pages were built exactly this way at 800 x 600 / 256.

SOURCE
------
Rendered from  C:\Users\jhess\Downloads\Dark-Visions-Instruction-Manual.pdf  (9 pages)
plus a generated back cover, by the compose_master.py script (scratchpad). The 1x
version of the same script produced the shipped 800 x 600 views.
