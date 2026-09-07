Status: TODO — TOP PRIORITY; owner playtest is blocked until this passes
Priority: P0 — the owner played the 0.6 build and could not reliably interact with it
Board rows: `fix06_28` (new), unparks `env06_9`; sequenced ahead of `refine06_1`
Opened: 2026-09-07 from direct owner playtest feedback

# Agent Prompt — fix06_28: Restore Observable Interaction and Confirm Working Order

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are working in `D:\Projects\Beat-The-House` on `main` at `152db3c7` or later.
This prompt is complete on its own.

## 0. Authority — read this first

**The owner played the handed-off 0.6 build and reported that it is not reliably
playable.** Their words:

> "when the user clicks a button most of the time the action doesnt take place
> and the room remains unchanged, and if the action is taking place it is not
> apparent. also things like machine environment models and slot machine play
> are also broken."

The `playtest06_1` handoff claimed eight complete mouse-driven seeds passed and
all six game-surface families opened and played. **Both statements cannot be
true.** The owner's hands are authoritative; the automated result is not.

**Finding zero, which you must resolve as part of this row:** the acceptance
suite reported green on a build the owner could not play. Until you understand
why, no green result from that suite is evidence of anything. Do not close this
row by re-running the same harnesses and reporting that they pass.

This is the sixth time in this program that a harness reported working software
where reality differed, or vice versa. See `docs/todo/qa06_1_harness_production_fidelity_prompt.md`.

## 1. Symptom one — actions produce no observable result

### Root cause, already measured

Of **729** player-facing scenario actions on `main`:

| Handler | Count | What the player observes |
| --- | --- | --- |
| `change_scene_object` | 360 | the object's description variant changes; **the room's appearance does not** |
| `complete_objective_step` | 174 | objective text only |
| `set_local` | **125** | **nothing whatsoever** |
| `resolve_objective` | 48 | objective text only |
| `publish_feedback` | 8 | visible |
| `event_bridge` | 6 | visible |
| `grant_item` | 5 | visible |
| `grant_cash` | 2 | visible |
| `play_cue` | 1 | audible |

**Only 22 of 729 actions — 3% — produce an unmistakable player-visible result.**
125 are wholly silent. The remaining 582 change text the player only sees if they
re-select the object and read the panel.

Compounding it, in `scripts/ui/pixel_scene_canvas.gd`:

```gdscript
func _fallback_event_prop(visual_key: String, icon_key: String) -> String:
```

Object `state` is **not an input** to prop selection. So `change_scene_object` —
the single most common consequence, 360 uses — **cannot** alter the room's
appearance by construction. The owner's inference that "the action didn't take
place" is a correct reading of the evidence the game gives them.

### Why the previous bar missed it

The re-scoped `env06_8` acceptance bar required "every action has a handler; no
action is a silent no-op **at the data layer**." `set_local` satisfies that
wording while being invisible to the player. **The bar was wrong.** The correct
bar is the owner's original ruling:

> Acting on an object must produce visible consequence: a conversation, an item,
> a change in the room. Never a silent flip.

That is a **player-observable** bar. Use it. A handler existing is not a pass.

### Required work

1. **Make consequence observable.** Every player-facing action must produce at
   least one of: a changed room appearance, a conversation/event, an item or
   cash change, or an unmistakable on-screen acknowledgement. Re-selecting an
   object to read changed text is **not** sufficient on its own.
2. **Teach prop selection to read `state`.** `change_scene_object` must be able
   to change what the player sees. This is the single highest-leverage fix in
   this row — it upgrades 360 actions at once.
3. **Eliminate or upgrade the 125 `set_local` actions.** Either give each an
   observable consequence, or fold it into an action that has one. A pure
   variable flip presented to the player as a clickable choice is the defect.
4. **Add an immediate acknowledgement path.** Even a correct, visible consequence
   can be missed if it is off-screen or subtle. Every accepted action should
   confirm itself at the point of interaction.

`env06_9` (`docs/todo/env06_9_visual_consequence_and_object_identity_prompt.md`)
is **hereby unparked and absorbed into this row.** The owner's playtest answered
its first question: visible consequence must be apparent **in the room**, not
only in the panel. Its remaining two questions — how much distinct per-object art
is required, and whether full art parity is 0.6 scope — stay open; take the
default of "enough that a player can tell objects apart and see state change,"
record what you did, and do not block on them.

## 2. Symptom two — slot machine play and machine environment models

### Confirmed lead

`scripts/tests/foundation/check_slots_surfaces.gd` **does not run to completion.**
It aborts with:

> `SCRIPT ERROR: Invalid call. Nonexistent function '_check_canonical_pack_paths'`

Cause: `scripts/tests/foundation/check_core_content.gd:761` performs

```gdscript
call("_check_canonical_pack_paths", failures)
```

but that function is defined only in
`scripts/tests/foundation/check_lenders_release_saves.gd:4368`. The dynamic
`call()` resolves against whichever object is running, so it explodes when the
shared foundation run is entered from the slots check.

**Consequence: slot surface validation has been erroring, not validating.** Its
green-looking history is worthless. Fix the cross-script call, then find out what
the now-working check actually reports.

`scripts/tests/foundation/game06_4_machine_ritual_contract.gd` **passes**, so the
machine ritual *logic* is probably intact and the breakage is more likely in
presentation, model/prop loading, or the environment's machine objects. Confirm
that; do not assume it.

### Required work

1. Fix the cross-script `call()` defect and get `check_slots_surfaces.gd` running.
2. Reproduce the owner's slot-play failure by actually playing a slot machine
   through the production host, and fix it.
3. Reproduce and fix "machine environment models" — establish first whether the
   owner means machine props in the room, machine game surfaces, or both. If
   ambiguous after investigation, record the exact question, fix everything you
   can identify, and report what remains uncertain.

## 3. Symptom three — the general working-order pass

The owner asked for a general pass confirming the build is in working order for
playtesting. This is the row's third deliverable.

**Method matters more than coverage here.** Drive the game through the
production host exactly as a player does. Do not validate by calling core
functions directly, and do not trust any existing harness until you have checked
it against section 5.

Cover at minimum, on multiple seeds:

- entering rooms; selecting **every** object; confirming each has an icon, label,
  description and populated panel, and that acting on it visibly does something;
- travelling repeatedly between nodes, including departing a room you have acted
  in, and revisiting;
- every one of the six surface families opened **and actually played** to a
  resolved outcome — novelty, slots, dice, cards, wheel, coin pusher;
- The Punchline L1 → L2 → L3, including back-room content;
- save, reload, Continue, and revisit after each of the above;
- the Crew path far enough to confirm favors, jobs and deliveries respond.

Any hard block becomes a `fix06_*` row. Anything cosmetic goes to a findings list
for the owner.

## 4. Known related defects — fold in or route, do not rediscover

- **Seed-dependent dead rooms (`fix06_27`).** Room finalization fails on a
  minority of seeds; each failure gives unpopulated panels **and** refused
  travel. Three reproducible cases with root causes are in
  `docs/todo/fix06_27_seed_dependent_room_finalization_prompt.md`. This may be
  part of what the owner experienced. Fix it here or confirm it is separate.
- **65 confirmed failures in the Crew/world contracts on `main`.** Reproduced
  2026-09-07 by running
  `scripts/tests/foundation/check_slots_surfaces.gd`, which enters the shared
  foundation runner (`crew_recruitment_contract`, 38.4s, `failures=65`). Note the
  contract completes in ~40s inside the shared runner but hangs past 600s when
  launched standalone — that discrepancy is itself worth understanding. The
  distinct error classes are:

  **(a) Two of seven crew members cannot be recruited by their fallback path.**
  > `Crew recruitment crew_mags could not enter its generated fallback placement.`
  > `Crew recruitment crew_bishop could not enter its generated fallback placement.`
  > `Production generation did not expose crew_mags's fallback recruitment path.`
  > `Production generation did not expose crew_bishop's fallback recruitment path.`

  If the owner cannot reach Mags or Bishop, the Crew roster is incomplete in play.

  **(b) The heist's Plan B lifeline is broken.**
  > `Plan B could not activate its real coordinated-play lifeline.`
  > `Plan B did not consume exactly one real coordinated-play activation as a finite lifeline.`

  Plan B is one of the two shipped heist plans — flagship 0.6 content.

  **(c) The crew-ignoring golden probe is failing across every checkpoint.**
  `CREW-IGNORED-GOLDEN-B` differs on `initial_bar`, `ordinary_travel`,
  `bar_revisit` and `save_load_round_trip`, for `run_state`,
  `current_environment` and `world_environments`, in both bytes and SHA.

  **This is the invariant every prompt in this program calls absolute: "the
  crew-ignoring run is a true no-op." It broke once before; this golden probe
  exists because of it.** Determine whether the golden is legitimately stale
  because content changed, or whether Crew state is once again leaking into a run
  that ignores the Crew. **Do not refresh the golden to make this pass** without
  proving the content change was legitimate — that is the exact failure mode the
  probe was built to catch. If it is a real leak, it is a P0 and outranks the rest
  of this row.

  These 65 failures were counted by the acceptance suite and the build was still
  handed off as playtestable. That is the sharpest available evidence for finding
  zero in section 0.
- **Harness fidelity (`qa06_1`).** Five prior incidents where harnesses
  reimplemented the host instead of driving it, plus finding zero above.
  `docs/todo/refine06_1_harness_fidelity_and_room_finalization_prompt.md` holds
  the full audit. **Pull its shared arrive/activate helpers forward into this
  row** — you cannot trust your own verification without them.

## 5. Harness rules you must follow while verifying

Two failure modes have repeatedly produced false results in this program:

- **Skipping a mandatory host step.** `RunState.scenario_preflight_environment_change()`
  (`scripts/core/run_state.gd:1578`, `:1605`) is fail-closed: departure is refused
  unless `scenario_semantic_ready` is true, which only
  `RunState.scenario_finalize_installed_environment()` sets. In production,
  `EnvironmentInteractionController.interactable_object_view_list()`
  (`scripts/ui/environment_interaction_controller.gd:108`) does this while
  building the room's object list — and **returns degraded fallback records if it
  fails**, which is what produces dead panels plus refused travel. Any harness
  that travels must finalize on arrival exactly as the host does.
- **Selecting targets by broad type or render order instead of exact semantic
  identity.** `tools/foundation_visual_qa.gd` clicks `travel:motel_room`
  ("Room Door") instead of `travel:leave` for this reason, producing a false
  "broken world map" plus twenty cascading failures. Root cause and fix are in
  `docs/todo/playtest06_current_source_bug_investigation_2026-09-07.md`.

## 6. Acceptance

This row closes when **a person can play the build and see it respond**, not when
a suite reports green.

- Every player-facing action produces an observable consequence by the owner's
  bar. Zero remaining actions whose only effect is a silent variable flip.
- `change_scene_object` visibly changes the room.
- Objects are distinguishable well enough that a player can tell them apart.
- Slot play works end to end through the production host; `check_slots_surfaces.gd`
  runs to completion and passes.
- Machine environment models render and behave correctly.
- The section 3 pass completes on multiple seeds with every hard block fixed or
  filed.
- Finding zero is explained: you can state why the acceptance suite passed a
  build the owner could not play, and the gap is closed.
- `tools/validate_project.ps1` green on the exact head.
- No change to money, RNG, RTP, payouts, odds, schema or migration.

## 7. Hard limits

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** Making a harness perform a step the production host performs is
  fidelity; deleting or relaxing an assertion is weakening. A budget crossing
  16.67 ms needs owner sign-off.
- **Never refresh a golden** without proving the content legitimately changed.
- **No release activity.** No version bump, tag, packaging, or publish. You may
  produce a **local Windows build** for the owner when the row is done — that is
  this row's deliverable.
- **Delete nothing** — no branch, worktree, or stash. No `gc`, `reset --hard`,
  `clean`.
- **Never stage owner property**: `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`.
- **Leave no diagnostics in the tree.**
- Commit to a branch at least every 30 minutes, labeled if unreviewed.
- Keep `main` green after every merge and keep `origin/main` in sync.

## 8. Standards every row inherits

- **Idle draw cost of 0.000 is a failure, not a pass.** Four recorded
  regressions, and this row touches the renderer.
- **No per-frame deep copies.** The slot bonus watchdog once cost 32.6 ms/frame.
  You are changing slot and prop rendering — do not reintroduce it.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Exactly once.** Every consequence fires once across save, reload, travel,
  revisit, abort and expiry.
- **Hidden state is absolute.** A newly visible prop state must never reveal
  Turn, traitor, grievance, rigged-draw or unrevealed-ticket state. A leak is an
  automatic P0, and this row makes previously invisible state visible — check
  every new visual against it.
- **The crew-ignoring run is a true no-op.**
- **Rules and math are preserved.** This row changes presentation and
  interaction, not odds.

## 9. Reporting

Report at each symptom's resolution. Lead with what a player can now do that they
could not before, the evidence you gathered **by playing**, anything still
uncertain with its exact question, and `main`/`origin` sync state.

Your terminal condition is a local Windows build the owner can play in which
clicking things visibly works. Deliver it with an honest report of what remains.
