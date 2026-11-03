extends SceneTree

# Canvas contract: an action catalog is descriptive data, not permission to
# invent a wager target. Only controls published by the bound native renderer
# can receive pointer input. Native hit publication below is synthetic; input
# uses actual InputEventScreenTouch and the production canvas handler.
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Module := preload("res://scripts/core/game_module.gd")
const Style := preload("res://scripts/ui/visual_style.gd")

var checks := 0
var failures: Array[String] = []
var emitted: Array = []
var unavailable_draw_observed := false

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func _snapshot() -> Dictionary:
	return {"game_id": "ownership_probe", "surface_renderer": "result", "surface_controls_native": true,
		"legal_actions": [{"id": "old_wager", "label": "Wager", "enabled": true}],
		"cheat_actions": [{"id": "old_cheat", "label": "Risk", "enabled": true}],
		"has_valid_stake": true, "stake_min": 1, "stake_max": 100, "selected_stake": 5,
		"surface_action_bindings": {"surface_legal": {"action": "native_play", "index": 7}}}

func _touch(canvas: Control, position: Vector2, pressed: bool, emulated: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = 0
	event.pressed = pressed
	if emulated: event.device = InputEvent.DEVICE_ID_EMULATION
	canvas._gui_input(event)

func _run() -> void:
	var canvas := Canvas.new()
	canvas.size = Vector2(Style.GAME_BOARD_SIZE)
	root.add_child(canvas)
	await process_frame
	canvas.clear_runtime_state()
	canvas.surface_action.connect(func(action: String, index: int, confirmed: bool): emitted.append({"action": action, "index": index, "confirmed": confirmed}))
	canvas.render_game_snapshot(_snapshot())
	for action in ["surface_legal", "surface_cheat", "surface_resolve", "surface_stake_down", "surface_stake_up", "surface_stake_max"]:
		var position := canvas.local_position_for_surface_action(action, 0)
		_check(position.x < 0.0 and position.y < 0.0, "unbound catalog does not synthesize local target " + action)
		_check(not canvas.global_rect_for_surface_action(action, 0).has_area(), "unbound catalog does not synthesize global target " + action)
	_check(canvas.hit_regions.is_empty(), "coordinate queries cannot create actionable controls")
	_touch(canvas, Vector2(120, 120), true)
	_touch(canvas, Vector2(120, 120), false)
	_check(emitted.is_empty(), "unbound catalog cannot dispatch a wager on touch")

	var first := Module.new()
	first.setup({"id": "first_native", "gameplay_model": "full_simulation"})
	canvas.set_game_module(first)
	canvas.render_game_snapshot(_snapshot())
	# A native renderer owns this registration boundary; no catalog-derived
	# rectangle or fallback action implementation participates.
	canvas.surface_add_exact_hit(Rect2(100, 100, 100, 60), "native_play", 7)
	var native_position := canvas.local_position_for_surface_action("native_play", 7)
	var alias_position := canvas.local_position_for_surface_action("surface_legal", 0)
	_check(native_position == alias_position and native_position.x >= 0.0, "compatibility alias locates an existing native control")
	_check(canvas.global_rect_for_surface_action("surface_legal", 0).has_area(), "native control retains global pointer geometry")
	_touch(canvas, native_position, true)
	_touch(canvas, native_position, false)
	_check(emitted.size() == 1 and emitted[0].action == "native_play" and int(emitted[0].index) == 7, "real touch dispatches the native action exactly once")
	_touch(canvas, native_position, true, true)
	_touch(canvas, native_position, false, true)
	_check(emitted.size() == 1, "emulated touch copy cannot duplicate the native action")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = native_position
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	canvas._gui_input(mouse)
	_check(emitted.size() == 1, "emulated mouse copy cannot duplicate the native touch")

	var second := Module.new()
	second.setup({"id": "second_native", "gameplay_model": "full_simulation"})
	canvas.set_game_module(second)
	_check(canvas.hit_regions.is_empty(), "replacement renderer releases old actionable controls immediately")
	_check(not canvas.global_rect_for_surface_action("native_play", 7).has_area(), "replacement cannot borrow preceding native geometry")
	_touch(canvas, native_position, true)
	_touch(canvas, native_position, false)
	_check(emitted.size() == 1, "old native target cannot dispatch into its replacement")
	canvas.surface_add_exact_hit(Rect2(260, 100, 100, 60), "replacement_play", 2)
	var replacement_position := canvas.local_position_for_surface_action("replacement_play", 2)
	_touch(canvas, replacement_position, true)
	_touch(canvas, replacement_position, false)
	_check(emitted.size() == 2 and emitted[1].action == "replacement_play", "replacement native target retains touch behavior")
	canvas.set_game_module(null)
	_check(canvas.hit_regions.is_empty(), "unbinding releases the replacement control immediately")
	_touch(canvas, replacement_position, true)
	_touch(canvas, replacement_position, false)
	_check(emitted.size() == 2, "unbound replacement cannot dispatch another action")

	# Godot's headless rendering backend may omit draw callbacks. Qualify this
	# extra display boundary only when the real callback actually ran.
	var previous_draws: int = canvas.perf_draw_frame_total_count
	canvas.set_game_module(Module.new()) # Base module declines native drawing.
	canvas.render_game_snapshot(_snapshot())
	for _frame in range(4): await process_frame
	unavailable_draw_observed = int(canvas.perf_draw_frame_total_count) > previous_draws
	if unavailable_draw_observed:
		_check(canvas.hit_regions.size() == 1 and str(canvas.hit_regions[0].get("action", "")) == "surface_back", "declining renderer exposes only the Leave control")
		_check(not canvas.global_rect_for_surface_action("surface_legal", 0).has_area(), "declining renderer never recreates a wager target")
	canvas.queue_free()
	await process_frame
	var report := {"checks": checks, "failures": failures, "emitted": emitted, "unavailable_draw_observed": unavailable_draw_observed,
		"fidelity": "Synthetic native hit publication and real InputEventScreenTouch/emulated-copy handling through production GameSurfaceCanvas; no wager model, money, save or browser input. Declining-renderer drawing is checked only when the real draw callback is observed."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("GAME_SURFACE_NATIVE_OWNERSHIP ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
