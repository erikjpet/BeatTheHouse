Status: TODO — owner-reported regression; supersedes and absorbs `fix06_25`
Board row: `env06_8` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 env06_8: Environment Readability, Object Presentation and Consequence

Copy everything below this line into the agent. It may use sub-agents.

---

You are working in `D:\Projects\Beat-The-House`. The owner playtested 0.6 and
found environments cluttered with objects that cannot be meaningfully clicked,
that have no icons or descriptions, that expose no options in their information
panel, and that when acted on change things invisibly.

**The bar, in the owner's words:** every object must behave like a 0.5 object —
icon, description, and the right information and selection options in its text
box — including every new object the 0.6 scenario runtime creates. Objects must
be placed appropriately so rooms read cleanly. Decorative objects stay and are
**inspectable**, showing what has been happening in the room and hinting at how
their presence affects the player. Acting on an object must produce visible
consequence: a conversation, an item, a change in the room. Never a silent flip.

## Measured evidence — verify, then extend

`data/environments/scenario_sequences/*.json`, 55 scenarios / 376 phases:

| Fact | Value |
| --- | --- |
| `scene_ops` (decorative objects) | 806 |
| `actor_ops` (actors) | 302 |
| `interaction_ops` | 490 ops / 298 records |
| `transition_ops` | 412 |
| Player-facing actions | 673 |
| **Objects with NO `zone_id`** | **768 of 1,108 (69%)** |
| Objects per phase | avg 2.9, max 10, only 18 phases above 8 |

Action handlers across all 673 actions:
`complete_objective_step` 178 · `set_local` 78 · `resolve_objective` 48 ·
`publish_feedback` 13 · **`event_bridge` 1** · **no handler at all: 355** ·
**item/cash grants: 0**

Transition prose is machine-generated template text describing system mechanics,
e.g. "The toast shared aftermath fixes a distinct bar wake room state for
revisit." This is not shippable copy.

## Root causes

**1. Presentation wiring gap (code).** `env06_6` (commit `202a2566`) split
scenario objects into two record kinds in
`scripts/ui/environment_interaction_controller.gd`:
`_merge_projected_interaction()` (~line 450) produces
`object_type = "scenario_sequence"` and is fully wired; while
`_merge_projected_scene_object()` and `_merge_projected_actor()` (~lines 493,
527) produce `"scenario_scene_object"`, `"scenario_actor"` and `"character"` and
were **never wired**. Neither sets `icon_key` — every other producer in the
project does, and `pixel_scene_canvas.gd` `_fallback_event_prop` (~2652, ~4814)
consumes it to choose the drawn prop. `foundation_main.gd` has two
`match object_type:` tables — `_add_context_object_actions()` and
`_activate_interactable_object_with_lifecycle_snapshot()` — and **neither has a
case for the three types**, so selecting shows nothing and activating dead-ends
on `_show_message("Inspect this first.")`.

**2. Placement gap (content).** 69% of scenario objects declare no `zone_id`, so
they never reach the composed placement the zone vocabulary supports
(`center`, `left`, `right`, `background`, `foreground`, `exit_lane`,
`service_lane` — 196 zone entries authored in `archetypes.json`). They fall to
fallback slots resolved only for collision, not for composition. That is why
rooms read as arbitrary rather than staged.

**3. Consequence gap (content).** The `env06_7` conversion was produced by a
generator (`tools/env06_7_package_a_generate.gd`). It satisfies the structural
contract while producing almost no observable consequence. `depth06_1` passed it
because that gate measured structural uniqueness — mechanic signatures, phase and
branch counts — and never whether an action produces something a player can see.

Ordinary 0.5-era objects (games, travel, items, services, lenders, home, casino
fixtures) are NOT affected: `world_sequence_finalize_base_semantics()` stamps
rather than replaces them, and `_compose_projected_records()` passes unclaimed
base records through untouched. Confirm this before editing — it bounds the work
to 0.6-authored content.

## 1. Presentation wiring

- Set `icon_key` on every scenario/world-owned record so it resolves to a real
  drawn prop. Compose from the authored `role`, `state` and `appearance` fields.
- Handle `scenario_scene_object`, `scenario_actor` and `character` in both
  dispatch tables. Selecting one populates the information panel with icon,
  label, description and either actionable options or a read-only entry.
- `"Inspect this first."` and empty panels must become unreachable for any object
  the player can select.

## 2. Placement and readability

- Assign a deliberate `zone_id` to every object that lacks one. Zones are a
  composition vocabulary, not a slot allocator: foreground reads first,
  background sets scene, lanes stay walkable.
- **Exit and service lanes must remain clear.** A scenario may block a route only
  when it supplies a readable alternate objective or exit, per the `env06_6`
  contract. Verify no scenario traps the player.
- Validate every phase for overlap, reachability of every hit region, z-order
  correctness, text safety, and small-screen and reduced-motion layouts. The
  existing gap rule is 8px padded on both rects
  (`environment_instance.gd` `_rects_overlap_with_layout_gap`).
- Density is not the current problem (avg 2.9 per phase); composition is. Do not
  delete objects to reduce counts. If a phase still reads as cluttered after
  zoning, rebalance placement first and only then reconsider the object.

## 3. Inspectable descriptions — owner-decided policy

Decorative objects stay and become inspectable flavor that carries the story.

- **State-aware.** `scene_ops` change state across phases (`spawn`, `move`,
  `replace`, `reveal`, `hide`, state change). A description must reflect current
  state and read differently after it changes. The joined memorial tables before
  the toast and after it are not the same sentence.
- **Show what has been happening.** A player arriving mid-sequence, or returning
  after leaving, must be able to read the room's objects and correctly describe
  what occurred there.
- **Hint at mechanical effect in fiction.** A watching patron implies cheating is
  riskier; an open bar implies cheaper drinks; a blocked aisle implies that exit
  is closed; a thinning crowd implies the night is ending. Never state a number.
  **No description may imply an effect the object does not actually have** —
  verify each against the real effect.

**Authoring structure.** 1,108 records across 376 phases, each needing copy per
material state. Do not write a flat list of 1,108 strings and do not regenerate
templates — that is the defect being fixed. Author a base description per object
plus variant lines keyed to material states. Prove the pattern on one archetype
package, report the real per-package cost, then scale from measurement.

## 4. Consequence

- Extend the action handler vocabulary so an action can trigger a conversation,
  grant an item or cash, change a visible scene object or actor state, and play a
  cue. Reuse existing machinery — `_consume_scenario_event_requests()` already
  dispatches `_activate_event_object(event_id)` for real dialogue, and
  `_consume_scenario_transitions()` already plays cues and surfaces messages
  (`foundation_main.gd` ~12534–12570). `event_bridge` exists and is used once; it
  must become ordinary.
- **Every action produces at least one observable result** — a conversation, an
  item or cash change, a visible scene or actor change, or a staged animation —
  plus a message. A branch advance with no observable result is a defect.
- Rewrite templated prose into authored narrative in the project's voice.

## 5. Hidden-information risk — mandatory, P0

Adding roughly 1,108 player-visible surfaces that narrate what has been happening
is a **new leak vector**. No description, on any object, in any state, may allow
inference of the Turn's traitor or grievance weighting, a rigged Numbers draw
before its discovery conditions, unrevealed scratch-ticket contents, or any other
hidden system. A room whose crew member has turned must read identically to one
whose has not.

Prove it: identical seeds differing only in hidden state produce identical
description sets. Any difference is an automatic P0. This evidence is required by
`world06_7`'s hidden-information audit.

## Parallel-safety — other agents are working right now

You are running alongside active closeout work. **Own only these paths:**

- `data/environments/scenario_sequences/*.json`
- `data/environments/archetypes.json` (zone and anchor authoring only)
- `scripts/ui/environment_interaction_controller.gd`
- the scenario-object layout resolver and the `pixel_scene_canvas.gd` icon
  fallback path
- `tools/env06_7_package_*` generators
- your own new tests

**Do not touch:** `scripts/games/*` (`game06_2` and `game06_8` closeouts in
flight), performance harnesses or budgets (`perf06_1`), `integ06_1` fixtures and
soak harness, tutorial lesson data (`teach06_2`), audio manifests (audio
closeout), or the `world06_*` crew models (world closeout).

In `foundation_main.gd`, edit **only** the scenario-object functions named in
this prompt. That file is large and shared. Rebase onto `main` frequently — at
minimum before every review request — and never bulk-format it.

## Definition of done — this row is not finished until it is on `main`

Per the board protocol: a pushed branch is `IN_PROGRESS`, and **branch existence
is never completion evidence.** This row is DONE only when its work is merged to
`main`, `main` is green at that exact head, the prompt is archived to
`docs/todone/`, and the board row records the merge commit. Do not report
completion before that, and do not stop at "ready to merge".

## Acceptance

1. Every object in all 55 scenarios has an icon, a label and a description, and
   selecting it populates the information panel — actionable options or read-only
   flavor. No empty panels, no `"Inspect this first."`.
2. Every object has a deliberate `zone_id`; zero remain unzoned.
3. Every phase passes overlap, reachability, z-order, text-safety, small-screen
   and reduced-motion validation. Exit and service lanes stay usable, or a
   readable alternate exit exists.
4. Descriptions are state-aware — before and after a material state change reads
   differently and correctly.
5. A player entering mid-sequence or returning can read the room and correctly
   describe what happened.
6. Descriptions telegraph real mechanical relevance and never imply an effect the
   object lacks.
7. Every action produces an observable consequence, evidenced per scenario.
8. Handler distribution shows real use of conversation, reward and scene-change
   handlers — report the before and after table against the baseline above.
9. Paired-observer hidden-state proof passes; any description difference is P0.
10. Unlabeled contact sheets per scenario: objects identifiable from icon and room
    state alone.
11. `depth06_1`'s gate is amended so structural uniqueness alone cannot pass a
    scenario whose actions produce no observable consequence.

Run project validation, scenario and sequence contracts, determinism, native/Web
parity, performance with the mandatory idle-liveness counter-gate, accessibility,
save and revisit, and visual QA. Record the before and after handler and zoning
tables in the closeout.
