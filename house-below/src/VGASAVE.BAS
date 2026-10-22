REM $DYNAMIC
DEFINT A-Z
'$INCLUDE: 'VGA.BI'

SaveError:
LoadError:
 ioerr = ERR
 RESUME NEXT

SUB SaveGame (slot)
 DIM f, i, path$
 ON ERROR GOTO SaveError
 ioerr = 0: f = FREEFILE
 path$ = "VGA\SLOT" + LTRIM$(STR$(slot)) + ".SAV"
 OPEN path$ FOR OUTPUT AS #f
 IF ioerr THEN CALL Say("SAVE FAILED", "The save directory is not writable. Your current journey is still running."): EXIT SUB
 PRINT #f, "DVGA3"
 WRITE #f, room
 FOR i = 1 TO 32: WRITE #f, flags(i): NEXT
 FOR i = 1 TO 16: WRITE #f, inv(i), visited(i): NEXT
 FOR i = 1 TO 14: WRITE #f, learned(i): NEXT
 CLOSE #f
 IF ioerr THEN CALL Say("SAVE FAILED", "The disk could not finish writing the save.") ELSE IF testing = 0 THEN CALL Say("GAME SAVED", "Your room, inventory, clues and puzzle progress have been saved.")
 EXIT SUB
END SUB

SUB LoadGame (slot)
 DIM f, i, nr, tf(32), ti(16), tv(16), tk(14), sig$, path$, valid, limit
 ON ERROR GOTO LoadError
 ioerr = 0: f = FREEFILE
 path$ = "VGA\SLOT" + LTRIM$(STR$(slot)) + ".SAV"
 OPEN path$ FOR INPUT AS #f
 IF ioerr THEN ioerr = 0: CALL Say("EMPTY SLOT", "There is no readable saved journey in that slot."): EXIT SUB
 LINE INPUT #f, sig$
 IF sig$ <> "DVGA1" AND sig$ <> "DVGA2" AND sig$ <> "DVGA3" THEN CLOSE #f: CALL Say("INVALID SAVE", "This file is not a House Below saved game."): EXIT SUB
 INPUT #f, nr
 ' Reject bad room IDs before any later array/index work. Check EOF explicitly
 ' instead of cascading DOS runtime errors through a truncated input file.
 IF ioerr OR nr < 1 OR nr > 16 THEN
  CLOSE #f: ioerr = 0
  CALL Say("INVALID SAVE", "The saved game is incomplete or corrupt. Your current progress was kept.")
  EXIT SUB
 END IF
 FOR i = 1 TO 32
  IF EOF(f) THEN ioerr = 1 ELSE INPUT #f, tf(i)
 NEXT
 FOR i = 1 TO 16
  IF EOF(f) THEN ioerr = 1 ELSE INPUT #f, ti(i), tv(i)
 NEXT
 IF sig$ <> "DVGA1" THEN
  FOR i = 1 TO 14
   IF EOF(f) THEN ioerr = 1 ELSE INPUT #f, tk(i)
  NEXT
 END IF
 CLOSE #f
 valid = (ioerr = 0 AND nr >= 1 AND nr <= 16)
 FOR i = 1 TO 32
  limit = 1
  IF i = 13 THEN limit = 2
  IF i >= 20 AND i <= 26 THEN limit = 7
  IF i >= 20 AND i <= 26 AND sig$ <> "DVGA1" THEN limit = 63
  IF i = 27 AND sig$ = "DVGA3" THEN limit = 63
  IF tf(i) < 0 OR tf(i) > limit THEN valid = 0
 NEXT
 FOR i = 1 TO 14
  IF tk(i) < 0 OR tk(i) > 36 THEN valid = 0
 NEXT
 FOR i = 1 TO 16
  IF ti(i) < 0 OR ti(i) > 1 OR tv(i) < 0 OR tv(i) > 1 THEN valid = 0
 NEXT
 IF valid = 0 THEN ioerr = 0: CALL Say("INVALID SAVE", "The saved game is incomplete or corrupt. Your current progress was kept."): EXIT SUB
 FOR i = 1 TO 32: flags(i) = tf(i): NEXT
 FOR i = 1 TO 16: inv(i) = ti(i): visited(i) = tv(i): NEXT
 FOR i = 1 TO 14: learned(i) = tk(i): NEXT
 IF sig$ = "DVGA1" THEN CALL LegacyKnowledge
 CALL SyncKnowledge
 CALL EnterRoom(nr)
 CALL Say("JOURNEY RESTORED", "Your saved progress has been restored. J opens your current lead.")
 EXIT SUB
END SUB

FUNCTION FindHot% (value, kind)
 DIM i, h
 FindHot% = 0
 FOR i = 1 TO hn(room)
  h = (room - 1) * 12 + i
  IF hv(h) = value AND hk(h) = kind THEN FindHot% = h: EXIT FUNCTION
 NEXT
END FUNCTION

