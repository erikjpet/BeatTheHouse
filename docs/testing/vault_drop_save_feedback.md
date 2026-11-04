# Vault Drop manual Save feedback

Task `BTH061-VAULTDROP-SAVE-001` retains the original R04 observation. Child
`BTH061-VAULTDROP-SAVE-FEEDBACK-001` tracks the independently testable feedback
defect. The feedback child is Complete with associated fix commit85c1782b and
the acceptance below; the original R04 parent remains Open.

## Original evidence and limit

Read-only source: `C:\Users\theep\Documents\Codex\2026-10-26\task\evidence\qa-R04-VaultDrop-763764-save-mismatch.json`,
SHA-256 `e171a801b9693874c2d87345442d320a56c47d1d5a8206a3be88ce096c03df28`.
Cases763/764 used source `3a9056120879fdabb91098e8612fb38e36a594db`, tree
`1dbb666695feb1ea4e7a69282f341f11384c4b41`, same localhost8099 origin and resident
`broad-challenge-r04` resume. Case763 cold began cash124, Heat0, Day5 07:45.
Machine entry was08:00; one normal Vault Drop cost1, leaving123 at08:15 with
Collect0($0). Save was dispatched at07:18:03.392Z, about13.416s after Drop began.
After1s the controller clicked HUD Menu, waited200ms, captured, then closed.
Case764 cold restored124 and07:45, with the previous taxi record newest.

There was no second Drop, skill Stop, Nudge, collection, normal Leave, item or
scenario action. Owned browser processes drained to0 and page errors were empty.
The menu capture shows generic "Resume Slot ready" text and enabled Save. Neither
"Saved" nor a pending/error acknowledgment was captured. The receipt explicitly
records `semantic_game_acceptance:not_asserted`. The intervening HUD Menu click
means this screenshot cannot identify the original internal Save branch. It is
consistent with refusal while live physics was unsettled; it does not establish a
falsely acknowledged Save or accepted-save rollback. Original generations and
load provenance are unavailable. No original profile/key/save is read, copied,
restored, refunded or replayed by this investigation.

## Confirmed source path

On the observed source, `_autosave_foundation_run(..., true)` returns false before
snapshot/write/bridge if `foundation_save_ready` is false. The Run Menu pauses
simulation, so waiting inside it cannot complete a live machine. The refusal is
sent to the hidden `message_label`; `_refresh_run_menu` shows generic slot text
and retains only Web bridge failures. Immediate storage failures have the same
feedback gap. Normal Leave uses the existing chunked settlement and durable
publication path. Save must not settle, refund, replay or change those mechanics.

## Independent qualification

Focused production-host check:
`res://scripts/tests/vault_drop_save_feedback_check.gd`.
Fresh seed `BTH061-VAULT-SAVE-001-F` selects the cabinet type only: source FNV64
absolute2798434022198271472 -> RNG seed1781198789 -> weighted roll81
(Vault bucket71..100). No paid result was inspected in selecting
it. Before spending, runtime must assert the normal Corner Store, no forced
variation, actual durable/surface Vault identity and nine cells. A mismatch stops
before the single normal production-pointer Drop.

The fixture requires explicit private `user://` and persistence paths before
host creation and verifies the actual SaveService distribution-root save path.
It checks refusal text, no pending/success acknowledgment, unchanged protected
live state and primary/backup fingerprints, refresh/reopen retention, normal
Leave settlement, floor Save, fresh-service/warm Continue, separate-process cold
Continue and storage-busy recovery. The continuous environment clock is disabled
only in the disposable test fixture, as in the established navigation test.
Final results, commit association and exact NEXT acceptance are recorded below.

The first unchanged-source attempt (`vault-save-red-1`) completed normally with
owned processes0, but its compound startup/Corner Store assertion failed before
any paid action. It also independently failed the storage-busy visible-refusal
assertion. That run does not qualify Vault behavior. The fixture now separates
the route stages, records offered targets and authority, and allows ordinary
frames for queued room publication. The actual resolved path guard fails closed
before gameplay. Setup failures are retained rather than counted as a product
failure or discarded paid outcome.

`vault-save-red-2` established the setup cause: candidateE offered only Bar and
Motel, with Corner Store absent, no modal and valid checked room authority. No
paid action occurred. A bounded route-only helper considered source-derived
Vault candidates F/K/N/T/U/Z and stopped immediately atF: normal start offered
Bar and enabled Corner Store. It performed no travel, machine entry or paid
action. Receipt `vault-route-qualify-1` passed with owned processes0; its exact
helper is retained at `task-14/evidence/vault_drop_route_qualification.gd`.

On unchanged production source, `vault-save-red-3` reached an actual generated
Vault and completed54 assertions with exactly4 failures: the unsettled-machine
refusal and three storage-busy attempts lacked visible refusal text. The other
checks passed, including the single debit, no pending/success acknowledgment,
unchanged protected live machine/wallet/RNG/clock/inventory and primary/backup,
normal Leave, settled floor Save, fresh-service and warm Continue, recovery
retry and no stale feedback after Load/New Run. Exit1 was expected for the
confirmed defect; no timeout and owned processes0.

## Scoped correction

The existing private Web-error field is now `_manual_save_error`, shared by
immediate manual refusals and the unchanged Web bridge failures. A refused Save
retains a visible "Not saved" notice in the Run Menu. An unsettled machine says
"Resume, then Leave the machine and save from the floor." Storage refusals retain
their actual error reason. Refresh and reopening preserve the notice; a new
attempt, successful run replacement or Load clears it. Lifecycle rollback
snapshots the field with the other save-status state.

The readiness guard, physics, settlement, wallets, payouts, native addon, disk
serializer and Web durability bridge are unchanged. This corrects feedback and
does not attribute the uncaptured original R04 branch. Original mismatch task
`BTH061-VAULTDROP-SAVE-001` remains Open. Its next trigger is a new disposable
post-acknowledgment rollback or an unexplained primary/backup load: retain exact
build/origin/slot, first cold clock/wallet/machine, acknowledgment and both save
generation fingerprints plus load outcome before another Save. No lost original
save is requested.

## Acceptance results

| Check | Result | Retained task14 evidence |
| --- | --- | --- |
| Unchanged actual Vault baseline |54 checks; exactly4 expected hidden-refusal failures | `evidence/vault-save-red-3.json` and `.log` |
| Corrected warm host |54 checks, no failures | `evidence/vault-save-green-1.json` and `.log` |
| Separate-process cold Continue |12 checks, no failures; no paid action | `evidence/vault-save-cold-1.json` and `.log` |
| Exact Web durability adapter |16 contracts, no failures; no profile/save/network I/O | `evidence/vault-save-web-adapter.log` |
| Rendered native guidance | Blocked before script initialization in two bounded attempts | `evidence/vault-save-visual-1.json` and `vault-save-visual-2.json` |
| Actual NEXT ordinary-input refusal and recovery | Passed; visible guidance at1280x720 and960x540, one Drop only, normal Leave/floor Save and cold Continue | `evidence/vault-feedback-web-acceptance.json` |
| Exact main/NEXT identity and served startup | Passed for85c1782b | `evidence/next-85c1782be759d4e50c50219945231312c2287640-release.json`; `vault-next-startup-85c1782b.json` |

Passing functional and route-qualification jobs ended without timeout and
drained owned processes to0. The two native graphics timeouts are described
separately below. Native behavioral acceptance, adapter contracts and NEXT Web
startup are separate scopes; no real Web live-machine refusal is claimed by a
native test. No canvas scheduling/performance code changes in this correction.
All191 existing ledger IDs are retained without duplication; the two named Vault
tasks make193. Item and scenario implementation, including Gas, remains paused.

Fix commit `85c1782be759d4e50c50219945231312c2287640`, tree
`ca81af757c465ede98b6f07a252f97fffb28225a`, was pushed to main and promoted by
the existing NEXT watcher at2026-11-04T08:07:37Z. Exact status/pointer/redirect,
BUILD/manifest/REF/VERSION and provenance agree. All six payload HEAD checks
passed; direct served PCK SHA-256 is
`243f191e094861029a239e0521ac6d0447fab550b4bd0afc4485afac547552f0`.
A fresh private browser displayed Version0.6.0-dev+85c1782be759, captured and
closed with no page/console errors and owned processes0. It made no gameplay
claim.

The native GL attempts each reached the300s resource-bound deadline before the
helper's initialization marker or any fixture/capture directory. CPU totals were
209.421875s and225.53125s; each job drained to0. The second retained only its own
first-attempt engine cache, since no fixture action had begun. Exact CLI
forwarding was checked. No shader/fixture root cause is established, no canvas
processing was disabled, and no performance change was made. These are
incomplete native visual checks, not gameplay failures. Actual Web rendering
qualifies the visible correction separately; no native raster pass is claimed.

## Actual NEXT ordinary-input acceptance

On the immutable85c NEXT build, a fresh disposable browser profile used visible
PLAY, normal First Night Skip Lessons/confirmation and Run Setup. Its first
restricted launch failed before navigation with a GPU-child access error and
drained to0. The approved process-sandbox escalation retained Chromium's own
sandbox and the12% CPU/2GiB Job cap. One unpaid preparation run revealed a
controller `insertText` issue; it was closed before travel or gameplay. The
controller changed to ordinary key events and verified the visible exact seedF
before Start. Neither setup failure was counted as gameplay acceptance.

Qualified session `vault-feedback-next-f-route-03` confirmed the normal Corner
Store route and paid its3 bus fare, cash100 ->97. The actual Vault cabinet was
visually confirmed before one ordinary Drop, cash97 ->96, Heat0. Manual Save
while unsettled displayed the exact recovery notice inside the Run Menu at both
1280x720 and960x540, fully readable and unclipped (independently viewed by the
parent investigator). No second Drop, Stop, Nudge or Collect occurred.

Resume and ordinary Leave completed settlement and returned to the floor.
Manual floor Save dismissed the menu with its normal acknowledgment at Day1
1:45PM, cash96, Heat0. The preceding capture showed "Saving to Resume Slot... Keep
this tab open." with disabled visible buttons. The browser closed286ms after the Save-click return, with
the post-ack screenshot before close. Separate-process session
`vault-feedback-next-f-cold-04` used normal Continue and captured the first floor
and menu at the same Day1 1:45PM/cash96/Heat0 and exactF seed. The old refusal
notice was absent. There was no further Save, machine entry or gameplay input.
Both qualified browser sessions completed with no page/console errors and owned
processes0. Web acceptance compares visible wallet/clock/seed and recovery;
native tests supply the full machine/tray/RNG comparisons. The floor's generic
Quarter Falls room/action labels are not evidence of cold Vault identity; that
identity is explicitly qualified by the native full-state comparisons.

Screenshots and typed command receipts are retained under
`task-14/evidence/web-vault-feedback/sessions/`. Key images in the route03 session:
`not-saved-1280.png`, `not-saved-960.png`, `after-normal-leave.png` and
`floor-save-ack.png`. The summary and all preparation classifications are in
`task-14/evidence/vault-feedback-web-acceptance.json`.

`BTH061-VAULTDROP-SAVE-FEEDBACK-001` is Complete: fix85c1782b is on main/NEXT,
native warm/cold and storage recovery pass, Web durability contracts pass, and
the actual deployed guidance/recovery/cold boundary passes. Its parent and
`BTH061-PULLTABS-SAVE-001` remain Open; neither original observation is attributed
or closed by this narrower correction.

During setup, the C drive reached0 free bytes and one shell launch failed before
execution (OS112). Task14-derived served-PCK downloads were removed only
after their hashes matched retained release receipts. All
receipts, screenshots, source and private fixture expectations were preserved.
Cleanup inventory: `task-14/evidence/derived-binary-cleanup-vault.json`.
