extends SceneTree

const PUSHER_V3_PERF_TICKS := 24
const JackpotRidgeVariationScript := preload("res://scripts/games/coin_pusher/jackpot_ridge.gd")
const VaultDropVariationScript := preload("res://scripts/games/coin_pusher/vault_drop.gd")


func _check_coin_pusher_contract(library: ContentLibrary, failures: Array) -> void:
	var game_definition := library.game("coin_pusher")
	if game_definition.is_empty():
		failures.append("Coin Pusher game definition is missing.")
		return
	var machine_definition: Dictionary = game_definition.get("coin_pusher_machine", {}) if typeof(game_definition.get("coin_pusher_machine", {})) == TYPE_DICTIONARY else {}
	_check_pusher_v3_machine_data(machine_definition, failures)
	_check_pusher_v3_alive_cabinet(library, machine_definition, failures)
	_check_pusher_v3_presentation_view(machine_definition, failures)
	_check_pusher_v3_rejected_mechanics_deleted(failures)
	_check_pusher_v3_landing_skill(machine_definition, failures)
	_check_pusher_v3_nestle(machine_definition, failures)
	_check_pusher_v3_face_push(machine_definition, failures)
	_check_pusher_v3_collective_ratchet(machine_definition, failures)
	_check_pusher_v3_no_lattice(machine_definition, failures)
	_check_pusher_v3_skill_stop(machine_definition, failures)
	_check_pusher_v3_tray_gutter_ceiling(machine_definition, failures)
	_check_pusher_v3_energy_settle_conservation(machine_definition, failures)
	_check_pusher_v3_input_trace_determinism(machine_definition, failures)
	_check_pusher_v3_ridge_physical_contract(library, failures)
	_check_pusher_v3_vault_physical_contract(library, failures)
	_check_pusher_v3_live_loop_and_persistence(machine_definition, failures)
	_check_pusher_v3_production_rail_drag(library, failures)
	_check_pusher_v3_v2_production_migration(library, failures)
	_check_pusher_v3_generated_rider_production(library, failures)
	_check_pusher_v3_solver_performance(machine_definition, failures)


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
	if float(signature.get("rear_width_factor", 0.0)) != 0.78 or float(signature.get("coin_rx", 0.0)) != 17.0 or float(signature.get("coin_ry", 0.0)) != 12.0 or float(signature.get("z_layer_offset", 0.0)) != 11.0 or int(signature.get("rotation_frames", 0)) != 4 or not bool(signature.get("depth_sorted", false)) or int(signature.get("batch_draws", -1)) != 1 or int(signature.get("batched_nodes", -1)) != 0 or int(signature.get("per_coin_nodes", -1)) != 0 or signature.get("draw_order", []) != ["shadows", "coin_batch", "feature_labels", "glass", "hardware"]:
		failures.append("Coin Pusher V3 projection drifted from the binding 0.78/17x12/11px/four-frame batched contract: %s." % JSON.stringify(signature))
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
	if float(hostile_signature.get("projection_width", 0.0)) != 200000.0 or float(hostile_signature.get("projection_back_y", 0.0)) != 80000.0 or float(hostile_signature.get("projection_coin_height", 0.0)) != 2500.0 or not is_equal_approx(projected_center.x, 450.0) or not is_equal_approx(projected_coin_high.y, projected_center.y - 11.0) or authored_deck.size() != 5:
		failures.append("Coin Pusher V3 renderer did not consume nondefault public geometry/coin height/deck polygon: signature=%s center=%s high=%s deck=%d." % [JSON.stringify(hostile_signature), projected_center, projected_coin_high, authored_deck.size()])
	if int(renderer.debug_interpolated_face_y_for_test(hostile_state)) != 37000:
		failures.append("Coin Pusher V3 face/platform midpoint interpolation was not 37000.")
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
	live_session["presentation_previous_bodies"] = [{"id": "plate", "kind": "coin", "x": 50000, "y": 58700, "z": 3600, "rest_state": "resting", "support_kind": "platform"}]
	live_session["presentation_current_bodies"] = [{"id": "plate", "kind": "coin", "x": 50000, "y": 58700, "z": 3600, "rest_state": "resting", "support_kind": "platform"}]
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


func _check_pusher_v3_machine_data(machine: Dictionary, failures: Array) -> void:
	var geometry: Dictionary = machine.get("geometry", {}) if typeof(machine.get("geometry", {})) == TYPE_DICTIONARY else {}
	var stroke: Dictionary = machine.get("stroke", {}) if typeof(machine.get("stroke", {})) == TYPE_DICTIONARY else {}
	var apparatus: Dictionary = machine.get("apparatus", {}) if typeof(machine.get("apparatus", {})) == TYPE_DICTIONARY else {}
	if str(machine.get("machine_id", "")) != "quarter_falls" \
			or int(geometry.get("width", 0)) != 100000 \
			or int(geometry.get("tray_lip_y", 0)) != 6000 \
			or int(geometry.get("face_extended_y", 0)) != 28000 \
			or int(geometry.get("face_retracted_y", 0)) != 46000 \
			or int(geometry.get("back_plate_y", 0)) != 63000 \
			or int(geometry.get("platform_top_z", 0)) != 3600 \
			or int(geometry.get("drop_y", 0)) != 58000 \
			or int(geometry.get("drop_z", 0)) != 24000:
		failures.append("Coin Pusher V3 machine geometry drifted from Amendment 6.2.")
	if int(stroke.get("period_ticks", 0)) != 240 or int(stroke.get("ramp_ticks", 0)) != 24 or str(stroke.get("profile", "")) != "cosine":
		failures.append("Coin Pusher V3 stroke data is not the binding 240-tick cosine/24-tick-ramp contract.")
	if str(apparatus.get("type", "")) != "rail_slot" or (apparatus.get("pegs", []) as Array).size() != 3 or int(machine.get("ceiling", 0)) != 600:
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
	if int(extended) != 28000 or int(retracted) != 46000:
		failures.append("Coin Pusher V3 stroke orientation drifted: extended=%s retracted=%s." % [extended, retracted])


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


func _check_pusher_v3_landing_skill(machine: Dictionary, failures: Array) -> void:
	var definitions := {"quarter_falls": machine}
	for variation_id in ["jackpot_ridge", "vault_drop"]:
		var variant: Dictionary = (machine.get("machines", {}) as Dictionary).get(variation_id, {}) if typeof(machine.get("machines", {})) == TYPE_DICTIONARY else {}
		definitions[variation_id] = variant
	for variation_id in definitions.keys():
		var definition: Dictionary = definitions[variation_id]
		var period := int((definition.get("stroke", {}) as Dictionary).get("period_ticks", 240))
		for phase in range(period):
			var state := _pusher_v3_state(definition, "PUSHER-V3-UPPER-%s-%03d" % [variation_id, phase])
			_pusher_v3_hold_phase(state, definition, phase)
			var drop_rng := _pusher_v3_rng("PUSHER-V3-UPPER-DROP-%s-%03d" % [variation_id, phase])
			var coin: Dictionary = CoinPusherSolverScript.add_coin(state, drop_rng, int((definition.get("geometry", {}) as Dictionary).get("width", 100000)) / 2, 1)
			var first_support := ""
			var landing_result: Dictionary = CoinPusherSolverScript.step_ticks_reference_for_test(state, {"motor_enabled": false}, 480)
			for event_value in landing_result.get("events", []):
				if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("body_id", "")) == str(coin.get("id", "")) and bool((event_value as Dictionary).get("first_support", false)):
					first_support = str((event_value as Dictionary).get("support_root", ""))
					break
			if first_support != "platform":
				failures.append("Coin Pusher V3 Amendment 6.2 first support bypassed the upper platform at %s phase %d: %s." % [variation_id, phase, first_support])
				return


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
			bodies.append(_pusher_v3_body_fixture("mass_%d_%d" % [row, column], 42000 + column * 8200, 38000 - row * 8200, 0, true, "deck"))
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
	CoinPusherSolverScript.step_ticks(state, {"motor_enabled": false}, 1)
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
	if representative_bytes > 2300 or cap_bytes > 5000:
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
	var exit_result := CoinPusherSolverScript.step_ticks(simulation, {"motor_enabled": false}, 1)
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
		"meta": {"value": 1},
	}


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
			or not impact.has("stack_depth") \
			or int(impact.get("fall_height", 0)) <= 0 \
			or int(impact.get("stack_depth", -1)) < 0:
		failures.append("Coin Pusher V3 %s impact omitted valid fall_height/stack_depth evidence: %s" % [expected_support, JSON.stringify(impact)])


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
	var lock_events: Dictionary = CoinPusherSolverScript.step_ticks_reference_for_test(lock_sim, {"motor_enabled": false}, 1)
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
	var run_events: Dictionary = CoinPusherSolverScript.step_ticks_reference_for_test(run_sim, {"motor_enabled": false}, 1)
	var run_outcome: Dictionary = JackpotRidgeVariationScript.apply_physical_events(run_state, run_events.get("events", []), config, 4)
	if not bool(run_outcome.get("ridge_run_triggered", false)) or int(run_state.get("ridge_run_count", 0)) != 1 or JackpotRidgeVariationScript.motor_rate_multiplier(run_state, config) != 2:
		failures.append("Jackpot Ridge Run did not arise once from three same-cycle physical banks at rate 2.")


func _check_pusher_v3_vault_physical_contract(library: ContentLibrary, failures: Array) -> void:
	var game_definition := library.game("coin_pusher")
	var game: GameModule = load(str(game_definition.get("module_path", ""))).new()
	game.setup(game_definition, library)
	var definition: Dictionary = game.call("_machine_definition", "vault_drop")
	var config: Dictionary = definition.get("sub_game", {}) if typeof(definition.get("sub_game", {})) == TYPE_DICTIONARY else {}
	var state := VaultDropVariationScript.initial_state(config, _pusher_v3_rng("VAULT-PHYSICAL-STATE"), 5, 5, "vault_contract")
	state["fragments"] = [{"id": "vault_fragment_contract"}]
	var simulation := _pusher_v3_state(definition, "VAULT-PHYSICAL-SIM")
	CoinPusherSolverScript.add_feature(simulation, "fragment", "vault_fragment_contract", 50000, 5000, {"z": 0, "radius": 5200, "height": 2800, "mass": 2000})
	var terminal: Dictionary = CoinPusherSolverScript.step_ticks_reference_for_test(simulation, {"motor_enabled": false}, 1)
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
