# AUD061-10 — Crew bankroll economy refresh

Specification: [BTH_0.6.1_audit_work_orders.md](../todo/BTH_0.6.1_audit_work_orders.md). Started from `75f90ca841dce23b7d890079074a7bde686be600` (AUD061-09 delivery receipt; runtime matches deployed93f3df02).

## Before

Pinned Godot4.6 `--headless --path E:\CodexQA\BTH\workspaces\aud061-20261110 --script res://scripts/tests/aud061_crew_bankroll_contract.gd`. Guarded fresh synthetic native profile, `aud061-10-before-corrected-20261110`, exit1. The initial11-check contract uses the actual abort, Whale exposure and getaway settlement methods with synthetic state and the fixture-owned host capability; no historical/player save or content change.

Actual output,11checks/3failures:

```text
AUD061_CREW_BANKROLL {"checks":11,"failures":["abort immediately refreshes economy","Whale immediately refreshes economy","getaway immediately refreshes economy"],"observations":[{"case":"abort","cash":35,"economy":"stable","result":{"cost":25,"message":"The crew folds the map. Preparation costs $25; the run stays yours.","ok":true,"run_ended":false}},{"case":"whale","cash":228,"economy":"volatile","result":{"message":"The front door becomes a race. The money keeps up.","ok":true,"outcome":"out_hot","payout":227,"resolved":true}},{"case":"getaway","cash":721,"economy":"volatile","expected_payout":720,"ok":true}]}
```

The initial probe also incorrectly expected the normal Whale low-score ending to pay zero. It actually clamps to the authored minimum. The corrected probe selects the existing hidden closed branch, which really pays zero. Both before outputs are retained; product source was unchanged between them.

## Change

Only three production lines in `crew_run_facade.gd`: abort calls `change_bankroll(-paid, true)`; the two payout paths call `change_bankroll(payout, true)`. This invokes the existing economy refresh while retaining deferred zero-wallet termination. No payout formula, cap, ending, RNG, item/scenario content, save format or animation scheduling changed. `aud061_crew_bankroll_contract.gd` asserts all three immediate economy states, exact existing monetary consequences, abort remaining active, and both zero-payout paths reaching their existing ending without an early bankroll failure.

## After

Initial after run of the same command, guarded run `aud061-10-after-20261110`, exit0:

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_CREW_BANKROLL {"checks":11,"failures":[],"observations":[{"case":"abort","cash":35,"economy":"volatile","result":{"cost":25,"message":"The crew folds the map. Preparation costs $25; the run stays yours.","ok":true,"run_ended":false}},{"case":"whale","cash":228,"economy":"growing","result":{"message":"The front door becomes a race. The money keeps up.","ok":true,"outcome":"out_hot","payout":227,"resolved":true}},{"case":"getaway","cash":721,"economy":"growing","expected_payout":720,"ok":true}]}
```

## Test comparison

Initial focused11/0 versus before11/3; strengthened final13/0. All focused jobs joined with zero active processes. Smoke **4stages pass/7fail**, matching baseline; content25/runtime16, parser/UI/geometry failure sets match. Performance has9error lines versus baseline10, with zero new normalized errors. Actual command: `powershell.exe -NoProfile -File tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -ReportDir <guarded-evidence>/smoke -VerboseStages`, exit1/no timeout. Full comparison: `evidence/AUD061-10_20261110/smoke_comparison.json`. Baseline Smoke4stages pass/7fail, Python180/0 and liveness PASS are in [baseline](AUD061_baseline_2026-11-10.md). No canvas, pause or performance code changed. Full outputs and storage/launch receipts are retained under `evidence/AUD061-10_20261110/`.

## NEXT

Pending code/ledger commits and existing-pipeline promotion; final-source focused checks and Smoke comparison complete. Immediate economic_state is a model property verified natively; exact NEXT startup remains to be checked. No native solver, broader heist gameplay route or personal-save acceptance is claimed.

The final contract additionally observes direct `fail_run` calls so an intermediate zero-wallet failure cannot be hidden by the subsequent ending. Final run `aud061-10-after-timing-20261110`, same command, exit0; actual output follows. Both zero-payout paths recorded0premature_failures,0cash,insolvent and ended.

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

AUD061_CREW_BANKROLL {"checks":13,"failures":[],"observations":[{"case":"abort","cash":35,"economy":"volatile","result":{"cost":25,"message":"The crew folds the map. Preparation costs $25; the run stays yours.","ok":true,"run_ended":false}},{"case":"whale","cash":228,"economy":"growing","result":{"message":"The front door becomes a race. The money keeps up.","ok":true,"outcome":"out_hot","payout":227,"resolved":true}},{"case":"getaway","cash":721,"economy":"growing","expected_payout":720,"ok":true},{"case":"whale_zero","cash":0,"economy":"insolvent","premature_failures":0,"status":"ended"},{"case":"getaway_zero","cash":0,"economy":"insolvent","premature_failures":0,"status":"ended"}]}
```
