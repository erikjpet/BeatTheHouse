# Agent Prompt - P1: Pre-Release Full-Arc Playtest Sweep

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike preparing 0.5. This file is self-contained.

## Why this exists

The 0.5 UI overhaul was declared complete at commit `12a437b6` with a full
green gate battery. Twelve commits landed after it, and nearly all of them
were UI defect fixes found afterward:

```
c111da94 Restore animated conversation character models
68d98b85 Compact the gameplay run information header
3d3fe675 Add an exact visual run clock
5abb776b Integrate risky actions into game surfaces
dee84af0 Advance environment clock while idle
37eed9cf Fix event popup layout and unknown caller portraits
c68e84ea Add multi-person lender conversations
88f05b1e Keep environment time moving after travel
f3b52fcd Present Crew favors as group conversations
6bcd5508 Prevent selection popup text collapse
544f49f7 Add free Beach return to River Queen
```

A pattern of "declared done, then eleven fixes" means the automated gates are
not catching this class of defect - layout collapse, missing portraits,
overlapping chrome, dead clocks. The remaining risk is what a human notices
and a script does not. This task hunts for the twelfth fix before a player
finds it.

## Task

Drive the game end to end, repeatedly, and hunt for presentation and flow
defects. Use the existing playtest tooling rather than inventing your own:
`tools\foundation_mouse_playtest.ps1`,
`tools\foundation_mouse_batch_playtest.ps1`,
`tools\foundation_stuck_state_sweep.ps1`,
`tools\foundation_soak_probe.ps1`, and `tools\foundation_visual_qa.ps1`.

Cover, at minimum, these routes with several seeds each:

1. **Cold start** - first boot, no profile: start screen, new run, the
   onboarding/tutorial arc through the Cage gift shop tutorial, first game.
2. **Full clean arc** - low-stakes rooms, travel, services, lenders, debt
   pressure, drinking, heat, into the Grand Casino, Cage, Players Card
   Bronze -> Silver -> Gold, clean cashout victory.
3. **Dirty arc** - cheat heavily, trip Rourke, the four-phase back-room
   showdown and the heads-up duel, both the taken-out-back loss and the
   keep-chips-uncashed ending.
4. **Meta loop** - run end, run report, drops, home, containers, loadout,
   Sal's pawn shop, trade-up, and a second run using the loadout.
5. **Each of the eight games**, including scratch tickets, with a real
   session on each surface.

For every route check specifically: nothing overlaps, nothing clips, no text
collapses, popups fit their content, portraits and character models render,
clocks advance, the cheat dock shows correct availability, the HUD meters and
icon tray track state, conversations animate and are skippable, and no screen
dead-ends. Run every route at 1280x720 AND in small-screen mode, and repeat
the visual checks with reduce-motion enabled.

Also watch the engine log the whole time: any `ERROR:` or `SCRIPT ERROR:`
line during normal play is a defect, even if nothing visibly breaks.

## Deliverable

Write `docs/plans/0.5_prerelease_playtest_report.md`: every defect found, with
the seed and route to reproduce it, a capture, and a severity call
(blocker / should-fix / polish).

Then FIX the blockers and should-fix items in this task. For anything you
judge polish-only or too large to absorb safely, write a focused follow-up
prompt into `docs/todo/` rather than leaving it as a note - the owner works
from prompt files, not backlogs.

## Known issues already tracked - do not duplicate

- The earlier `scratch_tickets` suite crash is RESOLVED (its prompt, `p0_1`,
  was deleted as stale on 2026-07-26); the suite passes. Do not re-open it.
- The Settings-starts-a-run regression is covered by
  `docs/todo/p0_0_settings_starts_run_regression_prompt.md`.
- The `is_inside_tree` boot error and stale UI gate evidence are covered by
  `docs/todo/p0_2_boot_viewport_error_and_gate_honesty_prompt.md`.

Run after `p0_0` and `p0_2` have landed, so you are testing a green tree.

## Hard rules

- Fix root causes, never symptoms, and never weaken a test to get green.
- Zero-copy per-frame; idle-animation liveness untouched - never accept a
  0.000 idle-draw number without the liveness counter check.
- Working tree may contain other people's uncommitted work; treat it as
  user-owned, never revert or stage it. Stage explicitly, file by file.
- Style: tabs, typed GDScript, sparse comments. Captures under `.tmp/`.

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (discover the list; do not guess)
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_determinism_probe.ps1`
- `tools\foundation_stuck_state_sweep.ps1`

## On completion

Only after every gate passes AND you have completed the sweep and fixes:

1. Commit the work in logical units.
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append a short execution record to the bottom of the moved
   file (date, implementing commit hashes, gate results, deviations), and
   stage the moved file so the archive lands in the final commit. Any
   follow-up prompts you author go into `docs/todo/` (not todone).
3. PUSH to the remote.
4. Report: defect count by severity, what you fixed, what you deferred and to
   which new prompt file, and gate results.

On an unfixable failure, stop at the last green commit, do NOT push or
archive, and report verbatim.

---

## Execution record - 2026-07-26

- Implementing commit: `c8c981a7` (`Fix prerelease playtest sweep tooling`)
- Archive commit: this commit
- Result: PASS
- Defects found: 0 blockers, 2 should-fix, 0 polish. Both should-fix items were in release/playtest tooling rather than player-facing gameplay: stale-camera visible-object double-click replay in `tools/foundation_visual_qa.gd`, and plateaued retained-memory warmup misclassified as sustained soak growth in `tools/foundation_soak_probe.gd`.
- Playtest report: `docs/plans/0.5_prerelease_playtest_report.md`
- Deviations: A separate trailer-rendering task repeatedly launched Godot during the FoundationSuite rerun. Contended guard attempts were discarded; counted gate results were rerun isolated after the trailer chain cleared. The first full soak attempt used too small a wrapper timeout and was inconclusive; the default soak was rerun with a larger timeout, fixed, and rerun to PASS.
- Gates:
  - `tools\validate_project.ps1`: PASS
  - Supported `-FoundationSuite` arguments: PASS 19/19 (`smoke`, `contracts`, `contract`, `games`, `systems`, `ui`, `slot`, `slots`, `slot_acceptance`, `blackjack`, `roulette`, `baccarat`, `video_poker`, `bar_dice`, `pull_tabs`, `scratch_tickets`, `audit`, `all`, `full`)
  - `tools\foundation_visual_qa.ps1`: PASS
  - `tools\foundation_performance_probe.ps1 -RequireGodot`: PASS
  - `tools\foundation_determinism_probe.ps1`: PASS (`793128878`)
  - `tools\foundation_stuck_state_sweep.ps1 -SeedCount 200 -RequireGodot`: PASS
  - `tools\foundation_mouse_batch_playtest.ps1 -RunCount 4 -SeedPrefix P1-2-SWEEP -RequireGodot`: PASS after fix (4/4)
  - `tools\foundation_soak_probe.ps1 -SimMinutes 180 -ActionsPerSample 28 -SeedPrefix P1-2-SOAK -RequireGodot`: PASS after fix
