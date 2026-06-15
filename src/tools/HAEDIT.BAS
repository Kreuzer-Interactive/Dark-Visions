'=====================================================================
' HAEDIT.BAS - Dark Visions hit-area (.PAC) editor
'
' Loads a room .PIC (CGA SCREEN 1, 320x200) into SCREEN 12 (640x480,
' 16 colour) at 1:1 in the top-left, leaving the rest of the screen
' for data: a list of all 25 objects on the right (colour, name, verb,
' direction, point count) and the selected object's detail + help at
' the bottom-left.  The .PAC hit points are overlaid as bright markers,
' one colour per object; the selected object's points show white.
'
' Drag the LEFT button to paint hit points for the selected object;
' the RIGHT button erases the point under the cursor.  Click an object
' row in the list (or [ ] / 1-9) to pick it.  Hold SPACE to peek the
' bare picture under the markers.  E edits the selected object's text;
' S saves the .PAC in the game's exact format.
'
' Run it from the folder that holds the .PIC/.PAC files.  Build (Q: =
' QB45 toolchain):  BC HAEDIT /O ;   LINK HAEDIT ,,, Q:\QB.LIB ;
' and run with a mouse driver loaded (MOUSE.COM).
'=====================================================================
DEFINT A-Z

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
DECLARE FUNCTION cgapix (x, y)

CONST MAXH = 256, MAXO = 25

DIM SHARED reg AS RegType
DIM SHARED pic$
DIM SHARED co, pa1, pa2, pa3, pal(3)
DIM SHARED ox(MAXH), oy(MAXH), oi(MAXH), nhot
DIM SHARED df$(MAXO), ms$(MAXO), ky$(MAXO), bs(MAXO), cs(MAXO), st(MAXO), tg$(MAXO)
DIM SHARED basef$, curobj, dirty
DIM SHARED mcol(9)
DIM SHARED cbuf(120), oxg, oyg, cdrawn
DIM SHARED peeking
DIM SHARED pkt AS SINGLE

mcol(0) = 12: mcol(1) = 10: mcol(2) = 14: mcol(3) = 11: mcol(4) = 13
mcol(5) = 9: mcol(6) = 4: mcol(7) = 2: mcol(8) = 1: mcol(9) = 6
curobj = 1

GOSUB pickfile
GOSUB loadpac
GOSUB loadpic
GOSUB setupmouse

SCREEN 12
GOSUB drawimage
LINE (321, 0)-(321, 479), 8
LINE (0, 201)-(321, 201), 8
GOSUB drawhots
GOSUB drawpanel
GOSUB status

DO
   reg.ax = 3: CALL INTERRUPT(&H33, reg, reg)
   sx = reg.cx: sy = reg.dx
   IF sx < 0 THEN sx = 0
   IF sx > 639 THEN sx = 639
   IF sy < 0 THEN sy = 0
   IF sy > 479 THEN sy = 479
   lb = (reg.bx AND 1): rb = (reg.bx AND 2)

   inart = 0: IF sx < 320 AND sy < 200 THEN inart = -1

   IF inart THEN
      cgx = (sx \ 4) * 4 + 2
      cgy = (sy \ 4) * 4 + 2
      IF cgx > 318 THEN cgx = 318
      IF cgy > 198 THEN cgy = 198
      IF cgx <> ocgx OR cgy <> ocgy OR cdrawn = 0 THEN
         GOSUB drawcross
         ocgx = cgx: ocgy = cgy
         COLOR 15: LOCATE 30, 1: PRINT "grid"; cgx; ","; cgy; "   ";
      END IF
      IF lb THEN GOSUB paintpt
      IF rb THEN GOSUB erasept
   ELSE
      IF cdrawn THEN GOSUB eraseCross
      IF lb <> 0 AND plb = 0 AND sx >= 322 THEN
         clo = sy \ 16
         IF clo >= 1 AND clo <= MAXO THEN curobj = clo: GOSUB objchanged
      END IF
   END IF
   plb = lb

   k$ = INKEY$
   IF k$ <> "" THEN GOSUB handlekey

   IF peeking AND TIMER > pkt THEN GOSUB unpeek
LOOP UNTIL quit

SCREEN 0: WIDTH 80: CLS
PRINT "Done."
END

'--- choose which room .pic to edit
pickfile:
   SCREEN 0: WIDTH 80: CLS
   PRINT "=== Dark Visions hit-area editor ==="
   PRINT
   PRINT "Picture files in this folder:"
   FILES "*.PIC"
   PRINT
   INPUT "Edit which room (base name, e.g. room1): ", basef$
   IF INSTR(basef$, ".") > 0 THEN basef$ = LEFT$(basef$, INSTR(basef$, ".") - 1)
   RETURN

'--- read palette, hit points and object info from the .pac
loadpac:
   OPEN basef$ + ".pac" FOR INPUT AS #1
   INPUT #1, co, pa1, pa2, pa3
   pal(0) = co: pal(1) = pa1: pal(2) = pa2: pal(3) = pa3
   nhot = 0
   FOR i = 1 TO 257
      INPUT #1, tx, ty, ti
      IF ty = 0 THEN EXIT FOR
      nhot = nhot + 1
      ox(nhot) = tx: oy(nhot) = ty: oi(nhot) = ti
   NEXT
   FOR i = 1 TO MAXO
      INPUT #1, df$(i), ms$(i), ky$(i)
      INPUT #1, bs(i), cs(i), st(i), tg$(i)
   NEXT
   CLOSE #1
   RETURN

'--- read raw .pic bytes (7-byte BSAVE header + CGA B800 dump)
loadpic:
   OPEN basef$ + ".pic" FOR BINARY AS #1
   pic$ = SPACE$(LOF(1))
   GET #1, 1, pic$
   CLOSE #1
   RETURN

'--- make sure a mouse driver is present
setupmouse:
   reg.ax = 0: CALL INTERRUPT(&H33, reg, reg)
   IF reg.ax = 0 THEN
      SCREEN 0: WIDTH 80
      PRINT "No mouse driver found - load MOUSE.COM and try again."
      END
   END IF
   RETURN

'--- slow first draw: decode CGA into SCREEN 12 at 1:1
drawimage:
   FOR y = 0 TO 199
      FOR x = 0 TO 319
         PSET (x, y), pal(cgapix(x, y))
      NEXT
   NEXT
   RETURN

'--- draw every hit-point marker
drawhots:
   FOR i = 1 TO nhot
      GOSUB drawmark
   NEXT
   RETURN

'--- draw the 2x2 marker for hotspot i (selected object shows white)
drawmark:
   px = ox(i): py = oy(i)
   IF oi(i) = curobj THEN mc = 15 ELSE mc = mcol(oi(i) MOD 10)
   LINE (px, py)-(px + 1, py + 1), mc, BF
   RETURN

'--- repaint the bare picture over hotspot i's marker footprint
restoremark:
   px = ox(i): py = oy(i)
   FOR yy = py - 1 TO py + 2
      FOR xx = px - 1 TO px + 2
         IF xx >= 0 AND xx <= 319 AND yy >= 0 AND yy <= 199 THEN PSET (xx, yy), pal(cgapix(xx, yy))
      NEXT
   NEXT
   RETURN

'--- box cursor on the snapped grid point, with save-under
drawcross:
   IF cdrawn THEN PUT (oxg, oyg), cbuf, PSET
   gx1 = cgx - 2: IF gx1 < 0 THEN gx1 = 0
   gy1 = cgy - 2: IF gy1 < 0 THEN gy1 = 0
   gx2 = cgx + 2: IF gx2 > 639 THEN gx2 = 639
   gy2 = cgy + 2: IF gy2 > 479 THEN gy2 = 479
   GET (gx1, gy1)-(gx2, gy2), cbuf
   oxg = gx1: oyg = gy1: cdrawn = 1
   LINE (cgx - 2, cgy - 2)-(cgx + 2, cgy + 2), 15, B
   RETURN

eraseCross:
   IF cdrawn THEN PUT (oxg, oyg), cbuf, PSET
   cdrawn = 0
   RETURN

'--- paint a hit point at the cursor for the current object
paintpt:
   FOR i = 1 TO nhot
      IF ox(i) = cgx AND oy(i) = cgy AND oi(i) = curobj THEN RETURN
   NEXT
   IF nhot >= MAXH THEN RETURN
   nhot = nhot + 1
   ox(nhot) = cgx: oy(nhot) = cgy: oi(nhot) = curobj
   dirty = 1
   GOSUB eraseCross
   i = nhot: GOSUB drawmark
   COLOR 12: LOCATE 14, 22: PRINT "*UNSAVED*";
   RETURN

'--- erase the hit point under the cursor
erasept:
   FOR i = nhot TO 1 STEP -1
      IF ox(i) = cgx AND oy(i) = cgy THEN
         GOSUB eraseCross
         GOSUB restoremark
         FOR j = i TO nhot - 1
            ox(j) = ox(j + 1): oy(j) = oy(j + 1): oi(j) = oi(j + 1)
         NEXT
         nhot = nhot - 1
         dirty = 1
         GOSUB drawhots
         GOSUB drawpanel
         GOSUB status
         RETURN
      END IF
   NEXT
   RETURN

'--- keyboard handling
handlekey:
   SELECT CASE k$
      CASE " "
         GOSUB dopeek
      CASE "["
         curobj = curobj - 1
         IF curobj < 1 THEN curobj = MAXO
         GOSUB objchanged
      CASE "]"
         curobj = curobj + 1
         IF curobj > MAXO THEN curobj = 1
         GOSUB objchanged
      CASE "1" TO "9"
         curobj = VAL(k$)
         GOSUB objchanged
      CASE "e", "E"
         GOSUB editinfo
      CASE "s", "S"
         GOSUB savepac
      CASE CHR$(27)
         quit = 1
   END SELECT
   RETURN

objchanged:
   GOSUB eraseCross
   GOSUB drawhots
   GOSUB drawpanel
   GOSUB status
   RETURN

'--- SPACE held: show the bare picture under the markers
dopeek:
   pkt = TIMER + .35
   IF peeking = 0 THEN
      GOSUB eraseCross
      FOR i = 1 TO nhot
         GOSUB restoremark
      NEXT
      peeking = 1
   END IF
   RETURN

unpeek:
   peeking = 0
   GOSUB eraseCross
   GOSUB drawhots
   RETURN

'--- list of all 25 objects (right panel)
drawpanel:
   LINE (323, 0)-(639, 479), 0, BF
   COLOR 7: LOCATE 1, 42: PRINT " # object    v tg  pts";
   FOR o = 1 TO MAXO
      pcnt = 0
      FOR i = 1 TO nhot
         IF oi(i) = o THEN pcnt = pcnt + 1
      NEXT
      COLOR mcol(o MOD 10)
      s$ = " ": IF o = curobj THEN s$ = ">"
      LOCATE o + 1, 42
      PRINT s$; RIGHT$(" " + LTRIM$(STR$(o)), 2); " "; LEFT$(df$(o) + SPACE$(9), 9); " "; LEFT$(ky$(o) + " ", 1); " "; LEFT$(tg$(o) + SPACE$(3), 3); pcnt;
   NEXT
   RETURN

'--- selected object detail + help (bottom-left, under the picture)
status:
   LINE (0, 204)-(320, 479), 0, BF
   COLOR 15: LOCATE 14, 1: PRINT basef$; ".pac";
   IF dirty THEN COLOR 12: LOCATE 14, 22: PRINT "*UNSAVED*";
   COLOR mcol(curobj MOD 10)
   LOCATE 15, 1: PRINT "object"; curobj; "  points";
   pcnt = 0
   FOR i = 1 TO nhot
      IF oi(i) = curobj THEN pcnt = pcnt + 1
   NEXT
   PRINT pcnt;
   LOCATE 16, 1: PRINT "df="; LEFT$(df$(curobj), 33);
   LOCATE 17, 1: PRINT "ms="; LEFT$(ms$(curobj), 33);
   LOCATE 18, 1: PRINT "ky="; ky$(curobj); " tg="; tg$(curobj);
   LOCATE 19, 1: PRINT "bs="; bs(curobj); " cs="; cs(curobj); " st="; st(curobj);
   COLOR 7
   LOCATE 21, 1: PRINT "LMB paint   RMB erase";
   LOCATE 22, 1: PRINT "click list / [ ] / 1-9: object";
   LOCATE 23, 1: PRINT "E edit text   SPACE peek";
   LOCATE 24, 1: PRINT "S save   ESC quit";
   RETURN

'--- edit the selected object's text fields
editinfo:
   GOSUB eraseCross
   o = curobj
   LINE (0, 400)-(639, 479), 0, BF
   COLOR 15
   LOCATE 26, 1: PRINT "Edit object"; o; " -- press ENTER alone to keep the [current] value";
   LOCATE 28, 1: PRINT "df$ target room ["; df$(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN df$(o) = n$
   LOCATE 28, 1: PRINT SPACE$(79);
   LOCATE 28, 1: PRINT "ms$ message ["; ms$(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN ms$(o) = n$
   LOCATE 28, 1: PRINT SPACE$(79);
   LOCATE 28, 1: PRINT "ky$ verb a/l/g/u ["; ky$(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN ky$(o) = n$
   LOCATE 28, 1: PRINT SPACE$(79);
   LOCATE 28, 1: PRINT "tg$ dir/flag wn ws we ww f.. ["; tg$(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN tg$(o) = n$
   LOCATE 28, 1: PRINT SPACE$(79);
   LOCATE 28, 1: PRINT "bs needs-item slot ["; bs(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN bs(o) = VAL(n$)
   LOCATE 28, 1: PRINT SPACE$(79);
   LOCATE 28, 1: PRINT "cs needs-state slot ["; cs(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN cs(o) = VAL(n$)
   LOCATE 28, 1: PRINT SPACE$(79);
   LOCATE 28, 1: PRINT "st sets-state slot ["; st(o); "]: ";: LINE INPUT n$: IF n$ <> "" THEN st(o) = VAL(n$)
   dirty = 1
   GOSUB drawpanel
   GOSUB status
   RETURN

'--- write the .pac back in the game's exact format
savepac:
   OPEN basef$ + ".pac" FOR OUTPUT AS #2
   WRITE #2, co, pa1, pa2, pa3
   FOR i = 1 TO nhot
      WRITE #2, ox(i), oy(i), oi(i)
   NEXT
   WRITE #2, 0, 0, 0
   FOR i = 1 TO MAXO
      WRITE #2, df$(i), ms$(i), ky$(i), bs(i), cs(i), st(i), tg$(i)
   NEXT
   CLOSE #2
   dirty = 0
   GOSUB status
   COLOR 10: LOCATE 25, 1: PRINT "Saved "; basef$; ".pac";
   RETURN

'--- decode one CGA SCREEN 1 pixel (x 0-319, y 0-199) -> colour index 0-3
FUNCTION cgapix (x, y)
   bank = y AND 1
   row = y \ 2
   ofs = 7 + bank * 8192 + row * 80 + (x \ 4)
   b = ASC(MID$(pic$, ofs + 1, 1))
   SELECT CASE x AND 3
      CASE 0: cgapix = (b \ 64) AND 3
      CASE 1: cgapix = (b \ 16) AND 3
      CASE 2: cgapix = (b \ 4) AND 3
      CASE ELSE: cgapix = b AND 3
   END SELECT
END FUNCTION
