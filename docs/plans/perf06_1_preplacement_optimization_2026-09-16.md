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
