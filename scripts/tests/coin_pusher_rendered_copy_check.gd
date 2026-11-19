extends SceneTree

# Windowed production-canvas evidence. Module cases install disposable synthetic
# rooms, retain real generated piles, and route emitted Canvas pointer events to
# the production module/canonical result boundary. The final case uses the real
# default Practice launcher and Foundation host. No owner save or win is selected.
# Full screenshots retain the production caches. Label/font recording uses a
# separate, uncomposited hardware-cache-layer callback probe of that same frame.
# Run through the admitted guarded runner WITHOUT --headless.
const Game := preload("res://scripts/games/coin_pusher.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Surface := preload("res://scripts/ui/game_surface_canvas.gd")
const EnvironmentScript := preload("res://scripts/core/environment_instance.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const Save := preload("res://scripts/core/save_service.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const FreshStorage := preload("res://scripts/tests/fixtures/qa_fresh_storage_admission.gd")
const LABEL_RECT := Rect2(538, 391, 76, 9)
const WINDOW_SIZE := Vector2i(1280, 720)

class HardwareLabelProbe extends Surface:
	var renderer: RefCounted
	var fixture_state: Dictionary = {}
	var drawn_drop: Dictionary = {}
	func _draw() -> void:
		drawn_drop = {}
		if renderer != null:
			renderer.call("draw_hardware_cache_layer", self, fixture_state)
	func surface_label_centered_plain(text: String, rect: Rect2, font_size: int, color: Color) -> void:
		if rect == Rect2(538, 391, 76, 9):
			var font := get_theme_default_font()
			var fitted := _centered_label_fit_size(font, text, rect, font_size)
			drawn_drop = {"label": text, "requested_font": font_size, "fitted_font": fitted, "width": font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x, "height": font.get_ascent(fitted) + font.get_descent(fitted), "draw_callback": true, "full_viewport_callback": false, "source": "separate production hardware-cache-layer callback probe"}
		super.surface_label_centered_plain(text, rect, font_size, color)

# The real launcher builds the run UI synchronously when entered. Suppress
# only the optional idle menu-prewarm coroutine so no suspended build can
# resume after this short-lived evidence host has been freed.
class PracticeHost extends Main:
	func _prewarm_run_ui_after_web_start() -> void:
		pass

var library: ContentLibrary
var game: CoinPusherGame
var run: RunState
var canvas: GameSurfaceCanvas
var ui: Dictionary = {}
var evidence := ""
var admitted := false
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var last_paid_stake := 0
var practice_app: PracticeHost
var practice_only := false
var rooms_only := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	practice_only = OS.get_cmdline_user_args().has("--practice-only")
	rooms_only = OS.get_cmdline_user_args().has("--rooms-only")
	var admission := FreshStorage.validate()
	if not _check(bool(admission.get("ok", false)), "exact prepared fresh guard admission: " + JSON.stringify(admission.get("errors", []))):
		_finish()
		return
	admitted = true
	evidence = str(admission.get("paths", {}).get("evidence", ""))
	if not _check(not (practice_only and rooms_only), "select at most one focused rendered mode"):
		_finish()
		return
	if not _check(DisplayServer.get_name() != "headless", "rendered evidence requires a windowed backend") or not _check(Solver.native_backend_available_for_test(), "exact approved native Coin Pusher backend is required"):
		_finish()
		return
	root.size = WINDOW_SIZE
	root.position = Vector2i(-32000, -32000)
	library = ContentLibrary.new()
	library.load(false)
	if rooms_only:
		await _room_case("grand_casino", "grand_main_seeded")
		await _room_case("grand_casino_high_limit", "grand_high_seeded")
		_finish()
		return
	if not practice_only:
		for variation in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
			await _module_case("ordinary_" + variation, variation, "")
		await _module_case("grand_main_seeded", "", "grand_casino")
		await _module_case("grand_high_seeded", "", "grand_casino_high_limit")
	await _practice_case()
	_finish()


func _room_case(room_id: String, case_id: String) -> void:
	print("PUSHER_RENDER_PROGRESS case=", room_id, " stage=generated_room_begin")
	var room_run := RunState.new()
	room_run.start_new("RENDERED-COPY-" + case_id)
	room_run.bankroll = 500
	room_run.grand_casino_chips = 200
	# Initial synthetic access only. The production generator/finalizer owns
	# both room fixtures and their normally random persistent machine states.
	room_run.narrative_flags["grand_casino_high_limit_access"] = true
	var generator := Generator.new(library)
	var arrival: Dictionary = Fidelity.generate_and_finalize(generator, room_run, failures, case_id + " room-view arrival", "grand_casino", true)
	if not _check(bool(arrival.get("ok", false)), case_id + " normal Grand generation/finalization"):
		return
	if room_id != "grand_casino" and not _check(generator.enter_grand_casino_room(room_run, room_id), case_id + " normal High Limit room entry"):
		return
	var save := Save.new()
	var slot := "rendered_copy_room_" + room_id
	if not _check(not save.has_run(slot), case_id + " room-view save slot is fresh") or not _check(save.save_run(room_run, slot) == OK, case_id + " save generated room to its own disposable slot"):
		return
	practice_app = PracticeHost.new()
	practice_app.autosave_slot_id = slot
	practice_app.continuous_environment_clock_enabled = false
	practice_app.script_prewarm_stopping = true
	root.add_child(practice_app)
	practice_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(4)
	practice_app.user_settings.coach_tips_enabled = false
	if not _check(practice_app.load_foundation_run(), case_id + " normal Continue restores the generated room"):
		await _close_practice_host()
		return
	await _frames(4)
	var floor: PixelSceneCanvas = practice_app.environment_canvas
	if not _check(floor != null, case_id + " Foundation owns its production room canvas"):
		await _close_practice_host()
		return
	floor.queue_redraw()
	await _frames(2)
	await RenderingServer.frame_post_draw
	var raster := root.get_texture().get_image()
	var restored: Dictionary = practice_app.run_state.current_environment
	var view := floor.current_view_snapshot()
	_check(practice_app.current_screen == Main.SCREEN_ENVIRONMENT and practice_app.current_game == null and not practice_app.dev_game_test_mode and not practice_app.dev_environment_test_mode, case_id + " ordinary room screen before opening any machine")
	_check(floor.is_visible_in_tree() and bool(view.get("uses_foundation_snapshot", false)), case_id + " actual authoritative room canvas is visible")
	_check(str(restored.get("archetype_id", "")) == room_id, case_id + " exact restored room identity")
	var selected_games: Array = restored.get("game_ids", [])
	_check(selected_games.count("coin_pusher") == 1 and not selected_games.has("pull_tabs"), case_id + " one pusher replaces Main Pull Tabs without a duplicate")
	var manifest_count := 0
	for row in restored.get("object_manifest", {}).get("rows", []):
		if str(row.get("presentation_object_id", "")) == "game:coin_pusher" and bool(row.get("active", false)) and bool(row.get("physical", false)):
			manifest_count += 1
		_check(str(row.get("presentation_object_id", "")) != "game:pull_tabs", case_id + " fresh room manifest has no stale Pull Tabs")
	_check(manifest_count == 1, case_id + " one active physical pusher in the restored manifest")
	var binding: Dictionary = restored.get("layout", {}).get("slot_bindings", {}).get("game:coin_pusher", {})
	var expected_slot := "fixed.game_machine_5" if room_id == "grand_casino" else "fixed.game_coin_pusher"
	_check(str(binding.get("slot_id", "")) == expected_slot, case_id + " reviewed room cabinet slot")
	var scene_count := 0
	for object_value in view.get("objects", []):
		var object_id := str(object_value.get("id", ""))
		if object_id == "game:coin_pusher":
			scene_count += 1
		_check(object_id != "game:pull_tabs", case_id + " published room has no stale Pull Tabs model")
	_check(scene_count == 1 and not floor.interactable_object_view("game:coin_pusher").is_empty(), case_id + " one production room model and semantic control")
	var cabinet_layout: Dictionary = {}
	for entry in view.get("object_layout", {}).get("objects", []):
		if str(entry.get("id", "")) == "game:coin_pusher":
			cabinet_layout = entry
	var geometry := _room_frame_geometry(floor, cabinet_layout)
	_check(bool(geometry.get("host_matches_viewport", false)) and bool(geometry.get("cabinet_fully_visible", false)), case_id + " actual full cabinet is within the normal viewport")
	var machine: Dictionary = restored.get("game_states", {}).get("coin_pusher", {})
	var denomination := 5 if room_id == "grand_casino_high_limit" else 1
	var price_policy := Game.new()
	price_policy.setup(library.game("coin_pusher"), library)
	var effective_cost := price_policy._drop_cost(restored)
	var effective_value := price_policy._coin_value(restored)
	_check(effective_cost == denomination and effective_value == denomination, case_id + " production room policy resolves the effective coin cost and payout value")
	# Ordinary $1 cabinets intentionally use production defaults. Only the
	# exceptional High Limit denomination must persist explicit override fields.
	if room_id == "grand_casino_high_limit":
		var flags: Dictionary = restored.get("local_narrative_flags", {})
		_check(int(machine.get("drop_cost", 0)) == 5 and int(machine.get("coin_value", 0)) == 5 and int(flags.get("coin_pusher_drop_cost", 0)) == 5 and int(flags.get("coin_pusher_coin_value", 0)) == 5, case_id + " exceptional $5 denomination persists in the generated machine and room policy")
	var path := evidence.path_join("pusher-room-" + room_id + ".png")
	if _check(raster != null and not raster.is_empty(), case_id + " actual full room viewport image exists") and _check(not FileAccess.file_exists(path), case_id + " room viewport evidence is single-use"):
		_check(raster.save_png(path) == OK, case_id + " save full generated room viewport before opening pusher")
		captures.append({"case": case_id, "stage": "generated_room_before_open", "path": path, "room_id": room_id, "slot": slot, "host_screen": practice_app.current_screen, "variation": machine.get("variation_id", ""), "cost": effective_cost, "coin_value": effective_value, "expected_denomination": denomination, "stored_denomination": {"drop_cost": machine.get("drop_cost"), "coin_value": machine.get("coin_value")}, "binding": binding, "cabinet_layout": cabinet_layout, "geometry": geometry, "view": view, "scope": "normal generation/finalization, own disposable save and real Foundation Continue room viewport; no pusher opened, overlays preserved; no door pointer traversal or gameplay claim"})
	await _close_practice_host()


func _room_frame_geometry(floor: PixelSceneCanvas, cabinet_layout: Dictionary) -> Dictionary:
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var visible_rect := viewport_rect.intersection(floor.get_global_rect())
	var ancestor: Node = floor
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	var visual: Dictionary = cabinet_layout.get("rect", {})
	var board_rect := Rect2(float(visual.get("x", 0.0)), float(visual.get("y", 0.0)), float(visual.get("w", 0.0)), float(visual.get("h", 0.0)))
	# Read the canvas's measured natural artwork rect through its actual live
	# camera transforms. These helpers only convert geometry; they change no UI.
	var cabinet_rect: Rect2 = floor._local_rect_to_global_rect(floor._board_rect_to_local_rect(board_rect))
	return {"window_size": [root.size.x, root.size.y], "viewport_rect": _rect_values(viewport_rect), "host_rect": _rect_values(practice_app.get_global_rect()), "floor_rect": _rect_values(floor.get_global_rect()), "cabinet_rect": _rect_values(cabinet_rect), "interaction_rect": _rect_values(floor.global_rect_for_object("game:coin_pusher")), "effective_clip_rect": _rect_values(visible_rect), "host_matches_viewport": _rect_near(practice_app.get_global_rect(), viewport_rect), "cabinet_fully_visible": floor.is_visible_in_tree() and cabinet_rect.has_area() and visible_rect.encloses(cabinet_rect)}


func _module_case(case_id: String, variation: String, room_id: String) -> void:
	print("PUSHER_RENDER_PROGRESS case=", case_id, " stage=begin")
	game = Game.new()
	game.setup(library.game("coin_pusher"), library)
	run = RunState.new()
	run.start_new("RENDERED-COPY-" + case_id)
	run.bankroll = 500
	run.grand_casino_chips = 200
	var environment: Dictionary
	if room_id.is_empty():
		environment = {"id": case_id, "archetype_id": "bar", "world_node_id": "bar", "game_ids": ["coin_pusher"], "game_states": {}, "scenario_game_modifiers": {"coin_pusher": {"variation_id": variation}}}
	else:
		var rng := RngStream.new()
		rng.configure(JsonCoerce._overflow_stable_hash("RENDERED-ROOM-" + case_id))
		environment = EnvironmentScript.from_archetype(library.environment_archetype(room_id), 0, rng, library).to_dict()
		environment["world_node_id"] = "grand_casino"
	if not _check(bool(run.set_environment(environment).get("ok", false)), case_id + " canonical environment installation"):
		return
	run.current_environment["game_states"]["coin_pusher"] = game.generate_environment_state(run, run.current_environment, run.create_rng("rendered_pusher"))
	game.enter(run, run.current_environment)
	ui = {"surface_time_msec": 0}
	canvas = Surface.new()
	canvas.size = Vector2(WINDOW_SIZE)
	root.add_child(canvas)
	canvas.set_game_module(game)
	canvas.surface_pointer_action.connect(_pointer)
	canvas.surface_action.connect(_action)
	canvas.render_game_snapshot(game.surface_state(run, run.current_environment, ui))
	await _frames(3)
	var cost := game._drop_cost(run.current_environment)
	_check(cost == (5 if room_id == "grand_casino_high_limit" else 1), case_id + " configured denomination")
	await _capture_canvas(case_id, "idle", "DROP $%d" % cost)
	var cash := run.bankroll
	var chips := run.grand_casino_chips
	last_paid_stake = 0
	_mouse(true)
	_mouse(false)
	_check(last_paid_stake == cost and run.bankroll == cash - cost and run.grand_casino_chips == chips, case_id + " rendered single press/release buys one cash coin without spending chips")
	await _capture_canvas(case_id, "single_just_paid", "DROPPING $%d" % cost)
	if not await _drain_queue(case_id):
		_teardown_canvas()
		return
	await _capture_canvas(case_id, "single_idle", "DROP $%d" % cost)
	_mouse(true)
	var machine: Dictionary = game._ensure_live_machine(run, run.current_environment)
	var started_tick := int(game._simulation(machine).get("tick", 0))
	var deadline := Time.get_ticks_msec() + 8000
	while int(game._simulation(machine).get("tick", 0)) - started_tick < 18 and Time.get_ticks_msec() < deadline:
		await _frames(1)
		_tick()
	var held_count := int(canvas.state.get("coin_pusher_drop_payable_count", 0))
	var held_total := int(canvas.state.get("coin_pusher_drop_payable_total", 0))
	_check(held_count >= 2 and held_total == held_count * cost, case_id + " sustained rendered hold quotes multiple exact-cost coins")
	await _capture_canvas(case_id, "sustained_hold", "DROPPING $%d" % held_total)
	cash = run.bankroll
	last_paid_stake = 0
	_mouse(false)
	_check(last_paid_stake == held_total and run.bankroll == cash - held_total and run.grand_casino_chips == chips, case_id + " release charges the displayed affordable batch once")
	await _capture_canvas(case_id, "batch_just_paid", "DROPPING $%d" % held_total)
	await _frames(2)
	_tick()
	var queue_count := int(canvas.state.get("coin_pusher_drop_queue_count", 0))
	var remaining_total := int(canvas.state.get("coin_pusher_drop_queue_total", 0))
	_check(remaining_total >= 0 and remaining_total <= held_total, case_id + " feeding retains remaining paid-batch dollars")
	await _capture_canvas(case_id, "feeding", "DROPPING $%d" % remaining_total if queue_count > 0 else "DROP $%d" % cost)
	if await _drain_queue(case_id):
		await _capture_canvas(case_id, "batch_idle", "DROP $%d" % cost)
	_teardown_canvas()


func _pointer(action_id: String, index: int, phase: String, point: Vector2) -> void:
	ui["surface_time_msec"] = int(canvas.surface_simulation_clock_msec)
	var command := game.surface_pointer_command(action_id, index, phase, point, ui, run, run.current_environment)
	ui = command.get("ui_state", ui)
	_publish_command(command)


func _action(action_id: String, index: int, confirmed: bool) -> void:
	_publish_command(game.surface_action_command(action_id, index, confirmed, ui, run, run.current_environment))


func _publish_command(command: Dictionary) -> void:
	canvas.apply_surface_state_patch(command.get("surface_state_patch", {}))
	if not bool(command.get("direct_resolve", false)):
		return
	var stake := int(command.get("set_stake", 0))
	var result := game.resolve_with_context(str(command.get("action_id", "")), stake, run, run.current_environment, run.create_rng("rendered_pusher_drop"), ui)
	var applied := GameModule.apply_result(run, result)
	_check(bool(applied.get("ok", false)), "canonical result application from emitted rendered control")
	last_paid_stake = int(result.get("stake", stake))
	canvas.apply_surface_state_patch(result.get("surface_action_view_patch", {}))
	actions.append({"variation": canvas.state.get("coin_pusher_variation_id", ""), "stake": stake, "cash": run.bankroll, "chips": run.grand_casino_chips, "queue_count": canvas.state.get("coin_pusher_drop_queue_count", -1), "queue_total": canvas.state.get("coin_pusher_drop_queue_total", -1)})


func _mouse(pressed: bool) -> void:
	var position := canvas.local_position_for_surface_action(Game.DROP_CHARGE_ACTION)
	_check(position.x >= 0.0 and position.y >= 0.0, "production full draw exposes drop hit region")
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	canvas._gui_input(event)


func _tick() -> void:
	ui["surface_time_msec"] = int(canvas.surface_simulation_clock_msec)
	canvas.apply_surface_state_patch(game.surface_realtime_state_patch(run, run.current_environment, ui, canvas.state))


func _drain_queue(case_id: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while int(canvas.state.get("coin_pusher_drop_queue_count", 0)) > 0 and Time.get_ticks_msec() < deadline:
		await _frames(1)
		_tick()
	return _check(int(canvas.state.get("coin_pusher_drop_queue_count", -1)) == 0, case_id + " ordinary feeder returns to idle within bounded real-time window")


func _capture_canvas(case_id: String, stage: String, expected: String) -> void:
	print("PUSHER_RENDER_PROGRESS case=", case_id, " stage=", stage)
	canvas.queue_redraw()
	await _frames(2)
	await RenderingServer.frame_post_draw
	# Freeze both the root image and its published frame state before awaiting
	# the separate diagnostic draw. Production cache ownership remains untouched.
	var frame_state := canvas.state.duplicate(true)
	var raster := root.get_texture().get_image()
	if not _check(raster != null and not raster.is_empty(), "actual native viewport image exists: " + case_id + "/" + stage):
		return
	var label := await _probe_hardware_label(game, frame_state, canvas)
	_check(str(label.get("label", "")) == expected, case_id + "/" + stage + " matching-frame production hardware callback copy " + expected)
	_check(float(label.get("width", 9999.0)) <= LABEL_RECT.size.x and float(label.get("height", 9999.0)) <= LABEL_RECT.size.y, case_id + "/" + stage + " production font helper fits existing label bounds")
	_check(not _stale(str(label.get("label", ""))), case_id + "/" + stage + " contains no retired drop-control wording")
	var path := evidence.path_join("pusher-" + case_id + "-" + stage + ".png")
	if not _check(not FileAccess.file_exists(path), "rendered evidence is single-use: " + path):
		return
	_check(raster.save_png(path) == OK, "save actual native viewport: " + path)
	captures.append({"case": case_id, "stage": stage, "path": path, "label": label, "expected": expected, "variation": frame_state.get("coin_pusher_variation_id", ""), "cost": frame_state.get("coin_pusher_drop_cost", 0), "queue_total": frame_state.get("coin_pusher_drop_queue_total", 0), "native_backend": Solver.last_step_backend_for_test(), "scope": "full production viewport PNG with caches unchanged; label/font from separate hardware callback probe of the same captured state"})


func _practice_case() -> void:
	print("PUSHER_RENDER_PROGRESS case=default_practice_host stage=begin")
	practice_app = PracticeHost.new()
	practice_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	practice_app.set("continuous_environment_clock_enabled", false)
	practice_app.set("script_prewarm_stopping", true)
	root.add_child(practice_app)
	# Match MainScene's full anchors and ZERO offsets. Assigning an explicit
	# size before parenting adds that size as right/bottom offsets against a
	# zero-sized parent, doubling the host when the real viewport is attached.
	practice_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(4)
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(_rect_near(practice_app.get_global_rect(), viewport_rect), "Practice host matches the canonical authored logical viewport without doubled anchor offsets")
	practice_app.get("user_settings").coach_tips_enabled = false
	practice_app.call("open_game_test_menu")
	practice_app.get("game_test_seed_input").text = "COIN-SHARED-PRACTICE-RENDER"
	if _check(bool(practice_app.call("start_game_test_session", "coin_pusher").get("ok", false)), "unchanged default Practice launcher opens Coin Pusher"):
		await _frames(4)
		var practice_run: RunState = practice_app.get("run_state")
		var surface: GameSurfaceCanvas = practice_app.get("game_surface_canvas")
		var module: CoinPusherGame = practice_app.get("current_game")
		if not _check(surface != null and module != null, "default Practice owns its production canvas and module"):
			await _close_practice_host()
			return
		_check(bool(practice_run.current_environment.get("local_narrative_flags", {}).get("practice_session", false)), "real default Practice identity retained")
		var cost := module._drop_cost(practice_run.current_environment)
		await _capture_practice(surface, module, "idle", "DROP $%d" % cost)
		var point := surface.local_position_for_surface_action(Game.DROP_CHARGE_ACTION)
		_check(point.x >= 0.0, "real Practice canvas exposes shared drop control")
		var cash := practice_run.bankroll
		_practice_mouse(surface, point, true)
		_practice_mouse(surface, point, false)
		_check(practice_run.bankroll == cash - cost, "real Practice host single drop charges configured cash once")
		var renderer: Variant = module._coin_pusher_renderer()
		_check(str(renderer._drop_control_label(surface.state)) == "DROPPING $%d" % cost, "real Practice host publishes single just-paid copy synchronously")
		actions.append({"case": "default_practice_host", "stage": "single_just_paid_synchronous", "label": renderer._drop_control_label(surface.state), "cash_delta": practice_run.bankroll - cash, "scope": "before next ordinary host authority tick; not a separate PNG"})
		var deadline := Time.get_ticks_msec() + 20000
		while int(surface.state.get("coin_pusher_drop_queue_count", 0)) > 0 and Time.get_ticks_msec() < deadline:
			await _frames(1)
		_check(int(surface.state.get("coin_pusher_drop_queue_count", -1)) == 0, "real Practice host feeder returns to idle")
		await _capture_practice(surface, module, "single_idle", "DROP $%d" % cost)
		_practice_mouse(surface, point, true)
		var machine: Dictionary = module._ensure_live_machine(practice_run, practice_run.current_environment)
		var started_tick := int(module._simulation(machine).get("tick", 0))
		deadline = Time.get_ticks_msec() + 8000
		while int(module._simulation(machine).get("tick", 0)) - started_tick < 18 and Time.get_ticks_msec() < deadline:
			await _frames(1)
		_check(int(surface.state.get("coin_pusher_drop_payable_count", 0)) >= 2, "real Practice sustained hold reaches multiple quoted coins")
		await _capture_practice(surface, module, "sustained_hold", "")
		cash = practice_run.bankroll
		var quoted := int(surface.state.get("coin_pusher_drop_payable_total", 0))
		_practice_mouse(surface, point, false)
		_check(practice_run.bankroll == cash - quoted, "real Practice sustained release charges its exact live quote once")
		await _capture_practice(surface, module, "batch_feeding", "")
		deadline = Time.get_ticks_msec() + 20000
		while int(surface.state.get("coin_pusher_drop_queue_count", 0)) > 0 and Time.get_ticks_msec() < deadline:
			await _frames(1)
		_check(int(surface.state.get("coin_pusher_drop_queue_count", -1)) == 0, "real Practice batch feeder returns to idle")
		await _capture_practice(surface, module, "batch_idle", "DROP $%d" % cost)
	await _close_practice_host()


func _close_practice_host() -> void:
	if practice_app == null:
		return
	practice_app._drain_script_prewarm_requests_for_shutdown()
	practice_app.save_service.wait_for_async_save()
	practice_app.queue_free()
	await _frames(2)
	practice_app = null


func _capture_practice(surface: GameSurfaceCanvas, module: CoinPusherGame, stage: String, expected: String) -> void:
	print("PUSHER_RENDER_PROGRESS case=default_practice_host stage=", stage)
	surface.queue_redraw()
	await _frames(2)
	await RenderingServer.frame_post_draw
	# Practice keeps advancing while the probe draws, so retain the root image
	# and exact published state first. Neither is read again after that await.
	var frame_state := surface.state.duplicate(true)
	var raster := root.get_texture().get_image()
	var geometry := _practice_frame_geometry(surface)
	_check(bool(geometry.get("host_matches_viewport", false)), "Practice capture host fills the intended logical viewport: " + stage)
	_check(bool(geometry.get("drop_fully_visible", false)) and bool(geometry.get("label_fully_visible", false)), "Practice capture includes the entire real drop control and its label: " + stage)
	if not _check(raster != null and not raster.is_empty(), "actual default Practice viewport image exists"):
		return
	var label := await _probe_hardware_label(module, frame_state, surface)
	var text := str(label.get("label", ""))
	if expected.is_empty():
		# The real host continues its ordinary authority ticks while the frame is
		# drawn. Compare against the matching published live state, not a stale
		# pre-frame hold count or already-emitted single coin.
		var cost := int(frame_state.get("coin_pusher_drop_cost", 0))
		var held := int(frame_state.get("coin_pusher_drop_charge_count", 0))
		var queued := int(frame_state.get("coin_pusher_drop_queue_count", 0))
		var total := int(frame_state.get("coin_pusher_drop_queue_total", 0))
		if held > 0:
			var payable := int(frame_state.get("coin_pusher_drop_payable_count", 0))
			total = payable * cost
			_check(payable >= 2 and int(frame_state.get("coin_pusher_drop_payable_total", -1)) == total, "real Practice drawn hold reflects its exact current affordable count and cost")
			expected = "DROPPING $%d" % total
		else:
			expected = "DROPPING $%d" % total if queued > 0 else "DROP $%d" % cost
	_check(text == expected and not _stale(text), "actual default Practice shared renderer copy " + stage + ": " + expected)
	_check(float(label.get("width", 9999.0)) <= LABEL_RECT.size.x and float(label.get("height", 9999.0)) <= LABEL_RECT.size.y, "default Practice production label fit " + stage)
	var path := evidence.path_join("pusher-default-practice-" + stage + ".png")
	if not _check(not FileAccess.file_exists(path), "Practice evidence is single-use"):
		return
	_check(raster.save_png(path) == OK, "save actual default Practice viewport " + stage)
	captures.append({"case": "default_practice_host", "stage": stage, "path": path, "label": label, "expected": expected, "variation": frame_state.get("coin_pusher_variation_id", ""), "cost": frame_state.get("coin_pusher_drop_cost", 0), "geometry": geometry, "scope": "actual default Practice/Foundation host PNG with caches unchanged; matching frozen-frame hardware callback probe"})


func _practice_frame_geometry(surface: GameSurfaceCanvas) -> Dictionary:
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var host_rect := practice_app.get_global_rect()
	var surface_rect := surface.get_global_rect()
	var drop_rect := surface.global_rect_for_surface_action(Game.DROP_CHARGE_ACTION)
	var label_rect := surface.global_rect_for_design_rect(LABEL_RECT)
	var visible_rect := viewport_rect.intersection(surface_rect)
	var ancestor: Node = surface
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return {"window_size": [root.size.x, root.size.y], "content_scale_size": [root.content_scale_size.x, root.content_scale_size.y], "viewport_rect": _rect_values(viewport_rect), "host_rect": _rect_values(host_rect), "surface_rect": _rect_values(surface_rect), "drop_rect": _rect_values(drop_rect), "label_rect": _rect_values(label_rect), "effective_clip_rect": _rect_values(visible_rect), "host_matches_viewport": _rect_near(host_rect, viewport_rect), "drop_fully_visible": surface.is_visible_in_tree() and drop_rect.has_area() and visible_rect.encloses(drop_rect), "label_fully_visible": surface.is_visible_in_tree() and label_rect.has_area() and visible_rect.encloses(label_rect)}


func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _rect_near(first: Rect2, second: Rect2) -> bool:
	return first.position.distance_to(second.position) <= 1.0 and first.size.distance_to(second.size) <= 1.0


func _probe_hardware_label(module: CoinPusherGame, frame_state: Dictionary, source_surface: GameSurfaceCanvas) -> Dictionary:
	# A retained child owns the visible hardware draw in production; a subclass
	# of the root canvas cannot intercept its label call. Probe the SAME public
	# production hardware-cache layer in a detached viewport, without disabling
	# that cache, changing its host, or compositing test graphics into the PNG.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 430)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := HardwareLabelProbe.new()
	probe.renderer = module._coin_pusher_renderer()
	probe.fixture_state = frame_state
	probe.size = Vector2(900, 430)
	var theme := Theme.new()
	theme.default_font = source_surface.get_theme_default_font()
	theme.default_font_size = source_surface.get_theme_default_font_size()
	probe.theme = theme
	viewport.add_child(probe)
	probe.queue_redraw()
	await _frames(2)
	await RenderingServer.frame_post_draw
	var captured := probe.drawn_drop.duplicate(true)
	viewport.free()
	return captured


func _practice_mouse(surface: GameSurfaceCanvas, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	surface._gui_input(event)


func _teardown_canvas() -> void:
	canvas.clear_runtime_state()
	canvas.queue_free()
	canvas = null
	game = null
	run = null
	ui = {}


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _stale(text: String) -> bool:
	return text.contains("DROP/HOLD") or text.begins_with("HOLD ") or text.begins_with("PAID ")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	if admitted:
		var expected_captures := 2 if rooms_only else (5 if practice_only else 40)
		_check(captures.size() == expected_captures, "selected rendered suite reaches every requested capture stage")
	var output := ""
	if admitted:
		output = OS.get_environment("BTH_TARGET_OUTPUT")
		if output.is_empty():
			output = evidence.path_join("coin-pusher-rendered-copy-result.json")
		_check(not FileAccess.file_exists(output), "rendered result evidence is single-use")
	var mode := "rooms_only" if rooms_only else ("practice_only" if practice_only else "full")
	var report := {"checks": checks, "failures": failures, "captures": captures, "actions": actions, "backend": DisplayServer.get_name(), "mode": mode, "scope": "Actual native windowed viewport and full production Canvas draw with normal retained caches unchanged. Label/font evidence comes from a separate, uncomposited production hardware-cache-layer draw callback probe of the exact captured frame state. Full mode covers explicit synthetic $1 variants and seeded Grand rooms through real Canvas/canonical module results; practice_only runs the actual default Practice/Foundation host with viewport/control visibility checks; rooms_only captures two normally generated Grand rooms through own disposable saves and normal Foundation Continue, before opening pusher. Room overlays remain unchanged; door pointer traversal is not claimed. No original save, natural payout, Web pixels, or broad performance acceptance claimed."}
	if admitted and not FileAccess.file_exists(output):
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("COIN_PUSHER_RENDERED_COPY_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
