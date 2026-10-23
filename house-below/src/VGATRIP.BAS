REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'
DECLARE SUB CrossThreshold (dest)

SUB Travel (h)
 DIM dest, first
 IF room = 1 AND hv(h) = 2 AND flags(1) = 0 THEN
  IF selected = 0 OR selected = 1 THEN
   CALL FrontDoor
   IF flags(1) = 0 THEN EXIT SUB
  END IF
 END IF
 IF selected THEN CALL Say("PUT THAT AWAY", "Right-click to put the item away, then choose a passage."): EXIT SUB
 IF need(h) THEN
  IF flags(need(h)) = 0 THEN
   SELECT CASE need(h)
   CASE 1
    CALL Speak(1, "AT THE DOOR", "May I see your invitation, sir?")
   CASE 2
    CALL Learn(kClock, 2)
    CALL Say("THE HIDDEN STAIR", "The clock conceals this passage. Replace its missing hand and set it to the scratched time.")
   CASE 9
    CALL Learn(kCrossing, 19)
    CALL Say("UNSAFE CROSSING", "The reservoir bridge must be secured from below. Reach it through the hidden clock stair. Bring the boathouse rope.")
   END SELECT
   EXIT SUB
  END IF
 END IF
 dest = hv(h): first = (visited(dest) = 0)
 IF room = 1 AND dest = 2 THEN
  CALL CrossThreshold(dest)
  IF first THEN CALL Speak(1, "INSIDE RAVENHURST", "Doctor Mahler is occupied. Your room is ready upstairs. The library is on this floor, should you wish to wait there.")
 ELSEIF room = 2 AND dest = 1 THEN
  CALL CrossThreshold(dest)
 ELSE
  CALL EnterRoom(dest)
 END IF
END SUB

SUB CheckTalk
 DIM i, npc, history, oldroom, oldsel, gate, ledger, wardkey, oldpick, saved(32), valid, knew(14)
 oldroom = room: oldsel = selected: oldpick = testpick
 gate = flags(1): ledger = flags(3): wardkey = inv(6)
 selected = 0: flags(1) = 0: flags(3) = 1: inv(6) = 0
 FOR i = 1 TO 32: saved(i) = flags(i): NEXT
 FOR i = 20 TO 27: flags(i) = 0: NEXT
 FOR i = 1 TO 14: knew(i) = learned(i): learned(i) = 4: NEXT
 flags(6) = 1: flags(9) = 1: flags(11) = 1
 FOR i = 1 TO 7
  room = 2: npc = i - 1
  IF i = 1 THEN room = 1: npc = 8
  history = 19 + npc
  testtalk$ = "24": CALL Talk(npc)
  CALL Check(flags(history) = 2, "only selected question marked: " + heading$)
  IF i = 1 THEN CALL Check(flags(20) = 0 AND flags(26) = 0, "coachman history is separate from James and legacy outdoor history")
  ' The asked question leaves the menu: row 1 is now question 1, not the one just asked.
  testtalk$ = "14": CALL Talk(npc)
  CALL Check(flags(history) = 3 AND testtalk$ = "", "next question moves up after one is asked: " + heading$)
  ' Keep asking the top question, then explicitly choose Leave.
  flags(history) = 0
  testtalk$ = "1114"
  CALL Talk(npc)
  CALL Check(testtalk$ = "" AND talkmenu = 0 AND nchoices = 3 AND (flags(history) AND 1) <> 0, "ask three questions then Leave: " + heading$)
 NEXT
 CALL Check(flags(1) = 0 AND inv(6) = 1, "repeated topics preserve gate and ward key progress")
 FOR i = 20 TO 27
  IF i <> 26 THEN flags(i) = 7
 NEXT
 CALL SaveGame(1)
 FOR i = 20 TO 27: flags(i) = 0: NEXT
 CALL LoadGame(1): valid = -1
 FOR i = 20 TO 27
  IF i <> 26 AND flags(i) <> 7 THEN valid = 0
 NEXT
 CALL Check(valid, "asked questions survive save and load")
 flags(20) = 64: CALL SaveGame(2): flags(20) = 2: CALL LoadGame(2)
 CALL Check(flags(20) = 2 AND heading$ = "INVALID SAVE", "invalid question history preserves current journey")
 FOR i = 20 TO 26: flags(i) = 0: NEXT
 CALL SaveGame(2): flags(20) = 7: CALL LoadGame(2)
 CALL Check(flags(20) = 0, "save with unasked topics restores unmarked history")
 FOR i = 1 TO 32: flags(i) = saved(i): NEXT
 FOR i = 1 TO 14: learned(i) = knew(i): NEXT
 room = oldroom: selected = oldsel: testpick = oldpick
 flags(1) = gate: flags(3) = ledger: inv(6) = wardkey: testtalk$ = ""
END SUB

SUB CrossThreshold (dest)
 DIM level
 ' A short VGA palette fade marks the outdoor/indoor boundary.
 ' Direct EnterRoom remains immediate for startup, loading, and DOS tests.
 IF testing THEN CALL EnterRoom(dest): EXIT SUB
 CALL DrawScene: CALL Present
 FOR level = 7 TO 0 STEP -1
  CALL DoorShade(level): CALL Present
 NEXT
 CALL EnterRoom(dest): CALL DrawScene
 FOR level = 0 TO 8
  CALL DoorShade(level): CALL Present
 NEXT
END SUB


SUB DoorShade (level)
 DIM i, shade(0 TO 255) AS tRGB
 FOR i = 0 TO 255
  shade(i).red = CHR$(ASC(pal(i).red) * level \ 8)
  shade(i).green = CHR$(ASC(pal(i).green) * level \ 8)
  shade(i).blue = CHR$(ASC(pal(i).blue) * level \ 8)
 NEXT
 uglPalSetBuff 0, 256, shade(0)
END SUB
