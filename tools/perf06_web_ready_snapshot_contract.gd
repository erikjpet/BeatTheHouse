extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app: Control = MainScene.instantiate()
	root.add_child(app)
	await process_frame

	# Native startup builds every stage synchronously. Clear the same nullable
	# fields that Web has not published when BTH_PERF_READY is emitted, then call
	# the public automation surface exactly at that boundary.
	app.set("EnvironmentInteractionViewModelScript", null)
	app.set("EnvironmentInteractionControllerScript", null)
	app.set("RunInventoryViewModelScript", null)
	app.set("RunJournalViewModelScript", null)
	app.set("run_ui_built", false)
	app.set("run_ui_build_stage", 0)

	var menu: Dictionary = app.call("current_start_menu_snapshot")
	_check(_rect_schema(menu.get("menu_panel_rect", {})), "start_menu_builtin_rect")
	var screen: Dictionary = app.call("current_screen_snapshot")
	_check(typeof(screen.get("start_menu", {})) == TYPE_DICTIONARY, "screen_snapshot_ready_safe")

	var inventory: Dictionary = app.call("current_run_inventory_snapshot")
	_check(not bool(inventory.get("available", true)), "inventory_unavailable")
	_check(bool(inventory.get("loading", false)), "inventory_loading")
	_check(inventory.get("items", null) == [], "inventory_stable_empty_items")
	_check(not bool(inventory.get("visible", true)), "inventory_hidden")

	var journal: Dictionary = app.call("current_run_journal_snapshot")
	_check(not bool(journal.get("available", true)), "journal_unavailable")
	_check(bool(journal.get("loading", false)), "journal_loading")
	_check(journal.get("entries", null) == [], "journal_stable_empty_entries")
	_check(int(journal.get("entry_count", -1)) == 0, "journal_stable_count")

	var spatial: Dictionary = app.call("current_spatial_interaction_snapshot")
	_check(not bool(spatial.get("available", true)), "spatial_unavailable")
	_check(bool(spatial.get("loading", false)), "spatial_loading")
	_check(spatial.get("objects", null) == [], "spatial_stable_empty_objects")
	_check(_rect_schema(spatial.get("camera_focus_rect", {})), "spatial_builtin_rect")
	_check(_point_schema(spatial.get("camera_focus_point", {})), "spatial_builtin_point")

	var direct_rect: Dictionary = app.call("_rect_to_dict", Rect2(1.5, 2.5, 3.5, 4.5))
	_check(direct_rect == {"x": 1.5, "y": 2.5, "w": 3.5, "h": 4.5}, "direct_builtin_rect_values")
	var direct_point: Dictionary = app.call("_vector2_to_dict", Vector2(6.5, 7.5))
	_check(direct_point == {"x": 6.5, "y": 7.5}, "direct_builtin_point_values")

	var report := {
		"tool": "perf06_web_ready_snapshot_contract",
		"schema": "perf06_web_ready_snapshot_contract_v1",
		"passed": failures.is_empty(),
		"checks": 17,
		"failures": failures,
	}
	print("PERF06_WEB_READY_SNAPSHOT_CONTRACT_%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(report)])
	quit(0 if failures.is_empty() else 1)


func _rect_schema(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY \
		and (value as Dictionary).has("x") \
		and (value as Dictionary).has("y") \
		and (value as Dictionary).has("w") \
		and (value as Dictionary).has("h")


func _point_schema(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY \
		and (value as Dictionary).has("x") \
		and (value as Dictionary).has("y")


func _check(condition: bool, id: String) -> void:
	if not condition:
		failures.append(id)
