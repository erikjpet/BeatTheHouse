## Execution Record

Completion date: 2026-07-20

Implementing commits:

- `dd959027` — Add Sal resale shelf contract tests.
- `ac4ee440` — Replace Sal item quotes with edge rarity curve.
- `745cb40b` — Add persistent six-slot Sal inventory.
- `084566c3` — Stock Sal once after every successful run.
- `9bb3305c` — Add physical Sal shelf purchasing, dialogue, and starter tutorial.
- `03c08bbf` — Polish Sal shelf visual layout and required QA states.
- `ba5be285` — Align fresh meta defaults with protected starter stock.

Verification gates:

- `tools/validate_project.ps1` — PASS (26.8 s in a clean detached worktree at `ba5be285`).
- `tools/collection_meta_check.ps1 -RequireGodot` — PASS (9.8 s after clean import).
- `tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300` — PASS (77.9 s total; systems 25.428 s), report `.tmp/sal_resale_evidence/check_systems/summary.json`.
- `tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300` — PASS (125.4 s total; UI 68.421 s and Dave 5.495 s), report `.tmp/sal_resale_evidence/check_ui/summary.json`.
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` — PASS (31.8 s; 326 checkpoints per run and identical hash `3683536865`).
- `tools/foundation_performance_probe.ps1 -RequireGodot` — PASS (37.2 s; 62 observations and complete renderer/game/resolve/new-surface coverage).
- `tools/foundation_visual_qa.ps1 -RequireGodot` — PASS (37.7 s; 51 states, 10 required Sal states, zero warnings), report `.tmp/sal_resale_evidence/foundation_visual_qa_report.json`.
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100` — PASS (23.8 s; zero stuck states).
- `tools/foundation_mouse_playtest.ps1 -RequireGodot -CleanSave` — PASS (41.2 s; 60 visible-control events, victory and recovery reached, zero warnings/errors), report `.tmp/sal_resale_evidence/foundation_mouse_playtest_report.json`.

Evidence:

- Migration map: `.tmp/sal_resale_migration_map.md`.
- Final readiness record: `.tmp/sal_resale_readiness.md`.
- Desktop screenshot/layout: `.tmp/sal_resale_evidence/layout_screenshots/pawn_shop.png` and `.tmp/sal_resale_evidence/layout_screenshots/layout_report.json`.

Deviations:

- No locked economy, success type, test, timeout, or pricing rule was weakened.
- Concurrent uncommitted inventory-renovation work made the shared tree's validator reject its object-shaped `data/ui/inventory_containers.json` and made its UI runner stop at `Standalone run inventory did not auto-select the first item when selection was absent.` The official systems and UI gates therefore ran in a clean detached worktree at the identical Sal head `ba5be285`; the unrelated files were not edited, staged, or committed.
- A first performance attempt was contaminated by a verified orphaned timed-out UI runner and failed unrelated roulette/baccarat timing rows. After stopping only that headless process pair, the unchanged implementation passed; both attempt reports are retained under `.tmp/sal_resale_evidence/`.

# Agent Prompt — Sal's Pawn Shop: Persistent Resale Shelf and Float-Rarity Tutorial

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike targeting Web/itch.io and Windows at 1280×720. This is a rework of the
landed walkable meta home and collection economy. Do not build a parallel shop
or return Sal's room to a menu.

Read completely before editing:

1. `docs/plans/0.5_sals_pawn_shop_resale_shelf_plan.md` — binding specification.
2. `docs/plans/item_collection_meta_system_plan.md` — upstream collection model;
   this prompt supersedes its conflicting pawn-value assumptions only.
3. `docs/plans/content_style_guide.md` — binding dialogue/copy rules.
4. Executed context in `docs/todone/v04_meta_home_environment_prompt.md`,
   `docs/todone/item_meta_p0_collections_schema_prompt.md`,
   `docs/todone/item_meta_p1_bag_drops_prompt.md`, and
   `docs/todone/CRITICAL_meta_home_must_be_walkable_environment_prompt.md`.
   These are history, not executable prompts.

## Outcome

Turn the current sell-only meta version of Sal's Pawn Shop into a persistent
six-slot resale store:

- exactly one starter listing exists from a fresh/migrated profile;
- every successful run adds one independent bag-generated collection item;
- empty shelf slots fill first, then a random eligible listing is replaced;
- normal listings cost 1.5× what Sal would pay for the exact instance;
- purchases transfer the exact persistent instance to the player for meta gold;
- Sal reacts through dialogue to purchases and sales;
- the discounted damaged starter contains a ≤1% rare non-durability float and
  launches a one-time buyback tutorial;
- all ordinary collection-item pawn quotes use the locked exponential edge-float
  rarity multiplier.

## Before editing: audit and migration map

Trace the landed implementation before changing it. At minimum inspect:

- store load/save/defaults/normalization, instance IDs, gold, quote, arm/confirm
  sale, ownership, capacity, trade-up, and history in
  `scripts/core/meta_collection_service.gd`;
- item definition indexing, bag options, `roll_instance`, normalization,
  `value_multiplier`, and special item classes in
  `scripts/core/collection_item_resolver.gd`;
- run-end success, collection/tier drop selection, bag selection, terminal flags,
  and meta-disabled early returns in `scripts/core/collection_drop_service.gd`;
- Sal environment, six item spots, cache keys, owned/sale rows, and current two
  interactables in `scripts/ui/meta_session_controller.gd`;
- terminal processing, Sal popup/actions, meta save boundary, talk/dialogue
  system, and room refresh in `scripts/ui/foundation_main.gd`;
- pawn archetype/layout in `data/environments/archetypes.json`;
- collection/bag/tier/pricing data in `data/collections/collections.json`;
- dialogue schema and existing speaker patterns in
  `data/dialogue/dialogues.json`;
- collection/meta, profile, UI, determinism, performance, and visual tests.

Write a concise migration map before the first implementation edit:

| Behavior/state | Current owner | New/changed owner | Persistence/RNG seam | Required test |
| -------------- | ------------- | ----------------- | -------------------- | ------------- |

Include quote computation, terminal success, virtual-bag roll, instance ID,
shelf slot, purchase, ordinary player sale, starter offer, dialogue recovery,
room layout, cache invalidation, profile save, and run-report idempotency.

Run relevant baselines and record timing. Keep reports under `.tmp/`. Suite
timeout is `max(300 seconds, ceil(recorded tools/check_godot.ps1 baseline ×
1.5))`.

## Owner-locked rules — do not reinterpret

1. Exactly six Sal resale slots.
2. Exactly one starter item on a new profile.
3. Exactly one new independent stock item after **every** successful run,
   including normal, tutorial, daily, challenge, and otherwise meta-disabled
   victories.
4. Failed runs add nothing.
5. Sal stock is unrelated to the player's drop/bag choice.
6. Items sold by the player to Sal never become stock.
7. Sal stock is generated through the same collection/tier/bag-item/four-float
   logic as a virtual bag opening.
8. Empty slots fill before a random replacement.
9. Normal resale = 1.5× exact pawn quote, rounded up and always at least one gold
   above quote.
10. Starter asking price = 0.75× exact pawn quote.
11. Starter durability/`condition` is below 30%.
12. One seeded starter channel among `potency`, `resonance`, and `usage` is
    forced to 1% or lower. Do not use low `condition` as the valuable rare edge.
13. Starter buyback = 1.25× exact pawn quote.
14. Accepted starter relist = 10× exact pawn quote.
15. The same starter instance and floats move player → Sal on buyback.
16. The special offer resolves once. No repeat buyback exploit.
17. Routine buys/sells and the special sequence use authored Sal dialogue.

## A. Add a six-slot persistent Sal inventory

Extend the authoritative `MetaCollectionService` store schema. Follow its
normalize-on-load, unknown-key preservation, corrupt-store fallback, atomic
write, and monotonic ID conventions.

Persist a normalized shelf state with:

- six stable indexed slots, never five or seven;
- exact item instance per occupied slot;
- provenance (`sal_starter_stock`, `sal_run_stock`, run receipt, virtual bag,
  collection, tier, generation seed);
- listing mode: `normal`, `starter_discount`, or `mocking_relist`;
- starter rare channel/value and tutorial eligibility;
- pending starter buyback transaction;
- seeded/first-purchased/tutorial-resolved flags;
- persisted RNG state;
- bounded replacement/purchase/stock history and processed-run receipts.

Shelf instances must not be returned from player `owned_instances()` and must
not count for collection completion, storage, carry/loadout, trade-up, Steam
ownership, or failure decay. They do consume the shared monotonic local instance
ID namespace. Update maximum-recorded-ID normalization accordingly.

Add focused, typed service APIs for read-only shelf rows, generation/insertion,
purchase quote/arm/confirm, and starter offer resolution. Views must not mutate.

## B. Seed and migrate the starter listing

On a fresh store—or once when migrating any legacy store with no initialized
Sal shelf—generate one starter listing and five empty slots.

Generate the item through the shared virtual-bag pipeline, then:

1. set/clamp `condition` to a deterministic positive value `<0.30`;
2. use the named starter RNG stream to select exactly one channel from
   `potency`, `resonance`, `usage`;
3. set that channel to exactly `0.01` (a value lower than 0.01 is acceptable only
   if deterministically data-authored and tested);
4. preserve the other rolled values;
5. record the rare channel/value explicitly;
6. set listing mode `starter_discount`;
7. calculate asking price from 0.75× the updated pawn quote.

Protect this unpurchased starter listing from full-shelf random replacement so
the tutorial cannot disappear. Remove protection after its first purchase.
Repeated load/normalize/save cannot reroll or duplicate it. Migration cannot
alter existing owned items, bags, gold, housing, loadout, trade history, or sale
history.

## C. Extract a reusable virtual-bag item roll

Do not duplicate private drop/opening logic in three places. Extract/reuse a
pure or focused seeded helper that:

1. selects a collection by the standard base collection rule;
2. selects tier using that collection's normal drop-table weights;
3. resolves the matching bag definition;
4. gets item options with
   `CollectionItemResolver.bag_item_options_for_bag(...)`;
5. selects one option;
6. calls the same `roll_instance(...)` path as real bag opening;
7. returns definition, virtual bag, normalized item, RNG snapshot, and provenance.

Regular stock distribution must match a normal independent virtual bag opening
over many seeds. It must not inspect or reuse the player's pending markers,
selected bag, claimed bag, opened bag, challenge reward, or item sales.

Use named persisted streams such as `sal_resale_stock`,
`sal_resale_replacement`, and `sal_starter_item` according to existing
`RngStream` conventions. UI open/close, room travel, hover, quote, redraw,
snapshot build, save/load, and run-report rerender consume no RNG.

## D. Stock once after every successful run

Integrate the Sal stocking call at the terminal-success boundary before any
existing `meta_collection_enabled_for_run()` early return. Do not enable other
meta rewards for daily/challenge runs; only this owner-approved shelf mutation
crosses that isolation boundary.

Qualifying result: terminal `RUN_STATUS_ENDED`. Nonqualifying:
`RUN_STATUS_FAILED`, abandoned/nonterminal state, preview/dry-run, or a terminal
result already stocked.

For each qualifying actual run attempt:

1. obtain a stable unique serialized run-completion receipt. Reuse an existing
   run identity if one exists; otherwise add the smallest save-compatible
   serialized receipt necessary. Seed text alone is invalid because a real
   same-seed replay must stock again.
2. Verify both run and profile records have not processed the receipt.
3. Roll one independent virtual-bag item.
4. Insert into the lowest-index empty slot if one exists.
5. If full, choose uniformly among eligible occupied slots with the named
   replacement stream. Exclude an unpurchased protected starter.
6. Replace the old Sal listing without paying gold or affecting the player.
7. Append bounded audit history for generation/insertion/replacement.
8. Commit profile shelf + RNG + receipt atomically, then mark/persist the
   terminal run receipt state.
9. Surface one concise run-report line naming that Sal stocked something new,
   without revealing more than the shop UI should reveal.

Repeated report rendering, terminal processing, save retry, app restart, or
loading the same terminal save must not add another item. A genuinely new run
with the same seed must add one.

## E. Replace Sal's ordinary collection-item price curve

For ordinary collection instances only, implement one pure price breakdown.
Clamp all floats to `[0,1]` before arithmetic.

```text
edge(x)       = abs(2x - 1)^4
durability(c) = c^4

rarity_multiplier =
    1
    + 0.5 × edge(potency)
    + 0.5 × edge(resonance)
    + 0.5 × edge(usage)
    + 0.5 × durability(condition)

pawn_quote = max(1, round(tier_base_sale_value × rarity_multiplier))
```

Properties:

- rarity multiplier stays in `[1,3]`;
- 50% potency/resonance/usage contributes 0;
- 0% and 100% potency/resonance/usage each contributes 0.5;
- contribution rises by fourth power near edges;
- 0% condition contributes 0 and 100% condition contributes 0.5;
- low durability is never rewarded as a rare edge.

This pawn quote supersedes the old condition-band/spent multiplier for Sal's
ordinary collection-item payout. Do not layer the old multiplier on top and
reverse the owner-approved edge rarity. The existing run-effect resolution may
continue using landed float semantics.

Do not change:

- unopened bag tier prices;
- Grand Casino chip-stack face-value-rate fencing;
- Players Card special policies;
- housing prices;
- trade-up rules;
- run bankroll/item shop prices.

Refactor ownership-dependent quote code so the same exact pure evaluator can
quote owned and shelf instances. Return:

- tier base;
- clamped floats;
- each float's rarity score/contribution;
- total multiplier;
- pawn quote;
- listing mode/multiplier;
- final asking/offer price.

All UI, dialogue, history, preview, and transaction code uses this result.

## F. Apply listing prices exactly

```text
normal_resale_price = max(pawn_quote + 1, ceil(pawn_quote × 1.5))
starter_price = max(1, round(pawn_quote × 0.75))
starter_buyback_offer = max(1, ceil(pawn_quote × 1.25))
mocking_relist_price = max(1, ceil(pawn_quote × 10.0))
```

The starter is an explicit one-time exception to the rule that Sal asks more
than he pays. All other normal listings must be strictly more expensive than
their exact pawn quote, including quote=1 edge cases.

Persist listing mode and enough quote basis for transparent audit. Never trust a
client/view-provided price at mutation time; revalidate the authoritative slot,
instance, policy, and gold.

## G. Make all six shelf items physical interactions

The meta pawn environment currently clears `item_offers` and exposes only a sell
counter plus exit. Rework it so the six existing archetype `item_spots` map
one-to-one to the six persistent Sal slots.

- Empty slot: visible empty shelf treatment, non-buyable.
- Occupied slot: visible item/icon/rarity treatment and focusable interaction.
- Stable object IDs, e.g. `meta_sal_shelf:0` through `:5`.
- Inspect view shows display name, collection, tier, all four percentages,
  durability, rare-edge contribution, rarity multiplier, Sal pawn quote,
  listing policy, asking price, and current gold.
- Buy action uses armed confirmation.
- Sell Counter remains a separate physical interaction.
- Sal dialogue presence appears at/behind the counter.
- Exit remains separate.

Update environment objective/map copy from sell-only to buy-and-sell. Include
shelf state in the existing lean cache key without rebuilding the full catalog
per frame. Preserve the meta-only top bar, room performance, keyboard/mouse
focus, small screen, accessibility, and reduced motion.

## H. Purchase exact shelf instances with meta gold

Purchase flow:

1. Read slot by stable index/ID.
2. Recompute authoritative asking price.
3. Validate occupied slot, sufficient meta gold, and owned-item capacity.
4. Arm a confirmation token bound to slot, instance ID, listing mode, and price.
5. On confirm, revalidate everything.
6. Atomically debit gold, empty slot, and append the exact normalized instance
   with the same instance ID/floats/provenance to `owned_instances`.
7. Record purchase history, clear pending transaction, save, refresh room/cache,
   then trigger Sal dialogue.

Failure changes nothing. A normal purchase does not reroll or refill its slot.
Only a later successful run stocks it.

The existing player sell flow remains destructive: remove owned item/bag and add
gold. Add Sal reaction dialogue after a committed sale, but never add, copy, or
reference the sold instance as shelf inventory.

## I. Add Sal transaction dialogue

Use the existing authored dialogue/talk system rather than message strings alone.
Create stable Sal speaker/dialogue IDs and concise lines matching the content
style guide.

At minimum add:

- a small deterministic pool of successful ordinary-purchase reactions;
- a small deterministic pool of successful item/bag-sale reactions;
- the blocking starter rare-float sequence;
- accepted buyback and mocking relist continuation;
- declined buyback continuation;
- safe resume copy for a persisted pending offer.

Routine dialogue triggers only after a successful committed transaction, not on
hover, inspect, cancel, insufficient gold, capacity failure, or quote refresh.
Do not let dialogue selection consume RNG on view refresh.

## J. Implement the one-time starter buyback tutorial

After the first successful purchase of the starter listing:

1. Save the completed purchase and persist a pending special offer tied to exact
   instance ID, original slot, rare channel/value, pawn quote, and 1.25× offer.
2. Immediately start blocking Sal dialogue.
3. Sal explicitly notices the rare float (for example, “one-percent resonance”)
   and makes clear that edge values affect collector price.
4. Show the exact buyback gold amount.
5. Offer two choices: **Sell it back** and **Keep it**.

### Sell it back

- Revalidate exact ownership and unchanged identity.
- Remove it from player ownership/loadout if necessary under the blocking
  transaction contract.
- Add exactly the persisted/revalidated 1.25× pawn offer to meta gold.
- Put the exact instance back in its original empty shelf slot.
- Set `mocking_relist`, 10× asking price, and tutorial resolved flags.
- Record both transfers in history and save atomically.
- Continue Sal dialogue with a mocking line establishing his character: he knew
  the roll was valuable, let the player sell it back, and now asks an extreme
  price.

### Keep it

- Leave ownership and gold unchanged.
- Permanently resolve/clear the special offer.
- Continue with Sal acknowledging that the player learned quickly.

App close/reload during the offer cannot duplicate payment or lose the choice.
Resume the unresolved offer on the next safe Sal interaction. The dialogue and
buyback can resolve only once. Purchasing a 10× relist later is an ordinary
purchase and never triggers another 1.25× offer.

## K. Save compatibility and invariants

- Bump/normalize the meta store schema using existing migration conventions.
- Legacy stores receive six slots and one starter exactly once.
- Unknown keys remain.
- Store writes remain atomic.
- Pending ordinary sale/trade-up behavior remains compatible.
- Pending shelf purchase/buyback tokens validate after reload or fail safely
  without mutation.
- Instance IDs remain unique across owned items, bags, containers, shelf stock,
  and special transactions.
- Shelf and dialogue state survive profile restart exactly.
- Corrupt shelf substate recovers conservatively without deleting player-owned
  assets or gold.

## Required automated tests

Add focused coverage to `collection_meta_check` and the relevant foundation/UI
suites.

### Schema/generation

1. Fresh store: six slots, one starter, five empty.
2. Legacy migration: same shelf initialization with all old fields preserved.
3. Repeated normalize/save/load: no new starter or changed floats.
4. Starter: `0 < condition < 0.30`; exactly one recorded selected channel among
   potency/resonance/usage is `≤0.01`; identity is a valid bag-openable
   collection item.
5. Same profile/RNG state gives identical virtual bag, item, floats, slot, and
   replacement.
6. UI/view/quote operations leave RNG unchanged.
7. Over many seeds, stock item/tier/float distribution matches virtual-bag
   generation and never emits bags/special items directly.

### Run stocking

8. Successful normal, tutorial, daily, challenge, and meta-disabled run each add
   exactly one item.
9. Failed/nonterminal run adds none.
10. Report refresh and terminal-save reload cannot add twice.
11. A new same-seed run stocks again.
12. Empty slots fill before replacement.
13. Full shelf replaces one eligible random slot and never the protected starter.
14. Player bag markers/choices do not determine Sal stock.
15. Selling an owned item/bag does not alter shelf slots.

### Float value

16. Exact curve fixtures for every float at 0, .01, .5, .99, and 1.
17. Symmetric floats produce equal contributions at x and 1-x.
18. Condition is monotonic toward 1 and never rewards the 0 edge.
19. Multiplier never leaves [1,3].
20. A 1%/99% non-condition float is worth more than 50%, all else equal.
21. Ordinary item quote uses tier base × rarity only and is pure.
22. Bag, chip-stack, and other special pricing remains bit-for-bit compatible.

### Prices and purchases

23. Normal asking price equals 1.5×/ceiling and is always pawn quote +1 or more.
24. Starter price equals 0.75× rounding rule and may be below quote.
25. Purchase moves exact instance/floats, debits exact gold once, empties one
   slot, honors capacity, and persists.
26. Stale token, insufficient gold, empty/replaced slot, or full storage mutates
   nothing.
27. Purchased slot stays empty until the next qualifying run.

### Dialogue tutorial

28. Normal committed buy/sell triggers appropriate Sal dialogue once; canceled/
   failed transactions do not.
29. Starter purchase immediately persists/opens special dialogue naming correct
   float/value and exact 1.25× offer.
30. Keep choice retains item/gold and prevents future offer.
31. Sell-back choice pays exactly, removes owned instance, returns exact instance
   to original slot, sets 10× price, and shows mocking continuation.
32. Reload during pending offer resumes safely and cannot duplicate gold/item.
33. Repurchasing 10× item never retriggers special buyback.

### Environment/regression

34. Six stable shelf object IDs occupy six authored item spots; empty/occupied
   visuals match state.
35. Sell counter, Sal dialogue, and exit remain separate usable fixtures.
36. Keyboard/mouse, small-screen, reduced-motion, accessibility, and meta top bar
   pass.
37. Existing housing, storage, bag opening, trade-up, collection ownership,
   Grand Casino rewards, and normal run systems remain green.

## Verification gates

Discover supported suite names from the repository; do not invent them. Run and
report at least:

- `tools/validate_project.ps1`
- `tools/collection_meta_check.ps1 -RequireGodot`
- every supported `tools/check_godot.ps1 -FoundationSuite ...` covering systems,
  items/meta, profile/save, run report, UI, dialogue, meta home, and tutorials
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- one strict `tools/foundation_mouse_playtest.ps1`

Manual smoke:

1. Open a fresh profile and visit Sal: one discounted damaged listing, five
   empty slots.
2. Inspect it: condition below 30%, one named non-condition float at 1%, price
   breakdown visible.
3. Earn enough gold, buy it, and verify immediate Sal offer dialogue.
4. Test Keep, then repeat in an isolated profile and test Sell it back.
5. Verify 1.25× payment and exact 10× relist with mocking dialogue.
6. Complete normal/tutorial/daily/challenge successes and verify one stock item
   per actual run.
7. Fill all six slots, complete another success, and verify one random eligible
   replacement.
8. Buy a normal listing, sell it back through the ordinary counter, and verify
   it is destroyed rather than placed on the shelf.
9. Restart around stocking, purchase, and pending buyback boundaries.
10. Inspect 1280×720, supported small-screen, keyboard, mouse, and reduced-motion
    states.

Capture visual QA for fresh shelf, partially filled, full shelf, inspected float
breakdown, starter purchase dialogue, buyback choice, 10× relist, empty slot, and
small-screen layout.

## Completion discipline

Preserve unrelated working-tree changes. Use logical commits:

1. red tests and migration map;
2. rarity valuation;
3. shelf schema/generation/starter;
4. all-success stocking/idempotency;
5. physical shelf purchasing;
6. Sal dialogue and special tutorial;
7. polish, migrations, and gate evidence.

After implementation and all required gates pass, prepend the execution record
required by `docs/todone/RULES.md`, then `git mv` this prompt into
`docs/todone/` in the final evidence commit. Do not simply delete it.

Final report must include migration map, schema changes, formula fixtures,
stocking receipt/idempotency design, generation/replacement RNG, dialogue IDs,
starter exact properties/prices, save migration, gate timings/results, visual QA
paths, commits, and deviations.

If a gate cannot be fixed without violating an owner-locked rule, stop at the
last green commit and report the failure verbatim. Do not weaken tests, exempt a
successful run type, stock player sales, reroll on UI open, or remove the
starter tutorial.
