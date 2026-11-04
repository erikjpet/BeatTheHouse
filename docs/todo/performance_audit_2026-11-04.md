# BTH-PERF-20261104: whole-game performance audit and fixes

Status: OPEN. Owner: dedicated performance audit, task-18. Created 2026-11-04.
Canonical audit record: [coverage, findings and evidence](../plans/performance_audit_2026-11-04.md).

Audit typical gameplay across the whole game for large leaks, major slowdowns
and avoidable expensive paths. Measure and fix confirmed substantial issues.
Web is the main discovery platform; actual native runtime gameplay and
performance coverage is also required. A scripted/native harness is not a
substitute for actual runtime play, nor do test counts certify native.

The owner's first example is Web Coin Pusher: moving the nozzle slows coin
dispensing/physics while the nozzle remains smooth. Profile authoritative
simulation, dense presentation, input work, allocations and frame timing
separately. This example does not narrow the whole-game scope.

Keep this parent open after each finding/batch. Every finding retains its own
ID, owner, reproduction, before/after evidence, fix commit and limits. Commit
tested scoped fixes to main and verify exact NEXT identity under the existing
pipeline. No completion without associated commit. Preserve saves, behavior,
fixed 16:9, touch/focus and autonomous animation; no portrait redesign.

Parent completion requires all coverage rows dispositioned with reproducible
Web/native evidence, substantial confirmed issues fixed or genuine blockers
recorded, normal-gameplay regressions and NEXT receipts linked, and explicit
reconciliation of remaining work. Source survey or one fix cannot close it.
