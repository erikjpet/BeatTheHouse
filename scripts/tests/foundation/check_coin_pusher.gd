extends SceneTree

const PUSHER_V3_PERF_TICKS := 24


func _check_coin_pusher_contract(library: ContentLibrary, failures: Array) -> void:
	var game_definition := library.game("coin_pusher")
	if game_definition.is_empty():
		failures.append("Coin Pusher game definition is missing.")
		return
	var machine_definition: Dictionary = game_definition.get("coin_pusher_machine", {}) if typeof(game_definition.get("coin_pusher_machine", {})) == TYPE_DICTIONARY else {}
	_check_pusher_v3_machine_data(machine_definition, failures)
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
	_check_pusher_v3_live_loop_and_persistence(machine_definition, failures)
	_check_pusher_v3_solver_performance(machine_definition, failures)


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
			or int(geometry.get("drop_y", 0)) != 40000 \
			or int(geometry.get("drop_z", 0)) != 14000:
		failures.append("Coin Pusher V3 machine geometry drifted from Amendment 6.1.")
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
	var window_ratio: int = CoinPusherSolverScript.deck_landing_phase_ratio_milli(machine)
	if int(extended) != 28000 or int(retracted) != 46000 or int(window_ratio) < 180 or int(window_ratio) > 220:
		failures.append("Coin Pusher V3 stroke/apex landing window is wrong: extended=%s retracted=%s deck_window=%s milli." % [extended, retracted, window_ratio])


func _check_pusher_v3_rejected_mechanics_deleted(failures: Array) -> void:
	var solver_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher/coin_pusher_solver.gd")
	var game_source := FileAccess.get_file_as_string("res://scripts/games/coin_pusher.gd")
	var native_source := FileAccess.get_file_as_string("res://native/coin_pusher/src/coin_pusher_step_kernel.cpp")
	var data_source := FileAccess.get_file_as_string("res://data/games/games.json")
	for rejected in ["_pressurize_full_pile", "_pusher_face_y", "_hot_apply_pushers", "MAX_COLLISION_PASSES", "phase_accuracy", "clean_nudge_phase", "clean_nudge_window_steps", "overlap * 5", "lean > 620"]:
		if solver_source.contains(rejected) or game_source.contains(rejected) or native_source.contains(rejected) or data_source.contains(rejected):
			failures.append("Coin Pusher V3 retained rejected mechanic token: %s" % rejected)
	for rejected_native in ["ACTION_TICKS", "std::sqrt", "upper_locked", "lower_locked"]:
		if native_source.contains(rejected_native):
			failures.append("Coin Pusher V3 native outcome path retained rejected mechanic token: %s" % rejected_native)
	if not solver_source.contains("transport_rule\": \"platform_carry_plus_back_plate") \
			or solver_source.contains("ratchet_walk") \
			or solver_source.contains("scripted_ratchet"):
		failures.append("Coin Pusher V3 ratchet is not structurally declared as carry + back-plate contact only.")


func _check_pusher_v3_landing_skill(machine: Dictionary, failures: Array) -> void:
	var platform_state := _pusher_v3_state(machine, "PUSHER-V3-LAND-PLATFORM")
	_pusher_v3_hold_phase(platform_state, machine, 0)
	var platform_rng := _pusher_v3_rng("PUSHER-V3-LAND-PLATFORM-DROP")
	var platform_coin: Dictionary = CoinPusherSolverScript.add_coin(platform_state, platform_rng, 42000, 1)
	var platform_result: Dictionary = CoinPusherSolverScript.step_ticks(platform_state, {"motor_enabled": false}, 100)
	var landed_platform := _pusher_v3_body(platform_state, str(platform_coin.get("id", "")))
	var deck_state := _pusher_v3_state(machine, "PUSHER-V3-LAND-DECK")
	_pusher_v3_hold_phase(deck_state, machine, 120)
	var deck_rng := _pusher_v3_rng("PUSHER-V3-LAND-DECK-DROP")
	var deck_coin: Dictionary = CoinPusherSolverScript.add_coin(deck_state, deck_rng, 42000, 1)
	var deck_result: Dictionary = CoinPusherSolverScript.step_ticks(deck_state, {"motor_enabled": false}, 100)
	var landed_deck := _pusher_v3_body(deck_state, str(deck_coin.get("id", "")))
	if str(landed_platform.get("support_kind", "")) != "platform" or int(landed_platform.get("z", -1)) != 3600:
		failures.append("Coin Pusher V3 early-phase drop did not land physically on the platform top: %s" % JSON.stringify(landed_platform))
	if str(landed_deck.get("support_kind", "")) != "deck" or int(landed_deck.get("z", -1)) != 0:
		failures.append("Coin Pusher V3 retraction-apex drop did not land physically on the exposed deck: %s" % JSON.stringify(landed_deck))
	_check_pusher_v3_impact_measurements(platform_result, str(platform_coin.get("id", "")), "platform", failures)
	_check_pusher_v3_impact_measurements(deck_result, str(deck_coin.get("id", "")), "deck", failures)


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
