'----- UGLTEST3.BAS: does a big video-DC uglGet/uglPut (page 0 -> page 1 strips)
'----- break the VESA display start afterwards? Bands on both pages, split at
'----- 459, start at 20 (hold), strip copies, start at 100 (hold), start at 300
'----- (hold), then the same starts again after a uglSetWrkPage toggle.
'----- Writes UGLTEST3.LOG, auto-exits.
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
DECLARE SUB VStart (y AS INTEGER)
DECLARE SUB LogStart (tag AS STRING)

DIM SHARED lf AS INTEGER
DIM video AS LONG, strip AS LONG
DIM p AS INTEGER, k AS INTEGER, y AS INTEGER, ln AS INTEGER

lf = FREEFILE
OPEN "ugltest3.log" FOR OUTPUT AS #lf
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CALL Done
video = uglSetVideoDC(UGL.8BIT, 640, 480, 2)
IF video = 0 THEN CALL Lg("no 640x480x2"): uglEnd: CALL Done
strip = uglNew(UGL.MEM, UGL.8BIT, 640, 48)
CALL Lg("strip dc:" + STR$(strip))

FOR p = 0 TO 1
	uglSetWrkPage p
	FOR k = 0 TO 29
		uglRectF video, 0, k * 16, 639, k * 16 + 15, 16 + p * 64 + k
	NEXT
NEXT
uglSetWrkPage 0
uglSetVisPage 0
OUT &H3D4, &H18: OUT &H3D5, 459 AND 255
OUT &H3D4, 7: ln = INP(&H3D5): OUT &H3D5, (ln AND &HEF) OR 16
OUT &H3D4, 9: ln = INP(&H3D5): OUT &H3D5, ln AND &HBF
CALL VStart(20)
CALL LogStart("A start 20 (expect band 1 at top)")
CALL Hold(3)
'----- the strip copies the manual does (page 0 lines 0..191 -> page 1)
FOR y = 0 TO 191 STEP 48
	uglSetWrkPage 0
	uglGet video, 0, y, strip
	uglSetWrkPage 1
	uglPut video, 0, y, strip
NEXT
uglSetWrkPage 0
CALL VStart(100)
CALL LogStart("B start 100 after strips (expect band 6 at top)")
CALL Hold(3)
CALL VStart(300)
CALL LogStart("C start 300 (expect band 18 at top)")
CALL Hold(3)
uglSetWrkPage 1
uglSetWrkPage 0
CALL VStart(500)
CALL LogStart("D start 500 (expect page-1 band 1 at top)")
CALL Hold(3)
uglRestore
uglEnd
CALL Lg("DONE")
CALL Done

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

SUB LogStart (tag AS STRING)
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &H4F07: r.bx = 1
	CALL INTERRUPT(vi, r, r2)
	CALL Lg(tag + ": 4F07 get ax=" + HEX$(r2.ax) + " cx=" + STR$(r2.cx) + " dx=" + STR$(r2.dx))
END SUB

SUB VStart (y AS INTEGER)
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &H4F07: r.bx = 0: r.cx = 0: r.dx = y
	CALL INTERRUPT(vi, r, r2)
END SUB
