<#
.SYNOPSIS
  mkdisks.ps1 - rebuild the 2-disk DOS install set from the current src tree:
    dist\DISK1  INSTALL.EXE + GAME.ZIP + PKUNZIP.EXE + README.TXT   (game, 1 floppy)
    dist\DISK2  MANUAL.ZIP + README.TXT                              (10 x 640x480 manual pages)

.DESCRIPTION
  Build GAME.EXE first (DOSBox-X -conf src\build_local.conf, check BUILD.LOG: 0 severe, LINK clean).
  GAME.ZIP = every runtime file in src (EXE COM BAT PIC PAC PCT MSK DAT TXT BMP INI TTT OVL BOX)
  minus dev-only files (HAEDIT.EXE, TESTBLT*.EXE, RESULTS*.TXT, SHADLD.TXT, the MAN0* manual
  experiments, the MANP* manual pages (disk 2), SAVER?.PAC slots incl. the SAVERK revive snapshot,
  *.LOG, INSTALL.BAT, GAME.EXR) plus the UGLTEST/UGLTESTD diagnostics from src\tools.
  MANUAL.ZIP = src\MANP00..09.BMP.
  Both archives are made by the real PKZIP 2.50 for DOS (third_party\pkzip250) inside DOSBox-X
  (a window pops up for a few seconds) and checked with PKUNZIP -t; the READMEs on the disks are
  kept as they are. Work files go to dist\.mkwork (gitignored with the rest of dist).
  Unattended install check (merged A: with both disks, AUTOTYPE enter x6): see the 2026-10-11 note
  in the manual-and-installer memory.

.EXAMPLE
  .\mkdisks.ps1
#>
param(
    [string]$DosBox = 'C:\dosbox-x\dosbox-x.exe'
)
$ErrorActionPreference = 'Stop'
$repo  = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src   = Join-Path $repo 'src'
$tools = Join-Path $repo 'src\tools'
$dist  = Join-Path $repo 'dist'
$pk    = Join-Path $repo 'third_party\pkzip250'
$floppy = 1457664
$mk     = Join-Path $dist '.mkwork'
$stageG = Join-Path $mk 'GAME'
$stageM = Join-Path $mk 'MANUAL'
$work   = Join-Path $mk 'pk'
$ascii = [System.Text.Encoding]::ASCII
function Write-Dos([string]$path, [string]$text) { [System.IO.File]::WriteAllText($path, ($text -replace "`r?`n", "`r`n"), $ascii) }
function Reset-Dir([string]$p) {
    # empty in place: Explorer / a DOSBox mount in the folder makes a directory delete fail
    if (Test-Path -LiteralPath $p) { Get-ChildItem -LiteralPath $p -Force | Remove-Item -Recurse -Force }
    else { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
if (-not (Test-Path -LiteralPath $DosBox)) { throw "DOSBox-X not found: $DosBox" }

# ---------- select the game runtime set from src ----------
$include = @('EXE','COM','BAT','PIC','PAC','PCT','MSK','DAT','TXT','BMP','INI','TTT','OVL','BOX')
$excludeNames = @('INSTALL.BAT','GAME.EXR','HAEDIT.EXE','SHADLD.TXT')
$excludeLike  = @('*.LOG','SAVER?.PAC','TESTBLT*.EXE','RESULTS*.TXT','MANP*.BMP','MAN0*.BMP')
Reset-Dir $stageG; Reset-Dir $stageM; Reset-Dir $work
$game = @()
foreach ($f in Get-ChildItem -LiteralPath $src -File) {
    $up = $f.Name.ToUpperInvariant()
    $ext = [System.IO.Path]::GetExtension($up).TrimStart('.')
    if ($include -notcontains $ext) { continue }
    if ($excludeNames -contains $up) { continue }
    $skip = $false; foreach ($pat in $excludeLike) { if ($up -like $pat) { $skip = $true } }
    if ($skip) { continue }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($up)
    if ($base.Length -gt 8 -or $ext.Length -gt 3) { throw "$up is not an 8.3 name" }
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $stageG $up)
    $game += $up
}
foreach ($diag in @('UGLTEST.EXE','UGLTESTD.EXE')) { Copy-Item -LiteralPath (Join-Path $tools $diag) -Destination (Join-Path $stageG $diag); $game += $diag }
$game = $game | Sort-Object
$man = @()
foreach ($i in 0..9) { $n = 'MANP{0:D2}.BMP' -f $i; Copy-Item -LiteralPath (Join-Path $src $n) -Destination (Join-Path $stageM $n); $man += $n }
"GAME set: {0} files, {1:N0} bytes" -f $game.Count, ((Get-ChildItem $stageG | Measure-Object Length -Sum).Sum)
"  non-art: " + (($game | Where-Object { $_ -notmatch '\.(PIC|PAC|PCT|MSK)$' }) -join ' ')
"MANUAL set: {0} files, {1:N0} bytes" -f $man.Count, ((Get-ChildItem $stageM | Measure-Object Length -Sum).Sum)

# ---------- PKZIP 2.50 in DOSBox-X (no -204 switch: it does not exist in 2.50 and hangs) ----------
Copy-Item (Join-Path $pk 'PKZIP.EXE') (Join-Path $work 'PKZIP.EXE'); Copy-Item (Join-Path $pk 'PKUNZIP.EXE') (Join-Path $work 'PKUNZIP.EXE')
$auto = @('[sdl]','output=surface','autolock=false','[cpu]','cycles=max','[autoexec]',
    "mount c `"$work`"", "mount d `"$stageG`"", "mount e `"$stageM`"", 'c:',
    'pkzip -ex GAME.ZIP D:\*.* > MAKE1.LOG', 'pkunzip -t GAME.ZIP > TEST1.LOG',
    'pkzip -ex MANUAL.ZIP E:\*.* > MAKE2.LOG', 'pkunzip -t MANUAL.ZIP > TEST2.LOG',
    'echo done > DONE.TXT', 'exit')
$conf = Join-Path $work 'mkdisks.conf'
Write-Dos $conf (($auto -join "`n") + "`n")
$p = Start-Process -FilePath $DosBox -ArgumentList @('-conf', "`"$conf`"") -PassThru
$t0 = Get-Date
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt 240) { Start-Sleep -Milliseconds 500 }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; throw 'DOSBox-X did not finish (killed)' }
if (-not (Test-Path (Join-Path $work 'DONE.TXT'))) { throw "DOSBox-X session ended early - see $work\MAKE*.LOG" }
foreach ($pair in @(@('GAME.ZIP','TEST1.LOG',$game.Count), @('MANUAL.ZIP','TEST2.LOG',$man.Count))) {
    $zip, $log, $expect = $pair
    if (-not (Test-Path (Join-Path $work $zip))) { throw "PKZIP made no $zip - see $work\MAKE*.LOG" }
    $tested = @(Get-Content (Join-Path $work $log) | Where-Object { $_ -match '^Testing: ' })
    $okc = @($tested | Where-Object { $_ -match '\sOK\s*$' }).Count
    "{0}: PKUNZIP -t {1} OK of {2} tested, {3} expected" -f $zip, $okc, $tested.Count, $expect
    if ($okc -ne $expect -or $tested.Count -ne $okc) { throw "PKUNZIP -t failed on $zip (see $work\$log)" }
}

# ---------- assemble the disks (READMEs kept) ----------
$d1 = Join-Path $dist 'DISK1'; $d2 = Join-Path $dist 'DISK2'
$readme1 = Get-Content -Raw (Join-Path $d1 'README.TXT'); $readme2 = Get-Content -Raw (Join-Path $d2 'README.TXT')
Reset-Dir $d1; Reset-Dir $d2
Copy-Item (Join-Path $tools 'INSTALL.EXE') (Join-Path $d1 'INSTALL.EXE')
Move-Item (Join-Path $work 'GAME.ZIP') (Join-Path $d1 'GAME.ZIP')
Copy-Item (Join-Path $pk 'PKUNZIP.EXE') (Join-Path $d1 'PKUNZIP.EXE')
[System.IO.File]::WriteAllText((Join-Path $d1 'README.TXT'), $readme1, $ascii)
Move-Item (Join-Path $work 'MANUAL.ZIP') (Join-Path $d2 'MANUAL.ZIP')
[System.IO.File]::WriteAllText((Join-Path $d2 'README.TXT'), $readme2, $ascii)
foreach ($d in @($d1, $d2)) {
    $sum = (Get-ChildItem -LiteralPath $d -File | Measure-Object Length -Sum).Sum
    "{0}: {1:N0} bytes of {2:N0} ({3:N0} free) {4}" -f (Split-Path $d -Leaf), $sum, $floppy, ($floppy - $sum), $(if ($sum -le $floppy) { 'FITS' } else { 'TOO BIG' })
    Get-ChildItem -LiteralPath $d -File | ForEach-Object { "   {0,-12} {1,10:N0}" -f $_.Name, $_.Length }
}
