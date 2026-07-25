extends SceneTree

const UIArtScript := preload("res://scripts/ui/ui_art.gd")
const SegmentedMeterScript := preload("res://scripts/ui/segmented_meter.gd")
const FoundationHudBarScript := preload("res://scripts/ui/foundation_hud_bar.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(UIArtScript.ICON_IDS.size() == 12, "HUD icon contract is incomplete.")
	_check(UIArtScript.PORTRAIT_IDS.size() == 6, "Portrait contract is incomplete.")
	_check(UIArtScript.ENVIRONMENT_TITLE_IDS.size() == 18, "Environment title contract is incomplete.")
	for path in UIArtScript.expected_runtime_paths():
		_check(ResourceLoader.exists(path), "Manifested runtime asset is missing: %s" % path)
	var missing_icon := UIArtScript.fallback_for_test("icon", "missing")
	var missing_title := UIArtScript.fallback_for_test("title", "missing")
	_check(missing_icon != null and missing_icon.get_size() == Vector2(64, 64), "Missing icon did not return its code fallback.")
	_check(missing_title != null and missing_title.get_size() == Vector2(384, 64), "Missing title did not return its code fallback.")

	var meter: SegmentedMeter = SegmentedMeterScript.new()
	root.add_child(meter)
	meter.configure("heat", 0.0)
	_check(str(meter.current_snapshot().get("band", "")) == "safe", "Heat 0 did not use the safe band.")
	meter.configure("heat", 35.0)
	_check(str(meter.current_snapshot().get("band", "")) == "warning", "Heat 35 did not use the warning band.")
	meter.configure("heat", 70.0)
	_check(str(meter.current_snapshot().get("band", "")) == "danger", "Heat 70 did not use the danger band.")
	meter.configure("drunk", 40.0, 20.0)
	var pending_snapshot := meter.current_snapshot()
	_check(bool(pending_snapshot.get("ghost_visible", false)), "Pending drink did not expose a ghost segment.")
	_check((pending_snapshot.get("ticks", []) as Array).size() == 2, "Threshold ticks are missing.")
	meter.queue_free()

	var hud: FoundationHudBar = FoundationHudBarScript.new()
	root.add_child(hud)
	await process_frame
	hud.render({
		"bankroll": 240,
		"bankroll_delta": 40,
		"show_chips": true,
		"chips": 17,
		"heat_level": 70,
		"drunk_level": 40,
		"pending_drunk_absorption": 20,
		"clock_display": "Night 2 · 11:40 PM",
		"clock_tooltip": "Closes soon.",
		"status_icons": [{"id": "debt", "icon": "debt", "tooltip": "Marker due"}],
	})
	var hud_snapshot := hud.current_snapshot()
	_check(str(hud_snapshot.get("wallet", "")) == "$240", "Structured HUD wallet does not use authoritative cash.")
	_check(bool(hud_snapshot.get("chips_visible", false)) and str(hud_snapshot.get("chips", "")) == "17", "Grand Casino chips are not conditionally visible.")
	_check(bool((hud_snapshot.get("drunk", {}) as Dictionary).get("ghost_visible", false)), "Structured HUD did not show pending drink.")
	_check(int(hud_snapshot.get("status_icon_count", 0)) == 1, "Structured HUD conditional icon tray is incorrect.")
	hud.call("_on_time_pressed")
	_check(bool(hud.current_snapshot().get("time_detail_visible", false)), "Time widget did not open its schedule detail.")
	hud.queue_free()

	if failures.is_empty():
		print("UI05_DESIGN_SYSTEM_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
