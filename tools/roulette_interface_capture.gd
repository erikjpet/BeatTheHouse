extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

const CAPTURE_DIR := "res://.tmp/roulette_interface_capture"
const CANVAS_SIZE := Vector2i(900, 430)
const CAPTURE_SIZE := Vector2i(1800, 860)

var failures: Array[String] = []
var captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	root.size = CAPTURE_SIZE
	DisplayServer.window_set_size(CAPTURE_SIZE)
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("ContentLibrary validation error: %s" % error)
	var game := _load_roulette(library)
	if game == null:
		_finish()
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ROULETTE-INTERFACE-CAPTURE")
	run_state.bankroll = 1000
	var environment := {
		"id": "grand_casino_capture_room",
		"display_name": "Grand Casino Capture",
		"depth": 4,
		"game_ids": ["roulette"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 200},
		"security_profile": {"strictness": "high"},
		"turns": 0,
	}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("roulette_capture_table"))
	environment["game_states"] = {"roulette": table}
	run_state.current_environment = environment.duplicate(true)

	var empty_surface := game.surface_state(run_state, environment, {})
	var empty_capture := _begin_surface_capture(game, empty_surface, "roulette_01_empty_table")
	await _finish_surface_capture(empty_capture, empty_surface, "roulette_01_empty_table", "Empty roulette table with wheel, dealer, patrons, and full betting grid.")

	var ready_ui := _place_capture_bets(game, run_state, environment, empty_surface)
	var ready_surface := game.surface_state(run_state, environment, ready_ui)
	var ready_capture := _begin_surface_capture(game, ready_surface, "roulette_02_bets_ready")
	await _finish_surface_capture(ready_capture, ready_surface, "roulette_02_bets_ready", "Multiple inside and outside bets placed; spin controls enabled.")

	var spin_command: Dictionary = game.surface_action_command("roulette_spin", 0, false, ready_ui, run_state, environment)
	if not bool(spin_command.get("resolve", false)):
		failures.append("Roulette spin command did not resolve for screenshot capture.")
		_finish()
		return
	var spin_result: Dictionary = game.resolve_with_context(
		"spin_roulette",
		int(spin_command.get("set_stake", 1)),
		run_state,
		environment,
		run_state.create_rng("roulette_capture_spin"),
		spin_command.get("ui_state", {})
	)
	if not bool(spin_result.get("ok", false)):
		failures.append("Roulette spin failed for screenshot capture: %s" % str(spin_result.get("message", "")))
		_finish()
		return
	var persisted_table: Dictionary = (environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary
	var last_result: Dictionary = persisted_table.get("last_result", {}) as Dictionary
	var resolved_at := int(last_result.get("resolved_at_msec", Time.get_ticks_msec()))
	var spinning_surface := game.surface_state(run_state, environment, {"surface_time_msec": resolved_at + 2400})
	var spinning_capture := _begin_surface_capture(game, spinning_surface, "roulette_03_spin_in_motion")
	await _finish_surface_capture(spinning_capture, spinning_surface, "roulette_03_spin_in_motion", "Resolved spin replaying through the precomputed ball trajectory.")
	var settled_surface := game.surface_state(run_state, environment, {"surface_time_msec": resolved_at + 7600})
	var settled_capture := _begin_surface_capture(game, settled_surface, "roulette_04_settled_result")
	await _finish_surface_capture(settled_capture, settled_surface, "roulette_04_settled_result", "Post-spin table with latest result and payout message.")
	_finish()


func _load_roulette(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("roulette")
	if definition.is_empty():
		failures.append("Roulette definition was not found.")
		return null
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Roulette module could not be loaded.")
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Roulette module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _place_capture_bets(game: GameModule, run_state: RunState, environment: Dictionary, surface: Dictionary) -> Dictionary:
	var ui: Dictionary = {}
	var targets: Array = surface.get("bet_targets", []) as Array
	var placements := [
		{"type": "straight", "number": "17", "chip": 5},
		{"type": "split", "number": "20", "chip": 5},
		{"type": "corner", "number": "14", "chip": 5},
		{"type": "top_line", "number": "0", "chip": 1},
		{"type": "red", "number": "", "chip": 10},
		{"type": "column", "number": "", "chip": 5},
		{"type": "dozen", "number": "", "chip": 5},
	]
	for placement_value in placements:
		var placement: Dictionary = placement_value
		var target_index := _target_index(targets, str(placement.get("type", "")), str(placement.get("number", "")))
		if target_index < 0:
			failures.append("Could not find roulette screenshot target %s %s." % [str(placement.get("type", "")), str(placement.get("number", ""))])
			continue
		ui["selected_chip"] = int(placement.get("chip", 1))
		var command: Dictionary = game.surface_action_command("roulette_bet", target_index, false, ui, run_state, environment)
		if not bool(command.get("handled", false)):
			failures.append("Could not place roulette screenshot bet %s: %s" % [str(placement.get("type", "")), str(command.get("message", ""))])
			continue
		ui = command.get("ui_state", {})
	return ui


func _target_index(targets: Array, target_type: String, number: String = "") -> int:
	for i in range(targets.size()):
		if typeof(targets[i]) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = targets[i]
		if str(target.get("type", "")) != target_type:
			continue
		if number.is_empty() or _string_array(target.get("numbers", [])).has(number):
			return i
	return -1


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(str(entry))
	return result


func _begin_surface_capture(game: GameModule, surface_state: Dictionary, stem: String) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "%s_viewport" % stem
	viewport.size = CAPTURE_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas: GameSurfaceCanvas = GameSurfaceCanvasScript.new()
	canvas.name = stem
	canvas.size = Vector2(CANVAS_SIZE)
	canvas.set_game_module(game)
	viewport.add_child(canvas)
	canvas.render_game_snapshot(surface_state)
	return {"viewport": viewport, "canvas": canvas}


func _finish_surface_capture(capture: Dictionary, surface_state: Dictionary, stem: String, description: String) -> void:
	var viewport: SubViewport = capture.get("viewport", null)
	var canvas: GameSurfaceCanvas = capture.get("canvas", null)
	if viewport == null or canvas == null:
		failures.append("Screenshot capture surface was not initialized for %s." % stem)
		return
	await process_frame
	await process_frame
	canvas.queue_redraw()
	await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		failures.append("Viewport texture was unavailable for screenshot %s." % stem)
		viewport.queue_free()
		await process_frame
		return
	var image := texture.get_image()
	if image == null:
		failures.append("Viewport image was unavailable for screenshot %s." % stem)
		viewport.queue_free()
		await process_frame
		return
	image = image.get_region(Rect2i(Vector2i.ZERO, CANVAS_SIZE))
	var res_path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var abs_path := ProjectSettings.globalize_path(res_path)
	var save_error := image.save_png(abs_path)
	if save_error != OK:
		failures.append("Failed to save screenshot %s: %s" % [abs_path, error_string(save_error)])
	else:
		captures.append({
			"name": stem,
			"path": abs_path,
			"description": description,
			"phase": str(surface_state.get("phase", "")),
			"total_wager": int(surface_state.get("total_wager_cost", 0)),
			"hit_regions": (canvas.current_view_snapshot().get("surface_hit_actions", []) as Array).size(),
			"winning_number": str((surface_state.get("last_result", {}) as Dictionary).get("winning_number", "")),
		})
	viewport.queue_free()
	await process_frame


func _finish() -> void:
	var report := {
		"tool": "roulette_interface_capture",
		"captures": captures,
		"failures": failures,
	}
	var report_path := ProjectSettings.globalize_path("%s/report.json" % CAPTURE_DIR)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
