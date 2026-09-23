extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const CharacterChainModelScript := preload("res://scripts/core/character_chain_model.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const FIXED_LOCK_PROJECT_PATH := "user://environment_grounding_fixed_lock_project.json"
const FIXED_LOCK_USER_PATH := "user://environment_grounding_fixed_lock_user.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	_check_authored_placement_authority(failures)
	_check_inclusive_physical_support_boundaries(failures)
	_check_fixed_developer_lock_repack(failures)
	_check_generated_route_blocker_repack(failures)
	_check_dense_repack_budget(failures)
	_check_lazy_fine_candidate_materialization(failures)
	_check_clique_solver_oracle(failures)
	_check_zone_person(failures)
	_check_content_aware_classes(failures)
	_check_named_people_classes(failures)
	_check_hidden_state_neutrality(failures)
	_check_scenario_reservation_lifecycle(failures)
	_check_scenario_surface_overrides(failures)
	_check_bounded_grounding_fallback(failures)
	_check_deferred_layout_finalization(failures)
	_check_character_chain_deferred_reconciliation(failures)
	_check_scenario_prime_cache_lifecycle(failures)
	_check_initial_generation_finalization_receipt(failures)
	if failures.is_empty():
		print("ENVIRONMENT_GROUNDING_CONTRACT_OK authored=preserved_when_clear blocked_authored=class_valid_repacked fixed_current=pinned fixed_blocker=class_valid_adjusted route_blocker=class_valid_adjusted fixed_metadata=save_stable fixed_exhaustion=fail_closed dense_repack=under_2000ms lazy_fine=on_demand clique_oracle=hall_ac_and_exhaustive normal_and_expanded=disjoint bounded_fallback=grounded deferred_layout=raw_until_finalize late_control=grounded final_layout=idempotent chain_defer=raw_idempotent_materialized_reconciled scenario_prime=same_cycle_cached_cycle_aware initial_generation=finalization_receipted zone_person=feet named_people=person person_event=floor wall_sign=wall hidden_state=neutral scenario_reservations=active_only scenario_overrides=bound hanging=multiple")
		quit(0)
		return
	for failure_value in failures:
		printerr("ENVIRONMENT_GROUNDING_CONTRACT_FAIL %s" % str(failure_value))
	quit(1)


func _check_authored_placement_authority(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var authored := Rect2(272.0, 314.0, 32.0, 36.0)
	var clear := ScenarioLayoutResolverScript._collision_safe_rect(
		"scenario::floor_person", authored, [], "Floor Person", Rect2(),
		environment, "standing_person"
	)
	var clear_rect: Rect2 = clear.get("rect", Rect2())
	if bool(clear.get("colliding", true)) or bool(clear.get("adjusted", true)) or not clear_rect.is_equal_approx(authored):
		failures.append("A clear supported authored placement was not preserved exactly.")
	elif not EnvironmentPlacementScript.valid_rect(environment, "standing_person", clear_rect):
		failures.append("The clear authored-authority fixture did not remain on the Bar floor.")

	var blocker_small := ScenarioLayoutResolverScript._expanded_rect(authored, Vector2(44.0, 44.0))
	var occupied := [{
		"identity": "base::blocker",
		"rect": authored,
		"small_rect": blocker_small,
		"label_rect": Rect2(),
		"small_label_rect": Rect2(),
	}]
	var blocked := ScenarioLayoutResolverScript._collision_safe_rect(
		"scenario::floor_person", authored, occupied, "Floor Person", Rect2(),
		environment, "standing_person"
	)
	var blocked_rect: Rect2 = blocked.get("rect", Rect2())
	var blocked_small := ScenarioLayoutResolverScript._expanded_rect(blocked_rect, Vector2(44.0, 44.0))
	if bool(blocked.get("colliding", true)) or not bool(blocked.get("adjusted", false)) or blocked_rect.is_equal_approx(authored):
		failures.append("An occupied supported authored placement was not deterministically repacked.")
	elif not EnvironmentPlacementScript.valid_rect(environment, "standing_person", blocked_rect):
		failures.append("The blocked authored-authority fixture left its standing-person floor support.")
	elif blocked_rect.intersects(authored) and blocked_rect.intersection(authored).get_area() > 0.01:
		failures.append("The repacked authored fixture retained ambiguous normal hit authority.")
	elif blocked_small.intersects(blocker_small) and blocked_small.intersection(blocker_small).get_area() > 0.01:
		failures.append("The repacked authored fixture retained ambiguous expanded hit authority.")


func _check_inclusive_physical_support_boundaries(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	# Candidate enumeration deliberately includes the far edge of a floor band or
	# doorway. Validation must accept the same closed support boundary; Rect2's
	# half-open has_point() semantics otherwise manufacture invalid candidates.
	var floor_edge := Rect2(92.0, 360.0, 96.0, 54.0)
	if not EnvironmentPlacementScript.valid_rect({"archetype_id": "delta_queen"}, "floor_fixture", floor_edge):
		failures.append("A generated floor candidate on the authored band edge lost its physical support.")
	var stage_edge := Rect2(432.0, 170.0, 110.0, 72.0)
	if not EnvironmentPlacementScript.valid_rect({"archetype_id": "jazz_club"}, "floor_fixture", stage_edge):
		failures.append("A generated stage candidate was incorrectly constrained by the ordinary floor contact range.")
	var doorway_edge := Rect2(692.0, 80.0, 100.0, 64.0)
	if not EnvironmentPlacementScript.valid_rect(environment, "doorway", doorway_edge):
		failures.append("A generated doorway candidate on the authored boundary lost its physical support.")


func _check_fixed_developer_lock_repack(failures: Array) -> void:
	var prior_project_path := OS.get_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV)
	var prior_user_path := OS.get_environment(DeveloperPlacementStoreScript.USER_PATH_ENV)
	_remove_fixed_lock_fixture_generations()
	var fixture_payload := {
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {"bar": {"object_slot_positions": {
			"item:fixed_alpha": [360.0, 120.0],
			"item:fixed_beta": [360.0, 120.0],
		}}},
	}
	var empty_payload := {"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION, "rooms": {}}
	if not _write_fixed_lock_fixture(FIXED_LOCK_PROJECT_PATH, fixture_payload) \
			or not _write_fixed_lock_fixture(FIXED_LOCK_USER_PATH, empty_payload):
		failures.append("The fixed-lock placement fixture could not be written.")
		_remove_fixed_lock_fixture_generations()
		return
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, FIXED_LOCK_PROJECT_PATH)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, FIXED_LOCK_USER_PATH)
	DeveloperPlacementStoreScript.reload()

	var environment := {"archetype_id": "bar"}
	var entries := [
		{"object_id": "item:fixed_alpha", "object_type": "item", "index": 0, "spot_field": "item_spots"},
		{"object_id": "item:fixed_beta", "object_type": "item", "index": 1, "spot_field": "item_spots"},
	]
	var fixture_size := Vector2(56.0 / 900.0, 40.0 / 430.0)
	var authored_normalized := Rect2(Vector2(360.0 / 900.0, 120.0 / 430.0), fixture_size)
	var clear_rects := {"item:fixed_alpha": EnvironmentInstanceScript._rect_to_dict(authored_normalized)}
	var clear_layout: Dictionary = {}
	EnvironmentInstanceScript._ground_authored_object_rects(clear_rects, clear_layout, environment, [entries[0]])
	var clear_result := EnvironmentInstanceScript._rect_from_dict(clear_rects.get("item:fixed_alpha", {}))
	if not clear_result.is_equal_approx(authored_normalized):
		failures.append("A clear fixed developer placement did not persist exactly.")
	if not (clear_layout.get("placement_adjusted_ids", []) as Array).is_empty():
		failures.append("A clear fixed developer placement was incorrectly marked adjusted.")

	var object_rects := {
		"item:fixed_alpha": EnvironmentInstanceScript._rect_to_dict(authored_normalized),
		"item:fixed_beta": EnvironmentInstanceScript._rect_to_dict(authored_normalized),
	}
	var layout: Dictionary = {}
	EnvironmentInstanceScript._ground_authored_object_rects(object_rects, layout, environment, entries)
	var alpha := EnvironmentInstanceScript._rect_from_dict(object_rects.get("item:fixed_alpha", {}))
	var beta := EnvironmentInstanceScript._rect_from_dict(object_rects.get("item:fixed_beta", {}))
	var alpha_pixel := Rect2(alpha.position * Vector2(900.0, 430.0), alpha.size * Vector2(900.0, 430.0))
	if not beta.is_equal_approx(authored_normalized):
		failures.append("The deterministic later/current fixed placement was not kept pinned at its exact authored rect.")
	if alpha.is_equal_approx(authored_normalized):
		failures.append("The earlier colliding fixed placement was not relocated as the last-resort blocker.")
	elif not EnvironmentPlacementScript.valid_rect(environment, "surface_item", alpha_pixel):
		failures.append("The earlier colliding fixed placement was relocated outside its class-valid surface.")
	var alpha_expanded := EnvironmentInstanceScript._expanded_object_rect(alpha)
	var beta_expanded := EnvironmentInstanceScript._expanded_object_rect(beta)
	if alpha.intersects(beta) and alpha.intersection(beta).get_area() > 0.000001:
		failures.append("Colliding fixed placements retained ambiguous normal authority after repack.")
	if alpha_expanded.intersects(beta_expanded) and alpha_expanded.intersection(beta_expanded).get_area() > 0.000001:
		failures.append("Colliding fixed placements retained ambiguous expanded authority after repack.")
	if layout.get("placement_adjusted_ids", []) != ["item:fixed_alpha"]:
		failures.append("Fixed-placement adjustment metadata did not identify exactly the relocated earlier lock: %s" % JSON.stringify(layout.get("placement_adjusted_ids", [])))
	if not (layout.get("placement_errors", []) as Array).is_empty():
		failures.append("A class-valid fixed-lock repack reported placement exhaustion: %s" % JSON.stringify(layout.get("placement_errors", [])))

	# A v15 save predates explicit fixed-adjustment metadata. It must recompute on
	# load, then remain byte-stable through the next save/load round trip.
	var stale_layout := {
		"generated_object_rect_version": 15,
		"grounding_signature": "legacy-v15-signature",
		"placement_errors": [],
		"placement_fallback_ids": [],
		"object_rects": {
			"item:fixed_alpha": EnvironmentInstanceScript._rect_to_dict(authored_normalized),
			"item:fixed_beta": EnvironmentInstanceScript._rect_to_dict(authored_normalized),
		},
	}
	var stale_environment := {
		"archetype_id": "bar",
		"item_offers": [{"id": "fixed_alpha"}, {"id": "fixed_beta"}],
		"layout": stale_layout,
	}
	var migrated := EnvironmentInstanceScript.ensure_generated_layout(stale_environment)
	if int(migrated.get("generated_object_rect_version", 0)) <= 15:
		failures.append("A v15 generated layout was not migrated to the fixed-adjustment authority version.")
	if migrated.get("placement_adjusted_ids", []) != ["item:fixed_alpha"]:
		failures.append("A migrated v15 layout did not recompute deterministic fixed-adjustment metadata.")
	var serialized := JSON.stringify(migrated)
	var restored_value: Variant = JSON.parse_string(serialized)
	if typeof(restored_value) != TYPE_DICTIONARY:
		failures.append("The fixed-lock layout was not JSON save/load compatible.")
	else:
		var restored_environment := stale_environment.duplicate(true)
		restored_environment["layout"] = restored_value
		var restored := EnvironmentInstanceScript.ensure_generated_layout(restored_environment)
		var same_rects := _rect_maps_equal_approx(restored.get("object_rects", {}), migrated.get("object_rects", {}))
		var same_adjusted: bool = restored.get("placement_adjusted_ids", []) == migrated.get("placement_adjusted_ids", [])
		var same_errors: bool = restored.get("placement_errors", []) == migrated.get("placement_errors", [])
		var same_signature := str(restored.get("grounding_signature", "")) == str(migrated.get("grounding_signature", ""))
		var same_version := int(restored.get("generated_object_rect_version", 0)) == int(migrated.get("generated_object_rect_version", 0))
		if not same_rects or not same_adjusted or not same_errors or not same_signature or not same_version:
			failures.append("Fixed-placement adjustment metadata or geometry changed across save/load (rects=%s adjusted=%s errors=%s signature=%s version=%s)." % [same_rects, same_adjusted, same_errors, same_signature, same_version])

	var impossible_rect := Rect2(0.25, 0.25, 0.08, 0.12)
	var impossible_record := {
		"object_id": "item:current_lock", "object_type": "item", "placement_class": "surface_item",
		"anchor_rect": Rect2(impossible_rect.position * Vector2(900.0, 430.0), impossible_rect.size * Vector2(900.0, 430.0)),
		"current_rect": impossible_rect, "surface_id": "developer_free", "fallback": false,
		"is_route": false, "fixed": true,
	}
	var impossible_blocker := impossible_record.duplicate(true)
	impossible_blocker["object_id"] = "item:earlier_lock"
	var impossible_placed := {"item:earlier_lock": EnvironmentInstanceScript._rect_to_dict(impossible_rect)}
	var impossible := EnvironmentInstanceScript._try_repack_base_conflict_cohort(
		impossible_record,
		{"archetype_id": "missing_fixed_lock_fixture"},
		impossible_placed,
		impossible_placed.duplicate(true),
		{"item:earlier_lock": impossible_blocker},
		{}
	)
	if bool(impossible.get("ok", false)):
		failures.append("An impossible fixed-lock collision did not fail closed after class-valid candidates were exhausted.")

	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, prior_project_path)
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, prior_user_path)
	DeveloperPlacementStoreScript.reload()
	_remove_fixed_lock_fixture_generations()


func _check_generated_route_blocker_repack(failures: Array) -> void:
	var board := Vector2(900.0, 430.0)
	var target_pixel := Rect2(570.0, 116.0, 110.0, 72.0)
	var target_rect := Rect2(target_pixel.position / board, target_pixel.size / board)
	var route_pixel := Rect2(644.0, 80.0, 100.0, 64.0)
	var route_rect := Rect2(route_pixel.position / board, route_pixel.size / board)
	var target_record := {
		"object_id": "game:bar_dice", "object_type": "game", "index": 0,
		"placement_class": "surface_item", "anchor_rect": target_pixel,
		"current_rect": target_rect, "surface_id": "developer_free",
		"fallback": false, "is_route": false, "fixed": true,
	}
	var route_record := {
		"object_id": "event:side_door", "object_type": "event", "index": 0,
		"placement_class": "doorway", "anchor_rect": route_pixel,
		"current_rect": route_rect, "surface_id": "service_door",
		"fallback": false, "is_route": true, "fixed": false,
	}
	var placed := {"event:side_door": EnvironmentInstanceScript._rect_to_dict(route_rect)}
	var solved := EnvironmentInstanceScript._try_repack_base_conflict_cohort(
		target_record,
		{"archetype_id": "bar"},
		placed,
		placed.duplicate(true),
		{"event:side_door": route_record},
		{}
	)
	if not bool(solved.get("ok", false)):
		failures.append("A generated route blocker could not vacate an exact developer placement.")
		return
	var placements: Dictionary = solved.get("placements", {})
	var solved_target: Dictionary = placements.get("game:bar_dice", {})
	var solved_route: Dictionary = placements.get("event:side_door", {})
	var target_result: Rect2 = solved_target.get("rect", Rect2())
	var route_result: Rect2 = solved_route.get("rect", Rect2())
	var route_result_pixel := Rect2(route_result.position * board, route_result.size * board)
	if not target_result.is_equal_approx(target_rect):
		failures.append("Generated-route recovery moved the exact current developer placement.")
	if route_result.is_equal_approx(route_rect) or not EnvironmentPlacementScript.valid_rect({"archetype_id": "bar"}, "doorway", route_result_pixel):
		failures.append("Generated-route recovery did not move its blocker onto a valid doorway support.")
	if target_result.intersects(route_result) and target_result.intersection(route_result).get_area() > 0.000001 \
			or EnvironmentInstanceScript._expanded_object_rect(target_result).intersects(EnvironmentInstanceScript._expanded_object_rect(route_result)) \
			and EnvironmentInstanceScript._expanded_object_rect(target_result).intersection(EnvironmentInstanceScript._expanded_object_rect(route_result)).get_area() > 0.000001:
		failures.append("Generated-route recovery retained ambiguous normal or expanded authority.")


func _check_dense_repack_budget(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var anchor := Rect2(600.0, 32.0, 40.0, 40.0)
	var normalized := Rect2(anchor.position / Vector2(900.0, 430.0), anchor.size / Vector2(900.0, 430.0))
	var records: Array = []
	for index in range(8):
		records.append({
			"object_id": "item:dense_%02d" % index,
			"object_type": "item",
			"index": index,
			"placement_class": "surface_item",
			"anchor_rect": anchor,
			"current_rect": normalized,
			"surface_id": "service_shelf",
			"fallback": false,
			"is_route": false,
			"fixed": false,
		})
	var target_record: Dictionary = records[0]
	var target_candidates := EnvironmentInstanceScript._base_layout_repack_candidates(target_record, environment)
	if target_candidates.is_empty():
		failures.append("The dense-repack performance fixture exposed no semantic target candidate.")
		return
	var started_msec := Time.get_ticks_msec()
	var solved := EnvironmentInstanceScript._solve_base_layout_repack_cohort(
		records,
		environment,
		{},
		{},
		{},
		{str(target_record.get("object_id", "")): [target_candidates[0]]},
		{},
		str(target_record.get("object_id", "")),
		EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_FINE
	)
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	if not bool(solved.get("ok", false)):
		failures.append("The dense deterministic repack fixture did not find its class-valid composition.")
	elif elapsed_msec > 2000:
		failures.append("Dense deterministic repack exceeded its 2000ms focused budget (%dms)." % elapsed_msec)


# Supported-tier recovery is the ordinary dense-room path. It must not enumerate
# or retain the much larger fine 8px grid until an exact supported proof fails.
func _check_lazy_fine_candidate_materialization(failures: Array) -> void:
	var environment := {"archetype_id": "bar"}
	var anchor := Rect2(600.0, 32.0, 40.0, 40.0)
	var normalized := Rect2(anchor.position / Vector2(900.0, 430.0), anchor.size / Vector2(900.0, 430.0))
	var target_record := {
		"object_id": "item:lazy_target",
		"object_type": "item",
		"index": 0,
		"placement_class": "surface_item",
		"anchor_rect": anchor,
		"current_rect": normalized,
		"surface_id": "service_shelf",
		"fallback": false,
		"is_route": false,
		"fixed": false,
	}
	var blocker_record := target_record.duplicate(true)
	blocker_record["object_id"] = "item:lazy_blocker"
	blocker_record["index"] = 1
	var placed := {"item:lazy_blocker": EnvironmentInstanceScript._rect_to_dict(normalized)}
	var candidate_cache: Dictionary = {}
	var solved := EnvironmentInstanceScript._try_repack_base_conflict_cohort(
		target_record,
		environment,
		placed,
		placed.duplicate(true),
		{"item:lazy_blocker": blocker_record},
		candidate_cache
	)
	if not bool(solved.get("ok", false)):
		failures.append("The lazy-candidate supported-tier fixture did not find its class-valid composition.")
		return
	for object_id in ["item:lazy_target", "item:lazy_blocker"]:
		var cached_value: Variant = candidate_cache.get(object_id, null)
		if typeof(cached_value) != TYPE_DICTIONARY:
			failures.append("Supported-tier repack eagerly retained the full fine-grid candidate array for %s." % object_id)
			return
		var cached := cached_value as Dictionary
		if int(cached.get("max_tier", EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_FINE)) \
				!= EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_SUPPORTED:
			failures.append("Supported-tier repack upgraded %s before exact supported exhaustion." % object_id)
		for candidate_value in cached.get("candidates", []):
			var candidate: Dictionary = candidate_value
			if int(candidate.get("tier", EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_FINE)) \
					> EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_SUPPORTED:
				failures.append("Supported-tier repack retained an eagerly enumerated fine-grid candidate for %s." % object_id)
				break
	var cold_full := EnvironmentInstanceScript._base_layout_repack_candidates(
		target_record,
		environment,
		EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_FINE
	)
	var upgraded_full := EnvironmentInstanceScript._cached_base_layout_repack_candidates(
		target_record,
		environment,
		candidate_cache,
		EnvironmentInstanceScript.BASE_REPACK_CANDIDATE_TIER_FINE
	)
	if var_to_bytes(upgraded_full) != var_to_bytes(cold_full):
		failures.append("Fine-tier cache upgrade changed canonical full candidate order, provenance, or ordinals.")


func _check_clique_solver_oracle(failures: Array) -> void:
	var hall_domains: Dictionary = {}
	for object_index in range(6):
		var object_candidates: Array = []
		for slot_index in range(5):
			object_candidates.append(_oracle_candidate(slot_index, slot_index, false))
		hall_domains["object:%02d" % object_index] = object_candidates
	var hall_started_msec := Time.get_ticks_msec()
	var hall_result := EnvironmentInstanceScript._solve_base_layout_repack_clique(hall_domains, "object:00")
	var hall_elapsed_msec := Time.get_ticks_msec() - hall_started_msec
	if bool(hall_result.get("ok", false)):
		failures.append("The clique solver accepted six pairwise-supported objects in five mutually exclusive slots.")
	elif hall_elapsed_msec > 500:
		failures.append("The Hall-capacity rejection exceeded its 500ms focused budget (%dms)." % hall_elapsed_msec)
	# Exercise the exact production color-sort -> object/color-matching bound, not
	# a hand-written approximation.  Degree ties encounter this regular graph in
	# object-major order; the second production rank must group equal geometry and
	# reject the six-partition/five-slot deficit at the root.
	var hall_vertex_objects := PackedInt32Array()
	var hall_vertex_values: Array = []
	for object_index in range(6):
		for candidate_value in hall_domains.get("object:%02d" % object_index, []):
			hall_vertex_objects.append(object_index)
			hall_vertex_values.append(candidate_value)
	var hall_vertex_count := hall_vertex_objects.size()
	var hall_word_count := int(ceil(float(hall_vertex_count) / float(EnvironmentInstanceScript.BASE_REPACK_CLIQUE_WORD_BITS)))
	var hall_adjacency: Array = []
	hall_adjacency.resize(hall_vertex_count)
	for left_vertex in range(hall_vertex_count):
		var neighbors := PackedInt64Array()
		neighbors.resize(hall_word_count)
		for right_vertex in range(hall_vertex_count):
			if left_vertex == right_vertex or int(hall_vertex_objects[left_vertex]) == int(hall_vertex_objects[right_vertex]):
				continue
			if not EnvironmentInstanceScript._base_layout_repack_candidate_geometry_conflicts(
				hall_vertex_values[left_vertex],
				hall_vertex_values[right_vertex]
			):
				EnvironmentInstanceScript._base_layout_repack_clique_mask_add(neighbors, right_vertex)
		hall_adjacency[left_vertex] = neighbors
	var hall_object_rank := PackedInt32Array()
	var hall_active := PackedInt64Array()
	hall_active.resize(hall_word_count)
	for vertex_index in range(hall_vertex_count):
		hall_object_rank.append(vertex_index)
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(hall_active, vertex_index)
	var hall_geometry_rank := EnvironmentInstanceScript._base_layout_repack_clique_geometry_rank(
		hall_vertex_values,
		hall_vertex_objects
	)
	var hall_geometry_colors := EnvironmentInstanceScript._base_layout_repack_clique_color_sort(
		hall_active,
		hall_adjacency,
		hall_geometry_rank
	)
	var hall_ordered_vertices: PackedInt32Array = hall_geometry_colors[0]
	var hall_color_bounds: PackedInt32Array = hall_geometry_colors[1]
	var hall_color_count := int(hall_color_bounds[hall_color_bounds.size() - 1])
	var hall_pipeline_matching := EnvironmentInstanceScript._base_layout_repack_clique_color_matching_bound(
		hall_ordered_vertices,
		hall_color_bounds,
		hall_vertex_objects,
		6,
		hall_color_count
	)
	var hall_bound_stats: Dictionary = {}
	var hall_root_allowed := EnvironmentInstanceScript._base_layout_repack_clique_bounds_allow(
		hall_active,
		6,
		hall_adjacency,
		hall_vertex_objects,
		6,
		[hall_object_rank, hall_geometry_rank],
		hall_bound_stats
	)
	if hall_color_count != 5 or hall_pipeline_matching != 5:
		failures.append("The geometry-major production coloring did not expose exactly five physical slots (colors=%d matching=%d)." % [hall_color_count, hall_pipeline_matching])
	if hall_root_allowed or int(hall_bound_stats.get("matching_rejections", 0)) <= 0:
		failures.append("The production root Hall bound did not reject the six-partition/five-slot deficit through object/color matching.")
	var matching_bound := EnvironmentInstanceScript._base_layout_repack_clique_color_matching_bound(
		PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7]),
		PackedInt32Array([1, 2, 1, 2, 1, 2, 3, 4]),
		PackedInt32Array([0, 0, 1, 1, 2, 2, 3, 3]),
		4,
		4
	)
	if matching_bound != 3:
		failures.append("The object-to-color Hall bound returned %d instead of 3 for a four-color, four-partition deficit." % matching_bound)
	# This three-partition graph is deliberately loose under both production
	# scalar/matching bounds (3 colors, matching 3), but pairwise support removal
	# cascades across two passes and empties the final partition.  It locks the
	# fixed-point nature of arc consistency rather than a one-shot forward check.
	var arc_vertex_objects := PackedInt32Array([0, 0, 0, 1, 1, 1, 2, 2, 2])
	var arc_edges := [
		Vector2i(0, 8), Vector2i(0, 3), Vector2i(0, 5),
		Vector2i(1, 8), Vector2i(1, 3), Vector2i(2, 6),
		Vector2i(2, 7), Vector2i(3, 6), Vector2i(4, 8),
		Vector2i(4, 6), Vector2i(5, 6),
	]
	var arc_adjacency: Array = []
	arc_adjacency.resize(arc_vertex_objects.size())
	for vertex_index in range(arc_vertex_objects.size()):
		var neighbors := PackedInt64Array()
		neighbors.resize(1)
		arc_adjacency[vertex_index] = neighbors
	for edge in arc_edges:
		var left_neighbors: PackedInt64Array = arc_adjacency[edge.x]
		var right_neighbors: PackedInt64Array = arc_adjacency[edge.y]
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(left_neighbors, edge.y)
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(right_neighbors, edge.x)
		arc_adjacency[edge.x] = left_neighbors
		arc_adjacency[edge.y] = right_neighbors
	var arc_active := PackedInt64Array()
	arc_active.resize(1)
	for vertex_index in range(arc_vertex_objects.size()):
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(arc_active, vertex_index)
	var arc_degree_rank := PackedInt32Array([6, 0, 3, 8, 1, 2, 4, 5, 7])
	var arc_object_rank := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8])
	var unpropagated_stats: Dictionary = {}
	if not EnvironmentInstanceScript._base_layout_repack_clique_bounds_allow(
		arc_active,
		3,
		arc_adjacency,
		arc_vertex_objects,
		3,
		[arc_degree_rank, arc_object_rank],
		unpropagated_stats
	):
		failures.append("The multi-step arc fixture was already rejected by the unpropagated scalar/matching bounds.")
	var arc_stats := {"arc_passes": 0, "arc_removals": 0, "arc_rejections": 0}
	var arc_object_masks := EnvironmentInstanceScript._base_layout_repack_clique_object_masks(
		arc_vertex_objects,
		3,
		1
	)
	var arc_reduced := EnvironmentInstanceScript._base_layout_repack_clique_arc_consistency(
		arc_active,
		arc_adjacency,
		arc_vertex_objects,
		3,
		arc_object_masks,
		3,
		arc_stats
	)
	var arc_remaining_objects := EnvironmentInstanceScript._base_layout_repack_clique_distinct_object_count(
		arc_reduced,
		arc_vertex_objects,
		3
	)
	if arc_remaining_objects >= 3 or int(arc_stats.get("arc_passes", 0)) < 2 \
			or int(arc_stats.get("arc_removals", 0)) < 5 \
			or int(arc_stats.get("arc_rejections", 0)) <= 0:
		failures.append("Multi-step arc consistency did not cascade to the exact empty-partition rejection: objects=%d stats=%s." % [arc_remaining_objects, JSON.stringify(arc_stats)])
	# A satisfiable closure crossing the 62-bit mask boundary must retain every
	# solution vertex, discard unsupported decoys, and be idempotent.
	var high_vertex_objects := PackedInt32Array()
	for vertex_index in range(65):
		high_vertex_objects.append(0 if vertex_index < 31 else (1 if vertex_index < 62 else 2))
	var high_adjacency := _oracle_graph_adjacency(65, [
		Vector2i(0, 31), Vector2i(0, 64), Vector2i(31, 64),
	])
	var high_active := _oracle_full_mask(65)
	var high_object_masks := EnvironmentInstanceScript._base_layout_repack_clique_object_masks(
		high_vertex_objects,
		3,
		high_active.size()
	)
	var high_stats: Dictionary = {}
	var high_reduced := EnvironmentInstanceScript._base_layout_repack_clique_arc_consistency(
		high_active,
		high_adjacency,
		high_vertex_objects,
		3,
		high_object_masks,
		3,
		high_stats
	)
	var high_second := EnvironmentInstanceScript._base_layout_repack_clique_arc_consistency(
		high_reduced,
		high_adjacency,
		high_vertex_objects,
		3,
		high_object_masks,
		3,
		{}
	)
	if EnvironmentInstanceScript._base_layout_repack_clique_mask_count(high_reduced) != 3 \
			or not EnvironmentInstanceScript._base_layout_repack_clique_mask_has(high_reduced, 0) \
			or not EnvironmentInstanceScript._base_layout_repack_clique_mask_has(high_reduced, 31) \
			or not EnvironmentInstanceScript._base_layout_repack_clique_mask_has(high_reduced, 64) \
			or not _oracle_masks_equal(high_reduced, high_second):
		failures.append("Arc consistency removed a satisfiable high-word solution or failed closure idempotence.")
	var high_solver_stats: Dictionary = {}
	if not EnvironmentInstanceScript._base_layout_repack_clique_can_complete(
		high_active,
		3,
		high_adjacency,
		high_vertex_objects,
		3,
		high_object_masks,
		[_oracle_degree_rank(high_adjacency), _oracle_identity_rank(65)],
		high_solver_stats,
		{}
	):
		failures.append("The exact solver rejected a satisfiable composition spanning multiple mask words.")
	# The only triangle is reached after decoy candidates fail. This locks exact
	# partition branching: every candidate of the selected object must remain
	# reachable even when earlier candidates have partial cross-object support.
	var prefix_objects := PackedInt32Array([0, 0, 1, 1, 2, 2])
	var prefix_adjacency := _oracle_graph_adjacency(6, [
		Vector2i(0, 2), Vector2i(0, 4), Vector2i(2, 4),
		Vector2i(1, 3), Vector2i(1, 4), Vector2i(3, 5), Vector2i(0, 5),
	])
	var prefix_active := _oracle_full_mask(6)
	var prefix_masks := EnvironmentInstanceScript._base_layout_repack_clique_object_masks(prefix_objects, 3, 1)
	var prefix_stats: Dictionary = {}
	if not EnvironmentInstanceScript._base_layout_repack_clique_can_complete(
		prefix_active,
		3,
		prefix_adjacency,
		prefix_objects,
		3,
		prefix_masks,
		[_oracle_degree_rank(prefix_adjacency), _oracle_identity_rank(6)],
		prefix_stats,
		{}
	) or int(prefix_stats.get("partition_branches", 0)) < 2:
		failures.append("Exact partition branching did not recover the satisfiable clique after failed decoy candidates: %s." % JSON.stringify(prefix_stats))
	# Arbitrary symmetric partition graphs protect exactness independently of the
	# rectangle generator and compare both SAT and UNSAT outcomes to brute force.
	var graph_rng := RandomNumberGenerator.new()
	graph_rng.seed = 0xAC706
	for graph_case in range(96):
		var graph_object_count := graph_rng.randi_range(2, 5)
		var graph_vertex_objects := PackedInt32Array()
		var graph_object_vertices: Array = []
		for object_index in range(graph_object_count):
			var vertices := PackedInt32Array()
			for candidate_index in range(graph_rng.randi_range(1, 4)):
				var vertex_index := graph_vertex_objects.size()
				graph_vertex_objects.append(object_index)
				vertices.append(vertex_index)
			graph_object_vertices.append(vertices)
		var graph_edges: Array = []
		for left_vertex in range(graph_vertex_objects.size()):
			for right_vertex in range(left_vertex + 1, graph_vertex_objects.size()):
				if int(graph_vertex_objects[left_vertex]) != int(graph_vertex_objects[right_vertex]) \
						and graph_rng.randf() < 0.43:
					graph_edges.append(Vector2i(left_vertex, right_vertex))
		var graph_adjacency := _oracle_graph_adjacency(graph_vertex_objects.size(), graph_edges)
		var graph_active := _oracle_full_mask(graph_vertex_objects.size())
		var graph_masks := EnvironmentInstanceScript._base_layout_repack_clique_object_masks(
			graph_vertex_objects,
			graph_object_count,
			graph_active.size()
		)
		var expected_graph := _oracle_partition_graph_has_solution(graph_object_vertices, graph_adjacency, 0, [])
		var actual_graph := EnvironmentInstanceScript._base_layout_repack_clique_can_complete(
			graph_active,
			graph_object_count,
			graph_adjacency,
			graph_vertex_objects,
			graph_object_count,
			graph_masks,
			[_oracle_degree_rank(graph_adjacency), _oracle_identity_rank(graph_vertex_objects.size())],
			{},
			{}
		)
		if actual_graph != expected_graph:
			failures.append("The exact solver disagreed with arbitrary partition-graph brute force in case %d." % graph_case)
			return
	var satisfiable_domains: Dictionary = {}
	for object_index in range(5):
		var object_candidates: Array = []
		for slot_index in range(5):
			object_candidates.append(_oracle_candidate(slot_index, slot_index, false))
			satisfiable_domains["object:%02d" % object_index] = object_candidates
	var satisfiable := EnvironmentInstanceScript._solve_base_layout_repack_clique(satisfiable_domains, "object:00")
	var satisfiable_placements: Dictionary = satisfiable.get("placements", {})
	var priority_placement: Dictionary = satisfiable_placements.get("object:00", {})
	var first_priority_candidate := _oracle_candidate(0, 0, false)
	var priority_rect: Rect2 = priority_placement.get("rect", Rect2())
	var first_priority_rect: Rect2 = first_priority_candidate.get("rect", Rect2())
	if not bool(satisfiable.get("ok", false)) or not _oracle_solution_is_valid(satisfiable_domains, satisfiable.get("placements", {})):
		failures.append("The clique solver rejected or corrupted a five-object/five-slot composition.")
	elif not priority_rect.is_equal_approx(first_priority_rect):
		failures.append("The clique solver did not preserve the priority object's first feasible candidate.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB7A06
	for case_index in range(64):
		var object_count := rng.randi_range(2, 5)
		var slot_count := rng.randi_range(2, 7)
		var domains: Dictionary = {}
		var object_ids: Array = []
		for object_index in range(object_count):
			var object_id := "random:%02d" % object_index
			object_ids.append(object_id)
			var available_slots: Array = []
			for slot_index in range(slot_count):
				available_slots.append(slot_index)
			var candidates: Array = []
			var candidate_count := rng.randi_range(1, mini(5, slot_count))
			for candidate_index in range(candidate_count):
				var selected_index := rng.randi_range(0, available_slots.size() - 1)
				var slot_index := int(available_slots[selected_index])
				available_slots.remove_at(selected_index)
				candidates.append(_oracle_candidate(slot_index, candidate_index, true))
			domains[object_id] = candidates
		var expected := _oracle_candidate_domains_have_solution(domains, object_ids, 0, [])
		var actual := EnvironmentInstanceScript._solve_base_layout_repack_clique(domains, str(object_ids[0]))
		if bool(actual.get("ok", false)) != expected:
			failures.append("The clique solver disagreed with the exhaustive oracle in deterministic case %d." % case_index)
			return
		if expected and not _oracle_solution_is_valid(domains, actual.get("placements", {})):
			failures.append("The clique solver emitted a conflicting placement in deterministic case %d." % case_index)
			return


func _oracle_candidate(slot_index: int, ordinal: int, overlapping_slots: bool) -> Dictionary:
	var column_count := 4
	var step := 0.10 if overlapping_slots else 0.18
	var size := Vector2(0.14, 0.12) if overlapping_slots else Vector2(0.10, 0.10)
	var position := Vector2(0.04 + float(slot_index % column_count) * step, 0.08 + float(slot_index / column_count) * 0.22)
	var rect := Rect2(position, size)
	return {
		"rect": rect,
		"expanded_rect": rect,
		"preferred": ordinal == 0,
		"fallback": false,
		"ordinal": ordinal,
		"key": "%02d" % slot_index,
	}


func _oracle_candidate_domains_have_solution(domains: Dictionary, object_ids: Array, object_index: int, placed: Array) -> bool:
	if object_index >= object_ids.size():
		return true
	for candidate_value in domains.get(str(object_ids[object_index]), []):
		var candidate: Dictionary = candidate_value
		var conflicts := false
		for placed_value in placed:
			if EnvironmentInstanceScript._base_layout_repack_candidate_geometry_conflicts(candidate, placed_value):
				conflicts = true
				break
		if conflicts:
			continue
		placed.append(candidate)
		if _oracle_candidate_domains_have_solution(domains, object_ids, object_index + 1, placed):
			placed.pop_back()
			return true
		placed.pop_back()
	return false


func _oracle_solution_is_valid(domains: Dictionary, placements_value: Variant) -> bool:
	if typeof(placements_value) != TYPE_DICTIONARY:
		return false
	var placements: Dictionary = placements_value
	if placements.size() != domains.size():
		return false
	var object_ids := domains.keys()
	object_ids.sort()
	for left_index in range(object_ids.size()):
		var left_id := str(object_ids[left_index])
		var left: Dictionary = placements.get(left_id, {})
		if left.is_empty():
			return false
		var belongs_to_domain := false
		for candidate_value in domains.get(left_id, []):
			var candidate: Dictionary = candidate_value
			var candidate_rect: Rect2 = candidate.get("rect", Rect2())
			var candidate_expanded: Rect2 = candidate.get("expanded_rect", candidate_rect)
			var left_rect: Rect2 = left.get("rect", Rect2())
			var left_expanded: Rect2 = left.get("expanded_rect", left_rect)
			if candidate_rect.is_equal_approx(left_rect) \
					and candidate_expanded.is_equal_approx(left_expanded) \
					and str(candidate.get("key", "")) == str(left.get("key", "")) \
					and int(candidate.get("ordinal", -1)) == int(left.get("ordinal", -2)):
				belongs_to_domain = true
				break
		if not belongs_to_domain:
			return false
		for right_index in range(left_index + 1, object_ids.size()):
			var right: Dictionary = placements.get(str(object_ids[right_index]), {})
			if right.is_empty() or EnvironmentInstanceScript._base_layout_repack_candidate_geometry_conflicts(left, right):
				return false
	return true


func _oracle_graph_adjacency(vertex_count: int, edges: Array) -> Array:
	var word_count := int(ceil(float(vertex_count) / float(EnvironmentInstanceScript.BASE_REPACK_CLIQUE_WORD_BITS)))
	var result: Array = []
	for _vertex_index in range(vertex_count):
		var neighbors := PackedInt64Array()
		neighbors.resize(word_count)
		result.append(neighbors)
	for edge_value in edges:
		var edge: Vector2i = edge_value
		var left: PackedInt64Array = result[edge.x]
		var right: PackedInt64Array = result[edge.y]
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(left, edge.y)
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(right, edge.x)
		result[edge.x] = left
		result[edge.y] = right
	return result


func _oracle_full_mask(vertex_count: int) -> PackedInt64Array:
	var result := PackedInt64Array()
	result.resize(int(ceil(float(vertex_count) / float(EnvironmentInstanceScript.BASE_REPACK_CLIQUE_WORD_BITS))))
	for vertex_index in range(vertex_count):
		EnvironmentInstanceScript._base_layout_repack_clique_mask_add(result, vertex_index)
	return result


func _oracle_degree_rank(adjacency: Array) -> PackedInt32Array:
	var values: Array = []
	for vertex_index in range(adjacency.size()):
		values.append(vertex_index)
	values.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left_index := int(left_value)
		var right_index := int(right_value)
		var left_neighbors: PackedInt64Array = adjacency[left_index]
		var right_neighbors: PackedInt64Array = adjacency[right_index]
		var left_degree := EnvironmentInstanceScript._base_layout_repack_clique_mask_count(left_neighbors)
		var right_degree := EnvironmentInstanceScript._base_layout_repack_clique_mask_count(right_neighbors)
		return left_degree > right_degree if left_degree != right_degree else left_index < right_index
	)
	var result := PackedInt32Array()
	for vertex_value in values:
		result.append(int(vertex_value))
	return result


func _oracle_identity_rank(vertex_count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for vertex_index in range(vertex_count):
		result.append(vertex_index)
	return result


func _oracle_partition_graph_has_solution(object_vertices: Array, adjacency: Array, object_index: int, selected: Array) -> bool:
	if object_index >= object_vertices.size():
		return true
	var candidates: PackedInt32Array = object_vertices[object_index]
	for vertex_index in candidates:
		var compatible := true
		var neighbors: PackedInt64Array = adjacency[vertex_index]
		for selected_value in selected:
			if not EnvironmentInstanceScript._base_layout_repack_clique_mask_has(neighbors, int(selected_value)):
				compatible = false
				break
		if not compatible:
			continue
		selected.append(vertex_index)
		if _oracle_partition_graph_has_solution(object_vertices, adjacency, object_index + 1, selected):
			selected.pop_back()
			return true
		selected.pop_back()
	return false


func _oracle_masks_equal(left: PackedInt64Array, right: PackedInt64Array) -> bool:
	if left.size() != right.size():
		return false
	for word_index in range(left.size()):
		if int(left[word_index]) != int(right[word_index]):
			return false
	return true


func _write_fixed_lock_fixture(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	var error := file.get_error()
	file.close()
	return error == OK


func _remove_fixed_lock_fixture_generations() -> void:
	for path in [FIXED_LOCK_PROJECT_PATH, FIXED_LOCK_USER_PATH]:
		for suffix in ["", ".tmp", ".bak", ".rollback", ".bak.rollback"]:
			var absolute_path := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)


func _rect_maps_equal_approx(left_value: Variant, right_value: Variant) -> bool:
	if typeof(left_value) != TYPE_DICTIONARY or typeof(right_value) != TYPE_DICTIONARY:
		return false
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	if left.size() != right.size():
		return false
	for object_id_value in left.keys():
		var object_id := str(object_id_value)
		if not right.has(object_id) or not EnvironmentInstanceScript._rect_from_dict(left.get(object_id, {})).is_equal_approx( \
				EnvironmentInstanceScript._rect_from_dict(right.get(object_id, {}))):
			return false
	return true


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


# Run generation may add living-world and character-chain controls after the
# archetype is hydrated. Its explicit deferred path must preserve the authored
# layout until that complete control set is ready, while default restore callers
# retain the existing eager-grounding contract.
func _check_deferred_layout_finalization(failures: Array) -> void:
	var archetype := {
		"id": "corner_store",
		"kind": "venue",
		"tier": 1,
		"name_prefixes": ["Deferred"],
		"name_nouns": ["Room"],
		"game_pool": [],
		"game_count": 0,
		"event_count": 0,
		"service_pool": ["house_drink"],
		"travel_hooks": ["leave"],
		"layout": {
			"event_spots": [[592, 180], [76, 346]],
			"service_spots": [[350, 178]],
			"travel_spots": [[780, 258]],
		},
	}
	var scenario := {
		"id": "postfix06_2_deferred_scenario",
		"archetype_id": "corner_store",
		"display_name": "Deferred Scenario",
		"mutations": {},
	}
	var rng := RngStream.new()
	rng.configure(6202)
	var deferred := EnvironmentInstanceScript.from_archetype(archetype, 0, rng, null, {}, scenario, true)
	if str(deferred.scenario_state.get("id", "")) != str(scenario.get("id", "")):
		failures.append("Deferred archetype hydration dropped its selected scenario state.")
	for generated_key in [
		"generated_object_rect_version", "grounding_signature", "object_rects",
		"placement_classes", "placement_surfaces", "placement_errors",
		"placement_fallback_ids", "placement_adjusted_ids",
	]:
		if deferred.layout.has(generated_key):
			failures.append("Deferred archetype generation materialized %s before late controls were complete." % generated_key)
	var complete_raw := deferred.to_dict()
	complete_raw["event_ids"] = ["town_rumor_staff"]
	var finalized_layout := EnvironmentInstanceScript.ensure_generated_layout(complete_raw)
	if int(finalized_layout.get("generated_object_rect_version", 0)) != EnvironmentInstanceScript.GENERATED_LAYOUT_VERSION:
		failures.append("The deferred environment did not ground at its explicit finalization boundary.")
	var object_rects: Dictionary = finalized_layout.get("object_rects", {})
	for required_object_id in ["event:town_rumor_staff", "service:house_drink", "travel:leave"]:
		if not object_rects.has(required_object_id):
			failures.append("Deferred finalization omitted complete control %s." % required_object_id)
	if not (finalized_layout.get("placement_errors", []) as Array).is_empty() \
			or not (finalized_layout.get("placement_fallback_ids", []) as Array).is_empty():
		failures.append("Deferred finalization required errors or unsafe fallbacks: %s / %s." % [JSON.stringify(finalized_layout.get("placement_errors", [])), JSON.stringify(finalized_layout.get("placement_fallback_ids", []))])
	var finalized_environment := complete_raw.duplicate(true)
	finalized_environment["layout"] = finalized_layout
	var repeated_layout := EnvironmentInstanceScript.ensure_generated_layout(finalized_environment)
	if JSON.stringify(repeated_layout) != JSON.stringify(finalized_layout):
		failures.append("A complete deferred layout changed when finalized a second time.")
	var eager_restore := EnvironmentInstanceScript.from_dict(complete_raw)
	if JSON.stringify(eager_restore.layout) != JSON.stringify(finalized_layout):
		failures.append("Default environment hydration no longer matches explicit complete finalization.")


# Character-chain projection participates in both raw generation and eager
# restore/live mutation. Raw generation must retain the one explicit finalization
# boundary, while a membership change on a materialized room reconciles at once.
func _check_character_chain_deferred_reconciliation(failures: Array) -> void:
	var run_state = RunStateScript.new()
	run_state.story_flags["chain06_world_anchors_seeded"] = true
	var environment := {
		"id": "pawn_shop_contract",
		"archetype_id": "pawn_shop",
		"world_node_id": "pawn_shop",
		"scenario_id": "pawn_shop_estate_lot_day",
		"scenario_state": {"id": "pawn_shop_estate_lot_day"},
		"event_ids": [],
		"layout": {"event_spots": [[280, 180], [460, 180]]},
	}
	CharacterChainModelScript.apply_to_environment(run_state, environment)
	if not (environment.get("event_ids", []) as Array).has("chain06_sal_estate_item"):
		failures.append("Character-chain raw projection did not inject the eligible estate event.")
	var raw_layout: Dictionary = environment.get("layout", {})
	if raw_layout.has("generated_object_rect_version") or raw_layout.has("grounding_signature") or raw_layout.has("object_rects"):
		failures.append("Character-chain raw projection finalized layout before the controlled generation boundary.")
	CharacterChainModelScript.apply_to_environment(run_state, environment)
	var repeated_raw_layout: Dictionary = environment.get("layout", {})
	if repeated_raw_layout.has("generated_object_rect_version") or repeated_raw_layout.has("grounding_signature") or repeated_raw_layout.has("object_rects"):
		failures.append("Idempotent character-chain raw projection materialized layout on its second pass.")
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment)
	var materialized_layout: Dictionary = environment.get("layout", {})
	var materialized_rects: Dictionary = materialized_layout.get("object_rects", {})
	if not materialized_rects.has("event:chain06_sal_estate_item"):
		failures.append("Explicit finalization omitted the deferred character-chain event rectangle.")
	var stable_materialized := JSON.stringify(materialized_layout)
	CharacterChainModelScript.apply_to_environment(run_state, environment)
	if JSON.stringify(environment.get("layout", {})) != stable_materialized:
		failures.append("Idempotent character-chain projection changed an already materialized layout.")
	run_state.story_flags["chain06_sal_item_taken"] = true
	CharacterChainModelScript.apply_to_environment(run_state, environment)
	if (environment.get("event_ids", []) as Array).has("chain06_sal_estate_item"):
		failures.append("Character-chain materialized reconciliation retained an inactive event.")
	var reconciled_rects: Dictionary = (environment.get("layout", {}) as Dictionary).get("object_rects", {})
	if reconciled_rects.has("event:chain06_sal_estate_item"):
		failures.append("Character-chain materialized reconciliation retained stale event geometry.")


# Town scenario priming is called at every destination build. A valid seed may be
# reused only inside the same operating cycle: repeated same-cycle calls must not
# re-resolve or recopy the authored sequence, while the next day must reselect.
func _check_scenario_prime_cache_lifecycle(failures: Array) -> void:
	var library = ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		failures.append("Scenario-prime cache fixture could not load production content: %s" % JSON.stringify(library.validation_errors))
		return
	var seed := "POSTFIX06_2-SCENARIO-PRIME-CACHE"
	var run_state = RunStateScript.new()
	run_state.start_new(seed, RunStateScript.custom_challenge("postfix06_2_scenario_prime_cache", seed, {
		"scenario_pins": {"bar": "bar_fight_night"},
		"scenario_pins_apply_mutations": true,
	}))
	run_state.game_clock_minutes = 720
	var map_data := {"nodes": [{"id": "bar", "archetype_id": "bar"}], "edges": []}
	run_state.configure_town_world(map_data, false)
	var generator = RunGeneratorScript.new(library)
	generator.set_world_environment_timing_enabled(true)
	generator._prime_town_scenarios(run_state, map_data)
	var first_stage: Dictionary = generator._world_scenario_prime_stages_usec.get("bar", {})
	var first_definition := run_state._seeded_scenario_definition_for_node_readonly("bar")
	var first_cycle := run_state.environment_situation_cycle("bar")
	if bool(first_stage.get("cached", false)) or not first_stage.has("select"):
		failures.append("Scenario-prime cache fixture treated its first seed as cached.")
	if str(first_definition.get("id", "")) != "bar_fight_night" or str(first_cycle.get("cycle_id", "")).is_empty():
		failures.append("Scenario-prime cache fixture did not establish the pinned first-cycle seed.")
		return
	var first_snapshot := JSON.stringify(run_state.to_save_snapshot())
	generator._prime_town_scenarios(run_state, map_data)
	var same_cycle_stage: Dictionary = generator._world_scenario_prime_stages_usec.get("bar", {})
	if not bool(same_cycle_stage.get("cached", false)):
		failures.append("Scenario priming re-resolved an already seeded venue in the same operating cycle.")
	if JSON.stringify(run_state.to_save_snapshot()) != first_snapshot:
		failures.append("Same-cycle scenario-prime caching changed serialized run state.")
	var restored_run = RunStateScript.new()
	restored_run.from_dict(run_state.to_save_snapshot())
	var restored_before := JSON.stringify(restored_run.to_save_snapshot())
	var restored_rng_state: int = restored_run.rng_state
	var restored_generator = RunGeneratorScript.new(library)
	restored_generator.set_world_environment_timing_enabled(true)
	restored_generator._prime_town_scenarios(restored_run, map_data)
	var restored_stage: Dictionary = restored_generator._world_scenario_prime_stages_usec.get("bar", {})
	if not bool(restored_stage.get("cached", false)):
		failures.append("A restored same-cycle scenario seed was needlessly re-resolved.")
	if JSON.stringify(restored_run.to_save_snapshot()) != restored_before or restored_run.rng_state != restored_rng_state:
		failures.append("Restored same-cycle scenario-prime caching changed save or RNG state.")

	run_state.game_clock_minutes += 1440
	var rollover_rng_state: int = run_state.rng_state
	if run_state._seeded_scenario_definition_for_node_readonly("bar").is_empty():
		failures.append("Scenario-prime rollover fixture no longer exposes the stale identity-compatible seed that the cycle guard must reject.")
	generator._prime_town_scenarios(run_state, map_data)
	var rollover_stage: Dictionary = generator._world_scenario_prime_stages_usec.get("bar", {})
	var second_cycle := run_state.environment_situation_cycle("bar")
	if bool(rollover_stage.get("cached", false)) or not rollover_stage.has("select"):
		failures.append("Scenario priming reused a seed after the venue entered a new operating cycle.")
	if str(second_cycle.get("cycle_id", "")) == str(first_cycle.get("cycle_id", "")):
		failures.append("Scenario priming did not advance the venue lifecycle after a full-day rollover.")
	if run_state.rng_state != rollover_rng_state:
		failures.append("Scenario priming changed the canonical run RNG during lifecycle rollover.")
	generator._prime_town_scenarios(run_state, map_data)
	var repeated_rollover_stage: Dictionary = generator._world_scenario_prime_stages_usec.get("bar", {})
	if not bool(repeated_rollover_stage.get("cached", false)):
		failures.append("Scenario priming did not cache the freshly selected rollover seed.")


# Initial generation already seals scenario semantics inside RunGenerator's
# atomic install. The result boundary must carry that receipt so presentation
# harnesses cannot pay for a second identical finalization.
func _check_initial_generation_finalization_receipt(failures: Array) -> void:
	var library = ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		failures.append("Initial-generation receipt fixture could not load production content: %s" % JSON.stringify(library.validation_errors))
		return
	var seed := "POSTFIX06_2-INITIAL-FINALIZATION-RECEIPT"
	var run_state = RunStateScript.new()
	run_state.start_new(seed, RunStateScript.custom_challenge("postfix06_2_initial_finalization_receipt", seed, {
		"scenario_pins": {"bar": "bar_fight_night"},
		"scenario_pins_apply_mutations": true,
	}))
	run_state.game_clock_minutes = 720
	var generator = RunGeneratorScript.new(library)
	if not generator.has_method("next_environment_result"):
		failures.append("RunGenerator has no receipt-bearing initial-generation result boundary.")
		return
	var generated: Dictionary = generator.next_environment_result(run_state, "bar", true)
	if not bool(generated.get("ok", false)):
		failures.append("Receipt-bearing initial generation failed: %s" % JSON.stringify(generated.get("errors", [])))
		return
	if not bool(generated.get("scenario_finalized", false)):
		failures.append("Initial generation omitted its atomic scenario-finalization receipt.")
	if str(generated.get("target_id", "")) != "bar" or run_state.current_world_node_id() != "bar":
		failures.append("Initial-generation receipt was not bound to the requested installed Bar node.")
	var returned_environment: Dictionary = generated.get("environment", {}) if typeof(generated.get("environment", {})) == TYPE_DICTIONARY else {}
	if var_to_bytes(returned_environment) != var_to_bytes(run_state.current_environment):
		failures.append("Initial-generation receipt did not return the exact sealed installed environment.")
	var installed_audit: Dictionary = run_state.current_environment.get("scenario_layout_audit", {}) if typeof(run_state.current_environment.get("scenario_layout_audit", {})) == TYPE_DICTIONARY else {}
	if str(run_state.current_environment.get("scenario_id", "")) != "bar_fight_night" \
			or not run_state._scenario_semantic_ready() or not bool(installed_audit.get("valid", false)):
		failures.append("Initial generation claimed a finalization receipt without a sealed installed room.")
	var tampered_generation := generated.duplicate(true)
	var tampered_receipt: Dictionary = tampered_generation.get("finalization_receipt", {}) if typeof(tampered_generation.get("finalization_receipt", {})) == TYPE_DICTIONARY else {}
	tampered_receipt["inactive"] = true
	tampered_generation["finalization_receipt"] = tampered_receipt
	var tampered_failures: Array = []
	var tampered_result := HarnessProductionFidelityScript.finalize_arrival(
		run_state,
		library,
		tampered_failures,
		"initial-generation tampered inactive receipt",
		{},
		tampered_generation
	)
	if bool(tampered_result.get("ok", false)) or tampered_failures.is_empty():
		failures.append("Receipt-aware harness accepted an inactive receipt for an active sealed scenario.")
	var viewport_only_before := var_to_bytes(run_state.current_environment)
	var viewport_only_failures: Array = []
	var viewport_only_result := HarnessProductionFidelityScript.finalize_arrival(
		run_state,
		library,
		viewport_only_failures,
		"initial-generation viewport-only receipt context",
		HarnessProductionFidelityScript.DEFAULT_LAYOUT_CONTEXT,
		generated
	)
	var viewport_only_finalization: Dictionary = viewport_only_result.get("finalization", {}) if typeof(viewport_only_result.get("finalization", {})) == TYPE_DICTIONARY else {}
	if not bool(viewport_only_result.get("ok", false)) or not viewport_only_failures.is_empty():
		failures.append("Receipt-aware harness could not reuse an install seal for a viewport-only hint: %s" % JSON.stringify(viewport_only_failures))
	elif not bool(viewport_only_finalization.get("already_finalized", false)):
		failures.append("Receipt-aware harness finalized twice for a non-material viewport-only hint.")
	elif var_to_bytes(run_state.current_environment) != viewport_only_before:
		failures.append("Receipt-aware harness mutated the sealed environment for a non-material viewport-only hint.")
	var context_failures: Array = []
	var requested_context := {"reduce_motion": true}
	var context_result := HarnessProductionFidelityScript.finalize_arrival(
		run_state,
		library,
		context_failures,
		"initial-generation receipt context",
		requested_context,
		generated
	)
	if not bool(context_result.get("ok", false)) or not context_failures.is_empty():
		failures.append("Receipt-aware harness could not finalize a changed material layout context: %s" % JSON.stringify(context_failures))
	elif run_state.current_environment.get("scenario_layout_context", {}) != requested_context:
		failures.append("Receipt-aware harness reused a seal from a different material layout context.")
	var same_node_before := var_to_bytes(run_state.to_save_snapshot())
	var rejected_same_node: Dictionary = generator.next_environment_result(run_state, "bar", false)
	if bool(rejected_same_node.get("ok", false)):
		failures.append("Receipt-bearing generation accepted an unchanged same-node result without a real install.")
	if var_to_bytes(run_state.to_save_snapshot()) != same_node_before:
		failures.append("Rejected same-node generation did not restore the exact pre-call run snapshot.")

	var invalid_seed := "POSTFIX06_2-INITIAL-FINALIZATION-ROLLBACK"
	var invalid_run = RunStateScript.new()
	invalid_run.start_new(invalid_seed, RunStateScript.custom_challenge("postfix06_2_initial_finalization_rollback", invalid_seed))
	var invalid_before := var_to_bytes(invalid_run.to_save_snapshot())
	var invalid_generator = RunGeneratorScript.new(library)
	var rejected_invalid: Dictionary = invalid_generator.next_environment_result(invalid_run, "postfix06_2_missing_node", true)
	if bool(rejected_invalid.get("ok", false)):
		failures.append("Receipt-bearing generation accepted a missing explicit destination.")
	if var_to_bytes(invalid_run.to_save_snapshot()) != invalid_before or not invalid_run.current_environment.is_empty():
		failures.append("Rejected initial generation left world/scenario state or a fallback room installed.")


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
