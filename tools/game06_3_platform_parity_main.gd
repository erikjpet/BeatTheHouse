extends Node

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RESULT_MARKER := "GAME06_3_PLATFORM_PARITY="
const SEED_COUNT := 10


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("Content validation failed: %s" % error)
	var roulette: GameModule = _load_game(library, "roulette", failures)
	var baccarat: GameModule = _load_game(library, "baccarat", failures)
	var payload := {"seed_count": SEED_COUNT, "roulette": [], "baccarat": []}
	if roulette != null:
		payload["roulette"] = _roulette_payload(roulette, failures)
	if baccarat != null:
		payload["baccarat"] = _baccarat_payload(baccarat, failures)
	var semantic_json := JSON.stringify(payload)
	var report := {
		"ok": failures.is_empty(),
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"failures": failures,
		"semantic_payload": payload,
		"semantic_sha256": semantic_json.sha256_text(),
	}
	print(RESULT_MARKER + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _load_game(library: ContentLibrary, game_id: String, failures: Array):
	var definition: Dictionary = library.game(game_id)
	var module_script: Script = load(str(definition.get("module_path", "")))
	if definition.is_empty() or module_script == null:
		failures.append("Could not load %s." % game_id)
		return null
	var game = module_script.new()
	if not game is GameModule:
		failures.append("%s does not extend GameModule." % game_id)
		return null
	game.setup(definition, library)
	return game


func _roulette_payload(game: GameModule, failures: Array) -> Array:
	var records: Array = []
	for index in range(SEED_COUNT):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("GAME06_3-PLATFORM-ROULETTE-%02d" % index)
		var environment := _environment("roulette", index)
		var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("table"))
		environment["game_states"] = {"roulette": table}
		run_state.current_environment = environment.duplicate(true)
		var rng := run_state.create_rng("spin")
		var profile: Dictionary = game.call("_effective_physics_profile", table, run_state, environment, {}, rng)
		var spin: Dictionary = game.call("_simulate_spin", table, profile, rng)
		spin = game.call("_apply_table_wheel_bias", spin, table, rng)
		var number := str(spin.get("winning_number", ""))
		var winning_index := int(spin.get("winning_index", -1))
		var sequence: Array = table.get("wheel_sequence", []) if typeof(table.get("wheel_sequence", [])) == TYPE_ARRAY else []
		var physics: Dictionary = _dict(spin.get("physics", {}))
		var capture: Dictionary = _dict(physics.get("capture", {}))
		var trajectory: Array = spin.get("trajectory", []) if typeof(spin.get("trajectory", [])) == TYPE_ARRAY else []
		var final_frame: Dictionary = _dict(trajectory[trajectory.size() - 1]) if not trajectory.is_empty() else {}
		var final_angle := _rounded(fposmod(float(final_frame.get("ball_angle", -1.0)), TAU))
		var capture_angle := _rounded(fposmod(float(capture.get("final_ball_angle", -2.0)), TAU))
		if winning_index < 0 or winning_index >= sequence.size() or str(sequence[winning_index]) != number:
			failures.append("Roulette seed %d authority did not map to its wheel pocket." % index)
		if int(capture.get("index", -1)) != winning_index or str(capture.get("number", "")) != number:
			failures.append("Roulette seed %d capture metadata diverged from authority." % index)
		if trajectory.size() < 48 or absf(final_angle - capture_angle) > 0.000001:
			failures.append("Roulette seed %d presentation did not finish in the authoritative pocket." % index)
		records.append({
			"seed": index,
			"number": number,
			"winning_index": winning_index,
			"trajectory_frames": trajectory.size(),
			"final_ball_angle": final_angle,
			"capture_angle": capture_angle,
		})
	return records


func _baccarat_payload(game: GameModule, failures: Array) -> Array:
	var records: Array = []
	for index in range(SEED_COUNT):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("GAME06_3-PLATFORM-BACCARAT-%02d" % index)
		run_state.simulation_msec = 10000
		var squeeze_event := {
			"type": "squeeze",
			"target_zone": "player" if index % 2 == 0 else "banker",
			"card_slot": index % 3,
			"delay_msec": 1800,
			"duration_msec": 600,
		}
		var table := {"last_result": {"hand_id": "platform_%02d" % index, "resolved_at_msec": 8200, "animation_events": [squeeze_event]}}
		var before := JSON.stringify(table)
		var normal: Dictionary = game.call("_squeeze_command", {"surface_time_msec": 10000}, table, run_state, false)
		var reduced: Dictionary = game.call("_squeeze_command", {"surface_time_msec": 10000, "reduce_motion": true}, table, run_state, false)
		var target: Dictionary = game.call("_baccarat_squeeze_state", table.get("last_result", {}))
		var normal_progress := _rounded(float(_dict(normal.get("ui_state", {})).get("baccarat_squeeze_progress", 0.0)))
		var reduced_progress := _rounded(float(_dict(reduced.get("ui_state", {})).get("baccarat_squeeze_progress", 0.0)))
		if JSON.stringify(table) != before:
			failures.append("Baccarat seed %d squeeze mutated the fixed card authority." % index)
		if str(target.get("target_zone", "")) != str(squeeze_event.get("target_zone", "")) or int(target.get("card_slot", -1)) != int(squeeze_event.get("card_slot", -2)):
			failures.append("Baccarat seed %d squeeze targeted a different card." % index)
		if normal_progress <= 0.0 or normal_progress >= 1.0 or reduced_progress != 1.0:
			failures.append("Baccarat seed %d normal/reduced squeeze parity failed." % index)
		records.append({
			"seed": index,
			"target_zone": str(target.get("target_zone", "")),
			"card_slot": int(target.get("card_slot", -1)),
			"normal_progress": normal_progress,
			"reduced_progress": reduced_progress,
		})
	return records


func _environment(game_id: String, index: int) -> Dictionary:
	return {
		"id": "game06_3_platform_%s_%02d" % [game_id, index],
		"archetype_id": "grand_casino",
		"kind": "boss",
		"game_ids": [game_id],
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 1000},
		"security_profile": {"strictness": "high"},
	}


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _rounded(value: float) -> float:
	return snappedf(value, 0.000001)
