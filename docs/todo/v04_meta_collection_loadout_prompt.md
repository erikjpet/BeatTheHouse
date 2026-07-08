# Agent Prompt - v0.4 Meta Collection Loadout And Failure Decay

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This task closes the first dangling collection loop: owned
collection items must be packable into a run loadout, injected into runs, and
decayed on failure.

## Read first

- `docs/plans/0.4_act1_completion_plan.md`
- `docs/plans/item_collection_meta_system_plan.md`
- `docs/todone/item_meta_p0_collections_schema_prompt.md`
- `docs/todone/item_meta_p1_bag_drops_prompt.md`
- `scripts/core/meta_collection_service.gd`
- `scripts/core/collection_item_resolver.gd`
- `scripts/core/collection_drop_service.gd`
- `scripts/core/run_generator.gd`
- `scripts/core/run_state.gd`
- `scripts/ui/foundation_main.gd`
- `scripts/ui/meta_collection_view_model.gd`
- `scripts/ui/run_inventory_screen.gd`
- `scripts/ui/run_inventory_view_model.gd`
- `scripts/tests/collection_meta_check.gd`
- `scripts/tests/foundation_check.gd`
- `scripts/tests/ui_scene_compile_check.gd`

## Required behavior

1. Meta collection instances can be packed and unpacked into a backpack loadout
   from the main-menu collection/profile UI.
2. Loadout capacity is data-backed and starts conservatively:
   - bag: 1 slot,
   - backpack: 2 slots,
   - suitcase: 3 slots,
   - trunk: 4 slots.
   If the existing home/container system already defines capacity, use that
   source instead of duplicating it.
3. Starting a run injects selected loadout items into the run inventory through
   existing item dictionaries resolved by `CollectionItemResolver`.
4. The injected run items keep enough metadata to map back to their meta
   instance id, but deterministic gameplay must not read the profile store
   mid-run.
5. On terminal failure, each carried loadout item decays its mutable `usage`
   float by a small data-defined amount. Victory/clean completion does not
   decay. Items are never deleted by decay.
6. Save/load round-trips a run with injected loadout items without duplicating
   or losing them.
7. UI shows loadout state and prevents duplicate packing of the same instance.

## Hard constraints

- MetaCollectionService stays outside RunState. Inject once at run start,
  settle once at run end.
- Run determinism must not depend on wall-clock or profile reads during a run.
- Corrupt or old meta files still normalize to defaults.
- Do not build pawn sale, trade-up, Steam integration, or a new meta-home scene
  in this task.

## Tests

- `collection_meta_check.gd`: pack/unpack, capacity, duplicate prevention,
  deterministic run item resolution, failure decay, victory no-decay.
- `foundation_check.gd`: run start injection and terminal settlement happen
  exactly once.
- `ui_scene_compile_check.gd`: collection UI exposes pack/unpack controls and
  loadout state without overflow.

## Done gate

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -TimeoutSec 600`
- `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5 -SeedPrefix V04-LOADOUT` —
  run-start injection is exactly the determinism risk this task creates; two
  processes with the same seed and same loadout must hash-match. Do not
  leave this for the final release gate to discover.
- Prompt archived to `docs/todone/` with execution record and committed
  locally.
