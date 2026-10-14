# car3d_refresh.ps1 -- the "after a save" loop for the 3D car: convert the newest model
# export + the texture in src\ART\Car3d, (re)launch the live DOSBox-X window with the
# drive on a loop, and push the files to the 486 if its FTP server answers.
#
#   powershell -ExecutionPolicy Bypass -File src\tools\car3d_refresh.ps1
#   ... -Texture Texture3.png      another texture file (default Texture2.png)
#   ... -Lit                       8 lighting bands instead of unlit (for grey-shaded textures)
#   ... -Scale 1                   the car as modelled (default 1.15: 15% bigger in place)
#   ... -Seconds 120               how long the window runs (default 300; ESC quits early)
#   ... -NoLaunch / -No486         skip the window / skip the 486
#
# Keys in the window: ESC quit, SPACE pause, O ink on/off, R turntable, [ ] heading,
# - = light (lit models), A/Z zoom.
param(
    [string]$Texture = "Texture2.png",
    [string]$Backdrop = "carr_road2.png",   # painted 320x200 backdrop in src\ART\Car3d; "" or a missing file = the carr.pic composition
    [double]$Scale = 1.15,                 # the car's size in place (converter -Scale); 1 = as modelled
    [switch]$Lit,
    [int]$Seconds = 300,
    [switch]$NoLaunch,
    [switch]$No486
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$src = (Resolve-Path "$tools\..").Path

# 1. convert (the converter picks the newest .3ds in src\ART\Car3d and says which)
$cnv = @{ Texture = $Texture; Scale = $Scale }
if (-not $Lit) { $cnv.Unlit = $true }
if ($Backdrop -and (Test-Path "$src\ART\Car3d\$Backdrop")) { $cnv.Backdrop = $Backdrop }
& "$tools\car3dcnv.ps1" @cnv | Where-Object { $_ -match 'model:|dropped|MDL|BMP' }

# 2. the live window
if (-not $NoLaunch) {
    $conf = Join-Path $env:TEMP 'car3d_live.conf'
    $lines = @('[sdl]', 'autolock=false', '', '[cpu]', 'cycles=max', 'cputype=486', '', '[autoexec]',
        "mount D $src", 'D:', 'cd \', "D:\TOOLS\CAR3D.EXE $Seconds", 'exit')
    [IO.File]::WriteAllText($conf, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
    Get-Process dosbox-x -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Process -FilePath 'C:\dosbox-x\dosbox-x.exe' -ArgumentList @('-conf', "`"$conf`"", '-nogui')
    "live window: CAR3D for $Seconds s"
}

# 3. the 486
if (-not $No486) {
    $net = "$tools\net486.ps1"
    $up = (& $net ping 2>&1 | Out-String) -match 'is up'
    if ($up) {
        $files = @("$src\CAR3D.MDL", "$src\CAR3D.BMP", "$tools\CAR3D.EXE"); if (Test-Path "$src\CARROAD.BMP") { $files += "$src\CARROAD.BMP" }
    foreach ($f in $files) { & $net push -Source $f -All | Select-Object -Last 1 }
        & $net run -Job 'C:;cd \darkv;car3d 30' | Select-Object -Last 1
        "486: running the drive for 30 s"
    } else { "486: FTP server not answering (restart SERVE on it), skipped" }
}
