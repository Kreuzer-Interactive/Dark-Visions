REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB CheckSpeech
 DIM before, consumed, valid, i, x, y, oldpick, mask, q, s$
 DIM expected AS LONG, actual AS LONG, savedBack AS LONG, full AS LONG
 oldpick = testpick: mask = flags(20)
 CALL BeginTalk(1)
 body$ = "A patient voice should arrive a little at a time."
 testing = 0: CALL StartSpeech(100!)
 CALL Check(speechcount = 0 AND Speaking%, "speech starts unrevealed")
 CALL AdvanceSpeech(100.06!): before = speechcount
 CALL AdvanceSpeech(100.12!)
 CALL Check(before > 0 AND speechcount > before AND speechcount < LEN(body$), "speech reveals progressively without waiting or blocking input")
 before = speechcount: CALL AdvanceSpeech(100.12!)
 CALL Check(speechcount = before, "repeated drawing without elapsed time adds no letters")
 body$ = "A, B. After the pause."
 CALL StartSpeech(200!): CALL AdvanceSpeech(200.06!)
 before = speechcount: CALL AdvanceSpeech(200.12!)
 CALL Check(before = 2 AND speechcount = 2, "comma adds a natural pause")
 CALL AdvanceSpeech(200.3!)
 CALL Check(speechcount > before, "letters resume after punctuation")
 consumed = RevealSpeech%(-1)
 CALL Check(consumed AND speechcount = LEN(body$) AND Speaking% = 0, "first activation reveals the whole line and is consumed")
 CALL Check(RevealSpeech%(-1) = 0, "second activation is available to continue")
 CALL StartSpeech(86399.94!): CALL AdvanceSpeech(.02!)
 CALL Check(speechcount > 0 AND speechcount < LEN(body$), "speech timing survives midnight")
 CALL StartSpeech(300!): CALL AdvanceSpeech(350!)
 CALL Check(speechcount < LEN(body$), "a stalled frame does not skip an entire speech")
 ' Long replies split into three-line pages: contiguous, each page typed in turn, the last ends the text.
 body$ = "At first I could read. Then I heard someone reading ahead of me. Improvement did not mean he had permission to keep dosing us. I asked him to stop and he said the notes would explain, but the notes never did."
 convperson = 1: talkmenu = 0: CALL StartSpeech(900!)
 before = PageEnd%
 CALL Check(PageStart% = 1 AND before < LEN(body$) AND Speaking%, "a long reply starts on its first three-line page")
 consumed = NextPage%
 CALL Check(consumed AND PageStart% > before AND PageStart% <= before + 2 AND speechcount = PageStart% - 1, "the next page continues exactly where the last ended")
 DO WHILE NextPage%: LOOP
 CALL Check(PageEnd% = LEN(body$) AND OnLastPage% AND NextPage% = 0, "the last page ends the text and cannot advance further")
 talkmenu = 1: CALL StartSpeech(400!)
 CALL Check(Speaking% = 0, "question menus remain immediate")
 talkmenu = 0: convperson = 0: CALL StartSpeech(400!)
 CALL Check(speechcount = LEN(body$) AND Speaking% = 0, "ordinary puzzle and save dialogs remain immediate")
 convperson = 1
 s$ = "A single unusuallylongword arrives slowly. The words keep their place while the speaker continues."
 full = uglNew(UGL.MEM, UGL.8BIT, 320, 80)
 IF full = 0 THEN
  CALL Check(0, "allocate stable wrapping fixture")
 ELSE
  savedBack = back: back = full: uglClear back, 240
  CALL Wrap(12, 4, s$, 247, 150)
  back = savedBack: valid = -1
  FOR i = 1 TO LEN(s$) STEP 7
   uglClear back, 240: CALL RevealWrap(12, 4, s$, 150, i)
   FOR y = 0 TO 79
    FOR x = 0 TO 180
     actual = uglPGet(back, x, y): expected = uglPGet(full, x, y)
     IF actual = 247 AND expected <> 247 THEN valid = 0
    NEXT
   NEXT
  NEXT
  CALL Check(valid, "letters keep their final wrapped positions during reveal")
  uglClear back, 240: CALL RevealWrap(12, 4, s$, 150, LEN(s$))
  valid = -1
  FOR y = 0 TO 79
   FOR x = 0 TO 180
    IF uglPGet(back, x, y) <> uglPGet(full, x, y) THEN valid = 0
   NEXT
  NEXT
  CALL Check(valid, "complete revealed text matches the normal font wrapper")
  uglDel full
 END IF
 testing = -1: testpick = 0
 utterance$ = "THIS OLD QUESTION SHOULD NOT APPEAR"
 CALL Reply(1, "JAMES", "I should have opened more than the front door.")
 modal = -1: CALL DrawScene: CALL DumpFrame(30)
 CALL Check(uglPGet(back, 276, 139) = 254 AND uglPGet(back, 44, 139) <> 254, "cream tail connects their reply to the right-hand portrait")
 valid = -1
 FOR y = 178 TO 192
  FOR x = 18 TO 290
   IF uglPGet(back, x, y) <> 254 THEN valid = 0
  NEXT
 NEXT
 CALL Check(valid, "answer shows no repeated You said question")
 testing = 0: CALL StartSpeech(500!): CALL AdvanceSpeech(500.2!)
 CALL DrawScene: CALL DumpFrame(31)
 CALL Check(speechcount > 0 AND speechcount < LEN(body$), "native preview captures a partially spoken line")
 testing = -1
 q = TalkPick%(1, "JAMES", "Greeting", "Who is downstairs?", "My invitation", "The clock")
 talkmenu = 1: CALL SetChoices: CALL PrepareFaces: CALL DrawScene: CALL DumpFrame(32)
 CALL Check(body$ = "" AND uglPGet(back, 44, 139) = 253 AND uglPGet(back, 276, 139) <> 253 AND uglPGet(back, 150, 153) = 253, "your turn is a blue panel with its tail on the left portrait")
 CALL EndTalk: modal = 0: flags(20) = mask: testpick = oldpick
 CALL Check(Speaking% = 0 AND speechcount = 0, "leaving a conversation clears reveal state")
END SUB
