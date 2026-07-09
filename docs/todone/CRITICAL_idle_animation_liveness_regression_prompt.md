## Execution Record

Completion date: 2026-07-08

Implementing commits:

- `dcc814e` - Claim idle animation liveness regression.
- Final archive/evidence commit: this file is archived with the root fix,
  release-gated liveness check, performance-probe semantic update, and queue
  cleanup.

Root cause:

- The regression was reintroduced by the performance-oriented redraw gating
  around `066e479` and then preserved by later performance evidence. The game
  modules for Blackjack, Roulette, Baccarat, Bar Dice, and Pull Tabs were
  rendering time-based motion via `surface_flicker()` and timer-derived draw
  helpers, but their surface snapshots still declared
  `surface_animates_idle=false` and no ambient overlay. `GameSurfaceCanvas`
  therefore treated them as static and did not schedule animation-cadence
  redraws while the mouse was idle.
- Mouse movement over selectable regions masked the bug because hover changes
  call the normal dirty/redraw path, so the same frozen time-based renderers
  appeared to move only while the pointer crossed hit regions.
- The recurrence pattern came from asymmetric gates: performance probes
  rewarded `0.000ms` idle draw samples, and old foundation assertions
  explicitly required table surfaces not to redraw for idle animation. No
  release gate asserted that a surface with time-based ambient motion must keep
  redrawing without input.

Fix:

- Added a single `GameSurfaceCanvas` liveness/scheduler path:
  `surface_animation_liveness_active()`,
  `_surface_main_animation_redraw_active()`,
  `_surface_overlay_animation_redraw_active()`, and
  `_schedule_surface_animation_redraws()`. Production `_process()` and the
  headless diagnostic hook both use this same authority.
- Updated animated surface declarations for Blackjack, Roulette, Baccarat, Bar
  Dice, and Pull Tabs so they declare `surface_animates_idle=true` while still
  keeping `surface_realtime_state_refresh=false`; animation redraws no longer
  imply full snapshot rebuilds.
- Replaced the old "must not redraw" table-contract assertions with release
  liveness assertions that verify zero-input simulated time advances the
  animation sample and increments the redraw scheduler.
- Updated `tools/foundation_performance_probe.gd` so static idle surfaces may
  have zero draw samples only when no animation liveness is active. Animated
  idle surfaces must produce draw samples and are budgeted as animated redraw
  cost. Roulette's measured animated-idle renderer budget is recorded
  explicitly at 7.0ms p95; static idle budget remains 1.5ms.
- Added the `CLAUDE.md` hard rule that idle-animation liveness and idle-draw
  budgets must pass together.

Guard proof:

- Before the fix, after adding the new guard but before changing surface
  declarations/scheduling,
  `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games -TimeoutSec 300`
  failed as intended in `.tmp/test_reports/20260708_184700_smoke/summary.json`.
  The guard reported Blackjack, Roulette, Baccarat, and Bar Dice as using
  time-based idle motion without `surface_animates_idle`, without zero-input
  redraw scheduling, and without an advancing animation sample.
- After the fix, the same games suite passed in
  `.tmp/test_reports/20260708_185349_smoke/summary.json`.

Verification:

- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite games -TimeoutSec 300`
  - PASS.
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
  - PASS, report `.tmp/test_reports/20260708_185922_smoke/summary.json`.
- `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot`
  - PASS. Animated-idle samples were live for Pull Tabs, Bar Dice,
  Blackjack, Baccarat, and Roulette; static Slot and Video Poker idle surfaces
  remained at zero samples.
- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
  - PASS: `Beat the House foundation architecture validation passed.`
- Manual 30-second mouse-idle playtest was not separately driven in a visible
  desktop window in this agent run; the new release-gated headless liveness
  fixture is the permanent regression guard and covers the same zero-input
  condition.

Release note:

- The existing 0.4.0 Web/Windows packages are stale because this fix post-dates
  the packaged release candidate. Re-export and checklist hash refresh remain
  owned by the pre-publish step in `docs/todo/QUEUE.md`.

# Agent Prompt - CRITICAL: Table Idle Animations Frozen Again — Fix It AND Make Recurrence Impossible

Priority: **CRITICAL — top of queue. Playtest blocker for the 0.4 release.**

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Owner playtest of the 0.4 candidate found: **in
table games, when the mouse is not moving over selectable objects, the scene
freezes — ambient animations (dealer, patrons, wheel, timers) do not play.**
Moving the mouse over hit regions makes things move again.

## This is a REPEAT regression — the fourth documented occurrence

- `8420529` "Restore idle room animation redraws" (0.3.1, SA.1 fallout)
- `901549d` "Restore 60 FPS animation cadence"
- Post-0.3.2 hotfix chain: `e43a148`, `17c4be6`, `67b99c9`, `22deecb`,
  `dc09d69`; then the root fix `eef32ff` (ambient-overlay consolidation,
  docs/todone/playtest_root_fix_agent_prompt.md)
- Now again, after `066e479` "Recover table surface idle performance"
  (v0.4 baseline task) and/or the performance-pass budget adoption
  (docs/todone/v04_player_performance_pass_prompt.md era commits).

## Why it keeps happening (verify, then confirm or correct this analysis)

The repository enforces idle-draw budgets that celebrate `0.000ms` idle
draws (see the 0.3.2 checklist: "0.000 means the dirty/animation gates
avoided an idle redraw"). **No gate anywhere asserts that a surface with
active ambient animation KEEPS redrawing without input.** So every
performance pass re-tightens dirty-gating toward zero and silently drops
animation channels from the continuous-redraw set — and manual testing
misses it because mouse movement over hit regions marks the canvas dirty
(hover state), forcing redraws that mask the freeze. One side of the
perf-vs-liveness tension is release-gated; the other side is unenforced.
That asymmetry is the root cause of the recurrence pattern, and closing it
is half this task.

## Part 1 — Root-cause THIS instance

1. `git log -p` the redraw scheduling since `eef32ff` (last known-good
   root fix): `scripts/ui/game_surface_canvas.gd` `_process`,
   `_needs_continuous_redraw` / `_surface_animation_redraw_due` / the
   animation-channel and ambient predicates, plus whatever `066e479` and
   the performance-pass commits changed there and in per-game modules.
2. Identify the exact change that removed/re-gated ambient scheduling and
   the exact reason mouse-hover forces redraws. Write both into the
   execution record — the owner explicitly wants the "why".

## Part 2 — Fix at the root, not another band-aid

1. **One liveness authority:** a single shared predicate decides "this
   surface has active animation channels → schedule redraws at the
   animation cadence." Every game surface uses it; hover/dirty marking
   must be COMPLETELY irrelevant to whether ambient animation advances.
   If the predicate already exists but callers drifted (the historical
   failure mode), consolidate the callers; do not add a parallel check.
2. Verify all seven game surfaces + the meta home rooms: any surface that
   draws time-based motion (dealer/patron bob, wheel, reels, timers,
   urgency bars) animates with zero input, and truly static surfaces may
   rest ONLY by declaring no active channels.
3. Efficiency still matters: animation-cadence redraws must stay within
   the recorded per-surface active budgets (the blackjack ambient waiver
   pattern in the 0.3.2 checklist is the precedent). No per-frame
   allocations, zero-copy rules hold.

## Part 3 — Make recurrence impossible (the owner's explicit demand)

1. **New release-gated liveness check** (foundation check, cheap enough
   for the default/smoke gate so EVERY future change hits it): for each
   game surface (and meta rooms with animation), open the surface, feed
   ZERO input, advance simulated time, and assert (a) the canvas
   scheduled redraws at the animation cadence, and (b) successive frame
   outputs actually differ (hash the draw output or sample animated
   element positions — reuse the visual-QA/perf-probe plumbing rather
   than inventing new capture). A surface passing the idle-draw budget by
   never redrawing while it has active animation channels is a FAILURE.
2. **Re-specify the perf budgets so the two gates cannot be traded off:**
   in `tools/foundation_performance_probe.gd`, "idle draw 0.000 via
   gating" is legal ONLY for surfaces reporting no active animation
   channels; animated surfaces are budgeted on animated-redraw cost
   instead. Document this in the probe near the budget table.
3. **CLAUDE.md hard rule:** add one line under Hard rules — idle-animation
   liveness is release-gated; never optimize idle redraws by suppressing
   animation scheduling; the liveness check and the idle-draw budgets
   must both pass, together.
4. The check must FAIL on the current broken tree before your fix and
   pass after — prove the guard actually guards (state both results in
   the execution record).

## Verification

1. Manual: sit at blackjack, roulette, baccarat, and bar dice without
   touching the mouse for 30+ seconds — dealer/patrons/wheel/timers all
   animate continuously.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
   and `-FoundationSuite games -TimeoutSec 300` (with the new liveness
   check wired in).
4. `tools\foundation_performance_probe.ps1 -RequireGodot` — budgets hold
   WITH animations live under the re-specified semantics.
5. Note in the execution record that the built 0.4.0 packages are now
   STALE (this fix post-dates them); the repackage/hash refresh happens in
   the pre-publish step per QUEUE.md — do not re-export here.
6. Archive to docs/todone/ with the execution record (root cause, guard
   proof, budget deltas); update QUEUE.md. Commit locally; do NOT push.

## Hard constraints

1. Do not weaken the idle-draw budgets to make room — re-specify semantics
   as described, with the probe's numbers still enforced.
2. No band-aids (no "redraw every frame always", no hover-simulation
   hacks). Single-ownership liveness predicate or consolidation thereof.
3. Match house style: tabs, typed GDScript, sparse constraint comments.
