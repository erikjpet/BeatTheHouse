extends SceneTree

const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _manifest()
	var textures := _textures()
	var counters: Dictionary = PackScript.room_counter_rectangles("gas_station_casino")
	_check(counters.get("gas_station_staff_window", Rect2()) == Rect2(532, 80, 104, 8), "Shipping counter geometry must be read unchanged.")
	var path := "user://environment_art_pack_contract.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var pack = PackScript._load_paths("gas_station_casino", path, "user://environment_art_fixture", counters, textures)
	_check(pack != null, "Valid manifest loads from disk into typed fields: " + PackScript.last_error)
	if pack == null:
		_finish()
		return
	_check(pack.background.get_size() == Vector2(1800, 860), "Background preserves authored 2x pixels.")
	_check(pack.animations.size() == 5, "All five closed animation types compile in manifest order.")
	_check(pack.animations[0].frame_regions.size() == 4 and pack.animations[0].frame_regions[3] == Rect2(48, 0, 16, 8), "Frame source regions are precomputed, in texture pixels.")
	_check(pack.animations[1].min_opacity == 0.55 and pack.animations[1].period == 1.6, "Pulse timing/opacity compiles.")
	_check(pack.animations[2].has_clip and pack.animations[2].clip == Rect2(0, 0, 12, 10) and pack.animations[2].still_hidden, "Mover clip and Reduce Motion hide compile.")
	_check(not pack.animations[3].web_low_detail and pack.animations[3].speed == Vector2(0, 4), "Scroll low-detail and speed compile.")
	_check(pack.animations[4].additive and pack.animations[4].beam_thickness == 4.0, "Sweep keeps additive blend and 2x native beam thickness.")
	_check(pack.counters["gas_station_staff_window"].rect == Rect2(532, 80, 104, 8), "Counter source is the shipping front rectangle.")
	_check(pack.texture_paths.size() == 7, "Unique loaded texture paths are retained once per pack.")
	var empty := manifest.duplicate(true)
	empty.erase("animations")
	empty.erase("counters")
	var empty_pack = PackScript.compile_manifest(empty, "gas_station_casino", "user://fixture", counters, textures)
	_check(empty_pack != null and empty_pack.animations.is_empty() and empty_pack.counters.is_empty(), "Animation/counter layers can be omitted.")
	for loop_mode in ["loop", "pingpong", "once_hold"]:
		for still in ["first", "hide", 0, 3]:
			var variant := manifest.duplicate(true)
			variant["animations"][0]["loop"] = loop_mode
			variant["animations"][0]["still"] = still
			_check(PackScript.compile_manifest(variant, "gas_station_casino", "user://fixture", counters, textures) != null, "All loop/still modes validate.")
	var bleed := manifest.duplicate(true)
	bleed["counters"]["gas_station_staff_window"]["bleed"] = [1, 2, 3, 4]
	var bleed_textures := textures.duplicate()
	bleed_textures["counters/front.png"] = _texture(216, 28)
	var bleed_pack = PackScript.compile_manifest(bleed, "gas_station_casino", "user://fixture", counters, bleed_textures)
	_check(bleed_pack != null and bleed_pack.counters["gas_station_staff_window"].rect == Rect2(531, 78, 108, 14), "Bleed expands the texture rectangle without moving contact geometry.")
	var framed := manifest.duplicate(true)
	framed["animations"][2]["frames"] = 3
	framed["animations"][2]["fps"] = 4
	var framed_textures := textures.duplicate()
	framed_textures["anim/mover.png"] = _texture(12, 4)
	_check(PackScript.compile_manifest(framed, "gas_station_casino", "user://fixture", counters, framed_textures) != null, "Mover may carry a frame strip.")
	for invalid_case in _invalid_cases():
		var variant := manifest.duplicate(true)
		var target: Variant = variant
		var keys: Array = invalid_case["path"]
		for index in range(keys.size() - 1):
			target = target[keys[index]]
		target[keys[-1]] = invalid_case["value"]
		var invalid_pack = PackScript.compile_manifest(variant, "gas_station_casino", "user://fixture", counters, textures)
		_check(invalid_pack == null and not PackScript.last_error.is_empty(), "Invalid case rejected with reason: " + str(invalid_case["name"]))
	var uneven := textures.duplicate()
	uneven["anim/frames.png"] = _texture(63, 8)
	_check(PackScript.compile_manifest(manifest, "gas_station_casino", "user://fixture", counters, uneven) == null and PackScript.last_error.contains("uneven"), "Uneven frame strips return null.")
	var scroll := manifest.duplicate(true)
	scroll["animations"][3]["rect"] = [0, 42, 900, 34]
	var tile := textures.duplicate()
	tile["anim/scroll.png"] = _texture(16, 68)
	_check(PackScript.compile_manifest(scroll, "gas_station_casino", "user://fixture", counters, tile) == null and PackScript.last_error.contains("1800"), "Owner-confirmed full-rectangle scroll rule rejects small tiles.")
	_check(PackScript.load_pack("__environment_art_disabled_contract_fixture") == null, "A room absent from the enable list ignores pack loading.")
	_check(not PackScript.room_counter_rectangles("punchline_club").has("punchline_right_table"), "Punchline club does not borrow casino counter ids.")
	# A rejected pack must not prevent the current, untouched room renderer from
	# rendering/advancing. The canvas integration is added in later phases.
	var canvas: Control = PixelSceneCanvasScript.new()
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	canvas.call("render_environment_snapshot", {"archetype_id": "gas_station_casino", "interactable_objects": [], "reduce_motion": false})
	canvas.call("set_developer_slot_placement_mode", true)
	for index in range(24):
		await process_frame
	_check(canvas.is_processing() and bool(canvas.call("performance_live_status").get("scene_idle_animation_active", false)), "Code-rendered room remains live with placement overlay after validation failures.")
	canvas.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("ENVIRONMENT_ART_PACK_CONTRACT " + JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _textures() -> Dictionary:
	return {
		"background.png": _texture(1800, 860),
		"anim/frames.png": _texture(64, 8),
		"anim/pulse.png": _texture(16, 8),
		"anim/mover.png": _texture(4, 4),
		"anim/scroll.png": _texture(16, 8),
		"anim/sweep.png": _texture(128, 8),
		"counters/front.png": _texture(208, 16),
	}


func _manifest() -> Dictionary:
	return {
		"schema": "bth.environment_art/v1", "environment_id": "gas_station_casino", "board_size": [900, 430], "pixel_scale": 2,
		"background": {"texture": "background.png"},
		"animations": [
			{"type": "frames", "texture": "anim/frames.png", "rect": [0, 4, 8, 4], "frames": 4, "fps": 5},
			{"type": "pulse", "texture": "anim/pulse.png", "rect": [0, 0, 8, 4], "min_opacity": 0.55, "max_opacity": 1.0, "period": 1.6},
			{"type": "mover", "texture": "anim/mover.png", "size": [2, 2], "from": [-3, 5], "to": [10, 5], "duration": 2.0, "gap": 0.5, "clip": [0, 0, 12, 10], "still": "hide"},
			{"type": "scroll", "texture": "anim/scroll.png", "rect": [2, 1, 8, 4], "speed": [0, 4], "web_low_detail": false},
			{"type": "sweep", "texture": "anim/sweep.png", "origin": [739, 94], "from": [724, 190], "to": [796, 190], "period": 3.5, "blend": "add"},
		],
		"counters": {"gas_station_staff_window": {"texture": "counters/front.png"}},
	}


func _invalid_cases() -> Array:
	return [
		{"name": "schema", "path": ["schema"], "value": "wrong"},
		{"name": "id", "path": ["environment_id"], "value": "bar"},
		{"name": "board", "path": ["board_size"], "value": [901, 430]},
		{"name": "scale", "path": ["pixel_scale"], "value": 1},
		{"name": "bool scale", "path": ["pixel_scale"], "value": true},
		{"name": "missing background", "path": ["background"], "value": null},
		{"name": "missing texture", "path": ["background", "texture"], "value": "missing.png"},
		{"name": "traversal", "path": ["background", "texture"], "value": "../background.png"},
		{"name": "absolute path", "path": ["background", "texture"], "value": "C:/background.png"},
		{"name": "unknown type", "path": ["animations", 0, "type"], "value": "neon"},
		{"name": "zero frames", "path": ["animations", 0, "frames"], "value": 0},
		{"name": "fractional frames", "path": ["animations", 0, "frames"], "value": 1.5},
		{"name": "uneven strip", "path": ["animations", 0, "frames"], "value": 3},
		{"name": "wrong frame size", "path": ["animations", 0, "rect"], "value": [0, 4, 9, 4]},
		{"name": "negative fps", "path": ["animations", 0, "fps"], "value": -2},
		{"name": "off board", "path": ["animations", 0, "rect"], "value": [901, 4, 8, 4]},
		{"name": "nonfinite rect", "path": ["animations", 0, "rect"], "value": [NAN, 4, 8, 4]},
		{"name": "zero rect", "path": ["animations", 0, "rect"], "value": [0, 4, 0, 4]},
		{"name": "bad loop", "path": ["animations", 0, "loop"], "value": "forever"},
		{"name": "bad still", "path": ["animations", 0, "still"], "value": 4},
		{"name": "bad blend", "path": ["animations", 0, "blend"], "value": "screen"},
		{"name": "opacity", "path": ["animations", 0, "opacity"], "value": 1.1},
		{"name": "nonfinite phase", "path": ["animations", 0, "phase"], "value": INF},
		{"name": "detail flag", "path": ["animations", 0, "web_low_detail"], "value": "false"},
		{"name": "pulse bounds", "path": ["animations", 1, "min_opacity"], "value": 1.1},
		{"name": "pulse period", "path": ["animations", 1, "period"], "value": 0},
		{"name": "mover duration", "path": ["animations", 2, "duration"], "value": 0},
		{"name": "mover gap", "path": ["animations", 2, "gap"], "value": -1},
		{"name": "mover clip", "path": ["animations", 2, "clip"], "value": [901, 0, 2, 2]},
		{"name": "scroll speed", "path": ["animations", 3, "speed"], "value": [0, INF]},
		{"name": "sweep origin", "path": ["animations", 4, "origin"], "value": [0]},
		{"name": "sweep period", "path": ["animations", 4, "period"], "value": 0},
		{"name": "unknown counter", "path": ["counters", "not_in_this_room"], "value": {"texture": "counters/front.png"}},
		{"name": "bad bleed", "path": ["counters", "gas_station_staff_window", "bleed"], "value": [0, -1, 0, 0]},
	]
