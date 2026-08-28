# crew06_10 immutable integration replay manifest

Status: **UNREVIEWED / docs-only / dependency-held / no closure claim**

Manifest base: GREEN main
`00ee744fa6269e8a7eb34f67b2659f32d55febaa`, tree
`8ae1554fd50fba705246bbe4da21ef28adead8af`.

This file freezes custody and a future replay procedure for the
Director-authorized crew06_10 partial successor. It does not accept the first
product, expand the partial verdict, infer an owner decision, assemble a
candidate, run a gate, change the board, authorize landing, or claim crew06_10
complete. All missing dependencies and evidence fail closed.

## Immutable custody

| Role | Exact commit | Exact tree | Binding disposition |
| --- | --- | --- | --- |
| First product | `678c3e2742fb0f1f93252b1ebd935a4248e85334` | `2c648e97a8d374b19cbb4c3c4a3666680979c1de` | **FIRST PRODUCT REJECTION**; provenance only, never a landing candidate |
| Corrected intake handoff | `4eef51f9230ce2705e36bafd88b9f93722b1200f` | `0100c8d5470b3fab046147d80accd8d739d0cbb9` | Docs-only corrected evidence provenance; not product, acceptance, or gate authority |
| Director-authorized partial successor | `339997729bcb1c5496fd1d9909da867f7ab09b83` | `f9574c471463906b7f5367f3f4dec6fd1dfbe79f` | Accepted by Primary only within the frozen partial boundary below; no full-row or landing acceptance |

The partial successor has consumed the row's second ordinary review. No third
ordinary review cycle is authorized. A later integration replay is a new
dependency-composition and exact-head gate subject; it must not silently reopen,
reinterpret, or broaden the accepted partial product verdict.

The corrected intake handoff records the first product as five files, 960
insertions and 13 deletions from product base
`855a296126e8b4747b78fbe89cb5a2d02daf61f5`. Its producer-reported focused
result has no retained exact-head/hash-bound artifact. Its retained validation,
load, and predecessor-red reports are historical context only and are not
qualifying evidence for either immutable product identity above.

## Frozen partial payload

The authorized remediation is the semantic difference from first product
`678c3e27...` to partial successor `33999772...`, exactly two files:

| Path | First-product blob | Partial-successor blob | Delta |
| --- | --- | --- | --- |
| `scripts/games/crew_draw_poker.gd` | `7c92fa7a4ef2eb1be75f1fd5950c267931a33d4e` | `f260d8851b79917ec86fbcd08811604c80abf4bd` | 195 insertions, 55 deletions |
| `scripts/tests/foundation/crew06_10_depth_contract.gd` | `5ce36d80883ce6faf2d099b6ba0f273b7f406963` | `9fc0982a066473a2e8229bee8969b5bc32bc90b9` | 470 insertions, 5 deletions |

Total frozen remediation delta: **two files, 665 insertions, 60 deletions**.
No product, test, board, ledger, environment, catalog, or owner artifact outside
these two paths belongs to the accepted partial remediation.

The immutable overlay checkpoint order is:

| Order | Commit | Tree |
| --- | --- | --- |
| 1 | `e36d39ce63ee420686a8b7a8dc7041a4f64fde30` | `058f8641288d927d8587e4192e3abe0e34263ac5` |
| 2 | `71a11ad06a70d05eb163040a5cf209c040013b01` | `7a68b4d6d4922242b0f8b88a32f092d5f6d8f618` |
| 3 | `c6b5a7f8c8cbbac965708ea7650daea751c349b0` | `90e7661faf99b7394ca510ea573b3abfcbc9af81` |
| 4 | `c8af239cddf5e26edc7952627da16ca5ddf5c030` | `d0e0360afde145ebe13b0bbc607dfd99229e2707` |
| 5 | `41a1e7c1b61f89c21777983cc3ca604a1f4b3f0a` | `2ebb3537454feb0e66a2d1fc6d28f9bee5271598` |
| 6 | `fc91c880e8709d298a397994fbb5cee72f1775ff` | `77779e6697229891764428785d85a325cbbf50e6` |
| 7 | `339997729bcb1c5496fd1d9909da867f7ab09b83` | `f9574c471463906b7f5367f3f4dec6fd1dfbe79f` |

These checkpoints preserve provenance and review reconstruction only. They are
not a cherry-pick plan and do not grant separate acceptance to intermediate
trees.

For future semantic reconstruction, the other three original row-payload blobs
are unchanged between the first product and partial successor:

| Path | Frozen blob | Status |
| --- | --- | --- |
| `data/games/rituals/crew06_10_poker_nights.json` | `c194dfbb76de82887f6089617c4a85a4bee284ee` | Rejected-product provenance; requires dependency assembly and new exact-head evidence |
| `docs/plans/crew06_10_policy_and_turn_engine.md` | `f72942d7bab8d3b9c066ad98e020c0f5a3c427f5` | Design provenance; not an authority root |
| `docs/plans/crew06_10_shared_assembly_manifest.md` | `a470b72694beb6b3c8591f8214758e7b18ebbfc7` | Historical assembly proposal; not authorization or evidence |

The five blobs above describe reconstructable source material, not an accepted
five-file product. The accepted verdict remains limited to the two-file partial
semantics and hostile proofs.

### Rejected game06_1 contract binding is not replay authority

Three frozen source locations hardcode game06_1 contract head
`a2760d816c781e711ff0923c296f97b786662453`, tree
`1df3d9b767d7490acdffb291ce5220c0b409127e`:

- `contract_head` in `data/games/rituals/crew06_10_poker_nights.json`;
- `Frozen contract` in `docs/plans/crew06_10_shared_assembly_manifest.md`; and
- the `_check_night_package` assertion in
  `scripts/tests/foundation/crew06_10_depth_contract.gd`.

The current owner record treats `a2760d81...` as a rejected game06_1 contract
head with unresolved validator P1s. Its historical presence in main ancestry
does not supersede that later rejection. Validator-closure branch head
`70568bdef8544bed76685ed43092b201cd5788e0`, tree
`1af94164dd3528bf03f7a55f9fcb51a516e638ff`, is not in manifest-base main
ancestry and is not inferred accepted or landable.

All three hardcoded bindings are mandatory game06_1-owned semantic rebase
points. Replay must replace them coherently only after an authentic replacement
contract is independently accepted and landed. That exact replacement
commit/tree is **MISSING / not yet representable**. Preserving `a2760d81...` to
obtain byte equivalence, or substituting `70568bde...` without a new accepted
and landed owner record, is prohibited. The candidate must not reproduce the
rejected `a2760d81...` assertion. Consequently no full five-file
byte-for-byte reconstruction or full-row claim is currently possible.

## Accepted partial boundary

Primary independently verified the exact partial identity and a clean static
two-file diff. Within that boundary only, the frozen successor establishes:

- after a player fold, ordered remaining-NPC play continues to legal NPC-only
  settlement; folded player cards are excluded from contenders, winner choice,
  hand evaluation, and tell learning;
- raw `pause`, `resume`, and `abort` room interruption inputs are non-mutating,
  non-authoritative typed proposals with zero bankroll/refund/application side
  effects and exact gap `host_room_interrupt_authority_unavailable`;
- caller-mintable generic game-command receipts cannot activate adaptive public
  memory; absent authentic memory authority preserves ordinary base policy and
  reports `host_poker_memory_authority_unavailable`;
- caller-mintable tell receipts, malformed/recomputed observations, and hostile
  restored observations cannot teach a tell; absent authentic observation
  authority reports `host_tell_observation_authority_unavailable`; and
- migration supplies inert defaults only and does not synthesize a host root,
  receipt, verified observation, refund, or application result.

This does **not** establish authentic poker-memory consumption, authentic tell
learning, authoritative interruption/refund application, environment mounting,
room aftermath, visual behavior, native/Web parity, accessibility, performance,
full exact-head gates, landing, or PostLand qualification.

## Missing authentic authority dependencies

Every row below is **BLOCKED / IDENTITY ABSENT**. No exact accepted-and-landed
commit/tree was provided at freeze time, so this manifest deliberately records
an empty immutable slot rather than naming a nearby implementation, generic
`ScenarioHostTransaction`, caller claim, self-hash, proposal, or post-commit
validator as authority.

| Required owner/root | Exact accepted-and-landed identity | Minimum authentic binding required | Current verdict |
| --- | --- | --- | --- |
| game06_1 public poker-session memory | **MISSING / not yet representable** | Host-produced and host-verified public action/card facts bound to run, seed, game/table, session/hand, phase, action ordinal, actor, receipt identity, source digest and authoritative lifecycle | BLOCKED; partial uses neutral base policy and exact unavailable gap |
| game06_1 tell observation/action-card provenance | **MISSING / not yet representable** | Authoritative action/card provenance or sealed observation bound to the same game/table/session/hand/phase/actor/action, with live host verification, hostile restore rejection and exactly-once learning receipt | BLOCKED; no tell mutation is authorized |
| env06_6 room interruption/refund authority | **MISSING / not yet representable** | Existing authentic environment host root binding run, seed, room/node/layer, visit, scenario, game/table/session/hand, disposition, refund/application result and exactly-once receipt | BLOCKED; pause/resume/abort remains proposal-only and side-effect-free |

The integration owner must populate each slot with the exact accepted source
commit, source tree, landed-main merge, landed tree, schema/blob identities, and
independent authority evidence before constructing a candidate. A new receipt
type minted inside crew06_10, a generic caller-mintable transaction, validation
performed only after mutation, or a second writer/self-hash is inadmissible.

If the landed dependency cannot represent one of these roots without changing
its owner contract, replay stops. That is a representability finding for
game06_1/env owner disposition, not permission for crew06_10 to invent the root.

## Semantic rebase and assembly order

The successor ancestry includes work outside the row-local payload. Therefore
neither `678c3e27...33999772` nor the full successor tree may be cherry-picked,
merged, or treated as a clean candidate range.

Replay from an exact clean current main in this order:

1. Record current main commit/tree and prove it descends from manifest base
   `00ee744f...`; stop if main is not qualifying green.
2. Record the accepted and landed game06_1 public-session-memory and tell-root
   identities. Verify their live host-validation API and exact receipt/schema
   blobs without adapting crew code yet.
3. Record the accepted and landed environment interruption/refund root. Verify
   that mutation and exactly-once application remain exclusively host-owned.
4. Reconstruct the three unchanged row-source semantics listed above against
   current-main catalogs and documentation, but replace the rejected
   `a2760d81...` JSON/document bindings with the exact accepted-and-landed
   game06_1 contract identity. Do not overwrite newer shared catalog entries or
   owner documentation.
5. Port only the accepted two-file partial semantics from successor blobs
   `f260d885...` and `9fc0982a...`, replacing the rejected `a2760d81...` test
   assertion with that same accepted-and-landed identity. Resolve all conflicts
   semantically against accepted dependency APIs; do not preserve obsolete
   ancestry merely to obtain a blob match.
6. Add the smallest owner-approved adapters that consume the already-landed
   authentic roots. Adapter ownership, files, commits, and reviewers must be
   declared before editing. No crew-local fallback may mint authority.
7. Register the poker-night catalog and foundation shard only through the
   current accepted shared assembly surfaces. Mount five production nights and
   aftermath behavior through the accepted environment owner surface.
8. Run a semantic overlap audit covering game/table/session lifecycle, action
   history, cards, RNG labels/order, bankroll/pot/refund, receipts, save/migrate,
   environment room transitions, observation queues, and tell memory.
9. Freeze a new candidate head/tree, tracked-clean status, base-to-head file
   manifest and artifact hashes. Independent integration review and all gates
   below must name that exact head/tree.

Any candidate edit after review invalidates affected review and gates. Any
missing dependency identity, semantic conflict, synthesized authority, broad
ancestry transplant, board edit, or product change outside declared ownership
stops replay and keeps the row dependency-held.

## Executable partial and hostile matrices

The successor test blob `9fc0982a...` statically contains the following frozen
partial matrices. These are source custody, not retained exact-head runtime
evidence; they must be replayed after authentic dependency assembly.

| Matrix | Frozen coverage | Required future extension |
| --- | --- | --- |
| Five night sequences / seven opponent profiles | Executable authored nights and seven distinct seeded opponent policies; public-memory response versus neutral fallback | Consume only verified host public memory; paired hidden-state neutrality before authorized disclosure |
| Raise/re-raise | Seeds search for a legal player raise followed by an NPC re-raise chain | Exact current candidate across all five production profiles and native/Web parity |
| Multi-NPC player fold | Player folds at an ordered turn; remaining NPC actions settle; player cannot win; memory remains unchanged | Paired hidden player-card variants with byte/behavior neutrality and restore/revisit |
| Interruption | `pause`/`resume`/`abort` crossed with literal claim, substituted accepted response, signed-looking recomputed digest, and cross-session request | Legitimate authentic host accept/refund/apply pair, replay, duplicate, stale phase, wrong room/session/visit, hostile restore, exactly once |
| Public memory | Missing receipt plus same-domain caller-minted game-command receipt compared with a neutral paired fixture | Legitimate host-rooted receipt, changed content, transplanted run/session/hand, duplicate, restore/revisit, bounded rollover |
| Tell observation | Blank receipt; malformed observation; coherently recomputed queue/history/cards with caller-minted same-domain receipt; stripped predecessor; restored hostile states | Legitimate sealed/authoritative observation, wrong actor/action/cards/phase, transplant, changed content, duplicate and exactly-once restore |
| Save/restore | Ordered mid-hand and settled state round trips; hostile tell states fail closed | Exact save bytes, schema migration, repeat restore, travel/revisit and authoritative receipt retention |

For every hostile case compare two otherwise-identical observers before and
after: complete run/save serialization, table state, cards and hidden state,
action history, observation queues, verified receipts, crew memory, bankroll,
pot/contributions, RNG state and consumption, environment state, logs/errors,
presentation, allocations, scans, timing and work counters. Rejection must be
non-mutating and must not create a distinguishing leak.

Required positive controls are coherent legitimate blank-receipt failure and a
live host-rooted success for each authority family. The blank case must remain
playable/neutral where specified while recording the exact unavailable reason;
it may not be reclassified as successful authority. A positive control is valid
only when the independent host observer proves the same receipt and exactly-once
mutation. Caller-visible success alone is insufficient.

## Held assembly, platform, and release gates

All gates below remain **BLOCKED / UNVERIFIED** until dependencies are landed
and a clean composed candidate exists. No result from `678c3e27...`,
`33999772...`, a predecessor, this docs branch, or another head may qualify.

- exact five-night production environment assembly, entry/exit, interruption,
  refund, cleanup, aftermath, travel/revisit and save/migration behavior;
- complete five-profile, raise/re-raise, multi-NPC-fold, public-memory, tell,
  interruption and hostile/paired matrix on the exact candidate;
- native Windows and shipped-Web import/load, focused product, shared game06_1,
  environment, systems, UI, save/migration, determinism and parity suites;
- keyboard, controller, pointer, direct-semantic and reduced-motion equivalence;
  focus order, labels, non-color cues, hit targets, text scale, small-screen and
  obstruction checks;
- low-end native/Web frame, draw, action-resolution, allocation, scan, save,
  revisit, maximal-composition and idle-liveness budgets;
- native and Web visual captures for all five nights, table states, every legal
  action, fold continuation, showdown, tell disclosure, interruption/refund,
  success/failure, cleanup, aftermath, restore/revisit, reduced motion and small
  screen, with unlabeled contact sheets and independent review;
- exact-head validation, GDScript load, focused foundation shard, relevant
  Foundation suites, Smoke, full project gate, artifact hash manifest and clean
  status; and
- depth06_1 exact-tree audit and player-facing build evidence on the composed
  candidate; and
- Integrator-controlled one-row-at-a-time landing followed by exact landed-main
  PostLand Smoke and ledger reconciliation.

Gate artifacts must bind candidate commit/tree, parent main, dependency merges,
Godot executable/version/hash, native/Web build and export hashes, harness and
fixture hashes, commands, environment, start/end/duration, exit/timeout/lifecycle
status, raw stdout/stderr/report/capture hashes, and independent verdict. No
local Godot or gate run is authorized by this manifest.

## Fail-closed replay verdict

Current replay verdict: **BLOCKED / PARTIAL CUSTODY ONLY**.

- First product `678c3e27...` remains first-rejected.
- Corrected handoff `4eef51f9...` remains provenance only.
- Successor `33999772...` remains accepted only for the frozen two-file partial.
- Genuine game06_1 poker-memory and tell roots are absent.
- Genuine environment interruption/refund authority is absent.
- Product assembly and all visual, native-Web, accessibility, performance and
  full exact-head gates are unrun and unverified.
- No full-row, product, gate, landing, PostLand, or program-completion claim is
  made, and no owner authority is inferred.

Future custody review may verify only that this docs-only manifest accurately
binds the immutable objects, gaps, and replay procedure. Such acceptance is not
crew06_10 product acceptance or authorization to assemble or land.
