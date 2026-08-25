' TESTBLT4.BAS -- blit ALL FOUR v5 instances (incl. the odd start row of the
' north rect) and run one full compose (lit + sprite AND + keep AND + bg OR)
' for the north instance, verifying everything against BASIC-computed bytes.
REM $DYNAMIC
DEFINT A-Z
DECLARE SUB TLoad (sdt%())
REDIM SHARED pool(5800) AS INTEGER
DIM SHARED tN AS INTEGER
DIM SHARED tTX(4) AS INTEGER, tTY(4) AS INTEGER, tTW(4) AS INTEGER, tTH(4) AS INTEGER
DIM SHARED tOId(4) AS INTEGER, tOLt(4) AS INTEGER, tOKp(4) AS INTEGER, tOBg(4) AS INTEGER
DIM SHARED tOSU(4) AS INTEGER, tOSD(4) AS INTEGER
DIM SHARED tRB(4) AS INTEGER, tVI(4) AS INTEGER, tSBW(4) AS INTEGER, tSPH(4) AS INTEGER
DIM SHARED tDst$(4)
DIM buf(300) AS INTEGER, g(700) AS INTEGER, exp1(700) AS INTEGER
DIM d2 AS LONG

OPEN "SHADBOP.OVL" FOR BINARY AS #1
bop$ = SPACE$(LOF(1)): GET #1, 1, bop$: CLOSE #1
OPEN "SHADBLT.OVL" FOR BINARY AS #1
blt$ = SPACE$(LOF(1)): GET #1, 1, blt$: CLOSE #1
OPEN "SHADW2.PAC" FOR INPUT AS #3
CALL TLoad(pool())

SCREEN 1: CLS
OPEN "RESULTS4.TXT" FOR OUTPUT AS #1

' ---- part 1: direct lit blits of all four instances, compare payloads
DEF SEG = VARSEG(blt$)
FOR k = 1 TO tN
	CALL ABSOLUTE(BYVAL VARSEG(pool(tOLt(k))), BYVAL VARPTR(pool(tOLt(k))), BYVAL tTX(k) \ 4, BYVAL tTY(k), BYVAL tTH(k), BYVAL tRB(k), BYVAL tRB(k), BYVAL 0, SADD(blt$))
NEXT
DEF SEG
FOR k = 1 TO tN
	GET (tTX(k), tTY(k))-(tTX(k) + tTW(k) - 1, tTY(k) + tTH(k) - 1), g
	bad = 0: n = tRB(k) * tTH(k) \ 2
	FOR i = 0 TO n - 1
		IF g(i + 2) <> pool(tOLt(k) + i) THEN bad = bad + 1
	NEXT
	PRINT #1, "inst"; k; "rect("; tTX(k); tTY(k); ") mismatches:"; bad; "of"; n
NEXT

' ---- part 2: full compose for the NORTH instance (k=3), sprite mid-pool
k = 3
rb = tRB(k): rw = tTH(k)
bs = VARSEG(buf(0)): bo = VARPTR(buf(0))
sx = tTX(k) + 21: sy = tTY(k) + 5
DEF SEG = VARSEG(bop$)
CALL ABSOLUTE(BYVAL VARSEG(pool(tOLt(k))), BYVAL VARPTR(pool(tOLt(k))), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 0, SADD(bop$))
so2 = tOSU(k) + (sx AND 3) * tVI(k)
d2 = bo
IF d2 < 0 THEN d2 = d2 + 65536
d2 = d2 + (sy - tTY(k)) * rb + (sx \ 4 - tTX(k) \ 4)
IF d2 > 32767 THEN d2 = d2 - 65536
CALL ABSOLUTE(BYVAL VARSEG(pool(so2)), BYVAL VARPTR(pool(so2)), BYVAL bs, BYVAL CINT(d2), BYVAL tSPH(k), BYVAL tSBW(k), BYVAL tSBW(k), BYVAL rb, BYVAL 1, SADD(bop$))
CALL ABSOLUTE(BYVAL VARSEG(pool(tOKp(k))), BYVAL VARPTR(pool(tOKp(k))), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 1, SADD(bop$))
CALL ABSOLUTE(BYVAL VARSEG(pool(tOBg(k))), BYVAL VARPTR(pool(tOBg(k))), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 2, SADD(bop$))
DEF SEG = VARSEG(blt$)
CALL ABSOLUTE(BYVAL bs, BYVAL bo, BYVAL tTX(k) \ 4, BYVAL tTY(k), BYVAL rw, BYVAL rb, BYVAL rb, BYVAL 0, SADD(blt$))
DEF SEG

' BASIC-computed expectation of the same compose (int-wise ops on the pool)
n = rb * rw \ 2
FOR i = 0 TO n - 1
	exp1(i) = pool(tOLt(k) + i)
NEXT
' sprite AND at byte granularity via masks over ints
sbw = tSBW(k)
FOR r = 0 TO tSPH(k) - 1
	FOR c = 0 TO sbw - 1
		bofs = (sy - tTY(k) + r) * rb + (sx \ 4 - tTX(k) \ 4) + c
		sofs = r * sbw + c
		sv = pool(so2 + sofs \ 2)
		IF sofs AND 1 THEN sb = (sv \ 256) AND 255 ELSE sb = sv AND 255
		dv = exp1(bofs \ 2)
		IF bofs AND 1 THEN
			db = (dv \ 256) AND 255
			db = db AND sb
			exp1(bofs \ 2) = (dv AND 255) OR (db * 256)
		ELSE
			db = dv AND 255
			db = db AND sb
			exp1(bofs \ 2) = ((dv \ 256) AND 255) * 256 OR db
		END IF
	NEXT
NEXT
FOR i = 0 TO n - 1
	kv = pool(tOKp(k) + i): bv = pool(tOBg(k) + i)
	lo = (exp1(i) AND 255) AND (kv AND 255) OR (bv AND 255)
	hi = ((exp1(i) \ 256) AND 255) AND ((kv \ 256) AND 255) OR ((bv \ 256) AND 255)
	exp1(i) = hi * 256 OR lo
NEXT
GET (tTX(k), tTY(k))-(tTX(k) + tTW(k) - 1, tTY(k) + tTH(k) - 1), g
bad = 0: fb = -1
FOR i = 0 TO n - 1
	gv = g(i + 2)
	IF gv < 0 THEN gv = gv + 65536
	ev = exp1(i)
	IF ev < 0 THEN ev = ev + 65536
	IF gv <> ev THEN
		bad = bad + 1
		IF fb < 0 THEN fb = i
	END IF
NEXT
PRINT #1, "north compose mismatches:"; bad; "of"; n; " first:"; fb
CLOSE #1
SYSTEM

SUB TLoad (sdt%())
	DIM sv AS INTEGER, sn2 AS INTEGER, si2 AS INTEGER, sof AS INTEGER, sar AS INTEGER, sdi AS INTEGER
	DIM d1 AS INTEGER, d2 AS INTEGER, d3 AS INTEGER, d4 AS INTEGER, d5 AS INTEGER
	INPUT #3, sv, tN
	sof = 0
	FOR sdi = 1 TO tN
		INPUT #3, tTX(sdi), tTY(sdi), tTW(sdi), tTH(sdi), d1, d2, d3, d4, d5, tSBW(sdi), tSPH(sdi), tDst$(sdi)
		tRB(sdi) = tTW(sdi) \ 4
		tVI(sdi) = (tSBW(sdi) * tSPH(sdi) + 1) \ 2
		FOR sar = 1 TO 6
			INPUT #3, sn2
			IF sar = 1 THEN tOId(sdi) = sof
			IF sar = 2 THEN tOLt(sdi) = sof
			IF sar = 3 THEN tOKp(sdi) = sof
			IF sar = 4 THEN tOBg(sdi) = sof
			IF sar = 5 THEN tOSU(sdi) = sof
			IF sar = 6 THEN tOSD(sdi) = sof
			FOR si2 = 1 TO sn2
				INPUT #3, sdt%(sof)
				sof = sof + 1
			NEXT
		NEXT
	NEXT
	CLOSE #3
END SUB
