'----- GAME4.BAS: menu / save / load UI module. Own 64K code segment.
'----- Pure library module (no COMMON SHARED). Holds the ESC main menu
'----- (MainMenu), the dedicated Save and Load book screens (SlotScreen,
'----- SAVEBG/LOADBG.PIC), the themed yes/no dialog (DrawYNBox/YNBtn/YNWait)
'----- and the per-slot stat painter (slDrawStat). Real file I/O is delegated
'----- to SaveGame/LoadGame (GAME.BAS).

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
DECLARE SUB drawText (x AS INTEGER, y AS INTEGER, text AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
DECLARE FUNCTION textWidth (text AS STRING, fontData() AS INTEGER)
DECLARE SUB DrawYNBox (msg AS STRING, dk AS INTEGER, fontData() AS INTEGER)
DECLARE SUB DlgLoad ()
DECLARE SUB YNBtn (sel AS INTEGER, dk AS INTEGER)
DECLARE SUB YNWait (mvint AS INTEGER, msen AS SINGLE, dk AS INTEGER, res AS INTEGER)
DECLARE SUB SaveGame (slot AS INTEGER)
DECLARE SUB LoadGame (slot AS INTEGER)
DECLARE SUB ReviveShow (mvint AS INTEGER, msen AS SINGLE)
DECLARE SUB SlotScreen (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, mode AS INTEGER, dead AS INTEGER, act AS INTEGER)
DECLARE FUNCTION slLoc$ (rq AS STRING)

'----- per-slot occupancy (1 = has a save); set by slDrawStat, read for overwrite/load confirms
DIM SHARED slUsed(10) AS INTEGER
'----- last slot saved/loaded; persists across SlotScreen opens (reset by RUN/New Game)
DIM SHARED slLast AS INTEGER
'----- ESC main-menu art, parsed from disk ONCE per session (mnOk flag):
'----- mnArt = MENUMAIN.PCT (122x99 box, inventory palette), mnLbl = MENULBL.PCT
'----- (6 frames of 70 ints, 59x9 label cells: 1-4 = New Game/Save/Load/Quit
'----- not-selected, 5 = Save disabled, 6 = Load disabled). Dynamic = far heap.
'----- Placeholder size: module-level code never RUNS in a non-main module, so
'----- the real REDIM to full size happens inside MainMenu on first open.
REDIM SHARED mnArt(1) AS INTEGER
REDIM SHARED mnLbl(1) AS INTEGER
DIM SHARED mnOk AS INTEGER
'----- themed yes/no dialog parts, parsed once by DlgLoad (dlgOk flag). ONE art
'----- set: every dialog screen (ESC menu, save/load book, inventory quit) uses
'----- the same palette layout (1=dkgray 2=ltgray 3=brown).
'----- dlgCor = DLGCOR.PCT, 4x 9x9 corner scrolls (BL,BR,TL,TR);
'----- dlgBtn = DLGBTN.PCT, 4x 16x10 buttons (yes-act, yes-inact, no-act, no-inact);
'----- dlgStr = DLGSTRK.PCT, 1x 91x3 ornament stroke
REDIM SHARED dlgCor(1) AS INTEGER
REDIM SHARED dlgBtn(1) AS INTEGER
REDIM SHARED dlgStr(1) AS INTEGER
DIM SHARED dlgOk AS INTEGER
'----- orange slot selection ring (src/ART/SLRing.png via RING2.DAT): packed
'----- attr*10000 + dy*100 + dx pixels, 100x20 -- fits BOTH pages' 82px slot
'----- boxes (rect at dx13-96, ornament hanging left); placeholder REDIM
REDIM SHARED rgL(1) AS INTEGER
DIM SHARED rgNL AS INTEGER, rgOk AS INTEGER
'----- revive message sprite (src/Revive.png -> REVIVE.DAT: count n, then n
'----- sprite ints and n mask ints; ints 0/1 = width*2 and height). Drawn the
'----- game's masked way: PUT mask AND, PUT sprite OR. Placeholder REDIMs.
REDIM SHARED rvArt(1) AS INTEGER
REDIM SHARED rvMsk(1) AS INTEGER
DIM SHARED rvOk AS INTEGER

'----- map a saved room tag (q$) to a short location name shown on the slot
FUNCTION slLoc$ (rq AS STRING)
	DIM hd$, nm$, q1 AS INTEGER, q2 AS INTEGER
	IF rq = "" THEN
		slLoc$ = "?"
	ELSEIF LEFT$(rq, 4) = "room" THEN
		nm$ = ""
		OPEN rq + ".pac" FOR INPUT AS #4
		LINE INPUT #4, hd$
		CLOSE #4
		q1 = INSTR(hd$, CHR$(34))
		IF q1 > 0 THEN
			q2 = INSTR(q1 + 1, hd$, CHR$(34))
			IF q2 > q1 + 1 THEN nm$ = MID$(hd$, q1 + 1, q2 - q1 - 1)
		END IF
		IF nm$ <> "" THEN slLoc$ = nm$ ELSE slLoc$ = "Room " + MID$(rq, 5)
	ELSE
		slLoc$ = rq
	END IF
END FUNCTION

'----- draw one slot's stats: Location + Progress%, or "- empty -" for an unused slot.
'----- Also records slUsed(slot). Progress mirrors GAME3 drawStats.
SUB slDrawStat (slot AS INTEGER, sx AS INTEGER, sy AS INTEGER, fontData() AS INTEGER)
	DIM f$, sq$, sdn$, stt$, sa$, slf$
	DIM scl AS SINGLE, spt AS SINGLE, sob AS INTEGER, j AS INTEGER, pc AS INTEGER
	'----- wipe the stat area (covers a previous "- empty -" on refresh)
	LINE (sx - 1, sy - 1)-(sx + 56, sy + 12), 0, BF
	f$ = "saver" + CHR$(slot + 96) + ".pac"
	OPEN f$ FOR APPEND AS #2: CLOSE #2          ' ensure the file exists (no truncate)
	OPEN f$ FOR INPUT AS #2
	IF EOF(2) THEN
		slUsed(slot) = 0
		CALL drawText(sx - 1, sy + 3, "- empty -", 2, fontData())
		CLOSE #2: EXIT SUB
	END IF
	slUsed(slot) = 1
	INPUT #2, sq$, scl, spt, sdn$, stt$, sa$, slf$
	pc = 0
	FOR j = 1 TO 65
		sob = 0: IF NOT EOF(2) THEN INPUT #2, sob
		IF j <= 51 AND sob >= 1 THEN pc = pc + 1
		IF j = 35 AND sob >= 1 THEN pc = pc + 2
		IF j = 36 AND sob >= 1 THEN pc = pc + 2
	NEXT j
	CLOSE #2
	pc = CINT(pc * 100 / 47)
	CALL drawText(sx - 1, sy - 1, slLoc$(sq$), 2, fontData())
	CALL drawText(sx - 1, sy + 6, LTRIM$(STR$(pc)) + "% done", 2, fontData())
END SUB

'----- SlotScreen: dedicated Save (mode 1) or Load (mode 2) screen on the book
'----- background (SAVEBG/LOADBG.PIC; palette 1=dkgray 2=ltgray 3=brown).
'----- 10 slots: 1-5 on the left page (x60-159), 6-0 on the right (x170-263),
'----- rows y = 37 + 22*row, 20 tall. Arrows / number keys / click select a
'----- slot; Enter, Space, a DOUBLE-click, the action button or its S/L key
'----- fires it (save = overwrite confirm when the slot is used, load =
'----- lost-progress confirm unless dead).
'----- Buttons under the book: Back (X or Esc) at 109-151, the screen's action
'----- button (Save S / Load L) at 168-210, both y178-194. Switching screens =
'----- Back to the menu and pick the other.
'----- act out: 1 = a game was LOADED, 0 = Back (caller decides what's behind).
SUB SlotScreen (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, mode AS INTEGER, dead AS INTEGER, act AS INTEGER)
	DIM mr AS RegType, mo AS RegType
	DIM cbuf(40) AS INTEGER
	DIM sel AS INTEGER, i AS INTEGER, done AS INTEGER, mlb AS INTEGER, cdrn AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, nmx AS INTEGER, nmy AS INTEGER
	DIM ns AS INTEGER, k$, cyn AS INTEGER
	DIM sgi AS INTEGER, sgx1 AS INTEGER, sgy1 AS INTEGER, sgx2 AS INTEGER, sgy2 AS INTEGER, sgtx AS INTEGER
	DIM dcs AS INTEGER, dct AS SINGLE, rp AS INTEGER, rgo AS INTEGER
	REDIM srb(300) AS INTEGER

	'----- parse the selection-ring pixel list once per session
	IF rgOk <> 1 THEN
		REDIM rgL(400) AS INTEGER
		OPEN "RING2.DAT" FOR INPUT AS #2
		INPUT #2, rgNL
		FOR i = 1 TO rgNL: INPUT #2, rgL(i): NEXT
		CLOSE #2
		rgOk = 1
	END IF

	'----- mlb starts PRESSED so the click/keypress that opened this screen
	'----- doesn't re-register here
	act = 0: done = 0: mlb = 1: cdrn = 0: dcs = 0: dct = 0
	sel = 1: IF slLast >= 1 AND slLast <= 10 THEN sel = slLast
	SCREEN 1
	GOSUB ssall
	IF msen = 1 THEN
		mr.ax = 2: CALL INTERRUPT(mvint, mr, mo)
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		mx = mo.cx \ 2: my = mo.dx
		IF mx > 312 THEN mx = 312 ELSE IF mx < 0 THEN mx = 0
		IF my > 192 THEN my = 192 ELSE IF my < 0 THEN my = 0
		GOSUB ssdrawcur
	END IF

	sswait:
	k$ = INKEY$
	IF k$ <> "" THEN GOSUB sskey
	IF done = 0 AND msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN GOSUB sserase: mx = nmx: my = nmy: GOSUB ssdrawcur
		IF (mo.bx AND 1) <> 0 AND mlb = 0 THEN GOSUB ssclick
		mlb = (mo.bx AND 1)
	END IF
	IF done = 0 THEN GOTO sswait
	IF msen = 1 THEN GOSUB sserase
	EXIT SUB

	'----- full redraw: background by mode, palette, slot stats, selection ring
	ssall:
	IF mode = 1 THEN
		DEF SEG = &HB800: BLOAD "SAVEBG.PIC", 0: DEF SEG
	ELSE
		DEF SEG = &HB800: BLOAD "LOADBG.PIC", 0: DEF SEG
	END IF
	PALETTE 1, 8: PALETTE 2, 7: PALETTE 3, 6
	FOR i = 1 TO 10
		sgi = i: GOSUB ssgeo
		CALL slDrawStat(i, sgtx, sgy1 + 4, fontData())
	NEXT
	GOSUB ssring
	RETURN

	'----- slot geometry: sgi in -> box rect + stat text x (text anchored so the
	'----- wipe rect stays inside each pill's black interior: left 88-146, right 190-248)
	ssgeo:
	IF sgi <= 5 THEN sgx1 = 60: sgx2 = 159: sgtx = 90 ELSE sgx1 = 170: sgx2 = 263: sgtx = 192
	sgy1 = 37 + ((sgi - 1) MOD 5) * 22
	sgy2 = sgy1 + 19
	RETURN

	'----- selection ring: the classic orange ring sprite, PSET over the slot
	'----- after a save-under GET (erase = PUT it back). One ring fits both
	'----- pages (equal 82px slot boxes); the draw origin puts its rectangle
	'----- flush around the box with the diamond ornament hanging left of it.
	'----- Left page box starts at x68 -> origin 54; right box at x170 -> 156.
	ssring:
	sgi = sel: GOSUB ssgeo
	rgo = 6: IF sel > 5 THEN rgo = 14
	GET (sgx1 - rgo, sgy1)-(sgx1 - rgo + 99, sgy2), srb
	FOR i = 1 TO rgNL
		rp = rgL(i)
		PSET (sgx1 - rgo + rp MOD 100, sgy1 + (rp \ 100) MOD 100), rp \ 10000
	NEXT
	RETURN
	ssunring:
	sgi = sel: GOSUB ssgeo
	rgo = 6: IF sel > 5 THEN rgo = 14
	PUT (sgx1 - rgo, sgy1), srb, PSET
	RETURN

	'----- move the selection to ns (1-10)
	ssmove:
	IF ns < 1 OR ns > 10 OR ns = sel THEN RETURN
	IF msen = 1 THEN GOSUB sserase
	GOSUB ssunring
	sel = ns
	GOSUB ssring
	IF msen = 1 THEN GOSUB ssdrawcur
	RETURN

	'----- keys: Esc/X back, Enter/Space/S(save)/L(load) fire, digits jump,
	'----- arrows move (up/down within the page, left/right across pages)
	sskey:
	IF k$ = CHR$(27) OR k$ = "x" OR k$ = "X" THEN act = 0: done = 1: RETURN
	IF k$ = CHR$(13) OR k$ = " " THEN GOSUB ssfire: RETURN
	IF mode = 1 AND (k$ = "s" OR k$ = "S") THEN GOSUB ssfire: RETURN
	IF mode = 2 AND (k$ = "l" OR k$ = "L") THEN GOSUB ssfire: RETURN
	ns = 0
	IF k$ >= "1" AND k$ <= "9" THEN ns = ASC(k$) - 48
	IF k$ = "0" THEN ns = 10
	IF k$ = CHR$(0) + CHR$(72) THEN ns = sel - 1: IF ns < 1 THEN ns = 1
	IF k$ = CHR$(0) + CHR$(80) THEN ns = sel + 1: IF ns > 10 THEN ns = 10
	IF k$ = CHR$(0) + CHR$(75) THEN IF sel > 5 THEN ns = sel - 5
	IF k$ = CHR$(0) + CHR$(77) THEN IF sel <= 5 THEN ns = sel + 5
	IF ns > 0 THEN GOSUB ssmove
	RETURN

	'----- click: the buttons under the book, or a slot (select; double-click fires)
	ssclick:
	IF my >= 178 AND my <= 194 THEN
		IF mx >= 109 AND mx <= 151 THEN act = 0: done = 1
		IF mx >= 168 AND mx <= 210 THEN GOSUB ssfire
		RETURN
	END IF
	FOR i = 1 TO 10
		sgi = i: GOSUB ssgeo
		IF mx >= sgx1 AND mx <= sgx2 AND my >= sgy1 AND my <= sgy2 THEN
			IF i = sel AND dcs = i AND TIMER - dct >= 0 AND TIMER - dct < .45 THEN
				dcs = 0
				GOSUB ssfire
			ELSE
				ns = i: GOSUB ssmove
				dcs = i: dct = TIMER
			END IF
			i = 10
		END IF
	NEXT
	RETURN

	'----- fire the selected slot: save to it / load from it (with confirms)
	ssfire:
	IF mode = 1 THEN
		cyn = 1
		IF slUsed(sel) = 1 THEN
			IF msen = 1 THEN GOSUB sserase
			CALL DrawYNBox("Overwrite this slot?", 1, fontData())
			CALL YNWait(mvint, msen, 1, cyn)
		END IF
		IF cyn = 1 THEN CALL SaveGame(sel): slLast = sel
		IF msen = 1 THEN GOSUB sserase
		GOSUB ssall
		IF msen = 1 THEN GOSUB ssdrawcur
		mlb = 1
	ELSE
		IF slUsed(sel) = 0 THEN RETURN
		cyn = 1
		IF dead = 0 THEN
			IF msen = 1 THEN GOSUB sserase
			CALL DrawYNBox("Load? unsaved game lost.", 1, fontData())
			CALL YNWait(mvint, msen, 1, cyn)
		END IF
		IF cyn = 1 THEN
			CALL LoadGame(sel)
			slLast = sel
			act = 1: done = 1
		ELSE
			IF msen = 1 THEN GOSUB sserase
			GOSUB ssall
			IF msen = 1 THEN GOSUB ssdrawcur
			mlb = 1
		END IF
	END IF
	RETURN

	'----- self-drawn NW-arrow cursor with save-under (same art as the other screens)
	ssdrawcur:
	GET (mx, my)-(mx + 5, my + 7), cbuf
	PSET (mx, my), 3
	PSET (mx, my + 1), 3: PSET (mx + 1, my + 1), 3
	PSET (mx, my + 2), 3: PSET (mx + 2, my + 2), 3
	PSET (mx, my + 3), 3: PSET (mx + 3, my + 3), 3
	PSET (mx, my + 4), 3: PSET (mx + 4, my + 4), 3
	PSET (mx, my + 5), 3: PSET (mx + 2, my + 5), 3: PSET (mx + 3, my + 5), 3
	PSET (mx, my + 6), 3: PSET (mx + 1, my + 6), 3
	PSET (mx + 1, my + 2), 2
	PSET (mx + 1, my + 3), 2: PSET (mx + 2, my + 3), 2
	PSET (mx + 1, my + 4), 2: PSET (mx + 2, my + 4), 2: PSET (mx + 3, my + 4), 2
	PSET (mx + 1, my + 5), 2
	cdrn = 1
	RETURN
	sserase:
	IF cdrn = 1 THEN PUT (mx, my), cbuf, PSET
	cdrn = 0
	RETURN
END SUB

'----- shared yes/no modal window (dark theme, matches the main menu): nested
'----- outlines (dkgray, black, dkgray, ltgray, black interior), 9x9 corner
'----- scrolls, ltgray message, ornament stroke, art Yes/No buttons (Yes drawn
'----- active). dk = the active palette's dark-gray attr: 3 on the inventory /
'----- main-menu palette, 1 on the save/load screen (also selects the
'----- attr-swapped art variant). Buttons sit centered as a pair (16x10 art at
'----- 138/166): hit zones Yes 132-158, No 161-187, y 105-117 (plus the legacy
'----- 260-270/80-87 = No).
SUB DrawYNBox (msg AS STRING, dk AS INTEGER, fontData() AS INTEGER)
	CALL DlgLoad
	LINE (44, 76)-(276, 124), dk, B
	LINE (45, 77)-(275, 123), 0, B
	LINE (46, 78)-(274, 122), dk, B
	LINE (47, 79)-(273, 121), 2, B
	LINE (48, 80)-(272, 120), 0, BF
	PUT (44, 116), dlgCor(0), PSET
	PUT (268, 116), dlgCor(16), PSET
	PUT (44, 76), dlgCor(32), PSET
	PUT (268, 76), dlgCor(48), PSET
	CALL drawText(160 - textWidth(msg, fontData()) \ 2, 85, msg, 2, fontData())
	PUT (115, 96), dlgStr(0), PSET
	CALL YNBtn(1, dk)
END SUB

'----- parse the dialog part sprites from disk once (see the dlg* notes up top)
SUB DlgLoad
	DIM i AS INTEGER
	IF dlgOk = 1 THEN EXIT SUB
	REDIM dlgCor(63) AS INTEGER
	REDIM dlgBtn(87) AS INTEGER
	REDIM dlgStr(36) AS INTEGER
	OPEN "DLGCOR.PCT" FOR INPUT AS #2
	FOR i = 0 TO 15
		INPUT #2, dlgCor(i), dlgCor(16 + i), dlgCor(32 + i), dlgCor(48 + i)
	NEXT
	CLOSE #2
	OPEN "DLGBTN.PCT" FOR INPUT AS #2
	FOR i = 0 TO 21
		INPUT #2, dlgBtn(i), dlgBtn(22 + i), dlgBtn(44 + i), dlgBtn(66 + i)
	NEXT
	CLOSE #2
	OPEN "DLGSTRK.PCT" FOR INPUT AS #2
	FOR i = 0 TO 36
		INPUT #2, dlgStr(i)
	NEXT
	CLOSE #2
	dlgOk = 1
END SUB

'----- modal wait on an ALREADY-DRAWN yes/no dialog (DrawYNBox), with its own
'----- self-drawn cursor: hover/arrows move the active-button highlight,
'----- Enter/Space fire the active button, Y/N/Esc answer directly, clicks use
'----- the classic zones. dk as in DrawYNBox. res out: 1 = Yes, 0 = No.
'----- Used by GAME.BAS QuitConfirm (kept tiny for the 64K code ceiling).
SUB YNWait (mvint AS INTEGER, msen AS SINGLE, dk AS INTEGER, res AS INTEGER)
	DIM mr AS RegType, mo AS RegType
	DIM cbuf(40) AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, nmx AS INTEGER, nmy AS INTEGER
	DIM sel AS INTEGER, nyn AS INTEGER, cdrn AS INTEGER
	DIM k$
	res = -1: sel = 1: cdrn = 0
	IF msen = 1 THEN
		'----- let the opening click release so it doesn't carry into Yes/No
		DO
			mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		LOOP WHILE (mo.bx AND 1) <> 0
		mx = mo.cx \ 2: my = mo.dx
		IF mx > 312 THEN mx = 312 ELSE IF mx < 0 THEN mx = 0
		IF my > 192 THEN my = 192 ELSE IF my < 0 THEN my = 0
		GOSUB ynwdraw
	END IF
	ynwloop:
	nyn = 0
	k$ = INKEY$
	IF k$ = "y" OR k$ = "Y" THEN res = 1
	IF k$ = "n" OR k$ = "N" OR k$ = CHR$(27) THEN res = 0
	IF k$ = CHR$(0) + CHR$(75) THEN nyn = 1
	IF k$ = CHR$(0) + CHR$(77) THEN nyn = 2
	IF k$ = CHR$(13) OR k$ = " " THEN IF sel = 1 THEN res = 1 ELSE res = 0
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN GOSUB ynwerase: mx = nmx: my = nmy: GOSUB ynwdraw
		IF my >= 105 AND my <= 117 THEN
			IF mx >= 132 AND mx <= 158 THEN nyn = 1
			IF mx >= 161 AND mx <= 187 THEN nyn = 2
		END IF
		IF (mo.bx AND 1) <> 0 THEN
			IF my >= 105 AND my <= 117 AND mx >= 132 AND mx <= 158 THEN res = 1
			IF my >= 105 AND my <= 117 AND mx >= 161 AND mx <= 187 THEN res = 0
			IF my >= 80 AND my <= 87 AND mx >= 260 AND mx <= 270 THEN res = 0
		END IF
	END IF
	'----- hover / arrows move the active-button highlight
	IF nyn > 0 AND nyn <> sel THEN
		sel = nyn
		GOSUB ynwerase
		CALL YNBtn(sel, dk)
		GOSUB ynwdraw
	END IF
	IF res = -1 THEN GOTO ynwloop
	GOSUB ynwerase
	EXIT SUB

	'----- self-drawn NW-arrow cursor with save-under (same art as the save/load screen's)
	ynwdraw:
	IF msen <> 1 THEN RETURN
	GET (mx, my)-(mx + 5, my + 7), cbuf
	PSET (mx, my), 3
	PSET (mx, my + 1), 3: PSET (mx + 1, my + 1), 3
	PSET (mx, my + 2), 3: PSET (mx + 2, my + 2), 3
	PSET (mx, my + 3), 3: PSET (mx + 3, my + 3), 3
	PSET (mx, my + 4), 3: PSET (mx + 4, my + 4), 3
	PSET (mx, my + 5), 3: PSET (mx + 2, my + 5), 3: PSET (mx + 3, my + 5), 3
	PSET (mx, my + 6), 3: PSET (mx + 1, my + 6), 3
	PSET (mx + 1, my + 2), 2
	PSET (mx + 1, my + 3), 2: PSET (mx + 2, my + 3), 2
	PSET (mx + 1, my + 4), 2: PSET (mx + 2, my + 4), 2: PSET (mx + 3, my + 4), 2
	PSET (mx + 1, my + 5), 2
	cdrn = 1
	RETURN
	ynwerase:
	IF cdrn = 1 THEN PUT (mx, my), cbuf, PSET
	cdrn = 0
	RETURN
END SUB

'----- ReviveShow: after a revive=1 timer death restores the temp save, show
'----- the "they're still in there" message sprite (REVIVE.DAT) centered over
'----- the restored room in a fixed palette, wait for a fresh key or click,
'----- then put the screen back. The CALLER restores the room palette (rmpal).
SUB ReviveShow (mvint AS INTEGER, msen AS SINGLE)
	DIM mr AS RegType, mo AS RegType
	DIM i AS INTEGER, n AS INTEGER, cx AS INTEGER, cy AS INTEGER
	DIM k$
	DIM rt AS SINGLE, el AS SINGLE
	DIM cbuf(40) AS INTEGER
	DIM cmx AS INTEGER, cmy AS INTEGER, nmx AS INTEGER, nmy AS INTEGER, cdrn AS INTEGER
	REDIM rvu(1200) AS INTEGER
	IF rvOk <> 1 THEN
		REDIM rvArt(1200) AS INTEGER
		REDIM rvMsk(1200) AS INTEGER
		OPEN "REVIVE.DAT" FOR INPUT AS #2
		INPUT #2, n
		FOR i = 0 TO n - 1
			INPUT #2, rvArt(i)
		NEXT
		FOR i = 0 TO n - 1
			INPUT #2, rvMsk(i)
		NEXT
		CLOSE #2
		rvOk = 1
	END IF
	cx = (320 - rvArt(0) \ 2) \ 2
	cy = (200 - rvArt(1)) \ 2
	'----- art palette: dkgray box, blue portrait detail, brown/orange text
	PALETTE 1, 8: PALETTE 2, 1: PALETTE 3, 6
	GET (cx, cy)-(cx + rvArt(0) \ 2 - 1, cy + rvArt(1) - 1), rvu
	PUT (cx, cy), rvMsk, AND
	PUT (cx, cy), rvArt, OR
	'----- keys mashed during the death music/screen are NOT a dismissal:
	'----- flush the type-ahead buffer and drain any held click first
	DO
		k$ = INKEY$
	LOOP WHILE k$ <> ""
	IF msen = 1 THEN
		DO
			mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		LOOP WHILE (mo.bx AND 1) <> 0
		'----- software cursor so the pointer stays visible over the message
		cmx = mo.cx \ 2: cmy = mo.dx
		IF cmx > 312 THEN cmx = 312 ELSE IF cmx < 0 THEN cmx = 0
		IF cmy > 192 THEN cmy = 192 ELSE IF cmy < 0 THEN cmy = 0
		GOSUB rvcdraw
	END IF
	'----- wait for a fresh key or click, cursor tracking the mouse...
	rt = TIMER
	rvwait:
	k$ = INKEY$
	IF k$ <> "" THEN GOTO rvdone
	IF msen = 1 THEN
		GOSUB rvctrack
		IF (mo.bx AND 1) <> 0 THEN GOTO rvdone
	END IF
	GOTO rvwait
	'----- ...but never blink away: an early press still leaves the message
	'----- up until it has been visible a full second (cursor keeps moving)
	rvdone:
	DO
		el = TIMER - rt
		IF el < 0 THEN el = el + 86400
		IF el >= 1 THEN EXIT DO
		IF msen = 1 THEN GOSUB rvctrack
	LOOP
	IF msen = 1 THEN GOSUB rvcerase
	PUT (cx, cy), rvu, PSET
	EXIT SUB

	'----- poll the mouse and move the software cursor if it changed
	rvctrack:
	mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
	nmx = mo.cx \ 2: nmy = mo.dx
	IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
	IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
	IF nmx <> cmx OR nmy <> cmy THEN GOSUB rvcerase: cmx = nmx: cmy = nmy: GOSUB rvcdraw
	RETURN

	'----- NW-arrow cursor with save-under (brown outline + dkgray fill --
	'----- the revive palette has no light gray)
	rvcdraw:
	GET (cmx, cmy)-(cmx + 5, cmy + 7), cbuf
	PSET (cmx, cmy), 3
	PSET (cmx, cmy + 1), 3: PSET (cmx + 1, cmy + 1), 3
	PSET (cmx, cmy + 2), 3: PSET (cmx + 2, cmy + 2), 3
	PSET (cmx, cmy + 3), 3: PSET (cmx + 3, cmy + 3), 3
	PSET (cmx, cmy + 4), 3: PSET (cmx + 4, cmy + 4), 3
	PSET (cmx, cmy + 5), 3: PSET (cmx + 2, cmy + 5), 3: PSET (cmx + 3, cmy + 5), 3
	PSET (cmx, cmy + 6), 3: PSET (cmx + 1, cmy + 6), 3
	PSET (cmx + 1, cmy + 2), 1
	PSET (cmx + 1, cmy + 3), 1: PSET (cmx + 2, cmy + 3), 1
	PSET (cmx + 1, cmy + 4), 1: PSET (cmx + 2, cmy + 4), 1: PSET (cmx + 3, cmy + 4), 1
	PSET (cmx + 1, cmy + 5), 1
	cdrn = 1
	RETURN
	rvcerase:
	IF cdrn = 1 THEN PUT (cmx, cmy), cbuf, PSET
	cdrn = 0
	RETURN
END SUB

'----- (re)draw the dialog's Yes/No art buttons inside their hit rects.
'----- sel: 1 = Yes active / No inactive, 2 = No active / Yes inactive.
'----- (dk kept for signature stability; one art set fits every dialog screen)
SUB YNBtn (sel AS INTEGER, dk AS INTEGER)
	DIM yf AS INTEGER, nf AS INTEGER
	CALL DlgLoad
	yf = 1: IF sel = 1 THEN yf = 0
	nf = 3: IF sel = 2 THEN nf = 2
	PUT (138, 106), dlgBtn(yf * 22), PSET
	PUT (166, 106), dlgBtn(nf * 22), PSET
END SUB

'----- ESC main menu: dim the LIVE room screen to black/dark-gray, switch to the
'----- inventory palette and draw the MainMenu box centered. Items: 1 New Game,
'----- 2 Save, 3 Load (dithered+skipped when no save exists), 4 Quit (SYSTEM after
'----- confirm). Save/Load open the Save/Load screen (own bg, replaces the menu).
'----- act out: 0 = resume the game (caller reloads the room), 1 = a game was
'----- LOADED, 2 = NEW GAME chosen (caller RUNs).
'----- dead = 1: opened over the death screen -- Save is dithered/locked, ESC/x
'----- cannot resume (the player must pick New Game, Load or Quit), and New
'----- Game skips its confirm (there is nothing to lose).
SUB MainMenu (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, act AS INTEGER, dead AS INTEGER)
	DIM mr AS RegType, mo AS RegType
	DIM cbuf(40) AS INTEGER
	DIM mny(4) AS INTEGER
	DIM i AS INTEGER, v AS INTEGER, t AS INTEGER, f AS INTEGER
	DIM sel AS INTEGER, ns AS INTEGER, dir AS INTEGER, ldok AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, nmx AS INTEGER, nmy AS INTEGER, mlb AS INTEGER
	DIM done AS INTEGER, cdrn AS INTEGER, hit AS INTEGER
	DIM k$, mnf$, cmsg$, ck$
	DIM cyes AS INTEGER, cmlb AS INTEGER
	DIM cysl AS INTEGER, cnyn AS INTEGER
	DIM mnmd AS INTEGER, act2 AS INTEGER
	'----- save-under for the yes/no modal (44,76)-(276,124): 59 bytes x 49 rows
	REDIM cnf(1450) AS INTEGER
	'----- whole-screen save-under so Back from the save/load screens can restore
	'----- the dimmed menu exactly (GET needs 4 + 80*200 bytes = 8002 ints)
	REDIM mnscr(8195) AS INTEGER

	act = 0: done = 0: sel = 1: mlb = 1: cdrn = 0
	mny(1) = 34: mny(2) = 48: mny(3) = 62: mny(4) = 76

	'----- parse the menu art once per session (interleaved 6-wide like other .PCTs);
	'----- the REDIMs do the real far-heap allocation (see module-level note)
	IF mnOk <> 1 THEN
		REDIM mnArt(1536) AS INTEGER
		REDIM mnLbl(419) AS INTEGER
		OPEN "MENUMAIN.PCT" FOR INPUT AS #2
		FOR i = 0 TO 1536: INPUT #2, mnArt(i): NEXT
		CLOSE #2
		OPEN "MENULBL.PCT" FOR INPUT AS #2
		FOR i = 0 TO 69
			INPUT #2, mnLbl(i), mnLbl(70 + i), mnLbl(140 + i), mnLbl(210 + i), mnLbl(280 + i), mnLbl(350 + i)
		NEXT
		CLOSE #2
		mnOk = 1
	END IF

	'----- Load is dithered/skipped unless some slot holds a save (same probe as slDrawStat)
	ldok = 0
	FOR i = 1 TO 10
		mnf$ = "saver" + CHR$(i + 96) + ".pac"
		OPEN mnf$ FOR APPEND AS #2: CLOSE #2
		OPEN mnf$ FOR INPUT AS #2
		IF NOT EOF(2) THEN ldok = 1
		CLOSE #2
	NEXT

	'----- dim the live screen: snap every colour to dark gray FIRST (instant, hides the
	'----- pixel pass), then rewrite the framebuffer so every lit pixel is attr 1, then
	'----- switch to the standard UI palette (1=dkgray 2=ltgray 3=brown -- same
	'----- layout as the save/load screens, so dialog art needs no variants)
	PALETTE 0, 0: PALETTE 1, 8: PALETTE 2, 8: PALETTE 3, 8
	DEF SEG = &HB800
	FOR i = 0 TO 16383
		v = PEEK(i)
		IF v <> 0 THEN t = (v OR v \ 2) AND &H55: POKE i, t
	NEXT
	DEF SEG
	PALETTE 1, 8: PALETTE 2, 7: PALETTE 3, 6

	'----- take the REAL driver position before the first draw -- mmdraw ends with a
	'----- cursor draw at (mx,my), so a made-up position here would orphan a cursor
	IF msen = 1 THEN
		mr.ax = 2: CALL INTERRUPT(mvint, mr, mo)
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		mx = mo.cx \ 2: my = mo.dx
		IF mx > 312 THEN mx = 312 ELSE IF mx < 0 THEN mx = 0
		IF my > 192 THEN my = 192 ELSE IF my < 0 THEN my = 0
	END IF
	GOSUB mmdraw

	mmwait:
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN
			GOSUB mmerasecur: mx = nmx: my = nmy
			GOSUB mmhover
			'----- a hover-driven redraw already drew the cursor (cdrn=1); drawing
			'----- again would GET a save-under WITH the cursor in it = ghost trail
			IF cdrn = 0 THEN GOSUB mmdrawcur
		END IF
		IF (mo.bx AND 1) <> 0 AND mlb = 0 THEN
			GOSUB mmhit
			IF hit = sel AND hit > 0 THEN GOSUB mmgo
		END IF
		mlb = (mo.bx AND 1)
	END IF
	k$ = INKEY$
	IF (k$ = CHR$(27) OR k$ = "x" OR k$ = "X") AND dead = 0 THEN done = 1
	IF k$ = CHR$(13) OR k$ = " " THEN GOSUB mmgo
	IF k$ = "n" OR k$ = "N" THEN ns = 1: GOSUB mmset: GOSUB mmgo
	IF (k$ = "s" OR k$ = "S") AND dead = 0 THEN ns = 2: GOSUB mmset: GOSUB mmgo
	IF (k$ = "l" OR k$ = "L") AND ldok = 1 THEN ns = 3: GOSUB mmset: GOSUB mmgo
	IF k$ = "q" OR k$ = "Q" THEN ns = 4: GOSUB mmset: GOSUB mmgo
	IF k$ = CHR$(0) + CHR$(72) THEN dir = -1: GOSUB mmstep
	IF k$ = CHR$(0) + CHR$(80) THEN dir = 1: GOSUB mmstep
	IF done = 0 THEN GOTO mmwait
	IF msen = 1 THEN GOSUB mmerasecur
	EXIT SUB

	'----- draw the menu box + the not-selected/disabled label states over it.
	'----- The selected item keeps the base art's light-gray label.
	mmdraw:
	IF msen = 1 THEN GOSUB mmerasecur
	PUT (99, 50), mnArt, PSET
	FOR i = 1 TO 4
		f = 0
		IF i = 2 AND dead = 1 THEN
			f = 5
		ELSEIF i = 3 AND ldok = 0 THEN
			f = 6
		ELSEIF i <> sel THEN
			f = i
		END IF
		IF f > 0 THEN PUT (128, 50 + mny(i)), mnLbl((f - 1) * 70), PSET
	NEXT
	IF msen = 1 THEN GOSUB mmdrawcur
	RETURN

	'----- move the selection dir steps, wrapping and skipping a disabled Load
	mmstep:
	ns = sel
	mmstep2:
	ns = ns + dir
	IF ns < 1 THEN ns = 4
	IF ns > 4 THEN ns = 1
	IF ns = 2 AND dead = 1 THEN GOTO mmstep2
	IF ns = 3 AND ldok = 0 THEN GOTO mmstep2
	mmset:
	IF ns <> sel THEN sel = ns: GOSUB mmdraw
	RETURN

	'----- which item the mouse is over (0 = none); rows follow the label boxes
	mmhit:
	hit = 0
	IF mx >= 120 AND mx <= 195 THEN
		FOR i = 1 TO 4
			IF my >= 47 + mny(i) AND my <= 61 + mny(i) THEN hit = i
		NEXT
	END IF
	IF hit = 2 AND dead = 1 THEN hit = 0
	IF hit = 3 AND ldok = 0 THEN hit = 0
	RETURN

	mmhover:
	GOSUB mmhit
	IF hit > 0 AND hit <> sel THEN ns = hit: GOSUB mmset
	RETURN

	'----- fire the selected item
	mmgo:
	IF sel = 1 THEN
		cyes = 1
		IF dead = 0 THEN cmsg$ = "New game? unsaved game lost.": GOSUB mmconfirm
		IF cyes = 1 THEN act = 2: done = 1
	ELSEIF sel = 2 OR sel = 3 THEN
		mnmd = sel - 1
		GOSUB mmslot
	ELSEIF sel = 4 THEN
		cmsg$ = "Quit the game?": GOSUB mmconfirm
		IF cyes = 1 THEN SYSTEM
	END IF
	RETURN

	'----- open the Save (mnmd 1) or Load (mnmd 2) screen over the menu; Back
	'----- restores the dimmed menu from a whole-screen save-under
	mmslot:
	IF msen = 1 THEN GOSUB mmerasecur
	GET (0, 0)-(319, 199), mnscr
	CALL SlotScreen(fontData(), mvint, msen, mnmd, dead, act2)
	IF act2 = 1 THEN act = 1: done = 1: RETURN
	PUT (0, 0), mnscr, PSET
	PALETTE 0, 0: PALETTE 1, 8: PALETTE 2, 7: PALETTE 3, 6
	mlb = 1
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		mx = mo.cx \ 2: my = mo.dx
		IF mx > 312 THEN mx = 312 ELSE IF mx < 0 THEN mx = 0
		IF my > 192 THEN my = 192 ELSE IF my < 0 THEN my = 0
		GOSUB mmdrawcur
	END IF
	RETURN

	'----- yes/no modal over the menu, with save-under restore on No
	mmconfirm:
	IF msen = 1 THEN GOSUB mmerasecur
	GET (44, 76)-(276, 124), cnf
	CALL DrawYNBox(cmsg$, 1, fontData())
	cyes = -1: cmlb = 1: cysl = 1
	IF msen = 1 THEN GOSUB mmdrawcur
	mmcfw:
	cnyn = 0
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN GOSUB mmerasecur: mx = nmx: my = nmy: GOSUB mmdrawcur
		IF my >= 105 AND my <= 117 THEN
			IF mx >= 132 AND mx <= 158 THEN cnyn = 1
			IF mx >= 161 AND mx <= 187 THEN cnyn = 2
		END IF
		IF (mo.bx AND 1) <> 0 AND cmlb = 0 THEN
			IF my >= 105 AND my <= 117 AND mx >= 132 AND mx <= 158 THEN cyes = 1
			IF my >= 105 AND my <= 117 AND mx >= 161 AND mx <= 187 THEN cyes = 0
			IF my >= 80 AND my <= 87 AND mx >= 260 AND mx <= 270 THEN cyes = 0
		END IF
		cmlb = (mo.bx AND 1)
	END IF
	ck$ = INKEY$
	IF ck$ = "y" OR ck$ = "Y" THEN cyes = 1
	IF ck$ = "n" OR ck$ = "N" OR ck$ = CHR$(27) THEN cyes = 0
	IF ck$ = CHR$(0) + CHR$(75) THEN cnyn = 1
	IF ck$ = CHR$(0) + CHR$(77) THEN cnyn = 2
	IF ck$ = CHR$(13) OR ck$ = " " THEN IF cysl = 1 THEN cyes = 1 ELSE cyes = 0
	'----- hover / arrows move the active-button highlight
	IF cnyn > 0 AND cnyn <> cysl THEN
		cysl = cnyn
		IF msen = 1 THEN GOSUB mmerasecur
		CALL YNBtn(cysl, 1)
		IF msen = 1 THEN GOSUB mmdrawcur
	END IF
	IF cyes = -1 THEN GOTO mmcfw
	IF msen = 1 THEN GOSUB mmerasecur
	PUT (44, 76), cnf, PSET
	IF msen = 1 THEN GOSUB mmdrawcur
	RETURN

	'----- self-drawn NW-arrow cursor with save-under (same art as the save/load screen's)
	mmdrawcur:
	GET (mx, my)-(mx + 5, my + 7), cbuf
	PSET (mx, my), 3
	PSET (mx, my + 1), 3: PSET (mx + 1, my + 1), 3
	PSET (mx, my + 2), 3: PSET (mx + 2, my + 2), 3
	PSET (mx, my + 3), 3: PSET (mx + 3, my + 3), 3
	PSET (mx, my + 4), 3: PSET (mx + 4, my + 4), 3
	PSET (mx, my + 5), 3: PSET (mx + 2, my + 5), 3: PSET (mx + 3, my + 5), 3
	PSET (mx, my + 6), 3: PSET (mx + 1, my + 6), 3
	PSET (mx + 1, my + 2), 2
	PSET (mx + 1, my + 3), 2: PSET (mx + 2, my + 3), 2
	PSET (mx + 1, my + 4), 2: PSET (mx + 2, my + 4), 2: PSET (mx + 3, my + 4), 2
	PSET (mx + 1, my + 5), 2
	cdrn = 1
	RETURN
	mmerasecur:
	IF cdrn = 1 THEN PUT (mx, my), cbuf, PSET
	cdrn = 0
	RETURN
END SUB

'----- MapView: the m-key map screen. Five level plans (MAPL1..MAPB2, W/N.PIC):
'----- W = full plan (shown when the map item 16 is held), N = fog (rooms solid).
'----- Without the map only VISITED rooms (vis bitmask = ob(64)) are lifted from
'----- the W picture and pasted over the N one. Per-room layout lives in
'----- MAPDAT.PAC: room,level,x0,y0,x1,y1,dotx,doty (level 1=L1 2=L2 3=L3 4=B1
'----- 5=B2). Red ring = viewed level; red dot on the plan = the player (only
'----- when viewing his level); red dot beside the selector = his level when
'----- viewing another. Click a selector label to switch level (the plan slides
'----- in from above/below per the building direction); any key or a click
'----- anywhere else closes. The caller reloads the room afterwards.
SUB MapView (hasmap AS INTEGER, curRoom AS INTEGER, vis AS LONG, mvint AS INTEGER, msen AS SINGLE)
	DIM mr AS RegType, mo AS RegType
	DIM cbuf(40) AS INTEGER
	DIM rmN(15) AS INTEGER, rmL(15) AS INTEGER, rx0(15) AS INTEGER, ry0(15) AS INTEGER
	DIM rx1(15) AS INTEGER, ry1(15) AS INTEGER, rdx(15) AS INTEGER, rdy(15) AS INTEGER
	DIM rvx(15) AS INTEGER, rvy(15) AS INTEGER, rvo(15) AS INTEGER
	DIM ls(5) AS INTEGER, hgt(5) AS INTEGER
	DIM nrm AS INTEGER, i AS INTEGER, fh AS INTEGER, nrev AS INTEGER, ofs AS INTEGER
	DIM w AS INTEGER, h AS INTEGER, bpr AS INTEGER
	DIM plv AS INTEGER, vlv AS INTEGER, olv AS INTEGER, hitl AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, nmx AS INTEGER, nmy AS INTEGER, cdrn AS INTEGER
	DIM ly AS INTEGER, dxx AS INTEGER, dyy AS INTEGER, sdy AS INTEGER, sst AS INTEGER
	DIM t9 AS SINGLE
	DIM kbs AS INTEGER, kc AS INTEGER, mvq AS INTEGER
	DIM oly AS INTEGER, nly AS INTEGER, stp AS INTEGER, yy AS INTEGER
	DIM rbuf(120) AS INTEGER
	DIM k$, lv$
	REDIM mbuf(8100) AS INTEGER
	'----- selector: slots top->bottom are L3 L2 L1 B1 B2 (label tops y=83+8*slot).
	'----- ls maps level<->slot (the permutation is its own inverse); hgt = how
	'----- high each level sits in the building (drives the slide direction)
	ls(1) = 3: ls(2) = 2: ls(3) = 1: ls(4) = 4: ls(5) = 5
	hgt(1) = 3: hgt(2) = 4: hgt(3) = 5: hgt(4) = 2: hgt(5) = 1
	nrm = 0
	fh = FREEFILE
	OPEN "mapdat.pac" FOR INPUT AS #fh
	DO WHILE NOT EOF(fh)
		IF nrm >= 15 THEN EXIT DO
		nrm = nrm + 1
		INPUT #fh, rmN(nrm), rmL(nrm), rx0(nrm), ry0(nrm), rx1(nrm), ry1(nrm), rdx(nrm), rdy(nrm)
	LOOP
	CLOSE #fh
	plv = 0
	FOR i = 1 TO nrm
		IF rmN(i) = curRoom THEN plv = rmL(i)
	NEXT
	vlv = plv: IF vlv < 1 THEN vlv = 2
	kbs = ls(vlv)
	olv = 0
	KEY OFF
	GOSUB mvdraw
	'----- flush type-ahead and wait out the opening click
	DO: k$ = INKEY$: LOOP WHILE k$ <> ""
	IF msen = 1 THEN
		DO
			mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		LOOP WHILE (mo.bx AND 1) <> 0
		mx = mo.cx \ 2: my = mo.dx
		IF mx > 313 THEN mx = 313
		IF mx < 0 THEN mx = 0
		IF my > 191 THEN my = 191
		IF my < 0 THEN my = 0
		GOSUB mvcdraw
	END IF
	mvloop:
	k$ = INKEY$
	IF k$ = "" THEN GOTO mvmouse
	IF LEN(k$) = 2 THEN
		'----- arrows walk the selector; Down past B2 parks on the Close button
		kc = ASC(RIGHT$(k$, 1))
		IF kc = 72 AND kbs > 1 THEN kbs = kbs - 1: GOSUB mvkbpos
		IF kc = 80 AND kbs < 6 THEN kbs = kbs + 1: GOSUB mvkbpos
		GOTO mvloop
	END IF
	IF k$ = CHR$(13) OR k$ = " " THEN
		GOSUB mvact
		IF mvq = 1 THEN GOTO mvout
		GOTO mvloop
	END IF
	GOTO mvout
	mvmouse:
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 313 THEN nmx = 313
		IF nmx < 0 THEN nmx = 0
		IF nmy > 191 THEN nmy = 191
		IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN GOSUB mvcerase: mx = nmx: my = nmy: GOSUB mvcdraw
		IF (mo.bx AND 1) <> 0 THEN
			DO
				mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
			LOOP WHILE (mo.bx AND 1) <> 0
			GOSUB mvact
			IF mvq = 1 THEN GOTO mvout
		END IF
	END IF
	GOTO mvloop
	mvout:
	EXIT SUB

	'----- activate whatever is under the pointer: a level label switches (with
	'----- the slide + ring animations), anything else closes (mvq = 1)
	mvact:
	mvq = 0
	hitl = 0
	FOR i = 1 TO 5
		ly = 83 + (i - 1) * 8
		IF my >= ly - 2 AND my <= ly + 6 AND mx >= 196 AND mx <= 220 THEN hitl = ls(i)
	NEXT
	IF hitl = 0 THEN mvq = 1: RETURN
	IF hitl <> vlv THEN
		GOSUB mvcerase
		olv = vlv: vlv = hitl
		GOSUB mvdraw
		GOSUB mvcdraw
	END IF
	RETURN

	'----- park the pointer on the keyboard-selected slot (6 = Close button)
	mvkbpos:
	GOSUB mvcerase
	IF kbs <= 5 THEN
		mx = 207: my = 83 + (kbs - 1) * 8 + 2
	ELSE
		mx = 105: my = 183
	END IF
	'----- warp the driver too (INT33 fn 4) or the next poll snaps the pointer
	'----- straight back to the physical mouse position
	IF msen = 1 THEN
		mr.ax = 4: mr.cx = mx * 2: mr.dx = my
		CALL INTERRUPT(mvint, mr, mo)
	END IF
	GOSUB mvcdraw
	RETURN

	'----- compose the vlv view; when olv is set the plan half slides into place
	mvdraw:
	cdrn = 0
	PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	lv$ = MID$("L1L2L3B1B2", vlv * 2 - 1, 2)
	DEF SEG = &HB800
	IF hasmap = 1 THEN
		BLOAD "MAP" + lv$ + "W.PIC", 0
	ELSE
		BLOAD "MAP" + lv$ + "N.PIC", 0
	END IF
	DEF SEG
	IF hasmap <> 1 THEN
		'----- no map item: walls only (the N picture is blue-only) and ONLY the
		'----- room he is standing in -- everything else stays black, so the real
		'----- map is worth finding
		hitl = 0
		IF plv = vlv AND curRoom >= 1 THEN
			FOR i = 1 TO nrm
				IF rmN(i) = curRoom THEN hitl = i
			NEXT
		END IF
		IF hitl = 0 THEN
			LINE (0, 19)-(199, 177), 0, BF
		ELSE
			IF ry0(hitl) > 19 THEN LINE (0, 19)-(199, ry0(hitl) - 1), 0, BF
			IF ry1(hitl) < 177 THEN LINE (0, ry1(hitl) + 1)-(199, 177), 0, BF
			IF rx0(hitl) > 0 THEN LINE (0, ry0(hitl))-(rx0(hitl) - 1, ry1(hitl)), 0, BF
			IF rx1(hitl) < 199 THEN LINE (rx1(hitl) + 1, ry0(hitl))-(199, ry1(hitl)), 0, BF
		END IF
	END IF
	'----- the player's dot goes on BEFORE the slide so it rides with the plan
	IF plv = vlv AND curRoom >= 1 THEN
		FOR i = 1 TO nrm
			IF rmN(i) = curRoom THEN dxx = rdx(i): dyy = rdy(i): GOSUB mvdot
		NEXT
	END IF
	IF olv >= 1 AND olv <> vlv THEN
		GET (0, 28)-(199, 169), mbuf(0)
		IF hgt(vlv) > hgt(olv) THEN sdy = -9 ELSE sdy = 9
		'----- plans show light blue WITH the map, dark gray without (less inviting)
	PALETTE 1, 7: PALETTE 3, 12
	IF hasmap = 1 THEN PALETTE 2, 9 ELSE PALETTE 2, 8
		FOR sst = 3 TO 0 STEP -1
			LINE (0, 19)-(199, 178), 0, BF
			PUT (0, 28 + (sdy * sst) \ 3), mbuf(0), PSET
			t9 = TIMER
			DO
				IF TIMER < t9 THEN EXIT DO
			LOOP WHILE TIMER < t9 + .035
		NEXT
	END IF
	'----- selector overlays: ring on the viewed level, dot beside the player's
	'----- plans show light blue WITH the map, dark gray without (less inviting)
	PALETTE 1, 7: PALETTE 3, 12
	IF hasmap = 1 THEN PALETTE 2, 9 ELSE PALETTE 2, 8
	IF olv >= 1 AND olv <> vlv THEN
		'----- the ring hops down/up the selector to the new slot
		oly = 83 + (ls(olv) - 1) * 8
		nly = 83 + (ls(vlv) - 1) * 8
		GET (202, 80)-(218, 122), rbuf
		stp = 4: IF nly < oly THEN stp = -4
		FOR yy = oly TO nly STEP stp
			PUT (202, 80), rbuf, PSET
			LINE (204, yy - 2)-(216, yy + 6), 3, B
			t9 = TIMER
			DO
				IF TIMER < t9 THEN EXIT DO
			LOOP WHILE TIMER < t9 + .025
		NEXT
		PUT (202, 80), rbuf, PSET
	END IF
	ly = 83 + (ls(vlv) - 1) * 8
	LINE (204, ly - 2)-(216, ly + 6), 3, B
	IF plv >= 1 AND plv <> vlv THEN
		ly = 83 + (ls(plv) - 1) * 8
		dxx = 199: dyy = ly + 2: GOSUB mvdot
	END IF
	RETURN

	'----- 5x5 rounded red dot at (dxx,dyy)
	mvdot:
	LINE (dxx - 1, dyy - 2)-(dxx + 1, dyy - 2), 3
	LINE (dxx - 2, dyy - 1)-(dxx + 2, dyy + 1), 3, BF
	LINE (dxx - 1, dyy + 2)-(dxx + 1, dyy + 2), 3
	RETURN

	'----- self-drawn NW-arrow cursor with save-under (the save/load screen's art)
	mvcdraw:
	IF msen <> 1 THEN RETURN
	GET (mx, my)-(mx + 5, my + 7), cbuf
	PSET (mx, my), 3
	PSET (mx, my + 1), 3: PSET (mx + 1, my + 1), 3
	PSET (mx, my + 2), 3: PSET (mx + 2, my + 2), 3
	PSET (mx, my + 3), 3: PSET (mx + 3, my + 3), 3
	PSET (mx, my + 4), 3: PSET (mx + 4, my + 4), 3
	PSET (mx, my + 5), 3: PSET (mx + 2, my + 5), 3: PSET (mx + 3, my + 5), 3
	PSET (mx, my + 6), 3: PSET (mx + 1, my + 6), 3
	PSET (mx + 1, my + 2), 2
	PSET (mx + 1, my + 3), 2: PSET (mx + 2, my + 3), 2
	PSET (mx + 1, my + 4), 2: PSET (mx + 2, my + 4), 2: PSET (mx + 3, my + 4), 2
	PSET (mx + 1, my + 5), 2
	cdrn = 1
	RETURN
	mvcerase:
	IF cdrn = 1 THEN PUT (mx, my), cbuf, PSET
	cdrn = 0
	RETURN
END SUB
