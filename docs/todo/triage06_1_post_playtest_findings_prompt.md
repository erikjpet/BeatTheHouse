Status: PARKED - do not claim until the owner opens the polish pass
Board row: `triage06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** -
- **Completion commits:** -
- **Input capture and build:** -
- **Finding counts/dispositions:** -
- **Created fix rows / roadmap decisions:** -
- **Verification:** -
- **Deviations:** -

# Agent Prompt - 0.6 triage06_1: Post-Playtest Finding Triage

Copy everything below this line into the agent only after the board coordinator
has changed this row from `PARKED` to `TODO`.

---

You are working in `D:\Projects\Beat-The-House`. This row turns the owner's
completed 0.6 playtest capture into an owner-dispositioned work queue. It
normalizes and routes findings; it does not fix product code, tune values,
rewrite voice, clean files, bump a version, build/package, tag, upload or
publish.

Read in full:

- `docs/plans/0.6_post_playtest_program.md`;
- the playtest script, capture format and handoff delivered by
  `playtest06_2` / `playtest06_1`;
- the owner's complete capture without editing the original;
- `docs/plans/0.6_living_world_roadmap.md` and its owner decisions;
- `docs/plans/0.6_remaining_work_program.md`;
- `docs/todo/README_0_6_board.md` and relevant archived task prompts;
- `balance06_1`'s report only to recognize already-known economic findings.

## Claim gate

Follow the active board protocol. Do not self-unpark this row. Claim it only if
the row is `TODO`, `playtest06_1` is DONE, the capture names an exact playtest
build, and the owner has explicitly declared both the playtest closed and the
polish pass open. If any condition is absent, record the exact absence through
the board protocol and stop.

The primary integrator alone edits the active board, allocates `fix06_*` ids,
archives prompts and merges branches. Prepare exact board-ready text and files
for that integrator; do not race another board writer.

## 1. Build the lossless finding ledger

Create `docs/plans/0.6_post_playtest_triage.md`. Give each raw note a stable
`PT06-NNN` id and preserve the owner's original wording. Normalize these fields:

| Field | Requirement |
| --- | --- |
| Original note | Verbatim owner meaning; a short quotation or faithful full note, never a reinterpretation. |
| Observed / expected | What happened and what the owner expected. Use `UNKNOWN`, not a guess. |
| Context | Surface/location, route/session, build commit, platform, save provenance and named seed. |
| Reproduction | Smallest known steps, frequency and evidence paths. Mark unverified claims honestly. |
| Class | `DEFECT`, `DESIGN_OBJECTION`, or `UNCLEAR`. |
| Severity | Proposed P0/P1/P2/P3 with evidence. |
| Ownership | Owning system/files and shared-file/dependency risks. |
| Gate analysis | Gate that should have caught it, escape reason and proposed durable repair. |
| Owner disposition | `BLOCK_0.6`, `DEFER_0.7`, `DESIGN_DECISION_REQUIRED`, or `NOT_A_FINDING`, plus date/reference. |
| Route | `fix06_*` id, roadmap decision id, or no-work reason. |

Reproduce findings only through read-only diagnostics unless the capture is
already sufficient. Do not mutate saves or owner evidence in place. Do not
discard duplicates: link them to a canonical finding and retain their ids.

## 2. Enforce the defect/design split

Classify as `DEFECT` only when the observation violates an existing accepted
rule, invariant, prompt, roadmap decision or explicit expected behavior. Cite
that contract.

Classify as `DESIGN_OBJECTION` when the implementation may match the locked
contract but the owner objects to the rule, direction, feel or intended
experience. Record a `PENDING OWNER` roadmap decision containing the finding,
current locked rule, evidence and the smallest decision the owner must make.
Do not propose a preferred implementation as if it were approved.

Classify ambiguity as `UNCLEAR` and route it exactly like a design objection.
An agent never resolves ambiguity in favor of code changes.

This is an acceptance rule, not advice: no `fix06_*` prompt may be derived from
a design objection or unclear note unless it cites a roadmap decision id with
the owner's approved wording. A pending decision creates no implementation
row. After the owner decides, record the decision in the roadmap first; only
then derive a defect or scoped design-change row that implements exactly it.

## 3. Recommend severity; obtain owner disposition

- **P0:** data loss/corruption, security/privacy exposure, destructive
  migration, or unrecoverable launch failure.
- **P1:** promised core behavior unavailable or wrong; deterministic, money-
  conservation, save, platform or release-critical contract broken; no
  reasonable workaround.
- **P2:** material functional/experience failure with bounded scope or a
  reliable workaround.
- **P3:** non-functional polish, minor presentation or low-impact edge case.

The severity is the triage agent's reproducible recommendation. It does not
decide the release. Present the complete ledger to the owner and record exactly
one final disposition for every finding. Only the owner decides
`BLOCK_0.6` versus `DEFER_0.7`, including P0/P1. Do not interpret silence as
approval or deferral.

A deferred finding must retain its evidence, owner wording/date and explicit
0.7 roadmap target. `NOT_A_FINDING` requires the owner's reason or evidence
that the captured observation did not occur on the named build.

## 4. Write one prompt per accepted defect

After owner disposition, create one `docs/todo/fix06_<next>_<slug>_prompt.md`
per independently owned defect. Check ids in both `docs/todo/` and
`docs/todone/`; never reuse one. Combine findings only when they share the same
root cause, ownership and verification. Split them when they can land safely
and independently.

Every prompt uses this complete template:

```markdown
Status: TODO (or PARKED when an explicit dependency remains)
Board row: `fix06_<id>` in `docs/todo/README_0_6_board.md`
Source finding: `PT06-NNN`
Owner disposition: `BLOCK_0.6|DEFER_0.7`, date/reference
Owner roadmap decision: `<id and approved wording>` or `NOT DESIGN-DERIVED`

## Execution Record (fill on completion)
- Completed:
- Completion commits:
- Verification:
- Deviations:

# Agent Prompt - 0.6 fix06_<id>: <defect title>

Copy everything below this line into the agent.
---

## Reproduction
- Exact playtest build, platform, save provenance and seed
- Minimal steps
- Observed result and evidence
- Reproduction frequency

## Expected behavior and binding source
- Exact expected behavior
- Roadmap/prompt/invariant citation

## Severity and release disposition
- Proposed severity and evidence
- Owner's final BLOCK_0.6/DEFER_0.7 decision

## Ownership and dependencies
- Owning system and exact allowed files
- Shared consumers, migrations and rows that must land first
- Explicit forbidden files/behaviors

## Escaped-gate repair
- Gate that should have caught the defect
- Why it escaped or falsely passed
- Negative control that fails before the repair
- Permanent regression assertion after the repair
- If automation is unreasonable, why and the durable manual/instrumented gate

## Implementation contract
- Smallest root-cause repair
- Locked design/values/voice that must not change
- Save, idempotency, determinism, hidden-state and platform obligations

## Acceptance and exact commands
- Focused reproduction and negative control
- Owning Foundation/UI/visual/performance/parity/migration gates as applicable
- Full project validation

## Board completion and handoff
- Logical commits; execution record; board evidence; archive, review and merge
```

Every fix must repair the escaped gate as part of its definition of done. If no
automated gate reasonably could have caught the defect, document why and add
the smallest repeatable manual or instrumented acceptance step. The phrase
`no gate` by itself fails review.

Do not write a fix prompt for a `DEFER_0.7` finding unless the owner explicitly
asks to preserve a parked prompt. If so, mark it `PARKED`, give it a 0.7 target
and do not schedule or claim it.

## 5. Produce the board-ready queue

For the primary integrator, provide:

- exact new row markdown in current board format;
- dependencies, unblocks, file ownership and shared-file collisions;
- recommended parallel batches and genuine serialization points;
- owner disposition and roadmap-decision reference per row;
- a zero-work list for deferred, rejected, duplicate and decision-pending notes.

No row is unparked or started by this task. The primary integrator coordinates
board changes after checking other family writers.

## Validation and completion

- Prove ledger coverage: raw note count equals canonical findings plus linked
  duplicates; every raw id appears exactly once.
- Prove routing coverage: every canonical finding has an owner disposition and
  exactly one valid route.
- Validate every created prompt has all template fields and that design-derived
  prompts cite an approved roadmap decision.
- Run `tools/validate_project.ps1` and prove only documentation changed.
- Review the full diff for invented owner intent, implementation, release work,
  modified evidence, missing gates, reused ids and accidentally staged owner
  files.

Commit in logical `triage06_1` units and hand off for independent review. On
completion, the primary integrator updates the row, records the report and row
list, and archives this prompt. Do not start any generated `fix06_*` row.
