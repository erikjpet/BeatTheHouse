extends SceneTree
const MainScene := preload("res://scenes/main.tscn")
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const ROOM_IDS := ["corner_store", "back_alley", "motel", "bar", "gas_station_casino", "punchline_club", "small_underground_casino", "punchline_back_room", "jazz_club", "kitty_cat_lounge", "delta_queen", "beach", "pawn_shop", "grand_casino", "grand_casino_high_limit", "grand_casino_back_room", "grand_casino_cage", "motel_room", "apartment", "house"]
var out_dir := ""
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var original := FileAccess.get_file_as_bytes(PackScript.INDEX_PATH)
	_check(PackScript.enabled_environment_ids() == ["gas_station_casino"], "Production proof index enables only Gas.")
	var app: Control = MainScene.instantiate()
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	var canvas: Control = app.get("main_menu_background")
	for frame in range(180):
		await process_frame
		if canvas != null and canvas.get("environment_art_pack") != null:
			break
	await _settle(8)
	_check(canvas != null and canvas.get("environment_id") == "gas_station_casino", "Enabled Gas is selected naturally by the production menu.")
	_check(canvas.get("environment_art_pack") != null and canvas.get("background_texture") == null and not canvas.get("use_external_background"), "Menu uses the fully validated in-play pack rather than an external flat PNG.")
	_check(canvas.mouse_filter == Control.MOUSE_FILTER_IGNORE and is_equal_approx(float(canvas.get("camera_zoom")), 1.0) and canvas.get("camera_offset") == Vector2.ZERO, "Menu remains click-through with existing board/camera framing.")
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	first.save_png(out_dir.path_join("menu_after.png"))
	var before: Dictionary = canvas.call("current_view_snapshot")
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var after: Dictionary = canvas.call("current_view_snapshot")
	var second := root.get_texture().get_image()
	second.save_png(out_dir.path_join("menu_idle.png"))
	_check(float(after["scene_animation_time"]) > float(before["scene_animation_time"]) and int(after["scene_idle_animation_redraw_count"]) > int(before["scene_idle_animation_redraw_count"]), "Menu clock and redraws advance with no input.")
	_check(first.get_data() != second.get_data(), "Packed menu visibly animates without input.")
	var play: Control = CanvasScript.new()
	var view := SubViewport.new()
	view.size = Vector2i(900, 430)
	root.add_child(view)
	view.add_child(play)
	play.size = Vector2(900, 430)
	play.call("render_environment_snapshot", {"archetype_id": "gas_station_casino", "interactable_objects": []})
	_check(play.get("environment_art_pack") == canvas.get("environment_art_pack"), "Play and menu select the exact same compiled background/animation/counter resource.")
	view.free()
	var snapshot: Dictionary = canvas.get("foundation_snapshot").duplicate(true)
	snapshot["reduce_motion"] = true
	canvas.call("render_environment_snapshot", snapshot)
	await _settle(8)
	await RenderingServer.frame_post_draw
	var still := (canvas.get("environment_art_renderer").get("texture") as Texture2D).get_image().get_data()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_check(still == (canvas.get("environment_art_renderer").get("texture") as Texture2D).get_image().get_data(), "Menu art has an identical stable Reduce Motion pose.")
	var library: Variant = app.get("library")
	var definitions: Array = library.environment_archetypes.duplicate(true)
	for room in ROOM_IDS:
		_index([room])
		var selected: Dictionary = app.call("_select_main_menu_background_environment")
		var identity := str(selected.get("visual_context", {}).get("art_key", selected.get("id", "")))
		_check(identity == room, "Pack candidate identity: " + room)
		if room == "punchline_club" or room == "punchline_back_room":
			_check(selected.get("id") == "small_underground_casino" and not str(selected.get("current_layer_id", "")).is_empty(), "Layer candidate retains venue identity: " + room)
	_check(library.environment_archetypes == definitions, "Candidate selection never mutates immutable content definitions.")
	_index(["bar"])
	PackScript.invalidate()
	app.call("_reroll_main_menu_background")
	await _settle(8)
	_check(canvas.get("environment_id") == "bar" and canvas.get("environment_art_pack") == null and not canvas.get("use_external_background") and canvas.is_processing(), "Enabled missing pack uses its original live room drawing, not an old flat PNG.")
	_index([])
	PackScript.invalidate()
	app.call("_reroll_main_menu_background")
	await _settle(4)
	_check(canvas.get("use_external_background") and canvas.get("background_texture") != null and canvas.get("environment_art_pack") == null, "An empty enabled list preserves the existing legacy selector and flat PNG path.")
	var file := FileAccess.open(PackScript.INDEX_PATH, FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	PackScript.invalidate()
	app.call("_reroll_main_menu_background")
	await _settle(12)
	_check(canvas.get("environment_art_pack") != null, "Restored production index returns to packed Gas.")
	var departing_pack: WeakRef = weakref(canvas.get("environment_art_pack"))
	app.free()
	_check(departing_pack.get_ref() == null and PackScript.peek_pack("gas_station_casino") == null, "Application teardown releases its ready art cache and instances.")
	var closing_app: Control = MainScene.instantiate()
	closing_app.set("script_prewarm_stopping", true)
	root.add_child(closing_app)
	PackScript.advance_loading()
	_check(not PackScript._pending.is_empty(), "Shutdown fixture owns a newly issued loading request.")
	closing_app.free()
	_check(PackScript._pending.is_empty() and PackScript._cache.is_empty(), "Application teardown drains issued engine tokens and pending metadata.")
	var result := {"checks": checks, "failures": failures, "room_identities": ROOM_IDS, "idle_before": before, "idle_after": after, "index_restored": FileAccess.get_file_as_bytes(PackScript.INDEX_PATH) == original}
	file = FileAccess.open(out_dir.path_join("menu.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("ENVART_MENU_CONTRACT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _index(ids: Array) -> void:
	var file := FileAccess.open(PackScript.INDEX_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"enabled": ids}))
	file.close()

func _settle(count: int) -> void:
	for frame in range(count):
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
