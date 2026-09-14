Status: DONE — merged to `main` in `d2594eb3`; retained by the 2026-09-14 integration audit

# Agent Prompt — Game Props 01: Room Object Art for Coin Pushers, Scratch Tickets, Craps, and Bar Dice

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before editing — do not plan from this prompt alone.

## Goal

In a room (the main environment screen), every playable game appears as a drawn
object the player clicks to open that game. Three of these objects are already
good: **slots, video poker, and pull tabs**. Each is a detailed, lit,
recognizable cabinet whose front shows a miniature of the game you get when you
open it: reels, five cards and hold buttons, rows of tickets with a plunger.

Four are not good enough, and the owner wants them reworked to the same level:

1. **Coin pusher machines**: all three cabinets, **Quarter Falls**,
   **Jackpot Ridge**, and **Vault Drop**.
2. **Scratch ticket machines.**
3. **Craps tables**: casino craps, and street craps where it appears as its own
   object.
4. **Bar dice.**

Each new object must:

- **Be unique.** It must not be a recolored generic cabinet or a green rectangle
  with an icon. A player should know which game it is **without reading the
  label**.
- **Showcase the specific game.** It should be a miniature, room-scale preview
  of what opening it will roughly look like: the same layout, key elements,
  palette, and identity as the in-game screen. It must not look like a doorway
  to something else.
- **Match the reference detail.** Marquee or signage, body, a miniature play
  area, controls, lights with a gentle idle pulse, base shadow, and
  selected/disabled states. Use the same drawing vocabulary as the references.

## What exists today (verified on main — re-read, line numbers will move)

All room game objects are drawn in `scripts/ui/pixel_scene_canvas.gd`:

- `_apply_draw_hints` → `_production_game_prop(object_data)` (≈3407) picks a
  `prop`:
  - coin pusher → `coin_pusher_machine`;
  - `slot`, `pull_tabs`, `scratch_tickets` → `machine`;
  - craps and bar dice (`family == "dice"`, `environment_prop: "dice_table"` in
    `data/games/games.json`) → `dice_table`.
- `_draw_game_prop` (≈5445) dispatches:
  - `machine` → `_draw_pull_tab_machine_prop`, `_draw_scratch_ticket_machine_prop`,
    or `_draw_slot_cabinet_prop`;
  - `coin_pusher_machine` → `_draw_coin_pusher_room_prop`;
  - `video_poker_machine`, `baccarat_table`, and `roulette_table` → their own
    functions;
  - **everything else, including `dice_table`, falls into a generic green
    rectangle plus `_draw_game_object_icon`.** Craps and bar dice look like any
    card table.
- `_draw_low_detail_game_prop` is the simplified path used by the Grand Casino
  web low-detail mode (`_grand_casino_web_low_detail()`).
- **References (the quality bar — study them closely):**
  - `_draw_slot_cabinet_prop` (≈6254). It reads `object_data.visual_state`
    (cabinet identity, format, reel/row count, live `slot_preview`) produced by
    `scripts/games/slot.gd` `environment_object_state` /
    `_slot_environment_visual_state` (≈1203–1300), so each slot cabinet looks
    like *its* machine and shows its live state.
  - `_draw_video_poker_machine_prop` (≈6810).
  - `_draw_pull_tab_machine_prop` (≈6200).
- **Current weak versions:** `_draw_scratch_ticket_machine_prop` (≈6138),
  `_draw_coin_pusher_room_prop` (≈6158, identical for all three machines), and
  the `dice_table` fallback.
- In-game surfaces (what "opening it" looks like — your source of truth for
  each miniature):
  - Coin pusher: `scripts/games/coin_pusher.gd` + `scripts/games/coin_pusher/`.
    Per-cabinet identity data lives in `data/games/games.json` under the coin
    pusher `cabinet` / `machines` blocks: marquee text, `palette`,
    `topper_style`, `marquee_subline`, `backglass_display`, `body_colors`,
    `colors`. It already implements `environment_object_state`.
  - Scratch tickets: `scripts/games/scratch_tickets.gd`,
    `scripts/games/scratch_ticket_machine_renderer.gd` (in-game machine with
    stock rows), the `scratch_ticket_*_renderer.gd` files,
    `data/games/scratch_tickets.json`.
  - Craps: `scripts/games/craps.gd` + `scripts/games/craps/`, including the
    street variant (`_is_street_variant`, `street_craps` config in `games.json`).
  - Bar dice: `scripts/games/bar_dice.gd` (`surface_renderer: "dice_table"`),
    `data/games/bar_dice_game_ritual_v1.json`.
  - Shared table drawing: `scripts/games/table_game_visuals.gd`.
- Capture tools to reuse:
  - in-game surfaces: `tools/coin_pusher_visual_capture.gd`,
    `tools/scratch_ticket_redesign_capture.gd`,
    `tools/craps_table_visual_capture.ps1`,
    `tools/street_craps_visual_capture.ps1`,
    `tools/game06_6_bar_dice_web_capture.mjs`;
  - real rooms: `tools/environment_layout_screenshots.gd` (run windowed);
  - production room receipts: `tools/env06_8_unlabeled_contact_sheet_probe.gd`
    (it already renders rooms with text removed — a useful model for the "no
    label" check).

## Parallel-work setup (do this first)

Other agents are working in `D:\Projects\Beat-The-House` with **uncommitted
changes to `scripts/ui/pixel_scene_canvas.gd`** (reusable environment spawn
slots) and other environment files. **Do not edit, stage, stash, reset, or
commit anything in that checkout.**

- Create a worktree from `main`:
  `git -C D:\Projects\Beat-The-House worktree add -b codex/game-prop-art D:\Projects\Beat-The-House-worktrees\game-prop-art main`
  If it already exists, reuse it.
- Do all work inside that worktree. The only file you may touch in the main
  checkout is this prompt file (execution record at the end).
- Godot binary: the main checkout's `.tools\godot-4.6-stable\` or
  `$env:GODOT_BIN`; point `GODOT_BIN` at it rather than copying `.tools`.
- **Keep the merge small.** Put the new drawing code in new files:
  `scripts/ui/game_props/coin_pusher_room_prop.gd`, `scratch_ticket_room_prop.gd`,
  `craps_room_prop.gd`, `bar_dice_room_prop.gd`, plus a shared
  `game_prop_kit.gd` if helpers repeat. Use static `draw(canvas, rect,
  object_data, accent, selected, disabled, flicker)` functions, following the
  `ScratchTicketMachineRenderer` pattern. Limit `pixel_scene_canvas.gd` edits to:
  - `_production_game_prop` mapping;
  - the dispatch lines in `_draw_game_prop`;
  - the matching branches of `_draw_low_detail_game_prop`;
  - deleting the replaced old functions.

  Do not reformat or move unrelated code in that file.

## Work

### 1. Study before drawing

For each of the four games, and for the three references, produce a side-by-side
**study sheet** under `.tmp/game_props01/study/`:

- the current room prop, cropped from a real room screenshot at its real size;
- the in-game surface, captured with the existing capture tool, in idle and in
  mid-play;
- a short list of the **five to eight visual elements that make that game
  recognizable**, taken from the surface code and data (not guessed).

Examples of the kind of list expected (verify against the code):

- **Quarter Falls:** carnival brass-and-red cabinet, crown-light topper,
  "QUARTER FALLS" marquee, prize-showcase backglass with rider/2X/5X cases, a
  glass play field with a coin pile and pusher shelf, riders on the pile, a
  payout tray.
- **Jackpot Ridge / Vault Drop:** read their own `cabinet` data. Each must get a
  distinct silhouette, topper, palette, backglass, and play-field feature, not
  just a different color.
- **Scratch tickets:** the in-game dispenser's stock rows with real ticket
  faces/colors from `scratch_tickets.json`, the foil look, the dispense slot, a
  coin/scratch tool, the waste basket if the surface shows it.
- **Craps:** oval/rounded casino rail, felt with the pass line, don't pass, come,
  field and place boxes in recognizable positions, a pair of dice, stickman's
  stick, chip racks, the ON/OFF point puck. **Street craps:** chalk-on-pavement
  layout or wall backstop, loose dice, cash on the ground — whatever the in-game
  street surface actually draws.
- **Bar dice:** bar-top segment, leather dice cup, five dice with visible pips,
  the pot/glass, a coaster or bar mat, the ritual's signature objects.

Record, for every room where each game object can appear, the object's real rect
sizes: smallest, typical, and largest. Sources are `data/environments/archetypes.json`,
`scenarios.json`, `spawn_slots.json` where present, and real captures. Include
small-screen layouts. You design for that size range.

### 2. Draw the new props

For each game, write a room prop that:

- Uses the references' structure: `safe` inset, base shadow, body, identity
  signage/marquee, a **miniature of the in-game play area** as the focal region,
  controls/rails/trays, accent lights with a per-object `phase` pulse, a
  selected outline, a disabled dim/strike, and a small-rect fallback that still
  reads as that game.
- Takes identity from data, not hard-coded per-room branches:
  - coin pusher reads the cabinet identity (`quarter_falls`, `jackpot_ridge`,
    `vault_drop`) and its palette/topper/backglass data;
  - scratch tickets reads the machine's ticket stock;
  - craps reads table vs street variant;
  - bar dice reads its table/ritual variant if one exists.
- **Shows live public state where the game already exposes it**, like the slot
  preview. Add or extend `environment_object_state` / `visual_state` in the game
  module only with player-visible state. Candidates:
  - coin pusher: pile height, riders/features live, busy/occupied;
  - scratch tickets: stock remaining, sold-out rows;
  - craps: point ON/OFF and point number, last roll;
  - bar dice: pot size, table busy.

  Never expose hidden outcomes: no upcoming scratch results, no future dice, no
  coin positions that reveal the physics seed.
- Keeps `_draw_game_runtime_badge` working and unobstructed.
- Adds a matching **low-detail** silhouette in `_draw_low_detail_game_prop` for
  each game. It stays distinct per game but is cheap. Today all machines share
  one "reel" silhouette.
- Does not draw the generic `_draw_game_object_icon` as the main identifier. A
  small icon is fine only if the references do the same.
- Does not change object rects, placement, spawn slots, or room layouts. If a
  game genuinely needs a different aspect ratio or size to read well, **do not
  change it**: record the exact proposal (room, current rect, proposed rect,
  why) for the owner.

### 3. Performance and liveness (hard repo rules)

- **Zero allocation per frame** in the new draw code. No `duplicate()`, no
  building Arrays/Dictionaries, no string formatting of constant text inside
  draw loops. Precompute per-identity palettes/geometry tables as `const` or
  cache them when `object_data` changes. A past per-frame deep copy cost
  32.6 ms/frame, and room/surface redraw cost is already the main source of
  slowness.
- Measure room draw cost before (on `main`) and after, in rooms containing each
  game, with `tools/foundation_performance_probe.gd`: at minimum the Grand
  Casino floor, a gas station/corner store with scratch tickets, a bar with bar
  dice, a room with a coin pusher, and a street craps location. Stay within
  `tools/perf06_budget_table.json`. Do not raise budgets; optimize instead.
- **Idle liveness gate:** perf passes in this repo have frozen idle animation
  four times because idle budgets reward 0.000. The new props must keep a
  visible idle pulse, and the probe's liveness counters
  (`scene_idle_animation_redraw_count` / surface animation redraw counts) must
  still pass. Never accept a 0.000 idle cost without the liveness check.
- Reduce-motion setting: the pulse stops, and the prop stays fully readable.

### 4. Tests

Extend existing tests. Do not create a parallel suite.

- Dispatch: each target game (coin pusher ×3 identities, scratch tickets, craps,
  street craps, bar dice) resolves to its dedicated prop renderer in normal and
  low-detail modes. None hits the generic `dice_table`/card-table fallback.
- Distinctness: render each prop to an offscreen image at typical size. The three
  coin pusher identities differ from each other, and every target prop differs
  from every other game's prop (including the three references), by a
  meaningful pixel-difference threshold. Pick the threshold, document it, and
  prove it fails for today's identical coin pusher cabinets.
- Every size in the recorded range renders without drawing outside its rect and
  without errors, including the small fallback.
- Hidden information: any new `visual_state` fields contain only player-visible
  data.
- The Grand Casino low-detail path and reduce-motion path render all four games.

### 5. Visual review — the acceptance authority

Produce under `.tmp/game_props01/review/`:

1. **Per-game board:** new prop (idle, selected, disabled, live-state variants,
   low-detail, smallest size) next to the in-game surface capture and next to
   the old prop.
2. **Reference lineup:** at the same scale, a single row of slot, video poker,
   pull tabs, the three coin pushers, scratch tickets, craps, street craps, and
   bar dice. Show it once with labels and once with **all text removed**.
3. **Real rooms:** `environment_layout_screenshots.gd` captures of every room
   archetype where each game can appear, in normal and small-screen layout.

Open every PNG yourself. Then run a **blind identification check**: give the
unlabeled lineup, with shuffled order, to a fresh sub-agent that has not seen
this prompt. Ask it to name each game from these options: slot, video poker,
pull tabs, coin pusher, scratch tickets, craps, street craps, bar dice. Also ask
it to describe what it expects to see after opening each one. All target props
must be identified correctly. The descriptions must roughly match the in-game
surfaces. If one fails, redesign it and repeat. Record each round's answers.

## Engineering rules

- GDScript: tabs, static typing on new vars/functions, match the surrounding
  naming and drawing idiom (`draw_rect`, `draw_circle`, `_neon_text`-style
  helpers, the shared `C_*` palette constants); comments only where a constraint
  isn't obvious.
- Pixel-art register: crisp rectangles and small circles like the references.
  No external image assets unless the references use them.
- Don't touch other games' props, scenario objects/glyphs (owned by parked
  `docs/todo/env06_9_visual_consequence_and_object_identity_prompt.md`), room
  layouts, spawn slots, placement, or in-game surfaces (except adding read-only
  `visual_state`).
- Reports and scratch go under `.tmp/` only, never committed.

## Validation gates (all must pass, in the worktree)

1. `powershell -File tools\validate_project.ps1`
2. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui`
3. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games`
4. `powershell -File tools\check_godot.ps1 -RequireGodot -FoundationSuite coin_pusher`,
   then `-FoundationSuite scratch_tickets`, `-FoundationSuite craps`, and
   `-FoundationSuite bar_dice`.
5. `powershell -File tools\check_godot.ps1 -RequireGodot -Suite Smoke`
6. Performance probe: before/after numbers for every measured room, within
   budget, liveness passing.
7. Visual review boards produced and reviewed by you. The blind identification
   check passes.
8. End-to-end: launch the game from the worktree and walk into a room with each
   of the four games through normal play (use the start-menu Games library only
   to compare surfaces). Hover and select each prop, open it, and confirm the
   game you get looks like the miniature you clicked. Screenshot both moments.

If a gate fails for a reason that also fails on untouched `main`, prove it by
running the same gate on `main` and record it as pre-existing; don't fix
unrelated failures.

## Completion

- **Do not commit, push, or merge.** Leave all changes uncommitted in the
  worktree `D:\Projects\Beat-The-House-worktrees\game-prop-art` on branch
  `codex/game-prop-art` for the owner to review.
- Write `.tmp/game_props01/report.md` in the worktree with:
  - the list of changed/new files;
  - the per-game recognizable-element lists;
  - the blind identification results for every round;
  - perf before/after;
  - rect/aspect proposals for the owner, if any;
  - a note on expected merge contact with the main checkout's uncommitted
    `pixel_scene_canvas.gd` changes (which functions both sides touch).
- Append an execution record to the bottom of **this file in the main checkout**
  (`D:\Projects\Beat-The-House\docs\todo\game_props01_room_object_art_rework_prompt.md`)
  with:
  - date, base commit, and worktree path;
  - gate results (pass/fail + pre-existing notes);
  - perf numbers;
  - blind-ID outcome;
  - paths to the review boards;
  - owner decisions needed.

  Change `Status: READY` to `Status: DONE — uncommitted in worktree, awaiting
  owner review`. Do not move the file.

On gate failure you cannot resolve: leave the work uncommitted, set
`Status: BLOCKED`, and paste the failing output verbatim into the execution
record.

---

## Execution record — 2026-09-13

- Base commit: `56de66598a2bcdbc3f171f090b48c361daf35563`
- Worktree: `D:\Projects\Beat-The-House-worktrees\game-prop-art`
- Branch/state: `codex/game-prop-art`, deliberately uncommitted; nothing was staged, committed, pushed, or merged.
- Result: dedicated normal/low-detail room art now covers Quarter Falls, Jackpot Ridge, Vault Drop, Scratch Tickets, casino Craps, street Craps, and Bar Dice. Public live-state projections contain no future scratch outcomes, future dice, or seeded Coin Pusher body positions.
- Follow-up result: Silas Crow is now a character-backed dialogue object with authored roster model, description, and bio. Selecting him shows character details; activating him opens the `silas_crow_numbers` conversation dock, not the generic Numbers menu, while retaining his route-tip and handle purchases.

### Gates

- `tools/validate_project.ps1`: PASS in 133.4 seconds; output: `Beat the House foundation architecture validation passed.`
- Exact wrapper rerun: validation/import/GDScript-load stages passed on every fully launched candidate invocation. Coin Pusher passed its complete exact wrapper (`.tmp/test_reports/20260913_015355_smoke/summary.json`). UI reached `ui_scene_compile` and failed an unchanged TalkDock `clear_entry` assertion; untouched base also fails the exact UI wrapper at an unrelated onboarding fixture assertion (candidate `.tmp/test_reports/20260913_013458_smoke/summary.json`; base `C:\Users\theep\AppData\Local\Temp\bth-game-props01-baseline\.tmp\test_reports\20260913_013806_smoke\summary.json`).
- Exact Games completed all five game checks with zero failures but the parent process did not exit before its 300-second timeout; untouched base also fails that exact wrapper before completion on its generated native-extension fixture (candidate `.tmp/test_reports/20260913_014228_smoke/summary.json`; base `C:\Users\theep\AppData\Local\Temp\bth-game-props01-baseline\.tmp\test_reports\20260913_015029_smoke\summary.json`). Scratch Tickets stopped in the mandatory broad-content precheck on its obsolete 19.0-second budget (`.tmp/test_reports/20260913_015834_smoke/summary.json`). Craps recorded 19 unrelated broad-content failures and then passed `craps_game_suite` with zero failures (`.tmp/test_reports/20260913_020610_smoke/summary.json`). Bar Dice recorded the same content failures, reached its game suite, and then hit the parent timeout (`.tmp/test_reports/20260913_021602_smoke/summary.json`).
- Exact Smoke passed validation/import/load and stopped in `foundation_smoke_content`; the identical untouched-base Smoke gate stops in that same stage (candidate `.tmp/test_reports/20260913_022354_smoke/summary.json`; base `C:\Users\theep\AppData\Local\Temp\bth-game-props01-baseline\.tmp\test_reports\20260913_022802_smoke\summary.json`). These reproduced broad-harness/content failures are pre-existing and outside the room-prop/Silas changes.
- Direct target contracts: PASS with zero failures for Coin Pusher (final rerun), Scratch Tickets, Craps, and Bar Dice. Receipts: `.tmp/game_props01/coin_pusher_direct_final.json`, `scratch_tickets_direct.json`, `craps_direct.json`, and `bar_dice_direct.json`.
- Dispatch/distinctness/containment/hidden-state/reduce-motion checks: PASS. Pixel difference threshold: 540 changed pixels; every target/reference pair clears it, 110x72 and 72x48 stay contained, repeated reduce-motion output is stable, and all normal/low-detail targets use dedicated renderers.
- Production activation walk: PASS for Coin Pusher, Scratch Tickets, casino Craps, and Bar Dice. Receipt and eight selected/open captures: `.tmp/game_props01/review/end_to_end/`.
- Silas character/conversation probe: PASS. Receipt and selected/conversation captures: `.tmp/game_props01/review/silas_crow/`.
- Final `git diff --check` and dialogue JSON parse: PASS.

### Performance

Focused 120-frame room-canvas before/after measurements (average frame ms; idle redraw count before/after): Grand Casino/Craps `6.9000 -> 6.9000`, `49/49`; Gas Station Casino/Scratch `6.9002 -> 6.8999`, `50/50`; Bar/Bar Dice `6.8999 -> 6.9000`, `50/50`; Corner Store/Quarter Falls `6.9001 -> 6.9001`, `50/50`; Back Alley/Street Craps `6.9000 -> 6.9001`, `50/50`. No regression and no frozen-idle result.

The standard probe's target renderer draw averages were also lower in the candidate run: Scratch `1.766 -> 1.234 ms`, Bar Dice `3.041 -> 2.261 ms`, Craps `1.780 -> 1.123 ms`, Coin Pusher `5.571 -> 4.066 ms`; every required target liveness counter was nonzero. Its four candidate failures are pre-existing game-surface budget overruns reproduced by untouched base (Blackjack resolve avg/p95/max and Coin Pusher full-surface idle p95), outside the changed room-prop paths. Reports: `.tmp/game_props01/perf/before.json`, `after.json`, `rooms_before.json`, and `rooms_after.json`.

### Blind identification and review

- Blind round 1 failed Scratch vs Pull Tabs and Quarter Falls vs Slots. Both props were redesigned.
- Blind round 2 passed all ten shuffled unlabeled entries: street craps, slot, Vault Drop, scratch tickets, bar dice, Quarter Falls, video poker, casino craps, pull tabs, Jackpot Ridge. Expected opened-surface descriptions also matched.
- Full report: `.tmp/game_props01/report.md`
- Per-game boards: `.tmp/game_props01/review/*_review_board.png`
- Final labeled/unlabeled lineups: `.tmp/game_props01/review/recognition_lineup_labeled.png`, `recognition_lineup_unlabeled.png`, and `recognition_lineup_unlabeled_shuffled.png`
- Real rooms: `.tmp/game_props01/review/rooms_after/` and `.tmp/game_props01/review/rooms_after_small/`
- Study sheets: `.tmp/game_props01/study/`

### Owner decisions

- No geometry change proposed: retain production 110x72 and 72x48 fallback.
- Decide whether Silas Crow should land with this branch or be split into a separate change.
- Expected merge contact: `scripts/ui/pixel_scene_canvas.gd` mapping/dispatch/low-detail branches and deletion of the old weak functions overlap the main checkout's concurrent spawn-slot work; integrate those narrow hunks manually or rebase after that work lands. The new renderer bodies are isolated under `scripts/ui/game_props/`.
