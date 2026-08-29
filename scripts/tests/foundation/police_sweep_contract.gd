extends RefCounted

const PoliceSweepModelScript := preload("res://scripts/core/police_sweep_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const TownStateScript := preload("res://scripts/core/town_state.gd")
const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")


static func run(failures: Array) -> void:
	_check_track_and_legibility(failures)
	_check_default_spawn_probability(failures)
	_check_pressure_and_wake(failures)
	_check_encounter_ladder(failures)
	_check_punchline_and_escape(failures)
	_check_foreign_lock_composition(failures)


static func _check_track_and_legibility(failures: Array) -> void:
	var map_data := _map_fixture()
	var happening := {"start_action": 0, "end_action": 24}
	var config := _sweep_config()
	var first := PoliceSweepModelScript.new()
	var twin := PoliceSweepModelScript.new()
	var first_capability := RefCounted.new()
	var twin_capability := RefCounted.new()
	first.bind_host_capability(first_capability)
	twin.bind_host_capability(twin_capability)
	first.reset(7719, config)
	twin.reset(7719, config)
	first.configure_world(map_data, happening, config, 0)
	twin.configure_world(map_data, happening, config, 0)
	if JSON.stringify(first.segments) != JSON.stringify(twin.segments):
		failures.append("Police Sweep track was not deterministic for the same seed and graph.")
	for seed_index in range(64):
		var property_model := PoliceSweepModelScript.new()
		property_model.reset(1000 + seed_index, config)
		property_model.configure_world(map_data, happening, config, 0)
		for segment_value in property_model.segments:
			var node_id := str((segment_value as Dictionary).get("node_id", ""))
			if node_id.begins_with("grand_casino"):
				failures.append("Police Sweep generated a Grand Casino path segment at seed %d." % seed_index)
				return
		for segment_index in range(property_model.segments.size() - 1):
			var source_node := str((property_model.segments[segment_index] as Dictionary).get("node_id", ""))
			var target_node := str((property_model.segments[segment_index + 1] as Dictionary).get("node_id", ""))
			if _fixture_node_tier(source_node, map_data) == 1 and _fixture_node_tier(target_node, map_data) != 2:
				failures.append("Police Sweep did not prefer a tier-2 neighbor after tier 1 at seed %d." % seed_index)
				return
	if bool(first.intel_status({}).get("available", true)) or not first.map_marker().is_empty():
		failures.append("Police Sweep leaked status or a map marker without a sighting/capability.")
	var before_poll := JSON.stringify(first.snapshot())
	var intel := first.intel_status(first_capability, true)
	if intel.is_empty() or not first.map_marker().is_empty() or JSON.stringify(first.snapshot()) != before_poll:
		failures.append("Capability-gated Police Sweep status polling was not strictly read-only.")
		return
	if bool(first.report_intel_at_boundary({}).get("available", true)) or not first.map_marker().is_empty():
		failures.append("Police Sweep accepted an intel report boundary without capability.")
		return
	var reported_marker := first.report_intel_at_boundary(first_capability, true)
	if reported_marker.is_empty() or str(reported_marker.get("source", "")) != "crew_intel":
		failures.append("Capability-gated Police Sweep boundary report did not record a marker.")
		return
	var reported_node := str(reported_marker.get("node_id", ""))
	first.advance_to(3)
	var stale_marker := first.map_marker(first_capability, true)
	if str(stale_marker.get("node_id", "")) != reported_node or int(stale_marker.get("stale_actions", 0)) != 3 or bool(stale_marker.get("live", true)):
		failures.append("Police Sweep intel marker tracked live instead of preserving a stale reported node.")
	var restored := PoliceSweepModelScript.new()
	var restored_capability := RefCounted.new()
	restored.bind_host_capability(restored_capability)
	if not restored.restore(first.snapshot(), 7719, config):
		failures.append("Police Sweep mid-track snapshot did not restore.")
		return
	restored.configure_world(map_data, happening, config, 3)
	if JSON.stringify(restored.status()) != JSON.stringify(first.status()) or JSON.stringify(restored.map_marker(restored_capability, true)) != JSON.stringify(first.map_marker(first_capability, true)):
		failures.append("Police Sweep save/load did not preserve track and marker staleness.")
	var canvas := WorldMapCanvasScript.new()
	canvas.size = Vector2(640.0, 360.0)
	var canvas_snapshot := map_data.duplicate(true)
	canvas_snapshot["visible_node_ids"] = ["back_alley", "pawn_shop", "bar", "small_underground_casino"]
	canvas_snapshot["sweep_marker"] = stale_marker
	canvas.set_map_snapshot(canvas_snapshot)
	var rendered_marker := _dictionary(canvas.current_view_snapshot().get("sweep_marker", {}))
	if str(rendered_marker.get("node_id", "")) != reported_node or not rendered_marker.has("screen_center") or bool(rendered_marker.get("live", true)):
		failures.append("Production world-map canvas did not render the stale Police Sweep marker.")
	canvas.free()


static func _check_default_spawn_probability(failures: Array) -> void:
	var saw_spawn := false
	var saw_sweep_free := false
	for seed_value in range(1, 129):
		var town := TownStateScript.new()
		town.generate(seed_value, TownStateScript.conditions())
		var spawned := false
		for happening_value in town.happenings:
			if str((happening_value as Dictionary).get("id", "")) == "police_sweep":
				spawned = true
				break
		saw_spawn = saw_spawn or spawned
		saw_sweep_free = saw_sweep_free or not spawned
		if saw_spawn and saw_sweep_free:
			break
	if not saw_spawn or not saw_sweep_free:
		failures.append("Default Police Sweep tuning did not produce both spawned and sweep-free deterministic seeds.")


static func _check_pressure_and_wake(failures: Array) -> void:
	var conditions := _town_conditions_fixture()
	var town := TownStateScript.new()
	town.generate(4021, conditions)
	var map_data := _map_fixture()
	town.configure_world(map_data)
	var status := town.sweep_internal_status()
	if status.is_empty():
		failures.append("Guaranteed Police Sweep fixture did not spawn a track.")
		return
	var hidden_public := town.public_snapshot()
	var hidden_public_text := JSON.stringify(hidden_public)
	if _copy_array(hidden_public.get("active_happenings", [])).has("police_sweep") \
		or _copy_array(hidden_public.get("active_town_flags", [])).has("police_sweep") \
		or hidden_public_text.contains(str(status.get("current_node_id", ""))) \
		or (not str(status.get("heading_node_id", "")).is_empty() and hidden_public_text.contains(str(status.get("heading_node_id", "")))):
		failures.append("Active Police Sweep leaked its internal ID, flag, current node, or heading through the public town snapshot.")
	if town.active_happenings().has("police_sweep") or town.happening_active("police_sweep") or town.town_flag_active("police_sweep"):
		failures.append("Active Police Sweep leaked through player-facing town status accessors.")
	var current_node := str(status.get("current_node_id", ""))
	var adjacent_node := _first_adjacent_node(current_node, map_data)
	if adjacent_node.is_empty():
		failures.append("Police Sweep fixture did not expose an adjacent scenario-pressure node.")
		return
	var pressured_id := "back_alley_cruiser_parked" if adjacent_node == "back_alley" else "pawn_shop_serial_check_day"
	var pressure := town.scenario_weight_multiplier(adjacent_node, pressured_id, ["law:pressure"])
	if pressure <= 1.0 or town.scenario_weight_multiplier("grand_casino", pressured_id, ["law:pressure"]) != 1.0:
		failures.append("Police Sweep adjacency pressure did not shift generically while keeping Grand Casino inert.")
	var first_end := int((town.police_sweep.segments[0] as Dictionary).get("end_action", 2))
	var departed_node := str((town.police_sweep.segments[0] as Dictionary).get("node_id", ""))
	town.advance_actions(first_end)
	var moved_status := town.sweep_internal_status()
	var recent_fact := town.rumor_fact("sweep:recent")
	var recent_payload := _dictionary(recent_fact.get("payload", {}))
	var expected_recent := str(moved_status.get("previous_node_id", moved_status.get("current_node_id", "")))
	if str(recent_fact.get("target_node_id", "")) != expected_recent \
		or str(recent_payload.get("truth_node_id", "")) != str(moved_status.get("current_node_id", "")) \
		or int(recent_payload.get("track_segment_index", -1)) != int(moved_status.get("segment_index", -2)):
		failures.append("Police Sweep recent rumor did not match the actual departed node and live track segment.")
	var expected_heading := str(moved_status.get("heading_node_id", ""))
	if not expected_heading.is_empty():
		var heading_fact := town.rumor_fact("sweep:heading")
		var heading_payload := _dictionary(heading_fact.get("payload", {}))
		if str(heading_fact.get("target_node_id", "")) != expected_heading \
			or str(heading_payload.get("truth_node_id", "")) != str(moved_status.get("current_node_id", "")) \
			or int(heading_payload.get("track_segment_index", -1)) != int(moved_status.get("segment_index", -2)):
			failures.append("Police Sweep heading rumor did not match the actual next track node.")
	var window := town.swept_window(departed_node)
	if int(window.get("security_strictness_band_delta", 0)) != -1 or not bool(window.get("cheat_window_open", false)) or int(window.get("pusher_alarm_tolerance_band_delta", 0)) != 1:
		failures.append("Police Sweep wake did not publish all three security override effects.")
	var wake_run := RunStateScript.new()
	wake_run.start_new("SWEEP-WAKE")
	wake_run.town_state = town
	var environment := {
		"id": departed_node,
		"world_node_id": departed_node,
		"archetype_id": departed_node,
		"security_profile": {
			"strictness_band": "high",
			"cheat_risk_window": "narrow",
			"machine_alarm_tolerance_band": "normal",
		},
	}
	wake_run.apply_town_living_world_context(environment)
	var loosened := _dictionary(environment.get("security_profile", {}))
	if str(loosened.get("strictness_band", "")) != "tight" or str(loosened.get("cheat_risk_window", "")) != "open" or str(loosened.get("machine_alarm_tolerance_band", "")) != "lax":
		failures.append("Police Sweep wake did not measurably loosen production security fields.")
	town.advance_actions(int(window.get("remaining_actions", 0)))
	wake_run.apply_town_living_world_context(environment)
	var restored := _dictionary(environment.get("security_profile", {}))
	if str(restored.get("strictness_band", "")) != "high" or str(restored.get("cheat_risk_window", "")) != "narrow" or str(restored.get("machine_alarm_tolerance_band", "")) != "normal":
		failures.append("Police Sweep wake did not restore security after expiry.")
	town.advance_actions(24)
	if town.scenario_weight_multiplier(adjacent_node, pressured_id, ["law:pressure"]) != 1.0:
		failures.append("Police Sweep scenario pressure did not restore after the track expired.")


static func _check_encounter_ladder(failures: Array) -> void:
	var pass_result := _encounter_fixture(0, [], [])
	var shakedown_result := _encounter_fixture(30, [], [])
	var confiscation_result := _encounter_fixture(50, ["marked_cards"], [])
	var empty_confiscation_result := _encounter_fixture(80, [], [], "back_alley", 1)
	var lock_result := _encounter_fixture(80, ["marked_cards"], [{"id": "street_note", "debt_kind": "cash", "status": "active", "balance": 20}])
	var outcomes := [
		str(pass_result.get("outcome", "")),
		str(shakedown_result.get("outcome", "")),
		str(confiscation_result.get("outcome", "")),
		str(lock_result.get("outcome", "")),
	]
	if outcomes != ["pass_over", "shakedown", "confiscation", "travel_lock"]:
		failures.append("Police Sweep encounter ladder did not scale across heat/contraband/debt fixtures: %s." % str(outcomes))
	if str(empty_confiscation_result.get("outcome", "")) != "confiscation" or str(empty_confiscation_result.get("cost_kind", "")) != "travel_delay":
		failures.append("Empty Police Sweep confiscation did not use its deterministic nonterminal fallback cost.")
	for result in [pass_result, shakedown_result, confiscation_result, empty_confiscation_result, lock_result]:
		if not bool(result.get("run_continues", false)):
			failures.append("Police Sweep encounter exposed a run-kill outcome.")
		if str(result.get("cost_kind", "")).is_empty() or int(result.get("cost_amount", 0)) <= 0:
			failures.append("Police Sweep encounter outcome was not a costed continue: %s." % str(result.get("outcome", "")))


static func _check_punchline_and_escape(failures: Array) -> void:
	var low := _encounter_fixture(20, ["marked_cards"], [], "small_underground_casino")
	var high := _encounter_fixture(90, ["marked_cards"], [], "small_underground_casino")
	if str(low.get("outcome", "")) != "pass_over" or int(low.get("punchline_layer", 0)) != 1:
		failures.append("Low-heat Punchline sweep did not pass at layer 1.")
	if str(high.get("outcome", "")) != "punchline_l2_near_miss" or int(high.get("punchline_layer", 0)) != 2:
		failures.append("Extreme-heat Punchline sweep did not fire the layer-2 near miss.")
	if int(low.get("cost_amount", 0)) <= 0 or int(high.get("cost_amount", 0)) <= 0:
		failures.append("Punchline sweep outcomes were not costed continues.")
	var escape_run := RunStateScript.new()
	escape_run.start_new("SWEEP-ESCAPE")
	escape_run.current_environment = {
		"id": "back_alley",
		"world_node_id": "back_alley",
		"archetype_id": "back_alley",
		"turns": 0,
		"travel_locked_actions": 0,
		"travel_lock_remaining": 0,
	}
	escape_run.suspicion = {"level": 90, "local_levels": {"back_alley": 90}, "cues": []}
	escape_run.inventory = ["marked_cards"]
	var result := _arm_and_resolve(escape_run, "back_alley", 3)
	var lock_actions := int(result.get("travel_lock_actions", 0))
	if lock_actions <= 0 or lock_actions > 3:
		failures.append("Police Sweep travel lock outlasted the patrol's deterministic departure.")
		return
	var wait_status := escape_run.sweep_wait_action_status()
	if not bool(wait_status.get("visible", false)) or str(wait_status.get("label", "")) != "Wait out the sweep":
		failures.append("Police Sweep lock did not expose the production wait/continue action.")
		return
	var waits_used := 0
	while escape_run.current_travel_lock_remaining() > 0 and waits_used < 4:
		var waited := escape_run.perform_sweep_wait_action()
		if not bool(waited.get("ok", false)) or int(waited.get("actions_advanced", 0)) != 1:
			failures.append("Police Sweep production wait action failed before travel reopened.")
			return
		waits_used += 1
	if escape_run.current_travel_lock_remaining() != 0 or escape_run.is_terminal():
		failures.append("Police Sweep worst-case lock did not leave a legal continue through the player-facing wait action.")
	if waits_used != lock_actions or bool(escape_run.sweep_wait_action_status().get("visible", false)):
		failures.append("Police Sweep wait action did not retire exactly when the bounded lock expired.")


static func _check_foreign_lock_composition(failures: Array) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("SWEEP-ENGINE-TROUBLE")
	run_state.current_environment = {
		"id": "back_alley",
		"world_node_id": "back_alley",
		"archetype_id": "back_alley",
		"turns": 0,
		"travel_locked_actions": 3,
		"travel_lock_remaining": 3,
		"travel_lock_source": "engine_trouble",
		"engine_trouble_progress": 1,
	}
	run_state.suspicion = {"level": 90, "local_levels": {"back_alley": 90}, "cues": []}
	run_state.bankroll = 1
	var debt_before := run_state.debt.size()
	var result := _arm_and_resolve(run_state, "back_alley", 4)
	if int(run_state.current_environment.get("travel_lock_remaining", 0)) != 3 \
		or str(run_state.current_environment.get("travel_lock_source", "")) != "engine_trouble" \
		or int(run_state.current_environment.get("engine_trouble_progress", 0)) != 1:
		failures.append("Police Sweep overwrote or advanced an existing Engine Trouble lock channel.")
	if not bool(result.get("foreign_lock_preserved", false)) \
		or str(result.get("cost_kind", "")) != "street_debt" \
		or int(result.get("cost_amount", 0)) <= 0 \
		or run_state.debt.size() != debt_before + 1:
		failures.append("Police Sweep did not fall back to its data-tuned cost while preserving a foreign lock.")
	if bool(run_state.sweep_wait_action_status().get("visible", false)) or bool(run_state.perform_sweep_wait_action().get("ok", true)):
		failures.append("Police Sweep wait action exposed a bypass for an Engine Trouble-owned lock.")


static func _encounter_fixture(heat: int, items: Array, debts: Array, node_id: String = "back_alley", bankroll: int = 80) -> Dictionary:
	var run_state := RunStateScript.new()
	run_state.start_new("SWEEP-ENCOUNTER-%s-%d-%d-%d" % [node_id, heat, items.size(), debts.size()])
	run_state.current_environment = {
		"id": node_id,
		"world_node_id": node_id,
		"archetype_id": node_id,
		"turns": 0,
		"travel_locked_actions": 0,
		"travel_lock_remaining": 0,
	}
	run_state.suspicion = {"level": heat, "local_levels": {node_id: heat}, "cues": []}
	run_state.inventory = items.duplicate(true)
	run_state.debt = debts.duplicate(true)
	run_state.bankroll = bankroll
	return _arm_and_resolve(run_state, node_id, 4)


static func _arm_and_resolve(run_state, node_id: String, departure_actions: int) -> Dictionary:
	var sweep = run_state.town_state.police_sweep
	sweep.disabled = false
	sweep.configured = true
	sweep.start_action = int(run_state.town_state.action_index)
	sweep.end_action = sweep.start_action + maxi(1, departure_actions)
	sweep.segments = [{"node_id": node_id, "start_action": sweep.start_action, "end_action": sweep.end_action, "dwell_actions": maxi(1, departure_actions)}]
	sweep.segment_index = 0
	sweep.last_encounter_segment = -1
	sweep.last_encounter_node_id = ""
	return run_state.resolve_current_police_sweep_encounter()


static func _town_conditions_fixture() -> Dictionary:
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
				"sweep": _sweep_config(),
			}],
		},
	}


static func _sweep_config() -> Dictionary:
	return {
		"dwell_actions": [2, 2],
		"swept_window_actions": 3,
		"adjacent_sighting_chance_percent": 100,
		"adjacent_scenario_pressure": {
			"scenario_weight_by_id": {
				"back_alley_cruiser_parked": 2.8,
				"pawn_shop_serial_check_day": 2.8,
			},
			"scenario_weight_by_tag": {"law:pressure": 1.65},
		},
		"encounter": {
			"heat_bands": [
				{"max": 24, "points": 0},
				{"max": 49, "points": 2},
				{"max": 74, "points": 4},
				{"max": 100, "points": 6},
			],
			"contraband_points_each": 2,
			"street_debt_points_each": 1,
			"pass_over_max_score": 1,
			"shakedown_max_score": 4,
			"confiscation_max_score": 7,
			"pass_over_fee": [2, 6],
			"pass_over_fallback_lock_actions": 1,
			"shakedown_fee": [10, 28],
			"shakedown_fallback_lock_actions": 1,
			"empty_confiscation_fee": [8, 16],
			"empty_confiscation_fallback_lock_actions": 2,
			"travel_lock_actions": [2, 4],
			"occupied_lock_fine": [6, 12],
			"punchline_l2_heat_threshold": 75,
			"punchline_near_miss_lock_actions": 2,
		},
	}


static func _map_fixture() -> Dictionary:
	return {
		"start_node_id": "back_alley",
		"current_node_id": "back_alley",
		"nodes": [
			{"id": "back_alley", "label": "Back Alley", "kind": "street", "tier": 1, "position": {"x": 0.12, "y": 0.52}},
			{"id": "pawn_shop", "label": "Pawn Shop", "kind": "shop", "tier": 2, "position": {"x": 0.36, "y": 0.32}},
			{"id": "bar", "label": "Bar", "kind": "casino", "tier": 1, "position": {"x": 0.58, "y": 0.55}},
			{"id": "small_underground_casino", "label": "The Punchline", "kind": "casino", "tier": 2, "position": {"x": 0.78, "y": 0.35}},
			{"id": "grand_casino", "label": "Grand Casino", "kind": "boss", "tier": 3, "position": {"x": 0.92, "y": 0.52}},
		],
		"edges": [
			{"a": "back_alley", "b": "pawn_shop"},
			{"a": "pawn_shop", "b": "bar"},
			{"a": "bar", "b": "small_underground_casino"},
			{"a": "small_underground_casino", "b": "grand_casino"},
		],
		"visited_path": ["back_alley"],
	}


static func _first_adjacent_node(node_id: String, map_data: Dictionary) -> String:
	for edge_value in map_data.get("edges", []):
		var edge: Dictionary = edge_value
		if str(edge.get("a", "")) == node_id and not str(edge.get("b", "")).begins_with("grand_casino"):
			return str(edge.get("b", ""))
		if str(edge.get("b", "")) == node_id and not str(edge.get("a", "")).begins_with("grand_casino"):
			return str(edge.get("a", ""))
	return ""


static func _fixture_node_tier(node_id: String, map_data: Dictionary) -> int:
	for node_value in map_data.get("nodes", []):
		if str((node_value as Dictionary).get("id", "")) == node_id:
			return int((node_value as Dictionary).get("tier", 0))
	return 0


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
