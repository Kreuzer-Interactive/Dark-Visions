REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'
TYPE RegType
 ax AS INTEGER
 bx AS INTEGER
 cx AS INTEGER
 dx AS INTEGER
 bp AS INTEGER
 si AS INTEGER
 di AS INTEGER
 flags AS INTEGER
END TYPE
DECLARE SUB INTERRUPT (intnum AS INTEGER, inreg AS RegType, outreg AS RegType)
DECLARE SUB UpdatePointer ()
DIM SHARED pointerDC AS LONG, pointerSave AS LONG, pointerKind
DIM SHARED pointerDrawn, pointerX, pointerY

SUB InitPointer
 DIM r AS RegType, o AS RegType, mi, a, b, c, d, segm AS LONG, offs AS LONG
 ' Use the original game's INT 33h position polling, not a mickey callback.
 mouseok = 0: mi = &H33
 DEF SEG = 0
 a = PEEK(&HCC): b = PEEK(&HCD): c = PEEK(&HCE): d = PEEK(&HCF)
 DEF SEG
 IF a OR b OR c OR d THEN
  segm = c + d * 256&: offs = a + b * 256&
  IF segm > 32767 THEN segm = segm - 65536
  IF offs > 32767 THEN offs = offs - 65536
  DEF SEG = segm: a = PEEK(offs): DEF SEG
  IF a <> 0 AND a <> &HCF THEN
   r.ax = 0: CALL INTERRUPT(mi, r, o)
   mouseok = (o.ax <> 0)
  END IF
 END IF
 IF mouseok THEN
  r.ax = 2: CALL INTERRUPT(mi, r, o)
  ' Low-resolution DOS mouse coordinates use twice the screen width.
  r.ax = 7: r.cx = 0: r.dx = 639: CALL INTERRUPT(mi, r, o)
  r.ax = 8: r.cx = 0: r.dx = 199: CALL INTERRUPT(mi, r, o)
  CALL PositionPointer(mx, my)
 END IF
 pointerDC = uglNew(UGL.MEM, UGL.8BIT, 16, 16)
 pointerSave = uglNew(UGL.MEM, UGL.8BIT, 16, 16)
END SUB

SUB EndPointer
 IF pointerDC <> 0 THEN uglDel pointerDC: pointerDC = 0
 IF pointerSave <> 0 THEN uglDel pointerSave: pointerSave = 0
 pointerDrawn = 0
END SUB

SUB ReadPointer (x, y, buttons)
 DIM r AS RegType, o AS RegType, mi
 buttons = 0
 IF NOT mouseok THEN EXIT SUB
 mi = &H33: r.ax = 3: CALL INTERRUPT(mi, r, o)
 x = o.cx \ 2: y = o.dx: buttons = o.bx
 IF x < 0 THEN x = 0
 IF x > 319 THEN x = 319
 IF y < 0 THEN y = 0
 IF y > 199 THEN y = 199
END SUB

SUB PositionPointer (x, y)
 DIM r AS RegType, o AS RegType, mi
 IF NOT mouseok THEN EXIT SUB
 mi = &H33: r.ax = 4: r.cx = x * 2: r.dx = y
 CALL INTERRUPT(mi, r, o)
END SUB

SUB UpdatePointer
 DIM ox, oy, savedDC AS LONG
 savedDC = back: ox = mx: oy = my
 back = pointerDC: mx = 5: my = 5
 uglClear back, 227
 CALL Cursor
 back = savedDC: mx = ox: my = oy
END SUB

SUB RefreshPointer
 DIM x, y, buttons, kind
 IF pointerDC = 0 OR pointerSave = 0 THEN EXIT SUB
 x = mx: y = my: CALL ReadPointer(x, y, buttons)
 kind = verb: IF hover THEN kind = kind + 3
 IF selected THEN kind = 7
 IF convperson THEN kind = 8: IF hover THEN kind = 9
 IF pointerDrawn AND x = pointerX AND y = pointerY AND kind = pointerKind THEN EXIT SUB
 IF pointerDrawn THEN uglPut video, pointerX - 5, pointerY - 5, pointerSave
 IF kind <> pointerKind THEN CALL UpdatePointer: pointerKind = kind
 uglGet video, x - 5, y - 5, pointerSave
 uglPutMsk video, x - 5, y - 5, pointerDC
 pointerX = x: pointerY = y: pointerDrawn = -1
END SUB

SUB Present
 DIM stamp AS SINGLE
 ' Keep polling while waiting; only the small cursor rectangle is redrawn.
 stamp = TIMER
 DO WHILE (INP(&H3DA) AND 8) <> 0
  CALL RefreshPointer
  IF TIMER <> stamp THEN EXIT DO
 LOOP
 DO WHILE (INP(&H3DA) AND 8) = 0
  CALL RefreshPointer
  IF TIMER <> stamp THEN EXIT DO
 LOOP
 uglPut video, 0, 0, back
 pointerDrawn = 0
 IF pointerDC = 0 OR pointerSave = 0 THEN
  CALL Cursor: uglPut video, 0, 0, back
 ELSE
  CALL RefreshPointer
 END IF
END SUB

SUB Cursor
 DIM col
 col = 247: IF hover THEN col = 255
 IF convperson THEN
  uglLine back, mx + 1, my + 1, mx + 1, my + 10, 240
  uglLine back, mx, my, mx, my + 9, CLNG(col)
  uglLine back, mx, my, mx + 6, my + 6, CLNG(col)
  uglLine back, mx, my + 7, mx + 6, my + 6, CLNG(col)
 ELSEIF selected THEN
  uglRect back, mx - 3, my - 3, mx + 3, my + 3, 246
  uglLine back, mx - 5, my, mx + 5, my, 247
 ELSEIF verb = 2 THEN
  uglRect back, mx - 3, my - 3, mx + 3, my + 2, CLNG(col)
  uglLine back, mx + 3, my + 2, mx + 6, my + 5, CLNG(col)
 ELSEIF verb = 3 THEN
  uglRect back, mx - 4, my - 4, mx + 4, my + 2, CLNG(col)
  uglLine back, mx - 1, my + 2, mx - 3, my + 5, CLNG(col)
 ELSE
  uglLine back, mx + 1, my + 1, mx + 1, my + 10, 240
  uglLine back, mx, my, mx, my + 9, CLNG(col)
  uglLine back, mx, my, mx + 6, my + 6, CLNG(col)
  uglLine back, mx, my + 7, mx + 6, my + 6, CLNG(col)
 END IF
END SUB

SUB Poll
 DIM i, h, buttons, warped, mi, r AS RegType, o AS RegType
 warped = 0
 click = 0: rightclick = 0: keys$ = INKEY$
 ' Extended scan codes can equal uppercase letters (F9 and arrow keys).
 IF LEN(keys$) = 1 THEN keys$ = LCASE$(keys$)
 CALL ReadPointer(mx, my, buttons)
 IF (buttons AND 1) AND oldleft = 0 THEN click = -1
 IF (buttons AND 2) AND oldright = 0 THEN rightclick = -1
 oldleft = buttons AND 1: oldright = buttons AND 2
 ' Driver press counts also retain clicks shorter than one scene redraw.
 IF mouseok THEN
  mi = &H33: r.ax = 5: r.bx = 0: CALL INTERRUPT(mi, r, o)
  IF o.bx THEN click = -1: mx = o.cx \ 2: my = o.dx
  r.ax = 5: r.bx = 1: CALL INTERRUPT(mi, r, o)
  IF o.bx THEN
   rightclick = -1
   IF NOT click THEN mx = o.cx \ 2: my = o.dx
  END IF
 END IF
 IF keys$ = CHR$(13) OR keys$ = " " THEN click = -1
 IF keys$ = CHR$(0) + CHR$(75) THEN mx = mx - 5: warped = -1
 IF keys$ = CHR$(0) + CHR$(77) THEN mx = mx + 5: warped = -1
 ' In a conversation Up/Down step the highlighted ticket instead (Pick handles them).
 IF NOT (modal AND convperson) THEN
  IF keys$ = CHR$(0) + CHR$(72) THEN my = my - 5: warped = -1
  IF keys$ = CHR$(0) + CHR$(80) THEN my = my + 5: warped = -1
 END IF
 IF keys$ = CHR$(9) AND modal = 0 THEN
  h = Hit%(mx, my): i = h - (room - 1) * 12 + 1
  IF i < 1 OR i > hn(room) THEN i = 1
  h = (room - 1) * 12 + i
  warped = -1
  mx = (hx(h) + hr(h)) \ 2: my = (hy(h) + hb(h)) \ 2
 END IF
 IF mx < 0 THEN mx = 0
 IF mx > 319 THEN mx = 319
 IF my < 0 THEN my = 0
 IF my > 199 THEN my = 199
 ' Only navigation keys warp the driver. Ordinary keys never reset its position.
 IF warped THEN CALL PositionPointer(mx, my)
 CALL RefreshPointer
END SUB
