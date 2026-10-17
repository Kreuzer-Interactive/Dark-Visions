# push_intro486.ps1 -- send the 3D-intro build to the 486 (mTCP FTP server, see
# net486.ps1) and run the game there: GAME.EXE plus the files GAME7 (IntroCar3D)
# reads from the game directory. SHADBOP.OVL is already part of the game.
#
#   powershell -ExecutionPolicy Bypass -File src\tools\push_intro486.ps1
#   ... -NoRun          push only
param([switch]$NoRun)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$src = (Resolve-Path "$tools\..").Path
$net = "$tools\net486.ps1"
$up = (& $net ping 2>&1 | Out-String) -match 'is up'
if (-not $up) { "486: FTP server not answering (restart SERVE on it)"; exit 1 }
$files = @('GAME.EXE', 'C3DT128.OVL', 'C3DTRI.OVL', 'C3DPRJ.OVL', 'C3DEDGE.OVL', 'C3DBLTM.OVL', 'C3DROT.OVL', 'C3DBLTF.OVL', 'SHADBOP.OVL', 'CAR3D.MDL', 'CAR3D.BMP', 'CARROAD.BMP', 'HILLROAD.BMP', 'HOUSE.PIC', 'ENTER.PIC', 'C3DTAB.DAT', 'JOED.BIN', 'SHADW2.BIN')
# (the last three are the caches the game writes itself -- C3DTAB.DAT keyed to this EXE's size -- pushed so the 486's first run is quick too)
foreach ($f in $files) {
    $p = Join-Path $src $f
    if (Test-Path $p) { & $net push -Source $p -All | Select-Object -Last 1 } else { "missing: $p" }
}
if (-not $NoRun) {
    # C3DDUMP=1: GAME7 appends its timing line to C3D.LOG in \darkv (pull it with net486 pull)
    & $net run -Job 'C:;cd \darkv;set C3DDUMP=1;game' | Select-Object -Last 1
    "486: running the game (the intro's 3D car logs to \darkv\C3D.LOG)"
}
