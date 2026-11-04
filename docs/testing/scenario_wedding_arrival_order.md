# BTH-SCENARIO-WEDDING-001: delayed arrival after Wedding tasks

Parent: **BTH-11 — Scenario polish**. Both items remain open through their
recorded commit and required NEXT/behavior acceptance. There are no intentional
holds. Current owner: `Resume scenario improvements`
(`01a1a3e5-607c-73bf-b678-e3e03f5e40f6`).

Fix on main: `1c201c9e341ac6f3e068c4d498fd00bf7298880e`, tree
`da735bf6dd3bf2decbba8ab728ec207952596448`. The initial automatic publication
review block cleared after the user's standing BTH main/NEXT authorization was
provided. The scoped update preserves concurrent main commits.

The existing watcher observed the fix but reports
`Asset/importer/settings inputs changed; cold-import qualification required`.
NEXT still serves `adb75dbe7f97e2b96279fbf401f7d7b8913072b3`; no deployment,
startup or changed-behavior pass for the fix is claimed. Follow the maintained
qualification path with its owner; do not bypass the guard or substitute a
manual build. This is a concrete deployment dependency, not an intentional hold.

## Recovered report and correction

The original Web report used source
`f3a2f0b1930813a34553054c966c965a5ee13bff`, campaign R03. After ordinary Delta
Queen arrival, Secure Ceremony Lane, Save/Continue, Recover Ring Case, Steady
Best Man and Leave him smiling, the scene unexpectedly displayed the losing
table aftermath. No wager, refusal, failure command or later travel was taken.
The failure remained after cold Continue. This is Delta Queen Wedding Charter,
not Motel Wedding Overflow. Original screenshots and the receipt remain in
the original QA evidence directory; no original campaign was rewritten.

The world-travel facade queued `travel_arrived` after installing the destination.
Zero-turn scenario commands could then advance from `arrival` to `work_3`
without consuming that fact. The event response advances an ordinary turn,
which flushes the original arrival against `work_3`'s authored arrival-pressure
branch. The branch selects `table_opportunity`; the correlated event response
itself only publishes feedback.

`RunGenerator.travel_environment_result` now flushes destination facts before
reporting successful travel. A rejected flush uses the existing rollback owner:
the direct facade restores its snapshot, or its caller receives failure and
restores the enclosing travel transaction. The returned environment is the
accepted post-flush room. No content graph, event choice, reward, placement,
RNG rule, game format, viewport or input behavior changes.

## Verification record

Native verification on 2026-11-04 used runtime source
`dc15b7d369f435d50fbf16e37af33952a4c58760`. Before integration, the generator blob still matched the tested baseline.
Concurrent Coin Pusher publication-cadence changes were preserved; this receipt
does not extend its regression claims to those independently owned changes.

| Check | Result |
| --- | --- |
| Historical control, original generator, `BTH_WEDDING_EXPECT_OLD=1` | 25 assertions pass: one queued initial arrival survives Secure Lane, Recover Rings and Steady Best Man; Leave him smiling resolves `work_3_pressure` from `travel:travel_arrived:1` into `table_opportunity`. |
| Corrected `wedding_arrival_order_check.gd` | 56 assertions pass: arrival consumed once before commands; all four ceremony commands, real event response, fresh SaveService round trips, explicit failure/refusal, new arrival pressure and injected rejection remain correct. |
| `travel_arrival_rollback_check.gd` | 29 assertions pass: direct complete rollback, explicit caller-owned rollback, ownership reset after rejection and supported sequence-suppressed destination. |

Both focused scripts ran with `--headless --path . --audio-driver Dummy
--script res://scripts/tests/<check>.gd` in disposable `native-private-*`
storage. Each process was assigned before execution to the maintained capped
Job; successful runs exited 0, timed out false and left zero owned processes.
The import also exited 0. No full suite was run.

These use a synthetic pinned challenge, ordinary clock advance to 19:00,
production generator travel with route admission prevalidated, authenticated
RunState commands and the real EventModule response. Save checks use a fresh
SaveService and normal loaded-room finalization in the native process. The
caller-owned rejection test explicitly owns/restores the generator snapshot;
it does not claim the complete UI fare transaction was exercised.

The rejected synthetic source is normalized through ordinary restore before
the strict full snapshot comparison: existing restore adds absent zero-default
reputation and local Heat fields. No financial value or RNG cursor differed.
The assertion was retained. Failed early Host setups and the helper-name parse
failure remain harness evidence; they are not gameplay passes.

Retained local receipts: `evidence/wedding-direct-control-result.json`,
`wedding-final-result.json` and `arrival-rollback-final-result.json` in task-16.
Their invocation receipts retain full commands, test hashes, limits and
cleanup. No player save/profile/key is included in this commit. Visual Web
acceptance and recovery of the original campaign remain unverified.

## Remaining scope and next actions

- Record the fix commit, exact NEXT identity/served provenance and basic launch.
  Exercise the normal visible Wedding path on that build; keep this acceptance
  open until it has a matching receipt.
- **BTH-SCENARIO-ARRIVAL-002:** investigate Punchline Bringer Show's layer-entry
  arrival ordering with a separate focused regression. Its producer also queues
  arrival after installation. This is a source-supported lead, not a reproduced
  new player failure. Grand scenarios have no arrival-pressure listeners and
  need no speculative change for this report.
- Keep BTH-11 open. The recovered original matrix contains all 55 stable IDs;
  its new game formats, controls, numeric tuning, APIs and release batches were
  proposals, not completed implementations. Select further bounded work from
  current-source evidence and resolve only choices needed by that slice.

This correction does not migrate pending arrivals in already-progressed old
saves or revise completed historical aftermaths. It prevents a newly completed
world trip from leaving its arrival pending behind later commands.
