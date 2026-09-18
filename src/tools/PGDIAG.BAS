'----- PGDIAG.BAS: why does the textured page draw in DOSBox but BLACK on the 486?
'----- Checks, on whatever machine runs it: (1) is a math coprocessor (FPU) present
'----- (BIOS equipment word 0040:0010 bit 1); (2) does the AFFINE mapper uglQuadT draw
'----- straight to video; (3) does the PERSPECTIVE mapper uglTriTP draw into a MEM
'----- back-buffer; (4) does uglPut copy the back-buffer to video. Each step reads back
'----- a pixel that should be a texture index (NOT 248 = the clear colour) if it drew.
'----- Writes PGDIAG.LOG. Build/run: src\tools\pgdiag.conf.
DEFINT A-Z
'$INCLUDE: 'UGL.BI'

CONST D2R = 3.141593 / 180!

DECLARE SUB Lg (s AS STRING)
DECLARE SUB HoldS (secs AS SINGLE)

DIM SHARED lf AS INTEGER

DIM video AS LONG, back AS LONG, tex AS LONG, rc AS CLIPRECT
DIM vq AS QuadType, t1 AS TriType
DIM pal(0 TO 255) AS tRGB, ps AS STRING * 1024
DIM eq AS INTEGER, fpu AS INTEGER, i AS INTEGER, bf AS INTEGER
DIM c AS SINGLE, cx AS INTEGER, cy AS INTEGER, w2 AS SINGLE, h2 AS SINGLE

lf = FREEFILE
OPEN "pgdiag.log" FOR OUTPUT AS #lf
CALL Lg("PGDIAG " + DATE$ + " " + TIME$)

'----- FPU present? BIOS equipment word at 0040:0010, bit 1 = math coprocessor
DEF SEG = &H40
eq = PEEK(&H10)
DEF SEG
fpu = (eq AND 2)
CALL Lg("BIOS equip low byte = " + HEX$(eq) + "h  coprocessor bit(AND 2) =" + STR$(fpu) + " (0 = NO FPU)")

IF NOT uglInit THEN CALL Lg("uglInit FAILED"): CLOSE #lf: END
video = uglSetVideoDC(UGL.8BIT, 640, 480, 1)
IF video = 0 THEN CALL Lg("mode fail"): uglEnd: CLOSE #lf: END
rc.xMin = 0: rc.yMin = 0: rc.xMax = 639: rc.yMax = 479
uglSetClipRect video, rc
tex = uglNewBMPEx(UGL.MEM, UGL.8BIT, "mantex.bmp", BMPOPT.NO332)
CALL Lg("texture handle =" + STR$(tex))
IF tex = 0 THEN CALL Lg("no texture"): uglRestore: uglEnd: CLOSE #lf: END

bf = FREEFILE
OPEN "manp00.bmp" FOR BINARY AS #bf
GET #bf, 55, ps
CLOSE #bf
FOR i = 0 TO 255
	pal(i).blue = MID$(ps, i * 4 + 1, 1): pal(i).green = MID$(ps, i * 4 + 2, 1): pal(i).red = MID$(ps, i * 4 + 3, 1)
NEXT
uglPalSetBuff 0, 256, pal(0)
cx = 320: cy = 240: w2 = 256: h2 = 192
c = COS(30 * D2R)

'----- (A) AFFINE quad straight to video (a 30-degree-narrowed rectangle)
uglClear video, 248
vq.v1.x = cx - w2 * c: vq.v1.y = cy - h2: vq.v1.u = 0: vq.v1.v = 0
vq.v2.x = cx + w2 * c: vq.v2.y = cy - h2: vq.v2.u = 1: vq.v2.v = 0
vq.v3.x = cx + w2 * c: vq.v3.y = cy + h2: vq.v3.u = 1: vq.v3.v = 1
vq.v4.x = cx - w2 * c: vq.v4.y = cy + h2: vq.v4.u = 0: vq.v4.v = 1
uglQuadT video, vq, UGL.MASK.FALSE, tex
CALL Lg("(A) AFFINE uglQuadT -> video: px(320,240)=" + STR$(uglPGet(video, 320, 240)) + " (260,240)=" + STR$(uglPGet(video, 260, 240)) + "  [248 = drew nothing]")
CALL HoldS(2.5)

'----- (B) PERSPECTIVE triangle into a MEM back-buffer (flat, z=1)
back = uglNew(UGL.MEM, UGL.8BIT, 640, 480)
CALL Lg("back-buffer handle =" + STR$(back))
IF back <> 0 THEN
	uglSetClipRect back, rc
	uglClear back, 248
	t1.v1.x = cx - w2: t1.v1.y = cy - h2: t1.v1.z = 1: t1.v1.u = 0: t1.v1.v = 0
	t1.v2.x = cx + w2: t1.v2.y = cy - h2: t1.v2.z = 1: t1.v2.u = 1: t1.v2.v = 0
	t1.v3.x = cx + w2: t1.v3.y = cy + h2: t1.v3.z = 1: t1.v3.u = 1: t1.v3.v = 1
	uglTriTP back, t1, UGL.MASK.FALSE, tex
	CALL Lg("(B) PERSP uglTriTP -> back: px(300,200)=" + STR$(uglPGet(back, 300, 200)) + " (330,240)=" + STR$(uglPGet(back, 330, 240)) + "  [248 = drew nothing]")
	uglPut video, 0, 0, back
	CALL Lg("(C) uglPut back -> video: px(300,200)=" + STR$(uglPGet(video, 300, 200)))
	CALL HoldS(2.5)
END IF
CALL Lg("DONE")
uglRestore
uglEnd
CLOSE #lf
END

SUB HoldS (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	t9 = TIMER
	DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END SUB

SUB Lg (s AS STRING)
	PRINT #lf, s
END SUB
