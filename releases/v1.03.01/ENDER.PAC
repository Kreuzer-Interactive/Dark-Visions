DEFINT A-B: DIM b(600)
SCREEN 1
PALETTE 1, 8
PALETTE 2, 4
PALETTE 3, 14
BLOAD "end.pic"
PLAY "e-6d5e-5d5f7p7"
PLAY "a5>c6<b6a5g6a4"
FOR i = 1 TO 5
SOUND 32761, 1: NEXT i
FOR f = 1 TO 3: FOR h = 1 TO 3
IF h = 1 THEN a = 8 ELSE IF h = 2 THEN a = 7 ELSE IF h = 3 THEN a = 15
PALETTE f, a
FOR i = 1 TO 5: IF RND < .9 THEN SOUND RND * 71 + 50, (RND * .2) + .3 ELSE SOUND 32767, .5
NEXT i
NEXT h: NEXT f
PALETTE 0, 15
7 BLOAD "end2.pic"
FOR i = 1 TO 7: SOUND 32671, .5: NEXT i
PALETTE 0, 0
FOR f = 1 TO 3: FOR h = 1 TO 3
IF h = 1 THEN a = 8 ELSE IF h = 2 THEN a = 7 ELSE IF h = 3 THEN GOSUB 40
PALETTE f, a
FOR i = 1 TO 5: IF RND < .9 THEN SOUND RND * 71 + 50, (RND * .2) + .3 ELSE SOUND 32767, .5
NEXT i
NEXT h: NEXT f
FOR i = 1 TO 40: SOUND 32676, .1
NEXT i
GOSUB 60
FOR i = 1 TO 20
SOUND 32761, 1: NEXT i
GOSUB 50
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
30 a$ = INKEY$: IF a$ = "" THEN 30
SYSTEM
40 IF f = 1 THEN a = 8
IF f = 2 THEN a = 2
IF f = 3 THEN a = 6
RETURN
50 FOR i = 1 TO 23: FOR g = 1 TO 40
LOCATE INT(RND * 23) + 1, INT(RND * 40) + 1: PRINT " "
SOUND 32676, .05
NEXT g: NEXT i
CLS
RETURN
60 GET (212, 140)-(262, 160), b
PUT (212, 140), b, XOR
LINE (211, 148)-(265, 148), 1
FOR xi = 212 TO 65 STEP -1
PUT (xi, 140), b, XOR
SOUND (RND * 100) + 50, .1: SOUND 100, .1
PUT (xi, 140), b, XOR
NEXT xi
RETURN



