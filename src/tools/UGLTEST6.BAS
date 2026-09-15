'----- UGLTEST6.BAS: can uGL 0.23b re-open 640x480x256 (2 pages) a second time?
'----- Cycle 1: uglInit / SetVideoDC / uglRestore / uglEnd (what VgaOpen/VgaClose do).
'----- Cycle 2: the same again - does SetVideoDC still succeed?  If not, which
'----- fallbacks work (640x480x1, 320x200), and does a mode set WITHOUT uglEnd
'----- in between (restore only) work?  Writes UGLTEST6.LOG, auto-exits.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

DECLARE SUB Lg (s AS STRING)
DECLARE SUB Hold (secs AS SINGLE)
DECLARE SUB Done ()
DECLARE FUNCTION TryMode& (tag AS STRING, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)

DIM SHARED lf AS INTEGER
DIM v AS LONG, r AS INTEGER

lf = FREEFILE
OPEN "ugltest6.log" FOR OUTPUT AS #lf

'----- cycle 1
IF NOT uglInit THEN CALL Lg("c1 uglInit FAILED"): CALL Done
v = TryMode&("c1", 640, 480, 2)
IF v <> 0 THEN r = uglPutBMPEx(v, 0, 0, "tplogo.bmp", BMPOPT.NO332): CALL Hold(1)
uglRestore
uglEnd
CALL Lg("c1 restored + ended")

'----- cycle 2: same sequence
IF NOT uglInit THEN CALL Lg("c2 uglInit FAILED"): CALL Done
v = TryMode&("c2", 640, 480, 2)
IF v = 0 THEN v = TryMode&("c2 fallback", 640, 480, 1)
IF v = 0 THEN v = TryMode&("c2 fallback", 320, 200, 1)
IF v <> 0 THEN CALL Hold(1)
uglRestore
uglEnd
CALL Lg("c2 restored + ended")

'----- cycle 3: keep uGL initialised, restore between modes (no uglEnd)
IF NOT uglInit THEN CALL Lg("c3 uglInit FAILED"): CALL Done
v = TryMode&("c3a", 640, 480, 2)
IF v <> 0 THEN CALL Hold(1)
uglRestore
CALL Lg("c3 restored (no end)")
v = TryMode&("c3b", 640, 480, 2)
IF v <> 0 THEN CALL Hold(1)
uglRestore
CALL Lg("c3 restored again")
v = TryMode&("c3c", 320, 200, 1)
IF v <> 0 THEN CALL Hold(1)
uglRestore
v = TryMode&("c3d", 640, 480, 2)
IF v <> 0 THEN CALL Hold(1)
uglRestore
uglEnd
CALL Lg("c3 ended")

'----- cycle 4: init again after cycle 3
IF NOT uglInit THEN CALL Lg("c4 uglInit FAILED"): CALL Done
v = TryMode&("c4", 640, 480, 2)
IF v <> 0 THEN CALL Hold(1)
uglRestore
uglEnd
CALL Lg("DONE")
CALL Done

SUB Done
	CLOSE #lf
	END
END SUB

SUB Hold (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	t9 = TIMER
	DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END SUB

SUB Lg (s AS STRING)
	PRINT #lf, s
END SUB

FUNCTION TryMode& (tag AS STRING, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
	DIM v AS LONG, inf AS TDC
	v = uglSetVideoDC(UGL.8BIT, xr, yr, np)
	IF v = 0 THEN
		CALL Lg(tag + ":" + STR$(xr) + "x" + LTRIM$(STR$(yr)) + " pages" + STR$(np) + " -> FAILED")
	ELSE
		uglDCGet v, inf
		CALL Lg(tag + ":" + STR$(xr) + "x" + LTRIM$(STR$(yr)) + " pages" + STR$(np) + " -> ok, bps" + STR$(inf.bps) + " pages" + STR$(inf.pages))
	END IF
	TryMode& = v
END FUNCTION
