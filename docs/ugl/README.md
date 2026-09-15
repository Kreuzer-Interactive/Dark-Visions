# uGL in Dark Visions - integration guide and quick reference

uGL ("Useless Game Library", by Blitz and v1ctor) is a pure-x86-asm VESA/EMS graphics library for
QuickBASIC 4.x, PDS, VBDOS and Borland C. It gives the QB45 game 640x480x256 (and other VESA modes),
multiple video pages, off-screen bitmaps in conventional memory or EMS, BMP loading, palette control,
fast masked sprite blits, timers, a keyboard ISR and a mouse module.

## What is in the repo

| Path | Contents |
|------|----------|
| `third_party/ugl/ugl023b.zip`, `uGL024.zip` | pristine archives (see the README there) |
| `src/ugl/` | **what the build uses**: `UGL.LIB` (0.23b release, QB 4.5 target), `UGLD.LIB` (0.23b debug), `*.BI` includes, `stubs/` |
| `src/tools/UGLTEST.BAS` + `ugltest.conf` | smoke test / template program (see "Proven build recipe") |
| `src/TPLOGO.BMP` | tenthplay logo, 640x480, 8-bit, own 256-colour palette (converted from darkv-bas `SRC/art/TP640.pcx`) |
| `src/TPLOG320.BMP` | tenthplay logo, 320x200, 8-bit (from darkv-bas `SRC/art/TP320.pcx`) - the mode 13h fallback art |
| `docs/ugl/ugl_man.html` / `ugl_man.txt` | the uGL manual (version 0.23; identical in 0.23b and 0.24) |
| `docs/ugl/chnglog-0.24.txt` | changelog incl. the 0.24 additions; `chnglog-0.23b.txt` = release history |
| `docs/ugl/readme-0.23b.txt` | upstream readme: library builder, EMS notes, the `/SEG` note, sound |
| `docs/ugl/arch.txt`, `dos.txt`, `v0.24-doc/2dfx.txt` | module docs (archives, DOS/file/mem routines, 2DFX effects) |
| `docs/ugl/annots-src-notes.txt` | author notes: DC alignment rules, EMS mapping limits, bank rules |
| `docs/ugl/examples/*.bas` | upstream QB examples (page flipping, BMP, palette, mouse, kbd, timer, sprites...) |
| `docs/ugl/v0.24-inc/*.bi` | 0.24 include files - API reference for the newer routines we do NOT have compiled for QB |

## Version choice (important)

* **0.23b (27 Nov 2003)** is the last official release and the only one with a prebuilt **QB 4.5** library
  (`lib/release/qb/ugl.lib`, `lib/debug/qb/ugld.lib`). That is what `src/ugl/` holds.
* **0.24b** (GitHub `av1ctor/old-uGL`, files dated 2020) adds `uglBlit*` (partial-source blits, i.e. sprite
  sheets), `pal.bi` fades (`uglPalFadeIn/Out`, `uglPalBestFit`), XMS DCs, an EMS emulator and the 2DFX
  alpha/blend module - but ships **only a VBDOS build** (`UGLV.LIB`). Building it for QB needs MASM 6 (`ml`)
  + dmake (`src/mk4qb.bat`). Not attempted; the darkv-bas repo used the VBDOS 0.24 lib.
* The per-compiler libs are not interchangeable: string arguments and runtime hooks (`B$SETM` = QB's SETMEM)
  differ. Always link the `qb` build with BC 4.5.

## Proven build recipe (2026-09-12, DOSBox-X + QB45 at C:\Code\TOOLS\qb45)

`src/tools/ugltest.conf` (DOSBox-X `[autoexec]`), condensed:

```
mount Q C:\Code\TOOLS\qb45
mount D C:\Code\Dark-Visions\src
set INCLUDE=D:\UGL                 ' so '$INCLUDE: 'UGL.BI' resolves from any module dir
Q:
BC D:\TOOLS\UGLTEST.BAS, D:\TOOLS\UGLTEST.OBJ, D:\TOOLS\UGLTEST.LST /O;
LINK /SEG:800 D:\TOOLS\UGLTEST.OBJ, D:\TOOLS\UGLTEST.EXE, D:\TOOLS\UGLTEST.MAP, BCOM45.LIB+D:\UGL\UGL.LIB;
```

* `/SEG:800` is required (uGL has far more segments than LINK's default 128 - "too many segments" otherwise).
* Swap `UGL.LIB` for `UGLD.LIB` during development: the debug build refuses bad handles, logs every
  init/shutdown step and every error to `UGL.LOG` in the current directory.
* For the game: add `+D:\UGL\UGL.LIB` to the existing `LINK ... QB.LIB;` line and `/SEG:800` in front.
  Only the modules a program references are pulled in (UGLTEST.EXE is 84 KB in total).
* Optional QB IDE quick library: `LINK /Q /SEG:800 UGL.LIB, UGL.QLB,, BQLB45.LIB;` then `QB /L UGL`.

### Smoke test results (UGLTEST.LOG, DOSBox-X svga_s3, cycles=max)

```
uglInit ok
video DC ok: xRes 640 yRes 480 bps 1024 pages 2 size 983040   <- VESA 640x480x8, logical width 1024, 2 pages = 960 KB VRAM
uglPutBMPEx tplogo.bmp: -1 (TRUE)                              <- 8-bit BMP drawn with its own palette (BMPOPT.NO332)
page0 pixels (0,0)=240 (centre)=253 (50,50)=240                <- exactly the indices in the source PCX
page1 pixels (10,10)=40 (centre)=200                           <- second page independent (uglClear + uglRectF)
60 vsync flips took .82 s                                      <- ~73 Hz with the two-phase retrace wait (SUB VSync)
page0 again (centre)=253                                       <- flipping back works
free far heap 533098 before and after                          <- uGL takes nothing from QB's far heap for video/BNK DCs
```

### Video-mode ladder (what UGLTEST does, and what the logo scene will do)

1. `uglSetVideoDC(UGL.8BIT, 640, 480, 2)` - VESA, two pages (needs >= 960 KB VRAM), art `TPLOGO.BMP`
2. `uglSetVideoDC(UGL.8BIT, 640, 480, 1)` - VESA, one page (480 KB, fits a 512 KB card)
3. `uglSetVideoDC(UGL.8BIT, 320, 200, 1)` - plain VGA mode 13h, needs neither VESA nor EMS, art `TPLOG320.BMP`
4. everything fails (no VGA at all) -> skip the scene, the CGA game is untouched

Proven in DOSBox-X on 2026-09-12 (one UGLTEST.LOG per run, kept in the session scratchpad):

| DOSBox-X setup | Rung reached | Notes |
|---|---|---|
| `machine=svga_s3`, auto VRAM | 640x480, 2 pages | bps 1024, 983040 bytes; 60 flips = 0.82 s |
| `machine=svga_s3`, `[video] vmemsize=1` (1 MB) | 640x480, 2 pages | 960 KB fits exactly |
| `machine=svga_s3`, `[video] vmemsize=0` (512 KB) | 640x480, 1 page | 2 pages refused; 491520 bytes used |
| `machine=svga_et4000`, `vmemsize=0` (512 KB) | 320x200 | DOSBox-X's ET4000 has no VESA BIOS at all (4F00h unanswered), so this is the no-VESA case, not a chip quirk |
| `machine=vgaonly` (no VESA) | 320x200 | `TPLOG320.BMP`, pixels match the PCX |
| `machine=vgaonly` + `[dos] ems=false` | 320x200 | `uglInit` still succeeds without EMS |
| `machine=svga_s3` + `[dos] ems=false` | 640x480, 2 pages | EMS is not needed for any rung (2026-09-13) |
| `machine=vesa_oldvbe` (VBE 1.2) | 640x480, 2 pages | only after the version-check patch; the pristine lib gets 320x200 here, like the 486 |

Scenario conf keys: `[dosbox] machine=...`, `[video] vmemsize=0|1` (`-1` = auto, which ignores `vmemsizekb`),
`[dos] ems=false`. Note 320x200 has 1:1.2 pixels on a 4:3 monitor, so the 320 art is a separate export, not a downscale.

## Core concepts

* Every surface is a **DC** (device context) addressed by a **LONG handle**. `uglSetVideoDC` returns the
  video DC (VRAM, one DC covering all pages); `uglNew(UGL.MEM|UGL.EMS, UGL.8BIT, w, h)` makes off-screen DCs.
  `uglNewBMP` loads a BMP straight into a new DC. All drawing routines take any DC as source/destination.
* `uglInit` once; `uglRestore` (back to text mode) + `uglEnd` before the game continues in CGA
  (`SCREEN 1`). If `uglInit` or `uglSetVideoDC` returns 0, just skip the VGA scene.
* **Pages**: `uglSetWrkPage n` = where drawing to the video DC lands; `uglSetVisPage n` = what is shown.
  Draw on the hidden page, wait for retrace, flip.
* **Palette**: 8-bit modes start with a fixed 3-3-2 palette; `uglColor(UGL.8BIT, r, g, b)` returns the 332
  index. For real art set your own palette with `uglPalSetBuff 0, 256, pal(0)` (`tRGB` array, components
  0-255, NOT 0-63) and load BMPs with `BMPOPT.NO332` so their indices are kept. The smoke test reads the
  palette straight out of the BMP file (offset 55, 256 x BGRA) - see UGLTEST.BAS.
* **Masked blits** (`uglPutMsk`) skip RGB (255,0,255); in an 8-bit DC that is index 227 (= 332 code of magenta).
  `BMPOPT.MASK` on load converts that colour to the mask. Verify with a custom palette before relying on it.
* **Memory**: MEM DCs come out of DOS memory via SETMEM (QB's far heap shrinks accordingly); EMS DCs need
  EMM386/EMS (DOSBox-X: `ems=true`, on). A 640x480x8 image is 300 KB - use EMS or draw BMPs directly to
  the video DC (`uglPutBMPEx video, x, y, file, opt`) as UGLTEST does; sprites/small buffers fit in MEM.
* **Timing**: `WAIT &H3DA, 8` alone can return immediately if you are already inside the retrace
  (the smoke test's 60 flips took "0 s"). Wait for the retrace to END first: `WAIT &H3DA, 8, 8: WAIT &H3DA, 8`.
  QB `TIMER` (55 ms) is fine for holds; uGL's `tmrInit` reprograms the PIT - do not mix with PLAY/SOUND, and
  `tmrEnd` before returning to the game.
* `kbdInit` replaces the keyboard ISR (INKEY$ stops working until `kbdEnd`); INKEY$ works fine without it.

## QB45 gotchas

* `DEFINT A-Z` before `'$INCLUDE: 'UGL.BI'`; handles and colours are LONG, never let them default to INTEGER.
* `Seg` parameters (`TMR`, `MOUSEINF`, `TKBD`, palette arrays) must be static (`DIM`, not `REDIM`/`$DYNAMIC`)
  when an ISR keeps a pointer to them (timers, kbd, mouse). Plain palette arrays only need to be static during the call.
* Module layout: each `.BAS` module has its own 64 KB code segment (GAME.BAS is at the wall) - put every
  uGL call in a new module (e.g. `GAME6.BAS`, "VGA scenes") that includes `UGL.BI`; the main flow just CALLs it.
* Compatibility: VESA + logical-scanline (VBE 06h) support is required for 640x480 (uGL pads the pitch to 1024);
  2 pages need >= 960 KB VRAM. 320x200x8 with 1 page never uses VESA (plain mode 13h) and is the universal fallback.
* **Real-hardware triage (`VGA.LOG`)**: whenever `VgaOpen` misses the two-page rung, GAME6 `VgaDiag` appends a report to
  `VGA.LOG` in the game directory: which rungs uGL refused, far heap, EMS presence, the raw VESA answers (4F00h info block:
  signature/version/OEM/total VRAM/mode list; 4F01h for mode 101h: attributes, bytes per line, extra pages) and, when no 640x480
  rung worked, a by-hand probe (4F02h set 101h, 4F06h get / set 1024 / get, 4F07h display start) before the mode-13h rung runs.
  The 486 floppy (`tools/pack486.ps1`) also carries `UGLTEST.EXE` and `UGLTESTD.EXE` (debug library, writes `UGL.LOG`).
  First 486 result (Cirrus GD5430/5434, 1 MB, 2026-09-13): logo and manual came up in 320x200. The VGA.LOG
  (`docs/ugl/logs/486-cirrus-gd54xx-vga.log`) showed a healthy VBE 1.2 BIOS, so the fault was uGL's own version check:
  `VBE_MIN_VER = 0120h` where VBE 1.2 is `0102h` (major/minor bytes) - every VBE 1.x card was rejected and only VBE 2.0
  (DOSBox-X's S3) worked. Fixed by a binary patch of the shipped libs (`src/ugl/README.md`), reproduced and verified with
  DOSBox-X `machine=vesa_oldvbe` (VBE 1.2 emulation; `vesa_oldvbe10` = VBE 1.0, which uGL still rejects by design).

## Quick reference (0.23b, QB signatures - exact ones in `src/ugl/UGL.BI`)

Init / video:
`uglInit%()`, `uglEnd`, `uglRestore`, `uglVersion(major, minor, stable, build)`,
`uglSetVideoDC&(fmt, xRes, yRes, pages)`, `uglGetVideoDC&()`, `uglSetVisPage page`, `uglSetWrkPage page`,
`uglSetClipRect dc, cr`, `uglGetClipRect dc, cr`, `uglGetSetClipRect dc, inCr, outCr`.

DCs: `uglNew&(typ, fmt, w, h)`, `uglNewMult%(arr(), n, typ, fmt, w, h)`, `uglDel dc`, `uglDelMult arr()`,
`uglDCGet dc, info` (TDC: fmt, typ, xRes, yRes, bps, pages, size, cr), `uglColors&(fmt)`, `uglColorsEx&(dc)`,
`uglDCAccessRd/Wr/RdWr&(dc, y)` (scanline far pointers; flaky from QB per the changelog).

Colour: `uglColor&(fmt, r, g, b)`, `uglColor8/15/16/32&(r, g, b)`, `uglGetConv/uglPutConv` (blit between bit depths),
`uglRowRead/uglRowWrite dc, x, y, pixels, bufferFmt, buffer&`, `uglRowSetPal`.

Primitives: `uglPSet dc, x, y, clr&`, `uglPGet&(dc, x, y)`, `uglClear dc, clr&`, `uglHLine dc, x1, y, x2, clr&`,
`uglVLine dc, x, y1, y2, clr&`, `uglLine dc, x1, y1, x2, y2, clr&`, `uglRect/uglRectF dc, x1, y1, x2, y2, clr&`,
`uglCircle/uglCircleF dc, cx, cy, radius&, clr&`, `uglEllipse/uglEllipseF dc, cx, cy, rx, ry, clr&`,
`uglPoly/uglPolyF dc, pnts(), n, clr&`, `uglPolyPoly*`, `uglQuadricBez`, `uglCubicBez`, `uglTriF/G/T/TP`, `uglQuadF/T`.

Blits: `uglGet src, x, y, dst` (dst size = capture size), `uglPut dst, x, y, src`, `uglPutMsk dst, x, y, src`,
`uglPutFlip/uglPutMskFlip dst, x, y, mode, src` (UGL.HFLIP/VFLIP/VHFLIP), `uglPutRot dst, x, y, angle!, src`,
`uglPutScl/uglPutMskScl dst, x, y, xScale!, yScale!, src`, `uglPutRotScl`, `uglPutAB dst, x, y, alpha, src` (alpha blend),
`uglPutConv/uglPutMskConv` (depth conversion).

Images: `uglNewBMP&(typ, fmt, file$)`, `uglNewBMPEx&(typ, fmt, file$, opt)`, `uglPutBMP%(dc, x, y, file$)`,
`uglPutBMPEx%(dc, x, y, file$, opt)`; opt = `BMPOPT.NO332` (keep indices), `BMPOPT.MASK`. BMP 1/4/8/15/16/24/32-bit,
4/8-bit RLE. Files may live inside Quake PAK archives (`arch.pak::dir/file.bmp`).

Palette: `uglPalSet/uglPalGet idx, entries, pal&` (far ptr), `uglPalSetBuff/uglPalGetBuff idx, entries, pal(0)` (tRGB array),
`uglPalLoad&(file$, PALRGB|PALBGR)` (raw file -> far ptr, free with memFree), `uglPalUsingLin`.

Modules (own .BI each): timers `tmrInit/tmrEnd/tmrNew t, mode, rate&/tmrDel/tmrMs2Freq&...` (TMR.BI);
mouse `mouseInit%(dc, ms)/mouseShow/mouseHide/mouseCursor dc, xs, ys/mouseRange/mousePos/mouseIn%` (MOUSE.BI);
keyboard `kbdInit kbd/kbdEnd/kbdPause/kbdResume` (KBD.BI, TKBD has one flag per key);
fonts `fontNew&(file$)/fontTextOut/fontWidth%...` (FONT.BI, UVF vector fonts via tools/ttf2uvf);
EMS `emsCheck/emsAlloc/emsFree/emsMap/emsAvail&` (EMS.BI); DOS `fileOpen/bfileOpen/memAlloc/memFree/memCopy...` (DOS.BI);
sound `snd*` / music `mod*` (SND.BI/MOD.BI, Sound Blaster only, untested here).

## In the game (done 2026-09-12)

* **`src/GAME6.BAS`** is the VGA scene module: the only module that includes `UGL.BI`. Pure library, no
  COMMON block. Routines: `VgaOpen&(xr, yr, np)` = `uglInit` + the mode ladder, returns the video DC or 0
  and reports the mode reached; `VgaClose` = `uglRestore` + `uglEnd`; `VgaPalBMP bmp$` sets the hardware
  palette from an 8-bit BMP's own colour table; `VgaPalBlack`; `VgaHold secs!` (any key cuts it short);
  `LogoShow` = the tenthplay logo, darkv-bas style: cut in, 2 s hold, any key ends it, cut to black.
* **Startup flow** (GAME.BAS, inside the `introSkip` error trap): `LoadConfig` -> `LogoShow` when
  `intro=1`, `quickstart=0` and `logo=1` -> `CALL Intro` (`SCREEN 1`, the CGA carriage cutscene). Any uGL
  failure returns silently and the CGA game is untouched. On the 486 target (Cirrus GD5430/5434, 1 MB) the
  logo should reach the top rung: 1 MB is exactly what two 640x480 pages need, and the BIOS has VESA.
* **DARK.INI**: new key `logo=1` (parsed in GAME2 `LoadConfig`, variable `lgon` in the COMMON block of
  GAME.BAS and GAME2.BAS - both lines must stay identical). `logo=0` drops just the logo, for troubleshooting
  a card that dislikes the VESA switch.
* **Mid-game use (the planned VGA manual):** open with `VgaOpen`, draw, `VgaClose`, then `SCREEN 1` again and
  redraw the room - the CGA framebuffer and palette do not survive the mode switch. UGLTEST's "cycle 2" proves
  uGL re-initialises cleanly after a full close.
* **Build changes** (`src/build.conf`): `set INCLUDE=D:\UGL` after the mounts; a `BC ... GAME6.BAS` line; the
  link fields moved into **`src/LINK.RSP`** (`LINK @D:LINK.RSP`), because the one-line form with `/SEG:800`,
  six objects and the library overflows the 127-character DOS command tail - LINK then saw `UGLD.L` and
  reported eight unresolved `UGL*` externals while still writing a broken EXE. `LINKD.RSP` links the debug
  library instead. Cost: GAME.EXE 230668 -> 272134 bytes with the release lib (277238 with the debug lib), uGL code
  segment `ugl_text` ~18 KB, uGL's data ~4.5 KB of DGROUP (`_DATA` segment in GAME.MAP); the far heap is
  untouched until a MEM DC is allocated.
* **Art pipeline**: `src/tools/pcx2bmp.ps1 in.pcx [out.bmp] [-Info]` converts 8-bit PCX to the 8-bit BMP uGL
  loads (byte-identical to `TPLOGO.BMP`/`TPLOG320.BMP`). `src/tools/img2bmp8.ps1 in.png out.bmp [-Width 640
  -Height 480] [-Stretch]` takes any PNG/JPG/BMP, fits it on a black canvas (aspect kept, centred) and
  quantises it to an optimal 256-colour palette (WPF octree, nearest colour, no dither). VGA assets live flat
  in `src/` in 8.3 names.
* **VGA manual (Tab in the game, 2026-09-12)**: `ManualShow(msen)` in GAME6. GAME.BAS: `IF a$ = CHR$(9) THEN
  GOSUB domanual` next to the `m` map key; `domanual:` = erase the software cursor, `CALL ManualShow(msen)`,
  `GOTO invret` (the inventory/map return path that reloads the room and redraws the player). GAME_CODE is at
  64889 of 65536 bytes after this.
  - **Pages**: `MANnnH.BMP` (top, **624 wide**, up to 460 rows) + `MANnnHB.BMP` (rest, up to 480 rows), nn = 01,
    02... made with `img2bmp8.ps1 ... -Width 624 -Height 0 -SplitAt 460` (the two files share one palette; an
    8-bit source that needs resizing is resampled in RGB and mapped back onto its own palette, so the author's
    colours survive). `MANnnL.BMP` (320x200) serves the mode-13h rung through the simple one-page viewer.
    Palette slots 248-255 are reserved for the viewer's UI colours (`-Reserve 8`), index 0 is forced to the
    darkest colour. The right 16 px of the screen belong to the scrollbar, hence 624.
  - **How it draws** (two-page VESA rung only): the whole page lives in video memory. VRAM lines 0-19 are the
    bottom bar (back/forward page arrows, up/down scroll buttons, one dot per page), shown at the bottom of the
    screen by the VGA split-screen (CRTC line compare = 459). The page art fills VRAM lines 20.. across both uGL
    pages and is scrolled with the VESA display start (INT 10h 4F07h) - no blits per scroll step, works without
    EMS. Columns 624-639 of every page line carry a static scrollbar track drawn once per page, so a scroll step
    only moves the thumb. The mouse is read straight from INT 33h (ranges set to 640x480, driver cursor hidden)
    and drawn as a 12x18 software arrow with save-unders through `VBlit`, which clips to the visible VRAM range so
    the cursor never bleeds into the bar or the hidden part of the page.
  - **Scroll-step order matters** (the first version drew the whole scrollbar before moving the display start and
    it jittered one frame per step): `WAIT &H3DA,8,8` (be in the active picture), write the display start (the
    CRTC latches it at the coming retrace, whichever edge the card uses), `WAIT &H3DA,8` (retrace began), then
    erase/redraw the thumb and the cursor at their new VRAM rows inside the retrace.
  - **Controls**: Up/Down 16 px, PgUp/PgDn 400 px, Home/End, Left/Right turn pages, Tab/Esc close. Mouse: bar
    page arrows, bar up/down buttons (32 px), dots, scrollbar track (400 px), thumb drag. Page turns fade through
    black; forward slides the old page left, back slides the new page in from the left (display-start x offset).
  - **uGL 0.23b bug found on the way**: `uglPutBMP`/`uglPutBMPEx` ignore `uglSetWrkPage` and always write video
    page 0 (the primitives, `uglGet`/`uglPut` and `uglSetVisPage` honour the page - proven by
    `src/tools/UGLTEST2.BAS`). LoadPage therefore stages the bottom file on page 0 and lifts it to page 1 in
    48-line strips with `uglGet`/`uglPut` (`UGLTEST3.BAS` proves the strips leave the display start intact).
    The loader's clipping is fine; do not draw a BMP taller than 480 rows anyway.
  - **uGL 0.23b release-lib bug #2 (found 2026-09-13)**: from the THIRD `uglInit`/`uglEnd` cycle on, the release
    library cannot set any VESA mode any more (mode 13h still works), so in the game the logo + first manual worked
    and the second Tab dropped to the 320x200 fallback. The debug library is unaffected. Cause in the source:
    `vbeCheck` (called by `b8_Init`) `memCalloc`s a new VBE info block on every init and `b8_End` never frees it.
    Workaround in GAME6: `uglInit` runs once per run (`mInit`), scenes only `uglSetVideoDC` ... `uglRestore`, the
    viewer frees its DCs with `uglDel`, and `uglEnd` is left to uGL's exit hook. Two consequences: `uglRestore`
    returns to the mode uGL was initialised in (text mode 3 at the logo), so `VgaClose` reads the BIOS mode at
    `VgaOpen` (INT 10h AH=0Fh) and sets it back with INT 10h AH=00h; and uGL's own `ul$initialized` flag lives in
    its code segment, so a `RUN` (New Game) does not re-init it either - `uglInit` becomes a no-op then.
    Probes: `UGLTEST6.BAS` (cycles), `UGLTEST7.BAS` (the game's mode sequence), `UGLTEST8.BAS` (init once, 5 cycles).
  - **DOSBox-X quirk**: with the default `mouse_emulation=integration`, DOSBox-X stopped repainting the window
    while the viewer polled INT 33h in the VESA mode, although the BIOS/CRTC state kept changing correctly
    (scripted runs, trace readbacks). `mouse_emulation=locked` (what QA\Play-Current.bat already sets) works.
    `UGLTEST5.BAS` shows each mouse-path step behaving in isolation.
  - Verified with quickstart + `AUTOTYPE -w 8 -p 2 tab down down down down pagedown right left end tab`, row-mapping
    every capture back to the page art: exact 16-px steps, PgDn to rows 393-852, page 2, back, End, room reload.
