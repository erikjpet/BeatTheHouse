# perf06_1 Measurement Prestage

Status: **UNREVIEWED PRESTAGE — no 0.6 measurement claim**

This document prepares the evidence contract for `perf06_1`. It does not claim
the board row, does not replace its final report, and does not treat the current
partial 0.6 tree as a release candidate. No Godot process, performance harness,
product file, budget, or measurement was changed or run for this prestage.

## Bound qualifying checkpoint

The only qualifying 0.6-era checkpoint bound here is the owner-approved
quiesced baseline recorded by exact commit:

- checkpoint: `a04fa18b2161113cc7e9b14ac4df1354d76c84e5`
- measured source: `a62f48840686c6b5d09a6e5670bb537fd86e15bc`
- run window: 2026-08-27 23:29:07–23:29:54 CDT
- result: exit 0 in 47.767 seconds; 73 observations across 8 seeds; zero
  failures
- quiescence witnesses: `0814cec1` (worker) and `a41d9339` (director)
- host precondition: zero Godot, compiler, or gate processes; three CPU samples
  of 8.620%, 18.961%, and 11.060%
- exercised Coin Pusher fixture: historical 300-body live stress workload,
  not the current shipped cap
- Coin Pusher active frame/draw/resolve milliseconds:
  - drop: 18.618 / 5.887 / 14.884
  - carriage: 13.950 / 5.307 / 11.828
  - skill stop: 13.888 / 5.221 / 12.165
  - skill release: 13.987 / 5.247 / 12.085
  - collect: 13.977 / 5.241 / 13.969
- Coin Pusher raw solver p95: 3.863 ms
- named non-pusher observations: Scratch resolve max 4.118 ms; Baccarat
  resolve p95 1.041 ms

The checkpoint is evidence for its exact source only. Its commit record does
not contain a complete hardware manifest, build/export manifest, seed list,
warm-up record, raw report, per-surface table, Web run, low-end run,
composition run, full-run trajectory, or allocation matrix. Those omissions
must not be reconstructed by assumption.

Owner ruling attached to the checkpoint: performance is a quiesced checkpoint
gate after every five landings and before any playtest build; functional gates
remain mandatory per landing.

## Quiesced measurement protocol

The final `perf06_1` owner must publish this protocol before collecting binding
numbers and retain one immutable manifest per run.

1. Bind the exact source commit, native-plugin binary hash, Godot version,
   build/export identity, harness commit, and budget-table version.
2. Reserve the measurement host. Stop or finish all unrelated Godot, compiler,
   gate, export, browser-driver, and test processes. Do not measure while
   parallel gates or builds are active.
3. Record worker/director quiescence witnesses and a process inventory. Capture
   repeated idle CPU and memory samples before starting. If the host is not
   quiescent, record the attempt as contaminated and do not qualify it.
4. Warm the Gate Service environment deliberately: native plugin built and
   hashed, imports complete, and required caches in the declared cold/warm
   state. Cold Web startup must use a fresh browser/cache profile; warm Web
   measurements must use a separately named warmed profile.
5. Fix resolution at 1280×720 and record display mode, renderer, quality
   settings, frame cap/vsync, audio state, browser version and flags, throttle
   profile, and power/thermal state.
6. Use a published deterministic seed list. Record the warm-up actions and
   frames separately from measured samples. Never include shader/import/startup
   warm-up in an active-frame distribution unless the row is explicitly a cold
   startup row.
7. Run the complete native, exported Web, and low-end matrices against the same
   candidate and scenario definitions. Preserve raw samples, summaries,
   stdout/stderr, and exact commands.
8. Pair every idle cost row structurally with its liveness counter, required
   floor, measured count, and pass/fail. An animated idle surface reporting
   zero samples is a failure. A deliberately static surface requires an
   explicit accepted zero-liveness reason.
9. Record allocation/copy counters alongside frame and draw figures. Per-frame
   deep copies and unbounded per-frame allocation are failures even when timing
   happens to fit the host budget.
10. Repeat the quiescence inventory after the run. A run affected by newly
    active competing processes is diagnostic, not qualifying.
11. Qualify the checkpoint only when all required matrix cells are populated,
    all applicable 0.5 comparisons are resolved, and every exception is
    owner-approved without silently changing a budget.

The five-landing checkpoint cadence does not make an intermediate partial tree
the final `perf06_1` candidate. The binding row still waits for Families 1 and
2 and the required compositions to be merged.

## Required run-manifest fields

Every native, Web, and low-end result must carry the following fields rather
than relying on prose around a report.

| Category | Required fields |
| --- | --- |
| Identity | source commit; harness commit; native-plugin SHA-256; plugin source/backend identity; Godot version; report schema version; budget-table version |
| Hardware | host identifier; OS/build; CPU model, logical/physical cores, governor/power plan; RAM; GPU and driver; storage; display refresh; thermal/power state |
| Build | debug/release/template type; architecture; renderer; native/Web backend; export preset hash; executable/PCK/WASM sizes and hashes; import/cache state |
| Runtime | 1280×720 mode; vsync/frame cap; quality settings; audio state; locale; browser/version/flags; worker/thread configuration; CPU throttle/low-end method |
| Quiescence | witnesses; process inventory before/after; idle CPU samples; idle memory; rejected contamination reason if applicable |
| Seeds | ordered seed list; seed prefix; scenario fixture/version; number of repetitions; deterministic checkpoint identity |
| Warm-up | cold or warm classification; cache/profile identity; import/shader warm-up; warm-up actions and frames; discarded samples |
| Sampling | clock/timer; frames per idle/active phase; resolve samples; allocation interval; percentile method; outlier policy; start/end timestamps |
| Result | mean/p95/max; draw calls/cost; frame cost; resolve cost; allocations/copies; liveness counter/floor/count; pass/fail; raw artifact path/hash |

The final report must mark a field `unknown` when historical evidence did not
record it. It must not infer a hardware or sampling value from a later harness
default.

## Required measurement matrix

Each applicable row below is required for **native**, **exported Web**, and the
declared **low-end profile**. Each surface phase records frame mean/p95/max,
draw mean/p95/max and call count, allocations/copies, retained-state change,
and liveness. Action rows additionally record synchronous resolve
mean/p95/max. Web startup rows record cold and warm cache separately.

### Per-game surfaces

| Surface | Required phases |
| --- | --- |
| Pull Tabs | idle; purchase/active; payout/redeem; staged ritual sequence |
| Scratch Tickets | idle; purchase; scratching/reveal; payout; staged ritual sequence |
| Slot | static idle with accepted zero reason; spin; autoplay; bonus; jackpot/attendant path if retained by the authority decision |
| Bar Dice | idle; wager/roll; resolve/payout; staged ritual sequence |
| Blackjack | betting idle; deal/action; cheat/skill surface; resolve/payout; staged ritual sequence |
| Baccarat | betting idle; deal/reveal; cheat/skill surface; resolve/payout; staged ritual sequence |
| Roulette | betting idle; spin; post-spin animation; cheat/skill surface; resolve/payout; staged ritual sequence |
| Video Poker | idle; wager/draw/hold; double-up/feature; payout; staged ritual sequence |
| Coin Pusher | exact 160-body shipped-cap idle/drop/carriage/skill stop/skill release/collect; separate raw 300-body solver stress; ceiling refusal; staged ritual sequence |

The final inventory must add every Family 1 or Family 2 game/surface that lands
after this prestage; absence from this table is not an exemption.

### Non-game and system surfaces

| Surface/system | Required phases |
| --- | --- |
| Meta home | open and animated idle |
| Room/environment | isolated quiet room; object focus; interaction; scene idle |
| Dynamic scenario runtime | fully staged sequence with all authored actors/objects; transition between beats; terminal cleanup |
| Crew | actor-present idle; dialogue open/active/close; full crew sequence; late-run fixture |
| World | map idle; travel/transition; maximal populated environment; return/revisit |
| Talk/dialogue | talk dock active; dialogue active; choice/advance; close |
| Report/run end | report open; replay; terminal transition |
| Inventory/store/service | open; populated active state; mutation; close |
| Audio | quiet idle; maximal concurrent authored cues; transition cleanup; allocation/copy activity |
| Save/restore | save at start/mid/terminal; restore/revisit; serialized-size and retained-state trajectory |

### integ06_1 compositions

Measure actual compositions delivered by `integ06_1`, not synthetic estimates.
At minimum the matrix must identify and sample:

- every authored cross-family composition independently;
- maximal environment node/object/actor population;
- maximal simultaneous scenario staging, crew presence, world activity, UI,
  game surface, effects, and audio allowed by the shipped runtime;
- transitions into, within, and out of the maximal composition;
- active-game plus background-runtime work;
- save/restore while the composition is live; and
- terminal cleanup, including retained nodes/resources/objects and orphan count.

The `integ06_1` composition manifest, exact fixture ids, expected active
systems, and authored maximum counts are currently missing and must be supplied
before the final matrix can be executed.

### Full-run trajectory

Use the same seeds and sampling points to compare start, post-warm-up,
representative mid-run, maximal late-run, and terminal/revisit state. Record:

- frame/draw/resolve distributions;
- static and dynamic memory;
- node, object, resource, timer, signal, and audio-player counts;
- serialized RunState size;
- bounded receipt/history/cache/actor/object counts;
- allocations and deep/shallow copies per frame and per action; and
- liveness floors at every sampled animated surface.

## Allocation and liveness pairing

The final budget table must contain one inseparable row per surface/phase:

| Platform/profile | Surface/phase | Frame mean/p95/max | Draw mean/p95/max + calls | Allocation/copy counters | Liveness counter measured/floor | Existing budget | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| unmeasured | unmeasured | unmeasured | unmeasured | unmeasured | unmeasured | unchanged | unmeasured |

No budget is proposed or changed by this prestage. The final implementation may
add enforcement only after measurements name the missing coverage. An idle
timing assertion and its liveness assertion must be in the same test structure
so a later optimization cannot retain one and remove the other. Per-frame
allocation enforcement must distinguish finite warm-up from recurring churn
and must fail deep-copy activity on the steady-state frame path.

## Web and low-end requirements

The exported Web matrix must include:

- export archive, PCK, WASM, JavaScript, and native-module sizes/hashes;
- cold load and warm load;
- navigation start to engine-ready and first interactive frame;
- first-time profile to actual play without a stall;
- scene frame, memory, liveness, allocation, and composition rows;
- telemetry overhead;
- fresh-start distribution validation; and
- browser console/network failures and worker/thread configuration.

The low-end profile must name whether it is physical hardware or a reproducible
throttle. It must run the same functional scenarios and report the actual
profile; a development-host scale-factor calculation alone is not the required
low-end run.

## Available 0.5 comparators

The authoritative 0.5 exact-source section in
`docs/plans/0.5_performance_audit.md` records source through `84ae3fc6` and the
following usable comparator classes:

- native idle draw mean/p95/max and liveness for Pull Tabs, Scratch Tickets,
  Slot, Bar Dice, Blackjack, Baccarat, Roulette, and Video Poker;
- native resolve mean/p95/max for those eight game paths;
- Slot autoplay draw p95;
- Grand Casino living-floor frame p95;
- meta home, talk dock, dialogue, eviction-map transition, report replay, and
  Rourke duel figures;
- Web 4x cold-ready time, telemetry overhead, the L0.2 and Grand Casino plan
  pass records;
- three-hour soak memory/object/node/orphan and serialized-state figures; and
- focused Slot storage and long-run storage-soak figures.

Comparisons must use like-for-like platform, build, scenario, throttle,
resolution, sample policy, and metric semantics. Otherwise the 0.5 value is
context only and the report must say why it is not a valid delta.

## Missing 0.5 comparators

The checked-in 0.5 records do **not** provide a complete like-for-like
comparator for:

- Coin Pusher, which was not in the listed 0.5 per-game surface table;
- the 0.6 dynamic scenario runtime with a full sequence staged;
- the 0.6 crew sequences with the current authored actor count;
- the 0.6 world/environment expansions and their maximal population;
- any Family 1 or Family 2 depth surface added or materially re-composed in
  0.6;
- `integ06_1` maximal cross-family compositions;
- the complete per-surface allocation/deep-copy matrix;
- a single checked-in table of native/Web/low-end results collected from the
  same source, hardware manifest, seeds, warm-up, and sample policy;
- a physical low-end hardware run for every required surface/composition;
- per-surface Web mean/p95/max, draw, allocation, and liveness numbers for all
  current matrix rows (the 0.5 summary reports many plan outcomes without the
  full raw table in Git);
- cold and warm Web startup from an identical 0.5 export/profile protocol; and
- start-to-terminal trajectories for all current state-growth and allocation
  counters.

These are `no historical comparator`, not regressions and not passes. The final
report must establish a reproducible 0.6 baseline for them and may compare only
the overlapping metrics whose definitions still match.

## Current completion state

| Deliverable | State |
| --- | --- |
| Quiesced protocol and manifest schema | PRESTAGED, UNREVIEWED |
| `a04fa18b` exact qualifying baseline | RECORDED AS HISTORICAL EXACT-SOURCE EVIDENCE |
| Native full matrix | NOT RUN |
| Web full matrix | NOT RUN |
| Low-end full matrix | NOT RUN |
| Per-surface allocation/copy matrix | NOT RUN |
| integ06_1 composition matrix | BLOCKED on final composition manifest and merged candidate |
| Family 1/2 final surface inventory | BLOCKED on merged families |
| 0.5 comparator normalization | PARTIAL; missing items listed above |
| Budget/enforcement changes | NONE |
| Optimizations | NONE |
| Final perf06_1 verdict | NOT AVAILABLE |

