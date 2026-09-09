Status: TODO — owner-reported regression; blocking for playtest quality
Board row: `fix06_25` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_25: Environment Object Presentation and Consequence Feedback

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. The owner playtested 0.6 and
reported that environments are cluttered with objects that cannot be
meaningfully clicked, that lack icons and descriptions, that expose no options in
their information panel, and that when something does happen it happens
invisibly. Their requirement: **every object must behave like a 0.5 object —
icon, description, selectable options in its information panel — including all
new objects created by the 0.6 scenario runtime. And acting on an object must
produce visible consequence: a conversation, an item, a change in the room.
Never a silent state flip.**

This is two separate failures that produce one symptom. Fix both.

## Measured evidence — do not re-derive, verify and extend

Across `data/environments/scenario_sequences/*.json`, 55 scenarios / 376 phases:

| Op family | Count | Consequence |
| --- | --- | --- |
| `scene_ops` (decorative objects) | 806 | enter the clickable list, no icon, no panel wiring |
| `actor_ops` (actors) | 302 | same |
| `interaction_ops` | 490 (298 records) | wired for actions, but see payload below |
| `transition_ops` | 412 | text-only, machine-templated prose |

Of **673 player-facing actions** in the entire game:

- `complete_objective_step`: 178 · `set_local`: 78 · `resolve_objective`: 48 ·
  `publish_feedback`: 13 · **`event_bridge`: 1**
- **355 actions carry no handler at all** — they only advance a branch.
- **Zero actions grant an item, cash, or any tangible reward.**

Transition messages are developer-language templates, not narrative — e.g.
"The tray move beat moves props and actors for carry to regular." and
"The toast shared aftermath fixes a distinct bar wake room state for revisit."

## Failure 1 — Presentation wiring gap (code)

`env06_6` (commit `202a2566`, reconciled at `2d185713`) added a semantic
projection layer in `scripts/ui/environment_interaction_controller.gd` splitting
scenario objects into two record kinds:

- `_merge_projected_interaction()` (line ~450) → `object_type = "scenario_sequence"`.
  Fully wired end to end.
- `_merge_projected_scene_object()` / `_merge_projected_actor()` (lines ~493, ~527)
  → `object_type = "scenario_scene_object"` / `"scenario_actor"` / `"character"`.
  **Never wired.**

Specifically:

1. Neither merge function sets `icon_key`. Every other interactable producer in
   the project sets it explicitly; `pixel_scene_canvas.gd` (`_fallback_event_prop`,
   lines ~2652 / ~4814) uses it to choose the drawn prop. Result: no icon.
2. `foundation_main.gd` has two `match object_type:` dispatch tables —
   `_add_context_object_actions()` (builds info-panel buttons on selection) and
   `_activate_interactable_object_with_lifecycle_snapshot()` (handles activation).
   **Neither has a case for the three new types.** Selecting shows nothing;
   activating falls through to the catch-all `_show_message("Inspect this first.")`
   — a dead end, because inspecting also shows nothing.

Ordinary 0.5-era objects (games, travel, items, services, lenders, home, casino
fixtures) are NOT affected: `world_sequence_finalize_base_semantics()` stamps
them rather than replacing them, and `_compose_projected_records()` passes
unclaimed base records through untouched. Confirm this before changing anything —
it bounds the blast radius to 0.6-authored content only.

### Required outcome — owner-decided policy

**Decorative objects are inspectable, not removed.** The owner has ruled that
scene objects and actors stay in the room as inspectable flavor that carries the
story of the night. Implement this exactly:

- Every scenario/world-owned record reaching the player's object list has an
  `icon_key` resolving to a real drawn prop, a `label`, and a description.
- Both dispatch tables handle `scenario_scene_object`, `scenario_actor` and
  `character`. Selecting one populates the information panel with icon, label and
  description. Objects with no authored actions show a read-only panel entry —
  never an empty panel, never `"Inspect this first."`, which must become
  unreachable.
- **Descriptions are state-aware.** `scene_ops` change state across phases
  (`spawn` / `move` / `replace` / `reveal` / `hide` / state change). An object's
  description must reflect its *current* state and read differently after that
  state changes. The joined memorial tables before the toast and after it are not
  the same sentence.
- **Descriptions showcase what has been happening.** The room's objects are the
  visible record of the scenario's progress. A player who walks in mid-sequence,
  or returns after leaving, should be able to read the room and understand what
  occurred from the props and actors alone.
- **Descriptions hint at mechanical effect on the player.** Where an object's
  presence changes the player's situation, the description must telegraph it in
  fiction rather than stating a number: a watching patron implies cheating is
  riskier here; an open bar implies cheaper drinks; a blocked aisle implies that
  exit is closed; a thinning crowd implies the night is ending. Where an object
  has no mechanical effect, it still carries the room's story.
- No object that appears clickable may produce nothing when clicked.

### Authoring structure and scale — plan before writing

1,108 records (806 scene objects + 302 actors) across 376 phases, each needing
copy per material state. Do not attempt a flat list of 1,108 hand-written
strings, and do not regenerate template prose — that is the defect being fixed.

Structure it as an authored base description per object plus variant lines keyed
to its material states, so a state change swaps the line rather than duplicating
the object. Establish the pattern and prove it on one full archetype package
before scaling, and report the real per-package cost after that first package so
the remaining scope is estimated from measurement rather than guess.

### Hidden-information risk introduced by this change — mandatory

Adding ~1,108 new player-visible description surfaces that narrate "what has been
happening" is a **new leak vector for hidden state**. This is the single most
dangerous part of this row.

No description, on any object, in any state, may allow inference of: the Turn's
traitor or grievance weighting, a rigged Numbers draw before its discovery
conditions, unrevealed scratch-ticket contents, or any other hidden system.
A room whose crew member has turned must read identically to one whose has not.
Prove it with paired-observer evidence: identical seeds differing only in hidden
state must produce identical description sets. A leak here is an automatic P0 and
this evidence belongs in `world06_7`'s hidden-information audit.

## Failure 2 — Consequence payload gap (content and handler vocabulary)

The `env06_7` conversion was produced by a generator (`tools/env06_7_package_a_generate.gd`).
It satisfies the structural contract — unique mechanic signatures, phase graphs,
branches, aftermath — while producing no tangible player consequence. `depth06_1`
passed it because that gate measured *structural* uniqueness, not experienced
richness.

### Required outcome

- **Extend the action handler vocabulary** so an action can: trigger a
  conversation/event, grant an item or cash, change a visible scene object or
  actor state, and play a cue. `event_bridge` already exists and is used exactly
  once — it must become ordinary. Reuse the existing machinery rather than
  building a parallel one: `_consume_scenario_event_requests()` already dispatches
  `_activate_event_object(event_id)` for real dialogue, and
  `_consume_scenario_transitions()` already plays audio cues and surfaces
  messages (`foundation_main.gd` ~12534–12570).
- **Every action must produce at least one observable result**: a conversation, an
  item/cash change, a visible scene or actor change, or a staged animation — plus
  a message. A branch advance with no observable result is a defect.
- **Rewrite the templated prose.** Transition messages, object labels, and prompts
  must read as authored narrative in the project's voice, not as system
  description. "The toast shared aftermath fixes a distinct bar wake room state
  for revisit" is not shippable copy.
- **Curate the 806 decorative objects.** Many should be pure background dressing
  with no hit region. Others should become real interactions. Justify the split
  per scenario rather than leaving all 806 clickable-but-inert.

## Constraints

- Preserve determinism, action-boundary timing, exactly-once consequences, and
  hidden-state discipline. Item grants and dialogue triggers must fire exactly
  once across save, reload, revisit, abort and expiry.
- Do not change RTP, EV, payouts, odds, wager math, schema or migration.
- Never weaken a test or refresh a golden to accommodate new content; if a
  golden legitimately changes because authored copy changed, prove the content
  change is intentional and record it.
- Reduced-motion paths must keep semantic parity with animated ones.

## Acceptance

1. A player can enter any of the 55 scenarios, see every object with an icon and
   description, and select any object to get a populated information panel —
   either actionable options or read-only flavor.
2. No object in any scenario reaches `"Inspect this first."` or an empty panel.
3. Descriptions are state-aware: an object read before and after a material state
   change produces different, correct copy. Evidence per scenario.
4. A player entering mid-sequence or returning after leaving can read the room's
   objects and correctly describe what happened there.
5. Descriptions telegraph mechanical relevance in fiction where a mechanical
   effect exists, verified against the actual effect — no description implies an
   effect the object does not have.
6. Every action produces an observable consequence, evidenced per scenario.
7. Handler distribution shows real use of conversation, reward, and scene-change
   handlers — not 355 no-op branch advances. Report the before/after table.
8. Paired-observer hidden-state proof: identical seeds differing only in hidden
   state produce identical description sets. Any difference is a P0.
9. Visual evidence: unlabeled contact sheets per scenario showing objects are
   identifiable from icon and room state alone.
10. `depth06_1`'s gate is amended so structural uniqueness alone cannot pass a
    scenario whose actions produce no observable consequence, and `world06_7`'s
    hidden-information audit covers description surfaces.

Run project validation, the scenario/sequence contracts, determinism, native/Web
parity, performance with the idle-liveness counter-gate, and visual QA. Record
the before/after handler distribution table in the closeout.
