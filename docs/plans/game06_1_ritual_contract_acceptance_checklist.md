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

## Frozen env06_6 mapping ledger

Normative source: commit `749390ce`,
`D:\bth-env6\docs\todo\env06_6_runtime_vocabulary_and_delivery_handoff.md`.
The reviewer must verify all fourteen mappings against that exact source:

1. `ENV-VOCAB-01` — closed command, result, rejection, fact, operation, and
   receipt envelopes: contract §3.2;
2. `ENV-VOCAB-02` — local/qualified id grammar, namespace ownership, sealed
   host references, and collision rejection: contract §3.1;
3. `ENV-VOCAB-03` — durable boundary/cause vocabulary and exactly-once
   semantics: contract §3.3;
4. `ENV-VOCAB-04` — closed condition kinds and the four generic operation
   families/verb allowlists: contract §3.4;
5. `ENV-VOCAB-05` — bounded actor/object/interaction states, owned creation,
   sealed host authority, and tombstones: contract §3.5;
6. `ENV-VOCAB-06` — semantic anchors/zones, design-space rectangles, layout,
   reachability, z-order, text safety, and fail-closed projection: contract §3.6;
7. `ENV-VOCAB-07` — receipts, canonical fingerprints, replay conflict, atomic
   failure, and persistence: contract §3.3/12;
8. `ENV-VOCAB-08` — public typed versioned action-boundary facts: contract §3.7;
9. `ENV-VOCAB-09` — closed handler I/O, authority, persistence, RNG, emissions,
   and transactional behavior: contract §3.7;
10. `ENV-VOCAB-10` — closed rejection/error taxonomy and side-effect-free
    records: contract §3.8;
11. `ENV-VOCAB-11` — strict versions, unknown-field rejection, authenticated
    migration, and invalid-restore behavior: contract §3.9;
12. `ENV-VOCAB-12` — facts/operations-only cross-runtime mapping with no import
    of scenario lifecycle: contract §13;
13. `ENV-VOCAB-13` — keyboard/controller/reduced-motion equivalent-action
    shapes and invariant outcomes: contract §3.8;
14. `ENV-VOCAB-14` — private-by-default authority, reveal boundaries, closed
    public projections, and authenticated actions: contract §3.9.

No value in this ledger was harvested from product implementation. Independent
review must still reject any mapping that weakens the normative handoff or
imports scenario objectives, reentry, expiry, cleanup, aftermath, route
authority, or command-entry world-boundary grace into game ritual lifecycle.
