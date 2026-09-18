'----- SCRLTEST.BAS: hardware scrolling probe for the 486's Cirrus Logic card.
'----- The Cirrus VBE 1.2 BIOS says "ok" to INT 10h 4F07h (set display start) but
'----- the picture does not move (VGA.LOG of 2026-09-13). This test scrolls the
'----- 640x480x256 two-page screen (1024-byte pitch, page 1 at VRAM line 480) four
'----- ways and logs the CRTC registers after each, so the log shows what the BIOS
'----- really wrote and the viewer at the monitor sees which method moves the
'----- picture:
'-----   phase 1 (one square top-left)    VESA 4F07h,   0 -> 480 -> 0 lines
'-----   phase 2 (two squares)            direct CRTC,  0 -> 480 -> 0 lines
'-----   phase 3 (three squares)          direct CRTC,  sideways 0 -> 384 -> 0 px
'-----   phase 4 (four squares)           direct CRTC,  4 fast up/down cycles (timed)
'----- Direct CRTC = CR0C/CR0D (start address, in the mode's byte/word/dword unit,
'----- read from CR14 bit 6 / CR17 bit 6) + Cirrus CR1B bits 0,2,3 = address bits
'----- 16,17,18 (+ CR1D bit 7 = bit 19 on GD5430 and later). Cirrus extensions are
'----- unlocked with SR06 = 12h (reads back 12h; any other value locks, reads 0Fh);
'----- CR27 bits 7-2 = chip id (98h = GD5428, 9Ch = GD5429, A0h = GD5430,
'----- A8h = GD5434, ACh = GD5436, B8h = GD5446).
'----- Page 0 = colour bands + a white row marker every 60 lines (n ticks = n*60),
'----- page 1 = the same bands shifted by 8 colours + black markers, so a scroll
'----- from page 0 to page 1 is obvious. Writes SCRLTEST.LOG, auto-exits (~25 s).
'----- Build/run: src\tools\scrltest.conf (DOSBox-X: proves phases 1 and 2 on S3).
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

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

DECLARE SUB Lg (s AS STRING)
DECLARE SUB Hold (secs AS SINGLE)
DECLARE SUB VSync ()
DECLARE SUB Done ()
DECLARE FUNCTION Crt% (idx AS INTEGER)
DECLARE SUB CrtW (idx AS INTEGER, v AS INTEGER)
DECLARE FUNCTION SeqR% (idx AS INTEGER)
DECLARE SUB SeqW (idx AS INTEGER, v AS INTEGER)
DECLARE SUB LogRegs (tag AS STRING)
DECLARE SUB StartDirect (ofs AS LONG)
DECLARE SUB StartVesa (x AS INTEGER, y AS INTEGER)
DECLARE SUB Marker (n AS INTEGER)
DECLARE SUB Bands (pg AS INTEGER, shift AS INTEGER, mk AS INTEGER)

DIM SHARED lf AS INTEGER
DIM SHARED video AS LONG
DIM SHARED pitch AS LONG, unit AS INTEGER, cirrus AS INTEGER, chip AS INTEGER

DIM inf AS TDC
DIM xr AS INTEGER, yr AS INTEGER, np AS INTEGER, i AS INTEGER, y AS INTEGER, x AS INTEGER
DIM t0 AS SINGLE, t1 AS SINGLE, n AS INTEGER, s6 AS INTEGER, s6b AS INTEGER, s6c AS INTEGER

lf = FREEFILE
OPEN "scrltest.log" FOR OUTPUT AS #lf
CALL Lg("SCRLTEST " + DATE$ + " " + TIME$ + " free" + STR$(FRE(-1)))
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CALL Done
xr = 640: yr = 480: np = 2
video = uglSetVideoDC(UGL.8BIT, xr, yr, np)
IF video = 0 THEN
	CALL Lg("640x480x8 2 pages: refused - nothing to scroll into")
	uglEnd
	CALL Done
END IF
uglDCGet video, inf
pitch = inf.bps
CALL Lg("mode 640x480x8 2 pages, bps" + STR$(inf.bps) + " size" + STR$(inf.size))

'----- CRTC addressing unit: CR14 bit 6 = doubleword, else CR17 bit 6 = byte, else word
IF Crt%(&H14) AND &H40 THEN
	unit = 4
ELSEIF Crt%(&H17) AND &H40 THEN
	unit = 1
ELSE
	unit = 2
END IF
'----- Cirrus? SR06 reads 0Fh when locked (after any write but 12h), 12h when unlocked
s6 = SeqR%(6)
CALL SeqW(6, &HA)
s6b = SeqR%(6)
CALL SeqW(6, &H12)
s6c = SeqR%(6)
cirrus = 0: chip = 0
IF s6b = &HF AND s6c = &H12 THEN cirrus = -1: chip = Crt%(&H27)
CALL Lg("SR06 as found " + HEX$(s6) + ", after 0A -> " + HEX$(s6b) + ", after 12 -> " + HEX$(s6c) + "  cirrus" + STR$(cirrus) + " CR27 " + HEX$(chip))
CALL Lg("unit" + STR$(unit) + " bytes (CR14 " + HEX$(Crt%(&H14)) + " CR17 " + HEX$(Crt%(&H17)) + ")  CR13 " + HEX$(Crt%(&H13)) + " CR1B " + HEX$(Crt%(&H1B)) + " CR1D " + HEX$(Crt%(&H1D)))
CALL LogRegs("start as set by uGL")

'----- the pictures: page 0 white markers, page 1 shifted bands + black markers
uglSetVisPage 0
CALL Bands(0, 0, 255)
CALL Bands(1, 8, 0)
uglSetWrkPage 0
CALL Hold(2)

'----- phase 1: VESA 4F07h
CALL Marker(1)
CALL Hold(1)
FOR y = 0 TO 480 STEP 2
	CALL StartVesa(0, y)
	IF y = 480 THEN CALL LogRegs("phase1 vesa y=480")
NEXT
CALL Hold(1)
FOR y = 480 TO 0 STEP -2
	CALL StartVesa(0, y)
NEXT
CALL LogRegs("phase1 vesa back at 0")
CALL Hold(1)

'----- phase 2: direct CRTC, same movement
CALL Marker(2)
CALL Hold(1)
FOR y = 0 TO 480 STEP 2
	CALL StartDirect(y * pitch)
	IF y = 480 THEN CALL LogRegs("phase2 direct y=480")
NEXT
CALL Hold(1)
FOR y = 480 TO 0 STEP -2
	CALL StartDirect(y * pitch)
NEXT
CALL LogRegs("phase2 direct back at 0")
CALL Hold(1)

'----- phase 3: sideways (x in bytes, must be a multiple of the unit)
CALL Marker(3)
CALL Hold(1)
FOR x = 0 TO 384 STEP 4
	CALL StartDirect(CLNG(x))
NEXT
CALL LogRegs("phase3 direct x=384")
CALL Hold(1)
FOR x = 384 TO 0 STEP -4
	CALL StartDirect(CLNG(x))
NEXT
CALL Hold(1)

'----- phase 4: four fast cycles, timed (frames = 2 * 481 / 4 per cycle)
CALL Marker(4)
CALL Hold(1)
n = 0
t0 = TIMER
FOR i = 1 TO 4
	FOR y = 0 TO 480 STEP 4
		CALL StartDirect(y * pitch): n = n + 1
	NEXT
	FOR y = 480 TO 0 STEP -4
		CALL StartDirect(y * pitch): n = n + 1
	NEXT
NEXT
t1 = TIMER - t0
CALL Lg("phase4:" + STR$(n) + " steps in" + STR$(t1) + " s =" + STR$(n / t1) + " steps/s (60 = one per frame)")
CALL StartDirect(0)
CALL LogRegs("end at 0")
CALL Hold(1)
uglRestore
uglEnd
CALL Lg("DONE")
CALL Done

SUB Bands (pg AS INTEGER, shift AS INTEGER, mk AS INTEGER)
	DIM b AS INTEGER, y AS INTEGER, k AS INTEGER, c AS LONG
	uglSetWrkPage pg
	FOR b = 0 TO 14
		c = ((b + shift) MOD 15) * 16 + 20
		uglRectF video, 0, b * 32, 639, b * 32 + 31, c
	NEXT
	'----- row markers every 60 lines: a 3-line bar, then n ticks (n = line / 60)
	FOR y = 0 TO 420 STEP 60
		uglRectF video, 0, y, 639, y + 2, CLNG(mk)
		FOR k = 1 TO y \ 60
			uglRectF video, k * 24, y + 4, k * 24 + 12, y + 14, CLNG(mk)
		NEXT
	NEXT
	uglSetWrkPage 0
END SUB

'----- n black squares top-left of page 0 (visible whenever the start is 0)
SUB Marker (n AS INTEGER)
	DIM k AS INTEGER
	uglSetWrkPage 0
	uglRectF video, 400, 4, 639, 26, 255
	FOR k = 1 TO n
		uglRectF video, 400 + k * 30, 6, 400 + k * 30 + 20, 24, 0
	NEXT
END SUB

'----- direct CRTC display start: ofs = byte offset into video memory
SUB StartDirect (ofs AS LONG)
	DIM u AS LONG, b AS INTEGER
	u = ofs \ unit
	WAIT &H3DA, 8, 8
	CALL CrtW(&HC, (u \ 256) AND 255)
	CALL CrtW(&HD, u AND 255)
	IF cirrus THEN
		b = Crt%(&H1B) AND &HF2
		IF u AND &H10000 THEN b = b OR 1
		IF u AND &H20000 THEN b = b OR 4
		IF u AND &H40000 THEN b = b OR 8
		CALL CrtW(&H1B, b)
		IF chip >= &HA0 THEN
			b = Crt%(&H1D) AND &H7F
			IF u AND &H80000 THEN b = b OR &H80
			CALL CrtW(&H1D, b)
		END IF
	END IF
	WAIT &H3DA, 8
END SUB

'----- VESA VBE 4F07h BL=0: CX = first pixel, DX = first line
SUB StartVesa (x AS INTEGER, y AS INTEGER)
	DIM r AS RegTypeX, r2 AS RegTypeX, vi AS INTEGER
	WAIT &H3DA, 8, 8
	r.ax = &H4F07: r.bx = 0: r.cx = x: r.dx = y
	r.bp = 0: r.si = 0: r.di = 0: r.flags = 0: r.ds = -1: r.es = -1
	vi = &H10
	CALL INTERRUPTX(vi, r, r2)
	WAIT &H3DA, 8
END SUB

SUB LogRegs (tag AS STRING)
	CALL Lg(tag + ": CR0C " + HEX$(Crt%(&HC)) + " CR0D " + HEX$(Crt%(&HD)) + " CR1B " + HEX$(Crt%(&H1B)) + " CR1D " + HEX$(Crt%(&H1D)) + " CR13 " + HEX$(Crt%(&H13)) + " SR06 " + HEX$(SeqR%(6)))
END SUB

FUNCTION Crt% (idx AS INTEGER)
	OUT &H3D4, idx
	Crt% = INP(&H3D5)
END FUNCTION

SUB CrtW (idx AS INTEGER, v AS INTEGER)
	OUT &H3D4, idx
	OUT &H3D5, v
END SUB

FUNCTION SeqR% (idx AS INTEGER)
	OUT &H3C4, idx
	SeqR% = INP(&H3C5)
END FUNCTION

SUB SeqW (idx AS INTEGER, v AS INTEGER)
	OUT &H3C4, idx
	OUT &H3C5, v
END SUB

SUB Done
	CLOSE #lf
	END
END SUB

SUB Hold (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	t9 = TIMER
	DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END SUB

SUB Lg (s AS STRING)
	PRINT #lf, s
END SUB

SUB VSync
	WAIT &H3DA, 8, 8
	WAIT &H3DA, 8
END SUB
