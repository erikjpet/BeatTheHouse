# BTH061-PULLTABS-SAVE-001: Grand Web Save acknowledgment

Status: **Open; original ticket rollback not attributed.** An independent Grand
Audit Night fixture confirmed a separate, relevant Save acknowledgment defect:
warm Load restored a newer saved clock while cold Continue could restore an
older clock. The scoped correction below passed the independent Web boundaries.
It does not establish the cause of the original campaign's lost collection.
Commit association and NEXT verification are recorded separately below.

## Original evidence and limits

The original NEXT source was `3fd56aebde05182a02a6babf096ae8b7fe430f7f`;
campaign `grand-fresh-r01`, seed `RUN-20261103-988450-001`. It had an earned,
carried Gold Players Card and an unclaimed Blue Bag. One ordinary $2 Pull Tabs
purchase retained $94 cash and Heat 0, reducing chips 15 to 13. Collection and
in-machine Menu Save showed unopened Moonlight Bars #008, pile 1/1, empty tray,
Day 3 8:00 AM. Cold entry showed that ticket back in the tray at 4:45 AM while
retaining the debit. Recollection and floor Save subsequently preserved custody.

The original case-121 screenshot identifies Audit Night by its signage
`EVERY DRAWER GETS COUNTED.`; authored data identifies
`grand_casino_audit_night`. The preserved command log contains Buy, wait 900 ms,
Collect, wait 350 ms, Menu, Save, screenshot, close. Although narrative evidence
mentions Open, that command log contains **no Open input**. The closer fixture
therefore follows the recorded inputs without a reveal.

The original report remains unchanged at
`C:\Users\theep\Documents\Codex\2026-10-27\task-2\evidence\grand-r01-window-125\PULL-TABS-ONE-TICKET-COLD-ROUTE-REPORT.md`.
Its retained copy SHA-256 is
`1fb7bb2eeef86247643b5db9402095d0662abf2d5a1443c95198b5e9086c241d`.
The advanced campaign, its saves and authority/profile companions were **not
read, copied, edited or replayed**. Its exact precollection generation was not
captured. A new fixture cannot diagnose that missing generation retrospectively.

## Independent reconstruction

`pull_tab_grand_fixture.gd` creates a fresh synthetic starting condition with
its own profile and authority companion. Production meta/resolver APIs supply
a carried Gold card; a production Blue Bag marker remains unclaimed. Starting
cash/chips are $94/15, Heat 0. An authored scenario pin and initial clock select
Grand Audit Night, Day 3 4:00 AM **before** normal world generation/finalization.
Room authority and semantic validation are retained. This starting grant does
not claim an earned route or replay a Gold-ending outcome.

Independent seed `BTH061-PULLTABS-GRAND-AUDIT-INDEPENDENT-1` naturally supplies
an available $2 row. Normal host/UI Buy yields unopened ticket #009, serial
001-64422; it debits chips once to 13. No ticket, outcome, stock order or RNG is
fabricated or filtered. No Peel, Peek, Auto, extra purchase or payout is used.

Native and Web fidelity differ. Native uses the full host with exact protected
snapshots. Web first preloads only the freshly generated **pre-purchase** fixture
and its own companions via the shipped Engine preload API. Cold sessions reuse
the same disposable profile/origin without reimport. They use ordinary input
and screenshots, with no game evaluator or storage inspection/editing. The
official engine/runtime is unchanged; this is a local independent Web fixture,
not the advanced campaign or a live NEXT-origin playthrough.

## Confirmed boundary and correction

The control uses immutable official runtime/PCK source
`467459090bd4ee2bdacd7674370b1742f8453150`. Its PCK SHA-256 is
`6ef2977cade39f136b29e3fd62980f1c4a0df0319c2cab6001119730672dab8a`.
Relevant Pull Tabs/save/host code is unchanged from original source 3fd56aeb.

| Official control boundary | Observed result |
| --- | --- |
| Collect, accepted machine Save 5:30 AM, close 94 ms after Save-click return | Cold Continue retains 5:30 AM and collected custody |
| Accepted floor Save 6:15 AM, close 150 ms after Save-click return | Cold Continue returns 5:30 AM; ticket/wallet retained |
| Later floor Save 7:00 AM, wait two seconds, close | Cold Continue returns 6:15 AM; ticket/wallet retained |
| Save at 7:30 AM, let clock reach 7:45 AM, then warm Menu Load | Restores 7:30 AM, proving the newer virtual-file generation is loadable |

HUD digital clocks display 15-minute marks. The 45-minute regressions exceed
that rounding; Web evidence does not claim an exact-minute comparison.

Manual Save previously acknowledged validated installation in Godot's virtual
filesystem. Neither BTH's synchronous write nor its async drain awaited browser
IndexedDB persistence. Godot schedules that sync later, and its promise completes
after the filesystem transaction. A delay alone is not a durability receipt.
This explains the acknowledgment gap demonstrated above; the exact engine/
IndexedDB timing responsible for the historical ticket report remains unproven.
No larger-save or timestamp-resolution cause is asserted.

The correction affects **explicit Menu Save** in `foundation_main.gd` only.
After validated installation, `web_save_durability_bridge.gd` captures the current
engine sync promise, calls public `JavaScriptBridge.force_fs_sync`, and waits for
a **distinct subsequent** engine-owned promise to finish without error. An
earlier in-flight sync cannot acknowledge the new Save. No concurrent
`FS.syncfs`, save-format change, IndexedDB schema access or engine/shell patch is
introduced. Native Menu Save remains synchronous.

The menu displays Saving and disables its controls/input/lifecycle transitions
while pending. Unsupported runtime, sync error or a 15-second timeout retain
the menu with a retry message rather than a successful dismissal. Stale
completion checks run/slot identity. Canvas processing and animation scheduling
are unchanged. The internal promise dependency is guarded for Godot 4.6.0 stable
commit prefix `89cea1439` and the expected persistent-filesystem/promise shape;
an engine upgrade must qualify/update this adapter.

Primary implementation references:
[JavaScriptBridge](https://docs.godotengine.org/en/4.6/classes/class_javascriptbridge.html),
[Web OS scheduling](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/os_web.cpp),
[filesystem sync JavaScript](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/js/libs/library_godot_os.js).
The shipped runtime's matching code was also inspected directly.

## Candidate qualification

Candidate base: `f8271e9fd01aafa59bdcb62b586f47984d0d2b5f`. A private Web PCK
exports the two frozen production changes; runtime donor remains 46745909.
Candidate PCK SHA-256:
`f58f4db12702998a8a278d51c356db8aa1a80a5c3f1690bf0e4e16c381570c81`.
Production-file hashes are retained in `task-14/grand-web-candidate/build_manifest.json`.
This private, uncommitted-candidate manifest is explicitly labeled; it is not a
deployment provenance claim. Export exits 0 with zero owned processes and no
script parse/load errors.

| Candidate Web boundary | Observed result |
| --- | --- |
| One Buy, Collect, machine Menu Save | Saving menu visibly retained/disabled, then success dismissal; clock 4:45 AM, pile 1/1, empty tray, $94/13, Heat 0 |
| Same-profile cold Continue/re-entry | Same unopened #009/001-64422 and 4:45 AM retained |
| New elapsed floor Save, close directly after visual success | Saved 5:30 AM; subsequent cold Continue retains 5:30 AM and ticket/wallet |
| New elapsed in-machine Save, close directly after visual success | Saved 7:30 AM; subsequent cold Continue retains 7:30 AM and ticket/wallet |

The rapid-close controller uses screenshots of the menu's fixed border to wait
for dismissal, then captures the full success image and closes immediately.
Full screenshots verify the condition; no runtime evaluator is used. Floor and
machine sync acknowledgments occur about 1.5 s and 0.8 s after Save-click return
in these capped runs. They are observations, not performance guarantees.

Candidate sessions are `grand-candidate-create-01`,
`grand-candidate-cold-machine-01`, `grand-candidate-cold-floor-01`, and
`grand-candidate-cold-machine-final-01`, under
`task-14/evidence/web-grand-candidate/sessions/`. Each has action/screenshot/error
and Job receipts. Completed jobs exit 0, leave zero owned processes and close
their loopback server; page/console errors are empty. Browser jobs use 12%
aggregate CPU/2 GiB, native checks 3%/2 GiB. No original campaign is touched.

Focused commands (run only with explicitly isolated user/profile/distribution
roots, as recorded by `task-14/run_owned.py` and its receipts):

```text
godot --headless --path . --script res://scripts/tests/pull_tab_grand_save_check.gd -- --audit --elapsed
godot --headless --path . --script res://scripts/tests/pull_tab_grand_save_check.gd -- --audit --elapsed --cold
node scripts/tests/web_save_durability_bridge_check.cjs
```

The final warm native run passes **59** assertions, including 16 synthetic
pending-menu checks. Those checks disable all nine actual menu controls and
attempt Close, Load, Abandon, Main Menu and duplicate Save while comparing run
reference, slot, saved-file SHA and protected state. They model the pending flag,
not a browser transaction. Exact clock, ticket/stock, cash/chips, Heat, string
RNG, inventory, Gold float bits, Blue Bag and modifiers are compared at actual
machine/floor Save boundaries. Repeat Collect remains idempotent. The paired
cold process passes **21** assertions. Receipts `grand-candidate-guard-native-warm`
and `grand-candidate-guard-native-cold` both confirm exit 0, no timeout and zero
owned processes. Along with the bridge contract, this is 96 focused assertions.

The exact embedded JavaScript adapter passes **16** checks for an older in-flight
promise, later success/error/rejection, unavailable persistence, busy request,
timeout and late callback. These tests do not claim rendered failure/retry UI
qualification. Positive pending/success UI is rendered above; error/unsupported
UI is covered by source review and adapter contracts.

Earlier independent native evidence remains labeled: generic Grand warm31/
cold15; Audit warm37/cold21; elapsed Audit warm43/cold21. The first candidate's
43-check native warm run also passed. An added-guard run ended without its final
runner receipt and supplies no qualification; a read-only process inventory
subsequently found no matching worker. The instrumented final warm run completes
all 59 checks. Setup-only Web attempts with a controller typo/wrong preload root
were closed before any wager and are not acceptance. The original cash-route
warm18/cold14/pending52/winner12 checks remain historical adjacent evidence;
their unchanged ticket/save-format paths were not rerun as a new broad suite.

## Tracking and remaining acceptance

**BTH061-PULLTABS-SAVE-001 stays Open.** The narrower acknowledgment defect has
independent native/Web acceptance; the original lost-collection generation and
its cause remain unavailable/unconfirmed. Do not mark the parent task Complete
solely because this correction is committed or deployed. Preserve the original
observation and associate the tested fix commit, NEXT identity and remaining
limitation in the canonical stability ledger.

Commit/NEXT receipt: pending final integration.
