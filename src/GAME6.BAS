'----- GAME6.BAS: VGA scene module (uGL 0.23b, src\ugl). Sixth code module ->
'----- its own 64K code segment. Pure library (no COMMON SHARED): the ONLY module
'----- that includes UGL.BI and talks to the library; the rest of the game stays
'----- in CGA land and just CALLs the scenes.
'-----
'----- VgaOpen: uglInit ONCE per run (the 0.23b release lib refuses every VESA
'-----   mode from the third uglInit/uglEnd cycle on - UGLTEST6/7/8) + the video
'-----   mode ladder -- VESA 640x480x256 two pages -> one page -> plain VGA
'-----   320x200x256 (needs neither VESA nor EMS). Returns the video DC handle
'-----   (0 = nothing available, skip the scene) and reports the mode reached in
'-----   xr/yr/np. Remembers the BIOS mode it was called from. Whenever the
'-----   two-page VESA rung is NOT reached it appends a report to VGA.LOG (VgaDiag:
'-----   free memory, EMS, the raw VESA answers - 4F00h info block, 4F01h mode
'-----   101h, and if no 640x480 rung worked a manual 4F02h/4F06h/4F07h probe) so
'-----   a real 486 can tell us why. DOSBox-X's S3 never writes it.
'----- VgaClose: uglRestore (which only knows the mode uGL was INITIALISED in, the
'-----   text mode at the logo) then INT 10h sets the caller's mode back. The CGA
'-----   framebuffer does NOT survive a switch: an in-game caller must redraw the
'-----   room afterwards (GAME.BAS domanual -> invret does). uglEnd is left to
'-----   uGL's own exit hook.
'----- VgaPalLoad / VgaPalApply / VgaPalBMP / VgaPalBlack: the hardware palette
'-----   from an 8-bit BMP's own colour table (54-byte header + 256 BGRA entries),
'-----   kept in mPal() so it can be applied scaled (fades) / all black. BMPs are
'-----   drawn with BMPOPT.NO332 so their indices are kept as authored.
'----- VgaHold: TIMER wait (midnight-safe) that any key cuts short.
'----- VgaSync: wait for the NEXT vertical retrace (leave the current one first;
'-----   a bare WAIT &H3DA, 8 returns at once when already inside a retrace).
'----- LogoShow: tenthplay logo before the intro, darkv-bas style: cut in, hold
'-----   2 s, any key ends it, cut to black. TPLOGO.BMP (640x480) on the VESA
'-----   rungs, TPLOG320.BMP (320x200) on the mode-13h rung.
'-----
'----- ManualShow (Tab in the game): the VGA manual. It opens 800x600x256 (one
'-----   page = 600 KB, fits a 1 MB card) and flips through the composed views
'-----   MANP00.BMP, MANP01.BMP, ... - each a complete 800x600 image made from the
'-----   instruction-manual PDF (tools\compose_all.py): MANP00 = front cover
'-----   centred, the inside pages shown with the NEXT page cut off at the right edge
'-----   and a soft binding crease at the seam (Tunic-style), the last MANP = back
'-----   cover centred. A view is drawn whole at (0,0); there is no scrolling and no
'-----   second page (the Cirrus VESA BIOS honours neither), so a page turn just
'-----   fades through black to the next view. Keys: Left/Up/PgUp = previous,
'-----   Right/Down/PgDn = next, Home/End, Tab/Esc = close. Mouse (game mouse=1):
'-----   click the left half of the screen = previous, right half = next. If 800x600
'-----   is unavailable it falls back to ManualSimple (the old MANnnH/L pages).
'-----
'----- ReviveVga (GAME4 ReviveShow calls it first): the revive message over the
'-----   live room in plain VGA mode 13h so the room keeps its own 4 colours AND
'-----   the message gets 3 of its own (light gray / blue / brown) -- CGA's one
'-----   shared palette can't do both. Snapshots the B800 framebuffer, redraws it
'-----   pixel-for-pixel in 256-colour mode, draws the masked sprite on top, then
'-----   mode 4 again and POKEs the snapshot back under a black palette (the
'-----   caller's rmpal lights it). Returns 0 = no VGA, use the CGA version.
'-----
'----- IntroTalk (GAME.BAS Intro, the enter-house scene): the walk up the hall
'-----   and the James / player conversation in mode 13h, replacing the CGA
'-----   walk + TALK.PIC. ENTER.PIC (BLOADed by the caller behind a black
'-----   palette) is snapshotted and redrawn in its own colours plus light gray
'-----   (index 4); Joe's JOEW2 frames walk with the original timing; halfway
'-----   up, each line of INTROTLK.TXT ("Y|..." / "J|...") appears in the black
'-----   area above the hall as a DrawYNBox-style dialog (DLGCOR corners, the
'-----   game's bitmap font) with the speaker's head (HEADYOU / HEADJAM.PCT,
'-----   src\ART\Head*.png via tools\png2pct.ps1) on their side, warbled like
'-----   the old talk scene; any key = next line, 's' = skip the intro. Shared
'-----   helpers: CgaSnap / CgaLut / CgaRows (B800 snapshot -> mode-13h rows),
'-----   VgaPalSet, VgaArt (a SCREEN 1 PUT array with an attr -> index map),
'-----   VgaText / VgaTextW / VgaWrap (font.txt glyphs on a DC), VgaWarble.
'-----   Returns 0 = not shown (no VGA, or the script / heads missing) so the
'-----   CGA scene runs, 1 = done, 2 = skipped.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'
'$INCLUDE: 'DOS.BI'

'----- QB.LIB interrupt support (INT 10h VESA display start, INT 33h mouse)
TYPE RegType
	ax AS INTEGER
	bx AS INTEGER
	cx AS INTEGER
	dx AS INTEGER
	bp AS INTEGER
	si AS INTEGER
	di AS INTEGER
	flags AS INTEGER
END TYPE
DECLARE SUB INTERRUPT (intnum AS INTEGER, inreg AS RegType, outreg AS RegType)
TYPE RegTypeX
	ax AS INTEGER
	bx AS INTEGER
	cx AS INTEGER
	dx AS INTEGER
	bp AS INTEGER
	si AS INTEGER
	di AS INTEGER
	flags AS INTEGER
	ds AS INTEGER
	es AS INTEGER
END TYPE
DECLARE SUB INTERRUPTX (intnum AS INTEGER, inreg AS RegTypeX, outreg AS RegTypeX)

'----- manual layout (screen 640x480 = 460-line page + 20-line bar at the bottom)
CONST mBarH = 20, mBarY = 460, mArtH = 460, mPgW = 624, mMaxPages = 20
CONST mCurW = 12, mCurH = 18
'----- fixed UI palette slots (img2bmp8.ps1 -Reserve 8)
CONST cBlack = 248, cWhite = 249, cLGray = 250, cMGray = 251, cDGray = 252, cParch = 253, cDParch = 254, cRed = 255
CONST cMask = 227
'----- fade/slide background = 1E1A20 (matches the dark background of the page art),
'----- as 0-255 RGB; the fades settle to this instead of pure black
CONST bgR = 30, bgG = 26, bgB = 32

DECLARE FUNCTION VgaOpen& (pref AS INTEGER, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
DECLARE SUB VgaDiag (r1 AS INTEGER, r2 AS INTEGER, full AS INTEGER)
DECLARE SUB VbeCall (fh AS INTEGER, tag AS STRING, rx AS RegTypeX)
DECLARE FUNCTION VBb% (i AS INTEGER)
DECLARE FUNCTION VBw& (i AS INTEGER)
DECLARE FUNCTION PeekStr$ (sg AS LONG, ofs AS LONG, n AS INTEGER)
DECLARE SUB VgaClose ()
DECLARE SUB VgaPalLoad (bmp AS STRING)
DECLARE SUB VgaPalApply (f AS INTEGER)
DECLARE SUB VgaPalBMP (bmp AS STRING)
DECLARE SUB VgaPalBlack ()
DECLARE SUB VgaHold (secs AS SINGLE)
DECLARE SUB VgaSync ()
DECLARE SUB LogoShow ()
DECLARE SUB ManualShow (msen AS SINGLE)
DECLARE SUB ShowInstructions (msen AS SINGLE)
DECLARE SUB ShowRules ()
DECLARE SUB ManualSimple (v AS LONG, xr AS INTEGER, np AS INTEGER)
DECLARE FUNCTION ManPage% (v AS LONG, n AS INTEGER, np AS INTEGER, sfx AS STRING, vis AS INTEGER)
DECLARE SUB ManualScroll (msen AS SINGLE)
DECLARE FUNCTION FileExists% (fil AS STRING)
DECLARE FUNCTION LoadView% (n AS INTEGER)
DECLARE SUB PageTurn (n AS INTEGER)
DECLARE SUB SlideTo (n AS INTEGER)
DECLARE SUB ScrollX (px AS INTEGER)
DECLARE FUNCTION CrtcR% (idx AS INTEGER)
DECLARE SUB CrtcW (idx AS INTEGER, v AS INTEGER)
DECLARE SUB SlideFrame (px AS INTEGER, f AS INTEGER)
DECLARE SUB VgaPalCalc (f AS INTEGER)
DECLARE SUB MouseRead (x AS INTEGER, y AS INTEGER, b AS INTEGER)
DECLARE FUNCTION ReviveVga% (art() AS INTEGER, msk() AS INTEGER, co AS INTEGER, p1 AS INTEGER, p2 AS INTEGER, p3 AS INTEGER, mvint AS INTEGER, msen AS SINGLE)
DECLARE SUB CgaRGB (c AS INTEGER, p AS tRGB)
DECLARE SUB CgaSnap (cga() AS INTEGER)
DECLARE SUB CgaLut (lut() AS INTEGER)
DECLARE SUB CgaRows (v AS LONG, cga() AS INTEGER, lut() AS INTEGER, row() AS INTEGER, y0 AS INTEGER, y1 AS INTEGER, x0 AS INTEGER, x1 AS INTEGER)
DECLARE SUB VgaPalSet (cc() AS INTEGER, n AS INTEGER)
DECLARE FUNCTION PutByte% (arr() AS INTEGER, q AS INTEGER)
DECLARE SUB VgaArt (v AS LONG, x0 AS INTEGER, y0 AS INTEGER, art() AS INTEGER, ao AS INTEGER, msk() AS INTEGER, mo AS INTEGER, um AS INTEGER, cmap() AS INTEGER)
DECLARE SUB VgaText (v AS LONG, x AS INTEGER, y AS INTEGER, s AS STRING, clr AS INTEGER, fd() AS INTEGER)
DECLARE FUNCTION VgaTextW% (s AS STRING, fd() AS INTEGER)
DECLARE SUB VgaWrap (v AS LONG, x AS INTEGER, y AS INTEGER, s AS STRING, clr AS INTEGER, maxpx AS INTEGER, lineh AS INTEGER, fd() AS INTEGER)
DECLARE SUB VgaWrapSplit (s AS STRING, maxpx AS INTEGER, fd() AS INTEGER, lines() AS STRING, n AS INTEGER)
DECLARE SUB VgaType (v AS LONG, x AS INTEGER, y AS INTEGER, s AS STRING, clr AS INTEGER, maxpx AS INTEGER, lineh AS INTEGER, fd() AS INTEGER, f3 AS SINGLE, k AS STRING)
DECLARE SUB VgaWarble (f3 AS SINGLE)
DECLARE SUB VgaMark (v AS LONG, x AS INTEGER, y AS INTEGER, clr AS INTEGER)
DECLARE FUNCTION IntroTalk% (fd() AS INTEGER, f3 AS SINGLE)
DECLARE FUNCTION IntroWalkCga% (f3 AS SINGLE)

'----- module state for the page-flip viewer (mPal / vbuf in the far heap via REDIM)
REM $DYNAMIC
DIM SHARED mPal(0 TO 255) AS tRGB
DIM SHARED pBuf(0 TO 255) AS tRGB
DIM SHARED vbuf(0 TO 255) AS INTEGER
REM $STATIC
DIM SHARED mv AS LONG
DIM SHARED mPage AS INTEGER, mNPages AS INTEGER
DIM SHARED mMouse AS INTEGER
DIM SHARED mInit AS INTEGER, mMode AS INTEGER
'----- horizontal page-slide state: framebuffer pitch, the CRTC addressing unit, and
'----- whether the mode has an off-screen margin to slide into (set in ManualScroll)
DIM SHARED gPitch AS LONG, gUnit AS INTEGER, gSlide AS INTEGER

'----- bottom bar at VRAM lines 460..479 (shown directly, display start stays 0):
'----- back / forward arrows and one dot per sub-page, the current one lit


'----- 12x18 arrow: X = black outline, O = white fill, . = transparent


FUNCTION FileExists% (fil AS STRING)
	DIM f AS FILE
	FileExists% = 0
	IF fileOpen(f, fil, F4READ) THEN fileClose f: FileExists% = -1
END FUNCTION

'----- filename for sub-page n (top "h" or bottom "hb" half of a spread)

'----- load one sub-page (a single BMP <= 460 rows) onto page 0 at line 0, its
'----- palette into mPal. One screen at a time: no scrolling, no page 1, no strip.

SUB LogoShow
	DIM v AS LONG, xr AS INTEGER, yr AS INTEGER, np AS INTEGER, bmp AS STRING
	v = VgaOpen&(0, xr, yr, np)
	IF v = 0 THEN EXIT SUB
	IF xr = 640 THEN bmp = "tplogo.bmp" ELSE bmp = "tplog320.bmp"
	uglSetWrkPage 0
	uglSetVisPage 0
	CALL VgaPalBlack
	'----- draw hidden under the black palette, then reveal in one palette write
	IF uglPutBMPEx(v, 0, 0, bmp, BMPOPT.NO332) THEN
		CALL VgaPalBMP(bmp)
		DO: LOOP WHILE INKEY$ <> ""
		CALL VgaHold(2)
		CALL VgaPalBlack
	END IF
	CALL VgaClose
END SUB

'----- mouse click in the bottom bar (my >= 460): back / forward arrows, sub-page dots

FUNCTION ManPage% (v AS LONG, n AS INTEGER, np AS INTEGER, sfx AS STRING, vis AS INTEGER)
	DIM bmp AS STRING, hid AS INTEGER
	bmp = "man" + RIGHT$("0" + LTRIM$(STR$(n)), 2) + sfx + ".bmp"
	ManPage% = 0
	'----- black out, reload in place on page 0 (the BMP loader only writes
	'----- page 0, so a hidden-page flip is not available), reveal
	hid = np: hid = vis
	uglSetWrkPage 0
	CALL VgaPalBlack
	IF uglPutBMPEx(v, 0, 0, bmp, BMPOPT.NO332) = 0 THEN EXIT FUNCTION
	CALL VgaPalBMP(bmp)
	ManPage% = -1
END FUNCTION

'----- page-flip viewer (640x480, one screen per sub-page). Display start stays 0
'----- (the Cirrus GD54xx VESA BIOS ignores 4F07h), so each sub-page is a single BMP
'----- on page 0 with the bar at the bottom; a page turn fades through black. Mouse
'----- only when msen = 1.

SUB ManualShow (msen AS SINGLE)
	CALL ManualScroll(msen)
END SUB

'----- intro "Do you want instructions?" = the illustrated manual when it is
'----- installed, otherwise the classic text rules. SCREEN 1 is restored either way
'----- because qstart draws the cursor sprite in CGA graphics right after.
SUB ShowInstructions (msen AS SINGLE)
	IF FileExists%("manp00.bmp") THEN
		CALL ManualScroll(msen)
		SCREEN 1
	ELSE
		CALL ShowRules
	END IF
END SUB

'----- fallback viewer for the one-page / 320x200 rungs: whole page, Left/Right only
SUB ManualSimple (v AS LONG, xr AS INTEGER, np AS INTEGER)
	DIM pg AS INTEGER, n AS INTEGER, vis AS INTEGER, k AS STRING, sfx AS STRING
	IF xr = 640 THEN sfx = "h" ELSE sfx = "l"
	vis = 0
	uglSetWrkPage 0
	uglSetVisPage 0
	CALL VgaPalBlack
	pg = 1
	IF ManPage%(v, pg, 1, sfx, vis) = 0 THEN CALL VgaClose: EXIT SUB
	DO: LOOP WHILE INKEY$ <> ""
	DO
		k = INKEY$
		IF k = CHR$(9) OR k = CHR$(27) THEN EXIT DO
		IF LEN(k) = 2 THEN
			n = pg
			IF ASC(RIGHT$(k, 1)) = 77 OR ASC(RIGHT$(k, 1)) = 81 THEN n = pg + 1
			IF ASC(RIGHT$(k, 1)) = 75 OR ASC(RIGHT$(k, 1)) = 73 THEN n = pg - 1
			IF n >= 1 AND n <> pg THEN
				IF ManPage%(v, n, np, sfx, vis) THEN
					pg = n
				ELSE
					CALL VgaPalBMP("man" + RIGHT$("0" + LTRIM$(STR$(pg)), 2) + sfx + ".bmp")
				END IF
			END IF
		END IF
	LOOP
	CALL VgaPalBlack
	CALL VgaClose
END SUB


'----- turn to sub-page n with a fade through black (the page-flip effect)

SUB VgaClose
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	uglRestore
	'----- uglRestore returns to the mode uGL was initialised in; put back the
	'----- one the caller was in (mode 4 for the CGA game, 3 before the intro)
	vi = &H10
	r.ax = mMode
	CALL INTERRUPT(vi, r, r2)
END SUB

'----- VGA.LOG report. r1/r2 = the 640x480 two-page / one-page rungs (0 = refused,
'----- -2 = uglInit itself failed); full = also set mode 101h by hand and try the
'----- calls uGL needs (logical scanline 1024, display start), then restore mMode.
SUB VgaDiag (r1 AS INTEGER, r2 AS INTEGER, full AS INTEGER)
	DIM fh AS INTEGER, i AS INTEGER, k AS INTEGER, sg AS LONG, ofs AS LONG, w AS LONG
	DIM rx AS RegTypeX, s AS STRING, r AS RegType, r0 AS RegType, vi AS INTEGER
	REDIM vbuf(0 TO 255) AS INTEGER
	fh = FREEFILE
	OPEN "vga.log" FOR APPEND AS #fh
	PRINT #fh, "--- " + DATE$ + " " + TIME$ + " from bios mode" + STR$(mMode) + " far heap" + STR$(FRE(-1)) + " strings" + STR$(FRE(""))
	IF r1 = -2 THEN
		PRINT #fh, "uglInit FAILED"
	ELSE
		PRINT #fh, "uGL 640x480x256 2 pages:" + STR$(r1 <> 0) + "  1 page:" + STR$(r2 <> 0) + "  (-1 = ok, 0 = refused)"
	END IF
	'----- EMS driver present? (INT 67h vector -> device header "EMMXXXX0")
	DEF SEG = 0
	sg = PEEK(&H67 * 4 + 2) + 256& * PEEK(&H67 * 4 + 3)
	s = ""
	IF sg <> 0 THEN s = PeekStr$(sg, 10, 8)
	IF s = "EMMXXXX0" THEN
		vi = &H67
		r.ax = &H4200
		CALL INTERRUPT(vi, r, r0)
		PRINT #fh, "EMS: present, free pages" + STR$(r0.bx) + " of" + STR$(r0.dx) + " (16 KB each)"
	ELSE
		PRINT #fh, "EMS: none (not needed for uGL modes)"
	END IF
	'----- VESA info block (4F00h): signature, version, OEM, memory, mode list
	FOR i = 0 TO 255: vbuf(i) = 0: NEXT
	rx.ax = &H4F00: rx.bx = 0: rx.cx = 0: rx.dx = 0
	CALL VbeCall(fh, "4F00 info", rx)
	IF rx.ax = &H4F THEN
		s = CHR$(VBb%(0)) + CHR$(VBb%(1)) + CHR$(VBb%(2)) + CHR$(VBb%(3))
		PRINT #fh, "  sig " + s + " vbe " + LTRIM$(STR$(VBb%(5))) + "." + LTRIM$(STR$(VBb%(4))) + " caps " + HEX$(VBb%(10)) + " total vram KB" + STR$(VBw&(18) * 64)
		PRINT #fh, "  oem: " + PeekStr$(VBw&(8), VBw&(6), 40)
		sg = VBw&(16): ofs = VBw&(14): s = ""
		FOR k = 0 TO 47
			DEF SEG = sg
			w = PEEK(ofs + k * 2) + 256& * PEEK(ofs + k * 2 + 1)
			IF w = 65535 THEN EXIT FOR
			s = s + " " + HEX$(w)
		NEXT
		DEF SEG
		PRINT #fh, "  modes:" + s
	END IF
	'----- mode 101h = 640x480x256 (4F01h)
	FOR i = 0 TO 255: vbuf(i) = 0: NEXT
	rx.ax = &H4F01: rx.cx = &H101
	CALL VbeCall(fh, "4F01 mode 101h", rx)
	IF rx.ax = &H4F THEN
		PRINT #fh, "  attr " + HEX$(VBw&(0)) + " winA attr " + HEX$(VBb%(2)) + " gran KB" + STR$(VBw&(4)) + " win KB" + STR$(VBw&(6)) + " winA seg " + HEX$(VBw&(8))
		PRINT #fh, "  bytes/line" + STR$(VBw&(16)) + " res" + STR$(VBw&(18)) + " x" + STR$(VBw&(20)) + " planes" + STR$(VBb%(24)) + " bpp" + STR$(VBb%(25))
		PRINT #fh, "  banks" + STR$(VBb%(26)) + " model" + STR$(VBb%(27)) + " bank KB" + STR$(VBb%(28)) + " extra pages" + STR$(VBb%(29))
	END IF
	IF full THEN
		'----- by hand: set 101h, read/set the logical scanline, move the display start
		rx.ax = &H4F02: rx.bx = &H101
		CALL VbeCall(fh, "4F02 set 101h", rx)
		IF rx.ax = &H4F THEN
			rx.ax = &H4F06: rx.bx = 1: rx.cx = 0
			CALL VbeCall(fh, "4F06 get scanline (bx bytes, cx px, dx lines)", rx)
			rx.ax = &H4F06: rx.bx = 0: rx.cx = 1024
			CALL VbeCall(fh, "4F06 set scanline 1024 px", rx)
			rx.ax = &H4F06: rx.bx = 1: rx.cx = 0
			CALL VbeCall(fh, "4F06 get scanline again", rx)
			rx.ax = &H4F07: rx.bx = 0: rx.cx = 0: rx.dx = 480
			CALL VbeCall(fh, "4F07 display start line 480", rx)
			rx.ax = &H4F07: rx.bx = 1: rx.cx = 0: rx.dx = 0
			CALL VbeCall(fh, "4F07 get display start", rx)
		END IF
		vi = &H10
		r.ax = mMode
		CALL INTERRUPT(vi, r, r0)
	END IF
	CLOSE #fh
	ERASE vbuf
END SUB

'----- one VESA call through INT 10h with ES:DI -> vbuf; logs the registers back
SUB VbeCall (fh AS INTEGER, tag AS STRING, rx AS RegTypeX)
	DIM rx2 AS RegTypeX, vi AS INTEGER
	rx.bp = 0: rx.si = 0: rx.flags = 0: rx.ds = -1
	rx.es = VARSEG(vbuf(0)): rx.di = VARPTR(vbuf(0))
	vi = &H10
	CALL INTERRUPTX(vi, rx, rx2)
	PRINT #fh, tag + ": ax " + HEX$(rx2.ax) + " bx " + HEX$(rx2.bx) + " cx " + HEX$(rx2.cx) + " dx " + HEX$(rx2.dx)
	rx.ax = rx2.ax: rx.bx = rx2.bx: rx.cx = rx2.cx: rx.dx = rx2.dx
END SUB

'----- byte / word i of vbuf (unsigned)
FUNCTION VBb% (i AS INTEGER)
	DIM w AS LONG
	w = vbuf(i \ 2)
	IF w < 0 THEN w = w + 65536
	IF (i AND 1) THEN VBb% = w \ 256 ELSE VBb% = w AND 255
END FUNCTION

FUNCTION VBw& (i AS INTEGER)
	VBw& = VBb%(i) + 256& * VBb%(i + 1)
END FUNCTION

'----- up to n bytes of text at sg:ofs, stops at a zero byte
FUNCTION PeekStr$ (sg AS LONG, ofs AS LONG, n AS INTEGER)
	DIM s AS STRING, k AS INTEGER, b AS INTEGER
	DEF SEG = sg
	FOR k = 0 TO n - 1
		b = PEEK(ofs + k)
		IF b = 0 THEN EXIT FOR
		IF b < 32 OR b > 126 THEN b = 46
		s = s + CHR$(b)
	NEXT
	DEF SEG
	PeekStr$ = s
END FUNCTION

SUB VgaHold (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	t9 = TIMER
	DO
		IF INKEY$ <> "" THEN EXIT DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END SUB


'----- mPal() interpolated by f/16 into the DAC (16 = as loaded, 0 = the bg colour)
SUB VgaPalApply (f AS INTEGER)
	DIM i AS INTEGER
	REDIM p(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		p(i).red = CHR$(bgR + ((ASC(mPal(i).red) - bgR) * f) \ 16)
		p(i).green = CHR$(bgG + ((ASC(mPal(i).green) - bgG) * f) \ 16)
		p(i).blue = CHR$(bgB + ((ASC(mPal(i).blue) - bgB) * f) \ 16)
	NEXT
	uglPalSetBuff 0, 256, p(0)
END SUB

SUB VgaPalBlack
	DIM i AS INTEGER
	REDIM blk(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		blk(i).red = CHR$(0): blk(i).green = CHR$(0): blk(i).blue = CHR$(0)
	NEXT
	uglPalSetBuff 0, 256, blk(0)
END SUB

SUB VgaPalBMP (bmp AS STRING)
	REDIM mPal(0 TO 255) AS tRGB
	CALL VgaPalLoad(bmp)
	CALL VgaPalApply(16)
END SUB

'----- 256 BGRA entries at file offset 55 (54-byte header) -> mPal()
SUB VgaPalLoad (bmp AS STRING)
	DIM i AS INTEGER, fh AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN bmp FOR BINARY AS #fh
	SEEK #fh, 55
	s = INPUT$(1024, #fh)
	CLOSE #fh
	FOR i = 0 TO 255
		mPal(i).blue = MID$(s, i * 4 + 1, 1)
		mPal(i).green = MID$(s, i * 4 + 2, 1)
		mPal(i).red = MID$(s, i * 4 + 3, 1)
	NEXT
	s = ""
END SUB

SUB VgaSync
	WAIT &H3DA, 8, 8
	WAIT &H3DA, 8
END SUB


'----- filled rect in VRAM-line coordinates across both uGL pages

'----- filled triangle in VRAM-line coordinates (drawn on both uGL pages, each clips)

'----- load composed view n (MANP00..) full-screen at (0,0), palette into mPal
FUNCTION LoadView% (n AS INTEGER)
	DIM bmp AS STRING
	bmp = "manp" + RIGHT$("0" + LTRIM$(STR$(n)), 2) + ".bmp"
	LoadView% = 0
	IF NOT FileExists%(bmp) THEN EXIT FUNCTION
	uglSetWrkPage 0
	CALL VgaPalApply(0)
	IF uglPutBMPEx(mv, 0, 0, bmp, BMPOPT.NO332) = 0 THEN EXIT FUNCTION
	CALL VgaPalLoad(bmp)
	'----- force index 0 (fills the off-screen margin the slide exposes) to the bg
	'----- colour; several pages ship a light-grey index 0 that showed as a grey sliver
	mPal(0).red = CHR$(bgR): mPal(0).green = CHR$(bgG): mPal(0).blue = CHR$(bgB)
	mPage = n
	LoadView% = -1
END FUNCTION

'----- the manual: 640x480 full-page view flipper (see the header notes)
SUB ManualScroll (msen AS SINGLE)
	DIM xr AS INTEGER, yr AS INTEGER, np AS INTEGER, i AS INTEGER, k AS STRING, code AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, mb AS INTEGER, wasDown AS INTEGER
	DIM r AS RegType, r2 AS RegType, mi AS INTEGER, lf2 AS INTEGER
	REDIM mPal(0 TO 255) AS tRGB
	REDIM pBuf(0 TO 255) AS tRGB
	'----- no manual installed (SETUP skipped disk 2): quiet no-op, stay in the game
	IF NOT FileExists%("manp00.bmp") THEN EXIT SUB
	mv = VgaOpen&(640, xr, yr, np)
	IF mv = 0 THEN EXIT SUB
	IF xr <> 640 THEN CALL ManualSimple(mv, xr, np): EXIT SUB
	'----- can we do the horizontal slide? needs a pitch wider than 640 (an off-screen
	'----- margin to nudge the page into). If so, read the CRTC addressing unit. The
	'----- slide itself is plain-VGA display-start writes, so it needs no coprocessor.
	DIM inf AS TDC
	uglDCGet mv, inf
	gPitch = inf.bps
	gSlide = 0
	IF gPitch > 640 THEN
		IF CrtcR%(&H14) AND &H40 THEN
			gUnit = 4
		ELSEIF CrtcR%(&H17) AND &H40 THEN
			gUnit = 1
		ELSE
			gUnit = 2
		END IF
		gSlide = -1
	END IF
	'----- count the composed views MANP00.. on disk
	mNPages = 0
	FOR i = 0 TO 29
		IF FileExists%("manp" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".bmp") THEN mNPages = i + 1 ELSE EXIT FOR
	NEXT
	IF mNPages = 0 THEN CALL VgaClose: EXIT SUB
	uglSetWrkPage 0
	uglSetVisPage 0
	CALL VgaPalApply(0)
	IF LoadView%(0) = 0 THEN CALL VgaClose: EXIT SUB
	'----- MANOK.LOG: one line per open (views, mode, free heap) - field diagnostic
	lf2 = FREEFILE
	OPEN "manok.log" FOR APPEND AS #lf2
	PRINT #lf2, "manual open: views" + STR$(mNPages) + " mode" + STR$(xr) + "x" + STR$(yr) + " free" + STR$(FRE(-1))
	CLOSE #lf2
	'----- mouse: range to the 640x480 screen, driver cursor hidden (we click page halves)
	mMouse = 0
	IF msen = 1 THEN
		mi = &H33
		r.ax = 7: r.cx = 0: r.dx = 639: CALL INTERRUPT(mi, r, r2)
		r.ax = 8: r.cx = 0: r.dx = 479: CALL INTERRUPT(mi, r, r2)
		r.ax = 2: CALL INTERRUPT(mi, r, r2)
		mMouse = 1
	END IF
	FOR i = 0 TO 10
		CALL VgaSync
		CALL VgaPalApply(i * 16 \ 10)
	NEXT
	DO: LOOP WHILE INKEY$ <> ""
	wasDown = 0
	DO
		k = INKEY$
		IF k = CHR$(9) OR k = CHR$(27) THEN EXIT DO
		IF LEN(k) = 2 THEN
			code = ASC(RIGHT$(k, 1))
			SELECT CASE code
				CASE 75, 72, 73: CALL PageTurn(mPage - 1)
				CASE 77, 80, 81: CALL PageTurn(mPage + 1)
				CASE 71: CALL PageTurn(0)
				CASE 79: CALL PageTurn(mNPages - 1)
			END SELECT
		END IF
		IF mMouse THEN
			CALL MouseRead(mx, my, mb)
			IF (mb AND 1) THEN
				IF wasDown = 0 THEN
					IF mx < 320 THEN CALL PageTurn(mPage - 1) ELSE CALL PageTurn(mPage + 1)
				END IF
				wasDown = -1
			ELSE
				wasDown = 0
			END IF
		END IF
	LOOP
	FOR i = 10 TO 0 STEP -1
		CALL VgaSync
		CALL VgaPalApply(i * 16 \ 10)
	NEXT
	CALL VgaPalBlack
	CALL VgaClose
END SUB

'----- INT 33h mouse read (buttons + position), clamped to the 800x600 screen
SUB MouseRead (x AS INTEGER, y AS INTEGER, b AS INTEGER)
	DIM r AS RegType, r2 AS RegType, mi AS INTEGER
	mi = &H33
	r.ax = 3
	CALL INTERRUPT(mi, r, r2)
	b = r2.bx: x = r2.cx: y = r2.dx
	IF x < 0 THEN x = 0
	IF x > 639 THEN x = 639
	IF y < 0 THEN y = 0
	IF y > 479 THEN y = 479
END SUB

'----- turn to view n: horizontal nudge-slide where the mode allows it, else a fade
SUB PageTurn (n AS INTEGER)
	DIM i AS INTEGER
	IF n < 0 OR n > mNPages - 1 OR n = mPage THEN EXIT SUB
	IF gSlide THEN CALL SlideTo(n): EXIT SUB
	'----- fallback (320x200, or a mode with no scroll margin): fade through the bg
	FOR i = 10 TO 0 STEP -1
		CALL VgaSync
		CALL VgaPalApply(i * 16 \ 10)
	NEXT
	CALL VgaPalApply(0)
	IF LoadView%(n) = 0 THEN i = LoadView%(mPage)
	FOR i = 0 TO 10
		CALL VgaSync
		CALL VgaPalApply(i * 16 \ 10)
	NEXT
END SUB

'----- the horizontal page turn (proven on the 486SX - FPU-free): nudge the current
'----- page LEFT a few px while fading to black, load the next page unseen, then slide
'----- it in from the left back to normal while fading up. ScrollX moves the display
'----- start by direct CRTC writes (VESA's 4F07h is broken on the target Cirrus), and
'----- a few px only needs the standard VGA CR0C/CR0D, so it works on any VGA card.
SUB SlideTo (n AS INTEGER)
	DIM i AS INTEGER, nud AS INTEGER, steps AS INTEGER
	'----- nud = px of horizontal travel; steps = fade granularity. Fewer steps and no
	'----- extra hold (SlideFrame is already retrace-paced) = a snappier turn. Tune here.
	nud = 16: steps = 3
	FOR i = 0 TO steps
		CALL SlideFrame(nud * i \ steps, (steps - i) * 16 \ steps)
	NEXT
	IF LoadView%(n) = 0 THEN IF LoadView%(mPage) = 0 THEN EXIT SUB
	FOR i = 0 TO steps
		CALL SlideFrame(nud * (steps - i) \ steps, i * 16 \ steps)
	NEXT
	CALL ScrollX(0)
END SUB

'----- one flicker-free slide frame: compute the faded palette OFF-screen (the slow
'----- part - string math over 256 colours), then in the vertical blank do ONLY the
'----- fast register writes: move the display start (the scroll) and load the DAC. So
'----- the palette never changes while the beam is drawing the picture.
SUB SlideFrame (px AS INTEGER, f AS INTEGER)
	DIM u AS INTEGER
	CALL VgaPalCalc(f)
	IF gUnit = 0 THEN gUnit = 1
	u = px \ gUnit
	WAIT &H3DA, 8, 8
	WAIT &H3DA, 8
	CALL CrtcW(&HC, (u \ 256) AND 255)
	CALL CrtcW(&HD, u AND 255)
	uglPalSetBuff 0, 256, pBuf(0)
END SUB

'----- scale mPal by f/16 into pBuf (no DAC write, no per-frame REDIM - both of which
'----- would push the actual palette load out of the vertical blank and cause flicker)
SUB VgaPalCalc (f AS INTEGER)
	DIM i AS INTEGER
	FOR i = 0 TO 255
		pBuf(i).red = CHR$(bgR + ((ASC(mPal(i).red) - bgR) * f) \ 16)
		pBuf(i).green = CHR$(bgG + ((ASC(mPal(i).green) - bgG) * f) \ 16)
		pBuf(i).blue = CHR$(bgB + ((ASC(mPal(i).blue) - bgB) * f) \ 16)
	NEXT
END SUB

'----- set the horizontal display start to pixel px (line 0) via the CRTC, waiting out
'----- the retrace so it latches cleanly. Small offsets only touch CR0C/CR0D = plain
'----- VGA (every card); gUnit is the mode's byte/word/dword addressing unit.
SUB ScrollX (px AS INTEGER)
	DIM u AS INTEGER
	IF gUnit = 0 THEN gUnit = 1
	u = px \ gUnit
	WAIT &H3DA, 8, 8
	CALL CrtcW(&HC, (u \ 256) AND 255)
	CALL CrtcW(&HD, u AND 255)
	WAIT &H3DA, 8
END SUB

'----- CRTC register read / write (index at 3D4h, data at 3D5h)
FUNCTION CrtcR% (idx AS INTEGER)
	OUT &H3D4, idx
	CrtcR% = INP(&H3D5)
END FUNCTION

SUB CrtcW (idx AS INTEGER, v AS INTEGER)
	OUT &H3D4, idx
	OUT &H3D5, v
END SUB

'----- VgaOpen: uglInit once + remember the caller's BIOS mode, then set the mode.
'----- pref = 640 -> VESA 640x480x256 one page -> 320x200 (the manual);
'----- pref = 800 -> VESA 800x600x256 one page -> 640x480x1 -> 320x200 (legacy);
'----- pref = 0 -> the logo/intro ladder 640x480x2 -> 1 -> 320x200 (with VGA.LOG on a miss).
FUNCTION VgaOpen& (pref AS INTEGER, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
	DIM v AS LONG, r AS RegType, r2 AS RegType, vi AS INTEGER, k1 AS INTEGER, k2 AS INTEGER
	VgaOpen& = 0
	IF mInit = 0 THEN
		IF NOT uglInit THEN CALL VgaDiag(-2, -2, -1): EXIT FUNCTION
		mInit = -1
	END IF
	vi = &H10
	r.ax = &HF00
	CALL INTERRUPT(vi, r, r2)
	mMode = r2.ax AND 255
	IF pref = 640 THEN
		'----- the manual: 640x480x256 TWO pages (the 1024-byte pitch gives the off-
		'----- screen margin the horizontal page-slide nudges into) -> one page (fade
		'----- turns) -> 320x200 (fade) on a VESA miss
		xr = 640: yr = 480: np = 2
		v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		IF v = 0 THEN np = 1: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		IF v = 0 THEN xr = 320: yr = 200: np = 1: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		VgaOpen& = v
		EXIT FUNCTION
	END IF
	IF pref = 320 THEN
		'----- in-game overlays (ReviveVga): plain VGA mode 13h only, no VESA,
		'----- the mode every VGA has -- 0 here means "no VGA at all"
		xr = 320: yr = 200: np = 1
		VgaOpen& = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		EXIT FUNCTION
	END IF
	IF pref = 800 THEN
		xr = 800: yr = 600: np = 1
		v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		IF v = 0 THEN xr = 640: yr = 480: np = 1: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		IF v = 0 THEN xr = 320: yr = 200: np = 1: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		VgaOpen& = v
		EXIT FUNCTION
	END IF
	xr = 640: yr = 480: np = 2
	v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
	k1 = (v <> 0)
	IF v = 0 THEN np = 1: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
	k2 = (v <> 0)
	IF v = 0 THEN
		CALL VgaDiag(k1, k2, -1)
		xr = 320: yr = 200: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
	ELSEIF k1 = 0 THEN
		CALL VgaDiag(k1, k2, 0)
	END IF
	IF v = 0 THEN EXIT FUNCTION
	VgaOpen& = v
END FUNCTION

'----- CGA/EGA 16-colour index -> 0-255 RGB (6 = brown, not dark yellow)
SUB CgaRGB (c AS INTEGER, p AS tRGB)
	DIM r AS INTEGER, g AS INTEGER, b AS INTEGER, hi AS INTEGER
	hi = 0
	IF (c AND 8) THEN hi = &H55
	r = hi: g = hi: b = hi
	IF (c AND 4) THEN r = r + &HAA
	IF (c AND 2) THEN g = g + &HAA
	IF (c AND 1) THEN b = b + &HAA
	IF c = 6 THEN g = &H55
	p.red = CHR$(r): p.green = CHR$(g): p.blue = CHR$(b)
END SUB

'----- ReviveVga: see the module header. art()/msk() = REVIVE.DAT in QB PUT layout
'----- (int 0 = width*2 bits, int 1 = height, then byte-aligned 2bpp rows; mask
'----- pixel 3 = transparent, 0 = opaque). co/p1-p3 = the room's COLOR/PALETTE.
'----- Palette indices: 0-3 = the room's four CGA colours, 4 = light gray (the
'----- sprite's attr 1), 5 = blue (attr 2), 6 = brown (attr 3). Returns -1 when
'----- it showed the message (screen is back in mode 4 with attrs 1-3 black),
'----- 0 when there is no VGA -- nothing was touched, use the CGA ReviveShow.
FUNCTION ReviveVga% (art() AS INTEGER, msk() AS INTEGER, co AS INTEGER, p1 AS INTEGER, p2 AS INTEGER, p3 AS INTEGER, mvint AS INTEGER, msen AS SINGLE)
	DIM v AS LONG, xr AS INTEGER, yr AS INTEGER, np AS INTEGER
	DIM i AS INTEGER, x AS INTEGER, y AS INTEGER, b AS INTEGER, k AS INTEGER, q AS INTEGER
	DIM ofs AS INTEGER, w AS INTEGER, h AS INTEGER, cx AS INTEGER, cy AS INTEGER, bpr AS INTEGER
	DIM sb AS INTEGER, sa AS INTEGER, ma AS INTEGER, px AS INTEGER, hv AS INTEGER
	DIM lo AS INTEGER, hi AS INTEGER, mb AS INTEGER, sbt AS INTEGER
	DIM kk AS STRING, rt AS SINGLE, el AS SINGLE
	DIM cmx AS INTEGER, cmy AS INTEGER, nmx AS INTEGER, nmy AS INTEGER, mbt AS INTEGER, cdrn AS INTEGER
	DIM cc(0 TO 3) AS INTEGER
	DIM cbuf(0 TO 47) AS LONG
	'----- far heap is tight on the 486 (~43 KB free in-game, VGA.LOG): the
	'----- framebuffer copy is packed two bytes per int (16 KB) and the sprite
	'----- bytes are split on the fly -- ~18 KB in all
	REDIM cga(0 TO 8191) AS INTEGER
	REDIM lut(0 TO 255, 0 TO 1) AS INTEGER
	REDIM row(0 TO 159) AS INTEGER
	REDIM pal(0 TO 255) AS tRGB
	ReviveVga% = 0
	'----- sprite geometry; bail out on garbage data (CGA version copes)
	w = art(0) \ 2: h = art(1): bpr = (art(0) + 7) \ 8
	IF w < 1 OR w > 320 OR h < 1 OR h > 200 THEN EXIT FUNCTION
	cx = (320 - w) \ 2: cy = (200 - h) \ 2
	'----- 1. snapshot the CGA framebuffer: both interleaves, the full 16 KB,
	'----- byte pairs packed little-endian into signed ints
	CALL CgaSnap(cga())
	'----- 2. mode 13h -- or no VGA: leave with nothing changed
	v = VgaOpen&(320, xr, yr, np)
	IF v = 0 THEN EXIT FUNCTION
	uglSetWrkPage 0
	uglSetVisPage 0
	'----- 3. palette first (the mode set left VRAM black), so nothing shows in
	'----- the default VGA colours while the rows go in
	cc(0) = co: cc(1) = p1: cc(2) = p2: cc(3) = p3
	cc(4) = 7: cc(5) = 1: cc(6) = 6
	CALL VgaPalSet(cc(), 7)
	'----- 4. byte -> 4 pixels lookup: two ints of two 8-bit indices each
	'----- (little-endian: pixel 0 in the low byte), i.e. the row buffer layout
	CALL CgaLut(lut())
	'----- 5. the screen, one row at a time: CGA row (y\2)*80 in interleave
	'----- (y AND 1) = 40 packed ints -> 320 indices 0-3; the message row laid
	'----- over it. QB's \ is signed, so the high byte is split by hand.
	FOR y = 0 TO 199
		ofs = (y \ 2) * 40 + (y AND 1) * 4096
		k = 0
		FOR x = 0 TO 39
			hv = cga(ofs + x)
			lo = hv AND 255
			hi = (hv AND &H7F00) \ 256
			IF hv < 0 THEN hi = hi + 128
			row(k) = lut(lo, 0): row(k + 1) = lut(lo, 1)
			row(k + 2) = lut(hi, 0): row(k + 3) = lut(hi, 1)
			k = k + 4
		NEXT
		IF y >= cy AND y < cy + h THEN
			sb = 4 + (y - cy) * bpr
			FOR x = 0 TO w - 1
				IF (x AND 3) = 0 THEN
					'----- next sprite/mask byte (byte q of the PUT array)
					q = sb + (x \ 4)
					hv = msk(q \ 2)
					IF (q AND 1) THEN
						mb = (hv AND &H7F00) \ 256
						IF hv < 0 THEN mb = mb + 128
					ELSE
						mb = hv AND 255
					END IF
					hv = art(q \ 2)
					IF (q AND 1) THEN
						sbt = (hv AND &H7F00) \ 256
						IF hv < 0 THEN sbt = sbt + 128
					ELSE
						sbt = hv AND 255
					END IF
				END IF
				ma = lut(mb, (x AND 3) \ 2)
				IF (x AND 1) THEN ma = ma \ 256 ELSE ma = ma AND 255
				IF ma = 0 THEN
					sa = lut(sbt, (x AND 3) \ 2)
					IF (x AND 1) THEN sa = sa \ 256 ELSE sa = sa AND 255
					IF sa THEN sa = sa + 3
					px = cx + x: k = px \ 2
					IF (px AND 1) THEN row(k) = (row(k) AND 255) OR (sa * 256) ELSE row(k) = (row(k) AND &HFF00) OR sa
				END IF
			NEXT
		END IF
		uglRowWriteBuff v, 0, y, 320, UGL.BF.8BIT, row(0)
	NEXT
	'----- 6. same dismissal contract as the CGA ReviveShow: mashed keys and a
	'----- held button are not a dismissal; then a fresh key / click, but the
	'----- message stays up at least a full second
	DO
		kk = INKEY$
	LOOP WHILE kk <> ""
	cdrn = 0
	IF msen = 1 THEN
		DO
			CALL MouseRead(nmx, nmy, mbt)
		LOOP WHILE (mbt AND 1) <> 0
		cmx = nmx \ 2: cmy = nmy
		IF cmx > 312 THEN cmx = 312
		IF cmy > 192 THEN cmy = 192
		GOSUB rvgdraw
	END IF
	rt = TIMER
	rvgwait:
	kk = INKEY$
	IF kk <> "" THEN GOTO rvgdone
	IF msen = 1 THEN
		GOSUB rvgtrack
		IF (mbt AND 1) <> 0 THEN GOTO rvgdone
	END IF
	GOTO rvgwait
	rvgdone:
	DO
		el = TIMER - rt
		IF el < 0 THEN el = el + 86400
		IF el >= 1 THEN EXIT DO
		IF msen = 1 THEN GOSUB rvgtrack
	LOOP
	'----- 7. back to mode 4: attrs 1-3 black BEFORE the framebuffer goes back so
	'----- the room never flashes in the BIOS default cyan/magenta/white; the
	'----- caller's rmpal sets the real colours
	CALL VgaClose
	PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	DEF SEG = &HB800
	FOR i = 0 TO 8191
		hv = cga(i)
		hi = (hv AND &H7F00) \ 256
		IF hv < 0 THEN hi = hi + 128
		POKE i * 2, hv AND 255
		POKE i * 2 + 1, hi
	NEXT
	DEF SEG
	ReviveVga% = -1
	EXIT FUNCTION

	'----- poll the mouse; move the software cursor when it changed
	rvgtrack:
	CALL MouseRead(nmx, nmy, mbt)
	nmx = nmx \ 2
	IF nmx > 312 THEN nmx = 312
	IF nmy > 192 THEN nmy = 192
	IF nmx <> cmx OR nmy <> cmy THEN GOSUB rvgerase: cmx = nmx: cmy = nmy: GOSUB rvgdraw
	RETURN

	'----- the game's NW-arrow cursor (brown outline, light gray fill) with a
	'----- 6x8 save-under read back pixel by pixel
	rvgdraw:
	k = 0
	FOR y = 0 TO 7
		FOR x = 0 TO 5
			cbuf(k) = uglPGet(v, cmx + x, cmy + y): k = k + 1
		NEXT
	NEXT
	uglPSet v, cmx, cmy, 6
	uglPSet v, cmx, cmy + 1, 6: uglPSet v, cmx + 1, cmy + 1, 6
	uglPSet v, cmx, cmy + 2, 6: uglPSet v, cmx + 2, cmy + 2, 6
	uglPSet v, cmx, cmy + 3, 6: uglPSet v, cmx + 3, cmy + 3, 6
	uglPSet v, cmx, cmy + 4, 6: uglPSet v, cmx + 4, cmy + 4, 6
	uglPSet v, cmx, cmy + 5, 6: uglPSet v, cmx + 2, cmy + 5, 6: uglPSet v, cmx + 3, cmy + 5, 6
	uglPSet v, cmx, cmy + 6, 6: uglPSet v, cmx + 1, cmy + 6, 6
	uglPSet v, cmx + 1, cmy + 2, 4
	uglPSet v, cmx + 1, cmy + 3, 4: uglPSet v, cmx + 2, cmy + 3, 4
	uglPSet v, cmx + 1, cmy + 4, 4: uglPSet v, cmx + 2, cmy + 4, 4: uglPSet v, cmx + 3, cmy + 4, 4
	uglPSet v, cmx + 1, cmy + 5, 4
	cdrn = 1
	RETURN
	rvgerase:
	IF cdrn = 1 THEN
		k = 0
		FOR y = 0 TO 7
			FOR x = 0 TO 5
				uglPSet v, cmx + x, cmy + y, cbuf(k): k = k + 1
			NEXT
		NEXT
	END IF
	cdrn = 0
	RETURN
END FUNCTION

'----- CGA framebuffer helpers shared by the mode-13h overlays (ReviveVga,
'----- IntroTalk). CgaSnap: B800 (both interleaves, 16 KB) into cga() packed
'----- two bytes per int. CgaLut: byte -> 4 indices table, two ints of two
'----- 8-bit indices each, pixel 0 in the low byte = the row buffer layout.
'----- CgaRows: rows y0..y1 of the snapshot rewritten on the video DC over
'----- the 8-pixel-aligned span covering x0..x1 (also the sprite "erase").
SUB CgaSnap (cga() AS INTEGER)
	DIM i AS INTEGER, hi AS INTEGER
	DEF SEG = &HB800
	FOR i = 0 TO 8191
		hi = PEEK(i * 2 + 1)
		IF hi > 127 THEN hi = hi - 256
		cga(i) = PEEK(i * 2) + hi * 256
	NEXT
	DEF SEG
END SUB

SUB CgaLut (lut() AS INTEGER)
	DIM b AS INTEGER
	FOR b = 0 TO 255
		lut(b, 0) = (b \ 64) + ((b \ 16) AND 3) * 256
		lut(b, 1) = ((b \ 4) AND 3) + (b AND 3) * 256
	NEXT
END SUB

SUB CgaRows (v AS LONG, cga() AS INTEGER, lut() AS INTEGER, row() AS INTEGER, y0 AS INTEGER, y1 AS INTEGER, x0 AS INTEGER, x1 AS INTEGER)
	DIM y AS INTEGER, j AS INTEGER, j0 AS INTEGER, j1 AS INTEGER, k AS INTEGER
	DIM hv AS INTEGER, lo AS INTEGER, hi AS INTEGER, ofs AS INTEGER, xs AS INTEGER, npx AS INTEGER
	j0 = x0 \ 8: j1 = x1 \ 8
	IF j0 < 0 THEN j0 = 0
	IF j1 > 39 THEN j1 = 39
	xs = j0 * 8: npx = (j1 - j0 + 1) * 8
	FOR y = y0 TO y1
		ofs = (y \ 2) * 40 + (y AND 1) * 4096
		FOR j = j0 TO j1
			hv = cga(ofs + j)
			lo = hv AND 255
			hi = (hv AND &H7F00) \ 256
			IF hv < 0 THEN hi = hi + 128
			k = j * 4
			row(k) = lut(lo, 0): row(k + 1) = lut(lo, 1)
			row(k + 2) = lut(hi, 0): row(k + 3) = lut(hi, 1)
		NEXT
		uglRowWriteBuff v, xs, y, npx, UGL.BF.8BIT, row(j0 * 4)
	NEXT
END SUB

'----- VgaPalSet: indices 0..n-1 from CGA colour numbers cc(), the rest black
SUB VgaPalSet (cc() AS INTEGER, n AS INTEGER)
	DIM i AS INTEGER, c AS INTEGER
	REDIM pal(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		pal(i).red = CHR$(0): pal(i).green = CHR$(0): pal(i).blue = CHR$(0)
	NEXT
	FOR i = 0 TO n - 1
		c = cc(i) AND 15
		CALL CgaRGB(c, pal(i))
	NEXT
	uglPalSetBuff 0, 256, pal(0)
END SUB

'----- PutByte: byte q (0-based, header included) of a SCREEN 1 PUT array --
'----- QB's \ is signed, so the high byte is split by hand
FUNCTION PutByte% (arr() AS INTEGER, q AS INTEGER)
	DIM hv AS INTEGER, b AS INTEGER
	hv = arr(q \ 2)
	IF (q AND 1) THEN
		b = (hv AND &H7F00) \ 256
		IF hv < 0 THEN b = b + 128
	ELSE
		b = hv AND 255
	END IF
	PutByte% = b
END FUNCTION

'----- VgaArt: a SCREEN 1 PUT array (2bpp; ints ao.. of art(), and with um <> 0
'----- ints mo.. of msk() -- mask 0 = opaque, 3 = transparent, the game's PUT
'----- AND / PUT OR pair) at (x0,y0), attrs mapped to indices through cmap()
SUB VgaArt (v AS LONG, x0 AS INTEGER, y0 AS INTEGER, art() AS INTEGER, ao AS INTEGER, msk() AS INTEGER, mo AS INTEGER, um AS INTEGER, cmap() AS INTEGER)
	DIM w AS INTEGER, h AS INTEGER, bpr AS INTEGER, x AS INTEGER, y AS INTEGER
	DIM q AS INTEGER, sb AS INTEGER, mb AS INTEGER, sa AS INTEGER, ma AS INTEGER, dv AS INTEGER
	DIM sv(0 TO 3) AS INTEGER
	sv(0) = 64: sv(1) = 16: sv(2) = 4: sv(3) = 1
	w = art(ao) \ 2: h = art(ao + 1): bpr = (art(ao) + 7) \ 8
	mb = 0: sb = 0
	FOR y = 0 TO h - 1
		FOR x = 0 TO w - 1
			IF (x AND 3) = 0 THEN
				q = 4 + y * bpr + (x \ 4)
				sb = PutByte%(art(), ao * 2 + q)
				IF um <> 0 THEN mb = PutByte%(msk(), mo * 2 + q)
			END IF
			dv = sv(x AND 3)
			ma = (mb \ dv) AND 3
			IF ma = 0 THEN
				sa = (sb \ dv) AND 3
				uglPSet v, x0 + x, y0 + y, cmap(sa)
			END IF
		NEXT
	NEXT
END SUB

'----- VgaText / VgaTextW / VgaWrap: the game's bitmap font (font.txt layout,
'----- GAME3 drawChar) on a uGL DC. Plain text only (no ~ _ | codes); space =
'----- 4 px, glyph advance = width + 1; a backslash in VgaWrap forces a line
'----- break (as in drawWrap).
SUB VgaText (v AS LONG, x AS INTEGER, y AS INTEGER, s AS STRING, clr AS INTEGER, fd() AS INTEGER)
	DIM i AS INTEGER, cx AS INTEGER, cc AS INTEGER, w AS INTEGER, hh AS INTEGER, di AS INTEGER
	DIM r AS INTEGER, c AS INTEGER, pat AS INTEGER, bit AS INTEGER, msb AS INTEGER
	hh = fd(0): cx = x
	FOR i = 1 TO LEN(s)
		cc = ASC(MID$(s, i, 1))
		IF cc = 32 THEN
			cx = cx + 4
		ELSE
			di = cc * (hh + 1): w = fd(di)
			IF w > 0 AND w < 16 THEN
				msb = 1
				FOR c = 2 TO w
					msb = msb * 2
				NEXT
				FOR r = 0 TO hh - 1
					pat = fd(di + 1 + r)
					IF pat <> 0 THEN
						bit = msb
						FOR c = 0 TO w - 1
							IF (pat AND bit) <> 0 THEN uglPSet v, cx + c, y + r, clr
							bit = bit \ 2
						NEXT
					END IF
				NEXT
			END IF
			IF w = 0 THEN w = 3
			cx = cx + w + 1
		END IF
	NEXT
END SUB

FUNCTION VgaTextW% (s AS STRING, fd() AS INTEGER)
	DIM i AS INTEGER, cc AS INTEGER, w AS INTEGER, tot AS INTEGER, hh AS INTEGER
	hh = fd(0): tot = 0
	FOR i = 1 TO LEN(s)
		cc = ASC(MID$(s, i, 1))
		IF cc = 32 THEN
			tot = tot + 4
		ELSE
			w = fd(cc * (hh + 1))
			IF w = 0 THEN w = 3
			tot = tot + w + 1
		END IF
	NEXT
	VgaTextW% = tot
END FUNCTION

'----- VgaWrapSplit: word-wrap s into lines() (at most UBOUND(lines) + 1 of
'----- them, the rest dropped), n = how many; a backslash forces a break
SUB VgaWrapSplit (s AS STRING, maxpx AS INTEGER, fd() AS INTEGER, lines() AS STRING, n AS INTEGER)
	DIM i AS INTEGER, ww AS INTEGER, lw AS INTEGER, mx AS INTEGER
	DIM ch AS STRING, word AS STRING, ln AS STRING, brc AS STRING
	n = 0: mx = UBOUND(lines) + 1
	ln = "": lw = 0: word = "": brc = CHR$(92)
	FOR i = 1 TO LEN(s) + 1
		IF i <= LEN(s) THEN ch = MID$(s, i, 1) ELSE ch = " "
		IF ch = " " OR ch = brc THEN
			IF LEN(word) > 0 THEN
				ww = VgaTextW%(word, fd())
				IF lw = 0 THEN
					ln = word: lw = ww
				ELSEIF lw + 4 + ww > maxpx THEN
					IF n < mx THEN lines(n) = ln: n = n + 1
					ln = word: lw = ww
				ELSE
					ln = ln + " " + word: lw = lw + 4 + ww
				END IF
				word = ""
			END IF
			IF ch = brc THEN
				IF n < mx THEN lines(n) = ln: n = n + 1
				ln = "": lw = 0
			END IF
		ELSE
			word = word + ch
		END IF
	NEXT
	IF LEN(ln) > 0 AND n < mx THEN lines(n) = ln: n = n + 1
END SUB

SUB VgaWrap (v AS LONG, x AS INTEGER, y AS INTEGER, s AS STRING, clr AS INTEGER, maxpx AS INTEGER, lineh AS INTEGER, fd() AS INTEGER)
	DIM i AS INTEGER, n AS INTEGER
	DIM lines(0 TO 7) AS STRING
	CALL VgaWrapSplit(s, maxpx, fd(), lines(), n)
	FOR i = 0 TO n - 1
		CALL VgaText(v, x, y + i * lineh, lines(i), clr, fd())
	NEXT
END SUB

'----- VgaType: VgaWrap as a typewriter -- one glyph at a time, each letter a
'----- step of the intro's warble (SOUND is foreground, so the notes also pace
'----- it: ~3 short notes + a silent one per letter, FPU-free). A key pressed
'----- while typing finishes the line at once and comes back in k ("" = none)
'----- so the caller can treat 's' as the skip.
SUB VgaType (v AS LONG, x AS INTEGER, y AS INTEGER, s AS STRING, clr AS INTEGER, maxpx AS INTEGER, lineh AS INTEGER, fd() AS INTEGER, f3 AS SINGLE, k AS STRING)
	DIM i AS INTEGER, j AS INTEGER, n AS INTEGER, cx AS INTEGER, cy AS INTEGER
	DIM tw AS INTEGER, fast AS INTEGER, ch AS STRING
	DIM lines(0 TO 7) AS STRING
	CALL VgaWrapSplit(s, maxpx, fd(), lines(), n)
	k = "": fast = 0: tw = 50
	FOR i = 0 TO n - 1
		cx = x: cy = y + i * lineh
		FOR j = 1 TO LEN(lines(i))
			ch = MID$(lines(i), j, 1)
			CALL VgaText(v, cx, cy, ch, clr, fd())
			cx = cx + VgaTextW%(ch, fd())
			IF fast = 0 THEN
				IF ch <> " " THEN
					SOUND f3, .05
					SOUND tw, .05
					SOUND (450 - tw) / 2, .05
					tw = tw + 10
					IF tw > 250 THEN tw = 50
				END IF
				'----- the pace: ~27 ms of silence (half a clock tick) per letter
				'----- on top of the ~8 ms warble step
				SOUND 32767, .5
				k = INKEY$
				IF k <> "" THEN fast = 1
			END IF
		NEXT
	NEXT
END SUB

'----- VgaWarble: the intro's speech / footstep warble (GAME.BAS 17850)
SUB VgaWarble (f3 AS SINGLE)
	DIM tw AS INTEGER
	FOR tw = 50 TO 250 STEP 10
		SOUND f3, .05
		SOUND tw, .05
		SOUND (450 - tw) / 2, .05
	NEXT
END SUB

'----- VgaMark: the "press a key" triangle (4 x 7, pointing right) at (x,y)
'----- in colour clr; 0 erases it
SUB VgaMark (v AS LONG, x AS INTEGER, y AS INTEGER, clr AS INTEGER)
	DIM c AS INTEGER, r AS INTEGER
	FOR c = 0 TO 3
		FOR r = c TO 6 - c
			uglPSet v, x + c, y + r, clr
		NEXT
	NEXT
END SUB

'----- IntroTalk: see the module header. fd() = the game's font.txt glyphs,
'----- f3 = the warble base tone. Returns 0 = not shown (no VGA, or the
'----- script / heads missing) so GAME.BAS runs the CGA walk + TALK.PIC;
'----- 1 = done (mode 4 again, VRAM black -- the title screen BLOADs next);
'----- 2 = 's' pressed, the intro's skip.
FUNCTION IntroTalk% (fd() AS INTEGER, f3 AS SINGLE)
	DIM v AS LONG, xr AS INTEGER, yr AS INTEGER, np AS INTEGER, fh AS INTEGER
	DIM i AS INTEGER, j AS INTEGER, n AS INTEGER, tc AS INTEGER, fr AS INTEGER, res AS INTEGER
	DIM ln AS STRING, k AS STRING
	DIM bx1 AS INTEGER, by1 AS INTEGER, bx2 AS INTEGER, by2 AS INTEGER
	DIM hx AS INTEGER, tx AS INTEGER, tw AS INTEGER, nw AS INTEGER, mk AS INTEGER
	DIM rt AS SINGLE, el AS SINGLE
	DIM cc(0 TO 4) AS INTEGER, cmRoom(0 TO 3) AS INTEGER, cmUI(0 TO 3) AS INTEGER, cmHead(0 TO 3) AS INTEGER
	DIM spk(0 TO 15) AS STRING, txt(0 TO 15) AS STRING
	IntroTalk% = 0
	IF FileExists%("INTROTLK.TXT") = 0 THEN EXIT FUNCTION
	IF FileExists%("HEADYOU.PCT") = 0 THEN EXIT FUNCTION
	IF FileExists%("HEADJAM.PCT") = 0 THEN EXIT FUNCTION
	'----- the script: "Y|text" / "J|text", ";" comments, up to 16 lines
	n = 0
	fh = FREEFILE
	OPEN "INTROTLK.TXT" FOR INPUT AS #fh
	DO WHILE NOT EOF(fh)
		LINE INPUT #fh, ln
		IF LEN(ln) >= 3 AND n < 16 THEN
			IF LEFT$(ln, 1) <> ";" AND MID$(ln, 2, 1) = "|" THEN
				spk(n) = UCASE$(LEFT$(ln, 1)): txt(n) = MID$(ln, 3): n = n + 1
			END IF
		END IF
	LOOP
	CLOSE #fh
	IF n = 0 THEN EXIT FUNCTION
	REDIM cga(0 TO 8191) AS INTEGER
	REDIM lut(0 TO 255, 0 TO 1) AS INTEGER
	REDIM row(0 TO 159) AS INTEGER
	REDIM r1(0 TO 125) AS INTEGER, r2(0 TO 125) AS INTEGER
	REDIM mr1(0 TO 125) AS INTEGER, mr2(0 TO 125) AS INTEGER
	REDIM jr(0 TO 125) AS INTEGER, mjr(0 TO 125) AS INTEGER
	REDIM hdY(0 TO 513) AS INTEGER, hdJ(0 TO 513) AS INTEGER
	REDIM cor(0 TO 63) AS INTEGER
	REDIM non(0 TO 1) AS INTEGER
	'----- art: Joe's two walk frames + masks (GAME.BAS 18310's files), the
	'----- heads, the dialog corner ornaments
	fh = FREEFILE
	OPEN "JOEW2.PCT" FOR INPUT AS #fh
	FOR i = 0 TO 125
		INPUT #fh, r1(i), r2(i)
	NEXT
	CLOSE #fh
	OPEN "JOEW2.MSK" FOR INPUT AS #fh
	FOR i = 0 TO 125
		INPUT #fh, mr1(i), mr2(i)
	NEXT
	CLOSE #fh
	'----- Joe standing, facing right (JOED column 3 of down/up/right/left/
	'----- dl/dr/ul/ur -- GAME.BAS joeface): he turns to James for the talk
	OPEN "JOED.PCT" FOR INPUT AS #fh
	FOR i = 0 TO 125
		INPUT #fh, t1, t2, jr(i), t4, t5, t6, t7, t8
	NEXT
	CLOSE #fh
	OPEN "JOED.MSK" FOR INPUT AS #fh
	FOR i = 0 TO 125
		INPUT #fh, t1, t2, mjr(i), t4, t5, t6, t7, t8
	NEXT
	CLOSE #fh
	OPEN "HEADYOU.PCT" FOR INPUT AS #fh
	FOR i = 0 TO 513
		INPUT #fh, hdY(i)
	NEXT
	CLOSE #fh
	OPEN "HEADJAM.PCT" FOR INPUT AS #fh
	FOR i = 0 TO 513
		INPUT #fh, hdJ(i)
	NEXT
	CLOSE #fh
	OPEN "DLGCOR.PCT" FOR INPUT AS #fh
	FOR i = 0 TO 15
		INPUT #fh, cor(i), cor(16 + i), cor(32 + i), cor(48 + i)
	NEXT
	CLOSE #fh
	'----- the hall: snapshot the CGA BLOAD, then mode 13h (0 = no VGA: nothing
	'----- has been touched yet, the CGA scene takes over)
	CALL CgaSnap(cga())
	v = VgaOpen&(320, xr, yr, np)
	IF v = 0 THEN EXIT FUNCTION
	uglSetWrkPage 0
	uglSetVisPage 0
	CALL VgaPalBlack
	'----- palette: 0-3 = the hall (COLOR 0 / PALETTE 8,1,6), 4 = light gray.
	'----- Art maps: room art as is; UI art (DLGCOR, the save/load palette
	'----- 1=dkgray 2=ltgray 3=brown); heads 1=ltgray 2=blue 3=brown
	cc(0) = 0: cc(1) = 8: cc(2) = 1: cc(3) = 6: cc(4) = 7
	FOR i = 0 TO 3
		cmRoom(i) = i
	NEXT
	cmUI(0) = 0: cmUI(1) = 1: cmUI(2) = 4: cmUI(3) = 3
	cmHead(0) = 0: cmHead(1) = 4: cmHead(2) = 2: cmHead(3) = 3
	CALL CgaLut(lut())
	CALL CgaRows(v, cga(), lut(), row(), 0, 199, 0, 319)
	CALL VgaPalSet(cc(), 5)
	'----- the walk, GAME.BAS 18310's timing: frame 1 at tc, frame 2 at tc-2,
	'----- a warble + two silent SOUNDs per step, the step erased before the
	'----- next; the conversation when frame 1 stands at 130 (Joe stays up)
	bx1 = 8: by1 = 4: bx2 = 311: by2 = 95
	res = 1
	tc = 150: fr = 1
	DO
		IF fr = 1 THEN
			CALL VgaArt(v, 143, tc, r1(), 0, mr1(), 0, 1, cmRoom())
		ELSE
			CALL VgaArt(v, 143, tc, r2(), 0, mr2(), 0, 1, cmRoom())
		END IF
		IF INKEY$ = "s" THEN res = 2: EXIT DO
		CALL VgaWarble(f3)
		FOR i = 1 TO 2
			SOUND 32676, .3
		NEXT
		IF fr = 1 AND tc = 130 THEN
			'----- Joe turns to face James (standing, right) for the talk; the
			'----- erase after the conversation puts the walk frame back
			CALL CgaRows(v, cga(), lut(), row(), tc, tc + 30, 143, 173)
			CALL VgaArt(v, 143, tc, jr(), 0, mjr(), 0, 1, cmRoom())
			FOR i = 0 TO n - 1
				'----- the box: DrawYNBox's border (dk / black / dk / light,
				'----- black fill) with the DLGCOR corner ornaments
				uglRect v, bx1, by1, bx2, by2, 1
				uglRect v, bx1 + 1, by1 + 1, bx2 - 1, by2 - 1, 0
				uglRect v, bx1 + 2, by1 + 2, bx2 - 2, by2 - 2, 1
				uglRect v, bx1 + 3, by1 + 3, bx2 - 3, by2 - 3, 4
				uglRectF v, bx1 + 4, by1 + 4, bx2 - 4, by2 - 4, 0
				CALL VgaArt(v, bx1, by2 - 8, cor(), 0, non(), 0, 0, cmUI())
				CALL VgaArt(v, bx2 - 8, by2 - 8, cor(), 16, non(), 0, 0, cmUI())
				CALL VgaArt(v, bx1, by1, cor(), 32, non(), 0, 0, cmUI())
				CALL VgaArt(v, bx2 - 8, by1, cor(), 48, non(), 0, 0, cmUI())
				'----- the speaker's head on their side of the hall (you come in
				'----- on the left, James waits on the right), the name under it,
				'----- the line wrapped beside it
				IF spk(i) = "J" THEN
					hx = bx2 - 9 - 63
					tx = bx1 + 9: tw = hx - 9 - tx
					CALL VgaArt(v, hx, by1 + 8, hdJ(), 0, non(), 0, 0, cmHead())
					ln = "James"
				ELSE
					hx = bx1 + 9
					tx = hx + 64 + 9: tw = bx2 - 9 - tx
					CALL VgaArt(v, hx, by1 + 8, hdY(), 0, non(), 0, 0, cmHead())
					ln = "You"
				END IF
				CALL VgaText(v, hx + 32 - VgaTextW%(ln, fd()) \ 2, by1 + 8 + 64 + 2, ln, 3, fd())
				'----- the line types itself out, each letter a step of the warble
				'----- (the old talk scene's voice); a key finishes it at once...
				DO
					k = INKEY$
				LOOP WHILE k <> ""
				CALL VgaType(v, tx, by1 + 12, txt(i), 4, tw, fd(0) + 2, fd(), f3, k)
				IF k = "s" THEN res = 2: EXIT FOR
				k = ""
				'----- ...then any key = next line, 's' = skip the intro, with the
				'----- marker blinking in the corner meanwhile
				mk = 1: CALL VgaMark(v, bx2 - 14, by2 - 14, 3)
				rt = TIMER
				DO WHILE k = ""
					el = TIMER - rt
					IF el < 0 OR el >= .4 THEN
						rt = TIMER: mk = 1 - mk
						CALL VgaMark(v, bx2 - 14, by2 - 14, mk * 3)
					END IF
					k = INKEY$
				LOOP
				IF k = "s" THEN res = 2: EXIT FOR
			NEXT
			'----- the box away (ENTER.PIC is black above the hall)
			uglRectF v, bx1, by1, bx2, by2, 0
			IF res = 2 THEN EXIT DO
		END IF
		CALL CgaRows(v, cga(), lut(), row(), tc, tc + 30, 143, 173)
		tc = tc - 2
		IF fr = 1 THEN fr = 2 ELSE fr = 1
	LOOP WHILE tc >= 116
	'----- back to CGA: mode 4, VRAM and attrs black; the title screen (or the
	'----- skip exit) sets its own palette and BLOADs
	CALL VgaClose
	PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	IntroTalk% = res
END FUNCTION

'----- IntroWalkCga: the CGA enter scene, moved here from GAME.BAS (18310 /
'----- 17590 / 17690) for the 64K code wall; the no-VGA fallback of IntroTalk.
'----- Joe (JOEW2 frames) walks up the hall with the warble per step; halfway
'----- up TALK.PIC in its 7/6/1 palette with the warble voice until a key,
'----- then the screen scrolled away and ENTER.PIC back, then the rest of the
'----- walk. The caller has ENTER.PIC loaded (any palette); this sets 8/1/6.
'----- Returns 2 = 's' pressed (skip the intro), else 1.
FUNCTION IntroWalkCga% (f3 AS SINGLE)
	DIM tc AS INTEGER, i AS INTEGER, fh AS INTEGER, k AS STRING
	REDIM r1(0 TO 130) AS INTEGER, r2(0 TO 130) AS INTEGER
	REDIM mr1(0 TO 130) AS INTEGER, mr2(0 TO 130) AS INTEGER
	REDIM rbg(0 TO 130) AS INTEGER
	IntroWalkCga% = 2
	PALETTE 1, 8: PALETTE 2, 1: PALETTE 3, 6
	fh = FREEFILE
	OPEN "joew2.pct" FOR INPUT AS #fh
	FOR i = 0 TO 125
		INPUT #fh, r1(i), r2(i)
	NEXT
	CLOSE #fh
	OPEN "joew2.msk" FOR INPUT AS #fh
	FOR i = 0 TO 125
		INPUT #fh, mr1(i), mr2(i)
	NEXT
	CLOSE #fh
	tc = 150
	DO
		GET (143, tc)-(173, tc + 30), rbg: PUT (143, tc), mr1, AND: PUT (143, tc), r1, OR
		IF INKEY$ = "s" THEN EXIT FUNCTION
		CALL VgaWarble(f3)
		FOR i = 1 TO 2
			SOUND 32676, .3
		NEXT
		PUT (143, tc), rbg, PSET
		IF tc = 130 THEN
			FOR i = 1 TO 10000
			NEXT
			'----- talk scene
			PALETTE 1, 7: PALETTE 2, 6: PALETTE 3, 1
			DEF SEG = &HB800: BLOAD "talk.pic", 0: DEF SEG
			k = INKEY$
			DO
				CALL VgaWarble(f3)
				SOUND 32576, INT(RND * 9)
				k = INKEY$
				IF k = "s" THEN EXIT FUNCTION
			LOOP WHILE k = ""
			'----- restore the enter scene: scroll the talk away, reload
			FOR i = 1 TO 24
				LOCATE 25, 1
				PRINT " "
			NEXT
			PALETTE 1, 8: PALETTE 2, 1: PALETTE 3, 6
			DEF SEG = &HB800: BLOAD "enter.pic", 0: DEF SEG
		END IF
		tc = tc - 2
		GET (143, tc)-(173, tc + 30), rbg: PUT (143, tc), mr2, AND: PUT (143, tc), r2, OR
		IF INKEY$ = "s" THEN EXIT FUNCTION
		CALL VgaWarble(f3)
		FOR i = 1 TO 2
			SOUND 32676, .3
		NEXT
		PUT (143, tc), rbg, PSET
		tc = tc - 2
	LOOP WHILE tc >= 116
	IntroWalkCga% = 1
END FUNCTION
