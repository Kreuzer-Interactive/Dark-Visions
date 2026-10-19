'----- SNDPROBE.BAS: how long do QB 4.5 foreground SOUND notes really take (the
'----- game's walk is paced by them), and does work between them add to it?
DEFINT A-Z
DECLARE FUNCTION Ticks& ()
DECLARE SUB Busy (n AS INTEGER)
DIM fh AS INTEGER, t0 AS LONG, i AS INTEGER, j AS INTEGER
	fh = FREEFILE
	OPEN "SNDPROBE.LOG" FOR OUTPUT AS #fh
	PLAY "MF"
	t0 = Ticks&: CALL Busy(200): PRINT #fh, "busy 200:"; Ticks& - t0; " ticks"
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 32676, .49: NEXT: PRINT #fh, "50 x .49 (24.5):"; Ticks& - t0
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 32676, 1.12: NEXT: PRINT #fh, "50 x 1.12 (56):"; Ticks& - t0
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 32676, .1: NEXT: PRINT #fh, "50 x .1 (5):"; Ticks& - t0
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 3000, .1: FOR j = 1 TO 2: SOUND 32676, 1.12: NEXT: NEXT: PRINT #fh, "50 2D steps (117):"; Ticks& - t0
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 3000, .1: FOR j = 1 TO 2: SOUND 32676, 1.12: NEXT: CALL Busy(10): NEXT: PRINT #fh, "50 2D steps + busy 10:"; Ticks& - t0
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 3000, .1: FOR j = 1 TO 4: SOUND 32676, .49: NEXT: NEXT: PRINT #fh, "50 x (.1 + 4 x .49) (103):"; Ticks& - t0
	t0 = Ticks&: FOR i = 1 TO 50: SOUND 3000, .1: FOR j = 1 TO 4: CALL Busy(2): SOUND 32676, .49: NEXT: NEXT: PRINT #fh, "same + busy 2 per frame:"; Ticks& - t0
	CLOSE #fh
	END

FUNCTION Ticks&
	DEF SEG = &H40
	Ticks& = CLNG(PEEK(&H6C)) + 256& * PEEK(&H6D) + 65536 * PEEK(&H6E)
	DEF SEG
END FUNCTION

SUB Busy (n AS INTEGER)
	DIM i AS INTEGER, k AS INTEGER, x AS INTEGER
	FOR i = 1 TO n: FOR k = 1 TO 2000: x = x XOR k: NEXT: NEXT
END SUB