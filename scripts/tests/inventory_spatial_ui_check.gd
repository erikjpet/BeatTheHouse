extends SceneTree

const CatalogScript := preload("res://scripts/ui/inventory_container_catalog.gd")
const SurfaceScript := preload("res://scripts/ui/inventory_container_surface.gd")
const RunScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
const MetaScreenScript := preload("res://scripts/ui/meta_item_interaction_screen.gd")
const MetaViewModelScript := preload("res://scripts/ui/meta_item_interaction_view_model.gd")
const MetaServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")

const TEST_STORE_PATH := "user://inventory_spatial_ui_check.json"

var failures: Array[String] = []
var confirmed_keys: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_audit_icon_models()
	_audit_collection_icon_coverage()
	_audit_container_art_style()
	_audit_item_voice()
	var catalog := CatalogScript.load_catalog(true)
	for error in CatalogScript.validate_catalog(catalog):
		failures.append(str(error))
	var expected := {"bag": 3, "backpack": 5, "suitcase": 7, "trunk": 10}
	for container_type in expected.keys():
		var rects := CatalogScript.slot_rects(str(container_type), int(expected[container_type]), catalog)
		_check(rects.size() == int(expected[container_type]), "%s slot count mismatch." % container_type)
		_check(_rects_are_valid_and_separate(rects), "%s slots are invalid or overlap." % container_type)
		_check(rects == CatalogScript.slot_rects(str(container_type), int(expected[container_type]), catalog), "%s slots are not deterministic." % container_type)

	var surface: InventoryContainerSurface = SurfaceScript.new()
	surface.size = Vector2(420, 420)
	root.add_child(surface)
	surface.configure(Callable(), catalog)
	surface.update_model(_surface_model(["a", "b", "c"], "b"))
	surface.slot_confirmed.connect(_record_confirmed)
	await process_frame
	var stable_before := str(surface.layout_snapshot().get("stable_bounds_signature", ""))
	var first_surface_snapshot := surface.layout_snapshot()
	_check(str(first_surface_snapshot.get("item_presentation", "")) == "transparent_cutout", "Inventory items are not rendered as unframed cutouts.")
	_check(str(first_surface_snapshot.get("selection_cue", "")) == "underline_and_marker", "Inventory focus fell back to a surrounding highlight box.")
	for slot_value in _array(first_surface_snapshot.get("slots", [])):
		var slot: Dictionary = slot_value
		var hit_rect: Rect2 = slot.get("rect", Rect2())
		var icon_rect: Rect2 = slot.get("icon_rect", Rect2())
		_check(hit_rect.encloses(icon_rect), "An item model escaped its accessible slot target.")
	var pool_before := int(surface.layout_snapshot().get("pool_count", 0))
	var texture_bindings_before := int(surface.layout_snapshot().get("texture_binding_count", 0))
	var unique_textures_before := int(surface.layout_snapshot().get("unique_texture_count", 0))
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	surface.call("_on_slot_gui_input", double_click, 0)
	_check(surface.selected_key() == "run:carried:a" and confirmed_keys.is_empty(), "First confirm on an unselected object did not commit selection without advancing.")
	surface.call("_on_slot_gui_input", double_click, 0)
	_check(confirmed_keys == ["run:carried:a"], "Second confirm on the committed object did not advance exactly once.")
	surface.call("_on_slot_hovered", 1)
	surface.call("_on_slot_focused", 2)
	var interaction_snapshot := surface.layout_snapshot()
	_check(str(interaction_snapshot.get("selected_key", "")) == "run:carried:a", "Hover or focus changed committed selection.")
	_check(str(interaction_snapshot.get("hovered_key", "")) == "run:carried:b", "Hover state was not exposed distinctly.")
	_check(str(interaction_snapshot.get("focused_key", "")) == "run:carried:c", "Focus state was not exposed distinctly.")
	surface.call("_focus_neighbor", 0, Vector2.RIGHT)
	_check(str(surface.layout_snapshot().get("focused_key", "")) == "run:carried:b", "Directional navigation did not choose the nearest object to the right.")
	surface.call("_focus_neighbor", 0, Vector2.DOWN)
	_check(str(surface.layout_snapshot().get("focused_key", "")) == "run:carried:c", "Directional navigation did not choose the nearest object below.")
	surface.focus_selection("run:carried:c", false)
	await process_frame
	_check(stable_before == str(surface.layout_snapshot().get("stable_bounds_signature", "")), "Selection moved the container bounds.")
	surface.update_model(_surface_model(["a", "b"], "a"))
	await process_frame
	_check(surface.selected_key() == "run:carried:a", "Removal did not reconcile to the geometrically nearest occupied slot (got %s)." % surface.selected_key())
	var repeated_update_started_usec := Time.get_ticks_usec()
	for index in range(30):
		surface.update_model(_surface_model(["a", "b"], surface.selected_key()))
	var repeated_update_usec := Time.get_ticks_usec() - repeated_update_started_usec
	var pool_after := int(surface.layout_snapshot().get("pool_count", 0))
	_check(pool_after == pool_before, "Repeated updates grew the slot-control pool.")
	_check(int(surface.layout_snapshot().get("texture_binding_count", 0)) == texture_bindings_before, "Repeated updates grew rendered texture bindings.")
	_check(int(surface.layout_snapshot().get("unique_texture_count", 0)) == unique_textures_before, "Repeated updates grew unique rendered textures.")
	surface.set_reduced_motion(true)
	_check(bool(surface.layout_snapshot().get("reduced_motion", false)), "Reduced-motion state did not reach the surface.")
	surface.set_small_screen_mode(true)
	var trunk_ids: Array = []
	for index in range(10):
		trunk_ids.append("trunk_%d" % index)
	var trunk_slots: Array = []
	for id_value in trunk_ids:
		trunk_slots.append({"slot_index": trunk_slots.size(), "occupied": true, "selection_key": "run:carried:%s" % id_value, "item": {"id": id_value, "display_name": id_value}})
	surface.update_model({"selected_key": "run:carried:trunk_0", "focus_explicit": true, "containers": [{"key": "trunk", "container_type": "trunk", "display_name": "Trunk", "capacity": 10, "slots": trunk_slots}]})
	await process_frame
	var small_snapshot := surface.layout_snapshot()
	_check(int(small_snapshot.get("visible_page_count", 0)) == 2 and _array(small_snapshot.get("slots", [])).size() == 5, "Small-screen trunk did not use explicit pages.")
	for slot_value in _array(small_snapshot.get("slots", [])):
		var target_rect: Rect2 = (slot_value as Dictionary).get("rect", Rect2())
		_check(target_rect.size.x >= 48.0 and target_rect.size.y >= 48.0, "Small-screen slot target fell below policy minimum.")
	surface.focus_selection("run:carried:trunk_8", false)
	await process_frame
	var second_trunk_page := surface.layout_snapshot()
	_check(int(second_trunk_page.get("active_page_index", -1)) == 1, "Programmatic focus did not reveal an object on the second small-screen page.")
	_check(str(second_trunk_page.get("selected_key", "")) == "run:carried:trunk_8", "Second-page focus lost exact object identity.")
	surface.set_small_screen_mode(false)
	surface.update_model({
		"selected_key": "run:carried:a",
		"multi_selected_keys": ["run:carried:a", "run:container:bag_a:b:0"],
		"containers": [
			{"key": "run_carried", "container_type": "loose_carry", "display_name": "Carried Items", "capacity": 0, "slots": [{"slot_index": 0, "occupied": true, "selection_key": "run:carried:a", "item": {"id": "a", "display_name": "A"}}]},
			{"key": "run_home:bag_a", "container_type": "bag", "display_name": "Desk Bag", "capacity": 3, "slots": [{"slot_index": 0, "occupied": true, "selection_key": "run:container:bag_a:b:0", "item": {"id": "b", "display_name": "B", "storage_source": "container", "container_id": "bag_a"}}]},
			{"key": "run_home:bag_b", "container_type": "backpack", "display_name": "Closet Pack", "capacity": 5, "slots": [{"slot_index": 0, "occupied": true, "selection_key": "run:container:bag_b:c:0", "item": {"id": "c", "display_name": "C", "storage_source": "container", "container_id": "bag_b"}}]},
		],
	})
	await process_frame
	var multi_snapshot := surface.layout_snapshot()
	_check(int(multi_snapshot.get("visible_container_count", 0)) == 3, "Home storage surface did not keep all containers visible together.")
	_check(_array(multi_snapshot.get("container_rects", [])).size() == 3, "Home storage surface did not report every visible container rect.")
	_check(_array(multi_snapshot.get("slots", [])).size() >= 9, "Home storage surface collapsed multi-container slots into one active container.")
	_check(_array(multi_snapshot.get("multi_selected_keys", [])).size() == 2, "Snapshot omitted multi-selection state.")
	surface.set_small_screen_mode(true)
	await process_frame
	var compact_multi_snapshot := surface.layout_snapshot()
	_check(int(compact_multi_snapshot.get("visible_container_count", 0)) == 1, "Small-screen multi-container layout did not switch to one explicit active container.")
	_check(str(compact_multi_snapshot.get("active_container_key", "")) == "run_carried", "Small-screen container switcher did not retain the active container.")
	for slot_value in _array(compact_multi_snapshot.get("slots", [])):
		var target_rect: Rect2 = (slot_value as Dictionary).get("rect", Rect2())
		if bool((slot_value as Dictionary).get("occupied", false)):
			_check(target_rect.size.x >= 48.0 and target_rect.size.y >= 48.0, "Small-screen multi-container target fell below policy minimum.")
	surface.call("_change_container", 1)
	await process_frame
	_check(str(surface.layout_snapshot().get("active_container_key", "")) == "run_home:bag_a", "Explicit container switching skipped the next home container.")
	surface.call("_change_container", 1)
	await process_frame
	_check(str(surface.layout_snapshot().get("active_container_key", "")) == "run_home:bag_b", "Explicit container switching did not reach every home container.")
	surface.set_small_screen_mode(false)
	surface.update_model({
		"selected_key": "",
		"focus_explicit": true,
		"containers": [{
			"key": "preference",
			"container_type": "bag",
			"display_name": "Bag",
			"capacity": 3,
			"slots": [
				{"slot_index": 0, "occupied": true, "actionable": false, "selection_key": "run:carried:inspect_only", "item": {"id": "inspect_only"}},
				{"slot_index": 1, "occupied": true, "actionable": true, "selection_key": "run:carried:actionable", "item": {"id": "actionable"}},
			],
		}],
	})
	_check(surface.selected_key() == "run:carried:actionable", "Initial focus did not prefer the first actionable object over an inspect-only object.")
	VisualStyle.set_high_contrast_enabled(true)
	_check(bool(surface.layout_snapshot().get("high_contrast", false)), "High-contrast state did not reach the spatial surface.")
	VisualStyle.set_high_contrast_enabled(false)
	surface.queue_free()

	var card_library: ContentLibrary = ContentLibraryScript.new()
	card_library.load(false)
	var card_run: RunState = RunStateScript.new()
	card_run.start_new("INVENTORY-CARD-CONTRACT")
	card_run.inventory = ["creased_luck_card", "creased_luck_card", "roadside_map"]
	var card_service: RunActionService = RunActionServiceScript.new()
	card_service.setup(card_library, card_run)
	var card_model := RunViewModelScript.build(card_run, card_service, "inspect", "", {})
	_check(str((card_model.get("layout", {}) as Dictionary).get("presentation", "")) == "grouped_card_grid", "Run inventory view model did not request the shared card grid.")
	var card_surface: InventoryContainerSurface = SurfaceScript.new()
	card_surface.size = Vector2(640, 420)
	root.add_child(card_surface)
	card_surface.configure(Callable(), catalog)
	card_surface.update_model(card_model)
	await process_frame
	var run_card_snapshot := card_surface.layout_snapshot()
	_check(str(run_card_snapshot.get("item_presentation", "")) == "rarity_card_grid", "Run inventory did not use the shared item-card renderer.")
	var saw_stack_two := false
	for slot_value in _array(run_card_snapshot.get("slots", [])):
		var slot: Dictionary = slot_value
		if str(slot.get("stack_text", "")) == "+2":
			saw_stack_two = true
		_check(not bool(slot.get("contains_risk_badge", true)), "Item card exposed the forbidden risk_tier badge.")
		for rect_key in ["name_rect", "description_rect", "badge_rect", "count_rect"]:
			var child_rect: Rect2 = slot.get(rect_key, Rect2())
			_check(child_rect.has_area() and (slot.get("rect", Rect2()) as Rect2).grow(1.0).encloses(child_rect), "Run item card %s escaped its card bounds." % rect_key)
	_check(saw_stack_two, "Duplicate run items did not collapse into a visible +2 stack.")
	card_surface.queue_free()

	var fallback_surface: InventoryContainerSurface = SurfaceScript.new()
	fallback_surface.size = Vector2(420, 420)
	root.add_child(fallback_surface)
	fallback_surface.configure(Callable(), {"presentations": {}})
	fallback_surface.update_model(_surface_model(["fallback_a", "fallback_b"], "fallback_a"))
	await process_frame
	var fallback_snapshot := fallback_surface.layout_snapshot()
	_check(_array(fallback_snapshot.get("slots", [])).size() == 3, "Missing presentation fallback lost authoritative bag spaces.")
	_check(fallback_surface.item_for_selection("run:carried:fallback_b").get("id", "") == "fallback_b", "Missing presentation fallback dropped an owned item.")
	fallback_surface.queue_free()

	var focus_origin := Button.new()
	focus_origin.text = "Inventory origin"
	focus_origin.focus_mode = Control.FOCUS_ALL
	root.add_child(focus_origin)
	focus_origin.grab_focus()
	await process_frame
	var run_screen: RunInventoryScreen = RunScreenScript.new()
	root.add_child(run_screen)
	run_screen.open({
		"mode": "inspect",
		"title": "Inventory",
		"summary": "Spatial",
		"items": [
			{"id": "same", "display_name": "Same", "storage_source": "carried"},
			{"id": "same", "display_name": "Same", "storage_source": "container"},
		],
		"selected": {"id": "same", "source": "carried"},
	})
	await process_frame
	run_screen.select_item("same", "container", false)
	_check(str(run_screen.selected_item_key().get("source", "")) == "container", "Run identity collapsed same-ID items from different sources.")
	run_screen.close()
	await process_frame
	_check(root.gui_get_focus_owner() == focus_origin, "Closing run inventory did not restore focus to its originating control.")
	run_screen.size = Vector2(1280, 720)
	run_screen.open({
		"mode": "home_container",
		"title": "Home Storage",
		"summary": "Spatial",
		"items": [
			{"id": "a", "display_name": "A", "storage_source": "carried", "selection_key": "run:carried:a", "storage_destinations": [{"container_id": "bag_a", "display_name": "Desk Bag", "full": false, "read_only": false}]},
			{"id": "b", "display_name": "B", "storage_source": "container", "container_id": "bag_a", "selection_key": "run:container:bag_a:b:0", "storage_destinations": [{"container_id": "bag_b", "display_name": "Closet Pack", "full": false, "read_only": false}]},
		],
		"selected": {"id": "b", "source": "container", "selection_key": "run:container:bag_a:b:0"},
		"selected_key": "run:container:bag_a:b:0",
		"containers": [
			{"key": "run_carried", "container_type": "loose_carry", "display_name": "Carried Items", "capacity": 0, "slots": [{"slot_index": 0, "occupied": true, "selection_key": "run:carried:a", "item": {"id": "a", "display_name": "A", "storage_source": "carried", "selection_key": "run:carried:a"}}]},
			{"key": "run_home:bag_a", "container_type": "bag", "display_name": "Desk Bag", "capacity": 3, "slots": [{"slot_index": 0, "occupied": true, "selection_key": "run:container:bag_a:b:0", "item": {"id": "b", "display_name": "B", "storage_source": "container", "container_id": "bag_a", "selection_key": "run:container:bag_a:b:0", "storage_destinations": [{"container_id": "bag_b", "display_name": "Closet Pack", "full": false, "read_only": false}]}}]},
			{"key": "run_home:bag_b", "container_type": "backpack", "display_name": "Closet Pack", "capacity": 5, "slots": []},
		],
	})
	await process_frame
	var home_layout := run_screen.layout_rects()
	_check((home_layout.get("detail_rect", Rect2()) as Rect2).has_area(), "Home storage detail panel was not visible with the containers.")
	_check(int((home_layout.get("spatial", {}) as Dictionary).get("visible_container_count", 0)) == 3, "Home storage popup did not present all containers at once.")
	_check(_control_tree_has_text(run_screen, "MOVE ITEM"), "Home storage action panel did not label the transfer controls clearly.")
	_check(_control_tree_has_text(run_screen, "Take into carried inventory"), "Stored item panel did not expose the take-to-inventory action.")
	_check(_control_tree_has_text(run_screen, "Move to Closet Pack"), "Stored item panel did not expose a direct container-to-container action.")
	var screen_pool_count := int((home_layout.get("spatial", {}) as Dictionary).get("pool_count", 0))
	for repeat_index in range(10):
		run_screen.close()
		run_screen.open({
			"mode": "inspect",
			"title": "Inventory",
			"summary": "Leak check",
			"items": [{"id": "repeat", "display_name": "Repeat", "storage_source": "carried", "selection_key": "run:carried:repeat"}],
			"selected": {"id": "repeat", "source": "carried"},
			"selected_key": "run:carried:repeat",
			"containers": [{"key": "repeat", "container_type": "bag", "display_name": "Bag", "capacity": 3, "slots": [{"slot_index": 0, "occupied": true, "actionable": true, "selection_key": "run:carried:repeat", "item": {"id": "repeat", "display_name": "Repeat", "storage_source": "carried", "selection_key": "run:carried:repeat"}}]}],
		})
	var repeated_screen_pool := int((run_screen.layout_rects().get("spatial", {}) as Dictionary).get("pool_count", 0))
	_check(repeated_screen_pool <= screen_pool_count, "Repeated screen open/close cycles grew the shared slot-control pool.")
	run_screen.close()
	run_screen.open({
		"mode": "place_container",
		"title": "Place Storage",
		"summary": "Choose storage.",
		"selected": {"id": "trunk", "source": "carried"},
		"selected_key": "run:carried:trunk",
		"items": [{"id": "trunk", "display_name": "Trunk", "item_class": "container", "domain": "home", "capacity": 10, "storage_source": "carried", "selection_key": "run:carried:trunk"}],
		"containers": [{
			"key": "run_carried",
			"container_type": "loose_carry",
			"display_name": "Containers to Place",
			"capacity": 0,
			"slots": [{"slot_index": 0, "occupied": true, "actionable": true, "selection_key": "run:carried:trunk", "item": {"id": "trunk", "display_name": "Trunk", "item_class": "container", "domain": "home", "capacity": 10, "storage_source": "carried", "selection_key": "run:carried:trunk"}}],
		}],
	})
	await process_frame
	_check(_control_tree_has_text(run_screen, "Open Trunk preview"), "Placement flow did not show the selected container's open-interior preview.")
	_check(_control_tree_has_text(run_screen, "10 selectable spaces"), "Placement preview did not use the selected container's authoritative capacity.")
	run_screen.close()
	run_screen.set_small_screen_mode(true)
	run_screen.size = Vector2(640, 360)
	var compact_items: Array = []
	var compact_slots: Array = []
	for index in range(8):
		var item_id := "compact_%d" % index
		var item := {
			"id": item_id,
			"display_name": "Compact Item %d" % index,
			"storage_source": "carried",
			"selection_key": "run:carried:%s" % item_id,
			"description": "A deliberately verbose inventory description that should scroll inside the fitted popup instead of forcing the menu below the viewport.",
			"active_item": true,
		}
		compact_items.append(item)
		compact_slots.append({"slot_index": index, "occupied": true, "actionable": true, "selection_key": item.get("selection_key", ""), "item": item})
	run_screen.open({
		"mode": "inspect",
		"title": "Compact Inventory",
		"summary": "Small viewport fit check.",
		"selected": {"id": "compact_0", "source": "carried"},
		"selected_key": "run:carried:compact_0",
		"items": compact_items,
		"containers": [{"key": "run_carried", "container_type": "loose_carry", "display_name": "Carried Items", "capacity": 0, "slots": compact_slots}],
	})
	await process_frame
	var compact_layout := run_screen.layout_rects()
	_check(_screen_encloses_rect(compact_layout, "popup_rect"), "Compact run inventory popup escaped the screen.")
	_check(_screen_encloses_rect(compact_layout, "grid_rect"), "Compact run inventory item area escaped the screen.")
	_check(_screen_encloses_rect(compact_layout, "detail_rect"), "Compact run inventory detail/actions area escaped the screen.")
	_check(_control_tree_has_text(run_screen, "Set Active"), "Compact fitted detail panel lost the selected item's action button.")
	run_screen.close()
	run_screen.set_small_screen_mode(false)
	run_screen.size = Vector2(1280, 720)

	var ticket_run: RunState = RunStateScript.new()
	var ticket_library: ContentLibrary = ContentLibraryScript.new()
	ticket_library.load(false)
	var ticket_service: RunActionService = RunActionServiceScript.new()
	ticket_service.setup(ticket_library, ticket_run)
	var ticket_origin := {"id": "corner_store_test", "display_name": "Corner Store", "world_node_id": "corner_store", "archetype_id": "corner_store"}
	ticket_run.remember_portable_ticket_state("scratch_tickets", ticket_origin, {
		"active_ticket": {"id": "active_ticket"},
		"pending_queue": [{"id": "queued_a"}, {"id": "queued_b"}],
		"winner_pile": [{"id": "winner_a", "payout": 25}],
		"loser_pile": [{"id": "loser_a", "payout": 0}],
	})
	var pile_detail := ticket_service.inventory_item_detail(RunStateScript.SCRATCH_TICKET_PILE_ITEM_ID)
	_check(bool(pile_detail.get("ticket_pile_item", false)), "Scratch ticket pile did not identify itself as an inert stateful pile item.")
	_check(int(pile_detail.get("ticket_count", 0)) == 5, "Scratch ticket pile detail did not count active, queued, winner, and loser tickets.")
	_check(int(pile_detail.get("ticket_unplayed_count", 0)) == 3, "Scratch ticket pile detail did not count queued scratch tickets as unplayed state.")
	_check(not bool(pile_detail.get("active_item", true)) and not bool(pile_detail.get("sellable", true)) and not bool(pile_detail.get("repairable", true)), "Scratch ticket pile still exposed normal item action affordances.")
	run_screen.open({
		"mode": "inspect",
		"title": "Inventory",
		"summary": "Ticket pile presentation.",
		"selected": {"id": RunStateScript.SCRATCH_TICKET_PILE_ITEM_ID, "source": "carried"},
		"selected_key": "run:carried:%s" % RunStateScript.SCRATCH_TICKET_PILE_ITEM_ID,
		"items": [pile_detail],
		"containers": [{"key": "run_carried", "container_type": "loose_carry", "display_name": "Carried Items", "capacity": 0, "slots": [{"slot_index": 0, "occupied": true, "actionable": true, "selection_key": "run:carried:%s" % RunStateScript.SCRATCH_TICKET_PILE_ITEM_ID, "item": pile_detail}]}],
	})
	await process_frame
	_check(_control_tree_has_text(run_screen, "Return to"), "Ticket pile detail did not show its purchase-location return guidance.")
	_check(_control_tree_has_text(run_screen, "Corner Store"), "Ticket pile detail did not name the origin where state will resume.")
	_check(not _control_tree_has_text(run_screen, "Set Active") and not _control_tree_has_text(run_screen, "Cannot sell."), "Ticket pile detail still rendered the legacy normal-item action menu.")
	run_screen.queue_free()
	focus_origin.queue_free()

	var transfer_run: RunState = RunStateScript.new()
	transfer_run.home_state = {"active": true, "home_node_id": "home_test"}
	transfer_run.current_environment = {
		"kind": "home",
		"world_node_id": "home_test",
		"home_containers": [
			{"id": "bag_a", "item_id": "bag", "display_name": "Desk Bag", "capacity": 3, "items": ["odds_notebook"]},
			{"id": "bag_b", "item_id": "backpack", "display_name": "Closet Pack", "capacity": 5, "items": []},
		],
	}
	var transfer_result := transfer_run.transfer_item_between_home_containers("bag_a", "bag_b", "odds_notebook")
	var transferred_containers := transfer_run.current_home_containers()
	_check(bool(transfer_result.get("ok", false)), "Run state rejected direct home container transfer: %s" % str(transfer_result.get("message", "")))
	_check(_array((transferred_containers[0] as Dictionary).get("items", [])).is_empty(), "Source container still held the transferred item.")
	_check(_array((transferred_containers[1] as Dictionary).get("items", [])).has("odds_notebook"), "Destination container did not receive the transferred item.")

	OS.set_environment(MetaServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_test_store()
	var service: Variant = MetaServiceScript.new()
	service.load()
	var resolver: Variant = ResolverScript.new()
	for index in range(14):
		service.grant_instance(resolver.roll_instance(1000, "spatial-owned-%d" % index))
	for index in range(13):
		service.grant_bag(9000, "spatial-bag-%d" % index)
	var before := JSON.stringify(service.snapshot())
	var inventory_model := MetaViewModelScript.build(service, MetaViewModelScript.MODE_CONTAINER)
	var bag_model := MetaViewModelScript.build(service, MetaViewModelScript.MODE_BAGS)
	var sale_model := MetaViewModelScript.build(service, MetaViewModelScript.MODE_SALE)
	_check(_array(inventory_model.get("items", [])).size() == 14, "Meta inventory dropped an owned instance above the former 10-row limit.")
	_check(_array(bag_model.get("items", [])).size() == 13, "Bag screen dropped an exact bag instance.")
	_check(_array(sale_model.get("items", [])).size() == 27, "Sale screen dropped an option above the former 12-row limit.")
	_check(_unique_selection_count(inventory_model) == 14, "Same-definition meta instances did not retain distinct exact keys.")
	_check(JSON.stringify(service.snapshot()) == before, "View-model construction mutated the meta store or RNG state.")

	var meta_screen: MetaItemInteractionScreen = MetaScreenScript.new()
	root.add_child(meta_screen)
	meta_screen.set_reduced_motion(true)
	meta_screen.set_small_screen_mode(false)
	meta_screen.open(sale_model)
	await process_frame
	var meta_snapshot_large := meta_screen.layout_snapshot()
	_check(int(meta_snapshot_large.get("item_count", 0)) == 27, "Meta screen did not expose every sale option.")
	_check(not bool(meta_snapshot_large.get("small_screen_mode", true)) and bool(meta_snapshot_large.get("reduced_motion", false)), "Meta screen large accessibility state was not retained.")
	_check(_meta_card_surface_clean(meta_snapshot_large, "large meta sale grid"), "Large meta sale grid had overlapping or clipped cards.")
	meta_screen.set_small_screen_mode(true)
	await process_frame
	var meta_snapshot_small := meta_screen.layout_snapshot()
	_check(bool(meta_snapshot_small.get("small_screen_mode", false)) and bool(meta_snapshot_small.get("reduced_motion", false)), "Meta screen small accessibility modes were not retained.")
	_check(_meta_card_surface_clean(meta_snapshot_small, "small meta sale grid"), "Small meta sale grid had overlapping or clipped cards.")
	meta_screen.queue_free()

	_remove_test_store()
	OS.set_environment(MetaServiceScript.STORE_PATH_ENV, "")
	await process_frame
	if failures.is_empty():
		print("INVENTORY_SPATIAL_UI_METRICS %s" % JSON.stringify({"repeated_updates": 30, "repeated_update_usec": repeated_update_usec, "pool_before": pool_before, "pool_after": pool_after, "large_meta_items": 27}))
		print("INVENTORY_SPATIAL_UI_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _surface_model(ids: Array, selected_id: String) -> Dictionary:
	var slots: Array = []
	for id_value in ids:
		var id := str(id_value)
		slots.append({"slot_index": slots.size(), "occupied": true, "selection_key": "run:carried:%s" % id, "item": {"id": id, "display_name": id.to_upper()}})
	return {
		"selected_key": "run:carried:%s" % selected_id,
		"containers": [{"key": "test", "container_type": "bag", "display_name": "Bag", "capacity": 3, "slots": slots}],
	}


func _audit_icon_models() -> void:
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/art_manifest.json"))
	var manifest: Dictionary = manifest_value if typeof(manifest_value) == TYPE_DICTIONARY else {}
	var ui_surfaces: Dictionary = manifest.get("ui_surfaces", {}) if typeof(manifest.get("ui_surfaces", {})) == TYPE_DICTIONARY else {}
	var ui_surface_paths := {}
	for surface_value in ui_surfaces.values():
		if typeof(surface_value) == TYPE_DICTIONARY:
			var surface_path := str((surface_value as Dictionary).get("path", "")).strip_edges()
			if not surface_path.is_empty():
				ui_surface_paths[surface_path] = true
	var directories := [
		"res://assets/art/items",
		"res://assets/art/events",
		"res://assets/art/games",
		"res://assets/art/map_icons",
		"res://assets/art/run_outcomes",
		"res://assets/art/ui",
	]
	var checked := 0
	for directory_path in directories:
		var directory := DirAccess.open(directory_path)
		_check(directory != null, "Missing icon-model directory: %s" % directory_path)
		if directory == null:
			continue
		for filename in directory.get_files():
			if not filename.ends_with(".png"):
				continue
			var path := "%s/%s" % [directory_path, filename]
			if ui_surface_paths.has(path):
				continue
			var texture := load(path) as Texture2D
			var image := texture.get_image() if texture != null else Image.new()
			_check(texture != null and not image.is_empty(), "Icon model could not be loaded: %s" % path)
			if texture == null or image.is_empty():
				continue
			checked += 1
			_check(image.get_width() == 32 and image.get_height() == 32, "Icon model left the 32px art contract: %s" % path)
			var transparent_corners := 0
			for corner in [Vector2i(0, 0), Vector2i(31, 0), Vector2i(0, 31), Vector2i(31, 31)]:
				if image.get_pixelv(corner).a <= 0.01:
					transparent_corners += 1
			_check(transparent_corners >= 3, "Icon model still has a baked background/frame: %s" % path)
			var used_rect := image.get_used_rect()
			_check(used_rect.has_area(), "Icon model has no visible object: %s" % path)
			_check(maxi(used_rect.size.x, used_rect.size.y) >= 28, "Icon model leaves excessive dead margin instead of filling its space: %s" % path)
	_check(checked >= 130, "Icon-model audit did not cover the complete item/event/game/environment/outcome/UI set.")
	_check(ui_surfaces.size() >= 2, "Art manifest did not classify the complete scalable UI-surface set.")
	for surface_id_value in ui_surfaces.keys():
		var surface_id := str(surface_id_value)
		var surface: Dictionary = ui_surfaces.get(surface_id_value, {}) if typeof(ui_surfaces.get(surface_id_value, {})) == TYPE_DICTIONARY else {}
		var path := str(surface.get("path", "")).strip_edges()
		var expected_size: Array = surface.get("size", []) if typeof(surface.get("size", [])) == TYPE_ARRAY else []
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture != null else Image.new()
		_check(path.begins_with("res://assets/art/ui/") and texture != null and not image.is_empty(), "UI surface could not be loaded: %s (%s)" % [surface_id, path])
		if texture == null or image.is_empty():
			continue
		_check(expected_size.size() == 2 and image.get_width() == int(expected_size[0]) and image.get_height() == int(expected_size[1]), "UI surface left its authored canvas contract: %s" % path)
		_check(image.get_used_rect().has_area(), "UI surface has no visible art: %s" % path)


func _audit_collection_icon_coverage() -> void:
	var resolver: Variant = ResolverScript.new()
	var definitions := _array(resolver.item_definitions()) + _array(resolver.special_item_definitions())
	for definition_value in definitions:
		var definition: Dictionary = definition_value
		var icon_key := str(definition.get("icon_key", "")).strip_edges()
		if icon_key.is_empty():
			continue
		var path := "res://assets/art/items/%s.png" % icon_key
		_check(ResourceLoader.exists(path), "Collection item has no placeable icon model: %s" % icon_key)


func _audit_container_art_style() -> void:
	var filenames := [
		"bag_open.png",
		"backpack_open.png",
		"suitcase_open.png",
		"trunk_open.png",
		"loose_carry.png",
		"home_storage.png",
	]
	for filename in filenames:
		var path := "res://assets/art/ui/inventory_containers/%s" % filename
		var texture := load(path) as Texture2D
		_check(texture != null, "Container art could not be loaded: %s" % path)
		if texture == null:
			continue
		var image := texture.get_image()
		_check(image.get_width() == 512 and image.get_height() == 512, "Container art left the 512px contract: %s" % path)
		var metrics := _container_art_metrics(image)
		_check(int(metrics.get("unique_colors", 0)) >= 4096, "Container art lost the approved material/detail density: %s" % path)
		_check(int(metrics.get("dark_pixels", 0)) >= 2048, "Container art lost the ink/navy foundation: %s" % path)
		_check(int(metrics.get("cyan_pixels", 0)) >= 8, "Container art lost the shared cyan rim-light accent: %s" % path)
		_check(int(metrics.get("warm_pixels", 0)) >= 8, "Container art lost the shared amber/brass accent: %s" % path)


func _audit_item_voice() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	var descriptions: Dictionary = {}
	var items := _array(parsed)
	_check(items.size() >= 60, "Item voice audit did not cover the full run-item roster.")
	for item_value in items:
		var item: Dictionary = item_value
		var description := str(item.get("description", "")).strip_edges()
		_check(not description.is_empty(), "Item %s has no voiced description." % str(item.get("id", "unknown")))
		_check(description.find("\n") < 0 and description.find("\r") < 0, "Item %s description is not one line." % str(item.get("id", "unknown")))
		_check(not _contains_digit(description), "Item %s description restates mechanics with a number." % str(item.get("id", "unknown")))
		_check(not descriptions.has(description), "Item description is duplicated: %s" % description)
		descriptions[description] = true
	var collection_flavors: Array[String] = []
	_collect_named_strings(JSON.parse_string(FileAccess.get_file_as_string("res://data/collections/collections.json")), "flavor", collection_flavors)
	_check(collection_flavors.size() >= 40, "Item voice audit did not cover the collection-item roster.")
	for flavor in collection_flavors:
		_check(not flavor.strip_edges().is_empty() and not _contains_digit(flavor), "Collection flavor is blank or restates mechanics: %s" % flavor)


func _collect_named_strings(value: Variant, key: String, result: Array[String]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		if dictionary.has(key):
			result.append(str(dictionary.get(key, "")))
		for child in dictionary.values():
			_collect_named_strings(child, key, result)
	elif typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			_collect_named_strings(child, key, result)


func _contains_digit(value: String) -> bool:
	for character in value:
		if character >= "0" and character <= "9":
			return true
	return false


func _container_art_metrics(image: Image) -> Dictionary:
	var colors: Dictionary = {}
	var dark_pixels := 0
	var cyan_pixels := 0
	var warm_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			colors[color.to_rgba32()] = true
			if color.v < 0.16:
				dark_pixels += 1
			if color.a > 0.0 and color.g > color.r * 1.25 and color.b > color.r * 1.35 and color.b > 0.28:
				cyan_pixels += 1
			if color.a > 0.0 and color.r > 0.34 and color.r > color.b * 1.45 and color.g > color.b * 1.15:
				warm_pixels += 1
	return {
		"unique_colors": colors.size(),
		"dark_pixels": dark_pixels,
		"cyan_pixels": cyan_pixels,
		"warm_pixels": warm_pixels,
	}


func _rects_are_valid_and_separate(rects: Array) -> bool:
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 1.0 or rect.end.y > 1.0:
			return false
		for other_index in range(index):
			var overlap := rect.intersection(rects[other_index] as Rect2)
			if overlap.size.x > 0.015 and overlap.size.y > 0.015:
				return false
	return true


func _unique_selection_count(model: Dictionary) -> int:
	var keys: Dictionary = {}
	for item_value in _array(model.get("items", [])):
		keys[str((item_value as Dictionary).get("selection_key", ""))] = true
	return keys.size()


func _meta_card_surface_clean(snapshot: Dictionary, label: String) -> bool:
	var surface: Dictionary = snapshot.get("surface", {}) if typeof(snapshot.get("surface", {})) == TYPE_DICTIONARY else {}
	if str(surface.get("item_presentation", "")) != "rarity_card_grid":
		failures.append("%s did not use the rarity card-grid presentation." % label)
		return false
	var slots := _array(surface.get("slots", []))
	if slots.is_empty():
		failures.append("%s did not render any visible card slots." % label)
		return false
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		var rect: Rect2 = slot.get("rect", Rect2())
		if rect.size.x < 96.0 or rect.size.y < 82.0:
			failures.append("%s rendered an unreadably small card: %s." % [label, str(rect)])
			return false
		for key in ["icon_rect", "name_rect", "description_rect", "badge_rect", "count_rect", "group_rect"]:
			var child_rect: Rect2 = slot.get(key, Rect2())
			if child_rect.size.x <= 0.0 or child_rect.size.y <= 0.0 or not rect.grow(1.0).encloses(child_rect):
				failures.append("%s %s escaped its card: card=%s child=%s." % [label, key, str(rect), str(child_rect)])
				return false
		for other_index in range(index):
			var other: Dictionary = slots[other_index]
			var other_rect: Rect2 = other.get("rect", Rect2())
			var overlap := rect.intersection(other_rect)
			if overlap.size.x > 1.0 and overlap.size.y > 1.0:
				failures.append("%s cards overlapped: %s vs %s." % [label, str(rect), str(other_rect)])
				return false
	return true


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _screen_encloses_rect(snapshot: Dictionary, key: String) -> bool:
	var screen_rect: Rect2 = snapshot.get("screen_rect", Rect2())
	var target_rect: Rect2 = snapshot.get(key, Rect2())
	return screen_rect.size.x > 0.0 and screen_rect.size.y > 0.0 and target_rect.size.x > 0.0 and target_rect.size.y > 0.0 and screen_rect.grow(1.0).encloses(target_rect)


func _remove_test_store() -> void:
	var path := ProjectSettings.globalize_path(TEST_STORE_PATH)
	if FileAccess.file_exists(TEST_STORE_PATH):
		DirAccess.remove_absolute(path)


func _record_confirmed(selection_key: String) -> void:
	confirmed_keys.append(selection_key)


func _control_tree_has_text(node: Node, needle: String) -> bool:
	var label := node as Label
	if label != null and label.text.find(needle) >= 0:
		return true
	var button := node as Button
	if button != null and button.text.find(needle) >= 0:
		return true
	for child in node.get_children():
		if _control_tree_has_text(child, needle):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
