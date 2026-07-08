# Agent Prompt - v0.4 Publish: Pre-Publish Audit, GitHub Push + Tag, itch Upload

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Every 0.4 queue task through
`v04_release_docs_packaging` is archived and the 0.4.0 packages are built.
This task **publishes the release**. The owner launching this prompt IS the
explicit authorization to push to GitHub and upload to itch.io — both are
otherwise forbidden in this repository's agent rules. If any pre-publish
audit step below fails, STOP before pushing anything and report; do not
publish a broken cut.

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

## 2. GitHub publish

1. `git fetch origin` and inspect `origin/main..HEAD` and `HEAD..origin/main`.
   If the remote has new commits, merge (never rebase — evidence ledgers pin
   commit hashes) and re-run the validate gate before continuing.
2. `git push origin main`.
3. Tag and push: `git tag -a v0.4.0 -m "Beat the House 0.4.0 — Act 1 completion"`,
   `git push origin v0.4.0`.
4. Create the GitHub release with `gh release create v0.4.0` using the
   release notes from CHANGELOG.md's 0.4.0 section; attach both zips only
   if prior releases did so (check `gh release view v0.3.0` for precedent —
   mirror it).

## 3. itch.io upload

1. Verify butler auth non-interactively first (`butler status` via the
   export tool's path or directly). If credentials are missing or expired,
   STOP here, report exactly what is needed, and leave GitHub published —
   do not attempt interactive login.
2. Push through the established channels (mirror the 0.3.x pattern in
   tools/export_itch.ps1: web zip → `html` channel, windows zip →
   `windows` channel, user version 0.4.0).
3. Wait for butler processing to settle; record the butler build numbers
   and output.
4. Verify live: fetch the itch page, confirm the new build is being served
   (butler status shows the new build live on both channels).

## 4. Record

Append a "Published" section to `docs/plans/0.4_release_checklist.md`: push
commit hash, tag, GitHub release URL, butler build numbers/channels,
publish timestamp. Commit that locally and push it too (it is part of this
authorized publish).

## Done gate

- Pre-publish audit fully green before the first push.
- main + v0.4.0 tag on GitHub; GitHub release created.
- Both itch channels serving the 0.4.0 builds (or a precise credential
  blocker reported with GitHub already published).
- Checklist "Published" section committed and pushed.
- Prompt archived to docs/todone/ with an execution record; QUEUE.md
  updated; archive commit pushed.
