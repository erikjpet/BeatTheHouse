# BTH-BARDICE-WARM-PROGRESSION-001: warm Shake/Settle progression

Broad observed a genuine first22 Bar Dice round on build
`14d532f353334e7635800b93743c33d91a7a6fc3`: Roll Cup and Take Cover opened the
cup at167 cash, but warm Shake/Settle controls did not progress. A Settle input
about64 seconds after Take Cover still left SHAKE. Normal Save, engine-cold
Continue and re-entry restored progression; that original round then naturally
lost22 once, ending145. No second paid round or pre-failure save capture exists.
The completed original R04 profile was not opened, reset, exported or replayed
by this fix work.

Original report and screenshots:
`C:/Users/theep/Documents/Codex/2026-10-26/task/evidence/qa-BTH-BARDICE-WARM-PROGRESSION-001.json`.
They establish the public warm/cold contrast, not the original private clock or
RNG values. The reconstructed fixtures below are explicitly synthetic.

## Root cause and correction

Bar Dice stamps opening, reroll and settlement tumble starts in the Host's
pause-safe surface-clock epoch. A normal Continue can restore that epoch ahead
of fresh process uptime. The Bar Dice animation channel omitted its clock
source, so the shared canvas compared those starts with realtime process ticks.
When realtime was behind, elapsed time clamped to0 and the animation's input
gate stayed active even after the module's own correctly timed tumble expired.
Cold restoration removes process-local opening-tumble keys, explaining why the
same cup could then progress.

The correction supplies `clock_source: surface` for the Bar Dice tumble channel.
The authored900ms duration, block list, autonomous processing, shared canvas
defaults, saved deadlines, authority, dice generation, funding and settlement
remain intact. No item/scenario, portrait, fixed16:9 viewport, touch/focus or
scheduler change is included. The relevant Bar Dice, GameModule, canvas and
Foundation source on the initial current NEXT
`79ace22c2e508134c3ab4c5698b14426688ab6f6` matches the reported14d build.

The source mechanism is confirmed by deterministic model/canvas reproduction
and reconstructed Host acceptance. The unavailable original pre-failure clock
values are not claimed as directly inspected or recovered.

## Focused qualification

| Check | Passing assertions | Evidence scope |
| --- | ---: | --- |
| `bar_dice_tumble_clock_check.gd` | 32 | Generated table, normal module Roll/Take Cover, real canvas clocks/input gate/public action signal; authored console hit geometry registered by the test, no drawn-pixel/Host/Web claim |
| `bar_dice_warm_host_check.gd`, warm | 69 | Real production Host and drawn controls, future checkpoint via official Save/Continue, warm progression, exact accounting and replay rejection |
| Same Host check, cold | 25 | Separate-process settled-cup Continue/re-entry, bounded result feedback, unchanged full outcome guard and second official Save; zero paid inputs |
| Existing surface restoration check | 26 | Exact open cup/timing choice restore, invalid ledger/pending/unfundable rejection |
| Existing pending recovery check | 14 | Correct interrupted hand, funding, forged delivery rejection and exactly-once settlement |
| Total | **166** | Focused native assertions, not full-suite or original-save qualification |

The unchanged no-pointer animation-liveness check also passes. All qualified
jobs use the maintained5% CPU /2GiB kill-on-close runner, exit0 without timeout,
and leave zero owned processes. Native sandbox certificate-store diagnostics are
retained and are not an application-startup or TLS qualification.

The clock baseline on unchanged product source produced exactly six expected
failures among32 checks: future and paused/restored surface epochs completed
the module's tumble while the canvas still blocked Settle. Baseline surface
epoch192121 versus process12150 demonstrated the mismatch. Early blocking,
reduced motion, unchanged cup, RNG and durable state checks already passed.
After the one-channel change the same test passes32/32. Pause/resume keeps the
surface-clock owner; reduced motion removes the cosmetic gate. Rebuilding an
unchanged model does not restart or perpetuate the tumble.

The Host fixture uses supported practice-launcher167 cash /22 ante inputs and
an explicitly synthetic future checkpoint, saved with the official SaveService.
Normal Continue and game entry restore it before any wager. All eight gameplay
inputs use real rendered hit regions, injected native mouse events and ordinary
Host handlers: Roll, Take Cover, Shake, Shake, Settle, Slam, Lift and Call.
Three passive tumble waits advance the surface clock beyond900ms, produce
autonomous renderer frames, change no cup/accounting state and release the
controls without pointer movement or restart. The covered cup remains unfunded
until Call. Exactly one natural synthetic22 loss changes167 to145; the final
authoritative dice are retained, with one round and no pending delivery. Exact
duplicate and forged-stake delivery probes change no complete run field.

Normal Menu Save preserves the exact open cup before settlement, then saves the
single outcome. Cold Continue preserves full table/ledger, wallets, RNG,
inventory, story and outcome hashes. Its legitimate result feedback starts at
0.369s of the900ms cue; after a passive1068ms and77 renderer frames, it is1.437s
old and the new-round control is available. The entire outcome guard remains
unchanged, with zero new paid inputs. The earlier instant-availability test
expectation was retained as a test-contract failure, not treated as another
product stall. The cold-only wait adjustment does not change the qualified
warm function or product source; warm and cold receipts retain distinct test
file hashes.

## Commands, receipts and limits

Use the maintained local `run_owned.py` with a fresh private case for each
independent fixture and the same case for the Host warm/cold pair. Set
`BTH_BAR_DICE_HOST_STAGE=cold` only for the second Host process; original capture
and browser-profile inputs must be empty. Native entry points:

```text
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_tumble_clock_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_warm_host_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_surface_restore_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/bar_dice_pending_recovery_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/animation_liveness_without_pointer_check.gd
```

Local evidence root:
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/`.
Qualified receipts are `bardice-clock-final-result.json`,
`bardice-host-qualified-warm-result.json`,
`bardice-host-bounded-cold-result.json`, and the corresponding Job/log files.
The adjacent Job/log prefixes are `bardice-adjacent-restore`,
`bardice-adjacent-pending` and `bardice-adjacent-liveness`. Original report,
baseline, setup/parser diagnostics and the instant-cold expectation failure are
preserved separately and excluded from passing counts. No saves or keys are
committed or uploaded. Native GUI-event testing is distinct from OS-pointer or
visual Web acceptance.

## Release status

The stable task remains Open until its tested fix commit is associated and
exact NEXT identity/basic startup is verified. Item and scenario work remain
paused. Stable/itch and the hosting audience are unchanged.

## Authorized publication follow-through

On2026-11-04 explicit user approval authorized finished work publication to
NEXT. Exact implementation `be3f1b2d99d6d6f36ee65637f9e8e75a788ecbe8` is preserved
by a separate merge onto current public main `f3058b6daab820e9d747c4c4aabc2d983e9ae32e`.
Current Host warm/cold refresh, one authorized publication retry and exact
NEXT acceptance are pending. Original166-check and no-input liveness evidence
retains its original source and scope. No original R04 cup is opened or
replayed; other finished fixes retain separate commits and acceptance records.
Item/scenario and fixed16:9/touch/focus boundaries remain unchanged.

### Published fix; NEXT export failure, 2026-11-04

The separately reviewed normal push succeeded at
`345f94149609e828c76c7a9df6b2cffaff5862b9`, preserving exact original fix
`be3f1b2d99d6d6f36ee65637f9e8e75a788ecbe8`. Current-main warm69 and independent
cold25 checks pass with zero owned processes; cold retains cash145, one settled
round and zero new paid inputs. Existing166-check/liveness evidence remains
historical unchanged-path qualification, not a fresh full-suite pass.

The existing watcher attempted this exact source and failed at16:10:25UTC,
49%PCK savepack, with `Stack overflow.` and exit3221225725 (0xC00000FD). The last
logged asset is a generated Coin Pusher export-parity scene, but that location
does not establish the cause. No allocation root cause or link to Bar Dice
metadata is proven. Previous NEXTf3058b6daab820e9d747c4c4aabc2d983e9ae32e remains
served and verified for the other two fixes. Bar Dice stays Open: published and
native-qualified, but not yet built/deployed/startup accepted.

Raw evidence `finished-stackoverflow-345.log` and
`finished-combined-export-failure-status.json` are preserved in task-6 evidence;
`finished-release-combined-receipt.json` distinguishes each task. This follow-up
records real partial acceptance and the remaining blocker. The watcher keeps
its ordinary15-minute same-SHA retry/new-main behavior; no restart, duplicate
watcher, manual substitute build, cap/trust change or original-state access
was used.
