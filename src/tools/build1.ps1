# build1.ps1 <NAME> - compile src\tools\NAME.BAS with BC 4.5 + link against uGL inside headless
# DOSBox-X (blocking). Log: src\tools\NAME_B.LOG. Usage: powershell -File src\tools\build1.ps1 CAR3D
param([Parameter(Mandatory=$true)][string]$Name, [switch]$NoList, [string[]]$Modules = @())   # -NoList: no .LST; -Modules: more .BAS compiled and linked in (MANWALK -Modules MWROOM)
$Name = $Name.ToUpperInvariant()
$tools = $PSScriptRoot
$LogName = $Name.Substring(0, [Math]::Min(6, $Name.Length)) + '_B'   # 8.3: DOS truncates longer log names
$conf = Join-Path $env:TEMP "build_$Name.conf"
# LINK's arguments in a response file: with more modules the command passes DOS's 127-character limit
$objs = (@("D:\TOOLS\$Name.OBJ") + @($Modules | ForEach-Object { "D:\TOOLS\$($_.ToUpperInvariant()).OBJ" })) -join '+'
[IO.File]::WriteAllText((Join-Path $tools "$Name.LNK"), "$objs`r`nD:\TOOLS\$Name.EXE`r`nD:\TOOLS\$Name.MAP`r`nBCOM45.LIB+D:\UGL\UGL.LIB;`r`n", [Text.Encoding]::ASCII)
$lines = @('[sdl]','autolock=false','','[cpu]','cycles=max','','[autoexec]',
 'mount Q C:\Code\Utils\qb45','mount D C:\Code\Dark-Visions\src','set INCLUDE=D:\UGL;D:\TOOLS','Q:',
 "del D:\TOOLS\$Name.OBJ","del D:\TOOLS\$Name.EXE",
 "echo === BC === > D:\TOOLS\${LogName}.LOG",
 $(if ($NoList) { "BC D:\TOOLS\$Name.BAS, D:\TOOLS\$Name.OBJ /O; >> D:\TOOLS\${LogName}.LOG" } else { "BC D:\TOOLS\$Name.BAS, D:\TOOLS\$Name.OBJ, D:\TOOLS\$Name.LST /O; >> D:\TOOLS\${LogName}.LOG" }),
 @($Modules | ForEach-Object { "BC D:\TOOLS\$($_.ToUpperInvariant()).BAS, D:\TOOLS\$($_.ToUpperInvariant()).OBJ /O; >> D:\TOOLS\${LogName}.LOG" }),
 "echo === LINK === >> D:\TOOLS\${LogName}.LOG",
 "LINK /SEG:800 @D:\TOOLS\$Name.LNK >> D:\TOOLS\${LogName}.LOG",
 "echo === DONE === >> D:\TOOLS\${LogName}.LOG",'exit')
$lines = @($lines | ForEach-Object { $_ })   # (the -Modules lines come in as an inner array)
[IO.File]::WriteAllText($conf, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
$p = Start-Process -FilePath 'C:\dosbox-x\dosbox-x.exe' -ArgumentList @('-conf', "`"$conf`"", '-nogui', '-silent') -PassThru -Wait
$log = Join-Path $tools "${LogName}.LOG"
$txt = [string](Get-Content $log -Raw)
$sev = [regex]::Match($txt, '(\d+) Severe').Groups[1].Value
$exe = Join-Path $tools "$Name.EXE"
if ((Test-Path $exe) -and $sev -eq '0' -and $txt -notmatch 'error L') { "$Name.EXE built: $((Get-Item $exe).Length) bytes" } else { "BUILD FAILED:"; $txt }
