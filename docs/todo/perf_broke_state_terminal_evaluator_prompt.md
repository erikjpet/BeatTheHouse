# Agent Prompt — Stop Running the Terminal Evaluator Every Frame While Broke

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. Run/world logic lives under `scripts/core/`; the UI
host is `scripts/ui/foundation_main.gd`. This file is fully self-contained.

## The problem (verified; re-verify line numbers before editing)

`_advance_deferred_bankroll_failure` (`scripts/ui/foundation_main.gd:969-979`)
is called from `_process` every frame. Its guards pass whenever
`run_state.bankroll <= 0` and the run is not terminal — which is exactly the
deferred-bankroll-zero recovery state a player can sit in for a long time
while deciding what to do. In that state it calls
`RunTerminalEvaluatorScript.evaluate(run_state, library)` EVERY FRAME.
The evaluator (`scripts/core/run_terminal_evaluator.gd:7+`) walks the
current environment's games, items, lenders, and events with `_string_array`
copies and per-entry lookups. Frames are heaviest precisely when the player
is stressed and the game should feel most responsive. On web/low-end this
eats the thin idle budget (~7 ms p95 measured on dev hardware).

The evaluation result can only change at action boundaries (bankroll,
inventory, environment, debt, and flags only mutate through actions), so
per-frame evaluation is pure waste.

## The task

1. Make the deferred-bankroll-failure check event-driven instead of
   per-frame. Acceptable designs (pick the cleanest, state your choice):
   - Evaluate once when entering the broke state and re-evaluate only
     after an action/state mutation (a run-state mutation counter or the
     existing action pipeline hooks), caching the verdict in between; or
   - Move the check entirely to action-boundary call sites (everywhere
     bankroll/inventory/debt can change) and delete the per-frame path.
2. The player-visible contract must not change by even one frame's worth
   of behavior at action boundaries: a run that should fail when its last
   recovery option disappears must still fail at the same action boundary
   it does today; a run with recovery options must stay alive exactly as
   today. Timing-wise, deferring the verdict from "same frame" to "same
   action boundary" is acceptable ONLY if today's verdict also only ever
   changes at action boundaries — verify this claim in code before relying
   on it, and document what you found.
3. While in the file, confirm no OTHER `_process` subsystem calls the
   terminal evaluator or similarly heavy core evaluation per frame; report
   anything found (fixing it is in scope if it is the same pattern).

## Hard rules (binding)

- Zero functional change: identical failure reasons, identical messages,
  identical timing at action-boundary granularity, identical determinism.
- Zero-copy per-frame: the fix must not introduce new per-frame
  allocation; the goal is removing it.
- Idle-animation liveness stays untouched.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA (all required)

1. Broke-state scenarios: drive a run to bankroll 0 with (a) recovery
   available (sellable item), (b) recovery available (lender), (c) no
   recovery → confirm (a)/(b) keep the run alive and (c) fails with the
   same reason/message as before the change.
2. Closing-time broke case: bankroll 0 at closing time with forced travel
   required must still resolve the way the stuck-state sweep expects
   (`broke_closing_walk_fallback` scenario).
3. Add/extend foundation tests asserting the verdict at action boundaries
   for (a)-(c), plus a regression test that the evaluator is NOT invoked
   per frame in the broke state (counter or spy hook).
4. Performance: measure frame time in the broke-idle state before/after
   and report the delta.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the design chosen, the action-boundary verification, the broke-state
frame-time delta, test additions, and each gate result. If a gate fails and
you cannot fix it, stop, do not commit, and report the failure output
verbatim.
