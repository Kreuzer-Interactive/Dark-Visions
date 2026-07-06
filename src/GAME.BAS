REM $DYNAMIC
'--Dark Visions  by Rob & Jon Kreuzer--
'Programmed in QuickBASIC 4.5

'----- SUB declarations
DECLARE SUB Intro ()
DECLARE SUB Credits ()
DECLARE SUB invhi ()
DECLARE SUB SaveLoadScreen (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, act AS INTEGER, dead AS INTEGER)
DECLARE SUB drawcur ()
DECLARE SUB erasecur ()
DECLARE SUB InitVars ()
DECLARE SUB Snd1 ()
DECLARE SUB Snd2 ()
DECLARE SUB Snd3 ()
DECLARE SUB Snd4 ()
DECLARE SUB Snd5 ()
DECLARE SUB QuitConfirm ()
DECLARE SUB DrawYNBox (msg AS STRING, dk AS INTEGER, fontData() AS INTEGER)
DECLARE SUB DeathMusic ()
DECLARE SUB LoadConfig ()
DECLARE SUB initAllFonts (fontData() AS INTEGER, font3Data() AS INTEGER, fontbData() AS INTEGER)
DECLARE SUB drawChar (x AS INTEGER, y AS INTEGER, char AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
DECLARE SUB drawText (x AS INTEGER, y AS INTEGER, text AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
DECLARE SUB drawWrap (x AS INTEGER, y AS INTEGER, txt AS STRING, col AS INTEGER, maxc AS INTEGER, lineh AS INTEGER, fontData() AS INTEGER)
DECLARE FUNCTION textWidth (text AS STRING, fontData() AS INTEGER)
DECLARE SUB drawStats (ob() AS SINGLE, cl AS SINGLE, cr AS SINGLE, fontData() AS INTEGER)
DECLARE SUB drawMsg (s AS STRING, fontData() AS INTEGER)
DECLARE SUB introShowCarr ()
DECLARE SUB introFadeCredit ()
DECLARE SUB showBook (sel AS SINGLE, fontData() AS INTEGER)
DECLARE SUB PStand (d$, px!, py!, nopl!, fbg%(), fd%(), mfd%(), fu%(), mfu%(), fr%(), mfr%(), fl%(), mfl%(), fdl%(), mfdl%(), fdr%(), mfdr%(), ful%(), mful%(), fur%(), mfur%())
DECLARE SUB PStep (x!, y!, fb%, sfrq!, sdur!, ofs%, wa%(), mwa%(), wb%(), mwb%(), wbg%())
DECLARE SUB LoadWalks (cwa%(), cmwa%(), cwb%(), cmwb%())
DECLARE SUB walkTo (tx!, ty!, px!, py!, sfrq!, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%())

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
COMMON SHARED f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, sa, sb, sc, mt, sfps, fpsc, fpst, jsen, inon, msen, snr, exsen, mxyon, nfon, hzon$, klon, wksen, qkon
COMMON SHARED mcur AS INTEGER, mvint AS INTEGER
DIM SHARED pk, jx, jy, dx2, dy2, co, co2, pa1, pa2, pa3
DIM SHARED oh, ohs, pz, j, pc, pp2, gm, tmo, wk, js0, js1
DIM SHARED fpsv, fpsd
DIM SHARED ifc, it0, itt
DIM SHARED mlb, mrb, mshown, cshp, hovr
DIM SHARED nf$(25), nfseed, lcount, lastlx, lastly, lh1, lh2, lh3
DIM SHARED mreg AS RegType, mout AS RegType
DIM SHARED mhsx AS INTEGER, mhsy AS INTEGER, mxor, mraw
DIM SHARED mregx AS RegTypeX, moutx AS RegTypeX
DIM SHARED cmask(31) AS INTEGER
DIM SHARED arow$(15)
DIM SHARED px(4, 80), py(4, 80), pc(4, 80), npix(4)
DIM SHARED curbuf(100), cdrawn, cox, coy
DIM SHARED mx AS INTEGER, my AS INTEGER, nmx AS INTEGER, nmy AS INTEGER, lmx AS INTEGER, lmy AS INTEGER
DIM SHARED fontData(2047) AS INTEGER
DIM SHARED font3Data(2047) AS INTEGER
DIM SHARED fontbData(2047) AS INTEGER
DIM SHARED curp$(15)
DIM SHARED cbg(100) AS INTEGER

'----- shared sprite/door buffers
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
'----- masks for the 8 face sprites (AND-mask) + save-under for the standing player at (140,130)
DIM SHARED mfd(150) AS INTEGER
DIM SHARED mfu(150) AS INTEGER
DIM SHARED mfr(150) AS INTEGER
DIM SHARED mfl(150) AS INTEGER
DIM SHARED mfdl(150) AS INTEGER
DIM SHARED mfdr(150) AS INTEGER
DIM SHARED mful(150) AS INTEGER
DIM SHARED mfur(150) AS INTEGER
DIM SHARED fbg(150) AS INTEGER
'----- masks for the shared walk-frame buffers (wa/wb) + a per-frame save-under for the moving player
DIM SHARED mwa(150) AS INTEGER
DIM SHARED mwb(150) AS INTEGER
DIM SHARED wbg(150) AS INTEGER
'----- player position (top-left of the 31x31 sprite box), walkable band for
'----- walk-to stand points (defaults, or a "-1,xmin,xmax,ymin,ymax" line after
'----- the .pac anim placements; ymin = highest allowed sprite TOP, ymax =
'----- lowest allowed sprite BOTTOM), and the room loadroom last loaded
'----- (position is kept on a same-room reload like the inventory return)
DIM SHARED pjx, pjy, wbmin, wbmax, wbymin, wbymax, lrq$
'----- per-object authored walk-to stand points from the .pac ("-2,obj,x,y,dir"
'----- records): feet-center x/y (spx=-1 none) + facing digit (0 = auto lookdir)
DIM SHARED spx(25) AS INTEGER, spy(25) AS INTEGER, spd(25) AS INTEGER
'----- startup-cached walk frames, 4 direction sets at slot d*151 (0=down/joew1, 1=up/joew2, 2=right/joew3, 3=left/joew4)
'----- 8-direction walk cache (REDIM = dynamic -> far heap; 8 slots x 151 ints; DGROUP is nearly full)
REDIM SHARED cwa(1207) AS INTEGER, cwb(1207) AS INTEGER, cmwa(1207) AS INTEGER, cmwb(1207) AS INTEGER
'----- data-driven animation system: ANIMS.PAC library + per-room placements
DIM SHARED nAnim AS INTEGER, nPlace AS INTEGER
DIM SHARED anId(50) AS INTEGER, anRate(50) AS INTEGER
DIM SHARED anName$(50), anType$(50), anSrc$(50), anFrames$(50), anMode$(50), anPal$(50), anSnd$(50)
DIM SHARED plAnim(20) AS INTEGER, plX(20) AS INTEGER, plY(20) AS INTEGER, plCond(20) AS INTEGER, plSet(20) AS INTEGER
'----- scratch buffers for the generic .pct/.msk frame loader (de-interleave + masked draw)
DIM SHARED afrm(150) AS INTEGER, amfrm(150) AS INTEGER, fsq(30) AS INTEGER
'----- anim source cache: each .pct/.msk pair parsed from disk ONCE, then reused (6 slots,
'----- round-robin evict). REDIM = dynamic arrays in the far heap, so DGROUP is untouched.
REDIM SHARED acPct(6, 1600) AS INTEGER, acMsk(6, 1600) AS INTEGER
DIM SHARED acSrc$(6), acN(6) AS INTEGER, acM(6) AS INTEGER
'----- active loop-animation instances for the current room (idle-loop tick)
DIM SHARED nLoop AS INTEGER
DIM SHARED liAnim(4) AS INTEGER, liX(4) AS INTEGER, liY(4) AS INTEGER, liCur(4) AS INTEGER, liRate(4) AS INTEGER
DIM SHARED liLast(4) AS SINGLE, liSaveAll(640) AS INTEGER

'----- shared world and inventory arrays
DIM SHARED bk(100)
DIM SHARED bk2(100)
DIM SHARED gr(1700)
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
DIM SHARED dn$(65)
DIM SHARED sn$(65)
DIM SHARED iord(35)
DIM SHARED gp(100)
DIM SHARED er1(400)
DIM SHARED d(300)
DIM SHARED tilarr(12600) AS INTEGER
DIM SHARED iconarr(9400) AS INTEGER
DIM SHARED kmarr(9400) AS INTEGER
DIM SHARED dsav(250) AS INTEGER
DIM SHARED tix(65) AS INTEGER
DIM SHARED cilist(40) AS INTEGER
DIM SHARED aqo(65) AS INTEGER
DIM SHARED nwf(65) AS INTEGER
DIM SHARED starr(10) AS INTEGER
DIM SHARED aqc AS INTEGER

'----- shared save-slot arrays
DIM SHARED slvAct AS INTEGER

'----- startup
tmo = 2
'COM() statements in this programme
'----- reset the 8253 timer (channel 0) to the standard 18.2 Hz tick.  Win98
'      "MS-DOS mode" can hand off with channel 0 left reprogrammed faster,
'      which shortens SOUND durations (the intro races past) and skews TIMER
'      (the in-room clock) -- prime suspect for the MS-DOS-mode rush + lock-up.
'      No-op on a healthy DOS boot (it's already 18.2 Hz there).
OUT &H43, &H36
OUT &H40, 0
OUT &H40, 0
CALL InitVars
CALL LoadConfig
CALL initAllFonts(fontData(), font3Data(), fontbData())
'----- guard Intro's cutscene sound loops on fast CPUs: QB's SOUND runtime
'      can raise "Illegal function call" in the tight loops on hardware far
'      faster than this 1993 intro targets.  Intro has no handler of its own
'      (it runs before the ON ERROR GOTO errhand below).  RESUME NEXT would
'      need /X, which overflows the 64K module, so on such an error introSkip
'      bails out of the cutscene to introDone -- the intro ends early but the
'      game runs instead of crashing to DOS.  (Throttle work restores it.)
ON ERROR GOTO introSkip
IF inon <> 0 AND qkon = 0 THEN CALL Intro
introDone:
ON ERROR GOTO 0
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

SCREEN 1
CLS
CLOSE
GOSUB loadanims
CALL LoadWalks(cwa(), cmwa(), cwb(), cmwb())

'----- quickstart=1 (dark.ini): drop straight into the game for testing
'----- (joeface still runs -- it LOADS the 8 standing player sprites)
IF qkon <> 0 THEN GOSUB joeface: GOTO qstart

'----- title screen
SCREEN 1
PALETTE 3, 0
LOCATE 10, 12
PRINT "A Kreuzer Production"
a$ = INKEY$
GOSUB joeface
a$ = INKEY$
CALL introFadeCredit
CLS

'----- instructions prompt
PRINT " Do you want instructions Y/N"
IF sfps = 1 AND itt > .5 THEN LOCATE 3, 1: PRINT USING "Intro: ### steps in ###.# secs"; ifc; itt
400 a$ = INKEY$
IF a$ <> "" THEN GOTO 430
GOTO 400
430 IF a$ = "Y" OR a$ = "y" THEN GOSUB rules

'----- enter the game
qstart:
b = 122
a = 82
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
'----- error handler: show the error and exit cleanly
errhand:
	ehcode = ERR: ehline = ERL
	'----- keep this handler SOUND-FREE: a sound here can itself fail on some
	'      machines and hang before the message can be shown.
	SCREEN 0: WIDTH 80: CLS
	LOCATE 10, 5: PRINT "Dark Visions has hit an unexpected error and must close."
	LOCATE 12, 5: PRINT "  (error"; ehcode; "at line"; ehline; ")"
	LOCATE 14, 5: PRINT "Press any key to exit..."
	a$ = INPUT$(1)
	SYSTEM

'----- Intro-only error trap (armed around CALL Intro at startup): on CPUs
'      far faster than 1993 hardware, QB's SOUND runtime can raise err 5 in
'      the cutscene sound loops.  Bail to introDone (just past CALL Intro):
'      the cutscene ends early but the game continues instead of crashing.
introSkip:
	RESUME introDone


'----- Resolve action on object under cursor
'----- clrtxt: wipe only the rows the last top message used
clrtxt:
	IF txr > 0 THEN LINE (0, 0)-(319, 21), 0, BF
	RETURN

action:
	GOSUB strigoff
	GOSUB clrtxt: txr = 0
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

'----- Apply state change and print message (get/use first walk the player over)
6340 GOSUB wlkitem
	ob(CINT(st(i))) = 1
	'----- pickup sound now plays via the acquisition scan (mainloop) so action-gets sound too
	IF a$ <> "u" THEN GOTO 6400
	CALL Snd3
	6400 CALL drawMsg(ms$(i), font3Data()): txr = 1
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

'----- Face the tagged direction. With walk-to on the direction is COMPUTED
'----- from the player's eyes toward the click (the data's hardcoded letter
'----- assumed a center-screen player); walkto=0 keeps the classic letter.
	6710 IF LEFT$(tg$(i), 1) <> "f" THEN GOTO 6740
	'----- an authored stand-point facing already turned the player (wlkdd)
	IF wlkdd = 1 THEN GOTO 6740
	IF wksen = 1 THEN GOSUB lookdir ELSE a$ = RIGHT$(tg$(i), 1)
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
	IF q$ = "room3" AND ob(50) = 1 AND ob(42) = 0 THEN GOSUB dooseq ELSE GOSUB face
	RETURN

'----- invhi: ESC inventory -- graphical SCREEN 1 (320x200, 4-color) tile grid.
'      Loads INVTIL1/2.PIC, GETs the 36 45x54 tiles into tilarr, then PUTs the
'      carried items into a 7-col grid with a movable selection ring.
doinv:
	CALL invhi
	IF slvAct = 2 THEN RUN
	GOSUB loadroom
	IF tt$ <> "y" THEN a$ = lf$: lf$ = "": GOSUB face
	t0 = TIMER
	RETURN

'----- main game loop: input, movement, actions
mainloop:
	FOR iaq = 1 TO 35
		IF ob(iord(iaq)) = 1 AND aqo(iord(iaq)) = 0 THEN aqc = aqc + 1: aqo(iord(iaq)) = aqc: nwf(iord(iaq)) = 1: CALL Snd1
	NEXT
	IF msen <> 1 THEN PUT (b, a), d, XOR
	pt = (TIMER - t0) + pt
	t0 = TIMER
	IF (INT(cl * cr)) <= 35 THEN GOTO 7100
	'CALL DoorOpen   ' door migrated to data-driven animation (ANIMS.PAC id 1 + room3.pac placement)
	7100 GOSUB reanim
	IF doc <> 1 THEN GOTO 7180
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
	GOSUB animtick
	IF ob(43) = 1 AND tk$ = "" THEN cv = CINT(cl): tk$ = "y"
	IF tk$ = "y" AND cv + 120 < cl THEN GOTO burn
	IF a$ <> "" THEN GOTO 7300
	GOTO 7180

'----- numpad movement: nudge player by direction
	7300 IF msen <> 1 THEN PUT (b, a), d, XOR
	IF a$ = CHR$(0) + CHR$(72) THEN a$ = "8"
	IF a$ = CHR$(0) + CHR$(80) THEN a$ = "2"
	IF a$ = CHR$(0) + CHR$(75) THEN a$ = "4"
	IF a$ = CHR$(0) + CHR$(77) THEN a$ = "6"
	IF msen = 1 AND INSTR("82467139", a$) > 0 THEN CALL erasecur
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
	7610 IF msen = 1 AND INSTR("82467139", a$) > 0 THEN GOSUB ksync
	IF a$ = CHR$(27) THEN GOSUB doinv: GOTO mainloop
	IF a$ <> "i" THEN GOTO 7630
	GOSUB doinv: GOTO mainloop
	7630 IF doc <> 1 THEN GOTO 7660
	GOSUB fight
	GOTO mainloop
	7660 IF a$ = "a" OR a$ = "u" OR a$ = "g" OR a$ = "l" THEN
		IF msen = 1 THEN GOSUB msnap
		GOSUB action
		GOSUB events
		GOSUB trigger
		IF a$ = "l" AND nfon = 1 THEN GOSUB lookmiss
		IF msen = 1 THEN GOSUB synchit
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

'----- debug overlay, config dark.ini hitzones=<verbs> (e.g. l): ring each hotspot's snr click-zone COLORED
'----- BY VERB (look=blue, action=brown, get/use=gray) + dot its hit point. A click registers only INSIDE a circle.
hitzones:
	IF hzon$ = "" OR snr <= 0 THEN RETURN
	FOR hzi = 1 TO 257
		IF oy(hzi) = 0 THEN EXIT FOR
		hzv$ = ky$(CINT(oi(hzi)))
		IF hzv$ <> "" AND INSTR(hzon$, hzv$) > 0 THEN
			hzc = 2
			IF hzv$ = "a" THEN hzc = 3
			IF hzv$ = "g" THEN hzc = 1
			IF hzv$ = "u" THEN hzc = 1
			CIRCLE (ox(hzi), oy(hzi)), snr, hzc
			PSET (ox(hzi), oy(hzi)), hzc
		END IF
	NEXT
	RETURN

'----- 25 generic"nothing to see" lines (used by lookmiss)
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
	FOR ivi = 1 TO 29: iord(ivi) = ivi: NEXT
	iord(30) = 30: iord(31) = 49: iord(32) = 35: iord(33) = 36: iord(34) = 34: iord(35) = 52
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
	GOSUB clrtxt
	CALL drawMsg(nf$(nfp), font3Data()): txr = 1
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
'----- loadanims: load the ANIMS.PAC animation library (id,name,type,src,frames,rate,mode,pal); robust if absent
loadanims:
	nAnim = 0
	ON ERROR GOTO animeof
	CLOSE #3
	OPEN "ANIMS.PAC" FOR INPUT AS #3
	animloop:
	IF nAnim >= 50 THEN GOTO animend
	INPUT #3, anId(nAnim + 1), anName$(nAnim + 1), anType$(nAnim + 1), anSrc$(nAnim + 1), anFrames$(nAnim + 1), anRate(nAnim + 1), anMode$(nAnim + 1), anPal$(nAnim + 1), anSnd$(nAnim + 1)
	nAnim = nAnim + 1
	GOTO animloop
	animeof:
	RESUME animend
	animend:
	CLOSE #3
	ON ERROR GOTO errhand
	RETURN

'----- animframe: draw 1-based frame FN of sprite source SRC$ at (PX,PY); mask if .msk present, else PSET
'----- cached: the .pct/.msk files are parsed ONCE into a slot (animload), then every frame draw
'----- is array-copy + PUT -- was 2 full ASCII file re-parses PER FRAME (the slow door swing)
animframe:
	acs = 0
	FOR aci = 1 TO 6
		IF acSrc$(aci) = SRC$ THEN acs = aci
	NEXT
	IF acs = 0 THEN GOSUB animload
	anf = acN(acs)
	IF anf < 2 THEN RETURN
	ank = 0
	afk1:
	IF ank >= anf THEN GOTO afk2
	IF acPct(acs, ank + 1) <> acPct(acs, 1) THEN GOTO afk2
	ank = ank + 1
	GOTO afk1
	afk2:
	IF ank < 1 THEN ank = 1
	anpf = anf \ ank
	IF anpf > 150 THEN anpf = 150
	IF afn < 1 THEN afn = 1
	IF afn > ank THEN afn = ank
	FOR aj = 0 TO anpf - 1: afrm(aj) = acPct(acs, afn + aj * ank): NEXT
	IF acM(acs) >= anf THEN
		FOR aj = 0 TO anpf - 1: amfrm(aj) = acMsk(acs, afn + aj * ank): NEXT
		PUT (PX, PY), amfrm, AND
		PUT (PX, PY), afrm, OR
	ELSE
		PUT (PX, PY), afrm, PSET
	END IF
	RETURN

'----- animload: parse SRC$.pct + SRC$.msk from disk into cache slot acs (round-robin evict;
'----- a missing/short file is cached as a miss so it isn't re-tried every frame)
animload:
	acNext = acNext + 1
	IF acNext > 6 THEN acNext = 1
	acs = acNext
	acSrc$(acs) = SRC$
	anf = 0
	ON ERROR GOTO afeof1
	CLOSE #3
	OPEN SRC$ + ".pct" FOR INPUT AS #3
	afl1:
	IF anf >= 1600 THEN GOTO afd1
	anf = anf + 1
	INPUT #3, acPct(acs, anf)
	GOTO afl1
	afeof1:
	anf = anf - 1
	RESUME afd1
	afd1:
	CLOSE #3
	ON ERROR GOTO errhand
	acN(acs) = anf
	anm = 0
	ON ERROR GOTO afeof2
	CLOSE #3
	OPEN SRC$ + ".msk" FOR INPUT AS #3
	afl2:
	IF anm >= 1600 THEN GOTO afd2
	anm = anm + 1
	INPUT #3, acMsk(acs, anm)
	GOTO afl2
	afeof2:
	anm = anm - 1
	RESUME afd2
	afd2:
	CLOSE #3
	ON ERROR GOTO errhand
	acM(acs) = anm
	RETURN

'----- animparse: parse anFrames$(aidx) like "0;1;2" into fsq(1..nfr) frame indices
animparse:
	nfr = 0
	aps$ = anFrames$(aidx) + ";"
	apst = 1
	FOR apc = 1 TO LEN(aps$)
		IF MID$(aps$, apc, 1) = ";" THEN
			IF apc > apst AND nfr < 30 THEN
				nfr = nfr + 1
				fsq(nfr) = VAL(MID$(aps$, apst, apc - apst))
			END IF
			apst = apc + 1
		END IF
	NEXT
	RETURN

'----- animwait: pause awrate*0.05s between animation frames (TIMER-based, midnight-safe)
animwait:
	awt! = TIMER
	awd:
	IF TIMER < awt! THEN RETURN
	IF TIMER < awt! + awrate * .05 THEN GOTO awd
	RETURN

'----- animdraw: composite scene-animation placements onto the room (static / hold / once; loop = Phase 1b3)
animdraw:
	nLoop = 0
	IF nPlace < 1 THEN RETURN
	'----- bg pass: full-screen .pic swaps (BLOAD over the base) BEFORE the sprite overlays
	FOR pp = 1 TO nPlace
		bgi = 0
		FOR aa = 1 TO nAnim
			IF anId(aa) = plAnim(pp) THEN bgi = aa
		NEXT
		IF bgi = 0 THEN GOTO bgnext
		IF anType$(bgi) <> "bg" THEN GOTO bgnext
		IF plCond(pp) <> 0 THEN IF ob(plCond(pp)) <> 1 THEN GOTO bgnext
		bgf$ = anFrames$(bgi)
		bgp = 0
		FOR bgc = 1 TO LEN(bgf$)
			IF MID$(bgf$, bgc, 1) = ";" THEN bgp = bgc
		NEXT
		IF bgp > 0 THEN bgf$ = MID$(bgf$, bgp + 1)
		IF bgf$ <> "" THEN DEF SEG = -18432: BLOAD bgf$ + ".pic", 0: DEF SEG
		bgnext:
	NEXT
	'----- sprite pass
	FOR pp = 1 TO nPlace
		aidx = 0
		FOR aa = 1 TO nAnim
			IF anId(aa) = plAnim(pp) THEN aidx = aa
		NEXT
		IF aidx = 0 THEN GOTO adnext
		IF anType$(aidx) = "bg" THEN GOTO adnext
		IF plCond(pp) <> 0 THEN IF ob(plCond(pp)) <> 1 THEN GOTO adnext
		GOSUB animparse
		IF nfr < 1 THEN GOTO adnext
		SRC$ = anSrc$(aidx)
		PX = plX(pp)
		PY = plY(pp)
		awrate = anRate(aidx)
		IF anMode$(aidx) = "static" THEN
			afn = fsq(nfr) + 1
			GOSUB animframe
		ELSEIF anMode$(aidx) = "hold" OR anMode$(aidx) = "once" THEN
			adplayed = 0
			IF plSet(pp) > 0 THEN IF ob(plSet(pp)) = 1 THEN adplayed = 1
			IF adplayed = 1 THEN
				IF anMode$(aidx) = "hold" THEN afn = fsq(nfr) + 1: GOSUB animframe
			ELSE
				IF q$ = "room3" THEN GOTO adnext
				GET (PX, PY)-(PX + 30, PY + 30), wbg
				FOR adf = 1 TO nfr
					afn = fsq(adf) + 1
					GOSUB animframe
					GOSUB animwait
				NEXT
				IF anSnd$(aidx) <> "" THEN PLAY anSnd$(aidx)
				IF anMode$(aidx) = "once" THEN PUT (PX, PY), wbg, PSET
				IF plSet(pp) > 0 THEN ob(plSet(pp)) = 1
			END IF
		ELSEIF anMode$(aidx) = "loop" THEN
			IF nLoop < 4 THEN
				nLoop = nLoop + 1
				liAnim(nLoop) = aidx
				liX(nLoop) = PX
				liY(nLoop) = PY
				liCur(nLoop) = 1
				liRate(nLoop) = awrate
				liLast(nLoop) = TIMER
				GET (PX, PY)-(PX + 30, PY + 30), liSaveAll((nLoop - 1) * 150)
				afn = fsq(1) + 1
				GOSUB animframe
			END IF
		END IF
		adnext:
	NEXT
	RETURN

'----- animtick: advance active loop animations (idle-loop tick, TIMER-delta gated)
animtick:
	IF nLoop < 1 THEN RETURN
	FOR li = 1 TO nLoop
		IF TIMER < liLast(li) THEN liLast(li) = TIMER
		IF TIMER >= liLast(li) + liRate(li) * .05 THEN
			liLast(li) = TIMER
			aidx = liAnim(li)
			GOSUB animparse
			IF nfr >= 1 THEN
				PUT (liX(li), liY(li)), liSaveAll((li - 1) * 150), PSET
				liCur(li) = liCur(li) + 1
				IF liCur(li) > nfr THEN liCur(li) = 1
				SRC$ = anSrc$(aidx)
				PX = liX(li)
				PY = liY(li)
				afn = fsq(liCur(li)) + 1
				GOSUB animframe
			END IF
		END IF
	NEXT
	RETURN

'----- reanim: mainloop check -- play any placement that just became active+unplayed (hold/once); data-driven DoorOpen
reanim:
	IF nPlace < 1 THEN RETURN
	FOR pp = 1 TO nPlace
		aidx = 0
		FOR aa = 1 TO nAnim
			IF anId(aa) = plAnim(pp) THEN aidx = aa
		NEXT
		IF aidx = 0 THEN GOTO ranext
		IF anType$(aidx) = "bg" THEN GOTO ranext
		IF anMode$(aidx) <> "hold" AND anMode$(aidx) <> "once" THEN GOTO ranext
		IF plCond(pp) = 0 THEN GOTO ranext
		IF ob(plCond(pp)) <> 1 THEN GOTO ranext
		IF plSet(pp) < 1 THEN GOTO ranext
		IF ob(plSet(pp)) = 1 THEN GOTO ranext
		GOSUB animparse
		IF nfr < 1 THEN GOTO ranext
		SRC$ = anSrc$(aidx)
		PX = plX(pp)
		PY = plY(pp)
		awrate = anRate(aidx)
		GET (PX, PY)-(PX + 30, PY + 30), wbg
		FOR adf = 1 TO nfr
			afn = fsq(adf) + 1
			GOSUB animframe
			GOSUB animwait
		NEXT
		IF anSnd$(aidx) <> "" THEN PLAY anSnd$(aidx)
		IF anMode$(aidx) = "once" THEN PUT (PX, PY), wbg, PSET
		ob(plSet(pp)) = 1
		ranext:
	NEXT
	RETURN

'----- dooseq: room3 door entry cutscene -- walk player in from the door while it opens, face up-right
dooseq:
	CLOSE
	'----- walk in from the door using the startup-cached right-facing set (slot 2 = offset 302)
	FOR i = 90 TO 140 STEP 3
		CALL PStep(i, 130, 0, f3, 1, 302, cwa(), cmwa(), cwb(), cmwb(), wbg())
		i = i + 3
		CALL PStep(i, 130, 1, f3, 1, 302, cwa(), cmwa(), cwb(), cmwb(), wbg())
	NEXT
	a$ = "6": GOSUB face
	dwsec = .5: GOSUB dwait
	a$ = "9": GOSUB face
	dwsec = .5: GOSUB dwait
	SRC$ = "door"
	PLAY "MB<<f6p20d7p20g-7p20e-7p20a5>>"
	FOR i = 1 TO 4
		afn = i: PX = 175: PY = 109: GOSUB animframe
		dwsec = .18: GOSUB dwait
	NEXT
	PLAY "MF"
	ob(42) = 1
	RETURN

dwait:
	dwt = TIMER
	dwl1:
	dwd = TIMER - dwt
	IF dwd < 0 THEN dwd = dwd + 86400
	IF dwd < dwsec THEN GOTO dwl1
	RETURN

loadroom:
	txr = 0: cdrawn = 0
	CLOSE
	OPEN q$ + ".pac" FOR INPUT AS #1
	LINE INPUT #1, hd$
	co = VAL(hd$): hd$ = MID$(hd$, INSTR(hd$, ",") + 1)
	pa1 = VAL(hd$): hd$ = MID$(hd$, INSTR(hd$, ",") + 1)
	pa2 = VAL(hd$): hd$ = MID$(hd$, INSTR(hd$, ",") + 1)
	pa3 = VAL(hd$)
	nopl = 0: IF INSTR(hd$, ",") > 0 THEN nopl = VAL(MID$(hd$, INSTR(hd$, ",") + 1))
	i = 0
	ON ERROR GOTO hoterr
	DO
		i = i + 1
		INPUT #1, ox(i), oy(i), oi(i)
	LOOP UNTIL oy(i) = 0 OR i = 257
	hotok:
	ON ERROR GOTO objerr
	FOR i = 1 TO 25
		INPUT #1, df$(i), ms$(i), ky$(i)
		INPUT #1, bs(i), cs(i), st(i), tg$(i)
	NEXT
	objok:
	ON ERROR GOTO errhand
	nPlace = 0
	wbmin = 40: wbmax = 250
	wbymin = 138: wbymax = 176
	FOR i = 1 TO 25: spx(i) = -1: spd(i) = 0: NEXT
	ON ERROR GOTO placeeof
	placeloop:
	IF nPlace >= 20 THEN GOTO placeend
	INPUT #1, pla, plb, plc, pld, ple
	'----- pla=-1 sentinel = walkable-band record: x min/max, then optional
	'----- y limits (sprite-top min, sprite-bottom max; 0 = keep default)
	IF pla <> -1 THEN GOTO notwband
	wbmin = plb: wbmax = plc
	IF pld > 0 THEN wbymin = pld
	IF ple > 0 THEN wbymax = ple
	GOTO placeloop
	notwband:
	'----- pla=-2 sentinel = per-object stand point: obj, feet x, feet y, facing
	IF pla <> -2 THEN GOTO notstand
	IF plb >= 1 AND plb <= 25 THEN spx(plb) = plc: spy(plb) = pld: spd(plb) = ple
	GOTO placeloop
	notstand:
	IF pla < 1 THEN GOTO placeend
	nPlace = nPlace + 1
	plAnim(nPlace) = pla: plX(nPlace) = plb: plY(nPlace) = plc: plCond(nPlace) = pld: plSet(nPlace) = ple
	GOTO placeloop
	placeeof:
	RESUME placeend
	'----- on a bad/short room file, skip the rest of that read and keep going
	hoterr:
	IF i >= 1 AND i <= 257 THEN oy(i) = 0
	RESUME hotok
	objerr:
	RESUME objok
	placeend:
	ON ERROR GOTO errhand
	CLS
	COLOR co
	PALETTE 1, pa1
	PALETTE 2, pa2
	PALETTE 3, pa3
	DEF SEG = -18432
	BLOAD q$ + ".pic", 0
	KEY OFF
	DEF SEG
	GOSUB animdraw
	GET (1, 8)-(9, 18), bk: GET (1, 8)-(9, 18), bk2
	IF q$ <> lrq$ THEN pjx = 140: pjy = 130
	lrq$ = q$
	GET (pjx, pjy)-(pjx + 30, pjy + 30), fbg
	GOSUB hitzones
	IF q$ <> "title" THEN GOTO walkout

	'----- title screen music: "Dark Visions" ostinato (original composition,
	'----- replaced Gounod's Funeral March of a Marionette / Hitchcock theme).
	'----- Trailing o0 leaves the octave state the old block left, since later
	'----- jingles use relative <>'s from wherever the title music ended.
	PLAY "t120mno1l8de-de-de-de-de-de-de-de-"
	PLAY "o1l8fg-fg-fg-fg-g+ag+ag+ag+a"
	PLAY "o2l8de-de-de-de-dc+dc+dc+dc+"
	PLAY "o2d4p8o1a4p8d2o0"

'----- walk-out: dispatch to walking animation
walkout:
	GOTO 8240
	'----- decide whether to walk out and which direction sprite to load
	8240 CLOSE
	IF q$ = "title" OR q$ = "death" OR q$ = "dindead" THEN RETURN
	IF wk = 1 THEN GOTO 8265
	RETURN
	RETURN

	'----- erase the standing player, then walk out via GAME5 walkTo from
	'----- wherever the player stands (a$ direction 1=s 2=n 3=e 4=w; the
	'----- old per-walkout joew sprite disk loads are gone -- LoadWalks
	'----- cached all 4 direction sets at startup)
	8265 sf$ = a$
	a$ = ""
	GOSUB face
	a$ = sf$
	wtx = pjx: wty = pjy
	IF a$ = "1" THEN wty = 152
	IF a$ = "2" THEN wty = 118
	IF a$ = "3" THEN wtx = 197
	IF a$ = "4" THEN wtx = 87
	'----- vertical exit clicked while standing away from the door (walk-to can
	'----- leave the player anywhere): L-walk to the door's x first, then out.
	'----- The 12px dead zone keeps the classic centered walkout pixel-identical.
	IF (a$ = "1" OR a$ = "2") AND ABS(b - 15 - pjx) > 12 THEN wtx = b - 15
	CALL walkTo(wtx, wty, pjx, pjy, f3, cwa(), cmwa(), cwb(), cmwb(), wbg())
	RETURN
face:
	'----- tear down the mouse cursor first: its save-under was sampled before this turn, so restoring it later would repaint the OLD player (erasecur no-ops when the cursor isn't drawn). Next mousepoll re-samples after the turn.
	CALL erasecur
	'----- erase + redraw the standing player at (pjx,pjy) -- GAME5 PStand
	'----- (erase restores fbg; nopl close-up rooms erase but skip the draw)
	CALL PStand(a$, pjx, pjy, nopl, fbg(), fd(), mfd(), fu(), mfu(), fr(), mfr(), fl(), mfl(), fdl(), mfdl(), fdr(), mfdr(), ful(), mful(), fur(), mfur())
	lf$ = a$
	RETURN

'----- walk-to-item (walkto ini, wksen): a firing get/use first walks the
'----- player to stand under the clicked spot (b,a), clamped to the room's
'----- walkable x-band, then re-anchors the standing save-under (fbg) there
'----- and faces the item. ACTIONS walk too, but ONLY to an authored stand
'----- point (no beside-the-item fallback, so walkouts + unauthored actions
'----- stay instant); look is always instant; close-up scenes (nopl) never
'----- walk. Called from the action fire point.
wlkitem:
	wlkdd = 0
	IF wksen <> 1 OR nopl = 1 THEN RETURN
	woi% = CINT(i)
	IF a$ = "a" AND spx(woi%) < 0 THEN RETURN
	IF a$ <> "g" AND a$ <> "u" AND a$ <> "a" THEN RETURN
	IF spx(woi%) >= 0 THEN
		'----- authored stand point (editor-placed): feet-center -> sprite top-left
		wsx = spx(woi%) - 15
		wsy = spy(woi%) - 30
	ELSE
		'----- no authored point: stand BESIDE the item (right half of the view
		'----- -> ~20px left of it, left half -> ~20px right), head toward the
		'----- item's height, clamped to the room's floor band
		IF b > 160 THEN wsx = b - 35 ELSE wsx = b + 5
		IF wsx < wbmin THEN wsx = wbmin
		IF wsx > wbmax THEN wsx = wbmax
		wsy = a
		IF wsy < wbymin THEN wsy = wbymin
		IF wsy > wbymax - 30 THEN wsy = wbymax - 30
	END IF
	'----- keep the 31x31 sprite box on screen whatever the data says
	IF wsx < 0 THEN wsx = 0
	IF wsx > 289 THEN wsx = 289
	IF wsy < 0 THEN wsy = 0
	IF wsy > 169 THEN wsy = 169
	IF wsx = pjx AND wsy = pjy THEN GOTO wlkface
	sf$ = a$
	a$ = ""
	GOSUB face
	a$ = sf$
	CALL walkTo(wsx, wsy, pjx, pjy, f3, cwa(), cmwa(), cwb(), cmwb(), wbg())
	GET (pjx, pjy)-(pjx + 30, pjy + 30), fbg
	wlkface:
	sf$ = a$
	'----- authored facing wins (wlkdd suppresses the later f-tag turn); else aim the eyes
	IF spx(woi%) >= 0 AND spd(woi%) >= 1 THEN a$ = LTRIM$(STR$(spd(woi%))): wlkdd = 1 ELSE GOSUB lookdir
	GOSUB face
	a$ = sf$
	RETURN

'----- lookdir: set a$ to the 8-way facing from the player's EYES (top of the
'----- head, ~5px into the sprite) toward the click point (b,a). Replaces the
'----- directions hardcoded in the room data, which assumed a center-screen
'----- player. Dead zones keep small offsets from twitching into diagonals.
lookdir:
	ldx = b - (pjx + 15)
	ldy = a - (pjy + 5)
	lxs = 0
	IF ldx < -10 THEN lxs = -1
	IF ldx > 10 THEN lxs = 1
	lys = 0
	IF ldy < -8 THEN lys = -1
	IF ldy > 8 THEN lys = 1
	a$ = "2"
	IF lxs = -1 AND lys = -1 THEN a$ = "7"
	IF lxs = 0 AND lys = -1 THEN a$ = "8"
	IF lxs = 1 AND lys = -1 THEN a$ = "9"
	IF lxs = -1 AND lys = 0 THEN a$ = "4"
	IF lxs = 1 AND lys = 0 THEN a$ = "6"
	IF lxs = -1 AND lys = 1 THEN a$ = "1"
	IF lxs = 1 AND lys = 1 THEN a$ = "3"
	RETURN

'----- joeface: load Joe face sprites, pick direction toward player
joeface:
	CLOSE
	OPEN "joed.pct" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 9705
		INPUT #1, fd(i), fu(i), fr(i), fl(i), fdl(i), fdr(i), ful(i), fur(i)
	NEXT
	9705 CLOSE
	OPEN "joed.msk" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 9710
		INPUT #1, mfd(i), mfu(i), mfr(i), mfl(i), mfdl(i), mfdr(i), mful(i), mfur(i)
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
		IF EOF(1) THEN GOTO 9955
		INPUT #1, wa(i)
	NEXT
	9955 CLOSE
	OPEN "wilb.msk" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 9960
		INPUT #1, mwa(i)
	NEXT

	9960 PUT (110, 128), mwa, AND: PUT (110, 128), wa, OR

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
		IF EOF(1) THEN GOTO 10205
		INPUT #1, wa(i), wb(i)
	NEXT
	10205 CLOSE
	OPEN "golf.msk" FOR INPUT AS #1
	FOR i = 0 TO 125
		IF EOF(1) THEN GOTO 10200
		INPUT #1, mwa(i), mwb(i)
	NEXT
	10200 i = 150

	10210 CALL PStep(135, i, 0, f3, 1.2, 0, wa(), mwa(), wb(), mwb(), wbg())
	i = i - 2
	CALL PStep(135, i, 1, f3, 1.2, 0, wa(), mwa(), wb(), mwb(), wbg())
	i = i + -2
	IF i >= 135 THEN GOTO 10210
	GET (135, 135)-(165, 165), wbg: PUT (135, 135), mwa, AND: PUT (135, 135), wa, OR
	IF sy$ <> "y" THEN GOTO 10400
	sy$ = ""
	PUT (135, 135), wbg, PSET: RETURN

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


'----- events: fire room-specific Wilbur / golf events by step count
events:
	IF doc <> 1 THEN GOTO 10840
	10840 IF klon = 0 THEN GOTO 11570
	IF q$ = "room7" AND (INT(cl * cr)) > 0 AND (INT(cl * cr)) < 8 THEN GOSUB wilb
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
	11570 IF (INT(cl * cr)) <= 30 THEN GOTO 11580
	ob(37) = 1
	11580 RETURN

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
	'----- no mouse driver loaded? the INT 33h vector is 0000:0000 when none
	'      is present; CALL INTERRUPT would then jump into the interrupt
	'      vector table and hang.  Bail out (disable the mouse) before calling.
	'      Test the 4 vector bytes directly -- PEEK()*256 would overflow INTEGER.
	DEF SEG = 0
	m33a = PEEK(&HCC): m33b = PEEK(&HCD): m33c = PEEK(&HCE): m33d = PEEK(&HCF)
	DEF SEG
	IF m33a = 0 AND m33b = 0 AND m33c = 0 AND m33d = 0 THEN msen = 0: RETURN
	'----- ...and bail if the vector points to a bare IRET stub (first byte
	'      &HCF).  That is what is there with NO real driver (e.g. after
	'      exiting Win98 to MS-DOS mode); calling INT 33h on it hangs.  A real
	'      driver's handler starts with executable code (mouse.com begins with
	'      a JMP, &HEB), never a bare IRET (&HCF) or a 0/dead byte -- so this
	'      tells a real driver from a dead leftover vector (seen as &HCF on one
	'      PC, 0 on another) without ever calling INT 33h.
	m33ls& = m33c + m33d * 256&
	m33lo& = m33a + m33b * 256&
	IF m33ls& > 32767 THEN m33si = m33ls& - 65536 ELSE m33si = m33ls&
	IF m33lo& > 32767 THEN m33oi = m33lo& - 65536 ELSE m33oi = m33lo&
	DEF SEG = m33si
	m33fb = PEEK(m33oi)
	DEF SEG
	IF m33fb = &HCF OR m33fb = 0 THEN msen = 0: RETURN
	mreg.ax = 0
	CALL INTERRUPT(mvint, mreg, mout)
	IF mout.ax = 0 THEN msen = 0
	mlb = 0
	mrb = 0
	cdrawn = 0
	lmx = -1
	lmy = -1
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
	nmx = mout.cx \ 2
	nmy = mout.dx
	IF nmx < 0 THEN nmx = 0
	IF nmx > 304 THEN nmx = 304
	IF nmy < 0 THEN nmy = 0
	IF nmy > 190 THEN nmy = 190
	IF nmx <> lmx OR nmy <> lmy THEN
		lmx = nmx
		lmy = nmy
		mx = nmx
		my = nmy
		b = (mx \ 4) * 4 + 2
		a = (my \ 4) * 4 + 2
		IF b > 302 THEN b = 302
		IF a < 10 THEN a = 10
		IF a > 190 THEN a = 190
		GOSUB hovexit
	END IF
	IF mxyon = 1 THEN GOSUB mxytick
	IF cdrawn = 0 OR mx <> cox OR my <> coy THEN CALL erasecur: CALL drawcur
	IF (mout.bx AND 1) <> 0 AND mlb = 0 THEN a$ = "a": GOSUB msnap
	IF (mout.bx AND 2) <> 0 AND mrb = 0 THEN a$ = "l": GOSUB msnap
	mlb = (mout.bx AND 1)
	mrb = (mout.bx AND 2)
	RETURN

'----- ksync: keyboard moved the hit point -> move the software pointer to match
'----- (mouse stays put, so mousepoll won't override until the mouse is moved)
ksync:
	mx = b
	my = a
	IF my > 190 THEN my = 190
	GOSUB hovexit
	RETURN

'----- synchit: re-derive the hit point from the cursor position (undo msnap's
'----- action-only snap, so a following keyboard nudge starts from the cursor, not the hotspot)
synchit:
	b = (mx \ 4) * 4 + 2
	a = (my \ 4) * 4 + 2
	IF b > 302 THEN b = 302
	IF a < 10 THEN a = 10
	IF a > 190 THEN a = 190
	RETURN



'----- snap click to nearest hotspot within snr px (0 = off/exact)
'----- VERB-AWARE: only weighs hotpoints whose object verb = a$, so a look-click snaps to
'----- the nearest LOOK point, never a closer get/action point that the action scan can't use
'----- ABS box just prefilters; sdd<snd is the real test = a circle of radius snr (Euclidean)
'----- breaks at first oy=0 exactly like action, so it never snaps to an entry action can't reach
msnap:
	IF snr <= 0 THEN RETURN
	' tie-break: a hotspot exactly under the cursor's own cell wins over an expanded (snapped) neighbour
	FOR sni = 1 TO 257
		IF oy(sni) = 0# THEN EXIT FOR
		IF ox(sni) = b AND oy(sni) = a AND ky$(oi(sni)) = a$ THEN RETURN
	NEXT
	snd = snr * snr + 1
	snx = -1
	FOR sni = 1 TO 257
		IF oy(sni) = 0# THEN EXIT FOR
		sdx = mx - ox(sni)
		sdy = my - oy(sni)
		IF ky$(oi(sni)) = a$ AND ABS(sdx) <= snr AND ABS(sdy) <= snr THEN
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
		IF LEFT$(tg$(hvo), 1) = "w" AND (bs(hvo) = 0 OR ob(bs(hvo)) = 1) AND (cs(hvo) = 0 OR ob(cs(hvo)) = 0) THEN
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
	CALL erasecur
	cshp = newshp
	RETURN

'----- AX=9 hardware-cursor shape code removed (software cursor is used instead)

'----- load object display names from object.pac
loadnames:
	CLOSE
	OPEN "object.pac" FOR INPUT AS #1
	FOR i = 1 TO 50
		IF EOF(1) THEN GOTO 12580
		INPUT #1, b, sn$(b), dn$(b)
	NEXT
	12580 CLOSE
	RETURN


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

	14700 CALL SaveLoadScreen(fontData(), mvint, msen, slvAct, 1)
	IF slvAct = 2 THEN RUN
	IF slvAct = 0 OR slvAct = 3 THEN GOTO 14700
	GOSUB loadroom
	IF tt$ <> "y" THEN a$ = lf$: lf$ = "": GOSUB face
	t0 = TIMER
	GOTO 14570

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

'----- DeathMusic moved to GAME2.BAS (multi-module split)


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
	'----- carr black-out / 1s hold / load / reveal moved to introShowCarr (GAME3), called below
	KEY OFF
	KEY 16, CHR$(0) + CHR$(1)
	KEY(16) ON

	'----- buffers + load car image
	DIM ec(1000) AS INTEGER
	DIM r1(130) AS INTEGER
	DIM r2(130) AS INTEGER
	DIM mr1(130) AS INTEGER
	DIM mr2(130) AS INTEGER
	DIM rbg(130) AS INTEGER
	CALL introShowCarr
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
	17340 SOUND tc, .1: SOUND f10, .1: SOUND 32676, 1
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

	'----- title music: "Dark Visions Theme" (original composition, D minor;
	'----- replaced Gounod's Funeral March of a Marionette / Hitchcock theme).
	'----- Trailing o0 restores the octave state the old block left, since later
	'----- jingles use relative <>'s from wherever the title music ended.
	18200 KEY 16, CHR$(0) + CHR$(1)
	KEY(16) ON
	PLAY "t120o2d4f8a8g+2g4f8e8c+4d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "o2d4f8a8b-2a4g8f8e4c+4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "o3d4f8a8g+2g4f8e8c+4d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "o3d4f8a8b-2a4g8f8e8d8c+4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "o3b-2a4g4f2e4d4"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "o3c+4e4g4b-4a2g+2"
	IF INKEY$ = "s" THEN GOTO 18640
	PLAY "o2d4f8e8e-8d8c+8d8o1a2o2d1o0"
	RETURN

	'----- animate Joe walking + dialogue
	18310 CLOSE
	w$ = "joew2"
	OPEN (w$) + ".pct" FOR INPUT AS #1
	tc = 0
	18370 INPUT #1, r1(tc), r2(tc)
	tc = tc + 1
	IF tc <= 125 THEN GOTO 18370
	CLOSE
	OPEN (w$) + ".msk" FOR INPUT AS #1
	tc = 0
	18375 INPUT #1, mr1(tc), mr2(tc)
	tc = tc + 1
	IF tc <= 125 THEN GOTO 18375
	CLOSE
	wc = wc + 1
	tc = 150
	18420 GET (143, tc)-(173, tc + 30), rbg: PUT (143, tc), mr1, AND: PUT (143, tc), r1, OR
	IF INKEY$ = "s" THEN GOTO 18640
	IF it0 >= 0 THEN ifc = ifc + 1
	GOSUB 17850

	FOR n = 1 TO 2
		SOUND 32676, .3
	NEXT
	PUT (143, tc), rbg, PSET
	IF tc <> 130 THEN GOTO 18530

	FOR n = 1 TO 10000
	NEXT
	tf = 0#
	IF it0 >= 0 THEN itt = itt + (TIMER - it0): it0 = -1: GOSUB introlog
	GOSUB 17590
	IF skp = 1 THEN GOTO 18640
	18530 tf = 1
	tc = tc - 2
	GET (143, tc)-(173, tc + 30), rbg: PUT (143, tc), mr2, AND: PUT (143, tc), r2, OR
	IF INKEY$ = "s" THEN GOTO 18640
	IF it0 >= 0 THEN ifc = ifc + 1
	GOSUB 17850

	FOR n = 1 TO 2
		SOUND 32676, .3
	NEXT
	PUT (143, tc), rbg, PSET
	tc = tc - 2
	IF tc >= 116 THEN GOTO 18420
	RETURN

	'----- skip / cleanup exit
	18640 IF it0 >= 0 THEN itt = itt + (TIMER - it0): it0 = -1: GOSUB introlog
	it0 = -1
	ERASE ec
	ERASE r1
	ERASE r2
	ERASE mr1
	ERASE mr2
	ERASE rbg
	EXIT SUB

	'----- write intro frame/time log
introlog:
	IF sfps <> 1 THEN RETURN
	OPEN "intro.log" FOR APPEND AS #2
	PRINT #2, ifc; itt
	CLOSE #2
	RETURN

END SUB


'----- LoadConfig moved to GAME2.BAS (multi-module split)


'----- compute and print percent of game completed
'----- (PctComplete removed: legacy % display, only the retired inv: clock used it)

'----- Snd1-Snd5 moved to GAME2.BAS (multi-module split)

'----- (no diagnostic tracer in release builds)


SUB drawcur
	GET (mx, my)-(mx + 15, my + 9), curbuf
	FOR mi = 0 TO npix(cshp) - 1
		PSET (mx + px(cshp, mi), my + py(cshp, mi)), pc(cshp, mi)
	NEXT
	cox = mx: coy = my: cdrawn = 1
END SUB

SUB erasecur
	IF cdrawn = 1 THEN PUT (cox, coy), curbuf, PSET
	cdrawn = 0
END SUB

SUB invhi
	SCREEN 1
	PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	CLS
	tst = 330: ist = 245
	FOR ivi = 1 TO 30: tix(ivi) = ivi - 1: NEXT
	tix(49) = 30: tix(36) = 31: tix(34) = 32: tix(35) = 33
	'----- the unreadable formula (52, combine step 1) has its own tile 37
	'----- (INVTIL2/INVMSK2 slot 16; art = the complete-formula icon relabeled)
	tix(52) = 37
	'----- load keep-masks -> kmarr, then tiles -> tilarr (full) + iconarr (tile AND keepmask = frameless item)
	DEF SEG = -18432
	BLOAD "INVMSK1.PIC", 0
	DEF SEG
	FOR ivk = 0 TO 20
		ivc = ivk MOD 7: ivr = ivk \ 7
		GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 39), kmarr(ivk * ist)
	NEXT
	DEF SEG = -18432
	BLOAD "INVTIL1.PIC", 0
	DEF SEG
	FOR ivk = 0 TO 20
		ivc = ivk MOD 7: ivr = ivk \ 7
		GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 53), tilarr(ivk * tst)
		PUT (ivc * 45, ivr * 54), kmarr(ivk * ist), AND
		GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 39), iconarr(ivk * ist)
	NEXT
	DEF SEG = -18432
	BLOAD "INVMSK2.PIC", 0
	DEF SEG
	FOR ivk = 21 TO 37
		'----- slot 15 (ivk 36) is the ring AND-mask tile, no keep-mask
		IF ivk <> 36 THEN ivj = ivk - 21: ivc = ivj MOD 7: ivr = ivj \ 7: GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 39), kmarr(ivk * ist)
	NEXT
	DEF SEG = -18432
	BLOAD "INVTIL2.PIC", 0
	DEF SEG
	FOR ivk = 21 TO 37
		ivj = ivk - 21: ivc = ivj MOD 7: ivr = ivj \ 7
		GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 53), tilarr(ivk * tst)
		IF ivk <> 36 THEN PUT (ivc * 45, ivr * 54), kmarr(ivk * ist), AND: GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 39), iconarr(ivk * ist)
	NEXT
	'----- derive AND-screen masks in place: kmarr = NOT keepmask (PRESET draws NOT), for the drag sprite (36 = ring mask, skip)
	FOR ivk = 0 TO 37
		IF ivk <> 36 THEN PUT (0, 0), kmarr(ivk * ist), PRESET: GET (0, 0)-(44, 39), kmarr(ivk * ist)
	NEXT
	'----- build the carried-item list (newest-first)
	GOSUB cibuild
	'----- load the single background; GET both panels, erase the Info template
	DEF SEG = -18432
	BLOAD "INVMAIN.PIC", 0
	DEF SEG
	REDIM combuf(800), infobuf(800), modalbuf(500), combtn(80), exmico(40)
	GET (29, 129)-(85, 144), combtn
	LINE (29, 129)-(85, 144), 0, BF
	GET (182, 40)-(199, 58), exmico
	LINE (182, 40)-(199, 58), 0, BF
	GET (279, 21)-(283, 25), starr
	LINE (279, 21)-(283, 25), 0, BF
	GET (10, 27)-(104, 151), combuf
	GET (108, 27)-(202, 151), infobuf
	GET (210, 34)-(297, 73), modalbuf
	LINE (8, 27)-(202, 151), 0, BF
	LINE (210, 34)-(297, 73), 0, BF
	invtab = 0
	isel = 0: ivscr = 0: cbot = 0: cdrg = 0: crec = 0
	ivmax = (cic + 3) \ 4 - 2: IF ivmax < 0 THEN ivmax = 0
	mlb = 0
	IF msen = 1 THEN cshp = 0: mx = 160: my = 100: cdrawn = 0: mreg.ax = &H11: CALL INTERRUPT(mvint, mreg, mout)
	GOSUB invdraw
	IF msen = 1 THEN CALL drawcur
	PALETTE 1, 6: PALETTE 2, 7: PALETTE 3, 8
	invwait:
	IF msen = 1 THEN
		mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout)
		nmx = mout.cx \ 2: nmy = mout.dx: ivwh = mout.bx \ 256
		IF nmx > 304 THEN nmx = 304 ELSE IF nmx < 0 THEN nmx = 0
		IF nmy > 190 THEN nmy = 190 ELSE IF nmy < 0 THEN nmy = 0
		IF nmx <> mx OR nmy <> my THEN IF cdrg = 1 THEN GOSUB dragmove ELSE CALL erasecur: mx = nmx: my = nmy: CALL drawcur
		IF ivwh <> 0 THEN ivns = ivscr + SGN(ivwh): GOSUB invss
		IF (mout.bx AND 1) <> 0 AND mx >= 299 AND my >= 37 AND my <= 145 THEN ivns = (my - 37 - ivth \ 2) * ivmax \ (108 - ivth): GOSUB invss
		IF (mout.bx AND 1) <> 0 AND mlb = 0 THEN
			IF my >= 28 AND my <= 42 AND mx >= 14 AND mx <= 52 AND invtab <> 0 THEN invtab = 0: GOSUB invredraw
			IF my >= 28 AND my <= 42 AND mx >= 53 AND mx <= 98 AND invtab <> 1 THEN invtab = 1: GOSUB invredraw
			IF exf = 1 AND mx >= 84 AND mx <= 101 AND my >= 43 AND my <= 58 THEN GOSUB doexam
			IF mx >= 275 AND mx <= 312 AND my >= 164 AND my <= 183 THEN GOTO invdone
			IF mx >= 188 AND mx <= 264 AND my >= 164 AND my <= 183 THEN GOSUB svldopen: IF slvAct <> 0 THEN GOTO invdone ELSE mlb = 1: GOTO invwait
			IF mx >= 4 AND mx <= 96 AND my >= 164 AND my <= 183 THEN GOSUB doquit: mlb = 1: GOTO invwait
			IF mx >= 299 AND my >= 28 AND my <= 36 THEN ivns = ivscr - 1: GOSUB invss
			IF mx >= 299 AND my >= 146 AND my <= 154 THEN ivns = ivscr + 1: GOSUB invss
			IF invtab = 1 AND crec > 0 AND mx >= 32 AND mx <= 81 AND my >= 129 AND my <= 143 THEN GOSUB combdo
			IF mx >= 112 AND mx <= 297 AND my >= 31 AND my <= 140 THEN
				nsel = ivscr * 4 + ((my - 31) \ 56) * 4 + (mx - 112) \ 47
				IF nsel < cic THEN
					IF invtab = 1 AND nsel <> isel THEN
						cdi = cilist(nsel): GOSUB dragstart
					ELSEIF invtab <> 1 THEN
						isel = nsel: GOSUB invredraw
					END IF
				END IF
			END IF
		END IF
		IF (mout.bx AND 1) = 0 AND mlb <> 0 AND cdrg = 1 THEN
			cdrg = 0
			PUT (dgx, dgy), dsav, PSET
			IF mx <= 104 THEN
				cbot = cdi: GOSUB invredraw
			ELSEIF mx >= 112 AND mx <= 297 AND my >= 31 AND my <= 140 THEN
				nsel = ivscr * 4 + ((my - 31) \ 56) * 4 + (mx - 112) \ 47
				IF nsel < cic THEN isel = nsel: GOSUB invredraw
			END IF
		END IF
		mlb = (mout.bx AND 1)
	END IF
	ivk$ = INKEY$
	IF ivk$ = CHR$(27) OR ivk$ = "x" OR ivk$ = "i" THEN GOTO invdone
	IF ivk$ = "q" OR ivk$ = "Q" THEN GOSUB doquit: mlb = 1: GOTO invwait
	IF ivk$ = "s" OR ivk$ = "S" OR ivk$ = "l" OR ivk$ = "L" THEN GOSUB svldopen: IF slvAct <> 0 THEN GOTO invdone ELSE mlb = 1: GOTO invwait
	nsel = isel
	IF ivk$ = CHR$(0) + CHR$(72) THEN nsel = isel - 4
	IF ivk$ = CHR$(0) + CHR$(80) THEN nsel = isel + 4
	IF ivk$ = CHR$(0) + CHR$(75) THEN nsel = isel - 1
	IF ivk$ = CHR$(0) + CHR$(77) THEN nsel = isel + 1
	IF nsel < 0 OR nsel >= cic THEN nsel = isel
	IF nsel <> isel THEN
		isel = nsel
		IF isel \ 4 < ivscr THEN ivscr = isel \ 4
		IF isel \ 4 > ivscr + 1 THEN ivscr = isel \ 4 - 1
		GOSUB invredraw
	END IF
	GOTO invwait
	invdone:
	IF msen = 1 THEN CALL erasecur
	FOR ivi = 1 TO 35: nwf(iord(ivi)) = 0: NEXT
	SCREEN 1
	EXIT SUB

	'----- lift the cursor, redraw the inventory, put the cursor back
	invredraw:
	IF msen = 1 THEN CALL erasecur
	IF invtab = 1 AND cic > 0 THEN IF cilist(isel) = cbot THEN cbot = 0
	GOSUB invdraw
	IF msen = 1 THEN CALL drawcur
	RETURN

	'----- quit confirmation: show centered modal, wait for Yes/No (click or key)
	doquit:
	IF msen = 1 THEN CALL erasecur
	CALL DrawYNBox("Quit the game?", 3, fontData())
	IF msen = 1 THEN CALL drawcur
	CALL QuitConfirm
	DEF SEG = -18432: BLOAD "INVMAIN.PIC", 0: DEF SEG
	PALETTE 1, 6: PALETTE 2, 7: PALETTE 3, 8
	LINE (8, 27)-(202, 151), 0, BF: LINE (210, 34)-(297, 73), 0, BF
	GOSUB invdraw
	IF msen = 1 THEN CALL drawcur
	RETURN

	'----- clamp a new scroll value and apply it
	invss:
	IF ivns < 0 THEN ivns = 0
	IF ivns > ivmax THEN ivns = ivmax
	IF ivns <> ivscr THEN ivscr = ivns: GOSUB invredraw
	RETURN

	'----- draw the active panel, then the grid cells, selection ring, info icon
	invdraw:
	IF cic > 0 THEN nwf(cilist(isel)) = 0
	LINE (279, 21)-(283, 25), 0, BF
	IF invtab = 0 THEN PUT (10, 27), infobuf, PSET ELSE PUT (10, 27), combuf, PSET
	FOR ivs = 0 TO 7
		ivc = ivs MOD 4: ivr = ivs \ 4
		ivpx = 112 + ivc * 47: ivpy = 31 + ivr * 56
		ivx = ivscr * 4 + ivs
		IF ivx < cic THEN ivtk = tix(cilist(ivx)) ELSE ivtk = 34
		PUT (ivpx, ivpy), tilarr(ivtk * tst), PSET
		IF ivx < cic THEN IF nwf(cilist(ivx)) = 1 THEN PUT (ivpx + 36, ivpy + 3), starr, OR
	NEXT
	ivss = isel - ivscr * 4
	IF ivss >= 0 AND ivss <= 7 THEN
		ivc = ivss MOD 4: ivr = ivss \ 4: ivpx = 112 + ivc * 47: ivpy = 31 + ivr * 56
		PUT (ivpx, ivpy), tilarr(36 * tst), AND
		PUT (ivpx, ivpy), tilarr(35 * tst), OR
	END IF
	exf = 0
	IF invtab = 0 AND cic > 0 THEN
		sel = cilist(isel)
		CALL drawText(16, 46, sn$(sel), 2, fontData())
		PUT (30, 56), kmarr(tix(sel) * ist), AND
		PUT (30, 56), iconarr(tix(sel) * ist), OR
		CALL drawWrap(14, 114, dn$(sel), 2, 88, 8, fontData())
		IF INSTR("/3/9/10/16/19/21/25/", "/" + LTRIM$(STR$(sel)) + "/") THEN exf = 1: PUT (84, 40), exmico, PSET
	END IF
	IF invtab = 1 THEN
		IF cic > 0 THEN sel = cilist(isel): PUT (35, 39), kmarr(tix(sel) * ist), AND: PUT (35, 39), iconarr(tix(sel) * ist), OR
		IF cbot > 0 THEN PUT (35, 89), kmarr(tix(cbot) * ist), AND: PUT (35, 89), iconarr(tix(cbot) * ist), OR
		GOSUB combchk
	END IF
	GOSUB invthumb
	CALL drawStats(ob(), cl, cr, fontData())
	IF cic > 0 THEN sel = cilist(isel)
	RETURN

	'----- scrollbar thumb
	invthumb:
	LINE (302, 37)-(306, 145), 0, BF
	LINE (303, 37)-(303, 145), 3
	LINE (305, 37)-(305, 145), 3
	ivtot = (cic + 3) \ 4
	IF ivtot < 1 THEN ivtot = 1
	IF ivtot <= 2 THEN
		LINE (302, 37)-(306, 145), 2, BF
	ELSE
		ivth = 218 \ ivtot
		IF ivth < 8 THEN ivth = 8
		ivty = 37 + (ivscr * (108 - ivth)) \ (ivtot - 2)
		LINE (302, ivty)-(306, ivty + ivth), 2, BF
	END IF
	RETURN

	'----- rebuild the carried-item list (newest-first), recompute scroll max
	cibuild:
	cic = 0
	FOR ivi = 1 TO 35
		ivn = iord(ivi)
		IF ob(ivn) = 1 THEN cilist(cic) = ivn: cic = cic + 1
	NEXT
	FOR ivi = 0 TO cic - 2
		FOR ivj = 0 TO cic - 2 - ivi
			IF aqo(cilist(ivj)) < aqo(cilist(ivj + 1)) THEN SWAP cilist(ivj), cilist(ivj + 1)
		NEXT
	NEXT
	ivmax = (cic + 3) \ 4 - 2: IF ivmax < 0 THEN ivmax = 0
	RETURN

	'----- combine: set crec to the recipe matched by top (sel) + bottom (cbot); hide button if none
	combchk:
	crec = 0
	IF cic > 0 AND cbot > 0 THEN
		sel = cilist(isel)
		selx% = sel: cbx% = cbot
		IF (selx% = 18 AND cbx% = 28) OR (selx% = 28 AND cbx% = 18) THEN crec = 1
		'----- formula step 1: the two halves (11+24, either order) tape into
		'----- the UNREADABLE formula 52 -- no book needed yet
		IF (selx% = 11 AND cbx% = 24) OR (selx% = 24 AND cbx% = 11) THEN crec = 2
		'----- formula step 2: unreadable formula + deciphering book -> complete 36
		IF (selx% = 52 AND cbx% = 25) OR (selx% = 25 AND cbx% = 52) THEN crec = 4
		IF (selx% = 29 AND cbx% = 34) OR (selx% = 34 AND cbx% = 29) THEN crec = 3
	END IF
	IF crec > 0 THEN PUT (29, 129), combtn, PSET
	RETURN

	'----- combine: apply the matched recipe, then refresh
	combdo:
	cnew% = 0
	IF crec = 1 THEN ob(18) = 0: ob(28) = 0: ob(22) = 1: cnew% = 22
	IF crec = 2 THEN ob(24) = 0: ob(11) = 0: ob(52) = 1: cnew% = 52
	IF crec = 3 THEN ob(29) = 0: ob(34) = 0: ob(35) = 1: cnew% = 35
	IF crec = 4 THEN ob(52) = 0: ob(36) = 1: cnew% = 36
	IF ob(32) = 1 AND ob(36) = 1 THEN ob(33) = 1
	IF cnew% > 0 THEN aqc = aqc + 1: aqo(cnew%) = aqc
	cbot = 0
	invtab = 0
	GOSUB cibuild
	isel = 0: ivscr = 0
	GOSUB invredraw
	RETURN

	'----- draw the held item's icon centered on the cursor (AND-mask clears, OR fills = transparent over grid)
	dragdraw:
	dgx = mx - 22: IF dgx < 0 THEN dgx = 0 ELSE IF dgx > 275 THEN dgx = 275
	dgy = my - 20: IF dgy < 0 THEN dgy = 0 ELSE IF dgy > 160 THEN dgy = 160
	GET (dgx, dgy)-(dgx + 44, dgy + 39), dsav
	PUT (dgx, dgy), kmarr(tix(cdi) * ist), AND
	PUT (dgx, dgy), iconarr(tix(cdi) * ist), OR
	RETURN

	'----- start dragging: hide the arrow cursor, draw the held item at the cursor
	dragstart:
	cdrg = 1
	IF msen = 1 THEN CALL erasecur
	GOSUB dragdraw
	RETURN

	'----- drag move: restore the bg under the old position, redraw the item at the new
	dragmove:
	PUT (dgx, dgy), dsav, PSET
	mx = nmx: my = nmy
	GOSUB dragdraw
	RETURN

	'----- examine: show the item's full-screen content, wait for a key/click, then restore the inventory
	doexam:
	IF msen = 1 THEN CALL erasecur
	IF sel = 16 THEN bk$ = "MAP1" ELSE bk$ = "BOOK": PALETTE 1, 7: PALETTE 2, 2: PALETTE 3, 15
	IF sel = 16 THEN PALETTE 1, 6: PALETTE 2, 4: PALETTE 3, 8
	DEF SEG = -18432: BLOAD bk$ + ".PIC", 0
	GOSUB exdrain
	IF sel <> 16 THEN CALL showBook(sel, font3Data())
	exwt:
	ek$ = INKEY$: IF ek$ <> "" THEN GOTO exret
	IF msen = 1 THEN mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout): IF (mout.bx AND 1) <> 0 THEN GOTO exret
	GOTO exwt
	exret:
	GOSUB exdrain
	BLOAD "INVMAIN.PIC", 0: DEF SEG
	PALETTE 1, 6: PALETTE 2, 7: PALETTE 3, 8
	LINE (8, 27)-(202, 151), 0, BF: LINE (210, 34)-(297, 73), 0, BF
	GOSUB invdraw
	IF msen = 1 THEN CALL drawcur
	RETURN

	'----- wait for any held mouse button to release (drains the click)
	exdrain:
	IF msen = 0 THEN RETURN
	DO
		mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout)
	LOOP WHILE (mout.bx AND 1) <> 0
	RETURN

	'----- open the graphical Save/Load screen. Cancel (slvAct=0) restores the inventory and stays here; Load/New (slvAct<>0) leave the screen up so the caller GOTO invdone -> game.
	svldopen:
	CALL SaveLoadScreen(fontData(), mvint, msen, slvAct, 0)
	IF slvAct <> 0 THEN RETURN
	DEF SEG = -18432: BLOAD "INVMAIN.PIC", 0: DEF SEG
	PALETTE 1, 6: PALETTE 2, 7: PALETTE 3, 8
	LINE (8, 27)-(202, 151), 0, BF: LINE (210, 34)-(297, 73), 0, BF
	GOSUB invdraw
	IF msen = 1 THEN CALL drawcur
	RETURN

END SUB

'----- QuitConfirm: wait for Yes/No on the quit modal (click a button or press Y/N)
SUB QuitConfirm
	'----- let the opening click release so it doesn't carry into Yes/No
	IF msen = 1 THEN
		DO
			mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout)
		LOOP WHILE (mout.bx AND 1) <> 0
	END IF
	DO
		qk$ = INKEY$
		IF qk$ = "y" OR qk$ = "Y" THEN SYSTEM
		IF qk$ = "n" OR qk$ = "N" THEN EXIT SUB
		IF msen = 1 THEN
			mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout)
			nmx = mout.cx \ 2: nmy = mout.dx
			IF nmx > 304 THEN nmx = 304 ELSE IF nmx < 0 THEN nmx = 0
			IF nmy > 190 THEN nmy = 190 ELSE IF nmy < 0 THEN nmy = 0
			IF nmx <> mx OR nmy <> my THEN CALL erasecur: mx = nmx: my = nmy: CALL drawcur
			IF (mout.bx AND 1) <> 0 THEN
				IF mx >= 92 AND mx <= 142 AND my >= 105 AND my <= 117 THEN SYSTEM
				IF mx >= 178 AND mx <= 228 AND my >= 105 AND my <= 117 THEN EXIT SUB
				IF mx >= 260 AND mx <= 270 AND my >= 80 AND my <= 87 THEN EXIT SUB
			END IF
		END IF
	LOOP
END SUB

'----- write the live game state to slot 1-10 (saver a-j.pac). Lives in GAME.BAS for DIM SHARED access; called from the GAME4 save/load screen.
SUB SaveGame (slot AS INTEGER)
	DIM slz AS INTEGER
	OPEN "saver" + CHR$(slot + 96) + ".pac" FOR OUTPUT AS #1
	WRITE #1, q$, cl, pt, done$, tt$, a$, lf$
	FOR slz = 1 TO 65
		WRITE #1, ob(slz)
	NEXT
	CLOSE #1
END SUB

'----- read game state from slot 1-10 + rebuild inventory acquire-order/new-flags (mirrors the old reload: path)
SUB LoadGame (slot AS INTEGER)
	DIM slz AS INTEGER
	OPEN "saver" + CHR$(slot + 96) + ".pac" FOR INPUT AS #1
	INPUT #1, q$, cl, pt, done$, tt$, a$, lf$
	tt$ = "n": done$ = "": IF LEN(lf$) <> 1 OR INSTR("12346789", lf$) = 0 THEN lf$ = "2"
	FOR slz = 1 TO 65
		INPUT #1, ob(slz)
	NEXT
	CLOSE #1
	aqc = 0
	FOR slz = 1 TO 35
		IF ob(iord(slz)) = 1 THEN aqc = aqc + 1: aqo(iord(slz)) = aqc ELSE aqo(iord(slz)) = 0
		nwf(iord(slz)) = 0
	NEXT
	ERASE er1
	FOR slz = 1 TO 40
		gp(slz) = 0#
	NEXT
END SUB
