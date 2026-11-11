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
73 checks / 0 failures: five menu routes ask; primary bytes and current RunState remain untouched before consent; default focus is Keep saved run; default Enter, Escape and actual cancel-button signal retain bytes; explicit start proceeds once; duplicate confirmation cannot start twice. A real loadable backup alone also prompts and survives cancellation. No save and a deliberately unreadable current-build fixture start immediately. Mandatory automatic tutorial and both tutorial/ordinary finished-report New Run remain immediate.

First candidate test36/2 is retained: alternating cases reopened the dialog before the previous native button event finished closing it. Test fixture now waits actual frame boundaries between independent interactions; no assertion was removed or weakened. Intermediate four-route check56/0, expanded final73/0. This was a QA sequencing correction, not a waived game failure.

Animation liveness without pointer input: PASS. Required Smoke command:
`powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages`.
Observed after4pass7fail versus baseline4/7; content25/runtime16 identical old sets; performance9 inherited failures versus baseline10; normalized new stderr errors []. Stage/error comparison is retained in evidence/QOL-01_20261111/smoke_comparison.json. Initial baseline4pass7fail, content25/runtime16 and ten performance failures. Ledger1683 inherited errors/52tasks, zero AUD061/QOL findings. Fresh E-only profiles; unchanged12%CPU/2GiB Job, storage budget/reserve, no active-profile migration. Full commands, raw outputs and gates retained.

## NEXT

Pending finished task push and exact existing-pipeline served identity, startup and rendered confirmation/cancellation verification.
