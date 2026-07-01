extends SceneTree

# Focused pull-tab seed audit for fixed sleeves, rapid buying, tray handling,
# reveal/file flow, and redemption.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunTerminalEvaluatorScript := preload("res://scripts/core/run_terminal_evaluator.gd")

const SEED_COUNT := 24
const MAX_FILED_TICKETS_PER_SEED := 72
const STRESS_BUY_ALL_COUNT := 24
const STRESS_SINGLE_COLUMN_BUY_COUNT := 40
const MAX_RENDERED_TRAY_TICKETS := 32
const MAX_RENDERED_STACK_TICKETS := 9
const MAX_ACTIVE_DISPENSE_EVENTS := 48
const MAX_EVENT_LOCAL_DROP_START_MSEC := 300


func _init() -> void:
	var failures: Array = []
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		failures.append("Content library validation failed: %s" % JSON.stringify(library.validation_errors))
	var definition := library.game("pull_tabs")
	if definition.is_empty():
		failures.append("Pull Tabs game definition is missing.")
	else:
		for seed_index in range(SEED_COUNT):
			_audit_seed(seed_index, library, definition, failures)
		_audit_purchase_volume_budget(library, definition, failures)
		_audit_single_column_spam_budget(library, definition, failures)
		_audit_bankroll_zero_deferred_ticket_flow(library, definition, failures)
		_audit_active_item_mechanics(library, definition, failures)
	if failures.is_empty():
		print("Pull Tabs seed audit passed across %d generated machines." % SEED_COUNT)
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _audit_seed(seed_index: int, library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var label := "PULL-TABS-AUDIT-%02d" % seed_index
	var module_script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("%s: pull-tab module failed to load." % label)
		return
	var game = module_script.new()
	if not game is GameModule:
		failures.append("%s: pull-tab module does not extend GameModule." % label)
		return
	game.setup(definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.bankroll = 10000
	var environment := {
		"id": label.to_lower(),
		"archetype_id": "bar",
		"visual_context": {"scene_type": "bar"},
		"game_states": {},
	}
	var generated: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_machine"))
	if generated.is_empty():
		failures.append("%s: machine generation returned empty state." % label)
		return
	environment["game_states"] = {"pull_tabs": generated}
	_audit_generated_machine(generated, label, failures)
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	if _surface_blocks_action_while(surface, "pull_tab_buy", "pull_tab_dispense") or _surface_blocks_action_while(surface, "pull_tab_buy_all", "pull_tab_dispense"):
		failures.append("%s: purchases are blocked during dispense animation." % label)
	if not _surface_blocks_action_while(surface, "pull_tab_collect_tray", "pull_tab_dispense"):
		failures.append("%s: tray collection is not protected during dispense animation." % label)
	_audit_rapid_purchases(game, run_state, environment, label, failures)
	var ui_state := _collect_tray(game, run_state, environment, {}, label, failures)
	var filed_count := 0
	while filed_count < MAX_FILED_TICKETS_PER_SEED:
		var current_surface: Dictionary = game.surface_state(run_state, environment, ui_state)
		if int(current_surface.get("pull_tab_pending_payout", 0)) > 0:
			break
		if int(current_surface.get("pull_tab_stack_count", 0)) <= 0:
			_buy_all(game, run_state, environment, label, "fill_%02d" % filed_count, failures)
			ui_state = _collect_tray(game, run_state, environment, ui_state, label, failures)
			current_surface = game.surface_state(run_state, environment, ui_state)
			if int(current_surface.get("pull_tab_stack_count", 0)) <= 0:
				failures.append("%s: could not refill play stack during audit." % label)
				return
		if not _reveal_file_next(game, run_state, environment, ui_state, label, filed_count, failures):
			return
		filed_count += 1
	if int(game.surface_state(run_state, environment, ui_state).get("pull_tab_pending_payout", 0)) <= 0:
		failures.append("%s: no winning tab found after filing %d tickets." % [label, filed_count])
		return
	_audit_redemption(game, run_state, environment, ui_state, label, failures)


func _audit_generated_machine(machine: Dictionary, label: String, failures: Array) -> void:
	var deals: Array = machine.get("deals", [])
	if deals.size() != 4:
		failures.append("%s: expected 4 pull-tab columns, found %d." % [label, deals.size()])
	var remaining_levels := {}
	for deal_index in range(deals.size()):
		var deal: Dictionary = deals[deal_index]
		var sleeve: Array = deal.get("ticket_sleeve", [])
		var prizes: Array = deal.get("prizes", [])
		var ticket_count := int(deal.get("ticket_count", 0))
		var initial_removed_count := int(deal.get("initial_removed_count", 0))
		if ticket_count <= 0:
			failures.append("%s: column %d has no generated ticket count." % [label, deal_index])
		if sleeve.is_empty():
			failures.append("%s: column %d has no fixed ticket sleeve." % [label, deal_index])
		if int(deal.get("remaining", -1)) != sleeve.size():
			failures.append("%s: column %d remaining count does not match sleeve." % [label, deal_index])
		if initial_removed_count <= 0:
			failures.append("%s: column %d did not remove an opening run." % [label, deal_index])
		if initial_removed_count + sleeve.size() != ticket_count:
			failures.append("%s: column %d opening burn plus sleeve does not match generated ticket count." % [label, deal_index])
		if prizes.size() < 6:
			failures.append("%s: column %d does not expose the full prize ladder." % [label, deal_index])
		remaining_levels[str(deal.get("remaining", 0))] = true
		_check_prize_remainders_match_sleeve(deal, label, deal_index, failures)
	if remaining_levels.size() != deals.size():
		failures.append("%s: column stack heights are not distinct." % label)
	var item_state: Dictionary = machine.get("item_state", {})
	if item_state.is_empty():
		failures.append("%s: generated machine is missing pull-tab item state." % label)
	elif int(item_state.get("xray_deal_index", -1)) < 0 or (item_state.get("xray_target", {}) as Dictionary).is_empty():
		failures.append("%s: generated machine did not choose an x-ray target." % label)


func _audit_active_item_mechanics(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var label := "PULL-TABS-ITEMS"
	var module_script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("%s: pull-tab module failed to load." % label)
		return
	var game = module_script.new()
	if not game is GameModule:
		failures.append("%s: pull-tab module does not extend GameModule." % label)
		return
	game.setup(definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.bankroll = 100000
	run_state.add_item("xray_glasses")
	run_state.add_item("tab_detector")
	run_state.add_item("tarot_card")
	run_state.set_active_item("tab_detector")
	var environment := {
		"id": label.to_lower(),
		"archetype_id": "bar",
		"visual_context": {"scene_type": "bar"},
		"game_states": {},
	}
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_machine"))}
	var xray_surface: Dictionary = game.surface_state(run_state, environment, {})
	var xray_seen := false
	var xray_target := {}
	for deal_value in xray_surface.get("pull_tab_deals", []):
		if typeof(deal_value) == TYPE_DICTIONARY and not ((deal_value as Dictionary).get("xray_target", {}) as Dictionary).is_empty():
			xray_seen = true
			xray_target = ((deal_value as Dictionary).get("xray_target", {}) as Dictionary).duplicate(true)
			break
	if not xray_seen:
		failures.append("%s: x-ray glasses did not expose a machine target in the deal view." % label)
	else:
		_audit_xray_target_consumption(game, run_state, environment, xray_target, label, failures)
	var detector_command: Dictionary = game.active_item_command("tab_detector", run_state, environment, run_state.create_rng("detector"))
	if not bool(detector_command.get("handled", false)):
		failures.append("%s: tab detector active command was not handled." % label)
	else:
		GameModule.apply_result(run_state, detector_command.get("result", {}), run_state.create_rng("detector_apply"))
	var detector_surface: Dictionary = game.surface_state(run_state, environment, {})
	var highlighted_index := -1
	for deal_value in detector_surface.get("pull_tab_deals", []):
		if typeof(deal_value) == TYPE_DICTIONARY and bool((deal_value as Dictionary).get("tab_detector_highlight", false)):
			highlighted_index = int((deal_value as Dictionary).get("index", -1))
			break
	if highlighted_index < 0:
		failures.append("%s: active tab detector did not highlight a deal button." % label)
	else:
		var winner_result := _buy_until_detector_winner(game, run_state, environment, label, failures)
		if not winner_result.is_empty():
			if int(winner_result.get("pull_tab_payout", 0)) <= 0:
				failures.append("%s: detector winner audit stopped on a non-winner." % label)
			if int(winner_result.get("suspicion_delta", 0)) != 4:
				failures.append("%s: first detector winner heat should be +4, got %+d." % [label, int(winner_result.get("suspicion_delta", 0))])
	run_state.set_active_item("tarot_card")
	var tarot_command: Dictionary = game.active_item_command("tarot_card", run_state, environment, run_state.create_rng("tarot"))
	if not bool(tarot_command.get("handled", false)):
		failures.append("%s: tarot active command was not handled." % label)
	else:
		GameModule.apply_result(run_state, tarot_command.get("result", {}), run_state.create_rng("tarot_apply"))
		if run_state.inventory.has("tarot_card"):
			failures.append("%s: tarot card was not consumed when armed." % label)
		if str(run_state.active_item_id) == "tarot_card":
			failures.append("%s: consumed tarot card remained in the active slot." % label)
	var tarot_result := _buy_one_without_expected_payout(game, run_state, environment, 0, label, "tarot_buy", failures)
	var tarot_ticket: Dictionary = tarot_result.get("pull_tab_ticket", {})
	if not bool(tarot_ticket.get("tarot_converted", false)):
		failures.append("%s: tarot purchase did not convert the bought ticket." % label)
	if int(tarot_ticket.get("payout", -1)) != 0:
		failures.append("%s: tarot-converted ticket should pay $0." % label)
	if (tarot_ticket.get("tarot_reading", []) as Array).size() != 5:
		failures.append("%s: tarot ticket did not show five future results." % label)


func _audit_xray_target_consumption(game: GameModule, run_state: RunState, environment: Dictionary, target: Dictionary, label: String, failures: Array) -> void:
	var deal_index := int(target.get("deal_index", -1))
	var target_ticket_number := int(target.get("ticket_number", -1))
	var pull_count := maxi(1, int(target.get("tickets_until", 1)))
	var bought_target := false
	for pull_index in range(pull_count):
		var result := _buy_one(game, run_state, environment, deal_index, label, "xray_%03d" % pull_index, failures)
		var ticket: Dictionary = result.get("pull_tab_ticket", {})
		if int(ticket.get("ticket_number_value", 0)) != target_ticket_number:
			continue
		bought_target = true
		if not bool(ticket.get("xray_target_consumed", false)):
			failures.append("%s: x-ray target ticket was bought without marking the ticket consumed." % label)
		break
	if not bought_target:
		failures.append("%s: x-ray target ticket was not reached after %d pulls." % [label, pull_count])
	var machine := _machine(environment)
	var item_state: Dictionary = machine.get("item_state", {})
	if not bool(item_state.get("xray_target_consumed", false)):
		failures.append("%s: x-ray target was not marked consumed in machine state." % label)
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	for deal_value in surface.get("pull_tab_deals", []):
		if typeof(deal_value) != TYPE_DICTIONARY:
			continue
		var deal_view: Dictionary = deal_value
		if int(deal_view.get("index", -1)) == deal_index and not ((deal_view.get("xray_target", {}) as Dictionary).is_empty()):
			failures.append("%s: x-ray target highlight remained visible after the target ticket was bought." % label)


func _audit_rapid_purchases(game: GameModule, run_state: RunState, environment: Dictionary, label: String, failures: Array) -> void:
	var expected_event_ids: Array = []
	var batch_id := ""
	for purchase_index in range(3):
		var result := _buy_one(game, run_state, environment, purchase_index % 4, label, "rapid_%02d" % purchase_index, failures)
		var ticket: Dictionary = result.get("pull_tab_ticket", {})
		if not ticket.is_empty():
			expected_event_ids.append(str(ticket.get("id", "")))
		var machine := _machine(environment)
		var current_batch_id := str(machine.get("last_dispense_id", ""))
		if purchase_index == 0:
			batch_id = current_batch_id
		elif current_batch_id != batch_id:
			failures.append("%s: rapid purchase restarted the dispense batch instead of extending it." % label)
		_assert_dispense_events_include(machine, expected_event_ids, label, failures)
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	if int(surface.get("pull_tab_tray_count", 0)) < 3:
		failures.append("%s: rapid purchases did not accumulate tickets in the tray." % label)
	var all_result := _buy_all(game, run_state, environment, label, "rapid_all", failures)
	for ticket_value in all_result.get("pull_tab_tickets", []):
		if typeof(ticket_value) == TYPE_DICTIONARY:
			expected_event_ids.append(str((ticket_value as Dictionary).get("id", "")))
	_assert_dispense_events_include(_machine(environment), expected_event_ids, label, failures)
	surface = game.surface_state(run_state, environment, {})
	if int(surface.get("pull_tab_tray_count", 0)) < 4:
		failures.append("%s: all-column purchase did not add multiple tray tickets." % label)


func _buy_one(game: GameModule, run_state: RunState, environment: Dictionary, column: int, label: String, stream_key: String, failures: Array) -> Dictionary:
	var machine_before := _machine(environment)
	var deals_before: Array = machine_before.get("deals", [])
	if column < 0 or column >= deals_before.size():
		failures.append("%s: buy column %d is out of range." % [label, column])
		return {}
	var deal_before: Dictionary = deals_before[column]
	var sleeve_before: Array = deal_before.get("ticket_sleeve", [])
	var expected_payout := _sleeve_entry_payout(deal_before, int(sleeve_before[0]) if not sleeve_before.is_empty() else -1)
	var command: Dictionary = game.surface_action_command("pull_tab_buy", column, false, {}, run_state, environment)
	if not bool(command.get("handled", false)) or str(command.get("action_id", "")) != "buy_tab":
		failures.append("%s: buy command was not handled for column %d." % [label, column])
		return {}
	var result: Dictionary = game.resolve_with_context("buy_tab", int(command.get("set_stake", 1)), run_state, environment, run_state.create_rng(stream_key), command.get("ui_state", {}))
	if not bool(result.get("ok", false)):
		failures.append("%s: buy resolve failed for column %d." % [label, column])
	if int(result.get("pull_tab_payout", -1)) != expected_payout:
		failures.append("%s: buy result did not match predefined sleeve payout." % label)
	var machine_after := _machine(environment)
	var deal_after: Dictionary = (machine_after.get("deals", []) as Array)[column]
	if not sleeve_before.is_empty() and (deal_after.get("ticket_sleeve", []) as Array).size() != sleeve_before.size() - 1:
		failures.append("%s: buy did not consume exactly one sleeve ticket." % label)
	return result


func _buy_one_without_expected_payout(game: GameModule, run_state: RunState, environment: Dictionary, column: int, label: String, stream_key: String, failures: Array) -> Dictionary:
	var command: Dictionary = game.surface_action_command("pull_tab_buy", column, false, {}, run_state, environment)
	if not bool(command.get("handled", false)) or str(command.get("action_id", "")) != "buy_tab":
		failures.append("%s: buy command was not handled for column %d." % [label, column])
		return {}
	var result: Dictionary = game.resolve_with_context("buy_tab", int(command.get("set_stake", 1)), run_state, environment, run_state.create_rng(stream_key), command.get("ui_state", {}))
	if not bool(result.get("ok", false)):
		failures.append("%s: buy resolve failed for column %d." % [label, column])
	return result


func _buy_until_detector_winner(game: GameModule, run_state: RunState, environment: Dictionary, label: String, failures: Array) -> Dictionary:
	for purchase_index in range(180):
		var surface: Dictionary = game.surface_state(run_state, environment, {})
		var column := -1
		for deal_value in surface.get("pull_tab_deals", []):
			if typeof(deal_value) == TYPE_DICTIONARY and bool((deal_value as Dictionary).get("tab_detector_highlight", false)):
				column = int((deal_value as Dictionary).get("index", -1))
				break
		if column < 0:
			failures.append("%s: detector lost its highlighted column before a winner." % label)
			return {}
		var result := _buy_one_without_expected_payout(game, run_state, environment, column, label, "detector_buy_%03d" % purchase_index, failures)
		if int(result.get("pull_tab_payout", 0)) > 0:
			return result
	failures.append("%s: detector did not reach a winner within the audit budget." % label)
	return {}


func _buy_all(game: GameModule, run_state: RunState, environment: Dictionary, label: String, stream_key: String, failures: Array) -> Dictionary:
	var command: Dictionary = game.surface_action_command("pull_tab_buy_all", 0, false, {}, run_state, environment)
	if not bool(command.get("handled", false)) or str(command.get("action_id", "")) != "buy_tab_set":
		failures.append("%s: buy-all command was not handled." % label)
		return {}
	var result: Dictionary = game.resolve_with_context("buy_tab_set", int(command.get("set_stake", 1)), run_state, environment, run_state.create_rng(stream_key), command.get("ui_state", {}))
	if not bool(result.get("ok", false)) or int(result.get("pull_tab_ticket_count", 0)) <= 0:
		failures.append("%s: buy-all resolve did not produce tickets." % label)
	return result


func _collect_tray(game: GameModule, run_state: RunState, environment: Dictionary, ui_state: Dictionary, label: String, failures: Array) -> Dictionary:
	var command: Dictionary = game.surface_action_command("pull_tab_collect_tray", 0, false, ui_state, run_state, environment)
	if not bool(command.get("handled", false)) or not bool(command.get("environment_changed", false)):
		failures.append("%s: tray collection command did not update environment." % label)
	return command.get("ui_state", ui_state)


func _reveal_file_next(game: GameModule, run_state: RunState, environment: Dictionary, ui_state: Dictionary, label: String, index: int, failures: Array) -> bool:
	var reveal: Dictionary = game.surface_action_command("pull_tab_reveal_next", 0, false, ui_state, run_state, environment)
	if not bool(reveal.get("handled", false)):
		failures.append("%s: reveal command was not handled." % label)
		return false
	var reveal_state: Dictionary = reveal.get("ui_state", ui_state)
	var file_command: Dictionary = game.surface_action_command("pull_tab_file_ticket", 0, false, reveal_state, run_state, environment)
	if not bool(file_command.get("handled", false)) or str(file_command.get("action_id", "")) != "sort_tab_ticket":
		failures.append("%s: file command did not request ticket sort." % label)
		return false
	var sort_result: Dictionary = game.resolve_with_context("sort_tab_ticket", 0, run_state, environment, run_state.create_rng("sort_%02d" % index), file_command.get("ui_state", reveal_state))
	if not bool(sort_result.get("ok", false)) or int(sort_result.get("bankroll_delta", -1)) != 0:
		failures.append("%s: ticket sort failed or paid immediately." % label)
		return false
	return true


func _audit_redemption(game: GameModule, run_state: RunState, environment: Dictionary, ui_state: Dictionary, label: String, failures: Array) -> void:
	var before_bankroll := run_state.bankroll
	var before_payout := int(game.surface_state(run_state, environment, ui_state).get("pull_tab_pending_payout", 0))
	var command: Dictionary = game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, environment, run_state.create_rng("redeem"))
	if not bool(command.get("handled", false)):
		failures.append("%s: redemption hook was not handled." % label)
		return
	var result: Dictionary = command.get("result", {})
	if str(result.get("type", "")) != "game_hook" or int(result.get("bankroll_delta", 0)) != before_payout:
		failures.append("%s: redemption result did not match pending payout." % label)
		return
	GameModule.apply_result(run_state, result, run_state.create_rng("redeem_apply"))
	if run_state.bankroll != before_bankroll + before_payout:
		failures.append("%s: redemption did not apply bankroll payout." % label)
	if int(game.surface_state(run_state, environment, ui_state).get("pull_tab_pending_payout", -1)) != 0:
		failures.append("%s: redemption did not clear pending payout." % label)


func _audit_purchase_volume_budget(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var label := "PULL-TABS-STRESS"
	var module_script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("%s: pull-tab module failed to load." % label)
		return
	var game = module_script.new()
	if not game is GameModule:
		failures.append("%s: pull-tab module does not extend GameModule." % label)
		return
	game.setup(definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.bankroll = 100000
	var environment := {
		"id": label.to_lower(),
		"archetype_id": "bar",
		"visual_context": {"scene_type": "bar"},
		"game_states": {},
	}
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_machine"))}
	for buy_index in range(STRESS_BUY_ALL_COUNT):
		_buy_all(game, run_state, environment, label, "stress_buy_%02d" % buy_index, failures)
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	var expected_tray_count := STRESS_BUY_ALL_COUNT * 4
	if int(surface.get("pull_tab_tray_count", 0)) != expected_tray_count:
		failures.append("%s: stress tray count did not preserve all purchased tickets." % label)
	if (surface.get("pull_tab_tray_stack", []) as Array).size() > MAX_RENDERED_TRAY_TICKETS:
		failures.append("%s: stress surface rendered too many tray tickets." % label)
	if (surface.get("pull_tab_dispense_events", []) as Array).size() > MAX_ACTIVE_DISPENSE_EVENTS:
		failures.append("%s: active dispense events exceeded the render budget." % label)
	_assert_dispense_event_timing_budget(surface, label, failures)
	var ui_state := _collect_tray(game, run_state, environment, {}, label, failures)
	surface = game.surface_state(run_state, environment, ui_state)
	if int(surface.get("pull_tab_stack_count", 0)) != expected_tray_count:
		failures.append("%s: stress stack count did not preserve collected tickets." % label)
	if (surface.get("pull_tab_stack", []) as Array).size() > MAX_RENDERED_STACK_TICKETS:
		failures.append("%s: stress surface rendered too many play-stack tickets." % label)


func _audit_single_column_spam_budget(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var label := "PULL-TABS-SINGLE-SPAM"
	var module_script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("%s: pull-tab module failed to load." % label)
		return
	var game = module_script.new()
	if not game is GameModule:
		failures.append("%s: pull-tab module does not extend GameModule." % label)
		return
	game.setup(definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	run_state.bankroll = 100000
	var environment := {
		"id": label.to_lower(),
		"archetype_id": "bar",
		"visual_context": {"scene_type": "bar"},
		"game_states": {},
	}
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_machine"))}
	var expected_event_ids: Array = []
	for buy_index in range(STRESS_SINGLE_COLUMN_BUY_COUNT):
		var result := _buy_one(game, run_state, environment, 0, label, "single_spam_%02d" % buy_index, failures)
		var ticket: Dictionary = result.get("pull_tab_ticket", {})
		if not ticket.is_empty():
			expected_event_ids.append(str(ticket.get("id", "")))
	var machine := _machine(environment)
	_assert_dispense_events_include(machine, expected_event_ids, label, failures)
	var tray_stack: Array = machine.get("tray_stack", [])
	if tray_stack.size() != STRESS_SINGLE_COLUMN_BUY_COUNT:
		failures.append("%s: single-column spam stored the wrong tray stack size." % label)
	elif not expected_event_ids.is_empty():
		var first_ticket := (tray_stack[0] as Dictionary) if typeof(tray_stack[0]) == TYPE_DICTIONARY else {}
		var last_ticket := (tray_stack[tray_stack.size() - 1] as Dictionary) if typeof(tray_stack[tray_stack.size() - 1]) == TYPE_DICTIONARY else {}
		if first_ticket.is_empty() or last_ticket.is_empty() or str(first_ticket.get("id", "")) != str(expected_event_ids[0]) or str(last_ticket.get("id", "")) != str(expected_event_ids[expected_event_ids.size() - 1]):
			failures.append("%s: tray storage no longer preserves bottom-to-top purchase order." % label)
	var surface: Dictionary = game.surface_state(run_state, environment, {})
	if int(surface.get("pull_tab_tray_count", 0)) != STRESS_SINGLE_COLUMN_BUY_COUNT:
		failures.append("%s: single-column spam did not preserve every purchased tray ticket." % label)
	var column_counts: Array = surface.get("pull_tab_tray_column_counts", [])
	if column_counts.size() < 4 or int(column_counts[0]) != STRESS_SINGLE_COLUMN_BUY_COUNT or int(column_counts[1]) != 0 or int(column_counts[2]) != 0 or int(column_counts[3]) != 0:
		failures.append("%s: single-column spam tray counts are not isolated to the purchased column." % label)
	if (surface.get("pull_tab_tray_stack", []) as Array).size() > MAX_RENDERED_TRAY_TICKETS:
		failures.append("%s: single-column spam rendered too many tray tickets." % label)
	var previous_tray_index := -1
	for ticket_value in surface.get("pull_tab_tray_stack", []):
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value
		if int(ticket.get("deal_index", -1)) != 0:
			failures.append("%s: single-column spam rendered a ticket in the wrong tray column." % label)
			break
		if int(ticket.get("tray_index", -1)) <= previous_tray_index:
			failures.append("%s: rendered tray tickets are not bottom-to-top within their column." % label)
			break
		previous_tray_index = int(ticket.get("tray_index", -1))
	if (surface.get("pull_tab_dispense_events", []) as Array).size() != STRESS_SINGLE_COLUMN_BUY_COUNT:
		failures.append("%s: single-column spam did not keep each active purchase animation." % label)
	_assert_dispense_event_timing_budget(surface, label, failures)
	var ui_state := _collect_tray(game, run_state, environment, {}, label, failures)
	var collected_machine := _machine(environment)
	var play_stack: Array = collected_machine.get("ticket_stack", [])
	if not expected_event_ids.is_empty() and not play_stack.is_empty() and str((play_stack[0] as Dictionary).get("id", "")) != str(expected_event_ids[expected_event_ids.size() - 1]):
		failures.append("%s: collecting the tray did not leave the newest ticket on top of the play pile." % label)
	if int(game.surface_state(run_state, environment, ui_state).get("pull_tab_tray_count", -1)) != 0:
		failures.append("%s: collecting the spam tray did not clear the tray." % label)


func _audit_bankroll_zero_deferred_ticket_flow(library: ContentLibrary, definition: Dictionary, failures: Array) -> void:
	var label := "PULL-TABS-ZERO-DEFER"
	var module_script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("%s: pull-tab module failed to load." % label)
		return
	var game = module_script.new()
	if not game is GameModule:
		failures.append("%s: pull-tab module does not extend GameModule." % label)
		return
	game.setup(definition, library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(label)
	var environment := {
		"id": label.to_lower(),
		"archetype_id": "bar",
		"visual_context": {"scene_type": "bar"},
		"game_ids": ["pull_tabs"],
		"game_states": {},
	}
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("pull_tab_machine"))}
	run_state.set_environment(environment)
	var machine := _machine(run_state.current_environment)
	var deals: Array = machine.get("deals", [])
	if deals.is_empty():
		failures.append("%s: generated machine has no deals." % label)
		return
	var price := maxi(1, int((deals[0] as Dictionary).get("price", 1)))
	run_state.bankroll = price
	var buy_command: Dictionary = game.surface_action_command("pull_tab_buy", 0, false, {}, run_state, run_state.current_environment)
	var buy_result: Dictionary = game.resolve_with_context("buy_tab", price, run_state, run_state.current_environment, run_state.create_rng("zero_buy"), buy_command.get("ui_state", {}))
	if run_state.bankroll != 0:
		failures.append("%s: all-in pull-tab purchase did not spend the last cash." % label)
	if run_state.run_status == RunState.RUN_STATUS_FAILED:
		failures.append("%s: all-in pull-tab purchase failed before the ticket could be resolved." % label)
	if not bool(buy_result.get("defer_bankroll_zero_failure", false)):
		failures.append("%s: all-in pull-tab purchase did not mark bankroll-zero failure as deferred." % label)
	var runtime_state: Dictionary = game.environment_runtime_state(run_state, run_state.current_environment)
	if not bool(runtime_state.get("bankroll_zero_failure_deferred", false)):
		failures.append("%s: runtime state did not expose deferred bankroll-zero failure with tray tickets pending." % label)
	var terminal_status: Dictionary = RunTerminalEvaluatorScript.evaluate(run_state, library)
	if not bool(terminal_status.get("bankroll_zero_deferred", false)) or bool(terminal_status.get("failed", false)):
		failures.append("%s: terminal evaluator did not preserve the run while pull-tab value remained." % label)
	if game.wager_cost_for_context("sort_tab_ticket", 999, run_state, run_state.current_environment, {}) != 0:
		failures.append("%s: filing an already purchased ticket still reports a wager cost." % label)
	var collect_state: Dictionary = _collect_tray(game, run_state, run_state.current_environment, {}, label, failures)
	var reveal_command: Dictionary = game.surface_action_command("pull_tab_reveal_next", 0, false, collect_state, run_state, run_state.current_environment)
	var file_command: Dictionary = game.surface_action_command("pull_tab_file_ticket", 0, false, reveal_command.get("ui_state", collect_state), run_state, run_state.current_environment)
	if str(file_command.get("action_id", "")) != "sort_tab_ticket":
		failures.append("%s: opened ticket did not produce a file/sort command." % label)
		return
	var sort_result: Dictionary = game.resolve_with_context("sort_tab_ticket", 0, run_state, run_state.current_environment, run_state.create_rng("zero_sort"), file_command.get("ui_state", {}))
	var post_sort_terminal: Dictionary = RunTerminalEvaluatorScript.evaluate(run_state, library)
	if int(sort_result.get("pull_tab_payout", 0)) > 0:
		if not bool(post_sort_terminal.get("bankroll_zero_deferred", false)):
			failures.append("%s: zero-bankroll run was not deferred while a winner waited for redemption." % label)
		var redeem_command: Dictionary = game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, run_state.current_environment, run_state.create_rng("zero_redeem"))
		var redeem_result: Dictionary = redeem_command.get("result", {})
		if not bool(redeem_command.get("handled", false)) or int(redeem_result.get("bankroll_delta", 0)) <= 0:
			failures.append("%s: pending winner could not be redeemed from zero bankroll." % label)
		else:
			GameModule.apply_result(run_state, redeem_result, run_state.create_rng("zero_redeem_apply"))
			if run_state.bankroll <= 0 or run_state.run_status == RunState.RUN_STATUS_FAILED:
				failures.append("%s: redeeming a pending winner did not rescue the zero-bankroll run." % label)
	else:
		if bool(post_sort_terminal.get("bankroll_zero_deferred", false)):
			failures.append("%s: zero-bankroll run stayed deferred after the last losing ticket was exhausted." % label)
		var final_terminal: Dictionary = RunTerminalEvaluatorScript.evaluate_and_apply(run_state, library)
		if not bool(final_terminal.get("failed", false)) or run_state.run_failure_reason != RunState.FAILURE_BANKROLL_ZERO:
			failures.append("%s: zero-bankroll run did not fail after all pull-tab tickets were exhausted." % label)


func _assert_dispense_event_timing_budget(surface: Dictionary, label: String, failures: Array) -> void:
	for event_value in surface.get("pull_tab_dispense_events", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			failures.append("%s: active dispense event is not a dictionary." % label)
			continue
		var event: Dictionary = event_value
		var drop_start := int(event.get("drop_start_msec", 0))
		if drop_start > MAX_EVENT_LOCAL_DROP_START_MSEC:
			failures.append("%s: active dispense event uses batch-relative drop timing instead of local drop timing." % label)
			return


func _check_prize_remainders_match_sleeve(deal: Dictionary, label: String, deal_index: int, failures: Array) -> void:
	var prizes: Array = deal.get("prizes", [])
	var counts: Array = []
	for _index in range(prizes.size()):
		counts.append(0)
	for sleeve_entry in deal.get("ticket_sleeve", []):
		var prize_index := int(sleeve_entry)
		if prize_index >= 0 and prize_index < counts.size():
			counts[prize_index] = int(counts[prize_index]) + 1
	for prize_index in range(prizes.size()):
		var prize: Dictionary = prizes[prize_index]
		if int(prize.get("remaining", 0)) != int(counts[prize_index]):
			failures.append("%s: column %d prize remainder does not match sleeve." % [label, deal_index])
			return


func _assert_dispense_events_include(machine: Dictionary, ticket_ids: Array, label: String, failures: Array) -> void:
	var event_ids := {}
	for event_value in machine.get("last_dispense_events", []):
		if typeof(event_value) == TYPE_DICTIONARY:
			event_ids[str((event_value as Dictionary).get("ticket_id", ""))] = true
	for ticket_id in ticket_ids:
		if not event_ids.has(str(ticket_id)):
			failures.append("%s: active dispense batch dropped ticket event %s." % [label, str(ticket_id)])
			return


func _sleeve_entry_payout(deal: Dictionary, sleeve_entry: int) -> int:
	if sleeve_entry < 0:
		return 0
	var prizes: Array = deal.get("prizes", [])
	if sleeve_entry >= prizes.size():
		return 0
	return maxi(0, int((prizes[sleeve_entry] as Dictionary).get("payout", 0)))


func _surface_blocks_action_while(surface_state: Dictionary, action_id: String, animation_channel: String) -> bool:
	for block_value in surface_state.get("surface_action_blocks", []):
		if typeof(block_value) != TYPE_DICTIONARY:
			continue
		var block: Dictionary = block_value
		if str(block.get("while_animation", "")) != animation_channel:
			continue
		if str(block.get("action", "")) == action_id:
			return true
		for blocked_action in block.get("actions", []):
			if str(blocked_action) == action_id:
				return true
	return false


func _machine(environment: Dictionary) -> Dictionary:
	return ((environment.get("game_states", {}) as Dictionary).get("pull_tabs", {}) as Dictionary)
