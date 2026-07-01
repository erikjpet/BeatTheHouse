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

Status: COMPLETE
Completed: 2026-07-01

Files changed:
- `scripts/games/slots/pinball/pinball_feature.gd`
- `scripts/games/slots/slot_family_pinball.gd`
- `scripts/games/slot.gd`
- `scripts/games/slots/slot_machine_state.gd`
- `scripts/games/slots/slot_presentation.gd`
- `scripts/games/slots/slot_renderer.gd`
- `scripts/games/slots/slot_resolver.gd`
- `scripts/tests/foundation_check.gd`
- `tools/slot_pinball_physics_audit.gd`
- `tools/slot_pinball_performance_probe.gd`
- Deleted `scripts/games/slots/slot_pinball_table.gd`
- Deleted `scripts/games/slots/slot_pinball_table.gd.uid`

Integration notes:
- Slot family reel/payline contracts were restored to the prior tested shape,
  while `open_feature`, `step_bonus`, and preview now delegate to the new
  `PinballFeature` adapter.
- Surface refresh advances live visual pinball state through `pinball_view`
  instead of dispatching `slot_bonus_tick`.
- Renderer, state normalization, resolver metrics, foundation checks, and audit
  tools now read compact `pinball_view`/`pinball_summary` payloads instead of
  round-tripping `pinball_session`.
- `scripts/tools` grep is clean for `pinball_session`, `slot_pinball_table`,
  `slot_bonus_tick`, and `SlotPinballTable`.
- Current visual perf guardrails pass; the stricter order-of-magnitude final
  budget remains Phase 6 work.

Verification commands:

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke -NoImport -TimeoutSec 180
```

Output:

```text
validate_project                PASS     1299ms
gdscript_load_check             PASS     6155ms
foundation_smoke                PASS    32900ms
ui_scene_compile                PASS    28924ms
roulette_audio_audit            PASS     1592ms
Report: D:\Projects\Beat-The-House\.tmp\test_reports\20260701_182654_smoke\summary.json
Beat the House Godot checks passed. Suite=Smoke
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/pinball_sim_probe.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_DETERMINISM seeds=48 status=PASS
PINBALL_SIM_DRAIN board=bumper_alley seeds=48 drained=48 avg_ticks=230.85 avg_events=15.17 avg_award=39.94 max_events_tick=2 event_types=["1","9","8","4","5","2","3","6","12","11","7"]
PINBALL_SIM_PERF ticks=2400 avg_tick_us=50.502 sim_reported_avg_us=48.857 max_tick_us=993 object_delta=0 max_active=4 status=PASS
PINBALL_SIM_PROBE_OVERALL status=PASS failures=0
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_physics_audit.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_AUDIT_DIRECT runs=48 drained=48 avg=47.21 max=195 avg_ticks=960.00 max_active=1 events_tick=2 event_types=["1","2","3","4","5","12","8","6","13","7"]
PINBALL_SIM_AUDIT_FEATURE mode=em_bumper_drop runs=48 complete=48 avg=134.60 max=162 max_active=1
PINBALL_SIM_AUDIT_FEATURE mode=lane_multiball runs=48 complete=48 avg=135.10 max=144 max_active=3
PINBALL_SIM_AUDIT_FEATURE mode=video_feature runs=48 complete=48 avg=85.23 max=90 max_active=1
PINBALL_SIM_AUDIT_ITEMS effects=["slot_pinball_rubber_pegs"]
PINBALL_SIM_AUDIT_OVERALL status=PASS failures=0
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_performance_probe.gd' -- 120
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_PERF_VISUAL mode=em_bumper_drop frames=120 avg_surface_us=1358.142 avg_signature_us=664.508 avg_draw_us=1605.175 avg_total_us=3627.825 max_draw_calls=383 max_label_calls=24 max_hit_calls=5
PINBALL_PERF_VISUAL mode=lane_multiball frames=120 avg_surface_us=1407.425 avg_signature_us=724.192 avg_draw_us=1718.250 avg_total_us=3849.867 max_draw_calls=414 max_label_calls=24 max_hit_calls=5
PINBALL_PERF_VISUAL mode=video_feature frames=120 avg_surface_us=1268.167 avg_signature_us=676.150 avg_draw_us=1600.550 avg_total_us=3544.867 max_draw_calls=383 max_label_calls=23 max_hit_calls=5
PINBALL_PERF_OVERALL status=PASS failures=0
```

## Phase 3 - Sequencer + Boards B/C

Status: COMPLETE
Completed: 2026-07-01

Files changed:
- `scripts/games/slots/pinball/pinball_boards.gd`
- `scripts/games/slots/pinball/pinball_feature.gd`
- `scripts/games/slots/pinball/pinball_sequencer.gd`
- `scripts/games/slots/slot_machine_state.gd`
- `tools/slot_pinball_physics_audit.gd`
- `docs/plans/pinball_rework_progress.md`

Feel reference citations:
- `docs/plans/pinball_feel_reference.md` target "Full feature duration by
  board": Board B and C max-tick/active-ball settings are bounded for quick
  headless completion while allowing 3-ball multiball.
- `docs/plans/pinball_feel_reference.md` target "Visible event density":
  Board B/C use dense peg fields, pop bumpers, launchers, splitter/multiplier
  sensors, and pockets to maintain frequent readable cause/effect events.
- `docs/plans/pinball_feel_reference.md` target "Trigger-chain clarity":
  sequencer state now carries named sequence hits, lit inserts, locks,
  multiball state, and jackpot/super state as compact summary data.

Implementation notes:
- Added Board B `Lock & Cascade` and Board C `Jackpot Works` as real compiled
  board layouts mapped to `lane_multiball` and `video_feature`.
- Added `pinball_sequencer.gd` for Board A/B/C named sequence state:
  `skill_shot`, `bumper_streak`, `alley_loop`, `locks_multiball`, `cascade`,
  `jackpot`, `portal_combo`, `qualify_super`, `super_jackpot`,
  `video_multiball`, and `jackpot_works`.
- Runtime summaries now include sequencer state, lit inserts, sequence events,
  locks, multiball, and jackpot state without restoring the old per-tick
  session payload.
- Physics audit now includes scripted sequence reachability evidence for all
  three boards.

Verification commands:

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_physics_audit.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_AUDIT_DIRECT runs=48 drained=48 avg=47.21 max=195 avg_ticks=960.00 max_active=1 events_tick=2 event_types=["1","2","3","4","5","12","8","6","13","7"]
PINBALL_SIM_AUDIT_FEATURE mode=em_bumper_drop runs=48 complete=48 avg=141.27 max=162 max_active=1
PINBALL_SIM_AUDIT_FEATURE mode=lane_multiball runs=48 complete=48 avg=141.73 max=144 max_active=3
PINBALL_SIM_AUDIT_FEATURE mode=video_feature runs=48 complete=48 avg=89.98 max=90 max_active=3
PINBALL_SIM_AUDIT_SEQUENCES board=bumper_alley award=140 hits={"alley_loop":1,"bumper_streak":1,"skill_shot":1}
PINBALL_SIM_AUDIT_SEQUENCES board=lock_cascade award=300 hits={"cascade":1,"jackpot":1,"locks_multiball":1,"portal_combo":1}
PINBALL_SIM_AUDIT_SEQUENCES board=jackpot_works award=370 hits={"jackpot_works":1,"qualify_super":2,"super_jackpot":1,"video_multiball":1}
PINBALL_SIM_AUDIT_ITEMS effects=["slot_pinball_rubber_pegs"]
PINBALL_SIM_AUDIT_OVERALL status=PASS failures=0
```

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke -NoImport -TimeoutSec 180
```

Output:

```text
validate_project                PASS     1407ms
gdscript_load_check             PASS     7354ms
foundation_smoke                PASS    34498ms
ui_scene_compile                PASS    29350ms
roulette_audio_audit            PASS     2771ms
Report: D:\Projects\Beat-The-House\.tmp\test_reports\20260701_184149_smoke\summary.json
Beat the House Godot checks passed. Suite=Smoke
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/pinball_sim_probe.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_DETERMINISM seeds=48 status=PASS
PINBALL_SIM_DRAIN board=bumper_alley seeds=48 drained=48 avg_ticks=230.85 avg_events=15.17 avg_award=39.94 max_events_tick=2 event_types=["1","9","8","4","5","2","3","6","12","11","7"]
PINBALL_SIM_PERF ticks=2400 avg_tick_us=51.187 sim_reported_avg_us=49.527 max_tick_us=698 object_delta=0 max_active=4 status=PASS
PINBALL_SIM_PROBE_OVERALL status=PASS failures=0
```

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
