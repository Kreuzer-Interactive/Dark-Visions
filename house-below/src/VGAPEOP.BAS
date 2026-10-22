REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'
REM $STATIC
DIM SHARED stageH(16), stageX(16), stageY(16), stageL(16), stageR(16)
DIM SHARED actorW(0 TO 8), actorH(0 TO 8)
REM $DYNAMIC

ActorDataError:
 ioerr = ERR
 RESUME NEXT

SUB InitActors
 DIM n
 ON ERROR GOTO ActorDataError
 ioerr = 0
 OPEN "VGA\STAGE.DAT" FOR INPUT AS #1
 IF ioerr THEN PRINT "Missing VGA\STAGE.DAT.": END
 FOR n = 1 TO 16
  INPUT #1, stageH(n), stageX(n), stageY(n), stageL(n), stageR(n)
 NEXT
 CLOSE #1
 IF ioerr THEN PRINT "Invalid character staging data.": END
END SUB

SUB PrepareActors (n)
 DIM i, j, h, feet, x, y, sx, sy, inset, path$, sourceDC AS LONG, col AS LONG
 ' Size once on room entry. Normal frames use the same fast masked blit.
 px = stageX(n): py = stageY(n): tx = px
 FOR i = 0 TO 8
  IF sprites(i) <> 0 THEN uglDel sprites(i): sprites(i) = 0
 NEXT
 FOR i = 0 TO 8
  feet = py
  IF i > 0 AND i <> 7 THEN
   feet = 160
   IF n = 14 THEN feet = 168
   FOR j = 1 TO hn(n)
    h = (n - 1) * 12 + j
    IF hk(h) = 4 AND hv(h) = i THEN feet = hb(h)
   NEXT
  END IF
  actorH(i) = stageH(n) + feet - py
  actorW(i) = 2 * ((actorH(i) * 24 + 44) \ 88)
  path$ = "VGA\CHAR" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".BMP"
  sourceDC = uglNewBMPEx(UGL.MEM, UGL.8BIT, path$, BMPOPT.NO332)
  IF sourceDC = 0 THEN CALL Finish: PRINT "Missing character art: "; path$: END
  ' uGL memory surfaces MUST have widths divisible by eight. Keep a 48-pixel
  ' canvas, and center the narrower scaled image inside its transparent border.
  sprites(i) = uglNew(UGL.MEM, UGL.8BIT, 48, actorH(i))
  IF sprites(i) = 0 THEN uglDel sourceDC: CALL Finish: PRINT "Not enough memory for characters.": END
  uglClear sprites(i), 227
  ' Nearest-neighbor sampling preserves palette/mask indices and works with
  ' the 48-wide source. This is outside the frame loop, including all divides.
  inset = (48 - actorW(i)) \ 2
  FOR y = 0 TO actorH(i) - 1
   sy = y * 88 \ actorH(i)
   FOR x = 0 TO actorW(i) - 1
    sx = x * 48 \ actorW(i)
    col = uglPGet(sourceDC, sx, sy)
    uglPSet sprites(i), inset + x, y, col
   NEXT
  NEXT
  uglDel sourceDC
 NEXT
 ' Keep visible heads/shoulders clickable, with no center drift on revisits.
 FOR j = 1 TO hn(n)
  h = (n - 1) * 12 + j
  IF hk(h) = 4 THEN
   i = hv(h): x = (hx(h) + hr(h) + 1) \ 2
   hx(h) = x - actorW(i) \ 2: hr(h) = hx(h) + actorW(i) - 1
   hy(h) = hb(h) - actorH(i) + 1
  END IF
 NEXT
END SUB

SUB Actor (x, y, who, stepn)
 DIM which, leftx, topy, wide, faceleft
 which = who
 IF who = 0 AND stepn AND (frame \ 5) MOD 2 THEN which = 7
 leftx = x - 24: topy = y - actorH(which) + 1
 wide = actorW(which) \ 3
 uglLine back, x - wide, y, x + wide, y, 240
 faceleft = (who = 0 AND tx < px)
 ' James's master looks right. Turn toward the player's current position.
 IF who = 1 THEN faceleft = (px < x)
 IF faceleft THEN
  uglPutMskFlip back, leftx, topy, UGL.HFLIP, sprites(which)
 ELSE
  uglPutMsk back, leftx, topy, sprites(which)
 END IF
END SUB

SUB WalkPlayer
 IF tx < stageL(room) THEN tx = stageL(room)
 IF tx > stageR(room) THEN tx = stageR(room)
 IF px < tx THEN px = px + 2: IF px > tx THEN px = tx
 IF px > tx THEN px = px - 2: IF px < tx THEN px = tx
END SUB

SUB CheckActors
 DIM x, y, col, topy, bottomy, i, h, centerx
 ' Inspect actual rendered pixels, including the scaled sprite's feet.
 uglClear back, 227: CALL Actor(px, py, 0, 0)
 topy = 240: bottomy = 0
 FOR y = 12 TO 183
  FOR x = 0 TO 319
   col = uglPGet(back, x, y)
   IF col <> 227 AND col <> 240 THEN
    IF y < topy THEN topy = y
    IF y > bottomy THEN bottomy = y
   END IF
  NEXT
 NEXT
 CALL Check(bottomy - topy >= 70 AND ABS(bottomy - py) <= 2, "human scale and planted feet in room " + STR$(room))
 FOR i = 1 TO hn(room)
  h = (room - 1) * 12 + i
  IF hk(h) = 4 THEN
   centerx = (hx(h) + hr(h) + 1) \ 2
   CALL Check(Hit%(centerx, hy(h) + 8) = h, "enlarged head is clickable: " + names$(h))
  END IF
 NEXT
END SUB
