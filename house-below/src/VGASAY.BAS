REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'
REM $STATIC
DIM SHARED spoff(1 TO 40), splen(1 TO 40), splines, sppage, sppages
REM $DYNAMIC

FUNCTION Speaking%
 Speaking% = (convperson <> 0 AND talkmenu = 0 AND speechcount < speechend)
END FUNCTION

' Wrap body$ once into lines of at most 272 pixels (the same greedy rule RevealWrap uses) and
' group them into pages of three lines; one page fits the conversation panel.
SUB SpeechLayout
 DIM i, first, wordstart
 splines = 0: first = 1: wordstart = 1
 FOR i = 1 TO LEN(body$) + 1
  IF MID$(body$, i, 1) = " " OR i > LEN(body$) THEN
   IF Tw%(MID$(body$, first, i - first)) > 272 AND wordstart > first THEN
    splines = splines + 1
    IF splines <= 40 THEN spoff(splines) = first: splen(splines) = wordstart - first - 1
    first = wordstart
   END IF
   wordstart = i + 1
  END IF
 NEXT
 splines = splines + 1
 IF splines <= 40 THEN spoff(splines) = first: splen(splines) = LEN(body$) - first + 1
 IF splines > 40 THEN splines = 40
 sppages = (splines + 2) \ 3
 sppage = 1
END SUB

FUNCTION PageStart%
 PageStart% = spoff((sppage - 1) * 3 + 1)
END FUNCTION

FUNCTION PageEnd%
 DIM last
 last = (sppage - 1) * 3 + 3
 IF last > splines THEN last = splines
 PageEnd% = spoff(last) + splen(last) - 1
END FUNCTION

FUNCTION OnLastPage%
 OnLastPage% = (sppage >= sppages)
END FUNCTION

' Advance to the next three-line page; 0 when the speech is on its last page.
FUNCTION NextPage%
 NextPage% = 0
 IF sppage >= sppages THEN EXIT FUNCTION
 sppage = sppage + 1
 speechcount = PageStart% - 1: speechend = PageEnd%
 speechcredit = 0
 NextPage% = -1
END FUNCTION

SUB StartSpeech (stamp AS SINGLE)
 speechclock = stamp: speechcredit = 0: speechdelay = .028
 CALL SpeechLayout
 speechcount = LEN(body$): speechend = LEN(body$)
 IF convperson AND talkmenu = 0 AND testing = 0 THEN
  speechcount = PageStart% - 1: speechend = PageEnd%
 END IF
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
 DO WHILE speechcredit >= speechdelay AND speechcount < speechend
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
  speechcount = speechend: speechcredit = 0
  RevealSpeech% = -1
 END IF
END FUNCTION

SUB RevealWrapInk (x, y, text$, wide, shown, ink)
 DIM i, first, wordstart, n, yy
 first = 1: wordstart = 1: yy = y
 ' Wrap the complete sentence, then reveal fixed positions. Partial words
 ' never jump to the following line as the next letters arrive.
 FOR i = 1 TO LEN(text$) + 1
  IF MID$(text$, i, 1) = " " OR i > LEN(text$) THEN
   IF Tw%(MID$(text$, first, i - first)) > wide AND wordstart > first THEN
    n = wordstart - first - 1
    IF n > shown - first + 1 THEN n = shown - first + 1
    IF n > 0 THEN CALL Txt(x, yy, MID$(text$, first, n), ink)
    yy = yy + 10: first = wordstart
   END IF
   wordstart = i + 1
  END IF
 NEXT
 n = LEN(text$) - first + 1
 IF n > shown - first + 1 THEN n = shown - first + 1
 IF n > 0 THEN CALL Txt(x, yy, MID$(text$, first, n), ink)
END SUB

SUB RevealWrap (x, y, text$, wide, shown)
 CALL RevealWrapInk(x, y, text$, wide, shown, 247)
END SUB

' Pixel-art rounded rectangle (2 px corner cut) from three filled rectangles.
SUB RRect (x0, y0, x1, y1, c)
 uglRectF back, x0 + 2, y0, x1 - 2, y1, CLNG(c)
 uglRectF back, x0 + 1, y0 + 1, x1 - 1, y1 - 1, CLNG(c)
 uglRectF back, x0, y0 + 2, x1, y1 - 2, CLNG(c)
END SUB

' The conversation panel: soft shadow, 1 px gold outline, black fill.
SUB DrawPanel (edge)
 CALL RRect(pnX0 + 1, pnY0 + 2, pnX1 + 1, pnY1 + 2, 242)
 CALL RRect(pnX0, pnY0, pnX1, pnY1, CLNG(edge))
 CALL RRect(pnX0 + 1, pnY0 + 1, pnX1 - 1, pnY1 - 1, 240)
END SUB

' Speech tail rising from the panel's top edge at tipx, pointing at the speaker's chin.
SUB DrawTail (tipx, edge)
 DIM k, half, y
 FOR k = 0 TO 9
  half = k * 3 \ 4 + 1: y = pnY0 - 9 + k
  uglLine back, tipx - half, y, tipx + half, y, 240
  IF k = 0 THEN
   uglLine back, tipx - half, y, tipx + half, y, CLNG(edge)
  ELSE
   uglPSet back, tipx - half, y, CLNG(edge)
   uglPSet back, tipx + half, y, CLNG(edge)
  END IF
 NEXT
 ' Open the panel outline under the tail so it flows into the panel.
 uglRectF back, tipx - 6, pnY0, tipx + 6, pnY0 + 1, 240
END SUB

FUNCTION MenuMode%
 MenuMode% = (convperson <> 0 AND (talkmenu <> 0 OR nchoices > 1))
END FUNCTION

FUNCTION LeaveAt% (x, y)
 LeaveAt% = 0
 IF talkmenu = 0 THEN EXIT FUNCTION
 IF x >= pnX1 - 14 - Tw%("Leave [Esc]") AND x <= pnX1 - 6 AND y >= pnY0 + 3 AND y <= pnY0 + 14 THEN LeaveAt% = -1
END FUNCTION

SUB DrawTickets
 DIM i, y, x0, x1, hv, nm$, none
 x0 = choicex: x1 = choicex + choicew - 1
 none = -1
 FOR i = 1 TO nchoices
  IF choices$(i) <> "" THEN
   none = 0
   y = choicetop + (i - 1) * choicestep
   hv = (ChoiceAt%(mx, my) = i)
   nm$ = LTRIM$(STR$(i))
   IF hv THEN
    uglRectF back, x0, y, x1, y + 9, 254
    uglRectF back, x0 + 1, y + 1, x1 - 1, y + 8, 254
    uglRectF back, x0 + 1, y + 1, x0 + 15, y + 8, 249
    uglLine back, x1 - 8, y + 2, x1 - 8, y + 6, 249
    uglLine back, x1 - 7, y + 3, x1 - 7, y + 5, 249
    uglPSet back, x1 - 6, y + 4, 249
    CALL Txt(x0 + 6, y + 2, nm$, 254)
    CALL Txt(x0 + 21, y + 2, choices$(i), 240)
   ELSE
    uglRectF back, x0, y, x1, y + 9, 244
    uglRectF back, x0 + 1, y + 1, x1 - 1, y + 8, 243
    uglRectF back, x0 + 1, y + 1, x0 + 15, y + 8, 242
    CALL Txt(x0 + 6, y + 2, nm$, 246)
    CALL Txt(x0 + 21, y + 2, choices$(i), 254)
   END IF
   uglPSet back, x0 + 16, y + 1, 240: uglPSet back, x0 + 16, y + 3, 240: uglPSet back, x0 + 16, y + 5, 240: uglPSet back, x0 + 16, y + 7, 240
  END IF
 NEXT
 IF none AND talkmenu THEN CALL Txt(pnX0 + 11, choicetop + 3, "Nothing more to ask right now.", 244)
END SUB

SUB DrawSpeech
 DIM youtalk, nm$, nx, ps, pe, shown, lv
 ' Black bubble, white outline. Only the tail and the gold name header say who is speaking.
 youtalk = (talkmenu <> 0 OR playerline <> 0 OR MenuMode%)
 CALL DrawPanel(246)
 IF youtalk THEN CALL DrawTail(44, 246) ELSE CALL DrawTail(276, 246)
 nm$ = FaceName$(convperson): IF youtalk THEN nm$ = "YOU"
 IF introshot = 4 THEN nm$ = heading$
 IF youtalk THEN nx = pnX0 + 11 ELSE nx = pnX1 - 11 - Tw%(nm$)
 CALL Txt(nx, pnY0 + 6, nm$, 246)
 uglLine back, nx, pnY0 + 15, nx + Tw%(nm$) - 1, pnY0 + 15, 244
 IF talkmenu THEN
  lv = LeaveAt%(mx, my)
  nx = pnX1 - 11 - Tw%("Leave [Esc]")
  IF lv THEN CALL Txt(nx, pnY0 + 6, "Leave [Esc]", 254) ELSE CALL Txt(nx, pnY0 + 6, "Leave [Esc]", 244)
 END IF
 IF MenuMode% THEN
  CALL DrawTickets
 ELSE
  ps = PageStart%: pe = PageEnd%
  shown = speechcount - ps + 1: IF shown < 0 THEN shown = 0
  CALL RevealWrapInk(pnX0 + 11, pnY0 + 20, MID$(body$, ps, pe - ps + 1), 272, shown, 254)
  IF NOT Speaking% THEN
   uglLine back, pnX1 - 14, pnY1 - 8, pnX1 - 9, pnY1 - 8, 246
   uglLine back, pnX1 - 13, pnY1 - 7, pnX1 - 10, pnY1 - 7, 246
   uglLine back, pnX1 - 12, pnY1 - 6, pnX1 - 11, pnY1 - 6, 246
  END IF
 END IF
END SUB
