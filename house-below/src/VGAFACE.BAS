REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

FUNCTION FaceName$ (person)
 SELECT CASE person
 CASE 0: FaceName$ = "YOU"
 CASE 1: FaceName$ = "JAMES"
 CASE 2: FaceName$ = "ELIAS HART"
 CASE 3: FaceName$ = "ADA FINCH"
 CASE 4: FaceName$ = "CLARA VALE"
 CASE 5: FaceName$ = "THOMAS REED"
 CASE 6: FaceName$ = "MIRIAM BELL"
 CASE 8
  FaceName$ = "COACHMAN"
  IF flags(28) THEN FaceName$ = "ARTHUR PIKE"
 END SELECT
END FUNCTION

FUNCTION PortraitFile$ (person, mood, quiet)
 DIM suffix$
 suffix$ = "A": IF quiet THEN suffix$ = "L"
 PortraitFile$ = "VGA\P" + LTRIM$(STR$(person)) + LTRIM$(STR$(mood)) + suffix$ + ".BMP"
END FUNCTION

SUB BeginTalk (person)
 CALL EndTalk
 convperson = person
 faceKey = -1: youKey = -1
END SUB

SUB EndTalk
 IF faceDC <> 0 THEN uglDel faceDC: faceDC = 0
 IF youDC <> 0 THEN uglDel youDC: youDC = 0
 convperson = 0: convquit = 0: talkmenu = 0
 playerline = 0
 faceMood = 0: youMood = 0: faceKey = -1: youKey = -1
 utterance$ = "": lastreply$ = ""
 speechcount = 0: speechcredit = 0
 topiccount = 0: topicpage = 0
END SUB

SUB PrepareFaces
 DIM quiet, mood, cacheid, path$
 ' Only two pre-sized faces are resident. No disk reads in the frame loop.
 quiet = 0: IF talkmenu OR playerline THEN quiet = 1
 cacheid = convperson * 16 + faceMood * 2 + quiet
 IF faceKey <> cacheid THEN
  IF faceDC <> 0 THEN uglDel faceDC: faceDC = 0
  path$ = PortraitFile$(convperson, faceMood, quiet)
  faceDC = uglNewBMPEx(UGL.MEM, UGL.8BIT, path$, BMPOPT.NO332)
  IF faceDC = 0 THEN CALL Finish: PRINT "Cannot load portrait: "; path$: END
  faceKey = cacheid
 END IF
 quiet = 1: mood = youMood
 IF talkmenu OR playerline THEN quiet = 0: mood = 0
 cacheid = mood * 2 + quiet
 IF youKey <> cacheid THEN
  IF youDC <> 0 THEN uglDel youDC: youDC = 0
  path$ = PortraitFile$(0, mood, quiet)
  youDC = uglNewBMPEx(UGL.MEM, UGL.8BIT, path$, BMPOPT.NO332)
  IF youDC = 0 THEN CALL Finish: PRINT "Cannot load portrait: "; path$: END
  youKey = cacheid
 END IF
END SUB

SUB DrawFaces
 IF talkmenu OR playerline THEN
  uglPutMsk back, 0, 12, youDC
  uglPutMskFlip back, 240, 36, UGL.HFLIP, faceDC
 ELSE
  uglPutMsk back, 8, 36, youDC
  uglPutMskFlip back, 224, 12, UGL.HFLIP, faceDC
 END IF
END SUB

SUB Reply (mood, title$, text$)
 ' 0 attentive, 1 troubled, 2 determined, 3 warm. Authored per line.
 faceMood = mood: youMood = 0
 IF mood = 1 OR mood = 3 THEN youMood = mood
 CALL Say(title$, text$)
END SUB

SUB Speak (person, title$, text$)
 CALL BeginTalk(person)
 faceMood = 2
 IF title$ = "INSIDE RAVENHURST" THEN faceMood = 3
 CALL Reply(faceMood, title$, text$)
 CALL EndTalk
END SUB
