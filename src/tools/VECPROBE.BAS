'----- VECPROBE.BAS: what QB 4.5's foreground SOUND does to the INT 8 vector and PIT channel 0
'----- over time: does its music engine stay hooked once its notes are over, and does it put
'----- its vector back in front of a handler hooked after it? Output: VECPROBE.LOG
DEFINT A-Z
DECLARE FUNCTION Vec$ ()
DECLARE FUNCTION PitMax& (n AS INTEGER)
DECLARE SUB Idle (s AS SINGLE)
DIM fh AS INTEGER, k AS INTEGER, t0 AS SINGLE, v0 AS STRING
	fh = FREEFILE
	OPEN "VECPROBE.LOG" FOR OUTPUT AS #fh
	v0 = Vec$
	PRINT #fh, "start:"; v0; " pit"; PitMax&(400)
	SOUND 32676, 1 / 32
	PRINT #fh, "a 1/32 note queued:"; Vec$; " pit"; PitMax&(400)
	CALL Idle(.3)
	PRINT #fh, ".3 s later:"; Vec$; " pit"; PitMax&(400)
	SOUND 32676, 2
	PRINT #fh, "a 2-tick note queued:"; Vec$; " pit"; PitMax&(400)
	CALL Idle(.3)
	PRINT #fh, ".3 s later:"; Vec$; " pit"; PitMax&(400)
	'----- a vector of our own in front (pointing at the BIOS's own handler, so nothing breaks):
	'----- does QB's engine put its own back when a note starts or ends?
	DEF SEG = 0
	POKE &H20, PEEK(&H20): POKE &H21, PEEK(&H21): POKE &H22, PEEK(&H22): POKE &H23, PEEK(&H23)
	DEF SEG
	FOR k = 1 TO 3
		SOUND 32676, 1 / 32
		PRINT #fh, "note"; k; "queued:"; Vec$; " pit"; PitMax&(200)
		CALL Idle(.2)
		PRINT #fh, "  .2 s later:"; Vec$; " pit"; PitMax&(400)
	NEXT
	t0 = TIMER: CALL Idle(1)
	PRINT #fh, "TIMER over an idle second:"; TIMER - t0
	CLOSE #fh
	END

SUB Idle (s AS SINGLE)
	DIM t AS SINGLE
	t = TIMER
	DO: LOOP WHILE TIMER - t < s AND TIMER >= t
END SUB

FUNCTION Vec$
	DIM o AS LONG, g AS LONG
	DEF SEG = 0
	o = PEEK(&H20) + 256& * PEEK(&H21): g = PEEK(&H22) + 256& * PEEK(&H23)
	DEF SEG
	Vec$ = " " + HEX$(g) + ":" + HEX$(o)
END FUNCTION

'----- the largest latched count of channel 0 in n samples (~ its reload value)
FUNCTION PitMax& (n AS INTEGER)
	DIM i AS INTEGER, lo AS INTEGER, hi AS INTEGER, c AS LONG, m AS LONG
	FOR i = 1 TO n
		OUT &H43, 0
		lo = INP(&H40): hi = INP(&H40)
		c = hi * 256& + lo
		IF c > m THEN m = c
	NEXT
	PitMax& = m
END FUNCTION
