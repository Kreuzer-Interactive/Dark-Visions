# Dark Visions — Data-Driven Animation & Scene-Layer System (Spec)

Status: **design agreed, not yet implemented.** Authored 2026-06-18.

## Goal
Replace the hardcoded animation/event routines (`DoorOpen`, `golf`, `wilb`, the
intro/burn/ending cutscenes) with one **data-driven** system, authored in the web
editor, that supports:

- **Sprite / region animations** placed in a scene (candle flicker, machinery).
- **Full-background animations & state swaps** (cutscenes, flooded/dark rooms).
- **Palette effects** (the burn/fade colour-cycling) as data.
- **State-based scene changes** (overlays, exits) driven by the existing `ob()` flags.

This is the proven pattern from the Dark Visions family (DARKV2, DreamGiver/ARUNNER,
Space/RUNNER at `C:\Code\darkv-bas\Decompile\Other Code`), generalized into two
reusable layers. Notably **DARKV2 is a Dark Visions build where the author already
replaced the bespoke death/door SUBs with a generic frame-player + overlay table** —
so this is the natural, in-family evolution of *this* engine, not an invention.

## Two layers (define once, place many)
1. **Animation library** (global, reusable) — file `ANIMS.PAC`. Named animations =
   frames + timing + mode + palette. Authored in the **Animation tab**.
2. **Placements** (per-scene) — appended to each room's `.pac`. Lightweight instances
   that reference a library animation + position + condition. Authored in the
   **Hit Areas tab**.

(Same separation AGS uses: reusable *Views* + per-room *Objects*.)

---

## Data model

### Animation library — `ANIMS.PAC`
One record per animation, `WRITE#` format (quoted strings + bare numbers, CRLF):

```
id, "name", "type", "source", "frames", rate, "mode", "pal", "snd"
```

| field  | meaning |
|--------|---------|
| id     | integer, referenced by placements |
| name   | editor label |
| type   | `spr` = sprite frames (`.pct`) · `bg` = full-screen images (`.pic`) · `pal` = palette-only effect (cycle the 4 colours, image unchanged) |
| source | `spr`: the `.pct` base name (mask `.msk` implied) · `bg`/`pal`: `""` |
| frames | `spr`: frame indices into the `.pct`, e.g. `"0;1;2"` (or `"*"` = all) · `bg`: `.pic` names, e.g. `"burn1;burn2;burn3"` · `pal`: palette tuples, e.g. `"0 14 12 4;0 12 8 4;0 8 2 6"` |
| rate   | ticks per frame (hold time); 0 = static (never advances) |
| mode   | `loop` · `once` · `hold` · `static` |
| pal    | base palette `"co pa1 pa2 pa3"` used by `bg` (its `.pic`s) and as the `pal` start; `spr` leaves it `""` and **inherits the room palette** |
| snd    | optional QB `PLAY` string; played once when a `once`/`hold` animation fires (e.g. the door's open tune). Empty = silent |

**Modes**
- `loop`   — cycle forever while active (candle).
- `once`   — play through once on activation, then hide.
- `hold`   — play once on activation, freeze on the last frame (door → stays open).
- `static` — no animation; show frame[last] while active (a state overlay — lamp on).
- `random min max` — cycle forever like `loop`, but every frame holds for a random `min..max`
  **seconds** instead of the fixed `rate` (`rate` is ignored) — a curtain stirring in a breeze.
  The two numbers ride inside the mode field (e.g. `"random 0.2 1"`) so the record stays
  9 fields; each wait is rolled separately, so several placements never move in step.
- `move` — the sprite itself **travels**: the frames field holds a 1px-step script instead of
  frame indices — `;`-separated tokens of `u/d/l/r` (combined for diagonals: `ul`, `dr`) with
  an optional repeat count (`ul5`); `p` = pause in place (`p6` = hold 6 steps — any token
  with no direction letters is a zero-move step). Each step lasts `rate` ticks; frame 0 is
  drawn. **Before the trigger fires, the placement shows frame 0 at its start spot** (cond is
  the travel trigger, not visibility — so a clock is on the wall from the first visit and the
  background art needn't contain it); the engine keeps the background under the idle frame
  and lifts it cleanly when the travel starts. After playing, the sprite
  settles wherever the script ends (and re-entering the room shows it at that end spot).
  Plays once via the placement's cond/set flags, exactly like `hold` — the player stays drawn
  while it moves. Max 60 steps. Example — a clock that shudders then slides up-left and eases
  back: `"u;d;u;d;u;d;ul5;dr2"`.

Examples:
```
1,"Candle flicker","spr","candle","0;1;2",6,"loop","",""
2,"Door opening","spr","door","0;1;2;3",2,"hold","","<<f6p20d7p20g-7p20e-7p20a5>>"
3,"Burn cutscene","bg","","burn1;burn2;burn3",10,"once","0 14 12 4",""
4,"Lamp on","spr","lamp","0",0,"static","",""
5,"Burn fire cycle","pal","","0 14 12 4;0 12 8 4;0 8 2 6",4,"loop","0 14 12 4",""
```

### Placements — appended to the room `.pac`
After the 25 object records, a list read **until EOF** (so old `.pac`s with no list =
zero animations — backward-compatible, exactly like the `nopl` header flag):

```
animId, x, y, cond, set
```

| field  | meaning |
|--------|---------|
| animId | references a library animation (>= 1) |
| x, y   | position (ignored for `bg`/`pal` — full-screen) |
| cond   | `ob()` flag that must be ON for this placement to be active; 0 = always; **negative** = active while `ob(-cond)` is **OFF** (a tick-tock pendulum until the clock slides) — a running loop freezes the moment the flag turns on, and negative conds never trigger mid-room plays |
| set    | "played" flag — after a `once`/`hold` animation plays its first time, the engine sets `ob(set)=1`; thereafter the placement skips the animation and shows only the end frame. 0 = no marker (replays on each activation). **This makes "door opens once, then stays open forever" work.** |

Example (ROOM3.PAC, after the objects):
```
1,50,40,0,0      ' candle: shows always, loops forever
2,175,109,42,43  ' door: shows when ob(42); plays once, then sets ob(43) so it stays open (mode hold)
```

A **full-background state swap** is just a `bg`/`static` placement
`{altbgAnimId, 0, 0, flag}` — when the flag holds, the full-screen frame is drawn over
the base, replacing it. One mechanism, no special "base override" field.

---

## Palette (base + effects)
Two things, both now **data**, so a new scene/cutscene never needs hardcoded colours.

**1. Base palette as data — so the palette is always known.**
- **Rooms:** already in the `.pac` header `co,pa1,pa2,pa3` (read by `loadroom`). No change.
- **Cutscene / non-room `.pic`s:** today their palette is hardcoded twice — `COLOR`/`PALETTE`
  calls in `GAME.BAS`, and the editor's hand-extracted `CUTSCENE_PAL` map. Move it into
  the **animation entry's `pal` field** (a `bg`/`pal` animation carries the colours of the
  `.pic`s it shows). The editor reads `pal` to render them and the game sets it before
  drawing — **retiring the hardcoded `CUTSCENE_PAL` map** and the in-code `PALETTE` lines.

**2. Palette effects as a `pal` animation type — preserve the existing burn/fade.**
A `pal` animation's *frames are palettes*. The image underneath stays put; the engine just
runs `COLOR co : PALETTE 1,pa1 : PALETTE 2,pa2 : PALETTE 3,pa3` per frame — **no redraw**,
extremely cheap. This is exactly how the current burn/end2 effects work, now expressed as
data (and reusable). `mode hold` settles on a final palette (the burn's end state);
`mode loop` cycles forever; `mode once` plays a fade.

CGA SCREEN 1 supports this — it's limited to remapping the **4 attributes** to other
colours (not the SCREEN-13 256-entry cycling the family's VGA games used), which is all the
existing effects need.

---

## Lifecycle / semantics

**On room enter (`loadroom`)** — for each placement, evaluate its condition (`cond==0`, or `ob(cond)==1`):
- not active → skip (the base `.pic` shows through — e.g. a locked door's closed art).
- active + `loop` → start cycling.
- active + `static` → show frame[last] (a plain state overlay — lamp on); `pal` → set the palette.
- active + `once`/`hold`:
  - **first time** (`set==0`, or `ob(set)==0`) → **PLAY the animation once**, then set `ob(set)=1` (if `set>0`); `hold` leaves the last frame, `once` hides.
  - **already played** (`ob(set)==1`) → skip the animation, just show the end frame (`hold`) or nothing (`once`).

That's the **door** exactly: `cond=ob(unlocked)`, `mode=hold`, `set=ob(door_played)`. The first time you're in the room with it unlocked, it plays the opening **once** and sets `door_played`; every visit after, it just shows the open frame — no animation. `door_played` is a normal `ob()` flag, saved with the game, so it persists for the whole playthrough.

**On flag flip during play** (an interaction's `st` sets `ob(cond)` while you're standing in the room) → the same check runs, so a not-yet-played `once`/`hold` placement **plays once** then marks `set`. So unlocking the door *while you're there* plays it too — entirely from data, replacing the bespoke `DoorOpen`.

**Animation + room change on one interaction:** when the interaction *also* has a target
(`df` — a close-up or room), the engine runs the `reanim` pass **before** leaving, so a
placement triggered by the just-set flag plays first, then the target loads (use key →
door swings open → the closet close-up appears). Because it's play-once-marked, it won't
replay when you come back out.

---

## Engine changes (GAME.BAS)
1. **Library load (startup):** read `ANIMS.PAC` into parallel arrays
   (`anId(), anType$(), anSrc$(), anFrames$(), anRate(), anMode$(), anPal$()`), cap ~50.
2. **`loadroom`:** after the base `.pic` BLOAD + the existing `.pac` parse, read the
   placement list (until EOF) into per-room arrays (`plAnim(), plX(), plY(), plCond()`).
   For each active placement: register an instance; for `spr` ensure its `.pct`/`.msk` is
   loaded; composite `static`/`hold` end-states (and set final palettes) now.
3. **Animation tick** (idle poll loop, gated on a `TIMER`-delta — rides the pending
   throttling work): for each active `loop` instance past its `rate`, advance a frame —
   `spr`: `PUT save-under,PSET` → advance → `PUT mask,AND : PUT frame,OR` (the exact masking
   + save-under already built for the walk/face/golf); `pal`: set the next palette (no draw);
   `bg`: `BLOAD` the next `.pic`.
4. **Interaction → flag re-eval:** where the action handler sets `ob(st)`, call a `reanim`
   pass that activates any now-eligible placements.
5. **Full-bg / palette:** `bg` frames wipe sprite overlays, so don't `loop` a `bg` under
   sprites; reserve `bg` for `once`/`hold`. `pal` is free (no redraw) and composes with
   anything.
6. **Caps:** <= ~8 active sprite instances per room + save-under buffers (DGROUP); `bg`
   loops discouraged (16 KB BLOAD/frame); `pal` is cheap.

---

## Web-app authoring (haedit.html)

### Animation tab — build the library
- List `ANIMS.PAC`; add/edit: pick **type** (sprite / full-bg / palette); pick the
  **source** (`.pct` for sprite; `.pic` frames for full-bg; none for palette); set
  **frames** (sprite frames / `.pic` list / **palette frames built with the existing
  4-colour CGA adjuster** the Backgrounds modal already has); set **rate** + **mode** +
  base **palette**.
- **▶ Preview** plays it on the canvas (reuses the sprite decode + masking; full-bg cycles
  the `.pic`s; palette just re-colours).
- Save → POST `ANIMS.PAC` (new endpoint, mirrors `/api/pac`).

### Hit Areas tab — place into a scene
- A **"Place animation"** tool: pick a library animation → click/drag onto the room (marker
  like a hotspot) → set **cond** via the existing flag dropdown (full-bg/palette ignore x/y).
- **"+ Sprite"** — show a single sprite frame in the scene (usually flag-gated), no animation:
  the editor finds or creates the 1-frame `static` library entry itself and places it.
- Preview on the scene (composite static/hold end-state, or play loops).
- Save → placements write into the room `.pac` (extend `genPac`/`parsePac`; keep the
  round-trip byte-faithful — old `.pac`s gain nothing after the objects).

Everything reuses decoders, the 4-colour palette adjuster, flag dropdowns, and save
endpoints already built.

---

## Phasing
1. **Phase 1 — sprite/region animations.** Library (`spr` type) + placements + the tick +
   Animation tab + the place tool; `loop`/`hold`/`static`. Covers candles, fires, and the
   door-as-data. Self-contained; proves the pipeline end to end. (Sprites inherit the room
   palette, so no palette work needed yet.)
2. **Phase 2 — full-bg, state swaps & palette.** The `bg` and `pal` types; full-screen
   placements/swaps; move cutscene palettes into the `pal` field (retire the editor's
   `CUTSCENE_PAL` map and the in-code `PALETTE` calls); fold in the existing intro/burn/
   ending cutscenes (they become `bg` + `pal` animations).
3. **Phase 3 — richer triggers/conditions.** `cond` negation (flag-off), multi-flag,
   on-interact one-shots, exit rerouting by state.

## Constraints
- CGA SCREEN 1: 4 colours, 320×200. Palette *cycling* DOES work here — it's how the existing
  burn/end2 effects run — but it's limited to remapping the **4 attributes**, not the
  SCREEN-13 256-entry cycling the family's VGA games used.
- Memory: sprite frames + save-unders live in DGROUP — cap active instances; full-bg frames
  load from disk (no RAM blowup) but cost a 16 KB BLOAD each; palette frames are tiny.
- Speed: the tick rides the existing `TIMER`-delta throttle; keep active loops modest.
- Backward-compatible: old `.pac`s (no placement section) load with zero animations.

## Open decisions
- `mode` in the library (per-animation) vs overridable per-placement → start library-only.
- `cond` = single flag-ON for Phase 1; negation / multi-flag later.
- `frames "*"` (use all `.pct` frames in order) shorthand — nice-to-have.
- Animation asset source: reuse `.pct`/`.msk` (decided). New frames authored in Aseprite →
  add `.pct` import (mirrors the `.pic`/`.msk` import); the Animation tab stays a sequencer.
- Standalone (non-animated) cutscene `.pic`s: covered by giving each a 1-frame `bg` entry
  for its `pal`, OR a tiny palette table — decide when we get to Phase 2.
