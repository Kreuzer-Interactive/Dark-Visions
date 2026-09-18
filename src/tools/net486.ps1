<#
.SYNOPSIS
  net486.ps1 - talk to the Dark Visions 486 over the LAN (3Com 3C509B + mTCP FTP server).

.DESCRIPTION
  The 486 runs mTCP FTPSRV inside SERVE.BAT (see the disk verb). This script is the PC side:

    disk                    build dist\NET486 = the one-floppy setup payload for the 486 (3Com
                            config tool + packet driver, mTCP tools, MTCP.CFG, FTPPASS.TXT,
                            NETINST/CFGNIC/NET/SERVE batches, README.TXT). Copy it onto a floppy.
    set-host <ip|name>      remember the 486's address (what DHCP printed on the 486)
    ping                    is the FTP server answering?
    ls [dir]                directory listing (default /drive_c/darkv/)
    push [-Source d|file]   upload what changed since the last push (default source dist\DV486,
                            the flat set that pack486.ps1 makes; -Pack rebuilds it first; -All
                            re-sends everything). Files land in -Dest (default /drive_c/darkv).
    pull <remote> [-To d]   download one file (e.g. VGA.LOG, or /drive_c/net/FTPSRV.LOG)
    run [-Job "..."|-JobFile f] [-Wait]
                            upload C:\NET\JOB.BAT and tell the server to quit: SERVE.BAT runs the
                            job (default: start the game) and restarts the server afterwards.
                            -Wait blocks until the server is back (the job finished).
    quit                    restart the server with an empty job (re-reads MTCP.CFG/FTPPASS.TXT)
    who | stats | diskfree  the server's SITE commands
    help

  DOS paths are written mTCP style: /drive_c/darkv/GAME.EXE. Transfers use curl.exe (built into
  Windows 10/11); the control-channel commands use a small FTP client in this script.

.EXAMPLE
  .\net486.ps1 disk                          # build the floppy folder dist\NET486
  .\net486.ps1 set-host 10.10.1.123          # once, after DHCP on the 486 printed the address
  .\net486.ps1 push -Pack                    # pack486 -NoZip, then upload the changed files
  .\net486.ps1 run -Wait                     # start the game on the 486, return when it exits
  .\net486.ps1 pull VGA.LOG                  # fetch C:\DARKV\VGA.LOG into dist\.net486\pulled
  .\net486.ps1 run -Job "cd \darkv;ugltest" -Wait; .\net486.ps1 pull UGLTEST.LOG
#>
param(
    [Parameter(Position = 0)][string]$Verb = 'help',
    [Parameter(Position = 1)][string]$Arg = '',
    [string]$Target = '',
    [int]$Port = 21,
    [string]$User = 'claude',
    [string]$Password = 'dv486',
    [string]$Source = '',
    [string]$Dest = '/drive_c/darkv',
    [string]$To = '',
    [string]$Job = '',
    [string]$JobFile = '',
    [string]$LimitRate = '',
    [int]$WaitMinutes = 60,
    [int]$NicIrq = 10,
    [string]$NicIo = '300',
    [switch]$All,
    [switch]$Pack,
    [switch]$Wait,
    [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dist = Join-Path $repo 'dist'
$state = Join-Path $dist '.net486'
if (-not (Test-Path -LiteralPath $state)) { New-Item -ItemType Directory -Path $state -Force | Out-Null }
$hostFile = Join-Path $state 'host.txt'
$ascii = [System.Text.Encoding]::ASCII
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
if (-not (Test-Path -LiteralPath $curl)) { $curl = 'curl.exe' }

function Write-Dos([string]$path, [string]$text) {
    # DOS text: CRLF, ASCII
    [System.IO.File]::WriteAllText($path, (($text -replace "`r?`n", "`r`n").TrimEnd() + "`r`n"), $ascii)
}

# ---------------------------------------------------------------- FTP control channel
function Read-FtpReply($ftp) {
    $lines = @()
    while ($true) {
        $l = $ftp.Reader.ReadLine()
        if ($null -eq $l) { throw 'the server closed the connection' }
        $lines += $l
        if ($l -match '^(\d{3}) ') { return [pscustomobject]@{ Code = [int]$matches[1]; Text = ($lines -join "`n") } }
    }
}
function Send-Ftp($ftp, [string]$cmd) { $ftp.Writer.WriteLine($cmd); return Read-FtpReply $ftp }
function Open-Ftp([string]$h, [int]$p, [string]$u, [string]$pw, [int]$timeoutMs = 5000) {
    $c = New-Object System.Net.Sockets.TcpClient
    $ar = $c.BeginConnect($h, $p, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne($timeoutMs)) { $c.Close(); throw "no answer from ${h}:$p (is SERVE running on the 486?)" }
    $c.EndConnect($ar)
    $s = $c.GetStream(); $s.ReadTimeout = 20000
    $r = New-Object System.IO.StreamReader($s, $ascii)
    $w = New-Object System.IO.StreamWriter($s, $ascii); $w.NewLine = "`r`n"; $w.AutoFlush = $true
    $ftp = [pscustomobject]@{ Client = $c; Reader = $r; Writer = $w }
    $x = Read-FtpReply $ftp
    if ($x.Code -ne 220) { throw "unexpected greeting: $($x.Text)" }
    $x = Send-Ftp $ftp "USER $u"
    if ($x.Code -eq 331) { $x = Send-Ftp $ftp "PASS $pw" }
    if ($x.Code -ne 230) { $c.Close(); throw "login as $u failed: $($x.Text)" }
    return $ftp
}
function Close-Ftp($ftp) {
    try { $ftp.Writer.WriteLine('QUIT'); Start-Sleep -Milliseconds 100 } catch {}
    try { $ftp.Client.Close() } catch {}
}
function Test-Port([string]$h, [int]$p, [int]$timeoutMs = 2000) {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $c.BeginConnect($h, $p, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($timeoutMs)) { return $false }
        $c.EndConnect($ar)
        return $true
    } catch { return $false } finally { $c.Close() }
}

# ---------------------------------------------------------------- helpers
function Get-Target {
    if ($Target) { return $Target }
    if (Test-Path -LiteralPath $hostFile) { $t = (Get-Content -LiteralPath $hostFile -Raw).Trim(); if ($t) { return $t } }
    foreach ($n in 'dv486', 'DV486') { try { if ([System.Net.Dns]::GetHostAddresses($n).Count -gt 0) { return $n } } catch {} }
    throw "I do not know the 486's address yet. NET.BAT (DHCP) prints it on the 486; then run:  net486.ps1 set-host <address>"
}
function ConvertTo-RemotePath([string]$p) {
    if (-not $p) { return $Dest }
    $p = $p -replace '\\', '/'
    if ($p -match '^[A-Za-z]:') { $p = '/drive_' + $p.Substring(0, 1).ToLower() + $p.Substring(2) }   # C:\NET\X -> /drive_c/NET/X
    if (-not $p.StartsWith('/')) { $p = $Dest.TrimEnd('/') + '/' + $p }
    return $p
}
function Invoke-Curl([string[]]$curlArgs) {
    $base = @('--silent', '--show-error', '--disable-epsv', '--connect-timeout', '10', '--user', "${User}:${Password}")
    if ($LimitRate) { $base += @('--limit-rate', $LimitRate) }
    & $curl @base @curlArgs
    $script:curlExit = $LASTEXITCODE
}
function Get-Sha1([string]$path) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $fs = [System.IO.File]::OpenRead($path)
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '') } finally { $fs.Dispose() }
}
function Get-StateFile([string]$h) { return Join-Path $state ("pushed-" + ($h -replace '[^A-Za-z0-9]', '_') + ".json") }
function Read-State([string]$h) {
    $f = Get-StateFile $h
    $m = @{}
    if (Test-Path -LiteralPath $f) {
        $o = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
        foreach ($p in $o.PSObject.Properties) { $m[$p.Name] = @{ sha1 = $p.Value.sha1; size = [long]$p.Value.size } }
    }
    return $m
}
function Write-State([string]$h, $m) {
    $o = New-Object PSObject
    foreach ($k in ($m.Keys | Sort-Object)) { $o | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ sha1 = $m[$k].sha1; size = $m[$k].size }) }
    $o | ConvertTo-Json | Set-Content -LiteralPath (Get-StateFile $h) -Encoding ASCII
}

# ---------------------------------------------------------------- verbs
function Do-Disk {
    $mt = Get-ChildItem -LiteralPath (Join-Path $repo 'third_party\mtcp') -Filter 'mTCP_*.zip' | Sort-Object Name | Select-Object -Last 1
    $ed = Get-ChildItem -LiteralPath (Join-Path $repo 'third_party\3com-etherdisk') -Filter '*.zip' | Select-Object -First 1
    if (-not $mt) { throw 'third_party\mtcp\mTCP_*.zip is missing' }
    if (-not $ed) { throw 'third_party\3com-etherdisk\*.zip is missing' }
    $ex = Join-Path $state 'extract'
    if (Test-Path -LiteralPath $ex) { Remove-Item -LiteralPath $ex -Recurse -Force }
    Expand-Archive -LiteralPath $mt.FullName -DestinationPath (Join-Path $ex 'mtcp') -Force
    Expand-Archive -LiteralPath $ed.FullName -DestinationPath (Join-Path $ex 'ed') -Force
    $out = Join-Path $dist 'NET486'
    if (Test-Path -LiteralPath $out) { Get-ChildItem -LiteralPath $out -Force | Remove-Item -Recurse -Force } else { New-Item -ItemType Directory -Path $out | Out-Null }
    $take = @(
        @('mtcp\dhcp.exe', 'DHCP.EXE'), @('mtcp\ftpsrv.exe', 'FTPSRV.EXE'), @('mtcp\ping.exe', 'PING.EXE'),
        @('mtcp\pkttool.exe', 'PKTTOOL.EXE'), @('mtcp\nc.exe', 'NC.EXE'), @('mtcp\ftp.exe', 'FTP.EXE'),
        @('mtcp\sntp.exe', 'SNTP.EXE'), @('mtcp\htget.exe', 'HTGET.EXE'), @('mtcp\COPYING.TXT', 'COPYING.TXT'),
        @('ed\3C5X9CFG.EXE', '3C5X9CFG.EXE'), @('ed\3C5X9ENG.HLP', '3C5X9ENG.HLP'), @('ed\PNPDSABL.BAT', 'PNPDSABL.BAT'),
        @('ed\PKTDVR\3C5X9PD.COM', '3C5X9PD.COM'), @('ed\PKTDVR\3C5X9PD.DOC', '3C5X9PD.DOC'), @('ed\DIAG\INSTRUCT.TXT', 'INSTRUCT.TXT')
    )
    foreach ($t in $take) {
        $src = Join-Path $ex $t[0]
        if (-not (Test-Path -LiteralPath $src)) { throw "missing in the zip: $($t[0])" }
        Copy-Item -LiteralPath $src -Destination (Join-Path $out $t[1])
    }
    $mtcpVer = ($mt.Name -replace '^mTCP_', '' -replace '\.zip$', '')
    $today = Get-Date -Format 'yyyy-MM-dd'

    Write-Dos (Join-Path $out 'MTCP.CFG') @"
# mTCP configuration for the Dark Visions 486        C:\NET\MTCP.CFG
# NET.BAT sets MTCPCFG to this file. DHCP.EXE appends the IPADDR / NETMASK /
# GATEWAY / NAMESERVER / LEASE_TIME lines itself (and rewrites them each run).

# where the packet driver is (3C5X9PD 0x60)
packetint 0x60
# full-size Ethernet frames = faster file transfers
mtu 1500
# name we ask the router for; the PC may be able to reach us as "dv486"
hostname DV486
dhcp_lease_request_secs 86400
dhcp_lease_threshold 1800

# FTP server (FTPSRV.EXE) - the PC logs in with the user in FTPPASS.TXT
ftpsrv_password_file C:\NET\FTPPASS.TXT
ftpsrv_log_file C:\NET\FTPSRV.LOG
ftpsrv_session_timeout 600
ftpsrv_clients 3
# let the PC overwrite files (default is to refuse)
ftpsrv_clobber_files true
ftpsrv_exclude_drives AB
# biggest buffers: a modern PC floods a 486 otherwise
ftpsrv_filebuffer_size 16
ftpsrv_tcpbuffer_size 16
ftpsrv_packets_per_poll 2
"@

    Write-Dos (Join-Path $out 'FTPPASS.TXT') @"
# mTCP FTPSRV users:  userid password sandbox upload permissions
# (mTCP manual, "Setting up the password file"). Change the password here
# and pass -Password to net486.ps1 on the PC. Permissions: dele mkd rmd rnfr
# stor appe stou sitequit  (sitequit = the PC may stop/restart the server).
$User $Password [none] [any] dele mkd rmd rnfr stor appe stou sitequit
"@

    Write-Dos (Join-Path $out 'NETINST.BAT') @"
@echo off
rem Dark Visions 486 - copy the network tools from this disk to C:\NET
if not exist C:\NET\NUL md C:\NET
copy *.* C:\NET > nul
echo.
echo Copied to C:\NET.   Next:   C:   CD \NET   CFGNIC      (one-time card setup)
echo The whole procedure is in README.TXT - open it with   EDIT README.TXT
"@

    Write-Dos (Join-Path $out 'CFGNIC.BAT') @"
@echo off
rem Dark Visions 486 - ONE-TIME setup of the 3Com 3C509B. Plain DOS, no network
rem drivers loaded. Lines 1+2 are 3Com's PNPDSABL: wake the card from its Plug and
rem Play wait, then turn PnP off. Line 3 sets I/O ${NicIo}h, IRQ $NicIrq, twisted pair.
rem Another IRQ needed (3,5,7,9,10,11,12,15)? Change /INT:$NicIrq - nothing else changes.
3C5X9CFG /PNPRST
3C5X9CFG CONFIGURE /PNP:DISABLED
3C5X9CFG CONFIGURE /IOBASE:$NicIo /INT:$NicIrq /XCVR:TP /OPTIMIZE:DOS
echo.
echo If the last message was "successfully configured": power the PC OFF, wait
echo 10 seconds, power it ON, boot to DOS, then   CD \NET   and run   NET
echo Card not found? See README.TXT. Full-screen tool any time: 3C5X9CFG
"@

    Write-Dos (Join-Path $out 'NET.BAT') @"
@echo off
rem Dark Visions 486 - bring the network up: packet driver + address by DHCP.
rem Run after every boot (or CALL C:\NET\NET.BAT from AUTOEXEC.BAT).
rem Tight on conventional memory? Use  LH C:\NET\3C5X9PD 0x60  (needs UMBs).
if "%NETUP%"=="1" goto cfg
C:\NET\3C5X9PD 0x60
set NETUP=1
:cfg
set MTCPCFG=C:\NET\MTCP.CFG
C:\NET\DHCP -retries 3 -timeout 15
if errorlevel 1 goto dhcpfail
echo.
echo Network is up. Tell the PC the IPADDR shown above (net486 set-host ...),
echo then run   SERVE   to let the PC copy files here.
goto end
:dhcpfail
echo.
echo DHCP got no answer. Check the link light on the card and the cable, that
echo the packet driver printed the card's MAC address, then run NET again.
echo Diagnostics:  PKTTOOL STATS 0x60     3C5X9CFG (Tests: Run Tests)
:end
"@

    Write-Dos (Join-Path $out 'SERVE.BAT') @"
@echo off
rem Dark Visions 486 - run the mTCP FTP server for the PC, in a loop.
rem The PC uploads files into C:\DARKV. It can also upload C:\NET\JOB.BAT and
rem send SITE QUIT: the server exits, JOB.BAT runs (usually: start the game),
rem and when the job is over the server starts again on its own.
rem Ctrl-C at the server = stop; then any key restarts it, Ctrl-C again quits.
if "%MTCPCFG%"=="" call C:\NET\NET.BAT
:loop
C:
cd \NET
if exist C:\NET\JOB.BAT del C:\NET\JOB.BAT
rem renew the DHCP lease (24 h) each time round, mTCP refuses to start on a stale one
C:\NET\DHCP -retries 2 -timeout 10
C:\NET\FTPSRV
if exist C:\NET\JOB.BAT goto job
echo.
echo Server stopped. Press any key to start it again, or Ctrl-C to quit to DOS.
pause > nul
goto loop
:job
if exist C:\NET\RUN.BAT del C:\NET\RUN.BAT
ren C:\NET\JOB.BAT RUN.BAT
echo Running the job from the PC ...
call C:\NET\RUN.BAT
echo Job finished - starting the server again.
goto loop
"@

    Write-Dos (Join-Path $out 'README.TXT') @"
DARK VISIONS 486 - NETWORK SETUP DISK                    (built $today)
======================================================================
Puts the 3Com EtherLink III card (3C509B-TPO, 10BASE-T) to work under plain
DOS with the mTCP TCP/IP tools, so the PC can copy game builds to this
machine over the LAN and start them, instead of walking floppies over.

WHAT IS ON THIS DISK
  3C5X9CFG.EXE  3Com configuration + diagnostics program (EtherDisk 4.3)
  3C5X9ENG.HLP  its help file (F1)          INSTRUCT.TXT  its full reference
  3C5X9PD.COM   3Com packet driver          3C5X9PD.DOC   its notes
  PNPDSABL.BAT  3Com's own "turn Plug and Play off" batch (CFGNIC does it)
  DHCP FTPSRV PING PKTTOOL NC FTP SNTP HTGET (.EXE)
                mTCP $mtcpVer by Michael Brutman, GPLv3 (COPYING.TXT)
  MTCP.CFG      mTCP settings: packet driver at int 0x60, FTP server options
  FTPPASS.TXT   FTP server user for the PC:  $User / $Password
  NETINST.BAT   copies everything to C:\NET
  CFGNIC.BAT    one-time card setup: PnP off, I/O ${NicIo}h, IRQ $NicIrq, twisted pair
  NET.BAT       loads the packet driver, gets an address by DHCP
  SERVE.BAT     runs the FTP server in a loop (see HOW SERVE WORKS)

ONE-TIME SETUP  (plain DOS - exit Windows first)
  1. Cable from the card to the switch or router. Any normal patch cable.
  2. A:   then   NETINST                -> the tools are now in C:\NET
  3. C:   then   CD \NET   then   CFGNIC
     The last line should read: "The 3C5X9 adapter, adapter number 1,
     was successfully configured".   "Cannot find adapter"? -> see NOTES.
  4. Power the PC OFF, wait 10 seconds, power ON, boot to DOS. (3Com asks
     for a real power cycle after the Plug and Play change.)
  5. CD \NET   then   NET
     3C5X9PD prints the card's MAC address (compare with the sticker on the
     card), I/O $NicIo, IRQ $NicIrq. DHCP prints the address the router gave us,
     for example:   IPADDR 10.10.1.123
     Tell the PC that number:   net486.ps1 set-host 10.10.1.123
  6. PING 10.10.1.1     four replies from the router = the network works
     PING 10.10.1.200   the PC (its Windows firewall may ignore pings)
  7. SERVE    -> "mTCP FtpSrv ... Press [Ctrl-C] or [Alt-X] to end the server"
     Leave it. The PC can now push files into C:\DARKV and start the game.

EVERY BOOT AFTER THAT
  CD \NET   then   SERVE          (SERVE runs NET first when needed)
  Optional: put   CALL C:\NET\NET.BAT   at the end of AUTOEXEC.BAT.

HOW SERVE WORKS
  FTPSRV runs until it is told to stop. The PC uploads C:\NET\JOB.BAT and
  sends SITE QUIT: the server exits, JOB.BAT runs (for example: CD \DARKV
  and DARKV), and when that is over the server starts again by itself.
  So: the PC says "run", the game appears on this screen, you play, you
  quit the game, the server is back. Ctrl-C at the server stops it; then
  any key restarts it and Ctrl-C again drops to DOS.

IF SOMETHING DOES NOT WORK
  no link light on the card   cable, other switch port. 10BASE-T only: some
                               2.5G/10G switches refuse 10 Mbit - use a plain
                               gigabit switch port or the router itself
  packet driver: no MAC/wrong  card not configured (CFGNIC) or no power cycle
  DHCP times out               link light? PKTTOOL STATS 0x60 shows packets
                               in/out; "in" stays 0 = wrong IRQ or no link
  3C5X9CFG full-screen         Install > Configure Adapter shows the settings;
                               Tests > Run Tests checks the card and the link
  "lease expires" warning       the DHCP lease lasts 24 h; SERVE renews it on
                               every loop, otherwise run NET again
  Out of environment space     add to CONFIG.SYS:
                               SHELL=C:\DOS\COMMAND.COM C:\DOS /E:1024 /P
  game short of memory         NET.BAT: LH C:\NET\3C5X9PD 0x60 (needs UMBs);
                               3C5X9PD -u unloads the driver (~10 KB back)

NOTES
  - "Cannot find adapter" in CFGNIC: run PNPDSABL (3Com's version of the same
    two steps), power-cycle, run CFGNIC again. A late-486 board with a Plug
    and Play BIOS: set "PnP OS installed: No" and try again.
  - IRQ $NicIrq and I/O ${NicIo}h are free on a typical 486. If another card uses
    IRQ $NicIrq, change /INT: in CFGNIC.BAT (3,5,7,9,10,11,12,15); the packet
    driver reads the settings from the card, so nothing else changes.
  - Windows 3.1 needs none of this; run the game and SERVE from plain DOS.
  - Passwords travel in the clear; this is for the home LAN only.
"@

    $items = Get-ChildItem -LiteralPath $out -File
    $total = ($items | Measure-Object -Property Length -Sum).Sum
    $items | Sort-Object Name | ForEach-Object { "{0,-13} {1,9:N0}" -f $_.Name, $_.Length }
    "{0} files, {1:N0} bytes -> {2}" -f $items.Count, $total, $out
    if ($total -le 1457664) { "fits on one 1.44 MB floppy ({0:N0} bytes free). Copy the folder's contents onto the disk." -f (1457664 - $total) }
    else { Write-Warning "too big for one floppy by $($total - 1457664) bytes" }
}

function Do-Push {
    $h = Get-Target
    if ($Pack) { & (Join-Path $PSScriptRoot 'pack486.ps1') -NoZip }
    $src = $Source
    if (-not $src) { $src = Join-Path $dist 'DV486' }
    $src = (Resolve-Path $src).Path
    if (Test-Path -LiteralPath $src -PathType Leaf) { $dir = Split-Path $src -Parent; $files = @(Get-Item -LiteralPath $src) }
    else { $dir = $src; $files = @(Get-ChildItem -LiteralPath $src -File | Where-Object { $_.Name -notlike '*.LOG' }) }
    if ($files.Count -eq 0) { throw "nothing to push in $src" }
    $st = Read-State $h
    $todo = @()
    $sum = 0
    foreach ($f in $files) {
        $name = $f.Name.ToUpperInvariant()
        if ($name.Length -gt 12 -or $name -notmatch '^[A-Z0-9_\-!@#$%^&(){}`~]{1,8}(\.[A-Z0-9_\-!@#$%^&(){}`~]{1,3})?$') { Write-Warning "$name is not an 8.3 name, skipped"; continue }
        $sha = Get-Sha1 $f.FullName
        if ($All -or -not $st.ContainsKey($name) -or $st[$name].sha1 -ne $sha) { $todo += [pscustomobject]@{ File = $f; Name = $name; Sha1 = $sha }; $sum += $f.Length }
    }
    if ($todo.Count -eq 0) { "nothing changed since the last push to $h ($($files.Count) files known). Use -All to resend."; return }
    "pushing {0} of {1} files ({2:N0} bytes) to {3}{4}/" -f $todo.Count, $files.Count, $sum, $h, $Dest
    $url = "ftp://${h}:${Port}$($Dest.TrimEnd('/'))/"
    $t0 = Get-Date
    Push-Location $dir
    try {
        # one curl per batch keeps one control connection; the 486 logs in once per batch
        $batch = @(); $i = 0
        foreach ($t in $todo) {
            $batch += $t.File.Name; $i++
            if ($batch.Count -eq 40 -or $i -eq $todo.Count) {
                $spec = if ($batch.Count -eq 1) { $batch[0] } else { '{' + ($batch -join ',') + '}' }
                Invoke-Curl @('--ftp-create-dirs', '--upload-file', $spec, $url)
                if ($script:curlExit -ne 0) { throw "curl failed (exit $script:curlExit) while uploading $($batch -join ' ')" }
                $batch = @()
            }
        }
    } finally { Pop-Location }
    $secs = ((Get-Date) - $t0).TotalSeconds
    "sent in {0:N0} s ({1:N0} KB/s)" -f $secs, ($sum / 1024 / [Math]::Max($secs, 0.1))
    if ($NoVerify) { foreach ($t in $todo) { $st[$t.Name] = @{ sha1 = $t.Sha1; size = $t.File.Length } }; Write-State $h $st; return }
    $ftp = Open-Ftp $h $Port $User $Password
    try {
        $x = Send-Ftp $ftp "CWD $Dest"; if ($x.Code -ne 250) { throw "CWD $Dest failed: $($x.Text)" }
        Send-Ftp $ftp 'TYPE I' | Out-Null
        $bad = 0
        foreach ($t in $todo) {
            $x = Send-Ftp $ftp "SIZE $($t.Name)"
            $remote = -1
            if ($x.Code -eq 213 -and $x.Text -match '^213 (\d+)') { $remote = [long]$matches[1] }
            if ($remote -eq $t.File.Length) { $st[$t.Name] = @{ sha1 = $t.Sha1; size = $t.File.Length } }
            else { $bad++; Write-Warning ("{0}: remote size {1}, local {2}" -f $t.Name, $remote, $t.File.Length) }
        }
    } finally { Close-Ftp $ftp }
    Write-State $h $st
    if ($bad) { throw "$bad file(s) did not verify; run push again" }
    "verified $($todo.Count) file(s) by size on the 486"
}

function Do-Pull {
    $h = Get-Target
    if (-not $Arg) { throw 'pull needs a remote file, e.g.  pull VGA.LOG   or   pull /drive_c/net/FTPSRV.LOG' }
    $rp = ConvertTo-RemotePath $Arg
    $dirTo = $To
    if (-not $dirTo) { $dirTo = Join-Path $state 'pulled' }
    if (-not (Test-Path -LiteralPath $dirTo)) { New-Item -ItemType Directory -Path $dirTo -Force | Out-Null }
    $local = Join-Path $dirTo (Split-Path $rp -Leaf)
    Invoke-Curl @('--output', $local, "ftp://${h}:${Port}$rp")
    if ($script:curlExit -ne 0) { throw "curl failed (exit $script:curlExit) fetching $rp" }
    "{0} -> {1} ({2:N0} bytes)" -f $rp, $local, (Get-Item -LiteralPath $local).Length
}

function Do-Ls {
    $h = Get-Target
    $rp = ConvertTo-RemotePath $Arg
    if (-not $rp.EndsWith('/')) { $rp += '/' }
    Invoke-Curl @("ftp://${h}:${Port}$rp")
    if ($script:curlExit -ne 0) { throw "curl failed (exit $script:curlExit) listing $rp" }
}

function Do-Site([string]$cmd) {
    $h = Get-Target
    $ftp = Open-Ftp $h $Port $User $Password
    try { $x = Send-Ftp $ftp $cmd; $x.Text } finally { Close-Ftp $ftp }
}

function Do-Run([bool]$emptyJob) {
    $h = Get-Target
    if ($emptyJob) { $text = "@echo off`nrem restart requested by the PC`n" }
    elseif ($JobFile) { $text = Get-Content -LiteralPath $JobFile -Raw }
    elseif ($Job) { $text = "@echo off`n" + (($Job -split '\s*;\s*|\r?\n') -join "`n") + "`n" }
    else { $text = "@echo off`nC:`ncd \DARKV`ncall DARKV.BAT`n" }
    $tmp = Join-Path $state 'JOB.BAT'
    Write-Dos $tmp $text
    if (-not (Test-Port $h $Port)) { throw "the FTP server on $h is not answering; is SERVE running (or a job still running)?" }
    Invoke-Curl @('--upload-file', $tmp, "ftp://${h}:${Port}/drive_c/net/JOB.BAT")
    if ($script:curlExit -ne 0) { throw "curl failed (exit $script:curlExit) uploading JOB.BAT" }
    $ftp = Open-Ftp $h $Port $User $Password
    $reply = ''
    try { $x = Send-Ftp $ftp 'SITE QUIT'; $reply = $x.Text } catch { $reply = "(server closed the connection: $($_.Exception.Message))" } finally { try { $ftp.Client.Close() } catch {} }
    "job uploaded, SITE QUIT sent: $reply"
    if ($emptyJob) { "the server restarts by itself in a few seconds" }
    else { "the 486 is running the job now:"; ($text -split "`n" | Where-Object { $_ -and $_ -notmatch '^@echo off' }) | ForEach-Object { "    $_" } }
    if (-not $Wait) { return }
    $t0 = Get-Date
    while ((Test-Port $h $Port 1000) -and ((Get-Date) - $t0).TotalSeconds -lt 40) { Start-Sleep -Seconds 1 }
    "server down, waiting for the job to finish (up to $WaitMinutes min) ..."
    while (-not (Test-Port $h $Port 1000)) {
        if (((Get-Date) - $t0).TotalMinutes -gt $WaitMinutes) { throw "gave up after $WaitMinutes minutes; the server is still down" }
        Start-Sleep -Seconds 3
    }
    "server is back after {0:N0} s - the job is done" -f ((Get-Date) - $t0).TotalSeconds
}

switch ($Verb.ToLowerInvariant()) {
    'disk' { Do-Disk }
    'set-host' { if (-not $Arg) { throw 'set-host needs an address' }; Set-Content -LiteralPath $hostFile -Value $Arg -Encoding ASCII; "486 = $Arg (saved in $hostFile)" }
    'ping' { $h = Get-Target; if (Test-Port $h $Port 3000) { "$h answers on port $Port (FTPSRV is up)" } else { "$h does not answer on port $Port" } }
    'ls' { Do-Ls }
    'push' { Do-Push }
    'pull' { Do-Pull }
    'run' { Do-Run $false }
    'quit' { Do-Run $true }
    'who' { Do-Site 'SITE WHO' }
    'stats' { Do-Site 'SITE STATS' }
    'diskfree' { $d = if ($Arg) { $Arg } else { 'C' }; Do-Site "SITE DISKFREE $d" }
    default { Get-Help $PSCommandPath -Detailed }
}
