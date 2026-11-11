# AUD061-14 — Handle six ignored store-save results

Started from main **494c5db53e9ca0a39b55e0955f58f65e7ee7524d** (AUD061-16 delivery receipt); NEXT e05ceb6bd64f3ddec44804752aaa32d88600c622. Specification: [audit work order](../todo/BTH_0.6.1_audit_work_orders.md#aud061-14--six-call-sites-ignore-a-failed-profile-meta-or-settings-save).

## Before

Pinned Godot4.6.stable.official.89cea1439, approved E-root profiles, capped Job12% CPU/2GiB, assignment before resume. Command before/after:
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/aud061_ignored_store_failures_check.gd

Actual original29-check run (a prior fixture type-inference error is also retained, not counted as a reproduction):
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_14_IGNORED_STORES {"checks":29,"failures":["scratch failed store remains pending","home_setting failed store remains pending","reset_coach failed store remains pending","seen_coach failed store remains pending","purchase failed store remains pending","purchase visibly says not saved","pack failed store remains pending","pack visibly says not saved","unpack failed store remains pending","unpack visibly says not saved","Shared error boundary exists"],"observations":[{"case":"scratch","pending":false,"save_calls":1,"warning":false},{"case":"home_setting","pending":false,"save_calls":1,"warning":false},{"case":"reset_coach","pending":false,"save_calls":1,"warning":false},{"case":"seen_coach","pending":false,"save_calls":1,"warning":false},{"case":"purchase","pending":false,"save_calls":1,"warning":false},{"case":"pack","pending":false,"save_calls":1,"warning":false},{"case":"unpack","pending":false,"save_calls":1,"warning":false}],"scope":"Actual six caller sites plus both pack directions. Real profile/settings mutations and real housing upgrade/price. Pack domain service stubbed; caller behavior is under test. Empty Host has no canvases; full production liveness is a separate check."}
```
29checks/11failures. All seven branches (six sites, pack and unpack separately) attempted saving but retained no pending status; purchase/packing showed no unsaved warning.

## Change

scripts/ui/foundation_main.gd: all six callers use one checked persistence boundary. Repeated failures log once per pending store. Profile/coach/settings retain their state and retry on the next change without a modal. Home purchases and pack/unpack retain the new paid state, show a plain unsaved warning in the actual popup and collection header, and retry the current Meta store every3seconds. A successful save removes pending status/warnings and stops the retry chain. Retry defers across active response/Rourke transactions. Existing run-autosave cadence, schemas, money rules, canvas processing and autonomous animation are unchanged.

Two focused source tests cover all callers, repeated failures and later changes; a full production Main/Meta Home check uses an actual private filesystem temporary-path directory to reject DurableStore's write, then removes only that empty owned fault and waits for the real timer. The save override only counts calls and always delegates to production save.

## After

Actual expanded caller test:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_14_IGNORED_STORES {"checks":41,"failures":[],"observations":[{"case":"scratch","pending":true,"save_calls":1,"warning":false},{"case":"home_setting","pending":true,"save_calls":1,"warning":false},{"case":"reset_coach","pending":true,"save_calls":1,"warning":false},{"case":"seen_coach","pending":true,"save_calls":1,"warning":false},{"case":"purchase","pending":true,"save_calls":1,"warning":true},{"case":"pack","pending":true,"save_calls":1,"warning":true},{"case":"unpack","pending":true,"save_calls":1,"warning":true}],"scope":"Actual six caller sites plus both pack directions. Real profile/settings mutations and real housing upgrade/price. Pack domain service stubbed; caller behavior is under test. Empty Host has no canvases; full production liveness is a separate check."}
```
Initial identical29-check command after:29/0; expanded41/0. The pack domain operation is stubbed in that caller fixture; actual housing purchase/price, profile and settings mutations run through their base services. Empty Host fixture has no canvases and is not animation evidence.

Full production UI/timer/disk command:
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/aud061_meta_store_retry_ui_check.gd
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

BTH support: Home upgrade save failed (12); retry pending.
AUD061_14_META_RETRY_UI {"checks":17,"facts":{"collection_warning":"Your shelves are empty. Beat a route to bring home bags and permanent keepsakes.\nNot saved yet. Keep this game open; saving will retry.","gold_before":10000,"gold_saved":9940,"purchase_warning":"Home upgraded to Motel Room.\nNot saved yet. Keep this game open; saving will retry.","recovered_summary":"Your shelves are empty. Beat a route to bring home bags and permanent keepsakes.","save_calls":2,"upgrade_price":60},"failures":[],"scope":"Actual production Main, Meta Home, popup and collection header, real timer and final DurableStore disk write/load. Synthetic QA gold supplied through actual add_gold; actual filesystem directory fault blocks the temporary write and is removed before retry. Save override only counts calls and always delegates to production save. No processing/rendering disabled."}
```
17checks/0failures, real write error12. Actual popup and collection Label controls are visible in the production scene; recovery clears both pending state and visible collection warning without new input. Fresh Meta service loads exact gold9940 and upgraded Motel Room after a60-gold purchase from10000. No second charge. Synthetic QA gold was supplied through actual add_gold; this is not an organically earned wallet. No game processing/rendering disabled. This is native visible-control evidence, not browser pixel evidence.

Retained intermediate UI12/0 used an error-return boundary with real final disk save. First physical17-check attempt had one incorrect fixture path assertion (user:// differed from the launcher's explicitly admitted Meta path); actual write rejection/recovery all passed. Corrected gate now requires BTH_QA_RUN_DIR containment on non-C storage and exits before any fault creation if invalid. Final17/0 above.

Animation-liveness command res://scripts/tests/animation_liveness_without_pointer_check.gd: **PASS**. Smoke4stages pass/7fail versus baseline4/7. Content25/runtime16 exact inherited assertion sets; normalized new stderr errors []. Performance retains9old failures versus baseline10. Actual suite command: powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages. Exit1, no timeout, active processes0. Baseline Python180/0. Ledger reconciliation1683inherited errors/52tasks, zero new AUD061/QOL findings. Fixed reference time and command are the same as baseline; current owner timestamps are actual current time. Raw commands, job/launch manifests and full logs in evidence/AUD061-14_20261111/.

## NEXT

Initial delivery **d7034cf137805e6af325adbac988bfcd2597347b** containing bc1ee0c9d1e4c8c161c64aa3da95ee08a0ffc4d6 promoted2026-11-11T07:08:45Z, tree1fa28f4dc1f1596c90605aab3991a19f80bffe35, archive5ed4de9896f21d0ef7c159a1eaf4f4bcbc59edc77712d6e25799cbe29c113128. Exact10assetsPASS; startup clean, pageerrors0/consolewarnings-errors0. This is **not final accepted delivery** because visible verification found stale Result feedback after recovery.

First browser fixture setup wrote outside the actual app_userdata folder; Home gold0 confirmed it was not loaded. Retained as unaccepted, no purchase/fault attempted. New fresh-profile corrected setup loads same-candidate native Meta fixture (synthetic gold9940/Motel Room, SHA256dada2add223fdef7b9d79f45ee27a81cb62ae06fbb5607e4e26ae5c3fcd710c6); normal Upgrade Sign Buy250 changes to Apartment/gold9690. Actual owned Meta .tmp directory rejects write; popup and Result clearly say not saved. Removing only that empty fault allows timer recovery, clears popup warning and leavesgold9690 unchanged. Top Result retained old warning; screenshots08/10 demonstrate it. This is a seeded new QA profile, not an organically earned wallet or migrated active/old profile. No game script/scene/path overrides.

Follow-up: one targeted _refresh_environment_result_feedback call after recovery, plus two assertions in actual UI fixture. Same native UI command before:19checks/1failure (Actual visible Result clears recovered warning); after:19/0, recovered_result=Collection changes saved. Exact paid gold9940 retained. Caller41/0 and livenessPASS again. Raw logs and screenshots retained. Final Smoke4pass/7fail matches baseline stage outcomes and content25/runtime16 exact inherited sets. Its performance stage has10failures versus baseline10, with an extra idle Blackjack draw-p95 timing12.57ms against5ms. Original failure is retained. Same-source bounded repeat uses the identical probe, pinned Godot, verbose mode, RUNS0/FRAMES120/RESOLVE24/seedCHECK-GODOT-PERF, same12percentCPU/2GiB cap: Blackjack2.914ms/13drawsamples (floor8), only9inherited failures. Historical initial-audit-source control3.277ms/12samples is prior evidence, not a new control run. Earlier paired01/02 and QOL03 also observed this nonreproduced timing category. No threshold,cadence,liveness floor,source or limits changed for the repeat. No sustained rendering regression is established; broad performance/native-solver qualification remains open. Full reports and performance_controls.json retained. No timeout/active processes0. Final NEXT delivery pending. No manual deployment.
