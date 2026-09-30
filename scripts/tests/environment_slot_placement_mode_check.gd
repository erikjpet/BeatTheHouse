extends SceneTree

const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")

var failures: Array[String] = []
var locked_request: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var temp_root := ProjectSettings.globalize_path("res://.tmp/environment_slot_placement_mode_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	var user_path := temp_root.path_join("user.json")
	var project_path := temp_root.path_join("project.json")
	var settings_path := temp_root.path_join("settings.json")
	for path in [user_path, project_path, settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, user_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, project_path)
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, settings_path)
	DeveloperPlacementStoreScript.reload()

	await _check_settings_contract()
	_check_slot_geometry_and_promotion(user_path, project_path)
	await _check_canvas_contract()

	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, "")
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, "")
	DeveloperPlacementStoreScript.reload()
	for path in [user_path, "%s.bak" % user_path, project_path, "%s.bak" % project_path, settings_path, "%s.bak" % settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(temp_root)

	if failures.is_empty():
		print("ENVIRONMENT_SLOT_PLACEMENT_MODE_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_settings_contract() -> void:
	var settings := UserSettingsScript.new()
	settings.developer_placement_mode = true
	settings.developer_slot_placement_mode = true
	var restored := UserSettingsScript.new()
	restored.from_dict(settings.to_dict())
	_check(restored.developer_slot_placement_mode, "Slot placement preference must survive settings serialization.")
	_check(not restored.developer_placement_mode, "Loading slot placement must disable spawned-object placement.")
	restored.reset()
	_check(not restored.developer_slot_placement_mode, "Slot placement must default off.")

	var menu: SettingsMenu = SettingsMenuScript.new()
	root.add_child(menu)
	menu.setup(restored)
	menu.open()
	_check(menu.developer_slot_placement_mode != null, "Settings > Developer must expose Environment slot placement mode.")
	_check(menu.developer_slot_placement_mode.text.begins_with("[ ]"), "The slot-placement toggle must render an explicit unchecked indicator.")
	menu.developer_slot_placement_mode.toggled.emit(true)
	_check(menu.developer_slot_placement_mode.text.begins_with("[X]"), "The slot-placement toggle must render an explicit checked indicator.")
	menu.call("_on_developer_placement_mode", true)
	menu.call("_on_developer_slot_placement_mode", true)
	_check(
		bool(menu.draft.developer_slot_placement_mode) and not bool(menu.draft.developer_placement_mode),
		"The two developer placement modes must be mutually exclusive."
	)
	menu.call("_on_apply")
	_check(restored.developer_slot_placement_mode, "Applying Settings must enable slot placement mode.")
	menu.queue_free()
	await process_frame


func _check_slot_geometry_and_promotion(user_path: String, project_path: String) -> void:
	var environment := {"archetype_id": "corner_store"}
	var normal_before := EnvironmentPlacementScript.surface_map(environment)
	var fixed_before := _slot(normal_before, "fixed.item_shop_1")
	var event_before := _slot(normal_before, "event.floor_patron_1")
	var scenario_before := _slot(normal_before, "scenario.floor_patron_1")
	var exit_before := _slot(normal_before, "exit.safe_left")
	_check(not fixed_before.is_empty() and not event_before.is_empty() and not scenario_before.is_empty() and not exit_before.is_empty(), "Fixture must expose fixed, event, scenario, and exit slots.")
	if fixed_before.is_empty() or event_before.is_empty() or scenario_before.is_empty() or exit_before.is_empty():
		return

	var fixed_target := _slot_position(fixed_before) + Vector2(40.0, 20.0)
	var event_target := _slot_position(event_before) + Vector2(8.0, -12.0)
	var scenario_target := _slot_position(scenario_before) + Vector2(-24.0, -16.0)
	var exit_target := _slot_position(exit_before) + Vector2(18.0, 12.0)
	for edit in [
		["fixed.item_shop_1", fixed_target],
		["event.floor_patron_1", event_target],
		["scenario.floor_patron_1", scenario_target],
		["exit.safe_left", exit_target],
	]:
		var saved := DeveloperPlacementStoreScript.save_position(environment, "slot_positions", str(edit[0]), edit[1] as Vector2)
		_check(bool(saved.get("ok", false)), "Every slot kind must save through the durable placement store.")
	_check(FileAccess.file_exists(user_path), "A locked slot must create the machine-local placement file.")

	var normal_local := EnvironmentPlacementScript.surface_map(environment)
	var authoring_local := EnvironmentPlacementScript.authoring_surface_map(environment)
	_check(_slot_position(_slot(normal_local, "fixed.item_shop_1")).is_equal_approx(fixed_target), "A locked fixed-slot edit must remain active after placement mode is disabled.")
	_check(_slot_position(_slot(normal_local, "event.floor_patron_1")).is_equal_approx(event_target), "Normal rendering must consume the locked event-slot edit before project promotion.")
	_check(_slot_position(_slot(normal_local, "scenario.floor_patron_1")).is_equal_approx(scenario_target), "Normal rendering must consume the locked scenario-slot edit before project promotion.")
	_check(_slot_position(_slot(normal_local, "exit.safe_left")).is_equal_approx(exit_target), "Normal rendering must consume the locked exit-slot edit before project promotion.")
	_check(_slot_position(_slot(authoring_local, "fixed.item_shop_1")).is_equal_approx(fixed_target), "Authoring view must load the local fixed-slot edit.")
	_check(_slot_position(_slot(authoring_local, "event.floor_patron_1")).is_equal_approx(event_target), "Authoring view must load the local event-slot edit.")
	_check(_slot_position(_slot(authoring_local, "scenario.floor_patron_1")).is_equal_approx(scenario_target), "Authoring view must load the local scenario-slot edit.")
	_check(_slot_position(_slot(authoring_local, "exit.safe_left")).is_equal_approx(exit_target), "Authoring view must load the local exit-slot edit.")
	_check(_translated_geometry(fixed_before, _slot(authoring_local, "fixed.item_shop_1"), fixed_target - _slot_position(fixed_before)), "Moving a slot must rigidly translate pos, hit_rect, and label_anchor without resizing it.")

	DeveloperPlacementStoreScript.reload()
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1")).is_equal_approx(fixed_target), "Locked slot edits must survive a durable reload in normal rendering.")
	var other_environment := {"archetype_id": "bar"}
	_check(_slot(EnvironmentPlacementScript.authoring_surface_map(other_environment), "fixed.item_shop_1").is_empty(), "A slot edit must not leak into another environment.")

	var local_binding := EnvironmentSlotBinderScript.bind_base_layout(
		{
			"archetype_id": "corner_store",
			"item_offers": [{"id": "local_future_stock"}],
		},
		[{
			"object_id": "item:local_future_stock",
			"object_type": "item",
			"label": "Local Future Stock",
			"family": "fixed",
			"placement_class": "shop_item",
			"exact_slot_id": "fixed.item_shop_1",
			"active": true,
		}]
	)
	var local_future_binding: Dictionary = (local_binding.get("slot_bindings", {}) as Dictionary).get("item:local_future_stock", {})
	var local_future_rect: Dictionary = (local_binding.get("object_rects", {}) as Dictionary).get("item:local_future_stock", {})
	var local_target_rect := _slot_rect(_slot(normal_local, "fixed.item_shop_1"))
	_check(str(local_future_binding.get("slot_id", "")) == "fixed.item_shop_1", "A newly generated environment must bind future objects to a locally moved slot.")
	_check(
		is_equal_approx(float(local_future_rect.get("x", -1.0)), local_target_rect.position.x / 900.0)
			and is_equal_approx(float(local_future_rect.get("y", -1.0)), local_target_rect.position.y / 430.0),
		"A newly generated environment must keep the locally moved slot position after authoring mode exits."
	)
	var club_layer := {"archetype_id": "small_underground_casino", "current_layer_id": "club"}
	var casino_layer := {"archetype_id": "small_underground_casino", "current_layer_id": "casino"}
	var club_slot := _slot(EnvironmentPlacementScript.surface_map(club_layer), "fixed.door_right_lower")
	var club_target := _slot_position(club_slot) + Vector2(-10.0, -6.0)
	var layer_saved := DeveloperPlacementStoreScript.save_position(club_layer, "slot_positions", "fixed.door_right_lower", club_target)
	_check(bool(layer_saved.get("ok", false)), "A layered-environment slot edit must save.")
	_check(
		DeveloperPlacementStoreScript.user_slot_overrides(club_layer, "slot_positions").has("fixed.door_right_lower")
			and not DeveloperPlacementStoreScript.user_slot_overrides(casino_layer, "slot_positions").has("fixed.door_right_lower"),
		"Slot edits must be scoped to the exact environment layer."
	)

	var promoted := DeveloperPlacementStoreScript.promote_user_overrides()
	_check(bool(promoted.get("ok", false)) and FileAccess.file_exists(project_path), "Save to Project must promote locked slot edits.")
	DeveloperPlacementStoreScript.reload()
	var normal_promoted := EnvironmentPlacementScript.surface_map(environment)
	var promoted_base := _slot(normal_promoted, "fixed.item_shop_1")
	_check(_slot_position(promoted_base).is_equal_approx(fixed_target), "Promoted slot geometry must become normal generation authority.")

	var binding := EnvironmentSlotBinderScript.bind_base_layout(
		{
			"archetype_id": "corner_store",
			"item_offers": [{"id": "future_stock"}],
		},
		[{
			"object_id": "item:future_stock",
			"object_type": "item",
			"label": "Future Stock",
			"family": "fixed",
			"placement_class": "shop_item",
			"exact_slot_id": "fixed.item_shop_1",
			"active": true,
		}]
	)
	var future_binding: Dictionary = (binding.get("slot_bindings", {}) as Dictionary).get("item:future_stock", {})
	var future_rect: Dictionary = (binding.get("object_rects", {}) as Dictionary).get("item:future_stock", {})
	var promoted_rect := _slot_rect(promoted_base)
	_check(str(future_binding.get("slot_id", "")) == "fixed.item_shop_1", "A future object must bind to the edited reusable slot, not an instance override.")
	_check(
		is_equal_approx(float(future_rect.get("x", -1.0)), promoted_rect.position.x / 900.0)
			and is_equal_approx(float(future_rect.get("y", -1.0)), promoted_rect.position.y / 430.0),
		"Normal binding must consume the promoted slot hit rectangle."
	)

	var cleared := DeveloperPlacementStoreScript.clear_position(environment, "slot_positions", "fixed.item_shop_1")
	_check(bool(cleared.get("ok", false)), "Reset must clear the local edit without deleting promoted project geometry.")
	DeveloperPlacementStoreScript.reload()
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1")).is_equal_approx(fixed_target), "A promoted slot must survive local reset and reload.")


func _check_canvas_contract() -> void:
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.developer_placement_lock_requested.connect(_capture_lock_request)
	canvas.render_environment_snapshot({
		"archetype_id": "corner_store",
		"display_name": "Corner Store",
		"interactable_objects": [{
			"object_id": "item:fixture",
			"object_type": "item",
			"label": "Fixture",
			"slot_id": "fixed.item_shop_1",
			"slot_family": "fixed",
			"fixed_slot_geometry": true,
			"normalized_rect": {"x": 130.0 / 900.0, "y": 80.0 / 430.0, "w": 44.0 / 900.0, "h": 48.0 / 430.0},
		}],
	})
	canvas.set_developer_slot_placement_mode(true)
	await process_frame
	var snapshot: Dictionary = canvas.developer_slot_placement_snapshot()
	_check(bool(snapshot.get("enabled", false)) and int(snapshot.get("visible_slot_count", 0)) > 0, "Slot mode must expose every authored slot even when the room has no occupying objects.")
	var filters: Dictionary = snapshot.get("family_filters", {})
	_check(filters.keys().size() == 4 and filters.has("fixed") and filters.has("event") and filters.has("scenario") and filters.has("exit"), "Slot mode must expose independent filters for all four slot families.")
	var all_family_count := int(snapshot.get("visible_slot_count", 0))
	canvas.set_developer_slot_family_visible("event", false)
	var filtered_snapshot := canvas.developer_slot_placement_snapshot()
	_check(int(filtered_snapshot.get("visible_slot_count", 0)) < all_family_count, "Hiding the event family must remove event slots from the authoring overlay.")
	canvas.set_developer_slot_family_visible("event", true)
	_check(not bool(canvas.developer_placement_snapshot().get("enabled", true)), "Enabling slot mode must disable spawned-object placement mode.")
	var wrapped_label: Array = canvas.call("_wrap_developer_slot_label", "scenario.wall_item_1", ThemeDB.fallback_font, 8, 42.0)
	_check(wrapped_label.size() > 1 and "".join(wrapped_label) == "scenario.wall_item_1", "Slot overlay labels must wrap onto multiple rows without truncating their stable IDs.")

	var slot: Dictionary = canvas.call("_developer_slot", "scenario.wall_item_1")
	_check(not slot.is_empty(), "The overlay must include empty scenario slots by stable ID.")
	if not slot.is_empty():
		var rect: Rect2 = canvas.call("_developer_slot_rect", slot)
		var selected_id := str(canvas.call("_developer_slot_id_at_local_position", rect.get_center()))
		_check(selected_id == "scenario.wall_item_1", "An empty overlay slot must be directly selectable.")
		canvas.call("_begin_developer_slot_placement_drag", rect.get_center())
		var target_top_left := rect.position + Vector2(12.0, 8.0)
		canvas.call("_update_developer_slot_placement_preview", target_top_left)
		snapshot = canvas.developer_slot_placement_snapshot()
		var request: Dictionary = snapshot.get("request", {})
		_check(bool(snapshot.get("pending", false)) and bool(snapshot.get("valid", false)), "Dragging a slot must expose a valid live preview.")
		_check(str(request.get("field", "")) == "slot_positions" and str(request.get("slot_id", "")) == "scenario.wall_item_1", "A slot edit request must retain reusable slot identity.")
		canvas.call("_lock_developer_slot_placement")
		_check(str(locked_request.get("slot_id", "")) == "scenario.wall_item_1", "Lock must emit the selected reusable slot edit.")

	var occupied_slot: Dictionary = canvas.call("_developer_slot", "fixed.item_shop_1")
	var occupied_rect: Rect2 = canvas.call("_developer_slot_rect", occupied_slot)
	var baseline_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	canvas.call("_begin_developer_slot_placement_drag", occupied_rect.get_center())
	canvas.call("_update_developer_slot_placement_preview", occupied_rect.position + Vector2(16.0, 8.0))
	var preview_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	_check(not preview_object_rect.position.is_equal_approx(baseline_object_rect.position), "An occupied slot preview must move its current object with the slot.")
	canvas.call("_lock_developer_slot_placement")
	var persisted := DeveloperPlacementStoreScript.save_position(
		locked_request.get("environment", {}) as Dictionary,
		str(locked_request.get("field", "")),
		str(locked_request.get("slot_id", "")),
		locked_request.get("position", Vector2.ZERO) as Vector2
	)
	_check(bool(persisted.get("ok", false)), "A released slot move must persist through the production placement store.")
	var moved_slot := _slot(EnvironmentPlacementScript.surface_map({"archetype_id": "corner_store"}), "fixed.item_shop_1")
	var moved_rect := _slot_rect(moved_slot)
	canvas.render_environment_snapshot({
		"archetype_id": "corner_store",
		"display_name": "Corner Store",
		"interactable_objects": [{
			"object_id": "item:fixture",
			"object_type": "item",
			"label": "Fixture",
			"slot_id": "fixed.item_shop_1",
			"slot_family": "fixed",
			"fixed_slot_geometry": true,
			"normalized_rect": {
				"x": moved_rect.position.x / 900.0,
				"y": moved_rect.position.y / 430.0,
				"w": moved_rect.size.x / 900.0,
				"h": moved_rect.size.y / 430.0,
			},
		}],
	})
	canvas.set_developer_slot_placement_mode(false)
	var persisted_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	_check(persisted_object_rect.position.is_equal_approx(moved_rect.position), "Leaving slot mode must retain the locked slot position in normal rendering.")

	canvas.set_developer_slot_placement_mode(true)
	occupied_slot = canvas.call("_developer_slot", "fixed.item_shop_1")
	occupied_rect = canvas.call("_developer_slot_rect", occupied_slot)
	canvas.call("_begin_developer_slot_placement_drag", occupied_rect.get_center())
	canvas.call("_update_developer_slot_placement_preview", occupied_rect.position + Vector2(16.0, 8.0))
	canvas.set_developer_placement_mode(true)
	_check(not bool(canvas.developer_slot_placement_snapshot().get("enabled", true)) and bool(canvas.developer_placement_snapshot().get("enabled", false)), "Switching to object placement must disable slot placement.")
	var restored_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	_check(restored_object_rect.position.is_equal_approx(moved_rect.position), "Leaving slot mode must discard only an unlocked preview while preserving the last locked slot position.")
	canvas.queue_free()
	await process_frame


func _capture_lock_request(request: Dictionary) -> void:
	locked_request = request.duplicate(true)


func _slot(surface_map: Dictionary, slot_id: String) -> Dictionary:
	for field in ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]:
		for slot_value in surface_map.get(field, []):
			if typeof(slot_value) == TYPE_DICTIONARY and str((slot_value as Dictionary).get("id", "")) == slot_id:
				return (slot_value as Dictionary).duplicate(true)
	return {}


func _slot_position(slot: Dictionary) -> Vector2:
	var values: Array = slot.get("pos", [])
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2.ZERO


func _slot_rect(slot: Dictionary) -> Rect2:
	var values: Array = slot.get("hit_rect", [])
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])) if values.size() >= 4 else Rect2()


func _translated_geometry(before: Dictionary, after: Dictionary, delta: Vector2) -> bool:
	var before_rect := _slot_rect(before)
	var after_rect := _slot_rect(after)
	var before_label: Array = before.get("label_anchor", [])
	var after_label: Array = after.get("label_anchor", [])
	if before_label.size() < 2 or after_label.size() < 2:
		return false
	return after_rect.position.is_equal_approx(before_rect.position + delta) \
		and after_rect.size.is_equal_approx(before_rect.size) \
		and Vector2(float(after_label[0]), float(after_label[1])).is_equal_approx(Vector2(float(before_label[0]), float(before_label[1])) + delta)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
