# Deprecated-code audit continuation 008

`BTH061-AUDIT-COMMAND-CHANGE-DETECTOR-008` removes a measured redundant full-state comparison from successful fresh scenario commands. The original receipt-capacity case falls from 28.3 to 17.1 seconds in the controlled copied-source pair; the canonical module passes in 16.957 seconds. All validation, receipt limits, replay values, rollback ownership and other 113 Runtime method bodies remain unchanged. Paused feature/authoring work is preserved. The whole audit `BTH061-AUDIT-001` and catalog task `BTH061-AUDIT-CONTENT-TIMEOUT-006` stay Open. Base: `069734374cf935ed14130eaa79eea900a34f966c`.

## Cause and exact change

Default `apply_command` normalized the input, then built canonical copies and JSON text of the whole growing state before and after an accepted command merely to compute `changed`. A successful nonreplayed command necessarily appends a new lifetime receipt before that comparison. Validation requires a canonical nonempty String identity; replay exits earlier; handlers, phase entry, outcomes and cleanup preserve the receipt array. Its shallow growth from N to N+1 cannot be hidden by canonicalization. The comparison is therefore always true. The prevalidated path already used literal true.

The fix removes only the unused `state_before` snapshot and sets the final fresh-success result to `changed: true`. The original rollback deep clone remains. Every rejection branch, lifetime/causal/capacity guard, replay cache value, action cost, schema/version, receipt and API signature is retained. Legacy cached `changed=false` continues to replay false. The result-cache insertion occurs after the old comparison; receipt-array growth, not that later insertion, proves equivalence. Current reconstruction callers authenticate the full result, so qualification compares complete returned Variants.

Only `apply_command` changes in the 114 method Runtime; 113 other bodies and all bytes outside the two expressions/comment remain raw-exact, with CRLF preserved. Baseline Runtime SHA256: `ef6ccc15be0c7260cdc23ebc08a6851929501827f1bd66c174a5bb626a153bec`; final candidate: `1f2c55166f411f7b24c3d610f2f111694064c063eed82309a81e21e80626b566`. A focused regression contract checks fresh durable change, caller ownership, legacy false replay, conflicting replay and normalized zero-cost rollback. No obsolete fallback API, active compatibility path or private clone guard was removed.

## Measurements and qualification

| Check | Result and scope |
| --- | --- |
| Original full-flow38step observer | 180 second whole-process cap; 32 steps returned, then delivery-day package was censored. Largest returned step: capacity 28.287332 s. |
| Focused copied-resource telemetry |Case passes 28.665487 s; normalization 13.068846 s and canonical traversal 8.959542 s are inclusive/overlapping. Primitive dedup 0.467551 s and hex 0.863054 s do not justify unrelated fixes. |
| Controlled original/candidate capacity |28.292947 s versus 17.084278 s, both complete original assertions/calls/limits pass, about 39.6% lower case time. |
| Canonical capacity module |Original 29.477874 s; fixed 16.957039 s, zero failures. This removes the copied-resource qualification limit for the capacity case. |
| Complete old/new Variant parity |PASS: 256 accepted commands, 281 complete command-result pairs and 546 complete `var_to_bytes` comparisons, 566 input-ownership checks. Includes exact/conflicting replay, overflow/old replay, synthetic legacy false cache, 14 malformed cases, post-handler normalized rollback, deep payload/output ownership. Four unchanged assertion cases pass on both copied resources: atomic failures, lifecycle commands, handler reducers and receipt reconstruction. |
| New canonical regression contract |PASS, 14 checks. |
| No-input animation liveness |PASS under maintained owned Job; no scheduling/canvas code changed. |
| Fixed original-order full flow |Same 180 second cap; all 38 steps return, then later semantic presentation is censored. Later inventory/arrival, final mutation fingerprints and Scratch remain unreached. Returned does not imply assertions passed. |
| Canonical maintained sequence selector |FAIL on both exact original and candidate: identical ordered 19 assertions. Check timing 73.036 s original/63.633 s candidate, including final library fingerprints. No timeout/parse error, both owned Jobs0. This is nonregression evidence, not a green sequence/suite/full-entry claim. |

The full-flow diagnostic preserves all 942 runner methods, 89 sequence methods, nine maintained sources and 34 required symbols. It retains 83 outer traces and adds 76 around the 38 original calls. Reversing traces/helpers/preload restores both canonical files byte-exact. Copied ScriptResource/nested-fixture identities are diagnostic limits. Timings use paired engine-clock microseconds; absolute engine readings are not wall-cap offsets. All runs keep the original 180 second observation limit, 12% aggregate CPU, 2 GiB memory, suspended assignment, no breakaway and kill-on-close. Existing source validation/process/reserve/time guards are unchanged; the complete guarded maintained entry point was not rerun or claimed passing.

The first parity fixture incorrectly expected rollback to equal raw input. Both original and candidate instead return normalized input by the existing API contract; r1 matched all 545 values but failed that expectation on both sides. R2 preserves the failed receipt and compares the complete rollback against each runtime's independently normalized pre-command bytes, retaining the zero-cost and caller-ownership assertions. R2 passes all 546 comparisons. No product assertion was removed to obtain a pass.

## Open findings and preserved scope

`BTH061-AUDIT-SEQUENCE-BASELINE-008` retains all 19 canonical assertions: lifecycle/transaction and tutorial presentation rollback, recipient node binding/quarantine, and EventModule delivery aftermath/fact/replay checks. The exact original Runtime was temporarily restored for one fresh bounded comparison; its source remained exact throughout, reproduced all 19 in the same order, and the exact tested candidate was restored afterward. Existing Health Inspector follow-up `BTH061-AUDIT-INTERRUPT-BASELINE-004` overlaps one finding and remains preserved. These findings require current-interface diagnosis; no new gameplay-defect or stale-fixture conclusion is invented.

The later semantic-presentation timeout remains in `BTH061-AUDIT-CONTENT-TIMEOUT-006`. No assertion/filter/order/budget change, worker stop or donor-machinery change was used. NEXT donor qualification is assigned separately; no new deployment, Web startup or Web gameplay acceptance is claimed here. The removal child stays Open until its associated commit and required delivery acceptance are recorded.

The generic seen-Dictionary proposal passed 108 cases/16,731 primitive checks but improved the capacity case only 3.17%, within existing variation, so its exact original production bytes were restored. Native hex and Schema pair-copy proposals remain unapplied source hypotheses, not timeout fixes. The original JsonCoerce/Schema and all paused feature work remain unchanged. This batch does not close full-codebase semantic coverage or the five existing phase 004 baseline follow-ups.

## Evidence

[Portable measured receipt](deprecated_code_audit_continuation_008.json) accompanies this report. Private task evidence remains under `evidence/content008-*`, `content-command008-proposal`, `content-command008-review`, `content-command008-diff-proposal`, `content-capacity008-telemetry-root-r1` and the rejected helper proposal directories. Original failures, source copies, fixtures and saves are retained. Both ledger views and the runtime inventory retain the exact task IDs, source status and owned closures; no task is marked Complete without an associated commit and required acceptance.

Associated scoped source commit: `6eba32814477ae7d379d8eb13e7c16ccdf6fa950`. The removal child remains Open for required NEXT delivery; the catalog and inherited 19 assertion triage remain Open. Manual reconciliation before association has zero audit/task9 findings; 54 current and 520 all findings remain outside this scope. All 15 owned 008 Jobs are closed with zero processes.
