'----- COMPTEST.BAS: checks C3DCOMP.OVL's ops 5 (MERGE) and 6 (OVERLAY) against QB's own
'----- drawing on a SCREEN 1 page: random boxes, random sprite pairs at random offsets (part
'----- off the box, any pixel phase, with and without a mask), the overlay's result against
'----- PUT AND + PUT OR (or PSET) there, the merge's against PSET of POINT per pixel.
'----- Run from src (C3DCOMP.OVL there). Output: COMPTEST.LOG
DEFINT A-Z
DECLARE SUB Cop (op, d(), s(), m(), w5, w6, w7, w8, nomask)
DECLARE SUB Fill (x, y, w, h)
'$DYNAMIC
DIM SHARED pcm(0 TO 8) AS INTEGER, ovl(0 TO 400) AS INTEGER
DIM SHARED db(0 TO 400) AS INTEGER, tb(0 TO 400) AS INTEGER, rf(0 TO 400) AS INTEGER
DIM SHARED ar(0 TO 400) AS INTEGER, mk(0 TO 400) AS INTEGER
'$STATIC
DIM fh, i, n, tr, w, h, ow, oh, dx, dy, op, bad5, bad6, nw, x, y, c0, c1, r0, r1, nm, s$
	fh = FREEFILE
	OPEN "C3DCOMP.OVL" FOR BINARY AS #fh
	n = LOF(fh): s$ = SPACE$(n): GET #fh, 1, s$: CLOSE #fh
	FOR i = 0 TO n - 1 STEP 2
		ovl(i \ 2) = CVI(MID$(s$ + CHR$(0), i + 1, 2))
	NEXT
	SCREEN 1: RANDOMIZE 12345
	fh = FREEFILE
	OPEN "COMPTEST.LOG" FOR OUTPUT AS #fh
	PRINT #fh, "C3DCOMP.OVL"; n; "bytes"
	'----- op 6: the overlay
	FOR tr = 1 TO 400
		w = (INT(RND * 10) + 1) * 4: h = INT(RND * 30) + 1
		ow = INT(RND * 23) + 1: oh = INT(RND * 20) + 1
		dx = INT(RND * (w + 30)) - 25: dy = INT(RND * (h + 25)) - 20
		nm = 0: IF RND < .2 THEN nm = 1
		CALL Fill(0, 0, w, h): GET (0, 0)-(w - 1, h - 1), db
		CALL Fill(0, 50, ow, oh): GET (0, 50)-(ow - 1, 50 + oh - 1), ar
		CALL Fill(0, 80, ow, oh): GET (0, 80)-(ow - 1, 80 + oh - 1), mk
		'----- the reference: the box at (160, 100), the pair put over it there
		PUT (160, 100), db, PSET
		IF nm THEN
			PUT (160 + dx, 100 + dy), ar, PSET
		ELSE
			PUT (160 + dx, 100 + dy), mk, AND: PUT (160 + dx, 100 + dy), ar, OR
		END IF
		GET (160, 100)-(160 + w - 1, 100 + h - 1), rf
		nw = 2 + (((w * 2 + 7) \ 8) * h + 1) \ 2
		FOR i = 0 TO nw: tb(i) = db(i): NEXT
		'----- (an odd byte count: the last word's high byte is past the data)
		IF (((w * 2 + 7) \ 8) * h) AND 1 THEN rf(nw - 1) = (rf(nw - 1) AND &HFF) OR (db(nw - 1) AND &HFF00)
		CALL Cop(6, tb(), ar(), mk(), 0, 0, dx, dy, nm)
		FOR i = 0 TO nw - 1
			IF tb(i) <> rf(i) THEN
				bad6 = bad6 + 1
				IF bad6 < 8 THEN PRINT #fh, "op 6 trial"; tr; "box"; w; h; "pair"; ow; oh; "at"; dx; dy; "nomask"; nm; "word"; i; HEX$(tb(i)); " ref "; HEX$(rf(i))
				EXIT FOR
			END IF
		NEXT
		LINE (0, 0)-(319, 199), 0, BF
	NEXT
	PRINT #fh, "op 6: 400 trials,"; bad6; "bad"
	'----- op 5: the merge
	FOR tr = 1 TO 400
		w = (INT(RND * 10) + 1) * 4: h = INT(RND * 30) + 1
		c0 = INT(RND * w): c1 = c0 + INT(RND * (w - c0)): r0 = INT(RND * h): r1 = r0 + INT(RND * (h - r0))
		CALL Fill(0, 0, w, h): GET (0, 0)-(w - 1, h - 1), db
		CALL Fill(0, 50, w, h): GET (0, 50)-(w - 1, 50 + h - 1), ar
		PUT (160, 100), db, PSET
		FOR y = r0 TO r1: FOR x = c0 TO c1: PSET (160 + x, 100 + y), POINT(x, 50 + y): NEXT: NEXT
		GET (160, 100)-(160 + w - 1, 100 + h - 1), rf
		nw = 2 + (((w * 2 + 7) \ 8) * h + 1) \ 2
		FOR i = 0 TO nw: tb(i) = db(i): NEXT
		'----- (an odd byte count: the last word's high byte is past the data)
		IF (((w * 2 + 7) \ 8) * h) AND 1 THEN rf(nw - 1) = (rf(nw - 1) AND &HFF) OR (db(nw - 1) AND &HFF00)
		CALL Cop(5, tb(), ar(), ar(), c0, c1, r0, r1, 1)
		FOR i = 0 TO nw - 1
			IF tb(i) <> rf(i) THEN
				bad5 = bad5 + 1
				IF bad5 < 8 THEN PRINT #fh, "op 5 trial"; tr; "box"; w; h; "rect"; c0; c1; r0; r1; "word"; i; HEX$(tb(i)); " ref "; HEX$(rf(i))
				EXIT FOR
			END IF
		NEXT
		LINE (0, 0)-(319, 199), 0, BF
	NEXT
	PRINT #fh, "op 5: 400 trials,"; bad5; "bad"
	CLOSE #fh
	SCREEN 0: WIDTH 80
	END

'----- Cop: one C3DCOMP call (nomask: mask segment 0)
SUB Cop (op, d(), s(), m(), w5, w6, w7, w8, nomask)
	pcm(0) = op: pcm(1) = VARSEG(d(0)): pcm(2) = VARPTR(d(0)): pcm(3) = VARSEG(s(0)): pcm(4) = VARPTR(s(0))
	IF op = 5 THEN
		pcm(5) = w5: pcm(6) = w6
	ELSEIF nomask THEN
		pcm(5) = 0: pcm(6) = 0
	ELSE
		pcm(5) = VARSEG(m(0)): pcm(6) = VARPTR(m(0))
	END IF
	pcm(7) = w7: pcm(8) = w8
	DEF SEG = VARSEG(ovl(0))
	CALL ABSOLUTE(BYVAL VARSEG(pcm(0)), BYVAL VARPTR(pcm(0)), VARPTR(ovl(0)))
	DEF SEG
END SUB

'----- Fill: random pixels in the w x h box at (x, y)
SUB Fill (x, y, w, h)
	DIM i, j
	FOR j = 0 TO h - 1: FOR i = 0 TO w - 1: PSET (x + i, y + j), INT(RND * 4): NEXT: NEXT
END SUB
