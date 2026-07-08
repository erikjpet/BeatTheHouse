# Execution Record

Completion date: 2026-07-08.

Implementing/evidence commits:
- `8c465a1` - Claimed this queue entry after confirming entry 1 was archived.
- Archive/evidence commit - this commit.

Work completed:
- Added `docs/plans/content_style_guide.md` as the active v0.4 Act 1 release voice and copy convention guide.
- Added a focused release-copy blocker check to `scripts/tests/foundation_check.gd`; it parses every JSON file under `data/` and scans the release-path terminal-copy script files for blocker phrases.
- Updated the README documentation index to include the style guide.
- Updated the v0.4 completion plan and Act 1 D6 ledger so the old missing-style-guide failure is no longer stale.

Audit result:
- Structured JSON scan found only the two known Grand Casino Act 2 seam messages in `data/events/events.json`.
- Source scan found the same known seam in `scripts/core/run_state.gd` and `scripts/ui/foundation_main.gd`; this remains owned by `act_two_seam_prompt.md`.
- No TODO, placeholder, debug-only, dev-only, test-only, coming-soon, real-money, or cash-prize release-path content was introduced.

Verification:
- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS, "Beat the House foundation architecture validation passed."
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300` - PASS. Stages: validate_project 15,369ms; godot_import 12,491ms; gdscript_load_check 10,153ms; foundation_systems 24,553ms. Report: `.tmp/test_reports/20260707_203933_smoke/summary.json`.
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` - PASS. Stages: validate_project 15,504ms; godot_import 11,934ms; gdscript_load_check 10,131ms; ui_scene_compile 47,064ms. Report: `.tmp/test_reports/20260707_204040_smoke/summary.json`.

Deviations:
- The existing Act 2 "not implemented yet" seam was not removed because `act_two_seam_prompt.md` owns that work. The new validator allows only those documented seam locations.

# Agent Prompt - v0.4 Content Style Guide And Copy Audit

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This task closes the old Act 1 content-style gap and audits
release-path copy before 0.4.

## Read first

- `README.md`
- `docs/plans/0.4_act1_completion_plan.md`
- `docs/plans/act_one_feature_complete_task_board.md` section 13, especially
  the historical D6 failure.
- `docs/plans/grand_casino_endgame_design.md`
- `data/` content packs
- `scripts/tests/foundation_check.gd` placeholder/copy checks
- `tools/validate_project.ps1`

## Required work

1. Create `docs/plans/content_style_guide.md`.
2. Define the release voice: terse casino noir, readable stakes, no dev/TODO
   copy, no real-money gambling framing, no overpromising Act 2, no explicit
   stat spoilers in item descriptions unless already surfaced through glyphs.
3. Document naming/copy conventions for:
   - environments,
   - events and choices,
   - services/lenders/debt,
   - travel/world-map routes,
   - items/collections/bags,
   - profile/meta text,
   - terminal victory/failure summaries,
   - simulated-gambling safety copy.
4. Audit all player-facing JSON content and obvious script constants for
   `TODO`, `placeholder`, `not implemented`, debug-only copy, overlong labels,
   and stale 0.3 framing. Do not remove the existing Act 2 seam copy here if
   `act_two_seam_prompt.md` still owns it; instead record it as an expected
   follow-up.
5. Add or extend a focused foundation check that loads release-path content and
   asserts the style-guide blockers are absent. Keep it narrow and factual.
6. Update README documentation index to include the style guide if it remains
   active.

## Hard constraints

- This is mostly docs/data/tests. Do not redesign mechanics.
- Do not weaken existing copy validators.
- Keep player copy short enough for existing UI limits.
- Use data-driven JSON edits for content text.

## Done gate

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- Prompt archived to `docs/todone/` with execution record and committed
  locally.
