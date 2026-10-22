REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'
DECLARE SUB ClearContext ()
DECLARE FUNCTION HasTopic% (id)
DECLARE FUNCTION NamedHot% (s$)
DECLARE SUB AskKnown (person, id)

SUB ClearContext
 DIM i
 FOR i = 1 TO 32: flags(i) = 0: NEXT
 FOR i = 1 TO 16: inv(i) = 0: visited(i) = 0: NEXT
 FOR i = 1 TO 14: learned(i) = 0: NEXT
 inv(1) = 1: selected = 0: testpick = 0: testtalk$ = ""
 CALL EndTalk
END SUB

FUNCTION HasTopic% (id)
 DIM i
 HasTopic% = 0
 FOR i = 1 TO topiccount
  IF topicid(i) = id THEN HasTopic% = i: EXIT FUNCTION
 NEXT
END FUNCTION

FUNCTION NamedHot% (s$)
 DIM i, h
 NamedHot% = 0
 FOR i = 1 TO hn(room)
  h = (room - 1) * 12 + i
  IF names$(h) = s$ THEN NamedHot% = h: EXIT FUNCTION
 NEXT
END FUNCTION

' Ask one topic the story currently allows (wherever it sits in the menu), then leave.
SUB AskKnown (person, id)
 DIM i, npc
 CALL BuildTopics(person): i = HasTopic%(id)
 IF i = 0 THEN CALL Check(0, "test topic unexpectedly unavailable"): EXIT SUB
 testforce = id: testtalk$ = "4"
 npc = person
 CALL Talk(npc)
END SUB

' Is this topic currently one of the three menu rows?
FUNCTION RowHas% (person, id)
 DIM i
 RowHas% = 0
 CALL BuildTopics(person): talkmenu = person: CALL FillTopics(0): talkmenu = 0
 FOR i = 1 TO 3
  IF rowid(i) = id THEN RowHas% = -1
 NEXT
END FUNCTION

SUB CheckContext
 DIM sf(32), si(16), sv(16), sk(14), i, n, h, q, ok, oldroom, oldverb, oldpick
 DIM oldx, oldy, oldclick, oldkeys$
 oldroom = room: oldverb = verb: oldpick = testpick
 oldx = mx: oldy = my: oldclick = click: oldkeys$ = keys$
 FOR i = 1 TO 32: sf(i) = flags(i): NEXT
 FOR i = 1 TO 16: si(i) = inv(i): sv(i) = visited(i): NEXT
 FOR i = 1 TO 14: sk(i) = learned(i): NEXT
 CALL ClearContext: CALL EnterRoom(1)
 CALL BuildTopics(8)
 CALL Check(topiccount = 3 AND HasTopic%(6) = 0 AND HasTopic%(3) > 0, "fresh arrival cannot ask about an unseen upstairs shadow")
 h = NamedHot%("House windows"): verb = 3: CALL Act(h)
 CALL Check(learned(kWindow) = 0, "TALK to an object does not read its clue")
 verb = 2: CALL Act(h): CALL BuildTopics(8)
 CALL Check(HasTopic%(6) > 0 AND learned(kWindow) = 1, "LOOK at windows unlocks the shadow question with its source")
 CALL BeginTalk(8): testpick = 0
 q = ContextPick%(8, "COACHMAN", "Best get inside.")
 modal = -1: talkmenu = 8: CALL SetChoices: CALL PrepareFaces
 mx = 30: my = 177: CALL DrawScene: CALL DumpFrame(33)
 CALL Check(ChoiceAt%(30, 165) = 1 AND ChoiceAt%(30, 187) = 3 AND ChoiceAt%(30, 172) = 0, "three ticket rows with gaps between them")
 CALL Check(LeaveAt%(pnX1 - 20, pnY0 + 8) AND rowid(1) = 1 AND rowid(3) = 3, "clue questions wait behind the general ones until a slot frees up")
 CALL EndTalk: modal = 0
 ' Asked questions leave the menu and the next one moves up; evidence questions appear when learned.
 CALL ClearContext: CALL EnterRoom(6)
 CALL Check(RowHas%(3, 3) AND RowHas%(3, 4) AND RowHas%(3, 5) AND RowHas%(3, 6) = 0, "Ada's menu starts with three general questions")
 testtalk$ = "14": CALL Talk(3)
 CALL Check(RowHas%(3, 3) = 0 AND RowHas%(3, 4) AND RowHas%(3, 6) AND (flags(22) AND 4) <> 0, "an asked question vanishes and the next one takes its place")
 CALL ClearContext: CALL EnterRoom(2): learned(kPatients) = 5
 CALL Check(RowHas%(1, 1) AND RowHas%(1, 2), "James offers the patient topic once it is known")
 testtalk$ = "24": CALL Talk(1)
 CALL Check(RowHas%(1, 2) AND (flags(20) AND 2) <> 0, "evidence topics whose answer changes stay in the menu after being asked")
 CALL ClearContext: CALL EnterRoom(2)

 CALL ClearContext: CALL EnterRoom(2): CALL BuildTopics(1)
 CALL Check(HasTopic%(2) = 0 AND HasTopic%(3) = 0, "James does not assume knowledge of patients or the clock")
 CALL AskKnown(1, 4): CALL BuildTopics(1)
 CALL Check(HasTopic%(2) = 0 AND HasTopic%(3) = 0 AND learned(kPatients) = 0, "James's household introduction does not reveal patients or the ward")
 CALL AskKnown(1, 6)
 CALL Check((flags(20) AND 32) <> 0, "a late question records its stable identity")
 CALL EnterRoom(3): h = NamedHot%("Grandfather clock"): verb = 2: CALL Act(h)
 CALL BuildTopics(1)
 CALL Check(HasTopic%(3) > 0 AND learned(kClock) = 2, "examining the clock unlocks a question about the observed clock")

 CALL ClearContext: CALL EnterRoom(5): h = NamedHot%("Place cards")
 verb = 2: CALL Act(h): CALL BuildTopics(1)
 CALL Check(HasTopic%(2) = 0 AND learned(kPatients) = 0, "dining names do not identify people as patients")
 CALL EnterRoom(7): h = NamedHot%("Prescription notes"): CALL Act(h)
 CALL Learn(kRecords, 32): CALL BuildTopics(1)
 CALL Check(HasTopic%(2) = 0, "prescription notes and a study lead do not establish patients")
 CALL EnterRoom(6): CALL AskKnown(3, 6): CALL EnterRoom(2): CALL BuildTopics(1)
 q = HasTopic%(2)
 CALL Check(q > 0 AND topicsource$(q) = "Ada told you", "outside testimony unlocks James's patient topic with its actual source")
 CALL BeginTalk(1): CALL JamesPatients
 CALL Check(faceMood = 0 AND INSTR(body$, "doctor's affairs") > 0, "general knowledge gets a calm deflection, not a ward or ledger reaction")
 flags(3) = 1: CALL JamesPatients
 CALL Check(faceMood = 0 AND INSTR(body$, "doctor's papers") > 0, "recovered ledger gets a present-tense deflection without disclosing the ward")
 flags(3) = 0: inv(10) = 1: CALL JamesPatients
 CALL Check(INSTR(body$, "doctor's papers") > 0, "carried ledger also supports the evidence reply")
 inv(10) = 0: CALL EnterRoom(10): CALL EnterRoom(2): CALL JamesPatients
 CALL Check(faceMood = 1 AND INSTR(body$, "Downstairs?") = 1, "visiting the ward supports a worried response to the player's observation")
 flags(3) = 1: CALL JamesPatients
 CALL Check(faceMood = 1 AND INSTR(body$, "Doctor Mahler will explain it.") = 1, "ward and records strain James's composure without a confession")
 modal = -1: CALL DrawScene: CALL DumpFrame(39): modal = 0
 CALL EndTalk
 CALL ClearContext: CALL EnterRoom(10): CALL EnterRoom(2): CALL BuildTopics(1)
 q = HasTopic%(2)
 CALL Check(q > 0 AND learned(kPatients) = 0 AND topicsource$(q) = "Your visit downstairs", "seeing the ward permits an observation without inventing medical knowledge")
 CALL AskKnown(1, 2): CALL AskKnown(1, 2)
 CALL Check(flags(20) = 2 AND flags(3) = 0 AND inv(10) = 0, "evidence topic never grants unread records")

 CALL ClearContext: CALL EnterRoom(4): CALL BuildTopics(2)
 CALL Check(topiccount = 3 AND HasTopic%(1) = 0 AND HasTopic%(2) = 0 AND HasTopic%(3) = 0, "Elias starts with no ledger, preparation or ward-key assumptions")
 CALL AskKnown(2, 4)
 CALL Check(inv(6) = 0 AND learned(kRecords) = 5, "initial request for help establishes the study lead without giving a key")
 CALL AskKnown(2, 5): CALL BuildTopics(2)
 CALL Check(HasTopic%(2) > 0 AND flags(21) = 24 AND learned(kPreparation) = 5, "Elias's own explanation immediately unlocks a follow-up")
 CALL Check((flags(21) AND 2) = 0, "new question does not inherit the color of its old row")
 CALL Check(flags(21) = 24 AND RowHas%(2, 5) = 0, "asked introductory questions leave the menu once new ones appear")
 CALL AskKnown(2, 6): CALL BuildTopics(2)
 CALL Check(HasTopic%(3) > 0 AND HasTopic%(1) = 0, "learning about the key does not claim an unread ledger")
 CALL AskKnown(2, 3)
 CALL Check(inv(6) = 0, "contextual ward-key question still requires reading the evidence")
 flags(3) = 1: inv(10) = 1: CALL AskKnown(2, 1)
 CALL Check(inv(6) = 1, "reporting the discovered ledger earns the ward key")
 CALL ClearContext: CALL EnterRoom(7): h = NamedHot%("Prescription notes")
 verb = 1: CALL Act(h): CALL BuildTopics(2)
 CALL Check(learned(kPreparation) = 7 AND HasTopic%(2) > 0 AND HasTopic%(1) = 0, "ACT reads prescription notes without falsely reading the locked ledger")

 CALL ClearContext: CALL EnterRoom(6): CALL BuildTopics(3)
 CALL Check(HasTopic%(1) = 0 AND HasTopic%(2) = 0, "Ada begins without unexplored lake or machinery questions")
 CALL AskKnown(3, 4): CALL AskKnown(3, 5): CALL BuildTopics(3)
 CALL Check(HasTopic%(1) > 0 AND HasTopic%(2) > 0, "Ada's general answers open lake and machinery follow-ups")
 CALL ClearContext: CALL EnterRoom(10): CALL BuildTopics(4)
 CALL Check(HasTopic%(3) = 0, "Clara cannot be told the escape is safe before preparations")
 CALL AskKnown(4, 1): CALL BuildTopics(5)
 CALL Check(HasTopic%(1) > 0 AND HasTopic%(2) > 0 AND HasTopic%(3) > 0 AND learned(kCrossing) = 8, "Clara's plan unlocks relevant questions for Thomas")
 flags(6) = 1: flags(11) = 1: CALL BuildTopics(4)
 CALL Check(HasTopic%(3) = 0, "partial rescue preparations do not claim a safe route")
 flags(9) = 1: CALL BuildTopics(4)
 CALL Check(HasTopic%(3) > 0, "completed preparations unlock Clara's ready-to-leave statement")
 CALL ClearContext: CALL BuildTopics(5)
 CALL Check(topiccount = 3 AND HasTopic%(1) = 0 AND HasTopic%(2) = 0 AND HasTopic%(3) = 0, "Thomas offers general questions before technical discoveries")
 CALL AskKnown(5, 4): CALL BuildTopics(5)
 CALL Check(HasTopic%(1) > 0 AND HasTopic%(2) > 0 AND HasTopic%(3) = 0, "engine explanation unlocks pressure and fan without inventing a bridge clue")
 CALL AskKnown(5, 5): CALL BuildTopics(5)
 CALL Check(HasTopic%(3) > 0, "Thomas explains the crossing before its follow-up is offered")
 CALL ClearContext: CALL EnterRoom(11): CALL BuildTopics(6)
 CALL Check(HasTopic%(3) = 0, "Miriam does not assume a rescue plan before discussing it")
 CALL AskKnown(6, 4): CALL BuildTopics(6)
 CALL Check(HasTopic%(3) > 0 AND learned(kRescue) = 22, "Miriam's request establishes a shared plan to leave")

 ' Visit flags alone must never unlock objects the player did not read.
 CALL ClearContext
 FOR i = 1 TO 16: visited(i) = 1: NEXT
 CALL BuildTopics(2)
 CALL Check(HasTopic%(1) = 0 AND HasTopic%(2) = 0, "visiting every room does not read any hidden evidence")
 CALL Learn(kPreparation, 7): CALL Learn(kPreparation, 5)
 flags(21) = 50: CALL SaveGame(1)
 learned(kPreparation) = 0: flags(21) = 0: CALL LoadGame(1)
 CALL Check(learned(kPreparation) = 7 AND flags(21) = 50, "save restores original clue source and extended asked history")
 learned(kPreparation) = 37: CALL SaveGame(2): learned(kPreparation) = 7
 CALL LoadGame(2)
 CALL Check(heading$ = "INVALID SAVE" AND learned(kPreparation) = 7, "invalid discovery source cannot replace the current journey")
 OPEN "VGA\SLOT2.SAV" FOR OUTPUT AS #6
 PRINT #6, "DVGA1": WRITE #6, 4
 FOR i = 1 TO 32
  n = 0: IF i = 21 THEN n = 2
  WRITE #6, n
 NEXT
 FOR i = 1 TO 16: WRITE #6, 0, 0: NEXT
 CLOSE #6
 CALL LoadGame(2): CALL BuildTopics(2)
 CALL Check(room = 4 AND flags(21) = 2 AND learned(kPreparation) = 5 AND HasTopic%(1) = 0, "legacy DVGA1 recovers heard dialogue without inventing unread evidence")
 OPEN "VGA\SLOT2.SAV" FOR OUTPUT AS #6
 PRINT #6, "DVGA2": WRITE #6, 4: CLOSE #6
 CALL LoadGame(2)
 CALL Check(heading$ = "INVALID SAVE" AND learned(kPreparation) = 5, "truncated discovery save preserves knowledge")

 ' Exercise every authored answer, including page-two topics and width checks.
 CALL ClearContext: ok = -1
 FOR n = 1 TO 8
  IF n <> 7 THEN
   FOR i = 1 TO 14: learned(i) = 4: NEXT
   flags(3) = 1: flags(6) = 1: flags(9) = 1: flags(11) = 1
   flags(28) = 1: flags(29) = 1
   room = 2: IF n = 8 THEN room = 1
   FOR q = 1 TO 6: CALL AskKnown(n, q): NEXT
   IF flags(19 + n) <> 63 THEN ok = 0
  END IF
 NEXT
 CALL Check(ok, "all 42 contextual and introductory topics are answerable and tracked")
 CALL EndTalk: modal = 0
 FOR i = 1 TO 32: flags(i) = sf(i): NEXT
 FOR i = 1 TO 16: inv(i) = si(i): visited(i) = sv(i): NEXT
 FOR i = 1 TO 14: learned(i) = sk(i): NEXT
 CALL EnterRoom(oldroom): verb = oldverb: testpick = oldpick
 mx = oldx: my = oldy: click = oldclick: keys$ = oldkeys$: testtalk$ = ""
END SUB
