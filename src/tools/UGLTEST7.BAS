'----- UGLTEST7.BAS: the game's real mode sequence. Cycle 1 from text mode (the
'----- logo), then QB SCREEN 1 (CGA mode 4), then cycle 2 from mode 4 (Tab ->
'----- manual), then the CGA screen again and cycle 3. The BIOS video mode
'----- (INT 10h AH=0Fh) is logged around every step. Writes UGLTEST7.LOG.
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
DECLARE SUB Hold (secs AS SINGLE)
DECLARE SUB Done ()
DECLARE FUNCTION BiosMode% ()
DECLARE FUNCTION TryMode& (tag AS STRING, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
DECLARE SUB Cycle (tag AS STRING)

DIM SHARED lf AS INTEGER

lf = FREEFILE
OPEN "ugltest7.log" FOR OUTPUT AS #lf
CALL Lg("start: bios mode" + STR$(BiosMode%))
CALL Cycle("c1 (from text)")
SCREEN 1
LINE (0, 0)-(319, 199), 2, BF
CALL Lg("after SCREEN 1: bios mode" + STR$(BiosMode%))
CALL Hold(1)
CALL Cycle("c2 (from CGA)")
CALL Lg("after c2: bios mode" + STR$(BiosMode%) + " (game expects 4)")
LINE (0, 0)-(319, 199), 1, BF
CALL Hold(1)
CALL Cycle("c3 (from CGA again)")
CALL Lg("after c3: bios mode" + STR$(BiosMode%))
SCREEN 0
CALL Lg("DONE")
CALL Done

FUNCTION BiosMode%
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &HF00
	CALL INTERRUPT(vi, r, r2)
	BiosMode% = r2.ax AND 255
END FUNCTION

'----- uglInit / ladder / hold / uglRestore / uglEnd, like VgaOpen + VgaClose
SUB Cycle (tag AS STRING)
	DIM v AS LONG, r AS INTEGER
	IF NOT uglInit THEN CALL Lg(tag + " uglInit FAILED"): EXIT SUB
	CALL Lg(tag + " init ok, bios mode" + STR$(BiosMode%))
	v = TryMode&(tag, 640, 480, 2)
	IF v = 0 THEN v = TryMode&(tag + " fallback", 640, 480, 1)
	IF v = 0 THEN v = TryMode&(tag + " fallback", 320, 200, 1)
	IF v <> 0 THEN
		CALL Lg(tag + " in mode: bios mode" + STR$(BiosMode%))
		r = uglPutBMPEx(v, 0, 0, "tplogo.bmp", BMPOPT.NO332)
		CALL Hold(1)
	END IF
	uglRestore
	CALL Lg(tag + " after uglRestore: bios mode" + STR$(BiosMode%))
	uglEnd
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

FUNCTION TryMode& (tag AS STRING, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
	DIM v AS LONG, inf AS TDC
	v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
	IF v = 0 THEN
		CALL Lg(tag + ":" + STR$(xr) + "x" + LTRIM$(STR$(yr)) + " pages" + STR$(np) + " -> FAILED")
	ELSE
		uglDCGet v, inf
		CALL Lg(tag + ":" + STR$(xr) + "x" + LTRIM$(STR$(yr)) + " pages" + STR$(np) + " -> ok, bps" + STR$(inf.bps) + " pages" + STR$(inf.pages))
	END IF
	TryMode& = v
END FUNCTION
