# perf06_1 Performance and Platform Report

Status: qualification not yet run; this report is the live execution ledger.

Candidate custody begins from pushed `origin/main` commit `c570f2ce6fafa4212292f8b129ca08f2e9e1e954`. The binding candidate may change when the required `fix06_31` environment work lands; only the final exact pushed candidate may supply binding figures.

## Harness recovery and review

The six named harness artifacts on `origin/main` are byte-identical to `codex/perf06-final-run`: `docs/plans/perf06_1_final_runtime_runbook.md`, `docs/plans/perf06_1_static_harness_review.md`, `tools/perf06_binding_preflight.ps1`, `tools/perf06_phase_qualification_contract.ps1`, `tools/perf06_capture_quiescence.ps1`, and `tools/perf06_matrix_contract.ps1`. The stale branch was neither merged nor cherry-picked.

The historical `[UNREVIEWED]` changes `92bb16f5` and `618d0033` were read and verified on 2026-09-11. Their hostile-fixture suites pass and demonstrate rejection of nonignored untracked files, staged and unstaged changes, occupied ports, below-floor idle liveness, forged static-zero authority, missing active progress, published timing overruns, missing witness custody, wrong sequencing, and mutable evidence destinations:

- `powershell -ExecutionPolicy Bypass -File tools/perf06_binding_preflight_contract_test.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/perf06_phase_qualification_contract_test.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/perf06_quiescence_contract_test.ps1`

## Non-measurement gates

All runbook section 2 gates passed on `c570f2ce` on 2026-09-11. This includes Godot parser/import, required-matrix, budget, phase qualification, quiescence, binding preflight, allocation, Web idle liveness, Coin Pusher clock, Web prestage, Coin Pusher action diagnostics, complementary startup, run-UI deferral, backglass readability, deferred validation, Web READY snapshot, idle-liveness runtime, and Coin Pusher production static-cache checks. Total observed wall time for this local gate batch was 116.9 seconds; its output is validation only and is not binding performance evidence.

## Enforcement wiring

Pending Phase 2.

## Reduced-sample dry run

Pending Phase 3. All output will remain below `.tmp/` and will not be represented as binding evidence.

## Binding measurement method and artifact index

Pending the scheduling prerequisites and full seven-step runbook execution.

## Native, Web, and low-end matrix

No binding measurements are available yet.

## Export, startup, load, and memory

No binding measurements are available yet.

## Published budgets and liveness pairings

Pending final matrix consumption. An idle timing row will not be reported without its retained liveness counter and floor; zero animated-idle liveness is a failure.

## Optimizations

None. No product code has been changed by this row.

## Historical comparator handling

The missing like-for-like 0.5 comparators named in `docs/plans/perf06_1_measurement_prestage.md` will be labeled `no historical comparator`. They will establish 0.6 baselines and will not be called regressions or passes against invented history.

## Routed findings

None yet.

## Owner summary

No ship verdict is available until the binding three-profile matrix passes.
