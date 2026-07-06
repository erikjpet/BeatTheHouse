# Agent Prompt - Add Beach Environment and Cumquat Sandwich Legendary Slot Item

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6-compatible
GDScript casino roguelike. This is content plus a small slot-item behavior
task. Do not redesign unrelated environments, inventory, slots, map flow, or
travel.

## User-Facing Goal

Add a new environment called **The Beach** near the boat casino. At the beach,
the player can relax to lower heat, or inspect a hidden suspicious pile of sand.
Inspecting the pile once grants a legendary item: **Cumquat Sandwich**.

The Cumquat Sandwich is a consumable slot-machine item. When consumed at a slot
machine, it triggers exactly one bonus event/feature on that cabinet. Its item
icon must show an open-face piece of bread with white mayo spread to the edges
and orange cumquat slices.

Keep all player-facing copy brief, precise, and true to the mechanic.

## Current-Code Evidence

- The boat casino route is `delta_queen` in `data/travel/routes.json:102`.
  It routes to archetype `delta_queen`, costs 12, has medium risk, and is
  distance `far` (`data/travel/routes.json:102-110`).
- The boat casino archetype is `delta_queen` in
  `data/environments/archetypes.json:1861`. It is tier 2, kind `casino`, scene
  type `delta_queen`, and currently uses `travel_hooks` for authored map
  neighbors (`data/environments/archetypes.json:1861-1877` and validator checks
  at `scripts/core/content_library.gd:1215-1222`).
- Heat-lowering services already use negative `suspicion_delta`; for example
  `riverboat_deck_walk` in `data/services/services.json:138-148` has category
  `recovery`, brief copy, cost, and an effect with `suspicion_delta: -2`.
- Item validation currently requires item effect dictionaries, `icon_key`,
  `environment_prop`, `surface`, art assets, and sane prices
  (`scripts/core/content_library.gd:657-675`). There is no existing item-level
  rarity schema in `data/items/items.json`; environment rarity exists, but item
  rarity does not.
- Slot active items are dispatched from `scripts/games/slot.gd:100-109`.
  Existing consumable handlers write a `slot_item_state` key, persist it through
  `StateScript.write_machine`, remove the consumed item via result deltas, and
  return `host_apply_result` (`scripts/games/slot.gd:782-874`).
- Slot feature-weight items already flow through item effects
  (`scripts/games/slot.gd:1088-1100`), while the current hard force path is
  buffalo-specific `must_hit_ready` in
  `scripts/games/slots/slot_resolver.gd:495-514`. Generalize carefully instead
  of hardcoding a family-only solution.
- Slot item fixtures live in `scripts/tests/foundation_check.gd:2974-3004` and
  `scripts/tests/foundation_check.gd:3135-3150`.
- Map icons are generated, not hand-placed. The generator has map icon draw
  functions around `tools/generate_icon_art.py:1183-1192`, registers them in
  `MAP_ICONS` at `tools/generate_icon_art.py:1360-1374`, and writes them in
  `main()` at `tools/generate_icon_art.py:1384-1394`.
- The world map falls back to `res://assets/art/map_icons/%s.png` by archetype
  id when no explicit icon path is present (`scripts/ui/world_map_canvas.gd:374-383`).
- Art manifest map icon entries include existing map icons such as
  `map_delta_queen` (`data/art/art_manifest.json:137-145`). Item icon manifest
  entries are under `data/art/art_manifest.json:52+`.

## Hard Constraints

1. Content must be data-driven JSON under `data/` and loaded through
   `ContentLibrary`.
2. `RunState` is authoritative. Do not mutate bankroll, heat, inventory, or
   environment state directly from a UI surface. Use result dictionaries,
   `GameModule.apply_result`, `RunActionService`, or the existing environment
   object action path.
3. Deterministic RNG only. Do not call `randomize()`, `randf()`, `randi()`, or
   nondeterministic shuffle APIs.
4. Save/load must round-trip the beach one-shot state and any new slot item
   armed state. Add normalization defaults if new keys are introduced.
5. Generated art only. Do not hand-place PNGs. Add the beach map icon and
   Cumquat Sandwich item icon to `tools/generate_icon_art.py`, regenerate art,
   and update `data/art/art_manifest.json`.
6. The sandwich item is legendary. If item rarity support still does not exist
   when this prompt is executed, add the minimal item-level `rarity` support
   needed for `rarity: "legendary"` and validate accepted values. Do not build a
   broad loot-tier system.
7. The hidden sand pile grants the sandwich once per persistent beach node.
   Revisiting the beach must not duplicate the item.
8. The sandwich triggers one slot bonus event only. After one forced bonus is
   consumed, the cabinet returns to normal odds.

## Implementation Plan

1. Update travel/environment data.
   - Add a `beach` route in `data/travel/routes.json`. It should be close to
     `delta_queen`, use low-cost travel, and brief copy such as `Beach access.`
   - Add a `beach` archetype in `data/environments/archetypes.json`. It should
     be near/connected to `delta_queen` through `travel_hooks` and route
     metadata, and should include a recovery service and the hidden sand
     interaction.
   - Update `delta_queen` and any appropriate nearby tier-2 route hooks so the
     generated world can discover/connect the beach without making it a start
     location.
   - Preserve existing fog-of-war and world-map snapshot rules: undiscovered,
     untravelable locations must not leak.

2. Add beach interactions.
   - Add a `beach_relax` service to `data/services/services.json` modeled after
     `riverboat_deck_walk`: category `recovery`, brief label/copy, and a
     negative `suspicion_delta` that lowers heat. Keep the effect conservative.
   - Add a one-shot suspicious sand pile interaction using the existing
     environment object/event/action path. The interaction should be hidden or
     understated in the scene, player-selectable, and should grant exactly one
     `cumquat_sandwich`.
   - Persist the inspected state in the environment/node state so save/load and
     revisits do not reset it.

3. Add `cumquat_sandwich`.
   - Add the item to `data/items/items.json` with:
     - `id`: `cumquat_sandwich`
     - `display_name`: `Cumquat Sandwich`
     - `rarity`: `legendary`
     - active consumable slot targeting, consistent with existing slot active
       item definitions
     - `price_min`/`price_max` set to 0 or a high legendary value depending on
       whether it can appear in shops; because this item is hidden/unique, do
       not add it to random shop pools unless the design explicitly needs that
     - brief description, icon key, environment prop, and surface fields that
       fit existing validators and inventory UI
   - If it must appear in `data/content_groups/groups.json` to validate or be
     shown by slot-item systems, add it deliberately. Prefer keeping it out of
     random `slot_pack` offers if that would make a hidden legendary item common.

4. Generate art.
   - Add `draw_cumquat_sandwich_item()` to `tools/generate_icon_art.py`.
     The icon must read as an open-face bread slice with white mayo to the
     edges and orange cumquat slices.
   - Add `draw_beach_map()` to `tools/generate_icon_art.py` and register
     `"beach": draw_beach_map` in `MAP_ICONS`.
   - Regenerate via:
     `python tools/generate_icon_art.py`
   - Update `data/art/art_manifest.json` with `cumquat_sandwich` and
     `map_beach`. Commit the generated PNGs that are actual source assets.

5. Implement slot behavior.
   - Add a `CUMQUAT_SANDWICH_ITEM_ID` constant and active item dispatch in
     `scripts/games/slot.gd`.
   - The active command should arm a persisted one-shot flag in
     `slot_item_state`, consume the sandwich through normal result deltas, and
     return a clear message such as `The next bonus is forced.`
   - Update resolver logic so the next eligible paid spin selects a bonus/feature
     entry for the current slot family, marks the force as consumed, and then
     resumes normal odds. Do not special-case only buffalo unless the current
     cabinet is buffalo; pinball and other slot families must either work or
     return a clear handled failure if a family truly has no feature entry.
   - Preserve deterministic outcomes and existing slot feature rules. The item
     changes only the selected outcome entry for one spin; the feature itself
     should run through the normal path.

6. Update UI/scene drawing only as needed.
   - Add beach scene drawing if the current scene renderer needs an explicit
     `scene_type`. Keep it lightweight and consistent with existing environment
     art.
   - The hidden sand object should be discoverable/selectable without large
     layout churn or per-frame allocation.
   - Ensure inventory uses the generated item icon.

## Tests And Fixtures

Add permanent coverage. Suggested fixtures:

1. `foundation_check.gd`
   - Content validates with `beach`, `beach_relax`, and `cumquat_sandwich`.
   - `delta_queen` can connect to `beach`, and the beach route is low cost /
     near the boat casino.
   - `beach_relax` lowers heat through the normal action/result path.
   - Inspecting suspicious sand grants one `cumquat_sandwich`; inspecting again
     does not duplicate it; save/load preserves the inspected state.
   - Using `cumquat_sandwich` at a slot consumes it, persists an armed one-shot
     flag, forces one bonus/feature on the next eligible spin, clears the flag,
     and leaves later spins normal.
   - The item rarity field validates as `legendary`.

2. `ui_scene_compile_check.gd`
   - Beach scene opens without missing art or broken hit regions.
   - World map can render the beach map icon when the node is visible.
   - Inventory/detail UI can render the Cumquat Sandwich icon and short copy.

3. Slot-specific seed fixture or audit extension
   - Same seed before/after item arming should be deterministic.
   - The forced feature should use the normal feature completion path.

## Verification Gate

Run the narrowest useful suites while developing, then finish with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300
powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite slot -TimeoutSec 300
powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300
```

If a UI/scene renderer was changed, also run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/foundation_visual_qa.ps1 -RequireGodot
```

## Completion Record

When complete, move this file to `docs/todone/` with an execution record that
lists:

- files changed
- generated art files
- commands run and pass/fail output
- test fixture names
- one-line evidence that the beach one-shot pickup, heat-lowering relax action,
  and one-shot forced slot bonus all work
