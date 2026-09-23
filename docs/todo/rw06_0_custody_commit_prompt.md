# rw06_0 — Verify the worker merge, commit the plan, organize todo

Status: TODO. Self-contained. Launch with this file only.

## Why

The postfix06_2 worker (row `rw06_pre`) merges its own finished fixes to `main`,
preserves its solver in history through the snapshot commit, and deletes its
branch. This row confirms that really happened, commits the release-week plan
files, and organizes the todo folder so `main` tells one coherent story.

## Preconditions (stop and report if any fail)

1. The worker reported MERGED, with a merge hash and a SNAPSHOT hash.
2. `git merge-base --is-ancestor <SNAPSHOT> origin/main` succeeds.
3. `docs/plans/postfix06_2_placement_harvest.md` is on `origin/main`.
4. `wip/postfix06_2-snapshot` no longer exists locally or on origin. If it still
   exists and its tip is an ancestor of `origin/main`, delete it (local and
   remote) and record that. If its tip is **not** an ancestor, stop and report:
   there is unmerged work.
5. `git worktree list` shows no postfix06_2 worktree. Prune any stale entries.
6. The primary checkout `D:\Projects\Beat-The-House` is on `main` with no tracked
   modifications.

## Owner questions (binding for every agent)

All owner decisions, including the hard gates, go through
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Always use that absolute path (the primary checkout copy). Follow
its protocol:

- append a short, precise question with options and a recommendation;
- mark your work `WAITING Q-NNN`;
- keep working on anything that doesn't depend on the answer.

Read the file at the start of every session. Pick up any ANSWERED entry whose
`Resume` is yours, even if another agent asked it. Never talk to the owner any
other way, and never stall waiting.

## Rules

- You may commit to `main` and push `origin main`. Never force-push. Never
  rewrite history. Never stage `.tmp/`.
- Never weaken a test, budget, liveness floor or deterministic assertion.
- Serialize Godot runs.

## Work

### Commit 1: plan files (made IN the primary checkout)

The plan files exist only as untracked files in the primary checkout
`D:\Projects\Beat-The-House`, and the owner keeps editing
`rw06_owner_questions.md` there. Commit them **in place**. If you committed them
from a worktree instead, the untracked copies would block every later
`git pull` in the primary checkout.

In the primary checkout:

1. `git pull --ff-only`
2. Stage exactly these files:

- `docs/todo/README_0_6_release_week.md`
- all `docs/todo/rw06_*.md`, including `rw06_owner_questions.md` with the owner's current edits
- `docs/plans/0.6.1_backlog.md`

3. Commit ("Add 0.6 release-week plan"), then `git push origin main`.

After this, the primary checkout tracks these files. Keep it on `main` and
current with `git pull --ff-only`.

Do commit 2 in a worktree off the new `origin/main`, then fast-forward `main`.

### Commit 2: organize the todo folder (archive, never delete)

- Add a banner at the top of `docs/todo/README_0_6_board.md`, and replace its
  "Current owner-directed sequence" section with a pointer to
  `README_0_6_release_week.md`.
- Move `postfix06_2_post_fix_remediation_ledger.md` to `docs/todone/`, after
  confirming the worker's ledger updates are in it.
- Move superseded prompts to `docs/todone/`, each with a one-line
  `Superseded 2026-09-22 by rwNN` header:
  - `release06_1_ship_prompt.md` (by rw06_4)
  - `balance06_2_post_playtest_tuning_prompt.md` (by rw06_3)
  - `playtest06_2_playtest_gate_refresh_prompt.md` (by rw06_2 and rw06_4)
  - `fixsweep06_1_extended_playtest_bug_sweep_prompt.md` (already DONE)
  - `health06_1_code_health_remediation_prompt.md`, only if its work is
    verifiably on `main`. Otherwise move it to `docs/todo/deferred_0_6_1/`.
- Move deferred prompts to `docs/todo/deferred_0_6_1/`:
  - `voice06_1`
  - `cleanup06_1`
  - `triage06_1`
  - `balance06_1_follow_on`
  - both `perf06_1` prompts
  - `tutorial_first_time_player_completion_prompt.md`
- The `release06_1_*_template.md` files stay in `docs/todo/`, because rw06_4
  uses them.

## Verification

1. `tools/validate_project.ps1`
2. `tools/check_godot.ps1 -Suite Smoke -RequireGodot`
3. `tools/check_godot.ps1 -Suite Contract -RequireGodot -KeepGoing`. Record the
   failing-shard count. Only room/scenario composition reds may remain, until
   rw06_1.

## Finish

- Push `main`. Set rw06_pre and rw06_0 to DONE in `README_0_6_release_week.md`.
  Fill in the scoreboard (Smoke, Contract failing shards, open P1/P2) and add a
  history line. Archive this prompt, with its execution record filled in, to
  `docs/todone/` in the same commit.
- `git branch -a` must show no leftover postfix06_2 branch.
