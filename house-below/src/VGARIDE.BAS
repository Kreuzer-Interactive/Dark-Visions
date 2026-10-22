REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB CarBackdrop
 IF art <> 0 THEN uglDel art
 art = uglNewBMPEx(UGL.MEM, UGL.8BIT, "VGA\CAR.BMP", BMPOPT.NO332)
 IF art = 0 THEN CALL Finish: PRINT "Missing car opening background.": END
 carscene = -1
END SUB

SUB PlayerSays (text$)
 playerline = -1
 CALL Say("YOU", text$)
 playerline = 0
END SUB

SUB Opening
 DIM q, skipped
 CALL CarBackdrop
 q = Pick%("THE ROAD TO RAVENHURST", "", "Begin journey [Enter]", "Skip to arrival [Esc]", "")
 skipped = (q <> 1)
 IF q = 1 THEN
  ' The coat and racing sleeve are visible from the back seat.
  flags(29) = 1
  CALL BeginTalk(8)
  CALL Reply(0, "COACHMAN", "Last bend before Ravenhurst, sir. You have business with Doctor Mahler?")
  IF convquit = 0 THEN CALL PlayerSays("He is my uncle. I graduated three weeks ago. His letter offered me an apprenticeship; he says my chemistry will be useful.")
  IF convquit = 0 THEN CALL Reply(3, "COACHMAN", "Fresh from college, then. I hope he has a warm room ready as well as work. Keep that letter handy; James will want it at the door.")
  IF convquit = 0 THEN CALL CoachmanTalk
  IF convquit = 0 THEN CALL Reply(0, "COACHMAN", "Ravenhurst. That's us. I'll pull up by the gate.")
  skipped = convquit
  CALL EndTalk
 END IF
 carscene = 0: CALL EnterRoom(1)
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
