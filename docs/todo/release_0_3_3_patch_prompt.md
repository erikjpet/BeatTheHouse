# Agent Prompt — Cut and Package the 0.3.3 Patch Release

Copy everything below this line into the agent.

---

You are cutting **0.3.3**, a fixes-only patch release of Beat the House, from
commit `cc9657d` (or the current tip of `main` if later doc-only commits
exist). Follow the documented release procedure in
`docs/plans/0.3.2_release_checklist.md` — this prompt only states what differs.

## Why this release exists

0.3.1 and 0.3.2 are **closed internal releases** (ledgers:
`docs/plans/0.3.1_release_checklist.md`, `docs/plans/0.3.2_release_checklist.md`)
whose packaged zips were built at LD.2 close. **Eight post-close playtest
hotfixes landed after packaging** (`e43a148` through `49b09ee`: table
animation regressions, idle liveness scheduling, slot autoplay one-click,
pull-tabs duplicate canvas, roulette full-wheel motion/labels/bet hot path,
canvas pointer duplicate suppression). The existing 0.3.2 artifacts therefore
contain known visual regressions and MUST NOT be uploaded. 0.3.3 = 0.3.2 +
those hotfixes + tooling/doc changes. No new content, no balance changes.

## Hard constraints

1. **Clean tree only.** Run `git status --porcelain` first; it must be empty.
   Execute this release from a clean clone/checkout (the work-agent server),
   NEVER from the project-manager machine's working tree, which carries
   in-progress feature work (home environment, inventory extraction, playtest
   root fixes) that is not part of this release.
2. Version stamp `0.3.3` in `project.godot` and all export presets
   (`export_presets.cfg`): Windows file/product, Android name (code `6`),
   iOS short/build. Commit the stamp before running the heavy gates, matching
   prior release discipline.
3. Do not re-run the 180-minute soak for this patch; the 0.3.2 soak plus the
   hotfixes' evidence commits stand. Run everything else in the 0.3.2 gate
   matrix.

## Gate matrix (all must pass on the stamped tree)

1. `tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 1800 -ReportDir .tmp\r033_full_suite`
3. `tools\foundation_performance_probe.ps1 -RequireGodot`
4. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix R033-DETERMINISM`
5. `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200`
6. `tools\foundation_mouse_batch_playtest.ps1 -RunCount 60 -RequireGodot -AllowRunFailures -OutputRoot .tmp\r033_mouse_batch_60`
7. `tools\web_perf_smoke.ps1`
8. Exports: `tools\export_itch.ps1 -Target web` then `-Target windows`;
   record sizes and SHA256 hashes.

## Deliverables

1. `docs/plans/0.3.3_release_checklist.md` in the exact format of the 0.3.2
   checklist: release identity, gate matrix with results, artifact hashes,
   accepted limitations (carry forward the 0.3.2 ones that still apply),
   release decision.
2. Move this prompt to `docs/todone/` with an execution record per
   `docs/todone/RULES.md`, in the same commit as the checklist.
3. Push. Uploading the zips to itch.io remains a manual operator action —
   report the artifact paths and hashes and stop there.
