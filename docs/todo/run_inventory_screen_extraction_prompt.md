# Agent Prompt — Extract RunInventoryScreen UI Component

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4 GDScript casino roguelike. All UI is built in code (no .tscn scenes) inside `scripts/ui/foundation_main.gd` (~12k lines, "Main"). Run/inventory authority lives in `scripts/core/run_state.gd` and `scripts/core/run_action_service.gd`; Main coordinates actions, autosave, journal, and messages.

Your job: extract the run-inventory popup out of Main into a self-contained UI component, `scripts/ui/run_inventory_screen.gd`, that renders from a view-model dictionary and emits intent signals. **Inventory authority stays in RunState/RunActionService; Main keeps action execution.** This is a refactor for modularity and editability — zero behavior change is the acceptance bar for slice 1.

Line numbers below were verified against the current tree; they may drift slightly — trust the function names.

## Hard constraints

1. **The QA snapshot contract must stay green unchanged.** `scripts/tests/ui_scene_compile_check.gd:2825–3030` drives the popup via `app.call("open_run_inventory")`, `app.call("close_run_inventory")`, `app.call("select_run_inventory_item", id, source)`, `app.call("sell_inventory_item", id)`, and asserts on `app.call("current_run_inventory_snapshot")`:
   - keys `visible`, `mode`, `items`, `grid: true`, `selected_item_id`, `selected_item_source`, `selected_item`, `container_id`, `merchant_available`, `shop_description`
   - when visible: `anchor == "screen_center"`, `interaction_kind`, `popup_rect`, `grid_rect`, `detail_rect`, `screen_rect`, `environment_rect`
   - popup centered within 1.5px, fully inside screen, size identical before/after item selection, detail panel wider than grid.
   These existing assertions are the parity proof — do not weaken or rewrite them to make the refactor pass. `current_run_inventory_snapshot()` stays on Main (foundation_main.gd:5889) and sources its rects from the new component.
2. **No RunState/RunActionService reads or writes inside run_inventory_screen.gd.** The component renders only what the model dictionary contains and emits signals. If you find yourself importing RunState there, stop.
3. **Every existing Main entry point keeps its name and signature** — there are ~25 call sites gating input routing and closing the popup (`_run_inventory_popup_is_visible()` at foundation_main.gd:390, 5412; `_hide_run_inventory_popup()` at 461, 568, 1166, 2147, 2247, 8553, 8729, 9589; `_open_run_inventory_popup(mode, container_id)` at 1475, 1485, 1488, 1502, 1511, 1521, 1540, 1575, 1750, 1773, 1796). They become thin wrappers over the component. Do not touch those call sites.
4. Two commits, strictly ordered: **slice 1** = component extraction with wrappers, zero behavior change; **slice 2** = view-model builder extraction, only after slice 1 passes the ui suite. Do not mix.
5. Match house style: tab indentation, typed GDScript (`:=`, typed params/returns), sparse comments stating constraints only, UI built in code.
6. Don't iterate against the full QA harness while developing — verify by reading code, then run the two validation commands once per slice at the end.

## Target shape

New file `scripts/ui/run_inventory_screen.gd`:

```gdscript
class_name RunInventoryScreen
extends Control

signal close_requested
signal item_selected(item_id: String, source: String)
signal set_active_requested(item_id: String)
signal sell_requested(item_id: String)
signal repair_requested(item_id: String)
signal place_container_requested(item_id: String)
signal store_item_requested(container_id: String, item_id: String)
signal take_item_requested(container_id: String, item_id: String)

func configure(texture_provider: Callable) -> void  # Main binds _run_item_texture_for_asset_path
func open(model: Dictionary) -> void
func update_model(model: Dictionary) -> void        # rerender in place, preserve scroll where cheap
func close() -> void
func is_open() -> bool
func selected_item_key() -> Dictionary              # {"id": String, "source": String}
func layout_rects() -> Dictionary                   # popup_rect / grid_rect / detail_rect / screen_rect as Rect2, for the QA snapshot
```

The component owns: overlay + panel construction (today's `_build_run_inventory_overlay()`, foundation_main.gd:3319–3386), the item grid, the detail panel, per-mode action buttons, selection highlight, positioning/clamping, and the `RUN_INVENTORY_POPUP_SIZE` / `RUN_INVENTORY_POPUP_MARGIN` constants (move them here; `model.layout` may override size later).

**Texture loading stays in Main.** `_run_item_texture_for_asset_path` (foundation_main.gd:12294) caches textures; the component calls the injected `texture_provider` Callable with `asset_path` instead of loading itself. Do not duplicate the cache.

### Shared widget builders (prerequisite inside slice 1)

The popup rendering uses Main's stateless builder helpers: `_button` (12228), `_label` (12207), `_muted_label` (12216), `_panel_container` (12021), `_add_detail_row` (12056), `_add_card_button` (12076), `_set_control_font_color` (12094), `_set_control_font_size`, `_style_selected_button` (12327), `_clear` (12333). They only touch `VisualStyle` and the constants `MIN_NATIVE_TOUCH_TARGET_HEIGHT` / `DEFAULT_CONTROL_FONT_SIZE` — no instance state.

Extract them as **static funcs** into a new `scripts/ui/foundation_widgets.gd` (`class_name FoundationWidgets`), moving the two constants (or referencing them from VisualStyle if they already belong there). Main's existing instance methods become one-line delegates (`return FoundationWidgets.button(text, callback)`) so the hundreds of other call sites in Main are untouched. One important difference: the static `button` variant must accept the callback the same way (`pressed.connect(callback)`); do not change styling.

Do **not** duplicate these helpers into RunInventoryScreen.

## View-model contract

Main builds the model; use the **actual field names already flowing through the code** so slice 1 needs no translation layer:

```gdscript
{
	"mode": "inspect",              # "" / "inspect" / "merchant_sale" / "place_container" / "home_container"
	"title": "Inventory",           # Main computes per-mode titles, including the home-container
	                                # display_name (today read via _home_container_by_id inside
	                                # _render_run_inventory_popup_contents, foundation_main.gd:10543–10552 —
	                                # that RunState read moves OUT of render and into model building)
	"summary": "...",               # from _run_inventory_summary_text (foundation_main.gd:11259)
	"container_id": "",
	"selected": {"id": "odds_notebook", "source": "carried"},
	"empty_text": "No run items yet.",   # from _empty_inventory_popup_text (foundation_main.gd:10734)
	"items": [
		{
			"id": "odds_notebook",
			"display_name": "Odds Notebook",
			"description": "...",
			"effect_summary": "...",
			"asset_path": "res://...",
			"item_class": "tool", "domain": "global", "item_type": "...",
			"storage_source": "carried",   # or "container"
			"capacity": 0,
			"sellable": true, "sale_price": 12,
			"repairable": false, "repair_cost": 0,
			"active_item": false, "active_selected": false
		}
	],
	"layout": {"columns": 2}
}
```

### Behaviors to preserve exactly (these are the subtle ones)

- Selection is keyed by **(id, storage_source) pair**, not id alone (`_inventory_popup_has_selection`, foundation_main.gd:10706). Home-container mode lists the same item id as carried and stored variants.
- Opening with a different mode or container_id **resets selection**; reopening with the same mode keeps it (foundation_main.gd:10522–10524).
- When the selection is missing from the item list, **auto-select the first item** (foundation_main.gd:10560–10563).
- Grid card: 124×112 buttons, `"STORED\n"` prefix for container-sourced items, display_name truncated to 18 chars, tooltip = full display_name, teal border for sellable items in merchant mode (`_add_inventory_item_card` 10570, `_inventory_grid_button_text` 10728).
- Detail panel per-mode buttons (`_render_run_inventory_detail`, foundation_main.gd:10599–10653): merchant → Repair-for-N / Sell-for-N; place_container → "Place at Home"; home_container → "Move to Inventory" when `storage_source == "container"` else "Move to Storage"; default → "Set Active"/"Active Item" (disabled+primary when `active_selected`), plus Repair/Sale info rows. Button presses emit the matching signal — nothing else.
- Positioning: clamp to overlay minus `RUN_INVENTORY_POPUP_MARGIN*2`, floor-centered, applied immediately **and** via `call_deferred` after open/select (foundation_main.gd:10530–10531, 10595–10596, `_position_run_inventory_popup` 10746).
- `close()` resets panel size/position to defaults and clears the grid (`_hide_run_inventory_popup`, foundation_main.gd:10769) — Main still clears its own mode/selection mirrors in the wrapper.

## Migration steps

### Slice 1 — component extraction, zero behavior change

1. Create `foundation_widgets.gd` (static builders) and delegate Main's helper methods to it.
2. Create `run_inventory_screen.gd` building the exact node tree of `_build_run_inventory_overlay()` (colors, minimum sizes, stretch ratios 0.78/1.22, separations — copy them verbatim).
3. In Main: delete `_build_run_inventory_overlay()`; construct/`add_child` the component where it was called (foundation_main.gd:2550), call `configure(Callable(self, "_run_item_texture_for_asset_path"))`, and connect every signal to the existing Main methods:
   - `close_requested` → `close_run_inventory`
   - `item_selected` → mirror into `selected_run_inventory_item_id/_source` (QA snapshot reads these) — keep `select_run_inventory_item(item_id, source)` public on Main since QA calls it; it forwards to the component.
   - `set_active_requested` → `select_active_inventory_item` (foundation_main.gd:1581)
   - `sell_requested` → `sell_inventory_item` (1754); `repair_requested` → `repair_inventory_item` (1777)
   - `place_container_requested` → `_place_home_container_from_popup` (1479)
   - `store_item_requested` → `_store_home_container_item_from_popup` (1506); `take_item_requested` → `_take_home_container_item_from_popup` (1516)
   Those Main methods already handle the RunActionService call, autosave, messaging, and refresh-by-reopening (`if _run_inventory_popup_is_visible(): _open_run_inventory_popup(...)`) — that refresh pattern becomes "rebuild model, `update_model(model)`", same visible result.
4. Rewrite the wrappers: `_open_run_inventory_popup` builds the model (using the still-in-Main data helpers below) and calls `open`; `_hide_run_inventory_popup` calls `close` and resets Main's mode/selection mirrors; `_run_inventory_popup_is_visible` returns `is_open()`.
5. Move into the component (pure UI): `_add_inventory_item_card`, `_render_run_inventory_detail`, `_inventory_grid_button_text`, `_position_run_inventory_popup`, `_render_run_inventory_popup_contents`, `_inventory_popup_has_selection`, `_selected_inventory_popup_item` (dedupe: Main's snapshot can keep its own copy reading from the model it built, or ask the component). Delete the Main originals — no dead code left behind.
6. Keep in Main for this slice (they read RunState): `_inventory_popup_item_view_list`, `_inventory_item_view_list` (11119), `_held_container_inventory_details` (10664), `_home_container_inventory_details` (10682), `_run_inventory_summary_text` (11259), `_empty_inventory_popup_text` (title/empty-text become model fields Main fills from them).
7. Update `current_run_inventory_snapshot()` to pull `popup_rect`/`grid_rect`/`detail_rect`/`screen_rect` from `layout_rects()`; every other key comes from Main state exactly as today.
8. Run the two validation commands (below). Commit slice 1.

### Slice 2 — view-model builder extraction

1. Create `scripts/ui/run_inventory_view_model.gd` (`class_name RunInventoryViewModel`, static or RefCounted) with a single entry point taking explicit inputs — `(run_state, run_action_service, mode, container_id, selection)` — and returning the model dictionary. Absorb `_inventory_popup_item_view_list`, `_held_container_inventory_details`, `_home_container_inventory_details`, `_run_inventory_summary_text`, `_empty_inventory_popup_text`, plus the per-mode title logic. Main's `_container_item_option` / `_storable_inventory_item_ids` / `_home_container_by_id` may move too if nothing else in Main uses them — grep first.
2. Main's wrapper shrinks to: build model via RunInventoryViewModel, hand to component, keep snapshot/mirror bookkeeping.
3. No rendering change of any kind in this slice. Run validation. Commit slice 2.

## New regression coverage (extend ui_scene_compile_check.gd, slice 1)

Add a fixture that exercises the component **standalone with a fake model** (no RunState): instantiate RunInventoryScreen, `configure` with a stub texture provider, then assert:

- `open(model)` in inspect mode renders grid cards + detail panel; `is_open()` true; `close()` → false, and no RunState existed at all (proves constraint 2 structurally).
- merchant_sale model with `sellable`/`repairable` items exposes both buttons; pressing them emits `sell_requested`/`repair_requested` with the right id (connect test lambdas).
- place_container model exposes "Place at Home" → `place_container_requested`.
- home_container model with one carried + one stored variant of the same id exposes "Move to Storage" / "Move to Inventory" respectively, and selecting each variant keeps the (id, source) pair distinct.
- `update_model` with the same selection keeps it; with the selection absent, first item auto-selects.
- After resizing the parent to a small viewport (e.g. 640×360), `layout_rects().popup_rect` stays inside `screen_rect`.

The existing end-to-end assertions at 2825–3030 remain the integration parity check — run unmodified.

## Verification

Per slice, at the end, run once:

```
powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1
powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui
```

Note: `tools/foundation_performance_probe` slot-autoplay failures are pre-existing baseline, not your regression.

Report per slice: functions moved, functions deleted from Main, Main line-count delta, and confirmation that the pre-existing snapshot assertions passed without edits.
