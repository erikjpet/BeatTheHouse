# Typed-memo and layout investigation checkpoint

This evidence-only checkpoint publishes no new game code. Published Schema `ec321eb0` is restored locally; all three unaccepted repair prototypes and the unchanged pending `1f24` regression remain preserved. Audit001, ContentTimeout006, MemoTypeSafety014 and PersistenceProjection013 remain Open. The [JSON report](deprecated_code_audit_continuation_016.json) records exact pins and named receipts.

The canonical regression reproduced **41 checks / 11 failures** on the published base. Each repair passed the same **56 checks**, preserving original cold errors and fixing the demonstrated typed warm-cache false acceptances. All repairs remain unaccepted because of measured cost.

| Same 32 actual-hit population | Mean | Disposition |
| --- | ---: | --- |
| Retained original | 0.77794 ms | Comparator |
| First typed repair `2ec80` | 3.54516 ms | Rejected |
| Parallel helper `d66d` | 2.88156 ms | Unaccepted |
| Bounded recursion `998f` | 2.99591 ms | Rejected; no observed benefit |

The parallel and recursive helpers passed the same nine exact node/depth/byte/DAG/cycle/typed-Dictionary controls, 29 checks each. The component probe passed 1,437 checks with 1,188 samples; payload admission is its largest separately measured component. These separate passes cannot be summed or subtracted to manufacture exclusive savings. No cache, skipped subtree, weaker gate or native-hash change was accepted. Frozen recipes and the recursive rejection/inverse are retained under `evidence/memo016-*`.

The maintained memo contract fails the same production uniqueness-authority assertion on both `d66d` and published `ec`. This establishes a baseline failure, without proving the underlying authority hashes/counts equal: the combined assertion emits neither. Candidate acceptance remains open; no expected hash was retuned. The unchanged no-pointer liveness check passed on `d66d`.

The actual canonical layout capture passed **76 report / 78 final checks**, preserving both complete 491,332-byte durable outputs and source custody. Four exact root/layer packets qualify the observed mutable/untyped container domain. The later replay passed **675 report / 677 final checks** across **72 fresh-input calls**, comparing canonical, anonymous-original and anonymous-observer resources in all six role orders. Complete returned values, post-assignment inputs, live flags, old alias content and named reference facts all match. One input retains equal value bytes while replacing layout and manifest references, so value equality cannot authorize identity changes.

The private observer recorded 348 completed spans and 24 branches. Its largest nonoverlapping ensure owners are reconciliation **154.143 ms**, binding **143.530 ms** and persisted authority **87.419 ms** across the selected calls. Within reconciliation, opaque `Manifest.reconcile` plus its original input-copy argument takes **119.694 ms**, physical entries **21.084 ms** and surface lookup **0.607 ms**. Children are contained in their parent and must not be added to it. Logging, shared cache warmth, first-call/order effects and separate Script identity remain; these timings establish neither a speedup nor earlier canonical branch selection. The complete analysis is `evidence/storage016-replay-independent-native-analysis-r1.{json,md}`.

All **15 named native Jobs** finished assigned and guarded at 180 seconds / 12% CPU / 2 GiB with active0: 12 exited0; the expected original regression and both maintained authority-contract checks exited1. Closure is separate from test acceptance. The temporary-source owner restored original RunState/Generator only after verified owned closure. All 1,245 source pins, four support pins and retained known custody files were checked at their explicit epochs; all failed runs and prototypes remain. The root-certificate startup diagnostic and existing unchecked CloseHandle BOOL limitation are retained without claiming certificate/network acceptance or a global process census.

Next work is the typed admission architecture/cost, actual maintained authority workproducts, and opaque Binder/Manifest/authority internals. No production call is confirmed removable. Cleanup stays stopped and all eight paused feature tasks remain unchanged. The original 180-second content guard, Systems300/43.712 comparator, 330 supervisor and four-shard/55-check/all220 planned recipe are unchanged. The prior full Systems300.242 failure and separately assigned NEXT delivery remain Open. No full-stage, malformed-input logger, arbitrary alias, RNG, native9b or deployment acceptance follows from these focused results.

Manual current/all reconciliation reports zero findings in this worker scope, with181 runtime records and the prior166-record prefix preserved. The unchanged outside scope findings remain78 current/544 total, including54 outside runtime errors. No other task/owner was changed to conceal them.
