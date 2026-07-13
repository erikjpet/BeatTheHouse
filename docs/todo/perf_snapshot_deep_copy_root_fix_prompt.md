# Agent Prompt — Root Fix: Per-Frame Deep-Copy Elimination in the Game Surface Pipeline

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: the release candidate was tested, bugs were found, and this
task is part of the 0.4.0 polish line — not a post-release change. All game
rendering is immediate-mode GDScript drawing on a 900×430 board; per-game
modules under `scripts/games/` talk to the host
(`scripts/ui/foundation_main.gd`) through dictionary "surface commands" and
"surface state" snapshots. This file is fully self-contained.

## The problem (verified; re-verify line numbers before editing)

The game-screen hot loop deep-copies dictionaries every frame:

1. `_advance_game_surface_automation` (`foundation_main.gd:792-805`) runs
   every `_process` frame while a game is open and calls
   `_current_game_surface_ui_state()` (`:8905-8912`), which does
   `game_surface_ui_state.duplicate(true)` plus
   `_focused_talk_speaker_snapshot()` (`:8915-8924`, another
   `duplicate(true)`), plus `_current_game_surface_status()` — all before
   `surface_needs_auto_tick` even decides whether anything needs to happen.
   Result: at least one deep copy per frame on every game screen, even
   fully idle ones.
2. During active presentations, `_advance_game_surface_realtime_state`
   (`:808-821`) rebuilds the ENTIRE view snapshot at 60 Hz
   (`GAME_SURFACE_REALTIME_REFRESH_INTERVAL_MSEC := 16`, `:46`) via
   `_game_view_snapshot()` (`:8791+`), which calls the module's
   `surface_state(...)` and then `module_surface_state.duplicate(true)`
   (`:8812`) — for slots/blackjack that is a large nested dict, 60×/sec.
3. This is the exact "per-tick deep-copy round-tripping" pattern this
   repo's pinball post-mortem identified as its perf root cause, and the
   repo separately shipped a measured 32.6 ms/frame regression from a
   per-frame `active_bonus` deep copy in the old slot watchdog. The
   pattern keeps reappearing because nothing structural prevents it.

Measurement hooks already exist: `GameSurfaceCanvas` tracks
`perf_full_snapshot_calls`, `perf_runtime_status_calls`, and
`perf_draw_frame_usec_samples` (`game_surface_canvas.gd:179-190`), and
`tools/foundation_performance_probe.gd` enforces per-surface p95 budgets.

## The task

Fix this at the root, not per-call-site, then sweep the codebase for every
other instance of the pattern.

1. **Measure first.** Before changing code, capture a baseline: run
   `tools/foundation_performance_probe.ps1` and record per-surface
   avg/p95/max plus `perf_full_snapshot_calls` per scenario into a report
   under `.tmp/`. Every claim of improvement must diff against this.
2. **Redesign the snapshot flow so idle frames are allocation-free.**
   Constraints on the design (the exact mechanism is yours to choose, but
   it must satisfy all of these):
   - A game screen with no active presentation and no state change since
     the last snapshot performs ZERO dictionary deep copies per frame.
   - `surface_needs_auto_tick` (or an equivalent cheap pre-check) must be
     answerable without building the full ui_state — e.g. a monotonic
     state-version/dirty counter bumped by the ~30 mutation sites of
     `game_surface_ui_state`, checked before any copy happens.
   - During presentations, snapshot rebuilds happen only when the module's
     surface state can actually have changed (module-declared dirty flag,
     animation channels driven by canvas-side elapsed time, or an
     explicitly documented cheaper cadence) — not unconditionally at
     60 Hz. Animation smoothness must NOT regress: canvas-side animation
     (`SURFACE_ANIMATION_FPS`, flicker, channel timing) already runs
     independently of snapshot rebuilds; keep presentation motion at
     current smoothness.
   - Where a copy is still required, prefer shallow copies of subtrees
     that are documented immutable-after-build, and state that contract in
     a comment at the owning builder.
3. **Codebase sweep.** Audit every `duplicate(` call reachable from
   `_process`, `_physics_process`, `_draw`, or anything they call each
   frame, across `scripts/ui/` and `scripts/games/` (410 occurrences exist
   repo-wide; most are action-boundary and fine — only per-frame paths are
   in scope). Known suspects to check explicitly:
   `procedural_music_player.gd` (75 duplicate calls; verify which run in
   `_process` at `:178`), `pixel_scene_canvas.gd`, `talk_dock.gd`,
   `world_map_canvas.gd`, `perf_telemetry_overlay.gd`. Fix hot ones the
   same way; list cold ones you deliberately left alone in the report.
4. **Do NOT change what the player sees.** Identical visuals, identical
   animation timing, identical action behavior, identical determinism.
   This task is allocation/copy elimination only.

## Hard rules (binding)

- Zero functional or visual change. If a design choice trades visual
  fidelity for speed, it is the wrong choice for this task.
- Idle-animation liveness is release-gated: never suppress animation
  scheduling to reduce redraws. Liveness counters
  (`scene_idle_animation_redraw_count`, surface animation channels) must
  show equivalent activity before/after. Never accept a 0.000 idle-draw
  number without the liveness check passing.
- Determinism: seeds→hashes must be unchanged. Snapshot caching must never
  change WHAT is rendered or resolved, only how often it is rebuilt.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA (extensive, all required)

1. Baseline vs after: performance probe per-surface avg/p95/max table; the
   after-numbers must be equal or better on EVERY surface, and
   `perf_full_snapshot_calls` during the idle-game scenario must drop to
   ~zero (state your measured counts).
2. Animation regression pass: run `tools/foundation_visual_qa.ps1` and
   confirm all route checks pass; manually drive one full presentation in
   each game (pull tabs, slots incl. a bonus, bar dice, blackjack deal,
   baccarat deal, roulette spin, video poker draw) and confirm motion is
   smooth and complete — no frozen mid-presentation states, no skipped
   result reveals.
3. Liveness: with the game idle on each surface, confirm idle animation
   still visibly runs and liveness counters advance.
4. Determinism: `tools/foundation_determinism_probe.ps1 -RequireGodot
   -SeedCount 10` — hashes self-consistent.
5. Full behavior suites: `tools/check_godot.ps1 -RequireGodot
   -FoundationSuite systems -TimeoutSec 300` and `-FoundationSuite ui`.
6. Add regression tests to the foundation test suite that assert the
   allocation-free idle contract (e.g. snapshot-call counters do not
   advance across N idle frames on a game screen) so this cannot silently
   recur.
7. Strict player-style pass: `tools/foundation_mouse_playtest.ps1` single
   strict run must pass.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_performance_probe.ps1 -RequireGodot`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_visual_qa.ps1`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the before/after performance table, the sweep findings (fixed vs
deliberately-left), test additions, and each gate result. If a gate fails
and you cannot fix it, stop, do not commit, and report the failure output
verbatim.
