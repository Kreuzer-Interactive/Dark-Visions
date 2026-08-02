'----- GAME2.BAS: secondary module for the multi-module split (sound effects)
'----- gets its own 64K code segment; shares scalars with GAME.BAS via COMMON SHARED.
'----- The COMMON SHARED line below MUST match GAME.BAS exactly (same names + order).
TYPE RegType
	ax AS INTEGER
	bx AS INTEGER
	cx AS INTEGER
	dx AS INTEGER
	bp AS INTEGER
	si AS INTEGER
	di AS INTEGER
	flags AS INTEGER
	ds AS INTEGER
	es AS INTEGER
END TYPE
DECLARE SUB INTERRUPT (intnum AS INTEGER, inreg AS RegType, outreg AS RegType)
COMMON SHARED f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, sa, sb, sc, mt, sfps, fpsc, fpst, jsen, inon, msen, snr, exsen, mxyon, nfon, hzon$, klon, wksen, qkon, rvon
COMMON SHARED mcur AS INTEGER, mvint AS INTEGER

'----- DeathMusic: play one of four random dirges, note by note so a keypress
'----- or mouse click skips the rest (octave shifts are rebalanced on a skip
'----- since the tunes rely on balanced <...> pairs)
SUB DeathMusic
	DIM mr AS RegType, mo AS RegType
	DIM tn$, nt$, ch$
	DIM i AS INTEGER, shf AS INTEGER, skp AS INTEGER
	RANDOMIZE TIMER
	mt = INT(RND * 4)
	IF mt = 1 THEN tn$ = "<<<g-2g8a+8f+8e8d-3e4f+5f+5e-5e3>d2>>"
	IF mt = 2 THEN tn$ = "<<<d+8e-8<a8g8f3b8g8f+8e3g-2g8a8f+8e8d-3e4f+5c8c8c3>>>"
	IF mt = 3 THEN tn$ = "<<<c3c3d-5d-5c3c3<b-5a-5>c3c3d-5e-5c3c3>>>"
	IF tn$ = "" THEN tn$ = "<g8a8b-8b8<c8g8a8b-8a8a8b8a8>>"
	PLAY "MF"
	i = 1: shf = 0: skp = 0
	DO WHILE i <= LEN(tn$)
		'----- gather octave shifts (and skip spaces) onto the next note
		nt$ = ""
		DO WHILE i <= LEN(tn$)
			ch$ = MID$(tn$, i, 1)
			IF ch$ <> "<" AND ch$ <> ">" AND ch$ <> " " THEN EXIT DO
			IF ch$ = "<" THEN nt$ = nt$ + ch$: shf = shf + 1
			IF ch$ = ">" THEN nt$ = nt$ + ch$: shf = shf - 1
			i = i + 1
		LOOP
		IF i > LEN(tn$) THEN
			IF nt$ <> "" THEN PLAY nt$: shf = 0
			EXIT DO
		END IF
		'----- the note letter plus accidentals / length digits / dots
		nt$ = nt$ + MID$(tn$, i, 1): i = i + 1
		DO WHILE i <= LEN(tn$)
			ch$ = MID$(tn$, i, 1)
			IF (ch$ < "0" OR ch$ > "9") AND ch$ <> "+" AND ch$ <> "-" AND ch$ <> "#" AND ch$ <> "." THEN EXIT DO
			nt$ = nt$ + ch$: i = i + 1
		LOOP
		PLAY nt$
		'----- a key or click skips the rest of the dirge
		IF INKEY$ <> "" THEN skp = 1
		IF skp = 0 AND msen = 1 THEN
			mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
			IF (mo.bx AND 1) <> 0 THEN skp = 1
		END IF
		IF skp = 1 THEN
			IF shf > 0 THEN PLAY STRING$(shf, ">")
			IF shf < 0 THEN PLAY STRING$(-shf, "<")
			'----- signal the caller: the skip press also ends the death screen
			mt = -1
			EXIT DO
		END IF
	LOOP
END SUB

'----- joystick poll (moved from GAME.BAS -- 64K ceiling): read STICK, set the
'----- movement direction into a2$; any direction cancels a pending verb (vk2$)
SUB JoyPoll (a2$, vk2$)
	DIM js0 AS SINGLE, js1 AS SINGLE
	IF jsen <> 1 THEN EXIT SUB
	js0 = STICK(0)
	js1 = STICK(1)
	IF js1 = 0# AND js0 = 0 THEN EXIT SUB
	IF js0 < 40 THEN a2$ = "4"
	IF js0 > 120 THEN a2$ = "6"
	IF js1 < 40 THEN a2$ = "8"
	IF js1 > 120 THEN a2$ = "2"
	IF js1 < 40 AND js0 > 120 THEN a2$ = "9"
	IF js1 < 40 AND js0 < 40 THEN a2$ = "7"
	IF js0 > 120 AND js1 > 120 THEN a2$ = "3"
	IF js0 < 40 AND js1 > 120 THEN a2$ = "1"
	IF LEN(a2$) = 1 THEN
		IF INSTR("123456789", a2$) > 0 THEN vk2$ = ""
	END IF
END SUB

'----- sound effect 1
SUB Snd1
	SOUND f6, 1: SOUND f3, .5: SOUND f7, 1: SOUND f2, .1: SOUND f8, .5
END SUB

'----- sound effect 2
SUB Snd2
	FOR sa = 1 TO 5: SOUND f3, .2: SOUND 32676, 3: NEXT
END SUB

'----- sound effect 3
SUB Snd3
	SOUND f6, .1: SOUND f3, .5
	FOR sb = 100 TO 600 STEP 100: SOUND sb, .1: NEXT
	SOUND f8, .5: SOUND f5, .5
END SUB

'----- sound effect 4
SUB Snd4
	FOR sc = 50 TO 100 STEP 5: SOUND sc, .5: SOUND f9, .1: NEXT
	FOR sc = 100 TO 50 STEP -5: SOUND sc, .5: SOUND f9, .1: NEXT
	SOUND 32676, .5: SOUND f1, .5
END SUB

'----- sound effect 5
SUB Snd5
	FOR sc = 50 TO 80: SOUND f3, .1: SOUND sc, .1: NEXT
	PLAY "p10"
	FOR sc = 1 TO 300 STEP 20: SOUND (RND * 300) + 50, .1: NEXT
	SOUND f3, .2: SOUND 32676, 2: SOUND f3, .2: SOUND 32676, 2
END SUB

'----- debug readout (moved from GAME.BAS -- 64K ceiling): raw mouse xy, snapped hit
'----- point, and the object+verb a click here resolves to
SUB MxyTick (mx%, my%, bx, ay, snr2, ox%(), oy%(), oi%(), ky$())
	oi2% = 0
	mind% = snr2 * snr2 + 1
	FOR i% = 1 TO 257
		IF oy%(i%) = 0 THEN EXIT FOR
		dx% = mx% - ox%(i%)
		dy% = my% - oy%(i%)
		IF ABS(dx%) <= snr2 AND ABS(dy%) <= snr2 THEN
			dd% = dx% * dx% + dy% * dy%
			IF dd% < mind% THEN mind% = dd%: oi2% = oi%(i%)
		END IF
	NEXT
	v$ = "-"
	IF oi2% >= 1 AND oi2% <= 25 THEN v$ = ky$(oi2%)
	IF v$ = "" THEN v$ = "-"
	LOCATE 24, 1
	PRINT USING "mxy ### ### hit ### ### obj ## v="; mx%; my%; bx; ay; oi2%;
	PRINT v$; "  ";
END SUB

'----- hit-zone debug overlay (moved from GAME.BAS): ring each hotspot's snr click-zone
'----- coloured by verb (look=blue, action=brown, get/use=gray) + dot its hit point
SUB HitZones (hz$, snr2, ox%(), oy%(), oi%(), ky$())
	IF hz$ = "" OR snr2 <= 0 THEN EXIT SUB
	FOR i% = 1 TO 257
		IF oy%(i%) = 0 THEN EXIT FOR
		v$ = ky$(oi%(i%))
		IF v$ <> "" AND INSTR(hz$, v$) > 0 THEN
			c% = 2
			IF v$ = "a" THEN c% = 3
			IF v$ = "g" THEN c% = 1
			IF v$ = "u" THEN c% = 1
			CIRCLE (ox%(i%), oy%(i%)), snr2, c%
			PSET (ox%(i%), oy%(i%)), c%
		END IF
	NEXT
END SUB

'----- parse an anim frames field like "0;1;2" into fsq(1..nfr2) frame indices
SUB AnimParse (s$, fsq%(), nfr2%)
	nfr2% = 0
	t$ = s$ + ";"
	sp% = 1
	FOR i% = 1 TO LEN(t$)
		IF MID$(t$, i%, 1) = ";" THEN
			IF i% > sp% AND nfr2% < 30 THEN
				nfr2% = nfr2% + 1
				fsq%(nfr2%) = VAL(MID$(t$, sp%, i% - sp%))
			END IF
			sp% = i% + 1
		END IF
	NEXT
END SUB

'----- pause rate2*0.05s between animation frames (TIMER-based, midnight-safe)
SUB AnimWait (rate2)
	t! = TIMER
	DO
		IF TIMER < t! THEN EXIT SUB
	LOOP WHILE TIMER < t! + rate2 * .05
END SUB

'----- inventory combine: which recipe do items s% (top) + c% (bottom) match? 0 = none.
'----- 1: 18+28 -> 22 · 2: formula halves 11+24 -> unreadable 52 · 4: 52 + book 25 ->
'----- complete formula 36 · 3: syringe 29 + drug 34 -> loaded syringe 35
SUB CombChk (s%, c%, r%)
	r% = 0
	IF (s% = 18 AND c% = 28) OR (s% = 28 AND c% = 18) THEN r% = 1
	IF (s% = 11 AND c% = 24) OR (s% = 24 AND c% = 11) THEN r% = 2
	IF (s% = 52 AND c% = 25) OR (s% = 25 AND c% = 52) THEN r% = 4
	IF (s% = 29 AND c% = 34) OR (s% = 34 AND c% = 29) THEN r% = 3
END SUB

'----- apply combine recipe r%: swap the ingredient ob() flags for the result, and
'----- re-derive 33 (ready to mix) since 36 may just have appeared
SUB CombDo2 (r%, ob(), cn%)
	'----- ingredients become state 2 ("used up"): out of the inventory but
	'----- still counting as taken, so their pickup spots never re-arm
	cn% = 0
	IF r% = 1 THEN ob(18) = 2: ob(28) = 2: ob(22) = 1: cn% = 22
	IF r% = 2 THEN ob(24) = 2: ob(11) = 2: ob(52) = 1: cn% = 52
	IF r% = 3 THEN ob(29) = 2: ob(34) = 2: ob(35) = 1: cn% = 35
	IF r% = 4 THEN ob(52) = 2: ob(36) = 1: cn% = 36
	IF ob(32) = 1 AND ob(36) = 1 THEN ob(33) = 1
END SUB

'----- keyboard/joystick navigation for the inventory screen. Zones: 0 = item grid,
'----- 1 = tabs (left pane), 2 = bottom buttons. k$ = U/D/L/R move, E = activate.
'----- Grid: left off column 0 -> tabs (active tab first); moving toward the inactive
'----- tab ACTIVATES it; down off the grid (or from the tabs) -> the buttons.
'----- Returns the cursor park spot for the focus in mx2%/my2% and act%:
'----- 1 selection changed | 2 tab switched | 3 focus moved | 4 quit | 5 save/load |
'----- 6 exit | 7 combine (grid E on combine tab) | 8 examine (grid E on info tab)
SUB InvNav (k$, nvz, nvb, isel, cic, invtab, ivscr, ivmax, mx2%, my2%, act%)
	act% = 3
	IF nvz = 0 THEN
		IF k$ = "L" THEN
			IF cic = 0 OR (INT(isel) MOD 4) = 0 THEN nvz = 1 ELSE isel = isel - 1: act% = 1
		ELSEIF k$ = "R" THEN
			IF (INT(isel) MOD 4) < 3 AND isel + 1 < cic THEN isel = isel + 1: act% = 1
		ELSEIF k$ = "U" THEN
			IF isel - 4 >= 0 THEN isel = isel - 4: act% = 1 ELSE nvz = 1
		ELSEIF k$ = "D" THEN
			IF isel + 4 < cic THEN isel = isel + 4: act% = 1 ELSE nvz = 2
		ELSEIF k$ = "E" THEN
			IF invtab = 1 THEN act% = 7 ELSE act% = 8
		END IF
	ELSEIF nvz = 1 THEN
		IF k$ = "L" THEN
			IF invtab = 1 THEN invtab = 0: act% = 2
		ELSEIF k$ = "R" THEN
			IF invtab = 0 THEN invtab = 1: act% = 2 ELSE nvz = 0
		ELSEIF k$ = "D" THEN
			nvz = 2
		END IF
	ELSE
		'----- bottom row is just Close now (quit button removed -- q key quits)
		nvb = 0
		IF k$ = "U" THEN
			IF cic > 0 THEN nvz = 0 ELSE nvz = 1
		ELSEIF k$ = "E" THEN
			act% = 6
		END IF
	END IF
	'----- scroll the selected row into view, then park the cursor on the focus:
	'----- items get it at their lower-right, tabs/buttons near their right edge
	IF nvz = 0 THEN
		IF INT(isel / 4) < ivscr THEN ivscr = INT(isel / 4)
		IF INT(isel / 4) > ivscr + 1 THEN ivscr = INT(isel / 4) - 1
		'----- arrow TIP just inside the 45x54 icon's lower-right quadrant
		mx2% = 112 + (INT(isel) MOD 4) * 47 + 36
		my2% = 31 + (INT(isel / 4) - ivscr) * 56 + 44
		IF cic = 0 THEN mx2% = 150: my2% = 85
	ELSEIF nvz = 1 THEN
		'----- tab art: Info 14-52, Combine 53-98, both y28-42
		IF invtab = 0 THEN mx2% = 46 ELSE mx2% = 92
		my2% = 39
	ELSE
		'----- button art: Close ~268-306, y169-181
		mx2% = 300
		my2% = 178
	END IF
END SUB

'----- joystick -> inventory nav letter (same 40/120 thresholds as the game's joy
'----- poll); the latch releases-to-repeat so holding the stick doesn't flood
SUB JoyNav (d$) STATIC
	d$ = ""
	nd$ = ""
	js0% = STICK(0)
	js1% = STICK(1)
	IF js0% < 40 THEN nd$ = "L"
	IF js0% > 120 THEN nd$ = "R"
	IF js1% < 40 THEN nd$ = "U"
	IF js1% > 120 THEN nd$ = "D"
	IF STRIG(1) <> 0 THEN nd$ = "E"
	IF nd$ = ld$ THEN EXIT SUB
	ld$ = nd$
	d$ = nd$
END SUB

'----- reselect the inventory item picked last time (lv%); the grid order can shift
'----- between opens, so match by ITEM NUMBER and scroll its row into view
SUB InvReSel (cilist%(), cic2, lv%, is2, iv2, ivm)
	IF lv% <= 0 THEN EXIT SUB
	FOR i% = 0 TO cic2 - 1
		IF cilist%(i%) = lv% THEN is2 = i%
	NEXT
	iv2 = INT(is2 / 4)
	IF iv2 > ivm THEN iv2 = ivm
END SUB

'----- set a room palette (COLOR + the 3 attribute maps); idempotent
SUB RmPal (co2, p1, p2, p3)
	COLOR co2
	PALETTE 1, p1
	PALETTE 2, p2
	PALETTE 3, p3
END SUB

'----- LoadFade: palette fade-in after loading a game -- steps the whole room
'----- through black, dark gray, light gray and white, then the room palette
SUB LoadFade (co2, p1, p2, p3)
	DIM fi AS INTEGER, fc AS INTEGER
	DIM ft AS SINGLE, fd AS SINGLE
	FOR fi = 1 TO 4
		fc = 0
		IF fi = 2 THEN fc = 8
		IF fi = 3 THEN fc = 7
		IF fi = 4 THEN fc = 15
		PALETTE 1, fc: PALETTE 2, fc: PALETTE 3, fc
		ft = TIMER
		DO
			fd = TIMER - ft
			IF fd < 0 THEN fd = fd + 86400
		LOOP WHILE fd < .13
	NEXT
	CALL RmPal(co2, p1, p2, p3)
END SUB

'----- does the player's 31x31 box intersect rect x1..x2 / y1..y2? (np = nopl close-up)
SUB OvPlayer (x1, y1, x2, y2, pjx2, pjy2, np, ov%)
	ov% = 0
	IF np = 1 THEN EXIT SUB
	IF x1 < pjx2 + 31 AND x2 >= pjx2 AND y1 < pjy2 + 31 AND y2 >= pjy2 THEN ov% = 1
END SUB

'----- walkout/exit direction letter -> numpad facing digit ("" = not a direction)
SUB DirDigit (l$, d$)
	d$ = ""
	IF l$ = "s" THEN d$ = "1"
	IF l$ = "n" THEN d$ = "2"
	IF l$ = "e" THEN d$ = "3"
	IF l$ = "w" THEN d$ = "4"
END SUB

'----- fps counter (moved from GAME.BAS -- 64K ceiling): fpsc/fpst ride in COMMON
SUB FpsTick
	fpsc = fpsc + 1
	fd! = TIMER - fpst
	IF fd! < 0 OR fd! >= 2 THEN
		fpst = TIMER
		fpsc = 0
	ELSEIF fd! >= 1 THEN
		fv! = fpsc / fd!
		IF fv! > 99999 THEN fv! = 99999
		LOCATE 1, 35
		PRINT USING "#####"; fv!;
		fpst = TIMER
		fpsc = 0
	END IF
END SUB

'----- lookmiss brain (moved from GAME.BAS -- 64K ceiling): out$ = "" when there's
'----- nothing to say. A click on any hit point resets; 3 looks at the same empty
'----- cell picks a random, non-repeating "nothing to see" line
SUB LookMissLine (bx%, ay%, ox%(), oy%(), nf$(), out$) STATIC
	out$ = ""
	FOR i% = 1 TO 257
		IF oy%(i%) = 0 THEN EXIT FOR
		IF ox%(i%) = bx% AND oy%(i%) = ay% THEN lc% = 0: EXIT SUB
	NEXT
	IF bx% = lx% AND ay% = ly% THEN
		lc% = lc% + 1
	ELSE
		lc% = 1: lx% = bx%: ly% = ay%
	END IF
	IF lc% < 3 THEN EXIT SUB
	IF lsd% = 0 THEN RANDOMIZE TIMER: lsd% = 1
	DO
		p% = INT(RND * 25) + 1
	LOOP WHILE p% = h1% OR p% = h2% OR p% = h3%
	h3% = h2%: h2% = h1%: h1% = p%
	out$ = nf$(p%)
END SUB

'----- derive cache slot acs's frame count. k frames interleave word0 x k then
'----- height x k -- but when width*2 = height the leading-equal count OVERSHOOTS
'----- (a 3x6 frame reads 6,6,6,6...). Validate candidates downward: the k whose
'----- frame geometry exactly tiles the file wins; fall back to the raw count.
SUB AnimK (acPct%(), acN%(), acs, kk%)
	kk% = 1
	anf% = acN%(acs)
	IF anf% < 2 THEN EXIT SUB
	ld% = 0
	DO WHILE ld% < anf%
		IF acPct%(acs, ld% + 1) <> acPct%(acs, 1) THEN EXIT DO
		ld% = ld% + 1
	LOOP
	IF ld% < 1 THEN ld% = 1
	w0& = acPct%(acs, 1)
	IF w0& < 0 THEN w0& = w0& + 65536
	FOR k% = ld% TO 1 STEP -1
		IF (anf% MOD k%) = 0 THEN
			h& = acPct%(acs, k% + 1)
			IF h& < 0 THEN h& = h& + 65536
			IF h& >= 1 AND h& <= 140 AND w0& >= 2 AND w0& <= 280 THEN
				per& = 2 + INT((INT((w0& + 7) / 8) * h& + 1) / 2)
				IF per& * k% = anf% THEN kk% = k%: EXIT SUB
			END IF
		END IF
	NEXT
	kk% = ld%
END SUB

'----- measure cache slot acs's frame size in pixels (moved from GAME.BAS): frame
'----- count via AnimK; capped so the region fits a 150-int save-under slot
SUB AnimDims (acPct%(), acN%(), acs, adw, adh)
	adw = 31: adh = 31
	IF acN%(acs) < 2 THEN EXIT SUB
	CALL AnimK(acPct%(), acN%(), acs, kk%)
	w% = acPct%(acs, 1) \ 2
	h% = acPct%(acs, kk% + 1)
	IF w% < 1 OR h% < 1 THEN EXIT SUB
	'----- any shape is fine as long as the region fits a 210-int save-under slot
	IF ((w% * 2 + 7) \ 8) * h% > 416 THEN EXIT SUB
	adw = w%: adh = h%
END SUB

'----- parse a move-anim script into 1px step arrays (max 60 steps).
'----- Tokens split on ";": letters u/d/l/r combine into a direction (ul = up-left),
'----- a trailing number repeats it ("ul5"); "p" (no direction letters) = a pause
'----- step in place ("p6" holds 6 steps). Example: "u;d;u;d;u;d;p6;ul5;dr2"
SUB MovParse (s$, mdx%(), mdy%(), mn%, bx1%, by1%, bx2%, by2%)
	mn% = 0
	t$ = LCASE$(s$) + ";"
	sp% = 1
	FOR i% = 1 TO LEN(t$)
		IF MID$(t$, i%, 1) = ";" THEN
			w$ = MID$(t$, sp%, i% - sp%)
			sp% = i% + 1
			IF w$ <> "" THEN
				dx% = 0: dy% = 0: rp% = 0
				FOR j% = 1 TO LEN(w$)
					c$ = MID$(w$, j%, 1)
					IF c$ = "u" THEN dy% = dy% - 1
					IF c$ = "d" THEN dy% = dy% + 1
					IF c$ = "l" THEN dx% = dx% - 1
					IF c$ = "r" THEN dx% = dx% + 1
					IF c$ >= "0" AND c$ <= "9" THEN rp% = rp% * 10 + VAL(c$)
				NEXT
				IF rp% < 1 THEN rp% = 1
				FOR j% = 1 TO rp%
					IF mn% < 60 THEN mn% = mn% + 1: mdx%(mn%) = dx%: mdy%(mn%) = dy%
				NEXT
			END IF
		END IF
	NEXT
	'----- path bounds (cumulative offsets) for player-overlap tests during the travel
	bx1% = 0: by1% = 0: bx2% = 0: by2% = 0
	cx% = 0: cy% = 0
	FOR i% = 1 TO mn%
		cx% = cx% + mdx%(i%): cy% = cy% + mdy%(i%)
		IF cx% < bx1% THEN bx1% = cx%
		IF cx% > bx2% THEN bx2% = cx%
		IF cy% < by1% THEN by1% = cy%
		IF cy% > by2% THEN by2% = cy%
	NEXT
END SUB

'----- fill the lookmiss "nothing to see" lines (25); lives here because GAME.BAS
'----- is at its 64K code-segment ceiling
SUB LoadMsgs (nf$())
	nf$(1) = "There is nothing to see here."
	nf$(2) = "Nothing catches your eye."
	nf$(3) = "You see nothing unusual."
	nf$(4) = "Nothing worth a closer look."
	nf$(5) = "You find nothing of interest."
	nf$(6) = "Nothing remarkable here."
	nf$(7) = "You look closer, but find nothing."
	nf$(8) = "There's nothing special about it."
	nf$(9) = "You see only the ordinary."
	nf$(10) = "Nothing stands out to you."
	nf$(11) = "There's nothing here to examine."
	nf$(12) = "It holds no secrets for you."
	nf$(13) = "Nothing draws your attention."
	nf$(14) = "You don't see anything useful."
	nf$(15) = "Nothing of note here."
	nf$(16) = "Whatever you sought, it isn't here."
	nf$(17) = "Nothing worth mentioning."
	nf$(18) = "There's nothing here for you."
	nf$(19) = "Just as it looks - nothing more."
	nf$(20) = "Your eyes find nothing of value."
	nf$(21) = "Nothing but dust and shadow."
	nf$(22) = "There's nothing here to help you."
	nf$(23) = "You peer closer. Still nothing."
	nf$(24) = "Nothing reveals itself to you."
	nf$(25) = "The shadows hide nothing here."
END SUB

'----- pick a random, non-repeating reply for a use that did nothing. sel = the item
'----- being used; wantbs = an item some hit use point wanted instead (0 = none).
'----- Specials: a key on a lock wanting a DIFFERENT key -> key lines; the paper
'----- clip (27) on a keyed lock -> too-tough-to-pick lines; the bar (6) where the
'----- poker's (2) reach is needed -> too-short lines. Keys: 5, 8, 13, 22.
SUB UseMissLine (sel, wantbs, out$) STATIC
	DIM us$(12), km$(6), pc$(2), rc$(2)
	IF umini = 0 THEN
		umini = 1
		us$(1) = "That doesn't work."
		us$(2) = "You can't use that there."
		us$(3) = "Nothing happens."
		us$(4) = "That's not going to work."
		us$(5) = "You try, but it does nothing."
		us$(6) = "That has no effect."
		us$(7) = "It doesn't seem to fit."
		us$(8) = "You can't find a way to use it here."
		us$(9) = "That won't help here."
		us$(10) = "Try as you might, nothing happens."
		us$(11) = "That accomplishes nothing."
		us$(12) = "No matter how you try, it won't work."
		km$(1) = "The key doesn't fit the lock."
		km$(2) = "The key goes in but refuses to turn."
		km$(3) = "It's the wrong key for this lock."
		km$(4) = "The key rattles but will not turn."
		km$(5) = "That's not the key for this lock."
		km$(6) = "No use - this key will never turn it."
		pc$(1) = "The lock is too tough to pick. You'll   need the key."
		pc$(2) = "Too sturdy to pick - this one needs its key."
		rc$(1) = "You need something a little longer to   reach it."
		rc$(2) = "You can't quite reach it with that."
		RANDOMIZE TIMER
	END IF
	kk = 0
	IF wantbs > 0 AND wantbs <> sel THEN
		wk = 0
		IF wantbs = 5 OR wantbs = 8 OR wantbs = 13 OR wantbs = 22 THEN wk = 1
		IF wk = 1 THEN
			IF sel = 5 OR sel = 8 OR sel = 13 OR sel = 22 THEN kk = 1
			IF sel = 27 THEN kk = 2
		END IF
		IF sel = 6 AND wantbs = 2 THEN kk = 3
	END IF
	IF kk = 2 THEN
		pch = (pch MOD 2) + 1
		out$ = pc$(pch)
	ELSEIF kk = 3 THEN
		rch = (rch MOD 2) + 1
		out$ = rc$(rch)
	ELSEIF kk = 1 THEN
		DO
			ump = INT(RND * 6) + 1
		LOOP WHILE ump = kh1 OR ump = kh2
		kh2 = kh1
		kh1 = ump
		out$ = km$(ump)
	ELSE
		DO
			ump = INT(RND * 12) + 1
		LOOP WHILE ump = uh1 OR ump = uh2 OR ump = uh3
		uh3 = uh2
		uh2 = uh1
		uh1 = ump
		out$ = us$(ump)
	END IF
END SUB

'----- create/read dark.ini settings (showfps, joystick)
SUB LoadConfig
	CLOSE
	OPEN "dark.ini" FOR APPEND AS #1
	IF LOF(1) = 0 THEN
		PRINT #1, "; Dark Visions settings"
		PRINT #1, "; showfps=1 shows main loop speed top right + intro pace"
		PRINT #1, "showfps=0"
		PRINT #1, "; joystick=1 enables joystick/gamepad control (off avoids stray input)"
		PRINT #1, "joystick=0"
		PRINT #1, "; mouse=1 enables mouse cursor + hardware pointer (needs a mouse driver)"
		PRINT #1, "mouse=0"
		PRINT #1, "; mousecursor: 0 driver default, 1 arrow, 2 crosshair, 3 box, 4 crosshair(xor)"
		PRINT #1, "mousecursor=1"
		PRINT #1, "; mousesnap: click pulls to nearest hotspot within N pixels (0=off/exact)"
		PRINT #1, "mousesnap=6"
		PRINT #1, "; exitcursor=1 changes the pointer to a direction arrow near room exits"
		PRINT #1, "exitcursor=1"
		PRINT #1, "; mousexy=1 shows live mouse x,y + snapped hit point bottom row (debug; needs mouse=1)"
		PRINT #1, "mousexy=0"
		PRINT #1, "; lookmiss=1 shows a random 'nothing to see' line after looking 3x at an empty"
		PRINT #1, "; spot, and a random 'that doesn't work' line when a use action does nothing"
		PRINT #1, "lookmiss=1"
		PRINT #1, "; killers=0 turns off the roaming killers (for testing; scripted deaths still happen)"
		PRINT #1, "killers=1"
		PRINT #1, "; walkto=1 walks the player over to an item before get/use actions fire (0=instant, as the original)"
		PRINT #1, "walkto=1"
		PRINT #1, "; intro=1 plays the opening cutscene (set 0 to skip it)"
		PRINT #1, "intro=1"
		PRINT #1, "; quickstart=1 jumps straight into the game - no intro, title or instructions prompt (testing)"
		PRINT #1, "quickstart=0"
		PRINT #1, "; revive=1 auto-saves when a timed-death room arms and, after dying there,"
		PRINT #1, "; restores that save with a message instead of the Load screen"
		PRINT #1, "revive=0"
			PRINT #1, "; hit-zone debug overlay (needs mouse=1): ring hotspot click-zones, 1=show 0=hide (look=blue action=brown get/use=gray)"
			PRINT #1, "hitzone_look=0"
			PRINT #1, "hitzone_get=0"
			PRINT #1, "hitzone_use=0"
			PRINT #1, "hitzone_action=0"
	END IF
	CLOSE

	snr = 6
	exsen = 1
	nfon = 1
	inon = 1
	klon = 1
	wksen = 1
	qkon = 0
	rvon = 0
	hzon$ = ""
	OPEN "dark.ini" FOR INPUT AS #1
	DO WHILE NOT EOF(1)
		LINE INPUT #1, ln$
		ln$ = LTRIM$(RTRIM$(ln$))
		c$ = LEFT$(ln$, 1)
		IF ln$ <> "" AND c$ <> ";" AND c$ <> "#" AND c$ <> "'" AND c$ <> "[" THEN
			eq = INSTR(ln$, "=")
			IF eq >= 2 THEN
				k$ = LCASE$(LTRIM$(RTRIM$(LEFT$(ln$, eq - 1))))
				v$ = LCASE$(LTRIM$(RTRIM$(MID$(ln$, eq + 1))))
				tv = 0
				IF v$ = "1" OR v$ = "true" OR v$ = "yes" OR v$ = "on" THEN tv = 1
				IF k$ = "showfps" THEN sfps = tv
				IF k$ = "joystick" THEN jsen = tv
				IF k$ = "mouse" THEN msen = tv
				IF k$ = "mousecursor" THEN mcur = VAL(v$)
				IF k$ = "mousesnap" THEN snr = VAL(v$)
				IF k$ = "exitcursor" THEN exsen = tv
				IF k$ = "mousexy" THEN mxyon = tv
				IF k$ = "lookmiss" THEN nfon = tv
				IF k$ = "killers" THEN klon = tv
				IF k$ = "walkto" THEN wksen = tv
				IF k$ = "intro" THEN inon = tv
				IF k$ = "quickstart" THEN qkon = tv
				IF k$ = "revive" THEN rvon = tv
				IF k$ = "hitzone_look" AND tv = 1 THEN hzon$ = hzon$ + "l"
				IF k$ = "hitzone_get" AND tv = 1 THEN hzon$ = hzon$ + "g"
				IF k$ = "hitzone_use" AND tv = 1 THEN hzon$ = hzon$ + "u"
				IF k$ = "hitzone_action" AND tv = 1 THEN hzon$ = hzon$ + "a"
			END IF
		END IF
	LOOP
	CLOSE

	fpst = TIMER
	fpsc = 0
	mvint = &H33
END SUB

'----- OvReg: register a foreground overlay ("fg" anim mode) -- copy the frame
'----- animframe just decoded (afrm/amfrm, anpf ints) into ovf() after the meta
'----- header, so GAME5 OvTop can re-stamp it over the player (body here, not in
'----- GAME.BAS -- 64K code ceiling). ovh=1 when a mask exists; ovnext = next
'----- free element (by ref).
SUB OvReg (ovf%(), afrm%(), amfrm%(), anpf!, ovh!, ovnext!, PX!, PY!)
	IF ovf%(0) >= 4 THEN EXIT SUB
	IF ovnext! + anpf! * 2 > 1500 THEN EXIT SUB
	ovf%(0) = ovf%(0) + 1
	ovb% = 1 + (ovf%(0) - 1) * 4
	ovf%(ovb%) = PX!: ovf%(ovb% + 1) = PY!
	ovf%(ovb% + 2) = ovnext!
	ovf%(ovb% + 3) = 0
	FOR aj% = 0 TO anpf! - 1: ovf%(ovnext! + aj%) = afrm%(aj%): NEXT
	ovnext! = ovnext! + anpf!
	IF ovh! = 1 THEN
		ovf%(ovb% + 3) = ovnext!
		FOR aj% = 0 TO anpf! - 1: ovf%(ovnext! + aj%) = amfrm%(aj%): NEXT
		ovnext! = ovnext! + anpf!
	END IF
END SUB
'----- LookDir: 8-way facing digit from the player's eyes (px+15, py+5) toward
'----- the click (bx, ay), with x/y dead zones; both in the zone -> face down.
'----- (moved from GAME.BAS lookdir -- 64K code ceiling)
SUB LookDir (bx!, ay!, px2!, py2!, d2$)
	ldx! = bx! - (px2! + 15)
	ldy! = ay! - (py2! + 5)
	lxs% = 0
	IF ldx! < -10 THEN lxs% = -1
	IF ldx! > 10 THEN lxs% = 1
	lys% = 0
	IF ldy! < -8 THEN lys% = -1
	IF ldy! > 8 THEN lys% = 1
	d2$ = "2"
	IF lxs% = -1 AND lys% = -1 THEN d2$ = "7"
	IF lxs% = 0 AND lys% = -1 THEN d2$ = "8"
	IF lxs% = 1 AND lys% = -1 THEN d2$ = "9"
	IF lxs% = -1 AND lys% = 0 THEN d2$ = "4"
	IF lxs% = 1 AND lys% = 0 THEN d2$ = "6"
	IF lxs% = -1 AND lys% = 1 THEN d2$ = "1"
	IF lxs% = 1 AND lys% = 1 THEN d2$ = "3"
END SUB
'----- KillChk: which roaming killer owns room q2 + $ at step count w --
'----- bit 1 = wilb window, bit 2 = golf window (moved verbatim from
'----- GAME.BAS events: -- that module is at the 64K code ceiling).
SUB KillChk (q2$, w!, h9b!, t1b!, t2b!, t3b!, f3b!, kw%)
	kw% = 0
	IF q2$ = "room7" AND w! > 0 AND w! < 8 THEN kw% = kw% OR 1
	IF q2$ = "room6" AND w! > 8 AND w! < 20 THEN kw% = kw% OR 1
	IF q2$ = "room8" AND w! > 20 AND w! < 35 THEN kw% = kw% OR 1
	IF q2$ = "room9" AND w! > 35 AND w! < 47 THEN kw% = kw% OR 1
	IF q2$ = "room7" AND w! > 47 AND w! < h9b! THEN kw% = kw% OR 1
	IF q2$ = "room11" AND w! > h9b! AND w! < t1b! THEN kw% = kw% OR 1
	IF q2$ = "room4" AND w! > t1b! AND w! < t2b! THEN kw% = kw% OR 1
	IF q2$ = "room10" AND w! > t2b! AND w! < t3b! THEN kw% = kw% OR 1
	IF q2$ = "room11" AND w! > t3b! AND w! < f3b! THEN kw% = kw% OR 1
	IF q2$ = "room2" AND w! > 0 AND w! < 8 THEN kw% = kw% OR 2
	IF q2$ = "room1" AND w! > 8 AND w! < 20 THEN kw% = kw% OR 2
	IF q2$ = "room5" AND w! > 20 AND w! < 35 THEN kw% = kw% OR 2
	IF q2$ = "room5" AND w! > 35 AND w! < 47 THEN kw% = kw% OR 2
	IF q2$ = "room4" AND w! > 47 AND w! < h9b! THEN kw% = kw% OR 2
	IF q2$ = "room1" AND w! > h9b! AND w! < t1b! THEN kw% = kw% OR 2
	IF q2$ = "room9" AND w! > t1b! AND w! < t2b! THEN kw% = kw% OR 2
	IF q2$ = "room1" AND w! > t2b! AND w! < t3b! THEN kw% = kw% OR 2
	IF q2$ = "room4" AND w! > t3b! AND w! < f3b! THEN kw% = kw% OR 2
END SUB

'----- CursorPats: build the 5 software-cursor pixel grids (0=NW pointer,
'----- 1=up 2=down 3=right 4=left exit arrows) into px/py/pc/npix.
'----- Moved VERBATIM from GAME.BAS setgrid/grdnw..grdlf (64K ceiling).
'----- X = outline pixel (pc 1), 0 = fill pixel (pc 2), . = clear
SUB CursorPats (px!(), py!(), pc!(), npix!())
	DIM ar$(15)
	FOR s% = 0 TO 4
		FOR mr% = 0 TO 15
			ar$(mr%) = "................"
		NEXT
		SELECT CASE s%
		CASE 0
			ar$(0) = "X..............."
			ar$(1) = "XX.............."
			ar$(2) = "X0X............."
			ar$(3) = "X00X............"
			ar$(4) = "X000X..........."
			ar$(5) = "X0XX............"
			ar$(6) = "XX.............."
		CASE 1
			ar$(0) = "...X............"
			ar$(1) = "..X0X..........."
			ar$(2) = "..X0X..........."
			ar$(3) = ".X000X.........."
			ar$(4) = "X00000X........."
			ar$(5) = "..X0X..........."
			ar$(6) = "..X0X..........."
			ar$(7) = "..X0X..........."
		CASE 2
			ar$(0) = "..X0X..........."
			ar$(1) = "..X0X..........."
			ar$(2) = "..X0X..........."
			ar$(3) = "X00000X........."
			ar$(4) = ".X000X.........."
			ar$(5) = "..X0X..........."
			ar$(6) = "..X0X..........."
			ar$(7) = "...X............"
		CASE 3
			ar$(0) = "...X............"
			ar$(1) = "...0X..........."
			ar$(2) = "XXX00XX........."
			ar$(3) = "0000000X........"
			ar$(4) = "XXX00XX........."
			ar$(5) = "...0X..........."
			ar$(6) = "...X............"
		CASE 4
			ar$(0) = "....X..........."
			ar$(1) = "...X0..........."
			ar$(2) = ".XX00XXX........"
			ar$(3) = "X0000000........"
			ar$(4) = ".XX00XXX........"
			ar$(5) = "...X0..........."
			ar$(6) = "....X..........."
		END SELECT
		npc% = 0
		FOR mr% = 0 TO 15
			FOR mc% = 0 TO 15
				mch$ = MID$(ar$(mr%), mc% + 1, 1)
				IF mch$ = "X" THEN px(s%, npc%) = mc%: py(s%, npc%) = mr%: pc(s%, npc%) = 1: npc% = npc% + 1
				IF mch$ = "0" THEN px(s%, npc%) = mc%: py(s%, npc%) = mr%: pc(s%, npc%) = 2: npc% = npc% + 1
			NEXT
		NEXT
		npix(s%) = npc%
	NEXT
END SUB
