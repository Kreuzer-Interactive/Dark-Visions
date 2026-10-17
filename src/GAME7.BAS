'----- GAME7.BAS: the 3D intro car: the road drive and, since 2026-10-14, the
'----- drive up the hill to the house over the artist's hill picture, with the
'----- hill scene's lightning and thunder. Intro (GAME.BAS) used to lift the CGA car
'----- sprite off carr.pic and PUT it across the screen, one step per engine
'----- sweep; IntroCar3D drives the textured 3D model of tools\CAR3D.BAS
'----- (CAR3D.MDL + CAR3D.BMP from tools\car3dcnv.ps1) along the same road in
'----- VGA mode 13h over the painted backdrop CARROAD.BMP, with the same
'----- engine sweep (SOUND tc,.06 / SOUND f3,.06, tc 50..200 by 18) playing
'----- in the background. Seventh code module -> its own 64K code segment;
'----- pure library (no COMMON SHARED, no UGL.BI: GAME6 owns uGL -- the mode
'----- switch, the retrace wait and FileExists come from there).
'-----
'----- The renderer is FPU-free (the 486SX): hand-assembled 386 routines from
'----- tools\build_car3d_asm.ps1, loaded as strings and CALL ABSOLUTEd:
'-----   C3DPRJ.OVL    projection of the prepared model (1/16 pixel) + its box
'-----   C3DT128.OVL   the frame: screen-winding cull, affine texture mapping
'-----   (C3DTRI.OVL)  (8.8 fixed point, colour key 255), far-to-near, into
'-----                 the work buffer; the 64-texel mapper for a 64-wide BMP
'-----   C3DEDGE.OVL   marks the car's silhouette pixels (254)
'-----   SHADBOP.OVL   rectangle copies (backdrop strip -> work buffer)
'-----   C3DBLTF.OVL   the copy to VRAM, 254 -> colour 3 (the ink outline); backdrop
'-----                 pixels flagged by the converter's -Front mask (bit 7) go
'-----                 out instead of the car: the car passes behind them
'-----   C3DROT.OVL    rotates the model to a pitch and a heading and depth-sorts
'-----                 the faces (every frame the heading changes)
'----- Memory (the far heap is ~43 KB free in the game; Intro ERASEs the
'----- shadow / anim caches around the call): the backdrop rows BGY0..199
'----- only (the car never leaves rows 119..190), a WKW x WKH work buffer,
'----- the texture and the rotated model -- about 70 KB, checked against
'----- FRE(-1) first. Anything missing returns 1 and Intro shows the CGA
'----- sprite drive as before. Nothing is allocated -- and FRE(-1) is never
'----- called, it compacts the heap -- once C3dPoint has taken the buffers'
'----- addresses (the far heap moves arrays).
'-----
'----- Timing: SPD tenths of a path step (of 200 along the road) per 70 Hz
'----- retrace, twice that when a frame took two. The clock is the engine
'----- sound itself: QB's
'----- background music runs PIT channel 0 at 582.6 Hz (reload 2048) while
'----- notes play and every SOUND x,.06 lasts exactly one of those ticks, so
'----- the notes consumed from the queue (PLAY(0)) measure time to 1.7 ms;
'----- the PIT count means nothing meanwhile (tools\PITPROBE.BAS).
'----- C3DDUMP=1 in the environment appends the timing to C3D.LOG.
'----- C3DEDIT=1: the artist's turn editor. While the car drives, the Left and
'----- Right arrows turn it (2 degrees a press) on top of the path's heading
'----- and the offset is recorded per road step; at the end the last frame
'----- holds with the engine off, R runs (and records) the drive again, Esc,
'----- S or space goes on (other keys are ignored there). The recording is saved as C3DTURN.DAT ("C3DT", n,
'----- n quarter-degrees) and a normal run applies it to the heading; delete
'----- the file for the plain curve.
DEFINT A-Z
TYPE C3dFac
	a AS INTEGER
	b AS INTEGER
	c AS INTEGER
	d AS INTEGER
	ci AS INTEGER
END TYPE
TYPE C3dHdr
	magic AS STRING * 4
	nv AS INTEGER
	nf AS INTEGER
	flags AS INTEGER
END TYPE
TYPE C3dVtx
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
	u AS SINGLE
	v AS SINGLE
END TYPE
TYPE C3dNrm
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
END TYPE

DECLARE FUNCTION IntroCar3D% (f3 AS SINGLE, f10 AS SINGLE, f1 AS SINGLE, f6 AS SINGLE, nfr AS SINGLE)
DECLARE FUNCTION IntroCar3DLoad% (f3 AS SINGLE, f10 AS SINGLE, f1 AS SINGLE, f6 AS SINGLE)
DECLARE SUB StartupOpen ()
DECLARE SUB StartupLine (s AS STRING)
DECLARE SUB StartupPart (s AS STRING)
DECLARE FUNCTION C3dDrive% (trk AS INTEGER)
DECLARE SUB C3dSceneRoad ()
DECLARE SUB C3dSceneHill ()
DECLARE SUB C3dWay ()
DECLARE SUB C3dHeadPitch ()
DECLARE SUB C3dTrack (need AS LONG)
DECLARE SUB C3dAlloc ()
DECLARE SUB C3dFlash (lit AS INTEGER)
DECLARE SUB C3dDrain ()
DECLARE SUB C3dKeep ()
DECLARE SUB C3dMark (s AS STRING)
DECLARE SUB C3dHillSave ()
DECLARE SUB C3dHillLoad ()
DECLARE FUNCTION C3dProbe& ()
DECLARE FUNCTION C3dLoadModel% ()
DECLARE FUNCTION C3dLoadTexture% ()
DECLARE SUB C3dLoadBg (fil AS STRING)
DECLARE SUB C3dLoadOvl (fil AS STRING, s AS STRING)
DECLARE SUB C3dPoint ()
DECLARE SUB C3dBand (b AS INTEGER, w AS INTEGER)
DECLARE FUNCTION C3dBandSeg% (b AS INTEGER)
DECLARE SUB C3dSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
DECLARE SUB C3dPath (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB C3dBend ()
DECLARE SUB C3dTurn (d AS INTEGER)
DECLARE SUB C3dTurnA (a AS SINGLE, d AS INTEGER)
DECLARE SUB C3dHeadTab ()
DECLARE SUB C3dLoadTurn ()
DECLARE SUB C3dSaveTurn ()
DECLARE SUB C3dDbg ()
DECLARE SUB C3dDraw (px AS LONG, py AS LONG, pz AS LONG)
DECLARE SUB C3dCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
DECLARE SUB C3dCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
DECLARE SUB C3dCopyF (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, fg AS INTEGER, fo AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, fst AS INTEGER, col AS INTEGER)
DECLARE FUNCTION C3dSeg% (sg AS INTEGER, ofs AS INTEGER)
DECLARE SUB C3dPal (f AS INTEGER)
DECLARE FUNCTION C3dHold% (secs AS SINGLE)
DECLARE SUB C3dFree ()
DECLARE SUB C3dShot (fil AS STRING)
DECLARE FUNCTION C3dTicks& ()
DECLARE FUNCTION C3dTabKey& ()
DECLARE FUNCTION C3dTabLoad% (blk AS INTEGER)
DECLARE SUB C3dTabSave ()
'----- GAME2 (the binary-cache helpers)
DECLARE SUB BinGetI (fh AS INTEGER, a%(), n AS INTEGER)
DECLARE SUB BinGetL (fh AS INTEGER, a&(), n AS INTEGER)
DECLARE SUB BinPutI (fh AS INTEGER, a%(), n AS INTEGER)
DECLARE SUB BinPutL (fh AS INTEGER, a&(), n AS INTEGER)
'----- GAME6
DECLARE FUNCTION VgaOpen& (pref AS INTEGER, xr AS INTEGER, yr AS INTEGER, np AS INTEGER)
DECLARE SUB VgaClose ()
DECLARE SUB VgaSync ()
DECLARE FUNCTION FileExists% (fil AS STRING)

'----- the work buffer (the car's screen box is at most about 126x66 at the
'----- converter's 1.15 scale, plus the join with the previous frame's box)
'----- and the backdrop strip's first row
CONST WKW = 152
CONST WKH = 100
CONST BGY0 = 80
'----- the pace: tenths of a path step per 70 Hz retrace (10 = one step per
'----- retrace, the 2026-10-13 pace, 3.0 s for the drive; 17 = 70% faster)
'----- the bend (carr_road2.png turns up and away at the right): from step
'----- BENDS the car's wheel line follows a curve on screen that leaves along
'----- the straight run's motion (BENDM steps' worth of it to the control
'----- point) to (BENDX, BENDY), its depth rising with the distance covered to
'----- BENDZ units -- the road climbs there, so the screen point sets the
'----- height. The steps along it keep perspective: the screen speed falls
'----- with the SQUARE of the depth as it does on the straight run, and the
'----- depth's growth per screen pixel ramps up from the straight run's rate,
'----- so nothing changes abruptly at the join. A car receding like that
'----- slows a lot on screen, so the drive is cut BENDL steps into the bend
'----- (the table runs on to BENDMAX steps). The heading over the drive is
'----- the artist's take (turnKnots below); C3dBend builds the tables
CONST BENDMAX = 300
CONST BENDNS = 200
'----- the pitch (tenths of a degree, positive = nose up) the car reaches at
'----- the cut, evenly from the bend's start; none on the straight run

'----- the drive (x16 units): the world line of tools\CAR3D.BAS, from screen
'----- (77,154) at depth 420 to depth 740 under the sprite's last x; the car
'----- heads along it (yaw = 90 deg - ATN(PDZ/PDX)), away from the camera
'----- the light (x256, camera space, towards it) for a lit model: upper left
CONST LX = -137
CONST LY = 154
CONST LZ = -153
'----- the heading tables cover a straight run of at most 200 steps + the bend
CONST TMAX = 500
'----- a tangent heading (mode 1) is the chord over this many steps each way:
'----- 12 steps = about the car's wheelbase (108 units) on the hill path
CONST HEADW = 12
'----- the scene's numbers (the constants above describe them; C3dSceneRoad and
'----- C3dSceneHill set them): the straight run, the bend, the cut, the pace in
'----- tenths of a step per retrace, the pitch at the cut and the step it starts
'----- from (with heading mode 1 the pitch is the path's own climb plus PITCHE),
'----- the heading mode (0 = the knots below, 1 = the path's own direction)
DIM SHARED PX0 AS INTEGER, PDX AS INTEGER, PY0 AS INTEGER, PDY AS INTEGER, PZ0 AS INTEGER, PDZ AS INTEGER
DIM SHARED BENDS AS INTEGER, BENDM AS INTEGER, BENDX AS INTEGER, BENDY AS INTEGER, BENDZ AS INTEGER, BENDL AS INTEGER
DIM SHARED SPD AS INTEGER, PITCHE AS INTEGER, PITCHS AS INTEGER, HEADM AS INTEGER, PACEX AS INTEGER, bgFile AS STRING
DIM SHARED flashAt(0 TO 31) AS INTEGER, nflash AS INTEGER, trkLen AS INTEGER, trkPos AS INTEGER, trkThunder AS INTEGER
'----- the hill drive's stop (2026-10-15, the artist): the last DECELS steps ease
'----- out, then RBF frames of roll-back (RBT tenths of a step each: the
'----- anticipation before the full stop), then the car sits for the thunder
CONST DECELS = 50
'----- the car is drawn 12 times a second (the artist, 2026-10-15: the stop-
'----- motion look of a classic): a drawn frame every FPSN notes of the clock
'----- (1.717 ms each: 48 = 1/12 s); the path runs on between
CONST FPSN = 48
CONST RBF = 2
CONST RBT = 5
DIM SHARED sf3 AS SINGLE, sf10 AS SINGLE, sf1 AS SINGLE, sf6 AS SINGLE, frameAcc AS LONG
DIM SHARED blk(0 TO 15) AS INTEGER, nblk AS INTEGER

REM $DYNAMIC
DIM SHARED mx(1) AS INTEGER, my(1) AS INTEGER, mz(1) AS INTEGER
DIM SHARED rx(1) AS INTEGER, ry(1) AS INTEGER, rz(1) AS INTEGER
DIM SHARED tpx(1) AS LONG, tpy(1) AS LONG, tpz(1) AS LONG, tcs(1) AS INTEGER, tsn(1) AS INTEGER
DIM SHARED tyaw(1) AS SINGLE, toff(1) AS INTEGER, tcp(1) AS INTEGER, tsp(1) AS INTEGER
DIM SHARED hpx(1) AS LONG, hpy(1) AS LONG, hpz(1) AS LONG, hcs(1) AS INTEGER, hsn(1) AS INTEGER, hcp(1) AS INTEGER, hsp(1) AS INTEGER
DIM SHARED qx(1) AS SINGLE, qy(1) AS SINGLE, qa(1) AS SINGLE, qp(1) AS SINGLE, tpit(1) AS INTEGER, trkF(1) AS INTEGER
'----- the vertices as the raster reads them (2026-10-16): x,y (projected,
'----- 1/16 px) and u,v (8.8 texels) interleaved, 4 words a vertex, one segment
DIM SHARED vt(1) AS INTEGER
'----- the rasteriser's thresholds, 1/16 px: a face smaller than C3DFLAT both
'----- ways is filled flat with one texel (no gradients, no divides); a quad's
'----- second triangle shorter than C3DQUAD shares the first one's gradients
CONST C3DFLAT = 64
CONST C3DQUAD = 384
DIM SHARED fa(1) AS C3dFac
DIM SHARED fband(1) AS INTEGER, ord(1) AS INTEGER, lnk(1) AS INTEGER, bkt(1) AS INTEGER
DIM SHARED bgb(1) AS INTEGER, wkb(1) AS INTEGER
DIM SHARED tb0(1) AS INTEGER, tb1(1) AS INTEGER, tb2(1) AS INTEGER, tb3(1) AS INTEGER
DIM SHARED tb4(1) AS INTEGER, tb5(1) AS INTEGER, tb6(1) AS INTEGER, tb7(1) AS INTEGER
REM $STATIC
DIM SHARED prm(0 TO 63) AS INTEGER, prq(0 TO 31) AS INTEGER, bt(0 TO 7) AS INTEGER
DIM SHARED prr(0 TO 25) AS INTEGER, ymin AS INTEGER, lastd AS INTEGER, bendN AS INTEGER, bendE AS INTEGER
DIM SHARED edit AS INTEGER, eoff AS INTEGER, lastoff AS INTEGER
'----- the engine sweep kept going between the scenes (C3dKeep): on, and its tone
DIM SHARED keepOn AS INTEGER, ktc AS INTEGER
'----- the 3D intro is loaded by IntroCar3DLoad (the startup page, before the
'----- logo) and played by IntroCar3D: what the load found, kept for the play
DIM SHARED c3dReady AS INTEGER, hillOn AS INTEGER, c3dNeed AS LONG, c3dFre0 AS LONG, c3dFre1 AS LONG
'----- the hill scene's numbers kept aside with its tables (C3dHillSave)
DIM SHARED hPX0 AS INTEGER, hPDX AS INTEGER, hPY0 AS INTEGER, hPDY AS INTEGER, hPZ0 AS INTEGER, hPDZ AS INTEGER
DIM SHARED hBendN AS INTEGER, hBendE AS INTEGER, hSPD AS INTEGER
'----- the drive tables' cache, C3DTAB.DAT (C3dTabKey/Load/Save): the floats of
'----- C3dWay, C3dBend and C3dHeadPitch take a 486SX ten seconds, the finished
'----- tables read back a fraction of one. Keyed to the EXE's size, the path
'----- DATA, the scenes' constants and the model, so a new build or path makes
'----- them afresh (and rewrites the file). TABVER: bump it when the table
'----- MATHS changes in a way none of those catch
DIM SHARED tabDirty AS INTEGER, tabKey AS LONG
CONST TABVER = 1
DIM SHARED tk(0 TO 7) AS INTEGER
DIM SHARED wpx(0 TO 15) AS INTEGER, wpy(0 TO 15) AS INTEGER, wpz(0 TO 15) AS INTEGER, wpp(0 TO 15) AS INTEGER
'----- the heading over the drive: the artist's take of 2026-10-14 with the
'----- turn editor, fitted with a knot every TURNK steps (tenths of a degree
'----- from the camera's forward direction, linear between knots): nearly
'----- straight until the bend, then the turn, to 25 deg at the cut (the take's
'----- 21 over-steered a little; the road's own direction there is 30)
CONST TURNK = 50
CONST NKNOT = 8
turnKnots:
DATA 547, 511, 494, 503, 480, 367, 288, 250
'----- the hill drive's track: the count, then per waypoint the screen point of
'----- the car's ground centre (the artist's green guide line on Hill_New
'----- Road2.png, 2026-10-15: from the bottom edge right along the lower leg,
'----- the hairpin at the right, back left along the top to the front door),
'----- its depth (game units) and the road's climb there (tenths of a degree,
'----- nose up). Depth and climb come from the artist's 3DS scene of the road
'----- (ART\Car3d\CarPathScene2.3ds) seen through a camera fitted to the
'----- painting (tools\hillpath.ps1; the scene's own camera does not frame
'----- the painting): the road's centre line at the same fraction of the way,
'----- the depths scaled so the car is 15 px wide at the door; depth and climb
'----- smoothed by a cubic in the way-along (the raw values turned the car in
'----- bursts)
hillWay:
DATA 15
DATA 172,199,468,93, 193,193,481,78, 210,186,506,67, 226,179,541,57, 239,169,586,48, 250,156,648,40, 248,147,691,35, 240,145,733,32
DATA 231,143,785,28, 219,141,863,22, 208,139,945,18, 196,137,1047,13, 185,135,1152,8, 174,132,1271,4, 164,130,1413,0
'----- the hill scene's lightning: flashes in all, the last with the thunder, the
'----- others spread evenly over the drive (2 since 2026-10-15: the artist found
'----- the original's one in five sweeps too many)
CONST HILLFL = 2
'----- the hill car's size, percent of the data's (the data: 15 px wide at the
'----- door): the depths are scaled by the inverse. 75 since 2026-10-15 (the
'----- artist: 25% smaller)
CONST HILLCAR = 75
DIM SHARED nv AS INTEGER, nf AS INTEGER, unlit AS INTEGER, texW AS INTEGER, bands AS INTEGER
DIM SHARED bgseg AS INTEGER, bgo AS INTEGER, wseg AS INTEGER, wko AS INTEGER
DIM SHARED bx1 AS INTEGER, bx2 AS INTEGER, by1 AS INTEGER, by2 AS INTEGER
DIM SHARED ox AS INTEGER, oy AS INTEGER, ox2 AS INTEGER, oy2 AS INTEGER
DIM SHARED ovlTri AS STRING, ovlPrj AS STRING, ovlBop AS STRING, ovlEdge AS STRING, ovlBltm AS STRING
DIM SHARED ovlRot AS STRING, ovlBltf AS STRING
DIM SHARED palb AS STRING, dbg AS INTEGER

'----- StartupOpen / StartupLine / StartupPart: the text-mode startup page
'----- (2026-10-15, the artist: a DOS-style loading page before the logo
'----- instead of a black wait after it): a title bar, then a line per thing
'----- as it is loaded; StartupPart adds to the current line
SUB StartupOpen
	DIM eq AS INTEGER
	SCREEN 0: WIDTH 80: CLS
	COLOR 15, 4
	LOCATE 1, 1: PRINT LEFT$("  DARK VISIONS" + SPACE$(62) + "10th Play 1993-2026" + SPACE$(80), 79);
	COLOR 7, 0
	LOCATE 3, 1
	DEF SEG = 0: eq = PEEK(&H410): DEF SEG
	PRINT "D_Main: startup."
	IF (eq AND 2) <> 0 THEN PRINT "I_CPU: coprocessor present." ELSE PRINT "I_CPU: no coprocessor, software floats."
	PRINT "M_LoadDefaults: DARK.INI read."
	PRINT "I_Fonts: fonts loaded."
END SUB

SUB StartupLine (s AS STRING)
	PRINT s
END SUB

SUB StartupPart (s AS STRING)
	PRINT s;
END SUB

'----- IntroCar3DLoad: the 3D intro's loading, on the startup page: the files,
'----- the model and texture, the hill's tables and track (kept aside), the
'----- road's tables. A second or two on a 486SX. The data stays in the far
'----- heap (lent by the empty shadow / anim caches) through the logo; the
'----- addresses the blobs use are taken at play time. 0 = not available (the
'----- CGA car instead), -1 = ready
FUNCTION IntroCar3DLoad% (f3 AS SINGLE, f10 AS SINGLE, f1 AS SINGLE, f6 AS SINGLE)
	DIM tneed AS LONG, ok AS INTEGER
	IntroCar3DLoad% = 0
	c3dReady = 0
	dbg = VAL(ENVIRON$("C3DDUMP"))
	edit = 0
	IF ENVIRON$("C3DEDIT") <> "" THEN edit = -1
	eoff = 0: lastoff = 0: frameAcc = 0: keepOn = 0: ktc = 50
	sf3 = f3: sf10 = f10: sf1 = f1: sf6 = f6
	CALL C3dMark("start")
	CALL StartupPart("C3D_Init: 3D intro")
	c3dNeed = C3dProbe&
	CALL C3dMark("probe " + STR$(c3dNeed))
	IF c3dNeed = 0 THEN CALL StartupLine(" - files missing, the CGA car instead."): EXIT FUNCTION
	c3dFre0 = FRE(-1)
	IF c3dFre0 < c3dNeed THEN CALL StartupLine(" - needs " + LTRIM$(STR$(c3dNeed \ 1024)) + " KB, " + LTRIM$(STR$(c3dFre0 \ 1024)) + " free: the CGA car instead."): EXIT FUNCTION
	hillOn = FileExists%("HILLROAD.BMP")
	IF texW = 128 THEN CALL C3dLoadOvl("C3DT128.OVL", ovlTri) ELSE CALL C3dLoadOvl("C3DTRI.OVL", ovlTri)
	CALL C3dLoadOvl("C3DPRJ.OVL", ovlPrj)
	CALL C3dLoadOvl("SHADBOP.OVL", ovlBop)
	CALL C3dLoadOvl("C3DEDGE.OVL", ovlEdge)
	CALL C3dLoadOvl("C3DBLTM.OVL", ovlBltm)
	CALL C3dLoadOvl("C3DROT.OVL", ovlRot)
	CALL C3dLoadOvl("C3DBLTF.OVL", ovlBltf)
	IF LEN(ovlTri) < 100 OR LEN(ovlPrj) < 50 OR LEN(ovlBop) < 50 THEN GOTO c3dlfail
	IF LEN(ovlEdge) < 50 OR LEN(ovlBltm) < 50 THEN GOTO c3dlfail
	IF LEN(ovlRot) < 100 OR LEN(ovlBltf) < 50 THEN GOTO c3dlfail
	CALL C3dMark("ovls")
	'----- every allocation now (the tables at their largest); FRE(-1) COMPACTS
	'----- the far heap (arrays move), so the one here comes before anything
	'----- holds an address -- and the play takes its addresses afresh
	CALL C3dAlloc
	CALL C3dMark("alloc")
	IF C3dLoadModel% = 0 THEN GOTO c3dlfail
	CALL C3dMark("model")
	CALL StartupPart(": car model, " + LTRIM$(STR$(nv)) + " vertices")
	c3dFre1 = FRE(-1)
	IF C3dLoadTexture% = 0 THEN GOTO c3dlfail
	CALL C3dMark("texture")
	CALL StartupPart(", texture")
	'----- the hill scene's tables (from the cache, or C3dWay's floats) and its
	'----- track, kept aside by C3dHillSave; then the road's
	tabKey = C3dTabKey&: tabDirty = 0
	IF hillOn THEN
		CALL C3dSceneHill
		ok = 0
		IF edit = 0 THEN ok = C3dTabLoad%(1)
		IF ok = 0 THEN CALL C3dWay: tabDirty = -1
		'----- the track is made to last the drive at the scene's pace (8.313
		'----- notes a retrace), the car waiting at the door through the
		'----- thunder; if the track cannot be that long, the pace follows it
		tneed = (CLNG(BENDS + bendE) * 83130) \ (CLNG(SPD) * 1000) + 1800
		CALL C3dTrack(tneed)
		IF trkLen < tneed THEN
			SPD = ((BENDS + bendE) * 87000) \ (CLNG(trkLen) * 1000)
			IF SPD < 8 THEN SPD = 8
			IF SPD > 24 THEN SPD = 24
		END IF
		CALL C3dHillSave
		CALL C3dMark("hill tables")
		CALL StartupPart(", hill")
	END IF
	CALL C3dSceneRoad
	ok = 0
	IF edit = 0 THEN ok = C3dTabLoad%(0)
	IF ok = 0 THEN CALL C3dBend: tabDirty = -1
	IF tabDirty AND edit = 0 THEN CALL C3dTabSave
	CALL C3dMark("road tables")
	CALL StartupLine(", road.")
	CALL StartupLine("Z_Init: " + LTRIM$(STR$(c3dNeed \ 1024)) + " KB of " + LTRIM$(STR$(c3dFre0 \ 1024)) + " KB free for the car.")
	c3dReady = -1
	IntroCar3DLoad% = -1
	EXIT FUNCTION
c3dlfail:
	CALL C3dFree
	CALL StartupLine(" - a file is missing or wrong, the CGA car instead.")
END FUNCTION

'----- IntroCar3D: the scenes, after IntroCar3DLoad. Returns 0 road only, 3
'----- road + hill (the house scene follows), 1 not available (the CGA car
'----- instead), 2 's' pressed
FUNCTION IntroCar3D% (f3 AS SINGLE, f10 AS SINGLE, f1 AS SINGLE, f6 AS SINGLE, nfr AS SINGLE)
	DIM v AS LONG, xr AS INTEGER, yr AS INTEGER, np AS INTEGER, pref AS INTEGER, res AS INTEGER
	DIM px AS LONG, py AS LONG, pz AS LONG, fh AS INTEGER, ts0 AS INTEGER, b AS INTEGER
	IntroCar3D% = 1
	IF c3dReady = 0 THEN EXIT FUNCTION
	res = 0
	'----- mode 13h, palette black
	pref = 320
	v = VgaOpen&(pref, xr, yr, np)
	IF v = 0 THEN GOTO c3dfail
	CALL C3dPal(0)
	CALL C3dMark("vga")
	'----- the addresses the blobs use, now: the logo ran since the load and
	'----- its palette REDIMs may have moved the far heap's arrays. No FRE(-1)
	'----- from here on
	FOR b = 0 TO bands - 1: bt(b) = C3dBandSeg%(b): NEXT
	FOR b = bands TO 7: bt(b) = bt(bands - 1): NEXT
	CALL C3dPoint
	'----- scene 1: the road (its tables are in place from the load). The
	'----- original: carr.pic black for a second, then the reveal with the car
	'----- at its start; it drives from the first visible frame on
	CALL C3dSceneRoad
	CALL C3dTurn(0)
	CALL C3dMark("turn0")
	IF dbg THEN CALL C3dDbg
	CALL C3dLoadBg(bgFile)
	CALL C3dMark("backdrop")
	ox2 = -1: ts0 = -50
	CALL C3dPath(ts0, px, py, pz)
	CALL C3dDraw(px, py, pz)
	CALL C3dMark("first frame")
	IF C3dHold%(1!) THEN res = 2: GOTO c3dout
	CALL C3dMark("hold done")
	CALL C3dPal(16)
	res = C3dDrive%(0)
	'----- the cut, with the car still rolling: black in the next blank. With
	'----- the hill to come the engine keeps running through the black and on
	'----- into the hill drive's track -- it is the car driving (the artist,
	'----- 2026-10-15): C3dKeep tops the queue up while the backdrop loads.
	'----- Otherwise the last queued notes play out (the original cut to
	'----- hill.pic with the sweep still going)
	CALL C3dPal(0)
	IF res = 2 OR hillOn = 0 THEN
		CALL C3dDrain
	ELSE
		keepOn = -1
		CALL C3dKeep
	END IF
	IF dbg THEN
		fh = FREEFILE
		OPEN "C3D.LOG" FOR APPEND AS #fh
		PRINT #fh, "--- " + DATE$ + " " + TIME$ + " IntroCar3D: heap before"; c3dFre0; " needed"; c3dNeed; " after"; c3dFre1; " strings"; FRE(""); " hill"; hillOn
		CLOSE #fh
		CALL C3dKeep
	END IF
	IF res = 2 THEN GOTO c3dout
	IF hillOn = 0 THEN GOTO c3dout
	'----- scene 2: the drive up the hill to the house, with the hill scene's
	'----- lightning and thunder on the queue (its tables and track from the load)
	CALL C3dSceneHill
	CALL C3dHillLoad
	CALL C3dTurn(0)
	CALL C3dKeep
	IF dbg THEN CALL C3dDbg: CALL C3dKeep
	CALL C3dLoadBg(bgFile)
	ox2 = -1
	CALL C3dPath(ts0, px, py, pz)
	CALL C3dDraw(px, py, pz)
	CALL C3dKeep
	CALL C3dPal(16)
	res = C3dDrive%(1)
	CALL C3dPal(0)
	CALL C3dDrain
	IF res = 0 THEN res = 3
c3dout:
	'----- black, then mode 4 again (Intro BLOADs the next CGA screen over black)
	CALL C3dPal(0)
	CALL VgaClose
	CALL C3dFree
	c3dReady = 0
	nfr = nfr + frameAcc
	IntroCar3D% = res
	EXIT FUNCTION
c3dfail:
	CALL VgaClose
	CALL C3dFree
	c3dReady = 0
END FUNCTION

'----- C3dDrive: the current scene's drive. trk 0 = the engine sweep repeated,
'----- the drive ending at the path's cut; 1 = the scene's track (C3dTrack)
'----- with its lightning, the drive ending with the track (the car waiting at
'----- the path's end if it gets there first). 2 = 's' pressed.
FUNCTION C3dDrive% (trk AS INTEGER)
	DIM ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG, stp AS INTEGER, d AS INTEGER, i AS INTEGER
	DIM qt AS LONG, cons AS LONG, cl AS LONG, du AS LONG, k AS STRING, res AS INTEGER
	DIM fh AS INTEGER, fi AS INTEGER, fl AS INTEGER, done AS INTEGER, tsEnd AS INTEGER, shot AS INTEGER
	DIM frames AS LONG, tk0 AS LONG, tk1 AS LONG, mxdu AS LONG, mndu AS LONG
	DIM adv AS INTEGER, rb AS INTEGER, drw AS INTEGER, lastDrw AS LONG, tkn AS LONG, tkw AS LONG, acc AS LONG
	res = 0
	tsEnd = (BENDS + bendE) * 10
	ts = -50
c3drun:
	PLAY "MB"
	'----- notes still queued (the sweep kept up across the cut) count as the
	'----- drive's own: its clock runs from them
	qt = PLAY(0): cl = 0: cons = 0: frames = 0: mxdu = 0: mndu = 999: trkPos = 0: fi = 0: fl = 0: done = 0: shot = 0: rb = 0: lastDrw = 0: acc = 0
	keepOn = 0
	IF trk = 0 THEN ktc = 50
	tk0 = C3dTicks&: tkw = tk0
	DO
		'----- the queue kept 36 notes ahead: the sweep, or the track
		IF trk = 0 THEN
			DO WHILE PLAY(0) < 36
				SOUND ktc, .06
				SOUND sf3, .06
				qt = qt + 2
				ktc = ktc + 18
				IF ktc > 200 THEN ktc = 50
			LOOP
		ELSE
			DO WHILE PLAY(0) < 36 AND trkPos < trkLen
				IF trkF(trkPos) = 0 THEN SOUND 32676, .06 ELSE SOUND trkF(trkPos), .06
				trkPos = trkPos + 1: qt = qt + 1
			LOOP
		END IF
		k = INKEY$
		IF k = "s" THEN res = 2: EXIT DO
		IF edit AND trk = 0 THEN
			IF k = CHR$(0) + "K" THEN eoff = eoff - 8: IF eoff < -180 THEN eoff = -180
			IF k = CHR$(0) + "M" THEN eoff = eoff + 8: IF eoff > 180 THEN eoff = 180
		END IF
		'----- a drawn frame only every FPSN notes (12 a second); the car is
		'----- rotated to its step then. A machine slower than that draws when
		'----- it can, in phase
		drw = 0
		IF frames = 0 THEN drw = -1
		IF cons - lastDrw >= FPSN THEN drw = -1: lastDrw = cons - ((cons - lastDrw) MOD FPSN)
		IF drw THEN
			IF (edit = 0 OR trk = 1) AND d <> lastd THEN CALL C3dTurn(d)
			CALL C3dPath(ts, px, py, pz)
			CALL C3dDraw(px, py, pz)
			frames = frames + 1
		END IF
		'----- C3DDUMP=2: two frames of the hill drive as BMPs (each stalls it)
		IF dbg > 1 AND trk = 1 THEN
			IF shot = 0 AND ts >= 500 THEN shot = 1: CALL C3dShot("C3DHILL1.BMP")
			IF shot = 1 AND ts >= 1500 THEN shot = 2: CALL C3dShot("C3DHILL2.BMP")
		END IF
		'----- notes played since the last frame (1.717 ms each) -> retraces
		'----- (8.313 notes) -> SPD tenths of a path step each
		cons = qt - PLAY(0)
		du = cons - cl: cl = cons
		'----- a lightning flash when the track reaches one: the blacks white
		'----- for two frames (the CGA version's COLOR 15)
		IF fl > 0 AND drw THEN
			fl = fl - 1
			IF fl = 0 THEN CALL C3dFlash(0)
		END IF
		IF trk = 1 AND fi < nflash THEN
			IF cons >= flashAt(fi) THEN CALL C3dFlash(1): fl = 2: fi = fi + 1
		END IF
		'----- the notes carried over an accumulator: the loop passes many times
		'----- a retrace now, so a pass's fraction must not be rounded away
		acc = acc + du * 1000
		stp = acc \ 8313
		IF stp > 4 THEN stp = 4
		acc = acc - stp * 8313&
		'----- (a LONG multiply: 4 * 8313 overflows an INTEGER, and the step count
		'----- ran away on the 486, whose frames are long enough to reach 4)
		'----- no notes played since the last pass: no advance (the loop spins
		'----- between drawn frames) -- unless the clock has stalled for two
		'----- ticks (the engine restarting): then one step keeps things going
		IF stp < 1 THEN
			tkn = C3dTicks&
			IF tkn - tkw >= 2 THEN stp = 1: tkw = tkn
		ELSE
			tkw = C3dTicks&
		END IF
		IF trk = 1 THEN
			'----- the stop: eased over the last DECELS steps, a tick of roll-back,
			'----- then the thunder (the sweeps still queued are skipped)
			adv = stp * SPD
			'----- braking: the speed falls as the square root of the way left, i.e.
			'----- a steady deceleration that reaches zero (a speed proportional to
			'----- the way left never arrives: the car looked stopped, then crept)
			IF rb = 0 AND stp > 0 AND tsEnd - ts < DECELS * 10 THEN adv = CINT(stp * SPD * SQR((tsEnd - ts) / (DECELS * 10))): IF adv < 1 THEN adv = 1
			IF rb = 0 THEN ts = ts + adv: IF ts >= tsEnd THEN ts = tsEnd: rb = 1
			IF rb >= 1 AND rb <= RBF THEN ts = tsEnd - rb * RBT: IF drw THEN rb = rb + 1
			IF rb = RBF + 1 THEN
				rb = RBF + 2
				IF trkPos < trkThunder THEN
					FOR i = fi TO nflash - 1: flashAt(i) = flashAt(i) - (trkThunder - trkPos): NEXT
					trkPos = trkThunder
				END IF
			END IF
		ELSE
			ts = ts + stp * SPD
			IF ts > tsEnd THEN ts = tsEnd
		END IF
		d = ts \ 10
		IF d < 0 THEN d = 0
		IF d > BENDS + bendE THEN d = BENDS + bendE
		IF edit AND trk = 0 THEN
			FOR i = lastd TO d: toff(i) = eoff: NEXT
			IF d <> lastd OR eoff <> lastoff THEN CALL C3dTurnA(tyaw(d) + eoff * .0043633, d): lastd = d: lastoff = eoff
		END IF
		IF dbg THEN
			IF frames > 1 THEN
				IF du > mxdu THEN mxdu = du
				IF du < mndu THEN mndu = du
			END IF
		END IF
		IF trk = 0 THEN
			IF ts >= tsEnd THEN done = -1
		ELSE
			IF trkPos >= trkLen AND PLAY(0) = 0 THEN done = -1
		END IF
	LOOP UNTIL done
	tk1 = C3dTicks&
	frameAcc = frameAcc + frames
	CALL C3dFlash(0)
	'----- C3DEDIT (the road scene): the recording saved, the engine off, the
	'----- last frame held; R runs (and records) the drive again, Esc, S or
	'----- space goes on (arrows still held at the end, or queued, are ignored)
	IF edit AND trk = 0 AND res = 0 THEN
		CALL C3dSaveTurn
		CALL C3dDrain
		DO
			k = INKEY$
		LOOP UNTIL k = "r" OR k = "R" OR k = CHR$(27) OR k = "s" OR k = "S" OR k = " "
		IF k = "r" OR k = "R" THEN
			CALL C3dCopy(bgseg, CLNG(bgo), &HA000, CLNG(BGY0) * 320, 200 - BGY0, 320, 320, 320)
			ts = -50: eoff = 0: lastoff = 0: ox2 = -1
			CALL C3dTurnA(tyaw(0), 0): lastd = 0
			CALL C3dPath(ts, px, py, pz)
			CALL C3dDraw(px, py, pz)
			GOTO c3drun
		END IF
	END IF
	IF dbg THEN
		fh = FREEFILE
		OPEN "C3D.LOG" FOR APPEND AS #fh
		PRINT #fh, "drive"; trk; ": frames"; frames; " ticks"; tk1 - tk0; " notes played"; cons; " per frame min"; mndu; " max"; mxdu; " steps"; BENDS + bendE; " SPD"; SPD; " track"; trkLen; " flashes"; nflash; " res"; res
		PRINT #fh, "  end: tsEnd"; tsEnd; " ts"; ts; " bendE"; bendE; " BENDS"; BENDS; " done"; done; " key"; LEN(k)
		CLOSE #fh
	END IF
	C3dDrive% = res
END FUNCTION

'----- C3dDrain: the queue played out (half a second at most), then foreground
SUB C3dDrain
	DIM t9 AS SINGLE, d9 AS SINGLE
	t9 = TIMER
	DO WHILE PLAY(0) > 0
		d9 = TIMER - t9
		IF d9 < 0 OR d9 > .5 THEN EXIT DO
	LOOP
	PLAY "MF"
END SUB

'----- C3dKeep: while keepOn, the engine sweep kept 36 notes ahead on the
'----- queue (the road drive's sweep carried on by ktc): called wherever the
'----- cut's work could outlast the queue (62 ms); off once the hill drive
'----- queues its own track
SUB C3dKeep
	IF keepOn = 0 THEN EXIT SUB
	DO WHILE PLAY(0) < 36
		SOUND ktc, .06
		SOUND sf3, .06
		ktc = ktc + 18
		IF ktc > 200 THEN ktc = 50
	LOOP
END SUB

'----- C3dMark: a checkpoint line in C3D.LOG (C3DDUMP set), to see how far the
'----- setup gets on a machine that shows only black
SUB C3dMark (s AS STRING)
	DIM fh AS INTEGER
	'----- (dbg is set by the intro's load; a quickstart run has none, so the
	'----- environment is asked again)
	IF dbg = 0 THEN dbg = VAL(ENVIRON$("C3DDUMP"))
	IF dbg = 0 THEN EXIT SUB
	fh = FREEFILE
	OPEN "C3D.LOG" FOR APPEND AS #fh
	PRINT #fh, "mark " + TIME$ + " t" + LTRIM$(STR$(C3dTicks&)) + " " + s
	CLOSE #fh
END SUB

'----- C3dHillSave: the hill scene's tables (C3dWay's, for its bendN steps)
'----- and numbers put aside while the road scene uses the shared ones
SUB C3dHillSave
	DIM i AS INTEGER
	FOR i = 0 TO bendN
		hpx(i) = tpx(i): hpy(i) = tpy(i): hpz(i) = tpz(i)
		hcs(i) = tcs(i): hsn(i) = tsn(i): hcp(i) = tcp(i): hsp(i) = tsp(i)
	NEXT
	hPX0 = PX0: hPDX = PDX: hPY0 = PY0: hPDY = PDY: hPZ0 = PZ0: hPDZ = PDZ
	hBendN = bendN: hBendE = bendE: hSPD = SPD
END SUB

'----- C3dHillLoad: them back (after C3dSceneHill), the engine kept up
SUB C3dHillLoad
	DIM i AS INTEGER
	bendN = hBendN: bendE = hBendE: SPD = hSPD
	PX0 = hPX0: PDX = hPDX: PY0 = hPY0: PDY = hPDY: PZ0 = hPZ0: PDZ = hPDZ
	FOR i = 0 TO bendN
		tpx(i) = hpx(i): tpy(i) = hpy(i): tpz(i) = hpz(i)
		tcs(i) = hcs(i): tsn(i) = hsn(i): tcp(i) = hcp(i): tsp(i) = hsp(i)
		IF (i AND 31) = 0 THEN CALL C3dKeep
	NEXT
END SUB

'----- C3dSceneRoad: the road drive -- the world line of tools\CAR3D.BAS from
'----- screen (77,154) at depth 420 to depth 740 under the sprite's last x,
'----- the bend up and away at the right, the artist's heading knots
SUB C3dSceneRoad
	PX0 = -2178: PDX = 7219: PY0 = -1418: PDY = 0: PZ0 = 6720: PDZ = 5120
	BENDS = 200: BENDM = 40: BENDX = 308: BENDY = 108: BENDZ = 2200: BENDL = 150
	SPD = 17: PITCHE = 100: PITCHS = 200: HEADM = 0: PACEX = 2
	bgFile = "CARROAD.BMP"
END SUB

'----- C3dSceneHill: the drive over the artist's hill picture (HILLROAD.BMP)
'----- along the hillWay track to the front door, where the house scene then
'----- shows the car parked: no straight run (C3dWay sets the lead-in from the
'----- track's first leg), the heading from the path itself, the pitch the
'----- road's climb at each waypoint (PITCHE is added to it, tenths of a
'----- degree), one speed along the path in the world (PACEX unused); the pace
'----- SPD (tenths of a step a retrace; 8 = half the 2026-10-15 morning's, the
'----- drive 4.5 s) sets how long the track is made
SUB C3dSceneHill
	PX0 = 0: PDX = 0: PY0 = -1418: PDY = 0: PZ0 = 5120: PDZ = 0
	'----- BENDL: the drive stops that many steps along the path's 250 -- 195 =
	'----- a second short of the door at this pace (the artist, 2026-10-15: not
	'----- as far down the road); the track is made to last just that
	BENDS = 0: BENDM = 0: BENDX = 0: BENDY = 0: BENDZ = 0: BENDL = 195
	SPD = 8: PITCHE = 0: PITCHS = 0: HEADM = 1: PACEX = 1
	bgFile = "HILLROAD.BMP"
END SUB

'----- C3dTrack: the hill scene's soundtrack as the original played it (GAME.BAS
'----- Intro 17180-17510), a frequency per 1.717 ms unit (0 = silence): the
'----- engine sweeps (the original's 35; here as many as cover need units
'----- together with the rest, at most 2200 units of them) with HILLFL - 1
'----- lightning flashes (two silent units each) spread evenly among them, the
'----- descending thunder (tc and f10 a tenth of a tick each = 3 units, a
'----- tick's silence = 32), a flash, the second descending tone (tc a tenth,
'----- f1 two tenths) and f6 -- those last 665 units, 1.1 s
SUB C3dTrack (need AS LONG)
	DIM i AS INTEGER, j AS INTEGER, tc AS INTEGER, n AS INTEGER, lim AS LONG, nsw AS INTEGER
	n = 0: nflash = 0
	lim = need - 665
	IF lim > 2200 THEN lim = 2200
	nsw = lim \ 18
	IF nsw < 1 THEN nsw = 1
	FOR i = 1 TO nsw
		tc = 50
		DO
			trkF(n) = tc: trkF(n + 1) = CINT(sf3): n = n + 2
			tc = tc + 18
		LOOP WHILE tc <= 200
		IF nflash < HILLFL - 1 THEN
			IF i = ((nflash + 1) * nsw) \ HILLFL THEN flashAt(nflash) = n: nflash = nflash + 1: trkF(n) = 0: trkF(n + 1) = 0: n = n + 2
		END IF
	NEXT
	trkThunder = n
	tc = 200
	DO
		FOR j = 1 TO 3: trkF(n) = tc: n = n + 1: NEXT
		FOR j = 1 TO 3: trkF(n) = CINT(sf10): n = n + 1: NEXT
		FOR j = 1 TO 32: trkF(n) = 0: n = n + 1: NEXT
		tc = tc - 10
	LOOP WHILE tc >= 50
	IF nflash < 30 THEN flashAt(nflash) = n: nflash = nflash + 1
	tc = 200
	DO
		FOR j = 1 TO 3: trkF(n) = tc: n = n + 1: NEXT
		FOR j = 1 TO 6: trkF(n) = CINT(sf1): n = n + 1: NEXT
		tc = tc - 30
	LOOP WHILE tc >= 50
	FOR j = 1 TO 3: trkF(n) = CINT(sf6): n = n + 1: NEXT
	trkLen = n
END SUB

'----- C3dTabKey: what the cached tables depend on, folded into one number:
'----- TABVER, the model's lowest point (ymin), the hill waypoints and the
'----- heading knots (DATA), both scenes' constants, the table CONSTs, the
'----- EXE's size (any rebuild starts the cache afresh) and a recorded turn
'----- (C3DTURN.DAT) if there is one
FUNCTION C3dTabKey&
	DIM k AS LONG, i AS INTEGER, n AS INTEGER, v AS INTEGER, fh AS INTEGER, s AS STRING
	k = TABVER
	k = (k * 31 + ymin) MOD 1000003
	RESTORE hillWay
	READ n
	k = (k * 31 + n) MOD 1000003
	IF n > 16 THEN n = 16
	FOR i = 1 TO n * 4: READ v: k = (k * 31 + v) MOD 1000003: NEXT
	RESTORE turnKnots
	FOR i = 1 TO NKNOT: READ v: k = (k * 31 + v) MOD 1000003: NEXT
	FOR i = 0 TO 1
		IF i = 0 THEN CALL C3dSceneHill ELSE CALL C3dSceneRoad
		k = (k * 31 + PX0) MOD 1000003: k = (k * 31 + PDX) MOD 1000003: k = (k * 31 + PY0) MOD 1000003
		k = (k * 31 + PDY) MOD 1000003: k = (k * 31 + PZ0) MOD 1000003: k = (k * 31 + PDZ) MOD 1000003
		k = (k * 31 + BENDS) MOD 1000003: k = (k * 31 + BENDM) MOD 1000003: k = (k * 31 + BENDX) MOD 1000003
		k = (k * 31 + BENDY) MOD 1000003: k = (k * 31 + BENDZ) MOD 1000003: k = (k * 31 + BENDL) MOD 1000003
		k = (k * 31 + SPD) MOD 1000003: k = (k * 31 + PITCHE) MOD 1000003: k = (k * 31 + PITCHS) MOD 1000003
		k = (k * 31 + HEADM) MOD 1000003: k = (k * 31 + PACEX) MOD 1000003
	NEXT
	k = (k * 31 + HILLCAR) MOD 1000003: k = (k * 31 + HEADW) MOD 1000003: k = (k * 31 + BENDNS) MOD 1000003
	k = (k * 31 + BENDMAX) MOD 1000003: k = (k * 31 + TMAX) MOD 1000003: k = (k * 31 + TURNK) MOD 1000003
	IF FileExists%("GAME.EXE") THEN
		fh = FREEFILE
		OPEN "GAME.EXE" FOR BINARY AS #fh
		k = (k * 31 + LOF(fh) MOD 65521) MOD 1000003
		CLOSE #fh
	END IF
	IF FileExists%("C3DTURN.DAT") THEN
		fh = FREEFILE
		OPEN "C3DTURN.DAT" FOR BINARY AS #fh
		k = (k * 31 + LOF(fh) MOD 65521) MOD 1000003
		IF LOF(fh) > 0 AND LOF(fh) < 16000 THEN
			s = SPACE$(LOF(fh))
			GET #fh, 1, s
			FOR i = 1 TO LEN(s) - 1 STEP 2: k = (k * 31 + CVI(MID$(s, i, 2))) MOD 1000003: NEXT
		END IF
		CLOSE #fh
	END IF
	C3dTabKey& = k
END FUNCTION

'----- C3dTabLoad: the scene's finished tables from C3DTAB.DAT into tpx..tsp,
'----- bendN, bendE and PX0.. (blk 1 = the hill's block, 0 = the road's, after
'----- that scene's constants are set); 0 = no cache, or not this build's.
'----- Layout: "C3T1", key&, the road block's position&, hill flag%, the hill
'----- block, the road block; a block = n1%, n2%, bendN%, bendE%, PX0..PDZ (6
'----- ints), n1 longs each of tpx, tpy, tpz, n2 ints each of tcs, tsn, tcp, tsp
FUNCTION C3dTabLoad% (blk AS INTEGER)
	DIM fh AS INTEGER, tag AS STRING, k AS LONG, ro AS LONG, hf AS INTEGER, n1 AS INTEGER, n2 AS INTEGER
	C3dTabLoad% = 0
	IF FileExists%("C3DTAB.DAT") = 0 THEN EXIT FUNCTION
	fh = FREEFILE
	OPEN "C3DTAB.DAT" FOR BINARY AS #fh
	IF LOF(fh) < 34 THEN CLOSE #fh: EXIT FUNCTION
	tag = SPACE$(4)
	GET #fh, 1, tag
	GET #fh, , k
	GET #fh, , ro
	GET #fh, , hf
	IF tag <> "C3T1" OR k <> tabKey THEN CLOSE #fh: EXIT FUNCTION
	IF blk = 1 THEN
		IF hf = 0 THEN CLOSE #fh: EXIT FUNCTION
	ELSE
		IF ro < 15 OR ro > LOF(fh) THEN CLOSE #fh: EXIT FUNCTION
		SEEK #fh, ro
	END IF
	GET #fh, , n1
	GET #fh, , n2
	IF n1 < 2 OR n1 > BENDMAX + 1 OR n2 < 2 OR n2 > TMAX + 1 THEN CLOSE #fh: EXIT FUNCTION
	IF SEEK(fh) + 15 + CLNG(n1) * 12 + CLNG(n2) * 8 > LOF(fh) THEN CLOSE #fh: EXIT FUNCTION
	GET #fh, , bendN: GET #fh, , bendE
	GET #fh, , PX0: GET #fh, , PDX: GET #fh, , PY0: GET #fh, , PDY: GET #fh, , PZ0: GET #fh, , PDZ
	IF bendN <> n1 - 1 OR BENDS + bendE <> n2 - 1 THEN CLOSE #fh: EXIT FUNCTION
	CALL BinGetL(fh, tpx(), n1): CALL BinGetL(fh, tpy(), n1): CALL BinGetL(fh, tpz(), n1)
	CALL BinGetI(fh, tcs(), n2): CALL BinGetI(fh, tsn(), n2): CALL BinGetI(fh, tcp(), n2): CALL BinGetI(fh, tsp(), n2)
	CLOSE #fh
	C3dTabLoad% = -1
END FUNCTION

'----- C3dTabSave: C3DTAB.DAT written afresh -- the hill's block from the h*
'----- copies (C3dHillSave), the road's from tpx..tsp (the road scene current)
SUB C3dTabSave
	DIM fh AS INTEGER, tag AS STRING, ro AS LONG, hf AS INTEGER, n1 AS INTEGER, n2 AS INTEGER
	IF FileExists%("C3DTAB.DAT") THEN KILL "C3DTAB.DAT"
	fh = FREEFILE
	OPEN "C3DTAB.DAT" FOR BINARY AS #fh
	tag = "C3T1": PUT #fh, 1, tag
	PUT #fh, , tabKey
	ro = 0: PUT #fh, , ro
	hf = 0: IF hillOn THEN hf = 1
	PUT #fh, , hf
	IF hf THEN
		n1 = hBendN + 1: n2 = hBendE + 1
		PUT #fh, , n1: PUT #fh, , n2
		PUT #fh, , hBendN: PUT #fh, , hBendE
		PUT #fh, , hPX0: PUT #fh, , hPDX: PUT #fh, , hPY0: PUT #fh, , hPDY: PUT #fh, , hPZ0: PUT #fh, , hPDZ
		CALL BinPutL(fh, hpx(), n1): CALL BinPutL(fh, hpy(), n1): CALL BinPutL(fh, hpz(), n1)
		CALL BinPutI(fh, hcs(), n2): CALL BinPutI(fh, hsn(), n2): CALL BinPutI(fh, hcp(), n2): CALL BinPutI(fh, hsp(), n2)
	END IF
	ro = SEEK(fh)
	n1 = bendN + 1: n2 = BENDS + bendE + 1
	PUT #fh, , n1: PUT #fh, , n2
	PUT #fh, , bendN: PUT #fh, , bendE
	PUT #fh, , PX0: PUT #fh, , PDX: PUT #fh, , PY0: PUT #fh, , PDY: PUT #fh, , PZ0: PUT #fh, , PDZ
	CALL BinPutL(fh, tpx(), n1): CALL BinPutL(fh, tpy(), n1): CALL BinPutL(fh, tpz(), n1)
	CALL BinPutI(fh, tcs(), n2): CALL BinPutI(fh, tsn(), n2): CALL BinPutI(fh, tcp(), n2): CALL BinPutI(fh, tsp(), n2)
	PUT #fh, 9, ro
	CLOSE #fh
END SUB

'----- C3dFlash: the backdrop's black palette slots white (on) or back
SUB C3dFlash (lit AS INTEGER)
	DIM i AS INTEGER, p AS INTEGER
	FOR i = 0 TO nblk - 1
		OUT &H3C8, blk(i)
		IF lit THEN
			OUT &H3C9, 63: OUT &H3C9, 63: OUT &H3C9, 63
		ELSE
			p = blk(i) * 4
			OUT &H3C9, ASC(MID$(palb, p + 3, 1)) \ 4
			OUT &H3C9, ASC(MID$(palb, p + 2, 1)) \ 4
			OUT &H3C9, ASC(MID$(palb, p + 1, 1)) \ 4
		END IF
	NEXT
END SUB

'----- C3dAlloc: the buffers and tables, once, at their largest
SUB C3dAlloc
	REDIM bgb(0 TO (200 - BGY0) * 160 - 1) AS INTEGER
	REDIM wkb(0 TO (WKW * WKH) \ 2 - 1) AS INTEGER
	REDIM qx(0 TO BENDNS) AS SINGLE, qy(0 TO BENDNS) AS SINGLE, qa(0 TO BENDNS) AS SINGLE, qp(0 TO BENDNS) AS SINGLE
	REDIM tpx(0 TO BENDMAX) AS LONG, tpy(0 TO BENDMAX) AS LONG, tpz(0 TO BENDMAX) AS LONG, tpit(0 TO BENDMAX) AS INTEGER
	REDIM tyaw(0 TO TMAX) AS SINGLE, toff(0 TO TMAX) AS INTEGER, tcs(0 TO TMAX) AS INTEGER, tsn(0 TO TMAX) AS INTEGER
	REDIM tcp(0 TO TMAX) AS INTEGER, tsp(0 TO TMAX) AS INTEGER
	REDIM hpx(0 TO BENDMAX) AS LONG, hpy(0 TO BENDMAX) AS LONG, hpz(0 TO BENDMAX) AS LONG
	REDIM hcs(0 TO BENDMAX) AS INTEGER, hsn(0 TO BENDMAX) AS INTEGER, hcp(0 TO BENDMAX) AS INTEGER, hsp(0 TO BENDMAX) AS INTEGER
	REDIM trkF(0 TO 2999) AS INTEGER
END SUB

'----- C3dProbe: the files' headers -> texW, bands, nv, nf and the heap the
'----- scene needs; 0 = something is missing or wrong (BINARY open creates a
'----- missing file, so existence is checked first)
FUNCTION C3dProbe&
	DIM fh AS INTEGER, s AS STRING, w AS INTEGER, h AS INTEGER, hd AS C3dHdr, need AS LONG
	C3dProbe& = 0
	IF FileExists%("CAR3D.MDL") = 0 THEN EXIT FUNCTION
	IF FileExists%("CAR3D.BMP") = 0 THEN EXIT FUNCTION
	IF FileExists%("CARROAD.BMP") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DPRJ.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("SHADBOP.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DEDGE.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DBLTM.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DROT.OVL") = 0 THEN EXIT FUNCTION
	IF FileExists%("C3DBLTF.OVL") = 0 THEN EXIT FUNCTION
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 THEN CLOSE #fh: EXIT FUNCTION
	s = SPACE$(4)
	GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	GET #fh, 23, s: h = CVI(LEFT$(s, 2))
	CLOSE #fh
	IF w <> 64 AND w <> 128 THEN EXIT FUNCTION
	IF h < w OR h > w * 8 OR (h \ w) * w <> h THEN EXIT FUNCTION
	texW = w: bands = h \ w
	IF texW = 128 THEN
		IF FileExists%("C3DT128.OVL") = 0 THEN EXIT FUNCTION
	ELSE
		IF FileExists%("C3DTRI.OVL") = 0 THEN EXIT FUNCTION
	END IF
	OPEN "CARROAD.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 + 64000 THEN CLOSE #fh: EXIT FUNCTION
	CLOSE #fh
	OPEN "CAR3D.MDL" FOR BINARY AS #fh
	IF LOF(fh) < 10 THEN CLOSE #fh: EXIT FUNCTION
	GET #fh, , hd
	CLOSE #fh
	IF hd.magic <> "C3D2" THEN EXIT FUNCTION
	IF hd.nv < 3 OR hd.nf < 1 OR hd.nv > 2000 OR hd.nf > 2000 THEN EXIT FUNCTION
	'----- strip + work buffer + texture bands + model (14 bytes a vertex and
	'----- a face, the sort's lists) + the descriptors and slack
	need = CLNG(200 - BGY0) * 320 + CLNG(WKW) * WKH
	need = need + CLNG(bands) * (CLNG(w) * w + 32)
	need = need + CLNG(hd.nv) * 20 + CLNG(hd.nf) * 18 + 512 + CLNG(BENDMAX + 1) * 34 + CLNG(TMAX + 1) * 14 + CLNG(BENDNS + 1) * 16 + 6000 + 800 + 6000
	C3dProbe& = need
END FUNCTION

'----- C3dLoadModel: CAR3D.MDL (tools\car3dcnv.ps1: floats) -> the vertices
'----- rotated to the drive's heading in x16 units, texels in 8.8, the faces,
'----- their lighting band (a lit BMP) and the far-to-near order
FUNCTION C3dLoadModel%
	DIM fh AS INTEGER, i AS INTEGER, f AS INTEGER, bk AS INTEGER, n AS INTEGER, d AS INTEGER
	DIM h AS C3dHdr, vt AS C3dVtx, nm AS C3dNrm, t AS LONG, yaw AS SINGLE
	DIM cs AS INTEGER, sn AS INTEGER, x AS INTEGER, y AS INTEGER, z AS INTEGER
	DIM nxr AS INTEGER, nzr AS INTEGER, sh AS INTEGER, band AS INTEGER
	DIM nxi AS INTEGER, nyi AS INTEGER, nzi AS INTEGER
	C3dLoadModel% = 0
	fh = FREEFILE
	OPEN "CAR3D.MDL" FOR BINARY AS #fh
	GET #fh, , h
	IF h.magic <> "C3D2" THEN CLOSE #fh: EXIT FUNCTION
	nv = h.nv: nf = h.nf: unlit = h.flags AND 1
	IF nv < 3 OR nf < 1 OR nv > 2000 OR nf > 2000 THEN CLOSE #fh: EXIT FUNCTION
	IF LOF(fh) < 10 + CLNG(nv) * 20 + CLNG(nf) * 22 THEN CLOSE #fh: EXIT FUNCTION
	REDIM mx(0 TO nv - 1) AS INTEGER, my(0 TO nv - 1) AS INTEGER, mz(0 TO nv - 1) AS INTEGER
	REDIM rx(0 TO nv - 1) AS INTEGER, ry(0 TO nv - 1) AS INTEGER, rz(0 TO nv - 1) AS INTEGER
	REDIM vt(0 TO nv * 4 - 1) AS INTEGER
	REDIM fa(0 TO nf - 1) AS C3dFac
	REDIM fband(0 TO nf - 1) AS INTEGER, ord(0 TO nf - 1) AS INTEGER
	REDIM lnk(0 TO nf - 1) AS INTEGER, bkt(0 TO 255) AS INTEGER
	'----- the heading of the straight run (for a lit model's bands; the
	'----- vertices themselves are rotated by C3DROT, per frame in the bend).
	'----- The scene's numbers are not set yet here (0/0): ATN of that is a
	'----- NaN an FPU never minds, but the FPU-less runtime of a 486SX never
	'----- returns from it (the black-screen hang of 2026-10-15); a lit model
	'----- would need C3dSceneRoad first
	yaw = 0
	IF PDZ <> 0 THEN yaw = ATN(PDX / PDZ)
	ymin = 32767
	cs = CINT(COS(yaw) * 256): sn = CINT(SIN(yaw) * 256)
	FOR i = 0 TO nv - 1
		GET #fh, , vt
		x = CINT(vt.x * 16): y = CINT(vt.y * 16): z = CINT(vt.z * 16)
		mx(i) = x: my(i) = y: mz(i) = z
		IF y < ymin THEN ymin = y
		'----- texel coordinates, 8.8 fixed point over the texture's width
		t = CLNG(vt.u * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		vt(i * 4 + 2) = t
		t = CLNG(vt.v * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		vt(i * 4 + 3) = t
	NEXT
	FOR f = 0 TO nf - 1
		GET #fh, , fa(f)
		IF fa(f).a < 0 OR fa(f).a >= nv OR fa(f).b < 0 OR fa(f).b >= nv OR fa(f).c < 0 OR fa(f).c >= nv OR fa(f).d >= nv THEN CLOSE #fh: EXIT FUNCTION
	NEXT
	FOR f = 0 TO nf - 1
		GET #fh, , nm
		IF unlit OR bands < 2 THEN
			fband(f) = 0
		ELSE
			nxi = CINT(nm.x * 256): nyi = CINT(nm.y * 256): nzi = CINT(nm.z * 256)
			nxr = (CLNG(nxi) * cs + CLNG(nzi) * sn) \ 256
			nzr = (CLNG(nzi) * cs - CLNG(nxi) * sn) \ 256
			sh = (CLNG(nxr) * LX + CLNG(nyi) * LY + CLNG(nzr) * LZ) \ 256
			'----- band 0..7 = 3 + 4.5 * cos(angle to the light)
			band = (768 + (CLNG(sh) * 9) \ 2) \ 256
			IF band < 0 THEN band = 0
			IF band > bands - 1 THEN band = bands - 1
			fband(f) = band
		END IF
	NEXT
	CLOSE #fh
	C3dLoadModel% = -1
END FUNCTION

'----- C3dLoadTexture: the palette (BGRA x 256) and the pixels of CAR3D.BMP
'----- (texW wide, texW*bands rows, bottom-up) -> one 16-byte-aligned array
'----- per lighting band, its segment in bt(b): band b's texel row y sits at
'----- that segment, offset y*texW
FUNCTION C3dLoadTexture%
	DIM fh AS INTEGER, r AS INTEGER, h AS INTEGER, w AS INTEGER, b AS INTEGER, y AS INTEGER, s AS STRING
	C3dLoadTexture% = 0
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	s = SPACE$(4)
	GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	GET #fh, 23, s: h = CVI(LEFT$(s, 2))
	IF w <> texW OR h <> bands * w THEN CLOSE #fh: EXIT FUNCTION
	IF LOF(fh) < 1078 + CLNG(w) * h THEN CLOSE #fh: EXIT FUNCTION
	SEEK #fh, 55
	palb = INPUT$(1024, #fh)
	'----- the backdrops' black-ish slots (the lightning whites them)
	nblk = 0
	FOR b = 0 TO 15
		IF ASC(MID$(palb, b * 4 + 1, 1)) + ASC(MID$(palb, b * 4 + 2, 1)) + ASC(MID$(palb, b * 4 + 3, 1)) < 24 THEN blk(nblk) = b: nblk = nblk + 1
	NEXT
	FOR b = 0 TO bands - 1: CALL C3dBand(b, w): NEXT
	FOR b = 0 TO bands - 1: bt(b) = C3dBandSeg%(b): NEXT
	FOR b = bands TO 7: bt(b) = bt(bands - 1): NEXT
	s = SPACE$(w)
	SEEK #fh, 1079
	FOR r = 0 TO h - 1
		GET #fh, , s
		y = h - 1 - r
		b = y \ w
		CALL C3dCopy(VARSEG(s), CLNG(SADD(s)), bt(b), CLNG(y - b * w) * w, 1, w, w, w)
	NEXT
	CLOSE #fh
	C3dLoadTexture% = -1
END FUNCTION

'----- C3dBand: band b's array, w*w bytes plus 16 for the alignment
SUB C3dBand (b AS INTEGER, w AS INTEGER)
	DIM n AS INTEGER
	n = (CLNG(w) * w + 16) \ 2
	SELECT CASE b
	CASE 0: REDIM tb0(0 TO n) AS INTEGER
	CASE 1: REDIM tb1(0 TO n) AS INTEGER
	CASE 2: REDIM tb2(0 TO n) AS INTEGER
	CASE 3: REDIM tb3(0 TO n) AS INTEGER
	CASE 4: REDIM tb4(0 TO n) AS INTEGER
	CASE 5: REDIM tb5(0 TO n) AS INTEGER
	CASE 6: REDIM tb6(0 TO n) AS INTEGER
	CASE 7: REDIM tb7(0 TO n) AS INTEGER
	END SELECT
END SUB

'----- C3dBandSeg: the segment at which band b's data starts at offset 0
FUNCTION C3dBandSeg% (b AS INTEGER)
	DIM tp AS INTEGER, sg AS INTEGER
	SELECT CASE b
	CASE 0: tp = VARPTR(tb0(0)): sg = VARSEG(tb0(0))
	CASE 1: tp = VARPTR(tb1(0)): sg = VARSEG(tb1(0))
	CASE 2: tp = VARPTR(tb2(0)): sg = VARSEG(tb2(0))
	CASE 3: tp = VARPTR(tb3(0)): sg = VARSEG(tb3(0))
	CASE 4: tp = VARPTR(tb4(0)): sg = VARSEG(tb4(0))
	CASE 5: tp = VARPTR(tb5(0)): sg = VARSEG(tb5(0))
	CASE 6: tp = VARPTR(tb6(0)): sg = VARSEG(tb6(0))
	CASE 7: tp = VARPTR(tb7(0)): sg = VARSEG(tb7(0))
	END SELECT
	C3dBandSeg% = C3dSeg%(sg, tp + ((16 - (tp AND 15)) AND 15))
END FUNCTION

'----- C3dLoadBg: a backdrop BMP (320x200, bottom-up, palette slots 0..15, bit
'----- 7 = in front of the car) -> VRAM whole, rows BGY0..199 into the strip
'----- the frames restore from
SUB C3dLoadBg (fil AS STRING)
	DIM fh AS INTEGER, y AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN fil FOR BINARY AS #fh
	IF LOF(fh) < 1078 + 64000 THEN CLOSE #fh: EXIT SUB
	s = SPACE$(320)
	SEEK #fh, 1079
	FOR y = 199 TO 0 STEP -1
		IF (y AND 15) = 0 THEN CALL C3dKeep
		GET #fh, , s
		CALL C3dCopy(VARSEG(s), CLNG(SADD(s)), &HA000, CLNG(y) * 320, 1, 320, 320, 320)
		IF y >= BGY0 THEN CALL C3dCopy(VARSEG(s), CLNG(SADD(s)), bgseg, CLNG(bgo) + CLNG(y - BGY0) * 320, 1, 320, 320, 320)
	NEXT
	CLOSE #fh
END SUB

'----- C3dPoint: the buffers' addresses for the routines (after the last
'----- allocation: the far heap may move arrays)
SUB C3dPoint
	bgseg = C3dSeg%(VARSEG(bgb(0)), VARPTR(bgb(0))): bgo = VARPTR(bgb(0)) AND 15
	wseg = C3dSeg%(VARSEG(wkb(0)), VARPTR(wkb(0))): wko = VARPTR(wkb(0)) AND 15
	prm(0) = wseg: prm(1) = wko: prm(2) = WKW: prm(3) = WKH
	prm(4) = VARSEG(bt(0)): prm(23) = VARPTR(bt(0))
	prm(5) = VARSEG(vt(0)): prm(6) = VARPTR(vt(0))      ' the interleaved vertices (bit 15 of word 25)
	prm(7) = 0: prm(8) = 0: prm(9) = 0: prm(10) = 0: prm(11) = 0: prm(12) = 0
	prm(13) = VARSEG(fa(0)): prm(14) = VARPTR(fa(0))
	prm(15) = VARSEG(fband(0)): prm(16) = VARPTR(fband(0))
	IF unlit THEN prm(15) = 0                            ' every face band 0: the texture segment read once
	prm(17) = VARSEG(ord(0)): prm(18) = VARPTR(ord(0))
	prm(19) = nf
	prq(0) = VARSEG(rx(0)): prq(1) = VARPTR(rx(0))
	prq(2) = VARSEG(ry(0)): prq(3) = VARPTR(ry(0))
	prq(4) = VARSEG(rz(0)): prq(5) = VARPTR(rz(0))
	prq(6) = VARSEG(vt(0)): prq(7) = VARPTR(vt(0))
	prq(8) = prq(6): prq(9) = prq(7) + 2
	prq(21) = 8                                           ' the projection writes x,y 8 bytes apart
	prq(10) = nv
	prr(0) = VARSEG(mx(0)): prr(1) = VARPTR(mx(0))
	prr(2) = VARSEG(my(0)): prr(3) = VARPTR(my(0))
	prr(4) = VARSEG(mz(0)): prr(5) = VARPTR(mz(0))
	prr(6) = VARSEG(rx(0)): prr(7) = VARPTR(rx(0))
	prr(8) = VARSEG(ry(0)): prr(9) = VARPTR(ry(0))
	prr(10) = VARSEG(rz(0)): prr(11) = VARPTR(rz(0))
	prr(12) = nv
	prr(15) = VARSEG(fa(0)): prr(16) = VARPTR(fa(0))
	prr(17) = VARSEG(ord(0)): prr(18) = VARPTR(ord(0))
	prr(19) = nf
	prr(20) = VARSEG(lnk(0)): prr(21) = VARPTR(lnk(0))
	prr(22) = VARSEG(bkt(0)): prr(23) = VARPTR(bkt(0))
	prr(24) = 256: prr(25) = 0
END SUB

'----- C3dPath: world position (x16 units) at ts tenths of a step (of 200)
'----- along the drive
SUB C3dPath (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG)
	DIM d AS INTEGER, i AS INTEGER, f AS INTEGER
	IF ts <= BENDS * 10 THEN
		'----- (a waypoint path: PX0.. are its first point and leg, so this is
		'----- the lead-in before it)
		px = PX0 + (CLNG(ts) * PDX) \ 2000
		py = PY0 + (CLNG(ts) * PDY) \ 2000
		pz = PZ0 + (CLNG(ts) * PDZ) \ 2000
	ELSE
		'----- the bend: between the table's steps
		d = ts - BENDS * 10
		i = d \ 10: f = d MOD 10
		IF i >= bendN THEN i = bendN - 1: f = 10
		px = tpx(i) + ((tpx(i + 1) - tpx(i)) * f) \ 10
		py = tpy(i) + ((tpy(i + 1) - tpy(i)) * f) \ 10
		pz = tpz(i) + ((tpz(i + 1) - tpz(i)) * f) \ 10
	END IF
END SUB

'----- C3dBend: the bend's position table (the car's centre, x16 units, per
'----- step of the bend) and the heading table (cos/sin x256 per step of the
'----- WHOLE drive). Floats, once, at load (about 0.4 s on a 486SX).
SUB C3dBend
	DIM i AS INTEGER, d AS INTEGER, j AS INTEGER, x0 AS SINGLE, z0 AS SINGLE, yw AS SINGLE
	DIM sx0 AS SINGLE, sy0 AS SINGLE, sxd AS SINGLE, syd AS SINGLE, v0 AS SINGLE
	DIM p1x AS SINGLE, p1y AS SINGLE, t AS SINGLE, u AS SINGLE, atot AS SINGLE, acur AS SINGLE
	DIM fr AS SINGLE, z AS SINGLE, sx AS SINGLE, sy AS SINGLE, x AS SINGLE, yc AS SINGLE, z1 AS SINGLE, kz AS SINGLE
	DIM k AS INTEGER, v AS INTEGER, fk AS INTEGER, i1 AS INTEGER, i2 AS INTEGER, dx AS SINGLE, dz AS SINGLE
	'----- the straight run's end (PDX, PDZ are per 200 steps): the wheel line's
	'----- screen point and velocity there
	x0 = (PX0 + PDX * (BENDS / 200)) / 16: z0 = (PZ0 + PDZ * (BENDS / 200)) / 16
	yw = PY0 / 16 + ymin / 16
	sx0 = 160 + 256 * x0 / z0: sy0 = 100 - 256 * yw / z0
	sxd = 256 * ((PDX / 3200) * z0 - x0 * (PDZ / 3200)) / (z0 * z0)
	syd = 256 * yw * (PDZ / 3200) / (z0 * z0)
	v0 = SQR(sxd * sxd + syd * syd)
	'----- the curve: a quadratic Bezier leaving along that velocity, sampled,
	'----- with the screen distance along it
	p1x = sx0 + sxd * BENDM: p1y = sy0 + syd * BENDM
	qa(0) = 0
	FOR i = 0 TO BENDNS
		t = i / BENDNS: u = 1 - t
		qx(i) = u * u * sx0 + 2 * u * t * p1x + t * t * BENDX
		qy(i) = u * u * sy0 + 2 * u * t * p1y + t * t * BENDY
		IF i > 0 THEN qa(i) = qa(i - 1) + SQR((qx(i) - qx(i - 1)) ^ 2 + (qy(i) - qy(i - 1)) ^ 2)
	NEXT
	atot = qa(BENDNS)
	'----- the depth along the curve: z1 units per screen pixel at the join
	'----- (the straight run's rate), rising to reach BENDZ at the curve's end
	z1 = (PDZ / 3200) / v0
	kz = (BENDZ - z0 - z1 * atot) / (atot * atot)
	'----- the steps: the screen speed is v0 at the join and falls with the
	'----- square of the depth, as perspective does on the straight run
	acur = 0: j = 0: bendN = 0
	FOR d = 0 TO BENDMAX
		DO WHILE j < BENDNS - 1
			IF qa(j + 1) >= acur THEN EXIT DO
			j = j + 1
		LOOP
		fr = 0
		IF qa(j + 1) > qa(j) THEN fr = (acur - qa(j)) / (qa(j + 1) - qa(j))
		IF fr > 1 THEN fr = 1
		sx = qx(j) + (qx(j + 1) - qx(j)) * fr: sy = qy(j) + (qy(j + 1) - qy(j)) * fr
		z = z0 + z1 * acur + kz * acur * acur
		x = (sx - 160) * z / 256
		yc = (100 - sy) * z / 256 - ymin / 16
		tpx(d) = CLNG(x * 16): tpy(d) = CLNG(yc * 16): tpz(d) = CLNG(z * 16)
		bendN = d
		IF acur >= atot THEN EXIT FOR
		IF PACEX = 2 THEN acur = acur + v0 * (z0 / z) * (z0 / z) ELSE acur = acur + v0 * (z0 / z)
		IF acur > atot THEN acur = atot
	NEXT
	'----- the cut: BENDL steps into the bend, or the curve's end if sooner
	bendE = BENDL
	IF bendE > bendN THEN bendE = bendN
	IF bendE < 2 THEN bendE = 2
	CALL C3dHeadPitch
END SUB

'----- C3dHeadPitch: the heading table -- the scene's knots (the artist's take)
'----- plus a recorded turn if any, or the path's own direction (smoothed over
'----- two steps) -- and the pitch, evenly from step PITCHS to the cut
SUB C3dHeadPitch
	DIM d AS INTEGER, k AS INTEGER, v AS INTEGER, fk AS INTEGER, i1 AS INTEGER, i2 AS INTEGER
	DIM dx AS SINGLE, dz AS SINGLE, sx AS SINGLE
	FOR d = 0 TO BENDS + bendE: toff(d) = 0: NEXT
	IF HEADM = 0 THEN
		RESTORE turnKnots
		FOR k = 0 TO NKNOT - 1: READ v: tk(k) = v: NEXT
		FOR d = 0 TO BENDS + bendE
			k = d \ TURNK: IF k > NKNOT - 2 THEN k = NKNOT - 2
			fk = d - k * TURNK: IF fk > TURNK THEN fk = TURNK
			tyaw(d) = (tk(k) + (tk(k + 1) - tk(k)) * fk / TURNK) * .0017453
		NEXT
		IF edit = 0 THEN CALL C3dLoadTurn
	ELSE
		FOR d = 0 TO BENDS + bendE
			IF d < BENDS THEN
				tyaw(d) = ATN(PDX / PDZ)
			ELSE
				'----- the chord of the car's wheelbase along the path (HEADW steps
				'----- each way), not the step's own direction: a car's heading is
				'----- its axles' line, and the step-to-step direction of a table
				'----- in 1/16 units jitters and turns in bursts
				i1 = d - BENDS - HEADW: i2 = d - BENDS + HEADW
				IF i1 < 0 THEN i1 = 0
				IF i2 > bendN THEN i2 = bendN
				dx = tpx(i2) - tpx(i1): dz = tpz(i2) - tpz(i1)
				IF dz < 1 THEN dz = 1
				tyaw(d) = ATN(dx / dz)
			END IF
		NEXT
	END IF
	CALL C3dHeadTab
	FOR d = 0 TO BENDS + bendE
		tcp(d) = 256: tsp(d) = 0
		IF HEADM = 1 THEN
			'----- the path's own climb (tpit, tenths of a degree) plus PITCHE
			k = d - BENDS: IF k < 0 THEN k = 0
			IF k > bendN THEN k = bendN
			sx = (tpit(k) + PITCHE) * .00017453
			tcp(d) = CINT(COS(sx) * 256): tsp(d) = CINT(SIN(sx) * 256)
		ELSEIF d > PITCHS AND BENDS + bendE > PITCHS THEN
			sx = PITCHE * .0017453 * (d - PITCHS) / (BENDS + bendE - PITCHS)
			tcp(d) = CINT(COS(sx) * 256): tsp(d) = CINT(SIN(sx) * 256)
		END IF
	NEXT
END SUB

'----- C3dWay: the position table from the scene's waypoints (hillWay): a
'----- Catmull-Rom curve through the screen points, each with its depth and the
'----- road's climb, every sample put back in the world (camera space, game
'----- units) from its screen point and depth, the steps along it at one speed
'----- in the world (about 250 in all), the climb kept per step as the pitch
'----- (tpit); the lead-in (PX0..) is the first leg. Floats, once, at load.
SUB C3dWay
	DIM nw AS INTEGER, i AS INTEGER, j AS INTEGER, d AS INTEGER, k AS INTEGER, k2 AS INTEGER, m AS INTEGER, ns AS INTEGER
	DIM t AS SINGLE, t2 AS SINGLE, t3 AS SINGLE, u AS SINGLE, fr AS SINGLE, s AS SINGLE
	DIM ax AS SINGLE, bx AS SINGLE, cx AS SINGLE, ex AS SINGLE, ay AS SINGLE, by AS SINGLE, cy AS SINGLE, ey AS SINGLE
	DIM az AS SINGLE, bz AS SINGLE, cz AS SINGLE, ez AS SINGLE, ap AS SINGLE, bp AS SINGLE, cp AS SINGLE, ep AS SINGLE
	DIM x AS SINGLE, y AS SINGLE, z AS SINGLE, p AS SINGLE
	RESTORE hillWay
	READ nw
	IF nw > 16 THEN nw = 16
	FOR i = 0 TO nw - 1: READ wpx(i): READ wpy(i): READ wpz(i): READ wpp(i): NEXT
	'----- the car HILLCAR percent of the data's size: everything that much deeper
	FOR i = 0 TO nw - 1: wpz(i) = (CLNG(wpz(i)) * 100) \ HILLCAR: NEXT
	'----- the curve: Catmull-Rom with the ends repeated, m samples a leg,
	'----- over the screen point, the depth and the climb alike
	m = BENDNS \ (nw - 1)
	ns = m * (nw - 1)
	FOR i = 0 TO nw - 2
		k = i - 1: IF k < 0 THEN k = 0
		k2 = i + 2: IF k2 > nw - 1 THEN k2 = nw - 1
		ax = wpx(k): ay = wpy(k): az = wpz(k): ap = wpp(k)
		bx = wpx(i): by = wpy(i): bz = wpz(i): bp = wpp(i)
		cx = wpx(i + 1): cy = wpy(i + 1): cz = wpz(i + 1): cp = wpp(i + 1)
		ex = wpx(k2): ey = wpy(k2): ez = wpz(k2): ep = wpp(k2)
		FOR j = 0 TO m
			t = j / m: t2 = t * t: t3 = t2 * t
			x = .5 * (2 * bx + (cx - ax) * t + (2 * ax - 5 * bx + 4 * cx - ex) * t2 + (3 * bx - ax - 3 * cx + ex) * t3)
			y = .5 * (2 * by + (cy - ay) * t + (2 * ay - 5 * by + 4 * cy - ey) * t2 + (3 * by - ay - 3 * cy + ey) * t3)
			z = .5 * (2 * bz + (cz - az) * t + (2 * az - 5 * bz + 4 * cz - ez) * t2 + (3 * bz - az - 3 * cz + ez) * t3)
			qp(i * m + j) = .5 * (2 * bp + (cp - ap) * t + (2 * ap - 5 * bp + 4 * cp - ep) * t2 + (3 * bp - ap - 3 * cp + ep) * t3)
			IF z < 16 THEN z = 16
			'----- the world point under the screen point at that depth
			qx(i * m + j) = (x - 160) * z / 256
			qy(i * m + j) = (100 - y) * z / 256
			qa(i * m + j) = z
		NEXT
	NEXT
	'----- one speed: the way along the curve, over about 250 steps
	s = 0
	FOR i = 1 TO ns
		s = s + SQR((qx(i) - qx(i - 1)) ^ 2 + (qy(i) - qy(i - 1)) ^ 2 + (qa(i) - qa(i - 1)) ^ 2)
	NEXT
	fr = s / 250
	IF fr < .01 THEN fr = .01
	'----- the walk: along the samples, a step at a time; the car's centre is
	'----- the ground point less the model's lowest point
	d = 0: i = 1
	bendN = 0
	x = qx(0): y = qy(0): z = qa(0): p = qp(0)
	DO
		tpx(d) = CLNG(x * 16): tpy(d) = CLNG((y - ymin / 16) * 16): tpz(d) = CLNG(z * 16)
		tpit(d) = CINT(p)
		bendN = d
		IF i > ns OR d >= BENDMAX THEN EXIT DO
		s = fr
		DO WHILE i <= ns
			u = SQR((qx(i) - x) ^ 2 + (qy(i) - y) ^ 2 + (qa(i) - z) ^ 2)
			IF u >= s THEN
				t = s / u
				x = x + (qx(i) - x) * t: y = y + (qy(i) - y) * t: z = z + (qa(i) - z) * t: p = p + (qp(i) - p) * t
				EXIT DO
			END IF
			s = s - u
			x = qx(i): y = qy(i): z = qa(i): p = qp(i)
			i = i + 1
		LOOP
		d = d + 1
	LOOP
	'----- the last point repeats the one before when the end fell on a step
	'----- (the heading there would be nothing): drop it
	IF bendN > 1 THEN
		IF tpx(bendN) = tpx(bendN - 1) AND tpz(bendN) = tpz(bendN - 1) THEN bendN = bendN - 1
	END IF
	'----- the lead-in: the first leg, as the straight run's constants (per 200 steps)
	PX0 = tpx(0): PY0 = tpy(0): PZ0 = tpz(0)
	PDX = (tpx(1) - tpx(0)) * 200: PDY = (tpy(1) - tpy(0)) * 200: PDZ = (tpz(1) - tpz(0)) * 200
	IF PDZ < 1 THEN PDZ = 1
	bendE = BENDL
	IF bendE > bendN THEN bendE = bendN
	IF bendE < 2 THEN bendE = 2
	CALL C3dHeadPitch
END SUB

'----- C3dHeadTab: the heading table's cos/sin (x256) from the angles and the
'----- recorded offsets (quarter degrees), an entry at a time (about 0.3 s
'----- on a 486SX, once)
SUB C3dHeadTab
	DIM d AS INTEGER, n AS INTEGER, a AS SINGLE
	n = BENDS + bendE
	FOR d = 0 TO n
		a = tyaw(d) + toff(d) * .0043633
		tcs(d) = CINT(COS(a) * 256): tsn(d) = CINT(SIN(a) * 256)
	NEXT
END SUB

'----- C3dLoadTurn: C3DTURN.DAT -> toff() (entries beyond the table ignored)
SUB C3dLoadTurn
	DIM fh AS INTEGER, d AS INTEGER, n AS INTEGER, v AS INTEGER, m AS STRING
	IF FileExists%("C3DTURN.DAT") = 0 THEN EXIT SUB
	fh = FREEFILE
	OPEN "C3DTURN.DAT" FOR BINARY AS #fh
	IF LOF(fh) < 6 THEN CLOSE #fh: EXIT SUB
	m = SPACE$(4)
	GET #fh, , m
	IF m <> "C3DT" THEN CLOSE #fh: EXIT SUB
	GET #fh, , n
	IF n < 1 OR n > 4000 OR LOF(fh) < 6 + CLNG(n) * 2 THEN CLOSE #fh: EXIT SUB
	FOR d = 0 TO n - 1
		GET #fh, , v
		IF d <= BENDS + bendE THEN toff(d) = v
	NEXT
	CLOSE #fh
END SUB

'----- C3dSaveTurn: toff() -> C3DTURN.DAT (replaced)
SUB C3dSaveTurn
	DIM fh AS INTEGER, d AS INTEGER, n AS INTEGER, m AS STRING
	IF FileExists%("C3DTURN.DAT") THEN KILL "C3DTURN.DAT"
	fh = FREEFILE
	OPEN "C3DTURN.DAT" FOR BINARY AS #fh
	m = "C3DT"
	PUT #fh, , m
	n = BENDS + bendE + 1
	PUT #fh, , n
	FOR d = 0 TO n - 1
		PUT #fh, , toff(d)
	NEXT
	CLOSE #fh
END SUB

'----- C3dTurnA: the model at heading a (radians) with step d's pitch, rotated
'----- and sorted
SUB C3dTurnA (a AS SINGLE, d AS INTEGER)
	prr(13) = CINT(COS(a) * 256): prr(14) = CINT(SIN(a) * 256): prr(24) = tcp(d): prr(25) = tsp(d)
	DEF SEG = VARSEG(ovlRot)
	CALL ABSOLUTE(BYVAL VARSEG(prr(0)), BYVAL VARPTR(prr(0)), SADD(ovlRot))
	DEF SEG
END SUB

'----- C3dDbg (C3DDUMP): the tables and the sort as the scene starts
SUB C3dDbg
	DIM fh AS INTEGER, i AS INTEGER, k AS INTEGER, inv AS INTEGER, dk AS INTEGER, dl AS INTEGER
	fh = FREEFILE
	OPEN "C3D.LOG" FOR APPEND AS #fh
	PRINT #fh, "dbg: bendN"; bendN; " cut at"; bendE; " ymin"; ymin; " nv"; nv; " nf"; nf
	PRINT #fh, "dbg: heading cs/sn at 0:"; tcs(0); tsn(0); " 100:"; tcs(100); tsn(100); " 200:"; tcs(200); tsn(200); " end:"; tcs(BENDS + bendE); tsn(BENDS + bendE)
	PRINT #fh, "dbg: bend x/y/z at 0:"; tpx(0); tpy(0); tpz(0); " mid:"; tpx(bendE \ 2); tpy(bendE \ 2); tpz(bendE \ 2); " cut:"; tpx(bendE); tpy(bendE); tpz(bendE); " end:"; tpx(bendN); tpy(bendN); tpz(bendN)
	PRINT #fh, "dbg: v0 rx/ry/rz:"; rx(0); ry(0); rz(0); " mx/my/mz:"; mx(0); my(0); mz(0); " v1:"; rx(1); ry(1); rz(1); " "; mx(1); my(1); mz(1)
	'----- the order must be far-to-near: depth keys never rising
	inv = 0
	FOR i = 1 TO nf - 1
		k = ord(i - 1): dk = (rz(fa(k).a) + rz(fa(k).b) + rz(fa(k).c) + 4096) \ 32
		k = ord(i): dl = (rz(fa(k).a) + rz(fa(k).b) + rz(fa(k).c) + 4096) \ 32
		IF dl > dk THEN inv = inv + 1
	NEXT
	PRINT #fh, "dbg: ord"; ord(0); ord(1); ord(2); ord(3); " ... "; ord(nf - 1); " depth inversions"; inv; " of"; nf - 1
	CLOSE #fh
END SUB

'----- C3dTurn: the model at the heading table's entry d (a step of the
'----- drive), rotated and depth-sorted by C3DROT
SUB C3dTurn (d AS INTEGER)
	prr(13) = tcs(d): prr(14) = tsn(d): prr(24) = tcp(d): prr(25) = tsp(d)
	DEF SEG = VARSEG(ovlRot)
	CALL ABSOLUTE(BYVAL VARSEG(prr(0)), BYVAL VARPTR(prr(0)), SADD(ovlRot))
	DEF SEG
	lastd = d
END SUB

'----- C3dDraw: C3DPRJ projects the model at (px,py,pz) and gives its screen
'----- box; the work buffer goes over the join of that box and the last one,
'----- filled from the strip, the faces drawn into it, the silhouette marked,
'----- and the block copied to VRAM in the vertical blank
SUB C3dDraw (px AS LONG, py AS LONG, pz AS LONG)
	DIM bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER, dx AS INTEGER, dy AS INTEGER
	DIM rw AS INTEGER, rh AS INTEGER, wo AS LONG, w1 AS INTEGER
	CALL C3dSplit(px, prq(11), prq(12))
	CALL C3dSplit(py, prq(13), prq(14))
	CALL C3dSplit(pz, prq(15), prq(16))
	DEF SEG = VARSEG(ovlPrj)
	CALL ABSOLUTE(BYVAL VARSEG(prq(0)), BYVAL VARPTR(prq(0)), SADD(ovlPrj))
	DEF SEG
	'----- the projection is in 1/16 pixel; the box in whole pixels, padded
	'----- for the ink, joined with the last frame's, kept inside the strip
	bx1 = prq(17) \ 16: bx2 = prq(18) \ 16: by1 = prq(19) \ 16: by2 = prq(20) \ 16
	bx = bx1 - 1: by = by1 - 1: ex = bx2 + 2: ey = by2 + 2
	IF ox2 >= 0 THEN
		IF ox < bx THEN bx = ox
		IF oy < by THEN by = oy
		IF ox2 > ex THEN ex = ox2
		IF oy2 > ey THEN ey = oy2
	END IF
	IF bx < 0 THEN bx = 0
	IF by < BGY0 THEN by = BGY0
	IF ex > 319 THEN ex = 319
	IF ey > 199 THEN ey = 199
	ox = bx1 - 1: oy = by1 - 1: ox2 = bx2 + 2: oy2 = by2 + 2
	IF ox < 0 THEN ox = 0
	IF oy < BGY0 THEN oy = BGY0
	IF ox2 > 319 THEN ox2 = 319
	IF oy2 > 199 THEN oy2 = 199
	'----- the work buffer's place on screen: over the box, inside the screen
	dx = bx: dy = by
	IF dx > 320 - WKW THEN dx = 320 - WKW
	IF dy > 200 - WKH THEN dy = 200 - WKH
	IF ex > dx + WKW - 1 THEN ex = dx + WKW - 1
	IF ey > dy + WKH - 1 THEN ey = dy + WKH - 1
	rw = ex - bx + 1: rh = ey - by + 1
	IF rw < 1 OR rh < 1 THEN EXIT SUB
	wo = CLNG(wko) + CLNG(by - dy) * WKW + (bx - dx)
	CALL C3dCopy(bgseg, CLNG(bgo) + CLNG(by - BGY0) * 320 + bx, wseg, wo, rh, rw, 320, WKW)
	prm(20) = dx * 16: prm(21) = dy * 16: prm(22) = 0
	prm(24) = C3DFLAT: prm(25) = C3DQUAD OR &H8000
	DEF SEG = VARSEG(ovlTri)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
	DEF SEG
	'----- silhouette ink: car pixels that border the background get marked
	'----- (254) and turn brown (3) in the copy, like the sprite's drawn outline
	IF rw >= 2 AND rh >= 2 THEN
		w1 = wo
		DEF SEG = VARSEG(ovlEdge)
		CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL WKW, BYVAL rw, BYVAL rh, SADD(ovlEdge))
		DEF SEG
	END IF
	CALL VgaSync
	CALL C3dCopyF(wseg, wo, &HA000, CLNG(by) * 320 + bx, bgseg, CLNG(bgo) + CLNG(by - BGY0) * 320 + bx, rh, rw, WKW, 320, 320, 3)
END SUB

'----- C3dCopy: SHADBOP.OVL mode 0 - rows x nb bytes from sg:so (stride sst)
'----- to dg:dof (stride dst); offsets as LONG 0..65535
SUB C3dCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBop)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL 0, SADD(ovlBop))
	DEF SEG
END SUB

'----- C3dCopyM: C3DBLTM.OVL - the same copy, every 254 written as colour col
SUB C3dCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBltm)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL col, SADD(ovlBltm))
	DEF SEG
END SUB

'----- C3dCopyF: C3DBLTF.OVL - the copy to VRAM with the backdrop strip's
'----- rectangle (fg:fo, stride fst) read alongside: its flagged pixels (bit 7,
'----- the artist's front layer) go out instead of the car's; 254 -> col
SUB C3dCopyF (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, fg AS INTEGER, fo AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, fst AS INTEGER, col AS INTEGER)
	DIM a AS LONG, b AS LONG, c AS LONG, s1 AS INTEGER, d1 AS INTEGER, f1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	c = fo: IF c > 32767 THEN c = c - 65536
	s1 = a: d1 = b: f1 = c
	DEF SEG = VARSEG(ovlBltf)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL fg, BYVAL f1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL fst, BYVAL col, SADD(ovlBltf))
	DEF SEG
END SUB

'----- C3dSeg: the segment at which (sg:ofs) is offset 0..15
FUNCTION C3dSeg% (sg AS INTEGER, ofs AS INTEGER)
	DIM s AS LONG, o AS LONG
	s = sg: IF s < 0 THEN s = s + 65536
	o = ofs: IF o < 0 THEN o = o + 65536
	s = s + o \ 16
	IF s > 32767 THEN s = s - 65536
	C3dSeg% = s
END FUNCTION

'----- C3dSplit: LONG -> two words (lo as the signed INTEGER of the low 16 bits)
SUB C3dSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
	DIM l AS LONG
	l = v AND &HFFFF&
	hi = (v - l) \ 65536
	IF l > 32767 THEN l = l - 65536
	lo = l
END SUB

SUB C3dLoadOvl (fil AS STRING, s AS STRING)
	DIM n AS INTEGER
	n = FREEFILE
	OPEN fil FOR BINARY AS #n
	s = SPACE$(LOF(n))
	IF LOF(n) > 0 THEN GET #n, 1, s
	CLOSE #n
END SUB

'----- C3dPal: CAR3D.BMP's palette (BGRA entries in palb) to the DAC, scaled
'----- by f/16 (0 = black, 16 = as authored), in the vertical blank
SUB C3dPal (f AS INTEGER)
	DIM i AS INTEGER, p AS INTEGER
	CALL VgaSync
	OUT &H3C8, 0
	'----- black needs no palette: the first C3dPal(0) comes right after the
	'----- mode switch, before CAR3D.BMP (which carries the palette) is read
	IF f = 0 OR LEN(palb) < 1024 THEN
		FOR i = 0 TO 767: OUT &H3C9, 0: NEXT
		EXIT SUB
	END IF
	FOR i = 0 TO 255
		p = i * 4
		OUT &H3C9, ((ASC(MID$(palb, p + 3, 1)) \ 4) * f) \ 16
		OUT &H3C9, ((ASC(MID$(palb, p + 2, 1)) \ 4) * f) \ 16
		OUT &H3C9, ((ASC(MID$(palb, p + 1, 1)) \ 4) * f) \ 16
	NEXT
END SUB

'----- C3dHold: wait secs (midnight-safe); -1 if 's' (skip the intro) came
FUNCTION C3dHold% (secs AS SINGLE)
	DIM t9 AS SINGLE, d9 AS SINGLE
	C3dHold% = 0
	t9 = TIMER
	DO
		IF INKEY$ = "s" THEN C3dHold% = -1: EXIT FUNCTION
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < secs
END FUNCTION

'----- C3dFree: the heap and the strings back
SUB C3dFree
	REDIM mx(1) AS INTEGER, my(1) AS INTEGER, mz(1) AS INTEGER
	REDIM rx(1) AS INTEGER, ry(1) AS INTEGER, rz(1) AS INTEGER
	REDIM tpx(1) AS LONG, tpy(1) AS LONG, tpz(1) AS LONG, tcs(1) AS INTEGER, tsn(1) AS INTEGER
	REDIM tyaw(1) AS SINGLE, toff(1) AS INTEGER, tcp(1) AS INTEGER, tsp(1) AS INTEGER
	REDIM hpx(1) AS LONG, hpy(1) AS LONG, hpz(1) AS LONG, hcs(1) AS INTEGER, hsn(1) AS INTEGER, hcp(1) AS INTEGER, hsp(1) AS INTEGER
	REDIM qx(1) AS SINGLE, qy(1) AS SINGLE, qa(1) AS SINGLE, qp(1) AS SINGLE, tpit(1) AS INTEGER, trkF(1) AS INTEGER
	REDIM vt(1) AS INTEGER
	REDIM fa(1) AS C3dFac
	REDIM fband(1) AS INTEGER, ord(1) AS INTEGER, lnk(1) AS INTEGER, bkt(1) AS INTEGER
	REDIM bgb(1) AS INTEGER, wkb(1) AS INTEGER
	REDIM tb0(1) AS INTEGER, tb1(1) AS INTEGER, tb2(1) AS INTEGER, tb3(1) AS INTEGER
	REDIM tb4(1) AS INTEGER, tb5(1) AS INTEGER, tb6(1) AS INTEGER, tb7(1) AS INTEGER
	ovlTri = "": ovlPrj = "": ovlBop = "": ovlEdge = "": ovlBltm = "": ovlRot = "": ovlBltf = "": palb = ""
END SUB

'----- C3dShot: the screen as an 8-bit BMP with the palette (C3DDUMP=2 only)
SUB C3dShot (fil AS STRING)
	DIM fh AS INTEGER, x AS INTEGER, y AS INTEGER, s AS STRING, o AS LONG
	fh = FREEFILE
	OPEN fil FOR BINARY AS #fh
	s = "BM" + MKL$(54 + 1024 + 64000) + MKL$(0) + MKL$(54 + 1024)
	s = s + MKL$(40) + MKL$(320) + MKL$(200) + MKI$(1) + MKI$(8) + MKL$(0) + MKL$(64000)
	s = s + MKL$(2835) + MKL$(2835) + MKL$(256) + MKL$(0)
	PUT #fh, , s
	PUT #fh, , palb
	s = SPACE$(320)
	DEF SEG = &HA000
	FOR y = 199 TO 0 STEP -1
		o = CLNG(y) * 320
		FOR x = 0 TO 319
			MID$(s, x + 1, 1) = CHR$(PEEK(o + x))
		NEXT
		PUT #fh, , s
	NEXT
	DEF SEG
	CLOSE #fh
END SUB

'----- C3dTicks: the BIOS tick count (18.2 Hz) for the C3DDUMP log
FUNCTION C3dTicks&
	DEF SEG = &H40
	C3dTicks& = CLNG(PEEK(&H6C)) + 256& * PEEK(&H6D) + 65536 * PEEK(&H6E)
	DEF SEG
END FUNCTION
