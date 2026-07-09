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
