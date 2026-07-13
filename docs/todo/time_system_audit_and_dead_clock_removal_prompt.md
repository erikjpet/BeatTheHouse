# Agent Prompt — Time System Audit: Player-Correct Behavior, No Softlocks, Dead Clock Scaffolding Removed

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. Run/world logic lives under `scripts/core/`; the UI
host is `scripts/ui/foundation_main.gd`. This file is fully self-contained.

## Background (verified; re-verify line numbers before editing)

The game clock is action-driven: `RunState.advance_game_clock_minutes`
(`run_state.gd:363`) advances via action costs (`:377`,
`ACTION_CLOCK_MINUTES`) and travel (`foundation_main.gd:3229`,
distance-scaled). Venues have `open_hours` in
`data/environments/archetypes.json` with wrap-around semantics, and a
closing-time eviction system exists (grace window, forced travel; the
stuck-state sweep has a `broke_closing_walk_fallback` scenario).

**Confirmed dead scaffolding from an earlier wall-clock design:**

- `_run_clock_should_tick` (`foundation_main.gd:409-425`) has ZERO callers.
- `_advance_run_game_clock` (`:405-406`) runs every `_process` frame and
  only zeroes `run_clock_minute_accumulator` — which nothing reads.
- Nine `_pause_run_clock_for_ui_preview` call sites (`:428-429`, `:1088`,
  `:1141`, `:1168`, `:7326`, `:7337`, `:7348`, `:7694`) maintain
  `run_clock_ui_preview_pause_frames`, consumed only by the dead function.

This survived the last dead-code cleanup because it is newer than the
audit that fed it.

## The task

### 1. Remove the dead scaffolding

Delete `_run_clock_should_tick`, `_advance_run_game_clock` (and its
`_process` call), `_pause_run_clock_for_ui_preview` and all nine call
sites, and the `run_clock_minute_accumulator` /
`run_clock_ui_preview_pause_frames` variables plus their reset sites —
UNLESS your audit (below) finds a live consumer this analysis missed, in
which case keep exactly what is consumed and report it.

### 2. Full time-system audit (behavior, from the player's seat)

Audit and verify each of the following, fixing what fails and adding a
test where coverage is missing:

1. **Time passes when it should.** Every player action that plausibly
   takes time advances the clock: game rounds, item use, service/lender
   hooks, events, travel (distance-scaled). Trace every
   `advance_game_clock_minutes` / action-cost call site and produce a
   table (action type → minutes) in your report. Flag anything that costs
   0 minutes and looks wrong; fix clear omissions, list judgment calls.
2. **The clock display is honest.** The HUD clock matches the simulated
   minute; day rollover behaves; AM/PM rendering is correct across
   midnight wrap.
3. **Open hours are enforced consistently.** Travel to a closed venue is
   blocked/labeled per its route + `open_hours`; a venue that closes
   while the player is elsewhere shows correctly on the map; arrival
   windows behave (e.g. delta_queen's availability_window plus
   open_hours interact sanely).
4. **Closing time with the player present NEVER softlocks and never
   feels like an unexplained ejection.** Verify the full eviction
   sequence: clear warning message at closing, the documented grace (a
   mid-resolution round finishes; at most one more action), then forced
   travel that ALWAYS has a legal destination:
   - normal case: player can pick a destination;
   - broke case: the walk-fallback destination exists and is free
     (`broke_closing_walk_fallback` in the stuck-state sweep must keep
     passing);
   - edge case to explicitly test: ALL neighboring venues also closed at
     that minute → the player must still have somewhere to go (24h venues
     exist: motel, back_alley, gas_station_casino,
     small_underground_casino, grand_casino — verify at least one is
     always reachable from every venue at every minute given current
     data; if a gap exists, fix it in data, not code, and report it);
   - mid-presentation case: closing during an active game presentation
     must not strand the game surface (grace rules apply).
5. **Determinism.** Time advancement is action-driven only — confirm no
   wall-clock (`Time.get_ticks_*`, `get_datetime_*`) leaks into
   simulation state anywhere in `scripts/core/` (presentation timing in
   UI is fine; the daily-challenge seed derivation from the system date
   at run START is an accepted, existing exception).

### 3. Report

Produce a written audit table in your completion report: each numbered
item above → PASS / FIXED (with what changed) / FLAGGED (judgment call,
with recommendation).

## Hard rules (binding)

- Behavior fixes must be minimal and player-expectation-driven; no
  redesigns of the time system.
- Determinism: seeds→hashes unchanged except where a genuine time-cost
  bug fix legitimately changes simulation (call these out explicitly; the
  determinism probe must still self-agree across repeat runs).
- Zero-copy per-frame; idle-animation liveness untouched.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- Manual smoke: sit in a venue until closing → warning, grace action,
  forced travel with a destination; repeat while broke.

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the audit table, dead-code removal summary, any data fixes, test
additions, and each gate result. If a gate fails and you cannot fix it,
stop, do not commit, and report the failure output verbatim.
