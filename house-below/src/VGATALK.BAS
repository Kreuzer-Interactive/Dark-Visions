REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB Talk (n)
 DIM q
 CALL BeginTalk(n)
 IF n = 8 THEN CALL CoachmanTalk: CALL EndTalk: EXIT SUB
 IF n = 2 OR n = 5 THEN faceMood = 1
 IF n = 4 OR n = 6 THEN faceMood = 2
 IF n = 1 AND room = 1 THEN CALL FrontDoor: EXIT SUB
 IF n = 1 AND selected = 1 THEN
  flags(1) = 1: selected = 0
  CALL Reply(3, "JAMES", "Yes, sir. Everything is in order. Your room is upstairs.")
  CALL EndTalk: EXIT SUB
 END IF
 DO
 SELECT CASE n
 CASE 1
  q = ContextPick%(n, "JAMES / BUTLER", "Can I be of assistance, sir?")
  IF q = 1 THEN CALL Reply(0, "JAMES", "That is for Doctor Mahler to explain. He asked me to have your room ready.")
  IF q = 2 THEN CALL JamesPatients
  IF q = 3 THEN CALL Reply(0, "JAMES", "I am afraid it will not tell you the hour, sir. Your watch will serve you better.")
  IF q = 4 THEN CALL Reply(0, "JAMES", "Mr. Hart is often in the library. Ada tends the garden. You may meet the others in due course.")
  IF q = 5 THEN CALL Reply(0, "JAMES", "Your room is upstairs. If you prefer to wait below, the library is on this floor.")
  IF q = 6 THEN CALL Reply(0, "JAMES", "The doctor is occupied, sir. I will let you know when he is ready.")
 CASE 2
  q = ContextPick%(n, "ELIAS HART", "The words are mine again, some of the time. Tell me you came to listen.")
  IF q = 1 OR q = 3 OR q = 4 THEN
   IF flags(3) OR inv(10) THEN
    IF inv(6) THEN
     CALL Reply(2, "ELIAS", "You have the ward key. Speak to Clara about the air and the crossing. Bring us out together.")
    ELSE
     faceMood = 3: youMood = 3
     CALL Give(6, "Take the ward key. Bring our names, not just the doctor's account of us. Clara will tell you what must be made safe.")
    END IF
   ELSE
    CALL Reply(2, "ELIAS", "His study drawer has the truth. It is locked with a little spring catch. Read it before asking me to trust another Mahler.")
   END IF
   CALL Learn(kRecords, 5)
  END IF
  IF q = 2 THEN CALL Reply(1, "ELIAS", "At first I could read. Then I heard someone reading ahead of me. Improvement did not mean he had permission to keep dosing us.")
  IF q = 5 THEN
   CALL Reply(1, "ELIAS", "Your uncle called it Preparation R. It helped at first. Then the words began to arrive in a voice that was not mine. I asked him to stop giving it to me.")
   CALL Learn(kPreparation, 5): CALL Learn(kPatients, 5)
  END IF
  IF q = 6 THEN
   CALL Reply(2, "ELIAS", "Leave. All four of us. I kept the ward key, but an open door alone will not make it safe. Read the study records first. Then speak to Clara; she knows what we need.")
   CALL Learn(kWardKey, 5): CALL Learn(kRescue, 5): CALL Learn(kRecords, 5)
  END IF
 CASE 3
  q = ContextPick%(n, "ADA FINCH / GARDENER", "Plants tell you when they need something. People do too, if you listen.")
  IF q = 1 THEN
   CALL Reply(0, "ADA", "Follow the path to the boathouse. There is a boat and a coil of rope there. A damaged reservoir crossing joins it from below the house. That bridge needs a safety line before anyone uses it.")
   CALL Learn(kCrossing, 9)
  END IF
  IF q = 2 THEN
   CALL Reply(0, "ADA", "Take my oil can. The generator bearings are dry. A spare fuse was locked in the doctor's study safe. The motor drives the ventilation fan below the house.")
   CALL Learn(kFan, 9)
  END IF
  IF q = 3 THEN CALL Reply(3, "ADA", "Someone had to keep a path clear. I hoped James would open the door. I am glad you came through it.")
  IF q = 4 THEN
   CALL Reply(0, "ADA", "Down to the lake. I keep the steps clear as far as the boathouse. Beyond the water is the village. On a clear morning you can hear the church bell.")
   CALL Learn(kLake, 9)
  END IF
  IF q = 5 THEN
   CALL Reply(0, "ADA", "The plants, mostly. And the old generator when James forgets it. My oil can is over there; its bearings must never run dry. Even a machine needs someone to notice when it is struggling.")
   CALL Learn(kMachine, 9)
  END IF
  IF q = 6 THEN
   CALL Reply(1, "ADA", "A house that became a private practice. Four patients came to your uncle for help. I still set places for them, though most cannot come upstairs now.")
   CALL Learn(kPatients, 9)
  END IF
 CASE 4
  q = ContextPick%(n, "CLARA VALE", "We can walk. We can speak. We can decide. Help us get the chance.")
  IF q = 1 THEN
   CALL Reply(2, "CLARA", "Copy our names from the archive. Power the fan, release the boiler pressure, and clear the vapor inlet. Secure the reservoir crossing. Thomas knows the machinery. Then use Elias' key on the ward gate.")
   CALL RescuePlan(8)
  END IF
  IF q = 2 THEN
   CALL Reply(1, "CLARA", "He was grieving for his wife. We knew. That did not make our refusals less real. Do not let his story become the only one anyone hears.")
   CALL Learn(kGrief, 8)
  END IF
  IF q = 3 THEN CALL Reply(3, "CLARA", "Then we can go. Use the key on the gate and we will follow the route to the boathouse. Together. No one gets left behind.")
  IF q = 4 THEN
   IF flags(11) THEN
    CALL Reply(3, "CLARA", "The air is better. I can hear my own thoughts again. That is a beginning.")
   ELSE
    CALL Reply(1, "CLARA", "Tired. Angry. Still myself. The vapor makes it hard to breathe, but do not mistake that for an inability to decide.")
   END IF
  END IF
  IF q = 5 THEN
   CALL Reply(0, "CLARA", "Thomas is here with me. Miriam is keeping watch over the records in the archive. Elias is usually in the library. Four people, not four experiments.")
   CALL Learn(kPatients, 8): CALL Learn(kNames, 8)
  END IF
  IF q = 6 THEN CALL Reply(1, "CLARA", "Long enough for the days to run together. Miriam kept track of our admissions. Ask her, if you need the dates; I remember what was done, not the calendar.")
 CASE 5
  q = ContextPick%(n, "THOMAS REED", "I used to maintain engines. Listening to this one kept me from listening to the other voices.")
  IF q = 1 THEN CALL Reply(2, "THOMAS", "ISOLATE the source. RETURN the trapped vapor. RELEASE the pressure. In that order. The safety interlock resets if you make a mistake.")
  IF q = 2 THEN CALL Reply(0, "THOMAS", "A fuse in the cabinet. Oil on the bearings. When both are ready the fan starts. Then work the boiler controls.")
  IF q = 3 THEN CALL Reply(1, "THOMAS", "My legs are unsteady. Tie a safety rope before you lower the sluice. A resonant fork should open its latch.")
  IF q = 4 THEN
   CALL Reply(0, "THOMAS", "Engines, pumps, things with an honest reason for breaking. Here the generator powers the ward fan. The boiler traps vapor under pressure. You need airflow before you can release it safely.")
   CALL Learn(kPressure, 13): CALL Learn(kFan, 13): CALL Learn(kMachine, 13)
  END IF
  IF q = 5 THEN
   CALL Reply(1, "THOMAS", "Slowly, if Clara helps. There is a way to the boathouse across the reservoir, but the crossing is damaged. I would need a sound safety line before I could try it.")
   CALL Learn(kCrossing, 13)
  END IF
  IF q = 6 THEN
   CALL Reply(1, "THOMAS", "They started after the doctor's Preparation R. Familiar voices, saying things I never wanted to hear again. I count the engine strokes to keep hold of something real.")
   CALL Learn(kPreparation, 13)
  END IF
 CASE 6
  q = ContextPick%(n, "MIRIAM BELL", "He numbered the folders. I kept the names. Ask me.")
  IF q = 1 THEN
   IF flags(6) THEN
    CALL Reply(3, "MIRIAM", "Elias Hart. Clara Vale. Thomas Reed. Miriam Bell. You put our names back where they belong. Thank you.")
   ELSE
    CALL Reply(2, "MIRIAM", "Elias Hart. Clara Vale. Thomas Reed. Miriam Bell. That is the order we arrived. Please put us back into the register.")
   END IF
   CALL Learn(kNames, 22): CALL Learn(kPatients, 22)
  END IF
  IF q = 2 THEN
   CALL Reply(0, "MIRIAM", "One admission each day, Monday through Thursday. The brass nameplates have our initials and dates.")
   CALL Learn(kNames, 22)
  END IF
  IF q = 3 THEN CALL Reply(2, "MIRIAM", "The ledger. Our names. Our right to tell the rest ourselves.")
  IF q = 4 THEN
   CALL Reply(2, "MIRIAM", "Help us leave together. Clara has thought through what must be made safe. I want the record to say who we were, so nobody can pretend we were only numbers.")
   CALL Learn(kRescue, 22): CALL Learn(kNames, 22)
  END IF
  IF q = 5 THEN CALL Reply(1, "MIRIAM", "Our case histories, in your uncle's words. Symptoms, doses, results. Almost nothing we said. I stayed with them because I was afraid even that much would vanish.")
  IF q = 6 THEN CALL Reply(3, "MIRIAM", "Better for being asked. I have spent too long answering questions that had nothing to do with how I felt.")
 END SELECT
 LOOP WHILE q <> 0 AND convquit = 0
 CALL EndTalk
END SUB

SUB JamesPatients
 DIM line$, answer$, mood
 ' He believes the doctor is alive. Evidence strains that belief; he never
 ' volunteers the ward or his history. The player must say what was found.
 answer$ = "Those are the doctor's affairs, sir. I attend to the house."
 IF flags(3) OR inv(10) THEN
  line$ = "I found the treatment records."
  answer$ = "The doctor's papers, sir. He will attend to them. Is there anything you need for your room?"
 END IF
 IF visited(10) THEN
  mood = 1
  line$ = "I've seen the people downstairs."
  answer$ = "Downstairs? That is not part of your visit, sir. Your room is upstairs. I can show you the way."
  IF flags(3) OR inv(10) THEN
   line$ = "I found treatment records. And I've seen the people downstairs."
   answer$ = "Doctor Mahler will explain it. He will. Now, your room is quite ready."
  END IF
 END IF
 IF line$ <> "" THEN CALL PlayerSays(line$)
 IF convquit = 0 THEN CALL Reply(mood, "JAMES", answer$)
END SUB

SUB Journal
 DIM s$
 s$ = "Three weeks after graduation, Uncle Frank offered an apprenticeship at Ravenhurst. He says your chemistry will be useful. Knock at the lit front door and show James the invitation. The coachman waits by the car."
 IF flags(1) THEN s$ = "James has shown you into the house. Explore your guest room, the library and the dining room. Examine objects and talk to people; discoveries open new questions marked with a star."
 IF flags(1) AND learned(kClock) THEN s$ = "Something is wrong with the guest-room clock. Examine its dial and the bedside letter, then look for the missing hand."
 IF flags(1) AND visited(2) = 0 THEN s$ = "James has checked your invitation. Click FRONT DOOR below the scene, or ACT on the lit door, to enter the house."
 IF flags(2) THEN s$ = "The clock has opened a stair beneath the house. Explore below and listen to the people you find there."
 IF learned(kRescue) THEN s$ = "The patients want to leave together. Ask Clara what needs to be made safe. Follow-up questions appear as you learn more; point at a starred question to see its source."
 IF flags(3) AND inv(6) = 0 THEN s$ = "Elias needs to hear that you read the study ledger. Speak to him in the library about the records; he has the ward key."
 IF inv(6) AND flags(6) = 0 THEN s$ = "Elias trusted you with the ward key. Speak to Clara about getting everyone out."
 IF learned(kNames) AND flags(6) = 0 THEN s$ = "The patients' names belong in the archive register. Miriam remembers them. Examine the admission records and listen to her."
 IF flags(6) AND flags(5) = 0 AND learned(kMachine) THEN s$ = "The names are preserved. Examine the generator machinery and ask Ada or Thomas about repairs."
 IF flags(5) AND flags(7) = 0 THEN s$ = "The ventilation fan is running. Examine the boiler controls. Thomas understands the pressure system."
 IF flags(5) AND flags(7) = 0 AND (flags(24) AND 1) THEN s$ = "Thomas explained the boiler sequence: ISOLATE, RETURN, RELEASE. The fan is running, so the controls can now respond."
 IF flags(7) AND flags(11) = 0 THEN s$ = "The line is isolated, but vapor remains in the ward inlet. The laboratory notes describe how to bind it. Read them before mixing anything."
 IF flags(11) AND flags(9) = 0 AND learned(kCrossing) THEN s$ = "The air is clear. Examine the damaged reservoir crossing and ask Thomas how to make it safe."
 IF flags(6) AND flags(11) AND flags(9) THEN s$ = "The names, air and route are safe. Use Elias' ward key on the gate. All four patients can reach the boathouse."
 IF flags(12) THEN s$ = "Everyone is at the boathouse. Click the rowboat and decide who will hold the evidence."
 IF flags(13) THEN s$ = "Four survivors. Four names restored. The completed journey is saved in slot 3. Thank you for playing Dark Visions."
 CALL Say("JOURNAL / NEXT LEAD", s$)
END SUB

SUB MapPage
 DIM q, i, text$
 text$ = "UPPER: Gates > Hall > Guest / Library / Dining. Library > Study > Attic, or Chapel. Dining > Conservatory > Boathouse. LOWER: Clock stair > Ward > Archive / Boiler / Reservoir. Stair > Generator."
 CALL Say("RAVENHURST / CONNECTIONS", text$)
END SUB
