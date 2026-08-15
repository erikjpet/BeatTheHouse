extends SceneTree

const PUSHER_DETERMINISM_ACTIONS := 200
const PUSHER_EV_ACTIONS := 2400
const PUSHER_VARIATION_EV_ACTIONS := 600


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
	_check_coin_pusher_surface_liveness(game, failures)
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
	_check_jackpot_ridge_lifecycle(definition, failures)
	_check_vault_drop_contract(game, definition, failures)
	_check_pusher_variation_distribution(game, failures)
	_check_pusher_variation_determinism_and_ev(game, definition, failures)


func _check_coin_pusher_data_contract(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
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
		"security_band_deltas", "tell_labels", "lane_count", "cell_count", "cell_capacity", "upper_phase_step", "lower_phase_step",
		"clean_nudge_phase", "clean_nudge_window_steps", "forward_phase_window_steps", "nudge_forces", "shelf_push_percent",
		"nudge_push_percent", "forward_push_bonus_percent", "retracted_push_penalty_percent", "mistimed_push_penalty",
		"max_settle_passes", "retracted_stack_threshold_bonus", "strong_push_threshold", "strong_push_extra_coins",
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
	if str(surface.get("coin_pusher_tell", "")) != "authored chirp":
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
	var stream: AudioStreamWAV = sfx.render_event_master_stream("alarm_chirp")
	if sfx.debug_normalized_event_id("alarm_chirp") != "heat_gain" or stream == null or stream.data.is_empty():
		failures.append("Quarter Falls alarm_chirp is not registered to the authored non-generic radio-chirp SFX bank.")
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


func _check_coin_pusher_surface_liveness(game: GameModule, failures: Array) -> void:
	var fixture := _coin_pusher_fixture(game, "PUSHER-LIVENESS")
	var run_state: RunState = fixture.get("run_state")
	var machine: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	machine["riders"] = [{"id": "visible_rider", "kind": "chip_stack", "label": "chip stack", "item_id": "", "cash_value": 4, "lane": 1, "cell": 2, "push": 1}]
	var surface := game.surface_state(run_state, run_state.current_environment, {"surface_time_msec": 1000})
	if str(surface.get("surface_renderer", "")) != "coin_pusher" or not bool(surface.get("surface_controls_native", false)):
		failures.append("Quarter Falls did not expose its native machine surface.")
	if bool(surface.get("surface_realtime_state_refresh", false)):
		failures.append("Quarter Falls must not rebuild its pile snapshot per frame.")
	_check_idle_animation_liveness_contract(surface, "Quarter Falls attract surface", failures)
	_check_surface_visual_motion_advances(game, surface, "Quarter Falls attract surface", failures)
	var approaches: Array = []
	for lane_value in surface.get("coin_pusher_lanes", []):
		if typeof(lane_value) == TYPE_DICTIONARY:
			approaches.append(int((lane_value as Dictionary).get("approach", 99)))
	if JSON.stringify(approaches) != JSON.stringify([-2, -1, 0, 1, 2]):
		failures.append("Quarter Falls surface did not expose five distinct lane approach identities.")
	if (surface.get("coin_pusher_riders", []) as Array).size() != 1:
		failures.append("Quarter Falls surface did not expose the prize rider ON its pile.")
	var digest_before_render: String = game.deterministic_state_digest(run_state.current_environment)
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
			or (state_after.get("coin_pusher_cells", []) as Array).size() != (state_before.get("coin_pusher_cells", []) as Array).size() \
			or (state_after.get("coin_pusher_riders", []) as Array).size() != (state_before.get("coin_pusher_riders", []) as Array).size() \
			or int(state_after.get("coin_pusher_tell_rung", -1)) != int(state_before.get("coin_pusher_tell_rung", -2)):
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
		failures.append("A clean Quarter Falls nudge did not evolve the coarse pile.")
	machine = (environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	_machine_hanger_fixture(machine, 2)
	machine["base_alarm_tolerance"] = 3
	machine["tolerance_modifier"] = 0
	machine["alarm_tolerance_remaining"] = 3
	machine["tell_rung"] = 0
	var tell_rungs: Array = []
	var alarm_result: Dictionary = {}
	for nudge_index in range(4):
		alarm_result = game.resolve_with_context("nudge_machine", 0, run_state, environment, run_state.create_rng("bad_nudge_%d" % nudge_index), {
			"coin_pusher_force": "tap", "coin_pusher_direction": "front", "coin_pusher_lane": 2, "coin_pusher_timing_phase": 9,
		})
		if nudge_index < 3:
			tell_rungs.append(int(alarm_result.get("coin_pusher_tell_rung", -1)))
		GameModule.apply_result(run_state, alarm_result, run_state.create_rng("bad_nudge_apply_%d" % nudge_index))
	if JSON.stringify(tell_rungs) != JSON.stringify([1, 2, 3]):
		failures.append("Quarter Falls tell ladder did not fire rock, chirp, attendant glance in order: %s." % JSON.stringify(tell_rungs))
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
		if not bool(cold_drop.get("ok", false)) or _coin_pusher_coin_count(after_cold) != authored_density or bool(after_cold.get("cold_quarters_armed", true)):
			failures.append("Cold Quarters density was not consumed by the next real pusher drop action.")

	var shim_fixture := _coin_pusher_fixture(game, "PUSHER-COIN-SHIM")
	var shim_run: RunState = shim_fixture.get("run_state")
	shim_run.add_item("coin_return_shim")
	var safe_shim_seed := _coin_pusher_seed_for_roll(false)
	var shim_seed_drop := game.resolve_with_context("drop_quarter", 1, shim_run, shim_run.current_environment, _configured_rng(safe_shim_seed), {"coin_pusher_lane": 2})
	GameModule.apply_result(shim_run, shim_seed_drop, shim_run.create_rng("shim_seed_drop_apply"))
	var shim_state: Dictionary = (shim_run.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var authored_uses := shim_run.item_effect_total("coin_pusher_gutter_recovery_uses", "coin_pusher")
	if not bool(shim_seed_drop.get("ok", false)) or bool(shim_seed_drop.get("coin_pusher_shim_recovered", false)) \
			or not bool(shim_state.get("shim_initialized", false)) or int(shim_state.get("shim_uses_remaining", 0)) != authored_uses or authored_uses != 3:
		failures.append("Coin-Return Shim did not seed its authored limited-use recovery state at the next real drop boundary.")
	var gutter_seed := _coin_pusher_seed_for_roll(true)
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
	for key in ["fragment_push_threshold", "progressive_floor", "progressive_growth_per_action", "progressive_crowded_growth_per_action", "reset_cell_count", "reset_odds_floor", "vault_cells", "documented_ev_by_meter"]:
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


func _check_jackpot_ridge_lifecycle(definition: Dictionary, failures: Array) -> void:
	var variations: Dictionary = (definition.get("coin_pusher_tuning", {}) as Dictionary).get("variations", {})
	var config: Dictionary = variations.get("jackpot_ridge", {})
	var state := JackpotRidgeVariation.initial_state(config, _configured_rng(173), 5, 6)
	state["pucks"] = [
		{"id": "m2", "kind": "multiplier", "multiplier": 2, "charges": 2, "lane": 2, "cell": 0, "push": 1},
		{"id": "m3", "kind": "multiplier", "multiplier": 3, "charges": 2, "lane": 2, "cell": 0, "push": 1},
		{"id": "m5", "kind": "multiplier", "multiplier": 5, "charges": 2, "lane": 2, "cell": 0, "push": 1},
	]
	var ridge := JackpotRidgeVariation.apply_movement(state, [{"lane": 2, "cell": 0, "moved": 1}], {"aimed_lane": 2, "push_strength": 0, "from_nudge": false}, config)
	if not bool(ridge.get("ridge_run_triggered", false)) or int(ridge.get("multiplier_drops", 0)) != 3 or int(state.get("cascade_remaining", 0)) != int(config.get("ridge_run_cycles", -1)):
		failures.append("Jackpot Ridge did not trigger exactly on three multiplier pucks in one shelf cycle with authored duration.")
	if JackpotRidgeVariation.payout_multiplier(state) != 5:
		failures.append("Jackpot Ridge armed multipliers did not expose the strongest truthful multiplier.")
	JackpotRidgeVariation.finish_drop(state)
	JackpotRidgeVariation.finish_drop(state)
	if JackpotRidgeVariation.payout_multiplier(state) != 1:
		failures.append("Jackpot Ridge multiplier charges did not expire after the authored drops.")
	state["pucks"] = [
		{"id": "lock", "kind": "lock", "shelf": "upper", "lane": 1, "cell": 0, "push": 1},
		{"id": "dud", "kind": "dud", "lane": 3, "cell": 0, "push": 1},
	]
	state["jammed_lanes"] = [3]
	JackpotRidgeVariation.apply_movement(state, [{"lane": 1, "cell": 0, "moved": 1}, {"lane": 3, "cell": 0, "moved": 1}], {"aimed_lane": 2, "push_strength": 0, "from_nudge": false}, config)
	if not JackpotRidgeVariation.shelf_locked(state, "upper") or JackpotRidgeVariation.lane_is_jammed(state, 3):
		failures.append("Jackpot Ridge lock/dud lifecycle did not freeze the shelf and clear the jam.")
	var two_state := state.duplicate(true)
	two_state["pucks"] = [
		{"kind": "multiplier", "multiplier": 2, "charges": 1, "lane": 0, "cell": 0, "push": 1},
		{"kind": "multiplier", "multiplier": 3, "charges": 1, "lane": 0, "cell": 0, "push": 1},
	]
	var two := JackpotRidgeVariation.apply_movement(two_state, [{"lane": 0, "cell": 0, "moved": 1}], {"aimed_lane": 0, "push_strength": 0, "from_nudge": false}, config)
	if bool(two.get("ridge_run_triggered", true)):
		failures.append("Jackpot Ridge cascade triggered below the exact three-puck threshold.")


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
	VaultDropVariation.apply_movement(state, [{"lane": 2, "cell": 0, "moved": 1}], {"aimed_lane": 2, "push_strength": 0, "from_nudge": false}, config)
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
	var meter_bands: Dictionary = (variations.get("vault_drop", {}) as Dictionary).get("documented_ev_by_meter", {})
	for meter_key in ["thin_120", "building_200", "fat_300"]:
		var band: Array = meter_bands.get(meter_key, [])
		if band.size() != 2 or float(band[0]) > float(band[1]):
			failures.append("Vault meter-dependent EV band %s is missing or inverted." % meter_key)


func _pusher_variation_session(game: GameModule, seed_text: String, variation_id: String, action_count: int) -> Dictionary:
	var fixture := _pusher_variation_fixture(game, seed_text, variation_id)
	var run_state: RunState = fixture.get("run_state")
	var environment: Dictionary = run_state.current_environment
	var payout := 0
	var outcomes: Array = []
	for index in range(action_count):
		var result := game.resolve_with_context("drop_quarter", 1, run_state, environment, run_state.create_rng("variation_drop_%d" % index), {"coin_pusher_lane": index % 5})
		payout += int(result.get("coin_pusher_payout", 0))
		outcomes.append([int(result.get("coin_pusher_payout", 0)), game.deterministic_state_digest(environment)])
		GameModule.apply_result(run_state, result, run_state.create_rng("variation_apply_%d" % index))
	return {"payout": payout, "cost": action_count, "outcomes": outcomes, "digest": game.deterministic_state_digest(environment)}


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
	var lanes: Array = machine.get("lanes", [])
	if lane < 0 or lane >= lanes.size():
		return
	var lane_data: Dictionary = lanes[lane]
	var cells: Array = lane_data.get("cells", [])
	if cells.is_empty():
		return
	var front: Dictionary = cells[0]
	front["height"] = 10
	front["edge_hang"] = true
	cells[0] = front
	lane_data["cells"] = cells
	lanes[lane] = lane_data
	machine["lanes"] = lanes


func _clear_coin_pusher_lanes(machine: Dictionary) -> void:
	var lanes: Array = machine.get("lanes", []) if typeof(machine.get("lanes", [])) == TYPE_ARRAY else []
	for lane_index in range(lanes.size()):
		if typeof(lanes[lane_index]) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lanes[lane_index]
		var cells: Array = lane.get("cells", []) if typeof(lane.get("cells", [])) == TYPE_ARRAY else []
		for cell_index in range(cells.size()):
			cells[cell_index] = {"height": 0, "edge_hang": false}
		lane["cells"] = cells
		lanes[lane_index] = lane
	machine["lanes"] = lanes
	machine["riders"] = []


func _coin_pusher_coin_count(machine: Dictionary) -> int:
	var total := 0
	for lane_value in machine.get("lanes", []):
		if typeof(lane_value) != TYPE_DICTIONARY:
			continue
		for cell_value in (lane_value as Dictionary).get("cells", []):
			if typeof(cell_value) == TYPE_DICTIONARY:
				total += int((cell_value as Dictionary).get("height", 0))
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


func _configured_rng(seed_value: int) -> RngStream:
	var rng := RngStream.new()
	rng.configure(seed_value)
	return rng
