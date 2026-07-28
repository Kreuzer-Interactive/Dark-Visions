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
