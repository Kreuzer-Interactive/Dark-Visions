'----- UGLTEST2.BAS: probe for the VGA manual's tricks on uGL 0.23b:
'----- two-page VRAM addressing, VESA display start (INT 10h 4F07h) and the
'----- CRTC line-compare split screen. Bands of 16 lines are drawn on both video
'----- pages (page p line y -> colour 16 + p*64 + y\16), read back, then the
'----- display start and split are exercised with 4-second holds for screenshots.
'----- Writes UGLTEST2.LOG in the cwd, auto-exits.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

TYPE RegType
	ax AS INTEGER
	bx AS INTEGER
	cx AS INTEGER
	dx AS INTEGER
	bp AS INTEGER
	si AS INTEGER
	di AS INTEGER
	flags AS INTEGER
END TYPE
DECLARE SUB INTERRUPT (intnum AS INTEGER, inreg AS RegType, outreg AS RegType)
DECLARE SUB Lg (s AS STRING)
DECLARE SUB Hold (secs AS SINGLE)
DECLARE SUB Done ()
DECLARE FUNCTION Crtc% (idx AS INTEGER)
DECLARE SUB LogRegs (tag AS STRING)

DIM SHARED lf AS INTEGER
DIM video AS LONG, r AS RegType, r2 AS RegType, vi AS INTEGER
DIM p AS INTEGER, k AS INTEGER, y AS INTEGER, v AS LONG, ln AS INTEGER

lf = FREEFILE
OPEN "ugltest2.log" FOR OUTPUT AS #lf
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CALL Done
video = uglSetVideoDC(UGL.8BIT, 640, 480, 2)
IF video = 0 THEN CALL Lg("no 640x480x2"): uglEnd: CALL Done

'----- bands on both pages
FOR p = 0 TO 1
	uglSetWrkPage p
	FOR k = 0 TO 29
		uglRectF video, 0, k * 16, 639, k * 16 + 15, 16 + p * 64 + k
	NEXT
NEXT
'----- does the BMP loader honour the work page? draw TPLOG320.BMP on page 1 and read both pages
uglSetWrkPage 1
v = uglPutBMPEx(video, 0, 0, "tplog320.bmp", BMPOPT.NO332)
CALL Lg("PutBMPEx on wrk page 1 returned" + STR$(v))
uglSetWrkPage 0
CALL Lg("page 0 (10,100) now" + STR$(uglPGet(video, 10, 100)) + " (band expects" + STR$(16 + 100 \ 16) + "; a logo pixel means the loader wrote page 0)")
uglSetWrkPage 1
CALL Lg("page 1 (10,100) now" + STR$(uglPGet(video, 10, 100)) + " (band expects" + STR$(80 + 100 \ 16) + ")")
CALL Lg("page 1 (160,100) now" + STR$(uglPGet(video, 160, 100)) + " (logo centre would be 48)")
uglSetWrkPage 0
CALL Lg("page 0 (160,100) now" + STR$(uglPGet(video, 160, 100)) + " (logo centre would be 48)")
'----- read back
FOR p = 0 TO 1
	uglSetWrkPage p
	FOR y = 0 TO 479 STEP 60
		v = uglPGet(video, 10, y)
		CALL Lg("page" + STR$(p) + " line" + STR$(y) + " read" + STR$(v) + " expect" + STR$(16 + p * 64 + y \ 16))
	NEXT
NEXT
uglSetWrkPage 0
uglSetVisPage 0
vi = &H10
CALL LogRegs("after SetVisPage 0")
uglSetWrkPage 1
CALL LogRegs("after SetWrkPage 1")
uglSetWrkPage 0
r.ax = &H4F07: r.bx = 0: r.cx = 0: r.dx = 20
CALL INTERRUPT(vi, r, r2)
CALL Lg("4F07 set y=20 returned ax=" + HEX$(r2.ax))
CALL LogRegs("after 4F07 y=20")
CALL Hold(4)
'----- split screen at line 459
OUT &H3D4, &H18: OUT &H3D5, 459 AND 255
OUT &H3D4, 7: ln = INP(&H3D5): OUT &H3D5, (ln AND &HEF) OR 16
OUT &H3D4, 9: ln = INP(&H3D5): OUT &H3D5, ln AND &HBF
CALL LogRegs("after split 459")
CALL Hold(4)
'----- display start at page-1 line 20 (VRAM 500)
r.ax = &H4F07: r.bx = 0: r.cx = 0: r.dx = 500
CALL INTERRUPT(vi, r, r2)
CALL Lg("4F07 set y=500 returned ax=" + HEX$(r2.ax))
CALL LogRegs("after 4F07 y=500")
CALL Hold(4)
'----- uGL's own flip to page 1, for comparison
uglSetVisPage 1
CALL LogRegs("after uglSetVisPage 1")
CALL Hold(4)
uglRestore
uglEnd
CALL Lg("DONE")
CALL Done

FUNCTION Crtc% (idx AS INTEGER)
	OUT &H3D4, idx
	Crtc% = INP(&H3D5)
END FUNCTION

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

'----- VBE display start (4F07 BL=1) + CRTC start address bytes + S3 extended bits
SUB LogRegs (tag AS STRING)
	DIM r AS RegType, r2 AS RegType, vi AS INTEGER
	vi = &H10
	r.ax = &H4F07: r.bx = 1
	CALL INTERRUPT(vi, r, r2)
	CALL Lg(tag + ": 4F07 get ax=" + HEX$(r2.ax) + " cx=" + STR$(r2.cx) + " dx=" + STR$(r2.dx))
	CALL Lg("   CR0C=" + STR$(Crtc%(&HC)) + " CR0D=" + STR$(Crtc%(&HD)) + " CR13=" + STR$(Crtc%(&H13)) + " CR18=" + STR$(Crtc%(&H18)) + " CR07=" + STR$(Crtc%(7)) + " CR09=" + STR$(Crtc%(9)))
	CALL Lg("   CR31=" + STR$(Crtc%(&H31)) + " CR51=" + STR$(Crtc%(&H51)) + " CR69=" + STR$(Crtc%(&H69)))
END SUB
