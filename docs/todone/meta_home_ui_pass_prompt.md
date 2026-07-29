# Agent Prompt — Meta-Home UI Pass (Simple HUD, Item Display, Map Framing)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas, foundation_main host,
data-driven, post-0.5-UI-overhaul design-token system). This file is a
three-part meta-home UI pass. Audit current code first; line references may
have drifted — code reality wins. Use the 0.5 design tokens +
`FoundationWidgets` kit only (no raw color/size literals), and register any
new/changed UI files in the token-adoption check and the UI redesign report
so the UI05 coverage gates stay green.

Meta-home mode is detectable via `foundation_main.gd` `_is_meta_session()` /
`meta_session_active`. Home state lives in
`scripts/core/meta_collection_service.gd` (`snapshot()`, `add_gold`,
`housing_tier`, `next_housing_upgrade`, `unopened_bags`).

---

## PART 1 — A simple, distinct meta-home HUD (top bar)

The top HUD is built for RUN state (`scripts/ui/foundation_hud_view_model.gd`
— bankroll, chips, heat, alcohol/time, run clock, run objective) and shows
that run chrome inside the meta home, where it is meaningless. Give the home
session its own simple top bar.

Home-mode top bar shows EXACTLY these — nothing else:

1. **Home type + current location** — the current meta location and housing
   tier (e.g. "Home · House", or "Sal's Pawn Shop" when there). Source:
   `housing_tier()` + the current meta location.
2. **Gold** — the home currency, prominent.
3. **Gold goal to tier up** — the gold needed for the next housing upgrade
   (e.g. "Next tier: 400g" or a gold-toward-goal readout). Source:
   `next_housing_upgrade()`. If already at the top tier, show a clean
   "Top tier" state.

Do NOT show items, bags, collection counts, cards, heat, alcohol, the run
clock, or the run objective in the home header. Run-only chrome is ABSENT in
home mode (not blanked). The bar must read unmistakably as "home."

Requirements: home mode reads the meta service snapshot (never `run_state`
for home currency/state); the run HUD stays byte-identical; readouts rebuild
on state change (gold spent, housing upgraded), not per frame; the mode
switches cleanly entering/leaving home and across save/load with no
cross-mode chrome bleed. Build into the existing HUD component/view-model
split; do not grow `foundation_main.gd`.

---

## PART 2 — Reorganize the home item storage display

Items stored in the home currently render disorganized and OVERLAPPING and
are hard to read. The display flows through
`scripts/ui/meta_collection_view_model.gd` (`_item_row`, `_bag_rows`),
`scripts/ui/meta_item_interaction_screen.gd`, and
`scripts/ui/inventory_container_surface.gd` /
`inventory_container_catalog.gd` (confirm the exact surface).

Rework the stored-item presentation into a clean, organized layout:

- A proper grid/list with consistent spacing — NO overlapping items,
  labels, or icons at any count; content never collides or clips.
- Sensible grouping and ordering (by collection / tier / container, and
  unopened bags distinct from owned items), so a player can scan what they
  own.
- Each item reads clearly: icon, name, count, and its rarity treatment —
  reuse the rarity-outline card treatment established by the bag-open reel
  (`bag_open_reel.gd`) so item rarity is consistent across the meta UI.
- Readable and non-overlapping at 1280×720 AND small-screen; if the
  collection exceeds the visible area, page/scroll it cleanly within its
  own container (the page body never scrolls).
- Token-based styling; hierarchy first (what you own at a glance).

This is a presentation/layout reorganization: do not change what items exist,
their data, or the sale/interaction actions — only how they are shown.

---

## PART 3 — Fix the meta-home map framing (pawn shop is off-frame)

On the meta-home world map, not all visitable locations are viewable: the
pawn shop node sits just outside the frame and is therefore not selectable.

Root cause to confirm: the meta map builds nodes via
`foundation_main.gd` `_meta_world_map_node(node_id, position, selected_id)`
(~:13022) / `_meta_world_map_snapshot()` (~:13017), rendered through the
`world_map_canvas.gd` bounds-fit system (`map_view_bounds_cache` /
`target_map_view_bounds_cache`). The pawn shop node's position falls outside
the framed/visible bounds.

Fix it so EVERY meta location is fully visible and selectable: the meta map
must frame ALL of its nodes (home + pawn shop + any future meta nodes)
within view with padding — either by computing the view bounds to fit every
meta node, or by placing the meta nodes within the guaranteed-visible frame.
Verify every meta node is on-screen and clickable at 1280×720 and
small-screen, and that selection + travel to the pawn shop works from the
map.

---

## Hard rules (all parts)

- Zero run-HUD behavior change; zero gameplay/data change (Parts 1-2 are
  presentation; Part 3 is framing). Zero-copy per-frame; idle-animation
  liveness untouched; determinism unaffected (UI observes state, never
  mutates). Tokens only, no raw literals; UI05 coverage/token gates stay
  green. Tabs, typed GDScript, sparse comments; captures under `.tmp/`.
  Suite timeout = max(300s, ceil(recorded baseline × 1.5)).
- The working tree may contain uncommitted user-owned work; never revert,
  reformat, or stage files you did not author. Stage explicitly.

## QA / Tests

1. HUD: home session renders the simple bar (location+tier, gold, gold-to-
   next-tier) and NOTHING else; a run renders the unchanged run HUD; gold /
   housing changes update the home bar; save/load keeps the right mode with
   no cross-mode bleed.
2. Item display: assert no overlapping rects across item/bag counts (small
   and large collections) at both screen sizes; grouping/order correct;
   rarity treatment matches the bag reel.
3. Map: assert every meta node's rendered rect is within the visible map
   bounds at both sizes; the pawn shop is selectable and travel to it works.
4. UI gates: token-adoption and surface-coverage checks green with new/
   changed files accounted; reduce-motion clean.
5. Manual: open the home — read location/gold/next-tier at a glance; open
   storage — items are organized and never overlap; open the map — the pawn
   shop is on-screen and selectable; travel there.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite ui`, `systems`, plus any collections/meta suite
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- all four `tools\ui05_*_check.ps1`

## On completion

Only after every gate passes AND you have confirmed all three parts in the
running game:

1. Commit in logical units (HUD mode; item display reorg; map framing).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, per-part commit
   hashes, gate results, deviations), and stage the move.
3. PUSH to the remote.
4. Report per part: what changed, before/after captures (home bar, storage,
   map), and gate results.

On an unfixable gate, stop at the last green commit, do NOT push, and
report verbatim.

---

## Execution record — 2026-07-28 20:48:13 -05:00

- HUD mode commit: `1ec64e3f` (`Add simple meta-home HUD mode`)
- Item display commit: `20307955` (`Reorganize meta-home item storage display`)
- Map framing commit: `e8734591` (`Fit meta-home map nodes in frame`)
- Manual confirmation: opened the meta home, verified the top bar reads as a home-only bar with location + housing tier, gold, and next-tier gold/ready state only; opened storage with a seeded 18-item collection at 1280×720 and small-screen and confirmed grouped rarity-outline cards are readable and non-overlapping with paging; opened the meta map and confirmed the pawn shop marker is fully on-screen, selectable, and offers travel.
- Captures: `.tmp/meta_home_ui_pass_captures/after/home_bar_after.png`, `.tmp/meta_home_ui_pass_captures/after/storage_after_1280.png`, `.tmp/meta_home_ui_pass_captures/after/storage_after_small.png`, `.tmp/meta_home_ui_pass_captures/after/map_pawn_shop_selected_after.png`.
- Gate results:
  - `tools\validate_project.ps1`: PASS
  - `tools\check_godot.ps1 -FoundationSuite ui -TimeoutSec 300`: PASS (`.tmp/test_reports/20260728_204231_smoke/summary.json`)
  - `tools\check_godot.ps1 -FoundationSuite systems -TimeoutSec 300`: PASS (`.tmp/test_reports/20260728_203801_smoke/summary.json`)
  - `tools\collection_meta_check.ps1`: PASS
  - `tools\foundation_visual_qa.ps1`: PASS
  - `tools\foundation_performance_probe.ps1 -RequireGodot`: PASS on quiet isolated rerun; an immediately prior run had one unrelated `video_poker` max-time spike (`5.125 ms` vs `5.000 ms`) and was dismissed under the timing-rerun policy after the clean rerun.
  - `tools\ui05_asset_pipeline_check.ps1`: PASS
  - `tools\ui05_popup_fit_check.ps1`: PASS
  - `tools\ui05_token_adoption_check.ps1`: PASS
  - `tools\ui05_surface_coverage_check.ps1`: PASS
- Deviations: none from gameplay/data scope; `.tmp` capture harness and images were left untracked as local evidence.
