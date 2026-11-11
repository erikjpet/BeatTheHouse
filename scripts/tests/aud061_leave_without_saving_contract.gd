extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/core/durable_store.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var expect_exit := false
var completed := false
var mode := "menu"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		mode = args[0]
	call_deferred("_run")

func _run() -> void:
	app = MainScene.instantiate()
	root.add_child(app)
	for i in range(4):
		await process_frame
	_check(bool(app.call("start_foundation_run", "AUD061-CONFIRM-LEAVE", {}, true)), "normal run starts")
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "baseline save succeeds")
	var run: RunState = app.get("run_state")
	var baseline_cash := run.bankroll
	var service: SaveService = app.get("save_service")
	var save_path := service.run_save_path("foundation_ui_autosave")
	var fingerprint := FileAccess.get_sha256(save_path)
	run.change_bankroll(-1, true)
	app.call("open_run_menu")
	Store.set_debug_force_write_failure(true)
	if mode == "menu":
		_check(not bool(app.call("return_to_main_menu")), "failed Main Menu returns false")
	else:
		app.notification(Control.NOTIFICATION_WM_CLOSE_REQUEST)
	var dialog: ConfirmationDialog = app.get("leave_without_saving_confirmation")
	if not _check(dialog != null and dialog.visible, "failed save opens explicit leave dialog"):
		await _finish()
		return
	_check(app.get("run_state") == run and bool(app.get("pending_autosave")), "dialog retains dirty live run")
	_check(dialog.get_cancel_button().text == "Keep playing" and dialog.get_cancel_button().has_focus(), "Keep playing is focused default")
	_check(dialog.dialog_text.contains("Progress since your last successful save will be lost.") and dialog.dialog_text.contains("Last successful save:"), "loss and known successful-save time are stated")
	_check(app.get("modal_focus_scope").call("active_root") == dialog.get_cancel_button().get_parent(), "shared modal scope owns both choices")
	var nav := InputEventAction.new()
	nav.action = "ui_focus_next"
	nav.pressed = true
	app.call("_on_leave_without_saving_input", nav)
	_check(dialog.get_ok_button().has_focus(), "keyboard/controller traversal reaches explicit leave")
	dialog.get_cancel_button().emit_signal("pressed")
	_check(not dialog.visible and app.get("run_state") == run and bool(app.get("pending_autosave")), "Keep playing closes dialog and retains dirty run")
	_check(FileAccess.get_sha256(save_path) == fingerprint, "cancel preserves previous saved bytes")
	_check(app.get("modal_focus_scope").get("_viewport") == app.get_viewport(), "Keep playing restores the underlying Run Menu input viewport")
	if mode == "menu":
		_check(not bool(app.call("return_to_main_menu")) and dialog.visible, "Main Menu can be deliberately retried")
		dialog.get_ok_button().emit_signal("pressed")
		_check(app.get("run_state") == null and str(app.get("current_screen")) == "START", "confirmed leave reaches start screen")
		_check(FileAccess.get_sha256(save_path) == fingerprint, "confirmed leave preserves prior disk generation")
		Store.reset_debug_faults()
		_check(bool(app.call("load_foundation_run")), "Continue loads prior successful save")
		var resumed: RunState = app.get("run_state")
		_check(resumed != null and resumed.bankroll == baseline_cash, "Continue retains saved cash rather than unsaved change")
		app.set("_web_manual_save_pending", true)
		_check(not bool(app.call("return_to_main_menu")) and not dialog.visible, "pending Web Save has no failed-save dialog")
		app.call("exit_game")
		_check(not dialog.visible, "Exit waits for pending Web Save without dialog")
		app.set("_web_manual_save_pending", false)
		_check(bool(app.call("return_to_main_menu")) and not dialog.visible, "healthy save leaves without prompting")
		await _finish()
	else:
		app.call("exit_game")
		_check(dialog.visible, "Exit opens failure dialog again")
		expect_exit = true
		if mode == "repeat":
			app.notification(Control.NOTIFICATION_WM_CLOSE_REQUEST)
		else:
			dialog.get_ok_button().emit_signal("pressed")
		_check(app.get("script_prewarm_thread") == null and not service.async_save_in_flight(), "quit joins owned prewarm and save work")
		_check(FileAccess.get_sha256(save_path) == fingerprint, "quit does not overwrite prior saved bytes")
		Store.reset_debug_faults()
		completed = true
		# Return releases coroutine locals before the actual engine shutdown. The
		# bounded launcher observes real process exit; _finalize checks completion.
		return

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("AUD061-02: " + label)
	return condition

func _finish() -> void:
	Store.reset_debug_faults()
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	completed = true
	print("AUD061_LEAVE_CONTRACT mode=%s checks=%d failures=%d" % [mode, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _finalize() -> void:
	if expect_exit and completed and failures.is_empty():
		print("AUD061_LEAVE_CONTRACT mode=%s checks=%d failures=0 actual_shutdown=true" % [mode, checks])
	elif not completed:
		push_error("AUD061-02 contract exited before completing its expected path")
