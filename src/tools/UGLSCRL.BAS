'----- UGLSCRL.BAS: does this card's display actually SCROLL / page-flip?
'----- Sets the same VESA 640x480x256 two-page mode the game uses, fills video
'----- memory with 32-pixel colour bands (a rainbow on page 0, shifted colours on
'----- page 1) plus a white "ruler" bar on each band whose LENGTH = that band's
'----- video-memory line / 2, so the bar at the very top of the screen tells you
'----- which memory line is being shown. Then it steps through phases, each held a
'----- few seconds after N beeps, changing ONLY how the display start is set:
'-----   P1  VESA 4F07h  -> line 0    (baseline: top band = RED, ruler bar tiny)
'-----   P2  VESA 4F07h  -> line 32   (works? top band = GREEN)
'-----   P3  VESA 4F07h  -> line 96   (works? top band = YELLOW)
'-----   P4  uglSetVisPage 1          (page flip works? whole screen shifts colours)
'-----   P5  CRTC 0Ch/0Dh = 8192      (dword-unit card? top = GREEN, line 32)
'-----   P6  CRTC 0Ch/0Dh = 32768     (byte-unit card? top = GREEN, line 32)
'----- If P2/P3 change the top colour, VESA scrolling works. If only P5 or P6 do,
'----- the card scrolls via the CRTC (we can use that). If nothing but P1 ever
'----- shows, the display cannot be moved on this card. Writes UGLSCRL.LOG (the
'----- 4F07h read-backs are logged too). Press any key to stop; loops until then.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

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
DECLARE SUB Lg (s AS STRING)
DECLARE FUNCTION Held% (secs AS SINGLE)
DECLARE SUB Vbe07 (ln AS INTEGER)
DECLARE FUNCTION Vbe07get$ ()
DECLARE SUB Crtc (adr AS LONG)
DECLARE SUB Bands (v AS LONG, pg AS INTEGER, cbas AS INTEGER)
DECLARE SUB VSplit (ln AS INTEGER)
DECLARE SUB Marker (v AS LONG, c AS LONG)

DIM SHARED lf AS INTEGER
DIM v AS LONG, inf AS TDC

lf = FREEFILE
OPEN "uglscrl.log" FOR OUTPUT AS #lf
CLOSE #lf
CALL Lg("UGLSCRL start " + DATE$ + " " + TIME$)
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CLOSE #lf: SYSTEM
v = uglSetVideoDC(UGL.8BIT, 640, 480, 2)
IF v = 0 THEN CALL Lg("640x480x2 not available - test needs it"): uglEnd: CLOSE #lf: SYSTEM
uglDCGet v, inf
CALL Lg("mode set: bps" + STR$(inf.bps) + " pages" + STR$(inf.pages) + " size" + STR$(inf.size))

'----- paint both pages once (page 0 rainbow, page 1 shifted so a flip is obvious)
CALL Bands(v, 0, 0)
CALL Bands(v, 1, 3)
uglSetWrkPage 0
uglSetVisPage 0

'----- each phase draws a full-width MARKER STRIPE at screen rows 464..479 in a
'----- phase colour, using the split screen (VRAM lines 0..15 shown at the bottom
'----- always, unaffected by display start) so you can tell phases apart on film:
'----- P1 red P2 green P3 yellow P4 magenta P5 cyan P6 white. The TOP band colour
'----- tells you whether the display actually moved.
CALL VSplit(463)
DO
	CALL Marker(v, uglColor(UGL.8BIT, 255, 0, 0))
	CALL Vbe07(0)
	CALL Lg("P1 red    4F07 line 0   want top RED         getback:" + Vbe07get$)
	IF Held%(4) THEN EXIT DO

	CALL Marker(v, uglColor(UGL.8BIT, 0, 255, 0))
	CALL Vbe07(32)
	CALL Lg("P2 green  4F07 line 32  VESA scroll? top GREEN getback:" + Vbe07get$)
	IF Held%(4) THEN EXIT DO

	CALL Marker(v, uglColor(UGL.8BIT, 255, 255, 0))
	CALL Vbe07(96)
	CALL Lg("P3 yellow 4F07 line 96  VESA scroll? top YELLOW getback:" + Vbe07get$)
	IF Held%(4) THEN EXIT DO

	CALL Vbe07(0)
	CALL Marker(v, uglColor(UGL.8BIT, 255, 0, 255))
	uglSetVisPage 1
	CALL Lg("P4 magenta uglSetVisPage 1 page flip? colours shift")
	IF Held%(4) THEN EXIT DO
	uglSetVisPage 0

	CALL Marker(v, uglColor(UGL.8BIT, 0, 255, 255))
	CALL Crtc(8192)
	CALL Lg("P5 cyan   CRTC 0C/0D=8192  dword card? top GREEN line32")
	IF Held%(4) THEN EXIT DO

	CALL Marker(v, uglColor(UGL.8BIT, 255, 255, 255))
	CALL Crtc(32768)
	CALL Lg("P6 white  CRTC 0C/0D=32768 byte card? top GREEN line32")
	IF Held%(4) THEN EXIT DO
	CALL Crtc(0)
LOOP

CALL Vbe07(0)
CALL Crtc(0)
uglRestore
uglEnd
SCREEN 0: WIDTH 80
CALL Lg("DONE")
CLOSE #lf
END

'----- 32px colour bands with a white ruler bar (width = VRAM line / 2) on each
SUB Bands (v AS LONG, pg AS INTEGER, cbas AS INTEGER)
	DIM py AS INTEGER, bi AS INTEGER, col AS LONG, w AS INTEGER, vln AS INTEGER
	uglSetWrkPage pg
	bi = 0
	FOR py = 0 TO 479 STEP 32
		SELECT CASE (bi + cbas) MOD 6
			CASE 0: col = uglColor(UGL.8BIT, 255, 0, 0)
			CASE 1: col = uglColor(UGL.8BIT, 0, 255, 0)
			CASE 2: col = uglColor(UGL.8BIT, 0, 0, 255)
			CASE 3: col = uglColor(UGL.8BIT, 255, 255, 0)
			CASE 4: col = uglColor(UGL.8BIT, 0, 255, 255)
			CASE 5: col = uglColor(UGL.8BIT, 255, 255, 255)
		END SELECT
		uglRectF v, 0, py, 639, py + 31, col
		vln = pg * 480 + py
		w = vln \ 2
		IF w > 639 THEN w = 639
		uglRectF v, 0, py, w, py + 3, uglColor(UGL.8BIT, 255, 255, 255)
		uglRectF v, 0, py + 4, w, py + 5, uglColor(UGL.8BIT, 0, 0, 0)
		bi = bi + 1
	NEXT
END SUB

'----- direct CRTC start address: CR0Ch = bits 15..8, CR0Dh = bits 7..0
SUB Crtc (adr AS LONG)
	OUT &H3D4, &HC: OUT &H3D5, (adr \ 256) AND 255
	OUT &H3D4, &HD: OUT &H3D5, adr AND 255
END SUB

'----- phase marker: full-width stripe at VRAM lines 0..15 (shown at the screen
'----- bottom by the split, always visible regardless of display start)
SUB Marker (v AS LONG, c AS LONG)
	uglSetWrkPage 0
	uglRectF v, 0, 0, 639, 15, c
	uglSetWrkPage 0
END SUB

'----- VGA split screen: line compare (18h low 8, 07h bit4 = bit8, 09h bit6 = bit9);
'----- screen lines after ln show VRAM from address 0
SUB VSplit (ln AS INTEGER)
	DIM vv AS INTEGER
	OUT &H3D4, &H18: OUT &H3D5, ln AND 255
	OUT &H3D4, 7: vv = INP(&H3D5)
	IF ln AND 256 THEN vv = vv OR 16 ELSE vv = vv AND &HEF
	OUT &H3D5, vv
	OUT &H3D4, 9: vv = INP(&H3D5)
	IF ln AND 512 THEN vv = vv OR 64 ELSE vv = vv AND &HBF
	OUT &H3D5, vv
END SUB

FUNCTION Held% (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	Held% = 0
	t9 = TIMER
	DO
		IF INKEY$ <> "" THEN Held% = -1: EXIT FUNCTION
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END FUNCTION

SUB Lg (s AS STRING)
	DIM f AS INTEGER
	f = FREEFILE
	OPEN "uglscrl.log" FOR APPEND AS #f
	PRINT #f, s
	CLOSE #f
END SUB

'----- VESA set display start (4F07h BL=0): x pixel 0, scanline ln
SUB Vbe07 (ln AS INTEGER)
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &H4F07: r.bx = 0: r.cx = 0: r.dx = ln
	r.bp = 0: r.si = 0: r.di = 0: r.flags = 0
	CALL INTERRUPT(vi, r, r2)
END SUB

'----- VESA get display start (4F07h BL=1): returns "cx=.. dx=.." (dx should echo the line)
FUNCTION Vbe07get$
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &H4F07: r.bx = 1: r.cx = 0: r.dx = 0
	r.bp = 0: r.si = 0: r.di = 0: r.flags = 0
	CALL INTERRUPT(vi, r, r2)
	Vbe07get$ = "ax " + HEX$(r2.ax) + " cx " + HEX$(r2.cx) + " dx " + HEX$(r2.dx)
END FUNCTION
