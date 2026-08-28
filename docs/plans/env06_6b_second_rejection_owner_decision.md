# env06_6b second-rejection owner decision

Status: **UNREVIEWED / docs-only / option-neutral**

Packet base: GREEN main
`00ee744fa6269e8a7eb34f67b2659f32d55febaa`

Decision scope: three independent authority choices left by the second review
of env06_6b: live availability, transaction rollback, and save-byte authority.
This packet does not select or recommend a combination, edit product or board
files, restart Smoke, or claim acceptance.

## Owner response required

Select one value on each independent axis and record the triple:

- availability: `V1`, `V2`, or `V3`;
- rollback: `R1`, `R2`, or `R3`; and
- save authority: `S1`, `S2`, or `S3`.

For example, `V1-R2-S1` is a complete response. It is only an example of the
syntax, not a preferred combination. All 27 combinations are listed below so
no omitted axis is inferred from another answer.

## Binding evidence and exclusions

| Artifact | Immutable identity | Binding fact |
| --- | --- | --- |
| Full prompt | `docs/todo/env06_6_dynamic_scenario_runtime_prompt.md`, blob `2f604ce121818af394e4e9636dc48b1a7d982448` | Requires shared runtime authority, transactional rejection, exact save/load at every phase and branch boundary, all 55 legacy migrations, no-sequence byte/behavior compatibility, no hidden authority leak, and Native/Web parity |
| First rejected integration | `9ea61fb8fe6c7e70a6c5db60829c28680ce2e92c`, tree `23234c2cd22a6da66c3095826036eb0b790fa50f` | Preserved first env06_6b integration; its retained gate remained red across lifecycle, rollback, save, catalog, and projection classes |
| Second-rejected product | `e297ca8f8aeec9512e2e8e899128ea4831082020`, tree `71a61ae02bc6606a14a855c8f60c6d46bbedea17` | Frozen after second rejection; exact net over `9ea61fb8` is `8 files, +176/-51`; no third ordinary product/review cycle is authorized |
| Second-review escalation | `58a362c84b161616ba8f785c37ed2d4783c954d2` | Records three P1s: caller availability grants augment authority; rollback aliases mutable NumbersModel/TownState objects; save restore lacks a durable sealed semantic root |
| Existing save decision packet | `3861e8efbaf63ec7f4d096a1a740c5f88a3ab57b` on `codex/env06_6b-save-byte-owner-decision` | Option-neutral evidence defining the closed root, semantic-equivalence, compatibility-exception choices, 16+3 matrix, SaveService caveat, migrations, hostile cases, and downstream inheritance |
| Former-lane consequence audit | Written handoff received after second review; incorporated in sections V, R, S, cross-axis cases, and downstream holds | Requires independent axes, exact alias/legacy consequences, no synthesis, and no dependent intake before all three selections are implementable together |

An empty marker is explicitly excluded. A zero-tree marker, empty commit,
claim-only head, branch label, or board status is not product, review, gate, or
decision evidence and is not an alternative product base. Only the exact
`e297ca8f` tree and the immutable evidence above are bound here.

## Second-review findings

### P1-V: caller availability can grant external augment authority

At `e297ca8f`, `RunState.scenario_sequence_command()` accepts a
`host_interaction_availability` dictionary. FoundationMain builds that map from
its composed interactable presentation list and passes it to the runtime. For
an augment or an external owner target, runtime code treats a caller map entry
whose value is `true` as proof that the addressed host interaction is enabled.

The action-origin envelope and authored augment still receive checks, but the
boolean that turns the external target on comes from the presentation caller,
not from the sealed `current_environment` base-interaction authority. A stale,
forged, duplicated, relabeled, or independently composed presentation record
can therefore grant rather than merely describe availability.

### P1-R: rollback does not close the mutable object graph

Environment-turn rollback serializes a RunState snapshot and separately copies
the environment/map/room dictionaries. Failure paths restore through
`from_dict()` and then replace selected roots. `NumbersModel` and `TownState`
are mutable objects referenced by other live consumers. Reconstructing or
replacing their values does not prove that every alias observed the same
transaction, and replacing an object can leave an external alias pointing at
the mutated pre-rollback instance.

The acceptance rule is stronger than equal JSON at one root. A rejected turn
must leave the complete authoritative graph equal, including object identities
where consumers retain them, nested model values, RNG, economy, ledgers,
environment/map/room state, receipts, and every registered alias.

### P1-S: stripped semantic authorization cannot be byte-exactly restored

Persistent storage strips the live semantic inventory, base interaction/actor
producer records, action digest, event-choice index, layout authority, and
projections. Those fields contain both transient material and the exact sealed
authority needed to authenticate the finalized environment/layer instance.
Current catalog reconstruction can recover possibilities but cannot silently
prove the exact prior instance/action authority. The existing save packet binds
the complete consequence analysis and remains normative evidence for axis S.

## Axis V -- live availability authority

### V1 -- sealed current-environment/base-interaction authority

Availability is resolved inside the authoritative host from the sealed
`current_environment` semantic inventory and exact base-interaction action
records/digest. The command boundary looks up the addressed owner/stable id,
target identity, enabled/interactive state, action id, origin receipt/boundary,
handler/input/cost, and environment/layer binding from that root.

Consequences:

- `host_interaction_availability` is removed as an authority input. A UI map may
  be compared for diagnostics but cannot enable, retarget, authorize, or alter
  cost/handler/input.
- An augment is available only when both the authored augment receipt and its
  exact sealed host target are live and enabled in the same environment/layer.
- Presentation and sealed authority must be checked as a pair: UI may be more
  restrictive, but disagreement cannot broaden authority. If the authoritative
  root is missing or ambiguous, the command fails closed.
- Same-domain relabels, duplicate presentation ids, cross-owner keys, stale
  enabled values, alternate target aliases, and a correct action attached to a
  wrong host target all reject before cost, RNG, mutation, or receipt.
- This selection couples to S: S1 supplies a durable root; S2 must name the
  trusted reconstruction that produces equivalent sealed host authority; S3
  must state when V1 cannot operate after restore.

### V2 -- de-authorized presentation proposals

FoundationMain or another presentation consumer may continue producing an
availability proposal, but the proposal is explicitly non-authoritative. It
can request focus, hide or disable presentation, or offer a candidate identity
for comparison. It cannot create a live target or turn false/unknown sealed
authority into true.

Consequences:

- The authoritative command path still requires an independent sealed source
  for owner, stable target, enabled state, action, handler/input/cost, and exact
  origin. If that source does not exist, the command rejects.
- Proposal `false` may conservatively suppress a presented action; proposal
  `true` is never sufficient to grant it. Missing, malformed, duplicate, stale,
  or transplanted proposals do not mutate authoritative state.
- Proposal bytes, display ordering, hover/focus state, hit-test caches, and
  composed aliases are declared derived/noncausal and excluded from command
  fingerprints except as one-way restrictions.
- Tests must prove a forged `true`, same-domain relabel, duplicate key,
  cross-layer target, stale UI object, valid overlay on wrong base target, and
  proposal recomputed from hostile presentation all fail to grant authority.
- This choice does not answer where sealed authority comes from; S1, S2, or the
  explicit S3 exception must answer that separately.

### V3 -- explicit caller-availability compatibility exception

The owner authorizes the presentation caller's availability map to continue
granting external/augment availability.

Consequences requiring explicit recording:

- Name which caller(s), target families, environments/layers, and actions may
  grant authority and whether caller `true` overrides absent/false sealed host
  state.
- State the accepted behavior for forged/stale maps, duplicate/colliding
  identities, same-domain relabels, cross-layer/cross-room transplant, and
  presentation/runtime disagreement.
- Revise the prompt, command-authority assertions, hostile tests, downstream
  contracts, and release criteria to name the exception. It cannot be reported
  as host-rooted sealed availability.
- Cost, RNG, mutation, and receipt consequences remain exactly-once; the
  exception changes who may grant availability, not the observable economy.

## Axis R -- rollback strategy

### R1 -- detached canonical candidates plus atomic root publish

Run the complete turn/command/fact/expiry transaction on a detached canonical
candidate graph with no shared mutable object or nested collection references
to the live graph. Only after every operation, capacity check, handler,
correlation, and semantic validation succeeds may one atomic publish replace
the live authoritative root set.

Consequences:

- Candidate construction covers RunState scalars and collections, RNG,
  current environment, world map and embedded environments, casino rooms,
  TownState, NumbersModel, delivery/crew/world models, ledgers, queues,
  receipts, and host-transaction state.
- Mutation of candidate TownState/NumbersModel or any nested array/dictionary
  must be unobservable through every live alias before publish.
- Rejection discards the candidate and leaves live object identities and values
  untouched. Acceptance atomically publishes one graph-consistent tuple; no
  consumer observes new model state with old room state or the reverse.
- The implementation must define how standing references rebind after accepted
  publish. A consumer cannot silently retain a pre-publish object if the new
  root replaces it.
- Proof includes an alias registry or equivalent graph audit and forced failure
  after each mutation stage, not only a final serialized equality assertion.

### R2 -- graph-complete in-place snapshot preserving identities

Keep the live object graph and mutate in place, but capture a graph-complete
authoritative snapshot before the transaction. On rejection, restore every
mutable object and nested collection into the same object identities observed
by registered consumers.

Consequences:

- Snapshot/restore covers all fields listed under R1 and explicitly includes
  TownState and NumbersModel private/durable values, RNG, queues, receipts,
  model ledgers, nested dictionaries/arrays, and every root duplicated
  separately at `e297ca8f`.
- Restore cannot call a path that creates new TownState/NumbersModel instances
  when existing consumers retain the old ones. Identity equality and value
  equality are both blocking checks for aliased objects.
- Alias topology is part of the proof: two roots that shared one authoritative
  object before the transaction still share one restored object afterward;
  two distinct objects do not collapse into one.
- Forced failures occur after town advance, Numbers advance, delivery/crew
  effects, environment/layer changes, fact enqueue/flush, expiry, receipt
  creation, and cleanup. Every case compares graph values, identities, economy,
  RNG, and serialized projection.

### R3 -- explicit partial-rollback compatibility exception

The owner accepts a named set of mutable objects or aliases that need not roll
back exactly when an environment transaction rejects.

Consequences requiring explicit recording:

- Name every exempt object/field and failure stage, including the permitted
  TownState/NumbersModel identity or value drift.
- State whether the turn/action is considered consumed, whether RNG/economy can
  advance, and how a retry avoids double effects or changed outcomes.
- Define presentation, save, parity, and downstream behavior for a rejected
  transaction whose world/model state advanced partially.
- Revise atomicity assertions and release criteria. No downstream row may call
  this a byte-identical no-op or complete rollback.

## Axis S -- save-byte authority

### S1 -- closed durable semantic root

Authorize the closed, versioned `environment_semantic_root` defined by packet
`3861e8ef`. Minimum authority includes environment/archetype/node/visit/layer,
sequence and catalog identities, sealed inventory records/provenance,
base-interaction action records and digest, catalog-derived event choices and
digest, authoritative state fingerprint, producer identity, and root digest.

Consequences:

- Integrity is not authorship: self-rehashing hostile nested records does not
  create authority. The trusted semantic host authors and atomically publishes
  root, matching sequence state, materialization, and ready marker.
- A SaveService envelope protects its container but does not authenticate the
  semantic authorship of nested records. Recomputed inner and outer envelopes
  remain hostile when authority provenance is wrong.
- Explicit schema migration/reconstruction is required. No-sequence saves stay
  byte/behavior compatible; an old active sequence without authentic root is
  reconstructed only from independently trusted durable producers or parked
  fail-closed.
- One exceptional independent review covers the full 16+3 matrix from the save
  packet, repeated-save stability, Native/Web parity, all 55 legacy scenarios,
  and the full hostile matrix below.

### S2 -- named semantic-equivalence contract revision

Replace byte-exact active-sequence restore with an owner-approved named contract
such as `ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1`.

Consequences:

- Enumerate exact durable fields and every permitted derived difference. Each
  omitted/rebuilt field needs a formal `derived_noncausal` declaration naming
  trusted inputs and proving it cannot change authority, branch, RNG, economy,
  receipts, layout/hit authority, or presentation semantics.
- Prove semantic, economy, RNG, layout, presentation, and exactly-once
  equivalence at all 16+3 checkpoints; include repeated-save stability,
  Native/Web parity, catalog mismatch fail-closed, 55 migrations, and
  no-sequence byte/behavior goldens.
- The owner must approve revisions to the prompt, affected assertions, and
  golden policy. Product code cannot silently reinterpret byte-exact language.
- V1/V2 still require an authenticated reconstructed host-availability source;
  semantic equivalence cannot treat a caller proposal as sealed authority.

### S3 -- explicit unsupported-save/compatibility exception

Record exact unsupported active states/boundaries and player-visible behavior:
disable/defer save, reject, cleanly abort, or restore a named authentic prior
checkpoint.

Consequences:

- Name behavior before/after finalization, phase entry, command, fact flush,
  branch, transition drain, expiry, cleanup/aftermath, same-room reload, travel
  revisit, and layer return.
- Define economy/RNG/receipt/objective/temporary-object cleanup and legacy-save
  handling. No unsupported state may silently replay or strand authority.
- Revise prompt, save UI, tests, downstream contracts, migration policy, and
  release claims to name the exception. No-sequence compatibility remains
  separate unless explicitly changed.

## Complete combination register

The axes do not choose one another. The complete selectable triples are:

| Save choice | Detached rollback `R1` | In-place rollback `R2` | Rollback exception `R3` |
| --- | --- | --- | --- |
| `S1` with sealed availability `V1` | `V1-R1-S1` | `V1-R2-S1` | `V1-R3-S1` |
| `S2` with sealed availability `V1` | `V1-R1-S2` | `V1-R2-S2` | `V1-R3-S2` |
| `S3` with sealed availability `V1` | `V1-R1-S3` | `V1-R2-S3` | `V1-R3-S3` |
| `S1` with proposal-only availability `V2` | `V2-R1-S1` | `V2-R2-S1` | `V2-R3-S1` |
| `S2` with proposal-only availability `V2` | `V2-R1-S2` | `V2-R2-S2` | `V2-R3-S2` |
| `S3` with proposal-only availability `V2` | `V2-R1-S3` | `V2-R2-S3` | `V2-R3-S3` |
| `S1` with caller-authority exception `V3` | `V3-R1-S1` | `V3-R2-S1` | `V3-R3-S1` |
| `S2` with caller-authority exception `V3` | `V3-R1-S2` | `V3-R2-S2` | `V3-R3-S2` |
| `S3` with caller-authority exception `V3` | `V3-R1-S3` | `V3-R2-S3` | `V3-R3-S3` |

Any triple containing `V3`, `R3`, or `S3` also requires the corresponding
explicit prompt/test/release exception. Any triple using V1 or V2 with S2/S3
must state the independent trusted post-restore availability source. Any R1
triple must state accepted-publish rebinding; any R2 triple must state the
identity-preserving alias registry.

## Combined hostile, alias, and legacy proof floor

The selected triple must produce one combined proof, not three isolated unit
claims.

### Availability/authority hostile cases

- caller `true` over absent/false sealed authority;
- caller `false` over true authority and one-way suppression behavior;
- missing, extra, wrong-type, duplicate, reordered, colliding, or noncanonical
  availability entries;
- stale UI map, cross-room/node/layer/archetype map, same-domain relabel,
  alternate owner alias, duplicate presentation id, and valid action on wrong
  base target;
- changed action id, handler, inputs, cost, origin receipt, boundary or
  fingerprint; base-action records with a recomputed digest; and
- valid root plus hostile proposal, or valid proposal plus hostile/missing root.

### Rollback/alias cases

- retained aliases to TownState and NumbersModel before the transaction, with
  forced failure after each model mutates;
- aliases to nested model dictionaries/arrays, current environment, world-map
  embedded environment, casino room state, delivery/crew/world state, ledgers,
  queues, receipts, and host transaction records;
- shared-before/still-shared-after and distinct-before/still-distinct-after
  topology checks;
- failure after RNG draw, cost/reward, town/sweep advance, Numbers advance,
  layer change, fact enqueue/flush, expiry, cleanup, and partial publish;
- exact object identity/value/no-new-work assertions for R2, and proof of zero
  shared mutable references plus atomic publish/rebind for R1; and
- repeated rejection and retry to prove no cumulative normalization, receipt,
  action, or RNG drift.

### Save/root/legacy cases

- cross-environment/node/visit/layer/archetype and same-definition instance
  transplant;
- missing/extra/wrong-type fields, record omission/reorder/duplicate/collision,
  mixed root/state/catalog versions, stale root with current state, changed
  action/event choice, forged provenance, and self-rehashed content;
- recomputed inner digest and recomputed outer SaveService envelope;
- hostile derived projection paired with valid root, valid projection paired
  with hostile root, catalog mismatch, and current-catalog substitution;
- all 16+3 checkpoints, repeated save/restore/save/restore, Native/Web parity,
  all 55 legacy scenario ids, every layer, and no-sequence byte/behavior golden;
  and
- absent empty/default marker behavior: migration cannot materialize an empty
  semantic root, ready flag, inventory, or decision marker on a no-sequence save.

## Downstream holds and inheritance

All holds remain until one complete triple is recorded, implemented, accepted
under the authorized review policy, and landed with the required env06_6
payload. Preserved downstream WIP is evidence only and must not invent a local
answer to any axis.

| Consumer | Hold and inherited consequence |
| --- | --- |
| env06_7 packages A-E and ordered assembly | Held on accepted env06_6b. Every archetype/layer/interaction inherits V authority, R transaction behavior, and S restore policy; package-local availability maps, rollback copies, or inventory roots are forbidden |
| depth06_1 | Held on env06_7/craps06_3/crew06_10; cannot audit depth against an unresolved runtime authority/rollback/save contract |
| world06_1 through world06_6 | Landing/integration held. Owner-scoped sequences consume the chosen host availability and rollback/save boundary; world adapters cannot become a second environment authority or bypass V/R/S exceptions |
| world06_7 | Held on accepted world family and therefore transitively on env06_6b; release claims must carry every explicit V3/R3/S3 exception |
| craps06_3 core/environment assembly | Held on accepted env06_6b plus its own owner decisions. Table/street layers, augments, wager/RNG/receipt rollback, save/revisit, and aliases inherit the selected triple |
| crew06_10 | Landing/integration held. Back-room poker room/augment availability, crew/poker/TownState aliases, economy/RNG rollback, and save/revisit inherit the selected triple without moving crew/game authority into the environment root |
| game06_7 and later composition/release rows where world/crew authority is a dependency | Transitively held; no showdown, integration, performance, playtest, or release evidence may treat unresolved environment authority as accepted |

## Decision recording requirements

The owner response must contain one exact triple `V?-R?-S?` and:

- for V1/V2, name the sealed availability source and one-way proposal rule; for
  V3, name the precise caller-authority exception;
- for R1, name candidate graph and atomic publish/rebind; for R2, name the
  graph-complete snapshot and identity-preserving alias registry; for R3, name
  every partial-rollback exception;
- for S1, authorize the closed root/schema/migration and exceptional review;
  for S2, approve the named contract plus prompt/assertion/golden revision; for
  S3, name every unsupported boundary and player behavior; and
- record all downstream holds, exact review target, and whether the complete
  triple stays same-scope or receives a separately named successor row.

No product gates were run for this packet. Evidence is source/ancestry review,
the recorded second-review findings, packet `3861e8ef`, and the former-lane
consequence audit only.
