# PKZIP 2.50 for DOS (shareware, PKWARE, 1999-03-01)

Copied 2026-09-13 from the user's `Downloads\pk` folder (the extracted PK250DOS package).
Used by `src/tools/pack486.ps1` to build the 486 floppy transfer archives: PKZIP.EXE runs
inside DOSBox-X to create the disk zips, PKUNZIP.EXE tests them and rides along on disk 1
so the 486 needs nothing else.

| File | Purpose |
|---|---|
| PKZIP.EXE | archiver (`pkzip -ex out.zip @list.txt` = maximum compression from a list file) |
| PKUNZIP.EXE | extractor / tester (`pkunzip -t x.zip`, `pkunzip -o x.zip C:\DARKV\`) |
| PKUNZJR.COM | tiny extract-only tool (2.9 KB) |
| ZIP2EXE.EXE | turns a zip into a self-extracting PKSFX .EXE |
| PKZIPFIX.EXE | archive repair |
| MANUAL.TXT, HINTS.TXT, ADDENDUM.TXT, WHATSNEW.TXT, LICENSE.TXT, ORDER.TXT, README.TXT, OMBUDSMN.ASP | PKWARE's docs and shareware notices |

Gotchas found in DOSBox-X (2026-09-13):
- There is no `-204` switch in this DOS version; passing it makes PKZIP hang silently. Plain `-ex` output
  is already readable by PKUNZIP 2.04g.
- Output redirection (`> file`) and EMS/XMS being present are fine.
- PKZIP's deflate is about 1% smaller than the .NET zip writer's on the game set.
