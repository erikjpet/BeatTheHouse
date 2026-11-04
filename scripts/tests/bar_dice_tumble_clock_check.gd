extends SceneTree

# Synthetic model/canvas clock contract, not a player-save or Web reproduction.
# Authored model buttons are registered on the real canvas with their existing
# console geometry because headless rendering need not issue draw callbacks.
# Real canvas input/gating emits the public surface_action signal; the module
# handles that signal normally. Full Host settlement/persistence is separate.
const Game := preload("res://scripts/games/bar_dice.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const DURATION := Game.TUMBLE_DURATION_MSEC
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"scope": "Synthetic generated table, real BarDice model and canvas input/clock contract; no original save, Host settlement, drawn-pixel or Web acceptance claim", "cases": {}}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-") and ProjectSettings.globalize_path("user://").contains("native-private-"), "explicit private storage roots required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured or original browser inputs"):
		_finish(); return
	root.size = Vector2i(1280, 720)
	var library := ContentLibrary.new()
	library.load(false)
	await _case(library, "future_epoch", false, false)
	await _case(library, "paused_future_epoch", false, true)
	await _case(library, "reduced_motion", true, false)
	_finish()

func _case(library: ContentLibrary, label: String, reduced: bool, paused: bool) -> void:
	var run := RunState.new()
	run.start_new("SYNTHETIC-BAR-DICE-TUMBLE-CLOCK-" + label)
	var game := Game.new()
	game.definition = library.game("bar_dice")
	var environment := {"id": "synthetic_tumble_" + label, "archetype_id": "bar", "economic_profile": {"stake_floor": 9, "stake_ceiling": 25}, "game_states": {}}
	var table := game.generate_environment_state(run, environment, run.create_rng("synthetic_table"))
	environment["game_states"] = {"bar_dice": table}
	run.current_environment = environment
	var epoch := Time.get_ticks_msec() + 180000
	var ui := {"surface_time_msec": epoch, "selected_stake_index": 0, "reduce_motion": reduced}
	var roll: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, ui, run, environment)
	ui = roll.get("ui_state", {})
	_check(str(ui.get("bar_dice_ritual_phase", "")) == "cover", label + " normal Roll reaches Cover")
	var cover: Dictionary = game.surface_action_command("bar_dice_ack_cover", 0, false, ui, run, environment)
	ui = cover.get("ui_state", {})
	if not _check(str(ui.get("bar_dice_ritual_phase", "")) == "shake" and bool(ui.get("rolled", false)), label + " normal Take Cover opens one generated cup"):
		return
	var cup := _cup(ui)
	var durable := Runtime.content_fingerprint(run.to_dict())
	var rng := run.rng_state
	var receipts := Runtime.content_fingerprint(table.get(Authority.LEDGER_KEY, {}))
	var canvas := Canvas.new()
	canvas.size = Vector2(1280, 720)
	root.add_child(canvas)
	var emitted: Array = []
	var blocked: Array = []
	canvas.surface_action.connect(func(action: String, index: int, confirm: bool):
		emitted.append(action)
		ui["surface_time_msec"] = canvas.surface_simulation_time_msec()
		var command: Dictionary = game.surface_action_command(action, index, confirm, ui, run, environment)
		var next: Dictionary = command.get("ui_state", ui).duplicate(true)
		ui.clear(); ui.merge(next, true)
	)
	canvas.surface_action_blocked.connect(func(action: String, _reason: String): blocked.append(action))
	_render(game, run, environment, ui, canvas)
	var case_facts := {"surface_epoch": epoch, "engine_msec_at_start": Time.get_ticks_msec(), "duration_msec": DURATION, "clock_source": canvas.surface_animation_channels.get(Game.TUMBLE_CHANNEL, {}).get("clock_source", "realtime"), "reduced_motion": reduced, "paused": paused}
	if reduced:
		_check(not canvas.surface_animation_active(Game.TUMBLE_CHANNEL), label + " reduced motion removes only cosmetic tumble gate")
		_click(canvas, "bar_dice_resolve")
		_check(emitted == ["bar_dice_resolve"] and str(ui.get("bar_dice_ritual_phase", "")) == "throw", label + " public Settle signal progresses same cup immediately")
	else:
		_check(canvas.surface_animation_active(Game.TUMBLE_CHANNEL), label + " fresh tumble remains active before900ms")
		_click(canvas, "bar_dice_resolve")
		_check(emitted.is_empty() and blocked == ["bar_dice_resolve"] and str(ui.get("bar_dice_ritual_phase", "")) == "shake", label + " early real canvas Settle remains blocked")
		if paused:
			canvas.set_environment_activity_paused(true)
			var paused_clock := canvas.surface_simulation_time_msec()
			await create_timer(1.05).timeout
			_check(canvas.surface_simulation_time_msec() == paused_clock and canvas.surface_animation_active(Game.TUMBLE_CHANNEL), label + " pause retains simulation-clock gate without advancing cup")
			canvas.set_environment_activity_paused(false)
		var started := int(ui.get("tumble_started_msec", epoch))
		var reached := await _wait_for_surface(canvas, started + DURATION + 120)
		_check(reached, label + " autonomous no-pointer surface clock crosses tumble duration")
		var read_ui := ui.duplicate(true)
		read_ui["surface_time_msec"] = canvas.surface_simulation_time_msec()
		case_facts["surface_elapsed_msec"] = canvas.surface_simulation_time_msec() - started
		case_facts["engine_msec_at_expiry"] = Time.get_ticks_msec()
		case_facts["model_active_at_expiry"] = game._tumble_is_active(game._active_tumble(read_ui, {}, true), read_ui)
		case_facts["canvas_active_at_expiry"] = canvas.surface_animation_active(Game.TUMBLE_CHANNEL)
		_check(not bool(case_facts.model_active_at_expiry), label + " model acknowledges completed tumble")
		_check(not bool(case_facts.canvas_active_at_expiry), label + " real canvas completes same tumble in matching clock epoch")
		_check(_cup(ui) == cup and run.rng_state == rng and Runtime.content_fingerprint(run.to_dict()) == durable, label + " passive animation preserves exact cup money RNG and durable receipts")
		# Rebuilding an unchanged view must not restart the accepted animation.
		ui["surface_time_msec"] = canvas.surface_simulation_time_msec()
		_render(game, run, environment, ui, canvas)
		_check(not canvas.surface_animation_active(Game.TUMBLE_CHANNEL), label + " ordinary model rebuild never restarts completed tumble")
		_check(Runtime.content_fingerprint(run.to_dict()) == durable and Runtime.content_fingerprint(table.get(Authority.LEDGER_KEY, {})) == receipts, label + " model rebuild changes no durable state or receipt envelope")
		_click(canvas, "bar_dice_resolve")
		_check(emitted == ["bar_dice_resolve"] and str(ui.get("bar_dice_ritual_phase", "")) == "throw", label + " real canvas public Settle progresses same warm cup after expiry")
	_check(_cup(ui) == cup and run.rng_state == rng and Runtime.content_fingerprint(run.to_dict()) == durable, label + " phase-only Settle preserves generated dice wager account and RNG")
	case_facts["emitted"] = emitted
	case_facts["blocked"] = blocked
	case_facts["final_phase"] = ui.get("bar_dice_ritual_phase", "")
	facts.cases[label] = case_facts
	canvas.queue_free()
	await process_frame

func _render(game: GameModule, run: RunState, environment: Dictionary, ui: Dictionary, canvas: GameSurfaceCanvas) -> void:
	var view: Dictionary = game.surface_state(run, environment, ui)
	# Same host clock augmentation as Foundation; do not replace channel clocks.
	view["surface_time_msec"] = int(ui.get("surface_time_msec", 0))
	view["surface_presentation_time_msec"] = int(ui.get("surface_time_msec", 0))
	view["reduce_motion"] = bool(ui.get("reduce_motion", false))
	canvas.render_game_snapshot(view)
	canvas.hit_regions.clear()
	var buttons: Array = view.get("bar_dice_action_buttons", [])
	var widths: Array = Game.CONSOLE_SELECT_BUTTON_WIDTHS if str(view.get("phase", "")) == "select" else Game.CONSOLE_ROLL_BUTTON_WIDTHS
	var x := 428.0
	for i in range(mini(buttons.size(), widths.size())):
		var button: Dictionary = buttons[i]
		if bool(button.get("enabled", true)):
			canvas.surface_add_exact_hit(Rect2(x, Game.CONSOLE_Y + 13, float(widths[i]), 44), str(button.get("action", "")), int(button.get("index", 0)))
		x += float(widths[i]) + 8.0

func _click(canvas: GameSurfaceCanvas, action: String) -> void:
	for region in canvas.hit_regions:
		if str(region.get("action", "")) != action: continue
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = canvas._board_to_screen((region.get("rect", Rect2()) as Rect2).get_center())
		canvas._gui_input(event)
		return
	_check(false, "authored model exposes input control " + action)

func _wait_for_surface(canvas: GameSurfaceCanvas, target: int) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while canvas.surface_simulation_time_msec() < target and Time.get_ticks_msec() < deadline:
		await process_frame
	return canvas.surface_simulation_time_msec() >= target

func _cup(ui: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["dice", "reroll", "shake_number", "selected_stake_index", "tumble_id", "tumble_started_msec", "tumble_indices"]:
		result[key] = ui.get(key)
	return result.duplicate(true)

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	facts["source_sha256"] = {}
	for path in ["scripts/games/bar_dice.gd", "scripts/ui/game_surface_canvas.gd", "scripts/core/game_module.gd", "scripts/tests/bar_dice_tumble_clock_check.gd"]:
		facts.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	var result := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("BAR_DICE_TUMBLE_CLOCK ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
