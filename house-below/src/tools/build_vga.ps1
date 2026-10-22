param([switch]$Test)
$ErrorActionPreference = 'Stop'
$src = Split-Path $PSScriptRoot -Parent
$hb = Split-Path $src -Parent
$repo = Split-Path $hb -Parent
$ugl = Join-Path $repo 'src\UGL'
$dosbox = 'C:\dosbox-x\dosbox-x.exe'
$qb = 'C:\Code\Utils\qb45'
if (!(Test-Path $dosbox)) { $dosbox = Join-Path $repo 'QA\DOSBox-X\dosbox-x.exe' }
if (!(Test-Path $qb)) { throw 'Set $qb in build_vga.ps1 to your licensed QuickBASIC 4.5 directory.' }
# BC requires DOS line endings, including the final newline.
$modules = @('VISIONS', 'VGADRAW', 'VGADIAL', 'VGAFACE', 'VGASAY', 'VGAMOUSE', 'VGAACT', 'VGATALK', 'VGATRIP', 'VGARIDE', 'VGAPEOP', 'VGASAVE', 'VGAKNOW', 'VGATOPIC', 'VGATEST', 'VGAPTEST', 'VGASTEST', 'VGAKTEST', 'VGARTEST')
foreach ($module in $modules) {
    $bas = Join-Path $src "$module.BAS"
    $code = [IO.File]::ReadAllText($bas) -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($bas, $code, [Text.Encoding]::ASCII)
}
$objs = ($modules | ForEach-Object { "D:\$_.OBJ" }) -join "+`r`n"
$response = "$objs`r`nD:\VISIONS.EXE`r`nD:\VISIONS.MAP`r`nBCOM45.LIB+QB.LIB+U:\UGL.LIB;`r`n"
[IO.File]::WriteAllText((Join-Path $src 'VGA.LNK'), $response, [Text.Encoding]::ASCII)
$lines = @('[sdl]', 'autolock=false', '[cpu]', 'cycles=max', '[autoexec]',
    "mount Q `"$qb`"", "mount D `"$src`"", "mount U `"$ugl`"", 'set INCLUDE=U:\;D:\', 'Q:',
    'echo VGA adventure build > D:\VGABUILD.LOG')
foreach ($module in $modules) {
    $lines += "BC D:\$module.BAS,D:\$module.OBJ,D:\$module.LST /O /W /X; >> D:\VGABUILD.LOG"
}
# Nested conversation calls and the DOS test fixtures exceed LINK's 2 KB default.
$lines += @('LINK /SEG:800 /ST:8192 @D:\VGA.LNK >> D:\VGABUILD.LOG', 'exit')
$conf = Join-Path $src 'vga_build.conf'
[IO.File]::WriteAllText($conf, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
Start-Process $dosbox -ArgumentList @('-conf', "`"$conf`"", '-nogui', '-silent') -WindowStyle Hidden -Wait
$log = [IO.File]::ReadAllText((Join-Path $src 'VGABUILD.LOG'))
if (([regex]::Matches($log, '0 Severe')).Count -ne $modules.Count -or $log -match 'error L' -or !(Test-Path (Join-Path $src 'VISIONS.EXE'))) { throw $log }
Write-Output "VISIONS.EXE compiled successfully."
if ($Test) {
    # Tests get an isolated writable save directory and cannot replace player saves.
    $qa = Join-Path $repo 'tmp\vga-qa'
    New-Item -ItemType Directory -Force (Join-Path $qa 'VGA') | Out-Null
    Copy-Item (Join-Path $src 'VGA\*.BMP') (Join-Path $qa 'VGA')
    Copy-Item (Join-Path $src 'VGA\*.DAT') (Join-Path $qa 'VGA')
    $testLogPath = Join-Path $qa 'VGA\TEST.LOG'
    if (Test-Path -LiteralPath $testLogPath) { Remove-Item -LiteralPath $testLogPath }
    $run = @('[sdl]','autolock=false','output=openglnb','[dosbox]','machine=svga_s3',
        '[cpu]','cycles=fixed 50000','[autoexec]',
        "mount D `"$src`"", "mount T `"$qa`"", 'T:', 'D:\VISIONS.EXE /TEST > RUN.LOG', 'exit')
    $testconf = Join-Path $qa 'test.conf'
    [IO.File]::WriteAllText($testconf, ($run -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
    Start-Process $dosbox -ArgumentList @('-conf', "`"$testconf`"", '-nogui', '-silent') -WindowStyle Hidden -Wait
    $testlog = [IO.File]::ReadAllText((Join-Path $qa 'VGA\TEST.LOG'))
    Write-Output $testlog
    if ($testlog -notmatch 'FAILURES 0' -or $testlog -match 'FAIL ') { throw 'VGA adventure regression test failed.' }
}
