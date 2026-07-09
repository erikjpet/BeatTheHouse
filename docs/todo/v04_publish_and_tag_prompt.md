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
