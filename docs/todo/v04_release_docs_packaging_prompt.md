# Agent Prompt - v0.4 Release Docs And Packaging

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This is the final v0.4 task after final gates are green. It stamps,
documents, packages, and prepares the Act 1 completion release.

## Read first

- `docs/plans/0.4_act1_completion_plan.md`
- `docs/plans/0.3.2_release_checklist.md`
- `docs/plans/0.3.3_publish_copy.md`
- `README.md`
- `CHANGELOG.md`
- `project.godot`
- `export_presets.cfg`
- `tools/export_itch.ps1`

## Required work

1. Bump release identity to `0.4.0` everywhere the release checklists track:
   `project.godot`, Windows preset file/product version, Android version/name,
   iOS version fields, README/start-screen visible version strings, and publish
   copy.
2. Update README as the 0.4 top-level spec:
   - current status,
   - current content counts generated from `data/`,
   - completed v0.4 features,
   - explicit boss fight/final scene cut,
   - validation commands,
   - active docs index.
3. Create `docs/plans/0.4_release_checklist.md`, mirroring the 0.3.2 format:
   release identity, scope, final gate matrix, package artifacts, checksums,
   export readiness, accepted limitations, release decision.
4. Update `CHANGELOG.md` with concise 0.4.0 release notes.
5. Create `docs/plans/0.4_publish_copy.md` with itch/GitHub/devlog copy.
6. Produce fresh Web and Windows itch packages through `tools/export_itch.ps1`.
7. Verify Web boot in the local server smoke path and Windows exe launch.
8. Run butler dry-run only. Publishing remains a user action.
9. Commit locally. Do not push.

## Hard constraints

- Do not claim Android/iOS store readiness without real credentials.
- Do not include boss fight/final scene copy as shipped content.
- Keep simulated-gambling safety copy.
- Do not commit build artifacts unless the repository already tracks them by
  release policy; package hashes belong in the checklist.

## Done gate

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- Export packages rebuilt with SHA256 hashes recorded.
- Web local smoke passes.
- Windows launch smoke passes.
- Butler dry-run output recorded.
- `docs/plans/0.4_release_checklist.md` has fresh evidence for every gate it
  lists.
- Prompt archived to `docs/todone/` with execution record and committed
  locally.
