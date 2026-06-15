REM $DYNAMIC
'--Dark Visions  by Rob & Jon Kreuzer--
'Programmed in QuickBASIC 4.5

'----- SUB declarations
DECLARE SUB Intro ()
DECLARE SUB Credits ()
DECLARE SUB InitVars ()
DECLARE SUB Snd1 ()
DECLARE SUB Snd2 ()
DECLARE SUB Snd3 ()
DECLARE SUB Snd4 ()
DECLARE SUB Snd5 ()
DECLARE SUB NotesSub ()
DECLARE SUB DeathMusic ()
DECLARE SUB PctComplete ()
DECLARE SUB InvGrid ()
DECLARE SUB DoorOpen ()
DECLARE SUB LoadConfig ()

'----- assembly interrupt support (INT 33h mouse)
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
TYPE RegTypeX
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
DECLARE SUB INTERRUPTX (intnum AS INTEGER, inreg AS RegTypeX, outreg AS RegTypeX)

'----- shared timers and counters
DIM SHARED cr AS SINGLE
DIM SHARED t0 AS SINGLE
DIM SHARED ti AS SINGLE
DIM SHARED td AS SINGLE
DIM SHARED pt AS SINGLE

'----- shared scalars and strings
DIM SHARED q$, a$, done$, tt$, lf$, sl$, dop$, vk$, tk$, m$, sf$, sy$
DIM SHARED cl, h9, h10, h11, hr, mn, t1, t2, t3, cv
DIM SHARED gw, gy, gx, sel, doc, sn, di, dn1, dn2, dn3
DIM SHARED f1, f2, f3, f4, f5, f6, f7, f8, f9, f10
DIM SHARED pk, jx, jy, dx2, dy2, co, co2, pa1, pa2, pa3
DIM SHARED oh, ohs, pz, j, pc, pp2, gm, mt, tmo, wk, js0, js1
DIM SHARED sa, sb, sc
DIM SHARED sfps, fpsc, fpst, fpsv, fpsd
DIM SHARED ifc, it0, itt
DIM SHARED jsen
DIM SHARED msen, mlb, mrb, mshown, snr, exsen, cshp, hovr, mxyon
DIM SHARED nf$(25), nfon, nfseed, lcount, lastlx, lastly, lh1, lh2, lh3
DIM SHARED mvint AS INTEGER
DIM SHARED mreg AS RegType, mout AS RegType
DIM SHARED mcur AS INTEGER, mhsx AS INTEGER, mhsy AS INTEGER, mxor, mraw
DIM SHARED mregx AS RegTypeX, moutx AS RegTypeX
DIM SHARED cmask(31) AS INTEGER
DIM SHARED arow$(15)
DIM SHARED px(4, 80), py(4, 80), pc(4, 80), npix(4)
DIM SHARED curbuf(100), cdrawn, cox, coy, mx, my

'----- shared sprite/door buffers
DIM SHARED do1(150) AS INTEGER
DIM SHARED do2(300) AS INTEGER
DIM SHARED do3(300) AS INTEGER
DIM SHARED do4(300) AS INTEGER
DIM SHARED wa(150) AS INTEGER
DIM SHARED wb(300) AS INTEGER
DIM SHARED fd(150) AS INTEGER
DIM SHARED fu(300) AS INTEGER
DIM SHARED fr(300) AS INTEGER
DIM SHARED fl(300) AS INTEGER
DIM SHARED fdl(300) AS INTEGER
DIM SHARED fdr(300) AS INTEGER
DIM SHARED ful(300) AS INTEGER
DIM SHARED fur(300) AS INTEGER

'----- shared world and inventory arrays
DIM SHARED bk(100)
DIM SHARED bk2(100)
DIM SHARED gr(2000)
DIM SHARED ob(100)
DIM SHARED oy(257) AS INTEGER
DIM SHARED ox(257) AS INTEGER
DIM SHARED oi(257) AS INTEGER
DIM SHARED df$(100)
DIM SHARED ms$(150)
DIM SHARED ky$(150)
DIM SHARED bs(100)
DIM SHARED cs(100)
DIM SHARED st(150)
DIM SHARED tg$(150)
DIM SHARED dn$(50)
DIM SHARED gp(100)
DIM SHARED er1(400)
DIM SHARED d(300)

'----- shared save-slot arrays
DIM SHARED sv1(50)
DIM SHARED sv2(50)
DIM SHARED sv3(50)
DIM SHARED sv4(50)
DIM SHARED sv5(50)
DIM SHARED sv6(50)
DIM SHARED sv7(50)
DIM SHARED sv8(50)
DIM SHARED sv9(50)
DIM SHARED sv10(50)

'----- startup
tmo = 2
'COM() statements in this programme
CALL InitVars
CALL LoadConfig
CALL Intro
KEY OFF
t0 = TIMER

'----- joystick button handlers
ON STRIG(2) GOSUB vact
ON STRIG(0) GOSUB vlook
ON STRIG(4) GOSUB vget
ON STRIG(6) GOSUB vuse
GOSUB strigon
GOSUB loadnames
GOSUB loadmsgs
GOSUB mouseinit
ON ERROR GOTO errhand

'----- load door coordinate table
SCREEN 1
CLS
CLOSE
OPEN "door.pct " FOR INPUT AS #1
FOR i = 0 TO 125
	INPUT #1, do1(i), do2(i), do3(i), do4(i)
NEXT

'----- title screen
SCREEN 1
LOCATE 10, 12
PRINT "A Kreuzer Production"
a$ = INKEY$
GOSUB joeface
a$ = INKEY$
CLS
b = 122
a = 82

'----- instructions prompt
PRINT " Do you want instructions Y/N"
IF sfps = 1 AND itt > .5 THEN LOCATE 3, 1: PRINT USING "Intro: ### steps in ###.# secs"; ifc; itt
400 a$ = INKEY$
IF a$ <> "" THEN GOTO 430
GOTO 400
430 IF a$ = "Y" OR a$ = "y" THEN GOSUB rules

'----- enter the game
DRAW "bm1,1c1r3d3l1u2l1d2l1u2"
GET (1, 1)-(4, 4), d
a$ = "2"
q$ = "room4"
GOSUB loadroom
GOSUB face
GOTO mainloop
'----- rules screen: instructions and intro text
rules:
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

	'----- wait for keypress, then return to game
	790 a$ = INKEY$
	IF a$ <> "" THEN SCREEN 1: RETURN
	GOTO 790

	'----- password prompt
	820 SCREEN 1
	CLS
	LOCATE 1, 1
	PRINT "Whats the password?"
	INPUT ""; a$
	IF a$ = "YURI" OR a$ = "yuri" OR a$ = "Yuri" THEN GOTO 940
	SYSTEM

	'----- credits roll
	940 CLS
	GOSUB loadpac
	CLS
	LOCATE 1, 1
	PRINT "  GAME DESIGN"
	PRINT "--ROB KREUZER--"
	PRINT "--Jon Kreuzer--"
	FOR i = 1 TO 1000
	NEXT
	PRINT "  STORYLINE"
	PRINT "--ROB KREUZER--"
	FOR i = 1 TO 1600
	NEXT
	PRINT "    MUSIC"
	PRINT "--Rob Kreuzer--"
	FOR i = 1 TO 1600
	NEXT
	PRINT " SOUND EFFECTS"
	PRINT "--JON KREUZER--"
	FOR i = 1 TO 1600
	NEXT
	PRINT "POINT ' CLICK INTERFACE"
	PRINT "  --JON KREUZER--"
	FOR i = 1 TO 1600
	NEXT
	PRINT "   GRAPHICS"
	PRINT "--ROB KREUZER--"
	PRINT "--Jon Kreuzer--"
	FOR i = 1 TO 1600
	NEXT
	PRINT "    EDITING"
	PRINT "--JON KREUZER--"
	GOTO 1440

	'----- dead code: jingle (skipped by GOTO 1440 above)
	FOR i = 900 TO 300 STEP -10
		SOUND i, .5
	NEXT
	SOUND 32676, 3
	FOR i = 50 TO 100 STEP 10
		SOUND i, .5
		SOUND f2, .05
		SOUND f1, 1
		SOUND 32676, .1
	NEXT
	SOUND 32676, 1
	SOUND f3, .3
	SOUND f1, .5
	SOUND f3, .3
	SOUND f1, .5
	i = 3

	'----- final credit and wait for key
	1440 FOR i = 1 TO 1600
	NEXT
	PRINT "    TEXT"
	PRINT "--ROB KREUZER--"
	PRINT "--Jon Kreuzer--"
	PRINT "Hit a key to continue!"
	1500 a$ = INKEY$
	IF a$ <> "" THEN GOTO 1530
	GOTO 1500
	1530 SYSTEM

'----- combination dial puzzle
dial:
	DRAW "bm153,104"

	'----- draw marker, poll for input
	1550 DRAW "c3bl5nl10br5bd4nd9bu4br5nr10bl5c1bu5nu9bd5"
	1560 a$ = INKEY$
	GOSUB joy
	IF a$ <> "" THEN GOTO 1600
	GOTO 1560

	'----- redraw marker, dispatch on key
	1600 DRAW "c2bl5nl10br5bd4nd9bu4br5nr10bl5bu5nu9bd5"
	IF a$ <> "6" THEN GOTO 1650
	GOSUB dialdown
	DRAW "ta=" + VARPTR$(di)
	GOTO 1550

	1650 IF a$ <> "4" THEN GOTO 1690
	GOSUB dialup
	DRAW "ta=" + VARPTR$(di)
	GOTO 1550

	'----- check for solved combination; exit on g/x
	1690 IF dn3 = 1 AND dn2 = 1 AND dn1 = 1 THEN SOUND f4, .5: ob(45) = 1
	IF a$ = "g" OR a$ = "x" THEN RETURN
	GOTO 1560

'----- turn dial counter-clockwise, track tumblers
dialdown:
	di = di - 10
	IF di <> -10 THEN GOTO 1790
	di = 350
	1790 IF (di / 10) <> 5 THEN GOTO 1820
	SOUND f3, .1
	dn1 = 0#
	1820 IF (di / 10) <> 9 THEN GOTO 1860
	SOUND f3, .1
	IF dn2 <> 1 THEN GOTO 1860
	dn1 = 1
	1860 IF (di / 10) <> 14 THEN GOTO 1910
	SOUND f3, .1
	dn1 = 0#
	IF dn2 <> 0# THEN GOTO 1910
	dn3 = 0#
	1910 IF (di / 10) <> 18 THEN GOTO 1940
	SOUND f3, .1
	dn3 = 1
	1940 IF (di / 10) <> 23 THEN GOTO 1960
	SOUND f3, .1
	1960 IF (di / 10) <> 27 THEN GOTO 1980
	SOUND f3, .1
	1980 IF (di / 10) <> 32 THEN GOTO 2000
	SOUND f3, .1
	2000 IF (di / 10) <> 0# THEN GOTO 2020
	SOUND f3, .1
	2020 RETURN

'----- turn dial clockwise, track tumblers
dialup:
	di = di + 10
	IF di <> 360 THEN GOTO 2060
	di = 0
	2060 IF (di / 10) <> 5 THEN GOTO 2110
	SOUND f3, .1
	dn1 = 0#
	IF dn3 <> 1 THEN GOTO 2110
	dn2 = 1
	2110 IF (di / 10) <> 9 THEN GOTO 2140
	SOUND f3, .1
	dn2 = 0#
	2140 IF (di / 10) <> 14 THEN GOTO 2170
	SOUND f3, .1
	dn1 = 0#
	2170 IF (di / 10) <> 18 THEN GOTO 2190
	SOUND f3, .1
	2190 IF (di / 10) <> 23 THEN GOTO 2210
	SOUND f3, .1
	2210 IF (di / 10) <> 27 THEN GOTO 2230
	SOUND f3, .1
	2230 IF (di / 10) <> 32 THEN GOTO 2250
	SOUND f3, .1
	2250 IF (di / 10) <> 0# THEN GOTO 2270
	SOUND f3, .1
	2270 RETURN
'----- error handler -- show ERR/ERL diagnostic then exit
errhand:
	BEEP
	SCREEN 0: WIDTH 80: CLS
	LOCATE 5, 5: PRINT "PASS2-RECON DIAGNOSTIC -- error handler triggered"
	LOCATE 7, 5: PRINT "ERR  (code) ="; ERR
	LOCATE 8, 5: PRINT "ERL  (line) ="; ERL
	LOCATE 10, 5: PRINT "Common QB4.5 codes: 5=IllFnCall 6=Overflow 9=SubscriptOOR"
	LOCATE 11, 5: PRINT "  11=DivByZero 13=TypeMismatch 53=FileNotFound 54=BadMode"
	LOCATE 12, 5: PRINT "  55=FileOpen 57=DevIOErr 62=InputPastEOF 68=DeviceUnavail"
	LOCATE 14, 5: PRINT "Press any key to exit..."
	a$ = INPUT$(1)
	PRINT "Program terminated!"
	SOUND 32676, 20
	SOUND f3, .1
	FOR i = 1000 TO 50 STEP -15
		SOUND i, .2
		SOUND f4, .1
		SOUND i * 2, .05
	NEXT
	SYSTEM

'----- inventory screen
inv:
	CLS
	td = TIMER - ti
	IF ob(32) = 1 AND ob(36) = 1 THEN ob(33) = 1
	m$ = ""

'----- compute in-game clock (hr:mn) from elapsed time
	IF (INT(cl * cr)) <= h9 THEN GOTO 2530
	hr = 9
	mn = INT(cl * cr) - 60
	GOTO 2550
	2530 mn = INT(cl * cr)
	hr = 8
	2550 IF (INT(cl * cr)) <= h10 THEN GOTO 2580
	hr = 10
	mn = INT(cl * cr) - 120
	2580 IF (INT(cl * cr)) <= h11 THEN GOTO 2610
	hr = 11
	mn = INT(cl * cr) - 180
	2610 LOCATE 3, 1
	PRINT "The time is "; hr; ":"; mn;
	CALL PctComplete

'----- name the current room from the screen tag
	PRINT "You are in the ";
	IF q$ = "openclos" OR q$ = "room4" THEN PRINT "guest room."
	IF q$ = "room6" THEN PRINT "library."
	IF q$ = "desk" OR q$ = "room7" THEN PRINT "master bedroom."
	IF q$ = "room8" THEN PRINT "servant's quarters."
	IF q$ = "room9" THEN PRINT "cell block."
	IF q$ = "room10" THEN PRINT "cell."
	IF q$ = "room1" THEN PRINT "entrance hall."
	IF q$ = "room2" THEN PRINT "upstairs hall."
	IF q$ = "safe" OR q$ = "window" OR q$ = "room3" THEN PRINT "storage hall."
	IF q$ = "table" OR q$ = "room11" THEN PRINT "attic."
	IF q$ = "rack" OR q$ = "room5" THEN PRINT "kitchen"

'----- list carried objects and build selectable grid
	gy = 6
	LOCATE 5, 1
	PRINT "      Objects: "
	gx = 2
	IF ob(1) <> 1 THEN GOTO 3020
	LOCATE gy, 2
	PRINT "Matches"
	gy = gy + 1
	gr((gw * gx) + gy) = 1
	3020 IF ob(2) <> 1 THEN GOTO 3070
	LOCATE gy, 2
	PRINT "Poker"
	gy = gy + 1
	gr((gw * gx) + gy) = 2
	3070 IF ob(3) <> 1 THEN GOTO 3120
	LOCATE gy, 2
	PRINT "Journal Page"
	gy = gy + 1
	gr((gw * gx) + gy) = 3
	3120 IF ob(4) <> 1 THEN GOTO 3170
	LOCATE gy, 2
	PRINT "Pipe Wrench"
	gy = gy + 1
	gr((gw * gx) + gy) = 4
	3170 IF ob(5) <> 1 THEN GOTO 3220
	LOCATE gy, 2
	PRINT "Small Key "
	gy = gy + 1
	gr((gw * gx) + gy) = 5
	3220 IF ob(6) <> 1 THEN GOTO 3270
	LOCATE gy, 2
	PRINT "Bar"
	gy = gy + 1
	gr((gw * gx) + gy) = 6
	3270 IF ob(7) <> 1 THEN GOTO 3320
	LOCATE gy, 2
	PRINT "Baking Soda"
	gy = gy + 1
	gr((gw * gx) + gy) = 7
	3320 IF ob(8) <> 1 THEN GOTO 3370
	LOCATE gy, gx
	PRINT "White Key"
	gy = gy + 1
	gr((gw * gx) + gy) = 8
	3370 IF ob(9) <> 1 THEN GOTO 3420
	LOCATE gy, gx
	PRINT "Patient book"
	gy = gy + 1
	gr((gw * gx) + gy) = 9
	3420 IF ob(10) <> 1 THEN GOTO 3470
	LOCATE gy, gx
	PRINT "Experiment book"
	gy = gy + 1
	gr((gw * gx) + gy) = 10
	3470 IF ob(11) <> 1 THEN GOTO 3520
	LOCATE gy, gx
	PRINT "Partial formula"
	gy = gy + 1
	gr((gw * gx) + gy) = 11
	3520 IF ob(12) <> 1 THEN GOTO 3570
	LOCATE gy, gx
	PRINT "Penny"
	gy = gy + 1
	gr((gw * gx) + gy) = 12
	3570 IF ob(13) <> 1 THEN GOTO 3620
	LOCATE gy, gx
	PRINT "Uncle's key"
	gy = gy + 1
	gr((gw * gx) + gy) = 13
	3620 IF ob(14) <> 1 THEN GOTO 3670
	LOCATE gy, gx
	PRINT "Rope"
	gy = gy + 1
	gr((gw * gx) + gy) = 14
	3670 IF ob(15) <> 1 THEN GOTO 3720
	LOCATE gy, gx
	PRINT "Polished rock"
	gy = gy + 1
	gr((gw * gx) + gy) = 15
	3720 IF ob(16) <> 1 THEN GOTO 3770
	LOCATE gy, gx
	PRINT "Map page"
	gy = gy + 1
	gr((gw * gx) + gy) = 16
	3770 IF ob(17) <> 1 THEN GOTO 3820
	LOCATE gy, gx
	PRINT "Spoon"
	gy = gy + 1
	gr((gw * gx) + gy) = 17
	3820 IF ob(18) <> 1 THEN GOTO 3870
	LOCATE gy, gx
	PRINT "Small knife"
	gy = gy + 1
	gr((gw * gx) + gy) = 18
	3870 GOSUB gridwrap
	IF ob(19) <> 1 THEN GOTO 3930
	LOCATE gy, gx
	PRINT "Uncle's journal"
	gy = gy + 1
	gr((gw * gx) + gy) = 19
	3930 GOSUB gridwrap
	IF ob(20) <> 1 THEN GOTO 3990
	LOCATE gy, gx
	PRINT "Carpenters saw"
	gy = gy + 1
	gr((gw * gx) + gy) = 20
	3990 GOSUB gridwrap
	IF ob(21) <> 1 THEN GOTO 4050
	LOCATE gy, gx
	PRINT "Syrem book"
	gy = gy + 1
	gr((gw * gx) + gy) = 21
	4050 GOSUB gridwrap
	IF ob(22) <> 1 THEN GOTO 4110
	LOCATE gy, gx
	PRINT "Apple key"
	gy = gy + 1
	gr((gw * gx) + gy) = 22
	4110 GOSUB gridwrap
	IF ob(23) <> 1 THEN GOTO 4170
	LOCATE gy, gx
	PRINT "Clock hand"
	gy = gy + 1
	gr((gw * gx) + gy) = 23
	4170 GOSUB gridwrap
	IF ob(24) <> 1 THEN GOTO 4230
	LOCATE gy, gx
	PRINT "Partial formula"
	gy = gy + 1
	gr((gw * gx) + gy) = 24
	4230 GOSUB gridwrap
	IF ob(25) <> 1 THEN GOTO 4290
	LOCATE gy, gx
	PRINT "Deciphering book"
	gy = gy + 1
	gr((gw * gx) + gy) = 25
	4290 GOSUB gridwrap
	IF ob(26) <> 1 THEN GOTO 4350
	LOCATE gy, gx
	PRINT "Numbered paper"
	gy = gy + 1
	gr((gw * gx) + gy) = 26
	4350 GOSUB gridwrap
	IF ob(27) <> 1 THEN GOTO 4410
	LOCATE gy, gx
	PRINT "Paper clip"
	gy = gy + 1
	gr((gw * gx) + gy) = 27
	4410 GOSUB gridwrap
	IF ob(28) <> 1 THEN GOTO 4470
	LOCATE gy, gx
	PRINT "Red Apple"
	gy = gy + 1
	gr((gw * gx) + gy) = 28
	4470 GOSUB gridwrap
	IF ob(29) <> 1 THEN GOTO 4530
	LOCATE gy, gx
	PRINT "Syringe"
	gy = gy + 1
	gr((gw * gx) + gy) = 29
	4530 GOSUB gridwrap
	IF ob(19) <> 1 THEN GOTO 4590
	LOCATE gy, gx
	PRINT "Valuable jewel"
	gy = gy + 1
	gr((gw * gx) + gy) = 19
	4590 GOSUB gridwrap
	IF ob(49) <> 1 THEN GOTO 4650
	LOCATE gy, gx
	PRINT "Stash of bills"
	gy = gy + 1
	gr((gw * gx) + gy) = 49
	4650 GOSUB gridwrap
	IF ob(35) <> 1 THEN GOTO 4710
	LOCATE gy, gx
	PRINT "Loaded syringe"
	gy = gy + 1
	gr((gw * gx) + gy) = 35
	4710 GOSUB gridwrap
	IF ob(36) <> 1 THEN GOTO 4770
	LOCATE gy, gx
	PRINT "Complete formula"
	gy = gy + 1
	gr((gw * gx) + gy) = 36
	4770 GOSUB gridwrap
	IF ob(34) <> 1 THEN GOTO 4830
	LOCATE gy, gx
	PRINT "Drug"
	gy = gy + 1
	gr((gw * gx) + gy) = 34
	4830 CALL InvGrid

'----- inventory menu key handling
	LOCATE 25, 1
	PRINT "r=restore,s=save,q=quit,x=exit inventory";
	4860 a$ = INKEY$
	GOSUB joy
	IF a$ <> "" THEN GOTO 4900
	GOTO 4860
	4900 IF a$ <> "r" THEN GOTO 4940
	GOSUB reload
	a$ = "x"
	GOTO 4960
	4940 IF a$ <> "q" THEN GOTO 4960
	GOSUB quit
	4960 IF a$ <> "s" THEN GOTO 4990
	GOSUB save
	a$ = "x"
	4990 IF a$ <> "u" THEN GOTO 5010
	GOSUB usecombine
	5010 IF a$ <> "a" THEN GOTO 5030
	GOSUB lookmap
	5030 IF done$ <> "y" THEN GOTO 5060
	done$ = ""
	GOTO inv
	5060 GOSUB invcur
	IF a$ = "g" OR a$ = "x" THEN GOTO 5100
	GOTO 4860

'----- exit inventory -- restore game state and redraw
	5100 IF doc <> 1 THEN GOTO 5120
	ti = TIMER - td
	5120 IF q$ <> "smart" THEN GOTO 5140
	GOTO 14570
	5140 GOSUB loadroom
	IF tt$ = "y" THEN GOTO 5190
	a$ = lf$
	lf$ = ""
	GOSUB face
	5190 IF doc = 1 THEN PUT (135, 135), wa, XOR
	RETURN
'----- Load saved game from saverN.pac
reload:
	LOCATE 1, 8
	PRINT "Load game 1,2,3 or 4?"
	CLOSE
	INPUT ""; sn
	IF sn > 4 OR sn < 0# THEN GOTO reload
	OPEN "saver" + CHR$(sn + 97) + ".pac" FOR INPUT AS #1
	INPUT #1, q$, cl, pt, done$, tt$, a$, lf$
	FOR i = 1 TO 65
		INPUT #1, ob(i)
	NEXT
	ERASE er1
	FOR i = 1 TO 40
		gp(i) = 0#
	NEXT
	LOCATE 2, 1
	PRINT "Load is complete!              "
	RETURN

'----- Save game to saverN.pac
save:
	LOCATE 1, 8
	PRINT "Save under 1,2,3, or 4?"
	CLOSE
	INPUT ""; sn
	IF sn > 4 OR sn < 0# THEN GOTO save
	OPEN "saver" + CHR$(sn + 97) + ".pac" FOR OUTPUT AS #1
	WRITE #1, q$, cl, pt, done$, tt$, a$, lf$
	FOR i = 1 TO 65
		WRITE #1, ob(i)
	NEXT
	LOCATE 2, 1
	PRINT "Save is complete!              "
	RETURN

'----- Confirm and exit to DOS
quit:
	LOCATE 1, 1
	PRINT "Do you really want to quit?"
	5990 a$ = INKEY$
	IF a$ <> "" THEN GOTO 6020
	GOTO 5990
	6020 IF a$ = "y" THEN SYSTEM
	RETURN

'----- Resolve action on object under cursor
action:
	GOSUB strigoff
	LOCATE 1, 1
	PRINT "                                                                               "
	cl = cl + 8
	FOR i = 1 TO 257
		IF b = ox(i) AND a = oy(i) THEN GOTO 6170
		6130 IF oy(i) <> 0# THEN GOTO 6150
		i = 257
	6150 NEXT
	RETURN

'----- Object hit: validate verb and conditions
6170 oh = i
	i = CINT(oi(i))
	IF ky$(i) <> a$ THEN GOTO 6210
	GOTO 6230
	6210 i = oh
	GOTO 6130
	6230 IF ky$(i) <> "u" THEN GOTO 6260
	IF bs(i) = sel THEN GOTO 6260
	GOTO 6280
	6260 IF bs(i) = 0 OR ob(bs(i)) = 1 THEN GOTO 6300
	6280 i = oh
	GOTO 6130
	6300 IF cs(i) = 0 OR ob(cs(i)) = 0 THEN GOTO 6340
	i = oh
	GOTO 6130

'----- Apply state change and print message
6340 ob(CINT(st(i))) = 1
	IF a$ = "g" AND st(i) <> 0# THEN CALL Snd1
	IF a$ <> "u" THEN GOTO 6400
	CALL Snd3
	6400 LOCATE 1, 1
	PRINT "                                                                               "
	LOCATE 1, 1
	PRINT ms$(i)
	IF tg$(i) = "" THEN GOTO 6740
	IF MID$(tg$(i), 2, 1) = "c" THEN sl$ = "s": tt$ = "y"
	IF LEFT$(tg$(i), 1) <> "w" THEN GOTO 6710

'----- Trigger a walkout in the tagged direction
	IF RIGHT$(tg$(i), 1) <> "s" THEN GOTO 6560
	ohs = i
	a$ = "1"
	wk = 1: GOSUB walkout: wk = 0
	i = ohs
	6560 IF RIGHT$(tg$(i), 1) <> "n" THEN GOTO 6610
	ohs = i
	a$ = "2"
	wk = 1: GOSUB walkout: wk = 0
	i = ohs
	6610 IF RIGHT$(tg$(i), 1) <> "e" THEN GOTO 6660
	ohs = i
	a$ = "3"
	wk = 1: GOSUB walkout: wk = 0
	i = ohs
	6660 IF RIGHT$(tg$(i), 1) <> "w" THEN GOTO 6710
	ohs = i
	a$ = "4"
	wk = 1: GOSUB walkout: wk = 0
	i = ohs

'----- Face the tagged direction
	6710 IF LEFT$(tg$(i), 1) <> "f" THEN GOTO 6740
	a$ = RIGHT$(tg$(i), 1)
	GOSUB face

'----- Play follow-up sound and run any deferred action
	6740 IF st(i) = 47 OR st(i) = 41 THEN CALL Snd4
	IF st(i) = 19 THEN CALL Snd5
	IF df$(i) = "" THEN RETURN
	FOR pz = 1 TO 500
	NEXT
	CALL Snd2
	IF df$(i) = "dial" THEN GOSUB dial: RETURN
	IF df$(i) = "end" THEN GOTO endgame
'----- enter a room and draw the player
gotoroom:
	q$ = df$(i)
	GOSUB loadroom
	IF q$ = "lightn" OR q$ = "dindead" OR q$ = "death" THEN GOTO death
	dop$ = ""
	IF tt$ = "y" AND sl$ = "z" THEN a$ = lf$: lf$ = "": GOSUB face: tt$ = "n"
	sl$ = "z"
	cl = cl + 30
	GOSUB face
	RETURN

'----- main game loop: input, movement, actions
mainloop:
	IF msen <> 1 THEN PUT (b, a), d, XOR
	pt = (TIMER - t0) + pt
	t0 = TIMER
	IF (INT(cl * cr)) <= 35 THEN GOTO 7100
	CALL DoorOpen
	7100 IF doc <> 1 THEN GOTO 7180
	IF (TIMER - ti) <= tmo THEN GOTO 7180
	LOCATE 1, 1
	PRINT "You should have been ready"
	doc = 0
	i = 0
	df$(i) = "death"
	GOSUB gotoroom

'----- idle poll: wait for keypress, tick fps, check timers
	7180 DEF SEG = 0
	POKE pk, 32
	IF sfps = 1 THEN GOSUB fpstick
	a$ = INKEY$
	GOSUB joy
	GOSUB mousepoll
	IF ob(43) = 1 AND tk$ = "" THEN cv = CINT(cl): tk$ = "y"
	IF tk$ = "y" AND cv + 120 < cl THEN GOTO burn
	IF a$ <> "" THEN GOTO 7300
	GOTO 7180

'----- numpad movement: nudge player by direction
	7300 IF msen = 1 THEN GOSUB erasecur
	IF msen <> 1 THEN PUT (b, a), d, XOR
	IF a$ <> "8" THEN GOTO 7330
	a = a - 4
	7330 IF a$ <> "2" THEN GOTO 7350
	a = a + 4
	7350 IF a$ <> "6" THEN GOTO 7370
	b = b + 4
	7370 IF a$ <> "4" THEN GOTO 7390
	b = b - 4
	7390 IF a$ <> "7" THEN GOTO 7420
	b = b - 4
	a = a - 4
	7420 IF a$ <> "1" THEN GOTO 7450
	b = b - 4
	a = a + 4
	7450 IF a$ <> "3" THEN GOTO 7480
	b = b + 4
	a = a + 4
	7480 IF a$ <> "9" THEN GOTO 7510
	b = b + 4
	a = a - 4

'----- clamp player to screen bounds
	7510 IF b >= 0 THEN GOTO 7540
	b = b + 4
	GOTO 7560
	7540 IF b <= 300 THEN GOTO 7560
	b = b - 4
	7560 IF a >= 10 THEN GOTO 7590
	a = a + 4
	GOTO 7610
	7590 IF a <= 195 THEN GOTO 7610
	a = a - 4

'----- handle inventory, fight, and action keys
	7610 IF a$ <> "i" THEN GOTO 7630
	GOSUB inv
	7630 IF doc <> 1 THEN GOTO 7660
	GOSUB fight
	GOTO mainloop
	7660 IF a$ = "a" OR a$ = "u" OR a$ = "g" OR a$ = "l" THEN
		IF msen = 1 THEN GOSUB msnap
		GOSUB action
		GOSUB events
		GOSUB trigger
		IF a$ = "l" AND nfon = 1 THEN GOSUB lookmiss
	END IF
	GOTO mainloop
	SYSTEM

'----- fps counter: update on-screen frame rate
fpstick:
	fpsc = fpsc + 1
	fpsd = TIMER - fpst
	IF fpsd < 0 OR fpsd >= 2 THEN
		fpst = TIMER
		fpsc = 0
	ELSEIF fpsd >= 1 THEN
		fpsv = fpsc / fpsd
		IF fpsv > 99999 THEN fpsv = 99999
		LOCATE 1, 35
		PRINT USING "#####"; fpsv;
		fpst = TIMER
		fpsc = 0
	END IF
	RETURN

'----- debug readout: raw mouse xy, snapped hit point, and the object+verb a click here resolves to
mxytick:
	dbgoi = 0
	dbgmin = snr * snr + 1
	FOR dbgsi = 1 TO 257
		IF oy(dbgsi) = 0# THEN EXIT FOR
		dbgx = mx - ox(dbgsi)
		dbgy = my - oy(dbgsi)
		IF ABS(dbgx) <= snr AND ABS(dbgy) <= snr THEN
			dbgdd = dbgx * dbgx + dbgy * dbgy
			IF dbgdd < dbgmin THEN dbgmin = dbgdd: dbgoi = CINT(oi(dbgsi))
		END IF
	NEXT
	dbgv$ = "-"
	IF dbgoi >= 1 AND dbgoi <= 25 THEN dbgv$ = ky$(dbgoi)
	IF dbgv$ = "" THEN dbgv$ = "-"
	LOCATE 24, 1
	PRINT USING "mxy ### ### hit ### ### obj ## v="; mx; my; b; a; dbgoi;
	PRINT dbgv$; "  ";
	RETURN

'----- 25 generic "nothing to see" lines (used by lookmiss)
loadmsgs:
	nf$(1) = "There is nothing to see here."
	nf$(2) = "Nothing catches your eye."
	nf$(3) = "You see nothing unusual."
	nf$(4) = "Nothing worth a closer look."
	nf$(5) = "You find nothing of interest."
	nf$(6) = "Nothing remarkable here."
	nf$(7) = "You look closer, but find nothing."
	nf$(8) = "There's nothing special about it."
	nf$(9) = "You see only the ordinary."
	nf$(10) = "Nothing stands out to you."
	nf$(11) = "There's nothing here to examine."
	nf$(12) = "It holds no secrets for you."
	nf$(13) = "Nothing draws your attention."
	nf$(14) = "You don't see anything useful."
	nf$(15) = "Nothing of note here."
	nf$(16) = "Whatever you sought, it isn't here."
	nf$(17) = "Nothing worth mentioning."
	nf$(18) = "There's nothing here for you."
	nf$(19) = "Just as it looks - nothing more."
	nf$(20) = "Your eyes find nothing of value."
	nf$(21) = "Nothing but dust and shadow."
	nf$(22) = "There's nothing here to help you."
	nf$(23) = "You peer closer. Still nothing."
	nf$(24) = "Nothing reveals itself to you."
	nf$(25) = "The shadows hide nothing here."
	RETURN

'----- look at a truly-empty spot: after 3 looks at the same cell, show a non-repeating random line
lookmiss:
	FOR lmi = 1 TO 257
		IF oy(lmi) = 0# THEN EXIT FOR
		IF ox(lmi) = b AND oy(lmi) = a THEN lcount = 0: RETURN
	NEXT
	IF b = lastlx AND a = lastly THEN
		lcount = lcount + 1
	ELSE
		lcount = 1
		lastlx = b
		lastly = a
	END IF
	IF lcount < 3 THEN RETURN
	IF nfseed = 0 THEN RANDOMIZE TIMER: nfseed = 1
	DO
		nfp = INT(RND * 25) + 1
	LOOP WHILE nfp = lh1 OR nfp = lh2 OR nfp = lh3
	lh3 = lh2
	lh2 = lh1
	lh1 = nfp
	LOCATE 1, 1
	PRINT "                                        "
	LOCATE 1, 1
	PRINT nf$(nfp)
	RETURN
'----- load palette/color config from .pac
loadpac:
	CLOSE
	OPEN q$ + ".pac" FOR INPUT AS #1
	INPUT #1, co, co2
	CLOSE
	CLS
	COLOR co, co2
	DEF SEG = -18432
	KEY OFF
	DEF SEG
	q$ = "hallez"
	RETURN

'----- load room: colors, object positions, door/exit data, picture
loadroom:
	CLOSE
	OPEN q$ + ".pac" FOR INPUT AS #1
	INPUT #1, co, pa1, pa2, pa3
	i = 0
	DO
		i = i + 1
		INPUT #1, ox(i), oy(i), oi(i)
	LOOP UNTIL oy(i) = 0 OR i = 257
	FOR i = 1 TO 25
		INPUT #1, df$(i), ms$(i), ky$(i)
		INPUT #1, bs(i), cs(i), st(i), tg$(i)
	NEXT
	CLS
	COLOR co
	PALETTE 1, pa1
	PALETTE 2, pa2
	PALETTE 3, pa3
	DEF SEG = -18432
	BLOAD q$ + ".pic", 0
	KEY OFF
	GET (1, 8)-(9, 18), bk: GET (1, 8)-(9, 18), bk2
	DEF SEG
	IF q$ <> "title" THEN GOTO walkout

	'----- title screen music
	PLAY "<d5f5g+5A+5d5f5G+5A+5e5g5a+5b5a5>c+5d5c+5"
	PLAY "<a>c+dc+<gaa+>d<gaa+.>d<g5g+5g 5g+5g5G+5"
	PLAY "g05d04b-08g02g08f04g08a-08b-08c03a-04"
	PLAY "<g05d04b-08g02g08f04g08a-08b-08c03a-04"
	PLAY ">g05d04b-08g02g08f04g08a-08b-08c03a-04"
	PLAY "e-04d08c04d08e-04g03d02<<g08b-08g08g"

'----- walk-out: dispatch to walking animation
walkout:
	GOTO 8240
	SYSTEM
	GET (100, 100)-(130, 130), d
	CLOSE
	LOCATE 1, 1
	INPUT ""; a$
	OPEN a$ + ".pct" FOR OUTPUT AS #1
	FOR i = 0 TO 125 STEP 10
		WRITE #1, sv1(i), sv2(i), sv3(i), sv4(i), sv5(i), sv6(i), sv7(i), sv8(i), sv9(i), sv10(i)
	NEXT
	SYSTEM

	'----- decide whether to walk out and which direction sprite to load
	8240 CLOSE
	IF q$ = "title" OR q$ = "death" OR q$ = "dindead" THEN RETURN
	IF wk = 1 THEN GOTO 8265
	RETURN
	RETURN

	8265 q$ = "joew2"
	IF a$ <> "1" THEN GOTO 8290
	q$ = "joew1"
	8290 IF a$ <> "2" THEN GOTO 8310
	q$ = "joew2"
	8310 IF a$ <> "3" THEN GOTO 8330
	q$ = "joew3"
	8330 IF a$ <> "4" THEN GOTO 8350
	q$ = "joew4"

	'----- load walk sprite frames
	8350 OPEN q$ + ".pct" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 8420
		INPUT #1, wa(i), wb(i)
	NEXT

	8420 sf$ = a$
	a$ = ""
	GOSUB face
	a$ = sf$
	IF a$ <> "1" THEN GOTO 8490
	GOTO 8570
	GOTO 8570
	8490 IF a$ <> "2" THEN GOTO 8520
	GOTO 8730
	GOTO 8570
	8520 IF a$ <> "3" THEN GOTO 8550
	GOTO 8900
	GOTO 8570
	8550 IF a$ <> "4" THEN GOTO 8570
	GOTO 9060

	'----- walk down animation
	8570 FOR i = 130 TO 150 STEP 2
		PUT (140, i), wa, XOR
		SOUND f3, .1
		FOR j = 1 TO 2
			SOUND 32676, 1.2
		NEXT
		PUT (140, i), wa, XOR
		i = i + 2
		PUT (140, i), wb, XOR
		SOUND f3, .1
		FOR j = 1 TO 2
			SOUND 32676, 1.2
		NEXT
		PUT (140, i), wb, XOR
	NEXT
	GOTO 9220

	'----- walk up animation
	8730 GOTO 8880
	8740 PUT (140, i), wa, XOR
	SOUND f3, .1
	FOR j = 1 TO 2
		SOUND 32676, 1.4
	NEXT
	PUT (140, i), wa, XOR
	i = i - 3
	PUT (140, i), wb, XOR
	SOUND f3, .1
	FOR j = 1 TO 2
		SOUND 32676, 1.4
	NEXT
	PUT (140, i), wb, XOR
	i = i + -2
	8880 IF i >= 120 THEN GOTO 8740
	GOTO 9220

	'----- walk right animation
	8900 FOR i = 140 TO 195 STEP 3
		PUT (i, 130), wa, XOR
		SOUND f3, .1
		FOR j = 1 TO 2
			SOUND 32676, 1
		NEXT
		PUT (i, 130), wa, XOR
		i = i + 3
		PUT (i, 130), wb, XOR
		SOUND f3, .1
		FOR j = 1 TO 2
			SOUND 32676, 1
		NEXT
		PUT (i, 130), wb, XOR
	NEXT
	GOTO 9220

	'----- walk left animation
	9060 GOTO 9210
	9070 PUT (i, 130), wa, XOR
	SOUND f3, .1
	FOR j = 1 TO 2
		SOUND 32676, 1
	NEXT
	PUT (i, 130), wa, XOR
	i = i - 3
	PUT (i, 130), wb, XOR
	SOUND f3, .1
	FOR j = 1 TO 2
		SOUND 32676, 1
	NEXT
	PUT (i, 130), wb, XOR
	i = i + -3
	9210 IF i >= 90 THEN GOTO 9070
	9220 RETURN
face:
	IF lf$ <> "4" THEN GOTO 9250
	PUT (140, 130), fl, XOR
	9250 IF lf$ <> "2" THEN GOTO 9270
	PUT (140, 130), fd, XOR
	9270 IF lf$ <> "6" THEN GOTO 9290
	PUT (140, 130), fr, XOR
	9290 IF lf$ <> "8" THEN GOTO 9310
	PUT (140, 130), fu, XOR
	9310 IF lf$ <> "1" THEN GOTO 9330
	PUT (140, 130), fdl, XOR
	9330 IF lf$ <> "7" THEN GOTO 9350
	PUT (140, 130), ful, XOR
	9350 IF lf$ <> "9" THEN GOTO 9370
	PUT (140, 130), fur, XOR
	9370 IF lf$ <> "3" THEN GOTO 9390
	PUT (140, 130), fdr, XOR

	9390 IF a$ <> "4" THEN GOTO 9410
	PUT (140, 130), fl, XOR
	9410 IF a$ <> "2" THEN GOTO 9430
	PUT (140, 130), fd, XOR
	9430 IF a$ <> "6" THEN GOTO 9450
	PUT (140, 130), fr, XOR
	9450 IF a$ <> "8" THEN GOTO 9470
	PUT (140, 130), fu, XOR
	9470 IF a$ <> "1" THEN GOTO 9490
	PUT (140, 130), fdl, XOR
	9490 IF a$ <> "7" THEN GOTO 9510
	PUT (140, 130), ful, XOR
	9510 IF a$ <> "9" THEN GOTO 9530
	PUT (140, 130), fur, XOR
	9530 IF a$ <> "3" THEN GOTO 9550
	PUT (140, 130), fdr, XOR

	9550 lf$ = a$
	RETURN

'----- joeface: load Joe face sprites, pick direction toward player
joeface:
	CLOSE
	OPEN "joed.pct" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 9710
		INPUT #1, fd(i), fu(i), fr(i), fl(i), fdl(i), fdr(i), ful(i), fur(i)
	NEXT

	9710 dx2 = jx - b
	dy2 = jy - a

	IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9760
	a$ = "1"
	9760 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9780
	a$ = "2"
	9780 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9800
	a$ = "3"
	9800 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9820
	a$ = "6"
	9820 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9840
	a$ = "9"
	9840 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9860
	a$ = "8"
	9860 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9880
	a$ = "7"
	9880 IF ((dy2 > dx2) AND ((dy2 < dx2) AND (dy2 > 0))) = 0 THEN GOTO 9900
	a$ = "4"

	9900 RETURN

'----- wilb: load and show Wilbur sprite, play death cue
wilb:
	CLOSE
	OPEN "wilb.pct" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 9960
		INPUT #1, wa(i)
	NEXT

	9960 PUT (110, 128), wa, XOR

	ti = TIMER
	FOR i = 1 TO 4
		IF (TIMER - ti) <= tmo THEN GOTO 10020
		i = 4
		GOTO 10030
	10020 i = 1
	10030 NEXT

	SOUND f3, .3
	SOUND f1, .5
	PLAY "p10"
	SOUND f3, .3
	SOUND f1, .5

	sl$ = "a"
	tt$ = "y"
	i = 0
	df$(i) = "death"
	GOTO gotoroom
'----- golf: animated golf-club swing sequence, then death event
golf:
	CLOSE
	OPEN "golf.pct" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 10200
		INPUT #1, wa(i), wb(i)
	NEXT
	10200 i = 150

	10210 PUT (135, i), wa, XOR
	SOUND f3, .1
	FOR j = 1 TO 2
		SOUND 32676, 1.2
	NEXT
	PUT (135, i), wa, XOR
	i = i - 2
	PUT (135, i), wb, XOR
	SOUND f3, .1
	FOR j = 1 TO 2
		SOUND 32676, 1.2
	NEXT
	PUT (135, i), wb, XOR
	i = i + -2
	IF i >= 135 THEN GOTO 10210
	PUT (135, 135), wa, XOR
	IF sy$ <> "y" THEN GOTO 10400
	sy$ = ""
	PUT (135, 135), wa, XOR: RETURN

	10400 i = 0
	df$(i) = "death"
	tt$ = "y"
	PLAY "p10"
	sl$ = "s"
	SOUND f3, .2
	SOUND f1, .5
	PLAY "p10"
	SOUND f3, .2
	SOUND f1, .5
	GOTO gotoroom

'----- gridwrap: wrap inventory cursor back to top-left
gridwrap:
	IF gy <= 22 THEN GOTO 10810
	gx = 21
	gy = 6
	10810 RETURN

'----- events: fire room-specific Wilbur / golf events by step count
events:
	IF doc <> 1 THEN GOTO 10840
	10840 IF q$ = "room7" AND (INT(cl * cr)) > 0 AND (INT(cl * cr)) < 8 THEN GOSUB wilb
	IF q$ = "room6" AND (INT(cl * cr)) > 8 AND (INT(cl * cr)) < 20 THEN GOSUB wilb
	IF q$ = "room8" AND (INT(cl * cr)) > 20 AND (INT(cl * cr)) < 35 THEN GOSUB wilb
	IF q$ = "room9" AND (INT(cl * cr)) > 35 AND (INT(cl * cr)) < 47 THEN GOSUB wilb
	IF q$ = "room7" AND (INT(cl * cr)) > 47 AND (INT(cl * cr)) < h9 THEN GOSUB wilb
	IF q$ = "room11" AND (INT(cl * cr)) > h9 AND (INT(cl * cr)) < t1 THEN GOSUB wilb
	IF q$ = "room4" AND (INT(cl * cr)) > t1 AND (INT(cl * cr)) < t2 THEN GOSUB wilb
	IF q$ = "room10" AND (INT(cl * cr)) > t2 AND (INT(cl * cr)) < t3 THEN GOSUB wilb
	IF q$ = "room11" AND (INT(cl * cr)) > t3 AND (INT(cl * cr)) < f3 THEN GOSUB wilb
	IF q$ = "room2" AND (INT(cl * cr)) > 0 AND (INT(cl * cr)) < 8 THEN GOSUB golf
	IF q$ = "room1" AND (INT(cl * cr)) > 8 AND (INT(cl * cr)) < 20 THEN GOSUB golf
	IF q$ = "room5" AND (INT(cl * cr)) > 20 AND (INT(cl * cr)) < 35 THEN GOSUB golf
	IF q$ = "room5" AND (INT(cl * cr)) > 35 AND (INT(cl * cr)) < 47 THEN GOSUB golf
	IF q$ = "room4" AND (INT(cl * cr)) > 47 AND (INT(cl * cr)) < h9 THEN GOSUB golf
	IF q$ = "room1" AND (INT(cl * cr)) > h9 AND (INT(cl * cr)) < t1 THEN GOSUB golf
	IF q$ = "room9" AND (INT(cl * cr)) > t1 AND (INT(cl * cr)) < t2 THEN GOSUB golf
	IF q$ = "room1" AND (INT(cl * cr)) > t2 AND (INT(cl * cr)) < t3 THEN GOSUB golf
	IF q$ = "room4" AND (INT(cl * cr)) > t3 AND (INT(cl * cr)) < f3 THEN GOSUB golf
	IF (INT(cl * cr)) <= 30 THEN GOTO 11580
	ob(37) = 1
	11580 RETURN

'----- invcur: move inventory cursor and report selected item
invcur:
	LOCATE gy, gx - 1
	PRINT " "
	IF a$ <> "2" THEN GOTO 11640
	gy = gy + 1
	GOTO 11650
	11640 GOTO 11670
	11650 IF gr((gy + 1) + (gw * gx)) <> 0 THEN GOTO 11670
	gy = gy - 1
	11670 IF a$ <> "8" THEN GOTO 11750
	gy = gy - 1
	IF gy >= 6 THEN GOTO 11750
	gy = 6
	IF gx <> 2 THEN GOTO 11740
	gx = 21
	GOTO 11750
	11740 gx = 2
	11750 LOCATE gy, gx - 1
	PRINT CHR$(26)
	IF gr((gy + 1) + (gw * gx)) <> sel AND a$ = "6" THEN sel = gr((gy + 1) + (gw * gx)): PLAY "a50b50e-30"
	IF a$ <> "l" THEN GOTO 11850
	LOCATE 1, 1
	PRINT "                                                                              "
	LOCATE 1, 1
	PRINT dn$(gr((gy + 1) + (gw * gx)))
	11850
'----- joystick poll: read STICK, set direction a$
joy:
	IF jsen <> 1 THEN RETURN
	js0 = STICK(0)
	js1 = STICK(1)
	IF js1 = 0# AND js0 = 0 THEN RETURN
	IF js0 >= 40 THEN GOTO 11920
	a$ = "4"
	11920 IF js0 <= 120 THEN GOTO 11940
	a$ = "6"
	11940 IF js1 >= 40 THEN GOTO 11960
	a$ = "8"
	11960 IF js1 <= 120 THEN GOTO 11980
	a$ = "2"
	11980 IF js1 < 40 AND js0 > 120 THEN a$ = "9"
	IF js1 < 40 AND js0 < 40 THEN a$ = "7"
	IF js0 > 120 AND js1 > 120 THEN a$ = "3"
	IF js0 < 40 AND js1 > 120 THEN a$ = "1"
	IF a$ = "1" OR a$ = "2" OR a$ = "3" OR a$ = "4" OR a$ = "5" OR a$ = "6" OR a$ = "7" OR a$ = "8" OR a$ = "9" THEN vk$ = ""
	RETURN

'----- enable joystick fire buttons
strigon:
	IF jsen <> 1 THEN RETURN
	STRIG(0) ON
	STRIG(2) ON
	STRIG(4) ON
	STRIG(6) ON
	RETURN

'----- button: look
vlook:
	IF vk$ <> "l" THEN GOTO 12250
	GOTO vact
	12250 a$ = "l"
	vk$ = "l"
	RETURN

'----- button: action
vact:
	IF vk$ <> "a" THEN GOTO 12310
	GOTO vget
	12310 a$ = "a"
	vk$ = "a"
	RETURN

'----- button: get
vget:
	IF vk$ <> "g" THEN GOTO 12370
	GOTO vuse
	12370 a$ = "g"
	vk$ = "g"
	RETURN

'----- button: use
vuse:
	IF vk$ <> "u" THEN GOTO 12430
	GOTO strigoff
	12430 a$ = "u"
	vk$ = "u"
	RETURN

'----- disable joystick fire buttons
strigoff:
	FOR i = 0 TO 6 STEP 2
		STRIG(i) OFF
	NEXT
	RETURN

'----- initialise the mouse driver (INT 33h)
mouseinit:
	IF msen <> 1 THEN RETURN
	mreg.ax = 0
	CALL INTERRUPT(mvint, mreg, mout)
	IF mout.ax = 0 THEN msen = 0
	mlb = 0
	mrb = 0
	cdrawn = 0
	' arow$(0) = "XXXXXXXX........"
	' arow$(1) = "X0000000X......."
	' arow$(2) = "X000XXXX........"
	' arow$(3) = "X0000X.........."
	' arow$(4) = "X0X000X........."
	' arow$(5) = "X0XX000X........"
	' arow$(6) = "X0X.X000X......."
	' arow$(7) = "X0X..X000X......"
	' arow$(8) = ".X....X0X......."
	' arow$(9) = ".......X........"
	' arow$(10) = "................"
	' arow$(11) = "................"
	' arow$(12) = "................"
	' arow$(13) = "................"
	' arow$(14) = "................"
	' arow$(15) = "................"

	' arow$(0) = "XXXXX..........."
	' arow$(1) = "X000X..........."
	' arow$(2) = "X00X............"
	' arow$(3) = "X0X0X..........."
	' arow$(4) = "XX.X0X.........."
	' arow$(5) = "....X..........."
	' arow$(6) = "................"
	' arow$(7) = "................"
	' arow$(8) = "................"
	' arow$(9) = "................"
	' arow$(10) = "................"
	' arow$(11) = "................"
	' arow$(12) = "................"
	' arow$(13) = "................"
	' arow$(14) = "................"
	' arow$(15) = "................"

	cshp = 0
	hovr = 8
	FOR sshp = 0 TO 4
		GOSUB setgrid
		npc = 0
		FOR mr = 0 TO 15
			FOR mc = 0 TO 15
				mch$ = MID$(arow$(mr), mc + 1, 1)
				IF mch$ = "X" THEN px(sshp, npc) = mc: py(sshp, npc) = mr: pc(sshp, npc) = 1: npc = npc + 1
				IF mch$ = "0" THEN px(sshp, npc) = mc: py(sshp, npc) = mr: pc(sshp, npc) = 2: npc = npc + 1
			NEXT
		NEXT
		npix(sshp) = npc
	NEXT
	RETURN

'----- select the cursor grid for shape sshp (0=NW 1=up 2=down 3=right 4=left)
setgrid:
	FOR mr = 0 TO 15
		arow$(mr) = "................"
	NEXT
	IF sshp = 0 THEN GOSUB grdnw
	IF sshp = 1 THEN GOSUB grdup
	IF sshp = 2 THEN GOSUB grddn
	IF sshp = 3 THEN GOSUB grdrt
	IF sshp = 4 THEN GOSUB grdlf
	RETURN

'----- cursor pixel grids (X = outline/gray, 0 = fill/blue, . = clear)
grdnw:
	arow$(0) = "X..............."
	arow$(1) = "XX.............."
	arow$(2) = "X0X............."
	arow$(3) = "X00X............"
	arow$(4) = "X000X..........."
	arow$(5) = "X0XX............"
	arow$(6) = "XX.............."
	RETURN

'----- north / up exit arrow
grdup:
	arow$(0) = "...X............"
	arow$(1) = "..X0X..........."
	arow$(2) = "..X0X..........."
	arow$(3) = ".X000X.........."
	arow$(4) = "X00000X........."
	arow$(5) = "..X0X..........."
	arow$(6) = "..X0X..........."
	arow$(7) = "..X0X..........."
	RETURN

'----- south / down exit arrow
grddn:
	arow$(0) = "..X0X..........."
	arow$(1) = "..X0X..........."
	arow$(2) = "..X0X..........."
	arow$(3) = "X00000X........."
	arow$(4) = ".X000X.........."
	arow$(5) = "..X0X..........."
	arow$(6) = "..X0X..........."
	arow$(7) = "...X............"
	RETURN

'----- east / right exit arrow
grdrt:
	arow$(0) = "...X............"
	arow$(1) = "...0X..........."
	arow$(2) = "XXX00XX........."
	arow$(3) = "0000000X........"
	arow$(4) = "XXX00XX........."
	arow$(5) = "...0X..........."
	arow$(6) = "...X............"
	RETURN

'----- west / left exit arrow
grdlf:
	arow$(0) = "....X..........."
	arow$(1) = "...X0..........."
	arow$(2) = ".XX00XXX........"
	arow$(3) = "X0000000........"
	arow$(4) = ".XX00XXX........"
	arow$(5) = "...X0..........."
	arow$(6) = "....X..........."
	RETURN

'----- poll mouse: move cursor and read buttons
mousepoll:
	IF msen <> 1 THEN RETURN
	mreg.ax = 3
	CALL INTERRUPT(mvint, mreg, mout)
	mx = mout.cx \ 2
	my = mout.dx
	IF mx < 0 THEN mx = 0
	IF mx > 304 THEN mx = 304
	IF my < 0 THEN my = 0
	IF my > 190 THEN my = 190
	b = (mx \ 4) * 4 + 2
	a = (my \ 4) * 4 + 2
	IF b > 302 THEN b = 302
	IF a < 10 THEN a = 10
	IF a > 190 THEN a = 190
	IF mxyon = 1 THEN GOSUB mxytick
	GOSUB hovexit
	IF cdrawn = 0 OR mx <> cox OR my <> coy THEN GOSUB erasecur: GOSUB drawcur
	IF (mout.bx AND 1) <> 0 AND mlb = 0 THEN a$ = "a": GOSUB msnap
	IF (mout.bx AND 2) <> 0 AND mrb = 0 THEN a$ = "l": GOSUB msnap
	mlb = (mout.bx AND 1)
	mrb = (mout.bx AND 2)
	RETURN

'----- draw software cursor: save background, then paint the arrow (1=gray, 2=blue)
drawcur:
	GET (mx, my)-(mx + 15, my + 9), curbuf
	FOR mi = 0 TO npix(cshp) - 1
		PSET (mx + px(cshp, mi), my + py(cshp, mi)), pc(cshp, mi)
	NEXT
	cox = mx: coy = my: cdrawn = 1
	RETURN

'----- erase software cursor: restore saved background
erasecur:
	IF cdrawn = 1 THEN PUT (cox, coy), curbuf, PSET
	cdrawn = 0
	RETURN

'----- snap click to nearest hotspot within snr px (0 = off/exact)
'----- ABS box just prefilters; sdd<snd is the real test = a circle of radius snr (Euclidean)
'----- breaks at first oy=0 exactly like action, so it never snaps to an entry action can't reach
msnap:
	IF snr <= 0 THEN RETURN
	' tie-break: a hotspot exactly under the cursor's own cell wins over an expanded (snapped) neighbour
	FOR sni = 1 TO 257
		IF oy(sni) = 0# THEN EXIT FOR
		IF ox(sni) = b AND oy(sni) = a THEN RETURN
	NEXT
	snd = snr * snr + 1
	snx = -1
	FOR sni = 1 TO 257
		IF oy(sni) = 0# THEN EXIT FOR
		sdx = mx - ox(sni)
		sdy = my - oy(sni)
		IF ABS(sdx) <= snr AND ABS(sdy) <= snr THEN
			sdd = sdx * sdx + sdy * sdy
			IF sdd < snd THEN
				snd = sdd
				snx = ox(sni)
				sny = oy(sni)
			END IF
		END IF
	NEXT
	IF snx >= 0 THEN b = snx: a = sny
	RETURN

'----- near a walkout exit? morph cursor to point the way the player leaves (exitcursor)
'----- reads tg$ direction (wn=up ws=down we=right ww=left); reverts to NW arrow otherwise
hovexit:
	IF exsen <> 1 THEN RETURN
	newshp = 0
	hvdir$ = ""
	hvb = hovr * hovr + 1
	FOR hvi = 1 TO 257
		IF oy(hvi) = 0# THEN EXIT FOR
		hvo = CINT(oi(hvi))
		IF LEFT$(tg$(hvo), 1) = "w" THEN
			hvx = mx - ox(hvi)
			hvy = my - oy(hvi)
			IF ABS(hvx) <= hovr AND ABS(hvy) <= hovr THEN
				hvd = hvx * hvx + hvy * hvy
				IF hvd < hvb THEN hvb = hvd: hvdir$ = RIGHT$(tg$(hvo), 1)
			END IF
		END IF
	NEXT
	IF hvb <= hovr * hovr THEN
		IF hvdir$ = "n" THEN newshp = 1
		IF hvdir$ = "s" THEN newshp = 2
		IF hvdir$ = "e" THEN newshp = 3
		IF hvdir$ = "w" THEN newshp = 4
	END IF
	IF newshp = cshp THEN RETURN
	GOSUB erasecur
	cshp = newshp
	RETURN

'----- install a custom mouse cursor shape (INT 33h AX=9)
setcursor:
	IF msen <> 1 OR mcur < 1 THEN RETURN
	FOR mi = 0 TO 31
		cmask(mi) = 0
	NEXT
	mhsx = 7: mhsy = 7: mxor = 0: mraw = 0
	IF mcur = 1 THEN GOSUB shArrow
	IF mcur = 2 THEN GOSUB shCross
	IF mcur = 3 THEN GOSUB shBox
	IF mcur = 4 THEN GOSUB shCross: mxor = 1
	IF mcur = 5 THEN GOSUB shArrowNE
	IF mraw = 0 THEN
		FOR mi = 0 TO 15
			IF mxor = 1 THEN cmask(mi) = &HFFFF ELSE cmask(mi) = NOT cmask(16 + mi)
		NEXT
	END IF
	mregx.ax = 9
	mregx.bx = mhsx
	mregx.cx = mhsy
	mregx.dx = VARPTR(cmask(0))
	mregx.es = VARSEG(cmask(0))
	CALL INTERRUPTX(mvint, mregx, moutx)
	RETURN

'----- cursor shape: NW arrow (user-drawn), black outline + fill, tip top-left
shArrowNE:
	mhsx = 0: mhsy = 0
	cmask(16) = &HFF00
	cmask(17) = &H8080
	cmask(18) = &H8F00
	cmask(19) = &H8400
	cmask(20) = &HA200
	cmask(21) = &HB100
	cmask(22) = &HA880
	cmask(23) = &HA440
	cmask(24) = &H4280
	cmask(25) = &H0100
	cmask(26) = &H0000
	cmask(27) = &H0000
	cmask(28) = &H0000
	cmask(29) = &H0000
	cmask(30) = &H0000
	cmask(31) = &H0000
	RETURN

'----- cursor shape: arrow (hotspot at tip)
shArrow:
	mhsx = 0: mhsy = 0
	cmask(16) = &H8000
	cmask(17) = &HC000
	cmask(18) = &HE000
	cmask(19) = &HF000
	cmask(20) = &HF800
	cmask(21) = &HFC00
	cmask(22) = &HFE00
	cmask(23) = &HFF00
	cmask(24) = &HFF80
	cmask(25) = &HFFC0
	RETURN

'----- cursor shape: crosshair (hotspot centre)
shCross:
	mhsx = 7: mhsy = 7
	cmask(16) = &H0100
	cmask(17) = &H0100
	cmask(18) = &H0100
	cmask(19) = &H0100
	cmask(20) = &H0100
	cmask(21) = &H0100
	cmask(22) = &H0100
	cmask(23) = &HFFFE
	cmask(24) = &H0100
	cmask(25) = &H0100
	cmask(26) = &H0100
	cmask(27) = &H0100
	cmask(28) = &H0100
	cmask(29) = &H0100
	RETURN

'----- cursor shape: box / target (hotspot centre)
shBox:
	mhsx = 7: mhsy = 7
	cmask(18) = &H3FF8
	cmask(19) = &H2008
	cmask(20) = &H2008
	cmask(21) = &H2008
	cmask(22) = &H2008
	cmask(23) = &H2008
	cmask(24) = &H2008
	cmask(25) = &H2008
	cmask(26) = &H2008
	cmask(27) = &H2008
	cmask(28) = &H3FF8
	RETURN

'----- load object display names from object.pac
loadnames:
	CLOSE
	OPEN "object.pac" FOR INPUT AS #1
	FOR i = 1 TO 50
		IF EOF(1) THEN GOTO 12580
		INPUT #1, b, dn$(b)
	NEXT
	12580 CLOSE
	RETURN

'----- combine/use objects and wait for completion
usecombine:
	IF gr((gy + 1) + (gw * gx)) = 28 AND sel = 18 THEN LOCATE 1, 1: PRINT "You find a key hidden inside the fruit.": ob(22) = 1: done$ = "y"
	IF ob(11) = 1 AND ob(24) = 1 AND sel = 25 THEN LOCATE 1, 1: PRINT "You decode and combine the formula": ob(24) = 0: ob(12) = 0: ob(36) = 1: done$ = "y"
	IF gr((gy + 1) + (gw * gx)) = 29 AND sel = 34 THEN LOCATE 1, 1: PRINT "You insert the chemicals into the syringe.": ob(35) = 1: ob(29) = 0: ob(34) = 0: done$ = "y"
	ti = TIMER
	12800 IF done$ = "" THEN GOTO 12830
	IF (TIMER - ti) >= tmo THEN GOTO 12830
	GOTO 12800
	12830 RETURN

'----- trigger room4 golf event
trigger:
	IF doc = 2 OR doc = 1 THEN RETURN
	IF q$ = "room4" AND ob(43) = 1 THEN GOTO 13970
	GOTO 14010
	13970 sy$ = "y": GOSUB golf: PUT (135, 135), wa, XOR
	doc = 1: ti = TIMER
	RETURN
	14010 RETURN

	ti = TIMER
	doc = 1
	PRINT tmo
	PALETTE 1, 8
	PALETTE 2, 7
	PALETTE 3, 11
	KEY OFF
	14090 a$ = INKEY$
	IF a$ <> "" THEN GOTO 14120
	GOTO 14090
	14120 GOTO 14250
	14250 CALL Credits

'----- endgame: roll credits, then quit or restart
endgame:
	IF ob(43) <> 1 THEN GOTO 14290
	CALL Credits: SYSTEM
	GOTO 14300
	14290 CALL Credits: RUN
	14300 SYSTEM
	PRINT ERL
	SYSTEM
'----- fight: inject the mental patient or warn on failed combat
fight:
	IF (a$ = "u" AND sel = 35) = 0 THEN GOTO 14360
	GOTO 14460
	IF (TIMER - ti) > 5 THEN GOSUB golf

	14360 IF a$ <> "u" THEN GOTO 14390
	LOCATE 1, 1
	PRINT "He sees what your trying do!                "
	14390 IF a$ <> "a" THEN GOTO 14420
	LOCATE 1, 1
	PRINT "Your no match for him in fair combat!       "
	14420 IF a$ <> "l" THEN GOTO 14450
	LOCATE 1, 1
	PRINT "The mental patient is preparing to kill you!"
	14450 RETURN

	'----- successful injection: patient crumbles
	14460 SOUND f3, .2
	SOUND f1, .5
	SOUND 32676, 2
	SOUND f3, .2
	SOUND f1, .5
	doc = 2
	LOCATE 1, 1
	PRINT "You quickly inject him and he crumbles into a distorted heap. "
	a$ = "n"
	PUT (135, 135), wa, XOR
	14570 RETURN

'----- death: play death music, wait for key, then continue
death:
	ti = TIMER
	CALL DeathMusic
	14600 IF (TIMER - ti) <= tmo THEN GOTO 14620
	GOTO 14630
	14620 GOTO 14600
	14630 a$ = INKEY$
	IF a$ <> "" THEN GOTO 14660
	GOTO 14630

	14660 IF q$ <> "dindead" THEN GOTO 14700
	q$ = "death"
	GOSUB loadroom
	GOTO 14600

	14700 q$ = "smart"
	GOTO inv

'----- lookmap: read notes or display the map for the current tile
lookmap:
	IF gr((gy + 1) + (gw * gx)) <> 16 THEN GOTO 14960
	GOTO 15030

	14960 IF gr((gy + 1) + (gw * gx)) = 3 OR gr((gy + 1) + (gw * gx)) = 21 THEN CALL NotesSub: RETURN
	IF gr((gy + 1) + (gw * gx)) = 10 OR gr((gy + 1) + (gw * gx)) = 9 THEN CALL NotesSub: RETURN
	IF gr((gy + 1) + (gw * gx)) = 19 THEN CALL NotesSub: RETURN
	RETURN

'----- show the map picture and wait for a keypress
	15030 PALETTE 1, 6
	PALETTE 2, 4
	PALETTE 3, 8
	DEF SEG = &HB800: BLOAD "map1.pic", 0: DEF SEG
	KEY OFF
	15070 a$ = INKEY$
	IF a$ <> "" THEN GOTO 15100
	GOTO 15070

	15100 done$ = "y"
	PALETTE 3, 6
	RETURN

'----- burn: flickering fire animation until a key is pressed
burn:
	KEY OFF
	DEF SEG = &HB800: BLOAD "burn.pic", 0: DEF SEG
	FOR i = 1 TO 300
		PALETTE 1, 14
		PALETTE 2, 12
		PALETTE 3, 4
		FOR j = 1 TO 10
			SOUND 32676, .1
		NEXT
		PALETTE 1, 15
		PALETTE 2, 14
		PALETTE 3, 12
		FOR j = 1 TO 10
			SOUND 32676, .1
		NEXT
		a$ = INKEY$
		IF a$ = "" THEN GOTO 15300
		GOTO 15316
		15300 i = 1
	NEXT

	'----- restart the game
	15316 RUN
	GOTO 16750
	16750 GOTO 18680
	18680 END

REM $STATIC

'----- Credits / ending sequence
SUB Credits
	DIM e0(600) AS INTEGER
	SCREEN 1
	KEY OFF
	PALETTE 1, 8: PALETTE 2, 4: PALETTE 3, 14
	IF ob(43) <> 1 THEN GOTO 15700

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

'----- DeathMusic: play one of four random dirges
SUB DeathMusic
	RANDOMIZE TIMER
	mt = INT(RND * 4)
	IF mt <> 1 THEN GOTO 15370
	GOTO 15440
	GOTO 15440
15370 IF mt <> 2 THEN GOTO 15400
	GOTO 15460
	GOTO 15440
15400 IF mt <> 3 THEN GOTO 15430
	GOTO 15490
	GOTO 15440
15430 GOTO 15510

15440 PLAY "<<<g-2g8a+8f+8e8d-3e4f+5f+5e-5e3>d2>>"
	EXIT SUB

15460 PLAY "<<<d+8e-8<a8g8f3b8g8f+8e3"
	PLAY "  g-2g8a8f+8e8d-3e4f+5c8c8c3>>>"
	EXIT SUB

15490 PLAY "<<<c3c3d-5d-5c3c3<b-5a-5>c3c3d-5e-5c3c3>>>"
	EXIT SUB

15510 PLAY "<g8a8b-8b8<c8g8a8b-8a8a8b8a8>>"
	EXIT SUB
END SUB

'----- DoorOpen: animate room3 door opening
SUB DoorOpen
	IF dop$ = "d" OR q$ <> "room3" OR ob(50) = 0 THEN EXIT SUB
	IF ob(42) <> 1 THEN GOTO 10570
	GOTO 10720

	'----- play full open animation
10570 FOR j = 1 TO 2
		SOUND 32676, 1
	NEXT
	PUT (175, 109), do1, PSET
	FOR j = 1 TO 2
		SOUND 32676, 1
	NEXT
	PUT (175, 109), do2, PSET
	FOR j = 1 TO 2
		SOUND 32676, 1
	NEXT
	PUT (175, 109), do3, PSET
	FOR j = 1 TO 2
		SOUND 32676, 1
	NEXT

10720 PUT (175, 109), do4, PSET
	IF ob(42) = 1 THEN GOTO 10750
	PLAY "<<f6p20d7p20g-7p20e-7p20a5>>"
10750 ob(42) = 1
	dop$ = "d"
	EXIT SUB
END SUB

'----- InitVars: set up global constants
SUB InitVars
	f1 = 50: f2 = 500: f3 = 100: f4 = 200: f5 = 1000: f8 = 700
	f6 = 300: f7 = 450: f10 = 75
	pk = 1047
	jx = 150: jy = 156
	f9 = 10000
	cr = 1 / 60: cl = 0: h9 = 59: h10 = 119: h11 = 179
	t1 = 65: t2 = 74: t3 = 88: gw = 71
END SUB
SUB Intro

	'----- screen + key setup
	SCREEN 1
	RANDOMIZE 0#
	ifc = 0
	itt = 0
	it0 = TIMER
	KEY 16, CHR$(0) + CHR$(1)
	KEY(16) ON
	PALETTE 3, 6
	PALETTE 1, 2
	PALETTE 2, 11
	KEY OFF
	KEY 16, CHR$(0) + CHR$(1)
	KEY(16) ON

	'----- buffers + load car image
	DIM ec(1000) AS INTEGER
	DIM r1(130) AS INTEGER
	DIM r2(130) AS INTEGER
	DEF SEG = &HB800: BLOAD "carr.pic", 0: DEF SEG
	cy = 133
	GET (8, 133)-(105, 175), ec
	PUT (8, 133), ec, XOR
	LINE (8, 155)-(105, 145), 3
	LINE (75, 175)-(120, 170), 3

	FOR n = 1 TO 2
		SOUND 32676, 1
	NEXT

	'----- drive car across screen
	FOR cx = 8 TO 220 STEP 4
		cy = cy - .5
		ifc = ifc + 1
		PUT (cx, cy), ec, XOR
		GOSUB 17070
		PUT (cx, cy), ec, XOR
	NEXT
	GOTO 17160

	'----- engine sweep tone
	17070 tc = 50
	17080 SOUND tc, .06
	SOUND f3, .06
	k$ = INKEY$
	IF (k$) <> "s" THEN GOTO 17130
	GOTO 18640
	17130 tc = tc + 18
	IF tc <= 200 THEN GOTO 17080
	RETURN

	'----- pause then hill scene
	17160 GOTO 17180
	17170 tc = tc + 1
	IF INKEY$ = "s" THEN GOTO 18640
	17180 IF tc <= 500 THEN GOTO 17170
	DEF SEG = &HB800: BLOAD "hill.pic", 0: DEF SEG
	PALETTE 2, 11
	PALETTE 3, 3
	KEY OFF
	tc = 0#

	'----- lightning flashes
	FOR n = 1 TO 35
		ifc = ifc + 1
		GOSUB 17070
		IF RND <= .8 THEN GOTO 17310
		COLOR 15
		tc = 1
	17280 SOUND 32676, .04
		tc = tc + 1
		IF tc <= 2 THEN GOTO 17280
	17310 COLOR 0
	NEXT

	'----- descending thunder
	tc = 200
	17340 SOUND tc, .1
	SOUND f10, .1
	SOUND 32676, 1
	tc = tc - 10
	IF INKEY$ = "s" THEN GOTO 18640
	IF tc >= 50 THEN GOTO 17340
	COLOR 15
	COLOR 0
	tc = 1
	17420 tc = tc + 1
	IF INKEY$ = "s" THEN GOTO 18640
	IF tc <= 500 THEN GOTO 17420

	'----- second descending tone
	tc = 200
	17450 SOUND tc, .1
	SOUND f1, .2
	tc = tc - 30
	IF INKEY$ = "s" THEN GOTO 18640
	IF tc >= 50 THEN GOTO 17450
	SOUND f6, .1
	GOTO 17510
	17510 tc = tc + 1
	IF INKEY$ = "s" THEN GOTO 18640
	IF tc <= 1000 THEN GOTO 17510

	'----- enter house scene
	PALETTE 1, 8
	PALETTE 2, 1
	PALETTE 3, 6
	KEY OFF
	DEF SEG = &HB800: BLOAD "enter.pic", 0: DEF SEG
	GOSUB 18310
	IF it0 >= 0 THEN itt = itt + (TIMER - it0): it0 = -1
	GOTO 17780

	'----- talk scene
	17590 KEY OFF
	PALETTE 1, 12
	PALETTE 2, 6
	PALETTE 3, 8
	DEF SEG = &HB800: BLOAD "talk.pic", 0: DEF SEG
	k$ = INKEY$
	17640 GOSUB 17850
	SOUND 32576, INT(RND * 9)
	k$ = INKEY$
	IF k$ = "s" THEN skp = 1: RETURN
	IF (k$) <> "" THEN GOTO 17690
	GOTO 17640
	GOTO 17780

	'----- restore enter scene after talk
	17690 FOR n = 1 TO 24
		LOCATE 25, 1
		PRINT " "
	NEXT
	KEY OFF
	PALETTE 1, 8
	PALETTE 2, 1
	PALETTE 3, 6
	DEF SEG = &HB800: BLOAD "enter.pic", 0: DEF SEG
	DEF SEG
	RETURN

	'----- title screen
	17780 PALETTE 2, 9
	PALETTE 1, 11
	PALETTE 3, 1
	KEY OFF
	DEF SEG = &HB800: BLOAD "title.pic", 0: DEF SEG
	GOSUB 18200
	SOUND 32676, 1
	GOTO 18640

	'----- speech warble tone
	17850 tw = 50
	17860 SOUND f3, .05
	SOUND tw, .05
	SOUND (450 - tw) / 2, .05
	tw = tw + 10
	IF tw <= 250 THEN GOTO 17860
	RETURN
	IF tf <> 1 THEN GOTO 17930
	17930 k$ = INKEY$
	IF (k$) <> "s" THEN GOTO 17960
	GOTO 18640
	17960 SOUND 32576, INT(RND * 9)
	tn = tn + 1
	IF (INT(RND * 4) + 2) <= tn THEN GOTO 18010
	GOTO 17850
	18010
	GOTO 18160

	'----- palette cycle on exit
	18030 GOTO 18140
	18040 FOR n = 1 TO 1000
	NEXT
	IF tc <> 1 THEN GOTO 18080
	PALETTE pi, 15
	18080 IF tc <> 2 THEN GOTO 18100
	PALETTE pi, 7
	18100 IF tc <> 3 THEN GOTO 18120
	PALETTE pi, 8
	18120 IF tc <> 4 THEN GOTO 18140
	PALETTE pi, 0
	18140 pi = pi + 1
	IF pi <= 3 THEN GOTO 18040
	18160 tc = tc + 1
	IF tc <= 4 THEN GOTO 18030
	SCREEN 0
	SYSTEM

	'----- title music
	18200 KEY 16, CHR$(0) + CHR$(1)
	KEY(16) ON
	PLAY "<d4d8d8c+8<b8>c+4d8e4<<a8d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY ">>d8d8c+8<b8>c+4d8e4<<a8d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "f8a4g8f4a8>c4<b-8a4>c8e4d8c+8<b8a8g8f8e8"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "d4d8d8c+8<b8>c+4d8e4<<a8d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY ">>d8d8c+8<b8>c+4d8e4<<a8d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "f8a4g8f4a8>c4<b-8a4>c8e4d8c+8<b8a8g8f8e8"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "<d8c+8d8e4f8c+4d4"
	RETURN

	'----- animate Joe walking + dialogue
	18310 CLOSE
	w$ = "joew2"
	OPEN (w$) + ".pct" FOR INPUT AS #1
	tc = 0
	18370 INPUT #1, r1(tc), r2(tc)
	tc = tc + 1
	IF tc <= 125 THEN GOTO 18370
	wc = wc + 1
	tc = 150
	18420 PUT (143, tc), r1, XOR
	IF INKEY$ = "s" THEN GOTO 18640
	IF it0 >= 0 THEN ifc = ifc + 1
	GOSUB 17850

	FOR n = 1 TO 2
		SOUND 32676, .3
	NEXT
	PUT (143, tc), r1, XOR
	IF tc <> 130 THEN GOTO 18530

	FOR n = 1 TO 10000
	NEXT
	tf = 0#
	IF it0 >= 0 THEN itt = itt + (TIMER - it0): it0 = -1: GOSUB introlog
	GOSUB 17590
	IF skp = 1 THEN GOTO 18640
	18530 tf = 1
	tc = tc - 2
	PUT (143, tc), r2, XOR
	IF INKEY$ = "s" THEN GOTO 18640
	IF it0 >= 0 THEN ifc = ifc + 1
	GOSUB 17850

	FOR n = 1 TO 2
		SOUND 32676, .3
	NEXT
	PUT (143, tc), r2, XOR
	tc = tc - 2
	IF tc >= 116 THEN GOTO 18420
	RETURN

	'----- skip / cleanup exit
	18640 IF it0 >= 0 THEN itt = itt + (TIMER - it0): it0 = -1: GOSUB introlog
	it0 = -1
	ERASE ec
	ERASE r1
	ERASE r2
	EXIT SUB

	'----- write intro frame/time log
introlog:
	IF sfps <> 1 THEN RETURN
	OPEN "intro.log" FOR APPEND AS #2
	PRINT #2, ifc; itt
	CLOSE #2
	RETURN

END SUB

'----- mark inventory grid slots matching held objects
SUB InvGrid
	FOR gx = 2 TO 21 STEP 19
		FOR gy = 5 TO 23
			FOR i = 1 TO 40
				IF gr((gy + 1) + (gw * gx)) <> gp(i) THEN GOTO 14770
				gm = 1
14770 NEXT
			IF gm = 1 THEN GOTO 14810
			LOCATE gy, gx - 1
			PRINT "*"
14810 gm = 0
		NEXT
	NEXT

	'----- snapshot grid contents into gp()
	i = 0
	FOR gx = 2 TO 21 STEP 19
		FOR gy = 5 TO 23
			i = i + 1
			gp(i) = gr((gy + 1) + (gw * gx))
		NEXT
	NEXT

	gy = 6
	gx = 2
	EXIT SUB
END SUB

'----- create/read dark.ini settings (showfps, joystick)
SUB LoadConfig
	CLOSE
	OPEN "dark.ini" FOR APPEND AS #1
	IF LOF(1) = 0 THEN
		PRINT #1, "; Dark Visions settings"
		PRINT #1, "; showfps=1 shows main loop speed top right + intro pace"
		PRINT #1, "showfps=0"
		PRINT #1, "; joystick=1 enables joystick/gamepad control (off avoids stray input)"
		PRINT #1, "joystick=0"
		PRINT #1, "; mouse=1 enables mouse cursor + hardware pointer (needs a mouse driver)"
		PRINT #1, "mouse=0"
		PRINT #1, "; mousecursor: 0 driver default, 1 arrow, 2 crosshair, 3 box, 4 crosshair(xor)"
		PRINT #1, "mousecursor=1"
		PRINT #1, "; mousesnap: click pulls to nearest hotspot within N pixels (0=off/exact)"
		PRINT #1, "mousesnap=6"
		PRINT #1, "; exitcursor=1 changes the pointer to a direction arrow near room exits"
		PRINT #1, "exitcursor=1"
		PRINT #1, "; mousexy=1 shows live mouse x,y + snapped hit point bottom row (debug; needs mouse=1)"
		PRINT #1, "mousexy=0"
		PRINT #1, "; lookmiss=1 shows a random 'nothing to see' line after looking 3x at an empty spot"
		PRINT #1, "lookmiss=1"
	END IF
	CLOSE

	snr = 6
	exsen = 1
	nfon = 1
	OPEN "dark.ini" FOR INPUT AS #1
	DO WHILE NOT EOF(1)
		LINE INPUT #1, ln$
		ln$ = LTRIM$(RTRIM$(ln$))
		c$ = LEFT$(ln$, 1)
		IF ln$ <> "" AND c$ <> ";" AND c$ <> "#" AND c$ <> "'" AND c$ <> "[" THEN
			eq = INSTR(ln$, "=")
			IF eq >= 2 THEN
				k$ = LCASE$(LTRIM$(RTRIM$(LEFT$(ln$, eq - 1))))
				v$ = LCASE$(LTRIM$(RTRIM$(MID$(ln$, eq + 1))))
				tv = 0
				IF v$ = "1" OR v$ = "true" OR v$ = "yes" OR v$ = "on" THEN tv = 1
				IF k$ = "showfps" THEN sfps = tv
				IF k$ = "joystick" THEN jsen = tv
				IF k$ = "mouse" THEN msen = tv
				IF k$ = "mousecursor" THEN mcur = VAL(v$)
				IF k$ = "mousesnap" THEN snr = VAL(v$)
				IF k$ = "exitcursor" THEN exsen = tv
				IF k$ = "mousexy" THEN mxyon = tv
				IF k$ = "lookmiss" THEN nfon = tv
			END IF
		END IF
	LOOP
	CLOSE

	fpst = TIMER
	fpsc = 0
	mvint = &H33
END SUB

'----- display the note/journal for the object under the cursor
SUB NotesSub
	KEY OFF
	PALETTE 1, 7
	PALETTE 2, 2
	PALETTE 3, 15
	DEF SEG = &HB800: BLOAD "book.pic", 0: DEF SEG
	ti = TIMER
	cl = cl + 40

	'----- pause for the timeout interval
	12900 IF (TIMER - ti) >= tmo THEN GOTO 12920
	GOTO 12900
	12920 done$ = "y"
	CLS
	LOCATE 1, 1
	PALETTE 3, 6

	'----- dispatch to the matching note text by object id
	IF gr((gy + 1) + (gw * gx)) <> 21 THEN GOTO 12980
	GOTO 13070
	12980 IF gr((gy + 1) + (gw * gx)) <> 3 THEN GOTO 13000
	GOTO 13280
	13000 IF gr((gy + 1) + (gw * gx)) <> 10 THEN GOTO 13020
	GOTO 13400
	13020 IF gr((gy + 1) + (gw * gx)) <> 9 THEN GOTO 13040
	GOTO 13490
	13040 IF gr((gy + 1) + (gw * gx)) <> 19 THEN GOTO 13060
	GOTO 13710
	13060

	'----- zombie serum (MPTP) note
	13070 PRINT "   The Zombie Syrem        "
	PRINT "MPTP this formula harbors  "
	PRINT "the most dangerous compound"
	PRINT "that will render a victim  "
	PRINT "paralyzed up to days at a  "
	PRINT "time. The conclusive test  "
	PRINT "on human subjects has yielded"
	PRINT "promising results.     "
	PRINT "    The subjects though are"
	PRINT "heightened in strength and "
	PRINT "reflexes making them harder"
	PRINT "to control. We have started"
	PRINT "the use of torture to stop "
	PRINT "this problem. It is almost "
	PRINT "safer to leave them on it  "
	PRINT "permantly so they do not   "
	PRINT "overthrow the doctors.     "
	13240 a$ = INKEY$
	IF a$ <> "" THEN GOTO 13270
	GOTO 13240
	13270 EXIT SUB

	'----- hidden money note
	13280 PRINT "The other doctors have become weary"
	PRINT "as the research money is drying up. "
	PRINT "I have taken the liberty to hide the"
	PRINT "rest so they do not get gready and  "
	PRINT "steal it. The money is now boarded up"
	PRINT "in the headboard of my bed not even  "
	PRINT "the servants know about it.Time is the"
	PRINT "barrier to the place of the damned."
	13360 a$ = INKEY$
	IF a$ <> "" THEN GOTO 13390
	GOTO 13360
	13390 EXIT SUB

	'----- coded notes / code book note
	13400 PRINT "I have concluded another successful"
	PRINT "expirement. This time though the other"
	PRINT "doctors have become gready and want "
	PRINT "possession of the notes. I have given"
	PRINT "them to servants and coded the notes"
	PRINT "the code book is now hidden so the "
	PRINT "other doctors cannot steal my break"
	PRINT "though."
	GOTO 13360

	'----- patient roster note
	13490 PRINT "Patient: Naton McDaniel     "
	PRINT "Disorder: Paranoid Schitsofrension"
	PRINT "Notes: Naton is very nervous and "
	PRINT "complains of voices, often talks in"
	PRINT "gibberish."
	PRINT "ID:12443"
	PRINT ""
	PRINT "Patient: Havos Lobos     "
	PRINT "Disorder: Severe Delusions"
	PRINT "Notes: Havos not only see's and"
	PRINT "hears things but they become his"
	PRINT "reality. He is very dangerous"
	PRINT "ID:385938"
	PRINT ""
	PRINT "Patient: Gary Coleman     "
	PRINT "Disorder: Phyocosis dementia"
	PRINT "Notes: Gary has become a leader"
	PRINT "of the other patients. He has"
	PRINT "a fixation with knives and human"
	PRINT "blood and sacrifice. Extremely disturbed"
	PRINT "ID:485970"
	GOTO 13360

	'----- attic passage diary note
	13710 PRINT "3/15"
	PRINT "The patients have become unruly"
	PRINT "I'm afraid they will overpower us"
	PRINT "but the research must go on."
	PRINT "3/17"
	PRINT "The other doctors to have become"
	PRINT "concerned. We all are tired from"
	PRINT "working long hours and are making"
	PRINT "many judmental mistakes"
	PRINT "3/23"
	PRINT "There must be something in the air"
	PRINT "down there it clouds my head. I have"
	PRINT "moved my practice to the attic and to"
	PRINT "conceal have placed a pit of ash in "
	PRINT "front of the passage only openable by "
	PRINT "an electric circuit. I have put the"
	PRINT "MPTP vials in the upper left."
	PRINT "3/29"
	PRINT "Doctor Edwards has been following me"
	PRINT "I'm afraid he is becoming suspicous."
	PRINT "(The rest of the page has been torn out)"
	GOTO 13360
END SUB

'----- compute and print percent of game completed
SUB PctComplete
	pc = 0
	FOR i = 1 TO 51
		IF ob(i) <> 1 THEN GOTO 14170
		pc = pc + 1
	14170 NEXT
	IF ob(36) <> 1 THEN GOTO 14200
	pc = pc + 2
	14200 IF ob(35) <> 1 THEN GOTO 14220
	pc = pc + 2
	14220 pp2 = CINT((pc * 100) / 47)
	PRINT pp2; "% complete";
	EXIT SUB
END SUB

'----- sound effect 1
SUB Snd1
	SOUND f6, 1: SOUND f3, .5: SOUND f7, 1: SOUND f2, .1: SOUND f8, .5
END SUB

'----- sound effect 2
SUB Snd2
	FOR sa = 1 TO 5: SOUND f3, .2: SOUND 32676, 3: NEXT
END SUB

'----- sound effect 3
SUB Snd3
	SOUND f6, .1: SOUND f3, .5
	FOR sb = 100 TO 600 STEP 100: SOUND sb, .1: NEXT
	SOUND f8, .5: SOUND f5, .5
END SUB

'----- sound effect 4
SUB Snd4
	FOR sc = 50 TO 100 STEP 5: SOUND sc, .5: SOUND f9, .1: NEXT
	FOR sc = 100 TO 50 STEP -5: SOUND sc, .5: SOUND f9, .1: NEXT
	SOUND 32676, .5: SOUND f1, .5
END SUB

'----- sound effect 5
SUB Snd5
	FOR sc = 50 TO 80: SOUND f3, .1: SOUND sc, .1: NEXT
	PLAY "p10"
	FOR sc = 1 TO 300 STEP 20: SOUND (RND * 300) + 50, .1: NEXT
	SOUND f3, .2: SOUND 32676, 2: SOUND f3, .2: SOUND 32676, 2
END SUB

