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
	if _scratch_test_dictionary_array(game.call("_ticket_types")).size() != 10:
		failures.append("Scratch Tickets launch roster did not expose all ten ticket types.")
	if _scratch_test_dictionary_array(machine.get("stock", [])).size() != 4:
		failures.append("Scratch Tickets machine did not draw its four-slot weighted subset.")
	var environment_hooks := _scratch_test_dictionary_array(machine.get("environment_hooks", []))
	if environment_hooks.size() != 1 or str((environment_hooks[0] as Dictionary).get("id", "")) != "scratch_ticket_clerk" or str((environment_hooks[0] as Dictionary).get("unique_object_class", "")) != "scratch_ticket_clerk":
		failures.append("Scratch Tickets machine did not persist its clerk hook for collision-safe room layout.")
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
	_check_scratch_ticket_gimmicks(game, failures)
	_check_scratch_ticket_items(game, failures)
	_check_scratch_ticket_stock_and_collection(game, failures)
	_check_scratch_ticket_rtp(game, failures)


func _check_scratch_ticket_determinism(game: GameModule, failures: Array) -> void:
	for type_id in _scratch_ticket_type_ids():
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
	for type_id in _scratch_ticket_type_ids():
		var roster_ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_test_rng("feel:%s" % type_id), 0, "feel")
		var roster_machine := {"active_ticket": roster_ticket, "pending_penalty": 0, "penalty_shields_remaining": 0}
		var roster_grid := roster_ticket.get("grid", {}) as Dictionary
		var roster_columns := int(roster_grid.get("columns", 3))
		var roster_rows := int(roster_grid.get("rows", 3))
		for row in range(roster_rows):
			var left: Rect2 = game.call("_cell_rect", row * roster_columns, roster_columns, roster_rows)
			var right: Rect2 = game.call("_cell_rect", row * roster_columns + roster_columns - 1, roster_columns, roster_rows)
			game.call("_scratch_segment", roster_machine, Vector2(left.position.x + 3.0, left.get_center().y), Vector2(right.end.x - 3.0, right.get_center().y))
		if not bool(game.call("_ticket_complete", roster_machine.get("active_ticket", {}))):
			failures.append("Scratch Tickets %s did not clear breezily with one full swipe per row." % type_id)
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


func _check_scratch_ticket_gimmicks(game: GameModule, failures: Array) -> void:
	var multiplier_ticket := _scratch_find_ticket(game, "gold_rush_doubler", "multiplier_symbol")
	var multiplier_outcome := multiplier_ticket.get("outcome", {}) as Dictionary
	if multiplier_ticket.is_empty() or not _scratch_test_ticket_symbols(multiplier_ticket).has(str(multiplier_ticket.get("multiplier_symbol", ""))):
		failures.append("Gold Rush Doubler did not print its purchase-fixed multiplier symbol.")
	elif not is_equal_approx(float(multiplier_outcome.get("base_payout", 0.0)) * float(multiplier_outcome.get("multiplier", 0)), float(multiplier_ticket.get("payout", -1))):
		failures.append("Gold Rush Doubler payout did not equal base line prize times multiplier.")
	var bonus_ticket := _scratch_find_ticket(game, "bonus_box", "payout")
	var bonus_machine := {"active_ticket": bonus_ticket, "pending_penalty": 0, "penalty_shields_remaining": 0}
	game.call("_reveal_all", bonus_machine)
	var revealed_bonus := bonus_machine.get("active_ticket", {}) as Dictionary
	if not _scratch_test_ticket_symbols(revealed_bonus).has("KEY") or not _scratch_test_ticket_symbols(revealed_bonus).has("BONUS") or not bool(revealed_bonus.get("bonus_unlocked", false)):
		failures.append("Bonus Box key did not unlock its separate bonus area.")
	var word_ticket := _scratch_find_ticket(game, "word_hunt", "winning_word")
	var word := str(word_ticket.get("winning_word", ""))
	var word_symbols := _scratch_test_ticket_symbols(word_ticket)
	var printed_word := ""
	for index in range(mini(word.length(), word_symbols.size())):
		printed_word += str(word_symbols[index])
	if word.is_empty() or printed_word != word:
		failures.append("Word Hunt did not print its completed purchase-fixed word.")
	var second_ticket := _scratch_find_ticket(game, "second_chance", "second_chance")
	var second_result := _scratch_settle_fixture(game, second_ticket, "SECOND-CHANCE-GIMMICK")
	var second_machine := second_result.get("machine", {}) as Dictionary
	var free_ticket := second_machine.get("active_ticket", {}) as Dictionary
	if not bool(second_result.get("result", {}).get("scratch_second_chance_ticket", {}).get("free_ticket", false)) or str(free_ticket.get("type_id", "")) != "lucky_7s" or int(free_ticket.get("price", -1)) != 0:
		failures.append("Second Chance did not immediately dispense a free cheaper ticket.")
	var devil_ticket := _scratch_find_ticket(game, "devils_cut", "cut")
	var devil_result := _scratch_settle_fixture(game, devil_ticket, "DEVILS-CUT-GIMMICK")
	var devil_action := devil_result.get("result", {}) as Dictionary
	if int(devil_ticket.get("gross_payout", 0)) - int(devil_ticket.get("cut", 0)) != int(devil_ticket.get("payout", -1)) or not _scratch_test_ticket_symbols(devil_ticket).has("DEVIL") or int(devil_action.get("suspicion_delta", 0)) <= 0:
		failures.append("Devil's Cut did not apply its printed cut and clerk heat.")
	var rare_ticket := _scratch_find_ticket(game, "midnight_rare", "luck_buff")
	var rare_result := _scratch_settle_fixture(game, rare_ticket, "MIDNIGHT-RARE-GIMMICK")
	var rare_run: RunState = rare_result.get("run_state")
	var rare_bonus := int(rare_ticket.get("luck_buff", 0))
	if rare_bonus <= 0 or rare_run.effective_luck() != rare_bonus:
		failures.append("Midnight Rare did not add its temporary effective-luck bonus.")
	else:
		rare_run.advance_environment_turns(int(rare_ticket.get("luck_turns", 0)) + 1)
		if rare_run.effective_luck() != 0:
			failures.append("Midnight Rare temporary luck did not expire on schedule.")


func _check_scratch_ticket_items(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-ITEM-EFFECTS")
	run_state.bankroll = 5000
	for item_id in ["xray_glasses", "tarot_card", "lucky_penny"]:
		run_state.add_item(item_id)
	var environment := {"id": "scratch_items", "archetype_id": "gas_station_casino", "game_states": {}}
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_test_rng("scratch-item-stock"))
	machine["stock"] = [{"type_id": "lucky_7s", "display_name": "Lucky 7s", "price": 2, "remaining": 2, "stock_weight": 100, "palette": {}}]
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment.duplicate(true)
	var purchase: Dictionary = game.resolve_with_context("buy_scratch_ticket", 2, run_state, environment, _scratch_test_rng("scratch-item-purchase"), {"scratch_stock_index": 0})
	var ticket := purchase.get("scratch_ticket", {}) as Dictionary
	var cells := _scratch_test_dictionary_array(ticket.get("cells", []))
	var peeks := _scratch_test_dictionary_array(purchase.get("scratch_xray_peeks", []))
	if peeks.size() < 2 or peeks.size() > 3 or int(purchase.get("suspicion_delta", 0)) <= 0:
		failures.append("X-Ray Glasses did not peek 2-3 cells with surveillance heat.")
	for peek_value in peeks:
		var peek: Dictionary = peek_value
		var index := int(peek.get("index", -1))
		if index < 0 or index >= cells.size() or str(peek.get("symbol", "")) != str((cells[index] as Dictionary).get("symbol", "")):
			failures.append("X-Ray Glasses peek did not match the purchase-fixed rolled symbol.")
			break
	if str(purchase.get("scratch_fortune", "")) != str(game.call("_fortune_tier", ticket)):
		failures.append("Tarot Card fortune did not match the fixed outcome tier.")
	var shock_ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "high_voltage"), _scratch_test_rng("penny-shield"), 0, "penny")
	var shock_cells := _scratch_test_dictionary_array(shock_ticket.get("cells", []))
	for cell_value in shock_cells:
		var cell: Dictionary = cell_value
		cell["penalty"] = 0
		cell["penalty_queued"] = false
	shock_cells[0]["symbol"] = "SHOCK"
	shock_cells[0]["penalty"] = 3
	shock_cells[0]["penalty_shield_reserved"] = true
	shock_ticket["cells"] = shock_cells
	var shield_machine := {"active_ticket": shock_ticket, "pending_penalty": 0, "penalty_shields_remaining": 1}
	game.call("_reveal_all", shield_machine)
	if int(shield_machine.get("pending_penalty", -1)) != 0 or int(shield_machine.get("penalty_shields_remaining", -1)) != 0 or not bool((_scratch_test_dictionary_array((shield_machine.get("active_ticket", {}) as Dictionary).get("cells", []))[0] as Dictionary).get("penalty_shielded", false)):
		failures.append("Lucky Penny did not consume exactly one shield against a penalty symbol.")
	var fixed_ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "high_voltage"), _scratch_test_rng("penny-fixed-order"), 0, "fixed-order")
	var fixed_cells := _scratch_test_dictionary_array(fixed_ticket.get("cells", []))
	for index in range(fixed_cells.size()):
		var cell: Dictionary = fixed_cells[index]
		cell["revealed"] = index not in [0, fixed_cells.size() - 1]
		cell["mask"] = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
		cell["penalty"] = 0
		cell["penalty_queued"] = false
		cell["penalty_shield_reserved"] = false
	fixed_cells[0]["penalty"] = 3
	fixed_cells[0]["penalty_shield_reserved"] = true
	fixed_cells[fixed_cells.size() - 1]["penalty"] = 1
	fixed_ticket["cells"] = fixed_cells
	var forward_penalty := _scratch_penalty_for_order(game, fixed_ticket, [0, fixed_cells.size() - 1])
	var reverse_penalty := _scratch_penalty_for_order(game, fixed_ticket, [fixed_cells.size() - 1, 0])
	if forward_penalty != 1 or reverse_penalty != forward_penalty:
		failures.append("Lucky Penny penalty result changed with scratch order instead of staying fixed at purchase.")
	var penny := game.library.item("lucky_penny")
	if penny.is_empty() or not bool(penny.get("sellable", false)) or not FileAccess.file_exists(str(penny.get("asset_path", ""))):
		failures.append("Lucky Penny did not complete the sellable item/icon pipeline.")
	for archetype_id in ["corner_store", "pawn_shop"]:
		var archetype := _scratch_archetype(game.library, archetype_id)
		if not _scratch_test_string_array(archetype.get("item_pool", [])).has("lucky_penny"):
			failures.append("Lucky Penny was missing from %s shop stock." % archetype_id)


func _check_scratch_ticket_stock_and_collection(game: GameModule, failures: Array) -> void:
	var rare_appearances := 0
	var samples := 3000
	var rng := _scratch_test_rng("SCRATCH-STOCK-MASS")
	for _sample in range(samples):
		var ids: Array = []
		for ticket_value in _scratch_test_dictionary_array(game.call("_weighted_stock_types", rng, 4)):
			ids.append(str((ticket_value as Dictionary).get("id", "")))
		if ids.has("midnight_rare"):
			rare_appearances += 1
	var rare_rate := float(rare_appearances) / float(samples)
	if rare_rate < 0.005 or rare_rate > 0.050:
		failures.append("Midnight Rare weighted stock appearance %.4f missed rarity band [0.005, 0.050]." % rare_rate)
	var first_stock: Array = []
	var rotated := false
	for day in range(1, 7):
		var machine: Dictionary = game.call("_generate_machine_state", null, {"id": "day-rotation", "day": day}, null)
		var ids: Array = []
		for slot_value in _scratch_test_dictionary_array(machine.get("stock", [])):
			ids.append(str((slot_value as Dictionary).get("type_id", "")))
		if first_stock.is_empty():
			first_stock = ids
		elif ids != first_stock:
			rotated = true
	if not rotated:
		failures.append("Scratch Tickets day-keyed stock did not rotate across six days.")
	var profile: ProfileInventory = ProfileInventoryScript.new()
	profile.from_dict({"scratch_ticket_types_discovered": ["lucky_7s", "cash_cow", "lucky_7s"]})
	profile.discover_scratch_ticket_type("word_hunt")
	var restored: ProfileInventory = ProfileInventoryScript.new()
	restored.from_dict(profile.to_dict())
	if restored.scratch_ticket_discovery_count() != 3 or not restored.has_discovered_scratch_ticket_type("word_hunt") or int(restored.to_dict().get("schema_version", 0)) < 4:
		failures.append("Scratch-ticket discovered collection did not schema-version and round-trip its set.")
	var surface_run: RunState = RunStateScript.new()
	surface_run.start_new("SCRATCH-COLLECTION-SURFACE")
	surface_run.narrative_flags["scratch_ticket_types_discovered"] = restored.scratch_ticket_types_discovered.duplicate()
	var surface := game.surface_state(surface_run, {"id": "collection-surface", "game_states": {}}, {})
	if int(surface.get("scratch_collection_count", -1)) != 3 or int(surface.get("scratch_collection_total", -1)) != 10:
		failures.append("Scratch Tickets machine did not expose the profile collection count as 3/10.")


func _check_scratch_ticket_rtp(game: GameModule, failures: Array) -> void:
	for type_id in _scratch_ticket_type_ids():
		var metrics: Dictionary = game.call("measure_rtp", type_id, 20000, "FOUNDATION-RTP")
		var ticket_type: Dictionary = game.call("_ticket_type", type_id)
		var band: Array = ticket_type.get("rtp_band", [])
		var rtp := float(metrics.get("rtp", -1.0))
		if band.size() < 2 or rtp < float(band[0]) or rtp > float(band[1]):
			failures.append("Scratch Tickets %s RTP %.5f missed declared band %s." % [type_id, rtp, str(band)])


func _scratch_find_ticket(game: GameModule, type_id: String, field: String) -> Dictionary:
	for seed_index in range(2500):
		var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_test_rng("%s:%s:%d" % [type_id, field, seed_index]), 0, "fixture")
		var value: Variant = ticket.get(field)
		if (typeof(value) == TYPE_BOOL and bool(value)) or (typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) > 0.0) or (typeof(value) == TYPE_STRING and not str(value).is_empty()):
			return ticket
	return {}


func _scratch_settle_fixture(game: GameModule, ticket: Dictionary, seed_text: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 5000
	var machine := {"schema": "scratch_ticket_machine_state", "version": 1, "stock": [], "active_ticket": ticket.duplicate(true), "winner_pile": [], "loser_pile": [], "pending_penalty": 0, "penalty_shields_remaining": 0}
	game.call("_reveal_all", machine)
	var environment := {"id": seed_text.to_lower(), "archetype_id": "gas_station_casino", "game_states": {"scratch_tickets": machine}}
	run_state.current_environment = environment.duplicate(true)
	var result := game.resolve_with_context("settle_scratch_ticket", 0, run_state, environment, _scratch_test_rng("%s:resolve" % seed_text), {})
	return {"result": result, "machine": (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}), "run_state": run_state}


func _scratch_penalty_for_order(game: GameModule, ticket: Dictionary, order: Array) -> int:
	var machine := {"active_ticket": ticket.duplicate(true), "pending_penalty": 0, "penalty_shields_remaining": 1}
	var grid := ticket.get("grid", {}) as Dictionary
	var columns := int(grid.get("columns", 3))
	var rows := int(grid.get("rows", 3))
	for index_value in order:
		var index := int(index_value)
		var rect: Rect2 = game.call("_cell_rect", index, columns, rows)
		game.call("_scratch_segment", machine, Vector2(rect.position.x + 3.0, rect.get_center().y), Vector2(rect.end.x - 3.0, rect.get_center().y))
	return int(machine.get("pending_penalty", 0))


func _scratch_archetype(library: ContentLibrary, archetype_id: String) -> Dictionary:
	for archetype_value in _scratch_test_dictionary_array(library.environment_archetypes):
		var archetype: Dictionary = archetype_value
		if str(archetype.get("id", "")) == archetype_id:
			return archetype
	return {}


func _scratch_ticket_type_ids() -> Array:
	return ["lucky_7s", "cash_cow", "high_voltage", "gold_rush_doubler", "bonus_box", "word_hunt", "second_chance", "devils_cut", "fools_gold", "midnight_rare"]


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


func _scratch_test_string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		result.append(str(entry))
	return result


func _scratch_test_ticket_symbols(ticket: Dictionary) -> Array:
	var result: Array = []
	for cell_value in _scratch_test_dictionary_array(ticket.get("cells", [])):
		result.append(str((cell_value as Dictionary).get("symbol", "")))
	return result
