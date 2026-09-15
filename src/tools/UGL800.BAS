'----- UGL800.BAS: can uGL set 800x600x256 and how many pages fit? Tries 2 pages
'----- then 1 page at 800x600, logs the DC (bytes-per-scanline, pages, VRAM bytes)
'----- and free far heap to UGL800.LOG. Also re-checks 640x480 for comparison.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'
DECLARE SUB Lg (s AS STRING)
DECLARE SUB TryMode (bpp AS INTEGER, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
DIM SHARED lf AS INTEGER

lf = FREEFILE
OPEN "ugl800.log" FOR OUTPUT AS #lf
CLOSE #lf
CALL Lg("UGL800 " + DATE$ + " " + TIME$ + " start free" + STR$(FRE(-1)))
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): SYSTEM
CALL Lg("init free" + STR$(FRE(-1)))
CALL TryMode(UGL.8BIT, 800, 600, 2)
CALL TryMode(UGL.8BIT, 800, 600, 1)
CALL TryMode(UGL.8BIT, 640, 480, 2)
uglEnd
CALL Lg("DONE")
SYSTEM

SUB Lg (s AS STRING)
	DIM f AS INTEGER
	f = FREEFILE
	OPEN "ugl800.log" FOR APPEND AS #f
	PRINT #f, s
	CLOSE #f
END SUB

SUB TryMode (bpp AS INTEGER, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
	DIM v AS LONG, inf AS TDC, tag AS STRING
	tag = LTRIM$(STR$(xr)) + "x" + LTRIM$(STR$(yr)) + " pages" + STR$(np)
	v = uglSetVideoDC(bpp, xr, yr, np)
	IF v = 0 THEN
		CALL Lg(tag + ": REFUSED")
	ELSE
		uglDCGet v, inf
		CALL Lg(tag + ": OK bps" + STR$(inf.bps) + " pages" + STR$(inf.pages) + " vram bytes" + STR$(inf.size) + " free" + STR$(FRE(-1)))
		uglRestore
	END IF
END SUB
