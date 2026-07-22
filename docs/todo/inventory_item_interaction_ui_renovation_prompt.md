# Agent Prompt - Renovate Inventory, Bags, and Item Interaction UI

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike targeting Web/itch.io and Windows at a 1280x720 design resolution.
The UI is built in code. This task renovates the inventory and every player-item
selection surface so it feels like handling physical possessions, not choosing
rows from a menu.

Read completely before editing:

1. `docs/plans/0.5_inventory_item_interaction_ui_renovation_plan.md` - binding
   specification for this task.
2. `docs/plans/0.5_ui_overhaul_brief.md` - broader UI direction where it does
   not conflict with this prompt.
3. `docs/plans/item_collection_meta_system_plan.md` - meta instances, bags,
   storage, loadout, and trade-up context.
4. `docs/plans/0.5_sals_pawn_shop_resale_shelf_plan.md` and
   `docs/todo/sals_pawn_shop_resale_shelf_prompt.md` if present - Sal shelf and
   exact-instance transaction integration. Do not undo work already landed or
   currently in the working tree.
5. `docs/plans/content_style_guide.md` - binding copy style.
6. `docs/todone/run_inventory_screen_extraction_prompt.md` - executed history
   for the component/view-model boundary. It is not a second active prompt.
7. `docs/todone/playtest_map_moves_on_selection_prompt.md` - selection may
   change emphasis/details but must not make the underlying view jump.

## Outcome

Deliver one coherent spatial item-interaction system:

- all applicable possessions appear as objects in a physical container surface;
- an open Bag has 3 spaces, Backpack 5, Suitcase 7, and Trunk 10;
- each container has new, type-specific open-interior pixel art;
- selecting an item uses map/environment-style hover, focus, highlight, detail,
  and confirm behavior;
- the container itself stays stable when selection changes;
- when a merchant, Sal, lender, repair service, home container, or trade-up
  station needs a player-owned item, the player visibly pulls out the same
  container and selects the item from it;
- all current gameplay rules, prices, exact instances, token confirmations,
  capacity rules, saves, and RNG authority remain intact.

Do not implement this as a reskinned grid of text buttons. The container art,
authored slot placement, item objects, spatial focus, and transaction context
are acceptance requirements.

## Before editing: audit, baseline, and dirty-tree safety

The working tree may contain active work in the high-traffic meta and UI files.
Treat every existing modification as user-owned. Do not reset, revert, overwrite,
or reformat unrelated changes. Inspect `git status` and `git diff` before the
first edit and again before handoff.

At minimum trace:

- `scripts/ui/run_inventory_screen.gd`: public API, signals, layout, selection,
  rendering, small-screen behavior, and test helpers;
- `scripts/ui/run_inventory_view_model.gd`: all modes and item/source shaping;
- `scripts/ui/foundation_main.gd`: run inventory entry points, public snapshots,
  environment input blocking, meta popups, bag opening, pack/unpack, sales,
  trade-up, dialogue, save, and refresh paths;
- `scripts/core/run_state.gd`: carried inventory, placed home containers,
  capacity, transfer, meta-loadout mirrors, save/restore, and duplicate rules;
- `scripts/core/run_action_service.gd`: item detail, active item, sale, repair,
  pawn, ticket, and mutation results;
- `scripts/core/meta_collection_service.gd`: exact instance identity, owned
  containers, carry/storage capacity, carried projection, bags, pack/unpack,
  quote/arm/confirm sale, trade-up, persistence, and RNG;
- `scripts/core/collection_item_resolver.gd`: exact instance floats, art/icon
  resolution, tiers, special classes, and display details;
- `scripts/ui/meta_collection_view_model.gd` and
  `scripts/ui/meta_session_controller.gd`: owned rows, unopened bags, sale rows,
  Sal shelf rows, trade candidates, and physical meta environments;
- `scripts/ui/world_map_canvas.gd`,
  `scripts/ui/world_map_overlay_controller.gd`,
  `scripts/ui/environment_interaction_controller.gd`, and
  `scripts/ui/environment_interaction_view_model.gd`: hover/focus/selected/
  confirm vocabulary and input routing;
- `data/items/items.json`: container definitions, capacity, current 32x32 closed
  icons, and item art fields;
- `data/collections/collections.json`: bag and item definitions;
- UI, collection-meta, environment-layout, save, determinism, accessibility,
  and performance tests.

Write a concise migration map before implementation:

| Context/state | Current UI owner | Business authority | New spatial host | Identity key | Required regression |
| ------------- | ---------------- | ------------------ | ---------------- | ------------ | ------------------- |

Include inspect, active item, run merchant sale/repair, run pawn/redeem, place
container, run home transfer, meta pack/unpack, unopened bag/reveal, Sal item and
bag sale, Sal buyback if landed, shelf purchase arrival, and trade-up.

Run relevant baselines before editing. Store reports under `.tmp/`; do not add
them to source control. Record the baseline command, result, duration, and any
pre-existing failures. Use a suite timeout of at least 300 seconds and at least
1.5x the measured baseline duration.

## Non-negotiable authority rules

1. `RunState`, `RunActionService`, and `MetaCollectionService` remain gameplay
   and mutation authority.
2. A renderer or UI controller cannot infer or apply a sale, repair, pawn,
   redeem, pack, unpack, transfer, bag roll, or trade-up result.
3. Prices, floats, effects, capacity, eligibility, disabled reasons, and token
   validity arrive from services/view models.
4. Run item selection preserves `(item_id, storage_source)` identity.
5. Meta items, unopened bags, and shelf items preserve exact `instance_id`.
6. Duplicate display names or definitions never collapse distinct instances.
7. UI open, close, hover, focus, selection, paging, resize, redraw, and animation
   consume no RNG and perform no save mutation.
8. Permanent actions retain the existing arm/confirm boundary. One click that
   selects an item must never sell, pawn, consume, trade, or discard it.
9. Existing container capacities are authoritative:
   - Bag: 3
   - Backpack: 5
   - Suitcase: 7
   - Trunk: 10
10. Source those values from `data/items/items.json` through existing content
    access. The list above is an assertion for tests, not a second runtime table.
11. This task does not add item weight, rotation, stacking, drag-placement rules,
    or a new capacity economy.
12. Slot position is presentation unless current state already records a real
    container assignment. Do not add save fields merely to preserve cosmetic
    order.
13. Every applicable owned item must be reachable. Remove the existing display
    truncation at 10 owned items, 12 sale options, and preselected first-five
    trade sets.
14. The physical six-slot Sal shelf remains Sal's inventory. Do not turn it into
    another popup shop list.

## A. Create the container visual catalog and new art

Add a focused data catalog under the repository's established data/UI location.
The final path and schema may follow local conventions, but one record per
presentation must define:

- stable container type;
- open-interior background texture;
- optional foreground/occlusion texture;
- normalized slot rectangles or centers;
- item-icon safe size/scale;
- container name/count anchor;
- optional empty-slot visual treatment;
- fallback behavior.

Required presentations:

1. `bag`: exactly 3 authored spaces;
2. `backpack`: exactly 5 authored spaces;
3. `suitcase`: exactly 7 authored spaces;
4. `trunk`: exactly 10 authored spaces;
5. `loose_carry`: a coat lining, counter mat, or equivalent presentation that
   does not imply a new finite gameplay capacity;
6. a home-storage presentation suitable for housing-backed collection storage,
   or a clearly documented composition that uses the home's existing physical
   storage/container surfaces.

Create brand-new open-container pixel art. Do not scale the existing 32x32
closed icons into backgrounds. Preserve those icons for item offers and closed
container selectors. New art must:

- match the existing sharp, nearest-neighbor pixel treatment and casino palette;
- clearly read as the inside of its named object;
- leave visual room for its exact number of item spaces;
- support a foreground lip/rim layer where useful so items appear inside;
- contain no baked-in inventory items;
- remain readable at 1280x720 and the repository's small-screen fixture;
- have import settings consistent with the project's texture-filter policy;
- include source/provenance notes required by repository art conventions.

Add catalog validation. Fail loudly in development/test if:

- a required container type or art path is missing;
- a slot lies outside normalized bounds;
- slots overlap beyond a small documented tolerance;
- slot count differs from authoritative content capacity;
- a foreground/background dimension pair is incompatible.

At runtime, corrupt or missing optional catalog data must degrade to a neutral
generated frame and deterministic generated slots. Items remain accessible; no
art failure may hide or destroy an item.

## B. Build one pure spatial container surface

Create a reusable component such as
`scripts/ui/inventory_container_surface.gd`. Naming may match repository style,
but there must be only one implementation of container art lookup, slot
geometry, hit testing, focus navigation, and selected-state rendering.

The component receives a pure dictionary model and emits intents. It may receive
an injected texture provider. It must not import, retrieve, or mutate `RunState`,
`RunActionService`, `MetaCollectionService`, save files, or RNG.

Minimum surface API:

```gdscript
signal slot_hovered(selection_key: String)
signal slot_selected(selection_key: String)
signal slot_confirmed(selection_key: String)
signal container_changed(container_key: String)

func configure(texture_provider: Callable, catalog: Dictionary) -> void
func update_model(model: Dictionary) -> void
func selected_key() -> String
func focus_selection(selection_key: String, emit_intent: bool = true) -> void
func layout_snapshot() -> Dictionary
```

Equivalent typed APIs are acceptable. The model must be domain-neutral and
contain no live service object.

Each container model supplies:

- `key`, `container_type`, `display_name`, `capacity`, and `read_only`;
- stable slots with `slot_index`, occupied state, selection key, item display
  model, actionable flag, and disabled reason;
- selected and multi-selected keys;
- count/capacity, paging, and context labels as needed.

Each item display model should be complete enough for the host detail panel:

- exact identity fields required by its domain;
- display name, description/flavor, icon/asset, class/domain/tier;
- storage source/location;
- floats, condition band, attribute badges, and effects where applicable;
- price/quote/cost fields supplied by authority;
- available actions and disabled reasons;
- packed/active/read-only/armed/multi-selected states.

### Rendering contract

- Draw background art, empty spaces, item icons, state overlays, then optional
  foreground occlusion.
- Empty spaces must be visible but must not look occupied.
- Selected item gets the strongest outline and a local emphasis/spotlight.
- Keyboard focus and hover are visually distinct from committed selection.
- Multi-selected trade inputs use numbered/checkmarked markers without hiding
  current focus.
- Disabled items are dimmed only enough to remain inspectable.
- High-contrast mode uses accessible palette tokens, not hard-coded invisible
  shades.
- Item names, state, and disabled reasons are available without relying on
  color, hover, or art alone.
- Do not pan, zoom, resize, resort, or reflow the container because selection
  changed. A local item lift or detail transition is allowed.
- Reduced-motion mode disables translation/scale/tween emphasis while keeping
  outline and detail changes.

### Input contract

- Pointer click/tap commits selection; hover previews without replacing it.
- Keyboard/controller directional navigation chooses the nearest eligible slot
  in the intended direction using slot-center geometry, stable tie-breaking by
  slot index.
- Confirm on an unselected slot selects it. Confirm again or an explicit action
  advances only when the host mode allows it. Permanent actions still require
  the service confirmation step.
- Cancel exits the current detail/confirm layer first, then closes the surface.
- Shoulder/tab actions cycle visible containers/pages and announce the new
  container and position.
- Initial focus order: prior valid selection, first actionable occupied slot,
  first inspectable occupied slot, Back/Close.
- Focus must never escape behind the blocking overlay.
- Touch targets obey `SmallScreenPolicy`; overlapping item art cannot create
  overlapping hit regions.

Do not clear and recreate the entire component tree for hover/focus changes.
Pool slot controls or update their state in place. Texture and geometry lookups
must be cached.

## C. Define shared selection and reconciliation rules

Create stable, domain-qualified selection keys. Examples:

- `run:carried:odds_notebook`;
- `run:container:home_box:odds_notebook`;
- `meta:item:1042`;
- `meta:bag:2044`;
- `pawn:ticket:sals_lucky_coin_ticket`.

Do not rely on display name or slot index as item identity.

When a new model arrives:

1. preserve the selected key if it still exists;
2. otherwise select the occupied slot nearest the previous slot center within
   the same container;
3. otherwise choose the first occupied slot in the next applicable container;
4. otherwise focus Back/Close;
5. clear ephemeral armed/multi-select state if its exact items are no longer
   present or eligible.

Adding an item after a bag reveal or purchase may explicitly focus that new
stable key. Removing an item after sale/pawn/trade selects the nearest remaining
item. A failed service result preserves current selection and shows the reason.

Selection and focus are view state only. They must not reorder `inventory`,
`loadout`, `owned_instances`, bags, shelf slots, or save data.

## D. Renovate RunInventoryScreen without breaking its API

Keep `scripts/ui/run_inventory_screen.gd` as the compatibility boundary for
existing Main code and tests. It may host the new spatial component or become a
thin specialization of a shared shell. Preserve the public methods and existing
signals unless all callers and tests are safely migrated with compatibility
wrappers:

- `configure`, `open`, `update_model`, `close`, `is_open`;
- `selected_item_key`, `select_item`, `layout_rects`,
  `rendered_item_child_count`, and `refresh_layout`;
- close, item selected, set active, sell, repair, pawn, redeem, place container,
  store, and take intents.

Extend `RunInventoryViewModel` rather than moving state reads into the component.
It should produce a container-oriented model while retaining legacy top-level
keys needed by `current_run_inventory_snapshot()`.

### Inspect mode

- Show all current carried items.
- Use real meta-loadout container projections when present.
- Use the loose-carry presentation for ordinary/legacy run inventory not assigned
  to a specific container; do not impose capacity.
- Preserve active-item action, attribute badges, description, effect summary,
  repair hint, and sale hint.

### Merchant sale and repair

- Open the same player container over a dimmed but recognizable merchant
  environment.
- Keep unsellable/unrepairable possessions visible and inspectable.
- The committed selected item drives supplied sale/repair action models.
- Existing `sell_inventory_item` and `repair_inventory_item` execute the action,
  autosave, journal/message, and refresh.
- Do not recompute the quote in UI.

### Pawn counter

- Carried pawnable objects use the player container.
- Pawn tickets/debts and any ticket pile use a distinct counter tray/sleeve
  surface so the UI does not imply they are ordinary bag contents.
- Preserve pawn lender ID, loan amount, ticket face value, Sal cash value,
  payoff, turns remaining, disabled reason, and all existing service calls.

### Place container

- Present carried Bag/Backpack/Suitcase/Trunk as closed selectable container
  objects, then show the selected type/open preview and exact capacity.
- Confirm through the existing placement intent and `RunState` path.
- Placing a container does not also move or create items.

### Home-container transfer

- Render a two-surface source/destination interaction:
  - current carried/loose inventory;
  - the exact placed container interior.
- Stored and carried variants remain distinguishable even if IDs match.
- Explicit Store/Take actions call the current transfer authority.
- Display exact used/capacity count and full/read-only status.
- Meta-loadout mirrors remain read-only and explain why.
- No drag-and-drop path may bypass service validation. Drag may be added as an
  input convenience only if it emits the same intent and still requires the
  existing result/validation path.

Preserve the existing centered/on-screen snapshot requirements. Add container,
slot, and selected-slot geometry to snapshots without deleting or renaming
legacy keys.

## E. Replace meta inventory action-card lists

Add a focused meta item-interaction screen/view model. Reuse the shared spatial
surface and, where practical, the same header/detail/action shell. Do not embed
meta service reads in the visual component.

Replace the generic list rendering reached from:

- `open_meta_container`;
- `open_meta_bag` before the mutation/reveal step;
- `open_meta_sell_counter`;
- `open_meta_trade_up`;
- related confirmation and result popups where item context should remain
  visible.

Keep thin compatibility entry points in Main. Main still coordinates service
calls, saves, room refresh, messages, and dialogue.

### Meta loadout and home storage

- Project packed items across actual owned containers using
  `MetaCollectionService.carried_container_rows()`.
- Show each owned container separately with its real type/capacity.
- Show stored/unpacked collection instances through the home-storage
  presentation. Housing capacity is not a Bag/Backpack/Suitcase/Trunk capacity.
- Pack/Unpack calls remain authoritative and refresh the projection.
- Do not persist cosmetic item-to-slot assignment.
- Preserve Players Card, Grand Casino Chip Stack, loadout eligibility, exact
  floats, condition, tier, collection, and all disabled reasons.
- Back-alley behavior remains exactly as the service defines it; use a loose-
  carry visual and explanatory copy instead of inventing a container limit.
- Every owned instance is reachable. Use container switching/paging or stable
  scroll; never truncate the data passed to the user.

### Unopened bag selection and opening

- Render every unopened bag as an exact object keyed by bag instance ID.
- Selecting shows collection, tier, source, and Open eligibility.
- Call `MetaCollectionService.open_bag(instance_id)` only after explicit Open.
- Capacity rejection happens before any reveal animation and leaves the bag in
  place.
- On success, save exactly once, then animate/display the returned exact result.
- Reveal the returned item instance, definition, floats, condition band, and
  tier. Do not reroll, reconstruct, or randomly choose art in UI.
- Refresh authoritative data and focus the newly granted exact instance in its
  storage/carry surface.
- Reopening the screen replays no reward and consumes no RNG.

The reveal may use a short bag-opening treatment, but it must be skippable,
reduced-motion compatible, and driven entirely by the already-returned result.

## F. Integrate player-item transactions with environments

Opening an item interaction from an NPC/environment must preserve the sense of
place:

- keep the environment visible and dimmed rather than replacing it with a
  generic full-opaque menu;
- label the actor/counter and current action;
- compose the open carried container as though placed on the counter or held in
  front of the player;
- route Cancel back to NPC/environment interaction without accidental movement;
- prevent underlying object clicks and movement while the surface is open;
- return focus to the originating interactable when closed.

### Sal sale flow

- Selecting `meta_pawn_counter:sell` opens the player's spatial collection/
  bag surface, not an action-card list.
- Collection items and unopened bags use exact, distinct identity keys.
- Selection requests/displays the authoritative current quote.
- Sell first calls the existing arm operation; confirmation uses the returned
  token; result comes from confirm.
- Keep the selected item visible through confirmation where possible.
- After success, remove only the exact sold instance and reconcile focus.
- Preserve Sal dialogue reactions implemented by the resale-shelf work.
- Items sold to Sal do not become shelf stock unless an explicit special
  starter-buyback service result says so.

### Sal shelf purchase and buyback

If the persistent shelf work is landed or present in the dirty tree:

- keep browsing/purchasing the six Sal-owned listings in the physical room;
- after purchase, show the exact acquired item arriving in the player's
  inventory surface if capacity/flow calls for it;
- allow the starter buyback dialogue to coexist with the container surface;
- accept/refuse actions use the existing exact-instance pending transaction;
- never duplicate the item between shelf and player container;
- never recompute the float rarity quote in UI.

If that work is not yet landed, add clean extension seams and focused fixtures,
but do not invent a parallel placeholder economy.

### Run merchants and lenders

Run-side seller/repair/lender entry remains in the existing run screen, but
must use the same container art, spatial slots, detail focus, and confirm
language as meta interactions.

## G. Make trade-up an exact five-item spatial selection

Replace precomputed first-five candidate cards with interactive multi-selection
over owned exact instances.

Behavior:

1. Initially all trade-up-eligible items are visible and inspectable.
2. First selected input establishes collection and tier constraints.
3. Compatible items remain actionable; incompatible items remain inspectable
   and show a precise reason.
4. Toggle exact instances into/out of the set.
5. Mark chosen inputs 1 through 5 on their slots and mirror them in a summary
   tray.
6. At exactly five compatible items, show the next-tier result description and
   enable Arm Trade-Up.
7. Call `arm_trade_up(instance_ids)` with the five exact IDs.
8. Display the returned permanent-action confirmation and call
   `confirm_trade_up(token)` only on explicit confirm.
9. On success, save/refresh and focus the exact output instance.
10. On cancel, token failure, or state change, clear only invalid ephemeral UI
    state and preserve all items.

The service revalidates at both arm and confirm. Do not move tier ordering,
collection matching, ownership, or output rolling into UI. Selection order must
be deterministic and visible, but cannot affect RNG unless the authoritative
service already defines that behavior.

## H. Details, action presentation, and copy

The detail area follows committed selection and shows the fields applicable to
that item/context:

- item art and full display name;
- carried/stored/container/pawn/shelf location;
- type/domain or collection/tier;
- description/flavor and effect summary;
- attribute badges;
- all four collection floats and condition band where applicable;
- active/packed/read-only state;
- authoritative price, repair cost, pawn value, payoff, or sale quote;
- available action and disabled reason.

Keep action labels direct: Inspect, Set Active, Pack, Unpack, Store, Take, Open,
Repair, Sell, Pawn, Redeem, Select for Trade, Remove from Trade, Confirm, Back.
Follow `content_style_guide.md`. Do not use verbose tutorial paragraphs where a
short state label and reason suffice.

The focused item should visually come forward in the container while the detail
area updates. This is the requested map/environment-like focus shift. Do not
move the entire container viewport or cause surrounding slots to jump.

## I. Responsive, accessibility, and input requirements

At 1280x720:

- prioritize the open-container stage;
- keep detail/action context visible without covering the selected slot;
- retain recognizable environment context for transactions.

At small-screen dimensions:

- stack the detail region below or beside the container according to available
  aspect ratio;
- preserve art aspect ratio;
- keep the selected item in view;
- use explicit container/page switching if two surfaces cannot fit;
- keep all targets at or above `SmallScreenPolicy` minimums;
- never clip Close/Back/Confirm.

Accessibility:

- full keyboard and controller traversal;
- mouse/touch parity;
- visible focus independent of hover;
- selected/multi-selected/disabled states communicated by shape/icon/text as
  well as color;
- high-contrast palette integration;
- reduced-motion path;
- useful accessible/tooltip text, with no essential fact available only on
  hover;
- deterministic focus restoration to the origin after close.

## J. Snapshot, test, and diagnostics contract

Preserve all existing `current_run_inventory_snapshot()` keys and behaviors.
Extend snapshots with enough read-only detail to test the spatial system:

- active container key/type, count, and capacity;
- container stage rect and stable bounds signature;
- slot index, rect, occupied state, and selection key;
- hovered/focused/selected/multi-selected keys;
- visible container/page count;
- current context/mode and actor/source;
- selected detail/action IDs;
- small-screen, high-contrast, and reduced-motion state;
- control/pool counts useful for leak/performance checks.

Add an equivalent focused meta-item interaction snapshot or component-level
snapshot. Snapshots are read-only and consume no RNG.

### Fail-before coverage

Add tests that demonstrate current deficiencies before replacing the UI:

- current run inventory is a generic card grid without container art/spaces;
- meta owned/sale UI truncates data beyond 10/12 rows;
- trade-up cannot choose five exact arbitrary compatible instances;
- current bag opening mutates directly from a generic interaction without the
  required selection/reveal surface.

Do not keep brittle tests that merely assert an old node class. Test player-
visible contracts and authority seams.

### Catalog/model tests

- required visual types exist;
- authoritative capacity and authored slot counts match 3/5/7/10;
- slot rects are valid, deterministic, and non-overlapping;
- missing art/catalog fallback preserves every item;
- same run ID/different source and same meta definition/different instance have
  distinct keys;
- no applicable owned item or bag is dropped or duplicated;
- multiple-container projection remains deterministic;
- model/view construction does not change RNG or serialized store snapshots.

### Standalone spatial component tests

- instantiate with fake models and no gameplay services;
- render all four container types and loose-carry fallback;
- verify background/foreground art and exact empty/occupied spaces;
- exercise hover, committed selection, confirm, and container switching;
- exercise directional nearest-slot navigation with stable tie-breaking;
- prove selection changes leave container bounds/signature unchanged;
- verify reduced-motion and high-contrast selected states;
- verify nearest-neighbor selection after removal and explicit focus after add;
- verify no full tree growth after repeated model updates/open/close;
- verify small-screen containment and target sizes.

### Run integration tests

- open/close/selection and existing snapshot compatibility;
- set active;
- merchant sell and repair, including disabled items;
- pawn, cash-ticket pile, and redeem;
- place Bag/Backpack/Suitcase/Trunk;
- store/take at 0, capacity-1, capacity, and full;
- read-only meta-loadout container;
- same item ID with carried/stored sources;
- environment input blocked/restored.

### Meta integration tests

- all owned instances reachable above the former 10-row limit;
- all sale candidates reachable above the former 12-row limit;
- multiple owned containers display 3/5/7/10 spaces as applicable;
- pack/unpack boundary and homeless behavior;
- exact unopened bag selection, capacity rejection, successful single roll,
  result focus, save/load, and no reroll on reopen;
- exact item sale and exact bag sale through arm/confirm token;
- five-item arbitrary compatible trade-up, invalid set, cancel, confirm, and
  exact output focus;
- Sal shelf purchase arrival and starter buyback integration when present;
- dialogue and environment focus recovery.

### Performance and leak tests

- use the largest practical owned-item fixture and all container types;
- record open time, selection update time, control count, and texture count;
- repeated hover/selection must not rebuild the whole surface;
- repeated open/close must not grow child, connection, or tween counts;
- no unbounded history, cache, or retained item-model growth;
- web/small-screen rendering remains responsive.

## K. Suggested implementation order

Keep the project compiling after every slice.

### Slice 1 - audit and pure foundation

1. Record migration map, dirty-tree overlap, baseline results, and timings.
2. Add catalog schema/loader/validation and new open-container art.
3. Add the pure shared spatial component and fake-model tests.
4. Verify no gameplay authority import and no RNG/state change.

### Slice 2 - run inventory

1. Extend `RunInventoryViewModel` with container/slot models and stable keys.
2. Host the surface in `RunInventoryScreen`.
3. Preserve public APIs, signals, entry points, and legacy snapshot keys.
4. Complete inspect/active mode and run regression suite.

### Slice 3 - run transactions and storage

1. Merchant sell/repair container-on-counter context.
2. Pawn/ticket tray context.
3. Place-container preview.
4. Two-surface home store/take and read-only meta mirror.
5. Run integration tests.

### Slice 4 - meta inventory and bag reveal

1. Add meta view model/host reusing the spatial surface.
2. Replace `open_meta_container` card lists.
3. Add every-instance paging/container switching.
4. Replace direct generic bag interaction with select/open/reveal/result focus.
5. Meta loadout, save, determinism, and capacity tests.

### Slice 5 - Sal and trade-up

1. Replace Sal sell list with the player's spatial inventory.
2. Integrate exact quotes, arm/confirm tokens, dialogue, and focus recovery.
3. Integrate shelf purchase arrival/buyback if the shelf work is present.
4. Implement exact five-item spatial trade selection and result focus.
5. Sal/trade integration tests.

### Slice 6 - accessibility, responsive, and final regression

1. Mouse/touch/keyboard/controller audit.
2. High contrast and reduced motion.
3. 1280x720 and small-screen composition.
4. Stress/leak/performance checks.
5. Full validation and documentation update.

Do not combine all slices into one unverified high-traffic Main edit. Keep
changes reviewable and isolate new reusable components from business services.

## Verification

Discover the current supported suite arguments before running them; do not guess
or weaken tests. At minimum run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300
```

Also run the focused collection/meta, environment-layout, determinism/save, and
performance suites discovered during the audit. If concurrent Godot execution
is supported in the current checkout and needed, follow the repository's
documented flag rather than inventing one.

Compare final results with the recorded baseline. Do not classify a new failure
as pre-existing without a matching baseline artifact.

## Completion report

Report:

- migration map and architecture chosen;
- new art/catalog files and exact slot counts;
- components/view models added or changed;
- each old menu/list entry point migrated;
- legacy API and snapshot compatibility;
- authority/RNG/persistence proof;
- mouse, keyboard, controller, touch, accessibility, and responsive coverage;
- tests/commands, durations, and report paths;
- performance/control-count comparison;
- any deviations, remaining known risks, and dirty-tree files deliberately left
  untouched.

## Definition of done

This task is not done until all of the following are true:

- Bag, Backpack, Suitcase, and Trunk use new open-interior art with exactly
  3/5/7/10 selectable spaces sourced from authoritative capacity;
- inventory is a spatial container experience, not a renamed card/list menu;
- every applicable owned item and unopened bag is reachable;
- item focus visibly changes selection/detail without moving the container;
- inspect, active item, merchant, repair, pawn, redeem, placement, home transfer,
  meta loadout, bag reveal, Sal sale/buyback, and trade-up use the coherent
  interaction language;
- Sal's six shelf items remain physical room objects;
- exact identities, prices, floats, effects, capacity, arm/confirm tokens, saves,
  and RNG stay authoritative;
- UI-only interaction is deterministic and mutation-free;
- legacy run entry points and snapshot consumers still work;
- accessibility, controller, touch, small-screen, performance, and leak checks
  pass;
- relevant validation suites pass without weakening unrelated tests.
