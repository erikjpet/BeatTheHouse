Status: TODO — single worker agent; owner-directed re-sequencing to a playtestable build
Board rows: `env06_8` (re-scoped), `fix06_26` (new), `integ06_1`, `playtest06_1` in `docs/todo/README_0_6_board.md`
Supersedes: `closeout06_1_env06_8_landing_and_board_completion_prompt.md`
Owner decision date: 2026-09-06

# Agent Prompt — closeout06_2: Fast-Path to a Playtestable Build

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are finishing 0.6 in `D:\Projects\Beat-The-House`. This prompt is complete on
its own. Read `docs/todo/README_0_6_board.md` for row state, but do not wait on
any other document, queue, or ceremony.

## 0. The owner's decision — read this before anything else

The owner has **re-prioritized the program**. The goal is no longer "verify
everything, then hand off." It is:

> **Get to a full playtestable build as fast as is safe, so refinement — bug
> fixing, performance, scenario tweaking — can start against the real game.**

Two consequences bind you:

1. **`env06_8` is split.** Its structural work lands now. Its visual work becomes
   a separate row, `env06_9`, which is **parked** (section 6). The second-review
   `REJECT` at `9c4196dd` is **resolved by this re-scoping**, not by exception and
   not by waiving a requirement — the findings were real but out of that row's
   reach (section 2).
2. **Verification that gates a *release* is deferred; verification that gates
   *playability* is not.** Section 5 says exactly which is which. Do not run the
   deferred work. Do not skip the required work.

## 1. Exact state you are inheriting (verified 2026-09-06)

- `main` and `origin/main` are both at `380721c2`. No source freeze has begun.
- `codex/env06_8-clean` is at `cccb5840`, pushed, containing candidate `9c4196dd`
  plus the escalation record. It is **13 commits ahead of `main`, 0 behind**.
- The candidate `9c4196dd` finalizes **55/55** scenario rooms and passes project
  validation, function census, environment readability, semantic layout, content
  depth, packages B/C/D/E, world-sequence delivery proof, and the hidden-state
  paired observer. Structural census: 55 scenarios, 376 phases, 0 unzoned
  objects, 0 handlerless actions.
- **One uncommitted tracked change** exists in the working tree:
  `tools/wave_b_composition_probe.gd`. Review and commit it — see section 3.
- `project.godot` reports `config/version="0.5.1"`. That is correct. Do not
  change it.
- Untracked prompt files in `docs/todo/` are inherited scaffolding. Leave them.

## 2. Why env06_8 is being split, so you do not relitigate it

The second review rejected `9c4196dd` on two P1 findings: 127 visual
consequence/coverage failures across 53/55 scenarios, and ten sampled contact
sheets whose objects were not identifiable without labels.

**Both findings are true, and both are unreachable from `env06_8`'s scope.** The
mechanism:

```gdscript
func _fallback_event_prop(visual_key: String, icon_key: String) -> String:
```

in `scripts/ui/pixel_scene_canvas.gd`. Object `state` is **not an input** to prop
selection. `env06_8`'s dominant consequence handler is `change_scene_object`
(360 uses), which changes an object's `state` and therefore its description
variant — but it **cannot** change the object's glyph. That is the whole
explanation for the "45 unchanged settled-room rasters." Likewise, 462 of 827
object ops carry no authored `icon_key` and fall through a keyword ladder into a
fixed vocabulary of roughly two dozen shared glyphs, which is why distinct
objects are not identifiable without labels.

`env06_8` owned scenario data plus `environment_interaction_controller.gd`. No
amount of scenario-data authoring could have cleared either finding. The row was
measured against a bar its own scope could not reach. The visual work is real and
is captured in `env06_9`; it is not abandoned.

**Do not** re-run the visual probe against `env06_8`, and do not treat its
findings as blocking this row.

## 3. The uncommitted change — review, then commit

`tools/wave_b_composition_probe.gd` gained one finalization call plus its
assertion, after the Punchline L1 arrival and before the L2 layer transition.

**Why it matters far more than its size.** Before it, the probe reported five
failures that the `integ06_1` report and the board both recorded as "pre-existing
production defects owned by the Punchline/Crew rows." That was wrong. Four of the
five were this same harness gap:

| Reported failure | Actual cause |
| --- | --- |
| Punchline L2 layer transition refused | L1 club room never finalized; preflight is fail-closed |
| L3 made-rank path "no door that way" | cascade — L2 was never entered |
| Save/load did not restore L3 | cascade |
| Revisit did not restore L3 | cascade |

With the finalization added, all four pass and the L3 back room populates with
its real content (`crew_planning_table`, `crew_job_board`, `crew_practice_rig`,
`numbers_desk`, `crew_mags_bench`, `crew_contact_rook`, `recruitment_rook_leads`,
crew draw poker). **The Punchline is not broken.** The flagship three-layer venue
works end to end.

This is the **fourth** instance of the same defect. The first three were fixed in
`env06_8_environment_readability_contract.gd`,
`world_sequence_delivery_proof_contract.gd`, and two earlier sites in this same
probe. **Whenever a harness travels between rooms, it must finalize on arrival
exactly as the production host does** — see section 4.

**Correct the record when you close `integ06_1`:** its soak report and the board
both currently misattribute these four to production. One genuine failure
remains, and it becomes `fix06_26` (section 5).

## 4. The root cause every agent on this program must know

`RunState.scenario_preflight_environment_change()` (`scripts/core/run_state.gd:1578`
and `:1605`) is **fail-closed**: departure from a room is refused with

> `Dynamic room sequence semantic records are not finalized for departure.`

unless `scenario_semantic_ready` is true, which only
`RunState.scenario_finalize_installed_environment()` sets.

In production, `EnvironmentInteractionController.interactable_object_view_list()`
(`scripts/ui/environment_interaction_controller.gd:108`) finalizes while building
the room's object list. **If that finalization fails, the controller returns the
degraded `trusted_base_result` fallback and the flag stays false.** The player
then sees a room whose objects have dead panels *and* cannot travel out. That was
the owner's original reported bug.

Measured finalization health:

| Tree | Rooms OK | Dead rooms |
| --- | --- | --- |
| `main` `380721c2` | 47 / 55 | **8** |
| candidate `9c4196dd` | 55 / 55 | **0** |

Closing those eight is the single largest player-facing win available, and it is
why this row lands before anything else.

## 5. Order of work

### Required — these gate playability

1. **Commit** the `wave_b_composition_probe.gd` change (section 3).
2. **Re-scope and close `env06_8`** against the structural bar in section 7. Do
   not reopen implementation. Do not chase the visual findings.
3. **Independent acceptance of the re-scoped row.** This is a *fresh* review
   against the *new* bar by an agent that implemented no part of it. The prior
   two rejections were against the old bar and do not count against the
   re-scoped row — record that explicitly so the two-rejection rule is not
   misapplied. If this review rejects on **structural** grounds, escalate.
4. **Merge to `main` and push**, in this proven conflict-free order:
   `codex/env06_8-clean` → `codex/integ06-final-run` → `codex/playtest06-final-custody`
   → `codex/balance06-final-run`. This is the source freeze.
5. **`fix06_26` — crew favor cadence.** The one genuine composition finding: the
   lender action succeeds (bankroll `+45`, debt recorded) but no Crew favor event
   is queued afterward. Evidence: `event_selection.enqueued = false`,
   `rolled_ids = []`, source
   `ContentLibrary.action_trigger_event_candidates_for_context_readonly`. An
   empty roll list means no candidate matched the trigger context, which points
   at content/trigger wiring rather than probability. **Timebox this.** If it is
   not a contained wiring fix, record it as a playtest finding and move on — it
   does not block the build.
6. **`integ06_1`, migration only.** Run the v0.5.1 and mid-0.6 admission
   matrices so the owner's existing saves survive. Correct the Punchline
   attribution. **Do not** run the full composition matrix or the multi-hour
   terminal soak yet.
7. **Playability sweep.** Across at least eight seeds, prove a player can: enter
   rooms and select objects with populated panels; travel between nodes
   repeatedly without refusal; enter The Punchline L1→L2→L3; open and play at
   least one game per surface family; save, reload, and revisit. Any hard block
   is a `fix06_*` row; cosmetic issues go to the playtest findings list.
8. **Idle liveness sanity check.** Not the full matrix — just the counter-gate in
   `scripts/ui/performance_liveness_guard.gd` on the reworked surfaces. **An idle
   draw cost of 0.000 is a failure, not a pass.** This project has four recorded
   regressions where a perf pass froze idle animations. Catch it now, not after
   the owner plays.
9. **`playtest06_1` — produce the build.** Export the Windows release to
   `builds/windows/BeatTheHouse.exe`, boot it, and hand the owner an honest
   report: what is in it, what is known-broken, what was deferred and why.

### Deferred to the refinement phase — do NOT run these now

- `perf06_1` binding performance matrix (`docs/plans/perf06_1_final_runtime_runbook.md`)
- `balance06_1` follow-on distributions and the 600k-drop pusher EV
- `integ06_1` full composition matrix and native/Web terminal soak
- `env06_9` visual consequence and object identifiability (section 6)
- `voice06_1`, `triage06_1`, `balance06_2`, `cleanup06_1`, `release06_1`

These are release-gating, not playability-gating. The owner will re-open them
after playing. Recording a deferral is required; running one is out of scope.

## 6. env06_9 — parked, do not start

The visual work from the second review is captured in
`docs/todo/env06_9_visual_consequence_and_object_identity_prompt.md`. It is
**PARKED** pending the owner's acceptance bar, because the bar is a design
decision the owner has not yet made:

- must an object's glyph change on state change, or is a changed panel
  description sufficient "visible consequence"?
- how many objects need distinct art versus a shared glyph plus a distinct label?
- is this 0.6 scope, or does it belong to the post-playtest polish pass?

Do not start it, do not guess the bar, and do not port the alternate contract
from `codex/closeout06-final` — the owner already applied the default of not
porting it.

## 7. Acceptance bar for the re-scoped env06_8

This is the **complete** bar. Nothing outside it blocks the row.

- every scenario object has an icon key, a label, a description, and a populated
  panel — actionable options or read-only flavor;
- `"Inspect this first."` is unreachable and no panel is ever empty;
- every action has a handler; no action is a silent no-op at the data layer;
- object zoning is complete — 0 unzoned objects — and the object count did not
  improve by deleting objects;
- **55/55 rooms finalize**, in normal and expanded small-screen layout;
- descriptions are state-accurate and do not lie about what happened;
- exactly-once holds for every consequence the row touches;
- no hidden-state leak, and nothing trusts a caller-supplied capability;
- no change to money, RNG, RTP, payouts, odds, schema or migration;
- project validation, function census, environment readability, semantic layout,
  content depth, packages B/C/D/E, and the world-sequence delivery proof are
  green on the exact head.

**Explicitly out of scope, and not grounds for rejection:** glyph distinctness,
per-object art, raster-visible state change, contact-sheet identifiability, and
anything else requiring `pixel_scene_canvas.gd` to read object `state`.

## 8. Hard limits

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** Adding a step the production host performs is not weakening; deleting
  or relaxing an assertion is. A budget crossing 16.67 ms needs owner sign-off.
- **Never refresh a golden** without proving the content legitimately changed.
- **No release activity.** No version bump, no tag, no packaging, no publish.
  `release06_1` stays parked. A local build for the owner is `playtest06_1`'s
  deliverable and is allowed.
- **Delete nothing** — no branch, worktree, or stash. No `gc`, `reset --hard`,
  `clean`.
- **Never stage owner property**: `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`, build output.
- **Leave no diagnostics in the tree.** Delete throwaway probes when done.
- Commit to a branch at least every 30 minutes, labeled if unreviewed.
- Keep `main` green after every merge and keep `origin/main` in sync.

## 9. Standards every row inherits

- **Idle draw cost of 0.000 is a failure, not a pass.** Four recorded regressions.
- **No per-frame deep copies.** The slot bonus watchdog once cost 32.6 ms/frame.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Exactly once.** Every consequence fires once across save, reload, travel,
  revisit, abort and expiry.
- **Hidden state is absolute.** No Turn, traitor, grievance, rigged-draw or
  unrevealed-ticket information may leak through scene data, serialized keys,
  captures, audio or fixtures. A leak is an automatic P0.
- **The crew-ignoring run is a true no-op.**
- **Rules and math are preserved.** Depth changes presentation and interaction.
- **Any harness that travels between rooms must finalize on arrival** exactly as
  the production host does. Four recorded false-failure incidents.

## 10. How not to stall

- **Park, never block.** If a row needs an owner decision, record the exact
  question, take the stated default, act on it, and move to the next row.
- **Defect budget: three new `fix06_*` rows.** Past that, defects go to the
  playtest findings list for the refinement phase. The owner will triage them
  against the real game, which is cheaper than you guessing now.
- **A second rejection escalates to the owner.** The re-scoped `env06_8` starts
  from zero rejections against its new bar.
- **Never idle.** A parked row means take the next one immediately.

## 11. Reporting

Report at every row closure. Lead with: rows closed of the required set, the row
in flight, anything parked with its exact question, and `main`/`origin` sync
state. Never report a row DONE before its evidence is recorded and its prompt is
archived to `docs/todone/`.

Your terminal condition is **`playtest06_1` handing the owner a booted Windows
build with an honest report**. Stop there. If you are about to stop for any other
reason, take the next required item instead.
