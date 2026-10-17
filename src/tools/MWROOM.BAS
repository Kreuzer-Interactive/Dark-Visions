'----- MWROOM.BAS: MANWALK's room module -- the walk mask and the path finder, the
'----- front pieces' loading, the room's things from the game's .PAC and the text line,
'----- picking a floor point, the depth scale, the mouse and its arrow. Built and linked
'----- with MANWALK.BAS (tools\build1.ps1 MANWALK -Modules MWROOM); the shared data is
'----- MANWALK.BI's COMMON SHARED.
DEFINT A-Z
'$INCLUDE: 'MANWALK.BI'
'----- LoadWalk: ROOM.WLK (8000 bytes: the walk mask, 1 bit a pixel, high bit
'----- left) -> wmk(); the path grid over the floor, each cell walkable when the
'----- mask is at its centre. Nothing (wmOn = 0: the floor's own bounds only)
'----- without the file
SUB LoadWalk
	DIM fh AS INTEGER, s AS STRING, k AS INTEGER, ix AS INTEGER, iz AS INTEGER, c AS INTEGER
	wmOn = 0
	fh = FREEFILE
	OPEN "ROOM.WLK" FOR BINARY AS #fh
	IF LOF(fh) <> 8000 THEN
		k = (LOF(fh) = 0)
		CLOSE #fh
		IF k THEN KILL "ROOM.WLK"
		EXIT SUB
	END IF
	s = SPACE$(8000): GET #fh, 1, s: CLOSE #fh
	FOR k = 0 TO 3999: wmk(k) = CVI(MID$(s, k * 2 + 1, 2)): NEXT
	FOR k = 0 TO 7: bitv(k) = 128 \ (2 ^ k): NEXT
	'----- the eight steps: the four straight ones first
	ddx(0) = 1: ddz(0) = 0: ddx(1) = -1: ddz(1) = 0: ddx(2) = 0: ddz(2) = 1: ddx(3) = 0: ddz(3) = -1
	ddx(4) = 1: ddz(4) = 1: ddx(5) = -1: ddz(5) = 1: ddx(6) = 1: ddz(6) = -1: ddx(7) = -1: ddz(7) = -1
	wmOn = 1
	gx0 = -INT(rxn) - GCELL: gnx = INT(2 * rxn / GCELL) + 3
	gz0 = INT(rzn): gnz = INT((rzf - rzn) / GCELL) + 2
	REDIM gwk(0 TO gnx * gnz - 1) AS INTEGER, gpar(0 TO gnx * gnz - 1) AS INTEGER, gq(0 TO gnx * gnz - 1) AS INTEGER
	FOR iz = 0 TO gnz - 1
		FOR ix = 0 TO gnx - 1
			c = iz * gnx + ix
			gwk(c) = MaskAt%(CLNG(gx0 * 16) + CLNG(ix) * GCELL * 16 + GCELL * 8, CLNG(gz0 * 16) + CLNG(iz) * GCELL * 16 + GCELL * 8)
		NEXT
	NEXT
END SUB

'----- MaskAt: the walk mask at the floor point (x16, z16), x16 units: 1 walkable
FUNCTION MaskAt% (x16 AS LONG, z16 AS LONG)
	DIM z AS SINGLE, sx AS INTEGER, sy AS INTEGER, b AS INTEGER
	MaskAt% = 0
	IF z16 < 160 THEN EXIT FUNCTION
	z = z16 / 16!
	sx = CINT(rcx + rfx * (x16 / 16!) / z): sy = CINT(rcy + 256 * rch / z)
	IF sx < 0 OR sx > 319 OR sy < 0 OR sy > 199 THEN EXIT FUNCTION
	DEF SEG = VARSEG(wmk(0)): b = PEEK(VARPTR(wmk(0)) + sy * 40 + sx \ 8): DEF SEG
	IF b AND bitv(sx AND 7) THEN MaskAt% = 1
END FUNCTION

'----- CellOf: the path grid's cell under (x16, z16), kept on the grid
FUNCTION CellOf% (x16 AS LONG, z16 AS LONG)
	DIM ix AS LONG, iz AS LONG
	ix = (x16 - CLNG(gx0) * 16) \ (GCELL * 16): iz = (z16 - CLNG(gz0) * 16) \ (GCELL * 16)
	IF ix < 0 THEN ix = 0
	IF ix > gnx - 1 THEN ix = gnx - 1
	IF iz < 0 THEN iz = 0
	IF iz > gnz - 1 THEN iz = gnz - 1
	CellOf% = iz * gnx + ix
END FUNCTION

'----- LineClear: the floor between two points (x16 units) walkable all along --
'----- the grid's cells every half a cell (the first point's own cell not asked)
FUNCTION LineClear% (ax AS LONG, az AS LONG, bx AS LONG, bz AS LONG)
	DIM n AS LONG, k AS LONG, dx AS LONG, dz AS LONG
	LineClear% = 0
	dx = bx - ax: dz = bz - az
	n = ABS(dx): IF ABS(dz) > n THEN n = ABS(dz)
	n = n \ (GCELL * 8) + 1
	FOR k = 1 TO n
		IF gwk(CellOf%(ax + dx * k \ n, az + dz * k \ n)) = 0 THEN EXIT FUNCTION
	NEXT
	LineClear% = 1
END FUNCTION

'----- FindPath: from (sx16, sz16) towards (tx, tz) -> wpx/wpz, nwp waypoints
'----- (0: nowhere to go). Breadth first over the grid's walkable cells, eight
'----- ways (a diagonal only past two walkable sides); the goal the target's cell,
'----- or the reached cell nearest it; the cells' centres back from the goal,
'----- then pulled straight: from each waypoint on to the farthest one the floor
'----- is clear to. The last waypoint is the target itself when it is walkable
SUB FindPath (sx16 AS LONG, sz16 AS LONG, tx AS LONG, tz AS LONG)
	DIM s AS INTEGER, g AS INTEGER, c AS INTEGER, n AS INTEGER, d AS INTEGER, qh AS INTEGER, qt AS INTEGER
	DIM ix AS INTEGER, iz AS INTEGER, nx AS INTEGER, nz AS INTEGER, m AS INTEGER, a AS INTEGER, b AS INTEGER, k AS INTEGER
	DIM best AS LONG, dd AS LONG, gx AS INTEGER, gz AS INTEGER, t1 AS LONG
	t1 = PitNow&
	nwp = 0
	FOR c = 0 TO gnx * gnz - 1: gpar(c) = -1: NEXT
	s = CellOf%(sx16, sz16)
	gpar(s) = s: qh = 0: qt = 1: gq(0) = s
	DO WHILE qh < qt
		c = gq(qh): qh = qh + 1
		ix = c MOD gnx: iz = c \ gnx
		FOR d = 0 TO 7
			nx = ix + ddx(d): nz = iz + ddz(d)
			IF nx >= 0 AND nx < gnx AND nz >= 0 AND nz < gnz THEN
				n = nz * gnx + nx
				IF gpar(n) < 0 THEN
					IF gwk(n) THEN
						IF d < 4 THEN
							gpar(n) = c: gq(qt) = n: qt = qt + 1
						ELSEIF gwk(iz * gnx + nx) <> 0 AND gwk(nz * gnx + ix) <> 0 THEN
							gpar(n) = c: gq(qt) = n: qt = qt + 1
						END IF
					END IF
				END IF
			END IF
		NEXT
	LOOP
	'----- the goal: the target's own cell if reached, else the reached cell nearest it
	g = CellOf%(tx, tz)
	IF gpar(g) < 0 OR gwk(g) = 0 THEN
		gx = g MOD gnx: gz = g \ gnx: best = 2147483647
		FOR k = 0 TO qt - 1
			c = gq(k)
			IF gwk(c) OR c = s THEN
				nx = c MOD gnx - gx: nz = c \ gnx - gz: dd = CLNG(nx) * nx + CLNG(nz) * nz
				IF dd < best THEN best = dd: g = c
			END IF
		NEXT
		tx = CLNG(gx0) * 16 + CLNG(g MOD gnx) * GCELL * 16 + GCELL * 8
		tz = CLNG(gz0) * 16 + CLNG(g \ gnx) * GCELL * 16 + GCELL * 8
	ELSEIF MaskAt%(tx, tz) = 0 THEN
		tx = CLNG(gx0) * 16 + CLNG(g MOD gnx) * GCELL * 16 + GCELL * 8
		tz = CLNG(gz0) * 16 + CLNG(g \ gnx) * GCELL * 16 + GCELL * 8
	END IF
	'----- the cells back from the goal (pcx/pcz: the start, the cells, the target)
	m = 0: c = g
	DO WHILE c <> s AND m < 250
		pcx(m) = CLNG(gx0) * 16 + CLNG(c MOD gnx) * GCELL * 16 + GCELL * 8
		pcz(m) = CLNG(gz0) * 16 + CLNG(c \ gnx) * GCELL * 16 + GCELL * 8
		m = m + 1: c = gpar(c)
	LOOP
	pcx(m) = sx16: pcz(m) = sz16: m = m + 1
	FOR k = 0 TO m \ 2 - 1
		SWAP pcx(k), pcx(m - 1 - k): SWAP pcz(k), pcz(m - 1 - k)
	NEXT
	pcx(m - 1) = tx: pcz(m - 1) = tz
	IF m = 1 THEN pcx(1) = tx: pcz(1) = tz: m = 2
	'----- pulled straight
	a = 0
	DO WHILE a < m - 1 AND nwp < 64
		b = a + 1
		DO WHILE b < m - 1
			IF LineClear%(pcx(a), pcz(a), pcx(b + 1), pcz(b + 1)) = 0 THEN EXIT DO
			b = b + 1
		LOOP
		wpx(nwp) = pcx(b): wpz(nwp) = pcz(b): nwp = nwp + 1
		a = b
	LOOP
	pathms = Ms!(t1, PitNow&)
END SUB

'----- LoadOcc: ROOM.OCC ("C3O1", n%, then per piece x0% y0% w% h% base%, then
'----- the masks, w x h bytes each) -> the front pieces, sorted far to near;
'----- none (nocc = 0) without the file or C3DMCPY.OVL
SUB LoadOcc
	DIM fh AS INTEGER, tag AS STRING, n AS INTEGER, k AS INTEGER, j AS INTEGER, b AS INTEGER, tot AS INTEGER, s AS STRING, ln AS LONG
	nocc = 0
	IF LEN(ovlMcpy) < 30 THEN EXIT SUB
	fh = FREEFILE
	OPEN "ROOM.OCC" FOR BINARY AS #fh
	ln = LOF(fh)
	IF ln < 6 THEN
		CLOSE #fh
		IF ln = 0 THEN KILL "ROOM.OCC"
		EXIT SUB
	END IF
	tag = SPACE$(4): GET #fh, 1, tag: GET #fh, , n
	IF tag <> "C3O1" OR n < 1 OR n > 16 THEN CLOSE #fh: EXIT SUB
	tot = 0
	FOR k = 0 TO n - 1
		GET #fh, , ocx0(k): GET #fh, , ocy0(k): GET #fh, , ocw(k): GET #fh, , och(k): GET #fh, , b
		ooff(k) = tot: tot = tot + ocw(k) * och(k)
		'----- its depth: the floor where its lowest pixel stands
		IF b > rcy + 1 THEN odep(k) = CLNG(256 * rch / (b - rcy) * 16) ELSE odep(k) = 2147483647
		oord(k) = k
	NEXT
	REDIM ocm(0 TO tot \ 2 + 1) AS INTEGER
	s = SPACE$(tot): GET #fh, , s: CLOSE #fh
	DEF SEG = VARSEG(ocm(0))
	FOR k = 0 TO tot - 1: POKE VARPTR(ocm(0)) + k, ASC(MID$(s, k + 1, 1)): NEXT
	DEF SEG
	'----- far to near
	FOR k = 1 TO n - 1
		FOR j = 0 TO n - 1 - k
			IF odep(oord(j)) < odep(oord(j + 1)) THEN SWAP oord(j), oord(j + 1)
		NEXT
	NEXT
	nocc = n
END SUB

'----- LoadPac: ROOM.PAC (the game's room file): the header line, hit points
'----- "x,y,obj" to a "0,0,0", the 25 objects (target, text, verb / item needed,
'----- flag, state, tag), then placements, of which the "-2,obj,x,y,dir" stand points
SUB LoadPac
	DIM fh AS INTEGER, ln AS LONG, l AS STRING, tx AS INTEGER, ty AS INTEGER, ti AS INTEGER, k AS INTEGER
	DIM d1 AS STRING, m AS STRING, ky AS STRING, b1 AS INTEGER, c1 AS INTEGER, s1 AS INTEGER, tg AS STRING
	DIM pa AS INTEGER, pb AS INTEGER, pc AS INTEGER, pd AS INTEGER, pe AS INTEGER
	nhot = 0
	fh = FREEFILE
	OPEN "ROOM.PAC" FOR BINARY AS #fh: ln = LOF(fh): CLOSE #fh
	IF ln = 0 THEN KILL "ROOM.PAC": EXIT SUB
	OPEN "ROOM.PAC" FOR INPUT AS #fh
	LINE INPUT #fh, l
	DO
		INPUT #fh, tx, ty, ti
		IF ty = 0 THEN EXIT DO
		IF nhot < 257 AND ti >= 1 AND ti <= 25 THEN hpx(nhot) = tx: hpy(nhot) = ty: hpo(nhot) = ti: nhot = nhot + 1
	LOOP
	FOR k = 1 TO 25
		INPUT #fh, d1, m, ky: INPUT #fh, b1, c1, s1, tg
		omsg(k) = m: oky(k) = ky: obs(k) = b1: ospx(k) = -1: ospd(k) = 0
	NEXT
	DO WHILE NOT EOF(fh)
		INPUT #fh, pa, pb, pc, pd, pe
		IF pa = -2 AND pb >= 1 AND pb <= 25 THEN ospx(pb) = pc: ospy(pb) = pd: ospd(pb) = pe
	LOOP
	CLOSE #fh
END SUB

'----- PacHit: the object a click at (x, y) means for verb v ("a" action, "l"
'----- look), 0 none -- the game's way: a hit point in the click's 4-pixel cell,
'----- else the nearest within 6 pixels, of an object with that verb that needs no
'----- item (all flags are clear at the start); its point in phx, phy
FUNCTION PacHit% (x AS INTEGER, y AS INTEGER, v AS STRING)
	DIM k AS INTEGER, o AS INTEGER, b AS INTEGER, a AS INTEGER, dx AS INTEGER, dy AS INTEGER, d AS INTEGER, best AS INTEGER
	PacHit% = 0
	b = (x \ 4) * 4 + 2: a = (y \ 4) * 4 + 2
	FOR k = 0 TO nhot - 1
		o = hpo(k)
		IF hpx(k) = b AND hpy(k) = a AND oky(o) = v AND obs(o) = 0 THEN phx = b: phy = a: PacHit% = o: EXIT FUNCTION
	NEXT
	best = 37
	FOR k = 0 TO nhot - 1
		o = hpo(k)
		IF oky(o) = v AND obs(o) = 0 THEN
			dx = x - hpx(k): dy = y - hpy(k)
			IF ABS(dx) <= 6 AND ABS(dy) <= 6 THEN
				d = dx * dx + dy * dy
				IF d < best THEN best = d: PacHit% = o: phx = hpx(k): phy = hpy(k)
			END IF
		END IF
	NEXT
END FUNCTION

'----- SayObj: object h's text under the room, the game's 40 columns a line, the
'----- |item| bars dropped (hsaid counts what was said, hlast the last one)
SUB SayObj (h AS INTEGER)
	DIM m AS STRING, k AS INTEGER
	m = RTRIM$(omsg(h))
	DO
		k = INSTR(m, "|"): IF k = 0 THEN EXIT DO
		m = LEFT$(m, k - 1) + MID$(m, k + 1)
	LOOP
	CALL DrawLabel(RTRIM$(LEFT$(m, 40)), LTRIM$(RTRIM$(MID$(m, 41, 40))))
	hsaid = hsaid + 1: hlast = h
END SUB

'----- DigitAim: a point far along numpad direction d on the screen from (px, pz)
'----- (8 into the room, 2 out of it, 4 left, 6 right, 7 9 1 3 between) -- the yaw
'----- whose forward (-sin, -cos) points that way
SUB DigitAim (d AS INTEGER, px AS LONG, pz AS LONG, tx AS LONG, tz AS LONG)
	DIM y AS SINGLE
	SELECT CASE d
	CASE 2: y = 0
	CASE 1: y = .7854
	CASE 4: y = 1.5708
	CASE 7: y = 2.3562
	CASE 8: y = 3.1416
	CASE 9: y = 3.927
	CASE 6: y = 4.7124
	CASE ELSE: y = 5.4978
	END SELECT
	tx = px - CLNG(SIN(y) * 16000): tz = pz - CLNG(COS(y) * 16000)
END SUB

'----- DrawLabel: two lines centred on rows 181..188 and 190..197 in the PC's ROM
'----- font (F000:FA6E, 8 x 8), brown, into the backdrop (so the frame's copies keep
'----- them) and onto the screen
SUB DrawLabel (s1 AS STRING, s2 AS STRING)
	DIM i AS INTEGER, r AS INTEGER, c AS INTEGER, b AS INTEGER, m AS INTEGER, x AS INTEGER, o AS LONG, fb(0 TO 7) AS INTEGER
	DIM ln AS INTEGER, s AS STRING, y0 AS INTEGER
	DEF SEG = bgseg
	FOR r = 180 TO 199
		o = bgo + r * 320&
		FOR c = 0 TO 319: POKE o + c, 0: NEXT
	NEXT
	FOR ln = 0 TO 1
		IF ln = 0 THEN s = s1: y0 = 181 ELSE s = s2: y0 = 190
		x = 160 - LEN(s) * 4
		FOR i = 1 TO LEN(s)
			b = ASC(MID$(s, i, 1)) AND 127
			DEF SEG = &HF000
			FOR r = 0 TO 7: fb(r) = PEEK(64110& + b * 8 + r): NEXT
			DEF SEG = bgseg
			FOR r = 0 TO 7
				o = bgo + (y0 + r) * 320& + x + (i - 1) * 8: m = 128
				FOR c = 0 TO 7
					IF fb(r) AND m THEN POKE o + c, 3
					m = m \ 2
				NEXT
			NEXT
		NEXT
	NEXT
	DEF SEG
	CALL RectCopy(bgseg, bgo + 180 * 320&, &HA000, 180 * 320&, 20, 320, 320, 320)
END SUB

'----- FloorPick: the floor point under screen (qx, qy), x16 units -- the ray
'----- through the pixel met with the floor (the camera rch above it in a room,
'----- -GROUNDY on the road). clampit: kept where he can walk (the floor less
'----- his reach from the walls; a click above the floor goes to the back);
'----- else as far as the back of the floor when the ray misses it
SUB FloorPick (qx AS INTEGER, qy AS INTEGER, clampit AS INTEGER, tx AS LONG, tz AS LONG)
	DIM h AS SINGLE, cx AS SINGLE, cy AS SINGLE, fh AS SINGLE, z AS SINGLE, x AS SINGLE, lim AS SINGLE, zl AS LONG
	IF roomOn THEN h = rch: cx = rcx: cy = rcy: fh = rfx ELSE h = -GROUNDY: cx = 160: cy = 100: fh = 256
	IF qy > cy + 1 THEN z = 256 * h / (qy - cy) ELSE z = 100000
	IF clampit OR z > 50000 THEN
		IF roomOn THEN
			IF z < rzn + 14 THEN z = rzn + 14
			IF z > rzf - 14 THEN z = rzf - 14
		ELSE
			IF z < 140 THEN z = 140
			IF z > 900 THEN z = 900
		END IF
	END IF
	x = (qx - cx) * z / fh
	IF clampit THEN
		zl = CLNG(z * 16)
		IF roomOn THEN lim = RoomX!(zl) - 14 * RoomK!(zl) ELSE lim = z / 2
		IF x > lim THEN x = lim
		IF x < -lim THEN x = -lim
	END IF
	tx = CLNG(x * 16): tz = CLNG(z * 16)
END SUB

'----- Atn2: the angle of (x, y) in -pi..pi
FUNCTION Atn2! (y AS SINGLE, x AS SINGLE)
	IF x > 0 THEN
		Atn2! = ATN(y / x)
	ELSEIF x < 0 THEN
		IF y >= 0 THEN Atn2! = ATN(y / x) + 3.14159 ELSE Atn2! = ATN(y / x) - 3.14159
	ELSE
		IF y > 0 THEN Atn2! = 1.5708 ELSE IF y < 0 THEN Atn2! = -1.5708 ELSE Atn2! = 0
	END IF
END FUNCTION

'----- Mouse: INT 33h with mreg() as ax, bx, cx, dx (C3DMSE.OVL)
SUB Mouse
	DEF SEG = VARSEG(ovlMse)
	CALL ABSOLUTE(BYVAL VARSEG(mreg(0)), BYVAL VARPTR(mreg(0)), SADD(ovlMse))
	DEF SEG
END SUB

'----- the arrow's 8 x 11 box at (x, y), cut at the screen's edge: CurCopy the
'----- backdrop into the work buffer, CurDraw the arrow into it, CurBlit it to VRAM
SUB CurCopy (x AS INTEGER, y AS INTEGER)
	DIM w AS INTEGER, h AS INTEGER, o AS LONG
	w = 8: IF x + w > 320 THEN w = 320 - x
	h = 11: IF y + h > 200 THEN h = 200 - y
	IF w <= 0 OR h <= 0 THEN EXIT SUB
	o = CLNG(y) * 320 + x
	CALL RectCopy(bgseg, bgo + o, wseg, wko + o, h, w, 320, 320)
END SUB

SUB CurDraw (x AS INTEGER, y AS INTEGER)
	DIM r AS INTEGER, c AS INTEGER, ch AS STRING, o AS LONG
	DEF SEG = wseg
	FOR r = 0 TO 10
		IF y + r <= 199 THEN
			o = CLNG(wko) + CLNG(y + r) * 320 + x
			FOR c = 0 TO 7
				IF x + c <= 319 THEN
					ch = MID$(curs(r), c + 1, 1)
					IF ch = "1" THEN POKE o + c, 12
					IF ch = "2" THEN POKE o + c, 13
				END IF
			NEXT
		END IF
	NEXT
	DEF SEG
END SUB

SUB CurBlit (x AS INTEGER, y AS INTEGER)
	DIM w AS INTEGER, h AS INTEGER, o AS LONG
	w = 8: IF x + w > 320 THEN w = 320 - x
	h = 11: IF y + h > 200 THEN h = 200 - y
	IF w <= 0 OR h <= 0 THEN EXIT SUB
	o = CLNG(y) * 320 + x
	CALL RectCopyM(wseg, wko + o, &HA000, o, h, w, 320, 320, 15)
END SUB

'----- RoomK: his scale at depth z (x16 units) in a room: the art's perspective
'----- shrinks him to zNear/zFar at the back wall; drawn this much bigger, his size
'----- falls only to rbs there, evenly with the depth
FUNCTION RoomK! (z AS LONG)
	DIM t AS SINGLE, zz AS SINGLE
	IF roomOn = 0 THEN RoomK! = 1: EXIT FUNCTION
	zz = z / 16
	t = (zz - rzn) / (rzf - rzn)
	IF t < 0 THEN t = 0
	IF t > 1 THEN t = 1
	RoomK! = rsc * (1 + (rbs - 1) * t) * zz / rzn
END FUNCTION

'----- RoomX: the floor's half width at depth z (x16 units): the drawn floor line,
'----- a straight line from the near corner to the far one
FUNCTION RoomX! (z AS LONG)
	RoomX! = rxn + (z / 16 - rzn) * (rxf - rxn) / (rzf - rzn)
END FUNCTION

