# man3danim.ps1 - a walk cycle for the 3D man, baked from his converted model (CAR3D.MDL from
# car3dcnv.ps1), written as MAN3D.ANI for MANWALK. No skeleton comes with the mesh: the
# artist's model is made of separate rigid pieces (head, torso, pelvis, two upper arms, two
# forearms with hands, two legs with a knee ring, two boots), so each piece is given to a
# bone by its place, the joints are put where the pieces meet, and only the knee ring is
# shared between two bones (thigh and shin). The 12 frames are posed with forward
# kinematics from a keyed walk (left heel strike at frame 0, the right leg half a cycle
# later, the arms swinging against the legs, the pelvis turning with the stride and the
# chest against it), each frame lowered so the lowest boot stands on the ground. The
# stance foot's travel gives the cycle length, so the runtime advances the frames by the
# distance walked and the planted foot stays put.
#   MAN3D.ANI: "C3A2", nv%, nframes%, cycle% (the distance of one cycle, x16 units), nframes x the
#              distance at which each frame starts (x16: the planted foot's travel, frame by frame), then
#              nframes x { nv x% , nv y% , nv z% } (x16 units, the MDL's vertex order)
# Usage: man3danim.ps1 -Mdl dist\manwalk\CAR3D.MDL [-Out <dir>\MAN3D.ANI] [-Preview png] [-Texture man_tex.png]
param(
  [Parameter(Mandatory = $true)][string]$Mdl,
  [string]$Out = "",
  [string]$Preview = "",
  [string]$Texture = "$PSScriptRoot\..\ART\Man3d\man_tex.png",
  [int]$Frames = 12
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('Man3D' -as [type])) { Add-Type -Path "$PSScriptRoot\Man3D.cs" -ReferencedAssemblies System.Drawing }
$Mdl = (Resolve-Path $Mdl).Path
if (-not $Out) { $Out = Join-Path ([IO.Path]::GetDirectoryName($Mdl)) 'MAN3D.ANI' }

if (-not ('WalkRig' -as [type])) { Add-Type -Path "$PSScriptRoot\WalkRig.cs" }
$r = [WalkRig]::Load($Mdl)
"model: $($r.NV) vertices, $($r.NP) polygons, $([Math]::Round($r.YMax - $r.YMin, 1)) units tall"
$r.Rig()
$r.Bake($Frames)
$r.Report.TrimEnd()
$r.Save($Out)
"-> $Out ($((Get-Item $Out).Length) bytes)"

if ($Preview) {
  # the frames through the engine-like preview renderer: side view (top row) and 3/4 view (bottom row)
  $m = New-Object Man3D ($r.UPC * 188 / 180), 0
  $img = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Texture).Path)
  $m.TW = $img.Width; $m.Tex = New-Object byte[] ($m.TW * $m.TW); $pal = [Man3D]::Pal
  for ($y = 0; $y -lt $m.TW; $y++) { for ($x = 0; $x -lt $m.TW; $x++) { $c = $img.GetPixel($x, $y); if ($c.A -lt 128) { $m.Tex[$y * $m.TW + $x] = 255; continue }; $best = 0; $bd = 1e9; for ($i = 0; $i -lt $pal.Count; $i++) { $d = [Math]::Abs($pal[$i].R - $c.R) + [Math]::Abs($pal[$i].G - $c.G) + [Math]::Abs($pal[$i].B - $c.B); if ($d -lt $bd) { $bd = $d; $best = $i } }; $m.Tex[$y * $m.TW + $x] = [byte]$best } }
  $img.Dispose()
  for ($i = 0; $i -lt $r.NV; $i++) { $m.V.Add([float[]]@($r.X[$i], $r.Y[$i], $r.Z[$i])); $m.UV.Add([float[]]@(($r.U[$i] * $m.TW), ($r.V[$i] * $m.TW))) }
  foreach ($p in $r.Polys) { $m.F.Add([int[]]@($p[0], $p[1], $p[2])); if ($p.Count -eq 4) { $m.F.Add([int[]]@($p[0], $p[2], $p[3])) } }
  # the converter's winding: if most faces point inward, flip them for the preview's cull
  $W = 70; $H = 120; $big = 3; $cols = $Frames + 1
  $sheet = New-Object System.Drawing.Bitmap ($cols * $W * $big), ([int](2 * $H * 1.2 * $big) + 40)
  $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30)); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
  $font = New-Object System.Drawing.Font 'Segoe UI', 9
  for ($f = -1; $f -lt $Frames; $f++) {
    for ($i = 0; $i -lt $r.NV; $i++) { if ($f -lt 0) { $m.V[$i] = [float[]]@($r.X[$i], $r.Y[$i], $r.Z[$i]) } else { $m.V[$i] = [float[]]@($r.FX[$f][$i], $r.FY[$f][$i], $r.FZ[$f][$i]) } }
    $col = $f + 1
    foreach ($row in 0, 1) {
      $yaw = if ($row -eq 0) { [Math]::PI / 2 } else { 0.6 }
      $bm = $m.Render($yaw, 150, $W, $H, 160, 1.2, 4, 0)
      $g.DrawImage($bm, $col * $W * $big, 20 + $row * ([int]($H * 1.2 * $big) + 10), $bm.Width * $big, $bm.Height * $big); $bm.Dispose()
    }
    $g.DrawString($(if ($f -lt 0) { 'rest' } else { "frame $f" }), $font, [System.Drawing.Brushes]::White, $col * $W * $big + 4, 2)
  }
  $g.Dispose(); $sheet.Save($Preview); $sheet.Dispose()
  "preview: $Preview"
}
