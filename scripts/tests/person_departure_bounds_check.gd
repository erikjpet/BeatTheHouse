extends SceneTree

# DEPARTING_OBSERVER_CLIP: renderer-only geometry regression. These synthetic
# records occupy shipped local Motel Stakeout slots; no scenario outcome, run,
# save, profile, command outcome or RNG is created or restored. Layout probes
# measure natural-model rectangles; paint probes record the real shared
# procedural painter's primitive bounds, not rasterized screenshot pixels.
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const TableVisuals := preload("res://scripts/games/table_game_visuals.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const Store := preload("res://scripts/core/developer_placement_store.gd")
const BOARD := Rect2(0.0, 0.0, 900.0, 430.0)
const OBSERVER_SIZE := Vector2(72.0, 80.0)
const OBSERVERS := {
	"scenario::motel_stakeout_north_observer": "scenario.local_standing_person_1",
	"scenario::motel_stakeout_south_observer": "scenario.local_standing_person_2",
}


class RecordingSurface:
	extends RefCounted

	var bounds := Rect2()
	var has_bounds := false
	var rectangles := 0
	var lines := 0
	var circles := 0

	func _include(rect: Rect2) -> void:
		if not rect.has_area():
			return
		bounds = bounds.merge(rect) if has_bounds else rect
		has_bounds = true

	func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
		if color.a <= 0.0:
			return
		rectangles += 1
		_include(rect if filled else rect.grow(maxf(1.0, width) * 0.5))

	func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
		if color.a <= 0.0:
			return
		lines += 1
		# Grow before testing area: horizontal/vertical center lines have no area.
		_include(Rect2(from.min(to), (to - from).abs()).grow(maxf(1.0, width) * 0.5))

	func draw_circle(center: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
		if color.a <= 0.0:
			return
		circles += 1
		var extent := absf(radius) + (0.0 if filled else maxf(1.0, width) * 0.5)
		_include(Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0))


var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _run() -> void:
	# Placement.surface_map also reads the optional authoring overlay. Require a
	# fresh explicit private path before calling it, so default user data is never
	# consulted and only the shipped project coordinates affect this regression.
	var private_path := OS.get_environment(Store.USER_PATH_ENV).strip_edges()
	var private_ready := not private_path.is_empty() and private_path.is_absolute_path()
	for suffix in ["", ".bak", ".tmp"]:
		private_ready = private_ready and not FileAccess.file_exists(private_path + suffix)
	if not _check(private_ready, "A fresh missing absolute BTH_DEVELOPER_PLACEMENT_PATH is required"):
		_finish()
		return
	if not _check(OS.get_environment(Store.PROJECT_PATH_ENV).is_empty(), "Use shipped project placement, with no BTH_PROJECT_PLACEMENT_PATH override"):
		_finish()
		return
	var surface := Placement.surface_map(_room([], false))
	var records: Array = []
	for object_id in OBSERVERS:
		var slot := _slot(surface, str(OBSERVERS[object_id]))
		var rect := _slot_rect(slot)
		if not _check(rect.size.is_equal_approx(OBSERVER_SIZE), str(object_id) + " retains the genuine shipped 72x80 standing footprint: " + JSON.stringify(slot)):
			_finish()
			return
		records.append(_record(str(object_id), "North observer" if str(object_id).contains("north") else "South observer", slot, "character"))
	var exit_slot := _slot(surface, "exit.door_curtain")
	if not _check(not exit_slot.is_empty(), "Shipped Motel Leave slot exists"):
		_finish()
		return
	var leave := _record("travel:leave", "Leave", exit_slot, "travel")
	for small_screen in [false, true]:
		for reduced_motion in [false, true]:
			_run_variant(records, leave, small_screen, reduced_motion)
	_finish()


func _run_variant(observers: Array, leave: Dictionary, small_screen: bool, reduced_motion: bool) -> void:
	var tag := ("small" if small_screen else "normal") + ("_reduced" if reduced_motion else "_animated")
	var canvas := Canvas.new()
	canvas.size = BOARD.size
	root.add_child(canvas)
	canvas.set_small_screen_mode(small_screen)
	var records := observers.duplicate(true)
	records.append(leave.duplicate(true))
	var before_room := _room(records, reduced_motion)
	var after_room := _room([leave.duplicate(true)], reduced_motion)
	var before_copy := before_room.duplicate(true)
	var after_copy := after_room.duplicate(true)
	# The first same-room snapshot establishes already-present people. Removing
	# them in the second snapshot invokes the real mid-visit departure machinery.
	canvas.render_environment_snapshot(before_room)
	_check(canvas.person_transit_ids.is_empty(), tag + " initial room has no arrival parade")
	var settled_sizes: Dictionary = {}
	var settled_positions: Dictionary = {}
	var leave_rect: Rect2 = canvas.call("_natural_model_rect_for_object", _object(canvas, "travel:leave"))
	for object_id in OBSERVERS:
		var object := _object(canvas, str(object_id))
		var rect: Rect2 = canvas.call("_natural_model_rect_for_object", object)
		var expected_size := Binder.expanded_rect(_slot_rect(_slot(Placement.surface_map(before_room), str(OBSERVERS[object_id])))).size if small_screen else OBSERVER_SIZE
		_check(rect.has_area() and rect.size.is_equal_approx(expected_size), tag + " " + str(object_id) + " starts at its full authored/expanded size")
		_check(_inside_board(rect), tag + " " + str(object_id) + " settled natural-model rect is in bounds")
		settled_sizes[object_id] = rect.size
		settled_positions[object_id] = rect.position
	canvas.render_environment_snapshot(after_room)
	var variant_facts := {"small_screen": small_screen, "reduce_motion": reduced_motion, "measurement": "natural_model_layout_rect_and_recorded_procedural_primitives_not_raster_pixels", "sample_count": 0, "durations": {}, "paint_probes": []}
	if reduced_motion:
		_check(canvas.person_transit_ids.is_empty(), tag + " reduced motion creates no walking targets")
		for object_id in OBSERVERS:
			_check(_object(canvas, str(object_id)).is_empty(), tag + " " + str(object_id) + " disappears immediately")
	else:
		_check(canvas.person_transit_ids.size() == OBSERVERS.size(), tag + " both removed observers start real departures")
		var times: Array[float] = [0.0]
		for index in range(1, 41):
			times.append(Canvas.PERSON_TRANSIT_MAX_DURATION_SEC * float(index) / 40.0)
		for object_id in OBSERVERS:
			var object := _object(canvas, str(object_id))
			_check(bool(object.get("person_transit_active", false)) and str(object.get("person_transit_kind", "")) == "departure", tag + " " + str(object_id) + " is a departure transient")
			var stage: Dictionary = object.get("actor_route_stage", {})
			var duration := float(stage.get("duration_sec", 0.0))
			_check(duration > 0.0 and duration <= Canvas.PERSON_TRANSIT_MAX_DURATION_SEC, tag + " " + str(object_id) + " has a bounded positive departure duration")
			variant_facts.durations[object_id] = duration
			# Include the final connector immediately before removal; uniform wall-
			# time samples alone can miss its short out-of-bounds interval.
			for fraction in [0.25, 0.5, 0.75, 0.99, 0.999999]:
				times.append(duration * fraction)
		times.sort()
		var first_escape: Dictionary = {}
		var moved: Dictionary = {}
		for elapsed in times:
			canvas.actor_route_time = elapsed
			canvas.call("_advance_person_transits")
			for object_id in OBSERVERS:
				var object := _object(canvas, str(object_id))
				if object.is_empty():
					_check(elapsed >= float(variant_facts.durations[object_id]), tag + " " + str(object_id) + " is not removed before its deadline")
					continue
				var rect: Rect2 = canvas.call("_natural_model_rect_for_object", object)
				var hit: Rect2 = canvas.call("_interaction_rect_for_object", object)
				variant_facts.sample_count += 1
				_check(elapsed < float(variant_facts.durations[object_id]), tag + " " + str(object_id) + " is removed at its own deadline")
				_check(rect.has_area() and rect.size.is_equal_approx(settled_sizes[object_id]), tag + " " + str(object_id) + " preserves full natural-model size at " + str(elapsed))
				_check(not bool(object.get("interactive", true)) and not hit.has_area(), tag + " " + str(object_id) + " cannot be clicked while departing at " + str(elapsed))
				if not rect.position.is_equal_approx(settled_positions[object_id]):
					moved[object_id] = true
				if not _inside_board(rect) and not first_escape.has(object_id):
					first_escape[object_id] = {"elapsed": elapsed, "rect": _rect_fact(rect)}
				if is_equal_approx(elapsed, float(variant_facts.durations[object_id]) * 0.999999):
					variant_facts.paint_probes.append(_record_paint_bounds(canvas, object, rect, tag))
		for object_id in OBSERVERS:
			_check(not first_escape.has(object_id), tag + " " + str(object_id) + " natural-model layout bounds stay inside 900x430 throughout sampled departure: " + JSON.stringify(first_escape.get(object_id, {})))
			_check(bool(moved.get(object_id, false)), tag + " " + str(object_id) + " actually moves before disappearing")
		variant_facts.first_escape = first_escape
	canvas.actor_route_time = Canvas.PERSON_TRANSIT_MAX_DURATION_SEC + 0.001
	canvas.call("_advance_person_transits")
	_check(canvas.person_transit_ids.is_empty(), tag + " no departure survives the maximum eight-second presentation deadline")
	for object_id in OBSERVERS:
		_check(_object(canvas, str(object_id)).is_empty(), tag + " " + str(object_id) + " is absent after the deadline")
	var final_leave := _object(canvas, "travel:leave")
	var final_leave_rect: Rect2 = canvas.call("_natural_model_rect_for_object", final_leave)
	var final_leave_hit: Rect2 = canvas.call("_interaction_rect_for_object", final_leave)
	_check(not final_leave.is_empty() and bool(final_leave.get("interactive", false)) and final_leave_hit.has_area(), tag + " ordinary Leave remains present and interactive")
	_check(final_leave_rect.is_equal_approx(leave_rect), tag + " ordinary Leave geometry remains unchanged")
	_check(before_room == before_copy and after_room == after_copy, tag + " rendering preserves both caller-owned input snapshots")
	facts[tag] = variant_facts
	canvas.free()


func _room(records: Array, reduced_motion: bool) -> Dictionary:
	return {"id": "motel_vis020", "archetype_id": "motel", "world_node_id": "motel", "scenario_id": "motel_stakeout", "scenario_state": {"id": "motel_stakeout"}, "environment_visit_id": "departure_bounds_same_visit", "interactable_objects": records, "reduce_motion": reduced_motion}


func _record(object_id: String, label: String, slot: Dictionary, visual_type: String) -> Dictionary:
	var rect := _slot_rect(slot)
	var record := {"object_id": object_id, "object_type": "character" if visual_type == "character" else "travel", "visual_type": visual_type, "label": label, "visible": true, "interactive": true, "enabled": true, "placement_class": "standing_person" if visual_type == "character" else "doorway", "slot_id": str(slot.get("id", "")), "slot_family": str(slot.get("kind", "")), "fixed_slot_geometry": true, "scenario_layout_resolved": true, "normalized_rect": Binder.normalized_rect(rect), "small_screen_rect": Binder.normalized_rect(Binder.expanded_rect(rect))}
	if visual_type == "character":
		record["character_actor"] = {"portrait_count": 1, "role": "watcher", "members": [{"id": object_id, "role": "watcher", "model": {"scale": 1.25, "silhouette": "coat"}}]}
	return record


func _record_paint_bounds(canvas: PixelSceneCanvas, object: Dictionary, rect: Rect2, tag: String) -> Dictionary:
	var object_id := str(object.get("id", ""))
	var actor: Dictionary = object.get("character_actor", {})
	var members: Array = actor.get("members", [])
	if not _check(members.size() == 1, tag + " " + object_id + " paint probe uses the actual single-member fixture actor"):
		return {}
	var member: Dictionary = members[0]
	var scales: Array = canvas.call("_character_actor_member_scales", rect, object, actor)
	if not _check(scales.size() == 1 and is_equal_approx(float(scales[0]), 0.7992), tag + " " + object_id + " real scale helper reaches maximum single-member scale 0.7992 from model scale 1.25"):
		return {}
	var combined := Rect2()
	var probe_count := 0
	var primitive_count := 0
	for pose in ["idle", "stretch", "head_scratch", "shoulder_roll"]:
		for side in [-1, 1]:
			# The real idle helper supplies gesture/head offsets at full gesture.
			# Sway/bob extrema are separate sampled foot offsets, added once as in
			# Canvas._draw_character_actor_member; the style disables painter sway.
			var profile := {"gesture_segment_duration": 2.0, "gesture_events": [{"pose": pose, "side": side, "start": 0.0, "duration": 2.0}]}
			var idle: Dictionary = canvas.call("_character_idle_state", profile, 1.0)
			for sway in [-3.30, 3.30]:
				for bob in [-1.52, 1.52]:
					idle["sway"] = sway
					idle["bob"] = bob
					var style: Dictionary = canvas.call("_character_actor_style", member, actor, false, idle)
					var foot := Vector2(rect.get_center().x, rect.end.y - 2.0) + Vector2(sway, bob)
					var recording := RecordingSurface.new()
					TableVisuals._draw_table_character(recording, style, foot, float(scales[0]), 1.0)
					var detail := tag + " " + object_id + " " + str(pose) + " side=" + str(side) + " sway=" + str(sway) + " bob=" + str(bob)
					_check(recording.has_bounds and recording.rectangles > 0 and recording.lines > 0, detail + " records real body and arm primitives")
					_check(_inside_board(recording.bounds), detail + " procedural paint bounds stay inside the board: " + JSON.stringify(_rect_fact(recording.bounds)))
					combined = recording.bounds if probe_count == 0 else combined.merge(recording.bounds)
					probe_count += 1
					primitive_count += recording.rectangles + recording.lines + recording.circles
	# Canvas's independent feet-shadow glow reaches five units below rect.end.y.
	# This is an explicit geometry contract, separate from the recorded body.
	_check(_inside_board(Rect2(rect.position, rect.size + Vector2(0.0, 5.0))), tag + " " + object_id + " retains board space for the feet-shadow/glow extent")
	return {"id": object_id, "pose_samples": probe_count, "primitive_count": primitive_count, "draw_scale": scales[0], "paint_bounds": _rect_fact(combined), "measurement": "real_procedural_draw_primitive_extents_including_line_width_not_rasterization_or_adornments"}


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


func _inside_board(rect: Rect2) -> bool:
	return rect.has_area() and BOARD.grow(0.0001).encloses(rect)


func _rect_fact(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


func _finish() -> void:
	print("PERSON_DEPARTURE_BOUNDS_FACTS ", JSON.stringify(facts))
	if failures.is_empty():
		print("PERSON_DEPARTURE_BOUNDS_CHECK PASS checks=", checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PERSON_DEPARTURE_BOUNDS_CHECK FAIL checks=", checks, " failures=", failures.size())
	quit(1)
