# Execution Record (2026-07-09)

- Claimed in `docs/todo/QUEUE.md` and committed locally as `ece6bc7` before
  audit. The claim was not pushed until the pre-publish audit passed, honoring
  the prompt's "STOP before pushing anything if any audit step fails" rule.
- Confirmed `docs/todone/v04_repackage_after_playtest_fixes_prompt.md` was
  archived and `docs/plans/0.4_release_checklist.md` contained the fresh
  package hashes from the repackage task.
- Pre-publish audit:
  - `git status --porcelain`: clean.
  - Queue audit: no remaining ready/claimed entries except this publish prompt;
    post-release verification remained blocked until publish completion.
  - Required v0.4 chain archives audited: 12 required prompt archives existed
    in `docs/todone/` with execution records.
  - Package hash audit: `BeatTheHouse-web.zip` matched
    `E364B27C765D8B82B6C525A1CDF248D013BDE69BD1643D104E48883256816F71`;
    `BeatTheHouse-windows.zip` matched
    `2D40849FF927EB47772A889D8F5735D7CAABE3D24030493A480C4729B90EA363`.
  - Archive integrity audit: Web zip opened with 9 entries; Windows zip opened
    with 2 entries.
  - Version stamps audited: `project.godot` and `export_presets.cfg` remained
    stamped `0.4.0`.
  - Required reports existed:
    `docs/plans/v04_work_review_2026_07.md` and
    `docs/plans/v04_performance_pass_2026_07.md`.
  - Package freshness audit: rebuilt zips were newer than gameplay/export
    sources; latest source checked was `scripts/ui/game_surface_canvas.gd`.
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`:
    PASS.
- Remote audit:
  - `git fetch origin`: PASS.
  - `origin/main..HEAD`: local `main` was ahead by 38 commits.
  - `HEAD..origin/main`: empty, so no merge was required.
- Authorized git publish:
  - `git push origin main`: PASS; `main` advanced from `9904fda` to `ece6bc7`.
  - `git tag -a v0.4.0 -m "Beat the House 0.4.0 - Act 1 completion"`: PASS.
  - `git push origin v0.4.0`: PASS.
  - Tag target commit: `ece6bc7c453bbb178d49c2b8f670b29f9ccfaddf`.
  - Tag object: `11eae2964d8efe372ebc4d2704ef54d314f1f1e6`.
- `docs/plans/0.4_release_checklist.md` was updated with a Published section,
  including the pushed commit/tag and the owner-only itch upload instructions.
- `docs/todo/QUEUE.md` was updated to remove this prompt and unblock
  `v04_post_release_verification_prompt.md` as owner-launch only.
- Explicitly not performed: no `gh`, no butler, no login attempt, no GitHub
  Release object, and no itch upload.

# Agent Prompt - v0.4 Publish: Pre-Publish Audit, GitHub Push + Tag, itch Upload

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Every 0.4 queue task through
`v04_release_docs_packaging` is archived and the 0.4.0 packages are built.
This task **publishes the release to GitHub** and prepares the itch upload
for the owner. The owner launching this prompt IS the explicit
authorization for the git pushes it contains. No new credentials are
involved: pushes use the machine's existing stored git credentials (the
same path all queue pushes use); `gh` and `butler` are NOT used. If any
pre-publish audit step below fails, STOP before pushing anything and
report; do not publish a broken cut.

## Read first

- `docs/plans/0.4_release_checklist.md` (must exist with fresh evidence)
- `docs/plans/0.4_publish_copy.md`
- `docs/todo/QUEUE.md` and `docs/todone/` (chain completeness)
- `tools/export_itch.ps1` (butler invocation path)

## 1. Pre-publish audit (all must pass before any push)

1. `git status --porcelain` is clean; no stray untracked source files.
2. QUEUE.md has no remaining ready/claimed entries except this one and the
   post-release prompt; every v0.4 chain prompt (baseline, web audio, style
   guide, meta home + its CRITICAL rework, profile, act seam, review pass,
   performance pass, final gate, packaging) is archived in docs/todone/
   with an execution record.
3. `docs/plans/0.4_release_checklist.md` lists every gate with fresh PASS
   evidence and records both package SHA256 hashes; recompute the hashes of
   `builds/itch/BeatTheHouse-web.zip` and `BeatTheHouse-windows.zip` and
   confirm they match the checklist exactly. If the packages are stale
   relative to the final commit, STOP and report (do not re-export inside
   this task — that invalidates the gate evidence trail).
4. `project.godot` and export presets are stamped 0.4.0; the review and
   performance reports exist under docs/plans/.
5. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
   passes one final time.

## 2. GitHub publish (existing git credentials — no gh, no new logins)

1. `git fetch origin` and inspect `origin/main..HEAD` and `HEAD..origin/main`.
   If the remote has new commits, merge (never rebase — evidence ledgers pin
   commit hashes) and re-run the validate gate before continuing.
2. `git push origin main` (the machine's stored git credentials — the same
   path every queue push has used).
3. Tag and push: `git tag -a v0.4.0 -m "Beat the House 0.4.0 — Act 1 completion"`,
   `git push origin v0.4.0`.
4. Do NOT use `gh` or attempt to create a GitHub Release object; prior
   releases shipped as pushed tags only. The owner can add a web release
   later if desired.

## 3. itch.io upload — prepared for the owner, performed by the owner

Do NOT attempt butler or any itch upload; no itch credentials exist by
owner decision, and prior releases were uploaded manually via the itch
web page. Instead, prepare the manual step precisely:

1. Write an "Itch Upload — Owner Action" section into the checklist's
   Published section with: the two zip paths, their SHA256 hashes, target
   channels (web zip → the HTML/playable channel, windows zip → the
   Windows channel), and the user-visible version string 0.4.0.
2. Confirm both zips open cleanly (archive integrity check) so the owner
   never uploads a corrupt file.

## 4. Record

Append a "Published" section to `docs/plans/0.4_release_checklist.md`: push
commit hash, tag, publish timestamp, and the Itch Upload — Owner Action
block. Commit it and push (part of this authorized publish).

## Done gate

- Pre-publish audit fully green before the first push.
- main + v0.4.0 tag on GitHub.
- Checklist "Published" section committed and pushed, including the
  owner's itch upload instructions with verified zip integrity.
- Prompt archived to docs/todone/ with an execution record; QUEUE.md
  updated; archive commit pushed.
