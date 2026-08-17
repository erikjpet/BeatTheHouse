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
	for action_index in range(maxi(1, int(input.get("action_count", 200)))):
		var ui_state := {
			"coin_pusher_lane": int(lane_cycle[action_index % lane_cycle.size()]),
			"coin_pusher_upper_input_phase": int(upper_cycle[action_index % upper_cycle.size()]),
			"coin_pusher_lower_input_phase": int(lower_cycle[action_index % lower_cycle.size()]),
		}
		var result := game.resolve_with_context(
			str(input.get("action_id", "drop_quarter")), 1, run_state, run_state.current_environment,
			run_state.create_rng("export_parity_action_%03d" % action_index), ui_state
		)
		outcomes.append([
			int(result.get("coin_pusher_payout", 0)), bool(result.get("coin_pusher_gutter", false)),
			int(result.get("coin_pusher_input_phase", -1)), int(result.get("coin_pusher_phase_accuracy", -1)),
			_compact_events(result.get("coin_pusher_physics_events", [])),
		])
		GameModuleScript.apply_result(run_state, result, run_state.create_rng("export_parity_apply_%03d" % action_index))
	var final_machine: Dictionary = (run_state.current_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {})
	var final_simulation: Dictionary = final_machine.get("simulation", {}) if typeof(final_machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var report := {
		"ok": true,
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"distribution_feature": OS.has_feature("distribution_build"),
		"input_artifact_sha256": input_text.sha256_text(),
		"action_count": outcomes.size(),
		"outcomes": outcomes,
		"outcomes_sha256": JSON.stringify(outcomes).sha256_text(),
		"final_digest": game.deterministic_state_digest(run_state.current_environment),
		"final_simulation": CoinPusherSolverScript.canonical_digest(final_simulation),
	}
	_publish(report)


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
