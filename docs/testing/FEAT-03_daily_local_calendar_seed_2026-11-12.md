# FEAT-03 — Daily Challenge uses the full local calendar date

Date: 2026-11-12. Starting source: `fd8bb1581d4e676fb1c86229deaa7dbb3630f7e4`.
The intervening FEAT-STALE/FEAT-04 commits record documentation and delivery only.
The runtime patch is limited to the seed function and its required year binding.

## Confirmed before state

The old production function accepted only day/month and returned their scaled
numbers. The new focused check was run against that unchanged function, using
its two-argument API to report the actual calendar collision:

Daily seed must receive the full local date, including year.
The same calendar date repeated across years.
Daily seed must be a short opaque hexadecimal hash.
Daily seed did not hash the full local date with its domain.
Daily local-date seed checks: 14 passed / 4 failed (18 total).

This is a reproduced product defect, not a stale expectation. No existing
expectation was removed or relaxed.

## Change

`_daily_challenge_seed_for_date(day, month, year)` now hashes
`BTH-DAILY|yyyy-mm-dd` and returns its first twelve hex characters. Its caller
still reads `Time.get_datetime_dict_from_system()` using the device's local
date; it passes that year to the seed function. The streak identifier function,
its format, save/load behavior, challenge configuration, platform adapter and
all other Daily UI remain unchanged.

The existing UI integration check receives the additional year argument.
Its actual-run seed, hidden-seed HUD/menu/report, and Daily-mode assertions stay
in place. The new focused test checks stable same-date seeds, different years,
consecutive days, year/leap-day boundaries, opaque date text, unchanged local
date IDs, and restoration of a legacy in-progress Daily seed/RNG. It logs no
complete run-state or save content.

## After state and baseline comparison

Commands use the existing capped/guarded launcher, a fresh E: profile, Godot
4.6 stable, and the approved storage budget. Raw manifests and launch receipts
remain under `E:\CodexQA\BTH`.

- Focused check: **18 passed / 0 failed**, versus **14 / 4** before.
- Animation liveness without pointer input: **PASS**.
- Full `tools/check_godot.ps1 -Suite Smoke -RequireGodot -KeepGoing -VerboseStages`:
  **10 passed / 1 failed**, exit 1. Baseline: **9 / 2**.
  Import, loader, content, runtime, UI, cold Continue, library, Dave, Roulette
  audio and performance stages all pass. No stage was skipped.
- The remaining validator failure is `rw06_1 launcher self-test changed the
  candidate project cache tree`; the original baseline validator instead
  stopped on its machine-idle guard. It is retained as a separate unresolved
  harness/host observation, not described as an identical baseline failure.
- The exact unchanged validator passes on isolated retry, exit 0. External
  before/after census: zero changed cache paths or timestamps. Its 10 + 25 + 10
  Python checks pass. The first cache-change observation did not recur; its
  precise cause remains unconfirmed. No validator or harness assertion changed.
  This separate pass does not rewrite the full Smoke exit 1 as an exit 0.
- Loader: 832 checked / 0 failures, versus baseline 831 / 0; one new test script.
- No game math, payouts, item effects, animation scheduling or pinned files
  changed. No sharing/results/leaderboard/platform work was added.

## NEXT

Pending. The existing watcher refuses the combined branch before import because
the earlier requested Crossword audit CSV note changes its import inputs:
`Asset/importer/settings inputs changed; cold-import qualification required`.
The last accepted served source remains
`070fc937ad69de8d152b0dddae769f5206704821`. No qualification request has been
substituted, no cache reused against that refusal, and no pipeline guard/pin/cap
changed. The new Daily behavior has not yet been claimed as served or visually
played on NEXT.

## Limits

The date-boundary checks supply local date dictionaries; the device clock was
not changed. Continue preservation is a production RunState serialization
round-trip, with the full Smoke cold-Continue stage providing adjacent native
coverage. Browser acceptance remains pending exact NEXT delivery.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-daily-before, uf061-daily-fix, uf061-daily-after, uf061-daily-liveness, uf061-daily-smoke, uf061-daily-validator-retry, uf061-daily-validator-retry2, uf061-next-pending-receipt, uf061-base.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-daily-proof-commit\evidence\raw-evidence-index.json | a585b637f4ab62c040462e8d53bd5b37f5efdce578129d5235825fa78955406e |
| E:\CodexQA\BTH\runs\uf061-daily-before\evidence\worker.log | 763c3696211ab504f4067eb3fe0815f65e900adfa4aa1aad9e5944a8bc9ccab7 |
| E:\CodexQA\BTH\runs\uf061-daily-after\evidence\worker.log | 548ed2322a223d8cdc8ee25c4d36c35059bf9f2b5a73adac179b080914a94552 |
| E:\CodexQA\BTH\runs\uf061-daily-liveness\evidence\worker.log | e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b |
| E:\CodexQA\BTH\runs\uf061-daily-smoke\evidence\smoke\summary.json | 4533b0fb236344b2f8370ddf70ea1df8482bf04b6b12d03c02cb83a0a4067c20 |
| E:\CodexQA\BTH\runs\uf061-daily-validator-retry2\evidence\cache-comparison.json | 46791cc9827401425e6deb478a654b57c4904089ae15105303d0373e13668d61 |
