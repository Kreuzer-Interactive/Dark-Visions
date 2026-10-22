REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

' Integer 2^n. QB's ^ is a software float routine, ~1 ms per call on an FPU-less 486SX.
FUNCTION Pow2% (n)
 DIM p, k
 p = 1
 FOR k = 1 TO n: p = p + p: NEXT
 Pow2% = p
END FUNCTION

SUB Box (x, y, w, h, c)
 uglRectF back, x, y, x + w - 1, y + h - 1, CLNG(c)
END SUB

SUB Txt (x, y, s$, c)
 DIM xx, i, a, rown, coln, mask
 xx = x
 FOR i = 1 TO LEN(s$)
  a = ASC(MID$(s$, i, 1))
  IF a < 32 OR a > 126 THEN a = 63
  FOR rown = 0 TO 6
   mask = Pow2%(fw(a) - 1)
   FOR coln = 0 TO fw(a) - 1
    IF bits(a, rown) AND mask THEN uglPSet back, xx + coln, y + rown, CLNG(c)
    mask = mask \ 2
   NEXT
  NEXT
  xx = xx + fw(a) + 1
 NEXT
 CALL RefreshPointer
END SUB

FUNCTION Tw% (s$)
 DIM i, a, w
 FOR i = 1 TO LEN(s$)
  a = ASC(MID$(s$, i, 1)): IF a < 32 OR a > 126 THEN a = 63
  w = w + fw(a) + 1
 NEXT
 Tw% = w
END FUNCTION

SUB Wrap (x, y, s$, c, wide)
 DIM i, start, yy, line$, word$, ch$
 yy = y: word$ = "": line$ = ""
 FOR i = 1 TO LEN(s$) + 1
  ch$ = MID$(s$, i, 1)
  IF ch$ = " " OR i > LEN(s$) THEN
   IF Tw%(line$ + word$) > wide THEN CALL Txt(x, yy, line$, c): yy = yy + 10: line$ = ""
   line$ = line$ + word$ + " ": word$ = ""
  ELSE
   word$ = word$ + ch$
  END IF
 NEXT
 CALL Txt(x, yy, line$, c)
END SUB

SUB EnterRoom (n)
 DIM path$
 IF art <> 0 THEN uglDel art
 room = n: visited(n) = 1: selected = 0
 path$ = "VGA\RM" + RIGHT$("0" + LTRIM$(STR$(n)), 2) + ".BMP"
 art = uglNewBMPEx(UGL.MEM, UGL.8BIT, path$, BMPOPT.NO332)
 IF art = 0 THEN
  CALL Finish
  PRINT "Could not load "; path$
  END
 END IF
 CALL PrepareActors(n)
END SUB

SUB Icon (x, y, item)
 SELECT CASE item
 CASE 1, 10
  CALL Box(x + 1, y + 2, 15, 12, 246)
  uglLine back, x + 2, y + 3, x + 8, y + 8, 244
  uglLine back, x + 15, y + 3, x + 8, y + 8, 244
  IF item = 10 THEN CALL Box(x + 1, y + 2, 3, 12, 249)
 CASE 2, 3, 6, 8
  uglLine back, x + 3, y + 13, x + 12, y + 3, 246
  uglLine back, x + 4, y + 14, x + 13, y + 4, 245
  IF item = 6 THEN uglRect back, x + 10, y + 1, x + 15, y + 6, 246
  IF item = 8 THEN uglLine back, x + 9, y + 6, x + 7, y, 246: uglLine back, x + 12, y + 8, x + 16, y + 2, 246
 CASE 4
  CALL Box(x + 5, y + 1, 6, 14, 251): CALL Box(x + 5, y + 1, 6, 3, 246): CALL Box(x + 5, y + 12, 6, 3, 246)
 CASE 5
  CALL Box(x + 3, y + 6, 11, 9, 251): uglLine back, x + 13, y + 7, x + 17, y + 1, 245
 CASE 7
  uglRect back, x + 2, y + 2, x + 14, y + 13, 245
  uglRect back, x + 4, y + 4, x + 12, y + 11, 246
  uglRect back, x + 6, y + 6, x + 10, y + 9, 245
 CASE 9
  CALL Box(x + 5, y + 2, 7, 3, 246): CALL Box(x + 3, y + 5, 11, 10, 251): CALL Box(x + 5, y + 7, 2, 5, 247)
 END SELECT
END SUB

SUB DrawScene
 DIM i, h, col, x, idx, label$, w, s$
 IF modal AND (convperson OR carscene) THEN CALL DrawDialog: EXIT SUB
 uglClear back, 240
 uglPut back, 0, 0, art
 IF room = 1 OR room = 14 THEN
  FOR i = 0 TO 14
   x = (i * 43 + frame * 3) MOD 320
   w = 14 + (i * 29 + frame * 7) MOD 140
   uglLine back, x, w, x - 2, w + 5, 250
  NEXT
 END IF
 hover = Hit%(mx, my)
 ' People and visible exit plates are part of the scene, not baked into art.
 FOR i = 1 TO hn(room)
  h = (room - 1) * 12 + i
  IF hk(h) = 2 THEN
   IF inv(hv(h)) = 0 THEN CALL Icon((hx(h) + hr(h)) \ 2 - 8, (hy(h) + hb(h)) \ 2 - 8, hv(h))
  END IF
  IF hk(h) = 4 THEN
   IF flags(12) = 0 OR hv(h) = 1 OR hv(h) = 3 OR hv(h) = 8 THEN CALL Actor((hx(h) + hr(h) + 1) \ 2, hb(h), hv(h), 0)
  END IF
  IF hk(h) = 1 AND hy(h) >= 143 THEN
   col = 241: IF hover = h THEN col = 250
   CALL Box(hx(h), hy(h), hr(h) - hx(h) + 1, hb(h) - hy(h) + 1, col)
   label$ = names$(h)
   IF need(h) THEN IF flags(need(h)) = 0 THEN label$ = "* " + label$
   CALL Txt(hx(h) + 3, hy(h) + 2, label$, 246)
  ELSEIF hints AND modal = 0 THEN
   IF hk(h) <> 2 OR inv(hv(h)) = 0 THEN
    uglRect back, hx(h), hy(h), hr(h), hb(h), 251
   END IF
  END IF
 NEXT
 IF room = 14 AND flags(12) THEN
  CALL Actor(40, 141, 2, 0): CALL Actor(92, 141, 4, 0)
  CALL Actor(228, 141, 5, 0): CALL Actor(280, 141, 6, 0)
 END IF
 CALL Actor(px, py, 0, (px <> tx))
 CALL Box(0, 0, 320, 10, 240)
 CALL Txt(5, 2, rt$(room), 246)
 CALL Txt(269, 2, "J  M  H", 244)
 CALL Box(0, 154, 320, 46, 240)
 uglLine back, 0, 154, 319, 154, 245
 FOR i = 1 TO 3
  x = (i - 1) * 44: col = 241
  IF verb = i AND selected = 0 THEN col = 250
  CALL Box(x + 1, 156, 42, 11, col)
 NEXT
 CALL Txt(8, 158, "ACT", 247): CALL Txt(50, 158, "LOOK", 247): CALL Txt(94, 158, "TALK", 247)
 CALL Txt(138, 158, "JOURNAL", 246): CALL Txt(202, 158, "MAP", 246): CALL Txt(250, 158, "CLUES", 246)
 countinv = 0
 FOR i = 1 TO 10
  IF inv(i) THEN countinv = countinv + 1: invlist(countinv) = i
 NEXT
 FOR i = 1 TO 8
  x = (i - 1) * 36: idx = i + invpage * 8
  CALL Box(x + 1, 168, 34, 22, 241)
  IF idx <= countinv THEN
   IF selected = invlist(idx) THEN uglRect back, x + 1, 168, x + 34, 189, 246
   CALL Icon(x + 9, 171, invlist(idx))
  END IF
 NEXT
 CALL Txt(295, 175, ">", 246)
 s$ = "Explore Ravenhurst.  F5 save / F9 load"
 IF room = 1 AND flags(1) = 0 THEN s$ = "Knock at the lit front door."
 IF room = 1 AND flags(1) THEN s$ = "The front door is open."
 IF hover AND my < 154 THEN s$ = names$(hover)
 IF selected THEN
  s$ = "Use " + items$(selected)
  IF hover AND my < 154 THEN s$ = s$ + " on " + names$(hover)
 END IF
 IF my >= 168 AND my <= 189 AND mx < 288 THEN
  idx = mx \ 36 + 1 + invpage * 8
  IF idx <= countinv THEN s$ = items$(invlist(idx))
 END IF
 CALL Txt(4, 192, s$, 246)
 IF modal THEN CALL DrawDialog
END SUB




FUNCTION Hit% (x, y)
 DIM i, h
 Hit% = 0
 FOR i = 1 TO hn(room)
  h = (room - 1) * 12 + i
  IF x >= hx(h) AND x <= hr(h) AND y >= hy(h) AND y <= hb(h) THEN
   IF hk(h) <> 4 OR flags(12) = 0 OR hv(h) = 1 OR hv(h) = 3 OR hv(h) = 8 THEN Hit% = h: EXIT FUNCTION
  END IF
 NEXT
END FUNCTION

SUB Finish
 DIM i
 CALL EndTalk
 FOR i = 0 TO 8
  IF sprites(i) <> 0 THEN uglDel sprites(i)
 NEXT
 CALL EndPointer
 IF art <> 0 THEN uglDel art
 IF back <> 0 THEN uglDel back
 uglRestore
 uglEnd
END SUB
