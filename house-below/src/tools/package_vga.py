"""Package only the native game and runtime assets, never developer or player saves."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'src'
out=ROOT/'dist'; out.mkdir(exist_ok=True)
with ZipFile(out/'Dark-Visions-VGA.zip','w',ZIP_DEFLATED) as z:
    z.write(SRC/'VISIONS.EXE','VISIONS.EXE')
    z.write(SRC/'PLAYVGA.BAT','PLAYVGA.BAT')
    for path in sorted((SRC/'VGA').glob('*')):
        if path.name.startswith('FACE') or path.name == 'YOU.BMP': continue
        if path.suffix.upper() in {'.BMP','.DAT'}: z.write(path,'VGA/'+path.name)
    z.write(ROOT/'docs'/'vga-walkthrough.md','WALKTHRU.TXT')
    z.writestr('README.TXT', '''DARK VISIONS: THE HOUSE BELOW\r\n
Native DOS / QuickBASIC adventure, 320x200 (mode 13h), 256 colors.\r\n
Extract the entire archive. In DOS, change to that folder and run PLAYVGA.\r\n
Requires a VGA card (mode 13h) and a DOS mouse driver.\r\n
Recommended: DOSBox-X, machine=svga_s3, cycles=fixed 50000.\r\n
Use autolock=false and mouse_emulation=never. Mouse capture is not needed.\r\n
Set [dos] int33 hide host cursor when polling=true for a single custom cursor.\r\n
Ctrl+F10 releases the mouse if manually captured.\r\n
ACT / LOOK / TALK: click verbs. Click inventory item then its target.\r\n
Right click cancels item / cycles verbs. TAB hotspots; ENTER activate.\r\n
1-8 inventory slots, I inventory page, arrows cursor, J journal, M map,\r\n
H hotspots, S PC speaker sound, F5 save, F9 load, ESC pause.\r\n
Dialogue choices: click or press 1-3. Saves go in VGA/SLOT1..3.SAV.\r\n
Portrait conversations cover the toolbar until you leave. TAB focuses options.\r\n
Transparent portraits face each other over the room, with four expressions per character.\r\n
The speaker is larger and brighter; the listener recedes. Expressions follow the dialogue.\r\n
The named speech panel points to its speaker. Only one turn is shown at a time.\r\n
Speech appears gradually. Click/Enter reveals it; Continue/Enter afterward advances.\r\n
Click Goodbye [Esc], press 4 in the topic menu, or ESC/right-click to leave.\r\n
Back to questions after an answer keeps the conversation open until Goodbye.\r\n
Asked questions turn blue and can be asked again. History is saved with your journey.\r\n
Questions unlock from examined clues and what people tell you.\r\n
* marks a clue-based question. Hover or TAB to see where you learned it.\r\n
Click page arrows or press PgUp/PgDn ([ / ]) for more questions.\r\n
Earlier topics remain available. Discovery sources are saved; older VGA saves still load.\r\n
The ending saves completed progress to slot 3.\r\n
16 rooms plus a back-seat motorcar opening, seven speaking characters, rescue puzzles.\r\n
Read your uncle's invitation in your lap before a road jolt and fade reveal the coachman.\r\n
Click/Enter reveals the reading, then advances; it waits until you are ready.\r\n
Click/Enter advances the opening captions. ESC skips to arrival, including during fades.\r\n
Outside, the coachman waits by the parked car on the left.\r\n
Knock at FRONT DOOR; show James the invitation to enter the hall.\r\n
Car and outdoor coachman questions share history. Earlier VGA saves still load.\r\n
Original Dark Visions by Rob and Jon Kreuzer. Comic-inspired adaptation.\r\n
New room and character art generated using the built-in imagegen tool.\r\n
''')
print(out/'Dark-Visions-VGA.zip')
