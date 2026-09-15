'----- UGLTEST5.BAS: which part of the manual's mouse path freezes the picture?
'----- Bands on both pages, split at 459, start 20. Then step by step, each
'----- followed by a new display start and a 3 s hold for a screenshot:
'-----   A: INT 33h reset, range 0-639/0-479, position 320,240, hide -> start 100
'-----   B: cursor-style blit through a clip rect (uglGet + uglPutMsk) -> start 200
'-----   C: 2000 INT 33h position polls -> start 300
'-----   D: 200 cursor moves (put/get/putmsk) -> start 400
'----- Writes UGLTEST5.LOG, auto-exits.
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
DECLARE SUB Ms (func AS INTEGER, c AS INTEGER, d AS INTEGER)

DIM SHARED lf AS INTEGER
DIM video AS LONG, cur AS LONG, sv AS LONG
DIM p AS INTEGER, k AS INTEGER, i AS INTEGER, ln AS INTEGER
DIM cr AS CLIPRECT, r AS RegType, r2 AS RegType, mi AS INTEGER

lf = FREEFILE
OPEN "ugltest5.log" FOR OUTPUT AS #lf
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CALL Done
video = uglSetVideoDC(UGL.8BIT, 640, 480, 2)
IF video = 0 THEN CALL Lg("no 640x480x2"): uglEnd: CALL Done

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
CALL LogStart("0 start 20")
CALL Hold(3)

'----- A: mouse driver calls
CALL Ms(0, 0, 0)
CALL Ms(7, 0, 639)
CALL Ms(8, 0, 479)
CALL Ms(4, 320, 240)
CALL Ms(2, 0, 0)
CALL VStart(100)
CALL LogStart("A after INT33 0/7/8/4/2, start 100 (expect band 6)")
CALL Hold(3)

'----- B: cursor-style blit through a clip rect
cur = uglNew(UGL.MEM, UGL.8BIT, 12, 18)
sv = uglNew(UGL.MEM, UGL.8BIT, 12, 18)
FOR k = 0 TO 17
	FOR i = 0 TO 11
		IF i <= k \ 2 THEN uglPSet cur, i, k, 249 ELSE uglPSet cur, i, k, 227
	NEXT
NEXT
cr.xMin = 0: cr.yMin = 20: cr.xMax = 639: cr.yMax = 479
uglSetClipRect video, cr
uglSetWrkPage 0
uglGet video, 320, 240, sv
uglPutMsk video, 320, 240, cur
cr.xMin = 0: cr.yMin = 0: cr.xMax = 639: cr.yMax = 479
uglSetClipRect video, cr
CALL VStart(200)
CALL LogStart("B after clip+get+putmsk, start 200 (expect band 12)")
CALL Hold(3)

'----- C: position polling
FOR i = 1 TO 2000
	CALL Ms(3, 0, 0)
NEXT
CALL VStart(300)
CALL LogStart("C after 2000 INT33 AX=3, start 300 (expect band 18)")
CALL Hold(3)

'----- D: cursor moves
FOR i = 1 TO 200
	uglPut video, 320 + (i MOD 7), 240 + (i MOD 5), sv
	uglGet video, 320 + ((i + 1) MOD 7), 240 + ((i + 1) MOD 5), sv
	uglPutMsk video, 320 + ((i + 1) MOD 7), 240 + ((i + 1) MOD 5), cur
NEXT
CALL VStart(400)
CALL LogStart("D after 200 cursor moves, start 400 (expect band 25)")
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

SUB Ms (func AS INTEGER, c AS INTEGER, d AS INTEGER)
	DIM r AS RegType, r2 AS RegType, mi AS INTEGER
	mi = &H33
	r.ax = func: r.cx = c: r.dx = d
	CALL INTERRUPT(mi, r, r2)
END SUB

SUB VStart (y AS INTEGER)
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &H4F07: r.bx = 0: r.cx = 0: r.dx = y
	CALL INTERRUPT(vi, r, r2)
END SUB
