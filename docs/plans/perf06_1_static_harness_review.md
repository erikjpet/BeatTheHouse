# perf06_1 Static Harness Review and Execution Matrix

Status: **IN PROGRESS — static preparation only; no binding measurements yet**

Prepared from integrated source `ee9545fa` and refreshed onto closeout candidate
base `c2db39c0` with platform harness tip `fee1c755` on 2026-09-03. The final
candidate is still changing, so this review deliberately records no performance verdict.
It converts the existing prestage contract into an executable coverage map and
names every missing measurement before a quiesced run begins.

This preparation update adds native idle/resolve coverage for Craps and Crew
Draw Poker, Web idle/active coverage for Scratch Tickets and Crew Draw Poker,
the previously ungated Craps Web rows, same-window Web idle liveness deltas, and
an explicit fail-closed cold/warm cache selector. These rows are prepared but
deliberately unmeasured; their status stays `EXTEND` until the exact final
candidate runs them successfully.

## Measurement method frozen before execution

The final pass will use the unchanged protocol in
`docs/plans/perf06_1_measurement_prestage.md`, with these concrete defaults:

- exact final source and harness commits, clean tracked tree, Godot 4.6 stable;
- 1280x720, compatibility renderer, release exports for Windows and Web;
- ordered seed family `PERF06-FINAL-01` through `PERF06-FINAL-08` for surface
  samples and a separately named deterministic terminal/soak seed set;
- eight native repetitions, 120 measured idle frames per surface, 48 resolve
  samples, and warm-up/import samples discarded before measurement;
- Chrome Web runs with a fresh profile for cold start and a separate retained
  profile for warm start; the maintained 4x CPU profile is the historical Web
  comparison, not a substitute for the required low-end run;
- no unrelated Godot, compiler, browser-driver, export, or gate processes;
  three idle CPU/memory observations and process inventories before and after;
- nearest-rank p95, with mean, p95, max, sample count, draw calls, retained
  memory/object/node deltas, allocation proxy, and liveness recorded together;
- no outlier deletion and no retry-as-a-pass. Contaminated attempts are marked
  diagnostic and repeated only after restoring the declared conditions.

Preliminary host identity is `DESKTOP-1950ULQ`, Windows 10 build 19045,
Intel i9-9900K (8 cores/16 logical), 63.9 GiB RAM, NVIDIA RTX 4070 Ti driver
32.0.15.9636, with NVMe project storage. Exact power, thermal, display,
browser, export and binary identities will be captured again in the immutable
final manifests; these preliminary values are not binding evidence.

## Existing harness audit

| Harness | Current evidence | Safe to reuse | Missing for perf06_1 |
| --- | --- | --- | --- |
| `foundation_performance_probe` | Native idle/draw/resolve rows, liveness guard, full-snapshot counters, shipped-cap 160-body Coin Pusher actions, and separate raw 300-body solver stress | Yes | Prepared Craps and Crew Draw Poker additions await execution; full phase matrix, complete runtime allocation counters and immutable host/build manifest remain |
| `perf_telemetry_overlay` + desktop driver | Frame/process/physics/draw/memory/object/node/orphan samples and allocation proxy | Yes | Scratch Tickets/Crew Draw Poker and same-window liveness deltas are prepared but unmeasured; no maximal 0.6 composition plan or complete per-phase pairing |
| `web_perf_smoke` | Fresh export, explicit cold/warm Chrome profile, 4x CPU L0.2/Grand Casino/Coin Pusher plans, startup and telemetry overhead | Yes | Prepared L0.2 budgets, fail-closed liveness pairs and cold/warm selector await execution; ValidateSet still has no maximal-composition plan |
| `scenario_sequence_parity_performance` | Native/Web sequence timings and exact semantic parity for Corner Store Delivery Day | Yes | One scenario is not the maximal composition or all-archetype coverage |
| Family platform probes | Current native/Web parity for environment packages and game families | Yes, as functional side evidence | They are not one same-method performance matrix |
| `foundation_soak_probe` | Native 180-minute/504-action retained-state trajectory | Yes | No Web terminal soak and no proof that every 0.6 subsystem is live together |
| `foundation_determinism_probe` | Cross-system deterministic checkpoints | Yes | Needs exact final-candidate rerun and matching native/Web terminal traces |
| `export_distribution_fresh_start_check` | Isolated first-run persistence and Play-to-tutorial route | Yes | Must be run against final Windows and Web exports with first-interactive timing |
| SA.2 per-frame tripwire | Static scan rejects deep copy, JSON, delays, callable creation and packed/vector allocations on named frame paths | Yes | Runtime allocation counts remain proxies; the scan's function-name call graph must be paired with measured churn |

No existing harness is falsified by this review. The main risk is incomplete
coverage: several tools are strong within their original rows but none alone
satisfies the project-wide 0.6 matrix.

## Per-game matrix

Legend: `READY` means an existing final-source driver can collect the row;
`EXTEND` means the harness needs coverage added before a binding result exists.

| Game | Native | Web | Low-end | Required closure |
| --- | --- | --- | --- | --- |
| Pull Tabs | READY | READY | EXTEND | Add payout/redeem and staged-ritual phase rows |
| Scratch Tickets | READY | EXTEND | EXTEND | Add Web idle/purchase/scratch/reveal/payout rows with liveness |
| Slot | READY | READY | EXTEND | Split spin, autoplay, bonus and jackpot/attendant phases |
| Bar Dice | READY | READY | EXTEND | Preserve row-local parity; add explicit payout and ritual rows |
| Blackjack | READY | READY | EXTEND | Add betting/deal/skill/payout/ritual rows on the accepted authority runtime |
| Baccarat | READY | READY | EXTEND | Add reveal/skill/payout/ritual rows |
| Craps | EXTEND | READY | EXTEND | Add native idle/offer/aim/throw/bounce/settle/resolve rows |
| Roulette | READY | READY | EXTEND | Split spin, post-spin, skill and payout rows |
| Crew Draw Poker | EXTEND | EXTEND | EXTEND | Add actor-present ordered-hand idle/action/terminal rows |
| Video Poker | READY | READY | EXTEND | Add hold/draw/double-up/payout/ritual rows |
| Coin Pusher | READY | READY | EXTEND | Retain the exact shipped 160-body idle/drop/carriage/skill/collect rows, separate raw 300-body solver stress, ceiling refusal, and liveness rows |

Every animated idle row must include the counter name, floor, measured delta and
timing budget in one result. A zero idle value without a declared static reason
is a failure. Coin Pusher reduced-motion remains a distinct static-presentation
row whose solver liveness must still advance.

## System and composition matrix

| Surface or composition | Native | Web | Low-end | Required closure |
| --- | --- | --- | --- | --- |
| Meta home | READY | READY | EXTEND | Open, live idle and close |
| Quiet room/environment | READY | READY | EXTEND | Scene idle, focus, interaction and transition |
| Fully staged dynamic scenario | PARTIAL | PARTIAL | EXTEND | Add full actor/object stage, beat transition and terminal cleanup |
| Crew actor/dialogue/sequence | PARTIAL | EXTEND | EXTEND | Add actor-present idle, open/active/close and late-run sequence |
| World map and revisit | READY | READY | EXTEND | Bind travel/transition/revisit to exact same fixture |
| Talk/dialogue | READY | READY | EXTEND | Choice/advance/close rows and paired liveness |
| Run report/terminal | READY | PARTIAL | EXTEND | Add terminal transition and replay on exported build |
| Inventory/store/service | PARTIAL | PARTIAL | EXTEND | Add populated open/mutate/close rows |
| Audio | PARTIAL | PARTIAL | EXTEND | Add maximal authored cues, cleanup, voice caps and churn counters |
| Save/restore | PARTIAL | PARTIAL | EXTEND | Start/mid/maximal/terminal save timings and retained trajectory |
| `integ06_1` maximal node | EXTEND | EXTEND | EXTEND | Blocked only on final composition manifest/fixture identity |
| Start-to-terminal trajectory | PARTIAL | PARTIAL | EXTEND | Same seeds at start, warm, mid, maximal late and terminal/revisit |

`PARTIAL` is deliberately not a pass. It means one or more existing probes
collect useful counters, but the complete phase or composition required by the
row is absent.

## Budget and enforcement review

- Native game idle timing and liveness are structurally paired in
  `foundation_performance_probe.gd` through `GAME_IDLE_LIVENESS` and
  `PerformanceLivenessGuard.evaluate`.
- The native probe rejects full-snapshot rebuilding in steady idle and Coin
  Pusher active paths. The Systems SA.2 scan rejects the known per-frame copy
  and allocation patterns statically.
- Telemetry records frame, process, physics, draw calls, objects, nodes,
  orphans, static memory and positive/negative allocation proxies. It does not
  identify every language-level allocation, so static and runtime evidence are
  both required.
- The Web Coin Pusher plan correctly pairs idle draw cost with presentation and
  solver liveness. General L0.2 Web rows currently lack equivalent enforced
  per-surface liveness floors and must be extended rather than inferred from
  native results.
- The historical 10.2x scale calculation remains useful headroom evidence but
  is not the required low-end execution. The final report will name a physical
  low-end host or a reproducible whole-matrix throttle profile and will not
  label scaled arithmetic as a measured platform.
- Existing budgets remain unchanged until clean before-measurements identify a
  concrete miss. No optimization or budget change is authorized by this static
  review.

## Immutable identity inputs already located

- Godot console SHA-256 at preparation time:
  `FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE`.
- Canonical Coin Pusher release DLL SHA-256 at preparation time:
  `32E359661288EA6D53C30AB2D3DF3DB1963113A7CA0E824D01B6BD5EA5412A79`.
- Canonical Coin Pusher release Web side-module SHA-256 at preparation time:
  `8F02F72A9346E85D5B18A7498C85A5756FFD9D69B6393C428E82EF0E4E8E9573`.

These are provenance checks, not final identities. Every hash will be
recomputed after the last functional integration and before each export.

## Qualified Web crypto/template unblock (nonbinding)

The first exact exported-Web diagnostic reached READY but proved that the
previous locked thin template omitted not only `Crypto` but also
`HMACContext`. The minimal correction in `0a508712` keeps Godot's standard
mbedTLS module in the pinned Godot 4.6/Emscripten 4.0.20 single-threaded dlink
template; no custom cipher, authenticator, entropy bridge, or privacy downgrade
is present.

- Deterministic template SHA-256:
  `CF371F607AA9CB18E690BD595976C1BAAF00C8CEC24078E4A307FD515AD07913`.
- Template size: 6,055,590 bytes, an increase of 306,863 bytes over the prior
  5,748,727-byte locked template.
- Fresh exact-`9ba11ee8` Web export aggregate SHA-256:
  `18DE35F88146D39B88A91DF1D087924D672A3FC2DCC7951C8A6E97CC83D7F3D4`.
- Upload archive: 40,821,103 bytes, SHA-256
  `F7EC1E7877E4A4A566F4AA8B6349D9D44E1D149B0D13FC8454609CED25BA29CA`;
  exported main module `index.wasm` is 1,508,237 bytes.
- Chrome 152 fresh-profile READY was 4,889 ms from navigation and 5,162 ms
  wall clock; the complete focused proof finished in 6,386 ms. This is current
  load evidence, not the final cold/warm performance verdict.
- Exported Web stock `Crypto` returned exact, non-repeating 16-, 32-, and
  65,536-byte values. `AESContext` round-tripped, `HMACContext` rejected a
  tampered capsule, two capsules stayed distinct and fixed at 65,584 bytes,
  and canonical private payload bytes were absent. Page, request, and HTTP
  failure counts were zero; the only captured console entry was the expected
  browser audio-autoplay warning.
- The native Coin Pusher Web side-module remained ABI-compatible and passed
  the live-batch parity contract. Its binary SHA-256 is
  `67213C258BAB0330EB0CCD57E3B64F7E1415D0432BB9317DB21F0ECB66D5771C`;
  the parity payload SHA-256 is
  `C03588BABF0A5FB40B36349020DD90E43BBA4A1C8644C6A15C7BC1F54E31953F`.

The focused report and native-extension manifest are retained under
`.tmp/perf06_crypto_mbedtls_exact_9ba11ee8/` and
`.tmp/perf06_native_live_batch_exact_9ba11ee8_retry/`. These artifacts qualify
the release-input repair and harness. They do not replace the final exact-head
scenario matrix after all integration work lands.

## Development matrix qualification (nonbinding)

A short native development run at branch head `f7b4eaf2` exercised 46
observations with zero failures. All ten game resolve rows returned eight
accepted samples and eight observable progress samples. Its historical
300-body Coin Pusher live workload was a nonbinding stress run, not the current
shipped cap; it ran on `native_v3`, with DROP frame p95 9.049 ms and draw p95
5.104 ms. One pre-existing coverage warning remained because the generated
slot preview room was boss-kind rather than casino-like. The retained report is
`.tmp/perf06_native_development_f7b4eaf2/report.json`, SHA-256
`E57B0ADDDFE552DA99249BD09F04E40CCEF0FD6FD8EAF400FAB4FCE82146C56E`.

The corresponding warm-profile Chrome/4x Web development run completed all 27
L0.2 scenarios with zero page, request, or HTTP failures. Every one of the ten
active game rows was accepted and showed canonical progress, including Craps
and Crew Draw Poker. It correctly failed 29 release assertions: READY was
23,390 ms against 20,000 ms; Corner Store open was 10,848.010 ms against
1,200 ms; 17 frame-time rows exceeded their current budgets; and ten
same-window liveness assertions failed across Baccarat, Bar Dice, Craps, Crew
Draw Poker, Roulette, Scratch Tickets, and Video Poker. The retained
report/summary is under `.tmp/perf06_l02_development_f7b4eaf2/`.

The diagnostic also exposed a harness defect rather than seven proven frozen
surfaces. Most shipped Web idle surfaces deliberately declare a 1 Hz low-detail
cadence, while the first prepared gate demanded a frame-count-derived 4 Hz
floor. The corrected gate now exports each surface's effective production idle
FPS and scheduler elapsed time, extends every measured idle window through at
least two declared intervals, and derives its redraw floor from that elapsed
time. A row passes only when the same window has a stable positive declaration,
enough scheduler time, the due scheduled redraws, and a real canvas draw. This
does not raise a budget, reduce the 1 Hz production cadence, or let zero-draw
idle appear cheap. Focused fail-closed coverage lives in
`tools/web_perf_idle_liveness_contract_test.ps1`; the paired runtime contract in
`tools/perf06_idle_liveness_runtime_contract.gd` also proves scheduler/reset
semantics and keeps a monotonic draw total separate from the bounded 512-sample
timing buffer, so a long L0.2 run cannot conceal drawing through saturation.

These development runs prove the repaired fixtures dispatch real actions and
that stalled animation cannot pass as a cheap frame. They are not a waiver,
optimization baseline, or final performance verdict. The misses remain for the
exact integrated, quiesced-host pass to reproduce and attribute.

## Final matrix consumer and low-end launcher

The opt-in closeout harness now freezes every required shipped game and system
phase in `tools/perf06_required_matrix.json`. The catalog is checked against
`data/games/games.json`, so a newly shipped game cannot silently escape the
native, Web, and low-end matrix. `tools/perf06_matrix_contract.ps1` consumes,
rather than recreates, the integration lane's all-archetype composition and
terminal-soak manifests and shards. It requires exact candidate identity,
artifact hashes, zero uncovered composition rows, every ordering, Crew-ignore,
victory/failure/profile coverage, and equal same-seed native-repeat/Web traces.

Every required phase row fails closed unless it includes launch-bound hardware,
build, browser/throttle/device-scale metadata; frame/draw/liveness/retained-state
figures; and complete allocation/copy evidence for the phase's declared call
roots. The telemetry overlay's counters are pre-registered and exist only when
the explicit perf overlay is constructed. The measured code path marks a root
only after that root actually executes. Empty or partially marked roots are
ineligible, as frozen by `perf06_allocation_contract_test.ps1`; a label claiming
zero allocations is not evidence. The companion source audit hashes exact root
functions and rejects direct deep copies, JSON codecs, delays, and callable
creation. Its `direct_root_source` scope is deliberately narrower than a
transitive call graph and cannot be presented as one.

`tools/perf06_low_end_matrix.ps1` runs the same native/Web/integration producers
on a declared physical low-end host. It rejects a dirty or wrong candidate,
pre-existing evidence directories, a caller-selected label without a matching
profile hash, hardware fingerprint, actual Windows power plan, Chrome identity,
captured CPU throttle, 1280x720 viewport, device scale, and launch flags. It
passes exact candidate/profile/output arguments to the integration producers;
their simulation remains owned by `integ06_1`.

These files prepare the missing execution seams. They contain no measurement,
budget change, terminal simulation, or product optimization, and do not change
the `perf06_1` verdict before the exact final candidate populates every row.

## Final execution order

1. Receive the exact integrated candidate and composition manifest; rebase this
   harness-only branch without carrying product changes.
2. Finish the missing native/Web/low-end rows above and prove all liveness pairs
   and allocation/copy guards can fail closed.
3. Freeze manifests, confirm a clean tree and quiesced host, then run the native
   before-measurement matrix.
4. Run fresh Windows and Web exports, cold/warm Web startup, the 4x historical
   comparison, and the declared low-end matrix.
5. Run final-source composition, deterministic terminal traces, full retained
   soak, fresh-start distribution, and start-to-terminal trajectory.
6. Optimize only a measured failing hot path, preserving behavior and rerunning
   its parity/determinism/liveness pair. If nothing fails, make no product edit.
7. Publish raw artifact hashes, populate every matrix cell, record honest
   exceptions/findings, and only then archive `perf06_1` as DONE.

## Current verdict

The repository has strong reusable performance infrastructure, especially for
native game surfaces and Coin Pusher, but the final `perf06_1` verdict is not
available. Missing maximal-composition, Crew Draw Poker, complete Craps and
Scratch Web, general Web liveness, warm-start, and measured low-end rows are
real work—not paperwork—and remain open until the final candidate is frozen.

## 2026-09-04 recovered closeout preparation

The prebuilt platform series was recovered from
`codex/perf06-platform-mbedtls` and the aggregate candidate, then merged over
integrated main `3c836d18` without replaying old product branches. The inherited
performance edits to `scripts/ui/foundation_main.gd` were removed; that shared
file is byte-identical to the integrated base. Runtime allocation coverage now
binds to the subsystem timings the performance overlay already receives.

The recovered harness now also provides:

- a fresh Windows-release measurement launcher with exact executable, Godot,
  source, tree, profile and raw-report hashes;
- immutable per-phase runtime tags and phase-local production-canvas draw cost
  (or a conservative complete-frame upper bound where PixelSceneCanvas exposes
  liveness but no separate CPU draw timer);
- an honest surface-report builder that rejects missing action progress,
  liveness, draw samples, deep-copy evidence or exact-source identity;
- an immutable host-profile capture and a reproducible whole-matrix low-end
  mode that constrains the complete launcher tree to a declared processor mask
  and priority while retaining the required Web CPU throttle; and
- start/end clean-tree checks for native and Web evidence so a moving candidate
  cannot produce a qualifying report.

Preparation checks are green: the required 11-game/12-system catalog, negative
allocation fixtures, Web idle-liveness contract, Web active/prestage contract,
and seven direct call-root source audits. Godot import and the focused 177-file
UI/tools load are green. A deliberately shortened, nonbinding Windows release
diagnostic at `f152e480` completed all 27 L0.2 runtime scenarios; its numbers are
not release evidence because it used 30-frame/10-second diagnostic windows and
the final candidate is still moving. A concurrent broad smoke retained one
pre-existing lifecycle red (`Second foundation EnvironmentInstance should leave
home into the world`); content and all parse/load stages were green, and no
performance-owned file participates in that assertion.

The final verdict remains unavailable. It still requires the landed
`integ06_1` composition/terminal manifests, the final env06_8 candidate, full
120/240/600 native and Web windows, cold/warm Web starts, the exact low-end
whole-matrix run, all remaining canonical phase rows, and a clean-host rerun.

The maintained timing caps are now published without changes in
`tools/perf06_budget_table.json` (schema/version 1). The Web gate consumes that
file directly and records its version and SHA-256 in every summary; the native
probe retains its existing checked-in constants. The companion budget contract
pins representative Web caps, the native draw/solver/action caps, the required
idle-timing/liveness pairing, and the zero steady-state deep-copy policy. The
first exact Windows-release diagnostic using the real meta-home environment
produced a green 26-row canonical surface report; the earlier static start-menu
substitution is no longer eligible as meta-home liveness evidence.

## 2026-09-04 aggregate-candidate execution record

Candidate `e045a27d` is an exact, clean and pushed performance branch, but it is
not the final integrated release candidate. A fresh Chrome Web run of the L0.2
plan at CPU throttle 1 completed all 65 scenarios with zero failures. Its
retained report is `.tmp/perf06_1/web_l02_e045_cpu1_fresh.json`; READY was
4,743 ms and Corner Store opened in 945.145 ms. This qualifies the harness and
the unthrottled candidate only. It does not substitute for the required CPU4,
low-end, composition or final-candidate rows.

Two immediate fresh-export Coin Pusher runs on the quiesced Chrome 152 CPU4
profile are retained red:

| Evidence | READY | Gameplay frame result | Draw result |
| --- | ---: | --- | --- |
| `web_pusher_e045_cpu4_fresh` | 22,746 ms / 20,000 ms | all seven frame rows green | skill-stop 8.860 ms / 7.000 ms from only three draws |
| `web_pusher_e045_cpu4_fresh_confirm` | 23,150 ms / 20,000 ms | six active/idle rows green; reduced-motion 16.667 ms / 16.000 ms | skill-stop returned to 3.200 ms; reduced-motion moved red to 9.000 ms / 5.000 ms from one draw |

The draw miss moved between phases instead of reproducing in one path. The
gate had accepted p95 values built from as few as one draw, which is not a
statistically eligible nearest-rank percentile. The harness now discards three explicit
production-canvas warm-up draws and requires at least 20 measured draws for
every Coin Pusher p95. Sparse measurement-only redraw requests use the real
canvas at 15-frame intervals; they do not advance the production animation
scheduler, change gameplay, or alter the 5/7 ms draw and 16/22 ms frame caps.
This hardening is not a pass until the exact candidate reruns it.

The cold-start red is separate and stable. The release export contains a
21,802,358-byte `index.side.wasm` engine module (41,022 functions), a
1,508,237-byte `index.wasm` loader module (5,043 functions), a 337,393-byte
Coin Pusher extension (516 functions), and a 43,850,988-byte PCK. The combined
engine WebAssembly payload is 23,310,595 bytes, already 38.15% smaller than the
37,686,550-byte official dlink template; its compressed template archive is
36.73% smaller. In the second
CPU4 run, the DOM loaded in 374.730 ms and every WebAssembly/PCK response ended
by 1,190.375 ms, but project code did not reach `engine_ready_start` until
21,049 ms. Foundation then reached the interactive menu in 636 ms. The same
pre-project hold appears across the retained CPU4 history (22.746-24.983 s
READY), so retry variance cannot close it.

The shipped custom engine is already a stripped production release:
single-threaded, SIMD-enabled, assertions disabled, `optimize=size`, 3D,
physics, navigation and XR disabled, a restricted class profile, and only the
GDScript, FreeType, fallback text, WebP and required mbedTLS modules enabled.
It deliberately uses `lto=none`; the native extension itself is stripped O3
release code and is less than two percent of the large engine side module.
Loading that small extension later cannot avoid compiling the dynamic-linking
engine before project startup. Removing the 21.8 MB engine tax would require a
validated smaller dynamic-linking template or moving the solver into a static
engine module/non-GDExtension bridge, neither of which may be represented as a
narrow or already-proven change.

Therefore `perf06_1` remains **IN PROGRESS**. The 20-second READY and 5/7 ms
draw budgets are unchanged and unwaived. The final candidate must rerun the
20-sample Coin Pusher gate and complete the native/Web/declared-low-end and
`integ06_1` composition matrices before this row can close.

### LTO cold-start experiment

Two isolated engine-template experiments changed only the pinned Godot LTO
mode and its mirrored artifact identity. Every run used a fresh export, Chrome
152, CPU throttle 4, cold cache, a clean exact commit and a quiesced host. All
red reports were retained; none was retried into a pass.

| Template | Archive SHA-256 | Archive bytes | Side/main Wasm bytes | CPU4 cold READY runs |
| --- | --- | ---: | ---: | --- |
| no LTO baseline | `cf371f607aa9cb18e690bd595976c1baaf00c8cec24078e4a307fd515ad07913` | 6,055,590 | 21,802,358 / 1,508,237 | 22,746; 23,150 ms |
| ThinLTO | `71e8ece320188e450f1d0272de590b87b53cd3ef654219c36dde5a304746e8de` | 6,225,810 | 22,433,415 / 1,508,095 | 22,144; 22,885; 22,616 ms |
| FullLTO | `726c7427795bb0b78c3d4051457c82e98ddddce8ae24f98a1903a097497fc03e` | 6,155,921 | 21,521,191 / 1,497,255 | 22,661; 23,199; 23,148 ms |

ThinLTO's `engine_ready_start` values were 20,165, 20,801 and 20,510 ms.
FullLTO's were 20,554, 21,053 and 21,058 ms. Neither candidate reached the
20,000 ms READY cap, much less enough margin to qualify as a stable fix.
ThinLTO increased the dominant side module by 2.9%; FullLTO reduced it by only
1.3% and did not improve startup. Both candidates were explicitly reverted;
the reviewed final source and lock remain on `lto=none` and the baseline hash.

The first eligible 20-sample runs also exposed a harness ordering defect: its
reduced-motion boundary event was recorded before the three discarded warm-up
draws, while the scenario's before-state was recorded after them. The marker is
now emitted at the actual post-warm sample boundary. All three FullLTO runs
passed that exact fixture/liveness linkage check. Their eligible idle draw p95
values were 7.395, 7.670 and 7.400 ms against 5.000 ms; reduced-motion draw p95
was 5.580, 7.195 and 6.480 ms against 5.000 ms. This is now a reproducible draw
hot-path failure, separate from the rejected engine-startup experiment.
