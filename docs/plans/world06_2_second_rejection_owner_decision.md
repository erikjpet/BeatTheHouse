# world06_2 second-rejection owner decision evidence

Status: **UNREVIEWED / OPTION-NEUTRAL / DOCUMENTATION ONLY**

Decision required: choose the disposition of the Streets delivery-depth model
after two product rejections. This packet records three executable choices and
their movement, cargo, receipt, save and double-fire consequences. It does not
select, rank or recommend a choice. A third ordinary remediation cycle is not
authorized.

This packet changes no product, world model, test, gate or board file. Both
rejected heads remain evidence only. Any implementation authorized by the owner
belongs to the exclusive world lane; the Integrator reviews, gates and lands but
does not implement the resolution.

## 1. Binding prompt, lineage and exact identities

The full row prompt is
`docs/todo/world06_2_streets_sequences_prompt.md`. It remains binding unless the
owner explicitly narrows the row under Option B or records the exception under
Option C. In particular, the prompt requires real carried cargo, distinct
ordered stops, real stash/ditch locations, played move/wait/duck actions,
reusable pursuit/cover verbs, staged world06_1 pickup/handoff, and exactly-once
consequences across save, exit, travel, revisit and expiry.

| Classification | Exact commit | Tree | Relationship / consequence |
| --- | --- | --- | --- |
| local `main` used for this packet | `232ec7d6be3947ef3a5195f3c380ae0b624430e5` | `df19fba31b62495dc1fb0d076e7856b3374d4004` | documentation base only |
| first rejected product | `b4b2f9f83839d227190845cea671a107b036ebd1` | `a74761ef2c8556934d8f132d148c4a71dee45cb0` | parent `2b56a8ee6aa0a4ba0f232783a083ba09d5e1316a`; frozen first candidate |
| proof hardening between candidates | `94e64cc31653e260ba238ff46b3582edacfb4c23` | `2e9cb824b0e2d920ca95767aa2d73ba4b0ecca3e` | direct child of first rejection; proof, not acceptance |
| second rejected product | `e4f4194f593bb401220eb56a1697b5fe58e60753` | `e10572bd226eca36bfb8cd3bc935e05042586ec7` | direct child of proof hardening; frozen second candidate |

The first rejected model blob is
`3bc7b018bb8f223f188a0a8376da63de9afd4384`. The second rejected model blob is
`fdcdc3955e8107d0a13c194b0e3f7c831b942ae5`; its inherited focused proof blob is
`664cf2be8659c1ceb413d9a73ff5576c63c2aead`.

The exact world06_1 contract is
`docs/plans/world06_1_crew_sequence_adapter_contract.md`. Its binding authority
rules are part of every option:

- authored commands are authenticated against a live resolved interaction;
- every command/outcome uses a closed cause envelope, stable receipt identity,
  exact boundary and canonical content fingerprint;
- a terminal sequence emits a stable owner-scoped outcome receipt;
- the owning model applies its existing API and durably acknowledges the result
  before the runtime receipt is consumed; and
- save/load between owner application, checkpoint, acknowledgement and cleanup
  must return the recorded result without applying consequences again.

The currently preserved world06_1 work head
`9d6ff952ab256bb74ec4d26e655cfb9cec3517e5` demonstrates a coupled delivery
checkpoint flow, but is marked `UNREVIEWED-BLOCKED`; it is evidence, not an
accepted dependency or authority. Option A must bind to an owner-approved,
accepted world06_1 successor flow rather than copy or infer authority from that
head.

## 2. Authority boundary that both candidates must be judged against

`DeliveryRunModel` may own delivery progress and enforce its closed state
machine. It does not own the live world graph, the existence of a route, the
current player node, cover existence, semantic interaction identity, or the
world06_1 command/outcome root. A caller-provided route id, node id, cover id,
receipt key or hash is comparison material only. It becomes authority only when
the trusted host issued it for the exact live instance, action, target and
boundary and the model can verify that unforgeable root.

The same rule applies to cargo. A model record saying `carried`, `stashed`,
`found`, `ditched` or `delivered` is not sufficient proof that the corresponding
host interaction or world movement occurred. Persisted physical state must be
causally linked to the exact authoritative host operation that produced it.

Multi-stop handoff is stricter than node equality. Every handoff command must
name the exact next `target_id`; omission is not shorthand, and a matching node
cannot select an unnamed target. Target order, cargo instance, arrival cause,
handoff interaction, delivery run and outcome receipt must all agree.

## 3. First rejection: `b4b2f9f8`

The first remediation preserved useful physical-delivery work and closed some
local replay and ordering gaps:

- a non-target arrival no longer advanced arrival position/count;
- a handoff checked the next pending stop and rejected an explicitly wrong
  target;
- stash, retrieve, found and ditch carried place identity more consistently;
- receipt replay returned the previous local state; and
- cargo modes and target ordering were tightened.

Those local checks did not establish host authority. The model still accepted
caller-supplied movement, node, cover/place and receipt material without a
non-forgeable world root. Handoff also allowed an absent `target_id`, making
exact target selection optional. A caller able to construct a coherent local
state and receipt could move cargo or advance delivery facts without proving the
corresponding live route, cover, interaction or world06_1 transaction.

The first head therefore remains rejected even where its local state-machine
improvements are suitable for semantic replay into an authorized successor.

## 4. Second rejection: `e4f4194f`

The second candidate added meaningful fail-closed shape checks:

- movement checks now compare source, destination and route identity;
- duck checks compare node-bound cover identity;
- carried/stashed ditch and found operations require matching locations;
- handoff requires pending arrival plus carried cargo at the node;
- receipt maps use a closed schema, ordered previous-receipt fingerprints and
  restore validation; and
- malformed receipt chains reject normalization.

Those changes do not make the authority non-forgeable. Public static helpers
`seal_movement_authority(...)` and `seal_cover_authority(...)` construct a
dictionary and append a SHA-256 of that same caller-known dictionary. The model
then recreates the same value and compares it. Any caller that can choose the
source, destination, route or cover can recompute the accepted fingerprint.

The action receipt chain has the same limit: it proves internal consistency and
ordering of model-authored records, not that the host authorized the original
movement, cargo transfer or semantic interaction. A self-hash can detect
accidental mutation; it is not a root receipt.

The second candidate also retains an optional handoff target check: an explicit
wrong `target_id` rejects, but an empty target id is accepted when the node and
pending order otherwise match. That is not the mandatory exact-target contract.

Therefore the remaining P1 is not another hashing-format defect. It is the
absence of host-rooted route/cover/target/cargo authority coupled to the
owner-approved world06_1 command and outcome receipt flow.

## 5. Consequence baseline for the owner choice

The decision must address five coupled surfaces:

1. **Movement.** Who proves the current source, legal adjacent destination,
   exact route and action boundary for move/wait/duck?
2. **Cargo.** Who proves pickup, carried location, stash/place, retrieve, found,
   ditch and handoff for the exact cargo instance?
3. **Receipts.** Is a record merely internally self-consistent, or rooted in a
   trusted host command/outcome receipt that callers cannot mint?
4. **Save/restore.** Can a copied, stripped, transplanted or recomputed record
   become authoritative after load?
5. **Double-fire.** Can crash/retry/revisit repeat or suppress delivery progress,
   reward, heat, trust, grievance, debt, cleanup or lifecycle outcomes?

The shipped economic values and attention/pursuit/hold tuning remain unchanged
under all options. The difference is whether their eligibility and exactly-once
causes are authenticated, excluded from this row, or explicitly accepted as
caller-constructible authority.

## 6. Option A: host-rooted full closure plus one exceptional review

Owner statement: retain the complete world06_2 prompt and authorize one
exceptional remediation/review coupled to an owner-approved world06_1 receipt
flow.

### Required implementation boundary

The exclusive world owner replays preservable local state-machine changes onto
the accepted dependency base. The delivery model receives a bounded host proof;
it never exposes a public function that can mint that proof. The trusted host
root binds at least:

- world06_1 owner token and public delivery instance;
- exact command/outcome receipt id and cause fingerprint;
- exact run, delivery and cargo instance;
- exact action verb, current source node, destination/stay node, route id and
  boundary serial;
- for duck, exact live cover identity owned by the current node;
- for stash/retrieve/found/ditch, exact semantic place and transfer operation;
- for handoff, mandatory nonempty exact next `target_id`, target node, cargo
  instance and authenticated handoff interaction; and
- predecessor/root fingerprint so a valid receipt cannot be transplanted to
  another run, route, target, cargo item, boundary or delivery state.

Validation is fail-closed and atomic. Missing, extra, malformed, stale,
cross-instance, cross-target, cross-route, cross-node, cross-cover, replayed or
causally mismatched proof leaves the complete delivery/world state unchanged.
The host is the only minter; the model may verify and retain the minimum durable
root/acknowledgement needed for replay but may not create a parallel authority.

### Required hostile proof

Proof must include exact rejection without mutation for:

- self-hashed movement/cover dictionaries generated with the rejected public
  sealing algorithm;
- valid-shaped but caller-chosen route, adjacency, cover, place and node values;
- missing and empty target id, correct-node/wrong-target, correct-target/
  wrong-node, out-of-order target and duplicate-node multi-stop ambiguity;
- transplanted host receipts across run, delivery, cargo, owner token, public
  instance, action, target, boundary and predecessor;
- forged pickup/stash/retrieve/found/ditch/handoff physical transitions;
- stripped, reordered, truncated, extended and coherently recomputed local
  receipt chains;
- save/load before and after command validation, model mutation, owner outcome,
  durable checkpoint, adapter acknowledgement, runtime consumption and cleanup;
  and
- crash/retry/revisit/expiry at every boundary, proving each delivery progress
  fact and every money/heat/trust/grievance/debt/lifecycle consequence applies
  exactly once or not at all.

Movement consequence: only a live host-authorized route/cover action advances
position or pursuit. Cargo consequence: every physical transfer is tied to the
exact item, place and host operation. Receipt consequence: local chains become
tamper evidence subordinate to a non-forgeable host root. Save consequence:
transplanted or stripped authority rejects; authentic pending work resumes.
Double-fire consequence: owner effect, acknowledgement and cleanup are distinct
durable checkpoints with idempotent retry.

Only one exceptional review is authorized. A rejection returns to the owner.
World06_2 remains blocked until both the owner-approved world06_1 flow and this
candidate are accepted. `world06_6` and `world06_7` remain blocked meanwhile.

## 7. Option B: proposal-only, de-authorized partial plus bridge successor

Owner statement: accept only a proposal/projection slice in world06_2 and defer
all authoritative host integration to named successor `world06_2b` (`Streets
Delivery Host Authority Bridge`).

World06_2 becomes `PARTIAL - PROPOSAL ONLY / NON-AUTHORITATIVE`, never `DONE`.
It may retain:

- deterministic candidate route, cover and delivery-action proposals labelled
  `authoritative=false` and `ready_for_host_validation`;
- player-safe derived presentation of cargo/stop state from already
  authoritative shipped delivery facts; and
- general move/wait/duck/stash/ditch/handoff vocabulary that cannot mutate or
  persist a new world, cargo, target, receipt or economic fact.

It excludes authoritative route traversal, cover use, physical cargo transfer,
multi-stop completion, model-owned action/target receipts and world06_1 outcome
acknowledgement. Proposal fields are never accepted as restore authority and are
recomputed or discarded after save/load.

`world06_2b` owns the accepted world06_1 command/outcome coupling, host-rooted
route/cover/place/target receipts, mandatory exact target, durable cargo
transfers, save migration, hostile matrices and exactly-once checkpoint flow.

Movement consequence: this row can display/propose but cannot assert travel or
cover. Cargo consequence: physical state remains derived from existing
authority; new stash/retrieve/found/ditch/handoff depth does not round-trip.
Receipt consequence: no proposal is a receipt. Save consequence: proposal state
is non-authoritative and cannot restore progress. Double-fire consequence: this
partial emits no owner consequence, so authoritative retry remains wholly open
in `world06_2b`.

All played-delivery, authoritative pursuit, physical cargo, persistence and
exactly-once completion claims remain open. `world06_6` and `world06_7` stay
blocked until `world06_2b` lands; neither may count the partial as the reusable
chase or delivery-depth dependency.

## 8. Option C: self-hash and bare-authority exception

Owner statement: record exception `WORLD06_2-BARE-AUTHORITY-01`, allowing the
delivery model to trust caller-provided movement, cover, cargo, target and
receipt material when it is internally shape-valid or self-hash-valid, without
a host-rooted world06_1 cause.

The exception must state exact accepted behavior:

- route and cover dictionaries generated by public self-sealing helpers count
  as authority;
- caller-selected node/place/cargo transition fields count as physical truth
  after local state checks;
- a locally generated action/target receipt chain counts as durable authority;
- handoff may omit `target_id` and use next-pending target plus node matching, or
  the owner must separately require the exact id while retaining the rest of
  the exception; and
- save/restore may trust internally coherent local records without an accepted
  world06_1 root receipt.

### Exact consequences

Movement: a caller able to choose route/source/destination/cover values can
recompute an accepted seal, so adjacency, live route existence and cover
presence are not host-attested. Cargo: a coherent local record can assert
carried/stashed/found/ditched/delivered state without proving the corresponding
world interaction. Receipt: self-hashes detect inconsistent edits but do not
identify a trusted issuer; a caller can recompute an entire coherent chain.

Save: copied or author-constructed records can survive normalization when their
shape, sequence and hashes agree. The product cannot claim fail-closed
anti-transplant, host-rooted route/cargo authority, or causal restore for these
fields. Double-fire: local receipt replay may suppress duplicate model actions,
but it cannot prove whether the owning world06_1/economic consequence already
committed. Crash windows can therefore suppress a required effect or repeat
money, heat, trust, grievance, debt, delivery completion, cleanup or lifecycle
effects unless every consumer adds a separate authoritative quarantine.

The owner must amend the row prompt, save/migration contract, movement/cargo and
receipt claims, exact-target rule, `world06_6` reuse contract and `world06_7`
release gate to name the exception. Every consumer must declare whether it
trusts bare-authority fields. If the release gates retain host authority,
anti-forgery and exactly-once requirements, world06_2, world06_6 and world06_7
remain blocked or a named successor must restore those guarantees.

## 9. Owner record required to resume

The decision record must state exactly `A`, `B` or `C`, owner and timestamp. It
must additionally name:

- for A, the exclusive implementation owner, the owner-approved world06_1
  receipt-flow head/contract and the single exceptional-review authorization;
- for B, successor `world06_2b`, its owner, proposal-only field boundary and all
  held world06_6/world06_7 dependencies; or
- for C, exception `WORLD06_2-BARE-AUTHORITY-01`, exact trusted bare fields,
  target-id policy, consumer quarantine and every amended save/movement/cargo/
  receipt/world06_6/world06_7 claim.

Until that record exists, `b4b2f9f8` and `e4f4194f` remain frozen rejected
evidence. No agent may infer a choice, no partial may be called authoritative,
and the Integrator may not implement a resolution.
