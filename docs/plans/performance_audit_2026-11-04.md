# Whole-game performance audit: BTH-PERF-20261104

Status: **OPEN / investigating**. Owner: performance audit task-18.
Created 2026-11-04; runtime baseline source `dc15b7d369f435d50fbf16e37af33952a4c58760`.
The initial developer checkout `398546e3` was stale; current NEXT source was
fetched from the watcher's existing local Git object repository before tests.
This objective is separate from deprecated-code cleanup and three-slot
qualification. It does not gate other playtests or room/game fixes.

## Scope and completion contract

Find and solve substantial avoidable performance hits and sustained memory or
resource leaks in typical play. Prioritize Web discovery without neglecting
native. Measure both platforms for major findings. Record actual runtime play
separately from synthetic/module checks and rendered automation. Preserve
authoritative ticks, RNG/economy, save compatibility, input/touch/focus, fixed
16:9, and no-input animation. Keep existing budgets.

The parent remains OPEN until each coverage row has current evidence or a
specific disposition, all substantial confirmed findings have a fix or a
genuine blocker, focused regressions and main/NEXT receipts are recorded, and
the full scope is reconciled. A delivered finding is a child batch only.
Completed todos require an associated commit; no rows are complete initially.

## Coverage plan

Every row needs build/source, route/fixture and starting state, platform and
hardware/profile, warmup/window, frame mean/p95/max, actual progress/liveness,
memory/object/resource retention where applicable, and evidence paths.
Diagnostic capped-host numbers are not general hardware qualification.

| Coverage | Web | Native runtime | Owner / next evidence |
| --- | --- | --- | --- |
| Coin Pusher: idle, drops, sustained nozzle drag, release; all three cabinets | Pending | Pending | task-18; distinguish solver ticks/backlog, emissions, projection serial/age, frame/input cost |
| Scratch Tickets and Pull Tabs: dispense/open/scratch/discard/reentry | Pending | Pending | task-18; frame/input cost and retained ticket resources |
| Slots: regular/autoplay, Buffalo, bonus and Pinball | Pending | Pending | task-18; foreground/background progress and interruption/reentry |
| Blackjack, Baccarat, Roulette: live deal/spin/settlement | Pending | Pending | task-18; frame/input/draw timing, histories and save/reentry |
| Bar Dice, Craps and Crew Hold'em: ordinary rounds/street/AI turns | Pending | Pending | task-18; action latency, histories and normal progress |
| Video Poker: ordinary deal/draw, Fred's hat hint, multi-hand/double-up | Pending | Pending | task-18; cold/warm hint computation versus normal deal |
| Rooms: quiet/crowded actors, placement overlay, focus/touch | Pending | Pending | task-18; draw/process attribution with autonomous liveness |
| Map, travel, scenarios, Crew/dialogue, inventory/services | Pending | Pending | task-18; transitions/refresh latency and retained state |
| Save/Continue, menu/run restart, aged normal saves | Pending | Pending | task-18; phase attribution, isolated custody and resource plateau |
| Audio on/off, repeated room/game/menu/Continue cycles | Pending | Pending | task-18; wall-clock retention slopes/cache bytes and audible/runtime recovery |

Source survey is discovery, not runtime coverage. See the companion
[source survey](performance_audit_2026-11-04_source_survey.md).

## Findings

| ID | Status / severity | Evidence and next action | Owner | Fix commit |
| --- | --- | --- | --- | --- |
| BTH-PERF-20261104-001 | Scoped fix on main/NEXT; broader normal-play performance remains | Web continuous input reproduced 180 ticks/180 nozzle moves/0 coin publications, 3017ms stale; fix restores 90 publications and 17ms sampled age. Native before/after, conservation, payment and no-pointer liveness pass. Main ea136553 is included in verified NEXT247ebe32; exact served bytes and fresh menu launch pass. [Evidence](../testing/performance_audit_20261104_coin001.md). | task-18 | ea136553ce3f33236aa3ea22d23921e6f957e7a2 |
| BTH-PERF-20261104-002 | Partial improvement tested on native/Web; residual synchronous hitch stays OPEN | Identical generated hands show 35–51% cold calculation reductions in capped native/Web samples; 1083 payout cases and 96 mask EV comparisons preserve advice and semantics. Cold advice still takes roughly 0.67–1.36s in these diagnostics. Normal rendered Deal responsiveness and bounded/deferred residual work remain. [Batch evidence](../testing/performance_audit_20261104_batch002_003.md). | task-18 | e6fef69a19cf73b4805fda734724652d76e0e141 |
| BTH-PERF-20261104-003 | Native/Web retention fix tested; delivery and broader play acceptance pending | Consumed history now compacts at 1024 events. After 30000 events, native retained growth falls from 18.9MB to 0.18MB; Web retains 304 records versus 30000 with all ticks/counts preserved. Web byte monitoring is unavailable. Native/Web order, authored-time, no-replay, legacy, settlement and DROP rollback checks pass. [Batch evidence](../testing/performance_audit_20261104_batch002_003.md). | task-18 | e6fef69a19cf73b4805fda734724652d76e0e141 |

Avoidable input-history retention is now measured at runtime as finding003.
No other large leak is confirmed from source inspection alone. Historical
reports are retained as leads and do not qualify this source or both platforms.

## Evidence and reconciliation

Initial source checkout is isolated at task-18/source; original dirty placement
work and primary player/browser saves are untouched. Native/diagnostic workers
use the maintained private capped Windows Job helpers, suspended assignment,
private state, bounded deadlines and closure receipts. Do not start another
NEXT watcher or substitute a manual deployment.

Coin001 main/NEXT identity and startup are verified. Findings002/003 delivery,
broader measured runtime coverage, normal-play acceptance and parent closeout
remain pending. Reconcile this document and the associated
TODO against actual commits and worker evidence after each batch; explicitly
retain pending rows in handoffs so one delivery cannot erase the parent.

Related inherited coverage is `BTH061-009`, `BTH061-010`, and `BTH061-011` in
the [canonical named ledger](0.6.1_stability_release_plan.md#named-playtest-task-ledger).
This parent does not close those legacy rows, `BTH-05`, or any other worker's
acceptance. Its separate stable rows must be reconciled with that ledger.

Actual native GPU telemetry attempts used OpenGL on RTX4070Ti, distinct from
module/unit checks. The initial 300-second sweep reached Baccarat; a bounded
240-second follow-through reached Roulette ball-settle. Neither produced a
final report, so neither certifies remaining native coverage. Logs and zero-job
cleanup receipts are retained. A shorter existing rendered foundation producer
is reported separately. No current player save is a prerequisite.
