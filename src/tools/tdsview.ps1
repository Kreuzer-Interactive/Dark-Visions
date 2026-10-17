# tdsview.ps1 - previews a 3DS model + its texture the way the C3DTRI engine draws it (nearest
# texel, no lighting, silhouette ink), as man3d.ps1 does for its own model: front / 3-4 / side /
# back, in-game size and two head close-ups -> <Out> (default <model>_views.png).
# The 3DS is read like car3dcnv.ps1 reads it: Z-up file -> (x, z, -y), v flipped.
# The texture's colours are matched to the atlas palette (Man3D.Pal); transparent = key.
# Usage: tdsview.ps1 -Model src\ART\Man3d\man_v2.3ds -Texture src\ART\Man3d\man_tex.png [-Out ...] [-Compare]
param(
  [Parameter(Mandatory = $true)][string]$Model,
  [Parameter(Mandatory = $true)][string]$Texture,
  [string]$Out = "",
  [switch]$Compare   # also man_compare.png next to it, through the scratchpad compare.ps1 (the references over the views)
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path "$PSScriptRoot\Man3D.cs" -ReferencedAssemblies System.Drawing
if (-not $Out) { $Out = [IO.Path]::Combine([IO.Path]::GetDirectoryName((Resolve-Path $Model).Path), [IO.Path]::GetFileNameWithoutExtension($Model) + "_views.png") }

$m = New-Object Man3D 1.0, 0
# ---- texture
$img = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Texture).Path)
if ($img.Width -ne $img.Height -or ($img.Width -ne 64 -and $img.Width -ne 128)) { throw "texture must be 64 or 128 square" }
$m.TW = $img.Width; $m.Tex = New-Object byte[] ($m.TW * $m.TW)
$pal = [Man3D]::Pal
for ($y = 0; $y -lt $m.TW; $y++) { for ($x = 0; $x -lt $m.TW; $x++) {
  $c = $img.GetPixel($x, $y)
  if ($c.A -lt 128) { $m.Tex[$y * $m.TW + $x] = 255; continue }
  $best = 0; $bd = 1e9
  for ($i = 0; $i -lt $pal.Count; $i++) { $d = [Math]::Abs($pal[$i].R - $c.R) + [Math]::Abs($pal[$i].G - $c.G) + [Math]::Abs($pal[$i].B - $c.B); if ($d -lt $bd) { $bd = $d; $best = $i } }
  $m.Tex[$y * $m.TW + $x] = [byte]$best } }
$img.Dispose()
# ---- 3DS
$b = [IO.File]::ReadAllBytes((Resolve-Path $Model).Path)
function U16($o) { [BitConverter]::ToUInt16($b, $o) }
function U32($o) { [BitConverter]::ToUInt32($b, $o) }
function F32($o) { [BitConverter]::ToSingle($b, $o) }
$o = 0; $base = 0
while ($o -lt $b.Length) {
  $id = U16 $o; $len = U32 ($o + 2)
  if ($id -in 0x4D4D, 0x3D3D, 0x4100) { $o += 6; continue }
  if ($id -eq 0x4000) { $p = $o + 6; while ($b[$p] -ne 0) { $p++ }; $o = $p + 1; $base = $m.V.Count; continue }
  if ($id -eq 0x4110) { $n = U16 ($o + 6); for ($i = 0; $i -lt $n; $i++) { $m.V.Add([float[]]@((F32 ($o + 8 + $i * 12)), (F32 ($o + 16 + $i * 12)), (-(F32 ($o + 12 + $i * 12))))); $m.UV.Add([float[]]@(0, 0)) } }
  elseif ($id -eq 0x4140) { $n = U16 ($o + 6); for ($i = 0; $i -lt $n -and ($base + $i) -lt $m.V.Count; $i++) { $uu = F32 ($o + 8 + $i * 8); $vv = F32 ($o + 12 + $i * 8); $m.UV[$base + $i] = [float[]]@(($uu * $m.TW), ((1 - $vv) * $m.TW)) } }
  elseif ($id -eq 0x4120) { $n = U16 ($o + 6); for ($i = 0; $i -lt $n; $i++) { $m.F.Add([int[]]@(($base + (U16 ($o + 8 + $i * 8))), ($base + (U16 ($o + 10 + $i * 8))), ($base + (U16 ($o + 12 + $i * 8))))) } }
  $o += $len
}
$hy = $m.V | ForEach-Object { $_[1] }; $m.S = (($hy | Measure -Max).Maximum - ($hy | Measure -Min).Minimum) / 180.0
"model: $($m.V.Count) vertices, $($m.F.Count) triangles, $([int](($hy | Measure -Max).Maximum - ($hy | Measure -Min).Minimum)) units tall"
# the renderer culls by winding: if most faces point inward (as the converter decides), flip them all
$inward = 0
for ($i = 0; $i -lt $m.F.Count; $i++) { $f = $m.F[$i]; $a = $m.V[$f[0]]; $bb = $m.V[$f[1]]; $c = $m.V[$f[2]]
  $ux = $bb[0] - $a[0]; $uy = $bb[1] - $a[1]; $uz = $bb[2] - $a[2]; $wx = $c[0] - $a[0]; $wy = $c[1] - $a[1]; $wz = $c[2] - $a[2]
  $nx = $uy * $wz - $uz * $wy; $ny = $uz * $wx - $ux * $wz; $nz = $ux * $wy - $uy * $wx
  $mx = ($a[0] + $bb[0] + $c[0]) / 3; $my = ($a[1] + $bb[1] + $c[1]) / 3; $mz = ($a[2] + $bb[2] + $c[2]) / 3
  if ($nx * $mx + $ny * $my + $nz * $mz -lt 0) { $inward++ } }
$cx = 0; $cy = 0; $cz = 0; $ys = $m.V | ForEach-Object { $_[1] }; $cy = (($ys | Measure -Min).Minimum + ($ys | Measure -Max).Maximum) / 2
# (the inward test above uses the raw origin; the model is centred on y for a fairer test)
$inward = 0
for ($i = 0; $i -lt $m.F.Count; $i++) { $f = $m.F[$i]; $a = $m.V[$f[0]]; $bb = $m.V[$f[1]]; $c = $m.V[$f[2]]
  $ux = $bb[0] - $a[0]; $uy = $bb[1] - $a[1]; $uz = $bb[2] - $a[2]; $wx = $c[0] - $a[0]; $wy = $c[1] - $a[1]; $wz = $c[2] - $a[2]
  $nx = $uy * $wz - $uz * $wy; $ny = $uz * $wx - $ux * $wz; $nz = $ux * $wy - $uy * $wx
  $mx = ($a[0] + $bb[0] + $c[0]) / 3; $my = ($a[1] + $bb[1] + $c[1]) / 3 - $cy; $mz = ($a[2] + $bb[2] + $c[2]) / 3
  if ($nx * $mx + $ny * $my + $nz * $mz -lt 0) { $inward++ } }
if ($inward -gt $m.F.Count / 2) { "winding flipped ($inward of $($m.F.Count) inward)"; for ($i = 0; $i -lt $m.F.Count; $i++) { $f = $m.F[$i]; $m.F[$i] = [int[]]@($f[0], $f[2], $f[1]) } }

# ---- the sheet (as man3d.ps1 draws it)
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
$g.Dispose(); $sheet.Save($Out); $sheet.Dispose()
"views: $Out"
if ($Compare) {
  $cmp = "C:\Users\jhess\AppData\Local\Temp\claude\C--Code-Dark-Visions\7b6a16f3-6861-4718-be85-d132c7a84af4\scratchpad\compare.ps1"
  $co = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Out), [IO.Path]::GetFileNameWithoutExtension($Model) + "_compare.png")
  & $cmp -Views $Out -Out $co
}
