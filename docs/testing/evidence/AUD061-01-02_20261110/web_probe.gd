extends Node
const MainScene := preload("res://scenes/main.tscn")
var app: Control
var ready := false
var setup: Dictionary = {}
var saved_hash := ""
var baseline_cash := 0
var save_path := ""
var last_emit := 0
func _ready() -> void:
	call_deferred("_mount")
func _mount() -> void:
	app = MainScene.instantiate()
	add_child(app)
	await get_tree().process_frame
	setup["started"] = app.call("start_foundation_run", "AUD061-DEPLOYED-LEAVE", {}, true)
	setup["baseline_saved"] = app.call("_autosave_foundation_run", "Baseline.", true)
	var service: SaveService = app.get("save_service")
	save_path = service.run_save_path("foundation_ui_autosave")
	setup["rollback_cases"] = []
	for suffix in [".bak.rollback", ".rollback"]:
		var stale := FileAccess.open(save_path + suffix, FileAccess.WRITE)
		stale.close()
		var ok: bool = app.call("_autosave_foundation_run", "Rollback recovery.", true)
		setup.rollback_cases.append({"suffix": suffix, "saved": ok, "stale_removed": not FileAccess.file_exists(save_path + suffix)})
	saved_hash = FileAccess.get_sha256(save_path)
	var run: RunState = app.get("run_state")
	baseline_cash = run.bankroll
	run.change_bankroll(-1, true)
	setup["real_storage_obstruction"] = DirAccess.make_dir_absolute(ProjectSettings.globalize_path(save_path + ".tmp")) == OK
	app.call("open_run_menu")
	ready = true
	_publish()
func _process(_delta: float) -> void:
	if ready and Time.get_ticks_msec() - last_emit > 100:
		_publish()
func _point(control: Control, offset: Vector2 = Vector2.ZERO) -> Dictionary:
	var center := control.get_global_rect().get_center() + offset
	return {"x": center.x, "y": center.y}
func _publish() -> void:
	last_emit = Time.get_ticks_msec()
	var dialog: ConfirmationDialog = app.get("leave_without_saving_confirmation")
	var run: RunState = app.get("run_state")
	var targets := {}
	var menu: Button = app.get("run_menu_main_menu_button")
	if menu != null and menu.is_visible_in_tree():
		targets["main_menu"] = _point(menu)
	if dialog != null and dialog.visible:
		targets["keep_playing"] = _point(dialog.get_cancel_button(), Vector2(dialog.position))
		targets["leave"] = _point(dialog.get_ok_button(), Vector2(dialog.position))
	var primary: Button = app.get("new_run_button")
	if primary != null and primary.is_visible_in_tree():
		targets["continue"] = _point(primary)
	var status: Dictionary = app.call("save_status_snapshot")
	var data := {"ready": ready, "setup": setup, "screen": app.get("current_screen"), "run_present": run != null, "cash": run.bankroll if run != null else -1, "baseline_cash": baseline_cash, "modal": dialog != null and dialog.visible, "default_keep_playing": dialog != null and dialog.visible and dialog.get_cancel_button().has_focus(), "leave_focused": dialog != null and dialog.visible and dialog.get_ok_button().has_focus(), "dialog_text": dialog.dialog_text if dialog != null else "", "save_unchanged": FileAccess.get_sha256(save_path) == saved_hash, "last_save_error": status.get("autosave_last_error", 0), "targets": targets}
	JavaScriptBridge.eval("window.__bth_aud061=" + JSON.stringify(data), true)
