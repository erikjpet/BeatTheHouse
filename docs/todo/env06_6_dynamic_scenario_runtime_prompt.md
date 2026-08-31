Status: IN_PROGRESS — implementation landed on `main`; formal row acceptance remains open
Board row: `env06_6` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 env06_6: Dynamic Scenario Runtime

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). This is an
owner-requested depth rework of the shipped Tonight system. Read the archived
`docs/todone/env06_1_scenario_engine_prompt.md`, the actual
`scripts/core/scenario_engine.gd`, `scripts/core/environment_instance.gd`,
`scripts/ui/pixel_scene_canvas.gd`, and the node snapshot/save contracts before
editing. Code reality wins.

## Why this rework exists

The current catalog has 55 scenarios. Every one changes presentation and
selects an exclusive event, but only 9 have more than one phase. The mutation
schema can swap patrons/staff, pools, prices, services, music, palette,
security, flags, and game modifiers. It cannot author room-object movement,
route/access changes, replacement interactions, local objectives, actor
behavior, branching phase graphs, or persistent spatial aftermath. The event
choices then mostly resolve to cash, suspicion, flags, or an item. Those are
useful consequences, but they are not a scenario.

The completed state must make a scenario a playable sequence that changes the
space and what the player does there. `env06_7` will rebuild every authored
variant on this runtime.

## Board protocol

Follow `docs/todo/README_0_6_board.md`. Claim `env06_6` before work, log
discoveries, never edit archived prompts, and archive this prompt only after
all gates pass. This task owns the runtime/schema/tests, not the 55 content
conversions.

## 1. Define the scenario-sequence contract

Add a validated, versioned data contract. Exact names may adapt to code
reality, but every capability below is mandatory:

- `local_state_schema`: typed/defaulted scenario-local state, stored in the
  node snapshot rather than global flags.
- `phase_graph`: stable phase ids, entry conditions, objective completion and
  explicit next-phase branches. Ordered `advance_after_actions` remains a
  supported compatibility path, not the only lifecycle.
- `scene_ops`: registered operations to spawn, remove, move, replace, reveal,
  hide, enable, disable, or change the state/appearance of semantic scene
  objects. Operations address stable object ids, never screen coordinates.
- `interaction_ops`: add, remove, replace, gate, or retarget interactables and
  services; support scenario-local prompts and state-dependent action sets.
- `actor_ops`: spawn/despawn actors, assign authored positions/routes/poses,
  and switch a bounded behavior state. Do not build a general scripting VM.
- `objectives`: multi-step local tasks with public, diegetic progress and
  success/failure/ignore/cancel outcomes.
- `transition_ops`: entry/exit reactions, short deterministic staging beats,
  sound/music cues, and scene changes applied exactly once.
- `reentry_policy`, `expiry`, and `cleanup`: define what a revisit sees, what
  survives the night, how abandoned objectives resume or fail, and how all
  temporary objects/interactions are safely removed.
- `aftermath`: persistent local scene/actor/service/game changes for each
  material branch. A global flag alone is not aftermath.
- `mechanic_tags` and `sequence_signature`: authored metadata used by the
  uniqueness audit; calculated normalized signatures must also be emitted so
  authors cannot evade the audit by renaming fields.

Complex mechanics must use small registered handlers with explicit input,
output, persistence, and deterministic-RNG contracts. JSON must not contain
arbitrary code, reflection targets, resource paths outside allowlists, or raw
node paths.

## 2. Make semantic scene objects real

- Give environment render models stable semantic object ids and bounded
  anchors/zones. The procedural renderer must consume scenario scene state,
  including collision/hit regions and visual state; metadata-only props fail.
- Build a layout resolver that validates object bounds, walk/access lanes,
  interaction reachability, z-order, text safety, and small-screen/reduced-
  motion layouts. A scenario may intentionally block a route only when it
  supplies a readable alternate objective or exit.
- Scene changes must be visibly staged at phase transitions and already be in
  their correct state after save/load or revisit. Rehydration must not replay
  rewards, dialogue, audio, or one-shot transition effects.
- Keep base environments byte/behavior compatible when no dynamic sequence is
  active. Existing simple mutation fields remain supported during migration.

## 3. Runtime lifecycle and action routing

- Route scenario actions through one authoritative command/result boundary.
  Validate phase, object/interactable availability, objective preconditions,
  cost, and idempotency before changing state.
- Advance only from explicit player/world actions or deterministic town
  boundaries. Never use wall-clock time for authoritative outcomes.
- Let games, events, services, travel, Police Sweep, crew state, heat, and town
  happenings publish typed facts to a scenario without directly mutating its
  internals. Scenarios may respond at the next safe boundary.
- Support coexistence: a scenario sequence, ordinary game session, event,
  service, traveler, and sweep pressure must not overwrite each other's
  interactables or snapshot state. Define priority and conflict rules.
- Persist local state, phase id, objective progress, actor/object state,
  resolved branches, transition receipts, and cleanup receipts. Migrate all
  55 legacy scenario snapshots without reselecting their identity.
- Event rewards/consequences may occur inside a sequence, but resolving the
  event must not automatically resolve the scenario unless its graph says so.

## 4. Authoring and uniqueness tools

Add a scenario sequence validator/report that, for every variant, emits:

- phase graph and reachable terminal branches;
- scene object/interactable/actor differences per phase;
- player verbs and objective steps per branch;
- persistence/reentry/cleanup coverage;
- normalized mechanic signature and nearest-neighbor similarity;
- referenced handler, event, game, service, item, actor, and object ids;
- seed/reachability evidence and screenshots/capture ids.

Reject content when it has unreachable phases, missing cleanup, orphaned hit
regions, invalid refs, duplicate rewards, state-only transitions with no
player-readable change, or a mechanic signature equivalent to another
scenario. Shared primitives are encouraged; shared complete sequences are not.

## 5. Hard definition of a complete variation

The validator and review checklist must require all of the following unless a
documented owner-approved exception names the reason:

1. A distinct arrival state readable without opening an info panel.
2. At least two meaningful semantic scene-object/actor changes across the
   sequence; tint, sign text, music, and crowd-density strings do not count.
3. At least one scenario-specific interaction or altered core-game task.
4. At least two consequential player/world action boundaries and an authored
   arrival → complication/opportunity → aftermath progression.
5. At least one meaningful choice, failure, refusal, or ignore path.
6. At least two material outcomes whose spatial, interaction, actor, service,
   route, or game aftermath differs. Reward amount alone does not count.
7. Revisit behavior after partial progress and after every terminal outcome.
8. A world-system connection that changes play, not just flavor text.
9. No item/cash/flag/reputation grant as the primary verb or whole sequence.
10. Human-readable feedback for cause/effect and a clean exit at every phase.

## 6. Tests and proof

- Fixture-test every scene/interaction/actor operation and every lifecycle
  policy, including invalid data rejection and idempotent replay.
- Save/load at every phase and immediately before/after each branch boundary;
  compare complete semantic snapshots and prove no duplicated consequences.
- Determinism: identical seed/actions produce identical sequence state,
  layouts, actor routes, and outcomes on native and Web.
- Compatibility: legacy saves for all 55 ids migrate in place; no-scenario
  nodes remain behavior-identical.
- Composition tests: sequence + event + game + service + traveler + sweep,
  including competing interactables and a mid-game scenario response.
- Visual QA: entry, every phase, every terminal aftermath, revisit, reduced
  motion, small screen, and obstruction/hit-target overlays.
- Performance: no per-frame schema evaluation or scene reconstruction;
  transitions work at boundaries and renderer reads prepared snapshots.

## Gates

- `tools/validate_project.ps1`
- all supported systems, content, UI, save, accessibility, and full foundation
  suites
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- native/Web exact-sequence parity fixture
- `tools/foundation_visual_qa.ps1`
- the new scenario sequence/uniqueness audit with zero failures

## Completion handoff

Report the schema, handler registry, persistence migration, conflict rules,
authoring report format, performance measurements, and gate evidence.
`env06_7` is unblocked only when one migrated proof scenario demonstrates a
real spatial change, multi-step objective, branch-specific aftermath, and
exact mid-sequence save/load.
