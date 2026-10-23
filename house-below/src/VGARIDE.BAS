REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB CarBackdrop
 IF art <> 0 THEN uglDel art
 art = uglNewBMPEx(UGL.MEM, UGL.8BIT, "VGA\CAR.BMP", BMPOPT.NO332)
 IF art = 0 THEN CALL Finish: PRINT "Missing car opening background.": END
 carscene = -1: introshot = 0
END SUB

SUB LetterBackdrop
 IF art <> 0 THEN uglDel art
 art = uglNewBMPEx(UGL.MEM, UGL.8BIT, "VGA\LETTER.BMP", BMPOPT.NO332)
 IF art = 0 THEN CALL Finish: PRINT "Missing letter opening background.": END
 carscene = -1: introshot = 1
END SUB

SUB DrawOpening (dx, dy)
 uglClear back, 240
 IF introshot = 1 OR introshot = 2 OR introshot = 4 THEN
  ' Four pixels of overscan keep the moving picture inside its viewport.
  uglPut back, dx - 4, dy - 4, art
 ELSE
  uglPut back, 0, 0, art
 END IF
 ' The title and caption remain still while the view of the lap jolts.
 CALL Box(0, 154, 320, 46, 240)
 CALL Box(0, 0, 320, 10, 240)
 CALL Txt(5, 2, "DARK VISIONS / THE HOUSE BELOW", 246)
 CALL Txt(246, 2, "ESC: arrive", 252)
 SELECT CASE introshot
 CASE 1
  CALL Txt(12, 160, "Rain drums on the roof.", 245)
  CALL Txt(12, 170, "Your uncle's letter lies open on your lap.", 245)
 CASE 2
  CALL Txt(12, 160, "The car jolts, and you steady your uncle's letter on your knee.", 245)
 CASE 4
  ' The player's reading panel supplies the text over this same lap view.
 CASE ELSE
  CALL Txt(12, 160, "Rain streaks the window; Ravenhurst is just ahead.", 245)
 END SELECT
 IF introshot = 2 OR introshot = 3 THEN CALL Txt(12, 187, "Click or Enter to continue", 243)
END SUB

FUNCTION ReadLetter%
 DIM q
 ' A solo player portrait, with the same paged text reveal as conversations.
 CALL BeginTalk(-1): introshot = 4: playerline = -1
 q = Pick%("YOU / READING UNCLE FRANK'S LETTER", "My dear nephew, I would be glad to have you at Ravenhurst. There is work here for a chemist. Your uncle, Frank.", "Continue [Enter]", "", "")
 IF q = 1 AND convquit = 0 THEN
  q = Pick%("YOU", "I've never met Uncle Frank. I didn't even know he'd heard I was studying chemistry.", "Continue [Enter]", "", "")
 END IF
 ReadLetter% = (q = 1 AND convquit = 0)
 CALL EndTalk: introshot = 1
 click = 0: rightclick = 0: keys$ = ""
END FUNCTION

FUNCTION IntroWait% (seconds AS SINGLE, advance)
 DIM started AS SINGLE, elapsed AS SINGLE
 IntroWait% = 0
 ' A pending cancellation also works in the isolated DOS harness.
 IF keys$ = CHR$(27) OR rightclick THEN EXIT FUNCTION
 IntroWait% = -1
 IF testing THEN EXIT FUNCTION
 started = TIMER
 DO
  CALL Poll
  IF keys$ = CHR$(27) OR rightclick THEN IntroWait% = 0: EXIT FUNCTION
  IF advance AND click THEN click = 0: keys$ = "": EXIT FUNCTION
  CALL Present
  elapsed = TIMER - started
  IF elapsed < 0 THEN elapsed = elapsed + 86400!
 LOOP WHILE elapsed < seconds
END FUNCTION

FUNCTION CarReveal%
 DIM i, dx, dy, level, oldmodal
 CarReveal% = 0: oldmodal = modal: modal = -1: hover = 0
 introshot = 2
 ' One brief bump, settling back to the original view; no palette flashing.
 FOR i = 0 TO 9
  SELECT CASE i
  CASE 0: dx = 2: dy = -2
  CASE 1: dx = -3: dy = 2
  CASE 2: dx = 3: dy = -1
  CASE 3: dx = -2: dy = 1
  CASE 4: dx = 2: dy = 0
  CASE 5: dx = -1: dy = -1
  CASE 6: dx = 1: dy = 1
  CASE 7: dx = -1: dy = 0
  CASE 8: dx = 0: dy = 1
  CASE 9: dx = 0: dy = 0
  END SELECT
  CALL DrawOpening(dx, dy)
  IF IntroWait%(.055, 0) = 0 THEN GOTO RevealDone
 NEXT
 IF IntroWait%(1.8, -1) = 0 THEN GOTO RevealDone
 FOR level = 7 TO 0 STEP -1
  CALL DoorShade(level)
  IF IntroWait%(.04, 0) = 0 THEN GOTO RevealDone
 NEXT
 CALL CarBackdrop: introshot = 3: CALL DrawOpening(0, 0)
 FOR level = 0 TO 8
  CALL DoorShade(level)
  IF IntroWait%(.04, 0) = 0 THEN GOTO RevealDone
 NEXT
 IF IntroWait%(2!, -1) = 0 THEN GOTO RevealDone
 CarReveal% = -1
RevealDone:
 ' Restore the palette even if Escape was pressed halfway through a fade.
 CALL DoorShade(8)
 introshot = 0: modal = oldmodal: click = 0: rightclick = 0: keys$ = ""
END FUNCTION

SUB PlayerSays (text$)
 playerline = -1
 CALL Say("YOU", text$)
 playerline = 0
END SUB

SUB Opening
 DIM q, skipped
 CALL LetterBackdrop
 q = Pick%("THE ROAD TO RAVENHURST", "", "Begin journey [Enter]", "", "")
 skipped = (q <> 1)
 IF q = 1 THEN
  skipped = (ReadLetter% = 0)
 END IF
 IF skipped = 0 THEN
  skipped = (CarReveal% = 0)
 END IF
 IF skipped = 0 THEN
  ' The coat and racing sleeve are visible from the back seat.
  flags(29) = 1
  CALL BeginTalk(8)
  CALL Reply(0, "COACHMAN", "Last bend before Ravenhurst, sir. You have business with Doctor Mahler?")
  IF convquit = 0 THEN CALL PlayerSays("Doctor Mahler is my uncle. I've just finished college. I'm to be his apprentice.")
  IF convquit = 0 THEN CALL Reply(3, "COACHMAN", "Fresh from college, then. I hope he has a warm room ready as well as work. Keep that letter handy; James will want it at the door.")
  IF convquit = 0 THEN CALL CoachmanTalk
  IF convquit = 0 THEN CALL Reply(0, "COACHMAN", "Ravenhurst. That's us. I'll pull up by the gate.")
  skipped = convquit
  CALL EndTalk
 END IF
 carscene = 0: introshot = 0: CALL EnterRoom(1)
 IF skipped = 0 THEN CALL Speak(8, "ARRIVAL", "Mind the step. There you are. Best get inside before that letter turns to pulp. James will answer the door.")
END SUB

SUB CoachmanTalk
 DIM q, greeting$
 IF selected THEN
  IF selected = 1 THEN
   CALL Reply(0, "COACHMAN", "That is for James, sir. Best keep it dry. Knock at the lit front door; he will see you in.")
  ELSE
   CALL Reply(0, "COACHMAN", "Best ask inside about that, sir. I only brought the car.")
  END IF
  selected = 0: EXIT SUB
 END IF
 greeting$ = "Best get inside out of the rain, sir. James will answer the front door."
 IF carscene THEN greeting$ = "There are the house lights, through the trees."
 DO
  q = ContextPick%(8, "COACHMAN", greeting$)
  SELECT CASE q
  CASE 1
   flags(28) = 1
   CALL Reply(3, "ARTHUR PIKE", "Pike. Arthur Pike. I used to drive horses. Better company than a motorcar, though no easier to start on a wet morning.")
  CASE 2
   CALL Reply(0, "COACHMAN", "He used to come out and meet the car himself. These days it is usually James.")
  CASE 3
   CALL Reply(0, "COACHMAN", "A little while. I'll see you safely in, then have a look at the engine. It has been complaining since the village.")
  CASE 4
   CALL Reply(1, "COACHMAN", "Once. Burgundy and gold. I kept the colours when I gave up the saddle.")
  CASE 5
   CALL Reply(3, "COACHMAN", "A horse turns an ear when you speak. This thing only answers when I haven't asked it anything.")
  CASE 6
   CALL Reply(1, "COACHMAN", "I couldn't say. I was watching you get down. Ask James when he lets you in.")
  END SELECT
 LOOP WHILE q <> 0 AND convquit = 0
END SUB

SUB FrontDoor
 DIM q
 CALL BeginTalk(1)
 CALL Reply(0, "JAMES / AT THE DOOR", "Good evening, sir. Doctor Mahler is expecting a guest. May I see your letter?")
 IF convquit = 0 THEN
  q = 1
  IF selected <> 1 THEN
   playerline = -1
   q = Pick%("AT THE FRONT DOOR", "", "Show Uncle Frank's invitation", "Not just yet [Esc]", "")
   playerline = 0
  END IF
  IF q = 1 AND convquit = 0 THEN
   CALL PlayerSays("My uncle invited me. Here is his letter.")
   IF convquit = 0 THEN
    flags(1) = 1: selected = 0
    CALL Reply(3, "JAMES / AT THE DOOR", "His nephew. Yes, of course. Come in, sir. Your room is ready.")
   END IF
  END IF
 END IF
 CALL EndTalk
END SUB
