'----- MANWALK.BAS: the 3D man (CAR3D.MDL/BMP from tools\car3dcnv.ps1, a
'----- model made by tools\man3d.ps1 or an artist's FBX through
'----- tools\fbx2tds.ps1) standing on the intro's road scene, walked about
'----- with tank controls, the frame rate shown. The renderer is CAR3D.BAS's
'----- (the hand-assembled 386 routines of tools\build_car3d_asm.ps1); only
'----- the main program differs. Usage: MANWALK  (Esc quits)  MANWALK S
'----- (scripted: MANWLK1/2.BMP + MANWALK.LOG, for checking from the PC).
'----- Keys: Up/Down walk forward/back, Left/Right turn, Space puts a copy of
'----- the model where he stands (up to 7, to load the renderer), C clears
'----- them, V toggles the vertical-sync wait (the raw render rate shows), O
'----- cycles the outline (off, brown on his edge pixels, blue 1 px round
'----- him, blue 2 px, blue only where his black meets a black floor, the same inside his edge; MANWALK 2 or S2
'----- starts with that one), [ and ] its
'----- colour (the 16 CGA colours, blue to start with), F the flat-fill
'----- threshold (off, 2, 4, 6 px), G the
'----- quad gradient sharing (off, 24 px), A sets the copies walking in place.
'----- A second character (JAMES.MDL / .BMP, his walk JAMESW.ANI and idle clips
'----- JAMESI.ANI -- tools\manwalk.ps1 -Npc makes them, only the clips he may play):
'----- he stands in the room idling on his own clock; Tab drives him instead (the
'----- other one stays where he is, idling), C hides or shows him. Two characters
'----- at most (MAXI), so the copies (Space) are only for the man alone.
'----- The walk (MAN3D.ANI from tools\man3danim.ps1, frames of the model's
'----- vertices) plays while he walks, a frame per 1/nframes of a stride, so
'----- the planted foot stays put. Standing, he breathes (MANIDLE.ANI from
'----- tools\man3dfbx.ps1 -Idle -Import: the bones' matrices per frame, the
'----- rest pose skinned by C3DSKIN.OVL) and now and then fidgets -- looks
'----- round, checks his watch, scratches his head, taps a foot; walking or
'----- turning stops a fidget. Turning on the spot he pivots on one foot (his
'----- left turning left) and steps round with the other: the step clips play
'----- by the angle turned, a step per TURNDEG degrees, and he is moved so the
'----- planted foot stays put; let go mid-step and the step finishes.
'----- The mouse (INT 33h through C3DMSE.OVL, when a driver is loaded): a
'----- left click on the floor walks him there (turning on the spot first when
'----- it is well off his heading, steering on the way), a right click turns
'----- him to face the point; the arrow keys take over again. The cursor is
'----- drawn into the frame like the models (its old and new places restored
'----- from the backdrop). MANWALK W: a click to walk and one to face,
'----- scripted -> MANGO1/2.BMP and MANGO.LOG (where he ended against where
'----- the click was).
'----- In a room with a walk mask (ROOM.WLK from src\ART\Rooms\roomN_walk.png,
'----- tools\walkmask.ps1 makes a starter): where his feet may stand. A click
'----- finds a path on a floor grid (GCELL units a cell, a cell walkable when
'----- the mask is at its centre's place on screen): breadth first from where he
'----- stands, the nearest reachable cell when the click itself cannot be
'----- reached, the cells' path pulled straight where the floor between is clear;
'----- he walks the waypoints. The arrow keys stop at the mask's edge (sliding
'----- along it). MANWALK P: two scripted clicks round the furniture ->
'----- MANPATH1/2.BMP, MANPATH.LOG.
'----- The furniture in front (ROOM.OCC from src\ART\Rooms\roomN_front.png,
'----- tools\occmask.ps1 makes a starter): pieces of the backdrop, each with its
'----- mask and its depth (its floor line); the frame draws men and pieces far
'----- to near, a piece being its backdrop pixels put back under its mask
'----- (C3DMCPY.OVL), each man outlined as he is drawn -- so a man behind a
'----- piece is hidden by it, outline and all, and one in front is not.
'----- The room's things are the game's own (ROOM.PAC = ROOMn.PAC, edited with
'----- HAEDIT): hit points on a 4-pixel grid, each naming one of 25 objects with
'----- a verb, conditions and its text, and "-2,obj,x,y,dir" stand points (feet
'----- pixel, numpad facing). As the game does it, a left click is the action and
'----- a right click is look: the click's cell, else the nearest point within 6
'----- pixels, of an object with that verb that is open at the start (no item or
'----- flag needed). An action with a stand point walks him there and turns him
'----- its way (to the thing when no digit); a look, or an action without one,
'----- turns him to the thing; then its text, on two lines under the room (the
'----- PC's ROM font). MANWALK H: an action and a look -> MANHOT0..2.BMP, MANHOT.LOG.
'----- MANWALK I: the fidgets one after another, a shot of each
'----- (MANIDL1..4.BMP), MANIDLE.DMP (a pose's vertices), then a turn each way
'----- (MANTRN1/2.BMP).
DEFINT A-Z
'$INCLUDE: 'MANWALK.BI'
'$INCLUDE: 'UGL.BI'




'$DYNAMIC
'----- (the second index of the per-model arrays: the model slot, 0 the man, 1 the second
'----- character -- JAMES.MDL / .BMP / JAMESW.ANI / JAMESI.ANI, when they are there)
DIM mx(0 TO MAXV, 0 TO 1) AS INTEGER, my(0 TO MAXV, 0 TO 1) AS INTEGER, mz(0 TO MAXV, 0 TO 1) AS INTEGER
DIM nvm(0 TO 1) AS INTEGER, nfm(0 TO 1) AS INTEGER
'----- the walk: nframes x { x(nv), y(nv), z(nv) } (x16 units), slot 0's in afr, slot 1's
'----- in afr1; anf frames, a cycle of acyc x16 units; aph the driven one's place in it
'----- (the distance walked), afcur his frame (-1 = the rest pose); the other's own (A)
DIM afr(1) AS INTEGER, afr1(1) AS INTEGER, anf(0 TO 1) AS INTEGER, acyc(0 TO 1) AS INTEGER
DIM rx(0 TO MAXV) AS INTEGER, ry(0 TO MAXV) AS INTEGER, rz(0 TO MAXV) AS INTEGER
DIM SHARED sx(0 TO MAXV) AS INTEGER, sy(0 TO MAXV) AS INTEGER
DIM SHARED tu(0 TO MAXV) AS INTEGER, tv(0 TO MAXV) AS INTEGER
DIM fa(0 TO MAXF, 0 TO 1) AS Fac
DIM SHARED nx(0 TO MAXF) AS INTEGER, ny(0 TO MAXF) AS INTEGER, nz(0 TO MAXF) AS INTEGER
DIM SHARED fband(0 TO MAXF) AS INTEGER
DIM ord(0 TO MAXF) AS INTEGER
DIM SHARED lnk(0 TO MAXF) AS INTEGER, head(0 TO 255) AS INTEGER
DIM SHARED bgb(0 TO 31999) AS INTEGER
DIM SHARED wkb(0 TO 31999) AS INTEGER
'----- the placed copies: their rotated vertices and sort order (one Prep each,
'----- at placement; the first index varies fastest, so (0, i) starts a block
'----- the projection and the raster address directly), their place
DIM rxs(0 TO MAXV, 1 TO MAXI - 1) AS INTEGER, rys(0 TO MAXV, 1 TO MAXI - 1) AS INTEGER, rzs(0 TO MAXV, 1 TO MAXI - 1) AS INTEGER
DIM ords(0 TO MAXF, 1 TO MAXI - 1) AS INTEGER
DIM SHARED sxs(0 TO MAXV, 1 TO MAXI - 1) AS INTEGER, sys(0 TO MAXV, 1 TO MAXI - 1) AS INTEGER
'----- the interleaved vertices x,y,u,v (4 words each) the projection writes and
'----- the raster reads: one per model (u,v set once from tu/tv)
DIM SHARED vt(0 TO 4 * MAXV + 3) AS INTEGER, vts(0 TO 4 * MAXV + 3, 1 TO MAXI - 1) AS INTEGER
'----- the rasteriser's thresholds (1/16 px): faces smaller than flatT are
'----- filled flat with one texel; a quad's second triangle shorter than quadT
'----- shares the first one's texture gradients. F and G cycle them
DIM SHARED flatT AS INTEGER, quadT AS INTEGER, dotT AS INTEGER
DIM SHARED ibx(0 TO MAXI - 1) AS INTEGER, iby(0 TO MAXI - 1) AS INTEGER, iex(0 TO MAXI - 1) AS INTEGER, iey(0 TO MAXI - 1) AS INTEGER
DIM prr(0 TO 25) AS INTEGER
DIM SHARED ipx(0 TO MAXI - 1) AS LONG, ipy(0 TO MAXI - 1) AS LONG, ipz(0 TO MAXI - 1) AS LONG, ninst AS INTEGER, vsync AS INTEGER
DIM SHARED aph AS LONG, afcur AS INTEGER, ianim AS INTEGER, plyaw AS SINGLE
DIM SHARED iyaw(0 TO MAXI - 1) AS SINGLE, iph(0 TO MAXI - 1) AS LONG, ifr(0 TO MAXI - 1) AS INTEGER
'----- where each walk frame starts in the cycle (x16 units): the planted
'----- foot's travel frame by frame (MAN3D.ANI C3A2), even for a C3A1 file
DIM acum(0 TO 23, 0 TO 1) AS INTEGER
'----- the idle clips (MANIDLE.ANI): 13 bones x 12 words a frame in idm(), each
'----- vertex's bones in ibw() (low byte, high byte), the skinned pose in kx/ky/kz;
'----- clip c is frames icst(c).. (icnt of them, icum = each one's start in 1/30 s,
'----- ilen the clip's length, ilp loops); per model: its clip (0 = breathing),
'----- time in it, the wait for its next fidget (1/30 s) and its last fidget
DIM idm(1) AS INTEGER, idm1(1) AS INTEGER, ibw(0 TO MAXV, 0 TO 1) AS INTEGER
DIM kx(0 TO MAXV) AS INTEGER, ky(0 TO MAXV) AS INTEGER, kz(0 TO MAXV) AS INTEGER
DIM icum(0 TO 199, 0 TO 1) AS INTEGER, icst(0 TO 7, 0 TO 1) AS INTEGER, icnt(0 TO 7, 0 TO 1) AS INTEGER, ilen(0 TO 7, 0 TO 1) AS INTEGER, ilp(0 TO 7, 0 TO 1) AS INTEGER
DIM inc(0 TO 1) AS INTEGER, nfid(0 TO 1) AS INTEGER
DIM iclp(0 TO MAXI - 1) AS INTEGER, itm(0 TO MAXI - 1) AS SINGLE, iwt(0 TO MAXI - 1) AS SINGLE, ilst(0 TO MAXI - 1) AS INTEGER
DIM prs(0 TO 16) AS INTEGER
'----- the walk mask (320 x 200, a bit a pixel, rows of 40 bytes), the path grid
'----- (gnx x gnz cells of GCELL units from gx0, gz0: walkable, the search's
'----- parents and queue), the waypoints of the path being walked (x16 units)
DIM wmk(0 TO 3999) AS INTEGER, gwk(1) AS INTEGER, gpar(1) AS INTEGER, gq(1) AS INTEGER
DIM wpx(0 TO 63) AS LONG, wpz(0 TO 63) AS LONG, pcx(0 TO 255) AS LONG, pcz(0 TO 255) AS LONG
DIM ddx(0 TO 7) AS INTEGER, ddz(0 TO 7) AS INTEGER, bitv(0 TO 7) AS INTEGER
'----- the front pieces: their masks one after another in ocm() (a byte a pixel),
'----- each one's box on screen, its mask's start, its depth (x16 units: the floor
'----- under its lowest pixel), and their order far to near
DIM ocm(1) AS INTEGER, ocx0(0 TO 15) AS INTEGER, ocy0(0 TO 15) AS INTEGER, ocw(0 TO 15) AS INTEGER, och(0 TO 15) AS INTEGER
DIM ooff(0 TO 15) AS INTEGER, odep(0 TO 15) AS LONG, oord(0 TO 15) AS INTEGER
'----- the room's things (ROOM.PAC): hit points (pixel, object), and per object
'----- its verb, the item it needs (0 none), its text, its stand point (feet
'----- pixel, -1 none) and facing digit (0 none)
DIM hpx(0 TO 256) AS INTEGER, hpy(0 TO 256) AS INTEGER, hpo(0 TO 256) AS INTEGER
DIM oky(1 TO 25) AS STRING * 1, obs(1 TO 25) AS INTEGER, omsg(1 TO 25) AS STRING * 120
DIM ospx(1 TO 25) AS INTEGER, ospy(1 TO 25) AS INTEGER, ospd(1 TO 25) AS INTEGER
'----- the turning steps: their clips (-1 none) to his left and right, the feet
'----- they pivot on (rest x,z x16: 0 left, 1 right), the step playing (tcl, -1 none)
'----- and how far into it (1/30 s of the clip); nfid the fidgets (kind 0)
DIM tcf(0 TO 1, 0 TO 1) AS INTEGER, tfx(0 TO 1, 0 TO 1) AS SINGLE, tfz(0 TO 1, 0 TO 1) AS SINGLE
'----- (slot 1's texture: bt1, its one band in tb1 -- both models are unlit, one band each)
DIM SHARED bt1(0 TO 7) AS INTEGER, rymnm(0 TO 1) AS INTEGER
DIM SHARED tb0(0 TO 7) AS INTEGER, tb1(0 TO 7) AS INTEGER, tb2(0 TO 7) AS INTEGER, tb3(0 TO 7) AS INTEGER
DIM SHARED tb4(0 TO 7) AS INTEGER, tb5(0 TO 7) AS INTEGER, tb6(0 TO 7) AS INTEGER, tb7(0 TO 7) AS INTEGER
DIM SHARED bt(0 TO 7) AS INTEGER
DIM SHARED prm(0 TO 63) AS INTEGER, prq(0 TO 31) AS INTEGER
DIM SHARED dig(0 TO 9, 0 TO 4) AS INTEGER
'$STATIC
'----- the mouse: the driver's there (msOn), the cursor shown (curOn) at mcx,mcy
'----- (last frame's at ocx,ocy), the INT 33h registers ax bx cx dx, the arrow
DIM SHARED msOn AS INTEGER, curOn AS INTEGER, mcx AS INTEGER, mcy AS INTEGER, ocx AS INTEGER, ocy AS INTEGER
'$DYNAMIC
DIM mreg(0 TO 3) AS INTEGER, curs(0 TO 10) AS STRING
'$STATIC
DIM SHARED vdc AS LONG, bg AS LONG
DIM SHARED lx AS INTEGER, ly AS INTEGER, lz AS INTEGER
DIM SHARED tris AS LONG
DIM SHARED ox AS INTEGER, oy AS INTEGER, ox2 AS INTEGER, oy2 AS INTEGER
DIM SHARED bmode AS INTEGER, unlit AS INTEGER
DIM SHARED palb AS STRING, ovlTri AS STRING, ovlPrj AS STRING, ovlBop AS STRING
DIM SHARED ovlEdge AS STRING, ovlBltm AS STRING, outl AS INTEGER, ovlEdgo AS STRING, ocol AS INTEGER
'----- (outline 4: the dark-colour flags for C3DEDGK, 16-byte aligned inside dkt at dkal; -1 = not built)
DIM SHARED ovlEdgk AS STRING, ovlEdgi AS STRING, dkal AS INTEGER
'$DYNAMIC
DIM SHARED dkt(0 TO 139) AS INTEGER
'$STATIC
DIM SHARED texW AS INTEGER
DIM SHARED bx1 AS INTEGER, bx2 AS INTEGER, by1 AS INTEGER, by2 AS INTEGER

DIM k AS STRING, ts AS INTEGER, yaw AS SINGLE, spin AS SINGLE, turn AS INTEGER, paused AS INTEGER
DIM fx AS INTEGER, stp AS SINGLE, tnow AS LONG, tlast AS LONG, dt AS LONG, trav AS LONG
DIM cxs AS INTEGER, cys AS INTEGER, pz AS LONG, px AS LONG, py AS LONG, zoom AS INTEGER
DIM t0 AS SINGLE, el AS SINGLE, frames AS LONG, lang AS SINGLE, secs AS SINGLE
DIM bf AS SINGLE, bi AS INTEGER, bn AS INTEGER, b1 AS SINGLE, b2 AS SINGLE, b3 AS SINGLE, b4 AS SINGLE, sd AS SINGLE
DIM i AS INTEGER, j AS INTEGER, ymn AS INTEGER, pyu AS LONG, fwd AS INTEGER, rot AS INTEGER, sc AS INTEGER, lim AS LONG
'----- a house room (ROOM.CFG, written by tools\manwalk.ps1 -Room n): the camera
'----- solved from the rooms' common template -- the picture centre (rcx, rcy,
'----- px), the camera's height over the floor (rch) and the floor's extent
'----- (depth rzn..rzf, half width rxh), in model units, and the horizontal focal length
'----- (rfx: the screen's pixels are 1.2 times taller than wide); the backdrop is the room
'----- the floor's half width at its near and far edges (the drawn floor lines),
'----- the size he keeps at the back (rbs: 1 = no shrink, the art's own perspective
'----- gives zNear/zFar), the model's lowest point (his feet)
'----- and his overall size against true scale (rsc: the room's own scale puts the
'----- 2D sprite's height at the front edge; the sprite was drawn for mid-room)
DIM rfh AS INTEGER, rk AS SINGLE
DIM tfps AS LONG, ffps AS INTEGER, fps AS INTEGER, scripted AS INTEGER, lastsc AS INTEGER, pf AS INTEGER, quit AS INTEGER
'----- the character driven (0 the man, 1 the second one; Tab swaps them)
DIM pc AS INTEGER, swp AS INTEGER
DIM shot(0 TO 7) AS INTEGER, nshot AS INTEGER, k2 AS INTEGER
DIM yaw0 AS SINGLE, pvk AS INTEGER, pvx AS SINGLE, pvz AS SINGLE, ttest AS LONG, c0 AS SINGLE, s0 AS SINGLE
'----- going where a click said: goMode 1 walk to (gox, goz), 2 turn to face it
'----- (x16 units); the click (clk 1 left, 2 right, at csx, csy), the buttons last
'----- frame (lmb); this frame's limits: the turn (radians) and the step (x16)
DIM goMode AS INTEGER, gox AS LONG, goz AS LONG, clk AS INTEGER, csx AS INTEGER, csy AS INTEGER, lmb AS INTEGER, mb AS INTEGER
DIM gdx AS SINGLE, gdz AS SINGLE, gdist AS SINGLE, gd AS SINGLE, gturn AS SINGLE, gstep AS SINGLE, dyw AS SINGLE, wst AS SINGLE
DIM gochk AS INTEGER, gph AS INTEGER, gt0 AS LONG, v AS LONG, vs AS LONG, vo AS LONG
DIM pathchk AS INTEGER, opx AS LONG, opz AS LONG, nbad AS LONG, gtol AS SINGLE
'----- the room's things: the one he is walking to (then facing), the one he is
'----- turning to (0 none), its hit point
DIM hact AS INTEGER, hface AS INTEGER, hotchk AS INTEGER, hh AS INTEGER, hk AS INTEGER, hfpx AS INTEGER, hfpy AS INTEGER

	'----- MANWALK: the model (CAR3D.MDL/BMP, meant for the man) standing on the
	'----- road scene, driven with tank controls: Up/Down walk along his
	'----- heading, Left/Right turn; O toggles the silhouette ink; Esc quits.
	'----- The keyboard is read from port 60h (the last scan code: a held arrow
	'----- keeps its make code until it is released), so he moves while a key
	'----- is held, not per keystroke. The frame rate is shown top left.
	'----- MANWALK S: a scripted run without anyone at the keys -- 60 frames
	'----- walking and turning, MANWLK1.BMP, 60 more, MANWLK2.BMP, and the fps
	'----- to MANWALK.LOG (how the renderer is checked from the PC).
	texW = TexWidth%
	IF texW <> 64 AND texW <> 128 THEN PRINT "CAR3D.BMP must be 64 or 128 texels wide": END
	CALL LoadModel
	CALL LoadModel2
	IF texW = 128 THEN CALL LoadOvl("C3DT128.OVL", ovlTri) ELSE CALL LoadOvl("C3DTRI.OVL", ovlTri)
	CALL LoadOvl("C3DPRJ.OVL", ovlPrj)
	CALL LoadOvl("SHADBOP.OVL", ovlBop)
	CALL LoadOvl("C3DEDGE.OVL", ovlEdge)
	CALL LoadOvl("C3DBLTM.OVL", ovlBltm)
	CALL LoadOvl("C3DEDGO.OVL", ovlEdgo)
	CALL LoadOvl("C3DEDGK.OVL", ovlEdgk)
	CALL LoadOvl("C3DEDGI.OVL", ovlEdgi)
	CALL LoadOvl("C3DSKIN.OVL", ovlSkin)
	CALL LoadOvl("C3DMSE.OVL", ovlMse)
	CALL LoadOvl("C3DMCPY.OVL", ovlMcpy)
	CALL LoadOvl("C3DROT.OVL", ovlRot)
	IF LEN(ovlRot) < 100 THEN PRINT "C3DROT.OVL missing (tools\build_car3d_asm.ps1)": END
	IF LEN(ovlTri) < 100 OR LEN(ovlPrj) < 50 OR LEN(ovlBop) < 50 THEN PRINT "C3DTRI/C3DPRJ/SHADBOP.OVL missing (tools\build_car3d_asm.ps1)": END
	IF LEN(ovlEdge) < 50 OR LEN(ovlBltm) < 50 OR LEN(ovlEdgo) < 30 OR LEN(ovlEdgk) < 30 OR LEN(ovlEdgi) < 30 THEN PRINT "C3DEDGE/C3DEDGO/C3DEDGK/C3DEDGI/C3DBLTM.OVL missing (tools\build_car3d_asm.ps1)": END
	'----- the 3x5 digits of the frame counter
	FOR i = 0 TO 9: FOR j = 0 TO 4: READ dig(i, j): NEXT: NEXT
	FOR i = 0 TO 10: READ curs(i): NEXT
	'----- (every dynamic array sized before any segment is taken: a REDIM may move
	'----- the others, the backdrop and work buffers and the texture bands with them)
	'----- his feet on the ground plane: the model's lowest point at GROUNDY
	FOR j = 0 TO nmod - 1
		ymn = 32767
		FOR i = 0 TO nvm(j) - 1
			IF my(i, j) < ymn THEN ymn = my(i, j)
		NEXT
		rymnm(j) = ymn
	NEXT
	ymn = rymnm(0)
	py = CLNG(GROUNDY) * 16 - ymn
	roomOn = 0
	rfh = FREEFILE
	OPEN "ROOM.CFG" FOR BINARY AS #rfh
	IF LOF(rfh) > 0 THEN roomOn = 1
	CLOSE #rfh
	IF roomOn THEN
		rfh = FREEFILE
		OPEN "ROOM.CFG" FOR INPUT AS #rfh
		INPUT #rfh, rcx, rcy, rch, rzn, rzf, rxn, rxf, rfx, rbs, rsc
		CLOSE #rfh
		prq(22) = CINT(rcx * 16): prq(23) = CINT(rcy * 16): prq(24) = CINT(rfx * 16)
		py = -CLNG(rch * 16) - ymn
		CALL LoadWalk
		CALL LoadOcc
		CALL LoadPac
	ELSE
		KILL "ROOM.CFG"
	END IF
	'----- he starts on the road's near part, facing the camera (yaw 0 = the
	'----- model's front, -z, towards it); forward is where he faces
	CALL PathPos(40, px, pyu, pz, 16)
	'----- in a room: mid-floor, a little in front of the middle
	IF roomOn THEN px = 0: pz = CLNG((rzn * .4 + rzf * .6) * 16)
	yaw = 0
	afcur = -1: aph = 0: ianim = 2: pc = 0
	CALL LoadAnim(0, "MAN3D.ANI")
	IF nmod = 2 THEN CALL LoadAnim(1, "JAMESW.ANI")
	RANDOMIZE TIMER
	CALL LoadIdle(0, "MANIDLE.ANI")
	IF nmod = 2 THEN CALL LoadIdle(1, "JAMESI.ANI")
	IF uglInit = 0 THEN PRINT "uglInit failed": END
	vdc = uglSetVideoDC(UGL.8BIT, 320, 200, 1)
	IF vdc = 0 THEN Fail "no mode 13h"
	bg = uglNew(UGL.MEM, UGL.8BIT, 320, 200)
	IF bg = 0 THEN Fail "no memory for the backdrop"
	uglSetWrkPage 0
	uglSetVisPage 0
	CALL LoadPalette
	CALL LoadTexture
	bgseg = NormSeg(VARSEG(bgb(0)), VARPTR(bgb(0))): bgo = VARPTR(bgb(0)) AND 15
	wseg = NormSeg(VARSEG(wkb(0)), VARPTR(wkb(0))): wko = VARPTR(wkb(0)) AND 15
	CALL LoadBackdrop
	ox = 0: oy = 0: ox2 = -1: oy2 = -1
	prm(0) = wseg: prm(1) = wko: prm(2) = WKW: prm(3) = WKH
	prm(5) = VARSEG(sx(0)): prm(6) = VARPTR(sx(0))
	prm(7) = VARSEG(sy(0)): prm(8) = VARPTR(sy(0))
	prm(9) = VARSEG(tu(0)): prm(10) = VARPTR(tu(0))
	prm(11) = VARSEG(tv(0)): prm(12) = VARPTR(tv(0))
	prm(15) = VARSEG(fband(0)): prm(16) = VARPTR(fband(0))
	prm(17) = VARSEG(ord(0)): prm(18) = VARPTR(ord(0))
	prq(0) = VARSEG(rx(0)): prq(1) = VARPTR(rx(0))
	prq(2) = VARSEG(ry(0)): prq(3) = VARPTR(ry(0))
	prq(4) = VARSEG(rz(0)): prq(5) = VARPTR(rz(0))
	prq(6) = VARSEG(sx(0)): prq(7) = VARPTR(sx(0))
	prq(8) = VARSEG(sy(0)): prq(9) = VARPTR(sy(0))
	lang = -2.3
	lx = CINT(COS(lang) * 205): ly = 154: lz = CINT(SIN(lang) * 205)
	'----- the rotate-and-sort block (C3DROT: the model x16 -> rx/ry/rz, the
	'----- faces bucket-sorted into ord; lnk and head are its scratch); the model's
	'----- own words (its faces, counts, texture) come from UseModel
	prr(0) = VARSEG(mx(0, 0)): prr(1) = VARPTR(mx(0, 0))
	prr(2) = VARSEG(my(0, 0)): prr(3) = VARPTR(my(0, 0))
	prr(4) = VARSEG(mz(0, 0)): prr(5) = VARPTR(mz(0, 0))
	prr(6) = VARSEG(rx(0)): prr(7) = VARPTR(rx(0))
	prr(8) = VARSEG(ry(0)): prr(9) = VARPTR(ry(0))
	prr(10) = VARSEG(rz(0)): prr(11) = VARPTR(rz(0))
	prr(17) = VARSEG(ord(0)): prr(18) = VARPTR(ord(0))
	prr(20) = VARSEG(lnk(0)): prr(21) = VARPTR(lnk(0))
	prr(22) = VARSEG(head(0)): prr(23) = VARPTR(head(0))
	prr(24) = 256: prr(25) = 0
	FOR i = 0 TO MAXF: fband(i) = 0: NEXT
	prq(21) = 8
	IF unlit THEN prm(15) = 0
	CALL UseModel(0)
	CALL PrepAsm(yaw)
	outl = 1: ninst = 1: vsync = 1: lastsc = 0: flatT = 64: quadT = 384: dotT = 0   ' (dots: no measurable gain on the VM, so off; D cycles it)
	outl = 2: ocol = 1: dkal = -1
	CALL OutlineCol(ocol)
	'----- the second character: standing towards the back on the left (in a room), further
	'----- along the road (outside), three-quarters to the camera, in his idle clips
	IF nmod = 2 THEN
		ninst = 2: iyaw(1) = .6: iph(1) = 0
		IF roomOn THEN
			ipz(1) = CLNG((rzn * .35 + rzf * .65) * 16): ipx(1) = -CLNG(RoomX!(ipz(1)) * 7)
		ELSE
			CALL PathPos(90, ipx(1), ipy(1), ipz(1), 16): ipy(1) = CLNG(GROUNDY) * 16 - rymnm(1)
		END IF
		ifr(1) = IdlePose%(1, 0, 0)
		CALL PoseInst(1, ifr(1), iyaw(1))
		CALL UseModel(0)
	END IF
	scripted = 0: idlechk = 0
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "S" THEN scripted = 1
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "I" THEN scripted = 1: idlechk = 1
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "W" THEN scripted = 1: gochk = 1
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "P" THEN scripted = 1: gochk = 1: pathchk = 1
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "H" THEN scripted = 1: gochk = 1: hotchk = 1
	'----- the mouse: only with a driver behind INT 33h (a zero vector, or one
	'----- pointing at an IRET, would hang or do nothing); reset, its range the
	'----- screen (x in 0..639 in mode 13h), its arrow's two colours
	msOn = 0: k2 = 0: v = 0
	IF LEN(ovlMse) > 20 AND scripted = 0 THEN
		DEF SEG = 0
		vo = PEEK(&HCC) + 256& * PEEK(&HCD): vs = PEEK(&HCE) + 256& * PEEK(&HCF)
		DEF SEG
		IF vo + vs > 0 THEN
			DEF SEG = vs: v = PEEK(vo): DEF SEG
			IF v <> &HCF THEN
				mreg(0) = 0: CALL Mouse: k2 = mreg(0)
				IF k2 = -1 THEN msOn = 1
			END IF
		END IF
	END IF
	IF msOn THEN
		mreg(0) = 7: mreg(2) = 0: mreg(3) = 639: CALL Mouse
		mreg(0) = 8: mreg(2) = 0: mreg(3) = 199: CALL Mouse
		mreg(0) = 4: mreg(2) = 320: mreg(3) = 100: CALL Mouse
		mcx = 160: mcy = 100
	END IF
	curOn = msOn: ocx = mcx: ocy = mcy
	'----- (what was found, for checking a machine: MOUSE.LOG)
	IF scripted = 0 THEN
		i = FREEFILE
		OPEN "MOUSE.LOG" FOR OUTPUT AS #i
		PRINT #i, "INT 33h vector "; HEX$(vs); ":"; HEX$(vo); " first byte "; HEX$(v); " reset ax "; k2; " -> mouse"; msOn
		CLOSE #i
	END IF
	OUT &H3C8, 12: OUT &H3C9, 0: OUT &H3C9, 0: OUT &H3C9, 0: OUT &H3C9, 63: OUT &H3C9, 63: OUT &H3C9, 63
	MID$(palb, 12 * 4 + 1, 8) = STRING$(4, 0) + STRING$(3, 255) + CHR$(0)
	'----- the outline to start with: a digit after the S, or alone
	k = LTRIM$(COMMAND$)
	IF scripted THEN k = MID$(k, 2)
	i = INSTR("012345", LEFT$(k, 1))
	IF i > 0 AND LEN(k) > 0 THEN outl = i - 1
	IF UCASE$(LEFT$(LTRIM$(COMMAND$), 1)) = "B" THEN CALL Bench
	'----- the scripted check in a room: men at the floor's four corners and the
	'----- front middle, in walk poses, so the scale can be judged across the floor
	IF scripted AND roomOn AND idlechk = 0 AND gochk = 0 THEN
		FOR i = 0 TO 4
			SELECT CASE i
			CASE 0: pz = CLNG((rzn + 18) * 16): px = CLNG(-(RoomX!(pz) - 22 * RoomK!(pz)) * 16): plyaw = .5
			CASE 1: pz = CLNG((rzn + 18) * 16): px = CLNG((RoomX!(pz) - 22 * RoomK!(pz)) * 16): plyaw = -.5
			CASE 2: pz = CLNG((rzf - 18) * 16): px = CLNG(-(RoomX!(pz) - 22 * RoomK!(pz)) * 16): plyaw = 1.57
			CASE 3: pz = CLNG((rzf - 18) * 16): px = CLNG((RoomX!(pz) - 22 * RoomK!(pz)) * 16): plyaw = 3.14
			CASE 4: px = 0: pz = CLNG((rzn + 18) * 16): plyaw = 0
			END SELECT
			IF anf(0) > 0 THEN CALL PoseInst(0, (i * 3) MOD anf(0), plyaw) ELSE CALL PoseInst(0, -1, plyaw)
			CALL PlaceCopy(px, py, pz)
		NEXT
		px = 0: pz = CLNG((rzn + rzf) * 8): yaw = .8: CALL PoseInst(0, -1, yaw)
	END IF
	'----- MANWALK I: him near the front, three-quarters on, a fidget half a second in
	IF idlechk THEN
		px = 0: yaw = .5: iwt(0) = 15
		IF roomOn THEN pz = CLNG((rzn * .75 + rzf * .25) * 16)
		CALL PoseInst(0, -1, yaw)
	END IF
	FOR i = 0 TO 7: shot(i) = 0: NEXT
	pvk = -1: ttest = -1: goMode = 0: clk = 0: lmb = 0: gph = 0: hact = 0: hface = 0
	'----- MANWALK W: him mid-floor facing the camera; P: in front of the bed
	IF gochk THEN
		px = 0: yaw = 0
		IF roomOn THEN pz = CLNG((rzn + rzf) * 8)
		IF pathchk THEN px = -1600: pz = 17920
		CALL PoseInst(0, -1, yaw)
	END IF
	'----- PIT channel 0 in mode 2 so PitNow reads the time within a tick
	OUT &H43, &H34: OUT &H40, 0: OUT &H40, 0
	tlast = PitNow&: tfps = tlast: ffps = 0: fps = 0
	CALL ShowFps(0)
	t0 = TIMER: frames = 0: fwd = 0: rot = 0
	DO
		'----- the keys: the last scan code (port 60h) is a make code while a
		'----- key is held and its break code (+128) once it is released; the
		'----- BIOS buffer is emptied every frame (a held arrow repeats into it
		'----- faster than a slow frame takes one key out, and a full buffer beeps)
		plyaw = yaw: quit = 0
		DO
			k = INKEY$
			IF k = "" THEN EXIT DO
			IF k = CHR$(27) THEN quit = 1
			IF k = "o" OR k = "O" THEN outl = (outl + 1) MOD 6
			IF k = "]" THEN ocol = (ocol + 1) MOD 16: CALL OutlineCol(ocol)
			IF k = "[" THEN ocol = (ocol + 15) MOD 16: CALL OutlineCol(ocol)
			IF k = " " THEN CALL PlaceCopy(px, py, pz)
			IF k = "c" OR k = "C" THEN IF nmod < 2 THEN ninst = 1: ox2 = -1
			IF (k = "c" OR k = "C") AND nmod = 2 AND pc = 0 THEN ninst = 3 - ninst: ox2 = -1
			IF k = "v" OR k = "V" THEN vsync = 1 - vsync
			IF k = "f" OR k = "F" THEN flatT = flatT + 32: IF flatT > 96 THEN flatT = 0
			IF k = "g" OR k = "G" THEN quadT = 384 - quadT
			IF k = "d" OR k = "D" THEN dotT = dotT + 8: IF dotT > 24 THEN dotT = 0
			IF k = "a" OR k = "A" THEN ianim = (ianim + 1) MOD 3
			'----- Tab: drive the other character (the one let go stands and idles where he is)
			IF k = CHR$(9) THEN swp = 1
		LOOP
		'----- (MANWALK S: Tab halfway, so the second half walks the other character)
		IF scripted AND frames = 60 AND idlechk = 0 AND gochk = 0 THEN swp = 1
		IF swp AND nmod = 2 AND ninst = 2 THEN
			ipx(pc) = px: ipy(pc) = py: ipz(pc) = pz: iyaw(pc) = yaw: iph(pc) = aph: ifr(pc) = afcur
			iclp(pc) = 0: itm(pc) = 0: iwt(pc) = 120
			pc = 1 - pc
			px = ipx(pc): py = ipy(pc): pz = ipz(pc): yaw = iyaw(pc): aph = iph(pc): afcur = ifr(pc)
			goMode = 0: hact = 0: hface = 0: tcl = -1: pvk = -1: fwd = 0: rot = 0
		END IF
		swp = 0
		IF quit THEN EXIT DO
		sc = INP(&H60)
		'----- (with a mouse the port may hold a PS/2 mouse byte instead: Esc comes
		'----- from the key buffer only, and only a new arrow press stops a click's walk)
		IF sc = 1 AND msOn = 0 THEN EXIT DO
		IF sc = 72 THEN fwd = 1: rot = 0
		IF sc = 80 THEN fwd = -1: rot = 0
		IF sc = 75 THEN rot = -1: fwd = 0
		IF sc = 77 THEN rot = 1: fwd = 0
		IF sc >= 128 THEN fwd = 0: rot = 0
		IF sc <> lastsc AND (sc = 72 OR sc = 80 OR sc = 75 OR sc = 77) THEN goMode = 0: hact = 0: hface = 0
		lastsc = sc
		'----- the mouse: where it is, a button's press (not its hold)
		IF msOn THEN
			mreg(0) = 3: CALL Mouse
			mb = mreg(1): mcx = mreg(2) \ 2: mcy = mreg(3)
			IF mcx < 0 THEN mcx = 0
			IF mcx > 319 THEN mcx = 319
			IF mcy < 0 THEN mcy = 0
			IF mcy > 199 THEN mcy = 199
			IF (mb AND 1) <> 0 AND (lmb AND 1) = 0 THEN clk = 1: csx = mcx: csy = mcy
			IF (mb AND 2) <> 0 AND (lmb AND 2) = 0 THEN clk = 2: csx = mcx: csy = mcy
			lmb = mb
		END IF
		IF scripted THEN
			IF frames < 60 THEN fwd = 1: rot = 1 ELSE fwd = -1: rot = 0
			IF roomOn = 0 AND (frames = 20 OR frames = 40 OR frames = 70) THEN CALL PlaceCopy(px, py, pz)
		END IF
		IF idlechk THEN
			fwd = 0: rot = 0
			'----- (after the fidgets: a turn to his left, then to his right)
			IF ttest >= 0 THEN
				IF frames - ttest < 45 THEN rot = 1 ELSE IF frames - ttest < 90 THEN rot = -1
			END IF
		END IF
		'----- MANWALK W: a left click to the front right of the floor; when he is
		'----- there, a right click up at the back left
		IF hotchk THEN
			'----- MANWALK H: a left click (action) on the cabinet in the back wall, then a
			'----- right click (look) on the bed; a shot and a line each time he is done
			fwd = 0: rot = 0
			IF frames = 3 THEN curOn = 1: mcx = 105: mcy = 119
			IF frames = 12 THEN CALL SaveShot("MANHOT0.BMP"): clk = 1: csx = mcx: csy = mcy: gph = 1: hk = hsaid
			IF gph >= 1 AND hsaid > hk THEN
				CALL SaveShot("MANHOT" + LTRIM$(STR$(gph)) + ".BMP")
				i = FREEFILE
				IF gph = 1 THEN OPEN "MANHOT.LOG" FOR OUTPUT AS #i ELSE OPEN "MANHOT.LOG" FOR APPEND AS #i
				PRINT #i, "object"; hlast; ": he is at"; px \ 16; pz \ 16; "facing"; INT(yaw * 573) / 10; "after"; frames - gt0; "frames, off the mask"; nbad
				PRINT #i, "   "; RTRIM$(omsg(hlast))
				CLOSE #i
				hk = hsaid
				IF gph = 1 THEN mcx = 128: mcy = 131: clk = 2: csx = mcx: csy = mcy: gph = 2 ELSE EXIT DO
			END IF
			IF wmOn THEN IF MaskAt%(px, pz) = 0 THEN nbad = nbad + 1
			IF frames > 3000 THEN
				i = FREEFILE: OPEN "MANHOT.LOG" FOR APPEND AS #i
				PRINT #i, "timeout"; px \ 16; pz \ 16; goMode; hact; hface; hsaid; nwp; iwp; gox \ 16; goz \ 16
				CLOSE #i: EXIT DO
			END IF
		END IF
		IF pathchk THEN
			'----- MANWALK P: into the gap between the bed and the dresser at the back,
			'----- then onto the bed (he stops in front of it); every frame he must be
			'----- on the mask
			fwd = 0: rot = 0
			IF MaskAt%(px, pz) = 0 THEN nbad = nbad + 1
			IF frames = 5 THEN clk = 1: csx = 158: csy = 137: gph = 1
			IF gph >= 1 AND goMode = 0 AND clk = 0 AND frames > 6 THEN
				CALL SaveShot("MANPATH" + LTRIM$(STR$(gph)) + ".BMP")
				i = FREEFILE
				IF gph = 1 THEN OPEN "MANPATH.LOG" FOR OUTPUT AS #i ELSE OPEN "MANPATH.LOG" FOR APPEND AS #i
				PRINT #i, "click"; csx; csy; ": path"; nwp; "waypoints";
				FOR k2 = 0 TO nwp - 1: PRINT #i, " ("; wpx(k2) \ 16; ","; wpz(k2) \ 16; ")";: NEXT
				PRINT #i, ""
				PRINT #i, "   he is at"; px \ 16; pz \ 16; " after"; frames - gt0; "frames; frames off the mask so far"; nbad; " search"; INT(pathms * 10) / 10; "ms"
				CLOSE #i
				IF gph = 1 THEN clk = 1: csx = 131: csy = 139: gph = 2 ELSE EXIT DO
			END IF
			IF frames > 3000 THEN EXIT DO
			curOn = 1: mcx = csx: mcy = csy
		END IF
		IF gochk AND pathchk = 0 AND hotchk = 0 THEN
			fwd = 0: rot = 0
			IF frames = 5 THEN clk = 1: csx = 250: csy = 172: gph = 1
			IF gph = 1 AND goMode = 0 AND frames > 6 THEN
				CALL SaveShot("MANGO1.BMP")
				i = FREEFILE
				OPEN "MANGO.LOG" FOR OUTPUT AS #i
				IF roomOn THEN c0 = rcx + rfx * px / pz: s0 = rcy + 256 * rch * 16 / pz ELSE c0 = 160 + 256 * px / pz: s0 = 100 - 256 * GROUNDY * 16 / pz
				PRINT #i, "walk: click"; csx; csy; " target"; gox / 16; goz / 16; " he is at"; px / 16; pz / 16; " his feet on screen"; INT(c0 * 10) / 10; INT(s0 * 10) / 10; " frames"; frames - gt0
				CLOSE #i
				clk = 2: csx = 70: csy = 125: gph = 2
			END IF
			IF gph = 2 AND goMode = 0 AND clk = 0 THEN
				CALL SaveShot("MANGO2.BMP")
				i = FREEFILE
				OPEN "MANGO.LOG" FOR APPEND AS #i
				gdx = gox - px: gdz = goz - pz
				PRINT #i, "face: click"; csx; csy; " heading"; INT(yaw * 5730) / 100; " wanted"; INT(Atn2!(-gdx, -gdz) * 5730) / 100; " frames"; frames - gt0
				CLOSE #i
				EXIT DO
			END IF
			IF frames > 2000 THEN EXIT DO
			curOn = 1: mcx = csx: mcy = csy
		END IF
		'----- a click on one of the room's things (left: its action, right: look): an
		'----- action with a stand point walks him there; else he turns to the thing
		hh = 0
		IF clk > 0 THEN hact = 0: hface = 0
		IF clk = 1 AND nhot > 0 THEN hh = PacHit%(csx, csy, "a")
		IF clk = 2 AND nhot > 0 THEN hh = PacHit%(csx, csy, "l")
		IF hh > 0 THEN
			hfpx = phx: hfpy = phy
			IF clk = 1 AND ospx(hh) >= 0 THEN
				csx = ospx(hh): csy = ospy(hh): hact = hh
			ELSE
				clk = 2: csx = phx: csy = phy: hface = hh
			END IF
		END IF
		'----- a click: where on the floor (a walk is kept to the floor, a face is not)
		IF clk = 1 THEN
			CALL FloorPick(csx, csy, 1, gox, goz): goMode = 1: gt0 = frames
			'----- with a walk mask: the path there, walked waypoint by waypoint
			nwp = 0
			IF wmOn THEN
				CALL FindPath(px, pz, gox, goz)
				IF nwp > 0 THEN iwp = 0: gox = wpx(0): goz = wpz(0) ELSE goMode = 0
			END IF
		END IF
		IF clk = 2 THEN CALL FloorPick(csx, csy, 0, gox, goz): goMode = 2: gt0 = frames
		clk = 0
		'----- going there: the heading to it; well off it (35 degrees), he turns on
		'----- the spot, else walks and steers; the last step and turn land on it
		gturn = 99: gstep = -1
		IF goMode > 0 THEN
			gdx = gox - px: gdz = goz - pz: gdist = SQR(gdx * gdx + gdz * gdz)
			'----- a waypoint on the way is passed a unit off; the last one is landed on
			gtol = 8: IF goMode = 1 AND iwp < nwp - 1 THEN gtol = 16
			IF gdist < gtol THEN
				IF goMode = 1 AND iwp < nwp - 1 THEN
					iwp = iwp + 1: gox = wpx(iwp): goz = wpz(iwp)
					gdx = gox - px: gdz = goz - pz: gdist = SQR(gdx * gdx + gdz * gdz)
				ELSE
					goMode = 0: fwd = 0: rot = 0
					'----- at a thing's stand point: now its facing (or the thing itself)
					IF hact > 0 THEN
						IF ospd(hact) > 0 THEN CALL DigitAim(ospd(hact), px, pz, gox, goz) ELSE CALL FloorPick(hfpx, hfpy, 0, gox, goz)
						goMode = 2: hface = hact: hact = 0
						gdx = gox - px: gdz = goz - pz: gdist = SQR(gdx * gdx + gdz * gdz)
					END IF
				END IF
			END IF
		END IF
		IF goMode > 0 THEN
			gd = Atn2!(-gdx, -gdz) - yaw
			DO WHILE gd > 3.14159: gd = gd - 6.28318: LOOP
			DO WHILE gd < -3.14159: gd = gd + 6.28318: LOOP
			rot = 0
			IF gd > .002 THEN rot = 1
			IF gd < -.002 THEN rot = -1
			gturn = ABS(gd): fwd = 0
			IF goMode = 1 THEN
				'----- (round a corner of the path he walks on through 50 degrees)
				IF ABS(gd) < .6 OR (iwp > 0 AND ABS(gd) < .87) THEN fwd = 1
				gstep = gdist
			ELSE
				IF rot = 0 THEN goMode = 0
			END IF
		END IF
		'----- turned to the thing he was sent to: its text
		IF goMode = 0 AND hface > 0 THEN CALL SayObj(hface): hface = 0
		'----- the frame's time in retraces (the PIT, 17045 ticks), exact, so he covers the
		'----- same ground a second at any frame rate; at most 10 (a frame under 7 fps),
		'----- so a stall never throws him across the room
		tnow = PitNow&: dt = tnow - tlast: tlast = tnow
		IF dt < 0 OR dt > 170450 THEN dt = 17045
		stp = dt / 17045!
		IF stp > 10 THEN stp = 10
		'----- turning: TURNRATE a retrace; walking: 1.44 units a retrace (about
		'----- 2 m/s), along the heading -- the model's front is -z at yaw 0,
		'----- so forward = (-sin yaw, -cos yaw)
		IF rot <> 0 THEN
			yaw0 = yaw
			dyw = rot * stp * TURNRATE
			IF ABS(dyw) > gturn THEN dyw = SGN(dyw) * gturn
			yaw = yaw + dyw
			IF yaw > 6.2832 THEN yaw = yaw - 6.2832
			IF yaw < 0 THEN yaw = yaw + 6.2832
			'----- on the spot with a step clip for this way: turned about the planted
			'----- foot (his left turning left, yaw rising) -- its place on the floor
			'----- kept from the turn's start, his own place following from it
			k2 = 0: IF rot < 0 THEN k2 = 1
			IF fwd = 0 AND inc(pc) > 0 AND tcf(k2, pc) >= 0 THEN
				rk = 1: IF roomOn THEN rk = RoomK!(pz)
				IF pvk <> k2 THEN
					pvk = k2: c0 = COS(yaw0): s0 = SIN(yaw0)
					pvx = px + (tfx(k2, pc) * c0 + tfz(k2, pc) * s0) * rk
					pvz = pz + (tfz(k2, pc) * c0 - tfx(k2, pc) * s0) * rk
				END IF
				c0 = COS(yaw): s0 = SIN(yaw)
				opx = px: opz = pz
				px = CLNG(pvx - (tfx(k2, pc) * c0 + tfz(k2, pc) * s0) * rk)
				pz = CLNG(pvz - (tfz(k2, pc) * c0 - tfx(k2, pc) * s0) * rk)
				'----- (not off the walk mask: there he turns about his middle instead)
				IF wmOn THEN
					IF MaskAt%(px, pz) = 0 AND MaskAt%(opx, opz) <> 0 THEN px = opx: pz = opz: pvk = -1
				END IF
			END IF
		ELSE
			pvk = -1
		END IF
		IF fwd <> 0 THEN
			'----- (in a room he is drawn RoomK times his size; he walks that much faster
			'----- so his feet keep their hold on the floor)
			rk = 1: IF roomOn THEN rk = RoomK!(pz)
			wst = WALK16 * stp * rk
			IF gstep >= 0 AND wst > gstep THEN wst = gstep
			opx = px: opz = pz
			px = px - CLNG(SIN(yaw) * wst * fwd)
			pz = pz - CLNG(COS(yaw) * wst * fwd)
			'----- the walk mask: off it he does not go (along its edge he slides);
			'----- already off it (a turn's pivot can do that) he may move
			IF wmOn THEN
				IF MaskAt%(px, pz) = 0 AND MaskAt%(opx, opz) <> 0 THEN
					IF MaskAt%(px, opz) THEN
						pz = opz
					ELSEIF MaskAt%(opx, pz) THEN
						px = opx
					ELSE
						px = opx: pz = opz
					END IF
				END IF
			END IF
			'----- kept on the screen and off the camera: 140..900 units away,
			'----- within the view's width at that depth
			IF roomOn THEN
				'----- the floor, less his reach (14 units) from the walls
				IF pz < CLNG((rzn + 14) * 16) THEN pz = CLNG((rzn + 14) * 16)
				IF pz > CLNG((rzf - 14) * 16) THEN pz = CLNG((rzf - 14) * 16)
				lim = CLNG((RoomX!(pz) - 14 * RoomK!(pz)) * 16)
			ELSE
				IF pz < 2240 THEN pz = 2240
				IF pz > 14400 THEN pz = 14400
				lim = pz \ 2
			END IF
			IF px > lim THEN px = lim
			IF px < -lim THEN px = -lim
		END IF
		'----- the walk frame by the distance walked (backwards plays it back);
		'----- standing, the rest pose. The model is re-rotated and re-sorted only
		'----- when its frame or heading changes
		pf = -1
		IF fwd <> 0 AND anf(pc) > 0 THEN aph = aph + CLNG(wst / rk * fwd): pf = AnimFrame%(pc, aph)
		'----- standing: the idle clips (turning holds him in the breathing loop)
		IF fwd <> 0 THEN
			iclp(pc) = 0: itm(pc) = 0: iwt(pc) = 120: tcl = -1: pvk = -1
		ELSE
			'----- a turning step (or the last one finishing), else the idle clips
			pf = TurnPose%(pc, rot, stp * TURNRATE * 57.296)
			IF pf >= 0 THEN
				j = IdlePose%(pc, 0, 1)
			ELSE
				pf = IdlePose%(pc, stp * 30 / 70, ABS(rot))
			END IF
		END IF
		IF pf <> afcur OR rot <> 0 THEN afcur = pf: CALL PoseInst(pc, afcur, yaw)
		'----- A: the copies walk in place, each at its own place in the cycle; again:
		'----- they stand and fidget, each on its own time
		IF ianim = 2 THEN
			FOR i = 0 TO ninst - 1
				IF i = pc THEN GOTO nexti2
				j = IdlePose%(i, stp * 30 / 70, 0)
				IF j <> ifr(i) THEN ifr(i) = j: CALL PoseInst(i, j, iyaw(i))
nexti2:
			NEXT
		END IF
		IF ianim = 1 THEN
			FOR i = 0 TO ninst - 1
				j = i: IF nmod < 2 THEN j = 0
				IF i = pc OR anf(j) = 0 THEN GOTO nexti1
				iph(i) = iph(i) + CLNG(WALK16 * stp): j = AnimFrame%(j, iph(i))
				IF j <> ifr(i) THEN ifr(i) = j: CALL PoseInst(i, j, iyaw(i))
nexti1:
			NEXT
		END IF
		ipx(pc) = px: ipy(pc) = py: ipz(pc) = pz: iyaw(pc) = yaw
		CALL DrawAll
		frames = frames + 1: ffps = ffps + 1
		'----- the frame rate over the last half second or so
		IF tnow - tfps >= 596591 THEN
			fps = CINT(ffps * 1193182! / (tnow - tfps))
			CALL ShowFps(fps)
			tfps = tnow: ffps = 0
		END IF
		'----- MANWALK I: a shot of each fidget 40% of the way in, the first one's
		'----- vertices too; done when every fidget has had its shot
		IF idlechk THEN
			i = iclp(0)
			IF i > 0 THEN
				IF shot(i) = 0 AND itm(0) >= ilen(i, 0) * .4 THEN
					shot(i) = 1: nshot = nshot + 1
					CALL SaveShot("MANIDL" + LTRIM$(STR$(i)) + ".BMP")
					IF i = 1 THEN
						j = FREEFILE
						OPEN "MANIDLE.DMP" FOR BINARY AS #j
						PUT #j, , afcur
						FOR k2 = 0 TO nvm(0) - 1: PUT #j, , kx(k2): NEXT
						FOR k2 = 0 TO nvm(0) - 1: PUT #j, , ky(k2): NEXT
						FOR k2 = 0 TO nvm(0) - 1: PUT #j, , kz(k2): NEXT
						CLOSE #j
					END IF
				END IF
			END IF
			IF nshot >= nfid(0) AND i = 0 AND ttest < 0 THEN ttest = frames
			IF ttest >= 0 THEN
				'----- the planted foot's place on screen, frame by frame (MANTURN.LOG)
				k2 = 0: IF frames - ttest >= 45 THEN k2 = 1
				c0 = 0: s0 = 0: j = 0
				FOR i = 0 TO nvm(0) - 1
					IF (ibw(i, 0) AND 255) = 5 + 3 * k2 THEN c0 = c0 + vt(i * 4): s0 = s0 + vt(i * 4 + 1): j = j + 1
				NEXT
				IF frames = ttest THEN OPEN "MANTURN.LOG" FOR OUTPUT AS #9 ELSE OPEN "MANTURN.LOG" FOR APPEND AS #9
				PRINT #9, frames - ttest; rot; INT(yaw * 573) / 10; INT(c0 / j / 1.6) / 10; INT(s0 / j / 1.6) / 10; afcur
				CLOSE #9
				IF frames - ttest = 25 THEN CALL SaveShot("MANTRN1.BMP")
				IF frames - ttest = 70 THEN CALL SaveShot("MANTRN2.BMP")
				IF frames - ttest >= 110 THEN EXIT DO
			END IF
			IF frames > 4000 THEN EXIT DO
		END IF
		IF scripted AND idlechk = 0 AND gochk = 0 THEN
			'----- (the second shot with the outline in yellow: the colour keys' path)
			IF frames = 60 THEN CALL SaveShot("MANWLK1.BMP"): ocol = 14: CALL OutlineCol(ocol)
			IF frames = 120 THEN CALL SaveShot("MANWLK2.BMP"): EXIT DO
		END IF
	LOOP
	el = TIMER - t0: IF el < 0 THEN el = el + 86400
	OUT &H43, &H36: OUT &H40, 0: OUT &H40, 0
	uglRestore
	uglEnd
	SCREEN 0: WIDTH 80, 25
	PRINT "MANWALK: verts"; nv; " faces"; nf; " models"; ninst; " frames"; frames; " secs"; INT(el * 10) / 10; " fps"; INT(frames / (el + .001)); " polys/frame"; INT(tris / (frames + 1))
	IF scripted THEN
		i = FREEFILE
		OPEN "MANWALK.LOG" FOR OUTPUT AS #i
		PRINT #i, "MANWALK S: verts"; nv; " faces"; nf; " models"; ninst; " frames"; frames; " secs"; INT(el * 10) / 10; " fps"; INT(frames / (el + .001)); " polys/frame"; INT(tris / (frames + 1)); " last shown"; fps; " free"; FRE(-1)
		PRINT #i, "pieces"; nocc; " walk mask"; wmOn; " hit points"; nhot; " strings"; FRE(""); " stack"; FRE(-2)
		CLOSE #i
	END IF
	END

'----- the digits 0..9 as 3x5 bit rows (4 = left, 1 = right)
DATA 7,5,5,5,7, 2,6,2,2,7, 7,1,7,4,7, 7,1,7,1,7, 5,5,7,1,1
DATA 7,4,7,1,7, 7,4,7,5,7, 7,1,1,1,1, 7,5,7,5,7, 7,5,7,1,7
'----- the mouse arrow, 8 x 11 (1 black, 2 white; slots 12 and 13)
DATA "1       ", "11      ", "121     ", "1221    ", "12221   ", "122221  "
DATA "1222221 ", "12222221", "122211  ", "1211    ", "11      "

'----- SetInst: the projection and the raster pointed at model i's rotated
'----- vertices and sort order (0 = the player: Prep's own arrays)
SUB SetInst (i AS INTEGER)
	IF nmod < 2 THEN CALL UseModel(0) ELSE CALL UseModel(i)
	IF i = 0 THEN
		prq(0) = VARSEG(rx(0)): prq(1) = VARPTR(rx(0))
		prq(2) = VARSEG(ry(0)): prq(3) = VARPTR(ry(0))
		prq(4) = VARSEG(rz(0)): prq(5) = VARPTR(rz(0))
		prm(17) = VARSEG(ord(0)): prm(18) = VARPTR(ord(0))
		prq(6) = VARSEG(vt(0)): prq(7) = VARPTR(vt(0)): prm(5) = prq(6): prm(6) = prq(7)
		prq(8) = prq(6): prq(9) = prq(7) + 2
	ELSE
		prq(0) = VARSEG(rxs(0, i)): prq(1) = VARPTR(rxs(0, i))
		prq(2) = VARSEG(rys(0, i)): prq(3) = VARPTR(rys(0, i))
		prq(4) = VARSEG(rzs(0, i)): prq(5) = VARPTR(rzs(0, i))
		prm(17) = VARSEG(ords(0, i)): prm(18) = VARPTR(ords(0, i))
		prq(6) = VARSEG(vts(0, i)): prq(7) = VARPTR(vts(0, i)): prm(5) = prq(6): prm(6) = prq(7)
		prq(8) = prq(6): prq(9) = prq(7) + 2
	END IF
END SUB

'----- PlaceCopy: the player's current rotation (Prep's arrays) and place kept
'----- as one more model
SUB PlaceCopy (px AS LONG, py AS LONG, pz AS LONG)
	DIM i AS INTEGER, n AS INTEGER
	IF ninst >= MAXI OR nmod = 2 THEN EXIT SUB
	n = ninst
	FOR i = 0 TO nv - 1: rxs(i, n) = rx(i): rys(i, n) = ry(i): rzs(i, n) = rz(i): NEXT
	FOR i = 0 TO nf - 1: ords(i, n) = ord(i): NEXT
	FOR i = 0 TO nv * 4 - 1: vts(i, n) = vt(i): NEXT
	ipx(n) = px: ipy(n) = py: ipz(n) = pz
	iyaw(n) = plyaw: iph(n) = aph + CLNG(n) * acyc(0) \ 3: ifr(n) = afcur
	iclp(n) = 0: itm(n) = RND * ilen(0, 0): iwt(n) = 60 + RND * 240: ilst(n) = 0
	ninst = ninst + 1
END SUB

'----- DrawAll: the frame -- every model projected for its box, the union of
'----- the boxes (and the last frame's) filled from the backdrop in the
'----- full-screen work buffer, the models drawn into it far to near, the
'----- ink, the vertical blank (unless V turned it off), the block to VRAM
SUB DrawAll
	DIM i AS INTEGER, j AS INTEGER, k AS INTEGER, bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER
	DIM rw AS INTEGER, rh AS INTEGER, wo AS LONG, w1 AS INTEGER, seq(0 TO MAXI - 1) AS INTEGER
	bx = 319: by = 199: ex = 0: ey = 0
	FOR i = 0 TO ninst - 1
		CALL SetInst(i)
		CALL ProjInst(i)
		'----- (3 px of margin: the blue outline's two rings, and the ink's skipped border)
		IF bx1 - 3 < bx THEN bx = bx1 - 3
		IF by1 - 3 < by THEN by = by1 - 3
		IF bx2 + 4 > ex THEN ex = bx2 + 4
		IF by2 + 4 > ey THEN ey = by2 + 4
		ibx(i) = bx1 - 3: iby(i) = by1 - 3: iex(i) = bx2 + 4: iey(i) = by2 + 4
		seq(i) = i
	NEXT
	'----- joined with the last frame's region, clamped
	IF ox2 >= 0 THEN
		IF ox < bx THEN bx = ox
		IF oy < by THEN by = oy
		IF ox2 > ex THEN ex = ox2
		IF oy2 > ey THEN ey = oy2
	END IF
	IF bx < 0 THEN bx = 0
	IF by < 0 THEN by = 0
	IF ex > 319 THEN ex = 319
	IF ey > 199 THEN ey = 199
	IF ex < bx OR ey < by THEN EXIT SUB
	'----- this frame's own region for next time
	ox = 319: oy = 199: ox2 = 0: oy2 = 0
	FOR i = 0 TO ninst - 1
		IF ibx(i) < ox THEN ox = ibx(i)
		IF iby(i) < oy THEN oy = iby(i)
		IF iex(i) > ox2 THEN ox2 = iex(i)
		IF iey(i) > oy2 THEN oy2 = iey(i)
	NEXT
	IF ox < 0 THEN ox = 0
	IF oy < 0 THEN oy = 0
	IF ox2 > 319 THEN ox2 = 319
	IF oy2 > 199 THEN oy2 = 199
	rw = ex - bx + 1: rh = ey - by + 1
	wo = CLNG(wko) + CLNG(by) * 320 + bx
	IF curOn THEN CALL CurCopy(ocx, ocy): CALL CurCopy(mcx, mcy)
	CALL RectCopy(bgseg, bgo + CLNG(by) * 320 + bx, wseg, wo, rh, rw, 320, 320)
	'----- far to near (by depth of place)
	FOR i = 1 TO ninst - 1
		FOR j = 0 TO ninst - 2 - (i - 1)
			IF ipz(seq(j)) < ipz(seq(j + 1)) THEN k = seq(j): seq(j) = seq(j + 1): seq(j + 1) = k
		NEXT
	NEXT
	prm(20) = 0: prm(21) = 0: prm(24) = flatT + dotT * 256: prm(25) = quadT OR &H8000
	'----- the men far to near, each front piece put back once the men behind it
	'----- are drawn (with pieces, each man is outlined as he is drawn)
	k = 0
	FOR j = 0 TO ninst - 1
		i = seq(j)
		DO WHILE k < nocc
			IF odep(oord(k)) <= ipz(i) THEN EXIT DO
			CALL OccApply(oord(k), bx, by, ex, ey): k = k + 1
		LOOP
		CALL SetInst(i)
		prm(22) = 0
		DEF SEG = VARSEG(ovlTri)
		CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
		DEF SEG
		tris = tris + prm(22)
		IF nocc > 0 THEN CALL InkBox(i, bx, by, ex, ey)
	NEXT
	DO WHILE k < nocc: CALL OccApply(oord(k), bx, by, ex, ey): k = k + 1: LOOP
	w1 = wo: IF wo > 32767 THEN w1 = wo - 65536
	IF nocc = 0 THEN CALL Ink(w1, 320, rw, rh)
	IF curOn THEN CALL CurDraw(mcx, mcy)
	IF vsync THEN
		WAIT &H3DA, 8, 8
		WAIT &H3DA, 8
	END IF
	CALL RectCopyM(wseg, wo, &HA000, CLNG(by) * 320 + bx, rh, rw, 320, 320, 15)
	IF curOn THEN CALL CurBlit(ocx, ocy): CALL CurBlit(mcx, mcy): ocx = mcx: ocy = mcy
END SUB

'----- OccApply: front piece o put back -- the backdrop under its mask copied into
'----- the work buffer, within the frame's box (bx, by)..(ex, ey)
SUB OccApply (o AS INTEGER, bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER)
	DIM x0 AS INTEGER, y0 AS INTEGER, x1 AS INTEGER, y1 AS INTEGER, a AS LONG, s1 AS INTEGER, d1 AS INTEGER, m1 AS INTEGER, nr AS INTEGER, nc AS INTEGER, mseg AS INTEGER, mw AS INTEGER
	x0 = ocx0(o): IF bx > x0 THEN x0 = bx
	y0 = ocy0(o): IF by > y0 THEN y0 = by
	x1 = ocx0(o) + ocw(o) - 1: IF ex < x1 THEN x1 = ex
	y1 = ocy0(o) + och(o) - 1: IF ey < y1 THEN y1 = ey
	IF x1 < x0 OR y1 < y0 THEN EXIT SUB
	a = CLNG(bgo) + CLNG(y0) * 320 + x0: IF a > 32767 THEN a = a - 65536
	s1 = a
	a = CLNG(wko) + CLNG(y0) * 320 + x0: IF a > 32767 THEN a = a - 65536
	d1 = a
	m1 = VARPTR(ocm(0)) + ooff(o) + (y0 - ocy0(o)) * ocw(o) + (x0 - ocx0(o))
	nr = y1 - y0 + 1: nc = x1 - x0 + 1: mseg = VARSEG(ocm(0)): mw = ocw(o)
	DEF SEG = VARSEG(ovlMcpy)
	CALL ABSOLUTE(BYVAL bgseg, BYVAL s1, BYVAL wseg, BYVAL d1, BYVAL mseg, BYVAL m1, BYVAL nr, BYVAL nc, BYVAL 320, BYVAL mw, SADD(ovlMcpy))
	DEF SEG
END SUB

'----- InkBox: model i's outline, within its own box (kept inside the frame's)
SUB InkBox (i AS INTEGER, bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER)
	DIM x0 AS INTEGER, y0 AS INTEGER, x1 AS INTEGER, y1 AS INTEGER, a AS LONG, w1 AS INTEGER
	x0 = ibx(i): IF bx > x0 THEN x0 = bx
	y0 = iby(i): IF by > y0 THEN y0 = by
	x1 = iex(i): IF ex < x1 THEN x1 = ex
	y1 = iey(i): IF ey < y1 THEN y1 = ey
	IF x1 - x0 < 2 OR y1 - y0 < 2 THEN EXIT SUB
	a = CLNG(wko) + CLNG(y0) * 320 + x0: IF a > 32767 THEN a = a - 65536
	w1 = a
	CALL Ink(w1, 320, x1 - x0 + 1, y1 - y0 + 1)
END SUB




'----- DarkSeg: the segment of the dark-colour table (C3DEDGK, outline 4): 256 flags at
'----- its offset 0 -- a palette colour this dark (r+g+b < 48 of 765: the backdrop's and his
'----- blacks; not the outline's own slots 14 and 15) is 1. Built when first wanted and again
'----- whenever a REDIM has moved dkt to a different 16-byte alignment
FUNCTION DarkSeg%
	DIM a AS LONG, s AS LONG, o AS LONG, al AS INTEGER, i AS INTEGER, c AS INTEGER, p AS INTEGER
	s = VARSEG(dkt(0)): IF s < 0 THEN s = s + 65536
	o = VARPTR(dkt(0)): IF o < 0 THEN o = o + 65536
	a = s * 16 + o: al = (16 - (a AND 15)) AND 15
	IF al <> dkal THEN
		DEF SEG = VARSEG(dkt(0))
		FOR i = 0 TO 255
			c = ASC(MID$(palb, i * 4 + 1, 1)) + ASC(MID$(palb, i * 4 + 2, 1)) + ASC(MID$(palb, i * 4 + 3, 1))
			p = 0: IF c < 48 AND i <> 14 AND i <> 15 THEN p = 1
			POKE o + al + i, p
		NEXT
		DEF SEG
		dkal = al
	END IF
	a = (a + al) \ 16: IF a > 32767 THEN a = a - 65536
	DarkSeg% = a
END FUNCTION

'----- OutlineCol: CGA colour c (0..15) into palette slots 14 and 15 (the
'----- outline's marks; the brown mode's mark is blitted as 15 as well)
SUB OutlineCol (c AS INTEGER)
	DIM r AS INTEGER, g AS INTEGER, b AS INTEGER, i AS INTEGER, hi AS INTEGER
	hi = 0: IF c AND 8 THEN hi = 85
	r = hi: g = hi: b = hi
	IF c AND 4 THEN r = r + 170
	IF c AND 2 THEN g = g + 170
	IF c AND 1 THEN b = b + 170
	IF c = 6 THEN g = 85
	OUT &H3C8, 14
	FOR i = 14 TO 15
		OUT &H3C9, r \ 4: OUT &H3C9, g \ 4: OUT &H3C9, b \ 4
		MID$(palb, i * 4 + 1, 3) = CHR$(b) + CHR$(g) + CHR$(r)
	NEXT
END SUB

'----- Ink: the outline in the work buffer block at offset w1 (row stride, rw x rh).
'----- outl 1: C3DEDGE marks his edge pixels that touch the background 254,
'----- slot 15 in the blit, like the drawn outline of the 2D sprites; 2/3:
'----- C3DEDGO rings him on the background side, his own edge pixels kept --
'----- 15 for the first ring, 14 for the second (both the outline colour,
'----- OutlineCol: [ and ] step it through the CGA colours)
'----- outl 4: C3DEDGK, the 1 px ring only where a black pixel of his meets a black background
'----- outl 5: C3DEDGI, the same drawn on his own black edge pixels instead (his size kept)
SUB Ink (w1 AS INTEGER, stride AS INTEGER, rw AS INTEGER, rh AS INTEGER)
	DIM tm AS INTEGER, ts AS INTEGER
	IF outl = 0 OR rw < 3 OR rh < 3 THEN EXIT SUB
	IF outl = 4 THEN
		tm = 16 + 15 * 256: ts = DarkSeg%
		DEF SEG = VARSEG(ovlEdgk)
		CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL stride, BYVAL rw, BYVAL rh, BYVAL tm, BYVAL ts, SADD(ovlEdgk))
		DEF SEG
		EXIT SUB
	END IF
	IF outl = 5 THEN
		tm = 16 + 15 * 256: ts = DarkSeg%
		DEF SEG = VARSEG(ovlEdgi)
		CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL stride, BYVAL rw, BYVAL rh, BYVAL tm, BYVAL ts, SADD(ovlEdgi))
		DEF SEG
		EXIT SUB
	END IF
	IF outl = 1 THEN
		DEF SEG = VARSEG(ovlEdge)
		CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL stride, BYVAL rw, BYVAL rh, SADD(ovlEdge))
		DEF SEG
		EXIT SUB
	END IF
	tm = 16 + 15 * 256
	DEF SEG = VARSEG(ovlEdgo)
	CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL stride, BYVAL rw, BYVAL rh, BYVAL tm, SADD(ovlEdgo))
	DEF SEG
	IF outl = 3 THEN
		tm = 15 + 14 * 256
		DEF SEG = VARSEG(ovlEdgo)
		CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL stride, BYVAL rw, BYVAL rh, BYVAL tm, SADD(ovlEdgo))
		DEF SEG
	END IF
END SUB

'----- ProjInst: model i projected at its place; in a room at its RoomK scale (C3DPRJ
'----- word 26), lowered so its feet stay on the floor
SUB ProjInst (i AS INTEGER)
	DIM k AS SINGLE, y AS LONG
	IF roomOn THEN
		k = RoomK!(ipz(i))
		prq(26) = CINT(k * 256)
		IF nmod < 2 THEN y = -CLNG(rch * 16) - CLNG(rymnm(0) * k) ELSE y = -CLNG(rch * 16) - CLNG(rymnm(i) * k)
		CALL Project(ipx(i), y, ipz(i))
	ELSE
		prq(26) = 0
		CALL Project(ipx(i), ipy(i), ipz(i))
	END IF
END SUB

'----- Ms: PIT units (1.193 MHz) between two PitNow readings, in ms
FUNCTION Ms! (t1 AS LONG, t2 AS LONG)
	DIM d AS LONG
	d = t2 - t1
	IF d < 0 THEN d = d + 2147483647
	Ms! = d / 1193.18
END FUNCTION

'----- Bench: MANWALK B -- each phase of a frame timed with the PIT, far (the
'----- start, about 45 px tall) and near (about 130 px), then whole frames with
'----- 1, 2 and 4 models; vsync off. -> MANWALK.LOG
SUB Bench
	DIM fh AS INTEGER, sc AS INTEGER, n AS INTEGER, i AS INTEGER, t1 AS LONG, t2 AS LONG, px AS LONG, py AS LONG, pz AS LONG
	DIM rw AS INTEGER, rh AS INTEGER, wo AS LONG, w1 AS INTEGER, polys AS LONG, a AS SINGLE, k AS STRING, q AS LONG
	DIM tf2a AS SINGLE
	DIM tr4(0 TO 4) AS SINGLE, j AS INTEGER, tcull AS SINGLE, sb(0 TO MAXF) AS INTEGER, sc2(0 TO MAXF) AS INTEGER, rep AS INTEGER, tt AS SINGLE
	DIM tp AS SINGLE, tc AS SINGLE, tr AS SINGLE, ti AS SINGLE, tb AS SINGLE, tq AS SINGLE, tqb AS SINGLE, tl AS SINGLE, tf1 AS SINGLE, tf2 AS SINGLE, tf4 AS SINGLE
	fh = FREEFILE
	OPEN "MANWALK.LOG" FOR OUTPUT AS #fh
	PRINT #fh, "MANWALK B: verts"; nv; " polys"; nf; " (ms per call, PIT-timed; frames with flat<4px + quads + dots<1.25px, best of 3)"
	vsync = 0: n = 20
	FOR sc = 1 TO 2
		CALL PathPos(40, px, py, pz, 16)
		IF sc = 2 THEN pz = 2500: px = -300
		py = ipy(0)
		'----- projection
		t1 = PitNow&
		FOR i = 1 TO n: CALL SetInst(0): CALL Project(px, py, pz): NEXT
		t2 = PitNow&: tp = Ms!(t1, t2) / n
		rw = bx2 - bx1 + 4: rh = by2 - by1 + 4
		IF bx1 < 1 THEN bx1 = 1
		IF by1 < 1 THEN by1 = 1
		wo = CLNG(wko) + CLNG(by1 - 1) * 320 + bx1 - 1
		w1 = wo: IF wo > 32767 THEN w1 = wo - 65536
		'----- the backdrop block into the work buffer (the man's box)
		t1 = PitNow&
		FOR i = 1 TO n: CALL RectCopy(bgseg, bgo + CLNG(by1 - 1) * 320 + bx1 - 1, wseg, wo, rh, rw, 320, 320): NEXT
		t2 = PitNow&: tc = Ms!(t1, t2) / n
		'----- the raster (projected once above): textured; flat 4 px; quads shared; both
		prm(20) = 0: prm(21) = 0: polys = 0
		FOR j = 0 TO 4
			prm(24) = 0: prm(25) = &H8000
			IF j = 1 OR j = 3 OR j = 4 THEN prm(24) = 64
			IF j = 2 OR j = 3 OR j = 4 THEN prm(25) = 384 OR &H8000
			IF j = 4 THEN prm(24) = 64 + 20 * 256
			FOR rep = 1 TO 3
				t1 = PitNow&
				FOR i = 1 TO n
					prm(22) = 0
					DEF SEG = VARSEG(ovlTri)
					CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
					DEF SEG
					IF j = 0 AND rep = 1 THEN polys = polys + prm(22)
				NEXT
				t2 = PitNow&: tt = Ms!(t1, t2) / n
				IF rep = 1 OR tt < tr4(j) THEN tr4(j) = tt
			NEXT
		NEXT
		tr = tr4(0)
		'----- the loop's fixed cost: every face degenerate (a=b=c), so only the
		'----- per-face loads and the cull run
		FOR i = 0 TO nf - 1: sb(i) = fa(i, 0).b: sc2(i) = fa(i, 0).c: fa(i, 0).b = fa(i, 0).a: fa(i, 0).c = fa(i, 0).a: NEXT
		prm(24) = 0: prm(25) = &H8000
		t1 = PitNow&
		FOR i = 1 TO n
			prm(22) = 0
			DEF SEG = VARSEG(ovlTri)
			CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
			DEF SEG
		NEXT
		t2 = PitNow&: tcull = Ms!(t1, t2) / n
		FOR i = 0 TO nf - 1: fa(i, 0).b = sb(i): fa(i, 0).c = sc2(i): NEXT
		'----- the ink
		t1 = PitNow&
		FOR i = 1 TO n
			DEF SEG = VARSEG(ovlEdge)
			CALL ABSOLUTE(BYVAL wseg, BYVAL w1, BYVAL WKW, BYVAL rw, BYVAL rh, SADD(ovlEdge))
			DEF SEG
		NEXT
		t2 = PitNow&: ti = Ms!(t1, t2) / n
		'----- the blit to VRAM
		t1 = PitNow&
		FOR i = 1 TO n: CALL RectCopyM(wseg, wo, &HA000, CLNG(by1 - 1) * 320 + bx1 - 1, rh, rw, 320, 320, 3): NEXT
		t2 = PitNow&: tb = Ms!(t1, t2) / n
		IF sc = 1 THEN PRINT #fh, "far  (box"; rw; "x"; rh; "px, polys drawn"; polys \ n; "):"; ELSE PRINT #fh, "near (box"; rw; "x"; rh; "px, polys drawn"; polys \ n; "):";
		PRINT #fh, " project"; INT(tp * 100) / 100; " copy-in"; INT(tc * 100) / 100; " raster"; INT(tr * 100) / 100; " ink"; INT(ti * 100) / 100; " blit"; INT(tb * 100) / 100; " = "; INT((tp + tc + tr + ti + tb) * 100) / 100
		PRINT #fh, "     raster textured"; INT(tr4(0) * 100) / 100; "  flat<4px"; INT(tr4(1) * 100) / 100; "  quads shared"; INT(tr4(2) * 100) / 100; "  both"; INT(tr4(3) * 100) / 100; "  +dots<1.25px"; INT(tr4(4) * 100) / 100; " ms (best of 3)"
		PRINT #fh, "     loads+cull only (all faces degenerate)"; INT(tcull * 100) / 100; " ms"
		'----- whole frames with 1, 2, 4 models (copies beside him), flat 4 px + quads shared
		flatT = 64: quadT = 384: dotT = 20
		ninst = 1: ox2 = -1
		ipx(0) = px: ipy(0) = py: ipz(0) = pz
		FOR rep = 1 TO 3
			t1 = PitNow&
			FOR i = 1 TO n: CALL DrawAll: NEXT
			t2 = PitNow&: tt = Ms!(t1, t2) / n: IF rep = 1 OR tt < tf1 THEN tf1 = tt
		NEXT
		CALL PlaceCopy(px + 400, py, pz + 300): ox2 = -1
		FOR rep = 1 TO 3
			t1 = PitNow&
			FOR i = 1 TO n: CALL DrawAll: NEXT
			t2 = PitNow&: tt = Ms!(t1, t2) / n: IF rep = 1 OR tt < tf2 THEN tf2 = tt
		NEXT
		tf2a = 0
		IF anf(0) > 0 THEN
			FOR rep = 1 TO 3
				t1 = PitNow&
				FOR i = 1 TO n: CALL PoseInst(0, i MOD anf(0), 0): CALL PoseInst(1, (i + 5) MOD anf(0), .6): CALL DrawAll: NEXT
				t2 = PitNow&: tt = Ms!(t1, t2) / n: IF rep = 1 OR tt < tf2a THEN tf2a = tt
			NEXT
			CALL PoseInst(0, -1, 0): CALL PoseInst(1, -1, .6)
		END IF
		CALL PlaceCopy(px - 400, py, pz + 600): CALL PlaceCopy(px + 800, py, pz + 900): ox2 = -1
		FOR rep = 1 TO 3
			t1 = PitNow&
			FOR i = 1 TO n: CALL DrawAll: NEXT
			t2 = PitNow&: tt = Ms!(t1, t2) / n: IF rep = 1 OR tt < tf4 THEN tf4 = tt
		NEXT
		PRINT #fh, "     frames, no vsync: 1 model"; INT(tf1 * 100) / 100; " ms ("; INT(1000 / tf1); " fps)  2 models"; INT(tf2 * 100) / 100; " ("; INT(1000 / tf2); ")  4 models"; INT(tf4 * 100) / 100; " ("; INT(1000 / tf4); ")"
		IF anf(0) > 0 THEN PRINT #fh, "     2 models walking, both re-posed every frame (the worst case):"; INT(tf2a * 100) / 100; " ms ("; INT(1000 / tf2a); " fps)"
		ninst = 1: ox2 = -1
	NEXT
	'----- the rotate-and-sort, asm and QB; the loop's own overhead
	t1 = PitNow&
	FOR i = 1 TO n: CALL PrepAsm(.01 * i): NEXT
	t2 = PitNow&: tq = Ms!(t1, t2) / n
	t1 = PitNow&
	FOR i = 1 TO 5: CALL Prep(.01 * i): NEXT
	t2 = PitNow&: tqb = Ms!(t1, t2) / 5
	a = .3
	t1 = PitNow&
	FOR i = 1 TO n
		k = INKEY$: sc = INP(&H60): q = PitNow&
		q = q - CLNG(SIN(a) * 16 * 2): q = q - CLNG(COS(a) * 16 * 2)
	NEXT
	t2 = PitNow&: tl = Ms!(t1, t2) / n
	PRINT #fh, "rotate+sort: asm (C3DROT)"; INT(tq * 100) / 100; " ms   QB (Prep)"; INT(tqb * 100) / 100; " ms   loop overhead (keys, PIT, sin/cos)"; INT(tl * 100) / 100; " ms"
	CLOSE #fh
	OUT &H43, &H36: OUT &H40, 0: OUT &H40, 0
	uglRestore
	uglEnd
	SCREEN 0: WIDTH 80, 25
	PRINT "MANWALK B: MANWALK.LOG written"
	END
END SUB

'----- ShowFps: the number top left, 3x5 digits in the light cyan of the
'----- backdrop palette (slot 2) on a black box, straight into VRAM (and into
'----- the backdrop copy, so the dirty rectangle restores it too)
SUB ShowFps (n AS INTEGER)
	DIM s AS STRING, i AS INTEGER, r AS INTEGER, c AS INTEGER, x AS INTEGER, y AS INTEGER, bits AS INTEGER, v AS INTEGER
	s = LTRIM$(STR$(n))
	IF LEN(s) > 4 THEN s = "9999"
	FOR y = 0 TO 8
		FOR x = 0 TO 21
			v = 0
			c = (x - 2) \ 4: r = y - 2
			IF x >= 2 AND r >= 0 AND r <= 4 AND c < LEN(s) THEN
				IF ((x - 2) MOD 4) < 3 THEN
					bits = dig(VAL(MID$(s, c + 1, 1)), r)
					IF ((x - 2) MOD 4) = 0 THEN i = 4 ELSE IF ((x - 2) MOD 4) = 1 THEN i = 2 ELSE i = 1
					IF (bits AND i) <> 0 THEN v = 2
				END IF
			END IF
			DEF SEG = &HA000
			POKE CLNG(y + 2) * 320 + x + 2, v
			DEF SEG = bgseg
			POKE CLNG(bgo) + CLNG(y + 2) * 320 + x + 2, v
			DEF SEG
		NEXT
	NEXT
END SUB

'----- Prep: rotate the model (x16 units) and its normals (x256) about Y by
'----- yaw, light each face into its texture band fband() and sort the faces
'----- far-to-near into ord(). Translation does not change the order, so the
'----- frame only projects. The only float here: COS/SIN.
SUB Prep (yaw AS SINGLE)
	DIM cs AS INTEGER, sn AS INTEGER, i AS INTEGER, f AS INTEGER, bk AS INTEGER, n AS INTEGER
	DIM nxr AS INTEGER, nzr AS INTEGER, sh AS INTEGER, band AS INTEGER, d AS INTEGER
	cs = CINT(COS(yaw) * 256): sn = CINT(SIN(yaw) * 256)
	FOR i = 0 TO nv - 1
		rx(i) = (CLNG(mx(i, 0)) * cs + CLNG(mz(i, 0)) * sn) \ 256
		rz(i) = (CLNG(mz(i, 0)) * cs - CLNG(mx(i, 0)) * sn) \ 256
		ry(i) = my(i, 0)
	NEXT
	FOR i = 0 TO 255: head(i) = -1: NEXT
	FOR f = 0 TO nf - 1
		IF unlit THEN
			fband(f) = 0
		ELSE
			nxr = (CLNG(nx(f)) * cs + CLNG(nz(f)) * sn) \ 256
			nzr = (CLNG(nz(f)) * cs - CLNG(nx(f)) * sn) \ 256
			sh = (CLNG(nxr) * lx + CLNG(ny(f)) * ly + CLNG(nzr) * lz) \ 256
			'----- band 0..7 = 3 + 4.5 * cos(angle to the light)
			band = (768 + (CLNG(sh) * 9) \ 2) \ 256
			IF band < 0 THEN band = 0
			IF band > 7 THEN band = 7
			fband(f) = band
		END IF
		'----- depth bucket by the summed z (x16 units, about +-4000)
		d = (rz(fa(f, 0).a) + rz(fa(f, 0).b) + rz(fa(f, 0).c) + 4096) \ 32
		IF d < 0 THEN d = 0
		IF d > 255 THEN d = 255
		lnk(f) = head(d): head(d) = f
	NEXT
	n = 0
	FOR bk = 255 TO 0 STEP -1
		f = head(bk)
		DO WHILE f >= 0
			ord(n) = f: n = n + 1
			f = lnk(f)
		LOOP
	NEXT
END SUB

'----- Project: C3DPRJ - sx()/sy() of the prepared model at world (px,py,pz)
'----- (x16 units) and the screen box bx1..by2
SUB Project (px AS LONG, py AS LONG, pz AS LONG)
	CALL LoSplit(px, prq(11), prq(12))
	CALL LoSplit(py, prq(13), prq(14))
	CALL LoSplit(pz, prq(15), prq(16))
	DEF SEG = VARSEG(ovlPrj)
	CALL ABSOLUTE(BYVAL VARSEG(prq(0)), BYVAL VARPTR(prq(0)), SADD(ovlPrj))
	DEF SEG
	'----- the projection is in 1/16 pixel; the box in whole pixels
	bx1 = prq(17) \ 16: bx2 = prq(18) \ 16: by1 = prq(19) \ 16: by2 = prq(20) \ 16
END SUB

'----- DrawCar: project, place the work buffer over the union of the previous
'----- and the new box, fill it from the backdrop, draw the faces, blit the
'----- block to VRAM in the vertical blank
SUB DrawCar (px AS LONG, py AS LONG, pz AS LONG)
	DIM bx AS INTEGER, by AS INTEGER, ex AS INTEGER, ey AS INTEGER, dx AS INTEGER, dy AS INTEGER
	DIM rw AS INTEGER, rh AS INTEGER, wo AS LONG
	CALL Project(px, py, pz)
	IF bmode = 1 THEN EXIT SUB
	'----- this frame's box (padded, clamped) joined with the last one
	bx = bx1 - 1: by = by1 - 1: ex = bx2 + 2: ey = by2 + 2
	IF ox2 >= 0 THEN
		IF ox < bx THEN bx = ox
		IF oy < by THEN by = oy
		IF ox2 > ex THEN ex = ox2
		IF oy2 > ey THEN ey = oy2
	END IF
	IF bx < 0 THEN bx = 0
	IF by < 0 THEN by = 0
	IF ex > 319 THEN ex = 319
	IF ey > 199 THEN ey = 199
	ox = bx1 - 1: oy = by1 - 1: ox2 = bx2 + 2: oy2 = by2 + 2
	IF ox < 0 THEN ox = 0
	IF oy < 0 THEN oy = 0
	IF ox2 > 319 THEN ox2 = 319
	IF oy2 > 199 THEN oy2 = 199
	'----- the work buffer's place on screen: covers the box, stays inside the
	'----- screen (a box bigger than the buffer - zoomed in - is simply cut)
	dx = bx: dy = by
	IF dx > 320 - WKW THEN dx = 320 - WKW
	IF dy > 200 - WKH THEN dy = 200 - WKH
	'----- only the box itself is copied in and out (the buffer is bigger than
	'----- the car so the car never has to be cut; the bus traffic stays small)
	IF ex > dx + WKW - 1 THEN ex = dx + WKW - 1
	IF ey > dy + WKH - 1 THEN ey = dy + WKH - 1
	rw = ex - bx + 1: rh = ey - by + 1
	wo = CLNG(wko) + CLNG(by - dy) * WKW + (bx - dx)
	CALL RectCopy(bgseg, bgo + CLNG(by) * 320 + bx, wseg, wo, rh, rw, 320, WKW)
	IF bmode = 2 THEN EXIT SUB
	prm(20) = dx * 16: prm(21) = dy * 16: prm(22) = 0
	DEF SEG = VARSEG(ovlTri)
	CALL ABSOLUTE(BYVAL VARSEG(prm(0)), BYVAL VARPTR(prm(0)), SADD(ovlTri))
	DEF SEG
	tris = tris + prm(22)
	'----- silhouette ink: car pixels that border the background get marked
	'----- (254) here and turn brown (3) in the blit below, like the drawn
	'----- outline of the original CGA sprite
	IF outl AND rw >= 2 AND rh >= 2 THEN
		DEF SEG = VARSEG(ovlEdge)
		CALL ABSOLUTE(BYVAL wseg, BYVAL CINT(wo), BYVAL WKW, BYVAL rw, BYVAL rh, SADD(ovlEdge))
		DEF SEG
	END IF
	'----- (the benchmark skips the retrace wait so it measures the work)
	IF bmode = 0 THEN
		WAIT &H3DA, 8, 8
		WAIT &H3DA, 8
	END IF
	CALL RectCopyM(wseg, wo, &HA000, CLNG(by) * 320 + bx, rh, rw, WKW, 320, 3)
END SUB

'----- RectCopyM: C3DBLTM.OVL - the same copy as RectCopy, with every 254
'----- (the ink mark) written as colour col
SUB RectCopyM (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER, col AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBltm)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL col, SADD(ovlBltm))
	DEF SEG
END SUB

'----- RectCopy: SHADBOP.OVL mode 0 - rows x nb bytes from sg:so (stride sst)
'----- to dg:dof (stride dst); offsets as LONG 0..65535
SUB RectCopy (sg AS INTEGER, so AS LONG, dg AS INTEGER, dof AS LONG, rows AS INTEGER, nb AS INTEGER, sst AS INTEGER, dst AS INTEGER)
	DIM a AS LONG, b AS LONG, s1 AS INTEGER, d1 AS INTEGER
	a = so: IF a > 32767 THEN a = a - 65536
	b = dof: IF b > 32767 THEN b = b - 65536
	s1 = a: d1 = b
	DEF SEG = VARSEG(ovlBop)
	CALL ABSOLUTE(BYVAL sg, BYVAL s1, BYVAL dg, BYVAL d1, BYVAL rows, BYVAL nb, BYVAL sst, BYVAL dst, BYVAL 0, SADD(ovlBop))
	DEF SEG
END SUB

'----- NormSeg: the segment at which (sg:ofs) is offset 0..15
FUNCTION NormSeg% (sg AS INTEGER, ofs AS INTEGER)
	DIM s AS LONG, o AS LONG
	s = sg: IF s < 0 THEN s = s + 65536
	o = ofs: IF o < 0 THEN o = o + 65536
	s = s + o \ 16
	IF s > 32767 THEN s = s - 65536
	NormSeg% = s
END FUNCTION

'----- LONG -> two words (lo as the signed INTEGER holding the low 16 bits)
SUB LoSplit (v AS LONG, lo AS INTEGER, hi AS INTEGER)
	DIM l AS LONG
	l = v AND &HFFFF&
	hi = (v - l) \ 65536
	IF l > 32767 THEN l = l - 65536
	lo = l
END SUB

SUB LoadOvl (fil AS STRING, s AS STRING)
	DIM n AS INTEGER
	n = FREEFILE
	OPEN fil FOR BINARY AS #n
	s = SPACE$(LOF(n))
	IF LOF(n) > 0 THEN GET #n, 1, s
	CLOSE #n
END SUB

SUB Fail (msg AS STRING)
	uglRestore
	uglEnd
	SCREEN 0: WIDTH 80, 25
	PRINT "CAR3D: "; msg
	END
END SUB

'----- SaveShot: the visible 320x200 screen as an 8-bit BMP with the palette
'----- (one uglPGet per pixel - slow, but only for the S mode)
SUB SaveShot (fil AS STRING)
	DIM fh AS INTEGER, x AS INTEGER, y AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN fil FOR BINARY AS #fh
	s = "BM" + MKL$(54 + 1024 + 64000) + MKL$(0) + MKL$(54 + 1024)
	s = s + MKL$(40) + MKL$(320) + MKL$(200) + MKI$(1) + MKI$(8) + MKL$(0) + MKL$(64000)
	s = s + MKL$(2835) + MKL$(2835) + MKL$(256) + MKL$(0)
	PUT #fh, , s
	PUT #fh, , palb
	s = SPACE$(320)
	FOR y = 199 TO 0 STEP -1
		FOR x = 0 TO 319
			MID$(s, x + 1, 1) = CHR$(uglPGet(vdc, x, y) AND 255)
		NEXT
		PUT #fh, , s
	NEXT
	CLOSE #fh
END SUB

'----- carr.pic (BSAVE of B800, 16 KB) -> bg DC as indices 0..3 with the 2D car
'----- erased, onto the screen once, then VRAM -> bgb() for the frame copies
SUB LoadBackdrop
	DIM y AS INTEGER, x AS INTEGER, k AS INTEGER, ofs AS INTEGER, hv AS INTEGER, lo AS INTEGER, hi AS INTEGER
	DIM fh AS INTEGER, s AS STRING
	'----- a painted backdrop (converter -Backdrop -> CARROAD.BMP, 320x200,
	'----- bottom-up, palette slots 0..15) replaces the carr.pic composition:
	'----- straight into bgb() and VRAM, nothing erased, no computed road
	fh = FREEFILE
	OPEN "CARROAD.BMP" FOR BINARY AS #fh
	IF LOF(fh) > 1078 THEN
		s = SPACE$(320)
		SEEK #fh, 1079
		FOR y = 199 TO 0 STEP -1
			GET #fh, , s
			CALL RectCopy(VARSEG(s), CLNG(SADD(s)), bgseg, CLNG(bgo) + CLNG(y) * 320, 1, 320, 320, 320)
		NEXT
		CLOSE #fh
		CALL RectCopy(bgseg, CLNG(bgo), &HA000, 0, 200, 320, 320, 320)
		EXIT SUB
	END IF
	CLOSE #fh
	IF LOF(fh) = 0 THEN KILL "CARROAD.BMP"
	REDIM cga(0 TO 8191) AS INTEGER
	REDIM lut(0 TO 255, 0 TO 1) AS INTEGER
	REDIM row(0 TO 159) AS INTEGER
	DEF SEG = VARSEG(cga(0)): BLOAD "CARR.PIC", VARPTR(cga(0)): DEF SEG
	FOR k = 0 TO 255
		lut(k, 0) = (k \ 64) + ((k \ 16) AND 3) * 256
		lut(k, 1) = ((k \ 4) AND 3) + (k AND 3) * 256
	NEXT
	FOR y = 0 TO 199
		ofs = (y \ 2) * 40 + (y AND 1) * 4096
		k = 0
		FOR x = 0 TO 39
			hv = cga(ofs + x)
			lo = hv AND 255
			hi = (hv AND &H7F00) \ 256
			IF hv < 0 THEN hi = hi + 128
			row(k) = lut(lo, 0): row(k + 1) = lut(lo, 1)
			row(k + 2) = lut(hi, 0): row(k + 3) = lut(hi, 1)
			k = k + 4
		NEXT
		'----- the painted road (brown, attr 3) goes: everything below the tree
		'----- trunks, which end at row 126, and its start at the right in 123..126
		IF y >= 123 THEN
			FOR k = 0 TO 159
				IF y >= 127 OR k >= 140 THEN
					IF (row(k) AND 255) = 3 THEN row(k) = row(k) AND &HFF00
					IF (row(k) \ 256) = 3 THEN row(k) = row(k) AND 255
				END IF
			NEXT
		END IF
		uglRowWriteBuff bg, 0, y, 320, UGL.BF.8BIT, row(0)
	NEXT
	'----- the 2D car sprite gone (Intro lifts it with GET/PUT XOR)
	uglRectF bg, 8, 133, 105, 175, 0
	'----- the road edges in perspective, on the car's ground plane
	CALL RoadEdge(-1)
	CALL RoadEdge(1)
	uglPut vdc, 0, 0, bg
	CALL RectCopy(&HA000, 0, bgseg, CLNG(bgo), 200, 320, 320, 320)
END SUB

'----- CAR3D.MDL (see tools\car3dcnv.ps1): floats in the file, converted once
'----- to x16 (vertices), 8.8 texels (u,v) and x256 (normals) integers
SUB LoadModel
	DIM fh AS INTEGER, i AS INTEGER, h AS Hdr, vv AS Vtx, nm AS Nrm, t AS LONG
	fh = FREEFILE
	OPEN "CAR3D.MDL" FOR BINARY AS #fh
	IF LOF(fh) = 0 THEN CLOSE #fh: PRINT "CAR3D.MDL missing": END
	GET #fh, , h
	IF h.magic <> "C3D2" THEN CLOSE #fh: PRINT "CAR3D.MDL: wrong format (rerun tools\car3dcnv.ps1)": END
	nv = h.nv: nf = h.nf: unlit = h.flags AND 1
	IF nv > MAXV + 1 OR nf > MAXF + 1 THEN CLOSE #fh: PRINT "model too big": END
	nvm(0) = nv: nfm(0) = nf: nmod = 1
	FOR i = 0 TO nv - 1
		GET #fh, , vv
		mx(i, 0) = CINT(vv.x * 16): my(i, 0) = CINT(vv.y * 16): mz(i, 0) = CINT(vv.z * 16)
		'----- texel coordinates, 8.8 fixed point over the texture's width (into the
		'----- interleaved vertices too: x, y from the projection, u, v these)
		t = CLNG(vv.u * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		tu(i) = t: vt(i * 4 + 2) = t
		t = CLNG(vv.v * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		tv(i) = t: vt(i * 4 + 3) = t
	NEXT
	FOR i = 0 TO nf - 1: GET #fh, , fa(i, 0): NEXT
	FOR i = 0 TO nf - 1
		GET #fh, , nm
		nx(i) = CINT(nm.x * 256): ny(i) = CINT(nm.y * 256): nz(i) = CINT(nm.z * 256)
	NEXT
	CLOSE #fh
END SUB

'----- LoadModel2: the second character into slot 1 -- JAMES.MDL (car3dcnv's format, unlit,
'----- the man's mesh or its own) with JAMES.BMP (its texture, the same width as CAR3D.BMP's,
'----- its colours in CAR3D.BMP's palette: tools\manwalk.ps1 merges them); u, v straight into
'----- slot 1's interleaved vertices. Either file missing: one character (nmod 1)
SUB LoadModel2
	DIM fh AS INTEGER, i AS INTEGER, h AS Hdr, vv AS Vtx, t AS LONG, w AS INTEGER, n AS LONG, s AS STRING
	fh = FREEFILE
	OPEN "JAMES.BMP" FOR BINARY AS #fh
	n = LOF(fh): w = 0
	IF n >= 1078 THEN s = SPACE$(4): GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	CLOSE #fh
	IF n = 0 THEN KILL "JAMES.BMP"
	IF n < 1078 OR w <> texW THEN EXIT SUB
	fh = FREEFILE
	OPEN "JAMES.MDL" FOR BINARY AS #fh
	IF LOF(fh) = 0 THEN CLOSE #fh: KILL "JAMES.MDL": EXIT SUB
	GET #fh, , h
	IF h.magic <> "C3D2" OR h.nv > MAXV + 1 OR h.nf > MAXF + 1 OR (h.flags AND 1) = 0 THEN CLOSE #fh: EXIT SUB
	nvm(1) = h.nv: nfm(1) = h.nf
	FOR i = 0 TO h.nv - 1
		GET #fh, , vv
		mx(i, 1) = CINT(vv.x * 16): my(i, 1) = CINT(vv.y * 16): mz(i, 1) = CINT(vv.z * 16)
		t = CLNG(vv.u * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		vts(i * 4 + 2, 1) = t
		t = CLNG(vv.v * (CLNG(texW) * 256 - 64)): IF t < 0 THEN t = 0
		IF t > CLNG(texW) * 256 - 1 THEN t = CLNG(texW) * 256 - 1
		vts(i * 4 + 3, 1) = t
	NEXT
	FOR i = 0 TO h.nf - 1: GET #fh, , fa(i, 1): NEXT
	CLOSE #fh
	nmod = 2
END SUB

'----- UseModel: the rotate, projection and raster blocks pointed at slot m's model -- its
'----- faces, vertex and face counts, texture (nv and nf become its)
SUB UseModel (m AS INTEGER)
	nv = nvm(m): nf = nfm(m)
	prq(10) = nv: prr(12) = nv: prr(19) = nf: prm(19) = nf
	prr(15) = VARSEG(fa(0, m)): prr(16) = VARPTR(fa(0, m))
	prm(13) = prr(15): prm(14) = prr(16)
	IF m = 0 THEN
		prm(4) = VARSEG(bt(0)): prm(23) = VARPTR(bt(0))
	ELSE
		prm(4) = VARSEG(bt1(0)): prm(23) = VARPTR(bt1(0))
	END IF
END SUB

'----- the 256 BGRA entries of CAR3D.BMP -> DAC
SUB LoadPalette
	DIM i AS INTEGER, fh AS INTEGER, s AS STRING
	REDIM pal(0 TO 255) AS tRGB
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	SEEK #fh, 55
	s = INPUT$(1024, #fh)
	CLOSE #fh
	'----- (slots 14 and 15, above the backdrop's colours, are the outline: OutlineCol)
	palb = s
	FOR i = 0 TO 255
		pal(i).blue = MID$(s, i * 4 + 1, 1)
		pal(i).green = MID$(s, i * 4 + 2, 1)
		pal(i).red = MID$(s, i * 4 + 3, 1)
	NEXT
	uglPalSetBuff 0, 256, pal(0)
END SUB

'----- the pixels of CAR3D.BMP (texW wide, texW*bands rows, stored bottom-up)
'----- -> one 16-byte-aligned array per lighting band, its segment in bt(b)
'----- (band b's texel row y sits at that segment, offset y*texW); with a second
'----- character, JAMES.BMP (unlit, one band) into tb1, its segment in bt1 -- then
'----- CAR3D.BMP must be unlit too. Every array sized first, the segments taken
'----- after the last REDIM (one can move the others), then the pixels copied in
SUB LoadTexture
	DIM fh AS INTEGER, r AS INTEGER, h AS INTEGER, w AS INTEGER, bands AS INTEGER, b AS INTEGER, y AS INTEGER, s AS STRING
	DIM tp AS INTEGER
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	s = SPACE$(4)
	GET #fh, 19, s: w = CVI(LEFT$(s, 2))
	GET #fh, 23, s: h = CVI(LEFT$(s, 2))
	CLOSE #fh
	IF w <> texW THEN Fail "CAR3D.BMP width changed"
	bands = h \ w
	IF bands < 1 OR bands > 8 OR bands * w <> h THEN Fail "CAR3D.BMP must be W x (W*bands)"
	IF bands > 1 AND nmod = 2 THEN Fail "two characters: CAR3D.BMP must be unlit (one band)"
	FOR b = 0 TO bands - 1: CALL BandAlloc(b, w): NEXT
	IF nmod = 2 THEN
		CALL BandAlloc(1, w)
		tp = VARPTR(tb0(0)): bt(0) = NormSeg(VARSEG(tb0(0)), tp + ((16 - (tp AND 15)) AND 15))
		tp = VARPTR(tb1(0)): bt(1) = NormSeg(VARSEG(tb1(0)), tp + ((16 - (tp AND 15)) AND 15))
		FOR b = 0 TO 7: bt1(b) = bt(1): NEXT
		bt(1) = bt(0)
	END IF
	FOR b = bands TO 7: bt(b) = bt(bands - 1): NEXT
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	s = SPACE$(w)
	SEEK #fh, 1079
	FOR r = 0 TO h - 1
		GET #fh, , s
		y = h - 1 - r
		b = y \ w
		CALL RectCopy(VARSEG(s), CLNG(SADD(s)), bt(b), CLNG(y - b * w) * w, 1, w, w, w)
	NEXT
	CLOSE #fh
	IF nmod < 2 THEN EXIT SUB
	fh = FREEFILE
	OPEN "JAMES.BMP" FOR BINARY AS #fh
	SEEK #fh, 1079
	FOR r = 0 TO w - 1
		GET #fh, , s
		y = w - 1 - r
		CALL RectCopy(VARSEG(s), CLNG(SADD(s)), bt1(0), CLNG(y) * w, 1, w, w, w)
	NEXT
	CLOSE #fh
END SUB

'----- BandAlloc: size band b's array to w*w bytes (+16 for alignment) and
'----- record the segment at which its data starts at offset 0
SUB BandAlloc (b AS INTEGER, w AS INTEGER)
	DIM n AS INTEGER, tp AS INTEGER, sg AS INTEGER
	n = (CLNG(w) * w + 16) \ 2
	SELECT CASE b
	CASE 0: REDIM tb0(0 TO n) AS INTEGER: tp = VARPTR(tb0(0)): sg = VARSEG(tb0(0))
	CASE 1: REDIM tb1(0 TO n) AS INTEGER: tp = VARPTR(tb1(0)): sg = VARSEG(tb1(0))
	CASE 2: REDIM tb2(0 TO n) AS INTEGER: tp = VARPTR(tb2(0)): sg = VARSEG(tb2(0))
	CASE 3: REDIM tb3(0 TO n) AS INTEGER: tp = VARPTR(tb3(0)): sg = VARSEG(tb3(0))
	CASE 4: REDIM tb4(0 TO n) AS INTEGER: tp = VARPTR(tb4(0)): sg = VARSEG(tb4(0))
	CASE 5: REDIM tb5(0 TO n) AS INTEGER: tp = VARPTR(tb5(0)): sg = VARSEG(tb5(0))
	CASE 6: REDIM tb6(0 TO n) AS INTEGER: tp = VARPTR(tb6(0)): sg = VARSEG(tb6(0))
	CASE 7: REDIM tb7(0 TO n) AS INTEGER: tp = VARPTR(tb7(0)): sg = VARSEG(tb7(0))
	END SELECT
	bt(b) = NormSeg(sg, tp + ((16 - (tp AND 15)) AND 15))
END SUB

'----- TexWidth: the width of CAR3D.BMP (64 or 128), read before anything else
FUNCTION TexWidth%
	DIM fh AS INTEGER, s AS STRING
	fh = FREEFILE
	OPEN "CAR3D.BMP" FOR BINARY AS #fh
	IF LOF(fh) < 1078 THEN CLOSE #fh: PRINT "CAR3D.BMP missing": END
	s = SPACE$(4)
	GET #fh, 19, s
	CLOSE #fh
	TexWidth% = CVI(LEFT$(s, 2))
END FUNCTION

'----- PathPos: world position (x16 units) at step ts of 200 along the drive
'----- (constant speed along the road); zm = 16 is the real distance
SUB PathPos (ts AS INTEGER, px AS LONG, py AS LONG, pz AS LONG, zm AS INTEGER)
	px = (PX0 + (CLNG(ts) * PDX) \ 200) * zm \ 16
	py = (PY0 + (CLNG(ts) * PDY) \ 200) * zm \ 16
	pz = (PZ0 + (CLNG(ts) * PDZ) \ 200) * zm \ 16
END SUB

'----- PitNow: time in 1.193 MHz PIT units from the BIOS tick count and the
'----- channel 0 countdown (re-read if a tick landed in between); wraps every
'----- 30 min, differences are what matter
FUNCTION PitNow&
	DIM lo AS INTEGER, hi AS INTEGER, cnt AS LONG, t1 AS LONG, t2 AS LONG
	DEF SEG = &H40
	DO
		t1 = PEEK(&H6C) + CLNG(PEEK(&H6D)) * 256
		OUT &H43, 0
		lo = INP(&H40): hi = INP(&H40)
		t2 = PEEK(&H6C) + CLNG(PEEK(&H6D)) * 256
	LOOP WHILE t1 <> t2
	DEF SEG
	cnt = 65535 - (CLNG(hi) * 256 + lo)
	PitNow& = (t1 AND &H7FFF&) * 65536 + cnt
END FUNCTION

'----- RoadEdge: one edge of the road (side -1 = nearer the camera, 1 = the
'----- far one) as a brown line on the backdrop: the line on the ground plane
'----- ROADW2 units beside the drive, projected (two points well in front of
'----- the camera, the projection of a line is a line) and clipped to the
'----- screen. Floats are fine here: this runs once.
SUB RoadEdge (side AS INTEGER)
	DIM dxp AS SINGLE, dzp AS SINGLE, l AS SINGLE, nxp AS SINGLE, nzp AS SINGLE
	DIM s AS SINGLE, wx AS SINGLE, wz AS SINGLE, x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE
	DIM t0 AS SINGLE, t1 AS SINGLE, p AS SINGLE, q AS SINGLE, r AS SINGLE, e AS INTEGER
	dxp = PDX / 16: dzp = PDZ / 16
	l = SQR(dxp * dxp + dzp * dzp)
	nxp = -dzp / l: nzp = dxp / l
	'----- the two points: s = -.8 (just in front of the camera) and s = 6 (far)
	FOR e = 1 TO 2
		IF e = 1 THEN s = -.8 ELSE s = 6
		wx = PX0 / 16 + s * dxp + side * ROADW2 * nxp
		wz = PZ0 / 16 + s * dzp + side * ROADW2 * nzp
		IF wz < 20 THEN wz = 20
		IF e = 1 THEN
			x1 = 160 + 256 * wx / wz: y1 = 100 - 256 * GROUNDY / wz
		ELSE
			x2 = 160 + 256 * wx / wz: y2 = 100 - 256 * GROUNDY / wz
		END IF
	NEXT
	'----- Liang-Barsky clip to 0..319 x 0..199
	t0 = 0: t1 = 1
	FOR e = 1 TO 4
		SELECT CASE e
		CASE 1: p = -(x2 - x1): q = x1
		CASE 2: p = x2 - x1: q = 319 - x1
		CASE 3: p = -(y2 - y1): q = y1
		CASE 4: p = y2 - y1: q = 199 - y1
		END SELECT
		IF p = 0 THEN
			IF q < 0 THEN EXIT SUB
		ELSE
			r = q / p
			IF p < 0 THEN
				IF r > t1 THEN EXIT SUB
				IF r > t0 THEN t0 = r
			ELSE
				IF r < t0 THEN EXIT SUB
				IF r < t1 THEN t1 = r
			END IF
		END IF
	NEXT
	uglLine bg, CINT(x1 + t0 * (x2 - x1)), CINT(y1 + t0 * (y2 - y1)), CINT(x1 + t1 * (x2 - x1)), CINT(y1 + t1 * (y2 - y1)), 3
END SUB
