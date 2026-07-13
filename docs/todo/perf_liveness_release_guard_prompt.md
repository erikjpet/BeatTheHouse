# Agent Prompt — Permanent Performance + Liveness Release Guard (High Priority)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. This file is fully self-contained. It runs AFTER the
perf-fix tasks in this queue (snapshot deep-copy root fix, broke-state
evaluator fix, `_process` fan-out guards) so the guard locks in their final
state — build on the tree as you find it.

## Background (verified)

This repo has a RECURRING regression pattern, observed four separate
times: a performance pass reduces idle redraw work, the idle-draw numbers
hit 0.000, and idle table/scene animations silently freeze — because the
perf gates reward low draw counts and nothing asserts that animation is
still alive. Counter-infrastructure already exists but is not enforced as
a gate:

- `PixelSceneCanvas.scene_idle_animation_redraw_count`
  (`pixel_scene_canvas.gd:456`) increments on idle-animation redraw ticks.
- `GameSurfaceCanvas` tracks `perf_full_snapshot_calls`,
  `perf_runtime_status_calls`, `perf_draw_frame_usec_samples`
  (`game_surface_canvas.gd:179-190`) and has
  `surface_animation_liveness_active()` (`:175`).
- `scripts/ui/perf_telemetry_overlay.gd` is a runtime-enabled overlay
  (`foundation_main.gd:447-452`).
- `tools/foundation_performance_probe.gd` enforces per-surface p95
  budgets and per-resolve-path budgets (see
  `docs/plans/v04_performance_pass_2026_07.md` for the current budget
  table and passing values).

## The task (execute in extreme detail; this is a high-priority guard)

### 1. Liveness assertions become release-gating

Extend `tools/foundation_performance_probe.gd` (and its `.ps1` wrapper if
needed) so that EVERY measured idle scenario asserts BOTH:

- frame-time budget (existing), AND
- a liveness floor: during the measured idle window, the relevant
  liveness counter advanced by at least the expected minimum for that
  surface (scene idle ticks for environment rooms; surface animation
  channel activity for game surfaces with idle animation; explicitly
  document surfaces that legitimately have zero idle animation — that
  list must be written in the probe as data, not implied by a zero
  threshold everywhere).

A 0.000-draw idle result with a stalled liveness counter must FAIL the
probe with a message naming the surface and the counter. This is the
whole point: the two numbers can never again pass separately.

### 2. Per-subsystem frame attribution in the telemetry overlay

Expand `perf_telemetry_overlay.gd` so a developer can see, live, where
frame time goes: per-frame usec attribution for the `_process` subsystems
of `foundation_main` (snapshot builds, environment runtime, autosave
flush, layout) and canvas draw times (already sampled). Requirements:

- Attribution instrumentation must be ZERO-COST when the overlay is
  disabled (guard with the existing `runtime_enabled()` pattern — no
  dictionary building, no timing calls on the disabled path).
- The overlay itself must obey the zero-copy per-frame rule (it currently
  has 3 `duplicate(true)` calls — audit them; fix any that run per frame
  while enabled).
- Counters exposed by the overlay must be the SAME counters the probe
  asserts, so what the developer sees is what the gate measures.

### 3. Regression tests

Add foundation tests that simulate the historical failure: force an
idle-animation scheduling suppression (e.g. stub the accumulator/demand
path the way past regressions broke it) and assert the probe's liveness
check logic FAILS it. This proves the guard actually guards. Then restore
and assert PASS.

### 4. Documentation

Record the guard contract in one place (probe header comment): what each
liveness counter means, its floor per surface, and the rule that idle
budgets and liveness floors only ever change TOGETHER in the same commit
with justification.

## Hard rules (binding)

- Zero visual/functional change to the shipped game. Instrumentation must
  be free when disabled and cheap when enabled.
- Zero-copy per-frame everywhere, including inside the overlay.
- Determinism: telemetry must never touch simulation state; seeds→hashes
  unchanged.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA (extensive, all required)

1. Probe battery: full performance probe run PASSES on the current tree
   with the new liveness assertions active; publish the per-surface
   table (budget, measured, liveness floor, measured liveness).
2. Guard proof: the forced-suppression regression test fails the liveness
   check, and the failure message names surface + counter (include the
   message in your report).
3. Overlay on/off cost: measure frame time with overlay disabled vs
   removed-entirely (should be indistinguishable) and enabled (report the
   cost; it must stay within the idle budget on dev hardware).
4. Full suites + determinism probe.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_performance_probe.ps1 -RequireGodot`
- `powershell -ExecutionPolicy Bypass -File tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the liveness floor table, the guard-proof failure message, overlay
cost numbers, test additions, and each gate result. If a gate fails and
you cannot fix it, stop, do not commit, and report the failure output
verbatim.
