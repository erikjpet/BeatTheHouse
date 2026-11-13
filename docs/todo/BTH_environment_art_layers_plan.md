# Beat the House — layered environment art: implementation plan

Plan date: 2026-11-13
Written against: `main` at `e5152c3`
For: a worker agent making the code changes. The art itself is delivered
separately as drop-in asset packs that follow the contract in section 3.

Suggested ledger ID: `BTH-ENVART-001` (parent), with one batch per phase.
Save this file as `docs/todo/BTH_environment_art_layers_plan.md`.

---

## 1. Goal

Rooms are currently painted by code, one hand-written routine per room made of
rectangles and lines. Change the room renderer so a room is assembled from
**editable art files in four layers**:

| Layer | What it is | Source after this work |
| --- | --- | --- |
| 1. Background | The static room | One PNG per room |
| 2. Animation | The things that move, flicker and glow | Small PNGs plus a list of animation entries in a JSON file |
| 3. Counters | Counter fronts that people stand behind | One PNG per counter |
| 4. Objects | Machines, staff, doors, items, labels | **Unchanged** — the existing live object system |

The room must feel as alive as it does today. An artist must be able to change
how a room looks or moves by editing a PNG or a JSON file, with no code change.

Rooms without an art pack keep working exactly as they do now, so the code can
land before the art does.

### Owner decisions (2026-11-13)

- **Art is authored at double the room grid**: backgrounds are 1800×860. The
  900×430 grid stays as the coordinate system for layout only.
- **All 20 rooms are in scope.** The code is built and proven on the Gas
  Station Casino, then every other room goes live as its pack is dropped in.
  The 20 packs are being produced in parallel and arrive as one drop-in folder
  (section 3, "Delivery").
- **The art may add set dressing** beyond what the code draws today. Every
  existing fixture stays where it is and the object positions stay clear.
- **Existing animation motifs are kept** per room, redrawn; packs may add more.
- **Scenarios stay tint-only.** No per-scenario backgrounds in this work.
- **The main menu shows the new rooms as they appear in the game** (Phase 9).
  The old flat room PNGs are retired.
- **The travel doorway images are replaced** to match the new interiors
  (Phase 10).

## 2. How rooms are drawn today

Everything is in `scripts/ui/pixel_scene_canvas.gd` (`PixelSceneCanvas`). All
coordinates are on a fixed 900×430 board (`ArtContracts.ENVIRONMENT_BOARD_SIZE`)
that `_scale_canvas()` maps to the screen with the camera zoom and offset.

`_draw()` (around line 3894) runs this order every redraw:

1. `_bg()` — dark striped fill.
2. **The room.** If `use_external_background` and `background_texture` are set,
   one `draw_texture_rect`; otherwise a `match environment_id` that calls one of
   20 routines (`_draw_corner_store`, `_draw_gas_station`, …). Only the main
   menu sets the texture path today (`foundation_main.gd`,
   `_reroll_main_menu_background`), so in play every room is code-drawn.
3. `_draw_authored_counter_foregrounds()` — counter fronts, code-drawn per
   `foreground_art_id` in `_draw_counter_foreground_art()` (21 ids across the
   maps in `data/environments/placement_surfaces.json`).
4. `_draw_scenario_palette()` — a 12% colour wash chosen by the scenario.
5. `_draw_scene_life()` — the per-room animation, also code: a `match
   environment_id` that calls 11 primitives (`_draw_sign_pulse`,
   `_draw_scan_bands`, `_draw_sparkles`, `_draw_light_cone`,
   `_draw_rain_streaks`, `_draw_puddle_ripples`, `_draw_smoke_bands`,
   `_draw_camera_sweep`, `_draw_headlights`, `_draw_string_lights`,
   `_draw_floor_sheen`) with hard-coded rectangles and colours.
6. Focus dim, then `_draw_scene_objects()`. Inside it, after people who stand
   behind a counter are drawn, that counter's front is drawn **again** so it
   covers their lower body (the loop ending near line 8728).
7. Outcome highlight, pressure, drunk and developer overlays.

Time and scheduling:

- All animation is a function of one clock, `flicker` (seconds), advanced in
  `_process()`. It is scaled by `drunk_time_scale` and forced to 0 when
  `reduce_motion` is on.
- Redraws are requested by `_scene_idle_animation_redraw_due()` at 60 fps
  native, 30 fps Web, 15 fps for Grand Casino on Web. This runs with no input.
  **`AGENTS.md` makes this a release gate: do not remove it, tie it to input,
  or suppress it.**

Room identity: `environment_id` is the archetype id, except the Punchline
layers, which use `visual_context.art_key` (`punchline_club`,
`punchline_back_room`). The 20 ids are: `corner_store`, `back_alley`, `motel`,
`motel_room`, `apartment`, `house`, `pawn_shop`, `bar`, `jazz_club`,
`kitty_cat_lounge`, `delta_queen`, `beach`, `gas_station_casino`,
`small_underground_casino`, `punchline_club`, `punchline_back_room`,
`grand_casino`, `grand_casino_high_limit`, `grand_casino_back_room`,
`grand_casino_cage`.

## 3. The art pack contract

This is the interface between the art and the code. The art delivery will
match it exactly; the code must accept it exactly.

### Files

```
data/art/environments/<environment_id>.json      manifest (one per room)
assets/art/environments/<environment_id>/
    background.png                               layer 1
    anim/<name>.png                              layer 2 textures
    counters/<foreground_art_id>.png             layer 3 textures
```

The manifest goes under `data/` on purpose: `export_presets.cfg` already
exports `data/**`, the travel art manifests already live in `data/art/`, and
`export_presets.cfg` is pinned by the NEXT builder and must not be edited. PNGs
under `assets/` are exported as imported resources like the travel art.

The existing flat files `assets/art/environments/<id>.png` stay where they are
until Phase 11. A pack folder `assets/art/environments/<id>/` sits beside the
flat file of the same name without conflict.

### Manifest

```json
{
  "schema": "bth.environment_art/v1",
  "environment_id": "gas_station_casino",
  "board_size": [900, 430],
  "pixel_scale": 2,
  "background": { "texture": "background.png" },
  "animations": [
    { "id": "soffit_lights", "type": "frames",
      "texture": "anim/soffit_lights.png", "frames": 4, "fps": 5,
      "rect": [0, 34, 900, 44], "blend": "add" },
    { "id": "neon_fascia", "type": "pulse",
      "texture": "anim/neon_fascia_glow.png", "rect": [0, 62, 900, 24],
      "min_opacity": 0.55, "max_opacity": 1.0, "period": 1.6, "blend": "add" },
    { "id": "headlights", "type": "mover",
      "texture": "anim/headlight_streak.png", "size": [58, 6],
      "from": [-80, 150], "to": [900, 150], "duration": 6.5,
      "clip": [50, 96, 258, 96], "blend": "add" },
    { "id": "scanline", "type": "scroll",
      "texture": "anim/scanline.png", "rect": [0, 42, 900, 34],
      "speed": [0, 48], "opacity": 0.08, "blend": "add" },
    { "id": "camera_laser", "type": "sweep",
      "texture": "anim/laser.png", "origin": [739, 94],
      "from": [724, 190], "to": [796, 190], "period": 3.5, "blend": "add" }
  ],
  "counters": {
    "gas_station_staff_window": { "texture": "counters/gas_station_staff_window.png" }
  }
}
```

Rules:

- **All positions and rectangles are board coordinates (900×430).**
- **Textures are authored at `pixel_scale` times the rectangle they fill.**
  `pixel_scale` is 2 for every delivered pack: the background is exactly
  1800×860, a counter front is twice its rectangle (including bleed), and each
  animation frame is twice its `rect` or `size`. The renderer always draws a
  texture into its board rectangle and never assumes texture pixels equal
  board pixels. The validator checks these sizes.
- `background.texture` is required. `animations` and `counters` may be empty.
- A counter entry's key is the `foreground_art_id` already present in
  `placement_surfaces.json`. Its texture is drawn into that counter's front
  rectangle (`x0..x1`, `top_y..front_y`), plus an optional
  `"bleed": [left, top, right, bottom]` in board pixels so a counter front can
  extend below or beside its contact rectangle.
- Texture paths are relative to `assets/art/environments/<environment_id>/`.

### Delivery

The art arrives as one folder that mirrors the repository, to be copied over
the repository root:

```
data/art/environments/index.json                 lists all 20 rooms as enabled
data/art/environments/<environment_id>.json      × 20
assets/art/environments/<environment_id>/…       × 20
assets/art/travel/doorways/<id>.png              × 12 replacements (Phase 10)
```

Copying it in must be the only step needed for a room to use its pack. If a
room fails its checks, remove that id from `index.json` and report it; the
room falls back to code.

### Animation entry types (a closed set of five)

Every entry is a pure function of the `flicker` clock. No entry keeps state
between frames. Common optional fields: `blend` (`"mix"` default, or `"add"`),
`opacity` (default 1), `phase` (seconds added to the clock, to de-sync
entries), `web_low_detail` (`false` = skip when the existing Web low-detail
mode is active), `still` (how to show the entry when Reduce Motion is on:
`"first"` default, `"hide"`, or a frame number).

| Type | Behaviour | Required fields |
| --- | --- | --- |
| `frames` | Frame-by-frame. The texture is a horizontal strip of equal frames. `loop` is `"loop"` (default), `"pingpong"` or `"once_hold"`. | `texture`, `frames`, `fps`, `rect` |
| `pulse` | One texture whose opacity moves between `min_opacity` and `max_opacity` on a sine of `period` seconds. For neon and lamps. | `texture`, `rect`, `min_opacity`, `max_opacity`, `period` |
| `mover` | One texture travelling in a straight line from `from` to `to` in `duration` seconds, then repeating. Optional `clip` rectangle (for things seen through a window) and `gap` seconds between passes. May also carry `frames`/`fps`. | `texture`, `size`, `from`, `to`, `duration` |
| `scroll` | A tiling texture scrolling inside `rect` at `speed` board pixels per second. For rain, smoke, water, scan lines. | `texture`, `rect`, `speed` |
| `sweep` | A texture stretched from `origin` to a point that swings between `from` and `to` every `period` seconds. For beams and lasers. | `texture`, `origin`, `from`, `to`, `period` |

This set covers everything the 11 code primitives do today. If a room needs
something else, add a sixth type deliberately; do not add per-room code.

## 4. New draw order

```
_bg()                                   unchanged
if the room has a valid, enabled pack:
    layer 1  background texture
    layer 2  animation entries, in manifest order
else:
    the existing code routine for the room      (unchanged)
layer 3  counter fronts      pack texture if the pack has that id, else existing code
_draw_scenario_palette()
if no pack: _draw_scene_life()                   (unchanged for unmigrated rooms)
focus dim → objects (with the behind-counter replay) → overlays     unchanged
```

Two deliberate differences from today, for migrated rooms only:

- Animation is drawn **under** counters (today it is over them). This is the
  layering the owner asked for.
- The scenario colour wash now also covers the animation layer. It is a 12%
  tint; record a before-and-after capture so the owner can see it.

The behind-counter replay inside `_draw_scene_objects()` must use the same
counter source as the first pass, so a person behind a counter is covered by
the same art that was drawn under them.

## 5. Work phases

Do them in order. Each phase is separately committed and proven.

### Phase 0 — Baseline

- Record Smoke, the animation-liveness check and the Python tests.
- Capture every one of the 20 rooms at 1280×720 with the existing capture
  tool (`tools/environment_layout_screenshots.gd`), idle, no scenario. These
  are the "before" pictures for every later phase.
- Record idle draw cost for the Gas Station Casino on native and on Web with
  the existing perf overlay.

### Phase 1 — Pack loader and validator

New file `scripts/ui/environment_art_pack.gd` (`EnvironmentArtPack`):

- `static func load_pack(environment_id) -> EnvironmentArtPack` reads
  `res://data/art/environments/<id>.json`, validates it, loads its textures,
  and returns `null` with a logged reason on any problem. A bad pack must never
  break a room; the room falls back to code.
- Validation: schema string; id matches; `board_size` equals
  `ArtContracts.ENVIRONMENT_BOARD_SIZE`; every texture exists; every rectangle
  is finite and intersects the board; `frames` ≥ 1 and the strip width divides
  evenly; types are from the closed set; counter keys exist as
  `foreground_art_id` in that room's surface map.
- On load, convert the manifest into typed arrays the draw code can walk
  without allocating (see Phase 3). Parsing happens once per load, never per
  frame.
- Enable list: `data/art/environments/index.json`,
  `{"enabled": ["gas_station_casino"]}`. A pack file that exists but is not
  listed is ignored. This is the per-room switch.

New tool `tools/check_environment_art_pack.py`: the same validation without
the engine, so an artist can check a pack before handing it over. It reads the
PNG sizes directly. Add its tests under `tools/tests/`.

### Phase 2 — Layer 1, background

- In `_render_owned_environment_snapshot()`, after `environment_id` is known,
  resolve the pack for that id (cached; see Phase 6) and keep it in a member.
- In `_draw()`, apply the order in section 4. Leave the existing
  `use_external_background` path alone; the main menu depends on it.
- Texture filtering: follow the travel views, which set
  `TEXTURE_FILTER_NEAREST`. Check the result with the camera moving and at
  1280×720 and 1920×1080. If a 2× background shimmers while the camera eases,
  report it with a capture before changing the approach.

### Phase 3 — Layer 2, animation

- New function `_draw_environment_art_animations(pack)` implementing the five
  types from section 3 as pure functions of `flicker`.
- **No per-frame allocation and no dictionary lookups by string key in the
  draw path.** The project's per-frame cost check
  (`foundation_smoke_content`, "per-frame cost tripwire") scans draw functions
  for `duplicate()`, array construction and string formatting; the new
  functions must pass it. Precompute rectangles, source regions and colours at
  load.
- `mover` with `clip`, and `scroll`, need clipping. Prefer computing the
  visible sub-rectangle and matching texture region arithmetically (straight
  lines and axis-aligned rectangles make this exact) over any per-frame
  clip-node or canvas-group change.
- Reduce Motion: `flicker` is already 0. Honour each entry's `still` field so a
  lamp is shown lit, a passing headlight is hidden, and nothing moves.
- Web low detail: skip entries marked `web_low_detail: false` when
  `_grand_casino_web_low_detail()` is true. Keep that function as the single
  switch.
- Scheduling: change nothing. `_scene_idle_animation_redraw_due()` keeps
  requesting redraws with no input, for packed and unpacked rooms alike.

### Phase 4 — Layer 3, counters

- In `_draw_counter_foreground_art()`, before the `match art_id`, check the
  active pack for that id and draw its texture into the front rectangle (plus
  `bleed`). Return as the code path does. Both call sites (the first pass and
  the behind-counter replay) then use the pack automatically.
- Counters without a pack entry keep their code drawing, even in a migrated
  room.

### Phase 5 — Prove it on the Gas Station Casino

- Build and prove phases 1 to 4 against the Gas Station Casino. A **starter
  pack** is supplied with this plan (`BTH_envart_starter_pack.zip`, to be
  unzipped over the repository root). It is placeholder art whose job is to
  exercise the code: a 1800×860 background, one counter front, and one
  animation of each of the five types. It is replaced by the final pack when
  the delivery folder arrives; nothing in the code may depend on its contents.
- Compare against Phase 0 captures: every object, label and hit rectangle in
  the same place; nothing unreadable against the new background.
- Check with each of the five Gas Station scenarios active, at closing time,
  with Reduce Motion on, and on Web.
- The code routine `_draw_gas_station()` and the Gas Station branch of
  `_draw_scene_life()` **stay in the file** as the fallback until the owner
  accepts the room in play.

### Phase 6 — Loading, memory, size

- Load a pack's textures when its room is about to be shown and release the
  previous room's when it is left. Keep at most the current and previous room
  in memory. The travel cinematic runs before arrival; start a threaded load
  (`ResourceLoader.load_threaded_request`) at departure so the room does not
  hitch on entry. If the textures are not ready on arrival, draw the code
  fallback for those frames; never block and never show an empty room.
- Budget, to be confirmed by measurement: one 1800×860 background is about
  6 MB in video memory. Record Web memory before and after entering the room,
  and the package size change.
- New PNGs reach NEXT through the pipeline's existing cold-import path, the
  way the travel art did. Do not edit builder pins or `export_presets.cfg`.

### Phase 7 — Authoring loop and documentation

- In the existing Environment Library practice rooms (developer mode only),
  add a key that reloads the current room's pack from disk, so an artist can
  save a PNG or JSON and see it without restarting. Packaged builds do not
  expose it.
- `docs/art/environment_art_packs.md`: the contract in section 3 in plain
  language, the board grid, the list of counters per room, how to run the
  checker, how to preview, and the rules in section 7.

### Phase 8 — All 20 rooms

When the delivery folder arrives, copy it in and run the pack checker over all
20. Then, for each room:

1. Compare with its Phase 0 capture: every object, label and hit rectangle is
   where it was, and each one is readable against the new art. A live object
   sitting on a busy part of the background is a finding to report with a
   capture, not something to fix by moving the object or editing the art.
2. Check it idle, with one scenario active, with Reduce Motion on, and on Web.
3. Punchline has three ids (`small_underground_casino`, `punchline_club`,
   `punchline_back_room`) and the Grand Casino four. Confirm each layer shows
   its own pack, including after a layer change inside the venue and after
   Continue.

No code change should be needed per room. If one is, the contract was
incomplete: fix the contract, not the room. A room that fails is removed from
`index.json` and reported; the others still ship.

### Phase 9 — Main menu uses the new rooms

The menu backdrop is a `PixelSceneCanvas` fed by
`_reroll_main_menu_background()` in `scripts/ui/foundation_main.gd`. Today it
picks among archetypes that have a `visual_context.asset_path` and shows that
flat PNG through `use_external_background`.

- Change the candidate list in `_select_main_menu_background_environment()` to
  rooms that have an **enabled art pack**.
- For a room with a pack, do not set `background_texture` or
  `use_external_background`; let the canvas draw the pack (background and
  animation) exactly as it does in play.
- Only if no pack is enabled at all, keep today's behaviour as the fallback.
- The menu must keep animating with no input, and
  `tools/main_menu_redesign_check.gd` must still pass or be updated to the new
  source with its guarantees intact.

### Phase 10 — Travel doorway images

The delivery replaces the 12 files in `assets/art/travel/doorways/`. Each
replacement has the **same path and the same pixel size** as the file it
replaces (1024×1536, except `pawn_shop.png` at 1086×1448), so the sizes
recorded in `data/art/art_manifest.json` and the `doorway_reference_size`
values in the `data/art/travel_*.json` files stay correct.

- Copy them in; change no travel data or code.
- Run the existing travel checks and watch each of the 12 entrances once on
  NEXT: the door opens onto the new interior with no stretch or seam.
- Update the hashes and the "generated with" notes in the three
  `*_doorways_generation.md` files beside them to describe the new files.

### Phase 11 — Retiring the old sources (later, on owner approval only)

When the owner has accepted a room in play, its `_draw_<room>()` routine and
its `_draw_scene_life()` branch can be deleted in a separate commit. When all
20 are gone, delete the 11 primitives and `_draw_floor_sheen()`. The old flat
files `assets/art/environments/<id>.png` and the `asset_path` values that point
at them are retired in the same step, once the menu no longer reads them.

## 6. Checks to add

- `scripts/tests/environment_art_pack_contract.gd`: valid pack loads; each
  invalid case (missing texture, wrong board size, unknown type, bad counter
  id, uneven frame strip) returns null and the room still draws from code.
- Draw-order check: with a pack, background then animation then counters;
  behind-counter replay uses the pack texture.
- Time check: each animation type gives the documented value at fixed clock
  times; with Reduce Motion nothing differs between two clock times.
- Unmigrated-room check: a room not in `index.json` draws exactly as before
  (compare captures from Phase 0).
- `animation_liveness_without_pointer_check.gd` must pass unchanged, with a
  packed room on screen.
- The per-frame cost check must pass for the new functions.

## 7. Rules

- `AGENTS.md` wins over this plan. Register IDs in both ledger views before
  starting; nothing is Complete without a commit, evidence and NEXT delivery.
- **Never** disable canvas processing, remove autonomous redraws, tie redraws
  to input, or pause animation while a placement overlay is open.
- Do not change: the object layer, hit testing, labels, slot or counter
  coordinates, `placement_surfaces.json` geometry, the board size, the camera,
  scenario logic, game rules or payouts.
- Do not change `export_presets.cfg`, `project.godot` or any pipeline pin.
- Do not delete any code-drawn room or old flat PNG in this task (Phase 11 is
  separate).
- Do not redraw, recolour or "improve" delivered art. If a pack looks wrong in
  the game, report it with a capture.
- Reproduce before changing; one phase per commit with its ID in the message;
  proof file per phase under `docs/testing/`; raw evidence stays under
  `E:\CodexQA\BTH`, not in the repository.

## 8. Done when

- All 20 rooms are drawn from their packs on NEXT, each animating with no
  input, on native and Web; any room that could not go live is listed with its
  reason.
- Editing a background, an animation PNG or a manifest changes the room with
  no code change, shown by a recorded reload in the Environment Library.
- The main menu shows a packed room, drawn and animating as it is in play.
- The 12 travel entrances open onto the new interiors.
- Smoke, liveness and Python results are no worse than the Phase 0 baseline,
  and idle draw cost for the room is no higher than before.
