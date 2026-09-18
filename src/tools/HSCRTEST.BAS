'----- HSCRTEST.BAS: horizontal page-turn test for the 486 (FPU-FREE - hardware
'----- display-start scroll via the Cirrus CRTC + uGL BMP blits + palette fade, none
'----- of which need a coprocessor, unlike the uGL texture mappers). The effect the
'----- user asked for, per page turn:
'-----   1. nudge the current page LEFT a few px (display start X 0 -> N) while fading
'-----      the palette down to black
'-----   2. at black, load the next page (uGL blit) + its palette (index 0 forced to
'-----      pure black so the exposed right-edge margin stays black)
'-----   3. the next page starts N px left (X = N) and slides to normal (X -> 0) while
'-----      the palette fades up
'----- Cycles MANP00->01->02->00... a few times so you can watch, and logs a pixel in
'----- the off-screen margin (px 700) to see if it reads black or garbage on the real
'----- card. Writes HSCRTEST.LOG. Build/run: src\tools\hscrtest.conf.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

CONST NUDGE = 16                                  '----- how many px the page nudges/slides

DECLARE SUB Lg (s AS STRING)
DECLARE SUB Hold (secs AS SINGLE)
DECLARE FUNCTION CrtcR% (idx AS INTEGER)
DECLARE SUB CrtcW (idx AS INTEGER, v AS INTEGER)
DECLARE FUNCTION SeqR% (idx AS INTEGER)
DECLARE SUB SeqW (idx AS INTEGER, v AS INTEGER)
DECLARE SUB ScrollX (px AS INTEGER)
DECLARE SUB PalApply (f AS INTEGER)
DECLARE FUNCTION LoadPage% (n AS INTEGER)
DECLARE SUB Advance (n AS INTEGER)

DIM SHARED lf AS INTEGER, video AS LONG
DIM SHARED gPitch AS LONG, gUnit AS INTEGER, gCirrus AS INTEGER, gChip AS INTEGER
DIM SHARED mPal(0 TO 255) AS tRGB

DIM inf AS TDC, ps AS STRING * 1024
DIM i AS INTEGER, s6b AS INTEGER, s6c AS INTEGER, rep AS INTEGER, pg AS INTEGER

lf = FREEFILE
OPEN "hscrtest.log" FOR OUTPUT AS #lf
CALL Lg("HSCRTEST " + DATE$ + " " + TIME$)
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CLOSE #lf: END
'----- 2 pages guarantees the 1024-byte pitch (per-line scroll margin); we draw page 0
video = uglSetVideoDC(UGL.8BIT, 640, 480, 2)
IF video = 0 THEN video = uglSetVideoDC(UGL.8BIT, 640, 480, 1)
IF video = 0 THEN CALL Lg("no 640x480"): uglEnd: CLOSE #lf: END
uglDCGet video, inf
gPitch = inf.bps
CALL Lg("mode 640x480 bps(pitch)" + STR$(inf.bps) + "  (margin px per line =" + STR$(inf.bps - 640) + ")")

'----- CRTC addressing unit + Cirrus unlock (for the direct display-start writes)
IF CrtcR%(&H14) AND &H40 THEN gUnit = 4 ELSE IF CrtcR%(&H17) AND &H40 THEN gUnit = 1 ELSE gUnit = 2
CALL SeqW(6, &HA): s6b = SeqR%(6)
CALL SeqW(6, &H12): s6c = SeqR%(6)
gCirrus = 0: gChip = 0
IF s6b = &HF AND s6c = &H12 THEN gCirrus = -1: gChip = CrtcR%(&H27)
CALL Lg("unit" + STR$(gUnit) + " cirrus" + STR$(gCirrus) + " CR27 " + HEX$(gChip))

uglSetWrkPage 0
uglSetVisPage 0
CALL Lg("margin BEFORE clear px(700,240)=" + STR$(uglPGet(video, 700, 240)))
uglClear video, 0
CALL Lg("margin AFTER uglClear px(700,240)=" + STR$(uglPGet(video, 700, 240)) + " (900,300)=" + STR$(uglPGet(video, 900, 300)) + "  [0 = uglClear wiped the margin too]")
CALL ScrollX(0)
IF LoadPage%(0) = 0 THEN CALL Lg("MANP00 load failed"): uglRestore: uglEnd: CLOSE #lf: END
CALL Lg("margin after page load px(700,240)=" + STR$(uglPGet(video, 700, 240)))
FOR i = 0 TO 10: CALL PalApply(i * 16 \ 10): CALL Hold(.03): NEXT
CALL Hold(1.5)

'----- cycle forward through the pages twice with the nudge+fade+slide
FOR rep = 1 TO 6
	pg = (rep) MOD 3
	CALL Advance(pg)
	CALL Hold(1.2)
NEXT
CALL Lg("DONE")
CALL PalApply(0)
uglRestore
uglEnd
CLOSE #lf
END

'----- the page-turn: nudge current left + fade out, swap, slide next in from left + fade up
SUB Advance (n AS INTEGER)
	DIM i AS INTEGER
	'----- 1 + 2: nudge left (X 0->NUDGE) while fading to black
	FOR i = 0 TO 8
		CALL ScrollX(NUDGE * i \ 8)
		CALL PalApply((8 - i) * 16 \ 8)
		CALL Hold(.03)
	NEXT
	'----- 3: black now; load the next page (unseen) + its palette
	IF LoadPage%(n) = 0 THEN i = LoadPage%(n)
	'----- 4: page starts NUDGE px left, slide to 0 while fading up
	FOR i = 0 TO 8
		CALL ScrollX(NUDGE * (8 - i) \ 8)
		CALL PalApply(i * 16 \ 8)
		CALL Hold(.03)
	NEXT
	CALL ScrollX(0)
END SUB

'----- load MANPnn onto page 0, its palette into mPal(), force index 0 pure black
FUNCTION LoadPage% (n AS INTEGER)
	DIM bmp AS STRING, fh AS INTEGER, ps AS STRING * 1024, i AS INTEGER
	bmp = "manp" + RIGHT$("0" + LTRIM$(STR$(n)), 2) + ".bmp"
	LoadPage% = 0
	uglSetWrkPage 0
	IF uglPutBMPEx(video, 0, 0, bmp, BMPOPT.NO332) = 0 THEN EXIT FUNCTION
	fh = FREEFILE
	OPEN bmp FOR BINARY AS #fh
	SEEK #fh, 55
	ps = INPUT$(1024, #fh)
	CLOSE #fh
	FOR i = 0 TO 255
		mPal(i).blue = MID$(ps, i * 4 + 1, 1): mPal(i).green = MID$(ps, i * 4 + 2, 1): mPal(i).red = MID$(ps, i * 4 + 3, 1)
	NEXT
	mPal(0).red = CHR$(0): mPal(0).green = CHR$(0): mPal(0).blue = CHR$(0)
	LoadPage% = -1
END FUNCTION

'----- mPal scaled by f/16 into the DAC (16 = full, 0 = black)
SUB PalApply (f AS INTEGER)
	DIM i AS INTEGER
	REDIM p(0 TO 255) AS tRGB
	FOR i = 0 TO 255
		p(i).red = CHR$(ASC(mPal(i).red) * f \ 16)
		p(i).green = CHR$(ASC(mPal(i).green) * f \ 16)
		p(i).blue = CHR$(ASC(mPal(i).blue) * f \ 16)
	NEXT
	uglPalSetBuff 0, 256, p(0)
END SUB

'----- set the display start to horizontal pixel px (line 0), direct CRTC (no BIOS)
SUB ScrollX (px AS INTEGER)
	DIM u AS LONG, b AS INTEGER
	u = CLNG(px) \ gUnit
	WAIT &H3DA, 8, 8
	CALL CrtcW(&HC, (u \ 256) AND 255)
	CALL CrtcW(&HD, u AND 255)
	IF gCirrus THEN
		b = CrtcR%(&H1B) AND &HF2
		IF u AND &H10000 THEN b = b OR 1
		IF u AND &H20000 THEN b = b OR 4
		IF u AND &H40000 THEN b = b OR 8
		CALL CrtcW(&H1B, b)
	END IF
	WAIT &H3DA, 8
END SUB

FUNCTION CrtcR% (idx AS INTEGER)
	OUT &H3D4, idx: CrtcR% = INP(&H3D5)
END FUNCTION
SUB CrtcW (idx AS INTEGER, v AS INTEGER)
	OUT &H3D4, idx: OUT &H3D5, v
END SUB
FUNCTION SeqR% (idx AS INTEGER)
	OUT &H3C4, idx: SeqR% = INP(&H3C5)
END FUNCTION
SUB SeqW (idx AS INTEGER, v AS INTEGER)
	OUT &H3C4, idx: OUT &H3C5, v
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
