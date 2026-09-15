
''
'' putb.bas -- alpha-blended bitmap drawing ex
''

DEFINT A-Z
'$INCLUDE: '..\inc\ugl.bi'

CONST xRes = 320
CONST yRes = 200
CONST cFmt = UGL.8BIT
CONST border = 0

CONST BMPS = 64
CONST bmpW = 32
CONST bmpH = 32

DECLARE SUB ExitError (msg AS STRING)

'':::
	DIM video AS LONG
	DIM bmp(0 TO BMPS - 1) AS LONG
	
	'' initialize
	IF (NOT uglInit) THEN ExitError "Init"
	
	'' change video-mode
	video = uglSetVideoDC(cFmt, xRes, yRes, 1)
	IF (video = 0) THEN ExitError "SetVideoDC"

	'' allocate the bitmaps
	IF (NOT uglNewMult(bmp(), BMPS, UGL.MEM, cFmt, bmpW, bmpH)) THEN
		ExitError "New bmps"
	END IF

        DIM rc AS CLIPRECT
	rc.xMin = border: rc.yMin = border
	rc.xMax = xRes - border: rc.yMax = yRes - border
        uglSetClipRect video, rc

	colors& = uglColors(cFmt)

	'' fill the bitmaps
	FOR i = 0 TO BMPS - 1
		FOR y = 0 TO bmpH - 1
			uglHLine bmp(i), 0, y, bmpW - 1, RND * colors&
		NEXT y
                uglRect bmp(i), 0, 0, bmpW - 1, bmpH - 1, RND * colors&
                uglLine bmp(i), 0, 0, bmpW - 1, bmpH - 1, uglColor(cFmt, 255, 0, 0)
                uglLine bmp(i), bmpW - 1, 0, 0, bmpH - 1, uglColor(cFmt, 255, 0, 0)
	NEXT i

        x = 0
        y = 0
        a = 110
        do
                uglClear video, uglColor(cFmt, 0, 255, 0)

                uglLine video, x, 0, x, yRes - 1, 0
                uglLine video, x + bmpW - 1, 0, x + bmpW - 1, yRes - 1, 0
	   
		'For i = 0 To 255
                        b& = bmp(1)
                        uglPut video, x, y, b&
                        uglPutAB video, x, y+40, a, b&
		'Next i

                DO
                   k$ = INKEY$
                LOOP WHILE (k$ = "")

                select case k$
                        case "a"
                                x = x - 1
                        case "d"
                                x = x + 1
                        case "w"
                                y = y - 1
                        case "s"
                                y = y + 1

                        case "z"
                                a = a + 1

                        case "x"
                                a = a - 1

                end select

        loop until k$ = chr$(27)

	uglRestore
	uglEnd
	END

'':::
SUB ExitError (msg AS STRING)
	uglRestore
	uglEnd
	PRINT "ERROR! "; msg
	END
END SUB

