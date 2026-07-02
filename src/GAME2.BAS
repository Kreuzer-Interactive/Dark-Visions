'----- GAME2.BAS: secondary module for the multi-module split (sound effects)
'----- gets its own 64K code segment; shares scalars with GAME.BAS via COMMON SHARED.
'----- The COMMON SHARED line below MUST match GAME.BAS exactly (same names + order).
COMMON SHARED f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, sa, sb, sc, mt, sfps, fpsc, fpst, jsen, inon, msen, snr, exsen, mxyon, nfon, hzon$
COMMON SHARED mcur AS INTEGER, mvint AS INTEGER

'----- DeathMusic: play one of four random dirges
SUB DeathMusic
	RANDOMIZE TIMER
	mt = INT(RND * 4)
	IF mt <> 1 THEN GOTO 15370
	GOTO 15440
	GOTO 15440
15370 IF mt <> 2 THEN GOTO 15400
	GOTO 15460
	GOTO 15440
15400 IF mt <> 3 THEN GOTO 15430
	GOTO 15490
	GOTO 15440
15430 GOTO 15510

15440 PLAY "<<<g-2g8a+8f+8e8d-3e4f+5f+5e-5e3>d2>>"
	EXIT SUB

15460 PLAY "<<<d+8e-8<a8g8f3b8g8f+8e3"
	PLAY "  g-2g8a8f+8e8d-3e4f+5c8c8c3>>>"
	EXIT SUB

15490 PLAY "<<<c3c3d-5d-5c3c3<b-5a-5>c3c3d-5e-5c3c3>>>"
	EXIT SUB

15510 PLAY "<g8a8b-8b8<c8g8a8b-8a8a8b8a8>>"
	EXIT SUB
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
		PRINT #1, "; lookmiss=1 shows a random 'nothing to see' line after looking 3x at an empty spot"
		PRINT #1, "lookmiss=1"
		PRINT #1, "; intro=1 plays the opening cutscene (set 0 to skip it)"
		PRINT #1, "intro=1"
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
				IF k$ = "intro" THEN inon = tv
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
