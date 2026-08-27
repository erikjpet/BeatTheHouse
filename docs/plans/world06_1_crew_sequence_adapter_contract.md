# world06_1 Crew and World Sequence Adapter Contract

Contract version: pre-implementation draft 2, bound to env vocabulary handoff  
Audience: `world06_1` implementer and `world06_2` through `world06_6` consumers  
Ownership: knowledge artifact only. The other program lane retains exclusive
ownership of `world06_1`, the `EventModule` crew seam, and every crew/world
model named in program section 0.1.  
Acceptance companion:
`docs/plans/world06_1_adapter_preimplementation_acceptance_checklist.md`  
Executable companion:
`scripts/tests/foundation/world_sequence_adapter_spec_contract.gd`

## 0. Authority and current binding status

This contract fixes adapter invariants before the reference implementation
lands. It is derived from the binding `world06_1` prompt, the Family 2 launcher,
the `env06_6` prompt, and the landed hidden-state/no-op contracts. It deliberately
does not infer runtime field names from an in-progress `env06_6` implementation.

The normative behavior vocabulary arrived in
`D:\bth-env6\docs\todo\env06_6_runtime_vocabulary_and_delivery_handoff.md` at
commit `749390ce`. It is an implementation-independent contract handoff, not
env06_6 acceptance or landing authorization. Its referenced product head is
`06459402`; the retained content report has 78 failures. This contract consumes
the handoff's normative behavior only. Section 10 records concrete
spelling/API/schema values that remain unresolved because the handoff defines
behavior rather than filenames or a preferred implementation. Consumers must
not infer those values from the unaccepted product branch.

Contract words have their usual force: MUST/MUST NOT are acceptance conditions;
SHOULD requires written justification to depart; MAY is optional.

## 1. Seam inventory

The seam is every crew/world interaction that `EventModule` presents or routes.
The inventory below records current production reality before conversion. A
future implementation must machine-check this inventory against the source so a
new unclassified path fails validation.

### 1.1 Dynamic EventModule surfaces

| Surface | Producer and current choices | Outcome authority | Persistence / expiry / cleanup | Classification and disposition |
| --- | --- | --- | --- | --- |
| `crew_planning_table` | `RunState.crew_heist_table_choices()`; plan lock, table observation, confrontation/hedge, setup actions, abort | Existing heist/Turn APIs only | `crew_heist_state`; heist lifecycle; live-table registration cleanup | Scene decisions and objectives. Convert incrementally; no hidden value enters definition/state. |
| `heist_live_table` | `RunState.crew_heist_live_table_choices()`; due round decisions and phase exits | Existing heist APIs only | `crew_heist_state`, registered event marker; heist phase cleanup | Scene decisions at authored boundaries. Convert; never pre-present later decisions. |
| `crew_job_board` | `RunState.crew_job_board_choices(payload)`; available definitions plus leave | `crew_job_accept_definition()` | `crew_jobs`, definition expiry action, job completion/abandon cleanup | Object transaction to accept, followed by objective sequences. Convert board and real job work. |
| `crew_practice_rig` | `crew_practice_rig_choices()`; timing windows | `crew_practice_rig_session(window)` | Existing training/crew state; action-boundary availability | Altered game/task at a semantic rig. Convert. |
| `crew_stake_horse_loss` | `crew_stake_horse_loss_choices()`; repay or shrug | `crew_resolve_stake_horse_loss(choice)` | Pending stake-loss state; resolves once | Genuine consequential scene decision. Convert; preserve exact cash/trust/grievance effects. |
| `crew_collection_press` | `crew_collection_choices()`; take cash or press | `crew_resolve_collection(choice)` | Pending collection state; resolves once | Genuine consequential scene decision. Convert. |
| `crew_rook_ride` | computed call/leave or unavailable acknowledgement | `crew_rook_begin_ride()` | run flags track day, uses, and active route discount | Vehicle/object transaction. Convert call/start; unavailable/leave may remain acknowledgement. |
| `crew_mags_bench` | `_mags_bench_choices()` projects five catalog crafts plus leave | ordinary event delta path (cash and inventory) | inventory/cash are authoritative; no parallel adapter ledger | Object transactions at the bench. Convert one catalog entry at a time without changing recipes. |
| `recruitment_rook_signpost` | `CrewRecruitmentModel.rook_signpost_choices(run)` | ordinary consequences and recruitment hooks | recruitment flags/model state; event lifecycle | Scene signpost/lead. Convert actionable lead; plain leave remains a choice. |
| `recruitment_rook_leads` | `rook_signpost_choices(run, false)` | ordinary consequences and recruitment hooks | recruitment flags/model state; event lifecycle | Scene objective/lead. Convert. |
| `crew_contact_rook`, `crew_contact_switch`, `crew_contact_mags`, `crew_contact_knuckles`, `crew_contact_velvet`, `crew_contact_bishop`, `crew_contact_lucky` | `CrewRecruitmentModel.contact_choices(...)` | existing contact/recruitment/job APIs | recruitment and job state; event lifecycle | Genuine dialogue may remain choices; transactions/tasks become object/objective interactions. Classify each emitted option in validation output. |

### 1.2 Data-backed EventModule surfaces

| Surface(s) | Current choices / producer | Outcome and persistence | Classification and disposition |
| --- | --- | --- | --- |
| `recruitment_switch`, `recruitment_mags`, `recruitment_knuckles`, `recruitment_velvet`, `recruitment_bishop`, `recruitment_lucky` | Authored work/wait/leave choices in `events.json` | ordinary consequence path, recruitment hooks and story flags | Recruitment encounters. Work/action becomes sequence; genuinely conversational refusal/wait may remain choice. |
| `crew_favor_delivery` | `run_package` / `refuse`; special route start through `resolve_crew_favor_delivery_job()` | delivery snapshot plus existing success/failure consequences and crew-favor flags | Route objective for package; refusal is a genuine dialogue choice and may remain. |
| `numbers_desk` | `read_the_books` / `leave_the_book` | current event flag; Numbers model remains authority | Object transaction and public book state. Convert read; leave may remain. |
| `numbers_knuckles_collection` | `take_the_marker` acknowledgement | Numbers/debt state is already applied; event flag only | One-line acknowledgement, not a sequence by itself. World06_3 may stage surrounding collection but must not fake a second outcome. |
| `numbers_lucky_swept_collection` | `take_luckys_blame` acknowledgement | grievance/Numbers consequence already authoritative; event flag only | Genuine dialogue acknowledgement; may remain a choice unless embedded in a larger honest scene. |
| `police_sweep_pass_over`, `police_sweep_shakedown`, `police_sweep_confiscation`, `police_sweep_travel_lock`, `police_sweep_punchline_l2_near_miss`, `police_sweep_adjacent_sighting` | one `continue` acknowledgement each; consequences are applied by `police_sweep_model`/boundary code before presentation | sweep model/world-map state, ordinary event-resolution cleanup | The acknowledgement itself stays a choice. World06_5 stages the encounter around it; the adapter must not reapply sweep economics. |

### 1.3 Event hook routing owned by the seam

The pre-result side of `EventModule.apply_event_result()` currently routes
`crew_switch_reveal`, `crew_knuckles_stash`, `crew_knuckles_retrieve`,
`crew_lucky_collection`, `crew_job_accept`, `crew_practice_rig`,
`crew_stake_loss_choice`, `crew_collection_choice`, `crew_rook_ride`, and
`crew_heist`. The post-result side routes `crew_recruit`, `crew_meet`, and
`crew_rook_lead_closed`. `crew_favor_delivery` also has a dedicated result path.

Each becomes a registered **outcome channel**, not an arbitrary model method
name in authored data. `hear_rumor`, ordinary event resolution, services,
travelers, and other non-crew hooks remain on their existing path and compose
with the adapter.

### 1.4 Explicit non-seam systems

Coordinated plays, delivery/Numbers boundary updates, and Police Sweep movement
have model APIs outside `EventModule`. Family 2 may mount their public moments
through this adapter, but `world06_1` MUST NOT move their authority into
`EventModule` or duplicate their state. Grand Casino showdown/cashout helpers
are not crew sequence adapter surfaces merely because they contain an optional
crew condition.

## 2. Source envelope and shared vocabulary

A crew/world sequence is an `env06_6` sequence with a different trusted source.
It MUST enter the same validator and runtime used by an environment scenario.
There is no crew-only phase graph, operation registry, layout resolver,
snapshot, transition engine, or cleanup engine.

The conceptual declaration contains:

```text
contract_version
sequence_id
source { domain=crew_or_world, owner_id, definition_id }
mount { node selector, semantic zone, registration policy }
local_state_schema
phase_graph
scene_ops
interaction_ops
actor_ops
objectives
transition_ops
reentry_policy
expiry
cleanup
aftermath
mechanic_tags
sequence_signature
ownership_claims
outcome_channels
private_capabilities
```

The first fourteen sequence fields mean exactly what the normative `env06_6`
handoff says. Adapter fields add source, ownership, feedback, and private
capability routing only. Exact spelling and concrete registry APIs remain
pending in section 10; their behavior is already bound.

Authored declarations MUST NOT contain arbitrary code, reflection targets,
model method names, raw node paths, screen coordinates, or resource paths
outside shared allowlists. All objects, actors, interactions, zones, handlers,
facts, outcomes, and private capabilities use registered ids.

## 3. Ownership and composition

### 3.1 Ownership layers

Every semantic write is keyed by node, semantic target, component/property, and
owner token. Non-scenario targets require exact room-bound sealed host
authority; catalog possibility and caller route/anchor hints are never instance
authority. Owners are separate:

1. base environment;
2. environment scenario;
3. crew/world sequence;
4. transient world pressure such as a sweep or traveler;
5. ordinary event/game/service interaction.

Base geometry and required exits are immutable unless the shared runtime marks
the target as safely overridable. An adapter never obtains ownership merely by
executing later.

### 3.2 Conflict rule

There is no broad last-writer-wins precedence. Two compatible claims compose:
different targets, different independent properties, or a shared collection
whose registry explicitly supports multiple owners. Two exclusive claims to the
same target/property are an authoring-time validation error. A temporary
world-pressure overlay may visually cover a target only through a registered
overlay property; it cannot steal persistent ownership or suppress a clean
exit.

Removal and cleanup are owner-scoped. A crew sequence can remove only values it
mounted, never the base object or another active sequence's values. Aftermath
is a separately declared owner-scoped persistent claim, not leftover temporary
state.

### 3.3 Interaction coexistence

Interaction ids are namespaced by owner while their semantic target ids remain
stable. Priority affects presentation ordering only; it cannot bypass
availability, cost, objective, or ownership validation. Games, services,
ordinary events, travelers, and sweep pressure remain addressable. Competing
exclusive hit regions or retargets fail validation.

An augment contributes actions to its authoritative target and never becomes a
separately addressable host action. Presented actions retain exact origin owner
and stable identity, operation receipt, boundary, and content fingerprint. The
runtime authenticates these against the live resolved interaction; caller
values are comparison material only. `alternate_exit` is an explicit authored
property, separate from `safe_exit`, reachability, label, or action text.

## 4. Lifecycle

The adapter lifecycle is:

```text
eligible -> mounted -> running -> terminal
                    \-> abandoned
                    \-> expired
terminal|abandoned|expired -> cleanup_pending -> cleaned
```

- **Eligible** is a pure boundary query. It creates no registration or state.
- **Mounted** allocates an owner token and shared-runtime instance at a named
  node only after the owning model publishes a public mount fact.
- **Running** advances solely on validated player/world facts at action or
  deterministic town boundaries.
- **Terminal** has a material branch result but is not considered applied until
  its outcome receipt is acknowledged by the owning model.
- **Abandoned** and **expired** follow authored resume/fail/cancel policy. An
  expiry without policy is invalid.
- **Cleanup pending** retains enough receipts to retry idempotently.
- **Cleaned** has no temporary object, actor, interaction, hit region, service
  override, route claim, handler registration, or transition effect remaining.

Save/load, exit, travel away, and revisit preserve shared-runtime state. Reentry
projects the already-achieved state and MUST NOT replay rewards, model feedback,
dialogue, audio, or one-shot transitions. Cleanup scans are forbidden unless a
persisted registration marker proves a crew/world sequence mounted.

Command-entered phases receive exactly one immediate turn-boundary grace so the
command's own world boundary is not counted twice. Fact-entered phases receive
no command grace. Stage expiry still follows the real world boundary when phase
progression consumes that grace.

The owning crew/world system ending forces its mounted sequence toward the
authored abandon/expiry state and cleanup. Adapter state never prolongs the
model's own expiry.

## 5. Authoritative action and outcome path

### 5.1 Command path

All public verbs route through the shared `env06_6` command/result boundary.
The runtime validates instance, phase, target availability, objective
preconditions, cost preview, ownership, and idempotency before state changes.
The adapter cannot call a model directly from JSON.

Every command or fact is a closed **cause** envelope with exact receipt key,
boundary, and canonical content fingerprint. Reusing a receipt with different
content rejects atomically. Branch records bind phase, branch, trigger kind,
trigger receipt and fingerprint, cause fingerprint, and target phase or
terminal outcome.

### 5.2 Outcome channels

An adapter registry maps a public outcome channel id to one existing owning
model API. The mapping lives in trusted code, not authored data. Each channel
declares:

- owning domain and accepted public payload schema;
- allowed lifecycle/phase and outcome kinds;
- deterministic/idempotent application contract;
- persisted receipt namespace;
- public result projection;
- cleanup or retry behavior.

Trust, grievance, job state, delivery state, heat, money/costs, Numbers state,
sweep state, recruitment, play state, and heist state remain authoritative in
their landed owners. The adapter stores no shadow balance, trust ledger,
grievance ledger, job, route, draw, sweep, play, or heist state.

### 5.3 Exactly-once handshake

The shared runtime emits a stable owner-scoped outcome receipt. The adapter
checks its persisted acknowledgement, submits the public payload once, records
the owning model's acknowledgement atomically at the boundary, and then marks
the runtime receipt consumed. Replaying any step returns the recorded public
result without applying the consequence again. Save/reload between every pair
of steps MUST be tested.

EventModule retained choices continue through their existing result path. A
system can convert one interaction without converting its siblings.

## 6. Hidden-state isolation

### 6.1 No hidden state in the adapter

The adapter has no hidden-state storage. A definition, phase, object, actor,
interaction, objective, operation, receipt, save key, log, error, capture,
fixture, or report MUST NOT name or encode:

- traitor identity or candidate pool;
- whether anybody turned;
- grievance kind, weight, source, or ledger length;
- hidden resolution state or private RNG;
- clue eligibility/emission internals;
- any model-private member id selected from hidden state.

Opaque hashes are not sufficient if equality, length, ordering, timing, or
presence distinguishes cases.

### 6.2 Neutral capabilities

Where a public sequence must react to private state, authored data names a
stable neutral capability such as `private_condition_01`. That id is identical
for every hidden case and conveys no identity or semantic meaning. Trusted
registry code owned with the model decides whether the capability may emit an
already-authorized **public fact** at the current boundary. Before authorized
disclosure, it emits nothing and persists no adapter result.

Definitions cannot choose an actor, object, branch, line, route, pose, timing,
or ordering from a private result. At the Turn's own disclosure boundary, the
existing model API may publish the public confrontation result already allowed
by its landed contract; the adapter stages that public result without retaining
the private cause.

### 6.3 Differential leak proof

For the same public seed-independent action history, capture one internal run
where a member turned and one where nobody did. Before authorized disclosure,
the complete adapter-owned serialization and all public surfaces MUST be
byte-identical. Compare key sets and values, scene graph, prepared render model,
actor ids/order/positions/poses, interactions, objectives, receipts, logs,
errors, reports, captures, registration/work/liveness counters, and timing
classes. The owning model's existing private save envelope is not copied into
adapter evidence and receives its own landed hidden-state audit. Any adapter
distinguishing signal is P0.

## 7. Determinism, no-op, and performance

- Eligibility is a pure query at a boundary. A crew-ignoring run mounts no
  sequence, performs no scan, registers nothing, rebuilds no node, changes no
  bytes, and adds no measurable cost.
- `crew_ignored_golden_probe.gd` is extended in place. No parallel golden or
  broadly stripped comparison is acceptable.
- Randomness comes from the run RNG through the shared fact/command boundary.
  No wall-clock value influences authority.
- No per-frame schema evaluation, eligibility scan, node reconstruction,
  ownership scan, receipt poll, or deep copy is allowed.
- Native and Web produce identical sequence state, layout, actor routes,
  results, receipts, and cleanup for the same seed/actions.
- Idle measurement includes a liveness counter. A 0.000 result without liveness
  proof fails.
- Persistent authority never round-trips derived route points, geometry,
  z-order, action tokens, availability projections, renderer snapshots, layout
  resolution, or audit projections.
- Renderer preparation fails closed: every public presentation collection is
  empty on error (`visual_objects`, `interaction_overlays`, `services`, `games`,
  `routes`, `active_stages`); only typed errors and safe non-content metadata
  may remain.

## 8. Validation errors

The shared validator MUST reject, with source location and stable error id:

1. unknown or wrong-version vocabulary;
2. unknown source owner/definition, node selector, zone, target, operation,
   handler, fact, outcome, or capability;
3. raw node path, coordinate, arbitrary code/reflection target, model method, or
   unallowlisted resource;
4. duplicate ids or an exclusive ownership conflict;
5. an outcome without one owning channel or a channel used from a forbidden
   phase;
6. missing cleanup for any temporary claim or orphaned hit region;
7. unreachable phase/objective/terminal branch;
8. expiry without explicit resume/fail/cancel and cleanup policy;
9. transition or feedback receipt without stable idempotency scope;
10. hidden semantic names, private member-dependent public state, or any
    equality/presence side channel;
11. sequence signatures that amount only to a choice list, reward/flag grant,
    metadata/tint/text change, or fixture-only producer;
12. proof conversion special-cases by event id, member id, node, or model.

## 9. Proof conversion contract

The implementation converts exactly one smallest genuine production
interaction. The recommended candidate is one real `crew_job_board` package-run
job because it demonstrates an object transaction, mounted route objective,
owning-model feedback, save/revisit, and cleanup. This recommendation is not an
authorization to change job or delivery contracts; the other lane may select a
smaller genuine candidate after its seam audit.

The proof MUST include:

1. an object/actor/interaction that exists in semantic scene state;
2. at least one public player verb/objective beyond selecting the old choice;
3. mount and play at a real production node;
4. feedback through the existing owning API and a stable exactly-once receipt;
5. save/load, exit/travel, revisit, completion or refusal, applicable expiry,
   and complete temporary cleanup;
6. an active environment scenario at the same node;
7. unchanged ordinary travel, event, service, traveler, sweep, and base room
   behavior;
8. keyboard, controller, reduced-motion, small-screen, and obstruction proof.

A proof-specific adapter branch is a design rejection. The worked example can
be made binding only after the `ENV-BIND-*` appendix is resolved.

## 10. Concrete env06_6 binding appendix

The handoff binds the behavior summarized by these rows. Since it deliberately
does not prescribe filenames or a preferred implementation, concrete spellings
and entry points remain unresolved and MUST NOT be guessed from product code.

| Binding id | Required concrete value | Status |
| --- | --- | --- |
| `ENV-BIND-01` | Contract/version field spelling, accepted value, and negotiation API (versioned behavior is bound) | CONCRETE BINDING UNRESOLVED |
| `ENV-BIND-02` | Root sequence definition envelope, required/optional keys, defaults, and unknown-key policy | UNRESOLVED |
| `ENV-BIND-03` | Stable sequence instance id and owner/source namespace format | UNRESOLVED |
| `ENV-BIND-04` | Node, semantic object, anchor/zone, actor, interaction, service, and route selector formats | UNRESOLVED |
| `ENV-BIND-05` | `local_state_schema` type vocabulary, default encoding, mutation commands, and validation rules | UNRESOLVED |
| `ENV-BIND-06` | `phase_graph` node/edge/condition/branch/terminal schema and compatibility `advance_after_actions` representation | UNRESOLVED |
| `ENV-BIND-07` | Registered `scene_ops` ids and the common operation envelope/result | UNRESOLVED |
| `ENV-BIND-08` | Registered `interaction_ops` ids, prompt/action-set schema, service retargeting, and hit-region ownership | UNRESOLVED |
| `ENV-BIND-09` | Registered `actor_ops` ids, actor source/position/route/pose/behavior schema | UNRESOLVED |
| `ENV-BIND-10` | Objective schema, public progress facts, completion/failure/refusal/ignore/cancel encodings | UNRESOLVED |
| `ENV-BIND-11` | Transition op schema, deterministic beat timing, cue ids, and one-shot receipt behavior | UNRESOLVED |
| `ENV-BIND-12` | Reentry policy enum/shape and partial/terminal projection rules | UNRESOLVED |
| `ENV-BIND-13` | Expiry clocks/facts, policy enum, boundary evaluation order, and resume/fail/cancel semantics | UNRESOLVED |
| `ENV-BIND-14` | Cleanup declaration, owner-scoped removal schema, cleanup receipt and retry semantics | UNRESOLVED |
| `ENV-BIND-15` | Aftermath declaration and persistent scene/actor/service/game property ownership | UNRESOLVED |
| `ENV-BIND-16` | Mechanic tags, authored `sequence_signature`, normalized signature algorithm/output, and uniqueness thresholds | UNRESOLVED |
| `ENV-BIND-17` | Typed fact envelope, publisher registry, delivery/safe-boundary order, deduplication, and persistence | UNRESOLVED |
| `ENV-BIND-18` | Authoritative command/result boundary API, error ids, cost preview, idempotency key, and replay response | UNRESOLVED |
| `ENV-BIND-19` | Handler registry declaration, input/output/persistence/RNG contracts, and allowlists | UNRESOLVED |
| `ENV-BIND-20` | Snapshot placement and exact shapes for phase/local/objective/scene/actor/interaction/branch/transition/cleanup receipts | UNRESOLVED |
| `ENV-BIND-21` | Ownership/conflict key, shared-versus-exclusive property declarations, overlay rules, and validation error ids | UNRESOLVED |
| `ENV-BIND-22` | Validator entry point/report schema and source-location representation for crew-sourced definitions | UNRESOLVED |
| `ENV-BIND-23` | Legacy/no-sequence compatibility guarantees exposed to an adapter and the no-op registration marker | UNRESOLVED |
| `ENV-BIND-24` | Native/Web parity serialization/canonicalization requirements and prepared render/layout snapshot contract | UNRESOLVED |

## 11. Consumer authoring boundary before bindings resolve

Family 2 authors MAY prepare inventories, semantic targets, actor/object intent,
public verbs/objectives, phase diagrams, outcome-channel intent, cleanup tables,
unchanged-value tables, capture plans, and negative tests against sections 1
through 9. They MUST label any serialized example `NON-BINDING INTENT` and MUST
NOT commit production JSON/GDScript using provisional env vocabulary. Once the
handoff resolves section 10, this document and its executable companion receive
an independent contract review; Family 2 implementation may then begin against
the accepted knowledge without waiting for the `world06_1` reference
implementation to land.
