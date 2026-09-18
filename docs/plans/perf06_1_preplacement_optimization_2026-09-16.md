# perf06_1 Pre-placement Optimization Probe — 2026-09-16

Status: **REDUCED, NON-BINDING DIAGNOSTIC — not Phase 4 qualification**

This pass profiles and improves shared code that is expected to survive the
replacement-placement work. It deliberately does not change a published
performance budget, simulation rule, economy value, RNG path, liveness floor,
or native/Web behavior contract.

## Candidate and method

- before source: `cf50b79b`
- optimized source: `6321b41e78bc781c1f2baf9064b88f66d89d8e36`
- normal profile SHA-256:
  `a12979de7462192e1a1eb4c95f6a10cf86010f1723b9e9379e297faa528b047d`
- low-end profile SHA-256:
  `ad33548cde64794509ac65e155e0e7b7026e6225f75edf3b98c4e4473b226bc4`
- targeted foundation samples: 3 runs, 60 frames per surface and 24 resolve
  samples
- Web low-end probe: Chrome CPU throttle factor 4
- local before evidence:
  `.tmp/preplacement_perf_20260916_baseline_cf50b79b/`
- local after evidence:
  `.tmp/preplacement_perf_20260916_after_6321b41e/`

The `.tmp` evidence is intentionally ignored local diagnostic output. These
figures are useful for deciding whether to retain an optimization, but do not
satisfy the quiescence, witness, sample-size, accepted-placement, or immutable
artifact requirements of the binding runbook.

## Decisions by requested focus area

| Area | Finding and decision |
| --- | --- |
| UI construction and lazy loading | Existing native asynchronous prewarm, staged Web run-UI prewarm, and deferred secondary menu panels already keep the first interactive surface bounded. The 31-root Web deferral contract passed. No speculative rewrite was made. |
| Menu and run-screen startup | Native distribution passed before and after. Normal Web ready moved from 4,344 ms to 4,056 ms; throttled Web ready moved from 18,113 ms to 16,451 ms. Corner Store startup moved from 1,704 ms to 1,715 ms on normal Web and 6,399 ms to 5,419 ms under throttle. The mixed results and short samples do not identify a stable shared-code hotspot, so no startup code was changed. |
| Game-surface redraw caching | Removed recurring deep copies from the common table redraw path while retaining malformed-fixture filtering. Retained. |
| Per-frame allocations and deep copies | The common table renderer now borrows canonical read-only dictionaries and arrays. The allocation contract and seven-root call-site audit pass. Retained. |
| Dialogue and Crew UI projection | A candidate removal of portrait projection copying measured neutral: late-Crew open 4.077→4.060 ms and selection 3.765→3.782 ms, with no talk/dialogue improvement. It was reverted and is not in the candidate. |
| Save/resource lifecycle and retained cleanup | Native L0.2 showed no steady object-position growth. The throttled Web memory scenario improved from 39.007 ms to 24.074 ms and had no positive object-growth signal. Normal Web had a short-window +2.98 MB heap delta with zero object growth, consistent with unforced browser GC and not sufficient to justify lifecycle changes. |
| Coin Pusher renderer | Cached the immutable five-scalar delivery-board projection instead of allocating the same dictionary on redraw. Static-cache pixel/command ordering, deterministic traces, and native/Web solver parity pass. Retained. |

## Optimization 1: common table renderer read-only views

The renderer previously deep-copied dealer, focus, patron, and wager
projections every animated redraw. The optimized path borrows canonical
read-only values. If a compatibility fixture supplies a malformed patron
array, the fallback still filters non-dictionaries without cloning valid
entries.

Targeted idle draw results:

| Surface | Before avg / p95 ms | After avg / p95 ms | p95 change |
| --- | ---: | ---: | ---: |
| Bar Dice | 2.608 / 5.601 | 1.672 / 1.765 | -68.5% |
| Craps | 1.036 / 1.096 | 0.851 / 0.887 | -19.1% |
| Blackjack | 3.068 / 3.158 | 2.597 / 2.686 | -14.9% |
| Baccarat | 1.863 / 1.979 | 2.476 / 2.625 | +32.6% |
| Roulette | 3.273 / 3.267 | 2.523 / 2.734 | -16.3% |
| Crew Draw Poker | 0.837 / 0.928 | 0.624 / 0.741 | -20.2% |

The Baccarat short-sample row regressed but remained below its unchanged
5 ms budget. Five of six affected surfaces improved, Bar Dice changed from a
red 5.601 ms p95 to a green 1.765 ms p95, and the complete after foundation
probe passed. This optimization was retained because it removes objectively
recurring deep-copy work and has broad measured benefit without changing the
projection values.

## Optimization 2: Coin Pusher delivery-board cache

The delivery board is a renderer-only projection of five authored scalar
values. The optimized renderer reuses its dictionary until one of those exact
values changes. It neither caches simulation state nor changes body stepping,
events, rewards, conservation, or draw ordering.

Targeted draw results after Optimization 1 and immediately before/after this
cache:

| Coin Pusher phase | Before avg / p95 ms | After avg / p95 ms | p95 change |
| --- | ---: | ---: | ---: |
| Idle | 2.618 / 2.741 | 2.561 / 2.656 | -3.1% |
| Active drop | 2.589 / 2.673 | 2.565 / 2.636 | -1.4% |
| Active carriage | 2.628 / 2.712 | 2.614 / 2.717 | +0.2% |
| Skill stop | 2.601 / 2.675 | 2.600 / 2.676 | +0.0% |
| Skill release | 2.635 / 2.723 | 2.611 / 2.689 | -1.2% |
| Collect | 2.513 / 2.654 | 2.512 / 2.661 | +0.3% |

This is a small allocation reduction, not a frame-time breakthrough. It was
retained because the idle/drop/release rows improved, the other movements are
within short-run noise, and exact visual and parity contracts pass.

## Whole-probe comparison

These results cover the combined candidate and are diagnostic rather than a
causal attribution to either small code change.

| Probe | Before | After |
| --- | --- | --- |
| Native first-start distribution | PASS; first interactive 51 ms; play-to-tutorial 2,945 ms | PASS |
| Native L0.2 | RED: quiet room/audio liveness floors | RED: same two liveness floors plus Scratch purchase and Video Poker draw/hold timing |
| Normal Web L0.2 | RED: four Corner Store boundary/reconciliation diagnostics | RED: the same four diagnostics |
| Throttled Web L0.2 | RED: four Corner diagnostics plus Slot autoplay, Baccarat active, Blackjack idle, and Slot idle | RED: the same eight failure classes |
| Throttled Web Bar Dice idle | frame p95 16.715 ms; draw p95 20.470 ms | frame p95 12.500 ms; draw p95 17.265 ms |
| Throttled Web Bar Dice active | frame p95 70.913 ms; draw p95 23.280 ms | frame p95 59.330 ms; draw p95 17.450 ms |
| Throttled Web Baccarat idle draw | 38.425 ms p95 | 18.055 ms p95 |
| Throttled Web Roulette idle draw | 47.675 ms p95 | 18.480 ms p95 |
| Throttled Web Crew active | frame p95 42.415 ms; draw p95 15.665 ms | frame p95 33.333 ms; draw p95 13.660 ms |

The newly red native timing rows are outside the two changed renderers and are
treated as reduced-sample variance or independent follow-up risk, not as a
budget exception. The Web runs preserve the same failure classes before and
after. No budget was changed to alter any result.

## Coin Pusher cost and invariants

- native active draw p95 values were 2.278–2.645 ms and green; the independent
  ceiling-refusal diagnostic remained red at 6.698 ms against 5 ms
- throttled Web active carriage draw p95 was 8.025 ms against 7 ms, and reduced
  motion draw p95 was 5.210 ms against 5 ms
- fresh parity passed across two independent Windows `native_v3` runs and two
  independent Web `gdscript_v3` runs with exact payload SHA-256
  `f3ab1247c8d11bb7ca0348cce258e7e101fb771b653f1389ac985daef2325e15`
- determinism passed twice across 3 seeds and 223 checkpoints with combined
  hash `3961074125`
- the production static-cache contract passed exact pixel and command ordering
- fixture identity and conservation checks passed

## Validation and remaining risk

Passing checks:

- targeted foundation probe after both retained changes
- native first-start distribution
- allocation contract and allocation call-root audit
- 31-root Web run-UI deferral contract
- Coin Pusher action-diagnostic contract
- Coin Pusher cached-backglass readability contract
- Coin Pusher production static-cache contract
- fresh native/Web exact input parity
- deterministic replay probe

The focused `check_godot` Bar Dice suite reached project validation and script
load successfully, then exceeded its 240-second fixture-suite timeout while
loading the large foundation fixture set. The smaller targeted foundation
probe completed and covered the changed common renderer. This timeout is not
reported as a pass.

This pass does not close `perf06_1`. Binding performance still waits for the
accepted placement candidate, a quiescent host, required witnesses, full
sample sizes, cold/warm matrices, and the unchanged runbook gates. The current
red low-end, liveness, startup-boundary, and Coin Pusher ceiling/carriage rows
remain visible follow-up work; none was waived.

## Continued shared-code pass

This continuation started from `154286fd`, retained the game/runtime changes in
`e4e24a20`, added the auto-tick host optimization in `08d61a90`, and repaired
the pinned Web-native build wrapper in `b61f2595`. Local evidence is under
`.tmp/perf_continue_20260916/`. It remains reduced, non-binding evidence.

The continuation did not change a performance budget, game rule, payout,
simulation step, RNG call, liveness requirement, or visual contract.

### Retained runtime optimizations

| Path | Before | After | Decision |
| --- | ---: | ---: | --- |
| Roulette active realtime p95 | 11,028 us | 285 us | Retained compact host-preserving projection. |
| Roulette ritual realtime p95 | 9,888 us | 302 us | Retained. |
| Bar Dice active realtime p95 | 4,764 us | 11 us | Retained; refresh cadence now follows its existing 900 ms tumble animation. |
| Crew Draw Poker active realtime p95 | 1,913 us | 134 us | Retained compact projection. |
| Baccarat active realtime p95 | 345 us | 253 us | Retained shallow result/session view. |
| Baccarat active module p95 | 162 us | 79 us | Retained. |
| Pinball realtime p95 | 508 us | 403 us | Retained compact steady-state patch after atomic takeover. |
| Scenario validated finalization | 398.630 ms | 65.653 ms | Retained trusted prevalidated internal path after exact validation. |
| Scenario core startup total | 505.790 ms | 169.642 ms | Retained. |
| Scenario travel startup | 677.086 ms | 335.388 ms | Retained. |
| Extreme-state meta interaction projection | 765.357 ms | 152.008 ms | Retained definition/icon/read-only caches. |
| Extreme-state collection projection | 101.266 ms | 71.411 ms | Retained single-snapshot/read-only projection. |

The same native reduced probe passed 46 observations with all 11 game surfaces
and renderer families covered. A 30-minute native lifecycle soak reported
`memory_growth=0`, `object_growth=0`, and `node_growth=0`; cache caps held.

### Throttled Web results

The first continuation report is
`.tmp/perf_continue_20260916/web_l02_cpu4_after.json`. Compared with the prior
renderer-only candidate, the important shared-path changes were:

| Scenario | Prior Web result | Continued result |
| --- | ---: | ---: |
| Bar Dice active frame p95 | 59.330 ms | 17.398 ms |
| Bar Dice active realtime p95 | 24.260 ms | 0.175 ms |
| Baccarat active realtime p95 | 18.625 ms | 1.995 ms |
| Baccarat ritual realtime p95 | 27.280 ms | 3.005 ms |
| Roulette active realtime p95 | 40.465 ms | 2.165 ms |
| Roulette ritual realtime p95 | 41.360 ms | 4.200 ms |
| Crew Draw Poker active realtime p95 | 10.250 ms | 3.000 ms |
| Slot active realtime p95 | 5.060 ms | 1.810 ms |
| Pinball realtime p95 | 6.620 ms | 4.015 ms |

The final fresh-export report is
`.tmp/perf_continue_20260916/web_l02_cpu4_auto_tick_after_b61.json`. It binds
source `b61f25954cf09f3f41583591ed6801706f8c5e7c` to export SHA-256
`9ca173340bdc6206cbf38d6a0b18456353892d14a1a3efb69700a61f6f785723`.
It completed all 61 scenarios with no page errors or request failures.

Pull Tabs was still rebuilding the generic selected-stake/action projection on
every active Auto Open frame even though its deadline and command consume only
the auto-open flag and timestamp. Foundation now computes stake for a compact
auto-tick state only when the module explicitly requests `selected_stake`.

| Pull Tabs payout/redeem metric | Before | After | Change |
| --- | ---: | ---: | ---: |
| Automation average | 11.027 ms | 3.181 ms | -71.2% |
| Automation p50 | 7.630 ms | 0.205 ms | -97.3% |
| Automation p95 | 10.060 ms | 1.025 ms | -89.8% |
| Whole-frame p95 | 33.333 ms | 26.772 ms | -19.7% |

Slot did not show a causal improvement from that host edit, so no Slot win is
claimed. Its autoplay p95 moved from 118.557 ms to 124.093 ms and remains red.
The final Web wrapper is also red for four existing Corner Store timing-schema
diagnostics, Baccarat active at 149.230 ms against 120 ms, and a noisy Slot
idle sample at 50.000 ms against 45 ms. These failures remain visible and no
budget was loosened.

### Rejected experiment and build reliability

Removing redundant-looking outer save/RNG copies from Bar Dice, Roulette, and
Video Poker did not produce a repeatable native improvement in the identical
3-run/60-frame/24-resolve probe. Bar Dice changed 0.632 -> 0.643 ms p95,
Roulette 1.452 -> 1.441 ms, and Video Poker 1.060 -> 1.051 ms. The experiment
was reverted rather than retained on code appearance alone.

The pinned Web-native build was initially blocked because Windows PowerShell
promoted normal Emscripten stderr diagnostics to terminating errors. The build
helpers now judge native commands by exit code while keeping stdout isolated
for exact pinned-version parsing. A locked Web `template_release` build and the
fresh export above passed after this repair.

### Continuation validation

- final deterministic replay passed twice across 3 seeds and 216 checkpoints;
  both runs produced combined hash `1357449945`
- fresh Coin Pusher parity passed across two native and two Web runs with exact
  payload SHA-256
  `f3ab1247c8d11bb7ca0348cce258e7e101fb771b653f1389ac985daef2325e15`
- allocation contract, seven-root allocation call audit, and 31-root Web UI
  deferral contract passed
- focused Roulette, Baccarat, Slot, Bar Dice, Crew Draw Poker, collection-meta,
  and inventory/spatial checks passed during the continuation
- the focused Pull Tabs game suite completed with zero failures; its wrapper is
  red because the mandatory global content precheck reported 84 pre-existing
  scenario-layout/inventory failures and exceeded the unchanged suite-time
  budget, so the wrapper is not reported as a pass

This continuation still does not close `perf06_1`; it improves code that is
shared with the eventual placement candidate and leaves the binding
qualification requirements unchanged.

## Late-run route-scout continuation

A production-sized 589,891-character continuation fixture exposed a visible
pause the first time the player selected an unvisited destination. The
unchanged `40 ms` route-scout limit failed at `498.375 ms` averaged across one
cold selection and three cache hits. Instrumentation showed the cold selection
itself at `1,888.517 ms`; `1,311.815 ms` was spent cold-loading and generating
Blackjack, Roulette, and Video Poker machine state that the route card never
renders.

The retained path now builds only the deterministic scout projection
(`game_ids`, services, lenders, item offers, tier/kind, and travel lock). It
preserves the authoritative RNG sequence for those fields, omits install-only
machine/layout/semantic work, starts from a compact preview snapshot, and uses
the already-validated UI target instead of repeating route discovery.

| Late-run interaction | Before | After | Change |
| --- | ---: | ---: | ---: |
| Selected scout, 4-call average | 498.375 ms | 16.446 ms | -96.7% |
| Selected scout, cold call | 1,888.517 ms | 65.472 ms | -96.5% |
| Selected scout, cached call average | ~0.1 ms | 0.104 ms | unchanged |
| Warm full refresh average | 18.929 ms | 16.487 ms | -12.9% |
| Layered scout parity suite, 9 cases | 592.270 ms | 14.574 ms | -97.5% |

No performance budget changed. The new projection parity probe compared all
15 environment archetypes and all authored scenario overlays: 73 exact
full-generation/scout projections passed. Deterministic replay passed twice
across 3 seeds and 212 checkpoints with combined hash `76501950`. The
extreme-state probe passed, and the full native performance probe completed 65
observations with all game surfaces and resolve paths covered. Its launcher was
also corrected to judge non-fatal Godot stderr diagnostics by process exit code,
matching the native build wrappers.

This remains reduced, non-binding pre-placement evidence. It does not close
the existing Web/low-end red rows or replace the accepted placement candidate,
quiescence, witness, and full-sample requirements.

## Immediate New Run continuation

The desktop startup contract exposed a separate player-visible pause after an
immediate New Run click. The menu itself was already interactive in `86 ms`,
but the click synchronously finished the run shell while its background loader
was still processing optional overlay and game scripts. The measured baseline
was `4,088 ms` to enter the first playable room.

Native resource requests are now queued in run-build order so first-room
scripts cannot sit behind optional inventory, journal, map, or meta overlays.
Coin Pusher remains prewarmed for a later encounter, but its large script is
queued last while the player is still on the menu and is no longer a required
run-shell build stage. Two empty staging frames that existed only for that
eager load were removed.

| Desktop startup interaction | Before | After | Change |
| --- | ---: | ---: | ---: |
| Menu interactive | 86 ms | 86 ms | unchanged |
| Immediate New Run | 4,088 ms | 3,886 ms | -4.9% |
| Immediate Continue | 366 ms | 364 ms | effectively unchanged |

An initially faster experiment requested Coin Pusher only after the first room
became playable and reached `3,580 ms`, but it was rejected: the full matrix
then observed a Blackjack idle draw p95 of `8.25 ms` against the unchanged
`5.00 ms` limit while background compilation competed with live play. The
retained menu-tail ordering removed that contention. The focused 47-observation
matrix then measured Blackjack at `3.922 ms` p95, and the final full native
matrix passed all 65 observations across 8 seeds. Native Coin Pusher input-trace
parity also passed on the `native_v3` backend.

No performance budget, simulation rule, RNG sequence, visual behavior, or
native/Web gameplay path changed. Web retains its single-threaded staged loader;
the request-order optimization is native-only because Web has no background
resource worker.

## Per-game and Slot continuation - 2026-09-17

This reduced, non-binding continuation profiled the production Slot foreground
autoplay boundary first, then rechecked every game resolver and renderer. No
published budget, simulation/economy rule, RNG sequence, liveness floor, or
visual contract changed.

The Slot trace found that Pinball simulation and rendering were already below
their locked limits. The avoidable cost was in the shared sealed-action host:
the synchronous autoplay path validated the same copy-on-write ledger twice,
the accepted isolated Slot table was recursively copied after ownership had
already transferred, and the game-action entry point performed a live cached
replay lookup even though its prepared handoff already contained the exact
validated candidate, ledger, and delivery. The resolver still validates that
prepared trio before mutation. Standalone replay claims still execute the full
live-ledger lookup, and deterministic proposal double-execution remains intact.

| Slot foreground autoplay | Before | After | Change |
| --- | ---: | ---: | ---: |
| Whole action average | 35.606 ms | 27.840 ms | -21.8% |
| Preparation average | 7.971 ms | 4.615 ms | -42.1% |
| Resolution average | 27.619 ms | 23.210 ms | -16.0% |
| Next-frame average | 9.734 ms | 8.998 ms | -7.6% |

The first ledger-validation removal alone moved preparation from 7.971 ms to
4.634 ms. Ownership transfer then moved the whole action from 30.925 ms to
30.641 ms. Skipping the redundant live replay lookup only for the synchronous
prepared handoff moved it from 30.641 ms to 27.840 ms. All comparisons used the
same 16-action foreground probe and unchanged limits.

The complete native matrix passed 42 observations. Practice fixtures covered
all 11 renderers/surfaces and all 10 resolver paths. Direct resolve p95 values
were Blackjack 3.027 ms, Slot 3.026 ms, Scratch Tickets 2.979 ms, Crew Draw
Poker 2.229 ms, Roulette 1.468 ms, Craps 1.269 ms, Video Poker 1.094 ms,
Baccarat 1.058 ms, Pull Tabs 0.765 ms, and Bar Dice 0.621 ms. The largest idle
draw p95 was Roulette at 3.787 ms; Slot was 2.075 ms. Every value remained
inside its unchanged published budget.

The reduced live interaction probe also improved the prior comparable rows:
Slot autoplay 6.06 -> 5.56 ms p95, active Slot 8.25 -> 6.67 ms, Blackjack
active 16.67 -> 6.84 ms, and Pinball feature 82.22 -> 71.94 ms. Pinball's
production canvas draw p95 was 5.33 ms and its dedicated simulation probe
averaged 54.87 microseconds per tick, so the remaining feature-session long
frames are transition/driver timing rather than a Slot simulation or renderer
hotspot. No speculative gameplay rewrite was retained.

Validation passed:

- Slot autoplay cadence and all generated Slot environment-entry variants;
- Slot runtime/storage scaling at 1, 3, 6, and 12 cabinets;
- 60,000 spins across all six Pinball/Buffalo format combinations, with every
  locked RTP, hit, near-miss, and feature-frequency band green;
- deterministic replay twice across 3 seeds and 214 checkpoints with matching
  combined hash `3217654750`;
- a 12-seed general stuck-state sweep covering 48 Slot scenarios and nine
  cross-game wait-state families.

The stuck-state probe was updated to recognize Pinball's shipped immediate
zero-work settlement as well as the generic delayed watchdog path. The desktop
telemetry wrapper was also corrected to retain non-fatal Godot stderr shutdown
diagnostics while judging the run by its native exit code; the identical rerun
then wrote its report successfully. The Web native-solver builder now applies
the same exit-code rule while loading Emscripten's environment, preventing its
normal stderr setup notice from aborting a successful locked build.

The fresh Chrome CPU4 probe completed from a clean source tree and preserved
the existing Web diagnosis. It remained red for the same four Corner Store
timing-schema diagnostics, Slot autoplay at 121.270 ms against 100 ms, and
Baccarat active at 150 ms against 120 ms. The preceding comparable run measured
124.093 ms and 149.230 ms respectively, and also failed Slot idle at 50 ms;
the current run measured Slot idle below budget. Slot active improved from
61.28 ms to 55.36 ms p95, autoplay draw from 41.47 ms to 25.24 ms, and Pinball
feature draw from 30.68 ms to 29.02 ms. These reduced samples show no new Web
regression, but they do not turn the known low-end rows green or close the
binding performance program.

### Shared turn-boundary follow-up

The next Slot trace separated game work from the shared environment boundary.
Two costs were independent of Slot rules: Crew play authorization serialized
the complete current environment twice even when passed the authoritative
dictionary itself, and TownState rebuilt every condition-rumor payload for
every map node on every action. Crew authorization now takes an identity fast
path while retaining value comparison for detached equivalent inputs.

TownState now fingerprints the complete condition-rumor inputs: eligible
weather and happenings, sorted target nodes, Cass's departed-traveler windows,
and Silas's current itinerary segment. An unchanged fingerprint retains the
existing payloads and only advances their registration action. Any source,
window, itinerary segment, or target-node change still performs the original
full rebuild. Freshly constructed internal rumor payloads also transfer
ownership into TownNetwork instead of being recursively copied a second time;
the public registration boundary remains defensive.

| Slot foreground autoplay | Prior checkpoint | After | Change |
| --- | ---: | ---: | ---: |
| Whole action average | 27.840 ms | 26.407 ms | -5.1% |
| Resolution average | 23.210 ms | 21.725 ms | -6.4% |
| Next-frame average | 8.998 ms | 7.741 ms | -14.0% |

The focused TownState foundation contract passed with zero failures.
Deterministic replay passed twice across 3 seeds and 204 checkpoints with the
same combined hash `2558357174`. The warm 46-observation all-games performance
matrix then passed every unchanged budget. Direct resolve p95 was Blackjack
3.182 ms, Slot 3.009 ms, Scratch Tickets 3.009 ms, Crew Draw Poker 2.014 ms,
Roulette 1.461 ms, Craps 1.241 ms, Baccarat 1.119 ms, Video Poker 1.031 ms,
Pull Tabs 0.781 ms, and Bar Dice 0.610 ms. A preceding cold/import-contended
sample put Blackjack idle draw at 5.62 ms against 5.00 ms; the immediate warm
rerun passed the complete matrix, so no budget or runtime behavior was changed
to accommodate that isolated sample.

The fresh Chrome CPU4 export for source commit `00bbbc32` retained the existing
Web diagnosis rather than closing it. Slot autoplay measured 132.568 ms p95
against 100 ms, Baccarat active measured 143.527 ms against 120 ms, and Slot
idle measured 50.000 ms against 45 ms; the same four Corner Store timing-schema
diagnostics also remained. Slot autoplay's production draw p95 was 32.950 ms
and its environment-runtime p95 was only 1.380 ms, confirming that the shared
Town refresh is no longer the dominant exported-frame cost. This reduced
sample is noisier than the preceding 121.270 ms autoplay run, so the remaining
work stays open and no limit was changed.

### Slot live-render and shared overdraw follow-up

The Slot renderer previously called its complete visual-audit manifest builder
inside every live draw. That public manifest intentionally includes diagnostic
reel arrays, Pinball geometry, Buffalo counters, nudge facts, and layout fields,
but the painter consumes only motion, reveal, result-strip, Buffalo-board, and
celebration values. Live drawing now builds that narrow projection directly;
the complete `render_signature()` contract and all visual QA consumers remain
unchanged.

| Pinball feature draw, 240 frames | Before | After | Change |
| --- | ---: | ---: | ---: |
| EM bumper drop average | 0.886 ms | 0.707 ms | -20.2% |
| Lane multiball average | 0.967 ms | 0.773 ms | -20.1% |
| Video feature average | 1.072 ms | 0.840 ms | -21.6% |

Every row retained the same maximum draw, label, and hit-target counts. The
production desktop trace also reduced Slot active draw p95 from 3.834 to 3.689
ms and autoplay draw p95 from 3.066 to 2.986 ms in the paired pre-overdraw run;
idle average remained effectively flat at 3.046 versus 3.022 ms.

Slot, Video Poker, and the full-board table renderers now declare the opaque
background they already paint. This prevents GameSurfaceCanvas from drawing a
hidden striped backdrop first. Paired production telemetry removed 70 render
primitives from stable Slot and Video Poker frames and typically 56 from the
table games; state-dependent paired rows removed 52 to 132. Native CPU timing
was noise-bound, so this is recorded as a strict render-resource reduction, not
as a claimed CPU speedup. No renderer draw order or visible primitive changed.

Validation passed the complete Slot cabinet visual QA, both Slot foundation
contracts, ordinary and Buffalo autoplay cadence, project architecture/content
validation, and deterministic replay twice across 3 seeds and 204 checkpoints
with matching combined hash `1211704896`. The locked native matrix passed all
65 observations across all 11 game surfaces and all 10 direct resolver paths
without changing a budget. Direct resolve p95 was Blackjack 3.288 ms, Slot
2.988 ms, Scratch Tickets 3.167 ms, Crew Draw Poker 2.018 ms, Roulette 1.435
ms, Craps 1.276 ms, Baccarat 1.113 ms, Video Poker 1.046 ms, Pull Tabs 0.793
ms, and Bar Dice 0.630 ms.

The exact Chrome CPU4 export for source commit `737e0037` preserved the same
known red rows and introduced no new failures. Slot autoplay whole-frame p95
improved from 132.568 to 123.547 ms (-6.8%) and its production draw p95
improved from 32.950 to 24.655 ms (-25.2%). Baccarat active moved from 143.527
to 141.200 ms. Slot idle was noisier in the short sample, moving from 50.000 to
59.288 ms whole-frame p95 and from 28.970 to 39.660 ms draw p95. The remaining
Web failures are therefore still Slot autoplay against 100 ms, Baccarat active
against 120 ms, Slot idle against 45 ms, and the same four Corner Store timing-
schema diagnostics. No performance threshold was changed. The full result is
recorded at `.tmp/perf_continue_20260917/web_l02_cpu4_after_slot_render.json`.

### Shared surface-audio and readability follow-up

The next play trace found frame-local presentation allocation shared by Slot
and the animated table games. `GameSurfaceCanvas` deep-copied the complete
surface-audio contract every process frame, rebuilt a diagnostic redraw-demand
dictionary for boolean scheduler checks, and repeatedly looked up each audio
animation channel while calculating elapsed, active, and identity values.
Slot audio additionally shallow-copied the complete surface snapshot just to
attach transient timing, then rebuilt the same cabinet profile, normalized cue
list, and reel-stop list during every active spin.

All of those values are now borrowed from the immutable presentation snapshot.
Transient timing travels beside the Slot state, the current cabinet audio
profile is cached by its complete five-field identity, and already-normalized
cue/stop arrays take a read-only fast path. Animation timing reads each channel
once while preserving missing-channel, reduced-motion, pause-clock, and finite-
duration behavior. The normal scheduler now queries its boolean directly; the
dictionary form remains available for diagnostics.

The canvas also stopped calculating and retaining text readability rectangles
when the distortion overlay is not visible. Distorted play still records the
same maximum 16 regions and uses the same shader projection; ordinary play had
no consumer for those temporary rectangles.

| Repeated native hot path | Before | After | Change |
| --- | ---: | ---: | ---: |
| Surface audio specification | 4.335 us | 0.567 us | -86.9% |
| Three-channel audio timing | 22.521 us | 12.887 us | -42.8% |
| Continuous-redraw predicate | 6.231 us | 3.773 us | -39.4% |
| Slot cabinet audio profile | 5.969 us | 2.501 us | -58.1% |
| Slot normalized cue list | 4.110 us | 2.114 us | -48.6% |
| Slot normalized reel stops | 1.998 us | 1.444 us | -27.7% |
| Forty inactive-overlay text registrations | 108.449 us | 46.011 us | -57.6% |

The paired production desktop trace improved Slot active whole-frame p95 from
8.522 to 7.031 ms, Slot autoplay from 8.333 to 7.407 ms, and Baccarat active
from 16.219 to 14.797 ms. Slot autoplay draw average/p95 moved from
2.993/3.108 to 2.818/2.892 ms. These are short trace comparisons; unrelated
rows moved in both directions, so acceptance remained the repeated locked
matrix rather than a favorable isolated sample.

That unchanged-budget matrix passed 61 observations across all 11 game
surfaces and all 10 direct resolver paths. Direct resolve p95 was Pull Tabs
0.805 ms, Scratch Tickets 2.986 ms, Slot 3.030 ms, Bar Dice 0.638 ms, Craps
1.297 ms, Blackjack 3.176 ms, Baccarat 1.155 ms, Roulette 1.492 ms, Crew Draw
Poker 2.163 ms, and Video Poker 1.062 ms. The surface-audio audit passed all 13
profiles and 83 delivery streams; the Slot surface suite, ordinary/Buffalo
autoplay cadence, all six cabinet visual-QA cases, project validation, the
focused hot-path state-integrity contract, and deterministic replay across 3
seeds and 204 checkpoints with hash `1211704896` also passed.

The exact fresh Chrome CPU4 export for source commit `fab14372` retained the
same seven known findings and added no failure class. Slot idle whole-frame p95
improved from 59.288 to 50.000 ms and draw p95 from 39.660 to 32.365 ms. Slot
autoplay draw average/p95 improved from 20.817/24.655 to 19.984/22.685 ms,
while whole-frame p95 was effectively flat at 123.547 versus 122.753 ms. Slot
active draw average/p95 also improved from 21.170/25.855 to 20.795/25.690 ms.
Blackjack active draw p95 improved from 45.455 to 33.075 ms; Baccarat idle draw
p95 improved from 21.665 to 17.830 ms. Baccarat active remained noisy and red,
with whole-frame p95 moving from 141.200 to 149.605 ms and its sparse 17-sample
draw p95 moving from 28.285 to 48.030 ms. Roulette and Video Poker remained
within their existing whole-frame budgets.

The remaining Web failures are Slot autoplay against 100 ms, Baccarat active
against 120 ms, Slot idle against 45 ms, and the same four Corner Store timing-
schema diagnostics. No threshold changed. The result is recorded at
`.tmp/perf_continue_20260917/web_l02_cpu4_after_surface_audio_hotpaths.json`.

### Slot realtime redraw-scheduler follow-up

Slot's 16 ms presentation refresh advanced only read-only clock and feature
projection state, but every patch also requested a complete cabinet redraw.
That bypassed the canvas scheduler: the constrained-Web idle scenario declared
1 fps and scheduled two redraws, yet the patch path forced 51 draws in the same
two-second window. Ordinary Slot patches and steady-state Pinball patches now
defer redraw ownership to the existing scheduler. Active reel/feature channels
retain their 60 fps cadence; the structural first Pinball takeover still draws
immediately and atomically.

| Fresh Chrome CPU4 scenario | Before (`fab14372`) | After (`1d1d2f2c`) | Result |
| --- | ---: | ---: | --- |
| Slot idle whole-frame p95 | 50.000 ms | 20.000 ms | now passes 45 ms |
| Slot idle full draws / scheduled draws | 51 / 2 | 2 / 2 | redundant draws removed |
| Slot active whole-frame p95 | 46.664 ms | 54.385 ms | passes 110 ms |
| Slot active full draws / scheduled draws | 61 / 23 | 22 / 20 | patch redraws removed |
| Slot autoplay whole-frame p95 | 122.753 ms | 21.165 ms | now passes 100 ms |
| Slot autoplay full draws | 65 | 2 | pre-spin toggle no longer repaints every patch |

The focused foreground-autoplay probe remained noise-bound: action average
moved from 28.928 to 29.851 ms and next-frame p95 from 9.349 to 9.796 ms. It
still advanced every spin exactly once, handed every unique animation to the
canvas, used only incremental snapshot refreshes, and retained at most two
sealed responses. Ordinary and Buffalo cadence, the complete Slot surface
suite, all six cabinet visual-QA cases, and native idle liveness passed.

The exact Web run removed both Slot failures without adding a failure class.
Baccarat active remains red at 139.468 ms against 120 ms, and the same four
Corner Store timing-schema diagnostics remain. A trial narrow-candidate
Baccarat authority path reduced native deal time from 214.166 to 123.826 ms,
but failed the required table-result/turn publication contract and was removed
in full; none of that unsafe experiment is retained. No budget changed. The
accepted Web result is
`.tmp/perf_continue_20260917/web_l02_cpu4_after_slot_scheduler.json`.

The unchanged-budget native matrix passed 61 observations across all 11 game
surfaces and all 10 direct resolver paths. Direct resolve p95 was Pull Tabs
0.887 ms, Scratch Tickets 3.105 ms, Slot 3.077 ms, Bar Dice 0.655 ms, Craps
1.324 ms, Blackjack 3.231 ms, Baccarat 1.089 ms, Roulette 1.671 ms, Crew Draw
Poker 2.053 ms, and Video Poker 1.040 ms. Project validation passed, and two
deterministic runs matched across 3 seeds and 204 checkpoints with combined
hash `1211704896`.

### Baccarat sealed-transaction follow-up

The remaining Baccarat hitch was outside the card resolver. Foundation's
legacy sealed path serialized a complete run, parsed it back into a temporary
RunState twice for deterministic replay, serialized both outputs, and restored
the accepted snapshot again. The game now implements the host's trusted full-
candidate seam. Both proposal executions still begin from independently
isolated complete transaction candidates and retain the full proposal snapshot,
fingerprint, replay, receipt, detached environment-turn, and publication
checks. This deliberately does not use Slot's lightweight candidate: an
earlier trial of that path reduced work but failed to publish the Baccarat
table result and was removed.

The accepted first proposal now consumes the already detached host transaction
candidate directly. Its independent replay clone is created before the first
mutation, so the second execution still proves the same full deterministic
output without a third deep copy of the Baccarat table.

| Production Baccarat deal | Before | Trusted full candidate | Final | Final change |
| --- | ---: | ---: | ---: | ---: |
| Native sealed resolve | 211.722 ms | 133.836 ms | 127.046 ms | -40.0% |
| Chrome CPU4 sealed resolve | 1074.140 ms | 600.075 ms | 590.550 ms | -45.0% |
| Chrome CPU4 active draw p95 | 25.915 ms | 22.260 ms | 23.035 ms | -11.1% |
| Chrome CPU4 active whole-frame p95 | 139.468 ms | 139.185 ms | 141.318 ms | noise-bound, still over 120 ms |

Every production trace advanced the environment from turn 0 to 1, appended the
story result, entered the dealing phase, and started one Baccarat deal
animation. The dedicated Roulette/Baccarat depth contract also passed exact
money conservation, shoe ownership, committed receipt replay, hostile/stale
delivery rejection, and pending retry/cancel behavior. The targeted Baccarat
game check itself reported zero failures; its shared full-content prelude still
reported unrelated randomized scenario-layout findings.

The exact cold Chrome export was built from commit `c3c59649`, with no page,
request, or response failures. Slot idle, active, and autoplay remained within
their unchanged budgets. Baccarat's action time and draw cost improved, but its
sparse 21-frame p95 remains red, as did the established four Corner Store
timing-schema diagnostics. One unrelated Blackjack-idle sample measured 27.372
ms against 25 ms after passing in the preceding exact export, so it remains a
variance finding rather than a threshold or behavior change. No budget was
changed.

Deterministic replay passed twice across 3 seeds and 204 checkpoints with the
unchanged combined hash `1211704896`. Three 61-observation native matrices kept
all direct resolve paths inside their locked budgets. The first two had isolated
idle-draw outliers at the 5 ms boundary: Craps 5.04 ms in the first, then Craps
5.07 ms and Baccarat 5.21 ms in the second; the corresponding prior accepted
measurements were 1.09 ms and 1.65 ms. Both red reports remain retained rather
than hidden or accommodated by changing a budget. The final uncontended repeat
passed all 61 observations. Its direct resolve p95 values were Pull Tabs 0.755
ms, Scratch Tickets 2.983 ms, Slot 3.141 ms, Bar Dice 0.623 ms, Craps 1.319 ms,
Blackjack 3.376 ms, Baccarat 1.062 ms, Roulette 1.449 ms, Crew Poker 1.977 ms,
and Video Poker 1.045 ms.

### Baccarat compact authority-evidence follow-up

A temporary native stage trace attributed 50.963 of 59.016 ms (86.4%) of the
post-copy host transaction to dual proposal replay and whole-run fingerprinting.
Baccarat now supplies the same compact-evidence seam already proven by Slot,
while retaining its full detached transaction candidate and independently cloned
full replay candidate. The evidence binds account/RNG checkpoints, the complete
Baccarat table and room context, wager UI, challenges, inventory, heat, alcohol,
staffing, and pit-boss state. Replay history and unrelated game tables remain
covered by their own host ledger/context contracts and are no longer recursively
serialized into both proposals.

| Production Baccarat deal | Before (`c3c59649`) | Compact evidence (`74ad74fc`) | Change |
| --- | ---: | ---: | ---: |
| Native sealed resolve | 127.046 ms | 111.086 ms | -12.6% |
| Chrome CPU4 sealed resolve | 590.550 ms | 539.690 ms | -8.6% |
| Chrome CPU4 active whole-frame p95 | 141.318 ms | 146.125 ms | noise-bound, still over 120 ms |

The exact cold Web export was built from `74ad74fc` with no page, request, or
response failures. It retained the observed committed result, turn advance,
dealing phase, and animation. Its remaining failures were the established four
Corner Store timing-schema diagnostics plus Baccarat active frame p95; Blackjack
idle passed in this repeat. Unrelated draw samples moved in both directions,
including a large Slot-active regression despite no Slot code change, so draw
variance is not claimed as an effect of this transaction-only optimization. No
budget changed.

Architecture validation and the direct Roulette/Baccarat depth contract passed.
The 400-hand Baccarat audit reported zero rule/accounting failures and ten
successful authoritative host commits. Two independent determinism processes
matched across 3 seeds and 222 checkpoints with combined hash `548969563`. The
focused Foundation Baccarat game check passed with zero failures in 279 ms; its
shared content prelude still emitted the same 84 unrelated randomized layout
failures, so the aggregate wrapper remained red rather than being reported as a
clean suite pass.

The first unchanged-budget 61-observation native matrix retained one unrelated
red sample: Craps idle draw p95 was 5.11 ms against 5.00 ms. The report remains
retained. The uncontended repeat passed all 61 observations, with Baccarat idle
draw p95 1.785 ms and direct resolver p95 values of Pull Tabs 0.769 ms, Scratch
Tickets 3.006 ms, Slot 3.144 ms, Bar Dice 0.653 ms, Craps 1.237 ms, Blackjack
3.106 ms, Baccarat 1.139 ms, Roulette 1.481 ms, Crew Poker 2.085 ms, and Video
Poker 1.192 ms.

### Baccarat structural replay follow-up

The compact-evidence trace still spent 6.783 ms cloning the independent replay
candidate and 7.762/7.890 ms producing each proposal; Baccarat card resolution
itself was only 0.382/0.423 ms. Of each proposal, roughly 5.5 ms was canonical
output serialization. The accepted proposal must retain that digest for its
receipt, but serializing the replay's identical payload a second time added no
authority after the host had already executed both isolated candidates.

Baccarat now opts into exact structural replay matching. The host still runs
two independently isolated full candidates and compares their input identity,
success state, result, run snapshot, RNG snapshot, and complete compact authority
evidence recursively. Only the accepted proposal is hashed for the receipt. A
focused contract proves that an independently owned exact replay is accepted
and a one-card result change is rejected.

| Production Baccarat deal | Compact evidence (`74ad74fc`) | Structural replay (`29f4b9a3`) | Incremental change |
| --- | ---: | ---: | ---: |
| Native sealed resolve | 111.086 ms | 100.903 ms | -9.2% |
| Chrome CPU4 sealed resolve | 539.690 ms | 488.490 ms | -9.5% |
| Chrome CPU4 active whole-frame p95 | 146.125 ms | 141.963 ms | still over 120 ms |

Relative to the preceding full-candidate checkpoint, native resolve is down
20.6% from 127.046 ms and Chrome CPU4 resolve is down 17.3% from 590.550 ms.
The 400-hand audit again reported zero failures; its ten authoritative host
commits improved from 41.614 to 37.124 ms average. Architecture validation, the
Roulette/Baccarat depth contract, explicit replay-tamper rejection, and two
independent determinism runs passed (3 seeds, 204 checkpoints, combined hash
`2413346138`). The fresh exact Web export from `29f4b9a3` had no page, request,
or response errors and preserved Baccarat result/turn/dealing/animation liveness.
Its failures remained the four established Corner Store timing-schema checks
and Baccarat active frame p95. No budget changed.

### Slot structural replay follow-up

The active Pinball feature remained the largest repeatable native gameplay
hitch. A temporary per-action trace showed that its sealed action resolver was
serializing the second deterministic proposal even after both independently
isolated candidates had produced exact matching result, RNG, and compact Slot
authority graphs. Slot now uses the same fail-closed structural replay matcher
proven by Baccarat. The accepted proposal still owns the canonical receipt
digest; any changed replay field still rejects the transaction.

| Paired native Pinball trace | Before | After (`15e08a80`) | Change |
| --- | ---: | ---: | ---: |
| Sealed action outer average (43 inputs) | 105.583 ms | 89.284 ms | -15.4% |
| Sealed module average (43 inputs) | 60.267 ms | 47.370 ms | -21.4% |
| Feature-session whole-frame p95 | 69.750 ms | 58.313 ms | -16.4% |

With all timing hooks removed, the production native matrix confirmed the same
direction: Pinball whole-frame p95 improved from 65.410 to 56.147 ms (-14.2%),
average frame time from 15.826 to 15.337 ms, and the largest snapshot/automation
spike from 190.988 to 162.740 ms (-14.8%). All 43 attempted Pinball inputs still
completed, the feature remained live, and draw p95 was effectively unchanged
(5.725 versus 5.753 ms).

The exact fresh Chrome CPU4 export from `15e08a80` retained all 43 inputs with
no page, request, or response errors. Against the preceding exact Web reference,
Pinball p50 improved from 19.993 to 17.540 ms, average frame time from 40.818 to
39.877 ms, and draw p95 from 38.785 to 32.740 ms. Its sparse whole-frame p95 was
noise-bound at 137.385 versus 138.713 ms and remained below the unchanged 180 ms
budget. This run retained the four Corner Store timing-schema failures and the
existing Baccarat active failure; Slot autoplay also produced a transient
122.908 ms sample after passing at 51.542 ms in the prior exact export. No budget
changed.

The complete Slot surface suite passed, including deterministic Pinball physics,
realtime lifecycle, multiball, item effects, bonus recovery, autoplay, RNG, and
economy checks. The machine-authority contract and architecture validation also
passed. Two independent determinism processes matched across 3 seeds and 210
checkpoints with combined hash `3446654568`.

### Sealed-ledger validation follow-up

Pinball's remaining input spikes grew with the two retained replay responses.
The manual surface path was validating that complete ledger, storing the exact
copy-on-write value synchronously, then validating the unchanged value once or
twice more before issuing the delivery. It now follows the already-proven Slot
autoplay rule: validate hostile persisted content once at the external boundary,
then carry that exact host-owned value through synchronous staging and issue.

The cache validator also hashed each hostile response once for the cache entry
and again for its embedded receipt. It now passes the first verified digest into
the receipt's remaining closed-shape, identity, binding, and fingerprint checks.
No hash or tamper check was removed; the same complete response is serialized
once instead of twice.

| Native Pinball production evidence | Before | After (`cf524b17`) | Change |
| --- | ---: | ---: | ---: |
| Whole-frame p95, two-run average | 63.193 ms | 58.512 ms | -7.4% |
| Whole-frame average, two-run average | 16.090 ms | 15.608 ms | -3.0% |
| Feature-session duration, two-run average | 9,025.5 ms | 7,917.5 ms | -12.3% |
| Cache validation average (183 calls) | 4.207 ms | 2.099 ms | -50.1% |
| Cache validation p95 (183 calls) | 18.796 ms | 9.704 ms | -48.4% |
| Cache validation total (183 calls) | 769.821 ms | 384.093 ms | -50.1% |

The paired whole-frame runs retained their individual samples rather than hiding
variance: control p95 values were 56.147/70.238 ms and candidate values were
65.060/51.963 ms. The scoped validator trace used the same 183 successful calls
on both sides and timed only validation work; all temporary timing hooks were
removed afterward.

The matching 60/90-frame Chrome CPU4 run used the exact fresh Web export from
`cf524b17`. Pinball p95 was effectively unchanged at 138.588 versus 138.713 ms
and stayed below the unchanged 180 ms budget. Its p50/average moved from
17.540/39.877 to 20.880/46.538 ms while the direct native validation trace showed
the intended stage reduction, so no broader Web-frame improvement is claimed.
All scenarios completed with no page, request, or response errors. This cold run
retained the four Corner Store timing-schema findings and red samples for ready
time, Slot autoplay, Pull Tabs idle, Baccarat active, Blackjack idle, and Bar
Dice idle. No budget changed.

The complete Slot surface suite, machine-authority contract, shared action-
authority depth contract, and architecture validation passed. Two independent
determinism processes matched across 3 seeds and 214 checkpoints with combined
hash `3952418742`.
