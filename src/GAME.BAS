REM $DYNAMIC
'--Dark Visions  by Rob & Jon Kreuzer--
'Programmed in QuickBASIC 4.5

'----- SUB declarations
DECLARE SUB Intro ()
DECLARE SUB Credits (gd%)
DECLARE SUB invhi ()
DECLARE SUB SlotScreen (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, mode AS INTEGER, dead AS INTEGER, act AS INTEGER)
DECLARE SUB MainMenu (fontData() AS INTEGER, mvint AS INTEGER, msen AS SINGLE, act AS INTEGER, dead AS INTEGER)
DECLARE SUB ReviveShow (mvint AS INTEGER, msen AS SINGLE)
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
DECLARE SUB YNWait (mvint AS INTEGER, msen AS SINGLE, dk AS INTEGER, res AS INTEGER)
DECLARE SUB DeathMusic ()
DECLARE SUB LoadConfig ()
DECLARE SUB LoadMsgs (nf$())
DECLARE SUB UseMissLine (sel, wantbs, out$)
DECLARE SUB MovParse (s$, mdx%(), mdy%(), mn%, bx1%, by1%, bx2%, by2%)
DECLARE SUB OvPlayer (x1, y1, x2, y2, pjx2, pjy2, np, ov%)
DECLARE SUB LookMissLine (bx%, ay%, ox%(), oy%(), nf$(), out$)
DECLARE SUB AnimDims (acPct%(), acN%(), acs, adw, adh)
DECLARE SUB AnimK (acPct%(), acN%(), acs, kk%)
DECLARE SUB FpsTick ()
DECLARE SUB MxyTick (mx%, my%, bx, ay, snr2, ox%(), oy%(), oi%(), ky$())
DECLARE SUB HitZones (hz$, snr2, ox%(), oy%(), oi%(), ky$())
DECLARE SUB DirDigit (l$, d$)
DECLARE SUB AnimParse (s$, fsq%(), nfr2%)
DECLARE SUB AnimWait (rate2)
DECLARE SUB InvReSel (cilist%(), cic2, lv%, is2, iv2, ivm)
DECLARE SUB RmPal (co2, p1, p2, p3)
DECLARE SUB LoadFade (co2, p1, p2, p3)
DECLARE SUB InvNav (k$, nvz, nvb, isel, cic, invtab, ivscr, ivmax, mx2%, my2%, act%)
DECLARE SUB JoyNav (d$)
DECLARE SUB JoyPoll (a2$, vk2$)
DECLARE SUB CombChk (s%, c%, r%)
DECLARE SUB CombDo2 (r%, ob(), cn%)
DECLARE SUB initAllFonts (fontData() AS INTEGER, font3Data() AS INTEGER, fontbData() AS INTEGER)
DECLARE SUB drawChar (x AS INTEGER, y AS INTEGER, char AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
DECLARE SUB drawText (x AS INTEGER, y AS INTEGER, text AS STRING, textColor AS INTEGER, fontData() AS INTEGER)
DECLARE SUB drawWrap (x AS INTEGER, y AS INTEGER, txt AS STRING, col AS INTEGER, maxc AS INTEGER, lineh AS INTEGER, fontData() AS INTEGER)
DECLARE FUNCTION textWidth (text AS STRING, fontData() AS INTEGER)
DECLARE SUB drawStats (ob() AS SINGLE, cl AS SINGLE, cr AS SINGLE, fontData() AS INTEGER)
DECLARE SUB drawMsg (s AS STRING, fontData() AS INTEGER)
DECLARE SUB HudUse (sel2 AS INTEGER, ob() AS SINGLE, sn$(), fontData() AS INTEGER)
DECLARE SUB introShowCarr ()
DECLARE SUB introFadeCredit ()
DECLARE SUB showBook (sel AS SINGLE, fontData() AS INTEGER)
DECLARE SUB MapView (hasmap AS INTEGER, curRoom AS INTEGER, vis AS LONG, mvint AS INTEGER, msen AS SINGLE)
DECLARE SUB PStand (d$, px!, py!, nopl!, fbg%(), fd%(), mfd%(), fu%(), mfu%(), fr%(), mfr%(), fl%(), mfl%(), fdl%(), mfdl%(), fdr%(), mfdr%(), ful%(), mful%(), fur%(), mfur%(), ovf%())
DECLARE SUB PStep (x!, y!, fb%, sfrq!, sdur!, ofs%, wa%(), mwa%(), wb%(), mwb%(), wbg%(), ovf%())
DECLARE SUB LoadWalks (cwa%(), cmwa%(), cwb%(), cmwb%())
DECLARE SUB OvReg (ovf%(), afrm%(), amfrm%(), anpf!, ovh!, ovnext!, PX!, PY!)
DECLARE SUB ClimbSeq (up%, x!, y0!, y1!, sfrq!, wa%(), mwa%(), wb%(), mwb%(), wbg%(), ovf%())
DECLARE SUB KillChk (q2$, w!, h9b!, t1b!, t2b!, t3b!, f3b!, kw%)
DECLARE SUB ShadLoad (sdt%())
DECLARE SUB ShadRoom (q2$)
DECLARE SUB ShadTick (q2$, clv!, h9b!, t1b!, t2b!, t3b!, ob43%, pjxv!, pjyv!, bv!, av!, sdt%(), bop$, blt$, fbg%())
DECLARE SUB PGrab (lf2$, fd%(), mfd%(), fu%(), mfu%(), fr%(), mfr%(), fl%(), mfl%(), fdl%(), mfdl%(), fdr%(), mfdr%(), ful%(), mful%(), fur%(), mfur%())
DECLARE SUB LookDir (bx!, ay!, px2!, py2!, d2$)
DECLARE SUB DialGame (sf3!, sf4!, ob() AS SINGLE)
DECLARE SUB BurnShow ()
DECLARE SUB CursorPats (px!(), py!(), pc!(), npix!())
DECLARE SUB walkTo (tx!, ty!, px!, py!, sfrq!, cwa%(), cmwa%(), cwb%(), cmwb%(), wbg%(), ovf%())
DECLARE SUB PicSeq (sq$, fr$, rate%, sn2$)
DECLARE SUB ShowRules ()

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
COMMON SHARED f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, sa, sb, sc, mt, sfps, fpsc, fpst, jsen, inon, msen, snr, exsen, mxyon, nfon, hzon$, klon, wksen, qkon, rvon
COMMON SHARED mcur AS INTEGER, mvint AS INTEGER
DIM SHARED pk, jx, jy, dx2, dy2, co, co2, pa1, pa2, pa3
DIM SHARED oh, ohs, pz, j, pc, pp2, gm, tmo, wk, js0, js1
DIM SHARED fpsv, fpsd
DIM SHARED ifc, it0, itt
DIM SHARED mlb, mrb, mshown, cshp, hovr
DIM SHARED nf$(25), nfseed, lcount, lastlx, lastly, lh1, lh2, lh3
'----- usemiss: acthit = the last action call fired an object (0 = the click/use
'----- resolved to nothing); wantbs = a use point hit whose bs wanted a DIFFERENT
'----- item (0 = none) -- lets UseMissLine (GAME2) answer key-on-wrong-lock specially
DIM SHARED acthit, wantbs
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
DIM SHARED wbg(210) AS INTEGER
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
DIM SHARED anId(70) AS INTEGER, anRate(70) AS INTEGER
DIM SHARED anName$(70), anType$(70), anSrc$(70), anFrames$(70), anMode$(70), anPal$(70), anSnd$(70)
DIM SHARED plAnim(20) AS INTEGER, plX(20) AS INTEGER, plY(20) AS INTEGER, plCond(20) AS INTEGER, plSet(20) AS INTEGER
'----- scratch buffers for the generic .pct/.msk frame loader (de-interleave + masked draw)
'----- anim frame buffers: 460 ints = frames up to ~110x32 for static/hold composites;
'----- loop/random/once stay <=31x31 (their save-under slots are 150 ints)
DIM SHARED afrm(460) AS INTEGER, amfrm(460) AS INTEGER, fsq(30) AS INTEGER
'----- anim source cache: each .pct/.msk pair parsed from disk ONCE, then reused (6 slots,
'----- round-robin evict). REDIM = dynamic arrays in the far heap, so DGROUP is untouched.
REDIM SHARED acPct(6, 1600) AS INTEGER, acMsk(6, 1600) AS INTEGER
DIM SHARED acSrc$(6), acN(6) AS INTEGER, acM(6) AS INTEGER
'----- foreground overlays ("fg" mode): furniture the player walks BEHIND. ovf(0)=count,
'----- then 4 ints per overlay (x, y, pct start, msk start), frame data packed after 17;
'----- PStand/PStep re-PUT any overlay that intersects the player box (GAME5 OvTop)
REDIM SHARED ovf(1500) AS INTEGER
'----- room9 gateopen cutscene save-under (union of the rope overlay rects)
REDIM SHARED gsv(2100) AS INTEGER
'----- shadow-door watcher pixel pool (SHADW2.PAC v5 raw blocks; parsed/drawn
'----- by GAME2 ShadLoad/ShadTick -- far heap, 4 watchers outgrew DGROUP) +
'----- the two CALL ABSOLUTE blitter routines (velocity-style .OVL strings)
REDIM SHARED sdwDat(27000) AS INTEGER
DIM SHARED sdwB1$, sdwB2$, sdwlf$
'----- active loop-animation instances for the current room (idle-loop tick)
DIM SHARED nLoop AS INTEGER
DIM SHARED liAnim(4) AS INTEGER, liX(4) AS INTEGER, liY(4) AS INTEGER, liCur(4) AS INTEGER, liRate(4) AS INTEGER
DIM SHARED liLast(4) AS SINGLE, liSaveAll(850) AS INTEGER
'----- random mode: liWait = seconds until the next frame advance; liMin/liMax = the random
'----- per-frame hold (seconds) -- every frame shows min..max s ("random min max" in ANIMS.PAC)
DIM SHARED liWait(4) AS SINGLE, liMin(4) AS SINGLE, liMax(4) AS SINGLE
'----- liW/liH = instance frame size (= its save-under GET size, from animdims)
DIM SHARED liW(4) AS INTEGER, liH(4) AS INTEGER
'----- liCond = the instance's placement cond; negative = "while flag OFF" -- the
'----- loop freezes the moment ob(-cond) turns ON (tick-tock until the clock slides)
DIM SHARED liCond(4) AS INTEGER
'----- plStat = per-placement "static frame is on screen" -- lets reanim composite a
'----- flag-gated static sprite the moment its flag trips, exactly once
DIM SHARED plStat(20) AS INTEGER
'----- move-mode anims: per-step 1px deltas parsed from the script (GAME2 MovParse)
DIM SHARED mdx(60) AS INTEGER, mdy(60) AS INTEGER
'----- an unplayed move placement SHOWS frame 0 at its start spot; mvSave holds the
'----- background under that idle frame so the travel can lift it cleanly (mvSp = owner)
DIM SHARED mvSave(210) AS INTEGER, mvSp AS INTEGER
'----- xus = per-object "use consumes the item" (tg suffix "x" in the .pac)
DIM SHARED xus(25) AS INTEGER
'----- lvsel = the ITEM selected when the inventory was last closed (0 = none);
'----- reselected on reopen (by item number -- the grid order can shift)
DIM SHARED lvsel AS INTEGER

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
DIM SHARED iord(36)
'----- mrn = last real room number (map screen dot + visited marking)
DIM SHARED mrn
DIM SHARED gp(100)
DIM SHARED er1(400)
DIM SHARED d(300)
DIM SHARED tilarr(12900) AS INTEGER
DIM SHARED iconarr(9600) AS INTEGER
DIM SHARED kmarr(9600) AS INTEGER
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
GOSUB shadload
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
430 IF a$ = "Y" OR a$ = "y" THEN CALL ShowRules

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
'----- rules screen: moved to GAME3 ShowRules (GAME.BAS is at the 64K code ceiling)

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
	'----- safe dial minigame: body in GAME4 DialGame -- 64K ceiling
	CALL DialGame(f3, f4, ob())
	RETURN
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
	acthit = 0: wantbs = 0
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
	'----- use records need the item STRICTLY held (ob=1): a consumed item
	'----- (state 2) satisfies flag checks but must not fire uses
	6230 IF ky$(i) <> "u" THEN GOTO 6260
	IF bs(i) = sel AND ob(sel) = 1 THEN GOTO 6260
	wantbs = bs(i)
	GOTO 6280
	6260 IF bs(i) = 0 OR ob(bs(i)) >= 1 THEN GOTO 6300
	6280 i = oh
	GOTO 6130
	6300 IF cs(i) = 0 OR ob(cs(i)) = 0 THEN GOTO 6340
	i = oh
	GOTO 6130

'----- Apply state change and print message (get/use first walk the player over)
6340 acthit = 1
	GOSUB wlkitem
	ob(CINT(st(i))) = 1
	'----- getting the map (16) opens the map screen instead of the inventory --
	'----- deferred to after the action wraps up (dmq checked in the mainloop)
	IF (a$ = "g" OR a$ = "u") AND CINT(st(i)) = 16 THEN dmq = 1: dm$ = ms$(i)
	IF a$ = "u" AND CINT(st(i)) = 68 THEN goq = 1
	'----- a consuming use takes the item out of the inventory. State 2 = "used
	'----- up": gone from the inventory (which lists =1 only) but still counting
	'----- as taken for room conditions -- so its pickup spot never re-arms
	IF a$ = "u" AND xus(i) = 1 THEN ob(sel) = 2: CALL HudUse(CINT(sel), ob(), sn$(), fontData())
	'----- pickup sound now plays via the acquisition scan (mainloop) so action-gets sound too
	IF a$ <> "u" THEN GOTO 6400
	CALL Snd3
	6400 CALL drawMsg(ms$(i), font3Data()): txr = 1
	IF tg$(i) = "" THEN GOTO 6740
	IF MID$(tg$(i), 2, 1) = "c" THEN sl$ = "s": tt$ = "y"
	IF LEFT$(tg$(i), 1) <> "w" THEN GOTO 6710

'----- Trigger a walkout in the tagged direction (letter -> digit via GAME2 DirDigit)
	CALL DirDigit(RIGHT$(tg$(i), 1), exd$)
	IF exd$ <> "" THEN
		ohs = i
		a$ = exd$
		wk = 1: GOSUB walkout: wk = 0
		i = ohs
	END IF

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
	'----- "e"+dir exit (arrow-only, stand-point walk): arrive in the next room
	'----- facing the exit's direction, exactly like a real walkout would
	IF LEFT$(tg$(i), 1) = "e" THEN
		CALL DirDigit(RIGHT$(tg$(i), 1), exd$)
		IF exd$ <> "" THEN a$ = exd$
	END IF
	'----- the flag this action just set may trigger a scene animation: play it BEFORE
	'----- leaving (unlock -> the door swings open -> THEN the close-up loads);
	'----- reanim is play-once (plSet-marked) so it won't replay on later visits
	GOSUB reanim
	FOR pz = 1 TO 500
	NEXT
	'----- rope climb out of the pit: the long ClimbSeq IS the transition --
	'----- the leave-room whoosh right before it reads as a stray door sound
	IF q$ <> "room12" OR df$(i) <> "room10" THEN CALL Snd2
	IF df$(i) = "dial" THEN GOSUB dial: RETURN
	IF df$(i) = "end" THEN GOTO endgame
'----- enter a room and draw the player
gotoroom:
	'----- leaving the pit (room12): climb the rope back up IN-room first
	IF q$ = "room12" AND df$(i) = "room10" THEN GOSUB climbup
	oq$ = q$
	'----- revive=1: snapshot the PRE-transition state (the safe room) before
	'----- q$ switches, so a killer death in the next room restores to before
	'----- entering it. The killer scenes flag rvArm when they fire. NEVER
	'----- snapshot the transition INTO a death cutscene -- that would clobber
	'----- the safe snapshot with the kill-room state.
	IF rvon = 1 AND q$ <> "" AND df$(i) <> "death" AND df$(i) <> "dindead" AND df$(i) <> "lightn" THEN CALL SaveGame(11): rvSnap = 1
	q$ = df$(i)
	GOSUB loadroom
	IF q$ = "lightn" OR q$ = "dindead" OR q$ = "death" THEN GOTO death
	dop$ = ""
	IF tt$ = "y" AND sl$ = "z" THEN a$ = lf$: lf$ = "": GOSUB face: tt$ = "n"
	sl$ = "z"
	cl = cl + 30
	'----- a stand-point exit (no walkout tag) arrives with a$ = the verb letter,
	'----- which face would draw as NOTHING -- fall back to the last real facing
	IF LEN(a$) <> 1 OR INSTR("12346789", a$) = 0 THEN
		a$ = lf$
		IF LEN(a$) <> 1 OR INSTR("12346789", a$) = 0 THEN a$ = "2"
	END IF
	IF q$ = "room3" AND ob(50) = 1 AND ob(42) = 0 THEN
		GOSUB dooseq
	'----- the trap only arms when escape is POSSIBLE: a rope source (held/hung
	'----- 14, or the poker 2 for the peg) AND a pulley path (held 62, grate
	'----- open 63, apple key 22, or the knife 18 to cut one) -- else softlock
	ELSEIF q$ = "room9" AND ob(66) = 0 AND ob(68) = 0 AND (ob(14) >= 1 OR ob(2) >= 1) AND (ob(62) >= 1 OR ob(63) = 1 OR ob(22) >= 1 OR ob(18) >= 1) THEN
		GOSUB face
		GOSUB gateseq
	ELSEIF q$ = "room12" AND oq$ = "room10" THEN
		GOSUB climbdn
	ELSEIF q$ = "room10" AND oq$ = "room12" THEN
		GOSUB upgrate
	ELSE
		GOSUB face
	END IF
	RETURN

'----- invhi: ESC inventory -- graphical SCREEN 1 (320x200, 4-color) tile grid.
'      Loads INVTIL1/2.PIC, GETs the 36 45x54 tiles into tilarr, then PUTs the
'      carried items into a 7-col grid with a movable selection ring.
doinv:
	CALL invhi
	GOTO invret

'----- map screen ("m" / auto-open on pickup): GAME4 MapView shows MAP1.PIC once
'----- the map (16) is held, a plain black placeholder before; shares doinv's
'----- return path (reload the room, player stays where he stood via lrq$)
domap:
	IF msen = 1 THEN CALL erasecur
	CALL MapView(CINT(ob(16)), CINT(mrn), CLNG(ob(64)), mvint, msen)
invret:
	GOSUB loadroom
	IF tt$ <> "y" THEN a$ = lf$: lf$ = "": GOSUB face
	'----- mid-fight inventory trip (e.g. grabbing the syringe): redraw the
	'----- killer the room repaint wiped and restart the reaction window
	IF doc = 1 THEN PUT (135, 135), wa, XOR: ti = TIMER
	t0 = TIMER
	RETURN

'----- ESC main menu (GAME4 MainMenu): dims the live screen and draws the menu box
'----- over it; same return contract as the inventory (2 = New Game -> RUN, else
'----- reload the room -- also repaints after a Load or a plain resume)
domenu:
	IF msen = 1 THEN CALL erasecur
	CALL MainMenu(fontData(), mvint, msen, slvAct, 0)
	IF slvAct = 2 THEN RUN
	'----- a manual load invalidates any armed/pending revive snapshot, and
	'----- fades the loaded room in (rvfd holds rmpal black until LoadFade)
	IF slvAct = 1 THEN rvArm = 0: rvSnap = 0: doc = 0: rvfd = 1: PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	GOSUB loadroom
	IF tt$ <> "y" THEN a$ = lf$: lf$ = "": GOSUB face
	IF rvfd = 1 THEN rvfd = 0: CALL LoadFade(co, pa1, pa2, pa3)
	'----- resumed mid-fight: redraw the killer and restart the reaction window
	IF doc = 1 THEN PUT (135, 135), wa, XOR: ti = TIMER
	t0 = TIMER
	RETURN

'----- main game loop: input, movement, actions
mainloop:
	'----- derived flag: 33 (ready to mix) = acid neutralized (32) + complete formula
	'----- (36). Re-derived every pass so it lands no matter which prerequisite came
	'----- last (the combine-only check missed soda-after-formula) and heals old saves
	IF ob(32) = 1 AND ob(36) = 1 THEN ob(33) = 1
	'----- heal: holding/having-taken the saw (20) implies the toolchest was
	'----- opened (58) -- saves from before flag 58 existed show it open
	IF ob(20) >= 1 AND ob(58) < 1 THEN ob(58) = 1
	'----- reveal first, sound second: a get that trips a scene sprite (open drawer)
	'----- draws it BEFORE the acquisition scan plays the pickup sound
	GOSUB reanim
	FOR iaq = 1 TO 36
		IF ob(iord(iaq)) = 1 AND aqo(iord(iaq)) = 0 THEN aqc = aqc + 1: aqo(iord(iaq)) = aqc: nwf(iord(iaq)) = 1: CALL Snd1
	NEXT
	'----- deferred map auto-open: by now the pickup sprite composited (reanim)
	'----- and the get sound played (scan above); re-print the pickup message
	'----- after the map closes so the player still sees it
	IF dmq = 1 THEN dmq = 0: GOSUB domap: CALL drawMsg(dm$, font3Data()): txr = 1
	'----- q$ guard: a death/load between the fire and this dispatch must not
	'----- replay the room9 cutscene over whatever room got restored
	IF goq = 1 THEN goq = 0: IF q$ = "room9" THEN GOSUB gateopen
	IF msen <> 1 THEN PUT (b, a), d, XOR
	pt = (TIMER - t0) + pt
	t0 = TIMER
	IF (INT(cl * cr)) <= 35 THEN GOTO 7100
	'CALL DoorOpen   ' door migrated to data-driven animation (ANIMS.PAC id 1 + room3.pac placement)
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
	IF sfps = 1 THEN CALL FpsTick
	a$ = INKEY$
	GOSUB joy
	GOSUB mousepoll
	GOSUB animtick
	IF lf$ <> sdwlf$ THEN sdwlf$ = lf$: CALL PGrab(lf$, fd(), mfd(), fu(), mfu(), fr(), mfr(), fl(), mfl(), fdl(), mfdl(), fdr(), mfdr(), ful(), mful(), fur(), mfur())
	CALL ShadTick(q$, cl, h9, t1, t2, t3, CINT(ob(43)), pjx, pjy, b, a, sdwDat(), sdwB1$, sdwB2$, fbg())
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
	IF a$ = CHR$(27) THEN GOSUB domenu: GOTO mainloop
	IF a$ <> "i" THEN GOTO 7620
	GOSUB doinv: GOTO mainloop
	7620 IF a$ = "m" THEN GOSUB domap: GOTO mainloop
	7630 IF doc <> 1 THEN GOTO 7660
	GOSUB fight
	GOTO mainloop
	7660 IF a$ = "a" OR a$ = "u" OR a$ = "g" OR a$ = "l" THEN
		IF msen = 1 THEN GOSUB msnap
		GOSUB action
		GOSUB events
		GOSUB trigger
		IF a$ = "l" AND nfon = 1 THEN GOSUB lookmiss
		IF a$ = "u" AND acthit = 0 AND nfon = 1 THEN GOSUB usemiss
		IF msen = 1 THEN GOSUB synchit
	END IF
	GOTO mainloop
	SYSTEM

'----- fps counter: moved to GAME2 (FpsTick) -- GAME.BAS is at the 64K code ceiling

'----- debug readout + hit-zone overlay: moved to GAME2 (MxyTick / HitZones) -- 64K ceiling
mxytick:
	CALL MxyTick(mx, my, b, a, snr, ox(), oy(), oi(), ky$())
	RETURN
hitzones:
	CALL HitZones(hzon$, snr, ox(), oy(), oi(), ky$())
	RETURN

'----- lookmiss/usemiss message text lives in GAME2 (LoadMsgs) -- this module is at
'----- the 64K code-segment ceiling, so the 37 string assignments moved out
loadmsgs:
	CALL LoadMsgs(nf$())
	FOR ivi = 1 TO 29: iord(ivi) = ivi: NEXT
	iord(30) = 30: iord(31) = 49: iord(32) = 35: iord(33) = 36: iord(34) = 34: iord(35) = 52
	'----- slot 36 = the pulley (62, room12). NEVER park a slot on 0 -- ob(0)
	'----- gets set by every st=0 action, which reads as a phantom pickup
	iord(36) = 62
	RETURN

'----- look at a truly-empty spot: after 3 looks at the same cell, show a non-repeating
'----- random line (the counting + picking lives in GAME2 LookMissLine)
lookmiss:
	CALL LookMissLine(CINT(b), CINT(a), ox(), oy(), nf$(), ums$)
	IF ums$ = "" THEN RETURN
	GOSUB clrtxt
	CALL drawMsg(ums$, font3Data()): txr = 1
	RETURN

'----- usemiss: a use that resolved to NOTHING (empty spot, or the wrong item on a
'----- use point) -- answer right away; UseMissLine (GAME2) picks a random line and
'----- answers a key-on-the-wrong-lock with key lines (doesn't fit / won't turn)
usemiss:
	CALL UseMissLine(sel, wantbs, ums$)
	GOSUB clrtxt
	CALL drawMsg(ums$, font3Data()): txr = 1
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
	IF nAnim >= 70 THEN GOTO animend
	INPUT #3, anId(nAnim + 1), anName$(nAnim + 1), anType$(nAnim + 1), anSrc$(nAnim + 1), anFrames$(nAnim + 1), anRate(nAnim + 1), anMode$(nAnim + 1), anPal$(nAnim + 1), anSnd$(nAnim + 1)
	nAnim = nAnim + 1
	GOTO animloop
	animeof:
	RESUME animend
	animend:
	CLOSE #3
	ON ERROR GOTO errhand
	RETURN

'----- shadload: guarded open for the shadow-door data (SHADW2.PAC); GAME2
'----- ShadLoad parses from the open #3. A missing file lands in shadeof and
'----- the feature simply stays off (old QA folders keep working).
shadload:
	ON ERROR GOTO shadeof
	CLOSE #3
	'----- the blitter routines first (BINARY open CREATES a missing file as
	'----- 0 bytes, so length-check instead of relying on an open error)
	OPEN "SHADBOP.OVL" FOR BINARY AS #3
	sdwB1$ = SPACE$(LOF(3))
	GET #3, 1, sdwB1$
	CLOSE #3
	OPEN "SHADBLT.OVL" FOR BINARY AS #3
	sdwB2$ = SPACE$(LOF(3))
	GET #3, 1, sdwB2$
	CLOSE #3
	IF LEN(sdwB1$) < 10 OR LEN(sdwB2$) < 10 THEN GOTO shadend
	OPEN "SHADW2.PAC" FOR INPUT AS #3
	CALL ShadLoad(sdwDat())
	shadend:
	ON ERROR GOTO errhand
	RETURN
	shadeof:
	RESUME shadend

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
	'----- frame count via GAME2 AnimK (validated -- a leading-equal count alone
	'----- overshoots when width*2 = height, e.g. a 3x6 tick-tock frame)
	CALL AnimK(acPct(), acN(), acs, ank%)
	ank = ank%
	anpf = anf \ ank
	IF anpf > 460 THEN anpf = 460
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

'----- animparse/animwait: bodies live in GAME2 (AnimParse/AnimWait) -- 64K ceiling
animparse:
	CALL AnimParse(anFrames$(aidx), fsq(), nft%)
	nfr = nft%
	RETURN

animwait:
	CALL AnimWait(awrate)
	RETURN

'----- animdims: measure SRC$'s frame size -> adw, adh (GAME2 AnimDims; ensures the
'----- .pct is cached first). Capped at 31 so a save-under always fits its slot.
animdims:
	acs = 0
	FOR aci = 1 TO 6
		IF acSrc$(aci) = SRC$ THEN acs = aci
	NEXT
	IF acs = 0 THEN GOSUB animload
	CALL AnimDims(acPct(), acN(), acs, adw, adh)
	RETURN

'----- rmpal: set the current room's palette (body in GAME2 -- 64K ceiling).
'----- While a load fade is pending (rvfd), stay black -- LoadFade lights it up.
rmpal:
	IF rvfd = 1 THEN RETURN
	CALL RmPal(co, pa1, pa2, pa3)
	RETURN

'----- animdraw: composite scene-animation placements onto the room (static / hold / once / loop / random)
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
		IF plCond(pp) > 0 THEN IF ob(plCond(pp)) < 1 THEN GOTO bgnext
		IF plCond(pp) < 0 THEN IF ob(-plCond(pp)) >= 1 THEN GOTO bgnext
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
		'----- move placements bypass the cond gate: cond is their TRIGGER, not their
		'----- visibility -- unplayed they sit at the start spot (the idle clock).
		'----- negative cond = show WHILE the flag is OFF (tick-tock until the slide)
		IF anMode$(aidx) = "move" THEN GOTO adcondok
		IF plCond(pp) > 0 THEN IF ob(plCond(pp)) < 1 THEN GOTO adnext
		IF plCond(pp) < 0 THEN IF ob(-plCond(pp)) >= 1 THEN GOTO adnext
		adcondok:
		GOSUB animparse
		IF nfr < 1 THEN GOTO adnext
		SRC$ = anSrc$(aidx)
		PX = plX(pp)
		PY = plY(pp)
		awrate = anRate(aidx)
		IF anMode$(aidx) = "move" THEN
			adplayed = 0
			IF plSet(pp) > 0 THEN IF ob(plSet(pp)) = 1 THEN adplayed = 1
			'----- trigger already on at room load (older save): the travel
			'----- belongs to the trigger moment -- settle at the end spot
			'----- silently and mark it played so reanim doesn't re-run it
			IF adplayed = 0 AND plCond(pp) > 0 THEN
				IF ob(plCond(pp)) >= 1 THEN
					adplayed = 1
					IF plSet(pp) > 0 THEN ob(plSet(pp)) = 1
				END IF
			END IF
			IF adplayed = 1 THEN
				'----- already travelled: rest at the END spot
				CALL MovParse(anFrames$(aidx), mdx(), mdy(), mvn%, bx1%, by1%, bx2%, by2%)
				FOR adf = 1 TO mvn%
					PX = PX + mdx(adf)
					PY = PY + mdy(adf)
				NEXT
			ELSE
				'----- idle at the START spot; keep the background under the frame so
				'----- the travel (reanim) can lift it without leaving a ghost
				GOSUB animdims
				GET (PX, PY)-(PX + adw - 1, PY + adh - 1), mvSave
				mvSp = pp
			END IF
			afn = 1
			GOSUB animframe
		ELSEIF anMode$(aidx) = "static" THEN
			afn = fsq(nfr) + 1
			GOSUB animframe
			plStat(pp) = 1
		ELSEIF anMode$(aidx) = "fg" THEN
			'----- foreground: composite like a static, then register the decoded
			'----- frame so every player draw re-PUTs it ON TOP of him
			afn = fsq(nfr) + 1
			GOSUB animframe
			plStat(pp) = 1
			GOSUB ovfreg
		ELSEIF anMode$(aidx) = "hold" OR anMode$(aidx) = "once" THEN
			adplayed = 0
			IF plSet(pp) > 0 THEN IF ob(plSet(pp)) = 1 THEN adplayed = 1
			IF adplayed = 1 THEN
				IF anMode$(aidx) = "hold" THEN afn = fsq(nfr) + 1: GOSUB animframe
			ELSE
				IF q$ = "room3" THEN GOTO adnext
				'----- cond on but never played (e.g. an older save): settle on the
				'----- end frame SILENTLY and mark it -- the animated play belongs
				'----- to the triggering action (reanim), never to room entry
				IF anMode$(aidx) = "hold" THEN afn = fsq(nfr) + 1: GOSUB animframe
				IF plSet(pp) > 0 THEN ob(plSet(pp)) = 1
			END IF
		ELSEIF anMode$(aidx) = "seq" THEN
			'----- never plays on a room LOAD (the bg swap already shows the end
			'----- state) -- just mark it played, healing saves made mid-flag
			IF plSet(pp) > 0 THEN ob(plSet(pp)) = 1
		ELSEIF anMode$(aidx) = "loop" OR LEFT$(anMode$(aidx), 6) = "random" THEN
			IF nLoop < 4 THEN
				nLoop = nLoop + 1
				liAnim(nLoop) = aidx
				liX(nLoop) = PX
				liY(nLoop) = PY
				liCur(nLoop) = 1
				liRate(nLoop) = awrate
				liLast(nLoop) = TIMER
				liCond(nLoop) = plCond(pp)
				liMin(nLoop) = 0: liMax(nLoop) = 0
				liWait(nLoop) = awrate * .05
				IF LEFT$(anMode$(aidx), 6) = "random" THEN
					'----- "random min max" (seconds): every frame holds a random min..max s
					'----- (curtain in the breeze); each placement rolls its own waits
					IF nfseed = 0 THEN RANDOMIZE TIMER: nfseed = 1
					ars$ = MID$(anMode$(aidx), 8)
					liMin(nLoop) = VAL(ars$)
					arp = INSTR(ars$, " ")
					IF arp > 0 THEN liMax(nLoop) = VAL(MID$(ars$, arp + 1))
					IF liMax(nLoop) < liMin(nLoop) THEN liMax(nLoop) = liMin(nLoop)
					liWait(nLoop) = liMin(nLoop) + RND * (liMax(nLoop) - liMin(nLoop))
				END IF
				'----- save-under sized to the FRAME, not a blanket 31x31 (which stomped
				'----- sprites near small anims); the tick's restore PUT reads dims from
				'----- the GET header, so it needs no change
				GOSUB animdims
				IF PX + adw > 320 THEN adw = 320 - PX
				IF PY + adh > 200 THEN adh = 200 - PY
				liW(nLoop) = adw: liH(nLoop) = adh
				GET (PX, PY)-(PX + adw - 1, PY + adh - 1), liSaveAll((nLoop - 1) * 210)
				afn = fsq(1) + 1
				GOSUB animframe
				'----- mark registered so reanim's mid-room spawn never doubles it
				plStat(pp) = 1
			END IF
		END IF
		adnext:
	NEXT
	RETURN

'----- ovfreg: register the frame animframe just drew as a foreground overlay --
'----- copies afrm/amfrm (still holding the composited frame) into ovf() with its
'----- spot, so GAME5 OvTop can re-stamp it over the player without any disk read
'----- (body in GAME2 OvReg -- 64K ceiling)
ovfreg:
	ovh = 0
	IF acM(acs) >= anf THEN ovh = 1
	CALL OvReg(ovf(), afrm(), amfrm(), anpf, ovh, ovnext, PX, PY)
	RETURN

'----- animtick: advance active loop/random animations (idle-loop tick, TIMER-delta gated);
'----- loop waits rate*.05 every frame; random holds each frame a random min..max seconds
animtick:
	IF nLoop < 1 THEN RETURN
	FOR li = 1 TO nLoop
		IF TIMER < liLast(li) THEN liLast(li) = TIMER
		IF TIMER >= liLast(li) + liWait(li) THEN
			'----- "while flag OFF" instance whose flag turned ON mid-room: freeze it
			'----- (no restore -- whatever replaced the area, e.g. the slide, stays)
			IF liCond(li) < 0 THEN IF ob(-liCond(li)) >= 1 THEN GOTO atnext
			'----- hold the tick while the player's 31x31 box overlaps this instance --
			'----- no z-order exists, advancing would stamp background over him; the
			'----- anim freezes and resumes as soon as he moves away (skip in nopl views)
			IF nopl = 0 THEN
				IF liX(li) < pjx + 31 AND liX(li) + liW(li) > pjx AND liY(li) < pjy + 31 AND liY(li) + liH(li) > pjy THEN GOTO atnext
			END IF
			'----- cursor parked on/near this anim: hold the tick too -- redrawing
			'----- under the pointer causes a draw-over war (resumes when it moves)
			IF liX(li) < b + 12 AND liX(li) + liW(li) > b - 6 AND liY(li) < a + 12 AND liY(li) + liH(li) > a - 6 THEN GOTO atnext
			liLast(li) = TIMER
			'----- lift the XOR mouse cursor while redrawing under it, else the restore
			'----- eats half the cursor and the next XOR-off leaves garbage pixels
			atcur = 0
			IF msen <> 1 THEN
				IF liX(li) < b + 12 AND liX(li) + liW(li) > b AND liY(li) < a + 12 AND liY(li) + liH(li) > a THEN
					PUT (b, a), d, XOR
					atcur = 1
				END IF
			END IF
			aidx = liAnim(li)
			GOSUB animparse
			IF nfr >= 1 THEN
				PUT (liX(li), liY(li)), liSaveAll((li - 1) * 210), PSET
				liCur(li) = liCur(li) + 1
				IF liCur(li) > nfr THEN liCur(li) = 1
				SRC$ = anSrc$(aidx)
				PX = liX(li)
				PY = liY(li)
				afn = fsq(liCur(li)) + 1
				GOSUB animframe
				IF liMax(li) > 0 THEN
					liWait(li) = liMin(li) + RND * (liMax(li) - liMin(li))
				ELSE
					liWait(li) = liRate(li) * .05
				END IF
			END IF
			IF atcur = 1 THEN PUT (b, a), d, XOR
		END IF
		atnext:
	NEXT
	RETURN

'----- reanim: mainloop check -- play any placement that just became active+unplayed (hold/once); data-driven DoorOpen
'----- overlay guard for MID-ROOM anim plays (reanim): the standing player's
'----- fbg and the cursor's save-under were sampled BEFORE the overlay draws,
'----- so restoring them later would stamp stale (closed-drawer) pixels over
'----- the new art. Erase both first (ovpre), play, then re-anchor fbg from
'----- the updated screen and redraw the player (ovpost).
'----- ovprep: decide the player handling for a play over rect ovx1..ovx2/ovy1..ovy2.
'----- Overlapping (ovl%=1): lift him now, re-draw per frame (the old behaviour).
'----- Clear of it (ovl%=0): leave him alone -- NO per-frame redraw (no flicker) --
'----- and turn him to WATCH the animation (lookdir toward its centre).
ovprep:
	CALL OvPlayer(ovx1, ovy1, ovx2, ovy2, pjx, pjy, nopl, ovl%)
	CALL erasecur
	IF nopl = 1 THEN RETURN
	IF ovl% = 1 THEN GOTO ovlift
	obb = b: oaa = a
	b = (ovx1 + ovx2) \ 2: a = (ovy1 + ovy2) \ 2
	GOSUB lookdir
	GOSUB face
	b = obb: a = oaa
	RETURN

'----- ovlift/ovpost route through face (the single PStand call site -- each
'----- 22-param CALL costs ~170 bytes and GAME.BAS is at the 64K code ceiling);
'----- a$/lf$ are saved around the trip since face assigns lf$ = a$
ovpre:
	CALL erasecur
'----- ovlift: erase-only (no cursor teardown) -- used between frames of a play so
'----- the player can be re-drawn over every frame instead of vanishing for the swing
ovlift:
	ov2$ = a$: ov3$ = lf$
	a$ = "": GOSUB face
	a$ = ov2$: lf$ = ov3$
	RETURN
ovpost:
	GET (pjx, pjy)-(pjx + 30, pjy + 30), fbg
	IF lf$ = "" THEN lf$ = "2"
	ov2$ = a$
	a$ = lf$: GOSUB face
	a$ = ov2$
	RETURN

reanim:
	IF nPlace < 1 THEN RETURN
	FOR pp = 1 TO nPlace
		aidx = 0
		FOR aa = 1 TO nAnim
			IF anId(aa) = plAnim(pp) THEN aidx = aa
		NEXT
		IF aidx = 0 THEN GOTO ranext
		IF anType$(aidx) = "bg" THEN GOTO ranext
		'----- flag-gated STATIC sprite whose flag just tripped: composite it now,
		'----- once (plStat) -- no need to leave and re-enter the room to see it
		IF anMode$(aidx) <> "static" THEN GOTO ranotstat
		IF plCond(pp) <= 0 THEN GOTO ranext
		IF ob(plCond(pp)) < 1 THEN GOTO ranext
		IF plStat(pp) = 1 THEN GOTO ranext
		GOSUB animparse
		IF nfr < 1 THEN GOTO ranext
		SRC$ = anSrc$(aidx)
		PX = plX(pp)
		PY = plY(pp)
		GOSUB ovpre
		afn = fsq(nfr) + 1
		GOSUB animframe
		plStat(pp) = 1
		GOSUB ovpost
		GOTO ranext
		ranotstat:
		'----- "seq" full-screen cutscene (GAME5 PicSeq): plays ONCE when its cond
		'----- flag trips mid-room; the end-facing digit rides in the pal field
		IF anMode$(aidx) <> "seq" THEN GOTO ranotseq
		IF plCond(pp) <= 0 THEN GOTO ranext
		IF ob(plCond(pp)) < 1 THEN GOTO ranext
		IF plSet(pp) < 1 THEN GOTO ranext
		IF ob(plSet(pp)) = 1 THEN GOTO ranext
		GOSUB ovpre
		CALL PicSeq(anSrc$(aidx), anFrames$(aidx), anRate(aidx), anSnd$(aidx))
		CALL HudUse(CINT(sel), ob(), sn$(), fontData())
		IF anPal$(aidx) <> "" THEN lf$ = anPal$(aidx)
		GOSUB ovpost
		ob(plSet(pp)) = 1
		GOTO ranext
		ranotseq:
		'----- loop/random placement whose cond flag tripped MID-ROOM (the exit fires
		'----- the moment the curtain seq ends): register the instance now -- animdraw
		'----- only does it on room load. plStat doubles as the "registered" marker
		'----- (animdraw sets it for load-time instances so this never double-spawns).
		IF anMode$(aidx) <> "loop" AND LEFT$(anMode$(aidx), 6) <> "random" THEN GOTO ranotloop
		IF plCond(pp) <= 0 THEN GOTO ranext
		IF ob(plCond(pp)) < 1 THEN GOTO ranext
		IF plStat(pp) = 1 THEN GOTO ranext
		IF nLoop >= 4 THEN GOTO ranext
		GOSUB animparse
		IF nfr < 1 THEN GOTO ranext
		SRC$ = anSrc$(aidx)
		PX = plX(pp)
		PY = plY(pp)
		awrate = anRate(aidx)
		'----- lift the player before the save-under GET so it never captures him
		GOSUB ovpre
		nLoop = nLoop + 1
		liAnim(nLoop) = aidx
		liX(nLoop) = PX
		liY(nLoop) = PY
		liCur(nLoop) = 1
		liRate(nLoop) = awrate
		liLast(nLoop) = TIMER
		liCond(nLoop) = plCond(pp)
		liMin(nLoop) = 0: liMax(nLoop) = 0
		liWait(nLoop) = awrate * .05
		IF LEFT$(anMode$(aidx), 6) = "random" THEN
			IF nfseed = 0 THEN RANDOMIZE TIMER: nfseed = 1
			ars$ = MID$(anMode$(aidx), 8)
			liMin(nLoop) = VAL(ars$)
			arp = INSTR(ars$, " ")
			IF arp > 0 THEN liMax(nLoop) = VAL(MID$(ars$, arp + 1))
			IF liMax(nLoop) < liMin(nLoop) THEN liMax(nLoop) = liMin(nLoop)
			liWait(nLoop) = liMin(nLoop) + RND * (liMax(nLoop) - liMin(nLoop))
		END IF
		GOSUB animdims
		IF PX + adw > 320 THEN adw = 320 - PX
		IF PY + adh > 200 THEN adh = 200 - PY
		liW(nLoop) = adw: liH(nLoop) = adh
		GET (PX, PY)-(PX + adw - 1, PY + adh - 1), liSaveAll((nLoop - 1) * 210)
		afn = fsq(1) + 1
		GOSUB animframe
		GOSUB ovpost
		plStat(pp) = 1
		GOTO ranext
		ranotloop:
		'----- move-mode: the sprite itself travels -- play its 1px step script once
		'----- (save-under follows it, the player stays drawn), settle at the end
		IF anMode$(aidx) <> "move" THEN GOTO ranotmove
		IF plCond(pp) <= 0 THEN GOTO ranext
		IF ob(plCond(pp)) < 1 THEN GOTO ranext
		IF plSet(pp) < 1 THEN GOTO ranext
		IF ob(plSet(pp)) = 1 THEN GOTO ranext
		CALL MovParse(anFrames$(aidx), mdx(), mdy(), mvn%, bx1%, by1%, bx2%, by2%)
		IF mvn% < 1 THEN GOTO ranext
		SRC$ = anSrc$(aidx)
		mvx = plX(pp)
		mvy = plY(pp)
		awrate = anRate(aidx)
		GOSUB animdims
		ovx1 = mvx + bx1%: ovy1 = mvy + by1%
		ovx2 = mvx + bx2% + adw - 1: ovy2 = mvy + by2% + adh - 1
		GOSUB ovprep
		'----- lift the idle frame animdraw showed at the start spot: put the clean
		'----- background back so the travel's save-unders never capture the sprite
		IF mvSp = pp THEN
			PUT (mvx, mvy), mvSave, PSET
			mvSp = 0
		END IF
		FOR adf = 1 TO mvn%
			GET (mvx, mvy)-(mvx + adw - 1, mvy + adh - 1), wbg
			PX = mvx: PY = mvy: afn = 1
			GOSUB animframe
			IF ovl% = 1 THEN GOSUB ovpost
			GOSUB animwait
			IF ovl% = 1 THEN GOSUB ovlift
			PUT (mvx, mvy), wbg, PSET
			mvx = mvx + mdx(adf)
			mvy = mvy + mdy(adf)
		NEXT
		PX = mvx: PY = mvy: afn = 1
		GOSUB animframe
		IF ovl% = 1 THEN GOSUB ovpost
		IF anSnd$(aidx) <> "" THEN PLAY anSnd$(aidx)
		ob(plSet(pp)) = 1
		GOTO ranext
		ranotmove:
		IF anMode$(aidx) <> "hold" AND anMode$(aidx) <> "once" THEN GOTO ranext
		IF plCond(pp) <= 0 THEN GOTO ranext
		IF ob(plCond(pp)) < 1 THEN GOTO ranext
		IF plSet(pp) < 1 THEN GOTO ranext
		IF ob(plSet(pp)) = 1 THEN GOTO ranext
		GOSUB animparse
		IF nfr < 1 THEN GOTO ranext
		SRC$ = anSrc$(aidx)
		PX = plX(pp)
		PY = plY(pp)
		awrate = anRate(aidx)
		GOSUB animdims
		ovx1 = PX: ovy1 = PY: ovx2 = PX + adw - 1: ovy2 = PY + adh - 1
		GOSUB ovprep
		'----- save-under sized to the FRAME (animdims ran above) -- big hold/once
		'----- frames (up to 416 bytes, e.g. 33x45) restore cleanly too
		GET (PX, PY)-(PX + adw - 1, PY + adh - 1), wbg
		'----- overlapping player stays VISIBLE through the play: re-drawn over each
		'----- frame (ovpost re-anchors fbg), lifted again before the next. A clear
		'----- player is left entirely alone (no flicker) -- he just turned to watch
		FOR adf = 1 TO nfr
			IF adf > 1 AND ovl% = 1 THEN GOSUB ovlift
			afn = fsq(adf) + 1
			GOSUB animframe
			IF ovl% = 1 THEN GOSUB ovpost
			GOSUB animwait
		NEXT
		IF anSnd$(aidx) <> "" THEN PLAY anSnd$(aidx)
		IF anMode$(aidx) = "once" THEN
			IF ovl% = 1 THEN GOSUB ovlift
			PUT (PX, PY), wbg, PSET
			IF ovl% = 1 THEN GOSUB ovpost
		END IF
		ob(plSet(pp)) = 1
		ranext:
	NEXT
	RETURN

'----- dooseq: room3 door entry cutscene -- walk player in from the door while it opens, face up-right
dooseq:
	CLOSE
	'----- walk in from the door using the startup-cached right-facing set (slot 2 = offset 302)
	FOR i = 90 TO 140 STEP 3
		CALL PStep(i, 130, 0, f3, 1, 302, cwa(), cmwa(), cwb(), cmwb(), wbg(), ovf())
		i = i + 3
		CALL PStep(i, 130, 1, f3, 1, 302, cwa(), cmwa(), cwb(), cmwb(), wbg(), ovf())
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

'----- room12 rope travel (GAME5 ClimbSeq does the sprite work).
'----- climbdn: entry from room10 -- the rope (14) leaves the inventory while
'----- it is tied off below (state 2); aqo resets so re-taking it beeps again.
climbdn:
	'----- no descend cutscene (normal entries do not show a walk-in either):
	'----- just appear at the rope base; the ASCEND (climbup) still animates
	ob(14) = 2: aqo(14) = 0
	pjx = 136: pjy = 132
	GET (pjx, pjy)-(pjx + 30, pjy + 30), fbg
	a$ = "2": GOSUB face
	RETURN
'----- climbup: fired in gotoroom BEFORE the room switch -- erase the standing
'----- player (via face, a$/lf$ preserved), then the sprite climbs up and away
climbup:
	ov2$ = a$: ov3$ = lf$
	a$ = "": GOSUB face
	a$ = ov2$: lf$ = ov3$
	CALL ClimbSeq(1, 138, 92, 132, f3, wa(), mwa(), wb(), mwb(), wbg(), ovf())
	RETURN
'----- upgrate: arrival in room10 from below -- stand at the grate; the walkout
'----- already set ob(14)=1, so the acquisition scan plays the pickup sound here
upgrate:
	pjx = 203: pjy = 140
	GET (pjx, pjy)-(pjx + 30, pjy + 30), fbg
	a$ = "1": GOSUB face
	CALL drawMsg("You gather up your rope on the way out.", font3Data()): txr = 1
	RETURN

'----- room9 trap: the gate slams and the lever drops on the first entry
'----- (gotoroom). 66 = trapped (all the state statics + exit lock key on it)
'----- gplook: coords of anim id gpi's placement in this room -> gpx,gpy
'----- (leaves the caller's preset fallback when no placement exists)
gplook:
	FOR gpp = 1 TO nPlace
		IF plAnim(gpp) = gpi THEN gpx = plX(gpp): gpy = plY(gpp)
	NEXT
	RETURN

gateseq:
	dwsec = .7: GOSUB dwait
	gpx = 215: gpy = 151: gpi = 47: GOSUB gplook
	SRC$ = "NOARROW": afn = 1: PX = gpx: PY = gpy: GOSUB animframe
	gpx = 221: gpy = 126: gpi = 48: GOSUB gplook: gtx = gpx: gty = gpy
	gpx = 210: gpy = 127: gpi = 49: GOSUB gplook: lvx = gpx: lvy = gpy
	SRC$ = "R9GATE"
	FOR gsf = 1 TO 5
		afn = gsf: PX = gtx: PY = gty: GOSUB animframe
		SOUND 90, .6: SOUND 32676, 1.2
		'----- first clunk: the player spins round to face the falling gate
		'----- (entry spawn 140,130 never overlaps the gate/lever/arrow rects)
		IF gsf = 1 THEN a$ = "6": GOSUB face
	NEXT
	SOUND 50, 2
	dwsec = .35: GOSUB dwait
	SRC$ = "R9LEVER"
	FOR gsf = 1 TO 3
		afn = gsf: PX = lvx: PY = lvy: GOSUB animframe
		SOUND 130, .3: SOUND 32676, 1
	NEXT
	ob(66) = 1
	CALL drawMsg("The gate slams down behind you! The lever drops with a heavy clunk.", font3Data()): txr = 1
	RETURN

'----- room9 escape (use rope on the pulley, st=68 -> deferred here): rope
'----- overlay, pull, lever up, gate reverse, arch restore, rope removal.
'----- 66 clears (trap statics + exit lock off), 68 = solved forever.
gateopen:
	GOSUB ovpre
	'----- coords come from the (never-shown, cond 99) editor placements
	gpx = 197: gpy = 98: gpi = 51: GOSUB gplook: gp1x = gpx: gp1y = gpy
	gpx = 197: gpy = 98: gpi = 52: GOSUB gplook: gp2x = gpx: gp2y = gpy
	gpx = 201: gpy = 98: gpi = 53: GOSUB gplook: gp3x = gpx: gp3y = gpy
	gpx = 221: gpy = 126: gpi = 48: GOSUB gplook: gtx = gpx: gty = gpy
	gpx = 210: gpy = 124: gpi = 50: GOSUB gplook: lux = gpx: luy = gpy
	gx1 = gp1x: IF gp2x < gx1 THEN gx1 = gp2x
	IF gp3x < gx1 THEN gx1 = gp3x
	gy1 = gp1y: IF gp2y < gy1 THEN gy1 = gp2y
	IF gp3y < gy1 THEN gy1 = gp3y
	gx2 = gp1x + 22: IF gp2x + 22 > gx2 THEN gx2 = gp2x + 22
	IF gp3x + 13 > gx2 THEN gx2 = gp3x + 13
	gy2 = gp1y + 48: IF gp2y + 48 > gy2 THEN gy2 = gp2y + 48
	IF gp3y + 49 > gy2 THEN gy2 = gp3y + 49
	IF gx2 > 319 THEN gx2 = 319
	IF gy2 > 199 THEN gy2 = 199
	GET (gx1, gy1)-(gx2, gy2), gsv
	SRC$ = "R9RPADD": afn = 1: PX = gp3x: PY = gp3y: GOSUB animframe
	'----- the hung rope drops in behind the player: show him in front for the
	'----- beat (ovpost snapshots the rope into fbg, ovlift erases him again)
	GOSUB ovpost
	dwsec = .6: GOSUB dwait
	GOSUB ovlift
	SRC$ = "R9PULL"
	FOR gsf = 1 TO 3
		afn = gsf: PX = gp1x: PY = gp1y: GOSUB animframe
		SOUND 100, .3: SOUND 32676, 1.4
	NEXT
	'----- the lever grind is AUDIO ONLY here: the rope is attached to the
	'----- lever, so its motion is baked into the pull frames -- a separate
	'----- lever anim drew over the held pull pose (user 2026-08-01)
	FOR gsf = 1 TO 3
		SOUND 140, .3: SOUND 32676, 1
	NEXT
	SRC$ = "R9GATE"
	FOR gsf = 5 TO 1 STEP -1
		afn = gsf: PX = gtx: PY = gty: GOSUB animframe
		SOUND 90, .5: SOUND 32676, 1.2
	NEXT
	SRC$ = "R9OPNBG": afn = 1: PX = 215: PY = 126: GOSUB animframe
	dwsec = .3: GOSUB dwait
	SRC$ = "R9RMROP"
	FOR gsf = 1 TO 3
		afn = gsf: PX = gp2x: PY = gp2y: GOSUB animframe
		'----- remove frame 3's art lacks the lever arm -- keep the raised
		'----- lever painted through the whole coil-up (no-op on frames 1-2)
		SRC$ = "R9LEVUP": afn = 1: PX = lux: PY = luy: GOSUB animframe
		SRC$ = "R9RMROP"
		dwsec = .22: GOSUB dwait
	NEXT
	PUT (gx1, gy1), gsv, PSET
	'----- the restore re-painted the trapped-state capture (lever down) --
	'----- stamp the raised lever back before the player returns
	SRC$ = "R9LEVUP": afn = 1: PX = lux: PY = luy: GOSUB animframe
	ob(66) = 0: ob(68) = 1
	GOSUB ovpost
	'----- the pickup chime tells the player the rope is theirs again
	CALL Snd1
	CALL drawMsg("The lever grinds up and the gate rises! You coil the |rope| back into your pack.", font3Data()): txr = 1
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
		'----- trailing "x" on tg = using this object CONSUMES the item (clockhand,
		'----- rock); stripped here so the walkout/face tag parsing never sees it
		xus(i) = 0
		IF RIGHT$(tg$(i), 1) = "x" THEN xus(i) = 1: tg$(i) = LEFT$(tg$(i), LEN(tg$(i)) - 1)
	NEXT
	objok:
	ON ERROR GOTO errhand
	nPlace = 0
	wbmin = 40: wbmax = 250
	wbymin = 138: wbymax = 176
	FOR i = 1 TO 25: spx(i) = -1: spd(i) = 0: NEXT
	FOR i = 1 TO 20: plStat(i) = 0: NEXT
	mvSp = 0
	ovf(0) = 0: ovnext = 17
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
	'----- rooms with overlays load behind a black palette so the base .pic (e.g. the
	'----- closed door) never flashes before animdraw composites the state frames on it;
	'----- rmpal (below / inside animdraw before any full play) then lights the room up
	IF nPlace > 0 THEN
		COLOR 0
		PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	ELSE
		GOSUB rmpal
	END IF
	DEF SEG = -18432
	BLOAD q$ + ".pic", 0
	KEY OFF
	DEF SEG
	GOSUB animdraw
	CALL ShadRoom(q$)
	GOSUB rmpal
	GET (1, 8)-(9, 18), bk: GET (1, 8)-(9, 18), bk2
	'----- bottom Use-item HUD, drawn BEFORE the player save-under GET so
	'----- sprite restores keep it intact
	IF q$ <> "title" AND q$ <> "death" AND q$ <> "dindead" AND q$ <> "lightn" THEN CALL HudUse(CINT(sel), ob(), sn$(), fontData())
	'----- map screen: remember the room number + mark it visited (ob(64) bitmask)
	IF LEFT$(q$, 4) = "room" THEN mrn = VAL(MID$(q$, 5)): IF mrn >= 1 AND mrn <= 12 THEN ob(64) = CLNG(ob(64)) OR CLNG(2 ^ (mrn - 1))
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
	CALL walkTo(wtx, wty, pjx, pjy, f3, cwa(), cmwa(), cwb(), cmwb(), wbg(), ovf())
	RETURN
face:
	'----- tear down the mouse cursor first: its save-under was sampled before this turn, so restoring it later would repaint the OLD player (erasecur no-ops when the cursor isn't drawn). Next mousepoll re-samples after the turn.
	CALL erasecur
	'----- erase + redraw the standing player at (pjx,pjy) -- GAME5 PStand
	'----- (erase restores fbg; nopl close-up rooms erase but skip the draw)
	CALL PStand(a$, pjx, pjy, nopl, fbg(), fd(), mfd(), fu(), mfu(), fr(), mfr(), fl(), mfl(), fdl(), mfdl(), fdr(), mfdr(), ful(), mful(), fur(), mfur(), ovf())
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
	CALL walkTo(wsx, wsy, pjx, pjy, f3, cwa(), cmwa(), cwb(), cmwb(), wbg(), ovf())
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
	'----- body in GAME2 LookDir -- 64K ceiling
	CALL LookDir(b, a, pjx, pjy, a$)
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
	'----- revive=1: the pre-room snapshot becomes the revive point (doc guard:
	'----- the fight loop re-enters these scenes -- only arm on first appearance)
	IF rvon = 1 AND doc = 0 AND rvSnap = 1 THEN rvArm = 1
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

	'----- close the msk (same #1 leak as golf's)
	9960 CLOSE
	PUT (110, 128), mwa, AND: PUT (110, 128), wa, OR

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
	'----- revive=1: the pre-room snapshot becomes the revive point (see wilb)
	IF rvon = 1 AND doc = 0 AND rvSnap = 1 THEN rvArm = 1
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
	'----- close the msk! it used to leak #1 open, which blew up any OPEN #1
	'----- before the next room load (e.g. the revive snapshot right after)
	10200 CLOSE
	i = 150

	10210 CALL PStep(135, i, 0, f3, 1.2, 0, wa(), mwa(), wb(), mwb(), wbg(), ovf())
	i = i - 2
	CALL PStep(135, i, 1, f3, 1.2, 0, wa(), mwa(), wb(), mwb(), wbg(), ovf())
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
	'----- the lit-curtain endgame OWNS room4: the scripted encounter (trigger),
	'----- never a roamer, must meet the player there or the ending breaks
	IF q$ = "room4" AND ob(43) = 1 THEN GOTO 11570
	IF doc <> 1 THEN GOTO 10840
	10840 IF klon = 0 THEN GOTO 11570
	'----- which roamer owns this room at this step count: table in GAME2
	'----- KillChk (64K ceiling); bit 1 = wilb, bit 2 = golf, order preserved
	CALL KillChk(q$, INT(cl * cr), h9, t1, t2, t3, f3, kw%)
	IF (kw% AND 1) = 1 THEN GOSUB wilb
	IF (kw% AND 2) = 2 THEN GOSUB golf
	11570 IF (INT(cl * cr)) <= 30 THEN GOTO 11580
	ob(37) = 1
	11580 RETURN

'----- joystick poll: body in GAME2 (JoyPoll) -- GAME.BAS is at the 64K ceiling
joy:
	CALL JoyPoll(a$, vk$)
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
	'----- cursor pixel grids + builder: moved to GAME2 CursorPats (64K ceiling)
	CALL CursorPats(px(), py(), pc(), npix())
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
'----- reads tg$ direction (wn=up ws=down we=right ww=left); "e"+dir = arrow WITHOUT the
'----- edge walkout (stand-point exits, e.g. the room8 concealed door); else NW arrow
hovexit:
	IF exsen <> 1 THEN RETURN
	newshp = 0
	hvdir$ = ""
	hvb = hovr * hovr + 1
	FOR hvi = 1 TO 257
		IF oy(hvi) = 0# THEN EXIT FOR
		hvo = CINT(oi(hvi))
		IF (LEFT$(tg$(hvo), 1) = "w" OR LEFT$(tg$(hvo), 1) = "e") AND (bs(hvo) = 0 OR ob(bs(hvo)) = 1) AND (cs(hvo) = 0 OR ob(cs(hvo)) = 0) THEN
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
	14250 CALL Credits(CINT(ob(43)))

'----- endgame: roll credits, then quit or restart
endgame:
	IF ob(43) <> 1 THEN GOTO 14290
	CALL Credits(CINT(ob(43))): SYSTEM
	GOTO 14300
	14290 CALL Credits(CINT(ob(43))): RUN
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
	rvArm = 0
	LOCATE 1, 1
	PRINT "You quickly inject him and he crumbles into a distorted heap. "
	a$ = "n"
	PUT (135, 135), wa, XOR
	14570 RETURN

'----- death: play death music, wait for key, then continue
death:
	ti = TIMER
	CALL DeathMusic
	'----- the press that skipped the dirge also ends the death screen --
	'----- otherwise it looks like the game stalled until a second press
	IF mt = -1 THEN GOTO 14660
	14600 IF (TIMER - ti) <= tmo THEN GOTO 14620
	GOTO 14630
	14620 GOTO 14600
	'----- key OR mouse click ends the death screen
	14630 a$ = INKEY$
	IF a$ <> "" THEN GOTO 14660
	IF msen = 1 THEN
		mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout)
		IF (mout.bx AND 1) <> 0 THEN GOTO 14660
	END IF
	GOTO 14630

	14660 IF q$ <> "dindead" THEN GOTO 14700
	q$ = "death"
	GOSUB loadroom
	GOTO 14600

	'----- revive=1 with an armed snapshot (saverk): skip the Load screen --
	'----- restore the snapshot, show the revive message, drop back into play
	14700 IF rvon <> 1 OR rvArm <> 1 THEN GOTO 14710
	rvArm = 0: doc = 0
	CALL LoadGame(11)
	'----- the snapshot restores the clock too: the killer STILL holds the room
	'----- that got you (killers block and redirect -- dying buys no passage);
	'----- the revive only spares the lost progress
	rvfd = 1: PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	GOSUB loadroom
	IF tt$ <> "y" THEN a$ = lf$: lf$ = "": GOSUB face
	rvfd = 0
	CALL LoadFade(co, pa1, pa2, pa3)
	CALL ReviveShow(mvint, msen)
	GOSUB rmpal
	t0 = TIMER
	GOTO 14570

	'----- death: the LOAD screen first; Back opens the main menu (Save locked,
	'----- no resume) so New Game / Quit stay reachable
	14710 CALL SlotScreen(fontData(), mvint, msen, 2, 1, slvAct)
	IF slvAct <> 1 THEN CALL MainMenu(fontData(), mvint, msen, slvAct, 1)
	IF slvAct = 2 THEN RUN
	IF slvAct <> 1 THEN GOTO 14710
	rvArm = 0: rvSnap = 0: doc = 0
	rvfd = 1: PALETTE 1, 0: PALETTE 2, 0: PALETTE 3, 0
	GOSUB loadroom
	IF tt$ <> "y" THEN a$ = lf$: lf$ = "": GOSUB face
	rvfd = 0
	CALL LoadFade(co, pa1, pa2, pa3)
	t0 = TIMER
	GOTO 14570

'----- burn: flickering fire animation until a key is pressed
burn:
	'----- house-fire flicker + restart: body in GAME4 BurnShow (64K ceiling)
	CALL BurnShow
	RUN
	GOTO 16750
	16750 GOTO 18680
	18680 END

REM $STATIC

'----- Credits / ending sequence: moved to GAME3 (64K ceiling); gd% = ob(43)
'----- (1 = the house-burns good ending, else the bad "uncle not saved" screen)

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
	'----- the pulley (62, room12) = tile 38 (INVTIL2/INVMSK2 slot 17)
	tix(62) = 38
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
	FOR ivk = 21 TO 38
		'----- slot 15 (ivk 36) is the ring AND-mask tile, no keep-mask
		IF ivk <> 36 THEN ivj = ivk - 21: ivc = ivj MOD 7: ivr = ivj \ 7: GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 39), kmarr(ivk * ist)
	NEXT
	DEF SEG = -18432
	BLOAD "INVTIL2.PIC", 0
	DEF SEG
	FOR ivk = 21 TO 38
		ivj = ivk - 21: ivc = ivj MOD 7: ivr = ivj \ 7
		GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 53), tilarr(ivk * tst)
		IF ivk <> 36 THEN PUT (ivc * 45, ivr * 54), kmarr(ivk * ist), AND: GET (ivc * 45, ivr * 54)-(ivc * 45 + 44, ivr * 54 + 39), iconarr(ivk * ist)
	NEXT
	'----- derive AND-screen masks in place: kmarr = NOT keepmask (PRESET draws NOT), for the drag sprite (36 = ring mask, skip)
	FOR ivk = 0 TO 38
		IF ivk <> 36 THEN PUT (0, 0), kmarr(ivk * ist), PRESET: GET (0, 0)-(44, 39), kmarr(ivk * ist)
	NEXT
	'----- build the carried-item list (newest-first)
	GOSUB cibuild
	'----- load the single background; GET both panels, erase the Info template
	DEF SEG = -18432
	BLOAD "INVMAIN.PIC", 0
	DEF SEG
	'----- save/load + quit moved to the ESC menu -- blank both old buttons
	'----- (quit still works via the q key)
	LINE (186, 162)-(266, 185), 0, BF
	LINE (8, 162)-(100, 185), 0, BF
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
	nvz = 0: nvb = 0
	ivmax = (cic + 3) \ 4 - 2: IF ivmax < 0 THEN ivmax = 0
	'----- reselect the item picked last time (GAME2 InvReSel; the grid can shift)
	CALL InvReSel(cilist(), cic, lvsel, isel, ivscr, ivmax)
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
	'----- mouseless navigation (arrows / joystick, Enter or Space = activate):
	'----- the zone state machine + cursor parking live in GAME2 InvNav
	nvk$ = ""
	IF ivk$ = CHR$(0) + CHR$(72) THEN nvk$ = "U"
	IF ivk$ = CHR$(0) + CHR$(80) THEN nvk$ = "D"
	IF ivk$ = CHR$(0) + CHR$(75) THEN nvk$ = "L"
	IF ivk$ = CHR$(0) + CHR$(77) THEN nvk$ = "R"
	IF ivk$ = CHR$(13) OR ivk$ = " " THEN nvk$ = "E"
	IF nvk$ = "" AND jsen = 1 THEN CALL JoyNav(nvk$)
	IF nvk$ <> "" THEN
		CALL InvNav(nvk$, nvz, nvb, isel, cic, invtab, ivscr, ivmax, nvx%, nvy%, act%)
		IF act% = 6 THEN GOTO invdone
		IF act% = 7 THEN IF invtab = 1 AND crec > 0 THEN GOSUB combdo
		IF act% = 8 THEN IF exf = 1 THEN GOSUB doexam
		IF act% = 1 OR act% = 2 THEN GOSUB invredraw
		IF msen = 1 THEN
			'----- park the arrow on the focused element AND warp the hardware mouse
			'----- there (INT 33h fn 4) -- else the next poll sees the physical mouse
			'----- position differ from mx/my and instantly snaps the cursor back
			CALL erasecur
			mx = nvx%: my = nvy%
			mreg.ax = 4: mreg.cx = mx * 2: mreg.dx = my
			CALL INTERRUPT(mvint, mreg, mout)
			CALL drawcur
		END IF
	END IF
	GOTO invwait
	invdone:
	lvsel = 0
	IF cic > 0 THEN lvsel = cilist(isel)
	IF msen = 1 THEN CALL erasecur
	FOR ivi = 1 TO 36: nwf(iord(ivi)) = 0: NEXT
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
	'----- dialogs use the standard UI palette layout (1=dkgray 2=ltgray 3=brown);
	'----- the inventory behind recolours while the modal is up, restored on No
	PALETTE 1, 8: PALETTE 2, 7: PALETTE 3, 6
	CALL DrawYNBox("Quit the game?", 1, fontData())
	CALL QuitConfirm
	DEF SEG = -18432: BLOAD "INVMAIN.PIC", 0: DEF SEG
	LINE (186, 162)-(266, 185), 0, BF
	LINE (8, 162)-(100, 185), 0, BF
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
	FOR ivi = 1 TO 36
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

	'----- combine: recipe matching + application live in GAME2 (CombChk / CombDo2)
	combchk:
	crec = 0
	IF cic > 0 AND cbot > 0 THEN
		sel = cilist(isel)
		CALL CombChk(CINT(sel), CINT(cbot), crr%)
		crec = crr%
	END IF
	IF crec > 0 THEN PUT (29, 129), combtn, PSET
	RETURN

	'----- combine: apply the matched recipe, then refresh
	combdo:
	CALL CombDo2(CINT(crec), ob(), cnw%)
	cnew% = cnw%
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
	'----- the map page opens the full map interface; closing returns HERE
	IF sel = 16 THEN
		CALL MapView(1, CINT(mrn), CLNG(ob(64)), mvint, msen)
		DEF SEG = -18432
		GOTO exret
	END IF
	bk$ = "BOOK": PALETTE 1, 7: PALETTE 2, 2: PALETTE 3, 15
	DEF SEG = -18432: BLOAD bk$ + ".PIC", 0
	GOSUB exdrain
	CALL showBook(sel, font3Data())
	exwt:
	ek$ = INKEY$: IF ek$ <> "" THEN GOTO exret
	IF msen = 1 THEN mreg.ax = 3: CALL INTERRUPT(mvint, mreg, mout): IF (mout.bx AND 1) <> 0 THEN GOTO exret
	GOTO exwt
	exret:
	GOSUB exdrain
	BLOAD "INVMAIN.PIC", 0: DEF SEG
	PALETTE 1, 6: PALETTE 2, 7: PALETTE 3, 8
	LINE (8, 27)-(202, 151), 0, BF: LINE (210, 34)-(297, 73), 0, BF
	'----- re-blank the retired quit/save buttons the reload brought back
	LINE (186, 162)-(266, 185), 0, BF: LINE (8, 162)-(100, 185), 0, BF
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

END SUB

'----- QuitConfirm: wait for Yes/No on the quit modal -- the interactive loop
'----- lives in GAME4 (YNWait) to stay under GAME.BAS's 64K code ceiling
SUB QuitConfirm
	CALL YNWait(mvint, msen, 1, qcr%)
	IF qcr% = 1 THEN SYSTEM
END SUB

'----- write the live game state to slot 1-10 (saver a-j.pac). Lives in GAME.BAS for DIM SHARED access; called from the GAME4 save/load screen.
SUB SaveGame (slot AS INTEGER)
	DIM slz AS INTEGER
	OPEN "saver" + CHR$(slot + 96) + ".pac" FOR OUTPUT AS #1
	WRITE #1, q$, cl, pt, done$, tt$, a$, lf$
	FOR slz = 1 TO 80
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
	'----- old saves hold 65 flags; the extension reads what exists (EOF guard)
	FOR slz = 66 TO 80: ob(slz) = 0: NEXT
	FOR slz = 1 TO 80
		IF EOF(1) THEN EXIT FOR
		INPUT #1, ob(slz)
	NEXT
	CLOSE #1
	aqc = 0
	FOR slz = 1 TO 36
		IF ob(iord(slz)) = 1 THEN aqc = aqc + 1: aqo(iord(slz)) = aqc ELSE aqo(iord(slz)) = 0
		nwf(iord(slz)) = 0
	NEXT
	ERASE er1
	FOR slz = 1 TO 40
		gp(slz) = 0#
	NEXT
END SUB
