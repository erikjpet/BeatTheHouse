extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const DESIGN_SIZE := Vector2(900, 430)

var failures: Array[String] = []
var checks: Array[Dictionary] = []
var observations: Dictionary = {}
var report_path := ""
var artifact_dir := ""
var source_head := ""
var source_tree := ""
var build_identity := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_args()
	if report_path.is_empty() or source_head.is_empty() or source_tree.is_empty() or build_identity.is_empty():
		failures.append("required_identity_arguments")
		_finish()
		return
	var absolute_report := ProjectSettings.globalize_path(report_path)
	if FileAccess.file_exists(absolute_report):
		failures.append("refuse_report_overwrite")
		print("COIN_PUSHER_STATIC_CACHE_CONTRACT_REFUSED existing_report=%s" % absolute_report)
		quit(2)
		return
	artifact_dir = report_path.get_base_dir().path_join("pixel_pairs")
	root.size = Vector2i(1280, 720)
	var app: Control = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "fix06_13_static_cache_contract")
	root.add_child(app)
	await _frames(4)
	app.call("start_game_test_session", "coin_pusher")
	await _frames(10)
	app.set_process(false)
	var game: GameModule = app.get("current_game") as GameModule
	var production_canvas: Control = app.get("game_surface_canvas") as Control
	_check(game != null and production_canvas != null, "production_surface_opened")
	if game == null or production_canvas == null:
		_finish()
		return
	var renderer: RefCounted = game.get("_renderer") as RefCounted
	_check(renderer != null and renderer.has_method("debug_static_cache_for_test"), "production_renderer_debug_contract")
	if renderer == null or not renderer.has_method("debug_static_cache_for_test"):
		_finish()
		return
	var command_equivalence: Dictionary = renderer.call("debug_static_cache_command_equivalence_for_test")
	observations["command_equivalence"] = command_equivalence
	_check(bool(command_equivalence.get("exact_order_match", false)), "expanded_command_order_exact")
	_check(command_equivalence.get("live_commands", []) == ["platform", "bodies", "apron", "glass", "hardware"], "dynamic_commands_remain_live")
	# Desktop evidence opts into the shipped-Web cache while retaining the exact
	# production game module, surface state, canvas and draw dispatch.
	production_canvas.call("apply_surface_state_patch", {"coin_pusher_static_cache_test": true})
	production_canvas.queue_redraw()
	await _frames(4)
	observations["production_board_rect"] = production_canvas.call("board_rect")
	var initial := _cache_state(renderer)
	observations["initial"] = initial
	_check(bool(initial.get("active", false)), "production_cache_active")
	_check(int(initial.get("viewport_count", 0)) == 4, "production_cache_layer_count")
	_check(int(initial.get("host_instance_id", 0)) == production_canvas.get_instance_id(), "production_cache_host")
	_check(int(initial.get("viewport_parent_instance_id", 0)) == production_canvas.get_instance_id(), "production_cache_parent")

	var snapshot: Dictionary = production_canvas.call("realtime_surface_state")
	var expected_backglass_protected_rects: Array = renderer.call("debug_static_cache_text_protected_rects_for_test", 3)
	var live_protected_rects: Array = production_canvas.get("surface_text_protected_rects")
	_check(not expected_backglass_protected_rects.is_empty(), "backglass_fixture_contains_readable_text")
	_check(live_protected_rects.size() >= expected_backglass_protected_rects.size(), "cached_backglass_live_readability_count")
	for rect_index in range(expected_backglass_protected_rects.size()):
		_check(rect_index < live_protected_rects.size() and live_protected_rects[rect_index] == expected_backglass_protected_rects[rect_index], "cached_backglass_registers_live_readability_rect_%d" % rect_index)
	observations["cached_backglass_readability"] = {
		"expected_rects": expected_backglass_protected_rects,
		"live_rect_count": live_protected_rects.size(),
	}
	var backglass_signature := str(renderer.call("debug_backglass_cache_signature_for_test", snapshot))
	var backglass_dynamic_mutations := {
		"presentation_serial": {"coin_pusher_presentation_view_serial": int(snapshot.get("coin_pusher_presentation_view_serial", 0)) + 1},
		"platform_face": {"coin_pusher_face_position_y": int(snapshot.get("coin_pusher_face_position_y", 0)) + 1},
		"carriage": {"coin_pusher_carriage_x": int(snapshot.get("coin_pusher_carriage_x", 0)) + 1},
		"tray": {"coin_pusher_tray_count": int(snapshot.get("coin_pusher_tray_count", 0)) + 1},
	}
	for mutation_id in backglass_dynamic_mutations:
		var mutated := snapshot.duplicate(true)
		mutated.merge(backglass_dynamic_mutations[mutation_id], true)
		_check(str(renderer.call("debug_backglass_cache_signature_for_test", mutated)) == backglass_signature, "backglass_cache_ignores_%s" % mutation_id)
	var goal: Dictionary = (snapshot.get("coin_pusher_goal", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("coin_pusher_goal", {})) == TYPE_DICTIONARY else {}
	for field_name in ["id", "title", "instruction", "target", "progress", "bonus_tokens", "active"]:
		var mutated := snapshot.duplicate(true)
		var mutated_goal := goal.duplicate(true)
		match field_name:
			"id", "title", "instruction":
				mutated_goal[field_name] = str(mutated_goal.get(field_name, "")) + ":changed"
			"active":
				mutated_goal[field_name] = not bool(mutated_goal.get(field_name, false))
			"progress":
				mutated_goal[field_name] = 0 if int(mutated_goal.get(field_name, 0)) > 0 else maxi(1, int(mutated_goal.get("target", 1)))
			_:
				mutated_goal[field_name] = int(mutated_goal.get(field_name, 0)) + 1
		mutated["coin_pusher_goal"] = mutated_goal
		_check(str(renderer.call("debug_backglass_cache_signature_for_test", mutated)) != backglass_signature, "backglass_cache_invalidates_goal_%s" % field_name)
	var display_state := snapshot.duplicate(true)
	display_state["coin_pusher_goal"] = {}
	var display_cabinet: Dictionary = (snapshot.get("coin_pusher_cabinet", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("coin_pusher_cabinet", {})) == TYPE_DICTIONARY else {}
	display_cabinet["backglass_display"] = {"style": "dual_value_dial", "primary_state_key": "contract_primary", "secondary_state_key": "contract_secondary", "label_template": "%d %d"}
	display_state["coin_pusher_cabinet"] = display_cabinet
	display_state["contract_primary"] = 1
	display_state["contract_secondary"] = 2
	var display_signature := str(renderer.call("debug_backglass_cache_signature_for_test", display_state))
	for value_key in ["contract_primary", "contract_secondary"]:
		var mutated := display_state.duplicate(true)
		mutated[value_key] = int(display_state.get(value_key, 0)) + 1
		_check(str(renderer.call("debug_backglass_cache_signature_for_test", mutated)) != display_signature, "backglass_cache_invalidates_%s" % value_key)
	observations["backglass_signature_contract"] = {
		"base": backglass_signature,
		"ignored_dynamic_count": backglass_dynamic_mutations.size(),
		"goal_invalidation_count": 7,
		"display_invalidation_count": 2,
	}
	var hardware_signature := str(renderer.call("debug_hardware_cache_signature_for_test", snapshot))
	var serial_only := snapshot.duplicate(true)
	serial_only["coin_pusher_presentation_view_serial"] = int(snapshot.get("coin_pusher_presentation_view_serial", 0)) + 1
	_check(str(renderer.call("debug_hardware_cache_signature_for_test", serial_only)) == hardware_signature, "hardware_cache_ignores_presentation_serial")
	var hardware_mutations := {
		"carriage": {"coin_pusher_carriage_x": int(snapshot.get("coin_pusher_carriage_x", 0)) + 1},
		"selected_hole": {"coin_pusher_selected_hole": int(snapshot.get("coin_pusher_selected_hole", 0)) + 1},
		"skill_stop": {"coin_pusher_skill_stop_engaged": not bool(snapshot.get("coin_pusher_skill_stop_engaged", false))},
		"drop_queue": {"coin_pusher_drop_queue_count": int(snapshot.get("coin_pusher_drop_queue_count", 0)) + 1},
		"drop_charge": {"coin_pusher_drop_charge_count": int(snapshot.get("coin_pusher_drop_charge_count", 0)) + 1},
		"tray_count": {"coin_pusher_tray_count": int(snapshot.get("coin_pusher_tray_count", 0)) + 1},
		"tray_value": {"coin_pusher_tray_value": int(snapshot.get("coin_pusher_tray_value", 0)) + 1},
		"locked": {"coin_pusher_locked": not bool(snapshot.get("coin_pusher_locked", false))},
		"vault_cell": {"coin_pusher_vault_selected_cell": int(snapshot.get("coin_pusher_vault_selected_cell", 0)) + 1},
		"tell": {"coin_pusher_tell_label": str(snapshot.get("coin_pusher_tell_label", "steady")) + ":changed"},
		"feature_hardware": {"coin_pusher_feature_hardware": {"contract_mutation": true}},
	}
	for mutation_id in hardware_mutations:
		var mutated := snapshot.duplicate(true)
		mutated.merge(hardware_mutations[mutation_id], true)
		_check(str(renderer.call("debug_hardware_cache_signature_for_test", mutated)) != hardware_signature, "hardware_cache_invalidates_%s" % mutation_id)
	_check(str(renderer.call("debug_hardware_cache_signature_for_test", snapshot, "coin_pusher_nudge")) != hardware_signature, "hardware_cache_invalidates_hover")
	var bindings_mutated := snapshot.duplicate(true)
	var bindings: Dictionary = (snapshot.get("surface_action_bindings", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var drop_binding: Dictionary = (bindings.get("coin_pusher_drop", {}) as Dictionary).duplicate(true) if typeof(bindings.get("coin_pusher_drop", {})) == TYPE_DICTIONARY else {}
	drop_binding["enabled"] = not bool(drop_binding.get("enabled", false))
	bindings["coin_pusher_drop"] = drop_binding
	bindings_mutated["surface_action_bindings"] = bindings
	_check(str(renderer.call("debug_hardware_cache_signature_for_test", bindings_mutated)) != hardware_signature, "hardware_cache_invalidates_binding")
	observations["hardware_signature_contract"] = {
		"base": hardware_signature,
		"mutation_count": hardware_mutations.size() + 2,
	}
	# Re-entry replaces the old surface; hide it before presenting the same game
	# module on a new production canvas so two hosts cannot race one renderer.
	app.visible = false
	var reentry_canvas: Control = GameSurfaceCanvasScript.new()
	reentry_canvas.name = "CoinPusherReentrySurface"
	reentry_canvas.position = Vector2.ZERO
	reentry_canvas.size = DESIGN_SIZE
	root.add_child(reentry_canvas)
	reentry_canvas.call("set_game_module", game)
	reentry_canvas.call("render_game_snapshot", snapshot)
	await _frames(5)
	var reentry := _cache_state(renderer)
	observations["reentry"] = reentry
	_check(bool(reentry.get("active", false)), "reentry_cache_active")
	_check(int(reentry.get("host_instance_id", 0)) == reentry_canvas.get_instance_id(), "reentry_host_rebound")
	_check(int(reentry.get("viewport_parent_instance_id", 0)) == reentry_canvas.get_instance_id(), "reentry_viewport_reparented")
	_check(int(reentry.get("render_serial", 0)) > int(initial.get("render_serial", 0)), "reentry_forced_rebuild")

	reentry_canvas.size = Vector2(800, 400)
	reentry_canvas.queue_redraw()
	await _frames(5)
	var resized := _cache_state(renderer)
	observations["resized"] = resized
	_check(bool(resized.get("active", false)), "resize_cache_active")
	_check(str(resized.get("key", "")) != str(reentry.get("key", "")), "resize_invalidates_key")
	_check(int(resized.get("rebuild_serial", 0)) > int(reentry.get("rebuild_serial", 0)), "resize_rebuilt")
	_check(resized.get("pixel_size", Vector2i.ZERO) != reentry.get("pixel_size", Vector2i.ZERO), "resize_pixel_extent_changed")
	reentry_canvas.size = DESIGN_SIZE
	reentry_canvas.queue_redraw()
	await _frames(5)
	var restored := _cache_state(renderer)
	observations["restored"] = restored
	_check(bool(restored.get("active", false)), "native_grid_cache_restored")
	_check(int(restored.get("rebuild_serial", 0)) > int(resized.get("rebuild_serial", 0)), "resize_restore_rebuilt")

	var effective_font: Font = reentry_canvas.get_theme_default_font().duplicate() as Font
	var isolated_theme := Theme.new()
	isolated_theme.default_font = effective_font
	reentry_canvas.theme = isolated_theme
	reentry_canvas.queue_redraw()
	await _frames(5)
	var theme_rebound := _cache_state(renderer)
	observations["theme_rebound"] = theme_rebound
	_check(bool(theme_rebound.get("active", false)), "effective_font_identity_rebound")
	var theme_serial := int(theme_rebound.get("render_serial", 0))
	effective_font.emit_changed()
	var font_invalidated := _cache_state(renderer)
	observations["font_invalidated"] = font_invalidated
	_check(bool(font_invalidated.get("pending", false)), "effective_font_mutation_invalidated")
	_check(str(font_invalidated.get("fallback_reason", "")) == "effective_font_changed", "effective_font_fallback_reason")
	await _frames(5)
	var font_rebuilt := _cache_state(renderer)
	observations["font_rebuilt"] = font_rebuilt
	_check(bool(font_rebuilt.get("active", false)), "effective_font_mutation_rebuilt")
	_check(int(font_rebuilt.get("render_serial", 0)) > theme_serial, "effective_font_render_serial_advanced")

	var static_key := str(font_rebuilt.get("key", ""))
	var static_serial := int(font_rebuilt.get("rebuild_serial", 0))
	var bodies: Array = snapshot.get("coin_pusher_bodies", []).duplicate(true)
	if not bodies.is_empty() and typeof(bodies[0]) == TYPE_DICTIONARY:
		(bodies[0] as Dictionary)["x"] = int((bodies[0] as Dictionary).get("x", 0)) + 17
	reentry_canvas.call("apply_surface_state_patch", {
		"coin_pusher_bodies": bodies,
		"coin_pusher_carriage_x": int(snapshot.get("coin_pusher_carriage_x", 50000)) + 31,
		"coin_pusher_tray_count": int(snapshot.get("coin_pusher_tray_count", 0)) + 1,
	})
	await _frames(3)
	var dynamic := _cache_state(renderer)
	observations["dynamic"] = dynamic
	_check(str(dynamic.get("key", "")) == static_key, "dynamic_state_preserves_static_key")
	_check(int(dynamic.get("rebuild_serial", 0)) == static_serial, "dynamic_state_does_not_rebuild_static_layer")

	var goal_before := _cache_state(renderer)
	var changed_goal := goal.duplicate(true)
	changed_goal["progress"] = 0 if int(changed_goal.get("progress", 0)) > 0 else maxi(1, int(changed_goal.get("target", 1)))
	reentry_canvas.call("apply_surface_state_patch", {"coin_pusher_goal": changed_goal})
	await _frames(5)
	var goal_after := _cache_state(renderer)
	observations["goal_after"] = goal_after
	_check(str(goal_after.get("backglass_key", "")) != str(goal_before.get("backglass_key", "")), "goal_progress_invalidates_backglass_key")
	_check(int(goal_after.get("rebuild_serial", 0)) > int(goal_before.get("rebuild_serial", 0)), "goal_progress_rebuilt_backglass_layer")

	var content_before := _cache_state(renderer)
	reentry_canvas.call("apply_surface_state_patch", {"coin_pusher_static_content_key": str(snapshot.get("coin_pusher_static_content_key", "")) + ":contract_mutation"})
	await _frames(5)
	var content_after := _cache_state(renderer)
	observations["content_after"] = content_after
	_check(str(content_after.get("key", "")) != str(content_before.get("key", "")), "static_content_fingerprint_invalidates")
	_check(int(content_after.get("render_serial", 0)) > int(content_before.get("render_serial", 0)), "static_content_fingerprint_rebuilt")

	var locked_before := _cache_state(renderer)
	reentry_canvas.call("apply_surface_state_patch", {"coin_pusher_locked": not bool(snapshot.get("coin_pusher_locked", false))})
	await _frames(5)
	var locked_after := _cache_state(renderer)
	observations["locked_after"] = locked_after
	_check(str(locked_after.get("key", "")) != str(locked_before.get("key", "")), "locked_palette_invalidates")
	_check(int(locked_after.get("render_serial", 0)) > int(locked_before.get("render_serial", 0)), "locked_palette_rebuilt")

	# Compare actual pixels from the production GameSurfaceCanvas at the shipped
	# 1280x720 viewport. The matrix crosses every authored variation with normal
	# and reduced motion, locked and unlocked palettes, and grounded/airborne
	# bodies so shadows are exercised rather than inferred from command order.
	reentry_canvas.queue_free()
	await _frames(2)
	var production_rect: Rect2 = production_canvas.get_global_rect()
	var comparison_viewport := SubViewport.new()
	comparison_viewport.name = "CoinPusherShippedPixelParityViewport"
	comparison_viewport.size = Vector2i(1280, 720)
	comparison_viewport.disable_3d = true
	comparison_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(comparison_viewport)
	var comparison_canvas: Control = GameSurfaceCanvasScript.new()
	comparison_canvas.name = "CoinPusherPixelParitySurface"
	comparison_canvas.position = production_rect.position
	comparison_canvas.size = production_rect.size
	comparison_viewport.add_child(comparison_canvas)
	comparison_canvas.call("set_game_module", game)
	var pixel_pairs: Array = []
	for variation_id in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
		for reduce_motion in [false, true]:
			for locked in [false, true]:
				for airborne in [false, true]:
					var case_id := "%s_%s_%s_%s" % [variation_id, "reduced" if reduce_motion else "normal", "locked" if locked else "unlocked", "airborne" if airborne else "grounded"]
					var case_state := _pixel_case_state(game, snapshot, variation_id, reduce_motion, locked, airborne)
					var pair := await _capture_pixel_pair(comparison_viewport, comparison_canvas, renderer, case_state, case_id)
					pixel_pairs.append(pair)
					_check(bool(pair.get("visually_equivalent", false)), "pixel_pair_%s" % case_id)
	observations["pixel_pairs"] = pixel_pairs

	_finish()


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--source-head="):
			source_head = argument.trim_prefix("--source-head=")
		elif argument.begins_with("--source-tree="):
			source_tree = argument.trim_prefix("--source-tree=")
		elif argument.begins_with("--build-identity="):
			build_identity = argument.trim_prefix("--build-identity=")


func _pixel_case_state(game: GameModule, snapshot: Dictionary, variation_id: String, reduce_motion: bool, locked: bool, airborne: bool) -> Dictionary:
	var result := snapshot.duplicate(true)
	var machine_definition: Dictionary = game.call("_machine_definition", variation_id)
	var geometry: Dictionary = (machine_definition.get("geometry", {}) as Dictionary).duplicate(true)
	var apparatus: Dictionary = (machine_definition.get("apparatus", {}) as Dictionary).duplicate(true)
	apparatus["drop_y"] = int(geometry.get("drop_y", 73000))
	var cabinet: Dictionary = game.call("_resolved_cabinet", variation_id)
	result["coin_pusher_variation_id"] = variation_id
	result["coin_pusher_cabinet"] = cabinet
	result["coin_pusher_geometry"] = geometry
	result["coin_pusher_apparatus"] = apparatus
	result["coin_pusher_static_content_key"] = JSON.stringify([cabinet, geometry, apparatus], "", true).sha256_text()
	result["coin_pusher_coin_height"] = int((machine_definition.get("coins", {}) as Dictionary).get("height", 950))
	result["coin_pusher_coin_radius"] = int((machine_definition.get("coins", {}) as Dictionary).get("radius", 2350))
	result["reduce_motion"] = reduce_motion
	result["coin_pusher_locked"] = locked
	if airborne:
		var current: Array = result.get("coin_pusher_bodies", []).duplicate(true)
		var previous: Array = result.get("coin_pusher_previous_bodies", current).duplicate(true)
		if not current.is_empty() and typeof(current[0]) == TYPE_DICTIONARY:
			(current[0] as Dictionary)["rest_state"] = "falling"
			(current[0] as Dictionary)["z"] = maxi(12000, int((current[0] as Dictionary).get("z", 0)) + 8000)
		if not previous.is_empty() and typeof(previous[0]) == TYPE_DICTIONARY:
			(previous[0] as Dictionary)["rest_state"] = "falling"
			(previous[0] as Dictionary)["z"] = maxi(10000, int((previous[0] as Dictionary).get("z", 0)) + 6000)
		result["coin_pusher_bodies"] = current
		result["coin_pusher_previous_bodies"] = previous
	return result


func _capture_pixel_pair(viewport: SubViewport, canvas: Control, renderer: RefCounted, state: Dictionary, case_id: String) -> Dictionary:
	var uncached_state := state.duplicate(true)
	uncached_state["coin_pusher_static_cache_test"] = false
	canvas.call("render_game_snapshot", uncached_state)
	canvas.queue_redraw()
	await _frames(3)
	await RenderingServer.frame_post_draw
	var uncached := viewport.get_texture().get_image()
	var uncached_path := artifact_dir.path_join(case_id + "_uncached.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir))
	uncached.save_png(ProjectSettings.globalize_path(uncached_path))

	var cached_state := state.duplicate(true)
	cached_state["coin_pusher_static_cache_test"] = true
	canvas.call("render_game_snapshot", cached_state)
	canvas.queue_redraw()
	for _index in range(12):
		await process_frame
		if bool(_cache_state(renderer).get("active", false)):
			break
	canvas.queue_redraw()
	await _frames(3)
	await RenderingServer.frame_post_draw
	var cached := viewport.get_texture().get_image()
	var cached_path := artifact_dir.path_join(case_id + "_cached.png")
	cached.save_png(ProjectSettings.globalize_path(cached_path))

	var uncached_bytes := uncached.get_data()
	var cached_bytes := cached.get_data()
	var differing_bytes := 0
	var max_channel_delta := 0
	var absolute_delta_sum := 0
	var pixels_over_two := 0
	var pixels_over_sixteen := 0
	var difference_bounds := Rect2i()
	if uncached_bytes.size() != cached_bytes.size():
		differing_bytes = maxi(uncached_bytes.size(), cached_bytes.size())
		max_channel_delta = 255
	else:
		for pixel_index in range(uncached_bytes.size() / 4):
			var pixel_max := 0
			for channel in range(4):
				var byte_index := pixel_index * 4 + channel
				var delta := absi(int(uncached_bytes[byte_index]) - int(cached_bytes[byte_index]))
				absolute_delta_sum += delta
				if delta > 0:
					differing_bytes += 1
					max_channel_delta = maxi(max_channel_delta, delta)
					pixel_max = maxi(pixel_max, delta)
			if pixel_max > 2:
				pixels_over_two += 1
				var point := Vector2i(pixel_index % uncached.get_width(), pixel_index / uncached.get_width())
				difference_bounds = Rect2i(point, Vector2i.ONE) if difference_bounds.size == Vector2i.ZERO else difference_bounds.expand(point)
			if pixel_max > 16:
				pixels_over_sixteen += 1
	var mean_absolute_channel_delta := float(absolute_delta_sum) / float(maxi(1, uncached_bytes.size()))
	# Transparent static layers are rendered once and then alpha-composited;
	# their premultiplication quantization can differ from direct drawing by a
	# few channel levels. Bound both aggregate error and larger edge outliers.
	var visually_equivalent := uncached_bytes.size() == cached_bytes.size() \
		and mean_absolute_channel_delta <= 0.10 \
		and pixels_over_two <= 1 \
		and pixels_over_sixteen <= 1
	return {
		"case_id": case_id,
		"viewport_size": {"width": viewport.size.x, "height": viewport.size.y},
		"surface_rect": {"x": canvas.position.x, "y": canvas.position.y, "width": canvas.size.x, "height": canvas.size.y},
		"uncached_png": uncached_path,
		"uncached_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(uncached_path)),
		"cached_png": cached_path,
		"cached_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(cached_path)),
		"byte_count": uncached_bytes.size(),
		"differing_bytes": differing_bytes,
		"max_channel_delta": max_channel_delta,
		"mean_absolute_channel_delta": mean_absolute_channel_delta,
		"pixels_over_two": pixels_over_two,
		"pixels_over_sixteen": pixels_over_sixteen,
		"difference_bounds_over_two": difference_bounds,
		"exact_match": differing_bytes == 0,
		"visually_equivalent": visually_equivalent,
	}


func _cache_state(renderer: RefCounted) -> Dictionary:
	return renderer.call("debug_static_cache_for_test") as Dictionary


func _check(condition: bool, id: String) -> void:
	checks.append({"id": id, "passed": condition})
	if not condition:
		failures.append(id)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _finish() -> void:
	var report := {
		"tool": "coin_pusher_static_cache_contract",
		"schema": "coin_pusher_static_cache_contract_v3",
		"source_head": source_head,
		"source_tree": source_tree,
		"build_identity": build_identity,
		"production_draw_path": true,
		"design_size": {"width": int(DESIGN_SIZE.x), "height": int(DESIGN_SIZE.y)},
		"passed": failures.is_empty(),
		"failures": failures,
		"checks": checks,
		"observations": observations,
	}
	if report_path.is_empty():
		print("COIN_PUSHER_STATIC_CACHE_CONTRACT_FAIL %s" % JSON.stringify(report))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("COIN_PUSHER_STATIC_CACHE_CONTRACT_%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(report)])
	quit(0 if failures.is_empty() else 1)
