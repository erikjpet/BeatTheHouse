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
