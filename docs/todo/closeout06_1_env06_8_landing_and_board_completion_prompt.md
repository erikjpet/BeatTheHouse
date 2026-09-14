Status: TODO — single worker agent; lands `env06_8` and drives the 0.6 board to the owner playtest
Board rows: `env06_8`, `integ06_1`, `perf06_1`, `playtest06_2`, `playtest06_1` in `docs/todo/README_0_6_board.md`
Supersedes: `closeout06_0_remaining_work_prompt.md` (its ordering is still correct; this prompt replaces its starting state)

# Agent Prompt — closeout06_1: Land env06_8 and Finish the 0.6 Board

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are finishing 0.6 in `D:\Projects\Beat-The-House`. This prompt is complete on
its own. Read `docs/todo/README_0_6_board.md` for row state and
`docs/plans/0.6_todo_state_audit_2026-08-31.md` for the landing history, but do
not wait on any other document, queue, or ceremony.

## 1. Exact state you are inheriting (verified 2026-09-05)

- `main` and `origin/main` are both at `380721c2` ("test(integ): seal terminal soak coverage").
- The working tree is on branch `codex/env06_8-clean` at `3621a696`
  ("fix(env): close env06_8 review findings"), which is **9 commits ahead of
  `main` and 0 behind**.
- There are **five uncommitted tracked modifications** in that working tree. They
  are described in section 2 and they are not yet committed to any branch. Do not
  discard them.
- Two untracked prompt files sit in `docs/todo/` (`closeout06_0_...` and
  `fix06_25_...`). `fix06_25` is superseded by `env06_8`; leave both alone.
- A local Windows build exists at `builds/windows/BeatTheHouse.exe`, exported
  2026-09-05 from `3621a696` plus the uncommitted changes. `builds/` is
  gitignored. It boots. It is a bug-hunting build, not a release candidate.
- `project.godot` still reports `config/version="0.5.1"`. That is correct. Do not
  change it.

## 2. The five uncommitted changes — review them, then commit them

All five are test/tool harness changes. **No product/runtime code was modified.**
Verify each against the reasoning below before you commit; if you disagree with
one, say so in your report rather than silently reverting it.

1. `tools/env06_8_unlabeled_contact_sheet_probe.gd`
   Two single-line function bodies (`func …() -> void: pass`) were expanded onto
   their own lines. **Why:** `tools/function_census.ps1:160` builds each function
   body as a line slice; a single-line body yields an empty slice, which
   PowerShell 5.1 binds as `$null` to its `[string[]]` parameter, so
   `[string]::Join` threw `ArgumentNullException`. That crashed
   `tools/validate_project.ps1`, which is the base gate every closeout row
   requires. Confirmed: census exits 0 on `main`, exited 1 on this branch, and
   now exits 0 here.

2. `scripts/tests/foundation/env06_8_environment_readability_contract.gd`
   `_seeded_description_observer` now calls
   `run_state.scenario_finalize_installed_environment(library, layout_context)`
   after travel and before reading the sequence definition/state. **Why:** see
   section 3. The same idiom already exists in this file at the
   `_check_partial_scenario_save_restore` path.

3. `scripts/tests/foundation/env06_8_environment_readability_check.gd`
   The PASS banner no longer prints `scenarios=55 objects=1108 actions=673`.
   **Why:** those are the *pre-rework* baseline figures. The current catalog is
   1,437 objects and 729 actions. The `env06_8` review prompt instructs the
   reviewer to re-derive the baseline and not trust the implementer's table — a
   PASS banner asserting the old numbers actively works against that.

4. `scripts/tests/foundation/world_sequence_delivery_proof_contract.gd`
   `_travel_away_and_revisit` now finalizes the *away* room before the return
   leg. **Why:** section 3. This contract went from FAIL to PASS.

5. `tools/wave_b_composition_probe.gd`
   Two arrival sites (rumor venue, heard scenario node) now finalize before the
   next travel. **Why:** section 3. Other arrival sites in this same file already
   did this; these two were missed.

None of these weakens an assertion. Each makes a harness perform the step the
production host performs, and #5 adds two new `_require` assertions.

## 3. The root cause you must understand before touching anything

`RunState.scenario_preflight_environment_change()`
(`scripts/core/run_state.gd:1578` and `:1605`) is **fail-closed**: departure from
a room is refused with

> `Dynamic room sequence semantic records are not finalized for departure.`

unless `scenario_semantic_ready` is true on `current_environment`. That flag is
set only by `RunState.scenario_finalize_installed_environment()`.

In production the flag gets set because
`EnvironmentInteractionController.interactable_object_view_list()`
(`scripts/ui/environment_interaction_controller.gd:108`) finalizes while building
the room's object list. **If that finalization fails, the controller returns the
degraded `trusted_base_result` fallback records and the flag stays false.** The
player then sees a room whose objects have dead panels *and* cannot travel out.

That is exactly the owner's reported bug: "bugs with selecting things and travel
that don't allow actions to go through."

Three separate test harnesses had the same defect — they travelled without
finalizing, so they were testing an empty sequence state. That produced 220
false failures in the `env06_8` contract, a false FAIL in the delivery proof, and
a false Jazz Club failure in the composition probe that was wrongly attributed to
`env06_8` in `docs/plans/integ06_1_composition_migration_soak_report.md`. **Correct
that attribution when you close `integ06_1`.**

Measured finalization health across all 55 sequence scenarios:

| Tree | Rooms finalizing OK | Dead rooms |
| --- | --- | --- |
| `main` `380721c2` | 47 / 55 | **8** |
| `codex/env06_8-clean` `3621a696` | 54 / 55 | **1** |

`env06_8` fixes seven of the eight. Preserve that result.

## 4. The one remaining dead room — fix it inside `env06_8`

`motel_conventioneers` fails finalization in every layout context (empty,
1280x720, and zero viewport) with:

> `Scenario obstacle scenario::motel_conventioneers_luggage_cart blocks the mandatory player access lane in normal or expanded small-screen layout.`

Facts:

- Rule: `scripts/core/scenario_layout_resolver.gd:564`. Any object whose `role` is
  `obstacle`/`barrier`/`blockade` may not intersect
  `WALK_LANE := Rect2(16.0, 378.0, 868.0, 36.0)` in normal **or** expanded
  small-screen layout.
- Object: `data/environments/scenario_sequences/env06_7_roadside_shelter.json`,
  `scenarios[0].sequence.phase_graph.phases[0].scene_ops[0]`,
  `stable_object_id = motel_conventioneers_luggage_cart`, `role = "obstacle"`,
  `zone_id = "foreground"`, `bounds = {w: 48.0, h: 44.0}`.
- The later phase already relocates it: `phases[2].scene_ops[0]` moves it to
  `zone_id = "background"` with `anchor_id = "package_b_motel_top_mid"`, and its
  authored variant text says the cart "has been rolled between the two luggage
  piles, opening a direct path."
- Zone ids in use across the catalog: `background`, `right`, `left`, `center`,
  `foreground`, `exit_lane`, `service_lane`. `foreground` is the zone that
  overlaps the walk lane.

The authored arrival description says the cart "blocks the lobby's front lane",
so the narrative intent is genuinely obstructive. **Keep `role: obstacle`** and
relocate it out of the mandatory entry lane rather than deleting it, downgrading
its role, or weakening the validator. Then confirm
`_room_path_reachable()` still passes — the room must remain enterable.

Acceptance for this fix: the health check in section 6 reports **55/55**.

## 5. Branch and worktree inventory — already audited, do not re-derive

40 worktrees exist. Classified by ahead/behind and by whether each unique blob
ever existed in `main`'s history:

**Only four branches carry unlanded work:**

| Branch | Ahead | Behind | Content |
| --- | --- | --- | --- |
| `codex/env06_8-clean` | 9 | 0 | The `env06_8` work; your working tree |
| `codex/balance06-final-run` | 30 | 12 | Balance shard-hardening tooling |
| `codex/playtest06-final-custody` | 3 | 0 | Playtest custody hardening |
| `codex/integ06-final-run` | 1 | 12 | `18e8dcc7`, the provisional-gates report |

**Nine worktrees are 0 commits ahead** (pure inspection checkouts, nothing to
recover): `v051-fixtures`, `perf06-platform`, `perf06-aggregate-candidate`,
`main-closeout06-land`, `integ06-1-golden-base`, `integ06-1-fixtures`,
`closeout06-crosscut-compose`, `world-baseline`, `env06_8-presentation`.

**All remaining worktrees are 100–235 commits behind `main`** and their content
landed and was superseded. This was verified by blob history, not by commit
subject — e.g. `world-closeout` has 0/10 subjects on `main` but every product
file traces to landed-then-superseded; only the board file differs, which is
expected because it is edited constantly.

**Merge order is proven conflict-free** by `git merge-tree` dry run, chained in
this exact order onto `main`:

```
codex/env06_8-clean  ->  codex/integ06-final-run  ->  codex/playtest06-final-custody  ->  codex/balance06-final-run
```

Zero conflicts at every step. Use that order.

**Six files exist nowhere on `main` or on the four live branches.** They live
only on stale branches and are safe there — retiring a *worktree* never touches
its *branch*. Do not import any of them into `scripts/tests/foundation/` without
first reconciling their API; four of them call contract functions that no longer
exist and would break the 177-file load gate:

- on `codex/closeout06-final`: `env06_8_environment_geometry_check.gd`,
  `env06_8_hidden_boundary_check.gd`,
  `tools/env06_8_all_scenario_contact_sheet_probe.gd`,
  `tools/env06_8_capture_contact_sheets.ps1`
- on the `codex/game-cl-*` branches: `tools/blackjack_payout_prefix_probe.gd`,
  `tools/blackjack_authority_fingerprint_equivalence.gd` (their rows are closed)

**Open decision for the owner, do not guess:** `codex/closeout06-final` holds a
*different* `env06_8` contract (815 lines) from the clean branch's (1,057 lines) —
not an older revision, a different one. The clean rebuild dropped
`check_geometry`, `_check_production_hidden_state_boundary`,
`_check_exactly_once_consequence`, and `_check_reachable_presentation_and_hidden_state`.
Exactly-once and reachability are named items on the acceptance bar in section 8.
Record this as an owner question, take the default of **not** porting them, and
keep moving.

## 6. Gate results already recorded — re-run on your exact head, do not trust these

Run every one of these again on whatever head you produce. They are listed so you
know what was true at `3621a696` + the uncommitted changes, not as evidence you
may cite.

Green:

- `tools/validate_project.ps1` → PASS ("Beat the House foundation architecture validation passed.")
- `tools/function_census.ps1 -Check -Quiet` → exit 0
- `scripts/tests/foundation/env06_8_environment_readability_check.gd` → exit 0, **0 failures** (was 220)
- `scripts/tests/foundation/world_sequence_delivery_proof_contract.gd` → PASS (was FAIL)
- `env06_7_package_b_contract.gd`, `_c_`, `_d_`, `_e_` → all four PASS

Never confirmed — **you must run these**:

- `scripts/tests/foundation/scenario_semantic_presentation_contract.gd`
- `scripts/tests/foundation/content_depth_contract.gd`

  (a batched run of all six contracts died at exit 4 after reporting the four
  package contracts; these two never reported.)

Known red, and **not** `env06_8`'s to fix — reproduced identically on `main` with
the same harness fixes applied:

- `tools/wave_b_composition_probe.gd` still fails five checks: Punchline L2
  layer transition, Punchline L3 made-rank path, save/load L3 restore, L3 revisit
  restore, and the crew favor lender/cadence path. These are pre-existing
  production defects owned by the Punchline/crew rows. Record them, route them,
  do not block `env06_8` on them, and do not fix them inside `env06_8`.

Useful measurement command for section 4 (write it as a throwaway probe under
`tools/`, run it, then delete it — do not leave diagnostics in the tree): for
each of the 55 sequence scenarios, pin the archetype pool to that scenario,
`start_new`, `next_environment`, `travel_environment_result` to its node, then
call `scenario_finalize_installed_environment` and count `ok && !inactive`.

## 7. Order of work

1. **Review and commit the five changes** in section 2 onto `codex/env06_8-clean`.
2. **Fix `motel_conventioneers`** (section 4). Re-run the health check; require 55/55.
3. **Re-run the full `env06_8` gate set** (section 6), including the two that
   never reported.
4. **Independent review of `env06_8`.** This must be an agent that implemented no
   part of it. The review prompt is `docs/todo/env06_8_review_prompt.md`.
   Acceptance is void the moment the head changes, so review the final head.
   **`env06_8` has already had one rejection round** ("fix(env): close env06_8
   review findings"). Under the two-rejection rule, a second rejection escalates
   to the owner instead of starting a third round.
5. **Merge to `main` in the proven order** (section 5) and push. This is the
   source freeze that everything else waits on.
6. **`integ06_1`** — run `docs/plans/integ06_1_final_execution_ledger.md` against
   the frozen candidate. Correct the Jazz Club attribution (section 3). Expect
   roughly 15 min for contracts, 1–4 h for composition plus lifecycle rows, up to
   3 h for the native/Web terminal soak.
7. **`perf06_1`** — run `docs/plans/perf06_1_final_runtime_runbook.md`. It
   requires `HEAD == origin/main`, a clean tracked tree, a quiescent host, and
   distinct `BTH_PERF_WORKER_WITNESS` / `BTH_PERF_DIRECTOR_WITNESS` values.
8. **`balance06_1` follow-on** — the binding final-tree distributions and the
   600k-drop pusher EV, which were always gated on this source freeze.
9. **`playtest06_2`**, then **`playtest06_1`**. Hand the owner an exact build and
   an honest report. That ends your program.
10. **Reconcile the board.** `README_0_6_board.md` is stale: it still describes
    `integ06_1` as "only save-inventory prestage landed at `6e3973f3`" when real
    integ/perf/playtest work has landed on `main` since. Fix every row you touch.

## 8. Acceptance bar for closing a row

On the exact current head:

- each of the prompt's requirements maps to landed code, data or tests, recorded;
- its focused suite is green on that exact head, with the command and result;
- the row's own named evidence exists — visual, reachability, platform, determinism;
- exactly-once holds for every consequence it touches;
- no hidden-state leak, and nothing trusts a caller-supplied capability;
- no change to money, RNG, RTP, payouts, odds, schema or migration.

Missing polish, absent captures the prompt never required, imperfect naming and
untested edge cases are **follow-on items, not blockers**. Record and close.

## 9. Hard limits

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** Adding a step the production host performs is not weakening; deleting
  or relaxing an assertion is. A budget crossing 16.67 ms needs owner sign-off.
- **Never refresh a golden** without proving the content legitimately changed.
- **No release activity.** No version bump, no tag, no packaging, no publish.
  `release06_1` stays parked. A local build for the owner is allowed and is
  `playtest06_1`'s deliverable.
- **Delete nothing** — no branch, worktree, or stash. No `gc`, `reset --hard`,
  `clean`. Retiring a worktree directory is a separate owner decision; the branch
  always stays.
- **Never stage owner property**: `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`, build output.
- **Leave no diagnostics in the tree.** Delete throwaway probes when done.
- Commit to a branch at least every 30 minutes, labeled if unreviewed.
- Keep `main` green after every merge and keep `origin/main` in sync.

## 10. Standards every row inherits

- **Idle draw cost of 0.000 is a failure, not a pass.** The counter-gate in
  `scripts/ui/performance_liveness_guard.gd` is mandatory wherever a surface is
  touched. Four recorded regressions.
- **No per-frame deep copies.** The slot bonus watchdog once cost 32.6 ms/frame.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Exactly once.** Every consequence fires once across save, reload, travel,
  revisit, abort and expiry.
- **Hidden state is absolute.** No Turn, traitor, grievance, rigged-draw or
  unrevealed-ticket information may leak through scene data, serialized keys,
  captures, audio or fixtures. A leak is an automatic P0.
- **The crew-ignoring run is a true no-op.**
- **Rules and math are preserved.** Depth changes presentation and interaction.

## 11. How not to stall

- **Park, never block.** If a row needs an owner decision, record the exact
  question, take the stated default, act on it, and move to the next row.
- **Defect budget: three new `fix06_*` rows** for the whole program. Past that,
  defects go on a deferred list for the post-playtest passes.
- **Two rejections on a row escalate to the owner, never a third round.**
- **Never idle.** A parked row means take the next one immediately.

## 12. Parked — do not start

`triage06_1`, `balance06_2`, `voice06_1`, `cleanup06_1`, `release06_1`, and the
seven `release06_1_*_template.md` companions. Their inputs are the strings,
numbers and direction decisions the owner's playtest is expected to change.
Tutorial `TUT-N17` needs five cold-player human sessions and cannot be done by an
agent — record it as owner-dependent.

## 13. Reporting

Report at every row closure. Lead with: rows closed of the remaining set, the row
in flight, anything parked with its exact question, and `main`/`origin` sync
state. Never report a row DONE before its evidence is recorded and its prompt is
archived to `docs/todone/`.

Stop only when `playtest06_1` has handed the owner its build. If you are about to
stop for any other reason, take the next row instead.
