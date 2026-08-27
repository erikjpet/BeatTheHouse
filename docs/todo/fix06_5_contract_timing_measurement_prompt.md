Status: IN PROGRESS — five-run idle-host measurement predeclared; no run executed
Board row: `fix06_5` in `docs/todo/README_0_6_board.md`

# fix06_5 — Contract Suite Timing Measurement

## Purpose

Determine whether the unchanged `foundation_contracts` wall-time guard is
representative on an idle host. This is a measurement row, not authority to
change the baseline, multiplier, cap, runner, tests or product.

The exact measurement source is commit
`e75f2c3d7f283d75d7faa44ac10694784b63bb25`, tree
`099eeb0233b0d468f52aa0bc196dee4144dac536`. All five attempts must run from
that same clean tracked tree. The machine-readable copy of this contract is
[`docs/plans/evidence/fix06_5/predeclaration.json`](../plans/evidence/fix06_5/predeclaration.json).

## Preserved historical evidence

- The guard remains baseline `153.594s` times multiplier `1.50`, cap
  `230.391s`, as committed in `tools/check_godot.ps1`.
- A live, dirty review tree completed the native-backed Contract stage in
  `213.643s`; a byte-identical tree later measured `231.531s`. Both ran amid
  parallel agents/native work and are contextual evidence, not members of the
  new idle-host series.
- Accepted `fix06_4` head `91e050bf` retained `261.805s`; post-land main
  `9a2022ae` retained `261.650s`. Functional assertions were green and the
  exact supplied native addon was recorded.
- Exact main `7c748f5b` completed all 16 Contract checks with zero functional
  failures or stderr and `native_v3`, but retained `259.847s > 230.391s`.
- Every historical red and green remains evidence. None may be deleted,
  relabeled as an idle run, or used to replace one of the five attempts below.

These observations motivate the measurement; they do not by themselves prove
that the baseline is stale or authorize a cap change.

## Locked environment and identities

Before attempt 01, record and preserve the following once, then verify them
again before every later attempt:

1. exact Git HEAD/tree above and an empty `git status --short
   --untracked-files=no`;
2. Windows host name, OS build, CPU model/logical count and installed memory;
3. Godot executable absolute path, version output and SHA-256;
4. ignored native addon identity and successful `native_v3` qualification.

Use the accepted ignored addon layout, without rebuilding it:

- `addons/coin_pusher_native/coin_pusher_native.gdextension` SHA-256
  `72EE625D61257DCBD65400E57F39077EADEDD3C265C25C83F68BC2F8EFBC9861`;
- its `.uid` SHA-256
  `F606704CBF202403DE82CBFD19B4160889346206EAD1D96E86C6A452B0C3A06A`;
- both accepted native DLL names SHA-256
  `1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5`.

If the layout or any identity differs, do not start the series. Record the
precondition failure and restore the exact accepted ignored layout; never build
or swap binaries between attempts.

## Idle-host eligibility

Each attempt begins only after all of these conditions pass:

- no other Godot process for this project is running;
- no project test, import, export, capture, native compile or other timed job is
  running anywhere on the host;
- the previous attempt has ended and at least two minutes have elapsed;
- a fresh 60-second Windows total-CPU sample (`Get-Counter
  '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 60`)
  has median at most 10% and nearest-rank p95 (sorted sample 57 of 60) at most
  25%; preserve every raw sample;
- AC power state and the Windows power plan are unchanged from attempt 01.

If eligibility is red, wait and repeat the precheck. A red precheck is retained
but is not a measurement attempt. Once a numbered attempt starts, it is never
discarded, repeated or replaced, even if it fails or is interrupted.

## Exact five-attempt method

Run attempts 01 through 05 serially, in that order, with no sixth attempt:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_godot.ps1 `
  -RequireGodot -Suite Contract -FoundationSuite contracts -TimeoutSec 600 `
  -ReportDir .tmp\fix06_5_contract_timing\run_0N
```

Replace `0N` only with `01`, `02`, `03`, `04` or `05`. Do not add
`-AllowConcurrentGodot`, `-NoImport`, change the timeout, or change any source,
runner setting or host identity between attempts.

For every attempt preserve the full report directory and record: start/end
timestamp, precheck data, command, process exit, all stage durations,
`foundation_contracts.duration_sec`, budget metadata, all 16 functional check
results, stderr issues, timeout state, solver backend and all identity hashes.
Report all five in attempt order, not sorted order.

## Eligibility and decision rule

A numbered attempt is timing-eligible only when it uses every locked identity,
reaches the Contract result, completes all 16 functional checks with zero
assertion/script/stderr failures, does not time out and identifies
`native_v3`. A timing red remains eligible only when the
`foundation_contracts` stage itself records `exit_code = 126` and that unchanged
stage-time cap is the sole failed-stage reason. The outer `check_godot.ps1`
wrapper exit `1` is timing-eligible if and only if that sole stage-126 budget
result caused it while all functional, stderr, timeout and identity predicates
above remain green. No other nonzero stage or wrapper exit is timing-eligible.

- If any of the five attempts is not timing-eligible, preserve it and classify
  the five-run timing conclusion as **INCONCLUSIVE**. Route the functional,
  identity or host interruption separately; do not substitute another run.
- If all five are eligible, compute the median of their exact
  `foundation_contracts.duration_sec` values: sort ascending and use value 3
  of 5. Do not round before comparison.
- Median `<= 230.391s`: the committed guard is **SUPPORTED BY THIS SERIES**.
  Individual reds remain reported as variance; no baseline/cap change follows.
- Median `> 230.391s`: record **STALE-BASELINE CANDIDATE** and prepare an
  owner-visible rebaseline proposal containing all five values, min/median/max,
  date, host and method. This row still does not change the baseline or cap;
  owner authorization, independent review and a separate committed decision
  are required first.

Do not call the baseline stale before five eligible results exist. Never select
only passing runs, average away a functional failure, raise a cap to clear the
series, or rerun until green.

## Boundaries and completion

Measurement execution may write only ignored evidence under
`.tmp/fix06_5_contract_timing/` plus later documentation records. No product,
test, runner, baseline, multiplier, cap, schema, migration, RNG, golden, native
source or build change belongs to this row. Do not perform visual capture,
remote, release, version, publish or package actions.

After the five attempts: commit the complete honest result record, obtain
independent implementation/evidence review, land only the accepted docs/evidence
payload, repeat a proportionate post-land documentation/evidence check and then
update the board and ledger. The row remains IN_PROGRESS until those steps are
complete.
