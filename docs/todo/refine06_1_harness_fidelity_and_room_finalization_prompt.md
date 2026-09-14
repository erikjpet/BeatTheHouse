Status: TODO — single worker agent; first refinement-phase execution row
Board rows: `qa06_1` and `fix06_27` in `docs/todo/README_0_6_board.md`
Opened: 2026-09-07 by owner decision
Runs against: `main` at `152db3c7` or later

# Agent Prompt — refine06_1: Harness Fidelity and Seed-Dependent Room Finalization

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are working in `D:\Projects\Beat-The-House`. This prompt is complete on its
own. Do not wait on any other document, queue, or ceremony.

## 0. Scope and priority

You are executing **two related rows in one pass**, because they share a root
cause and a fix surface:

- **Part A — `qa06_1`:** harnesses reimplement the production host's sequence
  instead of driving it, which has produced five false "production is broken"
  reports.
- **Part B — `fix06_27`:** room finalization fails on a minority of seeds,
  producing dead rooms — unpopulated object panels plus refused travel.

They belong together because **Part B's headline evidence was produced by a
Part A defect**: the `playtest06_1` handoff reports 55/55 rooms finalizing, which
was true only for the single seed family its harness used.

**The owner is playtesting the 0.6 build while you work.** Neither row blocks
that. Do not produce a new owner build, and do not perform release activity.

## 1. Background you need — the fail-closed guard

`RunState.scenario_preflight_environment_change()` (`scripts/core/run_state.gd:1578`
and `:1605`) refuses departure from a room with

> `Dynamic room sequence semantic records are not finalized for departure.`

unless `scenario_semantic_ready` is true. Only
`RunState.scenario_finalize_installed_environment()` sets it.

In production, `EnvironmentInteractionController.interactable_object_view_list()`
(`scripts/ui/environment_interaction_controller.gd:108`) finalizes while building
the room's object list. **If finalization fails, the controller returns the
degraded `trusted_base_result` fallback and the flag stays false.** The player
then gets a room whose objects have dead panels *and* cannot travel out. That was
the owner's original reported bug, and it is still reachable — see Part B.

## 2. Part A — qa06_1: harness/production fidelity

### The five incidents

| # | Harness | False symptom | Actual cause | Status |
| --- | --- | --- | --- | --- |
| 1 | `scripts/tests/foundation/env06_8_environment_readability_contract.gd` | 220 failures across ~every scenario | `_seeded_description_observer` travelled without finalizing, then called `apply_reentry({})` on an empty state | Fixed `4ed1d1d6` |
| 2 | `scripts/tests/foundation/world_sequence_delivery_proof_contract.gd` | "P1 travel/revisit return remained at back_alley" | `_travel_away_and_revisit` never finalized the *away* room | Fixed `4ed1d1d6` |
| 3 | `tools/wave_b_composition_probe.gd` (rumor venue, rumor target) | Composition FAIL, misattributed to `env06_8` as a "Jazz Club finalization" defect | Two arrival sites never finalized | Fixed `4ed1d1d6` |
| 4 | `tools/wave_b_composition_probe.gd` (Punchline L1) | Four failures recorded in the `integ06_1` report **and the board** as pre-existing Punchline/Crew production defects | L1 club never finalized before the L2 layer transition; the other three were cascades | Fixed on `main` |
| 5 | `tools/foundation_visual_qa.gd` | "Double-clicking Leave did not open the world map overlay" + 20 cascading failures | `_try_travel_object_flow()` reacquires with `_first_clickable_canvas_object_type_enabled(canvas, "travel", true)`, returning `travel:motel_room` ("Room Door") by render order instead of `travel:leave` | **Not yet fixed** |

Incident 4 nearly caused the flagship Punchline venue to be declared broken. One
finalization call cleared all four failures and revealed a fully working L3 back
room with `crew_planning_table`, `crew_job_board`, `crew_practice_rig`,
`numbers_desk`, `crew_mags_bench`, `crew_contact_rook`, `recruitment_rook_leads`
and Crew Draw Poker.

### Two failure modes

- **Mode A — skipping a mandatory host step.** Incidents 1–4. A harness that
  travels and then reads state or departs without finalizing is testing a state
  no player ever sees.
- **Mode B — selecting targets by broad type or render order rather than exact
  semantic identity.** Incident 5. "The first enabled object of type `travel`" is
  not what a player deliberately clicks, and it is nondeterministic with respect
  to authoring and render order.

Measured exposure on `main` `152db3c7`: **36 harnesses travel between rooms; 25
never call `scenario_finalize_installed_environment`.** Not all 25 are defective
— a harness that arrives once and never departs will not trip the guard — but
each is a candidate and none is protected against becoming one. There is no
shared test-support module, which is why every harness open-codes its own
approximation of the host.

The 25: `back_alley_fence_night_install_contract.gd`, `check_coin_pusher.gd`,
`check_core_content.gd`, `check_delivery_runs.gd`, `check_items_events_world.gd`,
`check_lenders_release_saves.gd`, `check_slots_surfaces.gd`,
`content_depth_contract.gd`, `crew_heist_contract.gd`,
`crew_ignored_golden_probe.gd`, `env06_7_production_authority_contract.gd`,
`numbers_contract.gd`, `punchline_layer_contract.gd`,
`scenario_sequence_contract.gd`, `tutorial_corner_shop_order_check.gd`,
`compile_run_menu_and_game_flows.gd`, `coin_pusher_copy_visual_probe.gd`,
`content06_manual_smoke.gd`, `crew_poker_visual_capture_wrapper_check.ps1`,
`crew_poker_visual_seed_audit.gd`, `cross_economy_audit.gd`,
`environment_generation_audit.gd`, `foundation_determinism_probe.gd`,
`perf06_deferred_validation_contract.gd`, `playtest06_2_seed_catalog_probe.gd`.

Note `punchline_layer_contract.gd` — a Punchline contract that travels and never
finalizes, the exact class that produced incident 4.

### Part A work

1. **Fix incident 5** per `docs/todo/playtest06_current_source_bug_investigation_2026-09-07.md`:
   reacquire `travel:leave` by exact id; verify it is enabled, visible and
   hittable before activating; include the selected object id/label and
   `_serialized_diff_summary()` in the failure message; add a regression case for
   a parent venue exposing both `travel:motel_room` and `travel:leave`, asserting
   the second recorded input targets `travel:leave`, the map becomes visible, and
   serialized run state stays byte-identical until route confirmation.
2. **Add a shared test-support module** preloadable from both `scripts/tests/**`
   and `tools/**`, providing at minimum:
   - an *arrive* helper that travels and then finalizes exactly as the production
     host does, failing loudly with the finalization errors if it cannot;
   - an *activate exact object* helper that resolves by semantic id and refuses
     to fall back to type or render order.
3. **Audit all 36 travelling harnesses.** For each of the 25, determine whether
   it departs, reads sequence state, or asserts on room contents after arriving.
   Convert every one that does onto the shared helpers. Record which are left
   unconverted and why.
4. **Make Mode A self-diagnosing.** A departure refused for missing finalization
   must surface a message naming the likely cause — the arrived room was never
   finalized. This is a diagnostic improvement; **the guard itself stays
   fail-closed.**
5. **Correct the historical record.** `docs/plans/integ06_1_composition_migration_soak_report.md`
   and `docs/todo/README_0_6_board.md` still attribute incidents 3 and 4 to
   Punchline/Crew production defects. Fix both.

**Part A changes no production behavior.** If the audit uncovers a real
production defect, file it as its own `fix06_*` row instead of fixing it here.

## 3. Part B — fix06_27: seed-dependent room finalization

### What is wrong

The `playtest06_1` handoff records 55/55 rooms finalizing. That is real but
**seed-specific**. Independent verification on `main` `152db3c7` swept five seed
families across all 55 sequence scenarios — 275 room instantiations:

| Seed family | Result |
| --- | --- |
| `SEEDSWEEP-A` | 55/55 |
| `SEEDSWEEP-C` | 55/55 |
| `SEEDSWEEP-D` | 55/55 |
| `PM-VERIFY` | 53/55 |
| `SEEDSWEEP-B` | 54/55 |

About 1% of instantiations fail, and each failure is a dead room.

Reproduce with seed `<prefix>-<scenario_id>`: pin the archetype's scenario pool
to the single target scenario, `start_new`, `next_environment`,
`travel_environment_result` to its node, then
`scenario_finalize_installed_environment` with
`{"viewport_size": {"x": 1280, "y": 720}}`.

### The three observed failures

**A. `corner_store_lotto_fever` (prefix `PM-VERIFY`)**

> `Scenario interaction scenario::queue_rail label overlaps unrelated room control event::event:town_rumor_staff in normal layout.` (and in expanded small-screen)

The collision is between an authored scenario object and a **randomly placed room
event**. Scenario objects are authored against a fixed board, but co-placed
events vary by seed, so static authoring cannot guarantee separation. This class
needs a runtime guarantee.

**B. `corner_store_inventory_night` (prefix `PM-VERIFY`)**

> `Scenario interactions scenario::corner_store_inventory_night_exit and scenario::count_cage have ambiguous expanded small-screen hit authority.`

Two authored scenario interactions colliding with each other, small-screen only.
Static, fixable by authoring.

**C. `kitty_cat_lounge_buyout` (prefix `SEEDSWEEP-B`)**

> `Scenario obstacle scenario::kitty_cat_lounge_buyout_buyout_ropes blocks the mandatory player access lane in normal or expanded small-screen layout.`

**Same defect class as the `motel_conventioneers` luggage cart fixed in
`env06_8`** (`b6db9576`), which moved one object out of
`WALK_LANE := Rect2(16.0, 378.0, 868.0, 36.0)`
(`scripts/core/scenario_layout_resolver.gd:564`). That was a point fix; at least
one more room has the same problem.

### Part B work

1. **Sweep, do not spot-fix.** For every object whose `role` is
   `obstacle`/`barrier`/`blockade`, across all 55 scenarios, all phases and all
   reachable states, assert it cannot intersect `WALK_LANE` in normal or expanded
   small-screen layout. Fix every violation, not only case C.
2. **Fix case B** by authoring, keeping both interactions selectable and
   unambiguous at small-screen scale.
3. **Decide and implement the durable answer to case A.** Options, in the order
   the PM considers defensible:
   - give room-event placement a collision-avoidance pass against already-placed
     scenario object label rects, so a seeded event never lands on an authored
     label;
   - or reserve authored label bands that event placement may not occupy;
   - or let finalization degrade gracefully for a *label* collision — keeping the
     room live and readable — while still failing closed for genuine access and
     hit-authority defects.
   The third is smallest but weakens a guarantee, so it requires an explicit
   recorded decision. **Do not simply relax the validator to make the failure
   disappear.**
4. **Add a permanent multi-seed regression gate** sweeping at least eight seed
   families across all 55 scenarios, requiring zero failures. A single-seed 55/55
   is not evidence and must never again be reported as one.

## 4. Order of work

Part A item 2 (the shared helpers) first — Part B's new multi-seed gate is itself
a harness and must be built on them, or it will reproduce the very defect class
this row exists to end. Then Part A 1/3/4/5, then Part B.

## 5. Acceptance

**Part A**

- Incident 5 fixed with its regression case green.
- Shared arrive/activate helpers exist and are used by every travelling harness
  that needs them.
- The 25-harness audit is complete and recorded, with a justification for each
  harness left unconverted.
- A departure refused for missing finalization names the cause in its message.
- The two historical documents no longer attribute harness defects to production.
- No production behavior changed.

**Part B**

- Zero finalization failures across at least eight seed families × 55 scenarios,
  in normal and expanded small-screen layouts.
- Each of the three named failures has a recorded root cause and fix.
- Case A has an explicit recorded design decision, not a silently relaxed rule.
- The multi-seed gate is checked in and green on the exact head.
- No scenario object deleted to make a collision go away; object counts do not
  regress.

**Both**

- `tools/validate_project.ps1` green on the exact head.
- No change to money, RNG, RTP, payouts, odds, schema or migration.

## 6. Hard limits

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** Making a harness perform a step the production host performs is
  fidelity, not weakening; deleting or relaxing an assertion is weakening. A
  budget crossing 16.67 ms needs owner sign-off.
- **Never refresh a golden** without proving the content legitimately changed.
- **No release activity.** No version bump, tag, packaging, publish, Web export,
  or new owner build. The owner is playing the existing build.
- **Delete nothing** — no branch, worktree, or stash. No `gc`, `reset --hard`,
  `clean`.
- **Never stage owner property**: `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`.
- **Leave no diagnostics in the tree.**
- Commit to a branch at least every 30 minutes, labeled if unreviewed.
- Keep `main` green after every merge and keep `origin/main` in sync.

## 7. Standards every row inherits

- **Idle draw cost of 0.000 is a failure, not a pass.** Four recorded regressions.
- **No per-frame deep copies.** The slot bonus watchdog once cost 32.6 ms/frame.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Exactly once.** Every consequence fires once across save, reload, travel,
  revisit, abort and expiry.
- **Hidden state is absolute.** A leak is an automatic P0.
- **The crew-ignoring run is a true no-op.**
- **Any harness that travels between rooms must finalize on arrival** exactly as
  the production host does. Five recorded incidents — that is what Part A exists
  to make structurally impossible.

## 8. Parked — do not start

`env06_9` (visual consequence and object identity) is parked pending the owner's
acceptance bar. `perf06_1`, the `balance06_1` follow-on, the `integ06_1` full
composition matrix and terminal soak, `voice06_1`, `triage06_1`, `balance06_2`,
`cleanup06_1` and `release06_1` remain deferred until the owner's playtest notes
arrive.

## 9. Reporting

Report at each part's completion. Lead with what changed, what was audited, the
multi-seed sweep result, anything parked with its exact question, and
`main`/`origin` sync state. If the audit finds a real production defect, name it
and file it rather than absorbing it.
