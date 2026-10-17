# manwalk.ps1 - the walk-around test scene for the 3D man: converts a model + texture with
# car3dcnv.ps1, stages everything MANWALK.EXE needs in dist\manwalk, and runs it.
#   manwalk.ps1                      stage the default (the artist's man_v2.3ds + man_tex.png) and open DOSBox-X on it
#   manwalk.ps1 -Model man3d.3ds     the procedural model instead (any .3ds in src\ART\Man3d)
#   manwalk.ps1 -Anim src\ART\Man3d\man_walk.fbx   the walk as edited in 3ds Max (exported as FBX, Bake Animation on)
#   manwalk.ps1 -Room 8              the man in a house room (1..11: they share one template) instead of on the road
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
  [string]$Anim = '',          # an animated FBX from 3ds Max (man3dfbx.ps1 made the first one): its mesh and its walk
  [int]$Room = 0,              # a house room (1..11, ROOMn.PIC) as the scene instead of the intro road
  [double]$BackScale = 0.65,   # in a room: his size at the back wall against the front (the art's perspective alone: 0.61)
  [double]$FrontHeight = 36,   # in a room: his height in pixels, outline included, at the front edge (the 2D sprite is 29, drawn for mid-room)
  [int]$Outline = 2,           # the outline he starts with: 0 off, 1 brown on his edge pixels, 2 blue 1 px round him, 3 blue 2 px (O cycles them)
  [string]$Texture = 'man_tex.png',
  [double]$Scale = 1.0,
  [switch]$Check,
  [switch]$Bench,
  [switch]$Push486,
  [switch]$NoStage
)
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path "$PSScriptRoot\..").Path
$art = "$src\ART\Man3d"
$st = (Resolve-Path "$src\..").Path + "\dist\manwalk"
if (-not (Test-Path $st)) { New-Item -ItemType Directory $st | Out-Null }
if (-not $NoStage) {
  if (-not (Test-Path "$src\tools\MANWALK.EXE")) { throw "src\tools\MANWALK.EXE missing: build it with tools\build1.ps1 MANWALK" }
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
    $bm.Save("$st\room_bg.png"); $bm.Dispose()
    $backdrop = "..\..\..\dist\manwalk\room_bg.png"
    # the camera, solved from the template the rooms share (measured in the pictures): the front floor edge
    # at y 177, the side walls' front top corners at y 130.8, the back wall's floor line at 135.3 and its
    # top at 107; the floor's corners 92.5 px either side of x 151.5 at the front, 55.75 at the back. The
    # verticals stay vertical, so a level camera with its picture centre shifted: the horizon where the
    # front and back wall heights agree; the scale from the back-wall doorway (room 2: 65% of the wall)
    # taken as 2.1 m, so the walls are 3.2 m = 142.3 units (the man: 188 cm = 83.6 units)
    $yff = 177.0; $yft = 130.8; $ybf = 135.3; $ybt = 107.0; $W = 142.3
    $h = ($yff * $ybt - $yft * $ybf) / ($yff + $ybt - $yft - $ybf)
    $Hc = $W * ($yff - $h) / ($yff - $yft)
    $zf = 256 * $Hc / ($yff - $h); $zb = 256 * $Hc / ($ybf - $h)
    # across, 307 px per unit at unit depth (256 x 1.2): the 320x200 pixels are 1.2 times taller than wide
    $fx = 256 * 1.2
    $xn = 92.5 * $zf / $fx; $xf = 55.75 * $zb / $fx
    $IC = [Globalization.CultureInfo]::InvariantCulture
    $cfg = (@(151.5, $h, $Hc, $zf, $zb, $xn, $xf, $fx) | ForEach-Object { ([double]$_).ToString('0.0', $IC) }) -join ','
    $cfg += ',' + $BackScale.ToString('0.00', $IC)
    $roomZ = @($zf, $zb)
    "room $Room camera: centre 151.5,$([Math]::Round($h, 1)) px, $([Math]::Round($Hc / 44.47, 2)) m above the floor, the floor $([Math]::Round($zf / 44.47, 1))..$([Math]::Round($zb / 44.47, 1)) m away, $([Math]::Round(2 * $xn / 44.47, 1))..$([Math]::Round(2 * $xf / 44.47, 1)) m wide; at the back he keeps $BackScale of his front size (perspective alone: $([Math]::Round($zf / $zb, 2)))"
  }
  & "$PSScriptRoot\car3dcnv.ps1" -Src $art -Model $Model -Texture $Texture -Unlit -Scale $Scale -Backdrop $backdrop -Out $st | Select-Object -Last 3
  if ($Room -gt 0) {
    # his overall scale: at the front edge the depth rule leaves him at true size, so the rest makes his
    # height there FrontHeight (less the 2 px of outline); mid-room and the back follow from BackScale
    $mb = [IO.File]::ReadAllBytes("$st\CAR3D.MDL"); $nv = [BitConverter]::ToInt16($mb, 4); $y0 = 1e9; $y1 = -1e9
    for ($i = 0; $i -lt $nv; $i++) { $y = [BitConverter]::ToSingle($mb, 14 + $i * 20); if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } }
    $trueFront = 256 * ($y1 - $y0) / $roomZ[0]
    $rsc = ($FrontHeight - 2) / $trueFront
    $cfg += ',' + $rsc.ToString('0.000', $IC)
    $mid = ($FrontHeight - 2) * (1 + ($BackScale - 1) / 2) + 2; $back = ($FrontHeight - 2) * $BackScale + 2
    "his height: $FrontHeight px at the front edge, $([Math]::Round($mid)) at mid-room, $([Math]::Round($back)) at the back wall (scale $([Math]::Round($rsc, 3)) over true size at the front)"
  }
  [IO.File]::WriteAllText("$st\ROOM.CFG", $cfg)   # empty = the road
  foreach ($x in 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'SHADBOP.OVL', 'C3DEDGE.OVL', 'C3DEDGO.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL') { Copy-Item "$src\$x" $st -Force }
  Copy-Item "$src\tools\MANWALK.EXE" $st -Force
  # the walk, baked from the model just converted (its vertex order)
  if ($Anim) { & "$PSScriptRoot\man3dfbx.ps1" -Import $Anim -Mdl "$st\CAR3D.MDL" -Out "$st\MAN3D.ANI" -Preview "$art\man_walk.png" | Select-String 'fbx:|skin|stride|->' }
  else { & "$PSScriptRoot\man3danim.ps1" -Mdl "$st\CAR3D.MDL" -Out "$st\MAN3D.ANI" -Preview "$art\man_walk.png" | Select-String 'stride|->' }
  "staged: $st ($Model + $Texture)"
}
if ($Push486) {
  $net = "$PSScriptRoot\net486.ps1"
  foreach ($x in 'MANWALK.EXE', 'CAR3D.MDL', 'CAR3D.BMP', 'CARROAD.BMP', 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'SHADBOP.OVL', 'C3DEDGE.OVL', 'C3DEDGO.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL', 'MAN3D.ANI', 'ROOM.CFG') {
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
    & $net run -Job "C:;cd \manwalk;manwalk $Outline" | Select-Object -Last 1
    "486: MANWALK running (Esc there quits it and prints the fps)"
  }
  return
}
$conf = Join-Path $env:TEMP 'manwalk_run.conf'
$auto = if ($Bench) { 'MANWALK B' } elseif ($Check) { "MANWALK S$Outline" } else { "MANWALK $Outline" }
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
if ($Check -or $Bench) {
  foreach ($x in 'MANWLK1.BMP', 'MANWLK2.BMP', 'MANWALK.LOG') { if (Test-Path "$st\$x") { [IO.File]::Delete("$st\$x") } }
  $p = Start-Process -FilePath 'C:\dosbox-x\dosbox-x.exe' -ArgumentList @('-conf', "`"$conf`"", '-nogui', '-silent') -PassThru
  if (-not $p.WaitForExit(90000)) { $p.Kill(); "timed out" }
  Get-Content "$st\MANWALK.LOG" -ErrorAction SilentlyContinue
} else {
  Start-Process -FilePath 'C:\dosbox-x\dosbox-x.exe' -ArgumentList @('-conf', "`"$conf`"", '-nogui') | Out-Null
  "DOSBox-X opened on $st : arrows to walk and turn, Esc to quit"
}
