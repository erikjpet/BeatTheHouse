# QOL-04 — Whole-number display after Continue

Started from main **28cc9bf93d8201bd5d9ef43904be9845a6d9dc2e** (QOL-03 delivery receipt); runtime NEXT49f0b2931b14ac139273b4ec54166fa709f7c21a. Specification: [audit work order](../todo/BTH_0.6.1_audit_work_orders.md#qol-04--loaded-numbers-can-render-as-20).

## Before

Approved E-root/capped fresh profiles; pinned Godot4.6.stable.official.89cea1439. Command(same before/after):
Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/qol04_whole_number_display_check.gd

The test opens each of11 normal Practice hosts, writes an actual save, calls production Continue, reopens that game and captures its production renderer text across scheduled frames. Wallet/RNG are checked. Processing/autonomous animation remain enabled. Loaded Baccarat squeeze drawing also uses a JSON-parsed numeric card and checks no card mutation.

Actual pre-change final output:
```
QOL04_SQUEEZE ["2.01"]
QOL04_WHOLE_NUMBER {"checks":80,"failures":["craps loaded whole-number labels: [\"0.0\"]","Loaded squeezed-card rank: [\"2.01\"]","Shared whole-number formatter exists"],"games":11}
```
The actual Craps resume status label was0.0(Energy); numeric squeeze rank emitted2.01 instead of21(the suffix is the existing suit representation). First draft of the new test had a parser error calling Object reflection on the Script class; corrected to instance reflection before production changes. Raw output retained. Initial single-frame capture missed retained Coin Pusher chrome; final before/after captures the union after Continue, including QUARTER FALLS counters. No production scheduling change.

## Change

PlayerText.whole_number formats integer-valued JSON floats at the display boundary. Integers keep exact strings; fractions, nonfinite/out-of-int64 floats and textual codes pass through. Uses cover Craps point/energy/dice, squeezed Baccarat rank, Bar Dice numeric labels, video-poker paytable, slot feature counts/payouts, shared stake/chip-stack and whole-second timer text. Zero padding and deliberately fractional PEEK precision remain. Existing safe %d/int/domain card-rank renderers remain. Files and sweep scope in display_sweep.json.

Display-only: no save/schema/type migration, rules/economy/RNG/authority, item/scenario data, cadence or input scheduling changes.

## After

Actual final output:
```
QOL04_SQUEEZE ["21"]
QOL04_WHOLE_NUMBER {"checks":88,"failures":[],"games":11}
```
Before80checks/3failures; after88checks/0failures. Eight formatter vectors run once the formatter exists(the missing formatter was an explicit failing assertion before). All11 Save/Continue/reopen/wallet/RNG checks pass. All11 observed resume samples have zero decimal-integer labels; full strings retained. Drawing preserves the squeeze fixture. Vectors include2.0,zero,negative,integer max,fractional1.25,A and00.

Existing saved-dice regression: res://scripts/tests/craps_saved_dice_labels_check.gd,24checks/0failures.
No-pointer animation: res://scripts/tests/animation_liveness_without_pointer_check.gd,PASS.
Adjacent copy: res://scripts/tests/fixsweep06_1_player_text_contract.gd,PASS(no total printed).
Focused jobs exit0/no timeout/zero active processes. Commands/logs/storage manifests/launch gates retained under evidence/QOL-04_20261110/.
Smoke4stages pass/7fail versus baseline4/7. Content25/runtime16exact old assertions; normalized new stderr errors: []. Performance9inherited failures versus baseline10; no new category. Missing locked native Coin Pusher solver remains an inherited qualification limit. No timeout, zero active processes. Full suite command: powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages. See retained smoke_comparison.json. Baseline4stages pass/7fail,content25/runtime16old assertions; baseline Python180/0.
Broader outcome/feature/old-save coverage not claimed; AUD061-17 follows later.

## NEXT

Pending finished code/ledger push and existing-pipeline promotion. Exact assets/startup and feasible deployed normal-input display check will be recorded after observation.
