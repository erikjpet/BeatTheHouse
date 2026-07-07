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
