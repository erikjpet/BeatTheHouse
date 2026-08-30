# world06_1 Crew and World Sequence Adapter Contract

Contract version: 1, concrete bindings resolved against frozen env06_6 head
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
the `env06_6` prompt, and the landed hidden-state/no-op contracts. The owner
authorized implementation against frozen, green env06_6 head
`855a296126e8b4747b78fbe89cb5a2d02daf61f5`; section 10 binds the adapter to
that exact API and schema surface.

The normative behavior vocabulary arrived in
`D:\bth-env6\docs\todo\env06_6_runtime_vocabulary_and_delivery_handoff.md` at
commit `749390ce`. It remains the normative behavior authority. The referenced
older product head `06459402` and its retained 78-failure content report are
historical evidence, not the implementation base. The owner-authorized frozen
head `855a2961` resolves the concrete spellings and APIs in section 10 without
changing the handoff's behavior.

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

### 3.4 Generic owner-scoped multi-sequence composition

The frozen env runtime stores one `sequence_state` on one environment and its
runtime identity contains only `scenario_id` and `node_id`. Reusing that slot
for crew/world work would replace the active environment scenario. Therefore
the adapter MUST own a generic persisted `world_sequence_instances` map. It is
keyed by the canonical owner token
`source_domain::owner_id::definition_id::public_instance_token`. Source domains
are exactly `crew` and `world`; semantic operation ownership remains the separate
shared `owner_namespace` vocabulary. The closed persisted value contains schema
version 1, owner token, public source, public instance token, node/mount selector,
definition fingerprint, registration marker, lifecycle, independent env runtime
state, ownership claims, and outcome receipts/acknowledgements. The definition
stays in its trusted catalog and must match the fingerprint on rehydration.
Every token component is canonical and the map key MUST equal the normalized
fields.

Every mounted instance calls the shared `ScenarioSequenceSchema`,
`ScenarioSequenceRuntime`, and `ScenarioOperationRegistry` separately. Facts are
fanned out in sorted composite-key order, but each instance owns its own queues,
receipts, phase, objectives, semantics, reentry, expiry, cleanup, and outcome
handshake. Presentation is a deterministic composition of base semantics, the
environment scenario, and all owner-scoped instances; it is never produced by
copying one instance over another. Conflicts are validated across the union of
claims before any mount or mutation. Removing one instance cannot alter another
instance's state or shared base semantics.

This container and its APIs are generic: no branch may inspect an event id,
crew member id, node id, or owning model to select storage, validation, dispatch,
or composition behavior. The proof conversion uses the same path that every
Family 2 consumer will use.

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

The adapter first derives a pure, non-persisting receipt preview from the exact
live registration, trusted definition fingerprint, and terminal cause. The
owning model then commits its consequences, `world_applied`, and a closed public
checkpoint in one synchronous rollback boundary. Only after that commit may the
adapter materialize the exact previewed receipt. Acknowledgement and cleanup are
separate retryable steps and neither can execute owner consequences.

`DeliveryRunModel` is the sole issuer of the persisted checkpoint. It binds the
delivery/job and public instance, owner token, neutral receipt id/fingerprint
and cause, resolution and delivery receipt fingerprints, and the canonical
public result/fingerprint. A mounted applied delivery without that exact
checkpoint fails closed; the established unmounted delivery path remains a
separate legacy boundary. Save/reload between preview, model commit, receipt
materialization, acknowledgement, and cleanup MUST be tested.

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
interaction: `crew_favor_delivery`. The `refuse` choice remains genuine dialogue
on its existing EventModule result path. `run_package` mounts the generic
adapter sequence and may not call a proof-specific adapter branch.

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

A proof-specific adapter branch is a design rejection.

### 9.1 Exact `crew_favor_delivery` worked interface

The trusted registration uses `source.domain=crew`, `source.owner_id=crew`,
`definition_id=crew_favor_delivery`, and a canonical attempt-scoped
`public_instance_token`. Its exact owner token is therefore
`crew::crew::crew_favor_delivery::<public_instance_token>`. The runtime
definition uses `id=crew_favor_delivery` and a nested
schema-v2 `sequence`. It mounts at the real delivery target node only after the
existing public delivery/job state authorizes the target. The semantic proof
must add a crew-owned package handoff interaction and at least one visible scene
or actor record, expose an authenticated `make_handoff` objective action, and
declare exact cleanup and branch aftermath.

The only trusted outcome channel for the conversion is
`delivery_handoff`. Authored data names that channel, never a
method. Trusted code maps it to the already-existing delivery/job completion
boundary. A success acknowledgement preserves the shipped +22 bankroll and +4 heat,
crew-favor completion flags, and existing job trust behavior exactly; a
delivery failure preserves the shipped +9 heat and failure flags exactly.
Starting or mounting applies none of those effects. The existing `refuse` path
preserves +9 heat and the refusal flag and does not mount an instance.

The sequence outcome receipt key is the composite instance key plus terminal
outcome and exact runtime receipt fingerprint. Its pure preview persists no
pending work. The delivery model commits the closed checkpoint and unchanged
owner consequences first; the adapter then independently materializes,
acknowledges, and cleans the exact receipt. Replay, save/load between any two
steps, duplicate EventModule submission, or revisit returns the checkpointed
public result and cannot reapply money, heat, trust, job, delivery, or flags.
Cleanup removes only crew-owned temporary semantics; aftermath is a separately
authored persistent claim.

## 10. Concrete env06_6 binding appendix

These values are resolved against frozen env06_6 head `855a2961`. A later
env06_6 review correction requires an explicit compatibility update to this
appendix; adapters do not silently guess or negotiate alternate spellings.

| Binding id | Concrete value | Status |
| --- | --- | --- |
| `ENV-BIND-01` | Version is integer `sequence.schema_version=2`; `ScenarioSequenceSchema.validate_definition(...)` accepts exact equality only. Runtime state is schema 4; command and fact envelopes are schema 1. There is no negotiation or fallback. | RESOLVED |
| `ENV-BIND-02` | Shared-validator input is `{id, sequence}`. `sequence` permits exactly `schema_version`, `local_state_schema`, `phase_graph`, `objectives`, `reentry_policy`, `expiry`, `cleanup`, `aftermath`, `mechanic_tags`, `sequence_signature`, `owner_exceptions`, `fact_subscriptions`, `completion_contract`, `declared_targets`; unknown sequence keys reject. Adapter metadata remains outside `sequence`. | RESOLVED |
| `ENV-BIND-03` | Env state identity is exact `scenario_id=definition.id` plus `node_id`. Adapter `owner_token` is `source.domain::source.owner_id::source.definition_id::public_instance_token`, with source domain exactly `crew|world`; its persisted map key must equal those canonical fields. Operation identity remains the separate exact `owner_namespace::stable_object_id`. | RESOLVED |
| `ENV-BIND-04` | `node_id` is exact persisted text. `stable_object_id` is canonical lowercase/digit/underscore/hyphen with optional colon-separated semantic components and no `::`. Position uses declared `anchor_id` or `zone_id`; route uses exact owned identity proven by the sealed room inventory. Declared collections are `scene_objects`, `interactions`, `actors`, `services`, `games`, `routes`, `anchors`, `zones`. | RESOLVED |
| `ENV-BIND-05` | Local types are `bool,int,float,string,enum,string_array,int_array`. Every field requires typed `default`, optional `visibility=private|public`, enum `values`, or paired numeric `min/max`. Mutations use registered `set_local` or integer-only `increment_local`; invalid type/domain/bounds reject. | RESOLVED |
| `ENV-BIND-06` | `phase_graph={initial_phase,phases}`. Phase keys are `id,label,arrival_feedback,exit_prompt,terminal,entry_conditions,objective_ids,advance_after_actions,scene_ops,interaction_ops,actor_ops,transition_ops,branches`. Branches have `id,condition` and exactly one `next_phase` or terminal `outcome`, with optional `objective_outcomes`. Conditions are `always,command,fact,local_equals,local_min,objective,outcome,receipt`. | RESOLVED |
| `ENV-BIND-07` | Scene ids are `spawn,remove,move,replace,reveal,hide,enable,disable,set_state,set_appearance`. Every operation has `family,op,receipt_id,owner_namespace,stable_object_id` plus the verb's closed payload. `apply_operations` is transactional and returns `ok,state,applied,errors` with fingerprint-bound replay. | RESOLVED |
| `ENV-BIND-08` | Interaction ids are `add,remove,replace,gate,retarget,augment`. Add/replace declares bounded label/state/prompt, enabled state, actions/inputs, non-color state, focus order, hit bounds/minimum 44px, `safe_exit`, and explicit `alternate_exit`. Overlays name exact target owner/id; an augment contributes authenticated actions but no second host identity. | RESOLVED |
| `ENV-BIND-09` | Actor ids are `spawn,despawn,set_position,set_route,set_pose,set_behavior`. Spawn carries closed `actor`; position requires anchor/zone, route requires sealed exact owned route, pose is canonical, behavior bounded. Resolved route points and platform motion are derived. | RESOLVED |
| `ENV-BIND-10` | Objective rows are `id,label,progress_label,steps,outcomes`; steps are `id,label,kind,command_id,fact_type,payload_equals`. Outcomes are `success,failure,ignore,cancel`. Public projection exposes progress; `complete_objective_step` and `resolve_objective` mutate it; terminal branches bind outcomes atomically. | RESOLVED |
| `ENV-BIND-11` | Transition ids are `stage,sound,music,scene_change,feedback`; all require `channel`. Stage requires message/id/duration 0..8/reduced-motion fallback; sound/music require `cue_id`; scene change requires message/change id. Production and delivery receipts are separate; `drain_transitions` emits each once and publishes bounded `active_stages`. | RESOLVED |
| `ENV-BIND-12` | `reentry_policy` is a closed dictionary with `partial`, `terminal`, `expired`, each one of `resume,restart,aftermath,expired`. `apply_reentry(state,definition,visit_id,host_semantics)` uses a structural visit receipt and rebuilds projection without replay. | RESOLVED |
| `ENV-BIND-13` | `expiry={boundary,after,policy}`. Boundaries are `none,leave,visit_end,night_end,town_action`; policies are `resume,fail,ignore,cancel,cleanup`. `apply_expiry_boundary` records ordered boundary/amount causes and applies objective/cleanup behavior atomically after the threshold. | RESOLVED |
| `ENV-BIND-14` | `cleanup={operations:[...]}`; each op includes `family` and the registered common envelope. Validation proves a live mutation/tombstone/overlay obligation and exact base restoration. Structural cleanup receipts and content fingerprints make exact retry idempotent and changed finalized content reject. | RESOLVED |
| `ENV-BIND-15` | `aftermath` is keyed by reachable outcome. Each row permits `label,revisit_feedback,scene_ops,interaction_ops,actor_ops,service_ops,game_ops,route_ops`. It applies after cleanup and persists material owner-scoped semantics/receipts; it cannot retain temporary claims. | RESOLVED |
| `ENV-BIND-16` | `mechanic_tags` are unique canonical ids. `sequence_signature` equals SHA-256 `calculated_signature_hash(definition)` of canonical `normalized_signature`. Equal hashes fail; similarity >=.820 fails, .720-.819 blocks, .600-.719 requires receipt-bound masked visual evidence, below .600 passes. | RESOLVED |
| `ENV-BIND-17` | Facts use schema-1 envelope `fact_type,producer,node_id,fact_id,producer_serial,boundary_serial,payload`. Producer/type/payload registries are in `ScenarioSequenceRuntime`; `enqueue_fact` fingerprints/deduplicates and `flush_facts` persists deterministically ordered exact batch/receipt records. | RESOLVED |
| `ENV-BIND-18` | Commands use schema 1 with exact `command_id,node_id,expected_phase,idempotency_key,owner_namespace,stable_object_id`, five `action_origin_*` authority fields, and `payload`. `apply_command` validates the live action and cost before mutation. Result keys are `ok,replayed,receipt_id,command_id,phase_id,status,boundary_serial,outcomes,changed,cost,state`; changed key content rejects and exact replay returns cached result. | RESOLVED |
| `ENV-BIND-19` | Registered handlers are `set_local,increment_local,complete_objective_step,resolve_objective,record_outcome,publish_feedback,request_cleanup,event_bridge`. `registered_handlers()` publishes closed inputs, source, persistent outputs, write algebra, atomicity, idempotence and `rng=none`; `validate_handler_inputs` is authoritative. Outcome channels are a separate trusted adapter registry. | RESOLVED |
| `ENV-BIND-20` | Container and registration schemas are 1. Each entry stores `owner_token,source,public_instance_token,node_id,mount_selector,definition_fingerprint,registration_marker,lifecycle,state,ownership_claims,outcome_channels,outcome_receipts,outcome_acknowledgements`; `state` is the complete normalized env runtime. Public adapter snapshot omits private state and adds env `public_projection` only when the trusted definition fingerprint rebinds. | RESOLVED |
| `ENV-BIND-21` | Owned identity is `owner_namespace::stable_object_id`; priority is `base10,traveler20,service30,game40,event50,crew55,scenario60,sweep70`. Priority arbitrates registered overlays only. Duplicate same-owner identity, ambiguous target, cycles, and exclusive target/property conflict reject; adapter preflights across all active instances. | RESOLVED |
| `ENV-BIND-22` | Validator entry is `ScenarioSequenceSchema.validate_definition(definition,ScenarioOperationRegistry,target_inventory)->Array[String]`; empty means valid. Crew reports wrap each unchanged message as `{source_kind,source_id,definition_id,instance_id,error}`, sort by composite instance/source ids, and never expose filesystem paths. | RESOLVED |
| `ENV-BIND-23` | `is_sequence` is false when nested `sequence` is absent; env migration/ensure leaves legacy snapshots unchanged. Adapter no-op is absence of `world_sequence_instances` and its registration marker, causing no scan/normalization. A marker is owner-scoped and removed only after durable cleanup. | RESOLVED |
| `ENV-BIND-24` | Canonical dictionaries sort string keys recursively; arrays preserve authored/receipt order; fingerprints are lowercase SHA-256. Persistence excludes Vector/Rect/render data. Prepared DTO collections are `visual_objects,interaction_overlays,services,games,routes,active_stages`; preparation failure empties all six. Native/Web serialize identical authority and semantically identical prepared DTOs. | RESOLVED |

## 11. Consumer authoring boundary after binding

Family 2 authors may author against sections 1 through 10 and the generic
owner-scoped instance API. They MUST NOT bypass the shared validator/runtime,
invent a second vocabulary, or special-case the proof conversion. Any change to
the frozen env binding first updates this appendix and its executable companion,
then receives independent contract review before consumer code adopts it.
