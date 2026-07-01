# Pinball Rework Progress

Started: 2026-07-01
Spec: `docs/plans/pinball_feature_rework_plan.md`
Feel reference: `docs/plans/pinball_feel_reference.md`

## Binding Working Rules

- Resume from the first phase that is not marked complete with recorded
  verification evidence.
- After every phase, record status, files changed, verification commands, and
  actual output or a faithful summary with the pass/fail line verbatim.
- Do not mark a phase complete with a failing gate.
- Commit at each phase boundary with a message naming the phase.
- Final acceptance must be recorded under `FINAL ACCEPTANCE` with fresh command
  output.

Known baseline note from the prompt: `foundation_performance_probe`
slot-autoplay failures are pre-existing and must not be chased unless new
failures are introduced.

## Original Intent Checklist

1. Physics, bounces, and streaks of a real pinball table.
2. Feature sequence events like an actual pinball-branded slot machine feature.
3. Skill-based, timing-based shot system with player/item edge.
4. Quick playout with lifelike physics and upward bumps from bumpers, flippers,
   and launchers.
5. Fully designed machine layouts with named hittable sequences.
6. Dynamic plinko/pinball board interactable through nudges.
7. Ballionaire-like satisfaction and smoothness.
8. Six existing pinball items work in the new system, plus new items.
9. Game-wide slowdown during the feature eliminated.

## Phase 0 - Ballionaire Research Capture

Status: COMPLETE
Completed: 2026-07-01

Files changed:
- `docs/plans/pinball_feel_reference.md`
- `docs/plans/pinball_feature_rework_plan.md`
- `docs/plans/pinball_rework_progress.md`

Research sources:
- Steam store: https://store.steampowered.com/app/2667120/Ballionaire/
- Raw Fury official page: https://rawfury.com/games/ballionaire/
- Rogueliker demo writeup: https://rogueliker.com/ballionaire-demo/
- Rogueliker early-access impressions:
  https://rogueliker.com/ballionaire-early-access-review/
- Guardian review:
  https://www.theguardian.com/games/2025/jan/11/ballionaire-newobject-rawfury-review-addictive-pinball-inspired-strategy-game
- Vice review:
  https://www.vice.com/en/article/ballionaire-brings-something-different-to-roguelikes-review/
- Openindie/newobject interview listing:
  https://openindie.eu/podcasts/ballionaire/
- Gameplay/review video references:
  https://www.youtube.com/watch?v=-ZCfoGHpq5I,
  https://www.youtube.com/watch?v=4dgBP5K701c,
  https://www.youtube.com/watch?v=n27yijGz6FY,
  https://www.youtube.com/watch?v=TJcPLB_I2xA

Research output:
- Wrote `docs/plans/pinball_feel_reference.md`.
- Extracted numeric targets for launch readiness, first payout latency,
  untouched fall, per-ball playout, full feature duration by board, event
  density, chain burst density, tally timing, board aspect, live ball cap,
  nudge budget, flipper rescue timing, skill edge, and performance budgets.
- Reconciled plan section 3.4: gravity, peg restitution, bumper kick, flipper
  rescue timing, event density, and tally targets updated to match the Phase 0
  reference.

Verification commands:

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_performance_probe.gd' -- 240
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_PERF_VISUAL mode=em_bumper_drop frames=240 avg_surface_us=469.058 avg_signature_us=270.250 avg_draw_us=980.237 avg_total_us=1719.546 max_draw_calls=358 max_label_calls=22 max_hit_calls=73
PINBALL_PERF_VISUAL mode=lane_multiball frames=240 avg_surface_us=608.987 avg_signature_us=383.725 avg_draw_us=1272.125 avg_total_us=2264.838 max_draw_calls=491 max_label_calls=26 max_hit_calls=73
PINBALL_PERF_VISUAL mode=video_feature frames=240 avg_surface_us=607.058 avg_signature_us=412.746 avg_draw_us=1477.638 avg_total_us=2497.442 max_draw_calls=559 max_label_calls=29 max_hit_calls=73
PINBALL_PERF_OVERALL status=PASS failures=0
```

Baseline metrics for final comparison:
- `em_bumper_drop`: avg_total_us 1719.546, avg_surface_us 469.058
- `lane_multiball`: avg_total_us 2264.838, avg_surface_us 608.987
- `video_feature`: avg_total_us 2497.442, avg_surface_us 607.058

## Phase 1 - Sim Core

Status: COMPLETE
Completed: 2026-07-01

Files changed:
- `scripts/games/slots/pinball/pinball_boards.gd`
- `scripts/games/slots/pinball/pinball_board.gd`
- `scripts/games/slots/pinball/pinball_sim.gd`
- `tools/pinball_sim_probe.gd`
- `docs/plans/pinball_rework_progress.md`

Feel reference citations:
- `docs/plans/pinball_feel_reference.md` target "Untouched top-to-bottom
  fall" and "Normal single-ball playout": Phase 1 Board A uses fast gravity,
  peg contacts, bumpers, launcher, and flipper rescue to produce quick
  253.22-tick average headless drains.
- `docs/plans/pinball_feel_reference.md` target "Sim tick budget": Phase 1
  probe measured 41.394us average at four active balls.
- `docs/plans/pinball_feel_reference.md` target "Hot-loop allocation budget":
  Phase 1 probe measured object_delta=0 around the hot tick loop.

Verification commands:

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/pinball_sim_probe.gd' -- 100
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_DETERMINISM seeds=100 status=PASS
PINBALL_SIM_DRAIN board=bumper_alley seeds=100 drained=100 avg_ticks=253.22 avg_events=16.88 avg_award=49.14 max_events_tick=3 event_types=["1","9","8","4","5","2","3","6","12","11","7"]
PINBALL_SIM_PERF ticks=2400 avg_tick_us=41.394 sim_reported_avg_us=40.102 max_tick_us=80 object_delta=0 max_active=4 status=PASS
PINBALL_SIM_PROBE_OVERALL status=PASS failures=0
```

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke -NoImport
```

Output:

```text
validate_project                PASS     1313ms
gdscript_load_check             PASS     7253ms
foundation_smoke                PASS    32294ms
ui_scene_compile                PASS    27759ms
roulette_audio_audit            PASS     2615ms
Report: D:\Projects\Beat-The-House\.tmp\test_reports\20260701_180003_smoke\summary.json
Beat the House Godot checks passed. Suite=Smoke
```

## Phase 2 - Runtime Integration

Status: NOT STARTED

## Phase 3 - Sequencer + Boards B/C

Status: NOT STARTED

## Phase 4 - Skill Layer

Status: NOT STARTED

## Phase 5 - Items

Status: NOT STARTED

## Phase 6 - Juice + Polish

Status: NOT STARTED

## FINAL ACCEPTANCE

Status: NOT STARTED

- [ ] `powershell -File tools/check_godot.ps1 -Suite Full` passes, with no
  failures other than the documented pre-existing baseline.
- [ ] Determinism probe: same seed + same input script produces identical
  results across 100 seeds.
- [ ] Performance: rewritten pinball perf probe meets plan 3.5 budgets and
  Phase 0 baseline comparison shows order-of-magnitude feature-time frame-cost
  reduction.
- [ ] All 3 boards playable end to end and every named sequence reachable and
  pays.
- [ ] Skill-edge probe: perfect-play policy beats random by +15-25% across
  1000 seeds under session cap.
- [ ] All 6 existing items verified active; at least 3 new items implemented
  end to end and verified.
- [ ] Nudge, tilt meter, tilt dampener, and flipper rescue functional and
  covered by probe/test assertion.
- [ ] `scripts/games/slots/slot_pinball_table.gd` deleted and grep shows no
  remaining references to it or removed per-tick session round-tripping.
- [ ] Every numeric feel target in `docs/plans/pinball_feel_reference.md`
  checked off with rationale.
- [ ] Final summary maps all 9 original intent points to concrete evidence.
