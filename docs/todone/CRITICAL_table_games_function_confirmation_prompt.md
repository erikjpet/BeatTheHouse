## Execution Record

Completion date: 2026-07-09

Implementation commit: same commit as this archive record.

Root causes:
- Roulette animation handoff/freeze: the post-payout roulette surface stopped requesting full realtime snapshots once `roulette_motion_active` became false, which is correct for performance, but `_draw_roulette_wheel()` still based settled wheel drift on the frozen `surface_time_msec` value from that last snapshot. The prior liveness guard only checked redraw-count/flicker advancement, so it passed while the actual roulette wheel signature stayed identical until input forced a fresh render path.
- Bet placement: no current runtime overlap or blocked-action defect reproduced after checking the real dispatch path. The actionable defect was test coverage: foundation game contracts called `surface_action_command()` directly and `SurfaceHarness` did not exercise `surface_add_cached_exact_hits()`, so roulette cached bet regions and canvas hit dispatch could regress without failing the gate.

Fix summary:
- Added shared canvas animation demand semantics with explicit channel-handoff tracking in `scripts/ui/game_surface_canvas.gd`.
- Added `debug_surface_motion_sample()` so guards can assert visual output changes, not just redraw counters.
- Refactored roulette wheel motion through one signature helper and made settled roulette drift use the canvas live render clock, preserving zero full-snapshot idle rebuilds.
- Hardened foundation checks with real canvas dispatch assertions for roulette, baccarat, blackjack, and bar dice, plus cached-hit coverage in `SurfaceHarness`.

Guard fail -> pass proof:
- Pre-fix hardened guard: `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite roulette -TimeoutSec 300` failed. Output: `validate_project PASS`, `godot_import PASS`, `gdscript_load_check PASS`, `foundation_roulette FAIL`; failure: `Roulette post-payout handoff visual motion sample did not advance across the table surface lifecycle.`
- Post-fix same command passed. Output: `validate_project PASS 16535ms`, `godot_import PASS 12959ms`, `gdscript_load_check PASS 10512ms`, `foundation_roulette PASS 6895ms`.

Per-game function confirmation:

| Game | First-click input path | Resolve/payout path | Animation/liveness | Cheat/skill spot check | Result |
| --- | --- | --- | --- | --- | --- |
| Blackjack | Canvas dispatch guard for `blackjack_deal`; games suite contract | Existing deal/hit/stand/payout contract | Idle + deal channel contracts | Count/basic-strategy checks | PASS |
| Roulette | Canvas dispatch guard for cached `roulette_bet`; games suite contract | Spin, recent-result, payout, rebet contracts | New post-payout motion signature guard; roulette suite fail->pass proof | Read-wheel/nudge checks | PASS |
| Baccarat | Canvas dispatch guard for `baccarat_bet`; games suite contract | Deal, settlement, road/commission contracts | Idle/deal/payout contracts | Read-shoe/edge-sort checks | PASS |
| Video Poker | Existing games suite + mouse batch surface path | Draw/double/settlement contracts | Covered by games/UI/mouse batch | Hold/double flow checks | PASS |
| Bar Dice | Canvas dispatch guard for `bar_dice_roll`; games suite contract | Roll/select/settle contracts | Idle/tumble contracts | Loaded/palm/press checks | PASS |
| Pull Tabs | Existing games suite + UI buy-button single-activation guard | Buy/reveal/payout contracts | Cabinet idle liveness contract | Route/item checks | PASS |
| Slot | Existing games suite + mouse batch surface path | Spin/feature/autoplay contracts | Performance probe surface coverage | Nudge/skill-feature checks | PASS |

Verification gates run:
- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` -> PASS (`Beat the House foundation architecture validation passed.`).
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite roulette -TimeoutSec 300` -> PASS after fix.
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games -TimeoutSec 600` -> PASS (`foundation_games PASS 116606ms`).
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` -> PASS (`ui_scene_compile PASS 52071ms`).
- `powershell -ExecutionPolicy Bypass -File tools\foundation_mouse_batch_playtest.ps1 -RunCount 20 -RequireGodot` -> PASS, playable-loop 20/20, UI regression 20/20, true failures 0.
- `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot` -> PASS, roulette covered, roulette idle draw p95 5.551ms, no failures.

Deviations and release note:
- Manual play of every table game was covered by automated function confirmation and mouse batch rather than interactive owner-style hand play in this agent run.
- 0.4.0 packages remain stale until the queued repackage step.

# Agent Prompt - CRITICAL: Full Table-Game Function Confirmation + Animation-Gap Liveness Fix

Priority: **CRITICAL — playtest blocker for the 0.4 release.**

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Owner playtest AFTER the idle-animation
liveness fix (docs/todone/CRITICAL_idle_animation_liveness_regression_prompt.md,
fix commit "Fix idle animation liveness regression") reports:

1. **Bet placement is failing** in table games (bets not placing on
   interaction).
2. **The roulette wheel stops spinning between bet-completion animations**,
   and clicking makes it **jump to where it should be**.

The owner's read is correct: symptom 2 is the SAME regression class the
liveness fix was supposed to resolve — the click-jump proves the simulation
advances while rendering does not, i.e. redraw scheduling drops out in a
state window and input-driven dirty-marking masks it. The previous fix
covered pure idle-from-open; it evidently does NOT cover **animation
handoff windows** (the gap after a bet/payout animation channel ends and
before idle/ambient scheduling resumes). This is the fifth documented
appearance of this class. The guard built last time passes while the game
is still visibly broken — so the guard is insufficient and must be
hardened, not just the code.

## Part 1 — Root-cause both symptoms

1. **Wheel freeze between animations:** trace the scheduling state machine
   across a full roulette action lifecycle (bet placed → spin channel →
   payout channel → return to idle) in game_surface_canvas.gd and
   roulette.gd. Find the window where no animation channel is registered
   but the wheel's continuous motion (and any other time-based motion)
   still needs frames. Check whether the liveness fix's predicate consults
   only *channel* state and misses *ambient/continuous* motion during
   channel transitions. Explain the exact gap in the execution record and
   why the new liveness check did not catch it.
2. **Bet placement failures:** reproduce first — which games, which
   interactions. Suspect list to check in order: input/hit-region changes
   from the liveness fix (if it touched redraw/input coupling), the meta
   top-bar work overlapping bet hit regions, and the blocked-action
   gating (closing-time / surface-lock predicates) misfiring outside their
   intended windows. Name the actual cause; do not fix blind.

## Part 2 — Fix at the root

1. The liveness predicate must cover the ENTIRE surface lifecycle: a
   surface schedules redraws whenever ANY of (a) an animation channel is
   active, (b) ambient/continuous motion is declared (the roulette wheel's
   idle rotation is such motion — always, on that surface), or (c) a
   channel handoff is in progress. No state window may exist where
   simulated visual state advances without scheduled redraws. One
   predicate, all callers — same single-ownership rule as before.
2. Fix bet placement per the actual root cause; bets place reliably on
   first interaction in every table game.

## Part 3 — Full table-game function confirmation (the owner's ask)

For EVERY game (blackjack, roulette, baccarat, video poker, bar dice,
pull tabs, slot), through the real input path (mouse-batch harness
scenarios or the visual-QA driver — extend, don't hand-roll):

1. Open the surface; every bet/wager type the game offers places
   correctly on first click (chip selection, stake changes, outside/inside
   bets for roulette, hold selections for video poker, etc.).
2. Resolve rounds and verify payouts apply to the bankroll correctly.
3. **Animation continuity across the whole lifecycle:** sample frame
   output through place → resolve → payout → idle and assert motion never
   stalls — specifically including the between-animations windows and
   30+ seconds of untouched idle after a resolve.
4. Cheat/skill actions still arm and grade (spot-check one per game).
5. Record a per-game PASS table in the execution record.

## Part 4 — Harden the guard so "passes while broken" cannot recur

1. Extend the liveness foundation check from idle-from-open to the **full
   lifecycle scenario**: scripted bet → resolve → payout → idle per table
   game, asserting scheduled redraws and differing frames in every phase
   INCLUDING channel transitions. It must FAIL on the current broken tree
   and pass after the fix — record both results.
2. Add the roulette-specific invariant: whenever the wheel is visible and
   the table is not barred, wheel angle advances between sampled frames
   without input.
3. Extend the input-fuzz/mouse coverage with a bet-placement smoke: every
   table game places one bet through real clicks in the batch harness, so
   bet regressions fail CI, not owner playtests.

## Verification

1. Manual: play every table game — bets place first-click, wheel never
   stops, nothing jumps on click.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite games -TimeoutSec 600`
   and `-FoundationSuite ui -TimeoutSec 300` (hardened checks wired in).
4. `tools\foundation_mouse_batch_playtest.ps1 -RunCount 20 -RequireGodot`
   — strict.
5. `tools\foundation_performance_probe.ps1 -RequireGodot` — budgets hold
   with continuous wheel motion under the liveness-aware semantics.
6. Note that 0.4.0 packages remain stale until the repackage step. Archive
   to docs/todone/ with the execution record (root causes, guard
   fail→pass proof, per-game PASS table); update QUEUE.md and commit per
   the queue lifecycle.

## Hard constraints

1. No band-aids: no always-redraw, no input-simulation hacks, no special-
   casing roulette outside the shared predicate.
2. Do not weaken idle-draw budgets or any existing check; the wheel's
   continuous motion is budgeted, not exempted.
3. Match house style: tabs, typed GDScript, sparse constraint comments.
