# Execution Record (2026-07-09)

- Claimed in `docs/todo/QUEUE.md` on 2026-07-09 and committed as `81082b1`.
- Preconditions verified before package work: both CRITICAL playtest-fix
  prompts were archived with execution records, no unresolved ready/claimed fix
  work remained in the queue, the tree was clean after `4377545`, and no Godot
  process was running before gates.
- Scope rerun: release-grade gates affected by the playtest fixes and package
  freshness were rerun instead of the full multi-hour release matrix, matching
  this prompt's scoped repackage instruction.
- Root cause found during repackage: exported Web table surfaces were still
  driving expensive idle redraws under Chrome 4x CPU throttle, which caused
  `tools\web_perf_smoke.ps1` to fail on baccarat, roulette, bar-dice, and
  blackjack idle budgets even though native probes passed.
- Fix commit: `3990ae2` adds a Web-only low-detail idle path for table surfaces
  and slows idle-only redraw cadence when no animation channel, overlay, or
  handoff is active. Active animations keep the normal redraw cadence.
- Verification:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`:
    PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1
    -RequireGodot -Suite Full -TimeoutSec 1800`: PASS; report
    `.tmp/test_reports/20260709_015947_full/summary.json`.
  - `powershell -ExecutionPolicy Bypass -File
    tools\foundation_performance_probe.ps1 -RequireGodot`: PASS; all seven
    game surfaces plus meta home, talk dock, dialogue, and eviction covered;
    `meta_home_open` 233.488ms under the 450ms budget.
  - `powershell -ExecutionPolicy Bypass -File
    tools\foundation_mouse_batch_playtest.ps1 -RunCount 20 -RequireGodot`:
    PASS strict; 20/20 playable, R100 20/20, victories 20/20, true failures 0.
  - `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1`: first
    run failed on Web table idle budgets; after `3990ae2`, PASS with Chrome 4x
    ready 14,378ms / 20,000ms and report
    `.tmp/web_perf_smoke/report.summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target web`:
    PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target windows`:
    PASS.
- Rebuilt artifacts:
  - `builds/itch/BeatTheHouse-web.zip`: 17,177,826 bytes, SHA256
    `E364B27C765D8B82B6C525A1CDF248D013BDE69BD1643D104E48883256816F71`.
  - `builds/itch/BeatTheHouse-windows.zip`: 43,657,926 bytes, SHA256
    `2D40849FF927EB47772A889D8F5735D7CAABE3D24030493A480C4729B90EA363`.
- Documentation updated: `docs/plans/0.4_release_checklist.md` package rows
  were refreshed and a Playtest Fix Addendum was appended.
- Queue update: this prompt was removed and
  `v04_publish_and_tag_prompt.md` was unblocked for owner-launch only.
- Deviations: none from the prompt. No push, tag, upload, or publish action was
  performed.

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
