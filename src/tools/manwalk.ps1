# manwalk.ps1 - the walk-around test scene for the 3D man: converts a model + texture with
# car3dcnv.ps1, stages everything MANWALK.EXE needs in dist\manwalk, and runs it.
#   manwalk.ps1                      stage the default (the artist's man_v2.3ds + man_tex.png) and open DOSBox-X on it
#   manwalk.ps1 -Model man3d.3ds     the procedural model instead (any .3ds in src\ART\Man3d)
#   manwalk.ps1 -Anim src\ART\Man3d\man_walk.fbx   the walk as edited in 3ds Max (exported as FBX, Bake Animation on)
#   manwalk.ps1 -Check               headless: MANWALK S -> dist\manwalk\MANWLK1/2.BMP + MANWALK.LOG, printed
#   manwalk.ps1 -Bench [-Push486]    MANWALK B: each phase of a frame timed with the PIT -> MANWALK.LOG, printed
#   manwalk.ps1 -Push486             push the staged folder to the 486 (\MANWALK) and start MANWALK there
#   manwalk.ps1 -Push486 -Check      ...the scripted run there; pull MANWALK.LOG and the BMPs back afterwards
# Keys in the scene: Up/Down walk, Left/Right turn, Space = a copy of the model where he stands (up to 7),
# C clears the copies, A sets the copies walking in place, V toggles the vertical-sync wait, F/G/D the raster's
# flat/quad/dot thresholds, O silhouette ink, Esc quits (prints the fps at exit). He walks with MAN3D.ANI
# (man3danim.ps1, baked from the staged model) when it is there.
param(
  [string]$Model = 'man_v2.3ds',
  [string]$Anim = '',          # an animated FBX from 3ds Max (man3dfbx.ps1 made the first one): its mesh and its walk
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
  & "$PSScriptRoot\car3dcnv.ps1" -Src $art -Model $Model -Texture $Texture -Unlit -Scale $Scale -Backdrop "..\Car3d\carr_road2.png" -Out $st | Select-Object -Last 3
  foreach ($x in 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'SHADBOP.OVL', 'C3DEDGE.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL') { Copy-Item "$src\$x" $st -Force }
  Copy-Item "$src\tools\MANWALK.EXE" $st -Force
  # the walk, baked from the model just converted (its vertex order)
  if ($Anim) { & "$PSScriptRoot\man3dfbx.ps1" -Import $Anim -Mdl "$st\CAR3D.MDL" -Out "$st\MAN3D.ANI" -Preview "$art\man_walk.png" | Select-String 'fbx:|skin|stride|->' }
  else { & "$PSScriptRoot\man3danim.ps1" -Mdl "$st\CAR3D.MDL" -Out "$st\MAN3D.ANI" -Preview "$art\man_walk.png" | Select-String 'stride|->' }
  "staged: $st ($Model + $Texture)"
}
if ($Push486) {
  $net = "$PSScriptRoot\net486.ps1"
  foreach ($x in 'MANWALK.EXE', 'CAR3D.MDL', 'CAR3D.BMP', 'CARROAD.BMP', 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'SHADBOP.OVL', 'C3DEDGE.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL', 'MAN3D.ANI') {
    & $net push -Source "$st\$x" -Dest /drive_c/manwalk -All | Select-Object -Last 1
  }
  if ($Check -or $Bench) {
    $job = if ($Bench) { 'C:;cd \manwalk;manwalk b' } else { 'C:;cd \manwalk;manwalk s' }
    & $net run -Job $job -Wait -WaitMinutes 5 | Select-Object -Last 2
    foreach ($x in 'MANWALK.LOG', 'MANWLK1.BMP', 'MANWLK2.BMP') {
      $d = "$st\from486"; if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null }
      if (Test-Path "$d\$x" -PathType Container) { [IO.Directory]::Delete("$d\$x", $true) } elseif (Test-Path "$d\$x") { [IO.File]::Delete("$d\$x") }
      & $net pull "/drive_c/manwalk/$x" -To $d | Select-Object -Last 1
    }
    Get-Content "$st\from486\MANWALK.LOG" -ErrorAction SilentlyContinue
  } else {
    & $net run -Job 'C:;cd \manwalk;manwalk' | Select-Object -Last 1
    "486: MANWALK running (Esc there quits it and prints the fps)"
  }
  return
}
$conf = Join-Path $env:TEMP 'manwalk_run.conf'
$auto = if ($Bench) { 'MANWALK B' } elseif ($Check) { 'MANWALK S' } else { 'MANWALK' }
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
