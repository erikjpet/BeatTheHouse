extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")

# Exercise the normal new-run boundary with fresh disposable storage. Only
# autosave I/O is replaced; generation, publication and canvas projection run.
class Observer extends Host:
	var presentations: Array[Dictionary] = []
	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		return true
	func _render_environment_canvas_snapshot() -> void:
		super._render_environment_canvas_snapshot()
		if run_state != null and environment_canvas != null:
			presentations.append({
				"objects": room_catalog_snapshot().size(),
				"transits": environment_canvas.person_transit_ids.duplicate(),
			})

var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	var private_root := OS.get_environment("BTH_INITIAL_ROOM_ROOT").replace("\\", "/").trim_suffix("/")
	if private_root.is_empty() or not ProjectSettings.globalize_path("user://").replace("\\", "/").begins_with(private_root + "/"):
		push_error("BTH_INITIAL_ROOM_ROOT must contain this disposable user:// root")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var app := Observer.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	# Distinct seeds and a repeated seed exercise fresh startup and reuse of the
	# same canvas/visit identities. The modifier is the normal home selection.
	for seed_text in ["INITIAL-ROOM-ALLEY-A", "INITIAL-ROOM-ALLEY-B", "INITIAL-ROOM-ALLEY-B"]:
		app.presentations.clear()
		var started := app.start_foundation_run(seed_text, {"modifiers": {"home_archetype_id": "back_alley"}}, false)
		_check(started, "normal Back Alley run starts: " + seed_text)
		if not started:
			continue
		_check(str(app.run_state.current_environment.get("archetype_id", "")) == "back_alley", "selected Back Alley was generated")
		_check(not app.presentations.is_empty(), "new run rendered its room")
		for presentation in app.presentations:
			_check(int(presentation.objects) > 0, "first room never renders an empty/stale catalog")
			_check((presentation.transits as Array).is_empty(), "initial population never walks in or out")
		var canvas = app.environment_canvas
		var people := 0
		var records := {}
		for record in canvas.foundation_snapshot.get("interactable_objects", []):
			records[str(record.get("object_id", ""))] = record
		for object_data in canvas.foundation_scene_objects:
			_check(not bool(object_data.get("person_transit_active", false)), "generated object is settled: " + str(object_data.get("id", "")))
			var record: Dictionary = records.get(str(object_data.get("id", "")), {})
			_check(not record.is_empty(), "rendered object belongs to published room")
			if not record.is_empty():
				var assigned_rect: Rect2 = canvas._normalized_rect_from_record(record)
				_check((object_data.position as Vector2).is_equal_approx(assigned_rect.get_center()), "object starts at assigned location: " + str(object_data.id))
			if canvas._scene_object_represents_person(object_data):
				people += 1
		_check(people > 0, "Back Alley fixture includes actual people")
		_check(app.selected_object_id.is_empty() and canvas.selected_object_id.is_empty(), "new run clears host and canvas selection")
		_check(canvas.camera_zoom == canvas.target_camera_zoom and canvas.camera_offset == canvas.target_camera_offset, "new run snaps camera to cleared focus")
		var catalog_before := var_to_bytes(app.room_catalog_snapshot())
		var rng_before := app.run_state.rng_state
		app._refresh()
		_check(canvas.person_transit_ids.is_empty(), "repeat presentation does not create arrivals")
		_check(var_to_bytes(app.room_catalog_snapshot()) == catalog_before and app.run_state.rng_state == rng_before, "repeat presentation preserves catalog and RNG")
		cases.append({"seed": seed_text, "people": people, "presentations": app.presentations.duplicate(true)})
		# Retain a repeated object ID in the outgoing selection to catch stale
		# camera/inspection state when the same room is generated again.
		app.focus_interactable_object("travel:leave")
		_check(canvas.selected_object_id == "travel:leave", "outgoing room has real focus before next start")
	var destination := ""
	for choice in app._travel_choice_view_list():
		if bool(choice.get("enabled", true)):
			destination = str(choice.get("id", ""))
			break
	_check(not destination.is_empty(), "generated start has an ordinary enabled travel route")
	if not destination.is_empty():
		_check(app.select_travel_option(destination), "normal travel selection succeeds")
		_check(app.confirm_selected_travel(true), "normal later room entry succeeds")
		_check(app.run_state.current_world_node_id() == destination, "travel installs selected destination")
		_check(not app.environment_canvas.foundation_scene_objects.is_empty(), "later room retains its generated objects")
		_check(app.environment_canvas.person_transit_ids.is_empty(), "later room population remains settled on entry")
	app.queue_free()
	await process_frame
	print("INITIAL_ROOM_POPULATION_CHECK ", JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "scope": "Normal generated new-run host/canvas path; disposable state, autosave spy; no original player save or visual Web claim."}))
	quit(0 if failures.is_empty() else 1)
