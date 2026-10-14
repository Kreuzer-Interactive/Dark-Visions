'----- C3DTEST.BAS: checks the hand-assembled 386 routines of
'----- tools\build_car3d_asm.ps1 without a screen: C3DTEST.OVL (instruction
'----- encodings against known arithmetic), C3DTRI.OVL (a textured triangle,
'----- a second one sharing its edge, a back-facing one that must be culled,
'----- rendered into a 32x16 buffer and dumped as hex) and C3DPRJ.OVL (the
'----- projection against the same formula in QB). Output: C3DTEST.LOG.
DEFINT A-Z
TYPE Fac
	a AS INTEGER
	b AS INTEGER
	c AS INTEGER
	d AS INTEGER
	ci AS INTEGER
END TYPE
DECLARE SUB LoadOvl (fil AS STRING, s AS STRING)
DECLARE SUB LoSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
'$DYNAMIC
DIM SHARED prm(0 TO 63) AS INTEGER
DIM SHARED wk(0 TO 255) AS INTEGER
DIM SHARED tx(0 TO 2063) AS INTEGER
DIM SHARED sx(0 TO 7) AS INTEGER, sy(0 TO 7) AS INTEGER, tu(0 TO 7) AS INTEGER, tv(0 TO 7) AS INTEGER
DIM SHARED fa(0 TO 3) AS Fac, bd(0 TO 3) AS INTEGER, ord(0 TO 3) AS INTEGER, bt(0 TO 7) AS INTEGER
DIM SHARED rx(0 TO 7) AS INTEGER, ry(0 TO 7) AS INTEGER, rz(0 TO 7) AS INTEGER
'$STATIC
DIM tst AS STRING, tri AS STRING, prj AS STRING
DIM fh AS INTEGER, i AS INTEGER, x AS INTEGER, y AS INTEGER, s AS STRING, v AS INTEGER
DIM tseg AS INTEGER, tp AS INTEGER, pad AS INTEGER, wseg AS INTEGER, woff AS INTEGER
DIM t1 AS LONG, t2 AS LONG, t4 AS LONG
DIM px AS LONG, py AS LONG, pz AS LONG, zz AS LONG, ex AS INTEGER, ey AS INTEGER, bad AS INTEGER

	fh = FREEFILE
	OPEN "C3DTEST.LOG" FOR OUTPUT AS #fh
	CALL LoadOvl("C3DTEST.OVL", tst)
	CALL LoadOvl("C3DTRI.OVL", tri)
	CALL LoadOvl("C3DPRJ.OVL", prj)
	PRINT #fh, "ovl sizes:"; LEN(tst); LEN(tri); LEN(prj)

	'----- 1. encodings: a=300 b=-7 c=25 d=13
	prm(0) = 300: prm(1) = -7: prm(2) = 25: prm(3) = 13
	DEF SEG = VARSEG(tst)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(tst))
	DEF SEG
	t1 = CLNG(prm(5)) * 65536 + (prm(4) AND &HFFFF&)
	t2 = CLNG(prm(7)) * 65536 + (prm(6) AND &HFFFF&)
	t4 = CLNG(prm(11)) * 65536 + (prm(10) AND &HFFFF&)
	PRINT #fh, "enc: a*b"; t1; "(-2100)  a*b-c*d"; t2; "(-2425)  /d"; prm(8); "(-186)  (a<<16)/b"; t4; "(-2808685)"
	PRINT #fh, "enc: a*c"; prm(12); "(7500)  (a&63)<<6"; prm(13); "(2816)  loop"; prm(14); "(25)  lo16(t1+t2)"; prm(15); "(-4525)"

	'----- 2. rasteriser: 64x64 texture (1..64 pattern, a 255-keyed block top right)
	tp = VARPTR(tx(0)): pad = (16 - (tp AND 15)) AND 15
	tseg = VARSEG(tx(0)) + (tp + pad) \ 16
	DEF SEG = tseg
	FOR y = 0 TO 63
		FOR x = 0 TO 63
			v = 1 + (x AND 7) + (y AND 7) * 8
			IF x >= 32 AND y < 8 THEN v = 255
			POKE y * 64 + x, v
		NEXT
	NEXT
	DEF SEG
	wseg = VARSEG(wk(0)): woff = VARPTR(wk(0))
	FOR i = 0 TO 255: wk(i) = 0: NEXT
	'----- screen coordinates are 1/16 pixel
	sx(0) = 2 * 16: sy(0) = 2 * 16: tu(0) = 0: tv(0) = 0
	sx(1) = 28 * 16: sy(1) = 3 * 16: tu(1) = 63 * 256: tv(1) = 0
	sx(2) = 12 * 16: sy(2) = 14 * 16: tu(2) = 0: tv(2) = 63 * 256
	sx(3) = 30 * 16: sy(3) = 14 * 16: tu(3) = 63 * 256: tv(3) = 63 * 256
	fa(0).a = 0: fa(0).b = 1: fa(0).c = 2: fa(0).d = -1: fa(0).ci = 0
	fa(1).a = 1: fa(1).b = 3: fa(1).c = 2: fa(1).d = -1: fa(1).ci = 0
	fa(2).a = 2: fa(2).b = 1: fa(2).c = 0: fa(2).d = -1: fa(2).ci = 0
	bd(0) = 0: bd(1) = 0: bd(2) = 0
	ord(0) = 0: ord(1) = 1: ord(2) = 2
	bt(0) = tseg
	prm(0) = wseg: prm(1) = woff: prm(2) = 32: prm(3) = 16: prm(4) = VARSEG(bt(0)): prm(23) = VARPTR(bt(0))
	prm(5) = VARSEG(sx(0)): prm(6) = VARPTR(sx(0))
	prm(7) = VARSEG(sy(0)): prm(8) = VARPTR(sy(0))
	prm(9) = VARSEG(tu(0)): prm(10) = VARPTR(tu(0))
	prm(11) = VARSEG(tv(0)): prm(12) = VARPTR(tv(0))
	prm(13) = VARSEG(fa(0)): prm(14) = VARPTR(fa(0))
	prm(15) = VARSEG(bd(0)): prm(16) = VARPTR(bd(0))
	prm(17) = VARSEG(ord(0)): prm(18) = VARPTR(ord(0))
	prm(19) = VAL(COMMAND$): IF prm(19) = 0 THEN prm(19) = 1
	prm(20) = 0: prm(21) = 0: prm(22) = -1
	DEF SEG = VARSEG(tri)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(tri))
	DEF SEG
	PRINT #fh, "tri: count"; prm(19); " faces drawn"; prm(22)
	PRINT #fh, "slots x,y,u,v:"; prm(24); prm(25); prm(26); prm(27); "|"; prm(28); prm(29); prm(30); prm(31); "|"; prm(32); prm(33); prm(34); prm(35)
	PRINT #fh, "dx1 dy1 dx2 dy2:"; prm(36); prm(37); prm(38); prm(39); " du1 du2 dv1 dv2:"; prm(40); prm(41); prm(42); prm(43)
	PRINT #fh, "det:"; CLNG(prm(45)) * 65536 + (prm(44) AND &HFFFF&); " dudx dvdx dudy dvdy:"; prm(46); prm(47); prm(48); prm(49)
	PRINT #fh, "xaccL:"; CLNG(prm(51)) * 65536 + (prm(50) AND &HFFFF&); " xstepL:"; CLNG(prm(53)) * 65536 + (prm(52) AND &HFFFF&)
	PRINT #fh, "xaccS:"; CLNG(prm(55)) * 65536 + (prm(54) AND &HFFFF&); " xstepS:"; CLNG(prm(57)) * 65536 + (prm(56) AND &HFFFF&)
	PRINT #fh, "cy yend lleft ordi foff tseg:"; prm(58); prm(59); prm(60); prm(61); prm(62); prm(63)
	DEF SEG = wseg
	FOR y = 0 TO 15
		s = ""
		FOR x = 0 TO 31
			s = s + RIGHT$("0" + HEX$(PEEK(woff + y * 32 + x)), 2) + " "
		NEXT
		PRINT #fh, s
	NEXT
	DEF SEG

	'----- 3. projection
	FOR i = 0 TO 7
		rx(i) = i * 300 - 1000: ry(i) = 500 - i * 150: rz(i) = i * 200 - 300
	NEXT
	rz(7) = -7500
	px = -1600: py = -960: pz = 7200
	prm(0) = VARSEG(rx(0)): prm(1) = VARPTR(rx(0))
	prm(2) = VARSEG(ry(0)): prm(3) = VARPTR(ry(0))
	prm(4) = VARSEG(rz(0)): prm(5) = VARPTR(rz(0))
	prm(6) = VARSEG(sx(0)): prm(7) = VARPTR(sx(0))
	prm(8) = VARSEG(sy(0)): prm(9) = VARPTR(sy(0))
	prm(10) = 8
	CALL LoSplit(px, prm(11), prm(12))
	CALL LoSplit(py, prm(13), prm(14))
	CALL LoSplit(pz, prm(15), prm(16))
	prm(17) = -1: prm(18) = -1: prm(19) = -1: prm(20) = -1
	DEF SEG = VARSEG(prj)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(prj))
	DEF SEG
	bad = 0
	FOR i = 0 TO 7
		zz = rz(i) + pz: IF zz < 16 THEN zz = 16
		ex = 2560 + ((rx(i) + px) * 4096) \ zz
		ey = 1600 - ((ry(i) + py) * 4096) \ zz
		PRINT #fh, "prj v"; i; " asm"; sx(i); sy(i); " qb"; ex; ey
		IF ex <> sx(i) OR ey <> sy(i) THEN bad = bad + 1
	NEXT
	PRINT #fh, "prj: mismatches"; bad; " bbox"; prm(17); prm(18); prm(19); prm(20)
	CLOSE #fh
	PRINT "C3DTEST done"
	END

SUB LoadOvl (fil AS STRING, s AS STRING)
	DIM n AS INTEGER
	n = FREEFILE
	OPEN fil FOR BINARY AS #n
	s = SPACE$(LOF(n))
	IF LOF(n) > 0 THEN GET #n, 1, s
	CLOSE #n
END SUB

'----- LONG -> two words (lo as the signed INTEGER holding the low 16 bits)
SUB LoSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
	DIM l AS LONG
	l = v AND &HFFFF&
	hi = (v - l) \ 65536
	IF l > 32767 THEN l = l - 65536
	lo = l
END SUB
