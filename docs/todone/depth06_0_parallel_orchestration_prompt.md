# Orchestration Prompt — Complete the Living Games and Environment Depth Program

Copy everything below this line into one primary Codex agent. That agent is the
program integrator and must employ sub-agents; it is not permitted to implement
the whole program alone.

---

You are the primary integrator for the owner-requested depth program in
`D:\Projects\Beat-The-House`. Your job is to use as many sub-agents as the
current runtime safely permits, complete every task below, independently review
each implementation branch, preserve logical individual commits, merge the
accepted work through an integration branch, run an exact-tree release audit,
and merge the finished program back into the branch from which you started.

Required task contracts:

1. `docs/todo/env06_6_dynamic_scenario_runtime_prompt.md`
2. `docs/todo/env06_7_all_variations_sequence_rework_prompt.md`
3. `docs/todo/craps06_3_craps_depth_rework_prompt.md`
4. `docs/todo/crew06_10_backroom_poker_depth_rework_prompt.md`
5. `docs/todo/depth06_1_games_and_scenarios_release_gate_prompt.md`

The active board is `docs/todo/README_0_6_board.md`. The five task prompts are
binding acceptance contracts. Read them completely before planning, then read
all repository `AGENTS.md` files that govern touched paths. Do not weaken or
reinterpret a task to make it fit the available time or agent count. Continue
until the full program is finished, or report a genuine blocker with exact
evidence.

## Authority and non-negotiable outcome

- You are explicitly authorized to create local branches and isolated Git
  worktrees, assign implementation and review work to sub-agents, commit the
  requested changes, merge accepted branches, resolve in-scope conflicts, and
  merge the fully accepted integration branch back into the starting branch.
- Do not push, open a pull request, publish a build, delete user work, or modify
  remote state unless the user separately requests it.
- Existing dirty/untracked files belong to the user. Record them at preflight,
  never copy them into worktrees, never stage them, and never use reset/clean/
  checkout commands that could discard them.
- All 55 existing environment scenario ids must finish as unique, playable,
  spatially changing sequences. Craps and poker must meet their complete depth
  prompts. Partial conversion is not a valid stopping point.
- “Parallel” is dependency-aware. Work that consumes `env06_6` may be audited,
  designed, and prototyped in parallel, but its final implementation branch
  must be based on the reviewed runtime integration commit.

## 1. Preflight and immutable baseline

1. Capture and report:
   - absolute repository path;
   - starting branch and exact HEAD;
   - upstream/ahead/behind state;
   - tracked modifications and untracked paths;
   - existing worktrees and branches matching `codex/depth-*`;
   - available agent/concurrency capacity;
   - supported validation/test commands and their practical runtimes.
2. If tracked user changes overlap any required file, do not hide or overwrite
   them. Create worktrees from the exact starting HEAD and leave the original
   working tree untouched until final integration; stop only if the overlap
   makes an honest final merge impossible.
3. Create `codex/depth-program-integration` from the exact starting HEAD in an
   isolated worktree. Record its path. All accepted work merges here first.
4. The six named depth-program prompt files and their matching board section
   are owner-requested in-scope planning inputs. If they are not yet present in
   the starting commit, copy only their exact current contents into the
   integration worktree and commit them first as
   `depth06_0: add parallel depth program contracts`. Do not include any other
   dirty or untracked path. Verify the resulting integration commit contains
   all five task contracts plus this launcher before creating worker branches.
5. The primary integrator is the only agent allowed to edit the active board,
   archive task prompts, merge branches, or resolve cross-branch conflicts.
   Workers and reviewers must leave those files alone.
6. Establish a live program ledger outside committed product data (or in the
   integration report) containing branch, worktree, owner, file ownership,
   base commit, dependencies, status, reviewer, findings, test evidence,
   accepted head, merge commit, and cleanup status.

## 2. Spawn the initial parallel audit team

Immediately use the available sub-agent slots. Give each agent a bounded,
read-only audit with a required written handoff. At minimum cover:

- scenario runtime/schema, renderer, persistence, migration, and conflict
  boundaries;
- the 55-scenario catalog, events, archetype renderers, shared-file collision
  map, and a proposed per-archetype implementation partition;
- Craps rules/surface/energy/street integration and its exact test matrix;
- poker betting/tells/session/Turn/L3 integration and its exact test matrix.

If capacity is lower than four workers, queue these audits and keep every slot
busy. Audit agents must cite paths/symbols, identify shared files, propose
commit boundaries, and map every prompt requirement to implementation/tests.
They do not edit code. Use their handoffs to produce the execution plan and
file-ownership matrix.

## 3. Branch and worktree topology

Use isolated worktrees for every concurrent implementation. Never let two
agents change branches in the same worktree. Use these branch families (add a
short numeric suffix only if a stale local name already exists):

- `codex/depth-env-runtime` for `env06_6`;
- `codex/depth-craps` for `craps06_3`;
- `codex/depth-poker` for `crew06_10`;
- `codex/depth-env-<package>` for environment content packages;
- `codex/depth-env-catalog-integration` for assembling all 55 packages;
- `codex/depth-release-remediation` only for exact-tree findings that cannot
  cleanly return to their owning branch.

Create worktrees under a verified sibling directory such as
`D:\Projects\Beat-The-House-worktrees\`. Resolve every path before creation or
cleanup. Never recursively delete a computed path; use `git worktree remove`
after verifying the registered path and only after its branch is safely merged.

Every worker assignment must state:

- its branch/worktree and exact base commit;
- the prompt sections and acceptance rows it owns;
- allowed files/directories and specifically forbidden shared files;
- dependencies and integration APIs it may assume;
- required focused and regression tests;
- required commits and self-review report;
- the rule that it must not merge, edit the board, archive prompts, or touch
  unrelated/user files.

## 4. Dependency-aware execution waves

### Wave 1 — dynamic runtime

Claim `env06_6` on the board. Assign its implementation to a runtime worker in
`codex/depth-env-runtime`. While it works, use remaining agents for read-only
design/test preparation for Craps, poker, and scenario packages.

The runtime branch must include at least these logical commits:

1. schema/validation/registered-operation contract;
2. runtime lifecycle, persistence, migration, and conflict handling;
3. semantic scene/render/interactable/actor integration;
4. authoring/uniqueness tooling and focused tests;
5. one proof scenario plus documentation/evidence.

Do not merge Wave 1 on implementer confidence alone. Apply the branch review
protocol below. Once accepted, merge it with `--no-ff` into the integration
branch, run runtime smoke/regression gates there, update/archive `env06_6`, and
record the integration commit. Only this accepted commit may be the base for
consumer implementation branches.

### Wave 2 — parallel consumers

From the accepted runtime integration commit, claim and start `craps06_3`,
`crew06_10`, and the environment-content packages concurrently. Keep all
available slots occupied, swapping a completed implementer for a reviewer
immediately.

Split the 55 scenarios into packages with exactly one owner per id. A suggested
partition is:

- `shops-streets`: corner store, back alley, motel (13 ids);
- `bars-road`: bar, gas-station casino (12 ids);
- `punchline-clubs`: Punchline, jazz club, Kitty Cat Lounge (16 ids);
- `queen-public`: Delta Queen, beach, pawn shop, Grand Casino (14 ids).

The catalog audit may adjust this partition for renderer/file ownership, but
the ledger must still account for exactly 55 unique ids once and only once.
Never have multiple workers casually edit a monolithic shared JSON file.
Choose one of these safe strategies and record it before implementation:

1. introduce validated per-archetype/per-package source files through the
   runtime and have each package own distinct files; or
2. make package workers own handlers/render/tests/dossiers while a single
   catalog-assembly agent applies their reviewed data patches to the shared
   catalog in deterministic package order.

Do not refactor content storage solely for convenience if it harms runtime
clarity or compatibility. If using catalog assembly, each content worker must
provide a machine-readable reviewed patch/dossier and fixture tests, and the
assembly agent must preserve package authorship in separate commits.

Each scenario package must:

- implement every anchor in `env06_7` for its assigned ids;
- include spatial/object/actor changes, scenario-specific verbs, branches,
  aftermath, reentry/cleanup, save/load, reachability, and captures;
- run package uniqueness comparisons against both its own ids and all already
  accepted packages;
- finish with one checklist mapping every assigned id to code, tests, captures,
  phase/branch counts, mechanic signature, and reviewer status.

Craps and poker workers follow their complete prompts. They may use additional
sub-agents for isolated rule/property tests, presentation/accessibility, policy
analysis, or capture review when slots become available, but one branch owner
remains accountable for coherent implementation and commit history.

### Wave 3 — package review and catalog assembly

Independently review each scenario package before assembly. Accepted package
heads are then rebased or merged onto the current catalog-integration base in a
fixed documented order. Resolve shared catalog conflicts semantically: preserve
all ids, refs, branches, and tests; never choose one side wholesale.

After every package integration:

- verify expected cumulative id count and no duplicate/missing ids;
- run schema/ref/uniqueness/reachability/package save tests;
- inspect the diff for accidental changes to previously accepted packages;
- create a distinct integration commit naming the package and accepted head.

When all 55 are assembled, run the complete `env06_7` gates and independent
visual contact-sheet review. Fix findings on the owning package branch when
practical, re-review, and reintegrate. Only then merge the catalog-integration
branch with `--no-ff` into the main program integration branch and close/archive
`env06_7`.

### Wave 4 — integrate Craps and poker

Each game branch requires independent review and all focused gates before it is
eligible. Merge accepted game branches one at a time with `--no-ff`, preserving
their logical commits. After each merge, run its focused tests plus scenario
composition/save/UI smoke on the integration branch. If the second merge breaks
the first, assign the finding to the responsible branch or an explicit
cross-system remediation commit; never mask it in the merge resolution.

Update/archive `craps06_3` and `crew06_10` only after their accepted heads and
post-merge integration gates are recorded.

### Wave 5 — independent release gate

Claim `depth06_1`. Spawn at least two reviewers who did not own the relevant
implementation:

- one for code/data/state/privacy/determinism/economy correctness;
- one for player-facing visual, interaction, accessibility, pacing, and the
  unlabeled scenario-identity contact sheets.

Run the entire `depth06_1` prompt on the exact integration head. Reviewers must
sample the build themselves, not merely read implementer reports. Consolidate
findings by severity and owner. Any P0/P1 or unmet prompt checkbox blocks
closure. Fix lower-severity issues when they affect correctness, uniqueness,
readability, accessibility, persistence, or the claimed finished experience.

Use owning branches for fixes where feasible; otherwise use the named release-
remediation branch with one issue per commit. Every remediation commit gets the
same self-review and independent review as an implementation commit.

## 5. Mandatory branch self-review protocol

Before requesting review, every implementer must stop editing and produce a
branch handoff containing:

1. exact base and head commits plus `git status` proving only intended files;
2. commit list with one-sentence purpose per commit;
3. prompt checklist mapping every owned requirement to file/symbol/test/capture;
4. `git diff --check` and a diff-stat/directory ownership audit;
5. review of the complete base-to-head diff for debug code, TODO stubs, dead
   paths, accidental generated files, hardcoded test shortcuts, privacy leaks,
   non-deterministic time/randomness, duplicated consequences, and save/revisit
   hazards;
6. focused tests, required regression suites, determinism/parity/performance,
   and visual/accessibility evidence with exact commands and results;
7. known risks or assumptions. “None” must be explicit, not omitted.

An implementation branch is not reviewable with dirty tracked changes,
uncommitted required work, missing evidence, skipped prompt rows, or unrelated
files. The implementer fixes its own self-review findings in new logical
commits, reruns affected gates, and refreshes the handoff.

## 6. Mandatory independent review protocol

Assign a reviewer who did not author the branch. The reviewer starts from the
recorded base, reads the binding prompt sections, and independently checks:

- full diff and commit boundaries;
- correctness, error paths, state ownership, migrations, idempotency, cleanup,
  deterministic RNG/action boundaries, Web/native behavior, performance, and
  accessibility;
- tests for false positives, missing negative cases, overfitted fixtures, and
  weakened assertions;
- actual player-facing behavior and captures, not just state flags;
- interactions with already accepted work and likely merge conflicts;
- every assigned checklist item, including every scenario id in a package.

Record findings as `P0` (data loss/security/unshippable), `P1` (incorrect or
missing required behavior), `P2` (material quality/maintainability gap), or
`P3` (non-blocking polish). P0/P1/P2 findings require a fix or a written
owner-approved exception; the integrator cannot waive them. The implementer
lands fixes, self-reviews again, and the reviewer verifies the new exact head.

The reviewer issues one of only two verdicts:

- `ACCEPT <exact-head>` with prompt coverage and rerun evidence; or
- `REJECT <exact-head>` with actionable findings.

Acceptance is invalid after the branch head changes. Re-review the new head.

## 7. Commit and merge discipline

- Preserve individual logical commits. Do not squash an entire task or all 55
  scenarios into one commit. Do not create a commit per trivial typo either.
- Commit messages use the task/package id and outcome, for example
  `env06_6: add deterministic scene operation runtime` or
  `env06_7: convert bar scenarios to staged room sequences`.
- Before every merge: fetch no remote state unless authorized; verify clean
  integration worktree, expected branch head, recorded reviewer acceptance,
  diff/check results, and no unrelated files.
- Merge accepted branches with non-interactive `git merge --no-ff` so their
  commits and a clear integration boundary remain visible.
- Resolve conflicts only in the integration worktree. After resolution inspect
  every conflicted hunk, rerun both sides' focused tests, and commit a clearly
  named merge. Never use blanket “ours” or “theirs” for product/data files.
- After each merge, record accepted head, merge commit, tests, and cumulative
  scenario count in the ledger. A failed post-merge gate reopens the responsible
  task.
- Do not stage `.tmp`, review artifacts, captures outside their documented
  evidence location, editor state, or pre-existing user files.

## 8. Final merge back to the starting branch

Only after `depth06_1` passes and all five rows are DONE/archived:

1. Verify the integration worktree is clean and contains the complete reviewed
   commit graph. Run `git diff --check`, project validation, the full supported
   foundation matrix, 10-seed determinism, native/Web parity, RTP/property
   gates, performance, accessibility, save/migration, scenario uniqueness, and
   visual QA one last time on that exact head.
2. Produce the closure report with all 55 ids, branch/reviewer/accepted-head/
   merge-commit mapping, Craps and poker evidence, remediation commits, and
   final gate results.
3. Return to the original working tree. Confirm the starting branch and verify
   its tracked state has not changed since preflight. If it has new overlapping
   user work, stop and report instead of overwriting it.
4. Merge `codex/depth-program-integration` into the starting branch with
   `--no-ff`. Do not squash. Do not reset or force-update the branch.
5. Run a final lightweight validation and verify the merge contains every
   accepted commit and no user/untracked artifacts.
6. Do not remove worktrees/branches until the final merge and validation pass.
   Then remove only clean, registered program worktrees whose accepted heads
   are reachable from the final branch. Keep branches unless the user asks to
   delete them.

## 9. Communication and terminal conditions

- Send concise progress updates at wave boundaries, after reviews, after each
  merge, and whenever a gate reopens work. Include counts: scenarios accepted
  out of 55, branches accepted/merged, unresolved findings, and next dependency.
- Never describe a row as complete before its independent reviewer accepts the
  exact head and its post-merge gates pass.
- If an agent stalls, reassign its bounded remaining work without discarding
  valid commits. If a test is flaky, diagnose and fix determinism; do not rerun
  until lucky or loosen thresholds.
- A genuine blocker must include three attempted safe approaches, exact error/
  evidence, affected prompt rows, preserved branch heads, and the smallest user
  decision needed. Hard work, merge conflicts, long tests, or review findings
  are not blockers.

Your final response must lead with the outcome and include: starting/final
branch and commits, all created branches, reviewer verdicts, merge commits,
scenario count and uniqueness result, Craps/poker completion summary, complete
gate table, closure-report paths, any retained worktrees/branches, and explicit
confirmation that pre-existing user files were not staged or modified.
