# Dark Visions: The House Below (VGA edition)

A standalone native DOS / QuickBASIC adventure inspired by the **Dark Visions** comic.
It is a separate game from the original CGA Dark Visions in `../src`, which is untouched.
It renders in standard VGA **mode 13h (320×200, one shared 256-color palette)**. Every room background is new.

**Play on Windows:** double-click `Play-Dark-Visions.cmd` in this folder. It uses the installed
DOSBox-X or the copy in `../QA/DOSBox-X`. The mouse works without capture. **Ctrl+F10** releases it if manually captured.
**Play in DOS:** change to `src` and run `PLAYVGA.BAT`.

- A back-seat motorcar opening, 16 illustrated rooms, 76 hotspots, seven conversational characters, and illustrated character sprites.
- Ten inventory items, contextual cursors, ACT / LOOK / TALK, visible exits, and optional hotspot outlines.
- Connected clock, safe, generator, records, organ, ventilation, laboratory, bridge, and rescue puzzles.
- A clue journal, location guide, three save slots, and two survivor-focused endings.
- Keyboard alternatives: TAB selects hotspots, ENTER activates, 1–8 select inventory slots,
  I changes inventory page, arrows move the cursor. J journal, M map, H clues, S sound,
  F5 save, F9 load, ESC pause/cancel. Dialogue questions accept 1–3.
- Conversations show transparent portraits facing each other, with four expressions and one
  speaker at a time. Dialogue appears gradually; click or Enter reveals the full line.
  Asked questions turn blue and stay repeatable; starred questions are based on clues you found.
  Click **Goodbye [Esc]**, press 4 or ESC, or right-click to leave a topic menu.

Requires any VGA card and a DOS mouse driver; there is no VESA or FPU requirement. Tested in
DOSBox-X and on an emulated 486SX/25 in 86Box (about 14-18 frames per second in rooms and
dialogue). Physical 486 hardware has not been tested. VGA saves are separate from original-game saves.

Build with `powershell -File src/tools/build_vga.ps1 -Test` using a licensed QuickBASIC 4.5
installation at the path configured in that script. It links the uGL library from `../src/UGL`.
The tests run inside DOSBox-X, in an isolated save directory.
[Implementation, art, and testing notes](docs/vga-adventure.md) and
[full walkthrough](docs/vga-walkthrough.md) explain the game.
