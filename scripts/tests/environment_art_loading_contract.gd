extends SceneTree
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []
var observations: Array = []
var out_dir := ""
var canvas: Control


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	PackScript.invalidate()
	canvas = CanvasScript.new()
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	_show("gas_station_casino")
	_check(canvas.get("environment_art_pack") == null and canvas.get("environment_art_waiting"), "Cold publication uses live code while loading, without synchronously waiting for textures.")
	_check(await _wait("gas_station_casino"), "Gas completes its staged request.")
	_check(canvas.get("environment_art_pack") != null, "The visible canvas activates the ready pack.")
	var gas_weak: WeakRef = weakref(canvas.get("environment_art_pack"))
	PackScript.prefetch_pack("bar")
	_check(await _wait("bar"), "A second generated pack loads before arrival.")
	_check(canvas.get("environment_id") == "gas_station_casino" and canvas.get("environment_art_pack") != null, "Departure preload never replaces the source room.")
	_show("bar")
	_check(canvas.get("environment_art_pack") != null, "A prefetched arrival is immediately ready.")
	_check(PackScript.peek_pack("gas_station_casino") != null, "Previous room is retained alongside current.")
	PackScript.prefetch_pack("corner_store")
	_check(await _wait("corner_store"), "Third room preload completes within the two-set budget.")
	_check(PackScript.peek_pack("gas_station_casino") == null and gas_weak.get_ref() == null, "The departed previous pack has no cache or view reference.")
	_show("corner_store")
	_check(canvas.get("environment_art_pack") != null, "Third prefetched room activates without a load wait.")
	# Supersede a started request. Its terminal tokens must be drained before
	# admitting a different third texture set; the current room stays live.
	PackScript.prefetch_pack("gas_station_casino")
	await process_frame
	PackScript.advance_loading()
	PackScript.prefetch_pack("bar")
	_check(await _wait("bar"), "An abandoned preload is drained and its replacement progresses.")
	_check(PackScript.peek_pack("gas_station_casino") == null, "An abandoned pack cannot publish after retirement.")
	_show("bar")
	_check(canvas.get("environment_art_pack") != null, "Replacement arrival uses its own room pack.")
	# Only this generated fixture is edited; supplied Gas art is untouched.
	var manifest_path := "res://data/art/environments/bar.json"
	var original := FileAccess.get_file_as_bytes(manifest_path)
	var malformed: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	malformed["board_size"] = [899, 430]
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(malformed))
	file.close()
	PackScript.invalidate("bar")
	_show("bar")
	for frame in range(120):
		PackScript.advance_loading()
		await process_frame
		if not PackScript.is_loading("bar"):
			break
	_check(PackScript.peek_pack("bar") == null and PackScript.last_error.contains("board_size"), "An invalid async pack is rejected by the same compiler with its exact reason.")
	_check(canvas.get("environment_art_pack") == null and canvas.is_processing(), "Rejected async art preserves the live code renderer.")
	malformed = JSON.parse_string(original.get_string_from_utf8())
	malformed["background"]["texture"] = "missing.png"
	file = FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(malformed))
	file.close()
	PackScript.invalidate("bar")
	_show("bar")
	for frame in range(120):
		PackScript.advance_loading()
		await process_frame
		if not PackScript.is_loading("bar"):
			break
	_check(PackScript.peek_pack("bar") == null and PackScript.last_error.contains("missing.png"), "A missing async texture terminates with its exact path and live fallback.")
	file = FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	_show("corner_store")
	_check(canvas.get("environment_art_pack") != null, "Retained previous room remains available after a failed load.")
	var renderer_weak: WeakRef = weakref(canvas.get("environment_art_renderer"))
	canvas.hide()
	_check(canvas.get("environment_art_pack") == null and canvas.get("environment_art_renderer") == null and renderer_weak.get_ref() == null, "Hiding a view releases its pack and retained render target references.")
	_check(canvas.is_processing(), "Hidden-view cleanup never disables canvas processing.")
	canvas.show()
	await process_frame
	_check(canvas.get("environment_art_pack") != null, "Showing the view reacquires its cached pack autonomously.")
	canvas.call("set_developer_slot_placement_mode", true)
	var start: Dictionary = canvas.call("current_view_snapshot")
	for frame in range(24):
		await process_frame
	var end: Dictionary = canvas.call("current_view_snapshot")
	_check(float(end["scene_animation_time"]) > float(start["scene_animation_time"]) and int(end["scene_idle_animation_redraw_count"]) > int(start["scene_idle_animation_redraw_count"]), "Packed-room animation stays scheduled without input while placement is open.")
	var layer := {"archetype_id": "small_underground_casino", "visual_context": {"art_key": "punchline_back_room"}}
	var unchanged := layer.duplicate(true)
	PackScript.prefetch_snapshot(layer)
	_check(PackScript._prefetch_room == "punchline_back_room" and layer == unchanged, "Departure resolves Punchline layer identity without mutating the source snapshot.")
	PackScript.prefetch_snapshot({"archetype_id": "grand_casino_cage"})
	_check(PackScript._prefetch_room == "grand_casino_cage", "Grand Casino rooms retain their own preload identity.")
	canvas.free()
	PackScript.invalidate()
	for frame in range(30):
		PackScript.advance_loading()
		await process_frame
	_check(PackScript._cache.is_empty() and PackScript._pending.is_empty(), "Invalidation drains all owned terminal requests and retains no room textures.")
	if not out_dir.is_empty():
		file = FileAccess.open(out_dir.path_join("loading.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "observations": observations}, "\t"))
		file.close()
	for failure in failures:
		push_error(failure)
	print("ENVART_LOADING_CONTRACT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _show(room_id: String) -> void:
	canvas.call("render_environment_snapshot", {"archetype_id": room_id, "interactable_objects": [], "reduce_motion": false})


func _wait(room_id: String) -> bool:
	for frame in range(180):
		PackScript.advance_loading()
		_check(PackScript._cache.size() <= 2 and PackScript._texture_room_count() <= 2, "Every loading step stays within two cached/active texture sets.")
		observations.append({"target": room_id, "frame": frame, "cache_ids": PackScript._cache.keys(), "texture_sets": PackScript._texture_room_count(), "texture_memory_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)})
		await process_frame
		await RenderingServer.frame_post_draw
		if PackScript.peek_pack(room_id) != null:
			return true
	return false


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
