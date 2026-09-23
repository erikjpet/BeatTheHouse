extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const ModalFocusScopeScript := preload("res://scripts/ui/modal_focus_scope.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const RoomActionListScript := preload("res://scripts/ui/room_action_list.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	_check_map_inventory(failures)
	_check_deterministic_base_binding(failures)
	_check_slot_map_cache_invalidation(failures)
	_check_base_overflow(failures)
	_check_scenario_exit_and_overflow(failures)
	_check_authored_actor_route(failures)
	_check_complete_record_binding(failures)
	_check_shared_base_binding_aliases(failures)
	_check_overflow_action_list(failures)
	_check_semantic_classification(failures)
	if failures.is_empty():
		print("ENVIRONMENT_GROUNDING_CONTRACT_OK authority=fixed_slots maps=21 base=deterministic overflow=action_list scenario=stage_exit routes=authored")
		quit(0)
		return
	for failure_value in failures:
		printerr("ENVIRONMENT_GROUNDING_CONTRACT_FAIL %s" % str(failure_value))
	quit(1)


func _check_map_inventory(failures: Array) -> void:
	var source := FileAccess.open("res://data/environments/placement_surfaces.json", FileAccess.READ)
	if source == null:
		failures.append("placement_surfaces.json could not be opened")
		return
	var parsed: Variant = JSON.parse_string(source.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("placement_surfaces.json is not an object")
		return
	var root := parsed as Dictionary
	var maps: Array = root.get("maps", [])
	if int(root.get("schema_version", 0)) != 2 or int(root.get("slot_schema_version", 0)) != 1 or maps.size() != 21:
		failures.append("fixed-slot source does not seal schema 2 / slot schema 1 / 21 maps")
	for map_value in maps:
		var map_data: Dictionary = map_value if typeof(map_value) == TYPE_DICTIONARY else {}
		if (map_data.get("base_slots", []) as Array).is_empty() \
				or (map_data.get("stage_slots", []) as Array).is_empty() \
				or (map_data.get("exit_slots", []) as Array).size() < 2:
			failures.append("map %s has incomplete base/stage/exit capacity" % str(map_data.get("id", "")))


func _check_deterministic_base_binding(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var entries := [
		{"object_id": "travel:leave", "object_type": "travel", "spot_field": "travel_spots", "index": 0},
		{"object_id": "game:blackjack", "object_type": "game", "spot_field": "game_spots", "index": 0, "label": "Blackjack"},
		{"object_id": "service:house_drink", "object_type": "service", "spot_field": "service_spots", "index": 0, "label": "House Drink"},
	]
	var first := EnvironmentSlotBinderScript.bind_base_layout(environment, entries)
	var reversed := entries.duplicate(true)
	reversed.reverse()
	var second := EnvironmentSlotBinderScript.bind_base_layout(environment, reversed)
	if JSON.stringify(first.get("slot_bindings", {})) != JSON.stringify(second.get("slot_bindings", {})) \
			or str(first.get("binding_digest", "")) != str(second.get("binding_digest", "")):
		failures.append("base binding depends on producer order")
	for binding_value in (first.get("slot_bindings", {}) as Dictionary).values():
		var binding: Dictionary = binding_value
		if str(binding.get("presentation_mode", "")) == "room" and str(binding.get("slot_id", "")).is_empty():
			failures.append("room binding has no authored slot id")


func _check_slot_map_cache_invalidation(failures: Array) -> void:
	var environment := {
		"id": "bar_cache_fixture",
		"archetype_id": "bar",
		"layout": {},
		"game_ids": ["slot"],
		"event_ids": [],
		"item_offers": [],
		"service_ids": ["house_drink"],
		"lender_hooks": [],
		"travel_hooks": ["pawn_shop"],
		"next_archetypes": [],
	}
	var first := EnvironmentInstanceScript.ensure_generated_layout(environment)
	var first_rects: Dictionary = first.get("object_rects", {})
	if not first_rects.has("game:slot"):
		failures.append("slot-map cache fixture did not bind its probe game")
		return
	var forged := first.duplicate(true)
	forged["slot_map_digest"] = "0".repeat(64)
	var forged_rects: Dictionary = forged.get("object_rects", {})
	forged_rects["game:slot"] = {"x": 0.91, "y": 0.91, "w": 0.01, "h": 0.01}
	forged["object_rects"] = forged_rects
	var restored_environment := environment.duplicate(true)
	restored_environment["layout"] = forged
	var rebound := EnvironmentInstanceScript.ensure_generated_layout(restored_environment)
	var rebound_rect: Dictionary = (rebound.get("object_rects", {}) as Dictionary).get("game:slot", {})
	if str(rebound.get("grounding_signature", "")) != str(first.get("grounding_signature", "")) \
			or str(rebound.get("slot_map_digest", "")) != str(first.get("slot_map_digest", "")) \
			or str(rebound.get("slot_binding_digest", "")) != str(first.get("slot_binding_digest", "")) \
			or JSON.stringify(rebound_rect) != JSON.stringify(first_rects.get("game:slot", {})):
		failures.append("a stale saved slot-map digest did not invalidate and deterministically rebind fixed room slots")


func _check_base_overflow(failures: Array) -> void:
	var entries: Array = []
	for index in range(32):
		entries.append({
			"object_id": "actor:overflow_%02d" % index,
			"object_type": "actor",
			"role": "patron",
			"label": "Overflow Patron %02d" % index,
			"spot_field": "event_spots",
			"index": index,
		})
	var result := EnvironmentSlotBinderScript.bind_base_layout({"archetype_id": "bar"}, entries)
	var overflow: Array = result.get("overflow_ids", [])
	if overflow.is_empty():
		failures.append("base capacity exhaustion did not produce overflow")
	for object_id_value in overflow:
		var binding: Dictionary = (result.get("slot_bindings", {}) as Dictionary).get(str(object_id_value), {})
		if str(binding.get("presentation_mode", "")) != "overflow" or not str(binding.get("slot_id", "")).is_empty():
			failures.append("base overflow retained room geometry authority")


func _check_scenario_exit_and_overflow(failures: Array) -> void:
	var entries: Array = [{
		"identity": "scenario::safe_exit",
		"semantic": {"present": true, "label": "Safe Exit", "role": "exit", "placement_class": "doorway"},
		"placement_class": "doorway",
		"safe_exit": true,
	}]
	for index in range(24):
		entries.append({
			"identity": "scenario::fixture_%02d" % index,
			"semantic": {"present": true, "label": "Fixture %02d" % index, "role": "fixture", "placement_class": "floor_fixture"},
			"placement_class": "floor_fixture",
			"safe_exit": false,
		})
	var first := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, entries)
	var second := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, entries)
	var bindings: Dictionary = first.get("slot_bindings", {})
	var exit_binding: Dictionary = bindings.get("scenario::safe_exit", {})
	if str(exit_binding.get("kind", "")) != "exit" or str(exit_binding.get("presentation_mode", "")) != "room":
		failures.append("required safe exit did not bind to an authored exit slot")
	if (first.get("overflow_ids", []) as Array).is_empty():
		failures.append("scenario capacity exhaustion did not produce overflow")
	if str(first.get("binding_digest", "")) != str(second.get("binding_digest", "")):
		failures.append("scenario binding is not stable across revisit/reload")


func _check_authored_actor_route(failures: Array) -> void:
	var surface_map := EnvironmentPlacementScript.surface_map({"archetype_id": "back_alley"})
	var result := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "back_alley"}, [{
		"identity": "scenario::patrol_officer",
		"semantic": {"present": true, "label": "Patrol Officer", "role": "guard", "route_id": "base::world:bar"},
		"placement_class": "standing_person",
		"actor": true,
	}])
	var binding: Dictionary = (result.get("slot_bindings", {}) as Dictionary).get("scenario::patrol_officer", {})
	var route: Dictionary = binding.get("route", {})
	if str(binding.get("slot_id", "")) != str(route.get("start_slot_id", "")) \
			or str(route.get("start_slot_id", "")) == str(route.get("end_slot_id", "")) \
			or (route.get("lane_ids", []) as Array).is_empty():
		failures.append("actor route did not reserve distinct authored endpoints and lane")
		return
	var start_slot := _slot_by_id(surface_map, str(route.get("start_slot_id", "")))
	var end_slot := _slot_by_id(surface_map, str(route.get("end_slot_id", "")))
	var route_lane_ids: Array = route.get("lane_ids", [])
	var route_points := EnvironmentSlotBinderScript.authored_route_points(surface_map, start_slot, end_slot, route_lane_ids)
	if route_points.size() != 2 \
			or not route_points[0].is_equal_approx(Vector2(452.0, 318.0)) \
			or not route_points[1].is_equal_approx(Vector2(752.0, 318.0)) \
			or not is_equal_approx(route_points[0].distance_to(route_points[1]), 300.0):
		failures.append("back-alley actor route did not use the exact 300px authored-lane slice without backtracking: %s" % str(route_points))

	var corner_map := EnvironmentPlacementScript.surface_map({"archetype_id": "corner_store"})
	var settled_slot := _slot_by_id(corner_map, "base.standing_person.01")
	var settled_rect := EnvironmentSlotBinderScript.rect_from_binding({"slot": settled_slot})
	var canvas = PixelSceneCanvasScript.new()
	canvas.foundation_snapshot = {"id": "corner_route_fixture", "archetype_id": "corner_store"}
	var settled := {
		"slot_id": "base.standing_person.01",
		"position": settled_rect.get_center() / Vector2(900.0, 430.0),
		"small_screen_rect": EnvironmentSlotBinderScript.normalized_rect(EnvironmentSlotBinderScript.expanded_rect(settled_rect)),
	}
	var arrival: Dictionary = canvas.call("_person_transit_route", settled, "arrival")
	var departure: Dictionary = canvas.call("_person_transit_route", settled, "departure")
	var arrival_pixels := _route_pixels(arrival.get("points", []))
	var departure_pixels := _route_pixels(departure.get("points", []))
	var expected_arrival: Array[Vector2] = [
		Vector2(41.0, 76.0),
		Vector2(64.0, 318.0),
		Vector2(450.0, 318.0),
		Vector2(652.0, 318.0),
	]
	var expected_departure: Array[Vector2] = expected_arrival.duplicate()
	expected_departure.reverse()
	var expected_distance := expected_arrival[0].distance_to(expected_arrival[1]) + 588.0
	if not _route_points_match(arrival_pixels, expected_arrival) \
			or not _route_points_match(departure_pixels, expected_departure) \
			or not is_equal_approx(float((arrival.get("stage", {}) as Dictionary).get("duration_sec", 0.0)), clampf(expected_distance / 82.0, 0.75, 8.0)):
		failures.append("person arrival/departure did not use the shortest ordered exit-to-slot lane slice: arrival=%s departure=%s" % [str(arrival_pixels), str(departure_pixels)])
	canvas.free()


func _check_complete_record_binding(failures: Array) -> void:
	var environment := {"archetype_id": "beach"}
	var records: Array = []
	for index in range(12):
		records.append({
			"object_id": "service:test_%02d" % index,
			"object_type": "service",
			"label": "Test Service %02d" % index,
			"visible": true,
			"enabled": true,
			"interactive": true,
			"layout_spot_field": "service_spots",
			"layout_index": index,
		})
	var result := EnvironmentSlotBinderScript.bind_base_records(environment, records)
	var rebound: Array = result.get("records", [])
	if rebound.size() != records.size():
		failures.append("complete record binder dropped generated inventory")
	for record_value in rebound:
		var record: Dictionary = record_value
		var mode := str(record.get("presentation_mode", ""))
		if mode == "room" and (record.get("focus_rect", {}) as Dictionary).is_empty():
			failures.append("room record has no fixed focus rectangle")
		elif mode == "overflow" and not (record.get("focus_rect", {}) as Dictionary).is_empty():
			failures.append("overflow record retained canvas geometry")


func _check_shared_base_binding_aliases(failures: Array) -> void:
	var environment := {"archetype_id": "pawn_shop"}
	var entries: Array = []
	for index in range(6):
		entries.append({
			"object_id": "item:sal_shelf_%d" % index,
			"object_type": "item",
			"spot_field": "item_spots",
			"index": index,
		})
	entries.append({"object_id": "shopkeeper:merchant", "object_type": "shopkeeper", "spot_field": "shopkeeper_spots", "index": 0})
	entries.append({"object_id": "travel:leave", "object_type": "travel", "spot_field": "travel_spots", "index": 0})
	var base_result := EnvironmentSlotBinderScript.bind_base_layout(environment, entries)
	var base_bindings: Dictionary = base_result.get("slot_bindings", {})
	var records: Array = []
	for index in range(6):
		records.append({
			"object_id": "meta_sal_shelf:%d" % index,
			"object_type": "meta_sal_shelf",
			"slot_binding_source_id": "item:sal_shelf_%d" % index,
			"placement_class": "surface_item",
		})
	records.append({
		"object_id": "meta_sal:talk",
		"object_type": "meta_sal_talk",
		"slot_binding_source_id": "shopkeeper:merchant",
		"placement_class": "behind_counter_person",
	})
	records.append({
		"object_id": "meta_pawn_counter:sell",
		"object_type": "meta_pawn_counter",
		"placement_class": "behind_counter_person",
	})
	records.append({"object_id": "travel:leave", "object_type": "travel"})
	var result := EnvironmentSlotBinderScript.bind_base_records(environment, records, base_bindings)
	var bindings: Dictionary = result.get("slot_bindings", {})
	var rebound_by_id: Dictionary = {}
	for record_value in result.get("records", []):
		var record: Dictionary = record_value
		rebound_by_id[str(record.get("object_id", ""))] = record
	var shelf_slots: Dictionary = {}
	for index in range(6):
		var source_id := "item:sal_shelf_%d" % index
		var alias_id := "meta_sal_shelf:%d" % index
		var source: Dictionary = bindings.get(source_id, {})
		var alias: Dictionary = bindings.get(alias_id, {})
		var rebound: Dictionary = rebound_by_id.get(alias_id, {})
		var slot_id := str(alias.get("slot_id", ""))
		if str(source.get("presentation_mode", "")) != "room" \
				or str(alias.get("presentation_mode", "")) != "room" \
				or slot_id != str(source.get("slot_id", "")) \
				or str(alias.get("placement_class", "")) != "surface_item" \
				or (rebound.get("focus_rect", {}) as Dictionary).is_empty():
			failures.append("Sal shelf %d did not reuse its generated fixed surface-item binding" % index)
		if shelf_slots.has(slot_id):
			failures.append("Sal shelf %d reused another visible shelf slot %s" % [index, slot_id])
		shelf_slots[slot_id] = true
	var sal: Dictionary = bindings.get("meta_sal:talk", {})
	var merchant: Dictionary = bindings.get("shopkeeper:merchant", {})
	var counter: Dictionary = bindings.get("meta_pawn_counter:sell", {})
	if str(sal.get("presentation_mode", "")) != "room" \
			or str(sal.get("slot_id", "")) != str(merchant.get("slot_id", "")) \
			or str(sal.get("placement_class", "")) != "behind_counter_person":
		failures.append("Sal did not reuse the generated shopkeeper fixed binding")
	if str(counter.get("presentation_mode", "")) != "room" \
			or str(counter.get("placement_class", "")) != "behind_counter_person" \
			or str(counter.get("slot_id", "")).is_empty() \
			or str(counter.get("slot_id", "")) == str(sal.get("slot_id", "")):
		failures.append("Sal and the pawn sell counter did not receive distinct fixed behind-counter slots")
	var exit_record: Dictionary = rebound_by_id.get("travel:leave", {})
	if str(exit_record.get("presentation_mode", "")) != "room" \
			or str(exit_record.get("placement_class", "")) != "doorway" \
			or str(exit_record.get("slot_id", "")).is_empty():
		failures.append("pawn-shop Street Door lost its generated fixed doorway binding")


func _check_overflow_action_list(failures: Array) -> void:
	var records := [
		{
			"object_id": "scenario::overflow_enabled", "object_type": "scenario_object",
			"label": "Overflow enabled", "presentation_mode": "overflow", "visible": true,
			"presentation_required": true, "enabled": true, "focus_order": 20,
			"available_actions": [{"id": "inspect", "label": "Inspect"}],
			"focus_rect": Rect2(0.2, 0.2, 0.1, 0.1),
		},
		{
			"object_id": "scenario::overflow_disabled", "object_type": "scenario_object",
			"label": "Overflow disabled", "presentation_mode": "overflow", "visible": true,
			"presentation_required": true, "enabled": false, "focus_order": 10,
			"disabled_reason": "Not yet available.", "available_actions": [],
		},
		{
			"object_id": "scenario::hidden", "label": "Hidden", "presentation_mode": "overflow",
			"visible": false, "presentation_required": true, "enabled": true,
			"available_actions": [{"id": "leak", "label": "Leak"}],
		},
		{
			"object_id": "scenario::not_required", "label": "Not required", "presentation_mode": "overflow",
			"visible": true, "presentation_required": false, "enabled": true,
			"available_actions": [{"id": "leak", "label": "Leak"}],
		},
		{
			"object_id": "scenario::room", "label": "In room", "presentation_mode": "room",
			"visible": true, "presentation_required": true, "enabled": true,
			"available_actions": [{"id": "inspect", "label": "Inspect"}],
		},
	]
	var focus_scope := ModalFocusScopeScript.new()
	var action_list = RoomActionListScript.new()
	action_list.configure(focus_scope)
	get_root().add_child(action_list)
	var selected: Array = []
	action_list.record_selected.connect(func(record: Dictionary) -> void:
		selected.append(record)
	)
	action_list.render(records)
	var buttons := action_list.find_children("*", "Button", true, false)
	var row_button: Button = null
	var all_targets_accessible := true
	for button_value in buttons:
		var button := button_value as Button
		if button.custom_minimum_size.x < 44.0 or button.custom_minimum_size.y < 44.0 or button.focus_mode != Control.FOCUS_ALL:
			all_targets_accessible = false
		if button.text.begins_with("Overflow disabled"):
			row_button = button
	if not action_list.visible or buttons.size() != 4 or not all_targets_accessible or row_button == null:
		failures.append("overflow action list did not expose exactly two sorted 44-pixel keyboard/controller/touch rows")
	else:
		action_list.open()
		if focus_scope.active_root() == null:
			failures.append("overflow action list did not enter the shared modal focus scope")
		row_button.emit_signal("pressed")
		if selected.size() != 1 or str((selected[0] as Dictionary).get("object_id", "")) != "scenario::overflow_disabled" \
				or focus_scope.active_root() != null:
			failures.append("overflow action selection did not route the exact disabled record and close its modal scope")
	var canvas = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900.0, 430.0)
	canvas.render_environment_snapshot({"id": "overflow_list_contract", "archetype_id": "bar", "interactable_objects": records})
	for object_value in canvas.current_view_snapshot().get("objects", []):
		if str((object_value as Dictionary).get("presentation_mode", "room")) == "overflow":
			failures.append("overflow action remained drawable/hittable on the room canvas")
			break
	canvas.free()
	action_list.render([])
	if action_list.visible:
		failures.append("empty overflow action list left a visible launcher")
	action_list.free()


func _check_semantic_classification(failures: Array) -> void:
	var fixtures := [
		[{"label": "Tomas Reed", "role": "shopkeeper"}, "base_object", "shopkeeper:merchant", "behind_counter_person"],
		[{"label": "Priya Moss", "character_id": "priya_moss"}, "scene_object", "priya_moss", "standing_person"],
		[{"label": "League Notice", "visual_prop": "room_display", "role": "notice"}, "event", "event:league_notice", "wall_mounted"],
	]
	for fixture_value in fixtures:
		var fixture: Array = fixture_value
		var actual := EnvironmentPlacementScript.classify(fixture[0], str(fixture[1]), str(fixture[2]))
		if actual != str(fixture[3]):
			failures.append("semantic fixture %s classified as %s instead of %s" % [str(fixture[2]), actual, str(fixture[3])])


func _slot_by_id(surface_map: Dictionary, slot_id: String) -> Dictionary:
	for field in ["base_slots", "stage_slots", "exit_slots"]:
		for slot_value in surface_map.get(field, []):
			var slot: Dictionary = slot_value if typeof(slot_value) == TYPE_DICTIONARY else {}
			if str(slot.get("id", "")) == slot_id:
				return slot.duplicate(true)
	return {}


func _route_pixels(points_value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if typeof(points_value) != TYPE_ARRAY:
		return result
	for point_value in points_value as Array:
		var point: Dictionary = point_value if typeof(point_value) == TYPE_DICTIONARY else {}
		result.append(Vector2(float(point.get("x", -1.0)) * 900.0, float(point.get("y", -1.0)) * 430.0))
	return result


func _route_points_match(actual: Array[Vector2], expected: Array[Vector2]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		if not actual[index].is_equal_approx(expected[index]):
			return false
	return true
