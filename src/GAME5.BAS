'----- GAME5.BAS: player rendering module (walk-to movement phase 1).
'----- Fifth code module -> its own 64K code segment. Pure library like GAME4
'----- (no COMMON SHARED): callers pass sprite/mask/save-under arrays as params.
'-----
'----- PStand: erase the standing player (save-under PSET) then draw facing d$
'-----   ("2"=dn "8"=up "4"=lt "6"=rt "1"=dl "7"=ul "9"=ur "3"=dr, ""=erase only).
'-----   nopl close-up rooms erase but never draw, matching the old face: code.
'----- PStep: one walk half-step at (x,y): GET save-under, masked frame draw
'-----   (fb 0=frame A, 1=frame B), footstep sound (the SOUNDs are the pacing),
'-----   then restore the save-under so the next half-step starts clean.
'-----   ofs = start element in the frame arrays (0 for plain wa/wb scratch,
'-----   d*151 to pick a direction slot out of the startup-cached sets).
'-----   (named ofs because OFF is a QB reserved word)
'----- LoadWalks: read joew1-8 .pct/.msk once into the 8-slot cache arrays
'-----   (slot d*151: 0=down/joew1, 1=up/joew2, 2=right/joew3, 3=left/joew4,
'-----   4=dn-left/joew5, 5=dn-right/joew6, 6=up-left/joew7, 7=up-right/joew8)
'-----   so walking never re-reads sprite files from disk mid-game.
'----- walkTo: walk the player from (px,py) to (tx,ty) DIAGONAL-FIRST --
'-----   full (3,2) steps with the matching diagonal sprite set while BOTH
'-----   axes still have a step left, then the remainder on the classic
'-----   straight rails (horizontal 3px, then vertical 2px), frames
'-----   alternating, per-direction sound pacing (right/left 1, down 1.2,
'-----   up 1.4, dn-diagonals 1.1, up-diagonals 1.2). Updates px,py by ref.

'----- OvTop: foreground overlays (furniture the player walks BEHIND). ovf(0)=count,
'----- 4 meta ints per overlay (x, y, pct start, msk start; 0 = no mask), frame data
'----- packed after -- re-PUT every overlay whose box intersects the player's 31x31.
DECLARE SUB OvTop (px!, py!, ovf%())

'----- walk-box floor pathfinding (ROOMx.BOX). See LoadBoxes below.
DECLARE SUB LoadBoxes (rm$, bxa%())
DECLARE FUNCTION PtInBox% (fx!, fy!, bxa%(), bi%)
DECLARE SUB SnapFloor (sx!, sy!, bxa%())
DECLARE SUB NearInBox (fx!, fy!, bxa%(), bi%, nx!, ny!)
DECLARE FUNCTION NearBox% (fx!, fy!, bxa%())
DECLARE FUNCTION BoxAt% (fx!, fy!, bxa%())
DECLARE FUNCTION Adjacent% (bxa%(), i%, j%)
DECLARE FUNCTION SegInt% (ax!, ay!, bx!, by!, cx!, cy!, dx!, dy!, ix!, iy!)
DECLARE SUB GateOf (bxa%(), i%, j%, gx!, gy!)
DECLARE SUB FindPath (sx!, sy!, gx!, gy!, bxa%(), wpx!(), wpy!(), wpn%)
DECLARE SUB WalkSeg (tx!, ty!, px!, py!, sfrq!, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
DECLARE SUB WalkFloor (tx!, ty!, px!, py!, sfrq!, bxa%(), cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())

'----- wfb: the walk stride phase (0=frame A, 1=frame B). Module-level so it
'----- PERSISTS across walkTo calls -- short diagonal legs (1-3 steps) would
'----- otherwise restart on frame A every walk and frame B would never show.
DIM SHARED wfb%

SUB OvTop (px!, py!, ovf%())
	IF ovf%(0) < 1 THEN EXIT SUB
	FOR oi% = 1 TO ovf%(0)
		om% = 1 + (oi% - 1) * 4
		ox% = ovf%(om%): oy% = ovf%(om% + 1)
		os% = ovf%(om% + 2)
		ow% = ovf%(os%) \ 2: oh% = ovf%(os% + 1)
		IF ox% < px! + 31 AND ox% + ow% > px! AND oy% < py! + 31 AND oy% + oh% > py! THEN
			IF ovf%(om% + 3) > 0 THEN
				PUT (ox%, oy%), ovf%(ovf%(om% + 3)), AND
				PUT (ox%, oy%), ovf%(os%), OR
			ELSE
				PUT (ox%, oy%), ovf%(os%), PSET
			END IF
		END IF
	NEXT
END SUB

SUB PStand (d$, px!, py!, nopl!, fbg%(), fd%(), mfd%(), fu%(), mfu%(), fr%(), mfr%(), fl%(), mfl%(), fdl%(), mfdl%(), fdr%(), mfdr%(), ful%(), mful%(), fur%(), mfur%(), ovf%())
	PUT (px!, py!), fbg%(0), PSET
	IF nopl! = 1 THEN EXIT SUB
	IF d$ = "4" THEN PUT (px!, py!), mfl%(0), AND: PUT (px!, py!), fl%(0), OR
	IF d$ = "2" THEN PUT (px!, py!), mfd%(0), AND: PUT (px!, py!), fd%(0), OR
	IF d$ = "6" THEN PUT (px!, py!), mfr%(0), AND: PUT (px!, py!), fr%(0), OR
	IF d$ = "8" THEN PUT (px!, py!), mfu%(0), AND: PUT (px!, py!), fu%(0), OR
	IF d$ = "1" THEN PUT (px!, py!), mfdl%(0), AND: PUT (px!, py!), fdl%(0), OR
	IF d$ = "7" THEN PUT (px!, py!), mful%(0), AND: PUT (px!, py!), ful%(0), OR
	IF d$ = "9" THEN PUT (px!, py!), mfur%(0), AND: PUT (px!, py!), fur%(0), OR
	IF d$ = "3" THEN PUT (px!, py!), mfdr%(0), AND: PUT (px!, py!), fdr%(0), OR
	IF d$ <> "" THEN CALL OvTop(px!, py!, ovf%())
END SUB

SUB PStep (x!, y!, fb%, sfrq!, sdur!, ofs%, wa%(), mwa%(), wb%(), mwb%(), wbg%(), ovf%())
	GET (x!, y!)-(x! + 30, y! + 30), wbg%(0)
	IF fb% = 0 THEN
		PUT (x!, y!), mwa%(ofs%), AND: PUT (x!, y!), wa%(ofs%), OR
	ELSE
		PUT (x!, y!), mwb%(ofs%), AND: PUT (x!, y!), wb%(ofs%), OR
	END IF
	CALL OvTop(x!, y!, ovf%())
	SOUND sfrq!, .1
	FOR j% = 1 TO 2: SOUND 32676, sdur!: NEXT
	PUT (x!, y!), wbg%(0), PSET
END SUB

SUB LoadWalks (cwa%(), cmwa%(), cwb%(), cmwb%())
	'----- fh = file handle (fn* names are illegal in QB -- reserved for DEF FN)
	FOR d% = 0 TO 7
		fh% = FREEFILE
		OPEN "joew" + CHR$(49 + d%) + ".pct" FOR INPUT AS #fh%
		FOR i% = 0 TO 125
			IF EOF(fh%) THEN EXIT FOR
			INPUT #fh%, cwa%(d% * 151 + i%), cwb%(d% * 151 + i%)
		NEXT
		CLOSE #fh%
		fh% = FREEFILE
		OPEN "joew" + CHR$(49 + d%) + ".msk" FOR INPUT AS #fh%
		FOR i% = 0 TO 125
			IF EOF(fh%) THEN EXIT FOR
			INPUT #fh%, cmwa%(d% * 151 + i%), cmwb%(d% * 151 + i%)
		NEXT
		CLOSE #fh%
	NEXT
END SUB

'----- PicSeq: full-screen .pic cutscene player (anim mode "seq"). BLOADs
'-----   sq$+"01".pic .. sq$+NN.pic at rate%*0.025s a frame -- HALF the unit
'-----   the other anim modes use (integer rates were too coarse to tune a
'-----   14-frame cutscene: 0.10s vs 0.15s with nothing between) -- then settles on
'-----   sq$+"x.pic" -- the SAME player-less end-state file a bg placement
'-----   shows on later room loads. Rows 0-21 (the live top message) are
'-----   lifted before the first frame and re-stamped over every BLOAD so the
'-----   triggering action's message stays readable through the play.
'-----   sn2$ non-empty = PLAY string fired at the start ("MB.." = background).
SUB PicSeq (sq$, fr$, rate%, sn2$)
	n% = VAL(fr$)
	IF n% < 1 THEN EXIT SUB
	REDIM tb%(884)
	GET (0, 0)-(319, 21), tb%
	IF sn2$ <> "" THEN PLAY sn2$
	FOR f% = 1 TO n%
		pf$ = LTRIM$(STR$(f%))
		IF f% < 10 THEN pf$ = "0" + pf$
		DEF SEG = -18432
		BLOAD sq$ + pf$ + ".pic", 0
		DEF SEG
		PUT (0, 0), tb%, PSET
		t! = TIMER
		DO
			IF TIMER < t! THEN EXIT DO
		LOOP WHILE TIMER < t! + rate% * .025
	NEXT
	DEF SEG = -18432
	BLOAD sq$ + "x.pic", 0
	DEF SEG
	PUT (0, 0), tb%, PSET
	ERASE tb%
END SUB

SUB walkTo (tx!, ty!, px!, py!, sfrq!, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
	'----- stride phase wfb% carries over from the previous walk (no reset)
	'----- diagonal leg: full (3,2) steps while both axes still need one
	WHILE ABS(tx! - px!) >= 3 AND ABS(ty! - py!) >= 2
		IF ty! > py! THEN
			IF tx! > px! THEN d% = 5 ELSE d% = 4
			sd! = 1.1
		ELSE
			IF tx! > px! THEN d% = 7 ELSE d% = 6
			sd! = 1.2
		END IF
		px! = px! + SGN(tx! - px!) * 3
		py! = py! + SGN(ty! - py!) * 2
		CALL PStep(px!, py!, wfb%, sfrq!, sd!, d% * 151, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
		wfb% = 1 - wfb%
	WEND
	WHILE px! <> tx!
		'----- 4px stride at down-walk cadence = same speed, step sound in rhythm
		IF tx! > px! THEN d% = 2 ELSE d% = 3
		IF ABS(tx! - px!) <= 3 THEN px! = tx! ELSE px! = px! + SGN(tx! - px!) * 4
		CALL PStep(px!, py!, wfb%, sfrq!, 1.12, d% * 151, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
		wfb% = 1 - wfb%
	WEND
	WHILE py! <> ty!
		IF ty! > py! THEN d% = 0: sd! = 1.2 ELSE d% = 1: sd! = 1.4
		IF ABS(ty! - py!) <= 2 THEN py! = ty! ELSE py! = py! + SGN(ty! - py!) * 2
		CALL PStep(px!, py!, wfb%, sfrq!, sd!, d% * 151, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
		wfb% = 1 - wfb%
	WEND
END SUB

'----- ClimbSeq: rope-climb cutscene (room12). Loads CLIMB.PCT/.MSK (2
'----- interleaved 31x31 frames, golf-style 2-column text) into the caller's
'----- scratch arrays, then PStep-walks the sprite vertically at x: up=0
'----- descends y0->y1, up=1 ascends y1->y0. 2px half-steps, frames alternate,
'----- and each step restores its save-under so the rope stays clean behind.
SUB ClimbSeq (up%, x!, y0!, y1!, sfrq!, wa%(), mwa%(), wb%(), mwb%(), wbg%(), ovf%())
	fh% = FREEFILE
	OPEN "climb.pct" FOR INPUT AS #fh%
	FOR i% = 0 TO 149
		IF EOF(fh%) THEN EXIT FOR
		INPUT #fh%, wa%(i%), wb%(i%)
	NEXT
	CLOSE #fh%
	fh% = FREEFILE
	OPEN "climb.msk" FOR INPUT AS #fh%
	FOR i% = 0 TO 149
		IF EOF(fh%) THEN EXIT FOR
		INPUT #fh%, mwa%(i%), mwb%(i%)
	NEXT
	CLOSE #fh%
	cf% = 0
	IF up% = 0 THEN
		FOR i% = y0! TO y1! STEP 2
			CALL PStep(x!, CSNG(i%), cf%, sfrq!, 1.2, 0, wa%(), mwa%(), wb%(), mwb%(), wbg%(), ovf%())
			cf% = 1 - cf%
		NEXT
	ELSE
		FOR i% = y1! TO y0! STEP -2
			CALL PStep(x!, CSNG(i%), cf%, sfrq!, 1.2, 0, wa%(), mwa%(), wb%(), mwb%(), wbg%(), ovf%())
			cf% = 1 - cf%
		NEXT
	END IF
END SUB

'----- Walk-box floor (the convex areas the player may walk), authored per room in
'----- haedit and stored as the sidecar ROOMx.BOX (one quad/line: x1,y1,..,x4,y4).
'----- bxa(0) = box count; then 8 ints per box (4 corners). A missing/empty file
'----- leaves the count 0 and the caller keeps the old rectangle walk-band.
'----- Coordinates are the player's FEET (bottom-centre). Because a straight line
'----- can't leave a convex box, snapping the stand target into a box is enough to
'----- keep the walk on the floor within that box (multi-box routing = phase 2).
SUB LoadBoxes (rm$, bxa%())
	bxa%(0) = 0
	lbxN% = 0
	fh% = FREEFILE
	'----- a missing .box file errors on OPEN; the caller (loadroom) traps it and
	'----- keeps the count at 0. QB propagates an untrapped SUB error to the caller.
	OPEN rm$ + ".box" FOR INPUT AS #fh%
	DO WHILE NOT EOF(fh%) AND lbxN% < 24
		o% = 1 + lbxN% * 8
		INPUT #fh%, bxa%(o%), bxa%(o% + 1), bxa%(o% + 2), bxa%(o% + 3), bxa%(o% + 4), bxa%(o% + 5), bxa%(o% + 6), bxa%(o% + 7)
		lbxN% = lbxN% + 1
	LOOP
	CLOSE #fh%
	bxa%(0) = lbxN%
END SUB

'----- point (fx,fy) inside convex box bi% -- all four edge cross products share a
'----- sign (a point on an edge = 0 counts as inside). Reads the box's own winding
'----- so clockwise or counter-clockwise both work.
FUNCTION PtInBox% (fx!, fy!, bxa%(), bi%)
	o% = 1 + bi% * 8
	cvP% = 0: cvN% = 0
	FOR e% = 0 TO 3
		ax% = bxa%(o% + e% * 2): ay% = bxa%(o% + e% * 2 + 1)
		g% = (e% + 1) MOD 4
		cx% = bxa%(o% + g% * 2): cy% = bxa%(o% + g% * 2 + 1)
		cr& = CLNG(cx% - ax%) * (fy! - ay%) - CLNG(cy% - ay%) * (fx! - ax%)
		IF cr& > 0 THEN cvP% = 1
		IF cr& < 0 THEN cvN% = 1
	NEXT
	PtInBox% = (cvP% = 0 OR cvN% = 0)
END FUNCTION

'----- snap a stand target (sprite top-left sx,sy) so the FEET (sx+15,sy+30) land
'----- on the floor: if already inside a box, no-op; else move to the nearest point
'----- on any box edge. Convex boxes -> the straight walkTo then stays on the floor.
SUB SnapFloor (sx!, sy!, bxa%())
	IF bxa%(0) < 1 THEN EXIT SUB
	fx! = sx! + 15: fy! = sy! + 30
	IF BoxAt%(fx!, fy!, bxa%()) >= 0 THEN EXIT SUB
	b% = NearBox%(fx!, fy!, bxa%())
	IF b% < 0 THEN EXIT SUB
	CALL NearInBox(fx!, fy!, bxa%(), b%, nx!, ny!)
	sx! = nx! - 15: sy! = ny! - 30
END SUB

'----- nearest point to (fx,fy) within/on convex box bi% (the point itself if inside)
SUB NearInBox (fx!, fy!, bxa%(), bi%, nx!, ny!)
	IF PtInBox%(fx!, fy!, bxa%(), bi%) THEN nx! = fx!: ny! = fy!: EXIT SUB
	o% = 1 + bi% * 8
	bestd! = 1E30
	nx! = fx!: ny! = fy!
	FOR e% = 0 TO 3
		ax! = bxa%(o% + e% * 2): ay! = bxa%(o% + e% * 2 + 1)
		g% = (e% + 1) MOD 4
		cx! = bxa%(o% + g% * 2): cy! = bxa%(o% + g% * 2 + 1)
		dx! = cx! - ax!: dy! = cy! - ay!
		slen! = dx! * dx! + dy! * dy!
		IF slen! <= 0 THEN
			px! = ax!: py! = ay!
		ELSE
			t! = ((fx! - ax!) * dx! + (fy! - ay!) * dy!) / slen!
			IF t! < 0 THEN t! = 0
			IF t! > 1 THEN t! = 1
			px! = ax! + t! * dx!: py! = ay! + t! * dy!
		END IF
		dd! = (px! - fx!) * (px! - fx!) + (py! - fy!) * (py! - fy!)
		IF dd! < bestd! THEN bestd! = dd!: nx! = px!: ny! = py!
	NEXT
END SUB

'----- index of the box nearest (fx,fy) by its closest interior/edge point
FUNCTION NearBox% (fx!, fy!, bxa%())
	NearBox% = -1
	bestd! = 1E30
	FOR b% = 0 TO bxa%(0) - 1
		CALL NearInBox(fx!, fy!, bxa%(), b%, nx!, ny!)
		dd! = (nx! - fx!) * (nx! - fx!) + (ny! - fy!) * (ny! - fy!)
		IF dd! < bestd! THEN bestd! = dd!: NearBox% = b%
	NEXT
END FUNCTION

'----- index of the box containing (fx,fy), or -1
FUNCTION BoxAt% (fx!, fy!, bxa%())
	BoxAt% = -1
	FOR b% = 0 TO bxa%(0) - 1
		IF PtInBox%(fx!, fy!, bxa%(), b%) THEN BoxAt% = b%: EXIT FUNCTION
	NEXT
END FUNCTION

'----- do convex boxes i,j overlap or touch? (SAT: separated if any edge-normal
'----- axis has a projection gap; 1-unit slack so an authored edge-touch counts)
FUNCTION Adjacent% (bxa%(), i%, j%)
	Adjacent% = -1
	FOR side% = 0 TO 1
		IF side% = 0 THEN
			bse% = 1 + i% * 8
		ELSE
			bse% = 1 + j% * 8
		END IF
		FOR e% = 0 TO 3
			ax% = bxa%(bse% + e% * 2): ay% = bxa%(bse% + e% * 2 + 1)
			f% = (e% + 1) MOD 4
			cx% = bxa%(bse% + f% * 2): cy% = bxa%(bse% + f% * 2 + 1)
			nxx! = cy% - ay%: nyy! = ax% - cx%
			oi% = 1 + i% * 8: amin! = 1E30: amax! = -1E30
			FOR k% = 0 TO 3
				pr! = nxx! * bxa%(oi% + k% * 2) + nyy! * bxa%(oi% + k% * 2 + 1)
				IF pr! < amin! THEN amin! = pr!
				IF pr! > amax! THEN amax! = pr!
			NEXT
			oj% = 1 + j% * 8: bmin! = 1E30: bmax! = -1E30
			FOR k% = 0 TO 3
				pr! = nxx! * bxa%(oj% + k% * 2) + nyy! * bxa%(oj% + k% * 2 + 1)
				IF pr! < bmin! THEN bmin! = pr!
				IF pr! > bmax! THEN bmax! = pr!
			NEXT
			IF amax! < bmin! - 1 OR bmax! < amin! - 1 THEN Adjacent% = 0: EXIT FUNCTION
		NEXT
	NEXT
END FUNCTION

'----- segment (ax,ay)-(bx,by) x (cx,cy)-(dx,dy): -1 + point in ix,iy if they cross
FUNCTION SegInt% (ax!, ay!, bx!, by!, cx!, cy!, dx!, dy!, ix!, iy!)
	SegInt% = 0
	r1! = bx! - ax!: r2! = by! - ay!
	s1! = dx! - cx!: s2! = dy! - cy!
	den! = r1! * s2! - r2! * s1!
	IF den! = 0 THEN EXIT FUNCTION
	t! = ((cx! - ax!) * s2! - (cy! - ay!) * s1!) / den!
	u! = ((cx! - ax!) * r2! - (cy! - ay!) * r1!) / den!
	IF t! >= 0 AND t! <= 1 AND u! >= 0 AND u! <= 1 THEN ix! = ax! + t! * r1!: iy! = ay! + t! * r2!: SegInt% = -1
END FUNCTION

'----- gate point in the shared region of adjacent boxes i,j = the average of the
'----- corners of one lying inside the other + the edge-edge crossings (all such
'----- points lie in i AND j, so their average is a point in i n j to walk through)
SUB GateOf (bxa%(), i%, j%, gx!, gy!)
	oi% = 1 + i% * 8: oj% = 1 + j% * 8
	sxg! = 0: syg! = 0: cg% = 0
	FOR e% = 0 TO 3
		pcx! = bxa%(oi% + e% * 2): pcy! = bxa%(oi% + e% * 2 + 1)
		IF PtInBox%(pcx!, pcy!, bxa%(), j%) THEN sxg! = sxg! + pcx!: syg! = syg! + pcy!: cg% = cg% + 1
	NEXT
	FOR e% = 0 TO 3
		pcx! = bxa%(oj% + e% * 2): pcy! = bxa%(oj% + e% * 2 + 1)
		IF PtInBox%(pcx!, pcy!, bxa%(), i%) THEN sxg! = sxg! + pcx!: syg! = syg! + pcy!: cg% = cg% + 1
	NEXT
	FOR e% = 0 TO 3
		a1x! = bxa%(oi% + e% * 2): a1y! = bxa%(oi% + e% * 2 + 1)
		f% = (e% + 1) MOD 4
		a2x! = bxa%(oi% + f% * 2): a2y! = bxa%(oi% + f% * 2 + 1)
		FOR g% = 0 TO 3
			b1x! = bxa%(oj% + g% * 2): b1y! = bxa%(oj% + g% * 2 + 1)
			h% = (g% + 1) MOD 4
			b2x! = bxa%(oj% + h% * 2): b2y! = bxa%(oj% + h% * 2 + 1)
			IF SegInt%(a1x!, a1y!, a2x!, a2y!, b1x!, b1y!, b2x!, b2y!, ixp!, iyp!) THEN sxg! = sxg! + ixp!: syg! = syg! + iyp!: cg% = cg% + 1
		NEXT
	NEXT
	IF cg% > 0 THEN
		gx! = sxg! / cg%: gy! = syg! / cg%
	ELSE
		gx! = (bxa%(oi%) + bxa%(oi% + 2) + bxa%(oi% + 4) + bxa%(oi% + 6) + bxa%(oj%) + bxa%(oj% + 2) + bxa%(oj% + 4) + bxa%(oj% + 6)) / 8
		gy! = (bxa%(oi% + 1) + bxa%(oi% + 3) + bxa%(oi% + 5) + bxa%(oi% + 7) + bxa%(oj% + 1) + bxa%(oj% + 3) + bxa%(oj% + 5) + bxa%(oj% + 7)) / 8
	END IF
END SUB

'----- FindPath (FEET coords): fill wpx/wpy with the walk waypoints, wpn = count.
'----- BFS the box-adjacency graph start->goal, then route through the gate point
'----- of each consecutive box pair (final waypoint = the goal). Off-floor goal is
'----- snapped onto the nearest box; no boxes or no path = a single straight leg.
SUB FindPath (sx!, sy!, gx!, gy!, bxa%(), wpx!(), wpy!(), wpn%)
	nb% = bxa%(0)
	wpn% = 0
	IF nb% < 1 THEN wpx!(0) = gx!: wpy!(0) = gy!: wpn% = 1: EXIT SUB
	gb% = BoxAt%(gx!, gy!, bxa%())
	IF gb% < 0 THEN
		gb% = NearBox%(gx!, gy!, bxa%())
		CALL NearInBox(gx!, gy!, bxa%(), gb%, ngx!, ngy!)
		gx! = ngx!: gy! = ngy!
	END IF
	sb% = BoxAt%(sx!, sy!, bxa%())
	IF sb% < 0 THEN sb% = NearBox%(sx!, sy!, bxa%())
	IF sb% = gb% THEN wpx!(0) = gx!: wpy!(0) = gy!: wpn% = 1: EXIT SUB
	REDIM vis%(31), par%(31), qq%(31), pbx%(31)
	FOR t% = 0 TO nb% - 1: vis%(t%) = 0: par%(t%) = -1: NEXT
	head% = 0: tail% = 1: qq%(0) = sb%: vis%(sb%) = 1: found% = 0
	DO WHILE head% < tail% AND found% = 0
		cur% = qq%(head%): head% = head% + 1
		IF cur% = gb% THEN found% = 1
		IF found% = 0 THEN
			FOR nn% = 0 TO nb% - 1
				IF vis%(nn%) = 0 THEN
					IF Adjacent%(bxa%(), cur%, nn%) THEN vis%(nn%) = 1: par%(nn%) = cur%: qq%(tail%) = nn%: tail% = tail% + 1
				END IF
			NEXT
		END IF
	LOOP
	IF found% = 0 THEN wpx!(0) = gx!: wpy!(0) = gy!: wpn% = 1: EXIT SUB
	plen% = 0: cur% = gb%
	DO
		pbx%(plen%) = cur%: plen% = plen% + 1
		IF cur% = sb% THEN EXIT DO
		cur% = par%(cur%)
		IF cur% < 0 THEN EXIT DO
	LOOP WHILE plen% < 32
	FOR k% = plen% - 1 TO 1 STEP -1
		CALL GateOf(bxa%(), pbx%(k%), pbx%(k% - 1), ggx!, ggy!)
		wpx!(wpn%) = ggx!: wpy!(wpn%) = ggy!: wpn% = wpn% + 1
	NEXT
	wpx!(wpn%) = gx!: wpy!(wpn%) = gy!: wpn% = wpn% + 1
END SUB

'----- walk the player STRAIGHT from (px,py) to (tx,ty) (sprite top-left), one
'----- 8-way direction for the leg (a straight line stays inside a convex box)
SUB WalkSeg (tx!, ty!, px!, py!, sfrq!, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
	dx! = tx! - px!: dy! = ty! - py!
	mv! = ABS(dx!): IF ABS(dy!) > mv! THEN mv! = ABS(dy!)
	ns% = INT(mv! / 3): IF ns% < 1 THEN ns% = 1
	adx! = ABS(dx!): ady! = ABS(dy!)
	IF adx! > ady! * 2 THEN
		IF dx! > 0 THEN d% = 2 ELSE d% = 3
		sd! = 1.12
	ELSEIF ady! > adx! * 2 THEN
		IF dy! > 0 THEN
			d% = 0: sd! = 1.2
		ELSE
			d% = 1: sd! = 1.4
		END IF
	ELSE
		IF dy! > 0 THEN
			IF dx! > 0 THEN d% = 5 ELSE d% = 4
			sd! = 1.1
		ELSE
			IF dx! > 0 THEN d% = 7 ELSE d% = 6
			sd! = 1.2
		END IF
	END IF
	FOR s% = 1 TO ns%
		px! = px! + dx! / ns%: py! = py! + dy! / ns%
		CALL PStep(px!, py!, wfb%, sfrq!, sd!, d% * 151, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
		wfb% = 1 - wfb%
	NEXT
	px! = tx!: py! = ty!
END SUB

'----- WalkFloor: floor-aware walk. Route (px,py)->(tx,ty) through the walk-boxes
'----- and walk each straight leg. Feet = sprite + (15,30); boxes are feet coords.
SUB WalkFloor (tx!, ty!, px!, py!, sfrq!, bxa%(), cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
	REDIM wpx(31) AS SINGLE, wpy(31) AS SINGLE
	wpn% = 0
	CALL FindPath(px! + 15, py! + 30, tx! + 15, ty! + 30, bxa%(), wpx(), wpy(), wpn%)
	FOR w% = 0 TO wpn% - 1
		CALL WalkSeg(wpx(w%) - 15, wpy(w%) - 30, px!, py!, sfrq!, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
	NEXT
END SUB
