# Agent Prompt - P2: Career / Stats Surface (the last un-redesigned screen)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike preparing 0.5. This file is self-contained.

## Why this exists

`docs/plans/0.5_ui_overhaul_brief.md` scoped "the career/stats view (NEW in
this overhaul - profile run history + lifetime stats finally get a surface)".
It was never built as a designed surface. The UI redesign report does not
mention career, lifetime, run history, or stats anywhere.

The DATA is fully persisted and normalized already in
`scripts/core/profile_inventory.gd`: `run_history` (capped list of run
snapshots with outcome, final bankroll, day count, duration), `lifetime_stats`
(total runs, victories per route, total bankroll won/lost, biggest single
win), `daily_runs` (current/best streak), and `completed_challenge_rows()`.

The only presentation is `_add_profile_summary_sections()` at
`scripts/ui/foundation_main.gd:10656` - roughly 60 lines that append flat
text rows into the inventory list via `_profile_line()`, using raw literals
(`Color("#05070d", 0.86)`, font sizes 12/14/15) and prose strings like
`"Runs: %d  Daily streak: %d / best %d"` and
`"%s - %s - $%d - Day %d - %d actions"`.

That is precisely the pattern the overhaul was built to eliminate, and it
survived because `foundation_main.gd` is not in the token-adoption check's
file list. It is the last screen that still looks like the pre-overhaul game.

## Task

Build a real career/stats surface using the 0.5 design system
(`VisualStyle` tokens + `FoundationWidgets` kit; follow
`docs/plans/0.5_ui_redesign_report.md` for the established patterns, and
`docs/plans/0.5_ui_art_manifest.md` for the icon pipeline if you add art).

Requirements:

- **Placement is an open owner question.** The brief's open question 1 asked:
  start-screen tab, meta-home object (e.g. a scrapbook in the house), or
  both? It was never answered. Implement the start-screen entry (lowest risk,
  always reachable, works before a profile has a home) and structure the
  component so a meta-home object can open the SAME screen later without a
  rewrite. Note the decision in your report so the owner can add the
  in-world object if they want it.
- **Hierarchy, not a table dump.** Lifetime headline numbers read at a
  glance; run history is scannable; challenges are a distinct block. Use the
  stat-chip / panel / list-row widgets rather than inventing new ones.
- **Show the shape of a career, not just totals.** Win/loss split, the two
  victory routes (`players_card_cashout` vs `showdown`) as distinct
  achievements, biggest win called out, streaks visible. A player should
  understand their history without reading a legend.
- **Empty state matters.** A fresh profile with zero runs must look
  intentional and inviting, not broken - this is the first thing a new
  player may click.
- Extract it into its own component under `scripts/ui/` with a view model,
  matching the project's existing screen/view-model split. Do not grow
  `foundation_main.gd` (already 13,314 lines); remove the old
  `_add_profile_summary_sections()` text block once the new surface covers it.
- Small-screen and reduce-motion behavior implemented at the same time.
- Zero data-model change: read from `ProfileInventory` as-is. If a number you
  want to show is not persisted, report it rather than adding fields.

## Hard rules

- No raw color/size literals - tokens only. Add the new files to
  `tools\ui05_token_adoption_check.ps1`'s file list.
- Add the new files to `docs/plans/0.5_ui_redesign_report.md` with cold-look
  notes and captures, so `tools\ui05_surface_coverage_check.ps1` stays green.
- Zero gameplay-behavior change. Zero-copy per-frame; idle liveness untouched.
- Working tree may contain other people's uncommitted work; treat it as
  user-owned, never revert or stage it. Stage explicitly, file by file.
- Style: tabs, typed GDScript, sparse comments. Captures under `.tmp/`.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite ui`, `systems`
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- all four `tools\ui05_*_check.ps1`

## On completion

Only after every gate passes AND the surface is confirmed working end to end:

1. Commit the work in logical units.
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append a short execution record to the bottom of the moved
   file (date, implementing commit hashes, gate results, deviations), and
   stage the moved file so the archive lands in the final commit.
3. PUSH to the remote.
4. Report: the surface design, the placement decision and how a meta-home
   entry would attach, before/after captures, any lifetime stat you wanted but
   could not source, and gate results.

On an unfixable failure, stop at the last green commit, do NOT push or
archive, and report verbatim.

---

## Execution record - 2026-07-26

- Implementing commit: `d2f1750f` (`Add career stats surface`)
- Surface: added `CareerStatsScreen` plus `CareerStatsViewModel`; start menu now opens a dedicated Career ledger while inventory returns to stash-only presentation.
- Placement: implemented start-screen entry now; future meta-home scrapbook/object can call `open_career_stats_screen()` and reuse the same component/model.
- Captures: `.tmp/ui05_captures/p2_1/career_empty.json`, `.tmp/ui05_captures/p2_1/career_seeded.json`
- Missing stat: per-game win rates are not persisted, so the surface reports that instead of adding data fields.
- Gates:
  - `tools\validate_project.ps1` PASS
  - `tools\check_godot.ps1 -FoundationSuite ui` PASS
  - `tools\check_godot.ps1 -FoundationSuite systems` PASS
  - `tools\foundation_visual_qa.ps1` PASS
  - `tools\foundation_performance_probe.ps1 -RequireGodot` PASS
  - `tools\ui05_asset_pipeline_check.ps1` PASS
  - `tools\ui05_popup_fit_check.ps1` PASS
  - `tools\ui05_surface_coverage_check.ps1` PASS (`57 scripts/ui files accounted`)
  - `tools\ui05_token_adoption_check.ps1` PASS (`10 tokenized component files`)
- Deviations: none.
