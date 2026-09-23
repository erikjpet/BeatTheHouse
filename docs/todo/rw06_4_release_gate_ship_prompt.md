# rw06_4 — 0.6.0 release gate and artifact handoff

Status: TODO. Self-contained. Launch with this file only.
Depends on rw06_1, rw06_2, rw06_3 and rw06_5 being DONE. This replaces
`release06_1_ship_prompt.md` (archived) with the owner-approved smaller gate.
The larger gates are listed in `docs/plans/0.6.1_backlog.md`.

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

## Deliverable

Two upload-ready zip files: the **itch.io Web build** and the **Windows `.exe`**,
both at version 0.6.0, built with `tools/export_itch.ps1` without `-Push` and
ready for owner playtesting. Before artifact handoff, verify both from the exact
packages:

- the Web build loads in a browser;
- the `.exe` launches and shows version 0.6.0;
- each can reach the first room and play a game;
- save and Continue work.

Agents never run `export_itch.ps1 -Push`, butler, or any upload or publish
command. The owner always uploads both zip files personally.

## Hard owner gates (ask in the questions file, never assume)

1. **Source approval** before packaging.
2. **Artifact approval** after both exact zip files pass every packaged gate.
3. **Artifact handoff/upload confirmation**: post both zip paths and SHA-256
   hashes in the questions file. The owner uploads them personally and answers
   when complete. Only then may the exact source be tagged `v0.6.0`.

Each gate is a question in `rw06_owner_questions.md`. While a gate is waiting,
keep doing work that doesn't depend on it: records, copy drafts, evidence.

Any code change after an approval invalidates the candidate: rerun the affected
gates and rebuild.

## Gate (all on one frozen candidate commit)

1. `tools/validate_project.ps1`
2. `tools/check_godot.ps1 -Suite Smoke -RequireGodot`, including performance
   smoke budgets at current values.
3. `tools/check_godot.ps1 -Suite Contract -RequireGodot`: zero failing shards.
4. `tools/rw06_2_ending_replay.ps1` passes all three endings on the candidate.
5. Save migration: default mode of `integ06_1_v051_migration_smoke.gd`, all 37
   v0.5.1 fixtures admitted with a stable round trip.
6. `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`.
7. **One** 180-minute soak with feature music:
   `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28 -SeedPrefix RW06_4-SOAK`.
   It must show zero orphans and zero liveness failures, with state and caches
   within budgets.
8. Idle-liveness runtime:
   `tools/archive/perf06/perf06_idle_liveness_runtime_contract.gd`, with at least
   120 redraws and a positive draw cost. A 0.000 idle number without its
   liveness counter is a FAIL.
9. Packaged builds from `tools/export_itch.ps1`, for Windows and Web:
   - PCK manifest audit (`tools/audit_pck_manifest.py`);
   - a diagnostic launch of each package;
   - `tools/postfix06_2_feature_pcm_runtime.ps1` on each package (the remainder
     of RP-006);
   - a manual smoke: new run → first room → one game → save → Continue.

Mobile (Android/iOS) is not in 0.6.0.

## Release records

- Set the version to `0.6.0` in `project.godot`, export presets, README and
  CHANGELOG.
- Fill these templates, and have the owner approve the copy:
  - `docs/todo/release06_1_release_checklist_template.md`
  - `release06_1_final_rc_evidence_template.md`
  - `release06_1_devlog_post_template.md`
  - `release06_1_publish_copy_template.md`
  - `release06_1_talking_points_template.md`

  The trailer template is optional and can wait for 0.6.1.
- Update `docs/current_game_state.md` and the status line of
  `docs/plans/0.6_living_world_roadmap.md` to "shipped as 0.6.0 (<hash>)".
- After artifact approval, post both zip paths and SHA-256 hashes in the owner
  questions file. Do not run any upload or publish command. After the owner
  confirms there that they personally uploaded the artifacts, tag `v0.6.0` on
  the exact handed-off source and push the tag.

## Rules

- Never weaken a test, budget, liveness floor or deterministic assertion to get
  to green. On a gate failure, fix the root cause if it is small and scoped.
  Otherwise stop, report on the scoreboard, and wait for the owner.
- Serialize Godot runs.
- Evidence goes under `.tmp/rw06_4/`. Reference it from the RC evidence file.

## Finish

- Scoreboard: every gate item row set to green or red with an evidence path,
  plus a history line.
- Report to the owner the candidate hash, zip paths and SHA-256 hashes, and
  which owner gate is waiting.
- Work in a worktree branch, fast-forward `main` and push; never force-push.
  After shipping, `git branch -a` and `git worktree list` must show no leftover
  rw06 branches or worktrees. Delete yours, local and origin.
