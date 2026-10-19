# manwalk.ps1 - the walk-around test scene for the 3D man: converts a model + texture with
# car3dcnv.ps1, stages everything MANWALK.EXE needs in dist\manwalk, and runs it.
#   manwalk.ps1                      stage the default (the artist's man_v2.3ds + man_tex.png) and open DOSBox-X on it
#   manwalk.ps1 -Model man3d.3ds     the procedural model instead (any .3ds in src\ART\Man3d)
#   manwalk.ps1 -Anim src\ART\Man3d\man_walk.fbx   the walk as edited in 3ds Max (exported as FBX, Bake Animation on)
#   manwalk.ps1 -Room 8              the man in a house room (1..11: they share one template) instead of on the road
#   manwalk.ps1 -Room 8 -Picture src\ART\Man3d\ROOM8_POC_test.png   the room drawn bigger (a 320x200 picture in the
#                                    rooms' 4 colours, the template scaled about a point): the scale and offset fitted
#                                    from its front floor line (or -PicScale -PicDX -PicDY: new = scale x old + d), and
#                                    the camera, his size, the walk mask, the front pieces and the hit points with it
#   manwalk.ps1 -HotCheck            headless: MANWALK H -> an action and a look on the room's things: MANHOT0..2.BMP + MANHOT.LOG
#   manwalk.ps1 -PathCheck           headless: MANWALK P -> two scripted clicks round the furniture: MANPATH1/2.BMP + MANPATH.LOG
#   manwalk.ps1 -GoCheck             headless: MANWALK W -> a scripted click to walk and one to face: MANGO1/2.BMP + MANGO.LOG
#   manwalk.ps1 -IdleCheck           headless: MANWALK I -> the fidgets' shots dist\manwalk\MANIDL1..4.BMP, MANIDLE.DMP, a turn each way MANTRN1/2.BMP
#   manwalk.ps1 -Check               headless: MANWALK S -> dist\manwalk\MANWLK1/2.BMP + MANWALK.LOG, printed
#   manwalk.ps1 -Bench [-Push486]    MANWALK B: each phase of a frame timed with the PIT -> MANWALK.LOG, printed
#   manwalk.ps1 -Push486             push the staged folder to the 486 (\MANWALK) and start MANWALK there
#   manwalk.ps1 -Push486 -Check      ...the scripted run there; pull MANWALK.LOG and the BMPs back afterwards
# Keys in the scene: Up/Down walk, Left/Right turn, Space = a copy of the model where he stands (up to 7),
# C clears the copies, A sets the copies walking in place, V toggles the vertical-sync wait, F/G/D the raster's
# flat/quad/dot thresholds, O cycles the outline (off / on his edge / 1 px round him / 2 px), [ ] its colour (the 16 CGA colours), Esc quits (prints the fps at exit). He walks with MAN3D.ANI
# (man3danim.ps1, baked from the staged model) when it is there.
param(
  [string]$Model = 'man_v2.3ds',
  [string]$Anim = '',
  [string]$Idle = '',          # the idle clips' FBX (default src\ART\Man3d\man_idle.fbx when it is there; 'none' = without)          # an animated FBX from 3ds Max (man3dfbx.ps1 made the first one): its mesh and its walk
  [int]$Room = 0,              # a house room (1..11, ROOMn.PIC) as the scene instead of the intro road
  [string]$Picture = '',       # in a room: this picture (PNG, 320x200, the rooms' colours) instead of ROOMn.PIC -- the template scaled
  [double]$PicScale = 0,       # ...its scale and offset against the template (0 = fitted from the picture's front floor line)
  [double]$PicDX = 0,
  [double]$PicDY = 0,
  [double]$BackScale = 0.65,   # in a room: his size at the back wall against the front (the art's perspective alone: 0.61)
  [double]$FrontHeight = 36,   # in a room: his height in pixels, outline included, at the front edge (the 2D sprite is 29, drawn for mid-room)
  [double]$RefHeight = 83.6,   # ...for a man this tall (units; the man as first modelled, 188 cm): a shorter model is drawn shorter (0 = whatever the model's height)
  [int]$Outline = 2,           # the outline he starts with: 0 off, 1 brown on his edge pixels, 2 blue 1 px round him, 3 blue 2 px, 4 blue only where his black meets a black floor, 5 the same inside his edge (O cycles them)
  [string]$Texture = 'man_tex.png',
  [double]$Scale = 1.0,
  [switch]$Check,
  [switch]$IdleCheck,
  [switch]$GoCheck,
  [switch]$PathCheck,
  [switch]$HotCheck,
  [switch]$Bench,
  [switch]$Push486,
  [switch]$NoStage,
  [string]$Npc = '',            # a second character beside him: his walk FBX (made by man3dfbx.ps1 on his own mesh, e.g. src\ART\Man3d\james_v2_walk.fbx) -> JAMES.MDL/.BMP/JAMESW.ANI; Tab drives him
  [string]$NpcIdle = '',        # ...his idle clips' FBX (default: the walk's name with _walk -> _idle) -> JAMESI.ANI
  [string]$NpcTexture = 'james_new_tex.png',   # ...his texture (in src\ART\Man3d)
  [string]$NpcClips = 'breathe,look,turnL,turnR'   # ...the idle clips he may play (the clips file's names; the rest are left out of his file)
)
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path "$PSScriptRoot\..").Path
$art = "$src\ART\Man3d"
$st = (Resolve-Path "$src\..").Path + "\dist\manwalk"
if (-not (Test-Path $st)) { New-Item -ItemType Directory $st | Out-Null }
if (-not $NoStage) {
  if (-not (Test-Path "$src\tools\MANWALK.EXE")) { throw "src\tools\MANWALK.EXE missing: build it with tools\build1.ps1 MANWALK -Modules MWROOM,MWANIM" }
  if ($Anim) {
    # the mesh from the animated FBX itself, so the walk's vertices line up with it
    $Anim = (Resolve-Path $Anim).Path
    & "$PSScriptRoot\fbx2tds.ps1" -In $Anim -Out "$art\man_anim.3ds" | Select-Object -First 2
    $Model = 'man_anim.3ds'
  }
  $backdrop = "..\Car3d\carr_road2.png"; $cfg = ''
  if ($Room -gt 0) {
    # the room picture (CGA, 2 bpp, BSAVE) in the rooms' palette (ROOMn.PAC: 0 black, 1 dark gray, 2 blue, 3 brown)
    Add-Type -AssemblyName System.Drawing
    $pb = [IO.File]::ReadAllBytes("$src\ROOM$Room.PIC"); $bm = New-Object System.Drawing.Bitmap 320, 200
    $cols = @([System.Drawing.Color]::FromArgb(0,0,0), [System.Drawing.Color]::FromArgb(85,85,85), [System.Drawing.Color]::FromArgb(0,0,170), [System.Drawing.Color]::FromArgb(170,85,0))
    for ($y = 0; $y -lt 200; $y++) { $row = 7 + ($y % 2) * 8192 + [Math]::Floor($y / 2) * 80; for ($x = 0; $x -lt 320; $x++) { $ci = ($pb[$row + [Math]::Floor($x / 4)] -shr (6 - 2 * ($x % 4))) -band 3; $bm.SetPixel($x, $y, $cols[$ci]) } }
    # (-Picture: that picture instead, and the template's scale and offset in it)
    $ps = 1.0; $pdx = 0.0; $pdy = 0.0
    if ($Picture) {
      $bm.Dispose(); $bm = New-Object System.Drawing.Bitmap 320, 200
      $pic = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Picture).Path)
      for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) { $bm.SetPixel($x, $y, $pic.GetPixel($x, $y)) } }
      $pic.Dispose()
      if ($PicScale -gt 0) { $ps = $PicScale; $pdx = $PicDX; $pdy = $PicDY } else {
        # the front floor line: the longest brown row in the lower half; the template's runs 54..249 at y 177
        $br = [System.Drawing.Color]::FromArgb(170, 85, 0).ToArgb(); $best = 0; $by = 0; $bx = 0
        for ($y = 100; $y -lt 200; $y++) { $run = 0; for ($x = 0; $x -lt 320; $x++) { if ($bm.GetPixel($x, $y).ToArgb() -eq $br) { $run++; if ($run -gt $best) { $best = $run; $by = $y; $bx = $x - $run + 1 } } else { $run = 0 } } }
        $ps = $best / 196.0; $pdx = $bx - $ps * 54; $pdy = $by - $ps * 177
      }
      "picture: $([IO.Path]::GetFileName($Picture)), the template x $([Math]::Round($ps, 3)) + ($([Math]::Round($pdx, 1)), $([Math]::Round($pdy, 1)))"
    }
    $bm.Save("$st\room_bg.png"); $bm.Dispose()
    $backdrop = "..\..\..\dist\manwalk\room_bg.png"
    # the camera, solved from the template the rooms share (measured in the pictures): the front floor edge
    # at y 177, the side walls' front top corners at y 130.8, the back wall's floor line at 135.3 and its
    # top at 107; the floor's corners 92.5 px either side of x 151.5 at the front, 55.75 at the back. The
    # verticals stay vertical, so a level camera with its picture centre shifted: the horizon where the
    # front and back wall heights agree; the scale from the back-wall doorway (room 2: 65% of the wall)
    # taken as 2.1 m, so the walls are 3.2 m = 142.3 units (the man: 188 cm = 83.6 units)
    $yff = 177.0 * $ps + $pdy; $yft = 130.8 * $ps + $pdy; $ybf = 135.3 * $ps + $pdy; $ybt = 107.0 * $ps + $pdy; $W = 142.3
    $h = ($yff * $ybt - $yft * $ybf) / ($yff + $ybt - $yft - $ybf)
    $Hc = $W * ($yff - $h) / ($yff - $yft)
    $zf = 256 * $Hc / ($yff - $h); $zb = 256 * $Hc / ($ybf - $h)
    # across, 307 px per unit at unit depth (256 x 1.2): the 320x200 pixels are 1.2 times taller than wide
    $fx = 256 * 1.2
    $xn = 92.5 * $ps * $zf / $fx; $xf = 55.75 * $ps * $zb / $fx; $pcx = 151.5 * $ps + $pdx
    $IC = [Globalization.CultureInfo]::InvariantCulture
    $cfg = (@($pcx, $h, $Hc, $zf, $zb, $xn, $xf, $fx) | ForEach-Object { ([double]$_).ToString('0.0', $IC) }) -join ','
    $cfg += ',' + $BackScale.ToString('0.00', $IC)
    $roomZ = @($zf, $zb)
    "room $Room camera: centre $([Math]::Round($pcx, 1)),$([Math]::Round($h, 1)) px, $([Math]::Round($Hc / 44.47, 2)) m above the floor, the floor $([Math]::Round($zf / 44.47, 1))..$([Math]::Round($zb / 44.47, 1)) m away, $([Math]::Round(2 * $xn / 44.47, 1))..$([Math]::Round(2 * $xf / 44.47, 1)) m wide; at the back he keeps $BackScale of his front size (perspective alone: $([Math]::Round($zf / $zb, 2)))"
  }
  & "$PSScriptRoot\car3dcnv.ps1" -Src $art -Model $Model -Texture $Texture -Unlit -Scale $Scale -Backdrop $backdrop -Out $st | Select-Object -Last 3
  if ($Room -gt 0) {
    # his overall scale: at the front edge the depth rule leaves him at true size, so the rest makes his
    # height there FrontHeight (less the 2 px of outline); mid-room and the back follow from BackScale
    $mb = [IO.File]::ReadAllBytes("$st\CAR3D.MDL"); $nv = [BitConverter]::ToInt16($mb, 4); $y0 = 1e9; $y1 = -1e9
    for ($i = 0; $i -lt $nv; $i++) { $y = [BitConverter]::ToSingle($mb, 14 + $i * 20); if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } }
    $refH = if ($RefHeight -gt 0) { $RefHeight } else { $y1 - $y0 }
    $trueFront = 256 * $refH / $roomZ[0]
    if ($Picture -and -not $PSBoundParameters.ContainsKey('FrontHeight')) { $FrontHeight = 2 + ($FrontHeight - 2) * $ps }
    $rsc = ($FrontHeight - 2) / $trueFront
    $cfg += ',' + $rsc.ToString('0.000', $IC)
    $mid = ($FrontHeight - 2) * (1 + ($BackScale - 1) / 2) + 2; $back = ($FrontHeight - 2) * $BackScale + 2
    "his height: $([Math]::Round($FrontHeight)) px at the front edge, $([Math]::Round($mid)) at mid-room, $([Math]::Round($back)) at the back wall (scale $([Math]::Round($rsc, 3)) over true size at the front); this model: $([Math]::Round(2 + ($FrontHeight - 2) * ($y1 - $y0) / $refH)) px at the front"
  }
  [IO.File]::WriteAllText("$st\ROOM.CFG", $cfg)   # empty = the road
  # the room's walk mask (src\ART\Rooms\roomN_walk.png, tools\walkmask.ps1 makes a starter) -> ROOM.WLK,
  # 1 bit a pixel (white = his feet may stand there), high bit left; empty = no mask
  $wpng = "$src\ART\Rooms\room${Room}_walk.png"; $wb = [byte[]]@()
  # (-Picture: a template-sized mask read through the picture's scale and offset)
  function Remap($bmp) {
    if (-not $Picture -or $ps -eq 1 -and $pdx -eq 0 -and $pdy -eq 0) { return $bmp }
    $o = New-Object System.Drawing.Bitmap 320, 200
    for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) {
      $sx = [int][Math]::Floor(($x - $pdx) / $ps); $sy = [int][Math]::Floor(($y - $pdy) / $ps)
      if ($sx -ge 0 -and $sx -lt 320 -and $sy -ge 0 -and $sy -lt 200) { $o.SetPixel($x, $y, $bmp.GetPixel($sx, $sy)) } else { $o.SetPixel($x, $y, [System.Drawing.Color]::Black) }
    } }
    $bmp.Dispose(); return $o
  }
  if ($Room -gt 0 -and (Test-Path $wpng)) {
    Add-Type -AssemblyName System.Drawing
    $wm = Remap ([System.Drawing.Bitmap]::FromFile($wpng)); $wb = New-Object byte[] 8000; $nw = 0
    for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) { $c = $wm.GetPixel($x, $y); if ($c.R + $c.G + $c.B -gt 384) { $wb[$y * 40 + [Math]::Floor($x / 8)] = $wb[$y * 40 + [Math]::Floor($x / 8)] -bor (128 -shr ($x % 8)); $nw++ } } }
    $wm.Dispose(); "walk mask: room${Room}_walk.png, $nw walkable pixels"
  } elseif ($Room -gt 0 -and (Test-Path "$src\ROOM$Room.BOX")) {
    # no painted mask: the game's walk boxes (ROOMn.BOX: convex quads, 4 corners each, in feet pixels)
    # filled in -- coarser (they keep clear of whole furniture fronts) but every room has them
    $wb = New-Object byte[] 8000; $nw = 0
    $boxes = @(Get-Content "$src\ROOM$Room.BOX" | Where-Object { $_ -match '\d' } | ForEach-Object { ,([int[]]($_ -split ',')) })
    for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) {
      foreach ($q in $boxes) {
        $pos = 0; $neg = 0
        for ($k = 0; $k -lt 4; $k++) { $ax = $q[2 * $k]; $ay = $q[2 * $k + 1]; $bx = $q[(2 * $k + 2) % 8]; $by = $q[(2 * $k + 3) % 8]; $cr = ($bx - $ax) * ($y - $ay) - ($by - $ay) * ($x - $ax); if ($cr -gt 0) { $pos++ } elseif ($cr -lt 0) { $neg++ } }
        if ($pos -eq 0 -or $neg -eq 0) { $wb[$y * 40 + [Math]::Floor($x / 8)] = $wb[$y * 40 + [Math]::Floor($x / 8)] -bor (128 -shr ($x % 8)); $nw++; break }
      } } }
    "walk mask: from ROOM$Room.BOX ($($boxes.Count) boxes, $nw walkable pixels)"
  }
  [IO.File]::WriteAllBytes("$st\ROOM.WLK", $wb)
  # the room's front pieces (src\ART\Rooms\roomN_front.png, tools\occmask.ps1 makes a starter; a colour a
  # piece) -> ROOM.OCC: "C3O1", n%, per piece x0% y0% w% h% base% (its lowest row), then the masks, a byte
  # a pixel; empty = none
  $fpng = "$src\ART\Rooms\room${Room}_front.png"; $ob = [byte[]]@()
  if ($Room -gt 0 -and (Test-Path $fpng)) {
    Add-Type -AssemblyName System.Drawing
    $fm = Remap ([System.Drawing.Bitmap]::FromFile($fpng)); $px = @{}
    for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 320; $x++) { $c = $fm.GetPixel($x, $y); if ($c.R + $c.G + $c.B -gt 0) { $key = $c.ToArgb(); if (-not $px.ContainsKey($key)) { $px[$key] = New-Object System.Collections.Generic.List[int] }; $px[$key].Add($y * 320 + $x) } } }
    $fm.Dispose()
    $hdr = New-Object System.Collections.Generic.List[byte]; $msk = New-Object System.Collections.Generic.List[byte]
    $hdr.AddRange([Text.Encoding]::ASCII.GetBytes('C3O1')); $hdr.AddRange([BitConverter]::GetBytes([int16]$px.Count))
    foreach ($key in $px.Keys) {
      $l = $px[$key]; $x0 = 320; $y0 = 200; $x1 = 0; $y1 = 0
      foreach ($q in $l) { $qx = $q % 320; $qy = [Math]::Floor($q / 320); if ($qx -lt $x0) { $x0 = $qx }; if ($qx -gt $x1) { $x1 = $qx }; if ($qy -lt $y0) { $y0 = $qy }; if ($qy -gt $y1) { $y1 = $qy } }
      $w = $x1 - $x0 + 1; $hh = $y1 - $y0 + 1; $mb = New-Object byte[] ($w * $hh)
      foreach ($q in $l) { $mb[([Math]::Floor($q / 320) - $y0) * $w + ($q % 320 - $x0)] = 1 }
      foreach ($v in $x0, $y0, $w, $hh, $y1) { $hdr.AddRange([BitConverter]::GetBytes([int16]$v)) }
      $msk.AddRange($mb)
    }
    $hdr.AddRange($msk); $ob = $hdr.ToArray()
    "front pieces: room${Room}_front.png, $($px.Count) pieces"
  }
  [IO.File]::WriteAllBytes("$st\ROOM.OCC", $ob)
  # the room's things: the game's own room file (ROOMn.PAC: hit points, objects and their text, stand
  # points), as it is -> ROOM.PAC; empty on the road
  if ($Room -gt 0) {
    $pac = @(Get-Content "$src\ROOM$Room.PAC")
    if ($Picture) {
      # (-Picture: the hit points -- the lines before 0,0,0 -- and the -2 stand points through the map)
      $ph = 1
      for ($i = 1; $i -lt $pac.Count; $i++) {
        $w = $pac[$i] -split ','
        if ($ph -eq 1) {
          if ($pac[$i].Trim() -eq '0,0,0') { $ph = 2; continue }
          $pac[$i] = "$([Math]::Round([int]$w[0] * $ps + $pdx)),$([Math]::Round([int]$w[1] * $ps + $pdy)),$($w[2])"
        } elseif ($w.Count -ge 5 -and $w[0].Trim() -eq '-2') {
          $w[2] = [string][Math]::Round([int]$w[2] * $ps + $pdx); $w[3] = [string][Math]::Round([int]$w[3] * $ps + $pdy); $pac[$i] = $w -join ','
        }
      }
    }
    [IO.File]::WriteAllLines("$st\ROOM.PAC", [string[]]$pac); "room's things: ROOM$Room.PAC$(if ($Picture) { ', moved with the picture' })"
  }
  else { [IO.File]::WriteAllBytes("$st\ROOM.PAC", [byte[]]@()) }
  foreach ($x in 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'SHADBOP.OVL', 'C3DEDGE.OVL', 'C3DEDGO.OVL', 'C3DEDGK.OVL', 'C3DEDGI.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL', 'C3DSKIN.OVL', 'C3DMSE.OVL', 'C3DMCPY.OVL') { Copy-Item "$src\$x" $st -Force }
  Copy-Item "$src\tools\MANWALK.EXE" $st -Force
  # the walk, baked from the model just converted (its vertex order)
  if ($Anim) { & "$PSScriptRoot\man3dfbx.ps1" -Import $Anim -Mdl "$st\CAR3D.MDL" -Out "$st\MAN3D.ANI" -Preview "$art\man_walk.png" | Select-String 'fbx:|skin|stride|->' }
  else { & "$PSScriptRoot\man3danim.ps1" -Mdl "$st\CAR3D.MDL" -Out "$st\MAN3D.ANI" -Preview "$art\man_walk.png" | Select-String 'stride|->' }
  # the idle clips (man3dfbx.ps1 -Idle made them; the artist's edits come back the same way)
  if (-not $Idle) { $Idle = "$art\man_idle.fbx" }
  if (Test-Path "$st\MANIDLE.ANI") { [IO.File]::Delete("$st\MANIDLE.ANI") }
  if ($Idle -ne 'none' -and (Test-Path $Idle)) { & "$PSScriptRoot\man3dfbx.ps1" -Idle -Import (Resolve-Path $Idle).Path -Mdl "$st\CAR3D.MDL" -Out "$st\MANIDLE.ANI" | Select-String 'kept|worst|->' }
  else { [IO.File]::WriteAllBytes("$st\MANIDLE.ANI", [byte[]]@()); "no idle clips" }
  # the second character (-Npc): his mesh and texture converted like the man's, his texture's colours
  # merged into CAR3D.BMP's palette (the two share the screen's 256: an exact match where the man's
  # texture has the colour, else a free slot from 16 up -- never 0..15, the backdrop's, which the
  # outline routines take for background), his walk and the clips he may play baked on his mesh.
  # Without -Npc the files are written empty (MANWALK then shows the man alone; empty files on the
  # 486 replace an earlier push's)
  foreach ($x in 'JAMES.MDL', 'JAMES.BMP', 'JAMESW.ANI', 'JAMESI.ANI') { [IO.File]::WriteAllBytes("$st\$x", [byte[]]@()) }
  if ($Npc) {
    $Npc = (Resolve-Path $Npc).Path
    if (-not $NpcIdle) { $NpcIdle = $Npc -replace '_walk(\.fbx)$', '_idle$1' }
    $nt = Join-Path $env:TEMP 'manwalk_npc'; if (Test-Path $nt) { [IO.Directory]::Delete($nt, $true) }; New-Item -ItemType Directory $nt | Out-Null
    & "$PSScriptRoot\fbx2tds.ps1" -In $Npc -Out "$nt\npc.3ds" | Select-Object -First 1
    Copy-Item "$art\$NpcTexture" "$nt\npc_tex.png"
    & "$PSScriptRoot\car3dcnv.ps1" -Src $nt -Model npc.3ds -Texture npc_tex.png -Unlit -Scale $Scale -Out $nt | Select-Object -Last 2
    Copy-Item "$nt\CAR3D.MDL" "$st\JAMES.MDL" -Force
    $mb = [IO.File]::ReadAllBytes("$st\CAR3D.BMP"); $nb = [IO.File]::ReadAllBytes("$nt\CAR3D.BMP")
    if ([BitConverter]::ToInt32($nb, 18) -ne [BitConverter]::ToInt32($mb, 18)) { throw "the second character's texture must be as wide as the man's" }
    $used = @{}; for ($i = 1078; $i -lt $mb.Length; $i++) { $used[[int]$mb[$i]] = 1 }
    $map = @{ 255 = 255 }; $added = 0
    for ($i = 1078; $i -lt $nb.Length; $i++) {
      $k = [int]$nb[$i]; if ($map.ContainsKey($k)) { continue }
      $b = $nb[54 + 4 * $k]; $g = $nb[55 + 4 * $k]; $r = $nb[56 + 4 * $k]; $hit = -1
      for ($j = 16; $j -lt 255; $j++) { if ($used.ContainsKey($j) -and $mb[54 + 4 * $j] -eq $b -and $mb[55 + 4 * $j] -eq $g -and $mb[56 + 4 * $j] -eq $r) { $hit = $j; break } }
      if ($hit -lt 0) {
        for ($j = 16; $j -lt 255; $j++) { if (-not $used.ContainsKey($j)) { $hit = $j; break } }
        if ($hit -lt 0) { throw "no free palette slot for the second character's colours" }
        $mb[54 + 4 * $hit] = $b; $mb[55 + 4 * $hit] = $g; $mb[56 + 4 * $hit] = $r; $used[$hit] = 1; $added++
      }
      $map[$k] = $hit
    }
    for ($i = 1078; $i -lt $nb.Length; $i++) { $nb[$i] = [byte]$map[[int]$nb[$i]] }
    [Array]::Copy($mb, 54, $nb, 54, 1024)
    [IO.File]::WriteAllBytes("$st\CAR3D.BMP", $mb); [IO.File]::WriteAllBytes("$st\JAMES.BMP", $nb)
    "second character: $([IO.Path]::GetFileName($Npc)) + $NpcTexture, $($map.Count - 1) colours ($added new in the palette)"
    & "$PSScriptRoot\man3dfbx.ps1" -Import $Npc -Mdl "$nt\CAR3D.MDL" -Out "$st\JAMESW.ANI" | Select-String 'stride|->'
    if (Test-Path $NpcIdle) { & "$PSScriptRoot\man3dfbx.ps1" -Idle -Import (Resolve-Path $NpcIdle).Path -Mdl "$nt\CAR3D.MDL" -Out "$st\JAMESI.ANI" -OnlyClips $NpcClips | Select-String 'kept|->' }
    else { "no idle clips for him ($NpcIdle)" }
  }
  "staged: $st ($Model + $Texture$(if ($Npc) { ' + ' + [IO.Path]::GetFileName($Npc) }))"
}
if ($Push486) {
  $net = "$PSScriptRoot\net486.ps1"
  foreach ($x in 'MANWALK.EXE', 'CAR3D.MDL', 'CAR3D.BMP', 'CARROAD.BMP', 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'SHADBOP.OVL', 'C3DEDGE.OVL', 'C3DEDGO.OVL', 'C3DEDGK.OVL', 'C3DEDGI.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL', 'C3DSKIN.OVL', 'C3DMSE.OVL', 'C3DMCPY.OVL', 'MAN3D.ANI', 'MANIDLE.ANI', 'JAMES.MDL', 'JAMES.BMP', 'JAMESW.ANI', 'JAMESI.ANI', 'ROOM.CFG', 'ROOM.WLK', 'ROOM.OCC', 'ROOM.PAC') {
    & $net push -Source "$st\$x" -Dest /drive_c/manwalk -All | Select-Object -Last 1
  }
  if ($Check -or $Bench) {
    $job = if ($Bench) { 'C:;cd \manwalk;manwalk b' } else { "C:;cd \manwalk;manwalk s$Outline" }
    & $net run -Job $job -Wait -WaitMinutes 5 | Select-Object -Last 2
    foreach ($x in 'MANWALK.LOG', 'MANWLK1.BMP', 'MANWLK2.BMP') {
      $d = "$st\from486"; if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null }
      if (Test-Path "$d\$x" -PathType Container) { [IO.Directory]::Delete("$d\$x", $true) } elseif (Test-Path "$d\$x") { [IO.File]::Delete("$d\$x") }
      & $net pull "/drive_c/manwalk/$x" -To $d | Select-Object -Last 1
    }
    Get-Content "$st\from486\MANWALK.LOG" -ErrorAction SilentlyContinue
  } else {
    # (the game's mouse driver first: DARKV.BAT loads it the same way; a second load finds it there)
    & $net run -Job "C:;\darkv\mouse;cd \manwalk;manwalk $Outline" | Select-Object -Last 1
    "486: MANWALK running (Esc there quits it and prints the fps)"
  }
  return
}
$conf = Join-Path $env:TEMP 'manwalk_run.conf'
$auto = if ($HotCheck) { 'MANWALK H' } elseif ($PathCheck) { 'MANWALK P' } elseif ($GoCheck) { 'MANWALK W' } elseif ($IdleCheck) { 'MANWALK I' } elseif ($Bench) { 'MANWALK B' } elseif ($Check) { "MANWALK S$Outline" } else { "MANWALK $Outline" }
@"
[sdl]
autolock=false
output=opengl

[cpu]
cycles=max
cputype=486

[autoexec]
mount D $st
D:
$auto
exit
"@ | Set-Content $conf -Encoding ASCII
if ($Check -or $Bench -or $IdleCheck -or $GoCheck -or $PathCheck -or $HotCheck) {
  foreach ($x in 'MANWLK1.BMP', 'MANWLK2.BMP', 'MANWALK.LOG', 'MANIDL1.BMP', 'MANIDL2.BMP', 'MANIDL3.BMP', 'MANIDL4.BMP', 'MANIDLE.DMP', 'MANTRN1.BMP', 'MANTRN2.BMP', 'MANGO1.BMP', 'MANGO2.BMP', 'MANGO.LOG', 'MANPATH1.BMP', 'MANPATH2.BMP', 'MANPATH.LOG', 'MANHOT0.BMP', 'MANHOT1.BMP', 'MANHOT2.BMP', 'MANHOT.LOG') { if (Test-Path "$st\$x") { [IO.File]::Delete("$st\$x") } }
  $p = Start-Process -FilePath 'C:\dosbox-x\dosbox-x.exe' -ArgumentList @('-conf', "`"$conf`"", '-nogui', '-silent') -PassThru
  if (-not $p.WaitForExit(90000)) { $p.Kill(); "timed out" }
  Get-Content "$st\MANWALK.LOG" -ErrorAction SilentlyContinue
  if ($GoCheck) { Get-Content "$st\MANGO.LOG" -ErrorAction SilentlyContinue }
  if ($PathCheck) { Get-Content "$st\MANPATH.LOG" -ErrorAction SilentlyContinue }
  if ($HotCheck) { Get-Content "$st\MANHOT.LOG" -ErrorAction SilentlyContinue }
} else {
  Start-Process -FilePath 'C:\dosbox-x\dosbox-x.exe' -ArgumentList @('-conf', "`"$conf`"", '-nogui') | Out-Null
  "DOSBox-X opened on $st : arrows to walk and turn, Esc to quit"
}
