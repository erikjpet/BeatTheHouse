# AUD061-09 — retry after an older async failure

Specification: [BTH_0.6.1_audit_work_orders.md](../todo/BTH_0.6.1_audit_work_orders.md). Started from `9bfba25bb2923740b96a6ae430c0d66d0b9b79b6` (paired01/02 delivery receipt; product runtime matches deployed18af19ac).

## Before

Pinned Godot4.6 `--headless --path E:\CodexQA\BTH\workspaces\aud061-20261110 --script res://scripts/tests/aud061_async_failure_retry_contract.gd`, guarded run `aud061-09-before-20261110`, exit1. Fresh synthetic profile. The failing subclass returns ERR_BUSY from an actual WorkerThreadPool task; the main thread joins that task. The same contract runs before/after.

Actual final output (17 checks,7 failures):

```text
AUD061_ASYNC_RETRY {"checks":17,"failures":["explicit save tries current write after old async failure","older async failure retained for diagnostics","two failures report second write error rather than older ERR_BUSY","clear removes both generations after old worker failure","host synchronous save writes current state after old failure","successful new write clears current failure state","host retains older drain failure separately"],"observations":[{"case":"retry","file_exists":false,"outcome":{"completed":true,"error":44,"in_flight":false,"ok":false,"slot_id":"retry"},"result":44,"task_drained":true},{"case":"both_fail","outcome":{"completed":true,"error":44,"in_flight":false,"ok":false,"slot_id":"both_fail"},"result":44,"task_drained":true},{"backup_exists":true,"case":"clear","primary_exists":true,"result":44,"task_drained":true},{"case":"host","cash":99,"loaded_cash":100,"outcome":{"completed":true,"error":44,"in_flight":false,"ok":false,"slot_id":"foundation_ui_autosave"},"saved":false,"task_drained":true}]}
```

## Change

`save_service.gd` retains the previous failure in `last_async_failure_outcome` and continues the requested synchronous write after joining. `clear_run` also joins and continues deletion. `foundation_main.gd` retains its generation-specific failure record, then attempts the current synchronous generation. The new write decides success/error and clears current blocked state on success. Mutex, validation, format, scheduling and owned worker drain remain in place. The new17-check contract covers healthy retry, two distinct errors, deletion of both generations and saving the host's current99cash instead of the previous100cash.

## After

Same command, guarded run `aud061-09-after-20261110`, exit0:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_ASYNC_RETRY {"checks":17,"failures":[],"observations":[{"case":"retry","file_exists":true,"outcome":{"error":0,"error_code":"","ok":true,"slot_id":"retry"},"result":0,"task_drained":true},{"case":"both_fail","outcome":{"data":{},"error":20,"error_code":"debug_forced_write_failure","message":"Debug Forced Write Failure","ok":false,"outcome":"nothing-loadable","slot_id":"both_fail"},"result":20,"task_drained":true},{"backup_exists":false,"case":"clear","primary_exists":false,"result":0,"task_drained":true},{"case":"host","cash":99,"loaded_cash":99,"outcome":{"error":0,"error_code":"","ok":true,"slot_id":"foundation_ui_autosave"},"saved":true,"task_drained":true}]}
```

Adjacent actual output:

```text
HEALTH06_1_DURABLE_STORE PASS checks=129 failures=0
SAVE_NAVIGATION_DURABILITY PASS paid_drop_seeds=2 storage_failure_recovery=true interrupted_settle_recovery=true forced_save_results=true
```

## Test comparison

Focused retry17/0 versus before17/7; durable-store129/0; navigation suite passes (no numeric assertion total printed). All owned jobs exited, zero active processes. Smoke **4stages pass/7fail**, exactly matching baseline; content25/runtime16 assertions, parser/UI/geometry and10performance error lines match, with zero new normalized errors. Full comparison in `evidence/AUD061-09_20261110/smoke_comparison.json`. Actual Smoke command: `powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages`, exit1, no timeout. Baseline Smoke4stages pass/7fail, Python180/0 and liveness PASS are recorded in [baseline](AUD061_baseline_2026-11-10.md). No canvas or pause scheduling changed in this order. Evidence and storage/launch gates are retained under `evidence/AUD061-09_20261110/`.

## NEXT

Pending code/ledger commits and existing-pipeline promotion; finished-source focused checks and Smoke comparison complete. The actual older-worker-failure/current-write branch is directly tested on native Godot; Web startup and visible manual-save recovery remain to be checked against the exact pushed build. No native solver qualification, personal profile, migration, item/scenario or deployment-guard change is claimed.
