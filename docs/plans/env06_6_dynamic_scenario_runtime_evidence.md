# env06_6 Dynamic Scenario Runtime — Runtime and Evidence Report

Status: implementation and static review in progress. This report does not mark
`env06_6` complete and does not unblock `env06_7`.

## Production proof

The committed proof package is
`data/environments/scenario_sequences/env06_7_shops_streets.json`. It overlays
the legacy `corner_store_delivery_day` identity through
`ScenarioSequenceCatalog`, with the allowlisted `shops_streets` handler and
renderer adapters. The proof is one object-envelope package containing one
scenario definition; the env06_6 uniqueness shape is therefore exactly one
definition and zero pairs. It is not evidence that the 55-scenario env06_7
conversion is complete.

The delivery-day sequence has five authored phases, a three-step sorting
objective, four material terminal outcomes, partial/terminal/expired reentry,
night-end cleanup, stable semantic anchors, and typed event-result correlation.
The base delivery event remains gated through arrival, sorting, verification,
awaiting-stock, resolution, refusal, interruption, and expiry. The verification
command queues a correlated request; the production UI drains that request and
then activates the event modal. Repaired and broken results remove the terminal
gate only after the exact delivered resolution has legitimately completed.

## Authority map

| Concern | Authority | Evidence surface |
| --- | --- | --- |
| Package envelope and immutable legacy overlay | `ScenarioSequenceCatalog` | package id, file, handler, renderer, scenario ids, authoring evidence |
| Typed state, graph, objectives, lifecycle, hard definition, normalized signature | `ScenarioSequenceSchema` | validation failures, calculated hard-10 rows, uniqueness rows and pair counts |
| Registered semantic operations and conflict priority | `ScenarioOperationRegistry` | operation/handler registries, owner priority, target identity, idempotent receipts |
| Commands, typed facts, event requests, cleanup and reentry | `ScenarioSequenceRuntime` | phase/local/objective/semantic snapshots, request history, transactional reject/drop queue isolation, fact/command/cleanup receipts |
| External refs, layout and extension binding | `ScenarioEngine` | registry/ref/layout validation and package handler/renderer checks |
| Persistence and legacy suppression | `RunState` plus `SaveService` | exact node snapshots, suppression markers, migration receipts, derived-view rebuild |

JSON packages contain data only. Complex behavior crosses the fixed extension
dispatch and registered-handler boundaries; arbitrary callables, node paths,
reflection targets, and unallowlisted resources remain invalid.

## Conflict, persistence, and migration rules

Interaction identity is `owner_namespace::stable_object_id`. Base, traveler,
service, game, event, crew, scenario, and sweep records compose by the registry's
fixed priority. Same-owner duplicates fail closed. A scenario gate targets the
base event identity without replacing unrelated game, service, traveler, or
sweep records.

Authoritative snapshots persist the phase id, typed local state, objective
progress, semantic objects/interactions/actors, resolved branches/outcomes,
fact and command identities, delivered transition/request receipts, cleanup,
expiry, visit, and migration receipts. Presentation projections and render
snapshots are derived and rebuilt after load. Old saves preserve the selected
legacy scenario id; mutation-suppressed scenarios cannot reacquire an overlay
or leak a queued event request during restore.

Fact flushes are transactional. If one queued fact fails payload/authority
matching, all effects roll back, that offending identity is dropped without a
receipt, fingerprint, or last-flushed advance, and every other queued fact
retains its ingress order for a later safe boundary.

The focused production contract covers exact snapshots for every persistable
delivery-day phase, immediately before and after request drain, all four
terminal outcomes, and expiry. The authored `resolution` phase is transaction-
internal: the same accepted command/fact that enters it immediately selects its
terminal branch, so no standalone resolution snapshot is committed between
safe boundaries.

## Authoring audit format

`tools/scenario_sequence_audit.ps1` invokes the deterministic
`tools/scenario_sequence_audit.gd` report. JSON is the machine artifact and
Markdown is its review summary. The report contains:

- phase graph and reachable terminal branches;
- scene, interaction, and actor deltas per phase;
- player verbs and objective steps;
- local-state, reentry, expiry, cleanup, and aftermath coverage;
- calculated signature, nearest id/similarity, exact count and pair count;
- handler/renderer package identity and external references;
- capture ids, seed/reachability evidence, hard-10 rows, and owner exceptions;
- hostile-fixture rejection for unreachable/nonterminating graphs, missing
  cleanup, orphan targets/hit regions, invalid refs, duplicate receipts and
  material rewards, unreadable state-only changes, equivalent signatures, and
  missing evidence.

The wrapper accepts a positive expected count and requires the schema's exact
`0.820` fail threshold; it cannot be weakened by a command-line override. Any
argument, catalog, schema, registry, hard-proof-shape, hostile-fixture, or write
failure produces a nonzero process result.

## Performance design evidence

Schema/catalog validation and normalized signature work occur at content-load
or explicit audit time. Runtime mutations occur at command, fact, town-boundary,
reentry, expiry, and load seams. Operation batches are bounded and transactional;
the renderer consumes prepared projections. No new per-frame schema evaluation,
catalog scan, or scene reconstruction is introduced by the proof or audit.

The static repository validator's function census passed. Measured native/Web
timing evidence remains pending because the shared Godot/compiler host is
locked.

## Gate ledger

| Gate | Status |
| --- | --- |
| PowerShell syntax parsing and static JSON/object-envelope checks | PASS — object accepted; array, null, string, number, and boolean rejected by the object-package rule |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1 -Quiet` | PASS — exit 0 in 52.255 seconds on the full dirty tree; includes the static function census/helper shard |
| Godot GDScript load/compile check | **DEFERRED — HOST LOCK** |
| Foundation systems/content/UI/save/accessibility suites | **DEFERRED — HOST LOCK** |
| `tools/scenario_sequence_audit.ps1 -RequireGodot -ExpectedCount 1` | **DEFERRED — HOST LOCK** |
| Native/Web exact-sequence parity | **DEFERRED — HOST LOCK** |
| `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` | **DEFERRED — HOST LOCK** |
| `tools/foundation_visual_qa.ps1` including phase/outcome/revisit/reduced-motion/small-screen/overlay captures | **DEFERRED — HOST LOCK** |
| Native/Web performance measurements | **DEFERRED — HOST LOCK** |

No deferred row is a PASS. Completion, archival, board-row closure, and the
`env06_7` unblock decision require the host-serialized gates and independent
review to land successfully.
