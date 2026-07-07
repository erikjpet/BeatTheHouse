# Agent Prompt - v0.4 Meta Collection Economy And UI Polish

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This task closes the second collection loop for 0.4: collection
items need a useful local economy and a polished enough browser that the
feature does not feel half-built.

## Read first

- `docs/plans/0.4_act1_completion_plan.md`
- `docs/plans/item_collection_meta_system_plan.md`
- `docs/todone/item_meta_p0_collections_schema_prompt.md`
- `docs/todone/item_meta_p1_bag_drops_prompt.md`
- `docs/todone/v04_meta_collection_loadout_prompt.md` execution record (that
  task archives before this one starts; if it is still in docs/todo, stop —
  this task's dependency is not met)
- `scripts/core/meta_collection_service.gd`
- `scripts/core/collection_item_resolver.gd`
- `scripts/ui/meta_collection_view_model.gd`
- `scripts/ui/foundation_main.gd`
- `scripts/tests/collection_meta_check.gd`
- `scripts/tests/ui_scene_compile_check.gd`

## Required behavior

1. Pawn sale: owned collection item instances can be destroyed for local meta
   gold. Price must be deterministic and based on tier, condition, usage, and
   potency band. Record sale history.
2. Trade-up: consume 5 same-tier, same-collection owned items to roll one
   next-tier item in that collection. Gold tier is terminal. Record trade-up
   history. The output roll (item pick and floats, with per-float mean
   inheritance from the inputs per the design plan) draws from the persisted
   meta RNG stream the P0/P1 work established — never an unseeded stream,
   never wall-clock, so replaying the same store state trades up identically.
3. Gold balance is visible in the collection/profile UI and persists through
   `MetaCollectionService`.
4. The collection browser supports practical sort/filter controls for
   collection, tier, owned/unowned, unopened bags, and loadout.
5. Bag reveal is upgraded from plain text to a compact reveal panel with item
   name, collection, tier color, condition band, and four floats. Keep it
   simple; no long animation system.
6. Owned collection items show enough identity to feel collectible: tier color,
   condition band, usage band, and float summary. Do not introduce real-money
   or market copy.

## Hard constraints

- Local-only meta economy. No Steam, community market, real money, paid bags,
  or platform credentials.
- Destroying an item through pawn/trade-up is deliberate and confirmed.
- Do not delete items because a run failed; failure only decays usage.
- Do not add prestige purchases.

## Tests

- `collection_meta_check.gd`: pawn price determinism, gold mutation,
  sale-history entry, trade-up eligibility, trade-up output tier, history,
  terminal gold-tier rejection.
- `ui_scene_compile_check.gd`: browser controls fit, confirm flows work,
  reveal panel fits, no duplicate destructive action on rapid click.
- `foundation_check.gd`: meta store stays out of RunState and old/corrupt
  stores normalize.

## Done gate

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- Prompt archived to `docs/todone/` with execution record and committed
  locally.
