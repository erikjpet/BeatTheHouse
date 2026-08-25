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
	_check_pusher_v3_stocked_phase_topology(machine_definition, failures)
	_check_pusher_v3_nestle(machine_definition, failures)
	_check_pusher_v3_face_push(machine_definition, failures)
	_check_pusher_v3_collective_ratchet(machine_definition, failures)
	_check_pusher_v3_no_lattice(machine_definition, failures)
	_check_pusher_v3_skill_stop(machine_definition, failures)
	_check_pusher_v3_tray_gutter_ceiling(machine_definition, failures)
	_check_pusher_v3_energy_settle_conservation(machine_definition, failures)
	_check_pusher_v3_real_weight_gravity(machine_definition, failures)
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
	if float(signature.get("rear_width_factor", 0.0)) != 0.78 or float(signature.get("coin_rx", 0.0)) != 17.0 or float(signature.get("coin_ry", 0.0)) != 12.0 or float(signature.get("z_layer_offset", 0.0)) != 10.0 or float(signature.get("playfield_width_ratio", 0.0)) < 0.70 or float(signature.get("playfield_height_ratio", 0.0)) < 0.60 or playfield_rect.intersects(marquee_rect) or playfield_rect.intersects(backglass_rect) or not cabinet_rect.encloses(playfield_rect) or int(signature.get("rotation_frames", 0)) != 4 or not bool(signature.get("depth_sorted", false)) or int(signature.get("batch_draws", -1)) != 1 or int(signature.get("batched_nodes", -1)) != 0 or int(signature.get("per_coin_nodes", -1)) != 0 or signature.get("draw_order", []) != ["shadows", "coin_batch", "feature_labels", "glass", "hardware"]:
		failures.append("Coin Pusher V3 lost the playfield-dominant 0.78/17x12/10px/four-frame batched projection contract: %s." % JSON.stringify(signature))
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
	_check_pusher_v3_shipped_variant_definitions(machine, failures)


func _check_pusher_v3_shipped_variant_definitions(machine: Dictionary, failures: Array) -> void:
	var ridge_pegs: Array = []
	var ridge_rows := [
		[20000, [12500, 37500, 62500, 87500]],
		[17000, [5000, 27500, 50000, 72500, 95000]],
		[14000, [12500, 37500, 62500, 87500]],
		[11000, [5000, 27500, 50000, 72500, 95000]],
		[8000, [12500, 37500, 62500, 87500]],
	]
	for row in ridge_rows:
		for x in row[1]:
			ridge_pegs.append({"x": x, "z": row[0], "r": 1200})
	var common_geometry := {"width": 100000, "tray_lip_y": 6000, "deck_z": 0, "platform_top_z": 3600, "face_extended_y": 28000, "face_retracted_y": 46000, "back_plate_y": 63000, "back_plate_gap": 400, "drop_y": 58000, "drop_z": 24000}
	var common_stroke := {"period_ticks": 240, "ramp_ticks": 24, "profile": "cosine"}
	var common_coins := {"radius": 4300, "height": 1700, "mass": 1000, "value": 1, "drop_cost": 1}
	var board := {"y": 58000, "z_top": 24000, "z_bottom": 3600, "x_min": 0, "x_max": 100000}
	var ridge_geometry := common_geometry.duplicate(true)
	ridge_geometry["gutter_x"] = 4000
	var ridge_expected := {
		"machine_id": "jackpot_ridge", "geometry": ridge_geometry, "stroke": common_stroke.duplicate(true),
		"apparatus": {"type": "hole_set", "rail": {}, "holes": [25000, 50000, 75000], "drop_board": board.duplicate(true), "pegs": ridge_pegs, "release_jitter": 300, "custom": {}},
		"coins": common_coins.duplicate(true), "ceiling": 600, "economy": {"documented_ev_band": [0.70, 1.08]},
		"sub_game": {"feature_kind": "puck", "feature_mass": 3000, "jam_radius": 5200, "ridge_run_rate": 2, "stroke_period_ticks": 240},
	}
	var vault_geometry := common_geometry.duplicate(true)
	vault_geometry["gutter_x"] = 4400
	var vault_expected := {
		"machine_id": "vault_drop", "geometry": vault_geometry, "stroke": common_stroke.duplicate(true),
		"apparatus": {"type": "rail_slot", "rail": {"x_min": 10000, "x_max": 90000, "speed_per_tick": 750}, "holes": [], "drop_board": board.duplicate(true), "pegs": [{"x": 22000, "z": 12500, "r": 1400}, {"x": 42000, "z": 10500, "r": 1400}, {"x": 62000, "z": 12500, "r": 1400}, {"x": 82000, "z": 10500, "r": 1400}], "release_jitter": 220, "custom": {}},
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
		for target_x in _pusher_v3_release_targets(definition):
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
					for event_value in target_result.get("events", []):
						if typeof(event_value) != TYPE_DICTIONARY or str((event_value as Dictionary).get("body_id", "")) != str(target_coin.get("id", "")):
							continue
						if str((event_value as Dictionary).get("kind", "")) in ["tray", "gutter"] and target_root.is_empty():
							terminal_before_support = true
						if bool((event_value as Dictionary).get("first_support", false)):
							target_root = str((event_value as Dictionary).get("support_root", ""))
							break
					var landed_view := _pusher_v3_body(target_state, str(target_coin.get("id", "")))
					var independent_root := str((CoinPusherSolverScript.body_views(target_state).filter(func(view): return str((view as Dictionary).get("id", "")) == str(target_coin.get("id", ""))).front() as Dictionary).get("support_root", "")) if not landed_view.is_empty() else ""
					if target_root != "platform" or independent_root != "platform" or terminal_before_support:
						failures.append("Coin Pusher V3 Cartesian landing failed at %s x=%d phase=%d jitter_sign=%d: event_root=%s view_root=%s terminal_before_support=%s." % [variation_id, int(target_x), phase, desired_sign, target_root, independent_root, terminal_before_support])
						return


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
	var pegs: Array = apparatus.get("pegs", []) if typeof(apparatus.get("pegs", [])) == TYPE_ARRAY else []
	var jitter := maxi(0, int(apparatus.get("release_jitter", 0)))
	var saw_negative := false
	var saw_positive := false
	for target_x in _pusher_v3_release_targets(definition):
		for seed_index in range(32):
			var state := CoinPusherSolverScript.create_machine(_pusher_v3_rng("PUSHER-V3-JITTER-STATE-%s-%d-%d" % [variation_id, int(target_x), seed_index]), definition, 0)
			var released: Dictionary = CoinPusherSolverScript.add_coin(state, _pusher_v3_rng("PUSHER-V3-JITTER-DROP-%s-%d-%d" % [variation_id, int(target_x), seed_index]), int(target_x), 1)
			var release_x := int(released.get("x", int(target_x)))
			var offset := release_x - int(target_x)
			saw_negative = saw_negative or offset < 0
			saw_positive = saw_positive or offset > 0
			if absi(offset) > jitter:
				failures.append("Coin Pusher V3 production release escaped authored jitter at %s x=%d offset=%d jitter=%d." % [variation_id, int(target_x), offset, jitter])
				return
			for peg_value in pegs:
				if typeof(peg_value) == TYPE_DICTIONARY and release_x == int((peg_value as Dictionary).get("x", release_x + 1)):
					failures.append("Coin Pusher V3 production release created exact peg symmetry at %s x=%d seed=%d." % [variation_id, release_x, seed_index])
					return
	if jitter > 0 and (not saw_negative or not saw_positive):
		failures.append("Coin Pusher V3 production release seed set did not exercise both jitter signs at %s." % variation_id)


func _pusher_v3_release_targets(definition: Dictionary) -> Array:
	var apparatus: Dictionary = definition.get("apparatus", {}) if typeof(definition.get("apparatus", {})) == TYPE_DICTIONARY else {}
	var holes: Array = apparatus.get("holes", []) if typeof(apparatus.get("holes", [])) == TYPE_ARRAY else []
	if not holes.is_empty():
		return holes.duplicate()
	var rail: Dictionary = apparatus.get("rail", {}) if typeof(apparatus.get("rail", {})) == TYPE_DICTIONARY else {}
	var rail_min := int(rail.get("x_min", 8000))
	var rail_max := int(rail.get("x_max", 92000))
	return [rail_min, (rail_min + rail_max) / 2, rail_max]


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
	var gutter_step := CoinPusherSolverScript.step_ticks_reference_for_test(simulation, {"motor_enabled": false}, 1)
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
	if landing_tick < 24 or landing_tick > 45 or int(landing_event.get("impact_speed", 0)) < 40000 or str(landing_event.get("impact_class", "")) != "hard" or int(landing_event.get("fall_height", 0)) < 18000:
		failures.append("Coin Pusher V3 insert did not produce a fast, weighty physical landing: tick=%d event=%s." % [landing_tick, JSON.stringify(landing_event)])
		return
	CoinPusherSolverScript.step_ticks(production, {"motor_enabled": false}, 5)
	var landed_body := _pusher_v3_body(production, body_id)
	if landed_body.is_empty() or not bool(landed_body.get("sleeping", false)) or str(landed_body.get("rest_state", "")) != "resting":
		failures.append("Coin Pusher V3 hard landing did not settle without floaty post-impact chatter: %s." % JSON.stringify(landed_body))


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
	CoinPusherSolverScript.step_ticks(production_simulation, {"motor_enabled": true}, 24)
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
	var paid_step := CoinPusherSolverScript.step_ticks_reference_for_test(production_simulation, {"motor_enabled": false}, 1)
	game.call("_consume_physics_events", production_run, production_live, paid_step.get("events", []), _pusher_v3_rng("RIDGE-PRODUCTION-CONSUME"))
	var paid_entry := {}
	for entry_value in production_simulation.get("tray_ledger", []):
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("body_id", "")) == str(paid_coin.get("id", "")):
			paid_entry = entry_value
			break
	var bankroll_before_collect := production_run.bankroll
	var collect_command := game.surface_action_command("coin_pusher_collect", 0, false, {}, production_run, production_environment)
	if int(((paid_entry.get("provenance", {}) as Dictionary).get("ridge_multiplier", 0))) != 3 \
			or production_run.bankroll != bankroll_before_collect + 3 \
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
	var physical_bank := CoinPusherSolverScript.step_ticks_reference_for_test(live_simulation, {"motor_enabled": false}, 1)
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
