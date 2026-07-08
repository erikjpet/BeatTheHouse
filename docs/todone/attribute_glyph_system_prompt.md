# Agent Prompt — Attribute Glyph System: Symbol Badges Replace Prose Text Boxes

## Execution Record

- Completion date: 2026-07-06.
- Implementing commit hash(es): pending. The implementation is verified in the working tree, but this workspace contains broad unrelated dirty changes, including same-file edits; do not create a blended commit for this archive move.
- Verification gates:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui` -> PASS, report `D:\Projects\Beat-The-House\.tmp\test_reports\20260706_204117_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` -> PASS, report `D:\Projects\Beat-The-House\.tmp\test_reports\20260706_204250_smoke\summary.json`.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_mouse_batch_playtest.ps1 -RunCount 10 -RequireGodot` -> PASS, strict gate, playable-loop `10/10`, victory `10/10`, true failures `0`.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_performance_probe.ps1 -RequireGodot` -> FAIL on pre-existing synthetic game-surface idle rows not exercised by attribute badges: dice table p95 `2.00ms > 1.50ms`, baccarat p95 `3.25ms > 1.50ms`, roulette p95 `6.66ms > 1.50ms`, synthetic blackjack idle produced no draw samples. Badge-relevant environment focus observations remained within the probe path.
- Summary:
  - Added `data/art/attribute_glyphs.json` as the active authored glyph registry, avoiding the deprecated `data/runtime` path that production validators forbid.
  - Added `scripts/core/attribute_badges.gd` for read-only badge translation and `scripts/ui/attribute_badge_row.gd` for cached Control/canvas rendering.
  - Integrated badge rows into travel focus cards, world-map target nodes, item/shop/inventory detail paths, event modal choices, talk-dock choices, services/lenders, and the run-menu legend.
  - Added validator required-file coverage and foundation/UI tests for registry validation, class coverage, read-only builders, legend enumeration, and inventory component rendering.
- Deviations:
  - The prompt referenced `data/runtime/attribute_glyphs.json`, but `tools/validate_project.ps1` explicitly forbids `data/runtime`; the registry was implemented under `data/art/attribute_glyphs.json`.
  - No commit was created because the workspace is carrying unrelated dirty work and same-file edits. A later partition pass should commit this task separately.

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (1280×720 viewport, immediate-mode canvas rendering, data-driven
content — see CLAUDE.md). You are replacing prose "text box" attribute
descriptions — starting with the travel menu — with a **repo-wide attribute
glyph system**: small, standardized, instantly recognizable symbols that show
how something (a travel route, item, event, service) affects the run, plus a
class badge showing what category it belongs to.

## Product intent (binding)

1. A player glancing at a travel route, shop item, or event choice reads its
   effects from symbols in under a second: a cash glyph with `+5`, a heat
   glyph with `+1`, a three-pip risk tier — not a sentence.
2. Symbols are **standard across all content types**: the same heat glyph
   means suspicion everywhere it appears; the same cash glyph means bankroll
   everywhere. One vocabulary, learned once.
3. Every card/entry shows its **class** (item class, event type, route risk
   tier, service category) as a compact badge so category recognition is
   immediate.
4. Prose does not disappear — it demotes: one short flavor line stays on
   cards, and the full sentence moves to hover/focus detail. Symbols carry
   the mechanical facts.

## The text-box pattern you are replacing (investigated)

- `_world_object_summary_text` (foundation_main.gd:4191-4200) concatenates
  prose from the keys `short_description, choice_summary, cost_summary,
  effect_summary, impact_summary, risk_summary, action_summary,
  disabled_reason`, manually prefixing "Risk:" / "Impact:" strings.
- Focus detail cards add text-only rows: `_add_detail_row(card, "Cost", ...)`
  / `("Risk", ...)` at foundation_main.gd:4732-4737.
- Travel choice cards append `_travel_risk_summary(choice)` prose plus muted
  preview lines at foundation_main.gd:4966-4970; travel risk detail strings
  are hand-assembled at foundation_main.gd:2328-2335.
- The world map (scripts/ui/world_map_canvas.gd) and the travel object focus
  path present route info — inventory every place route attributes render as
  text before you start (grep for `risk_summary`, `cost_summary`,
  `_travel_risk_summary`, `route_risk`).

## Existing infrastructure you MUST build on (do not invent a parallel system)

- `scripts/ui/icon_sprite_renderer.gd` (`IconSpriteRenderer`) renders small
  pixel sprites authored as shape data in `data/runtime/icon_sprites.json` —
  frame + shapes, accent-colorable, `texture()` and `draw_canvas()` paths.
  Its header comment states the design rule: icons are authored as data, not
  content-id branches inside UI scripts. Attribute glyphs follow the same
  rule.
- `pixel_scene_canvas.gd` already consumes authored icon sprites via
  `_texture_for_icon_sprite` (:3029) — study its texture caching before
  writing any new texture path.
- `scripts/ui/visual_style.gd` holds the palette; glyph color semantics must
  come from there, not hard-coded colors.

## Attribute data you are symbolizing (verified shapes)

- **Travel routes** (data/travel/routes.json, 10 entries): `cost` (int),
  `risk` ("low"/…), `distance` ("near"/…), `risk_decay` (int), plus runtime
  route-risk events carrying `chance_percent`, `bankroll_delta`,
  `suspicion_delta`.
- **Items** (data/items/items.json): `class` (e.g. "permanent"), `domain`,
  `sale_price`/`price_min`/`price_max`, `effect` dict with keys like
  `baseline_luck_delta`, `win_chance`, `win_bonus`.
- **Events** (data/events/events.json): `type` (e.g. "opportunistic"),
  choice `consequences` with `bankroll_delta`, `suspicion_delta`, etc.
- **Services** (data/services/services.json) and **lenders**
  (data/debt/lenders.json): inventory their effect keys the same way before
  finalizing the glyph vocabulary.

## Design to implement

### 1. Glyph vocabulary (data)

New authored file `data/runtime/attribute_glyphs.json` mapping **semantic
attribute keys** to glyph definitions:

- Core set (extend after auditing all effect keys): `bankroll` (cash),
  `suspicion` (heat), `luck`, `risk_tier` (1–3 pips), `distance`, `cost`,
  `win_chance`, `win_bonus`, `risk_decay`, `debt`, `time_actions`.
- Class badges: item classes (`permanent`, consumable, etc. — enumerate from
  items.json), event types, route risk tiers, service categories.
- Each glyph entry: sprite shapes (icon_sprites.json format, reuse the
  renderer), a `polarity` rule (whether positive values are good, bad, or
  neutral — heat +1 is bad, cash +5 is good) driving color from
  visual_style.gd (dual-code with shape/direction so color is never the only
  signal — colorblind safety), and a compact value format (`"+%d"`, `"%d%%"`,
  pips).
- Validate the file on load exactly like icon_sprites.json is validated; add
  it to `tools/validate_project.ps1`'s required-files list.

### 2. Badge builder (one central translator, core layer)

One shared builder (e.g. `scripts/core/attribute_badges.gd`, static funcs)
that translates a content definition + context into an ordered badge list
`[{glyph_id, value_text, polarity}, ...]`:

- `for_route(route, route_risk)`, `for_item(item)`, `for_event_choice(choice)`,
  `for_service(service)` — every UI consumer calls these; no UI script builds
  badge lists ad hoc (same rule as IconSpriteRenderer's no-content-branches).
- Read-only: builders take definitions and return new arrays; they must not
  mutate inputs (SB.2 mutation firewall covers preview/read paths).
- Unknown/missing attribute keys are skipped silently — content additions
  must not crash old builds.

### 3. Badge row renderer (UI layer)

One shared renderer (e.g. `scripts/ui/attribute_badge_row.gd`) that draws a
horizontal row of glyph+value badges, usable from both worlds this codebase
has:

- **Control path** for cards/panels (used by the focus detail card, travel
  choice cards, shop/inventory item rows, event choice buttons).
- **Canvas path** (`draw_canvas`-style, like IconSpriteRenderer) for
  immediate-mode surfaces (world map route hover, pixel scene object labels).
- Textures are cached by (glyph_id, size, polarity) — never create an
  ImageTexture per frame (idle-draw budgets are release-gated; zero per-frame
  allocations).
- Fixed badge size (~14–18 px glyph + value text) and consistent ordering
  (class badge first, then cost, then effects, then risk) so placement itself
  is information.

### 4. Replace the travel menu text box (first integration, the user's ask)

- Travel choice cards and the travel focus detail card render a badge row
  (class/tier, cost, distance, risk pips, risk-event deltas) instead of the
  concatenated `cost_summary`/`risk_summary` prose; keep one short flavor
  line (`description` — "Cheap supplies.").
- The full prose sentence moves to the hover/expanded state of the card, not
  deleted (screen-reader/clarity fallback and legend reinforcement).
- Apply the same treatment to the world map route presentation
  (world_map_canvas.gd) via the canvas path.

### 5. Roll out to items, events, services

- Shop and inventory item rows: class badge + price + effect badges.
  **Sequencing:** `docs/todo/run_inventory_screen_extraction_prompt.md`
  restructures the inventory popup — check whether it has been executed (see
  docs/todone/) and integrate with whichever inventory implementation is
  current.
- Event choice buttons (modal popup now; the talk dock from
  `docs/todo/talk_overlay_decision_system_prompt.md` when it lands): each
  choice shows consequence badges (`bankroll_delta`, `suspicion_delta`, …) so
  decisions read at a glance.
- Services/lender cards: same builder + renderer.

### 6. Legend (learnability)

A compact legend reachable from the run menu (and linked wherever badges
first appear) listing every glyph with its meaning — generated **from**
`attribute_glyphs.json` at runtime so it can never drift from the vocabulary.

## Hard constraints

1. Zero per-frame allocations in badge rendering; cache textures; never
   `duplicate(true)` live state per frame (see CLAUDE.md).
2. Builders are read-only over definitions (mutation firewall suites will
   catch violations — run them).
3. Do not remove the prose summary keys from data or the summary builder
   until every consumer of `_world_object_summary_text` is inventoried; any
   consumer you do not convert in this task keeps working.
4. Keep the data-authored discipline: no `if item_id == ...` branches in UI
   scripts; everything routes through the glyph registry and builders.
5. Foundation coverage to add: (a) attribute_glyphs.json loads/validates and
   every class named in items/events/routes data has a badge, (b) builder
   outputs are stable and read-only for representative content, (c) travel
   card renders badges for a seeded route without per-frame texture creation
   (extend the perf tripwire pattern from SA.2 if a hook exists), (d) legend
   enumerates every registry entry.
6. Match existing style: tab indentation, typed GDScript, sparse comments
   stating constraints only.

## Verification gates (run at the end, not iteratively)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui` and
   `-FoundationSuite systems`.
3. `tools\foundation_performance_probe.ps1 -RequireGodot` — idle-draw budgets
   must hold with badges rendering.
4. One `tools\foundation_mouse_batch_playtest.ps1 -RunCount 10 -RequireGodot`
   integration smoke (travel + shop interactions exercise the new cards).
