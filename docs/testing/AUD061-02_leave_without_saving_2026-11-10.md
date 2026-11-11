# AUD061-02 — leave_without_saving

Specification: [BTH_0.6.1_audit_work_orders.md](../todo/BTH_0.6.1_audit_work_orders.md). Started from `ca2302b6bbe36f9b2d6b2af7fbcd8728de9ab968`; remote source baseline `06e5492116b2f4aac78ffbc3d41ed15be64833a9`.

## Before

Locked Godot `--headless --path E:\CodexQA\BTH\workspaces\aud061-20261110 --script res://.tmp/aud061_before.gd`, guarded run `aud061-01-02-before-20261110`, exit 0. This is a fresh synthetic native profile using the real DurableStore/MainScene/save APIs; no personal save. The source of the disposable probe is retained in `evidence/AUD061-01-02_20261110/before_probe.gd`.

Actual output:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061-01 BEFORE {"result":{"data":{},"error":22,"error_code":"stale_transaction_rollback","message":"Stale Transaction Rollback","ok":false,"outcome":"nothing-loadable"},"stale":".bak.rollback","stale_remains":true,"valid_primary":true}
AUD061-01 BEFORE {"result":{"data":{},"error":22,"error_code":"stale_transaction_rollback","message":"Stale Transaction Rollback","ok":false,"outcome":"nothing-loadable"},"stale":".rollback","stale_remains":true,"valid_primary":true}
AUD061-01 BEFORE {"result":{"data":{},"error":22,"error_code":"stale_transaction_rollback","message":"Stale Transaction Rollback","ok":false,"outcome":"nothing-loadable"},"stale":".bak.rollback","stale_remains":true,"valid_primary":false}
AUD061-02 BEFORE {"baseline_saved":true,"last_error":{"data":{},"error":20,"error_code":"debug_forced_write_failure","message":"Debug Forced Write Failure","ok":false,"outcome":"nothing-loadable","slot_id":"foundation_ui_autosave"},"leave_dialog_exists":false,"main_menu_return":false,"run_retained":true,"started":true}
AUD061-02 BEFORE Exit and native close returned; run still open=true

```

## Change

`foundation_main.gd` and `foundation_screen_builder.gd` add the specified ConfirmationDialog and pending action. Keep playing has focus; the existing ModalFocusScope owns its two-button Control row and Window input. Main Menu and Exit retain their save guard, then offer an explicit loss choice. A repeated native close confirms Quit. The confirmed quit joins only owned prewarm/save work. Tutorial/meta and pending Web Save branches remain. The existing navigation contract retains its preservation/retry assertions and now cancels the new choice between attempts; a new contract tests cancellation, Continue, healthy/pending paths and actual native shutdown.

## After

The same stale-file conditions and failed-save navigation steps are exercised by the committed contracts. Actual decisive output (verbatim):

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

HEALTH06_1_DURABLE_STORE PASS checks=129 failures=0
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_LEAVE_CONTRACT mode=menu checks=20 failures=0
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_LEAVE_CONTRACT mode=exit checks=14 failures=0 actual_shutdown=true
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_LEAVE_CONTRACT mode=repeat checks=14 failures=0 actual_shutdown=true
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

SAVE_NAVIGATION_DURABILITY PASS paid_drop_seeds=2 storage_failure_recovery=true interrupted_settle_recovery=true forced_save_results=true
BAR_DICE_SHUTDOWN_SAVE_OBSERVATION {"async_save_in_flight":false,"async_slot_id":"","async_task_id":-1,"completed_generation":4,"dirty_generation":5,"host_alive":true,"host_processing":true,"host_queued_for_deletion":true,"label":"tree_exiting_after_host_exit_tree","last_outcome_error":0,"last_outcome_ok":true,"pending_after_frame":-1,"pending_autosave":false,"pending_not_before_msec":0,"process_frame":692,"service_alive":true,"service_instance_id":-9223371927685429761,"ticks_msec":21335}
```

Full commands, output and Bar Dice86/0 result JSON are retained in `evidence/AUD061-01-02_20261110/`. The Coin Pusher navigation checks ran on native Godot using the available `gdscript_v3` solver; no matching native plugin was supplied to this isolated checkout. Native window shutdown is directly observed; this does not claim native solver qualification or Web gameplay.

First explicit-exit test held references in its own suspended coroutine and emitted resource-retention errors. Returning from the test coroutine before engine teardown removed those test-owned references; both actual shutdown reruns are clean. An overlapping Smoke attempt stopped at the existing concurrency guard (exit 125); no guard was disabled. Serial run02 and the reviewed UTF-8 run retained the same 4/7 stage result. A focused stacked-scope check then caught a dialog-owned viewport retained after cancel (20 checks, 1 failure); the new helper now rebinds the surviving scope through its existing public API. The final exact-source Smoke comparison and bounded timing controls are retained below. All prior failed/intermediate attempts remain in guarded evidence.

## Test comparison

Baseline: Smoke 4 pass / 7 fail; Python 180 pass / 0 fail; animation liveness 1 pass / 0 fail; ledger 1683 inherited errors. Focused checks: durable-store 129/0; leave contracts 20/0 + 14/0 + 14/0; Bar Dice shutdown 86/0; save-navigation suite pass (no numeric assertion total printed). Final-source Smoke: **4 pass / 7 fail**, matching baseline stage results. Content25/runtime16 assertions and parser/UI/geometry failures match exactly. The performance stage recorded11 failures versus baseline10 due to one Blackjack p95 outlier6.006ms against5ms. A bounded candidate repeat measured3.447ms and unchanged-source control3.689ms, each with the original10failure categories. These do not establish a sustained rendering regression; the outlier remains retained and later performance qualification stays open. No budget, cadence, test or animation floor changed. See `smoke_comparison.json` and `performance_controls.json` in the evidence directory. Ledger after registration remains 1683 inherited errors, zero new scoped findings. See [baseline](AUD061_baseline_2026-11-10.md).

## NEXT

Pending: paired code/proof and associated-SHA ledger commits have not been pushed yet. After tests compare no worse than baseline, push together through existing main watcher and record exact promoted/served identity, startup and visible Web behavior here. Native window close remains native-only evidence.

Unverified: deployed behavior and storage-denial cleanup failure under a real OS file lock. No read-side recovery, save migration, manual export/deployment, guard change or item/scenario content change.

## Performance control custody

Three production files were temporarily replaced with exact baseline HEAD content for the unchanged-source control and restored byte-for-byte to their recorded reviewed SHA-256 values before staging. Initial control preparation attempts were stopped by exact storage-guard declaration errors (`invalid_path` for a relative path; `not_directory` when an existing output file was supplied as a writable directory). No guard, volume, reserve or security setting was changed. The first run named control01 actually measured candidate source because preparation had stopped; it is explicitly classified as candidate in the retained comparison. Control02 measured original baseline source. All owned Jobs ended with zero active processes.
