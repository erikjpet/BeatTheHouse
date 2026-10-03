extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	_check_map_inventory(failures)
	_check_deterministic_base_binding(failures)
	_check_strict_family_isolation(failures)
	_check_manifest_binding(failures)
	_check_slot_map_cache_invalidation(failures)
	_check_base_capacity_failure(failures)
	_check_scenario_exit_and_capacity_failure(failures)
	_check_authored_actor_route(failures)
	_check_complete_record_binding(failures)
	_check_shared_base_binding_aliases(failures)
	_check_home_meta_binding_aliases(failures)
	_check_action_attachment(failures)
	_check_semantic_classification(failures)
	if failures.is_empty():
		print("ENVIRONMENT_GROUNDING_CONTRACT_OK authority=four_family_slots maps=21 binding=deterministic family_isolation=strict manifest=sealed overflow=removed scenario=scenario_exit actions=attached routes=authored")
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
	if int(root.get("schema_version", 0)) != 3 or int(root.get("slot_schema_version", 0)) != 2 or maps.size() != 21:
		failures.append("four-family source does not seal schema 3 / slot schema 2 / 21 maps")
	for map_value in maps:
		var map_data: Dictionary = map_value if typeof(map_value) == TYPE_DICTIONARY else {}
		var validation := EnvironmentSlotBinderScript.validate_slot_map(map_data)
		if not bool(validation.get("ok", false)):
			failures.append("map %s violates the four-family contract: %s" % [str(map_data.get("id", "")), JSON.stringify(validation.get("errors", []))])
		for family in ["fixed", "event", "scenario", "exit"]:
			var collection_name := "%s_slots" % family
			if typeof(map_data.get(collection_name)) != TYPE_ARRAY:
				failures.append("map %s does not declare %s" % [str(map_data.get("id", "")), collection_name])
		if typeof(map_data.get("fixed_objects")) != TYPE_ARRAY or typeof(map_data.get("object_family_ids")) != TYPE_DICTIONARY:
			failures.append("map %s does not declare its fixed-object and family manifests" % str(map_data.get("id", "")))


func _check_deterministic_base_binding(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var entries := [
		{"object_id": "travel:leave", "object_type": "travel", "family": "exit", "placement_class": "standing_person", "exact_slot_id": "exit.travel_right", "spot_field": "travel_spots", "index": 0, "required": true, "active": true},
		{"object_id": "game:blackjack", "object_type": "game", "family": "fixed", "placement_class": "surface_item", "exact_slot_id": "fixed.random_game_1", "spot_field": "game_spots", "index": 0, "label": "Blackjack", "required": true, "active": true},
		{"object_id": "service:house_drink", "object_type": "service", "family": "fixed", "placement_class": "surface_item", "exact_slot_id": "fixed.drink", "spot_field": "service_spots", "index": 0, "label": "House Drink", "required": true, "active": true},
	]
	var first := EnvironmentSlotBinderScript.bind_base_layout(environment, entries)
	var reversed := entries.duplicate(true)
	reversed.reverse()
	var second := EnvironmentSlotBinderScript.bind_base_layout(environment, reversed)
	if JSON.stringify(first.get("slot_bindings", {})) != JSON.stringify(second.get("slot_bindings", {})) \
			or str(first.get("binding_digest", "")) != str(second.get("binding_digest", "")):
		failures.append("base binding depends on producer order")
	if not bool(first.get("ok", false)):
		failures.append("four-family deterministic fixture did not bind: %s" % JSON.stringify(first.get("errors", [])))
	for binding_value in (first.get("slot_bindings", {}) as Dictionary).values():
		var binding: Dictionary = binding_value
		if str(binding.get("presentation_mode", "")) == "room" and str(binding.get("slot_id", "")).is_empty():
			failures.append("room binding has no authored slot id")
		var family := str(binding.get("slot_family", ""))
		if family not in ["fixed", "event", "scenario", "exit"] or not str(binding.get("slot_id", "")).begins_with("%s." % family):
			failures.append("room binding crossed or omitted its slot family: %s" % JSON.stringify(binding))


func _check_strict_family_isolation(failures: Array) -> void:
	# Bar has compatible fixed.surface_item capacity but no event.surface_item
	# capacity. The event must fail instead of borrowing from fixed.
	var result := EnvironmentSlotBinderScript.bind_base_layout({"archetype_id": "bar"}, [{
		"object_id": "event:family_isolation_probe",
		"object_type": "event",
		"visual_prop": "room_surface",
		"family": "event",
		"placement_class": "surface_item",
		"exact_slot_id": "fixed.random_game_1",
		"required": true,
		"active": true,
	}])
	if bool(result.get("ok", true)) or (result.get("errors", []) as Array).is_empty():
		failures.append("event family borrowed compatible fixed capacity")
	if (result.get("slot_bindings", {}) as Dictionary).has("event:family_isolation_probe"):
		failures.append("cross-family event binding survived strict finalization")


func _check_manifest_binding(failures: Array) -> void:
	var environment := {
		"id": "jazz_manifest_fixture",
		"archetype_id": "jazz_club",
		"layout": {},
		"game_ids": [],
		"event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"travel_hooks": [],
		"next_archetypes": [],
	}
	var layout := EnvironmentInstanceScript.ensure_generated_layout(environment)
	environment["layout"] = layout
	var manifest: Dictionary = environment.get("object_manifest", {})
	var first_digest := str(manifest.get("digest", ""))
	var first_revision := int(manifest.get("revision", 0))
	if not EnvironmentInstanceScript.object_manifest_errors(environment).is_empty() \
			or first_digest.is_empty() or first_revision <= 0 \
			or str(environment.get("object_manifest_digest", "")) != first_digest:
		failures.append("Jazz Club generated an invalid or unmirrored object manifest")
		return
	var expected := {
		"shopkeeper:merchant": "fixed.staff_bartender",
		"musician:jazz_sax": "fixed.musician_sax",
		"musician:jazz_cello": "fixed.musician_cello",
		"musician:jazz_drummer": "fixed.musician_drummer",
		"service:jazz_band_tip_jar": "fixed.tip_jar_band",
		"fixture:jazz_band_stage": "fixed.band_stage",
	}
	var rows_by_presentation: Dictionary = {}
	for row_value in EnvironmentInstanceScript.active_object_manifest_rows(environment, "fixed"):
		var row: Dictionary = row_value
		rows_by_presentation[str(row.get("presentation_object_id", ""))] = row
	var bindings: Dictionary = layout.get("slot_bindings", {})
	for presentation_id in expected:
		var expected_slot := str(expected.get(presentation_id, ""))
		var row: Dictionary = rows_by_presentation.get(presentation_id, {})
		var binding: Dictionary = bindings.get(presentation_id, {})
		if row.is_empty() or not bool(row.get("required", false)) or not bool(row.get("active", false)) \
				or str(row.get("family", "")) != "fixed" or str(row.get("exact_slot_id", "")) != expected_slot:
			failures.append("Jazz Club manifest lost required fixed object %s" % presentation_id)
		if str(binding.get("slot_family", "")) != "fixed" or str(binding.get("slot_id", "")) != expected_slot:
			failures.append("Jazz Club fixed object %s did not bind its exact slot %s" % [presentation_id, expected_slot])
	for attached_action in ["service:jazz_sax_round", "service:jazz_cello_round", "service:jazz_drummer_round", "service:listen_to_jazz"]:
		if rows_by_presentation.has(attached_action):
			failures.append("attached Jazz Club action %s became a duplicate physical object" % attached_action)
	var reconciled := EnvironmentInstanceScript.reconcile_object_manifest(environment)
	if str(reconciled.get("digest", "")) != first_digest or int(reconciled.get("revision", 0)) != first_revision:
		failures.append("unchanged Jazz Club manifest reconciliation was not idempotent")


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


func _check_base_capacity_failure(failures: Array) -> void:
	var entries: Array = []
	# Keep the fixture larger than the room's authored standing-person capacity;
	# new hand-placed slots must not accidentally turn this into a success case.
	for index in range(12):
		entries.append({
			"object_id": "actor:overflow_%02d" % index,
			"object_type": "actor",
			"visual_type": "character",
			"physical_person": true,
			"role": "patron",
			"label": "Overflow Patron %02d" % index,
			"family": "event",
			"placement_class": "standing_person",
			"required": false,
			"active": true,
			"spot_field": "event_spots",
			"index": index,
		})
	var result := EnvironmentSlotBinderScript.bind_base_layout({"archetype_id": "bar"}, entries)
	var overflow: Array = result.get("overflow_ids", [])
	if bool(result.get("ok", true)) or (result.get("errors", []) as Array).is_empty():
		failures.append("base capacity exhaustion did not fail with a missing authored-slot data error: %s" % JSON.stringify(result))
	if not overflow.is_empty():
		failures.append("base capacity exhaustion still produced removed overflow rows")
	for binding_value in (result.get("slot_bindings", {}) as Dictionary).values():
		if str((binding_value as Dictionary).get("presentation_mode", "")) == "overflow":
			failures.append("base capacity exhaustion retained an overflow binding")


func _check_scenario_exit_and_capacity_failure(failures: Array) -> void:
	var bar_surface_map := EnvironmentPlacementScript.surface_map({"archetype_id": "bar"})
	var scenario_person_capacity := 0
	for slot_value in bar_surface_map.get("scenario_slots", []):
		var slot: Dictionary = slot_value if typeof(slot_value) == TYPE_DICTIONARY else {}
		if str(slot.get("footprint_class", "")) == "standing_person":
			scenario_person_capacity += 1
	if scenario_person_capacity <= 0:
		failures.append("bar exposes no authored scenario standing-person capacity")
		return
	var entries: Array = [{
		"identity": "scenario::safe_exit",
		"semantic": {"present": true, "label": "Safe Exit", "role": "exit", "placement_class": "doorway"},
		"family": "exit",
		"placement_class": "doorway",
		"navigation_exit": true,
		"active": true,
		"safe_exit": true,
	}]
	for index in range(scenario_person_capacity):
		entries.append({
			"identity": "scenario::fixture_%02d" % index,
			"semantic": {"present": true, "label": "Patron %02d" % index, "role": "patron", "placement_class": "standing_person"},
			"family": "scenario",
			"placement_class": "standing_person",
			"actor": true,
			"active": true,
			"safe_exit": false,
		})
	var boundary := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, entries)
	if not bool(boundary.get("ok", false)):
		failures.append("scenario exact-capacity boundary rejected available authored slots: %s" % JSON.stringify(boundary.get("errors", [])))
	var overflow_identity := "scenario::fixture_%02d" % scenario_person_capacity
	entries.append({
		"identity": overflow_identity,
		"semantic": {"present": true, "label": "Overflow Patron", "role": "patron", "placement_class": "standing_person"},
		"family": "scenario",
		"placement_class": "standing_person",
		"actor": true,
		"active": true,
		"safe_exit": false,
	})
	var first := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, entries)
	var second := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "bar"}, entries)
	var bindings: Dictionary = first.get("slot_bindings", {})
	var exit_binding: Dictionary = bindings.get("scenario::safe_exit", {})
	if str(exit_binding.get("kind", "")) != "exit" or str(exit_binding.get("presentation_mode", "")) != "room":
		failures.append("required safe exit did not bind to an authored exit slot")
	var missing_slot_error := false
	for error_value in first.get("errors", []):
		if str(error_value).contains("no free compatible authored scenario.standing_person slot"):
			missing_slot_error = true
			break
	if bool(first.get("ok", true)) or not missing_slot_error:
		failures.append("scenario capacity exhaustion did not fail with the expected missing authored-slot data error: %s" % JSON.stringify(first.get("errors", [])))
	if not (first.get("overflow_ids", []) as Array).is_empty():
		failures.append("scenario capacity exhaustion still produced removed overflow rows")
	if bindings.has(overflow_identity):
		failures.append("scenario capacity exhaustion assigned the extra actor an authored binding")
	if str(first.get("binding_digest", "")) != str(second.get("binding_digest", "")):
		failures.append("scenario binding is not stable across revisit/reload")


func _check_authored_actor_route(failures: Array) -> void:
	var surface_map := EnvironmentPlacementScript.surface_map({"archetype_id": "back_alley"})
	var result := EnvironmentSlotBinderScript.bind_scenario_visuals({"archetype_id": "back_alley"}, [{
		"identity": "scenario::patrol_officer",
		"semantic": {"present": true, "label": "Patrol Officer", "role": "guard", "route_id": "base::world:bar"},
		"family": "scenario",
		"placement_class": "standing_person",
		"actor": true,
		"active": true,
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
	var start_center := EnvironmentSlotBinderScript.rect_from_binding({"slot": start_slot}).get_center()
	var end_center := EnvironmentSlotBinderScript.rect_from_binding({"slot": end_slot}).get_center()
	var route_axis := end_center - start_center
	var ordered_route := route_points.size() >= 2 \
		and route_points[0].is_equal_approx(start_center) \
		and route_points[-1].is_equal_approx(end_center) \
		and route_axis.length_squared() > 0.0
	var previous_progress := -1.0e30
	if ordered_route:
		for point in route_points:
			var progress := (point - start_center).dot(route_axis)
			if progress < previous_progress - 0.001:
				ordered_route = false
				break
			previous_progress = progress
	if not ordered_route:
		failures.append("back-alley actor route did not use an ordered authored-lane slice without backtracking: %s" % str(route_points))

	var corner_map := EnvironmentPlacementScript.surface_map({"archetype_id": "corner_store"})
	var settled_slot := _slot_by_id(corner_map, "scenario.standing_person_1")
	var settled_rect := EnvironmentSlotBinderScript.rect_from_binding({"slot": settled_slot})
	var canvas = PixelSceneCanvasScript.new()
	canvas.foundation_snapshot = {"id": "corner_route_fixture", "archetype_id": "corner_store"}
	var settled := {
		"slot_id": "scenario.standing_person_1",
		"slot_family": "scenario",
		"position": settled_rect.get_center() / Vector2(900.0, 430.0),
		"small_screen_rect": EnvironmentSlotBinderScript.normalized_rect(EnvironmentSlotBinderScript.expanded_rect(settled_rect)),
	}
	var arrival: Dictionary = canvas.call("_person_transit_route", settled, "arrival")
	var departure: Dictionary = canvas.call("_person_transit_route", settled, "departure")
	var arrival_pixels := _route_pixels(arrival.get("points", []))
	var departure_pixels := _route_pixels(departure.get("points", []))
	var expected_departure: Array[Vector2] = arrival_pixels.duplicate()
	expected_departure.reverse()
	var expected_distance := 0.0
	for index in range(1, arrival_pixels.size()):
		expected_distance += arrival_pixels[index - 1].distance_to(arrival_pixels[index])
	if arrival_pixels.size() < 2 \
			or not _route_points_match(departure_pixels, expected_departure) \
			or not is_equal_approx(float((arrival.get("stage", {}) as Dictionary).get("duration_sec", 0.0)), clampf(expected_distance / 82.0, 0.75, 8.0)):
		failures.append("person arrival/departure did not use the shortest ordered exit-to-slot lane slice: arrival=%s departure=%s" % [str(arrival_pixels), str(departure_pixels)])
	canvas.free()


func _check_complete_record_binding(failures: Array) -> void:
	var environment := {"archetype_id": "beach"}
	var records: Array = []
	for index in range(3):
		records.append({
			"object_id": "actor:test_%02d" % index,
			"object_type": "actor",
			"visual_type": "character",
			"physical_person": true,
			"label": "Test Patron %02d" % index,
			"visible": true,
			"enabled": true,
			"interactive": true,
			"family": "scenario",
			"placement_class": "standing_person",
			"exact_slot_id": "scenario.standing_person_%d" % (index + 1),
			"required": true,
			"active": true,
			"layout_spot_field": "event_spots",
			"layout_index": index,
		})
	var result := EnvironmentSlotBinderScript.bind_base_records(environment, records)
	if not bool(result.get("ok", false)):
		failures.append("complete record binder rejected available authored room slots: %s" % JSON.stringify(result.get("errors", [])))
	var rebound: Array = result.get("records", [])
	if rebound.size() != records.size():
		failures.append("complete record binder dropped generated inventory")
	for record_value in rebound:
		var record: Dictionary = record_value
		var mode := str(record.get("presentation_mode", ""))
		if mode == "room" and (record.get("focus_rect", {}) as Dictionary).is_empty():
			failures.append("room record has no fixed focus rectangle")
		elif mode != "room":
			failures.append("live physical record was not assigned a room slot")


func _check_shared_base_binding_aliases(failures: Array) -> void:
	var offers: Array = []
	for index in range(6):
		offers.append({"id": "sal_shelf_%d" % index})
	var environment := {"archetype_id": "pawn_shop", "item_offers": offers}
	var entries: Array = []
	for index in range(6):
		entries.append({
			"object_id": "item:sal_shelf_%d" % index,
			"object_type": "item",
			"family": "fixed",
			"placement_class": "shop_item",
			"exact_slot_id": "fixed.item_shop_%d" % (index + 1),
			"required": true,
			"active": true,
			"spot_field": "item_spots",
			"index": index,
		})
	entries.append({"object_id": "shopkeeper:merchant", "object_type": "shopkeeper", "family": "fixed", "placement_class": "behind_counter_person", "exact_slot_id": "fixed.staff_merchant", "required": true, "active": true, "spot_field": "shopkeeper_spots", "index": 0})
	entries.append({"object_id": "travel:leave", "object_type": "travel", "family": "exit", "placement_class": "doorway", "exact_slot_id": "exit.door_left_lower", "required": true, "active": true, "spot_field": "travel_spots", "index": 0})
	var base_result := EnvironmentSlotBinderScript.bind_base_layout(environment, entries)
	var base_bindings: Dictionary = base_result.get("slot_bindings", {})
	environment["layout"] = {
		"slot_schema_version": base_result.get("slot_schema_version", 0),
		"slot_map_digest": base_result.get("slot_map_digest", ""),
		"slot_binding_digest": base_result.get("binding_digest", ""),
		"slot_bindings": base_bindings.duplicate(true),
		"slot_overflow_ids": base_result.get("overflow_ids", []),
		"object_rects": base_result.get("object_rects", {}),
	}
	var records: Array = []
	for index in range(6):
		records.append({
			"object_id": "meta_sal_shelf:%d" % index,
			"object_type": "meta_sal_shelf",
			"slot_binding_source_id": "item:sal_shelf_%d" % index,
			"family": "fixed",
			"placement_class": "shop_item",
			"exact_slot_id": "fixed.item_shop_%d" % (index + 1),
			"active": true,
		})
	records.append({
		"object_id": "meta_sal:talk",
		"object_type": "meta_sal_talk",
		"slot_binding_source_id": "shopkeeper:merchant",
		"family": "fixed",
		"placement_class": "behind_counter_person",
		"exact_slot_id": "fixed.staff_merchant",
		"active": true,
	})
	records.append({
		"object_id": "meta_pawn_counter:sell",
		"object_type": "meta_pawn_counter",
		"family": "fixed",
		"placement_class": "behind_counter_person",
		"exact_slot_id": "fixed.staff_pawn_counter",
		"active": true,
	})
	records.append({"object_id": "travel:leave", "object_type": "travel", "family": "exit", "placement_class": "doorway", "exact_slot_id": "exit.door_left_lower", "active": true})
	var result := EnvironmentSlotBinderScript.bind_base_records(environment, records, base_bindings)
	if not bool(result.get("ok", false)):
		failures.append("Sal shared alias binding failed: %s" % JSON.stringify(result.get("errors", [])))
		return
	var bindings: Dictionary = result.get("slot_bindings", {})
	var rebound_by_id: Dictionary = {}
	for record_value in result.get("records", []):
		var record: Dictionary = record_value
		rebound_by_id[str(record.get("object_id", ""))] = record
	var shelf_slots: Dictionary = {}
	for index in range(6):
		var source_id := "item:sal_shelf_%d" % index
		var alias_id := "meta_sal_shelf:%d" % index
		var source: Dictionary = base_bindings.get(source_id, {})
		var alias: Dictionary = bindings.get(alias_id, {})
		var rebound: Dictionary = rebound_by_id.get(alias_id, {})
		var slot_id := str(alias.get("slot_id", ""))
		if str(source.get("presentation_mode", "")) != "room" \
				or str(alias.get("presentation_mode", "")) != "room" \
				or slot_id != str(source.get("slot_id", "")) \
				or str(alias.get("placement_class", "")) != "shop_item" \
				or (rebound.get("focus_rect", {}) as Dictionary).is_empty():
			failures.append("Sal shelf %d did not reuse its generated fixed shop-item binding" % index)
		if shelf_slots.has(slot_id):
			failures.append("Sal shelf %d reused another visible shelf slot %s" % [index, slot_id])
		shelf_slots[slot_id] = true
	var sal: Dictionary = bindings.get("meta_sal:talk", {})
	var merchant: Dictionary = base_bindings.get("shopkeeper:merchant", {})
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
			or str(exit_record.get("slot_family", "")) != "exit" \
			or str(exit_record.get("placement_class", "")) != "standing_person" \
			or str(exit_record.get("slot_id", "")).is_empty():
		failures.append("pawn-shop Street Door lost its generated exit-family navigation binding")


func _check_home_meta_binding_aliases(failures: Array) -> void:
	var container_id := "home_alias_probe_01"
	var source_id := "home_container:%s" % container_id
	var environment := {
		"id": "home_alias_fixture",
		"archetype_id": "house",
		"kind": "home",
		"home_lost": false,
		"home_containers": [{"id": container_id, "item_id": "bag", "display_name": "Probe Bag", "capacity": 3, "items": []}],
		"game_ids": [],
		"event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"travel_hooks": ["pawn_shop"],
		"next_archetypes": [],
		"layout": {},
	}
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment)
	var base_bindings: Dictionary = (environment.get("layout", {}) as Dictionary).get("slot_bindings", {})
	var source: Dictionary = base_bindings.get(source_id, {})
	if str(source.get("presentation_mode", "")) != "room" \
			or str(source.get("placement_class", "")) != "floor_fixture" \
			or str(source.get("slot_family", "")) != "fixed" \
			or str(source.get("slot_id", "")) != "fixed.home_container_1":
		failures.append("generated home container did not receive the expected fixed floor-fixture source binding")
		return
	var records := [
		{
			"object_id": "meta_container:%s" % container_id,
			"object_type": "home_container",
			"slot_binding_source_id": source_id,
			"family": "fixed",
			"placement_class": "floor_fixture",
			"exact_slot_id": "fixed.home_container_1",
			"active": true,
			"label": "Probe Bag",
		},
		{
			"object_id": "meta_upgrade:home",
			"object_type": "meta_upgrade",
			"family": "fixed",
			"placement_class": "wall_mounted",
			"exact_slot_id": "fixed.home_upgrade",
			"active": true,
			"label": "Upgrade Sign",
		},
		{
			"object_id": "meta_trade_up:station",
			"object_type": "meta_trade_up",
			"family": "fixed",
			"placement_class": "surface_item",
			"exact_slot_id": "fixed.home_trade_up",
			"active": true,
			"label": "Trade-Up Station",
		},
		{
			"object_id": "travel:leave",
			"object_type": "travel",
			"family": "exit",
			"placement_class": "doorway",
			"exact_slot_id": "exit.travel_door",
			"active": true,
			"label": "Map Door",
		},
	]
	var result := EnvironmentSlotBinderScript.bind_base_records(environment, records, base_bindings)
	if not bool(result.get("ok", false)):
		failures.append("home late-record fixed-slot binding failed: %s" % JSON.stringify(result.get("errors", [])))
		return
	var bindings: Dictionary = result.get("slot_bindings", {})
	var alias: Dictionary = bindings.get("meta_container:%s" % container_id, {})
	if str(alias.get("presentation_mode", "")) != "room" \
			or str(alias.get("slot_id", "")) != str(source.get("slot_id", "")) \
			or str(alias.get("placement_class", "")) != "floor_fixture":
		failures.append("late meta container did not reuse its exact generated home-container fixed binding")
	for expectation in [
		["meta_upgrade:home", "fixed.home_upgrade", "fixed", "wall_mounted"],
		["meta_trade_up:station", "fixed.home_trade_up", "fixed", "surface_item"],
		["travel:leave", "exit.travel_door", "exit", "doorway"],
	]:
		var binding: Dictionary = bindings.get(str(expectation[0]), {})
		if str(binding.get("presentation_mode", "")) != "room" \
				or str(binding.get("slot_id", "")) != str(expectation[1]) \
				or str(binding.get("slot_family", "")) != str(expectation[2]) \
				or str(binding.get("placement_class", "")) != str(expectation[3]):
			failures.append("home late control %s did not bind its named %s %s slot as %s: %s" % [expectation[0], expectation[1], expectation[2], expectation[3], JSON.stringify(binding)])


func _check_action_attachment(failures: Array) -> void:
	var records := [
		{
			"object_id": "actor:clerk", "object_type": "character", "visual_type": "character",
			"label": "Clerk", "presentation_mode": "room", "visible": true, "interactive": true,
			"focus_rect": {"x": 0.2, "y": 0.2, "w": 0.1, "h": 0.2},
		},
		{
			"object_id": "scenario::abstract_ledger", "object_type": "scenario_sequence",
			"label": "Ledger", "visible": true, "enabled": true,
			"owner_namespace": "scenario", "stable_object_id": "abstract_ledger",
			"scenario_sequence_actions": [{"id": "inspect", "label": "Inspect Ledger"}],
		},
	]
	var attached := EnvironmentInteractionControllerScript._attach_action_only_records(records)
	if attached.size() != 1:
		failures.append("abstract room action was not folded into exactly one visible object")
		return
	var host := attached[0] as Dictionary
	var actions: Array = host.get("attached_room_actions", [])
	if str(host.get("object_id", "")) != "actor:clerk" or actions.size() != 1 \
			or str((actions[0] as Dictionary).get("label", "")) != "Inspect Ledger":
		failures.append("abstract room action did not remain reachable from its visible host object")


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
	for field in ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]:
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
