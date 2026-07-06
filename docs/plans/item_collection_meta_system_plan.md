# Item Collection Meta System — Design Plan

Date: 2026-07-06 (rev 2 — owner decisions incorporated)
Status: PLANNING. Promote to docs/todo prompts per phase once dependencies
land. Owner reference model: Counter-Strike item system (collections, rarity
tiers, float values, trade-up contracts), adapted to the game — and designed
from day one to be **Steam Inventory Service / community market compatible**.

## Vision

A persistent collection meta-game layered over runs. Players find **bags**
(containers) — themselves extremely rare items, discovered in-game or in
special locations; a bag visibly shows its **collection** and **tier**
(blue → purple → pink → red → gold) before opening. Opening a bag yields an
item whose identity is defined by **four float attributes** rolled in [0,1].
Items live in the player's **meta-home** — a persistent, rented home viewed
*outside* the run — and are packed into a **backpack loadout** carried into
runs. Items are never deleted by play: failure **decays** them. Items leave
the collection only by deliberate destruction: pawn-shop sale for **gold**
(the meta currency) or **trade-up** to the next tier.

## Compliance framing (binding, revised)

In-game acquisition is earned through play only — no real-money purchase of
bags or items in the game itself. The gambling simulation remains free of
real-money wagering. **Steam-marketable items are a planned future layer**
(the CS model: items tradable/marketable on the Steam community market once
Steam Inventory integration ships); when that lands, store-page and framing
language must be revisited deliberately. Until then, everything is local.

## Terminology

| Term | Meaning |
| --- | --- |
| Collection | A themed set of 14 items across 5 tiers |
| Bag | A rare container item; shows collection + tier before opening |
| Tier | blue → purple → pink → red → gold (ascending rarity) |
| Floats | Four per-item attributes in [0,1]: potency, condition, resonance, usage |
| Gold | Meta currency, earned only by destroying items |
| Meta-home | Persistent rented home visited outside runs; stores the collection |
| Loadout | Items packed into the backpack and carried into a run |
| Trade-up | Consume N same-tier, same-collection items → 1 next-tier item |

## 1. Item identity: four float attributes

Each item instance rolls four independent floats in [0,1] at drop time
(seeded). Together with the item type they fully define the instance:

1. **`potency`** — scales the magnitude of the item's primary run effect
   between a per-item min/max band (`float_bindings.potency`).
2. **`condition`** — finish quality at drop: display band (Battered / Worn /
   Clean / Crisp / Mint), base sale value, and visual finish. Immutable.
3. **`resonance`** — weights a secondary/quirk effect (activates above a
   per-item threshold) and drives the **theme variant** of the art.
4. **`usage`** — durability. Starts at its rolled value and **decays by a
   small amount each time a run fails while the item is in the loadout**
   (decay size is data, e.g. 0.02–0.05 per failure, seeded jitter). Usage is
   the only mutable float. It never reaches deletion: at 0 the item is
   "spent" — heavily reduced sale value and dampened potency — but remains
   owned, displayable, and trade-up-eligible. Decay of value over time, not
   destruction.

**Floats drive art, not just stats.** Each of the 14 items per collection
gets a full art rework, authored with variation axes so the floats visibly
modulate: partial/accent colors, hue shifts, wear overlays (condition +
usage), and theme variants (resonance). Two drops of the same item must be
visually distinguishable at a glance.

## 2. Data schema (Steam-compatible from day one)

New `data/collections/collections.json`, validated on load like existing
content. **Design constraint: the schema mirrors Steam Inventory Service
concepts so future Steam integration is a mapping layer, not a redesign:**

- Every item **definition** (including each bag type) carries a stable
  numeric `itemdef_id` (never reused, never renumbered).
- Every owned item **instance** carries a unique instance id plus its four
  floats as dynamic per-instance properties (Steam supports CS-style dynamic
  properties; floats and decayed usage live there).
- Display names compose market-hash-friendly: `"{Item Name} ({Condition
  Band})"`; tier maps to a rarity tag (blue/purple/pink/red/gold), collection
  maps to an item-set tag.
- **Bags are item definitions too** (owner ruling: bags are items in
  themselves) — with their own tier, collection attribute, rarity tagging,
  and eventual marketability. A bag's tier/collection is plainly visible in
  every UI before opening.

Definition contents: collection (`id`, `display_name`, `theme`, per-tier item
lists, bag defs per tier, unlock/discovery rules, drop tables); item
(`itemdef_id`, `id`, `display_name`, `tier`, `base_effect` using the existing
items.json effect-key vocabulary, `float_bindings`, art variation bindings,
flavor).

## 3. Launch content (owner spec)

- **2 collections × 14 items**: 4 × tier-1 (blue), 4 × tier-2 (purple),
  3 × tier-3 (pink), 2 × tier-4 (red), 1 × gold.
- Items are drawn from existing in-game objects but **vetted and curated** —
  each selected item gets completely reworked art authored for float-driven
  variation (§1). Selection list is an owner-review checkpoint in P0.

## 4. Acquisition: bags as rare finds

- Bags are **extremely rare in-game finds**: seeded drop rolls at run
  milestones (victory, showdown, first-time challenge clears, high-heat
  clean escapes) plus placement in **special locations** (rare environment
  spots/events — hooks into the environment/event systems; exact venues
  curated per collection).
- Tier odds per drop table are data (descending curve, e.g. 60/25/10/4/1),
  but the *found bag itself always shows what it is* — collection and tier —
  from the moment it drops. The suspense is which item and which floats.
- Found bags travel home with the run's conclusion and sit **unopened** in
  meta-home storage.

## 5. Opening pipeline (v1: deliberately simple)

- When a bag is **stored in a home container**, it exposes a single
  **Open** button. Pressing it consumes the bag, rolls the item (seeded),
  and plays a **simple reveal animation** showcasing the acquired item
  (name, tier color, floats/bands).
- **Out of scope for now (owner ruling):** the richer container-transfer
  mechanic (transferring containers to the items within them) is a future,
  separate game mechanic with its own plan/prompt. Do not build toward it
  beyond keeping the open pipeline behind one clean function boundary.

## 6. Meta persistence (new layer — none exists today)

- New `scripts/core/meta_collection_service.gd` owning
  `user://meta_collection.json`: schema-versioned, atomic write (pattern:
  scripts/core/user_settings.gd:6,67), corruption-tolerant normalize-on-load
  (RunState discipline).
- Holds: unopened bags, owned item instances (itemdef + instance id + four
  floats), gold balance, backpack loadout, meta-home state (rent, container
  furniture, placements), collection progress, trade-up/sale history.
- **Strictly outside RunState.** Loadout injected once at run start; drops
  and usage decay applied once at run end. No mid-run meta writes — SB.3
  save fuzz and SB.5 determinism contracts stay untouched inside runs.
- `data/prestige/purchases.json` is an empty stub; fold prestige ambitions
  into this layer rather than maintaining two meta systems.

## 7. Meta-home (overarching home, outside the run)

- Distinct from the run-side home currently in progress
  (docs/todo/home_environment_feature_prompt.md). Entered from the main
  menu, not travel. First pass reuses the run-home environment rendering in
  a "meta" mode.
- Interactions: browse collection, open bags (§5), pack backpack, trade-up
  station, **pawn shop counter** (§9), pay rent.
- Rent charged from gold; lapsed rent downgrades storage capacity (tuning
  lever — no eviction spirals in v1).
- Container furniture = storage; unlocked container tier
  (bag → backpack → suitcase → trunk) gates **loadout slots**, not storage.

## 8. Backpack loadout → run integration

- Pack up to N items (N = unlocked container tier; bag 1 / backpack 2 /
  suitcase 3 / trunk 4 — tune).
- At run start the loadout injects as normal run items: items.json-compatible
  dictionaries with float-scaled effects, flowing through the existing item
  pipeline unchanged. Loadout recorded in the run save (SB.3 idempotence);
  injection is seed-stable given the same loadout.
- **Risk ruling (owner decision):** run failure while holding loadout items
  applies **usage decay** (§1.4) to each carried item at run end. Nothing is
  deleted, nothing cools down — value erodes. Victory/clean exit: no decay.

## 9. Destruction economy: gold

Gold enters the meta economy **only** by destroying items — two paths:

1. **Pawn shop sale** (meta-home counter): item is destroyed permanently for
   gold; price = f(tier base, condition, usage, potency band). Spent items
   fetch scrap prices.
2. **Trade-up**: consume 5 same-tier, same-collection items → 1 random
   next-tier item of that collection. Float inheritance: per-float mean of
   inputs remapped into the output item's band with seeded jitter (usage
   inherits too — trading up worn items yields a worn output). Gold tier is
   terminal.

Gold is a **separate meta currency** (owner decision) — never mixed with the
run bankroll. Gold spends on rent (§7) and future meta sinks.

## 10. Inventory rework

- Builds on the extracted `RunInventoryScreen` + view model (verify in
  docs/todone first) and the attribute glyph system (tier colors join the
  glyph registry as class badges; float bands render as badges; bags render
  their collection + tier badges unopened).
- One inventory component, two model sources: run inventory (existing view
  model) and meta collection (new meta view model) — same grid/detail UI,
  different intents (run: use/sell/store; meta: pack/open/trade-up/pawn).
- Sort/filter by collection, tier, float bands.

## 11. Phasing (each phase = one future docs/todo prompt)

| Phase | Scope | Depends on |
| --- | --- | --- |
| P0 | collections.json schema (Steam-compatible ids) + validation; MetaCollectionService versioned save; 4-float roll/decay/effect resolution with unit coverage; owner-vetted 2×14 item selection list | CRITICAL table bug fixed |
| P1 | Bag drops (milestones + special locations) + unopened storage + single-button open pipeline with simple reveal animation + basic collection browser | P0 |
| P2 | Backpack loadout + run-start injection + run-end usage decay | P0; run inventory extraction verified |
| P3 | Meta-home scene (browse/open/pack in-world) + rent + pawn shop counter | P1; run-side home feature shipped |
| P4 | Trade-up station + gold economy balance + collection completion rewards | P1 |
| P5 | Art rework integration for float-driven variation; glyph/tier badges; sort/filter; reveal polish | P2; attribute glyph system |
| P6 (future, separate plan) | Container-transfer mechanic; Steam Inventory Service + community market integration | Owner go-ahead; P0–P5 |

## Resolved owner decisions (2026-07-06)

1. **Risk:** usage-decay on failure (fourth float), never deletion, no
   cooldowns.
2. **Bag visibility:** bags are rare items in their own right; collection and
   tier are visible attributes before opening; bags (and items) must be
   Steam item/market compatible by construction.
3. **Launch size:** 2 collections × 14 items (4/4/3/2/1 across
   blue/purple/pink/red/gold); curated from existing game objects with full
   art rework; four floats modulate partial colors, hue, wear, theme.
4. **Currency:** separate meta gold, minted only by item destruction (pawn
   sale or trade-up consumption).
