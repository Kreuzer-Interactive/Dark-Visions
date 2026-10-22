REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

FUNCTION Speaking%
 Speaking% = (convperson <> 0 AND talkmenu = 0 AND speechcount < LEN(body$))
END FUNCTION

SUB StartSpeech (stamp AS SINGLE)
 speechclock = stamp: speechcredit = 0: speechdelay = .028
 speechcount = LEN(body$)
 IF convperson AND talkmenu = 0 AND testing = 0 THEN speechcount = 0
END SUB

SUB AdvanceSpeech (stamp AS SINGLE)
 DIM elapsed AS SINGLE, ch$
 IF NOT Speaking% THEN EXIT SUB
 elapsed = stamp - speechclock
 IF elapsed < 0 THEN elapsed = elapsed + 86400!
 speechclock = stamp
 ' A stall or a backgrounded window must not dump the entire line at once.
 IF elapsed > .25 THEN elapsed = .25
 speechcredit = speechcredit + elapsed
 DO WHILE speechcredit >= speechdelay AND speechcount < LEN(body$)
  speechcredit = speechcredit - speechdelay
  speechcount = speechcount + 1: ch$ = MID$(body$, speechcount, 1)
  speechdelay = .028
  IF ch$ = " " THEN speechdelay = .01
  IF INSTR(",;:", ch$) THEN speechdelay = .14
  IF INSTR(".!?", ch$) THEN speechdelay = .26
 LOOP
END SUB

FUNCTION RevealSpeech% (requested)
 RevealSpeech% = 0
 IF requested AND Speaking% THEN
  speechcount = LEN(body$): speechcredit = 0
  RevealSpeech% = -1
 END IF
END FUNCTION

SUB RevealWrap (x, y, text$, wide, shown)
 DIM i, first, wordstart, n, yy
 first = 1: wordstart = 1: yy = y
 ' Wrap the complete sentence, then reveal fixed positions. Partial words
 ' never jump to the following line as the next letters arrive.
 FOR i = 1 TO LEN(text$) + 1
  IF MID$(text$, i, 1) = " " OR i > LEN(text$) THEN
   IF Tw%(MID$(text$, first, i - first)) > wide AND wordstart > first THEN
    n = wordstart - first - 1
    IF n > shown - first + 1 THEN n = shown - first + 1
    IF n > 0 THEN CALL Txt(x, yy, MID$(text$, first, n), 247)
    yy = yy + 10: first = wordstart
   END IF
   wordstart = i + 1
  END IF
 NEXT
 n = LEN(text$) - first + 1
 IF n > shown - first + 1 THEN n = shown - first + 1
 IF n > 0 THEN CALL Txt(x, yy, MID$(text$, first, n), 247)
END SUB

SUB DrawSpeech
 DIM tip, y, span, s$
 ' A speech-tail and adjacent name attach the text to the correct portrait.
 tip = 272: IF talkmenu OR playerline THEN tip = 48
 IF carscene THEN tip = 320 - tip
 FOR y = 120 TO 132
  span = (y - 120) \ 2
  uglLine back, tip - span, y, tip + span, y, 241
 NEXT
 uglLine back, tip - 6, 132, tip, 120, 245
 uglLine back, tip, 120, tip + 6, 132, 245
 span = 81: IF talkmenu THEN span = 107
 CALL Box(8, 133, 304, span, 241)
 uglLine back, 8, 132, tip - 6, 132, 245
 uglLine back, tip + 6, 132, 311, 132, 245
 s$ = FaceName$(convperson): IF talkmenu OR playerline THEN s$ = "YOU"
 IF carscene AND talkmenu = 0 THEN
  IF playerline THEN s$ = "YOU / BACK SEAT" ELSE s$ = s$ + " / AT THE WHEEL"
 END IF
 CALL Txt(18, 140, s$, 246)
 IF talkmenu THEN
  IF topiccount THEN CALL TopicHeader ELSE CALL Txt(18, 155, "Choose a reply. Blue = already asked.", 252)
 ELSE
  CALL RevealWrap(18, 153, body$, 284, speechcount)
 END IF
END SUB
