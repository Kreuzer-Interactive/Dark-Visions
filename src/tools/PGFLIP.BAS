'----- PGFLIP.BAS: 3D page-flip VISUAL demo, PERSPECTIVE-CORRECT (uglTriTP) drawn to a
'----- MEM back-buffer then blitted to video (the uGL example draws the perspective
'----- triangles to a MEM DC, not straight to the banked video DC). The page (low-res
'----- texture MANTEX.BMP 256x256) spins about its vertical centre like a turning card.
'----- Per-vertex uGL wants z = 1/w, u = uTex/w, v = vTex/w so the mapper divides per
'----- pixel (that is what kills the affine warp). Sequence: full cover 3 s, rock-flip
'----- 3x, full cover 3 s. Writes PGFLIP.LOG (with a pixel readback + step markers so a
'----- crash is locatable). Build/run: src\tools\pgflip.conf.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

CONST PI = 3.141593, D2R = PI / 180!

DECLARE SUB Lg (s AS STRING)
DECLARE SUB Frame (back AS LONG, video AS LONG, t1 AS TriType, t2 AS TriType, tex AS LONG, ang AS SINGLE, cx AS INTEGER, cy AS INTEGER, w2 AS SINGLE, h2 AS SINGLE, dist AS SINGLE)
DECLARE SUB Hold (secs AS SINGLE)

DIM SHARED lf AS INTEGER

DIM video AS LONG, back AS LONG, tex AS LONG, inf AS TDC, rc AS CLIPRECT
DIM t1 AS TriType, t2 AS TriType
DIM pal(0 TO 255) AS tRGB
DIM ps AS STRING * 1024
DIM ang AS SINGLE, dist AS SINGLE, w2 AS SINGLE, h2 AS SINGLE
DIM cx AS INTEGER, cy AS INTEGER, i AS INTEGER, bf AS INTEGER, rep AS INTEGER, big AS INTEGER
DIM fr AS INTEGER, t0 AS SINGLE, t1t AS SINGLE

lf = FREEFILE
OPEN "pgflip.log" FOR OUTPUT AS #lf
CALL Lg("PGFLIP persp-bb " + DATE$ + " " + TIME$)
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CLOSE #lf: END
video = uglSetVideoDC(UGL.8BIT, 640, 480, 1)
IF video = 0 THEN CALL Lg("640x480x8 refused"): uglEnd: CLOSE #lf: END

'----- MEM back-buffer for the perspective triangles (blitted to video each frame)
back = uglNew(UGL.MEM, UGL.8BIT, 640, 480)
CALL Lg("back-buffer 640x480 MEM = " + STR$(back) + " (0 = alloc failed)")
IF back = 0 THEN CALL Lg("no back-buffer"): uglRestore: uglEnd: CLOSE #lf: END
rc.xMin = 0: rc.yMin = 0: rc.xMax = 639: rc.yMax = 479
uglSetClipRect back, rc

big = -1
tex = uglNewBMPEx(UGL.MEM, UGL.8BIT, "mantex.bmp", BMPOPT.NO332)
IF tex = 0 THEN big = 0: tex = uglNewBMPEx(UGL.MEM, UGL.8BIT, "mantx128.bmp", BMPOPT.NO332)
IF tex = 0 THEN CALL Lg("no texture DC"): uglRestore: uglEnd: CLOSE #lf: END
uglDCGet tex, inf
CALL Lg("texture" + STR$(inf.xRes) + "x" + STR$(inf.yRes) + " size" + STR$(inf.size) + " (256 ok:" + STR$(big) + ")")

'----- the page's real palette (the texture holds MANP00's indices)
bf = FREEFILE
OPEN "manp00.bmp" FOR BINARY AS #bf
GET #bf, 55, ps
CLOSE #bf
FOR i = 0 TO 255
	pal(i).blue = MID$(ps, i * 4 + 1, 1)
	pal(i).green = MID$(ps, i * 4 + 2, 1)
	pal(i).red = MID$(ps, i * 4 + 3, 1)
NEXT
uglPalSetBuff 0, 256, pal(0)
CALL Lg("palette set; about to draw frame 1")

cx = 320: cy = 240: w2 = 256: h2 = 192
dist = 700

CALL Frame(back, video, t1, t2, tex, 0, cx, cy, w2, h2, dist)
CALL Lg("px in(320,240)=" + STR$(uglPGet(video, 320, 240)) + " in(120,120)=" + STR$(uglPGet(video, 120, 120)) + " out(10,10)=" + STR$(uglPGet(video, 10, 10)))
CALL Hold(3)
'----- max-speed timing (unpaced) = the real 486 frame rate for this flip
fr = 0: t0 = TIMER
FOR rep = 1 TO 3
	FOR ang = 0 TO 88 STEP 4
		CALL Frame(back, video, t1, t2, tex, ang, cx, cy, w2, h2, dist): fr = fr + 1
	NEXT
	FOR ang = 88 TO 0 STEP -4
		CALL Frame(back, video, t1, t2, tex, ang, cx, cy, w2, h2, dist): fr = fr + 1
	NEXT
NEXT
t1t = TIMER - t0: IF t1t <= 0 THEN t1t = .001
CALL Lg("max-speed flip:" + STR$(fr) + " frames in" + STR$(t1t) + " s =" + STR$(fr / t1t) + " fps")
'----- now the slow, watchable version
FOR rep = 1 TO 3
	FOR ang = 0 TO 88 STEP 4
		CALL Frame(back, video, t1, t2, tex, ang, cx, cy, w2, h2, dist)
		CALL Hold(.05)
	NEXT
	FOR ang = 88 TO 0 STEP -4
		CALL Frame(back, video, t1, t2, tex, ang, cx, cy, w2, h2, dist)
		CALL Hold(.05)
	NEXT
NEXT
CALL Frame(back, video, t1, t2, tex, 0, cx, cy, w2, h2, dist)
CALL Lg("shown: full cover + 3 rock-flips + full cover")
CALL Hold(3)
CALL Lg("DONE")
uglRestore
uglEnd
CLOSE #lf
END

'----- draw the page at angle ang as two perspective-correct textured triangles into
'----- the MEM back-buffer, then blit the back-buffer to video. Corners rotate about
'----- the vertical centre; persp = dist/(dist+Z); vertex z = persp (=1/w), u/v =
'----- texCoord*persp. texcoords TL(0,0) TR(1,0) BR(1,1) BL(0,1).
SUB Frame (back AS LONG, video AS LONG, t1 AS TriType, t2 AS TriType, tex AS LONG, ang AS SINGLE, cx AS INTEGER, cy AS INTEGER, w2 AS SINGLE, h2 AS SINGLE, dist AS SINGLE)
	DIM s AS SINGLE, c AS SINGLE, pl AS SINGLE, pr AS SINGLE
	DIM tlx AS SINGLE, tly AS SINGLE, trx AS SINGLE, tryy AS SINGLE
	DIM brx AS SINGLE, bry AS SINGLE, blx AS SINGLE, bly AS SINGLE
	s = SIN(ang * D2R): c = COS(ang * D2R)
	pl = dist / (dist + (-w2 * s))
	pr = dist / (dist + (w2 * s))
	tlx = cx + (-w2 * c) * pl: tly = cy + (-h2) * pl
	trx = cx + (w2 * c) * pr: tryy = cy + (-h2) * pr
	brx = cx + (w2 * c) * pr: bry = cy + (h2) * pr
	blx = cx + (-w2 * c) * pl: bly = cy + (h2) * pl
	t1.v1.x = tlx: t1.v1.y = tly: t1.v1.z = pl: t1.v1.u = 0: t1.v1.v = 0
	t1.v2.x = trx: t1.v2.y = tryy: t1.v2.z = pr: t1.v2.u = pr: t1.v2.v = 0
	t1.v3.x = brx: t1.v3.y = bry: t1.v3.z = pr: t1.v3.u = pr: t1.v3.v = pr
	t2.v1.x = tlx: t2.v1.y = tly: t2.v1.z = pl: t2.v1.u = 0: t2.v1.v = 0
	t2.v2.x = brx: t2.v2.y = bry: t2.v2.z = pr: t2.v2.u = pr: t2.v2.v = pr
	t2.v3.x = blx: t2.v3.y = bly: t2.v3.z = pl: t2.v3.u = 0: t2.v3.v = pl
	uglClear back, 248
	uglTriTP back, t1, UGL.MASK.FALSE, tex
	uglTriTP back, t2, UGL.MASK.FALSE, tex
	uglPut video, 0, 0, back
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
