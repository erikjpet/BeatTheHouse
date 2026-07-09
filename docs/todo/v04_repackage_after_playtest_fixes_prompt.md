# Agent Prompt - v0.4 Repackage After Playtest Fixes

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). The owner's playtest produced CRITICAL fixes
(idle-animation liveness, meta home lag/phantom-items/top-bar) that
post-date the packaged 0.4.0 builds, so `builds/itch/*.zip` and the hashes
in `docs/plans/0.4_release_checklist.md` no longer describe the release
tree. This task re-verifies and re-packages so the publish audit passes
against the FIXED tree.

## Preconditions (verify, else stop)

1. Both CRITICAL playtest-fix prompts are archived in docs/todone/ with
   execution records, and QUEUE.md shows no other ready/claimed fix work.
2. `git status --porcelain` is clean.
3. The owner has not reported additional unresolved playtest issues in
   QUEUE.md notes.

## Required work

1. Re-run the release-grade verification affected by the fixes (not the
   full 3h matrix — the final-gate evidence still stands for everything
   the fixes did not touch; scope honestly and record what you reran and
   why it suffices):
   - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
   - `tools\check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 1800`
   - `tools\foundation_performance_probe.ps1 -RequireGodot` (now including
     the liveness-aware budgets and the home-open budget)
   - `tools\foundation_mouse_batch_playtest.ps1 -RunCount 20 -RequireGodot`
   - `tools\web_perf_smoke.ps1`
2. Re-export both packages via `tools\export_itch.ps1 -Target web` and
   `-Target windows`; record sizes and SHA256 hashes.
3. Update `docs/plans/0.4_release_checklist.md`: replace the package
   artifact rows with the new sizes/hashes and append a "Playtest Fix
   Addendum" section listing the fix commits, the gates rerun with
   results, and the re-export evidence. Do not rewrite prior sections.
4. Confirm version stamps are still 0.4.0 everywhere (the fixes must not
   have touched them).

## Done gate

- All commands above pass; both zips rebuilt with hashes recorded in the
  updated checklist; addendum written.
- Prompt archived to docs/todone/ with an execution record; QUEUE.md
  updated (this unblocks the publish entry's package-freshness condition).
  Commit per the queue lifecycle.
