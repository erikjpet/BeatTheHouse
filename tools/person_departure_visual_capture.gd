extends SceneTree

# Optional native raster evidence for DEPARTING_OBSERVER_CLIP. Run windowed:
# godot --path . --position -32000,-32000 --script res://tools/person_departure_visual_capture.gd
# Requires a fresh absolute BTH_DEVELOPER_PLACEMENT_PATH and an absolute
# BTH_DEPARTURE_CAPTURE_DIR. Existing output directories are allowed; existing
# PNG/manifest targets are never overwritten. No run, save or profile is loaded.
#
# This is a synthetic, explicitly sampled presentation capture, not ordinary
# player input, real-time departure timing or no-input animation qualification.
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const Store := preload("res://scripts/core/developer_placement_store.gd")
const OBSERVERS := {
	"scenario::motel_stakeout_north_observer": "scenario.local_standing_person_1",
	"scenario::motel_stakeout_south_observer": "scenario.local_standing_person_2",
}
const CAPTURE_SIZES := [Vector2i(1280, 720), Vector2i(640, 480)]
const SAMPLES := ["south", "north"]
const MANIFEST_NAME := "person_departure_visual_capture.json"


class SampledCanvas:
	extends "res://scripts/ui/pixel_scene_canvas.gd"

	var sampled_elapsed := 0.0

	func _process(_delta: float) -> void:
		# Keep the production process callback enabled, but deliberately supply
		# sampled presentation time. A slow offscreen frame must not accidentally
		# remove the target before its near-deadline image is drawn. Production
		# animation liveness and real elapsed timing are checked separately.
		actor_route_time = sampled_elapsed
		flicker = sampled_elapsed
		super._process(0.0)
		queue_redraw()


var output_dir := ""
var failures: Array[String] = []
var captures: Array = []


func _initialize() -> void:
	# The launch flag also places the initial window offscreen before this code
	# runs; retain that position while switching viewport sizes.
	root.position = Vector2i(-32000, -32000)
	call_deferred("_run")


func _require(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error(message)
	return ok


func _run() -> void:
	if not _preflight():
		_finish()
		return
	var surface := Placement.surface_map(_room([]))
	var observers: Array = []
	for object_id in OBSERVERS:
		var slot := _slot(surface, str(OBSERVERS[object_id]))
		if not _require(_slot_rect(slot).size.is_equal_approx(Vector2(72.0, 80.0)), "Expected shipped 72x80 observer slot: " + str(object_id)):
			_finish()
			return
		var label := "North observer" if str(object_id).contains("north") else "South observer"
		observers.append(_record(str(object_id), label, slot, true))
	var leave_slot := _slot(surface, "exit.door_curtain")
	if not _require(not leave_slot.is_empty(), "Shipped Motel Leave slot is missing"):
		_finish()
		return
	var leave := _record("travel:leave", "Leave", leave_slot, false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for capture_size in CAPTURE_SIZES:
		root.size = capture_size
		root.position = Vector2i(-32000, -32000)
		for small_screen in [false, true]:
			if not await _capture_variant(observers, leave, capture_size, small_screen):
				_finish()
				return
	_write_manifest()
	_finish()


func _preflight() -> bool:
	var private_path := OS.get_environment(Store.USER_PATH_ENV).strip_edges()
	var private_ready := not private_path.is_empty() and private_path.is_absolute_path()
	for suffix in ["", ".bak", ".tmp"]:
		private_ready = private_ready and not FileAccess.file_exists(private_path + suffix) and not DirAccess.dir_exists_absolute(private_path + suffix)
	if not _require(private_ready, "A fresh missing absolute BTH_DEVELOPER_PLACEMENT_PATH is required"):
		return false
	if not _require(OS.get_environment(Store.PROJECT_PATH_ENV).is_empty(), "Use shipped placement without BTH_PROJECT_PLACEMENT_PATH"):
		return false
	if not _require(DisplayServer.get_name() != "headless", "Native raster capture requires a windowed rendering backend"):
		return false
	output_dir = OS.get_environment("BTH_DEPARTURE_CAPTURE_DIR").strip_edges()
	if not _require(not output_dir.is_empty() and output_dir.is_absolute_path(), "An absolute BTH_DEPARTURE_CAPTURE_DIR is required"):
		return false
	output_dir = output_dir.simplify_path()
	if not _require(not FileAccess.file_exists(output_dir), "Capture output must be a directory"):
		return false
	var targets: Array[String] = [MANIFEST_NAME]
	for capture_size in CAPTURE_SIZES:
		for small_screen in [false, true]:
			for sample in SAMPLES:
				targets.append(_file_name(capture_size, small_screen, sample))
	for target in targets:
		if not _require(_target_missing(target), "Refusing to overwrite capture target: " + output_dir.path_join(target)):
			return false
	return _require(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "Could not create capture directory: " + output_dir)


func _capture_variant(observers: Array, leave: Dictionary, capture_size: Vector2i, small_screen: bool) -> bool:
	var canvas := SampledCanvas.new()
	canvas.size = Vector2(capture_size)
	root.add_child(canvas)
	canvas.set_small_screen_mode(small_screen)
	var records := observers.duplicate(true)
	records.append(leave.duplicate(true))
	canvas.render_environment_snapshot(_room(records))
	canvas.render_environment_snapshot(_room([leave.duplicate(true)]))
	if not _require(canvas.person_transit_ids.size() == OBSERVERS.size() and canvas.is_processing(), "Both synthetic observers must have active departures with processing enabled"):
		canvas.free()
		return false
	for sample in SAMPLES:
		var object_id: String = "scenario::motel_stakeout_" + str(sample) + "_observer"
		var transit: Dictionary = canvas.person_transits.get(object_id, {})
		var deadline := float(transit.get("ends_at", 0.0))
		if not _require(deadline > 0.01, "Departure deadline missing for " + object_id):
			canvas.free()
			return false
		canvas.sampled_elapsed = deadline - 0.01
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if not _require(not _object(canvas, object_id).is_empty() and canvas.is_processing(), "Sampled target must remain visible and processing at its own near-end"):
			canvas.free()
			return false
		var image := root.get_texture().get_image()
		if not _require(image != null and not image.is_empty() and image.get_size() == capture_size, "Viewport raster must match requested size without image resizing"):
			canvas.free()
			return false
		var file_name := _file_name(capture_size, small_screen, sample)
		if not _require(_target_missing(file_name), "Refusing to overwrite " + file_name):
			canvas.free()
			return false
		if not _require(image.save_png(output_dir.path_join(file_name)) == OK, "Could not save " + file_name):
			canvas.free()
			return false
		var objects: Array = []
		for visible_id in OBSERVERS:
			var object := _object(canvas, str(visible_id))
			if object.is_empty():
				continue
			var rect: Rect2 = canvas.call("_natural_model_rect_for_object", object)
			var route_position: Vector2 = canvas.call("_actor_route_position", object)
			objects.append({"id": visible_id, "natural_model_rect": _rect_fact(rect), "route_position": {"x": route_position.x, "y": route_position.y}, "interactive": object.get("interactive", true)})
		var board_rect: Rect2 = canvas.call("_board_screen_rect", canvas.camera_offset, canvas.camera_zoom)
		captures.append({"file": file_name, "width": capture_size.x, "height": capture_size.y, "small_screen": small_screen, "target": object_id, "sampled_presentation_seconds": canvas.sampled_elapsed, "target_deadline_seconds": deadline, "seconds_before_target_deadline": 0.01, "processing_enabled": canvas.is_processing(), "board_viewport_rect": _rect_fact(board_rect), "visible_observers": objects})
	canvas.free()
	return true


func _room(records: Array) -> Dictionary:
	return {"id": "motel_vis020", "archetype_id": "motel", "world_node_id": "motel", "scenario_id": "motel_stakeout", "scenario_state": {"id": "motel_stakeout"}, "environment_visit_id": "departure_bounds_same_visit", "interactable_objects": records, "reduce_motion": false}


func _record(object_id: String, label: String, slot: Dictionary, person: bool) -> Dictionary:
	var rect := _slot_rect(slot)
	var visual_type := "character" if person else "travel"
	var result := {"object_id": object_id, "object_type": visual_type, "visual_type": visual_type, "label": label, "visible": true, "interactive": true, "enabled": true, "placement_class": "standing_person" if person else "doorway", "slot_id": str(slot.get("id", "")), "slot_family": str(slot.get("kind", "")), "fixed_slot_geometry": true, "scenario_layout_resolved": true, "normalized_rect": Binder.normalized_rect(rect), "small_screen_rect": Binder.normalized_rect(Binder.expanded_rect(rect))}
	if person:
		result["character_actor"] = {"role": "watcher", "pose": "watching", "portrait_count": 1, "members": [{"id": object_id, "role": "watcher", "pose": "watching", "model": {"scale": 1.25, "silhouette": "coat"}}]}
	return result


func _slot(surface: Dictionary, slot_id: String) -> Dictionary:
	for value in Placement.all_slots(surface):
		if str(value.get("id", "")) == slot_id:
			return value
	return {}


func _slot_rect(slot: Dictionary) -> Rect2:
	return Binder.rect_from_binding({"slot": slot})


func _object(canvas: PixelSceneCanvas, object_id: String) -> Dictionary:
	for value in canvas.foundation_scene_objects:
		if str(value.get("id", "")) == object_id:
			return value
	return {}


func _file_name(capture_size: Vector2i, small_screen: bool, sample: String) -> String:
	return "%dx%d_%s_%s_near_end.png" % [capture_size.x, capture_size.y, "small" if small_screen else "normal", sample]


func _target_missing(file_name: String) -> bool:
	var path := output_dir.path_join(file_name)
	return not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path)


func _rect_fact(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


func _write_manifest() -> void:
	if not _require(_target_missing(MANIFEST_NAME), "Refusing to overwrite capture manifest"):
		return
	var file := FileAccess.open(output_dir.path_join(MANIFEST_NAME), FileAccess.WRITE)
	if not _require(file != null, "Could not write capture manifest"):
		return
	file.store_string(JSON.stringify({"task_id": "DEPARTING_OBSERVER_CLIP", "engine": Engine.get_version_info(), "source_sha_operator_supplied": OS.get_environment("BTH_DEPARTURE_SOURCE_SHA"), "fidelity": "Native viewport PNGs of synthetic shipped Motel observer slots with max-scale single coat character actors. No original save, scenario action, game state, economy or RNG. Fixture subclass keeps processing enabled but samples presentation time via super._process(0.0); these images are not ordinary-input, real-time deadline or no-input animation evidence. South and North are sampled 0.01 presentation seconds before their respective deadlines; South may be absent at the later North sample.", "captures": captures}, "\t"))
	_require(file.get_error() == OK, "Could not finish writing capture manifest")
	file.close()


func _finish() -> void:
	print("PERSON_DEPARTURE_VISUAL_CAPTURE ", "PASS" if failures.is_empty() else "FAIL", " captures=", captures.size(), " failures=", failures.size(), " dir=", output_dir)
	quit(0 if failures.is_empty() else 1)
