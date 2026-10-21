extends SceneTree

# Focused synthetic model/view checks for the normal-UI finding. No player save,
# settlement/payment action, private draw, or authority record is changed by UI.
const Numbers := preload("res://scripts/core/numbers_model.gd")
const MainScene := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/core/user_settings.gd")

var failures: Array[String] = []
var cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	var model := Numbers.new()
	model.reset(731)
	_check(model.recent_slips_public().is_empty(), "Empty history stays empty")
	var bought := model.buy_slip("motel", "000", 1, "straight")
	_check(bool(bought.get("ok", false)), "Buy a normal synthetic slip")
	var before := JSON.stringify(model.snapshot())
	var history := model.recent_slips_public()
	_check(history.size() == 1, "One purchased receipt")
	if history.is_empty():
		_finish(null)
		return
	var expected_keys := ["digits", "draw", "payout", "play_type", "stake", "status", "venue_label"]
	var keys: Array = history[0].keys()
	keys.sort()
	_check(keys == expected_keys, "Closed player-safe fields only")
	_check(history[0]["digits"] == "000" and history[0]["stake"] == 1, "Own bet terms retained")
	_check(history[0]["status"] == "open" and history[0]["payout"] == 0, "Pending is not a loss or an early payout")
	_check(JSON.stringify(model.snapshot()) == before, "Reading does not mutate model, draw, clock or RNG")
	history[0]["digits"] = "999"
	history.append({"digits": "999"})
	_check(model.recent_slips_public()[0]["digits"] == "000", "Returned receipt and array are owned")
	# A malformed/private early result must not leak through the pending view.
	model.slips[0]["payout"] = 777
	model.slips[0]["winning_number"] = "913"
	model.slips[0]["detected"] = true
	_check(model.recent_slips_public()[0]["payout"] == 0, "Pending masks an early payout field")
	model.slips[0].erase("payout")
	model.slips[0].erase("winning_number")
	model.slips[0]["detected"] = false
	model.advance_to(model.settlement_action(0))
	history = model.recent_slips_public()
	_check(history[0]["status"] == "settled", "Canonical settlement is displayed")
	_check(history[0]["payout"] == int(model.slips[0].get("payout", 0)), "Displays only the model's already-settled payout")
	model.reset(733)
	model.buy_slip("motel", "123", 2, "box")
	model.confiscate_open_slips("focused test")
	_check(model.recent_slips_public()[0]["status"] == "confiscated", "Confiscation is distinct from pending/settled")
	model.reset(739)
	for index in range(4):
		model.buy_slip("motel", "%03d" % index, 1, "straight")
	model.advance_to(24)
	for index in range(4, 8):
		model.buy_slip("gas_station_casino", "%03d" % index, 1, "box")
	history = model.recent_slips_public()
	_check(history.size() == 6 and history[0]["digits"] == "007" and history[5]["digits"] == "002", "Newest six in receipt order")
	before = JSON.stringify(model.snapshot())
	OS.set_environment(Settings.SETTINGS_PATH_ENV, "user://numbers_history_settings.json")
	var settings := Settings.new()
	settings.reset()
	settings.save()
	root.size = Vector2i(1280, 720)
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle()
	app.call("_on_start_pressed")
	await _settle()
	var run_state: RunState = app.get("run_state")
	_check(run_state != null, "Isolated view host initialized")
	if run_state == null:
		_finish(app)
		return
	# Deliberately synthetic view fixture, not a room/save restoration claim.
	run_state.numbers_state = model
	run_state.current_environment["archetype_id"] = "gas_station_casino"
	run_state.bankroll = 64
	for viewport in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport
		app.size = Vector2(viewport)
		app.call("_open_numbers_surface", "book")
		await _settle()
		var choices: VBoxContainer = app.get("event_choice_popup_choices_list")
		var section: VBoxContainer = choices.get_node_or_null("NumbersSlipHistory")
		_check(section != null and section.get_child_count() == 7, "Six receipt rows and heading")
		var text := ""
		if section != null:
			for child in section.get_children():
				if child is Label:
					text += child.text + "\n"
		_check(text.contains("007 Box - $1 - Waiting for draw"), "Pending receipt visible")
		_check(text.contains("Settled: paid $"), "Settled amount visible, no second collection action")
		_check(choices.get_node_or_null("NumbersSlipForm") != null, "Existing new-bet form retained")
		var back: Button
		for child in choices.get_children():
			if child is Button and child.text == "Back":
				back = child
		var panel: Control = app.get("event_choice_popup_panel")
		var safe := Rect2(Vector2.ZERO, Vector2(viewport))
		_check(back != null and safe.encloses(back.get_global_rect()), "Back stays in viewport at " + str(viewport))
		_check(safe.encloses(panel.get_global_rect()), "History and form fit at " + str(viewport))
		_check(run_state.bankroll == 64 and JSON.stringify(model.snapshot()) == before, "Opening/reading pays nothing and mutates no model state")
		cases.append({"viewport": str(viewport), "rows": history.size(), "panel_height": panel.size.y})
	_finish(app)


func _settle() -> void:
	for _frame in range(5):
		await process_frame


func _finish(app: Control) -> void:
	var report := {"passed": failures.is_empty(), "failures": failures, "cases": cases, "scope": "Synthetic Numbers receipt projection and native modal geometry; no Web/save or new payout claim"}
	var report_path := OS.get_environment("BTH_NUMBERS_HISTORY_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("NUMBERS_SLIP_HISTORY " + ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		push_error(failure)
	if app != null:
		app.queue_free()
	quit(0 if failures.is_empty() else 1)
