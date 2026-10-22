$ErrorActionPreference = 'Stop'
$dosbox = 'C:\dosbox-x\dosbox-x.exe'
if (!(Test-Path $dosbox)) { $dosbox = Join-Path $PSScriptRoot '..\QA\DOSBox-X\dosbox-x.exe' }
if (!(Test-Path $dosbox)) { throw 'DOSBox-X was not found. Run SRC\PLAYVGA.BAT on a DOS machine with a standard VGA (mode 13h) and a mouse driver.' }
$src = Join-Path $PSScriptRoot 'src'
$config = Join-Path $PSScriptRoot 'src\vga-play.conf'
New-Item -ItemType Directory -Force (Split-Path $config) | Out-Null
$lines = @('[sdl]', 'autolock=false', 'mouse_emulation=never', 'usesystemcursor=false', 'windowresolution=960x720', 'output=openglnb',
    '[render]', 'aspect=true', 'scaler=normal3x', '[dosbox]', 'machine=svga_s3',
    '[cpu]', 'cycles=fixed 50000', '[dos]', 'int33 hide host cursor when polling=true', '[autoexec]', "mount D `"$src`"", 'D:', 'call PLAYVGA.BAT', 'exit')
[IO.File]::WriteAllText($config, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
# This launcher is explicitly invoked by the player to show the interactive game.
Start-Process $dosbox -ArgumentList @('-conf', "`"$config`"") -Wait
