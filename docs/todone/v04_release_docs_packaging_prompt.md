# Execution Record

Completion date: 2026-07-08

Implementing commits:

- `7fbd32b` - Claim v04 release docs packaging.
- Final archive/evidence commit: this file is archived with the 0.4.0 version
  stamp, README/checklist/changelog/publish-copy updates, and QUEUE.md update.

Verification gates and package evidence:

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` -
  PASS: `Beat the House foundation architecture validation passed.`
- `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target web`
  - PASS; `builds/itch/BeatTheHouse-web.zip`, 17,159,727 bytes, SHA256
  `DF72D4E2DC1BC83EA232859E6A0FF6432EE9523BE3DABE73D3ADB01A04E45649`.
- `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target windows`
  - PASS; `builds/itch/BeatTheHouse-windows.zip`, 43,640,988 bytes, SHA256
  `E305532F29959E9F99E4ED0F162FB2CE1FF4A55B0A8409B4912517E7E177EDF1`.
- `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1` - PASS;
  Chrome 4x ready 14,812ms / 20,000ms, report
  `.tmp/web_perf_smoke/report.summary.json`.
- Windows launch smoke - PASS; started
  `builds/windows/BeatTheHouse.exe`, it stayed alive for 8 seconds, and the
  smoke stopped it.
- `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target web -SkipExport -Push -DryRun -ItchTarget your-itch-user/beat-the-house`
  - PASS; printed
  `butler push --userversion 0.4.0 D:\Projects\Beat-The-House\builds\web your-itch-user/beat-the-house:html`;
  no upload performed.
- `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target windows -SkipExport -Push -DryRun -ItchTarget your-itch-user/beat-the-house`
  - PASS; printed
  `butler push --userversion 0.4.0 D:\Projects\Beat-The-House\builds\windows your-itch-user/beat-the-house:windows`;
  no upload performed.

Changes completed:

- Stamped release identity to `0.4.0` in `project.godot`,
  `export_presets.cfg`, and the visible `FoundationMain` fallback version.
- Updated `README.md` as the 0.4 top-level spec with current scope, generated
  content counts, validation commands, active docs, export status, and the
  explicit boss-fight/final-scene cut.
- Added `docs/plans/0.4_release_checklist.md` with final gate evidence,
  package hashes, export readiness, accepted limitations, and release decision.
- Added `docs/plans/0.4_publish_copy.md` with itch.io, GitHub release, and
  devlog copy.
- Updated `CHANGELOG.md` with concise 0.4.0 notes.
- Updated `docs/todo/QUEUE.md`; publish/tag and post-release verification
  remain owner-launch only.

Deviations:

- Publishing was intentionally not performed. The prompt requires butler
  dry-run only; actual itch/GitHub publication remains a user action with
  credentials outside the repository.
- Android and iOS were version-stamped but not packaged or claimed
  store-ready because signing/team credentials are not available in source.

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
