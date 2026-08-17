extends Node

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const CoinPusherGameScript := preload("res://scripts/games/coin_pusher.gd")
const CoinPusherSolverScript := preload("res://scripts/games/coin_pusher/coin_pusher_solver.gd")
const INPUT_PATH := "res://scripts/games/coin_pusher/coin_pusher_export_parity_input.json"
const RESULT_MARKER := "COIN_PUSHER_EXPORT_PARITY_RESULT="


func _ready() -> void:
	call_deferred("_run_parity")


func _run_parity() -> void:
	var input_text := FileAccess.get_file_as_string(INPUT_PATH)
	var input_value: Variant = JSON.parse_string(input_text)
	if typeof(input_value) != TYPE_DICTIONARY:
		_publish({"ok": false, "error": "input_parse_failed"})
		return
	var input: Dictionary = input_value
	var library := ContentLibraryScript.new()
	library.load()
	var game := CoinPusherGameScript.new()
	game.setup(library.game("coin_pusher"), library)
	var run_state := RunStateScript.new()
	run_state.start_new(str(input.get("seed", "REWORK06-2-CROSS-EXPORT")))
	run_state.bankroll = 100000
	var environment := {
		"id": "cross_export_coin_pusher", "archetype_id": "bar", "world_node_id": "bar",
		"name": "Roadside Bar", "kind": "casino", "tier": 1,
		"game_ids": ["coin_pusher", "bar_dice"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "normal"},
		"scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls"}},
		"game_states": {},
	}
	var machine := game.generate_environment_state(run_state, environment, run_state.create_rng("coin_pusher_initial"))
	environment["game_states"] = {"coin_pusher": machine}
	run_state.set_environment(environment)
	var lane_cycle: Array = input.get("lane_cycle", [0])
	var upper_cycle: Array = input.get("upper_phase_cycle", [0])
	var lower_cycle: Array = input.get("lower_phase_cycle", [0])
	var outcomes: Array = []
	var action_backends: Array[String] = []
	var native_backend_available := CoinPusherSolverScript.native_backend_available_for_test()
	var expected_action_count := maxi(1, int(input.get("action_count", 200)))
	var captured_frame_count := 0
	var captured_final_frame_sha256 := ""
	for action_index in range(expected_action_count):
		var ui_state := {
			"coin_pusher_lane": int(lane_cycle[action_index % lane_cycle.size()]),
			"coin_pusher_upper_input_phase": int(upper_cycle[action_index % upper_cycle.size()]),
			"coin_pusher_lower_input_phase": int(lower_cycle[action_index % lower_cycle.size()]),
		}
		if action_index == 0:
			ui_state["coin_pusher_capture_presentation_trace"] = true
		var result := game.resolve_with_context(
			str(input.get("action_id", "drop_quarter")), 1, run_state, run_state.current_environment,
			run_state.create_rng("export_parity_action_%03d" % action_index), ui_state
		)
		action_backends.append(CoinPusherSolverScript.last_step_backend_for_test())
		if action_index == 0:
			var patch: Dictionary = result.get("surface_presentation_snapshot_patch", {}) if typeof(result.get("surface_presentation_snapshot_patch", {})) == TYPE_DICTIONARY else {}
			var packed: Dictionary = patch.get("trace_packed", {}) if typeof(patch.get("trace_packed", {})) == TYPE_DICTIONARY else {}
			captured_frame_count = int(packed.get("frame_count", 0))
			var decoded := CoinPusherSolverScript.decode_packed_presentation_trace(packed)
			if decoded.size() == captured_frame_count and not decoded.is_empty():
				captured_final_frame_sha256 = JSON.stringify(decoded.back()).sha256_text()
		outcomes.append([
			int(result.get("coin_pusher_payout", 0)), bool(result.get("coin_pusher_gutter", false)),
			int(result.get("coin_pusher_input_phase", -1)), int(result.get("coin_pusher_phase_accuracy", -1)),
			_compact_events(result.get("coin_pusher_physics_events", [])),
		])
		GameModuleScript.apply_result(run_state, result, run_state.create_rng("export_parity_apply_%03d" % action_index))
	var final_machine: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var final_simulation: Dictionary = final_machine.get("simulation", {}) if typeof(final_machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var native_acceptance := native_acceptance_report(native_backend_available, action_backends, expected_action_count)
	var report := {
		"ok": bool(native_acceptance.get("all_actions_native", false)) and captured_frame_count == 14 and not captured_final_frame_sha256.is_empty(),
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"distribution_feature": OS.has_feature("distribution_build"),
		"input_artifact_sha256": input_text.sha256_text(),
		"action_count": outcomes.size(),
		"outcomes": outcomes,
		"outcomes_sha256": JSON.stringify(outcomes).sha256_text(),
		"final_digest": game.deterministic_state_digest(run_state.current_environment),
		"final_simulation": CoinPusherSolverScript.canonical_digest(final_simulation),
		"captured_frame_count": captured_frame_count,
		"captured_final_frame_sha256": captured_final_frame_sha256,
	}
	report.merge(native_acceptance)
	_publish(report)


static func native_acceptance_report(native_available: bool, action_backends: Array, expected_action_count: int) -> Dictionary:
	var native_action_count := 0
	for backend_value in action_backends:
		if str(backend_value) == "native":
			native_action_count += 1
	var action_backend_count := action_backends.size()
	var all_actions_native := native_available \
		and expected_action_count > 0 \
		and action_backend_count == expected_action_count \
		and native_action_count == expected_action_count
	return {
		"native_backend_available": native_available,
		"native_action_count": native_action_count,
		"action_backend_count": action_backend_count,
		"action_backends_sha256": JSON.stringify(action_backends).sha256_text(),
		"all_actions_native": all_actions_native,
	}


func _compact_events(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for event_value in value as Array:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		result.append([
			str(event.get("body_id", "")), str(event.get("kind", "")), str(event.get("outcome", "")),
			str(event.get("cause", "")), int(event.get("x", 0)), int(event.get("y", 0)), int(event.get("z", 0)),
		])
	return result


func _publish(report: Dictionary) -> void:
	var payload := JSON.stringify(report)
	print(RESULT_MARKER + payload)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BTHCoinPusherParity = JSON.parse(%s); document.title = 'BTH_COIN_PUSHER_PARITY_DONE';" % JSON.stringify(payload), true)
	else:
		get_tree().quit(0 if bool(report.get("ok", false)) else 1)
