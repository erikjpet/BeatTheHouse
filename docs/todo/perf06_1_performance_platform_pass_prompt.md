Status: TODO
Board row: `perf06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 perf06_1: Performance and Platform Pass

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, which ships to Web (itch.io) and
Windows at 1280×720 and has a documented history of performance regressions.
Read `scripts/ui/performance_liveness_guard.gd`,
`scripts/ui/perf_telemetry_overlay.gd`, `scripts/ui/game_surface_canvas.gd`'s
performance counters, `docs/plans/0.5_performance_audit.md`,
`docs/plans/v04_performance_pass_2026_07.md`,
`docs/plans/0.3.2_low_end_web_cleanup_board.md`, and
`scripts/tests/export_distribution_fresh_start_check.gd`.

## Why this row exists

The last project-wide performance pass predates the coin pusher physics solver,
the dynamic scenario runtime, and two depth programs that added actors, scene
objects and staged sequences to every surface in the game. Individual rows held
their own budgets, but budgets were set per surface against a build with fewer
simultaneous systems.

Read the project's recorded failure patterns before measuring anything:

- **The idle-animation regression, four occurrences.** Performance passes freeze
  idle table animations because idle-draw budgets reward 0.000 with no liveness
  counter-gate. An idle number of 0.000 is a failure, not a pass. Never accept
  one without the liveness check.
- **Per-frame deep copies.** The slot bonus watchdog deep-copied active bonus
  state every frame at a measured 32.6 ms. Per-frame checks must stay zero-copy.
- **Surfaces redraw fully in GDScript every frame.** This is the baseline cause
  of overall slowness in this project, not a new problem to solve here, but the
  thing every measurement must be interpreted against.

## Board and dependencies

Follow the active board protocol. Claim `perf06_1`. This row requires Families 1
and 2 to be merged. You own the measurement harness, budget documentation and
narrowly-scoped optimizations that do not change behavior. Behavior-changing
fixes route as `fix06_*` rows or back to the owning row.

## 1. Measure before optimizing

- Establish the measurement method first: hardware, build type, resolution,
  settings, seed set, warm-up policy and how many samples per figure. Publish it
  so the numbers can be reproduced and compared later.
- Measure per surface, idle and active: frame cost mean, p95 and max; draw call
  and allocation behavior; and the liveness counter alongside every idle figure.
  A surface reported as cheap while idle must simultaneously prove it is alive.
- Measure the compositions `integ06_1` builds, not just isolated surfaces. The
  maximal node is the real worst case.
- Measure the coin pusher at its shipped cap, the dynamic scenario runtime with a
  full sequence staged, and the crew sequences with actors present.
- Measure a full run's trajectory: frame cost at the start versus at terminal,
  and any state growth that should be bounded.

## 2. Web and low-end

- Run the same matrix on the Web export and on a low-end profile, not only on
  native and not only on the development machine.
- Measure export size, initial load time, time to first interactive frame and
  memory ceiling on Web. Report regressions against the last recorded 0.5
  figures where a comparison exists.
- Confirm the fresh-start distribution check still passes and that a first-time
  Web player reaches play without a stall.

## 3. Budgets and enforcement

- Publish a per-surface budget table covering idle, active and worst-case
  composition, each paired with a mandatory liveness expectation.
- Add or extend automated gates so a future regression fails a suite rather than
  a playtest. Every idle budget assertion must be paired with a liveness
  counter-gate assertion in the same test, structurally, so the pair cannot be
  separated by a later well-meaning change.
- Add an assertion class for per-frame allocation and copying, so the deep-copy
  pattern cannot return silently.

## 4. Optimize only what the measurements name

- Fix what the data shows, in order of measured cost. Do not refactor for
  elegance and do not optimize a surface the numbers exonerate.
- Any optimization must preserve behavior exactly: identical outcomes, identical
  determinism, identical native/Web parity, and identical liveness. Prove each
  with the relevant gate, not by inspection.
- Anything that would change behavior, feel or timing is a finding, not a fix.
  Route it and say so.

## 5. Deliverable

A report under `docs/plans/` containing: the measurement method; the full per
surface and per composition matrix for native, Web and low-end; export size and
load figures; the published budget table with liveness pairings; every
optimization made with before-and-after numbers; and every routed finding with
severity and destination.

This row remains TODO or BLOCKED if any surface reports an idle figure without a
passing liveness counter, if any budget is exceeded without an owner-approved
exception, if Web or low-end regresses against 0.5 figures without an explanation
the report can defend, or if an optimization changed behavior. Archive with the
report path and exact commands on the board.
