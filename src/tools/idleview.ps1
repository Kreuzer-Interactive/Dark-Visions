# idleview.ps1 - a sheet of the idle clips as WalkRig.cs IdleAnim keys them (before any edit in Max), front
# three-quarters and side, Samples frames a clip -> src\ART\Man3d\man_idle.png. The staged model gives the vertex order.
param([string]$Mdl = "$PSScriptRoot\..\..\dist\manwalk\CAR3D.MDL", [string]$Out = "$PSScriptRoot\..\ART\Man3d\man_idle.png", [int]$Samples = 9, [double]$Yaw = 0.5, [double]$Yaw2 = 1.2)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
Add-Type -Path "$tools\WalkRig.cs"
Add-Type -AssemblyName System.Drawing
Add-Type -Path "$tools\Man3D.cs" -ReferencedAssemblies System.Drawing
$r = [WalkRig]::Load($Mdl); $r.Rig(); $ia = New-Object IdleAnim $r
$m = New-Object Man3D ($r.UPC * 188 / 180), 0
$img = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\..\ART\Man3d\man_tex.png")
$m.TW = $img.Width; $m.Tex = New-Object byte[] ($m.TW * $m.TW); $pal = [Man3D]::Pal
for ($y = 0; $y -lt $m.TW; $y++) { for ($x = 0; $x -lt $m.TW; $x++) { $c = $img.GetPixel($x, $y); if ($c.A -lt 128) { $m.Tex[$y * $m.TW + $x] = 255; continue }; $best = 0; $bd = 1e9; for ($k = 0; $k -lt $pal.Count; $k++) { $d = [Math]::Abs($pal[$k].R - $c.R) + [Math]::Abs($pal[$k].G - $c.G) + [Math]::Abs($pal[$k].B - $c.B); if ($d -lt $bd) { $bd = $d; $best = $k } }; $m.Tex[$y * $m.TW + $x] = [byte]$best } }
$img.Dispose()
for ($i = 0; $i -lt $r.NV; $i++) { $m.V.Add([float[]]@($r.X[$i], $r.Y[$i], $r.Z[$i])); $m.UV.Add([float[]]@(($r.U[$i] * $m.TW), ($r.V[$i] * $m.TW))) }
foreach ($p in $r.Polys) { $m.F.Add([int[]]@($p[0], $p[1], $p[2])); if ($p.Count -eq 4) { $m.F.Add([int[]]@($p[0], $p[2], $p[3])) } }
$W0 = 70; $H0 = 120; $big = 2; $nc = $ia.Clips.Count
$rowH = [int]($H0 * 1.2 * $big)
$sheet = New-Object System.Drawing.Bitmap ($Samples * 2 * $W0 * $big), ($nc * ($rowH + 18))
$g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30)); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = New-Object System.Drawing.Font 'Segoe UI', 8
for ($c = 0; $c -lt $nc; $c++) {
  $cl = $ia.Clips[$c]
  for ($s = 0; $s -lt $Samples; $s++) {
    $fr = [int][Math]::Round($cl.Len * $s / ($Samples - 1))
    $W = $ia.World($ia.At($c, $fr))
    for ($i = 0; $i -lt $r.NV; $i++) { $q = $ia.Skin($W, $i); $m.V[$i] = [float[]]@($q[0], $q[1], $q[2]) }
    foreach ($v in 0, 1) {
      $bm = $m.Render($(if ($v -eq 0) { $Yaw } else { $Yaw2 }), 150, $W0, $H0, 160, 1.2, 4, 0)
      $x0 = ($s * 2 + $v) * $W0 * $big; $y0 = $c * ($rowH + 18) + 16
      $g.DrawImage($bm, $x0, $y0, $bm.Width * $big, $bm.Height * $big); $bm.Dispose()
    }
    $g.DrawString("$($cl.Name) $fr", $font, [System.Drawing.Brushes]::White, ($s * 2 * $W0 * $big + 2), ($c * ($rowH + 18) + 1))
  }
}
$g.Dispose(); $sheet.Save($Out); $sheet.Dispose(); "preview: $Out"
