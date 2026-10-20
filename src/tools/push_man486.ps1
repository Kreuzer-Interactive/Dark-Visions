# push_man486.ps1 -- send the game with the 3D man (GAME8) to the 486 (mTCP FTP server, net486.ps1),
# switch it on in the 486's dark.ini (man3d=1; -Off sets man3d=0 for the 2D sprite) and run the game
# there with the mouse driver, as DARKV.BAT does. C3DDUMP=1: the room loads log their far heap to
# \darkv\C3D.LOG, and GAME8 logs whether the man loaded.
#
#   powershell -ExecutionPolicy Bypass -File src\tools\push_man486.ps1 [-Off] [-NoRun]
param([switch]$Off, [switch]$NoRun)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$src = (Resolve-Path "$tools\..").Path
$net = "$tools\net486.ps1"
$files = @('GAME.EXE', 'MAN3D.MDL', 'MAN3D.BMP', 'MAN3DW.ANI', 'MAN3DI.ANI', 'JAMES3D.MDL', 'JAMES3D.BMP', 'JAMES3DI.ANI', 'C3DEDGI.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'C3DROT.OVL', 'C3DSKIN.OVL', 'C3DEDGO.OVL', 'C3DCGA.OVL', 'C3DCOMP.OVL', 'C3DFUSE.OVL')
foreach ($f in $files) {
    $p = Join-Path $src $f
    if (Test-Path $p) { & $net push -Source $p -All | Select-Object -Last 1 } else { "missing: $p" }
}
# the 486's own dark.ini, with the man3d line set
$tmp = Join-Path $env:TEMP 'man486'; if (-not (Test-Path $tmp)) { New-Item -ItemType Directory $tmp | Out-Null }
if (Test-Path "$tmp\DARK.INI") { [IO.File]::Delete("$tmp\DARK.INI") }
& $net pull /drive_c/darkv/DARK.INI -To $tmp | Select-Object -Last 1
$ini = @(Get-Content "$tmp\DARK.INI" | Where-Object { $_ -notmatch '^\s*man3d\s*=' -and $_ -notmatch '^; man3d' })
$ini += '; man3d=1 draws the player as the 3D man in the house rooms (needs MAN3D.* and the C3D*.OVL files; 0 = the 2D sprite)'
$ini += "man3d=$(if ($Off) { 0 } else { 1 })"
[IO.File]::WriteAllLines("$tmp\DARK.INI", [string[]]$ini)
& $net push -Source "$tmp\DARK.INI" -Dest /drive_c/darkv -All | Select-Object -Last 1
if (-not $NoRun) {
    & $net run -Job 'C:;cd \darkv;mouse;set C3DDUMP=1;game' | Select-Object -Last 1
    "486: running the game, man3d=$(if ($Off) { 0 } else { 1 }) (C3D.LOG in \darkv)"
}
