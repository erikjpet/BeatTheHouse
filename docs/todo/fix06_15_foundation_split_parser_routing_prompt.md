Status: TODO
Board row: `fix06_15` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_15: Restore Foundation split ownership and parser routing

Work in `D:\Projects\Beat-The-House` from the exact current `main`. Read the
current `land06_0` landing contract, the active board and landing ledger, commit
`c507475d12c0a7576f574cece6bc93a64ce53fa4`, every split Foundation runner, and
the scripts and PowerShell launchers that select those runners before editing.
This is an inherited release-suite infrastructure defect exposed while running
the shared full gate for `env06_6`; it is not permission to absorb an
`env06_6` product change.

## Retained red and provenance — do not replace or hide it

The split originated at exact commit
`c507475d12c0a7576f574cece6bc93a64ce53fa4` (`Complete release gate recovery`).
That commit replaced the monolithic `scripts/tests/foundation_check.gd` with a
chain rooted at `scripts/tests/foundation/check_core_content.gd` and distributed
checks and helpers across sibling split scripts.

On the current `env06_6` integration line, a direct production-engine parse of
`check_core_content.gd` failed before any assertion could run. The retained raw
log is:

`D:\bth-env6\.tmp\env06_6_runtime_fix\direct_check_core.log`

It contains exactly 668 `SCRIPT ERROR: Parse Error:` records. Of those, 592 are
missing-function occurrences covering 102 unique helper/check names. The root
script calls roughly one hundred checks or helpers that are defined only on
later siblings in the split inheritance chain, or are otherwise not owned and
routed where the caller can resolve them. The final loader result is
`Failed to load script ... check_core_content.gd` with `Parse error`.

Preserve that red as first-failure evidence. Do not overwrite it, reinterpret a
parse failure as a skipped suite, or replace it with a later passing run.

## Required work

1. Reproduce the parser failure once on a clean exact-head worktree and retain
   the complete command, engine identity, stdout/stderr, exit code and counts.
2. Build a machine-checkable inventory of the pre-split release suite and the
   current split: every check/helper definition, every caller, every supported
   suite entry point, and the `extends`/launcher route that is meant to own it.
   Reconcile the inventory to the split-parity claim recorded at `c507475d`;
   unexplained missing, extra or multiply routed checks are failures.
3. Restore coherent ownership and routing. A valid repair may move calls to the
   split script that owns their definitions, move genuinely shared helpers to a
   reachable shared base, or introduce an explicit composition/dispatch layer.
   The root and every supported terminal runner must parse independently under
   the production engine. Preserve the intended suite boundaries and execution
   order.
4. Add a permanent fail-closed guard proving that every supported split runner
   parses and that each release check is routed exactly as intended. The guard
   must catch unresolved sibling-only calls, orphaned checks and duplicate
   execution. It may not infer success from source-text presence alone where a
   real engine load or execution can decide the question.
5. Run project validation, direct parser/load probes for every split runner,
   every supported Foundation suite, Contract, Smoke, Systems, UI, 10-seed
   determinism and the complete `env06_6` shared full-gate invocation on the
   exact accepted head. Supply and record the generated native plugin before
   any native-sensitive gate. Preserve every result, including timing reds.
6. Obtain independent implementation and evidence review. The reviewer must
   compare the pre/post inventories, inspect actual runner output for duplicate
   or omitted checks, and return `ACCEPT <exact-head>` or
   `REJECT <exact-head>` under the landing contract.

## Locked boundaries

- Do not weaken, delete, filter, skip or duplicate any check, assertion, suite,
  seed, fixture, parser rule, timeout, budget or liveness floor.
- Do not make a parser/load guard green by excluding `check_core_content.gd` or
  any sibling from validation, by swallowing engine errors, or by routing all
  suite names to one reduced body.
- Do not change product behavior, locked design, RTP, EV, payout, odds, wager
  math, RNG, economy values, schema or migration.
- Keep the repair in test and gate infrastructure unless exact evidence proves
  a product source change is unavoidable. Route any such product defect as a
  separate row; do not absorb it here.
- `env06_6` remains dependent on this row for its shared full-gate evidence.
  This row does not accept, merge or otherwise complete `env06_6`.
- Never rerun until green, raise a cap, discard a slow result, or refresh a
  golden to conceal a red.

Commit logically, self-review the full diff, obtain independent review, and
land only through the single-PM one-row-at-a-time loop after exact-head and
post-land gates are green.
