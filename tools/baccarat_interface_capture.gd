extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

const CAPTURE_DIR := "res://.tmp/baccarat_interface_capture"
const CANVAS_SIZE := Vector2i(900, 430)
const CAPTURE_SIZE := Vector2i(1800, 860)

var failures: Array = []
var captures: Array = []
var animation_samples: Array = []
var interaction_report: Dictionary = {}


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
	var game := _load_baccarat(library)
	if game == null:
		_finish()
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("BACCARAT-INTERFACE-CAPTURE")
	run_state.bankroll = 1000
	var environment := {
		"id": "grand_casino_baccarat_capture_room",
		"display_name": "Grand Casino Baccarat Capture",
		"depth": 4,
		"game_ids": ["baccarat"],
		"economic_profile": {"stake_floor": 20, "stake_ceiling": 200},
		"security_profile": {"strictness": "boss"},
		"turns": 0,
	}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("baccarat_capture_table"))
	environment["game_states"] = {"baccarat": table}
	run_state.current_environment = environment.duplicate(true)

	var empty_surface := game.surface_state(run_state, environment, {})
	_capture_interaction_contract(empty_surface)
	var empty_capture := _begin_surface_capture(game, empty_surface, "baccarat_01_empty_table")
	await _finish_surface_capture(empty_capture, empty_surface, "baccarat_01_empty_table", "Empty baccarat table with croupier, patrons, shoe, discard tray, and all bet zones.")

	var ready_ui := _place_capture_bets(game, run_state, environment, empty_surface)
	var ready_surface := game.surface_state(run_state, environment, ready_ui)
	_capture_ready_contract(ready_surface)
	var ready_capture := _begin_surface_capture(game, ready_surface, "baccarat_02_bets_ready")
	await _finish_surface_capture(ready_capture, ready_surface, "baccarat_02_bets_ready", "Player, Tie, Player Pair, and Banker Pair chips placed; table controls enabled.")

	var deal_command: Dictionary = game.surface_action_command("baccarat_deal", 0, false, ready_ui, run_state, environment)
	if not bool(deal_command.get("resolve", false)):
		failures.append("Baccarat deal command did not request resolution for screenshot capture.")
		_finish()
		return
	var started_bankroll := run_state.bankroll
	var start_usec := Time.get_ticks_usec()
	var deal_result: Dictionary = game.resolve_with_context(
		"deal_baccarat",
		int(deal_command.get("set_stake", 1)),
		run_state,
		environment,
		run_state.create_rng("baccarat_capture_deal"),
		deal_command.get("ui_state", {})
	)
	var resolve_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
	if not bool(deal_result.get("ok", false)):
		failures.append("Baccarat deal failed for screenshot capture: %s" % str(deal_result.get("message", "")))
		_finish()
		return
	var persisted_table: Dictionary = (environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary
	var last_result: Dictionary = persisted_table.get("last_result", {}) as Dictionary
	var resolved_at := int(last_result.get("resolved_at_msec", Time.get_ticks_msec()))
	var dealing_surface := _surface_at_animation_offset(game, run_state, environment, resolved_at, 2100)
	var dealing_capture := _begin_surface_capture(game, dealing_surface, "baccarat_03_deal_in_motion")
	await _finish_surface_capture(dealing_capture, dealing_surface, "baccarat_03_deal_in_motion", "Resolved hand replaying through the baccarat card-deal animation.")
	var settled_surface := _surface_at_animation_offset(game, run_state, environment, resolved_at, 6200)
	var settled_capture := _begin_surface_capture(game, settled_surface, "baccarat_04_settled_result")
	await _finish_surface_capture(settled_capture, settled_surface, "baccarat_04_settled_result", "Settled baccarat result with visible totals, winner marker, and payout message.")
	await _sample_animation_sequence(game, run_state, environment, resolved_at)
	interaction_report["resolve_ms"] = resolve_ms
	interaction_report["bankroll_before"] = started_bankroll
	interaction_report["bankroll_after"] = run_state.bankroll
	interaction_report["bankroll_delta"] = run_state.bankroll - started_bankroll
	interaction_report["winner"] = str(deal_result.get("baccarat_winner", ""))
	interaction_report["total_wager"] = int(deal_result.get("baccarat_total_wager", 0))
	_finish()


func _load_baccarat(library: ContentLibrary) -> GameModule:
	var definition: Dictionary = library.game("baccarat")
	if definition.is_empty():
		failures.append("Baccarat definition was not found.")
		return null
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Baccarat module could not be loaded.")
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Baccarat module does not extend GameModule.")
		return null
	var game: GameModule = instance
	game.setup(definition, library)
	return game


func _capture_interaction_contract(surface: Dictionary) -> void:
	var targets: Array = surface.get("bet_targets", []) as Array
	interaction_report["surface_renderer"] = str(surface.get("surface_renderer", ""))
	interaction_report["surface_life"] = str(surface.get("surface_life", ""))
	interaction_report["surface_cast"] = str(surface.get("surface_cast", ""))
	interaction_report["bet_target_count"] = targets.size()
	interaction_report["bet_target_ids"] = _target_ids(targets)
	interaction_report["phase_empty"] = str(surface.get("phase", ""))
	interaction_report["can_deal_empty"] = bool(surface.get("can_deal", false))
	interaction_report["table_minimum"] = int(surface.get("table_minimum", 0))
	if str(surface.get("surface_renderer", "")) != "baccarat":
		failures.append("Baccarat surface did not advertise the baccarat renderer.")
	if str(surface.get("surface_life", "")) != "immersive_table":
		failures.append("Baccarat surface does not use the immersive table life-cycle.")
	if str(surface.get("surface_cast", "")) != "dealer_table":
		failures.append("Baccarat surface does not use dealer-table cast metadata.")
	for target_id in ["player", "banker", "tie", "player_pair", "banker_pair"]:
		if not _target_ids(targets).has(target_id):
			failures.append("Baccarat missing bet target %s." % target_id)
	if bool(surface.get("can_deal", false)):
		failures.append("Baccarat deal button was enabled before bets were placed.")


func _capture_ready_contract(surface: Dictionary) -> void:
	interaction_report["phase_ready"] = str(surface.get("phase", ""))
	interaction_report["can_deal_ready"] = bool(surface.get("can_deal", false))
	interaction_report["ready_total_wager"] = int(surface.get("total_wager_cost", 0))
	if not bool(surface.get("can_deal", false)):
		failures.append("Baccarat deal button was not enabled after legal capture bets.")


func _place_capture_bets(game: GameModule, run_state: RunState, environment: Dictionary, surface: Dictionary) -> Dictionary:
	var ui: Dictionary = {}
	var targets: Array = surface.get("bet_targets", []) as Array
	var placements := [
		{"id": "player", "chip": 20},
		{"id": "tie", "chip": 10},
		{"id": "player_pair", "chip": 10},
		{"id": "banker_pair", "chip": 10},
	]
	for placement_value in placements:
		var placement: Dictionary = placement_value
		var target_index := _target_index(targets, str(placement.get("id", "")))
		if target_index < 0:
			failures.append("Could not find baccarat screenshot target %s." % str(placement.get("id", "")))
			continue
		ui["selected_chip"] = int(placement.get("chip", 5))
		var command: Dictionary = game.surface_action_command("baccarat_bet", target_index, false, ui, run_state, environment)
		if not bool(command.get("handled", false)):
			failures.append("Could not place baccarat screenshot bet %s: %s" % [str(placement.get("id", "")), str(command.get("message", ""))])
			continue
		ui = command.get("ui_state", {})
	return ui


func _target_index(targets: Array, target_id: String) -> int:
	for i in range(targets.size()):
		if typeof(targets[i]) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = targets[i]
		if str(target.get("id", "")) == target_id:
			return i
	return -1


func _target_ids(targets: Array) -> Array:
	var ids := []
	for target_value in targets:
		if typeof(target_value) == TYPE_DICTIONARY:
			ids.append(str((target_value as Dictionary).get("id", "")))
	return ids


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
	var start_usec := Time.get_ticks_usec()
	await process_frame
	await process_frame
	canvas.queue_redraw()
	await process_frame
	var capture_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
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
	var image_stats := _image_stats(image)
	if float(image_stats.get("lit_ratio", 0.0)) < 0.04:
		failures.append("Screenshot %s appears too visually sparse or blank." % stem)
	var res_path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var abs_path := ProjectSettings.globalize_path(res_path)
	var save_error := image.save_png(abs_path)
	if save_error != OK:
		failures.append("Failed to save screenshot %s: %s" % [abs_path, error_string(save_error)])
	else:
		var view_snapshot: Dictionary = canvas.current_view_snapshot()
		captures.append({
			"name": stem,
			"path": abs_path,
			"description": description,
			"phase": str(surface_state.get("phase", "")),
			"total_wager": int(surface_state.get("total_wager_cost", 0)),
			"hit_regions": (view_snapshot.get("surface_hit_actions", []) as Array).size(),
			"animations": view_snapshot.get("surface_animations", {}),
			"capture_ms": capture_ms,
			"image_stats": image_stats,
			"winner": str((surface_state.get("last_result", {}) as Dictionary).get("winner", "")),
		})
	viewport.queue_free()
	await process_frame


func _sample_animation_sequence(game: GameModule, run_state: RunState, environment: Dictionary, resolved_at: int) -> void:
	var viewport := SubViewport.new()
	viewport.name = "baccarat_animation_sample_viewport"
	viewport.size = CANVAS_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas: GameSurfaceCanvas = GameSurfaceCanvasScript.new()
	canvas.name = "baccarat_animation_sample"
	canvas.size = Vector2(CANVAS_SIZE)
	canvas.set_game_module(game)
	viewport.add_child(canvas)
	var max_render_ms := 0.0
	var steady_max_render_ms := 0.0
	var cold_start_render_ms := 0.0
	var changed_hashes := {}
	var sample_index := 0
	for offset in [0, 420, 840, 1260, 1680, 2100, 2520, 2940, 3360, 3780, 4200, 5000, 5800]:
		var surface_state := _surface_at_animation_offset(game, run_state, environment, resolved_at, int(offset))
		var start_usec := Time.get_ticks_usec()
		canvas.render_game_snapshot(surface_state)
		await process_frame
		canvas.queue_redraw()
		await process_frame
		var render_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
		max_render_ms = maxf(max_render_ms, render_ms)
		if sample_index == 0:
			cold_start_render_ms = render_ms
		else:
			steady_max_render_ms = maxf(steady_max_render_ms, render_ms)
		var image_hash := ""
		var texture := viewport.get_texture()
		if texture != null:
			var image := texture.get_image()
			if image != null:
				image_hash = str(_image_stats(image.get_region(Rect2i(Vector2i.ZERO, CANVAS_SIZE))).get("sample_hash", ""))
				changed_hashes[image_hash] = true
		var snapshot: Dictionary = canvas.current_view_snapshot()
		var animations: Dictionary = snapshot.get("surface_animations", {})
		var deal_animation: Dictionary = animations.get("baccarat_deal", {}) if animations.has("baccarat_deal") else {}
		var payout_animation: Dictionary = animations.get("baccarat_payout", {}) if animations.has("baccarat_payout") else {}
		animation_samples.append({
			"offset_msec": int(offset),
			"phase": str(surface_state.get("phase", "")),
			"render_ms": render_ms,
			"deal_active": bool(deal_animation.get("active", false)),
			"deal_progress": float(deal_animation.get("progress", 0.0)),
			"payout_active": bool(payout_animation.get("active", false)),
			"payout_progress": float(payout_animation.get("progress", 0.0)),
			"image_hash": image_hash,
		})
		sample_index += 1
	interaction_report["animation_sample_count"] = animation_samples.size()
	interaction_report["animation_max_render_ms"] = max_render_ms
	interaction_report["animation_cold_start_render_ms"] = cold_start_render_ms
	interaction_report["animation_steady_max_render_ms"] = steady_max_render_ms
	interaction_report["animation_unique_frame_hashes"] = changed_hashes.size()
	if changed_hashes.size() < 5:
		failures.append("Baccarat deal animation did not produce enough distinct rendered frames.")
	if steady_max_render_ms > 50.0:
		failures.append("Baccarat steady animation sample exceeded 50 ms for a frame: %.2f ms." % steady_max_render_ms)
	viewport.queue_free()
	await process_frame


func _surface_at_animation_offset(game: GameModule, run_state: RunState, environment: Dictionary, resolved_at: int, offset_msec: int) -> Dictionary:
	var surface_state := game.surface_state(run_state, environment, {"surface_time_msec": resolved_at + offset_msec})
	var now_msec := Time.get_ticks_msec()
	var channels := surface_state.get("surface_animation_channels", []) as Array
	for i in range(channels.size()):
		if typeof(channels[i]) != TYPE_DICTIONARY:
			continue
		var channel: Dictionary = channels[i]
		var channel_id := str(channel.get("id", ""))
		if not bool(channel.get("active", false)):
			continue
		if channel_id == "baccarat_deal":
			channel["started_msec"] = now_msec - clampi(offset_msec, 0, 4200)
		elif channel_id == "baccarat_payout":
			channel["started_msec"] = now_msec - clampi(offset_msec - 4200, 0, 1600)
		channels[i] = channel
	surface_state["surface_animation_channels"] = channels
	return surface_state


func _image_stats(image: Image) -> Dictionary:
	var lit := 0
	var samples := 0
	var hash_value := 2166136261
	var step := 6
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			if color.a > 0.05 and luma > 0.08:
				lit += 1
			var bucket := int(clampf(luma, 0.0, 1.0) * 255.0)
			hash_value = int((hash_value ^ bucket) * 16777619) & 0x7fffffff
			samples += 1
	return {
		"samples": samples,
		"lit_samples": lit,
		"lit_ratio": float(lit) / float(maxi(1, samples)),
		"sample_hash": "%08x" % hash_value,
	}


func _finish() -> void:
	var report := {
		"tool": "baccarat_interface_capture",
		"captures": captures,
		"animation_samples": animation_samples,
		"interaction_report": interaction_report,
		"failures": failures,
	}
	var report_path := ProjectSettings.globalize_path("%s/report.json" % CAPTURE_DIR)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
