extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const DESIGN_SIZE := Vector2(900, 430)
const REPORT_PATH := "res://.tmp/fix06_13_static_cache_contract/report.json"

var failures: Array[String] = []
var checks: Array[Dictionary] = []
var observations: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
	_check(command_equivalence.get("live_commands", []) == ["backglass", "platform", "bodies", "apron", "glass", "hardware"], "dynamic_commands_remain_live")
	# Desktop evidence opts into the shipped-Web cache while retaining the exact
	# production game module, surface state, canvas and draw dispatch.
	production_canvas.call("apply_surface_state_patch", {"coin_pusher_static_cache_test": true})
	production_canvas.queue_redraw()
	await _frames(4)
	observations["production_board_rect"] = production_canvas.call("board_rect")
	var initial := _cache_state(renderer)
	observations["initial"] = initial
	_check(bool(initial.get("active", false)), "production_cache_active")
	_check(int(initial.get("viewport_count", 0)) == 3, "production_cache_layer_count")
	_check(int(initial.get("host_instance_id", 0)) == production_canvas.get_instance_id(), "production_cache_host")
	_check(int(initial.get("viewport_parent_instance_id", 0)) == production_canvas.get_instance_id(), "production_cache_parent")

	var snapshot: Dictionary = production_canvas.call("realtime_surface_state")
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

	_finish()


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
		"production_draw_path": true,
		"design_size": {"width": int(DESIGN_SIZE.x), "height": int(DESIGN_SIZE.y)},
		"passed": failures.is_empty(),
		"failures": failures,
		"checks": checks,
		"observations": observations,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("COIN_PUSHER_STATIC_CACHE_CONTRACT_%s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(report)])
	quit(0 if failures.is_empty() else 1)
