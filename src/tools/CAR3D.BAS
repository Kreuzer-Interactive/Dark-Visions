'----- CAR3D.BAS: prototype of the 3D intro car, FPU-free (the 486SX). Mode 13h
'----- via uGL for the mode, the palette and the once-composed backdrop (the
'----- CGA carr.pic with the 2D car erased and its road lines redrawn); the
'----- per-frame work is three hand-assembled 386 routines from
'----- tools\build_car3d_asm.ps1 (CALL ABSOLUTE, see there):
'-----   C3DPRJ.OVL  projection of the prepared model + its screen box
'-----   C3DTRI.OVL  the frame: culls, texture-maps (8.8 fixed point, colour
'-----               key 255 = 1-bit alpha) every face far-to-near into a
'-----               WKW x WKH work buffer
'-----   SHADBOP.OVL rectangle copies: backdrop -> work buffer -> VRAM
'----- The model (CAR3D.MDL + CAR3D.BMP from tools\car3dcnv.ps1) is kept in
'----- 1/16 units as INTEGERs, rotated, lit (8 brightness bands = 8 copies of
'----- the texture stacked in the BMP, or none for a -Unlit model) and
'----- depth-sorted in LONG math only when the yaw changes (Prep).
'----- Usage: CAR3D [seconds]  (runs that long then prints the stats; ESC quits)
'-----        CAR3D B          (benchmark: prints ms per frame phase)
'-----        CAR3D S          (dumps two rendered frames to CAR3DS1/2.BMP)
'-----        CAR3D G          (dumps the backdrop alone to CAR3DBG.BMP)
'----- Keys: ESC quit, SPACE pause, R turntable, [ ] yaw, - = light, A/Z zoom,
'-----       O silhouette ink on/off.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

TYPE Vtx
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
	u AS SINGLE
	v AS SINGLE
END TYPE
TYPE Fac
	a AS INTEGER
	b AS INTEGER
	c AS INTEGER
	d AS INTEGER
	ci AS INTEGER
END TYPE
TYPE Nrm
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
END TYPE
TYPE Hdr
	magic AS STRING * 4
	nv AS INTEGER
	nf AS INTEGER
	flags AS INTEGER
END TYPE

DECLARE SUB LoadModel ()
DECLARE SUB LoadBackdrop ()
DECLARE SUB LoadPalette ()
DECLARE SUB LoadTexture ()
DECLARE SUB LoadOvl (fil AS STRING, s AS STRING)
DECLARE SUB LoSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
DECLARE SUB Prep (yaw AS SINGLE)
DECLARE SUB Project (px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB PathPos (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG, zm AS INTEGER)
DECLARE FUNCTION PitNow& ()
DECLARE SUB RoadEdge (side AS INTEGER)
DECLARE SUB DrawCar (px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB RectCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
DECLARE SUB RectCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
DECLARE FUNCTION NormSeg% (sg AS INTEGER, ofs AS INTEGER)
DECLARE FUNCTION TexWidth% ()
DECLARE SUB BandAlloc (b AS INTEGER, w AS INTEGER)
DECLARE SUB Fail (msg AS STRING)
DECLARE SUB SaveShot (fil AS STRING)

CONST MAXV = 1023
CONST MAXF = 1023
CONST WKW = 160
CONST WKH = 100
'----- the drive: a straight, level world line (x16 units) from screen (77,154)
'----- at depth 420 (the sprite started at x 57; the turned car is wider, so
'----- 20 px further in keeps its tail on screen) to depth 740 under the
'----- sprite's last x (269); the car heads along it, so the camera sits
'----- behind and beside it (ATN(PDZ/PDX))
CONST PX0 = -2178
CONST PDX = 7219
CONST PY0 = -1418
CONST PDY = 0
CONST PZ0 = 6720
CONST PDZ = 5120
'----- the ground plane the car's wheels ride on (units, camera height above
'----- it: the car's centre PY0/16 less half its height) and the road's half
'----- width; the backdrop's road edges are drawn as lines on that plane
'----- parallel to the drive, so they meet at the car's own vanishing point
CONST GROUNDY = -124
CONST ROADW2 = 90

'$DYNAMIC
DIM SHARED mx(0 TO MAXV) AS INTEGER, my(0 TO MAXV) AS INTEGER, mz(0 TO MAXV) AS INTEGER
DIM SHARED rx(0 TO MAXV) AS INTEGER, ry(0 TO MAXV) AS INTEGER, rz(0 TO MAXV) AS INTEGER
DIM SHARED sx(0 TO MAXV) AS INTEGER, sy(0 TO MAXV) AS INTEGER
DIM SHARED tu(0 TO MAXV) AS INTEGER, tv(0 TO MAXV) AS INTEGER
DIM SHARED fa(0 TO MAXF) AS Fac
DIM SHARED nx(0 TO MAXF) AS INTEGER, ny(0 TO MAXF) AS INTEGER, nz(0 TO MAXF) AS INTEGER
DIM SHARED fband(0 TO MAXF) AS INTEGER, ord(0 TO MAXF) AS INTEGER
DIM SHARED lnk(0 TO MAXF) AS INTEGER, head(0 TO 255) AS INTEGER
DIM SHARED bgb(0 TO 31999) AS INTEGER
DIM SHARED wkb(0 TO 7999) AS INTEGER
DIM SHARED tb0(0 TO 7) AS INTEGER, tb1(0 TO 7) AS INTEGER, tb2(0 TO 7) AS INTEGER, tb3(0 TO 7) AS INTEGER
DIM SHARED tb4(0 TO 7) AS INTEGER, tb5(0 TO 7) AS INTEGER, tb6(0 TO 7) AS INTEGER, tb7(0 TO 7) AS INTEGER
DIM SHARED bt(0 TO 7) AS INTEGER
DIM SHARED prm(0 TO 63) AS INTEGER, prq(0 TO 31) AS INTEGER
'$STATIC
DIM SHARED nv AS INTEGER, nf AS INTEGER
DIM SHARED vdc AS LONG, bg AS LONG
DIM SHARED lx AS INTEGER, ly AS INTEGER, lz AS INTEGER
DIM SHARED tris AS LONG
DIM SHARED ox AS INTEGER, oy AS INTEGER, ox2 AS INTEGER, oy2 AS INTEGER
DIM SHARED bmode AS INTEGER, unlit AS INTEGER
DIM SHARED palb AS STRING, ovlTri AS STRING, ovlPrj AS STRING, ovlBop AS STRING
DIM SHARED ovlEdge AS STRING, ovlBltm AS STRING, outl AS INTEGER
DIM SHARED bgseg AS INTEGER, bgo AS INTEGER, wseg AS INTEGER, wko AS INTEGER, texW AS INTEGER
DIM SHARED bx1 AS INTEGER, bx2 AS INTEGER, by1 AS INTEGER, by2 AS INTEGER

DIM k AS STRING, ts AS INTEGER, yaw AS SINGLE, spin AS SINGLE, turn AS INTEGER, paused AS INTEGER
DIM fx AS INTEGER, stp AS INTEGER, tnow AS LONG, tlast AS LONG, dt AS LONG, trav AS LONG
DIM cxs AS INTEGER, cys AS INTEGER, pz AS LONG, px AS LONG, py AS LONG, zoom AS INTEGER
DIM t0 AS SINGLE, el AS SINGLE, frames AS LONG, lang AS SINGLE, secs AS SINGLE
DIM bf AS SINGLE, bi AS INTEGER, bn AS INTEGER, b1 AS SINGLE, b2 AS SINGLE, b3 AS SINGLE, b4 AS SINGLE, sd AS SINGLE

	secs = VAL(COMMAND$)
	'----- no argument: stop after 30 s anyway, so an unattended run (the
	'----- 486 job) can never hold the machine
	IF LTRIM$(COMMAND$) = "" THEN secs = 30
	'----- the texture's size picks the mapper blob (masks and row stride)
	texW = TexWidth%
	IF texW <> 64 AND texW <> 128 THEN PRINT "CAR3D.BMP must be 64 or 128 texels wide": END
	CALL LoadModel
	IF texW = 128 THEN CALL LoadOvl("C3DT128.OVL", ovlTri) ELSE CALL LoadOvl("C3DTRI.OVL", ovlTri)
	CALL LoadOvl("C3DPRJ.OVL", ovlPrj)
	CALL LoadOvl("SHADBOP.OVL", ovlBop)
	CALL LoadOvl("C3DEDGE.OVL", ovlEdge)
	CALL LoadOvl("C3DBLTM.OVL", ovlBltm)
	IF LEN(ovlTri) < 100 OR LEN(ovlPrj) < 50 OR LEN(ovlBop) < 50 THEN PRINT "C3DTRI/C3DPRJ/SHADBOP.OVL missing (tools\build_car3d_asm.ps1)": END
	IF LEN(ovlEdge) < 50 OR LEN(ovlBltm) < 50 THEN PRINT "C3DEDGE/C3DBLTM.OVL missing (tools\build_car3d_asm.ps1)": END
	IF uglInit = 0 THEN PRINT "uglInit failed": END
	vdc = uglSetVideoDC(UGL.8BIT, 320, 200, 1)
	IF vdc = 0 THEN Fail "no mode 13h"
	bg = uglNew(UGL.MEM, UGL.8BIT, 320, 200)
	IF bg = 0 THEN Fail "no memory for the backdrop"
	uglSetWrkPage 0
	uglSetVisPage 0
	'----- the buffers the routines address directly (segment:offset)
	bgseg = NormSeg(VARSEG(bgb(0)), VARPTR(bgb(0))): bgo = VARPTR(bgb(0)) AND 15
	wseg = NormSeg(VARSEG(wkb(0)), VARPTR(wkb(0))): wko = VARPTR(wkb(0)) AND 15
	CALL LoadPalette
	CALL LoadTexture
	CALL LoadBackdrop
	ox = 0: oy = 0: ox2 = -1: oy2 = -1
	'----- the frame routine's parameter block (constant part)
	prm(0) = wseg: prm(1) = wko: prm(2) = WKW: prm(3) = WKH
	prm(4) = VARSEG(bt(0)): prm(23) = VARPTR(bt(0))
	prm(5) = VARSEG(sx(0)): prm(6) = VARPTR(sx(0))
	prm(7) = VARSEG(sy(0)): prm(8) = VARPTR(sy(0))
	prm(9) = VARSEG(tu(0)): prm(10) = VARPTR(tu(0))
	prm(11) = VARSEG(tv(0)): prm(12) = VARPTR(tv(0))
	prm(13) = VARSEG(fa(0)): prm(14) = VARPTR(fa(0))
	prm(15) = VARSEG(fband(0)): prm(16) = VARPTR(fband(0))
	prm(17) = VARSEG(ord(0)): prm(18) = VARPTR(ord(0))
	prm(19) = nf
	'----- the projection block
	prq(0) = VARSEG(rx(0)): prq(1) = VARPTR(rx(0))
	prq(2) = VARSEG(ry(0)): prq(3) = VARPTR(ry(0))
	prq(4) = VARSEG(rz(0)): prq(5) = VARPTR(rz(0))
	prq(6) = VARSEG(sx(0)): prq(7) = VARPTR(sx(0))
	prq(8) = VARSEG(sy(0)): prq(9) = VARPTR(sy(0))
	prq(10) = nv

	'----- light direction (camera space, x256, towards the light): from the
	'----- camera's upper left (z negative = this side of the car); lang sweeps it
	lang = -2.3
	lx = CINT(COS(lang) * 205): ly = 154: lz = CINT(SIN(lang) * 205)
	'----- heading: the model's long axis along the drive's direction (33.5
	'----- degrees away from the camera), the front leading
	yaw = 1.5708 - ATN(PDZ / PDX)
	CALL Prep(yaw)
	outl = 1

	'----- CAR3D B: benchmark - raw float loop, then 20 frames each of
	'----- project only / + backdrop block copy / full frame
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "B" THEN
		bn = 20
		t0 = TIMER
		bf = 1
		FOR bi = 1 TO 10000
			bf = bf * 1.0001 + .5
		NEXT
		b1 = TIMER - t0
		FOR bmode = 1 TO 3
			ox2 = -1
			t0 = TIMER
			FOR bi = 1 TO bn
				CALL DrawCar(-1600 + bi * 16, -960, 7200)
			NEXT
			el = TIMER - t0: IF el < 0 THEN el = el + 86400
			IF bmode = 1 THEN b2 = el
			IF bmode = 2 THEN b3 = el
			IF bmode = 3 THEN b4 = el
		NEXT
		t0 = TIMER
		FOR bi = 1 TO 5
			CALL Prep(yaw + bi * .01)
		NEXT
		el = TIMER - t0: IF el < 0 THEN el = el + 86400
		uglRestore
		uglEnd
		SCREEN 0: WIDTH 80, 25
		PRINT "CAR3D bench (asm): 10000 float mul+add"; INT(b1 * 1000); " ms;  per frame (ms): project"; INT(b2 * 1000 / bn);
		PRINT " +block copy"; INT(b3 * 1000 / bn); " full"; INT(b4 * 1000 / bn); " polys/frame"; INT(tris / bn); " Prep (yaw change)"; INT(el * 200); " ms"
		END
	END IF

	'----- CAR3D G: dump the composed backdrop alone (no car) to CAR3DBG.BMP
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "G" THEN
		CALL SaveShot("CAR3DBG.BMP")
		uglRestore
		uglEnd
		SCREEN 0: WIDTH 80, 25
		PRINT "CAR3D: backdrop written"
		END
	END IF

	'----- CAR3D S: snapshot - render the car mid-path, dump the screen to
	'----- CAR3DS1.BMP, turn it 0.8 rad, dump CAR3DS2.BMP (checks the renderer
	'----- without anyone watching the monitor)
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "S" THEN
		'----- CAR3D S <radians>: the turn for the second dump (default .8)
		sd = VAL(MID$(LTRIM$(COMMAND$), 2)): IF sd = 0 THEN sd = .8
		FOR ts = 0 TO 60
			CALL PathPos(ts, px, py, pz, 16)
			CALL DrawCar(px, py, pz)
		NEXT
		CALL SaveShot("CAR3DS1.BMP")
		CALL Prep(yaw + sd)
		CALL DrawCar(px, py, pz)
		CALL DrawCar(px, py, pz)
		CALL SaveShot("CAR3DS2.BMP")
		uglRestore
		uglEnd
		SCREEN 0: WIDTH 80, 25
		PRINT "CAR3D: snapshots written"
		END
	END IF

	'----- CAR3D V: dump the drive, every 5th path step, as CAR3DV00..40.BMP
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "V" THEN
		FOR bi = 0 TO 40
			ts = bi * 5
			CALL PathPos(ts, px, py, pz, 16)
			CALL DrawCar(px, py, pz)
			CALL SaveShot("CAR3DV" + RIGHT$("0" + LTRIM$(STR$(bi)), 2) + ".BMP")
		NEXT
		bi = 41
		uglRestore
		uglEnd
		SCREEN 0: WIDTH 80, 25
		PRINT "CAR3D:"; bi; "frames written"
		END
	END IF

	zoom = 16
	ts = 0: turn = 0: paused = 0
	'----- PIT channel 0 into mode 2 (rate generator): the same 18.2 Hz tick
	'----- for DOS, but the count runs 65535..0 once per tick instead of twice,
	'----- so PitNow can read the time within a tick; mode 3 is put back at exit
	OUT &H43, &H34: OUT &H40, 0: OUT &H40, 0
	tlast = PitNow&
	t0 = TIMER: frames = 0
	DO
		k = INKEY$
		IF k = CHR$(27) THEN EXIT DO
		IF k = " " THEN paused = NOT paused
		IF k = "r" OR k = "R" THEN turn = NOT turn
		IF k = "o" OR k = "O" THEN outl = 1 - outl
		IF k = "[" THEN yaw = yaw - .2618: CALL Prep(yaw + spin)
		IF k = "]" THEN yaw = yaw + .2618: CALL Prep(yaw + spin)
		IF k = "-" OR k = "=" THEN
			IF k = "-" THEN lang = lang - .3 ELSE lang = lang + .3
			lx = CINT(COS(lang) * 205): lz = CINT(SIN(lang) * 205)
			CALL Prep(yaw + spin)
		END IF
		IF k = "a" OR k = "A" THEN zoom = zoom - 2: IF zoom < 4 THEN zoom = 4
		IF k = "z" OR k = "Z" THEN zoom = zoom + 2
		IF turn THEN spin = spin + .03: CALL Prep(yaw + spin)
		'----- the drive: constant speed along the road, one step of 200 per
		'----- 70 Hz retrace (two when the frame took two, measured with the
		'----- PIT); the renderer places vertices to 1/16 pixel, so the slow far
		'----- end stays smooth. zoom 16 = the real distance
		CALL PathPos(ts, px, py, pz, zoom)
		CALL DrawCar(px, py, pz)
		frames = frames + 1
		tnow = PitNow&: dt = tnow - tlast: tlast = tnow
		IF dt < 0 OR dt > 170450 THEN dt = 17045
		stp = (dt + 8522) \ 17045
		IF stp < 1 THEN stp = 1
		IF stp > 4 THEN stp = 4
		IF paused = 0 THEN
			ts = ts + stp: trav = trav + stp
			IF ts > 205 THEN ts = -5
		END IF
		IF secs > 0 THEN
			el = TIMER - t0: IF el < 0 THEN el = el + 86400
			IF el >= secs THEN EXIT DO
		END IF
	LOOP
	el = TIMER - t0: IF el < 0 THEN el = el + 86400
	OUT &H43, &H36: OUT &H40, 0: OUT &H40, 0
	uglRestore
	uglEnd
	SCREEN 0: WIDTH 80, 25
	PRINT "CAR3D asm/textured dirty-rect"; WKW; "x"; WKH; ": verts"; nv; " faces"; nf; " frames"; frames; " secs"; INT(el * 10) / 10; " fps"; INT(frames / (el + .001)); " polys/frame"; INT(tris / (frames + 1));
	PRINT " path steps/s"; INT(trav / (el + .001)); "(70 = one per retrace)"
	END

'----- Prep: rotate the model (x16 units) and its normals (x256) about Y by
'----- yaw, light each face into its texture band fband() and sort the faces
'----- far-to-near into ord(). Translation does not change the order, so the
'----- frame only projects. The only float here: COS/SIN.
SUB Prep (yaw AS SINGLE)
	DIM cs AS INTEGER, sn AS INTEGER, i AS INTEGER, f AS INTEGER, bk AS INTEGER, n AS INTEGER
	DIM nxr AS INTEGER, nzr AS INTEGER, sh AS INTEGER, band AS INTEGER, d AS INTEGER
	cs = CINT(COS(yaw) * 256): sn = CINT(SIN(yaw) * 256)
	FOR i = 0 TO nv - 1
		rx(i) = (CLNG(mx(i)) * cs + CLNG(mz(i)) * sn) \ 256
		rz(i) = (CLNG(mz(i)) * cs - CLNG(mx(i)) * sn) \ 256
		ry(i) = my(i)
	NEXT
	FOR i = 0 TO 255: head(i) = -1: NEXT
	FOR f = 0 TO nf - 1
		IF unlit THEN
			fband(f) = 0
		ELSE
			nxr = (CLNG(nx(f)) * cs + CLNG(nz(f)) * sn) \ 256
			nzr = (CLNG(nz(f)) * cs - CLNG(nx(f)) * sn) \ 256
			sh = (CLNG(nxr) * lx + CLNG(ny(f)) * ly + CLNG(nzr) * lz) \ 256
			'----- band 0..7 = 3 + 4.5 * cos(angle to the light)
			band = (768 + (CLNG(sh) * 9) \ 2) \ 256
			IF band < 0 THEN band = 0
			IF band > 7 THEN band = 7
			fband(f) = band
		END IF
		'----- depth bucket by the summed z (x16 units, about +-4000)
		d = (rz(fa(f).a) + rz(fa(f).b) + rz(fa(f).c) + 4096) \ 32
		IF d < 0 THEN d = 0
		IF d > 255 THEN d = 255
		lnk(f) = head(d): head(d) = f
	NEXT
	n = 0
	FOR bk = 255 TO 0 STEP -1
		f = head(bk)
		DO WHILE f >= 0
			ord(n) = f: n = n + 1
			f = lnk(f)
		LOOP
	NEXT
END SUB

'----- Project: C3DPRJ - sx()/sy() of the prepared model at world (px,py,pz)
'----- (x16 units) and the screen box bx1..by2
SUB Project (px AS LONG, py AS LONG, pz AS LONG)
	CALL LoSplit(px, prq(11), prq(12))
	CALL LoSplit(py, prq(13), prq(14))
	CALL LoSplit(pz, prq(15), prq(16))
	DEF SEG = VARSEG(ovlPrj)
	CALL ABSOLUTE(BYVAL VARSEG(prq(0)), BYVAL VARPTR(prq(0)), SADD(ovlPrj))
	DEF SEG
	'----- the projection is in 1/16 pixel; the box in whole pixels
	bx1 = prq(17) \ 16: bx2 = prq(18) \ 16: by1 = prq(19) \ 16: by2 = prq(20) \ 16
END SUB

'----- DrawCar: project, place the work buffer over the union of the previous
'----- and the new box, fill it from the backdrop, draw the faces, blit the
'----- block to VRAM in the vertical blank
SUB DrawCar (px AS LONG, py AS LONG, pz AS LONG)
	DIM bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER, dx AS INTEGER, dy AS INTEGER
	DIM rw AS INTEGER, rh AS INTEGER, wo AS LONG
	CALL Project(px, py, pz)
	IF bmode = 1 THEN EXIT SUB
	'----- this frame's box (padded, clamped) joined with the last one
	bx = bx1 - 1: by = by1 - 1: ex = bx2 + 2: ey = by2 + 2
	IF ox2 >= 0 THEN
		IF ox < bx THEN bx = ox
		IF oy < by THEN by = oy
		IF ox2 > ex THEN ex = ox2
		IF oy2 > ey THEN ey = oy2
	END IF
	IF bx < 0 THEN bx = 0
	IF by < 0 THEN by = 0
	IF ex > 319 THEN ex = 319
	IF ey > 199 THEN ey = 199
	ox = bx1 - 1: oy = by1 - 1: ox2 = bx2 + 2: oy2 = by2 + 2
	IF ox < 0 THEN ox = 0
	IF oy < 0 THEN oy = 0
	IF ox2 > 319 THEN ox2 = 319
	IF oy2 > 199 THEN oy2 = 199
	'----- the work buffer's place on screen: covers the box, stays inside the
	'----- screen (a box bigger than the buffer - zoomed in - is simply cut)
	dx = bx: dy = by
	IF dx > 320 - WKW THEN dx = 320 - WKW
	IF dy > 200 - WKH THEN dy = 200 - WKH
	'----- only the box itself is copied in and out (the buffer is bigger than
	'----- the car so the car never has to be cut; the bus traffic stays small)
	IF ex > dx + WKW - 1 THEN ex = dx + WKW - 1
	IF ey > dy + WKH - 1 THEN ey = dy + WKH - 1
	rw = ex - bx + 1: rh = ey - by + 1
	wo = CLNG(wko) + CLNG(by - dy) * WKW + (bx - dx)
	CALL RectCopy(bgseg, bgo + CLNG(by) * 320 + bx, wseg, wo, rh, rw, 320, WKW)
	IF bmode = 2 THEN EXIT SUB
	prm(20) = dx * 16: prm(21) = dy * 16: prm(22) = 0
	DEF SEG = VARSEG(ovlTri)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
	DEF SEG
	tris = tris + prm(22)
	'----- silhouette ink: car pixels that border the background get marked
	'----- (254) here and turn brown (3) in the blit below, like the drawn
	'----- outline of the original CGA sprite
	IF outl AND rw >= 2 AND rh >= 2 THEN
		DEF SEG = VARSEG(ovlEdge)
		CALL ABSOLUTE(BYVAL wseg, BYVAL CINT(wo), BYVAL WKW, BYVAL rw, BYVAL rh, SADD(ovlEdge))
		DEF SEG
	END IF
	'----- (the benchmark skips the retrace wait so it measures the work)
	IF bmode = 0 THEN
		WAIT &H3DA, 8, 8
		WAIT &H3DA, 8
	END IF
	CALL RectCopyM(wseg, wo, &HA000, CLNG(by) * 320 + bx, rh, rw, WKW, 320, 3)
END SUB

'----- RectCopyM: C3DBLTM.OVL - the same copy as RectCopy, with every 254
'----- (the ink mark) written as colour col
SUB RectCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBltm)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL col, SADD(ovlBltm))
	DEF SEG
END SUB

'----- RectCopy: SHADBOP.OVL mode 0 - rows x nb bytes from sg:so (stride sst)
'----- to dg:dof (stride dst); offsets as LONG 0..65535
SUB RectCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBop)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL 0, SADD(ovlBop))
	DEF SEG
END SUB

'----- NormSeg: the segment at which (sg:ofs) is offset 0..15
FUNCTION NormSeg% (sg AS INTEGER, ofs AS INTEGER)
	DIM s AS LONG, o AS LONG
	s = sg: IF s < 0 THEN s = s + 65536
	o = ofs: IF o < 0 THEN o = o + 65536
	s = s + o \ 16
	IF s > 32767 THEN s = s - 65536
	NormSeg% = s
END FUNCTION

'----- LONG -> two words (lo as the signed INTEGER holding the low 16 bits)
SUB LoSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
	DIM l AS LONG
	l = v AND &HFFFF&
	hi = (v - l) \ 65536
	IF l > 32767 THEN l = l - 65536
	lo = l
END SUB

SUB LoadOvl (fil AS STRING, s AS STRING)
	DIM n AS INTEGER
	n = FREEFILE
	OPEN fil FOR BINARY AS #n
	s = SPACE$(LOF(n))
	IF LOF(n) > 0 THEN GET #n, 1, s
	CLOSE #n
END SUB

SUB Fail (msg AS STRING)
	uglRestore
	uglEnd
	SCREEN 0: WIDTH 80, 25
	PRINT "CAR3D: "; msg
	END
END SUB

'----- SaveShot: the visible 320x200 screen as an 8-bit BMP with the palette
'----- (one uglPGet per pixel - slow, but only for the S mode)
SUB SaveShot (fil AS STRING)
	DIM fh AS INTEGER, x AS INTEGER, y AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN fil FOR BINARY AS #fh
	s = "BM" + MKL$(54 + 1024 + 64000) + MKL$(0) + MKL$(54 + 1024)
	s = s + MKL$(40) + MKL$(320) + MKL$(200) + MKI$(1) + MKI$(8) + MKL$(0) + MKL$(64000)
	s = s + MKL$(2835) + MKL$(2835) + MKL$(256) + MKL$(0)
	PUT #fh, , s
	PUT #fh, , palb
	s = SPACE$(320)
	FOR y = 199 TO 0 STEP -1
		FOR x = 0 TO 319
			MID$(s, x + 1, 1) = CHR$(uglPGet(vdc, x, y) AND 255)
		NEXT
		PUT #fh, , s
	NEXT
	CLOSE #fh
END SUB

'----- carr.pic (BSAVE of B800, 16 KB) -> bg DC as indices 0..3 with the 2D car
'----- erased, onto the screen once, then VRAM -> bgb() for the frame copies
SUB LoadBackdrop
	DIM y AS INTEGER, x AS INTEGER, k AS INTEGER, ofs AS INTEGER, hv AS INTEGER, lo AS INTEGER, hi AS INTEGER
	DIM fh AS INTEGER, s AS STRING
	'----- a painted backdrop (converter -Backdrop -> CARROAD.BMP, 320x200,
	'----- bottom-up, palette slots 0..15) replaces the carr.pic composition:
	'----- straight into bgb() and VRAM, nothing erased, no computed road
	fh = FREEFILE
	OPEN "CARROAD.BMP" FOR BINARY AS #fh
	IF LOF(fh) > 1078 THEN
		s = SPACE$(320)
		SEEK #fh, 1079
		FOR y = 199 TO 0 STEP -1
			GET #fh, , s
			CALL RectCopy(VARSEG(s), CLNG(SADD(s)), bgseg, CLNG(bgo) + CLNG(y) * 320, 1, 320, 320, 320)
		NEXT
		CLOSE #fh
		CALL RectCopy(bgseg, CLNG(bgo), &HA000, 0, 200, 320, 320, 320)
		EXIT SUB
	END IF
	CLOSE #fh
	IF LOF(fh) = 0 THEN KILL "CARROAD.BMP"
	REDIM cga(0 TO 8191) AS INTEGER
	REDIM lut(0 TO 255, 0 TO 1) AS INTEGER
	REDIM row(0 TO 159) AS INTEGER
	DEF SEG = VARSEG(cga(0)): BLOAD "CARR.PIC", VARPTR(cga(0)): DEF SEG
	FOR k = 0 TO 255
		lut(k, 0) = (k \ 64) + ((k \ 16) AND 3) * 256
		lut(k, 1) = ((k \ 4) AND 3) + (k AND 3) * 256
	NEXT
	FOR y = 0 TO 199
		ofs = (y \ 2) * 40 + (y AND 1) * 4096
		k = 0
		FOR x = 0 TO 39
			hv = cga(ofs + x)
			lo = hv AND 255
			hi = (hv AND &H7F00) \ 256
			IF hv < 0 THEN hi = hi + 128
			row(k) = lut(lo, 0): row(k + 1) = lut(lo, 1)
			row(k + 2) = lut(hi, 0): row(k + 3) = lut(hi, 1)
			k = k + 4
		NEXT
		'----- the painted road (brown, attr 3) goes: everything below the tree
		'----- trunks, which end at row 126, and its start at the right in 123..126
		IF y >= 123 THEN
			FOR k = 0 TO 159
				IF y >= 127 OR k >= 140 THEN
					IF (row(k) AND 255) = 3 THEN row(k) = row(k) AND &HFF00
					IF (row(k) \ 256) = 3 THEN row(k) = row(k) AND 255
				END IF
			NEXT
		END IF
		uglRowWriteBuff bg, 0, y, 320, UGL.BF.8BIT, row(0)
	NEXT
	'----- the 2D car sprite gone (Intro lifts it with GET/PUT XOR)
	uglRectF bg, 8, 133, 105, 175, 0
	'----- the road edges in perspective, on the car's ground plane
	CALL RoadEdge(-1)
	CALL RoadEdge(1)
	uglPut vdc, 0, 0, bg
	CALL RectCopy(&HA000, 0, bgseg, CLNG(bgo), 200, 320, 320, 320)
END SUB

'----- CAR3D.MDL (see tools\car3dcnv.ps1): floats in the file, converted once
'----- to x16 (vertices), 8.8 texels (u,v) and x256 (normals) integers
SUB LoadModel
	DIM fh AS INTEGER, i AS INTEGER, h AS Hdr, vt AS Vtx, nm AS Nrm, t AS LONG
	fh = FREEFILE
	OPEN "CAR3D.MDL" FOR BINARY AS #fh
	IF LOF(fh) = 0 THEN CLOSE #fh: PRINT "CAR3D.MDL missing": END
	GET #fh, , h
	IF h.magic <> "C3D2" THEN CLOSE #fh: PRINT "CAR3D.MDL: wrong format (rerun tools\car3dcnv.ps1)": END
	nv = h.nv: nf = h.nf: unlit = h.flags AND 1
	IF nv > MAXV + 1 OR nf > MAXF + 1 THEN CLOSE #fh: PRINT "model too big": END
	FOR i = 0 TO nv - 1
		GET #fh, , vt
		mx(i) = CINT(vt.x * 16): my(i) = CINT(vt.y * 16): mz(i) = CINT(vt.z * 16)
		'----- texel coordinates, 8.8 fixed point over the texture's width
		t = CLNG(vt.u * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		tu(i) = t
		t = CLNG(vt.v * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		tv(i) = t
	NEXT
	FOR i = 0 TO nf - 1: GET #fh, , fa(i): NEXT
	FOR i = 0 TO nf - 1
		GET #fh, , nm
		nx(i) = CINT(nm.x * 256): ny(i) = CINT(nm.y * 256): nz(i) = CINT(nm.z * 256)
	NEXT
	CLOSE #fh
END SUB

'----- the 256 BGRA entries of CAR3D.BMP -> DAC
SUB LoadPalette
	DIM i AS INTEGER, fh AS INTEGER, s AS STRING
	REDIM pal(0 TO 255) AS tRGB
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	SEEK #fh, 55
	s = INPUT$(1024, #fh)
	CLOSE #fh
	palb = s
	FOR i = 0 TO 255
		pal(i).blue = MID$(s, i * 4 + 1, 1)
		pal(i).green = MID$(s, i * 4 + 2, 1)
		pal(i).red = MID$(s, i * 4 + 3, 1)
	NEXT
	uglPalSetBuff 0, 256, pal(0)
END SUB

'----- the pixels of CAR3D.BMP (texW wide, texW*bands rows, stored bottom-up)
'----- -> one 16-byte-aligned array per lighting band, its segment in bt(b)
'----- (band b's texel row y sits at that segment, offset y*texW)
SUB LoadTexture
	DIM fh AS INTEGER, r AS INTEGER, h AS INTEGER, w AS INTEGER, bands AS INTEGER, b AS INTEGER, y AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	s = SPACE$(4)
	GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	GET #fh, 23, s: h = CVI(LEFT$(s, 2))
	IF w <> texW THEN CLOSE #fh: Fail "CAR3D.BMP width changed"
	bands = h \ w
	IF bands < 1 OR bands > 8 OR bands * w <> h THEN CLOSE #fh: Fail "CAR3D.BMP must be W x (W*bands)"
	FOR b = 0 TO bands - 1: CALL BandAlloc(b, w): NEXT
	FOR b = bands TO 7: bt(b) = bt(bands - 1): NEXT
	s = SPACE$(w)
	SEEK #fh, 1079
	FOR r = 0 TO h - 1
		GET #fh, , s
		y = h - 1 - r
		b = y \ w
		CALL RectCopy(VARSEG(s), CLNG(SADD(s)), bt(b), CLNG(y - b * w) * w, 1, w, w, w)
	NEXT
	CLOSE #fh
END SUB

'----- BandAlloc: size band b's array to w*w bytes (+16 for alignment) and
'----- record the segment at which its data starts at offset 0
SUB BandAlloc (b AS INTEGER, w AS INTEGER)
	DIM n AS INTEGER, tp AS INTEGER, sg AS INTEGER
	n = (CLNG(w) * w + 16) \ 2
	SELECT CASE b
	CASE 0: REDIM tb0(0 TO n) AS INTEGER: tp = VARPTR(tb0(0)): sg = VARSEG(tb0(0))
	CASE 1: REDIM tb1(0 TO n) AS INTEGER: tp = VARPTR(tb1(0)): sg = VARSEG(tb1(0))
	CASE 2: REDIM tb2(0 TO n) AS INTEGER: tp = VARPTR(tb2(0)): sg = VARSEG(tb2(0))
	CASE 3: REDIM tb3(0 TO n) AS INTEGER: tp = VARPTR(tb3(0)): sg = VARSEG(tb3(0))
	CASE 4: REDIM tb4(0 TO n) AS INTEGER: tp = VARPTR(tb4(0)): sg = VARSEG(tb4(0))
	CASE 5: REDIM tb5(0 TO n) AS INTEGER: tp = VARPTR(tb5(0)): sg = VARSEG(tb5(0))
	CASE 6: REDIM tb6(0 TO n) AS INTEGER: tp = VARPTR(tb6(0)): sg = VARSEG(tb6(0))
	CASE 7: REDIM tb7(0 TO n) AS INTEGER: tp = VARPTR(tb7(0)): sg = VARSEG(tb7(0))
	END SELECT
	bt(b) = NormSeg(sg, tp + ((16 - (tp AND 15)) AND 15))
END SUB

'----- TexWidth: the width of CAR3D.BMP (64 or 128), read before anything else
FUNCTION TexWidth%
	DIM fh AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 THEN CLOSE #fh: PRINT "CAR3D.BMP missing": END
	s = SPACE$(4)
	GET #fh, 19, s
	CLOSE #fh
	TexWidth% = CVI(LEFT$(s, 2))
END FUNCTION

'----- PathPos: world position (x16 units) at step ts of 200 along the drive
'----- (constant speed along the road); zm = 16 is the real distance
SUB PathPos (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG, zm AS INTEGER)
	px = (PX0 + (CLNG(ts) * PDX) \ 200) * zm \ 16
	py = (PY0 + (CLNG(ts) * PDY) \ 200) * zm \ 16
	pz = (PZ0 + (CLNG(ts) * PDZ) \ 200) * zm \ 16
END SUB

'----- PitNow: time in 1.193 MHz PIT units from the BIOS tick count and the
'----- channel 0 countdown (re-read if a tick landed in between); wraps every
'----- 30 min, differences are what matter
FUNCTION PitNow&
	DIM lo AS INTEGER, hi AS INTEGER, cnt AS LONG, t1 AS LONG, t2 AS LONG
	DEF SEG = &H40
	DO
		t1 = PEEK(&H6C) + CLNG(PEEK(&H6D)) * 256
		OUT &H43, 0
		lo = INP(&H40): hi = INP(&H40)
		t2 = PEEK(&H6C) + CLNG(PEEK(&H6D)) * 256
	LOOP WHILE t1 <> t2
	DEF SEG
	cnt = 65535 - (CLNG(hi) * 256 + lo)
	PitNow& = (t1 AND &H7FFF&) * 65536 + cnt
END FUNCTION

'----- RoadEdge: one edge of the road (side -1 = nearer the camera, 1 = the
'----- far one) as a brown line on the backdrop: the line on the ground plane
'----- ROADW2 units beside the drive, projected (two points well in front of
'----- the camera, the projection of a line is a line) and clipped to the
'----- screen. Floats are fine here: this runs once.
SUB RoadEdge (side AS INTEGER)
	DIM dxp AS SINGLE, dzp AS SINGLE, l AS SINGLE, nxp AS SINGLE, nzp AS SINGLE
	DIM s AS SINGLE, wx AS SINGLE, wz AS SINGLE, x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE
	DIM t0 AS SINGLE, t1 AS SINGLE, p AS SINGLE, q AS SINGLE, r AS SINGLE, e AS INTEGER
	dxp = PDX / 16: dzp = PDZ / 16
	l = SQR(dxp * dxp + dzp * dzp)
	nxp = -dzp / l: nzp = dxp / l
	'----- the two points: s = -.8 (just in front of the camera) and s = 6 (far)
	FOR e = 1 TO 2
		IF e = 1 THEN s = -.8 ELSE s = 6
		wx = PX0 / 16 + s * dxp + side * ROADW2 * nxp
		wz = PZ0 / 16 + s * dzp + side * ROADW2 * nzp
		IF wz < 20 THEN wz = 20
		IF e = 1 THEN
			x1 = 160 + 256 * wx / wz: y1 = 100 - 256 * GROUNDY / wz
		ELSE
			x2 = 160 + 256 * wx / wz: y2 = 100 - 256 * GROUNDY / wz
		END IF
	NEXT
	'----- Liang-Barsky clip to 0..319 x 0..199
	t0 = 0: t1 = 1
	FOR e = 1 TO 4
		SELECT CASE e
		CASE 1: p = -(x2 - x1): q = x1
		CASE 2: p = x2 - x1: q = 319 - x1
		CASE 3: p = -(y2 - y1): q = y1
		CASE 4: p = y2 - y1: q = 199 - y1
		END SELECT
		IF p = 0 THEN
			IF q < 0 THEN EXIT SUB
		ELSE
			r = q / p
			IF p < 0 THEN
				IF r > t1 THEN EXIT SUB
				IF r > t0 THEN t0 = r
			ELSE
				IF r < t0 THEN EXIT SUB
				IF r < t1 THEN t1 = r
			END IF
		END IF
	NEXT
	uglLine bg, CINT(x1 + t0 * (x2 - x1)), CINT(y1 + t0 * (y2 - y1)), CINT(x1 + t1 * (x2 - x1)), CINT(y1 + t1 * (y2 - y1)), 3
END SUB
