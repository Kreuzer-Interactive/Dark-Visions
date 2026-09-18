# mTCP 2025-01-10 (DOS TCP/IP tools)

`mTCP_2025-01-10.zip` is the unmodified binary release of mTCP by Michael Brutman,
downloaded 2026-09-16 from the home page: http://www.brutman.com/mTCP/mTCP.html
(the PDF manual, `mTCP_2025-01-10.pdf`, is on the same page). License: GPLv3
(`COPYING.TXT` inside the zip).

Used by `src\tools\net486.ps1 disk` to build the 486 network-setup floppy
(`dist\NET486`): DHCP.EXE, FTPSRV.EXE, PING.EXE, PKTTOOL.EXE, NC.EXE, FTP.EXE,
SNTP.EXE, HTGET.EXE. The 486 runs FTPSRV (the FTP server); the PC pushes builds
into C:\DARKV with `net486.ps1 push`.
