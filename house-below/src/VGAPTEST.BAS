REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

FUNCTION FacePixels% (dc AS LONG, w, h, x, y, flipped)
 DIM xx, yy, sx, expected AS LONG
 FacePixels% = -1
 FOR yy = 0 TO h - 1
  FOR xx = 0 TO w - 1
   sx = xx: IF flipped THEN sx = w - 1 - xx
   expected = uglPGet(dc, sx, yy)
   IF expected = 227 THEN
    expected = 240
    IF y + yy < 154 THEN expected = uglPGet(art, x + xx, y + yy)
   END IF
   IF uglPGet(back, x + xx, y + yy) <> expected THEN FacePixels% = 0: EXIT FUNCTION
  NEXT
 NEXT
END FUNCTION

SUB CheckPortraits
 DIM n, person, q, mood, oldroom, oldpick, valid, mask
 DIM savedFace AS LONG, savedYou AS LONG
 oldroom = room: oldpick = testpick
 CALL EnterRoom(2)
 FOR person = 1 TO 7
  n = person: IF person = 7 THEN n = 8
  testpick = 0: CALL Talk(n)
  CALL BeginTalk(n): modal = -1
  FOR mood = 0 TO 3
   faceMood = mood: youMood = mood
   ' Both busts are full size: you left, them right and mirrored to face you (rows above the tail).
   talkmenu = 0: nchoices = 1: CALL SetChoices: CALL PrepareFaces
   CALL DrawScene
   valid = FacePixels%(faceDC, 96, 60, 222, 75, -1)
   valid = valid AND FacePixels%(youDC, 96, 60, 2, 75, 0)
   CALL Check(valid, "both busts face inward at full size over the room: " + FaceName$(n) + STR$(mood))
   talkmenu = n: nchoices = 3: CALL SetChoices: CALL PrepareFaces
   CALL DrawScene
   valid = FacePixels%(faceDC, 96, 60, 222, 75, -1)
   valid = valid AND FacePixels%(youDC, 96, 60, 2, 75, 0)
   CALL Check(valid, "busts keep their places while you choose: " + FaceName$(n) + STR$(mood))
  NEXT
  faceMood = 0
  IF n = 2 OR n = 5 THEN faceMood = 1
  IF n = 4 OR n = 6 THEN faceMood = 2
  CALL PrepareFaces: CALL DrawScene: CALL DumpFrame(19 + n)
  valid = -1
  FOR q = 1 TO 3
   IF ChoiceAt%(20, 165 + (q - 1) * 11) <> q THEN valid = 0
  NEXT
  CALL Check(valid, "full-width ticket hit regions: " + FaceName$(n))
  savedFace = faceDC: savedYou = youDC
  CALL PrepareFaces
  CALL Check(savedFace = faceDC AND savedYou = youDC, "unchanged dialogue reuses loaded portraits: " + FaceName$(n))
  CALL EndTalk: modal = 0
 NEXT
 mask = flags(20)
 CALL BeginTalk(1): testpick = 2
 q = TalkPick%(1, "JAMES", "Were you expected, sir?", "My invitation", "Who are you?", "The house")
 CALL Check(q = 2 AND utterance$ = "Who are you?", "selected topic is retained internally for conversation flow")
 CALL Reply(0, "JAMES", "The doctor is occupied, sir. I will let you know when he is ready.")
 modal = -1: CALL DrawScene: CALL DumpFrame(26)
 utterance$ = "I've seen the people downstairs."
 CALL Reply(1, "JAMES", "Downstairs? That is not part of your visit, sir. Your room is upstairs. I can show you the way.")
 CALL Check(faceMood = 1 AND youMood = 1, "troubled line changes speaker expression and listener reaction")
 CALL DrawScene: CALL DumpFrame(27)
 testpick = 0: q = TalkPick%(1, "JAMES", "A greeting", "My invitation", "Who are you?", "The house")
 CALL Check(faceMood = 1 AND body$ = "" AND lastreply$ <> "", "returning topics keep the expression without repeating speech")
 utterance$ = "Here is my uncle's invitation."
 CALL Reply(3, "JAMES", "Yes, sir. Everything is in order. Your room is upstairs.")
 CALL Check(faceMood = 3 AND youMood = 3, "welcome changes both faces to warmth")
 CALL DrawScene: CALL DumpFrame(28)
 CALL Reply(2, "JAMES", "Please show me your invitation before we go inside.")
 CALL Check(faceMood = 2 AND youMood = 0, "firm line returns listener to attention")
 CALL DrawScene: CALL DumpFrame(29)
 CALL Check(ChoiceAt%(80, 192) = 0 AND ChoiceAt%(80, 170) = 0, "spoken lines have no clickable rows or covered toolbar")
 CALL Check(ChoiceAt%(8, 160) = 0 AND ChoiceAt%(50, 175) = 0, "hidden verbs and inventory have no conversation hit regions")
 talkmenu = 1: nchoices = 3: choices$(1) = "a": choices$(2) = "b": choices$(3) = "c": CALL SetChoices
 CALL Check(ChoiceAt%(80, 172) = 0 AND ChoiceAt%(8, 165) = 0 AND ChoiceAt%(80, 60) = 0, "ticket gaps and portrait areas do not select questions")
 CALL Check(LeaveAt%(pnX1 - 20, pnY0 + 8) AND LeaveAt%(80, 165) = 0, "Leave sits in the panel header")
 CALL EndTalk: modal = 0
 CALL Check(faceDC = 0 AND youDC = 0 AND convperson = 0 AND faceMood = 0 AND utterance$ = "", "Goodbye frees portraits, expressions and conversation state")
 flags(20) = mask
 CALL EnterRoom(oldroom): testpick = oldpick
END SUB
