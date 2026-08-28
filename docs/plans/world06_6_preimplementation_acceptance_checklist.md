# world06_6 Heist and Confrontation — Pre-implementation Acceptance Checklist

Status: binding checklist written before implementation acceptance  
Scope: `world06_6` only; this document changes no product code, runtime,
contract value, economy value, timing budget, or release state.  
Authority: `docs/todo/world06_6_heist_and_turn_staging_prompt.md`, the approved
heist and Turn sections of `docs/plans/0.6_living_world_roadmap.md`, the
`world06_1` adapter contract/checklist, the `world06_2` chase contract, the
archived `crew06_8` and `crew06_9` contracts, and the accepted `env06_6`
sealed-authority vocabulary.

## Blocking acceptance rule

Every box is blocking unless explicitly labeled evidence metadata. A caller's
claim is comparison material, never authority. A literal capability flag,
nested claim, substituted record, signed-looking envelope, self-issued receipt,
self-hash, or hash recomputed from caller content must never authorize a mount,
observation, route, confrontation, outcome, or consequence. Proposal identity
and proposal self-consistency are not capabilities. Without an authentic host
root, the operation must reject atomically or return an explicitly
non-authoritative, non-mutating proposal with the exact recorded authority gap.

## 1. Exact-head and invariant custody

- [ ] Record the reviewed implementation head, accepted dependency heads,
  commands, durations, report hashes, host, date, Godot identity, native-library
  identity, and independent reviewer.
- [ ] Prove the candidate changes no plan gating, phase boundary, real-session
  requirement, mixed-game requirement, chip-flow scoring, coordinated-play use,
  pursuit rule, clue emission rate, hidden selection weight, outcome math, RNG,
  reward, trust cost, heat, payout, schema, migration, or economy value.
- [ ] Attach before/after tables for both outcome ladders and all governing
  values. A moved value is rejection, not a documentation exception.
- [ ] Confirm all new public projections are derived, bounded, neutral, and
  absent from authoritative serialized state unless the binding adapter schema
  explicitly owns them.

## 2. Authentic host-root requirements

- [ ] For every accepted capability, record the immutable host root, room/node
  binding, owner, schema/kind, source provenance, content digest, live receipt,
  phase/boundary, and validation path that established it.
- [ ] Verify the root came from the exact live host inventory or owning-model
  result, not from a request, proposal, fixture, cache, renderer, save projection,
  log, capture, catalog possibility, or caller-recomputed digest.
- [ ] Verify seals and receipts are not portable across rooms, nodes, layers,
  phases, visits, plans, runs, owners, or restored instances.
- [ ] Verify the live host independently resolves the authoritative record and
  compares every caller field against it. No caller field may fill a missing host
  field or become authority by surviving normalization.
- [ ] Preserve the provenance chain in gate evidence. A pass without the exact
  authentic root and validation trace is incomplete.

## 3. Mandatory hostile authority matrix

For every evidence, route/chase, poker/public-observation, mount, command, and
outcome seam below, run all variants and prove zero authoritative mutation on
rejection:

- [ ] Literal claim: `authorized`, `authenticated`, `host_rooted`, `sealed`,
  `committed`, or equivalent boolean/string asserted by the caller.
- [ ] Nested claim: the same assertion hidden under capability, provenance,
  receipt, context, metadata, payload, result, or presentation objects.
- [ ] Substitution: valid-looking record with another run, node, room, layer,
  plan, phase, actor, route, action, visit, owner, or boundary substituted.
- [ ] Signed-looking claim: plausible signature, digest, nonce, timestamp,
  certificate label, or receipt shape with no authentic host verification.
- [ ] Self-issued identity: proposal id, action id, stable id, source id,
  content fingerprint, or receipt id supplied by the same caller requesting use.
- [ ] Self/recomputed hash: digest correctly recomputed over forged or altered
  caller content, including canonicalized and reordered forms.
- [ ] Transplant: authentic record copied from another valid run, node, phase,
  visit, owner, or outcome and paired with locally plausible fields.
- [ ] Restore attack: hostile fields persisted, normalized, saved, loaded, then
  presented as if restore had authenticated them.
- [ ] Partial truth: one authentic field combined with caller-authored missing
  fields, suffixes, aliases, fallbacks, or raw ids.
- [ ] Replay/change: exact receipt replay is idempotent; same receipt with any
  content change rejects atomically.

## 4. Evidence and public-observation seams

- [ ] Poker observation consumes only the landed public observation channel and
  authentic poker host provenance. Knowledge, tell, actor, or observation fields
  supplied by a caller cannot make a beat observable.
- [ ] Route discrepancy consumes only authenticated visited-world evidence.
  Claimed itinerary, node history, actor presence, timestamps, or route ids do
  not establish a contradiction.
- [ ] Payment discrepancy consumes only the authentic posted amount and settled
  handoff receipt. Caller-supplied posted/paid values, labels, hashes, or delivery
  snapshots cannot establish the observation.
- [ ] Each observation remains at its landed rate and boundary. Staging may not
  emit early, emit twice, improve detectability, expose absence, or reveal why a
  public line became available.
- [ ] A correctly read authenticated observation is actionable in the staged
  scene through the landed public path; observability without a usable player
  action fails. Exercise the poker observation against the landed `crew06_10`
  implementation, not a fixture or parallel tell producer.
- [ ] Public scene, actor, interaction, save, log, error, fixture, capture, and
  timing surfaces contain no hidden identity, weight, candidate set, resolution
  state, eligibility, evidence count, or forbidden semantic alias.

## 5. Route, pursuit, and chase authority

- [ ] Clean walk stays at zero pursuit across later action boundaries using
  authentic host outcome state; a caller cannot assert `clean`, `safe_exit`, or
  zero pursuit.
- [ ] Hot exit mounts only the accepted `world06_2` chase verbs from exact live
  route/position authority. A route hint, path suffix, alternate-exit label, or
  catalog route is not authority.
- [ ] `alternate_exit` and `safe_exit` remain separate explicit claims. Neither
  is inferred from labels, geometry, action copy, proximity, or the other flag.
- [ ] Cross-room, stale, ambiguous, unsealed, transplanted, or recomputed route
  authority rejects without pursuit, heat, travel, scene, or receipt mutation.
- [ ] Rejection preserves ordinary travel and the pre-attempt route, actor,
  objective, pursuit, and save state byte-for-byte.

## 6. Mount and confrontation authority

- [ ] Plan phases mount only from the exact live owner registration and sealed
  host inventory for that node/room/layer. A valid authored definition or
  proposal proves possibility, not live mount authority.
- [ ] The quiet confrontation surface appears only through an authentic neutral
  capability. Caller-supplied identity, observation list, count, capability
  token, or self-hash cannot make it appear.
- [ ] Two otherwise-identical observers without authentic capability are
  byte-equal and behavior-equal across public projection, serialized save,
  decoded key set, scene graph, actor state/order/pose, interactions, objectives,
  logs, errors, reports, captures, timing, allocations, scans, and work counters.
- [ ] The paired comparison covers a privately positive case and a privately
  negative case. Normalization may remove only explicitly public action history;
  it may not erase the distinguishing signal after measuring it.
- [ ] No public actor selection, absence, route, animation, timing, copy, or
  interaction order identifies a private candidate or whether one exists.
- [ ] Without authentic capability, the surface is absent or explicitly
  proposal-only/non-mutating; it must not mutate trust, state, phase, receipts,
  mounts, or logs.

## 7. Outcome and aftermath authority

- [ ] Right, wrong, and hedge aftermath apply only from an authenticated owning
  model outcome rooted in the exact live command, phase, actor choice, and
  receipt. Caller-authored outcome labels never apply consequences.
- [ ] Both plan-specific fracture beats and both mechanical failure beats are
  distinct, reachable, and selected only by authentic owning-model state.
- [ ] A presentation proposal, matching beat id, self-hash, or internally
  coherent outcome chain cannot grant a free play, change trust, alter odds,
  preserve a partial haul, add heat, end the run, or write aftermath.
- [ ] Cleanup completes before material aftermath; changed-content replay,
  transplanted aftermath, and restore-then-replay reject atomically.
- [ ] Every consequence is exactly once across save, load, exit, travel,
  revisit, abort, expiry, and each ordering around the terminal boundary.
- [ ] Other outcomes and private identities do not leak through durable keys,
  tombstones, receipts, cleanup differences, actor remnants, timing, or work.

## 8. Production-shape and composition negatives

- [ ] Play both plans end to end in production shape: planning, every authored
  phase, every decision at its authored boundary, the full setup and play, both
  exit classes, and every rung of both outcome ladders. The positive matrix must
  prove Plan A's planning table, floor, count, dock/corridor, and exit, and Plan
  B's planning table, mixed invitational tables, cage, interview, and exit.
- [ ] Plan A rejects early decisions, generic action counts, repeated actions
  presented as distinct sessions, wrong-game settlement, and fixture-only flags.
- [ ] Plan B rejects generic rounds in place of mixed craps/card play,
  unauthenticated chips, unrelated casino outcomes, replayed finite lifelines,
  and fixture-only component/vouch claims.
- [ ] Scenario, sweep, traveler, service, ordinary event, delivery cargo, and
  heist state compose without ownership collision or lost base functionality.
- [ ] Empty/non-heist boundary sync performs no mount, scan, registration, map
  rebuild, save drift, log, allocation, or measurable work.

## 9. Required evidence and verdict

- [ ] Retain every hostile input, authentic root, comparison trace, pre/post
  digest, exit code, duration, stdout/stderr, save, log, capture, and work count.
- [ ] Run the hidden-state paired audit on native and Web, after save/restore,
  after travel/revisit, and with reduced motion and accessibility paths.
- [ ] Run project, content, systems, UI, save, accessibility, determinism,
  native/Web, performance/liveness, Rourke duel, Players Card route, and visual
  gates on the exact candidate.
- [ ] Visual evidence explicitly covers the planning table, every phase of both
  plans, floor/count, dock, corridor, mixed invitational tables, cage, interview,
  clean walk, hot chase, quiet confrontation, hedge, both plan-specific fracture
  beats, both mechanical failure beats, reduced motion, and small screen.
- [ ] Any distinguishing signal, unauthorized mutation, moved contract value,
  double-fire, or missing authentic provenance is an automatic rejection.
- [ ] ACCEPT only after an independent reviewer checks every blocking item;
  otherwise record REJECT or BLOCKED with the exact unmet item.
