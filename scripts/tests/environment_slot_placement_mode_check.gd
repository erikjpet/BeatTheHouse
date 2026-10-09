extends SceneTree

const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const LOCAL_SCENARIO_SURFACE_1 := "scenario.local_surface_item_1"
const LOCAL_SCENARIO_FLOOR_1 := "scenario.local_floor_fixture_1"
const LOCAL_SCENARIO_STANDING_2 := "scenario.local_standing_person_2"

var failures: Array[String] = []
var locked_request: Dictionary = {}
var locked_requests: Array[Dictionary] = []
var export_request_count := 0
var exported_pending_request: Dictionary = {}
var slot_layer_request: Dictionary = {}
var slot_shortcut_states: Array[bool] = []
var placement_undo_request_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var temp_root := ProjectSettings.globalize_path("res://.tmp/environment_slot_placement_mode_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	var user_path := temp_root.path_join("user.json")
	var project_path := temp_root.path_join("project.json")
	var report_path := temp_root.path_join("placement_report.json")
	var distribution_root := temp_root.path_join("distribution_data")
	var settings_path := temp_root.path_join("settings.json")
	for path in [
		user_path, "%s.bak" % user_path,
		project_path, "%s.bak" % project_path,
		report_path, "%s.bak" % report_path,
		settings_path, "%s.bak" % settings_path,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_write_project_fixture(project_path)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, user_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, project_path)
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, report_path)
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, settings_path)
	DeveloperPlacementStoreScript.reload()

	await _check_settings_contract()
	_check_catalog_drift_recovery(user_path)
	_check_slot_geometry_export_and_promotion(user_path, project_path, report_path)
	await _check_canvas_contract()
	_check_distribution_report_path(distribution_root)

	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, "")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, "")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_FEATURE_ENV, "")
	OS.set_environment(UserSettingsScript.SETTINGS_PATH_ENV, "")
	DeveloperPlacementStoreScript.reload()
	for path in [user_path, "%s.bak" % user_path, project_path, "%s.bak" % project_path, report_path, "%s.bak" % report_path, settings_path, "%s.bak" % settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path in [
		distribution_root.path_join("BeatTheHouse_environment_slot_placement_changes.json"),
		distribution_root.path_join("BeatTheHouse_environment_slot_placement_changes.json.bak"),
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(distribution_root):
		DirAccess.remove_absolute(distribution_root)
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
	menu.sync_developer_slot_placement_mode(false)
	_check(
		not restored.developer_slot_placement_mode
			and not menu.draft.developer_slot_placement_mode
			and menu.developer_slot_placement_mode.text.begins_with("[ ]"),
		"A live shortcut change must synchronize the saved setting, open draft, and Settings checkbox."
	)
	menu.sync_developer_slot_placement_mode(true)
	menu.queue_free()
	await process_frame


func _check_slot_geometry_export_and_promotion(user_path: String, project_path: String, report_path: String) -> void:
	var environment := {"archetype_id": "corner_store"}
	var scenario_environment := {
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_lotto_fever",
		"scenario_state": {"id": "corner_store_lotto_fever"},
	}
	var empty_export := DeveloperPlacementStoreScript.export_user_overrides()
	var empty_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var empty_rooms: Dictionary = empty_report.get("rooms", {})
	var empty_apartment: Dictionary = empty_rooms.get("apartment", {})
	var empty_slots: Dictionary = empty_apartment.get("slot_positions", {})
	_check(
		bool(empty_export.get("ok", false))
			and int(empty_export.get("room_count", -1)) == 1
			and int(empty_export.get("slot_count", -1)) == 1
			and int(empty_export.get("local_slot_count", -1)) == 0
			and _reported_position(empty_slots, "fixed.home_sleep").is_equal_approx(Vector2(12.0, 34.0)),
		"A project-only placement must export self-contained effective authority while reporting zero machine-local positions."
	)
	_check_complete_layout_storage(user_path, project_path)
	var normal_before := EnvironmentPlacementScript.surface_map(environment)
	for no_scenario_alias in ["", "__none", "__default", "base", DeveloperPlacementStoreScript.BASE_LAYOUT_ID]:
		_check(
			EnvironmentPlacementScript.active_scenario_id({
				"archetype_id": "corner_store",
				"scenario_id": no_scenario_alias,
			}).is_empty(),
			"The no-scenario selector alias %s must resolve to base placement authority." % no_scenario_alias
		)
	var fixed_before := _slot(normal_before, "fixed.item_shop_1")
	var event_before := _slot(normal_before, "event.standing_person_1")
	var scenario_before := _slot(EnvironmentPlacementScript.surface_map(scenario_environment), LOCAL_SCENARIO_SURFACE_1)
	var exit_before := _slot(normal_before, "exit.safe_right")
	_check(not fixed_before.is_empty() and not event_before.is_empty() and not scenario_before.is_empty() and not exit_before.is_empty(), "Fixture must expose fixed, event, scenario, and exit slots.")
	if fixed_before.is_empty() or event_before.is_empty() or scenario_before.is_empty() or exit_before.is_empty():
		return
	_check(
		_slot(normal_before, "scenario.surface_item_1").is_empty()
			and not _slot(normal_before, "scenario.standing_person_4").is_empty(),
		"A no-scenario catalog room must hide ordinary generic scenario capacity while retaining shared runtime reserves."
	)

	var fixed_target := _slot_position(fixed_before) + Vector2(40.0, 20.0)
	var event_target := _slot_position(event_before) + Vector2(8.0, -12.0)
	var scenario_target := _slot_position(scenario_before) + Vector2(-24.0, -16.0)
	var exit_target := _slot_position(exit_before) + Vector2(18.0, 12.0)
	for edit in [
		["fixed.item_shop_1", fixed_target],
		["event.standing_person_1", event_target],
		["exit.safe_right", exit_target],
	]:
		var saved := DeveloperPlacementStoreScript.save_position(environment, "slot_positions", str(edit[0]), edit[1] as Vector2)
		_check(bool(saved.get("ok", false)), "Every slot kind must save through the durable placement store.")
	var scenario_saved := DeveloperPlacementStoreScript.save_position(
		scenario_environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1,
		scenario_target
	)
	_check(bool(scenario_saved.get("ok", false)), "An exact scenario-instance slot must save in its active scenario layout.")
	var fixed_layer_saved := DeveloperPlacementStoreScript.save_slot_layer(environment, "fixed.item_shop_1", -1)
	var scenario_layer_saved := DeveloperPlacementStoreScript.save_slot_layer(scenario_environment, LOCAL_SCENARIO_SURFACE_1, 1)
	var invalid_layer_rejected := DeveloperPlacementStoreScript.save_slot_layer(environment, "fixed.item_shop_1", 2)
	_check(
		bool(fixed_layer_saved.get("ok", false)) \
			and bool(scenario_layer_saved.get("ok", false)) \
			and not bool(invalid_layer_rejected.get("ok", true)),
		"Slot draw layers must persist in shared and exact-scenario scopes and reject values outside the three authored layers: %s / %s / %s" % [fixed_layer_saved, scenario_layer_saved, invalid_layer_rejected]
	)
	var rejected_unscoped_scenario := DeveloperPlacementStoreScript.save_position(
		environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1,
		scenario_target
	)
	_check(not bool(rejected_unscoped_scenario.get("ok", true)), "An ordinary scenario-instance slot must not save without an active scenario.")
	var rejected_unknown_scenario := DeveloperPlacementStoreScript.save_position(
		{"archetype_id": "corner_store", "scenario_id": "unknown_scenario"},
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1,
		scenario_target
	)
	_check(not bool(rejected_unknown_scenario.get("ok", true)), "An unknown scenario must not create an untracked placement layout.")
	_check(FileAccess.file_exists(user_path), "A locked slot must create the machine-local placement file.")

	var normal_local := EnvironmentPlacementScript.surface_map(environment)
	var scenario_local := EnvironmentPlacementScript.surface_map(scenario_environment)
	var authoring_local := EnvironmentPlacementScript.authoring_surface_map(environment)
	var scenario_authoring_local := EnvironmentPlacementScript.authoring_surface_map(scenario_environment)
	_check(_slot_position(_slot(normal_local, "fixed.item_shop_1")).is_equal_approx(fixed_target), "A locked fixed-slot edit must remain active after placement mode is disabled.")
	_check(_slot_position(_slot(normal_local, "event.standing_person_1")).is_equal_approx(event_target), "Normal rendering must consume the locked event-slot edit before project promotion.")
	_check(_slot_position(_slot(scenario_local, LOCAL_SCENARIO_SURFACE_1)).is_equal_approx(scenario_target), "Normal rendering must consume the active layout's locked scenario-slot edit before project promotion.")
	_check(_slot_position(_slot(normal_local, "exit.safe_right")).is_equal_approx(exit_target), "Normal rendering must consume the locked exit-slot edit before project promotion.")
	_check(
		int(_slot(normal_local, "fixed.item_shop_1").get("draw_layer", 99)) == -1 \
			and int(_slot(scenario_local, LOCAL_SCENARIO_SURFACE_1).get("draw_layer", 99)) == 1,
		"Effective placement maps must apply shared and scenario-specific slot draw layers before rendering."
	)
	_check(_slot_position(_slot(authoring_local, "fixed.item_shop_1")).is_equal_approx(fixed_target), "Authoring view must load the local fixed-slot edit.")
	_check(_slot_position(_slot(authoring_local, "event.standing_person_1")).is_equal_approx(event_target), "Authoring view must load the local event-slot edit.")
	_check(_slot_position(_slot(scenario_authoring_local, LOCAL_SCENARIO_SURFACE_1)).is_equal_approx(scenario_target), "Authoring view must load the local scenario-instance edit.")
	_check(_slot_position(_slot(authoring_local, "exit.safe_right")).is_equal_approx(exit_target), "Authoring view must load the local exit-slot edit.")
	_check(_translated_geometry(fixed_before, _slot(authoring_local, "fixed.item_shop_1"), fixed_target - _slot_position(fixed_before)), "Moving a slot must rigidly translate pos, hit_rect, and label_anchor without resizing it.")
	var other_scenario_environment := {
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_inventory_night",
		"scenario_state": {"id": "corner_store_inventory_night"},
	}
	_check(
		not _slot_position(_slot(EnvironmentPlacementScript.surface_map(other_scenario_environment), LOCAL_SCENARIO_SURFACE_1)).is_equal_approx(scenario_target),
		"The same local scenario role ID must keep an independent coordinate in a different scenario layout."
	)

	DeveloperPlacementStoreScript.reload()
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1")).is_equal_approx(fixed_target), "Locked slot edits must survive a durable reload in normal rendering.")
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(scenario_environment), LOCAL_SCENARIO_SURFACE_1)).is_equal_approx(scenario_target), "Scenario-layout edits must survive a durable reload in their exact context.")
	_check(
		int(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1").get("draw_layer", 99)) == -1 \
			and int(_slot(EnvironmentPlacementScript.surface_map(scenario_environment), LOCAL_SCENARIO_SURFACE_1).get("draw_layer", 99)) == 1,
		"Slot draw-layer choices must survive a durable reload."
	)
	var other_environment := {"archetype_id": "bar"}
	_check(_slot(EnvironmentPlacementScript.authoring_surface_map(other_environment), "fixed.item_shop_1").is_empty(), "A slot edit must not leak into another environment.")
	var no_catalog_environment := {"archetype_id": "house"}
	var no_catalog_slot := _slot(EnvironmentPlacementScript.surface_map(no_catalog_environment), "scenario.surface_item_1")
	var no_catalog_saved := DeveloperPlacementStoreScript.save_position(
		no_catalog_environment,
		"slot_positions",
		"scenario.surface_item_1",
		Vector2(10.0, 10.0)
	)
	_check(
		no_catalog_slot.is_empty() and not bool(no_catalog_saved.get("ok", true)),
		"A map with no catalog scenarios must reject its retired, unused scenario-family capacity."
	)

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
	var retained_club_scenario_on_casino_floor := {
		"archetype_id": "small_underground_casino",
		"current_layer_id": "casino",
		"scenario_id": "punchline_open_mic_night",
		"scenario_state": {"id": "punchline_open_mic_night", "layer_id": "club"},
	}
	_check(
		DeveloperPlacementStoreScript.active_scenario_id(retained_club_scenario_on_casino_floor).is_empty()
			and DeveloperPlacementStoreScript.layout_id(retained_club_scenario_on_casino_floor) == "small_underground_casino:casino::__base",
		"A retained scenario cursor must not claim placement authority on another floor."
	)
	var club_slot := _slot(EnvironmentPlacementScript.surface_map(club_layer), "fixed.door_right_lower")
	var club_target := _slot_position(club_slot) + Vector2(-10.0, -6.0)
	var layer_saved := DeveloperPlacementStoreScript.save_position(club_layer, "slot_positions", "fixed.door_right_lower", club_target)
	_check(bool(layer_saved.get("ok", false)), "A layered-environment slot edit must save.")
	_check(
		DeveloperPlacementStoreScript.user_slot_overrides(club_layer, "slot_positions").has("fixed.door_right_lower")
			and not DeveloperPlacementStoreScript.user_slot_overrides(casino_layer, "slot_positions").has("fixed.door_right_lower"),
		"Slot edits must be scoped to the exact environment layer."
	)
	var user_bytes_before_export := FileAccess.get_file_as_bytes(user_path)
	var exported := DeveloperPlacementStoreScript.export_user_overrides()
	_check(
		bool(exported.get("ok", false))
			and str(exported.get("path", "")) == report_path
			and str(exported.get("absolute_path", "")) == ProjectSettings.globalize_path(report_path)
			and int(exported.get("room_count", 0)) == 3
			and int(exported.get("slot_count", 0)) == 6
			and int(exported.get("local_slot_count", -1)) == 5
			and FileAccess.file_exists(report_path),
		"Export Placement Report must combine the five local changes with committed authority at the requested writable path."
	)
	var report_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var report_rooms: Dictionary = (report_data as Dictionary).get("rooms", {}) if typeof(report_data) == TYPE_DICTIONARY else {}
	var corner_report: Dictionary = report_rooms.get("corner_store", {})
	var corner_slots: Dictionary = corner_report.get("slot_positions", {})
	var corner_layers: Dictionary = corner_report.get("slot_layers", {})
	var corner_layouts: Dictionary = corner_report.get("scenario_layouts", {})
	var lotto_report: Dictionary = corner_layouts.get("corner_store_lotto_fever", {})
	var lotto_slots: Dictionary = lotto_report.get("slot_positions", {})
	var lotto_layers: Dictionary = lotto_report.get("slot_layers", {})
	var club_report: Dictionary = report_rooms.get("small_underground_casino:club", {})
	var club_slots: Dictionary = club_report.get("slot_positions", {})
	var report_coverage: Dictionary = (report_data as Dictionary).get("coverage", {})
	var report_metadata: Dictionary = (report_data as Dictionary).get("report_metadata", {})
	_check(
		int((report_data as Dictionary).get("schema_version", 0)) == DeveloperPlacementStoreScript.SCHEMA_VERSION
			and report_rooms.has("apartment")
			and _reported_position(corner_slots, "fixed.item_shop_1").is_equal_approx(fixed_target)
			and _reported_position(corner_slots, "event.standing_person_1").is_equal_approx(event_target)
			and not corner_slots.has(LOCAL_SCENARIO_SURFACE_1)
			and _reported_position(lotto_slots, LOCAL_SCENARIO_SURFACE_1).is_equal_approx(scenario_target)
			and _reported_position(corner_slots, "exit.safe_right").is_equal_approx(exit_target)
			and _reported_position(club_slots, "fixed.door_right_lower").is_equal_approx(club_target)
			and int(corner_layers.get("fixed.item_shop_1", 99)) == -1
			and int(lotto_layers.get(LOCAL_SCENARIO_SURFACE_1, 99)) == 1
			and int(report_coverage.get("expected_layout_count", 0)) == 75
			and int(report_coverage.get("saved_layout_count", -1)) == 0
			and str(report_metadata.get("schema", "")) == "beat_the_house.environment_placement_report/v1"
			and str(report_metadata.get("report_scope", "")) == "effective_reviewed_authority"
			and not str(report_metadata.get("placement_surfaces_sha256", "")).is_empty()
			and not str(report_metadata.get("scenario_slot_layouts_sha256", "")).is_empty()
			and int(report_metadata.get("effective_slot_count", -1)) == 6
			and int(report_metadata.get("local_slot_count", -1)) == 5,
		"The schema-v3 report must separate shared and exact scenario coordinates, preserve layered room keys, include source-bound metadata, and include 75-layout coverage."
	)
	_check(FileAccess.get_file_as_bytes(user_path) == user_bytes_before_export, "Exporting must not mutate or clear the active machine-local placement data.")

	var promoted := DeveloperPlacementStoreScript.promote_user_overrides()
	_check(bool(promoted.get("ok", false)) and FileAccess.file_exists(project_path), "Save to Project must promote locked slot edits.")
	DeveloperPlacementStoreScript.reload()
	var normal_promoted := EnvironmentPlacementScript.surface_map(environment)
	var promoted_base := _slot(normal_promoted, "fixed.item_shop_1")
	_check(_slot_position(promoted_base).is_equal_approx(fixed_target), "Promoted slot geometry must become normal generation authority.")
	_check(int(promoted_base.get("draw_layer", 99)) == -1, "Promoted slot draw layers must become normal generation authority.")

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
	var reexported := DeveloperPlacementStoreScript.export_user_overrides()
	var refreshed_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var refreshed_rooms: Dictionary = refreshed_report.get("rooms", {})
	var refreshed_corner: Dictionary = refreshed_rooms.get("corner_store", {})
	_check(
		bool(reexported.get("ok", false))
			and (refreshed_corner.get("slot_positions", {}) as Dictionary).has("fixed.item_shop_1")
			and int(reexported.get("slot_count", 0)) == 6
			and int(reexported.get("local_slot_count", -1)) == 4,
		"Re-exporting must retain committed effective authority while separately reporting the current local-change count."
	)
	for slot_id in ["event.standing_person_1", "exit.safe_right"]:
		DeveloperPlacementStoreScript.clear_position(environment, "slot_positions", slot_id)
	DeveloperPlacementStoreScript.clear_position(scenario_environment, "slot_positions", LOCAL_SCENARIO_SURFACE_1)
	DeveloperPlacementStoreScript.clear_position(club_layer, "slot_positions", "fixed.door_right_lower")
	var cleared_export := DeveloperPlacementStoreScript.export_user_overrides()
	var cleared_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	_check(
		bool(cleared_export.get("ok", false))
			and int(cleared_export.get("room_count", -1)) == 3
			and int(cleared_export.get("slot_count", -1)) == 6
			and int(cleared_export.get("local_slot_count", -1)) == 0
			and _reported_position(
				(((cleared_report.get("rooms", {}) as Dictionary).get("corner_store", {}) as Dictionary).get("slot_positions", {}) as Dictionary),
				"fixed.item_shop_1"
			).is_equal_approx(fixed_target)
			and not FileAccess.file_exists("%s.bak" % report_path),
		"Exporting after the last local reset must remain a self-contained effective snapshot and remove its stale backup."
	)
	DeveloperPlacementStoreScript.reload()
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1")).is_equal_approx(fixed_target), "A promoted slot must survive local reset and reload.")


func _check_catalog_drift_recovery(user_path: String) -> void:
	var file := FileAccess.open(user_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {
			"house": {
				"base_saved": true,
				"slot_positions": {
					"fixed.home_sleep": [321.0, 123.0],
					"fixed.retired_fixture": [1.0, 2.0],
				},
				"slot_layers": {
					"fixed.home_sleep": 1,
					"fixed.retired_fixture": -1,
				},
				"scenario_layouts": {
					"retired_scenario": {
						"saved": true,
						"slot_positions": {"scenario.retired_actor": [4.0, 5.0]},
					},
				},
			},
		},
	}, "\t"))
	file.close()
	var backup_file := FileAccess.open("%s.bak" % user_path, FileAccess.WRITE)
	backup_file.store_string(JSON.stringify({
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {
			"apartment": {
				"slot_positions": {"fixed.home_sleep": [9.0, 9.0]},
			},
		},
	}, "\t"))
	backup_file.close()
	DeveloperPlacementStoreScript.reload()
	var recovered_positions := DeveloperPlacementStoreScript.user_slot_overrides(
		{"archetype_id": "house"}
	)
	var recovered_layers := DeveloperPlacementStoreScript.slot_layer_overrides(
		{"archetype_id": "house"}
	)
	_check(
		bool(DeveloperPlacementStoreScript.last_user_load_outcome.get("recovered_catalog_drift", false))
			and _reported_position(recovered_positions, "fixed.home_sleep").is_equal_approx(Vector2(321.0, 123.0))
			and not recovered_positions.has("fixed.retired_fixture")
			and int(recovered_layers.get("fixed.home_sleep", 0)) == 1
			and not DeveloperPlacementStoreScript.layout_saved({"archetype_id": "house"}),
		"Catalog changes must retain known primary coordinates and layers instead of rolling back to an older valid backup, while invalidating only incomplete review state."
	)
	for path in [user_path, "%s.bak" % user_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DeveloperPlacementStoreScript.reload()


func _check_complete_layout_storage(user_path: String, project_path: String) -> void:
	var rejected_unknown := DeveloperPlacementStoreScript.save_layout(
		{"archetype_id": "corner_store", "scenario_id": "unknown_scenario"},
		{"fixed.item_shop_1": Vector2(10.0, 10.0)}
	)
	_check(not bool(rejected_unknown.get("ok", true)), "A full-layout save must reject an untracked environment/scenario context.")
	var rejected_fixed := DeveloperPlacementStoreScript.save_position(
		{"archetype_id": "corner_store"}, "slot_positions", "fixed.not_authored", Vector2(10.0, 10.0)
	)
	var rejected_scenario := DeveloperPlacementStoreScript.save_position(
		{"archetype_id": "corner_store", "scenario_id": "corner_store_lotto_fever"},
		"slot_positions",
		"scenario.not_authored",
		Vector2(10.0, 10.0)
	)
	_check(
		not bool(rejected_fixed.get("ok", true)) and not bool(rejected_scenario.get("ok", true)),
		"Single-slot authoring must reject fabricated shared and scenario slot identities."
	)
	var base_environment := {"archetype_id": "house"}
	var base_positions := _surface_positions(EnvironmentPlacementScript.surface_map(base_environment))
	var incomplete_base_positions := base_positions.duplicate(true)
	incomplete_base_positions.erase("fixed.home_sleep")
	var rejected_incomplete := DeveloperPlacementStoreScript.save_layout(base_environment, incomplete_base_positions)
	var fabricated_base_positions := base_positions.duplicate(true)
	fabricated_base_positions["fixed.not_authored"] = Vector2(10.0, 10.0)
	var rejected_fabricated := DeveloperPlacementStoreScript.save_layout(base_environment, fabricated_base_positions)
	_check(
		not bool(rejected_incomplete.get("ok", true)) and not bool(rejected_fabricated.get("ok", true)),
		"A completed layout save must require the exact authored slot set."
	)
	var base_save := DeveloperPlacementStoreScript.save_layout(base_environment, base_positions)
	var coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	_check(
		bool(base_save.get("ok", false))
			and str(base_save.get("layout_id", "")) == "house::__base"
			and int(base_save.get("slot_count", -1)) == base_positions.size()
			and int(coverage.get("saved_layout_count", -1)) == 1
			and int(coverage.get("expected_layout_count", -1)) == 75,
		"Saving a complete base layout must capture its full active slot set and advance 75-layout coverage."
	)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(user_path))
	var house_room: Dictionary = (stored.get("rooms", {}) as Dictionary).get("house", {})
	_check(
		bool(house_room.get("base_saved", false))
			and not (house_room.get("slot_positions", {}) as Dictionary).has("scenario.surface_item_1")
			and not house_room.has("scenario_layouts"),
		"A no-catalog map must not reserialize retired scenario-family capacity in its shared base room."
	)
	var promoted_base := DeveloperPlacementStoreScript.promote_user_overrides()
	for path in [user_path, "%s.bak" % user_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DeveloperPlacementStoreScript.reload()
	_check(
		bool(promoted_base.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 1
			and DeveloperPlacementStoreScript.layout_saved(base_environment),
		"Committed completion markers must contribute to effective placement coverage."
	)
	var shadow_position := _slot_position(_slot(EnvironmentPlacementScript.surface_map(base_environment), "fixed.home_sleep")) + Vector2(3.0, 2.0)
	var shadow_edit := DeveloperPlacementStoreScript.save_position(base_environment, "slot_positions", "fixed.home_sleep", shadow_position)
	_check(
		bool(shadow_edit.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 0
			and not DeveloperPlacementStoreScript.layout_saved(base_environment),
		"A first local edit must shadow a committed completion marker until the layout is saved again."
	)
	DeveloperPlacementStoreScript.clear_position(base_environment, "slot_positions", "fixed.home_sleep")
	_check(
		int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 1
			and DeveloperPlacementStoreScript.layout_saved(base_environment),
		"Clearing the last local edit must restore committed completion authority."
	)

	var lotto_environment := {
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_lotto_fever",
		"scenario_state": {"id": "corner_store_lotto_fever"},
	}
	var lotto_positions := _surface_positions(EnvironmentPlacementScript.surface_map(lotto_environment))
	var lotto_save := DeveloperPlacementStoreScript.save_layout(lotto_environment, lotto_positions)
	coverage = DeveloperPlacementStoreScript.coverage_snapshot()
	_check(
		bool(lotto_save.get("ok", false))
			and str(lotto_save.get("layout_id", "")) == "corner_store::corner_store_lotto_fever"
			and int(coverage.get("saved_layout_count", -1)) == 2
			and DeveloperPlacementStoreScript.layout_saved(lotto_environment)
			and not DeveloperPlacementStoreScript.layout_saved({"archetype_id": "corner_store"}),
		"Saving a scenario layout must mark only that exact scenario context, not its base room."
	)
	stored = JSON.parse_string(FileAccess.get_file_as_string(user_path))
	var corner_room: Dictionary = (stored.get("rooms", {}) as Dictionary).get("corner_store", {})
	var corner_shared: Dictionary = corner_room.get("slot_positions", {})
	var corner_layouts: Dictionary = corner_room.get("scenario_layouts", {})
	var lotto_layout: Dictionary = corner_layouts.get("corner_store_lotto_fever", {})
	var lotto_scenario_positions: Dictionary = lotto_layout.get("slot_positions", {})
	_check(
		not corner_shared.has(LOCAL_SCENARIO_SURFACE_1)
			and corner_shared.has("fixed.item_shop_1")
			and lotto_scenario_positions.has(LOCAL_SCENARIO_SURFACE_1)
			and bool(lotto_layout.get("saved", false)),
		"A complete scenario save must split shared room positions from exact scenario-instance positions."
	)

	var inventory_environment := {
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_inventory_night",
		"scenario_state": {"id": "corner_store_inventory_night"},
	}
	var inventory_positions := _surface_positions(EnvironmentPlacementScript.surface_map(inventory_environment))
	var inventory_original: Vector2 = inventory_positions.get(LOCAL_SCENARIO_SURFACE_1, Vector2.ZERO)
	inventory_positions[LOCAL_SCENARIO_SURFACE_1] = inventory_original + Vector2(9.0, 7.0)
	var inventory_save := DeveloperPlacementStoreScript.save_layout(inventory_environment, inventory_positions)
	stored = JSON.parse_string(FileAccess.get_file_as_string(user_path))
	corner_room = (stored.get("rooms", {}) as Dictionary).get("corner_store", {})
	corner_layouts = corner_room.get("scenario_layouts", {})
	lotto_scenario_positions = (corner_layouts.get("corner_store_lotto_fever", {}) as Dictionary).get("slot_positions", {})
	var inventory_scenario_positions: Dictionary = (corner_layouts.get("corner_store_inventory_night", {}) as Dictionary).get("slot_positions", {})
	coverage = DeveloperPlacementStoreScript.coverage_snapshot()
	_check(
		bool(inventory_save.get("ok", false))
			and int(coverage.get("saved_layout_count", -1)) == 3
			and not _reported_position(lotto_scenario_positions, LOCAL_SCENARIO_SURFACE_1).is_equal_approx(
				_reported_position(inventory_scenario_positions, LOCAL_SCENARIO_SURFACE_1)
			),
		"Two scenarios may reuse the same compact role ID while retaining independent saved coordinates."
	)

	var promoted_scenarios := DeveloperPlacementStoreScript.promote_user_overrides()
	for path in [user_path, "%s.bak" % user_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DeveloperPlacementStoreScript.reload()
	_check(
		bool(promoted_scenarios.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3,
		"Committed exact-scenario completion markers must survive promotion and reload."
	)
	var shared_corner_position := _slot_position(
		_slot(EnvironmentPlacementScript.surface_map(lotto_environment), "fixed.item_shop_1")
	) + Vector2(5.0, 4.0)
	var shared_corner_edit := DeveloperPlacementStoreScript.save_position(
		lotto_environment,
		"slot_positions",
		"fixed.item_shop_1",
		shared_corner_position
	)
	_check(
		bool(shared_corner_edit.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 1,
		"A shared room edit must invalidate every committed scenario context in that room."
	)
	DeveloperPlacementStoreScript.clear_position(
		lotto_environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1
	)
	_check(
		int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 1
			and not DeveloperPlacementStoreScript.layout_saved(lotto_environment),
		"Resetting an exact slot must not erase its incomplete shadow while a shared edit remains."
	)
	DeveloperPlacementStoreScript.clear_position(
		lotto_environment,
		"slot_positions",
		"fixed.item_shop_1"
	)
	_check(
		int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3,
		"Resetting the final shared edit must restore committed scenario completion authority."
	)
	var project_inventory_positions := _surface_positions(
		EnvironmentPlacementScript.surface_map(inventory_environment)
	)
	var unchanged_inventory_save := DeveloperPlacementStoreScript.save_layout(
		inventory_environment,
		project_inventory_positions
	)
	var direct_shared_reset := DeveloperPlacementStoreScript.clear_position(
		inventory_environment,
		"slot_positions",
		"fixed.item_shop_2"
	)
	_check(
		bool(direct_shared_reset.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Resetting a project-identical shared row directly after Save Layout must persist and restore project completion."
	)
	var temporary_inventory_position := _slot_position(
		_slot(EnvironmentPlacementScript.surface_map(inventory_environment), LOCAL_SCENARIO_SURFACE_1)
	) + Vector2(2.0, 1.0)
	DeveloperPlacementStoreScript.save_position(
		inventory_environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1,
		temporary_inventory_position
	)
	DeveloperPlacementStoreScript.clear_position(
		inventory_environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1
	)
	_check(
		bool(unchanged_inventory_save.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Resetting the last exact edit must restore committed completion when the local shared snapshot matches the project."
	)
	DeveloperPlacementStoreScript.clear_position(
		inventory_environment,
		"slot_positions",
		LOCAL_SCENARIO_FLOOR_1
	)
	_check(
		int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Repeated resets of project-identical exact rows must not recreate a false completion shadow."
	)
	var shared_snapshot_position := _slot_position(
		_slot(EnvironmentPlacementScript.surface_map(inventory_environment), "fixed.item_shop_1")
	)
	DeveloperPlacementStoreScript.save_position(
		inventory_environment,
		"slot_positions",
		"fixed.item_shop_1",
		shared_snapshot_position + Vector2(4.0, 2.0)
	)
	DeveloperPlacementStoreScript.clear_position(
		inventory_environment,
		"slot_positions",
		"fixed.item_shop_1"
	)
	_check(
		int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3
			and DeveloperPlacementStoreScript.layout_saved(lotto_environment)
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Resetting a shared edit must restore completion even when project-identical snapshot rows remain."
	)
	var changed_lotto_positions := _surface_positions(
		EnvironmentPlacementScript.surface_map(lotto_environment)
	)
	changed_lotto_positions["fixed.item_shop_1"] = (
		changed_lotto_positions.get("fixed.item_shop_1", Vector2.ZERO) as Vector2
	) + Vector2(7.0, 3.0)
	var changed_lotto_save := DeveloperPlacementStoreScript.save_layout(
		lotto_environment,
		changed_lotto_positions
	)
	_check(
		bool(changed_lotto_save.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 2
			and DeveloperPlacementStoreScript.layout_saved(lotto_environment)
			and not DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"A direct full-layout save with changed shared geometry must invalidate other completed contexts."
	)
	var restored_inventory_save := DeveloperPlacementStoreScript.save_layout(
		inventory_environment,
		project_inventory_positions
	)
	_check(
		bool(restored_inventory_save.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3
			and DeveloperPlacementStoreScript.layout_saved(lotto_environment)
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Saving shared geometry back to the project must clear stale sibling completion shadows."
	)
	var custom_inventory_positions := project_inventory_positions.duplicate(true)
	custom_inventory_positions["fixed.item_shop_1"] = (
		custom_inventory_positions.get("fixed.item_shop_1", Vector2.ZERO) as Vector2
	) + Vector2(6.0, 4.0)
	custom_inventory_positions[LOCAL_SCENARIO_SURFACE_1] = (
		custom_inventory_positions.get(LOCAL_SCENARIO_SURFACE_1, Vector2.ZERO) as Vector2
	) + Vector2(3.0, 2.0)
	var custom_inventory_save := DeveloperPlacementStoreScript.save_layout(
		inventory_environment,
		custom_inventory_positions
	)
	var unchanged_custom_shared := DeveloperPlacementStoreScript.save_position(
		inventory_environment,
		"slot_positions",
		"fixed.item_shop_1",
		custom_inventory_positions.get("fixed.item_shop_1", Vector2.ZERO)
	)
	var unchanged_custom_exact := DeveloperPlacementStoreScript.save_position(
		inventory_environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1,
		custom_inventory_positions.get(LOCAL_SCENARIO_SURFACE_1, Vector2.ZERO)
	)
	_check(
		bool(custom_inventory_save.get("ok", false))
			and bool(unchanged_custom_shared.get("ok", false))
			and bool(unchanged_custom_exact.get("ok", false))
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Writing an unchanged shared or exact coordinate must preserve the reviewed layout marker."
	)
	var shared_return_to_project := DeveloperPlacementStoreScript.save_position(
		inventory_environment,
		"slot_positions",
		"fixed.item_shop_1",
		project_inventory_positions.get("fixed.item_shop_1", Vector2.ZERO)
	)
	_check(
		bool(shared_return_to_project.get("ok", false))
			and int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 2
			and DeveloperPlacementStoreScript.layout_saved(lotto_environment)
			and not DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Changing shared geometry back to the project must still invalidate an unreviewed custom exact-layout hybrid."
	)
	DeveloperPlacementStoreScript.clear_position(
		inventory_environment,
		"slot_positions",
		LOCAL_SCENARIO_SURFACE_1
	)
	_check(
		int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 3
			and DeveloperPlacementStoreScript.layout_saved(inventory_environment),
		"Resetting the final custom exact coordinate must restore committed completion after hybrid invalidation."
	)

	for path in [user_path, "%s.bak" % user_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_write_project_fixture(project_path)
	DeveloperPlacementStoreScript.reload()
	_check(int(DeveloperPlacementStoreScript.coverage_snapshot().get("saved_layout_count", -1)) == 0, "The complete-layout fixture must reset machine-local coverage before the remaining placement tests.")


func _write_project_fixture(project_path: String) -> void:
	var project_file := FileAccess.open(project_path, FileAccess.WRITE)
	project_file.store_string(JSON.stringify({
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {
			"apartment": {
				"slot_positions": {"fixed.home_sleep": [12.0, 34.0]},
			},
		},
	}, "\t"))
	project_file.close()


func _check_canvas_contract() -> void:
	var canvas: PixelSceneCanvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	root.add_child(canvas)
	await process_frame
	canvas.set_developer_slot_placement_shortcut_enabled(true)
	canvas.developer_placement_lock_requested.connect(_capture_lock_request)
	canvas.developer_placement_export_requested.connect(_capture_export_request)
	canvas.developer_slot_layer_requested.connect(_persist_slot_layer_request)
	canvas.developer_placement_undo_requested.connect(_persist_placement_undo_request)
	canvas.developer_slot_placement_shortcut_toggled.connect(_capture_slot_shortcut_state)
	var stale_canvas_object_id := "scenario::stale_canvas_visual"
	var stale_canvas_objects: Array = canvas.call("_objects_from_foundation_snapshot", {
		"archetype_id": "corner_store",
		"scenario_render_snapshot": {
			"ok": true,
			"scenario_id": "corner_store_lotto_fever",
			"visual_objects": [{
				"object_id": stale_canvas_object_id,
				"object_type": "scenario_object",
				"visible": true,
			}],
		},
	})
	var stale_canvas_visual_present := false
	for object_value in stale_canvas_objects:
		if typeof(object_value) == TYPE_DICTIONARY \
				and str((object_value as Dictionary).get("id", "")) == stale_canvas_object_id:
			stale_canvas_visual_present = true
	_check(not stale_canvas_visual_present, "The canvas fallback must reject stale scenario visuals when the room has no active scenario.")
	var corner_snapshot := {
		"archetype_id": "corner_store",
		"display_name": "Corner Store",
		"scenario_id": "corner_store_lotto_fever",
		"scenario_state": {"id": "corner_store_lotto_fever"},
		"scenario_sequence_state": {
			"scenario_id": "corner_store_lotto_fever",
			"phase_id": "arrival",
			"status": "active",
		},
		"interactable_objects": [{
			"object_id": "item:fixture",
			"object_type": "item",
			"label": "Fixture",
			"slot_id": "fixed.item_shop_1",
			"slot_family": "fixed",
			"fixed_slot_geometry": true,
			"normalized_rect": {"x": 130.0 / 900.0, "y": 80.0 / 430.0, "w": 44.0 / 900.0, "h": 48.0 / 430.0},
		}],
	}
	canvas.render_environment_snapshot(corner_snapshot)
	await _send_key(KEY_F1)
	_check(
		bool(canvas.developer_slot_placement_snapshot().get("enabled", false)) and slot_shortcut_states == [true],
		"F1 must enable slot placement and report the live setting change."
	)
	await _send_key(KEY_F1)
	_check(
		not bool(canvas.developer_slot_placement_snapshot().get("enabled", true)) and slot_shortcut_states == [true, false],
		"A second F1 press must disable slot placement."
	)
	canvas.set_developer_slot_placement_mode(true)
	await process_frame
	_check(canvas.developer_placement_export_button != null and canvas.developer_placement_export_button.text == "Export Report", "The placement overlay must expose an explicit EXE-safe report action.")
	canvas.developer_placement_export_button.pressed.emit()
	_check(export_request_count == 1, "Export Placement Report must work without requiring a selected slot or pending move.")
	var snapshot: Dictionary = canvas.developer_slot_placement_snapshot()
	_check(bool(snapshot.get("enabled", false)) and int(snapshot.get("visible_slot_count", 0)) > 0, "Slot mode must expose occupied or required slots in its default preview.")
	var filters: Dictionary = snapshot.get("family_filters", {})
	_check(
		filters.keys().size() == 5 and bool(filters.get("scenario", false)) \
			and not bool(filters.get("event", true)) and not bool(filters.get("fixed", true)) \
			and not bool(filters.get("exit", true)) and not bool(filters.get("all", true)),
		"An exact-scenario placement pass must open on the Scenario family alone instead of displaying all four families."
	)
	_check(bool(snapshot.get("show_empty_capacity", false)) and bool(snapshot.get("show_runtime_reserves", false)), "A manual placement pass must reveal empty capacity and runtime reserves by default.")
	_check(not bool(snapshot.get("edit_shared_in_scenario", true)), "Exact-scenario placement must lock room-shared positions by default.")
	_check(int(snapshot.get("visible_slot_count", 0)) < int(snapshot.get("total_slot_count", 0)), "Family tabs must keep the default scenario preview from displaying all four families together.")
	var preview_context: Dictionary = snapshot.get("preview_context", {})
	_check(
		str(preview_context.get("scenario_id", "")) == "corner_store_lotto_fever" \
			and str(preview_context.get("phase_id", "")) == "arrival",
		"Slot mode must identify the active scenario and phase represented by the current room snapshot."
	)
	canvas.render_environment_snapshot({
		"archetype_id": "small_underground_casino",
		"current_layer_id": "casino",
		"scenario_id": "punchline_open_mic_night",
		"scenario_state": {
			"id": "punchline_open_mic_night",
			"layer_id": "club",
			"display_name": "Open Mic Night",
		},
		"scenario_sequence_state": {
			"scenario_id": "punchline_open_mic_night",
			"phase_id": "arrival",
			"status": "active",
		},
		"interactable_objects": [],
	})
	preview_context = canvas.developer_slot_placement_snapshot().get("preview_context", {})
	_check(
		str(preview_context.get("scenario_id", "")).is_empty()
			and str(preview_context.get("label", "")) == "Active preview: no scenario",
		"A retained scenario cursor from another floor must not mislabel the active placement context."
	)
	var available_base_slots: Array = canvas.call("_developer_slots", true)
	var authored_base_slots: Array = canvas.call("_developer_authored_slots")
	var hidden_base_scenario_ids: Array[String] = []
	for slot_value in authored_base_slots:
		var authored_slot := slot_value as Dictionary
		if str(authored_slot.get("kind", "")) == "scenario":
			hidden_base_scenario_ids.append(str(authored_slot.get("id", "")))
	var available_base_scenario_ids: Array[String] = []
	for slot_value in available_base_slots:
		var available_slot := slot_value as Dictionary
		if str(available_slot.get("kind", "")) == "scenario":
			available_base_scenario_ids.append(str(available_slot.get("id", "")))
	var no_scenario_snapshot := canvas.developer_slot_placement_snapshot()
	var no_scenario_required: Array = no_scenario_snapshot.get("required_review_families", [])
	var scenario_filter_button := canvas.developer_slot_filter_buttons.get("scenario") as BaseButton
	var full_base_request: Dictionary = canvas.call("_developer_full_slot_layout_request")
	var full_base_positions: Dictionary = full_base_request.get("full_positions", {})
	var hidden_reserves_preserved := not hidden_base_scenario_ids.is_empty()
	for hidden_slot_id in hidden_base_scenario_ids:
		hidden_reserves_preserved = hidden_reserves_preserved and full_base_positions.has(hidden_slot_id)
	_check(
		available_base_scenario_ids.is_empty()
			and not no_scenario_required.has("scenario")
			and scenario_filter_button != null
			and not scenario_filter_button.visible,
		"A no-scenario room must not offer scenario-family markers, review work, or a Scenario placement tab."
	)
	_check(hidden_reserves_preserved, "Hiding no-scenario reserve markers must still preserve their shared coordinates in a complete base-layout save.")
	canvas.set_developer_slot_family_visible("scenario", true)
	var rejected_scenario_filter := canvas.developer_slot_placement_snapshot()
	_check(
		str(rejected_scenario_filter.get("active_family", "")) == "fixed"
			and not bool((rejected_scenario_filter.get("family_filters", {}) as Dictionary).get("scenario", false)),
		"A no-scenario placement context must reject programmatic Scenario-family selection."
	)
	canvas.render_environment_snapshot(corner_snapshot)
	_check(
		(canvas.developer_slot_filter_buttons.get("scenario") as BaseButton).visible,
		"Rendering an exact scenario must restore its Scenario placement tab."
	)
	canvas.set_developer_slot_family_visible("event", true)
	var filtered_snapshot := canvas.developer_slot_placement_snapshot()
	filters = filtered_snapshot.get("family_filters", {})
	_check(
		str(filtered_snapshot.get("active_family", "")) == "event" \
			and bool(filters.get("event", false)) \
			and not bool(filters.get("fixed", true)) \
			and bool(filtered_snapshot.get("edit_shared_in_scenario", false)),
		"Selecting a shared family tab must replace the prior family and unlock that room-shared family in a scenario preview."
	)
	_check(int(filtered_snapshot.get("visible_slot_count", -1)) > 0, "The default complete-pass view must expose empty event capacity.")
	for editable_family in ["fixed", "event", "exit"]:
		canvas.set_developer_slot_family_visible(editable_family, true)
		var family_slots: Array = canvas.call("_developer_slots")
		_check(not family_slots.is_empty(), "%s must expose at least one slot in the scenario fixture." % editable_family.capitalize())
		if family_slots.is_empty():
			continue
		var family_slot := family_slots[0] as Dictionary
		var family_rect: Rect2 = canvas.call("_developer_slot_rect", family_slot)
		canvas.call("_begin_developer_slot_placement_drag", family_rect.get_center())
		_check(
			bool(canvas.developer_slot_dragging) and bool(canvas.developer_slot_placement_snapshot().get("pending", false)),
			"Selecting %s during an active scenario must make its shared slots movable without a second unlock step." % editable_family.capitalize()
		)
		canvas.call("_cancel_developer_slot_placement_preview")
	canvas.set_developer_slot_family_visible("all", true)
	var all_snapshot := canvas.developer_slot_placement_snapshot()
	var all_filters: Dictionary = all_snapshot.get("family_filters", {})
	_check(
		str(all_snapshot.get("active_family", "")) == "all" \
			and bool(all_filters.get("all", false)) \
			and bool(all_filters.get("fixed", false)) \
			and bool(all_filters.get("event", false)) \
			and bool(all_filters.get("scenario", false)) \
			and bool(all_filters.get("exit", false)) \
			and int(all_snapshot.get("visible_slot_count", -1)) == int(all_snapshot.get("total_slot_count", -2)),
		"The final All tab must show every available slot family together without hiding capacity."
	)
	canvas.set_developer_slot_family_visible("event", true)
	canvas.set_developer_slot_show_empty_capacity(false)
	_check(int(canvas.developer_slot_placement_snapshot().get("visible_slot_count", -1)) == 0, "Turning off Empty capacity must temporarily hide unused event positions.")
	canvas.set_developer_slot_show_empty_capacity(true)
	_check(int(canvas.developer_slot_placement_snapshot().get("visible_slot_count", 0)) > 0, "The Empty capacity toggle must reveal unused slots in the active family.")
	_check(not bool(canvas.developer_placement_snapshot().get("enabled", true)), "Enabling slot mode must disable spawned-object placement mode.")
	var wrapped_label: Array = canvas.call("_wrap_developer_slot_label", "scenario.local_wall_item_1", ThemeDB.fallback_font, 8, 42.0)
	_check(wrapped_label.size() > 1 and "".join(wrapped_label) == "scenario.local_wall_item_1", "Slot overlay labels must wrap onto multiple rows without truncating their stable IDs.")
	var fixed_slot: Dictionary = canvas.call("_developer_slot", "fixed.item_shop_1")
	_check(str(canvas.call("_developer_slot_primary_label", fixed_slot)) == "Fixture", "Occupied slot labels must lead with the friendly occupant name instead of the raw stable ID.")
	var future_phase_slot: Dictionary = canvas.call("_developer_slot", LOCAL_SCENARIO_SURFACE_1)
	_check(
		str(canvas.call("_developer_slot_primary_label", future_phase_slot)) == "Winning Slips and Cups",
		"An unoccupied exact scenario slot must identify its future claimant instead of displaying only a generic physical class."
	)
	var alternate_phase_fixture := {
		"id": LOCAL_SCENARIO_FLOOR_1,
		"kind": "scenario",
		"footprint_class": "floor_fixture",
		"physical_role": "Floor Fixture 1",
		"scenario_instance": true,
		"scenario_id": "bar_live_band",
		"occupant_ids": [
			"scenario::bar_live_band_aftermath_set_failed_prop",
			"scenario::bar_live_band_band_stage",
		],
	}
	_check(
		str(canvas.call("_developer_slot_primary_label", alternate_phase_fixture)) == "Band Stage (+1 alternate)",
		"A multi-phase exact slot must lead with its normal human-readable role and disclose alternate claimants."
	)
	var aftermath_fixture := {
		"id": LOCAL_SCENARIO_SURFACE_1,
		"kind": "scenario",
		"footprint_class": "surface_item",
		"physical_role": "Surface Item 1",
		"scenario_instance": true,
		"scenario_id": "bar_live_band",
		"occupant_ids": ["scenario::bar_live_band_aftermath_set_completed_prop"],
	}
	_check(
		str(canvas.call("_developer_slot_primary_label", aftermath_fixture)) == "Aftermath: Set Completed",
		"An aftermath-only placement marker must name its phase and claimant instead of using a generic slot label."
	)
	var occupied_reserve := fixed_slot.duplicate(true)
	occupied_reserve["runtime_reserve"] = true
	_check(bool(canvas.call("_developer_slot_visible_by_detail", occupied_reserve)), "An occupied runtime-reserve slot must remain visible even while empty reserves are hidden.")
	var reserve_fixture := {
		"id": "scenario.standing_person_3",
		"kind": "scenario",
		"footprint_class": "standing_person",
		"physical_role": "Delivery Contact Reserve",
		"occupant_ids": ["runtime:delivery_contact"],
		"runtime_reserve": true,
		"reserve_reason": "delivery contact",
	}
	_check(bool(canvas.call("_developer_slot_is_runtime_reserve", reserve_fixture)), "The placement UI must recognize canonical runtime-reserve metadata.")
	_check(str(canvas.call("_developer_slot_reserve_reason", reserve_fixture)) == "Delivery Contact", "Runtime reserves must expose a friendly reason in the placement panel.")
	_check(str(canvas.call("_developer_slot_capacity_label", reserve_fixture)) == "Delivery Contact Reserve 3", "Repeated shared capacity labels must include their stable ordinal.")
	_check((canvas.call("_developer_slot_known_claimants", reserve_fixture) as Array).has("runtime:delivery_contact"), "Known slot claimants must remain available in placement details without replacing an active occupant label.")
	_check(
		(canvas.call("_developer_slot_claimant_labels", reserve_fixture) as Array).is_empty(),
		"Shared runtime reserves must not present migration aliases as additional objects to place."
	)
	var shared_chain_fixture := {
		"id": "event.surface_item_1",
		"kind": "event",
		"footprint_class": "surface_item",
		"physical_role": "Counter or table item",
		"occupant_ids": ["event:chain06_sal_estate_item"],
	}
	_check(
		(canvas.call("_developer_slot_claimant_labels", shared_chain_fixture) as Array).is_empty(),
		"Shared slots must not expose technical runtime identities as secondary Known roles."
	)
	_check(
		str(canvas.call("_developer_slot_claimant_label", "meta_sal_shelf:0", "")) == "Sal's Shelf Slot 1",
		"Changing pawn-shop stock must leave each shared shelf position with a clear owner-facing name."
	)
	_check(
		str(canvas.call("_developer_slot_claimant_label", "bar_lock_in_task_0", "bar_lock_in")).is_empty()
			and str(canvas.call("_developer_slot_claimant_label", "delta_queen_fog_delay_work_1_choice_2", "delta_queen_fog_delay")).is_empty(),
		"Action-only task and decision IDs must not masquerade as physical placement claimants."
	)

	canvas.set_developer_slot_family_visible("scenario", true)
	var slot: Dictionary = canvas.call("_developer_slot", LOCAL_SCENARIO_SURFACE_1)
	_check(not slot.is_empty(), "All-capacity mode must include empty scenario slots by stable ID.")
	if not slot.is_empty():
		var rect: Rect2 = canvas.call("_developer_slot_rect", slot)
		var selected_id := str(canvas.call("_developer_slot_id_at_local_position", rect.get_center()))
		_check(selected_id == LOCAL_SCENARIO_SURFACE_1, "An empty overlay slot must be directly selectable.")
		canvas.call("_begin_developer_slot_placement_drag", rect.get_center())
		var target_top_left := rect.position + Vector2(12.0, 8.0)
		canvas.call("_update_developer_slot_placement_preview", target_top_left)
		snapshot = canvas.developer_slot_placement_snapshot()
		var request: Dictionary = snapshot.get("request", {})
		_check(bool(snapshot.get("pending", false)) and bool(snapshot.get("valid", false)), "Dragging a slot must expose a valid live preview.")
		for overlap_id_value in snapshot.get("overlap_ids", []):
			var overlap_slot: Dictionary = canvas.call("_developer_slot", str(overlap_id_value))
			_check(not overlap_slot.is_empty(), "Overlap diagnostics must name only authored markers from the complete active context.")
		_check(str(request.get("field", "")) == "slot_positions" and str(request.get("slot_id", "")) == LOCAL_SCENARIO_SURFACE_1, "A slot edit request must retain reusable slot identity.")
		canvas.developer_placement_export_button.pressed.emit()
		_check(str(exported_pending_request.get("slot_id", "")) == LOCAL_SCENARIO_SURFACE_1, "Export must carry the selected reusable slot edit to the host before writing the report.")
		_check(export_request_count == 2 and not bool(canvas.developer_slot_placement_snapshot().get("pending", true)), "Export must request the report only after retaining the current pending slot move.")

	locked_requests.clear()
	var nudge_slot: Dictionary = canvas.call("_developer_slot", LOCAL_SCENARIO_SURFACE_1)
	var next_slot: Dictionary = canvas.call("_developer_slot", LOCAL_SCENARIO_STANDING_2)
	if not nudge_slot.is_empty() and not next_slot.is_empty():
		canvas.developer_slot_selected_id = LOCAL_SCENARIO_SURFACE_1
		var right_key := InputEventKey.new()
		right_key.keycode = KEY_RIGHT
		right_key.pressed = true
		canvas.call("_handle_developer_slot_placement_input", right_key)
		_check(bool(canvas.developer_slot_placement_snapshot().get("pending", false)), "A keyboard nudge must create a pending slot edit.")
		var next_slot_rect: Rect2 = canvas.call("_developer_slot_rect", next_slot)
		canvas.call("_begin_developer_slot_placement_drag", next_slot_rect.get_center())
		_check(
			locked_requests.size() == 1
				and str(locked_requests[0].get("slot_id", "")) == LOCAL_SCENARIO_SURFACE_1
				and str(canvas.developer_slot_placement_snapshot().get("selected_slot_id", "")) == LOCAL_SCENARIO_STANDING_2,
			"Selecting another marker must lock a valid keyboard-nudged position before changing selection."
		)
		canvas.call("_handle_developer_slot_placement_input", right_key)
		canvas.render_environment_snapshot({
			"archetype_id": "bar",
			"display_name": "Bar",
			"scenario_id": "bar_live_band",
			"scenario_state": {"id": "bar_live_band"},
			"interactable_objects": [],
		})
		_check(
			locked_requests.size() == 2
				and str(locked_requests[1].get("slot_id", "")) == LOCAL_SCENARIO_STANDING_2
				and str((locked_requests[1].get("environment", {}) as Dictionary).get("scenario_id", "")) == "corner_store_lotto_fever",
			"Changing Library context must lock a valid keyboard-nudged position against the old exact scenario before rendering the new context."
		)
		canvas.render_environment_snapshot(corner_snapshot)

	canvas.set_developer_slot_family_visible("fixed", true)
	canvas.set_developer_slot_show_empty_capacity(false)
	var occupied_slot: Dictionary = canvas.call("_developer_slot", "fixed.item_shop_1")
	var occupied_rect: Rect2 = canvas.call("_developer_slot_rect", occupied_slot)
	var baseline_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	canvas.call("_begin_developer_slot_placement_drag", occupied_rect.get_center())
	var front_layer_button := canvas.developer_slot_layer_buttons.get("front") as BaseButton
	var previous_item_shop_layer := int(DeveloperPlacementStoreScript.slot_layer_overrides(
		corner_snapshot
	).get("fixed.item_shop_1", 0))
	_check(front_layer_button != null and not front_layer_button.disabled, "Selecting an editable slot must enable all three draw-layer controls.")
	if front_layer_button != null:
		front_layer_button.toggled.emit(true)
	_check(
		str(slot_layer_request.get("slot_id", "")) == "fixed.item_shop_1" \
			and int(slot_layer_request.get("layer", 99)) == 1 \
			and int(canvas.call("_scene_object_draw_layer", canvas.call("_scene_object", "item:fixture"))) == 1,
		"The Front control must persist the selected slot at the highest draw layer and immediately affect object ordering."
	)
	var undo_key := InputEventKey.new()
	undo_key.keycode = KEY_Z
	undo_key.ctrl_pressed = true
	undo_key.pressed = true
	canvas.call("_handle_developer_slot_placement_input", undo_key)
	_check(
		placement_undo_request_count == 1 \
			and int(canvas.developer_slot_placement_snapshot().get("undo_count", -1)) == 0 \
			and int(DeveloperPlacementStoreScript.slot_layer_overrides(
				corner_snapshot
			).get("fixed.item_shop_1", 0)) == previous_item_shop_layer \
			and int(canvas.call("_scene_object_draw_layer", canvas.call("_scene_object", "item:fixture"))) == previous_item_shop_layer,
		"Ctrl+Z must durably undo the latest slot layer edit and immediately restore the room view."
	)
	canvas.call("_cancel_developer_slot_placement_preview")
	occupied_slot = canvas.call("_developer_slot", "fixed.item_shop_1")
	occupied_rect = canvas.call("_developer_slot_rect", occupied_slot)
	canvas.call("_begin_developer_slot_placement_drag", occupied_rect.get_center())
	_check(bool(canvas.developer_slot_placement_snapshot().get("edit_shared_in_scenario", false)), "Selecting Fixed in a scenario must automatically enable shared-room editing.")
	_check(bool(canvas.developer_slot_dragging), "The occupied-slot performance fixture must exercise an active drag.")
	# Warm the static overlay model once; pointer motion may move only the selected
	# rectangle and must not rescan every object/manifest row for every slot.
	canvas.call("_developer_slot_overlay_rows")
	canvas.reset_performance_counters()
	var drag_work_before := canvas.debug_soak_snapshot()
	var final_preview_top_left := (occupied_rect.position + Vector2(16.0, 8.0)).round()
	for preview_top_left in [
		occupied_rect.position + Vector2(6.0, 3.0),
		occupied_rect.position + Vector2(11.0, 5.0),
		final_preview_top_left,
	]:
		canvas.call("_update_developer_slot_placement_preview", preview_top_left)
		canvas.call("_developer_slot_overlay_rows")
	# A fractional motion that rounds to the current board coordinate must be a
	# no-op instead of repeating any of the expensive placement rebuilds.
	canvas.call("_update_developer_slot_placement_preview", final_preview_top_left + Vector2(0.24, 0.24))
	var drag_work_after := canvas.debug_soak_snapshot()
	_check(
		int(drag_work_after.get("scene_object_cache_rebuild_count", -1)) == int(drag_work_before.get("scene_object_cache_rebuild_count", -2)),
		"Mouse motion during a slot drag must not rebuild the complete scene-object cache."
	)
	_check(
		int(drag_work_after.get("developer_placement_panel_update_count", -1)) == int(drag_work_before.get("developer_placement_panel_update_count", -2)),
		"Mouse motion during a slot drag must defer the complete placement-panel audit until the edit finishes."
	)
	_check(
		int(drag_work_after.get("developer_slot_cache_rebuild_count", -1)) == 0,
		"A warmed slot cache must not be rebuilt for each drag-motion event."
	)
	_check(
		int(drag_work_after.get("developer_slot_overlay_cache_rebuild_count", -1)) == 0,
		"A warmed slot-overlay model must not rescan occupants, requirements, and warnings for each drag redraw."
	)
	var preview_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	_check(
		preview_object_rect.position.is_equal_approx(final_preview_top_left)
			and not preview_object_rect.position.is_equal_approx(baseline_object_rect.position),
		"An occupied slot preview must follow the final pointer position without mutating and rebuilding the complete scene."
	)
	canvas.call("_lock_developer_slot_placement")
	_check(bool(locked_request.get("defer_refresh", false)), "A normal slot drop must defer the expensive authoritative room rebuild until the placement pass is flushed.")
	var persisted := DeveloperPlacementStoreScript.save_position(
		locked_request.get("environment", {}) as Dictionary,
		str(locked_request.get("field", "")),
		str(locked_request.get("slot_id", "")),
		locked_request.get("position", Vector2.ZERO) as Vector2
	)
	_check(bool(persisted.get("ok", false)), "A released slot move must persist through the production placement store.")
	var moved_slot := _slot(EnvironmentPlacementScript.surface_map({"archetype_id": "corner_store"}), "fixed.item_shop_1")
	var moved_rect := _slot_rect(moved_slot)
	canvas.reset_performance_counters()
	canvas.render_environment_snapshot({
		"archetype_id": "corner_store",
		"display_name": "Corner Store",
		"scenario_id": "corner_store_lotto_fever",
		"scenario_state": {"id": "corner_store_lotto_fever"},
		"scenario_sequence_state": {
			"scenario_id": "corner_store_lotto_fever",
			"phase_id": "arrival",
			"status": "active",
		},
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
	_check(
		int(canvas.debug_soak_snapshot().get("scene_object_cache_rebuild_count", -1)) == 1,
		"One authoritative placement snapshot must build the scene and label caches exactly once."
	)
	canvas.set_developer_slot_placement_mode(false)
	var persisted_object_rect: Rect2 = canvas.call("_board_rect_for_object", canvas.call("_scene_object", "item:fixture"))
	_check(persisted_object_rect.position.is_equal_approx(moved_rect.position), "Leaving slot mode must retain the locked slot position in normal rendering.")

	canvas.set_developer_slot_placement_mode(true)
	canvas.set_developer_slot_edit_shared_in_scenario(true)
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


func _check_distribution_report_path(distribution_root: String) -> void:
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, "")
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_ROOT_ENV, distribution_root)
	OS.set_environment(PersistencePathsScript.DISTRIBUTION_FEATURE_ENV, "1")
	var exported := DeveloperPlacementStoreScript.export_user_overrides()
	var expected_path := distribution_root.path_join("BeatTheHouse_environment_slot_placement_changes.json")
	_check(
		bool(exported.get("ok", false))
			and str(exported.get("path", "")).replace("\\", "/") == expected_path.replace("\\", "/")
			and FileAccess.file_exists(expected_path),
		"An EXE distribution must export the report through its writable per-user data root instead of res:// or the executable directory."
	)


func _capture_lock_request(request: Dictionary) -> void:
	locked_request = request.duplicate(true)
	locked_requests.append(request.duplicate(true))


func _capture_export_request(request: Dictionary) -> void:
	export_request_count += 1
	exported_pending_request = request.duplicate(true)


func _capture_slot_shortcut_state(enabled: bool) -> void:
	slot_shortcut_states.append(enabled)


func _send_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	root.push_input(pressed, true)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.pressed = false
	root.push_input(released, true)
	await process_frame


func _persist_slot_layer_request(request: Dictionary) -> void:
	slot_layer_request = request.duplicate(true)
	request["_slot_layer_handled"] = true
	var state := DeveloperPlacementStoreScript.capture_user_room_state(
		request.get("environment", {}) as Dictionary
	)
	var result := DeveloperPlacementStoreScript.save_slot_layer(
		request.get("environment", {}) as Dictionary,
		str(request.get("slot_id", "")),
		int(request.get("layer", 0))
	)
	request["_slot_layer_persisted"] = bool(result.get("ok", false))
	if bool(result.get("ok", false)):
		request["_placement_undo_record"] = {
			"label": "Test layer change",
			"state": state,
		}


func _persist_placement_undo_request(request: Dictionary) -> void:
	placement_undo_request_count += 1
	request["_placement_undo_handled"] = true
	var record: Dictionary = request.get("undo_record", {})
	var result := DeveloperPlacementStoreScript.restore_user_room_state(
		(record.get("state", {}) as Dictionary)
	)
	request["_placement_undo_persisted"] = bool(result.get("ok", false))


func _slot(surface_map: Dictionary, slot_id: String) -> Dictionary:
	for field in ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]:
		for slot_value in surface_map.get(field, []):
			if typeof(slot_value) == TYPE_DICTIONARY and str((slot_value as Dictionary).get("id", "")) == slot_id:
				return (slot_value as Dictionary).duplicate(true)
	return {}


func _slot_position(slot: Dictionary) -> Vector2:
	var values: Array = slot.get("pos", [])
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2.ZERO


func _reported_position(slots: Dictionary, slot_id: String) -> Vector2:
	var values: Array = slots.get(slot_id, [])
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2(-99999.0, -99999.0)


func _surface_positions(surface_map: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]:
		for slot_value in surface_map.get(field, []):
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue
			var slot := slot_value as Dictionary
			var slot_id := str(slot.get("id", "")).strip_edges()
			if not slot_id.is_empty():
				result[slot_id] = _slot_position(slot)
	return result


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
