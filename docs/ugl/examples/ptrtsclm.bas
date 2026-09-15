''
''  putrotm.bas - Using uglPutRotSclMsk to rotate and
''                scale a DCs
''              
''
''

DEFINT A-Z
'$INCLUDE: '..\inc\ugl.bi'
'$INCLUDE: '..\inc\kbd.bi'
'$INCLUDE: '..\inc\font.bi'

CONST xRes = 320
CONST yRes = 200
CONST cFmt = UGL.16BIT
CONST FALSE = 0
CONST PAGES = 1


TYPE EnvType
	hFont       AS LONG
	hVideoDC    AS LONG
	hTextrDC    AS LONG
	Keyboard    AS TKBD
	FPS         AS SINGLE
	ViewPage    AS INTEGER
	WorkPage    AS INTEGER
END TYPE


DECLARE SUB doMain ()
DECLARE SUB doInit ()
DECLARE SUB doTerminate ()
DECLARE SUB ExitError (msg AS STRING)


	'' Your code goes in doMain ( )
	
	DIM SHARED Env AS EnvType
	
	doInit
	doMain
	doTerminate

SUB doInit

	'' Init UGL
	''
	IF (uglInit = FALSE) THEN
		ExitError "0x0000, UGL init failed..."
	END IF
	
	
	'' Set video mode with x pages where
	'' x = PAGES
	''
	Env.hVideoDC = uglSetVideoDC(cFmt, xRes, yRes, PAGES)
	IF (Env.hVideoDC = FALSE) THEN ExitError "0x0001, Could not set video mode..."
	
	
	'' Init keyboard handler
	''
	kbdInit Env.Keyboard
	
	
	'' Load UGL logo
	Env.hTextrDC = uglNewBMP(UGL.MEM, cFmt, "data/ugl.bmp")
	IF (Env.hTextrDC = FALSE) THEN ExitError "0x0002, Could not load data/ugl.bmp..."
	
END SUB

SUB doMain
	STATIC frmCounter AS SINGLE
	STATIC angle AS SINGLE, anglek AS SINGLE
	STATIC scale  AS SINGLE, scalek AS SINGLE
	STATIC tmrIni AS SINGLE, tmrEnd AS SINGLE
		
	scale = 1.1
	scalek = 0!
	anglek = 0!

	tmrIni = TIMER
	frmCounter = 0

	DO
		'' Wait for vsync
		'wait &h3da, 8
		
		'' Page flipping     
		'uglSetVisPage Env.ViewPage
		'uglSetWrkPage Env.WorkPage
		
		'' Clear screen
		'uglClear Env.hVideoDC, 0    
		
		'' Rotate DC
		uglPutMskRotScl Env.hVideoDC, (xRes - 128 * scale) / 2, (yRes - 128 * scale) / 2, angle, scale, scale, Env.hTextrDC
		
		
		IF (Env.Keyboard.p = FALSE) THEN
			angle = angle + anglek
			scale = scale + scalek
			
			IF (angle >= 360! AND anglek > 0) THEN
				angle = 0
			ELSEIF (angle <= 0! AND anglek < 0) THEN
				angle = 360
			END IF
			
			IF (scale >= 64) THEN
				scale = 64
			ELSEIF (scale <= .1) THEN
				scale = .1
			END IF
		END IF
		
		IF (Env.Keyboard.up) THEN scale = scale - .01
		IF (Env.Keyboard.down) THEN scale = scale + .01
		IF (Env.Keyboard.left) THEN anglek = anglek - .01
		IF (Env.Keyboard.right) THEN anglek = anglek + .01
		
		
		
		'' Update some frame counter
		'' etc etc     
		frmCounter = frmCounter + 1!
		Env.ViewPage = Env.WorkPage
		Env.WorkPage = (Env.WorkPage + 1) MOD PAGES
		
	LOOP UNTIL (Env.Keyboard.Esc)
	
	tmrEnd = TIMER
	Env.FPS = frmCounter / (tmrEnd - tmrIni)
		
END SUB

SUB doTerminate

	'' Terminate UGL
	''
	kbdEnd
	uglRestore
	uglEnd
	
	'' Print FPS
	CLS
	PRINT "Frames per second:" + STR$(CINT(Env.FPS))
		
END SUB

SUB ExitError (msg AS STRING)

	'' Terminate UGL
	'
	kbdEnd
	uglRestore
	uglEnd
	
	'' Print error message
	'' and end
	'
	PRINT "Error: " + msg
	END
	
END SUB

