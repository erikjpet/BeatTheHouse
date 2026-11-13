extends SceneTree
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	PackScript.invalidate()
	var pack = PackScript.cached_pack("gas_station_casino")
	_check(pack != null, "Enabled proof pack loads.")
	if pack == null:
		_finish()
		return
	_check(PackScript.cached_pack("gas_station_casino") == pack, "Same room reuses its validated resource.")
	_check(PackScript.cached_pack("bar") == null, "Unlisted room keeps the code source.")
	_check(PackScript.cached_pack("gas_station_casino") == pack, "Previous room remains cached.")
	var canvas: Control = CanvasScript.new()
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	canvas.call("render_environment_snapshot", {"archetype_id": "gas_station_casino", "interactable_objects": [], "reduce_motion": false})
	_check(canvas.get("environment_art_pack") == pack, "Room identity resolves the cached pack at snapshot publication.")
	_check(canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "2x textures use the existing nearest filter policy.")
	_check(bool(canvas.call("_environment_art_pack_active")), "Packed background is selected.")
	canvas.set("background_texture", pack.background)
	canvas.set("use_external_background", true)
	_check(not bool(canvas.call("_environment_art_pack_active")), "Explicit legacy external-background path retains precedence.")
	canvas.set("use_external_background", false)
	canvas.call("set_developer_slot_placement_mode", true)
	var start: Dictionary = canvas.call("current_view_snapshot")
	for index in range(24):
		await process_frame
	var end: Dictionary = canvas.call("current_view_snapshot")
	_check(float(end.get("scene_animation_time", 0.0)) > float(start.get("scene_animation_time", 0.0)), "Packed room clock advances with no pointer input and placement open.")
	_check(int(end.get("scene_idle_animation_redraw_count", 0)) > int(start.get("scene_idle_animation_redraw_count", 0)), "Packed room schedules autonomous redraws.")
	canvas.call("render_environment_snapshot", {"archetype_id": "small_underground_casino", "visual_context": {"art_key": "punchline_club"}, "interactable_objects": []})
	_check(canvas.get("environment_id") == "punchline_club" and canvas.get("environment_art_pack") == null, "Punchline resolves its layer art identity without borrowing another pack.")
	canvas.call("render_environment_snapshot", {"archetype_id": "bar", "interactable_objects": []})
	_check(canvas.get("environment_art_pack") == null, "Leaving a packed room clears the view's active pack.")
	_check(PackScript._cache.size() <= 2, "Cache retains no more than two room records.")
	PackScript._cache["gas_station_casino"] = null
	canvas.call("render_environment_snapshot", {"archetype_id": "gas_station_casino", "interactable_objects": []})
	_check(canvas.get("environment_art_pack") == null and canvas.is_processing(), "A rejected cached pack preserves the live code fallback.")
	canvas.queue_free()
	await process_frame
	PackScript.invalidate()
	_finish()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("ENVART_BACKGROUND_CONTRACT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
