# QOL-02 — visible autosave failure

Specification: [BTH_0.6.1_audit_work_orders.md](../todo/BTH_0.6.1_audit_work_orders.md). Started from `4a53053c1533a117ef4025e8e50e2be69e6c428d` (AUD061-10 delivery receipt; runtime matches deployedbcd22342).

## Before

Pinned Godot4.6 `--headless --path E:\CodexQA\BTH\workspaces\aud061-20261110 --script res://scripts/tests/qol02_save_warning_contract.gd`, guarded fresh synthetic profile `aud061-qol02-before-20261110`, exit1. Explicit failed-state input with healthy message text still creates a healthy save icon. Real forced DurableStore failure also leaves a healthy icon, emits no first-block notice and loses all visible failure indication when a new generation becomes dirty. The failing contract records17checks/8failures:

```text
QOL02_SAVE_WARNING {"checks":17,"failures":["explicit failure changes save icon without parsing status text","failure tooltip leads with problem and is not truncated","save failure stays visible when other icons fill two-icon tray","host passes explicit failure field into HUD","first blocked failure emits a nonmodal player message","background boundary publishes warning to actual rendered HUD immediately","new dirty generation keeps warning until successful save","new blocked episode after success emits its first message"],"observations":[{"case":"explicit_failure","first_icon":{"icon":"debt","id":"debt","label":"Debt","tooltip":"Debt"},"save_icon":{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Saved run."}},{"blocked":true,"case":"host_failure","message":"Shooters gather outside the chalk while a bottle-cap signal waits on the curb.","save_icon":{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Autosave failed. Retr..."}},{"case":"recovered","rendered":[{"icon":"home","id":"home","label":"Home","tooltip":"Home: Home: tenure active."},{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Autosave failed. Retr..."}],"save_icon":{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Recovered."}}]}
```

## Change

`foundation_hud_view_model.gd` receives `save_failed` as a boolean, creates the existing danger icon with Not saving label and full problem-first tooltip, and puts it first so the existing two-icon tray cannot hide it. `foundation_main.gd` retains visible warning and first-block notice state separately from retry-generation state. New dirty/retry requests retain that warning; accepted synchronous or asynchronous success clears it. One nonmodal notice appears at the first blocked failure of an episode. `foundation_hud_bar.gd` updates only its small retained status list at warning transitions; this avoids rebuilding objective/room models at save boundaries. No save debounce, retry cap/backoff, validation, file format, canvas processing, frame cadence or modal behavior changed.

## After

Same command, final strengthened contract `aud061-qol02-after-final-20261110`, exit0. It adds four assertions for repeated notice across a new generation and actual async worker completion. An intermediate17/0 run retained a mutable reference to the rendered array in its observation record; the final test freezes that observation before the next failure. Earlier outputs remain retained. Final actual output21/0:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

QOL02_SAVE_WARNING {"checks":21,"failures":[],"observations":[{"case":"explicit_failure","first_icon":{"icon":"danger","id":"save","label":"Not saving","tooltip":"Not saving — open Run Menu to retry"},"save_icon":{"icon":"danger","id":"save","label":"Not saving","tooltip":"Not saving — open Run Menu to retry"}},{"blocked":true,"case":"host_failure","message":"Not saving — open Run Menu to retry.","save_icon":{"icon":"danger","id":"save","label":"Not saving","tooltip":"Not saving — open Run Menu to retry"}},{"case":"recovered","rendered":[{"icon":"home","id":"home","label":"Home","tooltip":"Home: Home: tenure active."},{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Recovered."}],"save_icon":{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Recovered."}},{"case":"async_recovered","in_flight":false,"rendered":[{"icon":"home","id":"home","label":"Home","tooltip":"Home: Home: tenure active."},{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Autosaved."}],"save_icon":{"icon":"save","id":"save","label":"Save","tooltip":"Autosave On · Autosaved."}}]}
```

Native console transcripts above are decoded as UTF-8/UTF-8 to preserve their actual punctuation; raw bytes are retained unchanged. The controller console uses replacement characters for those legacy bytes. Source files remain UTF-8.

## Test comparison

Before17/8; final21/0. Adjacent `res://scripts/tests/postfix06_2_reliability_contract.gd`: `POSTFIX06_2_RELIABILITY PASS` (no numeric assertion total printed). Focused `res://scripts/tests/animation_liveness_without_pointer_check.gd`: `Animation liveness without pointer input: PASS`. All owned jobs exit with zero active processes. Smoke **4stages pass/7fail**, matching baseline. Content25/runtime16 and parser/UI/geometry failure sets match; performance9error lines versus baseline10, zero new normalized errors. Actual command: `powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages`, exit1/no timeout. Full comparison in `evidence/QOL-02_20261110/smoke_comparison.json`. Baseline Smoke4stages pass/7fail, Python180/0 and liveness PASS in [baseline](AUD061_baseline_2026-11-10.md). Evidence and storage/launch gates retained under `evidence/QOL-02_20261110/`.

## NEXT

Pending code/ledger commits, existing-pipeline promotion and visible warning/recovery check. Final-source native/reliability/liveness checks and Smoke comparison are complete. No personal save, item/scenario, migration or deployment-guard change.
