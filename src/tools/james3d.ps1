# james3d.ps1 - James, the house attendant, on the man's own mesh: the same 11 pieces and UVs as man_walk.fbx
# (so the walk, idle and turn clips play on him unchanged), with a texture painted in 3D by tools\James3D.cs --
# every texel gets the rest-pose body point it lands on and the rules below colour it:
#   long coat to below the knee, CGA blue (his sprite's colour; GAME8's room LUT keeps it blue), black seams,
#   collar + shirt front light gray with a black tie and dark waistcoat in the V, pocket square, half belt
#   at the back; blue trousers with a black crease; black shoes; slicked dark-gray hair; black mustache;
#   the man's face (eyes, nose, mouth lines) kept from man_tex.png.
# Out: src\ART\Man3d\james_tex.png (128 x 128) + james_views.png (tdsview), and with -Game the game's
#   src\JAMES3D.MDL / JAMES3D.BMP (man3dgame.ps1 -Name JAMES3D -NoAnim: he shares MAN3DW.ANI / MAN3DI.ANI).
#   With -Max: James3d.max/.fbx (mesh + UVs), james_walk and james_idle .max/.fbx (the clips) for editing.
# Usage: james3d.ps1 [-Game] [-Max]
param(
  [string]$Walk = "$PSScriptRoot\..\ART\Man3d\man_walk.fbx",
  [string]$Base = "$PSScriptRoot\..\ART\Man3d\man_tex.png",
  [string]$Out = "$PSScriptRoot\..\ART\Man3d\james_tex.png",
  [switch]$Game,
  [switch]$Max    # also James3d / james_walk / james_idle .max + .fbx (3ds Max, from the man's scenes)
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('JamesTex' -as [type])) { Add-Type -Path "$PSScriptRoot\James3D.cs" -ReferencedAssemblies System.Drawing }
$Walk = (Resolve-Path $Walk).Path; $Base = (Resolve-Path $Base).Path
$Out = [IO.Path]::GetFullPath($Out)
$tmp = Join-Path $env:TEMP 'james3d'; if (-not (Test-Path $tmp)) { New-Item -ItemType Directory $tmp | Out-Null }
& "$PSScriptRoot\fbx2tds.ps1" -In $Walk -Out "$tmp\man.3ds" | Select-Object -Last 1
$j = New-Object JamesTex; $j.Load3ds("$tmp\man.3ds"); $j.MapTexels()
if ($j.NPiece -ne 11) { throw "expected the man's 11 pieces, found $($j.NPiece)" }

# ---- colours (the car's CGA set + CGA blue)
$K = [Drawing.Color]::FromArgb(7, 7, 7); $O = [Drawing.Color]::FromArgb(170, 85, 0)
$G = [Drawing.Color]::FromArgb(85, 85, 85); $L = [Drawing.Color]::FromArgb(170, 170, 170)
$B = [Drawing.Color]::FromArgb(0, 0, 170)
# ---- pieces by their boxes (rest pose, Y up, front = -Z, units: 83.6 = 188 cm)
function PieceKind($p) {
  $b = $j.PBox[$p]; $cy = ($b[2] + $b[3]) / 2; $cx = ($b[0] + $b[1]) / 2
  if ($b[2] -gt 68) { return 'head' }
  if ($b[3] -lt 10) { return 'shoe' }
  if ([Math]::Abs($cx) -gt 6.5) { if ($cy -gt 54) { return 'uarm' } else { return 'farm' } }
  if ($b[3] -gt 69) { return 'torso' }
  if ($b[2] -gt 30) { return 'pelvis' }
  return 'leg'
}
$kind = @{}; for ($p = 0; $p -lt 11; $p++) { $kind[$p] = PieceKind $p }
$baseBmp = [Drawing.Bitmap]::FromFile($Base)

# the coat's front opening: half width of the V at height y (0 below the top button)
function VHalf($y) { if ($y -lt 57.5) { return 0 }; return [Math]::Min(5.2, ($y - 57.5) * 0.6) }

function Paint($kd, $x, $y, $z, $n, $tx, $ty) {
  $front = $n[2] -lt -0.35; $back = $n[2] -gt 0.35; $ax = [Math]::Abs($x)
  switch ($kd) {
    'head' {
      $c = $baseBmp.GetPixel($tx, $ty)
      # the mustache: thick under the nose, the ends curling down
      if ($front -or $z -lt -3.0) {
        if ($y -gt 73.7 -and $y -lt 74.5 -and $ax -lt 2.0) { return $K }
        if ($y -gt 73.1 -and $y -lt 73.9 -and $ax -ge 1.7 -and $ax -lt 2.5) { return $K }
      }
      if ($y -lt 70.6) { if ($front -and $ax -lt 1.6) { return $O }; return $L }   # neck: skin at the throat, collar round it
      # hair: whatever the man had as hair (gray) -> dark gray with black strands swept back
      if ($c.R -lt 120 -and $c.G -lt 120 -and [Math]::Abs($c.R - $c.G) -lt 20 -and $c.A -ge 128) {
        if ($y -lt 71) { return $c }
        if (([int][Math]::Floor($y * 1.3 + $z * 0.3)) % 4 -eq 0 -and $ax -gt 2.6 -and -not $front) { return $K }
        return $G }
      if ($c.B -gt 150 -and $c.R -lt 60) { return $K }   # the man's cyan eyes -> dark
      return $c
    }
    'torso' {
      $vh = VHalf $y
      if ($y -gt 68.9) { return $L }                                       # the collar band
      if ($front -and $vh -gt 0 -and $ax -lt $vh) {
        if ($ax -lt 0.55 -and $y -lt 68.4) { return $K }                     # tie
        if ($ax -lt 1.5 -and $y -gt 63.0) { return $L }                     # shirt front
        if ($ax -gt $vh - 0.55) { return $K }                               # lapel edge
        return $G                                                          # waistcoat
      }
      if ($front -and $ax -lt 0.4 -and $y -lt 57.6) { return $K }           # the buttoned front edge
      if ($front -and $ax -lt 1.2 -and [Math]::Abs($y - 55.6) -lt 0.45) { return $O }   # button
      if ($front -and $x -gt 3.2 -and $x -lt 5.6 -and [Math]::Abs($y - 63.6) -lt 0.5) { return $L }  # pocket square
      if ($back -and $ax -lt 0.35) { return $K }                            # back seam
      if ($back -and [Math]::Abs($y - 50.6) -lt 0.6) { return $K }           # half belt
      return $B
    }
    'pelvis' {
      if ($front -and $ax -lt 0.45) { return $K }
      if ($back -and $ax -lt 0.45) { return $K }                            # the vent
      if ($back -and [Math]::Abs($y - 50.6) -lt 0.6) { return $K }
      return $B
    }
    'uarm' { if ($y -gt 67.8 -and -not $front -and -not $back) { return $B }; return $B }
    'farm' {
      if ($y -lt 40.9) { return $O }                                       # hand
      if ($y -lt 41.8) { return $L }                                       # shirt cuff
      if ($y -lt 43.6 -and $y -gt 43.0) { return $K }                       # coat cuff line
      return $B
    }
    'leg' {
      $cx = if ($x -lt 0) { -4.4 } else { 4.4 }
      if ($y -gt 24.2) {                                                   # the coat's skirt
        if ($front -and $ax -lt 1.4) { return $K }                          # its open front edges
        if ($back -and $ax -lt 1.0) { return $K }
        return $B }
      if ($y -gt 23.3) { return $K }                                       # hem
      if ($front -and [Math]::Abs($x - $cx) -lt 0.4) { return $K }          # trouser crease
      return $B
    }
    'shoe' {
      if ($y -gt 3.6) { if ($front -and [Math]::Abs([Math]::Abs($x) - 5.9) -lt 0.4) { return $K }; return $B }   # trouser bottoms
      if ($y -gt 1.0 -and $z -lt -3.2 -and $n[1] -gt 0.3) { return $G }    # shine on the toe
      return $K
    }
  }
}

$bmp = New-Object Drawing.Bitmap 128, 128, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$used = 0
for ($t = 0; $t -lt 16384; $t++) {
  $tx = $t % 128; $ty = [Math]::Floor($t / 128)
  $f = $j.TFace[$t]
  if ($f -lt 0) { $bmp.SetPixel($tx, $ty, $baseBmp.GetPixel($tx, $ty)); continue }
  $p = $j.TPos[$t]
  $c = Paint $kind[$j.FacePiece[$f]] $p[0] $p[1] $p[2] $j.TNrm[$t] $tx $ty
  $bmp.SetPixel($tx, $ty, $c); $used++
}
$baseBmp.Dispose()
$bmp.Save($Out); $bmp.Dispose()
"pieces: " + (($kind.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' ')
"painted $used texels -> $Out"
& "$PSScriptRoot\tdsview.ps1" -Model "$tmp\man.3ds" -Texture $Out -Out ([IO.Path]::Combine([IO.Path]::GetDirectoryName($Out), 'james_views.png')) | Select-Object -Last 1
if ($Game) { & "$PSScriptRoot\man3dgame.ps1" -Walk $Walk -Texture $Out -Name JAMES3D -NoAnim }
if ($Max) {
  # James's own scenes for editing: the man's Man3d / man_walk / man_idle .max opened in 3ds Max (headless), every
  # bitmap that was man_tex.png pointed at james_tex.png, saved as James3d / james_walk / james_idle .max and
  # exported to .fbx the way the man's were (the mesh alone; the clips baked with their skin)
  $art = Split-Path $Out; $tex = $Out
  $batch = Get-ChildItem 'C:\Program Files\Autodesk\3ds Max *\3dsmaxbatch.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $batch) { throw "3ds Max (3dsmaxbatch.exe) not found" }
  $jobs = @(@('Man3d.max', 'James3d', 0), @('man_walk.max', 'james_walk', 1), @('man_idle.max', 'james_idle', 1))
  $logf = Join-Path $tmp 'max.log'; Remove-Item $logf -ErrorAction SilentlyContinue
  $ms = "lf = createFile @`"$logf`"`n"
  foreach ($jb in $jobs) {
    $in = Join-Path $art $jb[0]; $mx = Join-Path $art "$($jb[1]).max"; $fb = Join-Path $art "$($jb[1]).fbx"
    $ms += @"
loadMaxFile @"$in" quiet:true useFileUnits:true
nt = 0
for b in (getClassInstances BitmapTexture) do ( if matchPattern (filenameFromPath b.filename) pattern:"man_tex*" do ( b.filename = @"$tex"; nt += 1 ) )
saveMaxFile @"$mx" quiet:true
FBXExporterSetParam "ASCII" false
FBXExporterSetParam "Animation" $(if ($jb[2]) { 'true' } else { 'false' })
FBXExporterSetParam "Skin" $(if ($jb[2]) { 'true' } else { 'false' })
FBXExporterSetParam "Shape" false
$(if ($jb[2]) { "FBXExporterSetParam `"BakeAnimation`" true`nFBXExporterSetParam `"BakeFrameStart`" (animationRange.start.frame as integer)`nFBXExporterSetParam `"BakeFrameEnd`" (animationRange.end.frame as integer)`nFBXExporterSetParam `"BakeFrameStep`" 1`nexok = exportFile @`"$fb`" #noPrompt using:FBXEXP" } else { "select `$man`nexok = exportFile @`"$fb`" #noPrompt selectedOnly:true using:FBXEXP" })
format "% : % texture(s) -> james_tex, saved %, exported %\n" "$($jb[1])" nt (doesFileExist @"$mx") exok to:lf
resetMaxFile #noPrompt

"@
  }
  $ms += "close lf`n"
  $msf = Join-Path $tmp 'james.ms'; [IO.File]::WriteAllText($msf, $ms, [Text.Encoding]::ASCII)
  "building James's scenes in 3ds Max (headless) ..."
  $p = Start-Process -FilePath $batch.FullName -ArgumentList @("`"$msf`"", '-listenerlog', "`"$(Join-Path $tmp 'listener.txt')`"") -PassThru -WindowStyle Hidden
  if (-not $p.WaitForExit(900000)) { $p.Kill(); throw "3ds Max did not finish" }
  if (-not (Test-Path $logf)) { throw "the Max run failed (see $tmp\listener.txt)" }
  Get-Content $logf
  Copy-Item (Join-Path $art 'man_idle_clips.txt') (Join-Path $art 'james_idle_clips.txt') -Force
}
