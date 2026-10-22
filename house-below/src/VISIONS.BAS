REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'
DIM pal(0 TO 255) AS tRGB
DIM rt$(16)
DIM rd$(16)
DIM hn(16)
DIM visited(16)
DIM hx(192)
DIM hy(192)
DIM hr(192)
DIM hb(192)
DIM hk(192)
DIM hv(192)
DIM need(192)
DIM names$(192)
DIM descs$(192)
DIM fw(32 TO 126)
DIM bits(32 TO 126, 0 TO 6)
DIM flags(32)
DIM inv(16)
DIM items$(16)
DIM invlist(16)
DIM choices$(4)
DIM learned(14)
DIM topicid(6), topictext$(6), topicsource$(6)
DIM rowid(3), rowsource$(3)
DIM sprites(0 TO 8) AS LONG
ON ERROR GOTO FileError

testing = (UCASE$(COMMAND$) = "/TEST")
OPEN "VGA\FONT.DAT" FOR INPUT AS #1
IF ioerr THEN PRINT "Missing VGA\FONT.DAT. Run from the SRC directory.": END
FOR i = 32 TO 126
 INPUT #1, fw(i)
 FOR j = 0 TO 6: INPUT #1, bits(i, j): NEXT
NEXT
CLOSE #1
OPEN "VGA\WORLD.DAT" FOR INPUT AS #1
IF ioerr THEN PRINT "Missing VGA\WORLD.DAT.": END
FOR r = 1 TO 16
 INPUT #1, rt$(r), rd$(r), hn(r)
 FOR j = 1 TO hn(r)
  h = (r - 1) * 12 + j
  INPUT #1, hx(h), hy(h), hr(h), hb(h), hk(h), hv(h), need(h), names$(h), descs$(h)
 NEXT
NEXT
CLOSE #1
IF ioerr THEN PRINT "Invalid game data.": END
CALL InitActors
items$(1) = "Invitation": items$(2) = "Hairpin": items$(3) = "Clock hand"
items$(4) = "Fuse": items$(5) = "Oil can": items$(6) = "Ward key"
items$(7) = "Rope": items$(8) = "Tuning fork": items$(9) = "Reversal vial"
items$(10) = "Evidence ledger"
IF NOT uglInit THEN PRINT "uGL initialization failed.": END
video = uglSetVideoDC(UGL.8BIT, 320, 200, 1)
IF video = 0 THEN
 uglEnd
 PRINT "Standard VGA mode 13h (320x200x256) could not be set."
 END
END IF
back = uglNew(UGL.MEM, UGL.8BIT, 320, 200)
IF back = 0 THEN uglRestore: uglEnd: PRINT "Not enough conventional memory.": END
DIM ps AS STRING * 1024
OPEN "VGA\RM01.BMP" FOR BINARY AS #1
GET #1, 55, ps: CLOSE #1
FOR i = 0 TO 255
 pal(i).blue = MID$(ps, i * 4 + 1, 1)
 pal(i).green = MID$(ps, i * 4 + 2, 1)
 pal(i).red = MID$(ps, i * 4 + 3, 1)
NEXT
uglPalSetBuff 0, 256, pal(0)
mx = 160: my = 130: inv(1) = 1: running = -1: verb = 1
CALL InitPointer
CALL EnterRoom(1)
IF testing THEN CALL TestGame: CALL Finish: END
CALL Opening
DO WHILE running
 CALL Poll
 IF LEN(keys$) = 1 AND keys$ >= "1" AND keys$ <= "8" THEN
  j = VAL(keys$) + invpage * 8
  IF j <= countinv THEN selected = invlist(j): verb = 1
 END IF
 IF keys$ = "i" THEN invpage = 1 - invpage
 IF rightclick THEN
  IF selected THEN selected = 0 ELSE verb = verb MOD 3 + 1
 END IF
 IF keys$ = "j" THEN CALL Journal
 IF keys$ = "m" THEN CALL MapPage
 IF keys$ = "h" THEN hints = NOT hints
 IF keys$ = "s" THEN soundon = NOT soundon
 IF keys$ = CHR$(0) + CHR$(63) THEN
  slot = Pick%("SAVE GAME", "Choose a slot. Existing progress in that slot is replaced.", "Slot 1", "Slot 2", "Slot 3")
  IF slot THEN CALL SaveGame(slot)
 END IF
 IF keys$ = CHR$(0) + CHR$(67) THEN
  slot = Pick%("LOAD GAME", "Choose a saved journey. ESC keeps your current progress.", "Slot 1", "Slot 2", "Slot 3")
  IF slot THEN CALL LoadGame(slot)
 END IF
 IF keys$ = CHR$(27) THEN
  IF selected THEN
   selected = 0
  ELSE
   q = Pick%("PAUSE", "Dark Visions - The House Below", "Continue", "Controls", "Quit to DOS")
   IF q = 2 THEN CALL Say("CONTROLS", "ACT / LOOK / TALK: click a verb. Inventory: click item then target. Right click: cancel or cycle. TAB: next hotspot. Arrow keys: cursor. ENTER: activate. J journal, M map, H " + _
    "hotspots, S sound, F5 save, F9 load.")
   IF q = 3 THEN running = 0
  END IF
 END IF
 IF click THEN
  IF my >= 154 AND my <= 166 THEN
   IF mx < 43 THEN verb = 1: selected = 0
   IF mx >= 43 AND mx < 88 THEN verb = 2: selected = 0
   IF mx >= 88 AND mx < 132 THEN verb = 3: selected = 0
   IF mx >= 132 AND mx < 198 THEN CALL Journal
   IF mx >= 198 AND mx < 245 THEN CALL MapPage
   IF mx >= 245 THEN hints = NOT hints
  ELSEIF my >= 167 AND my <= 190 THEN
   IF mx >= 288 THEN
    invpage = 1 - invpage
   ELSE
    j = mx \ 36 + 1 + invpage * 8
    IF j <= countinv THEN selected = invlist(j): verb = 1
   END IF
  ELSEIF my < 154 THEN
   h = Hit%(mx, my)
   IF h THEN
    CALL Act(h)
   ELSE
    IF verb = 2 THEN CALL Say(rt$(room), rd$(room)) ELSE tx = mx
   END IF
  END IF
 END IF
 ' Animate at half the display rate; read input every display frame.
 stepnow = 1 - stepnow
 IF stepnow THEN
  CALL WalkPlayer
  frame = (frame + 1) MOD 120
 END IF
 CALL DrawScene: CALL Present
LOOP
CALL Finish
END

FileError:
ioerr = ERR
RESUME NEXT

