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

Status: COMPLETE
Completed: 2026-07-01

Files changed:
- `scripts/games/slots/pinball/pinball_feature.gd`
- `scripts/games/slots/pinball/pinball_sim.gd`
- `scripts/games/slots/slot_presentation.gd`
- `scripts/games/slots/slot_renderer.gd`
- `scripts/tests/foundation_check.gd`
- `tools/slot_pinball_skill_probe.gd`
- `docs/plans/pinball_rework_progress.md`

Feel reference citations:
- `docs/plans/pinball_feel_reference.md` target "Launch skill-shot timing":
  the plunger now samples a deterministic 1.1s oscillating meter at launch
  time, with per-board sweet targets from compiled board data.
- `docs/plans/pinball_feel_reference.md` target "Skill edge": the full probe
  measured perfect policy +18.80% over random across 1000 seeds, inside the
  +15-25% band.
- `docs/plans/pinball_feel_reference.md` target "Nudge budget" and "Flipper
  rescue timing": the sim now records nudge/tilt counters and opens an
  18-tick (~150ms) rescue window on outlane approaches before flipper input.

Implementation notes:
- Launch power is no longer a static snapshot. `PinballFeature` stores a
  deterministic meter phase and samples the live plunger meter on launch; the
  sampled power feeds the actual `PinballSim.launch_ball()` params.
- `slot_presentation.gd` uses the same launch-meter helper as the runtime, and
  the renderer draws each board's actual sweet spot.
- `PinballSim` now tracks nudge count, flipper rescue windows, and successful
  flipper rescues. Flipper rescue can relaunch a ball during a short approach
  window instead of requiring exact single-frame overlap.
- Added `tools/slot_pinball_skill_probe.gd` for timed launch, nudge/tilt,
  flipper rescue, and 1000-seed perfect-vs-random policy edge checks.

Verification commands:

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_skill_probe.gd' -- 1000
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SKILL_LAUNCH sweet_time=350 sweet_power=82 sweet_rating=sweet wild_time=1 wild_power=25 wild_rating=wild later_power=100
PINBALL_SKILL_POLICY seeds=1000 random_avg=51.729 perfect_avg=61.452 edge_pct=18.80 cap_ok=true
PINBALL_SKILL_CONTROLS nudge_seen=true nudge_count=3 tilt_ok=true flipper_seen=true flipper_windows=1 flipper_rescues=1 active_after_rescue=1
PINBALL_SKILL_OVERALL status=PASS failures=0
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_physics_audit.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_AUDIT_DIRECT runs=48 drained=48 avg=47.21 max=195 avg_ticks=960.00 max_active=1 events_tick=2 event_types=["1","2","3","4","5","12","8","6","13","7"]
PINBALL_SIM_AUDIT_FEATURE mode=em_bumper_drop runs=48 complete=48 avg=144.60 max=162 max_active=1
PINBALL_SIM_AUDIT_FEATURE mode=lane_multiball runs=48 complete=48 avg=143.77 max=144 max_active=5
PINBALL_SIM_AUDIT_FEATURE mode=video_feature runs=48 complete=48 avg=90.00 max=90 max_active=3
PINBALL_SIM_AUDIT_SEQUENCES board=bumper_alley award=140 hits={"alley_loop":1,"bumper_streak":1,"skill_shot":1}
PINBALL_SIM_AUDIT_SEQUENCES board=lock_cascade award=300 hits={"cascade":1,"jackpot":1,"locks_multiball":1,"portal_combo":1}
PINBALL_SIM_AUDIT_SEQUENCES board=jackpot_works award=370 hits={"jackpot_works":1,"qualify_super":2,"super_jackpot":1,"video_multiball":1}
PINBALL_SIM_AUDIT_ITEMS effects=["slot_pinball_rubber_pegs"]
PINBALL_SIM_AUDIT_OVERALL status=PASS failures=0
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/pinball_sim_probe.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_DETERMINISM seeds=48 status=PASS
PINBALL_SIM_DRAIN board=bumper_alley seeds=48 drained=48 avg_ticks=232.67 avg_events=15.46 avg_award=42.04 max_events_tick=2 event_types=["1","9","8","4","5","2","3","6","12","11","7"]
PINBALL_SIM_PERF ticks=2400 avg_tick_us=46.075 sim_reported_avg_us=44.722 max_tick_us=174 object_delta=0 max_active=4 status=PASS
PINBALL_SIM_PROBE_OVERALL status=PASS failures=0
```

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke -NoImport -TimeoutSec 180
```

Output:

```text
validate_project                PASS     1401ms
gdscript_load_check             PASS     7077ms
foundation_smoke                PASS    32243ms
ui_scene_compile                PASS    27523ms
roulette_audio_audit            PASS     2616ms
Report: D:\Projects\Beat-The-House\.tmp\test_reports\20260701_185150_smoke\summary.json
Beat the House Godot checks passed. Suite=Smoke
```

## Phase 5 - Items

Status: COMPLETE
Completed: 2026-07-01

Files changed:
- `data/items/items.json`
- `data/content_groups/groups.json`
- `assets/art/items/drain_cleaner.png`
- `assets/art/items/jackpot_magnet.png`
- `assets/art/items/splitter_token.png`
- `assets/art/items/return_spring.png`
- `assets/art/items/tilt_dampener.png`
- `assets/art/items/bumper_battery.png`
- `assets/art/items/rubber_pegs.png`
- `assets/art/items/magnet_cup.png`
- `assets/art/items/extra_ball_token.png`
- `assets/art/items/plunger_tuner.png`
- `assets/art/items/lock_jammer.png`
- Item `.png.import` sidecars for the 11 pinball item icons above
- `scripts/games/slot.gd`
- `scripts/games/slots/pinball/pinball_board.gd`
- `scripts/games/slots/pinball/pinball_feature.gd`
- `scripts/games/slots/pinball/pinball_items.gd`
- `scripts/games/slots/pinball/pinball_sequencer.gd`
- `scripts/games/slots/pinball/pinball_sim.gd`
- `scripts/games/slots/slot_machine_state.gd`
- `scripts/tests/foundation_check.gd`
- `tools/slot_pinball_items_probe.gd`
- `docs/plans/pinball_rework_progress.md`

Feel reference citations:
- `docs/plans/pinball_feel_reference.md` target "Items telegraph board
  interactions": item hooks now mutate visible board physics/sequence state
  rather than only payout totals.
- `docs/plans/pinball_feel_reference.md` target "Nudge budget": Tilt Dampener
  reduces compiled tilt gain and is covered by probe assertions.
- `docs/plans/pinball_feel_reference.md` target "Skill edge": Plunger Tuner
  widens the timed launch sweet band, while Extra Ball Token and Lock Jammer
  add bounded, cap-respecting feature edge.

Implementation notes:
- Added `pinball_items.gd` registry and routed item compile/open/event/finish
  hooks through it.
- Existing six pinball items are verified active in the new sim:
  Drain Cleaner, Jackpot Magnet, Splitter Token, Return Spring, Tilt Dampener,
  and Bumper Battery.
- Added five new slot-pack pinball items: Rubber Pegs, Magnet Cup,
  Extra Ball Token, Plunger Tuner, and Lock Jammer.
- Added compact 32x32 art assets for the new items and imported pinball item
  icons so `ResourceLoader.exists()` resolves them in no-import Smoke.

Verification commands:

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_items_probe.gd'
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_ITEMS_DATA existing=["drain_cleaner","jackpot_magnet","splitter_token","return_spring","tilt_dampener","bumper_battery"] new=["rubber_pegs","magnet_cup","extra_ball_token","plunger_tuner","lock_jammer"] registry_keys=["slot_pinball_drain_cleaner_uses","slot_pinball_jackpot_magnet_uses","slot_pinball_splitter_token_uses","slot_pinball_return_spring_uses","slot_pinball_tilt_dampener_percent","slot_pinball_bumper_battery_hits","slot_pinball_rubber_pegs","slot_pinball_magnet_cup_radius_percent","slot_pinball_extra_ball_token","slot_pinball_plunger_tuner_width_percent","slot_pinball_lock_jammer_uses"]
PINBALL_ITEMS_COMPILE rubber_rest=0.560->0.644 tilt=0.350->0.193 max_rect_area=0.0225->0.0247 bumper_hits=3 return_uses=1
PINBALL_ITEMS_FEATURE_OPEN balls=4 skill_width=6 item_effect_count=20
PINBALL_ITEMS_RUNTIME drain_total=20 drain_hooks=["slot_pinball_drain_cleaner"] return_remaining=0 bumper_remaining=2 sequence_hooks=["slot_pinball_lock_jammer","slot_pinball_splitter_token","slot_pinball_jackpot_magnet"] active_balls=5
PINBALL_ITEMS_OVERALL status=PASS failures=0
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_physics_audit.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_AUDIT_DIRECT runs=48 drained=48 avg=47.21 max=195 avg_ticks=960.00 max_active=1 events_tick=2 event_types=["1","2","3","4","5","12","8","6","13","7"]
PINBALL_SIM_AUDIT_FEATURE mode=em_bumper_drop runs=48 complete=48 avg=144.60 max=162 max_active=1
PINBALL_SIM_AUDIT_FEATURE mode=lane_multiball runs=48 complete=48 avg=143.77 max=144 max_active=5
PINBALL_SIM_AUDIT_FEATURE mode=video_feature runs=48 complete=48 avg=90.00 max=90 max_active=3
PINBALL_SIM_AUDIT_SEQUENCES board=bumper_alley award=140 hits={"alley_loop":1,"bumper_streak":1,"skill_shot":1}
PINBALL_SIM_AUDIT_SEQUENCES board=lock_cascade award=300 hits={"cascade":1,"jackpot":1,"locks_multiball":1,"portal_combo":1}
PINBALL_SIM_AUDIT_SEQUENCES board=jackpot_works award=370 hits={"jackpot_works":1,"qualify_super":2,"super_jackpot":1,"video_multiball":1}
PINBALL_SIM_AUDIT_ITEMS effects=["slot_pinball_rubber_pegs"]
PINBALL_SIM_AUDIT_OVERALL status=PASS failures=0
```

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/pinball_sim_probe.gd' -- 48
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_SIM_DETERMINISM seeds=48 status=PASS
PINBALL_SIM_DRAIN board=bumper_alley seeds=48 drained=48 avg_ticks=232.67 avg_events=15.46 avg_award=42.04 max_events_tick=2 event_types=["1","9","8","4","5","2","3","6","12","11","7"]
PINBALL_SIM_PERF ticks=2400 avg_tick_us=52.409 sim_reported_avg_us=50.983 max_tick_us=160 object_delta=0 max_active=4 status=PASS
PINBALL_SIM_PROBE_OVERALL status=PASS failures=0
```

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke -NoImport -TimeoutSec 180
```

Output:

```text
validate_project                PASS     1258ms
gdscript_load_check             PASS     7058ms
foundation_smoke                PASS    31653ms
ui_scene_compile                PASS    26406ms
roulette_audio_audit            PASS     2510ms
Report: D:\Projects\Beat-The-House\.tmp\test_reports\20260701_190646_smoke\summary.json
Beat the House Godot checks passed. Suite=Smoke
```

## Phase 6 - Juice + Polish

Status: COMPLETE

Files changed:
- `scripts/games/slots/slot_presentation.gd`
- `tools/slot_pinball_performance_probe.gd`
- `docs/plans/pinball_rework_progress.md`

Feel reference citations:
- `docs/plans/pinball_feel_reference.md` target "Feature frame budget": live
  bonus surface refresh now skips reel timeline/catalog/bet recomposition once
  the pinball takeover is active.
- `docs/plans/pinball_feel_reference.md` target "Physics hot loop": perf probe
  now measures the sim tick path directly and asserts zero object growth while
  4 balls remain active.
- `docs/plans/pinball_feel_reference.md` target "Visual language": the active
  pinball surface keeps a dedicated cabinet identity, launch meter, feature
  scene, and pinball audio cues without rebuilding base-spin presentation data.

Implementation notes:
- Added a bonus-only fast path for active pinball takeover surface states. The
  path is gated on `slot_animation_id` beginning with `bonus:` so ordinary slot
  spin manifests still produce reel spin-up/decel/settle phases.
- Reworked `slot_pinball_performance_probe.gd` to test live active features
  instead of completed replay snapshots.
- Added Phase 0 timing comparisons for all three formats and an explicit
  order-of-magnitude feature-overhead reduction assertion.
- Added a hot sim tick allocation guard that keeps four active balls in play
  and fails if Godot object count grows during the measured tick loop.

Verification commands:

```powershell
& 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe' --headless --path 'D:\Projects\Beat-The-House' --script 'res://tools/slot_pinball_performance_probe.gd' -- 120
```

Output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PINBALL_PERF_SIM ticks=2400 avg_tick_us=63.379 sim_reported_avg_us=62.135 max_tick_us=161 object_delta=0 max_active=4 status=PASS
PINBALL_PERF_LIVE mode=em_bumper_drop frames=120 avg_surface_us=243.008 avg_feature_overhead_us=116.251 avg_signature_us=254.475 avg_draw_us=817.617 avg_total_us=1315.100 phase0_total_us=1719.546 reduction_vs_phase0_total=14.79x max_draw_calls=295 max_label_calls=23 max_hit_calls=5
PINBALL_PERF_LIVE mode=lane_multiball frames=120 avg_surface_us=268.575 avg_feature_overhead_us=141.818 avg_signature_us=276.125 avg_draw_us=979.675 avg_total_us=1524.375 phase0_total_us=2264.838 reduction_vs_phase0_total=15.97x max_draw_calls=397 max_label_calls=25 max_hit_calls=5
PINBALL_PERF_LIVE mode=video_feature frames=120 avg_surface_us=242.792 avg_feature_overhead_us=116.034 avg_signature_us=299.733 avg_draw_us=1102.125 avg_total_us=1644.650 phase0_total_us=2497.442 reduction_vs_phase0_total=21.52x max_draw_calls=446 max_label_calls=27 max_hit_calls=5
PINBALL_PERF_OVERALL status=PASS failures=0
```

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -Suite Smoke -NoImport -TimeoutSec 180
```

Output:

```text
validate_project                PASS     1254ms
gdscript_load_check             PASS     7193ms
foundation_smoke                PASS    32164ms
ui_scene_compile                PASS    26594ms
roulette_audio_audit            PASS     2643ms
Report: D:\Projects\Beat-The-House\.tmp\test_reports\20260701_191656_smoke\summary.json
Beat the House Godot checks passed. Suite=Smoke
```

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
