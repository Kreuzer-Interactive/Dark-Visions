' TESTBLT5.BAS -- v6 equivalence: for EVERY instance in SHADW2.PAC, blit its
' lit rect to screen via SHADBLT and GET-compare against the pool bytes.
' Catches stride/geometry bugs per instance. Writes RESULTS5.TXT.
REM $DYNAMIC
DEFINT A-Z
DECLARE SUB TLoad (sdt%())
REDIM SHARED pool(27000) AS INTEGER
DIM SHARED tN AS INTEGER
DIM SHARED tRm$(20), tDst$(20)
DIM SHARED tTX(20) AS INTEGER, tTY(20) AS INTEGER, tTW(20) AS INTEGER, tTH(20) AS INTEGER
DIM SHARED tOLt(20) AS INTEGER, tRB(20) AS INTEGER
DIM g(700) AS INTEGER
DIM sl AS LONG

OPEN "SHADBLT.OVL" FOR BINARY AS #1
blt$ = SPACE$(LOF(1)): GET #1, 1, blt$: CLOSE #1
OPEN "SHADW2.PAC" FOR INPUT AS #3
CALL TLoad(pool())

SCREEN 1: CLS
OPEN "RESULTS5.TXT" FOR OUTPUT AS #2
PRINT #2, "instances:"; tN
FOR t = 1 TO tN
	CLS
	sl = VARPTR(pool(tOLt(t)))
	IF sl < 0 THEN sl = sl + 65536
	DEF SEG = VARSEG(blt$)
	CALL ABSOLUTE(BYVAL VARSEG(pool(tOLt(t))), BYVAL CINT(sl), BYVAL tTX(t) \ 4, BYVAL tTY(t), BYVAL tTH(t), BYVAL tRB(t), BYVAL tRB(t), BYVAL 0, SADD(blt$))
	DEF SEG
	GET (tTX(t), tTY(t))-(tTX(t) + tTW(t) - 1, tTY(t) + tTH(t) - 1), g
	bad = 0: fb = -1
	n = tRB(t) * tTH(t)
	n2 = n \ 2
	FOR i = 0 TO n2 - 1
		IF g(i + 2) <> pool(tOLt(t) + i) THEN
			bad = bad + 1
			IF fb < 0 THEN fb = i
		END IF
	NEXT
	PRINT #2, t; tRm$(t); "rb"; tRB(t); "bad"; bad; "of"; n2; "first"; fb
NEXT
CLOSE #2
SYSTEM

SUB TLoad (sdt%())
	DIM sv AS INTEGER, sn2 AS INTEGER, si2 AS INTEGER, sof AS INTEGER, sar AS INTEGER, sdi AS INTEGER
	DIM d1 AS INTEGER, d2 AS INTEGER, d3 AS INTEGER, d4 AS INTEGER, d5 AS INTEGER, d6 AS INTEGER, d7 AS INTEGER
	INPUT #3, sv, tN
	sof = 0
	FOR sdi = 1 TO tN
		INPUT #3, tRm$(sdi), tTX(sdi), tTY(sdi), tTW(sdi), tTH(sdi), d1, d2, d3, d4, d5, d6, d7, tDst$(sdi)
		tRB(sdi) = tTW(sdi) \ 4
		FOR sar = 1 TO 6
			INPUT #3, sn2
			IF sar = 2 THEN tOLt(sdi) = sof
			FOR si2 = 1 TO sn2
				INPUT #3, sdt%(sof)
				sof = sof + 1
			NEXT
		NEXT
	NEXT
	CLOSE #3
END SUB
