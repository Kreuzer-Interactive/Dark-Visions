'----- MAN800.BAS: standalone 800x600x256 demo of the page-flip manual, to see the
'----- higher-resolution art on the 486. Sets VESA 800x600 one page (600 KB, fits a
'----- 1 MB card; two pages would need 1.2 MB, so one page only), shows each sub-page
'----- (M801H, M801HB, M802H, M802HB - the two comic spreads split top/bottom, 784
'----- wide) centred, with the nav bar at the bottom 20 lines. NO scrolling and NO
'----- page-flip via the card (this Cirrus VESA BIOS honours neither) - each page is
'----- one image at display start 0; a turn fades through black. Keys: Left/Up/PgUp
'----- previous, Right/Down/PgDn next, Home/End, Tab/Esc quit. Logs MAN800.LOG.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'
'$INCLUDE: 'DOS.BI'

CONST barY = 580, barH = 20, scrW = 800, artH = 580
CONST cBlack = 248, cWhite = 249, cLGray = 250, cMGray = 251, cDGray = 252, cParch = 253, cDParch = 254, cRed = 255

DECLARE SUB PalLoad (bmp AS STRING)
DECLARE SUB PalApply (f AS INTEGER)
DECLARE SUB PalBlack ()
DECLARE SUB Sync ()
DECLARE FUNCTION Exists% (fil AS STRING)
DECLARE FUNCTION PName$ (n AS INTEGER)
DECLARE FUNCTION LoadP% (n AS INTEGER)
DECLARE SUB Bar ()
DECLARE SUB Flip (n AS INTEGER)
DECLARE SUB Lg (s AS STRING)

REM $DYNAMIC
DIM SHARED pal(0 TO 255) AS tRGB
REM $STATIC
DIM SHARED v AS LONG, pg AS INTEGER, npg AS INTEGER

DIM i AS INTEGER, k AS STRING, code AS INTEGER, lf AS INTEGER
REDIM pal(0 TO 255) AS tRGB

lf = FREEFILE: OPEN "man800.log" FOR OUTPUT AS #lf: CLOSE #lf
CALL Lg("MAN800 " + DATE$ + " " + TIME$ + " free" + STR$(FRE(-1)))
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): SYSTEM
v = uglSetVideoDC(UGL.8BIT, 800, 600, 1)
IF v = 0 THEN CALL Lg("800x600x256 one page NOT available"): uglEnd: SYSTEM
CALL Lg("800x600x256 set, free" + STR$(FRE(-1)))

'----- count sub-pages present
npg = 0
FOR i = 1 TO 4
	IF Exists%(PName$(i)) THEN npg = i ELSE EXIT FOR
NEXT
IF npg = 0 THEN CALL Lg("no M80*.BMP found"): uglRestore: uglEnd: SYSTEM
CALL Lg("pages" + STR$(npg))

uglSetWrkPage 0
uglSetVisPage 0
CALL PalBlack
IF LoadP%(1) = 0 THEN CALL Lg("page 1 load FAILED"): uglRestore: uglEnd: SYSTEM
CALL Bar
FOR i = 0 TO 10: CALL Sync: CALL PalApply(i * 16 \ 10): NEXT
DO: LOOP WHILE INKEY$ <> ""

DO
	k = INKEY$
	IF k = CHR$(9) OR k = CHR$(27) THEN EXIT DO
	IF LEN(k) = 2 THEN
		code = ASC(RIGHT$(k, 1))
		SELECT CASE code
			CASE 72, 75, 73: CALL Flip(pg - 1)
			CASE 80, 77, 81: CALL Flip(pg + 1)
			CASE 71: CALL Flip(1)
			CASE 79: CALL Flip(npg)
		END SELECT
	END IF
LOOP

FOR i = 10 TO 0 STEP -1: CALL Sync: CALL PalApply(i * 16 \ 10): NEXT
CALL PalBlack
uglRestore
uglEnd
SCREEN 0: WIDTH 80
CALL Lg("DONE")
SYSTEM

'----- nav bar at VRAM lines 580..599: back / forward arrows, one dot per page
SUB Bar
	DIM c AS INTEGER, i AS INTEGER, x AS INTEGER
	REDIM pt(0 TO 2) AS PNT2D
	uglSetWrkPage 0
	uglRectF v, 0, barY, scrW - 1, 599, cDGray
	uglHLine v, 0, barY, scrW - 1, cLGray
	IF pg > 1 THEN c = cParch ELSE c = cMGray
	pt(0).x = 44: pt(0).y = barY + 3: pt(1).x = 44: pt(1).y = barY + 16: pt(2).x = 14: pt(2).y = barY + 10
	uglPolyF v, pt(0), 3, c
	IF pg < npg THEN c = cParch ELSE c = cMGray
	pt(0).x = scrW - 45: pt(0).y = barY + 3: pt(1).x = scrW - 45: pt(1).y = barY + 16: pt(2).x = scrW - 15: pt(2).y = barY + 10
	uglPolyF v, pt(0), 3, c
	x = scrW \ 2 - (npg * 12) \ 2
	FOR i = 1 TO npg
		IF i = pg THEN c = cParch ELSE c = cMGray
		uglRectF v, x, barY + 7, x + 5, barY + 12, c
		x = x + 12
	NEXT
END SUB

FUNCTION Exists% (fil AS STRING)
	DIM f AS FILE
	Exists% = 0
	IF fileOpen(f, fil, F4READ) THEN fileClose f: Exists% = -1
END FUNCTION

'----- fade to black, load sub-page n centred, fade in (the page-flip effect)
SUB Flip (n AS INTEGER)
	DIM i AS INTEGER
	IF n < 1 OR n > npg OR n = pg THEN EXIT SUB
	FOR i = 10 TO 0 STEP -1: CALL Sync: CALL PalApply(i * 16 \ 10): NEXT
	CALL PalBlack
	IF LoadP%(n) = 0 THEN i = LoadP%(pg)
	CALL Bar
	FOR i = 0 TO 10: CALL Sync: CALL PalApply(i * 16 \ 10): NEXT
END SUB

'----- load sub-page n onto page 0, centred in the 0..579 art area, palette -> pal()
FUNCTION LoadP% (n AS INTEGER)
	DIM bmp AS STRING, fh AS INTEGER, w AS LONG, h AS LONG, xo AS INTEGER, yo AS INTEGER
	bmp = PName$(n)
	LoadP% = 0
	IF NOT Exists%(bmp) THEN EXIT FUNCTION
	fh = FREEFILE
	OPEN bmp FOR BINARY AS #fh
	GET #fh, 19, w
	GET #fh, 23, h
	CLOSE #fh
	IF h < 0 THEN h = -h
	xo = (scrW - w) \ 2: IF xo < 0 THEN xo = 0
	yo = (artH - h) \ 2: IF yo < 0 THEN yo = 0
	uglSetWrkPage 0
	CALL PalBlack
	uglRectF v, 0, 0, scrW - 1, 599, cBlack
	IF uglPutBMPEx(v, xo, yo, bmp, BMPOPT.NO332) = 0 THEN EXIT FUNCTION
	CALL PalLoad(bmp)
	pg = n
	CALL Lg("page" + STR$(n) + " " + bmp + " at" + STR$(xo) + "," + STR$(yo) + " size" + STR$(w) + "x" + STR$(h))
	LoadP% = -1
END FUNCTION

SUB Lg (s AS STRING)
	DIM f AS INTEGER
	f = FREEFILE
	OPEN "man800.log" FOR APPEND AS #f
	PRINT #f, s
	CLOSE #f
END SUB

'----- pal() scaled by f/16 into the DAC (16 = as loaded, 0 = black)
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

'----- 256 BGRA entries at file offset 55 (54-byte header) -> pal()
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

FUNCTION PName$ (n AS INTEGER)
	SELECT CASE n
		CASE 1: PName$ = "m801h.bmp"
		CASE 2: PName$ = "m801hb.bmp"
		CASE 3: PName$ = "m802h.bmp"
		CASE 4: PName$ = "m802hb.bmp"
		CASE ELSE: PName$ = ""
	END SELECT
END FUNCTION

SUB Sync
	WAIT &H3DA, 8, 8
	WAIT &H3DA, 8
END SUB
