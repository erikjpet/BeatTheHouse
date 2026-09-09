Status: TODO — refinement-phase defect; does not block owner playtesting
Priority: P1 gameplay defect — reintroduces the original dead-room symptom on a minority of seeds
Board row: `fix06_27` in `docs/todo/README_0_6_board.md`
Found: 2026-09-07 by PM verification of the `playtest06_1` handoff claim

# Agent Prompt — fix06_27: Seed-Dependent Room Finalization Failures

Copy everything below this line into one agent.

---

## 1. What is wrong

The `playtest06_1` handoff records **55/55 rooms finalizing**. That result is real
but **seed-specific**. Independent PM verification on `main` at `152db3c7` swept
five seed families across all 55 sequence scenarios — 275 room instantiations —
and found three failures:

| Seed family | Result |
| --- | --- |
| `SEEDSWEEP-A` | 55/55 |
| `SEEDSWEEP-C` | 55/55 |
| `SEEDSWEEP-D` | 55/55 |
| `PM-VERIFY` | 53/55 |
| `SEEDSWEEP-B` | 54/55 |

Roughly 1% of room instantiations fail. **Each failure is a dead room**: because
`EnvironmentInteractionController.interactable_object_view_list()` returns the
degraded `trusted_base_result` fallback when finalization fails,
`scenario_semantic_ready` stays false, so the player gets unpopulated object
panels *and* `scenario_preflight_environment_change()` refuses to let them travel
out. This is the owner's original reported bug, reduced from 8 unconditional
rooms to a seed-dependent minority — not eliminated.

## 2. The three observed failures

Reproduce with seed `<prefix>-<scenario_id>`, pinning the archetype's scenario
pool to the single target scenario, then `start_new` → `next_environment` →
`travel_environment_result` to its node → `scenario_finalize_installed_environment`
with `{"viewport_size": {"x": 1280, "y": 720}}`.

**A. `corner_store_lotto_fever` (prefix `PM-VERIFY`)**

> `Scenario interaction scenario::queue_rail label overlaps unrelated room control event::event:town_rumor_staff in normal layout.`
> (and again in expanded small-screen layout)

The collision is between an authored scenario object and a **randomly placed room
event**. This is the important one: scenario objects are authored against a fixed
board, but co-placed events vary by seed, so no amount of static authoring
guarantees separation. This class needs a *runtime* guarantee, not a data nudge.

**B. `corner_store_inventory_night` (prefix `PM-VERIFY`)**

> `Scenario interactions scenario::corner_store_inventory_night_exit and scenario::count_cage have ambiguous expanded small-screen hit authority.`

Two authored scenario interactions collide with each other, only in expanded
small-screen. Static, and fixable by authoring.

**C. `kitty_cat_lounge_buyout` (prefix `SEEDSWEEP-B`)**

> `Scenario obstacle scenario::kitty_cat_lounge_buyout_buyout_ropes blocks the mandatory player access lane in normal or expanded small-screen layout.`

**This is the same defect class as the `motel_conventioneers` luggage cart fixed
in `env06_8`** (`b6db9576`). That fix moved one object out of
`WALK_LANE := Rect2(16.0, 378.0, 868.0, 36.0)` (`scripts/core/scenario_layout_resolver.gd:564`).
It was a point fix. At least one more room has the same problem.

## 3. Required work

1. **Sweep, do not spot-fix.** For every object whose `role` is
   `obstacle`/`barrier`/`blockade` across all 55 scenarios and all phases, assert
   it cannot intersect `WALK_LANE` in normal or expanded small-screen layout, in
   any reachable phase state. Fix every violation found, not only case C.
2. **Fix case B** by authoring, keeping both interactions selectable and
   unambiguous at small-screen scale.
3. **Decide and implement the durable answer to case A.** Options, in the order
   the PM considers them defensible:
   - give room-event placement a collision-avoidance pass against already-placed
     scenario object label rects, so a seeded event never lands on an authored
     object's label;
   - or reserve authored label bands that event placement may not occupy;
   - or make finalization degrade gracefully for a *label* collision — keeping
     the room live and readable — while still failing closed for genuine access
     and hit-authority defects.
   The third is the smallest change but weakens a guarantee, so it needs an
   explicit recorded decision rather than a quiet edit. **Do not simply relax the
   validator to make the failure disappear.**
4. **Add a permanent multi-seed regression gate.** The existing check proves one
   seed family. Replace or supplement it with a gate that sweeps at least eight
   seed families across all 55 scenarios and requires zero finalization failures.
   A single-seed 55/55 is not evidence and must not be reported as one.

## 4. Acceptance

- Zero finalization failures across at least eight seed families × 55 scenarios,
  in normal and expanded small-screen layouts.
- The three named failures each have a recorded root cause and fix.
- Case A has an explicit recorded design decision, not a silently relaxed rule.
- The multi-seed gate is checked in and green on the exact head.
- No change to money, RNG, RTP, payouts, odds, schema or migration.
- No scenario object deleted to make a collision go away — object counts do not
  regress.

## 5. Standards

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** The walk-lane and hit-authority rules exist because a player who
  cannot reach or unambiguously click an object is stuck.
- **Idle draw cost of 0.000 is a failure, not a pass.** Four recorded regressions.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Hidden state is absolute.** A leak is an automatic P0.
- **Any harness that travels between rooms must finalize on arrival** exactly as
  the production host does. Five recorded false-failure incidents in this
  program — see `docs/todo/playtest06_current_source_bug_investigation_2026-09-07.md`
  for the most recent, a wrong-target click in `tools/foundation_visual_qa.gd`.
- Delete nothing; leave no diagnostics in the tree.
- No release activity: no version bump, tag, packaging, or publish.

## 6. Related, separately tracked

- `docs/todo/playtest06_current_source_bug_investigation_2026-09-07.md` — the
  `foundation_visual_qa.gd` wrong-target defect (test infrastructure, already
  root-caused, fix specified, not yet applied).
- `docs/todo/env06_9_visual_consequence_and_object_identity_prompt.md` — parked
  visual identity work.
