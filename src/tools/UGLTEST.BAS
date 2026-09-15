'----- UGLTEST.BAS: uGL 0.23b smoke test for the Dark Visions QB45 toolchain.
'----- Proves: BC + LINK with UGL.LIB, the video-mode ladder (VESA 640x480x256
'----- with 2 pages -> 1 page -> plain VGA 320x200x256, which needs no VESA),
'----- 8-bit BMP load keeping its own palette, page flipping, pixel readback,
'----- conventional-memory cost. Writes UGLTEST.LOG in the cwd, auto-exits.
'----- Build/run: src\tools\ugltest.conf (DOSBox-X). Needs TPLOGO.BMP (640x480)
'----- and TPLOG320.BMP (320x200) in the cwd.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

DECLARE SUB Lg (s AS STRING)
DECLARE SUB Hold (secs AS SINGLE)
DECLARE SUB VSync ()
DECLARE SUB Done ()

DIM SHARED lf AS INTEGER

DIM video AS LONG, inf AS TDC
DIM pal(0 TO 255) AS tRGB
DIM blk(0 TO 255) AS tRGB
DIM ps AS STRING * 1024
DIM bmp AS STRING
DIM t0 AS SINGLE, t1 AS SINGLE
DIM f0 AS LONG, f1 AS LONG, f2 AS LONG, f3 AS LONG
DIM p1 AS LONG, p2 AS LONG, p3 AS LONG, p4 AS LONG, p5 AS LONG, p6 AS LONG
DIM r AS INTEGER, i AS INTEGER, bf AS INTEGER, pg AS INTEGER
DIM xr AS INTEGER, yr AS INTEGER, np AS INTEGER, cx AS INTEGER, cy AS INTEGER

lf = FREEFILE
OPEN "ugltest.log" FOR OUTPUT AS #lf
f0 = FRE(-1)
CALL Lg("free far heap before uglInit:" + STR$(f0))

IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CALL Done
f1 = FRE(-1)
CALL Lg("uglInit ok; free:" + STR$(f1))

'----- mode ladder: 640x480 2 pages -> 640x480 1 page -> 320x200 1 page (mode 13h)
xr = 640: yr = 480: np = 2
video = uglSetVideoDC(UGL.8BIT, xr, yr, np)
IF video = 0 THEN
	CALL Lg("640x480x8 2 pages: not available")
	np = 1
	video = uglSetVideoDC(UGL.8BIT, xr, yr, np)
END IF
IF video = 0 THEN
	CALL Lg("640x480x8 1 page: not available")
	xr = 320: yr = 200: np = 1
	video = uglSetVideoDC(UGL.8BIT, xr, yr, np)
END IF
IF video = 0 THEN CALL Lg("320x200x8: not available - no logo possible"): uglEnd: CALL Done
IF xr = 640 THEN bmp = "tplogo.bmp" ELSE bmp = "tplog320.bmp"
cx = xr \ 2: cy = yr \ 2
f2 = FRE(-1)
uglDCGet video, inf
CALL Lg("mode set:" + STR$(xr) + "x" + LTRIM$(STR$(yr)) + " pages" + STR$(np) + " art " + bmp)
CALL Lg("video DC: free:" + STR$(f2) + " xRes" + STR$(inf.xRes) + " yRes" + STR$(inf.yRes) + " bps" + STR$(inf.bps) + " pages" + STR$(inf.pages) + " size" + STR$(inf.size))

'----- palette straight from the BMP file (54-byte header, then 256 BGRA entries)
bf = FREEFILE
OPEN bmp FOR BINARY AS #bf
GET #bf, 55, ps
CLOSE #bf
FOR i = 0 TO 255
	pal(i).blue = MID$(ps, i * 4 + 1, 1)
	pal(i).green = MID$(ps, i * 4 + 2, 1)
	pal(i).red = MID$(ps, i * 4 + 3, 1)
	blk(i).red = CHR$(0): blk(i).green = CHR$(0): blk(i).blue = CHR$(0)
NEXT

'----- page 0: black palette, load the logo hidden, then reveal
uglSetWrkPage 0
uglSetVisPage 0
uglPalSetBuff 0, 256, blk(0)
r = uglPutBMPEx(video, 0, 0, bmp, BMPOPT.NO332)
CALL Lg("uglPutBMPEx " + bmp + ":" + STR$(r))
uglPalSetBuff 0, 256, pal(0)
p1 = uglPGet(video, 0, 0)
p2 = uglPGet(video, cx, cy)
p3 = uglPGet(video, 50, 50)
CALL Lg("page0 pixels (0,0)=" + STR$(p1) + " (centre)=" + STR$(p2) + " (50,50)=" + STR$(p3))
CALL Hold(4)

IF np = 2 THEN
	'----- page 1: solid fill + rectangle, flip to it
	uglSetWrkPage 1
	uglClear video, 40
	uglRectF video, 100, 100, 539, 379, 200
	CALL VSync
	uglSetVisPage 1
	p4 = uglPGet(video, 10, 10)
	p5 = uglPGet(video, cx, cy)
	CALL Lg("page1 pixels (10,10)=" + STR$(p4) + " (centre)=" + STR$(p5))
	CALL Hold(1)

	'----- flip timing: 60 vsync-locked flips between the two pages
	t0 = TIMER
	FOR i = 1 TO 60
		CALL VSync
		pg = i AND 1
		uglSetVisPage pg
	NEXT
	t1 = TIMER - t0
	CALL Lg("60 vsync flips took" + STR$(t1) + " s")
	CALL VSync
	uglSetVisPage 0
	uglSetWrkPage 0
	p6 = uglPGet(video, cx, cy)
	CALL Lg("page0 again (centre)=" + STR$(p6))
	CALL Hold(1)
ELSE
	CALL Lg("single page: flip test skipped")
END IF

uglRestore
uglEnd
f3 = FRE(-1)
CALL Lg("after uglEnd free:" + STR$(f3))
'----- cycle 2: re-open after a full close (the VGA manual will do this mid-game)
IF NOT uglInit THEN CALL Lg("cycle2 uglInit FAILED"): CALL Done
video = uglSetVideoDC(UGL.8BIT, 320, 200, 1)
IF video = 0 THEN CALL Lg("cycle2 320x200 FAILED"): uglEnd: CALL Done
uglPalSetBuff 0, 256, blk(0)
r = uglPutBMPEx(video, 0, 0, "tplog320.bmp", BMPOPT.NO332)
CALL Lg("cycle2 320x200 ok, put:" + STR$(r) + " px(160,100)=" + STR$(uglPGet(video, 160, 100)))
CALL Hold(1)
uglRestore
uglEnd
CALL Lg("cycle2 closed; free:" + STR$(FRE(-1)))
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

'----- wait for the NEXT vertical retrace: first leave any retrace in progress,
'----- then wait for one to start (a bare WAIT &H3DA, 8 returns at once mid-retrace)
SUB VSync
	WAIT &H3DA, 8, 8
	WAIT &H3DA, 8
END SUB
