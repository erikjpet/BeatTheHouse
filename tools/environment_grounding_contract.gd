extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	_check_authored_placement_authority(failures)
	_check_zone_person(failures)
	_check_content_aware_classes(failures)
	_check_named_people_classes(failures)
	_check_hidden_state_neutrality(failures)
	_check_scenario_reservation_lifecycle(failures)
	_check_scenario_surface_overrides(failures)
	_check_bounded_grounding_fallback(failures)
	if failures.is_empty():
		print("ENVIRONMENT_GROUNDING_CONTRACT_OK authored=sacrosanct bounded_fallback=grounded zone_person=feet named_people=person person_event=floor wall_sign=wall hidden_state=neutral scenario_reservations=active_only scenario_overrides=bound hanging=multiple")
		quit(0)
		return
	for failure_value in failures:
		printerr("ENVIRONMENT_GROUNDING_CONTRACT_FAIL %s" % str(failure_value))
	quit(1)


func _check_authored_placement_authority(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var authored := Rect2(250.0, 270.0, 72.0, 80.0)
	var occupied := [{
		"identity": "base::blocker",
		"rect": authored,
		"small_rect": authored,
		"label_rect": Rect2(),
		"small_label_rect": Rect2(),
	}]
	var resolved := ScenarioLayoutResolverScript._collision_safe_rect(
		"scenario::floor_person", authored, occupied, "Floor Person", Rect2(),
		environment, "standing_person"
	)
	var rect: Rect2 = resolved.get("rect", Rect2())
	if bool(resolved.get("colliding", true)) or bool(resolved.get("adjusted", true)) or not rect.is_equal_approx(authored):
		failures.append("A supported authored placement was displaced by runtime packing.")
	elif not EnvironmentPlacementScript.valid_rect(environment, "standing_person", rect):
		failures.append("The authored-authority fixture did not remain on the Bar floor.")


func _check_zone_person(failures: Array) -> void:
	var semantic := {
		"owner_namespace": "scenario",
		"stable_object_id": "zone_person",
		"semantic_kind": "actor",
		"label": "Zone Person",
		"description": "A person waits beside the back wall.",
		"appearance": "patron",
		"role": "patron",
		"zone_id": "background",
		"present": true,
	}
	var projection := {
		"scenario_id": "grounding_contract",
		"phase_id": "arrival",
		"status": "active",
		"boundary_serial": 0,
		"semantic_state": {
			"scene_objects": {},
			"actors": {"scenario::zone_person": semantic},
			"interactions": {}, "services": {}, "games": {}, "routes": {},
		},
		"active_stages": [],
	}
	var environment := {
		"archetype_id": "bar",
		"semantic_zones": {"background": {"bounds": [32, 32, 836, 100]}},
	}
	var resolved := ScenarioLayoutResolverScript.resolve([], projection, environment)
	if not bool(resolved.get("ok", false)):
		failures.append("Zone-only person failed class-aware resolution: %s" % JSON.stringify(resolved.get("errors", [])))
		return
	var resolved_projection: Dictionary = resolved.get("projection", {})
	var resolved_semantic: Dictionary = resolved_projection.get("semantic_state", {})
	var resolved_actors: Dictionary = resolved_semantic.get("actors", {})
	if resolved_actors.size() != 1:
		failures.append("Zone-only person did not produce one resolved visual.")
		return
	var visual: Dictionary = resolved_actors.values()[0]
	var rect := _rect_from_normalized(visual.get("normalized_hit_rect", {}))
	if str(visual.get("placement_class", "")) != "standing_person" \
			or not EnvironmentPlacementScript.valid_rect(environment, "standing_person", rect):
		failures.append("Zone-only person did not resolve feet onto the Bar floor.")


func _check_content_aware_classes(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var person := {"label": "Rowdy Regular", "visual_prop": "rowdy_patron", "role": "patron"}
	var person_class := EnvironmentPlacementScript.classify(person, "event", "event:rowdy_regular")
	if person_class != "standing_person":
		failures.append("Person event classified as %s instead of standing_person." % person_class)
	else:
		var candidates := EnvironmentPlacementScript.candidate_rects(environment, person_class, Rect2(100, 80, 100, 64))
		if candidates.is_empty() or str((candidates[0] as Dictionary).get("surface_id", "")).contains("wall"):
			failures.append("Person event received a wall candidate.")
	var sign := {"label": "League Notice", "visual_prop": "room_display", "role": "notice"}
	var sign_class := EnvironmentPlacementScript.classify(sign, "event", "event:league_notice")
	if sign_class != "wall_mounted":
		failures.append("Wall sign classified as %s instead of wall_mounted." % sign_class)
	else:
		var candidates := EnvironmentPlacementScript.candidate_rects(environment, sign_class, Rect2(680, 70, 96, 54))
		if candidates.is_empty() or str((candidates[0] as Dictionary).get("surface_id", "")) != "wall":
			failures.append("Wall sign received a non-wall candidate.")


func _check_named_people_classes(failures: Array) -> void:
	var fixtures := [
		[{"label": "Tomas Reed", "role": "shopkeeper"}, "base_object", "shopkeeper:merchant", "behind_counter_person"],
		[{"label": "Malik Stone", "role": "merchant"}, "item_offer", "merchant:malik", "behind_counter_person"],
		[{"label": "Priya Moss", "character_id": "priya_moss"}, "scene_object", "priya_moss", "standing_person"],
		[{"label": "Pit Boss", "visual_prop": "pit_boss"}, "event", "pit_boss", "standing_person"],
		[{"label": "Silas", "role": "lender"}, "numbers_silas", "numbers:silas", "standing_person"],
	]
	for fixture_value in fixtures:
		var fixture: Array = fixture_value
		var actual := EnvironmentPlacementScript.classify(fixture[0], str(fixture[1]), str(fixture[2]))
		if actual != str(fixture[3]):
			failures.append("Named person %s classified as %s instead of %s." % [str((fixture[0] as Dictionary).get("label", "person")), actual, str(fixture[3])])


func _check_hidden_state_neutrality(failures: Array) -> void:
	var clean := {"archetype_id": "bar"}
	var hidden := {
		"archetype_id": "bar",
		"unrevealed_ticket": {"payout": 500},
		"traitor_member_id": "cass",
		"grievance_weight": 9,
	}
	var authored := Rect2(220, 270, 72, 80)
	var clean_candidates := EnvironmentPlacementScript.candidate_rects(clean, "standing_person", authored, Rect2(), true)
	var hidden_candidates := EnvironmentPlacementScript.candidate_rects(hidden, "standing_person", authored, Rect2(), true)
	if JSON.stringify(_candidate_snapshot(clean_candidates)) != JSON.stringify(_candidate_snapshot(hidden_candidates)):
		failures.append("Hidden state changed deterministic placement candidates.")


func _check_scenario_reservation_lifecycle(failures: Array) -> void:
	var base_map := EnvironmentPlacementScript.surface_map({"archetype_id": "delta_queen"})
	var active_map := EnvironmentPlacementScript.surface_map({"archetype_id": "delta_queen", "scenario_id": "delta_queen_engine_trouble"})
	if base_map.has("scenario_reserved_surfaces") or base_map.has("scenario_reserved_clear_rects"):
		failures.append("Scenario-only capacity remained blocked before a scenario was active.")
	var reserved_surfaces: Array = active_map.get("scenario_reserved_surfaces", [])
	var reserved_clear_rects: Array = active_map.get("scenario_reserved_clear_rects", [])
	if not reserved_surfaces.has("scenario_table") or reserved_clear_rects.is_empty():
		failures.append("Active scenario did not restore its authored surface reservations.")


func _check_scenario_surface_overrides(failures: Array) -> void:
	var environment := {"archetype_id": "motel", "scenario_id": "motel_wedding_overflow"}
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var overrides: Dictionary = surface_map.get("class_overrides", {})
	if str(overrides.get("motel_wedding_overflow_station", "")) != "surface_item" \
			or str(overrides.get("event:town_rumor_staff", "")) != "standing_person":
		failures.append("Scenario surface-map merge replaced global placement classes instead of applying the local override.")
	var station_region: Dictionary = (surface_map.get("scenario_object_regions", {}) as Dictionary).get("motel_wedding_overflow_station", {})
	if station_region.is_empty() or not (station_region.get("surface_ids", []) as Array).has("phone_desk"):
		failures.append("A scenario object region was not present at the shared placement boundary.")
	var hanging := EnvironmentPlacementScript.candidate_rects(environment, "hanging", Rect2(100.0, 0.0, 60.0, 44.0))
	if hanging.size() < 2:
		failures.append("Hanging placement exposed only one ceiling candidate to collision recovery.")
	var projected_environment := {"archetype_id": "motel", "semantic_anchors": {"station": {"position": [622.0, 258.0]}}}
	var projected := ScenarioLayoutResolverScript.resolve([], {
		"scenario_id": "motel_wedding_overflow", "phase_id": "arrival", "status": "active",
		"semantic_state": {"scene_objects": {"scenario::motel_wedding_overflow_station": {
			"owner_namespace": "scenario", "stable_object_id": "motel_wedding_overflow_station", "present": true,
			"label": "Read the room-key trail", "role": "task_station", "anchor_id": "station",
			"bounds": {"w": 64.0, "h": 56.0}, "visible": true, "enabled": true,
		}}, "actors": {}, "interactions": {}},
	}, projected_environment)
	var authority: Dictionary = projected.get("layout_authority", {})
	var station: Dictionary = authority.get("scenario::motel_wedding_overflow_station", {})
	var station_rect := _rect_from_normalized(station.get("normalized_hit_rect", {}))
	if not bool(projected.get("ok", false)) or station_rect.position.x < 588.0 or station_rect.position.x > 612.0:
		failures.append("Resolver did not carry the projected scenario id into placement-map selection.")


func _check_bounded_grounding_fallback(failures: Array) -> void:
	var authored := Rect2(300.0, 20.0, 72.0, 80.0)
	var resolved := EnvironmentPlacementScript.authored_or_local_rect({"archetype_id": "bar"}, "standing_person", authored)
	var rect: Rect2 = resolved.get("rect", Rect2())
	if not bool(resolved.get("ok", false)) or not bool(resolved.get("adjusted", false)):
		failures.append("A malformed person placement did not use the bounded safety net.")
	elif EnvironmentPlacementScript.support_for_rect({"archetype_id": "bar"}, "standing_person", rect).is_empty():
		failures.append("The bounded safety net left a person outside a floor support.")


func _candidate_snapshot(candidates: Array) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		var rect: Rect2 = candidate.get("rect", Rect2())
		result.append({"surface_id": str(candidate.get("surface_id", "")), "rect": str(rect)})
	return result


func _rect_from_normalized(value: Variant) -> Rect2:
	var data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	return Rect2(
		float(data.get("x", 0.0)) * 900.0,
		float(data.get("y", 0.0)) * 430.0,
		float(data.get("w", 0.0)) * 900.0,
		float(data.get("h", 0.0)) * 430.0
	)
