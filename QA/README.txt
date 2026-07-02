DARK VISIONS  --  QA TEST FOLDER
================================

This folder lets you play two versions of the game side by side, with no
installation. Everything needed (including the DOS emulator) is in here.


HOW TO PLAY
-----------
  Double-click   Play-Current.bat    -> the NEW build (this round of changes)
  Double-click   Play-Original.bat   -> the ORIGINAL 1993 game (v1.03.01)

A DOSBox-X window opens and the game starts on its own.
To quit a session: exit the game normally, or press  Ctrl+F9  to force-close
the emulator. (Closing the black window also works.)

If Windows SmartScreen warns about the .bat or the emulator, choose
"More info" -> "Run anyway" (it is just the DOSBox-X emulator).


CONTROLS
--------
  Mouse              point and click to move and interact
  Arrow keys         move the on-screen cursor; Right arrow selects.
                     (The original also accepts the number pad, Num Lock on.)
  i   or   ESC       open the inventory (while playing)

  In the inventory:
     i / x / ESC     close it (back to the game)
     s   or   l      open the Save / Load screen
     arrow keys      move the selection
     q               quit to DOS

  On the Save / Load screen:
     S / L / N       Save / Load / New game
     C   or   X      back to the inventory
     ESC             exit all the way out to the game
     arrow keys      move the slot selector


WHAT TO TEST (new build vs. original)
-------------------------------------
  * Inventory:  the NEW build has a graphical inventory (press i) with item
    tiles, an Info tab, and a Combine tab (drag one item onto another to
    combine).  The ORIGINAL has a plain text inventory.

  * Save / Load:  the NEW build has a 10-slot graphical Save/Load screen that
    shows each slot's room name and progress %.  Try Save, Load, and New Game.
    It remembers the last slot you used.

  * Examine:  pick a book or the map in the inventory and click the
    magnifying-glass icon to read/view it.

  * Death:  if your character dies, the NEW build drops you on the Save/Load
    screen (Save is hidden there; Load needs no confirmation).

  * Overall:  play through both and compare the feel, art, speed, and note any
    bugs, glitches, or differences.


IF THE GAME RUNS TOO FAST OR TOO SLOW
-------------------------------------
  Ctrl+F12  = speed up      Ctrl+F11 = slow down     (adjusts CPU cycles)


NOTES
-----
  - The NEW build starts with empty save slots; the original may have a few.
  - Mouse not moving the cursor?  Click once inside the window to capture it;
    press Ctrl+F10 to release the mouse back to Windows.
  - The two versions keep their own separate save files (in current\ and
    original\), so testing one will not affect the other.
