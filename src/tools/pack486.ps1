<#
.SYNOPSIS
  pack486.ps1 - gather the current Dark Visions build into a transfer folder for the 486,
  and (when it does not fit on one 1.44 MB floppy) into PKZIP archives, one per disk.

.DESCRIPTION
  Source = QA\current (the tested runtime set) unless -Source says otherwise.
  Takes: EXE COM BAT PIC PAC PCT MSK DAT TXT BMP INI TTT OVL, minus the save slots
  (SAVER?.PAC, the game recreates empty ones; -WithSaves ships the dev saves so the
  tester can jump to later rooms), logs, the 1993 floppy installer (INSTALL.BAT) and
  the stray GAME.EXR.
  Produces under <repo>\dist:
    DV486\              flat copy, uppercase 8.3 names, MANIFEST.TXT   (copy as-is if you have room)
    DV486-DISK1\ ...    when the set is bigger than one floppy: DV486.ZIP (or DV486_1.ZIP, _2 ...)
                        bin-packed to fit 1.44 MB each, plus EXTRACT.BAT, README.TXT and PKUNZIP.EXE.
                        Copy each folder's contents onto one floppy.
  The archives are made by the real PKZIP 2.50 for DOS (third_party\pkzip250) running inside
  DOSBox-X (QA\DOSBox-X or C:\dosbox-x - a window pops up for a few seconds), and every disk is
  then checked with PKUNZIP -t in the same session. Without PKZIP or DOSBox-X (or with -NoDosBox)
  the .NET zip writer is used instead; that output is plain deflate with 8.3 names and no extras,
  which PKUNZIP 2.04g+ reads (verified with PKUNZIP 2.50).
  Do NOT pass PKZIP 2.50 a "-204" switch: it does not exist in the DOS version and PKZIP hangs.

.EXAMPLE
  .\pack486.ps1                                    # QA\current -> dist\DV486 (+ disks if needed)
  .\pack486.ps1 -Source ..\..\src -NoZip            # just the folder, from src
  .\pack486.ps1 -WithSaves                          # include the SAVER?.PAC slots
  .\pack486.ps1 -NoDosBox                           # .NET zip writer instead of PKZIP
#>
param(
    [string]$Source = "",
    [string]$Dist = "",
    [string]$Name = "DV486",
    [int]$FloppyBytes = 1457664,
    [string]$PkDir = "",
    [string]$PkUnzip = "",
    [string]$DosBox = "",
    [string]$TargetDir = "C:\DARKV",
    [switch]$NoZip,
    [switch]$NoDosBox,
    [switch]$WithSaves
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Source) { $Source = Join-Path $repo 'QA\current' }
if (-not $Dist) { $Dist = Join-Path $repo 'dist' }
if (-not $PkDir) { $PkDir = Join-Path $repo 'third_party\pkzip250' }
if (-not $PkUnzip -and (Test-Path -LiteralPath (Join-Path $PkDir 'PKUNZIP.EXE'))) { $PkUnzip = Join-Path $PkDir 'PKUNZIP.EXE' }
if (-not $DosBox) {
    foreach ($cand in @((Join-Path $repo 'QA\DOSBox-X\dosbox-x.exe'), 'C:\dosbox-x\dosbox-x.exe')) { if (Test-Path -LiteralPath $cand) { $DosBox = $cand; break } }
}
$pkZipExe = Join-Path $PkDir 'PKZIP.EXE'
$usePk = (-not $NoDosBox) -and $DosBox -and (Test-Path -LiteralPath $pkZipExe) -and $PkUnzip
$Source = (Resolve-Path $Source).Path
$include = @('EXE', 'COM', 'BAT', 'PIC', 'PAC', 'PCT', 'MSK', 'DAT', 'TXT', 'BMP', 'INI', 'TTT', 'OVL')
$excludeNames = @('INSTALL.BAT', 'GAME.EXR')
$excludeLike = @('*.LOG')
if (-not $WithSaves) { $excludeLike += 'SAVER?.PAC' }
$ascii = [System.Text.Encoding]::ASCII

function Write-Dos([string]$path, [string]$text) {
    # DOS text: CRLF, ASCII
    [System.IO.File]::WriteAllText($path, ($text -replace "`r?`n", "`r`n"), $ascii)
}
function Clear-Dir([string]$path) {
    # empty a folder but keep the folder itself: Explorer or a DOSBox mount sitting in it
    # would make a delete of the directory fail with "used by another process"
    if (Test-Path -LiteralPath $path) { Get-ChildItem -LiteralPath $path -Force | Remove-Item -Recurse -Force }
    else { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

# ---------- select the runtime files ----------
$files = @()
foreach ($f in Get-ChildItem -LiteralPath $Source -File) {
    $up = $f.Name.ToUpperInvariant()
    $ext = [System.IO.Path]::GetExtension($up).TrimStart('.')
    if ($include -notcontains $ext) { continue }
    if ($excludeNames -contains $up) { continue }
    $skip = $false
    foreach ($pat in $excludeLike) { if ($up -like $pat) { $skip = $true } }
    if ($skip) { continue }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($up)
    if ($base.Length -gt 8 -or $ext.Length -gt 3) { Write-Warning "$up is not an 8.3 name - DOS will not see it as intended" }
    $files += [pscustomobject]@{ Path = $f.FullName; Name = $up; Size = $f.Length }
}
$files = $files | Sort-Object Name
if ($files.Count -eq 0) { throw "nothing to pack in $Source" }
$total = ($files | Measure-Object -Property Size -Sum).Sum
"{0} files, {1:N0} bytes from {2}" -f $files.Count, $total, $Source

# ---------- flat folder ----------
$flat = Join-Path $Dist $Name
Clear-Dir $flat
foreach ($f in $files) { Copy-Item -LiteralPath $f.Path -Destination (Join-Path $flat $f.Name) }
$manifest = "Dark Visions - 486 test build - packed {0}`n{1} files, {2:N0} bytes`n`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $files.Count, $total
foreach ($f in $files) { $manifest += ("{0,-12} {1,9:N0}`n" -f $f.Name, $f.Size) }
Write-Dos (Join-Path $flat 'MANIFEST.TXT') $manifest
"flat copy: $flat"

$fits = $total -le $FloppyBytes
if ($fits) { "the set fits on one 1.44 MB floppy uncompressed ({0:N0} bytes free)" -f ($FloppyBytes - $total) }
if ($NoZip -or $fits) { return }

# ---------- zip: measure each file's deflated size, bin-pack onto disks ----------
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-DeflatedSize([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream
    $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionLevel]::Optimal, $true)
    $ds.Write($bytes, 0, $bytes.Length); $ds.Dispose()
    $n = $ms.Length; $ms.Dispose(); return $n
}
"measuring compression..."
foreach ($f in $files) { $f | Add-Member -NotePropertyName Packed -NotePropertyValue ((Get-DeflatedSize $f.Path) + 76 + 2 * $f.Name.Length) }
$packedTotal = ($files | Measure-Object -Property Packed -Sum).Sum
"deflated: {0:N0} bytes ({1:P0} of the raw size)" -f $packedTotal, ($packedTotal / $total)
if ($usePk) { "archiver: PKZIP 2.50 for DOS in DOSBox-X ($DosBox)" } else { "archiver: .NET zip writer (PKZIP 2.04g compatible)" }

# .NET fallback writer
function New-ZipDotNet([string]$zipPath, $entries) {
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    foreach ($f in ($entries | Sort-Object Name)) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.Path, $f.Name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    $zip.Dispose()
}

# PKZIP in DOSBox-X: one session builds every disk's archive from a list file (D: = the flat
# folder, C: = the work folder) and tests each with PKUNZIP -t. Returns $true when all passed.
function New-ZipsPkzip($diskList, [string]$work) {
    Clear-Dir $work
    Copy-Item -LiteralPath $pkZipExe -Destination (Join-Path $work 'PKZIP.EXE')
    Copy-Item -LiteralPath $PkUnzip -Destination (Join-Path $work 'PKUNZIP.EXE')
    $auto = @('[sdl]', 'output=surface', 'autolock=false', '[cpu]', 'cycles=max', '[autoexec]', "mount c `"$work`"", "mount d `"$flat`"", 'c:')
    for ($i = 0; $i -lt $diskList.Count; $i++) {
        $n = $i + 1
        Write-Dos (Join-Path $work "LIST$n.TXT") ((($diskList[$i].Files | Sort-Object Name | ForEach-Object { 'D:\' + $_.Name }) -join "`n") + "`n")
        $auto += "pkzip -ex $($diskList[$i].ZipName) @LIST$n.TXT > MAKE$n.LOG"
        $auto += "pkunzip -t $($diskList[$i].ZipName) > TEST$n.LOG"
    }
    $auto += 'echo done > DONE.TXT'
    $auto += 'exit'
    $conf = Join-Path $work 'pack486.conf'
    Write-Dos $conf (($auto -join "`n") + "`n")
    $p = Start-Process -FilePath $DosBox -ArgumentList @('-conf', "`"$conf`"") -PassThru
    $limit = 120 + 30 * $diskList.Count
    $t0 = Get-Date
    while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $limit) { Start-Sleep -Milliseconds 500 }
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; Write-Warning "DOSBox-X did not finish in $limit s (killed)"; return $false }
    if (-not (Test-Path (Join-Path $work 'DONE.TXT'))) { Write-Warning "the DOSBox-X session ended early (see $work\MAKE*.LOG)"; return $false }
    for ($i = 0; $i -lt $diskList.Count; $i++) {
        $n = $i + 1
        $zipPath = Join-Path $work $diskList[$i].ZipName
        $log = Join-Path $work "TEST$n.LOG"
        if (-not (Test-Path -LiteralPath $zipPath) -or -not (Test-Path -LiteralPath $log)) { Write-Warning "PKZIP produced no $($diskList[$i].ZipName) (see $work\MAKE$n.LOG)"; return $false }
        $tested = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^Testing: ' })
        $okCount = @($tested | Where-Object { $_ -match '\sOK\s*$' }).Count
        if ($okCount -ne $diskList[$i].Files.Count -or $tested.Count -ne $okCount) {
            Write-Warning ("PKUNZIP -t on {0}: {1} OK of {2} entries, {3} expected (see {4})" -f $diskList[$i].ZipName, $okCount, $tested.Count, $diskList[$i].Files.Count, $log)
            return $false
        }
    }
    return $true
}

$extras = 4096                                   # EXTRACT.BAT + README.TXT + slack
$pkSize = 0
if ($PkUnzip) { if (-not (Test-Path -LiteralPath $PkUnzip)) { throw "PKUNZIP not found: $PkUnzip" }; $pkSize = (Get-Item -LiteralPath $PkUnzip).Length }
$work = Join-Path $Dist '.pkwork'
$shrink = 0
do {
    $disks = @()
    $cap1 = $FloppyBytes - $extras - $pkSize - 22 - $shrink      # every disk carries PKUNZIP so it
    $capN = $FloppyBytes - $extras - $pkSize - 22 - $shrink      # is self-contained (extract from any)
    foreach ($f in ($files | Sort-Object Packed -Descending)) {
        $placed = $false
        for ($i = 0; $i -lt $disks.Count; $i++) {
            $cap = if ($i -eq 0) { $cap1 } else { $capN }
            if ($disks[$i].Used + $f.Packed -le $cap) { $disks[$i].Files += $f; $disks[$i].Used += $f.Packed; $placed = $true; break }
        }
        if (-not $placed) {
            $disks += [pscustomobject]@{ Files = @($f); Used = $f.Packed }
        }
    }
    for ($i = 0; $i -lt $disks.Count; $i++) {
        $n = $i + 1
        $zipName = if ($disks.Count -eq 1) { "$Name.ZIP" } else { "{0}_{1}.ZIP" -f $Name, $n }
        $disks[$i] | Add-Member -NotePropertyName ZipName -NotePropertyValue $zipName -Force
        $disks[$i] | Add-Member -NotePropertyName ZipPath -NotePropertyValue (Join-Path (Join-Path $Dist ("{0}-DISK{1}" -f $Name, $n)) $zipName) -Force
    }
    # write the zips (PKZIP in DOSBox-X, else .NET) and check the real sizes
    $pkDone = $false
    if ($usePk) {
        $pkDone = New-ZipsPkzip $disks $work
        if (-not $pkDone) { Write-Warning "falling back to the .NET zip writer" }
    }
    $ok = $true
    for ($i = 0; $i -lt $disks.Count; $i++) {
        $diskDir = Split-Path $disks[$i].ZipPath -Parent
        Clear-Dir $diskDir
        if ($pkDone) { Move-Item -LiteralPath (Join-Path $work $disks[$i].ZipName) -Destination $disks[$i].ZipPath }
        else { New-ZipDotNet $disks[$i].ZipPath $disks[$i].Files }
        $disks[$i] | Add-Member -NotePropertyName ZipSize -NotePropertyValue (Get-Item -LiteralPath $disks[$i].ZipPath).Length -Force
        $budget = $FloppyBytes - $extras - $pkSize
        if ($disks[$i].ZipSize -gt $budget) { $ok = $false }
    }
    if (-not $ok) { $shrink += [int]($FloppyBytes * 0.03); "a zip overshot its floppy, repacking with {0:N0} bytes less per disk" -f $shrink }
} while (-not $ok -and $shrink -lt $FloppyBytes / 2)
if (-not $ok) { throw "could not pack the set onto floppies" }
if (Test-Path $work) { try { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction Stop } catch { Clear-Dir $work } }
# stale DISKn folders from an earlier run with more disks
foreach ($old in Get-ChildItem -LiteralPath $Dist -Directory -Filter "$Name-DISK*") {
    if ([int]($old.Name -replace '^.*DISK', '') -gt $disks.Count) { try { Remove-Item -LiteralPath $old.FullName -Recurse -Force -ErrorAction Stop } catch { Clear-Dir $old.FullName } }
}
$madeBy = if ($pkDone) { 'PKZIP 2.50 for DOS (tested with PKUNZIP -t)' } else { '.NET deflate, PKZIP 2.04g compatible' }

# ---------- disk extras: EXTRACT.BAT, README.TXT, PKUNZIP ----------
$nd = $disks.Count
for ($i = 0; $i -lt $nd; $i++) {
    $n = $i + 1
    $d = $disks[$i]
    $diskDir = Split-Path $d.ZipPath -Parent
    $doneLine = if ($n -eq $nd) { "echo All done. Now:  C:   then   CD \DARKV   then   DARKV" } else { "echo Now run EXTRACT from the next disk." }
    $bat = @"
@echo off
rem Dark Visions - 486 test build - disk $n of $nd
rem Unpacks $($d.ZipName) into $TargetDir (edit the two lines below to change it)
if not exist $TargetDir\NUL md $TargetDir
echo Unpacking Dark Visions disk $n of $nd to $TargetDir ...
pkunzip -o $($d.ZipName) $TargetDir\
if errorlevel 1 goto fail
echo Disk $n of $nd unpacked.
$doneLine
goto end
:fail
echo PKUNZIP failed or is not on this disk / in the PATH.
echo Put PKUNZIP.EXE (PKZIP 2.04g or newer) in the PATH and run EXTRACT again.
:end
"@
    Write-Dos (Join-Path $diskDir 'EXTRACT.BAT') $bat
    $list = ($d.Files | Sort-Object Name | ForEach-Object { $_.Name }) -join ' '
    $pkLine = if ($pkSize -gt 0) { "  PKUNZIP.EXE     the unpacker (PKZIP 2.50 for DOS)`n" } else { "" }
    $install = if ($nd -eq 1) { "INSTALL`n  A:`n  EXTRACT`n" } else { "INSTALL (all $nd disks, any order)`n  A:`n  EXTRACT`n  (swap disks and run EXTRACT on each one)`n" }
    $readme = @"
DARK VISIONS - 486 TEST BUILD - DISK $n OF $nd   (packed $(Get-Date -Format 'yyyy-MM-dd'))
==========================================================

WHAT IS ON THIS DISK
$("  {0,-15} {1}, {2} files" -f $d.ZipName, $madeBy, $d.Files.Count)
  EXTRACT.BAT     unpacks it into $TargetDir
  README.TXT      this file
$pkLine
$install  C:
  CD \DARKV
  DARKV

  PKUNZIP.EXE must be on the disk or in the PATH. To check a disk:  PKUNZIP -t $($d.ZipName)

WHAT TO LOOK AT ON THE 486
  - Start-up: the tenthplay logo should appear for 2 seconds in 640x480x256 (VESA).
    On a card without VESA it shows in 320x200 instead. Any key skips it.
  - In the game press TAB for the full instruction manual at 800x600. The cover
    shows on its own; inside pages show with the next page peeking at the edge.
    Left/Up/PgUp = previous, Right/Down/PgDn = next, Home/End = first/last,
    TAB or ESC = back to the game. Mouse: click the left half = previous page,
    the right half = next. Each turn fades through black.
  - Please note the manual comes up at 800x600 and every page reads clearly, and
    that the room comes back cleanly after closing it (and after reopening).
  - Needs a mouse driver for the mouse (DARKV.BAT loads MOUSE.COM). EMS is not needed.
  - Settings live in DARK.INI (logo=0 turns the logo off, mouse=0 disables the mouse).

IF THE LOGO OR THE MANUAL IS NOT 640x480
  The game writes VGA.LOG in C:\DARKV only when the 640x480 mode is refused, and
  MANOK.LOG each time the manual opens (page count, free memory). If anything looks
  wrong, run the game, open the manual with TAB, then COPY C:\DARKV\*.LOG A:.
  Also run, from C:\DARKV:
    UGLTEST        the mode ladder on its own      -> UGLTEST.LOG
    UGLTESTD       same, debug graphics library    -> UGLTEST.LOG + UGL.LOG
  then copy the logs to the floppy:   COPY C:\DARKV\*.LOG A:
  and bring the disk back. A VESA driver such as UNIVBE / SciTech Display
  Doctor loaded before the game is the usual cure for an old VESA BIOS.

FILES ON THIS DISK
  $list
"@
    Write-Dos (Join-Path $diskDir 'README.TXT') $readme
    if ($pkSize -gt 0) { Copy-Item -LiteralPath $PkUnzip -Destination (Join-Path $diskDir 'PKUNZIP.EXE') }
    $onDisk = (Get-ChildItem -LiteralPath $diskDir -File | Measure-Object -Property Length -Sum).Sum
    "disk {0}: {1} ({2:N0} bytes, {3} files) + extras = {4:N0} of {5:N0} bytes -> {6}" -f $n, $d.ZipName, $d.ZipSize, $d.Files.Count, $onDisk, $FloppyBytes, $diskDir
}
if ($pkSize -eq 0) { "note: no PKUNZIP.EXE included (pass -PkUnzip <path>); the 486 needs PKUNZIP 2.04g or newer in its PATH" }
