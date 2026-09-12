extends SceneTree

const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")

var failures: Array[String] = []
var locked_request: Dictionary = {}
var persist_canvas_locks := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var temp_root := ProjectSettings.globalize_path("res://.tmp/developer_placement_mode_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	var user_path := temp_root.path_join("user.json")
	var project_path := temp_root.path_join("project.json")
	var settings_path := temp_root.path_join("settings.json")
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, user_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, project_path)
	OS.set_environment("BTH_USER_SETTINGS_PATH", settings_path)
	DeveloperPlacementStoreScript.reload()

	await _check_settings_round_trip()
	_check_store_scope_and_promotion(user_path, project_path)
	await _check_canvas_authoring_contract()

	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, "")
	OS.set_environment("BTH_USER_SETTINGS_PATH", "")
	DeveloperPlacementStoreScript.reload()
	DirAccess.remove_absolute(user_path)
	DirAccess.remove_absolute(project_path)
	DirAccess.remove_absolute(settings_path)
	DirAccess.remove_absolute(temp_root)

	if failures.is_empty():
		print("DEVELOPER_PLACEMENT_MODE_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_settings_round_trip() -> void:
	var settings := UserSettingsScript.new()
	settings.developer_placement_mode = true
	var restored := UserSettingsScript.new()
	restored.from_dict(settings.to_dict())
	_check(restored.developer_placement_mode, "Developer placement preference must survive settings serialization.")
	restored.reset()
	_check(not restored.developer_placement_mode, "Developer placement mode must default off.")
	var menu: SettingsMenu = SettingsMenuScript.new()
	root.add_child(menu)
	menu.setup(restored)
	menu.open()
	_check(menu.developer_placement_mode != null, "Options must expose the developer placement toggle.")
	menu.developer_placement_mode.button_pressed = true
	menu.call("_on_developer_placement_mode", true)
	menu.call("_on_apply")
	_check(restored.developer_placement_mode, "Applying Options must activate developer placement mode.")
	menu.queue_free()
	await process_frame


func _check_store_scope_and_promotion(user_path: String, project_path: String) -> void:
	var bar := {"archetype_id": "bar"}
	var corner := {"archetype_id": "corner_store"}
	var original_bar := EnvironmentPlacementScript.surface_map(bar)
	var original_position: Array = (original_bar.get("object_slot_positions", {}) as Dictionary).get("game:slot", [])
	var saved := DeveloperPlacementStoreScript.save_position(bar, "object_slot_positions", "game:slot", Vector2(410.0, 294.0))
	_check(bool(saved.get("ok", false)) and FileAccess.file_exists(user_path), "Lock must save a durable local override.")
	var bar_slots: Dictionary = EnvironmentPlacementScript.surface_map(bar).get("object_slot_positions", {})
	_check(bar_slots.get("game:slot", []) == [410.0, 294.0], "Base override must feed the authoritative room placement map.")
	var spawned_environment := {"archetype_id": "bar", "game_ids": ["slot"], "layout": {}}
	var spawned_layout := EnvironmentInstanceScript.ensure_generated_layout(spawned_environment)
	var spawned_rect: Dictionary = (spawned_layout.get("object_rects", {}) as Dictionary).get("game:slot", {})
	_check(is_equal_approx(float(spawned_rect.get("x", -1.0)), 410.0 / 900.0) and is_equal_approx(float(spawned_rect.get("y", -1.0)), 294.0 / 430.0), "Every spawn must consume the locked board-space position.")
	DeveloperPlacementStoreScript.save_position(bar, "object_slot_positions", "game:slot", Vector2(8.0, 8.0))
	var free_layout := EnvironmentInstanceScript.ensure_generated_layout({"archetype_id": "bar", "game_ids": ["slot"], "layout": {}})
	var free_rect: Dictionary = (free_layout.get("object_rects", {}) as Dictionary).get("game:slot", {})
	_check(is_equal_approx(float(free_rect.get("x", -1.0)), 8.0 / 900.0) and is_equal_approx(float(free_rect.get("y", -1.0)), 8.0 / 430.0), "A manual placement must spawn exactly where authored even without a matching physical surface.")
	DeveloperPlacementStoreScript.save_position(bar, "object_slot_positions", "game:slot", Vector2(410.0, 294.0))
	var corner_slots: Dictionary = EnvironmentPlacementScript.surface_map(corner).get("object_slot_positions", {})
	_check(corner_slots.get("game:slot", []) != [410.0, 294.0], "An override must not leak to another environment.")
	var category_saved := DeveloperPlacementStoreScript.save_position(corner, "category_slot_positions", "item_spots:0", Vector2(612.0, 18.0))
	_check(bool(category_saved.get("ok", false)), "A reusable category slot must save.")
	for future_item_id in ["future_shop_item_a", "future_shop_item_b"]:
		var future_layout := EnvironmentInstanceScript.ensure_generated_layout({
			"archetype_id": "corner_store",
			"item_offers": [{"id": future_item_id}],
			"layout": {},
		})
		var future_rect: Dictionary = (future_layout.get("object_rects", {}) as Dictionary).get("item:%s" % future_item_id, {})
		_check(is_equal_approx(float(future_rect.get("x", -1.0)), 612.0 / 900.0) and is_equal_approx(float(future_rect.get("y", -1.0)), 18.0 / 430.0), "Category slots must place future objects independently of their item id.")
	DeveloperPlacementStoreScript.save_position(bar, "category_slot_positions", "event_spots:0", Vector2(700.0, 18.0))
	for future_event_id in ["future_event_a", "future_event_b"]:
		var future_event_layout := EnvironmentInstanceScript.ensure_generated_layout({
			"archetype_id": "bar",
			"event_ids": [future_event_id],
			"layout": {},
		})
		var future_event_rect: Dictionary = (future_event_layout.get("object_rects", {}) as Dictionary).get("event:%s" % future_event_id, {})
		_check(is_equal_approx(float(future_event_rect.get("x", -1.0)), 700.0 / 900.0) and is_equal_approx(float(future_event_rect.get("y", -1.0)), 18.0 / 430.0), "Event category slots must place future events independently of their event id.")
	var house := {"archetype_id": "house"}
	DeveloperPlacementStoreScript.save_position(house, "object_slot_positions", "home_sleep:bed", Vector2(42.0, 210.0))
	var spawned_house := {"archetype_id": "house", "kind": "home", "layout": {}}
	var house_layout := EnvironmentInstanceScript.ensure_generated_layout(spawned_house)
	var bed_rect: Dictionary = (house_layout.get("object_rects", {}) as Dictionary).get("home_sleep:bed", {})
	_check(is_equal_approx(float(bed_rect.get("x", -1.0)), 42.0 / 900.0) and is_equal_approx(float(bed_rect.get("y", -1.0)), 210.0 / 430.0), "Home objects must respawn at their exact locked position.")
	var club_layer := {"archetype_id": "small_underground_casino", "current_layer_id": "club"}
	var casino_layer := {"archetype_id": "small_underground_casino", "current_layer_id": "casino"}
	DeveloperPlacementStoreScript.save_position(club_layer, "object_slot_positions", "travel:leave", Vector2(12.0, 300.0))
	var club_slots: Dictionary = EnvironmentPlacementScript.surface_map(club_layer).get("object_slot_positions", {})
	var casino_slots: Dictionary = EnvironmentPlacementScript.surface_map(casino_layer).get("object_slot_positions", {})
	_check(club_slots.get("travel:leave", []) == [12.0, 300.0] and casino_slots.get("travel:leave", []) != [12.0, 300.0], "Layered-room overrides must be scoped to the exact layer.")

	var scenario_saved := DeveloperPlacementStoreScript.save_position(bar, "scenario_object_slot_positions", "bar_darts_league_night_league_captain", Vector2(720.0, 268.0))
	_check(bool(scenario_saved.get("ok", false)), "Scenario-object override must save.")
	var scenario_slots: Dictionary = EnvironmentPlacementScript.surface_map(bar).get("scenario_object_slot_positions", {})
	_check(scenario_slots.get("bar_darts_league_night_league_captain", []) == [720.0, 268.0], "Scenario-object override must use the same authoritative plane.")

	var promoted := DeveloperPlacementStoreScript.promote_user_overrides()
	_check(bool(promoted.get("ok", false)) and FileAccess.file_exists(project_path), "Save to Project must create the shippable override file.")
	var promoted_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(project_path))
	_check(typeof(promoted_data) == TYPE_DICTIONARY and (promoted_data as Dictionary).has("rooms"), "Promoted placement data must retain its closed schema.")

	var cleared := DeveloperPlacementStoreScript.clear_position(bar, "object_slot_positions", "game:slot")
	_check(bool(cleared.get("ok", false)), "Reset must remove the local object override.")
	# The just-promoted project value remains authoritative. Reloading proves that
	# Reset is local and that a promoted placement is truly part of the game data.
	DeveloperPlacementStoreScript.reload()
	bar_slots = EnvironmentPlacementScript.surface_map(bar).get("object_slot_positions", {})
	_check(bar_slots.get("game:slot", []) == [410.0, 294.0], "Promoted placement must survive local reset and reload.")
	_check(original_position != [410.0, 294.0], "Fixture must exercise a real position change.")


func _check_canvas_authoring_contract() -> void:
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.developer_placement_lock_requested.connect(_capture_lock_request)
	canvas.developer_placement_lock_requested.connect(_persist_canvas_lock_request)
	canvas.developer_placement_lock_requested.connect(_simulate_stale_placement_refresh.bind(canvas))
	canvas.developer_placement_promote_requested.connect(_promote_canvas_locks)
	canvas.render_environment_snapshot({
		"archetype_id": "bar",
		"display_name": "Bar",
		"interactable_objects": [{
			"object_id": "game:slot",
			"object_type": "game",
			"label": "Slot Machine",
			"owner_namespace": "game",
			"stable_object_id": "game:slot",
			"placement_class": "floor_fixture",
			"normalized_rect": {"x": 400.0 / 900.0, "y": 294.0 / 430.0, "w": 118.0 / 900.0, "h": 72.0 / 430.0},
		}],
	})
	canvas.set_developer_placement_mode(true)
	canvas.set_selected_object("game:slot", false)
	_check(str(canvas.call("_developer_object_id_at_local_position", Vector2(459.0, 330.0))) == "game:slot", "Every rendered object must be directly selectable in developer mode.")
	canvas.call("_update_developer_placement_preview", Vector2(8.0, 8.0))
	_check(bool(canvas.developer_placement_snapshot().get("valid", false)), "Every in-bounds location must be saveable even when it has no classified physical surface.")
	canvas.call("_update_developer_placement_preview", Vector2(410.0, 294.0))
	var snapshot: Dictionary = canvas.developer_placement_snapshot()
	_check(bool(snapshot.get("enabled", false)) and bool(snapshot.get("pending", false)), "Canvas must expose a live developer placement preview.")
	_check(bool(snapshot.get("valid", false)), "A correctly grounded preview must be lockable.")
	var request: Dictionary = snapshot.get("request", {})
	_check(str(request.get("field", "")) == "object_slot_positions" and str(request.get("slot_id", "")) == "game:slot", "Canvas must retain stable base-object identity.")
	var scenario_identity: Dictionary = canvas.call("_developer_placement_identity", {
		"id": "scenario::bar_darts_league_night_league_captain",
		"owner_namespace": "scenario",
		"stable_object_id": "bar_darts_league_night_league_captain",
	})
	_check(str(scenario_identity.get("field", "")) == "scenario_object_slot_positions" and str(scenario_identity.get("slot_id", "")) == "bar_darts_league_night_league_captain", "Scenario additions must retain their owner-scoped stable identity.")
	var item_category_identity: Dictionary = canvas.call("_developer_placement_identity", {
		"id": "item:any_future_stock",
		"interaction_type": "item",
		"layout_spot_field": "item_spots",
		"layout_index": 2,
	})
	_check(str(item_category_identity.get("field", "")) == "category_slot_positions" and str(item_category_identity.get("slot_id", "")) == "item_spots:2", "Item placement must author its reusable room-category slot rather than a single item id.")
	var event_category_identity: Dictionary = canvas.call("_developer_placement_identity", {
		"id": "event:any_future_event",
		"interaction_type": "event",
		"layout_spot_field": "event_spots",
		"layout_index": 1,
	})
	_check(str(event_category_identity.get("field", "")) == "category_slot_positions" and str(event_category_identity.get("slot_id", "")) == "event_spots:1", "Event placement must author its reusable room-category slot rather than a single event id.")
	canvas.call("_finish_developer_placement_edit")
	_check(locked_request.get("position", Vector2.ZERO) == Vector2(410.0, 294.0), "Finishing a drag must auto-lock the exact board-space position.")
	_check(not bool(canvas.developer_placement_snapshot().get("pending", true)), "A finished drag must become a retained room edit instead of a cancellable preview.")
	var locked_live_rect: Rect2 = canvas.call("_developer_edit_rect_for_object", canvas.call("_scene_object", "game:slot"))
	_check(locked_live_rect.position.is_equal_approx(Vector2(410.0, 294.0)), "Lock must keep the accepted position visible across its synchronous room refresh (got %s)." % locked_live_rect.position)
	persist_canvas_locks = true
	canvas.call("_update_developer_placement_preview", Vector2(420.0, 294.0))
	canvas.call("_save_developer_placement_to_project")
	var project_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DeveloperPlacementStoreScript.project_path()))
	var project_rooms: Dictionary = project_data.get("rooms", {})
	var project_bar: Dictionary = project_rooms.get("bar", {})
	var project_slots: Dictionary = project_bar.get("object_slot_positions", {})
	_check(project_slots.get("game:slot", []) == [420.0, 294.0], "Save to Project must lock the current pending position before promotion.")
	var saved_live_rect: Rect2 = canvas.call("_developer_edit_rect_for_object", canvas.call("_scene_object", "game:slot"))
	_check(saved_live_rect.position.is_equal_approx(Vector2(420.0, 294.0)), "Save to Project must leave the object at its newly saved position without a game reset (got %s)." % saved_live_rect.position)
	persist_canvas_locks = false
	canvas.set_developer_placement_mode(false)
	_check(not bool(canvas.developer_placement_snapshot().get("enabled", true)), "Disabling developer mode must restore normal input mode.")
	canvas.queue_free()
	await process_frame


func _capture_lock_request(request: Dictionary) -> void:
	locked_request = request.duplicate(true)


func _persist_canvas_lock_request(request: Dictionary) -> void:
	if not persist_canvas_locks:
		return
	DeveloperPlacementStoreScript.save_position(
		request.get("environment", {}),
		str(request.get("field", "object_slot_positions")),
		str(request.get("slot_id", "")),
		request.get("position", Vector2.ZERO)
	)


func _promote_canvas_locks() -> void:
	DeveloperPlacementStoreScript.promote_user_overrides()


func _simulate_stale_placement_refresh(_request: Dictionary, canvas: PixelSceneCanvas) -> void:
	# Reproduce the original host failure: saving synchronously refreshed a cached
	# pre-drag projection and made the object visibly snap back.
	canvas.render_environment_snapshot({
		"archetype_id": "bar",
		"display_name": "Bar",
		"interactable_objects": [{
			"object_id": "game:slot",
			"object_type": "game",
			"label": "Slot Machine",
			"owner_namespace": "game",
			"stable_object_id": "game:slot",
			"placement_class": "floor_fixture",
			"normalized_rect": {"x": 400.0 / 900.0, "y": 294.0 / 430.0, "w": 118.0 / 900.0, "h": 72.0 / 430.0},
		}],
	})


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
