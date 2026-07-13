# Agent Prompt — Guard the `_process` Subsystem Fan-Out (Perf-Only, No Behavior Change)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. The UI host is `scripts/ui/foundation_main.gd`. This
file is fully self-contained.

## The problem (verified; re-verify line numbers before editing)

`FoundationMain._process` (`foundation_main.gd:394-402`) fans out to eight
subsystem calls every frame on EVERY screen — main menu, meta home,
environment room, and game screens alike:
`_apply_run_screen_layout`, `_advance_run_game_clock`,
`_advance_game_surface_automation`, `_advance_game_surface_realtime_state`,
`_advance_presented_bankroll`, `_advance_environment_game_runtime`,
`_advance_deferred_bankroll_failure`, `_flush_pending_autosave_if_ready`.

Each has internal early-outs, but several still allocate or do redundant
work before bailing:

- `_advance_environment_game_runtime` (`:910-928`) copies the environment's
  `game_ids` array via `_string_array(...)` every frame and calls
  `environment_runtime_needs_tick` per game — on screens where no
  environment game can possibly be running (menus, meta sessions).
- `_apply_run_screen_layout` (`:5576+`) runs its guard chain every frame;
  layout only changes on resize (`_notification` already calls it,
  `:441-444`) and on explicit invalidation.
- Measured idle p95 on strong dev hardware is ~7 ms; every wasted per-frame
  call narrows the web/low-end margin.

Related dead scaffolding (`_advance_run_game_clock`,
`_run_clock_should_tick`) is handled by the separate time-system audit
task — if that task has already landed, do not resurrect it; work with
whatever `_process` currently contains.

## The task

1. Add cheap top-level screen/state guards so each `_process` subsystem is
   only invoked on screens/states where it can do work. Prefer one
   readable dispatch (e.g. guard clusters per screen) over eight scattered
   checks; keep it boring and obvious.
2. Hoist per-frame allocations out of the guarded paths that remain:
   `_advance_environment_game_runtime` must not copy `game_ids` per frame
   (cache on environment change; the environment only changes at travel /
   generation boundaries) and must skip entirely when the current
   environment has no runtime-capable games.
3. Verify `_apply_run_screen_layout` frame calls are redundant with the
   resize notification + explicit invalidation sites; if they are, remove
   it from `_process` (keep the invalidation-triggered path). If you find
   a real case that only the per-frame call catches, keep it and document
   that case in a comment instead.
4. Nothing else: this task is guards and hoists only. No redesigns.

## Hard rules (binding)

- Zero functional or visual change: autosaves still flush on the same
  frames, presented-bankroll animation still resolves identically,
  environment game autoplay still ticks at the same boundaries, layout
  still adapts on resize. If any guard changes observable behavior, the
  guard is wrong.
- Zero-copy per-frame: the point of the task; do not introduce new
  allocation.
- Idle-animation liveness stays untouched.
- Determinism: seeds→hashes unchanged.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA (extensive, all required)

1. Before/after frame-time measurement on: main menu idle, meta home idle,
   environment room idle, game screen idle, game presentation active.
   Every number must be equal or better; report the table.
2. Behavior spot checks: autosave flush after an action with the deferred
   frame window; presented bankroll hold/release during a game result;
   environment game autoplay (gas station slots style) still advancing
   while standing in the room; window resize reflows the HUD.
3. Full suites + strict single mouse playtest run.
4. Add a regression test asserting `_advance_environment_game_runtime`
   performs no array copy on menu/meta screens (counter or spy hook), so
   the guard cannot silently regress.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_performance_probe.ps1 -RequireGodot`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the before/after table, what was guarded/hoisted/removed, test
additions, and each gate result. If a gate fails and you cannot fix it,
stop, do not commit, and report the failure output verbatim.
