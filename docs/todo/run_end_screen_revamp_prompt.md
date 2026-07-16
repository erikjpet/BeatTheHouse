# Agent Prompt — Run End Screen Revamp: One-Screen Visual Report (Win + Loss)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping to Web/itch.io and Windows desktop (1280×720 viewport).
All rendering is immediate-mode GDScript drawing; UI components follow a
signal-based extraction pattern (see `scripts/ui/run_inventory_screen.gd`
and the freshly extracted view models in `scripts/ui/`). Content and icon
art are data-driven. This file is fully self-contained.

## The problem

The run-over screens (SCREEN_FAILURE / SCREEN_VICTORY,
`foundation_main.gd` — `_render_failure_summary` / `_render_victory_summary`
around :1053, victory panel built near :4980) are scrolling TEXT DUMPS:
lists of story lines, inventory strings, debt strings, and a
programmer-style score readout. The owner wants a complete revamp: **one
single screen, no scrolling, both win and loss**, made of distinct visual
sections that each tell one chunk of the run's story at a glance.

## What exists to build on (verified; re-verify before editing)

- **Seam:** `scripts/ui/terminal_consequence_view_model.gd`
  (`TerminalConsequenceViewModel`) already aggregates failure data from
  run state as a pure static builder — extend/replace its output rather
  than adding rendering logic to `foundation_main.gd`. Build the new
  screen as its own component (`RunReportScreen` + a pure
  `RunReportViewModel`), following the established extraction pattern.
- **Outcomes:** failure reasons are `bankroll_zero`, `stranded`,
  `police_capture`, `casino_taken_out_back`, `abandoned`
  (`run_state.gd:40-45`), plus two victory flavors (clean Players Card
  cashout vs. surviving Rourke's showdown — see the victory path).
- **Score:** `run_state.terminal_score_summary()` (`run_state.gd:4437`)
  → `{base_spending, multiplier, score}`; spending accumulates via
  `record_score_spending` (travel + purchases), multiplier is the
  victory multiplier or 1.
- **Story data:** `run_state.story_log` (capped at 240 +
  `story_log_archive_count`), entries carry `type`, `bankroll_delta`,
  `suspicion_delta`, environment ids, game/lender/item ids — enough to
  aggregate money per source and per game.
- **Environment timeline:** `run_state.environment_history` (capped 48,
  `run_state.gd:124,1046`).
- **Travel:** `run_state.world_map` has `visited_path`, node positions,
  states; `scripts/ui/world_map_canvas.gd` already renders the map.
- **Debt:** live `run_state.debt` only holds ACTIVE debts — paid ones are
  removed at settle (`_settle_paid_debt`) and defaults are removed or
  mutated; history exists only in story_log (`debt_paid`,
  `debt_default`, lender story entries).
- **Icons:** `tools/generate_icon_art.py` generates the pixel icon set;
  `data/art/attribute_glyphs.json` + `attribute_badges.gd` are the
  data-driven icon registry precedent.
- **DATA GAP (you must close it):** there is NO heat-over-time series.
  Heat exists only as current level plus per-entry `suspicion_delta` in
  story_log.

## The design (build exactly this; sections are the contract)

One screen, no scrolling, shown for BOTH win and loss with the same
layout (win/loss changes the RESULT section's content and accent colors,
not the structure). Wireframe on the 1280×720 design surface:

```
+----------------------------------------------------------------------+
| [ICON] RESULT: outcome + reason        | SCORE: friendly breakdown   |
|        where it ended + how it ended   |                             |
+--------------------------------------------------+-------------------+
| TRAVEL REPLAY                                     | STORY: money      |
|   world map, traveled path, [> Play] button       |   per-source bars |
|                                                   +-------------------+
|                                                   | ITEMS: kept /     |
|                                                   |   pawned / sold   |
+---------------------------------------------------+------------------+
| HEAT TIMELINE: heat graph + environment bands     | DEBT: loan ledger |
|   with replay progress cursor                     |                   |
+---------------------------------------------------+------------------+
|                  [New Run]   [Home]   [Copy Seed]                    |
+----------------------------------------------------------------------+
```

### 1. RESULT

- Outcome title + one-sentence "how it ended" + "where it ended" (final
  environment display name, day/time).
- **Every outcome gets a distinct icon** so the player reads what
  happened without reading anything: 5 failure icons (broke, stranded,
  police capture, taken out back, walked away) + 2 victory icons
  (Players Card, showdown survived). Add them to the generated icon set
  via `tools/generate_icon_art.py` in the established style, and map
  reason→icon in DATA (a small registry, not a match statement buried in
  UI code).

### 2. SCORE

Human-friendly, not a programmer dump. Show it as a visible calculation:
"Money put to work" (base spending) × "Winner's bonus ×N" (only on win)
= "Final score", with the numbers large and the labels plain. Use the
CURRENT formula from `terminal_score_summary()` — presentation changes
only, math unchanged.

### 3. ITEMS

What the player OWNED at the end (icon grid), what they PAWNED (with its
fate: redeemed / still held / forfeited), and what they SOLD (with
price). Source: final inventory + story_log item/pawn entries,
aggregated in the view model. Icons come from the existing item icon
keys. Compact: icon + tiny label, counts collapse duplicates.

### 4. HEAT TIMELINE (new data + graph)

- Add a lightweight, serialized `heat_history` series to `RunState`:
  append `(action_index, heat_value)` whenever suspicion changes and at
  environment transitions; cap it (propose 480 points with
  downsampling-on-overflow *(tunable)*) so saves stay bounded. It must
  survive save/load and be deterministic (it records what happened; it
  never influences simulation).
- Draw a line/area graph on a canvas: x = run timeline (action index),
  y = heat 0–100, with the capture threshold marked at 100. Spikes and
  cool-downs must be visually obvious.
- Under the graph, draw **environment occupancy bands**: colored
  segments showing which venue the player was in across the same
  timeline (from `environment_history` + the heat series' environment
  markers), so "heat spiked at the underground casino" is readable at a
  glance.

### 5. DEBT

Every loan taken during the run — paid or not. Live `debt` only has
active entries, so the view model must reconstruct the full ledger from
story_log lender/debt entries (borrowed X from Y; repaid / defaulted /
collateral kept; pawn tickets redeemed or forfeited). One row per loan:
lender, amount, outcome, color-coded (settled / outstanding / burned).

### 6. STORY (money flow, not a log dump)

Replace the story text dump with a per-source money summary: one bar row
per source showing NET gain/loss — each casino game the player actually
played (slots +$120, pull tabs +$40, bar dice −$85 …), plus rows for
events, services, lenders, items bought/sold, and travel costs.
Aggregate from story_log `bankroll_delta` by source type/game id in the
view model. Positive bars one accent color, negative another, sorted by
absolute value. The player must be able to see "I made money at slots
and pull tabs and lost it at dice" in two seconds.

### 7. TRAVEL REPLAY (the centerpiece — most important section)

- Render the world map (reuse `world_map_canvas.gd` rendering or a
  read-only variant fed by a snapshot — do NOT fork a second map
  renderer if reuse is feasible; if a variant is genuinely needed,
  extract shared drawing helpers instead of copying them).
- Show the full traveled path (`visited_path`) as a polyline over the
  map with visited nodes marked.
- A **Play button** starts an animated replay: a marker travels the
  path leg by leg in order, the currently-visited venue highlights and
  labels itself, and the path draws in progressively behind the marker.
- **Scrubber coupling:** the replay drives a progress cursor rendered ON
  the heat-timeline graph (section 4), video-editor style — as the
  marker travels, the cursor sweeps the same run timeline, so map
  position and heat history stay in sync. Clicking/dragging on the heat
  graph seeks the replay to that point. Map both directions through one
  shared timeline model (action index ↔ travel leg ↔ heat sample) built
  once in the view model.
- Replay is presentation-only: it never touches simulation state.
  Precompute all keyframes once when the screen opens; animation
  advances via canvas elapsed time. With reduce-motion enabled, the
  play button is replaced by instant full-path display with a draggable
  cursor (no autoplay).

### Layout rules

- Absolutely no scrolling at the design resolution; every section fully
  visible at once. Budget the grid so TRAVEL gets the largest area and
  HEAT the full lower-left width (they share the timeline).
- Small-screen play mode exists (see the recent small-screen commit):
  the report must remain usable there — compact paddings/fonts first;
  if it genuinely cannot fit, sections may collapse into two tab groups
  (Result+Score+Travel / Heat+Story+Items+Debt) — tabs, never scroll.
- Both end screens (win and loss) route into this ONE component; delete
  the old text-dump rendering paths when the replacement lands (no dead
  parallel screens).
- Buttons: keep existing post-run actions (new run, return home, copy
  seed) — reuse existing wiring.

## Hard rules (binding)

- Zero-copy per-frame: the replay and graph render from precomputed,
  immutable keyframe/sample arrays; no per-frame `duplicate(true)`, no
  per-frame dictionary building. This repo shipped a measured
  32.6 ms/frame regression from that mistake once.
- Idle-animation liveness gates stay untouched; the replay animation
  must respect reduce-motion.
- Determinism: `heat_history` recording must not alter any RNG or
  simulation path; determinism probe hashes must remain self-consistent.
  Score math unchanged.
- Simulation/UI split: ALL aggregation (money per source, debt ledger,
  item fates, timeline model) lives in a pure view model with explicit
  inputs; the screen component only draws. `foundation_main.gd` gains
  only thin wiring (this file is under active decomposition — do not
  grow it).
- Match existing style: tab indentation, typed GDScript, sparse
  constraint comments, VisualStyle palette, existing panel/button
  widgets. Reports under `.tmp/` (gitignored) only.
- Suite timeouts: per-suite timeout = max(300s, ceil(recorded baseline
  in tools/check_godot.ps1 × 1.5)). Never trim tests to fit a timeout.

## QA (extensive; all required)

1. View-model unit tests (foundation test suites): money-per-source
   aggregation from a scripted story_log; debt ledger reconstruction
   (paid, defaulted, pawn redeemed, pawn forfeited); item fates (kept /
   pawned / sold); timeline model index mapping (action ↔ leg ↔ sample);
   heat_history capping/downsampling and save/load round trip.
2. Outcome coverage: drive a run to each of the 5 failure reasons and
   both victories; assert the correct icon key, title, and where/how
   text (extend existing terminal-path tests).
3. Single-screen guarantee: automated check that the report layout at
   1280×720 has no scroll container and no section clipped off-screen
   (assert rects within viewport in the UI suite), and the small-screen
   mode fits or tabs.
4. Replay: keyframes precomputed once (counter/spy assertion, not
   vibes); scrubbing seeks correctly at leg boundaries; reduce-motion
   path shows full state with no animation.
5. Determinism probe (10 seeds) + stuck-state sweep unaffected.
6. Visual QA route extended to capture the new end screen (win + one
   failure) so regressions are visible; manual smoke of a full run to
   victory and to bankroll-zero, checking every section reads correctly
   at a glance.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- Every supported `-FoundationSuite` covering systems + UI via
  `tools/check_godot.ps1 -RequireGodot` (timeout policy above)
- `powershell -ExecutionPolicy Bypass -File tools/foundation_visual_qa.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_performance_probe.ps1 -RequireGodot`
  (the end screen must not introduce a heavy surface; if the probe does
  not cover it, add it as a measured surface with a budget)
- Strict mouse playtest run (`tools/foundation_mouse_playtest.ps1`) —
  it exercises run completion and must still pass end-to-end.

## On completion

When every gate passes: commit the work in logical units (data series;
view model + tests; screen component; icon art; old-path removal),
delete this prompt file in the final commit so it cannot be executed
twice, push, and report: a screenshot description of each section, the
view-model API, heat_history sizing decisions, what was reused from
world_map_canvas vs extracted, and each gate result. If a gate fails and
you cannot fix it, stop at the last green commit and report the failure
verbatim.
