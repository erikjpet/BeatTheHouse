extends SceneTree

const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const PersistencePathsScript := preload("res://scripts/core/persistence_paths.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const SettingsMenuScript := preload("res://scripts/ui/settings_menu.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")

var failures: Array[String] = []
var locked_request: Dictionary = {}
var locked_requests: Array[Dictionary] = []
var export_request_count := 0
var exported_pending_request: Dictionary = {}


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
	_check(
		bool(empty_export.get("ok", false))
			and int(empty_export.get("slot_count", -1)) == 0
			and (empty_report.get("rooms", {}) as Dictionary).is_empty(),
		"A project-only placement must produce a current empty report instead of being misreported as a local EXE change."
	)
	_check_complete_layout_storage(user_path, project_path)
	var normal_before := EnvironmentPlacementScript.surface_map(environment)
	var fixed_before := _slot(normal_before, "fixed.item_shop_1")
	var event_before := _slot(normal_before, "event.standing_person_1")
	var scenario_before := _slot(EnvironmentPlacementScript.surface_map(scenario_environment), "scenario.surface_item_1")
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
		"scenario.surface_item_1",
		scenario_target
	)
	_check(bool(scenario_saved.get("ok", false)), "An exact scenario-instance slot must save in its active scenario layout.")
	var rejected_unscoped_scenario := DeveloperPlacementStoreScript.save_position(
		environment,
		"slot_positions",
		"scenario.surface_item_1",
		scenario_target
	)
	_check(not bool(rejected_unscoped_scenario.get("ok", true)), "An ordinary scenario-instance slot must not save without an active scenario.")
	var rejected_unknown_scenario := DeveloperPlacementStoreScript.save_position(
		{"archetype_id": "corner_store", "scenario_id": "unknown_scenario"},
		"slot_positions",
		"scenario.surface_item_1",
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
	_check(_slot_position(_slot(scenario_local, "scenario.surface_item_1")).is_equal_approx(scenario_target), "Normal rendering must consume the active layout's locked scenario-slot edit before project promotion.")
	_check(_slot_position(_slot(normal_local, "exit.safe_right")).is_equal_approx(exit_target), "Normal rendering must consume the locked exit-slot edit before project promotion.")
	_check(_slot_position(_slot(authoring_local, "fixed.item_shop_1")).is_equal_approx(fixed_target), "Authoring view must load the local fixed-slot edit.")
	_check(_slot_position(_slot(authoring_local, "event.standing_person_1")).is_equal_approx(event_target), "Authoring view must load the local event-slot edit.")
	_check(_slot_position(_slot(scenario_authoring_local, "scenario.surface_item_1")).is_equal_approx(scenario_target), "Authoring view must load the local scenario-instance edit.")
	_check(_slot_position(_slot(authoring_local, "exit.safe_right")).is_equal_approx(exit_target), "Authoring view must load the local exit-slot edit.")
	_check(_translated_geometry(fixed_before, _slot(authoring_local, "fixed.item_shop_1"), fixed_target - _slot_position(fixed_before)), "Moving a slot must rigidly translate pos, hit_rect, and label_anchor without resizing it.")
	var other_scenario_environment := {
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_inventory_night",
		"scenario_state": {"id": "corner_store_inventory_night"},
	}
	_check(
		not _slot_position(_slot(EnvironmentPlacementScript.surface_map(other_scenario_environment), "scenario.surface_item_1")).is_equal_approx(scenario_target),
		"The same local scenario role ID must keep an independent coordinate in a different scenario layout."
	)

	DeveloperPlacementStoreScript.reload()
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1")).is_equal_approx(fixed_target), "Locked slot edits must survive a durable reload in normal rendering.")
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(scenario_environment), "scenario.surface_item_1")).is_equal_approx(scenario_target), "Scenario-layout edits must survive a durable reload in their exact context.")
	var other_environment := {"archetype_id": "bar"}
	_check(_slot(EnvironmentPlacementScript.authoring_surface_map(other_environment), "fixed.item_shop_1").is_empty(), "A slot edit must not leak into another environment.")
	var no_catalog_environment := {"archetype_id": "house"}
	var no_catalog_slot := _slot(EnvironmentPlacementScript.surface_map(no_catalog_environment), "scenario.surface_item_1")
	var no_catalog_target := _slot_position(no_catalog_slot) + Vector2(6.0, -6.0)
	var no_catalog_saved := DeveloperPlacementStoreScript.save_position(
		no_catalog_environment,
		"slot_positions",
		"scenario.surface_item_1",
		no_catalog_target
	)
	_check(
		bool(no_catalog_saved.get("ok", false))
			and str(no_catalog_saved.get("scope", "")) == "shared"
			and _slot_position(_slot(EnvironmentPlacementScript.surface_map(no_catalog_environment), "scenario.surface_item_1")).is_equal_approx(no_catalog_target),
		"Scenario-family capacity on a map with no catalog scenarios must remain room-scoped and movable in its sole base context."
	)
	DeveloperPlacementStoreScript.clear_position(no_catalog_environment, "slot_positions", "scenario.surface_item_1")

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
			and int(exported.get("room_count", 0)) == 2
			and int(exported.get("slot_count", 0)) == 5
			and FileAccess.file_exists(report_path),
		"Export Placement Report must create a shareable five-change snapshot at the requested writable path."
	)
	var report_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var report_rooms: Dictionary = (report_data as Dictionary).get("rooms", {}) if typeof(report_data) == TYPE_DICTIONARY else {}
	var corner_report: Dictionary = report_rooms.get("corner_store", {})
	var corner_slots: Dictionary = corner_report.get("slot_positions", {})
	var corner_layouts: Dictionary = corner_report.get("scenario_layouts", {})
	var lotto_report: Dictionary = corner_layouts.get("corner_store_lotto_fever", {})
	var lotto_slots: Dictionary = lotto_report.get("slot_positions", {})
	var club_report: Dictionary = report_rooms.get("small_underground_casino:club", {})
	var club_slots: Dictionary = club_report.get("slot_positions", {})
	var report_coverage: Dictionary = (report_data as Dictionary).get("coverage", {})
	_check(
		int((report_data as Dictionary).get("schema_version", 0)) == DeveloperPlacementStoreScript.SCHEMA_VERSION
			and not report_rooms.has("apartment")
			and _reported_position(corner_slots, "fixed.item_shop_1").is_equal_approx(fixed_target)
			and _reported_position(corner_slots, "event.standing_person_1").is_equal_approx(event_target)
			and not corner_slots.has("scenario.surface_item_1")
			and _reported_position(lotto_slots, "scenario.surface_item_1").is_equal_approx(scenario_target)
			and _reported_position(corner_slots, "exit.safe_right").is_equal_approx(exit_target)
			and _reported_position(club_slots, "fixed.door_right_lower").is_equal_approx(club_target)
			and int(report_coverage.get("expected_layout_count", 0)) == 75
			and int(report_coverage.get("saved_layout_count", -1)) == 0,
		"The schema-v3 report must separate shared and exact scenario coordinates, preserve layered room keys, and include 75-layout coverage."
	)
	_check(FileAccess.get_file_as_bytes(user_path) == user_bytes_before_export, "Exporting must not mutate or clear the active machine-local placement data.")

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
	var reexported := DeveloperPlacementStoreScript.export_user_overrides()
	var refreshed_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var refreshed_rooms: Dictionary = refreshed_report.get("rooms", {})
	var refreshed_corner: Dictionary = refreshed_rooms.get("corner_store", {})
	_check(
		bool(reexported.get("ok", false))
			and not (refreshed_corner.get("slot_positions", {}) as Dictionary).has("fixed.item_shop_1")
			and int(reexported.get("slot_count", 0)) == 4,
		"Re-exporting must replace stale report contents with the current set of local changes."
	)
	for slot_id in ["event.standing_person_1", "exit.safe_right"]:
		DeveloperPlacementStoreScript.clear_position(environment, "slot_positions", slot_id)
	DeveloperPlacementStoreScript.clear_position(scenario_environment, "slot_positions", "scenario.surface_item_1")
	DeveloperPlacementStoreScript.clear_position(club_layer, "slot_positions", "fixed.door_right_lower")
	var cleared_export := DeveloperPlacementStoreScript.export_user_overrides()
	var cleared_report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	_check(
		bool(cleared_export.get("ok", false))
			and int(cleared_export.get("room_count", -1)) == 0
			and int(cleared_export.get("slot_count", -1)) == 0
			and (cleared_report.get("rooms", {}) as Dictionary).is_empty()
			and not FileAccess.file_exists("%s.bak" % report_path),
		"Exporting after the last local reset must replace the old report with an empty current snapshot and remove its stale backup."
	)
	DeveloperPlacementStoreScript.reload()
	_check(_slot_position(_slot(EnvironmentPlacementScript.surface_map(environment), "fixed.item_shop_1")).is_equal_approx(fixed_target), "A promoted slot must survive local reset and reload.")


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
			and (house_room.get("slot_positions", {}) as Dictionary).has("scenario.surface_item_1")
			and not house_room.has("scenario_layouts"),
		"A no-catalog map's scenario-family capacity must serialize in its shared base room."
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
		not corner_shared.has("scenario.surface_item_1")
			and corner_shared.has("fixed.item_shop_1")
			and lotto_scenario_positions.has("scenario.surface_item_1")
			and bool(lotto_layout.get("saved", false)),
		"A complete scenario save must split shared room positions from exact scenario-instance positions."
	)

	var inventory_environment := {
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_inventory_night",
		"scenario_state": {"id": "corner_store_inventory_night"},
	}
	var inventory_positions := _surface_positions(EnvironmentPlacementScript.surface_map(inventory_environment))
	var inventory_original: Vector2 = inventory_positions.get("scenario.surface_item_1", Vector2.ZERO)
	inventory_positions["scenario.surface_item_1"] = inventory_original + Vector2(9.0, 7.0)
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
			and not _reported_position(lotto_scenario_positions, "scenario.surface_item_1").is_equal_approx(
				_reported_position(inventory_scenario_positions, "scenario.surface_item_1")
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
		"scenario.surface_item_1"
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
		_slot(EnvironmentPlacementScript.surface_map(inventory_environment), "scenario.surface_item_1")
	) + Vector2(2.0, 1.0)
	DeveloperPlacementStoreScript.save_position(
		inventory_environment,
		"slot_positions",
		"scenario.surface_item_1",
		temporary_inventory_position
	)
	DeveloperPlacementStoreScript.clear_position(
		inventory_environment,
		"slot_positions",
		"scenario.surface_item_1"
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
		"scenario.floor_fixture_1"
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
	custom_inventory_positions["scenario.surface_item_1"] = (
		custom_inventory_positions.get("scenario.surface_item_1", Vector2.ZERO) as Vector2
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
		"scenario.surface_item_1",
		custom_inventory_positions.get("scenario.surface_item_1", Vector2.ZERO)
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
		"scenario.surface_item_1"
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
	canvas.developer_placement_lock_requested.connect(_capture_lock_request)
	canvas.developer_placement_export_requested.connect(_capture_export_request)
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
	canvas.set_developer_slot_placement_mode(true)
	await process_frame
	_check(canvas.developer_placement_export_button != null and canvas.developer_placement_export_button.text == "Export Placement Report", "The placement overlay must expose an explicit EXE-safe report action.")
	canvas.developer_placement_export_button.pressed.emit()
	_check(export_request_count == 1, "Export Placement Report must work without requiring a selected slot or pending move.")
	var snapshot: Dictionary = canvas.developer_slot_placement_snapshot()
	_check(bool(snapshot.get("enabled", false)) and int(snapshot.get("visible_slot_count", 0)) > 0, "Slot mode must expose occupied or required slots in its default preview.")
	var filters: Dictionary = snapshot.get("family_filters", {})
	_check(
		filters.keys().size() == 4 and bool(filters.get("fixed", false)) \
			and not bool(filters.get("event", true)) and not bool(filters.get("scenario", true)) and not bool(filters.get("exit", true)),
		"Slot mode must open on the Fixed family alone instead of displaying all four families."
	)
	_check(not bool(snapshot.get("show_empty_capacity", true)) and not bool(snapshot.get("show_runtime_reserves", true)), "Empty capacity and runtime reserves must be hidden by default.")
	_check(int(snapshot.get("visible_slot_count", 0)) < int(snapshot.get("total_slot_count", 0)), "The default occupied preview must not flood the room with every authored capacity slot.")
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
	canvas.render_environment_snapshot(corner_snapshot)
	canvas.set_developer_slot_family_visible("event", true)
	var filtered_snapshot := canvas.developer_slot_placement_snapshot()
	filters = filtered_snapshot.get("family_filters", {})
	_check(
		str(filtered_snapshot.get("active_family", "")) == "event" and bool(filters.get("event", false)) and not bool(filters.get("fixed", true)),
		"Selecting a family tab must replace the prior family instead of accumulating overlay clutter."
	)
	_check(int(filtered_snapshot.get("visible_slot_count", -1)) == 0, "An event family with no active occupants must stay empty until capacity is explicitly requested.")
	canvas.set_developer_slot_show_empty_capacity(true)
	_check(int(canvas.developer_slot_placement_snapshot().get("visible_slot_count", 0)) > 0, "The Empty capacity toggle must reveal unused slots in the active family.")
	_check(not bool(canvas.developer_placement_snapshot().get("enabled", true)), "Enabling slot mode must disable spawned-object placement mode.")
	var wrapped_label: Array = canvas.call("_wrap_developer_slot_label", "scenario.wall_item_1", ThemeDB.fallback_font, 8, 42.0)
	_check(wrapped_label.size() > 1 and "".join(wrapped_label) == "scenario.wall_item_1", "Slot overlay labels must wrap onto multiple rows without truncating their stable IDs.")
	var fixed_slot: Dictionary = canvas.call("_developer_slot", "fixed.item_shop_1")
	_check(str(canvas.call("_developer_slot_primary_label", fixed_slot)) == "Fixture", "Occupied slot labels must lead with the friendly occupant name instead of the raw stable ID.")
	var future_phase_slot: Dictionary = canvas.call("_developer_slot", "scenario.surface_item_1")
	_check(
		str(canvas.call("_developer_slot_primary_label", future_phase_slot)) == "Economy Stock Public Service",
		"An unoccupied exact scenario slot must identify its future claimant instead of displaying only a generic physical class."
	)
	var alternate_phase_fixture := {
		"id": "scenario.floor_fixture_1",
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
		"id": "scenario.surface_item_1",
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
	_check(str(canvas.call("_developer_slot_capacity_label", reserve_fixture)) == "Delivery Contact Reserve", "Empty slot labels must prefer the authored physical role over legacy slot-name wording.")
	_check((canvas.call("_developer_slot_known_claimants", reserve_fixture) as Array).has("runtime:delivery_contact"), "Known slot claimants must remain available in placement details without replacing an active occupant label.")

	canvas.set_developer_slot_family_visible("scenario", true)
	var slot: Dictionary = canvas.call("_developer_slot", "scenario.surface_item_1")
	_check(not slot.is_empty(), "All-capacity mode must include empty scenario slots by stable ID.")
	if not slot.is_empty():
		var rect: Rect2 = canvas.call("_developer_slot_rect", slot)
		var selected_id := str(canvas.call("_developer_slot_id_at_local_position", rect.get_center()))
		_check(selected_id == "scenario.surface_item_1", "An empty overlay slot must be directly selectable.")
		canvas.call("_begin_developer_slot_placement_drag", rect.get_center())
		var target_top_left := rect.position + Vector2(12.0, 8.0)
		canvas.call("_update_developer_slot_placement_preview", target_top_left)
		snapshot = canvas.developer_slot_placement_snapshot()
		var request: Dictionary = snapshot.get("request", {})
		_check(bool(snapshot.get("pending", false)) and bool(snapshot.get("valid", false)), "Dragging a slot must expose a valid live preview.")
		for overlap_id_value in snapshot.get("overlap_ids", []):
			var overlap_slot: Dictionary = canvas.call("_developer_slot", str(overlap_id_value))
			_check(bool(canvas.call("_developer_slot_is_context_active", overlap_slot)), "Overlap diagnostics must ignore mutually exclusive empty capacity outside the active preview.")
		_check(str(request.get("field", "")) == "slot_positions" and str(request.get("slot_id", "")) == "scenario.surface_item_1", "A slot edit request must retain reusable slot identity.")
		canvas.developer_placement_export_button.pressed.emit()
		_check(str(exported_pending_request.get("slot_id", "")) == "scenario.surface_item_1", "Export must carry the selected reusable slot edit to the host before writing the report.")
		_check(export_request_count == 2 and not bool(canvas.developer_slot_placement_snapshot().get("pending", true)), "Export must request the report only after retaining the current pending slot move.")

	locked_requests.clear()
	var nudge_slot: Dictionary = canvas.call("_developer_slot", "scenario.surface_item_1")
	var next_slot: Dictionary = canvas.call("_developer_slot", "scenario.standing_person_2")
	if not nudge_slot.is_empty() and not next_slot.is_empty():
		canvas.developer_slot_selected_id = "scenario.surface_item_1"
		var right_key := InputEventKey.new()
		right_key.keycode = KEY_RIGHT
		right_key.pressed = true
		canvas.call("_handle_developer_slot_placement_input", right_key)
		_check(bool(canvas.developer_slot_placement_snapshot().get("pending", false)), "A keyboard nudge must create a pending slot edit.")
		var next_slot_rect: Rect2 = canvas.call("_developer_slot_rect", next_slot)
		canvas.call("_begin_developer_slot_placement_drag", next_slot_rect.get_center())
		_check(
			locked_requests.size() == 1
				and str(locked_requests[0].get("slot_id", "")) == "scenario.surface_item_1"
				and str(canvas.developer_slot_placement_snapshot().get("selected_slot_id", "")) == "scenario.standing_person_2",
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
				and str(locked_requests[1].get("slot_id", "")) == "scenario.standing_person_2"
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
