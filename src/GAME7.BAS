'----- GAME7.BAS: the 3D intro car. Intro (GAME.BAS) used to lift the CGA car
'----- sprite off carr.pic and PUT it across the screen, one step per engine
'----- sweep; IntroCar3D drives the textured 3D model of tools\CAR3D.BAS
'----- (CAR3D.MDL + CAR3D.BMP from tools\car3dcnv.ps1) along the same road in
'----- VGA mode 13h over the painted backdrop CARROAD.BMP, with the same
'----- engine sweep (SOUND tc,.06 / SOUND f3,.06, tc 50..200 by 18) playing
'----- in the background. Seventh code module -> its own 64K code segment;
'----- pure library (no COMMON SHARED, no UGL.BI: GAME6 owns uGL -- the mode
'----- switch, the retrace wait and FileExists come from there).
'-----
'----- The renderer is FPU-free (the 486SX): hand-assembled 386 routines from
'----- tools\build_car3d_asm.ps1, loaded as strings and CALL ABSOLUTEd:
'-----   C3DPRJ.OVL    projection of the prepared model (1/16 pixel) + its box
'-----   C3DT128.OVL   the frame: screen-winding cull, affine texture mapping
'-----   (C3DTRI.OVL)  (8.8 fixed point, colour key 255), far-to-near, into
'-----                 the work buffer; the 64-texel mapper for a 64-wide BMP
'-----   C3DEDGE.OVL   marks the car's silhouette pixels (254)
'-----   SHADBOP.OVL   rectangle copies (backdrop strip -> work buffer)
'-----   C3DBLTM.OVL   the copy to VRAM, 254 -> colour 3 (the ink outline)
'----- Memory (the far heap is ~43 KB free in the game; Intro ERASEs the
'----- shadow / anim caches around the call): the backdrop rows BGY0..199
'----- only (the car never leaves rows 119..190), a WKW x WKH work buffer,
'----- the texture and the rotated model -- about 70 KB, checked against
'----- FRE(-1) first. Anything missing returns 1 and Intro shows the CGA
'----- sprite drive as before. Nothing is allocated once C3dPoint has taken
'----- the buffers' addresses (the far heap may move arrays).
'-----
'----- Timing: one path step (of 200 along the road) per 70 Hz retrace, two
'----- when a frame took two. The clock is the engine sound itself: QB's
'----- background music runs PIT channel 0 at 582.6 Hz (reload 2048) while
'----- notes play and every SOUND x,.06 lasts exactly one of those ticks, so
'----- the notes consumed from the queue (PLAY(0)) measure time to 1.7 ms;
'----- the PIT count means nothing meanwhile (tools\PITPROBE.BAS).
'----- C3DDUMP=1 in the environment appends the timing to C3D.LOG.
DEFINT A-Z
TYPE C3dFac
	a AS INTEGER
	b AS INTEGER
	c AS INTEGER
	d AS INTEGER
	ci AS INTEGER
END TYPE
TYPE C3dHdr
	magic AS STRING * 4
	nv AS INTEGER
	nf AS INTEGER
	flags AS INTEGER
END TYPE
TYPE C3dVtx
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
	u AS SINGLE
	v AS SINGLE
END TYPE
TYPE C3dNrm
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
END TYPE

DECLARE FUNCTION IntroCar3D% (f3 AS SINGLE, nfr AS SINGLE)
DECLARE FUNCTION C3dProbe& ()
DECLARE FUNCTION C3dLoadModel% ()
DECLARE FUNCTION C3dLoadTexture% ()
DECLARE SUB C3dLoadBackdrop ()
DECLARE SUB C3dLoadOvl (fil AS STRING, s AS STRING)
DECLARE SUB C3dPoint ()
DECLARE SUB C3dBand (b AS INTEGER, w AS INTEGER)
DECLARE FUNCTION C3dBandSeg% (b AS INTEGER)
DECLARE SUB C3dSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
DECLARE SUB C3dPath (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB C3dDraw (px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB C3dCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
DECLARE SUB C3dCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
DECLARE FUNCTION C3dSeg% (sg AS INTEGER, ofs AS INTEGER)
DECLARE SUB C3dPal (f AS INTEGER)
DECLARE FUNCTION C3dHold% (secs AS SINGLE)
DECLARE SUB C3dFree ()
DECLARE FUNCTION C3dTicks& ()
'----- GAME6
DECLARE FUNCTION VgaOpen& (pref AS INTEGER, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
DECLARE SUB VgaClose ()
DECLARE SUB VgaSync ()
DECLARE FUNCTION FileExists% (fil AS STRING)

'----- the work buffer (the car's screen box is at most 109x57, plus the
'----- join with the previous frame's box) and the backdrop strip's first row
CONST WKW = 136
CONST WKH = 72
CONST BGY0 = 96
'----- the drive (x16 units): the world line of tools\CAR3D.BAS, from screen
'----- (77,154) at depth 420 to depth 740 under the sprite's last x; the car
'----- heads along it (yaw = 90 deg - ATN(PDZ/PDX)), away from the camera
CONST PX0 = -2178
CONST PDX = 7219
CONST PY0 = -1418
CONST PDY = 0
CONST PZ0 = 6720
CONST PDZ = 5120
'----- the light (x256, camera space, towards it) for a lit model: upper left
CONST LX = -137
CONST LY = 154
CONST LZ = -153

REM $DYNAMIC
DIM SHARED rx(1) AS INTEGER, ry(1) AS INTEGER, rz(1) AS INTEGER
DIM SHARED sx(1) AS INTEGER, sy(1) AS INTEGER, tu(1) AS INTEGER, tv(1) AS INTEGER
DIM SHARED fa(1) AS C3dFac
DIM SHARED fband(1) AS INTEGER, ord(1) AS INTEGER, lnk(1) AS INTEGER, bkt(1) AS INTEGER
DIM SHARED bgb(1) AS INTEGER, wkb(1) AS INTEGER
DIM SHARED tb0(1) AS INTEGER, tb1(1) AS INTEGER, tb2(1) AS INTEGER, tb3(1) AS INTEGER
DIM SHARED tb4(1) AS INTEGER, tb5(1) AS INTEGER, tb6(1) AS INTEGER, tb7(1) AS INTEGER
REM $STATIC
DIM SHARED prm(0 TO 63) AS INTEGER, prq(0 TO 31) AS INTEGER, bt(0 TO 7) AS INTEGER
DIM SHARED nv AS INTEGER, nf AS INTEGER, unlit AS INTEGER, texW AS INTEGER, bands AS INTEGER
DIM SHARED bgseg AS INTEGER, bgo AS INTEGER, wseg AS INTEGER, wko AS INTEGER
DIM SHARED bx1 AS INTEGER, bx2 AS INTEGER, by1 AS INTEGER, by2 AS INTEGER
DIM SHARED ox AS INTEGER, oy AS INTEGER, ox2 AS INTEGER, oy2 AS INTEGER
DIM SHARED ovlTri AS STRING, ovlPrj AS STRING, ovlBop AS STRING, ovlEdge AS STRING, ovlBltm AS STRING
DIM SHARED palb AS STRING, dbg AS INTEGER

'----- IntroCar3D: the scene. 0 = done (mode 4 again, VRAM black), 1 = not
'----- available (nothing shown, Intro's CGA sprite drive follows), 2 = 's'
FUNCTION IntroCar3D% (f3 AS SINGLE, nfr AS SINGLE)
	DIM v AS LONG, xr AS INTEGER, yr AS INTEGER, np AS INTEGER, pref AS INTEGER, res AS INTEGER
	DIM ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG, stp AS INTEGER
	DIM qt AS LONG, cons AS LONG, cl AS LONG, du AS LONG, tc AS INTEGER, k AS STRING
	DIM t9 AS SINGLE, d9 AS SINGLE, need AS LONG, fre0 AS LONG, fre1 AS LONG, fh AS INTEGER
	DIM frames AS LONG, tk0 AS LONG, tk1 AS LONG, mxdu AS LONG, mndu AS LONG
	IntroCar3D% = 1
	res = 0
	dbg = 0
	dbg = VAL(ENVIRON$("C3DDUMP"))
	need = C3dProbe&
	IF need = 0 THEN EXIT FUNCTION
	fre0 = FRE(-1)
	IF fre0 < need THEN EXIT FUNCTION
	IF texW = 128 THEN CALL C3dLoadOvl("C3DT128.OVL", ovlTri) ELSE CALL C3dLoadOvl("C3DTRI.OVL", ovlTri)
	CALL C3dLoadOvl("C3DPRJ.OVL", ovlPrj)
	CALL C3dLoadOvl("SHADBOP.OVL", ovlBop)
	CALL C3dLoadOvl("C3DEDGE.OVL", ovlEdge)
	CALL C3dLoadOvl("C3DBLTM.OVL", ovlBltm)
	IF LEN(ovlTri) < 100 OR LEN(ovlPrj) < 50 OR LEN(ovlBop) < 50 THEN C3dFree: EXIT FUNCTION
	IF LEN(ovlEdge) < 50 OR LEN(ovlBltm) < 50 THEN C3dFree: EXIT FUNCTION
	'----- mode 13h first (uGL may take heap of its own), palette black
	pref = 320
	v = VgaOpen&(pref, xr, yr, np)
	IF v = 0 THEN C3dFree: EXIT FUNCTION
	CALL C3dPal(0)
	'----- every allocation now, none after C3dPoint
	REDIM bgb(0 TO (200 - BGY0) * 160 - 1) AS INTEGER
	REDIM wkb(0 TO (WKW * WKH) \ 2 - 1) AS INTEGER
	IF C3dLoadModel% = 0 THEN GOTO c3dfail
	IF C3dLoadTexture% = 0 THEN GOTO c3dfail
	CALL C3dPoint
	fre1 = FRE(-1)
	CALL C3dLoadBackdrop
	'----- the original: carr.pic black for a second, then the reveal with the
	'----- car at its start, two silent ticks, and off
	ox2 = -1
	ts = -5
	CALL C3dPath(ts, px, py, pz)
	CALL C3dDraw(px, py, pz)
	IF C3dHold%(1!) THEN res = 2: GOTO c3dout
	CALL C3dPal(16)
	IF C3dHold%(.11) THEN res = 2: GOTO c3dout
	'----- the drive, the engine sweep queued ahead in the background
	PLAY "MB"
	qt = 0: cl = 0: tc = 50: frames = 0: mxdu = 0: mndu = 999
	tk0 = C3dTicks&
	DO
		DO WHILE PLAY(0) < 36
			SOUND tc, .06
			SOUND f3, .06
			qt = qt + 2
			tc = tc + 18
			IF tc > 200 THEN tc = 50
		LOOP
		k = INKEY$
		IF k = "s" THEN res = 2: EXIT DO
		CALL C3dPath(ts, px, py, pz)
		CALL C3dDraw(px, py, pz)
		nfr = nfr + 1
		frames = frames + 1
		'----- notes played since the last frame (1.717 ms each) -> retraces
		'----- (8.313 notes) -> path steps
		cons = qt - PLAY(0)
		du = cons - cl: cl = cons
		stp = (du * 1000 + 4157) \ 8313
		IF stp < 1 THEN stp = 1
		IF stp > 4 THEN stp = 4
		ts = ts + stp
		IF dbg THEN
			IF frames > 1 THEN
				IF du > mxdu THEN mxdu = du
				IF du < mndu THEN mndu = du
			END IF
		END IF
	LOOP UNTIL ts > 205
	tk1 = C3dTicks&
	'----- the cut, with the car still rolling: black in the next blank while
	'----- the engine's last queued notes play out (the original cut to
	'----- hill.pic with the sweep still going)
	CALL C3dPal(0)
	t9 = TIMER
	DO WHILE PLAY(0) > 0
		d9 = TIMER - t9
		IF d9 < 0 OR d9 > .5 THEN EXIT DO
	LOOP
	PLAY "MF"
	IF dbg THEN
		fh = FREEFILE
		OPEN "C3D.LOG" FOR APPEND AS #fh
		PRINT #fh, "--- " + DATE$ + " " + TIME$ + " IntroCar3D: heap before"; fre0; " needed"; need; " after"; fre1; " strings"; FRE("")
		PRINT #fh, "tex"; texW; "x"; bands; " verts"; nv; " faces"; nf; " frames"; frames; " ticks"; tk1 - tk0; " notes played"; cons; " per frame min"; mndu; " max"; mxdu
		PRINT #fh, "steps/s"; INT(210 * 18.2 / ((tk1 - tk0) + .001)); " (70 = one per retrace)  res"; res
		CLOSE #fh
	END IF
c3dout:
	'----- black, then mode 4 again (Intro BLOADs hill.pic over black)
	CALL C3dPal(0)
	CALL VgaClose
	CALL C3dFree
	IntroCar3D% = res
	EXIT FUNCTION
c3dfail:
	CALL VgaClose
	CALL C3dFree
END FUNCTION

'----- C3dProbe: the files' headers -> texW, bands, nv, nf and the heap the
'----- scene needs; 0 = something is missing or wrong (BINARY open creates a
'----- missing file, so existence is checked first)
FUNCTION C3dProbe&
	DIM fh AS INTEGER, s AS STRING, w AS INTEGER, h AS INTEGER, hd AS C3dHdr, need AS LONG
	C3dProbe& = 0
	IF FileExists%("CAR3D.MDL") = 0 THEN EXIT FUNCTION
	IF FileExists%("CAR3D.BMP") = 0 THEN EXIT FUNCTION
	IF FileExists%("CARROAD.BMP") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DPRJ.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("SHADBOP.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DEDGE.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DBLTM.OVL") = 0 THEN EXIT FUNCTION
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 THEN CLOSE #fh: EXIT FUNCTION
	s = SPACE$(4)
	GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	GET #fh, 23, s: h = CVI(LEFT$(s, 2))
	CLOSE #fh
	IF w <> 64 AND w <> 128 THEN EXIT FUNCTION
	IF h < w OR h > w * 8 OR (h \ w) * w <> h THEN EXIT FUNCTION
	texW = w: bands = h \ w
	IF texW = 128 THEN
		IF FileExists%("C3DT128.OVL") = 0 THEN EXIT FUNCTION
	ELSE
		IF FileExists%("C3DTRI.OVL") = 0 THEN EXIT FUNCTION
	END IF
	OPEN "CARROAD.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 + 64000 THEN CLOSE #fh: EXIT FUNCTION
	CLOSE #fh
	OPEN "CAR3D.MDL" FOR BINARY AS #fh
	IF LOF(fh) < 10 THEN CLOSE #fh: EXIT FUNCTION
	GET #fh, , hd
	CLOSE #fh
	IF hd.magic <> "C3D2" THEN EXIT FUNCTION
	IF hd.nv < 3 OR hd.nf < 1 OR hd.nv > 2000 OR hd.nf > 2000 THEN EXIT FUNCTION
	'----- strip + work buffer + texture bands + model (14 bytes a vertex and
	'----- a face, the sort's lists) + the descriptors and slack
	need = CLNG(200 - BGY0) * 320 + CLNG(WKW) * WKH
	need = need + CLNG(bands) * (CLNG(w) * w + 32)
	need = need + CLNG(hd.nv) * 14 + CLNG(hd.nf) * 16 + 600 + 6000
	C3dProbe& = need
END FUNCTION

'----- C3dLoadModel: CAR3D.MDL (tools\car3dcnv.ps1: floats) -> the vertices
'----- rotated to the drive's heading in x16 units, texels in 8.8, the faces,
'----- their lighting band (a lit BMP) and the far-to-near order
FUNCTION C3dLoadModel%
	DIM fh AS INTEGER, i AS INTEGER, f AS INTEGER, bk AS INTEGER, n AS INTEGER, d AS INTEGER
	DIM h AS C3dHdr, vt AS C3dVtx, nm AS C3dNrm, t AS LONG, yaw AS SINGLE
	DIM cs AS INTEGER, sn AS INTEGER, x AS INTEGER, y AS INTEGER, z AS INTEGER
	DIM nxr AS INTEGER, nzr AS INTEGER, sh AS INTEGER, band AS INTEGER
	DIM nxi AS INTEGER, nyi AS INTEGER, nzi AS INTEGER
	C3dLoadModel% = 0
	fh = FREEFILE
	OPEN "CAR3D.MDL" FOR BINARY AS #fh
	GET #fh, , h
	IF h.magic <> "C3D2" THEN CLOSE #fh: EXIT FUNCTION
	nv = h.nv: nf = h.nf: unlit = h.flags AND 1
	IF nv < 3 OR nf < 1 OR nv > 2000 OR nf > 2000 THEN CLOSE #fh: EXIT FUNCTION
	IF LOF(fh) < 10 + CLNG(nv) * 20 + CLNG(nf) * 22 THEN CLOSE #fh: EXIT FUNCTION
	REDIM rx(0 TO nv - 1) AS INTEGER, ry(0 TO nv - 1) AS INTEGER, rz(0 TO nv - 1) AS INTEGER
	REDIM sx(0 TO nv - 1) AS INTEGER, sy(0 TO nv - 1) AS INTEGER
	REDIM tu(0 TO nv - 1) AS INTEGER, tv(0 TO nv - 1) AS INTEGER
	REDIM fa(0 TO nf - 1) AS C3dFac
	REDIM fband(0 TO nf - 1) AS INTEGER, ord(0 TO nf - 1) AS INTEGER
	REDIM lnk(0 TO nf - 1) AS INTEGER, bkt(0 TO 255) AS INTEGER
	'----- the heading: the long axis along the drive, the front leading
	yaw = 1.5708 - ATN(PDZ / PDX)
	cs = CINT(COS(yaw) * 256): sn = CINT(SIN(yaw) * 256)
	FOR i = 0 TO nv - 1
		GET #fh, , vt
		x = CINT(vt.x * 16): y = CINT(vt.y * 16): z = CINT(vt.z * 16)
		rx(i) = (CLNG(x) * cs + CLNG(z) * sn) \ 256
		rz(i) = (CLNG(z) * cs - CLNG(x) * sn) \ 256
		ry(i) = y
		'----- texel coordinates, 8.8 fixed point over the texture's width
		t = CLNG(vt.u * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		tu(i) = t
		t = CLNG(vt.v * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		tv(i) = t
	NEXT
	FOR f = 0 TO nf - 1
		GET #fh, , fa(f)
		IF fa(f).a < 0 OR fa(f).a >= nv OR fa(f).b < 0 OR fa(f).b >= nv OR fa(f).c < 0 OR fa(f).c >= nv OR fa(f).d >= nv THEN CLOSE #fh: EXIT FUNCTION
	NEXT
	FOR i = 0 TO 255: bkt(i) = -1: NEXT
	FOR f = 0 TO nf - 1
		GET #fh, , nm
		IF unlit OR bands < 2 THEN
			fband(f) = 0
		ELSE
			nxi = CINT(nm.x * 256): nyi = CINT(nm.y * 256): nzi = CINT(nm.z * 256)
			nxr = (CLNG(nxi) * cs + CLNG(nzi) * sn) \ 256
			nzr = (CLNG(nzi) * cs - CLNG(nxi) * sn) \ 256
			sh = (CLNG(nxr) * LX + CLNG(nyi) * LY + CLNG(nzr) * LZ) \ 256
			'----- band 0..7 = 3 + 4.5 * cos(angle to the light)
			band = (768 + (CLNG(sh) * 9) \ 2) \ 256
			IF band < 0 THEN band = 0
			IF band > bands - 1 THEN band = bands - 1
			fband(f) = band
		END IF
		'----- depth bucket by the summed z (x16 units, about +-4000)
		d = (rz(fa(f).a) + rz(fa(f).b) + rz(fa(f).c) + 4096) \ 32
		IF d < 0 THEN d = 0
		IF d > 255 THEN d = 255
		lnk(f) = bkt(d): bkt(d) = f
	NEXT
	CLOSE #fh
	n = 0
	FOR bk = 255 TO 0 STEP -1
		f = bkt(bk)
		DO WHILE f >= 0
			ord(n) = f: n = n + 1
			f = lnk(f)
		LOOP
	NEXT
	REDIM lnk(1) AS INTEGER, bkt(1) AS INTEGER
	C3dLoadModel% = -1
END FUNCTION

'----- C3dLoadTexture: the palette (BGRA x 256) and the pixels of CAR3D.BMP
'----- (texW wide, texW*bands rows, bottom-up) -> one 16-byte-aligned array
'----- per lighting band, its segment in bt(b): band b's texel row y sits at
'----- that segment, offset y*texW
FUNCTION C3dLoadTexture%
	DIM fh AS INTEGER, r AS INTEGER, h AS INTEGER, w AS INTEGER, b AS INTEGER, y AS INTEGER, s AS STRING
	C3dLoadTexture% = 0
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	s = SPACE$(4)
	GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	GET #fh, 23, s: h = CVI(LEFT$(s, 2))
	IF w <> texW OR h <> bands * w THEN CLOSE #fh: EXIT FUNCTION
	IF LOF(fh) < 1078 + CLNG(w) * h THEN CLOSE #fh: EXIT FUNCTION
	SEEK #fh, 55
	palb = INPUT$(1024, #fh)
	FOR b = 0 TO bands - 1: CALL C3dBand(b, w): NEXT
	FOR b = 0 TO bands - 1: bt(b) = C3dBandSeg%(b): NEXT
	FOR b = bands TO 7: bt(b) = bt(bands - 1): NEXT
	s = SPACE$(w)
	SEEK #fh, 1079
	FOR r = 0 TO h - 1
		GET #fh, , s
		y = h - 1 - r
		b = y \ w
		CALL C3dCopy(VARSEG(s), CLNG(SADD(s)), bt(b), CLNG(y - b * w) * w, 1, w, w, w)
	NEXT
	CLOSE #fh
	C3dLoadTexture% = -1
END FUNCTION

'----- C3dBand: band b's array, w*w bytes plus 16 for the alignment
SUB C3dBand (b AS INTEGER, w AS INTEGER)
	DIM n AS INTEGER
	n = (CLNG(w) * w + 16) \ 2
	SELECT CASE b
	CASE 0: REDIM tb0(0 TO n) AS INTEGER
	CASE 1: REDIM tb1(0 TO n) AS INTEGER
	CASE 2: REDIM tb2(0 TO n) AS INTEGER
	CASE 3: REDIM tb3(0 TO n) AS INTEGER
	CASE 4: REDIM tb4(0 TO n) AS INTEGER
	CASE 5: REDIM tb5(0 TO n) AS INTEGER
	CASE 6: REDIM tb6(0 TO n) AS INTEGER
	CASE 7: REDIM tb7(0 TO n) AS INTEGER
	END SELECT
END SUB

'----- C3dBandSeg: the segment at which band b's data starts at offset 0
FUNCTION C3dBandSeg% (b AS INTEGER)
	DIM tp AS INTEGER, sg AS INTEGER
	SELECT CASE b
	CASE 0: tp = VARPTR(tb0(0)): sg = VARSEG(tb0(0))
	CASE 1: tp = VARPTR(tb1(0)): sg = VARSEG(tb1(0))
	CASE 2: tp = VARPTR(tb2(0)): sg = VARSEG(tb2(0))
	CASE 3: tp = VARPTR(tb3(0)): sg = VARSEG(tb3(0))
	CASE 4: tp = VARPTR(tb4(0)): sg = VARSEG(tb4(0))
	CASE 5: tp = VARPTR(tb5(0)): sg = VARSEG(tb5(0))
	CASE 6: tp = VARPTR(tb6(0)): sg = VARSEG(tb6(0))
	CASE 7: tp = VARPTR(tb7(0)): sg = VARSEG(tb7(0))
	END SELECT
	C3dBandSeg% = C3dSeg%(sg, tp + ((16 - (tp AND 15)) AND 15))
END FUNCTION

'----- C3dLoadBackdrop: CARROAD.BMP (320x200, bottom-up, palette slots 0..15)
'----- -> VRAM whole, rows BGY0..199 into the strip the frames restore from
SUB C3dLoadBackdrop
	DIM fh AS INTEGER, y AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN "CARROAD.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 + 64000 THEN CLOSE #fh: EXIT SUB
	s = SPACE$(320)
	SEEK #fh, 1079
	FOR y = 199 TO 0 STEP -1
		GET #fh, , s
		CALL C3dCopy(VARSEG(s), CLNG(SADD(s)), &HA000, CLNG(y) * 320, 1, 320, 320, 320)
		IF y >= BGY0 THEN CALL C3dCopy(VARSEG(s), CLNG(SADD(s)), bgseg, CLNG(bgo) + CLNG(y - BGY0) * 320, 1, 320, 320, 320)
	NEXT
	CLOSE #fh
END SUB

'----- C3dPoint: the buffers' addresses for the routines (after the last
'----- allocation: the far heap may move arrays)
SUB C3dPoint
	bgseg = C3dSeg%(VARSEG(bgb(0)), VARPTR(bgb(0))): bgo = VARPTR(bgb(0)) AND 15
	wseg = C3dSeg%(VARSEG(wkb(0)), VARPTR(wkb(0))): wko = VARPTR(wkb(0)) AND 15
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
	prq(0) = VARSEG(rx(0)): prq(1) = VARPTR(rx(0))
	prq(2) = VARSEG(ry(0)): prq(3) = VARPTR(ry(0))
	prq(4) = VARSEG(rz(0)): prq(5) = VARPTR(rz(0))
	prq(6) = VARSEG(sx(0)): prq(7) = VARPTR(sx(0))
	prq(8) = VARSEG(sy(0)): prq(9) = VARPTR(sy(0))
	prq(10) = nv
END SUB

'----- C3dPath: world position (x16 units) at step ts of 200 along the drive
SUB C3dPath (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG)
	px = PX0 + (CLNG(ts) * PDX) \ 200
	py = PY0 + (CLNG(ts) * PDY) \ 200
	pz = PZ0 + (CLNG(ts) * PDZ) \ 200
END SUB

'----- C3dDraw: C3DPRJ projects the model at (px,py,pz) and gives its screen
'----- box; the work buffer goes over the join of that box and the last one,
'----- filled from the strip, the faces drawn into it, the silhouette marked,
'----- and the block copied to VRAM in the vertical blank
SUB C3dDraw (px AS LONG, py AS LONG, pz AS LONG)
	DIM bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER, dx AS INTEGER, dy AS INTEGER
	DIM rw AS INTEGER, rh AS INTEGER, wo AS LONG, w1 AS INTEGER
	CALL C3dSplit(px, prq(11), prq(12))
	CALL C3dSplit(py, prq(13), prq(14))
	CALL C3dSplit(pz, prq(15), prq(16))
	DEF SEG = VARSEG(ovlPrj)
	CALL ABSOLUTE(BYVAL VARSEG(prq(0)), BYVAL VARPTR(prq(0)), SADD(ovlPrj))
	DEF SEG
	'----- the projection is in 1/16 pixel; the box in whole pixels, padded
	'----- for the ink, joined with the last frame's, kept inside the strip
	bx1 = prq(17) \ 16: bx2 = prq(18) \ 16: by1 = prq(19) \ 16: by2 = prq(20) \ 16
	bx = bx1 - 1: by = by1 - 1: ex = bx2 + 2: ey = by2 + 2
	IF ox2 >= 0 THEN
		IF ox < bx THEN bx = ox
		IF oy < by THEN by = oy
		IF ox2 > ex THEN ex = ox2
		IF oy2 > ey THEN ey = oy2
	END IF
	IF bx < 0 THEN bx = 0
	IF by < BGY0 THEN by = BGY0
	IF ex > 319 THEN ex = 319
	IF ey > 199 THEN ey = 199
	ox = bx1 - 1: oy = by1 - 1: ox2 = bx2 + 2: oy2 = by2 + 2
	IF ox < 0 THEN ox = 0
	IF oy < BGY0 THEN oy = BGY0
	IF ox2 > 319 THEN ox2 = 319
	IF oy2 > 199 THEN oy2 = 199
	'----- the work buffer's place on screen: over the box, inside the screen
	dx = bx: dy = by
	IF dx > 320 - WKW THEN dx = 320 - WKW
	IF dy > 200 - WKH THEN dy = 200 - WKH
	IF ex > dx + WKW - 1 THEN ex = dx + WKW - 1
	IF ey > dy + WKH - 1 THEN ey = dy + WKH - 1
	rw = ex - bx + 1: rh = ey - by + 1
	IF rw < 1 OR rh < 1 THEN EXIT SUB
	wo = CLNG(wko) + CLNG(by - dy) * WKW + (bx - dx)
	CALL C3dCopy(bgseg, CLNG(bgo) + CLNG(by - BGY0) * 320 + bx, wseg, wo, rh, rw, 320, WKW)
	prm(20) = dx * 16: prm(21) = dy * 16: prm(22) = 0
	DEF SEG = VARSEG(ovlTri)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
	DEF SEG
	'----- silhouette ink: car pixels that border the background get marked
	'----- (254) and turn brown (3) in the copy, like the sprite's drawn outline
	IF rw >= 2 AND rh >= 2 THEN
		w1 = wo
		DEF SEG = VARSEG(ovlEdge)
		CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL WKW, BYVAL rw, BYVAL rh, SADD(ovlEdge))
		DEF SEG
	END IF
	CALL VgaSync
	CALL C3dCopyM(wseg, wo, &HA000, CLNG(by) * 320 + bx, rh, rw, WKW, 320, 3)
END SUB

'----- C3dCopy: SHADBOP.OVL mode 0 - rows x nb bytes from sg:so (stride sst)
'----- to dg:dof (stride dst); offsets as LONG 0..65535
SUB C3dCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBop)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL 0, SADD(ovlBop))
	DEF SEG
END SUB

'----- C3dCopyM: C3DBLTM.OVL - the same copy, every 254 written as colour col
SUB C3dCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBltm)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL col, SADD(ovlBltm))
	DEF SEG
END SUB

'----- C3dSeg: the segment at which (sg:ofs) is offset 0..15
FUNCTION C3dSeg% (sg AS INTEGER, ofs AS INTEGER)
	DIM s AS LONG, o AS LONG
	s = sg: IF s < 0 THEN s = s + 65536
	o = ofs: IF o < 0 THEN o = o + 65536
	s = s + o \ 16
	IF s > 32767 THEN s = s - 65536
	C3dSeg% = s
END FUNCTION

'----- C3dSplit: LONG -> two words (lo as the signed INTEGER of the low 16 bits)
SUB C3dSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
	DIM l AS LONG
	l = v AND &HFFFF&
	hi = (v - l) \ 65536
	IF l > 32767 THEN l = l - 65536
	lo = l
END SUB

SUB C3dLoadOvl (fil AS STRING, s AS STRING)
	DIM n AS INTEGER
	n = FREEFILE
	OPEN fil FOR BINARY AS #n
	s = SPACE$(LOF(n))
	IF LOF(n) > 0 THEN GET #n, 1, s
	CLOSE #n
END SUB

'----- C3dPal: CAR3D.BMP's palette (BGRA entries in palb) to the DAC, scaled
'----- by f/16 (0 = black, 16 = as authored), in the vertical blank
SUB C3dPal (f AS INTEGER)
	DIM i AS INTEGER, p AS INTEGER
	CALL VgaSync
	OUT &H3C8, 0
	'----- black needs no palette: the first C3dPal(0) comes right after the
	'----- mode switch, before CAR3D.BMP (which carries the palette) is read
	IF f = 0 OR LEN(palb) < 1024 THEN
		FOR i = 0 TO 767: OUT &H3C9, 0: NEXT
		EXIT SUB
	END IF
	FOR i = 0 TO 255
		p = i * 4
		OUT &H3C9, ((ASC(MID$(palb, p + 3, 1)) \ 4) * f) \ 16
		OUT &H3C9, ((ASC(MID$(palb, p + 2, 1)) \ 4) * f) \ 16
		OUT &H3C9, ((ASC(MID$(palb, p + 1, 1)) \ 4) * f) \ 16
	NEXT
END SUB

'----- C3dHold: wait secs (midnight-safe); -1 if 's' (skip the intro) came
FUNCTION C3dHold% (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	C3dHold% = 0
	t9 = TIMER
	DO
		IF INKEY$ = "s" THEN C3dHold% = -1: EXIT FUNCTION
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END FUNCTION

'----- C3dFree: the heap and the strings back
SUB C3dFree
	REDIM rx(1) AS INTEGER, ry(1) AS INTEGER, rz(1) AS INTEGER
	REDIM sx(1) AS INTEGER, sy(1) AS INTEGER, tu(1) AS INTEGER, tv(1) AS INTEGER
	REDIM fa(1) AS C3dFac
	REDIM fband(1) AS INTEGER, ord(1) AS INTEGER, lnk(1) AS INTEGER, bkt(1) AS INTEGER
	REDIM bgb(1) AS INTEGER, wkb(1) AS INTEGER
	REDIM tb0(1) AS INTEGER, tb1(1) AS INTEGER, tb2(1) AS INTEGER, tb3(1) AS INTEGER
	REDIM tb4(1) AS INTEGER, tb5(1) AS INTEGER, tb6(1) AS INTEGER, tb7(1) AS INTEGER
	ovlTri = "": ovlPrj = "": ovlBop = "": ovlEdge = "": ovlBltm = "": palb = ""
END SUB

'----- C3dTicks: the BIOS tick count (18.2 Hz) for the C3DDUMP log
FUNCTION C3dTicks&
	DEF SEG = &H40
	C3dTicks& = CLNG(PEEK(&H6C)) + 256& * PEEK(&H6D) + 65536 * PEEK(&H6E)
	DEF SEG
END FUNCTION
