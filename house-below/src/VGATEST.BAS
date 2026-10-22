REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB Check (ok, label$)
 IF ok THEN PRINT #7, "PASS "; label$ ELSE PRINT #7, "FAIL "; label$: failcount = failcount + 1
 ' Flush each result so an emulator/runtime fault leaves a useful last check.
 CLOSE #7: OPEN "VGA\TEST.LOG" FOR APPEND AS #7
END SUB

SUB TestGame
 DIM i, h, door, rx, ry, rb, stable
 OPEN "VGA\TEST.LOG" FOR OUTPUT AS #7
 CALL Check(video <> 0, "native 320x200 indexed display")
 CALL Check(mouseok <> 0, "standard DOS mouse initialized")
 IF mouseok THEN
  ' Exercise the DOS driver's actual position API and the small cursor blit.
  uglClear back, 240
  verb = 1: selected = 0: hover = 0
  CALL PositionPointer(20, 20): CALL Present
  CALL Check(uglPGet(video, 20, 20) = 247, "custom cursor visible")
  CALL Check(uglPGet(back, 20, 20) = 240, "cursor leaves back buffer clean")
  CALL PositionPointer(40, 40): CALL RefreshPointer
  CALL Check(uglPGet(video, 40, 40) = 247 AND uglPGet(video, 20, 20) = 240, "cursor moves and restores background without Present")
  CALL ReadPointer(rx, ry, rb)
  CALL Check(rx = 40 AND ry = 40, "cursor tip matches absolute input coordinates")
  verb = 2: CALL Present
  CALL Check(uglPGet(video, 37, 37) = 247 AND uglPGet(video, 40, 40) = 240, "LOOK cursor replaces ACT without residue")
  verb = 1: CALL PositionPointer(0, 0): CALL Present
  CALL ReadPointer(rx, ry, rb)
  CALL Check(rx = 0 AND ry = 0 AND uglPGet(video, 0, 0) = 247, "cursor reaches top left screen edge")
  CALL PositionPointer(319, 199): CALL RefreshPointer
  CALL ReadPointer(rx, ry, rb)
  CALL Check(rx = 319 AND ry = 199 AND uglPGet(video, 0, 0) = 240, "screen corners restore cleanly")
  stable = -1
  FOR i = 0 TO 12
   CALL PositionPointer(160 + i, 120 - i): CALL ReadPointer(rx, ry, rb)
   IF rx <> 160 + i OR ry <> 120 - i THEN stable = 0
  NEXT
  CALL Check(stable, "small upward moves remain small")
  FOR i = 0 TO 12
   CALL PositionPointer(160 - i, 120 + i): CALL ReadPointer(rx, ry, rb)
   IF rx <> 160 - i OR ry <> 120 + i THEN stable = 0
  NEXT
  CALL Check(stable, "small downward moves remain small")
  CALL PositionPointer(160, 130)
  FOR i = 1 TO 100
   CALL ReadPointer(rx, ry, rb)
   IF rx <> 160 OR ry <> 130 THEN stable = 0
  NEXT
  CALL Check(stable, "stationary polling never accumulates movement")
  CALL Poll
  CALL Check(click = 0 AND rightclick = 0, "moving the pointer does not invent clicks")
 END IF
 FOR i = 1 TO 16
  CALL EnterRoom(i): CALL DrawScene
  CALL Check(art <> 0, "room background " + STR$(i))
  CALL DumpFrame(i)
  CALL CheckActors
 NEXT
 CALL CheckTalk
 CALL CheckPortraits
 CALL CheckSpeech
 CALL CheckContext
 CALL CheckOpening
 CALL EnterRoom(14): verb = 1: h = FindHot%(16, 1): CALL Act(h)
 CALL Check(room = 14, "boathouse cannot bypass clock and bridge")
 flags(1) = 1: selected = 0
 CALL EnterRoom(3): testpick = 1: CALL Special(102)
 CALL Check(flags(2) = 0, "clock requires its hand")
 CALL EnterRoom(4): h = FindHot%(3, 2): CALL Act(h)
 CALL EnterRoom(3): selected = 3: CALL Special(102)
 CALL Check(flags(2) = 1, "clock opens hidden stairs")
 CALL EnterRoom(5): h = FindHot%(2, 2): CALL Act(h)
 CALL EnterRoom(7): selected = 2: CALL Special(103)
 CALL Check(flags(3) AND inv(10), "study evidence recovered")
 CALL EnterRoom(4): testpick = 4: CALL Talk(2)
 CALL Check(inv(6) = 0 AND talkmenu = 0 AND nchoices = 4, "leave Elias conversation without taking ward key")
 testpick = 1: CALL Talk(2)
 CALL Check(inv(6) = 1, "Elias gives key after evidence")
 CALL EnterRoom(7): testpick = 1: CALL Special(104)
 CALL Check(inv(4) = 0, "wrong safe answer gives no fuse")
 testpick = 2: CALL Special(104)
 CALL EnterRoom(6): h = FindHot%(5, 2): CALL Act(h)
 CALL EnterRoom(15): selected = 4: CALL Special(105)
 CALL Check(flags(5) = 0, "generator needs both supplies")
 selected = 5: CALL Special(115)
 CALL Check(flags(5) = 1, "generator powers ventilation")
 CALL EnterRoom(11): testpick = 3: CALL Special(106)
 CALL Check(flags(6) = 1, "patient names restored")
 ' Separate input queue is exercised by the three-step control routine.
 CALL EnterRoom(12): testpick = 2: CALL Special(107)
 CALL Check(flags(7) = 0, "unsafe valve order rejected")
 ' /TEST Pick override advances by title for the correct valve sequence.
 testpick = 9: CALL Special(107)
 CALL Check(flags(7) = 1, "isolate return release accepted")
 CALL EnterRoom(8): CALL Special(118): testpick = 2: CALL Special(110)
 CALL Check(inv(9) = 1, "reversal mixture prepared")
 CALL EnterRoom(10): selected = 9: CALL Special(111)
 CALL Check(flags(11) = 1, "ward vapor cleared")
 selected = 6: CALL Special(112)
 CALL Check(flags(12) = 0, "unsafe bridge prevents rescue")
 CALL EnterRoom(14): h = FindHot%(7, 2): CALL Act(h)
 CALL EnterRoom(16): selected = 7: CALL Special(116)
 CALL EnterRoom(13): testpick = 1: CALL Special(108)
 CALL EnterRoom(16): selected = 8: CALL Special(109)
 CALL Check(flags(9) = 1, "rope and resonant latch secure route")
 CALL EnterRoom(10): selected = 6: CALL Special(112)
 CALL Check(flags(12) = 1, "all four patients rescued")
 CALL SaveGame(1): flags(12) = 0: CALL LoadGame(1)
 CALL Check(flags(12) = 1 AND room = 10, "save load roundtrip")
 OPEN "VGA\SLOT2.SAV" FOR OUTPUT AS #6
 PRINT #6, "DVGA1": PRINT #6, "99": CLOSE #6
 CALL LoadGame(2)
 CALL Check(flags(12) = 1 AND room = 10, "corrupt save preserves current progress")
 CALL LoadGame(99)
 CALL Check(flags(12) = 1 AND room = 10, "missing save preserves current progress")
 CALL DrawScene
 CALL Check(countinv = 10, "all ten items fit paged inventory")
 CALL DumpFrame(17)
 invpage = 1: CALL DrawScene: CALL DumpFrame(18): invpage = 0
 CALL EnterRoom(14): testpick = 1: CALL Special(113)
 CALL Check(flags(13) = 1, "witness ending reachable")
 testpick = 2: CALL Special(113)
 CALL Check(flags(13) = 2, "survivor agency ending reachable")
 PRINT #7, "FAILURES"; failcount
 CLOSE #7
END SUB

SUB DumpFrame (n)
 DIM f, x, y, rowdata AS STRING * 320, path$
 path$ = "VGA\SHOT" + RIGHT$("0" + LTRIM$(STR$(n)), 2) + ".RAW"
 f = FREEFILE: OPEN path$ FOR BINARY AS #f
 FOR y = 0 TO 199
  FOR x = 0 TO 319: MID$(rowdata, x + 1, 1) = CHR$(uglPGet(back, x, y)): NEXT
  PUT #f, , rowdata
 NEXT
 CLOSE #f
END SUB
