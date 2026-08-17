extends SceneTree

const PUSHER_DETERMINISM_ACTIONS := 200
const PUSHER_EV_ACTIONS := 2400
const PUSHER_VARIATION_EV_ACTIONS := 600

var coin_pusher_snapshot_boundary_exercised := false


func _check_coin_pusher_contract(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	if definition.is_empty():
		failures.append("Quarter Falls game definition is missing.")
		return
	var game: GameModule = CoinPusherGameScript.new()
	game.setup(definition, library)
	_check_coin_pusher_data_contract(library, definition, failures)
	_check_coin_pusher_definition_routing(library, definition, failures)
	_check_coin_pusher_production_rider(game, library, failures)
	_check_coin_pusher_alarm_audio(failures)
	_check_coin_pusher_canonical_probe(failures)
	_check_coin_pusher_hot_solver_exact_twin(failures)
	_check_coin_pusher_profile_invariance(failures)
	_check_coin_pusher_surface_liveness(game, failures)
	_check_coin_pusher_snapshot_renderer_boundary(game, failures)
	if not coin_pusher_snapshot_boundary_exercised:
		failures.append("Coin Pusher synthetic snapshot boundary contract did not execute through its final assertion sentinel.")
	_check_coin_pusher_visible_timing(game, failures)
	_check_coin_pusher_presentation_replay(game, failures)
	_check_coin_pusher_feature_reconciliation(game, failures)
	_check_coin_pusher_discrete_solver(definition, failures)
	_check_coin_pusher_presentation_event_authority_invariance(failures)
	_check_coin_pusher_read_boundaries(game, failures)
	_check_coin_pusher_determinism(game, failures)
	_check_coin_pusher_security_bands(game, failures)
	_check_coin_pusher_force_matrix(game, definition, failures)
	_check_coin_pusher_nudge_alarm(game, library, failures)
	_check_coin_pusher_persistence_and_reset(game, failures)
	_check_coin_pusher_prize_items(game, failures)
	_check_coin_pusher_items(game, failures)
	_check_coin_pusher_economy(game, definition, failures)
	_check_pusher_variation_data(definition, failures)
	_check_jackpot_ridge_lifecycle(game, definition, failures)
	_check_vault_drop_contract(game, definition, failures)
	_check_pusher_variation_distribution(game, failures)
	_check_pusher_variation_determinism_and_ev(game, definition, failures)


func _check_coin_pusher_profile_invariance(failures: Array) -> void:
	var source := CoinPusherSolverScript.create(_configured_rng(8799), 48, 32, 5)
	var normal_state := source.duplicate(true)
	var profiled_state := source.duplicate(true)
	var config := {
		"captured_upper_phase_fp": 1700,
		"captured_lower_phase_fp": 2300,
		"push_scale": 3,
		"capture_presentation_trace": true,
	}
	var normal_result := CoinPusherSolverScript.step_action(normal_state, config)
	var profiled_config := config.duplicate(true)
	profiled_config["_debug_profile_stages"] = true
	var profiled_result := CoinPusherSolverScript.step_action(profiled_state, profiled_config)
	var profile: Dictionary = profiled_result.get("debug_stage_timing_usec", {}) if typeof(profiled_result.get("debug_stage_timing_usec", {})) == TYPE_DICTIONARY else {}
	profiled_result.erase("debug_stage_timing_usec")
	if JSON.stringify(normal_state) != JSON.stringify(profiled_state) or JSON.stringify(normal_result) != JSON.stringify(profiled_result):
		failures.append("Coin Pusher test-only stage profiling changed authoritative state or the production action result.")
	for stage in ["pack", "push_integrate_48_ticks", "collision_visited_setup", "grid", "collisions", "supports", "trace_construction", "final_scan", "writeback", "solver_result_assembly", "solver_total"]:
		if not profile.has(stage) or int(profile.get(stage, -1)) < 0:
			failures.append("Coin Pusher test-only stage profile omitted the nonnegative %s measurement." % stage)
	if normal_state.has("debug_stage_timing_usec") or normal_result.has("debug_stage_timing_usec"):
		failures.append("Coin Pusher stage profiling leaked into an authoritative state or non-profiled result.")


func _check_coin_pusher_hot_solver_exact_twin(failures: Array) -> void:
	var full_cap := CoinPusherSolverScript.create(_configured_rng(8800), 160, 160, 5)
	CoinPusherSolverScript.add_coin(full_cap, _configured_rng(8900), 2, 5)
	if not CoinPusherSolverScript.hot_state_eligible_for_test(full_cap):
		failures.append("Packed Coin Pusher oracle matrix did not actually exercise the production hot path.")
	_assert_coin_pusher_hot_solver_twin(full_cap, {
		"captured_upper_phase_fp": 1700, "captured_lower_phase_fp": 2300, "push_scale": 3,
	}, "full-cap drop without replay", failures)
	_assert_coin_pusher_hot_solver_twin(full_cap, {
		"captured_upper_phase_fp": 5100, "captured_lower_phase_fp": 6900, "push_scale": 5,
		"capture_presentation_trace": true, "nudge_x": 1200, "nudge_y": -4200, "aimed_x": 50000, "nudge_radius": 100000,
	}, "full-cap nudge with replay", failures)
	_assert_coin_pusher_hot_solver_twin(full_cap, {
		"captured_upper_phase_fp": 8500, "captured_lower_phase_fp": 11500, "push_scale": 4,
		"upper_locked": true, "lower_locked": true, "ridge_double": true, "emit_presentation_events": false,
	}, "locked ridge action without presentation events", failures)

	var compaction := CoinPusherSolverScript.create(_configured_rng(8803), 160, 150, 5)
	CoinPusherSolverScript.add_feature(compaction, "puck", "oracle_puck", 1, 31000, 5, {"mass": 3})
	CoinPusherSolverScript.add_feature(compaction, "fragment", "oracle_fragment", 2, 47000, 5, {"mass": 2})
	CoinPusherSolverScript.add_feature(compaction, "rider", "oracle_rider", 3, 69000, 5, {"mass": 4})
	var compaction_bodies: Array = compaction.get("bodies", [])
	for index in range(3):
		var body: Dictionary = compaction_bodies[index]
		body["y"] = CoinPusherSolverScript.FRONT_EDGE - int(body.get("radius", CoinPusherSolverScript.COIN_RADIUS)) - 10
		body["x"] = 50000 if index == 0 else -int(body.get("radius", CoinPusherSolverScript.COIN_RADIUS)) - 10 if index == 1 else 50000
		body["sleeping"] = false
	_assert_coin_pusher_hot_solver_twin(compaction, {
		"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true,
	}, "exit compaction with all physical feature kinds", failures)

	var sparse := CoinPusherSolverScript.create(_configured_rng(8804), 48, 0, 5)
	sparse["bodies"] = [{"id": "sparse_oracle", "kind": "coin", "x": 50000, "y": 30000, "z": 9000, "cap_pressure_ticks": -3, "cap_pressure_accel": -7}]
	var sparse_value: Variant = JSON.parse_string(JSON.stringify(sparse))
	_assert_coin_pusher_hot_solver_twin(sparse_value as Dictionary, {
		"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true,
	}, "cold sparse JSON body with negative optional pressure fields", failures)
	var duplicate_ids := CoinPusherSolverScript.create(_configured_rng(8806), 48, 0, 5)
	duplicate_ids["bodies"] = [
		_solver_body("duplicate_oracle", "coin", 48000, 30000, 0, false),
		_solver_body("duplicate_oracle", "coin", 52000, 30000, 0, true),
	]
	_assert_coin_pusher_hot_solver_twin(duplicate_ids, {"upper_locked": true, "lower_locked": true}, "duplicate-id reference fallback", failures)
	var aliased_body := _solver_body("aliased_oracle", "coin", 50000, 30000, 0, false)
	var aliased_reference := CoinPusherSolverScript.create(_configured_rng(8807), 48, 0, 5)
	var aliased_hot := aliased_reference.duplicate(true)
	aliased_reference["bodies"] = [aliased_body, aliased_body]
	var hot_alias_body := aliased_body.duplicate(true)
	aliased_hot["bodies"] = [hot_alias_body, hot_alias_body]
	var alias_config := {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true}
	var alias_reference_result := CoinPusherSolverScript.step_action_reference_for_test(aliased_reference, alias_config)
	var alias_hot_result := CoinPusherSolverScript.step_action(aliased_hot, alias_config)
	if JSON.stringify(aliased_reference) != JSON.stringify(aliased_hot) or JSON.stringify(alias_reference_result) != JSON.stringify(alias_hot_result):
		failures.append("Packed Coin Pusher solver did not preserve aliased-body reference semantics through its duplicate-id fallback.")
	var invalid_member := CoinPusherSolverScript.create(_configured_rng(8808), 48, 0, 5)
	invalid_member["bodies"] = ["invalid_body", _solver_body("valid_after_invalid", "coin", 50000, 30000, 0, false)]
	_assert_coin_pusher_hot_solver_twin(invalid_member, {"upper_locked": true, "lower_locked": true}, "non-dictionary body reference fallback", failures)
	var ordering_trap := CoinPusherSolverScript.create(_configured_rng(8809), 48, 0, 5)
	ordering_trap["bodies"] = [
		_solver_body("order_left", "coin", 50000, 30000, 3400, false),
		_solver_body("order_axis_tie", "coin", 54000, 34000, 3400, true),
		_solver_body("order_support_a", "coin", 48000, 30000, 1700, true),
		_solver_body("order_support_b", "coin", 52000, 30000, 1700, true),
		_solver_body("order_neighbor_cell", "coin", 59000, 30000, 3400, true),
	]
	_assert_coin_pusher_hot_solver_twin(ordering_trap, {
		"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true,
	}, "frozen-grid neighbor order, axis tie, and strict support tie", failures)
	var center_crossing := CoinPusherSolverScript.create(_configured_rng(8812), 48, 0, 5)
	center_crossing["bodies"] = [
		_solver_body("crossing_left", "coin", 9999, 30000, 3400, false),
		_solver_body("crossing_right", "coin", 6500, 30000, 3400, false),
		_solver_body("new_center_neighbor", "coin", 20001, 30000, 3400, false),
		_solver_body("crossing_support", "coin", 9500, 30000, 1700, true),
	]
	_assert_coin_pusher_hot_solver_twin(center_crossing, {
		"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true,
	}, "within-tick broadphase-center crossing with frozen candidate cache", failures)
	var int64_hostile := CoinPusherSolverScript.create(_configured_rng(8810), 48, 0, 5)
	int64_hostile["bodies"] = [_solver_body("int64_hostile", "coin", 50000, 30000, 0, false)]
	var int64_body: Dictionary = (int64_hostile.get("bodies", []) as Array)[0]
	int64_body["vx"] = 2147483000
	int64_body["vz"] = -2147483000
	int64_body["cap_pressure_ticks"] = 2147483000
	int64_body["cap_pressure_accel"] = 2147483000
	if CoinPusherSolverScript.hot_state_eligible_for_test(int64_hostile):
		failures.append("Packed Coin Pusher accepted an int64 hostile state without safe arithmetic headroom.")
	_assert_coin_pusher_hot_solver_twin(int64_hostile, {"upper_locked": true, "lower_locked": true}, "int64 scalar fallback", failures)
	var crossing_hostile := CoinPusherSolverScript.create(_configured_rng(8811), 48, 0, 5)
	crossing_hostile["bodies"] = [_solver_body("grid_crossing_hostile", "coin", 50000, 30000, 190000, false)]
	var crossing_body: Dictionary = (crossing_hostile.get("bodies", []) as Array)[0]
	crossing_body["vz"] = 10000000
	if not CoinPusherSolverScript.hot_state_eligible_for_test(crossing_hostile):
		failures.append("Packed Coin Pusher high-motion oracle did not exercise the exact-order overflow-grid path.")
	_assert_coin_pusher_hot_solver_twin(crossing_hostile, {"upper_locked": true, "lower_locked": true}, "in-range-entry high-motion overflow grid", failures)
	var over_count := CoinPusherSolverScript.create(_configured_rng(8812), 512, 0, 5)
	var over_count_bodies: Array = []
	for body_index in range(257):
		over_count_bodies.append(_solver_body("over_count_%03d" % body_index, "coin", 50000, 30000, 0, true))
	over_count["bodies"] = over_count_bodies
	if CoinPusherSolverScript.hot_state_eligible_for_test(over_count):
		failures.append("Packed Coin Pusher accepted more bodies than its proven arithmetic/pair-grid ceiling.")
	_assert_coin_pusher_hot_solver_twin(over_count, {"upper_locked": true, "lower_locked": true}, "over-body-cap fallback", failures)
	var hostile_config_source := CoinPusherSolverScript.create(_configured_rng(8813), 48, 0, 5)
	hostile_config_source["bodies"] = [_solver_body("hostile_config_body", "coin", 50000, 30000, 0, true)]
	var hostile_config := {"upper_locked": true, "lower_locked": true, "nudge_x": 2147483000, "nudge_y": -2147483000, "push_scale": 2147483000}
	if CoinPusherSolverScript.hot_state_eligible_for_test(hostile_config_source, hostile_config):
		failures.append("Packed Coin Pusher accepted hostile config impulses outside its proven arithmetic envelope.")
	_assert_coin_pusher_hot_solver_twin(hostile_config_source, hostile_config, "hostile nudge and push-scale config fallback", failures)
	for phase_locked in [false, true]:
		var hostile_phase := CoinPusherSolverScript.create(_configured_rng(8814 + int(phase_locked)), 48, 0, 5)
		hostile_phase["upper_phase_fp"] = 2147483000
		hostile_phase["lower_phase_fp"] = -2147483000
		var hostile_phase_config := {"upper_locked": phase_locked, "lower_locked": phase_locked}
		if CoinPusherSolverScript.hot_state_eligible_for_test(hostile_phase, hostile_phase_config):
			failures.append("Packed Coin Pusher accepted hostile stored phases for the %s phase path." % ("locked" if phase_locked else "unlocked"))
		_assert_coin_pusher_hot_solver_twin(hostile_phase, hostile_phase_config, "hostile stored phases (%s) fallback" % ("locked" if phase_locked else "unlocked"), failures)

	var sequence_source := CoinPusherSolverScript.create(_configured_rng(8805), 160, 150, 5)
	CoinPusherSolverScript.add_coin(sequence_source, _configured_rng(8905), 4, 5)
	var reference_sequence := sequence_source.duplicate(true)
	var hot_sequence := sequence_source.duplicate(true)
	var first_config := {"captured_upper_phase_fp": 2400, "captured_lower_phase_fp": 7600, "push_scale": 4, "capture_presentation_trace": true}
	var reference_first := CoinPusherSolverScript.step_action_reference_for_test(reference_sequence, first_config)
	var hot_first := CoinPusherSolverScript.step_action(hot_sequence, first_config)
	var reference_reload: Dictionary = JSON.parse_string(JSON.stringify(reference_sequence)) as Dictionary
	var hot_reload: Dictionary = JSON.parse_string(JSON.stringify(hot_sequence)) as Dictionary
	var second_config := {"nudge_x": -1600, "nudge_y": -3600, "aimed_x": 72000, "nudge_radius": 38000, "capture_presentation_trace": true}
	var reference_second := CoinPusherSolverScript.step_action_reference_for_test(reference_reload, second_config)
	var hot_second := CoinPusherSolverScript.step_action(hot_reload, second_config)
	if JSON.stringify(reference_first) != JSON.stringify(hot_first) or JSON.stringify(reference_second) != JSON.stringify(hot_second) \
			or JSON.stringify(reference_reload) != JSON.stringify(hot_reload):
		failures.append("Packed Coin Pusher solver changed an exact two-action save/reload sequence versus the dictionary oracle.")

	for seed_index in range(8):
		var reference_state := CoinPusherSolverScript.create(_configured_rng(9000 + seed_index), 160, 150 + seed_index % 3, 5)
		var hot_state := reference_state.duplicate(true)
		for action_index in range(10):
			if action_index % 3 == 0:
				CoinPusherSolverScript.add_coin(reference_state, _configured_rng(10000 + seed_index * 20 + action_index), (seed_index + action_index) % 5, 5, 1 + action_index % 2)
				CoinPusherSolverScript.add_coin(hot_state, _configured_rng(10000 + seed_index * 20 + action_index), (seed_index + action_index) % 5, 5, 1 + action_index % 2)
			var sequence_config := {
				"captured_upper_phase_fp": (seed_index * 1300 + action_index * 1700) % CoinPusherSolverScript.PHASE_PERIOD,
				"captured_lower_phase_fp": (seed_index * 1900 + action_index * 2300) % CoinPusherSolverScript.PHASE_PERIOD,
				"push_scale": 1 if action_index % 4 == 0 else 6 if action_index % 4 == 1 else 3 + action_index % 3,
				"upper_locked": action_index % 7 == 0,
				"lower_locked": action_index % 6 == 0,
				"ridge_double": action_index % 5 == 0,
				"capture_presentation_trace": action_index % 2 == 0,
				"emit_presentation_events": action_index % 4 < 2,
			}
			if action_index % 3 == 1:
				sequence_config.merge({
					"nudge_x": -1800 + seed_index * 300, "nudge_y": -3200 - action_index * 170,
					"aimed_x": 18000 + ((seed_index + action_index) % 5) * 16000, "nudge_radius": 24000 + action_index * 1800,
				})
			if not CoinPusherSolverScript.hot_state_eligible_for_test(hot_state, sequence_config):
				failures.append("Packed Coin Pusher carried oracle seed %d action %d unexpectedly selected the dictionary fallback." % [seed_index, action_index])
				break
			var reference_action := CoinPusherSolverScript.step_action_reference_for_test(reference_state, sequence_config)
			var hot_action := CoinPusherSolverScript.step_action(hot_state, sequence_config)
			var state_equal := JSON.stringify(reference_state) == JSON.stringify(hot_state)
			var result_equal := JSON.stringify(reference_action) == JSON.stringify(hot_action)
			if not state_equal or not result_equal:
				failures.append("Packed Coin Pusher solver diverged in carried sequence seed %d action %d config %s (state=%s result=%s)." % [seed_index, action_index, JSON.stringify(sequence_config), state_equal, result_equal])
				break
			if action_index == 4:
				reference_state = JSON.parse_string(JSON.stringify(reference_state)) as Dictionary
				hot_state = JSON.parse_string(JSON.stringify(hot_state)) as Dictionary


func _assert_coin_pusher_hot_solver_twin(source: Dictionary, config: Dictionary, label: String, failures: Array) -> void:
	var reference_state := source.duplicate(true)
	var hot_state := source.duplicate(true)
	var reference_result := CoinPusherSolverScript.step_action_reference_for_test(reference_state, config)
	var hot_result := CoinPusherSolverScript.step_action(hot_state, config)
	if JSON.stringify(reference_state) != JSON.stringify(hot_state):
		failures.append("Packed Coin Pusher solver changed exact authoritative state for %s versus the dictionary oracle." % label)
	if JSON.stringify(reference_result) != JSON.stringify(hot_result):
		failures.append("Packed Coin Pusher solver changed exits/events/metrics/trace order for %s versus the dictionary oracle." % label)


func _check_coin_pusher_data_contract(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var solver_api_contract := {
		"schema": CoinPusherSolverScript.SCHEMA,
		"fixed_hz": CoinPusherSolverScript.FIXED_HZ,
		"fixed_point_scale": CoinPusherSolverScript.FP,
		"width": CoinPusherSolverScript.WIDTH,
		"front_edge": CoinPusherSolverScript.FRONT_EDGE,
		"upper_edge": CoinPusherSolverScript.UPPER_EDGE,
		"rear_edge": CoinPusherSolverScript.REAR_EDGE,
		"upper_floor_z": CoinPusherSolverScript.UPPER_FLOOR_Z,
		"lower_floor_z": CoinPusherSolverScript.LOWER_FLOOR_Z,
		"coin_radius": CoinPusherSolverScript.COIN_RADIUS,
		"coin_height": CoinPusherSolverScript.COIN_HEIGHT,
		"object_radius": CoinPusherSolverScript.OBJECT_RADIUS,
		"object_height": CoinPusherSolverScript.OBJECT_HEIGHT,
		"action_ticks": CoinPusherSolverScript.ACTION_TICKS,
		"phase_period": CoinPusherSolverScript.PHASE_PERIOD,
		"tray_left": CoinPusherSolverScript.TRAY_LEFT,
		"tray_right": CoinPusherSolverScript.TRAY_RIGHT,
	}
	if solver_api_contract != CoinPusherSolverScript.implementation_contract():
		failures.append("Quarter Falls lazy solver API constants drifted from the deterministic implementation contract.")
	if str(definition.get("module_path", "")) != "res://scripts/games/coin_pusher.gd" or str(definition.get("family", "")) != "coin_pusher":
		failures.append("Quarter Falls is not registered as the data-routed coin_pusher family.")
	if not _string_array(definition.get("content_groups", [])).has("coin_pusher_pack") or _string_array(definition.get("content_groups", [])).has("slot_pack"):
		failures.append("Quarter Falls must use its own default-enabled content pack without entering the slot-only pack.")
	var pusher_group := library.content_group("coin_pusher_pack")
	if pusher_group.is_empty() or not bool(pusher_group.get("default_enabled", false)) or not _string_array(pusher_group.get("game_ids", [])).has("coin_pusher"):
		failures.append("Quarter Falls coin_pusher_pack is missing, disabled by default, or does not trace to the game id.")
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {}) if typeof(definition.get("coin_pusher_tuning", {})) == TYPE_DICTIONARY else {}
	for key in [
		"state_schema_version", "variation_id", "phase_steps", "force_order", "default_force", "direction_order", "default_direction",
		"security_band_deltas", "tell_labels", "lane_count", "depth_slot_count", "solver_fixed_hz", "solver_fixed_point_scale",
		"solver_action_ticks", "coin_cap", "opening_coin_count", "clean_nudge_phase", "clean_nudge_window_steps", "nudge_forces", "mistimed_push_penalty",
		"front_nudge_lane_radius", "skill_accuracy_base", "skill_accuracy_phase_penalty", "hard_alarm_heat",
		"prize_initial_cell_max", "documented_ev_band", "scenario_reset_contract", "prize_riders",
	]:
		if not tuning.has(key):
			failures.append("Quarter Falls tuning is missing %s." % key)
	var reset_contract: Dictionary = tuning.get("scenario_reset_contract", {}) if typeof(tuning.get("scenario_reset_contract", {})) == TYPE_DICTIONARY else {}
	if str(reset_contract.get("path", "")) != "scenario_game_modifiers.coin_pusher" or str(reset_contract.get("flag", "")) != "reset_pile":
		failures.append("Quarter Falls did not document the scenario pile-reset flag.")
	for venue_id in ["gas_station_casino", "corner_store", "bar"]:
		var venue := library.environment_archetype(venue_id)
		var pool: Array = venue.get("game_pool", []) if typeof(venue.get("game_pool", [])) == TYPE_ARRAY else []
		if not pool.has("coin_pusher"):
			failures.append("Tier-1 venue %s does not seed Quarter Falls availability." % venue_id)
	var corner := library.environment_archetype("corner_store")
	var corner_count: Array = corner.get("game_count", []) if typeof(corner.get("game_count", [])) == TYPE_ARRAY else []
	if corner_count.size() != 2 or int(corner_count[0]) != 0 or int(corner_count[1]) != 1:
		failures.append("Corner Store Quarter Falls placement must remain optional [0,1].")
	var generated_corner_counts := {}
	for sample_index in range(32):
		var sample_run: RunState = RunStateScript.new()
		sample_run.start_new("PUSHER-CORNER-%02d" % sample_index)
		var generated_corner := EnvironmentInstance.from_archetype(corner, sample_index, sample_run.create_rng("pusher_corner_optional"), library)
		var generated_count := generated_corner.game_ids.size()
		generated_corner_counts[generated_count] = true
		if generated_count > 1:
			failures.append("Generated Corner Store exceeded its true one-machine maximum (%d)." % generated_count)
			break
	if not bool(generated_corner_counts.get(0, false)) or not bool(generated_corner_counts.get(1, false)):
		failures.append("Generated Corner Stores did not exercise both optional Quarter Falls counts 0 and 1.")
	for untouched_id in ["motel", "pawn_shop", "back_alley"]:
		var pool: Array = library.environment_archetype(untouched_id).get("game_pool", [])
		if pool.has("coin_pusher"):
			failures.append("Quarter Falls leaked into non-target venue %s." % untouched_id)


func _check_coin_pusher_discrete_solver(definition: Dictionary, failures: Array) -> void:
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {}) if typeof(definition.get("coin_pusher_tuning", {})) == TYPE_DICTIONARY else {}
	var state := CoinPusherSolverScript.create(_configured_rng(6062), int(tuning.get("coin_cap", 0)), 0, 5)
	if str(state.get("schema", "")) != "coin_pusher_fixed_point" or int(state.get("fixed_hz", 0)) != 60 or int(state.get("fixed_point_scale", 0)) != 1000 or int(state.get("coin_cap", 0)) != 160:
		failures.append("Coin Pusher did not expose the shipped 60 Hz integer fixed-point solver and 160-coin cap.")
	var sparse_source := CoinPusherSolverScript.create(_configured_rng(6060), 48, 0, 5)
	sparse_source["bodies"] = [{"id": "restored_sparse", "kind": "coin", "x": 50000, "y": 30000, "z": 9000}]
	var restored_value: Variant = JSON.parse_string(JSON.stringify(sparse_source))
	var restored_sparse: Dictionary = restored_value if typeof(restored_value) == TYPE_DICTIONARY else {}
	var explicit_defaults := sparse_source.duplicate(true)
	explicit_defaults["bodies"] = [_solver_body("restored_sparse", "coin", 50000, 30000, 9000, false)]
	var sparse_step := CoinPusherSolverScript.step_action(restored_sparse, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	var explicit_step := CoinPusherSolverScript.step_action(explicit_defaults, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	if JSON.stringify(CoinPusherSolverScript.canonical_digest(restored_sparse)) != JSON.stringify(CoinPusherSolverScript.canonical_digest(explicit_defaults)):
		failures.append("Cold JSON-restored sparse Coin Pusher body did not normalize to the explicit canonical state.")
	for output_key in ["events", "motion_events", "presentation_events", "presentation_trace"]:
		if JSON.stringify(sparse_step.get(output_key, [])) != JSON.stringify(explicit_step.get(output_key, [])):
			failures.append("Cold JSON-restored sparse Coin Pusher body changed exact %s output after hot-field normalization." % output_key)
	var resting_stack := CoinPusherSolverScript.create(_configured_rng(6061), 48, 0, 5)
	resting_stack["bodies"] = [
		_solver_body("rest_base", "coin", 42000, 27000, 0, true),
		_solver_body("rest_top", "coin", 42000, 27000, CoinPusherSolverScript.COIN_HEIGHT, true),
	]
	CoinPusherSolverScript.step_action(resting_stack, {"upper_locked": true, "lower_locked": true})
	if int(((resting_stack.get("bodies", []) as Array)[1] as Dictionary).get("z", 0)) != CoinPusherSolverScript.COIN_HEIGHT:
		failures.append("A settled individual coin did not remain physically stacked on another coin.")
	state["bodies"] = [
		_solver_body("support", "coin", 50000, 30000, 0, true),
		_solver_body("leaner", "coin", 50000, 30000, 1700, false),
		_solver_body("landing", "coin", 52700, 30000, 9000, false),
	]
	var before_landing_z := int((state.get("bodies", []) as Array)[2].get("z", 0))
	var stack_step := CoinPusherSolverScript.step_action(state, {"upper_locked": true, "lower_locked": true})
	var bodies: Array = state.get("bodies", [])
	if bodies.size() < 3 or int((bodies[2] as Dictionary).get("z", 0)) >= before_landing_z:
		failures.append("A physical landing coin did not fall toward and disturb an individual stack.")
	var stack_metrics: Dictionary = stack_step.get("metrics", {}) if typeof(stack_step.get("metrics", {})) == TYPE_DICTIONARY else {}
	if int(stack_metrics.get("topple_count", 0)) < 1 or int(stack_metrics.get("collision_count", 0)) < 1 or int(stack_metrics.get("moved_count", 0)) < 2:
		failures.append("Discrete coins did not stack unevenly, record lean/topple state, and cascade from one landing.")
	var stack_impact := _presentation_event_for_body(stack_step, "impact", "landing")
	var stack_impact_metadata: Dictionary = stack_impact.get("metadata", {}) if typeof(stack_impact.get("metadata", {})) == TYPE_DICTIONARY else {}
	if str(stack_impact_metadata.get("material", "")) != "coin_on_coin" or int(stack_impact_metadata.get("stack_depth", 0)) < 1 \
			or int(stack_impact_metadata.get("fall_height_milli", 0)) <= 0:
		failures.append("Production stack impact audio metadata did not come from the actual falling coin and support depth.")
	var metal_state := CoinPusherSolverScript.create(_configured_rng(6068), 48, 0, 5)
	metal_state["bodies"] = [_solver_body("metal_landing", "coin", 25000, 30000, 9000, false)]
	var metal_step := CoinPusherSolverScript.step_action(metal_state, {"upper_locked": true, "lower_locked": true})
	var metal_impact := _presentation_event_for_body(metal_step, "impact", "metal_landing")
	var metal_impact_metadata: Dictionary = metal_impact.get("metadata", {}) if typeof(metal_impact.get("metadata", {})) == TYPE_DICTIONARY else {}
	if str(metal_impact_metadata.get("material", "")) != "coin_on_metal" or int(metal_impact_metadata.get("stack_depth", -1)) != 0 \
			or int(metal_impact_metadata.get("fall_height_milli", 0)) <= 0:
		failures.append("Production metal impact audio metadata did not come from the actual physical floor landing.")
	var fall_state := CoinPusherSolverScript.create(_configured_rng(6063), 80, 0, 5)
	fall_state["bodies"] = [
		_solver_body("upper_fall", "coin", 50000, CoinPusherSolverScript.UPPER_EDGE - 1000, CoinPusherSolverScript.UPPER_FLOOR_Z, false),
		_solver_body("tray_fall", "coin", 50000, 0, 0, false),
		_solver_body("gutter_fall", "coin", 1000, 0, 0, false),
	]
	var fall_step := CoinPusherSolverScript.step_action(fall_state, {"upper_locked": true, "lower_locked": true})
	var tray_seen := false
	var gutter_seen := false
	for event_value in fall_step.get("events", []):
		if typeof(event_value) == TYPE_DICTIONARY:
			tray_seen = tray_seen or str((event_value as Dictionary).get("outcome", "")) == "tray"
			gutter_seen = gutter_seen or str((event_value as Dictionary).get("outcome", "")) == "gutter"
	var upper_landed_lower := false
	for body_value in fall_state.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == "upper_fall":
			upper_landed_lower = int((body_value as Dictionary).get("z", 0)) < CoinPusherSolverScript.UPPER_FLOOR_Z
	if not upper_landed_lower or int((fall_step.get("metrics", {}) as Dictionary).get("upper_lower_fall_count", 0)) < 1 or not tray_seen or not gutter_seen:
		failures.append("Tier gravity did not produce upper-to-lower fall, tray payout, and side-gutter loss as physical exits.")
	var nudge_state := CoinPusherSolverScript.create(_configured_rng(6064), 80, 0, 5)
	nudge_state["bodies"] = [
		_solver_body("nudge_base", "coin", 50000, 9000, 0, true),
		_solver_body("nudge_top", "coin", 52000, 9000, 1700, true),
	]
	var nudge_before := JSON.stringify(CoinPusherSolverScript.canonical_digest(nudge_state))
	var nudge_step := CoinPusherSolverScript.step_action(nudge_state, {"upper_locked": true, "lower_locked": true, "nudge_x": 12000, "nudge_y": -22000, "aimed_x": 50000, "nudge_radius": 12000})
	if JSON.stringify(CoinPusherSolverScript.canonical_digest(nudge_state)) == nudge_before:
		failures.append("A nudge did not shift and destabilize a real individual-coin pile.")
	var production_event_kinds := {}
	var production_events: Array = []
	for production_step in [stack_step, fall_step, nudge_step]:
		for event_value in (production_step as Dictionary).get("presentation_events", []):
			if typeof(event_value) == TYPE_DICTIONARY:
				production_event_kinds[str((event_value as Dictionary).get("kind", ""))] = true
				production_events.append((event_value as Dictionary).duplicate(true))
	for required_kind in ["impact", "slide", "upper_to_lower", "topple", "ledge_tip", "tray_landing", "gutter_loss", "cabinet_shake"]:
		if not bool(production_event_kinds.get(required_kind, false)):
			failures.append("Solver-driven production fixtures did not emit required presentation/audio event %s." % required_kind)
	var production_sfx := SfxPlayerScript.new()
	var production_schedule := production_sfx.debug_coin_pusher_event_schedule({"coin_pusher_snapshot": {"events": production_events}})
	var routed_production_kinds := {}
	for scheduled_value in production_schedule:
		if typeof(scheduled_value) == TYPE_DICTIONARY and not str((scheduled_value as Dictionary).get("cue", "")).is_empty():
			routed_production_kinds[str((scheduled_value as Dictionary).get("kind", ""))] = true
	production_sfx.free()
	for required_kind in production_event_kinds.keys():
		if not bool(routed_production_kinds.get(str(required_kind), false)):
			failures.append("Solver-driven production event %s did not route through the Coin Pusher SFX profile." % str(required_kind))
	var pressure_rng := _configured_rng(6065)
	var pressure_state := CoinPusherSolverScript.create(pressure_rng.fork("opening"), 160, 150, 5)
	for action_index in range(600):
		CoinPusherSolverScript.add_coin(pressure_state, pressure_rng, action_index % 5, 5, 3 if action_index % 17 == 0 else 1)
		var pressure_step := CoinPusherSolverScript.step_action(pressure_state, {
			"captured_upper_phase_fp": (action_index * 1700) % CoinPusherSolverScript.PHASE_PERIOD,
			"captured_lower_phase_fp": (action_index * 2300) % CoinPusherSolverScript.PHASE_PERIOD,
			"push_scale": 1 + action_index % 5,
		})
		if CoinPusherSolverScript.coin_count(pressure_state) > 160:
			failures.append("Coin Pusher cap pressure left more than 160 real coins after action %d." % action_index)
			break
		for event_value in pressure_step.get("events", []):
			if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("cause", "")) != "physical_fall":
				failures.append("Coin Pusher cap pressure emitted a nonphysical exit on action %d." % action_index)
				return
	for body_value in nudge_state.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		for key in ["x", "y", "z", "vx", "vy", "vz", "radius", "height", "mass", "sleep_ticks", "lean_milli"]:
			if typeof(body.get(key, null)) != TYPE_INT:
				failures.append("Fixed-point solver field %s drifted away from integer state." % key)
				return


func _solver_body(id: String, kind: String, x: int, y: int, z: int, sleeping: bool) -> Dictionary:
	return {
		"id": id, "kind": kind, "x": x, "y": y, "z": z,
		"vx": 0, "vy": 0, "vz": 0,
		"radius": CoinPusherSolverScript.COIN_RADIUS, "height": CoinPusherSolverScript.COIN_HEIGHT, "mass": 1,
		"sleep_ticks": 8 if sleeping else 0, "sleeping": sleeping,
		"rest_state": "resting" if sleeping else "settling", "lean_milli": 0, "metadata": {},
	}


func _check_coin_pusher_definition_routing(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var fixture_definition := definition.duplicate(true)
	var tuning: Dictionary = fixture_definition.get("coin_pusher_tuning", {}).duplicate(true)
	tuning["state_schema_version"] = 7
	tuning["variation_id"] = "fixture_route_identity"
	tuning["phase_steps"] = 8
	tuning["force_order"] = ["shove", "tap", "slam"]
	tuning["default_force"] = "shove"
	tuning["direction_order"] = ["right", "front", "left"]
	tuning["default_direction"] = "right"
	tuning["tell_labels"] = ["quiet", "tilting", "authored chirp", "watched"]
	tuning["security_band_deltas"] = {"normal": 0, "lax": 4, "strict": -3}
	tuning["prize_count_min"] = 0
	tuning["prize_count_max"] = 0
	fixture_definition["coin_pusher_tuning"] = tuning
	var routed_game: GameModule = CoinPusherGameScript.new()
	routed_game.setup(fixture_definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PUSHER-DEFINITION-ROUTING")
	var environment := _coin_pusher_environment("pusher_definition_routing")
	var generated := routed_game.generate_environment_state(run_state, environment, _configured_rng(1701))
	environment["game_states"] = {"coin_pusher": generated}
	run_state.set_environment(environment)
	var surface := routed_game.surface_state(run_state, run_state.current_environment)
	if int(generated.get("version", 0)) != 7 or str(generated.get("variation_id", "")) != "fixture_route_identity":
		failures.append("Quarter Falls generated state ignored its authored schema version or variation identity.")
	if int(generated.get("upper_phase", -1)) >= 8 or int(generated.get("lower_phase", -1)) >= 8 \
			or int(surface.get("coin_pusher_phase_steps", 0)) != 8 or str(surface.get("coin_pusher_variation_id", "")) != "fixture_route_identity":
		failures.append("Quarter Falls phase domain or surface identity was not routed from the game definition.")
	if str(surface.get("coin_pusher_force", "")) != "shove" or str(surface.get("coin_pusher_direction", "")) != "right" \
			or JSON.stringify(surface.get("coin_pusher_force_order", [])) != JSON.stringify(["shove", "tap", "slam"]) \
			or JSON.stringify(surface.get("coin_pusher_direction_order", [])) != JSON.stringify(["right", "front", "left"]):
		failures.append("Quarter Falls controls ignored authored force/direction defaults or ordering.")
	var force_command := routed_game.surface_action_command("coin_pusher_force", 0, false, {}, run_state, run_state.current_environment)
	var direction_command := routed_game.surface_action_command("coin_pusher_direction", 0, false, {}, run_state, run_state.current_environment)
	if str((force_command.get("ui_state", {}) as Dictionary).get("coin_pusher_force", "")) != "shove" \
			or str((direction_command.get("ui_state", {}) as Dictionary).get("coin_pusher_direction", "")) != "right":
		failures.append("Quarter Falls action selection did not consume authored force/direction ordering.")
	var current_machine: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	current_machine["tell_rung"] = 2
	surface = routed_game.surface_state(run_state, run_state.current_environment)
	if str(_presentation_snapshot(surface).get("tell_label", "")) != "authored chirp":
		failures.append("Quarter Falls tell presentation ignored its authored label ladder.")
	var lax_environment := _coin_pusher_environment("pusher_definition_lax")
	lax_environment["security_profile"] = {"machine_alarm_tolerance_band": "lax"}
	var lax_machine := routed_game.generate_environment_state(run_state, lax_environment, _configured_rng(1701))
	if int(lax_machine.get("tolerance_modifier", 0)) != 4:
		failures.append("Quarter Falls security-band tolerance ignored the authored delta table.")


func _check_coin_pusher_production_rider(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var scenario := library.scenario("gas_station_graveyard_shift")
	var mutations: Dictionary = scenario.get("mutations", {}) if typeof(scenario.get("mutations", {})) == TYPE_DICTIONARY else {}
	var hooks: Dictionary = mutations.get("game_modifier_hooks", {}) if typeof(mutations.get("game_modifier_hooks", {})) == TYPE_DICTIONARY else {}
	var pusher: Dictionary = hooks.get("coin_pusher", {}) if typeof(hooks.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	var prize_item_ids := _string_array(pusher.get("prize_item_ids", []))
	if prize_item_ids != ["lucky_penny"] or library.item("lucky_penny").is_empty():
		failures.append("Graveyard Shift does not author its Quarter Falls rider with a valid production inventory item.")
	var exclusive: Dictionary = mutations.get("exclusive_opportunity", {}) if typeof(mutations.get("exclusive_opportunity", {})) == TYPE_DICTIONARY else {}
	var gas_station := library.environment_archetype("gas_station_casino")
	if not str(exclusive.get("game_id", "")).is_empty() or _string_array(gas_station.get("required_game_ids", [])).has("coin_pusher"):
		failures.append("Graveyard Shift must not force Quarter Falls availability to provide its optional rider config.")
	var rider_seen := false
	for sample_index in range(96):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("PUSHER-PRODUCTION-RIDER-%02d" % sample_index)
		var environment := _coin_pusher_environment("pusher_production_rider_%02d" % sample_index)
		environment["scenario_game_modifiers"] = hooks.duplicate(true)
		var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("production_scenario_rider"))
		for rider_value in machine.get("riders", []):
			if typeof(rider_value) == TYPE_DICTIONARY and str((rider_value as Dictionary).get("item_id", "")) == "lucky_penny":
				rider_seen = true
				break
		if rider_seen:
			break
	if not rider_seen:
		failures.append("Graveyard Shift's authored lucky-penny rider never entered a real generated Quarter Falls pile.")


func _check_coin_pusher_alarm_audio(failures: Array) -> void:
	var sfx := SfxPlayerScript.new()
	var pusher_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher.gd")
	if pusher_source.contains('result["surface_audio_cue"] = "alarm_chirp"'):
		failures.append("Coin Pusher still bypasses its snapshot-event chirp ladder through the legacy generic result cue.")
	var profile := sfx.debug_surface_sfx_profile("coin_pusher")
	var classes: Dictionary = profile.get("event_classes", {}) if typeof(profile.get("event_classes", {})) == TYPE_DICTIONARY else {}
	var expected_classes := ["impact_metal", "impact_stack", "slide", "upper_to_lower", "topple", "ledge_tip", "tray_landing", "gutter_loss", "cabinet_shake", "tell_rock", "tell_chirp", "attendant_glance", "alarm"]
	if str(profile.get("bus", "")) != "SFX" or str((profile.get("motor_loop", {}) as Dictionary).get("event_id", "")) != "coin_pusher_motor":
		failures.append("Coin Pusher audio profile is not registered through the central SFX bus and motor-loop manifest.")
	for event_class in expected_classes:
		var cue := str(classes.get(event_class, ""))
		var stream: AudioStreamWAV = sfx.render_event_master_stream(cue)
		if cue.is_empty() or sfx.debug_normalized_event_id(cue) != cue or stream == null or stream.data.is_empty():
			failures.append("Coin Pusher audio event class %s is missing its authored central-bank cue." % event_class)
	var schedule := sfx.debug_coin_pusher_event_schedule({"coin_pusher_snapshot": {"events": [
		{"kind": "impact", "tick_offset": 2, "intensity_milli": 400, "metadata": {"material": "coin_on_metal", "stack_depth": 0, "fall_height_milli": 0}},
		{"kind": "impact", "tick_offset": 3, "intensity_milli": 700, "metadata": {"material": "coin_on_coin", "stack_depth": 3, "fall_height_milli": 3000}},
		{"kind": "slide", "tick_offset": 5, "intensity_milli": 500, "metadata": {}},
		{"kind": "upper_to_lower", "tick_offset": 8, "intensity_milli": 700, "metadata": {}},
		{"kind": "topple", "tick_offset": 12, "intensity_milli": 800, "metadata": {}},
		{"kind": "ledge_tip", "tick_offset": 17, "intensity_milli": 600, "metadata": {}},
		{"kind": "tray_landing", "tick_offset": 22, "intensity_milli": 900, "metadata": {"group_count": 4, "group_index": 0}},
		{"kind": "gutter_loss", "tick_offset": 24, "intensity_milli": 800, "metadata": {}},
		{"kind": "cabinet_shake", "tick_offset": 1, "intensity_milli": 600, "metadata": {}},
		{"kind": "tell_rock", "tick_offset": 1, "intensity_milli": 400, "metadata": {"tell_rung": 1}},
		{"kind": "tell_chirp", "tick_offset": 1, "intensity_milli": 600, "metadata": {"tell_rung": 2}},
		{"kind": "attendant_glance", "tick_offset": 1, "intensity_milli": 700, "metadata": {"tell_rung": 3}},
		{"kind": "alarm", "tick_offset": 1, "intensity_milli": 1000, "metadata": {"tell_rung": 3}},
	]}})
	if schedule.size() != 13 or str((schedule[0] as Dictionary).get("cue", "")) != "coin_pusher_coin_metal" or str((schedule[1] as Dictionary).get("cue", "")) != "coin_pusher_coin_stack" \
			or float((schedule[1] as Dictionary).get("pitch", 0.0)) <= float((schedule[0] as Dictionary).get("pitch", 0.0)) \
			or str((schedule[6] as Dictionary).get("cue", "")) != "coin_pusher_tray" or str((schedule[7] as Dictionary).get("cue", "")) != "coin_pusher_gutter" \
			or str((schedule[12] as Dictionary).get("cue", "")) != "coin_pusher_alarm":
		failures.append("Coin Pusher snapshot events did not schedule the full layered impact/slide/motor/tray/gutter/tell/alarm audio map.")
	var height_schedule := sfx.debug_coin_pusher_event_schedule({"coin_pusher_snapshot": {"events": [
		{"kind": "impact", "tick_offset": 1, "intensity_milli": 500, "metadata": {"material": "coin_on_metal", "stack_depth": 0, "fall_height_milli": 0}},
		{"kind": "impact", "tick_offset": 1, "intensity_milli": 500, "metadata": {"material": "coin_on_metal", "stack_depth": 0, "fall_height_milli": 4000}},
	]}})
	if height_schedule.size() != 2 or float((height_schedule[1] as Dictionary).get("volume_db", -99.0)) <= float((height_schedule[0] as Dictionary).get("volume_db", -99.0)):
		failures.append("Coin Pusher impact mix does not respond to physical fall height.")
	var cascade_schedule := sfx.debug_coin_pusher_event_schedule({"coin_pusher_snapshot": {"events": [
		{"kind": "tray_landing", "tick_offset": 2, "intensity_milli": 700, "metadata": {"group_count": 3, "group_index": 0}},
		{"kind": "tray_landing", "tick_offset": 3, "intensity_milli": 700, "metadata": {"group_count": 3, "group_index": 1}},
	]}})
	if cascade_schedule.size() != 1 or float((cascade_schedule[0] as Dictionary).get("volume_db", -99.0)) <= -7.0:
		failures.append("Coin Pusher tray payout did not collapse physical landings into one count-scaled cascade.")
	var terminal_state := {"coin_pusher_snapshot": {
		"bodies": [], "lower_phase_milli": 0, "phase_domain_milli": 8000,
		"events": [
			{"kind": "tell_chirp", "tick_offset": 48, "intensity_milli": 600, "metadata": {"tell_rung": 2}},
			{"kind": "alarm", "tick_offset": 48, "intensity_milli": 1000, "metadata": {"tell_rung": 3}},
			{"kind": "tray_landing", "tick_offset": 48, "intensity_milli": 800, "metadata": {"group_count": 1, "group_index": 0}},
			{"kind": "gutter_loss", "tick_offset": 48, "intensity_milli": 700, "metadata": {"group_count": 1, "group_index": 0}},
		],
	}}
	var stale_runtime_markers := sfx.debug_coin_pusher_runtime_event_markers(terminal_state, 4.0, false, "restored_stale_action", true)
	var early_runtime_markers := sfx.debug_coin_pusher_runtime_event_markers(terminal_state, 0.79, true, "terminal_guard", true)
	var terminal_runtime_markers := sfx.debug_coin_pusher_runtime_event_markers(terminal_state, 0.8, false, "terminal_guard", false)
	var post_handoff_markers := sfx.debug_coin_pusher_runtime_event_markers(terminal_state, 1.1, false, "terminal_guard", false)
	if not stale_runtime_markers.is_empty() or not early_runtime_markers.is_empty() or terminal_runtime_markers.size() != 4 \
			or JSON.stringify(post_handoff_markers) != JSON.stringify(terminal_runtime_markers):
		failures.append("Coin Pusher runtime timing gate replayed stale idle audio or did not play terminal chirp/alarm/tray/gutter exactly once after an observed active action.")
	var alarm_stream: AudioStreamWAV = sfx.render_event_master_stream("coin_pusher_alarm")
	var chirp_stream: AudioStreamWAV = sfx.render_event_master_stream("coin_pusher_chirp")
	if alarm_stream == null or chirp_stream == null or alarm_stream.data == chirp_stream.data:
		failures.append("Coin Pusher alarm is not a distinct machine cue from the tell-ladder chirp.")
	sfx.free()


func _check_coin_pusher_canonical_probe(failures: Array) -> void:
	var probe_source := FileAccess.get_file_as_string("res://tools/foundation_determinism_probe.gd")
	if probe_source.is_empty() or not probe_source.contains('"coin_pusher"') \
			or not probe_source.contains('"drop_quarter"') or not probe_source.contains('"nudge_machine"'):
		failures.append("Canonical determinism does not include a real Quarter Falls drop-and-nudge sequence.")
	var capture_source := FileAccess.get_file_as_string("res://tools/coin_pusher_visual_capture.gd")
	for required_text in ["_on_settings_applied", "debug_surface_motion_sample", "motion_before", "motion_after", "animation_redraw_count == 0", "manifest_authoritative_pass"]:
		if not capture_source.contains(required_text):
			failures.append("Quarter Falls focused capture is missing reduced-motion proof seam %s." % required_text)
	var required_capture_contract := 'const REQUIRED_CAPTURE_IDS := ["normal_pile_rider", "tell_alarm_chirps", "reduced_motion", "hard_alarm_lockdown", "room_available_after_alarm", "jackpot_ridge", "vault_drop"]'
	if not capture_source.contains(required_capture_contract):
		failures.append("Coin Pusher focused capture does not require both Jackpot Ridge and The Vault Drop alongside the five base proofs.")
	var feel_source := FileAccess.get_file_as_string("res://tools/coin_pusher_physics_feel_capture.gd")
	var required_feel_contract := 'const REQUIRED_IDS := ["drop_disturbs_pile", "stack_topples", "upper_to_lower", "nudge_shifts_pile", "tray_fall", "gutter_loss", "tell_ladder_alarm"]'
	if not feel_source.contains(required_feel_contract) or not feel_source.contains("const SHIPPED_OPENING_COIN_COUNT := 150") \
			or not feel_source.contains("func _packed_state") or feel_source.contains("before_visual") or feel_source.contains("after_visual"):
		failures.append("Coin Pusher feel QA does not require all seven dense-pile scenarios at the shipped presentation cap.")
	for required_tell_capture_text in [
		'const TELL_STAGE_IDS := ["steady", "cabinet_rock", "chirp", "attendant_glance", "alarm_lock"]',
		'var stage_surfaces: Array = [game.surface_state',
		'"stage_evidence": stage_evidence',
		'func _capture_tell_stage',
	]:
		if not feel_source.contains(required_tell_capture_text):
			failures.append("Coin Pusher feel QA is missing five-stage production tell evidence seam %s." % required_tell_capture_text)
	var performance_source := FileAccess.get_file_as_string("res://tools/foundation_performance_probe.gd")
	for required_text in [
		'"coin_pusher": {"counter": "surface_animation_redraw_count", "minimum_per_120_frames": 8}',
		'"mode"] = "coin_pusher_solver_action_raw"',
		'"coin_pusher_active_drop"',
		'"coin_pusher_active_nudge"',
		'COIN_PUSHER_ACTIVE_ACTION_BUDGET_MS := 16.0',
		'float(stats.get("p95_ms", 0.0)) > COIN_PUSHER_ACTIVE_ACTION_BUDGET_MS',
		'resolve_call_ms > COIN_PUSHER_ACTIVE_ACTION_BUDGET_MS',
		'COIN_PUSHER_ACTIVE_FRAME_P95_BUDGET_MS := 16.0',
		'MAX_SURFACE_DRAW_P95_MS := 5.0',
	]:
		if not performance_source.contains(required_text):
			failures.append("Canonical performance coverage is missing the Coin Pusher acceptance seam %s." % required_text)
	var game_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher.gd")
	var actions_source := _source_function(game_source, "actions")
	var ensure_source := _source_function(game_source, "_ensure_machine_state")
	if actions_source.contains("_read_machine_state") or not ensure_source.contains("not _machine_read_requires_reconciliation") \
			or not ensure_source.contains("return machine"):
		failures.append("Coin Pusher action/stake reads no longer preserve the scalar readonly no-simulation-copy fast path.")
	var view_model_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_action_view_model.gd")
	var view_snapshot_source := _source_function(view_model_source, "game_view_snapshot")
	var result_snapshot_source := _source_function(view_model_source, "current_game_result_snapshot")
	if not view_snapshot_source.contains('result_key == "surface_presentation_snapshot_patch"') \
			or not view_snapshot_source.contains('game_id in ["slot", "coin_pusher"]') \
			or not result_snapshot_source.contains('result_game_id == "coin_pusher"') \
			or not result_snapshot_source.contains("duplicate(false)"):
		failures.append("Coin Pusher host snapshot assembly regressed to deep-copying its dense immutable presentation trace.")
	var main_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	if not main_source.contains("last_game_result = FoundationActionViewModelScript.stored_game_result_snapshot(result)"):
		failures.append("Coin Pusher foreground action storage no longer uses the ownership-preserving result boundary.")


func _check_coin_pusher_surface_liveness(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-LIVENESS")
	var run_state: RunState = fixture.get("run_state")
	var machine: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	machine["riders"] = [{"id": "visible_rider", "kind": "chip_stack", "label": "chip stack", "item_id": "", "cash_value": 4, "lane": 1, "cell": 2, "push": 1}]
	var surface := game.surface_state(run_state, run_state.current_environment, {"surface_time_msec": 1000})
	if str(surface.get("surface_renderer", "")) != "coin_pusher" or not bool(surface.get("surface_controls_native", false)):
		failures.append("Quarter Falls did not expose its native machine surface.")
	if not bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Quarter Falls live shelf phase is not connected to the canonical realtime surface refresh.")
	_check_idle_animation_liveness_contract(surface, "Quarter Falls attract surface", failures)
	_check_surface_visual_motion_advances(game, surface, "Quarter Falls attract surface", failures)
	var approaches: Array = []
	for lane_value in surface.get("coin_pusher_lanes", []):
		if typeof(lane_value) == TYPE_DICTIONARY:
			approaches.append(int((lane_value as Dictionary).get("approach", 99)))
	if JSON.stringify(approaches) != JSON.stringify([-2, -1, 0, 1, 2]):
		failures.append("Quarter Falls surface did not expose five distinct lane approach identities.")
	var presentation_snapshot: Dictionary = surface.get("coin_pusher_snapshot", {}) if typeof(surface.get("coin_pusher_snapshot", {})) == TYPE_DICTIONARY else {}
	if (presentation_snapshot.get("riders", []) as Array).size() != 1:
		failures.append("Quarter Falls surface did not expose the prize rider ON its pile.")
	var digest_before_render: String = game.deterministic_state_digest(run_state.current_environment)
	var live_canvas: Control = GameSurfaceCanvasScript.new()
	live_canvas.size = Vector2(450, 215)
	root.add_child(live_canvas)
	live_canvas.call("set_game_module", game)
	live_canvas.call("render_game_snapshot", surface)
	var live_before: Dictionary = live_canvas.call("realtime_surface_state")
	var live_before_snapshot: Dictionary = _presentation_snapshot(live_before)
	var live_patch: Dictionary = game.surface_realtime_state_patch(run_state, run_state.current_environment, {"coin_pusher_lane": 2, "surface_time_msec": 1900}, live_before)
	var live_patch_snapshot: Dictionary = _presentation_snapshot(live_patch)
	var shallow_references_preserved := true
	for key in ["bodies", "riders", "features", "events", "trace"]:
		if not _coin_pusher_arrays_share_reference(live_before_snapshot.get(key, []), live_patch_snapshot.get(key, [])):
			shallow_references_preserved = false
	var action_reference_preserved := _coin_pusher_dictionaries_share_reference(
		live_before_snapshot.get("action_state", {}), live_patch_snapshot.get("action_state", {})
	)
	live_canvas.call("apply_surface_state_patch", live_patch)
	var live_after: Dictionary = live_canvas.call("realtime_surface_state")
	var live_after_snapshot: Dictionary = _presentation_snapshot(live_after)
	var live_click: Dictionary = game.surface_action_command("coin_pusher_drop", 0, false, {"coin_pusher_lane": 2, "surface_time_msec": 1900}, run_state, run_state.current_environment)
	var live_click_ui: Dictionary = live_click.get("ui_state", {}) if typeof(live_click.get("ui_state", {})) == TYPE_DICTIONARY else {}
	if not shallow_references_preserved or not action_reference_preserved:
		failures.append("Quarter Falls realtime phase patch rebuilt physical snapshot arrays or action state instead of retaining their exact references.")
	if int(live_after_snapshot.get("upper_phase_milli", -1)) == int(live_before_snapshot.get("upper_phase_milli", -1)) \
			or int(live_after_snapshot.get("lower_phase_milli", -1)) == int(live_before_snapshot.get("lower_phase_milli", -1)) \
			or (live_after_snapshot.get("bodies", []) as Array).size() != (live_before_snapshot.get("bodies", []) as Array).size():
		failures.append("Quarter Falls single live canvas did not advance both rendered sweep plates while retaining its physical snapshot.")
	for key in ["bodies", "riders", "features", "events", "trace", "action_state"]:
		if JSON.stringify(live_after_snapshot.get(key)) != JSON.stringify(live_before_snapshot.get(key)):
			failures.append("Quarter Falls realtime phase patch changed retained snapshot field %s." % key)
	if int(live_click_ui.get("coin_pusher_upper_input_phase", -1)) != int(live_after_snapshot.get("upper_phase_milli", -2000)) / 1000 \
			or int(live_click_ui.get("coin_pusher_lower_input_phase", -1)) != int(live_after_snapshot.get("lower_phase_milli", -2000)) / 1000:
		failures.append("Quarter Falls action boundary did not capture the exact upper/lower shelf phases shown on the live canvas.")
	var base_transform: Dictionary = live_canvas.call("debug_design_space_transform", Vector2(900, 430), Vector2.ZERO)
	var shifted_transform: Dictionary = live_canvas.call("debug_design_space_transform", Vector2(900, 430), Vector2(4, 2))
	var base_scale: Vector2 = base_transform.get("scale", Vector2.ONE)
	var shifted_scale: Vector2 = shifted_transform.get("scale", Vector2.ZERO)
	var expected_shift := Vector2(4, 2) * base_scale
	var actual_shift: Vector2 = shifted_transform.get("position", Vector2.ZERO) - base_transform.get("position", Vector2.ZERO)
	if base_scale.is_equal_approx(Vector2.ONE) or not shifted_scale.is_equal_approx(base_scale) \
			or not actual_shift.is_equal_approx(expected_shift):
		failures.append("Coin Pusher cabinet shake did not compose its local offset with the real non-1 design-space transform.")
	var realtime_source := _source_function(FileAccess.get_file_as_string("res://scripts/games/coin_pusher.gd"), "surface_realtime_state_patch")
	if realtime_source.contains("surface_state(") or realtime_source.contains("_presentation_snapshot(") or realtime_source.contains("_body_views("):
		failures.append("Quarter Falls realtime shelf phase patch rebuilds the full surface or physical pile.")
	root.remove_child(live_canvas)
	live_canvas.free()
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	harness.flicker_value = 0.0
	game.draw_surface(harness, surface, {"contract_harness": true})
	for action in ["coin_pusher_lane", "coin_pusher_force", "coin_pusher_direction", "coin_pusher_drop", "coin_pusher_nudge"]:
		if not _surface_harness_has_action(harness, action):
			failures.append("Quarter Falls renderer is missing native action %s." % action)
	for approach_label in ["L2", "L1", "C", "R1", "R2"]:
		if not harness.labels.has(approach_label):
			failures.append("Quarter Falls renderer did not visibly label approach %s." % approach_label)
	var rider_position_a := _coin_pusher_label_position(harness, "R:")
	var moving_harness := SurfaceHarness.new()
	moving_harness.setup(surface)
	moving_harness.flicker_value = 1.0
	game.draw_surface(moving_harness, surface, {"contract_harness": true})
	var rider_position_b := _coin_pusher_label_position(moving_harness, "R:")
	if rider_position_a == Vector2.INF or rider_position_b == Vector2.INF:
		failures.append("Quarter Falls renderer did not draw a visible prize-rider glyph/label.")
	elif rider_position_a.is_equal_approx(rider_position_b):
		failures.append("Quarter Falls visible prize rider did not move with presentation time.")
	if game.deterministic_state_digest(run_state.current_environment) != digest_before_render:
		failures.append("Quarter Falls rider/approach rendering mutated the persisted pile per frame.")
	_check_coin_pusher_reduced_motion_freeze(game, surface, failures)


func _coin_pusher_arrays_share_reference(left_value: Variant, right_value: Variant) -> bool:
	if typeof(left_value) != TYPE_ARRAY or typeof(right_value) != TYPE_ARRAY:
		return false
	var left: Array = left_value
	var right: Array = right_value
	var left_size := left.size()
	right.append("__coin_pusher_reference_probe__")
	var shared := left.size() == left_size + 1
	right.pop_back()
	return shared and left.size() == left_size


func _coin_pusher_dictionaries_share_reference(left_value: Variant, right_value: Variant) -> bool:
	if typeof(left_value) != TYPE_DICTIONARY or typeof(right_value) != TYPE_DICTIONARY:
		return false
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	var probe_key := "__coin_pusher_reference_probe__"
	right[probe_key] = true
	var shared := left.has(probe_key)
	right.erase(probe_key)
	return shared and not left.has(probe_key)


func _check_coin_pusher_snapshot_renderer_boundary(game: GameModule, failures: Array) -> void:
	CoinPusherSolverScript._implementation = null
	if CoinPusherSolverScript._implementation != null:
		failures.append("Coin Pusher synthetic renderer guard could not clear the lazy solver implementation.")
	var synthetic_body := {
		"id": "synthetic_coin", "kind": "coin", "x": 50000, "y": 32000, "z": 1700,
		"radius": 4300, "height": 1700, "mass": 1, "sleeping": true,
		"rest_state": "resting", "level": "lower", "material_category": "coin", "lean_milli": 340, "metadata": {},
	}
	var synthetic_rider := synthetic_body.duplicate(true)
	synthetic_rider.merge({"id": "synthetic_rider", "kind": "rider", "material_category": "prize_rider", "x": 39000, "y": 61000, "metadata": {"label": "watch"}}, true)
	var synthetic_feature := synthetic_body.duplicate(true)
	synthetic_feature.merge({"id": "synthetic_puck", "kind": "puck", "material_category": "feature_puck", "x": 61000, "y": 66000, "metadata": {"kind": "multiplier", "multiplier": 3}}, true)
	var synthetic_event := {"kind": "impact", "body_id": "synthetic_coin", "x": 50000, "y": 32000, "z": 1700, "intensity_milli": 700, "tick_offset": 12, "metadata": {"material": "coin_on_coin", "stack_depth": 1}}
	var moved_body := synthetic_body.duplicate(true)
	moved_body["x"] = 53000
	var synthetic_trace := [
		{"tick_offset": 0, "bodies": [synthetic_feature, synthetic_rider, synthetic_body]},
		{"tick_offset": 48, "bodies": [synthetic_feature, synthetic_rider, moved_body]},
	]
	var synthetic := {
		"surface_renderer": "coin_pusher", "surface_time_msec": 1, "reduce_motion": false,
		"coin_pusher_snapshot": {
			"schema": "coin_pusher_presentation_snapshot", "version": 1,
			"geometry": {"width": 100000, "front_edge": 7000, "upper_edge": 52000, "rear_edge": 95000, "coin_radius": 4300, "coin_height": 1700},
			"bodies": [synthetic_feature, synthetic_rider, synthetic_body], "depth_ordered": true,
			"upper_phase_milli": 1600, "lower_phase_milli": 3200, "phase_domain_milli": 8000,
			"riders": [synthetic_rider], "features": [synthetic_feature], "events": [synthetic_event], "trace": synthetic_trace,
			"action_state": {"action_count": 1, "replay_active_id": "synthetic_action", "action_id": "drop_quarter"},
			"tell_rung": 2, "tell_label": "alarm chirps", "locked": false,
		},
		"coin_pusher_lanes": [{"lane": 0, "approach": 0}],
		"coin_pusher_lane": 0, "coin_pusher_force_order": ["tap", "shove", "slam"],
		"coin_pusher_direction_order": ["left", "right", "front"], "coin_pusher_variation_id": "jackpot_ridge",
		"coin_pusher_variation_name": "Jackpot Ridge", "coin_pusher_multiplier": 3,
		"coin_pusher_cascade_remaining": 1, "coin_pusher_jammed_lanes": [], "coin_pusher_tray_value": 0,
		"coin_pusher_last_message": "Synthetic snapshot.",
	}
	var harness := SurfaceHarness.new()
	harness.setup(synthetic)
	if not game.draw_surface(harness, synthetic, {"synthetic_snapshot_without_solver": true}):
		failures.append("Coin Pusher renderer did not run from a synthetic pure-data snapshot without a solver state.")
	elif not harness.labels.has("JACKPOT RIDGE") or not harness.labels.has("R:WATCH") or not harness.labels.has("x3") \
			or not harness.labels.has("Tell: alarm chirps") or not _surface_harness_has_action(harness, "coin_pusher_drop"):
		failures.append("Coin Pusher synthetic snapshot renderer did not retain its identity and input affordances.")
	if harness.draw_texture_rect_count != 1:
		failures.append("Coin Pusher renderer did not issue exactly one cached glyph draw for its one synthetic coin.")
	harness.animation_active = true
	harness.animation_progress = 0.0
	var motion_start: Dictionary = game.surface_motion_signature(harness, synthetic)
	harness.animation_progress = 1.0
	var motion_end: Dictionary = game.surface_motion_signature(harness, synthetic)
	if int(motion_start.get("physics_body_checksum", 0)) == int(motion_end.get("physics_body_checksum", 0)):
		failures.append("Coin Pusher renderer did not consume synthetic replay frames from the presentation snapshot.")
	var synthetic_sfx := SfxPlayerScript.new()
	var synthetic_audio_schedule := synthetic_sfx.debug_coin_pusher_event_schedule(synthetic)
	if synthetic_audio_schedule.size() != 1 or str((synthetic_audio_schedule[0] as Dictionary).get("cue", "")) != "coin_pusher_coin_stack":
		failures.append("Coin Pusher audio did not consume the synthetic physical event from the presentation snapshot.")
	synthetic_sfx.free()
	if CoinPusherSolverScript._implementation != null:
		failures.append("Coin Pusher synthetic render/audio path loaded the authoritative solver implementation.")
	harness.animation_active = false
	if bool(game.call("_presentation_particles_active", harness, synthetic)):
		failures.append("Coin Pusher terminal presentation particles remain visible after the replay channel ends.")
	harness.animation_active = true
	if not bool(game.call("_presentation_particles_active", harness, synthetic)):
		failures.append("Coin Pusher active replay particles are not connected to the finite presentation channel.")
	var shake_state := synthetic.duplicate(true)
	var shake_snapshot: Dictionary = (shake_state.get("coin_pusher_snapshot", {}) as Dictionary).duplicate(true)
	shake_snapshot["events"] = [{"kind": "cabinet_shake", "body_id": "cabinet", "x": 50000, "y": 52000, "z": 0, "intensity_milli": 900, "tick_offset": 1, "metadata": {}}]
	shake_snapshot["tell_rung"] = 0
	shake_state["coin_pusher_snapshot"] = shake_snapshot
	harness.setup(shake_state)
	harness.animation_active = true
	harness.animation_progress = 0.12
	harness.flicker_value = 0.37
	game.draw_surface(harness, shake_state, {"synthetic_snapshot_without_solver": true})
	var first_transform: Dictionary = harness.draw_transform_records.front() if not harness.draw_transform_records.is_empty() else {}
	var last_transform: Dictionary = harness.draw_transform_records.back() if not harness.draw_transform_records.is_empty() else {}
	if (first_transform.get("position", Vector2.ZERO) as Vector2).is_zero_approx() \
			or not (last_transform.get("position", Vector2.INF) as Vector2).is_zero_approx():
		failures.append("Coin Pusher nudge shake did not transform and then restore the complete cabinet draw as one unit.")
	var watch_state := synthetic.duplicate(true)
	var watch_snapshot: Dictionary = (watch_state.get("coin_pusher_snapshot", {}) as Dictionary).duplicate(true)
	watch_snapshot["tell_rung"] = 3
	watch_snapshot["tell_label"] = "attendant watches"
	watch_snapshot["locked"] = false
	watch_state["coin_pusher_snapshot"] = watch_snapshot
	harness.setup(watch_state)
	game.draw_surface(harness, watch_state, {"synthetic_snapshot_without_solver": true})
	if not harness.labels.has("WATCH") or harness.labels.has("ALARM"):
		failures.append("Coin Pusher pre-alarm tell rung 3 is mislabeled as a hard alarm.")
	watch_snapshot["locked"] = true
	harness.setup(watch_state)
	game.draw_surface(harness, watch_state, {"synthetic_snapshot_without_solver": true})
	if not harness.labels.has("ALARM"):
		failures.append("Coin Pusher hard-lock state does not visibly reserve the ALARM label for the actual alarm.")
	for forbidden_legacy_field in ["coin_pusher_bodies", "coin_pusher_riders", "coin_pusher_features", "coin_pusher_upper_phase_milli", "coin_pusher_lower_phase_milli", "coin_pusher_tell_rung", "coin_pusher_presentation_events", "coin_pusher_presentation_trace"]:
		if synthetic.has(forbidden_legacy_field):
			failures.append("Synthetic snapshot boundary still duplicates physical field %s outside the snapshot." % forbidden_legacy_field)
	var narrow_geometry: Dictionary = ((synthetic.get("coin_pusher_snapshot", {}) as Dictionary).get("geometry", {}) as Dictionary).duplicate(true)
	var wide_geometry: Dictionary = narrow_geometry.duplicate(true)
	wide_geometry["width"] = 200000
	var narrow_position: Vector2 = game.call("_body_screen_position", synthetic_body, narrow_geometry)
	var wide_position: Vector2 = game.call("_body_screen_position", synthetic_body, wide_geometry)
	if narrow_position.is_equal_approx(wide_position):
		failures.append("Coin Pusher renderer ignored synthetic snapshot geometry and therefore still depends on solver geometry.")
	var source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher.gd")
	var render_cells := _source_function(source, "_draw_cells")
	if render_cells.is_empty() or render_cells.contains("CoinPusherSolverScript"):
		failures.append("Coin Pusher render helpers reach through the renderer-agnostic snapshot into solver internals.")
	if render_cells.contains("sort_custom"):
		failures.append("Coin Pusher renderer still sorts every physical body per frame instead of consuming snapshot depth order.")
	var render_coin := _source_function(source, "_draw_coin_body")
	if not render_coin.contains("draw_texture_rect") or render_coin.contains("draw_circle"):
		failures.append("Coin Pusher physical coins are not using the cached one-glyph-per-coin render path.")
	var render_surface := _source_function(source, "draw_surface")
	if render_surface.contains("_draw_riders(") or render_surface.contains("_draw_variation_features("):
		failures.append("Coin Pusher renderer re-walks all bodies for riders/features instead of classifying them in one pass.")
	for renderer_function in ["draw_surface", "surface_motion_signature"]:
		if _source_call_graph_contains(source, renderer_function, "CoinPusherSolverScript"):
			failures.append("Coin Pusher renderer helper graph rooted at %s reaches through its snapshot into solver internals." % renderer_function)
	coin_pusher_snapshot_boundary_exercised = true


func _check_coin_pusher_presentation_event_authority_invariance(failures: Array) -> void:
	var source := CoinPusherSolverScript.create(_configured_rng(6077), 160, 150, 5)
	(source.get("bodies", []) as Array).append_array([
		_solver_body("event_probe_coin", "coin", 25000, 30000, 9000, false),
		_solver_body("event_probe_rider", "rider", 62000, 64000, CoinPusherSolverScript.UPPER_FLOOR_Z, true),
		_solver_body("event_probe_puck", "puck", 71000, 70000, CoinPusherSolverScript.UPPER_FLOOR_Z, true),
	])
	var reference_state := source.duplicate(true)
	var instrumented_state := source.duplicate(true)
	var reference_step := CoinPusherSolverScript.step_action(reference_state, {
		"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true,
		"emit_presentation_events": false,
	})
	var instrumented_step := CoinPusherSolverScript.step_action(instrumented_state, {
		"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true,
	})
	var reference_features := _coin_pusher_feature_body_digest(reference_state)
	var instrumented_features := _coin_pusher_feature_body_digest(instrumented_state)
	if JSON.stringify(CoinPusherSolverScript.canonical_digest(reference_state)) != JSON.stringify(CoinPusherSolverScript.canonical_digest(instrumented_state)) \
			or JSON.stringify(reference_step.get("events", [])) != JSON.stringify(instrumented_step.get("events", [])) \
			or JSON.stringify(_coin_pusher_trace_body_digest(reference_step)) != JSON.stringify(_coin_pusher_trace_body_digest(instrumented_step)) \
			or CoinPusherSolverScript.coin_count(reference_state) != CoinPusherSolverScript.coin_count(instrumented_state) \
			or JSON.stringify(reference_features) != JSON.stringify(instrumented_features):
		failures.append("Coin Pusher presentation impact instrumentation changed authoritative bodies, exits, replay frames, density, or feature objects.")
	if not (reference_step.get("presentation_events", []) as Array).is_empty() \
			or _presentation_event_for_body(instrumented_step, "impact", "event_probe_coin").is_empty():
		failures.append("Coin Pusher presentation-only impact proof did not isolate its event stream from authoritative solver output.")


func _coin_pusher_trace_body_digest(step: Dictionary) -> Array:
	var result: Array = []
	for value in step.get("presentation_trace", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = value
		result.append({"tick_offset": int(frame.get("tick_offset", 0)), "bodies": frame.get("bodies", [])})
	return result


func _coin_pusher_feature_body_digest(state: Dictionary) -> Array:
	var result: Array = []
	for value in state.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = value
		if str(body.get("kind", "")) in ["rider", "puck", "fragment"]:
			result.append(body.duplicate(true))
	return result


func _check_coin_pusher_visible_timing(game: GameModule, failures: Array) -> void:
	var early_fixture := _coin_pusher_fixture(game, "PUSHER-VISIBLE-TIMING")
	var late_fixture := _coin_pusher_fixture(game, "PUSHER-VISIBLE-TIMING")
	var replay_fixture := _coin_pusher_fixture(game, "PUSHER-VISIBLE-TIMING")
	var early_run: RunState = early_fixture.get("run_state")
	var late_run: RunState = late_fixture.get("run_state")
	var replay_run: RunState = replay_fixture.get("run_state")
	var early_surface := game.surface_state(early_run, early_run.current_environment, {"surface_time_msec": 0})
	var late_surface := game.surface_state(late_run, late_run.current_environment, {"surface_time_msec": 900})
	var early_command := game.surface_action_command("coin_pusher_drop", 0, false, {"surface_time_msec": 0, "coin_pusher_lane": 2}, early_run, early_run.current_environment)
	var late_command := game.surface_action_command("coin_pusher_drop", 0, false, {"surface_time_msec": 900, "coin_pusher_lane": 2}, late_run, late_run.current_environment)
	var replay_command := game.surface_action_command("coin_pusher_drop", 0, false, {"surface_time_msec": 0, "coin_pusher_lane": 2}, replay_run, replay_run.current_environment)
	var early_ui: Dictionary = early_command.get("ui_state", {})
	var late_ui: Dictionary = late_command.get("ui_state", {})
	var replay_ui: Dictionary = replay_command.get("ui_state", {})
	if int(early_ui.get("coin_pusher_upper_input_phase", -1)) != int(_presentation_snapshot(early_surface).get("upper_phase_milli", -2000)) / 1000 \
			or int(late_ui.get("coin_pusher_upper_input_phase", -1)) != int(_presentation_snapshot(late_surface).get("upper_phase_milli", -2000)) / 1000:
		failures.append("Quarter Falls click did not capture the exact shelf phase shown to the player.")
	if int(early_ui.get("coin_pusher_upper_input_phase", -1)) == int(late_ui.get("coin_pusher_upper_input_phase", -1)):
		failures.append("Quarter Falls visible pusher phase did not sweep as surface time advanced.")
	var early_result := game.resolve_with_context("drop_quarter", 0, early_run, early_run.current_environment, early_run.create_rng("visible_timing"), early_ui)
	var late_result := game.resolve_with_context("drop_quarter", 0, late_run, late_run.current_environment, late_run.create_rng("visible_timing"), late_ui)
	var replay_result := game.resolve_with_context("drop_quarter", 0, replay_run, replay_run.current_environment, replay_run.create_rng("visible_timing"), replay_ui)
	var early_machine: Dictionary = (early_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var late_machine: Dictionary = (late_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var early_bodies := JSON.stringify(CoinPusherSolverScript.canonical_digest(early_machine.get("simulation", {})).get("bodies", []))
	var late_bodies := JSON.stringify(CoinPusherSolverScript.canonical_digest(late_machine.get("simulation", {})).get("bodies", []))
	if int(early_result.get("coin_pusher_input_phase", -1)) == int(late_result.get("coin_pusher_input_phase", -1)) or early_bodies == late_bodies:
		failures.append("Quarter Falls different visible click phases did not produce different timing and physical pile outcomes.")
	if JSON.stringify(early_result.get("coin_pusher_solver_metrics", {})) != JSON.stringify(replay_result.get("coin_pusher_solver_metrics", {})) \
			or game.deterministic_state_digest(early_run.current_environment) != game.deterministic_state_digest(replay_run.current_environment):
		failures.append("Quarter Falls replaying the same captured display phase did not reproduce the exact pile.")


func _check_coin_pusher_presentation_replay(game: GameModule, failures: Array) -> void:
	var owned_events := [{"kind": "ownership_probe"}]
	var owned_trace := [{"tick_offset": 0, "bodies": []}]
	var owned_patch: Dictionary = game.call("_presentation_action_snapshot_patch", {"action_count": 4}, "ownership_probe", owned_events, owned_trace)
	if not _coin_pusher_arrays_share_reference(owned_events, owned_patch.get("events", [])) \
			or not _coin_pusher_arrays_share_reference(owned_trace, owned_patch.get("trace", [])):
		failures.append("Quarter Falls action presentation boundary copied its freshly owned event or trace arrays.")
	var view_model_script: Script = load("res://scripts/ui/foundation_action_view_model.gd")
	var source_deltas := {"bankroll_delta": 1, "messages": ["isolated"]}
	var stored_result: Dictionary = view_model_script.stored_game_result_snapshot({
		"game_id": "coin_pusher", "deltas": source_deltas,
		"surface_presentation_snapshot_patch": owned_patch,
	})
	if not _coin_pusher_dictionaries_share_reference(owned_patch, stored_result.get("surface_presentation_snapshot_patch", {})) \
			or _coin_pusher_dictionaries_share_reference(source_deltas, stored_result.get("deltas", {})):
		failures.append("Quarter Falls host result storage did not transfer only its immutable presentation patch while isolating ordinary result data.")
	var drop_fixture := _coin_pusher_fixture(game, "PUSHER-PRESENTATION-DROP")
	var drop_run: RunState = drop_fixture.get("run_state")
	var drop_ui := {"coin_pusher_lane": 2, "coin_pusher_upper_input_phase": 2, "coin_pusher_lower_input_phase": 5, "coin_pusher_capture_presentation_trace": true}
	var drop_result := game.resolve_with_context("drop_quarter", 1, drop_run, drop_run.current_environment, drop_run.create_rng("presentation_drop"), drop_ui)
	var drop_trace := _presentation_trace(drop_result)
	if not bool(drop_result.get("ok", false)) or drop_trace.size() < 4 or drop_trace.size() > 15 or not _trace_visibly_moves(drop_trace):
		failures.append("Quarter Falls drop did not expose a bounded authoritative body-motion replay.")
	var drop_machine: Dictionary = (drop_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if drop_machine.has("coin_pusher_presentation_trace") or (drop_machine.get("simulation", {}) as Dictionary).has("presentation_trace"):
		failures.append("Quarter Falls serialized its transient presentation replay into the node snapshot.")
	var final_trace_bodies: Array = (drop_trace.back() as Dictionary).get("bodies", []) if not drop_trace.is_empty() and typeof(drop_trace.back()) == TYPE_DICTIONARY else []
	var drop_simulation: Dictionary = drop_machine.get("simulation", {}) if typeof(drop_machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	if JSON.stringify(final_trace_bodies) != JSON.stringify(CoinPusherSolverScript.body_views(drop_simulation)):
		failures.append("Quarter Falls drop replay did not end on the exact authoritative persisted pile.")
	var persisted_digest: String = game.deterministic_state_digest(drop_run.current_environment)
	var persisted_save_json := JSON.stringify(drop_run.to_save_snapshot())
	if persisted_save_json.contains("surface_presentation_snapshot_patch") or persisted_save_json.contains("presentation_trace"):
		failures.append("Quarter Falls transient presentation replay leaked into the durable run save snapshot.")
	var replay_surface := game.surface_state(drop_run, drop_run.current_environment, {"surface_time_msec": 1000})
	_presentation_snapshot(replay_surface)["trace"] = drop_trace
	var replay_harness := SurfaceHarness.new()
	replay_harness.setup(replay_surface)
	replay_harness.animation_active = true
	replay_harness.animation_progress = 0.0
	var replay_start: Dictionary = game.surface_motion_signature(replay_harness, replay_surface)
	replay_harness.animation_progress = 0.5
	var replay_middle: Dictionary = game.surface_motion_signature(replay_harness, replay_surface)
	replay_harness.animation_progress = 1.0
	var replay_end: Dictionary = game.surface_motion_signature(replay_harness, replay_surface)
	if int(replay_start.get("physics_body_checksum", 0)) == int(replay_middle.get("physics_body_checksum", 0)) \
			or int(replay_middle.get("physics_body_checksum", 0)) == int(replay_end.get("physics_body_checksum", 0)):
		failures.append("Quarter Falls player-facing drop replay did not visibly advance body positions through time.")
	var reduced_surface := replay_surface.duplicate(true)
	reduced_surface["reduce_motion"] = true
	replay_harness.setup(reduced_surface)
	replay_harness.animation_progress = 0.0
	var reduced_sample: Dictionary = game.surface_motion_signature(replay_harness, reduced_surface)
	if int(reduced_sample.get("physics_body_checksum", 0)) != int(replay_end.get("physics_body_checksum", -1)):
		failures.append("Quarter Falls reduced motion did not jump directly to the authoritative final pile.")
	if game.deterministic_state_digest(drop_run.current_environment) != persisted_digest:
		failures.append("Quarter Falls presentation replay mutated the authoritative pile.")
	var first_patch: Dictionary = drop_result.get("surface_presentation_snapshot_patch", {}) if typeof(drop_result.get("surface_presentation_snapshot_patch", {})) == TYPE_DICTIONARY else {}
	var first_trace_json := JSON.stringify(first_patch.get("trace", []))
	var following_result := game.resolve_with_context("nudge_machine", 0, drop_run, drop_run.current_environment, drop_run.create_rng("presentation_following_action"), {
		"coin_pusher_lane": 2, "coin_pusher_force": "tap", "coin_pusher_direction": "front",
		"coin_pusher_upper_input_phase": 2, "coin_pusher_lower_input_phase": 5, "coin_pusher_capture_presentation_trace": true,
	})
	var following_patch: Dictionary = following_result.get("surface_presentation_snapshot_patch", {}) if typeof(following_result.get("surface_presentation_snapshot_patch", {})) == TYPE_DICTIONARY else {}
	if first_trace_json != JSON.stringify(first_patch.get("trace", [])) \
			or _coin_pusher_arrays_share_reference(first_patch.get("trace", []), following_patch.get("trace", [])):
		failures.append("Quarter Falls reused or mutated a prior action's presentation trace when the following action resolved.")
	var headless_fixture := _coin_pusher_fixture(game, "PUSHER-NO-PRESENTATION-TRACE")
	var headless_run: RunState = headless_fixture.get("run_state")
	var headless_result := game.resolve_with_context("drop_quarter", 1, headless_run, headless_run.current_environment, headless_run.create_rng("no_presentation_trace"), {"coin_pusher_lane": 2})
	if not _presentation_trace(headless_result).is_empty():
		failures.append("Quarter Falls generated replay frames for a non-presented headless action.")

	var nudge_fixture := _coin_pusher_fixture(game, "PUSHER-PRESENTATION-NUDGE")
	var nudge_run: RunState = nudge_fixture.get("run_state")
	var nudge_result := game.resolve_with_context("nudge_machine", 0, nudge_run, nudge_run.current_environment, nudge_run.create_rng("presentation_nudge"), {
		"coin_pusher_lane": 2, "coin_pusher_force": "slam", "coin_pusher_direction": "front",
		"coin_pusher_upper_input_phase": 2, "coin_pusher_lower_input_phase": 5, "coin_pusher_capture_presentation_trace": true,
	})
	var nudge_trace := _presentation_trace(nudge_result)
	if not bool(nudge_result.get("ok", false)) or not _trace_visibly_moves(nudge_trace):
		failures.append("Quarter Falls nudge did not expose visible real-pile movement from the authoritative solver.")

	var fall_state := CoinPusherSolverScript.create(_configured_rng(6141), 48, 0, 5)
	fall_state["bodies"] = [
		_solver_body("replay_upper", "coin", 50000, CoinPusherSolverScript.UPPER_EDGE - 1000, CoinPusherSolverScript.UPPER_FLOOR_Z, false),
		_solver_body("replay_tray", "coin", 50000, 2000, 0, false),
		_solver_body("replay_gutter", "coin", 1000, 2000, 0, false),
	]
	var fall_step := CoinPusherSolverScript.step_action(fall_state, {"upper_locked": true, "lower_locked": true, "capture_presentation_trace": true})
	var fall_trace: Array = fall_step.get("presentation_trace", [])
	if not _trace_body_changes_level(fall_trace, "replay_upper") or not _trace_has_exit_path(fall_trace, "replay_tray", "tray") or not _trace_has_exit_path(fall_trace, "replay_gutter", "gutter"):
		failures.append("Quarter Falls replay did not preserve legible upper-to-lower, tray, and gutter body paths.")

	# A feature spawned by the resolved action may exist only in the final
	# authoritative frame. Preserve an older trace feature by stable body id,
	# while drawing the final-only feature instead of hiding it until replay end.
	var selected_features := [
		{"id": "existing_rider_body", "kind": "rider"},
		{"id": "settled_coin", "kind": "coin"},
	]
	var existing_final := {"id": "existing_rider_body", "kind": "rider"}
	var spawned_final := {"id": "spawned_rider_body", "kind": "rider"}
	if bool(game.call("_should_draw_authoritative_feature", selected_features, existing_final, "rider")) \
			or not bool(game.call("_should_draw_authoritative_feature", selected_features, spawned_final, "rider")):
		failures.append("Quarter Falls replay did not reconcile one trace rider plus one final-only rider by stable body id.")
	var selected_pucks := [{"id": "existing_puck_body", "kind": "puck"}]
	var existing_puck := {"id": "existing_puck_body", "kind": "puck"}
	var spawned_fragment := {"id": "spawned_fragment_body", "kind": "fragment"}
	if bool(game.call("_should_draw_authoritative_feature", selected_pucks, existing_puck, "variation")) \
			or not bool(game.call("_should_draw_authoritative_feature", selected_pucks, spawned_fragment, "variation")):
		failures.append("Pusher variation replay did not reconcile existing and final-only physical features by stable body id.")


func _trace_visibly_moves(trace: Array) -> bool:
	if trace.size() < 2 or typeof(trace.front()) != TYPE_DICTIONARY or typeof(trace.back()) != TYPE_DICTIONARY:
		return false
	return JSON.stringify((trace.front() as Dictionary).get("bodies", [])) != JSON.stringify((trace.back() as Dictionary).get("bodies", []))


func _check_coin_pusher_feature_reconciliation(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-FEATURE-RECONCILIATION")
	var run_state: RunState = fixture.get("run_state")
	var machine: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	machine["variation_id"] = "quarter_falls"
	machine["riders"] = [
		{"id": "replacement_rider_a", "kind": "chip_stack", "label": "first", "cash_value": 4, "lane": 1, "cell": 2},
		{"id": "replacement_rider_b", "kind": "item", "label": "second", "item_id": "cold_quarters", "lane": 3, "cell": 3},
	]
	game.call("_sync_physical_features", machine)
	var physical_feature_ids: Array = []
	for body_value in CoinPusherSolverScript.body_views(machine.get("simulation", {})):
		if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("kind", "")) != "rider":
			continue
		var metadata: Dictionary = (body_value as Dictionary).get("metadata", {}) if typeof((body_value as Dictionary).get("metadata", {})) == TYPE_DICTIONARY else {}
		physical_feature_ids.append(str(metadata.get("feature_id", "")))
	physical_feature_ids.sort()
	if physical_feature_ids != ["replacement_rider_a", "replacement_rider_b"]:
		failures.append("Quarter Falls durable feature-ledger replacement left a stale physical rider or failed to add exactly the desired feature ids: %s." % JSON.stringify(physical_feature_ids))


func _trace_body_changes_level(trace: Array, body_id: String) -> bool:
	var first_z := 0
	var last_z := 0
	var seen := false
	for frame_value in trace:
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		for body_value in (frame_value as Dictionary).get("bodies", []):
			if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("id", "")) == body_id:
				if not seen:
					first_z = int((body_value as Dictionary).get("z", 0))
				seen = true
				last_z = int((body_value as Dictionary).get("z", 0))
	return seen and first_z >= CoinPusherSolverScript.UPPER_FLOOR_Z and last_z < CoinPusherSolverScript.UPPER_FLOOR_Z


func _trace_has_exit_path(trace: Array, body_id: String, outcome: String) -> bool:
	var positions: Array = []
	var terminal_count := 0
	for frame_value in trace:
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		for body_value in (frame_value as Dictionary).get("bodies", []):
			if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("id", "")) != body_id:
				continue
			var body: Dictionary = body_value
			positions.append([int(body.get("x", 0)), int(body.get("y", 0)), int(body.get("z", 0))])
			if str(body.get("rest_state", "")) == "falling_%s" % outcome:
				terminal_count += 1
	return positions.size() >= 3 and terminal_count >= 2 and JSON.stringify(positions.front()) != JSON.stringify(positions.back())


func _check_coin_pusher_reduced_motion_freeze(game: GameModule, surface: Dictionary, failures: Array) -> void:
	var reduced_surface := surface.duplicate(true)
	reduced_surface["reduce_motion"] = true
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("set_game_module", game)
	canvas.call("render_game_snapshot", reduced_surface)
	canvas.call("reset_performance_counters")
	var state_before: Dictionary = canvas.call("realtime_surface_state").duplicate(true)
	var motion_before: Dictionary = canvas.call("debug_surface_motion_sample")
	for _frame_index in range(18):
		canvas.call("debug_advance_idle_liveness", 1.0 / 60.0)
	var state_after: Dictionary = canvas.call("realtime_surface_state")
	var motion_after: Dictionary = canvas.call("debug_surface_motion_sample")
	var runtime: Dictionary = canvas.call("surface_runtime_status")
	if not bool(runtime.get("reduce_motion", false)):
		failures.append("Quarter Falls reduced-motion preference did not reach the live surface canvas.")
	if JSON.stringify(motion_before) != JSON.stringify(motion_after):
		failures.append("Quarter Falls reduced motion did not freeze its real shelf/rider presentation sample.")
	if int(runtime.get("surface_animation_redraw_count", -1)) != 0 or bool(runtime.get("surface_continuous_redraw_active", true)):
		failures.append("Quarter Falls reduced motion still scheduled continuous surface redraws.")
	if JSON.stringify(state_before) != JSON.stringify(state_after) \
			or str(state_after.get("surface_renderer", "")) != "coin_pusher" \
			or (_presentation_snapshot(state_after).get("bodies", []) as Array).size() != (_presentation_snapshot(state_before).get("bodies", []) as Array).size() \
			or (_presentation_snapshot(state_after).get("riders", []) as Array).size() != (_presentation_snapshot(state_before).get("riders", []) as Array).size() \
			or int(_presentation_snapshot(state_after).get("tell_rung", -1)) != int(_presentation_snapshot(state_before).get("tell_rung", -2)):
		failures.append("Quarter Falls reduced motion hid or changed the visible pile state.")
	root.remove_child(canvas)
	canvas.free()


func _check_coin_pusher_read_boundaries(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-READ-BOUNDARY")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	run_state.add_item("coin_return_shim")
	var generation_environment := _coin_pusher_environment("pusher_generation_boundary")
	var generator := RunGeneratorScript.new(game.library)
	var generated_states: Dictionary = generator._generated_game_states(run_state, generation_environment, run_state.create_rng("pusher_generation_boundary"))
	if not generated_states.has("coin_pusher") or run_state.rumor_fact("pusher:bar").is_empty():
		failures.append("Quarter Falls canonical environment generation did not publish its initial node-scoped pile rumor.")
	var generated_machine: Dictionary = generated_states.get("coin_pusher", {}) if typeof(generated_states.get("coin_pusher", {})) == TYPE_DICTIONARY else {}
	if not bool(generated_machine.get("shim_initialized", false)) or int(generated_machine.get("shim_uses_remaining", 0)) != 3:
		failures.append("Quarter Falls canonical environment generation did not persist the owned Coin-Return Shim state.")
	var fast_outputs := {
		"legal": game.legal_actions(run_state, environment),
		"cheat": game.cheat_actions(run_state, environment),
		"actions": game.actions(run_state, environment),
		"surface": game.surface_state(run_state, environment, {"surface_time_msec": 1000}),
	}
	var normalized_copy_environment := environment.duplicate(true)
	var normalized_copy_machine: Dictionary = ((normalized_copy_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary)
	normalized_copy_machine["version"] = maxi(0, int(normalized_copy_machine.get("version", 1)) - 1)
	var copied_outputs := {
		"legal": game.legal_actions(run_state, normalized_copy_environment),
		"cheat": game.cheat_actions(run_state, normalized_copy_environment),
		"actions": game.actions(run_state, normalized_copy_environment),
		"surface": game.surface_state(run_state, normalized_copy_environment, {"surface_time_msec": 1000}),
	}
	for output_key in fast_outputs.keys():
		if JSON.stringify(fast_outputs.get(output_key)) != JSON.stringify(copied_outputs.get(output_key)):
			failures.append("Quarter Falls scalar readonly fast path changed byte-identical %s output versus normalized-copy reads." % output_key)
	if game.deterministic_state_digest(environment) != game.deterministic_state_digest(normalized_copy_environment):
		failures.append("Quarter Falls scalar readonly fast path changed the canonical machine digest.")
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	# Exercise every branch that previously wrote through a read alias.
	machine["locked_down"] = true
	machine["lockdown_night"] = "stale-night"
	machine["shim_initialized"] = false
	var serialized_before := JSON.stringify(run_state.to_dict())
	game.enter(run_state, environment)
	game.actions(run_state, environment)
	game.surface_state(run_state, environment, {"surface_time_msec": 1000})
	game.environment_object_state(run_state, environment)
	var serialized_after := JSON.stringify(run_state.to_dict())
	if serialized_before != serialized_after:
		failures.append("Quarter Falls enter/actions/surface reads mutated serialized RunState.")
	environment["scenario_game_modifiers"] = {"coin_pusher": {"reset_pile": true, "reset_token": "read_boundary_reset"}}
	var serialized_before_reset_read := JSON.stringify(run_state.to_dict())
	game.enter(run_state, environment)
	game.actions(run_state, environment)
	game.surface_state(run_state, environment, {})
	if serialized_before_reset_read != JSON.stringify(run_state.to_dict()):
		failures.append("Quarter Falls scenario-reset presentation reads mutated serialized RunState.")


func _check_coin_pusher_determinism(game: GameModule, failures: Array) -> void:
	var first := _coin_pusher_mixed_scripted_session(game, "PUSHER-200", PUSHER_DETERMINISM_ACTIONS)
	var second := _coin_pusher_mixed_scripted_session(game, "PUSHER-200", PUSHER_DETERMINISM_ACTIONS)
	if str(first.get("digest", "")) != str(second.get("digest", "")):
		failures.append("Quarter Falls 200-action pile evolution diverged for identical seed and inputs.")
	if JSON.stringify(first.get("outcomes", [])) != JSON.stringify(second.get("outcomes", [])):
		failures.append("Quarter Falls 200-action payouts/gutters diverged for identical seed and inputs.")
	if int(first.get("actions", 0)) != PUSHER_DETERMINISM_ACTIONS:
		failures.append("Quarter Falls deterministic fixture did not complete all 200 actions.")
	if int(first.get("nudge_count", 0)) <= 0 or int(first.get("alarm_count", 0)) != 1:
		failures.append("Quarter Falls 200-action twin replay did not cover mixed nudges and exactly one real alarm outcome.")


func _check_coin_pusher_security_bands(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PUSHER-SECURITY-BANDS")
	var normal := _coin_pusher_environment("security_normal")
	var lax := _coin_pusher_environment("security_lax")
	var strict := _coin_pusher_environment("security_strict")
	var swept := _coin_pusher_environment("security_swept")
	normal["security_profile"] = {"machine_alarm_tolerance_band": "normal"}
	lax["security_profile"] = {"machine_alarm_tolerance_band": "lax"}
	strict["security_profile"] = {"machine_alarm_tolerance_band": "strict"}
	swept["security_profile"] = {"machine_alarm_tolerance_band": "normal", "pusher_alarm_tolerance_band_delta": 1}
	var base_seed := 481516
	var normal_state := game.generate_environment_state(run_state, normal, _configured_rng(base_seed))
	var lax_state := game.generate_environment_state(run_state, lax, _configured_rng(base_seed))
	var strict_state := game.generate_environment_state(run_state, strict, _configured_rng(base_seed))
	var swept_state := game.generate_environment_state(run_state, swept, _configured_rng(base_seed))
	var normal_tolerance := int(normal_state.get("alarm_tolerance_remaining", 0))
	if int(lax_state.get("alarm_tolerance_remaining", 0)) != normal_tolerance + 2:
		failures.append("Graveyard/lax scenario band did not add two pusher tolerance steps.")
	if int(strict_state.get("alarm_tolerance_remaining", 0)) != normal_tolerance - 2:
		failures.append("Serial-Check/strict adjacency band did not remove two pusher tolerance steps.")
	if int(swept_state.get("alarm_tolerance_remaining", 0)) != normal_tolerance + 1:
		failures.append("Swept-window pusher tolerance modifier did not add one band step.")
	var adjacency_run: RunState = RunStateScript.new()
	adjacency_run.start_new("PUSHER-SERIAL-ADJACENCY")
	adjacency_run.world_map = {
		"current_node_id": "bar_node",
		"start_node_id": "bar_node",
		"nodes": [
			{"id": "bar_node", "archetype_id": "bar", "label": "Roadside Bar", "kind": "casino", "tier": 1},
			{"id": "pawn_node", "archetype_id": "pawn_shop", "label": "Sal's Pawn", "kind": "shop", "tier": 1},
		],
		"edges": [{"a": "bar_node", "b": "pawn_node"}],
	}
	adjacency_run.town_state.configure_world(adjacency_run.world_map)
	var adjacency_environment := _coin_pusher_environment("bar_node")
	adjacency_environment["world_node_id"] = "bar_node"
	adjacency_run.set_environment(adjacency_environment)
	var adjacency_baseline := game.generate_environment_state(adjacency_run, adjacency_run.current_environment, _configured_rng(base_seed))
	var serial_definition := game.library.scenario("pawn_shop_serial_check_day")
	adjacency_run.seed_scenario_for_node("pawn_node", serial_definition)
	var adjacency_strict := game.generate_environment_state(adjacency_run, adjacency_run.current_environment, _configured_rng(base_seed))
	if int(adjacency_strict.get("alarm_tolerance_remaining", 0)) != int(adjacency_baseline.get("alarm_tolerance_remaining", 0)) - 2:
		failures.append("Authored nearby_alarm_tolerance_band on an adjacent production Serial-Check scenario did not tighten pusher tolerance.")
	var public_surface := game.surface_state(run_state, {"id": "hidden", "game_states": {"coin_pusher": normal_state}}, {})
	if public_surface.has("alarm_tolerance_remaining") or public_surface.has("base_alarm_tolerance"):
		failures.append("Quarter Falls leaked hidden machine tolerance into its public surface.")
	_check_coin_pusher_production_swept_window(game, base_seed, failures)


func _check_coin_pusher_force_matrix(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {}) if typeof(definition.get("coin_pusher_tuning", {})) == TYPE_DICTIONARY else {}
	var forces: Dictionary = tuning.get("nudge_forces", {}) if typeof(tuning.get("nudge_forces", {})) == TYPE_DICTIONARY else {}
	var expected := {"tap": [1, 1, 1], "shove": [2, 2, 2], "slam": [4, 4, 6]}
	for force_value in expected.keys():
		var force := str(force_value)
		var expected_values: Array = expected.get(force, [])
		var force_data: Dictionary = forces.get(force, {}) if typeof(forces.get(force, {})) == TYPE_DICTIONARY else {}
		if int(force_data.get("tolerance_cost", -1)) != int(expected_values[0]) or int(force_data.get("push_strength", -1)) != int(expected_values[1]):
			failures.append("Quarter Falls %s force is not fully data-authored at tolerance/push %s." % [force, JSON.stringify(expected_values.slice(0, 2))])
		var bad_fixture := _coin_pusher_fixture(game, "PUSHER-FORCE-BAD-%s" % force.to_upper())
		var bad_run: RunState = bad_fixture.get("run_state")
		var bad_machine: Dictionary = (bad_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
		bad_machine["alarm_tolerance_remaining"] = 10
		var bad_result := game.resolve_with_context("nudge_machine", 0, bad_run, bad_run.current_environment, bad_run.create_rng("force_bad"), {
			"coin_pusher_force": force, "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
		})
		if int(bad_result.get("coin_pusher_tolerance_spent", -1)) != int(expected_values[0]) \
				or int(bad_result.get("coin_pusher_force_push", -1)) != int(expected_values[1]) \
				or int(bad_machine.get("alarm_tolerance_remaining", -1)) != 10 - int(expected_values[0]):
			failures.append("Mistimed %s did not spend/publish its exact authored tolerance and push trade." % force)
		var clean_fixture := _coin_pusher_fixture(game, "PUSHER-FORCE-CLEAN-%s" % force.to_upper())
		var clean_run: RunState = clean_fixture.get("run_state")
		var clean_machine: Dictionary = (clean_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
		_machine_hanger_fixture(clean_machine, 2)
		clean_machine["alarm_tolerance_remaining"] = 10
		var clean_result := game.resolve_with_context("nudge_machine", 0, clean_run, clean_run.current_environment, clean_run.create_rng("force_clean"), {
			"coin_pusher_force": force, "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 3,
		})
		if not bool(clean_result.get("coin_pusher_clean_drop", false)) or int(clean_result.get("coin_pusher_tolerance_spent", -1)) != 0 \
				or int(clean_result.get("coin_pusher_push_strength", -1)) != int(expected_values[2]):
			failures.append("Clean %s did not preserve tolerance and apply its authored push trade." % force)


func _check_coin_pusher_production_swept_window(game: GameModule, base_seed: int, failures: Array) -> void:
	var town := TownStateScript.new()
	town.generate(4021, _coin_pusher_sweep_conditions())
	town.configure_world(_coin_pusher_sweep_map())
	var status := town.sweep_internal_status()
	if status.is_empty() or town.police_sweep.segments.is_empty():
		failures.append("Quarter Falls production swept-window fixture did not spawn a Police Sweep track.")
		return
	var first_segment: Dictionary = town.police_sweep.segments[0] as Dictionary
	var departed_node := str(first_segment.get("node_id", ""))
	town.advance_actions(int(first_segment.get("end_action", 2)))
	var window := town.swept_window(departed_node)
	if window.is_empty():
		failures.append("Quarter Falls production swept-window fixture did not create a wake window.")
		return
	var sweep_run: RunState = RunStateScript.new()
	sweep_run.start_new("PUSHER-PRODUCTION-SWEEP")
	sweep_run.town_state = town
	var baseline_environment := _coin_pusher_environment(departed_node)
	baseline_environment["world_node_id"] = departed_node
	baseline_environment["security_profile"] = {"machine_alarm_tolerance_band": "normal"}
	var baseline_state := game.generate_environment_state(sweep_run, baseline_environment, _configured_rng(base_seed))
	var swept_environment := baseline_environment.duplicate(true)
	sweep_run.apply_town_living_world_context(swept_environment)
	var swept_security: Dictionary = swept_environment.get("security_profile", {}) if typeof(swept_environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var channels: Dictionary = swept_security.get("security_override_channels", {}) if typeof(swept_security.get("security_override_channels", {})) == TYPE_DICTIONARY else {}
	if typeof(channels.get("police_sweep", {})) != TYPE_DICTIONARY or str(swept_security.get("machine_alarm_tolerance_band", "")) != "lax":
		failures.append("Production Police Sweep did not compose its visible band and source channel for Quarter Falls.")
	var swept_state := game.generate_environment_state(sweep_run, swept_environment, _configured_rng(base_seed))
	if int(swept_state.get("alarm_tolerance_remaining", 0)) != int(baseline_state.get("alarm_tolerance_remaining", 0)) + 1:
		failures.append("Production swept-window composition did not grant exactly baseline +1 pusher tolerance.")
	var swept_surface := game.surface_state(sweep_run, {"id": departed_node, "game_states": {"coin_pusher": swept_state}}, {})
	if swept_surface.has("alarm_tolerance_remaining") or swept_surface.has("base_alarm_tolerance"):
		failures.append("Production swept-window tolerance leaked its hidden value into the pusher surface.")
	town.advance_actions(int(window.get("remaining_actions", 0)))
	sweep_run.apply_town_living_world_context(swept_environment)
	var restored_security: Dictionary = swept_environment.get("security_profile", {}) if typeof(swept_environment.get("security_profile", {})) == TYPE_DICTIONARY else {}
	var restored_channels: Dictionary = restored_security.get("security_override_channels", {}) if typeof(restored_security.get("security_override_channels", {})) == TYPE_DICTIONARY else {}
	if str(restored_security.get("machine_alarm_tolerance_band", "")) != "normal" or restored_security.has("pusher_alarm_tolerance_band_delta") or restored_channels.has("police_sweep"):
		failures.append("Expired Police Sweep window did not restore its authored security fields/channel.")
	var restored_state := game.generate_environment_state(sweep_run, swept_environment, _configured_rng(base_seed))
	if int(restored_state.get("alarm_tolerance_remaining", 0)) != int(baseline_state.get("alarm_tolerance_remaining", 0)):
		failures.append("Expired Police Sweep window did not restore baseline pusher tolerance exactly.")


func _check_coin_pusher_nudge_alarm(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-ALARM")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["base_alarm_tolerance"] = 3
	machine["tolerance_modifier"] = 0
	machine["alarm_tolerance_remaining"] = 3
	machine["tell_rung"] = 0
	var digest_before_clean: String = str(game.call("deterministic_state_digest", environment))
	var clean := game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("clean_nudge"), {
		"coin_pusher_force": "tap", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 3,
	})
	if not bool(clean.get("coin_pusher_clean_drop", false)) or int(clean.get("coin_pusher_tolerance_spent", -1)) != 0:
		failures.append("Well-timed, aimed Quarter Falls nudge did not preserve tolerance and clean the hanger.")
	if game.deterministic_state_digest(environment) == digest_before_clean:
		failures.append("A clean Quarter Falls nudge did not evolve the physical pile.")
	machine = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["base_alarm_tolerance"] = 3
	machine["tolerance_modifier"] = 0
	machine["alarm_tolerance_remaining"] = 3
	machine["tell_rung"] = 0
	var tell_rungs: Array = []
	var tell_event_kinds := {}
	var runtime_tell_kinds: Dictionary = {}
	var tell_runtime_sfx := SfxPlayerScript.new()
	var alarm_result: Dictionary = {}
	for nudge_index in range(4):
		alarm_result = game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("bad_nudge_%d" % nudge_index), {
			"coin_pusher_force": "tap", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
		})
		if nudge_index < 3:
			tell_rungs.append(int(alarm_result.get("coin_pusher_tell_rung", -1)))
		var presentation_patch: Dictionary = alarm_result.get("surface_presentation_snapshot_patch", {}) if typeof(alarm_result.get("surface_presentation_snapshot_patch", {})) == TYPE_DICTIONARY else {}
		for event_value in presentation_patch.get("events", []):
			if typeof(event_value) == TYPE_DICTIONARY:
				tell_event_kinds[str((event_value as Dictionary).get("kind", ""))] = true
		var runtime_surface: Dictionary = {"coin_pusher_snapshot": presentation_patch}
		var runtime_schedule: Array = tell_runtime_sfx.debug_coin_pusher_event_schedule(runtime_surface)
		var runtime_id: String = "production_nudge_%d" % nudge_index
		tell_runtime_sfx.debug_coin_pusher_runtime_event_markers(runtime_surface, 0.0, true, runtime_id, true)
		var runtime_markers: Array = tell_runtime_sfx.debug_coin_pusher_runtime_event_markers(runtime_surface, 0.8, false, runtime_id, false)
		if runtime_markers.size() != runtime_schedule.size():
			failures.append("Production nudge %d emitted %d audio-primary events but runtime SFX consumed %d." % [nudge_index, runtime_schedule.size(), runtime_markers.size()])
		else:
			for scheduled_value in runtime_schedule:
				if typeof(scheduled_value) == TYPE_DICTIONARY:
					runtime_tell_kinds[str((scheduled_value as Dictionary).get("kind", ""))] = true
		GameModule.apply_result(run_state, alarm_result, run_state.create_rng("bad_nudge_apply_%d" % nudge_index))
	tell_runtime_sfx.free()
	if JSON.stringify(tell_rungs) != JSON.stringify([1, 2, 3]):
		failures.append("Quarter Falls tell ladder did not fire rock, chirp, attendant glance in order: %s." % JSON.stringify(tell_rungs))
	for required_tell_event in ["tell_rock", "tell_chirp", "attendant_glance", "alarm"]:
		if not bool(tell_event_kinds.get(required_tell_event, false)):
			failures.append("Production nudge ladder did not emit required presentation/audio event %s." % required_tell_event)
		if not bool(runtime_tell_kinds.get(required_tell_event, false)):
			failures.append("Production nudge ladder event %s did not traverse runtime SFX routing." % required_tell_event)
	if not bool(alarm_result.get("coin_pusher_hard_alarm", false)) or not bool(alarm_result.get("coin_pusher_machine_locked", false)):
		failures.append("Quarter Falls tolerance crossing did not lock only the machine.")
	if int(alarm_result.get("suspicion_delta", 0)) < 8 or bool(alarm_result.get("ended", false)) or not bool(alarm_result.get("coin_pusher_player_remains_in_environment", false)):
		failures.append("Quarter Falls hard alarm was not significant heat with a nonterminal stay-in-environment result.")
	if str(run_state.current_environment.get("id", "")) != str(environment.get("id", "")) or run_state.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("Quarter Falls hard alarm forced departure or ended the active run.")
	var other_definition := library.game("bar_dice")
	var other_script: Script = load(str(other_definition.get("module_path", "")))
	var other_game: GameModule = other_script.new() if other_script != null else null
	if other_game == null:
		failures.append("Quarter Falls coexistence fixture could not load the other venue game.")
	else:
		other_game.setup(other_definition, library)
		var other_actions := other_game.actions(run_state, environment)
		if (other_actions.get("legal_actions", []) as Array).is_empty():
			failures.append("Quarter Falls alarm disabled another game in the same venue.")
	var locked_actions := game.actions(run_state, environment)
	if not (locked_actions.get("legal_actions", []) as Array).is_empty() or not (locked_actions.get("cheat_actions", []) as Array).is_empty():
		failures.append("Quarter Falls locked cabinet still offered machine actions.")
	if run_state.rumor_fact("pusher:%s" % run_state.current_world_node_id()).is_empty():
		failures.append("Quarter Falls pile did not publish its truth-traced pusher rumor fact.")
	if run_state.reputation_value(run_state.current_world_node_id(), "alarm_tripped") <= 0.0:
		failures.append("Quarter Falls alarm did not flow through the existing reputation writer.")
	var slam_fixture := _coin_pusher_fixture(game, "PUSHER-SLAM-GRAB")
	var slam_run: RunState = slam_fixture.get("run_state")
	var slam_machine: Dictionary = (slam_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(slam_machine, 2)
	slam_machine["alarm_tolerance_remaining"] = 0
	var slam_result := game.resolve_with_context("nudge_machine", 0, slam_run, slam_run.current_environment, slam_run.create_rng("slam_grab"), {
		"coin_pusher_force": "slam", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
	})
	if not bool(slam_result.get("coin_pusher_hard_alarm", false)) or int(slam_result.get("coin_pusher_payout", 0)) < 4:
		failures.append("Quarter Falls slam-and-grab did not deliver a meaningful drop before/with the alarm.")
	run_state.suspicion = {}
	var serialized_before_watch_entry := JSON.stringify(run_state.to_dict())
	game.enter(run_state, environment)
	game.enter(run_state, environment)
	if serialized_before_watch_entry != JSON.stringify(run_state.to_dict()):
		failures.append("Quarter Falls staff-watch revisit mutated serialized RunState during surface entry.")
	run_state.advance_game_clock_minutes(1440)
	var watched_drop := game.resolve_with_context("drop_quarter", 1, run_state, environment, run_state.create_rng("staff_watch_drop"), {"coin_pusher_lane": 2})
	if int(watched_drop.get("suspicion_delta", 0)) < 12:
		failures.append("Quarter Falls staff-watch memory did not restore its venue-scoped floor at the next action boundary.")
	GameModule.apply_result(run_state, watched_drop, run_state.create_rng("staff_watch_drop_apply"))
	var repeated_watch_drop := game.resolve_with_context("drop_quarter", 1, run_state, environment, run_state.create_rng("staff_watch_repeat"), {"coin_pusher_lane": 2})
	if int(repeated_watch_drop.get("suspicion_delta", 0)) != 0:
		failures.append("Quarter Falls staff-watch action-boundary floor was not idempotent after it was restored.")


func _check_coin_pusher_persistence_and_reset(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PUSHER-PERSIST")
	run_state.bankroll = 100000
	var generator: RunGenerator = RunGeneratorScript.new(game.library)
	generator.next_environment(run_state)
	generator.next_environment(run_state, "bar", true)
	var adjacent_node_id := _coin_pusher_adjacent_world_node(run_state.world_map, "bar")
	if adjacent_node_id.is_empty():
		failures.append("Production world map generated no real node adjacent to the Quarter Falls Bar fixture.")
		return
	var environment: Dictionary = run_state.current_environment
	var game_ids: Array = environment.get("game_ids", []) if typeof(environment.get("game_ids", [])) == TYPE_ARRAY else []
	if not game_ids.has("coin_pusher"):
		game_ids.append("coin_pusher")
		environment["game_ids"] = game_ids
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	if typeof(game_states.get("coin_pusher", {})) != TYPE_DICTIONARY or (game_states.get("coin_pusher", {}) as Dictionary).is_empty():
		game_states["coin_pusher"] = game.generate_environment_state(run_state, environment, run_state.create_rng("pusher_persist_initial"))
		environment["game_states"] = game_states
	for index in range(12):
		var result := game.resolve_with_context("drop_quarter", 1, run_state, environment, run_state.create_rng("persist_%d" % index), {"coin_pusher_lane": index % 5})
		GameModule.apply_result(run_state, result, run_state.create_rng("persist_apply_%d" % index))
	var alarm_machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(alarm_machine, 2)
	alarm_machine["alarm_tolerance_remaining"] = 0
	var alarm_result := game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("persist_alarm"), {
		"coin_pusher_force": "slam", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
	})
	GameModule.apply_result(run_state, alarm_result, run_state.create_rng("persist_alarm_apply"))
	if not bool(alarm_result.get("coin_pusher_hard_alarm", false)):
		failures.append("Production revisit fixture did not create a real persisted Quarter Falls lockdown.")
	var persisted_digest: String = str(game.call("deterministic_state_digest", environment))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if game.deterministic_state_digest(restored.current_environment) != persisted_digest:
		failures.append("Quarter Falls pile did not survive RunState save/load round-trip.")
	var restored_generator: RunGenerator = RunGeneratorScript.new(game.library)
	restored_generator.next_environment(restored, adjacent_node_id, true)
	if restored.current_world_node_id() != adjacent_node_id:
		failures.append("Quarter Falls production revisit fixture did not travel to its real adjacent node %s." % adjacent_node_id)
	var stored_bar := WorldMapScript.node_by_id(restored.world_map, "bar")
	var stored_bar_environment: Dictionary = stored_bar.get("environment", {}) if typeof(stored_bar.get("environment", {})) == TYPE_DICTIONARY else {}
	if game.deterministic_state_digest(stored_bar_environment) != persisted_digest:
		failures.append("Production world-node storage did not retain the exact Quarter Falls pile/lockdown/memory digest.")
	restored_generator.next_environment(restored, "bar", true)
	var revisited_machine: Dictionary = (restored.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if restored.current_world_node_id() != "bar" or game.deterministic_state_digest(restored.current_environment) != persisted_digest \
			or not bool(revisited_machine.get("locked_down", false)) or not bool(revisited_machine.get("staff_watch_memory", false)):
		failures.append("Production RunGenerator revisit did not restore the exact Quarter Falls pile, lockdown, and staff memory.")
	restored.current_environment["scenario_game_modifiers"] = {"coin_pusher": {"reset_pile": true, "reset_token": "someone_else_played_a"}}
	var reset_result := game.resolve_with_context("drop_quarter", 1, restored, restored.current_environment, restored.create_rng("scenario_reset_action"), {"coin_pusher_lane": 2})
	GameModule.apply_result(restored, reset_result, restored.create_rng("scenario_reset_action_apply"))
	var reset_state: Dictionary = (restored.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if not bool(reset_result.get("ok", false)) or int(reset_state.get("action_count", -1)) != 1 \
			or str(reset_state.get("scenario_reset_token", "")) != "someone_else_played_a" \
			or game.deterministic_state_digest(restored.current_environment) == persisted_digest:
		failures.append("Quarter Falls scenario reset token did not replace the persisted pile at the next action boundary.")
	var second_reset_result := game.resolve_with_context("drop_quarter", 1, restored, restored.current_environment, restored.create_rng("scenario_reset_second_action"), {"coin_pusher_lane": 2})
	GameModule.apply_result(restored, second_reset_result, restored.create_rng("scenario_reset_second_action_apply"))
	reset_state = (restored.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if int(reset_state.get("action_count", -1)) != 2 or str(reset_state.get("scenario_reset_token", "")) != "someone_else_played_a":
		failures.append("Quarter Falls scenario reset token reapplied after its first persisted action boundary.")


func _check_coin_pusher_prize_items(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-PRIZE")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["riders"] = [{"id": "fixture_prize", "kind": "scenario_item", "label": "lucky penny", "item_id": "lucky_penny", "cash_value": 0, "lane": 2, "cell": 0, "push": 1}]
	var rider_body := _solver_body("fixture_rider_body", "rider", 50000, 2000, 0, false)
	rider_body["radius"] = CoinPusherSolverScript.OBJECT_RADIUS
	rider_body["height"] = CoinPusherSolverScript.OBJECT_HEIGHT
	rider_body["mass"] = 3
	rider_body["metadata"] = machine["riders"][0].duplicate(true)
	(rider_body["metadata"] as Dictionary)["feature_id"] = "fixture_prize"
	((machine.get("simulation", {}) as Dictionary).get("bodies", []) as Array).append(rider_body)
	var result := game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("prize_push"), {
		"coin_pusher_force": "shove", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 3,
	})
	GameModule.apply_result(run_state, result, run_state.create_rng("prize_apply"))
	if not run_state.inventory.has("lucky_penny") or (result.get("coin_pusher_prizes", []) as Array).is_empty():
		failures.append("Quarter Falls scenario inventory prize did not ride the pile into inventory.")


func _check_coin_pusher_items(game: GameModule, failures: Array) -> void:
	var cold_item := game.library.item("cold_quarters")
	var cold_effect: Dictionary = cold_item.get("effect", {}) if typeof(cold_item.get("effect", {})) == TYPE_DICTIONARY else {}
	if str(cold_effect.get("active_target", "")) != "machine":
		failures.append("Cold Quarters must advertise its shared machine target instead of one cabinet family.")
	var slot_definition := game.library.game("slot")
	var slot_game: GameModule = SlotGameScript.new()
	slot_game.setup(slot_definition, game.library)
	var slot_run: RunState = _slot_run_state("PUSHER-COLD-SHARED-SLOT", 100000)
	var slot_environment: Dictionary = _slot_environment()
	var slot_machine: Dictionary = _slot_machine(slot_definition, slot_run, "buffalo", "line_5x3", "standard", "plain")
	_slot_store_machine(slot_run, slot_environment, slot_machine)
	slot_run.add_item("cold_quarters")
	var slot_command := slot_game.active_item_command("cold_quarters", slot_run, slot_environment, slot_run.create_rng("cold_shared_slot"))
	var slot_result: Dictionary = slot_command.get("result", {}) if typeof(slot_command.get("result", {})) == TYPE_DICTIONARY else {}
	if not bool(slot_command.get("handled", false)) or not bool(slot_result.get("ok", false)):
		failures.append("Cold Quarters shared machine target no longer reached Slot's existing active-item handler.")

	var cold_fixture := _coin_pusher_fixture(game, "PUSHER-COLD-QUARTERS")
	var cold_run: RunState = cold_fixture.get("run_state")
	cold_run.add_item("cold_quarters")
	var authored_density := cold_run.item_effect_total("coin_pusher_drop_density", "coin_pusher")
	var command := game.active_item_command("cold_quarters", cold_run, cold_run.current_environment, cold_run.create_rng("cold_arm"))
	if not bool(command.get("handled", false)):
		failures.append("Cold Quarters could not arm the Quarter Falls dense drop.")
	else:
		GameModule.apply_result(cold_run, command.get("result", {}), cold_run.create_rng("cold_apply"))
		var state: Dictionary = (cold_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
		if not bool(state.get("cold_quarters_armed", false)) or int(state.get("cold_quarters_density_armed", 0)) != authored_density or authored_density != 3 or cold_run.inventory.has("cold_quarters"):
			failures.append("Cold Quarters did not persist one dense armed drop and consume the item.")
		_clear_coin_pusher_lanes(state)
		var safe_seed := _coin_pusher_seed_for_roll(false)
		var cold_drop := game.resolve_with_context("drop_quarter", 1, cold_run, cold_run.current_environment, _configured_rng(safe_seed), {"coin_pusher_lane": 2})
		var after_cold: Dictionary = (cold_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
		var cold_bodies: Array = ((after_cold.get("simulation", {}) as Dictionary).get("bodies", []) as Array)
		var dense_coin_seen := false
		for body_value in cold_bodies:
			if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("kind", "")) == "coin" and int((body_value as Dictionary).get("mass", 1)) == authored_density:
				dense_coin_seen = true
		if not bool(cold_drop.get("ok", false)) or not dense_coin_seen or bool(after_cold.get("cold_quarters_armed", true)):
			failures.append("Cold Quarters did not create one denser physical coin and consume the armed state.")

	var shim_fixture := _coin_pusher_fixture(game, "PUSHER-COIN-SHIM")
	var shim_run: RunState = shim_fixture.get("run_state")
	shim_run.add_item("coin_return_shim")
	var shim_state: Dictionary = (shim_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_clear_coin_pusher_lanes(shim_state)
	var safe_shim_seed := _coin_pusher_seed_for_roll(false)
	var shim_seed_drop := game.resolve_with_context("drop_quarter", 1, shim_run, shim_run.current_environment, _configured_rng(safe_shim_seed), {"coin_pusher_lane": 2})
	GameModule.apply_result(shim_run, shim_seed_drop, shim_run.create_rng("shim_seed_drop_apply"))
	shim_state = (shim_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var authored_uses := shim_run.item_effect_total("coin_pusher_gutter_recovery_uses", "coin_pusher")
	if not bool(shim_seed_drop.get("ok", false)) or bool(shim_seed_drop.get("coin_pusher_shim_recovered", false)) \
			or not bool(shim_state.get("shim_initialized", false)) or int(shim_state.get("shim_uses_remaining", 0)) != authored_uses or authored_uses != 3:
		failures.append("Coin-Return Shim did not seed its authored limited-use recovery state at the next real drop boundary.")
	var gutter_seed := _coin_pusher_seed_for_roll(true)
	var shim_simulation: Dictionary = shim_state.get("simulation", {}) if typeof(shim_state.get("simulation", {})) == TYPE_DICTIONARY else {}
	var shim_bodies: Array = shim_simulation.get("bodies", []) if typeof(shim_simulation.get("bodies", [])) == TYPE_ARRAY else []
	shim_bodies.append(_solver_body("shim_gutter_coin", "coin", 1000, 0, 0, false))
	var shim_drop := game.resolve_with_context("drop_quarter", 1, shim_run, shim_run.current_environment, _configured_rng(gutter_seed), {"coin_pusher_lane": 0})
	GameModule.apply_result(shim_run, shim_drop, shim_run.create_rng("shim_gutter_drop_apply"))
	shim_state = (shim_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	if not bool(shim_drop.get("coin_pusher_shim_recovered", false)) or bool(shim_drop.get("coin_pusher_gutter", true)) or int(shim_state.get("shim_uses_remaining", -1)) != authored_uses - 1:
		failures.append("Coin-Return Shim effect was not consumed by a real edge-gutter drop action.")


func _check_coin_pusher_economy(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var session := _coin_pusher_scripted_session(game, "PUSHER-EV", PUSHER_EV_ACTIONS)
	var cost := maxi(1, int(session.get("cost", 0)))
	var ev := float(session.get("payout", 0)) / float(cost)
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {})
	var band: Array = tuning.get("documented_ev_band", [])
	if band.size() != 2 or ev < float(band[0]) or ev > float(band[1]):
		failures.append("Quarter Falls long-run coin EV %.4f fell outside documented band %s." % [ev, JSON.stringify(band)])


func _check_pusher_variation_data(definition: Dictionary, failures: Array) -> void:
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {})
	var ids: Array = []
	for value in tuning.get("variation_distribution", []):
		if typeof(value) == TYPE_DICTIONARY:
			ids.append(str((value as Dictionary).get("id", "")))
	if JSON.stringify(ids) != JSON.stringify(["quarter_falls", "jackpot_ridge", "vault_drop"]):
		failures.append("Coin Pusher distribution must author all three launch variations in stable order.")
	var variations: Dictionary = tuning.get("variations", {})
	var ridge: Dictionary = variations.get("jackpot_ridge", {})
	var vault: Dictionary = variations.get("vault_drop", {})
	for key in ["schedule_count", "multiplier_values", "multiplier_drop_count", "lock_cycles", "ridge_run_cycles", "alarm_tolerance_bonus", "tolerance_band_size", "force_trim_order", "force_trim_push_delta", "force_trim_tolerance_delta", "documented_ev_band"]:
		if not ridge.has(key):
			failures.append("Jackpot Ridge tuning is missing %s." % key)
	for key in ["progressive_floor", "progressive_growth_per_action", "progressive_crowded_growth_per_action", "reset_cell_count", "reset_odds_floor", "vault_cells", "documented_ev_by_meter"]:
		if not vault.has(key):
			failures.append("Vault Drop tuning is missing %s." % key)
	var total_cells := 0
	var reset_cells := 0
	for value in vault.get("vault_cells", []):
		if typeof(value) == TYPE_DICTIONARY:
			var count := maxi(1, int((value as Dictionary).get("count", 1)))
			total_cells += count
			if str((value as Dictionary).get("kind", "")) == "reset":
				reset_cells += count
	if total_cells != 9 or reset_cells != int(vault.get("reset_cell_count", -1)) or float(vault.get("reset_odds_floor", 0.0)) > float(reset_cells) / float(total_cells) + 0.00001:
		failures.append("Vault Drop RESET odds do not match the documented honest 1-in-9 floor.")


func _check_jackpot_ridge_lifecycle(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var variations: Dictionary = (definition.get("coin_pusher_tuning", {}) as Dictionary).get("variations", {})
	var config: Dictionary = variations.get("jackpot_ridge", {})
	var state := JackpotRidgeVariation.initial_state(config, _configured_rng(173), 5, 6)
	state["pucks"] = [
		{"id": "m2", "kind": "multiplier", "multiplier": 2, "charges": 2},
		{"id": "m3", "kind": "multiplier", "multiplier": 3, "charges": 2},
		{"id": "m5", "kind": "multiplier", "multiplier": 5, "charges": 2},
	]
	var ridge := JackpotRidgeVariation.apply_physical_events(state, [
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "m2"}},
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "m3"}},
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "m5"}},
	], config)
	if not bool(ridge.get("ridge_run_triggered", false)) or int(ridge.get("multiplier_drops", 0)) != 3 or int(state.get("cascade_remaining", 0)) != int(config.get("ridge_run_cycles", -1)):
		failures.append("Jackpot Ridge did not trigger exactly on three multiplier pucks in one shelf cycle with authored duration.")
	if JackpotRidgeVariation.payout_multiplier(state) != 5:
		failures.append("Jackpot Ridge armed multipliers did not expose the strongest truthful multiplier.")
	JackpotRidgeVariation.finish_drop(state)
	JackpotRidgeVariation.finish_drop(state)
	if JackpotRidgeVariation.payout_multiplier(state) != 1:
		failures.append("Jackpot Ridge multiplier charges did not expire after the authored drops.")
	state["pucks"] = [
		{"id": "lock", "kind": "lock", "shelf": "upper"},
		{"id": "dud", "kind": "dud"},
	]
	JackpotRidgeVariation.apply_physical_events(state, [
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "lock"}},
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "dud"}},
	], config)
	if not JackpotRidgeVariation.shelf_locked(state, "upper") or not (state.get("pucks", []) as Array).is_empty():
		failures.append("Jackpot Ridge lock/dud lifecycle did not freeze the shelf and consume both physical outcomes.")
	var two_state := state.duplicate(true)
	two_state["pucks"] = [
		{"id": "two_a", "kind": "multiplier", "multiplier": 2, "charges": 1},
		{"id": "two_b", "kind": "multiplier", "multiplier": 3, "charges": 1},
	]
	var two := JackpotRidgeVariation.apply_physical_events(two_state, [
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "two_a"}},
		{"kind": "puck", "outcome": "tray", "metadata": {"feature_id": "two_b"}},
	], config)
	if bool(two.get("ridge_run_triggered", true)):
		failures.append("Jackpot Ridge cascade triggered below the exact three-puck threshold.")
	var nudge_fixture := _pusher_variation_fixture(game, "RIDGE-PUCK-NUDGE", "jackpot_ridge")
	var nudge_run: RunState = nudge_fixture.get("run_state")
	var nudge_environment: Dictionary = nudge_run.current_environment
	var nudge_machine: Dictionary = (nudge_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_replace_ridge_pucks(nudge_machine, [{"id": "visible_multiplier", "kind": "multiplier", "multiplier": 3, "charges": 2, "spawn_lane": 2, "spawn_depth_slot": 1}])
	var tolerance_before := int(nudge_machine.get("alarm_tolerance_remaining", 0))
	var nudge_result := game.resolve_with_context("nudge_machine", 0, nudge_run, nudge_environment, nudge_run.create_rng("ridge_puck_nudge"), {
		"coin_pusher_lane": 2, "coin_pusher_force": "tap", "coin_pusher_direction": "front",
		"coin_pusher_timing_phase": 3, "coin_pusher_ridge_trim": "balanced",
	})
	if not bool(nudge_result.get("coin_pusher_clean_drop", false)) \
			or int(nudge_result.get("coin_pusher_tolerance_spent", -1)) != 0 \
			or int(nudge_machine.get("alarm_tolerance_remaining", -1)) != tolerance_before:
		failures.append("Jackpot Ridge rejected a clean nudge aimed at a visible feature puck when no base coin was hanging.")
	var policy_fixture := _pusher_variation_fixture(game, "RIDGE-POLICY", "jackpot_ridge")
	var policy_machine: Dictionary = ((policy_fixture.get("environment") as Dictionary).get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_replace_ridge_pucks(policy_machine, [
		{"id": "dud_near", "kind": "dud", "spawn_lane": 1, "spawn_depth_slot": 0},
		{"id": "multiplier_near", "kind": "multiplier", "multiplier": 5, "spawn_lane": 3, "spawn_depth_slot": 1},
	])
	var nudge_decision := _ridge_strategy_decision(policy_machine, 4)
	var drop_decision := _ridge_strategy_decision(policy_machine, 5)
	if str(nudge_decision.get("action_id", "")) != "nudge_machine" \
			or str(nudge_decision.get("target_kind", "")) != "multiplier" \
			or int((nudge_decision.get("ui_state", {}) as Dictionary).get("coin_pusher_lane", -1)) != 3:
		failures.append("Jackpot Ridge strategy did not prioritize its readable multiplier puck for a clean nudge.")
	if str(drop_decision.get("action_id", "")) != "drop_quarter" \
			or int((drop_decision.get("ui_state", {}) as Dictionary).get("coin_pusher_lane", -1)) == 1:
		failures.append("Jackpot Ridge strategy knowingly paid into a dud-jammed lane.")
	_check_ridge_physical_jam_zone(game, failures)


func _check_ridge_physical_jam_zone(game: GameModule, failures: Array) -> void:
	var fixture := _pusher_variation_fixture(game, "RIDGE-JAM-ZONE", "jackpot_ridge")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_replace_ridge_pucks(machine, [{"id": "moving_dud", "kind": "dud", "spawn_lane": 2, "spawn_depth_slot": 4}])
	var jammed_surface := game.surface_state(run_state, environment, {"coin_pusher_lane": 2})
	if not (jammed_surface.get("coin_pusher_jammed_lanes", []) as Array).has(2):
		failures.append("Jackpot Ridge did not derive a jam from a dud body in the rear upper feed zone.")
	for body_value in (machine.get("simulation", {}) as Dictionary).get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("kind", "")) != "puck":
			continue
		var body: Dictionary = body_value
		body["y"] = CoinPusherSolverScript.UPPER_EDGE - CoinPusherSolverScript.OBJECT_RADIUS
		body["z"] = CoinPusherSolverScript.LOWER_FLOOR_Z
	var cleared_surface := game.surface_state(run_state, environment, {"coin_pusher_lane": 2})
	if (cleared_surface.get("coin_pusher_jammed_lanes", []) as Array).has(2):
		failures.append("Jackpot Ridge retained a metadata jam after the same dud body moved out of the physical feed zone.")


func _check_vault_drop_contract(game: GameModule, definition: Dictionary, failures: Array) -> void:
	var variations: Dictionary = (definition.get("coin_pusher_tuning", {}) as Dictionary).get("variations", {})
	var config: Dictionary = variations.get("vault_drop", {})
	var normal_state := TownState.new()
	normal_state.generate(9101)
	normal_state.register_progressive_meter("normal", {"target_node_id": "bar", "initial_value": 160, "floor": 120, "growth_per_action": 2})
	if int(normal_state.progressive_meter("normal").get("value", 0)) != 160:
		failures.append("Vault progressive changed outside an action boundary.")
	normal_state.advance_actions(3)
	if int(normal_state.progressive_meter("normal").get("value", 0)) != 166:
		failures.append("Vault progressive did not grow once per action boundary.")
	var crowded_state := TownState.new()
	crowded_state.generate(9101)
	crowded_state.register_progressive_meter("crowded", {"target_node_id": "gas", "initial_value": 160, "floor": 120, "growth_per_action": 4, "crowded": true})
	crowded_state.advance_actions(3)
	if int(crowded_state.progressive_meter("crowded").get("value", 0)) != 172:
		failures.append("Vault progressive did not grow faster under the crowded fixture.")
	var fixture := _pusher_variation_fixture(game, "VAULT-CONTRACT", "vault_drop")
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var state: Dictionary = machine.get("variation_state", {})
	state["fragments"] = [{"id": "proof_fragment", "lane": 2, "cell": 0, "push": 1}]
	VaultDropVariation.apply_physical_events(state, [{"kind": "fragment", "outcome": "tray", "metadata": {"feature_id": "proof_fragment"}}])
	if int(state.get("banked_fragments", 0)) != 1:
		failures.append("Vault fragment did not bank after crossing the shared pile ledge.")
	run_state.add_item("xray_glasses")
	var cells: Array = state.get("vault_cells", [])
	var reset_index := -1
	for index in range(cells.size()):
		if str((cells[index] as Dictionary).get("kind", "")) == "reset":
			reset_index = index
			break
	var peek_result := game.resolve_with_context("peek_vault_cell", 0, run_state, environment, run_state.create_rng("vault_peek"), {"coin_pusher_vault_cell": reset_index})
	var peek_outcome: Dictionary = peek_result.get("coin_pusher_vault_outcome", {})
	if not bool(peek_result.get("ok", false)) or str((peek_outcome.get("cell", {}) as Dictionary).get("kind", "")) != "reset" or int(state.get("peeked_cell", -1)) != reset_index:
		failures.append("X-Ray Glasses did not reveal exactly one selected truthful Vault cell.")
	state["banked_fragments"] = 2
	var start_result := game.resolve_with_context("start_vault_round", 0, run_state, environment, run_state.create_rng("vault_start"), {})
	var reset_result := game.resolve_with_context("open_vault_cell", 0, run_state, environment, run_state.create_rng("vault_reset"), {"coin_pusher_vault_cell": reset_index})
	if not bool(start_result.get("ok", false)) or not bool(reset_result.get("ok", false)) or int(run_state.progressive_meter(str(state.get("meter_id", ""))).get("value", -1)) != int(config.get("progressive_floor", -2)):
		failures.append("Vault RESET cell did not slam the TownState progressive to its floor.")
	var digest: String = str(game.call("deterministic_state_digest", environment))
	var restored := RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if game.deterministic_state_digest(restored.current_environment) != digest or int(restored.progressive_meter(str(state.get("meter_id", ""))).get("value", -1)) != int(config.get("progressive_floor", -2)):
		failures.append("Vault fragments/cells/progressive did not survive save/load.")
	if run_state.rumor_facts("vault_progressive").is_empty():
		failures.append("Vault progressive did not register its truthful rumor fact class.")


func _check_pusher_variation_distribution(game: GameModule, failures: Array) -> void:
	var reached: Array = []
	for seed_index in range(20):
		var run_state := RunStateScript.new()
		run_state.start_new("PUSHER-DISTRIBUTION-%02d" % seed_index)
		var environment := _coin_pusher_environment("distribution_%02d" % seed_index)
		environment.erase("scenario_game_modifiers")
		var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("variation_distribution"))
		var variation_id := str(machine.get("variation_id", ""))
		if not reached.has(variation_id):
			reached.append(variation_id)
	for required in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
		if not reached.has(required):
			failures.append("20-seed Coin Pusher distribution never reached %s." % required)
	var busy_fixture := _pusher_variation_fixture(game, "PUSHER-BUSY", "vault_drop")
	var busy_run: RunState = busy_fixture.get("run_state")
	busy_run.current_environment["scenario_game_modifiers"] = {"machine_occupancy": "high", "coin_pusher": {"variation_id": "vault_drop"}}
	if not game.legal_actions(busy_run, busy_run.current_environment).is_empty() or bool(game.resolve_with_context("drop_quarter", 1, busy_run, busy_run.current_environment, busy_run.create_rng("busy"), {}).get("ok", true)):
		failures.append("Trucker Convoy machine-busy mutation did not block pusher play.")


func _check_pusher_variation_determinism_and_ev(game: GameModule, definition: Dictionary, failures: Array) -> void:
	for variation_id in ["jackpot_ridge", "vault_drop"]:
		var first := _pusher_variation_session(game, "PUSHER-VARIATION-DETERMINISM", variation_id, 80)
		var second := _pusher_variation_session(game, "PUSHER-VARIATION-DETERMINISM", variation_id, 80)
		if JSON.stringify(first) != JSON.stringify(second):
			failures.append("%s scripted session diverged for identical seed and actions." % variation_id)
	var ridge_session := _pusher_variation_session(game, "RIDGE-EV", "jackpot_ridge", PUSHER_VARIATION_EV_ACTIONS)
	var variations: Dictionary = (definition.get("coin_pusher_tuning", {}) as Dictionary).get("variations", {})
	var ridge_band: Array = (variations.get("jackpot_ridge", {}) as Dictionary).get("documented_ev_band", [])
	var ridge_ev := float(ridge_session.get("payout", 0)) / float(maxi(1, int(ridge_session.get("cost", 0))))
	if ridge_band.size() != 2 or ridge_ev < float(ridge_band[0]) or ridge_ev > float(ridge_band[1]):
		failures.append("Jackpot Ridge long-run EV %.4f fell outside documented band %s." % [ridge_ev, JSON.stringify(ridge_band)])
	var vault_config: Dictionary = variations.get("vault_drop", {})
	var meter_bands: Dictionary = vault_config.get("documented_ev_by_meter", {})
	var base_cash_total := 0
	var cell_count := 0
	var jackpot_count := 0
	for value in vault_config.get("vault_cells", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition_value: Dictionary = value
		var count := maxi(1, int(definition_value.get("count", 1)))
		cell_count += count
		if str(definition_value.get("kind", "")) == "cash":
			base_cash_total += maxi(0, int(definition_value.get("cash", 0))) * count
		elif str(definition_value.get("kind", "")) == "jackpot":
			jackpot_count += count
	var meter_values := [120, 200, 300]
	var meter_keys := ["thin_120", "building_200", "fat_300"]
	for meter_index in range(meter_keys.size()):
		var meter_key := str(meter_keys[meter_index])
		var band: Array = meter_bands.get(meter_key, [])
		var cash_ev := float(base_cash_total + int(meter_values[meter_index]) * jackpot_count) / float(maxi(1, cell_count))
		if band.size() != 2 or cash_ev < float(band[0]) or cash_ev > float(band[1]):
			failures.append("Vault cash EV %.4f at meter %d fell outside documented band %s." % [cash_ev, int(meter_values[meter_index]), JSON.stringify(band)])


func _pusher_variation_session(game: GameModule, seed_text: String, variation_id: String, action_count: int) -> Dictionary:
	var fixture := _pusher_variation_fixture(game, seed_text, variation_id)
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var payout := 0
	var cost := 0
	var outcomes: Array = []
	for index in range(action_count):
		var action_id := "drop_quarter"
		var ui_state: Dictionary = {"coin_pusher_lane": index % 5}
		var target_kind := ""
		if variation_id == "jackpot_ridge":
			var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
			var decision := _ridge_strategy_decision(machine, index)
			action_id = str(decision.get("action_id", "drop_quarter"))
			ui_state = decision.get("ui_state", {}) as Dictionary
			target_kind = str(decision.get("target_kind", ""))
		var result := game.resolve_with_context(action_id, 1 if action_id == "drop_quarter" else 0, run_state, environment, run_state.create_rng("variation_action_%d" % index), ui_state)
		payout += int(result.get("coin_pusher_payout", 0))
		cost += 1 if action_id == "drop_quarter" else 0
		outcomes.append([action_id, target_kind, int(ui_state.get("coin_pusher_lane", -1)), int(result.get("coin_pusher_payout", 0)), game.deterministic_state_digest(environment)])
		GameModule.apply_result(run_state, result, run_state.create_rng("variation_apply_%d" % index))
	return {"payout": payout, "cost": cost, "outcomes": outcomes, "digest": game.deterministic_state_digest(environment)}


func _ridge_strategy_decision(machine: Dictionary, action_index: int) -> Dictionary:
	var target: Dictionary = {}
	var kind_priority := {"multiplier": 0, "lock": 1, "dud": 2}
	var jammed_lanes: Array = []
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	for value in CoinPusherSolverScript.body_views(simulation):
		if typeof(value) != TYPE_DICTIONARY or str((value as Dictionary).get("kind", "")) != "puck":
			continue
		var body: Dictionary = value
		var metadata: Dictionary = body.get("metadata", {}) if typeof(body.get("metadata", {})) == TYPE_DICTIONARY else {}
		var puck := {
			"id": str(metadata.get("feature_id", body.get("id", ""))),
			"kind": str(metadata.get("kind", "dud")),
			"lane": clampi(int(body.get("x", 0)) / (CoinPusherSolverScript.WIDTH / 5), 0, 4),
			"y": int(body.get("y", CoinPusherSolverScript.REAR_EDGE)),
		}
		if str(puck.get("kind", "")) == "dud" and not jammed_lanes.has(int(puck.get("lane", -1))):
			jammed_lanes.append(int(puck.get("lane", -1)))
		if target.is_empty():
			target = puck
			continue
		var puck_priority := int(kind_priority.get(str(puck.get("kind", "dud")), 3))
		var target_priority := int(kind_priority.get(str(target.get("kind", "dud")), 3))
		var puck_key := [puck_priority, int(puck.get("y", CoinPusherSolverScript.REAR_EDGE)), int(puck.get("lane", 99)), str(puck.get("id", ""))]
		var target_key := [target_priority, int(target.get("y", CoinPusherSolverScript.REAR_EDGE)), int(target.get("lane", 99)), str(target.get("id", ""))]
		if _ridge_strategy_key_before(puck_key, target_key):
			target = puck
	if action_index % 5 == 4 and not target.is_empty():
		return {
			"action_id": "nudge_machine",
			"target_kind": str(target.get("kind", "")),
			"ui_state": {
				"coin_pusher_lane": int(target.get("lane", 2)), "coin_pusher_force": "tap",
				"coin_pusher_direction": "front", "coin_pusher_timing_phase": 3,
				"coin_pusher_ridge_trim": "balanced",
			},
		}
	var preferred_lane := int(target.get("lane", action_index % 5)) if str(target.get("kind", "")) == "multiplier" else action_index % 5
	if jammed_lanes.has(preferred_lane):
		for offset in range(5):
			var candidate := posmod(action_index + offset, 5)
			if not jammed_lanes.has(candidate):
				preferred_lane = candidate
				break
	return {"action_id": "drop_quarter", "target_kind": str(target.get("kind", "")), "ui_state": {"coin_pusher_lane": preferred_lane}}


func _replace_ridge_pucks(machine: Dictionary, definitions: Array) -> void:
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var retained_bodies: Array = []
	for value in simulation.get("bodies", []):
		if typeof(value) != TYPE_DICTIONARY or str((value as Dictionary).get("kind", "")) != "puck":
			retained_bodies.append(value)
	simulation["bodies"] = retained_bodies
	var pucks: Array = []
	for value in definitions:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var puck := (value as Dictionary).duplicate(true)
		var lane := clampi(int(puck.get("spawn_lane", 2)), 0, 4)
		var depth_slot := clampi(int(puck.get("spawn_depth_slot", 2)), 0, 5)
		var depth := CoinPusherSolverScript.FRONT_EDGE + 9000 + depth_slot * (CoinPusherSolverScript.REAR_EDGE - CoinPusherSolverScript.FRONT_EDGE - 18000) / 5
		var metadata := puck.duplicate(true)
		metadata.erase("spawn_lane")
		metadata.erase("spawn_depth_slot")
		metadata["mass"] = 4
		var body := CoinPusherSolverScript.add_feature(simulation, "puck", str(puck.get("id", "")), lane, depth, 5, metadata)
		puck["body_id"] = str(body.get("id", ""))
		puck.erase("spawn_lane")
		puck.erase("spawn_depth_slot")
		pucks.append(puck)
	var state: Dictionary = machine.get("variation_state", {}) if typeof(machine.get("variation_state", {})) == TYPE_DICTIONARY else {}
	state["pucks"] = pucks


func _ridge_strategy_key_before(left: Array, right: Array) -> bool:
	for index in range(mini(left.size(), right.size())):
		if left[index] == right[index]:
			continue
		return left[index] < right[index]
	return left.size() < right.size()


func _pusher_variation_fixture(game: GameModule, seed_text: String, variation_id: String, crowd_density: String = "") -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	run_state.town_state.configure_world({"nodes": [{"id": "bar", "label": "Roadside Bar", "kind": "casino", "tier": 1}], "edges": []})
	var environment := _coin_pusher_environment("%s_%s" % [seed_text.to_lower().replace("-", "_"), variation_id])
	environment["scenario_game_modifiers"] = {"coin_pusher": {"variation_id": variation_id}}
	if not crowd_density.is_empty():
		environment["scenario_presentation"] = {"crowd_density": crowd_density}
	var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("coin_pusher_initial"))
	environment["game_states"] = {"coin_pusher": machine}
	game.environment_state_generated(run_state, environment, machine)
	run_state.set_environment(environment)
	return {"run_state": run_state, "environment": run_state.current_environment}


func _coin_pusher_scripted_session(game: GameModule, seed_text: String, action_count: int) -> Dictionary:
	var fixture := _coin_pusher_fixture(game, seed_text)
	var run_state: RunState = fixture.get("run_state")
	var rng := run_state.create_rng("scripted_session")
	var outcomes: Array = []
	var payout := 0
	var cost := 0
	for index in range(action_count):
		var result := game.resolve_with_context("drop_quarter", 1, run_state, run_state.current_environment, rng, {"coin_pusher_lane": index % 5})
		if not bool(result.get("ok", false)):
			break
		payout += int(result.get("coin_pusher_payout", 0))
		cost += 1
		outcomes.append([int(result.get("coin_pusher_payout", 0)), bool(result.get("coin_pusher_gutter", false))])
		GameModule.apply_result(run_state, result, rng)
	return {"digest": game.deterministic_state_digest(run_state.current_environment), "outcomes": outcomes, "actions": outcomes.size(), "payout": payout, "cost": cost}


func _coin_pusher_mixed_scripted_session(game: GameModule, seed_text: String, action_count: int) -> Dictionary:
	var fixture := _coin_pusher_fixture(game, seed_text)
	var run_state: RunState = fixture.get("run_state")
	var replay_drop_cost := game.wager_cost_for_context("drop_quarter", 1, run_state, run_state.current_environment)
	run_state.bankroll = maxi(run_state.bankroll, replay_drop_cost * action_count)
	var rng := run_state.create_rng("mixed_scripted_session")
	var outcomes: Array = []
	var alarm_count := 0
	var nudge_count := 0
	var alarm_reached := false
	for index in range(action_count):
		var result: Dictionary = {}
		var action_id := "drop_quarter"
		if not alarm_reached and index % 2 == 1:
			action_id = "nudge_machine"
			result = game.resolve_with_context(action_id, 0, run_state, run_state.current_environment, rng, {
				"coin_pusher_force": "slam", "coin_pusher_direction": "front", "coin_pusher_lane": index % 5, "coin_pusher_timing_phase": 9,
			})
			nudge_count += 1
		else:
			result = game.resolve_with_context(action_id, 1, run_state, run_state.current_environment, rng, {"coin_pusher_lane": index % 5})
		if not bool(result.get("ok", false)):
			break
		outcomes.append([
			action_id,
			int(result.get("coin_pusher_payout", 0)),
			bool(result.get("coin_pusher_gutter", false)),
			bool(result.get("coin_pusher_clean_drop", false)),
			bool(result.get("coin_pusher_hard_alarm", false)),
			int(result.get("coin_pusher_tolerance_spent", 0)),
			int(result.get("coin_pusher_tell_rung", 0)),
			int(result.get("coin_pusher_force_push", 0)),
			int(result.get("coin_pusher_push_strength", 0)),
		])
		GameModule.apply_result(run_state, result, rng)
		if bool(result.get("coin_pusher_hard_alarm", false)):
			alarm_count += 1
			alarm_reached = true
			run_state.advance_game_clock_minutes(1440)
			game.enter(run_state, run_state.current_environment)
	return {
		"digest": game.deterministic_state_digest(run_state.current_environment),
		"outcomes": outcomes,
		"actions": outcomes.size(),
		"alarm_count": alarm_count,
		"nudge_count": nudge_count,
	}


func _coin_pusher_fixture(game: GameModule, seed_text: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	run_state.town_state.configure_world({
		"nodes": [
			{"id": "bar", "label": "Roadside Bar", "kind": "casino", "tier": 1},
			{"id": "motel", "label": "Pink Motel", "kind": "service", "tier": 1},
		],
		"edges": [{"a": "bar", "b": "motel"}],
	})
	var environment := _coin_pusher_environment("%s_node" % seed_text.to_lower().replace("-", "_"))
	var generated := game.generate_environment_state(run_state, environment, run_state.create_rng("coin_pusher_initial"))
	environment["game_states"] = {"coin_pusher": generated}
	run_state.set_environment(environment)
	return {"run_state": run_state, "environment": run_state.current_environment}


func _coin_pusher_environment(id: String) -> Dictionary:
	return {
		"id": id,
		"archetype_id": "bar",
		"world_node_id": "bar",
		"name": "Roadside Bar",
		"kind": "casino",
		"tier": 1,
		"game_ids": ["coin_pusher", "bar_dice"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "normal"},
		"scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls"}},
		"game_states": {},
	}


func _coin_pusher_adjacent_world_node(world_map: Dictionary, source_id: String) -> String:
	for edge_value in world_map.get("edges", []):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		if a == source_id and not b.is_empty():
			return b
		if b == source_id and not a.is_empty():
			return a
	return ""


func _machine_hanger_fixture(machine: Dictionary, lane: int) -> void:
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var bodies: Array = simulation.get("bodies", []) if typeof(simulation.get("bodies", [])) == TYPE_ARRAY else []
	var center_x := lane * 20000 + 10000
	for index in range(4):
		var body := _solver_body("fixture_hanger_%d" % index, "coin", center_x + (index - 2) * 1200, 8500 + (index % 2) * 500, 0, true)
		bodies.append(body)


func _clear_coin_pusher_lanes(machine: Dictionary) -> void:
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	simulation["bodies"] = []
	machine["riders"] = []


func _coin_pusher_coin_count(machine: Dictionary) -> int:
	var total := 0
	var simulation: Dictionary = machine.get("simulation", {}) if typeof(machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	for body_value in simulation.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("kind", "")) == "coin":
			total += 1
	return total


func _coin_pusher_seed_for_roll(gutter: bool) -> int:
	for seed_value in range(1, 1000):
		var probe := _configured_rng(seed_value)
		var roll := probe.randi_range(1, 100)
		if (gutter and roll <= 24) or (not gutter and roll > 12):
			return seed_value
	return 1


func _coin_pusher_label_position(harness: SurfaceHarness, prefix: String) -> Vector2:
	for record_value in harness.label_records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value
		if not str(record.get("text", "")).begins_with(prefix):
			continue
		var rect_value: Variant = record.get("rect", Rect2())
		if typeof(rect_value) == TYPE_RECT2:
			var rect: Rect2 = rect_value
			return rect.position
	return Vector2.INF


func _coin_pusher_sweep_conditions() -> Dictionary:
	return {
		"schema_version": 1,
		"turn_horizon": 24,
		"weather_states": [{"id": "clear", "dwell_actions": [24, 24], "modifiers": {}}],
		"calendar": {"cycle": [{"id": "midweek", "duration_actions": 24, "modifiers": {}}]},
		"happenings": {
			"count_range": [1, 1],
			"definitions": [{
				"id": "police_sweep",
				"display_name": "Police Sweep",
				"spawn_chance_percent": 100,
				"start_action_range": [0, 0],
				"duration_actions": [8, 8],
				"modifiers": {"town_flags": ["police_sweep"]},
				"sweep": {
					"dwell_actions": [2, 2],
					"swept_window_actions": 3,
					"adjacent_sighting_chance_percent": 100,
				},
			}],
		},
	}


func _coin_pusher_sweep_map() -> Dictionary:
	return {
		"start_node_id": "back_alley",
		"current_node_id": "back_alley",
		"nodes": [
			{"id": "back_alley", "label": "Back Alley", "kind": "street", "tier": 1},
			{"id": "pawn_shop", "label": "Pawn Shop", "kind": "shop", "tier": 1},
			{"id": "bar", "label": "Bar", "kind": "casino", "tier": 1},
		],
		"edges": [
			{"a": "back_alley", "b": "pawn_shop"},
			{"a": "pawn_shop", "b": "bar"},
		],
		"visited_path": ["back_alley"],
	}


func _presentation_snapshot(surface_state: Dictionary) -> Dictionary:
	var value: Variant = surface_state.get("coin_pusher_snapshot", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _presentation_trace(result: Dictionary) -> Array:
	var patch: Variant = result.get("surface_presentation_snapshot_patch", {})
	if typeof(patch) != TYPE_DICTIONARY:
		return []
	var trace: Variant = (patch as Dictionary).get("trace", [])
	return trace if typeof(trace) == TYPE_ARRAY else []


func _presentation_event_for_body(step: Dictionary, kind: String, body_id: String) -> Dictionary:
	for value in step.get("presentation_events", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = value
		if str(event.get("kind", "")) == kind and str(event.get("body_id", "")) == body_id:
			return event
	return {}


func _source_function(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 6)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _source_call_graph_contains(source: String, root_function: String, needle: String) -> bool:
	var pending: Array = [root_function]
	var visited := {}
	var call_pattern := RegEx.new()
	call_pattern.compile("\\b(_[A-Za-z0-9_]+)\\s*\\(")
	while not pending.is_empty():
		var function_name := str(pending.pop_front())
		if bool(visited.get(function_name, false)):
			continue
		visited[function_name] = true
		var function_source := _source_function(source, function_name)
		if function_source.contains(needle):
			return true
		for call_match in call_pattern.search_all(function_source):
			var called_function := call_match.get_string(1)
			if not bool(visited.get(called_function, false)) and not _source_function(source, called_function).is_empty():
				pending.append(called_function)
	return false


func _configured_rng(seed_value: int) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed_value)
	return rng
