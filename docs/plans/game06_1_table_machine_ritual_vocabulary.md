# game06_1 Table and Machine Ritual Vocabulary

Status: contract draft; product implementation is forbidden until independent acceptance  
Contract version: `game_ritual/1`  
Checklist: `docs/plans/game06_1_ritual_contract_acceptance_checklist.md`

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

1. accepted env06_6 VOCABULARY SPECIFICATION for cross-runtime primitives;
2. `game06_1_table_machine_ritual_runtime_prompt.md`;
3. `craps06_3_craps_depth_rework_prompt.md` as a required conformance consumer;
4. current production seams where they do not contradict the authorities above.

The env06_6 vocabulary handoff has not yet been supplied. Section 13 enumerates
the fields that remain deliberately unresolved. No value observed in the
env06_6 implementation is binding until it appears in the accepted handoff.

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

All ids are stable lowercase semantic ids. The exact grammar, namespace
separator, cross-runtime ownership rules, and collision behavior are pending
`ENV-VOCAB-02`. Until resolved, examples in this document are illustrative and
must not be copied into production as an id parser.

References must resolve within the definition or an explicitly declared,
allowlisted registry. Display labels are not ids and may change without save
migration.

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

The canonical condition and operation envelope names remain pending
`ENV-VOCAB-01`, `ENV-VOCAB-03`, and `ENV-VOCAB-04`.

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
taxonomy remain pending `ENV-VOCAB-06`, `ENV-VOCAB-10`, and `ENV-VOCAB-13`.

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
Exact common shapes remain pending `ENV-VOCAB-05` and `ENV-VOCAB-06`.

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
markers, and receipt semantics remain pending `ENV-VOCAB-01`, `ENV-VOCAB-07`,
`ENV-VOCAB-08`, and `ENV-VOCAB-14`.

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

Canonical field names and error codes remain pending `ENV-VOCAB-01`,
`ENV-VOCAB-07`, and `ENV-VOCAB-10`.

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
unallowlisted resources in authored data. The binding handler shape remains
pending `ENV-VOCAB-09`.

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
invalid-save behavior remain pending `ENV-VOCAB-07` and `ENV-VOCAB-11`.

## 13. Cross-runtime mapping (pending env06_6 handoff)

Game rituals and environment scenarios share primitives but not lifecycle
ownership. A game ritual owns game phases and game commitments. A scenario owns
room objectives, reentry/expiry, and aftermath. Neither directly mutates the
other. They communicate through typed facts and declared operations at safe
boundaries. The normative separation and mapping rules remain pending
`ENV-VOCAB-12`.

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

These mappings are unresolved, not implementation gaps. The accepted env06_6
specification must settle all fourteen fields listed in the checklist before
this document can become accepted and before Family 1 product implementation
starts.

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

The error-code namespace and canonical rejection records remain pending
`ENV-VOCAB-10`.

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
