extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")

const PLACEMENT_PATH := "res://data/environments/placement_surfaces.json"
const LAYOUT_PATH := "res://data/environments/scenario_slot_layouts.json"
const CONDITIONAL_OBJECTS := {
	"pawn_shop::pawn_shop_estate_lot_day": ["event:chain06_sal_estate_item"],
	"motel::motel_weekly_rates": [
		"event:chain06_nico_weekly_door",
		"event:chain06_nico_what_it_covers",
	],
	"jazz_club::jazz_club_rent_party": ["event:chain06_trio_rent_payoff"],
	"gas_station_casino::gas_station_trucker_convoy": ["event:recruitment_switch"],
	"back_alley::back_alley_fence_night": ["event:recruitment_mags"],
	"bar::bar_fight_night": ["event:recruitment_knuckles"],
	"kitty_cat_lounge::kitty_cat_lounge_buyout": ["event:recruitment_velvet"],
	"kitty_cat_lounge::kitty_cat_lounge_slow_night": ["event:recruitment_velvet"],
	"beach::beach_festival_weekend": ["event:recruitment_lucky"],
}

var failures: Array[String] = []
var base_context_count := 0
var scenario_context_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var placement := _read_json(PLACEMENT_PATH)
	var authority := _read_json(LAYOUT_PATH)
	var maps := _rows_by_id(_array(placement.get("maps", [])), "id")
	var layouts := _rows_by_id(_array(authority.get("layouts", [])), "layout_id")
	var catalog_map_ids := _string_set(_array(authority.get("maps_with_catalog_scenarios", [])))
	_check(int(authority.get("layout_count", -1)) == 55, "authority must declare 55 scenario contexts")
	_check(layouts.size() == 55, "authority must contain 55 unique scenario layouts")
	_check(maps.size() == 21, "placement authority must contain 21 unique base maps")
	_check(_array(authority.get("base_layout_ids", [])).size() == 20, "authority must declare 20 reachable base contexts")
	_check(
		_array(authority.get("template_map_ids", [])) == ["small_underground_casino"],
		"authority must identify the unreachable layered Punchline parent as template-only"
	)

	for map_id_value in _array(authority.get("base_layout_ids", [])):
		_check_base_context(str(map_id_value), _dict(maps.get(str(map_id_value), {})), catalog_map_ids)
	for layout_value in _array(authority.get("layouts", [])):
		_check_scenario_context(_dict(layout_value), maps)
	_check_layer_scoped_scenario_cursor(maps)
	_check_conditional_runtime_ownership(layouts)
	_check_fail_closed_binding()
	_check_complete_manual_save_and_export(authority)

	_check(base_context_count == 20, "runtime sweep did not visit all 20 reachable base contexts")
	_check(scenario_context_count == 55, "runtime sweep did not visit all 55 scenario contexts")
	if failures.is_empty():
		print("SCENARIO_SLOT_LAYOUT_RUNTIME_CHECK PASS base=20 scenarios=55 contexts=75")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_base_context(map_id: String, base_map: Dictionary, catalog_map_ids: Dictionary) -> void:
	base_context_count += 1
	var environment := _environment_for_map(map_id)
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var label := "%s::base" % map_id
	_check(not base_map.is_empty(), "%s has no source placement map" % label)
	_check(str(surface.get("id", "")) == map_id, "%s resolved the wrong runtime map" % label)
	var validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
	_check(bool(validation.get("ok", false)), "%s runtime map is invalid: %s" % [label, JSON.stringify(validation.get("errors", []))])
	if not catalog_map_ids.has(map_id):
		return

	var reserve_ids := _runtime_reserve_ids(base_map)
	var runtime_scenario_slots := _array(surface.get("scenario_slots", []))
	var runtime_ids := _slot_ids(runtime_scenario_slots)
	_check(bool(surface.get("scenario_layout_scoped", false)), "%s is not scenario-layout scoped" % label)
	_check(str(surface.get("scenario_layout_id", "")) == label, "%s has the wrong base layout id" % label)
	_check(runtime_ids == reserve_ids, "%s did not remove its ordinary catalog scenario markers" % label)
	for slot_value in runtime_scenario_slots:
		var slot := _dict(slot_value)
		_check(bool(slot.get("runtime_reserve", false)), "%s retained ordinary no-scenario marker %s" % [label, str(slot.get("id", ""))])
	_check(_dict(surface.get("scenario_instance_slot_ids", {})).is_empty(), "%s leaked semantic instance mappings" % label)
	_check(_dict(surface.get("scenario_instance_object_slot_ids", {})).is_empty(), "%s leaked object instance mappings" % label)
	_check(_dict(surface.get("scenario_slot_ids", {})).is_empty(), "%s leaked ordinary scenario preferences" % label)
	for field in ["scenario_object_slot_ids", "scenario_category_slot_ids"]:
		for slot_id_value in _dict(surface.get(field, {})).values():
			_check(reserve_ids.has(str(slot_id_value)), "%s %s points outside runtime reserves" % [label, field])


func _check_scenario_context(layout: Dictionary, maps: Dictionary) -> void:
	scenario_context_count += 1
	var map_id := str(layout.get("map_id", "")).strip_edges()
	var scenario_id := str(layout.get("scenario_id", "")).strip_edges()
	var layout_id := "%s::%s" % [map_id, scenario_id]
	var base_map := _dict(maps.get(map_id, {}))
	var surface := EnvironmentPlacementScript.surface_map(_environment_for_map(map_id, scenario_id))
	_check(not base_map.is_empty(), "%s has no source placement map" % layout_id)
	_check(str(layout.get("layout_id", "")) == layout_id, "%s has a noncanonical authority id" % layout_id)
	_check(str(surface.get("id", "")) == map_id, "%s resolved the wrong runtime map" % layout_id)
	_check(bool(surface.get("scenario_layout_scoped", false)), "%s is not scoped at runtime" % layout_id)
	_check(str(surface.get("scenario_layout_id", "")) == layout_id, "%s selected the wrong runtime layout" % layout_id)
	_check(str(surface.get("scenario_layout_scenario_id", "")) == scenario_id, "%s lost its scenario identity" % layout_id)

	var validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
	_check(bool(validation.get("ok", false)), "%s runtime map is invalid: %s" % [layout_id, JSON.stringify(validation.get("errors", []))])
	var local_slots := _slots_by_id(_array(layout.get("scenario_slots", [])))
	var reserve_ids := _runtime_reserve_ids(base_map)
	var expected_ids := reserve_ids.duplicate(true)
	for slot_id_value in local_slots.keys():
		expected_ids[str(slot_id_value)] = true
	var runtime_slots := _slots_by_id(_array(surface.get("scenario_slots", [])))
	_check(_string_set(runtime_slots.keys()) == expected_ids, "%s runtime slots are not exact-layout plus reserves" % layout_id)
	for slot_id_value in local_slots.keys():
		var slot_id := str(slot_id_value)
		var runtime_slot := _dict(runtime_slots.get(slot_id, {}))
		_check(not runtime_slot.is_empty(), "%s is missing local slot %s" % [layout_id, slot_id])
		_check(not bool(runtime_slot.get("runtime_reserve", false)), "%s local slot %s became a runtime reserve" % [layout_id, slot_id])
		_check(str(runtime_slot.get("scenario_id", "")) == scenario_id, "%s local slot %s belongs to another scenario" % [layout_id, slot_id])
	for reserve_id_value in reserve_ids.keys():
		var reserve_id := str(reserve_id_value)
		_check(bool(_dict(runtime_slots.get(reserve_id, {})).get("runtime_reserve", false)), "%s lost reserve status for %s" % [layout_id, reserve_id])

	var semantic_preferences := _dict(layout.get("scenario_instance_slot_ids", {}))
	var object_preferences := _dict(layout.get("scenario_instance_object_slot_ids", {}))
	_check(_same_mapping(_dict(surface.get("scenario_instance_slot_ids", {})), semantic_preferences), "%s semantic exact mappings changed at runtime" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_instance_object_slot_ids", {})), object_preferences), "%s object exact mappings changed at runtime" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_slot_ids", {})), semantic_preferences), "%s compatibility semantic view is not exact" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_object_slot_ids", {})), object_preferences), "%s compatibility object view is not exact" % layout_id)
	for slot_id_value in semantic_preferences.values():
		var slot_id := str(slot_id_value)
		_check(local_slots.has(slot_id) and not reserve_ids.has(slot_id), "%s semantic mapping targets nonlocal slot %s" % [layout_id, slot_id])
	for object_id_value in object_preferences.keys():
		var object_id := str(object_id_value)
		var slot_id := str(object_preferences.get(object_id_value, ""))
		_check(local_slots.has(slot_id) and not reserve_ids.has(slot_id), "%s object %s targets nonlocal slot %s" % [layout_id, object_id, slot_id])
		_check(str(_dict(surface.get("object_family_ids", {})).get(object_id, "")) == "scenario", "%s object %s is not scenario-owned" % [layout_id, object_id])
		for family in ["fixed", "event", "exit"]:
			_check(not _dict(surface.get("%s_object_slot_ids" % family, {})).has(object_id), "%s object %s retained stale %s ownership" % [layout_id, object_id, family])
		for declaration_value in _array(surface.get("fixed_objects", [])):
			_check(str(_dict(declaration_value).get("object_id", "")) != object_id, "%s object %s retained a fixed declaration" % [layout_id, object_id])


func _check_layer_scoped_scenario_cursor(maps: Dictionary) -> void:
	var scenario_id := "punchline_open_mic_night"
	var retained_state := {
		"id": scenario_id,
		"archetype_id": "small_underground_casino",
		"layer_id": "club",
	}
	var casino_environment := {
		"archetype_id": "small_underground_casino",
		"current_layer_id": "casino",
		"scenario_id": scenario_id,
		"scenario_state": retained_state,
	}
	var casino_surface := EnvironmentPlacementScript.surface_map(casino_environment)
	var casino_base := _dict(maps.get("small_underground_casino:casino", {}))
	_check(
		EnvironmentPlacementScript.active_scenario_id(casino_environment).is_empty(),
		"a club-scoped scenario cursor remained active on the casino floor"
	)
	_check(
		str(casino_surface.get("scenario_layout_id", "")) == "small_underground_casino:casino::base",
		"a retained club scenario did not resolve the casino floor's base placement layout"
	)
	_check(
		_slot_ids(_array(casino_surface.get("scenario_slots", []))) == _runtime_reserve_ids(casino_base),
		"a retained club scenario exposed ordinary generic scenario capacity on the casino floor"
	)
	_check(
		_dict(casino_surface.get("scenario_instance_slot_ids", {})).is_empty(),
		"a retained club scenario leaked exact scenario mappings onto the casino floor"
	)

	var club_environment := casino_environment.duplicate(true)
	club_environment["current_layer_id"] = "club"
	var club_surface := EnvironmentPlacementScript.surface_map(club_environment)
	_check(
		EnvironmentPlacementScript.active_scenario_id(club_environment) == scenario_id,
		"a layer-scoped scenario was not active on its target club floor"
	)
	_check(
		str(club_surface.get("scenario_layout_id", "")) == "small_underground_casino:club::%s" % scenario_id,
		"the target club floor did not resolve its exact scenario placement layout"
	)


func _check_conditional_runtime_ownership(layouts: Dictionary) -> void:
	for layout_id_value in CONDITIONAL_OBJECTS.keys():
		var layout_id := str(layout_id_value)
		var layout := _dict(layouts.get(layout_id, {}))
		var map_id := str(layout.get("map_id", ""))
		var scenario_id := str(layout.get("scenario_id", ""))
		var surface := EnvironmentPlacementScript.surface_map(_environment_for_map(map_id, scenario_id))
		var object_preferences := _dict(surface.get("scenario_instance_object_slot_ids", {}))
		var family_ids := _dict(surface.get("object_family_ids", {}))
		for object_id_value in _array(CONDITIONAL_OBJECTS.get(layout_id, [])):
			var object_id := str(object_id_value)
			_check(object_preferences.has(object_id), "%s is missing conditional object %s" % [layout_id, object_id])
			_check(str(family_ids.get(object_id, "")) == "scenario", "%s conditional object %s is not scenario-owned" % [layout_id, object_id])
			for family in ["fixed", "event", "exit"]:
				_check(not _dict(surface.get("%s_object_slot_ids" % family, {})).has(object_id), "%s conditional object %s retained %s ownership" % [layout_id, object_id, family])


func _check_fail_closed_binding() -> void:
	var environment := _environment_for_map("back_alley", "back_alley_cruiser_parked")
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var valid_identity := "scenario::back_alley_cruiser_parked_exit"
	var valid := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, [{
		"identity": valid_identity,
		"semantic": {
			"present": true,
			"stable_object_id": "back_alley_cruiser_parked_exit",
		},
		"actor": false,
		"safe_exit": true,
		"placement_class": "doorway",
	}])
	_check(bool(valid.get("ok", false)), "known exact scenario mapping failed to bind: %s" % JSON.stringify(valid.get("errors", [])))
	var valid_binding := _dict(_dict(valid.get("slot_bindings", {})).get(valid_identity, {}))
	var expected_slot_id := str(_dict(surface.get("scenario_instance_slot_ids", {})).get("back_alley_cruiser_parked_exit", ""))
	_check(str(valid_binding.get("slot_id", "")) == expected_slot_id, "known exact scenario mapping bound the wrong slot")
	_check(not bool(_dict(_slots_by_id(_array(surface.get("scenario_slots", []))).get(expected_slot_id, {})).get("runtime_reserve", false)), "known exact scenario mapping fell into a reserve")

	var invented_identity := "scenario::__unmapped_runtime_actor"
	var rejected := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, [{
		"identity": invented_identity,
		"semantic": {
			"present": true,
			"stable_object_id": "__unmapped_runtime_actor",
		},
		"actor": true,
		"placement_class": "standing_person",
	}])
	_check(not bool(rejected.get("ok", true)), "unmapped scenario visual did not fail closed")
	_check(not _dict(rejected.get("slot_bindings", {})).has(invented_identity), "unmapped scenario visual received a fallback binding")
	_check(_array(rejected.get("occupied_slot_ids", [])).is_empty(), "unmapped scenario visual consumed scenario reserve capacity")
	var named_error := false
	for error_value in _array(rejected.get("errors", [])):
		if str(error_value).contains("no exact slot instance"):
			named_error = true
	_check(named_error, "unmapped scenario visual did not report missing exact authority")


func _check_complete_manual_save_and_export(authority: Dictionary) -> void:
	var temp_root := ProjectSettings.globalize_path("res://.tmp/scenario_slot_layout_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	var user_path := temp_root.path_join("user.json")
	var project_path := temp_root.path_join("project.json")
	var report_path := temp_root.path_join("report.json")
	for path in [user_path, "%s.bak" % user_path, project_path, "%s.bak" % project_path, report_path, "%s.bak" % report_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var project_file := FileAccess.open(project_path, FileAccess.WRITE)
	project_file.store_string(JSON.stringify({
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {},
	}, "\t"))
	project_file.close()
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, user_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, project_path)
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, report_path)
	DeveloperPlacementStoreScript.reload()
	var template_environment := _environment_for_map("small_underground_casino")
	var rejected_template := DeveloperPlacementStoreScript.save_layout(
		template_environment,
		_surface_positions(EnvironmentPlacementScript.surface_map(template_environment))
	)
	_check(
		not bool(rejected_template.get("ok", true)),
		"the unreachable layered Punchline parent was accepted as a manual base layout"
	)

	var expected_exported_slot_count := 0
	for map_id_value in _array(authority.get("base_layout_ids", [])):
		var map_id := str(map_id_value)
		var environment := _environment_for_map(map_id)
		var positions := _surface_positions(EnvironmentPlacementScript.surface_map(environment))
		expected_exported_slot_count += positions.size()
		var result := DeveloperPlacementStoreScript.save_layout(
			environment,
			positions
		)
		_check(bool(result.get("ok", false)), "%s::__base failed the complete manual save: %s" % [map_id, str(result.get("error", ""))])
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", ""))
		var scenario_id := str(layout.get("scenario_id", ""))
		expected_exported_slot_count += _array(layout.get("scenario_slots", [])).size()
		var environment := _environment_for_map(map_id, scenario_id)
		var result := DeveloperPlacementStoreScript.save_layout(
			environment,
			_surface_positions(EnvironmentPlacementScript.surface_map(environment))
		)
		_check(bool(result.get("ok", false)), "%s failed the complete manual save: %s" % [str(layout.get("layout_id", "")), str(result.get("error", ""))])

	var coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	_check(
		bool(coverage.get("complete", false))
			and int(coverage.get("expected_layout_count", -1)) == 75
			and int(coverage.get("saved_layout_count", -1)) == 75
			and _array(coverage.get("missing_layout_ids", [])).is_empty(),
		"the simulated owner pass did not reach complete 75/75 coverage"
	)
	var exported := DeveloperPlacementStoreScript.export_user_overrides()
	_check(
		bool(exported.get("ok", false))
			and bool(exported.get("complete", false))
			and int(exported.get("room_count", -1)) == 20
			and int(exported.get("slot_count", -1)) == expected_exported_slot_count
			and FileAccess.file_exists(report_path),
		"the complete owner pass did not export 20 rooms and %d scoped positions" % expected_exported_slot_count
	)
	var report := _read_json(report_path)
	var rooms := _dict(report.get("rooms", {}))
	for map_id_value in _array(authority.get("base_layout_ids", [])):
		var map_id := str(map_id_value)
		_check(bool(_dict(rooms.get(map_id, {})).get("base_saved", false)), "%s report lost base completion" % map_id)
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", ""))
		var scenario_id := str(layout.get("scenario_id", ""))
		var saved_layout := _dict(_dict(_dict(rooms.get(map_id, {})).get("scenario_layouts", {})).get(scenario_id, {}))
		_check(bool(saved_layout.get("saved", false)), "%s report lost scenario completion" % str(layout.get("layout_id", "")))
		_check(
			_dict(saved_layout.get("slot_positions", {})).size() == _array(layout.get("scenario_slots", [])).size(),
			"%s report did not preserve every local scenario coordinate" % str(layout.get("layout_id", ""))
		)

	var shared_edit := DeveloperPlacementStoreScript.save_position(
		{"archetype_id": "bar"},
		"slot_positions",
		"fixed.random_game_1",
		Vector2(75.0, 178.0)
	)
	var invalidated_coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	var invalidated_missing := _array(invalidated_coverage.get("missing_layout_ids", []))
	var expected_bar_missing: Array = ["bar::__base"]
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		if str(layout.get("map_id", "")) == "bar":
			expected_bar_missing.append(str(layout.get("layout_id", "")))
	expected_bar_missing.sort()
	_check(
		bool(shared_edit.get("ok", false))
			and invalidated_missing == expected_bar_missing
			and int(invalidated_coverage.get("saved_layout_count", -1)) == 75 - expected_bar_missing.size(),
		"editing shared room geometry did not invalidate the base and every previously reviewed scenario for that room"
	)

	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, "")
	DeveloperPlacementStoreScript.reload()
	for path in [user_path, "%s.bak" % user_path, project_path, "%s.bak" % project_path, report_path, "%s.bak" % report_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)


func _environment_for_map(map_id: String, scenario_id: String = "") -> Dictionary:
	var pieces := map_id.split(":", false, 1)
	var environment := {"archetype_id": str(pieces[0])}
	if pieces.size() > 1:
		environment["current_layer_id"] = str(pieces[1])
	if not scenario_id.is_empty():
		environment["scenario_id"] = scenario_id
	return environment


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _dict(parsed)


func _rows_by_id(rows: Array, id_field: String) -> Dictionary:
	var result: Dictionary = {}
	for row_value in rows:
		var row := _dict(row_value)
		var row_id := str(row.get(id_field, "")).strip_edges()
		if not row_id.is_empty():
			result[row_id] = row
	return result


func _slots_by_id(slots: Array) -> Dictionary:
	return _rows_by_id(slots, "id")


func _slot_ids(slots: Array) -> Dictionary:
	return _string_set(_slots_by_id(slots).keys())


func _runtime_reserve_ids(surface: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in _array(surface.get("scenario_slots", [])):
		var slot := _dict(slot_value)
		if bool(slot.get("runtime_reserve", false)):
			result[str(slot.get("id", ""))] = true
	return result


func _surface_positions(surface: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]:
		for slot_value in _array(surface.get(field, [])):
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			var position := _array(slot.get("pos", []))
			if not slot_id.is_empty() and position.size() >= 2:
				result[slot_id] = Vector2(float(position[0]), float(position[1]))
	return result


func _string_set(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in entries:
		result[str(value)] = true
	return result


func _same_mapping(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key_value in left.keys():
		if not right.has(key_value) or str(left.get(key_value)) != str(right.get(key_value)):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
