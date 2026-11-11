# QOL-01 — Confirm saved-run replacement

Started from main 28ece77b93a808c48ddd3388d82867fe965aba4b (AUD15 receipt); preceding accepted NEXT3b36a9c3957fe4b4484d8584d16e971fc743ef93. [Specification](../todo/BTH_0.6.1_audit_work_orders.md#qol-01--start-new-run-replaces-a-saved-run-with-no-confirmation).

## Before

Same production-scene focused command before/after (the final check additionally covers Replay Lessons, backup-only and unreadable saves):
`Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/qol01_saved_run_replacement_check.gd`

Actual original output:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

{"checks":18,"failure_count":8,"failures":["_on_start_pressed asks before replacement","_on_start_pressed keeps current run before consent","start_generated_foundation_run asks before replacement","start_generated_foundation_run keeps current run before consent","start_meta_quick_run asks before replacement","start_meta_quick_run keeps current run before consent","start_daily_challenge_run asks before replacement","start_daily_challenge_run keeps current run before consent"]}

```
18 checks / 8 failures. All four original menu starts replace the active run immediately without a prompt. At the immediate observation the old on-disk primary still matches, because the first autosave is queued; the test does not claim that it already wrote twice.

## Change

scripts/ui/foundation_main.gd and foundation_screen_builder.gd: one ConfirmationDialog, exact requested prompt, Start new run / Keep saved run choices. All configured/generated/Daily/meta quick/optional Replay Lessons menu starts pass a one-shot Callable through the same loadable-save guard. Repeated requests do not replace a pending action; confirm clears it before dispatch; cancel/Enter-default/Escape clear it without starting. Shared modal focus scope keeps both choices reachable and restores the previous scope. Explicit accept handling honors focused choice instead of the dialog's destructive default.

Automatic first tutorial and already-finished run-report continuation use their existing immediate entry points. Primary Continue still loads. No save format, content, autosave cadence, pause/render scheduling or pipeline setting changed. Optional Replay Lessons was included after the caller search showed another menu route into start_foundation_run; mandatory tutorial remains exempt as specified.

## After

Actual final output:
```
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

{"checks":73,"failure_count":0,"failures":[]}

```
Initial73 checks / 0 failures (before duplicate root/window-dispatch coverage was added): five menu routes ask; primary bytes and current RunState remain untouched before consent; default focus is Keep saved run; default Enter, Escape and actual cancel-button signal retain bytes; explicit start proceeds once; duplicate confirmation cannot start twice. A real loadable backup alone also prompts and survives cancellation. No save and a deliberately unreadable current-build fixture start immediately. Mandatory automatic tutorial and both tutorial/ordinary finished-report New Run remain immediate.

First candidate test36/2 is retained: alternating cases reopened the dialog before the previous native button event finished closing it. Test fixture now waits actual frame boundaries between independent interactions; no assertion was removed or weakened. Intermediate four-route check56/0, expanded final73/0. This was a QA sequencing correction, not a waived game failure.

Animation liveness without pointer input: PASS. Required Smoke command:
`powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages`.
Observed after4pass7fail versus baseline4/7; content25/runtime16 identical old sets; performance9 inherited failures versus baseline10; normalized new stderr errors []. Stage/error comparison is retained in evidence/QOL-01_20261111/smoke_comparison.json. Initial baseline4pass7fail, content25/runtime16 and ten performance failures. Ledger1683 inherited errors/52tasks, zero AUD061/QOL findings. Fresh E-only profiles; unchanged12%CPU/2GiB Job, storage budget/reserve, no active-profile migration. Full commands, raw outputs and gates retained.

## NEXT

First promotion a398302308be0f3f2380620450ba8f6111dfcfd7 (code b0cb51dfaf2cea0cf2cb61c42d693cca4b57b434), tree a66021737262fcd90f4bc57a7b50b91911746d48, archive4e9eb6ff81b0c53557734f610c7c684891f67a8700d80ffc394741c9d199d102: ten served-asset checks PASS and clean browser startup. This is NOT accepted QOL delivery: rendered default/cancel worked but Tab/Shift+Tab moved focus twice. All screenshots and raw output retained. Browser job0/pageerrors0/console0 did not override visual failure. Fresh Daily profile first entered the mandatory-tutorial exemption as specified; ordinary Skip Lessons then established the normal completed-profile boundary, without a profile override. Normal Run Setup prompt exact wording and Keep saved run focus then appeared. Enter, Escape and pointer cancellation retained primary100307bytes SHA2569f50fec672237d65f5b84866af552219d6b8cf32b2fafa7af36e2127e88d8c1b; explicit pointer replacement entered Back Alley with bankroll100.

Focused root/window Tab reproduction83checks/5failures (one per route). Final correction: root Main input returns while this embedded confirmation Window is visible, leaving its existing window_input handler the sole navigation owner. No shared ModalFocusScope behavior was changed. Same83checks/0failures. Final liveness PASS. Final Smoke4pass7fail versus initial4/7; content25/runtime16 exact old sets; performance10 inherited failures versus baseline10 (idle Coin Pusher47.67ms above45ms is also a baseline category); normalized new stderr errors []. No timeout, active processes0. Corrected exact NEXT delivery pending.

Final source command remains the focused production-scene check above: 83checks/0failures. The added ten checks exercise root+Window Tab and Shift-Tab dispatch across all five routes; the other73 assertions remain. No skip/waiver or shared-focus behavior change.

## Native Tab traversal correction

The second promoted build4ca0bd470a2fa39c2a38e5bcbb846831f4958a44, tree9016df827bf3dccf30a04819339637c54fea8d08, archiveccafee60e95385514058ff0ad12f26da7926d224d59b7234456642a5d4b6deea passed all ten served-asset checks and clean startup, but was also NOT accepted for QOL completion. Real ArrowDown/ArrowUp now moved choices once and Enter honored the selected safe choice; Tab still wrapped back. On that same build the existing delete-save ConfirmationDialog moved Delete Run -> Cancel once with Tab; Escape canceled it without deleting. The comparison isolates a difference in the new Window input handler, rather than establishing a browser-wide problem. Raw shots and job0/pageerrors0/console0 are retained with the explicit UNACCEPTED assessment.

The83-check test now sends actual Input.parse_input_event Tab/Shift-Tab press and release events through the full engine GUI and waits real frames before inspecting focus. The earlier synthetic root/window-only dispatch omitted native GUI traversal and was insufficient for this claim. No assertions were removed or weakened. This stronger same command reproduced83checks/5failures (one per route). Its raw output is retained.

Final narrow production correction: new confirmation window_input returns for KEY_TAB press/release, allowing the same built-in ConfirmationDialog button-row traversal used by delete-save. Root input continues to leave this Window sole ownership. Custom arrow navigation, safe Enter and Escape remain. Shared ModalFocusScope and other dialogs were not changed.

Same stronger focused command after:83checks/0failures. This verifies actual frame-settled Tab/Shift-Tab on all five routes, plus the other73 original cancellation, byte preservation, explicit-start and exemption assertions. Final Smoke:
4pass/7fail versus baseline4/7; performance stderr failures9 versus baseline10; normalized new stderr errors []. Content25/runtime16 retain exactly their old failure sets. Full comparison is linked above.
No timeout; active processes0. Previous liveness PASS covers unchanged scheduling and pause logic; this four-line native Tab ownership change does not alter either. Final corrected NEXT verification remains pending.
