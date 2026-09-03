extends SceneTree

# Opt-in historical fixture capture. This script is copied into an archive of
# the pinned v0.5.1 tree by tools/integ06_1_generate_v051_fixtures.ps1. Every
# state mutation below goes through FoundationMain's player-facing runtime.

const MainScene := preload("res://scenes/main.tscn")
const CAPTURE_TIMEOUT_SECONDS := 90.0


func _init() -> void:
	call_deferred("_begin_capture")


func _begin_capture() -> void:
	create_timer(CAPTURE_TIMEOUT_SECONDS).timeout.connect(_capture_timed_out)
	await _capture()


func _capture() -> void:
	print("INTEG06_1_PHASE=driver_started")
	var options := _options(OS.get_cmdline_user_args())
	var cases := _capture_cases(options)
	if cases.is_empty():
		_fail("capture plan did not contain a case")
		return
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version != "0.5.1":
		_fail("historical capture requires project version 0.5.1, got %s" % version)
		return

	for case_value in cases:
		if typeof(case_value) != TYPE_DICTIONARY:
			_fail("capture plan contained a non-dictionary case")
			return
		# Each fixture is an independent historical run. A fresh main scene prevents
		# modal/input guards and deferred UI state from one case reaching the next.
		var app: Control = MainScene.instantiate()
		app.set("continuous_environment_clock_enabled", false)
		root.add_child(app)
		await process_frame
		await process_frame
		print("INTEG06_1_PHASE=%s:historical_main_ready" % str((case_value as Dictionary).get("fixture_id", "unknown")))
		if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
			_fail("historical main scene did not initialize FoundationMain")
			return
		var result := await _capture_case(app, case_value as Dictionary, version)
		if result.is_empty():
			return
		print("INTEG06_1_FIXTURE_RESULT=%s" % JSON.stringify(result))
		app.queue_free()
		await process_frame
		await process_frame
	quit(0)


func _capture_case(app: Control, capture_case: Dictionary, version: String) -> Dictionary:
	var fixture_id := str(capture_case.get("fixture_id", "")).strip_edges()
	var seed_text := str(capture_case.get("seed", "")).strip_edges()
	if fixture_id.is_empty() or seed_text.is_empty():
		_fail("fixture id and seed must be non-empty")
		return {}
	app.set("autosave_slot_id", fixture_id)

	var methods: Array[String] = []
	var challenge_modifiers: Dictionary = capture_case.get("challenge_modifiers", {}).duplicate(true) if typeof(capture_case.get("challenge_modifiers", {})) == TYPE_DICTIONARY else {}
	var challenge_id := str(capture_case.get("challenge_id", "integ06_1_historical_fixture")).strip_edges()
	var challenge_config: Dictionary = {}
	if not challenge_modifiers.is_empty():
		challenge_config = RunState.custom_challenge(challenge_id, seed_text, challenge_modifiers)
		methods.append("RunState.custom_challenge")
	app.call("start_foundation_run", seed_text, challenge_config, false)
	methods.append("FoundationMain.start_foundation_run")
	await process_frame
	await process_frame
	print("INTEG06_1_PHASE=%s:foundation_run_started" % fixture_id)
	var run_state: Variant = app.get("run_state")
	if run_state == null:
		_fail("FoundationMain did not create a run")
		return {}
	var travel_path: Array[String] = []
	var steps: Array = capture_case.get("steps", []) if typeof(capture_case.get("steps", [])) == TYPE_ARRAY else []
	if steps.is_empty():
		for target_id in _string_array(capture_case.get("travel_path", [])):
			steps.append({"type": "travel", "target": target_id})
	for step_value in steps:
		if typeof(step_value) != TYPE_DICTIONARY:
			_fail("%s capture step was not a dictionary" % fixture_id)
			return {}
		var step: Dictionary = step_value
		var step_type := str(step.get("type", "")).strip_edges()
		if step_type == "lender":
			var lender_id := str(step.get("lender_id", "")).strip_edges()
			var lender_environment: Dictionary = run_state.get("current_environment")
			print("INTEG06_1_PHASE=%s:lender_attempt:%s:hooks=%s:block=%s" % [fixture_id, lender_id, str(lender_environment.get("lender_hooks", [])), str(app.call("_blocking_modal_message"))])
			if not bool(app.call("use_lender_hook", lender_id)):
				_fail("%s could not use public lender hook %s" % [fixture_id, lender_id])
				return {}
			methods.append("FoundationMain.use_lender_hook:%s" % lender_id)
			await process_frame
			await process_frame
			run_state = app.get("run_state")
			print("INTEG06_1_PHASE=%s:lender:%s:bankroll=%s:debts=%s" % [fixture_id, lender_id, str(run_state.get("bankroll")), str(run_state.get("debt"))])
			continue
		if step_type == "event":
			var event_id := str(step.get("event_id", "")).strip_edges()
			var choice_id := str(step.get("choice_id", "")).strip_edges()
			if not bool(app.call("select_event_choice", event_id, choice_id)):
				_fail("%s could not select public event choice %s:%s" % [fixture_id, event_id, choice_id])
				return {}
			app.call("confirm_selected_event_choice")
			methods.append("FoundationMain.select_event_choice:%s:%s" % [event_id, choice_id])
			methods.append("FoundationMain.confirm_selected_event_choice")
			await process_frame
			await process_frame
			run_state = app.get("run_state")
			var event_environment: Dictionary = run_state.get("current_environment")
			print("INTEG06_1_PHASE=%s:event:%s:%s:next=%s:block=%s:popup=%s" % [fixture_id, event_id, choice_id, str(event_environment.get("next_archetypes", [])), str(app.call("_blocking_modal_message")), str(app.call("current_event_choice_popup_snapshot"))])
			continue
		if step_type != "travel":
			_fail("%s capture step had unsupported type %s" % [fixture_id, step_type])
			return {}
		var target_id := str(step.get("target", "")).strip_edges()
		if not bool(app.call("select_travel_option", target_id)):
			_fail("%s could not select public travel target %s choice=%s block=%s" % [fixture_id, target_id, str(app.call("_travel_choice", target_id)), str(app.call("_blocking_modal_message"))])
			return {}
		app.call("confirm_selected_travel")
		await process_frame
		await process_frame
		run_state = app.get("run_state")
		var arrived_environment: Dictionary = run_state.get("current_environment")
		if str(arrived_environment.get("archetype_id", "")) != target_id:
			_fail("%s travel reached %s instead of %s" % [fixture_id, str(arrived_environment.get("archetype_id", "")), target_id])
			return {}
		methods.append("FoundationMain.select_travel_option:%s" % target_id)
		methods.append("FoundationMain.confirm_selected_travel")
		travel_path.append(target_id)
		print("INTEG06_1_PHASE=%s:travel:%s:next=%s" % [fixture_id, target_id, str(arrived_environment.get("next_archetypes", []))])

	var environment: Dictionary = run_state.get("current_environment")
	var expected_archetype := str(capture_case.get("expected_archetype", "")).strip_edges()
	if not expected_archetype.is_empty() and str(environment.get("archetype_id", "")) != expected_archetype:
		_fail("%s expected archetype %s, got %s" % [fixture_id, expected_archetype, str(environment.get("archetype_id", ""))])
		return {}
	var game_ids := _string_array(environment.get("game_ids", []))
	var game_id := ""
	var requested_game := str(capture_case.get("enter_game", "")).strip_edges()
	if requested_game == "first":
		if game_ids.is_empty():
			_fail("%s reached an environment with no playable game" % fixture_id)
			return {}
		game_id = str(game_ids[0])
	elif not requested_game.is_empty():
		if not game_ids.has(requested_game):
			_fail("%s requested unavailable generated game %s from %s" % [fixture_id, requested_game, str(game_ids)])
			return {}
		game_id = requested_game
	if not game_id.is_empty():
		if not bool(app.call("enter_game", game_id)):
			_fail("FoundationMain could not enter generated game %s" % game_id)
			return {}
		methods.append("FoundationMain.enter_game")
		await process_frame
		await process_frame

	# This is the public, synchronous player save boundary. It checkpoints the
	# live game surface before SaveService writes the historical envelope.
	app.call("save_foundation_run")
	methods.append("FoundationMain.save_foundation_run")
	print("INTEG06_1_PHASE=%s:public_save_returned" % fixture_id)
	var save_service: Variant = app.get("save_service")
	if save_service == null:
		_fail("FoundationMain did not expose its SaveService")
		return {}
	var save_error := int(save_service.call("wait_for_async_save"))
	methods.append("SaveService.wait_for_async_save")
	if save_error != OK:
		_fail("historical save did not finish: %d" % save_error)
		return {}
	var save_path := str(save_service.call("run_save_path", fixture_id))
	if not FileAccess.file_exists(save_path):
		_fail("historical SaveService did not write %s" % save_path)
		return {}
	var saved_text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(saved_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("historical SaveService output was not a JSON dictionary")
		return {}
	var envelope: Dictionary = parsed
	if str(envelope.get("schema", "")) != "beat_the_house.foundation_run":
		_fail("historical SaveService output had the wrong schema")
		return {}

	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	var event_cadence: Dictionary = run_state.get("event_cadence")
	return {
		"fixture_id": fixture_id,
		"seed": seed_text,
		"project_version": version,
		"save_path": ProjectSettings.globalize_path(save_path),
		"save_schema": str(envelope.get("schema", "")),
		"save_version": int(envelope.get("version", 0)),
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"game_id": game_id,
		"screen": str(screen_snapshot.get("screen", "")),
		# FoundationMain retains the previous surface key after a later run starts.
		# An environment-only capture has no foreground game, so do not let that
		# diagnostic-only residue misdescribe the fixture provenance.
		"game_state_key": str(app.get("current_game_state_key")) if not game_id.is_empty() else "",
		"action_index": int(event_cadence.get("action_index", 0)),
		"game_clock_minutes": run_state.get("game_clock_minutes"),
		"challenge_id": challenge_id if not challenge_modifiers.is_empty() else "",
		"challenge_modifiers": challenge_modifiers,
		"travel_path": travel_path,
		"methods": methods,
	}


func _capture_cases(options: Dictionary) -> Array:
	var plan_path := str(options.get("plan", "")).strip_edges()
	if plan_path.is_empty():
		return [{
			"fixture_id": str(options.get("fixture-id", "v051_smoke_foundation_run")),
			"seed": str(options.get("seed", "INTEG06-1-V051-SMOKE-001")),
			"enter_game": "first" if str(options.get("require-game", "false")).to_lower() in ["1", "true", "yes", "on"] else "",
		}]
	if not FileAccess.file_exists(plan_path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var plan: Dictionary = parsed
	var cases: Variant = plan.get("cases", [])
	if typeof(cases) != TYPE_ARRAY:
		return []
	var sequences: Dictionary = plan.get("step_sequences", {}) if typeof(plan.get("step_sequences", {})) == TYPE_DICTIONARY else {}
	var expanded: Array = []
	for case_value in cases as Array:
		if typeof(case_value) != TYPE_DICTIONARY:
			expanded.append(case_value)
			continue
		var capture_case: Dictionary = (case_value as Dictionary).duplicate(true)
		var sequence_id := str(capture_case.get("step_sequence", "")).strip_edges()
		if not sequence_id.is_empty() and typeof(sequences.get(sequence_id, [])) == TYPE_ARRAY:
			var resolved_steps: Array = (sequences.get(sequence_id, []) as Array).duplicate(true)
			if typeof(capture_case.get("append_steps", [])) == TYPE_ARRAY:
				resolved_steps.append_array((capture_case.get("append_steps", []) as Array).duplicate(true))
			capture_case["steps"] = resolved_steps
		expanded.append(capture_case)
	return expanded


func _options(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--") and index + 1 < arguments.size():
			result[argument.trim_prefix("--")] = str(arguments[index + 1])
			index += 2
		else:
			index += 1
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


func _fail(message: String) -> void:
	push_error("integ06_1 v0.5.1 fixture capture failed: %s" % message)
	quit(1)


func _capture_timed_out() -> void:
	push_error("integ06_1 v0.5.1 fixture capture exceeded %.0f seconds" % CAPTURE_TIMEOUT_SECONDS)
	quit(124)
