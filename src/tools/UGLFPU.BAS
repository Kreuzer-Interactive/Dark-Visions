'----- UGLFPU.BAS: which uGL fillers work on a CPU without an FPU (the 486SX)?
'----- Draws one triangle with uglPolyF (integer points), uglTriF and uglTriT
'----- (single-precision TriType) into a memory DC and reads a pixel back, then
'----- times QB's own float and LONG arithmetic. Result in UGLFPU.LOG.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'
DIM p(0 TO 2) AS PNT2D
DIM t AS TriType
DIM dc AS LONG, tx AS LONG, v AS LONG, r1 AS LONG, r2 AS LONG, r3 AS LONG, r4 AS LONG
DIM fh AS INTEGER, i AS INTEGER, t0 AS SINGLE, fs AS SINGLE, ls AS SINGLE, f AS SINGLE, g AS SINGLE
DIM a AS LONG, b AS LONG, c AS LONG

	fh = FREEFILE
	OPEN "UGLFPU.LOG" FOR OUTPUT AS #fh
	IF uglInit = 0 THEN PRINT #fh, "uglInit failed": CLOSE #fh: END
	v = uglSetVideoDC(UGL.8BIT, 320, 200, 1)
	IF v = 0 THEN PRINT #fh, "no mode 13h": CLOSE #fh: END
	dc = uglNew(UGL.MEM, UGL.8BIT, 64, 64)
	tx = uglNew(UGL.MEM, UGL.8BIT, 16, 16)
	uglClear tx, 7
	'----- 1. uglPolyF, integer points
	uglClear dc, 0
	p(0).x = 2: p(0).y = 2: p(1).x = 60: p(1).y = 4: p(2).x = 30: p(2).y = 60
	uglPolyF dc, p(0), 3, 5
	r1 = uglPGet(dc, 30, 20)
	'----- 2. uglTriF, single coordinates
	uglClear dc, 0
	t.v1.x = 2: t.v1.y = 2: t.v2.x = 60: t.v2.y = 4: t.v3.x = 30: t.v3.y = 60
	uglTriF dc, t, 5
	r2 = uglPGet(dc, 30, 20)
	'----- 3. uglTriT, textured
	uglClear dc, 0
	t.v1.u = 0: t.v1.v = 0: t.v2.u = 1: t.v2.v = 0: t.v3.u = 0: t.v3.v = 1
	uglTriT dc, t, UGL.MASK.FALSE, tx
	r3 = uglPGet(dc, 30, 20)
	'----- 4. uglTriF again after uglTriT (did TriT wreck the FPU state?)
	uglClear dc, 0
	uglTriF dc, t, 5
	r4 = uglPGet(dc, 30, 20)
	uglRestore
	uglEnd
	'----- 5. QB arithmetic speed
	t0 = TIMER
	f = 1: g = 1.0001
	FOR i = 1 TO 10000
		f = f * g + .5
	NEXT
	fs = TIMER - t0
	t0 = TIMER
	a = 1: b = 3
	FOR i = 1 TO 10000
		c = a * b + 7
		a = c \ 3
	NEXT
	ls = TIMER - t0
	PRINT #fh, "pixel inside the triangle (0 = nothing drawn): PolyF ="; r1; " TriF ="; r2; " TriT ="; r3; " TriF after TriT ="; r4
	PRINT #fh, "10000 x (single mul+add):"; INT(fs * 1000); " ms   10000 x (long mul+add+div):"; INT(ls * 1000); " ms"
	CLOSE #fh
	SCREEN 0: WIDTH 80, 25
	PRINT "PolyF ="; r1; " TriF ="; r2; " TriT ="; r3; " again ="; r4; "  single"; INT(fs * 1000); "ms long"; INT(ls * 1000); "ms"
	END
