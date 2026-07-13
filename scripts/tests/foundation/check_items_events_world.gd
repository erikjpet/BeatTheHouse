extends "res://scripts/tests/foundation/check_table_games.gd"

func _check_surface_command_non_mutating(game: GameModule, action: String, index: int, confirm_requested: bool, ui_state: Dictionary, run_state: RunState, environment: Dictionary, label: String, failures: Array) -> Dictionary:
	var before := JSON.stringify(run_state.to_dict())
	var command: Dictionary = game.surface_action_command(action, index, confirm_requested, ui_state, run_state, environment)
	if not bool(command.get("handled", false)):
		failures.append("Surface command was not handled: %s." % label)
	if JSON.stringify(run_state.to_dict()) != before:
		failures.append("Surface command mutated RunState before resolution: %s." % label)
	return command


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


func _surface_blocks_action(surface_state: Dictionary, action_id: String) -> bool:
	for block_value in surface_state.get("surface_action_blocks", []):
		if typeof(block_value) != TYPE_DICTIONARY:
			continue
		var block: Dictionary = block_value
		if str(block.get("action", "")) == action_id:
			return true
		for blocked_action in block.get("actions", []):
			if str(blocked_action) == action_id:
				return true
	return false


# Captures the RunState domains ActionResult is allowed to update.
func _run_state_result_snapshot(run_state: RunState) -> Dictionary:
	return {
		"bankroll": run_state.bankroll,
		"suspicion": run_state.suspicion_level(),
		"suspicion_location_id": run_state.current_suspicion_location_id(),
		"suspicion_levels": (run_state.suspicion.get("local_levels", {}) as Dictionary).duplicate(true),
		"drunk_level": run_state.drunk_level,
		"pending_drunk_absorption": run_state.pending_drunk_absorption_amount(),
		"alcoholic_level": run_state.alcoholic_level,
		"baseline_luck": run_state.baseline_luck,
		"debt_count": run_state.debt.size(),
		"story_count": run_state.story_log.size(),
		"rng_state": run_state.rng_state,
	}


# Checks the shared ActionResult/result-delta shape.
func _check_action_result_shape(result: Dictionary, expected_kind: String, failures: Array, context: String = "") -> void:
	var context_suffix := " (%s)" % context if not context.strip_edges().is_empty() else ""
	if not bool(result.get("ok", false)):
		failures.append("GameModule returned an unsuccessful result for %s action%s." % [expected_kind, context_suffix])
	if str(result.get("type", "")) != "game_action":
		failures.append("ActionResult should identify game_action results%s." % context_suffix)
	if str(result.get("action_kind", "")) != expected_kind:
		failures.append("ActionResult action kind mismatch%s: expected %s." % [context_suffix, expected_kind])
	var deltas: Dictionary = result.get("deltas", {})
	var required_delta_keys := [
		"bankroll_delta",
		"suspicion_delta",
		"alcohol_intake",
		"drunk_delta",
		"alcoholic_delta",
		"baseline_luck_delta",
		"debt_changes",
		"inventory_add",
		"inventory_remove",
		"flags_set",
		"travel_hooks_add",
		"travel_changes",
		"story_log",
		"messages",
		"ended",
		"item_hooks",
		"event_hooks",
		"demo_finale",
	]
	for key in required_delta_keys:
		if not deltas.has(key):
			failures.append("ActionResult deltas missing key: %s." % key)
	if int(result.get("bankroll_delta", 0)) != int(deltas.get("bankroll_delta", 0)):
		failures.append("ActionResult top-level bankroll_delta does not match deltas.")
	if int(result.get("suspicion_delta", 0)) != int(deltas.get("suspicion_delta", 0)):
		failures.append("ActionResult top-level suspicion_delta does not match deltas.")
	if bool(result.get("ended", false)) != bool(deltas.get("ended", false)):
		failures.append("ActionResult top-level ended does not match deltas.")
	if str(result.get("state", "")) == "":
		failures.append("ActionResult should include continue/ended state.")
	if str(result.get("message", "")).is_empty():
		failures.append("ActionResult should include a player-facing message.")
	if result.get("messages", []).is_empty() or deltas.get("messages", []).is_empty():
		failures.append("ActionResult should include messages in the shared delta shape.")
	for ui_key in ["host", "button_metadata", "overlay_state", "focus", "hover", "ui_state"]:
		if result.has(ui_key) or deltas.has(ui_key):
			failures.append("ActionResult leaked UI state key: %s." % ui_key)


# Checks both legacy self-applied results and pure host-applied module results.
func _check_action_result_application_contract(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	if not bool(result.get("host_apply_result", false)):
		_check_action_result_applied(before, run_state, result, label, failures)
		return
	if run_state.bankroll != int(before.get("bankroll", 0)):
		failures.append("RunState bankroll changed before host apply for %s." % label)
	var result_environment_id := str(result.get("environment_id", ""))
	if not result_environment_id.is_empty():
		var location_id := run_state.suspicion_location_id_for_environment_id(result_environment_id)
		var before_levels: Dictionary = before.get("suspicion_levels", {})
		var expected_suspicion := int(before_levels.get(location_id, 0))
		if run_state.suspicion_level_for_environment_id(result_environment_id) != expected_suspicion:
			failures.append("RunState suspicion changed before host apply for %s." % label)
	elif run_state.suspicion_level() != int(before.get("suspicion", 0)):
		failures.append("RunState suspicion changed before host apply for %s." % label)
	if run_state.story_log.size() != int(before.get("story_count", 0)):
		failures.append("RunState story log changed before host apply for %s." % label)
	var apply_rng := run_state.create_rng("%s_host_apply" % label.replace(" ", "_"))
	apply_rng.randi_range(1, 2147483646)
	GameModule.apply_result(run_state, result, apply_rng)
	_check_action_result_applied(before, run_state, result, "%s host apply" % label, failures)


# Checks that ActionResult changes were applied through RunState domains.
func _check_action_result_applied(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {})
	var expected_bankroll := int(before.get("bankroll", 0)) + int(deltas.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("RunState bankroll did not match %s delta." % label)
	var result_environment_id := str(result.get("environment_id", ""))
	var before_suspicion := int(before.get("suspicion", 0))
	var actual_suspicion := run_state.suspicion_level()
	if not result_environment_id.is_empty():
		var location_id := run_state.suspicion_location_id_for_environment_id(result_environment_id)
		var before_levels: Dictionary = before.get("suspicion_levels", {})
		before_suspicion = int(before_levels.get(location_id, before_suspicion if location_id == str(before.get("suspicion_location_id", "")) else 0))
		actual_suspicion = run_state.suspicion_level_for_environment_id(result_environment_id)
	var expected_suspicion := clampi(before_suspicion + int(deltas.get("suspicion_delta", 0)), 0, 100)
	if actual_suspicion != expected_suspicion:
		failures.append("RunState suspicion did not match %s delta." % label)
	var intake := maxi(0, int(deltas.get("alcohol_intake", 0)))
	var before_drunk := int(before.get("drunk_level", 0))
	var before_pending := int(before.get("pending_drunk_absorption", 0))
	var pending_capacity := maxi(0, RunState.ALCOHOL_MAX - before_drunk - before_pending)
	var accepted_intake := mini(intake, pending_capacity)
	var immediate_intake := mini(accepted_intake, RunState.DRUNK_ABSORPTION_INITIAL_POINTS)
	var expected_pending := before_pending + accepted_intake - immediate_intake
	var immediate_pending_delta := 0
	var pending_delta := int(deltas.get("pending_drunk_absorption_delta", 0))
	if pending_delta < 0:
		expected_pending = maxi(0, expected_pending + pending_delta)
	elif pending_delta > 0:
		var pending_delta_capacity := maxi(0, RunState.ALCOHOL_MAX - before_drunk - immediate_intake - expected_pending)
		var accepted_pending_delta := mini(pending_delta, pending_delta_capacity)
		immediate_pending_delta = mini(accepted_pending_delta, RunState.DRUNK_ABSORPTION_INITIAL_POINTS)
		expected_pending += maxi(0, accepted_pending_delta - immediate_pending_delta)
	var drunk_delta := int(deltas.get("drunk_delta", 0))
	var effective_drunk_delta := 0 if drunk_delta < 0 and expected_pending > 0 else drunk_delta
	var expected_drunk := clampi(before_drunk + immediate_intake + immediate_pending_delta + effective_drunk_delta, 0, RunState.ALCOHOL_MAX)
	if run_state.drunk_level != expected_drunk:
		failures.append("RunState drunk level did not match %s delta." % label)
	if run_state.pending_drunk_absorption_amount() != expected_pending:
		failures.append("RunState pending drunk absorption did not match %s alcohol intake." % label)
	var expected_alcoholic := clampi(int(before.get("alcoholic_level", 0)) + int(deltas.get("alcohol_intake", 0)) + int(deltas.get("alcoholic_delta", 0)), 0, RunState.ALCOHOL_MAX)
	if run_state.alcoholic_level != expected_alcoholic:
		failures.append("RunState alcoholic level did not match %s delta." % label)
	var expected_baseline_luck := clampi(int(before.get("baseline_luck", 0)) + int(deltas.get("baseline_luck_delta", 0)), RunState.BASELINE_LUCK_MIN, RunState.BASELINE_LUCK_MAX)
	if run_state.baseline_luck != expected_baseline_luck:
		failures.append("RunState baseline luck did not match %s delta." % label)
	var story_delta: Array = deltas.get("story_log", [])
	if run_state.story_log.size() != int(before.get("story_count", 0)) + story_delta.size():
		failures.append("RunState story log did not match %s delta." % label)
	var debt_delta: Array = deltas.get("debt_changes", [])
	if run_state.debt.size() != int(before.get("debt_count", 0)) + debt_delta.size():
		failures.append("RunState debt did not match %s delta." % label)
	if run_state.rng_state == int(before.get("rng_state", 0)):
		failures.append("RunState RNG state did not advance after %s." % label)


# Checks the one selected FT-06 starter game without touching demo UI modules.
func _check_selected_starter_game_port(library: ContentLibrary, failures: Array) -> void:
	var definition := library.game("pull_tabs")
	if definition.is_empty():
		failures.append("Selected starter game is missing from ContentLibrary: pull_tabs.")
		return
	var module_path := str(definition.get("module_path", ""))
	if module_path != "res://scripts/games/pull_tabs.gd":
		failures.append("Selected starter game should route through the PullTabsGame foundation module.")
		return
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Selected starter game module could not be loaded.")
		return
	var module_a = module_script.new()
	var module_b = module_script.new()
	if not module_a is GameModule or not module_b is GameModule:
		failures.append("Selected starter game module does not extend GameModule.")
		return

	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("PULL-TABS-PORT")
	run_b.start_new("PULL-TABS-PORT")
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var start_environment_a: EnvironmentInstance = generator_a.next_environment(run_a)
	var start_environment_b: EnvironmentInstance = generator_b.next_environment(run_b)
	var gambling_path_a := _first_reachable_target_path_with_game(library, start_environment_a.next_archetypes, "pull_tabs")
	var gambling_path_b := _first_reachable_target_path_with_game(library, start_environment_b.next_archetypes, "pull_tabs")
	if gambling_path_a.is_empty() or gambling_path_b.is_empty():
		failures.append("Selected starter route did not expose a reachable pull-tabs gambling environment.")
		return
	var environment_a := _generate_path_target_environment(generator_a, run_a, gambling_path_a)
	var environment_b := _generate_path_target_environment(generator_b, run_b, gambling_path_b)
	if not (environment_a.get("game_ids", []) as Array).has("pull_tabs"):
		failures.append("Selected starter pull-tabs route did not generate a pull-tabs gambling environment.")
		return
	var game_a: GameModule = module_a
	var game_b: GameModule = module_b
	game_a.setup(definition, library)
	game_b.setup(definition, library)
	var presentation := game_a.actions(run_a, environment_a)
	var legal_actions: Array = presentation.get("legal_actions", [])
	var cheat_actions: Array = presentation.get("cheat_actions", [])
	if legal_actions.is_empty():
		failures.append("Selected starter game did not expose a legal action.")
		return
	var has_detector_scan := false
	for cheat_action_value in cheat_actions:
		if typeof(cheat_action_value) == TYPE_DICTIONARY and str((cheat_action_value as Dictionary).get("id", "")) == "tab_detector_scan":
			has_detector_scan = true
	if not has_detector_scan:
		failures.append("Selected starter pull-tabs did not expose the detector-scan advantage action.")

	var legal_id := str(legal_actions[0].get("id", ""))
	var legal_before := _run_state_result_snapshot(run_a)
	var legal_result_a := game_a.resolve(legal_id, 5, run_a, environment_a, run_a.create_rng())
	var legal_result_b := game_b.resolve(legal_id, 5, run_b, environment_b, run_b.create_rng())
	_check_action_result_shape(legal_result_a, "legal", failures)
	_check_action_result_applied(legal_before, run_a, legal_result_a, "selected starter legal result", failures)
	_check_pull_tab_result_details(legal_result_a, failures)
	if JSON.stringify(legal_result_a) != JSON.stringify(legal_result_b):
		failures.append("Selected starter legal action was not deterministic.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Selected starter legal action did not leave deterministic RunState snapshots.")


func _first_target_with_game(library: ContentLibrary, target_ids: Array, game_id: String) -> String:
	for target_id_value in target_ids:
		var target_id := str(target_id_value)
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) != TYPE_DICTIONARY:
				continue
			var archetype: Dictionary = archetype_value
			if str(archetype.get("id", "")) != target_id:
				continue
			var game_pool_value: Variant = archetype.get("game_pool", [])
			var game_pool: Array = []
			if typeof(game_pool_value) == TYPE_ARRAY:
				game_pool = game_pool_value
			if game_id.is_empty() and not game_pool.is_empty():
				return target_id
			if game_pool.has(game_id):
				return target_id
	if game_id.is_empty() and not target_ids.is_empty():
		return str(target_ids[0])
	return ""


func _first_reachable_target_path_with_game(library: ContentLibrary, target_ids: Array, game_id: String) -> Array:
	var direct := _first_target_with_game(library, target_ids, game_id)
	if not direct.is_empty():
		return [direct]
	for target_id_value in target_ids:
		var target_id := str(target_id_value)
		var archetype := _archetype_by_id(library, target_id)
		if archetype.is_empty():
			continue
		var nested := _first_target_with_game(library, _string_array(archetype.get("next_archetypes", [])), game_id)
		if not nested.is_empty():
			return [target_id, nested]
	return []


func _generate_path_target_environment(generator: RunGenerator, run_state: RunState, target_path: Array) -> Dictionary:
	var environment := run_state.current_environment.duplicate(true)
	for target_id_value in target_path:
		environment = generator.next_environment(run_state, str(target_id_value)).to_dict()
	return environment


# Checks the small Pull Tabs result payload stays gameplay-only.
func _check_pull_tab_result_details(result: Dictionary, failures: Array) -> void:
	var ticket: Dictionary = result.get("pull_tab_ticket", {})
	var rows: Array = ticket.get("rows", [])
	if rows.size() != 3:
		failures.append("Pull Tabs result should expose a three-window ticket.")
	for row_value in rows:
		var row: Array = row_value
		if row.size() != 3:
			failures.append("Pull Tabs ticket windows should each expose three symbols.")
	if str(ticket.get("form", "")).is_empty() or str(ticket.get("serial", "")).is_empty() or str(ticket.get("ticket_number", "")).is_empty():
		failures.append("Pull Tabs ticket should expose form, serial, and ticket number metadata.")
	if (ticket.get("prize_rows", []) as Array).is_empty():
		failures.append("Pull Tabs ticket should carry a prize legend snapshot for rendering.")
	var deal: Dictionary = result.get("pull_tab_deal", {})
	if str(deal.get("form", "")) != str(ticket.get("form", "")) or str(deal.get("serial", "")) != str(ticket.get("serial", "")):
		failures.append("Pull Tabs ticket form/serial did not match its deal flare.")
	if (deal.get("prizes", []) as Array).is_empty():
		failures.append("Pull Tabs deal should expose its prize chart.")
	if int(result.get("match_count", 0)) < 1:
		failures.append("Pull Tabs result should report match count.")
	if int(result.get("pull_tab_payout", -1)) < 0 or int(result.get("payout", -1)) < 0:
		failures.append("Pull Tabs result should report non-negative payout.")
	for ui_key in ["windows", "revealed", "ticket_stack", "stack_label", "host"]:
		if result.has(ui_key):
			failures.append("Pull Tabs result leaked demo UI state key: %s." % ui_key)


func _pull_tab_test_ticket_result(ticket_id: String, payout: int) -> Dictionary:
	return {
		"pull_tab_ticket": {
			"id": "test:ticket:%s" % ticket_id,
			"display_name": "Test Pull Tab",
			"form": "TEST",
			"serial": "001-00001",
			"ticket_number": "#%s" % ticket_id,
			"rows": [["CHERRY", "CHERRY", "CHERRY"], ["LEMON", "BAR", "7"], ["BELL", "BAR", "CHERRY"]],
			"payout": payout,
			"price": 1,
		},
	}


func _pull_tab_sleeve_entry_payout(deal: Dictionary, sleeve_entry: int) -> int:
	if sleeve_entry < 0:
		return 0
	var prizes: Array = deal.get("prizes", [])
	if sleeve_entry >= prizes.size():
		return 0
	return maxi(0, int((prizes[sleeve_entry] as Dictionary).get("payout", 0)))


func _set_pull_tab_loser_count(environment: Dictionary, loser_count: int) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("pull_tabs", {})
	var losers: Array = []
	for loser_index in range(maxi(0, loser_count)):
		losers.append({
			"id": "test:loser:%03d" % loser_index,
			"display_name": "Dead Pull Tab",
			"form": "TEST",
			"serial": "001-00001",
			"ticket_number": "#L%03d" % loser_index,
			"rows": [["CHERRY", "LEMON", "BAR"], ["LEMON", "BAR", "7"], ["BELL", "BAR", "CHERRY"]],
			"payout": 0,
			"price": 1,
			"sorted": true,
			"fully_revealed": true,
		})
	machine["loser_pile"] = losers
	states["pull_tabs"] = machine
	environment["game_states"] = states


func _clear_pull_tab_winners(environment: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("pull_tabs", {})
	machine["winner_pile"] = []
	states["pull_tabs"] = machine
	environment["game_states"] = states


func _inject_pull_tab_winner(environment: Dictionary, source_result: Dictionary) -> void:
	var states: Dictionary = environment.get("game_states", {})
	var machine: Dictionary = states.get("pull_tabs", {})
	var ticket: Dictionary = source_result.get("pull_tab_ticket", {}).duplicate(true)
	if ticket.is_empty():
		ticket = {
			"id": "test:ticket:001",
			"display_name": "Test Pull Tab",
			"form": "TEST",
			"serial": "001-00001",
			"ticket_number": "#001",
			"rows": [["CHERRY", "CHERRY", "CHERRY"], ["LEMON", "BAR", "7"], ["BELL", "BAR", "CHERRY"]],
			"payout": 5,
			"price": 1,
		}
	ticket["payout"] = maxi(5, int(ticket.get("payout", 0)))
	ticket["sorted"] = true
	ticket["fully_revealed"] = true
	var winners: Array = machine.get("winner_pile", [])
	winners.push_front(ticket)
	machine["winner_pile"] = winners
	states["pull_tabs"] = machine
	environment["game_states"] = states


# Checks production item effects through the foundation ItemEffect contract.
func _check_item_effect_foundation(library: ContentLibrary, failures: Array) -> void:
	var item_def := library.item("instant_coffee")
	if item_def.is_empty():
		failures.append("Production item effect fixture is missing: instant_coffee.")
		return
	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("ITEM-EFFECT-SEED")
	run_b.start_new("ITEM-EFFECT-SEED")
	var context := {
		"domain": "games",
		"domains": ["global", "games"],
		"action_kind": "legal",
		"game_family": "novelty",
		"environment_id": "item_effect_fixture",
	}
	var effect_a := ItemEffect.new()
	var effect_b := ItemEffect.new()
	effect_a.setup(item_def)
	effect_b.setup(item_def)
	var result_a := effect_a.apply(context, run_a)
	var result_b := effect_b.apply(context, run_b)
	_check_item_result_delta_shape(result_a, failures)
	if not bool(result_a.get("applied", false)):
		failures.append("Production item effect did not apply to legal global game context.")
	var modifiers: Dictionary = result_a.get("modifiers", {})
	if int(modifiers.get("win_chance", 0)) < 3:
		failures.append("Production item legal-play modifier did not normalize to win_chance.")
	if int(modifiers.get("loss_reduction", 0)) < 1:
		failures.append("Production item loss-reduction modifier was missing.")
	if result_a.get("deltas", {}).get("item_hooks", []).is_empty():
		failures.append("Production item effect did not contribute an item hook.")
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("Production item effect result was not deterministic.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Production item effect did not leave deterministic RunState snapshots.")
	if JSON.parse_string(JSON.stringify(result_a)) == null:
		failures.append("Production item effect result was not serializable.")

	var family_effect := ItemEffect.new()
	family_effect.setup(library.item("scratch_pad"))
	var family_result := family_effect.apply({"domain": "games", "game_family": "cards", "action_kind": "legal"})
	if int(family_result.get("modifiers", {}).get("win_chance", 0)) < 5:
		failures.append("Game-family item modifier did not apply for matching family.")

	var security_effect := ItemEffect.new()
	security_effect.setup(library.item("cheap_sunglasses"))
	var security_result := security_effect.apply({"domain": "security", "action_kind": "cheat"})
	if int(security_result.get("modifiers", {}).get("suspicion_delta", 0)) >= 0:
		failures.append("Cheating-risk item modifier did not normalize suspicion_delta.")

	var travel_effect := ItemEffect.new()
	travel_effect.setup(library.item("roadside_map"))
	if not travel_effect.applies({"domain": "travel"}):
		failures.append("Travel domain item effect did not apply to travel context.")


# Checks that an existing item creates a visible build trade-off and changes game results through RunState inventory.
func _check_item_build_interaction_foundation(library: ContentLibrary, failures: Array) -> void:
	var item_def := library.item("instant_coffee")
	if item_def.is_empty():
		failures.append("Item build fixture is missing: instant_coffee.")
		return
	var item_effect_data: Dictionary = item_def.get("effect", {}) if typeof(item_def.get("effect", {})) == TYPE_DICTIONARY else {}
	if int(item_effect_data.get("legal_win_chance", 0)) <= 0:
		failures.append("Item build fixture should improve clean-play odds.")
	if int(item_effect_data.get("cheat_suspicion_delta", 0)) <= 0:
		failures.append("Item build fixture should include a risky-action trade-off.")

	var seed := _seed_for_first_roll_between(6, 8)
	if seed.is_empty():
		failures.append("Could not find deterministic item build seed fixture.")
		return
	var environment := {
		"id": "item_build_environment",
		"kind": "fixture",
		"tier": 1,
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 10,
		},
	}
	var game_definition := {
		"id": "item_build_game",
		"display_name": "Item Build Game",
		"family": "novelty",
		"legal_actions": [{"id": "legal_fixture", "label": "Play Clean", "win_chance": 5, "payout_mult": 2}],
		"cheat_actions": [{"id": "risky_fixture", "label": "Try Something Risky", "win_chance": 70, "payout_mult": 2, "suspicion_delta": 2}],
	}

	var baseline_run: RunState = RunStateScript.new()
	var item_run: RunState = RunStateScript.new()
	baseline_run.start_new(seed)
	item_run.start_new(seed)
	var purchase_result := _fixture_item_purchase_result(item_def, 4, str(environment.get("id", "")))
	GameModule.apply_result(item_run, purchase_result)
	if not item_run.inventory.has("instant_coffee"):
		failures.append("Item purchase did not add the item through result-delta inventory.")
	if item_run.bankroll != RunState.DEFAULT_BANKROLL - 4:
		failures.append("Item purchase did not apply item cost through result-delta bankroll.")
	if JSON.parse_string(JSON.stringify(purchase_result)) == null:
		failures.append("Item purchase result was not serializable.")

	var baseline_game := GameModule.new()
	var item_game := GameModule.new()
	baseline_game.setup(game_definition, library)
	item_game.setup(game_definition, library)
	var baseline_result := baseline_game.resolve("legal_fixture", 1, baseline_run, environment, baseline_run.create_rng())
	var item_result := item_game.resolve("legal_fixture", 1, item_run, environment, item_run.create_rng())
	if bool(baseline_result.get("won", false)):
		failures.append("Item build baseline fixture should lose before the clean-play item bonus.")
	if not bool(item_result.get("won", false)):
		failures.append("Item build fixture did not change the legal game result through inventory modifiers.")
	if int(item_result.get("bankroll_delta", 0)) <= int(baseline_result.get("bankroll_delta", 0)):
		failures.append("Item build fixture did not improve the legal game consequence.")

	var cheat_baseline_run: RunState = RunStateScript.new()
	var cheat_item_run: RunState = RunStateScript.new()
	cheat_baseline_run.start_new("ITEM-BUILD-CHEAT")
	cheat_item_run.start_new("ITEM-BUILD-CHEAT")
	GameModule.apply_result(cheat_item_run, _fixture_item_purchase_result(item_def, 4, str(environment.get("id", ""))))
	var cheat_baseline_game := GameModule.new()
	var cheat_item_game := GameModule.new()
	cheat_baseline_game.setup(game_definition, library)
	cheat_item_game.setup(game_definition, library)
	var cheat_baseline_result := cheat_baseline_game.resolve("risky_fixture", 1, cheat_baseline_run, environment, cheat_baseline_run.create_rng())
	var cheat_item_result := cheat_item_game.resolve("risky_fixture", 1, cheat_item_run, environment, cheat_item_run.create_rng())
	if int(cheat_item_result.get("suspicion_delta", 0)) <= int(cheat_baseline_result.get("suspicion_delta", 0)):
		failures.append("Item build fixture did not expose its risky-action trade-off.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_item_build"
	var save_error: Error = save_service.save_run(item_run, slot_id)
	if save_error != OK:
		failures.append("Save service could not save item build state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload item build state.")
		elif not loaded.inventory.has("instant_coffee"):
			failures.append("Item build inventory did not survive SaveService load.")
		elif loaded.bankroll != item_run.bankroll:
			failures.append("Item build bankroll did not survive SaveService load.")
		elif loaded.story_log.size() != item_run.story_log.size():
			failures.append("Item build story state did not survive SaveService load.")


func _seed_for_first_roll_between(min_roll: int, max_roll: int) -> String:
	for index in range(1, 5000):
		var seed := "ITEM-BUILD-%d" % index
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(seed)
		var rng := run_state.create_rng()
		var roll := rng.randi_range(1, 100)
		if roll >= min_roll and roll <= max_roll:
			return seed
	return ""


func _fixture_item_purchase_result(item_definition: Dictionary, price: int, environment_id: String) -> Dictionary:
	var item_id := str(item_definition.get("id", ""))
	var display_name := str(item_definition.get("display_name", item_id))
	var item_effect := ItemEffect.new()
	item_effect.setup(item_definition)
	var effect_result := item_effect.apply({
		"domain": str(item_definition.get("domain", "global")),
		"domains": [str(item_definition.get("domain", "global")), "global"],
		"environment_id": environment_id,
		"action_id": "buy_item",
	})
	var source_deltas: Dictionary = effect_result.get("deltas", {}) if typeof(effect_result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	for key in deltas.keys():
		var value: Variant = source_deltas.get(key, deltas[key])
		if typeof(value) == TYPE_ARRAY:
			deltas[key] = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			deltas[key] = (value as Dictionary).duplicate(true)
		else:
			deltas[key] = value
	deltas["bankroll_delta"] = int(deltas.get("bankroll_delta", 0)) - price
	var inventory_add: Array = deltas.get("inventory_add", [])
	if not inventory_add.has(item_id):
		inventory_add.append(item_id)
	deltas["inventory_add"] = inventory_add
	var message := "Bought %s for %d." % [display_name, price]
	deltas["story_log"] = [{
		"type": "item_purchase",
		"item_id": item_id,
		"item_name": display_name,
		"price": price,
		"environment_id": environment_id,
		"message": message,
	}]
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": bool(effect_result.get("ok", true)),
		"type": "item_effect",
		"source_id": item_id,
		"item_id": item_id,
		"item_effect_id": item_id,
		"action_id": "buy_item",
		"action_kind": "item",
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": message,
	})


# Checks ItemEffect returns the same shared result-delta keys as other modules.
func _check_item_result_delta_shape(result: Dictionary, failures: Array) -> void:
	if str(result.get("type", "")) != "item_effect":
		failures.append("ItemEffect result should identify item_effect results.")
	if str(result.get("item_effect_id", "")).is_empty():
		failures.append("ItemEffect result should include item_effect_id.")
	var deltas: Dictionary = result.get("deltas", {})
	var required_delta_keys := [
		"bankroll_delta",
		"suspicion_delta",
		"debt_changes",
		"inventory_add",
		"inventory_remove",
		"flags_set",
		"travel_hooks_add",
		"travel_changes",
		"story_log",
		"messages",
		"ended",
		"item_hooks",
		"event_hooks",
	]
	for key in required_delta_keys:
		if not deltas.has(key):
			failures.append("ItemEffect deltas missing key: %s." % key)
	for ui_key in ["host", "button_metadata", "overlay_state", "focus", "hover", "ui_state"]:
		if result.has(ui_key) or deltas.has(ui_key):
			failures.append("ItemEffect leaked UI state key: %s." % ui_key)


# Checks direct item deltas are applied through RunState domains.
func _check_item_result_applied(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {})
	var expected_bankroll := int(before.get("bankroll", 0)) + int(deltas.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("RunState bankroll did not match %s." % label)
	var expected_suspicion := clampi(int(before.get("suspicion", 0)) + int(deltas.get("suspicion_delta", 0)), 0, 100)
	if int(run_state.suspicion.get("level", 0)) != expected_suspicion:
		failures.append("RunState suspicion did not match %s." % label)
	var story_delta: Array = deltas.get("story_log", [])
	if run_state.story_log.size() != int(before.get("story_count", 0)) + story_delta.size():
		failures.append("RunState story log did not match %s." % label)
	var debt_delta: Array = deltas.get("debt_changes", [])
	if run_state.debt.size() != int(before.get("debt_count", 0)) + debt_delta.size():
		failures.append("RunState debt did not match %s." % label)


# Checks production event triggering and resolution through EventModule.
func _check_event_module_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	run_a.start_new("EVENT-MODULE-SEED")
	run_b.start_new("EVENT-MODULE-SEED")
	var generator_a: RunGenerator = RunGeneratorScript.new(library)
	var generator_b: RunGenerator = RunGeneratorScript.new(library)
	var environment_a := generator_a.next_environment(run_a).to_dict()
	var environment_b := generator_b.next_environment(run_b).to_dict()
	var event_context := _first_triggerable_event_context(library, run_a, environment_a)
	if event_context.is_empty():
		for target_id in ["corner_store", "back_alley", "motel", "bar", "gas_station_casino", "small_underground_casino", "jazz_club"]:
			environment_a = generator_a.next_environment(run_a, target_id).to_dict()
			environment_b = generator_b.next_environment(run_b, target_id).to_dict()
			event_context = _first_triggerable_event_context(library, run_a, environment_a)
			if not event_context.is_empty():
				break
	if event_context.is_empty():
		failures.append("No generated production event could trigger through EventModule.")
		return
	var event_id := str(event_context.get("event_id", ""))
	var definition := library.event(event_id)
	if definition.is_empty():
		failures.append("Production event was missing from ContentLibrary: %s." % event_id)
		return
	var event_a := EventModule.new()
	var event_b := EventModule.new()
	event_a.setup(definition)
	event_b.setup(definition)
	var trigger_context: Dictionary = event_context.get("context", {})
	if event_a.can_trigger(run_a, environment_a, trigger_context) != event_b.can_trigger(run_b, environment_b, trigger_context):
		failures.append("Production event trigger check was not deterministic.")
	if not event_a.can_trigger(run_a, environment_a, trigger_context):
		failures.append("Production event did not trigger in its generated context: %s." % event_id)
		return
	var choices := event_a.choices()
	if choices.is_empty():
		failures.append("Production event has no choices: %s." % event_id)
		return
	var choice_id := str(choices[0].get("id", ""))
	var before := _run_state_result_snapshot(run_a)
	var result_a := event_a.resolve(run_a, environment_a, choice_id)
	var result_b := event_b.resolve(run_b, environment_b, choice_id)
	_check_event_result_delta_shape(result_a, failures)
	_check_event_result_applied(before, run_a, result_a, "production event result", failures)
	if JSON.stringify(result_a) != JSON.stringify(result_b):
		failures.append("Production event resolution was not deterministic.")
	if JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
		failures.append("Production event resolution did not leave deterministic RunState snapshots.")
	if JSON.parse_string(JSON.stringify(run_a.to_dict())) == null:
		failures.append("Production event RunState result was not serializable.")
	if event_a.can_trigger(run_a, run_a.current_environment, trigger_context):
		failures.append("Resolved production event can still trigger in current RunState environment.")


# Checks events can key off run/system state and alter later choices through result-deltas.
func _check_event_system_state_foundation(library: ContentLibrary, failures: Array) -> void:
	var tip_event_def := library.event("parking_lot_tip")
	if tip_event_def.is_empty():
		failures.append("System-state event fixture is missing: parking_lot_tip.")
		return
	var tip_run: RunState = RunStateScript.new()
	tip_run.start_new("EVENT-SYSTEM-TIP")
	tip_run.set_environment({
		"id": "event_system_shop",
		"kind": "shop",
		"tier": 1,
		"event_ids": ["parking_lot_tip"],
		"resolved_event_ids": [],
		"next_archetypes": ["bar"],
		"travel_hooks": ["small_underground_casino"],
	})
	var underground_route := library.route("small_underground_casino")
	if underground_route.is_empty():
		failures.append("System-state event route fixture is missing: small_underground_casino.")
		return
	if bool(tip_run.travel_route_status(underground_route).get("available", true)):
		failures.append("System-state event route should start locked before the event flag.")
	var tip_event := EventModule.new()
	tip_event.setup(tip_event_def)
	if not tip_event.can_trigger(tip_run, tip_run.current_environment):
		failures.append("Flag-gated travel event should trigger before its unlock flag exists.")
	var tip_before := _run_state_result_snapshot(tip_run)
	var tip_result := tip_event.resolve(tip_run, tip_run.current_environment, "follow_tip")
	_check_event_result_delta_shape(tip_result, failures)
	_check_event_result_applied(tip_before, tip_run, tip_result, "system-state travel event result", failures)
	if not bool(tip_run.narrative_flags.get("underground_tip", false)):
		failures.append("System-state event did not set the travel unlock flag.")
	if not bool(tip_run.travel_route_status(underground_route).get("available", false)):
		failures.append("System-state event outcome did not unlock its downstream travel choice.")
	if tip_event.can_trigger(tip_run, tip_run.current_environment):
		failures.append("System-state event stayed eligible after its blocking flag was set.")

	var side_door_def := library.event("side_door")
	if side_door_def.is_empty():
		failures.append("Side Door cheap-route event fixture is missing.")
	else:
		var route_refresh_run: RunState = RunStateScript.new()
		route_refresh_run.start_new("EVENT-CHEAP-ROUTE-SHOP-REFRESH")
		var route_refresh_generator: RunGenerator = RunGeneratorScript.new(library)
		route_refresh_generator.next_environment(route_refresh_run)
		route_refresh_run.current_environment["kind"] = "casino"
		route_refresh_run.current_environment["event_ids"] = ["side_door"]
		route_refresh_run.current_environment["resolved_event_ids"] = []
		var stale_corner_environment := {
			"id": "stale_corner_store",
			"archetype_id": "corner_store",
			"kind": "shop",
			"item_offers": [{"id": "old_ticket", "price": 1}],
		}
		var stale_motel_environment := {
			"id": "stale_motel",
			"archetype_id": "motel",
			"kind": "shop",
			"item_offers": [{"id": "old_key", "price": 1}],
		}
		route_refresh_run.world_map = WorldMapScript.store_environment(route_refresh_run.world_map, "corner_store", stale_corner_environment)
		route_refresh_run.world_map = WorldMapScript.store_environment(route_refresh_run.world_map, "motel", stale_motel_environment)
		var stale_corner_node := WorldMapScript.node_by_id(route_refresh_run.world_map, "corner_store")
		var stale_motel_node := WorldMapScript.node_by_id(route_refresh_run.world_map, "motel")
		if _copy_dict(stale_corner_node.get("environment", {})).is_empty() or _copy_dict(stale_motel_node.get("environment", {})).is_empty():
			failures.append("Side Door route-refresh fixture could not seed stale shop environments.")
		var side_door_event := EventModule.new()
		side_door_event.setup(side_door_def)
		if not side_door_event.can_trigger(route_refresh_run, route_refresh_run.current_environment):
			failures.append("Side Door cheap-route event did not trigger in the route-refresh fixture.")
		else:
			var cheap_route_before := _run_state_result_snapshot(route_refresh_run)
			var cheap_route_result := side_door_event.resolve(route_refresh_run, route_refresh_run.current_environment, "cheap_route")
			_check_event_result_delta_shape(cheap_route_result, failures)
			_check_event_result_applied(cheap_route_before, route_refresh_run, cheap_route_result, "side-door cheap-route result", failures)
			var corner_after := WorldMapScript.node_by_id(route_refresh_run.world_map, "corner_store")
			var motel_after := WorldMapScript.node_by_id(route_refresh_run.world_map, "motel")
			if not _copy_dict(corner_after.get("environment", {})).is_empty() or not _copy_dict(motel_after.get("environment", {})).is_empty():
				failures.append("Side Door cheap-route choice did not clear stored shop nodes for fresh offers.")

	var debt_event_def := library.event("motel_knock")
	if debt_event_def.is_empty():
		failures.append("Economy-gated event fixture is missing: motel_knock.")
		return
	var stable_run: RunState = RunStateScript.new()
	stable_run.start_new("EVENT-SYSTEM-STABLE")
	stable_run.set_environment({
		"id": "event_system_motel",
		"kind": "shop",
		"tier": 1,
		"event_ids": ["motel_knock"],
		"resolved_event_ids": [],
		"next_archetypes": ["gas_station_casino"],
		"travel_hooks": [],
		"turns": 1,
	})
	var debt_event := EventModule.new()
	debt_event.setup(debt_event_def)
	if debt_event.can_trigger(stable_run, stable_run.current_environment, {"turns": 1}):
		failures.append("Economy-gated event triggered while economy was stable.")

	var strained_run: RunState = RunStateScript.new()
	strained_run.start_new("EVENT-SYSTEM-STRAINED")
	strained_run.change_bankroll(-60)
	strained_run.set_environment(stable_run.current_environment)
	if strained_run.economy() != "volatile":
		failures.append("Event system fixture did not enter volatile economy state.")
	if not debt_event.can_trigger(strained_run, strained_run.current_environment, {"turns": 1}):
		failures.append("Economy-gated event did not trigger from strained economy state.")
	var debt_before := _run_state_result_snapshot(strained_run)
	var debt_result := debt_event.resolve(strained_run, strained_run.current_environment, "borrow")
	_check_event_result_delta_shape(debt_result, failures)
	_check_event_result_applied(debt_before, strained_run, debt_result, "system-state debt event result", failures)
	if strained_run.debt.is_empty():
		failures.append("Economy-gated event did not add debt through result-delta.")
	if strained_run.economy() != "distressed":
		failures.append("Event debt outcome did not affect downstream economy pressure.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_event_system_state"
	var save_error: Error = save_service.save_run(strained_run, slot_id)
	if save_error != OK:
		failures.append("Save service could not save event system state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload event system state.")
		elif loaded.debt.size() != strained_run.debt.size():
			failures.append("Event debt outcome did not survive SaveService load.")
		elif loaded.economy() != strained_run.economy():
			failures.append("Event economy outcome did not survive SaveService load.")
		elif loaded.story_log.size() != strained_run.story_log.size():
			failures.append("Event story outcome did not survive SaveService load.")


# Checks the two-tier event interaction model and brother-in-law chain.
func _check_t4_7_event_interaction_model(library: ContentLibrary, failures: Array) -> void:
	_check_t4_7_validator_contract(library, failures)
	_check_t4_7_environment_generation(library, failures)
	_check_t4_7_interactable_ignore(library, failures)
	_check_t4_7_triggered_queue_round_trip(failures)
	_check_t4_7_chain_determinism(library, failures)
	_check_t4_7_family_loan_contract(library, failures)


func _check_t4_7_validator_contract(library: ContentLibrary, failures: Array) -> void:
	var bad_mode_library := _clone_library_for_validation(library)
	var bad_mode_event := library.event("call_brother_in_law").duplicate(true)
	bad_mode_event["id"] = "t47_bad_mode"
	bad_mode_event["interaction_mode"] = "popup"
	bad_mode_library.events.append(bad_mode_event)
	bad_mode_library.validate()
	if not _validation_errors_contain(bad_mode_library.validation_errors, "unknown interaction_mode"):
		failures.append("T4.7 validator did not reject an unknown interaction_mode.")

	var triggered_prop_library := _clone_library_for_validation(library)
	var triggered_prop_event := library.event("family_loan").duplicate(true)
	triggered_prop_event["id"] = "t47_triggered_prop"
	triggered_prop_event["icon_key"] = "payphone"
	triggered_prop_event["environment_prop"] = "payphone"
	triggered_prop_library.events.append(triggered_prop_event)
	triggered_prop_library.validate()
	if not _validation_errors_contain(triggered_prop_library.validation_errors, "must not declare environment_prop"):
		failures.append("T4.7 validator did not reject triggered event room props.")


func _check_t4_7_environment_generation(library: ContentLibrary, failures: Array) -> void:
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		for sample_index in range(10):
			var run_state: RunState = RunStateScript.new()
			run_state.start_new("T47-GEN-%s-%02d" % [archetype_id.to_upper(), sample_index])
			var environment := EnvironmentInstance.from_archetype(archetype, sample_index, run_state.create_rng("t47_generation"), library)
			var layout: Dictionary = environment.layout
			var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
			for event_id in _string_array(environment.event_ids):
				var event_def := library.event(event_id)
				if str(event_def.get("interaction_mode", "")) != "interactable":
					failures.append("T4.7 generated triggered event as room object: %s in %s." % [event_id, archetype_id])
				if not object_rects.has("event:%s" % event_id):
					failures.append("T4.7 generated event without layout rect: %s in %s." % [event_id, archetype_id])
			if ["corner_store", "motel"].has(archetype_id) and not environment.event_ids.has("call_brother_in_law"):
				failures.append("T4.7 phone-capable environment did not generate call_brother_in_law: %s." % archetype_id)


func _check_t4_7_interactable_ignore(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T47-IGNORE")
	run_state.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], ["call_brother_in_law"], ["bar"]))
	var event_module := EventModule.new()
	event_module.setup(library.event("call_brother_in_law"), library)
	var before := JSON.stringify(run_state.to_dict())
	if not event_module.can_trigger(run_state, run_state.current_environment):
		failures.append("T4.7 interactable phone event was not triggerable in its room context.")
	event_module.choices(run_state, run_state.current_environment)
	var after := JSON.stringify(run_state.to_dict())
	if before != after:
		failures.append("T4.7 inspecting/ignoring an interactable event mutated RunState.")


func _check_t4_7_triggered_queue_round_trip(failures: Array) -> void:
	var pending_run: RunState = RunStateScript.new()
	pending_run.start_new("T47-QUEUE-PENDING")
	pending_run.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], [], ["bar"]))
	pending_run.enqueue_triggered_event("family_loan", "fixture", {"trigger": "chain"})
	var pending_loaded: RunState = RunStateScript.new()
	pending_loaded.from_dict(pending_run.to_dict())
	if pending_loaded.pending_triggered_events.size() != 1 or str((pending_loaded.pending_triggered_events[0] as Dictionary).get("event_id", "")) != "family_loan":
		failures.append("T4.7 pending triggered queue did not survive RunState round-trip.")

	var active_entry := pending_run.begin_triggered_event_resolution(pending_run.next_pending_triggered_event())
	if active_entry.is_empty() or not pending_run.triggered_event_resolution_active():
		failures.append("T4.7 triggered event did not enter active modal resolution.")
	var active_loaded: RunState = RunStateScript.new()
	active_loaded.from_dict(pending_run.to_dict())
	if not active_loaded.triggered_event_resolution_active() or str(active_loaded.active_triggered_event.get("event_id", "")) != "family_loan":
		failures.append("T4.7 active triggered event did not survive RunState round-trip.")
	active_loaded.complete_triggered_event_resolution("family_loan")
	if active_loaded.triggered_event_resolution_active():
		failures.append("T4.7 triggered event modal state did not clear after resolution.")


func _check_talk_decision_system_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TALK-QUEUE")
	run_state.set_environment(_t4_3_fixture_environment("bar", "bar", 1, ["blackjack"], [], ["motel"]))
	var patron := {
		"name": "Mara",
		"mood": "wary",
		"behavior": "watching",
		"silhouette": "coat",
		"hair_color": "#442211",
		"jacket_color": "#224466",
		"tell": "glance",
	}
	var speaker := {
		"role": "patron",
		"name": str(patron.get("name", "")),
		"mood": str(patron.get("mood", "")),
		"behavior": str(patron.get("behavior", "")),
		"silhouette": str(patron.get("silhouette", "")),
		"bind": "table_patron",
		"patron_index": 0,
		"hair_color": str(patron.get("hair_color", "")),
		"jacket_color": str(patron.get("jacket_color", "")),
		"tell": str(patron.get("tell", "")),
	}
	var timing := {
		"expires": true,
		"duration_actions": 2,
		"remaining_actions": 2,
		"timeout_choice_id": "ignore",
	}
	var context := {
		"trigger": "table_approach",
		"type": "table_approach",
		"game_id": "blackjack",
		"hands_played": 2,
		"environment_snapshot": run_state.current_environment.duplicate(true),
	}
	var event_id := "blackjack_counter_probe"
	if library.event(event_id).is_empty():
		failures.append("Talk decision fixture event is missing: %s." % event_id)
		return
	if not run_state.enqueue_triggered_event(event_id, "fixture", context, {"presentation": "talk", "speaker": speaker, "timing": timing}):
		failures.append("Talk decision event could not be enqueued.")
		return
	if run_state.enqueue_triggered_event(event_id, "fixture", context, {"presentation": "talk"}):
		failures.append("Talk decision queue accepted a duplicate event id.")
	var talk_entry := run_state.next_pending_talk_event()
	if str(talk_entry.get("event_id", "")) != event_id or str(talk_entry.get("presentation", "")) != "talk":
		failures.append("Talk decision entry was not exposed through the talk subset.")
	if not run_state.next_pending_triggered_event().is_empty():
		failures.append("Talk decision entry leaked into the modal triggered-event accessor.")
	if not run_state.enqueue_triggered_event("family_loan", "fixture", {"trigger": "manual"}):
		failures.append("Modal fixture event could not be queued behind talk entry.")
	var modal_entry := run_state.next_pending_triggered_event()
	if str(modal_entry.get("event_id", "")) != "family_loan":
		failures.append("Modal triggered-event accessor did not skip the pending talk entry.")
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(run_state.to_dict())
	var loaded_talk := loaded.next_pending_talk_event()
	var loaded_speaker: Dictionary = loaded_talk.get("speaker", {}) if typeof(loaded_talk.get("speaker", {})) == TYPE_DICTIONARY else {}
	var loaded_timing: Dictionary = loaded_talk.get("timing", {}) if typeof(loaded_talk.get("timing", {})) == TYPE_DICTIONARY else {}
	if str(loaded_speaker.get("name", "")) != "Mara" or int(loaded_timing.get("remaining_actions", 0)) != 2:
		failures.append("Talk decision entry did not round-trip speaker/timing state.")
	patron["name"] = "Changed Later"
	if str(loaded_speaker.get("name", "")) != "Mara":
		failures.append("Talk decision speaker snapshot followed later patron mutation.")
	var highlighted := GameModule.patrons_with_talk_focus([patron], loaded_speaker)
	if highlighted.is_empty() or typeof(highlighted[0]) != TYPE_DICTIONARY or not bool((highlighted[0] as Dictionary).get("watching_player", false)):
		failures.append("Talk decision patron focus did not mark the snapshot patron as watching.")
	if bool(patron.get("watching_player", false)):
		failures.append("Talk decision patron focus mutated the source patron dictionary.")
	var first_tick := loaded.advance_focused_talk_event_actions(1)
	if not first_tick.is_empty():
		failures.append("Talk decision timing expired before its action counter was exhausted.")
	var second_tick := loaded.advance_focused_talk_event_actions(1)
	var second_timing: Dictionary = second_tick.get("timing", {}) if typeof(second_tick.get("timing", {})) == TYPE_DICTIONARY else {}
	if str(second_tick.get("event_id", "")) != event_id or str(second_timing.get("timeout_choice_id", "")) != "ignore" or int(second_timing.get("remaining_actions", -1)) != 0:
		failures.append("Talk decision timing did not deterministically expose the timeout choice.")
	loaded.complete_talk_event_resolution(event_id)
	if not loaded.next_pending_talk_event().is_empty():
		failures.append("Talk decision event did not clear after completion.")
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Talk ignore fixture could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("Talk ignore fixture requires FoundationMain runtime nodes.")
		_sb4_dispose_app(app)
		return
	var ignore_run: RunState = RunStateScript.new()
	ignore_run.start_new("TALK-IGNORE-PENALTY")
	ignore_run.set_environment(_t4_3_fixture_environment("bar", "bar", 1, ["blackjack"], [], ["motel"]))
	ignore_run.enqueue_triggered_event(event_id, "fixture", context, {"presentation": "talk", "speaker": speaker, "timing": timing})
	app.set("library", library)
	app.set("run_state", ignore_run)
	app.call("_refresh_talk_dock")
	var dock_snapshot: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(dock_snapshot.get("visible", false)) or not bool(dock_snapshot.get("expanded", false)):
		failures.append("Talk dock did not open as an expanded attention popup.")
	if int(dock_snapshot.get("ignore_penalty_heat", 0)) != 5:
		failures.append("Talk dock did not expose the ignore heat penalty.")
	var before_ignore_heat := ignore_run.suspicion_level()
	app.call("_on_talk_dock_choice_requested", event_id, "ignore")
	if not ignore_run.next_pending_talk_event().is_empty():
		failures.append("Talk explicit ignore did not clear the pending entry.")
	if ignore_run.suspicion_level() < before_ignore_heat + 5:
		failures.append("Talk explicit ignore did not add heat.")
	if _copy_array(ignore_run.current_environment.get("resolved_event_ids", [])).has(event_id):
		failures.append("Talk explicit ignore resolved the event benefit path instead of only applying the penalty.")
	if not _story_log_has_type(ignore_run.story_log, "talk_ignored"):
		failures.append("Talk explicit ignore did not record a story entry.")
	var travel_run: RunState = RunStateScript.new()
	travel_run.start_new("TALK-IGNORE-TRAVEL")
	travel_run.set_environment(_t4_3_fixture_environment("bar", "bar", 1, ["blackjack"], [], ["motel"]))
	travel_run.enqueue_triggered_event(event_id, "fixture", context, {"presentation": "talk", "speaker": speaker, "timing": timing})
	app.set("run_state", travel_run)
	app.set("generator", RunGeneratorScript.new(library))
	app.set("current_game", null)
	var travel_before_heat := travel_run.suspicion_level()
	app.call("_travel_to", "motel", "Motel", {"id": "motel", "label": "Motel", "enabled": true, "route": {"id": "motel", "cost": 0, "distance_blocks": 1}, "travel_minutes": 1})
	if not travel_run.next_pending_talk_event().is_empty():
		failures.append("Travel carried a pending talk entry into the next room.")
	if travel_run.suspicion_level() < travel_before_heat + 5:
		failures.append("Traveling away from pending talk did not add heat.")
	if str(travel_run.current_environment.get("archetype_id", "")) != "motel":
		failures.append("Talk travel-ignore fixture did not arrive at the target room.")
	_sb4_dispose_app(app)


func _check_dialogue_system_foundation(library: ContentLibrary, failures: Array) -> void:
	var dialogue := library.dialogue("pull_tab_clerk")
	if dialogue.is_empty():
		failures.append("Dialogue system pilot fixture is missing pull_tab_clerk.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("DIALOGUE-SYSTEM")
	run_state.set_environment(_t4_3_fixture_environment("corner_store", "shop", 1, ["pull_tabs"], [], ["bar"]))
	var speaker: Dictionary = dialogue.get("speaker", {}) if typeof(dialogue.get("speaker", {})) == TYPE_DICTIONARY else {}
	if not run_state.enqueue_dialogue("pull_tab_clerk", "dialogue:pull_tab_clerk", speaker, "greeting", "fixture", {"trigger": "dialogue"}):
		failures.append("Dialogue system could not enqueue a pilot dialogue.")
		return
	var pending := run_state.next_pending_talk_event()
	if str(pending.get("dialogue_id", "")) != "pull_tab_clerk" or str(pending.get("current_node", "")) != "greeting":
		failures.append("Dialogue queue entry did not expose dialogue_id/current_node.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_pending := restored.next_pending_talk_event()
	if str(restored_pending.get("dialogue_id", "")) != "pull_tab_clerk" or str(restored_pending.get("current_node", "")) != "greeting":
		failures.append("Dialogue queue entry did not round-trip through RunState save/load.")

	var ask_routes := _dialogue_choice_fixture(dialogue, "greeting", "ask_routes")
	if ask_routes.is_empty():
		failures.append("Dialogue pilot ask_routes choice is missing.")
	else:
		var route_effects: Dictionary = ask_routes.get("effects", {}) if typeof(ask_routes.get("effects", {})) == TYPE_DICTIONARY else {}
		var route_event := EventModule.new()
		route_event.setup(_dialogue_test_event_definition("dialogue_route_fixture", "ask_routes", route_effects), library)
		route_event.resolve(run_state, run_state.current_environment, "ask_routes")
		if not bool(run_state.story_flags.get("pull_tab_clerk_route_tip", false)) or not bool(run_state.narrative_flags.get("pull_tab_clerk_route_tip", false)):
			failures.append("Dialogue set_story_flag did not sync story_flags and narrative_flags.")
		if not run_state.unlocked_travel.has("gas_station_casino"):
			failures.append("Dialogue unlock_travel_route did not unlock the route destination.")
		var route_badges := AttributeBadgesScript.for_event_choice({"event_type": "social", "consequences": route_effects})
		var has_story_badge := false
		var has_route_badge := false
		for badge_value in route_badges:
			if typeof(badge_value) != TYPE_DICTIONARY:
				continue
			var badge: Dictionary = badge_value
			has_story_badge = has_story_badge or str(badge.get("glyph_id", "")) == "story"
			has_route_badge = has_route_badge or str(badge.get("glyph_id", "")) == "class_route"
		if not has_story_badge or not has_route_badge:
			failures.append("Dialogue effect badge disclosure did not include story and route badges.")

	var ask_loose := _dialogue_choice_fixture(dialogue, "greeting", "ask_loose")
	if ask_loose.is_empty():
		failures.append("Dialogue pilot ask_loose choice is missing.")
	else:
		var loose_effects: Dictionary = ask_loose.get("effects", {}) if typeof(ask_loose.get("effects", {})) == TYPE_DICTIONARY else {}
		var heat_before := run_state.suspicion_level()
		var loose_event := EventModule.new()
		loose_event.setup(_dialogue_test_event_definition("dialogue_loose_fixture", "ask_loose", loose_effects), library)
		loose_event.resolve(run_state, run_state.current_environment, "ask_loose")
		if run_state.suspicion_level() < heat_before + 2:
			failures.append("Dialogue risky branch did not apply its heat cost.")


func _dialogue_choice_fixture(dialogue: Dictionary, node_id: String, choice_id: String) -> Dictionary:
	var nodes: Dictionary = dialogue.get("nodes", {}) if typeof(dialogue.get("nodes", {})) == TYPE_DICTIONARY else {}
	var node: Dictionary = nodes.get(node_id, {}) if typeof(nodes.get(node_id, {})) == TYPE_DICTIONARY else {}
	var choices: Array = node.get("choices", []) if typeof(node.get("choices", [])) == TYPE_ARRAY else []
	for choice_value in choices:
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return (choice_value as Dictionary).duplicate(true)
	return {}


func _dialogue_test_event_definition(event_id: String, choice_id: String, effects: Dictionary) -> Dictionary:
	return {
		"id": event_id,
		"display_name": "Dialogue Fixture",
		"type": "social",
		"interaction_mode": "triggered",
		"scopes": ["any"],
		"trigger": {"type": "manual"},
		"payload": {
			"choices": [{
				"id": choice_id,
				"label": choice_id,
				"text": choice_id,
				"consequences": effects,
			}],
		},
	}


func _check_t4_7_chain_determinism(library: ContentLibrary, failures: Array) -> void:
	var success_seed := ""
	var failure_seed := ""
	for index in range(200):
		var seed := "T47-CHAIN-%03d" % index
		var triggered := _t4_7_phone_chain_triggers(library, seed)
		if triggered and success_seed.is_empty():
			success_seed = seed
		elif not triggered and failure_seed.is_empty():
			failure_seed = seed
		if not success_seed.is_empty() and not failure_seed.is_empty():
			break
	if success_seed.is_empty() or failure_seed.is_empty():
		failures.append("T4.7 could not find deterministic seeds for both phone-chain branches.")
		return
	if not _t4_7_phone_chain_triggers(library, success_seed):
		failures.append("T4.7 phone-chain success seed did not replay deterministically.")
	if _t4_7_phone_chain_triggers(library, failure_seed):
		failures.append("T4.7 phone-chain miss seed did not replay deterministically.")


func _t4_7_phone_chain_triggers(library: ContentLibrary, seed: String) -> bool:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], ["call_brother_in_law"], ["bar"]))
	var event_module := EventModule.new()
	event_module.setup(library.event("call_brother_in_law"), library)
	event_module.resolve(run_state, run_state.current_environment, "make_call")
	return run_state.pending_triggered_events.size() == 1 and str((run_state.pending_triggered_events[0] as Dictionary).get("event_id", "")) == "family_loan"


func _check_t4_7_family_loan_contract(library: ContentLibrary, failures: Array) -> void:
	var event_run: RunState = RunStateScript.new()
	event_run.start_new("T47-FAMILY-ACCEPT")
	event_run.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], [], ["bar"]))
	event_run.narrative_flags["brother_in_law_phone_ready"] = true
	var event_module := EventModule.new()
	event_module.setup(library.event("family_loan"), library)
	var event_result := event_module.resolve(event_run, event_run.current_environment, "accept")
	if str(event_result.get("conclusion_animation", "")) != "bankroll_transfer":
		failures.append("T4.7 family loan accept did not request bankroll_transfer animation.")
	if event_run.debt.size() != 1 or str((event_run.debt[0] as Dictionary).get("lender_id", "")) != "brother_in_law":
		failures.append("T4.7 family loan accept did not create brother_in_law debt.")
	if not bool(event_run.narrative_flags.get("brother_in_law_loan_used", false)):
		failures.append("T4.7 family loan accept did not set the single-use flag.")
	if bool(event_run.narrative_flags.get("brother_in_law_phone_ready", true)):
		failures.append("T4.7 family loan accept did not clear the phone-ready flag.")

	var lender_run: RunState = RunStateScript.new()
	lender_run.start_new("T47-FAMILY-LENDER")
	lender_run.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], [], ["bar"]))
	lender_run.narrative_flags["brother_in_law_phone_ready"] = true
	var action_service: RunActionService = RunActionServiceScript.new()
	action_service.setup(library, lender_run)
	var lender_result := action_service.hook_result("lender", "brother_in_law")
	GameModule.apply_result(lender_run, lender_result)
	if event_run.bankroll != lender_run.bankroll or JSON.stringify(event_run.debt) != JSON.stringify(lender_run.debt):
		failures.append("T4.7 family loan accept differs from the existing lender-path fixture.")

	var repeat_module := EventModule.new()
	repeat_module.setup(library.event("family_loan"), library)
	if repeat_module.can_trigger(event_run, event_run.current_environment):
		failures.append("T4.7 family loan stayed triggerable after the single-use flag.")

	var deny_run: RunState = RunStateScript.new()
	deny_run.start_new("T47-FAMILY-DENY")
	deny_run.set_environment(_t4_3_fixture_environment("motel", "shop", 1, [], [], ["bar"]))
	deny_run.narrative_flags["brother_in_law_phone_ready"] = true
	var deny_module := EventModule.new()
	deny_module.setup(library.event("family_loan"), library)
	deny_module.resolve(deny_run, deny_run.current_environment, "deny")
	if not deny_run.debt.is_empty():
		failures.append("T4.7 family loan deny created debt.")
	if bool(deny_run.narrative_flags.get("brother_in_law_loan_used", false)):
		failures.append("T4.7 family loan deny set the single-use flag.")
	if bool(deny_run.narrative_flags.get("brother_in_law_phone_ready", true)):
		failures.append("T4.7 family loan deny did not clear the phone-ready flag.")


# Checks T6.7 object visibility classes and deterministic world-event cadence.
func _check_t6_7_visibility_event_cadence(library: ContentLibrary, failures: Array) -> void:
	_check_t6_7_visibility_classes(library, failures)
	_check_t6_7_layout_stability(failures)
	_check_t6_7_event_cadence_state(failures)


func _check_t6_7_visibility_classes(library: ContentLibrary, failures: Array) -> void:
	var shop_environment := _t4_3_fixture_environment("fixture_shop", "shop", 1, [], [], ["bar"])
	shop_environment["object_fixtures"] = ["shopkeeper:merchant"]
	shop_environment["item_offers"] = []
	shop_environment["layout"] = EnvironmentInstance.ensure_generated_layout(shop_environment)
	var object_rects: Dictionary = (shop_environment.get("layout", {}) as Dictionary).get("object_rects", {}) if typeof(shop_environment.get("layout", {})) == TYPE_DICTIONARY else {}
	if not object_rects.has("shopkeeper:merchant"):
		failures.append("T6.7 shopkeeper fixture did not keep a stable layout rect when no offers were present.")

	var hidden_run: RunState = RunStateScript.new()
	hidden_run.start_new("T67-HIDDEN")
	var hidden_environment := _t4_3_fixture_environment("motel", "shop", 1, [], [], ["bar"])
	hidden_environment["lender_hooks"] = ["brother_in_law"]
	hidden_run.set_environment(hidden_environment)
	var hidden_resolver: RunActionService = RunActionServiceScript.new()
	hidden_resolver.setup(library, hidden_run)
	var hidden_option := hidden_resolver.hook_option("lender", "brother_in_law")
	if not bool(hidden_option.get("hidden", false)) or str(hidden_option.get("availability_class", "")) != RunState.AVAILABILITY_CATEGORICAL_UNAVAILABLE:
		failures.append("T6.7 flag-gated brother-in-law lender was not classified as categorically unavailable.")
	if not hidden_resolver.lender_hook_view_list().is_empty():
		failures.append("T6.7 categorically unavailable lender appeared in the lender view list.")
	hidden_run.narrative_flags["brother_in_law_phone_ready"] = true
	if hidden_resolver.lender_hook("brother_in_law").is_empty():
		failures.append("T6.7 brother-in-law lender did not appear once its story flag was set.")

	var poor_run: RunState = RunStateScript.new()
	poor_run.start_new("T67-TRANSIENT")
	poor_run.bankroll = 0
	var service_environment := _t4_3_fixture_environment("bar", "bar", 1, [], [], ["corner_store"])
	service_environment["service_ids"] = ["house_drink"]
	poor_run.set_environment(service_environment)
	var poor_resolver: RunActionService = RunActionServiceScript.new()
	poor_resolver.setup(library, poor_run)
	var service_option := poor_resolver.service_hook("house_drink")
	if service_option.is_empty():
		failures.append("T6.7 unaffordable drink service was hidden instead of visible as transiently blocked.")
	elif bool(service_option.get("enabled", true)) or str(service_option.get("availability_class", "")) != RunState.AVAILABILITY_TRANSIENT_BLOCKED:
		failures.append("T6.7 unaffordable drink service did not report a transient blocked status.")


func _check_t6_7_layout_stability(failures: Array) -> void:
	var environment := _t4_3_fixture_environment("layout_fixture", "shop", 1, ["blackjack"], [], ["bar"])
	environment["object_fixtures"] = ["shopkeeper:merchant"]
	environment["service_ids"] = ["house_drink"]
	environment["lender_hooks"] = ["brother_in_law", "sals_pawn_counter"]
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	var before_rects: Dictionary = (environment.get("layout", {}) as Dictionary).get("object_rects", {}) if typeof(environment.get("layout", {})) == TYPE_DICTIONARY else {}
	var trimmed := environment.duplicate(true)
	trimmed["lender_hooks"] = ["sals_pawn_counter"]
	trimmed["layout"] = EnvironmentInstance.ensure_generated_layout(trimmed)
	var after_rects: Dictionary = (trimmed.get("layout", {}) as Dictionary).get("object_rects", {}) if typeof(trimmed.get("layout", {})) == TYPE_DICTIONARY else {}
	for object_id in ["game:blackjack", "service:house_drink", "lender:sals_pawn_counter", "shopkeeper:merchant"]:
		if JSON.stringify(before_rects.get(object_id, {})) != JSON.stringify(after_rects.get(object_id, {})):
			failures.append("T6.7 hiding one object reflowed %s." % object_id)
	if after_rects.has("lender:brother_in_law"):
		failures.append("T6.7 inactive hidden lender rect was not pruned from generated layout.")


func _check_t6_7_event_cadence_state(failures: Array) -> void:
	var trace_a := _t6_7_cadence_trace("T67-CADENCE-A")
	var trace_b := _t6_7_cadence_trace("T67-CADENCE-A")
	var trace_c := _t6_7_cadence_trace("T67-CADENCE-C")
	if JSON.stringify(trace_a) != JSON.stringify(trace_b):
		failures.append("T6.7 event cadence did not replay deterministically for the same seed.")
	if JSON.stringify(trace_a.get("visit_rolls", [])) == JSON.stringify(trace_c.get("visit_rolls", [])):
		failures.append("T6.7 event cadence did not vary across different seeds.")
	var quiet_rate := float(int(trace_a.get("quiet_visit_count", 0))) / maxf(1.0, float(int(trace_a.get("visit_count", 0))))
	if quiet_rate < 0.40 or quiet_rate > 0.60:
		failures.append("T6.7 quiet visit rate drifted outside 40-60%%: %.2f." % quiet_rate)
	var event_actions: Array = trace_a.get("event_actions", [])
	for index in range(1, event_actions.size()):
		if int(event_actions[index]) - int(event_actions[index - 1]) < RunState.EVENT_CADENCE_GLOBAL_GAP_ACTIONS:
			failures.append("T6.7 event cadence fired inside the six-action global gap.")
			break
	var event_counts_by_visit: Dictionary = trace_a.get("event_counts_by_visit", {})
	for count_value in event_counts_by_visit.values():
		if int(count_value) > 1:
			failures.append("T6.7 event cadence allowed more than one world event in a visit.")
			break
	if not bool(trace_a.get("save_load_round_trip", false)):
		failures.append("T6.7 event cadence state did not survive RunState round-trip.")
	if not bool(trace_a.get("breather_gate", false)):
		failures.append("T6.7 modal breather gate did not require a later action before reopening.")


func _t6_7_cadence_trace(seed: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	var event_actions: Array = []
	var visit_rolls: Array = []
	var event_counts_by_visit: Dictionary = {}
	for visit_index in range(80):
		var environment := _t4_3_fixture_environment("cadence_%02d" % visit_index, "casino", 2, ["blackjack"], [], ["bar"])
		environment["id"] = "t67_cadence_%02d" % visit_index
		run_state.set_environment(environment)
		visit_rolls.append(bool(run_state.event_cadence.get("visit_should_fire", false)))
		var visit_key := str(run_state.event_cadence.get("visit_key", "visit_%02d" % visit_index))
		event_counts_by_visit[visit_key] = 0
		for _action_index in range(8):
			if run_state.event_cadence_allows_world_event("fixture_world_event", "random", "game", {}):
				event_actions.append(int(run_state.event_cadence.get("action_index", 0)))
				event_counts_by_visit[visit_key] = int(event_counts_by_visit.get(visit_key, 0)) + 1
				run_state.event_cadence_note_event_enqueued("fixture_world_event", true)
			run_state.advance_environment_turns(1)
	var saved := run_state.to_dict()
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(saved)
	var cadence_round_trip := JSON.stringify(saved.get("event_cadence", {})) == JSON.stringify(loaded.to_dict().get("event_cadence", {}))
	run_state.event_cadence_note_modal_closed()
	var blocked_same_action := not run_state.event_cadence_can_open_modal()
	run_state.advance_environment_turns(1)
	var opened_after_action := run_state.event_cadence_can_open_modal()
	return {
		"visit_rolls": visit_rolls,
		"visit_count": int(run_state.event_cadence.get("visit_count", 0)),
		"quiet_visit_count": int(run_state.event_cadence.get("quiet_visit_count", 0)),
		"event_actions": event_actions,
		"event_counts_by_visit": event_counts_by_visit,
		"save_load_round_trip": cadence_round_trip,
		"breather_gate": blocked_same_action and opened_after_action,
	}


func _clone_library_for_validation(library: ContentLibrary) -> ContentLibrary:
	var clone: ContentLibrary = ContentLibraryScript.new()
	clone.environment_archetypes = library.environment_archetypes.duplicate(true)
	clone.games = library.games.duplicate(true)
	clone.items = library.items.duplicate(true)
	clone.content_groups = library.content_groups.duplicate(true)
	clone.events = library.events.duplicate(true)
	clone.challenges = library.challenges.duplicate(true)
	clone.lenders = library.lenders.duplicate(true)
	clone.services = library.services.duplicate(true)
	clone.travel_routes = library.travel_routes.duplicate(true)
	return clone


func _validation_errors_contain(errors: Array, needle: String) -> bool:
	for error_value in errors:
		if str(error_value).find(needle) != -1:
			return true
	return false


# Finds the first generated event whose trigger contract is satisfied.
func _first_triggerable_event_context(library: ContentLibrary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var contexts := [
		{},
		{"turns": 999},
		{"trigger": "travel"},
	]
	for event_id in environment.get("event_ids", []):
		var event_def := library.event(str(event_id))
		if event_def.is_empty():
			continue
		var event_module := EventModule.new()
		event_module.setup(event_def)
		for context in contexts:
			if event_module.can_trigger(run_state, environment, context):
				return {
					"event_id": str(event_id),
					"context": context.duplicate(true),
				}
	return {}


# Checks EventModule returns the shared result-delta keys.
func _check_event_result_delta_shape(result: Dictionary, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		failures.append("EventModule returned an unsuccessful result.")
	if str(result.get("type", "")) != "event":
		failures.append("EventModule result should identify event results.")
	if str(result.get("event_id", "")).is_empty():
		failures.append("EventModule result should include event_id.")
	if str(result.get("choice_id", "")).is_empty():
		failures.append("EventModule result should include choice_id.")
	var deltas: Dictionary = result.get("deltas", {})
	var required_delta_keys := [
		"bankroll_delta",
		"suspicion_delta",
		"debt_changes",
		"inventory_add",
		"inventory_remove",
		"flags_set",
		"travel_hooks_add",
		"travel_changes",
		"story_log",
		"messages",
		"ended",
		"item_hooks",
		"event_hooks",
	]
	for key in required_delta_keys:
		if not deltas.has(key):
			failures.append("EventModule deltas missing key: %s." % key)
	if int(result.get("bankroll_delta", 0)) != int(deltas.get("bankroll_delta", 0)):
		failures.append("EventModule top-level bankroll_delta does not match deltas.")
	if int(result.get("suspicion_delta", 0)) != int(deltas.get("suspicion_delta", 0)):
		failures.append("EventModule top-level suspicion_delta does not match deltas.")
	if int(result.get("bankroll_delta", 0)) > 0 and str(result.get("conclusion_animation", "")) != "bankroll_transfer":
		failures.append("EventModule positive bankroll result did not request the bankroll transfer animation.")
	if str(result.get("message", "")).is_empty():
		failures.append("EventModule result should include a player-facing message.")
	if result.get("messages", []).is_empty() or deltas.get("messages", []).is_empty():
		failures.append("EventModule should include messages in the shared delta shape.")
	for ui_key in ["host", "button_metadata", "overlay_state", "focus", "hover", "ui_state"]:
		if result.has(ui_key) or deltas.has(ui_key):
			failures.append("EventModule leaked UI state key: %s." % ui_key)


# Checks event deltas were applied through RunState domains.
func _check_event_result_applied(before: Dictionary, run_state: RunState, result: Dictionary, label: String, failures: Array) -> void:
	if not bool(result.get("ok", false)):
		return
	var deltas: Dictionary = result.get("deltas", {})
	var expected_bankroll := int(before.get("bankroll", 0)) + int(deltas.get("bankroll_delta", 0))
	if run_state.bankroll != expected_bankroll:
		failures.append("RunState bankroll did not match %s." % label)
	var expected_suspicion := clampi(int(before.get("suspicion", 0)) + int(deltas.get("suspicion_delta", 0)), 0, 100)
	if int(run_state.suspicion.get("level", 0)) != expected_suspicion:
		failures.append("RunState suspicion did not match %s." % label)
	var story_delta: Array = deltas.get("story_log", [])
	if run_state.story_log.size() != int(before.get("story_count", 0)) + story_delta.size():
		failures.append("RunState story log did not match %s." % label)
	var debt_delta: Array = deltas.get("debt_changes", [])
	if run_state.debt.size() != int(before.get("debt_count", 0)) + debt_delta.size():
		failures.append("RunState debt did not match %s." % label)
	var flags: Dictionary = deltas.get("flags_set", {})
	for key in flags.keys():
		if run_state.narrative_flags.get(key) != flags[key]:
			failures.append("RunState flags did not match %s." % label)
	var resolved: Array = run_state.current_environment.get("resolved_event_ids", [])
	if not resolved.has(str(result.get("event_id", ""))):
		failures.append("RunState did not record resolved event for %s." % label)


# Checks SaveService as the only foundation run save/load path.
func _check_save_service_foundation_round_trip(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SAVE-SERVICE-SEED", RunState.custom_challenge("save_service_round_trip", "SAVE-SERVICE-SEED", {"fixture": true}))
	run_state.game_clock_minutes = 20 * 60
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var start_environment: EnvironmentInstance = generator.next_environment(run_state)
	var environment_target := _first_target_with_game(library, _unique_strings(start_environment.next_archetypes, start_environment.travel_hooks), "")
	var environment: EnvironmentInstance = generator.next_environment(run_state, environment_target)
	_resolve_first_save_test_action(library, run_state, environment, failures)
	if not library.items.is_empty():
		run_state.add_item(str((library.items[0] as Dictionary).get("id", "")))
	run_state.add_debt({
		"id": "save_service_debt",
		"lender_id": "save_service_fixture",
		"balance": 12,
		"status": "active",
	})
	run_state.narrative_flags["save_service_flag"] = true
	run_state.add_next_archetypes(environment.next_archetypes)
	run_state.log_story({
		"type": "save_service_marker",
		"id": "save_service_round_trip",
		"environment_id": environment.id,
	})

	var expected := _save_service_expected_snapshot(run_state)
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_save_round_trip"
	var save_path := save_service.run_save_path(slot_id)
	_remove_save_slot_files(save_service, slot_id)
	if not save_path.begins_with("%s/" % SaveService.SAVE_DIR) or save_path.contains("demo_save"):
		failures.append("Foundation SaveService path escaped the foundation run save directory.")
	var save_error := save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("SaveService foundation round trip save failed with error %s." % save_error)
		return
	if not save_service.has_run(slot_id):
		failures.append("SaveService did not report saved foundation slot.")
		return
	_check_save_payload_file(save_path, failures)
	var loaded = save_service.load_run(slot_id)
	if loaded == null:
		failures.append("SaveService foundation round trip load returned null.")
		return
	_check_run_state_save_round_trip(expected, loaded.to_dict(), failures)
	_check_save_service_atomic_recovery(failures)


func _check_save_service_atomic_recovery(failures: Array) -> void:
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_save_atomic_recovery"
	_remove_save_slot_files(save_service, slot_id)
	var primary_path := save_service.run_save_path(slot_id)
	var backup_path := save_service.backup_save_path(slot_id)
	var first_run := _save_service_atomic_fixture("SAVE-ATOMIC-FIRST", 137)
	var second_run := _save_service_atomic_fixture("SAVE-ATOMIC-SECOND", 289)
	var first_error := save_service.save_run(first_run, slot_id)
	if first_error != OK:
		failures.append("SaveService atomic fixture first save failed with error %s." % first_error)
		return
	var first_text := FileAccess.get_file_as_string(primary_path)
	var second_error := save_service.save_run(second_run, slot_id)
	if second_error != OK:
		failures.append("SaveService atomic fixture second save failed with error %s." % second_error)
		return
	var second_text := FileAccess.get_file_as_string(primary_path)
	var backup_text := FileAccess.get_file_as_string(backup_path)
	if backup_text != first_text:
		failures.append("SaveService backup rotation did not preserve the first successful save.")
	if second_text == first_text:
		failures.append("SaveService primary did not contain the second successful save after rotation.")
	var loaded_primary = save_service.load_run(slot_id)
	var primary_outcome := save_service.last_load_result()
	if loaded_primary == null or int(loaded_primary.bankroll) != second_run.bankroll:
		failures.append("SaveService primary load did not return the second successful save.")
	if str(primary_outcome.get("outcome", "")) != SaveService.LOAD_OUTCOME_PRIMARY:
		failures.append("SaveService load outcome did not report primary load.")
	_write_user_store_text(primary_path, "{\"schema\":\"truncated\"")
	if FileAccess.get_file_as_string(backup_path) != first_text:
		failures.append("SaveService backup changed after a truncated primary simulation.")
	if not save_service.has_run(slot_id):
		failures.append("SaveService has_run should stay true when a valid backup can recover a corrupt primary.")
	var loaded_backup = save_service.load_run(slot_id)
	var backup_outcome := save_service.last_load_result()
	if loaded_backup == null or int(loaded_backup.bankroll) != first_run.bankroll:
		failures.append("SaveService did not recover the backup when primary was corrupt.")
	if str(backup_outcome.get("outcome", "")) != SaveService.LOAD_OUTCOME_BACKUP:
		failures.append("SaveService load outcome did not report backup recovery.")
	_remove_user_store_file(primary_path)
	if not save_service.has_run(slot_id):
		failures.append("SaveService has_run should be true when only backup exists.")
	var backup_only = save_service.load_run(slot_id)
	if backup_only == null or int(backup_only.bankroll) != first_run.bankroll:
		failures.append("SaveService did not load from a backup-only slot.")
	_remove_user_store_file(backup_path)
	_write_user_store_text(primary_path, "{")
	if save_service.has_run(slot_id):
		failures.append("SaveService has_run should be false for an unrecoverable corrupt primary.")
	var loaded_corrupt = save_service.load_run(slot_id)
	var corrupt_outcome := save_service.last_load_result()
	if loaded_corrupt != null:
		failures.append("SaveService loaded an unrecoverable corrupt primary.")
	if str(corrupt_outcome.get("outcome", "")) != SaveService.LOAD_OUTCOME_NONE:
		failures.append("SaveService corrupt-primary outcome should be nothing-loadable.")
	_remove_save_slot_files(save_service, slot_id)


func _save_service_atomic_fixture(seed: String, bankroll: int) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = bankroll
	run_state.narrative_flags["atomic_fixture"] = seed
	return run_state


func _remove_save_slot_files(save_service: SaveService, slot_id: String) -> void:
	_remove_user_store_file(save_service.run_save_path(slot_id))
	_remove_user_store_file(save_service.backup_save_path(slot_id))


# Checks the local/no-op platform adapter stays outside core gameplay behavior.
func _check_platform_services_foundation(failures: Array) -> void:
	var platform: PlatformServices = PlatformServicesScript.new()
	platform.setup("local_fixture")
	var initialized := platform.initialize()
	_check_platform_payload(initialized, "initialize", failures)
	if not bool(initialized.get("available", false)):
		failures.append("PlatformServices local adapter did not report availability.")

	var daily_a := platform.get_daily_run_id("2026-05-21")
	var daily_b := platform.get_daily_run_id("2026-05-21")
	var daily_c := platform.get_daily_run_id("2026-05-22")
	_check_platform_payload(daily_a, "daily run id", failures)
	if JSON.stringify(daily_a) != JSON.stringify(daily_b):
		failures.append("PlatformServices daily run payload was not deterministic for the same date.")
	if str(daily_a.get("daily_id", "")).is_empty():
		failures.append("PlatformServices daily run payload did not include a daily_id.")
	if str(daily_a.get("daily_id", "")) == str(daily_c.get("daily_id", "")):
		failures.append("PlatformServices daily run payload did not vary by date.")
	var daily_challenge: Dictionary = daily_a.get("challenge_config", {})
	if str(daily_challenge.get("mode", "")) != "daily":
		failures.append("PlatformServices daily payload did not use RunState daily challenge config.")

	var daily_run_a: RunState = RunStateScript.new()
	var daily_run_b: RunState = RunStateScript.new()
	var daily_run_c: RunState = RunStateScript.new()
	daily_run_a.start_new("IGNORED", daily_challenge)
	daily_run_b.start_new("OTHER-IGNORED", daily_b.get("challenge_config", {}))
	daily_run_c.start_new("IGNORED", daily_c.get("challenge_config", {}))
	if JSON.stringify(daily_run_a.to_dict()) != JSON.stringify(daily_run_b.to_dict()):
		failures.append("Daily challenge config did not seed RunState deterministically.")
	if daily_run_a.seed_value == daily_run_c.seed_value:
		failures.append("Different daily challenge payloads did not produce distinct RunState seeds.")

	var custom_challenge := RunState.custom_challenge("local_custom", "CUSTOM-SEED", {"pressure": "low"})
	var custom_run_a: RunState = RunStateScript.new()
	var custom_run_b: RunState = RunStateScript.new()
	custom_run_a.start_new("IGNORED", custom_challenge)
	custom_run_b.start_new("OTHER-IGNORED", RunState.custom_challenge("local_custom", "CUSTOM-SEED", {"pressure": "low"}))
	if JSON.stringify(custom_run_a.to_dict()) != JSON.stringify(custom_run_b.to_dict()):
		failures.append("Custom challenge config did not seed RunState deterministically.")
	var custom_run_c: RunState = RunStateScript.new()
	custom_run_c.start_new("IGNORED", RunState.custom_challenge("local_custom", "CUSTOM-SEED", {"pressure": "high"}))
	if custom_run_a.seed_value == custom_run_c.seed_value:
		failures.append("Different custom challenge modifiers did not affect RunState seed.")

	var score_payload := platform.submit_score("foundation_score", custom_run_a.seed_text, custom_run_a.bankroll)
	_check_platform_payload(score_payload, "score submission", failures)
	if bool(score_payload.get("submitted", true)):
		failures.append("PlatformServices local score submission should be no-op.")
	var daily_score_payload := platform.submit_daily_score(str(daily_a.get("daily_id", "")), custom_run_a.bankroll, daily_challenge)
	_check_platform_payload(daily_score_payload, "daily score submission", failures)
	var daily_score_challenge: Dictionary = daily_score_payload.get("challenge_config", {})
	daily_score_challenge["seed_text"] = "mutated"
	if str(daily_challenge.get("seed_text", "")) == "mutated":
		failures.append("PlatformServices daily score payload leaked mutable challenge config input.")
	var achievement_payload := platform.unlock_achievement("foundation_check")
	_check_platform_payload(achievement_payload, "achievement unlock", failures)
	if bool(achievement_payload.get("unlocked", true)):
		failures.append("PlatformServices local achievement unlock should be no-op.")


func _check_platform_payload(payload: Dictionary, label: String, failures: Array) -> void:
	if not payload.has("ok"):
		failures.append("PlatformServices %s payload is missing ok." % label)
	if str(payload.get("service", "")).is_empty():
		failures.append("PlatformServices %s payload is missing service." % label)
	if str(payload.get("mode", "")) != "local_noop":
		failures.append("PlatformServices %s payload did not stay local/no-op." % label)


# Checks economy labels, bankroll-driven pressure, stake constraints, and save/load.
func _check_economy_pressure_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ECONOMY-PRESSURE")
	if run_state.economy() != "stable":
		failures.append("New RunState economy should start stable.")

	run_state.change_bankroll(-60)
	if run_state.economy() != "volatile":
		failures.append("Bankroll loss did not shift economy pressure to volatile.")
	var volatile_ceiling := run_state.economy_stake_ceiling(30)
	if volatile_ceiling >= 30 or volatile_ceiling != 20:
		failures.append("Volatile economy did not constrain max stake from bankroll pressure.")
	if not run_state.economy_pressure_summary().contains("Volatile"):
		failures.append("Economy pressure summary did not expose the visible volatile label.")

	var environment := {
		"id": "economy_pressure_fixture",
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 30,
		},
	}
	var game := GameModule.new()
	game.setup({
		"id": "economy_pressure_game",
		"display_name": "Economy Pressure Game",
		"family": "fixture",
		"legal_actions": [{"id": "legal_fixture", "label": "Legal Fixture", "win_chance": 45, "payout_mult": 2}],
		"cheat_actions": [],
	}, library)
	var action_view := game.actions(run_state, environment)
	if int(action_view.get("base_stake_ceiling", 0)) != 30:
		failures.append("GameModule did not expose base stake ceiling for economy visibility.")
	if int(action_view.get("economy_stake_ceiling", 0)) != volatile_ceiling:
		failures.append("GameModule action view did not expose the economy pressure recommendation.")
	if int(action_view.get("stake_ceiling", 0)) != 30:
		failures.append("GameModule action stake ceiling should allow wagers up to available bankroll.")
	if not bool(action_view.get("economy_pressure_applied", false)):
		failures.append("GameModule action view did not flag visible economy pressure.")

	var result := game.resolve("legal_fixture", 30, run_state, environment, run_state.create_rng())
	if int(result.get("stake", 0)) != 30:
		failures.append("GameModule resolve did not allow an all-available wager under economy pressure.")

	var distressed_run: RunState = RunStateScript.new()
	distressed_run.start_new("ECONOMY-DISTRESSED")
	distressed_run.change_bankroll(-70)
	distressed_run.add_debt({
		"id": "economy_debt_fixture",
		"lender_id": "street_lender",
		"balance": 10,
		"status": "active",
	})
	if distressed_run.economy() != "distressed":
		failures.append("Debt plus low bankroll did not shift economy pressure to distressed.")
	if distressed_run.economy_stake_ceiling(30) >= volatile_ceiling:
		failures.append("Distressed economy should constrain stake more than volatile economy.")

	var snapshot := distressed_run.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	if restored.economy() != distressed_run.economy():
		failures.append("Economy state did not survive RunState serialization.")
	if restored.economy_stake_ceiling(30) != distressed_run.economy_stake_ceiling(30):
		failures.append("Economy stake pressure did not survive RunState save/load restore.")


# Checks route affordability, flag conditions, cost/risk deltas, and save/load.
func _check_travel_route_foundation(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TRAVEL-ROUTE")
	var available_route := library.route("corner_store")
	if available_route.is_empty():
		failures.append("Travel route fixture is missing: corner_store.")
		return
	var available_status := run_state.travel_route_status(available_route)
	if not bool(available_status.get("available", false)):
		failures.append("Available travel route was unexpectedly disabled.")
	var cost := int(available_status.get("cost", 0))
	if cost <= 0:
		failures.append("Travel cost fixture should apply a nonzero bankroll cost.")
	var suspicion_delta := int(available_status.get("suspicion_delta", 0))
	if str(available_status.get("distance", "")).is_empty():
		failures.append("Travel route status did not expose distance metadata.")
	if int(available_status.get("risk_decay", -1)) < 0:
		failures.append("Travel route status did not expose local heat decay metadata.")
	if not available_status.has("unlock_conditions"):
		failures.append("Travel route status did not expose unlock/route condition metadata.")
	var before_bankroll := run_state.bankroll
	var before_suspicion := int(run_state.suspicion.get("level", 0))
	var result := _fixture_travel_result(run_state, available_route, "corner_store")
	GameModule.apply_result(run_state, result)
	if run_state.bankroll != before_bankroll - cost:
		failures.append("Confirmed travel did not apply route cost through result-delta.")
	if int(run_state.suspicion.get("level", 0)) != before_suspicion + suspicion_delta:
		failures.append("Confirmed travel did not apply route risk through result-delta.")
	if run_state.story_log.is_empty() or str((run_state.story_log[run_state.story_log.size() - 1] as Dictionary).get("type", "")) != "travel":
		failures.append("Confirmed travel did not record a travel story entry.")

	var locked_run: RunState = RunStateScript.new()
	locked_run.start_new("TRAVEL-LOCKED")
	var locked_route := library.route("small_underground_casino")
	if locked_route.is_empty():
		failures.append("Travel route fixture is missing: small_underground_casino.")
		return
	var locked_status := locked_run.travel_route_status(locked_route)
	if bool(locked_status.get("available", true)):
		failures.append("Route condition did not lock a flagged route.")
	if str(locked_status.get("disabled_reason", "")).is_empty():
		failures.append("Locked route did not expose a disabled reason.")
	var locked_conditions: Array = locked_status.get("unlock_conditions", []) if typeof(locked_status.get("unlock_conditions", [])) == TYPE_ARRAY else []
	if locked_conditions.is_empty():
		failures.append("Locked route did not surface unlock conditions.")
	locked_run.narrative_flags["underground_tip"] = true
	var unlocked_status := locked_run.travel_route_status(locked_route)
	if not bool(unlocked_status.get("available", false)):
		failures.append("Route condition did not unlock after the required flag.")

	var poor_run: RunState = RunStateScript.new()
	poor_run.start_new("TRAVEL-POOR")
	poor_run.change_bankroll(-(poor_run.bankroll - 1))
	var costly_route := library.route("bar")
	var poor_status := poor_run.travel_route_status(costly_route)
	if bool(poor_status.get("available", true)):
		failures.append("Unaffordable travel route was not disabled.")

	var boss_route := library.route("grand_casino")
	if boss_route.is_empty():
		failures.append("Travel route fixture is missing: grand_casino.")
	else:
		var boss_run: RunState = RunStateScript.new()
		boss_run.start_new("TRAVEL-GRAND-GATE")
		boss_run.bankroll = 200
		var boss_before_status := boss_run.travel_route_status(boss_route)
		if bool(boss_before_status.get("available", true)) or bool(boss_before_status.get("hidden", true)) or not bool(boss_before_status.get("locked", false)):
			failures.append("Grand Casino route should be visible locked until the run has traveled once.")
		boss_run.environment_history.append({"id": "visited_once", "archetype_id": "corner_store"})
		var boss_after_status := boss_run.travel_route_status(boss_route)
		if bool(boss_after_status.get("available", true)) or bool(boss_after_status.get("hidden", true)) or not bool(boss_after_status.get("locked", false)):
			failures.append("Grand Casino route should stay visible locked until the invitation flag is earned.")
		var world_map := WorldMapScript.new(library)
		var map_data := world_map.build(boss_run, boss_run.create_rng("grand_gate_map"))
		map_data = WorldMapScript.unlock_nodes(map_data, ["grand_casino"], WorldMapScript.DISCOVERY_SOURCE_TRAVEL)
		boss_run.set_world_map(map_data)
		boss_run.narrative_flags["grand_casino_invite"] = true
		var boss_unlocked_status := boss_run.travel_route_status(boss_route)
		if bool(boss_unlocked_status.get("hidden", true)) or not bool(boss_unlocked_status.get("available", false)):
			failures.append("Grand Casino route should be available after travel count, bankroll, and invitation.")

	var back_alley_route := library.route("back_alley")
	if back_alley_route.is_empty():
		failures.append("Travel route fixture is missing: back_alley.")
	else:
		var risk_preview := run_state.travel_route_risk_preview(back_alley_route)
		if risk_preview.is_empty() or int(risk_preview.get("chance_percent", 0)) <= 0:
			failures.append("Back Alley route should expose a deterministic shakedown risk event.")
		var deterministic_a: RunState = RunStateScript.new()
		var deterministic_b: RunState = RunStateScript.new()
		deterministic_a.start_new("TRAVEL-RISK-DETERMINISM")
		deterministic_b.start_new("TRAVEL-RISK-DETERMINISM")
		var risk_a := deterministic_a.travel_route_risk(back_alley_route, "back_alley")
		var risk_b := deterministic_b.travel_route_risk(back_alley_route, "back_alley")
		if JSON.stringify(risk_a) != JSON.stringify(risk_b):
			failures.append("Travel risk resolution was not deterministic for identical run state.")
		var forced_route := back_alley_route.duplicate(true)
		var forced_event: Dictionary = forced_route.get("risk_event", {}) if typeof(forced_route.get("risk_event", {})) == TYPE_DICTIONARY else {}
		forced_event["chance_percent"] = 100
		forced_route["risk_event"] = forced_event
		var forced_run: RunState = RunStateScript.new()
		forced_run.start_new("TRAVEL-RISK-FORCED")
		var forced_before_bankroll := forced_run.bankroll
		var forced_before_heat := forced_run.suspicion_level()
		var forced_risk := forced_run.travel_route_risk(forced_route, "back_alley")
		var forced_result := _fixture_travel_result(forced_run, forced_route, "back_alley", forced_risk)
		GameModule.apply_result(forced_run, forced_result)
		var expected_bankroll := forced_before_bankroll - int(forced_route.get("cost", 0)) + int(forced_risk.get("bankroll_delta", 0))
		var expected_heat := forced_before_heat + int(forced_route.get("suspicion_delta", 0)) + int(forced_risk.get("suspicion_delta", 0))
		if forced_run.bankroll != expected_bankroll:
			failures.append("Travel risk fixture did not apply route cost exactly once with the risk bankroll delta.")
		if forced_run.suspicion_level() != expected_heat:
			failures.append("Travel risk fixture did not apply route heat plus risk heat.")
		if not _story_log_has_type(forced_run.story_log, "travel_risk_event"):
			failures.append("Triggered travel risk did not record a travel_risk_event story entry.")

	var delta_route := library.route("delta_queen")
	var delta_archetype := _archetype_by_id(library, "delta_queen")
	if delta_route.is_empty() or delta_archetype.is_empty():
		failures.append("Travel preview fixtures are missing the Delta Queen route/archetype.")
	else:
		var partial_preview := run_state.travel_route_preview(delta_route, delta_archetype)
		if str(partial_preview.get("level", "")) != "partial":
			failures.append("Default route preview should be partial.")
		if not _string_array(partial_preview.get("game_ids", [])).is_empty():
			failures.append("Partial route preview should not reveal exact generated games.")
		var preview_run: RunState = RunStateScript.new()
		preview_run.start_new("TRAVEL-PREVIEW")
		preview_run.bankroll = 200
		preview_run.set_environment({
			"id": "preview_source",
			"archetype_id": "bar",
			"kind": "casino",
			"display_name": "Preview Source",
			"next_archetypes": ["delta_queen"],
			"travel_hooks": ["delta_queen"],
		})
		var preview_generator: RunGenerator = RunGeneratorScript.new(library)
		var predicted_environment := preview_generator.preview_environment(preview_run, "delta_queen")
		var full_preview := preview_run.travel_route_preview(delta_route, delta_archetype, predicted_environment, true)
		var travel_heat := preview_run.begin_travel_suspicion_decay(delta_route, "delta_queen")
		var actual_environment := preview_generator.next_environment(preview_run, "delta_queen").to_dict()
		preview_run.finish_travel_suspicion_decay(travel_heat)
		if _string_array(full_preview.get("game_ids", [])) != _string_array(actual_environment.get("game_ids", [])):
			failures.append("Scouted route preview games did not match the generated destination.")
		if _string_array(full_preview.get("service_ids", [])) != _string_array(actual_environment.get("service_ids", [])):
			failures.append("Scouted route preview services did not match the generated destination.")
		if int(full_preview.get("travel_locked_actions", 0)) != int(actual_environment.get("travel_locked_actions", 0)):
			failures.append("Scouted route preview did not expose the generated travel lock.")
	var beach_route := library.route("beach")
	var beach_archetype := _archetype_by_id(library, "beach")
	if beach_route.is_empty() or beach_archetype.is_empty():
		failures.append("Beach route/archetype fixture is missing.")
	else:
		if str(beach_route.get("destination_archetype", "")) != "beach":
			failures.append("Beach route does not point to the beach archetype.")
		if int(beach_route.get("cost", -1)) != 3 or str(beach_route.get("distance", "")) != "near" or str(beach_route.get("risk", "")) != "low":
			failures.append("Beach route should be a near, low-risk, low-cost stop.")
		if not _string_array(delta_archetype.get("travel_hooks", [])).has("beach"):
			failures.append("Delta Queen should expose the nearby beach travel hook.")
		if not _string_array(beach_archetype.get("travel_hooks", [])).has("delta_queen"):
			failures.append("Beach should route back to the Delta Queen.")
		if not _string_array(beach_archetype.get("service_pool", [])).has("beach_relax") or not _string_array(beach_archetype.get("service_pool", [])).has("beach_sand_pile"):
			failures.append("Beach should expose relax and sand-pile service hooks.")

	var scout_run: RunState = RunStateScript.new()
	scout_run.start_new("TRAVEL-SCOUTING")
	if scout_run.travel_scouting_level() != 0:
		failures.append("Fresh run should not start with route scouting.")
	scout_run.add_item("roadside_map")
	if scout_run.travel_scouting_level() <= 0:
		failures.append("Roadside Map did not enable full route scouting previews.")
	var service_scout_run: RunState = RunStateScript.new()
	service_scout_run.start_new("TRAVEL-SERVICE-SCOUT")
	var scout_service := library.service("cashier_tip")
	if scout_service.is_empty():
		failures.append("Scouting service fixture is missing: cashier_tip.")
	else:
		var scout_service_result := _fixture_service_result(service_scout_run, scout_service, "cashier_tip")
		GameModule.apply_result(service_scout_run, scout_service_result)
		if service_scout_run.travel_scouting_level() <= 0 or not bool(service_scout_run.narrative_flags.get("route_scouting_active", false)):
			failures.append("Cashier Tip service did not enable saved route scouting.")

	var snapshot := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	if restored.bankroll != run_state.bankroll:
		failures.append("Travel cost state did not survive RunState save/load restore.")
	if int(restored.suspicion.get("level", 0)) != int(run_state.suspicion.get("level", 0)):
		failures.append("Travel risk state did not survive RunState save/load restore.")
	if restored.story_log.size() != run_state.story_log.size():
		failures.append("Travel story state did not survive RunState save/load restore.")


func _enabled_world_route_ids_for_run(library: ContentLibrary, run_state: RunState, source_id: String) -> Array:
	var result: Array = []
	if run_state == null or not run_state.has_world_map():
		return result
	var map := WorldMapScript.new(library)
	for target_id_value in WorldMapScript.visible_node_ids(run_state.world_map):
		var target_id := str(target_id_value)
		if target_id == source_id or not WorldMapScript.has_path(run_state.world_map, source_id, target_id, true):
			continue
		var route := map.route_for_target(run_state.world_map, source_id, target_id)
		if route.is_empty():
			continue
		var status := run_state.travel_route_status(route)
		if not bool(status.get("hidden", false)) and (bool(status.get("available", true)) or bool(status.get("locked", false))):
			result.append(target_id)
	return result


func _check_world_map_foundation(library: ContentLibrary, failures: Array) -> void:
	var generator: RunGenerator = RunGeneratorScript.new(library)
	var run_a: RunState = RunStateScript.new()
	run_a.start_new("WORLD-MAP-SEED")
	var start_environment := generator.next_environment(run_a)
	if not run_a.has_world_map():
		failures.append("New runs should create a persistent world_map on first environment generation.")
		return
	var start_node_id := run_a.current_world_node_id()
	if start_node_id.is_empty() or start_node_id != str(run_a.current_environment.get("world_node_id", "")) or str(start_environment.archetype_id) != start_node_id:
		failures.append("Generated start environment did not sync to the current world map node.")
	var snapshot := WorldMapScript.snapshot(run_a.world_map)
	var visible_ids := _string_array(snapshot.get("visible_node_ids", []))
	if visible_ids.size() < 2:
		failures.append("World map should spawn-discover at least one travelable stop from the start node.")
	if _world_map_hidden_count(run_a.world_map) <= 0:
		failures.append("World map should keep distant nodes hidden before discovery.")
	if not _world_map_visible_ids_have_sources(run_a.world_map):
		failures.append("World map visible nodes must be visited, event-unlocked, or discovered at spawn.")
	var initial_leaks := _world_map_snapshot_hidden_leaks(run_a.world_map, snapshot)
	if not initial_leaks.is_empty():
		failures.append("World map snapshot leaked hidden node data at start: %s." % ", ".join(initial_leaks))
	if not _world_map_snapshot_icons_match_positions(run_a.world_map, snapshot):
		failures.append("World map snapshot icons did not preserve generated node positions.")
	var travel_targets := WorldMapScript.travel_target_ids(run_a.world_map, start_node_id)
	if travel_targets.is_empty():
		failures.append("World map should expose at least one capped travel target from the start node.")
	if travel_targets.size() > WorldMapScript.TRAVEL_TOTAL_TARGET_LIMIT:
		failures.append("World map exposed too many start travel targets: %d." % travel_targets.size())
	if _world_map_target_new_count(run_a.world_map, travel_targets) > WorldMapScript.TRAVEL_NEW_TARGET_LIMIT:
		failures.append("World map exposed more than two new travel targets from the start node.")
	if _string_array(run_a.current_environment.get("travel_hooks", [])) != travel_targets or _string_array(run_a.current_environment.get("next_archetypes", [])) != travel_targets:
		failures.append("Current environment travel hooks should mirror capped world-map travel targets.")
	var layout: Dictionary = run_a.current_environment.get("layout", {}) if typeof(run_a.current_environment.get("layout", {})) == TYPE_DICTIONARY else {}
	var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
	if not object_rects.has("travel:leave"):
		failures.append("World-map rooms should expose a single travel:leave layout object.")
	for target_id in travel_targets:
		if object_rects.has("travel:%s" % str(target_id)):
			failures.append("World-map rooms should not expose per-destination travel object travel:%s." % str(target_id))
			break
	for tip_seed_index in range(20):
		var tip_run: RunState = RunStateScript.new()
		tip_run.start_new("WORLD-MAP-UNDERGROUND-TIP-%02d" % tip_seed_index)
		generator.next_environment(tip_run)
		var underground_id := WorldMapScript.UNDERGROUND_SHORTCUT_ID
		if WorldMapScript.visible_node_ids(tip_run.world_map).has(underground_id):
			failures.append("World map showed the underground casino before the parking lot tip for seed %02d." % tip_seed_index)
			break
		tip_run.narrative_flags["underground_tip"] = true
		tip_run.add_next_archetypes([underground_id])
		if not WorldMapScript.visible_node_ids(tip_run.world_map).has(underground_id):
			failures.append("Parking lot tip did not reveal the underground casino for seed %02d." % tip_seed_index)
			break
		var tipped_targets := WorldMapScript.travel_target_ids(tip_run.world_map, tip_run.current_world_node_id(), WorldMapScript.TRAVEL_NEW_TARGET_LIMIT, WorldMapScript.TRAVEL_TOTAL_TARGET_LIMIT, [underground_id])
		if not tipped_targets.has(underground_id):
			failures.append("Parking lot tip did not make the underground casino a selectable map target for seed %02d." % tip_seed_index)
			break
		var tipped_route := WorldMapScript.new(library).route_for_target(tip_run.world_map, tip_run.current_world_node_id(), underground_id)
		if tipped_route.is_empty():
			failures.append("Parking lot tip revealed the underground casino without a usable map route for seed %02d." % tip_seed_index)
			break

	var run_b: RunState = RunStateScript.new()
	run_b.start_new("WORLD-MAP-SEED")
	generator.next_environment(run_b)
	if JSON.stringify(run_a.world_map) != JSON.stringify(run_b.world_map):
		failures.append("World map generation should be deterministic for the same seed.")
	var run_c: RunState = RunStateScript.new()
	run_c.start_new("WORLD-MAP-OTHER-SEED")
	generator.next_environment(run_c)
	if JSON.stringify(_world_map_positions(run_a.world_map)) == JSON.stringify(_world_map_positions(run_c.world_map)):
		failures.append("World map node layout should vary across different seeds.")

	for leak_seed_index in range(20):
		var leak_run: RunState = RunStateScript.new()
		leak_run.start_new("WORLD-MAP-FOG-%02d" % leak_seed_index)
		generator.next_environment(leak_run)
		var hidden_selected_id := _first_hidden_world_node_id(leak_run.world_map)
		var leak_snapshot := WorldMapScript.snapshot(leak_run.world_map, hidden_selected_id)
		var leaked_ids := _world_map_snapshot_hidden_leaks(leak_run.world_map, leak_snapshot)
		if not hidden_selected_id.is_empty() and str(leak_snapshot.get("selected_node_id", "")) == hidden_selected_id:
			leaked_ids.append("selected:%s" % hidden_selected_id)
		if not leaked_ids.is_empty():
			failures.append("World map fog leak for seed %02d: %s." % [leak_seed_index, ", ".join(leaked_ids)])
			break

	var hidden_unlock_id := _first_hidden_world_node_id(run_a.world_map)
	if hidden_unlock_id.is_empty():
		failures.append("World map event-unlock fixture could not find a hidden node.")
	else:
		var before_unlock_snapshot := WorldMapScript.snapshot(run_a.world_map)
		if _string_array(before_unlock_snapshot.get("visible_node_ids", [])).has(hidden_unlock_id):
			failures.append("World map event-unlock fixture started with the hidden target visible.")
		run_a.add_next_archetypes([hidden_unlock_id])
		var after_unlock_snapshot := WorldMapScript.snapshot(run_a.world_map)
		if not _string_array(after_unlock_snapshot.get("visible_node_ids", [])).has(hidden_unlock_id):
			failures.append("World map event grant did not reveal %s without re-entering the map." % hidden_unlock_id)
		var unlocked_node := WorldMapScript.node_by_id(run_a.world_map, hidden_unlock_id)
		if not bool(unlocked_node.get("unlocked", false)) or str(unlocked_node.get("discovery_source", "")) != WorldMapScript.DISCOVERY_SOURCE_EVENT:
			failures.append("World map event grant did not mark %s with event discovery metadata." % hidden_unlock_id)

	for seed_index in range(50):
		var reach_run: RunState = RunStateScript.new()
		reach_run.start_new("WORLD-MAP-REACH-%02d" % seed_index)
		generator.next_environment(reach_run)
		var hops := _world_map_hops_to(reach_run.world_map, reach_run.current_world_node_id(), RunState.GRAND_CASINO_ARCHETYPE_ID)
		if hops < 0 or hops > 6:
			failures.append("World map reachability failed for seed %02d: Grand Casino hops=%d." % [seed_index, hops])
			break

	for policy_seed_index in range(20):
		var policy_run: RunState = RunStateScript.new()
		policy_run.start_new("WORLD-MAP-POLICY-%02d" % policy_seed_index)
		generator.next_environment(policy_run)
		var policy_targets := WorldMapScript.travel_target_ids(policy_run.world_map, policy_run.current_world_node_id())
		if policy_targets.size() > WorldMapScript.TRAVEL_TOTAL_TARGET_LIMIT:
			failures.append("World map target policy exceeded total cap for seed %02d." % policy_seed_index)
			break
		if _world_map_target_new_count(policy_run.world_map, policy_targets) > WorldMapScript.TRAVEL_NEW_TARGET_LIMIT:
			failures.append("World map target policy exceeded new-target cap for seed %02d." % policy_seed_index)
			break
		var reachable_new := _world_map_reachable_visible_new_ids(policy_run.world_map, policy_run.current_world_node_id())
		if reachable_new.size() >= WorldMapScript.TRAVEL_NEW_TARGET_LIMIT and _world_map_target_new_count(policy_run.world_map, policy_targets) != WorldMapScript.TRAVEL_NEW_TARGET_LIMIT:
			failures.append("World map target policy did not offer two new destinations for seed %02d." % policy_seed_index)
			break

	for beach_seed_index in range(50):
		var beach_run: RunState = RunStateScript.new()
		beach_run.start_new("WORLD-MAP-BEACH-%02d" % beach_seed_index)
		generator.next_environment(beach_run)
		if not _world_map_beach_delta_adjacency_ok(beach_run.world_map, "seed %02d" % beach_seed_index, failures):
			break
		if not _world_map_beach_route_gate_ok(beach_run.world_map, "seed %02d" % beach_seed_index, library, failures):
			break

	if travel_targets.is_empty():
		failures.append("World map revisit fixture could not find a neighboring destination.")
		return
	var first_target := str(travel_targets[0])
	var first_route := generator.world_route_for_target(run_a, first_target)
	if first_route.is_empty() or not bool(first_route.get("generated_world_route", false)):
		failures.append("World route should merge generated edge metadata for visible targets.")
	var travel_heat := run_a.begin_travel_suspicion_decay(first_route, first_target)
	generator.next_environment(run_a, first_target)
	run_a.finish_travel_suspicion_decay(travel_heat)
	var visited_node_id := run_a.current_world_node_id()
	run_a.current_environment["game_states"] = _copy_dict(run_a.current_environment.get("game_states", {}))
	run_a.current_environment["game_states"]["world_map_fixture"] = {"remaining": 1, "top_prize_claimed": false}
	var return_targets := WorldMapScript.travel_target_ids(run_a.world_map, visited_node_id)
	if not return_targets.has(start_node_id):
		failures.append("Visited world-map node did not offer the previous stop as a return target.")
	for visited_id_value in _world_map_visited_ids(run_a.world_map):
		var visited_id := str(visited_id_value)
		if visited_id != visited_node_id and not return_targets.has(visited_id):
			failures.append("World map did not expose visited node %s as a revisit target from %s." % [visited_id, visited_node_id])
			break
	var return_route := generator.world_route_for_target(run_a, start_node_id)
	if _string_array(return_route.get("world_path", [])).size() < 2:
		failures.append("Return world-map route did not include a visible path.")
	var return_cost := int(return_route.get("cost", 0))
	if return_cost <= 0 and int(return_route.get("distance_blocks", 0)) > 0:
		failures.append("Return world-map route did not charge a distance-based cost.")
	var bankroll_before_return := run_a.bankroll
	var return_heat := run_a.begin_travel_suspicion_decay(return_route, start_node_id)
	generator.next_environment(run_a, start_node_id)
	run_a.finish_travel_suspicion_decay(return_heat)
	GameModule.apply_result(run_a, _world_map_travel_charge_result(start_node_id, return_cost))
	if run_a.bankroll != bankroll_before_return - return_cost:
		failures.append("Return world-map travel did not charge the generated edge cost.")
	var revisit_route := generator.world_route_for_target(run_a, visited_node_id)
	var revisit_heat := run_a.begin_travel_suspicion_decay(revisit_route, visited_node_id)
	generator.next_environment(run_a, visited_node_id)
	run_a.finish_travel_suspicion_decay(revisit_heat)
	var restored_game_states: Dictionary = run_a.current_environment.get("game_states", {}) if typeof(run_a.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var fixture_state: Dictionary = restored_game_states.get("world_map_fixture", {}) if typeof(restored_game_states.get("world_map_fixture", {})) == TYPE_DICTIONARY else {}
	if int(fixture_state.get("remaining", 0)) != 1 or bool(fixture_state.get("top_prize_claimed", true)):
		failures.append("Revisiting a world-map node did not restore stored local game state.")
	var save_snapshot := run_a.to_dict()
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(save_snapshot)
	if JSON.stringify(loaded.world_map) != JSON.stringify(run_a.world_map):
		failures.append("World map graph/discovery/path state did not survive RunState save/load.")
	_check_unique_object_layout_classes(library, failures)


func _check_meta_home_run_boundary(library: ContentLibrary, failures: Array) -> void:
	var service: Variant = MetaCollectionServiceScript.new()
	var modifiers: Dictionary = service.normal_run_start_modifiers()
	var config: Dictionary = RunStateScript.standard_challenge("META-HOME-BOUNDARY")
	config["modifiers"] = modifiers
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("META-HOME-BOUNDARY", config)
	if not run_state.meta_collection_enabled_for_run():
		failures.append("Standard run with meta modifiers did not enable the meta collection boundary.")
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	if str(run_state.current_environment.get("archetype_id", run_state.current_environment.get("id", ""))) != MetaCollectionServiceScript.HOUSING_BACK_ALLEY:
		failures.append("Default homeless meta run did not start in the back alley archetype.")
	var daily: RunState = RunStateScript.new()
	daily.start_new("META-HOME-DAILY", RunStateScript.daily_challenge("meta_home_daily", "META-HOME-DAILY", true))
	daily.run_status = RunStateScript.RUN_STATUS_ENDED
	var drop_service: Variant = CollectionDropServiceScript.new()
	if not drop_service.ensure_run_end_pending_bags(daily, null).is_empty():
		failures.append("Daily run created meta collection pending bags.")
	if not _copy_array(drop_service.flush_pending_bags(daily, service).get("granted", [])).is_empty():
		failures.append("Daily run flushed meta collection bags.")


func _check_meta_home_fresh_store_defaults(failures: Array) -> void:
	var previous_path := OS.get_environment(MetaCollectionServiceScript.STORE_PATH_ENV)
	var test_path := "user://foundation_check_fresh_meta_collection.json"
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, test_path)
	_remove_user_store_file(test_path)
	var service: Variant = MetaCollectionServiceScript.new()
	var fresh: Dictionary = service.load()
	if not _copy_array(fresh.get("owned_instances", [])).is_empty():
		failures.append("Fresh meta store must start with zero owned item instances.")
	if not _copy_array(fresh.get("unopened_bags", [])).is_empty():
		failures.append("Fresh meta store must start with zero unopened bags.")
	if int(fresh.get("gold_balance", -1)) != 0:
		failures.append("Fresh meta store must start with zero gold.")
	if str(fresh.get("housing_tier", "")) != MetaCollectionServiceScript.HOUSING_BACK_ALLEY:
		failures.append("Fresh meta store must start at back alley housing.")
	var containers := _copy_array(fresh.get("owned_containers", []))
	if containers.size() != 1:
		failures.append("Fresh meta store must contain exactly one starter container.")
	else:
		var container := _copy_dict(containers[0])
		if str(container.get("item_id", "")) != "bag" or int(container.get("capacity", 0)) != 3:
			failures.append("Fresh meta store starter container should be the empty spawn bag.")
	if int(fresh.get("next_instance_id", 0)) != MetaCollectionServiceScript.FIRST_INSTANCE_ID:
		failures.append("Fresh meta store next_instance_id should not advance without grants.")
	var save_error: Error = service.save()
	if save_error != OK:
		failures.append("Fresh meta store save failed with error %d." % int(save_error))
	var reloaded_service: Variant = MetaCollectionServiceScript.new()
	var reloaded: Dictionary = reloaded_service.load()
	if not _copy_array(reloaded.get("owned_instances", [])).is_empty() or not _copy_array(reloaded.get("unopened_bags", [])).is_empty():
		failures.append("Fresh meta store persisted phantom owned items or bags.")
	_remove_user_store_file(test_path)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, previous_path)


func _check_meta_home_fixture_pollution_migration(failures: Array) -> void:
	var previous_path := OS.get_environment(MetaCollectionServiceScript.STORE_PATH_ENV)
	var polluted_path := "user://foundation_check_polluted_meta_collection.json"
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, polluted_path)
	_remove_user_store_file(polluted_path)
	_write_user_store_file(polluted_path, {
		"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
		"gold_balance": 6,
		"housing_tier": MetaCollectionServiceScript.HOUSING_BACK_ALLEY,
		"owned_containers": [{"item_id": "bag", "instance_id": 1, "capacity": 3}],
		"owned_instances": [{
			"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
			"instance_id": 112,
			"itemdef_id": 2007,
			"state": {"condition": 1.0},
		}],
		"unopened_bags": [{
			"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
			"instance_id": 113,
			"bagdef_id": 1,
			"rng_seed": "UI-VICTORY-SEED|ended|run_victory|run_victory|9010|123456",
			"source": "run_victory",
			"source_id": "UI-RUN-MENU-VICTORY",
			"marker_id": "UI-DRY-RUN-SEED",
		}],
		"sale_history": [{"kind": "bag", "instance_id": 110}],
		"next_instance_id": 114,
	})
	var polluted_service: Variant = MetaCollectionServiceScript.new()
	var migrated: Dictionary = polluted_service.load()
	if not _copy_array(migrated.get("owned_instances", [])).is_empty():
		failures.append("Fixture-polluted meta store should quarantine legacy owned item instances.")
	if not _copy_array(migrated.get("unopened_bags", [])).is_empty():
		failures.append("Fixture-polluted meta store should quarantine UI/test unopened bags.")
	if int(migrated.get("gold_balance", -1)) != 0:
		failures.append("Fixture-only meta store should reset gold to zero after quarantine.")
	if not bool(migrated.get(MetaCollectionServiceScript.FIXTURE_POLLUTION_MIGRATION_FLAG, false)):
		failures.append("Fixture-polluted meta store did not persist the quarantine migration flag.")
	var quarantine := _copy_dict(migrated.get("quarantined_records", {}))
	if _copy_array(quarantine.get("fixture_bags", [])).is_empty():
		failures.append("Fixture-polluted meta store did not preserve quarantined bag evidence.")
	if _copy_array(quarantine.get("fixture_instances", [])).is_empty():
		failures.append("Fixture-polluted meta store did not preserve quarantined instance evidence.")
	var persisted_service: Variant = MetaCollectionServiceScript.new()
	var persisted: Dictionary = persisted_service.load()
	if not _copy_array(persisted.get("owned_instances", [])).is_empty() or not _copy_array(persisted.get("unopened_bags", [])).is_empty():
		failures.append("Fixture-polluted meta store quarantine did not survive reload.")
	_remove_user_store_file(polluted_path)

	var earned_path := "user://foundation_check_earned_meta_collection.json"
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, earned_path)
	_remove_user_store_file(earned_path)
	var earned_seed := "PLAYER-SEED|ended|run_victory|run_victory|9010|123456"
	_write_user_store_file(earned_path, {
		"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
		"gold_balance": 12,
		"housing_tier": MetaCollectionServiceScript.HOUSING_BACK_ALLEY,
		"owned_containers": [{"item_id": "bag", "instance_id": 1, "capacity": 3}],
		"owned_instances": [{
			"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
			"instance_id": 11,
			"itemdef_id": 2007,
			"source": "run_victory",
			"source_id": "run_victory",
			"source_rng_seed": earned_seed,
			"state": {"condition": 1.0},
		}],
		"unopened_bags": [{
			"schema_version": MetaCollectionServiceScript.SCHEMA_VERSION,
			"instance_id": 12,
			"bagdef_id": 1,
			"rng_seed": earned_seed,
			"source": "run_victory",
			"source_id": "run_victory",
		}],
		"next_instance_id": 13,
	})
	var earned_service: Variant = MetaCollectionServiceScript.new()
	var earned: Dictionary = earned_service.load()
	if _copy_array(earned.get("owned_instances", [])).size() != 1:
		failures.append("Earned meta item with real provenance was incorrectly quarantined.")
	if _copy_array(earned.get("unopened_bags", [])).size() != 1:
		failures.append("Earned meta bag with real provenance was incorrectly quarantined.")
	if int(earned.get("gold_balance", -1)) != 12:
		failures.append("Earned meta store gold changed during fixture quarantine check.")
	if bool(earned.get(MetaCollectionServiceScript.FIXTURE_POLLUTION_MIGRATION_FLAG, false)):
		failures.append("Clean earned meta store should not receive the fixture quarantine flag.")
	_remove_user_store_file(earned_path)
	OS.set_environment(MetaCollectionServiceScript.STORE_PATH_ENV, previous_path)


func _check_time_open_hours_foundation(library: ContentLibrary, failures: Array) -> void:
	var bar_archetype := _archetype_by_id(library, "bar")
	if bar_archetype.is_empty():
		failures.append("Time-system fixture is missing bar archetype.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TIME-OPEN-HOURS")
	var environment := EnvironmentInstance.from_archetype(bar_archetype, 1, run_state.create_rng("time_open_hours"), library)
	run_state.set_environment(environment.to_dict())
	run_state.game_clock_minutes = 0
	if run_state.clock_display_text(true) != "Day 1 12 AM":
		failures.append("Clock display should render midnight as Day 1 12 AM.")
	run_state.game_clock_minutes = 12 * 60
	if run_state.clock_display_text(true) != "Day 1 12 PM":
		failures.append("Clock display should render noon as Day 1 12 PM.")
	run_state.game_clock_minutes = 24 * 60
	if run_state.clock_display_text(true) != "Day 2 12 AM":
		failures.append("Clock display should roll over to Day 2 at midnight.")
	var action_clock_before := run_state.game_clock_minutes
	run_state.advance_environment_turns(2)
	if run_state.game_clock_minutes != action_clock_before + RunState.ACTION_CLOCK_MINUTES * 2:
		failures.append("Environment actions should advance the game clock by the action clock cost.")
	run_state.game_clock_minutes = (24 + 3) * 60
	if EnvironmentHoursScript.environment_open_at(bar_archetype, run_state.game_minute_of_day()):
		failures.append("Bar should be closed at its 3 AM boundary.")
	var closing_state := run_state.begin_closing_time(run_state.current_environment, run_state.game_minute_of_day())
	if str(closing_state.get("phase", "")) != RunState.CLOSING_TIME_PHASE_GRACE or int(closing_state.get("grace_actions_remaining", -1)) != RunState.CLOSING_TIME_DEFAULT_GRACE_ACTIONS:
		failures.append("Closing-time state did not start in one-action grace.")
	var loaded: RunState = RunStateScript.new()
	loaded.from_dict(run_state.to_dict())
	if JSON.stringify(loaded.closing_time_status()) != JSON.stringify(run_state.closing_time_status()):
		failures.append("Closing-time grace state did not survive save/load.")
	var spent := loaded.spend_closing_time_grace_action()
	if str(spent.get("phase", "")) != RunState.CLOSING_TIME_PHASE_FORCED_TRAVEL:
		failures.append("Closing-time grace did not transition to forced travel after one action.")
	loaded.bankroll = 0
	var terminal := RunTerminalEvaluatorScript.evaluate(loaded, library)
	if bool(terminal.get("failed", false)) or not bool(terminal.get("travel_available", false)):
		failures.append("Broke forced-closing travel should defer bankroll-zero failure and keep travel available.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(loaded.to_dict())
	if not restored.closing_time_forced_travel_required():
		failures.append("Forced closing travel state did not survive save/load.")
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("Closing-time travel fixture could not instantiate FoundationMain.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("Closing-time travel fixture requires FoundationMain runtime nodes.")
		_sb4_dispose_app(app)
		return
	var ui_run: RunState = RunStateScript.new()
	ui_run.start_new("TIME-OPEN-HOURS-UI")
	ui_run.bankroll = 100
	var ui_environment := EnvironmentInstance.from_archetype(bar_archetype, 2, ui_run.create_rng("time_open_hours_ui"), library).to_dict()
	ui_environment["next_archetypes"] = ["motel"]
	ui_environment["travel_hooks"] = []
	ui_environment["layout"] = EnvironmentInstance.ensure_generated_layout(ui_environment)
	ui_run.set_environment(ui_environment)
	ui_run.game_clock_minutes = (24 + 3) * 60
	ui_run.begin_closing_time(ui_run.current_environment, ui_run.game_minute_of_day())
	ui_run.spend_closing_time_grace_action()
	app.set("run_state", ui_run)
	app.set("current_game", null)
	app.set("last_hook_result", {})
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	if not bool(app.call("open_world_map", true)):
		failures.append("Closing-time forced travel could not open the map.")
	var selected_ok := bool(app.call("select_world_map_node", "motel"))
	if not selected_ok:
		failures.append("Closing-time forced travel could not select the motel route.")
	var selected_node := str(app.get("selected_world_map_node_id"))
	var selected_target := str(app.get("selected_travel_target_id"))
	if selected_node != "motel" or selected_target != "motel":
		failures.append("Closing-time forced travel selection did not arm the route: node=%s target=%s." % [selected_node, selected_target])
	var travel_clock_before := ui_run.game_clock_minutes
	app.call("confirm_world_map_travel")
	if str(ui_run.current_environment.get("archetype_id", "")) != "motel":
		failures.append("Closing-time map Travel button did not leave the closed venue; current=%s selected_node=%s selected_target=%s." % [
			str(ui_run.current_environment.get("archetype_id", "")),
			str(app.get("selected_world_map_node_id")),
			str(app.get("selected_travel_target_id")),
		])
	if ui_run.game_clock_minutes <= travel_clock_before:
		failures.append("Closing-time forced travel did not advance the action-driven travel clock.")
	if ui_run.closing_time_forced_travel_required():
		failures.append("Closing-time forced travel state was not cleared after successful travel.")
	_sb4_dispose_app(app)


func _world_map_hidden_count(map_data: Dictionary) -> int:
	var count := 0
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) == TYPE_DICTIONARY and str((node_value as Dictionary).get("state", "")) == WorldMapScript.STATE_HIDDEN:
			count += 1
	return count


func _world_map_visited_ids(map_data: Dictionary) -> Array:
	var ids: Array = []
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", "")).strip_edges()
		if not node_id.is_empty() and str(node.get("state", "")) == WorldMapScript.STATE_VISITED:
			ids.append(node_id)
	return ids


func _world_map_visible_ids_have_sources(map_data: Dictionary) -> bool:
	for node_id in WorldMapScript.visible_node_ids(map_data):
		var node := WorldMapScript.node_by_id(map_data, str(node_id))
		if str(node.get("state", "")) == WorldMapScript.STATE_VISITED:
			continue
		var source := str(node.get("discovery_source", "")).strip_edges()
		if bool(node.get("discovered_at_spawn", false)) or bool(node.get("unlocked", false)) or source == WorldMapScript.DISCOVERY_SOURCE_SPAWN or source == WorldMapScript.DISCOVERY_SOURCE_EVENT or source == WorldMapScript.DISCOVERY_SOURCE_TRAVEL:
			continue
		return false
	return true


func _world_map_snapshot_hidden_leaks(map_data: Dictionary, snapshot: Dictionary) -> Array:
	var hidden_ids := _world_map_hidden_ids(map_data)
	var leaks: Array = []
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if hidden_ids.has(node_id) and not leaks.has(node_id):
			leaks.append(node_id)
		if node.has("environment") and not leaks.has("%s:environment" % node_id):
			leaks.append("%s:environment" % node_id)
	for edge_value in _copy_array(snapshot.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var a := str(edge.get("a", ""))
		var b := str(edge.get("b", ""))
		if hidden_ids.has(a) and not leaks.has("edge:%s" % a):
			leaks.append("edge:%s" % a)
		if hidden_ids.has(b) and not leaks.has("edge:%s" % b):
			leaks.append("edge:%s" % b)
	var selected_id := str(snapshot.get("selected_node_id", ""))
	if hidden_ids.has(selected_id) and not leaks.has("selected:%s" % selected_id):
		leaks.append("selected:%s" % selected_id)
	return leaks


func _world_map_hidden_ids(map_data: Dictionary) -> Array:
	var hidden_ids: Array = []
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not node_id.is_empty() and not WorldMapScript.is_node_visible(map_data, node_id):
			hidden_ids.append(node_id)
	return hidden_ids


func _first_hidden_world_node_id(map_data: Dictionary) -> String:
	var hidden_ids := _world_map_hidden_ids(map_data)
	if hidden_ids.is_empty():
		return ""
	return str(hidden_ids[0])


func _world_map_snapshot_icons_match_positions(map_data: Dictionary, snapshot: Dictionary) -> bool:
	for node_value in _copy_array(snapshot.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			return false
		var snapshot_node: Dictionary = node_value
		var node_id := str(snapshot_node.get("id", ""))
		var map_node := WorldMapScript.node_by_id(map_data, node_id)
		if map_node.is_empty():
			return false
		if JSON.stringify(snapshot_node.get("position", {})) != JSON.stringify(map_node.get("position", {})):
			return false
		var icon_path := str(snapshot_node.get("icon_path", "")).strip_edges()
		if icon_path != "res://assets/art/map_icons/%s.png" % node_id:
			return false
	return true


func _world_map_target_new_count(map_data: Dictionary, target_ids: Array) -> int:
	var count := 0
	for target_id_value in target_ids:
		var node := WorldMapScript.node_by_id(map_data, str(target_id_value))
		if not node.is_empty() and str(node.get("state", "")) != WorldMapScript.STATE_VISITED:
			count += 1
	return count


func _world_map_reachable_visible_new_ids(map_data: Dictionary, source_id: String) -> Array:
	var result: Array = []
	for node_id_value in WorldMapScript.visible_node_ids(map_data):
		var node_id := str(node_id_value)
		if node_id == source_id:
			continue
		var node := WorldMapScript.node_by_id(map_data, node_id)
		if node.is_empty() or str(node.get("state", "")) == WorldMapScript.STATE_VISITED:
			continue
		if WorldMapScript.path_between(map_data, source_id, node_id, true).size() >= 2:
			result.append(node_id)
	return result


func _world_map_travel_charge_result(target_id: String, cost: int) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -maxi(0, cost)
	return GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": target_id,
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"bankroll_delta": -maxi(0, cost),
		"deltas": deltas,
		"message": "Travel charge fixture.",
	})


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _remove_user_store_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _write_user_store_file(path: String, data: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _write_user_store_text(path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _world_map_positions(map_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node_value in _copy_array(map_data.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		result[str(node.get("id", ""))] = _copy_dict(node.get("position", {}))
	return result


func _world_map_beach_delta_adjacency_ok(map_data: Dictionary, label: String, failures: Array) -> bool:
	var beach := WorldMapScript.node_by_id(map_data, "beach")
	var delta := WorldMapScript.node_by_id(map_data, "delta_queen")
	if beach.is_empty() or delta.is_empty():
		failures.append("World map beach adjacency fixture missing beach or delta_queen for %s." % label)
		return false
	var edge := _world_map_edge_between(map_data, "beach", "delta_queen")
	if edge.is_empty():
		failures.append("World map beach must have a direct edge to delta_queen for %s." % label)
		return false
	if int(edge.get("distance_blocks", 0)) != 1:
		failures.append("World map beach edge must price as 1 block for %s, got %d." % [label, int(edge.get("distance_blocks", 0))])
		return false
	var beach_edge_count := 0
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = edge_value
		if str(candidate.get("a", "")) == "beach" or str(candidate.get("b", "")) == "beach":
			beach_edge_count += 1
	if beach_edge_count != 1:
		failures.append("World map beach should only connect to delta_queen for %s, saw %d beach edges." % [label, beach_edge_count])
		return false
	return true


func _world_map_beach_route_gate_ok(map_data: Dictionary, label: String, library: ContentLibrary, failures: Array) -> bool:
	var gated_map := WorldMapScript.unlock_nodes(map_data, ["beach"], WorldMapScript.DISCOVERY_SOURCE_EVENT)
	gated_map = WorldMapScript.enter_node(gated_map, "delta_queen", {})
	var map_service: Variant = WorldMapScript.new(library)
	var delta_targets := WorldMapScript.travel_target_ids(gated_map, "delta_queen")
	if not delta_targets.has("beach"):
		failures.append("World map beach should be travelable from delta_queen for %s." % label)
		return false
	if map_service.route_for_target(gated_map, "delta_queen", "beach").is_empty():
		failures.append("World map beach route should resolve from delta_queen for %s." % label)
		return false
	gated_map = WorldMapScript.enter_node(gated_map, "beach", {})
	var beach_targets := WorldMapScript.travel_target_ids(gated_map, "beach")
	if not beach_targets.has("delta_queen"):
		failures.append("World map beach should still allow return travel to delta_queen for %s." % label)
		return false
	for node_id_value in WorldMapScript.visible_node_ids(gated_map):
		var source_id := str(node_id_value)
		if source_id == "delta_queen" or source_id == "beach":
			continue
		if WorldMapScript.travel_target_ids(gated_map, source_id).has("beach"):
			failures.append("World map beach should not be a travel target from %s for %s." % [source_id, label])
			return false
		if not map_service.route_for_target(gated_map, source_id, "beach").is_empty():
			failures.append("World map beach route should not resolve from %s for %s." % [source_id, label])
			return false
	return true


func _world_map_edge_between(map_data: Dictionary, a: String, b: String) -> Dictionary:
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var left := str(edge.get("a", "")).strip_edges()
		var right := str(edge.get("b", "")).strip_edges()
		if (left == a and right == b) or (left == b and right == a):
			return edge
	return {}


func _check_unique_object_layout_classes(library: ContentLibrary, failures: Array) -> void:
	var pull_tabs_game: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
	if pull_tabs_game == null:
		return
	for archetype_id in ["bar", "gas_station_casino", "jazz_club"]:
		var archetype := _archetype_by_id(library, str(archetype_id))
		if archetype.is_empty():
			failures.append("Unique object layout guard missing archetype: %s." % str(archetype_id))
			continue
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("UNIQUE-OBJECT-%s" % str(archetype_id))
		var environment := EnvironmentInstance.from_archetype(archetype, 1, run_state.create_rng("unique_object_environment"), library)
		var environment_data := environment.to_dict()
		var game_states := _copy_dict(environment_data.get("game_states", {}))
		game_states["pull_tabs"] = pull_tabs_game.generate_environment_state(run_state, environment_data, run_state.create_rng("unique_object_pull_tabs"))
		environment_data["game_states"] = game_states
		environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(environment_data)
		var conflicts := _unique_object_layout_conflicts(environment_data, library)
		if not conflicts.is_empty():
			failures.append("Unique object layout guard found duplicate identity classes in %s: %s." % [str(archetype_id), ", ".join(conflicts)])
		var object_rects: Dictionary = _copy_dict(_copy_dict(environment_data.get("layout", {})).get("object_rects", {}))
		if object_rects.has("dialogue:pull_tab_clerk"):
			failures.append("Pull Tabs duplicate dialogue clerk still reserved a room object in %s." % str(archetype_id))
		if not object_rects.has("game_hook:pull_tabs:ticket_redeemer"):
			failures.append("Pull Tabs unique clerk guard dropped the redeem counter in %s." % str(archetype_id))


func _unique_object_layout_conflicts(environment_data: Dictionary, library: ContentLibrary) -> Array:
	var class_by_object_id: Dictionary = {}
	for event_id in _string_array(environment_data.get("event_ids", [])):
		var event_definition := library.event(event_id)
		var unique_class := str(event_definition.get("unique_object_class", "")).strip_edges()
		if not unique_class.is_empty() and not bool(event_definition.get("allow_duplicate_unique_class", false)):
			class_by_object_id["event:%s" % event_id] = unique_class
	var game_states := _copy_dict(environment_data.get("game_states", {}))
	for game_id in _string_array(environment_data.get("game_ids", [])):
		var machine := _copy_dict(game_states.get(game_id, {}))
		for hook_value in _copy_array(machine.get("environment_hooks", [])):
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			var hook: Dictionary = hook_value
			var unique_class := str(hook.get("unique_object_class", "")).strip_edges()
			if unique_class.is_empty() or bool(hook.get("allow_duplicate_unique_class", false)):
				continue
			var object_id := str(hook.get("object_id", "")).strip_edges()
			if object_id.is_empty():
				var dialogue_id := str(hook.get("dialogue_id", "")).strip_edges()
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, str(hook.get("id", ""))]
			class_by_object_id[object_id] = unique_class
	var object_rects: Dictionary = _copy_dict(_copy_dict(environment_data.get("layout", {})).get("object_rects", {}))
	var seen_classes: Dictionary = {}
	var conflicts: Array = []
	for object_id_value in object_rects.keys():
		var object_id := str(object_id_value)
		var unique_class := str(class_by_object_id.get(object_id, "")).strip_edges()
		if unique_class.is_empty():
			continue
		if seen_classes.has(unique_class) and not conflicts.has(unique_class):
			conflicts.append(unique_class)
		seen_classes[unique_class] = object_id
	return conflicts


func _world_map_hops_to(map_data: Dictionary, start_id: String, target_id: String) -> int:
	if start_id == target_id:
		return 0
	var queue: Array = [{"id": start_id, "hops": 0}]
	var seen: Dictionary = {}
	seen[start_id] = true
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var node_id := str(entry.get("id", ""))
		var hops := int(entry.get("hops", 0))
		for neighbor_id in WorldMapScript.neighbor_ids(map_data, node_id, false):
			var neighbor := str(neighbor_id)
			if seen.has(neighbor):
				continue
			if neighbor == target_id:
				return hops + 1
			seen[neighbor] = true
			queue.append({"id": neighbor, "hops": hops + 1})
	return -1


func _fixture_travel_result(run_state: RunState, route: Dictionary, target_id: String, route_risk: Dictionary = {}) -> Dictionary:
	var status := run_state.travel_route_status(route)
	var cost := int(status.get("cost", 0))
	var suspicion_delta := int(status.get("suspicion_delta", 0))
	var risk_bankroll_delta := int(route_risk.get("bankroll_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var risk_suspicion_delta := int(route_risk.get("suspicion_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var total_bankroll_delta := -cost + risk_bankroll_delta
	var total_suspicion_delta := suspicion_delta + risk_suspicion_delta
	var message := "Traveled to %s." % target_id
	var story_entry := {
		"type": "travel",
		"id": target_id,
		"route_id": target_id,
		"bankroll_delta": total_bankroll_delta,
		"route_cost": cost,
		"suspicion_delta": total_suspicion_delta,
		"route_suspicion_delta": suspicion_delta,
		"route_risk": route_risk.duplicate(true),
		"message": message,
	}
	var story_entries: Array = [story_entry]
	if bool(route_risk.get("triggered", false)):
		story_entries.append({
			"type": "travel_risk_event",
			"id": str(route_risk.get("id", "travel_risk")),
			"route_id": target_id,
			"label": str(route_risk.get("label", "Route risk")),
			"roll": int(route_risk.get("roll", 0)),
			"chance_percent": int(route_risk.get("chance_percent", 0)),
			"bankroll_delta": risk_bankroll_delta,
			"suspicion_delta": risk_suspicion_delta,
			"message": str(route_risk.get("message", "The route risk catches you.")),
		})
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = total_bankroll_delta
	deltas["suspicion_delta"] = total_suspicion_delta
	deltas["story_log"] = story_entries
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": target_id,
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"bankroll_delta": total_bankroll_delta,
		"suspicion_delta": total_suspicion_delta,
		"route_cost": cost,
		"route_risk": route_risk.duplicate(true),
		"deltas": deltas,
		"message": message,
	})


# Checks service affordability, supported result-deltas, unsupported no-op behavior, and save/load.
func _check_service_hook_foundation(library: ContentLibrary, failures: Array) -> void:
	var service := library.service("cashier_tip")
	if service.is_empty():
		failures.append("Service fixture is missing: cashier_tip.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SERVICE-HOOK")
	run_state.add_suspicion("service_fixture_heat", 5)
	var status := run_state.service_hook_status(service)
	if not bool(status.get("available", false)):
		failures.append("Affordable service was unexpectedly disabled.")
	var cost := int(status.get("cost", 0))
	if cost <= 0:
		failures.append("Service fixture should expose a nonzero cost.")
	var before_bankroll := run_state.bankroll
	var before_suspicion := int(run_state.suspicion.get("level", 0))
	var result := _fixture_service_result(run_state, service, "cashier_tip")
	GameModule.apply_result(run_state, result)
	if run_state.bankroll != before_bankroll - cost:
		failures.append("Supported service did not apply cost through result-delta.")
	var expected_suspicion := clampi(before_suspicion + int(result.get("suspicion_delta", 0)), 0, 100)
	if int(run_state.suspicion.get("level", 0)) != expected_suspicion:
		failures.append("Supported service did not apply suspicion effect through result-delta.")
	if run_state.story_log.is_empty() or str((run_state.story_log[run_state.story_log.size() - 1] as Dictionary).get("type", "")) != "service_hook":
		failures.append("Supported service did not record a service story entry.")

	var drink_service := library.service("house_drink")
	if drink_service.is_empty():
		failures.append("Alcohol service is missing: house_drink.")
	else:
		var drink_run: RunState = RunStateScript.new()
		drink_run.start_new("SERVICE-ALCOHOL")
		drink_run.set_environment({"id": "service_alcohol_room", "archetype_id": "bar"})
		var drink_result := _fixture_service_result(drink_run, drink_service, "house_drink")
		var drink_intake := int(drink_result.get("deltas", {}).get("alcohol_intake", 0))
		GameModule.apply_result(drink_run, drink_result)
		if drink_intake <= 0:
			failures.append("Alcohol service did not expose a positive intake delta.")
		var immediate_drunk := mini(drink_intake, RunState.DRUNK_ABSORPTION_INITIAL_POINTS)
		if drink_run.drunk_level != immediate_drunk or drink_run.alcoholic_level != drink_intake or drink_run.pending_drunk_absorption_amount() != drink_intake - immediate_drunk:
			failures.append("Alcohol service did not apply the immediate first sip and queue the remaining drink intake.")
		var first_absorption_msec := int(((drink_run.pending_drunk_absorption[0] as Dictionary).get("next_msec", 0))) if not drink_run.pending_drunk_absorption.is_empty() else 0
		drink_run.update_drunk_absorption(first_absorption_msec - 1)
		if drink_run.drunk_level != immediate_drunk:
			failures.append("Alcohol absorption kicked in before its first interval.")
		drink_run.update_drunk_absorption(first_absorption_msec)
		var first_step := mini(drink_intake - immediate_drunk, RunState.DRUNK_ABSORPTION_POINTS_PER_INTERVAL)
		if drink_run.drunk_level != immediate_drunk + first_step or drink_run.pending_drunk_absorption_amount() != drink_intake - immediate_drunk - first_step:
			failures.append("Alcohol absorption did not add the expected drunk chunk at the first interval.")
		drink_run.advance_environment_turns(6)
		if drink_run.drunk_level != immediate_drunk + first_step:
			failures.append("Drunk decay ran while drink absorption was still pending.")
		drink_run.update_drunk_absorption(first_absorption_msec + drink_intake * RunState.DRUNK_ABSORPTION_INTERVAL_MSEC + 1)
		if drink_run.drunk_level != drink_intake or drink_run.pending_drunk_absorption_amount() != 0:
			failures.append("Alcohol service did not finish delayed absorption into the drunk meter.")
		var time_run: RunState = RunStateScript.new()
		time_run.start_new("SERVICE-DRUNK-TIME")
		if absf(time_run.drunk_time_scale() - 1.0) > 0.001 or time_run.drunk_time_scale_percent() != 100:
			failures.append("Sober drunk-time scale did not preserve full speed.")
		time_run.drunk_level = 33
		if time_run.drunk_time_scale() <= 0.85:
			failures.append("Early drunk-time scaling warped time too aggressively.")
		time_run.drunk_level = 66
		if absf(time_run.drunk_time_scale() - 0.66) > 0.025:
			failures.append("66 drunk did not slow world timing to roughly 66%% speed.")
		time_run.drunk_level = 100
		if absf(time_run.drunk_time_scale() - RunState.DRUNK_TIME_SCALE_MIN) > 0.001 or time_run.drunk_time_scale_percent() != 33:
			failures.append("100 drunk did not slow world timing to 33%% speed.")
		var stacked_run: RunState = RunStateScript.new()
		stacked_run.start_new("SERVICE-ALCOHOL-STACK")
		stacked_run.drink_alcohol(10)
		stacked_run.drink_alcohol(10)
		stacked_run.drink_alcohol(10)
		var stacked_next_msec := int(((stacked_run.pending_drunk_absorption[0] as Dictionary).get("next_msec", 0))) if not stacked_run.pending_drunk_absorption.is_empty() else 0
		stacked_run.update_drunk_absorption(stacked_next_msec)
		var stacked_immediate := RunState.DRUNK_ABSORPTION_INITIAL_POINTS * 3
		var stacked_first_step := RunState.DRUNK_ABSORPTION_POINTS_PER_INTERVAL * 3
		if stacked_run.drunk_level != stacked_immediate + stacked_first_step or stacked_run.pending_drunk_absorption_amount() != 30 - stacked_immediate - stacked_first_step:
			failures.append("Stacked drinks did not absorb one chunk per drink on the same interval.")
		var absorbed_luck := drink_run.effective_luck()
		var heat_before := drink_run.suspicion_level()
		var applied_heat := drink_run.add_suspicion("alcohol_heat_fixture", 2)
		if applied_heat <= 2 or drink_run.suspicion_level() <= heat_before + 2:
			failures.append("Alcohol pressure did not amplify positive heat gain.")
		drink_run.advance_environment_turns(6)
		if drink_run.drunk_level >= drink_run.alcoholic_level:
			failures.append("Alcohol did not decay into a dependency gap over time.")
		if drink_run.effective_luck() >= absorbed_luck:
			failures.append("Low drunk value under alcohol need did not lower effective luck.")

	var poor_run: RunState = RunStateScript.new()
	poor_run.start_new("SERVICE-POOR")
	poor_run.change_bankroll(-(poor_run.bankroll - maxi(0, cost - 1)))
	var poor_status := poor_run.service_hook_status(service)
	if bool(poor_status.get("available", true)):
		failures.append("Unaffordable service was not disabled.")

	var beach_relax := library.service("beach_relax")
	var beach_sand_pile := library.service("beach_sand_pile")
	if beach_relax.is_empty() or beach_sand_pile.is_empty():
		failures.append("Beach service fixture is missing.")
	else:
		var beach_run: RunState = RunStateScript.new()
		beach_run.start_new("SERVICE-BEACH")
		beach_run.set_environment({
			"id": "service_beach_room",
			"archetype_id": "beach",
			"service_ids": ["beach_relax", "beach_sand_pile"],
		})
		beach_run.add_suspicion("beach_heat_fixture", 8)
		var beach_heat_before := beach_run.suspicion_level()
		var relax_status := beach_run.service_hook_status(beach_relax)
		if not bool(relax_status.get("available", false)):
			failures.append("Beach relax service should be available.")
		var relax_result := _fixture_service_result(beach_run, beach_relax, "beach_relax")
		GameModule.apply_result(beach_run, relax_result)
		if beach_run.suspicion_level() >= beach_heat_before:
			failures.append("Beach relax service did not reduce heat.")
		var sand_status := beach_run.service_hook_status(beach_sand_pile)
		if not bool(sand_status.get("available", false)):
			failures.append("Beach sand pile should be available before inspection.")
		var sand_result := _fixture_service_result(beach_run, beach_sand_pile, "beach_sand_pile")
		GameModule.apply_result(beach_run, sand_result)
		if not beach_run.inventory.has("cumquat_sandwich"):
			failures.append("Beach sand pile did not add the Cumquat Sandwich.")
		if not bool(beach_run.narrative_flags.get("beach_sand_pile_found", false)):
			failures.append("Beach sand pile did not set its one-shot flag.")
		var sand_after_status := beach_run.service_hook_status(beach_sand_pile)
		if bool(sand_after_status.get("available", true)):
			failures.append("Beach sand pile stayed available after inspection.")
		var beach_loaded: RunState = RunStateScript.new()
		beach_loaded.from_dict(beach_run.to_dict())
		if not beach_loaded.inventory.has("cumquat_sandwich") or not bool(beach_loaded.narrative_flags.get("beach_sand_pile_found", false)):
			failures.append("Beach sand pile inventory/flag state did not survive RunState round-trip.")

	var unsupported_run: RunState = RunStateScript.new()
	unsupported_run.start_new("SERVICE-UNSUPPORTED")
	var unsupported_before := unsupported_run.to_dict()
	var unsupported_result := _fixture_service_result(unsupported_run, {
		"id": "display_only_service",
		"display_name": "Display Only Service",
		"effect": {},
	}, "display_only_service")
	GameModule.apply_result(unsupported_run, unsupported_result)
	if JSON.stringify(unsupported_run.to_dict()) != JSON.stringify(unsupported_before):
		failures.append("Unsupported service mutated RunState.")

	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_service"
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save service result state: %s." % save_error)
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload service result state.")
		elif loaded.bankroll != run_state.bankroll:
			failures.append("Service cost did not survive SaveService load.")
		elif int(loaded.suspicion.get("level", 0)) != int(run_state.suspicion.get("level", 0)):
			failures.append("Service suspicion result did not survive SaveService load.")
		elif loaded.story_log.size() != run_state.story_log.size():
			failures.append("Service story result did not survive SaveService load.")


func _fixture_service_result(run_state: RunState, service: Dictionary, service_id: String) -> Dictionary:
	var status := run_state.service_hook_status(service)
	var cost := int(status.get("cost", 0))
	var effect: Dictionary = service.get("effect", {}) if typeof(service.get("effect", {})) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = -cost
	deltas["suspicion_delta"] = int(effect.get("suspicion_delta", 0))
	deltas["alcohol_intake"] = int(effect.get("alcohol_intake", 0))
	deltas["drunk_delta"] = int(effect.get("drunk_delta", 0))
	deltas["alcoholic_delta"] = int(effect.get("alcoholic_delta", 0))
	deltas["baseline_luck_delta"] = int(effect.get("baseline_luck_delta", 0))
	if typeof(effect.get("inventory_add", [])) == TYPE_ARRAY:
		deltas["inventory_add"] = (effect.get("inventory_add", []) as Array).duplicate(true)
	if typeof(effect.get("inventory_remove", [])) == TYPE_ARRAY:
		deltas["inventory_remove"] = (effect.get("inventory_remove", []) as Array).duplicate(true)
	if typeof(effect.get("flags_set", {})) == TYPE_DICTIONARY:
		deltas["flags_set"] = (effect.get("flags_set", {}) as Dictionary).duplicate(true)
	if typeof(effect.get("messages", [])) == TYPE_ARRAY:
		deltas["messages"] = (effect.get("messages", []) as Array).duplicate(true)
	var flags: Dictionary = deltas.get("flags_set", {}) if typeof(deltas.get("flags_set", {})) == TYPE_DICTIONARY else {}
	var inventory_add: Array = deltas.get("inventory_add", []) if typeof(deltas.get("inventory_add", [])) == TYPE_ARRAY else []
	var inventory_remove: Array = deltas.get("inventory_remove", []) if typeof(deltas.get("inventory_remove", [])) == TYPE_ARRAY else []
	var has_mutation := int(deltas.get("bankroll_delta", 0)) != 0 or int(deltas.get("suspicion_delta", 0)) != 0 or int(deltas.get("alcohol_intake", 0)) != 0 or int(deltas.get("drunk_delta", 0)) != 0 or int(deltas.get("alcoholic_delta", 0)) != 0 or int(deltas.get("baseline_luck_delta", 0)) != 0 or not flags.is_empty() or not inventory_add.is_empty() or not inventory_remove.is_empty() or not (deltas.get("messages", []) as Array).is_empty()
	if not has_mutation:
		return GameModule.build_action_result({
			"ok": false,
			"type": "service_hook",
			"source_id": service_id,
			"action_id": "use_service_hook",
		})
	var message := str(service.get("message", "Used %s." % str(service.get("display_name", service_id))))
	deltas["story_log"] = [{
		"type": "service_hook",
		"id": service_id,
		"label": str(service.get("display_name", service_id)),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"alcohol_intake": int(deltas.get("alcohol_intake", 0)),
		"drunk_delta": int(deltas.get("drunk_delta", 0)),
		"alcoholic_delta": int(deltas.get("alcoholic_delta", 0)),
		"baseline_luck_delta": int(deltas.get("baseline_luck_delta", 0)),
		"message": message,
	}]
	if (deltas.get("messages", []) as Array).is_empty():
		deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": bool(status.get("available", false)),
		"type": "service_hook",
		"source_id": service_id,
		"action_id": "use_service_hook",
		"action_kind": "service",
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": message,
	})


func _check_jazz_club_foundation(library: ContentLibrary, failures: Array) -> void:
	var jazz_archetype := _archetype_by_id(library, "jazz_club")
	if jazz_archetype.is_empty():
		failures.append("Jazz Club archetype is missing.")
		return
	if str(jazz_archetype.get("kind", "")) != "shop":
		failures.append("Jazz Club should be a shop/bar service venue, not a casino.")
	if int(jazz_archetype.get("spawn_weight", 0)) < 4:
		failures.append("Jazz Club should have enough spawn weight to be discoverable once routed.")
	if _item_count_ceiling(jazz_archetype.get("item_count", 0)) > 2:
		failures.append("Jazz Club should stay uncluttered with no more than two item offers.")
	if _item_count_ceiling(jazz_archetype.get("event_count", 0)) > 1:
		failures.append("Jazz Club should stay uncluttered with no more than one ambient event.")
	for source_id in ["corner_store", "back_alley", "motel", "bar", "gas_station_casino", "small_underground_casino"]:
		var source_archetype := _archetype_by_id(library, source_id)
		if source_archetype.is_empty():
			failures.append("Jazz Club route source is missing: %s." % source_id)
			continue
		if not _string_array(source_archetype.get("rare_next_archetypes", [])).has("jazz_club"):
			failures.append("Jazz Club route source %s no longer exposes the music room." % source_id)
		if int(source_archetype.get("rare_next_chance_percent", 0)) < 20:
			failures.append("Jazz Club route source %s should expose the music room at least 20%% of the time." % source_id)
	var jazz_game_pool := _string_array(jazz_archetype.get("game_pool", []))
	if jazz_game_pool != ["pull_tabs"]:
		failures.append("Jazz Club should always expose exactly the pull-tabs machine.")
	if _string_array(jazz_archetype.get("required_game_ids", [])) != ["pull_tabs"]:
		failures.append("Jazz Club should require the pull-tabs machine in every generated instance.")
	var jazz_visual_context: Dictionary = jazz_archetype.get("visual_context", {}) if typeof(jazz_archetype.get("visual_context", {})) == TYPE_DICTIONARY else {}
	if str(jazz_visual_context.get("scene_type", "")) != "jazz_club":
		failures.append("Jazz Club visual context should use the jazz_club scene type.")
	if str(jazz_visual_context.get("asset_path", "")).find("jazz_club.png") == -1:
		failures.append("Jazz Club should reference its own environment art asset.")
	if str(jazz_visual_context.get("description", "")).strip_edges().is_empty():
		failures.append("Jazz Club visual description should be present.")
	for service_id in ["house_drink", "jazz_sax_round", "jazz_cello_round", "jazz_drummer_round", "jazz_band_tip_jar", "listen_to_jazz"]:
		if not _string_array(jazz_archetype.get("service_pool", [])).has(service_id):
			failures.append("Jazz Club service pool is missing %s." % service_id)
	var jazz_service_expectations := {
		"jazz_sax_round": "baseline_luck_delta",
		"jazz_cello_round": "suspicion_delta",
		"jazz_drummer_round": "alcohol_intake",
		"jazz_band_tip_jar": "heat_cooldown_actions",
		"listen_to_jazz": "suspicion_delta",
	}
	for service_id_value in jazz_service_expectations.keys():
		var service_id := str(service_id_value)
		var service_definition := library.service(service_id)
		var service_effect: Dictionary = service_definition.get("effect", {}) if typeof(service_definition.get("effect", {})) == TYPE_DICTIONARY else {}
		var expected_effect_key := str(jazz_service_expectations.get(service_id_value, ""))
		if service_definition.is_empty() or not service_effect.has(expected_effect_key):
			failures.append("Jazz Club service %s is missing concrete effect metadata for %s." % [service_id, expected_effect_key])
	for item_id in ["jazz_sax_lucky_coin", "jazz_cello_lucky_coin", "jazz_drummer_lucky_coin", "jazz_drummer_glasses"]:
		if library.item(item_id).is_empty():
			failures.append("Jazz reward item is missing: %s." % item_id)
	var jazz_event_ids := ["jazz_trio_set_break", "jazz_connected_regular", "jazz_after_hours_invitation"]
	var jazz_event_pool := _string_array(jazz_archetype.get("event_pool", []))
	for event_id_value in jazz_event_ids:
		var event_id := str(event_id_value)
		if not jazz_event_pool.has(event_id):
			failures.append("Jazz Club event pool is missing %s." % event_id)
		var event_definition := library.event(event_id)
		if event_definition.is_empty():
			failures.append("Jazz Club event definition is missing: %s." % event_id)
			continue
		if str(event_definition.get("interaction_mode", "")) != "triggered" or str(event_definition.get("presentation", "")) != "talk":
			failures.append("Jazz Club event %s should be a triggered talk event." % event_id)
		var event_conditions: Dictionary = event_definition.get("conditions", {}) if typeof(event_definition.get("conditions", {})) == TYPE_DICTIONARY else {}
		if not _string_array(event_conditions.get("archetype_ids", [])).has("jazz_club"):
			failures.append("Jazz Club event %s should be scoped to the jazz_club archetype." % event_id)
	var jazz_route := library.route("jazz_club")
	if jazz_route.is_empty() or str(jazz_route.get("destination_archetype", "")) != "jazz_club":
		failures.append("Jazz Club travel route metadata is missing.")

	var run_state: RunState = RunStateScript.new()
	run_state.start_new("JAZZ-CLUB")
	var environment_a := EnvironmentInstance.from_archetype(jazz_archetype, 2, run_state.create_rng("jazz_a"), library)
	var environment_b := EnvironmentInstance.from_archetype(jazz_archetype, 3, run_state.create_rng("jazz_b"), library)
	if environment_a.game_ids != ["pull_tabs"]:
		failures.append("Generated Jazz Club did not place the guaranteed pull-tab machine.")
	var jazz_environment_data := environment_a.to_dict()
	var pull_tabs_game: GameModule = _load_surface_contract_game(library, "pull_tabs", failures)
	if pull_tabs_game != null:
		jazz_environment_data["game_states"] = {
			"pull_tabs": pull_tabs_game.generate_environment_state(run_state, jazz_environment_data, run_state.create_rng("jazz_pull_tabs_machine"))
		}
	jazz_environment_data["layout"] = EnvironmentInstance.ensure_generated_layout(jazz_environment_data)
	_check_jazz_club_layout(jazz_environment_data, failures)
	var profile_a := environment_a.music_profile
	var profile_b := environment_b.music_profile
	if str(profile_a.get("procedural_variant", "")) != "jazz_club":
		failures.append("Jazz Club music profile did not request the jazz generator.")
	if str(profile_a.get("generated_signature", "")).is_empty() or str(profile_a.get("generated_title", "")).is_empty():
		failures.append("Jazz Club music profile did not save generated title/signature data.")
	if JSON.stringify(profile_a) == JSON.stringify(profile_b):
		failures.append("Separate Jazz Club instances did not generate distinct music profiles.")

	run_state.set_environment(environment_a.to_dict())
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	if resolver.service_hook("jazz_sax_round").is_empty() or resolver.service_hook("listen_to_jazz").is_empty() or resolver.service_hook("jazz_band_tip_jar").is_empty():
		failures.append("Jazz Club services did not appear in the action service.")
	var tip_option := resolver.hook_option("service", "jazz_band_tip_jar")
	if int(tip_option.get("cost", 0)) >= int(resolver.hook_option("service", "house_drink").get("cost", 0)):
		failures.append("Jazz band tip jar should cost less than a drink.")

	var jazz_event_run: RunState = RunStateScript.new()
	jazz_event_run.start_new("JAZZ-CLUB-EVENTS")
	jazz_event_run.bankroll = 100
	jazz_event_run.set_environment(environment_a.to_dict())
	var event_context := {
		"trigger": "action",
		"type": "action",
		"turns": 2,
	}
	var off_route_environment := jazz_event_run.current_environment.duplicate(true)
	off_route_environment["archetype_id"] = "corner_store"
	off_route_environment["kind"] = "shop"
	for event_id_value in jazz_event_ids:
		var event_id := str(event_id_value)
		var event_module := EventModule.new()
		event_module.setup(library.event(event_id), library)
		if event_id == "jazz_after_hours_invitation":
			jazz_event_run.set_story_flag("jazz_trio_backed_player", true)
		if not event_module.can_trigger(jazz_event_run, jazz_event_run.current_environment, event_context):
			failures.append("Jazz Club event %s did not trigger in the jazz club context." % event_id)
		if event_module.can_trigger(jazz_event_run, off_route_environment, event_context):
			failures.append("Jazz Club event %s triggered outside the jazz club archetype." % event_id)
	var after_hours_event := EventModule.new()
	after_hours_event.setup(library.event("jazz_after_hours_invitation"), library)
	var shades_result := after_hours_event.resolve(jazz_event_run, jazz_event_run.current_environment, "take_the_shades")
	if not bool(shades_result.get("ok", false)):
		failures.append("Jazz after-hours invitation cover-item choice did not resolve.")
	if not jazz_event_run.inventory.has("cheap_sunglasses"):
		failures.append("Jazz after-hours invitation did not award the Grand Casino cover item.")
	if not bool(jazz_event_run.story_flags.get("jazz_after_hours_cover", false)):
		failures.append("Jazz after-hours invitation did not persist its cover story flag.")

	var generated_setup_run: RunState = RunStateScript.new()
	generated_setup_run.start_new("JAZZ-CLUB-SETUP")
	generated_setup_run.set_environment(environment_a.to_dict())
	var generated_resolver: RunActionService = RunActionServiceScript.new()
	generated_resolver.setup(library, generated_setup_run)
	generated_resolver.use_hook("service", "jazz_sax_round")
	var generated_jazz_id := str(generated_setup_run.current_environment.get("id", ""))
	var generated_holder := str(generated_setup_run.narrative_flags.get("jazz_%s_reward_holder" % generated_jazz_id, ""))
	var generated_threshold := int(generated_setup_run.narrative_flags.get("jazz_%s_reward_drinks_required" % generated_jazz_id, 0))
	if not ["sax", "cello", "drummer"].has(generated_holder):
		failures.append("Jazz Club did not persist a valid hidden reward holder.")
	if generated_threshold < 3 or generated_threshold > 5:
		failures.append("Jazz Club reward drink threshold was not in the 3-5 range.")
	var saw_generated_reward_holder := false
	for setup_index in range(12):
		var sample_run: RunState = RunStateScript.new()
		sample_run.start_new("JAZZ-CLUB-SETUP-%d" % setup_index)
		var sample_environment := EnvironmentInstance.from_archetype(jazz_archetype, setup_index + 10, sample_run.create_rng("jazz_setup_%d" % setup_index), library)
		sample_run.set_environment(sample_environment.to_dict())
		var sample_resolver: RunActionService = RunActionServiceScript.new()
		sample_resolver.setup(library, sample_run)
		sample_resolver.use_hook("service", "jazz_sax_round")
		var sample_jazz_id := str(sample_run.current_environment.get("id", ""))
		var sample_holder := str(sample_run.narrative_flags.get("jazz_%s_reward_holder" % sample_jazz_id, ""))
		if sample_holder == "none":
			failures.append("Jazz Club generated a no-reward holder despite requiring one musician to hold the item.")
		elif ["sax", "cello", "drummer"].has(sample_holder):
			saw_generated_reward_holder = true
		if saw_generated_reward_holder:
			break
	if not saw_generated_reward_holder:
		failures.append("Jazz Club reward setup did not generate any musician reward holder in the deterministic sample.")

	var first_round_run: RunState = RunStateScript.new()
	first_round_run.start_new("JAZZ-CLUB-FIRST-ROUNDS")
	first_round_run.bankroll = 500
	var first_round_environment := EnvironmentInstance.from_archetype(jazz_archetype, 8, first_round_run.create_rng("jazz_first_rounds"), library)
	first_round_run.set_environment(first_round_environment.to_dict())
	var first_round_jazz_id := str(first_round_run.current_environment.get("id", ""))
	first_round_run.narrative_flags["jazz_%s_reward_holder" % first_round_jazz_id] = "drummer"
	first_round_run.narrative_flags["jazz_%s_reward_drinks_required" % first_round_jazz_id] = 3
	var first_round_resolver: RunActionService = RunActionServiceScript.new()
	first_round_resolver.setup(library, first_round_run)
	first_round_run.add_suspicion("jazz_cello_heat_fixture", 4, "behavior", false, {"environment_id": str(first_round_run.current_environment.get("id", ""))})
	for first_service_id in ["jazz_sax_round", "jazz_cello_round", "jazz_drummer_round"]:
		var first_result := first_round_resolver.use_hook("service", first_service_id)
		if not bool(first_result.get("ok", false)):
			failures.append("Jazz first musician drink did not resolve for %s." % first_service_id)
			continue
		var first_result_data: Dictionary = first_result.get("result", {}) if typeof(first_result.get("result", {})) == TYPE_DICTIONARY else {}
		var first_deltas: Dictionary = first_result_data.get("deltas", {}) if typeof(first_result_data.get("deltas", {})) == TYPE_DICTIONARY else {}
		if first_service_id == "jazz_sax_round" and int(first_deltas.get("baseline_luck_delta", 0)) < 1:
			failures.append("Jazz sax round did not apply its luck lift.")
		if first_service_id == "jazz_cello_round" and int(first_deltas.get("suspicion_delta", 0)) >= 0:
			failures.append("Jazz cello round did not cool local heat.")
		if first_service_id == "jazz_drummer_round" and int(first_deltas.get("alcohol_intake", 0)) != 4:
			failures.append("Jazz drummer round did not apply its light buzz.")
		if str(first_result.get("message", "")).to_lower().find("nothing") != -1:
			failures.append("Jazz first musician drink incorrectly revealed an empty musician for %s." % first_service_id)
		var first_musician_id := str(first_service_id).trim_suffix("_round").trim_prefix("jazz_")
		if bool(first_round_run.narrative_flags.get("jazz_%s_%s_no_item" % [first_round_jazz_id, first_musician_id], false)):
			failures.append("Jazz first musician drink marked %s empty before the threshold." % first_musician_id)
	if first_round_run.inventory.has("jazz_sax_lucky_coin") or first_round_run.inventory.has("jazz_cello_lucky_coin") or first_round_run.inventory.has("jazz_drummer_lucky_coin") or first_round_run.inventory.has("jazz_drummer_glasses"):
		failures.append("Jazz first musician drinks awarded a reward before the configured drink threshold.")

	var tip_run: RunState = RunStateScript.new()
	tip_run.start_new("JAZZ-CLUB-TIP")
	tip_run.bankroll = 500
	var tip_environment := EnvironmentInstance.from_archetype(jazz_archetype, 5, tip_run.create_rng("jazz_tip"), library)
	tip_run.set_environment(tip_environment.to_dict())
	tip_run.add_suspicion("jazz_tip_heat", 6, "behavior", false, {"environment_id": str(tip_run.current_environment.get("id", ""))})
	var tip_jazz_id := str(tip_run.current_environment.get("id", ""))
	tip_run.narrative_flags["jazz_%s_reward_holder" % tip_jazz_id] = "cello"
	tip_run.narrative_flags["jazz_%s_reward_drinks_required" % tip_jazz_id] = 4
	var tip_resolver: RunActionService = RunActionServiceScript.new()
	tip_resolver.setup(library, tip_run)
	var tip_success_seen := false
	var tip_cooldown_checked := false
	for _index in range(12):
		var favor_before := (
			int(tip_run.narrative_flags.get("jazz_%s_sax_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_cello_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_drummer_favor" % tip_jazz_id, 0))
		)
		var bankroll_before_tip := tip_run.bankroll
		var tip_result := tip_resolver.use_hook("service", "jazz_band_tip_jar")
		if not bool(tip_result.get("ok", false)):
			failures.append("Jazz band tip jar did not resolve.")
			break
		if tip_run.bankroll != bankroll_before_tip - 6:
			failures.append("Jazz band tip jar did not charge its configured cost.")
			break
		if not tip_cooldown_checked:
			var tip_result_data: Dictionary = tip_result.get("result", {}) if typeof(tip_result.get("result", {})) == TYPE_DICTIONARY else {}
			var tip_deltas: Dictionary = tip_result_data.get("deltas", {}) if typeof(tip_result_data.get("deltas", {})) == TYPE_DICTIONARY else {}
			if int(tip_deltas.get("heat_cooldown_actions", 0)) != 3 or int(tip_deltas.get("heat_cooldown_per_action", 0)) != 1:
				failures.append("Jazz band tip jar did not report its heat cooldown delta.")
			if tip_run.active_heat_cooldown_actions() <= 0:
				failures.append("Jazz band tip jar did not start a persistent heat cooldown.")
			var heat_before_cooldown_tick := tip_run.suspicion_level()
			tip_run.advance_environment_turns(1)
			if tip_run.suspicion_level() >= heat_before_cooldown_tick:
				failures.append("Jazz band tip jar heat cooldown did not cool on the next action.")
			tip_cooldown_checked = true
		var favor_after := (
			int(tip_run.narrative_flags.get("jazz_%s_sax_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_cello_favor" % tip_jazz_id, 0))
			+ int(tip_run.narrative_flags.get("jazz_%s_drummer_favor" % tip_jazz_id, 0))
		)
		if favor_after > favor_before:
			tip_success_seen = true
			break
	if not tip_success_seen:
		failures.append("Jazz band tip jar never contributed a drink purchase in the deterministic fixture.")

	var jazz_id := str(run_state.current_environment.get("id", ""))
	run_state.narrative_flags["jazz_%s_reward_holder" % jazz_id] = "cello"
	run_state.narrative_flags["jazz_%s_reward_drinks_required" % jazz_id] = 4
	var bankroll_before_wrong_round := run_state.bankroll
	var wrong_sax := resolver.use_hook("service", "jazz_sax_round")
	if not bool(wrong_sax.get("ok", false)):
		failures.append("Jazz wrong-musician round did not resolve.")
	if run_state.inventory.has("jazz_sax_lucky_coin"):
		failures.append("Wrong Jazz Club musician awarded a sax lucky coin.")
	if str(wrong_sax.get("message", "")).to_lower().find("nothing") != -1:
		failures.append("Wrong Jazz Club musician revealed there was nothing to give before the drink threshold.")
	if run_state.bankroll != bankroll_before_wrong_round - 8:
		failures.append("Wrong Jazz Club musician round did not charge exactly one drink.")
	if bool(run_state.narrative_flags.get("jazz_%s_sax_no_item" % jazz_id, false)):
		failures.append("Wrong Jazz Club musician was remembered as empty before the drink threshold.")
	if not bool(resolver.hook_option("service", "jazz_sax_round").get("enabled", false)):
		failures.append("Wrong Jazz Club musician was disabled before reaching the drink threshold.")
	resolver.use_hook("service", "jazz_sax_round")
	resolver.use_hook("service", "jazz_sax_round")
	var sax_empty := resolver.use_hook("service", "jazz_sax_round")
	if str(sax_empty.get("message", "")).to_lower().find("nothing") == -1:
		failures.append("Wrong Jazz Club musician did not reveal there was nothing to give at the drink threshold.")
	if not bool(run_state.narrative_flags.get("jazz_%s_sax_no_item" % jazz_id, false)):
		failures.append("Wrong Jazz Club musician was not remembered as empty after the drink threshold.")
	if bool(resolver.hook_option("service", "jazz_sax_round").get("enabled", false)):
		failures.append("Wrong Jazz Club musician remained available after threshold empty reveal.")

	var baseline_before_coin := run_state.baseline_luck
	resolver.use_hook("service", "jazz_cello_round")
	if run_state.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz Club holder paid before the configured drink threshold.")
	resolver.use_hook("service", "jazz_cello_round")
	if run_state.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz Club holder paid before the higher configured drink threshold.")
	resolver.use_hook("service", "jazz_cello_round")
	if run_state.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz Club holder paid one round before the higher configured drink threshold.")
	var cello_reward := resolver.use_hook("service", "jazz_cello_round")
	if not bool(cello_reward.get("ok", false)):
		failures.append("Jazz Club holder threshold round did not resolve.")
	if not run_state.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz Club holder did not award the cello lucky coin at the drink threshold.")
	if run_state.inventory.has("jazz_sax_lucky_coin") or run_state.inventory.has("jazz_drummer_glasses"):
		failures.append("Jazz Club awarded more than the single hidden musician reward.")
	if run_state.baseline_luck != baseline_before_coin + 5:
		failures.append("Jazz Club coin reward did not apply the expected luck bonus.")
	if not bool(run_state.narrative_flags.get("jazz_%s_reward_claimed" % jazz_id, false)):
		failures.append("Jazz Club did not mark the local reward as claimed.")
	if bool(resolver.hook_option("service", "jazz_drummer_round").get("enabled", false)):
		failures.append("Jazz Club kept musician rewards open after one item was claimed.")
	var free_drink_option := resolver.hook_option("service", "house_drink")
	if int(free_drink_option.get("cost", -1)) != 0:
		failures.append("Jazz bar did not comp drinks after a jazz reward item.")
	var bankroll_before_free_drink := run_state.bankroll
	var free_drink := resolver.use_hook("service", "house_drink")
	if not bool(free_drink.get("ok", false)):
		failures.append("Comped Jazz Club drink did not resolve.")
	if run_state.bankroll != bankroll_before_free_drink:
		failures.append("Comped Jazz Club drink still charged bankroll.")
	if run_state.pending_drunk_absorption_amount() <= 0:
		failures.append("Comped Jazz Club drink did not queue alcohol intake.")

	var drummer_environment := EnvironmentInstance.from_archetype(jazz_archetype, 4, run_state.create_rng("jazz_drummer"), library)
	run_state.set_environment(drummer_environment.to_dict())
	var drummer_jazz_id := str(run_state.current_environment.get("id", ""))
	run_state.narrative_flags["jazz_%s_reward_holder" % drummer_jazz_id] = "drummer"
	run_state.narrative_flags["jazz_%s_reward_drinks_required" % drummer_jazz_id] = 3
	resolver.use_hook("service", "jazz_drummer_round")
	resolver.use_hook("service", "jazz_drummer_round")
	var drummer_coin_reward := resolver.use_hook("service", "jazz_drummer_round")
	if not bool(drummer_coin_reward.get("ok", false)):
		failures.append("Jazz drummer short-stay threshold round did not resolve.")
	if not run_state.inventory.has("jazz_drummer_lucky_coin"):
		failures.append("Drummer holder did not award a lucky coin before two listened sets.")
	if run_state.inventory.has("jazz_drummer_glasses"):
		failures.append("Drummer awarded legend glasses before two listened sets.")

	var glasses_environment := EnvironmentInstance.from_archetype(jazz_archetype, 6, run_state.create_rng("jazz_drummer_glasses"), library)
	run_state.set_environment(glasses_environment.to_dict())
	var glasses_jazz_id := str(run_state.current_environment.get("id", ""))
	run_state.narrative_flags["jazz_%s_reward_holder" % glasses_jazz_id] = "drummer"
	run_state.narrative_flags["jazz_%s_reward_drinks_required" % glasses_jazz_id] = 3
	resolver.use_hook("service", "listen_to_jazz")
	resolver.use_hook("service", "listen_to_jazz")
	resolver.use_hook("service", "jazz_drummer_round")
	resolver.use_hook("service", "jazz_drummer_round")
	var glasses_reward := resolver.use_hook("service", "jazz_drummer_round")
	if not bool(glasses_reward.get("ok", false)):
		failures.append("Jazz drummer glasses threshold round did not resolve.")
	if not run_state.inventory.has("jazz_drummer_glasses"):
		failures.append("Drummer holder did not award the legend glasses after two listened sets.")

	run_state.add_suspicion("jazz_heat_fixture", 25, "behavior", false, {"environment_id": str(run_state.current_environment.get("id", ""))})
	var heat_before_glasses := run_state.suspicion_level()
	var glasses_option := resolver.hook_option("service", "show_drummer_glasses")
	if not bool(glasses_option.get("enabled", false)):
		failures.append("Legend glasses service did not appear when heat was present.")
	var glasses_clear := resolver.use_hook("service", "show_drummer_glasses")
	if not bool(glasses_clear.get("ok", false)):
		failures.append("Legend glasses heat-clear service did not resolve.")
	if run_state.suspicion_level() != 0:
		failures.append("Legend glasses did not clear all local heat.")
	var glasses_result: Dictionary = glasses_clear.get("result", {})
	if int(glasses_result.get("suspicion_delta", 0)) != -heat_before_glasses:
		failures.append("Legend glasses result did not report the full heat reduction (%d vs expected %d)." % [int(glasses_result.get("suspicion_delta", 0)), -heat_before_glasses])
	run_state.add_suspicion("jazz_heat_again", 10, "behavior", false, {"environment_id": str(run_state.current_environment.get("id", ""))})
	if bool(resolver.hook_option("service", "show_drummer_glasses").get("enabled", false)):
		failures.append("Legend glasses were reusable in the same venue location.")

	var saved := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(saved)
	if not restored.inventory.has("jazz_drummer_glasses") or not restored.inventory.has("jazz_drummer_lucky_coin") or not restored.inventory.has("jazz_cello_lucky_coin"):
		failures.append("Jazz reward inventory did not survive save/load.")
	if JSON.stringify(restored.current_environment.get("music_profile", {})) != JSON.stringify(run_state.current_environment.get("music_profile", {})):
		failures.append("Jazz generated music profile did not survive save/load.")
	if restored.story_log.size() != run_state.story_log.size():
		failures.append("Jazz story entries did not survive save/load.")

	var bar_archetype := _archetype_by_id(library, "bar")
	var bar_environment := EnvironmentInstance.from_archetype(bar_archetype, 4, run_state.create_rng("jazz_bar"), library)
	run_state.set_environment(bar_environment.to_dict())
	run_state.add_suspicion("bar_heat_fixture", 12, "behavior", false, {"environment_id": str(run_state.current_environment.get("id", ""))})
	if not bool(resolver.hook_option("service", "show_drummer_glasses").get("enabled", false)):
		failures.append("Legend glasses were not usable at a different venue location.")
	resolver.use_hook("service", "show_drummer_glasses")
	if run_state.suspicion_level() != 0:
		failures.append("Legend glasses did not clear heat at a second venue location.")


func _check_jazz_club_layout(environment_data: Dictionary, failures: Array) -> void:
	var layout: Dictionary = environment_data.get("layout", {}) if typeof(environment_data.get("layout", {})) == TYPE_DICTIONARY else {}
	var object_rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
	for object_id in [
		"game:pull_tabs",
		"game_hook:pull_tabs:ticket_redeemer",
		"shopkeeper:merchant",
		"service:house_drink",
		"service:jazz_sax_round",
		"service:jazz_cello_round",
		"service:jazz_drummer_round",
		"service:jazz_band_tip_jar",
		"service:listen_to_jazz",
	]:
		if not object_rects.has(object_id):
			failures.append("Jazz Club layout is missing object placement for %s." % object_id)
	var expected_zones := {
		"game:pull_tabs": Rect2(680, 175, 150, 105),
		"game_hook:pull_tabs:ticket_redeemer": Rect2(550, 210, 130, 85),
		"shopkeeper:merchant": Rect2(580, 80, 150, 105),
		"service:house_drink": Rect2(760, 85, 140, 90),
		"service:jazz_sax_round": Rect2(110, 220, 130, 90),
		"service:jazz_cello_round": Rect2(255, 220, 130, 90),
		"service:jazz_drummer_round": Rect2(405, 220, 130, 90),
		"service:jazz_band_tip_jar": Rect2(25, 305, 140, 90),
		"service:listen_to_jazz": Rect2(440, 305, 140, 90),
	}
	for object_id in expected_zones.keys():
		if not object_rects.has(object_id):
			continue
		var center := _layout_rect_center_board(_layout_rect_from_dict(object_rects.get(object_id, {})))
		if not (expected_zones[object_id] as Rect2).has_point(center):
			failures.append("Jazz Club object %s is outside its intended room zone at %s." % [object_id, str(center)])
	var seen_centers := {}
	var keys := object_rects.keys()
	for index in range(keys.size()):
		var key := str(keys[index])
		var rect := _layout_rect_from_dict(object_rects.get(key, {}))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failures.append("Jazz Club object placement has an empty rect for %s." % key)
			continue
		var center_key := "%0.4f,%0.4f" % [rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5]
		if seen_centers.has(center_key):
			failures.append("Jazz Club objects share the same map location: %s and %s." % [str(seen_centers[center_key]), key])
		else:
			seen_centers[center_key] = key
		for other_index in range(index + 1, keys.size()):
			var other_key := str(keys[other_index])
			var other_rect := _layout_rect_from_dict(object_rects.get(other_key, {}))
			if other_rect.size.x <= 0.0 or other_rect.size.y <= 0.0:
				continue
			if _layout_rects_overlap_with_gap(rect, other_rect):
				failures.append("Jazz Club objects overlap on the map: %s and %s." % [key, other_key])


func _layout_rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


func _layout_rect_center_board(rect: Rect2) -> Vector2:
	return Vector2(
		(rect.position.x + rect.size.x * 0.5) * float(ArtContractsScript.ENVIRONMENT_BOARD_SIZE.x),
		(rect.position.y + rect.size.y * 0.5) * float(ArtContractsScript.ENVIRONMENT_BOARD_SIZE.y)
	)


func _layout_rects_overlap_with_gap(first: Rect2, second: Rect2) -> bool:
	var gap := Vector2(8.0 / float(ArtContractsScript.ENVIRONMENT_BOARD_SIZE.x), 8.0 / float(ArtContractsScript.ENVIRONMENT_BOARD_SIZE.y))
	var padded_first := Rect2(first.position - gap, first.size + gap * 2.0)
	var padded_second := Rect2(second.position - gap, second.size + gap * 2.0)
	return padded_first.intersects(padded_second)


# Checks lender borrowing, repayment, defaults, special debt kinds, and save/load.
func _check_lender_debt_foundation(library: ContentLibrary, failures: Array) -> void:
	for lender_id in ["street_lender", "motel_friend", "the_crew", "brother_in_law", "sals_pawn_counter"]:
		if library.lender(lender_id).is_empty():
			failures.append("Lender fixture is missing: %s." % lender_id)
			return
	if library.service("call_brother_in_law").is_empty():
		failures.append("Brother-in-law phone service is missing.")
		return

	_check_cash_lender_lifecycle(library, "street_lender", "street_lender_note", true, failures)
	_check_cash_lender_lifecycle(library, "motel_friend", "motel_friend_note", false, failures)
	_check_crew_lender_lifecycle(library, failures)
	_check_family_lender_lifecycle(library, failures)
	_check_pawn_lender_lifecycle(library, failures)
	_check_pawn_shop_run_environment(library, failures)


func _check_cash_lender_lifecycle(library: ContentLibrary, lender_id: String, debt_id: String, expects_heat: bool, failures: Array) -> void:
	var fixture := _lender_fixture(library, "LENDER-CASH-%s" % lender_id, [lender_id], [], [])
	var run_state: RunState = fixture.get("run_state", null)
	var resolver: RunActionService = fixture.get("resolver", null)
	var before_bankroll := run_state.bankroll
	var before_suspicion := run_state.suspicion_level()
	var borrow := resolver.use_hook("lender", lender_id)
	if not bool(borrow.get("ok", false)):
		failures.append("Cash lender %s did not resolve: %s" % [lender_id, str(borrow.get("message", ""))])
		return
	var borrow_result: Dictionary = borrow.get("result", {}) if typeof(borrow.get("result", {})) == TYPE_DICTIONARY else {}
	if str(borrow_result.get("conclusion_animation", "")) != "bankroll_transfer":
		failures.append("Cash lender %s did not request the bankroll transfer animation." % lender_id)
	if run_state.bankroll <= before_bankroll:
		failures.append("Cash lender %s did not provide bankroll." % lender_id)
	if run_state.debt.size() != 1:
		failures.append("Cash lender %s did not add exactly one debt entry." % lender_id)
		return
	var debt_data: Dictionary = run_state.debt[0] as Dictionary
	if str(debt_data.get("id", "")) != debt_id or str(debt_data.get("lender_id", "")) != lender_id:
		failures.append("Cash lender %s debt identity was not preserved." % lender_id)
	var loan_amount := run_state.bankroll - before_bankroll
	var expected_balance := maxi(loan_amount, int(ceil(float(loan_amount) * 1.10)))
	if int(debt_data.get("balance", 0)) != expected_balance:
		failures.append("Cash lender %s did not add the 10 percent payoff balance." % lender_id)
	if expects_heat and run_state.suspicion_level() <= before_suspicion:
		failures.append("Street-style lender did not apply pressure heat.")
	if bool(resolver.hook_option("lender", lender_id).get("enabled", true)):
		failures.append("Cash lender %s stayed enabled while its debt was active." % lender_id)
	var repay_run := _lender_fixture(library, "LENDER-CASH-REPAY-%s" % lender_id, [lender_id], [], [])
	var repay_state: RunState = repay_run.get("run_state", null)
	var repay_resolver: RunActionService = repay_run.get("resolver", null)
	repay_resolver.use_hook("lender", lender_id)
	repay_state.bankroll = 500
	repay_state.add_suspicion("lender_repay_fixture", 8)
	var heat_before_repay := repay_state.suspicion_level()
	var repay := repay_state.repay_debt(debt_id)
	if not bool(repay.get("ok", false)) or not repay_state.debt.is_empty():
		failures.append("Cash lender %s could not be repaid cleanly." % lender_id)
	if repay_state.suspicion_level() >= heat_before_repay:
		failures.append("Cash lender %s repayment did not cool heat." % lender_id)
	if bool(repay_resolver.hook_option("lender", lender_id).get("enabled", true)):
		failures.append("Cash lender %s offered a larger loan in the same room after repayment." % lender_id)
	repay_state.current_environment["id"] = "lender_cash_return_%s" % lender_id
	var next_option := repay_resolver.hook_option("lender", lender_id)
	if not bool(next_option.get("enabled", false)):
		failures.append("Cash lender %s did not return after leaving the room: %s" % [lender_id, str(next_option.get("disabled_reason", ""))])
	else:
		var next_deltas: Dictionary = repay_resolver.hook_result_deltas(library.lender(lender_id), "lender", repay_state.lender_hook_status(library.lender(lender_id)))
		if int(next_deltas.get("bankroll_delta", 0)) <= loan_amount:
			failures.append("Cash lender %s did not offer a larger loan after repayment." % lender_id)
	var default_run := _lender_fixture(library, "LENDER-CASH-DEFAULT-%s" % lender_id, [lender_id], [], [])
	var default_state: RunState = default_run.get("run_state", null)
	var default_resolver: RunActionService = default_run.get("resolver", null)
	default_resolver.use_hook("lender", lender_id)
	var default_result := default_state.default_debt(debt_id)
	if not bool(default_result.get("ok", false)):
		failures.append("Cash lender %s default did not resolve." % lender_id)
	if default_state.story_log.is_empty():
		failures.append("Cash lender %s default did not write a story entry." % lender_id)
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "foundation_check_lender_%s" % lender_id
	var save_error: Error = save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("Save service could not save %s lender state: %s." % [lender_id, save_error])
	else:
		var loaded = save_service.load_run(slot_id)
		if loaded == null:
			failures.append("Save service could not reload %s lender state." % lender_id)
		elif JSON.stringify(loaded.debt) != JSON.stringify(run_state.debt):
			failures.append("Lender %s debt did not survive SaveService load." % lender_id)


func _check_crew_lender_lifecycle(library: ContentLibrary, failures: Array) -> void:
	var multi_fixture := _lender_fixture(library, "LENDER-CREW-MULTI", ["the_crew"], [], [])
	var multi_state: RunState = multi_fixture.get("run_state", null)
	var multi_resolver: RunActionService = multi_fixture.get("resolver", null)
	var first_marker := multi_resolver.use_hook("lender", "the_crew")
	if not bool(first_marker.get("ok", false)):
		failures.append("The Crew first location loan did not resolve.")
	var first_marker_result: Dictionary = first_marker.get("result", {}) if typeof(first_marker.get("result", {})) == TYPE_DICTIONARY else {}
	if str(first_marker_result.get("conclusion_animation", "")) != "bankroll_transfer":
		failures.append("The Crew lender did not request the bankroll transfer animation.")
	if bool(multi_resolver.hook_option("lender", "the_crew").get("enabled", true)):
		failures.append("The Crew allowed a second marker from the same location.")
	multi_state.current_environment["id"] = "lender_crew_second_room"
	var second_marker := multi_resolver.use_hook("lender", "the_crew")
	if not bool(second_marker.get("ok", false)):
		failures.append("The Crew second location loan did not resolve.")
	multi_state.current_environment["id"] = "lender_crew_third_room"
	var third_marker := multi_resolver.use_hook("lender", "the_crew")
	if not bool(third_marker.get("ok", false)):
		failures.append("The Crew third location loan did not resolve.")
	if multi_state.debt.size() != 1:
		failures.append("The Crew did not stack location markers into one debt entry.")
	else:
		var multi_debt: Dictionary = multi_state.debt[0] as Dictionary
		if int(multi_debt.get("balance", 0)) != 6:
			failures.append("The Crew stacked marker balance was not six favors after three locations.")
		if _copy_array(multi_debt.get("source_location_ids", [])).size() != 3:
			failures.append("The Crew did not preserve all three source locations.")
	multi_state.current_environment["id"] = "lender_crew_fourth_room"
	if bool(multi_resolver.hook_option("lender", "the_crew").get("enabled", true)):
		failures.append("The Crew allowed more than three active loan locations.")

	var fixture := _lender_fixture(library, "LENDER-CREW", ["the_crew"], [], [])
	var run_state: RunState = fixture.get("run_state", null)
	var resolver: RunActionService = fixture.get("resolver", null)
	var before_bankroll := run_state.bankroll
	var borrow := resolver.use_hook("lender", "the_crew")
	if not bool(borrow.get("ok", false)):
		failures.append("The Crew lender did not resolve: %s" % str(borrow.get("message", "")))
		return
	var borrow_result: Dictionary = borrow.get("result", {}) if typeof(borrow.get("result", {})) == TYPE_DICTIONARY else {}
	if str(borrow_result.get("conclusion_animation", "")) != "bankroll_transfer":
		failures.append("The Crew direct lender did not request the bankroll transfer animation.")
	if run_state.bankroll != before_bankroll + 45:
		failures.append("The Crew did not lend its configured cash amount.")
	var debt_data: Dictionary = run_state.debt[0] as Dictionary
	if str(debt_data.get("debt_kind", "")) != "favor" or int(debt_data.get("balance", 0)) != 2:
		failures.append("The Crew debt was not denominated as two favors.")
	run_state.advance_environment_turns(2)
	debt_data = run_state.debt[0] as Dictionary
	if str(debt_data.get("status", "")) != "favor_due" or not bool(run_state.narrative_flags.get("crew_favor_pending", false)):
		failures.append("The Crew did not schedule a favor when its marker came due.")
	var favor := run_state.complete_debt_favor("the_crew_marker")
	if not bool(favor.get("ok", false)):
		failures.append("The Crew favor completion did not resolve.")
	debt_data = run_state.debt[0] as Dictionary
	if int(debt_data.get("balance", 0)) != 1 or str(debt_data.get("status", "")) != "active":
		failures.append("The Crew favor completion did not reduce and reset the marker.")
	var refusal := run_state.refuse_debt_favor("the_crew_marker")
	if not bool(refusal.get("ok", false)):
		failures.append("The Crew favor refusal did not resolve.")
	debt_data = run_state.debt[0] as Dictionary
	if str(debt_data.get("debt_kind", "")) != "cash" or int(debt_data.get("balance", 0)) != 45:
		failures.append("The Crew refusal did not convert the remaining favor to cash at the configured rate.")


func _check_family_lender_lifecycle(library: ContentLibrary, failures: Array) -> void:
	var fixture := _lender_fixture(library, "LENDER-FAMILY", ["brother_in_law"], ["call_brother_in_law"], [])
	var run_state: RunState = fixture.get("run_state", null)
	var resolver: RunActionService = fixture.get("resolver", null)
	if bool(resolver.hook_option("lender", "brother_in_law").get("enabled", true)):
		failures.append("Brother-in-law lender was enabled before the phone service.")
	var phone := resolver.use_hook("service", "call_brother_in_law")
	if not bool(phone.get("ok", false)) or not bool(run_state.narrative_flags.get("brother_in_law_phone_ready", false)):
		failures.append("Brother-in-law phone service did not set the availability flag.")
	var borrow := resolver.use_hook("lender", "brother_in_law")
	if not bool(borrow.get("ok", false)):
		failures.append("Brother-in-law lender did not resolve after the phone call.")
		return
	var borrow_result: Dictionary = borrow.get("result", {}) if typeof(borrow.get("result", {})) == TYPE_DICTIONARY else {}
	if str(borrow_result.get("conclusion_animation", "")) != "bankroll_transfer":
		failures.append("Brother-in-law lender did not request the bankroll transfer animation.")
	if not bool(run_state.narrative_flags.get("brother_in_law_loan_used", false)):
		failures.append("Brother-in-law lender did not mark its single-use flag.")
	if bool(resolver.hook_option("lender", "brother_in_law").get("enabled", true)):
		failures.append("Brother-in-law lender stayed enabled after the one phone-call loan.")
	run_state.bankroll = 500
	var repay := run_state.repay_debt("brother_in_law_note")
	if not bool(repay.get("ok", false)) or not run_state.debt.is_empty():
		failures.append("Brother-in-law loan could not be repaid.")
	if not bool(run_state.narrative_flags.get("brother_in_law_goodwill", false)):
		failures.append("Brother-in-law early repayment did not record goodwill.")
	if bool(resolver.hook_option("lender", "brother_in_law").get("enabled", true)):
		failures.append("Brother-in-law offered a same-room repeat loan after repayment.")
	run_state.current_environment["id"] = "lender_family_return_room"
	run_state.narrative_flags["brother_in_law_phone_ready"] = true
	var repeat_option := resolver.hook_option("lender", "brother_in_law")
	if not bool(repeat_option.get("enabled", false)):
		failures.append("Brother-in-law did not become available again after repayment and a new phone call.")
	else:
		var repeat_deltas: Dictionary = resolver.hook_result_deltas(library.lender("brother_in_law"), "lender", run_state.lender_hook_status(library.lender("brother_in_law")))
		if int(repeat_deltas.get("bankroll_delta", 0)) <= 30:
			failures.append("Brother-in-law repeat loan did not scale above the first amount.")

	var late_fixture := _lender_fixture(library, "LENDER-FAMILY-LATE", ["brother_in_law"], ["call_brother_in_law"], [])
	var late_state: RunState = late_fixture.get("run_state", null)
	var late_resolver: RunActionService = late_fixture.get("resolver", null)
	late_resolver.use_hook("service", "call_brother_in_law")
	late_resolver.use_hook("lender", "brother_in_law")
	late_state.advance_environment_turns(6)
	var late_debt: Dictionary = late_state.debt[0] as Dictionary
	if str(late_debt.get("status", "")) != "overdue" or not bool(late_state.narrative_flags.get("brother_in_law_story_scar", false)):
		failures.append("Brother-in-law late default did not mark the narrative scar.")
	late_state.advance_environment_turns(3)
	if int(late_state.narrative_flags.get("brother_in_law_recurring_nag", 0)) <= 0:
		failures.append("Brother-in-law overdue debt did not produce recurring nag pressure.")


func _check_pawn_lender_lifecycle(library: ContentLibrary, failures: Array) -> void:
	var empty_fixture := _lender_fixture(library, "LENDER-PAWN-EMPTY", ["sals_pawn_counter"], [], [])
	var empty_resolver: RunActionService = empty_fixture.get("resolver", null)
	if bool(empty_resolver.hook_option("lender", "sals_pawn_counter").get("enabled", true)):
		failures.append("Sal's Pawn Counter was enabled without collateral.")
	var fixture := _lender_fixture(library, "LENDER-PAWN", ["sals_pawn_counter"], [], ["creased_luck_card", "cheap_sunglasses", "scratch_pad", "payment_calendar", "pawn_receipt_sleeve"])
	var run_state: RunState = fixture.get("run_state", null)
	var resolver: RunActionService = fixture.get("resolver", null)
	var quotes := resolver.pawn_quote_options("sals_pawn_counter")
	if quotes.size() < 3:
		failures.append("Sal's Pawn Counter did not expose multiple pawn quote choices.")
		return
	var pawn_ids := ["creased_luck_card", "cheap_sunglasses", "scratch_pad"]
	var principal_sum := 0
	for item_id in pawn_ids:
		var quote := _pawn_quote_by_item(quotes, item_id)
		if quote.is_empty():
			failures.append("Pawn quote was missing for %s." % item_id)
			continue
		var before_bankroll := run_state.bankroll
		var borrow := resolver.pawn_inventory_item(item_id, "sals_pawn_counter")
		if not bool(borrow.get("ok", false)):
			failures.append("Sal's Pawn Counter did not pawn selected item %s: %s" % [item_id, str(borrow.get("message", ""))])
			continue
		var borrow_result: Dictionary = borrow.get("result", {}) if typeof(borrow.get("result", {})) == TYPE_DICTIONARY else {}
		if str(borrow_result.get("conclusion_animation", "")) != "bankroll_transfer":
			failures.append("Sal's Pawn Counter did not request the bankroll transfer animation.")
		var loan_amount := maxi(0, int(quote.get("loan_amount", 0)))
		principal_sum += loan_amount
		if run_state.bankroll != before_bankroll + loan_amount:
			failures.append("Pawn selected-item principal was not paid out for %s." % item_id)
		if run_state.inventory.has(item_id):
			failures.append("Pawn collateral %s remained usable in inventory after borrowing." % item_id)
	if run_state.debt.size() != 3:
		failures.append("Sal's Pawn Counter did not create three selected pawn tickets.")
		return
	var ticket_ids := {}
	for debt_entry in run_state.debt:
		var debt_data: Dictionary = debt_entry as Dictionary
		var ticket_id := str(debt_data.get("id", ""))
		if ticket_ids.has(ticket_id):
			failures.append("Pawn ticket ids were not distinct.")
		ticket_ids[ticket_id] = true
		var principal := maxi(0, int(debt_data.get("principal", 0)))
		var expected_fee := maxi(1, int(ceil(float(principal) * 0.25)))
		if int(debt_data.get("balance", 0)) != principal + expected_fee or int(debt_data.get("redemption_fee", 0)) != expected_fee:
			failures.append("Pawn ticket fee math did not store principal plus 25 percent fee.")
		if int(debt_data.get("deadline_turns", 0)) <= 5:
			failures.append("Pawn receipt/calendar grace did not extend pawn ticket deadlines.")
	if principal_sum <= 0:
		failures.append("Pawn selected-item principal sum was empty.")
	var tickets := run_state.pawn_tickets_for_lender("sals_pawn_counter")
	if tickets.size() != 3:
		failures.append("Pawn ticket ledger did not expose all tickets.")
	var middle_debt: Dictionary = run_state.debt[1] as Dictionary
	var middle_id := str(middle_debt.get("id", ""))
	var middle_item := str(middle_debt.get("collateral_item_id", ""))
	var middle_payoff := maxi(0, int(middle_debt.get("balance", 0)))
	run_state.bankroll = 500
	var repay := run_state.repay_debt(middle_id)
	if not bool(repay.get("ok", false)) or not run_state.inventory.has(middle_item) or run_state.debt.size() != 2:
		failures.append("Pawn selective repayment did not redeem exactly the chosen ticket.")
	if run_state.bankroll != 500 - middle_payoff:
		failures.append("Pawn selective repayment did not charge exactly the ticket buy-back amount.")

	var default_fixture := _lender_fixture(library, "LENDER-PAWN-DEFAULT", ["sals_pawn_counter"], [], ["creased_luck_card"])
	var default_state: RunState = default_fixture.get("run_state", null)
	var default_resolver: RunActionService = default_fixture.get("resolver", null)
	default_resolver.use_hook("lender", "sals_pawn_counter")
	default_state.advance_environment_turns(5)
	if default_state.inventory.has("creased_luck_card") or not default_state.debt.is_empty() or not bool(default_state.narrative_flags.get("sals_pawn_defaulted", false)) or not default_state.sals_forfeited_item_ids.has("creased_luck_card"):
		failures.append("Pawn default did not forfeit collateral, clear the loan, and record Sal's shelf.")
	default_state.set_environment({
		"id": "pawn_shop_forfeit_fixture",
		"kind": "pawn_shop",
		"archetype_id": "pawn_shop",
		"display_name": "Sal's Pawn Shop",
		"item_offers": [],
		"layout": {},
	})
	var shelf_offer := _item_offer_by_id(default_state.current_environment.get("item_offers", []), "creased_luck_card")
	if shelf_offer.is_empty():
		failures.append("Forfeited pawn item did not appear on Sal's shelf.")
	else:
		var item_definition := library.item("creased_luck_card")
		if int(shelf_offer.get("price", 0)) != int(item_definition.get("price_max", 0)):
			failures.append("Forfeited pawn shelf item was not priced at retail price_max.")
	default_state.bankroll = 500
	var buy_back := default_resolver.buy_item_offer("creased_luck_card")
	if not bool(buy_back.get("ok", false)) or default_state.sals_forfeited_item_ids.has("creased_luck_card"):
		failures.append("Buying a forfeited shelf item did not clear Sal's forfeited list.")
	var save_service: SaveService = SaveServiceScript.new()
	default_state.sals_forfeited_item_ids = ["cheap_sunglasses"]
	var save_error: Error = save_service.save_run(default_state, "foundation_check_pawn_forfeit_shelf")
	if save_error != OK:
		failures.append("Save service could not save pawn forfeited shelf state: %s." % save_error)
	else:
		var loaded = save_service.load_run("foundation_check_pawn_forfeit_shelf")
		if loaded == null or not loaded.sals_forfeited_item_ids.has("cheap_sunglasses"):
			failures.append("Pawn forfeited shelf state did not survive SaveService load.")


func _check_pawn_shop_run_environment(library: ContentLibrary, failures: Array) -> void:
	var pawn_archetype := _archetype_by_id(library, "pawn_shop")
	if pawn_archetype.is_empty():
		failures.append("Pawn shop archetype is missing.")
		return
	if int(pawn_archetype.get("tier", 0)) != 1:
		failures.append("Pawn shop run archetype must be tier 1.")
	if not _string_array(pawn_archetype.get("lender_hooks", [])).has("sals_pawn_counter"):
		failures.append("Pawn shop run archetype does not expose Sal's pawn counter.")
	if _string_array(pawn_archetype.get("event_scopes", [])).find("shop") < 0:
		failures.append("Pawn shop run archetype does not use shop event scope.")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PAWN-SHOP-DISCOUNT")
	var pawn_environment := EnvironmentInstance.from_archetype(pawn_archetype, 1, run_state.create_rng("pawn_shop_discount"), library).to_dict()
	var pawn_offers: Array = pawn_environment.get("item_offers", [])
	if pawn_offers.is_empty():
		failures.append("Pawn shop did not roll discounted item offers.")
	for offer_value in pawn_offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer := offer_value as Dictionary
		var item := library.item(str(offer.get("id", "")))
		var expected_min := maxi(1, int(floor(float(item.get("price_min", 1)) * 0.85)))
		var expected_max := maxi(1, int(floor(float(item.get("price_max", item.get("price_min", 1))) * 0.85)))
		var price := int(offer.get("price", 0))
		if price < expected_min or price > expected_max:
			failures.append("Pawn shop offer %s price %d was outside discounted range %d..%d." % [str(offer.get("id", "")), price, expected_min, expected_max])
	var normal_archetype := _archetype_by_id(library, "corner_store")
	if not normal_archetype.is_empty():
		var normal_environment := EnvironmentInstance.from_archetype(normal_archetype, 1, run_state.create_rng("normal_shop_price"), library).to_dict()
		for offer_value in _copy_array(normal_environment.get("item_offers", [])):
			if typeof(offer_value) != TYPE_DICTIONARY:
				continue
			var offer := offer_value as Dictionary
			var item := library.item(str(offer.get("id", "")))
			var price := int(offer.get("price", 0))
			if price < int(item.get("price_min", 0)) or price > int(item.get("price_max", item.get("price_min", 0))):
				failures.append("Non-discount shop offer was changed by pawn multiplier pricing.")
	if bool(pawn_environment.get("meta_session", false)) or str(pawn_environment.get("kind", "")) != "pawn_shop":
		failures.append("Run pawn shop environment mixed with meta pawn session state.")


func _pawn_quote_by_item(quotes: Array, item_id: String) -> Dictionary:
	for quote_value in quotes:
		if typeof(quote_value) == TYPE_DICTIONARY and str((quote_value as Dictionary).get("item_id", "")) == item_id:
			return (quote_value as Dictionary).duplicate(true)
	return {}


func _item_offer_by_id(offers: Variant, item_id: String) -> Dictionary:
	if typeof(offers) != TYPE_ARRAY:
		return {}
	for offer_value in offers as Array:
		if typeof(offer_value) == TYPE_DICTIONARY and str((offer_value as Dictionary).get("id", "")) == item_id:
			return (offer_value as Dictionary).duplicate(true)
	return {}


func _lender_fixture(library: ContentLibrary, seed: String, lender_ids: Array, service_ids: Array, inventory_ids: Array) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = 100
	run_state.current_environment = {
		"id": "%s_room" % seed.to_lower(),
		"display_name": "Lender Fixture Room",
		"kind": "shop",
		"tier": 1,
		"archetype_id": "lender_fixture",
		"service_ids": service_ids.duplicate(true),
		"lender_hooks": lender_ids.duplicate(true),
		"layout": {},
	}
	for item_id in _string_array(inventory_ids):
		run_state.add_item(item_id)
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	return {
		"run_state": run_state,
		"resolver": resolver,
	}


func _fixture_lender_result(run_state: RunState, lender: Dictionary, lender_id: String) -> Dictionary:
	var status := run_state.lender_hook_status(lender)
	var effect: Dictionary = lender.get("effect", {}) if typeof(lender.get("effect", {})) == TYPE_DICTIONARY else {}
	var deltas := GameModule.empty_result_deltas()
	for key in deltas.keys():
		var value: Variant = effect.get(key, deltas[key])
		if typeof(value) == TYPE_ARRAY:
			deltas[key] = (value as Array).duplicate(true)
		elif typeof(value) == TYPE_DICTIONARY:
			deltas[key] = (value as Dictionary).duplicate(true)
		else:
			deltas[key] = value
	var has_mutation := int(deltas.get("bankroll_delta", 0)) != 0 or int(deltas.get("suspicion_delta", 0)) != 0
	has_mutation = has_mutation or not (deltas.get("debt_changes", []) as Array).is_empty()
	has_mutation = has_mutation or not (deltas.get("flags_set", {}) as Dictionary).is_empty()
	if not has_mutation:
		return GameModule.build_action_result({
			"ok": false,
			"type": "lender_hook",
			"source_id": lender_id,
			"action_id": "use_lender_hook",
		})
	var message := str(lender.get("message", "Used %s." % str(lender.get("display_name", lender_id))))
	deltas["story_log"] = [{
		"type": "lender_hook",
		"id": lender_id,
		"label": str(lender.get("display_name", lender_id)),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"message": message,
	}]
	if (deltas.get("messages", []) as Array).is_empty():
		deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": bool(status.get("available", false)),
		"type": "lender_hook",
		"source_id": lender_id,
		"action_id": "use_lender_hook",
		"action_kind": "lender",
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"message": message,
	})


# Checks behavior-first suspicion cues, downstream risky-action pressure, event eligibility, and save/load.
