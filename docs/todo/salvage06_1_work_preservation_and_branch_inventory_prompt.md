Status: TODO — run in a SEPARATE agent, not the `land06_0` project manager

# Agent Prompt — salvage06_1: Work Preservation and Branch Inventory

Copy everything below this line into a dedicated agent. This agent runs
alongside the `land06_0` project manager and must not disturb it.

---

You are working in `D:\Projects\Beat-The-House`. Your job has two halves:
make it impossible to lose any existing work, and give the `land06_0` project
manager a definitive map of every branch and every piece of outstanding work.

You are not the project manager. You do not land rows, review implementations,
validate gates, or decide dispositions. You preserve, inventory and report.

## Absolute constraints

- **Never delete anything.** No `git worktree remove`, no branch deletion, no
  `git stash drop` or `clear`, no `git gc`, no `reset --hard`, no `clean`, no
  force-anything. If a task seems to require deletion, it is out of scope.
- **Never disturb the project manager.** It is actively landing rows and owns
  `main`, `docs/todo/README_0_6_board.md`, and the `codex/land06-*` branches. Do
  not edit the board. Do not check out any branch in the primary working tree at
  `D:\Projects\Beat-The-House`. Do not change what any existing worktree has
  checked out. Operate read-only per worktree with `git -C <path>`, and create
  your own worktree if you need one.
- **Owner property is untouchable.** `.tmp/`, `.tools/`, `review_artifacts/`,
  editor state and build output are the owner's. Never stage them, never move
  them, never remove them.
- Never push, never modify remote state, never perform release activity.
- Preservation commits are **unreviewed and unvalidated by definition.** Label
  them as such. Do not run gates on them and do not present them as ready.

## 1. Preserve the four known at-risk items first

These are confirmed. Handle them before the general sweep, in this order.

### 1.1 Unreachable commits — highest risk

`D:\Projects\Beat-The-House-worktrees\pusherv3_4_agent` sits at detached HEAD
`2b59309e` ("Capture Pusher v3 feel through production sessions", 2026-08-18),
with at least two ancestors `e5fe1a11` and `ccf288fa`. **That head is reachable
from no branch.** It survives only via the worktree HEAD and the reflog. Removing
that worktree, or a garbage collection, destroys it.

Give it a branch name immediately — for example
`salvage/pusherv3_4_agent_2b59309e` — pointing at that exact commit, without
checking it out anywhere. Verify afterwards that `git branch --contains 2b59309e`
lists it.

Then sweep every other worktree for the same condition: any detached HEAD whose
commit is contained by no branch. Name each one the same way.

### 1.2 The stash

`stash@{0}` is "On codex/depth-env-runtime: wip env06_6 atomic consumer handoff",
holding `scripts/core/scenario_host_transaction.gd` at +355/−11 lines. That is
substantial `env06_6` work living in the single most losable place in git.

Preserve it as a real commit on a branch — for example
`salvage/env06_6_atomic_consumer_handoff_stash` — without dropping the stash.
The stash stays exactly where it is; you are duplicating it to safety, not
moving it.

### 1.3 Orphaned uncommitted work — `env06_6` lifecycle

`D:\Projects\Beat-The-House-worktrees\depth-env-lifecycle-remediation`, on branch
`codex/depth-env-runtime-4`, holds five modified tracked files, roughly 217
insertions and 37 deletions, idle since roughly 10:04 on 2026-08-26:

```
scripts/core/scenario_engine.gd
scripts/core/scenario_sequence_runtime.gd
scripts/tests/foundation/scenario_sequence_contract.gd
scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd
scripts/ui/foundation_main.gd
```

This is `env06_6` lifecycle work, orphaned when the depth-program integrator was
stood down. It exists only as working-tree edits. Commit it **on its own branch**
as an explicitly-labelled work-in-progress preservation commit. Do not merge it,
do not land it, do not validate it.

### 1.4 Stale detached worktree edits

`D:\Projects\Beat-The-House-worktrees\golden_ref` has one modified tracked file,
`scripts/tests/ui_scene/compile_components_and_main_flow.gd`, untouched for about
eight days. Preserve it the same way and mark it low-confidence: it is probably a
dead experiment from a closed wave, but that is a judgment for the PM, not you.

## 2. Sweep everything else

Enumerate every registered worktree — there are roughly forty — and for each
record: path, branch or detached head, whether that head is reachable from a
branch, tracked modifications, untracked files that are not ignored, and the
newest write time excluding `.git`, `.godot` and `.tmp`.

Preserve every uncommitted tracked change you find, on its own clearly named
branch, with a message stating it is unreviewed preservation. Untracked files
that are ignored build output or owner artifacts are not preserved — but list
them if a committed report or ledger references them as evidence, because a
citation to a file nobody preserved is a broken evidence chain and the PM needs
to know.

Also check for any other loss vector you can find: reflog-only commits, worktrees
whose branch was reset out from under them, and orphaned merge or rebase state.

## 3. Build the definitive branch and work inventory

Produce one document that lets the project manager see the entire remaining
landscape without re-deriving it. For **every** `codex/*` and `salvage/*` branch:

- exact head and short summary of its tip commit;
- commits ahead of and behind `main`, and its merge base;
- last activity timestamp;
- which 0.6 board row or program it belongs to, if any;
- classification, one of: **LANDED** (fully reachable from `main`),
  **FINISHED-UNLANDED** (complete and reviewed but not on `main`),
  **WIP** (in progress or partial), **SUPERSEDED** (its content is obsolete),
  **STALE** (from a closed wave, no remaining value), or **UNKNOWN** (say so
  rather than guessing);
- what it contains, in one or two concrete sentences — file areas and purpose,
  not commit-message paraphrase;
- whether it is entangled: carrying other rows' commits, ledgers, reverted
  merges, or sitting behind `main`;
- your recommended disposition for the PM to decide on.

Known starting points, all to be verified rather than trusted: roughly ten
branches sit ahead of `main`, including `codex/cross-completion-integration`
(~115 commits), `codex/depth-env-runtime-2` (~29, holding the independently
accepted `env06_6` static implementation at `a5ae1d8f`),
`codex/depth-env-runtime-5` (~18), `codex/cross-board` (~17, the board split),
`codex/depth-env-runtime-4` (~16), `codex/cross-pusher-audit` (~14),
`codex/cross-polish` (~8, `polish06_0` accepted with no findings),
`codex/cross-meta` (~7, `meta06_1` implementation), and `codex/cross-balance`
(~6, `balance06_1` finalized and verified at `1c0dec3b`).

Then cross-reference against the board: list every 0.6 row that has committed
work somewhere, and every row that has none. The PM has landed a small fraction
of the program while finished work sits uncollected; the value of this document
is showing exactly what is already done and merely waiting.

## 4. Write the anti-loss rules

Add a short, blunt section to the same document stating the rules that keep this
from recurring, at minimum:

- No worktree is removed until its uncommitted tracked changes are committed and
  its head is reachable from a branch.
- No branch is deleted while it holds commits not reachable from `main`.
- Stashes are preserved as branches before any cleanup.
- Detached heads get branch names the moment they are noticed.
- Cleanup is a deliberate task with its own verification, never a step tacked on
  to the end of something else.

## 5. Land the inventory on `main`

The inventory document is documentation only. It cannot break a gate, so it is
safe to land directly, but you are sharing `main` with an active project manager.

Write it to `docs/plans/0.6_branch_and_work_inventory.md`. Then:

1. Record `main`'s exact head.
2. Commit **only that one file**, as
   `salvage06_1: inventory all branches and preserve at-risk work`.
3. Before merging, re-check `main`'s head. If it moved, rebase your single commit
   onto the new head and re-verify your file is the only change.
4. Merge to `main` with `--no-ff`. Never force. If you cannot land cleanly in
   three attempts, stop and hand the branch name to the owner rather than
   fighting the PM for the branch.

Preservation branches are **not** landed. They stay as branches until the PM
decides what to do with each.

## 6. Report

Your final response leads with: how many at-risk items you preserved and where
each now lives, how many worktrees and branches you inventoried, and the count of
rows with finished-unlanded work.

Then include: the four known items and their disposition, anything further you
found, the inventory document's path and its commit on `main`, every preservation
branch name with what it holds, any evidence citation you found pointing at an
unpreserved file, and explicit confirmation that you deleted nothing, edited no
board, disturbed no worktree checkout, and touched no owner artifact.

Address the report to the project manager as well as the owner — it is the
handoff that tells the PM what it already has.
