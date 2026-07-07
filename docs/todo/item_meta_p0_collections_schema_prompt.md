# Agent Prompt — Item Meta P0: Collections Schema + Meta Store + Float Engine

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). This is **Phase P0 of the item collection meta
system** — the foundation layer only. Source design (read it first):
`docs/plans/item_collection_meta_system_plan.md` (rev 2, owner decisions
locked). Later phases add drops, loadouts, and the meta-home; P0 builds the
data schema, the persistent store, and the float engine, with **zero changes
to run behavior**.

## Scope guard (binding)

P0 creates **new files only**, plus at most one registration hook:

- `data/collections/collections.json` (new)
- `scripts/core/meta_collection_service.gd` (new)
- `scripts/core/collection_item_resolver.gd` (new, or fold into the service)
- New standalone test coverage (see Testing — do NOT edit
  `scripts/tests/foundation_check.gd` or `ui_scene_compile_check.gd`; both
  carry uncommitted work on the PM machine)
- Optional: add the new data file to `tools/validate_project.ps1`'s
  required-files list.

No RunState, RunActionService, foundation_main, or game-module edits. No UI.
If you find yourself touching an existing gameplay file, stop — that is P1+.

## 1. `data/collections/collections.json`

Schema is **Steam Inventory Service compatible by construction** (owner
requirement — these items will eventually be Steam item categories with
community-market support):

- Every definition (items AND bags) carries a stable numeric `itemdef_id`,
  unique across the file, never reused. Start collection 1 at 1000,
  collection 2 at 2000, bags in the 9000s.
- Tier vocabulary: `blue`, `purple`, `pink`, `red`, `gold` (ascending).
- Collection: `id`, `display_name`, `theme`, `bag_defs` (one per tier;
  bags are rare items in their own right — tier and collection are visible
  attributes), `items` (list), `drop_table` (tier weights, data only in P0).
- Item: `itemdef_id`, `id`, `display_name`, `tier`, `base_effect`
  (existing items.json effect-key vocabulary: `baseline_luck_delta`,
  `win_chance`, `win_bonus`, etc.), `float_bindings` (below), `flavor`,
  `icon_key`.
- **Launch content: 2 collections × 14 items** — 4 blue, 4 purple, 3 pink,
  2 red, 1 gold each. Author a **DRAFT** selection curated from existing
  game items/objects (read data/items/items.json for candidates), themed per
  collection. Mark the file header `"draft": true` — the owner vets and
  replaces this list before P1; ids/structure are what P0 locks, not the
  picks.

## 2. Float engine (four floats, [0,1], seeded)

Per plan §1. Each owned instance stores: `instance_id` (unique, monotonic),
`itemdef_id`, and floats `potency`, `condition`, `resonance`, `usage`.

- `float_bindings` per item define: potency → `{effect_key, min, max}`
  magnitude band; condition → display band cut points (Battered/Worn/Clean/
  Crisp/Mint) + value multiplier curve; resonance → `{effect_key, threshold,
  value}` quirk activation; usage → decay parameters (`decay_min`,
  `decay_max`, e.g. 0.02–0.05 per failed run).
- `roll_instance(itemdef_id, rng_seed) -> Dictionary` — deterministic for a
  given seed (two calls with the same seed produce identical instances).
- `apply_usage_decay(instance, rng_seed) -> Dictionary` — returns a new
  instance dict with usage reduced; floors at 0.0; **never deletes**. At
  usage 0 the instance is "spent": value multiplier bottoms out, potency
  dampened (data-driven dampening factor), item remains owned and
  trade-up-eligible.
- `resolve_run_item(instance) -> Dictionary` — produces an items.json-shaped
  dictionary (float-scaled effect values) ready for future run injection.
  Pure function, no side effects, mutates nothing.

## 3. `MetaCollectionService` (persistent store)

- Owns `user://meta_collection.json`. Follow `user_settings.gd`'s
  atomic-write pattern (scripts/core/user_settings.gd:6,67) and RunState's
  normalize-on-load discipline: schema_version field, corrupt/missing file
  loads empty defaults without crashing, unknown keys preserved.
- Holds: owned instances, unopened bags, gold balance (int, starts 0),
  loadout (empty array in P0), meta-home state (empty dict placeholder),
  trade-up/sale history (empty arrays).
- API in P0: load/save, `grant_instance`, `grant_bag`, `owned_instances()`,
  `remove_instance` (the destruction primitive for future pawn/trade-up),
  `add_gold`. No UI, no run wiring.
- **Strictly outside RunState** — no imports of RunState here, no imports of
  this service from run code (that boundary is enforced in later phases;
  keep it clean now).

## 4. Testing

New standalone check script `scripts/tests/collection_meta_check.gd`
(headless-runnable like existing checks; pattern-match how
`tools/check_godot.ps1` invokes script checks, but do NOT wire it into the
existing dirty test files — a new `tools/collection_meta_check.ps1` wrapper
following an existing wrapper's shape is the clean path):

1. collections.json loads and validates: unique itemdef_ids, exactly
   2×14 items at 4/4/3/2/1 tier counts, every item's float_bindings
   reference known effect keys, every tier has a bag def.
2. Same-seed roll determinism; different-seed variance.
3. Usage decay: monotonic decrease, floor at 0, never removes the instance;
   spent-item value/potency dampening applies.
4. `resolve_run_item` output shape matches an items.json entry (spot-check
   keys) and is side-effect free.
5. Store round-trip: grant → save → load → identical; corrupt file →
   defaults without crash; schema_version present.

## Hard constraints

1. Match house style: tab indentation, typed GDScript, sparse comments
   stating constraints only. Data-driven — no item-id branches in code.
2. All randomness through seeded RNG parameters; no unseeded `randf()`,
   no wall-clock anywhere in the engine or store.
3. Simulated-gambling compliance: bags/items are earned in play only; no
   real-money framing in any content text.
4. Zero changes to existing gameplay/UI/test files (Scope guard above).

## Verification gates (run at the end)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. Your new `tools\collection_meta_check.ps1` (headless Godot) — all
   assertions pass.
3. `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1
   -RequireGodot -FoundationSuite smoke` — proves no regression to existing
   load paths.
4. Report: itemdef id ranges used, the draft 28-item list (flagged for owner
   review), and the store schema. Move this prompt to docs/todone/ with an
   execution record per RULES; update QUEUE.md. Commit locally; do NOT push.
