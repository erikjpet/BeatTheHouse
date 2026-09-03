# perf06_1 Static Harness Review and Execution Matrix

Status: **IN PROGRESS — static preparation only; no binding measurements yet**

Prepared from integrated source `ee9545fa` and refreshed on current integration
root `47a3a241` through harness head `9ba11ee8` on 2026-09-03. The final
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
| `foundation_performance_probe` | Native idle/draw/resolve rows, liveness guard, full-snapshot counters, 300-body Coin Pusher actions and solver | Yes | Prepared Craps and Crew Draw Poker additions await execution; full phase matrix, complete runtime allocation counters and immutable host/build manifest remain |
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
| Coin Pusher | READY | READY | EXTEND | Retain exact 300-body cap, idle/drop/carriage/skill/collect/solver/ceiling/liveness rows |

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
accepted samples and eight observable progress samples. The full-cap Coin
Pusher sequence ran on `native_v3`; DROP frame p95 was 9.049 ms and draw p95
was 5.104 ms. One pre-existing coverage warning remained because the generated
slot preview room was boss-kind rather than casino-like. The retained report is
`.tmp/perf06_native_development_f7b4eaf2/report.json`, SHA-256
`E57B0ADDDFE552DA99249BD09F04E40CCEF0FD6FD8EAF400FAB4FCE82146C56E`.

The corresponding warm-profile Chrome/4x Web development run completed all 27
L0.2 scenarios with zero page, request, or HTTP failures. Every one of the ten
active game rows was accepted and showed canonical progress, including Craps
and Crew Draw Poker. It correctly failed 29 release assertions: READY was
23,390 ms against 20,000 ms; Corner Store open was 10,848.010 ms against
1,200 ms; nine frame-time rows exceeded their current budgets; and same-window
idle liveness failed closed for Baccarat, Bar Dice, Craps, Crew Draw Poker,
Roulette, Scratch Tickets, and Video Poker. The retained report/summary is under
`.tmp/perf06_l02_development_f7b4eaf2/`.

These development runs prove the repaired fixtures dispatch real actions and
that stalled animation cannot pass as a cheap frame. They are not a waiver,
optimization baseline, or final performance verdict. The misses remain for the
exact integrated, quiesced-host pass to reproduce and attribute.

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
