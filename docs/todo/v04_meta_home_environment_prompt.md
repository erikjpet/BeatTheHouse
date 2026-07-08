# Agent Prompt - v0.4 Meta Home Environment, Housing Progression, and Pawn Shop

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (see CLAUDE.md). This task **renovates the out-of-run inventory
experience**: the main-menu collection browser is replaced by a persistent,
walkable **home environment** where the player stores, inspects, packs,
opens, and trades their collection between runs — plus a housing progression
(back alley → motel room → apartment → house) bought with meta gold, an
out-of-run **map** for meta travel, and a **pawn shop** venue whose only
interaction is its sell counter.

**This prompt supersedes and absorbs two queued prompts** —
`v04_meta_collection_loadout_prompt.md` and
`v04_meta_collection_economy_polish_prompt.md` (both deleted from the queue;
their requirements are folded in below). Do not look for them.

## Read first

- `docs/plans/0.4_act1_completion_plan.md`
- `docs/plans/item_collection_meta_system_plan.md` (rev 2)
- `docs/todone/item_meta_p0_collections_schema_prompt.md` +
  `docs/todone/item_meta_p1_bag_drops_prompt.md` execution records
- `scripts/core/meta_collection_service.gd`, `collection_item_resolver.gd`,
  `collection_drop_service.gd`
- `scripts/core/run_generator.gd` (run start / home-start wiring),
  `run_state.gd`, `world_map.gd`
- `scripts/ui/foundation_main.gd`, `world_map_canvas.gd`,
  `pixel_scene_canvas.gd`, `meta_collection_view_model.gd`
- `data/environments/archetypes.json` (back_alley, motel_room, apartment,
  house archetypes shipped in 0.3.3; open-hours fields from the time system)
- `scripts/tests/collection_meta_check.gd`, `ui_scene_compile_check.gd`

## Owner decisions (binding)

1. The purchased meta-home is **linked** to the run-side starting home for
   **normally generated runs only**. Daily runs and challenge runs are fully
   isolated: no home-start change, no loadout injection, no meta drops, no
   usage decay — they neither read nor write the meta collection.
2. Housing is bought once with gold and never charges rent in this release.
   Leave a `rent` design note in code comments/data as a future hook, but
   implement no rent mechanics.
3. Selling happens at the **pawn shop sell counter** from day one — the pawn
   shop's single interaction. Nothing else there is interactive.
4. Homeless (back alley) players can do **everything except trade-ups**, but
   their storage is only what their owned containers hold, and **everything
   they own is carried into every normal run**. Trade-ups unlock at
   apartment or house tier (not motel).

## 1. Meta world map and travel

- Out-of-run travel reuses the world-map system/canvas in a **meta mode**:
  nodes are the player's current housing and the pawn shop. Travel is free
  and clockless for now. Entered from the main menu (this replaces the
  collection-browser menu entry; route the old entry to the home).
- Keep the node list data-driven so future meta venues (interactive pawn
  interior expansions, etc.) are additions, not rework.

## 2. Housing progression

- `MetaCollectionService` gains `housing_tier`
  (`back_alley` → `motel_room` → `apartment` → `house`), persisted,
  normalized, default `back_alley` (the player starts homeless).
- Upgrades are purchased in-world (an upgrade prop/sign inside the current
  home showing the next tier and price) with **gold only**, sequential
  (alley→motel→apartment→house), one-time, permanent.
- Prices are data in collections/meta config, not code. Propose numbers
  against the actual P1 drop rates and your pawn pricing curve so the
  motel is reachable in a handful of successful runs; document the rationale
  in the execution record. Starting proposal to tune: motel 60, apartment
  250, house 600.
- Tier effects (data-driven):
  - **Storage**: alley = containers only (see §4); motel 8, apartment 16,
    house 32 home-storage slots (tunable).
  - **Trade-up station**: present only at apartment/house.
  - Cosmetics: each tier renders its own archetype — reuse the shipped
    0.3.3 room archetypes in a meta interaction mode.

## 3. The home environment (replaces the collection browser)

Walkable room using the existing environment rendering (pixel scene canvas
+ archetype spots) with meta interaction props:

- **Storage/containers**: owned items render as inspectable storage. Item
  inspection shows what the item does (resolved effects), its four floats
  with condition/usage bands, tier color, and collection — through the
  shipped glyph/badge system. Sort/filter by collection, tier,
  owned/unopened, and packed state in the storage list view.
- **Packing**: assign items to owned containers for the next run. Capacity
  is per-container (bag/backpack/suitcase/trunk capacities come from the
  existing container data — do not invent a second capacity source).
  Duplicate packing of one instance is impossible.
- **Bag opening**: the P1 single-button open, upgraded to a compact reveal
  panel (item name, collection, tier color, condition band, four floats).
  Simple and short; no long animation system, no near-miss theatrics.
- **Trade-up station** (apartment/house only): consume 5 same-tier,
  same-collection items → 1 next-tier item of that collection; per-float
  mean inheritance with seeded jitter from the persisted meta RNG stream;
  gold tier terminal; history recorded; armed-confirm destructive flow.
- Gold balance always visible at home and pawn shop.

## 4. Containers and the homeless rule

- The player spawns with one starter bag (capacity from container data).
  Additional containers are the ones already earnable through the shipped
  systems; total carry capacity = sum of owned containers' capacities.
- **Homeless:** there is no home storage. Everything owned lives in the
  containers and ALL of it enters every normal run (auto-packed, capped by
  container capacity — the cap is also the ownership cap while homeless;
  handle the acquire-while-full case by blocking bag opening with a clear
  "no room" reason rather than deleting anything).
- **Housed:** the player chooses what to pack; unpacked items stay in home
  storage, safe from decay.

## 5. Run linkage (normal runs only)

- Run start (normal generation): the run's starting environment is the
  owned housing archetype (homeless → back_alley start). Packed containers
  inject their items into the run inventory via `CollectionItemResolver` —
  once, at generation, seed-stable for identical loadouts. Injected items
  keep their meta instance id mapping; deterministic gameplay never reads
  the meta store mid-run.
- Run end (normal runs): settle once — P1 bag drops grant, and on terminal
  **failure** every carried item decays its `usage` float by the
  data-defined amount (victory/clean exit: no decay). Items are never
  deleted by decay.
- Daily and challenge runs: current behavior untouched end to end (assert
  this in tests — it is an owner-binding rule, not an optimization).

## 6. Pawn shop (stub venue, one interaction)

- New meta-only archetype (art through the existing icon/archetype
  pipelines; modest is fine), reachable via the meta map.
- **Sell counter** (the only interaction): sell owned item instances AND
  unopened bags for gold. Deterministic price: items
  f(tier base, condition, usage, potency band); unopened bags f(tier).
  Armed-confirm destructive flow; sale history recorded. Gold is minted
  ONLY here (and consumed by housing/trade-ups) — no other faucets.
- Everything else in the room is non-interactive dressing for now.

## Hard constraints

1. `MetaCollectionService` stays strictly outside RunState: inject once at
   run start, settle once at run end; no meta reads/writes mid-run.
2. All rolls (trade-up, pricing inputs if randomized — prefer none) from
   the persisted meta RNG stream; no wall-clock, no unseeded randomness.
3. Old/corrupt meta stores normalize to defaults; every new field
   round-trips save/load idempotently.
4. Local-only economy: no Steam, no market, no real-money framing, no
   prestige purchases, no rent.
5. The in-run inventory popup (`RunInventoryScreen`) is untouched.
6. Zero per-frame allocations in the new meta screens; cached textures;
   per-frame paths stay zero-copy (see CLAUDE.md).
7. Do not weaken validators/tests; extend them.

## Tests (extend collection_meta_check.gd + ui_scene_compile_check.gd + foundation_check.gd)

- Housing: purchase sequence and gold math; tier gates trade-up; defaults
  to back_alley; persists/round-trips.
- Homeless rule: everything auto-carried; capacity cap enforced; open
  blocked (not lossy) when full; housed packing is selective and
  duplicate-proof.
- Run linkage: normal run starts at owned housing with injected loadout,
  seed-stable (two processes hash-match); daily and challenge runs are
  byte-identical to pre-feature behavior and never touch the meta store.
- Decay: failure decays exactly the carried set; victory decays nothing;
  never deletes.
- Pawn: price determinism for items and bags; gold mutation; history; armed
  confirm prevents rapid-click double-sells.
- Trade-up: eligibility (tier + housing), output tier/collection, float
  inheritance from the seeded stream, gold-tier rejection, history.
- UI: home interactions and reveal panel fit and compile per the scene
  check's patterns; meta map reaches home and pawn shop and back.

## Done gate

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -TimeoutSec 600`
- `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5 -SeedPrefix V04-METAHOME`
- Prompt archived to `docs/todone/` with execution record; QUEUE.md updated.
  Commit locally per queue lifecycle; do NOT push.
