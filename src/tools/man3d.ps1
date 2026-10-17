# man3d.ps1 - builds the protagonist as a low-poly textured model for the GAME7 / CAR3D
# renderer, in the car's CGA look (black fills, orange outlines, gray shirt, no dithers: the
# engine's nearest-texel sampling turns them into moire), from measurements -- no modelling
# program. The measurements are the artist's turnaround in src\ART\Man3d (front/side/back
# .png, silhouettes measured per cm of height, 2026-10-16). Writes into src\ART\Man3d:
#   man3d.3ds     the mesh (one object, Z-up as 3DS wants it; car3dcnv.ps1 reads it as is)
#   man_tex.png   the 128x128 texture atlas (top-down rows; the converter flips v itself)
#   man_atlas.png the atlas 4x with the part rectangles named (for editing by hand)
#   man_views.png preview: front / 3-4 / side / back as the game's renderer would show them
#                 (nearest texel, no lighting, mode 13h pixels stretched 1.2x as a 4:3 screen does)
# Then: car3dcnv.ps1 -Src src\ART\Man3d -Model man3d.3ds -Texture man_tex.png -Unlit ... -Out <dir>
# Params: -Height (units; the car is 83 tall = about 1.75 m, so 85 = 1.8 m), -Out, -NoPreview
param(
  [string]$Out = "$PSScriptRoot\..\ART\Man3d",
  [double]$Height = 85,
  [switch]$NoPreview,
  [int]$Seed = 7
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path $Out)) { New-Item -ItemType Directory -Path $Out | Out-Null }
$Out = (Resolve-Path $Out).Path

Add-Type -Path "$PSScriptRoot\Man3D.cs" -ReferencedAssemblies System.Drawing

# ---------------------------------------------------------------- the man
# measurements in cm from the turnaround (y up from the sole; the hair's top at 188), scaled to $Height units
$m = New-Object Man3D ($Height / 180.0), $Seed

# ---- atlas rectangles (128x128, top-down) ----
$rHead  = $m.R('head',   0,   0, 64, 40)    # around: back | his right | FRONT (centre) | his left | back ; rows crown -> chin
$rHairT = $m.R('hair',  64,   0, 16, 16)    # top cap
$rChin  = $m.R('chin',  80,   0,  8,  8)    # bottom cap under the jaw
$rNeck  = $m.R('neck',  88,   0, 24, 10)
$rHips  = $m.R('hips', 112,   0, 16, 16)    # bottom cap of the torso (trousers)
$rShldr = $m.R('shldr', 96,  16, 16, 16)    # shoulder caps (sleeve top)
$rHandT = $m.R('htip', 112,  16,  8,  8)
$rTorso = $m.R('torso', 0,  40, 128, 40)    # around: back | right | FRONT | left | back ; rows neck base -> crotch
$rUpArm = $m.R('uparm', 0,  80, 32, 16)     # shirt sleeve, rolled above the elbow
$rLoArm = $m.R('loarm', 32, 80, 32, 16)     # bare forearm
$rHand  = $m.R('hand',  64, 80, 24, 16)
$rBoot  = $m.R('boot',  88, 80, 40, 24)
$rLeg   = $m.R('leg',   0,  96, 56, 32)     # trousers: hip -> turn-up
$rSole  = $m.R('sole', 56, 104, 16, 16)

# ---- geometry ----
# a loft takes rings as a flat list: cx, cy, cz (cm), half-width, half-depth, texture row 0 (top) .. 1 (bottom)
function Flat($rings) { [double[]]@($rings | ForEach-Object { $_ }) }

# torso: from the neck base to the crotch. Measured: shoulders 49 across the back (deltoids
# included, so the ring stops short and the sleeves make the rest), chest 34, waist 29,
# hips 35, 26 cm deep; the legs part at 88
$torso = $m.Loft((Flat @(
  0, 153, 1.0,  7.0,  7.0, 0.00,    # neck base
  0, 149, 1.5, 20.5, 12.5, 0.10,    # shoulders
  0, 142, 1.0, 19.0, 13.5, 0.25,    # armpit level
  0, 134, 0.5, 17.0, 13.0, 0.40,    # chest
  0, 119, 0.0, 14.5, 12.5, 0.60,    # waist (the narrowest)
  0, 106, 0.0, 17.0, 13.5, 0.78,    # hip top (the vest hem is at 104)
  0,  96, 0.0, 17.5, 13.5, 0.90,    # hips
  0,  88, 0.0, 15.0, 12.0, 1.00     # crotch
)), 8, $rTorso, 0.35)
$m.Cap($torso[$torso.Count - 1], 10, $rHips)

# neck: 12 wide, set a little forward
$neck = $m.Loft((Flat @(0, 159, -0.5, 6.0, 6.5, 0.0,   0, 152, 0.5, 6.5, 7.0, 1.0)), 6, $rNeck, 0)

# head: a big curly head of hair (27 wide and deep at its fullest, the hairline down at 172),
# the face 17 wide, the head set 2 cm forward of the chest
$head = $m.Loft((Flat @(
  0, 188, -1.0,  5.0,  6.5, 0.00,   # crown
  0, 185, -1.5, 10.0, 11.0, 0.10,   # hair
  0, 180, -1.5, 12.0, 12.5, 0.20,   # hair, fullest
  0, 176, -2.0, 11.5, 12.0, 0.32,   # hair over the temples
  0, 172, -2.5,  9.5, 10.5, 0.46,   # the curls over the brow (hairline)
  0, 168, -2.5,  8.5, 10.0, 0.62,   # eyes
  0, 165, -2.5,  8.0,  9.5, 0.74,   # nose tip (bumped)
  0, 161, -2.0,  7.0,  8.5, 0.88,   # jaw
  0, 157, -1.5,  4.5,  5.5, 1.00    # chin
)), 8, $rHead, 0.25)
$m.Bump($head[5], 1.5); $m.Bump($head[6], 3.0)   # the nose
$m.Cap($head[0], -6, $rHairT)
$m.Cap($head[$head.Count - 1], 6, $rChin)

# arms: measured 12-13 cm thick in the rolled sleeve, the forearm 11 (muscular), the hand
# hanging at x 21-22 with the fingers at 78; a little away from the body
foreach ($side in @(-1, 1)) {
  $sx = $side
  $up = $m.Loft((Flat @(
    ($sx * 20.0), 151, 1.0, 6.5, 6.5, 0.0,   # shoulder (the deltoid, inside the torso's shoulder ring)
    ($sx * 21.5), 137, 1.0, 6.0, 6.0, 0.5,   # mid upper arm
    ($sx * 21.5), 123, 1.5, 6.5, 6.5, 1.0    # the rolled cuff above the elbow
  )), 6, $rUpArm, 0)
  $m.Cap($up[0], -5, $rShldr)
  $lo = $m.Loft((Flat @(
    ($sx * 21.5), 123,  1.5, 5.2, 5.2, 0.0,
    ($sx * 22.0), 110,  0.5, 5.5, 5.5, 0.4,  # the forearm's bulk
    ($sx * 22.5),  97, -0.5, 3.6, 3.2, 1.0   # wrist
  )), 6, $rLoArm, 0)
  $hand = $m.Loft((Flat @(
    ($sx * 22.5), 97, -0.5, 3.6, 2.2, 0.0,
    ($sx * 22.5), 88, -1.0, 4.5, 2.0, 0.5,   # palm
    ($sx * 22.5), 78, -1.5, 3.8, 1.6, 1.0    # fingertips
  )), 4, $rHand, 0.7)
  $m.Cap($hand[$hand.Count - 1], 4, $rHandT)
}

# legs: measured thighs 18 wide and 22 deep, knees 14, calves 14, the turn-ups 12, the feet
# 24 cm apart; the hips stand forward of the knees (the side view), the boots' toes forward
foreach ($side in @(-1, 1)) {
  $sx = $side
  $leg = $m.Loft((Flat @(
    ($sx * 10.0), 96, 0.0, 9.0, 11.0, 0.00,   # under the hips (inside the torso)
    ($sx * 11.0), 76, 1.0, 9.0, 10.5, 0.25,   # thigh
    ($sx * 12.0), 52, 3.0, 7.0,  9.5, 0.55,   # knee
    ($sx * 12.0), 38, 3.0, 7.0,  9.0, 0.72,   # calf
    ($sx * 12.0), 23, 3.0, 6.5,  8.5, 0.92,   # turn-up top
    ($sx * 12.0), 18, 3.0, 6.5,  8.5, 1.00    # turn-up bottom (the boot shows below)
  )), 6, $rLeg, 0.2)
  $boot = $m.Loft((Flat @(
    ($sx * 12.0), 18,  1.0, 5.5,  6.5, 0.00,  # under the turn-up (the boot's shaft)
    ($sx * 12.0), 10,  0.0, 6.0,  7.5, 0.35,  # ankle
    ($sx * 12.0),  4, -2.5, 6.5, 10.0, 0.70,  # instep
    ($sx * 12.0),  0, -5.0, 6.5, 13.0, 1.00   # sole: heel at +8, toe at -18
  )), 6, $rBoot, 0.5)
  $m.Cap($boot[$boot.Count - 1], 5, $rSole)
}

# ---------------------------------------------------------------- the texture
# K black, O orange, G gray, L light gray, C cyan, B ink
$K = [Man3D]::K; $O = [Man3D]::O; $G = [Man3D]::G; $L = [Man3D]::L; $C = [Man3D]::C; $B = [Man3D]::B

# skin = solid orange (a checker is noise in the engine); hair = black with a few orange curls
function Skin($r) { $m.Fill($r, $O) }
# light from the front: the back half of a skin tube (u < .22 or > .78) dithered darker
function Shade($r) { for ($y = $r.Y; $y -lt $r.Y + $r.H; $y++) { for ($x = $r.X; $x -lt $r.X + $r.W; $x++) { $q = ($x - $r.X) / [double]$r.W; if (($q -lt 0.22 -or $q -gt 0.78) -and $m.Get($x, $y) -eq $O -and ((($x + $y) -band 1) -eq 0)) { $m.Px($x, $y, $K) } } } }

# -- head strip: 64 wide around (back at 0 and 64, front centre at 32), 40 rows crown (188) -> chin (157).
# rows: 172 (hairline) = row 18, eyes 168 = row 25, nose tip 165 = row 30, mouth 162 = row 34, chin 157 = row 40
Skin $rHead
for ($x = 0; $x -lt 64; $x++) {
  $d = [Math]::Abs($x - 32)                           # 0 at the front, 32 at the back
  $hl = 16                                            # the forehead shows under the curls
  if ($d -gt 5) { $hl = 16 + [int](($d - 5) * 0.4) }  # lower over the temples and ears
  if ($d -gt 20) { $hl = 22 + [int](($d - 20) * 0.5) } # and down the nape at the back (164 = row 31)
  $hl += $m.Rnd.Next(0, 4) - 2                         # a ragged, curly edge
  if (($x % 5) -eq 2) { $hl += 2 }                     # a curl hanging down every so often
  for ($y = 0; $y -lt $hl; $y++) { $m.Px($x, $y, $K) }
}
# curls: a few orange ring-lets, none near the hairline so it stays dark against the face
for ($i = 0; $i -lt 80; $i++) { $x = $m.Rnd.Next(0, 64); $y = $m.Rnd.Next(0, 17); if ($m.Get($x, $y) -eq $K -and $m.Get($x, $y + 2) -eq $K -and $m.Get($x + 1, $y + 1) -eq $K) { $m.Px($x, $y, $O); $m.Px($x + 1, $y + 1, $O); if ($m.Rnd.Next(0, 2) -eq 0) { $m.Px($x, $y + 2, $O) } } }
# the face (front centre x = 32): strong brows, deep-set eyes, a straight nose, a small mouth, a square jaw
$m.HLine(25, 29, 22, $B); $m.HLine(35, 39, 22, $B)                    # brows
$m.Px(25, 23, $B); $m.Px(39, 23, $B)                                  # the brows' outer ends
$m.HLine(26, 28, 25, $B); $m.HLine(36, 38, 25, $B)                    # eyes
$m.Px(27, 25, $L); $m.Px(37, 25, $L)                                  # a glint
$m.HLine(26, 28, 24, $K); $m.HLine(36, 38, 24, $K)                    # the sockets' shadow
$m.VLine(32, 23, 29, $L)                                              # the nose's bridge (lit)
$m.VLine(33, 24, 29, $K)                                              # its shaded side
$m.HLine(30, 34, 30, $B); $m.Px(31, 29, $B); $m.Px(33, 29, $B)        # the nose's underside and nostrils
$m.HLine(29, 35, 34, $B); $m.HLine(30, 34, 35, $K)                    # the mouth, the lower lip's shadow
$m.Px(32, 37, $L)                                                     # the chin's highlight
$m.HLine(28, 36, 39, $B)                                              # under the jaw
$m.Line(21, 27, 24, 37, $B); $m.Line(43, 27, 40, 37, $B)              # the jaw's edges
$m.Px(24, 30, $L); $m.Px(40, 30, $L)                                  # cheekbones
# ears: at the sides (x = 16 and 48), rows 24..29
foreach ($ex in @(16, 48)) { $bk = $(if ($ex -lt 32) { -1 } else { 1 }); $m.VLine($ex + $bk, 24, 29, $B); $m.Px($ex, 23, $B); $m.Px($ex, 30, $B); $m.Px($ex, 26, $L) }
# hair top cap and chin cap
$m.Fill($rHairT, $K); $m.Sprinkle($rHairT, $O, 0.12)
Skin $rChin
Skin $rNeck
Shade $rNeck
$m.HLine($rNeck.X, $rNeck.X + $rNeck.W - 1, $rNeck.Y, $B)   # the shadow under the jaw

# -- torso strip: 128 wide around (back at 0/128, his right side at 32, FRONT at 64, left side at 96);
# 40 rows: neck base 153 = row 0, shoulders 149 = 4, chest 134 = 16, waist 119 = 24, vest hem 104 = 31, hips 96 = 36, crotch = 40
# base: the shirt (light gray, gray on the back half)
for ($y = $rTorso.Y; $y -lt $rTorso.Y + $rTorso.H; $y++) { for ($x = 0; $x -lt 128; $x++) { $m.Px($x, $y, $(if ($x -lt 28 -or $x -ge 100) { $G } else { $L })) } }
$ty = $rTorso.Y
# the vest: black with an orange outline; notched lapels round a V that closes at the first button (row 15);
# the armholes cut away at the sides (shirt shows at the shoulders); the hem pointed at the front
$hem = 31
for ($x = 0; $x -lt 128; $x++) {
  $d = [Math]::Abs($x - 64)          # 0 front centre, 64 back centre
  $top = 2
  if ($d -ge 22 -and $d -le 42) { $top = 11 - [int](5 * [Math]::Cos(($d - 32) / 10.0 * [Math]::PI / 2)) }   # the armhole
  if ($d -ge 16 -and $d -lt 22) { $top = 3 }
  $vee = 15 - $d * 1.6               # the V: 9 wide at the neck, closed at row 15
  if ($d -lt 10 -and $top -lt $vee) { $top = [int]$vee }
  if ($d -gt 42) { $top = 3 - [int](($d - 42) / 12) }
  $bottom = $hem; if ($d -lt 12) { $bottom = $hem + [int]((12 - $d) / 4) }   # the two points at the front hem
  for ($y = $top; $y -le $bottom; $y++) { $m.Px($x, $ty + $y, $K) }
  $m.Px($x, $ty + $top, $O); $m.Px($x, $ty + $bottom, $O)
}
# the lapels: a band 3 wide along each side of the V, notched at row 6
foreach ($sgn in @(-1, 1)) {
  for ($y = 3; $y -le 15; $y++) { $vx = 64 + $sgn * [int]((15 - $y) / 1.6); $m.Px($vx + $sgn * 3, $ty + $y, $O) }   # the lapel's outer edge
  $m.Line(64 + $sgn * 8, $ty + 6, 64 + $sgn * 11, $ty + 4, $O)      # the notch
  $m.Line(64 + $sgn * 11, $ty + 4, 64 + $sgn * 14, $ty + 7, $O)     # the collar's edge
}
# the front edge, the buttons (his right panel laps the left), the welt pockets, the chain
$m.VLine(64, $ty + 15, $ty + 33, $O)
foreach ($by in @(16, 19, 22, 25, 28)) { $m.Px(63, $ty + $by, $O); $m.Px(62, $ty + $by, $L) }
$m.HLine(70, 78, $ty + 24, $O); $m.HLine(50, 58, $ty + 24, $O)
$m.Line(64, $ty + 19, 69, $ty + 26, $O); $m.Line(69, $ty + 26, 74, $ty + 24, $O); $m.Px(66, $ty + 23, $L); $m.Px(71, $ty + 26, $L)
# the back: the side seams, a strap with a buckle at the waist
$m.VLine(0, $ty + 4, $ty + 20, $O); $m.VLine(127, $ty + 4, $ty + 20, $O)
$m.HLine(0, 14, $ty + 22, $O); $m.HLine(113, 127, $ty + 22, $O); $m.HLine(0, 14, $ty + 24, $O); $m.HLine(113, 127, $ty + 24, $O)
$m.VLine(1, $ty + 21, $ty + 25, $L); $m.VLine(126, $ty + 21, $ty + 25, $L)
$m.VLine(22, $ty + 11, $ty + 31, $O); $m.VLine(106, $ty + 11, $ty + 31, $O)   # the vest's side seams
# the shirt's standing collar, open at the front with the top button undone
for ($x = 0; $x -lt 128; $x++) { $m.Px($x, $ty + 0, $L); $m.Px($x, $ty + 1, $L); $m.Px($x, $ty + 2, $B) }
$m.HLine(59, 69, $ty + 2, $L); $m.VLine(60, $ty + 0, $ty + 4, $B); $m.VLine(68, $ty + 0, $ty + 4, $B)
$m.Px(64, $ty + 3, $B)
for ($y = 2; $y -lt 7; $y++) { for ($x = 61; $x -le 67; $x++) { if ($m.Get($x, $ty + $y) -ne $K -and $m.Get($x, $ty + $y) -ne $O) { $m.Px($x, $ty + $y, $O) } } }   # the skin in the open collar
# below the vest hem: the trousers (gray), the fly and the slanted pockets
for ($y = 29; $y -lt 40; $y++) { for ($x = 0; $x -lt 128; $x++) { $c0 = $m.Get($x, $ty + $y); if ($c0 -ne $K -and $c0 -ne $O) { $m.Px($x, $ty + $y, $G) } } }
$m.VLine(64, $ty + 34, $ty + 39, $K)                                  # the fly
$m.Line(50, $ty + 32, 46, $ty + 39, $K); $m.Line(78, $ty + 32, 82, $ty + 39, $K)   # the pockets' slanted openings
$m.Fill($rHips, $G)

# -- arms
# upper arm: the sleeve, rolled above the elbow: the roll is the bottom 5 rows (a fat band with a dark fold line)
for ($y = $rUpArm.Y; $y -lt $rUpArm.Y + $rUpArm.H; $y++) { for ($x = $rUpArm.X; $x -lt $rUpArm.X + $rUpArm.W; $x++) { $q = ($x - $rUpArm.X) / 32.0; $m.Px($x, $y, $(if ($q -lt 0.22 -or $q -gt 0.78) { $G } else { $L })) } }
$m.HLine($rUpArm.X, $rUpArm.X + 31, $rUpArm.Y + 10, $B)   # the fold above the roll
$m.HLine($rUpArm.X, $rUpArm.X + 31, $rUpArm.Y + 11, $G)
$m.HLine($rUpArm.X, $rUpArm.X + 31, $rUpArm.Y + 15, $B)   # the roll's lower edge
$m.Fill($rShldr, $L)
# forearm: skin, the roll's shadow at the top, a dark line down the back
Skin $rLoArm
Shade $rLoArm
$m.HLine($rLoArm.X, $rLoArm.X + 31, $rLoArm.Y, $B)
# hand: skin, finger lines on the lower half
Skin $rHand
Shade $rHand
foreach ($fx in @(6, 12, 18)) { $m.VLine($rHand.X + $fx, $rHand.Y + 9, $rHand.Y + 15, $B) }
$m.HLine($rHand.X, $rHand.X + 23, $rHand.Y + 7, $B)
Skin $rHandT

# -- legs: solid gray (the engine moires a checker), a dark crease down the front, seams, the turn-up band
$m.Fill($rLeg, $G)
$m.VLine($rLeg.X, $rLeg.Y, $rLeg.Y + 31, $K); $m.VLine($rLeg.X + 55, $rLeg.Y, $rLeg.Y + 31, $K)   # the back seam
$fx = $rLeg.X + $rLeg.W / 2
$m.VLine($fx, $rLeg.Y + 2, $rLeg.Y + 28, $B); $m.VLine($fx - 1, $rLeg.Y + 2, $rLeg.Y + 28, $B)   # the crease
$m.HLine($rLeg.X, $rLeg.X + 55, $rLeg.Y + 29, $B); $m.HLine($rLeg.X, $rLeg.X + 55, $rLeg.Y + 31, $B)   # the turn-up
$m.HLine($fx - 4, $fx + 4, $rLeg.Y + 17, $B)                                                         # a fold at the knee
# boots: black with orange laces up the front and a toe-cap line; the welt gray
$m.Fill($rBoot, $K)
$bx = $rBoot.X + $rBoot.W / 2
$m.HLine($rBoot.X, $rBoot.X + 39, $rBoot.Y, $O)
for ($i = 0; $i -lt 4; $i++) { $y = $rBoot.Y + 3 + $i * 3; $m.Px($bx - 2, $y, $O); $m.Px($bx + 2, $y, $O); $m.Px($bx, $y + 1, $O) }
$m.HLine($bx - 6, $bx + 6, $rBoot.Y + 17, $O)
$m.HLine($rBoot.X, $rBoot.X + 39, $rBoot.Y + 22, $G); $m.HLine($rBoot.X, $rBoot.X + 39, $rBoot.Y + 23, $G)
$m.Fill($rSole, $K); $m.HLine($rSole.X, $rSole.X + 15, $rSole.Y + 8, $G)

# ---------------------------------------------------------------- outputs
$m.Save3ds("$Out\man3d.3ds")
$m.SavePng("$Out\man_tex.png")
$m.SaveAtlas("$Out\man_atlas.png", 4)
"man3d: $($m.V.Count) vertices, $($m.F.Count) triangles -> $Out\man3d.3ds, man_tex.png"
$ys = $m.V | ForEach-Object { $_[1] }; $xs = $m.V | ForEach-Object { $_[0] }; $zs = $m.V | ForEach-Object { $_[2] }
"extent: x {0:0.0}..{1:0.0}  y {2:0.0}..{3:0.0}  z {4:0.0}..{5:0.0} units" -f ($xs | Measure -Min).Minimum, ($xs | Measure -Max).Maximum, ($ys | Measure -Min).Minimum, ($ys | Measure -Max).Maximum, ($zs | Measure -Min).Minimum, ($zs | Measure -Max).Maximum

if (-not $NoPreview) {
  # the four views at review size (camera at 150 units), in-game size (camera at 330, the car's mid-path distance),
  # and two head close-ups; each stretched 1.2x as a 4:3 monitor shows mode 13h, then 3x for looking at
  $views = @(@('front', 0.0), @('3-4', 0.6), @('side', ([Math]::PI / 2)), @('back', [Math]::PI))
  $W = 120; $H = 200; $big = 3
  $sheet = New-Object System.Drawing.Bitmap ($views.Count * ($W * $big + 6) + 700), ([int]($H * 1.2 * $big) + 24)
  $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30)); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
  $font = New-Object System.Drawing.Font 'Segoe UI', 10
  for ($i = 0; $i -lt $views.Count; $i++) {
    $bm = $m.Render($views[$i][1], 150, $W, $H, 256, 1.2, 4, 0)
    $x = $i * ($W * $big + 6)
    $g.DrawImage($bm, $x, 20, $bm.Width * $big, $bm.Height * $big); $bm.Dispose()
    $g.DrawString($views[$i][0], $font, [System.Drawing.Brushes]::White, $x, 2)
  }
  $bm = $m.Render(0.6, 330, 60, 110, 256, 1.2, 4, 0)
  $x = $views.Count * ($W * $big + 6) + 10
  $g.DrawImage($bm, $x, 20, $bm.Width * $big, $bm.Height * $big); $bm.Dispose()
  $g.DrawString('in-game size (3x)', $font, [System.Drawing.Brushes]::White, $x, 2)
  $x += 60 * $big + 10
  $hb = $m.Render(0.0, 85, 80, 80, 256, 1.2, 0, 78); $g.DrawImage($hb, $x, 240, $hb.Width * $big, $hb.Height * $big); $hb.Dispose()
  $hb = $m.Render(0.6, 85, 80, 80, 256, 1.2, 0, 78); $g.DrawImage($hb, $x + 80 * $big + 6, 240, $hb.Width * $big, $hb.Height * $big); $hb.Dispose()
  $g.DrawString('head', $font, [System.Drawing.Brushes]::White, $x, 222)
  $g.Dispose(); $sheet.Save("$Out\man_views.png"); $sheet.Dispose()
  "preview: $Out\man_views.png"
}
