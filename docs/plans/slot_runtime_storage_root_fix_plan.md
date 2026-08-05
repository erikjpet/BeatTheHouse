# Slot Runtime and Run Storage Root-Fix Plan

Status: executed 2026-08-05; SRP gates pass, with inherited non-SRP release blockers recorded below.

## Objective

Make late runs and rooms with multiple active slot machines substantially more
efficient while presenting exactly the same game to the player. The accepted
fix changes ownership, scheduling, persistence, and rendering work. It does not
remove, shorten, simplify, replace, or suppress reel symbols, cabinet art,
animations, audio cues, bonus sequences, environment motion, or gameplay.

The current measured failure is compound:

- three simultaneously active cabinets already produce a 17.1 ms resolve p95;
- six produce 27.3 ms and twelve produce 38.0 ms;
- the serialized run grows from about 49 KB with one cabinet to 243 KB with
  twelve;
- twelve-cabinet disk saves reach 19.7 ms p95 on the main thread;
- a representative capped late run spends 46 KB, or 63% of its save, on the
  story log; and
- completed profile run history is not responsible: it is capped at twenty
  compact entries and is about 8 KB in the current profile.

Evidence:

- `.tmp/performance_playtest_audit/multi_slot_scaling_report.json`
- `.tmp/performance_playtest_audit/save_storage_profile_report.json`
- `user://foundation_soak_probe_report.json` from the current 30-minute soak
- `docs/plans/0.5_performance_audit.md` for the existing native, Web, resolve,
  liveness, and visual-performance contracts

## Non-negotiable player-equivalence contract

Every phase is blocked unless all of these remain true.

1. The same seed, machine, action sequence, and timing inputs produce the same
   reel stops, visible symbols, payouts, feature triggers, heat, bankroll,
   inventory effects, RNG state, and story facts.
2. Reel count, row count, symbol identity, icon artwork, cabinet artwork,
   lighting, overlays, tease presentation, nudge presentation, bonus art,
   environment previews, and settled results are unchanged.
3. Reel start, stop, bounce, tease, hold, feature, and outcome timings match the
   accepted baseline within one rendered frame. Autoplay cadence and stable
   fixture tie ordering also match within one frame.
4. Every current surface and environment animation continues to redraw at its
   existing liveness rate. A performance fix may cache the source artwork, but
   may not substitute a static surface for an animated one.
5. Surface and environment audio cue IDs, ordering, pitch, and volume remain
   unchanged.
6. Closing and reopening a slot, leaving and returning to a room, and saving and
   loading during an active or pending feature preserve the same visible and
   playable state.
7. Foreground and background machines remain independent. No machine may skip a
   spin, reuse another fixture's state, consume another fixture's RNG, or lose a
   pending feature.
8. No budget, sample count, throttle, liveness floor, or visual assertion may be
   weakened to obtain a pass. The existing slot resolve budget of 6/8/10 ms
   average/p95/max remains binding and gains multi-cabinet gates.

Explicitly prohibited shortcuts:

- disabling animations, environment animation, or autoplay;
- lowering animation update frequency or shortening outcome holds;
- hiding or replacing moving reel icons, including with generic streaks or
  blank cells not already part of the accepted presentation;
- reducing reel/row/symbol counts or simplifying bonus sequences;
- reducing texture, audio, or effect fidelity by platform;
- pausing visible machines merely because several are active;
- dropping state that is needed to resume an active feature or presentation;
- increasing budgets, adding waivers, or measuring only a single machine; and
- treating a smaller save as proof of correctness without save/load parity.

## Root architecture

### 1. Separate immutable machine definitions from mutable machine state

Add a slot definition cache keyed by the existing stable machine identity:

`format_id:type_id:math_variant_id:bonus_variant_id:cabinet_variant_id`

The cache owns content-derived, immutable data such as canonical geometry,
configured reel strips, bonus reel strips when they are definition-derived,
reel heights, symbol metadata, paytable/config references, and cabinet/icon
presentation metadata. It is built from the loaded game definition and shared
by every matching cabinet.

`SlotMachineState` then owns only data that can actually change for one cabinet:
selected bet, reel stops and settled grids, counters, progressive/bonus state,
feature state, item state, pending offers, autoplay state, and the current
presentation checkpoint.

The resolver and renderer receive an immutable definition view plus mutable
machine state. They must not reconstruct or duplicate reel-strip arrays on each
read, spin, snapshot, or draw. This is a data-ownership change only: the exact
same strips and symbol definitions continue to drive math and art.

Implementation seams:

- add `scripts/games/slots/slot_definition_cache.gd`;
- evolve `scripts/games/slots/slot_machine_state.gd` to schema version 2;
- route `slot_machine_generator.gd`, `slot_resolver.gd`,
  `slot_presentation.gd`, and `slot_renderer.gd` through the shared definition
  view; and
- keep a legacy shadow comparison until generated definitions, resolved
  outcomes, and presentation digests match for every slot family/format/bonus
  combination.

Before removing any field, inventory all runtime and test consumers and classify
the field as immutable definition, durable mutable state, active presentation,
or analytics. Unknown fields remain preserved for forward/backward compatibility.

### 2. Give presentation data an explicit lifetime

Animations are retained, but completed animation payloads must not remain in
every cabinet forever.

Introduce a `SlotPresentationCheckpoint` with two forms:

- **active:** enough information to render or resume the exact current
  animation, including animation ID, start/elapsed timing, reel stops, previous
  and target grids, reel timeline, tease/feature markers, and audio-emission
  guards;
- **settled:** the final grid, classification, payout/result summary, and any
  persistent offer or feature state, with completed timeline-only data removed.

The active checkpoint stays live for the full authored animation. It transitions
to settled only after the renderer/presentation clock confirms completion. This
must work for foreground machines and environment previews. Saving during the
active form persists a compact checkpoint and loading reconstructs the identical
timeline; it must not jump directly to the settled frame.

Do not clear `last_previous_grid`, animation plans, timelines, or replay data
until consumer tests prove their presentation lifetime has ended. Feature replay
data that is player-accessible remains durable even after the ordinary spin
timeline settles.

### 3. Replace per-frame fixture scans with a deterministic due-time scheduler

Add `EnvironmentRuntimeScheduler`, owned by `FoundationMain` or a small runtime
coordinator. It maintains one queue per live/stored environment. Entries contain:

- environment identity;
- game ID and fixture state key;
- next due monotonic time;
- schedule generation/revision; and
- a stable tie-break key.

Games that opt into environment runtime expose their next due time directly,
rather than requiring the host to call `environment_runtime_needs_tick` for
every fixture on every frame. Slot writes that toggle autoplay, advance a spin,
pause for confirmation/feature attention, or change the next due timestamp
invalidate and reinsert only that fixture.

Required scheduler behavior:

- build/reconcile the queue when an environment is entered, generated, loaded,
  or its fixture set changes;
- inspect only the earliest due entry during ordinary frames;
- preserve the current one-result-per-frame behavior;
- order equal timestamps by stable environment/game/state key, matching current
  fixture order;
- discard stale entries by revision instead of performing full rescans;
- keep the stored Grand Casino main-floor runtime in the same coordinator; and
- expose queue depth, due lateness, stale-pop count, and per-frame work to the
  performance overlay/probe.

A low-frequency integrity reconciliation may scan all fixtures, but it must be
outside the per-frame hot path and must prove that no active fixture is missing.

### 4. Make routine results lightweight after they are committed

Rich resolution results are needed while applying gameplay and starting the
presentation, but they must not be deep-copied into long-lived host fields or
the story log after those consumers finish.

Add a typed compact result receipt containing only durable semantics used by
reports, tutorial/story checks, profile/lifetime statistics, security systems,
and replay summaries. Keep the full result only for the active presentation
boundary. `last_environment_runtime_result` should retain a compact receipt plus
the machine/state key; the machine's presentation checkpoint is the source for
animation data.

For story persistence, omit default zero/false/empty keys from routine game
actions while retaining all meaningful facts. Narrative events and unusual
feature/security/item events remain lossless. `story_log_entry_count()` and
archive behavior remain unchanged.

Before changing the receipt, enumerate all story consumers in `RunState`,
`FoundationMain`, terminal/run-report view models, tutorials, profile statistics,
and tests. Add consumer-contract tests before compacting the producer.

### 5. Introduce a versioned, deduplicated save projection

Do not mutate or strip the live runtime state just to save it. Add an explicit
save codec and bump the foundation save envelope to version 2.

The v2 projection contains:

- a registry of compact environments keyed by stable environment ID;
- references from the current environment, world-map nodes, and Grand Casino
  room storage instead of serializing the same environment/game state multiple
  times;
- compact slot machine schema-v2 state referencing immutable definition IDs;
- compact story receipts;
- all other current run fields without semantic loss; and
- unknown/forward fields where the current compatibility contract requires them.

Loading expands or references the registry according to current runtime
ownership expectations, hydrates definition views from content, reconstructs
active presentation checkpoints, and then runs the normal validators. Existing
v1 envelope and raw RunState saves must continue to load. They are migrated in
memory and written as v2 only after a successful subsequent save. Primary and
backup recovery behavior remains unchanged.

Suggested seams:

- add `scripts/core/run_save_codec.gd`;
- keep `RunState.to_dict()/from_dict()` as the canonical diagnostic/runtime
  representation until all callers are classified;
- make `SaveService` use `to_save_dict()/from_save_dict()` or the codec directly;
- add explicit v1-to-v2 migration fixtures; and
- update performance probes to measure both runtime-state size and actual v2
  save size so a compact projection cannot hide retained-memory growth.

### 6. Move save work off the frame path without moving gameplay

Gameplay resolution, RNG consumption, economy/security application, and state
commit stay serialized on the main thread. The save pipeline receives a fully
detached, immutable snapshot generation after commit.

Add `RunSaveCoordinator` with:

- a monotonically increasing dirty/save generation;
- cached versioned fragments for run sections and environment entries;
- invalidation only for changed fragments;
- at most one serialization/write job in flight;
- coalescing to the newest requested generation;
- worker-side JSON serialization, temporary-file writing, fingerprinting, and
  primary/backup rotation after engine/thread-safety verification;
- main-thread completion/failure notification; and
- explicit flush points for manual save, clean quit, terminal run handling, and
  any transition that currently promises durable completion.

Every accepted action still schedules durability. Repeated background spins may
coalesce full snapshots, but the latest generation must be written within the
durability bound and force-flushed at lifecycle boundaries. A failed write keeps
the dirty generation pending and preserves the last loadable primary/backup.

If detached JSON/file work cannot be proven safe on a worker in the project’s
Godot version, use bounded incremental serialization/write work across frames.
Do not silently return to a single 15-20 ms main-thread write.

### 7. Cache rendering work, never presentation fidelity

Storage/resolve improvements do not address all multi-machine draw cost. Optimize
the renderer by caching identical source artwork, not by drawing less artwork.

- Cache symbol/icon artwork by symbol, theme, scale, and visual-state key.
- Cache static cabinet layers by cabinet variant, viewport scale, and theme.
- Draw dynamic reel positions, lights, overlays, highlights, and feature layers
  over those caches at the same authored cadence.
- Resolve static reel definitions directly through the slot definition cache;
  do not copy strips into every surface snapshot.
- Patch only realtime timing/phase keys between semantic state changes.
- Cache environment-preview cabinet/static layers while continuing to animate
  every visible reel and environment object.
- Invalidate caches on viewport, scale, theme, definition, or relevant state
  changes, and bound them by explicit entry/byte limits.

Pixel/state golden tests decide whether a cache is equivalent. Any cache path
that changes an icon, layer order, clipping boundary, animation phase, opacity,
or timing is rejected even if it is faster.

## Phased implementation and gates

### Phase 0 — Freeze the accepted presentation and add instrumentation

Create deterministic golden fixtures for classic pinball, five-by-three
Buffalo, video-feature pinball, ordinary win/loss, near miss, nudge success and
failure, autoplay, pinball feature, Buffalo free games/hold-and-spin/monster
feature, item-forced bonus, and three/six/twelve simultaneous cabinets.

Capture, at fixed presentation timestamps:

- surface-state semantic digest;
- reel symbols and stops;
- animation/timeline digest;
- renderer screenshot/pixel digest at 1280x720;
- environment-preview digest;
- audio cue sequence; and
- final RunState/RNG digest.

Also split telemetry into scan/schedule, resolve, state commit, receipt/history,
snapshot capture, JSON serialization, disk rotation, presentation build, and
draw. No optimization begins until the baseline is reproducible twice.

Gate: current behavior is captured, all required active animations meet their
liveness floors, and a deliberately removed animation/icon makes the gate fail.

### Phase 1 — Immutable definitions and mutable state v2

Introduce the definition cache and shadow it against legacy in-machine strips.
Migrate resolver and presentation reads one family at a time. Keep legacy fields
until every combination passes deterministic and presentation comparisons.

Gate:

- all behavior/visual machine combinations match legacy outputs;
- no reel-strip deep copy occurs on a routine peek, snapshot, or draw;
- current slot resolve remains at or below the existing 6/8/10 ms budget; and
- all golden visual/audio/liveness checks pass unchanged.

### Phase 2 — Presentation lifetime and compact result receipts

Add active/settled checkpoints, clear only expired transient data, and stop
retaining rich background results after presentation handoff. Add compact story
receipts after consumer-contract coverage is green.

Gate:

- save/load at 25%, 50%, 90%, and 100% of each animation resumes within one
  frame of the baseline phase;
- feature replay and pending offers remain available;
- run report, tutorial facts, profile/lifetime stats, heat/security checks, and
  terminal outcomes are identical; and
- settled per-cabinet persistent state is at most 4 KB, with separately reported
  bounds for genuinely active complex features.

### Phase 3 — Deterministic runtime scheduler

Replace the per-frame fixture scan with the due-time queue. Run the old scanner
in diagnostic shadow mode during tests and compare selected fixture/action/order
on every tick.

Gate:

- 1/3/6/12 fixtures resolve in exactly the same stable order;
- no autoplay result, confirmation pause, feature alert, or stored-room update
  is lost;
- twelve-machine idle scheduler inspection is <=0.05 ms p95 and does not scale
  linearly with fixture count; and
- due lateness is no worse than the existing one-result-per-frame behavior.

### Phase 4 — Save v2 projection and migration

Add environment references, compact machine state, and compact story receipts.
Load every existing save fixture, including active autoplay and active bonus
fixtures, then resave/reload as v2.

Gate:

- v1 and raw legacy saves remain loadable through primary and backup paths;
- v1 -> runtime -> v2 -> runtime semantic digests match;
- twelve settled cabinets plus a capped representative late-run story stay
  <=150 KB, with no single settled cabinet above 4 KB;
- actual save JSON contains no definition-derived reel-strip duplication and no
  completed animation timeline; and
- current save corruption/recovery tests stay green.

### Phase 5 — Asynchronous/incremental save coordinator

Move detached serialization and file work away from gameplay frames, preserve
generation ordering, and coalesce redundant pending snapshots.

Gate:

- main-thread snapshot handoff is <=2.0 ms p95 and <=4.0 ms max in the
  twelve-cabinet capped-late-run fixture;
- no save-related frame exceeds 16.6 ms native;
- worker/incremental end-to-end save p95 is reported separately, not hidden;
- latest accepted state becomes durable within 2 seconds during continuing
  play and is force-flushed at explicit lifecycle boundaries;
- crash/interruption tests always load either the latest completed generation
  or its valid backup, never a partial file; and
- rapid spins followed by quit/load reproduce the committed bankroll, RNG,
  feature, and machine states.

### Phase 6 — Fidelity-preserving renderer caches

Cache symbol and cabinet source artwork and convert repeated full snapshot work
to bounded realtime patches. Exercise foreground surfaces and multiple visible
environment cabinets on native and 4x-throttled Web.

Gate:

- golden pixel/state/audio comparisons remain unchanged;
- every visible reel/icon and environment animation meets the existing liveness
  floor;
- 1/3/6/12 active-cabinet native frame p95 is <=16.6 ms;
- `slot_autoplay_active` meets its existing Web budget without a waiver; and
- cache memory reaches a stable bound under room churn, viewport changes, and
  all machine variants.

### Phase 7 — Long-run integration and release decision

Run two clean passes of determinism, slot acceptance/deep audit, save migration,
FoundationSuite all, native performance/liveness, visual QA, strict rendered
mouse play, Web performance, and a true uninterrupted three-hour same-run soak.
The soak must exercise a late capped story, world travel/revisits, active and
settled bonuses, and twelve persistent cabinets; it must not repeatedly reset to
a small retained fixture and call that late-run coverage.

Gate:

- no regression in gameplay, tutorial, normal-run time behavior, environment
  animation, audio, presentation, or save recovery;
- no monotonic retained object/node/resource growth;
- serialized size and every field/component budget remain bounded;
- the three-hour gate has an explicit practical wall-time budget and finishes
  in CI/developer use; and
- all new performance rows are green with no waivers or relaxed legacy budgets.

## Binding performance budgets

| Measurement | Required budget |
|---|---:|
| Existing single-slot resolve average / p95 / max | <= 6 / 8 / 10 ms |
| 3/6/12-machine runtime frame p95, native | <= 16.6 ms each |
| Twelve-machine idle scheduler inspection p95 | <= 0.05 ms |
| Twelve-machine capped-late-run snapshot handoff p95 / max | <= 2 / 4 ms |
| Save-caused main-thread frame p95 | <= 16.6 ms, with no isolated save hitch above budget |
| Settled slot persistent state | <= 4 KB per cabinet |
| Twelve-cabinet capped-late-run v2 save | <= 150 KB |
| Latest-generation continuing-play durability | <= 2 seconds |
| Native visible animation liveness | existing floors, unchanged |
| Web slot autoplay | existing Web budget, no waiver |

These are additive gates. Existing stricter subsystem budgets continue to win.

## Traceability

| ID | Root cause | Fundamental change | Proof |
|---|---|---|---|
| SRP-01 | Definition-derived strips/icons are copied into every cabinet and through hot paths | Shared immutable slot definition cache | Definition shadow parity, allocation counters, all-combination determinism |
| SRP-02 | Completed presentation plans/timelines remain in durable machine state | Explicit active/settled checkpoint lifetime | Mid-animation save/load goldens and settled-state size budget |
| SRP-03 | Host scans every fixture each active frame | Deterministic due-time scheduler | Scanner shadow comparison and 1/3/6/12 scheduler timing |
| SRP-04 | Rich background results and routine story entries outlive their consumers | Compact result/story receipts | Consumer-contract, report, tutorial, stats, and terminal parity tests |
| SRP-05 | Current/map/stored-room persistence duplicates environments and slot state | Versioned environment registry/reference save projection | V1 migration parity and component-size report |
| SRP-06 | Full JSON/write/backup rotation occurs on the main thread | Generation-based detached save coordinator | Frame telemetry, durability, corruption, and quit/load tests |
| SRP-07 | Multiple visible cabinets repeat static procedural draw work | Fidelity-preserving symbol/cabinet caches plus realtime patches | Pixel/audio/liveness goldens and native/Web multi-cabinet frame gates |
| SRP-08 | Existing multi-slot “budget” test checks correctness only | Real timing/allocation/save/render budgets | Required CI report rows with no waiver |
| SRP-09 | Current soak can miss uninterrupted late-run behavior and take impractical wall time | Same-run storage/slot soak with wall-time budget | Completed three-hour report with bounded state and retained resources |

## Rollback and review rules

- Land phases as independently reviewable commits; do not combine visual,
  gameplay-math, scheduler, save-format, and renderer changes in one patch.
- Keep legacy save migration permanently. Diagnostic legacy shadow paths may be
  removed only after two clean full-gate passes.
- A failed visual, animation, audio, deterministic, migration, or durability
  gate rolls back the responsible phase. It is not accepted as a performance
  tradeoff.
- Record before/after component timing, serialized field sizes, screenshots,
  liveness counts, and save generations for every phase.
- Do not archive this plan as completed until Phase 7 passes and the execution
  record lists commits, reports, migrations exercised, exact budgets, and any
  remaining known limits.

## Execution record — 2026-08-05

Implementation commits:

- `9fa3d541` — immutable slot definitions, compact schema-v2 cabinet state,
  active/settled presentation lifetime, compact receipts, and bounded pinball
  board templates;
- `9b4f3643` — deterministic due-time scheduler, v2 environment-reference save
  codec, shallow detached save snapshots, generation-coalesced async writes,
  atomic file-I/O synchronization, and lifecycle flushes; and
- `5a1ee569` — bounded renderer symbol/label metadata caches; and
- `7ebc7000` — real multi-cabinet timing/storage gates, the uninterrupted
  same-run soak, and expanded performance/visual diagnostics.

Final proof by traceability ID:

| ID | Executed proof |
|---|---|
| SRP-01 | `SlotDefinitionCache` owns immutable strips/geometry; slot contract hydration parity passes and stored/runtime snapshots omit reel-strip arrays. |
| SRP-02 | Disk save/load checkpoints at 25%, 50%, and 90% resume within one frame; 100% settles and removes the ordinary timeline. Settled cabinets are 2,833–3,091 bytes. |
| SRP-03 | `EnvironmentRuntimeScheduler` preserves stable fixture order and one-result-per-frame behavior. The 1/3/6/12 probe reports 5 µs scheduler inspection p95. |
| SRP-04 | Background results retain compact semantic receipts while the machine checkpoint owns presentation. Systems consumer, report, tutorial-fact, terminal, and save fuzz contracts pass for the changed scope. |
| SRP-05 | Save envelope v2 uses an environment registry/references and compact machine projections. Raw and v1 compatibility fixtures, primary/backup recovery, round trip, and interruption fuzz pass. |
| SRP-06 | Worker serialization/write uses generation coalescing and an I/O mutex around atomic rotation. Twelve-cabinet handoff is 0.254 ms p95, with zero worker/task errors and exact load parity. |
| SRP-07 | Renderer and pinball source caches have explicit caps. Visual QA passes; corrected-board Web liveness advances for active slots and pinball. |
| SRP-08 | `slot_runtime_storage_probe.gd` is a real 1/3/6/12 timing/storage/load gate with phase attribution and no waivers. |
| SRP-09 | `slot_runtime_storage_soak.gd` holds one seed/run for 180 accelerated minutes and 504 actions with twelve persistent cabinets, travel/revisits, active and settled bonuses, and repeated save/load. |

Final measured results (two consecutive clean dedicated-probe passes):

| Measurement | Baseline | Final | Budget |
|---|---:|---:|---:|
| 3-cabinet runtime p95 | 17.1 ms | 12.621 ms | <=16.6 ms |
| 6-cabinet runtime p95 | 27.3 ms | 12.784 ms | <=16.6 ms |
| 12-cabinet runtime p95 | 38.0 ms | 12.884 ms | <=16.6 ms |
| 12-cabinet scheduler inspection p95 | 167 µs full scan | 5 µs due-queue inspection | <=50 µs |
| Single-slot resolve avg/p95/max | audit baseline budget failure risk | 1.655 / 3.090 / 3.567 ms | <=6 / 8 / 10 ms |
| Settled cabinet maximum | definition/timeline dominated | 3,091 bytes | <=4,096 bytes |
| 12-cabinet capped-late v2 save | about 243 KB | 130,030 bytes | <=150,000 bytes |
| 12-cabinet snapshot handoff p95/max | synchronous 19.7 ms disk path | 0.254 / 0.254 ms | <=2 / 4 ms |
| Background autosave preparation p95 | combined main-thread save work | 1.735 ms | frame-safe |

Long-run and platform evidence:

- `user://slot_runtime_storage_probe_report.json`: pass; no strips or completed
  timeline duplication, no async errors, and v2 reload parity at 1/3/6/12.
- `user://slot_runtime_storage_soak_report.json`: pass; 19 samples through 180
  minutes, 504 actions, twelve cabinets at every sample, save growth 81,724 ->
  109,579 bytes, post-warmup memory +361,526 bytes, objects +2, nodes +4,
  orphans 0, and active/settled bonus state retained.
- `user://foundation_soak_probe_report.json`: pass; 504 measured actions, 224
  travels, 174 revisits, 21 save/load cycles, retained memory +1,969,752 bytes,
  objects +0, nodes +0, orphans 0, serialized maximum 105,578 bytes.
- `.tmp/web_perf_smoke/report.json`: pass in Chrome at 4x CPU throttle;
  corrected-board slot autoplay 100 ms p95 (budget 100), active slot 64.590 ms,
  pinball feature 141.202 ms (budget 180) with 479 animation redraws.
- `.tmp/foundation_determinism_probe/run_a.json` and `run_b.json`: pass; 10
  seeds, 320 checkpoints, identical combined hash `3075688543`.
- `foundation_visual_qa.ps1 -RequireGodot`: pass with zero warnings.
- `validate_project.ps1`: pass.

Inherited blockers and limits:

- A detached clean-`HEAD` run at `4cf2b440` and the final tree reproduced the
  same three slot acceptance failures exactly: Gold Buffalo collection does
  not advance, and Buffalo line/video sampled RTP are 0.77188/0.74195 versus
  their authored bands. The temporary comparison worktree was removed after
  recording the result; the retained final report is
  `.tmp/foundation_slot_acceptance_cache_fix.json`. The root fix changes none
  of those values. All pinball physics, visuals, seed variation, and feature
  simulations pass after the immutable-board cache correction. The optimized
  deep audit completes in 168.986 s versus clean-HEAD 221.447 s.
- The broader suite also inherits three dirty-tree travel content assertions,
  one tutorial dealer-line assertion, and the late-run Crew dialogue probe
  failure (28.106 ms/open-not-visible). These are outside SRP ownership. The
  slot-specific performance, offscreen autoplay, save, visual, Web, and soak
  rows are green without waivers or relaxed budgets.
