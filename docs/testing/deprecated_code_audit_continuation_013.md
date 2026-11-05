# Bounded catalog lookup repair and rejected projection experiment

Only candidate B is committed in `3c0fd716946f56cec0350d7ad43164bc29d14c28`: `ScenarioEngine.sequence_definition_for_environment` uses the existing fail-closed selected-overlay API instead of copying the full default catalog snapshot. Engine SHA256 is `d4b8b8d98d44929270770a00a5072af0877c57efc016c3d69203f1c09fdac378`; the new actual-class regression test is `5b20c57e2cd0ccf4bf7be4deab108280843a3fab305daf98d17b9f3e91714d6b`. The other 1,241 original sources are raw-exact. Catalog candidate A and the RunState projection candidate are excluded. The implementation and new focused test are committed; no NEXT result is claimed.

The private paired diagnostic measured 55 warm **unbound-fallback** resolver calls: 8.273362s baseline versus 6.740180s candidate, an 18.53% reduction in paired sums. All 55 candidate pairs were faster across both execution-order groups. This is copied-resource fallback timing, not an overall game, successful room-install or full-stage speedup. Component timings belong to separate executions and must not be subtracted from or added to the paired run.

| Actual/focused qualification | Baseline | B candidate |
| --- | --- | --- |
| R3 actual Engine/Catalog regression |662 checks, 0 failures|662 checks, 0 failures|
| Layer situation |14 checks pass|14 checks pass|
| Inactive storage/encoding |39 checks pass, exact JSON bytes|39 checks pass, exact JSON bytes|
| No-input animation liveness |Not newly repeated here|PASS|
| Selected `scenario_sequence_contract` |65.943s group /100.351s process|64.704s group /98.310s process|
| Full Systems four-shard/55-ID recipe |FAILED 300.234s; 300s harness limit and 43.712s comparator exceeded|FAILED 300.255s; same 300s harness limit and 43.712s comparator exceeded|

R3 check values and all fields except elapsed time match exactly. Coverage includes 55 authored definitions that must fail closed without bound physical authority, 10 cache fixtures, detached fallback ownership and an existing proof-backed positive alias. Healthy catalog admission is not physical authority. Historical terminal compatibility is unchanged but not exercised by this focused test; package/schema/extension rejection causes overlap; the existing schema memo is not claimed to be restored. The sequence runs execute one selected registered check with all 38 ordered steps; the other 57 registered checks were skipped, so this is not full-contract or Systems acceptance. The sequence candidate completed successfully before the implementation commit.

Earlier test failures remain retained: R1 stopped on a native-class name collision (`Engine`) before acceptance; R2 ran 618 checks with 168 failures because its oracle wrongly expected authored/unbound definitions to be admitted. R3 corrects that negative authority boundary and separately proves the existing positive receipt/alias path. These failures are not rewritten as production regressions or passes.

The projection experiment remains **rejected and unapplied**. Its corrected r2 oracle passed 713 checks across 100 pairs (96 raw Variant-byte pairs and 4 explicit opaque identity-view pairs), including 16 encoded-save pairs. R1's 160 recursive-equality errors remain preserved and invalidate its full shape acceptance. The default two-repeat projection timing changed from about 2.9% faster inr1 to 5.1% slower inr2; unchanged controls also fluctuate. There is no material-benefit claim, production source recommendation or cycle qualification. RunState remains its original 262b559c hash.

All 16 owned Jobs finished with verified zero active processes and exact guard readback. This is closure evidence, not 16 passing tests: timeout, parser and oracle failures remain separate retained outcomes. Guards remain 12% aggregate CPU, 2GiB, suspended assignment, kill-on-close/no-breakaway, 180s focused bounds and unchanged 300s/43.712s Systems limits with 330s outer supervision. The known Windows certificate-store error remains in focused logs. No files were cleared. Paused feature work and release machinery remain untouched.

`BTH061-AUDIT-001`, `CONTENT-TIMEOUT-006`, `LAYER-DEFINITION-013` and `PERSISTENCE-PROJECTION-013` remain Open. The committed candidate still fails the full Systems stage at 300.255s (outer 303.4455s below 330); baseline fails at 300.234s. Both reports classify the inner timeout as a harness exception with timed_out=false. No aggregate repair or speedup is claimed. NEXT qualification remains separately owned and required for the bounded child. Continue profiling the remaining definition/schema and persistence postprocessor/layout owners while retaining every authority and budget boundary.

The [JSON report](deprecated_code_audit_continuation_013.json) retains exact outcomes, all 16 owned-job records, hashes and scopes. Independent post-run evidence: `evidence/catalog013-independent-final-review-r1.json`, SHA256 `7626a04d2aae27e9aeb24f9e14e3d75418872335f4c5e3e535f9249a8a59c047`. All 1,243 current source hashes match the candidate freeze; other 1,241 original sources remain byte-exact.

The timed-out harness did not create aggregate stdout or foundation_systems.json. Its 108-byte stderr and per-shard Godot logs remain preserved; missing aggregate artifacts are not treated as passing evidence. The exact maintained launcher is unchanged, and no import/validator/Smoke, compiled-native cohort, global process census or deployed browser acceptance is claimed. The original 180-second whole-content diagnostic remains separately Open.

Canonical production sources were never temporarily instrumented. Component clocks ran only in retained anonymous diagnostic copies. Original and candidate source bytes, failed fixtures, private diagnostic trees and the prior restoration-owner qualification remain retained. The source tool/guard hashes remain unchanged.

Warm catalog timing does not prove successful schema memo hits: the raw 55 definitions correctly fail without independently bound targets. No memo or successful-room speedup is claimed.

Manual current/all reconciliation with Git verification reports zero assigned audit/task9 findings and retains 78 current/544 all errors outside this scope, including 54 unrelated runtime findings across 149 instances. All prior 133 runtime objects, unrelated task/owner evidence, policies/metadata and normalized readable-ledger line content remain exact. All 1,243 candidate source hashes match, and the preserved checkout is clean. Evidence: `evidence/reconciliation013-results-{current,all}-r1.json` and `evidence/continuation013-scope-preservation-r1.json`.
