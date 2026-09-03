extends SceneTree

# Opt-in historical fixture capture. This script is copied into an archive of
# the pinned v0.5.1 tree by tools/integ06_1_generate_v051_fixtures.ps1. Every
# state mutation below goes through FoundationMain's player-facing runtime.

const MainScene := preload("res://scenes/main.tscn")
const CAPTURE_TIMEOUT_SECONDS := 90.0


func _init() -> void:
	get_root().get_tree().create_timer(CAPTURE_TIMEOUT_SECONDS).timeout.connect(_capture_timed_out)
	call_deferred("_capture")


func _capture() -> void:
	print("INTEG06_1_PHASE=driver_started")
	var options := _options(OS.get_cmdline_user_args())
	var fixture_id := str(options.get("fixture-id", "v051_smoke_foundation_run")).strip_edges()
	var seed_text := str(options.get("seed", "INTEG06-1-V051-SMOKE-001")).strip_edges()
	var require_game := str(options.get("require-game", "false")).to_lower() in ["1", "true", "yes", "on"]
	if fixture_id.is_empty() or seed_text.is_empty():
		_fail("fixture id and seed must be non-empty")
		return
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version != "0.5.1":
		_fail("historical capture requires project version 0.5.1, got %s" % version)
		return

	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", fixture_id)
	root.add_child(app)
	await process_frame
	await process_frame
	print("INTEG06_1_PHASE=historical_main_ready")
	if not app.has_method("uses_foundation_runtime") or not bool(app.call("uses_foundation_runtime")):
		_fail("historical main scene did not initialize FoundationMain")
		return

	app.call("start_foundation_run", seed_text, {}, false)
	await process_frame
	await process_frame
	print("INTEG06_1_PHASE=foundation_run_started")
	var run_state: Variant = app.get("run_state")
	if run_state == null:
		_fail("FoundationMain did not create a run")
		return
	var environment: Dictionary = run_state.get("current_environment")
	var game_ids := _string_array(environment.get("game_ids", []))
	var game_id := ""
	var methods := ["FoundationMain.start_foundation_run"]
	if not game_ids.is_empty():
		game_id = str(game_ids[0])
		if not bool(app.call("enter_game", game_id)):
			_fail("FoundationMain could not enter generated game %s" % game_id)
			return
		methods.append("FoundationMain.enter_game")
		await process_frame
		await process_frame
	elif require_game:
		_fail("generated environment had no playable game")
		return

	# This is the public, synchronous player save boundary. It checkpoints the
	# live game surface before SaveService writes the historical envelope.
	app.call("save_foundation_run")
	methods.append("FoundationMain.save_foundation_run")
	print("INTEG06_1_PHASE=public_save_returned")
	var save_service: Variant = app.get("save_service")
	if save_service == null:
		_fail("FoundationMain did not expose its SaveService")
		return
	var save_error := int(save_service.call("wait_for_async_save"))
	methods.append("SaveService.wait_for_async_save")
	if save_error != OK:
		_fail("historical save did not finish: %d" % save_error)
		return
	var save_path := str(save_service.call("run_save_path", fixture_id))
	if not FileAccess.file_exists(save_path):
		_fail("historical SaveService did not write %s" % save_path)
		return
	var saved_text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(saved_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("historical SaveService output was not a JSON dictionary")
		return
	var envelope: Dictionary = parsed
	if str(envelope.get("schema", "")) != "beat_the_house.foundation_run":
		_fail("historical SaveService output had the wrong schema")
		return

	var screen_snapshot: Dictionary = app.call("current_screen_snapshot")
	var result := {
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
		"game_state_key": str(app.get("current_game_state_key")),
		"action_index": run_state.get("action_index"),
		"game_clock_minutes": run_state.get("game_clock_minutes"),
		"methods": methods,
	}
	print("INTEG06_1_FIXTURE_RESULT=%s" % JSON.stringify(result))
	app.queue_free()
	await process_frame
	quit(0)


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
