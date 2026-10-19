# man3dgame.ps1 - the 3D man's files for the GAME (GAME8.BAS: MAN3D=1 in dark.ini), next to GAME.EXE in src\:
#   MAN3D.MDL   the model (car3dcnv's C3D2 format), from the walk's own mesh (man_walk.fbx, so the walk's
#               bones line up)
#   MAN3D.BMP   its texture at 64 x 64 (in the rooms he is 24..36 px tall: 128 would be four texels a pixel),
#               unlit, 8-bit; GAME8 maps its colours to each room's four
#   MAN3DW.ANI  the walk as bone matrices ("C3I1", one clip of kind 4: played by the distance walked, each
#               frame's "time" = how far the planted foot carries him while it shows, x16 units)
#   MAN3DI.ANI  the idle and turning clips, packed small (tools\man3didle.ps1, from dist\manwalk\MANIDLE.ANI)
# Usage: man3dgame.ps1 [-Walk src\ART\Man3d\man_walk.fbx] [-Texture src\ART\Man3d\man_tex.png]
param(
  [string]$Walk = "$PSScriptRoot\..\ART\Man3d\man_walk.fbx",
  [string]$Texture = "$PSScriptRoot\..\ART\Man3d\man_tex.png",
  [string]$Name = 'MAN3D',   # another character on the same mesh (james3d.ps1: JAMES3D) ...
  [switch]$NoAnim            # ... with -NoAnim writes only src\<Name>.MDL/.BMP: the clips are shared
)
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path "$PSScriptRoot\..").Path
$Walk = (Resolve-Path $Walk).Path; $Texture = (Resolve-Path $Texture).Path
$tmp = Join-Path $env:TEMP 'man3dgame'; if (-not (Test-Path $tmp)) { New-Item -ItemType Directory $tmp | Out-Null }
# ---- the mesh, from the walk's FBX
& "$PSScriptRoot\fbx2tds.ps1" -In $Walk -Out "$tmp\man.3ds" | Select-Object -Last 1
# ---- the texture padded round its UV islands at 128 first (car3dcnv -PadOut: the texels no face uses, next to an
# island, take its edge colour), so the downscale's blocks on an island's border keep the island's colour
Add-Type -AssemblyName System.Drawing
Copy-Item $Texture "$tmp\man_tex128.png" -Force
& "$PSScriptRoot\car3dcnv.ps1" -Src $tmp -Model man.3ds -Texture man_tex128.png -Unlit -PadOut "$tmp\man_tex128p.png" -Out "$tmp\pad128" | Select-String 'padding'
# ---- the texture at 64: each 2 x 2 block's most common opaque colour (transparent only when all four are)
$t128 = [System.Drawing.Bitmap]::FromFile("$tmp\man_tex128p.png")
if ($t128.Width -ne 128 -or $t128.Height -ne 128) { throw "the texture must be 128 x 128" }
$t64 = New-Object System.Drawing.Bitmap 64, 64, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt 64; $y++) { for ($x = 0; $x -lt 64; $x++) {
  $cnt = @{}; $best = $null; $bn = 0
  foreach ($d in @(@(0, 0), @(1, 0), @(0, 1), @(1, 1))) { $c = $t128.GetPixel(2 * $x + $d[0], 2 * $y + $d[1]); if ($c.A -ge 128) { $k = $c.ToArgb(); $cnt[$k] = 1 + [int]$cnt[$k]; if ($cnt[$k] -gt $bn) { $bn = $cnt[$k]; $best = $c } } }
  if ($best) { $t64.SetPixel($x, $y, $best) } else { $t64.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255)) }
} }
$t128.Dispose(); $t64.Save("$tmp\man_tex64.png"); $t64.Dispose()
# ---- the model + texture through the car converter (into the temp folder: its default Out is src\, the intro car's files)
& "$PSScriptRoot\car3dcnv.ps1" -Src $tmp -Model man.3ds -Texture man_tex64.png -Unlit -Out $tmp | Select-Object -Last 1
Copy-Item "$tmp\CAR3D.MDL" "$src\$Name.MDL" -Force; Copy-Item "$tmp\CAR3D.BMP" "$src\$Name.BMP" -Force
if ($NoAnim) { "-> $src\$Name.MDL ($((Get-Item "$src\$Name.MDL").Length) B), $Name.BMP ($((Get-Item "$src\$Name.BMP").Length) B)"; return }
# ---- the walk as bone matrices, per frame, grounded, with the planted foot's stride per frame
if (-not ('WalkRig' -as [type])) { Add-Type -Path "$PSScriptRoot\WalkRig.cs" }
if (-not ('FbxScene' -as [type])) { Add-Type -Path "$PSScriptRoot\FbxWalkIO.cs" -ReferencedAssemblies System.IO.Compression }
$scene = [FbxScene]::Load($Walk); $scene.FindMesh(); $scene.Split(); $scene.FindAnim(); $scene.FindSkin()
$rig = [WalkRig]::Load("$src\MAN3D.MDL"); $rig.Rig(); $ia = New-Object IdleAnim $rig
if ($scene.SplitCP.Count -ne $rig.NV) { throw "the FBX splits into $($scene.SplitCP.Count) vertices, the model has $($rig.NV)" }
$p0 = $scene.SplitPos[0]; $off = [double[]]@(($p0[0] - $rig.X[0]), ($p0[2] - $rig.Y[0]), ((-$p0[1]) - $rig.Z[0]))
$names = [WalkRig]::BoneName; $cl = @{}; foreach ($c in $scene.Clusters) { $cl[[array]::IndexOf($names, $c.Name)] = $c }
for ($b = 0; $b -lt 13; $b++) { if (-not $cl.ContainsKey($b)) { throw "the skin has no bone $($names[$b])" } }
# the FBX's own weights: each vertex's two strongest bones (half and half when two)
$wl = @{}; foreach ($b in $cl.Keys) { $c = $cl[$b]; for ($k = 0; $k -lt $c.Idx.Length; $k++) { if ($c.W[$k] -le 0) { continue }; $cp = [int]$c.Idx[$k]; if (-not $wl.ContainsKey($cp)) { $wl[$cp] = @() }; $wl[$cp] += ,@($b, $c.W[$k]) } }
$ia.FB1 = New-Object int[] $rig.NV; $ia.FB2 = New-Object int[] $rig.NV; $bw = New-Object int[] $rig.NV
for ($i = 0; $i -lt $rig.NV; $i++) {
  $l = @($wl[$scene.SplitCP[$i]] | Sort-Object { -$_[1] }); $b1 = $l[0][0]; $b2 = $b1
  if ($l.Count -gt 1 -and $l[1][1] -ge 0.25 * ($l[0][1] + $l[1][1])) { $b2 = $l[1][0] }
  $ia.FB1[$i] = $b1; $ia.FB2[$i] = $b2; $bw[$i] = $b1 + 256 * $b2
}
$span = $scene.Stop - $scene.Start; $nf = [Math]::Max(1, [int][Math]::Round($span / $scene.FrameTicks))
$frs = New-Object 'System.Collections.Generic.List[double[][]]'
$rig.NF = $nf; $rig.FX = New-Object 'float[][]' $nf; $rig.FY = New-Object 'float[][]' $nf; $rig.FZ = New-Object 'float[][]' $nf
$worstQ = 0.0
for ($f = 0; $f -lt $nf; $f++) {
  $t = [long]($scene.Start + $span * $f / $nf)
  $W = New-Object 'double[][]' 13; for ($b = 0; $b -lt 13; $b++) { $W[$b] = [IdleAnim]::FromMesh($scene.ClusterMatrix($cl[$b], $t), $off) }
  $W = $ia.Ground($W); $frs.Add($W)
  $e = $ia.QuantErr($W); if ($e -gt $worstQ) { $worstQ = $e }
  $fx = New-Object float[] $rig.NV; $fy = New-Object float[] $rig.NV; $fz = New-Object float[] $rig.NV
  for ($i = 0; $i -lt $rig.NV; $i++) { $q = $ia.SkinF($W, $i); $fx[$i] = $q[0]; $fy[$i] = $q[1]; $fz[$i] = $q[2] }
  $rig.FX[$f] = $fx; $rig.FY[$f] = $fy; $rig.FZ[$f] = $fz
}
$rig.ComputeStride()
$durs = New-Object 'System.Collections.Generic.List[int]'
for ($f = 0; $f -lt $nf; $f++) { $nx = if ($f -lt $nf - 1) { $rig.Cum16[$f + 1] } else { $rig.Cycle16 }; $durs.Add($nx - $rig.Cum16[$f]) }
$cn = New-Object 'System.Collections.Generic.List[string]'; $cn.Add('walk')
$ck = New-Object 'System.Collections.Generic.List[int]'; $ck.Add(4)
$cd = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[int]]'; $cd.Add($durs)
$cf = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[double[][]]]'; $cf.Add($frs)
[IdleAnim]::SaveAni("$src\MAN3DW.ANI", $rig.NV, $bw, $cn, $ck, $cd, $cf)
"walk: $nf frames, a cycle of $([Math]::Round($rig.Cycle16 / 16.0, 1)) units, per frame (x16) $($durs -join ' '); the file's integers off by $([Math]::Round($worstQ, 3)) units at most"
"-> $src\MAN3D.MDL ($((Get-Item "$src\MAN3D.MDL").Length) B), MAN3D.BMP ($((Get-Item "$src\MAN3D.BMP").Length) B), MAN3DW.ANI ($((Get-Item "$src\MAN3DW.ANI").Length) B)"
& "$PSScriptRoot\man3didle.ps1" | Select-Object -Last 1
