Status: TODO
Board row: `fix06_16` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_16: Web performance server orphan cleanup

Work from exact current `main` after `fix06_14` lands. This row owns only the
Web performance wrapper/server lifecycle defect exposed by the consumed
`fix06_14` qualification. It does not own shipped-Web performance or any
Coin Pusher gameplay/evidence contract.

## Retained reproduction

At exact source `dba07c1a5c675e07cb9a3dc2956889d67086df2a`, the sole fresh
Chrome 151 CPU-4 qualification wrote its complete report and summary, then the
outer orchestration remained alive until 904 seconds. `serve_web.ps1` had left
orphan Python PID 39916 listening on port 18117 after the wrapper's server
process cleanup. The PM stopped only PID 39916 and verified both process and
listener absent. The measurement is immutable and must not be rerun or replaced
for this row.

## Required work

1. Reproduce the process-tree lifecycle defect without consuming a Coin Pusher
   Web timing run.
2. Attribute wrapper, PowerShell child and Python server ownership/termination.
3. Implement the smallest deterministic cleanup that terminates the exact
   launched server tree on success, assertion failure, probe failure and host
   interruption while preserving report/summary output already written.
4. Add hostile lifecycle tests proving no unrelated process/ref can be killed,
   cleanup cannot silently succeed while the owned listener remains, and a
   missing/already-exited child is handled deterministically.
5. Run static validation and focused non-Web lifecycle tests, then obtain
   independent exact-head review before landing.

## Locked boundaries

- Do not alter Web performance caps, fixtures, sample lengths, actions,
  throttling, scenario coverage, evidence schemas or console policy.
- Do not rerun or replace any retained `fix06_14` Web result.
- No gameplay, simulation, RNG, payout, odds, wager, economy, geometry, tuning,
  schema, migration, version, packaging, release or remote change.
- Never terminate by broad process name, wildcard or port alone. Track and
  verify the exact launched process tree and fail closed if ownership cannot be
  established.

Preserve every lifecycle artifact and exact process/port identity. Commit
logically, self-review, obtain independent review, and land before the next
locked `fix06_13` shipped-Web run.
