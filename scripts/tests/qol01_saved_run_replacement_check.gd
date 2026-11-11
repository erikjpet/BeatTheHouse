extends SceneTree
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures: Array[String] = []
var app
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _init() -> void: call_deferred("run")
func baseline(label: String) -> void:
	app.start_foundation_run("QOL01-OLD-" + label, {}, false)
	app._autosave_foundation_run("Baseline.", true)
	app.return_to_main_menu()
	app._ensure_run_ui_built()
	app._ensure_start_menu_config_panels_built()
	app.seed_input.text = "QOL01-NEW-" + label
func run() -> void:
	app = Main.instantiate()
	root.add_child(app)
	await process_frame
	app._complete_tutorial_profile()
	for route in ["_on_start_pressed", "start_generated_foundation_run", "start_meta_quick_run", "start_daily_challenge_run", "request_tutorial_replay"]:
		baseline(route)
		await process_frame
		var old_state = app.run_state
		var path: String = app.save_service.run_save_path(app.autosave_slot_id)
		var before := FileAccess.get_file_as_bytes(path)
		app.call(route)
		await process_frame
		var dialog = app.get("new_run_confirmation")
		check(dialog != null and dialog.visible, route + " asks before replacement")
		check(FileAccess.get_file_as_bytes(path) == before, route + " keeps primary before consent")
		check(app.run_state == old_state, route + " keeps current run before consent")
		if dialog == null or not dialog.visible: continue
		check(dialog.dialog_text == "Start a new run? Your saved run will be replaced.", route + " exact prompt")
		check(dialog.get_cancel_button().text == "Keep saved run", route + " safe cancel label")
		check(dialog.get_cancel_button().has_focus(), route + " safe default focus")
		# Use the shared keyboard scope and actual dialog cancel-button signal.
		var enter := InputEventAction.new()
		enter.action = "ui_accept"
		enter.pressed = true
		app._on_new_run_confirmation_input(enter)
		await process_frame
		check(not dialog.visible and FileAccess.get_file_as_bytes(path) == before, route + " default Enter preserves bytes")
		app.call(route)
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		app._on_new_run_confirmation_input(escape)
		check(not dialog.visible and FileAccess.get_file_as_bytes(path) == before, route + " Escape preserves bytes")
		app.call(route)
		dialog.get_cancel_button().pressed.emit()
		await process_frame
		check(not dialog.visible and FileAccess.get_file_as_bytes(path) == before, route + " cancel-button preserves bytes")
		app.call(route)
		dialog.get_ok_button().pressed.emit()
		await process_frame
		check(not dialog.visible and app.run_state != old_state, route + " explicit start proceeds")
		check(not app._pending_new_run_start.is_valid(), route + " pending callback clears")
		app._confirm_new_run_start()
		var replacement = app.run_state
		app._confirm_new_run_start()
		await process_frame
		check(app.run_state == replacement, route + " repeated confirmation cannot start twice")
	baseline("BACKUP")
	await process_frame
	var primary: String = app.save_service.run_save_path(app.autosave_slot_id)
	var backup: String = app.save_service.backup_save_path(app.autosave_slot_id)
	DirAccess.remove_absolute(backup)
	check(DirAccess.rename_absolute(primary, backup) == OK, "backup-only fixture prepared")
	var backup_bytes := FileAccess.get_file_as_bytes(backup)
	app._on_start_pressed()
	check(app.new_run_confirmation.visible, "loadable backup asks before replacement")
	app._cancel_new_run_start()
	check(FileAccess.get_file_as_bytes(backup) == backup_bytes, "cancel retains backup-only bytes")
	# No loadable save, including an unreadable save, preserves immediate start.
	app.save_service.clear_run(app.autosave_slot_id)
	app.run_state = null
	app.seed_input.text = "QOL01-NO-SAVE"
	check(app._on_start_pressed(), "no-save start succeeds")
	check(app.run_state != null and app.run_state.seed_text == "QOL01-NO-SAVE", "no-save begins immediately")
	var final_dialog = app.get("new_run_confirmation")
	check(final_dialog == null or not final_dialog.visible, "no-save has no prompt")
	app.save_service.clear_run(app.autosave_slot_id)
	app.pending_autosave = false
	var invalid := FileAccess.open(app.save_service.run_save_path(app.autosave_slot_id), FileAccess.WRITE)
	invalid.store_string("invalid current-build fixture")
	invalid.close()
	app.seed_input.text = "QOL01-UNLOADABLE"
	check(app._on_start_pressed(), "unloadable save starts immediately")
	check(not app.new_run_confirmation.visible and app.run_state.seed_text == "QOL01-UNLOADABLE", "unloadable save does not prompt")
	app.profile_inventory.tutorial_completed = false
	app.selected_challenge_id = ""
	app._on_start_pressed()
	check(app.run_state != null and app.run_state.is_tutorial_run(), "mandatory tutorial path begins without confirmation")
	check(final_dialog == null or not final_dialog.visible, "tutorial has no prompt")
	app.run_state.run_status = RunState.RUN_STATUS_FAILED
	app._on_run_report_new_run_requested()
	check(final_dialog == null or not final_dialog.visible, "finished report New Run has no prompt")
	app.start_foundation_run("QOL01-FINISHED", {}, false)
	app.run_state.run_status = RunState.RUN_STATUS_FAILED
	app._on_run_report_new_run_requested()
	check(final_dialog == null or not final_dialog.visible, "ordinary finished report has no prompt")
	check(app.run_state != null and app.run_state.run_status == RunState.RUN_STATUS_ACTIVE, "ordinary finished report starts next run")
	app.pending_autosave = false
	app.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "failures": failures, "failure_count": failures.size()}))
	quit(0 if failures.is_empty() else 1)
