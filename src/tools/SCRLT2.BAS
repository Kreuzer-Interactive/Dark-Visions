'----- SCRLT2.BAS: clean visual proof of direct-CRTC scrolling on the 486 Cirrus.
'----- v1 (SCRLTEST) set no palette, so its bands showed as yellow/white mush. This
'----- one sets a vivid palette and does ONE unmistakable thing: a 640x480x256 two-
'----- page screen with page 0 = red top / green bottom and page 1 (VRAM line 480) =
'----- solid blue with a big white "2". It scrolls the display start straight from
'----- page 0 down to page 1 and back, twice, by writing the Cirrus CRTC start-
'----- address registers directly (CR0C/CR0D + CR1B bits 0,2,3 = address bits 16-18;
'----- Cirrus extensions unlocked with SR06=12h). No VESA BIOS call. What you should
'----- see: RED, then GREEN, then a BLUE screen with a white 2, then back - a smooth
'----- vertical scroll through three clear colours. Writes SCRLT2.LOG, auto-exits.
'----- Build/run: src\tools\scrlt2.conf (DOSBox-X S3 proves it too, minus the Cirrus
'----- high-address bits which only the real card needs).
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

DECLARE SUB Lg (s AS STRING)
DECLARE SUB Hold (secs AS SINGLE)
DECLARE FUNCTION CrtcR% (idx AS INTEGER)
DECLARE SUB CrtcW (idx AS INTEGER, v AS INTEGER)
DECLARE FUNCTION SeqR% (idx AS INTEGER)
DECLARE SUB SeqW (idx AS INTEGER, v AS INTEGER)
DECLARE SUB StartAt (ofs AS LONG)
DECLARE SUB Digit2 ()

DIM SHARED lf AS INTEGER
DIM SHARED video AS LONG
DIM SHARED pitch AS LONG, unit AS INTEGER, cirrus AS INTEGER, chip AS INTEGER

DIM inf AS TDC
DIM pal(0 TO 255) AS tRGB
DIM xr AS INTEGER, yr AS INTEGER, np AS INTEGER, i AS INTEGER, y AS INTEGER, cyc AS INTEGER
DIM s6b AS INTEGER, s6c AS INTEGER

lf = FREEFILE
OPEN "scrlt2.log" FOR OUTPUT AS #lf
CALL Lg("SCRLT2 " + DATE$ + " " + TIME$)
IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CLOSE #lf: END
xr = 640: yr = 480: np = 2
video = uglSetVideoDC(UGL.8BIT, xr, yr, np)
IF video = 0 THEN CALL Lg("640x480x8 2 pages refused"): uglEnd: CLOSE #lf: END
uglDCGet video, inf
pitch = inf.bps
CALL Lg("mode 640x480x8 2pg bps" + STR$(inf.bps) + " size" + STR$(inf.size))

'----- CRTC addressing unit: CR14 bit6 = dword, else CR17 bit6 = byte, else word
IF CrtcR%(&H14) AND &H40 THEN
	unit = 4
ELSEIF CrtcR%(&H17) AND &H40 THEN
	unit = 1
ELSE
	unit = 2
END IF
'----- Cirrus? SR06 reads 0Fh when locked, 12h after the 12h unlock
CALL SeqW(6, &HA): s6b = SeqR%(6)
CALL SeqW(6, &H12): s6c = SeqR%(6)
cirrus = 0: chip = 0
IF s6b = &HF AND s6c = &H12 THEN cirrus = -1: chip = CrtcR%(&H27)
CALL Lg("unit" + STR$(unit) + " cirrus" + STR$(cirrus) + " CR27 " + HEX$(chip) + " CR1B " + HEX$(CrtcR%(&H1B)))

'----- vivid palette: 1 white, 2 red, 3 green, 4 blue, 5 yellow (rest black)
FOR i = 0 TO 255
	pal(i).red = CHR$(0): pal(i).green = CHR$(0): pal(i).blue = CHR$(0)
NEXT
pal(1).red = CHR$(255): pal(1).green = CHR$(255): pal(1).blue = CHR$(255)
pal(2).red = CHR$(255): pal(2).green = CHR$(0): pal(2).blue = CHR$(0)
pal(3).red = CHR$(0): pal(3).green = CHR$(210): pal(3).blue = CHR$(0)
pal(4).red = CHR$(40): pal(4).green = CHR$(90): pal(4).blue = CHR$(255)
pal(5).red = CHR$(255): pal(5).green = CHR$(210): pal(5).blue = CHR$(0)
uglPalSetBuff 0, 256, pal(0)

'----- page 0 (VRAM lines 0-479): red top half, green bottom half, edge stripes
uglSetWrkPage 0
uglRectF video, 0, 0, 639, 239, 2
uglRectF video, 0, 240, 639, 479, 3
uglRectF video, 0, 0, 639, 9, 1
uglRectF video, 0, 470, 639, 479, 5
'----- page 1 (VRAM lines 480-959): solid blue + a big white "2"
uglSetWrkPage 1
uglRectF video, 0, 0, 639, 479, 4
CALL Digit2
uglSetWrkPage 0

'----- start on page 0, then scroll down to page 1 and back, twice
CALL StartAt(0)
CALL Hold(2.5)
FOR cyc = 1 TO 2
	FOR y = 0 TO 480 STEP 2
		CALL StartAt(y * pitch)
	NEXT
	CALL Lg("cycle" + STR$(cyc) + " at page1: CR0C " + HEX$(CrtcR%(&HC)) + " CR0D " + HEX$(CrtcR%(&HD)) + " CR1B " + HEX$(CrtcR%(&H1B)))
	CALL Hold(2.5)
	FOR y = 480 TO 0 STEP -2
		CALL StartAt(y * pitch)
	NEXT
	CALL Hold(2.5)
NEXT
CALL StartAt(0)
uglRestore
uglEnd
CALL Lg("DONE")
CLOSE #lf
END

'----- big blocky white "2" centred on page 1 (its own y is VRAM line 480+)
SUB Digit2
	uglRectF video, 240, 140, 400, 172, 1
	uglRectF video, 368, 172, 400, 236, 1
	uglRectF video, 240, 236, 400, 268, 1
	uglRectF video, 240, 268, 272, 320, 1
	uglRectF video, 240, 320, 400, 352, 1
END SUB

'----- direct CRTC display start: ofs = byte offset into video memory
SUB StartAt (ofs AS LONG)
	DIM u AS LONG, b AS INTEGER
	u = ofs \ unit
	WAIT &H3DA, 8, 8
	CALL CrtcW(&HC, (u \ 256) AND 255)
	CALL CrtcW(&HD, u AND 255)
	IF cirrus THEN
		b = CrtcR%(&H1B) AND &HF2
		IF u AND &H10000 THEN b = b OR 1
		IF u AND &H20000 THEN b = b OR 4
		IF u AND &H40000 THEN b = b OR 8
		CALL CrtcW(&H1B, b)
		IF chip >= &HA0 THEN
			b = CrtcR%(&H1D) AND &H7F
			IF u AND &H80000 THEN b = b OR &H80
			CALL CrtcW(&H1D, b)
		END IF
	END IF
	WAIT &H3DA, 8
END SUB

FUNCTION CrtcR% (idx AS INTEGER)
	OUT &H3D4, idx
	CrtcR% = INP(&H3D5)
END FUNCTION

SUB CrtcW (idx AS INTEGER, v AS INTEGER)
	OUT &H3D4, idx
	OUT &H3D5, v
END SUB

FUNCTION SeqR% (idx AS INTEGER)
	OUT &H3C4, idx
	SeqR% = INP(&H3C5)
END FUNCTION

SUB SeqW (idx AS INTEGER, v AS INTEGER)
	OUT &H3C4, idx
	OUT &H3C5, v
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
