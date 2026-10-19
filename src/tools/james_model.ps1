# james_model.ps1 - James, the house attendant, as his OWN low-poly model (not the man re-textured):
# an older, slimmer, upright man in a knee-length blue frock coat (the painted James in ENTER.PIC has
# the long coat), slicked-back gray hair with a side parting, a mustache, a wing collar and tie, gray
# trousers and low polished shoes. Built like man3d.ps1 (lofted rings + a painted 128x128 atlas, the
# game's CGA colours, no dithers) in the same units as the man (83.6 = 188 cm; James is 183 cm).
# For viewing and editing in 3ds Max -- nothing in the game uses it. Writes into src\ART\Man3d:
#   james_new.obj / .mtl  the mesh with UVs and its material (Max: File > Import, the texture comes along);
#                         one group per piece (head, neck, torso, skirt, arms, hands, legs, shoes)
#   james_new.3ds         the same mesh, one object (no material: 3DS here is for car3dcnv / tdsview)
#   james_new_tex.png     the texture atlas; james_new_atlas.png = it 4x with the parts named
#   james_new_views.png   front / 3-4 / side / back + in-game size, through the game renderer's look
param(
  [string]$Out = "$PSScriptRoot\..\ART\Man3d",
  [string]$Name = 'james_new',
  [int]$Seed = 11
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$Out = (Resolve-Path $Out).Path
if (-not ('Man3D' -as [type])) { Add-Type -Path "$PSScriptRoot\Man3D.cs" -ReferencedAssemblies System.Drawing }

# the man's units: 83.6 units = 188 cm
$m = New-Object Man3D (83.6 / 188.0), $Seed
function Flat($rings) { [double[]]@($rings | ForEach-Object { $_ }) }
$parts = New-Object System.Collections.Generic.List[object]
function Part($name, [scriptblock]$build) { $f0 = $m.F.Count; & $build; $parts.Add(@($name, $f0, $m.F.Count)) }

# ---- atlas (128x128, top-down) ----
$rHead  = $m.R('head',   0,   0, 64, 40)    # around: back | his right | FRONT (x 32) | his left | back ; rows crown 183 -> chin 152
$rHairT = $m.R('hair',  64,   0, 16, 16)
$rChin  = $m.R('chin',  80,   0,  8,  8)
$rNeck  = $m.R('neck',  88,   0, 24, 10)    # rows 156 -> 148: skin, then the wing collar
$rHips  = $m.R('hips', 112,   0, 16, 16)
$rShldr = $m.R('shldr', 96,  16, 16, 16)
$rHandT = $m.R('htip', 112,  16,  8,  8)
$rTorso = $m.R('torso', 0,  40, 128, 40)    # around: back | right | FRONT (x 64) | left | back ; rows 148 -> 88
$rUpArm = $m.R('uparm', 0,  80, 32, 16)     # coat sleeve, shoulder -> elbow
$rLoArm = $m.R('loarm', 32, 80, 32, 16)     # coat sleeve, elbow -> cuff, the shirt cuff showing
$rHand  = $m.R('hand',  64, 80, 24, 16)
$rShoe  = $m.R('shoe',  88, 80, 40, 24)
$rLeg   = $m.R('leg',   0,  96, 56, 32)     # trousers, 96 -> 10
$rSole  = $m.R('sole', 56, 104, 16, 16)
$rSkirt = $m.R('skirt', 72, 104, 56, 24)    # the coat's skirt: around (front at x 100), waist 110 -> hem 54

# ---- geometry (cm, y up from the sole, front = -z) ----
Part 'torso' {
  # upright, narrower in the shoulders than the man, a little belly under the waistcoat
  $script:torso = $m.Loft((Flat @(
    0, 148,  1.0,  7.0,  7.0, (0 / 60.0),
    0, 144,  1.5, 19.5, 12.5, (4 / 60.0),    # shoulders (the coat's padding)
    0, 137,  1.0, 18.5, 13.0, (11 / 60.0),   # armpit
    0, 128,  0.0, 17.0, 13.5, (20 / 60.0),   # chest
    0, 116, -1.0, 16.0, 14.5, (32 / 60.0),   # waist: the belly
    0, 106, -0.5, 16.3, 14.0, (42 / 60.0),
    0,  96,  0.0, 16.5, 13.0, (52 / 60.0),
    0,  88,  0.0, 14.5, 11.5, 1.0
  )), 8, $rTorso, 0.35)
  $m.Cap($script:torso[$script:torso.Count - 1], 10, $rHips)
}
Part 'skirt' {
  # the frock coat's skirt: from the waist seam to just above the knee, flaring, outside the hips and legs
  $null = $m.Loft((Flat @(
    0, 110, -0.5, 17.2, 15.0, 0.0,
    0,  98,  0.0, 18.0, 15.0, (12 / 56.0),
    0,  80,  0.5, 19.0, 15.5, (30 / 56.0),
    0,  62,  0.5, 20.0, 16.0, (48 / 56.0),
    0,  54,  0.5, 20.5, 16.5, 1.0
  )), 8, $rSkirt, 0.35)
}
Part 'neck' { $null = $m.Loft((Flat @(0, 156, -0.5, 5.5, 6.0, 0.0,   0, 148, 0.5, 6.8, 7.2, 1.0)), 6, $rNeck, 0) }
Part 'head' {
  # hair slicked close to the skull (not the man's big curls), a long face, a strong nose, a jaw
  $hr = @(
    @(183, -1.0, 5.0, 6.0), @(180, -1.0, 9.0, 10.5), @(176, -1.2, 10.0, 11.5), @(172, -1.5, 9.5, 11.0),
    @(168, -2.0, 8.5, 10.0), @(164, -2.0, 8.2, 9.8), @(161, -2.0, 7.8, 9.4), @(158, -1.8, 7.2, 8.8),
    @(155, -1.5, 6.3, 7.8), @(152, -1.0, 4.3, 5.4))
  $fl = @(); foreach ($q in $hr) { $fl += @(0, $q[0], $q[1], $q[2], $q[3], ((183 - $q[0]) / 31.0)) }
  $script:head = $m.Loft((Flat $fl), 8, $rHead, 0.25)
  $m.Bump($script:head[5], 1.5); $m.Bump($script:head[6], 3.2); $m.Bump($script:head[7], 1.0)   # brow ridge, nose, mustache
  $m.Cap($script:head[0], -6, $rHairT)
  $m.Cap($script:head[$script:head.Count - 1], 6, $rChin)
}
foreach ($side in @(-1, 1)) {
  $sx = $side; $nm = $(if ($side -lt 0) { 'R' } else { 'L' })
  Part "arm$nm" {
    # the coat sleeves: a little wider than the man's, hanging straight (a servant's posture)
    $up = $m.Loft((Flat @(
      ($sx * 19.5), 145, 1.0, 6.2, 6.5, 0.0,
      ($sx * 21.5), 132, 1.2, 5.8, 6.0, 0.5,
      ($sx * 22.5), 120, 1.5, 5.5, 5.8, 1.0
    )), 6, $rUpArm, 0)
    $m.Cap($up[0], -5, $rShldr)
    $null = $m.Loft((Flat @(
      ($sx * 22.5), 120,  1.5, 5.3, 5.6, 0.0,
      ($sx * 23.0), 108,  0.5, 5.0, 5.3, 0.45,
      ($sx * 23.3),  99, -0.5, 4.6, 4.9, 0.8,    # the sleeve's end
      ($sx * 23.3),  97, -0.5, 3.4, 3.6, 1.0     # the shirt cuff
    )), 6, $rLoArm, 0)
  }
  Part "hand$nm" {
    # palms towards the thighs: thin across x, wide along z
    $hand = $m.Loft((Flat @(
      ($sx * 23.3), 97, -0.5, 2.2, 3.4, 0.0,
      ($sx * 23.5), 89, -1.0, 2.3, 4.2, 0.5,
      ($sx * 23.3), 81, -1.5, 1.8, 3.2, 1.0
    )), 4, $rHand, 0.7)
    $m.Cap($hand[$hand.Count - 1], 4, $rHandT)
  }
}
foreach ($side in @(-1, 1)) {
  $sx = $side; $nm = $(if ($side -lt 0) { 'R' } else { 'L' })
  Part "leg$nm" {
    # slimmer than the man's, feet closer (heels together-ish: a man standing to attention)
    $null = $m.Loft((Flat @(
      ($sx *  9.5), 96, 0.5, 8.0, 9.5, 0.0,
      ($sx * 10.0), 76, 1.0, 7.5, 9.0, (20 / 86.0),
      ($sx * 10.0), 52, 2.5, 6.3, 7.8, (44 / 86.0),
      ($sx * 10.0), 38, 2.5, 6.0, 7.2, (58 / 86.0),
      ($sx *  9.5), 10, 2.5, 5.0, 6.0, 1.0
    )), 6, $rLeg, 0.2)
  }
  Part "shoe$nm" {
    # low polished shoes: lower and slimmer than the man's boots
    $shoe = $m.Loft((Flat @(
      ($sx * 9.5), 10,  1.5, 4.6, 5.8, 0.0,
      ($sx * 9.5),  5, -1.5, 5.0, 8.8, 0.45,
      ($sx * 9.5),  0, -4.0, 5.0, 12.3, 1.0     # heel at +8.3, toe at -16.3
    )), 6, $rShoe, 0.5)
    $m.Cap($shoe[$shoe.Count - 1], 5, $rSole)
  }
}

# ---- texture ----
$K = [Man3D]::K; $O = [Man3D]::O; $G = [Man3D]::G; $L = [Man3D]::L; $B = [Man3D]::B; $U = [byte]7
function Shade($r) { for ($y = $r.Y; $y -lt $r.Y + $r.H; $y++) { for ($x = $r.X; $x -lt $r.X + $r.W; $x++) { $q = ($x - $r.X) / [double]$r.W; if (($q -lt 0.22 -or $q -gt 0.78) -and $m.Get($x, $y) -eq $O -and ((($x + $y) -band 1) -eq 0)) { $m.Px($x, $y, $K) } } } }

# -- head: 64 around (front x 32), rows: hairline 171 = 15, brows 167 = 21, eyes 165 = 23, nose tip 161 = 28,
#    mustache 159..157 = 31..34, mouth 156 = 35, chin 152 = 40
$m.Fill($rHead, $O)
for ($x = 0; $x -lt 64; $x++) {
  $d = [Math]::Abs($x - 32)
  $hl = 14                                              # a high forehead
  if ($d -ge 4 -and $d -lt 10) { $hl = 12 }             # receding at the temples
  if ($d -ge 10) { $hl = 14 + [int](($d - 10) * 0.6) }  # down over the ears' tops
  if ($d -ge 20) { $hl = 20 + [int](($d - 20) * 0.7) }  # to the nape (row ~28)
  for ($y = 0; $y -lt $hl; $y++) { $m.Px($x, $y, $G) }
  $m.Px($x, $hl - 1, $B)                                # a crisp edge: hair oiled flat
}
foreach ($cy in @(3, 7)) { for ($x = 0; $x -lt 64; $x += 1) { if ((($x + $cy) % 6) -lt 3) { $m.Px($x, $cy, $K) } } }   # comb lines running back
$m.VLine(39, 0, 11, $B)                                 # the side parting (his left)
# the face: gray brows, deep eyes, a long nose, a full black mustache, a thin mouth, the jaw line
$m.HLine(26, 29, 21, $G); $m.HLine(35, 38, 21, $G)
$m.HLine(26, 29, 23, $B); $m.HLine(35, 38, 23, $B); $m.Px(27, 23, $L); $m.Px(37, 23, $L)
$m.HLine(26, 29, 22, $K); $m.HLine(35, 38, 22, $K)
$m.VLine(32, 21, 27, $L); $m.VLine(33, 22, 27, $K)      # the nose
$m.HLine(30, 34, 28, $B); $m.Px(31, 27, $B); $m.Px(33, 27, $B)
for ($y = 30; $y -le 33; $y++) { $w = $(if ($y -eq 30) { 4 } else { 6 }); $m.HLine(32 - $w, 32 + $w, $y, $B) }   # the mustache
$m.Px(25, 34, $B); $m.Px(39, 34, $B)                    # its ends drooping
$m.HLine(30, 34, 35, $B)                                # the mouth
$m.Px(32, 37, $L); $m.HLine(28, 36, 39, $B)
$m.Line(22, 26, 25, 37, $B); $m.Line(42, 26, 39, 37, $B)
$m.Line(24, 30, 26, 32, $K); $m.Line(40, 30, 38, 32, $K)   # the lines of age by the nose
foreach ($ex in @(16, 48)) { $bk = $(if ($ex -lt 32) { -1 } else { 1 }); $m.VLine($ex + $bk, 22, 28, $B); $m.Px($ex, 21, $B); $m.Px($ex, 29, $B); $m.Px($ex, 25, $L) }
$m.Fill($rHairT, $G); for ($i = 0; $i -lt 16; $i += 3) { $m.HLine($rHairT.X, $rHairT.X + 15, $rHairT.Y + $i, $K) }
$m.Fill($rChin, $O)
# -- neck: skin over the wing collar (rows 4..10 = 153..148), the tie's knot at the front (x 12)
$m.Fill($rNeck, $O); Shade $rNeck
for ($y = 4; $y -lt 10; $y++) { $m.HLine($rNeck.X, $rNeck.X + 23, $rNeck.Y + $y, $L) }
$m.HLine($rNeck.X, $rNeck.X + 23, $rNeck.Y + 4, $B)
$m.Line($rNeck.X + 12, $rNeck.Y + 5, $rNeck.X + 9, $rNeck.Y + 8, $B); $m.Line($rNeck.X + 12, $rNeck.Y + 5, $rNeck.X + 15, $rNeck.Y + 8, $B)   # the wings
$m.VLine($rNeck.X + 12, $rNeck.Y + 6, $rNeck.Y + 9, $B); $m.VLine($rNeck.X + 11, $rNeck.Y + 7, $rNeck.Y + 9, $B); $m.VLine($rNeck.X + 13, $rNeck.Y + 7, $rNeck.Y + 9, $B)

# -- torso: 128 around (front x 64); rows 148 -> 88 (40 rows: row = (148 - y) * 2 / 3); the skirt
#    covers it below the waist seam (110 = row 25)
$m.Fill($rTorso, $U); $ty = $rTorso.Y
for ($y = 0; $y -le 18; $y++) {
  # the V of the open coat: wide at the collar, closed at the top button (row 18 = 121 cm)
  $vw = [int](13 - $y * 13 / 18.0)
  for ($x = 64 - $vw; $x -le 64 + $vw; $x++) {
    $d = [Math]::Abs($x - 64)
    $c = $G                                             # the waistcoat
    if ($y -le 6 -and $d -le (6 - $y)) { $c = $L }      # the shirt front above it
    $m.Px($x, $ty + $y, $c)
  }
  $m.Px(64 - $vw - 1, $ty + $y, $B); $m.Px(64 + $vw + 1, $ty + $y, $B)   # the lapels' inner edge
  $m.Px(64 - $vw - 5, $ty + $y, $B); $m.Px(64 + $vw + 5, $ty + $y, $B)   # their outer edge
}
$m.Line(64 - 18, $ty + 4, 64 - 14, $ty + 7, $B); $m.Line(64 + 18, $ty + 4, 64 + 14, $ty + 7, $B)   # the notches
$m.VLine(64, $ty + 0, $ty + 11, $B); $m.VLine(63, $ty + 1, $ty + 9, $B); $m.VLine(65, $ty + 1, $ty + 9, $B)   # the tie
foreach ($by in @(10, 13, 16)) { $m.Px(64, $ty + $by, $L) }        # the waistcoat's buttons
$m.VLine(64, $ty + 19, $ty + 39, $B)                    # the coat's closing edge
foreach ($by in @(20, 24)) { $m.Px(66, $ty + $by, $L); $m.Px(67, $ty + $by, $L) }   # the coat's buttons
$m.HLine(42, 50, $ty + 15, $B)                          # the breast pocket (his left)...
$m.HLine(44, 48, $ty + 14, $L)                          # ...and the handkerchief
$m.VLine(0, $ty + 6, $ty + 39, $B); $m.VLine(127, $ty + 6, $ty + 39, $B)   # the back seam
$m.VLine(24, $ty + 9, $ty + 39, $B); $m.VLine(104, $ty + 9, $ty + 39, $B)  # side seams
$m.HLine(0, 127, $ty + 25, $B)                          # the waist seam
for ($x = 0; $x -lt 128; $x++) { $m.Px($x, $ty, $U) }   # the coat's collar at the neck
$m.Fill($rHips, $G)
# -- the skirt: 56 around (front x 28), 24 rows waist (110) -> hem (54); the front edges meet at the
#    centre, a vent up the back, flapped hip pockets
$m.Fill($rSkirt, $U); $sxr = $rSkirt.X; $syr = $rSkirt.Y
$m.HLine($sxr, $sxr + 55, $syr, $B)                     # the waist seam
$m.VLine($sxr + 28, $syr, $syr + 23, $B)                # the front edge
$m.VLine($sxr, $syr + 9, $syr + 23, $B); $m.VLine($sxr + 55, $syr + 9, $syr + 23, $B)   # the back vent
$m.HLine($sxr, $sxr + 55, $syr + 23, $B)                # the hem
foreach ($px0 in @(13, 37)) { $m.HLine($sxr + $px0, $sxr + $px0 + 6, $syr + 3, $B); $m.HLine($sxr + $px0, $sxr + $px0 + 6, $syr + 6, $B); $m.VLine($sxr + $px0, $syr + 3, $syr + 6, $B); $m.VLine($sxr + $px0 + 6, $syr + 3, $syr + 6, $B) }
foreach ($by in @(2, 9)) { $m.Px($sxr + 30, $syr + $by, $L) }   # buttons below the waist
# -- sleeves, cuffs, hands
$m.Fill($rUpArm, $U); $m.VLine($rUpArm.X, $rUpArm.Y, $rUpArm.Y + 15, $B); $m.VLine($rUpArm.X + 31, $rUpArm.Y, $rUpArm.Y + 15, $B)
$m.Fill($rShldr, $U)
$m.Fill($rLoArm, $U); $m.VLine($rLoArm.X, $rLoArm.Y, $rLoArm.Y + 12, $B); $m.VLine($rLoArm.X + 31, $rLoArm.Y, $rLoArm.Y + 12, $B)
$m.HLine($rLoArm.X, $rLoArm.X + 31, $rLoArm.Y + 12, $B)   # the sleeve's end
for ($y = 13; $y -lt 16; $y++) { $m.HLine($rLoArm.X, $rLoArm.X + 31, $rLoArm.Y + $y, $L) }   # the shirt cuff
foreach ($bx in @(12, 15, 18)) { $m.Px($rLoArm.X + $bx, $rLoArm.Y + 10, $L) }   # sleeve buttons
$m.Fill($rHand, $O); Shade $rHand
foreach ($fx in @(6, 12, 18)) { $m.VLine($rHand.X + $fx, $rHand.Y + 9, $rHand.Y + 15, $B) }
$m.HLine($rHand.X, $rHand.X + 23, $rHand.Y + 7, $B)
$m.Fill($rHandT, $O)
# -- trousers: gray with a sharp crease; shoes black with a shine and a gray welt
$m.Fill($rLeg, $G)
$m.VLine($rLeg.X, $rLeg.Y, $rLeg.Y + 31, $K); $m.VLine($rLeg.X + 55, $rLeg.Y, $rLeg.Y + 31, $K)
$fx = $rLeg.X + $rLeg.W / 2
$m.VLine($fx, $rLeg.Y + 2, $rLeg.Y + 31, $B)
$m.HLine($rLeg.X, $rLeg.X + 55, $rLeg.Y + 31, $B)
$m.Fill($rShoe, $K)
$bx = $rShoe.X + $rShoe.W / 2
$m.HLine($rShoe.X, $rShoe.X + 39, $rShoe.Y, $G)          # the trouser hem's shadow line
$m.HLine($bx - 3, $bx + 3, $rShoe.Y + 6, $B); $m.Px($bx - 1, $rShoe.Y + 8, $L); $m.Px($bx + 1, $rShoe.Y + 16, $L); $m.Px($bx, $rShoe.Y + 17, $L)   # laces' bar, the shine
$m.HLine($rShoe.X, $rShoe.X + 39, $rShoe.Y + 22, $G); $m.HLine($rShoe.X, $rShoe.X + 39, $rShoe.Y + 23, $G)
$m.Fill($rSole, $K); $m.HLine($rSole.X, $rSole.X + 15, $rSole.Y + 8, $G)

# ---- outputs ----
$m.Save3ds("$Out\$Name.3ds")
$m.SavePng("$Out\${Name}_tex.png")
$m.SaveAtlas("$Out\${Name}_atlas.png", 4)
# OBJ (Y up, front -Z: Max's importer turns it Z-up) with a group per piece and the material
$IC = [Globalization.CultureInfo]::InvariantCulture
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# James (Dark Visions), tools\james_model.ps1 -- units: 83.6 = 188 cm (the man's); front = -Z, Y up")
[void]$sb.AppendLine("mtllib $Name.mtl")
foreach ($p in $m.V) { [void]$sb.AppendLine(('v {0} {1} {2}' -f $p[0].ToString('0.0000', $IC), $p[1].ToString('0.0000', $IC), $p[2].ToString('0.0000', $IC))) }
foreach ($t in $m.UV) { [void]$sb.AppendLine(('vt {0} {1}' -f ($t[0] / 128.0).ToString('0.000000', $IC), (1.0 - $t[1] / 128.0).ToString('0.000000', $IC))) }
foreach ($p in $parts) {
  [void]$sb.AppendLine("g $($p[0])"); [void]$sb.AppendLine("usemtl james")
  for ($i = $p[1]; $i -lt $p[2]; $i++) { $f = $m.F[$i]; [void]$sb.AppendLine(('f {0}/{0} {1}/{1} {2}/{2}' -f ($f[0] + 1), ($f[1] + 1), ($f[2] + 1))) }
}
[IO.File]::WriteAllText("$Out\$Name.obj", $sb.ToString())
[IO.File]::WriteAllText("$Out\$Name.mtl", "newmtl james`r`nKa 1 1 1`r`nKd 1 1 1`r`nKs 0 0 0`r`nillum 1`r`nmap_Kd ${Name}_tex.png`r`n")
"${Name}: $($m.V.Count) vertices, $($m.F.Count) triangles, $($parts.Count) pieces -> $Out\$Name.obj/.mtl/.3ds, ${Name}_tex.png"
$ys = $m.V | ForEach-Object { $_[1] }; $xs = $m.V | ForEach-Object { $_[0] }; $zs = $m.V | ForEach-Object { $_[2] }
"extent: x {0:0.0}..{1:0.0}  y {2:0.0}..{3:0.0}  z {4:0.0}..{5:0.0} units" -f ($xs | Measure -Min).Minimum, ($xs | Measure -Max).Maximum, ($ys | Measure -Min).Minimum, ($ys | Measure -Max).Maximum, ($zs | Measure -Min).Minimum, ($zs | Measure -Max).Maximum

# ---- preview: the four views, in-game size, the head (as man3d.ps1 draws them) ----
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
$hb = $m.Render(0.0, 85, 80, 80, 256, 1.2, 0, 76); $g.DrawImage($hb, $x, 240, $hb.Width * $big, $hb.Height * $big); $hb.Dispose()
$hb = $m.Render(0.6, 85, 80, 80, 256, 1.2, 0, 76); $g.DrawImage($hb, $x + 80 * $big + 6, 240, $hb.Width * $big, $hb.Height * $big); $hb.Dispose()
$g.DrawString('head', $font, [System.Drawing.Brushes]::White, $x, 222)
$g.Dispose(); $sheet.Save("$Out\${Name}_views.png"); $sheet.Dispose()
"preview: $Out\${Name}_views.png"
