'----- PITPROBE.BAS: what does QB 4.5's SOUND do to PIT channel 0, and how
'----- are .06-tick notes timed in foreground (MF) and background (MB) mode?
DEFINT A-Z
DECLARE FUNCTION Ticks& ()
DECLARE FUNCTION PitStat% ()
DECLARE FUNCTION PitMax& ()
DECLARE SUB Sweeps (n AS INTEGER)
DIM fh AS INTEGER, t0 AS LONG, t1 AS LONG, q AS INTEGER, qmax AS INTEGER
	fh = FREEFILE
	OPEN "PITPROBE.LOG" FOR OUTPUT AS #fh
	PRINT #fh, "start: status "; HEX$(PitStat%); " maxcount"; PitMax&
	t0 = Ticks&: CALL Sweeps(10): t1 = Ticks&
	PRINT #fh, "MF 10 sweeps (180 notes x .06 = 10.8 ticks expected):"; t1 - t0; " ticks"
	PRINT #fh, "after MF: status "; HEX$(PitStat%); " maxcount"; PitMax&
	'----- channel 0 to mode 2 (what CAR3D does), sounds again
	OUT &H43, &H34: OUT &H40, 0: OUT &H40, 0
	PRINT #fh, "mode2 set: status "; HEX$(PitStat%); " maxcount"; PitMax&
	t0 = Ticks&: CALL Sweeps(10): t1 = Ticks&
	PRINT #fh, "MF 10 sweeps in mode 2:"; t1 - t0; " ticks"
	PRINT #fh, "after MF in mode2: status "; HEX$(PitStat%); " maxcount"; PitMax&
	OUT &H43, &H36: OUT &H40, 0: OUT &H40, 0
	'----- background queue
	PLAY "MB"
	PRINT #fh, "MB set: status "; HEX$(PitStat%); " maxcount"; PitMax&; " PLAY(0)"; PLAY(0)
	t0 = Ticks&
	CALL Sweeps(10)
	t1 = Ticks&
	q = PLAY(0)
	PRINT #fh, "MB 10 sweeps queued in"; t1 - t0; " ticks, PLAY(0) now"; q
	PRINT #fh, "during MB: status "; HEX$(PitStat%); " maxcount"; PitMax&
	qmax = q
	DO
		q = PLAY(0): IF q > qmax THEN qmax = q
	LOOP WHILE q > 0
	t1 = Ticks&
	PRINT #fh, "MB drained at"; t1 - t0; " ticks (expect ~10.8+); qmax"; qmax
	PRINT #fh, "after MB: status "; HEX$(PitStat%); " maxcount"; PitMax&
	'----- one note at a time, in MB: how long does a .06 note last?
	t0 = Ticks&
	FOR q = 1 TO 90
		SOUND 100, .06
		SOUND 150, .06
	NEXT
	DO: LOOP WHILE PLAY(0) > 0
	t1 = Ticks&
	PRINT #fh, "MB 180 single notes drained at"; t1 - t0; " ticks (10.8 expected)"
	PLAY "MF"
	PRINT #fh, "end: status "; HEX$(PitStat%); " maxcount"; PitMax&
	CLOSE #fh
	PRINT "PITPROBE done"
	END

SUB Sweeps (n AS INTEGER)
	DIM i AS INTEGER, tc AS INTEGER
	FOR i = 1 TO n
		tc = 50
		DO
			SOUND tc, .06
			SOUND 100, .06
			tc = tc + 18
		LOOP WHILE tc <= 200
	NEXT
END SUB

FUNCTION Ticks&
	DEF SEG = &H40
	Ticks& = CLNG(PEEK(&H6C)) + 256& * PEEK(&H6D) + 65536 * PEEK(&H6E)
	DEF SEG
END FUNCTION

'----- read-back command: status byte of counter 0 (bit7 OUT, bits 3-1 mode)
FUNCTION PitStat%
	OUT &H43, &HE2
	PitStat% = INP(&H40)
END FUNCTION

'----- largest latched count seen in 3000 samples (~ the reload value)
FUNCTION PitMax&
	DIM i AS INTEGER, lo AS INTEGER, hi AS INTEGER, c AS LONG, m AS LONG
	m = 0
	FOR i = 1 TO 3000
		OUT &H43, 0
		lo = INP(&H40): hi = INP(&H40)
		c = hi * 256& + lo
		IF c > m THEN m = c
	NEXT
	PitMax& = m
END FUNCTION
