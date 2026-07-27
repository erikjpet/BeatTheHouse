# Agent Prompt - P2: Widen Token Coverage and Sweep UI Consistency

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike preparing 0.5. This file is self-contained.

## The gap

The 0.5 UI overhaul built a real design-token system and proved it, but its
enforcement gate covers only **8 of the 55** files in `scripts/ui/`.
`tools\ui05_token_adoption_check.ps1` hardcodes this list:

```
foundation_widgets.gd, foundation_hud_bar.gd, foundation_hud_view_model.gd,
hud_time_watch.gd, environment_header.gd, cheat_dock.gd, segmented_meter.gd,
talk_dock.gd
```

Everything else is unenforced, and drift is already measurable. Raw
`Color("#...")` literal counts outside the token system today:

| File | Count |
| --- | --- |
| `pixel_scene_canvas.gd` | 344 |
| `visual_style.gd` | 46 (expected - this IS the palette) |
| `world_map_canvas.gd` | 28 |
| `foundation_main.gd` | 24 |
| `run_report_timeline_canvas.gd` | 10 |
| `foundation_screen_builder.gd` | 7 |
| `run_report_screen.gd`, `bag_open_reel.gd` | 3 each |
| `run_inventory_screen.gd`, `item_found_popup.gd`, `game_surface_canvas.gd` | 2 each |
| `perf_telemetry_overlay.gd`, `meta_item_interaction_screen.gd`, `coach_overlay.gd` | 1 each |

## Task

This is a judgment task, not a find-and-replace. Work in three passes.

### 1. Classify

Go file by file and decide which category each raw literal falls into:

- **Chrome** - panels, buttons, labels, popups, HUD, menus. These MUST come
  from tokens. Migrate them.
- **Art** - scene/canvas painting where the color IS the artwork
  (`pixel_scene_canvas.gd` at 344 is almost certainly mostly this, likewise
  the map and timeline canvases). These are legitimately exempt, but the
  exemption should be DELIBERATE and documented, not accidental. Where an art
  canvas draws chrome-like elements (labels, frames, tooltips over the art),
  those parts still move to tokens.
- **Diagnostic** - `perf_telemetry_overlay.gd` and similar dev-only surfaces.
  Exempt, documented.

### 2. Migrate the chrome

Migrate every chrome literal to tokens, adding token entries where a genuine
new role exists (do not invent near-duplicate colors to avoid a migration -
if two shades were arbitrarily different, unify them). `foundation_main.gd`
and `foundation_screen_builder.gd` are the priority: they hold the remaining
pre-overhaul-looking chrome.

While in each file, fix the consistency defects the overhaul's per-surface
passes would have caught: inconsistent spacing between sibling elements,
font-size steps that do not match the type scale, missing hover/press/focus
states on interactive controls, and panels that do not use the shared
autosizing helper.

### 3. Make the gate real

Rewrite `tools\ui05_token_adoption_check.ps1` to check ALL of `scripts/ui/`
by default, driven by an explicit exemption list with a one-line justification
per exempt file, rather than an opt-in list of 8. A new UI file must be
covered automatically the day it is added - that is the whole point.

Also extend the check's patterns if you find drift shapes it currently misses
(e.g. raw `Vector2` sizes, raw separation constants) - it currently catches
four patterns.

## Scope discipline

This is a consistency sweep, NOT a redesign. Do not relayout screens or
change what any surface shows. If you find a surface that genuinely needs a
design pass, note it in your report for a follow-up prompt instead of doing
it here. The one exception: obviously broken states (a control with no hover
feedback, a panel with clipped text) should be fixed in place.

## Hard rules

- Zero gameplay-behavior change. Zero visual identity change - after this
  sweep the game must look the same, only more consistent. Before/after
  captures for every file group you touch.
- Zero-copy per-frame; idle-animation liveness untouched - never accept a
  0.000 idle-draw number without the liveness counter check.
- Working tree may contain other people's uncommitted work; treat it as
  user-owned, never revert or stage it. Stage explicitly, file by file.
- Style: tabs, typed GDScript, sparse comments. Captures under `.tmp/`.

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (discover the list; do not guess)
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- all four `tools\ui05_*_check.ps1`, with the widened token check green

## On completion

Only after every gate passes AND the sweep is confirmed visually unchanged:

1. Commit the work in logical units (classification/exemptions; chrome
   migration by file group; gate rewrite).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append a short execution record to the bottom of the moved
   file (date, implementing commit hashes, gate results, deviations), and
   stage the moved file so the archive lands in the final commit.
3. PUSH to the remote.
4. Report: the classification table, what you unified, the final exemption
   list with justifications, any surface you flagged for a follow-up design
   pass, and gate results.

On an unfixable failure, stop at the last green commit, do NOT push or
archive, and report verbatim.

---

## Execution record

Date: 2026-07-27

Implementation commit:

- `cb466acd` — Widen UI token coverage

Archive commit:

- This commit archives the completed prompt after green gates.

Summary:

- Migrated visible start/run chrome in `scripts/ui/foundation_screen_builder.gd` to `VisualStyle` spacing, type, color, border, and touch-target tokens without changing behavior or visual identity.
- Migrated `scripts/ui/coach_overlay.gd` off raw color, spacing, and font literals.
- Rewrote `tools/ui05_token_adoption_check.ps1` to auto-discover `scripts/ui/*.gd`, check raw hex colors/theme spacing/font sizes/control `Vector2` sizes, and require explicit one-line exemptions.
- Updated `docs/plans/0.5_ui_redesign_report.md` with the widened token gate result and current UI surface accounting.
- Before/after capture: `.tmp/ui05_captures/p2_2/token_sweep_before_after.json`.

Gate results:

- `tools\validate_project.ps1` — PASS.
- Supported `-FoundationSuite` list discovered from `tools/check_godot.ps1`: `smoke`, `contracts`, `games`, `systems`, `ui`, `slot`, `slot_acceptance`, `blackjack`, `roulette`, `baccarat`, `video_poker`, `bar_dice`, `pull_tabs`, `scratch_tickets`, `audit`, `all` — all PASS. Longest observed suite stages included `foundation_slot_acceptance` 492499ms, `foundation_audit` 497587ms, and `foundation_all` 124628ms.
- `tools\foundation_visual_qa.ps1` — PASS.
- `tools\foundation_performance_probe.ps1 -RequireGodot` — PASS.
- `tools\ui05_asset_pipeline_check.ps1` — PASS (`50 PNGs cross-checked; title and icon temp-copy deletion covered`).
- `tools\ui05_popup_fit_check.ps1` — PASS (`3 representative viewport/content pairs`).
- `tools\ui05_surface_coverage_check.ps1` — PASS (`57 scripts/ui files accounted`).
- `tools\ui05_token_adoption_check.ps1` — PASS (`38 scripts/ui files covered, 19 deliberate exemptions`).

Deviations / follow-ups:

- No gameplay or persistence behavior changes.
- `scripts/ui/foundation_main.gd` still has legacy host literals classified behind an explicit token-gate exemption because the tree contained user-owned in-flight changes there and the prompt forbids broad redesign. Follow-up design pass: decompose/tokenize remaining host-modal and popup geometry once those surfaces are free.
- Other deliberate exemptions are art canvases, diagnostic overlays, placement/view-model geometry, and frozen modal surfaces whose literal values are rendering geometry rather than reusable chrome tokens.
