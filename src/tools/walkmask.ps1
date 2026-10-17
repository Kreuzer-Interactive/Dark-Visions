# walkmask.ps1 - a house room's walk mask: where on the floor the man's feet may stand, as a 320x200
# picture over the room (white = walkable). The artist paints it in any editor; this makes a starter
# from the room template's floor less a margin at the walls and the furniture's footprints (floor
# rectangles in units, grown by his half width), and a view of it over the room.
#   walkmask.ps1 -Room 8 -Obstacles "-156,1153,2,1300; 54,1219,196,1300; 189,780,250,833"
#                        -> src\ART\Rooms\room8_walk.png (+ room8_walk_view.png)
#   (x across, z away from the camera, as MANWALK's room camera has them: the floor runs from z 788
#   at the front edge to 1287 at the back wall, 235 either side at the front, 225 at the back)
# manwalk.ps1 -Room n turns src\ART\Rooms\roomN_walk.png into the staged ROOM.WLK (1 bit a pixel).
param(
  [int]$Room = 8,
  [string]$Obstacles = '',
  [double]$Radius = 12,      # his half width (units; he is drawn about 1.2x true size in the rooms)
  [double]$Margin = 16,      # kept from the walls
  [switch]$Force             # overwrite an existing mask (it may be the artist's)
)
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path "$PSScriptRoot\..").Path
$dir = "$src\ART\Rooms"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
$out = "$dir\room${Room}_walk.png"
if ((Test-Path $out) -and -not $Force) { throw "$out exists (it may be painted by hand): -Force to replace it" }
# the camera, as manwalk.ps1 solves it from the template
$yff = 177.0; $yft = 130.8; $ybf = 135.3; $ybt = 107.0; $W = 142.3
$h = ($yff * $ybt - $yft * $ybf) / ($yff + $ybt - $yft - $ybf)
$Hc = $W * ($yff - $h) / ($yff - $yft)
$zf = 256 * $Hc / ($yff - $h); $zb = 256 * $Hc / ($ybf - $h)
$fx = 256 * 1.2
$xn = 92.5 * $zf / $fx; $xf = 55.75 * $zb / $fx
$obs = @()
foreach ($o in ($Obstacles -split ';')) { if ($o.Trim()) { $v = [double[]]($o.Trim() -split '\s*,\s*'); $obs += ,@(($v[0] - $Radius), ($v[1] - $Radius), ($v[2] + $Radius), ($v[3] + $Radius)) } }
Add-Type -AssemblyName System.Drawing
$m = New-Object System.Drawing.Bitmap 320, 200
$n = 0
for ($y = 0; $y -lt 200; $y++) {
  for ($x = 0; $x -lt 320; $x++) {
    $ok = $false
    if ($y -gt $h + 1) {
      $z = 256 * $Hc / ($y - $h); $wx = ($x - 151.5) * $z / $fx
      $half = $xn + ($z - $zf) * ($xf - $xn) / ($zb - $zf)
      $ok = ($z -ge $zf + $Margin) -and ($z -le $zb - $Margin) -and ([Math]::Abs($wx) -le $half - $Margin)
      if ($ok) { foreach ($o in $obs) { if ($wx -ge $o[0] -and $wx -le $o[2] -and $z -ge $o[1] -and $z -le $o[3]) { $ok = $false; break } } }
    }
    if ($ok) { $m.SetPixel($x, $y, [System.Drawing.Color]::White); $n++ } else { $m.SetPixel($x, $y, [System.Drawing.Color]::Black) }
  }
}
$m.Save($out)
# the view: the room with the walkable floor tinted
$pb = [IO.File]::ReadAllBytes("$src\ROOM$Room.PIC"); $cols = @([System.Drawing.Color]::FromArgb(0,0,0), [System.Drawing.Color]::FromArgb(85,85,85), [System.Drawing.Color]::FromArgb(0,0,170), [System.Drawing.Color]::FromArgb(170,85,0))
$vw = New-Object System.Drawing.Bitmap 320, 200
for ($y = 0; $y -lt 200; $y++) { $row = 7 + ($y % 2) * 8192 + [Math]::Floor($y / 2) * 80; for ($x = 0; $x -lt 320; $x++) { $ci = ($pb[$row + [Math]::Floor($x / 4)] -shr (6 - 2 * ($x % 4))) -band 3; $c = $cols[$ci]; if ($m.GetPixel($x, $y).R -gt 128 -and $ci -eq 0) { $c = [System.Drawing.Color]::FromArgb(0, 70, 0) }; $vw.SetPixel($x, $y, $c) } }
$big = New-Object System.Drawing.Bitmap 960, 600; $g = [System.Drawing.Graphics]::FromImage($big); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'; $g.DrawImage($vw, 0, 0, 960, 600); $g.Dispose()
$big.Save("$dir\room${Room}_walk_view.png"); $big.Dispose(); $vw.Dispose(); $m.Dispose()
"room $Room walk mask: $n walkable pixels, $($obs.Count) obstacles -> $out (view: room${Room}_walk_view.png)"
