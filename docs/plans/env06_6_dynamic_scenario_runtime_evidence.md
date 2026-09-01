# env06_6 Dynamic Scenario Runtime — Runtime and Evidence Report

Status: **DONE / ACCEPTED ON CURRENT MAIN CANDIDATE — 2026-08-31**

The previously host-blocked proof has now run against the recovered integrated
candidate. The full hostile scenario contract, exact two-native/two-Web parity,
locked timing budgets, 21-checkpoint runtime trace, 55-scenario downstream
audit, and production layout checks are green. This closes `env06_6` and
unblocks the already recovered `env06_7` rollout.

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

The dedicated `tools/scenario_sequence_probe_main.tscn` entry instantiates the
real `scenes/main.tscn`, prepares a detached production ContentLibrary, installs
the generated delivery-day corner store, and drives only FoundationMain's
authoritative action-token and event-response routes. It never manually flushes
scenario facts. Branches restore the entire RunState so bankroll, heat,
inventory, flags, story, and receipts cannot leak between outcomes.

`tools/scenario_sequence_parity_performance.ps1` runs two isolated native
processes and two fresh-profile Chrome Web processes at CPU4. The Web side uses
a fresh release export and freshly compiled extension physically beneath the
ignored output directory; root project/export configuration is hash-guarded.
Canonical semantic traces exclude host metadata and timing data, while exact
JSON and SHA-256 must match within and across platforms. Required nonzero rows
cover content/schema/catalog/index preparation, command/request drain/event
delivery, fact publish/flush and terminal cleanup, projection/layout,
production save and FoundationMain load/rebuild, reentry, expiry, and steady
prepared frames. Locked budgets are native transition p95/max `16/45 ms`,
native prepared-frame p95 `16.6 ms`, Web CPU4 transition p95/max `120/1200 ms`,
and Web prepared-frame p95 `120 ms`.

Measured native/Web timing evidence completed on the available Godot/compiler
host. All four processes produced the same canonical semantic SHA-256:
`bc70e7d69c5c1af415c3841cf272c1aedf9f1dee037b8b38d68e1c77519edd20`.
Native transition p95/max remained about `13.6/16.3 ms`; Web CPU4 transition
p95/max remained within the locked limits (worst observed `93.916/122.38 ms`),
and prepared-frame p95 remained within budget on both platforms.

## Executable visual, parity, and timing proof

Windowed GL capture command:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools\scenario_sequence_visual_capture.ps1 -RequireGodot -OutDir .tmp\env06_6\visual_capture -TimeoutSec 600`

The producer must write `manifest.json` and exactly one PNG for each of the 21
authored capture ids. Every row records a byte-verified PNG SHA-256, dimensions,
phase, status, outcome, visual-state fingerprint, and live assertions. The
proof uses actual canvas layout and public hit geometry, the real TalkDock
reservation, safe-exit/hit-center correlation, scenario text/non-color state,
a production reduced-motion transition with exact readable feedback and no
timed stage, and the exact enabled scenario target at logical `104x76` in
small-screen mode. The four material outcome PNGs and visual-state hashes must
be distinct.

Obstruction evidence pins two distinct production targets: the non-exit
`delivery_event_gate` and the safe-exit `delivery_exit`. Both must retain
enabled tokenized actions, resolve to distinct public live rectangles, correlate
exactly at their public hit-test centers, and remain clear of the TalkDock
reservation. The event gate is the selected composition for this proof.

Parity reports carry a separate pinned 21-row runtime order because efficient
branch restore order differs from authored capture-list order. Every checkpoint
must appear exactly once in that order with the production scenario and node,
the exact phase/status pair, and the exact outcome set. Missing, duplicate,
reordered, mislabeled, truncated, or semantically altered traces are rejected
even when their semantic hash is internally recomputed.

Parity/performance command:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools\scenario_sequence_parity_performance.ps1 -RequireGodot -Browser chrome -Cpu 4 -TimeoutMs 600000 -OutDir .tmp\env06_6\parity_performance`

The producer must write two native reports, two Web reports, a fail-closed
manifest, a transient Web project/build, fresh profiles, and complete logs
beneath the requested ignored output directory. Browser console errors, page
errors, or failed asset requests reject the Web report. Native processes direct
distribution data, settings, autosaves, and evidence-slot I/O into unique
output-owned directories; SaveService clears the isolated slot through its
public contract.

## Gate ledger

| Gate | Status |
| --- | --- |
| PowerShell/Node syntax, static JSON/object-envelope checks, executable-tool hostile contracts | **PASS** |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1` | **PASS** — 73.1 seconds, 2026-08-31 |
| Godot GDScript load/compile check | **PASS** |
| `env06_6_full_contract.gd` hostile runtime/persistence contract | **PASS** — 93 seconds, 2026-08-31 |
| 55-scenario catalog/audit and uniqueness proof | **PASS** — 55 identities; 1,485 pairs; zero failures; 27 approved warnings |
| `tools/scenario_sequence_parity_performance.ps1 -RequireGodot -Browser chrome -Cpu 4` exact native/Web trace | **PASS** — two native and two Web reports, exact canonical SHA |
| Deterministic replay and prepared-layout proof | **PASS** |
| Exact authored visual evidence | **PASS** — 21 runtime checkpoints plus 683 ENV06_7 captures and 14 contact sheets |
| Native/Web delivery transition and prepared-frame measurements | **PASS** — all locked p95/max budgets met |
