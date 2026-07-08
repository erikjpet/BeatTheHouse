# Execution Record

- Completion date: 2026-07-08.
- Implementing commits:
  - `aa6488a Report collection engagement in endgame metrics`
  - `89db5cd Preserve world map pooled hit targets`
  - `a7fc4ad Keep world map hit pool within soak budget`
  - `873f17c Cap world map hit pool at soak budget`
  - `08d1d17 Prewarm world map overlay at run start`
  - `263913a Stabilize world map badge pooling for soak`
  - `b3806b3 Stabilize mouse QA multi-game coverage`
  - `9a975f9 Stabilize mouse QA lender fixture routing`
- Evidence document: `docs/plans/0.4_act1_completion_plan.md`, section
  "Final Balance And Release Gate Evidence".
- Balance metrics:
  - `tools/endgame_metrics_probe.gd -- --seed-prefix=V04-FINAL --seeds-per-scenario=2 --output=res://.tmp/endgame_metrics_probe/v04_final.json --report=res://.tmp/endgame_metrics_probe/v04_final.md` - PASS; deterministic, 10 runs, victory rate 0.70, median 23.53 minutes, clean victory 0.6667, cheat victory 0.75, tier-2 0.70, lender 0.50, challenge 0.40, collection engagement 0.60, showdown 3/3.
- Verification gates:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 1800` - PASS; final report `.tmp/test_reports/20260708_044027_full/summary.json`.
  - Every `FoundationSuite` (`smoke`, `systems`, `ui`, `contracts`, `games`, `slot`, `slot_acceptance`, `blackjack`, `roulette`, `baccarat`, `video_poker`, `bar_dice`, `pull_tabs`, `audit`) - PASS on 2026-07-08 after final fixes.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot` - PASS; all seven game surfaces, all renderer coverage, and new v0.4 surfaces covered. The existing slot-autoplay dev-box headroom waiver remains web-gated.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28 -SeedPrefix V04-SOAK` - PASS; 19 samples, retained memory +987,350 bytes, retained nodes +1.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix V04-DETERMINISM` - PASS; 318 checkpoints, combined hash `3248604252`.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200` - PASS; 200 seeds, 0 stuck states.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot` - PASS; strict gate true, 60/60 playable, R100 60/60, victories 60/60, true failures 0.
  - `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1` - PASS; `.tmp/web_perf_smoke/report.summary.json`, Chrome 4x ready 14,143ms / 20,000ms, no failures.
- Root-cause fixes during the gate:
  - The 180-minute soak exposed a finite world-map UI allocation spike from lazy route badge cell creation. The map detail badge row now uses a fixed reusable cell pool.
  - The strict mouse batch exposed nondeterministic QA steering: multi-game coverage depended on generated rooms, and a lender route could bankrupt the run before save/load. Visual QA now steers to deterministic multi-game and lender fixtures.

# Agent Prompt - v0.4 Final Balance And Release Gate

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This task runs after all v0.4 feature/content prompts land. It
proves the Act 1 completion cut is playable, balanced, deterministic, and free
of known release-gate failures.

## Read first

- `docs/plans/0.4_act1_completion_plan.md`
- `README.md`
- `docs/plans/0.3.2_release_checklist.md`
- `tools/endgame_metrics_probe.gd`
- `tools/foundation_mouse_batch_playtest.ps1`
- `tools/foundation_performance_probe.ps1`
- `tools/foundation_soak_probe.ps1`
- `tools/foundation_determinism_probe.ps1`
- `tools/foundation_stuck_state_sweep.ps1`
- `tools/web_perf_smoke.ps1`

## Required work

1. Run the full validation matrix below on the current v0.4 candidate.
2. If any gate fails, fix the root cause unless the failure is an external
   credential/platform blocker already documented by the command itself.
3. Run `tools/endgame_metrics_probe.gd` with enough seeds to compare against
   the 0.3.2 T73-TUNED12 envelope. Record victory rate, clean/cheat split,
   tier-2 rate, lender rate, challenge rate, collection engagement, median
   minutes, and showdown route rate. If the probe does not yet emit
   collection-engagement metrics (it predates the collection loops), extend
   the probe to report them — do not skip the metric or estimate it by hand.
   If collection loadouts significantly change run outcomes, tune data
   rather than weakening checks.
4. Run the strict 60-run mouse batch. 0.4 is an Act 1 completion cut, so do
   not substitute the old 3-run 0.3 fast smoke for final release evidence.
5. Record a concise before/after table in `docs/plans/0.4_act1_completion_plan.md`.

## Gate matrix

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 1800`
- Every `FoundationSuite`: smoke, systems, ui, contracts, games, slot,
  slot_acceptance, blackjack, roulette, baccarat, video_poker, bar_dice,
  pull_tabs, audit.
- `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot`
- `powershell -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28 -SeedPrefix V04-SOAK`
- `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix V04-DETERMINISM`
- `powershell -ExecutionPolicy Bypass -File tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200`
- `powershell -ExecutionPolicy Bypass -File tools\foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot`
- `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1`

## Hard constraints

- Do not overlap Godot gates.
- Do not hide failures by changing command budgets or validators.
- Do not expand the boss fight/final scene. The existing Grand Casino route
  may be exercised as part of balance, but new finale content is out of scope.

## Done gate

- All commands above pass or have a documented external-only blocker.
- Metrics are recorded in the v0.4 plan.
- Prompt archived to `docs/todone/` with execution record and committed
  locally.
