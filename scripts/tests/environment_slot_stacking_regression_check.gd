extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_collision_reassignment()
	_test_shared_occupancy_reassignment()
	_test_capacity_failure_never_overflows()
	_test_persisted_duplicate_rejected()
	_test_presentation_alias_replaces_source()
	_test_family_isolation()
	_test_renderer_suppresses_duplicate_slot()
	if _failures.is_empty():
		print("ENVIRONMENT STACKING CHECK cases=7 duplicate_slots=0 overflow=0 family_crossovers=0 ok=true")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_collision_reassignment() -> void:
	var first := _slot("event.surface_item_1", "event", "surface_item", 10)
	var second := _slot("event.surface_item_2", "event", "surface_item", 20)
	var result := EnvironmentSlotBinderScript.guard_unique_slot_bindings({
		"alpha": _binding("alpha", first),
		"beta": _binding("beta", first),
	}, {}, {}, [first, second], "stacking regression")
	_check(_array(result.get("errors", [])).is_empty(), "A duplicate slot with spare capacity produced an error.")
	var bindings := _dict(result.get("slot_bindings", {}))
	_check(str(_dict(bindings.get("alpha", {})).get("slot_id", "")) == "event.surface_item_1", "The deterministic first occupant did not retain its slot.")
	_check(str(_dict(bindings.get("beta", {})).get("slot_id", "")) == "event.surface_item_2", "The later occupant was not reassigned to the free compatible slot.")
	_assert_unique(bindings, "collision reassignment")


func _test_shared_occupancy_reassignment() -> void:
	var first := _slot("scenario.surface_item_1", "scenario", "surface_item", 10)
	var second := _slot("scenario.surface_item_2", "scenario", "surface_item", 20)
	var result := EnvironmentSlotBinderScript.guard_unique_slot_bindings(
		{"late": _binding("late", first)},
		{},
		{"scenario.surface_item_1": "earlier"},
		[first, second],
		"shared occupancy regression"
	)
	var bindings := _dict(result.get("slot_bindings", {}))
	_check(str(_dict(bindings.get("late", {})).get("slot_id", "")) == "scenario.surface_item_2", "A later binding reused a slot held by an earlier pass.")
	_check(str(_dict(result.get("occupied_slots", {})).get("scenario.surface_item_1", "")) == "earlier", "The earlier shared-occupancy claim was overwritten.")


func _test_capacity_failure_never_overflows() -> void:
	var only_slot := _slot("event.surface_item_1", "event", "surface_item", 10)
	var result := EnvironmentSlotBinderScript.guard_unique_slot_bindings(
		{"late": _binding("late", only_slot)},
		{},
		{"event.surface_item_1": "earlier"},
		[only_slot],
		"capacity regression"
	)
	_check(not _array(result.get("errors", [])).is_empty(), "A room with no compatible free slot did not fail closed.")
	_check(not _dict(result.get("slot_bindings", {})).has("late"), "An unplaceable object retained a stacked room binding.")
	_check(_array(result.get("overflow_ids", [])).is_empty(), "An unplaceable object was routed to removed overflow UI.")


func _test_persisted_duplicate_rejected() -> void:
	var environment := {"archetype_id": "back_alley"}
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var slot := _authored_slot(surface_map, "fixed.random_game_1")
	_check(not slot.is_empty(), "Back Alley stacking regression slot is missing.")
	if slot.is_empty():
		return
	var bindings := {
		"alpha": _binding("alpha", slot),
		"beta": _binding("beta", slot),
	}
	environment["layout"] = _authority(surface_map, bindings)
	var result := EnvironmentSlotBinderScript.validate_base_layout_authority(environment, [], true)
	_check(not bool(result.get("ok", true)), "Persisted duplicate slot authority was accepted.")
	_check(JSON.stringify(result.get("errors", [])).contains("multiple live identities"), "Persisted duplicate rejection did not identify the shared slot.")


func _test_presentation_alias_replaces_source() -> void:
	var environment := {"archetype_id": "back_alley"}
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var slot := _authored_slot(surface_map, "fixed.random_game_1")
	_check(not slot.is_empty(), "Back Alley alias regression slot is missing.")
	if slot.is_empty():
		return
	var source_id := "home_container:test"
	var alias_id := "meta_container:test"
	var source_bindings := {source_id: _binding(source_id, slot)}
	environment["layout"] = _authority(surface_map, source_bindings)
	var records := [{
		"object_id": alias_id,
		"object_type": "home_container",
		"visual_type": "home_container",
		"slot_binding_source_id": source_id,
		"family": "fixed",
		"placement_class": "floor_fixture",
		"active": true,
		"visible": true,
		"interactive": true,
	}]
	var result := EnvironmentSlotBinderScript.bind_base_records(environment, records, source_bindings, {})
	_check(bool(result.get("ok", false)), "A presentation alias could not take ownership of its source slot: %s" % JSON.stringify(result.get("errors", [])))
	var bindings := _dict(result.get("slot_bindings", {}))
	_check(not bindings.has(source_id), "A presentation alias left its source identity occupying the same slot.")
	_check(str(_dict(bindings.get(alias_id, {})).get("slot_id", "")) == str(slot.get("id", "")), "A presentation alias did not inherit the source slot.")
	_assert_unique(bindings, "presentation alias replacement")


func _test_family_isolation() -> void:
	var fixed_slot := _slot("fixed.surface_item_1", "fixed", "surface_item", 10)
	var event_slot := _slot("event.floor_item_1", "event", "floor_fixture", 20)
	var cross_family_binding := _binding("event_probe", fixed_slot)
	cross_family_binding["kind"] = "event"
	cross_family_binding["slot_family"] = "event"
	var result := EnvironmentSlotBinderScript.guard_unique_slot_bindings(
		{"event_probe": cross_family_binding},
		{},
		{},
		[fixed_slot, event_slot],
		"family isolation regression"
	)
	_check(not _array(result.get("errors", [])).is_empty(), "A binding whose declared family disagreed with its slot did not fail closed.")
	_check(not _dict(result.get("slot_bindings", {})).has("event_probe"), "A cross-family binding survived finalization.")

	var bound := EnvironmentSlotBinderScript.bind_base_layout({"archetype_id": "bar"}, [{
		"object_id": "event:family_isolation_probe",
		"object_type": "event",
		"visual_prop": "room_surface",
		"family": "event",
		"placement_class": "surface_item",
		"exact_slot_id": "fixed.random_game_1",
		"required": true,
		"active": true,
	}])
	_check(not bool(bound.get("ok", true)), "An event object borrowed compatible capacity from the fixed family.")
	_check(not _dict(bound.get("slot_bindings", {})).has("event:family_isolation_probe"), "An event object received a fixed-family slot.")


func _test_renderer_suppresses_duplicate_slot() -> void:
	var canvas: Variant = PixelSceneCanvasScript.new()
	var common := {
		"object_type": "prop",
		"visual_type": "prop",
		"slot_id": "fixed.surface_item_1",
		"slot_family": "fixed",
		"presentation_mode": "room",
		"visible": true,
		"normalized_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1},
	}
	var alpha := common.duplicate(true)
	alpha["object_id"] = "alpha"
	var beta := common.duplicate(true)
	beta["object_id"] = "beta"
	var objects: Array = canvas.call("_objects_from_interactable_records", [alpha, beta])
	_check(objects.size() == 1 and str(_dict(objects[0]).get("id", "")) == "alpha", "The render boundary accepted two objects in one slot.")
	canvas.free()


func _authority(surface_map: Dictionary, bindings: Dictionary) -> Dictionary:
	var object_rects: Dictionary = {}
	for identity_value in bindings.keys():
		var identity := str(identity_value)
		object_rects[identity] = EnvironmentSlotBinderScript.normalized_rect(
			EnvironmentSlotBinderScript.rect_from_binding(_dict(bindings.get(identity_value, {})))
		)
	return {
		"slot_schema_version": EnvironmentSlotBinderScript.SLOT_SCHEMA_VERSION,
		"slot_map_digest": EnvironmentSlotBinderScript.slot_map_digest(surface_map),
		"slot_binding_digest": EnvironmentSlotBinderScript.binding_digest(bindings),
		"slot_bindings": bindings.duplicate(true),
		"slot_overflow_ids": [],
		"object_rects": object_rects,
	}


func _slot(slot_id: String, family: String, placement_class: String, priority: int) -> Dictionary:
	return {
		"id": slot_id,
		"kind": family,
		"pos": [100.0 + priority, 100.0],
		"footprint_class": placement_class,
		"hit_rect": [80.0 + priority, 60.0, 72.0, 48.0],
		"label_anchor": [116.0 + priority, 52.0],
		"facing": "none",
		"priority": priority,
		"zone_id": "room",
		"support_id": "test",
		"walk_lane_ids": [],
	}


func _binding(identity: String, slot: Dictionary) -> Dictionary:
	var family := str(slot.get("kind", ""))
	return {
		"identity": identity,
		"kind": family,
		"slot_family": family,
		"presentation_mode": "room",
		"slot_id": str(slot.get("id", "")),
		"placement_class": str(slot.get("footprint_class", "")),
		"slot": slot.duplicate(true),
	}


func _authored_slot(surface_map: Dictionary, slot_id: String) -> Dictionary:
	for collection_value in [surface_map.get("fixed_slots", []), surface_map.get("event_slots", []), surface_map.get("scenario_slots", []), surface_map.get("exit_slots", [])]:
		for slot_value in _array(collection_value):
			var slot := _dict(slot_value)
			if str(slot.get("id", "")) == slot_id:
				return slot
	return {}


func _assert_unique(bindings: Dictionary, label: String) -> void:
	var occupied: Dictionary = {}
	for identity_value in bindings.keys():
		var identity := str(identity_value)
		var binding := _dict(bindings.get(identity_value, {}))
		if str(binding.get("presentation_mode", "")) != "room":
			continue
		var slot_id := str(binding.get("slot_id", "")).strip_edges()
		if occupied.has(slot_id) and str(occupied.get(slot_id, "")) != identity:
			_failures.append("%s stacked %s and %s in %s." % [label, str(occupied.get(slot_id, "")), identity, slot_id])
		else:
			occupied[slot_id] = identity


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []
