REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB CheckOpening
 DIM sf(32), sk(14), sv(16), si(16), oldroom, oldpick, oldverb, oldsel, i, h, door, valid
 oldroom = room: oldpick = testpick: oldverb = verb: oldsel = selected
 FOR i = 1 TO 32: sf(i) = flags(i): flags(i) = 0: NEXT
 FOR i = 1 TO 14: sk(i) = learned(i): learned(i) = 0: NEXT
 FOR i = 1 TO 16: sv(i) = visited(i): si(i) = inv(i): NEXT
 selected = 0: verb = 1: visited(2) = 0
 testpick = 2: CALL Opening
 CALL Check(room = 1 AND carscene = 0 AND flags(1) = 0, "skip car opening arrives outside without bypassing invitation")
 CALL Check(flags(28) = 0 AND flags(29) = 0, "skipping does not invent coachman knowledge")
 CALL Journal
 CALL Check(INSTR(body$, "apprenticeship") > 0 AND INSTR(body$, "front door") > 0, "journal retains essential opening context after skipping")
 testpick = 1: testtalk$ = "114": CALL Opening
 CALL Check(room = 1 AND carscene = 0 AND convperson = 0 AND playerline = 0, "complete car conversation transitions cleanly to exterior")
 CALL Check(flags(27) = 3 AND flags(28) = 1 AND flags(29) = 1, "car questions and noticed silks carry into arrival")
 CALL Check(INSTR(body$, "Mind the step") > 0, "coachman encourages shelter after getting out")
 testtalk$ = "14": CALL Talk(8)
 CALL Check(flags(27) = 7 AND testtalk$ = "", "car questions do not return outside; the next question moves up")
 selected = 1: CALL Talk(8)
 CALL Check(flags(1) = 0 AND selected = 0 AND INSTR(body$, "James") > 0, "coachman redirects invitation to James")
 CALL Check(FindHot%(1, 4) = 0 AND FindHot%(8, 4) > 0, "coachman replaces outdoor James beside the car")
 h = FindHot%(8, 4)
 CALL Check((hx(h) + hr(h)) \ 2 < px, "coachman stands left of player beside parked car")
 flags(29) = 0: verb = 2: CALL Act(h)
 CALL Check(flags(29) = 1, "examining coachman notices his racing silks")
 flags(12) = 1
 CALL Check(Hit%((hx(h) + hr(h)) \ 2, hy(h) + 8) = h, "coachman remains separate from four rescued ward patients")
 flags(12) = 0
 FOR i = 1 TO hn(1)
  IF hk(i) = 1 AND hy(i) < 143 THEN door = i
 NEXT
 CALL Check(door > 0, "lit front door is an interactive route")
 IF door THEN
  verb = 2: CALL Act(door)
  CALL Check(room = 1 AND INSTR(body$, "knock") > 0, "LOOK explains knocking without starting entry")
  verb = 1: testpick = 2: CALL Act(door)
  CALL Check(room = 1 AND flags(1) = 0, "declining invitation conversation leaves player outside")
  selected = 2: CALL Act(door)
  CALL Check(room = 1 AND flags(1) = 0, "unrelated selected item cannot bypass James")
  selected = 1: testpick = 1: CALL Act(door)
  CALL Check(flags(1) = 1 AND room = 2 AND selected = 0, "showing invitation at door enters hall")
  CALL Check(heading$ = "INSIDE RAVENHURST", "James introduces house only after crossing threshold")
 END IF
 verb = 3: h = FindHot%(1, 1): CALL Act(h)
 CALL Check(room = 1, "hall exit returns to coachman exterior in TALK mode")
 verb = 2: h = FindHot%(2, 1): CALL Act(h)
 CALL Check(room = 2, "door exit plate enters in LOOK mode after admission")
 flags(1) = 0: CALL EnterRoom(1): selected = 0: testpick = 1
 CALL Act(FindHot%(2, 1))
 CALL Check(room = 2 AND flags(1) = 1, "knocking with no selected item offers invitation and enters")
 flags(27) = 63: flags(28) = 1: flags(29) = 1: CALL SaveGame(2)
 flags(27) = 0: flags(28) = 0: flags(29) = 0: CALL LoadGame(2)
 CALL Check(flags(27) = 63 AND flags(28) = 1 AND flags(29) = 1 AND carscene = 0, "DVGA3 restores coachman knowledge and all six topic bits without replay")
 flags(27) = 64: CALL SaveGame(2): flags(27) = 3: CALL LoadGame(2)
 CALL Check(flags(27) = 3 AND heading$ = "INVALID SAVE", "invalid coachman history preserves journey")
 ' A complete prior-format save has the same room graph and no new NPC history.
 OPEN "VGA\SLOT2.SAV" FOR OUTPUT AS #6
 PRINT #6, "DVGA2": WRITE #6, 1
 FOR i = 1 TO 32
  valid = 0: IF i = 26 THEN valid = 15
  WRITE #6, valid
 NEXT
 FOR i = 1 TO 16: WRITE #6, 0, 0: NEXT
 FOR i = 1 TO 14: WRITE #6, 0: NEXT
 CLOSE #6
 CALL LoadGame(2)
 CALL Check(room = 1 AND flags(26) = 15 AND flags(27) = 0, "DVGA2 outdoor James history never becomes coachman history")
 ' Capture actual native renderings of the new scene and speaker changes.
 CALL CarBackdrop: modal = -1: nchoices = 2: CALL SetChoices
 choices$(1) = "Begin journey [Enter]": choices$(2) = "Skip to arrival [Esc]"
 CALL DrawScene: CALL DumpFrame(35)
 CALL BeginTalk(8): CALL Reply(0, "COACHMAN", "Last bend before Ravenhurst, sir. You have business with Doctor Mahler?")
 CALL DrawScene: CALL DumpFrame(36)
 playerline = -1: CALL Say("YOU", "He is my uncle. His letter offered me an apprenticeship. He says my chemistry will be useful.")
 CALL DrawScene: CALL DumpFrame(37)
 CALL Check(uglPGet(back, 300, 170) = 253 AND uglPGet(back, 44, 139) = 253, "scripted player speech is the blue panel with the tail on you")
 playerline = 0: carscene = 0: CALL EndTalk: modal = 0
 FOR i = 1 TO 32: flags(i) = sf(i): NEXT
 FOR i = 1 TO 14: learned(i) = sk(i): NEXT
 FOR i = 1 TO 16: visited(i) = sv(i): inv(i) = si(i): NEXT
 CALL EnterRoom(oldroom)
 testpick = oldpick: verb = oldverb: selected = oldsel: testtalk$ = ""
END SUB
