REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SUB Learn (fact, origin)
 ' Preserve the first actual source, including information heard in dialogue.
 IF learned(fact) = 0 THEN learned(fact) = origin
END SUB

FUNCTION SourceName$ (origin)
 SELECT CASE origin
 CASE 1: SourceName$ = "House windows"
 CASE 2: SourceName$ = "Grandfather clock"
 CASE 3: SourceName$ = "Brass clock hand"
 CASE 4: SourceName$ = "James told you"
 CASE 5: SourceName$ = "Elias told you"
 CASE 6: SourceName$ = "Treatment ledger"
 CASE 7: SourceName$ = "Prescription notes"
 CASE 8: SourceName$ = "Clara told you"
 CASE 9: SourceName$ = "Ada told you"
 CASE 10: SourceName$ = "The boathouse"
 CASE 11: SourceName$ = "Oil can label"
 CASE 12: SourceName$ = "Generator machinery"
 CASE 13: SourceName$ = "Thomas told you"
 CASE 14: SourceName$ = "The ward gate"
 CASE 15: SourceName$ = "Pipe diagram"
 CASE 16: SourceName$ = "Pressure controls"
 CASE 17: SourceName$ = "Pressure gauge"
 CASE 18: SourceName$ = "Reservoir bridge"
 CASE 19: SourceName$ = "Blocked reservoir path"
 CASE 20: SourceName$ = "Dining room place cards"
 CASE 21: SourceName$ = "Mooring rope"
 CASE 22: SourceName$ = "Miriam told you"
 CASE 23: SourceName$ = "Patient register"
 CASE 24: SourceName$ = "Brass nameplates"
 CASE 25: SourceName$ = "Bedside letter"
 CASE 26: SourceName$ = "Family portrait"
 CASE 27: SourceName$ = "Frank's last letter"
 CASE 28: SourceName$ = "Spare generator fuse"
 CASE 29: SourceName$ = "Tuning fork"
 CASE 30: SourceName$ = "Laboratory notebook"
 CASE 31: SourceName$ = "Stone basin"
 CASE 32: SourceName$ = "Elias' brass key"
 CASE 33: SourceName$ = "Examining Ada"
 CASE 34: SourceName$ = "Clara's situation"
 CASE 35: SourceName$ = "Examining Thomas"
 CASE 36: SourceName$ = "Ward inlet"
 END SELECT
END FUNCTION

SUB Observe (h)
 ' Called only when an object is examined or actually interacted with.
 ' Entering a room or hovering never grants its unread clues.
 SELECT CASE names$(h)
 CASE "Coachman": flags(29) = 1
 CASE "House windows": CALL Learn(kWindow, 1)
 CASE "Grandfather clock": CALL Learn(kClock, 2)
 CASE "Brass clock hand": CALL Learn(kClock, 3)
 CASE "Bedside letter": CALL Learn(kClock, 25)
 CASE "Prescription notes": CALL Learn(kPreparation, 7)
 CASE "Elias Hart": CALL Learn(kRecords, 32)
 CASE "Ada Finch": CALL Learn(kLake, 33)
 CASE "Oil can": CALL Learn(kMachine, 11)
 CASE "Stone basin": CALL Learn(kLake, 31)
 CASE "Pipe diagram": CALL Learn(kFan, 15): CALL Learn(kMachine, 15)
 CASE "Pressure controls": CALL Learn(kPressure, 16): CALL Learn(kFan, 16)
 CASE "Pressure gauge": CALL Learn(kPressure, 17)
 CASE "Fuse cabinet", "Dry motor bearings": CALL Learn(kMachine, 12)
 CASE "Resonant sluice latch", "Bridge anchor": CALL Learn(kCrossing, 18)
 CASE "Coil of rope": CALL Learn(kCrossing, 21): CALL Learn(kLake, 21)
 CASE "Patient register": CALL Learn(kNames, 23)
 CASE "Brass nameplates": CALL Learn(kNames, 24)
 CASE "Family portrait": CALL Learn(kGrief, 26)
 CASE "Frank's last letter": CALL Learn(kGrief, 27)
 CASE "Laboratory notebook": CALL Learn(kPreparation, 30)
 CASE "Clara Vale": CALL Learn(kRescue, 34): CALL Learn(kNames, 34)
 CASE "Thomas Reed": CALL Learn(kPressure, 35)
 CASE "Ward gate": CALL Learn(kRescue, 14): CALL Learn(kNames, 14)
 CASE "Vapor inlet": CALL Learn(kPreparation, 36)
 END SELECT
END SUB

SUB RescuePlan (origin)
 CALL Learn(kRescue, origin): CALL Learn(kNames, origin)
 CALL Learn(kCrossing, origin): CALL Learn(kWardKey, origin)
 CALL Learn(kPressure, origin): CALL Learn(kFan, origin)
 CALL Learn(kPatients, origin): CALL Learn(kMachine, origin)
END SUB

SUB SyncKnowledge
 ' Inventory and completed tasks also prove knowledge, including old saves.
 IF inv(3) OR flags(16) OR flags(2) THEN CALL Learn(kClock, 3)
 IF flags(3) OR inv(10) THEN
  CALL Learn(kPatients, 6): CALL Learn(kPreparation, 6): CALL Learn(kRecords, 6)
 END IF
 IF inv(6) THEN CALL Learn(kWardKey, 5): CALL Learn(kRescue, 5)
 IF inv(5) THEN CALL Learn(kMachine, 11)
 IF inv(4) THEN CALL Learn(kMachine, 28): CALL Learn(kFan, 28)
 IF flags(5) OR flags(14) OR flags(15) THEN CALL Learn(kMachine, 12)
 IF flags(5) THEN CALL Learn(kFan, 12)
 IF flags(7) THEN CALL Learn(kPressure, 16)
 IF flags(9) OR flags(19) THEN CALL Learn(kCrossing, 18)
 IF inv(7) THEN CALL Learn(kCrossing, 21): CALL Learn(kLake, 21)
 IF inv(8) THEN CALL Learn(kCrossing, 29)
 IF flags(6) THEN CALL Learn(kNames, 23)
 IF flags(17) THEN CALL Learn(kNames, 24)
 IF flags(18) THEN CALL Learn(kPreparation, 30)
 IF flags(12) THEN CALL Learn(kRescue, 8)
END SUB

SUB LegacyKnowledge
 ' Old saves retain stable IDs 1-3. Recover only things their replies taught.
 IF flags(20) AND 2 THEN CALL Learn(kPatients, 4)
 IF flags(20) AND 4 THEN CALL Learn(kClock, 4)
 IF flags(21) AND 5 THEN CALL Learn(kRecords, 5)
 IF flags(21) AND 2 THEN CALL Learn(kPreparation, 5)
 IF flags(22) AND 1 THEN CALL Learn(kLake, 9): CALL Learn(kCrossing, 9)
 IF flags(22) AND 2 THEN CALL Learn(kMachine, 9): CALL Learn(kFan, 9)
 IF flags(23) AND 1 THEN
  CALL Learn(kRescue, 8): CALL Learn(kNames, 8): CALL Learn(kCrossing, 8)
  CALL Learn(kWardKey, 8): CALL Learn(kPressure, 8): CALL Learn(kFan, 8)
 END IF
 IF flags(23) AND 2 THEN CALL Learn(kGrief, 8)
 IF flags(24) AND 1 THEN CALL Learn(kPressure, 13)
 IF flags(24) AND 2 THEN CALL Learn(kFan, 13): CALL Learn(kMachine, 13)
 IF flags(24) AND 4 THEN CALL Learn(kCrossing, 13)
 IF flags(25) AND 3 THEN CALL Learn(kNames, 22)
 IF flags(25) AND 4 THEN CALL Learn(kRescue, 22)
 IF flags(26) AND 4 THEN CALL Learn(kWindow, 4)
END SUB
