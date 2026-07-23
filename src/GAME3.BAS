'----- GAME3.BAS: variable-width small-font renderer (from ART/font2.png, proportional ~7px).
'----- Own 64K code segment. Pure PSET = transparent over backgrounds. Pass a CGA attr (0-3) as textColor.
'----- font file: a HEIGHT line, then per glyph = ASCII code, width, then <height> rows of width-bit binary.
'----- fontData(0) = height H; fontData(code*(H+1)) = width; +1+row = that row's bits.  DIM fontData(2047) in GAME.BAS.
'----- gItal = italic flag (module-shared): drawText sets it from the _ markup, drawChar shears each row by it.
DIM SHARED gItal AS INTEGER
'----- pw2(n) = 2^n bit-mask LUT (filled in initFontSystem); avoids per-pixel floating-point 2^n in drawChar
DIM SHARED pw2(14) AS INTEGER

'----- load font.txt: ASCII code, width, then 7 rows
SUB initFontSystem (fontData() AS INTEGER, fpath AS STRING)
	DIM lineText AS STRING
	DIM cc AS INTEGER, wdt AS INTEGER, row AS INTEGER, di AS INTEGER, pat AS INTEGER, i AS INTEGER, hh AS INTEGER
	pw2(0) = 1: FOR i = 1 TO 14: pw2(i) = pw2(i - 1) * 2: NEXT i
	FOR i = 0 TO 2047
		fontData(i) = 0
	NEXT i
	CLOSE #1
	OPEN fpath FOR INPUT AS #1
	hgtRead:
	IF EOF(1) THEN GOTO fsExit
	LINE INPUT #1, lineText
	IF LEFT$(lineText, 1) = "#" OR LEN(lineText) = 0 THEN GOTO hgtRead
	hh = VAL(lineText): fontData(0) = hh
	DO WHILE NOT EOF(1)
		LINE INPUT #1, lineText
		IF LEFT$(lineText, 1) = "#" OR LEN(lineText) = 0 THEN GOTO fsMain
		cc = VAL(lineText): di = cc * (hh + 1)
		fsWid:
		IF EOF(1) THEN GOTO fsMain
		LINE INPUT #1, lineText
		IF LEFT$(lineText, 1) = "#" OR LEN(lineText) = 0 THEN GOTO fsWid
		wdt = VAL(lineText): fontData(di) = wdt
		FOR row = 0 TO hh - 1
			fsRow:
			IF EOF(1) THEN EXIT FOR
			LINE INPUT #1, lineText
			IF LEFT$(lineText, 1) = "#" OR LEN(lineText) = 0 THEN GOTO fsRow
			lineText = LTRIM$(RTRIM$(lineText))
			pat = 0
			FOR i = 1 TO LEN(lineText)
				IF MID$(lineText, i, 1) = "1" THEN pat = pat + pw2(LEN(lineText) - i)
			NEXT i
			fontData(di + 1 + row) = pat
		NEXT row
		fsMain:
	LOOP
	fsExit:
	CLOSE #1
END SUB

'----- draw one glyph (variable width); each of 7 rows holds (width) bits, MSB = leftmost pixel
SUB drawChar (x AS INTEGER, y AS INTEGER, char AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
	DIM cc AS INTEGER, di AS INTEGER, w AS INTEGER, r AS INTEGER, c AS INTEGER, pat AS INTEGER, hh AS INTEGER, sh AS INTEGER
	DIM bit AS INTEGER, msb AS INTEGER
	hh = fontData(0)
	cc = ASC(char): di = cc * (hh + 1): w = fontData(di)
	IF w = 0 THEN EXIT SUB
	msb = pw2(w - 1)
	FOR r = 0 TO hh - 1
		pat = fontData(di + 1 + r)
		IF pat <> 0 THEN
			IF gItal <> 0 THEN sh = (hh - 1 - r) \ 5 ELSE sh = 0
			bit = msb
			FOR c = 0 TO w - 1
				IF (pat AND bit) <> 0 THEN PSET (x + c + sh, y + r), textColor
				bit = bit \ 2
			NEXT c
		END IF
	NEXT r
END SUB

'----- underline cols x0..x1 at row uy, leaving 1px black on each side of any glyph pixel (descender tails). POINT-based, assumes black bg (message bar).
SUB drawUnder (x0 AS INTEGER, x1 AS INTEGER, uy AS INTEGER, col AS INTEGER)
	DIM ux AS INTEGER, gp AS INTEGER, gc AS INTEGER, gn AS INTEGER
	gp = 0
	FOR ux = x0 TO x1
		IF POINT(ux, uy) <> 0 THEN gc = 1 ELSE gc = 0
		IF POINT(ux + 1, uy) <> 0 THEN gn = 1 ELSE gn = 0
		IF gp = 0 AND gc = 0 AND gn = 0 THEN PSET (ux, uy), col
		gp = gc
	NEXT ux
END SUB

'----- draw a string left-to-right; each glyph advances by its own width + 1px, space = 4px
SUB drawText (x AS INTEGER, y AS INTEGER, text AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
	DIM i AS INTEGER, cx AS INTEGER, cc AS INTEGER, w AS INTEGER, hh AS INTEGER, curcol AS INTEGER, ulOn AS INTEGER, ulStart AS INTEGER
	hh = fontData(0): cx = x: curcol = textColor: gItal = 0: ulOn = 0
	FOR i = 1 TO LEN(text)
		cc = ASC(MID$(text, i, 1))
		IF cc = 126 THEN
			IF curcol = textColor THEN curcol = 2 ELSE curcol = textColor
		ELSEIF cc = 95 THEN
			IF gItal = 0 THEN gItal = 1 ELSE gItal = 0
		ELSEIF cc = 124 THEN
			IF ulOn = 0 THEN
				ulOn = 1: ulStart = cx
			ELSE
				ulOn = 0: CALL drawUnder(ulStart, cx - 2, y + hh - 1, curcol)
			END IF
		ELSEIF cc = 32 THEN
			cx = cx + 4
		ELSE
			CALL drawChar(cx, y, MID$(text, i, 1), curcol, fontData())
			w = fontData(cc * (hh + 1)): IF w = 0 THEN w = 3
			cx = cx + w + 1
		END IF
	NEXT i
	gItal = 0
END SUB

'----- pixel width of a string (for proportional word-wrap)
FUNCTION textWidth (text AS STRING, fontData() AS INTEGER)
	DIM i AS INTEGER, cc AS INTEGER, w AS INTEGER, tot AS INTEGER, hh AS INTEGER
	hh = fontData(0): tot = 0
	FOR i = 1 TO LEN(text)
		cc = ASC(MID$(text, i, 1))
		IF cc = 32 THEN
			tot = tot + 4
		ELSEIF cc <> 126 AND cc <> 95 AND cc <> 124 THEN
			w = fontData(cc * (hh + 1)): IF w = 0 THEN w = 3
			tot = tot + w + 1
		END IF
	NEXT i
	textWidth = tot
END FUNCTION

'----- draw a string word-wrapped to maxpx pixels/line (collapses space runs); a backslash forces a line break, two backslashes = a blank line
SUB drawWrap (x AS INTEGER, y AS INTEGER, txt AS STRING, col AS INTEGER, maxpx AS INTEGER, lineh AS INTEGER, fontData() AS INTEGER)
	DIM cy AS INTEGER, i AS INTEGER, ch AS STRING, word AS STRING, ln AS STRING, ww AS INTEGER, lw AS INTEGER, brc AS STRING
	cy = y: ln = "": lw = 0: word = "": brc = CHR$(92)
	FOR i = 1 TO LEN(txt) + 1
		IF i <= LEN(txt) THEN ch = MID$(txt, i, 1) ELSE ch = " "
		IF ch = " " OR ch = brc THEN
			IF LEN(word) > 0 THEN
				ww = textWidth(word, fontData())
				IF lw = 0 THEN
					ln = word: lw = ww
				ELSEIF lw + 4 + ww > maxpx THEN
					CALL drawText(x, cy, ln, col, fontData()): cy = cy + lineh: ln = word: lw = ww
				ELSE
					ln = ln + " " + word: lw = lw + 4 + ww
				END IF
				word = ""
			END IF
			IF ch = brc THEN CALL drawText(x, cy, ln, col, fontData()): cy = cy + lineh: ln = "": lw = 0
		ELSE
			word = word + ch
		END IF
	NEXT i
	IF LEN(ln) > 0 THEN CALL drawText(x, cy, ln, col, fontData())
END SUB

'----- live Progress % (top-left box) + in-game clock H:MM (top-right box), drawn in the empty
'----- space right of INVMAIN's baked "Progress"/"Time" labels. Heavy code lives here (GAME3 has room).
SUB drawStats (ob() AS SINGLE, cl AS SINGLE, cr AS SINGLE, fontData() AS INTEGER)
	DIM tmin AS INTEGER, hh AS INTEGER, mm AS INTEGER, pcnt AS INTEGER, i AS INTEGER
	tmin = INT(cl * cr): hh = 8 + tmin \ 60: mm = tmin - (hh - 8) * 60
	pcnt = 0
	FOR i = 1 TO 51
		IF ob(i) >= 1 THEN pcnt = pcnt + 1
	NEXT i
	IF ob(36) >= 1 THEN pcnt = pcnt + 2
	IF ob(35) >= 1 THEN pcnt = pcnt + 2
	pcnt = CINT(pcnt * 100 / 47)
	CALL drawText(49, 11, LTRIM$(STR$(pcnt)) + "%", 2, fontData())
	CALL drawText(278, 11, LTRIM$(STR$(hh)) + ":" + RIGHT$("0" + LTRIM$(STR$(mm)), 2), 2, fontData())
END SUB

'----- load all three fonts at startup, each into its own array (renderer selects via the fontData() arg)
SUB initAllFonts (fontData() AS INTEGER, font3Data() AS INTEGER, fontbData() AS INTEGER)
	CALL initFontSystem(fontData(), "font.txt")
	CALL initFontSystem(font3Data(), "font3.txt")
	CALL initFontSystem(fontbData(), "fontbold.txt")
END SUB

'----- top-of-screen message: black-bar the top rows, then word-wrap the string in the given font
SUB drawMsg (s AS STRING, fontData() AS INTEGER)
	DIM lh AS INTEGER
	lh = fontData(0) + 1
	LINE (0, 0)-(319, lh * 2 - 1), 0, BF
	CALL drawWrap(2, 1, s, 3, 314, lh, fontData())
END SUB

'----- bottom-left HUD: which inventory item the Use verb applies ("U" in the
'----- room's attr-3 brown, the rest attr-1 gray). Clears the strip when
'----- nothing usable is held.
SUB HudUse (sel2 AS INTEGER, ob() AS SINGLE, sn$(), fontData() AS INTEGER)
	DIM it$
	it$ = ""
	IF sel2 >= 1 AND sel2 <= 50 THEN
		IF ob(sel2) = 1 THEN it$ = sn$(sel2)
	END IF
	LINE (0, 192)-(170, 199), 0, BF
	IF it$ = "" THEN EXIT SUB
	CALL drawText(3, 192, "U", 3, fontData())
	CALL drawText(3 + textWidth("U", fontData()), 192, "se = " + it$, 1, fontData())
END SUB

'----- intro: black the palette, hold ~1s (hides the slow carr.pic BLOAD on old hardware), then load + reveal the car scene
SUB introShowCarr
	DIM t9 AS SINGLE, d9 AS SINGLE
	PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	t9 = TIMER
	DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < 1
	DEF SEG = &HB800: BLOAD "carr.pic", 0: DEF SEG
	PALETTE 3, 6: PALETTE 1, 2: PALETTE 2, 11
END SUB

'----- fade "A Kreuzer Production" (attr 3) in through the CGA grays: 0 black -> 8 dk-gray -> 7 lt-gray -> 15 white, then hold
SUB introFadeCredit
	DIM t9 AS SINGLE, d9 AS SINGLE, fws AS SINGLE
	fws = .15
	PALETTE 3, 8: GOSUB fcw
	PALETTE 3, 7: GOSUB fcw
	PALETTE 3, 15: GOSUB fcw
	fws = .5: GOSUB fcw
	EXIT SUB
	fcw:
	t9 = TIMER
	DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < fws
	RETURN
END SUB

'----- book reader: hold the just-loaded book picture ~1.5s, then clear and word-wrap the book's text in the given font
SUB showBook (sel AS SINGLE, fontData() AS INTEGER)
	DIM t9 AS SINGLE, d9 AS SINGLE, bt AS STRING, lh AS INTEGER
	t9 = TIMER
	DO
		d9 = TIMER - t9: IF d9 < 0 THEN d9 = d9 + 86400
	LOOP WHILE d9 < 1.5
	bt = ""
	SELECT CASE sel
	CASE 3
		bt = "The other doctors have become weary as the"
		bt = bt + " research money is drying up. I have taken the"
		bt = bt + " liberty of hiding the rest so they do not get"
		bt = bt + " greedy and steal it. The money is now boarded up"
		bt = bt + " in the headboard of my bed; not even the"
		bt = bt + " servants know about it.\\Time is the barrier to"
		bt = bt + " the place of the damned."
	CASE 9
		bt = "Patient: Naton McDaniel\Disorder: Paranoid"
		bt = bt + " Schizophrenia\Notes: Nervous, complains of"
		bt = bt + " voices, often talks in gibberish.\ID: 12443"
		bt = bt + "\\Patient: Havos Lobos\Disorder: Severe"
		bt = bt + " Delusions\Notes: What he sees and hears becomes"
		bt = bt + " his reality. Very dangerous.\ID: 385938"
		bt = bt + "\\Patient: Gary Coleman\Disorder: Psychotic"
		bt = bt + " dementia\Notes: A leader among the patients,"
		bt = bt + " fixated on knives, blood and sacrifice."
		bt = bt + " Extremely disturbed.\ID: 485970"
	CASE 10
		bt = "I have concluded another successful experiment."
		bt = bt + "  This time the other doctors have grown greedy"
		bt = bt + " and want the notes for themselves.  So I gave"
		bt = bt + " them to the servants and coded them -- and the"
		bt = bt + " code book is hidden, where they will never find"
		bt = bt + " it nor steal my breakthrough."
	CASE 19
		bt = "3/15\The patients have become unruly. I fear they"
		bt = bt + " will overpower us, but the research must go on."
		bt = bt + "\\3/17\The other doctors too are concerned. We"
		bt = bt + " are tired from the long hours and make many"
		bt = bt + " errors of judgment.\\3/23\Something in the air"
		bt = bt + " down there clouds my head. I have moved my"
		bt = bt + " practice to the attic, hidden behind a pit of"
		bt = bt + " ash that only an electric circuit will open."
		bt = bt + " The MPTP vials are upper left.\\3/29\Edwards has"
		bt = bt + " been following me. I fear he grows suspicious."
		bt = bt + " (The rest of the page is torn away.)"
	CASE 21
		bt = "The Zombie Syrem\\MPTP -- this formula harbors the"
		bt = bt + " most dangerous compound known, one that leaves a"
		bt = bt + " victim paralyzed for days at a time. The"
		bt = bt + " conclusive test on human subjects has yielded"
		bt = bt + " promising results.\\The subjects, though, gain in"
		bt = bt + " strength and reflex, growing harder to control."
		bt = bt + " We have begun using torture to curb them; it is"
		bt = bt + " almost safer to keep them on it permanently, lest"
		bt = bt + " they overthrow the doctors."
	CASE 25
		bt = "A Cipher Key\\A slim codex of symbols, each set"
		bt = bt + " beside its true letter. The doctor coded his"
		bt = bt + " notes to keep them from greedy hands -- but with"
		bt = bt + " this key the cipher gives way. Lay it against the"
		bt = bt + " torn halves of the formula and the scattered"
		bt = bt + " notations resolve into a single, complete"
		bt = bt + " working."
	CASE ELSE
		bt = "The pages are water-stained and illegible."
	END SELECT
	LINE (0, 0)-(319, 199), 0, BF
	PALETTE 3, 6
	lh = fontData(0) + 1
	CALL drawWrap(6, 2, bt, 3, 308, lh, fontData())
END SUB

'----- ShowRules: the pre-game instructions screen (moved verbatim from
'----- GAME.BAS's rules: gosub -- that module is at the 64K code ceiling)
SUB ShowRules
	CLS
	WIDTH 80
	PRINT " Welcome to the premier point and click game by Kreuzer productions"
	PRINT " The point and click interface is really quite easy. Move the green"
	PRINT " cursor onto the object you want to manipulate and press one of "
	PRINT " these keys. (a) for action . (l) to look at an object. Type (u) to"
	PRINT " use th active object. (g) to get that object.(note) some objects you"
	PRINT " must look at to get or you must look at the drawer to find the object "
	PRINT " inside. Also at any time during the game you may press (i) to display "
	PRINT " the your inventory ,time and place. Plus you may load,save or quit"
	PRINT " or select the active object from this screen. "
	PRINT " if you seem to be stuck it would be wise to backtrack and look to see if"
	PRINT " you anything new has opened up or one of your objects has a use in that"
	PRINT " room. If action does not work on something you might try look or get or"
	PRINT " vice versa, also try clicking the cursor on different parts of the object"
	PRINT " it might reveal different things. "
	PRINT " Hints: Click (a) on and arrow by the door to leave"
	PRINT " Even though it might seem as if two or more objects"
	PRINT " could do the trick, usually only one will work."
	PRINT " Just to get you started move your cursor by the rug of the first"
	PRINT " room. Then press (l) it will say you see a lumpy rug. That didn't help."
	PRINT " Don't worry, save often you never know what may happen"
	PRINT " P.S. Time does matter"
	PRINT " Get ready to journey into the twisting and contorting shadows of"
	PRINT " your uncle's residence"
	PRINT " PRESS ANY KEY TO CONTINUE "
	DO
		rk$ = INKEY$
	LOOP WHILE rk$ = ""
	SCREEN 1
END SUB

'----- Credits / ending sequence (moved verbatim from GAME.BAS -- 64K ceiling).
'----- gd% carries ob(43): 1 = curtains were lit -> the house-burns good
'----- ending; anything else -> the bad "uncle not saved" screen.
SUB Credits (gd%)
	DIM e0(600) AS INTEGER
	SCREEN 1
	KEY OFF
	PALETTE 1, 8: PALETTE 2, 4: PALETTE 3, 14
	IF gd% <> 1 THEN GOTO 15700

	'----- good ending: house burns
	DEF SEG = &HB800: BLOAD "end.pic", 0: DEF SEG
	PLAY "e-6d5e-5d5f7p7"
	PLAY "a5>c6<b6a5g6a4"
	FOR e3 = 1 TO 5: SOUND 32761, 1: NEXT e3

	FOR e6 = 1 TO 3
		FOR e4 = 1 TO 3
			IF e4 = 1 THEN e5 = 8 ELSE IF e4 = 2 THEN e5 = 7 ELSE e5 = 15
			PALETTE e6, e5
			FOR e3 = 1 TO 5: IF RND < .9 THEN SOUND RND * 71 + 50, (RND * .2) + .3 ELSE SOUND 32767, .5
			NEXT e3
		NEXT e4: NEXT e6

	PALETTE 0, 15
	DEF SEG = &HB800: BLOAD "end2.pic", 0: DEF SEG
	FOR e3 = 1 TO 7: SOUND 32671, .5: NEXT e3
	PALETTE 0, 0

	FOR e6 = 1 TO 3
		FOR e4 = 1 TO 3
			IF e4 = 1 THEN e5 = 8 ELSE IF e4 = 2 THEN e5 = 7 ELSE GOSUB 15640
			PALETTE e6, e5
			FOR e3 = 1 TO 5: IF RND < .9 THEN SOUND RND * 71 + 50, (RND * .2) + .3 ELSE SOUND 32767, .5
			NEXT e3
		NEXT e4: NEXT e6

	FOR e3 = 1 TO 40: SOUND 32676, .1: NEXT e3
	GOSUB 15660
	FOR e3 = 1 TO 20: SOUND 32761, 1: NEXT e3
	GOSUB 15650

	'----- closing narration
	PRINT "You run swiftly from the flaming"
	PRINT "building that is being consumed by"
	PRINT "the blaze. As you look back at the"
	PRINT "burning house, spewing fiery shrapnel"
	PRINT "about the grounds you wonder about"
	PRINT "your uncle and his work. What was"
	PRINT "he realy like? What was obliterated"
	PRINT "in the house? Did you leave something"
	PRINT "behind or undone ...."
	PRINT "Maybe some day you'll find out."
	PRINT "": PRINT "Press a key to exit."
15592 IF INKEY$ = "" THEN GOTO 15592
	EXIT SUB

	'----- pick palette color by frame
15640 IF e6 = 1 THEN e5 = 8
	IF e6 = 2 THEN e5 = 2
	IF e6 = 3 THEN e5 = 6
	RETURN

	'----- static-screen wipe effect
15650 FOR e3 = 1 TO 23: FOR e2 = 1 TO 40
		LOCATE INT(RND * 23) + 1, INT(RND * 40) + 1: PRINT " "
		SOUND 32676, .05
	NEXT e2: NEXT e3
	CLS
	RETURN

	'----- flying shrapnel animation
15660 GET (212, 140)-(262, 160), e0
	PUT (212, 140), e0, XOR
	LINE (211, 148)-(265, 148), 1
	FOR e1 = 212 TO 65 STEP -1
		PUT (e1, 140), e0, XOR
		SOUND (RND * 100) + 50, .1: SOUND 100, .1
		PUT (e1, 140), e0, XOR
	NEXT e1
	RETURN

	'----- bad ending (uncle not saved)
15700 DEF SEG = &HB800: BLOAD "end1.pic", 0: DEF SEG
	PALETTE 1, 8: PALETTE 2, 4: PALETTE 3, 14
	PLAY "e-6d5e-5d5f7p7"
	PLAY "a5>c6<b6a5g6a4"
15704 IF INKEY$ = "" THEN GOTO 15704
	EXIT SUB
END SUB
