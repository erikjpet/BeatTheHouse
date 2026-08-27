# game06_1 Ritual Vocabulary Contract — Pre-implementation Acceptance Checklist

Status: pre-implementation checklist; contract-authoring package only  
Owner: `/root/contract_author_game`  
Independent reviewer: pending Review Pool assignment  
Product implementation: not started and not owned by this package

This checklist is fixed before product implementation begins. Review must reject
the contract package if any binding item below is absent, ambiguous, inferred
from an implementation rather than specified, or weakened to match a schedule.

## Inputs and authority

- [ ] The accepted `env06_6` VOCABULARY SPECIFICATION is cited by exact document
  path and accepted commit.
- [ ] The `game06_1`, `craps06_3`, and `env06_6` prompts remain binding in full.
- [ ] Current `GameModule`, table visuals, surface canvas, Scratch Tickets, Coin
  Pusher, accessibility, save, and liveness seams are inventoried as constraints,
  not silently promoted into the new contract.
- [ ] Anything not settled by those authorities is called out as unresolved;
  no owner-locked design, economy, rules, or tuning value is guessed.

## Shared-vocabulary alignment

- [ ] The document defines a mapping to the accepted env06_6 vocabulary for
  commands, results, facts, operations, boundaries, receipts, and rejections.
- [ ] Stable identifier grammar, namespaces, ownership, and collision rules are
  explicit.
- [ ] Operation families use neutral names and generic verbs. Shared vocabulary
  contains no game-id or craps-specific branch, field, verb, actor, phase, target,
  payout, rule, or settlement assumption.
- [ ] Game ritual lifecycle remains distinct from scenario lifecycle where the
  semantics differ; reuse is by named primitives and mappings, not accidental
  coupling.
- [ ] Extension registries are bounded, allowlisted, deterministic, and reject
  arbitrary code, reflection targets, raw node paths, and unapproved resources.

## Versioned ritual definition

- [ ] A complete data shape is defined for schema version, ritual id, phases,
  transitions, permitted actions, staged commitments, pointer verbs, actors,
  scene objects, energy tiers, game facts, persistence, handlers, and declared
  targets.
- [ ] Stable phases have entry conditions, permitted action ids, explicit
  transition conditions, legal terminal states, and reachability rules.
- [ ] The state machine makes double commit, double settlement, out-of-phase
  action, charge-on-rejection, and stranded pending commitment structurally
  impossible.
- [ ] Place, correct, undo, remove-one, clear, repeat, re-bet, and confirm are
  distinct staged-commitment concepts; the contract does not require a game to
  support an action its rules forbid.
- [ ] Available funds, pending total, at-risk total, returned stake, payout, and
  per-item resolution have unambiguous accounting semantics without changing
  authoritative game math.
- [ ] Pointer verbs cover drag, hold, flick, place, and reveal using semantic
  regions and bounded design-space coordinates.
- [ ] Every rejection is side-effect-free: no charge, phase advance, fact,
  authoritative result change, or one-shot receipt.
- [ ] Every pointer verb declares keyboard, controller, and reduced-motion
  equivalents with identical authoritative outcomes and fair timing.

## Actors, objects, layout, and energy

- [ ] Actors have stable ids, authored semantic anchors, bounded poses, bounded
  behavior states, gaze/attention state, and action-boundary reactions to facts.
- [ ] Scene objects have stable semantic ids, visual and functional state,
  bounds, optional hit regions, z-order, and text-safety participation.
- [ ] Metadata-only actors or props are rejected.
- [ ] Semantic anchors/regions, coordinate space, bounds, reachability, z-order,
  text safety, small-screen behavior, touch targets, reduced motion, and
  colorblind distinguishability are fully specified and validated.
- [ ] Each energy tier changes at least one actor, object, or interactable state;
  music-only and text-only projection fails validation.

## Command/result and exactly-once behavior

- [ ] One authoritative command/result boundary validates ritual/phase,
  permitted action, semantic target, commitment preconditions, cost authority,
  receipt/fingerprint, and idempotency before mutation.
- [ ] Command, result, rejection, fact, operation, transition, and receipt shapes
  use the accepted shared vocabulary and specify required/optional fields.
- [ ] Identical receipt plus identical command returns the cached result; receipt
  reuse with a different fingerprint fails without mutation.
- [ ] Facts publish only at named safe action boundaries and are typed and
  versioned. Presentation never rerolls, reorders, or changes authoritative
  outcomes.
- [ ] Handlers declare allowlisted id, typed input, typed output, persistence,
  deterministic RNG ownership/consumption, side effects, and failure behavior.

## Persistence, restore, and compatibility

- [ ] The document separates authoritative serialized state, derived prepared
  projection, transient presentation state, and one-shot transition state.
- [ ] Restore reaches a legal phase without replaying reward, settlement,
  dialogue, audio, animation, fact publication, or any one-shot effect.
- [ ] Receipt and fingerprint retention, migration, unknown-field policy,
  version compatibility, and invalid-save behavior are explicit.
- [ ] Save, exit, and restore behavior is defined at every phase boundary.
- [ ] Adoption is opt-in. Every unadopted game preserves behavior and rendering;
  no shared default changes its command routing, surface state, or visuals.

## Performance and platform

- [ ] Phase advancement and fact publication occur only at action boundaries.
- [ ] No schema evaluation, scene reconstruction, state deep copy, or authority
  decision is introduced per frame.
- [ ] Existing animation-channel and liveness machinery is reused; no parallel
  scheduler is specified.
- [ ] Idle-liveness proof is mandatory and treats a measured `0.000` draw cost
  without advancing liveness evidence as failure.
- [ ] Identical seeds and input traces produce identical authoritative state and
  results on native and Web.

## Required validation-test evidence

- [ ] A data-only validation test loads the worked example and reports zero
  errors.
- [ ] Focused negative fixtures fail for malformed/unreachable phases, ambiguous
  or duplicate transitions, unbound actions, unbound pointer equivalents,
  charge-capable rejection paths, missing actor states, missing object bounds,
  metadata-only props, music/text-only energy, unsafe executable references,
  invalid ids/targets, receipt ambiguity, and persistence omissions.
- [ ] A static neutrality scan proves shared contract vocabulary and fixtures
  contain no craps id, special-case switch, or rules term.
- [ ] A consumer conformance matrix shows how ordinary casino craps, hot table,
  audit/security table, ordinary street circle, and interrupted street circle
  can be expressed without adding shared vocabulary. This is a specification
  proof, not a craps implementation.
- [ ] A Family 1 matrix shows blackjack, baccarat, roulette, machine games,
  counter games, bar dice, and the duel can each name phases, actors, objects,
  verbs, and persistence using only the contract and bounded extension points.
- [ ] The validation command, duration, exit code, and exact tested commit are
  recorded.

## Independent acceptance

- [ ] Reviewer is independent of this contract-authoring package and of later
  product implementation.
- [ ] Reviewer checks this list against the exact head and records every finding.
- [ ] Any rejection is remediated and re-reviewed; two rejections escalate to the
  program director.
- [ ] `game06_2` through `game06_7` begin only after this document and its
  validation test are independently accepted. They do not wait for a reference
  implementation to land.

## Binding fields currently unresolved pending the env06_6 specification

The structure above is intentionally nonbinding until the promised handoff
settles these exact fields:

1. canonical envelope names and required fields for command, result, fact,
   operation, boundary, receipt, and rejection;
2. stable-id grammar, namespaces, and ownership;
3. phase/transition condition vocabulary and exactly-once boundary semantics;
4. operation-family names, allowed generic verbs, and target/state fields;
5. actor/object/interactable state vocabularies and registry extension rules;
6. anchors, regions, bounds, z-order, and text-safety shapes;
7. persistence split and receipt/fingerprint replay policy;
8. safe-boundary fact types, payload typing, and versioning;
9. handler input/output/RNG/persistence contract;
10. rejection and validation-error taxonomy;
11. schema versioning, migration, and unknown-field policy;
12. cross-runtime mapping and separation rules;
13. equivalent-action and reduced-motion fields;
14. authority, privacy, and public-projection markers.

No implementation-derived value may fill these fields before the written
env06_6 vocabulary specification is accepted.
