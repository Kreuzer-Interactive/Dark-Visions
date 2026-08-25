' TESTBLT.BAS -- standalone proof for SHADBOP/SHADBLT (CALL ABSOLUTE blitters)
' Composites the same frame via QB PUTs and via the asm path, compares the
' results pixel-for-pixel, exercises odd-width rows, and benchmarks both.
' Writes RESULTS.TXT and exits (run headless from the build DOSBox).
DEFINT A-Z
DIM src1(60), src2(60), src3(60), buf(60), ref(60), got(60)
DIM odds(30), oddb(30), oddr(30), oddg(30)
DIM t1!, t2!, i!, n!

OPEN "SHADBOP.OVL" FOR BINARY AS #1
bop$ = SPACE$(LOF(1)): GET #1, 1, bop$: CLOSE #1
OPEN "SHADBLT.OVL" FOR BINARY AS #1
blt$ = SPACE$(LOF(1)): GET #1, 1, blt$: CLOSE #1

SCREEN 1: CLS
' three 24x16 GET blocks: pattern / AND mask with a hole / sparse OR dots
FOR y = 0 TO 15: FOR x = 0 TO 23: PSET (x, y), (x + y) MOD 4: NEXT: NEXT
GET (0, 0)-(23, 15), src1
LINE (0, 0)-(23, 15), 3, BF
LINE (6, 4)-(17, 11), 0, BF
GET (0, 0)-(23, 15), src2
LINE (0, 0)-(23, 15), 0, BF
FOR i = 0 TO 40: PSET ((i * 7) MOD 24, (i * 5) MOD 16), 2: NEXT
GET (0, 0)-(23, 15), src3
CLS

' ---- reference: QB PUT composite at (48,50)
PUT (48, 50), src1, PSET
PUT (48, 50), src2, AND
PUT (48, 50), src3, OR
GET (48, 50)-(71, 65), ref

' ---- asm path: compose in buf() then blit to (48,100). 24px = 6 bytes/row.
rb = 6: rw = 16
bs = VARSEG(buf(2)): bo = VARPTR(buf(2))
buf(0) = 48: buf(1) = 16
DEF SEG = VARSEG(bop$)
CALL ABSOLUTE(BYVAL VARSEG(src1(2)), BYVAL VARPTR(src1(2)), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 0, SADD(bop$))
CALL ABSOLUTE(BYVAL VARSEG(src2(2)), BYVAL VARPTR(src2(2)), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 1, SADD(bop$))
CALL ABSOLUTE(BYVAL VARSEG(src3(2)), BYVAL VARPTR(src3(2)), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 2, SADD(bop$))
DEF SEG = VARSEG(blt$)
CALL ABSOLUTE(BYVAL bs, BYVAL bo, BYVAL 12, BYVAL 100, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL 0, SADD(blt$))
GET (48, 100)-(71, 115), got

bad = 0
FOR i = 2 TO 49
	IF ref(i) <> got(i) THEN bad = bad + 1
NEXT

' ---- odd row-bytes path: 20px = 5 bytes/row, copy mode + blit
FOR y = 0 TO 7: FOR x = 0 TO 19: PSET (x, y), (x * y + x) MOD 4: NEXT: NEXT
GET (0, 0)-(19, 7), odds
CLS
PUT (100, 50), odds, PSET
GET (100, 50)-(119, 57), oddr
DEF SEG = VARSEG(bop$)
CALL ABSOLUTE(BYVAL VARSEG(odds(2)), BYVAL VARPTR(odds(2)), BYVAL VARSEG(oddb(2)), BYVAL VARPTR(oddb(2)), BYVAL 8, BYVAL 5, BYVAL 5, BYVAL 5, BYVAL 0, SADD(bop$))
DEF SEG = VARSEG(blt$)
CALL ABSOLUTE(BYVAL VARSEG(oddb(2)), BYVAL VARPTR(oddb(2)), BYVAL 25, BYVAL 100, BYVAL 8, BYVAL 5, BYVAL 5, BYVAL 1, SADD(blt$))
GET (100, 100)-(119, 107), oddg
obad = 0
FOR i = 2 TO 21
	IF oddr(i) <> oddg(i) THEN obad = obad + 1
NEXT

' ---- benchmark: 300 iterations of a 4-op composite, QB vs asm
n! = 3000
t1! = TIMER
FOR i! = 1 TO n!
	PUT (48, 50), src1, PSET
	PUT (48, 50), src2, AND
	PUT (48, 50), src3, OR
	PUT (48, 50), src2, AND
NEXT
t1! = TIMER - t1!
t2! = TIMER
DEF SEG = VARSEG(bop$)
FOR i! = 1 TO n!
	CALL ABSOLUTE(BYVAL VARSEG(src1(2)), BYVAL VARPTR(src1(2)), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 0, SADD(bop$))
	CALL ABSOLUTE(BYVAL VARSEG(src2(2)), BYVAL VARPTR(src2(2)), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 1, SADD(bop$))
	CALL ABSOLUTE(BYVAL VARSEG(src3(2)), BYVAL VARPTR(src3(2)), BYVAL bs, BYVAL bo, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL rb, BYVAL 2, SADD(bop$))
	DEF SEG = VARSEG(blt$)
	CALL ABSOLUTE(BYVAL bs, BYVAL bo, BYVAL 12, BYVAL 100, BYVAL rw, BYVAL rb, BYVAL rb, BYVAL 0, SADD(blt$))
	DEF SEG = VARSEG(bop$)
NEXT
t2! = TIMER - t2!

OPEN "RESULTS.TXT" FOR OUTPUT AS #1
PRINT #1, "composite mismatch ints:"; bad; "of 48"
PRINT #1, "odd-width mismatch ints:"; obad; "of 20"
PRINT #1, "qb put x300:"; t1!; "s"
PRINT #1, "asm     x300:"; t2!; "s"
IF t2! > 0 THEN PRINT #1, "speedup: x"; t1! / t2!
CLOSE #1
SYSTEM
