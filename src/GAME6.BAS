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
DECLARE SUB MouseRead (x AS INTEGER, y AS INTEGER, b AS INTEGER)

'----- module state for the page-flip viewer (mPal / vbuf in the far heap via REDIM)
REM $DYNAMIC
DIM SHARED mPal(0 TO 255) AS tRGB
DIM SHARED vbuf(0 TO 255) AS INTEGER
REM $STATIC
DIM SHARED mv AS LONG
DIM SHARED mPage AS INTEGER, mNPages AS INTEGER
DIM SHARED mMouse AS INTEGER
DIM SHARED mInit AS INTEGER, mMode AS INTEGER

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


'----- mPal() scaled by f/16 into the DAC (16 = as loaded, 0 = black)
SUB VgaPalApply (f AS INTEGER)
	DIM i AS INTEGER
	REDIM p(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		p(i).red = CHR$(ASC(mPal(i).red) * f \ 16)
		p(i).green = CHR$(ASC(mPal(i).green) * f \ 16)
		p(i).blue = CHR$(ASC(mPal(i).blue) * f \ 16)
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
	CALL VgaPalBlack
	IF uglPutBMPEx(mv, 0, 0, bmp, BMPOPT.NO332) = 0 THEN EXIT FUNCTION
	CALL VgaPalLoad(bmp)
	mPage = n
	LoadView% = -1
END FUNCTION

'----- the manual: 640x480 full-page view flipper (see the header notes)
SUB ManualScroll (msen AS SINGLE)
	DIM xr AS INTEGER, yr AS INTEGER, np AS INTEGER, i AS INTEGER, k AS STRING, code AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, mb AS INTEGER, wasDown AS INTEGER
	DIM r AS RegType, r2 AS RegType, mi AS INTEGER, lf2 AS INTEGER
	REDIM mPal(0 TO 255) AS tRGB
	'----- no manual installed (SETUP skipped disk 2): quiet no-op, stay in the game
	IF NOT FileExists%("manp00.bmp") THEN EXIT SUB
	mv = VgaOpen&(640, xr, yr, np)
	IF mv = 0 THEN EXIT SUB
	IF xr <> 640 THEN CALL ManualSimple(mv, xr, np): EXIT SUB
	'----- count the composed views MANP00.. on disk
	mNPages = 0
	FOR i = 0 TO 29
		IF FileExists%("manp" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".bmp") THEN mNPages = i + 1 ELSE EXIT FOR
	NEXT
	IF mNPages = 0 THEN CALL VgaClose: EXIT SUB
	uglSetWrkPage 0
	uglSetVisPage 0
	CALL VgaPalBlack
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

'----- turn to view n with a fade through black (the page-flip effect)
SUB PageTurn (n AS INTEGER)
	DIM i AS INTEGER
	IF n < 0 OR n > mNPages - 1 OR n = mPage THEN EXIT SUB
	FOR i = 10 TO 0 STEP -1
		CALL VgaSync
		CALL VgaPalApply(i * 16 \ 10)
	NEXT
	CALL VgaPalBlack
	IF LoadView%(n) = 0 THEN i = LoadView%(mPage)
	FOR i = 0 TO 10
		CALL VgaSync
		CALL VgaPalApply(i * 16 \ 10)
	NEXT
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
		'----- the manual: 640x480x256 one page, drops to 320x200 on a VESA miss
		xr = 640: yr = 480: np = 1
		v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		IF v = 0 THEN xr = 320: yr = 200: np = 1: v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
		VgaOpen& = v
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
