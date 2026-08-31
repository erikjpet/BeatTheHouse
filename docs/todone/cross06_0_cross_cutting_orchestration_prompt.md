Status: LAUNCHER
Board section: `Family 3 — Cross-cutting completion` in `docs/todo/README_0_6_board.md`

# Orchestration Prompt — Cross-Cutting Completion Program (Family 3)

Copy everything below this line into one primary Codex agent. That agent is the
program integrator and must employ sub-agents; it is not permitted to implement
the whole program alone.

---

You are the primary integrator for the cross-cutting completion program in
`D:\Projects\Beat-The-House`. Unlike Families 1 and 2, these rows are not one
dependency chain. Some can start today, some must wait for the depth programs,
and two are audits whose value depends entirely on being run last. Your job is
to schedule them correctly, use as many sub-agents as the runtime safely
permits, review every branch independently, and merge accepted work through an
integration branch.

Required task contracts:

| Row | Prompt | Can start |
| --- | --- | --- |
| `meta06_1` | `meta06_1_career_run_report_surfacing_prompt.md` | now |
| `balance06_1` | `balance06_1_cross_system_economy_audit_prompt.md` | now |
| `board06_1` | `board06_1_board_hygiene_prompt.md` | now |
| `pusherv3_11` | `pusherv3_11_pusher_program_closure_audit_prompt.md` | after `pusherv3_10` |
| `teach06_2` | `teach06_2_teaching_pass_two_prompt.md` | after `depth06_1`, `game06_8`, `world06_7` |
| `audio06_1` | `audio06_1_surface_sfx_pass_prompt.md` | after Families 1 and 2 land rituals |
| `integ06_1` | `integ06_1_composition_migration_soak_prompt.md` | after Families 1 and 2 merge |
| `perf06_1` | `perf06_1_performance_platform_pass_prompt.md` | after Families 1 and 2 merge |
| `playtest06_2` | `playtest06_2_playtest_gate_refresh_prompt.md` | after `integ06_1` and `perf06_1` |
| `polish06_0` | `polish06_0_post_playtest_program_prompt.md` | now (stays parked on delivery) |

The active board is `docs/todo/README_0_6_board.md`. Each prompt is a binding
acceptance contract. Read them completely before planning, then read all
repository `AGENTS.md` files that govern touched paths. Do not weaken or
reinterpret a task to fit available time or agent count.

## Why this program exists

The board covers designed features. It does not cover: the update being visible
in the between-run screens, the combined economy of every new income stream, the
teaching of everything 0.6 added, the sound of the reworked surfaces, whether a
real 0.5 save survives all of 0.6 at once, whether the game still performs on
Web and low-end hardware after two depth programs, whether the playtest gate
still describes the thing being playtested, and what the second half of 0.6
actually is. These rows are that work.

## Authority and non-negotiable outcome

- You may create local branches and isolated Git worktrees, assign work to
  sub-agents, commit, merge accepted branches, resolve in-scope conflicts, and
  merge the fully accepted integration branch back into the starting branch.
- Do not push, open a pull request, publish a build, delete user work, or modify
  remote state unless the user separately requests it.
- Existing dirty and untracked files belong to the user. Record them at
  preflight, never copy them into worktrees, never stage them, and never use
  reset, clean or checkout commands that could discard them.
- `balance06_1`, `integ06_1`, `perf06_1` and `pusherv3_11` are audits. An audit
  that finds nothing is a suspicious audit — but a fabricated finding is worse.
  Report what is there, with evidence.
- **No release activity.** No version bump, no tag, no packaging, no publish, no
  final balance tuning. `release06_1` remains the only row permitted to do any
  of that, and it stays parked.

## 1. Preflight and immutable baseline

1. Capture and report: absolute repository path; starting branch and exact HEAD;
   upstream/ahead/behind; tracked modifications and untracked paths; existing
   worktrees and branches matching `codex/cross-*`; available agent concurrency;
   supported validation and test commands with their practical runtimes.
2. Create `codex/cross-completion-integration` from the exact starting HEAD in an
   isolated worktree. Record its path. All accepted work merges here first.
3. If the ten task contracts and this launcher are not present in the starting
   commit, copy only their exact current contents into the integration worktree
   and commit them as `cross06_0: add cross-cutting program contracts`.
4. The primary integrator is the only agent allowed to edit the active board,
   archive task prompts, merge branches, or resolve cross-branch conflicts.
5. Establish a live program ledger containing branch, worktree, owner, file
   ownership, base commit, dependencies, status, reviewer, findings, test
   evidence, accepted head, merge commit, and cleanup status.

## 2. Branch topology

- `codex/cross-meta` for `meta06_1`;
- `codex/cross-balance` for `balance06_1` (report-only, plus proposals);
- `codex/cross-board` for `board06_1`;
- `codex/cross-pusher-audit` for `pusherv3_11`;
- `codex/cross-teach` for `teach06_2`;
- `codex/cross-audio` for `audio06_1`;
- `codex/cross-integ` for `integ06_1`;
- `codex/cross-perf` for `perf06_1`;
- `codex/cross-playtest` for `playtest06_2`;
- `codex/cross-polish` for `polish06_0`;
- `codex/cross-remediation` only for findings that cannot cleanly return to an
  owning branch or row.

Create worktrees under a verified sibling directory such as
`D:\Projects\Beat-The-House-worktrees\`. Resolve every path before creation or
cleanup. Never recursively delete a computed path; use `git worktree remove`
after verifying the registered path and only after the branch is safely merged.

## 3. Scheduling

### Wave 1 — start immediately, fully parallel

`meta06_1`, `balance06_1`, `board06_1` and `polish06_0`. None depends on the
depth programs. `board06_1` touches the board and docs only and must be
coordinated with the other family integrators so no one is editing the board at
the same moment — hold its merge until they confirm a quiet window.

`polish06_0` produces prompts and a program document, not code. Its output stays
parked; do not let it start any polish work it defines.

### Wave 2 — after `pusherv3_10`

`pusherv3_11`. It is an audit of a program that ran across ten rows and must be
owned by an agent that implemented none of them.

### Wave 3 — after Families 1 and 2 merge

`audio06_1`, then `integ06_1` and `perf06_1` in parallel. `integ06_1` and
`perf06_1` must run on a tree that already contains both depth programs;
running them earlier produces a report about a game that no longer exists.

### Wave 4 — after Wave 3

`teach06_2`, then `playtest06_2` last. `playtest06_2` amends the playtest gate
and must know what the other nine rows found.

Findings from `balance06_1`, `integ06_1`, `perf06_1` and `pusherv3_11` are
routed as new `fix06_*` rows or returned to the owning family, not silently
fixed inside an audit branch. An audit branch that quietly rewrites product code
has destroyed its own evidence.

## 4. Standing rules for every worker

- Determinism is seeded from run RNG; everything ticks at action boundaries,
  never on wall-clock time.
- The idle-liveness counter-gate in `scripts/ui/performance_liveness_guard.gd` is
  mandatory wherever a surface is touched. An idle draw cost of 0.000 is a
  failure, not a pass.
- Meta remains Players-Card-only per roadmap owner decision #1. No row here may
  add a cross-run progression system.
- Voice obeys the Voice Bible register split and brevity rule.
- No row here changes RTP, EV, payout tables, odds or any landed economic
  contract value. `balance06_1` may propose changes; only `release06_1` may
  apply tuning.

## 5. Mandatory branch self-review protocol

Before requesting review, every implementer stops editing and produces a branch
handoff containing: exact base and head commits plus `git status` proving only
intended files; the commit list with one-sentence purposes; a prompt checklist
mapping every owned requirement to file, symbol, test and capture;
`git diff --check` and a diff-stat ownership audit; a full base-to-head diff
review for debug code, TODO stubs, dead paths, generated files, hardcoded test
shortcuts, privacy leaks, non-deterministic time or randomness, duplicated
consequences and save hazards; test, determinism, parity, performance, visual and
accessibility evidence with exact commands and results; and known risks or
assumptions, where "None" must be explicit.

For the audit rows, the equivalent handoff is the report itself plus the exact
commands, seeds, builds and measurements behind every claim in it.

## 6. Mandatory independent review protocol

Assign a reviewer who did not author the branch. The reviewer independently
checks the full diff and commit boundaries; correctness, state ownership,
migrations, idempotency, determinism and platform behavior; tests for false
positives, missing negative cases and weakened assertions; and actual
player-facing behavior rather than state flags. For audit rows the reviewer
re-runs a sample of the measurements and confirms the numbers reproduce.

Findings are `P0` (data loss, security, unshippable), `P1` (incorrect or missing
required behavior), `P2` (material quality gap) or `P3` (non-blocking polish).
P0/P1/P2 require a fix or a written owner-approved exception. The reviewer
issues exactly one of `ACCEPT <exact-head>` with evidence, or
`REJECT <exact-head>` with actionable findings. Acceptance is invalid after the
head changes.

## 7. Commit and merge discipline

- Preserve individual logical commits; do not squash a task into one commit.
- Commit messages use the task id and outcome, for example
  `meta06_1: surface the crew heist route on the career screen`.
- Before every merge verify a clean integration worktree, the expected head,
  recorded reviewer acceptance, diff and check results, and no unrelated files.
- Merge with non-interactive `git merge --no-ff`. Resolve conflicts only in the
  integration worktree, inspect every hunk, rerun both sides' focused tests, and
  never use blanket "ours" or "theirs" for product or data files.
- Do not stage `.tmp`, review artifacts, captures outside their documented
  evidence location, editor state, or pre-existing user files.

## 8. Final merge back to the starting branch

Only after every schedulable row is DONE or archived and every audit report is
delivered: verify the integration worktree is clean; run `git diff --check`,
project validation, the full supported foundation matrix, 10-seed determinism,
native/Web parity, performance, accessibility, save and migration, and visual QA
on that exact head; produce a program closure report listing every row, its
branch, reviewer, accepted head and merge commit, plus every audit finding and
where it was routed; return to the original working tree and confirm its tracked
state is unchanged since preflight; merge `codex/cross-completion-integration`
with `--no-ff` without squashing or force-updating; run a final validation; then
remove only clean registered worktrees whose accepted heads are reachable from
the final branch.

## 9. Communication and terminal conditions

Send concise progress updates at wave boundaries, after reviews, after each
merge, and whenever an audit finding reopens work elsewhere. Never describe a row
as complete before its reviewer accepts the exact head. If a test is flaky,
diagnose and fix determinism; do not rerun until lucky or loosen thresholds.

A genuine blocker must include three attempted safe approaches, exact evidence,
affected prompt rows, preserved branch heads, and the smallest user decision
needed. Hard work, long tests and review findings are not blockers.

Your final response must lead with the outcome and include starting and final
branch and commits, all created branches, reviewer verdicts, merge commits, every
audit's headline findings and where each was routed, the complete gate table,
report paths, any retained worktrees or branches, and explicit confirmation that
pre-existing user files were not staged or modified and that no release activity
was performed.
