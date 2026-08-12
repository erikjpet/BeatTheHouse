extends SceneTree

# End-to-end guard for terminal report actions: only a failed tutorial replaces
# New Run with Restart Tutorial, and pressing it creates a fresh guided run.

const MainScene := preload("res://scenes/main.tscn")
const SAVE_SLOT := "tutorial_failure_restart_probe"

var app: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate()
	app.set("autosave_slot_id", SAVE_SLOT)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle(5)

	app.call("start_tutorial_run")
	await _settle(4)
	var tutorial: RunState = app.get("run_state")
	if tutorial == null or not tutorial.is_tutorial_run():
		_fail("Could not start the production tutorial run.")
		_finish()
		return
	var first_seed := tutorial.seed_text
	tutorial.fail_run(RunState.FAILURE_BANKROLL_ZERO, "Tutorial restart probe loss.")
	app.call("_route_failed_run_if_needed")
	app.call("_refresh")
	await _settle(3)
	var report: RunReportScreen = app.get("run_report_screen")
	if report == null or not report.visible:
		_fail("Tutorial loss did not display the run report.")
	elif report.new_run_button.text != "Restart Tutorial":
		_fail("Tutorial loss showed '%s' instead of Restart Tutorial." % report.new_run_button.text)
	elif report.new_run_button.tooltip_text.find("Restart the First Night tutorial") == -1:
		_fail("Tutorial restart button did not explain that the tutorial restarts from the beginning.")
	if report != null:
		report.new_run_button.pressed.emit()
	await _settle(5)
	var restarted: RunState = app.get("run_state")
	if restarted == null or not restarted.is_tutorial_run() or restarted.is_terminal():
		_fail("Pressing Restart Tutorial did not create a fresh, active tutorial run.")
	elif restarted.seed_text != first_seed:
		_fail("Restart Tutorial changed the authored tutorial seed.")

	app.call("start_foundation_run", "TUTORIAL-RESTART-NORMAL-LOSS")
	await _settle(4)
	var normal: RunState = app.get("run_state")
	if normal == null or normal.is_tutorial_run():
		_fail("Could not create the ordinary-run comparison fixture.")
	else:
		normal.fail_run(RunState.FAILURE_BANKROLL_ZERO, "Normal restart probe loss.")
		app.call("_route_failed_run_if_needed")
		app.call("_refresh")
		await _settle(3)
		report = app.get("run_report_screen")
		if report == null or report.new_run_button.text != "New Run":
			_fail("An ordinary failed run incorrectly received the tutorial restart action.")

	print("TUTORIAL_FAILURE_RESTART_PROBE %s" % JSON.stringify({
		"passed": failures.is_empty(),
		"failures": failures,
		"tutorial_button": "Restart Tutorial",
		"normal_button": report.new_run_button.text if report != null else "",
	}))
	_finish()


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish() -> void:
	quit(0 if failures.is_empty() else 1)
