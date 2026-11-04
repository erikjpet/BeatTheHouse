# Vault Drop manual Save feedback

Task `BTH061-VAULTDROP-SAVE-001` retains the original R04 observation. Child
`BTH061-VAULTDROP-SAVE-FEEDBACK-001` tracks the independently testable feedback
defect. Both remain Open until their own commit and required acceptance exist.

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
Results, commit association and exact NEXT acceptance remain pending.

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
| Rendered native guidance | Pending | `evidence/vault-save-visual-1` |
| Exact main/NEXT identity and served startup | Pending | Recorded after tested commit |

Completed capped jobs above ended without timeout and drained owned processes
to0. Native behavioral acceptance, adapter contracts and eventual NEXT Web
startup are separate scopes; no real Web live-machine refusal is claimed by a
native test. No canvas scheduling/performance code changes in this correction.
All191 existing ledger IDs are retained without duplication; the two named Vault
tasks make193. Item and scenario implementation, including Gas, remains paused.

During setup, the C drive reached0 free bytes and one shell launch failed before
execution (OS112). Three task14-derived served-PCK downloads were removed only
after their hashes matched retained release receipts, freeing about142MB. All
receipts, screenshots, source and private fixture expectations were preserved.
Cleanup inventory: `task-14/evidence/derived-binary-cleanup-vault.json`.
