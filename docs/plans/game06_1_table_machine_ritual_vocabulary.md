# game06_1 Table and Machine Ritual Vocabulary

Status: contract candidate; product implementation is forbidden until independent acceptance
Contract version: `game_ritual/1`  
Checklist: `docs/plans/game06_1_ritual_contract_acceptance_checklist.md`
Normative shared-vocabulary source: `749390ce`,
`D:\bth-env6\docs\todo\env06_6_runtime_vocabulary_and_delivery_handoff.md`

## 1. Purpose and authority

This contract lets a game describe a played ritual without teaching shared code
the rules of any particular game. It is a vocabulary for phases, committed
actions, semantic regions, actors, objects, energy, facts, and restore behavior.
It does not own authoritative outcomes, wager math, payouts, odds, tuning, or
game-specific content.

The contract is written before the reference ritual lands so Family 1 consumers
can implement in parallel after independent contract acceptance. A consumer may
add content and register bounded handlers, but it may not add a game-id branch to
shared ritual code.

The binding authorities are, in order:

1. env06_6 runtime vocabulary handoff at exact accepted commit `749390ce` for
   cross-runtime primitives;
2. `game06_1_table_machine_ritual_runtime_prompt.md`;
3. `craps06_3_craps_depth_rework_prompt.md` as a required conformance consumer;
4. current production seams where they do not contradict the authorities above.

The env06_6 vocabulary handoff defines behavior rather than filenames or a
preferred implementation. Sections 3.1–3.9 and 13 freeze the game-side closed
records and mappings derived from that behavior. Product implementation remains
outside this contract-authoring package.

## 2. Non-negotiable invariants

- Authoritative results remain seeded, rules-owned, and unchanged by ritual
  presentation.
- Commands advance at explicit action boundaries, never from wall-clock time.
- A rejected verb never charges, advances, publishes a fact, consumes RNG, or
  creates a one-shot receipt.
- One authoritative result settles at most once. Restore never replays money,
  rewards, facts, dialogue, audio, or one-shot staging.
- Stable semantic ids address actors, objects, and regions. Raw node paths and
  screen coordinates are not authority.
- Every pointer verb has keyboard, controller, and reduced-motion equivalents
  with identical authoritative outcomes and fair timing.
- An energy tier changes an actor, object, or interactable. Music or text alone
  is invalid.
- Adoption is opt-in. An unadopted game retains its previous state, commands,
  rendering, and input behavior.
- Shared vocabulary contains no game id, game rule, payout name, or
  game-specific branch.
- Nothing new performs schema work, authority decisions, scene reconstruction,
  or deep copies every frame.

## 3. Definition shape

A ritual definition is immutable, versioned data owned by one game module.
The normative JSON-like shape is:

```json
{
  "contract": "game_ritual/1",
  "ritual_id": "example_table.standard_session",
  "initial_phase": "open",
  "ritual_phases": [],
  "staged_commitment": {},
  "pointer_verbs": [],
  "actors": [],
  "scene_objects": [],
  "energy": {},
  "game_facts": [],
  "ritual_persistence": {},
  "handler_registry": [],
  "declared_targets": {}
}
```

Unknown top-level fields fail validation. Definitions and runtime records have
separate schemas; mutable state must never be written back into a definition.

### 3.1 Identifier rules

All ids are stable lowercase semantic ids. A local id is one atom matching
`^[a-z][a-z0-9_]{0,63}$`. A qualified id contains two or more local-id atoms
joined by `.` and is at most 192 characters. Definitions own their local phase,
transition, actor, object, region, action, and handler namespaces. Cross-runtime
references use qualified ids and must resolve through declared targets or an
exact sealed host inventory bound to the current room and layer. A catalog id or
caller string is never evidence that a live identity exists. Duplicate ids,
cross-kind collisions inside one definition, ambiguous references, and unsealed
host references reject. This resolves `ENV-VOCAB-02`.

References must resolve within the definition or an explicitly declared,
allowlisted registry. Display labels are not ids and may change without save
migration.

### 3.2 Closed envelopes (`ENV-VOCAB-01`)

Every runtime record is a closed dictionary. Unknown fields, missing required
fields, wrong types, noncanonical ids, unsafe strings, and over-limit arrays
reject before mutation. The shared game envelopes are:

```text
RitualCommand {
  envelope_version, ritual_id, session_id, command_id, action_id,
  expected_phase, source_id, target_id, parameters,
  authenticated_action, boundary, receipt_key, content_fingerprint
}
RitualResult {
  envelope_version, ok=true, ritual_id, session_id, command_id,
  phase_before, phase_after, authoritative_result_ref,
  state_receipts, operation_receipts, fact_receipts,
  boundary, receipt_key, content_fingerprint, public_projection
}
RitualRejection {
  envelope_version, ok=false, ritual_id, session_id, command_id,
  phase, error_code, public_message, retryable, return_policy,
  boundary, receipt_key, content_fingerprint, public_projection
}
GameFact {
  envelope_version, fact_id, fact_type, fact_version, payload,
  visibility=public, boundary, receipt_key, content_fingerprint
}
RitualOperation {
  envelope_version, operation_id, family, verb, source_owner_id,
  target_id, arguments
}
OperationResult {
  envelope_version, operation_id, family, verb, target_id,
  boundary, receipt_key, content_fingerprint, applied
}
ReceiptRecord {
  receipt_key, content_fingerprint, boundary_id, envelope_kind, status
}
```

`authenticated_action` is the current live resolved action descriptor obtained
from trusted surface state. It includes origin owner/stable identity, operation
receipt, boundary id, and fingerprint. Caller-supplied origin fields are compared
to that record and never establish authority. `parameters` and `payload` are
closed against the declared action/fact schema. `public_projection` contains
only allowlisted public fields and never durable authority.

### 3.3 Boundary, cause, receipt, and replay (`ENV-VOCAB-03/07`)

The game boundary record is:

```text
RitualBoundary {
  boundary_id, kind, ritual_id, session_id, phase_id, ordinal,
  cause_receipt_key
}
```

`kind` is one of `phase_entry`, `fact_flush`, `command`, `cleanup`, or
`aftermath_application`. The last two exist only for game-session teardown and a
game's already-authoritative terminal material result; they do not import
scenario cleanup or scenario aftermath lifecycle. `ordinal` is a durable,
monotonic session counter advanced only by an accepted authoritative boundary.

A cause is exactly one accepted `RitualCommand` or `GameFact`. Its receipt key
and fingerprint are copied into the boundary. A receipt key is path-safe lower
ASCII matching `^[a-z0-9][a-z0-9_.:-]{0,191}$`. A content fingerprint is the
lowercase 64-hex SHA-256 of the canonical closed envelope excluding the
fingerprint field. Canonicalization sorts dictionary keys, preserves authored
array order, uses explicit integer/boolean/string types, and forbids NaN,
infinity, resources, objects, and executable values.

The exact same receipt key plus fingerprint returns the cached result. The same
receipt key with different canonical content returns
`receipt_content_conflict` without mutation. Rejected ingress does not advance
the boundary ordinal and creates no accepted operation/fact/transition receipt.
Atomic failure preserves authoritative pre-state except a separately declared
bounded rejected-ingress diagnostic that is never game authority.

### 3.4 Conditions and operation families (`ENV-VOCAB-04`)

Condition records are closed and use exactly one `kind`:

- `accepted_action` — matches one action id in the current command cause;
- `fact` — matches one declared public fact type and closed payload predicate;
- `receipt_present` — matches one exact receipt kind/key/fingerprint;
- `authoritative_result_present` — matches a trusted game-owned result ref;
- `public_state_equals` — matches an allowlisted public state key/value.

Conditions cannot inspect private state, hidden outcomes, wall-clock time,
frame count, raw input paths, or renderer geometry. Branches are evaluated in
authored order; more than one matching transition at one boundary is an
`ambiguous_transition` validation failure.

The shared operation families and generic verbs are:

- `scene_ops`: `spawn`, `replace`, `remove`, `move`, `set_position`,
  `set_visibility`, `set_enabled`, `set_state`, `set_appearance`;
- `interaction_ops`: `add`, `remove`, `replace`, `gate`, `augment`, `retarget`;
- `actor_ops`: `spawn`, `despawn`, `replace`, `set_position`, `set_route`,
  `set_pose`, `set_behavior`;
- `transition_ops`: `feedback`, `stage`, `sound`, `music`, `scene_change`.

Every authored operation has `operation_id`, `family`, `verb`,
`source_owner_id`, `target_id`, and closed `arguments`. An operation registry
binds each family/verb to an input schema, output schema, target kind, creation
or existing-target rule, and atomic apply behavior. A definition cannot invent
a verb. No family or verb selects a game id or rules path.

`interaction_ops.augment` contributes actions to the authoritative target; its
source overlay never becomes an independent host action. Arbitration is stable
owner-priority order and fails closed on ambiguous winners, cycles, spoofed
origins, unavailable hosts, or lower-priority override attempts.

### 3.5 Actor, object, and interaction state (`ENV-VOCAB-05`)

Actor, object, and interaction state sets are bounded arrays declared by the
owning definition. Initial states must belong to those sets. Operations may set
only a declared state. Shared code understands identity, family, state slot,
anchor, and bounds; the meaning of a content state remains game-owned.

Spawn/add creates a live identity only when the definition owns that identity.
A modifier cannot manufacture a missing host identity. A host-owned target must
resolve through a sealed immutable inventory bound to the exact surface,
room/layer context, source provenance, and digest. Unknown, ambiguous, stale,
cross-context, or unsealed targets reject. Removal creates a replay-safe
tombstone owned by the same source and cannot erase unrelated host state.

Actor persistent semantics are identity, bounded pose/behavior, and authored
route/anchor request. Resolved points, collision adjustments, z-order, and
motion staging are derived. Object persistent semantics are identity, bounded
visual/functional state, and authored anchor request. Hit geometry is derived
from validated layout authority.

### 3.6 Anchors, regions, bounds, and layout (`ENV-VOCAB-06`)

An anchor is a qualified semantic id resolved from the definition or exact
sealed host inventory. A zone is an anchor plus a closed design-space rectangle
and optional bounded placement policy. A rectangle is
`{space="design", x:int, y:int, w:int, h:int}` with positive `w/h`; values must
fall inside the declared design canvas. Runtime screen coordinates never enter
authority.

Interactive regions additionally declare `region_id`, `owner_id`,
`minimum_touch_target`, `z_layer`, `enabled`, `reachable`, and optional
`text_safety_regions`. The layout resolver consumes validated final base records
and the successful sealed semantic result exactly once. It checks bounds,
reachability, overlap/arbitration, z-order, protected text, small-screen policy,
reduced motion, touch size, and color-independent distinguishability.
Presentation geometry is derived, not persisted.

If layout or renderer preparation fails, the public ritual presentation fails
closed: actor/object/interaction/hit-region/active-stage collections are empty;
typed errors and safe non-content metadata may remain. Partial or hidden payload
must not escape.

### 3.7 Facts and handlers (`ENV-VOCAB-08/09`)

Every fact declaration freezes a qualified `fact_type`, positive
`fact_version`, closed typed payload schema, `boundary=action`, and
`visibility=public`. A publisher produces `GameFact` only after its authoritative
boundary commits. Facts cannot expose hidden/revealed-later state, reducer
journals, inventory seals/digests, private actor state, future outcomes, or
unrevealed results. Consumers respond at their own next safe boundary.

Every handler registry entry freezes `handler_id`, positive version, permitted
actions/operations, closed typed/bounded input, closed typed/bounded output,
field authority, persisted state, transient state, emitted facts/operations,
rejection behavior, and retry policy. RNG is either `none` or names a trusted
game-rules stream plus a fixed action-boundary consumption rule. Handler data
cannot contain scripts, classes, reflection targets, raw node paths, executable
strings, or unallowlisted resources. Handler mutation, transition, fact
publication, and receipts commit transactionally.

### 3.8 Rejection taxonomy and equivalent actions (`ENV-VOCAB-10/13`)

`error_code` is one of:

`invalid_envelope`, `unsupported_version`, `invalid_id`, `unknown_reference`,
`stale_phase`, `action_not_permitted`, `disabled_action`, `blocked_action`,
`unavailable_source`, `unavailable_target`, `unsealed_authority`,
`authority_mismatch`, `ambiguous_target`, `invalid_parameters`,
`incomplete_gesture`, `out_of_bounds`, `inaccessible_target`,
`precondition_failed`, `insufficient_funds`, `receipt_content_conflict`,
`handler_rejected`, `invalid_restore`, `ambiguous_transition`, or
`internal_fail_closed`.

A `RitualRejection` always has `ok=false`, the current legal phase, a safe public
message, `retryable`, and `return_policy` (`none`, `return_to_source`, or
`restore_focus`). It has no authoritative result ref and empty public mutation
collections. Gesture errors always return without charge, phase advance, RNG,
facts, or accepted receipts.

Every pointer verb's `equivalents` is closed and contains:

- `keyboard`: `{action_id, target_selection}`;
- `controller`: `{action_id, target_selection}`;
- `reduced_motion`: `{action_id, target_selection, staging}`.

All three use the same semantic action/target validation and authoritative
handler as the pointer path. `target_selection` is `focus`, `cycle`, or
`direct_semantic`; `staging` is `instant`, `short`, or `authored_text`. Reduced
motion may change only presentation staging, never outcome, action availability,
receipt order, or durable duration-boundary semantics.

### 3.9 Versioning, migration, and projection (`ENV-VOCAB-11/14`)

Definitions use exact `contract=game_ritual/1`; envelopes use
`envelope_version=1`; facts and handlers carry their own positive versions.
Unknown definition/envelope fields reject. A newer major version requires an
explicit validator and migration. Migration may reconstruct authority only from
already durable authenticated records and matching fingerprints; it cannot use
caller assertions, catalog possibility, renderer snapshots, or projection data.
Invalid or ambiguous migration returns `invalid_restore` and preserves the
pre-migration save.

Persistent state is private authority unless a schema field is explicitly
marked `public`. `secret_until_reveal` is private until an authoritative reveal
boundary emits a public value. Public projections are freshly derived from
validated persistent authority using a closed allowlist. Consumers use only the
public projection and authenticated action descriptors; private local state,
hidden results, journals, tombstones, seals/digests, and fingerprints are never
presentation or gameplay shortcuts.

## 4. Ritual phases and transitions

`ritual_phases` is a nonempty array of records:

```json
{
  "id": "open",
  "entry_conditions": [],
  "permitted_actions": ["commit.place", "commit.correct", "commit.confirm"],
  "entry_operations": [],
  "transitions": [
    {
      "id": "open_to_committed",
      "condition": {"kind": "accepted_action", "action_id": "commit.confirm"},
      "next_phase": "committed",
      "operations": []
    }
  ],
  "terminal": false
}
```

Requirements:

- `initial_phase` resolves to exactly one phase.
- Phase ids and transition ids are unique and stable.
- Every nonterminal phase is reachable and has a reachable exit.
- Every transition has exactly one trigger condition and one next phase or
  terminal result.
- Ambiguous transitions from the same state and boundary fail validation.
- `permitted_actions` is an allowlist; absence means denial.
- Entry operations are prepared and receipted once per phase entry.
- An action not permitted by the current phase returns a typed rejection.
- Committed and settled are distinct authority states. No input trace can enter
  settlement twice for one authoritative result.

Canonical conditions, boundaries, causes, and operation envelopes are frozen in
Sections 3.2–3.5, resolving `ENV-VOCAB-01`, `ENV-VOCAB-03`, and
`ENV-VOCAB-04`.

## 5. Staged commitment

`staged_commitment` describes a pending set separately from at-risk working
items and settled resolutions:

```json
{
  "pending_collection": "pending_items",
  "working_collection": "working_items",
  "resolution_collection": "item_resolutions",
  "funds_authority": "game_rules",
  "actions": [
    {"id": "commit.place", "effect": "add_or_increment_one"},
    {"id": "commit.correct", "effect": "replace_one_pending_amount"},
    {"id": "commit.remove", "effect": "remove_one_pending_item"},
    {"id": "commit.undo", "effect": "reverse_last_pending_edit"},
    {"id": "commit.clear", "effect": "remove_all_pending_items"},
    {"id": "commit.repeat", "effect": "copy_last_eligible_commitment"},
    {"id": "commit.rebet", "effect": "copy_eligible_resolved_items"},
    {"id": "commit.confirm", "effect": "authorize_pending_set"}
  ],
  "readable_totals": [
    "available_funds", "pending_total", "at_risk_total",
    "returned_stake", "payout", "net_change"
  ]
}
```

These are semantic capabilities, not mandatory game rules. A definition lists
only actions that its authoritative rules support. Unsupported actions reject
as unavailable; they are never emulated by changing rules.

Each pending item has a stable item id, semantic target id, denomination/amount,
source, edit ordinal, eligibility, and disabled reason. Each resolution names
the item id, authoritative result id, stake disposition, returned stake, payout,
net change, and public explanation. The authoritative game module computes all
amounts and validates conservation; ritual code only stages and projects them.

`clear` may remove the whole pending set, but it is never the only correction
path. `remove` or `correct` must address one pending item. Confirm is idempotent
under a stable receipt and may not silently confirm an empty or illegal set.

## 6. Pointer verbs and equivalent actions

`pointer_verbs` binds a generic gesture to semantic regions:

```json
{
  "id": "place_primary",
  "verb": "place",
  "source_region": "player.reserve",
  "target_regions": ["layout.primary"],
  "bounds": {"space": "design", "min_distance": 0, "max_distance": 320},
  "phases": ["open"],
  "accepted_action": "commit.place",
  "rejection": "return_to_source",
  "equivalents": {
    "keyboard": {"action": "commit.place", "target_selection": "focus"},
    "controller": {"action": "commit.place", "target_selection": "focus"},
    "reduced_motion": {"action": "commit.place", "travel": "instant"}
  }
}
```

The five registered gesture classes are `drag`, `hold`, `flick`, `place`, and
`reveal`. A definition may omit any class it does not need. A bounded extension
requires a new contract version or an allowlisted handler whose behavior can be
expressed using an existing class.

Pointer sampling may be presentation input, but authority receives a normalized
semantic command: verb id, source id, target id, bounded normalized parameters,
current phase, and receipt. Screen-space paths, event timestamps, and frame count
must not influence authoritative outcomes.

Incomplete, out-of-bounds, blocked, wrong-phase, inaccessible, or otherwise
invalid gestures return a rejection and stage a harmless return. Rejection
cannot consume funds, RNG, phase progress, facts, or one-shot operations.

The binding coordinate/bounds shape, equivalent-action fields, and rejection
taxonomy are frozen in Sections 3.6, 3.8, and 6, resolving `ENV-VOCAB-06`,
`ENV-VOCAB-10`, and `ENV-VOCAB-13`.

## 7. Actors and scene objects

### 7.1 Actors

Actor records are addressable scene participants:

```json
{
  "id": "staff.primary",
  "role": "staff",
  "anchor": "station.primary",
  "poses": ["idle", "offer", "attend", "resolve"],
  "behavior_states": ["idle", "working", "watching", "reacting"],
  "initial_pose": "idle",
  "initial_behavior": "idle",
  "fact_reactions": []
}
```

Roles include dealers, staff, opponents, neighbours, and onlookers. Role is
descriptive; it never selects game rules. Poses and behavior states are bounded
per definition. Actors react to typed game facts at safe boundaries, never to
frame counts. Gaze and attention are ordinary bounded states, not special shared
branches.

### 7.2 Scene objects

Scene-object records describe real rendered/functional objects:

```json
{
  "id": "apparatus.primary",
  "anchor": "layout.center",
  "bounds": {"space": "design", "x": 280, "y": 90, "w": 340, "h": 180},
  "z_layer": "gameplay",
  "visual_states": ["idle", "active", "resolved"],
  "functional_states": ["enabled", "blocked"],
  "initial_visual_state": "idle",
  "initial_functional_state": "enabled",
  "hit_regions": [],
  "text_safety_regions": []
}
```

An actor or object that produces only metadata fails. Its state must affect the
prepared render model, a hit region, a functional route, or an interactable.

The layout validator checks bounds, semantic-anchor resolution, interactive
reachability, z-order, protected text regions, minimum touch targets,
small-screen layout, reduced-motion state, and non-color-only distinguishability.
The common bounded-state and layout shapes are frozen in Sections 3.5 and 3.6,
resolving `ENV-VOCAB-05` and `ENV-VOCAB-06`.

## 8. Energy

`energy` is a per-definition tier projection:

```json
{
  "initial_tier": "quiet",
  "tiers": [
    {
      "id": "quiet",
      "actor_operations": [],
      "object_operations": [{"target": "apparatus.primary", "state": "idle"}],
      "interaction_operations": [],
      "audio_cues": []
    },
    {
      "id": "engaged",
      "actor_operations": [{"target": "staff.primary", "behavior": "watching"}],
      "object_operations": [],
      "interaction_operations": [],
      "audio_cues": []
    }
  ]
}
```

Every tier must materially differ from at least one other tier through an actor,
object, or interactable state. Audio, music, tint, labels, and flavor text may
supplement that change but cannot satisfy it. Tier changes apply at safe action
boundaries and must be deterministic from authoritative state/facts.

## 9. Typed game facts

`game_facts` declares facts a game may publish:

- round/session start;
- commitment accepted;
- authoritative resolution;
- streak tier changed;
- large swing;
- cheat attempt;
- cheat result;
- attention or heat changed;
- session end.

Each declaration names a stable type, version, typed public payload, safe
publication boundary, visibility, and privacy classification. Payloads expose no
hidden outcome, future result, private actor state, or unrevealed information.

Facts are notifications, not direct mutation access. Consumers respond at their
next safe boundary. A fact receipt prevents duplicate publication across retry,
save/load, and revisit. Canonical fact envelopes, payload typing, visibility
markers, and receipt semantics are frozen in Sections 3.2, 3.3, 3.7, and 3.9,
resolving `ENV-VOCAB-01`, `ENV-VOCAB-07`, `ENV-VOCAB-08`, and
`ENV-VOCAB-14`.

## 10. Command/result boundary

One authoritative boundary receives a normalized ritual command and either
returns an accepted result or a typed rejection. Its validation order is:

1. contract and ritual id/version;
2. command and receipt identity;
3. expected current phase;
4. action permitted in the phase;
5. semantic source/target availability and reachability;
6. game-owned preconditions and cost authorization;
7. idempotency/fingerprint check;
8. authoritative mutation;
9. result, transition, operation, and fact receipt production.

An identical receipt and identical canonical command returns the cached result.
Receipt reuse with a different fingerprint rejects without mutation. Validation
and rejection are deterministic and consume no game RNG. Complex behavior is an
allowlisted handler, not an arbitrary target string.

Canonical field names, receipts, fingerprints, and error codes are frozen in
Sections 3.2, 3.3, and 3.8, resolving `ENV-VOCAB-01`, `ENV-VOCAB-07`, and
`ENV-VOCAB-10`.

## 11. Handler registry

Each `handler_registry` entry declares:

- stable allowlisted handler id and version;
- accepted action/operation ids;
- typed and bounded input;
- typed and bounded output;
- authoritative owner of each mutated field;
- persisted state and transient state;
- deterministic RNG source, stream, and fixed consumption rule, or `none`;
- emitted fact types and operations;
- rejection behavior and whether retry is legal.

Handlers cannot name scripts, classes, reflection targets, raw nodes, or
unallowlisted resources in authored data. Section 3.7 freezes the binding
handler shape, resolving `ENV-VOCAB-09`.

## 12. Ritual persistence and restore

`ritual_persistence` divides state into four classes:

1. **authoritative serialized** — ritual version/id, legal phase, pending and
   working item identities, authoritative result references, actor/object state,
   energy tier, handler state, and all receipts/fingerprints required for replay;
2. **derived prepared projection** — layout and visual records rebuilt from
   authoritative state without side effects;
3. **transient presentation** — pointer path, hover, focus animation progress,
   and other state safe to discard;
4. **one-shot receipted presentation** — transition/audio/dialogue cues that may
   resume visually under policy but never replay consequences.

Restore normalizes/migrates the record, validates references, selects the saved
legal phase or a specified recovery phase, rebuilds projection, and suppresses
already-receipted effects. Save may occur at every action boundary. A mid-motion
save restores according to the declared boundary policy without rerolling or
charging.

Unknown fields, version migration, receipt retention, fingerprinting, and
invalid-save behavior are frozen in Sections 3.3 and 3.9, resolving
`ENV-VOCAB-07` and `ENV-VOCAB-11`.

## 13. Cross-runtime mapping

Game rituals and environment scenarios share primitives but not lifecycle
ownership. A game ritual owns game phases and game commitments. A scenario owns
room objectives, reentry/expiry, and aftermath. Neither directly mutates the
other. They communicate through typed facts and declared operations at safe
boundaries. This strict separation resolves `ENV-VOCAB-12`.

The final contract must contain a normative mapping table for:

| Game concept | Shared primitive needed | Binding source |
| --- | --- | --- |
| normalized action | command envelope | `ENV-VOCAB-01` |
| accepted action response | result envelope | `ENV-VOCAB-01` |
| invalid gesture/action | rejection envelope/taxonomy | `ENV-VOCAB-01/10` |
| stable phase transition | boundary + condition + receipt | `ENV-VOCAB-03/07` |
| actor/object/interactable change | registered operation | `ENV-VOCAB-04/05` |
| semantic input region | anchor/region/bounds | `ENV-VOCAB-06` |
| outward notification | typed fact | `ENV-VOCAB-08/14` |
| complex deterministic behavior | registered handler | `ENV-VOCAB-09` |
| replay protection | receipt + fingerprint | `ENV-VOCAB-07` |
| accessible alternate input | equivalent action | `ENV-VOCAB-13` |

These mappings are frozen against the normative behavior in handoff `749390ce`.
They do not import scenario objectives, reentry, expiry, cleanup, aftermath,
room-route authority, or command-entry world-boundary grace into the game ritual
lifecycle. Family 1 product implementation starts only after independent review
accepts this exact contract and its validation test.

## 14. Worked neutral example

The normative worked example is
`scripts/tests/fixtures/game_ritual_vocabulary_v1.json`. It describes a neutral
table ritual with an open commitment phase, a bounded place gesture, a committed
action, an authoritative resolution phase, staff/object reactions, two material
energy tiers, typed facts, and legal restore boundaries.

The example is deliberately not an implementation of a shipped game. It proves
that shared vocabulary can express the required structure without importing a
rules engine or a game-specific branch.

## 15. Consumer conformance

Acceptance requires specification-only conformance matrices for:

- ordinary staffed table ritual;
- high-energy table ritual;
- security-attention table ritual;
- ordinary informal/street ritual;
- interrupted/relocated informal ritual;
- blackjack;
- baccarat;
- roulette;
- machine games;
- counter games;
- bar dice;
- the showdown duel.

Each matrix names only definition content: phases, semantic actors/objects,
generic verbs, facts, persistence points, and registered handlers. If any
consumer needs a new shared game-id branch, the contract is rejected and must be
redesigned before implementation.

## 16. Validation errors

The validation test must fail loudly for at least:

- unsupported contract version or unknown field;
- invalid, duplicate, or unresolved id;
- missing or unreachable initial/nonterminal phase;
- ambiguous transition or transition to a missing phase;
- action permitted nowhere or transition action not permitted in its phase;
- staged commitment without single-item correction/removal;
- unbound pointer verb, region, phase, action, or equivalent path;
- pointer rejection capable of authoritative side effects;
- actor without bounded poses/behavior states/anchor;
- object without bounds/state or with metadata-only projection;
- unreachable/overlapping interactive region or unsafe layout;
- music/text-only energy tier;
- fact with unknown/untyped/private-leaking payload;
- arbitrary code, reflection, script, raw node path, or unsafe resource string;
- handler without explicit I/O, authority, persistence, and RNG contract;
- persistence without legal phase/result/receipt recovery;
- receipt ambiguity or fingerprint mismatch policy omission;
- a game-specific identifier or branch in shared vocabulary.

Section 3.8 freezes the error-code namespace and canonical rejection record,
resolving `ENV-VOCAB-10`.

## 17. Implementation obligations after acceptance

The later implementation squad, not this contract-authoring package, must:

- implement the versioned validator and runtime;
- extend shared visuals/canvas with opt-in actor/object/layout support;
- reuse existing animation-channel and liveness machinery;
- prove no behavior/render change for every unadopted game;
- re-express the accepted reference ritual without a shared special case;
- run full rules/RTP, determinism, native/Web, performance, accessibility,
  save/restore, and visual gates.

Contract acceptance authorizes that work; this document does not claim that any
product runtime or reference ritual has been implemented.
