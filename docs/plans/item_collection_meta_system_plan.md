# Item Collection Meta System — Design Plan

Date: 2026-07-06
Status: PLANNING (owner-directed). Promote to docs/todo prompts per phase once
dependencies land. Owner reference model: Counter-Strike item system
(collections, rarity tiers, float values, trade-up contracts) adapted to a
single-player, non-monetized gambling roguelike.

## Vision

A persistent collection meta-game layered over runs. Players earn **bags**
(containers) through gameplay; a bag belongs to a **collection** and its bag
type/color encodes the **tier** of the item inside. Opening a bag yields an
item whose stats are defined by **three float values** rolled at drop time.
Items live in the player's **meta-home** — a persistent, rented home viewed
*outside* the run — and are packed into a **backpack loadout** to be carried
into runs, where they behave as run items. Duplicate/unwanted items feed an
**upgrade (trade-up)** path to higher tiers. The inventory UI is reworked to
serve both the run and the meta collection.

## Compliance framing (binding)

Beat the House is simulated gambling with no real-money anything. Bags are
**earned through play only** — never purchasable with real money, no
tradable/market economy, no external value. This is a progression/collection
system, not a monetized loot box. All content text must respect the existing
framing (see release checklists' "simulated gambling only" identity line).

## Terminology

| Term | Meaning |
| --- | --- |
| Collection | A themed set of items (e.g. "Boardwalk Collection") with items at multiple tiers |
| Bag | A container drop; art/type encodes tier; belongs to one collection |
| Tier | blue → purple → pink → red → gold (ascending rarity, CS-style) |
| Floats | Three per-item rolled values in [0,1] that combine to define the item's characteristics |
| Meta-home | Persistent rented home visited outside runs; stores the collection |
| Loadout | Items packed into the backpack and carried into a run |
| Trade-up | Consume N same-tier items from one collection → 1 item of the next tier |

## 1. Data schema

New `data/collections/collections.json` (data-driven, validated on load like
existing content):

- **Collection**: `id`, `display_name`, `theme`, `items` (per tier lists),
  `bag_asset_map` (tier → bag art; existing untracked art
  `assets/art/items/{bag,backpack,suitcase,trunk}.png` seeds the container
  visuals), unlock condition.
- **Collection item**: `id`, `display_name`, `tier`, `base_effect` (same
  effect-key vocabulary as `data/items/items.json` — `baseline_luck_delta`,
  `win_chance`, etc. so run integration reuses the existing item pipeline),
  `float_bindings` (below), flavor text, icon (icon_sprites.json format).
- **Float semantics** (the three floats, each rolled in [0,1] at drop time):
  1. `potency` — scales the magnitude of the item's primary effect between a
     min/max band defined per item (`float_bindings.potency: {effect_key,
     min, max}`).
  2. `condition` — wear/quality: drives sell/salvage value, display name
     suffix bands (e.g. Battered / Worn / Clean / Crisp / Mint), and visual
     accent.
  3. `resonance` — weights a secondary/quirk effect unique to the item
     (`float_bindings.resonance: {effect_key, threshold, value}` — quirk
     activates above threshold, stronger near 1.0).
  The triplet combines into one item identity: two "Lucky Keychain" drops
  play differently. Bands and thresholds are data, not code.

## 2. Acquisition (bag drops)

- Drop moments (seeded from the run seed so the determinism gate holds): run
  victory (guaranteed), showdown completion, first-time challenge clears,
  high-heat clean escapes, lender payoff milestones. Weights and tier odds
  are data (`drop_tables` in collections.json).
- Tier odds follow a CS-like descending curve (config, e.g. blue 60 / purple
  25 / pink 10 / red 4 / gold 1) — tunable per drop moment.
- Bags accumulate in the meta-home **unopened**; opening happens at the
  meta-home with a reveal ceremony (simple first pass: staged reveal panel;
  no gambling-adjacent near-miss theatrics — see compliance framing).

## 3. Meta persistence (new layer — does not exist today)

- New `scripts/core/meta_collection_service.gd` owning
  `user://meta_collection.json`: schema-versioned, atomic write (follow
  `user_settings.gd`'s pattern at scripts/core/user_settings.gd:6,67),
  corruption-tolerant load with normalization (follow RunState's
  normalize-on-load discipline).
- Holds: unopened bags, owned items (with float triplets), backpack loadout,
  meta-home state (rent status, placed decor), collection progress,
  trade-up history.
- **Strictly outside RunState.** Runs read the loadout once at run start
  (injection, §5) and write earned drops once at run end. No mid-run meta
  writes — this keeps the SB.3 save fuzz and SB.5 determinism contracts
  untouched inside runs.
- `data/prestige/purchases.json` is an empty stub today; fold prestige
  ambitions into this meta layer rather than maintaining two meta systems.

## 4. Meta-home (overarching home, outside the run)

- Distinct from the **run-side home** currently in progress
  (docs/todo/home_environment_feature_prompt.md: apartment/motel_room/house
  as run start environments). The meta-home is where the player *lives
  between runs*: entered from the main menu, not travel.
- First pass reuses the run-side home's environment rendering (same
  archetypes/pixel scene canvas) in a "meta" mode with different
  interactions: browse collection, open bags, pack backpack, trade-up
  station, pay rent.
- Rent: meta-home tier (apartment → motel → house mirrors run-home art)
  charged from a meta wallet funded by run results; lapsed rent downgrades
  storage capacity (design lever, tune later — do not build eviction
  spirals in v1).
- Container furniture = storage capacity; container/bag tier unlocks
  (bag → backpack → suitcase → trunk) gate **loadout slots**, not storage.

## 5. Backpack loadout → run integration

- Pre-run (or at meta-home), player packs up to N items; N = unlocked
  container tier (bag 1 / backpack 2 / suitcase 3 / trunk 4 — tune).
- At run start the loadout is injected as normal run items: each collection
  item resolves to an items.json-compatible dictionary with float-scaled
  effect values, flowing through the existing item pipeline
  (run_action_service/run_state) unchanged. The injection is part of run
  generation (seed-stable given the same loadout; the loadout itself is
  recorded in the run's save for SB.3 idempotence).
- **Risk ruling (recommended):** carried items are *staked* — lost on run
  failure (bust/arrest), kept on victory/clean exit. This makes packing a
  gambling decision consistent with the game's identity, and gives duplicate
  drops purpose. Alternative (safe mode): items always return but go "on
  cooldown" after a failed run. Decide before Phase 2 implementation; the
  schema supports both (`loadout_policy` field).

## 6. Trade-up (upgrade between tiers)

- Consume N (default 5 — fewer than CS's 10, collection sizes are smaller)
  items of tier T from the same collection → receive 1 random tier T+1 item
  of that collection.
- Float inheritance CS-style: output floats = per-float mean of inputs
  remapped into the output item's band, with a seeded jitter. Gold tier is
  terminal (no trade-up out; gold duplicates salvage into meta wallet).
- Trade-up rolls use a dedicated seeded stream in the meta service (recorded
  in the meta save for auditability); they happen outside runs, so run
  determinism is untouched.

## 7. Inventory rework

- Builds directly on two queued/in-flight pieces: the extracted
  `RunInventoryScreen` + view model (verify its prompt reaches todone first)
  and the attribute glyph system (tier = the class badge; tier colors
  blue/purple/pink/red/gold join the glyph registry; float bands render as
  badges).
- One inventory component, two model sources: run inventory (existing view
  model) and meta collection (new meta view model) — same grid/detail UI,
  different intents (run: use/sell/store; meta: pack/trade-up/place/salvage).
- Sort/filter by collection, tier, float bands.

## 8. Phasing (each phase = one future docs/todo prompt)

| Phase | Scope | Depends on |
| --- | --- | --- |
| P0 | collections.json schema + validation; MetaCollectionService with versioned save; float roll + effect resolution unit coverage | CRITICAL table bug fixed; nothing else |
| P1 | Bag drops at run milestones + unopened bag storage + basic collection browser (list UI) | P0 |
| P2 | Backpack loadout + run-start injection + risk ruling | P0, run inventory extraction verified |
| P3 | Meta-home scene (browse/open/pack in-world) + rent | P1, run-side home feature shipped |
| P4 | Trade-up station + salvage economy + collection completion rewards | P1 |
| P5 | Reveal ceremony polish, glyph/tier badge integration, sort/filter | P2, attribute glyph system |

## Open design questions (owner input wanted before P0 promotion)

1. Risk ruling for carried items (§5): staked (recommended) or cooldown?
2. Do bag *drops* announce their tier before opening (CS-style known-case,
   suspense on item) or is the tier itself hidden until opened?
3. Collection count at launch: recommend 2 collections × ~12 items each
   across 5 tiers to keep trade-up viable without dilution.
4. Does the meta wallet share the run bankroll currency or use a separate
   currency (recommend separate — protects run economy balance).
