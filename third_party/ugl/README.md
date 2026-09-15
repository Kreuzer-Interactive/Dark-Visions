# uGL archives (pristine)

Upstream: **uGL** ("Useless Game Library") by Blitz and v1ctor (Andre Victor T. Vicentini),
a pure-x86-assembly VESA/EMS game graphics library for QuickBASIC 4.x, PDS 7.x, VBDOS and Borland C.
Later home: https://github.com/av1ctor/old-uGL

| File | What it is | Source |
|------|------------|--------|
| `ugl023b.zip` | uGL 0.23b, the last official release (27 Nov 2003). Prebuilt libs for **qb** (QB 4.x), pds, vbd, bc, release + debug, docs, examples, asm source. | Dropbox/Evernote note "uGL - graphic library for QuickBASIC" (tenthplay Confluence archive), also petesqbsite |
| `uGL024.zip` | uGL 0.24b work-in-progress snapshot of the GitHub repo (files dated 2020-11-04). Adds uglBlit*, palette fades (pal.bi), XMS DCs, 2DFX module. **Only a VBDOS lib (UGLV.LIB/QLB) is prebuilt** - no QB 4.5 build; rebuilding needs MASM 6 + dmake. | same note, GitHub av1ctor/old-uGL |

What the game build actually uses is copied out to `src/ugl/` (0.23b, QB 4.5 target).
Documentation and examples are extracted to `docs/ugl/`.
