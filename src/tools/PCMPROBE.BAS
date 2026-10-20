'----- PCMPROBE.BAS: what QB 4.5's foreground SOUND leaves PIT channel 0 doing once its last note
'----- has ended (does the music engine's 582.6 Hz rate stay?), timed by the BIOS tick count.
'----- For GAME8's recorded footsteps, which turn interrupts off for ~45 ms. Output: PCMPROBE.LOG
DEFINT A-Z
DECLARE FUNCTION PitMax& (n AS INTEGER)
DECLARE FUNCTION Ticks& ()
DIM fh AS INTEGER, i AS INTEGER, t0 AS LONG, t1 AS LONG, k AS INTEGER
	fh = FREEFILE
	OPEN "PCMPROBE.LOG" FOR OUTPUT AS #fh
	PRINT #fh, "start: max count"; PitMax&(400)
	'----- a long silent note, then the 1/32-tick one GAME8 starts before a footstep
	SOUND 32676, 2
	PRINT #fh, "during a 2-tick note: max count"; PitMax&(400)
	SOUND 32676, 1 / 32
	PRINT #fh, "just after the 1/32 note started:"; PitMax&(200)
	FOR k = 1 TO 8
		PRINT #fh, "then"; k; ":"; PitMax&(400)
	NEXT
	'----- the BIOS clock over 50 silent notes of 1.12 ticks: 56 ticks expected
	t0 = Ticks&
	FOR i = 1 TO 50: SOUND 32676, 1.12: NEXT
	SOUND 32676, 1 / 32
	t1 = Ticks&
	PRINT #fh, "50 notes of 1.12 ticks:"; t1 - t0; "ticks (56 expected)"
	PRINT #fh, "after them: max count"; PitMax&(400)
	CLOSE #fh
	END

FUNCTION Ticks&
	DEF SEG = &H40
	Ticks& = CLNG(PEEK(&H6C)) + 256& * PEEK(&H6D) + 65536 * PEEK(&H6E)
	DEF SEG
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
