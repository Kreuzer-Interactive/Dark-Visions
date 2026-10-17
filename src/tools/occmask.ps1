# occmask.ps1 - a house room's front mask: the furniture that hides the man when he is behind it, as a
# 320x200 picture over the room. Each colour is one piece (paint its whole silhouette, the inside of its
# line drawing too); black is nothing. A piece's depth is its lowest painted pixel -- where it stands on
# the floor -- so the man is behind it when his feet are higher on the screen than that. This makes a
# starter from screen polygons, and a view of it over the room.
#   occmask.ps1 -Room 8 -Pieces "114,129 153,129 153,140 148,143 110,143 108,134; ..."
#                        -> src\ART\Rooms\room8_front.png (+ room8_front_view.png)
# manwalk.ps1 -Room n turns src\ART\Rooms\roomN_front.png into the staged ROOM.OCC.
param(
  [int]$Room = 8,
  [string]$Pieces = '',      # polygons in screen pixels, "x,y x,y ...", separated by ';' ('|' joins polygons into one piece)
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path "$PSScriptRoot\..").Path
$dir = "$src\ART\Rooms"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
$out = "$dir\room${Room}_front.png"
if ((Test-Path $out) -and -not $Force) { throw "$out exists (it may be painted by hand): -Force to replace it" }
Add-Type -AssemblyName System.Drawing
$pal = @([System.Drawing.Color]::FromArgb(255, 0, 0), [System.Drawing.Color]::FromArgb(0, 255, 0), [System.Drawing.Color]::FromArgb(0, 128, 255), [System.Drawing.Color]::FromArgb(255, 255, 0), [System.Drawing.Color]::FromArgb(255, 0, 255), [System.Drawing.Color]::FromArgb(0, 255, 255), [System.Drawing.Color]::FromArgb(255, 128, 0), [System.Drawing.Color]::FromArgb(128, 0, 255))
$m = New-Object System.Drawing.Bitmap 320, 200
$g = [System.Drawing.Graphics]::FromImage($m); $g.Clear([System.Drawing.Color]::Black); $g.SmoothingMode = 'None'; $g.PixelOffsetMode = 'Half'
$k = 0
foreach ($pc in ($Pieces -split ';')) {
  if (-not $pc.Trim()) { continue }
  $br = New-Object System.Drawing.SolidBrush $pal[$k % $pal.Count]
  foreach ($poly in ($pc -split '\|')) {
    $pts = @(); foreach ($xy in ($poly.Trim() -split '\s+')) { $v = $xy -split ','; $pts += New-Object System.Drawing.Point ([int]$v[0]), ([int]$v[1]) }
    $g.FillPolygon($br, [System.Drawing.Point[]]$pts); $pn = New-Object System.Drawing.Pen $pal[$k % $pal.Count]; $g.DrawPolygon($pn, [System.Drawing.Point[]]$pts); $pn.Dispose()
  }
  $br.Dispose(); $k++
}
$g.Dispose(); $m.Save($out)
# the view: the room, each piece tinted, its floor line (the depth) marked
$pb = [IO.File]::ReadAllBytes("$src\ROOM$Room.PIC"); $cols = @([System.Drawing.Color]::FromArgb(0,0,0), [System.Drawing.Color]::FromArgb(85,85,85), [System.Drawing.Color]::FromArgb(0,0,170), [System.Drawing.Color]::FromArgb(170,85,0))
$vw = New-Object System.Drawing.Bitmap 320, 200
for ($y = 0; $y -lt 200; $y++) { $row = 7 + ($y % 2) * 8192 + [Math]::Floor($y / 2) * 80; for ($x = 0; $x -lt 320; $x++) { $ci = ($pb[$row + [Math]::Floor($x / 4)] -shr (6 - 2 * ($x % 4))) -band 3; $c = $cols[$ci]; $q = $m.GetPixel($x, $y); if ($q.R + $q.G + $q.B -gt 0) { $c = [System.Drawing.Color]::FromArgb([int](($c.R + $q.R) / 2), [int](($c.G + $q.G) / 2), [int](($c.B + $q.B) / 2)) }; $vw.SetPixel($x, $y, $c) } }
$big = New-Object System.Drawing.Bitmap 960, 600; $g = [System.Drawing.Graphics]::FromImage($big); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'; $g.DrawImage($vw, 0, 0, 960, 600); $g.Dispose()
$big.Save("$dir\room${Room}_front_view.png"); $big.Dispose(); $vw.Dispose(); $m.Dispose()
"room $Room front mask: $k pieces -> $out (view: room${Room}_front_view.png)"
