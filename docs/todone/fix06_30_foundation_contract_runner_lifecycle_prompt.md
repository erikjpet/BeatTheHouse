# fix06_30 — Foundation Contracts Runner Lifecycle Repair

## Status

DONE — completed 2026-09-10 on implementation `3f31bf10`. This is a
harness-integrity row; its runner work does not change money, RNG, RTP,
payouts, odds, schema or migrations.

## Execution Record

- The generated runner now validates required helper symbols before execution,
  partitions the registered contract inventory exactly once, isolates mutable
  user/cache state, preserves canonical report order, and fails closed on
  missing reports/helpers, composition/parse/script errors, warnings, nonzero
  exits and timeouts.
- Permanent hostile PowerShell contracts cover missing/duplicate/unknown shard
  ids, missing helpers, script-error stderr, report/order drift, exit-code
  precedence, persistence ownership and cache isolation.
- Legitimate queued UI teardown receives real frames before shutdown leak
  diagnostics; a detached Blackjack authority fixture host is explicitly freed.
- Canonical verification:
  `tools/check_godot.ps1 -Suite Smoke -FoundationSuite contracts` passed all
  stages with the Foundation contracts stage at 227.786s, below the unchanged
  230.391s budget, with zero failures and zero warnings. Report:
  `.tmp/test_reports/20260910_024638_smoke/summary.json`.

## Reproduction

Run `tools/check_godot.ps1 -Suite Smoke -FoundationSuite contracts` from a
clean imported tree. The composed runner reaches the broad Foundation content
stage, emits approximately 70 script errors from scenario-sequence lifecycle
probes whose helper references are nil, and does not return a contract verdict
within the 300-second ceiling. The retained report is
`.tmp/fix06_28_contracts_final3/summary.json` in the fix06_28 worktree.

## Required work

- Trace why the generated aggregate runner loses or misbinds lifecycle helper
  scripts while the focused production-fidelity checks remain valid.
- Make runner composition fail closed before execution when a required helper
  or shard is missing.
- Add a permanent regression that cannot print PASS or exit zero after any
  parse, composition, missing-helper, or script error.
- Rerun the canonical broad command to a real zero-failure verdict and record
  elapsed time without relaxing its ceiling or deleting checks.

Do not change money, RNG, RTP, payouts, odds, schema, migrations, or product
behavior to repair this harness.
