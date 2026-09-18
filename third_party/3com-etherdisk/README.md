# 3Com EtherDisk 4.3 for the EtherLink III (3C509 / 3C509B)

`3com-etherdisk-4-3.zip` is the 1995 3Com EtherDisk 4.3 driver diskette for the
EtherLink III ISA family, downloaded 2026-09-16 (3Com no longer exists; this is
the diskette image as archived by the retro-computing community). Files used:

| File | What |
| --- | --- |
| `3C5X9CFG.EXE` + `3C5X9ENG.HLP` | configuration + diagnostics program (`DIAG\INSTRUCT.TXT` = its reference) |
| `PNPDSABL.BAT` | 3Com's "turn Plug and Play off" batch (`/PNPRST`, `CONFIGURE /PNP:DISABLED`) |
| `PKTDVR\3C5X9PD.COM` | the packet driver (class 1), `3C5X9PD 0x60`; `-u` unloads it |

The 486 has a 3C509B-TPO (10BASE-T only, no PnP BIOS). `src\tools\net486.ps1 disk`
copies these onto the `dist\NET486` floppy together with mTCP.
