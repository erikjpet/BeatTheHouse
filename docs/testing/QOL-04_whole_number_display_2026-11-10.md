# QOL-04 — Whole-number display after Continue

Started from main **28cc9bf93d8201bd5d9ef43904be9845a6d9dc2e** (QOL-03 delivery receipt); runtime NEXT49f0b2931b14ac139273b4ec54166fa709f7c21a. Specification: [audit work order](../todo/BTH_0.6.1_audit_work_orders.md#qol-04--loaded-numbers-can-render-as-20).

## Before

Approved E-root/capped fresh profiles; pinned Godot4.6.stable.official.89cea1439. Command(same before/after):
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/qol04_whole_number_display_check.gd

The test opens each of11 normal Practice hosts, calls production SaveService.save_run directly, calls production Continue, reopens that game and captures its production renderer text across scheduled frames plus the surface_state_labels resume model. Wallet/RNG are checked. Processing/autonomous animation remain enabled. Loaded Baccarat squeeze drawing also uses a JSON-parsed numeric card and checks no card mutation.

Actual pre-change final output:
```
QOL04_SQUEEZE ["2.01"]
QOL04_WHOLE_NUMBER {"checks":80,"failures":["craps loaded whole-number labels: [\"0.0\"]","Loaded squeezed-card rank: [\"2.01\"]","Shared whole-number formatter exists"],"games":11}
```
The actual Craps surface_state_labels resume model contained0.0(Energy); this is model text, not a claim that the current Web layout draws that Energy field; numeric squeeze rank emitted2.01 instead of21(the suffix is the existing suit representation). First draft of the new test had a parser error calling Object reflection on the Script class; corrected to instance reflection before production changes. Raw output retained. Initial single-frame capture missed retained Coin Pusher chrome; final before/after captures the union after Continue, including QUARTER FALLS counters. No production scheduling change.

## Change

PlayerText.whole_number formats integer-valued JSON floats at the display boundary. Integers keep exact strings; fractions, nonfinite/out-of-int64 floats and textual codes pass through. Uses cover Craps point/energy/dice, squeezed Baccarat rank, Bar Dice numeric labels, video-poker paytable, slot feature counts/payouts, shared stake/chip-stack and whole-second timer text. Zero padding and deliberately fractional PEEK precision remain. Existing safe %d/int/domain card-rank renderers remain. Files and sweep scope in display_sweep.json.

Display-only: no save/schema/type migration, rules/economy/RNG/authority, item/scenario data, cadence or input scheduling changes.

## After

Actual final output:
```
QOL04_SQUEEZE ["21"]
QOL04_WHOLE_NUMBER {"checks":88,"failures":[],"games":11}
```
Before80checks/3failures; after88checks/0failures. Eight formatter vectors run once the formatter exists(the missing formatter was an explicit failing assertion before). All11 native SaveService/Continue/reopen/wallet/RNG checks pass. Practice UI Save/Load are intentionally disabled; the native test explicitly calls the production service/host APIs. The normal-run browser check below covers actual enabled player Save/Load controls. All11 observed resume samples have zero decimal-integer labels; full strings retained. Drawing preserves the squeeze fixture. Vectors include2.0,zero,negative,integer max,fractional1.25,A and00.

Existing saved-dice regression: res://scripts/tests/craps_saved_dice_labels_check.gd,24checks/0failures.
No-pointer animation: res://scripts/tests/animation_liveness_without_pointer_check.gd,PASS.
Adjacent copy: res://scripts/tests/fixsweep06_1_player_text_contract.gd,PASS(no total printed).
Focused jobs exit0/no timeout/zero active processes. Commands/logs/storage manifests/launch gates retained under evidence/QOL-04_20261110/.
Smoke4stages pass/7fail versus baseline4/7. Content25/runtime16exact old assertions; normalized new stderr errors: []. Performance9inherited failures versus baseline10; no new category. Missing locked native Coin Pusher solver remains an inherited qualification limit. No timeout, zero active processes. Full suite command: powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages. See retained smoke_comparison.json. Baseline4stages pass/7fail,content25/runtime16old assertions; baseline Python180/0.
Broader outcome/feature/old-save coverage not claimed; AUD061-17 follows later.

## NEXT

Verified **d258f3dc14866f2e8bfd9ee35e3e707507acea95**, containing QOL-04 code **2bcea35cc68076235d51e88f4887abd66bad2c51**, tree d27886bfff97c7331bec61e1b7c319b682524975, archive a1467fabc7a31bdf753d6a419411444402cc4850b8bffb5143aa2e876fe91003. Existing watcher promoted2026-11-11T05:25:13Z,phasecurrent,errornull. Exact metadata/REF/HTML/JS/PCK/native GET hashes plus engine HEAD length/MIME/pins:10/10PASS; ordinary /dev/entry resolves to this identity.

Fresh approved browser profile, unmodified served build. Startup and Games page clean; Craps Practice screen shows whole-number controls. Its Save/Load controls are disabled by design, so no Web Practice save was claimed. Switched through Main Menu to a normal Daily Challenge, traveled House->Gas Casino, opened Slot, used enabled Menu Save. Save succeeded and closed the menu. An immediate click at Load's old coordinates therefore did not invoke Load; reopened Menu then used actual enabled Load. Clock restored to the saved1:45 state, returned to the room; re-entered Slot. Visually observed bankroll46,heat1,bet2,feature138,card symbols10 and zero-result text without trailing .0. Screenshots00startup,01Games,01click/02click,11click/13click/15click/16click/18click all inspected. Browser errors0,consolewarnings/errors0,jobexit0/no timeout/zero active processes after close.

This deployed sample proves normal Save/Load and visible restored numbers for Slot; it does not prove all11Webgame Continue branches or a live squeezed-card phase. Native88/0 covers all11 service/host resume samples plus the loaded squeezed-card draw; broader play phases belong to AUD061-17. No script/scene/path override or personal profile was used.

The earlier pre-change browser attempt reached only startup/Games. It consumed an old same-SHA stop command; copied visual_review text in that raw result is not accepted as evidence for this attempt. Retained attempt-assessment.json explains it. The helper now starts its inbox cursor at the prior command; corrected Node syntax check passed before the d258 run. The final d258 run's own screenshots/actions and explicit review are the accepted Web evidence.

Ledger reconciliation before push:1683inherited errors across52existing tasks, identical baseline; zero findings for AUD061/QOL-04. Parent remains Open with11other orders to execute.
