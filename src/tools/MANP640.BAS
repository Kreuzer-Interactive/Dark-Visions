'----- MANP640.BAS: standalone viewer for the optimized 640x480 / 64-colour manual.
'----- Loads MANP00.BMP.. full-screen at (0,0) in 640x480x256, fades between pages.
'----- Left/Up/PgUp = previous, Right/Down/PgDn = next, Home/End, Tab/Esc = quit;
'----- mouse: click left half = previous, right half = next. Does NOT touch the game.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'
'$INCLUDE: 'DOS.BI'

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
DECLARE FUNCTION Exists% (fil AS STRING)
DECLARE FUNCTION Load% (n AS INTEGER)
DECLARE SUB Turn (n AS INTEGER)
DECLARE SUB PalLoad (bmp AS STRING)
DECLARE SUB PalApply (f AS INTEGER)
DECLARE SUB PalBlack ()
DECLARE SUB Sync ()

REM $DYNAMIC
DIM SHARED pal(0 TO 255) AS tRGB
REM $STATIC
DIM SHARED v AS LONG, pg AS INTEGER, npg AS INTEGER

DIM i AS INTEGER, k AS STRING, code AS INTEGER, mMouse AS INTEGER, wasDown AS INTEGER
DIM mx AS INTEGER, mb AS INTEGER, mi AS INTEGER, r AS RegType, r2 AS RegType
REDIM pal(0 TO 255) AS tRGB

IF NOT uglInit THEN SCREEN 0: SYSTEM
v = uglSetVideoDC(UGL.8BIT, 640, 480, 1)
IF v = 0 THEN uglEnd: SCREEN 0: SYSTEM
npg = 0
FOR i = 0 TO 29
	IF Exists%("manp" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".bmp") THEN npg = i + 1 ELSE EXIT FOR
NEXT
IF npg = 0 THEN uglRestore: uglEnd: SCREEN 0: SYSTEM
pg = 0
uglSetWrkPage 0
uglSetVisPage 0
CALL PalBlack
IF Load%(0) = 0 THEN uglRestore: uglEnd: SCREEN 0: SYSTEM
'----- mouse (if a driver is present): range to the screen, driver cursor hidden
mi = &H33
r.ax = 0: CALL INTERRUPT(mi, r, r2)
mMouse = (r2.ax <> 0)
IF mMouse THEN
	r.ax = 7: r.cx = 0: r.dx = 639: CALL INTERRUPT(mi, r, r2)
	r.ax = 8: r.cx = 0: r.dx = 479: CALL INTERRUPT(mi, r, r2)
	r.ax = 2: CALL INTERRUPT(mi, r, r2)
END IF
FOR i = 0 TO 10
	CALL Sync
	CALL PalApply(i * 16 \ 10)
NEXT
DO: LOOP WHILE INKEY$ <> ""
wasDown = 0
DO
	k = INKEY$
	IF k = CHR$(9) OR k = CHR$(27) THEN EXIT DO
	IF LEN(k) = 2 THEN
		code = ASC(RIGHT$(k, 1))
		SELECT CASE code
			CASE 75, 72, 73: CALL Turn(pg - 1)
			CASE 77, 80, 81: CALL Turn(pg + 1)
			CASE 71: CALL Turn(0)
			CASE 79: CALL Turn(npg - 1)
		END SELECT
	END IF
	IF mMouse THEN
		mi = &H33: r.ax = 3: CALL INTERRUPT(mi, r, r2): mb = r2.bx: mx = r2.cx
		IF (mb AND 1) THEN
			IF wasDown = 0 THEN IF mx < 320 THEN CALL Turn(pg - 1) ELSE CALL Turn(pg + 1)
			wasDown = -1
		ELSE
			wasDown = 0
		END IF
	END IF
LOOP
FOR i = 10 TO 0 STEP -1
	CALL Sync
	CALL PalApply(i * 16 \ 10)
NEXT
CALL PalBlack
uglRestore
uglEnd
SCREEN 0: WIDTH 80
SYSTEM

FUNCTION Exists% (fil AS STRING)
	DIM f AS FILE
	Exists% = 0
	IF fileOpen(f, fil, F4READ) THEN fileClose f: Exists% = -1
END FUNCTION

'----- load view n full-screen at (0,0), palette from the file
FUNCTION Load% (n AS INTEGER)
	DIM bmp AS STRING, lh AS INTEGER
	bmp = "manp" + RIGHT$("0" + LTRIM$(STR$(n)), 2) + ".bmp"
	Load% = 0
	IF NOT Exists%(bmp) THEN EXIT FUNCTION
	uglSetWrkPage 0
	CALL PalBlack
	IF uglPutBMPEx(v, 0, 0, bmp, BMPOPT.NO332) = 0 THEN
		lh = FREEFILE: OPEN "MANOK.LOG" FOR APPEND AS #lh: PRINT #lh, bmp; " PUT-FAIL": CLOSE #lh
		EXIT FUNCTION
	END IF
	CALL PalLoad(bmp)
	pg = n
	lh = FREEFILE: OPEN "MANOK.LOG" FOR APPEND AS #lh: PRINT #lh, bmp; " OK": CLOSE #lh
	Load% = -1
END FUNCTION

'----- turn to view n with a fade through black
SUB Turn (n AS INTEGER)
	DIM i AS INTEGER
	IF n < 0 OR n > npg - 1 OR n = pg THEN EXIT SUB
	FOR i = 10 TO 0 STEP -1
		CALL Sync
		CALL PalApply(i * 16 \ 10)
	NEXT
	CALL PalBlack
	IF Load%(n) = 0 THEN i = Load%(pg)
	FOR i = 0 TO 10
		CALL Sync
		CALL PalApply(i * 16 \ 10)
	NEXT
END SUB

SUB PalApply (f AS INTEGER)
	DIM i AS INTEGER
	REDIM p(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		p(i).red = CHR$(ASC(pal(i).red) * f \ 16)
		p(i).green = CHR$(ASC(pal(i).green) * f \ 16)
		p(i).blue = CHR$(ASC(pal(i).blue) * f \ 16)
	NEXT
	uglPalSetBuff 0, 256, p(0)
END SUB

SUB PalBlack
	DIM i AS INTEGER
	REDIM blk(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		blk(i).red = CHR$(0): blk(i).green = CHR$(0): blk(i).blue = CHR$(0)
	NEXT
	uglPalSetBuff 0, 256, blk(0)
END SUB

SUB PalLoad (bmp AS STRING)
	DIM i AS INTEGER, fh AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN bmp FOR BINARY AS #fh
	SEEK #fh, 55
	s = INPUT$(1024, #fh)
	CLOSE #fh
	FOR i = 0 TO 255
		pal(i).blue = MID$(s, i * 4 + 1, 1)
		pal(i).green = MID$(s, i * 4 + 2, 1)
		pal(i).red = MID$(s, i * 4 + 3, 1)
	NEXT
	s = ""
END SUB

SUB Sync
	WAIT &H3DA, 8, 8
	WAIT &H3DA, 8
END SUB
