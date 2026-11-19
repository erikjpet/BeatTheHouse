extends SceneTree

# Run the lesson and skip branches in separate fresh BTH_SAVE_DIR roots.
const Host = preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _host() -> Control:
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.size = Vector2(1280, 720)
	return app

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame

func _run() -> void:
	var branch := OS.get_environment("BTH_FIRST_LESSON_BRANCH")
	if OS.get_environment("BTH_SAVE_DIR").is_empty() or (branch != "lesson" and branch != "skip"):
		quit(64)
		return
	root.size = Vector2i(1280, 720)
	var app := _host()
	await _frames()
	var profile_before: Dictionary = app.profile_inventory.to_dict().duplicate(true)
	_check(app._fresh_profile_needs_tutorial(), "fresh profile needs first-run choice")
	_check(app._on_start_pressed(), "fresh PLAY opens choice")
	var choice: ConfirmationDialog = app.first_lesson_choice
	_check(choice != null and choice.visible, "choice is visible")
	_check(choice.get_cancel_button().has_focus(), "Back has safe initial focus")
	_check(choice.get_ok_button().text == "Start Lesson" and app.first_lesson_skip_button.text == "Skip Tutorial", "both explicit choices are labelled")
	_check(app.run_state == null and not app._has_foundation_save(), "opening choice creates no run")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	app._on_first_lesson_choice_input(cancel)
	await _frames(1)
	_check(not choice.visible and app.run_state == null, "controller Back cancels without starting")
	_check(app.profile_inventory.to_dict() == profile_before and not app._has_foundation_save(), "Back preserves profile and save")
	_check(app._on_start_pressed() and choice.visible, "choice reopens after Back")
	choice.get_cancel_button().pressed.emit()
	await _frames(1)
	_check(not choice.visible and app.profile_inventory.to_dict() == profile_before, "mouse Back preserves onboarding")
	_check(app._on_start_pressed() and choice.visible, "choice reopens for explicit selection")
	if branch == "lesson":
		choice.get_ok_button().pressed.emit()
		await _frames()
		_check(not choice.visible and app.run_state != null and app.run_state.is_tutorial_run(), "Start Lesson enters authored lesson")
		_check(app.profile_inventory.tutorial_completed, "Lesson start resolves first-run prompt")
		_check(app.profile_inventory.items == profile_before.get("items", []), "Lesson start does not grant inventory")
		_check(app.profile_inventory.challenge_completions == profile_before.get("challenge_completions", {}), "Lesson start does not grant challenge completion")
		_check(app._autosave_foundation_run("First Lesson replay Save.", true), "Lesson Save establishes replacement boundary")
		_check(app.request_tutorial_replay() and app.new_run_confirmation.visible, "explicit Replay Lessons retains replacement prompt")
		app._cancel_new_run_start()
		_check(app.run_state != null and app.run_state.is_tutorial_run(), "cancel Replay preserves lesson")
	else:
		choice.custom_action.emit(&"skip_tutorial")
		await _frames()
		_check(not choice.visible and app.run_state != null and not app.run_state.is_tutorial_run(), "Skip enters ordinary run")
		_check(app.profile_inventory.tutorial_completed, "Skip persists explicit onboarding choice")
		_check(app.profile_inventory.items == profile_before.get("items", []), "Skip grants no inventory")
		_check(app.profile_inventory.challenge_completions == profile_before.get("challenge_completions", {}), "Skip grants no lesson completion")
		var seed: String = str(app.run_state.seed_text)
		_check(app._autosave_foundation_run("First Lesson choice Save.", true), "ordinary run Save succeeds")
		app.queue_free()
		await _frames(2)
		var cold := _host()
		await _frames()
		_check(cold.profile_inventory.tutorial_completed and not cold._fresh_profile_needs_tutorial(), "returning profile retains Skip choice")
		_check(cold.start_or_continue_primary(), "Continue restores ordinary run")
		await _frames()
		_check(cold.run_state != null and not cold.run_state.is_tutorial_run() and cold.run_state.seed_text == seed, "Continue preserves ordinary seed and mode")
		_check(not cold.first_lesson_choice.visible, "Continue does not nag with Lesson choice")
		_check(cold.request_tutorial_replay() and cold.new_run_confirmation.visible, "Replay Lessons remains available after Skip")
		cold._cancel_new_run_start()
		_check(cold.run_state != null and cold.run_state.seed_text == seed, "cancel Replay preserves saved run")
		app = cold
	app.pending_autosave = false
	app.queue_free()
	await _frames(2)
	print("FIRST_LESSON_CHOICE ", JSON.stringify({"branch": branch, "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
