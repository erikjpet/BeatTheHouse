extends "res://scripts/tests/foundation/check_lenders_release_saves.gd"


func _check_scratch_tickets_surface_contract(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-TICKET-CONTRACT")
	run_state.bankroll = 5000
	var environment := {
		"id": "scratch_contract_gas",
		"archetype_id": "gas_station_casino",
		"kind": "casino",
		"game_ids": ["scratch_tickets"],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 18},
		"visual_context": {"scene_type": "gas_station_casino"},
	}
	var machine: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("scratch_stock"))
	if str(machine.get("schema", "")) != "scratch_ticket_machine_state":
		failures.append("Scratch Tickets did not generate its machine-state schema.")
	if _scratch_test_dictionary_array(machine.get("stock", [])).size() != 3:
		failures.append("Scratch Tickets slice 1 machine did not expose all three launch types.")
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment.duplicate(true)
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "scratch_tickets":
		failures.append("Scratch Tickets surface did not route to its renderer.")
	if not bool(surface.get("surface_controls_native", false)) or bool(surface.get("surface_stake_controls_required", true)):
		failures.append("Scratch Tickets did not expose fixed-price native controls.")
	if not bool(surface.get("surface_animates_idle", false)) or bool(surface.get("surface_realtime_state_refresh", true)):
		failures.append("Scratch Tickets idle liveness/zero-copy flags are incorrect.")
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if not _surface_harness_has_action(harness, "scratch_buy"):
		failures.append("Scratch Tickets vending machine did not register buy hit regions.")

	var buy_command := game.surface_action_command("scratch_buy", 0, false, {}, run_state, environment)
	var buy_ui: Dictionary = buy_command.get("ui_state", {})
	var before_bankroll := run_state.bankroll
	var purchase := game.resolve_with_context("buy_scratch_ticket", int(buy_command.get("set_stake", 0)), run_state, environment, run_state.create_rng("scratch_purchase"), buy_ui)
	if not bool(buy_command.get("direct_resolve", false)) or not bool(purchase.get("scratch_outcome_fixed_at_purchase", false)):
		failures.append("Scratch Tickets purchase did not create a fixed outcome through the shared result path.")
	if run_state.bankroll != before_bankroll - int(purchase.get("stake", 0)):
		failures.append("Scratch Tickets purchase did not charge cash exactly once.")
	var purchased_machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var active_ticket: Dictionary = purchased_machine.get("active_ticket", {})
	var original_cells := _scratch_test_dictionary_array(active_ticket.get("cells", [])).duplicate(true)
	var begin := game.surface_pointer_command("scratch_scrub", 0, "begin", Vector2(400, 160), {}, run_state, environment)
	game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(400, 160), begin.get("ui_state", {}), run_state, environment)
	var after_click_ticket: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	if _scratch_test_dictionary_array(after_click_ticket.get("cells", [])) != original_cells:
		failures.append("Scratch Tickets bare click changed the latex mask; reveal must require drag motion.")

	var active_surface := game.surface_state(run_state, environment, {})
	harness.setup(active_surface)
	game.draw_surface(harness, active_surface, {"contract_harness": true})
	var scrub_hit := _surface_harness_first_hit(harness, "scratch_scrub", 0)
	if scrub_hit.is_empty() or not bool(scrub_hit.get("drag", false)):
		failures.append("Scratch Tickets did not register a pointer-capture drag region over the latex.")

	_check_scratch_ticket_determinism(game, failures)
	_check_scratch_ticket_feel_defaults(game, run_state, environment, failures)
	_check_scratch_ticket_save_restore(run_state, environment, failures)
	_check_scratch_ticket_penalty_and_clerk(game, run_state, environment, failures)
	_check_scratch_ticket_luck_hook(game, failures)
	_check_scratch_ticket_rtp(game, failures)


func _check_scratch_ticket_determinism(game: GameModule, failures: Array) -> void:
	for type_id in ["lucky_7s", "cash_cow", "high_voltage"]:
		var first: Dictionary = game.call("simulate_ticket_type", type_id, _scratch_test_rng("fixed:%s" % type_id), 0)
		var second: Dictionary = game.call("simulate_ticket_type", type_id, _scratch_test_rng("fixed:%s" % type_id), 0)
		if first != second:
			failures.append("Scratch Tickets purchase outcome was not deterministic for %s." % type_id)
	var rolled: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "high_voltage"), _scratch_test_rng("scratch-order"), 0, "order")
	var symbols_before := _scratch_test_ticket_symbols(rolled)
	var order := range(symbols_before.size())
	order.reverse()
	for index in order:
		var cell: Dictionary = (_scratch_test_dictionary_array(rolled.get("cells", []))[index] as Dictionary)
		cell["revealed"] = true
	if _scratch_test_ticket_symbols(rolled) != symbols_before:
		failures.append("Scratch Tickets reveal order altered purchase-fixed symbols.")


func _check_scratch_ticket_feel_defaults(game: GameModule, run_state: RunState, environment: Dictionary, failures: Array) -> void:
	var machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var ticket: Dictionary = machine.get("active_ticket", {})
	var grid: Dictionary = ticket.get("grid", {})
	var columns := int(grid.get("columns", 3))
	var rows := int(grid.get("rows", 3))
	for index in range(_scratch_test_dictionary_array(ticket.get("cells", [])).size()):
		var rect: Rect2 = game.call("_cell_rect", index, columns, rows)
		game.call("_scratch_segment", machine, Vector2(rect.position.x + 4.0, rect.get_center().y), Vector2(rect.end.x - 4.0, rect.get_center().y))
		var cells := _scratch_test_dictionary_array((machine.get("active_ticket", {}) as Dictionary).get("cells", []))
		if not bool((cells[index] as Dictionary).get("revealed", false)):
			game.call("_scratch_segment", machine, Vector2(rect.position.x + 4.0, rect.get_center().y + 7.0), Vector2(rect.end.x - 4.0, rect.get_center().y + 7.0))
			cells = _scratch_test_dictionary_array((machine.get("active_ticket", {}) as Dictionary).get("cells", []))
		if not bool((cells[index] as Dictionary).get("revealed", false)):
			failures.append("Scratch Tickets cell %d did not clear in one or two casual swipes." % index)
	if not bool(game.call("_ticket_complete", machine.get("active_ticket", {}))):
		failures.append("Scratch Tickets forgiving defaults left corner grinding after two swipes.")
	var fast_ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "cash_cow"), _scratch_test_rng("fast-swipe"), 0, "fast")
	var fast_machine := {"active_ticket": fast_ticket, "pending_penalty": 0}
	for row in range(3):
		var left: Rect2 = game.call("_cell_rect", row * 3, 3, 3)
		var right: Rect2 = game.call("_cell_rect", row * 3 + 2, 3, 3)
		game.call("_scratch_segment", fast_machine, Vector2(left.position.x + 3.0, left.get_center().y), Vector2(right.end.x - 3.0, right.get_center().y))
	for cell_value in _scratch_test_dictionary_array((fast_machine.get("active_ticket", {}) as Dictionary).get("cells", [])):
		if not bool((cell_value as Dictionary).get("revealed", false)):
			failures.append("Scratch Tickets interpolated fast swipe skipped a cell.")
			break
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment.duplicate(true)


func _check_scratch_ticket_save_restore(run_state: RunState, environment: Dictionary, failures: Array) -> void:
	run_state.current_environment = environment.duplicate(true)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var original: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	var loaded: Dictionary = ((restored.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	if _scratch_test_dictionary_array(original.get("cells", [])) != _scratch_test_dictionary_array(loaded.get("cells", [])):
		failures.append("Scratch Tickets save/load did not round-trip the mid-ticket mask.")


func _check_scratch_ticket_penalty_and_clerk(game: GameModule, run_state: RunState, environment: Dictionary, failures: Array) -> void:
	var shock_ticket := {}
	for seed_index in range(32):
		var candidate: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "high_voltage"), _scratch_test_rng("shock:%d" % seed_index), 0, "shock")
		if int(game.call("_ticket_penalty_total", candidate)) > 0:
			shock_ticket = candidate
			break
	if shock_ticket.is_empty():
		failures.append("Scratch Tickets High Voltage fixture could not roll a SHOCK symbol.")
		return
	var machine := {"schema": "scratch_ticket_machine_state", "version": 1, "stock": [], "active_ticket": shock_ticket, "winner_pile": [], "loser_pile": [], "pending_penalty": 0}
	game.call("_reveal_all", machine)
	environment["game_states"] = {"scratch_tickets": machine}
	var before := run_state.bankroll
	var settle := game.resolve_with_context("settle_scratch_ticket", 0, run_state, environment, run_state.create_rng("shock_settle"), {})
	var paid := -int(settle.get("bankroll_delta", 0))
	if paid <= 0 or run_state.bankroll != before - paid:
		failures.append("Scratch Tickets SHOCK penalty did not apply exactly once.")
	var settled: Dictionary = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if _scratch_test_dictionary_array(settled.get("winner_pile", [])).is_empty():
		var forced := shock_ticket.duplicate(true)
		forced["payout"] = 25
		forced["settled"] = true
		settled["winner_pile"] = [forced]
		environment["game_states"] = {"scratch_tickets": settled}
	var pending := int(game.call("_pending_payout", settled))
	var cash_before := run_state.bankroll
	var clerk: Dictionary = game.environment_action_command("scratch_ticket_clerk", "redeem_scratch_winners", run_state, environment, run_state.create_rng("scratch_clerk")).get("result", {})
	if pending <= 0 or int(clerk.get("bankroll_delta", 0)) != pending or run_state.bankroll != cash_before + pending:
		failures.append("Scratch Tickets clerk did not cash pending winners.")


func _check_scratch_ticket_luck_hook(game: GameModule, failures: Array) -> void:
	var cold_rng := _scratch_test_rng("luck-hook")
	var hot_rng := _scratch_test_rng("luck-hook")
	var cold_total := 0
	var hot_total := 0
	for _index in range(3000):
		cold_total += int((game.call("simulate_ticket_type", "lucky_7s", cold_rng, -10) as Dictionary).get("payout", 0))
		hot_total += int((game.call("simulate_ticket_type", "lucky_7s", hot_rng, 10) as Dictionary).get("payout", 0))
	if hot_total <= cold_total:
		failures.append("Scratch Tickets effective-luck hook did not improve purchase-time rolls.")


func _check_scratch_ticket_rtp(game: GameModule, failures: Array) -> void:
	for type_id in ["lucky_7s", "cash_cow", "high_voltage"]:
		var metrics: Dictionary = game.call("measure_rtp", type_id, 20000, "FOUNDATION-RTP")
		var ticket_type: Dictionary = game.call("_ticket_type", type_id)
		var band: Array = ticket_type.get("rtp_band", [])
		var rtp := float(metrics.get("rtp", -1.0))
		if band.size() < 2 or rtp < float(band[0]) or rtp > float(band[1]):
			failures.append("Scratch Tickets %s RTP %.5f missed declared band %s." % [type_id, rtp, str(band)])


func _scratch_test_rng(seed_text: String) -> RngStream:
	var rng := RngStream.new()
	var seed := RunState.text_to_seed(seed_text)
	rng.configure(seed, seed)
	return rng


func _scratch_test_dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			result.append(entry)
	return result


func _scratch_test_ticket_symbols(ticket: Dictionary) -> Array:
	var result: Array = []
	for cell_value in _scratch_test_dictionary_array(ticket.get("cells", [])):
		result.append(str((cell_value as Dictionary).get("symbol", "")))
	return result
