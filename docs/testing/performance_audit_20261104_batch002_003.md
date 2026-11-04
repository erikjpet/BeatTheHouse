# Performance audit batch: BTH-PERF-20261104-002 and -003

The [whole-game parent](../plans/performance_audit_2026-11-04.md) remains OPEN.
These are separate findings, with isolated before/after evidence. No user save,
browser profile, save schema, odds, money, RNG, placements, aspect ratio,
touch/focus handling or autonomous animation was changed.

## 002: reduce cold Video Poker hint work

An ordinary generated Deal with Fred's hat makes the cold advice path evaluate
32 hold masks synchronously. The original loop repeatedly copies owned sampling
arrays, rebuilds payout context and allocates scoring highlights that advice
never displays. Cache hits are fast; each new hand normally misses the cache.

The scoped change reuses owned completion/pool scratch, computes payout context
once per mask, and omits only advice's scoring-index array. It reuses the
existing natural/wild classifiers. Mask order, RNG calls, deck-removal order,
floating-point addition order, payout lookup priority, progressive/sequential
royals and cache-copy isolation are retained. Normal evaluator calls retain
their full default descriptors and scoring indices.

Three identical generated hands were measured before/after, using the same
probe source bytes and5% aggregate CPU diagnostic profile:

| Platform / hand | Cold before | Cold after | Reduction |
| --- | ---: | ---: | ---: |
| Native0 |1168.254ms|762.421ms|34.7%|
| Native1 |1330.403ms|674.044ms|49.3%|
| Native2 |1228.335ms|755.824ms|38.5%|
| Web0 |2337.075ms|1361.545ms|41.7%|
| Web1 |1843.645ms|1187.870ms|35.6%|
| Web2 |2044.280ms|1002.765ms|50.9%|

The same holds are recommended in all before/after pairs. The independent
frozen baseline oracle passes1083 payout cases and all32 mask expected values
for each of three generated cabinets, including Deuces Wild:96 exact mask
comparisons. It covers authored variants/tiers, bet/coin levels, special royal
bonuses, missing/duplicate payout rows, default descriptors, immutable input
hands and cache-return isolation. Web/native generated-hand functional checks
also pass, with no browser errors.

This is a substantial measured work reduction, **not closure of the latency
finding**. Cold advice remains synchronous and takes roughly0.67–1.36seconds
in these capped samples. Normal rendered Deal responsiveness, constrained and
normal host baselines, and a bounded/deferred approach to the residual hitch
remain to investigate. Diagnostic timings are not a binding player-hardware
budget or all-hand performance guarantee.

## 003: bound consumed Coin Pusher input history

The live session retained every consumed input dictionary until the cabinet
closed. A valid empty authored cabinet isolates this graph from coin-body
allocation:30000 real queue/advance events over500seconds of synthetic time
retain30000 already-consumed records and about18.9MB of native static-memory
growth. A diagnostic release of that graph frees about18.9MB. This proves
avoidable live-session retention; it is not a claim that exit fails to release
memory or that500seconds of wall-clock gameplay was exercised.

After normal synchronous advancement consumes1024 entries, the fix releases
the consumed prefix in one batch and retains the exact pending suffix/order.
It preserves cumulative input diagnostics in a scalar, including legacy/manual
sessions without that field. Settlement continues to own its existing trace
drain, and compact rejected-DROP rollback leaves pending input and reservations
intact. No per-event front removal or authoritative tick change is introduced.

| After30000 inputs | Before | After |
| --- | ---: | ---: |
| Native retained records |30000|290|
| Native static-memory growth |18866888bytes|about184KB|
| Web retained records |30000|304|
| Web authoritative ticks since warmup |30000|30000|
| Web pending records at final sample |0|0|
| Cumulative diagnostic input count |30000|30000|

Native/Web catch-up batching can reach the threshold on slightly different
ticks. Both keep the consumed history bounded instead of accumulating it for
the whole session. The release Web template reports0 for static-memory
monitoring; **no Web byte-reduction claim is made**. Its retained-record count,
authority timing and functional contracts are actual Web runtime observations.

Focused native and true-Web checks pass for mixed future inputs, conflicting
same-tick control order, exact authored tick, no later replay, legacy counts,
unchanged exit settlement and rejected production DROP rollback. Continuous
nozzle publication/conservation remains passing after the change. Required
no-pointer animation liveness passes on the combined source.

The memory probe's original same-stack cleanup measurement held an incidental
Array temporary. That failed attribution attempt is preserved externally; the
corrected byte-identical before/after probe releases in a helper that returns
before measuring freed memory. Native and Web samples use the same final probe.

## Evidence, runtime coverage and delivery limits

Raw reports, source/probe identities, payout parity, worker commands/limits and
zero-process cleanup receipts are in
[`evidence/performance_audit_20261104`](evidence/performance_audit_20261104).
Every native/browser worker uses disposable state and a finite capped Job.
Each proof distinguishes module/synthetic clocks from actual rendered host
automation. Original developer placements and primary player/profile files
remain untouched.

Actual native OpenGL execution on RTX4070Ti was attempted through the existing
production telemetry driver. The initial300second sweep reached Baccarat;
the240second follow-through reached Roulette ball-settle. Both retained their
partial logs and closed with zero owned processes. Neither produced a final
report or qualifies all native routes from test counts. A shorter existing
rendered foundation probe is recorded separately; unobserved rows stay open.

The first Coin001 fix is on main as
`ea136553ce3f33236aa3ea22d23921e6f957e7a2`. Existing NEXT cold-import
qualification consumed the exact247ebe3277ce request and promoted that source
at2026-11-04T00:52:33Z, tree`d6666d67326787155852e0fc51a91c354946e8ff`.
Served redirect,metadata,PCK/native bytes,engine payload sizes and a fresh
isolated menu startup pass; archive SHA256 is
`4973723cb4141541868fd6597a2bd61f2a71abfb78d63eb0627c81930c0ef0e1`.
That descendant contains Coin001 and the Slot Collect fix. This is identity/
startup evidence, not a new Slot gameplay claim. The audit's superseded,
unconsumed de945903 request was hash-checked and archived; the consumed exact
request and the prior good build remain preserved. Later NEXT heads are
reported separately rather than pretending247 remains current forever.

Associated implementation commit for findings002/003: `e6fef69a19cf73b4805fda734724652d76e0e141`.
Exact main integration and NEXT follow-through are recorded separately.
Keep all parent coverage and residual normal-play acceptance open. No stable,
itch or audience publication and no watcher/qualification bypass occurred.
