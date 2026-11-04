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
| BTH-PERF-20261104-001 | Source fix tested / main,NEXT and ordinary-input acceptance pending | Web continuous input reproduced180ticks/180nozzle moves/0coin publications,3017ms stale; fix restores90publications and17ms sampled age. Native before/after, conservation,payment and no-pointer liveness pass. [Evidence](../testing/performance_audit_20261104_coin001.md). | task-18 | Pending publication |
| BTH-PERF-20261104-002 | Native attribution measured / Web and fix pending | Video Poker hint computes32hold masks synchronously. Three generated hands measured1.17–1.33s cold versus17–40us cached under5% CPU cap. Diagnostic helper timings, not rendered gameplay or a platform budget verdict. Preserve deterministic recommendation. | task-18 | None |
| BTH-PERF-20261104-003 | Candidate / unmeasured | Coin Pusher consumed input dictionaries remain in the open live-session trace until exit; measure retained bytes/entries and verify rollback/settlement before changing it. | task-18 | None |

No large memory leak is confirmed from source inspection alone. Historical
reports are retained as leads and do not qualify this source or both platforms.

## Evidence and reconciliation

Initial source checkout is isolated at task-18/source; original dirty placement
work and primary player/browser saves are untouched. Native/diagnostic workers
use the maintained private capped Windows Job helpers, suspended assignment,
private state, bounded deadlines and closure receipts. Do not start another
NEXT watcher or substitute a manual deployment.

Main/NEXT integration, measured runtime coverage, fixed-behavior verification
and parent closeout remain pending. Reconcile this document and the associated
TODO against actual commits and worker evidence after each batch; explicitly
retain pending rows in handoffs so one delivery cannot erase the parent.

Related inherited coverage is `BTH061-009`, `BTH061-010`, and `BTH061-011` in
the [canonical named ledger](0.6.1_stability_release_plan.md#named-playtest-task-ledger).
This parent does not close those legacy rows, `BTH-05`, or any other worker's
acceptance. Its separate stable rows must be reconciled with that ledger.
