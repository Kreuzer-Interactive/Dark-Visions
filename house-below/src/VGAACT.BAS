REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB Give (n, s$)
 inv(n) = 1
 IF soundon AND testing = 0 THEN SOUND 660, 1: SOUND 880, 1
 CALL Say(items$(n), s$)
END SUB

SUB Act (h)
 hover = h
 ' Navigation plates remain usable while LOOK or TALK is selected.
 IF hk(h) = 1 AND hy(h) >= 143 THEN CALL Travel(h): EXIT SUB
 IF verb = 2 THEN CALL Observe(h): CALL Say(names$(h), descs$(h)): EXIT SUB
 IF verb = 3 AND hk(h) <> 4 THEN CALL Say("NO ANSWER", "Try speaking to someone who can hear you."): EXIT SUB
 SELECT CASE hk(h)
 CASE 1
  CALL Travel(h)
 CASE 2
  CALL Observe(h)
  IF inv(hv(h)) THEN CALL Say("ALREADY COLLECTED", "You already have it. Check the inventory below.") ELSE CALL Give(hv(h), descs$(h))
 CASE 3
  CALL Observe(h)
  CALL Special(hv(h))
 CASE 4
  CALL Talk(hv(h))
 END SELECT
END SUB

SUB Special (n)
 DIM q, h
 SELECT CASE n
 CASE 102
  IF selected = 3 THEN flags(16) = 1: selected = 0
  IF flags(16) = 0 THEN CALL Say("MISSING HAND", "The clock needs its brass hand. Search the library's books."): EXIT SUB
  q = Pick%("SET THE CLOCK", "VIII marks the hour. IV marks four groups of five minutes.", "8:20", "4:40", "12:04")
  IF q = 1 THEN flags(2) = 1: CALL Say("THE HOUSE BELOW", "The clock strikes once. A stone stair opens behind the wall. The stairs are now an exit from this room.")
 CASE 103
  IF selected <> 2 AND flags(3) = 0 THEN CALL Say("LOCKED DRAWER", "The catch is simple, but too narrow for your fingers. A hairpin might lift it."): EXIT SUB
  flags(3) = 1: selected = 0
  CALL Give(10, "You lift the catch. The ledger records patients refusing treatment, followed by further doses. Elias must see that you know. These pages must leave the house.")
 CASE 104
  q = Pick%("THE SYMBOL SAFE", "The chapel glass shows the path from night into dawn.", "Sun - moon - star", "Moon - star - sun", "Star - sun - moon")
  IF q = 2 THEN CALL Give(4, "The safe opens. Inside is the spare generator fuse. No treasure, just the means to keep the ventilation running.")
  IF q > 0 AND q <> 2 THEN CALL Say("WRONG SEQUENCE", "The dial springs back. Nothing is lost. Look at the chapel glass.")
 CASE 105, 115
  IF n = 105 AND selected = 4 THEN flags(14) = 1: selected = 0
  IF n = 115 AND selected = 5 THEN flags(15) = 1: selected = 0
  IF flags(14) AND flags(15) THEN
   flags(5) = 1: CALL Say("POWER RESTORED", "The generator turns. A fan begins to pull clean air through the lower ward. Now the pressure controls will respond.")
  ELSE
   CALL Say("GENERATOR MAINTENANCE", "Use the fuse on the cabinet and the oil can on the bearings. Both are needed before the motor can run safely.")
  END IF
 CASE 106
  q = Pick%("RESTORE THE PATIENT NAMES", "Use the admission initials and Miriam's names. Which is the correct order?", "Clara, Elias, Miriam, Thomas", "Thomas, Miriam, Elias, Clara", "Elias, Clara, Thomas, Miriam")
  IF q = 3 THEN flags(6) = 1: CALL Say("PEOPLE, NOT NUMBERS", "Elias Hart. Clara Vale. Thomas Reed. Miriam Bell. You copy the original names into the evidence ledger. Their stories will leave with them.")
  IF q > 0 AND q <> 3 THEN CALL Say("CHECK THE RECORD", "The dates do not match. Check the brass nameplates and speak with Miriam.")
 CASE 107
  IF flags(5) = 0 THEN CALL Say("NO AIRFLOW", "The ventilation fan must run first. Restore power at the generator."): EXIT SUB
  q = Pick%("PRESSURE / STEP ONE", "Thomas warned: stop the source before moving the air.", "ISOLATE", "RETURN", "RELEASE")
  IF q <> 1 THEN CALL Say("INTERLOCK RESET", "The safety interlock closes. Nothing is damaged. Thomas knows the correct order."): EXIT SUB
  q = Pick%("PRESSURE / STEP TWO", "The source is isolated. Where should the trapped vapor go?", "RELEASE", "RETURN", "ISOLATE")
  IF q <> 2 THEN CALL Say("INTERLOCK RESET", "Return the trapped vapor before releasing pressure."): EXIT SUB
  q = Pick%("PRESSURE / STEP THREE", "The vapor has returned to the sealed tank. Finish the sequence.", "RETURN", "ISOLATE", "RELEASE")
  IF q = 3 THEN flags(7) = 1: CALL Say("PRESSURE ZERO", "The needle falls to zero. The dosing line is isolated. A little vapor remains in the ward inlet; the laboratory notes describe how to bind it.")
 CASE 108
  q = Pick%("THE ORGAN", "Three notes on the score: C - E - G. Which chord will sound the latch?", "C - E - G", "G - C - E", "E - G - C")
  IF q = 1 THEN
   flags(8) = 1
   IF soundon AND testing = 0 THEN SOUND 262, 2: SOUND 330, 2: SOUND 392, 3
   CALL Give(8, "The chord shivers through the stone. A compartment opens, revealing a tuning fork. Its note matches the reservoir latch.")
  END IF
 CASE 109
  IF flags(9) THEN CALL Say("CROSSING SECURED", "The sluice is down and the safety rope is sound. Everyone can reach the boathouse."): EXIT SUB
  IF flags(19) = 0 THEN CALL Say("UNSAFE CROSSING", "Secure the bridge anchor with a rope before releasing the sluice."): EXIT SUB
  IF selected <> 8 THEN CALL Say("RESONANT LOCK", "The latch hums at one note. Use the tuning fork from the chapel."): EXIT SUB
  flags(9) = 1: selected = 0: CALL Say("A WAY OUT", "The fork sounds. The sluice lowers and the rope holds. The route to the boathouse is safe for the patients.")
 CASE 110
  IF flags(18) = 0 THEN CALL Say("READ BEFORE MIXING", "Your uncle's notebook records a reversal sequence. Guessing at his apparatus would repeat his mistake."): EXIT SUB
  q = Pick%("REVERSAL MIXTURE", "Choose the sequence from the notebook. These are the house's fictional reagents.", "Amber - clear - azure", "Azure - amber - clear", "Clear - azure - amber")
  IF q = 2 THEN flags(10) = 1: CALL Give(9, "A blue-white mixture settles in the vial. It will bind the vapor in the ward inlet. It is not a medicine to give the patients.")
  IF q > 0 AND q <> 2 THEN CALL Say("TRY AGAIN", "The apparatus drains the failed batch into its sealed receiver. Re-read the notebook; there are enough reagents to try again.")
 CASE 111
  IF flags(7) = 0 THEN CALL Say("SOURCE STILL OPEN", "Isolate the dosing line at the boiler controls before treating the residue."): EXIT SUB
  IF selected <> 9 THEN CALL Say("VAPOR RESIDUE", "Use the laboratory reversal vial on this inlet."): EXIT SUB
  flags(11) = 1: selected = 0: CALL Say("CLEAN AIR", "The last vapor condenses in the receiver. Clara takes a cautious breath. For the first time, only the living answer.")
 CASE 112
  IF flags(6) = 0 THEN CALL Speak(4, "CLARA", "First preserve our names. Miriam is in the archive. We will not disappear as numbers."): EXIT SUB
  IF flags(11) = 0 THEN CALL Speak(4, "CLARA", "The air must be clear. Restore the generator, isolate the line, and bind the remaining vapor."): EXIT SUB
  IF flags(9) = 0 THEN CALL Speak(4, "CLARA", "Make the reservoir crossing safe. Thomas cannot manage a broken bridge."): EXIT SUB
  IF selected <> 6 AND flags(12) = 0 THEN CALL Say("LOCKED WARD", "Elias kept the brass ward key. Show him that you have read the study ledger, then use the key here."): EXIT SUB
  flags(12) = 1: selected = 0: CALL Say("THE DOOR OPENS", "Clara leads Thomas and Miriam through the reservoir. Elias joins them by the lake. All four are waiting at the boathouse. Take the evidence with you.")
 CASE 113
  IF flags(12) = 0 THEN CALL Say("NOT ALONE", "There is room for everyone. Open the ward and make the crossing safe before you leave."): EXIT SUB
  q = Pick%("WHAT LEAVES THE HOUSE?", "Four survivors are aboard. Your uncle's ledger lies in your hands. Dawn is close.", "Take the evidence to the village", "Seal the ledger for the survivors", "Stay a little longer")
  IF q = 1 THEN flags(13) = 1: CALL Say("ENDING / THE WITNESSES", "At dawn, four people give their names. The ledger corroborates every word. Your uncle's work ends here. What comes next belongs to the people he " + _
    "failed. You row toward the village.")
  IF q = 2 THEN flags(13) = 2: CALL Say("ENDING / THEIR OWN VOICES", "You place the sealed ledger in Clara's hands. They will decide when and how to speak. The house recedes into morning mist. For once, you listen " + _
    "without trying to answer for them.")
  IF q = 1 OR q = 2 THEN
   CALL SaveGame(3)
   CALL Say("DARK VISIONS", "All four patients survived. The completed journey is saved in slot 3. You may continue exploring, load another save, or press ESC to quit. Story inspired by the Dark Visions comic. " + _
    "Original game: Rob and Jon Kreuzer.")
  END IF
 CASE 114
  flags(4) = 1: CALL Say("CHAPEL GLASS", "From bottom to top: MOON, STAR, SUN. Night into dawn. The study safe bears those same emblems.")
 CASE 116
  IF selected = 7 THEN
   flags(19) = 1: selected = 0
   CALL Say("SAFETY LINE", "You tie the rope to the bridge anchor. Now the resonant sluice latch can be released safely.")
  ELSE
   CALL Say("BRIDGE ANCHOR", "The broken safety cable needs a strong rope. There should be one at the boathouse.")
  END IF
 CASE 117
  flags(17) = 1: CALL Say("ADMISSION ORDER", "Monday: E.H. Tuesday: C.V. Wednesday: T.R. Thursday: M.B. Miriam remembers the full names. Match them in the register.")
 CASE 118
  flags(18) = 1: CALL Say("THE REVERSAL", "AZURE, then AMBER, then CLEAR. The mixture binds vapor inside the apparatus. Isolate and depressurize the dosing line first. This is a fictional chemical puzzle, not a treatment.")
 CASE ELSE
  h = FindHot%(n, 3)
  ' Generic look objects share action 120; use the hovered object when possible.
  IF hover > 0 THEN IF hv(hover) = n THEN h = hover
  IF h THEN CALL Say(names$(h), descs$(h))
 END SELECT
END SUB
