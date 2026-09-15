''
''
''
DEFINT A-Z
'$INCLUDE: '..\inc\ugl.bi'

CONST PI = 3.141593
CONST D2R = PI / 180!

CONST xRes = 320 * 1
CONST yRes = 200 * 1
CONST cFmt = UGL.8BIT
CONST border = 32

DECLARE SUB doInit ()
DECLARE SUB doTerminate ()
DECLARE SUB doMain ()
DECLARE SUB ExitError (msg AS STRING)

DECLARE SUB rotVtx (src AS vector3f, dst AS vector3f, s AS SINGLE, c AS SINGLE, cx AS INTEGER, cy AS INTEGER)
DECLARE SUB rotQuad (src AS QuadType, dst AS QuadType, angle AS SINGLE, scale AS SINGLE, cx AS INTEGER, cy AS INTEGER)

	DIM result AS LONG
	DIM SHARED hvideodc AS LONG
	
	doInit
	doMain
	doTerminate

SUB doInit

	'' Init lib
	IF (uglInit = 0) THEN ExitError "0x0000, Could not init lib..."

	'' Set video mode
	''
	hvideodc = uglSetVideoDC(cFmt, xRes, yRes, 1)
	IF (hvideodc = 0) THEN ExitError "0x0001, Could not set video mode..."
	
END SUB

SUB doMain
	STATIC vtx AS QuadType, rvtx AS QuadType
	DIM scale AS SINGLE, sInc AS SINGLE
	DIM angle AS SINGLE, aInc AS SINGLE
	DIM cx AS INTEGER, cy AS INTEGER
	
	cx = xRes \ 2
	cy = yRes \ 2
	angle = 0
	aInc = 6
	sInc = .5
	scale = .1

        DIM rc AS CLIPRECT
	rc.xMin = border: rc.yMin = border
	rc.xMax = xRes - border: rc.yMax = yRes - border
	uglSetClipRect hvideodc, rc
   
	DO
		'uglclear hvideodc, -1
	   
		angle = (angle + aInc)
		IF angle >= 360 THEN angle = angle - 360

		scale = scale + sInc
		IF (scale < .1) THEN
			scale = .1
			sInc = -sInc
			cx = RND * xRes
			cy = RND * yRes
		ELSEIF (scale > 1) THEN
			scale = 1
			sInc = -sInc
		END IF
	   
		vtx.v1.x = -xRes \ 2: vtx.v1.y = -yRes \ 2
		vtx.v2.x = xRes \ 2: vtx.v2.y = -yRes \ 2
		vtx.v3.x = xRes \ 2: vtx.v3.y = yRes \ 2
		vtx.v4.x = -xRes \ 2: vtx.v4.y = yRes \ 2
		rotQuad vtx, rvtx, angle, scale, cx, cy
	   
		r = RND * 256
		g = RND * 256
		b = RND * 256
		uglQuadF hvideodc, rvtx, uglColor(cFmt, r, g, b)

		'DO
			k$ = INKEY$
		'LOOP WHILE LEN(k$) = 0
		IF LEN(k$) = 0 THEN k$ = " "
	LOOP UNTIL (ASC(k$) = 27)
END SUB

SUB doTerminate

	'' Terminate lib
	''
	uglRestore
	uglEnd
	
END SUB

SUB ExitError (msg AS STRING)
	
	'' Terminate lib
	''
	uglRestore
	uglEnd
	
	'' Print message
	PRINT "Error: " + msg
		
END SUB

'':::
SUB rotQuad (src AS QuadType, dst AS QuadType, angle AS SINGLE, scale AS SINGLE, cx AS INTEGER, cy AS INTEGER) STATIC
  DIM s AS SINGLE, c AS SINGLE

  s = SIN(angle * D2R) * scale
  c = COS(angle * D2R) * scale

  rotVtx src.v1, dst.v1, s, c, cx, cy
  rotVtx src.v2, dst.v2, s, c, cx, cy
  rotVtx src.v3, dst.v3, s, c, cx, cy
  rotVtx src.v4, dst.v4, s, c, cx, cy
END SUB

SUB rotVtx (src AS vector3f, dst AS vector3f, s AS SINGLE, c AS SINGLE, cx AS INTEGER, cy AS INTEGER) STATIC
  dst.x = ((src.x * c) - (src.y * s)) + cx
  dst.y = ((src.y * c) + (src.x * s)) + cy
END SUB

