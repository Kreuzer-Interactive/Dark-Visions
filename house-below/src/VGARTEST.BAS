REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB CheckOpening
 DIM sf(32), sk(14), sv(16), si(16), oldroom, oldpick, oldverb, oldsel, i, h, door, valid
 DIM beforepal(0 TO 255) AS tRGB, afterpal(0 TO 255) AS tRGB
 oldroom = room: oldpick = testpick: oldverb = verb: oldsel = selected
 FOR i = 1 TO 32: sf(i) = flags(i): flags(i) = 0: NEXT
 FOR i = 1 TO 14: sk(i) = learned(i): learned(i) = 0: NEXT
 FOR i = 1 TO 16: sv(i) = visited(i): si(i) = inv(i): NEXT
 selected = 0: verb = 1: visited(2) = 0
 CALL LetterBackdrop: testpick = 0: valid = ReadLetter%
 CALL Check(valid = 0 AND introshot = 1 AND convperson = 0 AND playerline = 0 AND youDC = 0 AND faceDC = 0, "skipping letter reading frees its solo portrait and returns cleanly")
 CALL Check(INSTR(body$, "Ravenhurst") > 0 AND INSTR(body$, "chemist") > 0 AND INSTR(body$, "Your uncle, Frank") > 0, "the player reads the invitation shown on his lap")
 ' Render the actual reading text retained by the skipped first line.
 CALL BeginTalk(-1): introshot = 4: playerline = -1
 valid = Pick%("YOU / READING UNCLE FRANK'S LETTER", body$, "Continue [Enter]", "", "")
 CALL Check(youDC <> 0 AND faceDC = 0 AND ChoiceAt%(20, 175) = 0, "letter reading has only the player portrait and no hidden menu targets")
 testing = 0: CALL StartSpeech(100!): CALL AdvanceSpeech(100.2!)
 CALL Check(speechcount > 0 AND speechcount < LEN(body$) AND Speaking%, "the player's letter reading uses the gradual speech reveal")
 valid = RevealSpeech%(-1): modal = -1: CALL DrawScene: CALL DumpFrame(42)
 CALL Check(OnLastPage% AND PageEnd% = LEN(body$) AND Tw%(heading$) <= 288, "invitation and reading label fit the speech panel")
 testing = -1: CALL EndTalk: modal = 0: introshot = 1
 testpick = 1: valid = ReadLetter%
 CALL Check(valid AND introshot = 1 AND convperson = 0 AND speechcount = 0 AND TextLines%(body$, 272) <= 3, "brief reflection fits one speech page and clears reading state before the jolt")
 CALL Check(flags(1) = 0 AND flags(28) = 0 AND flags(29) = 0, "reading the invitation grants no house access or unseen coachman knowledge")
 testpick = 2: CALL Opening
 CALL Check(room = 1 AND carscene = 0 AND introshot = 0 AND flags(1) = 0, "skip car opening arrives outside without bypassing invitation")
 CALL Check(flags(28) = 0 AND flags(29) = 0, "skipping does not invent coachman knowledge")
 CALL Journal
 CALL Check(INSTR(body$, "apprenticeship") > 0 AND INSTR(body$, "front door") > 0, "journal retains essential opening context after skipping")
 testpick = 1: testtalk$ = "114": CALL Opening
 CALL Check(room = 1 AND carscene = 0 AND introshot = 0 AND convperson = 0 AND playerline = 0, "letter sequence and car conversation transition cleanly to exterior")
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
 ' Capture the letter, overscanned shake and forward reveal in the native renderer.
 CALL LetterBackdrop: modal = -1: nchoices = 1: CALL SetChoices
 choices$(1) = "Begin journey [Enter]": choices$(2) = ""
 CALL DrawScene: CALL DumpFrame(35)
 CALL Check(choicetop + choiceh <= 200, "opening Begin button fits on screen; Escape hint is in title bar")
 introshot = 2: CALL DrawOpening(3, -3): CALL DumpFrame(40)
 CALL Check(uglPGet(back, 0, 10) = uglPGet(art, 1, 17) AND uglPGet(back, 319, 153) = uglPGet(art, 320, 160), "jolt upper-right extreme has no exposed scenery edges")
 CALL DrawOpening(-3, 3)
 CALL Check(uglPGet(back, 0, 10) = uglPGet(art, 7, 11) AND uglPGet(back, 319, 153) = uglPGet(art, 326, 154), "jolt lower-left extreme has no exposed scenery edges")
 CALL Check(uglPGet(back, 319, 154) = 240 AND uglPGet(back, 319, 9) = 240, "letter overscan cannot cover the fixed title or toolbar")
 uglPalGetBuff 0, 256, beforepal(0)
 CALL DoorShade(0): keys$ = CHR$(27)
 valid = CarReveal%
 CALL Check(valid = 0 AND introshot = 0 AND keys$ = "" AND click = 0 AND rightclick = 0, "Escape cancels cinematic and consumes its input")
 uglPalGetBuff 0, 256, afterpal(0)
 valid = -1
 FOR i = 0 TO 255
  IF beforepal(i).red <> afterpal(i).red OR beforepal(i).green <> afterpal(i).green OR beforepal(i).blue <> afterpal(i).blue THEN valid = 0
 NEXT
 CALL Check(valid, "cancelling a darkened cinematic restores all 256 palette colors")
 CALL Check(flags(1) = 0 AND flags(28) = 0 AND flags(29) = 0, "cinematic cancellation grants no invitation or coachman knowledge")
 CALL LetterBackdrop: valid = CarReveal%
 CALL Check(valid AND carscene AND introshot = 0, "complete cinematic loads forward car view for conversation")
 introshot = 3: CALL DrawOpening(0, 0): CALL DumpFrame(41): introshot = 0
 CALL BeginTalk(8): CALL Reply(0, "COACHMAN", "Last bend before Ravenhurst, sir. You have business with Doctor Mahler?")
 CALL DrawScene: CALL DumpFrame(36)
 playerline = -1: CALL Say("YOU", "He is my uncle. His letter offered me an apprenticeship. He says my chemistry will be useful.")
 CALL DrawScene: CALL DumpFrame(37)
 CALL Check(uglPGet(back, 300, 170) = 240 AND uglPGet(back, 44, 136) = 246, "scripted player speech has its tail on you")
 playerline = 0: carscene = 0: CALL EndTalk: modal = 0
 FOR i = 1 TO 32: flags(i) = sf(i): NEXT
 FOR i = 1 TO 14: learned(i) = sk(i): NEXT
 FOR i = 1 TO 16: visited(i) = sv(i): inv(i) = si(i): NEXT
 CALL EnterRoom(oldroom)
 testpick = oldpick: verb = oldverb: selected = oldsel: testtalk$ = ""
END SUB
