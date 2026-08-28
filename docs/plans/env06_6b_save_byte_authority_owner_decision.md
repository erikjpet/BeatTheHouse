# env06_6b save-byte authority owner decision

Status: **UNREVIEWED / docs-only / option-neutral**

Packet base: GREEN main
`00ee744fa6269e8a7eb34f67b2659f32d55febaa`

Decision scope: the durable authority needed to restore an active dynamic
environment sequence after semantic authorization ephemera are stripped from a
save. This packet does not select or recommend an option, edit environment
product code, change a test, or claim a gate result.

## Exact decision requested

Choose exactly one save-authority disposition:

- **A -- Durable sealed inventory root.** Authorize a durable sealed
  `EnvironmentSemanticInventory` authority root bound to the exact environment
  and layer. It includes authoritative base-interaction action digest/records
  and a catalog-derived event-choice index, with an explicit schema, migration,
  reconstruction policy, hostile proof, and one exceptional independent review.
- **B -- Named semantic-equivalence contract.** Replace byte-exact active
  sequence persistence with a specifically named semantic restore-equivalence
  contract. The owner must approve its exact durable fields, permitted derived
  differences, reconstruction inputs, and hostile negatives.
- **C -- Explicit unsupported-save/compatibility exception.** Record the exact
  active-sequence states or boundaries that do not support save/restore, and the
  player-visible compatibility behavior used instead.

No option is selected or preferred here. Until the owner records one, the
program owns the unresolved escalation and the authority-dependent env06_7,
world, craps06_3, and crew06_10 intake remains held.

## Binding evidence

| Artifact | Immutable identity | Binding fact |
| --- | --- | --- |
| Full env06_6 prompt | `docs/todo/env06_6_dynamic_scenario_runtime_prompt.md`, blob `2f604ce121818af394e4e9636dc48b1a7d982448` | Requires save/load at every phase and immediately around every branch boundary, exact mid-sequence restore without replay, 55-id legacy migration, and byte/behavior compatibility for base environments with no dynamic sequence |
| Rejected integration | `9ea61fb8fe6c7e70a6c5db60829c28680ce2e92c`, tree `23234c2cd22a6da66c3095826036eb0b790fa50f` | Clean off-main integration of the accepted piece-1 payload plus the first env06_6b closure; recorded review gate remained red, including save byte identity/exactly-once and authority reconstruction clusters |
| Non-save successor | `e297ca8f8aeec9512e2e8e899128ea4831082020`, tree `71a61ae02bc6606a14a855c8f60c6d46bbedea17` | Descends from `9ea61fb8`; net `8 files, +176/-51`; closes additional caller rollback, lifecycle receipt/event, projection, catalog/layout, and atomic materialization work but is still UNREVIEWED and does not resolve the known save-authority choice |
| Inventory implementation at successor | `scripts/core/environment_semantic_inventory.gd`, blob `d3e00c6bbc838b65557f98d43b35ed041e2dbb9b` | Defines closed catalog/instance inventory forms, environment/layer/source binding, exact base interaction and actor authority, records/provenance, event-choice indexing, and content digest validation |
| Persistence implementation at successor | `scripts/core/run_state.gd`, blob `2fea5db412a4d2a0bb687a0b78abea052807b492` | `_strip_scenario_semantic_ephemera()` removes the live semantic inventory, base interaction/actor producer records, action digest, event-choice index, layout authority, and projections before persistent storage |
| Owner escalation record | board commits `37f00fd80d2422c4cf0006000eff3f850a62f61d` and `554e29171667fe75f3651e3feac0556478df3ed7` | Freeze feature expansion, preserve both heads, forbid synthesis or retention of stripped untrusted authorization, and require an owner choice between durable sealed authority and a changed persistence expectation |

The successor is evidence, not an acceptance candidate in this packet. Any
remaining non-save review findings stay with the implementation/review lanes;
this decision only resolves the save-byte authority boundary.

## Exact gap

### What is authoritative while the room is live

After semantic finalization, the live environment can carry a sealed instance
inventory bound to:

- environment id, archetype, world node, current layer, and source provenance;
- exact base interaction records and their live action authority;
- exact base actor records;
- catalog-derived event choices;
- semantic targets, owned records, presentation ids, provenance, and digest;
- the sequence definition/state, receipts, layout authority, and derived
  projection.

The runtime checks the base-interaction action digest against the exact records
before accepting a command. It also uses the event-choice index and target
inventory to distinguish catalog authority from caller-shaped possibilities.

### What persistent storage currently removes

At `e297ca8f`, persistent environment storage deliberately strips
`scenario_semantic_inventory`, `scenario_base_interactions`,
`scenario_base_actors`, `scenario_base_producer_context`,
`scenario_semantic_action_digest`, `scenario_event_choices`, layout authority,
and render/projection fields. It also removes derived semantic-state collections
such as target inventory, declared targets, base interactions, event choices,
and live objects/interactions/actors.

This protects saves from retaining transient presentation and caller-shaped
authorization. It also means the saved bytes no longer contain enough sealed
authority to reproduce the exact live authorization state by themselves.

### Why reconstruction is not currently an answer

The catalog can reconstruct possibilities and the event-choice index from
trusted content, but it cannot silently prove the exact finalized room/layer
instance and exact base-interaction actions that were authoritative when the
save was written. Rebuilding from the current presentation, caller records, or
a self-rehashed replacement would permit catalog drift, cross-layer transplant,
or forged action authority. Retaining every stripped live field would persist
untrusted/derived material and violate the existing authority split.

Therefore the current requirements cannot all be claimed at once without an
owner ruling:

1. strip transient and untrusted authorization;
2. restore the exact active sequence authority from durable state;
3. preserve byte-exact save/load behavior at every material boundary; and
4. never synthesize or weaken the sealed authority proof.

## Common safety baseline

Unless the owner expressly replaces an item under B or C:

- A caller-provided inventory, target, action, event choice, environment id,
  layer, provenance record, digest, or reconstruction hint is comparison
  material only and cannot create authority.
- Same-content rehashing does not authenticate self-issued records.
- Cross-environment, cross-node, cross-layer, cross-archetype, stale-catalog,
  changed-action, and changed-event-choice transplants reject before command,
  mutation, cost, RNG, receipt, transition, cleanup, or aftermath.
- Restore may not replay phase entry, branch resolution, outcome publication,
  audio/dialogue, reward/cost, cleanup, aftermath, or one-shot receipts.
- Receipt order, boundary serials, objective/local state, result/correlation
  identity, and exactly-once behavior survive every supported restore.
- A no-sequence legacy environment remains byte/behavior compatible and does
  not acquire a semantic authority root merely because the loader knows the new
  schema.
- Native and Web validate and reconstruct the same authority and produce the
  same semantic result for identical save bytes and content.

## Option A -- durable sealed EnvironmentSemanticInventory root

### Authority and schema consequences

- Add one durable, closed, versioned authority root owned by the environment
  instance, not by scenario data, presentation code, a caller, or a sequence
  adapter.
- The minimum closed root fields are: root schema/version and kind; environment,
  archetype, world-node, instance/visit and layer identities; sequence id and
  definition fingerprint; catalog identity/version; semantic-inventory schema
  and digest; closed target records and exact provenance; base-interaction
  action-authority records and digest; catalog-derived event-choice records and
  digest; authoritative sequence phase/boundary/state fingerprint; producer
  identity; and the root content digest. Any additional field requires a named
  authority purpose and closed type.
- Bind it to exact environment id, archetype id, world-node/instance identity,
  current layer id, environment visit or equivalent instance boundary,
  definition/catalog version identity, and a canonical content digest.
- Persist the minimum authoritative base-interaction action records and their
  digest. Records must bind owned identity, presentation identity, enabled
  state where authoritative, exact action ids, handlers/inputs or their closed
  canonical authority representation, hit/target authority required by the
  contract, and exact producer provenance.
- Persist or seal the exact catalog-derived event-choice index used by the
  instance, including enough catalog identity/version evidence to detect drift.
  It cannot be regenerated from caller event payloads.
- Keep derived layout, render snapshots, transient availability, presentation
  animation, and rebuildable projections outside the durable root unless the
  owner explicitly classifies a field as authority.
- Digest integrity is not semantic authorship. Recomputing the root digest over
  forged records proves only that those bytes agree with themselves. The trusted
  environment host must author the root from already authenticated live
  producers at semantic finalization and must reject caller-provided root
  content even when every digest is internally consistent.
- A SaveService file envelope, checksum, encryption/MAC, or outer save signature
  protects the save container according to that service's contract; it does not
  by itself prove that nested action records, event choices, provenance, or an
  inventory root were authored by the semantic host. Recomputing or legitimately
  rewriting an outer envelope cannot upgrade hostile nested content into
  semantic authority.

### Migration and reconstruction consequences

- New-schema saves write the root atomically with the sequence state at every
  action/phase/branch/expiry/cleanup boundary.
- Atomic publish means the root, exact sequence state fingerprint, materialized
  semantic authority, and ready/active marker become visible together. A crash
  or rejection exposes the complete prior tuple, never a new root with old
  state, new state with no root, or a ready flag whose authority is absent.
- Restore validates schema, environment/layer/instance binding, definition and
  catalog identity, closed records, and digest before reconstructing derived
  semantic state or accepting ingress.
- Reconstruction consumes only the sealed root plus trusted catalog/runtime
  code. It may rebuild presentation and layout projection, but cannot broaden
  targets, actions, event choices, or ownership beyond the sealed authority.
- Legacy no-sequence saves remain unchanged. For an older active-sequence save
  without the root, migration must either reconstruct from independently
  authentic durable producers under a specifically documented version rule or
  park fail-closed. It must not infer exact authority from a prior ready flag,
  presentation snapshot, or digest supplied beside mutable records.
- Catalog/version mismatch must have an explicit rule: validated migration to a
  new root, supported old-catalog reconstruction, or fail-closed compatibility
  handling. Silent current-catalog substitution is not sufficient.

### Review and proof consequences

- The row receives one exceptional independent review of the new authority
  surface after the already recorded first rejection and successor work.
- Proof includes round trips before/after phase entry, command, branch,
  transition drain, expiry, cleanup, aftermath, travel, revisit, and layer
  change; exact replay; legacy no-sequence bytes; and Native/Web parity.
- Hostile negatives include missing/extra/wrong-type root fields, wrong schema,
  wrong environment/node/layer/visit/catalog, record omission/reorder/duplicate,
  changed action handler/input/id, changed event choice, forged provenance,
  self-rehashed mutation, stale root with current state, same-archetype and
  same-definition cross-instance transplant, mixed root/sequence/catalog schema
  versions, recomputed inner digests, recomputed outer SaveService envelopes,
  and a valid root paired with hostile derived projection. Reordering that is
  declared non-semantic must canonicalize to one value; otherwise reorder is a
  hostile mismatch rather than an allowed alternate byte form.

### Binding 16+3 checkpoint matrix

Option A must cover the same named matrix on native and Web. The sixteen active
sequence checkpoints are immediately before and after each of: semantic
finalization, phase entry/reentry, authenticated command commit, fact flush,
branch/outcome resolution, transition drain, expiry resolution, and
cleanup/aftermath publication. The additional three rehydration contexts are:
same-room reload, travel-away then revisit, and layer change then return.

At every one of the 16+3 points the proof records save bytes, root/state digests,
authority records, semantic state, economy, RNG state, layout, presentation,
receipts, and one-shot counts. It performs an exact repeated save, a restore, a
second repeated save, and a replay attempt. The three context returns must use
the same authentic root without transplanting current-room or current-layer
authority.

## Option B -- named semantic restore-equivalence contract

### Contract identity

The owner names the replacement contract; a concrete neutral name for decision
recording is `ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1`. Selecting B must either
adopt that name or provide another exact name so tests and downstream rows cite
one immutable expectation rather than the phrase "semantically equivalent."

### Exact durable fields

The contract must enumerate the values that remain identical across save/load:

- environment/archetype/node/layer and scenario/definition identity;
- sequence status, phase, boundary serial, local state, objectives, resolved
  branches/outcomes, expiry/reentry/cleanup/aftermath state;
- command, operation, transition, fact, visit, outcome, cleanup, and replay
  receipts in authoritative order;
- money/cost/result/correlation/RNG identities and any host transaction ledger;
- owner-scoped material semantics and persistent aftermath; and
- an independently authenticated basis for permitted actions, targets, and
  event choices after reconstruction.

The contract must also list permitted differences, such as regenerated render
snapshots, normalized layout caches, transient presentation availability,
derived projection ordering where order is non-semantic, or cache fields. A
field is not permitted to drift merely because a test omits it.

Every omitted or regenerated field requires a formal `derived_noncausal`
declaration that names its trusted inputs, deterministic reconstruction rule,
and proof that it cannot authorize a target/action/event choice, change a
branch, consume RNG, alter economy, suppress or duplicate a receipt, affect
layout reachability/hit authority, or change observable presentation semantics.
Calling a field a cache or projection is not that proof.

### Reconstruction and hostile consequences

- Reconstruction inputs must be named and trusted. If the durable bytes do not
  carry an inventory root, the contract must state how current catalog/base
  producers authenticate exact action and event-choice authority without using
  caller-shaped or self-signed material.
- Catalog or definition mismatch fails closed before reconstruction unless an
  owner-approved migration transforms the exact old authority into the exact
  new contract. Current-catalog substitution is not semantic equivalence.
- Tests compare the exact field allowlist and fail on every extra unexplained
  difference; they do not replace the old assertion with a broad success flag.
- Required hostile negatives are wrong environment/node/layer, stale or changed
  catalog, changed base action id/handler/input, changed event choice, forged or
  self-rehashed producer records, omitted authority, duplicate/colliding
  identity, hostile derived projection, receipt/boundary drift, and replay at
  every interruption boundary.
- The owner must state whether byte-exact comparison still applies to the
  serialized persistent form even though the rehydrated live environment may
  differ in permitted derived fields.
- Equivalence is proven at the full 16+3 matrix defined under A. At every point
  it covers semantic state, economy, RNG, layout and hit authority,
  presentation, receipt ordering, one-shot counts, cleanup/aftermath, and
  exactly-once replay behavior, not only final scenario outcome.
- Native/Web parity compares the named field set and permitted derived
  reconstructions. Repeated-save proof requires save A, immediate save B,
  restore, save C, and a second restore to retain the same authoritative
  projection without cumulative normalization drift.
- All 55 legacy scenario migrations and all no-sequence environments retain
  their existing byte/behavior compatibility contract unless the owner names a
  separate explicit exception. The equivalence comparator cannot materialize
  empty/default semantic keys on those saves.

### Review consequence

B changes an acceptance requirement rather than authorizing new durable bytes.
The named contract and its exact comparator/negative matrix require independent
review before implementation or downstream consumers can claim compatibility.
It also requires an owner-approved revision to the full prompt, the affected
save/load assertions, and the golden-policy document or manifest that defines
which byte-exact comparisons remain binding. An implementation commit cannot
silently reinterpret those sources.

## Option C -- unsupported-save/compatibility exception

### Scope required

The owner must name every unsupported state and boundary. Examples that require
an explicit yes/no disposition are: pending semantic finalization, active phase,
immediately before/after a command, unresolved branch, queued transition,
expiry boundary, partial cleanup, persistent aftermath, travel away, revisit,
and layer change. A blanket "dynamic saves unsupported" statement is not enough
to define player behavior or downstream tests.

### Player and authority consequences

- The decision must state whether save is disabled, deferred to a safe boundary,
  the sequence is cleanly aborted, the room is restored to a pre-sequence
  checkpoint, or the save is rejected with visible explanation.
- It must define what happens to costs/rewards, RNG, objectives, receipts,
  temporary scene objects, interactions, actors, cleanup, and aftermath. No
  unsupported path may silently replay or strand authority.
- Existing saves encountered in an unsupported state need a versioned
  compatibility rule: reject, park, roll back to a named authentic checkpoint,
  or another explicitly authorized behavior.
- Validation/release evidence must name the exception; it cannot claim the full
  prompt's every-phase save/load requirement.
- Legacy no-sequence byte/behavior compatibility remains separate and cannot be
  waived implicitly by this option.

## Downstream inheritance

### env06_7

Every env06_7 archetype package and the ordered assembly inherit the selected
authority rule. Under A they bind their environment/layer/action/event-choice
authority into the durable root. Under B they cite and satisfy the named exact
field comparator and hostile matrix. Under C every affected variation and save
boundary is marked unsupported; env06_7 cannot claim full save/revisit coverage
for an excepted path.

### world06_1 through world06_6

The world adapter mounts owner-scoped sequences into live environments and must
not become a second inventory or reconstruction authority. Under A it consumes
the restored sealed environment root. Under B its own saved owner instances and
receipts must compose with the named environment equivalence fields. Under C it
must prevent or explicitly handle world-sequence saves at every excepted
environment boundary; expiry/abandon/cleanup cannot route around the exception.

### craps06_3

The craps environment integration inherits table/street layer binding, exact
interaction action authority, event choices, ritual receipts, and save/revisit
semantics. Under A these bind to the durable environment/layer root. Under B the
named comparator must cover committed wagers, ritual phase/results/receipts and
their environment authority. Under C every affected table/street save boundary
is an explicit product exception and cannot be reported as full row parity.

### crew06_10

Back-room poker inherits the same room/layer target and event-choice authority
while crew/game models retain their own result and economy authority. Under A
the environment root authenticates restored room interactions without absorbing
crew or poker state. Under B the comparator covers their composition and
exactly-once receipts. Under C unsupported room-sequence saves must not duplicate
buy-in, settlement, trust/heat, crew outcomes, cleanup, or table aftermath.

No downstream row may invent a row-local inventory root, weaken the chosen
comparator, preserve stripped caller authorization, or silently expand a C
exception.

## Decision recording requirements

The owner response should name `A`, `B`, or `C`.

- For A: record the closed schema owner, exact binding fields, durable action
  records/digest, event-choice index, catalog/version rule, legacy migration,
  reconstruction inputs, and exceptional reviewer.
- For B: record the contract name, exact durable field comparator, permitted
  differences, reconstruction authority, hostile negatives, and reviewer.
- For C: record every unsupported state/boundary, player-visible behavior,
  existing-save handling, cleanup/economy/RNG treatment, and downstream release
  exception.

No product gates were run for this decision packet. Evidence is limited to the
full prompt, immutable heads/trees/blobs, recorded review findings, and source
inspection of the frozen successor.
