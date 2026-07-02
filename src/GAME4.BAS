'----- GAME4.BAS: graphical Save / Load screen (10 slots). Own 64K code segment.
'----- Pure library module (no COMMON SHARED): invoked from invhi as
'-----   CALL SaveLoadScreen(fontData(), mvint, msen, act)
'----- It loads SVLDBG.PIC, reads each saver?.pac header to show per-slot
'----- Location + Progress%, runs its own mouse/keyboard loop with a self-drawn
'----- cursor, and delegates the real file I/O to SaveGame/LoadGame (GAME.BAS).
'----- New Game / overwrite-save / load each confirm via a yes/no modal.
'----- act returns 1 if a game was LOADED, 2 if NEW GAME chosen (caller RUNs), else 0.

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
DECLARE SUB SaveGame (slot AS INTEGER)
DECLARE SUB LoadGame (slot AS INTEGER)
DECLARE FUNCTION slLoc$ (rq AS STRING)

'----- per-slot occupancy (1 = has a save); set by slDrawStat, read for overwrite/load confirms
DIM SHARED slUsed(10) AS INTEGER
'----- selection ring from src/ART/SLRing.png, parsed to SLRING.DAT: slrN packed pixels
'----- (attr*10000 + dy*100 + dx); slrbuf = GET save-under for clean erase.
DIM SHARED slrp(400) AS INTEGER
DIM SHARED slrbuf(280) AS INTEGER
DIM SHARED slrN AS INTEGER
'----- last slot saved/loaded; persists across SaveLoadScreen opens (reset by RUN/New Game)
DIM SHARED slLast AS INTEGER

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
	LINE (sx - 1, sy - 1)-(sx + 53, sy + 12), 0, BF
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
		IF j <= 51 AND sob = 1 THEN pc = pc + 1
		IF j = 35 AND sob = 1 THEN pc = pc + 2
		IF j = 36 AND sob = 1 THEN pc = pc + 2
	NEXT j
	CLOSE #2
	pc = CINT(pc * 100 / 47)
	CALL drawText(sx - 1, sy - 1, slLoc$(sq$), 2, fontData())
	CALL drawText(sx - 1, sy + 6, LTRIM$(STR$(pc)) + "% done", 2, fontData())
END SUB

'----- draw (vis=1, orange) or erase (vis=0, black interior) the selection ring
'----- around a slot's number. Drawn on the black slot interior, so erase = black.
'----- draw (vis=1) the SLRing sprite around a slot via PSET (after GETting a save-under),
'----- or erase (vis=0) by PUTting the save-under back. Left slots rx=52, right rx=156.
SUB slRing (slot AS INTEGER, vis AS INTEGER)
	DIM rx AS INTEGER, ry AS INTEGER, i AS INTEGER, p AS INTEGER
	IF slot <= 5 THEN rx = 54 ELSE rx = 157
	ry = 37 + ((slot - 1) MOD 5) * 21
	IF vis = 1 THEN
		GET (rx, ry)-(rx + 98, ry + 20), slrbuf
		FOR i = 1 TO slrN
			p = slrp(i)
			PSET (rx + p MOD 100, ry + (p \ 100) MOD 100), p \ 10000
		NEXT
	ELSE
		PUT (rx, ry), slrbuf, PSET
	END IF
END SUB

SUB SaveLoadScreen (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, act AS INTEGER, dead AS INTEGER)
	DIM mr AS RegType, mo AS RegType
	DIM cbuf(40) AS INTEGER
	DIM sel AS INTEGER, osel AS INTEGER, i AS INTEGER, sx AS INTEGER, sy AS INTEGER
	DIM mx AS INTEGER, my AS INTEGER, nmx AS INTEGER, nmy AS INTEGER, mlb AS INTEGER
	DIM k$, r AS INTEGER, cs AS INTEGER, done AS INTEGER, cdrn AS INTEGER
	DIM cmsg$, ck$
	DIM cyes AS INTEGER, cmlb AS INTEGER, cnodraw AS INTEGER

	'----- mlb starts PRESSED so the click that opened this screen (still held) is not
	'----- re-registered as a button press here (it overlaps the New Game button).
	act = 0: done = 0: sel = 1: mlb = 1: cdrn = 0
	IF slLast >= 1 AND slLast <= 10 THEN sel = slLast
	SCREEN 1
	'----- load the selection-ring pixel data (SLRING.DAT) + size the save-under buffer
	OPEN "SLRING.DAT" FOR INPUT AS #2
	INPUT #2, slrN
	FOR i = 1 TO slrN: INPUT #2, slrp(i): NEXT
	CLOSE #2
	GOSUB drawall
	IF msen = 1 THEN mr.ax = 2: CALL INTERRUPT(mvint, mr, mo): mx = 160: my = 100: GOSUB drawcur4

	slwait:
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN GOSUB erasecur4: mx = nmx: my = nmy: GOSUB drawcur4
		IF (mo.bx AND 1) <> 0 AND mlb = 0 THEN GOSUB slclick
		mlb = (mo.bx AND 1)
	END IF
	k$ = INKEY$
	IF k$ <> "" THEN GOSUB slkey
	IF done = 0 THEN GOTO slwait
	IF msen = 1 THEN GOSUB erasecur4
	EXIT SUB

	'----- (re)draw the whole screen: background, all slot stats, the selector ring.
	'----- Used at startup and to wipe a confirm modal.
	drawall:
	DEF SEG = &HB800: BLOAD "SVLDBG.PIC", 0: DEF SEG
	PALETTE 1, 8: PALETTE 2, 7: PALETTE 3, 6
	IF dead = 1 THEN LINE (60, 170)-(106, 190), 0, BF: LINE (214, 170)-(289, 190), 0, BF
	FOR i = 1 TO 10
		IF i <= 5 THEN sx = 91: sy = 41 + (i - 1) * 21 ELSE sx = 193: sy = 41 + (i - 6) * 21
		CALL slDrawStat(i, sx, sy, fontData())
	NEXT i
	CALL slRing(sel, 1)
	RETURN

	'----- mouse click: pick a slot, or fire a bottom button
	slclick:
	r = 0
	IF my >= 37 AND my <= 58 THEN r = 1
	IF my >= 59 AND my <= 79 THEN r = 2
	IF my >= 80 AND my <= 100 THEN r = 3
	IF my >= 101 AND my <= 121 THEN r = 4
	IF my >= 122 AND my <= 143 THEN r = 5
	IF r > 0 THEN
		cs = 0
		IF mx >= 64 AND mx <= 152 THEN cs = r
		IF mx >= 166 AND mx <= 254 THEN cs = r + 5
		IF cs > 0 AND cs <> sel THEN GOSUB erasecur4: CALL slRing(sel, 0): sel = cs: CALL slRing(sel, 1): GOSUB drawcur4
	END IF
	IF my >= 171 AND my <= 189 THEN
		IF mx >= 60 AND mx <= 104 THEN GOSUB dosave: RETURN
		IF mx >= 108 AND mx <= 152 THEN GOSUB doload: RETURN
		IF mx >= 164 AND mx <= 213 THEN GOSUB donew: RETURN
		IF mx >= 216 AND mx <= 287 AND dead = 0 THEN done = 1: RETURN
	END IF
	RETURN

	'----- key: S save, L load, N new; C/X = back to inventory; Esc = close inventory entirely (act=3 -> game); arrows move the selector
	slkey:
	IF k$ = "s" OR k$ = "S" THEN GOSUB dosave: RETURN
	IF k$ = "l" OR k$ = "L" THEN GOSUB doload: RETURN
	IF k$ = "n" OR k$ = "N" THEN GOSUB donew: RETURN
	IF k$ = CHR$(27) AND dead = 0 THEN act = 3: done = 1: RETURN
	IF (k$ = "c" OR k$ = "C" OR k$ = "x" OR k$ = "X") AND dead = 0 THEN done = 1: RETURN
	osel = sel
	IF k$ = CHR$(0) + CHR$(72) THEN sel = sel - 1
	IF k$ = CHR$(0) + CHR$(80) THEN sel = sel + 1
	IF k$ = CHR$(0) + CHR$(75) AND sel > 5 THEN sel = sel - 5
	IF k$ = CHR$(0) + CHR$(77) AND sel <= 5 THEN sel = sel + 5
	IF sel < 1 THEN sel = 1
	IF sel > 10 THEN sel = 10
	IF sel <> osel THEN GOSUB erasecur4: CALL slRing(osel, 0): CALL slRing(sel, 1): GOSUB drawcur4
	RETURN

	'----- save to the selected slot; confirm first if it already holds a save
	dosave:
	IF dead = 1 THEN RETURN
	IF slUsed(sel) = 1 THEN cmsg$ = "Overwrite this slot?": GOSUB confirm: IF cyes = 0 THEN RETURN
	IF msen = 1 THEN GOSUB erasecur4
	CALL SaveGame(sel)
	slLast = sel
	IF sel <= 5 THEN sx = 91: sy = 41 + (sel - 1) * 21 ELSE sx = 193: sy = 41 + (sel - 6) * 21
	CALL slDrawStat(sel, sx, sy, fontData())
	CALL slRing(sel, 1)
	IF msen = 1 THEN GOSUB drawcur4
	mlb = 1
	RETURN

	'----- load the selected slot (only if it holds a save); confirm losing the current game
	doload:
	IF slUsed(sel) = 0 THEN RETURN
	IF dead = 0 THEN cmsg$ = "Load? unsaved game lost.": GOSUB confirm: IF cyes = 0 THEN RETURN
	IF msen = 1 THEN GOSUB erasecur4
	CALL LoadGame(sel)
	slLast = sel
	act = 1: done = 1
	RETURN

	'----- start a new game (confirm losing the current game); caller RUNs to replay the intro
	donew:
	IF dead = 0 THEN cnodraw = 1: cmsg$ = "New game? unsaved game lost.": GOSUB confirm: cnodraw = 0: IF cyes = 0 THEN RETURN
	act = 2: done = 1
	RETURN

	'----- yes/no modal. In: cmsg$. Out: cyes (1/0). Mouse Yes/No boxes + Y/N/Esc keys.
	'----- cmlb starts pressed (debounce the triggering click); wipes itself via drawall.
	confirm:
	IF msen = 1 THEN GOSUB erasecur4
	CALL DrawYNBox(cmsg$, 1, fontData())
	cyes = -1: cmlb = 1
	IF msen = 1 THEN GOSUB drawcur4
	cfw:
	IF msen = 1 THEN
		mr.ax = 3: CALL INTERRUPT(mvint, mr, mo)
		nmx = mo.cx \ 2: nmy = mo.dx
		IF nmx > 312 THEN nmx = 312 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 192 THEN nmy = 192 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN GOSUB erasecur4: mx = nmx: my = nmy: GOSUB drawcur4
		IF (mo.bx AND 1) <> 0 AND cmlb = 0 THEN
			IF my >= 105 AND my <= 117 AND mx >= 92 AND mx <= 142 THEN cyes = 1
			IF my >= 105 AND my <= 117 AND mx >= 178 AND mx <= 228 THEN cyes = 0
			IF my >= 80 AND my <= 87 AND mx >= 260 AND mx <= 270 THEN cyes = 0
		END IF
		cmlb = (mo.bx AND 1)
	END IF
	ck$ = INKEY$
	IF ck$ = "y" OR ck$ = "Y" THEN cyes = 1
	IF ck$ = "n" OR ck$ = "N" OR ck$ = CHR$(27) THEN cyes = 0
	IF cyes = -1 THEN GOTO cfw
	IF msen = 1 THEN GOSUB erasecur4
	IF cnodraw = 1 AND cyes = 1 THEN RETURN
	GOSUB drawall
	IF msen = 1 THEN GOSUB drawcur4
	RETURN

	'----- self-drawn NW-arrow cursor matching the inventory's grdnw (attr3 brown outline + attr2 ltgray fill) with save-under
	drawcur4:
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
	erasecur4:
	IF cdrn = 1 THEN PUT (mx, my), cbuf, PSET
	cdrn = 0
	RETURN
END SUB

'----- shared yes/no modal window (inventory quit style): ltgray(2) body, black(0) outer border + dkgray(dk)
'----- inner frame, BLACK title bar with an "x", centered black message, raised Yes/No buttons. dk = the
'----- active palette's dark-gray attr (1 on the save/load screen, 3 in the inventory). Caller polls the
'----- hit zones: Yes 92-142, No 178-228, x 260-270 (=No), all y 105-117 (x at y 80-87).
SUB DrawYNBox (msg AS STRING, dk AS INTEGER, fontData() AS INTEGER)
	LINE (44, 76)-(276, 124), 2, BF
	LINE (44, 76)-(276, 124), 0, B
	LINE (46, 78)-(274, 122), dk, B
	LINE (48, 80)-(272, 87), 0, BF
	LINE (262, 81)-(267, 86), 2: LINE (262, 86)-(267, 81), 2
	CALL drawText(160 - textWidth(msg, fontData()) \ 2, 94, msg, 0, fontData())
	LINE (92, 105)-(142, 117), 2, BF: LINE (92, 105)-(142, 117), 0, B
	LINE (93, 116)-(141, 116), dk: LINE (141, 106)-(141, 116), dk
	CALL drawText(110, 108, "Yes", 0, fontData())
	LINE (178, 105)-(228, 117), 2, BF: LINE (178, 105)-(228, 117), 0, B
	LINE (179, 116)-(227, 116), dk: LINE (227, 106)-(227, 116), dk
	CALL drawText(198, 108, "No", 0, fontData())
END SUB
