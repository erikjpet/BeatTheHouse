extends SceneTree

const RunReportScreenScript := preload("res://scripts/ui/run_report_screen.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen: RunReportScreen = RunReportScreenScript.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	await process_frame

	var main_menu_requests: Array[bool] = []
	screen.main_menu_requested.connect(func() -> void: main_menu_requests.append(true))
	_check(screen.main_menu_button != null, "The run report must expose a Main Menu button.")
	_check(screen.main_menu_button.text == "Main Menu", "The run report Main Menu action must use an explicit label.")
	screen.main_menu_button.pressed.emit()
	_check(main_menu_requests.size() == 1, "Pressing Main Menu must emit its navigation request exactly once.")

	screen.set_report({
		"take_home_item_reward": {
			"visible": true,
			"pending": true,
			"choices": [{"id": "backpack", "display_name": "Backpack", "capacity": 5}],
		},
	})
	await process_frame
	var snapshot := screen.debug_layout_snapshot()
	_check(bool(snapshot.get("main_menu_disabled", false)), "Main Menu must remain locked while an earned reward still needs a selection.")

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("RUN_REPORT_MAIN_MENU_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
