extends "res://scripts/tests/foundation/check_lenders_release_saves.gd"

const ScratchSfxPlayerScript := preload("res://scripts/ui/sfx_player.gd")
const ScratchRngStreamScript := preload("res://scripts/core/rng_stream.gd")
const ScratchRegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")
const SCRATCH_IDS := ["two_fer", "lucky_7s", "tic_tac_gold", "crossword_corner", "bonus_bingo", "high_roller_holdem", "golden_vault"]
const SCRATCH_PRICES := [2, 5, 10, 15, 20, 50, 100]
const SCRATCH_MECHANICS := ["match_two_of_three", "key_number_match", "tic_tac_toe", "crossword", "bingo", "beat_dealer_poker", "multi_game_vault"]
const SCRATCH_SECTION_COUNTS := [1, 2, 2, 2, 5, 3, 4]


func _check_scratch_tickets_surface_contract(game: GameModule, failures: Array) -> void:
	_check_scratch_measured_region_data(failures)
	_check_scratch_gas_station_generation(failures)
	_check_scratch_roster(game, failures)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-TICKET-CONTRACT")
	run_state.bankroll = 500000
	var environment := _scratch_environment("scratch_contract_gas")
	var machine: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("scratch_stock"))
	_ensure_stock_for_quantity(machine, 1)
	machine["scalper_visit_token"] = game.call("_scratch_visit_token", run_state, environment)
	machine["scalper_present"] = false
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	if str(machine.get("schema", "")) != "scratch_ticket_machine_state" or _dict_array(machine.get("stock", [])).size() != SCRATCH_IDS.size():
		failures.append("Scratch Tickets did not generate its scarce seven-ticket machine state.")
	var surface := game.surface_state(run_state, environment, {})
	if str(surface.get("surface_renderer", "")) != "scratch_tickets" or not bool(surface.get("surface_controls_native", false)):
		failures.append("Scratch Tickets did not route to its native surface.")
	if not bool(surface.get("surface_animates_idle", false)) or bool(surface.get("surface_realtime_state_refresh", true)):
		failures.append("Scratch Tickets idle liveness/zero-copy flags are incorrect.")
	var cash_hooks := game.environment_interactable_objects(run_state, environment)
	var scratch_cash_in_found := false
	for hook_value in cash_hooks:
		if typeof(hook_value) != TYPE_DICTIONARY:
			continue
		for action_value in (hook_value as Dictionary).get("available_actions", []):
			if typeof(action_value) == TYPE_DICTIONARY and str((action_value as Dictionary).get("label", "")) == "Cash In":
				scratch_cash_in_found = true
	if not scratch_cash_in_found:
		failures.append("Scratch Tickets redemption control did not use the Cash In label.")
	if not bool(surface.get("surface_pointer_coalesce_moves", false)) or not game.surface_pointer_uses_lightweight_ui_state("scratch_scrub"):
		failures.append("Scratch Tickets did not retain coalesced lightweight pointer input.")
	var main_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	if not main_source.contains('var notify_coach := phase != "move"') \
			or not main_source.contains("_guard_player_input_route(false, action, notify_coach)") \
			or not main_source.contains("_apply_game_surface_command(command, index, false, notify_coach, true)") \
			or not main_source.contains('not input_route_guarded and _guard_player_input_route(false, "ui:any", notify_coach)') \
			or not main_source.contains("if notify_coach:"):
		failures.append("Coalesced Scratch pointer moves no longer retain one trusted modal/closing guard while reserving coach action notification for begin/end boundaries.")
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
	_check_scratch_render_layers(game, failures)
	_check_scratch_instance_uniqueness(game, failures)
	_check_crossword_procedural_generation(game, failures)
	_check_scratch_shared_card_renderer(failures)
	_check_scratch_pre_reveal_privacy(game, failures)
	_check_scratch_determinism(game, failures)
	_check_scratch_luck_hook(game, failures)
	_check_scratch_mechanics(game, failures)
	_check_scratch_mask_feel(game, failures)
	_check_scratch_per_box_reveals(game, failures)
	_check_scratch_result_and_queue_flow(game, failures)
	_check_scratch_discard_flow(game, failures)
	_check_scratch_save_restore(game, failures)
	_check_scratch_stale_region_upgrade(game, failures)
	_check_scratch_sizes(game, failures)
	_check_scratch_stock(game, failures)
	_check_scratch_restock(game, failures)
	_check_scratch_scalper(game, failures)
	_check_scratch_collection_completion(game, failures)
	_check_scratch_single_remaining_purchase(game, failures)
	_check_scratch_rtp(game, failures)
	_check_scratch_sound(failures)
	_check_scratch_items(game, failures)
	_check_scratch_clerk(game, failures)
	_check_scratch_portable_state(game, failures)


func _check_scratch_measured_region_data(failures: Array) -> void:
	var data_path := "res://data/games/scratch_ticket_regions.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Scratch measured region source of truth is missing or invalid.")
		return
	var data: Dictionary = parsed
	if int(data.get("layout_version", 0)) != ScratchRegionModelScript.LAYOUT_VERSION:
		failures.append("Scratch measured region data does not match the runtime layout version.")
	var source_art: Dictionary = data.get("source_art", {}) if typeof(data.get("source_art", {})) == TYPE_DICTIONARY else {}
	var region_tables: Dictionary = data.get("regions", {}) if typeof(data.get("regions", {})) == TYPE_DICTIONARY else {}
	var alignment_status: Dictionary = data.get("alignment_status", {}) if typeof(data.get("alignment_status", {})) == TYPE_DICTIONARY else {}
	if str(alignment_status.get("crossword_corner", "")) != "measured_procedural" or _dict_array(region_tables.get("crossword_corner", [])).size() != 45:
		failures.append("Crossword Corner does not use its measured 18-letter/27-cell procedural layout table.")
	for type_id in SCRATCH_IDS:
		var source: Dictionary = source_art.get(type_id, {}) if typeof(source_art.get(type_id, {})) == TYPE_DICTIONARY else {}
		var art_path := "res://assets/art/scratch_tickets/layers/%s" % str(source.get("file", ""))
		if str(source.get("sha256", "")) != FileAccess.get_sha256(art_path):
			failures.append("Scratch %s source art changed without regenerating measured regions." % type_id)
		var art_size := Vector2(float(source.get("w", 0)), float(source.get("h", 0)))
		var frame := ScratchRegionModelScript.art_frame(Rect2(Vector2.ZERO, Vector2(548, 356)), art_size)
		if art_size.x <= 0.0 or art_size.y <= 0.0 or absf(frame.size.aspect() / art_size.aspect() - 1.0) > 0.005:
			failures.append("Scratch %s art frame does not preserve source aspect within 0.5%%." % type_id)
		if _dict_array(region_tables.get(type_id, [])).is_empty():
			failures.append("Scratch %s has no measured per-well region table." % type_id)


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
	var buy_index := _first_stocked_scratch_index((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}))
	if buy_index < 0:
		failures.append("Scratch purchase contract generated no stocked ticket rows.")
		return
	var buy_command := game.surface_action_command("scratch_buy", buy_index, false, {}, run_state, environment)
	var before := run_state.bankroll
	var purchase := game.resolve_with_context("buy_scratch_ticket", int(buy_command.get("set_stake", 0)), run_state, environment, run_state.create_rng("scratch_purchase"), buy_command.get("ui_state", {}))
	if not bool(purchase.get("scratch_outcome_fixed_at_purchase", false)) or run_state.bankroll != before - int(purchase.get("stake", 0)):
		failures.append("Scratch Tickets purchase did not fix its outcome and charge cash once.")
	if not bool(purchase.get("suppress_music_outcome", false)):
		failures.append("Scratch ticket purchase exposed its hidden outcome to the win/loss music system.")
	if str(purchase.get("surface_audio_cue", "")) != "ticket_dispenser" or str((purchase.get("surface_audio_context", {}) as Dictionary).get("action", "")) != "scratch_buy":
		failures.append("Scratch ticket purchase did not emit the successful dispense cue.")
	var result_ticket: Dictionary = purchase.get("scratch_ticket", {}) if typeof(purchase.get("scratch_ticket", {})) == TYPE_DICTIONARY else {}
	if result_ticket.has("latex_mask") or result_ticket.has("scratch_regions"):
		failures.append("Scratch ticket purchase duplicated its live foil mask into the action result.")
	var ticket: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	var initial_scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var initial_mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	if initial_mask.size() != int(initial_scratch.get("mask_columns", 0)) * int(initial_scratch.get("mask_rows", 0)) or _dict_array(ticket.get("scratch_regions", [])).is_empty():
		failures.append("A newly purchased scratch ticket deferred its foil mask until the first drag.")
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
	if drag_move.has("message"):
		failures.append("Ordinary Scratch pointer movement still routed a non-visible global status update through the hot path.")
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


func _check_scratch_render_layers(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("SCRATCH-LAYERS-%s" % type_id)
		run_state.bankroll = 500000
		var environment := _scratch_environment("scratch_layers_%s" % type_id)
		var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", type_id), _scratch_rng("layers:%s" % type_id), 1, "layers")
		game.call("_ensure_ticket_regions", ticket)
		environment["game_states"] = {"scratch_tickets": {"schema": "scratch_ticket_machine_state", "stock": [], "pending_queue": [], "winner_pile": [], "loser_pile": [], "active_ticket": ticket}}
		run_state.current_environment = environment
		var surface := game.surface_state(run_state, environment, {})
		var layers := _scratch_string_array(surface.get("scratch_ticket_render_layers", []))
		if layers != ["background", "icons", "foil"]:
			failures.append("Scratch %s render layers must be exactly background, icons, foil; got %s." % [type_id, JSON.stringify(layers)])
		if str(surface.get("scratch_foil_style_id", "")).is_empty():
			failures.append("Scratch %s did not expose a ticket-specific foil style." % type_id)
		if str(surface.get("scratch_mask_kind", "")) != "continuous_high_resolution":
			failures.append("Scratch %s did not expose the continuous high-resolution mask." % type_id)
		var harness := SurfaceHarness.new()
		harness.setup(surface)
		if not game.draw_surface(harness, surface, {"contract_harness": true}):
			failures.append("Scratch %s production render failed in the surface harness." % type_id)
		for layer_count in [1, 2, 3]:
			var isolated_harness := SurfaceHarness.new()
			isolated_harness.setup(surface)
			if not game.draw_surface(isolated_harness, surface, {"contract_harness": true, "scratch_layer_count": layer_count}):
				failures.append("Scratch %s layer-isolation render %d failed." % [type_id, layer_count])


func _check_scratch_instance_uniqueness(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var definition: Dictionary = game.call("_ticket_type", type_id)
		var mechanic: Dictionary = definition.get("mechanic", {})
		var table := _dict_array(definition.get("prize_table", []))
		if table.is_empty():
			failures.append("Scratch %s has no prize row for uniqueness proof." % type_id)
			continue
		var prize: Dictionary = table.back()
		var signatures: Dictionary = {}
		for instance_index in range(5):
			var content: Dictionary = game.call("_build_mechanic_content", str(mechanic.get("type", "")), mechanic, prize, _scratch_rng("same-payout:%s:%d" % [type_id, instance_index]))
			var fixture := {"mechanic": mechanic, "mechanic_result": content}
			if int(game.call("_evaluate_mechanic", fixture)) != int(prize.get("payout", -1)):
				failures.append("Scratch %s uniqueness instance %d did not preserve the selected payout." % [type_id, instance_index])
			signatures[JSON.stringify(content)] = true
		if signatures.size() < 3:
			failures.append("Scratch %s same-payout generation produced only %d visibly distinct results across five seeded instances." % [type_id, signatures.size()])


func _check_crossword_procedural_generation(game: GameModule, failures: Array) -> void:
	var definition: Dictionary = game.call("_ticket_type", "crossword_corner")
	var mechanic: Dictionary = definition.get("mechanic", {}) if typeof(definition.get("mechanic", {})) == TYPE_DICTIONARY else {}
	if str(mechanic.get("puzzle_generation", "")) != "procedural_unique_v1" or int(mechanic.get("unique_puzzle_cycle", 0)) < 100:
		failures.append("Crossword Corner does not declare its procedural per-ticket puzzle contract.")
		return
	var prize_table := _dict_array(definition.get("prize_table", []))
	var puzzle_ids := {}
	var word_signatures := {}
	for ticket_index in range(100):
		var prize: Dictionary = prize_table[ticket_index % prize_table.size()]
		var content: Dictionary = game.call("_build_mechanic_content", "crossword", mechanic, prize, _scratch_rng("crossword-unique:%d" % ticket_index), "practice_crossword:%d" % (ticket_index + 1))
		var puzzle_id := str(content.get("puzzle_id", ""))
		var words: Array = content.get("words", []) if typeof(content.get("words", [])) == TYPE_ARRAY else []
		var bank: Array = content.get("letter_bank", []) if typeof(content.get("letter_bank", [])) == TYPE_ARRAY else []
		var layout := _dict_array(content.get("crossword_layout", []))
		var spots := _dict_array(content.get("spots", []))
		if puzzle_id.is_empty() or words.size() != 7 or bank.size() != 18 or layout.size() != 7 or spots.size() != 45:
			failures.append("Crossword procedural ticket %d did not print one complete 7-word/18-letter puzzle." % ticket_index)
			return
		puzzle_ids[puzzle_id] = true
		word_signatures[JSON.stringify(words)] = true
		var actual_completed: Array = []
		for word_value in words:
			var word := str(word_value)
			var complete := true
			for letter_index in range(word.length()):
				if not bank.has(word.substr(letter_index, 1)):
					complete = false
					break
			if complete:
				actual_completed.append(word)
		if actual_completed.size() != int(prize.get("word_count", -1)) or actual_completed.size() != int(content.get("word_count", -1)):
			failures.append("Crossword procedural ticket %d letter bank completed %d words instead of exactly %d." % [ticket_index, actual_completed.size(), int(prize.get("word_count", -1))])
			return
		var cell_letters := {}
		for spot in spots:
			if str(spot.get("section_id", "")) == "crossword":
				cell_letters["%d,%d" % [int(spot.get("column", -1)), int(spot.get("row", -1))]] = str(spot.get("letter", ""))
		for entry in layout:
			var word := str(entry.get("word", ""))
			var across := str(entry.get("dir", "")) == "across"
			for letter_index in range(word.length()):
				var column := int(entry.get("x", 0)) + (letter_index if across else 0)
				var row := int(entry.get("y", 0)) + (0 if across else letter_index)
				if str(cell_letters.get("%d,%d" % [column, row], "")) != word.substr(letter_index, 1):
					failures.append("Crossword procedural ticket %d printed grid disagrees with word %s." % [ticket_index, word])
					return
		var fixture := {"mechanic": mechanic, "mechanic_result": content}
		if int(game.call("_evaluate_mechanic", fixture)) != int(prize.get("payout", -1)):
			failures.append("Crossword procedural ticket %d changed its authored payout." % ticket_index)
			return
	if puzzle_ids.size() != 100 or word_signatures.size() != 100:
		failures.append("Crossword Corner repeated a puzzle within 100 sequential ticket generations: ids=%d words=%d." % [puzzle_ids.size(), word_signatures.size()])
		return
	var rendered_ticket: Dictionary = game.call("_roll_ticket", definition, _scratch_rng("crossword-region-reconcile"), 0, "practice_crossword:101")
	var rendered_spots := _dict_array(rendered_ticket.get("spots", []))
	var rendered_regions := _dict_array(rendered_ticket.get("scratch_regions", []))
	if rendered_regions.size() != rendered_spots.size():
		failures.append("Crossword procedural ticket printed/scratch region counts do not reconcile.")
		return
	for region_index in range(rendered_regions.size()):
		var region: Dictionary = rendered_regions[region_index]
		var spot_index := int(region.get("spot_index", -1))
		if spot_index < 0 or spot_index >= rendered_spots.size() or str(region.get("section_id", "")) != str((rendered_spots[spot_index] as Dictionary).get("section_id", "")):
			failures.append("Crossword procedural ticket region %d does not cover its printed mechanic cell." % region_index)
			return


func _check_scratch_shared_card_renderer(failures: Array) -> void:
	var shared_path := "res://scripts/games/playing_card_renderer.gd"
	var shared_source := FileAccess.get_file_as_string(shared_path)
	if shared_source.is_empty() or shared_source.find("class_name PlayingCardRenderer") == -1:
		failures.append("Scratch card fidelity has no shared PlayingCardRenderer.")
		return
	for path in [
		"res://scripts/games/blackjack.gd",
		"res://scripts/games/baccarat.gd",
		"res://scripts/games/video_poker_renderer.gd",
		"res://scripts/games/scratch_ticket_icon_renderer.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		if source.find("playing_card_renderer.gd") == -1 or source.find("PlayingCardRendererScript.draw_card") == -1:
			failures.append("%s does not reuse the shared table-game card renderer." % path)


func _check_scratch_pre_reveal_privacy(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-PRE-REVEAL-PRIVACY")
	run_state.bankroll = 500000
	var environment := _scratch_environment("scratch_pre_reveal_privacy")
	var ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "two_fer"), _scratch_rng("pre-reveal-privacy"), 0, "privacy")
	ticket["xray_peeks"] = game.call("_xray_peeks", ticket, 3, _scratch_rng("pre-reveal-xray"))
	ticket["fortune_tier"] = game.call("_fortune_tier", ticket)
	environment["game_states"] = {"scratch_tickets": {"schema": "scratch_ticket_machine_state", "stock": [], "pending_queue": [], "winner_pile": [], "loser_pile": [], "active_ticket": ticket}}
	run_state.current_environment = environment
	var surface := game.surface_state(run_state, environment, {})
	if bool(surface.get("scratch_result_ready", true)) or not str(surface.get("scratch_result_summary", "")).is_empty() or not str(surface.get("scratch_result_reason", "")).is_empty():
		failures.append("Scratch surface exposed result text before the ticket was fully scratched.")
	if not _dict_array(surface.get("scratch_xray_peeks", [])).is_empty() or not str(surface.get("scratch_fortune", "")).is_empty():
		failures.append("Scratch surface exposed item-derived spoiler hints before the ticket was fully scratched.")
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if _surface_harness_label_contains(harness, "X-RAY") or _surface_harness_label_contains(harness, "TAROT"):
		failures.append("Scratch ticket drew a pre-reveal spoiler hint box on the ticket face.")
	game.surface_action_command("scratch_all", 0, false, {}, run_state, environment)
	var revealed := game.surface_state(run_state, environment, {})
	if not bool(revealed.get("scratch_result_ready", false)) or str(revealed.get("scratch_result_summary", "")).is_empty() or str(revealed.get("scratch_result_reason", "")).is_empty():
		failures.append("Scratch surface did not restore result text after the ticket was fully scratched.")


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
	if columns < 192 or rows < 128 or str(scratch.get("mask_kind", "")) != "continuous_high_resolution":
		failures.append("Scratch mask remained coarse at %dx%d instead of using a continuous high-resolution mask." % [columns, rows])
	var center_index := (rows / 2) * columns + columns / 2
	var center := rect.get_center()
	game.call("_scratch_segment", machine, center, center)
	var alpha_after_one := int((ticket.get("latex_mask", []) as Array)[center_index])
	if alpha_after_one != 0:
		failures.append("A scratch pass did not lift the core of the foil cleanly; alpha=%d." % alpha_after_one)
	var feather_row := clampi(roundi((center.y + 12.0 - rect.position.y) / rect.size.y * rows), 0, rows - 1)
	var feather_alpha := int((ticket.get("latex_mask", []) as Array)[feather_row * columns + columns / 2])
	if feather_alpha <= 0 or feather_alpha >= 255:
		failures.append("The scratch brush lost its soft feathered edge; alpha=%d." % feather_alpha)
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
			var expected := ScratchRegionModelScript.inset_rect(art_rect, ScratchRegionModelScript.MECHANIC_INSET_CELLS / ScratchRegionModelScript.MASK_COLUMNS, ScratchRegionModelScript.MECHANIC_INSET_CELLS / ScratchRegionModelScript.MASK_ROWS)
			if not _scratch_rect_values_equal(values, expected):
				failures.append("Scratch %s box %d mechanic rectangle is not the declared bounded inset of art_rect." % [type_id, region_index])
				break
			if type_id == "bonus_bingo" and region_index < 24 and str((regions[region_index] as Dictionary).get("mask_shape", "")) != "ellipse":
				failures.append("Scratch Bonus Bingo caller %d did not preserve its measured circular foil shape." % region_index)
				break
		var sample_indices := _scratch_representative_region_indices(regions)
		for region_index in sample_indices:
			_prime_region_just_below_pop(game, ticket, region_index)
			regions = _dict_array(ticket.get("scratch_regions", []))
			var sample_values: Array = (regions[region_index] as Dictionary).get("art_rect", [])
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
	var values: Array = (regions[region_index] as Dictionary).get("art_rect", [])
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
	var queue_index := _ensure_stock_for_quantity((environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}), 3)
	if queue_index < 0:
		failures.append("Scratch queue test could not find or create a stocked row.")
		return
	var expected_price := int((stock[queue_index] as Dictionary).get("price", 1))
	var buy := game.surface_action_command("scratch_buy", queue_index + 200, false, {}, run_state, environment)
	game.resolve_with_context("buy_scratch_ticket", int(buy.get("set_stake", 0)), run_state, environment, _scratch_rng("queue-buy"), buy.get("ui_state", {}))
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if run_state.bankroll != before - expected_price * 3:
		failures.append("Scratch multi-buy did not charge N times the ticket price.")
	if _dict_array(machine.get("pending_queue", [])).size() != 2 or (machine.get("active_ticket", {}) as Dictionary).is_empty():
		failures.append("Scratch multi-buy did not leave one active ticket plus a queued stack.")
	var first_id := str((machine.get("active_ticket", {}) as Dictionary).get("id", ""))
	var scratch_all_command := game.surface_action_command("scratch_all", 0, false, {}, run_state, environment)
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var active: Dictionary = machine.get("active_ticket", {})
	if str(active.get("id", "")) != first_id or not bool(active.get("result_ready", false)):
		failures.append("Scratch All should enter result state without filing the ticket.")
	var surface := game.surface_state(run_state, environment, {"reduce_motion": true})
	var first_payout := int(active.get("payout", 0))
	var expected_pile := "winner_pile" if first_payout > 0 else "loser_pile"
	if str(surface.get("scratch_result_summary", "")).is_empty() or str(surface.get("scratch_result_reason", "")).is_empty():
		failures.append("Scratch completion did not showcase the purchase-fixed result before filing.")
	if first_payout > 0 and int(surface.get("scratch_current_winnings", 0)) < first_payout:
		failures.append("Scratch completion did not include the active win in the visible amount due.")
	var expected_reveal_cue := "ticket_win" if first_payout > 0 else "scratch_box_pop"
	if str(scratch_all_command.get("surface_audio_cue", "")) != expected_reveal_cue:
		failures.append("Scratch completion did not time its winner cue to the reveal action.")
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	var ticket_rect_data: Dictionary = surface.get("scratch_ticket_rect", {}) if typeof(surface.get("scratch_ticket_rect", {})) == TYPE_DICTIONARY else {}
	var ticket_rect := Rect2(float(ticket_rect_data.get("x", 0)), float(ticket_rect_data.get("y", 0)), float(ticket_rect_data.get("w", 0)), float(ticket_rect_data.get("h", 0)))
	var file_hit_rect := Rect2()
	for hit_value in harness.hit_regions:
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")) == "scratch_file_ticket":
			file_hit_rect = (hit_value as Dictionary).get("rect", Rect2()) as Rect2
			break
	if file_hit_rect.size == Vector2.ZERO or not file_hit_rect.has_point(ticket_rect.get_center()):
		failures.append("Scratch result state did not expose a click-to-file hit region.")
	if _surface_harness_label_contains(harness, "FILE WIN") or _surface_harness_label_contains(harness, "FILE NO-WIN"):
		failures.append("Scratch result state retained the separate File button instead of using the completed ticket.")
	if _surface_harness_label_contains(harness, "%") or _surface_harness_label_contains(harness, "COVERAGE"):
		failures.append("Scratch surface rendered a progress/coverage readout.")
	var file := game.surface_action_command("scratch_file_ticket", 0, false, {}, run_state, environment)
	var file_result := game.resolve_with_context("settle_scratch_ticket", 0, run_state, environment, _scratch_rng("queue-file"), file.get("ui_state", {}))
	if not bool(file_result.get("suppress_music_outcome", false)):
		failures.append("Scratch filing replayed the winning-ticket sound after reveal.")
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if _dict_array(machine.get("pending_queue", [])).size() != 1 or str((machine.get("active_ticket", {}) as Dictionary).get("id", "")) == first_id:
		failures.append("Scratch filing did not advance to the next queued ticket.")
	var filed_pile := _dict_array(machine.get(expected_pile, []))
	if filed_pile.is_empty() or str((filed_pile.back() as Dictionary).get("id", "")) != first_id:
		failures.append("Scratch filing did not visibly retain the completed ticket in its win/loss pile.")
	elif (filed_pile.back() as Dictionary).has("latex_mask") or (filed_pile.back() as Dictionary).has("scratch_regions"):
		failures.append("Scratch filing retained the high-resolution scratch mask in a completed pile receipt.")
	if str(machine.get("last_settled_pile", "")) != expected_pile or str((machine.get("last_settled_ticket", {}) as Dictionary).get("id", "")) != first_id:
		failures.append("Scratch filing did not retain its pile-animation receipt.")
	elif (machine.get("last_settled_ticket", {}) as Dictionary).has("latex_mask") or (machine.get("last_settled_ticket", {}) as Dictionary).has("scratch_regions"):
		failures.append("Scratch pile-animation receipt retained a duplicate high-resolution mask.")


func _check_scratch_discard_flow(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-DISCARD-FLOW")
	run_state.bankroll = 500000
	var environment := _scratch_environment("scratch_discard")
	var dud := _scratch_ticket_with_win_state(game, "two_fer", false, "discard-dud")
	var next_ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "lucky_7s"), _scratch_rng("discard-next"), 0, "discard-next")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("discard-stock"))
	machine["active_ticket"] = dud
	machine["pending_queue"] = [next_ticket]
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var before_outcome_id := str(dud.get("outcome_id", ""))
	var before_payout := int(dud.get("payout", 0))
	game.call("_scratch_segment", machine, Vector2(450, 200), Vector2(520, 200))
	var accidental_begin := game.surface_pointer_command("scratch_scrub", 0, "begin", Vector2(450, 200), {}, run_state, environment)
	var accidental_end := game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(248, 372), accidental_begin.get("ui_state", {}), run_state, environment)
	if bool(accidental_end.get("direct_resolve", false)):
		failures.append("Scratch waste basket accepted an unintentional release without a deliberate drag path.")
	var begin := game.surface_pointer_command("scratch_scrub", 0, "begin", Vector2(450, 200), {}, run_state, environment)
	var move := game.surface_pointer_command("scratch_scrub", 0, "move", Vector2(286, 322), begin.get("ui_state", {}), run_state, environment)
	var command := game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(248, 372), move.get("ui_state", {}), run_state, environment)
	if not bool(command.get("handled", false)) or not bool(command.get("direct_resolve", false)) or not bool((command.get("ui_state", {}) as Dictionary).get("scratch_discard_unfinished", false)):
		failures.append("A deliberate long drag into the waste-basket opening did not create an unfinished-discard command.")
		return
	if not _dict_array((command.get("ui_state", {}) as Dictionary).get("scratch_crumbs", [])).is_empty() or (command.get("ui_state", {}) as Dictionary).has("scratch_last_pointer"):
		failures.append("Scratch release left a crumb or pointer dot at the final scratch position.")
	var result := game.resolve_with_context("settle_scratch_ticket", 0, run_state, environment, _scratch_rng("discard-resolve"), command.get("ui_state", {}))
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if not bool(result.get("scratch_discarded_unfinished", false)) or str((machine.get("active_ticket", {}) as Dictionary).get("id", "")) != str(next_ticket.get("id", "")):
		failures.append("Scratch waste basket did not remove the dud and advance the queue.")
	var filed_duds := _dict_array(machine.get("loser_pile", []))
	var filed_dud: Dictionary = filed_duds.back() if not filed_duds.is_empty() else {}
	if filed_dud.is_empty() or str(filed_dud.get("id", "")) != str(dud.get("id", "")) or str(filed_dud.get("outcome_id", "")) != before_outcome_id or int(filed_dud.get("payout", -1)) != before_payout:
		failures.append("Scratch discard changed the purchase-fixed dud or failed to file it.")
	elif filed_dud.has("mechanic_result") or filed_dud.has("spots") or filed_dud.has("latex_mask"):
		failures.append("Scratch discard retained resolved playfield data after filing the compact receipt.")
	var surface := game.surface_state(run_state, environment, {})
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	if _surface_harness_has_action(harness, "scratch_discard") or not _surface_harness_has_action(harness, "scratch_scrub"):
		failures.append("Scratch waste basket exposed an accidental click discard instead of the deliberate drag gesture.")
	var winner := _scratch_ticket_with_win_state(game, "golden_vault", true, "discard-winner")
	machine["active_ticket"] = winner
	game.call("_write_machine_state", environment, machine, run_state)
	var winner_command := game.surface_action_command("scratch_discard", 0, false, {}, run_state, environment)
	var winner_result := game.resolve_with_context("settle_scratch_ticket", 0, run_state, environment, _scratch_rng("discard-winner-resolve"), winner_command.get("ui_state", {}))
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if not bool(winner_result.get("scratch_discard_preserved_winner", false)) or _dict_array(machine.get("winner_pile", [])).is_empty():
		failures.append("Discarding an unfinished winner did not preserve it for clerk redemption.")
	if str(machine.get("last_settled_pile", "")) != "winner_pile" or str((machine.get("last_settled_ticket", {}) as Dictionary).get("id", "")) != str(winner.get("id", "")):
		failures.append("Filing the final ticket without a queue lost its visible pile-animation receipt.")


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
	game.call("_write_machine_state", environment, machine, run_state, false)
	var outcome_json := JSON.stringify(ticket.get("mechanic_result", {}))
	var mask_json := JSON.stringify(ticket.get("latex_mask", []))
	var queue_json := JSON.stringify(machine.get("pending_queue", []))
	run_state.world_map = {
		"version": 1,
		"seed_text": run_state.seed_text,
		"start_node_id": "scratch_save",
		"current_node_id": "scratch_save",
		"nodes": [{"id": "scratch_save", "state": "visited", "environment": {}}],
		"edges": [],
		"visited_path": ["scratch_save"],
	}
	run_state.store_current_world_node_environment()
	var save_data := run_state.to_dict()
	var saved_machine: Dictionary = (save_data.get("current_environment", {}).get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if saved_machine.has("active_ticket") or saved_machine.has("pending_queue"):
		failures.append("Scratch save duplicated player-owned tickets inside the current environment snapshot.")
	var saved_nodes: Array = (save_data.get("world_map", {}) as Dictionary).get("nodes", [])
	var saved_node_environment: Dictionary = (saved_nodes[0] as Dictionary).get("environment", {}) if not saved_nodes.is_empty() else {}
	var saved_node_machine: Dictionary = (saved_node_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if saved_node_machine.has("active_ticket") or saved_node_machine.has("pending_queue"):
		failures.append("Scratch save duplicated player-owned tickets inside a stored world-map environment.")
	# Simulate a pre-fix save: completed masks existed in the portable pile and
	# the entire player-owned machine was duplicated in the world-map node.
	var legacy_receipt := ticket.duplicate(true)
	legacy_receipt["settled"] = true
	legacy_receipt["result_ready"] = true
	var portable_snapshot: Dictionary = save_data.get("portable_ticket_piles", {})
	var scratch_origins: Dictionary = portable_snapshot.get("scratch_tickets", {})
	var origin_key := RunState.portable_ticket_origin_key(environment)
	var portable_state: Dictionary = scratch_origins.get(origin_key, {})
	var legacy_receipts: Array = []
	for receipt_index in range(40):
		var receipt := legacy_receipt.duplicate(true)
		receipt["id"] = "legacy-receipt-%d" % receipt_index
		legacy_receipts.append(receipt)
	portable_state["loser_pile"] = legacy_receipts
	portable_state["last_settled_ticket"] = legacy_receipt.duplicate(true)
	scratch_origins[origin_key] = portable_state
	portable_snapshot["scratch_tickets"] = scratch_origins
	save_data["portable_ticket_piles"] = portable_snapshot
	(saved_nodes[0] as Dictionary)["environment"] = environment.duplicate(true)
	(save_data.get("world_map", {}) as Dictionary)["nodes"] = saved_nodes
	var restored: RunState = RunStateScript.new()
	restored.from_dict(save_data)
	var loaded: Dictionary = ((restored.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {}) as Dictionary).get("active_ticket", {})
	var loaded_machine: Dictionary = (restored.current_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if JSON.stringify(loaded.get("mechanic_result", {})) != outcome_json or JSON.stringify(loaded.get("latex_mask", [])) != mask_json or JSON.stringify(loaded_machine.get("pending_queue", [])) != queue_json:
		failures.append("Scratch save/load did not restore fixed outcome, partial mask, and queued tickets.")
	var migrated_receipts := _dict_array(loaded_machine.get("loser_pile", []))
	if migrated_receipts.is_empty() or (migrated_receipts[0] as Dictionary).has("latex_mask") or (migrated_receipts[0] as Dictionary).has("scratch_regions"):
		failures.append("Scratch save migration did not compact a legacy completed-ticket mask.")
	elif migrated_receipts.size() != RunState.PORTABLE_SCRATCH_TICKET_LOSER_RECEIPT_LIMIT or int(loaded_machine.get("loser_archive_count", 0)) != 40 - RunState.PORTABLE_SCRATCH_TICKET_LOSER_RECEIPT_LIMIT:
		failures.append("Scratch save migration did not bound filed dud receipts while preserving their exact archived count.")
	var migrated_node: Dictionary = ((restored.world_map.get("nodes", []) as Array)[0] as Dictionary)
	var migrated_node_environment: Dictionary = migrated_node.get("environment", {})
	var migrated_node_machine: Dictionary = (migrated_node_environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if migrated_node_machine.has("active_ticket") or migrated_node_machine.has("pending_queue") or migrated_node_machine.has("loser_pile"):
		failures.append("Scratch save migration retained duplicate player-owned state in the world-map node.")


func _check_scratch_stale_region_upgrade(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-STALE-REGION-UPGRADE")
	run_state.bankroll = 500000
	var environment := _scratch_environment("scratch_stale_region_gas")
	var ticket_type: Dictionary = game.call("_ticket_type", "lucky_7s")
	var ticket: Dictionary = game.call("_roll_ticket", ticket_type, run_state.create_rng("scratch_stale_region_ticket"), 0, "stale-region-upgrade")
	var original_payout := int(ticket.get("payout", 0))
	var original_outcome := str(ticket.get("outcome_id", ""))
	var old_regions := _dict_array(ticket.get("scratch_regions", []))
	if old_regions.is_empty():
		failures.append("Scratch stale-region upgrade could not build a ticket fixture.")
		return
	var stale_first: Dictionary = old_regions[0]
	var expected_progress := 0.42
	stale_first["art_rect"] = [0.0, 0.0, 1.0, 1.0]
	stale_first["layout_version"] = 8
	stale_first["coverage"] = expected_progress
	stale_first["revealed"] = false
	stale_first["mask_remaining_units"] = roundi(float(stale_first.get("sample_total", 0)) * 255.0 * (1.0 - expected_progress))
	old_regions[0] = stale_first
	ticket["scratch_regions"] = old_regions
	ticket["region_layout_version"] = 8
	var machine: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("scratch_stale_region_stock"))
	machine["version"] = 2
	machine["active_ticket"] = ticket
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var upgraded: Dictionary = game.call("_ensure_machine_state", run_state, environment, true)
	var active: Dictionary = upgraded.get("active_ticket", {}) if typeof(upgraded.get("active_ticket", {})) == TYPE_DICTIONARY else {}
	var regions := _dict_array(active.get("scratch_regions", []))
	var expected := _dict_array(game.call("_ticket_art_regions", active))
	if int(upgraded.get("version", 0)) < 3 or int(active.get("region_layout_version", 0)) != ScratchRegionModelScript.LAYOUT_VERSION:
		failures.append("Scratch v8-to-current region upgrade did not stamp the current machine/ticket layout version.")
	if int(active.get("payout", -1)) != original_payout or str(active.get("outcome_id", "")) != original_outcome:
		failures.append("Scratch stale-region upgrade changed the fixed-at-purchase outcome.")
	if regions.size() != expected.size():
		failures.append("Scratch stale-region upgrade rebuilt %d regions; expected %d." % [regions.size(), expected.size()])
	elif not _scratch_rect_values_equal((regions[0] as Dictionary).get("art_rect", []), (expected[0] as Dictionary).get("art_rect", [])):
		failures.append("Scratch stale-region upgrade kept obsolete art_rect values.")
	elif absf(float((regions[0] as Dictionary).get("coverage", 0.0)) - expected_progress) > 0.01 or bool((regions[0] as Dictionary).get("revealed", false)):
		failures.append("Scratch v8-to-current region upgrade did not preserve partial per-well scratch progress.")
	var surface := game.surface_state(run_state, environment, {})
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	var crossword_environment := _scratch_environment("scratch_crossword_v9_region_upgrade")
	var crossword_ticket: Dictionary = game.call("_roll_ticket", game.call("_ticket_type", "crossword_corner"), run_state.create_rng("scratch_crossword_v9_ticket"), 0, "crossword-v9-upgrade")
	var crossword_outcome_json := JSON.stringify(crossword_ticket.get("mechanic_result", {}))
	var crossword_payout := int(crossword_ticket.get("payout", -1))
	var crossword_regions := _dict_array(crossword_ticket.get("scratch_regions", []))
	var crossword_progress := 0.37
	var stale_crossword_region: Dictionary = crossword_regions[0]
	stale_crossword_region["art_rect"] = [0.0, 0.0, 1.0, 1.0]
	stale_crossword_region["layout_version"] = 9
	stale_crossword_region["coverage"] = crossword_progress
	stale_crossword_region["revealed"] = false
	stale_crossword_region["mask_remaining_units"] = roundi(float(stale_crossword_region.get("sample_total", 0)) * 255.0 * (1.0 - crossword_progress))
	crossword_regions[0] = stale_crossword_region
	crossword_ticket["scratch_regions"] = crossword_regions
	crossword_ticket["region_layout_version"] = 9
	var crossword_machine: Dictionary = game.generate_environment_state(run_state, crossword_environment, run_state.create_rng("scratch_crossword_v9_stock"))
	crossword_machine["active_ticket"] = crossword_ticket
	crossword_environment["game_states"] = {"scratch_tickets": crossword_machine}
	run_state.current_environment = crossword_environment
	var upgraded_crossword_machine: Dictionary = game.call("_ensure_machine_state", run_state, crossword_environment, true)
	var upgraded_crossword: Dictionary = upgraded_crossword_machine.get("active_ticket", {}) if typeof(upgraded_crossword_machine.get("active_ticket", {})) == TYPE_DICTIONARY else {}
	var upgraded_crossword_regions := _dict_array(upgraded_crossword.get("scratch_regions", []))
	if int(upgraded_crossword.get("region_layout_version", 0)) != ScratchRegionModelScript.LAYOUT_VERSION:
		failures.append("Scratch Crossword v9-to-v10 region upgrade did not stamp layout v10.")
	elif JSON.stringify(upgraded_crossword.get("mechanic_result", {})) != crossword_outcome_json or int(upgraded_crossword.get("payout", -1)) != crossword_payout:
		failures.append("Scratch Crossword v9-to-v10 region upgrade changed its generated puzzle or payout.")
	elif upgraded_crossword_regions.is_empty() or absf(float((upgraded_crossword_regions[0] as Dictionary).get("coverage", 0.0)) - crossword_progress) > 0.01:
		failures.append("Scratch Crossword v9-to-v10 region upgrade did not preserve partial scratch progress.")


func _scratch_rect_values_equal(left_value: Variant, right_value: Variant) -> bool:
	if typeof(left_value) != TYPE_ARRAY or typeof(right_value) != TYPE_ARRAY:
		return false
	var left: Array = left_value
	var right: Array = right_value
	if left.size() < 4 or right.size() < 4:
		return false
	for index in range(4):
		if absf(float(left[index]) - float(right[index])) > 0.0001:
			return false
	return true


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
	if str(first.get("stock_stream_key", "")) != "scratch-stock:stock:day:4" or str(first.get("stock_weighting", "")) != "full_roster_75_out_of_stock_1_to_5":
		failures.append("Scratch stock did not record its named day-keyed weighted fork.")
	var stock := _dict_array(first.get("stock", []))
	if stock.size() != SCRATCH_IDS.size():
		failures.append("Scratch stock must show every ticket type in the machine.")
	var seen_types := {}
	for slot_value in stock:
		var slot: Dictionary = slot_value
		var type_id := str(slot.get("type_id", ""))
		seen_types[type_id] = true
		var remaining := int(slot.get("remaining", -1))
		if remaining < 0 or remaining > 5:
			failures.append("Scratch stock row %s has %d remaining; expected 0-5." % [type_id, remaining])
	for type_id in SCRATCH_IDS:
		if not seen_types.has(type_id):
			failures.append("Scratch machine stock omitted %s." % type_id)
	var out_of_stock_rows := 0
	var total_rows := 0
	var stocked_counts := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for sample in range(512):
		var sample_machine: Dictionary = game.call("_generate_machine_state", null, {"id": "stock-mass", "day": sample}, _scratch_rng("stock-mass:%d" % sample))
		for slot_value in _dict_array(sample_machine.get("stock", [])):
			total_rows += 1
			var sample_remaining := int((slot_value as Dictionary).get("remaining", 0))
			if sample_remaining <= 0:
				out_of_stock_rows += 1
			elif stocked_counts.has(sample_remaining):
				stocked_counts[sample_remaining] = int(stocked_counts.get(sample_remaining, 0)) + 1
	var sold_out_rate := float(out_of_stock_rows) / float(maxi(1, total_rows))
	if sold_out_rate < 0.70 or sold_out_rate > 0.80:
		failures.append("Scratch stock sold-out rate %.3f did not stay near the 75%% scarcity target." % sold_out_rate)
	var expected_stocked_bucket := float(total_rows) * 0.05
	for amount in range(1, 6):
		var bucket := int(stocked_counts.get(amount, 0))
		if absf(float(bucket) - expected_stocked_bucket) > expected_stocked_bucket * 0.45:
			failures.append("Scratch stocked count %d appeared %d times; expected an even 5%% bucket near %.1f." % [amount, bucket, expected_stocked_bucket])
	var rotated := false
	for day in range(5, 11):
		var day_machine: Dictionary = game.call("_generate_machine_state", null, {"id": "stock", "day": day}, null)
		if day_machine.get("stock", []) != first.get("stock", []):
			rotated = true
			break
	if not rotated:
		failures.append("Scratch stock did not rotate across day-keyed streams.")


func _check_scratch_restock(game: GameModule, failures: Array) -> void:
	var roll_counts := {0: 0, 1: 0, 2: 0}
	for roll in range(100):
		var count := int(game.call("restock_count_for_roll", roll))
		roll_counts[count] = int(roll_counts.get(count, 0)) + 1
	if int(roll_counts.get(0, 0)) != 50 or int(roll_counts.get(1, 0)) != 40 or int(roll_counts.get(2, 0)) != 10:
		failures.append("Scratch three-hour restock rolls are not exactly 50%% none, 40%% one, and 10%% two.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-RESTOCK-CATCHUP")
	run_state.game_clock_minutes = 540
	var environment := _scratch_environment("scratch_restock_catchup")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("restock-catchup-stock"))
	var stock := _dict_array(machine.get("stock", []))
	for slot_value in stock:
		var slot: Dictionary = slot_value
		slot["remaining"] = 0
		slot["capacity"] = 5
	machine["stock"] = stock
	machine["restock_phase_minute"] = 0
	machine["restock_cursor_absolute_minute"] = 0
	machine["next_restock_absolute_minute"] = 180
	machine["restock_event_count"] = 0
	machine["scalper_present"] = false
	game.call("_advance_restock_schedule", run_state, environment, machine)
	if int(machine.get("restock_event_count", 0)) != 3 or int(machine.get("restock_cursor_absolute_minute", -1)) != 540 or int(machine.get("next_restock_absolute_minute", -1)) != 720:
		failures.append("Scratch restock did not catch up each elapsed three-hour boundary exactly once.")
	var total_stock := int(game.call("_stock_total", machine))
	if total_stock < 0 or total_stock > 6:
		failures.append("Scratch catch-up added more than two tickets per elapsed restock.")
	for slot_value in _dict_array(machine.get("stock", [])):
		var slot: Dictionary = slot_value
		if int(slot.get("remaining", -1)) < 0 or int(slot.get("remaining", 0)) > int(slot.get("capacity", 0)):
			failures.append("Scratch restock exceeded a ticket slot's machine capacity.")
	var before_repeat := machine.duplicate(true)
	game.call("_advance_restock_schedule", run_state, environment, machine)
	if machine != before_repeat:
		failures.append("Scratch restock replayed a processed boundary without time advancing.")
	var replay_run: RunState = RunStateScript.new()
	replay_run.start_new("SCRATCH-RESTOCK-CATCHUP")
	replay_run.game_clock_minutes = 540
	var replay_machine: Dictionary = game.call("_generate_machine_state", replay_run, environment, _scratch_rng("restock-catchup-stock"))
	var replay_stock := _dict_array(replay_machine.get("stock", []))
	for slot_value in replay_stock:
		var slot: Dictionary = slot_value
		slot["remaining"] = 0
		slot["capacity"] = 5
	replay_machine["stock"] = replay_stock
	replay_machine["restock_phase_minute"] = 0
	replay_machine["restock_cursor_absolute_minute"] = 0
	replay_machine["next_restock_absolute_minute"] = 180
	replay_machine["restock_event_count"] = 0
	replay_machine["scalper_present"] = false
	game.call("_advance_restock_schedule", replay_run, environment, replay_machine)
	if replay_machine.get("stock", []) != machine.get("stock", []) or int(replay_machine.get("restock_event_count", 0)) != int(machine.get("restock_event_count", 0)):
		failures.append("Scratch elapsed-time restocking was not deterministic for a run seed and machine.")


func _check_scratch_scalper(game: GameModule, failures: Array) -> void:
	var present_count := 0
	var knows_count := 0
	for roll in range(100):
		present_count += 1 if bool(game.call("scalper_present_for_roll", roll)) else 0
		knows_count += 1 if bool(game.call("scalper_knows_for_roll", roll)) else 0
	if present_count != 30:
		failures.append("Scratch scalper visit odds drifted from the configured 30%% encounter chance.")
	if knows_count != 50:
		failures.append("Scratch scalper dialogue odds are not an exact 50/50 split.")
	var empty_spawn_found := false
	for day in range(2048):
		var spawn_run: RunState = RunStateScript.new()
		spawn_run.start_new("SCRATCH-EMPTY-SPAWN-%d" % day)
		var spawn_environment := _scratch_environment("scratch_empty_spawn_%d" % day)
		spawn_environment["generated_day"] = day
		spawn_environment["entered_game_clock_minutes"] = spawn_run.game_clock_minutes
		var spawn_machine: Dictionary = game.call("_generate_machine_state", spawn_run, spawn_environment, _scratch_rng("empty-spawn:%d" % day))
		if int(game.call("_stock_total", spawn_machine)) > 0:
			continue
		empty_spawn_found = true
		if not bool(spawn_machine.get("scalper_present", false)) \
				or str(spawn_machine.get("scalper_visit_token", "")).is_empty():
			failures.append("A scratch machine generated fully empty without its guaranteed scalper encounter.")
		break
	if not empty_spawn_found:
		failures.append("Scratch scalper regression could not produce an initially empty machine fixture.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-SCALPER")
	var environment := _scratch_environment("scratch_scalper")
	environment["entered_game_clock_minutes"] = run_state.game_clock_minutes
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("scalper-stock"))
	var stock := _dict_array(machine.get("stock", []))
	for slot_value in stock:
		(slot_value as Dictionary)["remaining"] = 1
	machine["stock"] = stock
	var cleared := int(game.call("_clear_machine_stock", machine))
	if cleared != stock.size() or int(game.call("_stock_total", machine)) != 0:
		failures.append("Scratch scalper did not leave every machine slot out of stock.")
	machine["scalper_visit_token"] = game.call("_scratch_visit_token", run_state, environment)
	machine["scalper_present"] = true
	machine["scalper_knows_schedule"] = true
	machine["next_restock_absolute_minute"] = run_state.game_clock_minutes + 180
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var hooks := game.environment_interactable_objects(run_state, environment)
	var scalper_hook := _scratch_hook(hooks, "scratch_ticket_scalper")
	if scalper_hook.is_empty() or str(scalper_hook.get("object_id", "")) != "dialogue:scratch_ticket_scalper" or str(scalper_hook.get("dialogue_id", "")) != "scratch_ticket_scalper_knows":
		failures.append("Scratch scalper did not appear as a stable talk target with the informed dialogue branch.")
	var informed_summary := str(scalper_hook.get("dialogue_summary", ""))
	if not informed_summary.contains("Day ") or informed_summary.count("Day ") != 3 or not informed_summary.contains("every three hours") or not (informed_summary.contains("AM") or informed_summary.contains("PM")):
		failures.append("Informed scratch scalper dialogue did not reveal the exact repeating restock schedule.")
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	machine["scalper_knows_schedule"] = false
	environment["game_states"] = {"scratch_tickets": machine}
	hooks = game.environment_interactable_objects(run_state, environment)
	scalper_hook = _scratch_hook(hooks, "scratch_ticket_scalper")
	if str(scalper_hook.get("dialogue_id", "")) != "scratch_ticket_scalper_oblivious" or str(scalper_hook.get("dialogue_summary", "")).contains("Day "):
		failures.append("Oblivious scratch scalper dialogue exposed the hidden restock schedule.")
	var tutorial_run: RunState = RunStateScript.new()
	tutorial_run.start_new("SCRATCH-SCALPER-TUTORIAL")
	tutorial_run.challenge_config = {"tutorial": true}
	var tutorial_environment := _scratch_environment("scratch_scalper_tutorial")
	tutorial_environment["entered_game_clock_minutes"] = tutorial_run.game_clock_minutes
	var tutorial_machine: Dictionary = game.call("_generate_machine_state", tutorial_run, tutorial_environment, _scratch_rng("scalper-tutorial-stock"))
	tutorial_machine["scalper_present"] = true
	tutorial_environment["game_states"] = {"scratch_tickets": tutorial_machine}
	tutorial_run.current_environment = tutorial_environment
	var tutorial_hooks := game.environment_interactable_objects(tutorial_run, tutorial_environment)
	if not _scratch_hook(tutorial_hooks, "scratch_ticket_scalper").is_empty():
		failures.append("Scratch scalper intruded on the guided tutorial run.")


func _scratch_hook(hooks: Array, hook_id: String) -> Dictionary:
	for hook_value in hooks:
		if typeof(hook_value) == TYPE_DICTIONARY and str((hook_value as Dictionary).get("id", "")) == hook_id:
			return hook_value as Dictionary
	return {}


func _check_scratch_collection_completion(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-COLLECTION-COMPLETE")
	run_state.bankroll = 500000
	run_state.narrative_flags["scratch_ticket_types_discovered"] = SCRATCH_IDS.duplicate()
	var environment := _scratch_environment("scratch_collection_complete")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("collection-complete-stock"))
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var surface := game.surface_state(run_state, environment, {})
	if not bool(surface.get("scratch_collection_complete", false)) or str(surface.get("scratch_collection_status", "")) != "FULL SET FOUND":
		failures.append("Scratch collection completion does not produce the cabinet's finished state.")
	var profile: ProfileInventory = ProfileInventoryScript.new()
	for type_id in SCRATCH_IDS:
		profile.discover_scratch_ticket_type(type_id)
	if not profile.scratch_ticket_collection_complete():
		failures.append("Scratch profile did not detect a complete seven-print collection.")
	if not profile.mark_scratch_ticket_collection_acknowledged():
		failures.append("Scratch profile did not mark the first completion acknowledgement.")
	if profile.mark_scratch_ticket_collection_acknowledged():
		failures.append("Scratch profile completion acknowledgement was not one-time.")


func _check_scratch_single_remaining_purchase(game: GameModule, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-SINGLE-LEFT")
	run_state.bankroll = 500000
	var environment := _scratch_environment("scratch_single_left")
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _scratch_rng("single-left-stock"))
	var stock := _dict_array(machine.get("stock", []))
	if stock.is_empty():
		failures.append("Scratch single-left fixture could not create machine stock.")
		return
	for index in range(stock.size()):
		(stock[index] as Dictionary)["remaining"] = 0
	(stock[0] as Dictionary)["remaining"] = 1
	machine["stock"] = stock
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	var surface := game.surface_state(run_state, environment, {})
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	game.draw_surface(harness, surface, {"contract_harness": true})
	var row_buy_hit := false
	for hit_value in harness.hit_regions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_value
		if str(hit.get("action", "")) == "scratch_buy" and int(hit.get("index", -1)) == 0:
			var rect: Rect2 = hit.get("rect", Rect2()) as Rect2
			if rect.size.x * rect.size.y > 1000.0:
				row_buy_hit = true
				break
	if not row_buy_hit:
		failures.append("Scratch machine did not expose the full single-stock row as a one-ticket buy target.")
	var buy := game.surface_action_command("scratch_buy", 0, false, {}, run_state, environment)
	if not bool(buy.get("handled", false)) or str(buy.get("action_id", "")) != "buy_scratch_ticket" or int(buy.get("set_stake", 0)) != int((stock[0] as Dictionary).get("price", 1)):
		failures.append("Scratch one-remaining row did not create a one-ticket purchase command.")
		return
	game.resolve_with_context("buy_scratch_ticket", int(buy.get("set_stake", 0)), run_state, environment, _scratch_rng("single-left-buy"), buy.get("ui_state", {}))
	var updated_machine: Dictionary = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var updated_stock := _dict_array(updated_machine.get("stock", []))
	if updated_stock.is_empty() or int((updated_stock[0] as Dictionary).get("remaining", -1)) != 0 or (updated_machine.get("active_ticket", {}) as Dictionary).is_empty():
		failures.append("Scratch one-remaining purchase did not consume the final ticket and set it active.")


func _check_scratch_rtp(game: GameModule, failures: Array) -> void:
	for type_id in SCRATCH_IDS:
		var metrics: Dictionary = game.call("measure_rtp", type_id, 100000, "FOUNDATION-RTP")
		var definition: Dictionary = game.call("_ticket_type", type_id)
		_check_scratch_prize_tier_weights(definition, failures)
		var band: Array = definition.get("rtp_band", [])
		var rtp := float(metrics.get("rtp", -1.0))
		if band.size() != 2 or rtp < float(band[0]) or rtp > float(band[1]):
			failures.append("Scratch RTP %s %.4f fell outside %s." % [type_id, rtp, JSON.stringify(band)])


func _check_scratch_prize_tier_weights(definition: Dictionary, failures: Array) -> void:
	var table := _dict_array(definition.get("prize_table", []))
	var total_weight := 0
	var loss_weight := 0
	var positive_tiers: Array = []
	for prize_value in table:
		var prize: Dictionary = prize_value
		var payout := int(prize.get("payout", 0))
		var weight := int(prize.get("weight", 0))
		total_weight += maxi(0, weight)
		if payout <= 0:
			loss_weight += maxi(0, weight)
		else:
			positive_tiers.append({"payout": payout, "weight": weight})
	if total_weight <= 0:
		failures.append("Scratch %s prize table has no positive total weight." % str(definition.get("id", "")))
		return
	if float(loss_weight) / float(total_weight) <= 0.50:
		failures.append("Scratch %s must keep no-payout odds above 50%%." % str(definition.get("id", "")))
	positive_tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("payout", 0)) < int(b.get("payout", 0))
	)
	for index in range(1, positive_tiers.size()):
		var previous: Dictionary = positive_tiers[index - 1]
		var current: Dictionary = positive_tiers[index]
		if int(current.get("payout", 0)) > int(previous.get("payout", 0)) and int(current.get("weight", 0)) >= int(previous.get("weight", 0)):
			failures.append("Scratch %s prize weights must descend as payouts rise: $%d weight %d, $%d weight %d." % [str(definition.get("id", "")), int(previous.get("payout", 0)), int(previous.get("weight", 0)), int(current.get("payout", 0)), int(current.get("weight", 0))])


func _check_scratch_sound(failures: Array) -> void:
	var sfx := ScratchSfxPlayerScript.new()
	var stream: AudioStreamWAV = sfx.preview_event_stream("scratch_paper_foley_loop")
	if stream == null or stream.loop_mode != AudioStreamWAV.LOOP_FORWARD or sfx.debug_normalized_event_id("scratch_paper_foley_loop") != "scratch_paper_foley_loop":
		failures.append("Scratch paper foley is not routed as the active procedural loop.")
	var pop_stream: AudioStreamWAV = sfx.preview_event_stream("scratch_box_pop")
	if pop_stream == null or pop_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED or sfx.debug_normalized_event_id("scratch_box_pop") != "scratch_box_pop":
		failures.append("Scratch per-box pop is not routed as a one-shot procedural cue.")
	var source := FileAccess.get_file_as_string("res://scripts/ui/sfx_player.gd")
	if not source.contains('"ticket_win": true'):
		failures.append("Winning ticket reveals are not routed to the music director cue boundary.")
	if source.contains("scratch_scrape_loop") or source.contains("coin_edge") or source.contains("_sample_scratch_scrape"):
		failures.append("Retired metallic scratch synthesis remains in the SFX source.")
	if not source.contains("NATIVE_PREWARM_BUDGET_USEC") or source.contains("_event_stream(str(_prewarm_queue.pop_front()))"):
		failures.append("Native SFX startup prewarm is not protected by an incremental frame budget.")
	var chunked_sfx := ScratchSfxPlayerScript.new()
	chunked_sfx.call("_begin_prewarm_event", "scratch_box_pop")
	chunked_sfx.call("_process_prewarm_chunk")
	var first_chunk: Dictionary = chunked_sfx.debug_soak_snapshot()
	var first_cursor := int(first_chunk.get("prewarm_active_frame_cursor", 0))
	var frame_count := int(first_chunk.get("prewarm_active_frame_count", 0))
	if not bool(first_chunk.get("prewarm_active", false)) or first_cursor <= 0 or first_cursor >= frame_count:
		failures.append("Native SFX prewarm did not yield after a bounded first synthesis chunk.")
	var chunk_count := 1
	while bool(chunked_sfx.debug_soak_snapshot().get("prewarm_active", false)) and chunk_count < 20000:
		chunked_sfx.call("_process_prewarm_chunk")
		chunk_count += 1
	var chunked_stream: AudioStreamWAV = chunked_sfx.preview_event_stream("scratch_box_pop")
	if chunk_count >= 20000 or chunked_stream == null or pop_stream == null or chunked_stream.data != pop_stream.data:
		failures.append("Incremental SFX prewarm did not finish with byte-identical deterministic PCM.")
	chunked_sfx.free()
	sfx.free()


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
	var rng := _scratch_rng("clerk-redeem")
	var command: Dictionary = game.environment_action_command("scratch_ticket_clerk", "redeem_scratch_winners", run_state, environment, rng)
	var result: Dictionary = command.get("result", {})
	if run_state.bankroll != before:
		failures.append("Scratch clerk redemption pre-applied bankroll before the host consumed the hook result.")
	GameModule.apply_result(run_state, result, rng)
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
	var buy_index := _first_stocked_scratch_index(machine)
	if buy_index < 0:
		failures.append("Scratch portable contract generated no stocked ticket rows.")
		return
	var buy := game.surface_action_command("scratch_buy", buy_index, false, {}, run_state, environment)
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


func _scratch_ticket_with_win_state(game: GameModule, type_id: String, winning: bool, seed_text: String) -> Dictionary:
	var definition: Dictionary = game.call("_ticket_type", type_id)
	var ticket: Dictionary = game.call("_roll_ticket", definition, _scratch_rng("%s:roll" % seed_text), 0, seed_text)
	var chosen_prize: Dictionary = {}
	for prize_value in _dict_array(definition.get("prize_table", [])):
		var prize: Dictionary = prize_value
		if (int(prize.get("payout", 0)) > 0) == winning:
			chosen_prize = prize
			break
	var mechanic: Dictionary = definition.get("mechanic", {})
	var content: Dictionary = game.call("_build_mechanic_content", str(mechanic.get("type", "")), mechanic, chosen_prize, _scratch_rng("%s:face" % seed_text))
	ticket["outcome_id"] = str(chosen_prize.get("id", ""))
	ticket["outcome"] = chosen_prize.duplicate(true)
	ticket["payout"] = int(chosen_prize.get("payout", 0))
	ticket["mechanic_result"] = content
	ticket["spots"] = content.get("spots", [])
	game.call("_initialize_ticket_mask", ticket, definition)
	return ticket


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


func _first_stocked_scratch_index(machine: Dictionary) -> int:
	var stock := _dict_array(machine.get("stock", []))
	for index in range(stock.size()):
		if int((stock[index] as Dictionary).get("remaining", 0)) > 0:
			return index
	return -1


func _ensure_stock_for_quantity(machine: Dictionary, quantity: int) -> int:
	var stock := _dict_array(machine.get("stock", []))
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		if int(slot.get("remaining", 0)) >= quantity:
			return index
	if not stock.is_empty():
		var slot: Dictionary = stock[0]
		slot["remaining"] = quantity
		stock[0] = slot
		machine["stock"] = stock
		return 0
	return -1


func _surface_harness_label_contains(harness: SurfaceHarness, needle: String) -> bool:
	for label_value in harness.labels:
		if str(label_value).contains(needle):
			return true
	return false
