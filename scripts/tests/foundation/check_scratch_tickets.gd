extends "res://scripts/tests/foundation/check_lenders_release_saves.gd"

const ScratchSfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const ScratchRngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SCRATCH_IDS := ["two_fer", "lucky_7s", "tic_tac_gold", "crossword_corner", "bonus_bingo", "high_roller_holdem", "golden_vault"]
const SCRATCH_PRICES := [2, 5, 10, 15, 20, 50, 100]
const SCRATCH_MECHANICS := ["match_two_of_three", "key_number_match", "tic_tac_toe", "crossword", "bingo", "beat_dealer_poker", "multi_game_vault"]
const SCRATCH_SECTION_COUNTS := [1, 2, 2, 2, 5, 3, 4]


func _check_scratch_tickets_surface_contract(game: GameModule, failures: Array) -> void:
	_check_scratch_gas_station_generation(failures)
	_check_scratch_roster(game, failures)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-TICKET-CONTRACT")
	run_state.bankroll = 500000
	var environment := _scratch_environment("scratch_contract_gas")
	var machine: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("scratch_stock"))
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	if str(machine.get("schema", "")) != "scratch_ticket_machine_state" or _dict_array(machine.get("stock", [])).size() != 4:
		failures.append("Scratch Tickets did not generate its four-slot machine state.")
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "scratch_tickets" or not bool(surface.get("surface_controls_native", false)):
		failures.append("Scratch Tickets did not route to its native surface.")
	if not bool(surface.get("surface_animates_idle", false)) or bool(surface.get("surface_realtime_state_refresh", true)):
		failures.append("Scratch Tickets idle liveness/zero-copy flags are incorrect.")
	if not bool(surface.get("surface_pointer_coalesce_moves", false)) or not game.surface_pointer_uses_lightweight_ui_state("scratch_scrub"):
		failures.append("Scratch Tickets did not retain coalesced lightweight pointer input.")
	if bool(surface.get("scratch_core_surface_scroll", true)) or str(surface.get("scratch_ui_mode", "")) != "machine_surface_split":
		failures.append("Scratch Tickets desktop UI lost its non-scrolling machine/surface split.")
	var compact_surface := game.surface_state(run_state, environment, {"surface_runtime_status": {"small_screen_mode": true}})
	if str(compact_surface.get("scratch_ui_mode", "")) != "compact_tabs" or bool(compact_surface.get("scratch_core_surface_scroll", true)):
		failures.append("Scratch Tickets small-screen UI did not compact without scrolling.")
	var compact_harness := SurfaceHarness.new()
	compact_harness.setup(compact_surface)
	game.draw_surface(compact_harness, compact_surface, {"contract_harness": true})
	if not _surface_harness_has_action(compact_harness, "scratch_compact_machine") or not _surface_harness_has_action(compact_harness, "scratch_compact_ticket"):
		failures.append("Scratch Tickets small-screen mode labels compact tabs without drawing both tab controls.")
	var art_features: Array = surface.get("scratch_machine_art_features", []) if typeof(surface.get("scratch_machine_art_features", [])) == TYPE_ARRAY else []
	for feature in ["floor_unit", "jackpot_marquee", "glass_stock_rows", "branded_side_panel", "selection_buttons", "dispensing_tray"]:
		if not art_features.has(feature):
			failures.append("Scratch vending-machine art contract is missing %s." % feature)
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if not _surface_harness_has_action(harness, "scratch_buy"):
		failures.append("Scratch Tickets machine exposed no spatial buy targets.")
	_check_scratch_purchase_and_input(game, run_state, environment, failures)
	_check_scratch_determinism(game, failures)
	_check_scratch_luck_hook(game, failures)
	_check_scratch_mechanics(game, failures)
	_check_scratch_mask_feel(game, failures)
	_check_scratch_per_box_reveals(game, failures)
	_check_scratch_result_and_queue_flow(game, failures)
	_check_scratch_save_restore(game, failures)
	_check_scratch_sizes(game, failures)
	_check_scratch_stock(game, failures)
	_check_scratch_rtp(game, failures)
	_check_scratch_sound(failures)
	_check_scratch_items(game, failures)
	_check_scratch_clerk(game, failures)
	_check_scratch_portable_state(game, failures)


func _check_scratch_roster(game: GameModule, failures: Array) -> void:
	var definitions := _dict_array(game.call("_ticket_types"))
	if definitions.size() != SCRATCH_IDS.size():
		failures.append("Scratch Tickets roster must contain exactly seven ticket types.")
		return
	for index in range(SCRATCH_IDS.size()):
		var definition: Dictionary = definitions[index]
		if str(definition.get("id", "")) != SCRATCH_IDS[index] or int(definition.get("price", 0)) != SCRATCH_PRICES[index]:
			failures.append("Scratch Tickets roster order/denomination drifted at index %d." % index)
		if str((definition.get("mechanic", {}) as Dictionary).get("type", "")) != SCRATCH_MECHANICS[index]:
			failures.append("Scratch Tickets %s lost its owner-approved mechanic." % SCRATCH_IDS[index])
		if _dict_array(definition.get("sections", [])).size() != SCRATCH_SECTION_COUNTS[index]:
			failures.append("Scratch Tickets %s has the wrong section count." % SCRATCH_IDS[index])
		for retired_id in ["cash_cow", "high_voltage", "gold_rush_doubler", "bonus_box", "word_hunt", "second_chance", "devils_cut", "fools_gold", "midnight_rare"]:
			if str(definition.get("id", "")) == retired_id:
				failures.append("Retired scratch type %s remains in the active roster." % retired_id)


func _check_scratch_purchase_and_input(game: GameModule, run_state: RunState, environment: Dictionary, failures: Array) -> void:
	var buy_command := game.surface_action_command("scratch_buy", 0, false, {}, run_state, environment)
	var before := run_state.bankroll
	var purchase := game.resolve_with_context("buy_scratch_ticket", int(buy_command.get("set_stake", 0)), run_state, environment, run_state.create_rng("scratch_purchase"), buy_command.get("ui_state", {}))
	if not bool(purchase.get("scratch_outcome_fixed_at_purchase", false)) or run_state.bankroll != before - int(purchase.get("stake", 0)):
		failures.append("Scratch Tickets purchase did not fix its outcome and charge cash once.")
	var ticket: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	game.call("_ensure_ticket_regions", ticket)
	var original_mask := (ticket.get("latex_mask", []) as Array).duplicate()
	var begin := game.surface_pointer_command("scratch_scrub", 0, "begin", Vector2(400, 160), {}, run_state, environment)
	game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(400, 160), begin.get("ui_state", {}), run_state, environment)
	if (ticket.get("latex_mask", []) as Array) != original_mask:
		failures.append("Scratch Tickets bare click changed the mask.")
	var active_scratch_rect: Rect2 = game.call("_ticket_scratch_rect", ticket)
	var drag_from := Vector2(active_scratch_rect.position.x + 10.0, active_scratch_rect.get_center().y)
	var drag_to := Vector2(active_scratch_rect.end.x - 10.0, active_scratch_rect.get_center().y)
	var drag_begin := game.surface_pointer_command("scratch_scrub", 0, "begin", drag_from, {}, run_state, environment)
	var drag_move := game.surface_pointer_command("scratch_scrub", 0, "move", drag_to, drag_begin.get("ui_state", {}), run_state, environment)
	if not bool(drag_move.get("surface_transient", false)) or str(drag_move.get("surface_audio_loop_start", "")) != "scratch_paper_foley_loop":
		failures.append("Scratch drag did not use its transient paper-foley route.")
	var drag_end := game.surface_pointer_command("scratch_scrub", 0, "end", drag_to, drag_move.get("ui_state", {}), run_state, environment)
	if str(drag_end.get("surface_audio_loop_stop", "")) != "scratch_paper_foley_loop":
		failures.append("Scratch pointer release did not stop the paper-foley loop.")
	var reduced := game.surface_state(run_state, environment, {"reduce_motion": true})
	if not bool(reduced.get("scratch_reduce_motion", false)) or not bool(reduced.get("scratch_all_available", false)):
		failures.append("Scratch Tickets did not expose its reduce-motion presentation path.")
	var active_harness := SurfaceHarness.new()
	active_harness.setup(reduced)
	game.draw_surface(active_harness, reduced, {"contract_harness": true})
	if not _surface_harness_has_action(active_harness, "scratch_all"):
		failures.append("Scratch Tickets active HUD did not expose Scratch All.")
	var leave_rect := Rect2(776, 22, 86, 34)
	for region_value in active_harness.hit_regions:
		var region: Dictionary = region_value
		var region_rect: Rect2 = region.get("rect", Rect2())
		if str(region.get("action", "")) == "scratch_all" and region_rect.intersects(leave_rect):
			failures.append("Scratch All overlaps the native Leave control.")
	var compact_active := game.surface_state(run_state, environment, {"surface_runtime_status": {"small_screen_mode": true}, "scratch_compact_tab": "ticket", "reduce_motion": true})
	var compact_active_harness := SurfaceHarness.new()
	compact_active_harness.setup(compact_active)
	game.draw_surface(compact_active_harness, compact_active, {"contract_harness": true})
	if not _surface_harness_has_action(compact_active_harness, "scratch_all") or _surface_harness_has_action(compact_active_harness, "scratch_buy"):
		failures.append("Scratch Tickets compact ticket tab did not isolate the scratch surface from machine buy rows.")


func _check_scratch_determinism(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var first: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_rng("fixed:%s" % type_id), 3, "fixed")
		var second: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_rng("fixed:%s" % type_id), 3, "fixed")
		if first != second:
			failures.append("Scratch purchase outcome was not deterministic for %s." % type_id)
		var outcome_json := JSON.stringify(first.get("mechanic_result", {}))
		var machine := {"active_ticket": first, "pending_penalty": 0, "penalty_shields_remaining": 0}
		game.call("_scratch_segment", machine, Vector2(350, 170), Vector2(610, 315))
		game.call("_scratch_segment", machine, Vector2(610, 315), Vector2(350, 170))
		if JSON.stringify(first.get("mechanic_result", {})) != outcome_json or int(game.call("_evaluate_mechanic", first)) != int(first.get("payout", -1)):
			failures.append("Scratch path/order altered the purchase-fixed %s result." % type_id)


func _check_scratch_luck_hook(game: GameModule, failures: Array) -> void:
	var definition: Dictionary = game.call("_ticket_type", "two_fer")
	var shifted := false
	for seed_index in range(256):
		var low: Dictionary = game.call("_weighted_prize", definition, _scratch_rng("luck-shift:%d" % seed_index), -20)
		var high: Dictionary = game.call("_weighted_prize", definition, _scratch_rng("luck-shift:%d" % seed_index), 20)
		if str(low.get("id", "")) != str(high.get("id", "")):
			shifted = true
			break
	if not shifted:
		failures.append("Scratch effective_luck no longer shifts the purchase-time prize roll.")


func _check_scratch_mechanics(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var definition: Dictionary = game.call("_ticket_type", type_id)
		var mechanic: Dictionary = definition.get("mechanic", {})
		for prize_value in _dict_array(definition.get("prize_table", [])):
			var prize: Dictionary = prize_value
			var content: Dictionary = game.call("_build_mechanic_content", str(mechanic.get("type", "")), mechanic, prize, _scratch_rng("mechanic:%s:%s" % [type_id, str(prize.get("id", ""))]))
			var fixture := {"mechanic": mechanic, "mechanic_result": content}
			if int(game.call("_evaluate_mechanic", fixture)) != int(prize.get("payout", -1)):
				failures.append("Scratch mechanic %s/%s did not compute its printed payout." % [type_id, str(prize.get("id", ""))])
	var lucky_def: Dictionary = game.call("_ticket_type", "lucky_7s")
	var lucky_mechanic: Dictionary = lucky_def.get("mechanic", {})
	var winning_seven := {"mechanic": lucky_mechanic, "mechanic_result": {"winning_numbers": [7, 22], "your_numbers": [{"number": 1, "prize": 2}, {"number": 3, "prize": 4}, {"number": 5, "prize": 6}, {"number": 8, "prize": 8}, {"number": 9, "prize": 10}, {"number": 11, "prize": 12}]}}
	if int(game.call("_evaluate_mechanic", winning_seven)) != 42:
		failures.append("Lucky 7s winning-number 7 did not win all six prizes.")
	var your_seven := {"mechanic": lucky_mechanic, "mechanic_result": {"winning_numbers": [12, 22], "your_numbers": [{"number": 7, "prize": 25}, {"number": 3, "prize": 99}]}}
	if int(game.call("_evaluate_mechanic", your_seven)) != 25:
		failures.append("Lucky 7s Your Number 7 did not auto-win independently.")
	_check_bingo_caller_integrity(game, failures)
	var holdem_definition: Dictionary = game.call("_ticket_type", "high_roller_holdem")
	var holdem_mechanic: Dictionary = holdem_definition.get("mechanic", {})
	var wild_content: Dictionary = game.call("_build_mechanic_content", "beat_dealer_poker", holdem_mechanic, {"payout": 500, "your_rank": "FLUSH", "dealer_rank": "STRAIGHT", "wild": true}, _scratch_rng("wild-upgrade"))
	var ranks: Array = holdem_mechanic.get("rank_order", [])
	if not bool(wild_content.get("wild", false)) or ranks.find(str(wild_content.get("your_rank", ""))) <= ranks.find(str(wild_content.get("base_your_rank", ""))):
		failures.append("High Roller Hold'em wild slot did not improve the player's printed hand.")
	var vault_definition: Dictionary = game.call("_ticket_type", "golden_vault")
	var vault_mechanic: Dictionary = vault_definition.get("mechanic", {})
	var multiplier_fixture := {"mechanic": vault_mechanic, "mechanic_result": {"multiplier": 5, "ladder": [{"match": true, "base_prize": 10, "payout": 50}], "gold_bar": false, "vault_win": false, "vault_payout": 0}}
	if int(game.call("_evaluate_mechanic", multiplier_fixture)) != 50:
		failures.append("Golden Vault multiplier did not multiply a matched ladder prize.")
	var gold_bar_fixture := {"mechanic": vault_mechanic, "mechanic_result": {"multiplier": 2, "ladder": [{"match": false, "base_prize": 3, "payout": 6}, {"match": false, "base_prize": 4, "payout": 8}], "gold_bar": true, "vault_win": false, "vault_payout": 0}}
	if int(game.call("_evaluate_mechanic", gold_bar_fixture)) != 14:
		failures.append("Golden Vault GOLD BAR did not win every ladder rung.")
	var vault_fixture := {"mechanic": vault_mechanic, "mechanic_result": {"multiplier": 2, "ladder": [], "gold_bar": false, "vault_win": true, "vault_payout": 900}}
	if int(game.call("_evaluate_mechanic", vault_fixture)) != 900:
		failures.append("Golden Vault final reveal did not pay its vault prize.")


func _check_bingo_caller_integrity(game: GameModule, failures: Array) -> void:
	var definition: Dictionary = game.call("_ticket_type", "bonus_bingo")
	var mechanic: Dictionary = definition.get("mechanic", {})
	for prize_value in _dict_array(definition.get("prize_table", [])):
		var prize: Dictionary = prize_value
		var content: Dictionary = game.call("_build_mechanic_content", "bingo", mechanic, prize, _scratch_rng("bingo-integrity:%s" % str(prize.get("id", ""))))
		var callers: Array = content.get("caller_numbers", [])
		if callers.size() != 24:
			failures.append("Bonus Bingo did not print exactly 24 caller numbers.")
			return
		for card_value in _dict_array(content.get("cards", [])):
			var card: Dictionary = card_value
			var numbers: Array = card.get("numbers", [])
			var daubed: Array = card.get("daubed", [])
			if numbers.size() != 25 or daubed.size() != 25:
				failures.append("Bonus Bingo card did not contain a full 5x5 grid.")
				return
			for cell_index in range(25):
				var expected_daub := cell_index == 12 or callers.has(int(numbers[cell_index]))
				if bool(daubed[cell_index]) != expected_daub:
					failures.append("Bonus Bingo daub state was not derived from its printed caller numbers.")
					return
			if int(card.get("completed_lines", -1)) != int(game.call("_bingo_completed_line_count", daubed)):
				failures.append("Bonus Bingo printed line count did not match its daubed grid.")
				return
			if bool(card.get("blackout", false)) and daubed.has(false):
				failures.append("Bonus Bingo blackout did not daub the full card.")
				return


func _check_scratch_mask_feel(game: GameModule, failures: Array) -> void:
	var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "two_fer"), _scratch_rng("feel"), 0, "feel")
	var machine := {"active_ticket": ticket, "pending_penalty": 0, "penalty_shields_remaining": 0}
	var rect: Rect2 = game.call("_ticket_scratch_rect", ticket)
	var scratch: Dictionary = ticket.get("scratch", {})
	if absf(float(scratch.get("pass_removal", 0.0)) - 0.66) > 0.001 or float(scratch.get("brush_radius", 99.0)) > 15.0:
		failures.append("Scratch feel tuning lost its 66% pass or compact brush.")
	var columns := int(scratch.get("mask_columns", 0))
	var rows := int(scratch.get("mask_rows", 0))
	var center_index := (rows / 2) * columns + columns / 2
	var center := rect.get_center()
	game.call("_scratch_segment", machine, center, center)
	var alpha_after_one := int((ticket.get("latex_mask", []) as Array)[center_index])
	if alpha_after_one < 82 or alpha_after_one > 92:
		failures.append("A scratch pass did not remove about two-thirds of remaining latex; alpha=%d." % alpha_after_one)
	if bool(game.call("_ticket_complete", ticket)):
		failures.append("One honest scratch point completed a ticket; multiple passes are required.")
	var fast := game.call("_scratch_segment", machine, Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y)) as Dictionary
	if int(fast.get("interpolated_dabs", 0)) < 8 or int(fast.get("erased_samples", 0)) < columns / 2:
		failures.append("Fast swipe interpolation skipped coverage samples.")


func _check_scratch_per_box_reveals(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_rng("sweep:%s" % type_id), 0, "sweep")
		var machine := {"active_ticket": ticket, "pending_penalty": 0, "penalty_shields_remaining": 0}
		var regions := _dict_array(ticket.get("scratch_regions", []))
		if regions.size() != _dict_array(ticket.get("spots", [])).size():
			failures.append("Scratch %s did not create one scratch region per printed spot." % type_id)
			continue
		for region_index in range(regions.size()):
			var values: Array = (regions[region_index] as Dictionary).get("rect", [])
			var art_rect: Array = (regions[region_index] as Dictionary).get("art_rect", [])
			if JSON.stringify(art_rect) != JSON.stringify(values):
				failures.append("Scratch %s region/art rectangle drifted at box %d." % [type_id, region_index])
				break
		var sample_indices := _scratch_representative_region_indices(regions)
		for region_index in sample_indices:
			_prime_region_just_below_pop(game, ticket, region_index)
			regions = _dict_array(ticket.get("scratch_regions", []))
			var sample_values: Array = (regions[region_index] as Dictionary).get("rect", [])
			var scratch_rect: Rect2 = game.call("_ticket_scratch_rect", ticket)
			var region: Dictionary = regions[region_index]
			if bool(region.get("revealed", false)) or float(region.get("coverage", 1.0)) >= 0.80:
				failures.append("Scratch box %s/%d popped before the 80%% threshold." % [type_id, region_index])
				break
			var center_y := scratch_rect.position.y + (float(sample_values[1]) + float(sample_values[3]) * 0.5) * scratch_rect.size.y
			var from_x := scratch_rect.position.x + (float(sample_values[0]) + float(sample_values[2]) * 0.15) * scratch_rect.size.x
			var to_x := scratch_rect.position.x + (float(sample_values[0]) + float(sample_values[2]) * 0.85) * scratch_rect.size.x
			var result: Dictionary = game.call("_scratch_segment", machine, Vector2(from_x, center_y), Vector2(to_x, center_y))
			regions = _dict_array(ticket.get("scratch_regions", []))
			if _dict_array(result.get("swept_regions", [])).is_empty() or not bool((regions[region_index] as Dictionary).get("revealed", false)):
				failures.append("Scratch box %s/%d did not pop at 80%%." % [type_id, region_index])
				break
			if float((regions[region_index] as Dictionary).get("coverage", 0.0)) != 1.0:
				failures.append("Scratch pop did not fully clear the exact symbol box for %s." % type_id)
				break


func _prime_region_just_below_pop(game: GameModule, ticket: Dictionary, region_index: int) -> void:
	var scratch: Dictionary = ticket.get("scratch", {})
	var columns := int(scratch.get("mask_columns", 48))
	var rows := int(scratch.get("mask_rows", 32))
	var mask: Array = ticket.get("latex_mask", [])
	var regions: Array = ticket.get("scratch_regions", [])
	var remaining := 0
	var values: Array = (regions[region_index] as Dictionary).get("rect", [])
	var left := float(values[0])
	var top := float(values[1])
	var right := minf(1.0, left + float(values[2]))
	var bottom := minf(1.0, top + float(values[3]))
	var column_start := clampi(int(ceil(left * float(columns) - 0.5)), 0, columns)
	var column_end := clampi(int(ceil(right * float(columns) - 0.5)), column_start, columns)
	var row_start := clampi(int(ceil(top * float(rows) - 0.5)), 0, rows)
	var row_end := clampi(int(ceil(bottom * float(rows) - 0.5)), row_start, rows)
	for row in range(row_start, row_end):
		var row_offset := row * columns
		for column in range(column_start, column_end):
			mask[row_offset + column] = 52
			remaining += 52
	var region: Dictionary = regions[region_index]
	region["mask_remaining_units"] = remaining
	region["coverage"] = 1.0 - float(remaining) / float(maxi(1, int(region.get("sample_total", 1)) * 255))
	region["revealed"] = false
	regions[region_index] = region
	ticket["sections"] = game.call("_sections_from_regions", regions)


func _scratch_representative_region_indices(regions: Array) -> Array:
	var result: Array = []
	if regions.is_empty():
		return result
	for candidate in [0, regions.size() / 2, regions.size() - 1]:
		var index := int(candidate)
		if not result.has(index):
			result.append(index)
	for index in range(regions.size()):
		var section_id := str((regions[index] as Dictionary).get("section_id", ""))
		var seen_section := false
		for selected in result:
			if str((regions[int(selected)] as Dictionary).get("section_id", "")) == section_id:
				seen_section = true
				break
		if not seen_section:
			result.append(index)
	return result


func _check_scratch_result_and_queue_flow(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-QUEUE-FLOW")
	run_state.bankroll = 500
	var environment := _scratch_environment("scratch_queue")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("queue-stock"))
	var stock := _dict_array(machine.get("stock", []))
	if stock.is_empty():
		failures.append("Scratch queue test could not create stocked machine.")
		return
	(stock[0] as Dictionary)["remaining"] = maxi(3, int((stock[0] as Dictionary).get("remaining", 0)))
	machine["stock"] = stock
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var before := run_state.bankroll
	var buy := game.surface_action_command("scratch_buy", 200, false, {}, run_state, environment)
	game.resolve_with_context("buy_scratch_ticket", int(buy.get("set_stake", 0)), run_state, environment, _scratch_rng("queue-buy"), buy.get("ui_state", {}))
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if run_state.bankroll != before - int((stock[0] as Dictionary).get("price", 1)) * 3:
		failures.append("Scratch multi-buy did not charge N times the ticket price.")
	if _dict_array(machine.get("pending_queue", [])).size() != 2 or (machine.get("active_ticket", {}) as Dictionary).is_empty():
		failures.append("Scratch multi-buy did not leave one active ticket plus a queued stack.")
	var first_id := str((machine.get("active_ticket", {}) as Dictionary).get("id", ""))
	game.surface_action_command("scratch_all", 0, false, {}, run_state, environment)
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var active: Dictionary = machine.get("active_ticket", {})
	if str(active.get("id", "")) != first_id or not bool(active.get("result_ready", false)):
		failures.append("Scratch All should enter result state without filing the ticket.")
	var surface := game.surface_state(run_state, environment, {"reduce_motion": true})
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if not _surface_harness_has_action(harness, "scratch_file_ticket"):
		failures.append("Scratch result state did not expose a click-to-file hit region.")
	if _surface_harness_label_contains(harness, "%") or _surface_harness_label_contains(harness, "COVERAGE"):
		failures.append("Scratch surface rendered a progress/coverage readout.")
	var file := game.surface_action_command("scratch_file_ticket", 0, false, {}, run_state, environment)
	game.resolve_with_context("settle_scratch_ticket", 0, run_state, environment, _scratch_rng("queue-file"), file.get("ui_state", {}))
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if _dict_array(machine.get("pending_queue", [])).size() != 1 or str((machine.get("active_ticket", {}) as Dictionary).get("id", "")) == first_id:
		failures.append("Scratch filing did not advance to the next queued ticket.")


func _check_scratch_save_restore(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-SAVE-MASK")
	var environment := _scratch_environment("scratch_save")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("save-stock"))
	var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "crossword_corner"), _scratch_rng("save-ticket"), 0, "save")
	machine["active_ticket"] = ticket
	machine["pending_queue"] = [
		game.call("_roll_ticket", game.call("_ticket_type", "two_fer"), _scratch_rng("save-queue-a"), 0, "save-queue-a"),
		game.call("_roll_ticket", game.call("_ticket_type", "lucky_7s"), _scratch_rng("save-queue-b"), 0, "save-queue-b"),
	]
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	game.call("_scratch_segment", machine, Vector2(350, 170), Vector2(590, 250))
	var outcome_json := JSON.stringify(ticket.get("mechanic_result", {}))
	var mask_json := JSON.stringify(ticket.get("latex_mask", []))
	var queue_json := JSON.stringify(machine.get("pending_queue", []))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var loaded: Dictionary = ((restored.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	var loaded_machine: Dictionary = (restored.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if JSON.stringify(loaded.get("mechanic_result", {})) != outcome_json or JSON.stringify(loaded.get("latex_mask", [])) != mask_json or JSON.stringify(loaded_machine.get("pending_queue", [])) != queue_json:
		failures.append("Scratch save/load did not restore fixed outcome, partial mask, and queued tickets.")


func _check_scratch_sizes(game: GameModule, failures: Array) -> void:
	var expected := {"two_fer": "small_rectangle", "lucky_7s": "medium_square", "tic_tac_gold": "medium_square", "crossword_corner": "large_rectangle", "bonus_bingo": "large_rectangle", "high_roller_holdem": "tall", "golden_vault": "tall"}
	var orientations := {"small_rectangle": "wide_short", "medium_square": "balanced", "large_rectangle": "wide_tall", "tall": "narrow_tall"}
	for type_id in expected:
		var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_rng("size:%s" % type_id), 0, "size")
		if str(ticket.get("size_id", "")) != str(expected[type_id]):
			failures.append("Scratch ticket %s has the wrong physical size." % type_id)
		if str(game.call("_size_orientation", str(expected[type_id]))) != str(orientations[expected[type_id]]):
			failures.append("Scratch size %s has the wrong orientation." % str(expected[type_id]))
		if game.has_method("_ticket_rect_for_size"):
			var rect: Rect2 = game.call("_ticket_rect_for_size", str(expected[type_id]), false)
			var small_rect: Rect2 = game.call("_ticket_rect_for_size", str(expected[type_id]), true)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or small_rect.end.x > 900.0 or small_rect.end.y > 430.0:
				failures.append("Scratch size %s does not fit both core surfaces." % str(expected[type_id]))


func _check_scratch_stock(game: GameModule, failures: Array) -> void:
	var first: Dictionary = game.call("_generate_machine_state", null, {"id": "stock", "day": 4}, _scratch_rng("stock-root"))
	var second: Dictionary = game.call("_generate_machine_state", null, {"id": "stock", "day": 4}, _scratch_rng("stock-root"))
	if first.get("stock", []) != second.get("stock", []):
		failures.append("Scratch stock was not deterministic for seed and day.")
	if str(first.get("stock_stream_key", "")) != "scratch-stock:stock:day:4" or str(first.get("stock_weighting", "")) != "inverse_price_without_replacement":
		failures.append("Scratch stock did not record its named day-keyed weighted fork.")
	var previous_weight := 1000000
	for type_id in SCRATCH_IDS:
		var definition: Dictionary = game.call("_ticket_type", type_id)
		var weight := int(definition.get("stock_weight", 0))
		if weight <= 0 or weight >= previous_weight:
			failures.append("Scratch stock weights are not strictly inverse to price at %s." % type_id)
		previous_weight = weight
	var appearances: Dictionary = {}
	for type_id in SCRATCH_IDS:
		appearances[type_id] = 0
	for sample in range(2500):
		var selected := game.call("_weighted_stock_types", _scratch_rng("stock-mass:%d" % sample), 4) as Array
		for definition_value in selected:
			var type_id := str((definition_value as Dictionary).get("id", ""))
			appearances[type_id] = int(appearances.get(type_id, 0)) + 1
	var previous_appearances := 1000000
	for type_id in SCRATCH_IDS:
		var count := int(appearances.get(type_id, 0))
		if count <= 0:
			failures.append("Scratch stock made %s impossible to find." % type_id)
		if count >= previous_appearances:
			failures.append("Scratch seeded stock rarity no longer rises with price at %s: %s" % [type_id, JSON.stringify(appearances)])
		previous_appearances = count
	if int(appearances.get("golden_vault", 0)) <= 0 or int(appearances.get("golden_vault", 0)) >= int(appearances.get("two_fer", 0)) / 4:
		failures.append("Scratch stock mass sample did not make the $100 vault a rare but possible find: %s" % JSON.stringify(appearances))
	var rotated := false
	for day in range(5, 11):
		var day_machine: Dictionary = game.call("_generate_machine_state", null, {"id": "stock", "day": day}, null)
		if day_machine.get("stock", []) != first.get("stock", []):
			rotated = true
			break
	if not rotated:
		failures.append("Scratch stock did not rotate across day-keyed streams.")


func _check_scratch_rtp(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var metrics: Dictionary = game.call("measure_rtp", type_id, 100000, "FOUNDATION-RTP")
		var definition: Dictionary = game.call("_ticket_type", type_id)
		var band: Array = definition.get("rtp_band", [])
		var rtp := float(metrics.get("rtp", -1.0))
		if band.size() != 2 or rtp < float(band[0]) or rtp > float(band[1]):
			failures.append("Scratch RTP %s %.4f fell outside %s." % [type_id, rtp, JSON.stringify(band)])


func _check_scratch_sound(failures: Array) -> void:
	var sfx := ScratchSfxPlayerScript.new()
	var stream: AudioStreamWAV = sfx.preview_event_stream("scratch_paper_foley_loop")
	if stream == null or stream.loop_mode != AudioStreamWAV.LOOP_FORWARD or sfx.debug_normalized_event_id("scratch_paper_foley_loop") != "scratch_paper_foley_loop":
		failures.append("Scratch paper foley is not routed as the active procedural loop.")
	var pop_stream: AudioStreamWAV = sfx.preview_event_stream("scratch_box_pop")
	if pop_stream == null or pop_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED or sfx.debug_normalized_event_id("scratch_box_pop") != "scratch_box_pop":
		failures.append("Scratch per-box pop is not routed as a one-shot procedural cue.")
	var source := FileAccess.get_file_as_string("res://scripts/ui/sfx_player.gd")
	if source.contains("scratch_scrape_loop") or source.contains("coin_edge") or source.contains("_sample_scratch_scrape"):
		failures.append("Retired metallic scratch synthesis remains in the SFX source.")


func _check_scratch_items(game: GameModule, failures: Array) -> void:
	var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "lucky_7s"), _scratch_rng("items"), 0, "items")
	var peeks := game.call("_xray_peeks", ticket, 3, _scratch_rng("xray")) as Array
	if peeks.size() != 3 or str((peeks[0] as Dictionary).get("symbol", "")).is_empty():
		failures.append("X-ray item no longer exposes purchase-fixed scratch content.")
	var before := float((ticket.get("scratch", {}) as Dictionary).get("sweep_threshold", 0.80))
	game.call("_reserve_penalty_shields", ticket, 2)
	if float((ticket.get("scratch", {}) as Dictionary).get("sweep_threshold", 0.80)) >= before:
		failures.append("Lucky Penny no longer provides a presentation-only scratch assist.")
	if str(game.call("_fortune_tier", ticket)).is_empty():
		failures.append("Tarot scratch fortune hint no longer reads fixed outcomes.")


func _check_scratch_clerk(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-CLERK")
	run_state.bankroll = 100
	var environment := _scratch_environment("scratch_clerk")
	var winner: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "golden_vault"), _scratch_rng("clerk-ticket"), 0, "clerk")
	winner["payout"] = 500
	winner["settled"] = true
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("clerk-stock"))
	machine["winner_pile"] = [winner]
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var before := run_state.bankroll
	var command: Dictionary = game.environment_action_command("scratch_ticket_clerk", "redeem_scratch_winners", run_state, environment, _scratch_rng("clerk-redeem"))
	var result: Dictionary = command.get("result", {})
	if run_state.bankroll != before + 500 or int(result.get("suspicion_delta", 0)) <= 0:
		failures.append("Scratch clerk did not cash a conspicuous winner with attention heat.")


func _check_scratch_portable_state(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-PORTABLE")
	run_state.bankroll = 500
	var environment := _scratch_environment("scratch_portable")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("portable-stock"))
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var buy := game.surface_action_command("scratch_buy", 0, false, {}, run_state, environment)
	game.resolve_with_context("buy_scratch_ticket", int(buy.get("set_stake", 0)), run_state, environment, _scratch_rng("portable-buy"), buy.get("ui_state", {}))
	if not run_state.inventory.has(RunState.SCRATCH_TICKET_PILE_ITEM_ID):
		failures.append("Scratch purchase did not retain the portable ticket-pile flow.")
	var ticket: Dictionary = run_state.portable_ticket_state("scratch_tickets", environment).get("active_ticket", {})
	if str(ticket.get("origin_key", "")).is_empty() or not bool(ticket.get("outcome_fixed_at_purchase", false)):
		failures.append("Portable scratch ticket lost its origin or fixed outcome.")


func _check_scratch_gas_station_generation(failures: Array) -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var archetype := library.environment_archetype("gas_station_casino")
	if archetype.is_empty() or not _scratch_string_array(archetype.get("required_game_ids", [])).has("scratch_tickets"):
		failures.append("Gas-station casinos no longer require Scratch Tickets.")


func _scratch_environment(environment_id: String) -> Dictionary:
	return {"id": environment_id, "world_node_id": environment_id, "display_name": "Roadside Gas", "archetype_id": "gas_station_casino", "kind": "casino", "game_ids": ["scratch_tickets"], "game_states": {}, "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "visual_context": {"scene_type": "gas_station_casino"}}


func _scratch_rng(seed_text: String) -> RngStream:
	var rng: RngStream = ScratchRngStreamScript.new()
	var seed := RunState.text_to_seed(seed_text)
	rng.configure(seed, seed)
	return rng


func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			if typeof(entry) == TYPE_DICTIONARY:
				result.append(entry)
	return result


func _scratch_string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _surface_harness_label_contains(harness: SurfaceHarness, needle: String) -> bool:
	for label_value in harness.labels:
		if str(label_value).contains(needle):
			return true
	return false
