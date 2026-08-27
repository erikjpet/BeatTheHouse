Status: TODO / ROUTED — nonblocking measurement-classification defect
Board row: `fix06_17` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_17: Scratch resolve tail-timing classification

Work in `D:\Projects\Beat-The-House` from the exact current `main` after
`fix06_13` lands, or in another PM-approved idle-host window that cannot
contaminate an in-flight row's timing. Read the current landing contract, the
performance probe, this routing record and all retained evidence before acting.

## Retained first result — do not replace or hide it

The first native performance run on the current-main `fix06_13` integration
candidate measured exact head
`cce1c8dfee30e4503e70352da7fbdbd98e675687` on 2026-08-27. It used Godot
4.6 stable, eight runs, 120 frames per surface, 48 resolve samples and seed
prefix `FIX06-13-CURRENT-MAIN-CCE1C8DF`. The descriptor-selected Windows
backend was `native_v3`, DLL SHA-256
`31FF8C0D74D2C48F7CE807A06F6862246F52AA73443CC69BE685C76011A2B8A8`.

The report is retained at
`.tmp/fix06_13_current_main_cce1c8df_native_performance_actual_1/foundation_performance_probe_report.json`,
SHA-256
`4195D724A1189886CC7C961F4BDEE4DF489804A9720630FD20191B94206090EA`.
Its stdout/stderr SHA-256 values are
`88AC687719B232B53EF0BC6C16CC9128512ADD5D52DD8D4FF0CF7F028261869C` /
`E7AA990C712A5038C8C292D2855CAC5BAEFAFCB68E0CFF811EC23B71971DAFA0`.
The sole failure was Scratch Tickets `buy_scratch_ticket` resolve maximum
`12.046 ms` against the locked `6.000 ms` cap. The same 48-sample observation's
average and p95 were green at `2.34789583333333 ms` / `3.734 ms` against
`3.000 ms` / `5.000 ms`.

Every Coin Pusher measurement owned by `fix06_13` was green on `native_v3`:
raw solver p95 `3.493/12.000 ms`; idle draw p95 `2.973/5.000 ms` with liveness
`50/8`; DROP frame/draw/resolve `9.505/4.166/6.873 ms`; carriage
`8.344/4.284/1.274 ms`; skill stop `8.938/4.327/1.267 ms`; skill release
`8.140/3.962/1.266 ms`; COLLECT `9.331/4.102/1.946 ms`, against locked active
caps `22/7/16 ms`. Every active window observed physical motion and positive
liveness; full-snapshot calls and host fallback counts were zero. The report
contains exactly one failure, so this unrelated Scratch result does not block
`fix06_13` or authorize another run of its native or shipped-Web gates.

## Current classification

The retained evidence supports **measurement/tail-latency variance, not a
reproduced Scratch product regression**. Historical retained runs include
isolated Scratch maxima of `12.652 ms` and `12.621 ms`, while the five-run
classification series after the accepted renderer work measured maxima
`4.235/4.093/4.102/3.975/3.831 ms`, and another five-run series measured
`4.530/4.352/4.570/4.351/4.330 ms`. The current average and p95 are green and
only one of 48 samples produced the max red. The recurring isolated spike is
still a real guard failure and therefore remains routed here; it is not waived
or reclassified green.

## Required work

1. Before measurement, predeclare one exact source head, one Godot identity,
   one native identity, objective idle-host eligibility and five serialized,
   non-replaceable runs of the unchanged performance probe.
2. Preserve and report every setup failure, run, average, p95, maximum, raw
   exit, stderr issue and host-eligibility result, including slow ones.
3. If the five-run evidence does not reproduce the tail breach, close this as
   timing variance while retaining the `12.046 ms` red. If it reproduces,
   profile the real `buy_scratch_ticket` resolve path and implement the smallest
   output-identical product optimization, followed by a new independently
   reviewed exact-head five-run series.
4. Prove Scratch rules, RNG, payouts, odds, wager math, stock/scarcity behavior,
   save/migration behavior and player-visible results are byte-for-byte or
   semantically unchanged, as applicable.
5. Obtain independent review and follow the single-PM landing loop. This row is
   complete only after it lands alone and its exact post-land documentation or
   product gates pass.

## Locked boundaries

- Do not raise, scale, reinterpret or waive the Scratch `3/5/6 ms`
  average/p95/maximum budgets. Do not weaken, filter, delete or reduce samples
  in any test.
- Do not rerun until green, discard a slow result, substitute a different
  source head, or use `fix06_13`'s locked Web run to investigate this row.
- Do not change RTP, EV, payouts, odds, wager math, RNG, economy values, stock
  quantities/scarcity, schema or migration behavior.
- This route is nonblocking for `fix06_13`; Coin Pusher's exact-head native
  scope is green in the retained report. Any future Scratch work lands as its
  own row after independent review.
