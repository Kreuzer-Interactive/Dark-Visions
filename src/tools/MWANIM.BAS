'----- MWANIM.BAS: MANWALK's animation module -- the walk (MAN3D.ANI) and the idle
'----- and turning-step clips (MANIDLE.ANI, skinned by C3DSKIN.OVL), choosing a pose,
'----- and the rotate-and-sort call that poses a model. Built and linked with
'----- MANWALK.BAS (tools\build1.ps1 MANWALK -Modules MWROOM,MWANIM); the shared data
'----- is MANWALK.BI's COMMON SHARED.
DEFINT A-Z
'$INCLUDE: 'MANWALK.BI'
'----- LoadIdle: MANIDLE.ANI (C3I1) -> idm(), ibw(), the clip tables, inc = the
'----- number of clips; nothing (inc = 0: he stands in the rest pose) when it or
'----- C3DSKIN.OVL is missing or it was made for another model
SUB LoadIdle
	DIM fh AS INTEGER, ln AS LONG, tag AS STRING, n AS INTEGER, nb AS INTEGER, nc AS INTEGER
	DIM c AS INTEGER, k AS INTEGER, g AS INTEGER, nfr AS INTEGER, lp AS INTEGER, d AS INTEGER
	DIM tot AS INTEGER, p AS INTEGER, m AS INTEGER, acc AS INTEGER, s AS STRING
	inc = 0
	IF LEN(ovlSkin) < 50 THEN EXIT SUB
	fh = FREEFILE
	OPEN "MANIDLE.ANI" FOR BINARY AS #fh
	ln = LOF(fh)
	IF ln < 12 THEN
		CLOSE #fh
		IF ln = 0 THEN KILL "MANIDLE.ANI"
		EXIT SUB
	END IF
	tag = SPACE$(4)
	GET #fh, 1, tag: GET #fh, , n: GET #fh, , nb: GET #fh, , nc
	IF tag <> "C3I1" OR n <> nv OR nb <> 13 OR nc < 1 OR nc > 8 THEN CLOSE #fh: EXIT SUB
	FOR k = 0 TO nv - 1: GET #fh, , ibw(k): NEXT
	g = 0
	FOR c = 0 TO nc - 1
		GET #fh, , nfr: GET #fh, , lp
		IF nfr < 1 OR g + nfr > 200 THEN CLOSE #fh: EXIT SUB
		icst(c) = g: icnt(c) = nfr: ilp(c) = lp: acc = 0
		FOR k = 0 TO nfr - 1
			GET #fh, , d
			icum(g + k) = acc: acc = acc + d
		NEXT
		ilen(c) = acc: g = g + nfr
	NEXT
	tot = g * 156
	REDIM idm(0 TO tot - 1) AS INTEGER
	p = 0
	DO WHILE p < tot
		m = tot - p: IF m > 1024 THEN m = 1024
		s = SPACE$(m * 2)
		GET #fh, , s
		FOR k = 0 TO m - 1: idm(p + k) = CVI(MID$(s, k * 2 + 1, 2)): NEXT
		p = p + m
	LOOP
	CLOSE #fh
	inc = nc
	FOR k = 0 TO MAXI - 1: iclp(k) = 0: itm(k) = 0: iwt(k) = 120: ilst(k) = 0: NEXT
	'----- the clips' kinds: the fidgets, the turning steps; the feet (bones 5, 8)
	nfid = 0: tcf(0) = -1: tcf(1) = -1: tcl = -1
	FOR c = 0 TO nc - 1
		IF ilp(c) = 0 THEN nfid = nfid + 1
		IF ilp(c) = 2 THEN tcf(0) = c
		IF ilp(c) = 3 THEN tcf(1) = c
	NEXT
	FOR c = 0 TO 1
		tfx(c) = 0: tfz(c) = 0: m = 0
		FOR k = 0 TO nv - 1
			IF (ibw(k) AND 255) = 5 + 3 * c THEN tfx(c) = tfx(c) + mx(k): tfz(c) = tfz(c) + mz(k): m = m + 1
		NEXT
		IF m > 0 THEN tfx(c) = tfx(c) / m: tfz(c) = tfz(c) / m ELSE tcf(c) = -1
	NEXT
END SUB

'----- IdleSkin: idle frame g's matrices applied to the rest pose -> kx/ky/kz
SUB IdleSkin (g AS INTEGER)
	prs(0) = VARSEG(mx(0)): prs(1) = VARPTR(mx(0))
	prs(2) = VARSEG(my(0)): prs(3) = VARPTR(my(0))
	prs(4) = VARSEG(mz(0)): prs(5) = VARPTR(mz(0))
	prs(6) = VARSEG(kx(0)): prs(7) = VARPTR(kx(0))
	prs(8) = VARSEG(ky(0)): prs(9) = VARPTR(ky(0))
	prs(10) = VARSEG(kz(0)): prs(11) = VARPTR(kz(0))
	prs(12) = nv
	prs(13) = VARSEG(ibw(0)): prs(14) = VARPTR(ibw(0))
	prs(15) = VARSEG(idm(g * 156)): prs(16) = VARPTR(idm(g * 156))
	DEF SEG = VARSEG(ovlSkin)
	CALL ABSOLUTE(BYVAL VARSEG(prs(0)), BYVAL VARPTR(prs(0)), SADD(ovlSkin))
	DEF SEG
END SUB

'----- IdlePose: model i standing, d (1/30 s) later: its clip moved on -- the
'----- breathing loop, or a fidget played once and back to breathing; after its
'----- wait a fidget starts (never the same twice running). hold (turning) stops
'----- a fidget and keeps the next one at least a second away. Returns the
'----- pose (1000 + the idle frame), -1 without idle clips
FUNCTION IdlePose% (i AS INTEGER, d AS SINGLE, hold AS INTEGER)
	DIM c AS INTEGER, g AS INTEGER
	IF inc = 0 THEN IdlePose% = -1: EXIT FUNCTION
	c = iclp(i)
	IF hold AND c > 0 THEN c = 0: itm(i) = 0
	itm(i) = itm(i) + d
	IF itm(i) >= ilen(c) THEN
		IF c = 0 THEN
			itm(i) = itm(i) - ilen(0) * INT(itm(i) / ilen(0))
		ELSE
			c = 0: itm(i) = 0
		END IF
	END IF
	IF c = 0 THEN
		iwt(i) = iwt(i) - d
		IF hold AND iwt(i) < 30 THEN iwt(i) = 30
		IF iwt(i) <= 0 AND nfid > 0 THEN
			'----- the fidgets are the kind-0 clips: the next in order (MANWALK I) or a
			'----- random one, not the last one again
			IF idlechk THEN
				c = ilst(i)
				DO
					c = c + 1: IF c >= inc THEN c = 1
				LOOP UNTIL ilp(c) = 0
				iwt(i) = 15
			ELSE
				DO
					g = 1 + INT(RND * nfid): c = 0
					DO
						c = c + 1
						IF ilp(c) = 0 THEN g = g - 1
					LOOP UNTIL g = 0
				LOOP WHILE c = ilst(i) AND nfid > 1
				iwt(i) = 180 + RND * 150
			END IF
			ilst(i) = c: itm(i) = 0
		END IF
	END IF
	iclp(i) = c
	g = icst(c) + icnt(c) - 1
	DO WHILE g > icst(c) AND icum(g) > itm(i): g = g - 1: LOOP
	IdlePose% = 1000 + g
END FUNCTION

'----- TurnPose: the turning step on the spot -- r the way he turns (1 to his
'----- left, -1 right, 0 not), dd the degrees this frame (when he has stopped,
'----- the pace the step finishes at). The step clip runs a cycle per TURNDEG
'----- degrees; turning the other way starts the other foot's step. Returns the
'----- pose (1000 + the frame), -1 when no step is playing
FUNCTION TurnPose% (r AS INTEGER, dd AS SINGLE)
	DIM c AS INTEGER, g AS INTEGER
	IF inc = 0 THEN TurnPose% = -1: EXIT FUNCTION
	c = -1
	IF r > 0 THEN c = tcf(0)
	IF r < 0 THEN c = tcf(1)
	IF r <> 0 AND c < 0 THEN tcl = -1
	IF c >= 0 AND c <> tcl THEN tcl = c: tph = 0
	IF tcl < 0 THEN TurnPose% = -1: EXIT FUNCTION
	tph = tph + dd * ilen(tcl) / TURNDEG
	IF tph >= ilen(tcl) THEN
		IF r = 0 THEN tcl = -1: TurnPose% = -1: EXIT FUNCTION
		tph = tph - ilen(tcl) * INT(tph / ilen(tcl))
	END IF
	g = icst(tcl) + icnt(tcl) - 1
	DO WHILE g > icst(tcl) AND icum(g) > tph: g = g - 1: LOOP
	TurnPose% = 1000 + g
END FUNCTION

'----- LoadAnim: MAN3D.ANI (tools\man3danim.ps1) -> afr(), anf, acyc; nothing
'----- (the rest pose only) when it is missing or made for another model
SUB LoadAnim
	DIM fh AS INTEGER, ln AS LONG, tag AS STRING, n AS INTEGER, nfr AS INTEGER, cyc AS INTEGER
	DIM p AS INTEGER, k AS INTEGER, m AS INTEGER, tot AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN "MAN3D.ANI" FOR BINARY AS #fh
	ln = LOF(fh)
	IF ln < 10 THEN
		CLOSE #fh
		IF ln = 0 THEN KILL "MAN3D.ANI"
		EXIT SUB
	END IF
	tag = SPACE$(4)
	GET #fh, 1, tag: GET #fh, , n: GET #fh, , nfr: GET #fh, , cyc
	IF (tag <> "C3A1" AND tag <> "C3A2") OR n <> nv OR nfr < 1 OR nfr > 24 OR cyc < 16 THEN CLOSE #fh: EXIT SUB
	IF tag = "C3A2" THEN
		IF ln < 10 + CLNG(nfr) * 2 + CLNG(nfr) * 6 * nv THEN CLOSE #fh: EXIT SUB
		FOR k = 0 TO nfr - 1: GET #fh, , acum(k): NEXT
	ELSE
		IF ln < 10 + CLNG(nfr) * 6 * nv THEN CLOSE #fh: EXIT SUB
		FOR k = 0 TO nfr - 1: acum(k) = (CLNG(cyc) * k) \ nfr: NEXT
	END IF
	tot = nfr * 3 * nv
	REDIM afr(0 TO tot - 1) AS INTEGER
	p = 0
	DO WHILE p < tot
		m = tot - p: IF m > 1024 THEN m = 1024
		s = SPACE$(m * 2)
		GET #fh, , s
		FOR k = 0 TO m - 1: afr(p + k) = CVI(MID$(s, k * 2 + 1, 2)): NEXT
		p = p + m
	LOOP
	CLOSE #fh
	anf = nfr: acyc = cyc
END SUB

'----- AnimFrame: the walk frame at a distance ph (x16 units) into the cycle
FUNCTION AnimFrame% (ph AS LONG)
	DIM q AS LONG, f AS INTEGER
	q = ph MOD acyc
	IF q < 0 THEN q = q + acyc
	f = anf - 1
	DO WHILE f > 0 AND acum(f) > q: f = f - 1: LOOP
	AnimFrame% = f
END FUNCTION

'----- SetPose: the rotate routine's input -- walk frame f, idle frame f - 1000
'----- (skinned into kx/ky/kz), or the rest pose
SUB SetPose (f AS INTEGER)
	DIM b AS INTEGER
	IF f >= 1000 THEN
		CALL IdleSkin(f - 1000)
		prr(0) = VARSEG(kx(0)): prr(1) = VARPTR(kx(0))
		prr(2) = VARSEG(ky(0)): prr(3) = VARPTR(ky(0))
		prr(4) = VARSEG(kz(0)): prr(5) = VARPTR(kz(0))
		EXIT SUB
	END IF
	IF f < 0 OR anf = 0 THEN
		prr(0) = VARSEG(mx(0)): prr(1) = VARPTR(mx(0))
		prr(2) = VARSEG(my(0)): prr(3) = VARPTR(my(0))
		prr(4) = VARSEG(mz(0)): prr(5) = VARPTR(mz(0))
	ELSE
		b = f * 3 * nv
		prr(0) = VARSEG(afr(b)): prr(1) = VARPTR(afr(b))
		prr(2) = VARSEG(afr(b + nv)): prr(3) = VARPTR(afr(b + nv))
		prr(4) = VARSEG(afr(b + 2 * nv)): prr(5) = VARPTR(afr(b + 2 * nv))
	END IF
END SUB

'----- RotTo: the rotate routine's output -- model i's rotated vertices and order
SUB RotTo (i AS INTEGER)
	IF i = 0 THEN
		prr(6) = VARSEG(rx(0)): prr(7) = VARPTR(rx(0))
		prr(8) = VARSEG(ry(0)): prr(9) = VARPTR(ry(0))
		prr(10) = VARSEG(rz(0)): prr(11) = VARPTR(rz(0))
		prr(17) = VARSEG(ord(0)): prr(18) = VARPTR(ord(0))
	ELSE
		prr(6) = VARSEG(rxs(0, i)): prr(7) = VARPTR(rxs(0, i))
		prr(8) = VARSEG(rys(0, i)): prr(9) = VARPTR(rys(0, i))
		prr(10) = VARSEG(rzs(0, i)): prr(11) = VARPTR(rzs(0, i))
		prr(17) = VARSEG(ords(0, i)): prr(18) = VARPTR(ords(0, i))
	END IF
END SUB

'----- PoseInst: model i in walk frame f (-1 = rest) at heading yaw, rotated and sorted
SUB PoseInst (i AS INTEGER, f AS INTEGER, yaw AS SINGLE)
	CALL SetPose(f)
	CALL RotTo(i)
	CALL PrepAsm(yaw)
END SUB

'----- PrepAsm: C3DROT -- the model rotated about Y by yaw into rx/ry/rz and
'----- the faces sorted far-to-near into ord (what Prep does in QB, in asm)
SUB PrepAsm (yaw AS SINGLE)
	prr(13) = CINT(COS(yaw) * 256): prr(14) = CINT(SIN(yaw) * 256)
	DEF SEG = VARSEG(ovlRot)
	CALL ABSOLUTE(BYVAL VARSEG(prr(0)), BYVAL VARPTR(prr(0)), SADD(ovlRot))
	DEF SEG
END SUB

