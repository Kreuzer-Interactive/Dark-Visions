'----- GAME8.BAS: the 3D man in the house rooms (dark.ini man3d=1; 0 or no line =
'----- the 2D sprite as always, and nothing here is loaded). Eighth code module, a
'----- pure library like GAME5 (no COMMON SHARED): GAME.BAS calls Man3dInit at
'----- loadgame and Man3dRoom at every room load; GAME5's PStand and PStepP hand
'----- the player's drawing here while Man3dOn% says this room is his.
'-----
'----- The game keeps all its own logic -- positions, walk boxes, stand points,
'----- facing digits -- in the 2D sprite's terms; only the drawing changes. Each
'----- draw turns the feet pixel (pjx + 15, pjy + 30) into a point on the floor
'----- through the camera the house rooms share (rooms 1..11 are one template),
'----- the facing digit (or the way he is walking) into a heading, scales him with
'----- the depth like tools\MANWALK, renders him into a small byte box (C3DROT,
'----- C3DPRJ, C3DTRI, the outline by C3DEDGO), and C3DCGA turns the box into a
'----- CGA art + mask pair in the room's own four colours, put like any sprite
'----- (mask AND, art OR) over a GET save-under.
'-----
'----- Files (tools\man3dgame.ps1 makes the first three): MAN3D.MDL (the model),
'----- MAN3D.BMP (its 64x64 texture), MAN3DW.ANI (the walk: bone matrices per
'----- frame, skinned by C3DSKIN, played by the distance walked), and C3DTRI,
'----- C3DPRJ, C3DROT, C3DSKIN, C3DEDGO, C3DCGA .OVL -- loaded into far arrays, not
'----- strings (DGROUP is nearly full). Anything missing, or too little far heap,
'----- and the game stays 2D. MAN3DI.ANI (tools\man3didle.ps1, optional): standing
'----- he breathes and now and then fidgets (Man3dIdle, from the main loop), and
'----- he steps round on the spot when his facing changes (M3Turn); without it he
'----- stands in the rest pose and turns without the step. The intro's enter-house
'----- scene (GAME6 IntroTalk, VGA mode 13h) has him too: the hall is the house
'----- rooms' template, so the same camera; there he is drawn through GAME6's
'----- CgaRows / VgaArt (Man3dHall, Man3dHallOp). James, painted into ENTER.PIC, is
'----- wiped out of it there and drawn in 3D instead (JAMES3D.MDL / .BMP: his own mesh,
'----- James v2; JAMES3DI.ANI his bone words and breathing loop -- M3Jam*). The man is loaded
'----- there without his fidgets to make room.
DEFINT A-Z

TYPE M3Hdr
	magic AS STRING * 4
	nv AS INTEGER
	nf AS INTEGER
	flags AS INTEGER
END TYPE
TYPE M3Vtx
	x AS SINGLE
	y AS SINGLE
	z AS SINGLE
	u AS SINGLE
	v AS SINGLE
END TYPE
TYPE M3Fac
	a AS INTEGER
	b AS INTEGER
	c AS INTEGER
	d AS INTEGER
	ci AS INTEGER
END TYPE

DECLARE SUB Man3dInit ()
DECLARE SUB Man3dFree ()
DECLARE SUB Man3dRoom (q$, co!, p1!, p2!, p3!, nopl!)
DECLARE FUNCTION Man3dOn% ()
DECLARE SUB Man3dStand (d$, px!, py!, ovf%())
DECLARE SUB Man3dStep (x!, y!, ofs%, j%, k%, ovf%())
DECLARE SUB Man3dIdle (ovf%(), ms!)
DECLARE SUB M3IdleLoad ()
DECLARE SUB M3IdleMx (g%)
DECLARE FUNCTION M3IdlePose% (d!)
DECLARE SUB M3IdleReset ()
DECLARE SUB M3StandShow ()
DECLARE SUB M3Turn (fx!, fy!, y0!, y1!, ovf%())
DECLARE FUNCTION M3Dif! (y0!, y1!)
DECLARE SUB M3Lut (co%, p1%, p2%, p3%)
DECLARE FUNCTION Man3dHall% (cga%())
DECLARE SUB Man3dHallOp (op%, v&, cga%(), lut%(), row%(), cm%(), tc%)
DECLARE SUB M3HallShow (v&, cga%(), lut%(), row%(), cm%())
DECLARE SUB M3Poke (cga%(), a%(), m%(), bx%, by%, bw%, bh%)
DECLARE SUB M3Pal (f$)
DECLARE SUB M3TexAl (t%(), al%)
DECLARE SUB M3JamLoad ()
DECLARE SUB M3JamStart (cga%())
DECLARE FUNCTION M3JamPose% ()
DECLARE SUB M3JamRender ()
DECLARE SUB M3JamDraw (v&, cga%(), lut%(), row%())
DECLARE FUNCTION M3JamDark% ()
'----- GAME6's mode-13h helpers (the hall scene)
DECLARE SUB CgaRows (v AS LONG, cga() AS INTEGER, lut() AS INTEGER, row() AS INTEGER, y0 AS INTEGER, y1 AS INTEGER, x0 AS INTEGER, x1 AS INTEGER)
DECLARE SUB VgaArt (v AS LONG, x0 AS INTEGER, y0 AS INTEGER, art() AS INTEGER, ao AS INTEGER, msk() AS INTEGER, mo AS INTEGER, um AS INTEGER, cmap() AS INTEGER)
'----- GAME.BAS's mouse cursor (taken off and put back round an idle redraw) and
'----- GAME5's foreground overlays (re-put over him)
DECLARE SUB erasecur ()
DECLARE SUB drawcur ()
DECLARE SUB OvTopBox (bx%, by%, bw%, bh%, ovf%())
DECLARE SUB Man3dStepShow ()
DECLARE FUNCTION Man3dSubs% (sdur!)
DECLARE FUNCTION Man3dWait! ()
DECLARE SUB Man3dStepOff ()
DECLARE SUB Man3dBox (bx%, by%, bw%, bh%)
DECLARE SUB Man3dSBox (bx%, by%, bw%, bh%)
DECLARE FUNCTION M3Ini% ()
DECLARE FUNCTION M3Size& (f$)
DECLARE SUB M3Ovl (f$, a%())
DECLARE SUB M3Render (fx!, fy!, yaw!, wf%)
DECLARE SUB M3Floor (fx!, fy!, wx!, wz!)
DECLARE FUNCTION M3K! (z!)
DECLARE FUNCTION M3Atn2! (y!, x!)
DECLARE FUNCTION M3DigYaw! (d$)
DECLARE SUB M3Split (v&, lo%, hi%)
DECLARE SUB M3TexSeg ()
DECLARE SUB C3dMark (s AS STRING)
DECLARE SUB M3Shot (k%)
DECLARE SUB Man3dFbg (tx%, ty%, rw%, rb%)
'----- GAME2's watchers (the door shadows): his pair handed over, his save-under refreshed
DECLARE SUB PGrab3 (a%(), m%(), bx%, by%, bw%, bh%)
DECLARE SUB ShadFbg (fbg%(), tx AS INTEGER, ty AS INTEGER, rw AS INTEGER, rb AS INTEGER)
DECLARE SUB M3WalkTest (px!, py!, d$)
DECLARE SUB M3Prof (px!, py!, d$)
DECLARE SUB PShiftB (sh AS INTEGER)

'----- the house rooms' camera (tools\manwalk.ps1 solves it from the template the
'----- rooms 1..11 share): picture centre, height over the floor, the floor's
'----- depth front..back, the horizontal focal length (pixels 1.2x taller than
'----- wide), his size at the back against the front, his scale over true size
CONST RCX = 151.5, RCY = 69.4, RCH = 331.5, RZN = 788.5, RZF = 1287.2, RFX = 307.2
CONST RBS = .65, RSC = 1.252
'----- the outline round him (C3DEDGO, in the room colour nearest blue): 0 = none (the
'----- user's choice, 2026-10-17), 1 = drawn
CONST M3OUTL = 0
'----- the intro hall: where he stops coming in (feet y; the door is at 180, James at 162)
CONST HSTOPY = 166
'----- James: where his feet are painted in ENTER.PIC (he is part of the picture, pixels
'----- 172..186 x 131..161), the box he is wiped out of (the hall there is black but for
'----- the skirting line on row 135, colour 3)
CONST JPX = 179, JPY = 161, JWX0 = 171, JWX1 = 187, JWY0 = 130, JWY1 = 162, JSKY = 135
'----- the byte box he is rendered into (his outline included: 36 px tall at the front)
CONST MAXW = 56, MAXH = 64

'$DYNAMIC
DIM SHARED oTri(1) AS INTEGER, oPrj(1) AS INTEGER, oRot(1) AS INTEGER, oSkn(1) AS INTEGER, oEdg(1) AS INTEGER, oCga(1) AS INTEGER
DIM SHARED mx(1) AS INTEGER, my(1) AS INTEGER, mz(1) AS INTEGER, rx(1) AS INTEGER, ry(1) AS INTEGER, rz(1) AS INTEGER
DIM SHARED kx(1) AS INTEGER, ky(1) AS INTEGER, kz(1) AS INTEGER, vt(1) AS INTEGER, ibw(1) AS INTEGER
DIM SHARED fa(1) AS M3Fac, fband(1) AS INTEGER, ord(1) AS INTEGER, lnk(1) AS INTEGER, head(1) AS INTEGER
DIM SHARED tex(1) AS INTEGER, bt(1) AS INTEGER, wfm(1) AS INTEGER, wcum(1) AS INTEGER
DIM SHARED buf(1) AS INTEGER, art(1) AS INTEGER, msk(1) AS INTEGER, bgs(1) AS INTEGER, bgw(1) AS INTEGER, lut(1) AS INTEGER
DIM SHARED tpr(1) AS INTEGER, tpg(1) AS INTEGER, tpb(1) AS INTEGER, ega(1) AS INTEGER
DIM SHARED prm(1) AS INTEGER, prq(1) AS INTEGER, prr(1) AS INTEGER, prs(1) AS INTEGER
DIM SHARED idc(1) AS INTEGER, imx(1) AS INTEGER, icum(1) AS INTEGER, icst(1) AS INTEGER, icnt(1) AS INTEGER, ilen(1) AS INTEGER, ilp(1) AS INTEGER
DIM SHARED jfa(1) AS M3Fac, jtex(1) AS INTEGER, jlut(1) AS INTEGER, jart(1) AS INTEGER, jmsk(1) AS INTEGER, jsv(1) AS INTEGER
DIM SHARED jmx(1) AS INTEGER, jmy(1) AS INTEGER, jmz(1) AS INTEGER, jvt(1) AS INTEGER, jibw(1) AS INTEGER, jidc(1) AS INTEGER, jicum(1) AS INTEGER
DIM SHARED oEdi(1) AS INTEGER, jdk(1) AS INTEGER
'$STATIC
'----- James in the hall (JAMES3D.MDL / .BMP: the man's mesh -- the same vertices, so only
'----- his faces, texture and colour table are his -- and the man's walk and idle clips):
'----- loaded (jok), drawn with his arrays while m3who = 1; his faces (jnf), texture
'----- alignment, feet pixel, heading, the idle frame shown (jpose, -1 the rest pose), his
'----- time in the breathing loop (1/30 s), his box on the screen, the clean hall under him
'----- saved in jsv (bytes jr0..jr1 of rows jy0..jy1)
DIM SHARED jok AS INTEGER, m3who AS INTEGER, jnf AS INTEGER, jtalo AS INTEGER, jfx AS SINGLE, jfy AS SINGLE, jyaw AS SINGLE
DIM SHARED jpose AS INTEGER, jtm AS SINGLE, jbx AS INTEGER, jby AS INTEGER, jbw AS INTEGER, jbh AS INTEGER
DIM SHARED jr0 AS INTEGER, jr1 AS INTEGER, jy0 AS INTEGER, jy1 AS INTEGER
'----- his own mesh (James v2): vertices jnv (rest pose jmx/jmy/jmz x16, the interleaved
'----- vertices jvt with his texels, his bone words jibw, his lowest point jymn); his
'----- breathing loop (JAMES3DI.ANI, C3J2): jnfr frames in jidc (98 words each, rotations
'----- times jirm), each one's start jicum (1/30 s), the loop's length jilen. m3hall: the
'----- man is loaded for the hall (his idle file without the fidgets: room for James)
DIM SHARED jnv AS INTEGER, jymn AS INTEGER, jnfr AS INTEGER, jilen AS INTEGER, jirm AS INTEGER, m3hall AS INTEGER
'----- his black jacket on the hall's black floor: C3DEDGI (oEdi) draws the edge pixels of his black
'----- where they meet the black round him in the outline colour (MANWALK's outline 5); jdk its
'----- table (a flag per colour: black in the hall), 16-byte aligned at jdkal (-1 = not built)
DIM SHARED jdkal AS INTEGER
'----- the idle and turning clips (MAN3DI.ANI): the frames packed in idc() (98 words each:
'----- the bones' rotations in bytes, then their translations), one unpacked for C3DSKIN in
'----- imx() (rotations times irm); clip c is frames icst(c).. (icnt of them, icum each one's
'----- start in 1/30 s, ilen its length, ilp its kind); inc clips (0: none -- the rest pose),
'----- nfid fidgets, tcf0/tcf1 the turning steps to his left/right (-1 none), iok allocated.
'----- The idle: its clip (0 breathing), time in it (1/30 s), wait for the next fidget, the
'----- last fidget, the last tick (TIMER). What is shown: the pose (m3pose, -1 the rest
'----- pose), the feet pixel and heading (m3fx, m3fy, m3yaw); m3er: the stand just erased
'----- (a walk is starting from there)
DIM SHARED inc AS INTEGER, nfid AS INTEGER, tcf0 AS INTEGER, tcf1 AS INTEGER, irm AS INTEGER, iok AS INTEGER
DIM SHARED iclp AS INTEGER, ilst AS INTEGER, itm AS SINGLE, iwt AS SINGLE, itl AS SINGLE
DIM SHARED m3pose AS INTEGER, m3fx AS SINGLE, m3fy AS SINGLE, m3yaw AS SINGLE, m3er AS INTEGER
'----- the hall scene: his box on the screen (hbw 0 = none), feet y and heading, frames a
'----- footstep (hk 1..4), the last footstep's start
DIM SHARED hbx AS INTEGER, hby AS INTEGER, hbw AS INTEGER, hbh AS INTEGER, hfy AS SINGLE, hyaw AS SINGLE
DIM SHARED hk AS INTEGER, ht0 AS SINGLE
'----- loaded (m3on), his room (m3room), the standing draw's box (m3drawn) and the
'----- step's, the last render's box; the model's sizes and lowest point; the walk
'----- (frames, cycle x16, the place in it), the last step (feet pixel, heading,
'----- when), the texture's alignment inside tex()
DIM SHARED m3on AS INTEGER, m3room AS INTEGER, m3drawn AS INTEGER, m3bx AS INTEGER, m3by AS INTEGER, m3bw AS INTEGER, m3bh AS INTEGER
DIM SHARED m3sx AS INTEGER, m3sy AS INTEGER, m3sw AS INTEGER, m3sh AS INTEGER, m3stp AS INTEGER
DIM SHARED rbx AS INTEGER, rby AS INTEGER, rbw AS INTEGER, rbh AS INTEGER
DIM SHARED nv AS INTEGER, nf AS INTEGER, ymn AS INTEGER, wnf AS INTEGER, wcyc AS LONG, aph AS LONG
DIM SHARED lfx AS SINGLE, lfy AS SINGLE, lyaw AS SINGLE, lt AS SINGLE, talo AS INTEGER
'----- M3DUMP (environment): 1 = the screen after his first stand -> M3SHOT1.PIC, 2 = also a
'----- walk to the right through the step path, a frame mid-walk -> M3SHOT2.PIC (checking from the PC)
DIM SHARED m3dump AS INTEGER, dumpn AS INTEGER
'----- freed for a full-screen page (inventory, map, manual, menu): reload at the next room
DIM SHARED m3was AS INTEGER
'----- a walk step in frames: its start and end feet, the last frame's feet, its heading;
'----- the frames it gets (sk, kk learnt, kcap its ceiling) and its length (sdT, s), its silent
'----- note per frame (wq, ticks), the last step's start (tS), the timed block of steps (b*)
DIM SHARED sx0 AS SINGLE, sy0 AS SINGLE, pfx AS SINGLE, pfy AS SINGLE, syaw AS SINGLE, sk AS INTEGER, sdT AS SINGLE, tS AS SINGLE, wq AS SINGLE, kk AS INTEGER, kcap AS INTEGER, bN AS INTEGER, bCont AS INTEGER, bAcc AS SINGLE, bExp AS SINGLE
'----- (M3DUMP=5: standing draws counted, logged every 10 s)
DIM SHARED cntS AS LONG, cntE AS LONG, cntT AS SINGLE

'----- the EGA colours the room palette numbers name (COLOR / PALETTE 0..15)
m3ega:
DATA 0,0,0, 0,0,170, 0,170,0, 0,170,170, 170,0,0, 170,0,170, 170,85,0, 170,170,170
DATA 85,85,85, 85,85,255, 85,255,85, 85,255,255, 255,85,85, 255,85,255, 255,255,85, 255,255,255

'----- Man3dInit: at loadgame -- dark.ini man3d=1, every file there and enough far
'----- heap (the model's arrays, the texture, the walk, the box and its pairs,
'----- ~32 KB) -> everything loaded, m3on = 1; else nothing allocated
SUB Man3dInit
	DIM fh AS INTEGER, i AS INTEGER, j AS INTEGER, k AS INTEGER, h AS M3Hdr, v AS M3Vtx, t AS LONG, s AS STRING
	DIM nb AS INTEGER, nc AS INTEGER, nfr AS INTEGER, kind AS INTEGER, d AS INTEGER, n AS LONG, need AS LONG, tag AS STRING
	IF m3on THEN EXIT SUB
	m3dump = VAL(ENVIRON$("M3DUMP")): dumpn = 0
	m3room = 0: m3drawn = 0: m3stp = 0
	IF M3Ini% = 0 THEN EXIT SUB
	IF M3Size&("MAN3D.MDL") < 10 OR M3Size&("MAN3D.BMP") < 1100 OR M3Size&("MAN3DW.ANI") < 12 THEN EXIT SUB
	IF M3Size&("C3DTRI.OVL") = 0 OR M3Size&("C3DPRJ.OVL") = 0 OR M3Size&("C3DROT.OVL") = 0 THEN EXIT SUB
	IF M3Size&("C3DSKIN.OVL") = 0 OR M3Size&("C3DEDGO.OVL") = 0 OR M3Size&("C3DCGA.OVL") = 0 THEN EXIT SUB
	fh = FREEFILE
	OPEN "MAN3D.MDL" FOR BINARY AS #fh
	GET #fh, 1, h
	IF h.magic <> "C3D2" OR h.nv < 3 OR h.nv > 600 OR h.nf < 1 OR h.nf > 600 THEN CLOSE #fh: EXIT SUB
	nv = h.nv: nf = h.nf
	'----- the far heap first, while nothing here holds an address (FRE(-1) compacts)
	need = CLNG(nv) * 22 + CLNG(nf) * 18 + 512 + 4200 + 2600 + 3600 + 4 * 900 + 6000 + 4000
	CALL C3dMark("man3d: needs" + STR$(need) + ", far heap" + STR$(FRE(-1)))
	IF FRE(-1) < need + 8000 THEN CLOSE #fh: EXIT SUB
	'----- every array now, before any address is taken
	REDIM mx(0 TO nv - 1) AS INTEGER, my(0 TO nv - 1) AS INTEGER, mz(0 TO nv - 1) AS INTEGER
	REDIM rx(0 TO nv - 1) AS INTEGER, ry(0 TO nv - 1) AS INTEGER, rz(0 TO nv - 1) AS INTEGER
	REDIM kx(0 TO nv - 1) AS INTEGER, ky(0 TO nv - 1) AS INTEGER, kz(0 TO nv - 1) AS INTEGER
	REDIM vt(0 TO 4 * nv + 3) AS INTEGER, ibw(0 TO nv - 1) AS INTEGER
	REDIM fa(0 TO nf - 1) AS M3Fac, fband(0 TO nf - 1) AS INTEGER, ord(0 TO nf - 1) AS INTEGER, lnk(0 TO nf - 1) AS INTEGER, head(0 TO 255) AS INTEGER
	REDIM tex(0 TO 2055) AS INTEGER, bt(0 TO 7) AS INTEGER
	REDIM buf(0 TO MAXW * MAXH \ 2 + 1) AS INTEGER, lut(0 TO 127) AS INTEGER
	REDIM art(0 TO 451) AS INTEGER, msk(0 TO 451) AS INTEGER, bgs(0 TO 451) AS INTEGER, bgw(0 TO 451) AS INTEGER
	REDIM tpr(0 TO 255) AS INTEGER, tpg(0 TO 255) AS INTEGER, tpb(0 TO 255) AS INTEGER, ega(0 TO 47) AS INTEGER
	REDIM prm(0 TO 63) AS INTEGER, prq(0 TO 31) AS INTEGER, prr(0 TO 25) AS INTEGER, prs(0 TO 16) AS INTEGER
	REDIM oTri(0 TO M3Size&("C3DTRI.OVL") \ 2 + 1) AS INTEGER, oPrj(0 TO M3Size&("C3DPRJ.OVL") \ 2 + 1) AS INTEGER
	REDIM oRot(0 TO M3Size&("C3DROT.OVL") \ 2 + 1) AS INTEGER, oSkn(0 TO M3Size&("C3DSKIN.OVL") \ 2 + 1) AS INTEGER
	REDIM oEdg(0 TO M3Size&("C3DEDGO.OVL") \ 2 + 1) AS INTEGER, oCga(0 TO M3Size&("C3DCGA.OVL") \ 2 + 1) AS INTEGER
	'----- the walk's size, then its arrays
	j = FREEFILE
	OPEN "MAN3DW.ANI" FOR BINARY AS #j
	tag = SPACE$(4): GET #j, 1, tag: GET #j, , k: GET #j, , nb: GET #j, , nc
	IF tag <> "C3I1" OR k <> nv OR nb <> 13 OR nc <> 1 THEN CLOSE #j: CLOSE #fh: EXIT SUB
	FOR i = 0 TO nv - 1: GET #j, , ibw(i): NEXT
	GET #j, , nfr: GET #j, , kind
	IF nfr < 1 OR nfr > 24 THEN CLOSE #j: CLOSE #fh: EXIT SUB
	REDIM wcum(0 TO nfr) AS INTEGER, wfm(0 TO nfr * 156 - 1) AS INTEGER
	wcyc = 0
	FOR i = 0 TO nfr - 1: GET #j, , d: wcum(i) = wcyc: wcyc = wcyc + d: NEXT
	FOR i = 0 TO nfr * 156 - 1: GET #j, , wfm(i): NEXT
	CLOSE #j
	wnf = nfr
	'----- the model: x16 integers, the texel coordinates 8.8 over 64 texels
	ymn = 32767
	FOR i = 0 TO nv - 1
		GET #fh, , v
		mx(i) = CINT(v.x * 16): my(i) = CINT(v.y * 16): mz(i) = CINT(v.z * 16)
		IF my(i) < ymn THEN ymn = my(i)
		t = CLNG(v.u * 16320): IF t < 0 THEN t = 0
		IF t > 16383 THEN t = 16383
		vt(i * 4 + 2) = t
		t = CLNG(v.v * 16320): IF t < 0 THEN t = 0
		IF t > 16383 THEN t = 16383
		vt(i * 4 + 3) = t
	NEXT
	FOR i = 0 TO nf - 1: GET #fh, , fa(i): fband(i) = 0: NEXT
	CLOSE #fh
	'----- the texture (bottom-up rows of 64) at a paragraph boundary inside tex(), and
	'----- its palette's colours (16.. are the texels; 255 is see-through)
	fh = FREEFILE
	OPEN "MAN3D.BMP" FOR BINARY AS #fh
	s = SPACE$(1024): GET #fh, 55, s
	FOR i = 0 TO 255
		tpb(i) = ASC(MID$(s, i * 4 + 1, 1)): tpg(i) = ASC(MID$(s, i * 4 + 2, 1)): tpr(i) = ASC(MID$(s, i * 4 + 3, 1))
	NEXT
	n = VARSEG(tex(0)): IF n < 0 THEN n = n + 65536
	n = n * 16 + VARPTR(tex(0))
	talo = (16 - (n AND 15)) AND 15
	s = SPACE$(64)
	SEEK #fh, 1079
	DEF SEG = VARSEG(tex(0))
	FOR i = 63 TO 0 STEP -1
		GET #fh, , s
		FOR k = 0 TO 63: POKE VARPTR(tex(0)) + talo + i * 64 + k, ASC(MID$(s, k + 1, 1)): NEXT
	NEXT
	DEF SEG
	CLOSE #fh
	'----- the overlays
	CALL M3Ovl("C3DTRI.OVL", oTri()): CALL M3Ovl("C3DPRJ.OVL", oPrj()): CALL M3Ovl("C3DROT.OVL", oRot())
	CALL M3Ovl("C3DSKIN.OVL", oSkn()): CALL M3Ovl("C3DEDGO.OVL", oEdg()): CALL M3Ovl("C3DCGA.OVL", oCga())
	RESTORE m3ega
	FOR i = 0 TO 47: READ ega(i): NEXT
	m3on = 1
	CALL C3dMark("man3d: loaded," + STR$(nv) + " vertices," + STR$(wnf) + " walk frames")
	CALL M3IdleLoad
END SUB

'----- Man3dFree: before a full-screen page that needs the far heap (the inventory's
'----- tiles alone are 64 KB): every array of his given back; the next Man3dRoom (the
'----- room is reloaded after the page) loads him again
SUB Man3dFree
	IF m3on = 0 THEN EXIT SUB
	ERASE oTri, oPrj, oRot, oSkn, oEdg, oCga, mx, my, mz, rx, ry, rz, kx, ky, kz, vt, ibw
	ERASE fa, fband, ord, lnk, head, tex, bt, wfm, wcum, buf, art, msk, bgs, bgw, lut
	ERASE tpr, tpg, tpb, ega, prm, prq, prr, prs
	IF iok THEN ERASE idc, imx, icum, icst, icnt, ilen, ilp: iok = 0
	IF jok THEN ERASE jfa, jtex, jlut, jart, jmsk, jsv, jmx, jmy, jmz, jvt, jibw, jidc, jicum, oEdi, jdk: jok = 0
	inc = 0: m3who = 0: m3hall = 0: jnfr = 0
	m3on = 0: m3room = 0: m3drawn = 0: m3stp = 0: m3was = 1
	CALL C3dMark("man3d: freed, far heap" + STR$(FRE(-1)))
END SUB

'----- M3Ini: dark.ini's man3d (1 = the 3D man)
FUNCTION M3Ini%
	DIM fh AS INTEGER, l AS STRING
	M3Ini% = 0
	IF M3Size&("DARK.INI") = 0 THEN EXIT FUNCTION
	fh = FREEFILE
	OPEN "DARK.INI" FOR INPUT AS #fh
	DO WHILE NOT EOF(fh)
		LINE INPUT #fh, l
		l = LCASE$(LTRIM$(RTRIM$(l)))
		IF LEFT$(l, 6) = "man3d=" THEN IF VAL(MID$(l, 7)) = 1 THEN M3Ini% = 1
	LOOP
	CLOSE #fh
END FUNCTION

'----- M3Size: a file's length, 0 when it is not there (and not left behind empty)
FUNCTION M3Size& (f$)
	DIM fh AS INTEGER, n AS LONG
	fh = FREEFILE
	OPEN f$ FOR BINARY AS #fh: n = LOF(fh): CLOSE #fh
	IF n = 0 THEN KILL f$
	M3Size& = n
END FUNCTION

'----- M3Ovl: an overlay's bytes into its (already sized) far array
SUB M3Ovl (f$, a%())
	DIM fh AS INTEGER, n AS INTEGER, i AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN f$ FOR BINARY AS #fh: n = LOF(fh)
	s = SPACE$(n): GET #fh, 1, s: CLOSE #fh
	DEF SEG = VARSEG(a%(0))
	FOR i = 0 TO n - 1: POKE VARPTR(a%(0)) + i, ASC(MID$(s, i + 1, 1)): NEXT
	DEF SEG
END SUB

'----- Man3dRoom: at every room load -- his in the template rooms 1..11 (not the
'----- close-ups); the colour table for this room's four: each texel colour to the
'----- nearest of (co, p1, p2, p3), the outline (mark 15) to the nearest to blue
'----- that is not the background. Nothing drawn yet in the new picture
SUB Man3dRoom (q$, co!, p1!, p2!, p3!, nopl!)
	DIM n AS INTEGER
	IF m3was AND m3on = 0 THEN m3was = 0: CALL Man3dInit
	m3room = 0: m3drawn = 0: m3stp = 0: lt = -99: m3er = 0: m3pose = -1
	IF m3on = 0 OR nopl! = 1 OR LEFT$(q$, 4) <> "room" THEN EXIT SUB
	n = VAL(MID$(q$, 5))
	IF n < 1 OR n > 11 THEN EXIT SUB
	CALL M3Lut(CINT(co!), CINT(p1!), CINT(p2!), CINT(p3!))
	m3room = 1
END SUB

'----- M3Lut: the colour table for four EGA colours (co = the background, p1..p3 = PALETTE
'----- 1..3): each texel colour to the nearest, the outline mark (15) to the nearest to blue
'----- that is not the background
SUB M3Lut (co%, p1%, p2%, p3%)
	DIM i AS INTEGER, k AS INTEGER, c(0 TO 3) AS INTEGER, best AS LONG, d AS LONG, bi AS INTEGER, v AS INTEGER
	DIM dr AS LONG, dg AS LONG, db AS LONG
	c(0) = co%: c(1) = p1%: c(2) = p2%: c(3) = p3%
	FOR i = 0 TO 3: c(i) = c(i) AND 15: NEXT
	DEF SEG = VARSEG(lut(0))
	FOR i = 0 TO 255
		v = 0
		IF i >= 16 AND i < 255 THEN
			best = 2147483647
			FOR k = 0 TO 3
				dr = tpr(i) - ega(c(k) * 3): dg = tpg(i) - ega(c(k) * 3 + 1): db = tpb(i) - ega(c(k) * 3 + 2)
				d = dr * dr + dg * dg + db * db
				IF d < best THEN best = d: bi = k
			NEXT
			v = 128 + bi
		END IF
		IF i = 15 THEN
			best = 2147483647
			FOR k = 1 TO 3
				dr = ega(c(k) * 3): dg = ega(c(k) * 3 + 1): db = 170 - ega(c(k) * 3 + 2)
				d = dr * dr + dg * dg + db * db
				IF d < best THEN best = d: bi = k
			NEXT
			v = 128 + bi
		END IF
		POKE VARPTR(lut(0)) + i, v
	NEXT
	DEF SEG
END SUB

'----- Man3dOn: the player is the 3D man in this room
FUNCTION Man3dOn%
	Man3dOn% = m3room
END FUNCTION

'----- Man3dBox: the standing draw's box (the foreground overlays, the watchers);
'----- size 0 while he is not drawn
SUB Man3dBox (bx%, by%, bw%, bh%)
	bx% = m3bx: by% = m3by: bw% = m3bw: bh% = m3bh
	IF m3drawn = 0 THEN bw% = 0: bh% = 0
END SUB

'----- Man3dFbg: a watcher composed a new background under him -- his standing
'----- save-under takes it (GAME2 ShadFbg on his GET layout), so a later erase puts
'----- back what is there now
SUB Man3dFbg (tx%, ty%, rw%, rb%)
	IF m3drawn THEN CALL ShadFbg(bgs(), tx%, ty%, rw%, rb%)
END SUB

'----- Man3dSBox: the walk step's box
SUB Man3dSBox (bx%, by%, bw%, bh%)
	bx% = m3sx: by% = m3sy: bw% = m3sw: bh% = m3sh
END SUB

'----- Man3dStand: the standing player (GAME5 PStand's work in his rooms): his last
'----- standing box restored, then -- unless d$ = "" (erase only) -- drawn facing
'----- d$ at the sprite position (px, py), over a fresh save-under. Shown here
'----- already (standing, or the walk's last frame) and facing elsewhere, he first
'----- steps round to d$ (M3Turn); standing he is in the idle clips' pose
SUB Man3dStand (d$, px!, py!, ovf%())
	DIM fx AS SINGLE, fy AS SINGLE, ty AS SINGLE
	IF m3dump = 5 THEN
		IF d$ = "" THEN cntE = cntE + 1 ELSE cntS = cntS + 1
		IF cntT = 0 THEN cntT = TIMER
		IF TIMER - cntT > 10 THEN CALL C3dMark("stand draws" + STR$(cntS) + ", erases" + STR$(cntE) + " in 10 s"): cntS = 0: cntE = 0: cntT = TIMER
	END IF
	fx = px! + 15: fy = py! + 30
	IF d$ = "" THEN
		CALL Man3dStepOff
		IF m3drawn THEN PUT (m3bx, m3by), bgs(0), PSET: m3drawn = 0: m3er = 1
		EXIT SUB
	END IF
	ty = M3DigYaw!(d$)
	IF (m3drawn OR m3stp) AND ABS(fx - m3fx) + ABS(fy - m3fy) < 3 THEN CALL M3Turn(fx, fy, m3yaw, ty, ovf%())
	m3er = 0: itl = TIMER
	IF inc > 0 THEN m3pose = M3IdlePose%(0) ELSE m3pose = -1
	IF m3pose >= 0 THEN CALL M3Render(fx, fy, ty, 1000 + m3pose) ELSE CALL M3Render(fx, fy, ty, -1)
	CALL M3StandShow
	m3fx = fx: m3fy = fy: m3yaw = ty: lyaw = ty
	IF m3dump > 0 AND dumpn = 0 THEN
		dumpn = 1: CALL M3Shot(1)
		IF m3dump = 2 THEN CALL M3WalkTest(px!, py!, d$)
		'----- (3: him standing in room 8's right doorway, where its watcher paces)
		IF m3dump = 3 THEN CALL Man3dStand("4", 200, 126, ovf%())
		IF m3dump = 4 THEN CALL M3Prof(px!, py!, d$): END
	END IF
END SUB

'----- M3StandShow: the pose just rendered put up as the standing draw -- the walk's
'----- frame or the last standing draw taken away (their save-unders) only now, so he
'----- never blinks out while rendering; GAME2's watchers get his new pair
SUB M3StandShow
	CALL Man3dStepOff
	IF m3drawn THEN PUT (m3bx, m3by), bgs(0), PSET
	m3bx = rbx: m3by = rby: m3bw = rbw: m3bh = rbh
	GET (m3bx, m3by)-(m3bx + m3bw - 1, m3by + m3bh - 1), bgs(0)
	PUT (m3bx, m3by), msk(0), AND
	PUT (m3bx, m3by), art(0), OR
	m3drawn = 1
	CALL PGrab3(art(), msk(), m3bx, m3by, m3bw, m3bh)
END SUB

'----- Man3dIdle: (GAME.BAS main loop, every pass) standing, the idle clips move on
'----- with the time; when their frame changes he is drawn again in it -- the mouse
'----- cursor (ms = 1) taken off round the draw, the foreground overlays put back over
'----- him. Nothing else when the frame is the same (a TIMER read and a compare)
SUB Man3dIdle (ovf%(), ms!)
	DIM tn AS SINGLE, d AS SINGLE, g AS INTEGER
	IF m3drawn = 0 OR inc = 0 THEN EXIT SUB
	tn = TIMER: d = tn - itl: IF d < 0 THEN d = d + 86400
	IF d < .05 THEN EXIT SUB
	itl = tn
	'----- (a long gap -- a message, a cutscene -- does not jump the clip on)
	IF d > .5 THEN d = .055
	g = M3IdlePose%(d * 30)
	IF g = m3pose THEN EXIT SUB
	m3pose = g
	CALL M3Render(m3fx, m3fy, m3yaw, 1000 + g)
	IF ms! = 1 THEN CALL erasecur
	CALL M3StandShow
	CALL OvTopBox(m3bx, m3by, m3bw, m3bh, ovf%())
	IF ms! = 1 THEN CALL drawcur
	'----- (M3DUMP=10, testing: a shot of each fidget 40% in -> M3SHOT11..14.PIC)
	IF m3dump = 10 AND iclp > 0 THEN
		IF itm > ilen(iclp) * .4 AND (dumpn AND 2 ^ iclp) = 0 THEN dumpn = dumpn OR 2 ^ iclp: CALL M3Shot(10 + iclp)
	END IF
END SUB

'----- M3Turn: him at feet pixel (fx, fy) stepping round on the spot from heading y0 to
'----- y1 the short way, 23 degrees a frame paced by silent 1-tick notes (420 degrees a
'----- second, MANWALK's; slower where a frame takes longer than the note), in the
'----- turning step clip for that way played once over the turn (the rest pose, or the
'----- breathing loop's first frame, without one); under 20 degrees he just faces y1.
'----- The frames go up like the walk's (Man3dStepShow), the standing draw taken off
SUB M3Turn (fx!, fy!, y0!, y1!, ovf%())
	DIM dy AS SINGLE, n AS INTEGER, j AS INTEGER, c AS INTEGER, g AS INTEGER, q AS SINGLE, wf AS INTEGER
	dy = M3Dif!(y0!, y1!)
	IF ABS(dy) < .35 THEN EXIT SUB
	n = INT(ABS(dy) / .4) + 1
	c = -1
	IF inc > 0 THEN
		IF dy > 0 THEN c = tcf0 ELSE c = tcf1
	END IF
	FOR j = 1 TO n
		wf = -1
		IF c >= 0 THEN
			q = ilen(c) * j / n
			g = icst(c) + icnt(c) - 1
			DO WHILE g > icst(c) AND icum(g) > q: g = g - 1: LOOP
			wf = 1000 + g
		ELSEIF inc > 0 THEN
			wf = 1000 + icst(0)
		END IF
		CALL M3Render(fx!, fy!, y0! + dy * j / n, wf)
		IF m3drawn THEN PUT (m3bx, m3by), bgs(0), PSET: m3drawn = 0
		CALL Man3dStepShow
		CALL OvTopBox(m3sx, m3sy, m3sw, m3sh, ovf%())
		'----- (M3DUMP=10: the first turn's middle frame -> M3SHOT20.PIC, logged)
		IF m3dump = 10 AND (dumpn AND 1024) = 0 AND j = n \ 2 + 1 THEN
			dumpn = dumpn OR 1024: CALL M3Shot(20)
			CALL C3dMark("man3d turn:" + STR$(INT(y0! * 57.3)) + " to" + STR$(INT(y1! * 57.3)) + " deg," + STR$(n) + " frames, clip" + STR$(c))
		END IF
		SOUND 32676, 1
	NEXT
	m3fx = fx!: m3fy = fy!: m3yaw = y1!
	CALL M3IdleReset
END SUB

'----- M3Dif: heading y1 less y0, the short way round (-pi..pi)
FUNCTION M3Dif! (y0!, y1!)
	DIM d AS SINGLE
	d = y1! - y0!
	DO WHILE d > 3.14159: d = d - 6.28318: LOOP
	DO WHILE d < -3.14159: d = d + 6.28318: LOOP
	M3Dif! = d
END FUNCTION

'----- M3IdleLoad: MAN3DI.ANI into the far heap (when it is there, made for this model,
'----- and there is room for it with ~12 KB to spare) -> inc clips; else inc = 0. For the
'----- intro hall (m3hall) only the breathing loop and the turning step to his left: he walks
'----- in, turns left to James and talks, and the other clips' frames (~11 KB) make his room
SUB M3IdleLoad
	DIM fh AS INTEGER, tag AS STRING, n AS INTEGER, nb AS INTEGER, nc AS INTEGER, rm AS INTEGER
	DIM c AS INTEGER, k AS INTEGER, g AS INTEGER, nfr AS INTEGER, kd AS INTEGER, d AS INTEGER, acc AS INTEGER
	DIM tot AS INTEGER, p AS LONG, nw AS LONG, m AS INTEGER, s AS STRING, fpos AS LONG, kept AS INTEGER, c2 AS INTEGER, q AS LONG
	DIM cn(0 TO 7) AS INTEGER, ck(0 TO 7) AS INTEGER
	inc = 0
	IF M3Size&("MAN3DI.ANI") < 12 THEN EXIT SUB
	fh = FREEFILE
	OPEN "MAN3DI.ANI" FOR BINARY AS #fh
	tag = SPACE$(4): GET #fh, 1, tag: GET #fh, , n: GET #fh, , nb: GET #fh, , nc: GET #fh, , rm
	IF tag <> "C3J1" OR n <> nv OR nb <> 13 OR nc < 1 OR nc > 8 OR rm < 1 OR rm > 258 THEN CLOSE #fh: EXIT SUB
	'----- the clip table twice: the frame counts first, for the room check
	fpos = SEEK(fh): tot = 0: kept = 0
	FOR c = 0 TO nc - 1
		GET #fh, , nfr: GET #fh, , kd
		IF nfr < 1 OR nfr > 60 THEN CLOSE #fh: EXIT SUB
		cn(c) = nfr: ck(c) = 1
		IF m3hall AND (kd = 0 OR kd = 3) THEN ck(c) = 0
		IF ck(c) THEN tot = tot + nfr: kept = kept + 1
		SEEK #fh, SEEK(fh) + 2 * nfr
	NEXT
	nw = CLNG(tot) * 98
	IF FRE(-1) < nw * 2 + 12000 THEN
		CALL C3dMark("man3d: no room for the idle clips (" + STR$(nw * 2) + " of" + STR$(FRE(-1)) + ")")
		CLOSE #fh: EXIT SUB
	END IF
	REDIM idc(0 TO nw - 1) AS INTEGER, imx(0 TO 155) AS INTEGER, icum(0 TO tot - 1) AS INTEGER
	REDIM icst(0 TO kept - 1) AS INTEGER, icnt(0 TO kept - 1) AS INTEGER, ilen(0 TO kept - 1) AS INTEGER, ilp(0 TO kept - 1) AS INTEGER
	iok = 1
	SEEK #fh, fpos: g = 0: nfid = 0: tcf0 = -1: tcf1 = -1: c2 = 0
	FOR c = 0 TO nc - 1
		GET #fh, , nfr: GET #fh, , kd
		IF ck(c) THEN
			icst(c2) = g: icnt(c2) = nfr: ilp(c2) = kd: acc = 0
			FOR k = 0 TO nfr - 1: GET #fh, , d: icum(g + k) = acc: acc = acc + d: NEXT
			ilen(c2) = acc: g = g + nfr
			IF kd = 0 THEN nfid = nfid + 1
			IF kd = 2 THEN tcf0 = c2
			IF kd = 3 THEN tcf1 = c2
			c2 = c2 + 1
		ELSE
			SEEK #fh, SEEK(fh) + 2 * nfr
		END IF
	NEXT
	'----- the frames, 2 KB at a time, a skipped clip's passed over
	p = 0
	FOR c = 0 TO nc - 1
		q = CLNG(cn(c)) * 98
		IF ck(c) THEN
			DO WHILE q > 0
				m = 1024: IF q < 1024 THEN m = q
				s = SPACE$(m * 2): GET #fh, , s
				FOR k = 0 TO m - 1: idc(p + k) = CVI(MID$(s, k * 2 + 1, 2)): NEXT
				p = p + m: q = q - m
			LOOP
		ELSE
			SEEK #fh, SEEK(fh) + q * 2
		END IF
	NEXT
	CLOSE #fh
	s = ""
	irm = rm
	'----- (clip 0 must be the breathing loop)
	IF ilp(0) = 1 THEN inc = kept
	RANDOMIZE TIMER
	CALL M3IdleReset
	m3pose = -1
	CALL C3dMark("man3d: idle clips" + STR$(inc) + "," + STR$(tot) + " frames, far heap" + STR$(FRE(-1)))
END SUB

'----- M3IdleReset: back to the breathing loop's start, the next fidget 4 s away
SUB M3IdleReset
	iclp = 0: itm = 0: iwt = 120
	IF m3dump = 10 THEN iwt = 15
END SUB

'----- M3IdlePose: the idle clips moved on d (1/30 s) -- the breathing loop, or a fidget
'----- played once and back to breathing; after its wait (6..11 s) a fidget starts, never
'----- the same one twice running (MANWALK's IdlePose). The idle frame now
FUNCTION M3IdlePose% (d!)
	DIM c AS INTEGER, g AS INTEGER
	c = iclp
	itm = itm + d!
	IF itm >= ilen(c) THEN
		IF c = 0 THEN
			itm = itm - ilen(0) * INT(itm / ilen(0))
		ELSE
			c = 0: itm = 0
		END IF
	END IF
	IF c = 0 THEN
		iwt = iwt - d!
		IF iwt <= 0 AND nfid > 0 THEN
			DO
				g = 1 + INT(RND * nfid): c = 0
				DO
					c = c + 1
					IF ilp(c) = 0 THEN g = g - 1
				LOOP UNTIL g = 0
			LOOP WHILE c = ilst AND nfid > 1
			iwt = 180 + RND * 150: IF m3dump = 10 THEN iwt = 15
			ilst = c: itm = 0
		END IF
	END IF
	iclp = c
	g = icst(c) + icnt(c) - 1
	DO WHILE g > icst(c) AND icum(g) > itm: g = g - 1: LOOP
	M3IdlePose% = g
END FUNCTION

'----- M3IdleMx: idle frame g unpacked into imx() for C3DSKIN (13 bones x 3 rows of
'----- three rotation words, x16384 after irm, and a translation word, x16 units)
SUB M3IdleMx (g%)
	DIM b AS INTEGER, r AS INTEGER, c AS INTEGER, k AS INTEGER, v AS INTEGER, t AS INTEGER, m AS INTEGER
	DIM bs AS LONG, o AS LONG
	DIM rm AS INTEGER
	bs = CLNG(g%) * 98
	IF m3who THEN
		DEF SEG = VARSEG(jidc(bs)): o = VARPTR(jidc(bs)): rm = jirm
	ELSE
		DEF SEG = VARSEG(idc(bs)): o = VARPTR(idc(bs)): rm = irm
	END IF
	IF o < 0 THEN o = o + 65536
	k = 0: t = 0
	FOR b = 0 TO 12
		FOR r = 0 TO 2
			m = b * 12 + r * 4
			FOR c = 0 TO 2
				v = PEEK(o + k): IF v > 127 THEN v = v - 256
				imx(m + c) = v * rm
				k = k + 1
			NEXT
			IF m3who THEN imx(m + 3) = jidc(bs + 59 + t) ELSE imx(m + 3) = idc(bs + 59 + t)
			t = t + 1
		NEXT
	NEXT
	DEF SEG
END SUB

'----- Man3dHall: (GAME6 IntroTalk, the enter-house scene, VGA up and the palette black)
'----- him loaded if dark.ini says so (Man3dInit) in the hall's colours (COLOR 0 /
'----- PALETTE 8, 1, 6); 1 = he walks the hall, 0 = the sprite. Man3dHallOp 5 frees him
'----- after the scene (loadgame loads him again). James too when his files are there and
'----- the heap has room (M3JamLoad): the painted James wiped out of cga() (GAME6's snapshot
'----- of ENTER.PIC, not on the screen yet) and the 3D one put in its place
FUNCTION Man3dHall% (cga%())
	Man3dHall% = 0
	m3hall = 1
	CALL Man3dInit
	IF m3on = 0 THEN EXIT FUNCTION
	CALL M3Lut(0, 8, 1, 6)
	hbw = 0: hk = 2: hyaw = 3.1416
	CALL M3IdleReset
	CALL M3JamLoad
	IF jok THEN CALL M3JamStart(cga%())
	Man3dHall% = 1
END FUNCTION

'----- M3JamLoad: James v2 -- his own mesh (JAMES3D.MDL: vertices, texels, faces), texture,
'----- colour table (the hall's four) and breathing loop (JAMES3DI.ANI, tools\man3didle.ps1
'----- -BoneWords: his bone words and the clip; without it he stands in his rest pose) into
'----- the far heap -> jok = 1. The man's scratch arrays (rotated, skinned, the face order)
'----- grow to James's counts when his are larger. Nothing when a file is missing or the
'----- heap would keep less than 3.6 KB (GAME6 REDIMs its palette after, 768 B; a hall draw
'----- takes 1.9 KB of locals). His pair (jart/jmsk) holds a box up to 32 px wide
SUB M3JamLoad
	DIM fh AS INTEGER, i AS INTEGER, k AS INTEGER, h AS M3Hdr, v AS M3Vtx, n AS LONG, s AS STRING, need AS LONG, t AS LONG
	DIM ji AS INTEGER, tag AS STRING, nb AS INTEGER, nc AS INTEGER, rm AS INTEGER, nfr AS INTEGER, kd AS INTEGER, acc AS INTEGER
	DIM c AS INTEGER, d AS INTEGER, p AS LONG, q AS LONG, m AS INTEGER, mv AS INTEGER, mf AS INTEGER
	DIM dd(0 TO 59) AS INTEGER
	jok = 0: jnfr = 0
	IF M3Size&("JAMES3D.MDL") < 10 OR M3Size&("JAMES3D.BMP") < 5174 THEN EXIT SUB
	fh = FREEFILE
	OPEN "JAMES3D.MDL" FOR BINARY AS #fh
	GET #fh, 1, h
	IF h.magic <> "C3D2" OR h.nv < 3 OR h.nv > 600 OR h.nf < 1 OR h.nf > 600 THEN CLOSE #fh: EXIT SUB
	jnv = h.nv: jnf = h.nf
	'----- his breathing loop's header and frame count (the frames come after the arrays)
	nfr = 0: ji = 0
	IF M3Size&("JAMES3DI.ANI") > 12 THEN
		ji = FREEFILE
		OPEN "JAMES3DI.ANI" FOR BINARY AS #ji
		tag = SPACE$(4): GET #ji, 1, tag: GET #ji, , k: GET #ji, , nb: GET #ji, , nc: GET #ji, , rm
		IF tag = "C3J2" AND k = jnv AND nb = 13 AND nc >= 1 AND rm >= 1 AND rm <= 258 THEN
			SEEK #ji, 13 + 2 * CLNG(jnv)
			GET #ji, , nfr: GET #ji, , kd
			IF nfr < 1 OR nfr > 60 OR kd <> 1 THEN nfr = 0
			FOR c = 0 TO nfr - 1: GET #ji, , dd(c): NEXT
		END IF
		IF nfr = 0 THEN CLOSE #ji: ji = 0
	END IF
	mv = 0: IF jnv > nv THEN mv = jnv - nv
	mf = 0: IF jnf > nf THEN mf = jnf - nf
	need = CLNG(jnv) * 16 + CLNG(jnf) * 10 + 4112 + 256 + 2 * 600 + 900 + CLNG(nfr) * 198 + mv * 12 + mf * 6 + 460
	CALL C3dMark("james3d: needs" + STR$(need) + ", far heap" + STR$(FRE(-1)))
	IF FRE(-1) < need + 3600 THEN
		CLOSE #fh: IF ji THEN CLOSE #ji
		EXIT SUB
	END IF
	REDIM jmx(0 TO jnv - 1) AS INTEGER, jmy(0 TO jnv - 1) AS INTEGER, jmz(0 TO jnv - 1) AS INTEGER
	REDIM jvt(0 TO 4 * jnv + 3) AS INTEGER, jibw(0 TO jnv - 1) AS INTEGER
	REDIM jfa(0 TO jnf - 1) AS M3Fac, jtex(0 TO 2055) AS INTEGER, jlut(0 TO 127) AS INTEGER
	REDIM jart(0 TO 299) AS INTEGER, jmsk(0 TO 299) AS INTEGER, jsv(0 TO 449) AS INTEGER
	IF nfr > 0 THEN REDIM jidc(0 TO CLNG(nfr) * 98 - 1) AS INTEGER, jicum(0 TO nfr - 1) AS INTEGER
	REDIM oEdi(0 TO M3Size&("C3DEDGI.OVL") \ 2 + 1) AS INTEGER, jdk(0 TO 139) AS INTEGER
	jdkal = -1
	'----- (the man's scratch, when James has more vertices or faces)
	IF mv > 0 THEN
		REDIM rx(0 TO jnv - 1) AS INTEGER, ry(0 TO jnv - 1) AS INTEGER, rz(0 TO jnv - 1) AS INTEGER
		REDIM kx(0 TO jnv - 1) AS INTEGER, ky(0 TO jnv - 1) AS INTEGER, kz(0 TO jnv - 1) AS INTEGER
	END IF
	IF mf > 0 THEN REDIM fband(0 TO jnf - 1) AS INTEGER, ord(0 TO jnf - 1) AS INTEGER, lnk(0 TO jnf - 1) AS INTEGER
	'----- his mesh: x16 integers, the texels 8.8 over 64, his lowest point
	jymn = 32767
	FOR i = 0 TO jnv - 1
		GET #fh, , v
		jmx(i) = CINT(v.x * 16): jmy(i) = CINT(v.y * 16): jmz(i) = CINT(v.z * 16)
		IF jmy(i) < jymn THEN jymn = jmy(i)
		t = CLNG(v.u * 16320): IF t < 0 THEN t = 0
		IF t > 16383 THEN t = 16383
		jvt(i * 4 + 2) = t
		t = CLNG(v.v * 16320): IF t < 0 THEN t = 0
		IF t > 16383 THEN t = 16383
		jvt(i * 4 + 3) = t
	NEXT
	FOR i = 0 TO jnf - 1: GET #fh, , jfa(i): NEXT
	CLOSE #fh
	'----- his breathing loop: his bone words, the frame times, the frames
	IF ji THEN
		SEEK #ji, 13
		FOR i = 0 TO jnv - 1: GET #ji, , jibw(i): NEXT
		acc = 0
		FOR c = 0 TO nfr - 1: jicum(c) = acc: acc = acc + dd(c): NEXT
		jilen = acc
		'----- (past every clip's table: the frames start after the last one; the first clip's come first)
		SEEK #ji, 13 + 2 * CLNG(jnv)
		FOR c = 0 TO nc - 1: GET #ji, , k: GET #ji, , kd: SEEK #ji, SEEK(ji) + 2 * k: NEXT
		p = 0: q = CLNG(nfr) * 98
		DO WHILE q > 0
			m = 1024: IF q < 1024 THEN m = q
			s = SPACE$(m * 2): GET #ji, , s
			FOR k = 0 TO m - 1: jidc(p + k) = CVI(MID$(s, k * 2 + 1, 2)): NEXT
			p = p + m: q = q - m
		LOOP
		CLOSE #ji
		s = ""
		jirm = rm: jnfr = nfr
	END IF
	'----- the texture, as Man3dInit's
	n = VARSEG(jtex(0)): IF n < 0 THEN n = n + 65536
	n = n * 16 + VARPTR(jtex(0))
	jtalo = (16 - (n AND 15)) AND 15
	fh = FREEFILE
	OPEN "JAMES3D.BMP" FOR BINARY AS #fh
	s = SPACE$(64)
	SEEK #fh, 1079
	DEF SEG = VARSEG(jtex(0))
	FOR i = 63 TO 0 STEP -1
		GET #fh, , s
		FOR k = 0 TO 63: POKE VARPTR(jtex(0)) + jtalo + i * 64 + k, ASC(MID$(s, k + 1, 1)): NEXT
	NEXT
	DEF SEG
	CLOSE #fh
	'----- his colour table: his palette through M3Lut, kept; then the man's back
	CALL M3Pal("JAMES3D.BMP"): CALL M3Lut(0, 8, 1, 6)
	FOR i = 0 TO 127: jlut(i) = lut(i): NEXT
	CALL M3Pal("MAN3D.BMP"): CALL M3Lut(0, 8, 1, 6)
	IF M3Size&("C3DEDGI.OVL") > 30 THEN CALL M3Ovl("C3DEDGI.OVL", oEdi())
	jok = 1
	CALL C3dMark("james3d: loaded," + STR$(jnv) + " vertices," + STR$(jnf) + " faces," + STR$(jnfr) + " breathing frames, far heap" + STR$(FRE(-1)))
END SUB

'----- M3Pal: a texture BMP's palette into tpr/tpg/tpb (M3Lut's colours)
SUB M3Pal (f$)
	DIM fh AS INTEGER, i AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN f$ FOR BINARY AS #fh
	s = SPACE$(1024): GET #fh, 55, s
	CLOSE #fh
	FOR i = 0 TO 255
		tpb(i) = ASC(MID$(s, i * 4 + 1, 1)): tpg(i) = ASC(MID$(s, i * 4 + 2, 1)): tpr(i) = ASC(MID$(s, i * 4 + 3, 1))
	NEXT
END SUB

'----- M3JamStart: the painted James wiped out of the snapshot (black, the skirting line
'----- through), James in 3D facing where the man stops, the clean hall round him kept (his
'----- box and 8 px about it), and his pair put into the snapshot
SUB M3JamStart (cga%())
	DIM x AS INTEGER, y AS INTEGER, c AS INTEGER, so AS LONG, sbs AS LONG, k AS INTEGER, b AS INTEGER, sb AS INTEGER
	DIM ax AS SINGLE, az AS SINGLE, bx AS SINGLE, bz AS SINGLE
	DEF SEG = VARSEG(cga%(0)): sbs = VARPTR(cga%(0)): IF sbs < 0 THEN sbs = sbs + 65536
	FOR y = JWY0 TO JWY1
		so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
		IF y = JSKY THEN c = 3 ELSE c = 0
		FOR x = JWX0 TO JWX1
			k = 6 - 2 * (x AND 3)
			sb = PEEK(so + x \ 4)
			SELECT CASE k
			CASE 6: sb = (sb AND &H3F) OR c * 64
			CASE 4: sb = (sb AND &HCF) OR c * 16
			CASE 2: sb = (sb AND &HF3) OR c * 4
			CASE ELSE: sb = (sb AND &HFC) OR c
			END SELECT
			POKE so + x \ 4, sb
		NEXT
	NEXT
	DEF SEG
	'----- turned to the man's stop
	jfx = JPX: jfy = JPY
	CALL M3Floor(jfx, jfy, ax, az): CALL M3Floor(158, HSTOPY, bx, bz)
	jyaw = M3Atn2!(-(bx - ax), -(bz - az))
	jtm = 0: IF jnfr > 0 THEN jtm = jilen \ 2
	jpose = M3JamPose%
	CALL M3JamRender
	'----- the clean hall round him (at most 450 bytes)
	jr0 = (rbx - 8) \ 4: jr1 = (rbx + rbw + 7) \ 4: jy0 = rby - 4: jy1 = rby + rbh + 3
	IF jr0 < 0 THEN jr0 = 0
	IF jr1 > 79 THEN jr1 = 79
	IF jy0 < 0 THEN jy0 = 0
	IF jy1 > 199 THEN jy1 = 199
	IF (jy1 - jy0 + 1) * (jr1 - jr0 + 1) > 450 THEN jy0 = jy1 + 1 - 450 \ (jr1 - jr0 + 1)
	DEF SEG = VARSEG(cga%(0))
	k = 0
	FOR y = jy0 TO jy1
		so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
		FOR b = jr0 TO jr1: jsv(k) = PEEK(so + b): k = k + 1: NEXT
	NEXT
	DEF SEG
	CALL M3Poke(cga%(), jart(), jmsk(), rbx, rby, rbw, rbh)
	jbx = rbx: jby = rby: jbw = rbw: jbh = rbh
	CALL C3dMark("james3d: feet" + STR$(jfx) + STR$(jfy) + ", heading" + STR$(INT(jyaw * 57.3)) + " deg, box" + STR$(rbx) + STR$(rby) + STR$(rbw) + " x" + STR$(rbh))
END SUB

'----- M3JamPose: his breathing loop's frame now, at jtm (-1: no loop -- the rest pose)
FUNCTION M3JamPose%
	DIM g AS INTEGER
	M3JamPose% = -1
	IF jnfr = 0 THEN EXIT FUNCTION
	jtm = jtm - jilen * INT(jtm / jilen)
	g = jnfr - 1
	DO WHILE g > 0 AND jicum(g) > jtm: g = g - 1: LOOP
	M3JamPose% = g
END FUNCTION

'----- M3JamDark: the segment of C3DEDGI's table -- 256 flags at its offset 0, 1 for a colour
'----- that is black in the hall (the box's empty 0, and each of his texels his colour table
'----- puts on the hall's colour 0), C3DEDGI's own word after them. Built when first wanted
'----- and again when a REDIM has moved jdk to another 16-byte alignment
FUNCTION M3JamDark%
	DIM n AS LONG, al AS INTEGER, i AS INTEGER, o AS LONG, fl(0 TO 255) AS INTEGER
	n = VARSEG(jdk(0)): IF n < 0 THEN n = n + 65536
	o = VARPTR(jdk(0)): IF o < 0 THEN o = o + 65536
	n = n * 16 + o: al = (16 - (n AND 15)) AND 15
	IF al <> jdkal THEN
		DEF SEG = VARSEG(jlut(0))
		FOR i = 16 TO 254: IF PEEK(VARPTR(jlut(0)) + i) = 128 THEN fl(i) = 1
		NEXT
		DEF SEG = VARSEG(jdk(0))
		fl(0) = 1
		FOR i = 0 TO 255: POKE o + al + i, fl(i): NEXT
		DEF SEG
		jdkal = al
	END IF
	n = (n + al) \ 16: IF n > 32767 THEN n = n - 65536
	M3JamDark% = n
END FUNCTION

'----- M3JamRender: James in pose jpose -> jart/jmsk, the box rbx, rby, rbw, rbh
SUB M3JamRender
	m3who = 1
	IF jpose >= 0 THEN CALL M3Render(jfx, jfy, jyaw, 1000 + jpose) ELSE CALL M3Render(jfx, jfy, jyaw, -1)
	m3who = 0
END SUB

'----- M3JamDraw: James in his new pose up in the hall -- the clean hall back in the
'----- snapshot round him, him put into it (he stays there: the man's frames are drawn over
'----- the snapshot), and the rows over his old and new box redrawn with the man (in front:
'----- nearer the door) put over him for the redraw when their boxes meet
SUB M3JamDraw (v&, cga%(), lut%(), row%())
	DIM x0 AS INTEGER, y0 AS INTEGER, x1 AS INTEGER, y1 AS INTEGER, y AS INTEGER, b AS INTEGER, k AS INTEGER
	DIM sbs AS LONG, so AS LONG, mb0 AS INTEGER, mb1 AS INTEGER, mm AS INTEGER
	DIM sv(0 TO 959) AS INTEGER
	DEF SEG = VARSEG(cga%(0)): sbs = VARPTR(cga%(0)): IF sbs < 0 THEN sbs = sbs + 65536
	k = 0
	FOR y = jy0 TO jy1
		so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
		FOR b = jr0 TO jr1: POKE so + b, jsv(k): k = k + 1: NEXT
	NEXT
	DEF SEG
	CALL M3JamRender
	CALL M3Poke(cga%(), jart(), jmsk(), rbx, rby, rbw, rbh)
	x0 = rbx: y0 = rby: x1 = rbx + rbw - 1: y1 = rby + rbh - 1
	IF jbx < x0 THEN x0 = jbx
	IF jby < y0 THEN y0 = jby
	IF jbx + jbw - 1 > x1 THEN x1 = jbx + jbw - 1
	IF jby + jbh - 1 > y1 THEN y1 = jby + jbh - 1
	jbx = rbx: jby = rby: jbw = rbw: jbh = rbh
	'----- the man over him for the redraw (his pair is still the one shown at hb*)
	mm = 0
	IF hbw > 0 THEN
		IF hbx <= x1 AND hbx + hbw - 1 >= x0 AND hby <= y1 AND hby + hbh - 1 >= y0 THEN mm = 1
	END IF
	IF mm THEN
		mb0 = hbx \ 4: mb1 = (hbx + hbw - 1) \ 4
		IF (mb1 - mb0 + 1) * hbh > 960 THEN mm = 0
	END IF
	IF mm THEN
		DEF SEG = VARSEG(cga%(0))
		k = 0
		FOR y = hby TO hby + hbh - 1
			so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
			FOR b = mb0 TO mb1: sv(k) = PEEK(so + b): k = k + 1: NEXT
		NEXT
		DEF SEG
		CALL M3Poke(cga%(), art(), msk(), hbx, hby, hbw, hbh)
	END IF
	CALL CgaRows(v&, cga%(), lut%(), row%(), y0, y1, x0, x1)
	IF mm THEN
		DEF SEG = VARSEG(cga%(0))
		k = 0
		FOR y = hby TO hby + hbh - 1
			so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
			FOR b = mb0 TO mb1: POKE so + b, sv(k): k = k + 1: NEXT
		NEXT
		DEF SEG
	END IF
END SUB

'----- Man3dHallOp: the hall scene, drawn in mode 13h through GAME6 (v the DC, cga/lut/row
'----- its ENTER.PIC snapshot and tables, cm the colour map):
'----- 0 = he walks in from the door (feet 158, 180) to just inside (HSTOPY), up the hall
'-----     at the game's walking pace, his strides paced like GAME5 PStepP's -- each half
'-----     cycle (a footstep, the game's click) in hk frames, each drawn while the note
'-----     before it plays, hk 2..4 by what a frame costs (the footsteps timed start to
'-----     start) -- then steps round to face up-right, to James (M3Turn's turn)
'----- 4 = the idle while the talk waits (redrawn when its frame changes)
'----- 5 = him freed. (tc is not used: GAME6's walk loop starts at the talk)
SUB Man3dHallOp (op%, v&, cga%(), lut%(), row%(), cm%(), tc%)
	DIM q AS SINGLE, f AS INTEGER, j AS INTEGER, n AS INTEGER, c AS INTEGER, g AS INTEGER, wf AS INTEGER
	DIM tn AS SINGLE, d AS SINGLE, wx AS SINGLE, z0 AS SINGLE, z1 AS SINGLE, z AS SINGLE, u AS SINGLE
	DIM s AS INTEGER, nst AS INTEGER, hs AS SINGLE, nl AS SINGLE, dt AS SINGLE, ph AS SINGLE
	IF m3on = 0 THEN EXIT SUB
	SELECT CASE op%
	CASE 0
		CALL M3Floor(158, 180, wx, z0): CALL M3Floor(158, HSTOPY, wx, z1)
		'----- footsteps: half his cycle each, at 85 units a second
		nst = CINT((z1 - z0) / (wcyc / 32)): IF nst < 1 THEN nst = 1
		hs = (z1 - z0) / nst / 85
		hk = 2: ht0 = TIMER
		FOR s = 0 TO nst - 1
			nl = hs * 18.2 / hk
			FOR j = 1 TO hk
				u = (s + j / hk) / nst
				z = z0 + (z1 - z0) * u: hfy = RCY + 256 * RCH / z
				ph = (s + j / hk) * .5: q = (ph - INT(ph)) * wcyc
				f = wnf - 1
				DO WHILE f > 0 AND wcum(f) > q: f = f - 1: LOOP
				CALL M3Render(158, hfy, 3.1416, f)
				CALL M3HallShow(v&, cga%(), lut%(), row%(), cm%())
				IF j = 1 THEN SOUND 100, .1
				SOUND 32676, nl
			NEXT
			'----- (this footstep ran long: a frame fewer; on time: one more, up to 4)
			tn = TIMER: dt = tn - ht0: IF dt < 0 THEN dt = dt + 86400
			ht0 = tn
			IF dt > hs * 1.25 AND hk > 1 THEN
				hk = hk - 1
			ELSEIF dt < hs * 1.1 AND hk < 4 THEN
				hk = hk + 1
			END IF
		NEXT
		'----- turned up-right to James, the turning step to his left
		c = tcf0: n = 2
		FOR j = 1 TO n
			wf = -1
			IF inc > 0 AND c >= 0 THEN
				q = ilen(c) * j / n
				g = icst(c) + icnt(c) - 1
				DO WHILE g > icst(c) AND icum(g) > q: g = g - 1: LOOP
				wf = 1000 + g
			END IF
			CALL M3Render(158, hfy, 3.1416 + .7854 * j / n, wf)
			CALL M3HallShow(v&, cga%(), lut%(), row%(), cm%())
			SOUND 32676, 1
		NEXT
		hyaw = 3.927: m3pose = -2: itl = TIMER
		CALL M3IdleReset
	CASE 4
		IF inc = 0 THEN EXIT SUB
		tn = TIMER: d = tn - itl: IF d < 0 THEN d = d + 86400
		IF d < .05 THEN EXIT SUB
		itl = tn: IF d > .5 THEN d = .055
		'----- James breathes on (his own time in the loop), drawn when his frame changes
		IF jok THEN
			jtm = jtm + d * 30: g = M3JamPose%
			IF g <> jpose THEN jpose = g: CALL M3JamDraw(v&, cga%(), lut%(), row%())
		END IF
		g = M3IdlePose%(d * 30)
		IF g = m3pose THEN EXIT SUB
		m3pose = g
		CALL M3Render(158, hfy, hyaw, 1000 + g)
		CALL M3HallShow(v&, cga%(), lut%(), row%(), cm%())
	CASE 5
		CALL Man3dFree
	END SELECT
	'----- (M3DUMP=11, testing: the VGA screen turned to James, then idling in the talk ->
	'----- M3HALL1..3.PIC (BSAVE of A000), the walk's frames a footstep logged)
	IF m3dump = 11 THEN
		dumpn = dumpn + 1
		IF op% = 0 OR (op% = 4 AND dumpn MOD 12 = 0 AND dumpn < 200) THEN
			cntS = cntS + 1
			IF cntS <= 3 THEN
				DEF SEG = &HA000: BSAVE "M3HALL" + LTRIM$(STR$(cntS)) + ".PIC", 0, 64000: DEF SEG
				CALL C3dMark("hall shot" + STR$(cntS) + ": op" + STR$(op%) + ", frames a footstep" + STR$(hk))
			END IF
		END IF
	END IF
END SUB

'----- M3HallShow: the frame just rendered up in the hall, without a flicker: his pair put
'----- into GAME6's CGA snapshot of the hall (the same 2-bit pixels: mask 0 = his), the rows
'----- covering his last box and this one redrawn from it at once (CgaRows: each pixel goes
'----- straight from the old picture to the new -- restoring the old box first and then
'----- drawing him pixel by pixel left him missing for ~40 ms on the 486), the snapshot's
'----- bytes put back
SUB M3HallShow (v&, cga%(), lut%(), row%(), cm%())
	DIM x0 AS INTEGER, y0 AS INTEGER, x1 AS INTEGER, y1 AS INTEGER, r AS INTEGER, b AS INTEGER, p AS INTEGER
	DIM bpr AS INTEGER, bx0 AS INTEGER, bx1 AS INTEGER, nb AS INTEGER, k AS INTEGER, x AS INTEGER, y AS INTEGER
	DIM ab AS INTEGER, mb AS INTEGER, sh AS INTEGER, sb AS INTEGER, so AS LONG, sbs AS LONG, ao AS LONG, mo AS LONG
	DIM sv(0 TO 959) AS INTEGER, dv(0 TO 3) AS INTEGER
	dv(0) = 64: dv(1) = 16: dv(2) = 4: dv(3) = 1
	'----- the snapshot's bytes under his box, kept
	bx0 = rbx \ 4: bx1 = (rbx + rbw - 1) \ 4: nb = bx1 - bx0 + 1
	IF nb * rbh > 960 THEN EXIT SUB
	DEF SEG = VARSEG(cga%(0)): sbs = VARPTR(cga%(0)): IF sbs < 0 THEN sbs = sbs + 65536
	k = 0
	FOR r = 0 TO rbh - 1
		y = rby + r: so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
		FOR b = bx0 TO bx1: sv(k) = PEEK(so + b): k = k + 1: NEXT
	NEXT
	DEF SEG
	'----- his pixels into it
	CALL M3Poke(cga%(), art(), msk(), rbx, rby, rbw, rbh)
	'----- the rows over both boxes from the snapshot, at once
	x0 = rbx: y0 = rby: x1 = rbx + rbw - 1: y1 = rby + rbh - 1
	IF hbw > 0 THEN
		IF hbx < x0 THEN x0 = hbx
		IF hby < y0 THEN y0 = hby
		IF hbx + hbw - 1 > x1 THEN x1 = hbx + hbw - 1
		IF hby + hbh - 1 > y1 THEN y1 = hby + hbh - 1
	END IF
	DEF SEG
	CALL CgaRows(v&, cga%(), lut%(), row%(), y0, y1, x0, x1)
	'----- the snapshot as it was
	DEF SEG = VARSEG(cga%(0))
	k = 0
	FOR r = 0 TO rbh - 1
		y = rby + r: so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
		FOR b = bx0 TO bx1: POKE so + b, sv(k): k = k + 1: NEXT
	NEXT
	DEF SEG
	hbx = rbx: hby = rby: hbw = rbw: hbh = rbh
END SUB

'----- M3Poke: a GET pair (a art, m mask: 4 header bytes, rows of (2w + 7) \ 8 bytes) put
'----- into GAME6's CGA snapshot at (bx, by) -- the pixels where the mask is 0
SUB M3Poke (cga%(), a%(), m%(), bx%, by%, bw%, bh%)
	DIM r AS INTEGER, p AS INTEGER, x AS INTEGER, y AS INTEGER, k AS INTEGER, bpr AS INTEGER
	DIM ab AS INTEGER, mb AS INTEGER, sh AS INTEGER, sb AS INTEGER, so AS LONG, sbs AS LONG, ao AS LONG, mo AS LONG
	DIM dv(0 TO 3) AS INTEGER
	dv(0) = 64: dv(1) = 16: dv(2) = 4: dv(3) = 1
	bpr = (bw% * 2 + 7) \ 8
	sbs = VARPTR(cga%(0)): IF sbs < 0 THEN sbs = sbs + 65536
	ao = VARPTR(a%(0)): IF ao < 0 THEN ao = ao + 65536
	mo = VARPTR(m%(0)): IF mo < 0 THEN mo = mo + 65536
	FOR r = 0 TO bh% - 1
		y = by% + r: so = sbs + (y \ 2) * 80 + (y AND 1) * 8192
		FOR p = 0 TO bw% - 1
			IF (p AND 3) = 0 THEN
				DEF SEG = VARSEG(m%(0)): mb = PEEK(mo + 4 + r * bpr + p \ 4)
				DEF SEG = VARSEG(a%(0)): ab = PEEK(ao + 4 + r * bpr + p \ 4)
				DEF SEG = VARSEG(cga%(0))
			END IF
			sh = dv(p AND 3)
			IF ((mb \ sh) AND 3) = 0 THEN
				x = bx% + p: k = dv(x AND 3)
				sb = PEEK(so + x \ 4)
				POKE so + x \ 4, (sb AND (255 - 3 * k)) OR (((ab \ sh) AND 3) * k)
			END IF
		NEXT
	NEXT
	DEF SEG
END SUB
'----- M3Shot: the CGA screen as it is -> M3SHOTk.PIC (BSAVE of B800, 16 KB)
SUB M3Shot (k%)
	DEF SEG = &HB800
	BSAVE "M3SHOT" + LTRIM$(STR$(k%)) + ".PIC", 0, 16384
	DEF SEG
END SUB

'----- M3Prof: (M3DUMP=4) the costs, by TIMER over many calls -> C3D.LOG, then the game ends
SUB M3Prof (px!, py!, d$)
	DIM i AS INTEGER, t0 AS SINGLE, s AS STRING, wx AS SINGLE, wz AS SINGLE, k AS SINGLE, c AS SINGLE
	t0 = TIMER: FOR i = 1 TO 20: CALL M3Render(px! + 15, py! + 30, 0, -1): NEXT
	s = "render stand" + STR$(INT((TIMER - t0) * 50)) + " ms;"
	t0 = TIMER: FOR i = 1 TO 20: CALL M3Render(px! + 15, py! + 30, 4.7, i MOD wnf): NEXT
	s = s + " render walk" + STR$(INT((TIMER - t0) * 50)) + " ms;"
	DIM ov(0) AS INTEGER
	t0 = TIMER: FOR i = 1 TO 20: CALL Man3dStand(d$, px!, py!, ov()): NEXT
	s = s + " stand draw" + STR$(INT((TIMER - t0) * 50)) + " ms;"
	t0 = TIMER: FOR i = 1 TO 5: CALL PShiftB(i AND 3): NEXT
	s = s + " shadow shift" + STR$(INT((TIMER - t0) * 200)) + " ms;"
	t0 = TIMER
	FOR i = 1 TO 100: CALL M3Floor(px! + 15, py! + 30, wx, wz): k = M3K!(wz): c = COS(k) + SIN(k): NEXT
	s = s + " float maths" + STR$(INT((TIMER - t0) * 10)) + " ms; box" + STR$(m3bw) + " x" + STR$(m3bh)
	CALL C3dMark(s)
END SUB

'----- M3WalkTest: (M3DUMP=2) 24 steps to the right from where he stands, through
'----- Man3dStep/Man3dStepOff like PStepP, a shot at step 12, then him standing again
SUB M3WalkTest (px!, py!, d$)
	DIM i AS INTEGER, x AS SINGLE
	PUT (m3bx, m3by), bgs(0), PSET: m3drawn = 0
	DIM j AS INTEGER, k AS INTEGER, t0 AS SINGLE, ex AS SINGLE, ov(0) AS INTEGER
	'----- (as GAME5 PStepP walks: the frames, their waits, the click; timed)
	t0 = TIMER
	FOR i = 0 TO 47
		x = px! + (i MOD 24) * 3
		k = Man3dSubs%(1.12)
		ex = ex + sdT
		FOR j = 1 TO k
			CALL Man3dStep(x, py!, 302, j, k, ov())
			CALL Man3dStepShow
			IF j = 1 THEN SOUND 3000, .1
			SOUND 32676, Man3dWait!
		NEXT
		IF i = 12 THEN CALL M3Shot(2)
	NEXT
	CALL C3dMark("walk test 48 steps" + STR$(TIMER - t0) + " s, sprite's" + STR$(ex) + " s, frames/step" + STR$(sk))
	CALL Man3dStand(d$, px!, py!, ov())
END SUB

'----- Man3dSubs: a walk step (GAME5 PStepP) starts -- it gets k frames, each followed
'----- by a silent note of the step's 2 sdur ticks / k (the sprite's step: a .1 click and
'----- two sdur notes). QB's foreground SOUND returns once its note has STARTED (it
'----- waits only for the one before -- tools\SNDPROBE), so each frame renders while the
'----- note before it plays and the step keeps the sprite's length as long as a frame
'----- fits in a note. k is learnt: blocks of 12 walking steps timed start to start, over
'----- several walks (a walk's first step left out: its first frame has no note to hide in)
'----- (TIMER's 55 ms steps even out over them) against what they should take -- over
'----- 8% long: one frame fewer, and never more again; under 5%: one more (up to 4; a block is
'----- read in whole ticks, 28 or 29 of 28.1 for 12 sprite steps)
FUNCTION Man3dSubs% (sdur!)
	DIM tn AS SINGLE, dt AS SINGLE, r AS SINGLE
	tn = TIMER
	IF kk = 0 THEN kk = 2: kcap = 4
	dt = tn - tS: IF dt < 0 THEN dt = dt + 86400
	IF sk > 0 AND dt < 1 THEN
		IF bCont THEN bAcc = bAcc + dt: bExp = bExp + sdT: bN = bN + 1
		bCont = 1
		IF bN >= 12 THEN
			r = bAcc / bExp - 1
			CALL C3dMark("man3d walk:" + STR$(kk) + " frames/step, 12 steps" + STR$(bAcc) + " s of" + STR$(bExp))
			IF r > .08 AND kk > 1 THEN
				kk = kk - 1: kcap = kk
			ELSEIF r < .05 AND kk < kcap THEN
				kk = kk + 1
			END IF
			bN = 0: bAcc = 0: bExp = 0
		END IF
	ELSE
		bCont = 0
	END IF
	tS = tn
	sdT = (.1 + 2 * sdur!) / 18.2
	sk = kk
	wq = 2 * sdur! / sk
	Man3dSubs% = sk
END FUNCTION

'----- Man3dWait: the silent note after each frame (ticks)
FUNCTION Man3dWait!
	Man3dWait! = wq
END FUNCTION

'----- Man3dStep: frame j of k of a walk step to sprite position (x, y): his feet
'----- slide from where the last step ended (a new walk: from here), the heading
'----- along the step (a new walk: the walk cache's direction slot, ofs \ 151), the
'----- walk cycle on by the floor distance covered (over his scale, so the feet keep
'----- their hold). Rendered only: Man3dStepShow puts it on the screen
SUB Man3dStep (x!, y!, ofs%, j%, k%, ovf%())
	DIM fx AS SINGLE, fy AS SINGLE, wx AS SINGLE, wz AS SINGLE, ox AS SINGLE, oz AS SINGLE, dx AS SINGLE, dz AS SINGLE
	DIM dd AS SINGLE, q AS LONG, f AS INTEGER, tn AS SINGLE, cfx AS SINGLE, cfy AS SINGLE
	cfx = x! + 15: cfy = y! + 30
	IF j% = 1 THEN
		tn = TIMER
		IF ABS(tn - lt) < 1 AND ABS(cfx - lfx) + ABS(cfy - lfy) < 16 THEN
			sx0 = lfx: sy0 = lfy
			CALL M3Floor(lfx, lfy, ox, oz): CALL M3Floor(cfx, cfy, wx, wz)
			dx = wx - ox: dz = wz - oz
			IF ABS(dx) + ABS(dz) > .3 THEN syaw = M3Atn2!(-dx, -dz) ELSE syaw = lyaw
		ELSEIF m3er AND ABS(cfx - m3fx) + ABS(cfy - m3fy) < 16 THEN
			'----- a new walk from where he stood: the way to the first step, and turned
			'----- to it first when it is well off his facing (35 degrees)
			sx0 = m3fx: sy0 = m3fy
			CALL M3Floor(m3fx, m3fy, ox, oz): CALL M3Floor(cfx, cfy, wx, wz)
			dx = wx - ox: dz = wz - oz
			IF ABS(dx) + ABS(dz) > .3 THEN syaw = M3Atn2!(-dx, -dz) ELSE syaw = M3DigYaw!(MID$("28641379", ofs% \ 151 + 1, 1))
			IF ABS(M3Dif!(m3yaw, syaw)) > .6 THEN CALL M3Turn(m3fx, m3fy, m3yaw, syaw, ovf%())
		ELSE
			sx0 = cfx: sy0 = cfy
			syaw = M3DigYaw!(MID$("28641379", ofs% \ 151 + 1, 1))
		END IF
		pfx = sx0: pfy = sy0: m3er = 0
		CALL M3IdleReset
	END IF
	fx = sx0 + (cfx - sx0) * j% / k%: fy = sy0 + (cfy - sy0) * j% / k%
	CALL M3Floor(pfx, pfy, ox, oz): CALL M3Floor(fx, fy, wx, wz)
	dx = wx - ox: dz = wz - oz: dd = SQR(dx * dx + dz * dz)
	aph = aph + CLNG(dd * 16 / M3K!(wz))
	pfx = fx: pfy = fy
	IF j% = k% THEN lfx = cfx: lfy = cfy: lt = TIMER: lyaw = syaw
	m3fx = fx: m3fy = fy: m3yaw = syaw
	q = aph MOD wcyc: IF q < 0 THEN q = q + wcyc
	f = wnf - 1
	DO WHILE f > 0 AND wcum(f) > q: f = f - 1: LOOP
	CALL M3Render(fx, fy, syaw, f)
END SUB

'----- Man3dStepShow: the frame just rendered onto the screen -- the walk's last frame
'----- taken away (its save-under) only now, so he never blinks out while rendering
SUB Man3dStepShow
	IF m3stp THEN PUT (m3sx, m3sy), bgw(0), PSET
	m3sx = rbx: m3sy = rby: m3sw = rbw: m3sh = rbh
	GET (m3sx, m3sy)-(m3sx + m3sw - 1, m3sy + m3sh - 1), bgw(0)
	PUT (m3sx, m3sy), msk(0), AND
	PUT (m3sx, m3sy), art(0), OR
	m3stp = 1
END SUB

'----- Man3dStepOff: the step's save-under put back (and its box, for overlays)
SUB Man3dStepOff
	IF m3stp THEN PUT (m3sx, m3sy), bgw(0), PSET: m3stp = 0
END SUB

'----- M3Render: him at feet pixel (fx, fy), heading yaw, walk frame wf (-1 the rest
'----- pose, 1000 + g idle frame g) -> art/msk, his box rbx, rby, rbw, rbh
SUB M3Render (fx!, fy!, yaw!, wf%)
	DIM wx AS SINGLE, wz AS SINGLE, k AS SINGLE, bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER, w AS INTEGER, h AS INTEGER
	DIM p AS LONG, tm AS INTEGER, mo AS INTEGER
	CALL M3Floor(fx!, fy!, wx, wz)
	k = M3K!(wz)
	'----- the pose: the walk frame's bones on the rest pose (C3DSKIN), or the rest pose
	IF wf% >= 0 THEN
		prs(0) = VARSEG(mx(0)): prs(1) = VARPTR(mx(0)): prs(2) = VARSEG(my(0)): prs(3) = VARPTR(my(0))
		prs(4) = VARSEG(mz(0)): prs(5) = VARPTR(mz(0))
		prs(6) = VARSEG(kx(0)): prs(7) = VARPTR(kx(0)): prs(8) = VARSEG(ky(0)): prs(9) = VARPTR(ky(0))
		prs(10) = VARSEG(kz(0)): prs(11) = VARPTR(kz(0)): prs(12) = nv
		prs(13) = VARSEG(ibw(0)): prs(14) = VARPTR(ibw(0))
		IF m3who THEN
			prs(0) = VARSEG(jmx(0)): prs(1) = VARPTR(jmx(0)): prs(2) = VARSEG(jmy(0)): prs(3) = VARPTR(jmy(0))
			prs(4) = VARSEG(jmz(0)): prs(5) = VARPTR(jmz(0)): prs(12) = jnv
			prs(13) = VARSEG(jibw(0)): prs(14) = VARPTR(jibw(0))
		END IF
		IF wf% >= 1000 THEN
			CALL M3IdleMx(wf% - 1000)
			prs(15) = VARSEG(imx(0)): prs(16) = VARPTR(imx(0))
		ELSE
			mo = wf% * 156: prs(15) = VARSEG(wfm(mo)): prs(16) = VARPTR(wfm(mo))
		END IF
		DEF SEG = VARSEG(oSkn(0))
		CALL ABSOLUTE(BYVAL VARSEG(prs(0)), BYVAL VARPTR(prs(0)), VARPTR(oSkn(0)))
		DEF SEG
		prr(0) = VARSEG(kx(0)): prr(1) = VARPTR(kx(0)): prr(2) = VARSEG(ky(0)): prr(3) = VARPTR(ky(0))
		prr(4) = VARSEG(kz(0)): prr(5) = VARPTR(kz(0))
	ELSEIF m3who THEN
		prr(0) = VARSEG(jmx(0)): prr(1) = VARPTR(jmx(0)): prr(2) = VARSEG(jmy(0)): prr(3) = VARPTR(jmy(0))
		prr(4) = VARSEG(jmz(0)): prr(5) = VARPTR(jmz(0))
	ELSE
		prr(0) = VARSEG(mx(0)): prr(1) = VARPTR(mx(0)): prr(2) = VARSEG(my(0)): prr(3) = VARPTR(my(0))
		prr(4) = VARSEG(mz(0)): prr(5) = VARPTR(mz(0))
	END IF
	'----- turned to yaw and the faces sorted far to near (C3DROT)
	prr(6) = VARSEG(rx(0)): prr(7) = VARPTR(rx(0)): prr(8) = VARSEG(ry(0)): prr(9) = VARPTR(ry(0))
	prr(10) = VARSEG(rz(0)): prr(11) = VARPTR(rz(0)): prr(12) = nv
	prr(13) = CINT(COS(yaw!) * 256): prr(14) = CINT(SIN(yaw!) * 256)
	prr(15) = VARSEG(fa(0)): prr(16) = VARPTR(fa(0)): prr(17) = VARSEG(ord(0)): prr(18) = VARPTR(ord(0)): prr(19) = nf
	IF m3who THEN prr(15) = VARSEG(jfa(0)): prr(16) = VARPTR(jfa(0)): prr(19) = jnf: prr(12) = jnv
	prr(20) = VARSEG(lnk(0)): prr(21) = VARPTR(lnk(0)): prr(22) = VARSEG(head(0)): prr(23) = VARPTR(head(0))
	prr(24) = 256: prr(25) = 0
	DEF SEG = VARSEG(oRot(0))
	CALL ABSOLUTE(BYVAL VARSEG(prr(0)), BYVAL VARPTR(prr(0)), VARPTR(oRot(0)))
	DEF SEG
	'----- projected through the room camera at his depth scale (C3DPRJ)
	prq(0) = VARSEG(rx(0)): prq(1) = VARPTR(rx(0)): prq(2) = VARSEG(ry(0)): prq(3) = VARPTR(ry(0))
	prq(4) = VARSEG(rz(0)): prq(5) = VARPTR(rz(0))
	prq(6) = VARSEG(vt(0)): prq(7) = VARPTR(vt(0)): prq(8) = prq(6): prq(9) = prq(7) + 2: prq(10) = nv
	IF m3who THEN prq(6) = VARSEG(jvt(0)): prq(7) = VARPTR(jvt(0)): prq(8) = prq(6): prq(9) = prq(7) + 2: prq(10) = jnv
	p = CLNG(wx * 16): CALL M3Split(p, prq(11), prq(12))
	IF m3who THEN p = -CLNG(RCH * 16) - CLNG(jymn * k) ELSE p = -CLNG(RCH * 16) - CLNG(ymn * k)
	CALL M3Split(p, prq(13), prq(14))
	p = CLNG(wz * 16): CALL M3Split(p, prq(15), prq(16))
	prq(21) = 8: prq(22) = CINT(RCX * 16): prq(23) = CINT(RCY * 16): prq(24) = CINT(RFX * 16): prq(25) = 0
	prq(26) = CINT(k * 256): prq(27) = 0
	DEF SEG = VARSEG(oPrj(0))
	CALL ABSOLUTE(BYVAL VARSEG(prq(0)), BYVAL VARPTR(prq(0)), VARPTR(oPrj(0)))
	DEF SEG
	'----- his box (3 px round for the outline, 1 without), on the screen, at most the byte box
	IF M3OUTL THEN
		bx = prq(17) \ 16 - 3: by = prq(19) \ 16 - 3: ex = prq(18) \ 16 + 4: ey = prq(20) \ 16 + 4
	ELSE
		bx = prq(17) \ 16 - 1: by = prq(19) \ 16 - 1: ex = prq(18) \ 16 + 2: ey = prq(20) \ 16 + 2
	END IF
	IF bx < 0 THEN bx = 0
	IF by < 0 THEN by = 0
	IF ex > 319 THEN ex = 319
	IF ey > 199 THEN ey = 199
	IF ex - bx + 1 > MAXW THEN ex = bx + MAXW - 1
	IF ey - by + 1 > MAXH THEN by = ey - MAXH + 1
	IF m3who AND ex - bx + 1 > 32 THEN ex = bx + 31
	w = ex - bx + 1: h = ey - by + 1
	'----- rendered into the byte box (C3DTRI; unlit: one band, the texture's segment)
	CALL M3TexSeg
	prm(0) = VARSEG(buf(0)): prm(1) = VARPTR(buf(0)): prm(2) = w: prm(3) = h
	prm(4) = VARSEG(bt(0)): prm(23) = VARPTR(bt(0))
	prm(5) = VARSEG(vt(0)): prm(6) = VARPTR(vt(0))
	IF m3who THEN prm(5) = VARSEG(jvt(0)): prm(6) = VARPTR(jvt(0))
	prm(13) = VARSEG(fa(0)): prm(14) = VARPTR(fa(0)): prm(15) = 0: prm(16) = VARPTR(fband(0))
	prm(17) = VARSEG(ord(0)): prm(18) = VARPTR(ord(0)): prm(19) = nf
	IF m3who THEN prm(13) = VARSEG(jfa(0)): prm(14) = VARPTR(jfa(0)): prm(19) = jnf
	prm(20) = bx * 16: prm(21) = by * 16: prm(22) = 0: prm(24) = 64: prm(25) = 384 OR &H8000
	DEF SEG = VARSEG(oTri(0))
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), VARPTR(oTri(0)))
	DEF SEG
	'----- (James: his black's edge on the black round him in the outline colour, C3DEDGI)
	IF m3who AND oEdi(0) <> 0 THEN
		tm = 16 + 15 * 256: mo = M3JamDark%
		DEF SEG = VARSEG(oEdi(0))
		CALL ABSOLUTE(BYVAL VARSEG(buf(0)), BYVAL VARPTR(buf(0)), BYVAL w, BYVAL w, BYVAL h, BYVAL tm, BYVAL mo, VARPTR(oEdi(0)))
		DEF SEG
	END IF
	'----- the outline round him (C3DEDGO: the box's 0s next to him become 15)
	IF M3OUTL THEN
		tm = 16 + 15 * 256
		DEF SEG = VARSEG(oEdg(0))
		CALL ABSOLUTE(BYVAL VARSEG(buf(0)), BYVAL VARPTR(buf(0)), BYVAL w, BYVAL w, BYVAL h, BYVAL tm, VARPTR(oEdg(0)))
		DEF SEG
	END IF
	'----- the CGA pair in this room's colours, the box left clear (C3DCGA)
	DEF SEG = VARSEG(oCga(0))
	IF m3who THEN
		CALL ABSOLUTE(BYVAL VARSEG(buf(0)), BYVAL VARPTR(buf(0)), BYVAL w, BYVAL h, BYVAL VARSEG(jlut(0)), BYVAL VARPTR(jlut(0)), BYVAL VARSEG(jart(0)), BYVAL VARPTR(jart(0)), BYVAL VARSEG(jmsk(0)), BYVAL VARPTR(jmsk(0)), VARPTR(oCga(0)))
	ELSE
		CALL ABSOLUTE(BYVAL VARSEG(buf(0)), BYVAL VARPTR(buf(0)), BYVAL w, BYVAL h, BYVAL VARSEG(lut(0)), BYVAL VARPTR(lut(0)), BYVAL VARSEG(art(0)), BYVAL VARPTR(art(0)), BYVAL VARSEG(msk(0)), BYVAL VARPTR(msk(0)), VARPTR(oCga(0)))
	END IF
	DEF SEG
	rbx = bx: rby = by: rbw = w: rbh = h
END SUB

'----- M3TexSeg: the texture's segment for the band table -- the far heap may have
'----- moved tex() since the load (other modules REDIM); if the move broke the
'----- paragraph alignment the texels are shifted to a new one
SUB M3TexSeg
	IF m3who THEN CALL M3TexAl(jtex(), jtalo) ELSE CALL M3TexAl(tex(), talo)
END SUB

'----- M3TexAl: M3TexSeg's work on texture t() (the man's or James's), al its alignment
SUB M3TexAl (t%(), al%)
	DIM n AS LONG, a2 AS INTEGER, i AS INTEGER, s AS STRING, sg AS LONG
	n = VARSEG(t%(0)): IF n < 0 THEN n = n + 65536
	n = n * 16 + VARPTR(t%(0))
	IF ((n + al%) AND 15) <> 0 THEN
		a2 = (16 - (n AND 15)) AND 15
		s = SPACE$(4096)
		DEF SEG = VARSEG(t%(0))
		FOR i = 0 TO 4095: MID$(s, i + 1, 1) = CHR$(PEEK(VARPTR(t%(0)) + al% + i)): NEXT
		FOR i = 0 TO 4095: POKE VARPTR(t%(0)) + a2 + i, ASC(MID$(s, i + 1, 1)): NEXT
		DEF SEG
		al% = a2
	END IF
	sg = (n + al%) \ 16: IF sg > 32767 THEN sg = sg - 65536
	FOR i = 0 TO 7: bt(i) = sg: NEXT
END SUB

'----- M3Floor: the floor point under feet pixel (fx, fy): z = 256 h / (y - cy),
'----- x = (x - cx) z / fx (units)
SUB M3Floor (fx!, fy!, wx!, wz!)
	DIM y AS SINGLE
	y = fy!: IF y < RCY + 2 THEN y = RCY + 2
	wz! = 256 * RCH / (y - RCY)
	wx! = (fx! - RCX) * wz! / RFX
END SUB

'----- M3K: his scale at depth z -- the art's perspective shrinks him to zNear/zFar
'----- at the back wall; drawn this much bigger he falls only to RBS there
FUNCTION M3K! (z!)
	DIM t AS SINGLE
	t = (z! - RZN) / (RZF - RZN)
	IF t < 0 THEN t = 0
	IF t > 1 THEN t = 1
	M3K! = RSC * (1 + (RBS - 1) * t) * z! / RZN
END FUNCTION

'----- M3DigYaw: the heading for a numpad facing on the screen (2 out of the room,
'----- 8 into it, 4 left, 6 right, 1 3 7 9 between) -- the yaw whose forward
'----- (-sin, -cos) points that way
FUNCTION M3DigYaw! (d$)
	SELECT CASE d$
	CASE "1": M3DigYaw! = .7854
	CASE "4": M3DigYaw! = 1.5708
	CASE "7": M3DigYaw! = 2.3562
	CASE "8": M3DigYaw! = 3.1416
	CASE "9": M3DigYaw! = 3.927
	CASE "6": M3DigYaw! = 4.7124
	CASE "3": M3DigYaw! = 5.4978
	CASE ELSE: M3DigYaw! = 0
	END SELECT
END FUNCTION

'----- M3Atn2: the angle of (x, y) in -pi..pi
FUNCTION M3Atn2! (y!, x!)
	IF x! > 0 THEN
		M3Atn2! = ATN(y! / x!)
	ELSEIF x! < 0 THEN
		IF y! >= 0 THEN M3Atn2! = ATN(y! / x!) + 3.14159 ELSE M3Atn2! = ATN(y! / x!) - 3.14159
	ELSE
		IF y! >= 0 THEN M3Atn2! = 1.5708 ELSE M3Atn2! = -1.5708
	END IF
END FUNCTION

'----- M3Split: a LONG as two INTEGER words (for the projection block)
SUB M3Split (v&, lo%, hi%)
	DIM l AS LONG
	l = v& AND &HFFFF&
	IF l > 32767 THEN lo% = l - 65536 ELSE lo% = l
	hi% = (v& - l) \ 65536
END SUB
