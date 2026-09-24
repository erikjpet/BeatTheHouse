# rw06 RESET step 1 — Consolidate everything onto main

Status: TODO. Self-contained. Launch with this file only. Run it ALONE: all
other agents must be stopped first.

## Why

The owner stopped all agents on 2026-09-24. Too much time went into testing and
evidence, and work is spread over about 15 branches and 17 worktrees. Your only
job: get **every piece of implementation work onto `main`**, leave **no branch
or worktree behind**, and leave `main` launching.

## Owner rules (binding)

- **No testing.** No test suites (Smoke/Contract/Full), no focused contracts, no
  audits, no verification passes, no new test files, no evidence hashes.
- Your only check is that the game still launches (see "Confirmation").
- Don't fix failing tests. Testing happens at the end of the release, not now.
- Never force-push or rewrite history. You may commit and push to `main`.
- Never upload or publish anything.

## Steps

1. **Inventory.** List every local and remote branch except `main` and
   `codex/wip-0.6-consolidated`, which is older and out of scope, so leave it
   alone. List every worktree under `D:\Projects\Beat-The-House-worktrees\`.
   Check each worktree for uncommitted work: commit it to that worktree's branch
   first ("WIP at reset") so nothing is lost.
2. **Merge into `main`, one family at a time.** Within a family, merge the
   branch that contains the others first, then any remaining unique commits.
   - rw06_1 rooms: `rw06_1-phase0`, `-visual-evidence`, `-grand-authority-fixture`,
     `-semantic-fixture-authority`, `-hand-meta`, `-hand-other`.
   - rw06_2 endings: `rw06_2-prep`, `-heist-seed-preflight`, `-corridor-fix`,
     `-cheat-barred`, `-cheat`, `-heist`.
   - rw06_6 pull-tab glimmer: `rw06_6-pull-tab-glimmer`, `-red`.
   - `rw06-forensic-archives` has no commits ahead of `main`, so just delete it.

   Resolve conflicts by keeping both sides' implementation. When two versions of
   the same logic truly conflict, keep the newer one and note it in the
   handoff. Unfinished work merges anyway: the next agents finish it on `main`.
3. **Clean up.** After each family merges and is pushed, delete its branches
   locally and on origin, and remove their worktrees. Also remove stray
   `.godot_leases` entries.
4. **Put the docs on `main`.** Commit any uncommitted owner/plan files in the
   primary checkout: `docs/todo/rw06_*.md`, `rw06_2p_status.md`, and the
   questions file.
5. **Confirmation (the only check).** Run
   `tools/validate_project.ps1` once, and launch the game once headless with the
   canonical Godot
   (`D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`),
   confirming it reaches the main menu and starts a new run without script
   errors. If a merge broke either one, fix the break (not the tests) and
   push.
6. **Handoff.** Write `docs/todo/rw06_reset_status.md` with:
   - what merged, and any conflicts where you picked one side;
   - a three-line "state of each lane": rooms / endings / pull-tab glimmer, each
     saying what works now and what's unfinished;
   - confirmation that `git branch -a` shows only `main` and
     `codex/wip-0.6-consolidated`, and `git worktree list` shows only the
     primary checkout (plus the wip-0.6 worktree).

   Commit, push, and stop.
