# Beat the House 0.5 Repository Release Readiness

Date: 2026-07-17 (America/Chicago)

Tested source commit: `31f0020b` (`Handle blocking dialogue in strict mouse QA`)

Result: **PASS — repository gates are green.**
Scope: Grand Casino rework slices `gc05_1` through `gc05_9`. Packaging,
publication, and the release tag remain owner-operated actions.

The final evidence commit after this tested source commit changes only this
report, `CHANGELOG.md`, and deletion of the completed Slice 9 prompt. A final
`tools/validate_project.ps1` pass is recorded after those evidence-only edits.

## Timeout policy

Every `tools/check_godot.ps1 -RequireGodot -FoundationSuite <name>` invocation
used the runner's recorded baseline policy: `max(300s, ceil(baseline * 1.5))`.
That yields 1,053 seconds for `Slot_Acceptance` and `Audit`, and 300 seconds for
all other accepted names. No test was trimmed, skipped, muted, or deleted.
Godot gates and probes ran serially.

## Full supported FoundationSuite matrix

All 18 accepted non-empty names, including compatibility aliases, passed.
Durations below are the measured foundation/UI stage durations; each invocation
also passed `validate_project` and `gdscript_load_check`.

| FoundationSuite | Result | Stage duration | Timeout | Report |
| --- | --- | ---: | ---: | --- |
| `Smoke` | PASS | 23.159s | 300s | `.tmp/test_reports/20260717_021628_smoke/summary.json` |
| `Contracts` | PASS | 113.465s | 300s | `.tmp/test_reports/20260717_021720_smoke/summary.json` |
| `Contract` alias | PASS | 113.476s | 300s | `.tmp/test_reports/20260717_021941_smoke/summary.json` |
| `Games` | PASS | 113.104s | 300s | `.tmp/test_reports/20260717_022203_smoke/summary.json` |
| `Systems` | PASS | 20.116s | 300s | `.tmp/test_reports/20260717_022425_smoke/summary.json` |
| `UI` | PASS | 79.407s | 300s | `.tmp/test_reports/20260717_022513_smoke/summary.json` |
| `Slot` | PASS | 21.686s | 300s | `.tmp/test_reports/20260717_022701_smoke/summary.json` |
| `Slots` alias | PASS | 21.585s | 300s | `.tmp/test_reports/20260717_022751_smoke/summary.json` |
| `Slot_Acceptance` | PASS | 479.859s | 1,053s | `.tmp/test_reports/20260717_022841_smoke/summary.json` |
| `Blackjack` | PASS | 8.675s | 300s | `.tmp/test_reports/20260717_023710_smoke/summary.json` |
| `Roulette` | PASS | 8.655s | 300s | `.tmp/test_reports/20260717_023747_smoke/summary.json` |
| `Baccarat` | PASS | 8.603s | 300s | `.tmp/test_reports/20260717_023823_smoke/summary.json` |
| `Video_Poker` | PASS | 62.710s | 300s | `.tmp/test_reports/20260717_023901_smoke/summary.json` |
| `Bar_Dice` | PASS | 32.288s | 300s | `.tmp/test_reports/20260717_024031_smoke/summary.json` |
| `Pull_Tabs` | PASS | 9.108s | 300s | `.tmp/test_reports/20260717_024132_smoke/summary.json` |
| `Audit` | PASS | 480.139s | 1,053s | `.tmp/test_reports/20260717_024210_smoke/summary.json` |
| `All` | PASS | 117.027s | 300s | `.tmp/test_reports/20260717_025038_smoke/summary.json` |
| `Full` alias | PASS | 115.266s | 300s | `.tmp/test_reports/20260717_025303_smoke/summary.json` |

Standalone `tools/validate_project.ps1`: **PASS** in 19.0 seconds before the
matrix. Post-evidence `tools/validate_project.ps1`: **PASS** in 18.9 seconds
after the report, CHANGELOG citation, and completed-prompt deletion.

## Dedicated release probes

| Gate | Result | Evidence |
| --- | --- | --- |
| Foundation performance | PASS | 33.1s; 59 observations across 8 seeds; every renderer, game surface, resolve path, and new surface covered. |
| Foundation soak | PASS | 707.9s; 180 simulated minutes, 504 measured actions, 19 samples, zero orphans, memory growth 739,122 bytes, object growth -12, node growth -6, serialized maximum 146,113 bytes. Report: `user://foundation_soak_probe_report.json`. |
| Determinism, 10 seeds | PASS | Two executions, 319 checkpoints each, identical combined hash `2644200507`. Reports: `.tmp/foundation_determinism_probe/run_a.json` and `run_b.json`. |
| Stuck-state sweep, 100 seeds | PASS | Zero stuck states; 48 slot scenarios and 9 wait/transition scenarios. |
| Visual QA | PASS | 34 states and exactly zero warnings. Report: `%APPDATA%/Godot/app_userdata/Beat the House/foundation_visual_qa_report.json`. |
| Strict mouse batch, 60 runs | PASS | 60/60 playable loops, 60/60 R100 UI regressions, 60/60 victories, zero true failures; 1,414.17s wall time; run p95 25.935s. Reports: `.tmp/foundation_mouse_batch/aggregate_summary.json` and `aggregate_summary.md`. |
| Web performance smoke | PASS | Chrome, 4x CPU throttle, 20 scenarios, zero failures; report `.tmp/web_perf_smoke/report.json`, summary `.tmp/web_perf_smoke/report.summary.json`. |
| Endgame metrics, 40 runs | PASS | Four scenarios x 10 seeds, both routes, three duel outcomes; reports `.tmp/endgame_metrics_probe/release_40.json` and `release_40.md`. |

### Performance highlights

| Surface/action | Measured p95 | Budget |
| --- | ---: | ---: |
| Pull Tabs resolve | 0.970ms | 2.5ms |
| Slot spin resolve | 5.467ms | 8.0ms |
| Bar Dice resolve | 0.909ms | 3.0ms |
| Blackjack resolve | 2.735ms | 5.5ms |
| Baccarat resolve | 0.993ms | 1.75ms |
| Roulette resolve | 1.180ms | 3.0ms |
| Video Poker resolve | 1.118ms | 4.5ms |
| Meta-home/talk/dialogue/map/report frames | about 6.9ms | 16.0ms |
| Grand Casino Rourke duel idle draw | 0.811ms | 5.0ms |

The native low-end proxy's pre-existing slot-autoplay waiver is closed by the
required exported-WebGL smoke: `slot_autoplay_active` measured 54.197ms p95
against 100ms under 4x CPU throttle. Other representative browser results were
active slot 62.5ms/110ms, pinball feature 144.363ms/180ms, and telemetry
overhead 0.0226ms/0.1ms. No web scenario exceeded the 128 MiB memory-delta
budget.

## Balance tuning and measured results

Only two data values changed in Slice 9. The before/after comparison uses the
same 40 deterministic runs; no performance baseline or budget changed.

| Data value | Before | After | Measured reason |
| --- | ---: | ---: | --- |
| `grand_casino_rourke_duel.correct_call_swing` | 8 chips | 18 chips | Prepared reads did not materially move the duel; the larger swing makes correct callouts consequential while the decisive-win rate remains in the hard-boss band. |
| `grand_casino_rourke_duel.shown_the_door_min` | -8 chips | -60 chips | The middle outcome was absent at 0/9 attempts; widening its data band made it meaningful without making it dominant. |

| Same-seed metric | Before | After |
| --- | ---: | ---: |
| Overall victories | 6/40 (15.0%) | 11/40 (27.5%) |
| Clean-route victories | 4/20 (20.0%) | 4/20 (20.0%) |
| Cheat-route victories | 2/20 (10.0%) | 7/20 (35.0%) |
| Showdown wins | 2/9 (22.2%) | 7/9 (77.8%) |
| Decisive duel wins | 2/9 (22.2%) | 3/9 (33.3%) |
| Shown the door | 0/9 (0.0%) | 4/9 (44.4%) |
| Duel outcome coverage | 2/3 | 3/3 |
| Median modeled duration | 6.87 min | 6.87 min |

Evidence: `.tmp/endgame_metrics_probe/balance_40.json` and
`.tmp/endgame_metrics_probe/balance_40_after.json`.

The independent final release seed set also passed:

| Final metric | Result |
| --- | ---: |
| Overall victories | 14/40 (35.0%) |
| Clean route | 4/20 (20.0%) |
| Cheat route | 10/20 (50.0%) |
| Showdown | 10/12 (83.33%) |
| Walk out clean / decisive duel | 7/12 (58.33%) |
| Shown the door | 3/12 (25.0%) |
| Taken out back | 2/12 (16.67%) |
| Duel outcome coverage | 3/3 |
| Players Card tiers | Gold 4, Silver 2, Bronze 6, none 28 |
| Median modeled duration | 6.30 min |

## Act 2 seam proof

A Gold-card clean victory sets `act_two_seam_ready = true`, records the seam
story entry once, and leaves the run terminal as the Act 1 victory. The run
report displays exactly one line: `The Gold card opens doors beyond this city.`
This contract is covered by the Systems, UI, Audit/All, determinism, and visual
gates above.

## Reported mechanical issue (not hot-patched in the data-only slice)

During probe development, the showdown `trash_item` choice rejected inventory
entries represented by dictionary/meta-collection payloads because the choice
identifier stringifies the dictionary rather than addressing its stable item
identity. The release metrics use the legal `keep_everything` path with a
non-contraband prestige item, so the issue does not invalidate the measured
route/outcome results and no mandatory gate failed. Slice 9 explicitly forbids
mechanical redesigns and requires genuine mechanical findings to be reported
rather than hot-patched; this item is therefore recorded for a later focused
fix.

## Owner actions remaining

1. Manually playtest both clean and cheat routes and explicitly reach all three
   duel endings: walk out clean, shown the door, and taken out back.
2. Run the owner-controlled export packaging for Web/itch.io and Windows.
3. Upload the approved packages to itch.io and GitHub.
4. Create and push the `0.5.0` release tag after publication is accepted.
