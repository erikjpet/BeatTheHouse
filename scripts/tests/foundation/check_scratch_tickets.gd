extends "res://scripts/tests/foundation/check_lenders_release_saves.gd"

const ScratchSfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
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
	_check_scratch_mechanics(game, failures)
	_check_scratch_mask_feel(game, failures)
	_check_scratch_section_sweeps(game, failures)
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
	var original_mask := (ticket.get("latex_mask", []) as Array).duplicate()
	var begin := game.surface_pointer_command("scratch_scrub", 0, "begin", Vector2(400, 160), {}, run_state, environment)
	game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(400, 160), begin.get("ui_state", {}), run_state, environment)
	if (ticket.get("latex_mask", []) as Array) != original_mask:
		failures.append("Scratch Tickets bare click changed the mask.")
	var drag_begin := game.surface_pointer_command("scratch_scrub", 0, "begin", Vector2(342, 190), {}, run_state, environment)
	var drag_move := game.surface_pointer_command("scratch_scrub", 0, "move", Vector2(560, 190), drag_begin.get("ui_state", {}), run_state, environment)
	if not bool(drag_move.get("surface_transient", false)) or str(drag_move.get("surface_audio_loop_start", "")) != "scratch_paper_foley_loop":
		failures.append("Scratch drag did not use its transient paper-foley route.")
	var drag_end := game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(560, 190), drag_move.get("ui_state", {}), run_state, environment)
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


func _check_scratch_section_sweeps(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_rng("sweep:%s" % type_id), 0, "sweep")
		var machine := {"active_ticket": ticket, "pending_penalty": 0, "penalty_shields_remaining": 0}
		var sections := _dict_array(ticket.get("sections", []))
		for section_index in range(sections.size()):
			_prime_section_just_below_sweep(game, ticket, section_index)
			var values: Array = (sections[section_index] as Dictionary).get("rect", [])
			var scratch_rect: Rect2 = game.call("_ticket_scratch_rect", ticket)
			var center := scratch_rect.position + Vector2(float(values[0]) + float(values[2]) * 0.5, float(values[1]) + float(values[3]) * 0.5) * scratch_rect.size
			var result: Dictionary = game.call("_scratch_segment", machine, center - Vector2(8, 0), center + Vector2(8, 0))
			if _dict_array(result.get("swept_sections", [])).is_empty() or not bool((sections[section_index] as Dictionary).get("revealed", false)):
				failures.append("Scratch section %s/%d did not auto-sweep at 80%%." % [type_id, section_index])
				break
			if float((sections[section_index] as Dictionary).get("coverage", 0.0)) != 1.0:
				failures.append("Scratch sweep did not clear the exact result-bearing section for %s." % type_id)
				break


func _prime_section_just_below_sweep(game: GameModule, ticket: Dictionary, section_index: int) -> void:
	var scratch: Dictionary = ticket.get("scratch", {})
	var columns := int(scratch.get("mask_columns", 48))
	var rows := int(scratch.get("mask_rows", 32))
	var mask: Array = ticket.get("latex_mask", [])
	var sections: Array = ticket.get("sections", [])
	var remaining := 0
	for sample_index in range(mask.size()):
		var normalized: Vector2 = game.call("_mask_sample_normalized", sample_index, columns, rows)
		if int(game.call("_section_index_at_normalized", sections, normalized)) == section_index:
			mask[sample_index] = 52
			remaining += 52
	var section: Dictionary = sections[section_index]
	section["mask_remaining_units"] = remaining
	section["coverage"] = 1.0 - float(remaining) / float(maxi(1, int(section.get("sample_total", 1)) * 255))
	sections[section_index] = section


func _check_scratch_save_restore(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-SAVE-MASK")
	var environment := _scratch_environment("scratch_save")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("save-stock"))
	var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "crossword_corner"), _scratch_rng("save-ticket"), 0, "save")
	machine["active_ticket"] = ticket
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	game.call("_scratch_segment", machine, Vector2(350, 170), Vector2(590, 250))
	var outcome_json := JSON.stringify(ticket.get("mechanic_result", {}))
	var mask_json := JSON.stringify(ticket.get("latex_mask", []))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var loaded: Dictionary = ((restored.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	if JSON.stringify(loaded.get("mechanic_result", {})) != outcome_json or JSON.stringify(loaded.get("latex_mask", [])) != mask_json:
		failures.append("Scratch save/load did not restore both fixed outcome and partial mask.")


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
	if archetype.is_empty() or not _string_array(archetype.get("required_game_ids", [])).has("scratch_tickets"):
		failures.append("Gas-station casinos no longer require Scratch Tickets.")


func _scratch_environment(environment_id: String) -> Dictionary:
	return {"id": environment_id, "world_node_id": environment_id, "display_name": "Roadside Gas", "archetype_id": "gas_station_casino", "kind": "casino", "game_ids": ["scratch_tickets"], "game_states": {}, "economic_profile": {"stake_floor": 1, "stake_ceiling": 100}, "visual_context": {"scene_type": "gas_station_casino"}}


func _scratch_rng(seed_text: String) -> RngStream:
	var rng: RngStream = RngStreamScript.new()
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


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value as Array:
			result.append(str(entry))
	return result
