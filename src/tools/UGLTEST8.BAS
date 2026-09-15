'----- UGLTEST8.BAS: the re-open workaround. uGL 0.23b's RELEASE lib can no longer
'----- set a VESA mode after two uglInit/uglEnd cycles (UGLTEST6/7). Here uglInit
'----- runs ONCE and each scene only does uglSetVideoDC ... uglRestore, freeing its
'----- MEM DCs with uglDel. Five cycles, the CGA mode 4 in between like the game,
'----- far-heap size logged each time. Writes UGLTEST8.LOG, auto-exits.
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

DIM SHARED lf AS INTEGER
DIM v AS LONG, strip AS LONG, cur AS LONG, c AS INTEGER, r AS INTEGER, inf AS TDC

lf = FREEFILE
OPEN "ugltest8.log" FOR OUTPUT AS #lf
CALL Lg("start: bios mode" + STR$(BiosMode%) + " free" + STR$(FRE(-1)))
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CALL Done
CALL Lg("init once: free" + STR$(FRE(-1)))
FOR c = 1 TO 5
	v = uglSetVideoDC(UGL.8BIT, 640, 480, 2)
	IF v = 0 THEN
		CALL Lg("cycle" + STR$(c) + ": 640x480x2 FAILED")
		v = uglSetVideoDC(UGL.8BIT, 320, 200, 1)
		CALL Lg("cycle" + STR$(c) + ": 320x200 ->" + STR$(v <> 0))
	ELSE
		uglDCGet v, inf
		CALL Lg("cycle" + STR$(c) + ": 640x480x2 ok, pages" + STR$(inf.pages) + " free" + STR$(FRE(-1)))
	END IF
	strip = uglNew(UGL.MEM, UGL.8BIT, 640, 48)
	cur = uglNew(UGL.MEM, UGL.8BIT, 12, 18)
	CALL Lg("  strip" + STR$(strip <> 0) + " cur" + STR$(cur <> 0) + " free" + STR$(FRE(-1)))
	IF v <> 0 THEN r = uglPutBMPEx(v, 0, 0, "tplogo.bmp", BMPOPT.NO332)
	CALL Hold(.5)
	uglDel strip
	uglDel cur
	uglRestore
	CALL Lg("  restored: bios mode" + STR$(BiosMode%) + " free" + STR$(FRE(-1)))
	IF c = 1 THEN SCREEN 1: LINE (0, 0)-(319, 199), 2, BF: CALL Lg("  SCREEN 1: bios mode" + STR$(BiosMode%))
NEXT
uglEnd
CALL Lg("ended: free" + STR$(FRE(-1)))
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
