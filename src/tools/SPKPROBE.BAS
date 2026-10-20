'----- SPKPROBE.BAS: what QB 4.5's foreground SOUND does to the speaker (port 61h bits 0/1 and PIT
'----- channel 2's mode and count) during a "silent" note, between back-to-back notes and after the
'----- last one, for SOUND 32676 (GAME5's pacing note) and SOUND 32767. Output: SPKPROBE.LOG
DEFINT A-Z
DECLARE SUB Probe (fh AS INTEGER, f AS LONG, lab AS STRING)
DECLARE FUNCTION Ch2$ ()
DIM fh AS INTEGER
	fh = FREEFILE
	OPEN "SPKPROBE.LOG" FOR OUTPUT AS #fh
	PRINT #fh, "start: 61h="; INP(&H61) AND 3; Ch2$
	CALL Probe(fh, 32676, "32676")
	CALL Probe(fh, 32767, "32767")
	CLOSE #fh
	END

'----- channel 2's status (read-back) and its count
FUNCTION Ch2$
	DIM st AS INTEGER, lo AS INTEGER, hi AS INTEGER
	OUT &H43, &HE8
	st = INP(&H42)
	OUT &H43, &H80
	lo = INP(&H42): hi = INP(&H42)
	Ch2$ = " ch2 mode" + STR$((st \ 2) AND 7) + " rw" + STR$((st \ 16) AND 3) + " count" + STR$(CLNG(lo) + 256& * hi)
END FUNCTION

SUB Probe (fh AS INTEGER, f AS LONG, lab AS STRING)
	DIM i AS INTEGER, k AS INTEGER, v AS INTEGER, n0 AS LONG, n3 AS LONG, tot AS LONG
	SOUND f, 2
	PRINT #fh, lab; " during a 2-tick note: 61h="; INP(&H61) AND 3; Ch2$
	'----- ten back-to-back notes of .5 tick: 61h sampled in a busy loop while they play
	n0 = 0: n3 = 0: tot = 0
	FOR k = 1 TO 10
		SOUND f, .5
		FOR i = 1 TO 300
			v = INP(&H61) AND 3
			IF v = 3 THEN n3 = n3 + 1 ELSE n0 = n0 + 1
			tot = tot + 1
		NEXT
	NEXT
	PRINT #fh, lab; " back to back: 61h=3 in"; n3; "of"; tot; "samples, other"; n0
	'----- after the last note has ended
	SOUND f, 1 / 32
	FOR i = 1 TO 3000: v = INP(&H61): NEXT
	PRINT #fh, lab; " after the last note: 61h="; INP(&H61) AND 3; Ch2$
END SUB
