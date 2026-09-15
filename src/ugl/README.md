# src/ugl - uGL 0.23b for the QB 4.5 build

Copied verbatim from `third_party/ugl/ugl023b.zip`:

- `UGL.LIB`  = `lib/release/qb/ugl.lib`  (release build, no checks - ship this)
- `UGLD.LIB` = `lib/debug/qb/ugld.lib`   (debug build: crash-safe, logs to UGL.LOG - use while developing)
- `*.BI`     = `inc/*.bi` (QB include files; only `UGL.BI` is needed for graphics, add `TMR.BI`/`MOUSE.BI`/`KBD.BI` per module)
- `stubs/`   = `lib/stubs/*.obj` (link a stub instead of a colour-depth module when trimming the lib)

The QB-target lib is NOT interchangeable with the VBDOS (`uglv`) or PDS (`uglp`) builds:
string arguments and the runtime hooks (`B$SETM` = SETMEM) differ per compiler.

Build rules (see `docs/ugl/README.md`): `SET INCLUDE=<this dir>` before BC so `'$INCLUDE: 'UGL.BI'`
resolves, and link with `/SEG:800` and `...+UGL.LIB` (or `UGLD.LIB`).

## Local patches (2026-09-13): VBE 1.2 cards (Cirrus GD-54xx on the 486)

Both `UGL.LIB` and `UGLD.LIB` carry two small binary patches in module `mdvbe.asm`
(source: `third_party/ugl/ugl023b.zip` -> `src/mods/mdvbe.asm`; OMF LEDATA checksums recomputed;
pristine copies in the zip; no assembler on this machine, so no source rebuild).

**1. Version check (the real bug).** `vbeCheck` compared the VBE version word with
`VBE_MIN_VER = 0120h`. VBE stores the version as major byte / minor byte, so 1.2 is `0102h` and the
check rejected every VBE 1.x BIOS - only VBE 2.0 cards (DOSBox-X's S3) ever passed. The 486's Cirrus
GD-54xx (VBE 1.2, 1 MB, mode 101h, working 06h/07h - see `docs/ugl/logs/486-cirrus-gd54xx-vga.log`)
therefore got 320x200 for the logo and the manual. The immediate is now `0102h`
(`26 81 7D 04 20 01` -> `... 02 01`; `UGL.LIB` 0x5F70, `UGLD.LIB` 0x616D). DOSBox-X
`machine=vesa_oldvbe` (VBE 1.2 emulation) reproduced the failure and now reaches 640x480 with 2 pages.

**2. Scanline fallback.** Routine `set_bps` sets the 1024-byte logical
scanline it needs for 640x480 with VBE function 06h subfunction 2 ("set in bytes"), which only exists
in VBE 2.0. The original code then did:

```
@@try_serv_00:  cmp al, 4Fh
                je  @@error        ; "service 02h supported??" -> give up
                ... mov bl, 0 / int 10h (VBE 1.2 "set in pixels")
```

so a VBE 1.2 BIOS that answers "function supported, call failed" (AL=4Fh, AH<>0) to subfunction 2
made every 640x480 mode fail, and the game fell back to 320x200 (first seen on the 486's Cirrus
GD5430/5434). The `je @@error` (`74 xx`) is now two NOPs, so subfunction 0 is always tried before
giving up. Patch offsets: `UGL.LIB` 0x60F4, `UGLD.LIB` 0x63FD. A BIOS with no working 06h at all still fails; the source tree's
`mdvbe_bugfix.asm` adds a CRTC-register fallback for that case but needs MASM (`ml`) to rebuild.
