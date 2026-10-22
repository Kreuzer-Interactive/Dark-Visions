# Dark Visions: The House Below

This is a new native DOS adventure entry point, `src/VISIONS.EXE`, implemented in
QuickBASIC 4.5 and the repository's uGL library. It lives in its own folder, `house-below/`, separate from the original game's `src/`, and is
launched with `PLAYVGA.BAT`.
It is a playable adaptation, not a claim to reproduce every comic panel or every puzzle
from the original game. The nephew, Frank Mahler, James, Preparation R, the clock passage,
the hidden experiments and the moral consequences draw on the supplied comic. Ada and
the patient rescue puzzle chain expand that premise.

## Presentation

The framebuffer is genuinely 320×200 indexed color (mode 13h; see the mode 13h section below), not a large true-color window with
a pixel filter. Sixteen room backgrounds and a 320×154 back-seat car backdrop share the same 256-entry palette.
The top ten pixels hold the room title; the scene includes visible exit plates; the bottom
46 pixels hold verbs, inventory and contextual text. Sixteen palette entries are reserved for
readable UI and accents. Nine 48×73 indexed character masters provide the protagonist, seven NPCs
and a walking pose. They are exported from the original art with the visible silhouette cropped
before resizing, so transparent margins do not shrink people or lift their feet off the floor.
uGL mask index 227 is reserved in sprites and conversation portraits. All scene art is newly generated.

The runtime uses memory DCs and one video page. Backgrounds are loaded one room at a time.
Room-specific staging sets the player's height to 76–88 pixels, with NPCs scaled for their
floor depth. Character sizes, spawn points, floor limits, and NPC hit regions agree. Nine
sprites are prepared once on room entry with nearest-neighbor sampling, then normal frames
use fast masked blits. Every cached bitmap has a 48-pixel-wide canvas to meet uGL's alignment
requirement. Characters remain above the exit controls and walking stays within the room's
foreground floor limits. James turns toward the player's current position, including when
the player walks past him. Mouse input uses standard INT 33h position polling, like
the original game: driver X coordinates 0–639 map to screen X 0–319, and Y spans 0–239.
There is no relative-movement callback or accumulated motion counter. A small saved-background
cursor sprite updates between text draws and during frame pacing, independently of full scene
redraws. Driver press counts retain brief clicks. Input is checked each display frame, paced by VGA retrace;
walking and rain advance every second frame. Retrace waits have a timeout for VESA
implementations with a static status bit. The DOSBox-X launcher uses `cycles=fixed 50000`
because `cycles=auto` leaves this real-mode program at just 3,000 cycles/ms.
The launcher uses nearest-neighbor OpenGL output, disables automatic capture, and sets
`mouse_emulation=never` so the uncaptured pointer follows the host position. It closes the
emulator on quitting the game.
Walking is intentionally restricted to the foreground staging
area; this edition does not provide the classic engine's detailed obstacle navigation or its
3D character renderer. PC speaker puzzle tones are optional with S. The new narrative has
no timer deaths and failed puzzle attempts do not consume unique items.

The opening begins in the back seat of a vintage motorcar approaching Ravenhurst in
rain. The coachman drives on the left; the windscreen view remains visible during speech,
with a named panel and a tail indicating the driver or the player in the back seat.
Their exchange establishes the invitation, recent graduation, chemistry training and
apprenticeship. Optional questions introduce Arthur Pike and his past with horses; his
racing silks suggest personal history without confirming a diagnosis. Escape skips to
arrival, and the journal retains the essential premise.

Outside, the revised background parks the car on the left. Pike stands beside it and
encourages shelter; James is no longer standing at the gates. ACT on the physical front
door or click FRONT DOOR to knock. James greets the player and offers an invitation
handover; selecting the inventory letter before knocking also works. Declining leaves
the player outside. Acceptance fades into the distinct entrance hall and its first-arrival
conversation. Returning outside retains Pike's answered questions and
learned sources from the ride. Navigation plates work in every verb mode; LOOK on the
physical door still examines it. The existing sixteen-room save graph is unchanged.

James's current dialogue follows the author's corrections in
[James Background And Motivation](https://chatgpt.com/share/6ad96c58-53ac-83ea-b285-e8b151618f6c).
He is a patient who believed himself Mahler's colleague, whose willingness Mahler exploited
as the experiments became inhumane. Shortly before the game, Mahler's cruel rejection of
that identity prompted James to kill him. James then adopted the identity of a long-serving
butler and sincerely believes the doctor is alive. The other patients' staff roles and their
silence about the lower ward protect a shared appearance of ordinary household life.
This is author-facing continuity, not information James supplies at the door. His dialogue
never confesses; questions about patients need outside evidence, and when the player says what
they found he deflects into household routine. The murder investigation and the other
characters' rescue dialogue are not yet revised.

## Conversations (B4 design)

The look and flow were designed in `docs/mockups/` (direction B4, name placement T1) and built in
`VGADIAL.BAS`, `VGASAY.BAS`, `VGAFACE.BAS` and `VGATOPIC.BAS`.

**Layout.** One fixed panel (x 5-314, y 145-196) is used for menus and speech, so nothing moves
between frames. Under the room picture is a warm leather band. You always stand on the left, the
other person on the right and mirrored so they face you; both busts are the full 96x75 art, their
lower rows tucked behind the panel. The bubble is black with a white double outline for everyone (a pale-blue-for-you variant was
mocked up and rejected: the tail and the name are enough). A small tail rises from the panel to the
speaker. The speaker's name is a gold header with a thin grey rule inside the panel, on their side
("YOU" left, the other person right). Text is white in the game's 7 px font, at most three 272 px
lines per page. Tickets are dark grey with a gold number; the hovered ticket is white with a red stub.

**Flow.** One click, Enter or Space anywhere does everything: the first finishes the typewriter,
the next goes to the following page of a long reply (replies are split into three-line pages
automatically), and the last one moves on. There is no Continue or Back button, only a small red
"more" marker. Esc or right-click inside a spoken line skips the rest of that line (in the car it
still jumps to arrival). The conversation starts with the person's greeting. Then the question
menu shows up to three **tickets**: gold paper rows with a numbered stub; the hovered or
keyboard-focused ticket turns cream with a red stub and arrow. Click, press 1-3, Tab or Down/Up
and Enter. **Leave [Esc]** is a text button on the right of the header (right-click and Esc also
leave). Choosing a question makes *you* say it out loud (your blue panel, which moves on by
itself after a short beat; a click skips it) before they answer, then the menu returns.

**Topics.** A question you have asked disappears and the next unasked one takes its place; new
questions appear as you discover and learn things (clue questions are listed first in each
person's order, so they surface as slots free up). Topics whose answer changes with the story
(James on the patients, Elias on the ward key) stay in the menu after being asked. When nothing is
left the panel says so and Leave remains. There is no paging, no colour legend and no clue stars
in the menu; the journal (J) and the Learn/SourceName$ knowledge log still record where each fact
came from. Asked history is still stored as six-bit masks in flags 20-25 and 27 (flag 26 is legacy
outdoor James) and is saved and loaded as before. Pike is NPC 8; flags 28 and 29 record his
introduction and the observed racing silks.

**Engine notes.** Panel, tail and tickets are built from a few filled rectangles, 1 px lines and
single pixels (`RRect`, `DrawPanel`, `DrawTail`, `DrawTickets` in `VGASAY.BAS`); nothing is drawn
per frame beyond what the screen redraw already does. Only the two full-size portraits are loaded
and they reload only when an expression changes. Palette slots 242 and 248 (leather shadow and
band), 253 (pale blue, now unused) and 254 (paper white, the outline and text colour) were added to the reserved UI colours.
`testforce` is a test-only hook that asks any currently allowed topic regardless of where it sits
in the menu.

## Mode 13h (320x200) edition

The game first ran at 320x240 (a VESA-only mode that DOSBox-X's S3 emulation offers but real
cards and the emulated Cirrus 486 do not). It now uses standard VGA mode 13h, 320x200. A 4:3
monitor stretches 200 lines to full height, so art keeps its width and its height is scaled:
rooms and the car view are 320x154 (was 184), the title bar is 10 lines, and the bottom panel
(verbs at y 156, inventory at y 168, status text at y 192) is 46 lines (was 56). Character sprite
masters are 48x73 (drawn about 64-74 lines tall; their width formula is `2 * ((height * 29 + 44) \ 88)`).
Portraits are 96x75 (28 expressions plus the coachman's, one size for both people): scaled by 5/6, then the bottom
12 rows are cropped (the panel covers them). Conversation layout: see the Conversations section (busts at y 75, panel y 145-196). Puzzle/modal panels start at y 12. Hotspot and floor y values were scaled by 154/184
(exit plates are 10 lines tall at y 143).

The Python exporters write the shipping 13h set directly (shared constants and the 5/6 squash +
portrait crop live in `tools/vga_common.py`). Run `build_vga_assets.py`, then
`build_vga_opening.py`, then `build_vga_story.py` (needs Pillow). `verify_vga_assets.py` checks the result.

486 note: QuickBASIC's `^` operator is a software floating-point routine, about 1 ms per call
on an FPU-less 486SX. `Txt` used it per glyph row and a frame took 1.4 s on the emulated SX;
integer `Pow2%` brought it to about 55 ms. Avoid `^`, `ATN` and other float math in per-frame code.

## Source map

| File | Responsibility |
| --- | --- |
| `VISIONS.BAS` | Startup, data loading, main input loop |
| `VGA.BI` | Shared declarations and COMMON layout |
| `VGADRAW.BAS` | Font, scene, sprites, inventory |
| `VGADIAL.BAS` | Conversation layout, question history, modal input |
| `VGAFACE.BAS` | Expression selection, portrait cache, transparent facing busts, speaker focus |
| `VGASAY.BAS` | Speaker-linked text, nonblocking reveal timing and stable partial-word wrapping |
| `VGAMOUSE.BAS` | Standard DOS mouse polling, saved-background cursor, display presentation |
| `VGAACT.BAS` | Hotspot actions and puzzle state transitions |
| `VGATALK.BAS` | Conversations, contextual journal and location guide |
| `VGATRIP.BAS` | Travel, front-door transition and hall arrival |
| `VGAPEOP.BAS` | Room-specific character sizes, feet, click regions and floor limits |
| `VGASAVE.BAS` | Validated save loading and saves |
| `VGAKNOW.BAS` | Discovery sources, observation hooks and old-save knowledge recovery |
| `VGATOPIC.BAS` | Context-sensitive topic lists; the menu shows the first three unasked questions |
| `VGATEST.BAS` | Main DOS regression harness and native framebuffer dumps |
| `VGAPTEST.BAS` | Portrait compositing, expression, focus and input regression checks |
| `VGASTEST.BAS` | Speech pacing, reveal input, text layout and single-speaker regression checks |
| `VGAKTEST.BAS` | Discovery gating, cross-character clues, vanishing/repeatable topics, stable history and save migration checks |
| `tools/build_vga_story.py` | Editable room graph, rectangles, descriptions; exports WORLD.DAT |
| `tools/build_vga_assets.py` | Shared palette, native-size backgrounds, sprites, original font export |
| `tools/build_vga_characters.py` | Re-export 48×73 sprites from the original master without touching backgrounds |
| `tools/vga_common.py` | Mode 13h constants and helpers: scene size, 5/6 vertical squash, portrait crop, mask-aware palette quantize |
| `tools/build_vga_portraits.py` | Hands the portrait masters to the expression exporter (the old boxed FACE/YOU bitmaps are gone) |
| `tools/build_vga_expressions.py` | Export 28 expressions at 96x75 (28 masked BMPs) |
| `tools/build_vga.ps1` | BC/LINK build and isolated DOSBox-X test execution |

Python asset exporters require Pillow. Neither compilation nor playing needs an API key or
network service. QB source uses CRLF and the compiler's `/O /W /X` options. The split keeps
the source within the compiler's memory and DOS segment limits. uGL is statically linked;
the distributable does not include the QuickBASIC compiler or runtime libraries.

## Art provenance and generation prompts

Created using the **built-in imagegen tool**, with locally inspected comic pages as style
references. Master files: `src/ART/visions-atlas.png` and `src/ART/visions-characters.png`.
All shipping backgrounds and character bitmaps live in `src/VGA`. The background contact
sheet is `src/ART/vga-contact-sheet.png`. No game asset points into a temporary imagegen directory.

Background prompt: a four-column, four-row atlas of sixteen distinct playable gothic
Victorian rooms; no people, lettering or interface; detailed 1993 VGA adventure pixel art,
ink-dark architecture, amber oil lamps, blue rain, readable silhouettes and open foregrounds.
In order: rainy manor gates, grand entrance hall, guest bedroom with grandfather clock,
library, dining room, glass conservatory, physician's study and safe, attic laboratory,
hidden stone stair, patient ward, record archive, boiler room, abandoned chapel and organ,
lakeside boathouse, electrical generator room, subterranean reservoir and bridge.
Comic references: chapter 1 opening and chapter 4 attic laboratory contact sheets.

Character prompt: transparent eight-column full-body sprite sheet; young dark curly-haired
chemistry graduate in charcoal Victorian suit; older mustached housekeeper James;
Elias in a blue waistcoat; gardener Ada in an olive work dress; Clara in sage dress and
shawl; Thomas in grey vest and trousers; Miriam in burgundy dress and pale shawl;
the same protagonist walking. Grounded proportions, readable faces and silhouettes,
amber light, cool shadows, crisp VGA pixel-art treatment, no scenery or text.

## Validation and limitations

*Note: the paragraphs below record the testing of the first prototype's dialog (paging, blue asked colours, a Goodbye
button, boxed portraits). The B4 redesign described under Conversations replaced those details; the harness was updated
to match (276 DOS checks, 0 failures) and a live run on an emulated 486SX covered the new flow.*

The original portrait masters in `src/ART/portraits/` were generated individually with the
built-in imagegen tool using `visions-characters.png` for identity/costume reference. Their
prompts remain in `prompts.json`. Seven new transparent 2×2 expression sheets were generated
with the same tool, using those individual portraits as identity references. These masters
are `expressions-00.png` through `expressions-06.png`; full prompts are in
`expression-prompts.json`, and the indexed results appear in `expression-contact-sheet.png`.
The exporter preserves generated alpha as the DOS mask and maps colors to the shared palette.
Runtime assets are `VGA/P00A.BMP` through `P63L.BMP` (person, expression, active/listening).
The superseded boxed FACE/YOU bitmaps were removed; the master art stays in source.

`build_vga.ps1 -Test` builds all nineteen modules and runs `VISIONS.EXE /TEST` in `tmp/vga-qa`.
It loads and renders all sixteen rooms, checks prerequisite gates, runs the complete puzzle
chain, rejects wrong answers, checks both endings, verifies save/load restoration, and rejects
a corrupt or missing save without replacing current progress. Cursor tests check movement
without another game frame, background restoration, shape changes, cursor/input alignment,
both screen corners, small movements in both directions, stationary polling and false clicks.
The opening checks cover the blocked front door, outdoor dialogue, the invitation,
journal guidance, first arrival, both directions, and exit buttons in LOOK/TALK modes.
Rendered-pixel checks verify human scale and feet placement in all sixteen rooms; head
hit tests cover every speaking character's enlarged click area. Conversation checks verify
that leaving James or Elias does not advance the invitation or grant the ward key.
Scripted conversations ask all three topics, repeat a question, and choose Goodbye for
every character, including Pike in the car and outside. History checks cover individual questions,
repeated selection, separate NPC histories, save/load persistence, invalid history, and older
saves without history. Portrait checks compare every pixel of both rendered faces for all
four expressions and both speaking/choosing states with each NPC. They verify horizontal
flipping, transparent scenery between silhouette edges, large/small focus, cache reuse,
expression transitions, remembered replies, input rectangles and cleanup. Dialogue length
and topic width are checked during every scripted conversation.
The native portrait menu and reply dumps were visually reviewed. The dialogue fits within
320×200 with room scenery above the text and the toolbar temporarily covered.
All **270 DOS checks passed**; results are recorded in `vga-test-results.txt`. The linker reserves
an 8 KB stack for the nested conversation calls and native test fixtures. James checks cover
the absence of early patient revelations, names-only place cards, external clue sources,
ledger-only, ward-only and combined evidence replies, and repeatable observation questions.
Native frame dumps verify the revised courteous and worried replies with portraits.
Discovery checks cover fresh menus, LOOK/ACT evidence,
cross-character knowledge, immediate follow-ups, partial rescue preparation, all 42 topics,
page arrows and blank rows, stable history after insertion, first-source retention, DVGA1
migration and corrupt/truncated DVGA2 files. Speech checks verify progressive timing, punctuation pauses,
midnight rollover, stall handling, reveal-before-continue input, fixed word wrapping,
speaker-tail direction, removal of repeated questions and cleanup. Earlier live DOSBox-X
checks confirmed inward-facing portraits, expression changes, speaker size/brightness,
question history and repeated conversations. Existing player saves were unchanged.
The current build was also checked live: the greeting and an answer visibly printed a
few letters at a time; continuing switched to the player-only choices, moved the speech
tail to the left and retained blue asked-topic text. Fast reveal/continue separation is
covered by the deterministic DOS input tests.
The native opening dumps show the full car view, driver speech, player speech and revised
exterior. The test harness exercises skipping, complete arrival, invitation redirection,
return visits, independent NPC history, all coachman expressions and DVGA2 migration.
The rebuilt game was launched in DOSBox-X and the live car dialogue was visually checked:
the rain-streaked windscreen remains visible, speaker text is legible, and the Continue
button sits below the speech panel. The running playthrough was left open.
The separate `verify_vga_assets.py` check validates the palette, sprites, hotspot bounds and
gated room graph. The DOS harness exports native frame dumps for visual
inspection. No tests write into the player's save directory.

Manual DOSBox-X checks cover intro/help layout, keyboard hotspot focus, dialogue choices,
the clickable Goodbye button, right-click cancellation, normal question responses,
asking multiple questions in one conversation before choosing Goodbye, blue asked-topic
text with gold unasked topics, repeating a blue question, and mouse positioning without
capture. Live checks clicked both intro buttons at different
horizontal positions, targeted the bottom inventory row, and moved nine host pixels up and
down (three game pixels) without jumping to an edge. The revised opening was checked live
from an existing save in an earlier build: GO INSIDE with LOOK selected displays the staircase hall and first-arrival
dialogue, and Go outside with TALK selected returns to the exterior. F9 was also checked live;
extended scan codes are preserved rather than lowercased with text input.
All sixteen native DOS room dumps were visually reviewed after the character scale adjustment.
The launcher leaves the mouse uncaptured; Ctrl+F10
can release it if the player manually captures it. Physical DOS
hardware is unverified (an emulated 486SX in 86Box runs it).

There are three explicit save slots. The ending writes completed progress to slot 3.
The map is a text connection guide, not a fast-travel system. New saves use the DVGA3 header:
the existing room/flags/inventory/visited fields, followed by fourteen discovery-source values.
The loader accepts DVGA1 and DVGA2 as well, retaining puzzle progress and asked history, and recovering
knowledge justified by inventory, completed tasks and recorded answers. Unrecorded old LOOK
actions cannot be recovered; those clues can be examined again. Validation is performed on
temporary arrays, so invalid or truncated files cannot replace the current journey. VGA saves
do not import the original CGA edition's saves. The original game is preserved separately.

## Car opening asset provenance

The built-in image_gen tool generated `ART/opening/car-interior.png` and
`ART/opening/exterior-car.png` using the approved coachman sheet and prior manor view.
It also extracted true transparent production cutouts into
`ART/coachman/coachman-cutouts.png`; the approved character sheet remains intact.
The exact prompts and references are preserved in `ART/opening/generation.json`.
`tools/build_vga_opening.py` crops, scales and quantizes these assets to the existing
palette, exporting `CAR.BMP`, the revised `RM01.BMP`, `CHAR08.BMP`, and eight `P8*` portraits.
`VGARIDE.BAS` owns the opening, Pike's answers and the front-door greeting.
`VGARTEST.BAS` covers this sequence in the isolated native DOS harness.
