# world06_1 post-Option-A receipt-timing owner decision

Status: **UNREVIEWED / docs-only / option-neutral**

Packet base: main `232ec7d6be3947ef3a5195f3c380ae0b624430e5`

Decision scope: the remaining ordering gap after the owner selected sealed
DeliveryRunModel authority for world06_1. This packet does not select or
recommend an option, modify product code, revise the sealed ruling, or claim a
gate result.

## Exact decision requested

Choose exactly one pre-apply receipt disposition:

- **A1 -- Non-persisting adapter prepare/preview.** Authorize the adapter, which
  remains the sole neutral-outcome-receipt authority, to prepare or preview the
  authentic receipt before owner apply without persisting or acknowledging it.
  DeliveryRunModel remains the sole checkpoint authority and commits
  `world_applied`, owner consequences, the sealed checkpoint, and the bound
  public consequence result atomically. Acknowledgement and cleanup occur only
  afterward.
- **A2 -- Another single-authority pre-apply mechanism.** Specify a different
  mechanism that makes the authentic neutral receipt identity and cause
  available before owner apply while naming exactly one authority for its
  creation. DeliveryRunModel still owns the sealed causal checkpoint required
  by the prior ruling.
- **A3 -- Explicit ordering or binding change.** Change the consequence ordering
  or the receipt-binding requirement explicitly, including which atomicity,
  replay, migration, expiry, and abandonment guarantees replace the sealed
  ordering now on record.

No option is selected or preferred here. Silence is not an owner-side blocker:
the program owns this unresolved escalation and keeps the authority-dependent
world rows parked until a choice is recorded.

## Binding record

| Artifact | Immutable identity | Binding fact |
| --- | --- | --- |
| Full world06_1 prompt | `docs/todo/world06_1_crew_sequence_adapter_prompt.md`, blob `3f5a917d7205f0e8e341fcaaa056c222c2fb39c0` | Requires one real Crew favor conversion, existing owner-model APIs and exactly-once money/heat/trust/job semantics, save/revisit/expiry in every ordering, neutral outcome routing, full cleanup, and inheritance by world06_2 through world06_6 |
| Frozen adapter contract | `docs/plans/world06_1_crew_sequence_adapter_contract.md`, blob `bdf957f7767489e736cec2bc1c431cbb11d2c239` at frozen branch ancestry | The adapter owns neutral outcome receipts and acknowledgements; the crew/world model remains outcome authority; adapter receipts cannot contain or become owner-model authority |
| Owner's sealed-model ruling | board commit `8a452c2d12f91456ba480cf3ed0f741e3cebaecf` | Selected the closed causal checkpoint inside DeliveryRunModel, atomic with `world_applied` and consequences, with fail-closed legacy migration and no checkpoint synthesis from the boolean; rejected adapter checkpoint authority |
| Ordering escalation | board commit `d46250abd485029190018bd479379f8416533de9` | Records that mounted expiry/abandon consequences set `world_applied=true` before the adapter emits the authoritative neutral receipt, so the selected receipt-bound checkpoint cannot be created atomically under the existing order |
| Second-rejected preserved head | `ef55807dcd155e30064798ef475710dc9be57c64` | Preserves the rejected product attempt and its post-cleanup replay proof; the owner ordered no third ordinary review round before the authority decision |
| Clean frozen WIP | `9d6ff952ab256bb74ec4d26e655cfb9cec3517e5`, tree `689bb9b8a9a48e2dbca4e01543fcf503c07dfc44`; test blob `422370c025002a7fe2c782231479e30abecbd98d` | Its only delta over `ef55807d` is `scripts/tests/foundation/world_sequence_delivery_proof_contract.gd`; the `UNREVIEWED-BLOCKED` head stages checkpoint/transplant/fingerprint/malformed/save-load/replay negatives and contains no guessed production timing change |
| Clean-park record | board commit `f0d0b5ddb3b0f2b25a5e2cca04aba9c049f80dcd` | Preserves `9d6ff952` and states that no workaround or boolean synthesis is authorized |

The frozen WIP calls prospective product seams such as
`world_sequence_checkpoint_delivery_outcome()` and
`DeliveryRunModel.closed_checkpoint()`. Their presence in a red test does not
authorize those spellings or prove a production implementation. The owner
choice must settle timing and authority first.

## Exact gap in the frozen behavior

The current delivery flow has two terminal sources:

1. A direct successful handoff calls `delivery_complete_handoff()`, which asks
   DeliveryRunModel to resolve success and immediately invokes
   `_apply_delivery_resolution()`.
2. Deadline expiry or abandonment resolves DeliveryRunModel first and then
   invokes `_apply_delivery_resolution()` from the owner lifecycle.

`_apply_delivery_resolution()` applies cash, heat, flags, job results, crew or
Numbers consequences, and then sets `active_delivery_run.world_applied=true`.
For mounted expiry/abandon it only afterward asks the adapter to synchronize the
owner lifecycle and find the resulting neutral receipt. At that moment the
owner consequence already exists, so DeliveryRunModel cannot atomically seal a
checkpoint that includes the not-yet-created receipt identity and cause.

The frozen negative scaffold requires a closed checkpoint to bind all of:

- delivery instance and job identity;
- exact adapter owner and public instance;
- neutral outcome receipt id, fingerprint, and cause fingerprint;
- normalized owner resolution and its fingerprint;
- delivery receipt fingerprint;
- closed public result and fingerprint; and
- the same atomic boundary as `world_applied` and owner consequences.

A post-apply adapter copy does not satisfy the ruling. A checkpoint inferred
from `world_applied=true` does not satisfy it either. A receipt-shaped value
created independently by both adapter and model would create two authorities
and also does not satisfy it.

## Rules common to all three choices

Unless A3 explicitly changes one of them, the following remain binding:

- DeliveryRunModel is the sole persisted checkpoint authority.
- The adapter is the sole authority for its neutral outcome receipt; caller
  values are comparison material only.
- Owner consequence application, `world_applied`, the causal checkpoint, and
  the public consequence result are one atomic commit.
- Neutral receipt acknowledgement and sequence cleanup happen only after that
  commit and are independently retryable.
- An exact checkpoint retry is idempotent. A transplant, changed content under
  the same receipt, wrong owner/instance/resolution, malformed field, or
  noncanonical value fails closed without consequence, acknowledgement,
  cleanup, RNG, or receipt mutation.
- No adapter or RunState registration checkpoint may substitute for the sealed
  DeliveryRunModel checkpoint selected by the owner.
- Economy values, RNG, job tuning, delivery outcomes, and Crew/Numbers
  consequences do not change merely because a timing option is selected.

## Direct handoff and version-1 migration boundary

The owner choice must preserve these distinctions explicitly.

### Mounted direct handoff

After the selected mechanism is introduced, a direct
`delivery_complete_handoff()` on a delivery owned by a mounted world sequence
must not apply first and attempt to bind a receipt later. It must either enter
the selected receipt-aware consume path with an authentic pre-apply receipt or
reject before resolution, cash, heat, flags, job state, `world_applied`,
checkpoint, acknowledgement, or cleanup. This is the direct-handoff rejection
rule. It does not prohibit the existing direct API for a delivery that has no
mounted sequence owner.

### Ambiguous version-1 state

A version-1 mounted save with `world_applied=true` but no authentic closed
checkpoint is ambiguous: the boolean cannot prove which receipt, owner,
instance, resolution, or public result caused the consequence. It must remain
parked fail-closed with its unresolved retry evidence retained. Migration must
not synthesize a checkpoint, acknowledge a receipt, clean the sequence, or
apply the consequence again.

A legacy direct-applied delivery with no mounted adapter owner and no pending
adapter outcome remains a direct owner-model result. Migration must not
reclassify it as adapter-consumed or manufacture a neutral receipt for it.
The implementation must distinguish this direct-applied case using authentic
persisted ownership/registration evidence, not the `world_applied` boolean
alone. If the evidence cannot distinguish the cases, the state is ambiguous
and follows the fail-closed rule above.

## Option A1 consequences

### Authority and implementation

- The adapter may deterministically prepare the exact neutral receipt envelope
  before owner apply, but the prepare/preview operation persists no pending
  receipt, acknowledgement, cleanup marker, consequence, or checkpoint.
- The preview must be derived from the live trusted definition, registration,
  current terminal cause, owner token, public instance, and canonical boundary.
  Caller-authored receipt ids, causes, hashes, or outcomes cannot seed it.
- DeliveryRunModel validates the preview as comparison material and atomically
  commits the bound checkpoint with its existing consequences and
  `world_applied`. It does not become a second neutral-receipt issuer.
- After commit, the adapter materializes or confirms exactly the prepared
  receipt, then acknowledgement and cleanup resume through the generic seam.
  Changed preview content rejects rather than being regenerated under the same
  identity.

### Delivered, expiry, and abandonment

- A mounted successful handoff must route through the receipt-aware path; a
  bare mounted direct handoff rejects as specified above.
- Deadline expiry and abandonment can prepare their neutral terminal receipt
  before `_apply_delivery_resolution()` and therefore can be represented in
  the same atomic model checkpoint as failure effects and `world_applied`.
- Save or interruption before model commit leaves neither consequence nor
  persisted preview. Retry prepares the same canonical identity.
- Save after model commit but before adapter acknowledgement resumes from the
  authentic checkpoint and exact pending/confirmable receipt without replaying
  owner effects. Save after acknowledgement but before cleanup retries cleanup
  only.

### Versioning and proof

- The DeliveryRunModel schema must distinguish a new authentic checkpoint from
  version-1 state and apply the common fail-closed/direct-applied rule.
- Tests must include direct mounted handoff rejection, preview replay and
  changed-content conflict, every before/after commit/ack/cleanup interruption,
  expiry, abandonment, authentic save/load, transplant, wrong owner/instance,
  fingerprint mutation, malformed fields, and exact no-op replay.

## Option A2 consequences

### Decision detail required

The owner must name the mechanism and exactly one pre-apply neutral-receipt
authority. The decision must state:

- which trusted live inputs create the receipt identity and cause;
- whether the mechanism is a pure query, reservation, capability, token, or
  another closed form;
- which component validates it and which component persists it;
- how exact retry returns the same identity without two issuers;
- how changed content, transplant, stale owner, and missing registration reject;
  and
- how the sealed DeliveryRunModel checkpoint binds it atomically with owner
  consequences and `world_applied`.

### Delivered, expiry, abandonment, and migration

- Mounted direct handoff must reject unless it enters the named mechanism before
  owner apply. Unmounted direct delivery remains separate.
- The mechanism must represent owner-driven expiry and abandonment before
  consequences are applied; if it cannot, those outcomes remain blocked rather
  than falling back to post-apply synthesis.
- The common version-1 ambiguous fail-closed/direct-applied rule remains in
  force unless the owner explicitly replaces it under A3.
- The same interruption, idempotence, hostility, save/load, and parity matrix
  required by A1 applies to the named mechanism.

## Option A3 consequences

### Explicit contract change required

The owner must state exactly which current requirement changes. This includes
whether consequences move after receipt creation, whether the receipt ceases to
bind the model checkpoint, whether `world_applied` is split into more than one
durable phase, or whether expiry/abandon receives a different terminal
contract. The replacement must name one authority for every durable fact.

### Observable and persistence consequences

- If consequence ordering changes, cash, heat, flags, jobs, Crew/Numbers state,
  public results, acknowledgement, and cleanup must receive a new exact order
  and interruption matrix. No intermediate save may expose half an owner result
  as completed.
- If receipt binding is weakened or removed, the decision must identify what
  now prevents transplant, double apply, wrong-instance acknowledgement, and
  cleanup of an unbound consequence.
- If expiry or abandonment is made unsupported, the decision must state how an
  already mounted sequence expires or is abandoned without orphaned objects,
  interactions, jobs, pending outcomes, or invisible applied effects.
- The owner must specify the version-1 migration rule. Without an explicit
  replacement, ambiguous mounted `world_applied=true` remains fail-closed and
  direct-applied unmounted results remain outside adapter acknowledgement.
- Native and Web must serialize and replay the replacement ordering identically.

## world06_2 and world06_3 inheritance

world06_2 depends on world06_1 and owns reusable deliveries, multi-stop routes,
holds, stash/ditch, and pursuit. It inherits the selected terminal transaction
unchanged for every success, deadline, caught/failure, abandonment, and cleanup
path. It must not add a route-specific receipt issuer, synthesize checkpoints,
or bypass mounted direct-handoff rejection.

world06_3 depends on world06_1 and world06_2 and feeds Numbers outcomes through
those delivery/chase verbs. It inherits the same receipt timing and sealed
checkpoint for collection/fix consequences, cash/debt/heat changes, terminal
public results, save/revisit, expiry, and abandonment. It must not infer adapter
completion from a Numbers flag, debt change, `world_applied`, or a route-local
receipt.

For A1, both rows consume the adapter preview plus model checkpoint seam. For
A2, both consume the single named mechanism. For A3, both remain held until the
replacement ordering and receipt contract is explicit enough to author and
test without inventing row-local authority.

## Decision recording requirements

The owner response should name `A1`, `A2`, or `A3`. For A2 it must provide the
single-authority mechanism details listed above. For A3 it must enumerate every
changed guarantee and its replacement. Every choice must record the schema and
migration rule, mounted direct-handoff behavior, expiry/abandon behavior,
world06_2/world06_3 inheritance, and the exact review target.

No product gates were run for this packet. Evidence consists only of immutable
source, ancestry, board rulings, and inspection of the frozen test WIP.
