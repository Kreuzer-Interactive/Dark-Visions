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
  i                  open the inventory (while playing)
  ESC                open the main menu (New Game / Save / Load / Quit)

  On the main menu:
     up / down       move the selection (Load is grayed out with no saves)
     Enter / Space   choose the selected item; N / S / L / Q jump directly
     ESC  or  x      back to the game
     mouse           hover to select, click to choose

  In the inventory:
     i / x / ESC     close it (back to the game)
     arrow keys      move the selection
     q               quit to DOS
     (save/load moved to the ESC main menu)

  On the Save or Load screen (book):
     arrows / 1-9,0  move the slot selector / jump to a slot
     Enter / Space   save to / load from the selected slot
     double-click    same as Enter on that slot
     S / L           the screen's action button (same as Enter)
     X   or  ESC     back to the main menu


WHAT TO TEST (new build vs. original)
-------------------------------------
  * Inventory:  the NEW build has a graphical inventory (press i) with item
    tiles, an Info tab, and a Combine tab (drag one item onto another to
    combine).  The ORIGINAL has a plain text inventory.

  * Save / Load:  the NEW build has separate 10-slot Save and Load book screens
    (ESC menu -> Save or Load) showing each slot's room name and progress %.
    Enter, double-click, or the action button saves/loads the selected slot;
    Back returns to the menu to switch screens. Remembers the last slot used.

  * Examine:  pick a book or the map in the inventory and click the
    magnifying-glass icon to read/view it.

  * Death:  if your character dies, the NEW build drops you on the Load screen
    (no save switch; loads need no confirmation). Back opens the main menu
    with Save grayed out, so New Game / Quit stay reachable.

  * Revive (dark.ini revive=1):  every room transition auto-saves the room you
    are LEAVING to a hidden temp slot; if a timed killer encounter then gets
    you, the death skips the Load screen -- the game restores that save (back
    in the safe room, before you walked in), shows Joe's "they're still in
    there" message, and play continues. revive=0 = classic behaviour.

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
