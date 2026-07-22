extends SceneTree

const CatalogScript := preload("res://scripts/ui/inventory_container_catalog.gd")
const SurfaceScript := preload("res://scripts/ui/inventory_container_surface.gd")
const RunScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
const MetaScreenScript := preload("res://scripts/ui/meta_item_interaction_screen.gd")
const MetaViewModelScript := preload("res://scripts/ui/meta_item_interaction_view_model.gd")
const MetaServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const TEST_STORE_PATH := "user://inventory_spatial_ui_check.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_audit_icon_models()
	_audit_collection_icon_coverage()
	_audit_container_art_style()
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
	surface.set_small_screen_mode(false)
	surface.update_model({
		"selected_key": "run:carried:a",
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
	surface.queue_free()

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
	run_screen.queue_free()

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
	meta_screen.set_small_screen_mode(true)
	meta_screen.set_reduced_motion(true)
	meta_screen.open(sale_model)
	await process_frame
	var meta_snapshot := meta_screen.layout_snapshot()
	_check(int(meta_snapshot.get("item_count", 0)) == 27, "Meta screen did not expose every sale option.")
	_check(bool(meta_snapshot.get("small_screen_mode", false)) and bool(meta_snapshot.get("reduced_motion", false)), "Meta screen accessibility modes were not retained.")
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


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


func _remove_test_store() -> void:
	var path := ProjectSettings.globalize_path(TEST_STORE_PATH)
	if FileAccess.file_exists(TEST_STORE_PATH):
		DirAccess.remove_absolute(path)


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
