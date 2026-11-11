extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Hud := preload("res://scripts/ui/foundation_hud_view_model.gd")
const Store := preload("res://scripts/core/durable_store.gd")
var checks := 0
var failures: Array[String] = []
var observations: Array = []

func _init() -> void: call_deferred("_run")

func _save_icon(model: Dictionary) -> Dictionary:
	for status in model.get("status_icons", []):
		if status.get("id") == "save": return status
	return {}

func _live_icon_state(bar: Control) -> Array:
	var icons: Array = []
	var tray: Control = bar.get("status_tray")
	for child in tray.get_children():
		if not child.is_queued_for_deletion() and child.is_visible_in_tree() and child.texture != null:
			icons.append({"id":child.get_meta("status_id", ""), "tooltip":child.tooltip_text})
	return icons

func _run() -> void:
	var run := RunState.new()
	run.start_new("QOL-02-MODEL")
	var data := {"has_save":true, "save_status_message":"Saved run.", "save_failed":true, "debt_items":["Debt"], "pit_boss_watch":{"active":true}, "pressure":{"state":"distressed"}}
	var model := Hud.run_status_model(run, data)
	observations.append({"case":"explicit_failure", "save_icon":_save_icon(model), "first_icon":model.status_icons[0]})
	_check(_save_icon(model).get("icon") == "danger", "explicit failure changes save icon without parsing status text")
	_check(str(_save_icon(model).get("tooltip", "")).begins_with("Not saving"), "failure tooltip leads with problem and is not truncated")
	_check(model.status_icons[0].get("id") == "save", "save failure stays visible when other icons fill two-icon tray")
	data.save_failed = false
	data.save_status_message = "Autosave failed. A diagnostic string is not state."
	_check(_save_icon(Hud.run_status_model(run, data)).get("icon") == "save", "healthy explicit state never inferred from message wording")

	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	_check(bool(app.call("start_foundation_run", "QOL-02-HOST", {}, true)), "normal host run starts")
	_check(bool(app.call("_autosave_foundation_run", "Baseline.", true)), "normal baseline saves")
	Store.set_debug_force_write_failure(true)
	_check(not bool(app.call("_autosave_foundation_run", "Blocked.", true)), "real synchronous storage failure is reported")
	model = app.call("_run_status_hud_model")
	var label: Label = app.get("message_label")
	observations.append({"case":"host_failure", "save_icon":_save_icon(model), "message":label.text, "blocked":app.get("autosave_retry_blocked")})
	_check(_save_icon(model).get("icon") == "danger" and str(_save_icon(model).get("tooltip", "")).begins_with("Not saving"), "host passes explicit failure field into HUD")
	_check(label.text.begins_with("Not saving"), "first blocked failure emits a nonmodal player message")
	var bar = app.get("structured_hud")
	var rendered: Array = bar.get("_status_details")
	_check(not rendered.is_empty() and rendered[0].get("id") == "save" and rendered[0].get("icon") == "danger", "background boundary publishes warning to actual rendered HUD immediately")
	var visible_icons := _live_icon_state(bar)
	observations.append({"case":"warning_visible_icons", "icons":visible_icons})
	_check(not visible_icons.is_empty() and visible_icons[0].id == "save" and str(visible_icons[0].tooltip).begins_with("Not saving"), "actual warning TextureRect exists visibly after replacement")
	var status_button: Button = bar.get("status_button")
	_check(status_button.tooltip_text.begins_with("Not saving"), "actual HUD hover target leads with save failure")
	var notice: Variant = bar.get("save_warning_notice")
	_check(is_instance_valid(notice) and notice.is_visible_in_tree() and str(notice.text).begins_with("Not saving"), "first blocked notice is actually visible on the HUD")
	_check(is_instance_valid(notice) and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE and notice.focus_mode == Control.FOCUS_NONE, "notice does not capture input or focus")
	if is_instance_valid(notice): notice.text = "Keep this newer notice."
	app.call("_show_message", "Keep this newer message.")
	app.call("_record_autosave_failure", ERR_CANT_CREATE, "repeated_fixture", int(app.get("autosave_dirty_generation")))
	_check(label.text == "Keep this newer message.", "repeated blocked failures do not spam player messages")
	app.call("_mark_autosave_dirty")
	_check(_save_icon(app.call("_run_status_hud_model")).get("icon") == "danger", "new dirty generation keeps warning until successful save")
	app.call("_record_autosave_failure", ERR_CANT_CREATE, "new_generation_fixture", int(app.get("autosave_dirty_generation")))
	_check(label.text == "Keep this newer message.", "new dirty generation does not repeat the blocked episode notice")
	_check(is_instance_valid(notice) and notice.text == "Keep this newer notice.", "repeated and newer-generation failures do not redisplay HUD notice")
	_check(not bool(app.get("leave_without_saving_confirmation").visible) and app.get("run_state") != null, "failure does not open a modal or interrupt play")
	Store.reset_debug_faults()
	_check(bool(app.call("_autosave_foundation_run", "Recovered.", true)), "healthy retry succeeds")
	model = app.call("_run_status_hud_model")
	rendered = bar.get("_status_details")
	observations.append({"case":"recovered", "save_icon":_save_icon(model), "rendered":rendered.duplicate(true)})
	_check(_save_icon(model).get("icon") == "save", "successful save clears warning model")
	_check(rendered.any(func(row): return row.get("id") == "save" and row.get("icon") == "save"), "successful save clears actual rendered warning")
	visible_icons = _live_icon_state(bar)
	observations.append({"case":"recovered_visible_icons", "icons":visible_icons})
	_check(visible_icons.any(func(row): return row.id == "save" and not str(row.tooltip).begins_with("Not saving")), "actual healthy TextureRect exists visibly after recovery")
	_check(not status_button.tooltip_text.begins_with("Not saving"), "actual HUD hover warning clears after successful save")
	_check(is_instance_valid(notice) and not notice.visible, "successful save clears visible notice immediately")
	Store.set_debug_force_write_failure(true)
	app.call("_autosave_foundation_run", "Blocked again.", true)
	_check(label.text.begins_with("Not saving"), "new blocked episode after success emits its first message")
	_check(is_instance_valid(notice) and notice.is_visible_in_tree() and str(notice.text).begins_with("Not saving"), "new blocked episode displays its HUD notice")
	Store.reset_debug_faults()
	app.call("_mark_autosave_dirty")
	_check(bool(app.call("_write_foundation_run_save", "Async recovery.", false)), "healthy asynchronous recovery starts actual worker")
	var service: SaveService = app.get("save_service")
	for _frame in range(240):
		await process_frame
		if not service.async_save_in_flight(): break
	model = app.call("_run_status_hud_model")
	rendered = bar.get("_status_details")
	observations.append({"case":"async_recovered", "save_icon":_save_icon(model), "rendered":rendered.duplicate(true), "in_flight":service.async_save_in_flight()})
	_check(not service.async_save_in_flight() and _save_icon(model).get("icon") == "save", "accepted async completion clears warning")
	_check(rendered.any(func(row): return row.get("id") == "save" and row.get("icon") == "save"), "async completion clears actual rendered warning")
	visible_icons = _live_icon_state(bar)
	observations.append({"case":"async_visible_icons", "icons":visible_icons})
	_check(visible_icons.any(func(row): return row.id == "save" and not str(row.tooltip).begins_with("Not saving")), "actual healthy TextureRect exists visibly after async recovery")
	app.queue_free()
	await process_frame
	print("QOL02_SAVE_WARNING " + JSON.stringify({"checks":checks, "failures":failures, "observations":observations}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("QOL-02: " + label)
