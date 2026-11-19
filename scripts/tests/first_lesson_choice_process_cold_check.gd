extends SceneTree
const Host = preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _frames(n: int = 3) -> void:
	for _i in range(n): await process_frame
func _facts(app: Control) -> Dictionary:
	var state: RunState = app.run_state
	return {"seed": state.seed_text, "cash": state.bankroll, "minute": state.game_clock_minutes, "room": str(state.current_environment.get("id", "")), "inventory": state.inventory.duplicate(true)}
func _run() -> void:
	var phase := OS.get_environment("BTH_FIRST_LESSON_PHASE")
	var evidence := OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if OS.get_environment("BTH_SAVE_DIR").is_empty() or evidence.is_empty() or not ["write", "cold"].has(phase):
		quit(64); return
	root.size = Vector2i(1280, 720)
	var app: Control = Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	await _frames()
	var expected_path := evidence.path_join("first_lesson_expected.json")
	if phase == "write":
		_check(app._fresh_profile_needs_tutorial() and app.run_state == null, "fresh profile starts without run")
		_check(app._on_start_pressed() and app.first_lesson_choice.visible, "PLAY opens first choice")
		app.first_lesson_choice.custom_action.emit(&"skip_tutorial")
		await _frames()
		_check(app.run_state != null and not app.run_state.is_tutorial_run() and app.profile_inventory.tutorial_completed, "Skip starts ordinary run and records choice")
		var facts := _facts(app)
		_check(app._autosave_foundation_run("First Lesson process-cold Save.", true), "ordinary Save succeeds")
		app.save_service.wait_for_async_save()
		var file := FileAccess.open(expected_path, FileAccess.WRITE)
		_check(file != null, "expected facts receipt opens")
		if file != null:
			file.store_string(JSON.stringify(facts)); file.close()
	else:
		var file := FileAccess.open(expected_path, FileAccess.READ)
		_check(file != null, "first-process facts receipt exists")
		var expected: Dictionary = {}
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text()); file.close()
			if typeof(parsed) == TYPE_DICTIONARY: expected = parsed
		_check(not expected.is_empty(), "expected facts parse")
		expected["cash"] = int(expected.get("cash", -1))
		expected["minute"] = int(expected.get("minute", -1))
		_check(app.profile_inventory.tutorial_completed and not app._fresh_profile_needs_tutorial(), "Skip choice survives process restart")
		_check(app.start_or_continue_primary(), "Continue loads ordinary run")
		await _frames()
		_check(app.run_state != null and not app.run_state.is_tutorial_run(), "Continue does not enter Lesson")
		if app.run_state != null:
			print("FIRST_LESSON_COLD_FACTS ", JSON.stringify({"expected": expected, "observed": _facts(app)}))
			_check(_facts(app) == expected, "seed cash time room inventory persist exactly")
		_check(not app.first_lesson_choice.visible, "returning Continue never nags")
	app.pending_autosave = false
	app.queue_free()
	await _frames(2)
	print("FIRST_LESSON_PROCESS_COLD ", JSON.stringify({"phase": phase, "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)