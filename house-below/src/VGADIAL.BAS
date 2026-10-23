REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB SetChoices
 choicex = 21: choicew = 278: choicetop = 100: choicestep = 15: choiceh = 14
 IF convperson THEN
  ' Paper tickets inside the conversation panel, under the name header.
  choicex = 10: choicew = 300: choicetop = pnY0 + 17: choicestep = 11: choiceh = 10
 ELSEIF talkmenu THEN
  choicetop = 85
 END IF
 IF carscene AND convperson = 0 THEN choicex = 12: choicew = 296: choicetop = 186: choicestep = 16
END SUB

FUNCTION ChoiceAt% (x, y)
 DIM rown
 ChoiceAt% = 0
 IF convperson <> 0 AND MenuMode% = 0 THEN EXIT FUNCTION
 IF x < choicex OR x >= choicex + choicew OR y < choicetop THEN EXIT FUNCTION
 rown = (y - choicetop) \ choicestep + 1
 IF rown > nchoices THEN EXIT FUNCTION
 IF talkmenu AND choices$(rown) = "" THEN EXIT FUNCTION
 IF (y - choicetop) MOD choicestep >= choiceh THEN EXIT FUNCTION
 ChoiceAt% = rown
END FUNCTION

FUNCTION TextLines% (text$, wide)
 DIM i, line$, word$, ch$, lines
 lines = 1
 FOR i = 1 TO LEN(text$) + 1
  ch$ = MID$(text$, i, 1)
  IF ch$ = " " OR i > LEN(text$) THEN
   IF Tw%(line$ + word$) > wide THEN lines = lines + 1: line$ = ""
   line$ = line$ + word$ + " ": word$ = ""
  ELSE
   word$ = word$ + ch$
  END IF
 NEXT
 TextLines% = lines
END FUNCTION

SUB DrawDialog
 DIM i, col, y, s$
 IF convperson THEN
  IF introshot = 4 THEN
   CALL DrawOpening(0, 0)
  ELSE
   ' Keep the toolbar's background beneath the overlaid portraits and speech bubble.
   uglClear back, 240
   uglPut back, 0, 0, art
   uglLine back, 0, 154, 319, 154, 245
   CALL Box(0, 0, 320, 10, 240)
   IF carscene THEN
    CALL Txt(5, 2, "THE ROAD TO RAVENHURST", 245)
    CALL Txt(246, 2, "ESC: arrive", 252)
   ELSE
    CALL Txt(5, 2, rt$(room), 245)
   END IF
  END IF
  CALL DrawFaces
  CALL DrawSpeech
  hover = ChoiceAt%(mx, my)
  EXIT SUB
 ELSEIF carscene THEN
  CALL DrawOpening(0, 0)
 ELSE
  CALL Box(12, 12, 296, 139, 240)
  uglRect back, 12, 12, 307, 150, 245
  CALL Txt(21, 21, heading$, 246)
  uglLine back, 21, 33, 298, 33, 243
  CALL Wrap(21, 41, body$, 247, 276)
 END IF
 FOR i = 1 TO nchoices
  IF choices$(i) <> "" THEN
  y = choicetop + (i - 1) * choicestep
  col = 241: IF ChoiceAt%(mx, my) = i THEN col = 250
  CALL Box(choicex, y, choicew, choiceh, col)
  s$ = LTRIM$(STR$(i)) + ". " + choices$(i)
  CALL Txt(choicex + 4, y + (choiceh - 7) \ 2, s$, 246)
  END IF
 NEXT
 hover = ChoiceAt%(mx, my)
END SUB

' Up/Down move the highlighted ticket (the cursor follows), skipping empty rows.
SUB StepChoice (delta)
 DIM i, tries
 i = ChoiceAt%(mx, my)
 tries = 0
 DO
  IF i = 0 THEN
   IF delta > 0 THEN i = 1 ELSE i = nchoices
  ELSE
   i = i + delta
   IF i < 1 THEN i = nchoices
   IF i > nchoices THEN i = 1
  END IF
  tries = tries + 1
 LOOP WHILE choices$(i) = "" AND tries <= nchoices
 IF choices$(i) = "" THEN EXIT SUB
 mx = choicex + 8: my = choicetop + (i - 1) * choicestep + choiceh \ 2
 CALL PositionPointer(mx, my)
END SUB

FUNCTION Pick% (title$, text$, a$, b$, c$)
 DIM result, i
 DIM hold AS SINGLE
 heading$ = title$: body$ = text$
 choices$(1) = a$: choices$(2) = b$: choices$(3) = c$
 nchoices = 1: IF b$ <> "" THEN nchoices = 2
 IF c$ <> "" THEN nchoices = 3
 IF talkmenu THEN nchoices = 3
 IF talkmenu <> 0 AND topiccount > 0 THEN CALL FillTopics(topicpage)
 CALL SetChoices
 IF convperson THEN CALL PrepareFaces
 CALL StartSpeech(TIMER)
 IF testing THEN
  IF convperson THEN
   IF talkmenu THEN
    FOR i = 1 TO nchoices
     IF Tw%(choices$(i)) > choicew - 40 THEN CALL Check(0, "topic overflows its ticket: " + choices$(i))
    NEXT
   END IF
  END IF
  Pick% = testpick
  IF testpick = 9 THEN
   Pick% = 1
   IF title$ = "PRESSURE / STEP TWO" THEN Pick% = 2
   IF title$ = "PRESSURE / STEP THREE" THEN Pick% = 3
  END IF
  IF talkmenu AND testpick = 4 THEN Pick% = 0
  EXIT FUNCTION
 END IF
 modal = -1: result = -1
 DO WHILE result = -1
  CALL Poll
  IF keys$ = CHR$(27) OR (convperson AND rightclick) THEN
   IF convperson <> 0 AND MenuMode% = 0 AND carscene = 0 THEN
    ' In a spoken line Esc or right-click skips the rest of the line, not the conversation.
    result = 1
   ELSE
    result = 0
    IF convperson THEN convquit = -1
   END IF
  END IF
  IF result = -1 AND convperson <> 0 AND MenuMode% = 0 THEN
   ' One click, Enter or Space anywhere: finish the line, then the next page, then move on.
   IF click THEN
    click = 0: keys$ = ""
    IF Speaking% THEN
     i = RevealSpeech%(-1)
    ELSEIF NextPage% THEN
     i = 0
    ELSE
     result = 1
    END IF
   END IF
   CALL AdvanceSpeech(TIMER)
   ' Spoken replies advance after a beat; the opening letter waits for the reader.
   IF result = -1 AND playerline <> 0 AND introshot <> 4 AND Speaking% = 0 AND OnLastPage% THEN
    IF hold = 0 THEN hold = TIMER
    IF TIMER - hold > .8 OR TIMER < hold THEN result = 1
   END IF
  ELSEIF result = -1 AND MenuMode% THEN
   IF keys$ >= "1" AND keys$ <= "4" AND LEN(keys$) = 1 THEN
    i = VAL(keys$): IF i <= nchoices AND choices$(i) <> "" THEN result = i
   END IF
   IF keys$ = CHR$(9) OR keys$ = CHR$(0) + CHR$(80) THEN CALL StepChoice(1)
   IF keys$ = CHR$(0) + CHR$(72) THEN CALL StepChoice(-1)
   IF click THEN
    i = ChoiceAt%(mx, my): IF i THEN result = i
    IF i = 0 AND LeaveAt%(mx, my) THEN result = 0
    IF i = 0 AND keys$ = CHR$(13) THEN CALL StepChoice(1)
   END IF
  ELSEIF result = -1 THEN
   i = click OR (LEN(keys$) = 1 AND keys$ >= "1" AND keys$ <= "4")
   IF RevealSpeech%(i) THEN click = 0: keys$ = ""
   CALL AdvanceSpeech(TIMER)
   IF keys$ >= "1" AND keys$ <= "4" AND LEN(keys$) = 1 THEN
    i = VAL(keys$): IF i <= nchoices AND choices$(i) <> "" THEN result = i
   END IF
   IF keys$ = CHR$(9) THEN
    i = ChoiceAt%(mx, my) MOD nchoices + 1
    DO WHILE choices$(i) = "": i = i MOD nchoices + 1: LOOP
    mx = choicex + 8: my = choicetop + (i - 1) * choicestep + choiceh \ 2
    CALL PositionPointer(mx, my)
   END IF
   IF click THEN
    IF carscene AND convperson = 0 AND keys$ = CHR$(13) THEN result = 1
    IF nchoices = 1 AND (keys$ = CHR$(13) OR keys$ = " ") THEN result = 1
    i = ChoiceAt%(mx, my): IF i THEN result = i
   END IF
  END IF
  CALL DrawScene: CALL Present
 LOOP
 modal = 0: click = 0: rightclick = 0: keys$ = "": Pick% = result
END FUNCTION

SUB Say (title$, text$)
 DIM q
 IF convperson THEN lastreply$ = text$
 q = Pick%(title$, text$, "Continue [Enter]", "", "")
END SUB

FUNCTION TalkPick% (person, title$, text$, a$, b$, c$)
 DIM q, id
 IF testing AND testtalk$ <> "" THEN
  testpick = VAL(LEFT$(testtalk$, 1)): testtalk$ = MID$(testtalk$, 2)
 END IF
 ' Let the greeting finish before showing the player's side of the exchange.
 IF lastreply$ = "" THEN CALL Say(title$, text$)
 IF convquit THEN TalkPick% = 0: EXIT FUNCTION
 IF testing AND testforce <> 0 THEN
  ' Test hook: ask any topic the story currently allows, wherever it sits in the menu.
  id = testforce: testforce = 0
  flags(19 + person) = flags(19 + person) OR Pow2%(id - 1)
  TalkPick% = id: EXIT FUNCTION
 END IF
 talkmenu = person
 q = Pick%(title$, "", a$, b$, c$)
 talkmenu = 0
 IF q >= 1 AND q <= 3 THEN
  id = q: IF topiccount THEN id = rowid(q)
  IF choices$(q) = "" THEN id = 0
  IF id THEN flags(19 + person) = flags(19 + person) OR Pow2%(id - 1)
  utterance$ = choices$(q)
  ' You say the question out loud before they answer.
  IF id THEN CALL PlayerSays(utterance$)
  IF convquit THEN id = 0
  q = id
 END IF
 TalkPick% = q
 ' A single scripted question is followed by Leave unless more are queued.
 IF testing THEN testpick = 0
END FUNCTION
