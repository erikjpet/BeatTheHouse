extends SceneTree

const PUSHER_V3_PERF_TICKS := 24
const JackpotRidgeVariationScript := preload("res://scripts/games/coin_pusher/jackpot_ridge.gd")
const VaultDropVariationScript := preload("res://scripts/games/coin_pusher/vault_drop.gd")
const PusherGameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")


func _check_coin_pusher_contract(library: ContentLibrary, failures: Array) -> void:
	var game_definition := library.game("coin_pusher")
	if game_definition.is_empty():
		failures.append("Coin Pusher game definition is missing.")
		return
	var machine_definition: Dictionary = game_definition.get("coin_pusher_machine", {}) if typeof(game_definition.get("coin_pusher_machine", {})) == TYPE_DICTIONARY else {}
	_check_pusher_v3_machine_data(machine_definition, failures)
	_check_pusher_v3_10_idle_queue_cups_and_stack(library, game_definition, machine_definition, failures)
	_check_pusher_v3_10_hold_inputs(library, game_definition, failures)
	_check_pusher_v3_coin_scale_lower_bed_and_edge_ramp(machine_definition, failures)
	_check_pusher_v3_played_in_opening_state(library, game_definition, failures)
	_check_pusher_v3_plinko_bounce_and_variance(machine_definition, failures)
	_check_pusher_v3_alive_cabinet(library, machine_definition, failures)
	_check_pusher_v3_presentation_view(machine_definition, failures)
	_check_pusher_v3_rejected_mechanics_deleted(failures)
	_check_pusher_v3_landing_skill(machine_definition, failures)
	_check_pusher_v3_stocked_phase_topology(machine_definition, failures)
	_check_pusher_v3_nestle(machine_definition, failures)
	_check_pusher_v3_face_push(machine_definition, failures)
	_check_pusher_v3_collective_ratchet(machine_definition, failures)
	_check_pusher_v3_no_lattice(machine_definition, failures)
	_check_pusher_v3_skill_stop(machine_definition, failures)
	_check_pusher_v3_tray_gutter_ceiling(machine_definition, failures)
	_check_pusher_v3_energy_settle_conservation(machine_definition, failures)
	_check_pusher_v3_real_weight_gravity(machine_definition, failures)
	_check_pusher_v3_irregular_supported_piles(machine_definition, failures)
	_check_pusher_v3_contact_only_pressure(machine_definition, failures)
	_check_pusher_v3_visible_terminal_falls(machine_definition, failures)
	_check_pusher_v3_input_trace_determinism(machine_definition, failures)
	_check_pusher_v3_ridge_physical_contract(library, failures)
	_check_pusher_v3_vault_physical_contract(library, failures)
	_check_pusher_v3_live_loop_and_persistence(machine_definition, failures)
	_check_pusher_v3_production_rail_drag(library, failures)
	_check_pusher_v3_all_variation_migrations(library, failures)
	_check_pusher_v3_v2_production_migration(library, failures)
	_check_pusher_v3_production_integration_boundaries(library, failures)
	_check_pusher_v3_items_alarm_and_rumor(library, failures)
	_check_pusher_v3_generated_rider_production(library, failures)
	_check_pusher_v3_solver_performance(machine_definition, failures)


func _check_pusher_v3_10_idle_queue_cups_and_stack(library: ContentLibrary, game_definition: Dictionary, machine: Dictionary, failures: Array) -> void:
	var opening := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-10-IDLE"), machine, 150)
	var third_counts := [0, 0, 0]
	for body_value in opening.get("bodies", []):
		var body: Dictionary = body_value
		third_counts[clampi(int(body.get("x", 0)) * 3 / int((machine.get("geometry", {}) as Dictionary).get("width", 100000)), 0, 2)] += 1
	var idle_before := CoinPusherSolverScript.canonical_digest(opening)
	var idle_result := CoinPusherSolverScript.step_ticks_reference_for_test(opening, {"motor_enabled": false}, 1200)
	var idle_after := CoinPusherSolverScript.canonical_digest(opening)
	if third_counts.min() < 24 or idle_before.get("bodies", []) != idle_after.get("bodies", []) or idle_before.get("tray_ledger", []) != idle_after.get("tray_ledger", []) or not (idle_result.get("events", []) as Array).is_empty() or int(opening.get("motor_rate_fp", -1)) != 0:
		failures.append("pusherv3_10 opening is not full-width and inert for five historical stroke periods: thirds=%s events=%d motor=%d." % [JSON.stringify(third_counts), (idle_result.get("events", []) as Array).size(), int(opening.get("motor_rate_fp", -1))])

	var queue_machine := {"simulation": CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-10-QUEUE"), machine, 0), "variation_state": {}, "drop_queue": [], "motor_started": false}
	CoinPusherLiveSessionScript.begin(queue_machine, machine, 7710)
	var queued := CoinPusherLiveSessionScript.enqueue_drops(queue_machine, {"nozzle_id": "quarter_rail", "density": 1, "provenance": {"test": true}}, 30)
	var now_msec := 0
	CoinPusherLiveSessionScript.advance(queue_machine, now_msec)
	for frame in range(70):
		now_msec += 50
		if frame == 20:
			CoinPusherSolverScript.set_carriage(queue_machine["simulation"], 85000)
		CoinPusherLiveSessionScript.advance(queue_machine, now_msec)
	var queued_bodies: Array = (queue_machine.get("simulation", {}) as Dictionary).get("bodies", [])
	var saw_left := false
	var saw_right := false
	for body_value in queued_bodies:
		var provenance: Dictionary = ((body_value as Dictionary).get("meta", {}) as Dictionary).get("provenance", {}) if typeof((body_value as Dictionary).get("meta", {})) == TYPE_DICTIONARY else {}
		if str(provenance.get("source_nozzle_id", "")) != "quarter_rail":
			continue
		saw_left = saw_left or int((body_value as Dictionary).get("x", 50000)) < 50000
		saw_right = saw_right or int((body_value as Dictionary).get("x", 50000)) > 70000
	if queued != 30 or int((queue_machine.get("simulation", {}) as Dictionary).get("accepted_inserts", 0)) != 30 or not bool(queue_machine.get("motor_started", false)) or not (queue_machine.get("drop_queue", []) as Array).is_empty() or not saw_left or not saw_right:
		failures.append("pusherv3_10 30-coin FIFO did not emit at cadence from a steerable bound rail nozzle.")

	var ridge: Dictionary = (machine.get("machines", {}) as Dictionary).get("jackpot_ridge", {})
	var target: Dictionary = ((ridge.get("apparatus", {}) as Dictionary).get("targets", []) as Array)[0]
	var cup_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-10-CUP"), ridge, 0)
	var cup_coin := CoinPusherSolverScript.add_coin(cup_state, _pusher_v3_rng("PUSHER-V3-10-CUP-COIN"), int(target.get("x", 0)), 1, {"source_nozzle_id": "ridge_left", "chain_depth": 0})
	cup_coin["x"] = int(target.get("x", 0))
	cup_coin["z"] = int(target.get("z", 0))
	cup_coin["vx"] = 0
	cup_coin["vz"] = -1000
	var cup_result := CoinPusherSolverScript.step_ticks_reference_for_test(cup_state, {"motor_enabled": false}, 1)
	var cup_events: Array = (cup_result.get("events", []) as Array).filter(func(event): return str((event as Dictionary).get("kind", "")) == "plinko_cup")
	if cup_events.size() != 1 or int(cup_state.get("cup_consumed_count", 0)) != 1 or not (cup_state.get("bodies", []) as Array).is_empty() or not bool((cup_result.get("invariants", {}) as Dictionary).get("conservation_ok", false)):
		failures.append("pusherv3_10 cup did not consume and conserve its physical trigger exactly once.")

	var game: GameModule = load(str(game_definition.get("module_path", ""))).new()
	game.setup(game_definition, library)
	var chain_machine := {"variation_id": "jackpot_ridge", "simulation": CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-10-CHAIN"), ridge, 0), "variation_state": {}, "drop_queue": [], "motor_started": false}
	CoinPusherLiveSessionScript.begin(chain_machine, ridge, 7711)
	game.call("_consume_physics_events", null, chain_machine, cup_events, _pusher_v3_rng("PUSHER-V3-10-CHAIN-RNG"))
	var chain_queue: Array = chain_machine.get("drop_queue", [])
	if chain_queue.size() != 1 or int((chain_queue[0] as Dictionary).get("remaining", 0)) != 5 or str((chain_queue[0] as Dictionary).get("nozzle_id", "")) != "ridge_left" or int((chain_queue[0] as Dictionary).get("chain_depth", 0)) != 1:
		failures.append("pusherv3_10 5X cup did not enqueue five bounded children through the trigger nozzle.")

	var stack_definition := machine.duplicate(true)
	(stack_definition.get("apparatus", {}) as Dictionary)["pegs"] = []
	var stack_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-10-STACK"), stack_definition, 0)
	var left := _pusher_v3_body_fixture("support_left", 47600, 30000, 0, true, "deck")
	var right := _pusher_v3_body_fixture("support_right", 52400, 30000, 0, true, "deck")
	var upper := _pusher_v3_body_fixture("upper_drop", 50000, 30000, 600, false, "")
	for stack_body in [left, right, upper]:
		stack_body["radius"] = 2350
		stack_body["height"] = 950
	upper["rest_state"] = "falling"
	upper["vz"] = -1000
	upper["meta"] = {"value": 1, "inserted": true}
	stack_state["bodies"] = [left, right, upper]
	stack_state["opening_body_count"] = 2
	stack_state["accepted_inserts"] = 1
	var supports_before := [int(left.get("x", 0)), int(right.get("x", 0))]
	var stack_events: Array = []
	for _tick in range(12):
		stack_events.append_array((CoinPusherSolverScript.step_ticks_reference_for_test(stack_state, {"motor_enabled": false}, 1)).get("events", []))
	var resolved_left := _pusher_v3_body(stack_state, "support_left")
	var resolved_right := _pusher_v3_body(stack_state, "support_right")
	var landing_events: Array = stack_events.filter(func(event): return str((event as Dictionary).get("body_id", "")) == "upper_drop" and bool((event as Dictionary).get("first_support", false)))
	if [int(resolved_left.get("x", 0)), int(resolved_right.get("x", 0))] != supports_before or landing_events.is_empty() or str((landing_events[0] as Dictionary).get("landing_quality", "")) != "supported_bad":
		failures.append("pusherv3_10 upper landing separated its supports or lost supported-bad classification.")
	var audio_events: Array = game.call("_presentation_audio_events", chain_machine, [{"kind": "impact", "first_support": true, "landing_quality": "bed_level_good"}, {"kind": "impact", "first_support": true, "landing_quality": "supported_bad"}])
	if audio_events.filter(func(event): return str((event as Dictionary).get("kind", "")) == "good_drop").size() != 1 or audio_events.filter(func(event): return str((event as Dictionary).get("kind", "")) == "bad_drop").size() != 1:
		failures.append("pusherv3_10 good/bad landing feedback was not classified exactly once.")


func _check_pusher_v3_10_hold_inputs(library: ContentLibrary, game_definition: Dictionary, failures: Array) -> void:
	# The shared canvas must expose the same captured begin/end lifecycle for
	# mouse, touch, keyboard, and controller. It remains game-agnostic: only the
	# renderer opts a region into confirm-action hold input.
	var canvas: Control = PusherGameSurfaceCanvasScript.new()
	canvas.size = Vector2(768, 432)
	root.add_child(canvas)
	var phases: Array = []
	canvas.surface_pointer_action.connect(func(action: String, _index: int, phase: String, _position: Vector2) -> void:
		if action == "fixture_hold":
			phases.append(phase)
	)
	canvas.call("surface_add_hold_hit", Rect2(40, 40, 80, 60), "fixture_hold")
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = Vector2(80, 70)
	canvas.call("_gui_input", mouse_press)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	mouse_release.position = mouse_press.position
	canvas.call("_gui_input", mouse_release)
	canvas.set("last_mouse_press_msec", -100000)
	var touch_press := InputEventScreenTouch.new()
	touch_press.pressed = true
	touch_press.position = mouse_press.position
	canvas.call("_gui_input", touch_press)
	var touch_release := InputEventScreenTouch.new()
	touch_release.pressed = false
	touch_release.position = mouse_press.position
	canvas.call("_gui_input", touch_release)
	var key_press := InputEventKey.new()
	key_press.keycode = KEY_ENTER
	key_press.pressed = true
	canvas.call("_gui_input", key_press)
	var key_release := InputEventKey.new()
	key_release.keycode = KEY_ENTER
	key_release.pressed = false
	canvas.call("_gui_input", key_release)
	var joy_press := InputEventJoypadButton.new()
	joy_press.button_index = JOY_BUTTON_A
	joy_press.pressed = true
	canvas.call("_gui_input", joy_press)
	var joy_release := InputEventJoypadButton.new()
	joy_release.button_index = JOY_BUTTON_A
	joy_release.pressed = false
	canvas.call("_gui_input", joy_release)
	canvas.call("_gui_input", key_press)
	canvas.notification(Control.NOTIFICATION_FOCUS_EXIT)
	canvas.call("_gui_input", key_release)
	if phases != ["begin", "end", "begin", "end", "begin", "end", "begin", "end", "begin", "cancel"]:
		failures.append("pusherv3_10 shared hold input did not preserve mouse/touch/keyboard/controller equivalence and focus-loss cancellation: %s." % JSON.stringify(phases))
	canvas.queue_free()

	var game: GameModule = load(str(game_definition.get("module_path", ""))).new()
	game.setup(game_definition, library)
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-10-HOLD", RunState.standard_challenge("PUSHER-V3-10-HOLD"))
	run_state.bankroll = 1000
	var environment := {"id": "pusher_v3_10_hold", "world_node_id": "pusher_v3_10_hold", "game_states": {}}
	var generated: Dictionary = game.generate_environment_state(run_state, environment, _pusher_v3_rng("PUSHER-V3-10-HOLD-GENERATE"))
	environment["game_states"] = {"coin_pusher": generated}
	game.enter(run_state, environment)
	var frame_rates := [30, 60, 120]
	for frame_rate in frame_rates:
		var begin: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "begin", Vector2(576, 374), {}, run_state, environment)
		var live_map: Dictionary = game.get("_live_machines")
		var live: Dictionary = live_map.values()[0] if not live_map.is_empty() else {}
		var simulation: Dictionary = live.get("simulation", {}) if typeof(live.get("simulation", {})) == TYPE_DICTIONARY else {}
		simulation["tick"] = int(simulation.get("tick", 0)) + 180
		var ending: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "end", Vector2(576, 374), begin.get("ui_state", {}), run_state, environment)
		if not bool(ending.get("direct_resolve", false)) or str(ending.get("action_id", "")) != "drop_quarter" or int(ending.get("set_stake", 0)) != 30:
			failures.append("pusherv3_10 three-second hold was not exactly 30 coins at the %d FPS presentation rate: %s." % [frame_rate, JSON.stringify(ending)])
			break
	var tap_begin: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "begin", Vector2(576, 374), {}, run_state, environment)
	var tap_end: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "end", Vector2(576, 374), tap_begin.get("ui_state", {}), run_state, environment)
	if int(tap_end.get("set_stake", 0)) != 1:
		failures.append("pusherv3_10 tap did not reserve exactly one coin.")
	run_state.bankroll = 7
	var limited_begin: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "begin", Vector2(576, 374), {}, run_state, environment)
	var limited_live_map: Dictionary = game.get("_live_machines")
	var limited_live: Dictionary = limited_live_map.values()[0] if not limited_live_map.is_empty() else {}
	var limited_simulation: Dictionary = limited_live.get("simulation", {}) if typeof(limited_live.get("simulation", {})) == TYPE_DICTIONARY else {}
	limited_simulation["tick"] = int(limited_simulation.get("tick", 0)) + 180
	var limited_end: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "end", Vector2(576, 374), limited_begin.get("ui_state", {}), run_state, environment)
	if int(limited_end.get("set_stake", 0)) != 7:
		failures.append("pusherv3_10 hold did not truncate atomically to seven affordable coins: %s." % JSON.stringify(limited_end))
	run_state.bankroll = 1000
	var cancel_begin: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "begin", Vector2(576, 374), {}, run_state, environment)
	var cancelled: Dictionary = game.surface_pointer_command("coin_pusher_drop_charge", 0, "cancel", Vector2(576, 374), cancel_begin.get("ui_state", {}), run_state, environment)
	var cancelled_ui: Dictionary = cancelled.get("ui_state", {}) if typeof(cancelled.get("ui_state", {})) == TYPE_DICTIONARY else {}
	if bool(cancelled.get("direct_resolve", false)) or cancelled_ui.has("coin_pusher_drop_charge_started_tick") or int(cancelled_ui.get("coin_pusher_drop_charge_count", -1)) != 0:
		failures.append("pusherv3_10 interrupted hold committed a wager or retained stale charge state: %s." % JSON.stringify(cancelled))


func _check_pusher_v3_alive_cabinet(library: ContentLibrary, machine: Dictionary, failures: Array) -> void:
	var cabinet: Dictionary = machine.get("cabinet", {}) if typeof(machine.get("cabinet", {})) == TYPE_DICTIONARY else {}
	var variations: Dictionary = cabinet.get("variations", {}) if typeof(cabinet.get("variations", {})) == TYPE_DICTIONARY else {}
	var identities := [str(cabinet.get("identity", ""))]
	for variation_id in ["jackpot_ridge", "vault_drop"]:
		var variant: Dictionary = variations.get(variation_id, {}) if typeof(variations.get(variation_id, {})) == TYPE_DICTIONARY else {}
		identities.append(str(variant.get("identity", "")))
		if str(variant.get("marquee", "")).is_empty() or str(variant.get("palette", "")).is_empty() or str(variant.get("topper_style", "")).is_empty() or (variant.get("colors", {}) as Dictionary).size() < 8 or (variant.get("backglass_display", {}) as Dictionary).is_empty() or (variant.get("body_colors", {}) as Dictionary).is_empty():
			failures.append("Coin Pusher V3 %s cabinet catalog entry is incomplete." % variation_id)
	if identities != ["quarter_falls", "jackpot_ridge", "vault_drop"] or (cabinet.get("colors", {}) as Dictionary).size() < 8:
		failures.append("Coin Pusher V3 cabinet catalog lost one of the three authored identities: %s." % JSON.stringify(identities))
	var game_definition := library.game("coin_pusher")
	var module_script: Script = load(str(game_definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 alive-cabinet test could not load the production module.")
		return
	var game: GameModule = module_script.new()
	game.setup(game_definition, library)
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-CABINET", RunState.standard_challenge("PUSHER-V3-CABINET"))
	var environment := {"id": "pusher_v3_cabinet_fixture", "world_node_id": "pusher_v3_cabinet_fixture", "scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls"}}, "game_states": {}}
	var generated: Dictionary = game.generate_environment_state(run_state, environment, _pusher_v3_rng("PUSHER-V3-CABINET-GENERATION"))
	environment["game_states"] = {"coin_pusher": generated}
	game.enter(run_state, environment)
	var initial := game.surface_state(run_state, environment, {})
	var signature: Dictionary = game.renderer_signature(initial)
	var audio: Dictionary = initial.get("surface_audio", {}) if typeof(initial.get("surface_audio", {})) == TYPE_DICTIONARY else {}
	if str(initial.get("surface_life", "")) != "coin_pusher_v3_alive_cabinet" or not bool(initial.get("coin_pusher_alive_cabinet", false)) or bool(initial.get("coin_pusher_v3_headless_placeholder", false)):
		failures.append("Coin Pusher V3 production surface did not replace the Stage-2 placeholder with the alive cabinet.")
	var playfield_rect: Rect2 = signature.get("playfield_rect", Rect2())
	var cabinet_rect: Rect2 = signature.get("cabinet_rect", Rect2())
	var marquee_rect: Rect2 = signature.get("marquee_rect", Rect2())
	var backglass_rect: Rect2 = signature.get("backglass_rect", Rect2())
	var front_contact_radius := float(signature.get("front_contact_radius_px", 0.0))
	var rear_contact_radius := float(signature.get("rear_contact_radius_px", 0.0))
	if float(signature.get("rear_width_factor", 0.0)) != 0.78 or not is_equal_approx(float(signature.get("coin_rx", 0.0)), front_contact_radius) or rear_contact_radius <= 0.0 or rear_contact_radius >= front_contact_radius or float(signature.get("coin_ry", 0.0)) != 12.0 or float(signature.get("z_layer_offset", 0.0)) != 10.0 or float(signature.get("playfield_width_ratio", 0.0)) < 0.70 or float(signature.get("playfield_height_ratio", 0.0)) < 0.60 or playfield_rect.intersects(marquee_rect) or playfield_rect.intersects(backglass_rect) or not cabinet_rect.encloses(playfield_rect) or int(signature.get("rotation_frames", 0)) != 4 or not bool(signature.get("depth_sorted", false)) or int(signature.get("batch_draws", -1)) != 1 or int(signature.get("batched_nodes", -1)) != 0 or int(signature.get("per_coin_nodes", -1)) != 0 or signature.get("draw_order", []) != ["shadows", "coin_batch", "feature_labels", "payout_edge_face", "glass", "hardware"]:
		failures.append("Coin Pusher V3 lost the playfield-dominant physical-contact/four-frame batched projection contract: %s." % JSON.stringify(signature))
	var renderer = load("res://scripts/games/coin_pusher/coin_pusher_renderer.gd").new()
	var canvas_source := FileAccess.get_file_as_string("res://scripts/ui/game_surface_canvas.gd")
	if not canvas_source.contains("draw_multimesh(multimesh, texture)") or canvas_source.contains("MultiMeshInstance2D.new()"):
		failures.append("Coin Pusher V3 coin batch is not drawn in exact parent CanvasItem order.")
	var hostile_state := {
		"surface_renderer": "coin_pusher",
		"coin_pusher_cabinet": {
			"identity": "hostile_custom_identity", "marquee": "UNRECOGNIZED", "palette": "hostile_custom_palette", "topper_style": "none",
			"backglass_display": {"style": "value_lamps", "value_state_key": "hostile_value", "lamp_count": 3, "label_template": "CUSTOM %d"},
			"body_colors": {"default": "#112233", "artifact": "#123456"}, "body_labels": {"artifact": "Z9"},
			"colors": {"body": "#010203", "side": "#040506", "trim": "#070809", "light": "#0a0b0c", "glass": "#0d0e0f", "deck": "#101112", "platform": "#131415", "backglass": "#161718"},
		},
		"coin_pusher_geometry": {"width": 200000, "back_plate_y": 80000, "deck_polygon": [[0, 6000, 0], [200000, 6000, 0], [185000, 42000, 0], [100000, 50000, 0], [15000, 42000, 0]]},
		"coin_pusher_apparatus": {"type": "hole_set", "holes": [22000, 97000, 181000], "drop_board": {"y": 80000, "z_top": 26000, "z_bottom": 3600, "x_min": 5000, "x_max": 195000}},
		"coin_pusher_variation_id": "hostile_fourth_apparatus",
		"coin_pusher_feature_hardware": {"selector_groups": [{"rect": Rect2(700, 300, 72, 18), "selected": "odd", "options": [{"id": "odd", "label": "ODD", "action": "hostile_selector"}]}], "panels": [{"rect": Rect2(120, 382, 400, 36), "controls": [{"rect": Rect2(128, 388, 92, 24), "label": "ALIEN", "action": "hostile_panel", "index": 7}]}]},
		"surface_action_bindings": {"hostile_selector": {"enabled": true}, "hostile_panel": {"enabled": true}},
		"coin_pusher_coin_height": 2500,
		"coin_pusher_previous_face_position_y": 46000,
		"coin_pusher_face_position_y": 28000,
		"coin_pusher_interpolation_alpha": 0.5,
	}
	var hostile_authored: Dictionary = renderer.debug_authored_cabinet_for_test(hostile_state, "artifact")
	var hostile_signature: Dictionary = renderer.render_signature(hostile_state)
	var projected_center: Vector2 = renderer.debug_project_for_test(hostile_state, 100000.0, 80000.0, 0.0)
	var projected_coin_high: Vector2 = renderer.debug_project_for_test(hostile_state, 100000.0, 80000.0, 2500.0)
	var authored_deck: PackedVector2Array = renderer.debug_deck_polygon_for_test(hostile_state)
	if hostile_authored.get("identity") != "hostile_custom_identity" or hostile_authored.get("display_style") != "value_lamps" or hostile_authored.get("display_state_key") != "hostile_value" or hostile_authored.get("body_color") != "123456" or hostile_authored.get("body_label") != "Z9" or hostile_authored.get("backglass_color") != "161718":
		failures.append("Coin Pusher V3 renderer ignored hostile authored cabinet descriptors: %s." % JSON.stringify(hostile_authored))
	if float(hostile_signature.get("projection_width", 0.0)) != 200000.0 or float(hostile_signature.get("projection_back_y", 0.0)) != 80000.0 or float(hostile_signature.get("projection_coin_height", 0.0)) != 2500.0 or not is_equal_approx(projected_center.x, 450.0) or not is_equal_approx(projected_coin_high.y, projected_center.y - 10.0) or authored_deck.size() != 5:
		failures.append("Coin Pusher V3 renderer did not consume nondefault public geometry/coin height/deck polygon: signature=%s center=%s high=%s deck=%d." % [JSON.stringify(hostile_signature), projected_center, projected_coin_high, authored_deck.size()])
	if int(renderer.debug_interpolated_face_y_for_test(hostile_state)) != 37000:
		failures.append("Coin Pusher V3 face/platform midpoint interpolation was not 37000.")
	var hostile_layout: Dictionary = renderer.debug_entry_hardware_layout_for_test(hostile_state)
	var hostile_targets: Array = hostile_layout.get("targets", []) if typeof(hostile_layout.get("targets", [])) == TYPE_ARRAY else []
	var projected_hole: Vector2 = renderer.debug_project_delivery_board_point_for_test(hostile_state, 97000.0, 26000.0)
	var hostile_catalog: Array = hostile_signature.get("hardware_catalog", []) if typeof(hostile_signature.get("hardware_catalog", [])) == TYPE_ARRAY else []
	var renderer_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher/coin_pusher_renderer.gd")
	if hostile_targets.size() != 3 or not ((hostile_targets[1] as Dictionary).get("center", Vector2.ZERO) as Vector2).is_equal_approx(projected_hole) or not (((hostile_targets[1] as Dictionary).get("rect", Rect2()) as Rect2).get_center()).is_equal_approx(projected_hole):
		failures.append("Coin Pusher V3 hostile fourth apparatus did not project its authored hole center and exact hit rect through the delivery-board transform: %s." % JSON.stringify(hostile_layout))
	if not hostile_catalog.has("hostile_selector") or not hostile_catalog.has("hostile_panel") or renderer_source.contains("quarter_falls") or renderer_source.contains("jackpot_ridge") or renderer_source.contains("vault_drop") or renderer_source.contains("coin_pusher_variation_id"):
		failures.append("Coin Pusher V3 renderer still identifies variations instead of consuming generic feature hardware: catalog=%s." % JSON.stringify(hostile_catalog))
	var hostile_rail_state := hostile_state.duplicate(true)
	hostile_rail_state["coin_pusher_apparatus"] = {"type": "rail_slot", "rail": {"x_min": 17000, "x_max": 183000}, "drop_board": {"y": 80000, "z_top": 26000, "z_bottom": 3600}}
	hostile_rail_state["coin_pusher_carriage_x"] = 97000
	var hostile_rail_layout: Dictionary = renderer.debug_entry_hardware_layout_for_test(hostile_rail_state)
	var expected_rail_start: Vector2 = renderer.debug_project_delivery_board_point_for_test(hostile_rail_state, 17000.0, 26000.0)
	var expected_rail_end: Vector2 = renderer.debug_project_delivery_board_point_for_test(hostile_rail_state, 183000.0, 26000.0)
	var expected_carriage: Vector2 = renderer.debug_project_delivery_board_point_for_test(hostile_rail_state, 97000.0, 26000.0)
	if not (hostile_rail_layout.get("rail_start", Vector2.ZERO) as Vector2).is_equal_approx(expected_rail_start) or not (hostile_rail_layout.get("rail_end", Vector2.ZERO) as Vector2).is_equal_approx(expected_rail_end) or not (hostile_rail_layout.get("carriage", Vector2.ZERO) as Vector2).is_equal_approx(expected_carriage):
		failures.append("Coin Pusher V3 legal rail/carriage projection diverged from the delivery-board body/pin x transform: %s." % JSON.stringify(hostile_rail_layout))
	hostile_state["reduce_motion"] = true
	if int(renderer.debug_interpolated_face_y_for_test(hostile_state)) != 28000:
		failures.append("Coin Pusher V3 reduced motion did not present the current face/platform position directly.")
	var crossing_bodies: Array = [
		{"id": "rear", "y": 50000, "z": 0},
		{"id": "middle", "y": 40000, "z": 0},
		{"id": "front", "y": 30000, "z": 0},
	]
	var crossing_before: Array = renderer.debug_batch_body_order_for_test(crossing_bodies, 77)
	var cache_before: String = renderer.debug_depth_cache_key_for_test()
	(crossing_bodies[0] as Dictionary)["y"] = 20000
	(crossing_bodies[1] as Dictionary)["y"] = 45000
	var crossing_after: Array = renderer.debug_batch_body_order_for_test(crossing_bodies, 78)
	var cache_after: String = renderer.debug_depth_cache_key_for_test()
	if crossing_before != ["rear", "middle", "front"] or crossing_after != ["middle", "front", "rear"] or cache_before == cache_after:
		failures.append("Coin Pusher V3 exact batch order/cache did not invalidate when overlapping bodies crossed on a new presentation view: before=%s after=%s." % [JSON.stringify(crossing_before), JSON.stringify(crossing_after)])
	if str(audio.get("profile_id", "")) != "coin_pusher" or str((audio.get("state_sync", {}) as Dictionary).get("method", "")) != "coin_pusher_state":
		failures.append("Coin Pusher V3 alive cabinet did not bind its continuous physics audio profile.")
	var sfx_script: Script = load("res://scripts/ui/sfx_player.gd")
	var sfx: Node = sfx_script.new()
	var audio_schedule: Array = sfx.debug_coin_pusher_event_schedule({
		"coin_pusher_audio_events": [
			{"kind": "impact", "intensity_milli": 500, "metadata": {"fall_height_milli": 2400, "stack_depth": 2, "material": "coin_on_coin"}},
			{"kind": "mass_slide", "intensity_milli": 600, "metadata": {"moving_count": 12}},
			{"kind": "plate_clink", "intensity_milli": 420, "metadata": {}},
			{"kind": "tray_landing", "intensity_milli": 700, "metadata": {"group_count": 4}},
			{"kind": "gutter_loss", "intensity_milli": 520, "metadata": {}},
		],
	})
	var audio_cues: Array = []
	for entry_value in audio_schedule:
		audio_cues.append(str((entry_value as Dictionary).get("cue", "")))
	for required_cue in ["coin_pusher_coin_stack", "coin_pusher_slide", "coin_pusher_coin_metal", "coin_pusher_tray", "coin_pusher_gutter"]:
		if not audio_cues.has(required_cue):
			failures.append("Coin Pusher V3 physics-audio event map omitted %s: %s." % [required_cue, JSON.stringify(audio_schedule)])
	var first_patch: Dictionary = game.surface_realtime_state_patch(run_state, environment, {"surface_time_msec": 1}, initial)
	var second_patch: Dictionary = game.surface_realtime_state_patch(run_state, environment, {"surface_time_msec": 35}, first_patch)
	var previous: Array = second_patch.get("coin_pusher_previous_bodies", []) if typeof(second_patch.get("coin_pusher_previous_bodies", [])) == TYPE_ARRAY else []
	var current: Array = second_patch.get("coin_pusher_bodies", []) if typeof(second_patch.get("coin_pusher_bodies", [])) == TYPE_ARRAY else []
	if previous.size() != current.size() or int(second_patch.get("coin_pusher_ticks_advanced", 0)) <= 0 or float(second_patch.get("coin_pusher_interpolation_alpha", -1.0)) < 0.0 or float(second_patch.get("coin_pusher_interpolation_alpha", 2.0)) > 1.0:
		failures.append("Coin Pusher V3 live cabinet did not publish consecutive exact tick views and a bounded interpolation alpha.")
	var time_msec := 35
	var stop_rates: Array[int] = []
	game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, run_state, environment)
	for _tick in range(30):
		time_msec += 17
		var patch: Dictionary = game.surface_realtime_state_patch(run_state, environment, {"surface_time_msec": time_msec}, {})
		stop_rates.append(int(patch.get("coin_pusher_motor_rate_fp", -1)))
		var sync_state := patch.duplicate(false)
		sync_state["reduce_motion"] = true
		var audio_motor: Dictionary = sfx.debug_coin_pusher_motor_sync(sync_state)
		if not is_equal_approx(float(audio_motor.get("rate", -1.0)), float(stop_rates[-1]) / 1000.0):
			failures.append("Coin Pusher V3 motor audio did not consume the production realtime rate under reduced motion: %s." % JSON.stringify(audio_motor))
			break
	var release_rates: Array[int] = []
	game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, run_state, environment)
	for _tick in range(30):
		time_msec += 17
		var patch: Dictionary = game.surface_realtime_state_patch(run_state, environment, {"surface_time_msec": time_msec}, {})
		release_rates.append(int(patch.get("coin_pusher_motor_rate_fp", -1)))
		var sync_state := patch.duplicate(false)
		sync_state["reduce_motion"] = true
		sfx.debug_coin_pusher_motor_sync(sync_state)
	if stop_rates.is_empty() or stop_rates[0] >= 1000 or stop_rates[-1] != 0 or release_rates.is_empty() or release_rates[0] <= 0 or release_rates[-1] != 1000:
		failures.append("Coin Pusher V3 production motor/audio ramp did not complete 1000->0->1000 across the binding 24 ticks: stop=%s release=%s." % [JSON.stringify(stop_rates), JSON.stringify(release_rates)])
	var stopped_audio: Dictionary = sfx.debug_coin_pusher_motor_sync({"coin_pusher_motor_rate_fp": 0, "coin_pusher_body_count": 100, "coin_pusher_audio_serial": 0, "reduce_motion": true})
	var running_audio: Dictionary = sfx.debug_coin_pusher_motor_sync({"coin_pusher_motor_rate_fp": 1000, "coin_pusher_body_count": 100, "coin_pusher_audio_serial": 0, "reduce_motion": true})
	if bool(stopped_audio.get("running", true)) or not bool(running_audio.get("running", false)) or float(running_audio.get("pitch", 0.0)) <= float(stopped_audio.get("pitch", 1.0)):
		failures.append("Coin Pusher V3 motor loop did not stop/rise in pitch with the real ramp: stopped=%s running=%s." % [JSON.stringify(stopped_audio), JSON.stringify(running_audio)])
	# Exercise the production classifier on consecutive renderer-facing views.
	# Plate clink is rear plate blocking, never the platform->deck deposit; slide
	# is collective face-driven deck motion close to the pushing face.
	var live_machine: Dictionary = game.call("_ensure_live_machine", run_state, environment)
	var live_simulation: Dictionary = live_machine.get("simulation", {})
	var live_session: Dictionary = live_machine.get("live_session", {})
	live_simulation["tick"] = 100
	live_simulation["face_y"] = 41000
	live_simulation["motor_rate_fp"] = 1000
	live_session["presentation_previous_face_y"] = 40000
	live_session["presentation_current_face_y"] = 41000
	live_session["presentation_previous_bodies"] = [{"id": "plate", "kind": "coin", "x": 50000, "y": 75650, "z": 3600, "rest_state": "resting", "support_kind": "platform"}]
	live_session["presentation_current_bodies"] = [{"id": "plate", "kind": "coin", "x": 50000, "y": 75650, "z": 3600, "rest_state": "resting", "support_kind": "platform"}]
	var plate_audio: Array = game.call("_presentation_audio_events", live_machine, [])
	live_simulation["tick"] = 106
	live_session["presentation_previous_face_y"] = 41000
	live_session["presentation_current_face_y"] = 42000
	live_session["presentation_previous_bodies"] = [{"id": "deposit", "kind": "coin", "x": 50000, "y": 40000, "z": 3600, "rest_state": "resting", "support_kind": "platform"}]
	live_session["presentation_current_bodies"] = [{"id": "deposit", "kind": "coin", "x": 50000, "y": 39000, "z": 0, "rest_state": "resting", "support_kind": "deck"}]
	var deposit_audio: Array = game.call("_presentation_audio_events", live_machine, [])
	live_simulation["tick"] = 120
	live_simulation["face_y"] = 36000
	live_session["presentation_previous_face_y"] = 37000
	live_session["presentation_current_face_y"] = 36000
	var slide_previous: Array = []
	var slide_current: Array = []
	for slide_index in range(5):
		slide_previous.append({"id": "slide_%d" % slide_index, "kind": "coin", "x": 30000 + slide_index * 9000, "y": 35000, "z": 0, "rest_state": "resting", "support_kind": "deck"})
		slide_current.append({"id": "slide_%d" % slide_index, "kind": "coin", "x": 30000 + slide_index * 9000, "y": 34000, "z": 0, "rest_state": "resting", "support_kind": "deck"})
	live_session["presentation_previous_bodies"] = slide_previous
	live_session["presentation_current_bodies"] = slide_current
	var slide_audio: Array = game.call("_presentation_audio_events", live_machine, [])
	var saw_plate_block := plate_audio.any(func(event: Variant) -> bool: return typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("kind", "")) == "plate_clink" and str(((event as Dictionary).get("metadata", {}) as Dictionary).get("classification", "")) == "rear_plate_blocked_carry")
	var deposit_was_silent := not deposit_audio.any(func(event: Variant) -> bool: return typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("kind", "")) == "plate_clink")
	var saw_face_slide := slide_audio.any(func(event: Variant) -> bool: return typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("kind", "")) == "mass_slide" and str(((event as Dictionary).get("metadata", {}) as Dictionary).get("classification", "")) == "forward_motion_under_face")
	if not saw_plate_block or not deposit_was_silent or not saw_face_slide:
		failures.append("Coin Pusher V3 production motion-audio classification drifted: plate=%s deposit=%s slide=%s." % [JSON.stringify(plate_audio), JSON.stringify(deposit_audio), JSON.stringify(slide_audio)])
	sfx.queue_free()
	var actions: Array = signature.get("hardware_actions", []) if typeof(signature.get("hardware_actions", [])) == TYPE_ARRAY else []
	var catalog: Array = signature.get("hardware_catalog", []) if typeof(signature.get("hardware_catalog", [])) == TYPE_ARRAY else []
	for required in ["coin_pusher_carriage_drag", "coin_pusher_drop", "coin_pusher_skill_stop", "coin_pusher_collect"]:
		if not catalog.has(required):
			failures.append("Coin Pusher V3 cabinet hardware omitted required interaction %s." % required)
	if actions.has("coin_pusher_collect"):
		failures.append("Coin Pusher V3 exposed disabled empty-tray COLLECT as an actionable hit target.")


func _check_pusher_v3_presentation_view(machine: Dictionary, failures: Array) -> void:
	var simulation := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-PRESENTATION-VIEW"), machine, 24)
	CoinPusherSolverScript.step_ticks(simulation, {"motor_enabled": true}, 36)
	var canonical_before: Dictionary = CoinPusherSolverScript.canonical_digest(simulation)
	var canonical_views: Array = CoinPusherSolverScript.body_views(simulation)
	var presentation_views: Array = CoinPusherLiveSessionScript.presentation_body_views_for_test(simulation)
	var canonical_after: Dictionary = CoinPusherSolverScript.canonical_digest(simulation)
	if presentation_views.size() != canonical_views.size():
		failures.append("Coin Pusher V3 lean public presentation view lost bodies: canonical=%d presentation=%d." % [canonical_views.size(), presentation_views.size()])
		return
	for body_index in range(canonical_views.size()):
		var canonical_body: Dictionary = canonical_views[body_index]
		var presentation_body: Dictionary = presentation_views[body_index]
		for field in ["id", "kind", "x", "y", "z", "rest_state", "support_kind"]:
			if presentation_body.get(field) != canonical_body.get(field):
				failures.append("Coin Pusher V3 lean public presentation view drifted at body %d field %s: canonical=%s presentation=%s." % [body_index, field, canonical_body.get(field), presentation_body.get(field)])
				return
	if canonical_after != canonical_before:
		failures.append("Coin Pusher V3 lean public presentation projection mutated canonical solver state/outcomes.")

	# The common renderer path keeps body order stable across ticks. It must use
	# the same-index prior body without constructing a 300-entry ID dictionary,
	# while a hostile reordering still falls back to exact ID interpolation.
	var renderer := CoinPusherRenderer.new()
	var interpolation_current := [
		{"id": "front", "kind": "coin", "x": 100, "y": 100, "z": 0},
		{"id": "rear", "kind": "coin", "x": 200, "y": 200, "z": 0},
	]
	var interpolation_previous := [
		{"id": "front", "kind": "coin", "x": 0, "y": 100, "z": 0},
		{"id": "rear", "kind": "coin", "x": 100, "y": 200, "z": 0},
	]
	var interpolation_current_before := JSON.stringify(interpolation_current)
	var interpolation_previous_before := JSON.stringify(interpolation_previous)
	var aligned_projection: Array = renderer.debug_interpolated_bodies_for_test(interpolation_current, interpolation_previous, 0.5, 700)
	var reordered_previous := [interpolation_previous[1].duplicate(true), interpolation_previous[0].duplicate(true)]
	var reordered_before := JSON.stringify(reordered_previous)
	var fallback_projection: Array = renderer.debug_interpolated_bodies_for_test(interpolation_current, reordered_previous, 0.5, 701)
	if aligned_projection != fallback_projection \
			or aligned_projection.size() != 2 \
			or str((aligned_projection[0] as Dictionary).get("id", "")) != "rear" \
			or float((aligned_projection[0] as Dictionary).get("x", -1.0)) != 150.0 \
			or str((aligned_projection[1] as Dictionary).get("id", "")) != "front" \
			or float((aligned_projection[1] as Dictionary).get("x", -1.0)) != 50.0:
		failures.append("Coin Pusher V3 renderer fast/fallback interpolation paths did not preserve exact ID and depth-order projection: aligned=%s fallback=%s." % [JSON.stringify(aligned_projection), JSON.stringify(fallback_projection)])
	if JSON.stringify(interpolation_current) != interpolation_current_before \
			or JSON.stringify(interpolation_previous) != interpolation_previous_before \
			or JSON.stringify(reordered_previous) != reordered_before:
		failures.append("Coin Pusher V3 renderer interpolation mutated its current/previous public view buffers.")

	# Presentation serials restart for each session. Two distinct session arrays
	# can therefore collide on serial, size, and endpoint IDs while their middle
	# depth geometry requires a different exact order.
	var session_a_bodies := [
		{"id": "same_first", "y": 400, "z": 0},
		{"id": "middle_a", "y": 300, "z": 0},
		{"id": "middle_b", "y": 200, "z": 0},
		{"id": "same_last", "y": 100, "z": 0},
	]
	var session_b_bodies := [
		{"id": "same_first", "y": 400, "z": 0},
		{"id": "middle_a", "y": 150, "z": 0},
		{"id": "middle_b", "y": 350, "z": 0},
		{"id": "same_last", "y": 100, "z": 0},
	]
	var session_a_before := JSON.stringify(session_a_bodies)
	var session_b_before := JSON.stringify(session_b_bodies)
	var session_a_order := renderer.debug_batch_body_order_for_test(session_a_bodies, 777)
	var session_b_order := renderer.debug_batch_body_order_for_test(session_b_bodies, 777)
	if is_same(session_a_bodies, session_b_bodies) \
			or session_a_order != ["same_first", "middle_a", "middle_b", "same_last"] \
			or session_b_order != ["same_first", "middle_b", "middle_a", "same_last"]:
		failures.append("Coin Pusher V3 renderer depth cache reused stale indices across distinct session arrays with a colliding serial/key: a=%s b=%s." % [JSON.stringify(session_a_order), JSON.stringify(session_b_order)])
	if JSON.stringify(session_a_bodies) != session_a_before or JSON.stringify(session_b_bodies) != session_b_before:
		failures.append("Coin Pusher V3 renderer depth-cache collision guard mutated or aliased distinct session arrays.")

	# Four-tick catch-up must publish only the exact final consecutive pair. The
	# opening and published buffers remain distinct, ordered, and equivalent to
	# canonical projection without changing save/reload results.
	var live_simulation := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-PRESENTATION-CATCHUP"), machine, 24)
	var expected_simulation := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-PRESENTATION-CATCHUP"), machine, 24)
	var live_machine := {"simulation": live_simulation, "motor_started": true, "locked_down": false, "drop_queue": [], "variation_state": {}}
	var live_session: Dictionary = CoinPusherLiveSessionScript.begin(live_machine, machine, 8814)
	var opening_previous: Array = live_session.get("presentation_previous_bodies", [])
	var opening_current: Array = live_session.get("presentation_current_bodies", [])
	var opening_previous_before := JSON.stringify(opening_previous)
	var opening_current_before := JSON.stringify(opening_current)
	CoinPusherLiveSessionScript.advance(live_machine, 0)
	CoinPusherSolverScript.step_ticks(expected_simulation, {"motor_enabled": true}, 3)
	var expected_previous := CoinPusherLiveSessionScript.presentation_body_views_for_test(expected_simulation)
	CoinPusherSolverScript.step_ticks(expected_simulation, {"motor_enabled": true}, 1)
	var expected_current := CoinPusherLiveSessionScript.presentation_body_views_for_test(expected_simulation)
	var catch_up := CoinPusherLiveSessionScript.advance(live_machine, 67)
	var catch_up_previous: Array = live_session.get("presentation_previous_bodies", [])
	var catch_up_current: Array = live_session.get("presentation_current_bodies", [])
	if is_same(opening_previous, opening_current) or is_same(catch_up_previous, catch_up_current) \
			or JSON.stringify(opening_previous) != opening_previous_before \
			or JSON.stringify(opening_current) != opening_current_before:
		failures.append("Coin Pusher V3 presentation double buffers aliased or mutated a previously published view.")
	if int(catch_up.get("ticks", 0)) != 4 \
			or int(live_session.get("presentation_view_serial", -1)) != 4 \
			or catch_up_previous != expected_previous \
			or catch_up_current != expected_current:
		failures.append("Coin Pusher V3 bounded catch-up did not publish the exact final consecutive projection pair: ticks=%s serial=%s previous=%s current=%s." % [catch_up.get("ticks"), live_session.get("presentation_view_serial"), JSON.stringify(catch_up_previous), JSON.stringify(catch_up_current)])
	var live_body_ids: Array = catch_up_current.map(func(body: Dictionary) -> String: return str(body.get("id", "")))
	var solver_body_ids: Array = (live_simulation.get("bodies", []) as Array).map(func(body: Dictionary) -> String: return str(body.get("id", "")))
	if catch_up_current.size() != (live_simulation.get("bodies", []) as Array).size() or live_body_ids != solver_body_ids:
		failures.append("Coin Pusher V3 bounded presentation projection changed body count/order: live=%s solver=%s." % [JSON.stringify(live_body_ids), JSON.stringify(solver_body_ids)])
	var saved := CoinPusherLiveSessionScript.make_snapshot(live_simulation, live_machine)
	var restored := CoinPusherLiveSessionScript.restore_snapshot(saved, machine)
	var resaved := CoinPusherLiveSessionScript.make_snapshot(restored, live_machine)
	var restored_canonical_views := CoinPusherSolverScript.body_views(restored)
	var restored_presentation_views := CoinPusherLiveSessionScript.presentation_body_views_for_test(restored)
	var restored_projection_matches := restored_canonical_views.size() == restored_presentation_views.size()
	for body_index in range(restored_canonical_views.size()):
		if not restored_projection_matches:
			break
		var restored_canonical_body: Dictionary = restored_canonical_views[body_index]
		var restored_presentation_body: Dictionary = restored_presentation_views[body_index]
		for field in ["id", "kind", "x", "y", "z", "rest_state", "support_kind"]:
			if restored_presentation_body.get(field) != restored_canonical_body.get(field):
				restored_projection_matches = false
				break
	if JSON.stringify(resaved) != JSON.stringify(saved) or not restored_projection_matches:
		failures.append("Coin Pusher V3 bounded presentation projection changed compact save/reload determinism or restored visual projection equivalence.")


func _check_pusher_v3_machine_data(machine: Dictionary, failures: Array) -> void:
	var geometry: Dictionary = machine.get("geometry", {}) if typeof(machine.get("geometry", {})) == TYPE_DICTIONARY else {}
	var stroke: Dictionary = machine.get("stroke", {}) if typeof(machine.get("stroke", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = machine.get("apparatus", {}) if typeof(machine.get("apparatus", {})) == TYPE_DICTIONARY else {}
	if str(machine.get("machine_id", "")) != "quarter_falls" \
			or int(geometry.get("width", 0)) != 100000 \
			or int(geometry.get("tray_lip_y", 0)) != 4000 \
			or int(geometry.get("payout_ramp_run", 0)) != 6500 \
			or int(geometry.get("payout_ramp_rise", 0)) != 900 \
			or int(geometry.get("payout_apron_drop", 0)) != 3000 \
			or int(geometry.get("face_extended_y", 0)) != 43000 \
			or int(geometry.get("face_retracted_y", 0)) != 61000 \
			or int(geometry.get("back_plate_y", 0)) != 78000 \
			or int(geometry.get("platform_top_z", 0)) != 3600 \
			or int(geometry.get("drop_y", 0)) != 73000 \
			or int(geometry.get("drop_z", 0)) != 24000:
		failures.append("Coin Pusher V3 machine geometry drifted from the extended lower-bed/edge-plate contract.")
	if int(stroke.get("period_ticks", 0)) != 240 or int(stroke.get("ramp_ticks", 0)) != 24 or str(stroke.get("profile", "")) != "cosine":
		failures.append("Coin Pusher V3 stroke data is not the binding 240-tick cosine/24-tick-ramp contract.")
	if str(apparatus.get("type", "")) != "rail_slot" or (apparatus.get("pegs", []) as Array).size() != 45 or int(machine.get("ceiling", 0)) != 600 \
			or int(apparatus.get("release_jitter", 0)) != 650 or int(apparatus.get("release_velocity_jitter", 0)) != 2400:
		failures.append("Coin Pusher V3 apparatus/ceiling data is incomplete.")
	var synthetic := machine.duplicate(true)
	var synthetic_pegs: Array = []
	for row in range(5):
		for column in range(4):
			synthetic_pegs.append({"x": 20000 + column * 20000 + (10000 if row % 2 == 1 else 0), "z": 20000 - row * 3000, "r": 1200})
	synthetic["apparatus"] = {"type": "hole_set", "holes": [25000, 50000, 75000], "pegs": synthetic_pegs, "release_jitter": 300}
	var synthetic_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-HOLE-SET"), synthetic, 0)
	if CoinPusherSolverScript.select_hole(synthetic_state, 2) != 75000 or int(synthetic_state.get("selected_hole", -1)) != 2 or synthetic_pegs.size() != 20:
		failures.append("Coin Pusher V3 apparatus framework did not accept a synthetic five-row hole-set/plinko definition.")
	var extended: int = CoinPusherSolverScript.face_y_for_phase(machine, 0)
	var retracted: int = CoinPusherSolverScript.face_y_for_phase(machine, 120)
	if int(extended) != 43000 or int(retracted) != 61000:
		failures.append("Coin Pusher V3 stroke orientation drifted: extended=%s retracted=%s." % [extended, retracted])
	_check_pusher_v3_shipped_variant_definitions(machine, failures)


func _check_pusher_v3_coin_scale_lower_bed_and_edge_ramp(machine: Dictionary, failures: Array) -> void:
	var geometry: Dictionary = machine.get("geometry", {}) if typeof(machine.get("geometry", {})) == TYPE_DICTIONARY else {}
	var coins: Dictionary = machine.get("coins", {}) if typeof(machine.get("coins", {})) == TYPE_DICTIONARY else {}
	var lip := int(geometry.get("tray_lip_y", 0))
	var ramp_run := int(geometry.get("payout_ramp_run", 0))
	var ramp_rise := int(geometry.get("payout_ramp_rise", 0))
	var apron_drop := int(geometry.get("payout_apron_drop", 0))
	var extended := int(geometry.get("face_extended_y", 0))
	var retracted := int(geometry.get("face_retracted_y", 0))
	var plate := int(geometry.get("back_plate_y", 0))
	var lower_depth := extended - lip
	var upper_depth := plate - extended
	var stroke_depth := retracted - extended
	if int(coins.get("radius", 0)) != 2350 or int(coins.get("height", 0)) != 950:
		failures.append("Coin Pusher V3 coins did not return to the prior 17 px physical scale: %s." % JSON.stringify(coins))
	if lower_depth <= upper_depth or upper_depth != 35000 or stroke_depth != 18000:
		failures.append("Coin Pusher V3 lower bed was not extended beyond the preserved upper shelf: lower=%d upper=%d stroke=%d." % [lower_depth, upper_depth, stroke_depth])
	var back_height := CoinPusherSolverScript.payout_ramp_height_for_y(machine, lip + ramp_run)
	var mid_height := CoinPusherSolverScript.payout_ramp_height_for_y(machine, lip + ramp_run / 2)
	var front_height := CoinPusherSolverScript.payout_ramp_height_for_y(machine, lip)
	var downhill_acceleration := CoinPusherSolverScript.payout_ramp_downhill_acceleration(machine)
	if ramp_run != 6500 or ramp_rise != 900 or apron_drop != 3000 or back_height != 0 or absi(mid_height - 450) > 1 or front_height != 900 or downhill_acceleration <= 0:
		failures.append("Coin Pusher V3 payout edge is not a finite upward plate with resolved gravity: run=%d rise=%d heights=%s downhill=%d." % [ramp_run, ramp_rise, JSON.stringify([back_height, mid_height, front_height]), downhill_acceleration])
	var renderer := CoinPusherRenderer.new()
	var render_state := {"coin_pusher_geometry": geometry, "coin_pusher_coin_radius": int(coins.get("radius", 0)), "coin_pusher_coin_height": int(coins.get("height", 0)), "coin_pusher_bodies": []}
	var signature := renderer.render_signature(render_state)
	var ramp_projection := renderer.debug_payout_ramp_for_test(render_state)
	var flat_front := renderer.debug_project_for_test(render_state, 0, lip, 0)
	var apron_depth_px := float((ramp_projection.get("apron_bottom_left", Vector2.ZERO) as Vector2).y) - float((ramp_projection.get("front_left", Vector2.ZERO) as Vector2).y)
	if not is_equal_approx(float(signature.get("coin_rx", 0.0)), 17.02246) or float(signature.get("coin_ry", 0.0)) != 12.0 or signature.get("coin_atlas_frame_size", Vector2i.ZERO) != Vector2i(40, 32) or not is_equal_approx(float(signature.get("front_contact_radius_px", 0.0)), float(signature.get("coin_rx", 0.0))) or int(ramp_projection.get("run", 0)) != ramp_run or int(ramp_projection.get("rise", 0)) != ramp_rise or int(ramp_projection.get("apron_drop", 0)) != apron_drop or float((ramp_projection.get("front_left", Vector2.ZERO) as Vector2).y) >= flat_front.y or apron_depth_px < 12.0:
		failures.append("Coin Pusher V3 renderer did not restore the prior coin size or project the raised payout plate: signature=%s ramp=%s." % [JSON.stringify(signature), JSON.stringify(ramp_projection)])
	var ramp_state := _pusher_v3_state(machine, "PUSHER-V3-EDGE-RAMP")
	_pusher_v3_hold_phase(ramp_state, machine, 0)
	var ramp_body := _pusher_v3_body_fixture("ramp_resistance", 50000, lip + ramp_run / 2, mid_height, false, "deck")
	ramp_body["radius"] = int(coins.get("radius", 2350))
	ramp_body["height"] = int(coins.get("height", 950))
	ramp_body["rest_state"] = "resting"
	ramp_body["vy"] = -8000
	(ramp_state.get("bodies", []) as Array).append(ramp_body)
	ramp_state["opening_body_count"] = 1
	var flat_machine := machine.duplicate(true)
	(flat_machine.get("geometry", {}) as Dictionary)["payout_ramp_rise"] = 0
	var flat_state := _pusher_v3_state(flat_machine, "PUSHER-V3-FLAT-EDGE")
	_pusher_v3_hold_phase(flat_state, flat_machine, 0)
	var flat_body := ramp_body.duplicate(true)
	flat_body["z"] = 0
	(flat_state.get("bodies", []) as Array).append(flat_body)
	flat_state["opening_body_count"] = 1
	CoinPusherSolverScript.step_ticks_reference_for_test(ramp_state, {"motor_enabled": false}, 1)
	CoinPusherSolverScript.step_ticks_reference_for_test(flat_state, {"motor_enabled": false}, 1)
	var resisted := _pusher_v3_body(ramp_state, "ramp_resistance")
	var unresisted := _pusher_v3_body(flat_state, "ramp_resistance")
	if resisted.is_empty() or unresisted.is_empty() or int(resisted.get("z", 0)) <= 0 or int(resisted.get("vy", 0)) <= int(unresisted.get("vy", 0)):
		failures.append("Coin Pusher V3 edge plate did not create uphill support and downhill resistance: ramp=%s flat=%s." % [JSON.stringify(resisted), JSON.stringify(unresisted)])


func _check_pusher_v3_played_in_opening_state(library: ContentLibrary, game_definition: Dictionary, failures: Array) -> void:
	var machine: Dictionary = game_definition.get("coin_pusher_machine", {}) if typeof(game_definition.get("coin_pusher_machine", {})) == TYPE_DICTIONARY else {}
	var tuning: Dictionary = game_definition.get("coin_pusher_tuning", {}) if typeof(game_definition.get("coin_pusher_tuning", {})) == TYPE_DICTIONARY else {}
	var authored_counts: Dictionary = tuning.get("opening_coin_counts", {}) if typeof(tuning.get("opening_coin_counts", {})) == TYPE_DICTIONARY else {}
	var expected_counts := {"quarter_falls": 150, "jackpot_ridge": 150, "vault_drop": 154}
	var normalized_counts := {}
	for variation_id in expected_counts.keys():
		normalized_counts[variation_id] = int(authored_counts.get(variation_id, -1))
	if normalized_counts != expected_counts:
		failures.append("Coin Pusher V3 played-in opening counts drifted from the smaller-coin 150/150/154 contract: %s." % JSON.stringify(authored_counts))
		return
	var definitions := {"quarter_falls": machine}
	var shipped: Dictionary = machine.get("machines", {}) if typeof(machine.get("machines", {})) == TYPE_DICTIONARY else {}
	definitions["jackpot_ridge"] = shipped.get("jackpot_ridge", {})
	definitions["vault_drop"] = shipped.get("vault_drop", {})
	var module_script: Script = load(str(game_definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 played-in production generator could not load the game module.")
		return
	var report := {}
	for variation_id in definitions.keys():
		var definition: Dictionary = definitions[variation_id]
		var opening_count := int(expected_counts[variation_id])
		for production_seed_index in range(2):
			var production_seed := "PUSHER-V3-PLAYED-IN-PRODUCTION-%s-%d" % [variation_id, production_seed_index]
			var run_state := RunState.new()
			run_state.start_new(production_seed, RunState.standard_challenge(production_seed))
			var environment := {"id": "played_in_%s" % variation_id, "world_node_id": "played_in_%s" % variation_id, "scenario_game_modifiers": {"coin_pusher": {"variation_id": variation_id}}, "game_states": {}}
			var game: GameModule = module_script.new()
			game.setup(game_definition, library)
			var generated: Dictionary = game.call("_generate_machine_state", run_state, environment, _pusher_v3_rng(production_seed))
			var repeated: Dictionary = game.call("_generate_machine_state", run_state, environment, _pusher_v3_rng(production_seed))
			var snapshot: Dictionary = generated.get("settled_state", {}) if typeof(generated.get("settled_state", {})) == TYPE_DICTIONARY else {}
			var production_state := CoinPusherLiveSessionScript.restore_snapshot(snapshot, definition)
			var production_bodies: Array = production_state.get("bodies", [])
			var feature_count := 0
			for body_value in production_bodies:
				if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("kind", "coin")) != "coin":
					feature_count += 1
			var minimum_features := 1 if variation_id == "quarter_falls" else 4 if variation_id == "jackpot_ridge" else 6
			var production_deterministic := JSON.stringify(snapshot, "", true) == JSON.stringify(repeated.get("settled_state", {}), "", true)
			var production_upper := _pusher_v3_elevated_opening_count(production_state, definition)
			if not production_deterministic or production_bodies.size() < opening_count + minimum_features or feature_count < minimum_features or int(snapshot.get("tray_count", 0)) != 0 or production_upper < 8 or _pusher_v3_overlap_pair_count(production_bodies) != 0:
				failures.append("Coin Pusher V3 %s production opening is not a deterministic collision-valid stock-plus-feature state: seed=%d deterministic=%s bodies=%d features=%d tray=%d upper=%d overlaps=%s." % [variation_id, production_seed_index, str(production_deterministic), production_bodies.size(), feature_count, int(snapshot.get("tray_count", 0)), production_upper, JSON.stringify(_pusher_v3_overlap_pair_details(production_bodies))])
				return
		var variation_max_payout := 0
		var variation_max_total := 0
		var variation_max_passive := 0
		var variation_min_retained_upper := 1000000
		var variation_min_retained_edge := 1000000
		var variation_min_contacting := 1000000
		for seed_index in range(4):
			var seed := "PUSHER-V3-PLAYED-IN-%s-%d" % [variation_id, seed_index]
			var state := CoinPusherSolverScript.create_machine(_pusher_v3_rng(seed), definition, opening_count)
			var repeated := CoinPusherSolverScript.create_machine(_pusher_v3_rng(seed), definition, opening_count)
			var bodies: Array = state.get("bodies", [])
			var upper_before := _pusher_v3_supported_upper_count(bodies)
			var overlap_before := _pusher_v3_overlap_pair_count(bodies)
			if CoinPusherSolverScript.canonical_digest(state) != CoinPusherSolverScript.canonical_digest(repeated):
				failures.append("Coin Pusher V3 %s played-in opening generation is not same-seed deterministic." % variation_id)
				return
			if bodies.size() != opening_count or not (state.get("tray_ledger", []) as Array).is_empty() or upper_before < opening_count - 135 or overlap_before != 0:
				failures.append("Coin Pusher V3 %s opening topology is not a collision-valid mixed-height played-in field: bodies=%d upper=%d overlaps=%d." % [variation_id, bodies.size(), upper_before, overlap_before])
				return
			var edge_before := CoinPusherSolverScript.edge_hanger_count(state)
			var contacting_before := CoinPusherSolverScript.contacting_coin_count(state, 120)
			variation_min_contacting = mini(variation_min_contacting, contacting_before)
			if contacting_before < opening_count - 10:
				failures.append("Coin Pusher V3 %s opening stock is still a sparse non-contact field: seed=%d contacting=%d opening=%d." % [variation_id, seed_index, contacting_before, opening_count])
				return
			CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 240)
			var passive := CoinPusherSolverScript.collect_tray(state)
			var passive_count := int(passive.get("count", 0))
			var edge_after_passive := CoinPusherSolverScript.edge_hanger_count(state)
			variation_min_retained_edge = mini(variation_min_retained_edge, edge_after_passive)
			if edge_before < 6 or edge_after_passive < 4:
				failures.append("Coin Pusher V3 %s opening stock did not retain a tensioned payout-edge buildup: seed=%d before=%d after_passive=%d." % [variation_id, seed_index, edge_before, edge_after_passive])
				return
			variation_max_passive = maxi(variation_max_passive, passive_count)
			var cumulative := passive_count
			var per_play: Array = []
			var targets := _pusher_v3_release_targets(definition)
			for play_index in range(5):
				var target := int(targets[play_index % targets.size()])
				CoinPusherSolverScript.add_coin(state, _pusher_v3_rng("%s-DROP-%d" % [seed, play_index]), target, 1, {"opening_probe": true})
				CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 360)
				var collected := CoinPusherSolverScript.collect_tray(state)
				var paid := int(collected.get("count", 0))
				per_play.append(paid)
				cumulative += paid
				variation_max_payout = maxi(variation_max_payout, paid)
			variation_max_total = maxi(variation_max_total, cumulative)
			var retained_upper := _pusher_v3_supported_upper_count(state.get("bodies", []))
			variation_min_retained_upper = mini(variation_min_retained_upper, retained_upper)
			if passive_count > 2 or per_play.max() > 6 or cumulative > 10 or retained_upper < 4:
				failures.append("Coin Pusher V3 %s opening stock surged or flattened during the first five plays: seed=%d passive=%d per_play=%s cumulative=%d retained_upper=%d." % [variation_id, seed_index, passive_count, JSON.stringify(per_play), cumulative, retained_upper])
				return
		report[variation_id] = {"opening": opening_count, "max_passive": variation_max_passive, "max_per_play": variation_max_payout, "max_first_five": variation_max_total, "min_retained_upper": variation_min_retained_upper, "min_retained_edge": variation_min_retained_edge, "min_contacting": variation_min_contacting}
	print("Coin Pusher V3 played-in opening report: %s" % JSON.stringify(report))


func _pusher_v3_supported_upper_count(bodies: Array) -> int:
	var count := 0
	for body_value in bodies:
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("support_kind", "")) == "body":
			count += 1
	return count


func _pusher_v3_elevated_opening_count(state: Dictionary, definition: Dictionary) -> int:
	var geometry: Dictionary = definition.get("geometry", {}) if typeof(definition.get("geometry", {})) == TYPE_DICTIONARY else {}
	var face := int(state.get("face_y", geometry.get("face_extended_y", 43000)))
	var platform_z := int(geometry.get("platform_top_z", 3600))
	var deck_z := int(geometry.get("deck_z", 0))
	var count := 0
	for body_value in state.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		var metadata: Dictionary = body.get("meta", {}) if typeof(body.get("meta", {})) == TYPE_DICTIONARY else {}
		if str(body.get("kind", "")) != "coin" or not bool(metadata.get("opening", false)):
			continue
		var surface_z := platform_z if int(body.get("y", 0)) >= face else deck_z
		if int(body.get("z", 0)) >= surface_z + int(body.get("height", 950)) - 100:
			count += 1
	return count


func _pusher_v3_overlap_pair_count(bodies: Array) -> int:
	return _pusher_v3_overlap_pair_details(bodies).size()


func _pusher_v3_overlap_pair_details(bodies: Array) -> Array:
	var pairs: Array = []
	for left_index in range(bodies.size()):
		var left: Dictionary = bodies[left_index]
		for right_index in range(left_index + 1, bodies.size()):
			var right: Dictionary = bodies[right_index]
			var left_z := int(left.get("z", 0))
			var right_z := int(right.get("z", 0))
			if left_z >= right_z + int(right.get("height", 950)) or right_z >= left_z + int(left.get("height", 950)):
				continue
			var dx := int(left.get("x", 0)) - int(right.get("x", 0))
			var dy := int(left.get("y", 0)) - int(right.get("y", 0))
			# The fixed-point solver intentionally retains a small positional slop;
			# compact snapshots also quantize positions to 100 units. Treat only a
			# penetration beyond that combined 300-unit envelope as an invalid spawn.
			var minimum := maxi(1, int(left.get("radius", 2350)) + int(right.get("radius", 2350)) - 300)
			if dx * dx + dy * dy < minimum * minimum:
				pairs.append([str(left.get("id", "")), str(left.get("kind", "")), int(left.get("x", 0)), int(left.get("y", 0)), int(left.get("z", 0)), str(right.get("id", "")), str(right.get("kind", "")), int(right.get("x", 0)), int(right.get("y", 0)), int(right.get("z", 0))])
	return pairs


func _check_pusher_v3_shipped_variant_definitions(machine: Dictionary, failures: Array) -> void:
	var shipped: Dictionary = machine.get("machines", {}) if typeof(machine.get("machines", {})) == TYPE_DICTIONARY else {}
	for variation_id in ["jackpot_ridge", "vault_drop"]:
		var definition: Dictionary = shipped.get(variation_id, {}) if typeof(shipped.get(variation_id, {})) == TYPE_DICTIONARY else {}
		var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
		var board: Dictionary = apparatus.get("drop_board", {}) if typeof(apparatus.get("drop_board", {})) == TYPE_DICTIONARY else {}
		var nozzles: Array = apparatus.get("nozzles", []) if typeof(apparatus.get("nozzles", [])) == TYPE_ARRAY else []
		var targets: Array = apparatus.get("targets", []) if typeof(apparatus.get("targets", [])) == TYPE_ARRAY else []
		if definition.is_empty() or int(board.get("z_top", 0)) < 48000 or nozzles.is_empty() or targets.size() < 2 or int(apparatus.get("release_interval_ticks", 0)) != 6 or int(apparatus.get("chain_depth_cap", 0)) != 3:
			failures.append("Coin Pusher V3 %s is missing its tall Plinko board, physical nozzles, rare cups, or bounded feed contract." % variation_id)
	return
	var ridge_pegs: Array = []
	var ridge_rows := [
		[17000, [25000, 50000, 75000]],
		[8000, [12500, 37500, 62500, 87500]],
	]
	for row in ridge_rows:
		for x in row[1]:
			ridge_pegs.append({"x": x, "z": row[0], "r": 1200})
	var common_geometry := {"width": 100000, "tray_lip_y": 4000, "payout_ramp_run": 6500, "payout_ramp_rise": 900, "payout_apron_drop": 3000, "deck_z": 0, "platform_top_z": 3600, "face_extended_y": 43000, "face_retracted_y": 61000, "back_plate_y": 78000, "back_plate_gap": 400, "drop_y": 73000, "drop_z": 24000}
	var common_stroke := {"period_ticks": 240, "ramp_ticks": 24, "profile": "cosine"}
	var common_coins := {"radius": 2350, "height": 950, "mass": 1000, "value": 1, "drop_cost": 1}
	var board := {"y": 73000, "z_top": 24000, "z_bottom": 3600, "x_min": 0, "x_max": 100000}
	var ridge_geometry := common_geometry.duplicate(true)
	ridge_geometry["gutter_x"] = 4000
	var ridge_expected := {
		"machine_id": "jackpot_ridge", "geometry": ridge_geometry, "stroke": common_stroke.duplicate(true),
		"apparatus": {"type": "hole_set", "rail": {}, "holes": [25000, 50000, 75000], "drop_board": board.duplicate(true), "pegs": ridge_pegs, "release_jitter": 850, "release_velocity_jitter": 3200, "custom": {}},
		"coins": common_coins.duplicate(true), "ceiling": 600, "economy": {"documented_ev_band": [0.70, 1.08]},
		"sub_game": {"feature_kind": "puck", "feature_mass": 3000, "jam_radius": 5200, "ridge_run_rate": 2, "stroke_period_ticks": 240},
	}
	var vault_geometry := common_geometry.duplicate(true)
	vault_geometry["gutter_x"] = 4400
	var vault_expected := {
		"machine_id": "vault_drop", "geometry": vault_geometry, "stroke": common_stroke.duplicate(true),
		"apparatus": {"type": "rail_slot", "rail": {"x_min": 10000, "x_max": 90000, "speed_per_tick": 750}, "holes": [], "drop_board": board.duplicate(true), "pegs": [{"x": 25000, "z": 17500, "r": 1400}, {"x": 50000, "z": 17500, "r": 1400}, {"x": 75000, "z": 17500, "r": 1400}, {"x": 12500, "z": 11000, "r": 1400}, {"x": 37500, "z": 11000, "r": 1400}, {"x": 62500, "z": 11000, "r": 1400}, {"x": 87500, "z": 11000, "r": 1400}, {"x": 25000, "z": 4500, "r": 1400}, {"x": 50000, "z": 4500, "r": 1400}, {"x": 75000, "z": 4500, "r": 1400}], "release_jitter": 700, "release_velocity_jitter": 2800, "custom": {}},
		"coins": common_coins.duplicate(true), "ceiling": 600, "economy": {"documented_ev_band": [0.72, 0.94]},
		"sub_game": {"feature_kind": "fragment", "feature_mass": 1800, "future_custom_apparatus": {}},
	}
	# ContentLibrary normalizes JSON numbers to floats. Round-trip the pinned
	# literals through the same JSON representation so exact value/shape checks
	# do not mistake 240 for a different contract than 240.0.
	ridge_expected = JSON.parse_string(JSON.stringify(ridge_expected))
	vault_expected = JSON.parse_string(JSON.stringify(vault_expected))
	var machines: Dictionary = machine.get("machines", {}) if typeof(machine.get("machines", {})) == TYPE_DICTIONARY else {}
	if JSON.stringify(machines.get("jackpot_ridge", {}), "", true) != JSON.stringify(ridge_expected, "", true):
		failures.append("Jackpot Ridge shipped machine definition drifted from its exact pinned geometry/apparatus/economy/subgame contract.")
	if JSON.stringify(machines.get("vault_drop", {}), "", true) != JSON.stringify(vault_expected, "", true):
		failures.append("Vault Drop shipped machine definition drifted from its exact pinned geometry/apparatus/economy/subgame contract.")


func _check_pusher_v3_plinko_bounce_and_variance(machine: Dictionary, failures: Array) -> void:
	var definitions := {"quarter_falls": machine}
	var shipped: Dictionary = machine.get("machines", {}) if typeof(machine.get("machines", {})) == TYPE_DICTIONARY else {}
	definitions["jackpot_ridge"] = shipped.get("jackpot_ridge", {})
	definitions["vault_drop"] = shipped.get("vault_drop", {})
	var expected_counts := {"quarter_falls": 45, "jackpot_ridge": 33, "vault_drop": 53}
	for variation_id in definitions.keys():
		var definition: Dictionary = definitions[variation_id]
		var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
		var pegs: Array = apparatus.get("pegs", []) if typeof(apparatus.get("pegs", [])) == TYPE_ARRAY else []
		if pegs.size() != int(expected_counts.get(variation_id, -1)):
			failures.append("Coin Pusher V3 %s entry field count is not the authored density: %d." % [variation_id, pegs.size()])
			return
		var coin_radius := int((definition.get("coins", {}) as Dictionary).get("radius", 2350))
		for left_index in range(pegs.size()):
			var left: Dictionary = pegs[left_index]
			for right_index in range(left_index + 1, pegs.size()):
				var right: Dictionary = pegs[right_index]
				var dx := int(left.get("x", 0)) - int(right.get("x", 0))
				var dz := int(left.get("z", 0)) - int(right.get("z", 0))
				var simultaneous_radius := coin_radius * 2 + int(left.get("r", 1200)) + int(right.get("r", 1200))
				if dx * dx + dz * dz <= simultaneous_radius * simultaneous_radius:
					failures.append("Coin Pusher V3 %s entry field lets one coin overlap pegs %d and %d simultaneously." % [variation_id, left_index, right_index])
					return

	# A centered crown strike must visibly reverse before it can separate and
	# legitimately strike again. One sustained numerical overlap cannot emit an
	# impact on every solver tick.
	var bounce_definition: Dictionary = machine.duplicate(true)
	var bounce_apparatus: Dictionary = bounce_definition.get("apparatus", {}).duplicate(true)
	bounce_apparatus["pegs"] = [{"x": 50000, "z": 14000, "r": 1200}]
	bounce_definition["apparatus"] = bounce_apparatus
	var bounce_state := _pusher_v3_state(bounce_definition, "PUSHER-V3-PEG-BOUNCE")
	var striker := _pusher_v3_body_fixture("peg_striker", 50000, 73000, 19700, false, "")
	striker["radius"] = 2350
	striker["height"] = 950
	striker["vx"] = 1400
	striker["vz"] = -18000
	striker["meta"] = {"value": 1, "inserted": true}
	(bounce_state.get("bodies", []) as Array).append(striker)
	bounce_state["opening_body_count"] = 1
	var event_ticks: Array = []
	var first_rebound_vz := -1
	var rebound_peak_z := 0
	for tick_index in range(90):
		var result := CoinPusherSolverScript.step_ticks_reference_for_test(bounce_state, {"motor_enabled": false}, 1)
		var body := _pusher_v3_body(bounce_state, "peg_striker")
		if not body.is_empty():
			rebound_peak_z = maxi(rebound_peak_z, int(body.get("z", 0)))
		for event_value in result.get("events", []):
			if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == "peg_impact" and str((event_value as Dictionary).get("body_id", "")) == "peg_striker":
				event_ticks.append(tick_index)
				if first_rebound_vz < 0 and not body.is_empty():
					first_rebound_vz = int(body.get("vz", 0))
	if event_ticks.is_empty() or event_ticks.size() > 4 or first_rebound_vz < 6000 or rebound_peak_z < 18000:
		failures.append("Coin Pusher V3 peg crown did not produce a bounded visible rebound: events=%s first_vz=%d peak_z=%d." % [JSON.stringify(event_ticks), first_rebound_vz, rebound_peak_z])
		return
	for event_index in range(1, event_ticks.size()):
		if int(event_ticks[event_index]) - int(event_ticks[event_index - 1]) < 5:
			failures.append("Coin Pusher V3 peg contact chattered instead of separating between impacts: ticks=%s." % JSON.stringify(event_ticks))
			return

	# Seeded position plus release-angle variance must create more than one real
	# collision/landing path at every authored input, including centered holes.
	for variation_id in definitions.keys():
		var definition: Dictionary = definitions[variation_id]
		var machine_signatures: Dictionary = {}
		for target_value in _pusher_v3_release_targets(definition):
			var target := int(target_value)
			var target_signatures: Dictionary = {}
			for seed_index in range(16):
				var state := _pusher_v3_state(definition, "PUSHER-V3-PLINKO-PATH-STATE-%s-%d-%d" % [variation_id, target, seed_index])
				var released := CoinPusherSolverScript.add_coin(state, _pusher_v3_rng("PUSHER-V3-PLINKO-PATH-DROP-%s-%d-%d" % [variation_id, target, seed_index]), target, 1)
				var body_id := str(released.get("id", ""))
				var peg_path: Array = []
				for _tick in range(180):
					var result := CoinPusherSolverScript.step_ticks_reference_for_test(state, {"motor_enabled": false}, 1)
					for event_value in result.get("events", []):
						if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == "peg_impact" and str((event_value as Dictionary).get("body_id", "")) == body_id:
							peg_path.append(int((event_value as Dictionary).get("peg_index", -1)))
					var body := _pusher_v3_body(state, body_id)
					if body.is_empty() or str(body.get("rest_state", "")) != "falling":
						break
				var landed := _pusher_v3_body(state, body_id)
				var landing_bin := int(landed.get("x", target)) / 1000 if not landed.is_empty() else -1
				var signature := "%s:%d" % [JSON.stringify(peg_path), landing_bin]
				target_signatures[signature] = true
				machine_signatures[signature] = true
			if target_signatures.size() < 2:
				failures.append("Coin Pusher V3 %s entry x=%d did not diverge across deterministic physical drops: %s." % [variation_id, target, JSON.stringify(target_signatures.keys())])
				return
		if machine_signatures.size() < 5:
			failures.append("Coin Pusher V3 %s entry field produced too little path variance: %d signatures." % [variation_id, machine_signatures.size()])
			return


func _check_pusher_v3_rejected_mechanics_deleted(failures: Array) -> void:
	var solver_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher/coin_pusher_solver.gd")
	var game_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher.gd")
	var native_source := FileAccess.get_file_as_string("res://native/coin_pusher/src/coin_pusher_step_kernel.cpp")
	var data_source := FileAccess.get_file_as_string("res://data/games/games.json")
	for rejected in ["_pressurize_full_pile", "_pusher_face_y", "_hot_apply_pushers", "MAX_COLLISION_PASSES", "phase_accuracy", "clean_nudge_phase", "clean_nudge_window_steps", "overlap * 5", "lean > 620"]:
		if solver_source.contains(rejected) or game_source.contains(rejected) or native_source.contains(rejected) or data_source.contains(rejected):
			failures.append("Coin Pusher V3 retained rejected mechanic token: %s" % rejected)
	if game_source.contains("CABINET CONTROLS OFFLINE") or game_source.contains("NO COIN ACCEPTED") \
			or game_source.contains("_draw_v3_headless_placeholder"):
		failures.append("Coin Pusher V3 retained temporary Stage-1/Stage-2 cabinet presentation.")
	for rejected_native in ["ACTION_TICKS", "std::sqrt", "upper_locked", "lower_locked"]:
		if native_source.contains(rejected_native):
			failures.append("Coin Pusher V3 native outcome path retained rejected mechanic token: %s" % rejected_native)
	if not solver_source.contains("transport_rule\": \"platform_carry_plus_back_plate") \
			or solver_source.contains("ratchet_walk") \
			or solver_source.contains("scripted_ratchet"):
		failures.append("Coin Pusher V3 ratchet is not structurally declared as carry + back-plate contact only.")


func _check_pusher_v3_stocked_phase_topology(machine: Dictionary, failures: Array) -> void:
	var signatures: Array = []
	var rooted: Array = []
	for phase in [100, 140]:
		var state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-STOCKED-TOPOLOGY"), machine, 70)
		_pusher_v3_hold_phase(state, machine, phase)
		var drop := CoinPusherSolverScript.add_coin(state, _pusher_v3_rng("PUSHER-V3-STOCKED-TOPOLOGY-DROP"), 50000, 1)
		var body_id := str(drop.get("id", ""))
		# Release the phase hold: timing only has meaning once the authored motor
		# resumes from the selected phase.
		state["motor_run_rate_fp"] = 1000
		state["motor_rate_fp"] = 1000
		state["motor_target_rate_fp"] = 1000
		state["skill_stop_engaged"] = false
		var first_support := {}
		for _tick in range(1200):
			var step := CoinPusherSolverScript.step_ticks_reference_for_test(state, {"motor_enabled": true}, 1)
			for event_value in step.get("events", []):
				if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("body_id", "")) == body_id and bool((event_value as Dictionary).get("first_support", false)):
					first_support = (event_value as Dictionary).duplicate(true)
					break
			if not first_support.is_empty():
				break
		var landed := _pusher_v3_body(state, body_id)
		signatures.append(_pusher_v3_local_topology_signature(state, landed))
		rooted.append(str(first_support.get("support_root", first_support.get("support", ""))) == "platform" and _pusher_v3_recursive_platform_root(state, landed, {}))
	if signatures.size() != 2 or signatures[0] == signatures[1] or rooted != [true, true]:
		failures.append("Coin Pusher V3 same-x stocked phase landing did not produce distinct neighbor/gap/stack topology with independent platform-rooted support chains: signatures=%s rooted=%s." % [JSON.stringify(signatures), JSON.stringify(rooted)])


func _pusher_v3_local_topology_signature(state: Dictionary, landed: Dictionary) -> Array:
	var result: Array = []
	if landed.is_empty():
		return result
	for body_value in state.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY or str((body_value as Dictionary).get("id", "")) == str(landed.get("id", "")):
			continue
		var body: Dictionary = body_value
		var dx := int(body.get("x", 0)) - int(landed.get("x", 0))
		var dy := int(body.get("y", 0)) - int(landed.get("y", 0))
		if dx * dx + dy * dy <= 13000 * 13000:
			result.append([dx / 250, dy / 250, int(body.get("z", 0)) / 100, str(body.get("support_kind", ""))])
	result.sort_custom(func(a: Array, b: Array) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return result


func _pusher_v3_recursive_platform_root(state: Dictionary, body: Dictionary, visited: Dictionary) -> bool:
	if body.is_empty():
		return false
	var body_id := str(body.get("id", ""))
	if visited.has(body_id):
		return false
	visited[body_id] = true
	if str(body.get("support_kind", "")) == "platform":
		return true
	if str(body.get("support_kind", "")) != "body":
		return false
	var best := {}
	var best_gap := 1 << 30
	for candidate_value in state.get("bodies", []):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		if str(candidate.get("id", "")) == body_id or int(candidate.get("z", 0)) >= int(body.get("z", 0)):
			continue
		var dx := int(candidate.get("x", 0)) - int(body.get("x", 0))
		var dy := int(candidate.get("y", 0)) - int(body.get("y", 0))
		var radius_sum := int(candidate.get("radius", 4300)) + int(body.get("radius", 4300))
		if dx * dx + dy * dy <= radius_sum * radius_sum:
			var gap := int(body.get("z", 0)) - (int(candidate.get("z", 0)) + int(candidate.get("height", 1700)))
			if absi(gap) < best_gap:
				best_gap = absi(gap)
				best = candidate
	return _pusher_v3_recursive_platform_root(state, best, visited)


func _check_pusher_v3_landing_skill(machine: Dictionary, failures: Array) -> void:
	var definitions := {"quarter_falls": machine}
	for variation_id in ["jackpot_ridge", "vault_drop"]:
		var variant: Dictionary = (machine.get("machines", {}) as Dictionary).get(variation_id, {}) if typeof(machine.get("machines", {})) == TYPE_DICTIONARY else {}
		definitions[variation_id] = variant
	for variation_id in definitions.keys():
		var definition: Dictionary = definitions[variation_id]
		_check_pusher_v3_production_release_jitter(str(variation_id), definition, failures)
		if not failures.is_empty():
			return
		var period := int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240))
		var traversal_metrics := {}
		var authored_target_ids: Array = []
		for target_value in (definition.get("apparatus", {}) as Dictionary).get("targets", []):
			if typeof(target_value) == TYPE_DICTIONARY:
				authored_target_ids.append(str((target_value as Dictionary).get("id", "")))
		for target_x in _pusher_v3_release_targets(definition):
			var nozzle_key := str(int(target_x))
			traversal_metrics[nozzle_key] = {"drops": 0, "peg_contacts": 0, "audio_contacts": 0, "landing_bins": {}, "capture_counts": {}, "min_x": 1 << 30, "max_x": -(1 << 30), "unresolved": 0}
			for phase in range(period):
				for desired_sign in [-1, 1]:
					var release := _pusher_v3_signed_release(definition, str(variation_id), int(target_x), phase, desired_sign)
					if release.is_empty():
						failures.append("Coin Pusher V3 could not produce authored jitter sign %d at %s x=%d phase=%d." % [desired_sign, variation_id, int(target_x), phase])
						return
					var target_state: Dictionary = release["state"]
					var target_coin: Dictionary = release["coin"]
					# This is the exhaustive production-behavior sweep (all machines,
					# targets, phases, and both jitter signs). Use the production backend
					# here; input-trace parity independently locks it to the reference
					# solver, while keeping this Cartesian gate inside the suite budget.
					var target_result: Dictionary = CoinPusherSolverScript.step_ticks(target_state, {"motor_enabled": false}, 480)
					var target_root := ""
					var terminal_before_support := false
					var captured_by_authored_target := false
					var metrics: Dictionary = traversal_metrics[nozzle_key]
					metrics["drops"] = int(metrics["drops"]) + 1
					for event_value in target_result.get("events", []):
						if typeof(event_value) != TYPE_DICTIONARY or str((event_value as Dictionary).get("body_id", "")) != str(target_coin.get("id", "")):
							continue
						if str((event_value as Dictionary).get("kind", "")) == "peg_impact":
							metrics["peg_contacts"] = int(metrics["peg_contacts"]) + 1
							metrics["audio_contacts"] = int(metrics["audio_contacts"]) + 1
						if str((event_value as Dictionary).get("kind", "")) == "plinko_cup":
							captured_by_authored_target = true
							var capture_counts: Dictionary = metrics["capture_counts"]
							var captured_id := str((event_value as Dictionary).get("target_id", ""))
							capture_counts[captured_id] = int(capture_counts.get(captured_id, 0)) + 1
							var capture_x := int((event_value as Dictionary).get("x", target_x))
							var capture_bin := str(clampi(capture_x / 5000, 0, 19))
							var capture_bins: Dictionary = metrics["landing_bins"]
							capture_bins[capture_bin] = int(capture_bins.get(capture_bin, 0)) + 1
							metrics["min_x"] = mini(int(metrics["min_x"]), capture_x)
							metrics["max_x"] = maxi(int(metrics["max_x"]), capture_x)
							break
						if str((event_value as Dictionary).get("kind", "")) in ["tray", "gutter"] and target_root.is_empty():
							terminal_before_support = true
						if bool((event_value as Dictionary).get("first_support", false)):
							target_root = str((event_value as Dictionary).get("support_root", ""))
							break
					var landed_view := _pusher_v3_body(target_state, str(target_coin.get("id", "")))
					var independent_root := str((CoinPusherSolverScript.body_views(target_state).filter(func(view): return str((view as Dictionary).get("id", "")) == str(target_coin.get("id", ""))).front() as Dictionary).get("support_root", "")) if not landed_view.is_empty() else ""
					if not landed_view.is_empty():
						var landing_x := int(landed_view.get("x", target_x))
						var landing_bin := str(clampi(landing_x / 5000, 0, 19))
						var landing_bins: Dictionary = metrics["landing_bins"]
						landing_bins[landing_bin] = int(landing_bins.get(landing_bin, 0)) + 1
						metrics["min_x"] = mini(int(metrics["min_x"]), landing_x)
						metrics["max_x"] = maxi(int(metrics["max_x"]), landing_x)
					elif not captured_by_authored_target:
						metrics["unresolved"] = int(metrics["unresolved"]) + 1
					if not captured_by_authored_target and (target_root != "platform" or independent_root != "platform" or terminal_before_support):
						failures.append("Coin Pusher V3 Cartesian landing failed at %s x=%d phase=%d jitter_sign=%d: event_root=%s view_root=%s terminal_before_support=%s target_capture=%s." % [variation_id, int(target_x), phase, desired_sign, target_root, independent_root, terminal_before_support, captured_by_authored_target])
						return
		for nozzle_key in traversal_metrics:
			var metrics: Dictionary = traversal_metrics[nozzle_key]
			var entropy_bits := 0.0
			for count_value in (metrics["landing_bins"] as Dictionary).values():
				var probability := float(int(count_value)) / float(maxi(1, int(metrics["drops"])))
				if probability > 0.0:
					entropy_bits -= probability * log(probability) / log(2.0)
			metrics["entropy_bits"] = snappedf(entropy_bits, 0.001)
			metrics["lateral_spread"] = int(metrics["max_x"]) - int(metrics["min_x"])
			metrics["capture_rate"] = float((metrics["capture_counts"] as Dictionary).values().reduce(func(total, value): return int(total) + int(value), 0)) / float(maxi(1, int(metrics["drops"])))
			metrics["stuck_count"] = int(metrics["unresolved"])
			# A rare clean path is allowed; it must remain exceptional rather than an
			# aimable strategy. Ninety percent meaningful-contact coverage plus more
			# than one terminal bin locks that distinction without demanding a hit on
			# every deterministic release.
			if int(metrics["unresolved"]) != 0 or int(metrics["peg_contacts"]) * 10 < int(metrics["drops"]) * 9 or (metrics["landing_bins"] as Dictionary).size() < 2:
				failures.append("Coin Pusher V3 Plinko traversal lacked dense-contact variance or left a stuck coin at %s nozzle x=%s: %s." % [variation_id, nozzle_key, JSON.stringify(metrics)])
				return
		var reached_targets := {}
		for metrics_value in traversal_metrics.values():
			for target_id in (metrics_value as Dictionary)["capture_counts"]:
				reached_targets[target_id] = int(reached_targets.get(target_id, 0)) + int(((metrics_value as Dictionary)["capture_counts"] as Dictionary)[target_id])
		for target_id in authored_target_ids:
			if int(reached_targets.get(target_id, 0)) <= 0:
				failures.append("Coin Pusher V3 authored Plinko target %s was unreachable across the exhaustive %s nozzle/phase/jitter sweep." % [target_id, variation_id])
				return
		for target_value in (definition.get("apparatus", {}) as Dictionary).get("targets", []):
			if typeof(target_value) != TYPE_DICTIONARY:
				continue
			var target: Dictionary = target_value
			var target_id := str(target.get("id", ""))
			var reward: Dictionary = target.get("reward", {}) if typeof(target.get("reward", {})) == TYPE_DICTIONARY else {}
			# A 5X cup becomes supercritical at a 20% capture rate. The stricter 8%
			# per-nozzle ceiling leaves substantial margin for bounded rare chains;
			# cash cups use a 10% ceiling so neither reward can become a parking exploit.
			var maximum_rate := 0.08 if str(reward.get("kind", "")) == "drop_multiplier" else 0.10
			for nozzle_key in traversal_metrics:
				var metrics: Dictionary = traversal_metrics[nozzle_key]
				var target_rate := float(int((metrics["capture_counts"] as Dictionary).get(target_id, 0))) / float(maxi(1, int(metrics["drops"])))
				if target_rate > maximum_rate:
					failures.append("Coin Pusher V3 Plinko target %s is exploitable from %s nozzle x=%s: capture_rate=%.6f cap=%.2f." % [target_id, variation_id, nozzle_key, target_rate, maximum_rate])
					return
		print("Coin Pusher V3 Plinko traversal report %s: %s" % [variation_id, JSON.stringify(traversal_metrics)])


func _pusher_v3_signed_release(definition: Dictionary, variation_id: String, target_x: int, phase: int, desired_sign: int) -> Dictionary:
	for seed_index in range(64):
		var state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-CARTESIAN-STATE-%s-%d-%d-%d-%d" % [variation_id, target_x, phase, desired_sign, seed_index]), definition, 0)
		_pusher_v3_hold_phase(state, definition, phase)
		var coin: Dictionary = CoinPusherSolverScript.add_coin(state, _pusher_v3_rng("PUSHER-V3-CARTESIAN-DROP-%s-%d-%d-%d-%d" % [variation_id, target_x, phase, desired_sign, seed_index]), target_x, 1)
		var offset := int(coin.get("x", target_x)) - target_x
		if signi(offset) == desired_sign:
			return {"state": state, "coin": coin, "offset": offset, "seed_index": seed_index}
	return {}


func _check_pusher_v3_production_release_jitter(variation_id: String, definition: Dictionary, failures: Array) -> void:
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var jitter := maxi(0, int(apparatus.get("release_jitter", 0)))
	var velocity_jitter := maxi(0, int(apparatus.get("release_velocity_jitter", 0)))
	var saw_negative := false
	var saw_positive := false
	var saw_velocity_negative := false
	var saw_velocity_positive := false
	for target_x in _pusher_v3_release_targets(definition):
		for seed_index in range(32):
			var state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-JITTER-STATE-%s-%d-%d" % [variation_id, int(target_x), seed_index]), definition, 0)
			var released: Dictionary = CoinPusherSolverScript.add_coin(state, _pusher_v3_rng("PUSHER-V3-JITTER-DROP-%s-%d-%d" % [variation_id, int(target_x), seed_index]), int(target_x), 1)
			var release_x := int(released.get("x", int(target_x)))
			var offset := release_x - int(target_x)
			var release_vx := int(released.get("vx", 0))
			saw_negative = saw_negative or offset < 0
			saw_positive = saw_positive or offset > 0
			saw_velocity_negative = saw_velocity_negative or release_vx < 0
			saw_velocity_positive = saw_velocity_positive or release_vx > 0
			if absi(offset) > jitter:
				failures.append("Coin Pusher V3 production release escaped authored jitter at %s x=%d offset=%d jitter=%d." % [variation_id, int(target_x), offset, jitter])
				return
			if absi(release_vx) > velocity_jitter:
				failures.append("Coin Pusher V3 production release escaped authored velocity jitter at %s vx=%d jitter=%d." % [variation_id, release_vx, velocity_jitter])
				return
	if jitter > 0 and (not saw_negative or not saw_positive):
		failures.append("Coin Pusher V3 production release seed set did not exercise both jitter signs at %s." % variation_id)
	if velocity_jitter > 0 and (not saw_velocity_negative or not saw_velocity_positive):
		failures.append("Coin Pusher V3 production release seed set did not exercise both release-angle signs at %s." % variation_id)


func _pusher_v3_release_targets(definition: Dictionary) -> Array:
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
	if not holes.is_empty():
		return holes.duplicate()
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := int(rail.get("x_max", 92000))
	var rail_run := rail_max - rail_min
	return [rail_min, rail_min + rail_run / 4, rail_min + rail_run / 2, rail_min + rail_run * 3 / 4, rail_max]


func _check_pusher_v3_nestle(machine: Dictionary, failures: Array) -> void:
	var state := _pusher_v3_state(machine, "PUSHER-V3-NESTLE")
	_pusher_v3_hold_phase(state, machine, 0)
	var bodies: Array = state.get("bodies", [])
	bodies.append(_pusher_v3_body_fixture("support_left", 46000, 18000, 0, true, "deck"))
	bodies.append(_pusher_v3_body_fixture("support_right", 54000, 18000, 0, true, "deck"))
	var pocket := _pusher_v3_body_fixture("pocket", 50000, 18000, 1700, false, "")
	pocket["vz"] = -40
	bodies.append(pocket)
	state["opening_body_count"] = 3
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": false}, 30)
	var nestled := _pusher_v3_body(state, "pocket")
	if int(nestled.get("z", -1)) != 1700 or str(nestled.get("support_kind", "")) != "body" or not bool(nestled.get("sleeping", false)):
		failures.append("Coin Pusher V3 nestle regression: a coin did not rest in the two-coin pocket: %s" % JSON.stringify(nestled))


func _check_pusher_v3_face_push(machine: Dictionary, failures: Array) -> void:
	var state := _pusher_v3_state(machine, "PUSHER-V3-FACE-PUSH")
	_pusher_v3_hold_phase(state, machine, 120)
	var bodies: Array = state.get("bodies", [])
	for row in range(3):
		for column in range(3):
			bodies.append(_pusher_v3_body_fixture("mass_%d_%d" % [row, column], 42000 + column * 8200, 53000 - row * 8200, 0, true, "deck"))
	state["opening_body_count"] = bodies.size()
	var front_before := _pusher_v3_min_y(state)
	state["motor_rate_fp"] = 1000
	state["motor_target_rate_fp"] = 1000
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 120)
	var front_after := _pusher_v3_min_y(state)
	if front_after >= front_before - 3000:
		failures.append("Coin Pusher V3 full-height forward face did not advance a three-row deck mass.")


func _check_pusher_v3_collective_ratchet(machine: Dictionary, failures: Array) -> void:
	var state := _pusher_v3_state(machine, "PUSHER-V3-COLLECTIVE-RATCHET")
	_pusher_v3_hold_phase(state, machine, 0)
	var bodies: Array = state.get("bodies", [])
	for row in range(3):
		for column in range(10):
			var x := 7000 + column * 9400 + (350 if row % 2 == 1 else 0)
			var y := 58700 - row * 8200
			bodies.append(_pusher_v3_body_fixture("top_%d_%d" % [row, column], x, y, 3600, true, "platform"))
	state["opening_body_count"] = bodies.size()
	state["skill_stop_engaged"] = false
	state["motor_rate_fp"] = 1000
	state["motor_target_rate_fp"] = 1000
	var tracked_front_ids := {}
	for column in range(10):
		tracked_front_ids["top_2_%d" % column] = true
	var placed_front_id := "top_2_5"
	var deposited_front := {}
	var deposit_at_physical_edge := true
	for _tick in range(720):
		var tick_result: Dictionary = CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 1)
		for event_value in tick_result.get("events", []):
			var event: Dictionary = event_value
			if str(event.get("kind", "")) != "platform_deposit":
				continue
			var body_id := str(event.get("body_id", ""))
			if not tracked_front_ids.has(body_id):
				continue
			deposited_front[body_id] = true
			var deposited_body := _pusher_v3_body(state, body_id)
			var face_y := int(state.get("face_y", 0))
			if deposited_body.is_empty() \
					or str(deposited_body.get("support_kind", "")) != "deck" \
					or int(deposited_body.get("y", face_y)) >= face_y:
				deposit_at_physical_edge = false
	var riding := 0
	for body_value in state.get("bodies", []):
		if str((body_value as Dictionary).get("support_kind", "")) == "platform":
			riding += 1
	if deposited_front.size() < 2:
		failures.append("Coin Pusher V3 collective queue did not physically advance and deposit multiple tracked front coins: %s." % JSON.stringify(deposited_front.keys()))
	if not deposited_front.has(placed_front_id):
		failures.append("Coin Pusher V3 ratchet walk did not carry the tracked placed/front coin to the face edge and deposit it within three cycles.")
	if not deposit_at_physical_edge:
		failures.append("Coin Pusher V3 emitted a platform deposit before the tracked front coin crossed the physical face edge onto the deck.")
	if riding < 16:
		failures.append("Coin Pusher V3 persistent top-stock invariant failed: only %d riding bodies remain." % riding)


func _check_pusher_v3_no_lattice(machine: Dictionary, failures: Array) -> void:
	var rng := _pusher_v3_rng("PUSHER-V3-NO-LATTICE")
	var state: Dictionary = CoinPusherSolverScript.create_machine(rng, machine, 300)
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		body["sleeping"] = false
		body["sleep_ticks"] = 0
		body["vx"] = rng.randi_range(-80, 80)
		body["vy"] = rng.randi_range(-80, 80)
	var settle_result: Dictionary = CoinPusherSolverScript.settle(state, false, 1200)
	var histogram := _pusher_v3_axis_histogram(state)
	if not bool(settle_result.get("settled", false)):
		failures.append("Coin Pusher V3 300-body no-lattice fixture did not settle within 1200 ticks: %s" % JSON.stringify(settle_result))
	if int(histogram.get("sample_count", 0)) < 200 or int(histogram.get("axis_ratio_milli", 1000)) >= 450:
		failures.append("Coin Pusher V3 no-lattice regression: nearest-neighbor axis ratio is %d/1000 over %d samples." % [int(histogram.get("axis_ratio_milli", 0)), int(histogram.get("sample_count", 0))])


func _check_pusher_v3_skill_stop(machine: Dictionary, failures: Array) -> void:
	var state := _pusher_v3_state(machine, "PUSHER-V3-SKILL-STOP")
	_pusher_v3_hold_phase(state, machine, 120)
	CoinPusherSolverScript.set_skill_stop(state, true)
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 24)
	var held_phase := int(state.get("phase_fp", -1))
	if int(state.get("motor_rate_fp", -1)) != 0:
		failures.append("Coin Pusher V3 skill stop did not ramp to zero in 24 ticks.")
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 24)
	if int(state.get("phase_fp", -2)) != held_phase:
		failures.append("Coin Pusher V3 skill stop did not hold the physical platform phase.")
	CoinPusherSolverScript.set_skill_stop(state, false)
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 24)
	if int(state.get("motor_rate_fp", -1)) != 1000 or int(state.get("phase_fp", -1)) == held_phase:
		failures.append("Coin Pusher V3 skill stop release did not ramp back to the live motor.")
	var bank_x_positions := [33200, 41600, 50000, 58400, 66800]
	var bank_drop_seeds := []
	for index in range(bank_x_positions.size()):
		bank_drop_seeds.append("PUSHER-V3-SKILL-STOP-DROP-%d" % index)
	var banked_result := _pusher_v3_skill_stop_release_displacement(machine, bank_x_positions, bank_drop_seeds, "PUSHER-V3-SKILL-STOP-BANK")
	var individual_displacement := 0
	var individual_fixtures_complete := true
	for index in range(bank_x_positions.size()):
		var individual_result := _pusher_v3_skill_stop_release_displacement(
			machine,
			[bank_x_positions[index]],
			[bank_drop_seeds[index]],
			"PUSHER-V3-SKILL-STOP-INDIVIDUAL-%d" % index
		)
		individual_displacement += int(individual_result.get("displacement", 0))
		individual_fixtures_complete = individual_fixtures_complete \
				and int(individual_result.get("banked_count", 0)) == 1 \
				and int(individual_result.get("released_count", 0)) == 1
	if int(banked_result.get("banked_count", 0)) != 5 or int(banked_result.get("released_count", 0)) != 5 or not individual_fixtures_complete:
		failures.append("Coin Pusher V3 skill-stop bank fixture did not retain every physically fed coin through release: bank=%s individuals_complete=%s." % [JSON.stringify(banked_result), individual_fixtures_complete])
	elif int(banked_result.get("displacement", 0)) < individual_displacement:
		failures.append("Coin Pusher V3 five-coin skill-stop bank released only %d displacement versus %d summed individual displacement." % [int(banked_result.get("displacement", 0)), individual_displacement])


func _check_pusher_v3_tray_gutter_ceiling(machine: Dictionary, failures: Array) -> void:
	var state := _pusher_v3_state(machine, "PUSHER-V3-LEDGERS")
	var bodies: Array = state.get("bodies", [])
	bodies.append(_pusher_v3_body_fixture("tray_coin", 50000, 5500, 0, false, "deck"))
	bodies.append(_pusher_v3_body_fixture("gutter_coin", 1000, 5500, 0, false, "deck"))
	state["opening_body_count"] = 2
	_pusher_v3_step_until_bodies_exit(state, ["tray_coin", "gutter_coin"], 60, false)
	if (state.get("tray_ledger", []) as Array).size() != 1 or (state.get("gutter_ledger", []) as Array).size() != 1:
		failures.append("Coin Pusher V3 tray/gutter sensors did not ledger physical exits exactly.")
	var collected: Dictionary = CoinPusherSolverScript.collect_tray(state)
	if int(collected.get("value", 0)) != 1 or int(collected.get("count", 0)) != 1 or not (state.get("tray_ledger", []) as Array).is_empty():
		failures.append("Coin Pusher V3 collection did not transfer exactly the physical tray ledger.")
	var ceiling_state := _pusher_v3_state(machine, "PUSHER-V3-CEILING")
	var ceiling_bodies: Array = ceiling_state.get("bodies", [])
	for index in range(600):
		ceiling_bodies.append(_pusher_v3_body_fixture("ceiling_%03d" % index, 50000, 20000, 0, true, "deck"))
	ceiling_state["opening_body_count"] = 600
	var before := ceiling_bodies.size()
	var refusal: Dictionary = CoinPusherSolverScript.add_coin(ceiling_state, _pusher_v3_rng("PUSHER-V3-CEILING-INSERT"), 50000, 1)
	if bool(refusal.get("accepted", true)) or not bool(refusal.get("returned", false)) or ceiling_bodies.size() != before or int(ceiling_state.get("refused_inserts", 0)) != 1:
		failures.append("Coin Pusher V3 ceiling did not refuse and return the coin without deleting a simulated body.")


func _check_pusher_v3_energy_settle_conservation(machine: Dictionary, failures: Array) -> void:
	var state := _pusher_v3_state(machine, "PUSHER-V3-INVARIANTS")
	_pusher_v3_hold_phase(state, machine, 0)
	var body := _pusher_v3_body_fixture("falling", 50000, 18000, 8000, false, "")
	body["vx"] = 200
	body["vy"] = -150
	body["vz"] = -100
	(state.get("bodies", []) as Array).append(body)
	state["opening_body_count"] = 1
	var settle_result: Dictionary = CoinPusherSolverScript.settle(state, false, 1200)
	var invariants: Dictionary = state.get("last_invariants", {})
	if not bool(settle_result.get("settled", false)):
		failures.append("Coin Pusher V3 stopped-motor settle guarantee exceeded 1200 ticks.")
	if not bool(invariants.get("energy_ok", false)):
		failures.append("Coin Pusher V3 no-energy-gain invariant failed in the stopped-motor fixture.")
	if not bool(invariants.get("conservation_ok", false)):
		failures.append("Coin Pusher V3 conservation reconciliation failed.")
	var conservation_state := _pusher_v3_state(machine, "PUSHER-V3-PER-TICK-CONSERVATION")
	_pusher_v3_hold_phase(conservation_state, machine, 0)
	var conservation_bodies: Array = conservation_state.get("bodies", [])
	conservation_bodies.append(_pusher_v3_body_fixture("per_tick_tray", 50000, 5500, 0, false, "deck"))
	conservation_bodies.append(_pusher_v3_body_fixture("per_tick_gutter", 1000, 12000, 0, false, "deck"))
	conservation_state["opening_body_count"] = conservation_bodies.size()
	for tick in range(60):
		var tick_result: Dictionary = CoinPusherSolverScript.step_ticks(conservation_state, {"motor_enabled": false}, 1)
		var tick_invariants: Dictionary = tick_result.get("invariants", {}) if typeof(tick_result.get("invariants", {})) == TYPE_DICTIONARY else {}
		var reconciled := int(tick_invariants.get("active", -1)) \
				+ int(tick_invariants.get("tray", -1)) \
				+ int(tick_invariants.get("gutter", -1)) == int(tick_invariants.get("origin", -2))
		if not bool(tick_invariants.get("conservation_ok", false)) or not reconciled:
			failures.append("Coin Pusher V3 per-tick conservation failed at fixture tick %d: %s" % [tick, JSON.stringify(tick_invariants)])
			break
	var running_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-RUNNING-SETTLE"), machine, 40)
	CoinPusherSolverScript.add_coin(running_state, _pusher_v3_rng("PUSHER-V3-RUNNING-STIMULUS"), 50000, 1)
	var running_settle: Dictionary = CoinPusherSolverScript.settle(running_state, true, 1200)
	if not bool(running_settle.get("settled", false)):
		failures.append("Coin Pusher V3 running-motor carried-sleep guarantee exceeded 1200 ticks.")


func _check_pusher_v3_input_trace_determinism(machine: Dictionary, failures: Array) -> void:
	var initial: Dictionary = CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-TRACE-INITIAL"), machine, 40)
	var trace := [
		{"tick": int(initial.get("tick", 0)) + 5, "kind": "drop", "x": 42000, "density": 1},
		{"tick": int(initial.get("tick", 0)) + 60, "kind": "skill_stop", "engaged": true},
		{"tick": int(initial.get("tick", 0)) + 96, "kind": "drop", "x": 58000, "density": 2},
		{"tick": int(initial.get("tick", 0)) + 130, "kind": "skill_stop", "engaged": false},
		{"tick": int(initial.get("tick", 0)) + 160, "kind": "nudge", "x": 700, "y": -900},
	]
	var first: Dictionary = CoinPusherSolverScript.replay_input_trace(initial, _pusher_v3_rng("PUSHER-V3-TRACE-RNG"), trace, 260)
	var second: Dictionary = CoinPusherSolverScript.replay_input_trace(initial, _pusher_v3_rng("PUSHER-V3-TRACE-RNG"), trace, 260)
	var first_digest: Dictionary = CoinPusherSolverScript.canonical_digest(first)
	var second_digest: Dictionary = CoinPusherSolverScript.canonical_digest(second)
	if JSON.stringify(first_digest, "", true) != JSON.stringify(second_digest, "", true):
		failures.append("Coin Pusher V3 tick-stamped input trace is not bit-identical across replays.")
	var native_state := initial.duplicate(true)
	var reference_state := initial.duplicate(true)
	CoinPusherSolverScript.step_ticks(native_state, {"input_trace": trace, "rng": _pusher_v3_rng("PUSHER-V3-PARITY-RNG")}, 260)
	CoinPusherSolverScript.step_ticks_reference_for_test(reference_state, {"input_trace": trace, "rng": _pusher_v3_rng("PUSHER-V3-PARITY-RNG")}, 260)
	var native_digest_json := JSON.stringify(CoinPusherSolverScript.canonical_digest(native_state), "", true)
	var reference_digest_json := JSON.stringify(CoinPusherSolverScript.canonical_digest(reference_state), "", true)
	if native_digest_json != reference_digest_json:
		failures.append("Coin Pusher V3 native and integer reference kernels diverged for the same tick-stamped trace.")


func _check_pusher_v3_live_loop_and_persistence(machine: Dictionary, failures: Array) -> void:
	var live_machine := {"simulation": CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-LIVE"), machine, 40), "variation_state": {}, "tell_rung": 0, "alarm_tolerance_remaining": 7, "locked_down": false}
	CoinPusherLiveSessionScript.begin(live_machine, machine, 117)
	var simulation: Dictionary = live_machine["simulation"]
	var start_tick := int(simulation.get("tick", 0))
	CoinPusherLiveSessionScript.advance(live_machine, 1000)
	var catch_up := CoinPusherLiveSessionScript.advance(live_machine, 1200)
	if int(catch_up.get("ticks", 0)) != 4 or int(catch_up.get("backlog_ticks", 0)) < 7 or int(simulation.get("tick", 0)) != start_tick + 4:
		failures.append("Coin Pusher V3 live accumulator skipped backlog or exceeded four catch-up ticks: %s" % JSON.stringify(catch_up))
	var hitch_machine := {"simulation": CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-HITCH"), machine, 0), "variation_state": {}, "tell_rung": 0, "alarm_tolerance_remaining": 7, "locked_down": false}
	CoinPusherLiveSessionScript.begin(hitch_machine, machine, 118)
	CoinPusherLiveSessionScript.advance(hitch_machine, 1000)
	var hitch_first := CoinPusherLiveSessionScript.advance(hitch_machine, 6000)
	var hitch_calls := 1
	while int((hitch_machine["live_session"] as Dictionary).get("accumulator_units", 0)) >= 1000 and hitch_calls < 100:
		CoinPusherLiveSessionScript.advance(hitch_machine, 6000)
		hitch_calls += 1
	if int(hitch_first.get("ticks", 0)) != 4 \
			or int(hitch_first.get("backlog_ticks", 0)) != 296 \
			or int((hitch_machine["simulation"] as Dictionary).get("tick", 0)) != 300 \
			or int((hitch_machine["live_session"] as Dictionary).get("accumulator_units", -1)) != 0:
		failures.append("Coin Pusher V3 discarded elapsed ticks during a five-second hitch or failed to drain the capped backlog: first=%s calls=%d tick=%d units=%d" % [JSON.stringify(hitch_first), hitch_calls, int((hitch_machine["simulation"] as Dictionary).get("tick", 0)), int((hitch_machine["live_session"] as Dictionary).get("accumulator_units", -1))])
	var exit_hitch := {"simulation": CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-EXIT-HITCH"), machine, 0), "variation_state": {}, "tell_rung": 0, "alarm_tolerance_remaining": 7, "locked_down": false}
	CoinPusherLiveSessionScript.begin(exit_hitch, machine, 119)
	CoinPusherLiveSessionScript.advance(exit_hitch, 1000)
	CoinPusherLiveSessionScript.advance(exit_hitch, 6000)
	CoinPusherLiveSessionScript.begin_chunked_settle(exit_hitch)
	var exit_drain := {"draining_backlog": true}
	var exit_drain_calls := 0
	while bool(exit_drain.get("draining_backlog", false)) and exit_drain_calls < 100:
		exit_drain = CoinPusherLiveSessionScript.advance_chunked_settle(exit_hitch, 8)
		exit_drain_calls += 1
	if int((exit_hitch["simulation"] as Dictionary).get("tick", 0)) < 300 \
			or int((exit_hitch["live_session"] as Dictionary).get("accumulator_units", -1)) >= 1000 \
			or exit_drain_calls < 74:
		failures.append("Coin Pusher V3 exit skipped present-time hitch backlog instead of draining it chunkwise: calls=%d tick=%d units=%d." % [exit_drain_calls, int((exit_hitch["simulation"] as Dictionary).get("tick", 0)), int((exit_hitch["live_session"] as Dictionary).get("accumulator_units", -1))])
	var stop_exit := {"simulation": CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-STOP-EXIT"), machine, 40), "variation_state": {}, "tell_rung": 0, "alarm_tolerance_remaining": 7, "locked_down": false}
	CoinPusherLiveSessionScript.begin(stop_exit, machine, 120)
	var stop_simulation: Dictionary = stop_exit["simulation"]
	CoinPusherSolverScript.set_skill_stop(stop_simulation, true)
	var stop_event := CoinPusherLiveSessionScript.queue_input(stop_exit, {"kind": "skill_stop", "engaged": true})
	var stop_trace_before: Array = ((stop_exit["live_session"] as Dictionary).get("input_trace", []) as Array).duplicate(true)
	var stop_begin := CoinPusherLiveSessionScript.begin_chunked_settle(stop_exit)
	var stop_session: Dictionary = stop_exit["live_session"]
	var stop_exit_released := not bool(stop_simulation.get("skill_stop_engaged", true)) \
			and int(stop_simulation.get("motor_target_rate_fp", 0)) == CoinPusherSolverScript.FP \
			and int(stop_session.get("input_cursor", -1)) == stop_trace_before.size() \
			and (stop_session.get("input_trace", []) as Array) == stop_trace_before \
			and int(stop_begin.get("pending_inputs_drained", 0)) == 1 \
			and int(stop_begin.get("input_drain_ticks", 0)) == 1 \
			and int(stop_event.get("tick", -1)) + 1 == int(stop_simulation.get("tick", -2))
	var stop_settle := {"done": false}
	var stop_settle_chunks := 0
	while not bool(stop_settle.get("done", false)) and stop_settle_chunks < 160:
		stop_settle = CoinPusherLiveSessionScript.advance_chunked_settle(stop_exit, 8)
		stop_settle_chunks += 1
	var carried_sleep_count := 0
	for body_value in stop_simulation.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("support_kind", "")) == "platform" \
				and bool((body_value as Dictionary).get("carried_sleep", false)):
			carried_sleep_count += 1
	var motor_on_carried_sleep_settled := bool(stop_settle.get("done", false)) \
			and not bool(stop_simulation.get("skill_stop_engaged", true)) \
			and int(stop_simulation.get("motor_target_rate_fp", 0)) == CoinPusherSolverScript.FP \
			and carried_sleep_count > 0 \
			and CoinPusherSolverScript.all_steady(stop_simulation, true)
	if not stop_exit_released or not motor_on_carried_sleep_settled:
		failures.append("Coin Pusher V3 same-tick SKILL STOP -> EXIT reapplied a pending stop or failed motor-on carried-sleep settlement: begin=%s settle=%s trace=%s." % [JSON.stringify(stop_begin), JSON.stringify(stop_settle), JSON.stringify(stop_trace_before)])
	var representative := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-SNAPSHOT-250"), machine, 250)
	var representative_snapshot := CoinPusherLiveSessionScript.make_snapshot(representative, {})
	var representative_bytes := JSON.stringify(representative_snapshot).to_utf8_buffer().size()
	var cap_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-SNAPSHOT-CAP"), machine, int(machine.get("ceiling", 600)))
	var cap_bytes := JSON.stringify(CoinPusherLiveSessionScript.make_snapshot(cap_state, {})).to_utf8_buffer().size()
	if representative_bytes > 2400 or cap_bytes > 5000:
		failures.append("Coin Pusher V3 compact snapshot missed the ~2 KB representative target or scaled nonlinearly at cap: 250=%d cap=%d." % [representative_bytes, cap_bytes])
	var loaded_tray_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-LOADED-TRAY"), machine, 50)
	var loaded_tray: Array = []
	for tray_index in range(300):
		loaded_tray.append({"kind": "coin", "value": 1, "item_id": "", "provenance": {"variation_id": "jackpot_ridge", "ridge_multiplier": 3} if tray_index % 5 == 0 else {}})
	loaded_tray.append({"kind": "rider", "value": 0, "item_id": "coffee", "provenance": {}})
	loaded_tray_state["tray_ledger"] = loaded_tray
	loaded_tray_state["opening_body_count"] = (loaded_tray_state.get("bodies", []) as Array).size() + loaded_tray.size()
	var loaded_tray_snapshot := CoinPusherLiveSessionScript.make_snapshot(loaded_tray_state, {})
	var loaded_tray_bytes := JSON.stringify(loaded_tray_snapshot).to_utf8_buffer().size()
	print("Coin Pusher V3 compact snapshot bytes: representative=%d cap=%d loaded_tray=%d" % [representative_bytes, cap_bytes, loaded_tray_bytes])
	var loaded_tray_restore := CoinPusherLiveSessionScript.restore_snapshot(loaded_tray_snapshot, machine)
	var loaded_tray_collect := CoinPusherSolverScript.collect_tray(loaded_tray_restore)
	var loaded_tray_tick := CoinPusherSolverScript.step_ticks(loaded_tray_restore, {"motor_enabled": true}, 1)
	if loaded_tray_bytes > 1800 or int(loaded_tray_collect.get("count", 0)) != loaded_tray.size() \
			or not (loaded_tray_collect.get("items", []) as Array).has("coffee") \
			or not bool((loaded_tray_tick.get("invariants", {}) as Dictionary).get("conservation_ok", false)):
		failures.append("Coin Pusher V3 heavily loaded tray missed compact persistence/exact-collect conservation: bytes=%d count=%d." % [loaded_tray_bytes, int(loaded_tray_collect.get("count", 0))])
	var growth_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-SNAPSHOT-GROWTH"), machine, 250)
	var growth_before := JSON.stringify(CoinPusherLiveSessionScript.make_snapshot(growth_state, {})).to_utf8_buffer().size()
	var growth_rng := _pusher_v3_rng("PUSHER-V3-SNAPSHOT-GROWTH-DROPS")
	for _drop in range(200):
		CoinPusherSolverScript.add_coin(growth_state, growth_rng, 50000, 1, {})
	var growth_snapshot := CoinPusherLiveSessionScript.make_snapshot(growth_state, {})
	var growth_after := JSON.stringify(growth_snapshot).to_utf8_buffer().size()
	if not (growth_snapshot.get("extra_bodies", []) as Array).is_empty() or growth_after - growth_before > 1600:
		failures.append("Coin Pusher V3 default player drops escaped compact packing: before=%d after=%d extras=%d." % [growth_before, growth_after, (growth_snapshot.get("extra_bodies", []) as Array).size()])
	var vault_growth := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-VAULT-GROWTH"), machine, 250)
	var vault_before := JSON.stringify(CoinPusherLiveSessionScript.make_snapshot(vault_growth, {})).to_utf8_buffer().size()
	var vault_rng := _pusher_v3_rng("PUSHER-V3-VAULT-GROWTH-DROPS")
	for _drop in range(200):
		CoinPusherSolverScript.add_coin(vault_growth, vault_rng, 50000, 1, {"variation_id": "vault_drop", "ridge_multiplier": 1})
	var vault_snapshot := CoinPusherLiveSessionScript.make_snapshot(vault_growth, {})
	var vault_after := JSON.stringify(vault_snapshot).to_utf8_buffer().size()
	if not (vault_snapshot.get("coin_provenance", {}) as Dictionary).is_empty() or vault_after - vault_before > 1600:
		failures.append("Coin Pusher V3 non-paying Vault labels created verbose per-coin provenance growth: before=%d after=%d sidecars=%d." % [vault_before, vault_after, (vault_snapshot.get("coin_provenance", {}) as Dictionary).size()])
	var ridge_growth := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-RIDGE-GROWTH"), machine, 250)
	var ridge_before := JSON.stringify(CoinPusherLiveSessionScript.make_snapshot(ridge_growth, {})).to_utf8_buffer().size()
	var ridge_rng := _pusher_v3_rng("PUSHER-V3-RIDGE-GROWTH-DROPS")
	for _drop in range(200):
		CoinPusherSolverScript.add_coin(ridge_growth, ridge_rng, 50000, 1, {"variation_id": "jackpot_ridge", "ridge_multiplier": 3})
	var ridge_snapshot := CoinPusherLiveSessionScript.make_snapshot(ridge_growth, {})
	var ridge_after := JSON.stringify(ridge_snapshot).to_utf8_buffer().size()
	if not (ridge_snapshot.get("extra_bodies", []) as Array).is_empty() \
			or not (ridge_snapshot.get("coin_provenance", {}) as Dictionary).is_empty() \
			or ridge_after - ridge_before > 1800:
		failures.append("Coin Pusher V3 meaningful Ridge drops escaped compact multiplier packing: before=%d after=%d extras=%d sidecars=%d." % [ridge_before, ridge_after, (ridge_snapshot.get("extra_bodies", []) as Array).size(), (ridge_snapshot.get("coin_provenance", {}) as Dictionary).size()])
	var provenance_state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-PROVENANCE"), machine, 0)
	var provenance_rng := _pusher_v3_rng("PUSHER-V3-PROVENANCE-DROP")
	var provenance_coin := CoinPusherSolverScript.add_coin(provenance_state, provenance_rng, 50000, 1, {"variation_id": "jackpot_ridge", "ridge_multiplier": 3})
	var provenance_snapshot := CoinPusherLiveSessionScript.make_snapshot(provenance_state, {})
	var provenance_restore := CoinPusherLiveSessionScript.restore_snapshot(provenance_snapshot, machine)
	var restored_provenance := _pusher_v3_body(provenance_restore, str(provenance_coin.get("id", "")))
	if int((((restored_provenance.get("meta", {}) as Dictionary).get("provenance", {}) as Dictionary).get("ridge_multiplier", 0))) != 3 \
			or not (provenance_snapshot.get("extra_bodies", []) as Array).is_empty():
		failures.append("Coin Pusher V3 meaningful Ridge provenance did not round-trip through the compact sidecar.")
	var trace_before := (live_machine["live_session"]["input_trace"] as Array).size()
	CoinPusherLiveSessionScript.queue_input(live_machine, {"kind": "carriage", "x": 41000})
	CoinPusherLiveSessionScript.queue_input(live_machine, {"kind": "skill_stop", "engaged": true})
	CoinPusherLiveSessionScript.queue_input(live_machine, {"kind": "collect"})
	if (live_machine["live_session"]["input_trace"] as Array).size() != trace_before + 3:
		failures.append("Coin Pusher V3 did not append every free input to the deterministic trace.")
	# Collection is the only operation that removes tray value; stepping and drops
	# leave the ledger intact and therefore cannot credit money implicitly.
	var ledger_fixture_bodies: Array = simulation.get("bodies", [])
	if not ledger_fixture_bodies.is_empty():
		ledger_fixture_bodies.pop_back()
	simulation["tray_ledger"] = [{"kind": "coin", "value": 3, "item_id": "", "provenance": {}}]
	CoinPusherSolverScript.step_ticks(simulation, {"motor_enabled": true}, 1)
	if (simulation.get("tray_ledger", []) as Array).size() != 1:
		failures.append("Coin Pusher V3 credited or cleared tray money without COLLECT.")
	var collected := CoinPusherSolverScript.collect_tray(simulation)
	if int(collected.get("value", 0)) != 3 or not (simulation.get("tray_ledger", []) as Array).is_empty():
		failures.append("Coin Pusher V3 COLLECT did not transfer the tray ledger exactly once.")
	var tray_persist := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-TRAY-PERSIST"), machine, 10)
	(tray_persist.get("bodies", []) as Array).pop_back()
	tray_persist["tray_ledger"] = [{"kind": "coin", "value": 2, "item_id": "", "provenance": {}}]
	var tray_snapshot := CoinPusherLiveSessionScript.make_snapshot(tray_persist, {})
	var tray_restore := CoinPusherLiveSessionScript.restore_snapshot(tray_snapshot, machine)
	var restored_tick := CoinPusherSolverScript.step_ticks(tray_restore, {"motor_enabled": true}, 1)
	var restored_collect := CoinPusherSolverScript.collect_tray(tray_restore)
	var post_collect_tick := CoinPusherSolverScript.step_ticks(tray_restore, {"motor_enabled": true}, 1)
	var duplicate_collect := CoinPusherSolverScript.collect_tray(tray_restore)
	if not bool((restored_tick.get("invariants", {}) as Dictionary).get("conservation_ok", false)) \
			or int(restored_collect.get("value", 0)) != 2 or int(restored_collect.get("count", 0)) != 1 \
			or not bool((post_collect_tick.get("invariants", {}) as Dictionary).get("conservation_ok", false)) \
			or int(duplicate_collect.get("count", -1)) != 0:
		failures.append("Coin Pusher V3 nonempty tray did not restore, collect exactly once, and continue motor ticks conservation-green.")
	# Preserve sparse IDs and support truth. A tall deck stack is not platform
	# carried merely because its z is above PLATFORM_TOP_Z.
	var bodies: Array = simulation.get("bodies", [])
	var tall: Dictionary = {}
	if bodies.size() >= 3:
		bodies.remove_at(1)
		tall = bodies[1]
		tall["z"] = 5100
		tall["support_kind"] = "deck"
		tall["carried_sleep"] = false
		for body_value in bodies:
			var body: Dictionary = body_value
			body["x"] = (int(body.get("x", 0)) + 50) / 100 * 100
			body["y"] = (int(body.get("y", 0)) + 50) / 100 * 100
			body["z"] = (int(body.get("z", 0)) + 50) / 100 * 100
	var snapshot := CoinPusherLiveSessionScript.make_snapshot(simulation, live_machine)
	var restored := CoinPusherLiveSessionScript.restore_snapshot(snapshot, machine)
	var restored_ids: Array = (restored.get("bodies", []) as Array).map(func(body: Dictionary): return str(body.get("id", "")))
	var source_ids: Array = bodies.map(func(body: Dictionary): return str(body.get("id", "")))
	if restored_ids != source_ids:
		failures.append("Coin Pusher V3 settled persistence changed sparse body identities.")
	var restored_tall := _pusher_v3_body(restored, str(tall.get("id", "")))
	if str(restored_tall.get("support_kind", "")) != "deck" or bool(restored_tall.get("carried_sleep", true)):
		failures.append("Coin Pusher V3 restored a tall deck stack as platform-carried.")
	var visit_digest := JSON.stringify(CoinPusherSolverScript.canonical_digest(restored), "", true)
	for _visit in range(79):
		restored = CoinPusherLiveSessionScript.restore_snapshot(CoinPusherLiveSessionScript.make_snapshot(restored, live_machine), machine)
	if JSON.stringify(CoinPusherSolverScript.canonical_digest(restored), "", true) != visit_digest:
		failures.append("Coin Pusher V3 visit 1 and visit 80 settled digests diverged.")
	if JSON.stringify(snapshot).contains("accumulator_units") or JSON.stringify(snapshot).contains("input_trace"):
		failures.append("Coin Pusher V3 serialized transient accumulator/backlog into settled outcome state.")


func _check_pusher_v3_production_rail_drag(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 production rail-drag test could not load the game module.")
		return
	var game: GameModule = module_script.new()
	game.setup(definition, library)
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-RAIL-DRAG", RunState.standard_challenge("PUSHER-V3-RAIL-DRAG"))
	var environment := {"id": "pusher_v3_rail_drag_fixture", "world_node_id": "pusher_v3_rail_drag_fixture", "game_states": {}}
	var generated: Dictionary = game.generate_environment_state(run_state, environment, _pusher_v3_rng("PUSHER-V3-RAIL-DRAG-GENERATION"))
	environment["game_states"] = {"coin_pusher": generated}
	game.enter(run_state, environment)
	var live_map: Dictionary = game.get("_live_machines")
	var live_machine: Dictionary = live_map.values()[0] if not live_map.is_empty() else {}
	var simulation: Dictionary = live_machine.get("simulation", {}) if typeof(live_machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var tick_before := int(simulation.get("tick", -1))
	var bankroll_before := run_state.bankroll
	var turns_before := int(environment.get("turns", 0))
	var surface := game.surface_state(run_state, environment, {})
	var begin := game.surface_pointer_command("coin_pusher_carriage_drag", 0, "begin", Vector2(176, 180), {}, run_state, environment)
	var move := game.surface_pointer_command("coin_pusher_carriage_drag", 0, "move", Vector2(450, 180), begin.get("ui_state", {}), run_state, environment)
	var ending := game.surface_pointer_command("coin_pusher_carriage_drag", 0, "end", Vector2(724, 180), move.get("ui_state", {}), run_state, environment)
	var session: Dictionary = live_machine.get("live_session", {}) if typeof(live_machine.get("live_session", {})) == TYPE_DICTIONARY else {}
	var trace: Array = session.get("input_trace", []) if typeof(session.get("input_trace", [])) == TYPE_ARRAY else []
	var trace_exact := trace.size() == 3
	if trace_exact:
		trace_exact = str((trace[0] as Dictionary).get("kind", "")) == "carriage" \
				and int((trace[0] as Dictionary).get("x", -1)) == 8000 \
				and int((trace[1] as Dictionary).get("x", -1)) == 50000 \
				and int((trace[2] as Dictionary).get("x", -1)) == 92000
		for event_value in trace:
			trace_exact = trace_exact and int((event_value as Dictionary).get("tick", -2)) == tick_before
	var production_drag_ok := bool(surface.get("surface_pointer_coalesce_moves", false)) \
			and game.surface_pointer_uses_lightweight_ui_state("coin_pusher_carriage_drag") \
			and bool(begin.get("handled", false)) and bool(move.get("handled", false)) and bool(ending.get("handled", false)) \
			and bool((begin.get("ui_state", {}) as Dictionary).get("coin_pusher_rail_drag_active", false)) \
			and not bool((ending.get("ui_state", {}) as Dictionary).get("coin_pusher_rail_drag_active", true)) \
			and int(simulation.get("carriage_x", -1)) == 92000 \
			and int((ending.get("surface_state_patch", {}) as Dictionary).get("coin_pusher_carriage_x", -1)) == 92000 \
			and trace_exact and run_state.bankroll == bankroll_before and int(environment.get("turns", 0)) == turns_before
	if not production_drag_ok:
		failures.append("Coin Pusher V3 production rail_slot did not provide a continuous deterministic pointer drag without charging or advancing a turn: begin=%s move=%s end=%s trace=%s." % [JSON.stringify(begin), JSON.stringify(move), JSON.stringify(ending), JSON.stringify(trace)])


func _check_pusher_v3_v2_production_migration(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 migration test could not load the production module.")
		return
	var legacy_sub_game := {"legacy_round": 7, "armed": true, "cells": [2, 0, 3]}
	var legacy_machine := {
		"schema": "coin_pusher_discrete_pile",
		"version": 2,
		"variation_id": "quarter_falls",
		"variation_state": legacy_sub_game.duplicate(true),
		"tray_value": 4,
		"base_alarm_tolerance": 9,
		"alarm_tolerance_remaining": 5,
		"tell_rung": 2,
		"staff_watch_memory": true,
		"locked_down": false,
		"action_count": 11,
		"total_cost": 11,
		"total_payout": 6,
	}
	var unrelated_state := {"schema": "slot_machine_state", "version": 9, "opaque": [3, {"keep": "exact"}]}
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-V2-MIGRATION", RunState.standard_challenge("PUSHER-V3-V2-MIGRATION"))
	var environment := {"id": "pusher_v2_migration_fixture", "world_node_id": "pusher_v2_migration_fixture", "game_states": {"coin_pusher": legacy_machine.duplicate(true), "slot": unrelated_state.duplicate(true)}}
	var game: GameModule = module_script.new()
	game.setup(definition, library)
	var activation_before := JSON.stringify(environment, "", true)
	game.enter(run_state, environment)
	var activation_exact := JSON.stringify(environment, "", true) == activation_before and run_state.story_log.is_empty()
	var live_map: Dictionary = game.get("_live_machines")
	var live_machine: Dictionary = live_map.values()[0] if not live_map.is_empty() else {}
	var simulation: Dictionary = live_machine.get("simulation", {}) if typeof(live_machine.get("simulation", {})) == TYPE_DICTIONARY else {}
	var migrated_collect_simulation := simulation.duplicate(true)
	var migrated_collect := CoinPusherSolverScript.collect_tray(migrated_collect_simulation)
	var migrated_post_collect := CoinPusherSolverScript.step_ticks(migrated_collect_simulation, {"motor_enabled": false}, 1)
	var migrated_collect_exact := int(migrated_collect.get("count", -1)) == 4 \
			and int(migrated_collect.get("value", -1)) == 4 \
			and bool((migrated_post_collect.get("invariants", {}) as Dictionary).get("conservation_ok", false))
	game.surface_action_command("coin_pusher_carriage_left", 0, false, {}, run_state, environment)
	var first_settled: Dictionary = (((environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary).get("settled_state", {}) as Dictionary).duplicate(true)
	var first_migration_logs := 0
	for entry_value in run_state.story_log:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "coin_pusher_v2_migrated":
			first_migration_logs += 1
	var migrated_exact: bool = activation_exact and migrated_collect_exact \
			and int(live_machine.get("tray_value", -1)) == 4 \
			and (simulation.get("tray_ledger", []) as Array).size() == 4 \
			and live_machine.get("variation_state", {}) == legacy_sub_game \
			and int(live_machine.get("base_alarm_tolerance", -1)) == 9 \
			and int(live_machine.get("alarm_tolerance_remaining", -1)) == 5 \
			and int(live_machine.get("tell_rung", -1)) == 2 \
			and bool(live_machine.get("staff_watch_memory", false)) \
			and first_migration_logs == 1
	if not migrated_exact:
		failures.append("Coin Pusher V3 production migration did not carry V2 tray/sub-game/alarm state and log exactly once.")
	game.begin_chunked_exit_settle(run_state, environment)
	var settle_result := {"done": false}
	var settle_chunks := 0
	while not bool(settle_result.get("done", false)) and settle_chunks < 24:
		settle_result = game.advance_chunked_exit_settle(run_state, environment, 64)
		settle_chunks += 1
	game.finalize_chunked_exit_settle(run_state, environment)
	var settled_before_reentry: Dictionary = (((environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary).get("settled_state", {}) as Dictionary).duplicate(true)
	game.enter(run_state, environment)
	var settled_after_reentry: Dictionary = (((environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary).get("settled_state", {}) as Dictionary).duplicate(true)
	var migration_logs_after_reentry := 0
	for entry_value in run_state.story_log:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "coin_pusher_v2_migrated":
			migration_logs_after_reentry += 1
	if not bool(settle_result.get("done", false)) or settled_before_reentry != settled_after_reentry or migration_logs_after_reentry != 1:
		failures.append("Coin Pusher V3 migrated state reseeded or relogged on stable re-entry.")
	var second_run := RunState.new()
	second_run.start_new("PUSHER-V3-V2-MIGRATION", RunState.standard_challenge("PUSHER-V3-V2-MIGRATION"))
	var second_environment := {"id": "pusher_v2_migration_fixture", "world_node_id": "pusher_v2_migration_fixture", "game_states": {"coin_pusher": legacy_machine.duplicate(true)}}
	var second_game: GameModule = module_script.new()
	second_game.setup(definition, library)
	second_game.enter(second_run, second_environment)
	second_game.surface_action_command("coin_pusher_carriage_left", 0, false, {}, second_run, second_environment)
	var second_settled: Dictionary = (((second_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary).get("settled_state", {}) as Dictionary)
	if first_settled != second_settled:
		failures.append("Coin Pusher V3 V2 migration reseed was not deterministic for the same run seed and machine node.")
	var non_pusher_run := RunState.new()
	non_pusher_run.start_new("PUSHER-V3-NON-PUSHER", RunState.standard_challenge("PUSHER-V3-NON-PUSHER"))
	var non_pusher_environment := {"id": "non_pusher_fixture", "game_states": {"slot": unrelated_state.duplicate(true)}}
	var non_pusher_before := JSON.stringify(non_pusher_environment, "", true)
	game.call("_read_machine_state", non_pusher_run, non_pusher_environment)
	if JSON.stringify(non_pusher_environment, "", true) != non_pusher_before:
		failures.append("Coin Pusher V3 read/migration path changed a non-pusher save byte contract.")
	var fresh_run := RunState.new()
	fresh_run.start_new("PUSHER-V3-FRESH-ACTIVATION", RunState.standard_challenge("PUSHER-V3-FRESH-ACTIVATION"))
	var fresh_environment := {"id": "pusher_v3_fresh_fixture", "world_node_id": "pusher_v3_fresh_fixture", "game_states": {}}
	var fresh_game: GameModule = module_script.new()
	fresh_game.setup(definition, library)
	var fresh_machine: Dictionary = fresh_game.call("_generate_machine_state", fresh_run, fresh_environment, _pusher_v3_rng("PUSHER-V3-FRESH-ACTIVATION"))
	var fresh_snapshot: Dictionary = fresh_machine.get("settled_state", {}) if typeof(fresh_machine.get("settled_state", {})) == TYPE_DICTIONARY else {}
	if str(fresh_snapshot.get("schema", "")) != CoinPusherLiveSessionScript.SNAPSHOT_SCHEMA \
			or fresh_machine.has("simulation") or fresh_machine.has("live_session") \
			or int(fresh_snapshot.get("coin_count", 0)) + (fresh_snapshot.get("extra_bodies", []) as Array).size() <= 0:
		failures.append("Coin Pusher V3 fresh generation did not persist only a populated compact settled snapshot.")
	fresh_environment["game_states"] = {"coin_pusher": fresh_machine}
	var fresh_before := JSON.stringify(fresh_environment, "", true)
	fresh_game.enter(fresh_run, fresh_environment)
	if JSON.stringify(fresh_environment, "", true) != fresh_before:
		failures.append("Coin Pusher V3 fresh compact machine mutated durable state during passive activation.")


func _check_pusher_v3_all_variation_migrations(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 all-variation migration test could not load production module.")
		return
	for variation_id in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
		var legacy_variation := {"legacy_marker": variation_id, "counter": 17, "opaque": [1, {"keep": true}]}
		if variation_id == "jackpot_ridge":
			legacy_variation.merge({"pucks": [{"id": "legacy_ridge", "kind": "lock"}], "armed_multipliers": [{"multiplier": 3, "remaining": 2}], "ridge_run_cycles_remaining": 2, "ridge_cycle_serial": 7, "multiplier_banks_by_cycle": {"7": 2}}, true)
		elif variation_id == "vault_drop":
			legacy_variation.merge({"meter_id": "vault_drop:migration_vault_drop", "meter_value": 211, "fragments": [{"id": "legacy_fragment"}], "banked_fragments": 2, "vault_round_active": true, "vault_cells": [{"kind": "reset", "opened": false}], "peeked_cell": 0}, true)
		var legacy := {
			"schema": "coin_pusher_discrete_pile", "version": 2, "variation_id": variation_id,
			"variation_state": legacy_variation.duplicate(true), "tray_value": 3,
			"base_alarm_tolerance": 8, "alarm_tolerance_remaining": 4, "tell_rung": 2,
			"staff_watch_memory": true, "locked_down": false, "action_count": 9,
		}
		var unrelated := {"schema": "unrelated_fixture", "opaque": [variation_id, 91]}
		var run_state := RunState.new()
		run_state.start_new("PUSHER-V3-MIGRATION-%s" % variation_id, RunState.standard_challenge("PUSHER-V3-MIGRATION-%s" % variation_id))
		var environment := {"id": "migration_%s" % variation_id, "world_node_id": "migration_%s" % variation_id, "game_states": {"coin_pusher": legacy.duplicate(true), "unrelated": unrelated.duplicate(true)}}
		var game: GameModule = module_script.new()
		game.setup(definition, library)
		var before_enter := JSON.stringify(environment, "", true)
		game.enter(run_state, environment)
		if JSON.stringify(environment, "", true) != before_enter:
			failures.append("Coin Pusher V3 %s migration mutated durable data at passive entry." % variation_id)
			return
		var live_map: Dictionary = game.get("_live_machines")
		var live: Dictionary = live_map.values()[0] if not live_map.is_empty() else {}
		var simulation: Dictionary = live.get("simulation", {}) if typeof(live.get("simulation", {})) == TYPE_DICTIONARY else {}
		var collect_probe := CoinPusherSolverScript.collect_tray(simulation.duplicate(true))
		game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, run_state, environment)
		var migration_logs := 0
		for entry_value in run_state.story_log:
			if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "coin_pusher_v2_migrated":
				migration_logs += 1
		var migrated_variation: Dictionary = live.get("variation_state", {}) if typeof(live.get("variation_state", {})) == TYPE_DICTIONARY else {}
		var legacy_fields_preserved := _pusher_v3_contains_legacy_shape(migrated_variation, legacy_variation)
		if str(live.get("variation_id", "")) != variation_id or not legacy_fields_preserved \
				or int(collect_probe.get("count", -1)) != 3 or int(collect_probe.get("value", -1)) != 3 \
				or int(live.get("alarm_tolerance_remaining", -1)) != 4 or int(live.get("tell_rung", -1)) != 2 \
				or not bool(live.get("staff_watch_memory", false)) or migration_logs != 1 \
				or ((environment.get("game_states", {}) as Dictionary).get("unrelated", {}) as Dictionary) != unrelated:
			failures.append("Coin Pusher V3 %s migration lost variation/tray/alarm/opaque state or logged incorrectly." % variation_id)
			return
		var initial_migrated_digest := CoinPusherSolverScript.canonical_digest(simulation)
		var initial_migrated_variation := (live.get("variation_state", {}) as Dictionary).duplicate(true)
		game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, run_state, environment)
		var logs_after_second_write := 0
		for entry_value in run_state.story_log:
			if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("type", "")) == "coin_pusher_v2_migrated":
				logs_after_second_write += 1
		if logs_after_second_write != 1:
			failures.append("Coin Pusher V3 %s migration logged more than once." % variation_id)
			return
		game.begin_chunked_exit_settle(run_state, environment)
		var settle := {"done": false}
		var chunks := 0
		while not bool(settle.get("done", false)) and chunks < 160:
			settle = game.advance_chunked_exit_settle(run_state, environment, 8)
			chunks += 1
		game.finalize_chunked_exit_settle(run_state, environment)
		var durable_after_settle := JSON.stringify(environment.get("game_states", {}), "", true)
		game.enter(run_state, environment)
		if not bool(settle.get("done", false)) or JSON.stringify(environment.get("game_states", {}), "", true) != durable_after_settle:
			failures.append("Coin Pusher V3 %s migration was not byte-stable across settle/re-entry." % variation_id)
			return
		var reseed_run := RunState.new()
		reseed_run.start_new("PUSHER-V3-MIGRATION-%s" % variation_id, RunState.standard_challenge("PUSHER-V3-MIGRATION-%s" % variation_id))
		var reseed_environment := {"id": "migration_%s" % variation_id, "world_node_id": "migration_%s" % variation_id, "game_states": {"coin_pusher": legacy.duplicate(true), "unrelated": unrelated.duplicate(true)}}
		var reseed_game: GameModule = module_script.new()
		reseed_game.setup(definition, library)
		reseed_game.enter(reseed_run, reseed_environment)
		reseed_game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, reseed_run, reseed_environment)
		var reseed_live_map: Dictionary = reseed_game.get("_live_machines")
		var reseed_live: Dictionary = reseed_live_map.values()[0] if not reseed_live_map.is_empty() else {}
		if CoinPusherSolverScript.canonical_digest(reseed_live.get("simulation", {})) != initial_migrated_digest \
				or reseed_live.get("variation_state", {}) != initial_migrated_variation:
			failures.append("Coin Pusher V3 %s real-shaped migration reseed was not deterministic." % variation_id)
			return


func _pusher_v3_contains_legacy_shape(actual: Variant, legacy: Variant) -> bool:
	if typeof(legacy) == TYPE_DICTIONARY:
		if typeof(actual) != TYPE_DICTIONARY:
			return false
		for key in (legacy as Dictionary).keys():
			if not (actual as Dictionary).has(key) or not _pusher_v3_contains_legacy_shape((actual as Dictionary)[key], (legacy as Dictionary)[key]):
				return false
		return true
	if typeof(legacy) == TYPE_ARRAY:
		if typeof(actual) != TYPE_ARRAY or (actual as Array).size() != (legacy as Array).size():
			return false
		for index in range((legacy as Array).size()):
			if not _pusher_v3_contains_legacy_shape((actual as Array)[index], (legacy as Array)[index]):
				return false
		return true
	return actual == legacy


func _check_pusher_v3_production_integration_boundaries(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 integration boundary test could not load production module.")
		return
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-INTEGRATIONS", RunState.standard_challenge("PUSHER-V3-INTEGRATIONS"))
	var generator: GameModule = module_script.new()
	generator.setup(definition, library)
	var base_environment := {"id": "pusher_integration", "world_node_id": "pusher_integration", "scenario_game_modifiers": {"coin_pusher": {"variation_id": "jackpot_ridge"}}, "game_states": {}}
	var generated: Dictionary = generator.generate_environment_state(run_state, base_environment, _pusher_v3_rng("PUSHER-V3-INTEGRATION-GENERATE"))
	base_environment["game_states"] = {"coin_pusher": generated}
	var durable_before := JSON.stringify(base_environment["game_states"], "", true)
	var busy_environment := base_environment.duplicate(true)
	busy_environment["scenario_game_modifiers"]["machine_occupancy"] = "occupied"
	var busy_game: GameModule = module_script.new()
	busy_game.setup(definition, library)
	var enter_result := busy_game.enter(run_state, busy_environment)
	var before_digest: String = busy_game.deterministic_state_digest(busy_environment)
	var action_result := busy_game.surface_action_command("coin_pusher_drop", 0, false, {}, run_state, busy_environment)
	var pointer_result := busy_game.surface_pointer_command("coin_pusher_carriage_drag", 0, "begin", Vector2(400, 180), {}, run_state, busy_environment)
	var resolve_result := busy_game.resolve_with_context("drop_coin", 1, run_state, busy_environment, _pusher_v3_rng("PUSHER-V3-BUSY-RESOLVE"), {})
	var patch: Dictionary = busy_game.surface_realtime_state_patch(run_state, busy_environment, {"surface_time_msec": 9000}, {})
	var after_digest: String = busy_game.deterministic_state_digest(busy_environment)
	var busy_object: Dictionary = busy_game.environment_object_state(run_state, busy_environment)
	var busy_live: Dictionary = busy_game.get("_live_machines")
	if busy_live.size() != 0 or before_digest != after_digest or JSON.stringify(busy_environment["game_states"], "", true) != durable_before \
			or not bool(action_result.get("handled", false)) or not bool(pointer_result.get("handled", false)) \
			or int((resolve_result.get("deltas", {}) as Dictionary).get("bankroll_delta", 0)) != 0 \
			or not bool(busy_object.get("coin_pusher_busy", false)) or not str(enter_result.get("message", "")).contains("convoy"):
		failures.append("Coin Pusher V3 occupied Convoy boundary opened/ticked/charged/mutated the machine: live=%d digest=%s durable=%s action=%s pointer=%s resolve=%s patch_tick=%d object=%s." % [busy_live.size(), before_digest == after_digest, JSON.stringify(busy_environment["game_states"], "", true) == durable_before, JSON.stringify(action_result), JSON.stringify(pointer_result), JSON.stringify(resolve_result), int(patch.get("coin_pusher_liveness_ticks", -1)), JSON.stringify(busy_object)])
		return
	# Graveyard reset is generation/action-boundary only and deterministic by token.
	var reset_environment := base_environment.duplicate(true)
	reset_environment["scenario_game_modifiers"]["coin_pusher"] = {"variation_id": "jackpot_ridge", "reset_pile": true, "reset_token": "graveyard_contract"}
	var reset_game: GameModule = module_script.new()
	reset_game.setup(definition, library)
	var reset_once: Dictionary = reset_game.call("_ensure_machine_state", run_state, reset_environment, true)
	var reset_digest := JSON.stringify(reset_once.get("settled_state", {}), "", true)
	var reset_twice: Dictionary = reset_game.call("_ensure_machine_state", run_state, reset_environment, true)
	if str(reset_once.get("scenario_reset_token", "")) != "graveyard_contract" or reset_digest != JSON.stringify(reset_twice.get("settled_state", {}), "", true):
		failures.append("Coin Pusher V3 Graveyard reset did not occur exactly once at the deterministic token boundary.")
		return
	# Police Sweep security channels tighten tolerance at generation, never per frame.
	var sweep_environment := {"id": "pusher_sweep", "world_node_id": "pusher_sweep", "security_profile": {"machine_alarm_tolerance_band": "normal", "security_override_channels": {"police_sweep": {"base_machine_alarm_tolerance_band": "normal", "pusher_alarm_tolerance_band_delta": -2}}}, "scenario_game_modifiers": {"coin_pusher": {"variation_id": "jackpot_ridge"}}, "game_states": {}}
	var sweep_machine: Dictionary = generator.generate_environment_state(run_state, sweep_environment, _pusher_v3_rng("PUSHER-V3-SWEEP-GENERATE"))
	if int(sweep_machine.get("applied_security_tolerance_modifier", 0)) != -2:
		failures.append("Coin Pusher V3 Police Sweep channel did not tighten alarm tolerance at generation.")


func _check_pusher_v3_items_alarm_and_rumor(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	var game: GameModule = load(str(definition.get("module_path", ""))).new()
	game.setup(definition, library)
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-ITEMS-ALARM", RunState.standard_challenge("PUSHER-V3-ITEMS-ALARM"))
	# Reputation accepts incidents only for real nodes in the seeded town graph.
	# Enter one through production generation, then host the focused cabinet
	# fixture at that node rather than inventing an unregistered test-only node.
	RunGenerator.new(library).next_environment(run_state)
	var reputation_node := run_state.current_world_node_id()
	for item_id in ["weighted_keyring", "mags_nudge_dampener", "cold_quarters", "coin_return_shim"]:
		run_state.add_item(item_id)
	var environment := {"id": "pusher_items_alarm", "world_node_id": reputation_node, "scenario_game_modifiers": {"coin_pusher": {"variation_id": "jackpot_ridge"}}, "game_states": {}}
	var generated: Dictionary = game.generate_environment_state(run_state, environment, _pusher_v3_rng("PUSHER-V3-ITEMS-GENERATE"))
	environment["game_states"] = {"coin_pusher": generated}
	game.enter(run_state, environment)
	var live_map: Dictionary = game.get("_live_machines")
	var live: Dictionary = live_map.values()[0] if not live_map.is_empty() else {}
	var simulation: Dictionary = live.get("simulation", {}) if typeof(live.get("simulation", {})) == TYPE_DICTIONARY else {}
	CoinPusherLiveSessionScript.advance(live, 1000)
	if int(live.get("applied_item_tolerance_modifier", 0)) <= 0 or int(live.get("shim_uses_remaining", 0)) <= 0:
		failures.append("Coin Pusher V3 Mags dampener/base shim did not initialize against production state.")
		return
	var suspicion_before_stop := run_state.suspicion_level()
	var tell_before_stop := int(live.get("tell_rung", 0))
	game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, run_state, environment)
	if run_state.suspicion_level() != suspicion_before_stop or int(live.get("tell_rung", 0)) != tell_before_stop or not bool(simulation.get("skill_stop_engaged", false)):
		failures.append("Coin Pusher V3 SKILL STOP entered heat/tell logic or failed to stop production motor.")
		return
	game.surface_action_command("coin_pusher_skill_stop", 0, false, {}, run_state, environment)
	# Start one point above the first authored tell threshold so the real tap
	# crosses into rung one. A fresh generated cabinet is intentionally too
	# tolerant for one light nudge to produce a tell at all.
	var effective_tolerance := maxi(1, int(live.get("base_alarm_tolerance", 1)) + int(live.get("tolerance_modifier", 0)))
	live["alarm_tolerance_remaining"] = maxi(2, (effective_tolerance * 2) / 3) + 1
	var trace_before_nudge := ((live.get("live_session", {}) as Dictionary).get("input_trace", []) as Array).size()
	var nudge_result := game.resolve_with_context("nudge_machine", 0, run_state, environment, _pusher_v3_rng("PUSHER-V3-ITEMS-NUDGE"), {"coin_pusher_force": "tap", "coin_pusher_direction": "right"})
	var trace: Array = (live.get("live_session", {}) as Dictionary).get("input_trace", []) if typeof((live.get("live_session", {}) as Dictionary).get("input_trace", [])) == TYPE_ARRAY else []
	var nudge_input: Dictionary = trace.back() if trace.size() > trace_before_nudge and typeof(trace.back()) == TYPE_DICTIONARY else {}
	if int(nudge_input.get("x", 0)) <= 1200 or str(nudge_input.get("kind", "")) != "nudge":
		failures.append("Coin Pusher V3 weighted keyring did not strengthen the production all-body nudge input: %s." % JSON.stringify(nudge_input))
		return
	GameModule.apply_result(run_state, nudge_result)
	var body_before := {}
	for body_value in simulation.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY:
			body_before[str((body_value as Dictionary).get("id", ""))] = [int((body_value as Dictionary).get("x", 0)), int((body_value as Dictionary).get("vx", 0))]
	var advanced := CoinPusherLiveSessionScript.advance(live, 1017)
	var untouched := 0
	for body_value in simulation.get("bodies", []):
		if typeof(body_value) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = body_value
		var before: Array = body_before.get(str(body.get("id", "")), [])
		if before.size() == 2 and int(body.get("x", 0)) == int(before[0]) and int(body.get("vx", 0)) == int(before[1]):
			untouched += 1
	if int(advanced.get("ticks", 0)) <= 0 or untouched > 0:
		failures.append("Coin Pusher V3 production nudge failed the all-body impulse contract: untouched=%d ticks=%d." % [untouched, int(advanced.get("ticks", 0))])
		return
	var tell_after_nudge := int(live.get("tell_rung", 0))
	game.call("_advance_tell_decay", live, 599)
	var tell_at_599 := int(live.get("tell_rung", 0))
	game.call("_advance_tell_decay", live, 1)
	if tell_after_nudge <= 0 or tell_at_599 != tell_after_nudge or int(live.get("tell_rung", 0)) != tell_after_nudge - 1:
		failures.append("Coin Pusher V3 tell ladder did not decay on the exact 600-tick boundary.")
		return
	var active_item := game.active_item_command("cold_quarters", run_state, environment, _pusher_v3_rng("PUSHER-V3-COLD-ARM"))
	if not bool(active_item.get("handled", false)):
		failures.append("Coin Pusher V3 cold quarters did not arm through production item routing.")
		return
	GameModule.apply_result(run_state, active_item.get("result", {}))
	var next_id := int(simulation.get("next_body_id", 1))
	var drop_result := game.resolve_with_context("drop_quarter", 1, run_state, environment, _pusher_v3_rng("PUSHER-V3-COLD-DROP"), {})
	GameModule.apply_result(run_state, drop_result)
	CoinPusherLiveSessionScript.advance(live, 1034)
	var cold_body := _pusher_v3_body(simulation, "body_%05d" % next_id)
	if int(cold_body.get("mass", 0)) != 3000:
		failures.append("Coin Pusher V3 cold quarters did not create the same physical drop at density/mass 3: %s." % JSON.stringify(cold_body))
		return
	var shim_before := int(live.get("shim_uses_remaining", 0))
	var gutter_coin := CoinPusherSolverScript.add_coin(simulation, _pusher_v3_rng("PUSHER-V3-SHIM-DROP"), 50000, 1, {"shim_contract": true})
	var gutter_body_id := str(gutter_coin.get("id", ""))
	var gutter_body_mass := int(gutter_coin.get("mass", 0))
	# Put the body beyond the physical tray lip in the left gutter mouth. A
	# lateral-only teleport is collision-corrected back inside before terminal
	# classification and therefore is not a gutter event.
	gutter_coin["x"] = 0
	gutter_coin["y"] = 0
	gutter_coin["sleeping"] = false
	var trace_before_shim := ((live.get("live_session", {}) as Dictionary).get("input_trace", []) as Array).size()
	var gutter_step := _pusher_v3_step_until_bodies_exit(simulation, [gutter_body_id], 60, true)
	var shim_outcome: Dictionary = game.call("_consume_physics_events", run_state, live, gutter_step.get("events", []), _pusher_v3_rng("PUSHER-V3-SHIM-CONSUME"))
	var returned_coin := _pusher_v3_body(simulation, gutter_body_id)
	var machine_geometry: Dictionary = ((simulation.get("machine_definition", {}) as Dictionary).get("geometry", {}) as Dictionary)
	var expected_return_x := int(machine_geometry.get("gutter_x", CoinPusherSolverScript.GUTTER_X)) + int(returned_coin.get("radius", CoinPusherSolverScript.COIN_RADIUS)) + 100
	var expected_return_y := int(machine_geometry.get("tray_lip_y", CoinPusherSolverScript.TRAY_LIP_Y)) + int(returned_coin.get("radius", CoinPusherSolverScript.COIN_RADIUS)) + 1200
	var trace_after_shim: Array = (live.get("live_session", {}) as Dictionary).get("input_trace", []) if typeof((live.get("live_session", {}) as Dictionary).get("input_trace", [])) == TYPE_ARRAY else []
	var return_input: Dictionary = trace_after_shim.back() if trace_after_shim.size() == trace_before_shim + 1 and typeof(trace_after_shim.back()) == TYPE_DICTIONARY else {}
	var returned_provenance: Dictionary = ((returned_coin.get("meta", {}) as Dictionary).get("provenance", {}) as Dictionary) if typeof((returned_coin.get("meta", {}) as Dictionary).get("provenance", {})) == TYPE_DICTIONARY else {}
	if not bool(shim_outcome.get("shim_recovered", false)) or returned_coin.is_empty() \
			or int(live.get("shim_uses_remaining", 0)) != shim_before - 1 \
			or int(returned_coin.get("mass", 0)) != gutter_body_mass \
			or not bool(returned_provenance.get("shim_contract", false)) \
			or int(returned_coin.get("x", -1)) != expected_return_x or int(returned_coin.get("y", -1)) != expected_return_y \
			or not (simulation.get("gutter_ledger", []) as Array).is_empty() \
			or str(return_input.get("kind", "")) != "gutter_return" or str(return_input.get("body_id", "")) != gutter_body_id:
		failures.append("Coin Pusher V3 shim did not preserve ID/provenance/mass, reenter at the gutter mouth, queue replay, and consume exactly one use: outcome=%s body=%s trace=%s." % [JSON.stringify(shim_outcome), JSON.stringify(returned_coin), JSON.stringify(return_input)])
		return
	# Isolate the rumor fixture from any legitimate tray outcomes produced by the
	# preceding live drop. Collection preserves the conservation ledger.
	CoinPusherSolverScript.collect_tray(simulation)
	(simulation.get("tray_ledger", []) as Array).append({"body_id": "rumor_tray", "kind": "coin", "value": 1, "item_id": "", "provenance": {}})
	simulation["external_origin_count"] = int(simulation.get("external_origin_count", 0)) + 1
	game.call("_register_pile_rumor", run_state, environment, live)
	if run_state.rumor_facts("pusher_tray_loaded").is_empty():
		failures.append("Coin Pusher V3 loaded tray did not register the town rumor fact class.")
		return
	(simulation.get("tray_ledger", []) as Array).clear()
	simulation["external_origin_count"] = int(simulation.get("external_origin_count", 0)) - 1
	game.call("_register_pile_rumor", run_state, environment, live)
	if not run_state.rumor_facts("pusher_tray_loaded").is_empty() or run_state.rumor_facts("pusher_pile").is_empty():
		failures.append("Coin Pusher V3 tray rumor did not truth-refresh/clear when the physical tray emptied.")
		return
	live["alarm_tolerance_remaining"] = 1
	var bankroll_before_alarm := run_state.bankroll
	var suspicion_before_alarm := run_state.suspicion_level()
	run_state.set_environment(environment)
	var alarm_result := game.resolve_with_context("nudge_machine", 0, run_state, environment, _pusher_v3_rng("PUSHER-V3-ALARM"), {"coin_pusher_force": "slam", "coin_pusher_direction": "front"})
	GameModule.apply_result(run_state, alarm_result)
	run_state.record_reputation_from_result(alarm_result, alarm_result.get("deltas", {}))
	if not bool(live.get("locked_down", false)) or str(alarm_result.get("surface_audio_cue", "")) != "coin_pusher_alarm" or (game.get("_live_machines") as Dictionary).is_empty():
		failures.append("Coin Pusher V3 hard alarm ejected the player or failed to night-lock/audio-signal in place.")
		return
	CoinPusherSolverScript.step_ticks(simulation, {"motor_enabled": false}, 24)
	var locked_surface := game.surface_state(run_state, environment)
	var locked_bindings: Dictionary = locked_surface.get("surface_action_bindings", {}) if typeof(locked_surface.get("surface_action_bindings", {})) == TYPE_DICTIONARY else {}
	var refused := game.surface_action_command("coin_pusher_drop", 0, false, {}, run_state, environment)
	if int(simulation.get("motor_rate_fp", -1)) != 0 or not bool(locked_surface.get("coin_pusher_locked", false)) \
			or bool((locked_bindings.get("coin_pusher_drop", {}) as Dictionary).get("enabled", true)) \
			or bool(refused.get("direct_resolve", false)) or run_state.bankroll != bankroll_before_alarm \
			or run_state.suspicion_level() <= suspicion_before_alarm or not bool(live.get("staff_watch_memory", false)) \
			or int(live.get("suspicion_floor", 0)) <= 0 or run_state.reputation_value(reputation_node, "alarm_tripped") <= 0.0:
		failures.append("Coin Pusher V3 hard alarm did not stop/darken/refuse without charge while applying heat, watch memory, and reputation: motor=%d locked=%s drop_enabled=%s direct=%s bankroll=%d/%d suspicion=%d/%d watch=%s floor=%d reputation=%.3f." % [int(simulation.get("motor_rate_fp", -1)), bool(locked_surface.get("coin_pusher_locked", false)), bool((locked_bindings.get("coin_pusher_drop", {}) as Dictionary).get("enabled", true)), bool(refused.get("direct_resolve", false)), run_state.bankroll, bankroll_before_alarm, run_state.suspicion_level(), suspicion_before_alarm, bool(live.get("staff_watch_memory", false)), int(live.get("suspicion_floor", 0)), run_state.reputation_value(reputation_node, "alarm_tripped")])
		return
	run_state.advance_game_clock_minutes(24 * 60)
	(game.get("_live_machines") as Dictionary).clear()
	game.enter(run_state, environment)
	var next_night_live_map: Dictionary = game.get("_live_machines")
	var next_night_live: Dictionary = next_night_live_map.values()[0] if not next_night_live_map.is_empty() else {}
	if bool(next_night_live.get("locked_down", true)) or not bool(next_night_live.get("staff_watch_memory", false)):
		failures.append("Coin Pusher V3 cabinet did not unlock on the new night while retaining staff-watch memory.")
		return
	var plain_run := RunState.new()
	plain_run.start_new("PUSHER-V3-MAGS-COMPARISON", RunState.standard_challenge("PUSHER-V3-MAGS-COMPARISON"))
	var mags_run := RunState.new()
	mags_run.start_new("PUSHER-V3-MAGS-COMPARISON", RunState.standard_challenge("PUSHER-V3-MAGS-COMPARISON"))
	mags_run.add_item("mags_nudge_dampener")
	var compare_environment := {"id": "pusher_mags_compare", "world_node_id": "pusher_mags_compare", "scenario_game_modifiers": {"coin_pusher": {"variation_id": "jackpot_ridge"}}, "game_states": {}}
	var plain_machine: Dictionary = game.generate_environment_state(plain_run, compare_environment, _pusher_v3_rng("PUSHER-V3-MAGS-COMPARE"))
	var mags_machine: Dictionary = game.generate_environment_state(mags_run, compare_environment, _pusher_v3_rng("PUSHER-V3-MAGS-COMPARE"))
	if int(mags_machine.get("alarm_tolerance_remaining", 0)) <= int(plain_machine.get("alarm_tolerance_remaining", 0)) \
			or int(mags_machine.get("applied_item_tolerance_modifier", 0)) <= int(plain_machine.get("applied_item_tolerance_modifier", 0)):
		failures.append("Mags' dampener did not comparatively increase production nudge tolerance.")


func _check_pusher_v3_generated_rider_production(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("coin_pusher")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Coin Pusher V3 production rider test could not load the game module.")
		return
	var game: GameModule = module_script.new()
	game.setup(definition, library)
	var run_state := RunState.new()
	run_state.start_new("PUSHER-V3-RIDER-PRODUCTION", RunState.standard_challenge("PUSHER-V3-RIDER-PRODUCTION"))
	var environment := {"id": "pusher_v3_rider_fixture", "scenario_game_modifiers": {"coin_pusher": {"variation_id": "quarter_falls", "prize_item_ids": ["coffee"]}}, "game_states": {}}
	var generated: Dictionary = {}
	var selected_rider: Dictionary = {}
	for seed_index in range(1, 129):
		var generation_rng := _pusher_v3_rng("PUSHER-V3-RIDER-%03d" % seed_index)
		generated = game.call("_generate_machine_state", run_state, environment, generation_rng)
		for rider_value in generated.get("riders", []):
			if typeof(rider_value) == TYPE_DICTIONARY and not str((rider_value as Dictionary).get("item_id", "")).is_empty():
				selected_rider = rider_value
				break
		if not selected_rider.is_empty():
			break
	if selected_rider.is_empty():
		failures.append("Coin Pusher V3 could not generate a production Quarter Falls item rider in the deterministic seed sweep.")
		return
	var generated_snapshot: Dictionary = generated.get("settled_state", {}) if typeof(generated.get("settled_state", {})) == TYPE_DICTIONARY else {}
	var generated_rider_body_id := str(selected_rider.get("body_id", ""))
	if generated_rider_body_id.is_empty() or generated.has("simulation") or generated.has("live_session") \
			or _pusher_v3_body(CoinPusherLiveSessionScript.restore_snapshot(generated_snapshot, game.call("_machine_definition")), generated_rider_body_id).is_empty():
		failures.append("Coin Pusher V3 generation did not compactly persist stable rider-to-body annotations.")
		return
	environment["game_states"] = {"coin_pusher": generated}
	var activation_before := JSON.stringify(environment, "", true)
	game.enter(run_state, environment)
	if JSON.stringify(environment, "", true) != activation_before:
		failures.append("Coin Pusher V3 rider-bearing machine mutated durable state during passive activation.")
	var live_machines: Dictionary = game.get("_live_machines")
	generated = live_machines.values()[0] if not live_machines.is_empty() else {}
	for rider_value in generated.get("riders", []):
		if typeof(rider_value) == TYPE_DICTIONARY and str((rider_value as Dictionary).get("id", "")) == str(selected_rider.get("id", "")):
			selected_rider = rider_value
			break
	var simulation: Dictionary = generated.get("simulation", {})
	var rider_body := _pusher_v3_body(simulation, str(selected_rider.get("body_id", "")))
	if rider_body.is_empty() or str(rider_body.get("kind", "")) != "rider":
		failures.append("Coin Pusher V3 generated a rider ledger record without its physical solver body.")
		return
	rider_body["x"] = CoinPusherSolverScript.WIDTH / 2
	rider_body["y"] = 0
	rider_body["z"] = 0
	var exit_result := _pusher_v3_step_until_bodies_exit(simulation, [str(selected_rider.get("body_id", ""))], 60, false)
	game.call("_consume_physics_events", run_state, generated, exit_result.get("events", []), _pusher_v3_rng("PUSHER-V3-RIDER-EXIT"))
	var snapshot := CoinPusherLiveSessionScript.make_snapshot(simulation, generated)
	var restored := CoinPusherLiveSessionScript.restore_snapshot(snapshot, game.call("_machine_definition"))
	generated["simulation"] = restored
	generated["live_session"] = {}
	var tray_before: Array = restored.get("tray_ledger", [])
	var item_id := str(selected_rider.get("item_id", ""))
	var tray_has_item := false
	for entry_value in tray_before:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("item_id", "")) == item_id:
			tray_has_item = true
	game.call("_collect_surface_command", run_state, environment, generated)
	if not tray_has_item or not run_state.inventory.has(item_id) or not (restored.get("tray_ledger", []) as Array).is_empty():
		failures.append("Coin Pusher V3 generated rider did not fall, persist in tray, and collect into inventory through production seams.")


func _check_pusher_v3_solver_performance(machine: Dictionary, failures: Array) -> void:
	if not CoinPusherSolverScript.native_backend_available_for_test():
		failures.append("Coin Pusher V3 native solver backend is unavailable for the 300-body frame-headroom contract.")
		return
	var rng := _pusher_v3_rng("PUSHER-V3-PERF")
	var state: Dictionary = CoinPusherSolverScript.create_machine(rng, machine, 300)
	var bodies: Array = state.get("bodies", [])
	for index in range(mini(80, bodies.size())):
		var body: Dictionary = bodies[index]
		body["sleeping"] = false
		body["sleep_ticks"] = 0
		body["vx"] = rng.randi_range(-1600, 1600)
		body["vy"] = rng.randi_range(-1800, 900)
	var samples := PackedInt32Array()
	for _tick in range(PUSHER_V3_PERF_TICKS):
		var started := Time.get_ticks_usec()
		CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 1)
		samples.append(Time.get_ticks_usec() - started)
	if CoinPusherSolverScript.last_step_backend_for_test() != "native_v3":
		failures.append("Coin Pusher V3 300-body performance fixture did not execute on the native V3 backend.")
	samples.sort()
	var p95 := samples[mini(samples.size() - 1, int(ceil(float(samples.size()) * 0.95)) - 1)]
	print("Coin Pusher V3 300-body solver tick p95: %d usec (native_v3, %d samples)." % [p95, samples.size()])
	if p95 > 12000:
		failures.append("Coin Pusher V3 300-body solver tick p95 leaves insufficient renderer headroom: %d usec." % p95)


func _pusher_v3_state(machine: Dictionary, seed: String) -> Dictionary:
	return CoinPusherSolverScript.create_machine(_pusher_v3_rng(seed), machine, 0)


func _pusher_v3_rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_pusher_v3_hash(seed))
	return rng


func _pusher_v3_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value


func _pusher_v3_hold_phase(state: Dictionary, machine: Dictionary, phase: int) -> void:
	state["phase_fp"] = phase * 1000
	state["motor_rate_fp"] = 0
	state["motor_target_rate_fp"] = 0
	state["skill_stop_engaged"] = true
	state["face_y"] = CoinPusherSolverScript.face_y_for_phase(machine, phase)
	state["previous_face_y"] = state["face_y"]


func _pusher_v3_body_fixture(id: String, x: int, y: int, z: int, sleeping: bool, support: String) -> Dictionary:
	return {
		"id": id,
		"kind": "coin",
		"x": x, "y": y, "z": z,
		"vx": 0, "vy": 0, "vz": 0,
		"radius": 4300, "height": 1700, "mass": 1000,
		"sleeping": sleeping, "sleep_ticks": 8 if sleeping else 0,
		"rest_state": "resting" if sleeping else "falling",
		"support_kind": support, "carried_sleep": sleeping and support == "platform",
		"support_ids": [], "exit_state": "", "exit_start_tick": -1,
		"meta": {"value": 1},
	}


func _pusher_v3_step_until_bodies_exit(state: Dictionary, body_ids: Array, max_ticks: int = 60, reference_only: bool = true) -> Dictionary:
	var all_events: Array = []
	var ticks := 0
	while ticks < max_ticks:
		var all_gone := true
		for body_id in body_ids:
			if not _pusher_v3_body(state, str(body_id)).is_empty():
				all_gone = false
				break
		if all_gone:
			break
		var result: Dictionary
		if reference_only:
			result = CoinPusherSolverScript.step_ticks_reference_for_test(state, {"motor_enabled": false}, 1)
		else:
			result = CoinPusherSolverScript.step_ticks(state, {"motor_enabled": false}, 1)
		all_events.append_array(result.get("events", []))
		ticks += 1
	return {"events": all_events, "ticks": ticks}


func _pusher_v3_body(state: Dictionary, id: String) -> Dictionary:
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		if str(body.get("id", "")) == id:
			return body
	return {}


func _check_pusher_v3_impact_measurements(result: Dictionary, body_id: String, expected_support: String, failures: Array) -> void:
	var impact := {}
	for event_value in result.get("events", []):
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "impact" and str(event.get("body_id", "")) == body_id:
			impact = event
			break
	if impact.is_empty():
		failures.append("Coin Pusher V3 did not emit a physical impact event for the %s landing fixture." % expected_support)
		return
	if str(impact.get("support", "")) != expected_support \
			or not impact.has("fall_height") \
			or not impact.has("impact_speed") \
			or not ["soft", "hard"].has(str(impact.get("impact_class", ""))) \
			or not impact.has("stack_depth") \
			or int(impact.get("fall_height", 0)) <= 0 \
			or int(impact.get("impact_speed", 0)) <= 0 \
			or int(impact.get("stack_depth", -1)) < 0:
		failures.append("Coin Pusher V3 %s impact omitted valid height/speed/class/stack evidence: %s" % [expected_support, JSON.stringify(impact)])


func _check_pusher_v3_real_weight_gravity(machine: Dictionary, failures: Array) -> void:
	var gravity_machine := machine.duplicate(true)
	var apparatus: Dictionary = gravity_machine.get("apparatus", {}) if typeof(gravity_machine.get("apparatus", {})) == TYPE_DICTIONARY else {}
	apparatus["pegs"] = []
	gravity_machine["apparatus"] = apparatus
	var reference := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-WEIGHT"), gravity_machine, 0)
	_pusher_v3_hold_phase(reference, gravity_machine, 120)
	var inserted: Dictionary = CoinPusherSolverScript.add_coin(reference, _pusher_v3_rng("PUSHER-V3-WEIGHT-DROP"), CoinPusherSolverScript.WIDTH / 2, 1)
	var body_id := str(inserted.get("id", ""))
	var production := reference.duplicate(true)
	var landing_tick := -1
	var landing_event := {}
	for tick in range(1, 61):
		var reference_result := CoinPusherSolverScript.step_ticks_reference_for_test(reference, {"motor_enabled": false}, 1)
		var production_result := CoinPusherSolverScript.step_ticks(production, {"motor_enabled": false}, 1)
		if JSON.stringify(reference_result.get("events", [])) != JSON.stringify(production_result.get("events", [])) or JSON.stringify(CoinPusherSolverScript.body_views(reference)) != JSON.stringify(CoinPusherSolverScript.body_views(production)):
			failures.append("Coin Pusher V3 real-weight fall diverged between reference and native production backends at tick %d." % tick)
			return
		for event_value in production_result.get("events", []):
			var event: Dictionary = event_value
			if str(event.get("kind", "")) == "impact" and str(event.get("body_id", "")) == body_id:
				landing_tick = tick
				landing_event = event
				break
		if landing_tick >= 0:
			break
	if landing_tick < 24 or landing_tick > 60 or int(landing_event.get("impact_speed", 0)) < 40000 or str(landing_event.get("impact_class", "")) != "hard" or int(landing_event.get("fall_height", 0)) < 18000:
		failures.append("Coin Pusher V3 insert did not produce a fast, weighty physical landing: tick=%d event=%s." % [landing_tick, JSON.stringify(landing_event)])
		return
	# The authored landing scatter gets a few frames to skid and thud to rest;
	# it must settle quickly, but not be erased on the impact frame.
	CoinPusherSolverScript.step_ticks(production, {"motor_enabled": false}, 18)
	var landed_body := _pusher_v3_body(production, body_id)
	if landed_body.is_empty() or not bool(landed_body.get("sleeping", false)) or str(landed_body.get("rest_state", "")) != "resting":
		failures.append("Coin Pusher V3 hard landing did not settle without floaty post-impact chatter: %s." % JSON.stringify(landed_body))


func _check_pusher_v3_irregular_supported_piles(machine: Dictionary, failures: Array) -> void:
	var scatter_state := _pusher_v3_state(machine, "PUSHER-V3-LANDING-SCATTER")
	_pusher_v3_hold_phase(scatter_state, machine, 0)
	var scatter_bodies: Array = scatter_state.get("bodies", [])
	for index in range(8):
		var landing := _pusher_v3_body_fixture("body_%05d" % (index + 1), 8000 + index * 12000, 18000, 100, false, "")
		landing["vz"] = -15000
		landing["fall_start_z"] = 9000
		landing["meta"] = {"value": 1, "inserted": true}
		scatter_bodies.append(landing)
	scatter_state["opening_body_count"] = scatter_bodies.size()
	var scatter_step := CoinPusherSolverScript.step_ticks_reference_for_test(scatter_state, {"motor_enabled": false}, 1)
	var scatter_vectors: Array[String] = []
	var scatter_sum := Vector2i.ZERO
	for event_value in scatter_step.get("events", []):
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "impact":
			continue
		var scatter := Vector2i(int(event.get("landing_scatter_x", 0)), int(event.get("landing_scatter_y", 0)))
		scatter_vectors.append("%d:%d" % [scatter.x, scatter.y])
		scatter_sum += scatter
	var unique_scatter := {}
	for vector_key in scatter_vectors:
		unique_scatter[vector_key] = true
	if scatter_vectors.size() != 8 or unique_scatter.size() != 8 or scatter_sum != Vector2i.ZERO:
		failures.append("Coin Pusher V3 repeated same-location landings did not receive bounded, balanced directional variance: vectors=%s sum=%s." % [JSON.stringify(scatter_vectors), scatter_sum])

	# A body-supported column rooted on the moving platform must inherit the
	# platform displacement even when its upper coin is awake from a small hit.
	var carry_state := _pusher_v3_state(machine, "PUSHER-V3-STACK-CARRY")
	var phase := 60
	carry_state["phase_fp"] = phase * 1000
	carry_state["motor_rate_fp"] = 1000
	carry_state["motor_target_rate_fp"] = 1000
	carry_state["motor_run_rate_fp"] = 1000
	carry_state["skill_stop_engaged"] = false
	carry_state["face_y"] = CoinPusherSolverScript.face_y_for_phase(machine, phase)
	carry_state["previous_face_y"] = carry_state["face_y"]
	var stack_y := int(carry_state.get("face_y", 0)) + 9000
	var base := _pusher_v3_body_fixture("stack_base", 50000, stack_y, CoinPusherSolverScript.PLATFORM_TOP_Z, true, "platform")
	var middle := _pusher_v3_body_fixture("stack_middle", 50000, stack_y, CoinPusherSolverScript.PLATFORM_TOP_Z + CoinPusherSolverScript.COIN_HEIGHT, true, "body")
	var top := _pusher_v3_body_fixture("stack_top", 50000, stack_y, CoinPusherSolverScript.PLATFORM_TOP_Z + CoinPusherSolverScript.COIN_HEIGHT * 2, false, "body")
	for stack_body in [base, middle, top]:
		stack_body["radius"] = CoinPusherSolverScript.COIN_RADIUS
		stack_body["height"] = CoinPusherSolverScript.COIN_HEIGHT
	middle["carried_sleep"] = true
	middle["support_ids"] = ["stack_base"]
	top["rest_state"] = "resting"
	top["carried_sleep"] = true
	top["support_ids"] = ["stack_middle"]
	top["vx"] = 60
	(carry_state.get("bodies", []) as Array).append_array([base, middle, top])
	carry_state["opening_body_count"] = 3
	var before_y := stack_y
	CoinPusherSolverScript.step_ticks_reference_for_test(carry_state, {"motor_enabled": true}, 1)
	var moved_base := _pusher_v3_body(carry_state, "stack_base")
	var moved_middle := _pusher_v3_body(carry_state, "stack_middle")
	var moved_top := _pusher_v3_body(carry_state, "stack_top")
	var base_delta := int(moved_base.get("y", before_y)) - before_y
	if base_delta == 0 or absi((int(moved_middle.get("y", before_y)) - before_y) - base_delta) > 50 or absi((int(moved_top.get("y", before_y)) - before_y) - base_delta) > 50 or not bool(moved_middle.get("carried_sleep", false)) or not bool(moved_top.get("carried_sleep", false)) or str(moved_top.get("support_kind", "")) != "body" or absi(int(moved_top.get("x", 50000)) - 50000) > 100:
		failures.append("Coin Pusher V3 platform-rooted pile did not remain supported and move as a restrained physical stack: base=%s middle=%s top=%s." % [JSON.stringify(moved_base), JSON.stringify(moved_middle), JSON.stringify(moved_top)])


func _check_pusher_v3_contact_only_pressure(machine: Dictionary, failures: Array) -> void:
	var gap_state := _pusher_v3_state(machine, "PUSHER-V3-CONTACT-GAP")
	_pusher_v3_hold_phase(gap_state, machine, 0)
	var driver := _pusher_v3_body_fixture("gap_driver", 30000, 18000, 0, false, "deck")
	driver["rest_state"] = "resting"
	driver["vx"] = 6000
	var separated := _pusher_v3_body_fixture("gap_target", 39600, 18000, 0, true, "deck")
	(gap_state.get("bodies", []) as Array).append_array([driver, separated])
	gap_state["opening_body_count"] = 2
	CoinPusherSolverScript.step_ticks_reference_for_test(gap_state, {"motor_enabled": false}, 1)
	var untouched := _pusher_v3_body(gap_state, "gap_target")
	if int(untouched.get("x", -1)) != 39600 or int(untouched.get("vx", -1)) != 0 or not bool(untouched.get("sleeping", false)):
		failures.append("Coin Pusher V3 transmitted pressure across a visible air gap: %s." % JSON.stringify(untouched))

	var chain_state := _pusher_v3_state(machine, "PUSHER-V3-CONTACT-CHAIN")
	_pusher_v3_hold_phase(chain_state, machine, 0)
	var chain_a := _pusher_v3_body_fixture("chain_a", 30000, 18000, 0, false, "deck")
	chain_a["rest_state"] = "resting"
	chain_a["vx"] = 6000
	var chain_b := _pusher_v3_body_fixture("chain_b", 38550, 18000, 0, true, "deck")
	var chain_c := _pusher_v3_body_fixture("chain_c", 47100, 18000, 0, true, "deck")
	var other_row := _pusher_v3_body_fixture("other_row", 38550, 29000, 0, true, "deck")
	(chain_state.get("bodies", []) as Array).append_array([chain_a, chain_b, chain_c, other_row])
	chain_state["opening_body_count"] = 4
	var native_chain := chain_state.duplicate(true)
	CoinPusherSolverScript.step_ticks_reference_for_test(chain_state, {"motor_enabled": false}, 1)
	CoinPusherSolverScript.step_ticks(native_chain, {"motor_enabled": false}, 1)
	var moved_b := _pusher_v3_body(chain_state, "chain_b")
	var moved_c := _pusher_v3_body(chain_state, "chain_c")
	var still_other := _pusher_v3_body(chain_state, "other_row")
	if int(moved_b.get("x", 38550)) <= 38550 or int(moved_c.get("x", 47100)) <= 47100 or int(still_other.get("x", -1)) != 38550 or not bool(still_other.get("sleeping", false)):
		failures.append("Coin Pusher V3 contact chain did not propagate locally through touching coins only: b=%s c=%s other=%s." % [JSON.stringify(moved_b), JSON.stringify(moved_c), JSON.stringify(still_other)])
	if JSON.stringify(CoinPusherSolverScript.canonical_digest(chain_state), "", true) != JSON.stringify(CoinPusherSolverScript.canonical_digest(native_chain), "", true):
		failures.append("Coin Pusher V3 native contact-only pressure diverged from the integer reference kernel.")


func _check_pusher_v3_visible_terminal_falls(machine: Dictionary, failures: Array) -> void:
	var initial := _pusher_v3_state(machine, "PUSHER-V3-VISIBLE-EXIT")
	_pusher_v3_hold_phase(initial, machine, 0)
	var falling_coin := _pusher_v3_body_fixture("visible_tray_coin", 50000, 6250, 0, false, "deck")
	falling_coin["radius"] = CoinPusherSolverScript.COIN_RADIUS
	falling_coin["height"] = CoinPusherSolverScript.COIN_HEIGHT
	falling_coin["rest_state"] = "resting"
	(initial.get("bodies", []) as Array).append(falling_coin)
	initial["opening_body_count"] = 1
	var reference := initial.duplicate(true)
	var native := initial.duplicate(true)
	var first_reference := CoinPusherSolverScript.step_ticks_reference_for_test(reference, {"motor_enabled": false}, 1)
	var first_native := CoinPusherSolverScript.step_ticks(native, {"motor_enabled": false}, 1)
	var active_fall := _pusher_v3_body(reference, "visible_tray_coin")
	if str(active_fall.get("exit_state", "")) != "tray_fall" or str(active_fall.get("rest_state", "")) != "terminal_fall" or not (reference.get("tray_ledger", []) as Array).is_empty() or not _pusher_v3_has_event(first_reference.get("events", []), "tray_fall_start", "visible_tray_coin"):
		failures.append("Coin Pusher V3 tray crossing did not begin a visible, still-active terminal fall: body=%s events=%s." % [JSON.stringify(active_fall), JSON.stringify(first_reference.get("events", []))])
		return
	if JSON.stringify(first_reference.get("events", [])) != JSON.stringify(first_native.get("events", [])):
		failures.append("Coin Pusher V3 native visible-fall start event diverged from the reference kernel.")
	for _tick in range(12):
		CoinPusherSolverScript.step_ticks_reference_for_test(reference, {"motor_enabled": false}, 1)
		CoinPusherSolverScript.step_ticks(native, {"motor_enabled": false}, 1)
	active_fall = _pusher_v3_body(reference, "visible_tray_coin")
	if active_fall.is_empty() or int(active_fall.get("z", 0)) >= 0 or not (reference.get("tray_ledger", []) as Array).is_empty():
		failures.append("Coin Pusher V3 terminal coin did not remain visible below the shelf before tray landing: %s." % JSON.stringify(active_fall))
	var reference_exit := _pusher_v3_step_until_bodies_exit(reference, ["visible_tray_coin"], 60, true)
	var native_exit := _pusher_v3_step_until_bodies_exit(native, ["visible_tray_coin"], 60, false)
	var tray_events: Array = first_reference.get("events", []).duplicate()
	tray_events.append_array(reference_exit.get("events", []))
	if (reference.get("tray_ledger", []) as Array).size() != 1 or not _pusher_v3_has_event(tray_events, "tray", "visible_tray_coin") or int(reference_exit.get("ticks", 0)) < 6 or not _pusher_v3_body(reference, "visible_tray_coin").is_empty():
		failures.append("Coin Pusher V3 visible fall did not finish in the collectible tray after a readable descent: state=%s events=%s." % [JSON.stringify(CoinPusherSolverScript.canonical_digest(reference)), JSON.stringify(tray_events)])
	if JSON.stringify(CoinPusherSolverScript.canonical_digest(reference), "", true) != JSON.stringify(CoinPusherSolverScript.canonical_digest(native), "", true) or JSON.stringify(reference_exit.get("events", [])) != JSON.stringify(native_exit.get("events", [])):
		failures.append("Coin Pusher V3 native visible terminal fall diverged from the reference lifecycle.")


func _pusher_v3_has_event(events: Array, kind: String, body_id: String) -> bool:
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == kind and str((event_value as Dictionary).get("body_id", "")) == body_id:
			return true
	return false


func _pusher_v3_skill_stop_release_displacement(machine: Dictionary, x_positions: Array, _drop_seeds: Array, seed: String) -> Dictionary:
	var state := _pusher_v3_state(machine, seed)
	_pusher_v3_hold_phase(state, machine, 120)
	var inserted_ids: Array[String] = []
	var bodies: Array = state.get("bodies", [])
	for index in range(x_positions.size()):
		var body_id := "bank_%d" % index
		bodies.append(_pusher_v3_body_fixture(body_id, int(x_positions[index]), 40000, 0, true, "deck"))
		inserted_ids.append(body_id)
	state["opening_body_count"] = bodies.size()
	var before_y := {}
	for body_id in inserted_ids:
		var body := _pusher_v3_body(state, body_id)
		if not body.is_empty() and not str(body.get("support_kind", "")).is_empty() and int(body.get("y", 0)) < int(state.get("face_y", 0)):
			before_y[body_id] = int(body.get("y", 0))
	CoinPusherSolverScript.set_skill_stop(state, false)
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": true}, 120)
	var displacement := 0
	var released_count := 0
	for body_id in inserted_ids:
		var body := _pusher_v3_body(state, body_id)
		if before_y.has(body_id) and not body.is_empty():
			released_count += 1
			displacement += maxi(0, int(before_y[body_id]) - int(body.get("y", before_y[body_id])))
	return {"displacement": displacement, "banked_count": before_y.size(), "released_count": released_count}


func _pusher_v3_min_y(state: Dictionary) -> int:
	var result := 1 << 30
	for body_value in state.get("bodies", []):
		result = mini(result, int((body_value as Dictionary).get("y", result)))
	return result


func _pusher_v3_axis_histogram(state: Dictionary) -> Dictionary:
	var bodies: Array = state.get("bodies", [])
	var samples := 0
	var axis := 0
	for index in range(bodies.size()):
		var body: Dictionary = bodies[index]
		var nearest_dx := 0
		var nearest_dy := 0
		var nearest_sq := 1 << 62
		for other_index in range(bodies.size()):
			if other_index == index:
				continue
			var other: Dictionary = bodies[other_index]
			if absi(int(other.get("z", 0)) - int(body.get("z", 0))) > 500:
				continue
			var dx := int(other.get("x", 0)) - int(body.get("x", 0))
			var dy := int(other.get("y", 0)) - int(body.get("y", 0))
			var distance_sq := dx * dx + dy * dy
			if distance_sq < nearest_sq:
				nearest_sq = distance_sq
				nearest_dx = dx
				nearest_dy = dy
		if nearest_sq == 1 << 62:
			continue
		var distance := maxi(1, int(sqrt(float(nearest_sq))))
		if absi(nearest_dx) * 1000 <= distance * 174 or absi(nearest_dy) * 1000 <= distance * 174:
			axis += 1
		samples += 1
	return {"sample_count": samples, "axis_ratio_milli": axis * 1000 / maxi(1, samples)}


func _check_pusher_v3_ridge_physical_contract(library: ContentLibrary, failures: Array) -> void:
	var game_definition := library.game("coin_pusher")
	var game: GameModule = load(str(game_definition.get("module_path", ""))).new()
	game.setup(game_definition, library)
	var definition: Dictionary = game.call("_machine_definition", "jackpot_ridge")
	var config: Dictionary = definition.get("sub_game", {}) if typeof(definition.get("sub_game", {})) == TYPE_DICTIONARY else {}
	var variation := JackpotRidgeVariationScript.initial_state(config, _pusher_v3_rng("RIDGE-PHYSICAL-STATE"), 3, 5)
	var simulation := _pusher_v3_state(definition, "RIDGE-PHYSICAL-SIM")
	var holes: Array = (definition.get("apparatus", {}) as Dictionary).get("holes", [])
	var board: Dictionary = (definition.get("apparatus", {}) as Dictionary).get("drop_board", {})
	variation["pucks"] = [{"id": "ridge_jam_contract", "kind": "dud", "jam_hole_index": 1}]
	var jam_body: Dictionary = CoinPusherSolverScript.add_feature(simulation, "puck", "ridge_jam_contract", int(holes[1]), int(board.get("y", 58000)), {"z": int((definition.get("geometry", {}) as Dictionary).get("platform_top_z", 3600)), "radius": 5200, "height": 2800, "mass": 3000, "kind": "dud", "jam_hole_index": 1})
	jam_body.merge({"support_kind": "platform", "rest_state": "resting", "sleeping": false}, true)
	var jam_body_id := str(jam_body.get("id", ""))
	if JackpotRidgeVariationScript.jammed_holes(variation, CoinPusherSolverScript.body_views(simulation), definition) != [1]:
		failures.append("Jackpot Ridge jam was not derived from the real dud body at the authored hole mouth.")
	# The production slam is a real all-body impulse and must move the same dud;
	# clearing is then proven through the authored motor/platform/back-plate path,
	# never by deleting or walking the puck in variation logic.
	var jam_x_before := int(jam_body.get("x", 0))
	CoinPusherSolverScript.apply_nudge(simulation, 4 * 1200, 0)
	CoinPusherSolverScript.step_ticks_reference_for_test(simulation, {"motor_enabled": false}, 1)
	var after_slam := _pusher_v3_body(simulation, jam_body_id)
	if after_slam.is_empty() or int(after_slam.get("x", jam_x_before)) == jam_x_before:
		failures.append("Jackpot Ridge production slam did not physically impulse the same jam dud.")
	var clear_events: Array = []
	CoinPusherSolverScript.set_motor_run_rate(simulation, CoinPusherSolverScript.FP)
	for _tick in range(240):
		var clear_step := CoinPusherSolverScript.step_ticks_reference_for_test(simulation, {"motor_enabled": true}, 1)
		clear_events.append_array(clear_step.get("events", []))
		if not JackpotRidgeVariationScript.jammed_holes(variation, CoinPusherSolverScript.body_views(simulation), definition).has(1):
			break
	if JackpotRidgeVariationScript.jammed_holes(variation, CoinPusherSolverScript.body_views(simulation), definition).has(1):
		failures.append("Jackpot Ridge authored machine did not physically push the same jam dud out of the mouth: %s" % JSON.stringify(_pusher_v3_body(simulation, jam_body_id)))
	var same_body_accounted := not _pusher_v3_body(simulation, jam_body_id).is_empty()
	for event_value in clear_events:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("body_id", "")) == jam_body_id and str((event_value as Dictionary).get("kind", "")) in ["tray", "gutter"]:
			same_body_accounted = true
	if not same_body_accounted:
		failures.append("Jackpot Ridge cleared a jam without retaining or physically terminal-accounting the same dud ID.")

	var lock_state := JackpotRidgeVariationScript.initial_state(config, _pusher_v3_rng("RIDGE-LOCK-STATE"), 3, 5)
	lock_state["armed_multipliers"] = [{"multiplier": 5, "remaining": 2}]
	lock_state["pucks"] = [{"id": "ridge_lock_contract", "kind": "lock"}]
	var lock_sim := _pusher_v3_state(definition, "RIDGE-LOCK-SIM")
	lock_sim["stroke_cycle_serial"] = 7
	lock_sim["phase_fp"] = 50000
	CoinPusherSolverScript.add_feature(lock_sim, "puck", "ridge_lock_contract", 50000, 5000, {"z": 0, "radius": 5200, "height": 2800, "mass": 3000, "kind": "lock"})
	var lock_events: Dictionary = _pusher_v3_step_until_bodies_exit(lock_sim, ["body_00001"], 60, true)
	var motor_before := [int(lock_sim.get("motor_rate_fp", 0)), int(lock_sim.get("face_y", 0))]
	JackpotRidgeVariationScript.apply_physical_events(lock_state, lock_events.get("events", []), config, 7)
	var event_phase := int(lock_sim.get("phase_fp", 0))
	var lock_start := 7 * 240 * 1000 + event_phase
	if int(lock_state.get("multiplier_lock_until_phase_units", -1)) != lock_start + 240 * 1000 or motor_before != [int(lock_sim.get("motor_rate_fp", 0)), int(lock_sim.get("face_y", 0))]:
		failures.append("Jackpot Ridge lock was not exactly one motor-phase stroke or steered the machine.")
	JackpotRidgeVariationScript.finish_drop(lock_state, 8, event_phase - 1, 240)
	if int((lock_state.get("armed_multipliers", [])[0] as Dictionary).get("remaining", 0)) != 2:
		failures.append("Jackpot Ridge lock expired before its exact stroke boundary.")
	JackpotRidgeVariationScript.finish_drop(lock_state, 8, event_phase, 240)
	if int((lock_state.get("armed_multipliers", [])[0] as Dictionary).get("remaining", 0)) != 1:
		failures.append("Jackpot Ridge lock survived beyond exactly one stroke.")

	var run_state := JackpotRidgeVariationScript.initial_state(config, _pusher_v3_rng("RIDGE-RUN-STATE"), 3, 5)
	run_state["pucks"] = []
	var run_sim := _pusher_v3_state(definition, "RIDGE-RUN-SIM")
	run_sim["stroke_cycle_serial"] = 4
	for index in range(3):
		var feature_id := "ridge_run_contract_%d" % index
		run_state["pucks"].append({"id": feature_id, "kind": "multiplier", "multiplier": 2, "charges": 2})
		CoinPusherSolverScript.add_feature(run_sim, "puck", feature_id, 36000 + index * 12000, 5000, {"z": 0, "radius": 5200, "height": 2800, "mass": 3000, "kind": "multiplier"})
	var run_events: Dictionary = _pusher_v3_step_until_bodies_exit(run_sim, ["body_00001", "body_00002", "body_00003"], 60, true)
	var run_outcome: Dictionary = JackpotRidgeVariationScript.apply_physical_events(run_state, run_events.get("events", []), config, 4)
	if not bool(run_outcome.get("ridge_run_triggered", false)) or int(run_state.get("ridge_run_count", 0)) != 1 or JackpotRidgeVariationScript.motor_rate_multiplier(run_state, config) != 2:
		failures.append("Jackpot Ridge Run did not arise once from three same-cycle physical banks at rate 2.")
	# The trigger cycle is not one of the three promised full bonus cycles. The
	# motor must remain doubled throughout cycles 5, 6, and 7, then return at 8.
	var boundary_remaining: Array = []
	for cycle in [5, 6, 7, 8]:
		boundary_remaining.append(JackpotRidgeVariationScript.advance_stroke_cycle(run_state, cycle))
	if boundary_remaining != [3, 2, 1, 0]:
		failures.append("Jackpot Ridge Run did not preserve three full post-trigger cycle boundaries: %s." % JSON.stringify(boundary_remaining))
	var split_state := JackpotRidgeVariationScript.initial_state(config, _pusher_v3_rng("RIDGE-RUN-SPLIT"), 3, 5)
	split_state["pucks"] = [
		{"id": "split_a", "kind": "multiplier", "multiplier": 2, "charges": 2},
		{"id": "split_b", "kind": "multiplier", "multiplier": 2, "charges": 2},
		{"id": "split_c", "kind": "multiplier", "multiplier": 2, "charges": 2},
	]
	var split_events := [
		{"body_kind": "puck", "outcome": "tray", "stroke_cycle": 4, "metadata": {"feature_id": "split_a"}},
		{"body_kind": "puck", "outcome": "tray", "stroke_cycle": 4, "metadata": {"feature_id": "split_b"}},
		{"body_kind": "puck", "outcome": "tray", "stroke_cycle": 5, "metadata": {"feature_id": "split_c"}},
	]
	var split_outcome := JackpotRidgeVariationScript.apply_physical_events(split_state, split_events, config, 5)
	if bool(split_outcome.get("ridge_run_triggered", false)) or int(split_state.get("ridge_run_count", 0)) != 0:
		failures.append("Jackpot Ridge Run incorrectly combined multiplier banks split across physical cycles.")

	# Production path: a real solver tray event snapshots the active multiplier
	# onto that same coin, and money moves only through the cabinet COLLECT action.
	var production_run := RunState.new()
	production_run.start_new("RIDGE-PRODUCTION-COLLECT", RunState.standard_challenge("RIDGE-PRODUCTION-COLLECT"))
	var production_environment := {"id": "ridge_production_collect", "world_node_id": "ridge_production_collect", "scenario_game_modifiers": {"coin_pusher": {"variation_id": "jackpot_ridge"}}, "game_states": {}}
	var production_machine: Dictionary = game.generate_environment_state(production_run, production_environment, _pusher_v3_rng("RIDGE-PRODUCTION-GENERATE"))
	production_environment["game_states"] = {"coin_pusher": production_machine}
	game.enter(production_run, production_environment)
	var production_live_map: Dictionary = game.get("_live_machines")
	var production_live: Dictionary = production_live_map.values()[0] if not production_live_map.is_empty() else {}
	var production_simulation: Dictionary = production_live.get("simulation", {}) if typeof(production_live.get("simulation", {})) == TYPE_DICTIONARY else {}
	var production_variation: Dictionary = production_live.get("variation_state", {}) if typeof(production_live.get("variation_state", {})) == TYPE_DICTIONARY else {}
	production_variation["ridge_run_cycles_remaining"] = 3
	game.call("_sync_variation_motor", production_live)
	CoinPusherSolverScript.step_ticks(production_simulation, {"motor_enabled": true}, 48)
	var live_ridge_surface := game.surface_state(production_run, production_environment)
	var ridge_sfx := SfxPlayer.new()
	var ridge_audio := ridge_sfx.debug_coin_pusher_motor_sync({"coin_pusher_motor_rate_fp": int(live_ridge_surface.get("coin_pusher_motor_rate_fp", 0)), "coin_pusher_body_count": int(live_ridge_surface.get("coin_pusher_body_count", 0)), "coin_pusher_audio_serial": 1, "reduce_motion": false})
	if int(production_simulation.get("motor_run_rate_fp", 0)) != 2000 or int(live_ridge_surface.get("coin_pusher_motor_rate_fp", 0)) != 2000 or not bool(ridge_audio.get("running", false)) or float(ridge_audio.get("pitch", 0.0)) <= 1.0:
		failures.append("Jackpot Ridge Run did not project live rate-2 motor/audio behavior.")
		ridge_sfx.queue_free()
		return
	ridge_sfx.queue_free()
	# The live ramp may legitimately move opening stock into the tray. Clear it
	# through the real money-credit boundary before isolating the paid multiplier
	# coin's exact-once assertion below.
	if not (production_simulation.get("tray_ledger", []) as Array).is_empty():
		game.surface_action_command("coin_pusher_collect", 0, false, {}, production_run, production_environment)
	production_variation["armed_multipliers"] = [{"multiplier": 3, "remaining": 2}]
	production_variation["pucks"] = [{"id": "ridge_live_lock", "kind": "lock"}]
	game.call("_consume_physics_events", production_run, production_live, [{"kind": "tray", "outcome": "tray", "body_kind": "puck", "stroke_cycle": 10, "phase_fp": 500, "metadata": {"feature_id": "ridge_live_lock"}}], _pusher_v3_rng("RIDGE-LIVE-LOCK"))
	var expected_live_lock_until := 10 * 240 * 1000 + 500 + 240 * 1000
	if int(production_variation.get("multiplier_lock_until_phase_units", -1)) != expected_live_lock_until:
		failures.append("Jackpot Ridge production live lock did not last exactly one physical stroke.")
		return
	var paid_coin := CoinPusherSolverScript.add_coin(production_simulation, _pusher_v3_rng("RIDGE-PRODUCTION-PAID"), 50000, 1, {"production_contract": true})
	paid_coin["x"] = 50000
	paid_coin["y"] = 0
	paid_coin["z"] = 0
	paid_coin["sleeping"] = false
	paid_coin["rest_state"] = "falling"
	var paid_step := _pusher_v3_step_until_bodies_exit(production_simulation, [str(paid_coin.get("id", ""))], 60, true)
	game.call("_consume_physics_events", production_run, production_live, paid_step.get("events", []), _pusher_v3_rng("RIDGE-PRODUCTION-CONSUME"))
	var paid_entry := {}
	for entry_value in production_simulation.get("tray_ledger", []):
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("body_id", "")) == str(paid_coin.get("id", "")):
			paid_entry = entry_value
			break
	var tray_credit := 0
	for entry_value in production_simulation.get("tray_ledger", []):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var ledger_entry: Dictionary = entry_value
		var ledger_provenance: Dictionary = ledger_entry.get("provenance", {}) if typeof(ledger_entry.get("provenance", {})) == TYPE_DICTIONARY else {}
		tray_credit += maxi(0, int(ledger_entry.get("value", 0))) * maxi(1, int(ledger_provenance.get("ridge_multiplier", 1)))
	var bankroll_before_collect := production_run.bankroll
	var collect_command := game.surface_action_command("coin_pusher_collect", 0, false, {}, production_run, production_environment)
	if int(((paid_entry.get("provenance", {}) as Dictionary).get("ridge_multiplier", 0))) != 3 \
			or production_run.bankroll != bankroll_before_collect + tray_credit \
			or not (production_simulation.get("tray_ledger", []) as Array).is_empty() \
			or not bool(collect_command.get("handled", false)):
		failures.append("Jackpot Ridge production event→multiplier→COLLECT path did not credit exactly once: entry=%s collect=%s." % [JSON.stringify(paid_entry), JSON.stringify(collect_command)])


func _check_pusher_v3_vault_physical_contract(library: ContentLibrary, failures: Array) -> void:
	var game_definition := library.game("coin_pusher")
	var game: GameModule = load(str(game_definition.get("module_path", ""))).new()
	game.setup(game_definition, library)
	var definition: Dictionary = game.call("_machine_definition", "vault_drop")
	var config: Dictionary = definition.get("sub_game", {}) if typeof(definition.get("sub_game", {})) == TYPE_DICTIONARY else {}
	var state := VaultDropVariationScript.initial_state(config, _pusher_v3_rng("VAULT-PHYSICAL-STATE"), 5, 5, "vault_contract")
	var reset_count := 0
	for cell_value in state.get("vault_cells", []):
		if typeof(cell_value) == TYPE_DICTIONARY and str((cell_value as Dictionary).get("kind", "")) == "reset":
			reset_count += 1
	if (state.get("vault_cells", []) as Array).size() != 9 or reset_count != 1 or not is_equal_approx(float(config.get("reset_odds_floor", 0.0)), 1.0 / 9.0):
		failures.append("Vault Drop shipped cell schema is not exactly nine cells with one RESET (1/9).")
	state["fragments"] = [{"id": "vault_fragment_contract"}]
	var simulation := _pusher_v3_state(definition, "VAULT-PHYSICAL-SIM")
	CoinPusherSolverScript.add_feature(simulation, "fragment", "vault_fragment_contract", 50000, 5000, {"z": 0, "radius": 5200, "height": 2800, "mass": 1800})
	var terminal: Dictionary = _pusher_v3_step_until_bodies_exit(simulation, ["body_00001"], 60, true)
	var banked: Dictionary = VaultDropVariationScript.apply_physical_events(state, terminal.get("events", []))
	if int(banked.get("fragments_banked", 0)) != 1 or int(state.get("banked_fragments", 0)) != 1 or not (state.get("fragments", []) as Array).is_empty():
		failures.append("Vault Drop did not bank the same fragment only at its real tray crossing.")
	var target := 0
	for index in range((state.get("vault_cells", []) as Array).size()):
		if str(((state.get("vault_cells", []) as Array)[index] as Dictionary).get("kind", "")) == "reset": target = index
	var peek := VaultDropVariationScript.peek_cell(state, target)
	var started := VaultDropVariationScript.start_round(state)
	var opened := VaultDropVariationScript.open_cell(state, target)
	var stopped := VaultDropVariationScript.stop_round(state)
	if not bool(peek.get("ok", false)) or not bool(started.get("ok", false)) or not bool(opened.get("ok", false)) or not bool(stopped.get("ok", false)) or int(state.get("meter_value", 0)) < int(config.get("progressive_floor", 120)):
		failures.append("Vault Drop physical fragment did not reach its peek/start/open/stop progressive lifecycle.")

	# Exercise the same lifecycle through the production module, beginning with
	# the authored 1800-mass fragment and a real physical tray event.
	var production_run := RunState.new()
	production_run.start_new("VAULT-PRODUCTION-LIFECYCLE", RunState.standard_challenge("VAULT-PRODUCTION-LIFECYCLE"))
	production_run.inventory.append("xray_glasses")
	var production_environment := {"id": "vault_production_lifecycle", "world_node_id": "vault_production_lifecycle", "scenario_game_modifiers": {"coin_pusher": {"variation_id": "vault_drop"}}, "game_states": {}}
	var generated: Dictionary = game.generate_environment_state(production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-GENERATE"))
	production_environment["game_states"] = {"coin_pusher": generated}
	game.environment_state_generated(production_run, production_environment, generated)
	var generated_variation: Dictionary = generated.get("variation_state", {}) if typeof(generated.get("variation_state", {})) == TYPE_DICTIONARY else {}
	var meter_id := str(generated_variation.get("meter_id", ""))
	var registered_meter := production_run.progressive_meter(meter_id)
	var registered_value := int(registered_meter.get("value", -1))
	production_run.town_state.advance_actions(2)
	game.enter(production_run, production_environment)
	var live_map: Dictionary = game.get("_live_machines")
	var live: Dictionary = live_map.values()[0] if not live_map.is_empty() else {}
	var live_simulation: Dictionary = live.get("simulation", {}) if typeof(live.get("simulation", {})) == TYPE_DICTIONARY else {}
	var live_state: Dictionary = live.get("variation_state", {}) if typeof(live.get("variation_state", {})) == TYPE_DICTIONARY else {}
	game.call("_sync_vault_meter", production_run, live)
	var grown_meter := production_run.progressive_meter(meter_id)
	if registered_meter.is_empty() or int(grown_meter.get("value", -1)) != registered_value + int(grown_meter.get("growth_per_action", 0)) * 2 or int(live_state.get("meter_value", -1)) != int(grown_meter.get("value", -2)):
		failures.append("Vault Drop town progressive did not register, grow on action boundaries, and sync into the live cabinet.")
		return
	var fragment_body := {}
	for body_value in live_simulation.get("bodies", []):
		if typeof(body_value) == TYPE_DICTIONARY and str((body_value as Dictionary).get("kind", "")) == "fragment":
			fragment_body = body_value
			break
	if fragment_body.is_empty() or int(fragment_body.get("mass", 0)) != 1800:
		failures.append("Vault Drop production fragment did not use authored mass 1800: %s." % JSON.stringify(fragment_body))
		return
	fragment_body["x"] = 50000
	fragment_body["y"] = 0
	fragment_body["z"] = 0
	fragment_body["sleeping"] = false
	fragment_body["rest_state"] = "falling"
	var physical_bank := _pusher_v3_step_until_bodies_exit(live_simulation, [str(fragment_body.get("id", ""))], 60, true)
	game.call("_consume_physics_events", production_run, live, physical_bank.get("events", []), _pusher_v3_rng("VAULT-PRODUCTION-CONSUME"))
	var reset_cell := -1
	var cash_cell := -1
	for index in range((live_state.get("vault_cells", []) as Array).size()):
		var kind := str(((live_state.get("vault_cells", []) as Array)[index] as Dictionary).get("kind", ""))
		if kind == "reset": reset_cell = index
		if kind == "cash" and cash_cell < 0: cash_cell = index
	var fragments_after_physical_bank := int(live_state.get("banked_fragments", 0))
	game.surface_action_command("coin_pusher_vault_cell_%d" % reset_cell, 0, false, {}, production_run, production_environment)
	production_run.inventory.erase("xray_glasses")
	var no_item_peek := game.resolve_with_context("peek_vault_cell", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-NO-XRAY"), {})
	if bool((no_item_peek.get("coin_pusher_vault_outcome", {}) as Dictionary).get("ok", false)) or int(live_state.get("peeked_cell", -1)) >= 0:
		failures.append("Vault Drop exposed truthful cell contents without the X-Ray Glasses item gate.")
		return
	production_run.inventory.append("xray_glasses")
	var peek_result := game.resolve_with_context("peek_vault_cell", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-PEEK"), {})
	var start_result := game.resolve_with_context("start_vault_round", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-START"), {})
	var stop_result := game.resolve_with_context("stop_vault_round", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-STOP"), {})
	var restart_result := game.resolve_with_context("start_vault_round", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-RESTART"), {})
	var reset_result := game.resolve_with_context("open_vault_cell", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-RESET"), {})
	var floor_value := int(config.get("progressive_floor", 120))
	if fragments_after_physical_bank != 1 or not bool((peek_result.get("coin_pusher_vault_outcome", {}) as Dictionary).get("ok", false)) \
			or not bool((start_result.get("coin_pusher_vault_outcome", {}) as Dictionary).get("ok", false)) \
			or not bool((stop_result.get("coin_pusher_vault_outcome", {}) as Dictionary).get("ok", false)) \
			or not bool((restart_result.get("coin_pusher_vault_outcome", {}) as Dictionary).get("ok", false)) \
			or not bool((reset_result.get("coin_pusher_vault_outcome", {}) as Dictionary).get("reset", false)) \
			or int(live_state.get("meter_value", -1)) != floor_value \
			or int(production_run.progressive_meter(meter_id).get("value", -1)) != floor_value:
		failures.append("Vault Drop production physical-bank/peek/start/stop/reset lifecycle failed: peek=%s start=%s stop=%s reset=%s state=%s." % [JSON.stringify(peek_result), JSON.stringify(start_result), JSON.stringify(stop_result), JSON.stringify(reset_result), JSON.stringify(live_state)])
		return
	# A production cash cell dispenses into the tray, never directly to bankroll.
	live_state["banked_fragments"] = 1
	game.surface_action_command("coin_pusher_vault_cell_%d" % cash_cell, 0, false, {}, production_run, production_environment)
	game.resolve_with_context("start_vault_round", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-CASH-START"), {})
	var bankroll_before_cash := production_run.bankroll
	var cash_result := game.resolve_with_context("open_vault_cell", 0, production_run, production_environment, _pusher_v3_rng("VAULT-PRODUCTION-CASH"), {})
	var cash_value := int((cash_result.get("coin_pusher_vault_outcome", {}) as Dictionary).get("cash", 0))
	if cash_value <= 0 or production_run.bankroll != bankroll_before_cash or (live_simulation.get("tray_ledger", []) as Array).is_empty():
		failures.append("Vault Drop production cash cell bypassed the tray or failed to dispense: %s." % JSON.stringify(cash_result))
		return
	game.surface_action_command("coin_pusher_collect", 0, false, {}, production_run, production_environment)
	if production_run.bankroll != bankroll_before_cash + cash_value or not (live_simulation.get("tray_ledger", []) as Array).is_empty():
		failures.append("Vault Drop production COLLECT did not move the dispensed cash exactly once.")
		return
	game.begin_chunked_exit_settle(production_run, production_environment)
	var exit_result := {"done": false}
	var exit_chunks := 0
	while not bool(exit_result.get("done", false)) and exit_chunks < 160:
		exit_result = game.advance_chunked_exit_settle(production_run, production_environment, 8)
		exit_chunks += 1
	game.finalize_chunked_exit_settle(production_run, production_environment)
	var durable_state := ((production_environment.get("game_states", {}) as Dictionary).get("coin_pusher", {}) as Dictionary).duplicate(true)
	game.enter(production_run, production_environment)
	var reentry_live_map: Dictionary = game.get("_live_machines")
	var reentry_live: Dictionary = reentry_live_map.values()[0] if not reentry_live_map.is_empty() else {}
	var durable_variation: Dictionary = durable_state.get("variation_state", {}) if typeof(durable_state.get("variation_state", {})) == TYPE_DICTIONARY else {}
	var reentry_variation: Dictionary = reentry_live.get("variation_state", {}) if typeof(reentry_live.get("variation_state", {})) == TYPE_DICTIONARY else {}
	if not bool(exit_result.get("done", false)) \
			or int(reentry_variation.get("meter_value", -1)) != int(durable_variation.get("meter_value", -2)) \
			or int(reentry_variation.get("banked_fragments", -1)) != int(durable_variation.get("banked_fragments", -2)) \
			or bool(reentry_variation.get("vault_round_active", false)) != bool(durable_variation.get("vault_round_active", true)) \
			or reentry_variation.get("vault_cells", []) != durable_variation.get("vault_cells", []):
		failures.append("Vault Drop production re-entry did not preserve meter/fragments/round/cell lifecycle state: durable=%s reentry=%s." % [JSON.stringify(durable_variation), JSON.stringify(reentry_variation)])
