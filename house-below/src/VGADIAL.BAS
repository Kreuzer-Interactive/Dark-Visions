REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB SetChoices
 choicex = 21: choicew = 278: choicetop = 100: choicestep = 15: choiceh = 14
 IF convperson THEN
  choicex = 12: choicew = 296: choicestep = 16: choiceh = 14
  choicetop = 186
  IF talkmenu THEN choicetop = 138
 ELSEIF talkmenu THEN
  choicetop = 85
 END IF
 IF carscene AND convperson = 0 THEN choicex = 12: choicew = 296: choicetop = 186: choicestep = 16
END SUB

FUNCTION ChoiceAt% (x, y)
 DIM rown
 ChoiceAt% = 0
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
  ' Transparent busts overlap the scene and the unframed dialogue strip.
  uglClear back, 240
  uglPut back, 0, 0, art
  CALL Box(0, 0, 320, 10, 240)
  IF carscene THEN
   CALL Txt(5, 2, "THE ROAD TO RAVENHURST", 245)
   CALL Txt(246, 2, "ESC: arrive", 252)
   CALL Box(0, 100, 320, 100, 240)
  ELSE
   CALL Txt(5, 2, rt$(room), 245)
   CALL Box(0, 78, 320, 122, 240)
   CALL DrawFaces
  END IF
  CALL DrawSpeech
 ELSEIF carscene THEN
  uglClear back, 240: uglPut back, 0, 0, art
  CALL Box(0, 0, 320, 10, 240)
  CALL Txt(5, 2, "DARK VISIONS / THE HOUSE BELOW", 246)
  CALL Txt(12, 160, "Burgundy and gold at the wheel. Rain on the roof.", 245)
 ELSE
  CALL Box(12, 12, 296, 139, 240)
  uglRect back, 12, 12, 307, 150, 245
  CALL Txt(21, 21, heading$, 246)
  uglLine back, 21, 33, 298, 33, 243
  CALL Wrap(21, 41, body$, 247, 276)
  IF talkmenu THEN CALL Txt(21, 74, "Blue = already asked. Ask again any time.", 252)
 END IF
 FOR i = 1 TO nchoices
  IF choices$(i) <> "" THEN
  y = choicetop + (i - 1) * choicestep
  col = 241: IF ChoiceAt%(mx, my) = i THEN col = 250
  CALL Box(choicex, y, choicew, choiceh, col)
  s$ = LTRIM$(STR$(i)) + ". " + choices$(i)
  IF convperson AND talkmenu = 0 THEN s$ = choices$(i)
  IF Speaking% THEN s$ = "Show full line [Enter]"
  col = 246
  IF talkmenu AND i <= 3 THEN
   IF topiccount THEN
    IF flags(19 + talkmenu) AND Pow2%(rowid(i) - 1) THEN col = 252
    IF rowsource$(i) <> "" THEN s$ = LTRIM$(STR$(i)) + ". * " + choices$(i)
   ELSE
    IF flags(19 + talkmenu) AND Pow2%(i - 1) THEN col = 252
   END IF
  END IF
  CALL Txt(choicex + 4, y + (choiceh - 7) \ 2, s$, col)
  END IF
 NEXT
 hover = ChoiceAt%(mx, my)
END SUB

FUNCTION Pick% (title$, text$, a$, b$, c$)
 DIM result, i
 heading$ = title$: body$ = text$
 choices$(1) = a$: choices$(2) = b$: choices$(3) = c$
 nchoices = 1: IF b$ <> "" THEN nchoices = 2
 IF c$ <> "" THEN nchoices = 3
 IF talkmenu THEN choices$(4) = "Goodbye [Esc]": nchoices = 4
 IF talkmenu <> 0 AND topiccount > 0 THEN CALL FillTopics(topicpage)
 CALL SetChoices
 IF convperson THEN CALL PrepareFaces
 CALL StartSpeech(TIMER)
 IF testing THEN
  IF convperson THEN
   IF TextLines%(body$, 284) > 6 THEN CALL Check(0, "speech overflows portrait panel: " + title$)
   FOR i = 1 TO nchoices
    IF Tw%(choices$(i)) > choicew - 34 THEN CALL Check(0, "topic overflows portrait panel: " + choices$(i))
   NEXT
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
   result = 0
   IF convperson THEN convquit = -1
  END IF
  IF result = -1 THEN
   i = click OR (LEN(keys$) = 1 AND keys$ >= "1" AND keys$ <= "4")
   IF RevealSpeech%(i) THEN click = 0: keys$ = ""
   CALL AdvanceSpeech(TIMER)
  END IF
  IF result = -1 AND talkmenu <> 0 AND topiccount > 0 THEN
   IF PageInput% THEN click = 0: keys$ = ""
  END IF
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
  CALL DrawScene: CALL Present
 LOOP
 IF talkmenu AND result = 4 THEN result = 0
 modal = 0: click = 0: rightclick = 0: keys$ = "": Pick% = result
END FUNCTION

SUB Say (title$, text$)
 DIM q, button$
 button$ = "Continue [Enter]"
 IF convperson THEN
  lastreply$ = text$
  IF utterance$ <> "" THEN button$ = "Back to questions [Enter]"
 END IF
 q = Pick%(title$, text$, button$, "", "")
END SUB

FUNCTION TalkPick% (person, title$, text$, a$, b$, c$)
 DIM q, id
 IF testing AND testtalk$ <> "" THEN
  DO WHILE LEFT$(testtalk$, 1) = ">" OR LEFT$(testtalk$, 1) = "<"
   IF LEFT$(testtalk$, 1) = ">" THEN CALL FillTopics(topicpage + 1) ELSE CALL FillTopics(topicpage - 1)
   testtalk$ = MID$(testtalk$, 2)
  LOOP
  testpick = VAL(LEFT$(testtalk$, 1)): testtalk$ = MID$(testtalk$, 2)
 END IF
 ' Let the greeting finish before showing the player's side of the exchange.
 IF lastreply$ = "" THEN CALL Say(title$, text$)
 IF convquit THEN TalkPick% = 0: EXIT FUNCTION
 talkmenu = person
 q = Pick%(title$, "", a$, b$, c$)
 IF q >= 1 AND q <= 3 THEN
  id = q: IF topiccount THEN id = rowid(q)
  IF choices$(q) = "" THEN id = 0
  IF id THEN flags(19 + person) = flags(19 + person) OR Pow2%(id - 1)
  utterance$ = choices$(q): q = id
 END IF
 talkmenu = 0
 TalkPick% = q
 ' A single scripted question is followed by Goodbye unless more are queued.
 IF testing THEN testpick = 0
END FUNCTION

