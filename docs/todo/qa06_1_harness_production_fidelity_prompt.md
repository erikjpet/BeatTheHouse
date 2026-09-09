Status: TODO — refinement-phase row; does not block owner playtesting
Priority: P1 test-infrastructure defect class — five recorded incidents, each of which reported working gameplay as broken
Board row: `qa06_1` in `docs/todo/README_0_6_board.md`
Opened: 2026-09-07 by owner decision after the fifth incident

# Refinement Row — qa06_1: Harness/Production Fidelity

## 1. The pattern

Five separate times during the 0.6 program, a **test harness defect was reported
as a production defect**. In every case the game was working and the test was
wrong. In two cases the false evidence reached official reports and the board.

| # | Harness | False symptom | Actual cause | Status |
| --- | --- | --- | --- | --- |
| 1 | `scripts/tests/foundation/env06_8_environment_readability_contract.gd` | 220 failures across ~every scenario: "scenario causal journal and pending fact capacity is invalid" | `_seeded_description_observer` travelled without finalizing, so it called `apply_reentry({})` on an empty state | Fixed `4ed1d1d6` |
| 2 | `scripts/tests/foundation/world_sequence_delivery_proof_contract.gd` | Contract FAIL: "P1 travel/revisit return remained at back_alley" | `_travel_away_and_revisit` never finalized the *away* room, so the return leg was refused | Fixed `4ed1d1d6` |
| 3 | `tools/wave_b_composition_probe.gd` (rumor venue, rumor target) | Composition matrix FAIL, misattributed to `env06_8` as a "Jazz Club scenario finalization" defect in `docs/plans/integ06_1_composition_migration_soak_report.md` | Two arrival sites never finalized | Fixed `4ed1d1d6` |
| 4 | `tools/wave_b_composition_probe.gd` (Punchline L1) | Four failures — L2 transition refused, L3 "no door that way", save/load L3, revisit L3 — recorded in the `integ06_1` report **and the board** as "pre-existing production defects owned by the Punchline/Crew rows" | The L1 club room was never finalized before the layer transition; the other three were cascades | Fixed; landed on `main` |
| 5 | `tools/foundation_visual_qa.gd` | "Opening the world map should not mutate serialized RunState"; "Double-clicking Leave did not open the world map overlay"; plus 20 cascading failures | `_try_travel_object_flow()` reacquires its target with `_first_clickable_canvas_object_type_enabled(canvas, "travel", true)`, which returns `travel:motel_room` ("Room Door") by render order instead of `travel:leave` | **Not yet fixed** — root-caused in `docs/todo/playtest06_current_source_bug_investigation_2026-09-07.md` |

**Incident 4 is the one that shows the real cost.** It very nearly caused the
flagship three-layer Punchline venue to be declared broken. Adding one
finalization call cleared all four failures and revealed a fully working L3 back
room populated with `crew_planning_table`, `crew_job_board`, `crew_practice_rig`,
`numbers_desk`, `crew_mags_bench`, `crew_contact_rook`, `recruitment_rook_leads`
and Crew Draw Poker.

## 2. Root cause

**Harnesses reimplement the host's sequence instead of driving it.** There is no
shared test-support module; each harness open-codes its own approximation of what
`foundation_main.gd` does. Two failure modes follow:

**Mode A — skipping a mandatory host step.** Incidents 1–4.
`RunState.scenario_preflight_environment_change()` (`scripts/core/run_state.gd:1578`,
`:1605`) is fail-closed: departure is refused unless `scenario_semantic_ready` is
true, which only `RunState.scenario_finalize_installed_environment()` sets. In
production, `EnvironmentInteractionController.interactable_object_view_list()`
(`scripts/ui/environment_interaction_controller.gd:108`) does this while building
the room's object list. A harness that travels and then reads or departs without
finalizing is testing a state the player never sees.

**Mode B — selecting targets by broad type or render order rather than exact
semantic identity.** Incident 5. A helper that returns "the first enabled object
of type `travel`" is not the object a player would deliberately click. Any room
exposing two objects of one type makes such a harness nondeterministic with
respect to authoring and render order.

Measured exposure on `main` at `152db3c7`: **36 harnesses travel between rooms;
25 of them never call `scenario_finalize_installed_environment`.** Not all 25 are
defective — a harness that arrives once and never departs will not trip the guard
— but every one of them is a candidate, and none of them is protected against
becoming defective later.

## 3. Required work

1. **Fix incident 5** exactly as specified in
   `docs/todo/playtest06_current_source_bug_investigation_2026-09-07.md`:
   reacquire `travel:leave` by exact id, verify it is enabled/visible/hittable
   before activating, include the selected object id/label and serialized-diff
   summary in any failure message, and add a regression case for a parent venue
   exposing both `travel:motel_room` and `travel:leave`.
2. **Add a shared test-support module** that harnesses use instead of open-coding
   the host sequence. At minimum:
   - an *arrive* helper that travels and then finalizes exactly as the production
     host does, failing loudly with the finalization errors if it cannot;
   - an *activate exact object* helper that resolves a target by semantic id and
     refuses to fall back to type or render order.
   Place it where every `scripts/tests/**` and `tools/**` harness can preload it.
3. **Audit all 36 travelling harnesses.** For each of the 25 that never finalize,
   determine whether it departs, reads sequence state, or asserts on room
   contents after arriving. Convert every one that does onto the shared helpers.
   Record the ones that genuinely do not need it and why.
4. **Make Mode A self-diagnosing.** When a departure is refused for
   `Dynamic room sequence semantic records are not finalized for departure.`,
   the failure text a harness surfaces must name the likely cause — the arrived
   room was never finalized — so the next occurrence costs minutes, not a review
   cycle. This is a diagnostic improvement, not a relaxation: the guard itself
   must stay fail-closed.
5. **Correct the historical record.** `docs/plans/integ06_1_composition_migration_soak_report.md`
   and `docs/todo/README_0_6_board.md` still describe incidents 3 and 4 as
   pre-existing Punchline/Crew production defects. They were not. Fix both.

## 4. Acceptance

- Incident 5 fixed, with its regression case green.
- Shared arrive/activate helpers exist and are used by every travelling harness
  that needs them.
- The 25-harness audit is complete and recorded, with a justification for each
  harness left unconverted.
- A departure refused for missing finalization produces a message that names the
  cause.
- The two historical documents no longer attribute harness defects to production.
- No production/runtime behavior changed by this row. It is test infrastructure
  only. If a real production defect is found during the audit, file it as its own
  `fix06_*` row rather than fixing it here.

## 5. Standards

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** Making a harness perform a step the production host performs is
  fidelity, not weakening. Deleting or relaxing an assertion is weakening.
- **Idle draw cost of 0.000 is a failure, not a pass.** Four recorded regressions.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Hidden state is absolute.** A leak is an automatic P0.
- Delete nothing; leave no diagnostics in the tree.
- No release activity: no version bump, tag, packaging, or publish.
