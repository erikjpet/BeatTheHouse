# fix06_30 — Foundation Contracts Runner Lifecycle Repair

## Status

IN_PROGRESS — owner opened 2026-09-09; `/root` claimed the row. This is a
harness-integrity row, not a product-behavior change.

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

