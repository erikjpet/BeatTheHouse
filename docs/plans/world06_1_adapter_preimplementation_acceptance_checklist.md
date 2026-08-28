# world06_1 Crew Sequence Adapter — Pre-implementation Acceptance Checklist

Status: independent checklist written before product implementation  
Scope: acceptance criteria for the future `world06_1` implementation; this
document neither claims that row nor authorizes edits outside the other lane's
exclusive crew/world ownership.  
Authority: `docs/todo/world06_1_crew_sequence_adapter_prompt.md`, the Family 2
launcher, the program prompt, and the landed hidden-state contracts.  
Contract dependency: normative behavior handoff `749390ce`, with all 24 concrete
bindings resolved against the owner-authorized frozen, green env06_6 head
`855a296126e8b4747b78fbe89cb5a2d02daf61f5`. The older `06459402` 78-failure
report remains historical evidence and is not the implementation base.

## Independent acceptance rule

Acceptance requires all blocking boxes below to be checked by a reviewer who
did not implement the row. A staged room followed by the old choice list, a
fixture-only conversion, a hidden-state distinguishing signal, a consequence
that can fire twice, or measurable work on a crew-ignoring run is an automatic
rejection regardless of other results.

## 1. Inputs and exact-head discipline

- [ ] The implementation is based on frozen env06_6 head `855a2961` or an
  independently reviewed compatible successor; landing on main is not a start
  precondition.
- [ ] The reviewer records the implementation head, `env06_6` merge/head, native
  plugin hash, commands, durations, and evidence paths.
- [ ] The adapter consumes the normative vocabulary at `749390ce` and exact
  `ENV-BIND-01..24` appendix, not provisional names or a crew-only vocabulary.
- [ ] Every concrete binding matches the frozen env implementation and the
  executable binding test; any successor drift updates/reviews the contract
  before product code adopts it.
- [ ] No crew/world model contract, tuning value, economy value, outcome ladder,
  clue rate, grievance weight, or hidden resolution rule changed.

## 2. Complete seam inventory

- [ ] Every crew/world interaction reaching the player through `EventModule` is
  inventoried with producer, entry point/action id, choices, outcome API,
  persistence, expiry, and cleanup.
- [ ] Each inventory row is classified as scene decision, object transaction,
  objective/task, or genuine dialogue choice.
- [ ] Every retained choice has a specific reason; one-line acknowledgements and
  genuine dialogue are not forced into sequences.
- [ ] Every converted row names its destination node, semantic objects, actors,
  public verbs/objectives, outcome receipt, and owning model callback.
- [ ] The inventory is machine-checked against the enumerated `EventModule`
  action/choice surface so an unclassified interaction fails validation.

## 3. Adapter data and shared validation

- [ ] Crew data can declare the accepted `env06_6` sequence vocabulary without a
  crew-only copy of the runtime or validator.
- [ ] The declaration covers scene, interaction, actor, objective, transition,
  reentry, expiry, cleanup, aftermath, mechanic metadata, and normalized
  signature fields required by `env06_6`.
- [ ] Definitions contain no arbitrary code, reflection target, raw node path,
  unallowlisted resource path, screen coordinate, model method name, or hidden
  semantic name.
- [ ] Handlers, facts, operations, ownership, outcomes, and receipts implement
  the handoff's closed, bounded, canonical, path-safe vocabulary.
- [ ] The same validator rejects invalid scenario-catalog and crew-sourced
  definitions consistently; source location does not create a weaker path.
- [ ] Conflicting scene/object/interaction/actor ownership, unowned outcomes,
  missing cleanup, unreachable objectives, and expiry without policy each fail
  loudly at authoring time.

## 4. Composition and precedence

- [ ] Runtime storage is a generic persisted owner-scoped instance map keyed by
  `source_domain::owner_id::definition_id::public_instance_token`; source domain
  is `crew|world`, semantic owner namespace stays separate, and every instance
  has independent env runtime state with no proof/event/model/node special-case.
- [ ] A crew sequence and environment scenario can coexist at one node without
  replacing each other's snapshot state, interactions, services, actors, or
  aftermath.
- [ ] Base environment ownership, environment-scenario ownership, crew ownership,
  and transient world-pressure ownership are separately addressable.
- [ ] Precedence is deterministic and narrow: compatible operations compose;
  exclusive writes to the same semantic property are validation errors rather
  than last-writer-wins behavior.
- [ ] Object/property conflicts use exact owned identities and sealed host
  authority; caller hints and priority cannot manufacture authority.
- [ ] Ordinary travel, event, game, service, traveler, Police Sweep, and base
  environment functionality remain available at every mountable node.
- [ ] A composed save/load round trip is byte/semantic stable and does not replay
  one-shot staging, rewards, audio, dialogue, or model feedback.

## 5. Lifecycle and exactly-once behavior

- [ ] Mount, run, complete, abandon, expire, and cleanup are defined state
  transitions at action or deterministic town boundaries only.
- [ ] Save, exit, travel away, revisit, abort, and expiry are exercised immediately
  before and after every material boundary.
- [ ] Local state, phase, objectives, scene/actor/interaction state, resolved
  branches, transition receipts, outcome receipts, and cleanup receipts survive
  rehydration without replay.
- [ ] The owning system ending removes every temporary object, actor,
  interaction, hit region, service override, and registration marker while
  preserving authored aftermath.
- [ ] Outcome receipts are stable, persisted, owner-scoped, and idempotent; trust,
  grievance, job/delivery state, heat, cash/costs, and aftermath each apply
  exactly once.
- [ ] Receipts bind an exact boundary and canonical content fingerprint; changed
  content under a reused receipt rejects and cleanup/replay is transactional.
- [ ] Interactions retained in `EventModule` are byte/behavior compatible, and
  conversion can proceed one interaction at a time.

## 6. Hidden-state isolation — blocking audit

- [ ] Public definitions, scene/object/actor/interaction state, objectives,
  receipts, serialized keys, captures, logs, errors, fixtures, and reports use
  only neutral opaque channels; none names or encodes traitor identity,
  grievance kind/weight, candidate pool, hidden resolution, clue eligibility,
  or whether anybody turned.
- [ ] Sequence authors receive only a public capability/fact token and neutral
  result class; they cannot query private crew state or select an actor/object
  from a private identity.
- [ ] Hidden evaluation remains inside the owning model's existing API. The
  adapter transports a neutral request/result and never reads `crew_heist_state`
  private data or the grievance ledger.
- [ ] Full-observer captures for paired runs (turned member versus no turn) are
  indistinguishable before contract-authorized disclosure after normalizing
  only explicitly public action history.
- [ ] The paired comparison covers saved bytes, decoded snapshot structure and
  key set, scene graph, render model, actor state/order/poses, interactables,
  objectives, receipts, logs, errors, reports, captures, fixture names, and
  timing/work counters.
- [ ] Forbidden semantic probes include at least `traitor`, `betrayal`,
  `the_turn`, `grievance`, `clue`, member ids on private channels, and aliases or
  hashed values whose equality still distinguishes cases.
- [ ] Existing clue channels remain honest and are not made easier or harder to
  infer by staging.
- [ ] Any distinguishing signal is reported as P0 and blocks acceptance.

## 7. No-op, determinism, and performance

- [ ] A crew-ignoring run mounts nothing, scans nothing, registers nothing,
  rebuilds no map nodes, changes no serialized bytes, and adds no measurable
  cost.
- [ ] `crew_ignored_golden_probe.gd` is extended in place; no parallel or weaker
  golden check substitutes for it.
- [ ] Cleanup or boundary sync scans only when a persisted registration marker
  proves that a crew sequence mounted.
- [ ] Identical seed plus actions yields identical definitions, layouts, actor
  routes, states, receipts, results, and cleanup on native and Web.
- [ ] RNG comes from the run stream at explicit boundaries; no wall-clock input,
  per-frame schema evaluation, per-frame scanning, or per-frame deep copy exists.
- [ ] Idle performance includes the liveness counter-gate; a reported 0.000 cost
  without liveness evidence fails.

## 8. Real proof conversion

- [ ] Exactly `crew_favor_delivery/run_package` is converted;
  the proof is not a fixture, one-line acknowledgement, reward-only action, or
  room staging around the old choice list.
- [ ] `crew_favor_delivery/refuse` remains on its honest EventModule dialogue
  path, mounts no instance, and preserves its exact shipped refusal effect.
- [ ] The proof demonstrates a real semantic scene/actor/object change, public
  player verb or objective, meaningful outcome feedback through the owning
  model's existing API, and visible branch aftermath.
- [ ] It demonstrates mount, play, save, exit/travel, revisit, completion or
  refusal, expiry where applicable, cleanup, and composition with an active
  environment scenario at the same node.
- [ ] No special-case exists for the proof's action id, crew member, node, or
  model. A required special-case is an adapter design rejection.
- [ ] The worked example in the contract matches production data and the tested
  conversion exactly.
- [ ] The trusted `delivery_handoff` channel preserves success
  (+22 bankroll, +4 heat, completion flags and existing trust behavior) and
  failure (+9 heat and failure flags) exactly once; mount/start applies none.

## 9. Required negative tests

- [ ] Conflicting semantic scene/property ownership rejects.
- [ ] Duplicate or shadowed interaction/actor/object ids reject.
- [ ] Unowned or unregistered outcome channel rejects.
- [ ] Missing cleanup or orphaned hit region rejects.
- [ ] Unreachable objective/phase rejects.
- [ ] Expiry without resume/fail/cancel policy rejects.
- [ ] Hidden-semantic identifiers and identity-dependent public definitions
  reject.
- [ ] Duplicate outcome receipt/replay cannot double-apply.
- [ ] A definition that is only a choice list, reward grant, metadata/tint/text
  change, or fixture-only producer fails the proof requirements.

## 10. Gate evidence required for acceptance

- [ ] Project validation and relevant foundation contract/system/content/UI/save
  suites pass on the exact head.
- [ ] The shared validator suite and every negative test above pass.
- [ ] Composition and exactly-once matrices pass in every required ordering.
- [ ] Hidden-state paired indistinguishability audit passes and records the exact
  compared surfaces and digests.
- [ ] Extended crew-ignoring golden probe passes byte-for-byte.
- [ ] Ten-seed determinism and native/Web parity pass.
- [ ] Performance, idle liveness, accessibility, reduced-motion, controller, and
  keyboard checks pass.
- [ ] Visual QA covers entry, objective/action, branch aftermath, revisit,
  cleanup, active environment-scenario composition, reduced motion, small
  screen, and obstruction/hit-target overlays.
- [ ] Evidence records exact commands, exit codes, durations, report/capture
  paths, native plugin hash, implementation head, and reviewer identity.

## Reviewer verdict

- [ ] ACCEPT — every blocking item is satisfied on the recorded exact head.
- [ ] REJECT — findings list the smallest reproducible contract violation.
- [ ] BLOCKED — only for an unresolved owner decision or missing authoritative
  vocabulary handoff; the report names the exact binding and compatible work
  already completed.
