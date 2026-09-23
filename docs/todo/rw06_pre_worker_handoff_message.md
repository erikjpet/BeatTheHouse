# rw06_pre — Worker steer: finish on a branch, merge to main, delete the branch

Status: TODO. The owner sends the block below to the running postfix06_2 worker
at the same moment the execution agent is launched
(`rw06_execute_release_week_prompt.md`). The execution agent prepares in its own
worktrees and does not write to `main` until this row reports MERGED.

End state of this row:

- All of the worker's finished work is on `main`.
- All of its solver work is permanently in `main`'s history through the merged
  snapshot commit, so nothing is lost.
- The unfinished solver is not active in production.
- The branch is deleted locally and on origin, and its worktree is removed.

Nothing is left unmerged.

```text
Owner direction change (2026-09-22). We are cutting 0.6 to a one-week release plan (target 2026-09-29). Read docs/todo/README_0_6_release_week.md. Room placement is being redesigned as fixed, modular per-room slots with an overflow action list (docs/todo/rw06_1_fixed_slot_rooms_prompt.md). That replaces the general placement solver and the full qualification campaign.

A separate execution agent starts in parallel now. It will NOT write to main or to D:\Projects\Beat-The-House, and will run no Godot process, until you report MERGED. You own getting your work onto main. Stop optimizing the solver and do not start the 180-minute soaks or the full campaign. Your work must not be lost, and your branch must not be left unmerged. If you need an owner decision, append a short question to D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md following its protocol, and continue with other steps meanwhile. Keep that file untracked, like the other PM files. Do this to completion:

1. SAFE STOP. Reach a safe stopping point and make sure no Godot process is running.

2. SNAPSHOT. In D:\Projects\Beat-The-House: `git switch -c wip/postfix06_2-snapshot`. Stage ALL your tracked and untracked changes EXCEPT the PM files, which must stay untracked: docs/todo/README_0_6_release_week.md, docs/todo/rw06_*.md, docs/plans/0.6.1_backlog.md. Never stage .tmp/. Include reports/playtest_2026-09-21/. Commit "postfix06_2 snapshot: all work as of handoff" and push -u. Record this commit hash as SNAPSHOT.

3. WORKTREE. `git switch main` in the primary checkout, then continue in a worktree of your branch at D:\Projects\Beat-The-House-worktrees\postfix06_2-snapshot.

4. HARVEST REPORT. Write docs/plans/postfix06_2_placement_harvest.md with:
   (a) Every placement piece you built (safe-exit corridor reservation, live base-control inclusion, exclusive 44px authority validator, renderer/authority geometry sync, repack/displacement, composition enumerator 55/415/177, exact historical seeds, initial-generation receipt, audit/grounding tools, and any others). For each: files and functions, what it does, a verdict of KEEP / ADAPT / DROP for a fixed-slot system and its static validator, and the exact SNAPSHOT path, so it can be recovered with `git show SNAPSHOT:<path>`.
   (b) Which hunks in each mixed file belong to which ledger row.
   (c) The true current status of every ledger row.

5. DEACTIVATE THE UNFINISHED SOLVER (one commit on the branch). Return placement production code to its b7c51bf4 behavior: scenario_layout_resolver.gd, environment_instance.gd, pixel_scene_canvas.gd, placement_surfaces.json, developer_placement_overrides.json, plus the placement hunks in mixed files. Keep every finished non-placement row (GP-PF-001…005, UIENV-PF-001/002, AIF-001…004, CR-PF-001, RP-001…012; RP-006 is the production accounting only, its packaged proof moves to rw06_4). New or changed placement tests and tools may stay only if they pass and add no new Contract failure; otherwise remove them in this commit and list them in the harvest report as recoverable from SNAPSHOT. If a finished row truly depends on a placement hunk, keep the minimum needed and document it. Update the ledger: placement rows become "SUPERSEDED → rw06_1"; each pending campaign row points to rw06_4 or the 0.6.1 backlog, matching those files.

6. VERIFY on the branch head:
   - tools/validate_project.ps1
   - tools/check_godot.ps1 -Suite Smoke -RequireGodot
   - the focused contracts from the ledger's verification column
   - tools/check_godot.ps1 -Suite Contract -RequireGodot -KeepGoing on both b7c51bf4 and your head, with NO failing shard that b7c51bf4 did not already fail
   Never weaken a test, budget, liveness floor or deterministic assertion.

7. MERGE AND CLEAN UP.
   - `git fetch`. If origin/main has moved, merge it into your branch and re-run Smoke.
   - In the primary checkout: `git switch main`, `git pull --ff-only`, `git merge --no-ff wip/postfix06_2-snapshot -m "Merge postfix06_2: finished fixes; solver preserved in history, superseded by rw06_1"`, then `git push origin main`.
   - Confirm SNAPSHOT is an ancestor of origin/main: `git merge-base --is-ancestor SNAPSHOT origin/main`.
   - Then `git worktree remove` your worktree, `git branch -d wip/postfix06_2-snapshot`, and `git push origin --delete wip/postfix06_2-snapshot`.
   - Never force-push.

8. REPORT "MERGED": the merge commit hash, the SNAPSHOT hash, the Smoke and Contract results, and anything you had to keep because of a dependency. Your work is then complete.
```
