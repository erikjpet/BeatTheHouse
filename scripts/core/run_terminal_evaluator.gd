class_name RunTerminalEvaluator
extends RefCounted

# Evaluates terminal run states that need both RunState and ContentLibrary context.


static func evaluate(run_state: RunState, library: ContentLibrary = null) -> Dictionary:
	var result := _base_result()
	if run_state == null:
		return result
	if run_state.run_status == RunState.RUN_STATUS_ENDED:
		result["terminal"] = true
		return result
	if run_state.run_status == RunState.RUN_STATUS_FAILED:
		result["failed"] = true
		result["terminal"] = true
		result["reason"] = run_state.run_failure_reason
		result["message"] = run_state.run_failure_message
		return result
	if run_state.suspicion_level() >= 100:
		if run_state.grand_casino_heat_reroute_available():
			return result
		result["failed"] = true
		result["terminal"] = true
		result["reason"] = RunState.FAILURE_POLICE_CAPTURE
		result["message"] = RunState.POLICE_CAPTURE_FAILURE_MESSAGE
		return result
	if run_state.bankroll <= 0:
		if run_state.closing_time_forced_travel_required():
			result["bankroll_zero_deferred"] = true
			result["travel_available"] = true
			result["recovery_available"] = true
			return result
		if library != null and _has_deferred_bankroll_zero_failure(run_state, library):
			result["bankroll_zero_deferred"] = true
			result["recovery_available"] = true
			return result
		result["failed"] = true
		result["terminal"] = true
		result["reason"] = RunState.FAILURE_BANKROLL_ZERO
		result["message"] = RunState.BANKROLL_ZERO_FAILURE_MESSAGE
		return result
	if library == null or run_state.current_environment.is_empty():
		return result

	result["wager_available"] = _has_valid_wager(run_state, library)
	result["travel_available"] = _has_available_travel(run_state, library)
	result["local_room_travel_available"] = _has_available_local_room_travel(run_state)
	result["event_recovery_available"] = _has_event_recovery(run_state, library)
	result["lender_available"] = _has_lender_recovery(run_state, library)
	result["merchant_sale_available"] = _has_merchant_sale_recovery(run_state, library)
	result["game_hook_recovery_available"] = _has_game_hook_recovery(run_state, library)
	var recovery_available := bool(result.get("travel_available", false)) \
		or bool(result.get("local_room_travel_available", false)) \
		or bool(result.get("event_recovery_available", false)) \
		or bool(result.get("lender_available", false)) \
		or bool(result.get("merchant_sale_available", false)) \
		or bool(result.get("game_hook_recovery_available", false))
	result["recovery_available"] = recovery_available
	if not bool(result.get("wager_available", false)) and not recovery_available:
		result["failed"] = true
		result["terminal"] = true
		result["reason"] = RunState.FAILURE_STRANDED
		result["message"] = RunState.STRANDED_FAILURE_MESSAGE
	return result


static func evaluate_and_apply(run_state: RunState, library: ContentLibrary = null) -> Dictionary:
	if run_state != null:
		run_state.handle_grand_casino_heat_reroute("terminal_evaluator")
	var result := evaluate(run_state, library)
	if run_state == null or not bool(result.get("failed", false)):
		return result
	var reason := str(result.get("reason", ""))
	var message := str(result.get("message", ""))
	run_state.fail_run(reason, message)
	return result


static func _base_result() -> Dictionary:
	return {
		"failed": false,
		"terminal": false,
		"reason": RunState.FAILURE_NONE,
		"message": "",
		"wager_available": false,
		"travel_available": false,
		"local_room_travel_available": false,
		"event_recovery_available": false,
		"lender_available": false,
		"merchant_sale_available": false,
		"game_hook_recovery_available": false,
		"recovery_available": false,
		"bankroll_zero_deferred": false,
	}


static func _has_valid_wager(run_state: RunState, library: ContentLibrary) -> bool:
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		var definition := library.game(game_id)
		if definition.is_empty():
			continue
		if _copy_array(definition.get("legal_actions", [])).is_empty() and _copy_array(definition.get("cheat_actions", [])).is_empty():
			continue
		var economic_profile: Dictionary = run_state.current_environment.get("economic_profile", {})
		var floor := maxi(1, int(economic_profile.get("stake_floor", 1)))
		var ceiling := run_state.wager_stake_ceiling(int(economic_profile.get("stake_ceiling", run_state.bankroll)))
		if mini(ceiling, run_state.bankroll) >= floor:
			return true
	return false


static func _has_deferred_bankroll_zero_failure(run_state: RunState, library: ContentLibrary) -> bool:
	if run_state == null or library == null or run_state.current_environment.is_empty():
		return false
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		var game := _create_game_module(library.game(game_id), library)
		if game == null:
			continue
		var runtime_state := game.environment_runtime_state(run_state, run_state.current_environment)
		if bool(runtime_state.get("bankroll_zero_failure_deferred", false)):
			return true
	return false


static func _has_available_travel(run_state: RunState, library: ContentLibrary) -> bool:
	for target_id in _travel_target_ids(run_state):
		var route := library.route(target_id)
		var status := run_state.travel_route_status(route)
		var cost := int(status.get("cost", route.get("cost", 0)))
		if bool(status.get("available", false)) and run_state.bankroll - cost > 0:
			return true
	return false


static func _has_available_local_room_travel(run_state: RunState) -> bool:
	if run_state == null or not run_state.is_grand_casino_environment():
		return false
	var flags: Dictionary = run_state.current_environment.get("local_narrative_flags", {}) if typeof(run_state.current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	for target_value in _copy_array(flags.get("casino_room_targets", [])):
		var target_id := str(target_value).strip_edges()
		if target_id.is_empty() or target_id == str(run_state.current_environment.get("archetype_id", "")):
			continue
		var access := run_state.grand_casino_room_access_status(target_id)
		var cost := maxi(0, int(access.get("cost", 0)))
		if bool(access.get("available", false)) and (cost == 0 or run_state.bankroll - cost > 0):
			return true
	return false


static func _has_event_recovery(run_state: RunState, library: ContentLibrary) -> bool:
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var event_module := EventModule.new()
		event_module.setup(definition)
		if not event_module.can_trigger(run_state, run_state.current_environment):
			continue
		for choice in event_module.choices():
			if typeof(choice) == TYPE_DICTIONARY and _choice_can_recover(choice as Dictionary):
				return true
	return false


static func _has_lender_recovery(run_state: RunState, library: ContentLibrary) -> bool:
	for lender_id in _string_array(run_state.current_environment.get("lender_hooks", [])):
		var definition := library.lender(lender_id)
		if definition.is_empty():
			continue
		var status := run_state.lender_hook_status(definition)
		if not bool(status.get("available", false)):
			continue
		var effect := _copy_dict(definition.get("effect", {}))
		if int(effect.get("bankroll_delta", 0)) > 0:
			return true
	return false


static func _has_merchant_sale_recovery(run_state: RunState, library: ContentLibrary) -> bool:
	if not _environment_has_shopkeeper(run_state.current_environment, library):
		return false
	for entry in run_state.inventory:
		var definition := library.item(str(entry))
		if definition.is_empty():
			continue
		if bool(definition.get("sellable", false)) and _item_sale_price(definition) > 0:
			return true
	return false


static func _has_game_hook_recovery(run_state: RunState, library: ContentLibrary) -> bool:
	for game_id in _string_array(run_state.current_environment.get("game_ids", [])):
		var game := _create_game_module(library.game(game_id), library)
		if game == null:
			continue
		for hook_value in game.environment_interactable_objects(run_state, run_state.current_environment):
			if typeof(hook_value) == TYPE_DICTIONARY and bool((hook_value as Dictionary).get("enabled", true)) and bool((hook_value as Dictionary).get("recovery", false)):
				return true
	return false


static func _create_game_module(definition: Dictionary, library: ContentLibrary) -> GameModule:
	var module_path := str(definition.get("module_path", ""))
	if module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		return null
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


static func _choice_can_recover(choice: Dictionary) -> bool:
	var consequences := _copy_dict(choice.get("consequences", {}))
	if int(consequences.get("bankroll_delta", 0)) > 0:
		return true
	if consequences.has("debt") or not _copy_array(consequences.get("debt_changes", [])).is_empty():
		return true
	if _travel_consequence_has_targets(consequences):
		return true
	return false


static func _travel_consequence_has_targets(consequences: Dictionary) -> bool:
	if not _copy_array(consequences.get("travel_hooks_add", [])).is_empty():
		return true
	if not _copy_array(consequences.get("set_next_archetypes", [])).is_empty():
		return true
	if not _copy_array(consequences.get("add_next_archetypes", [])).is_empty():
		return true
	var travel_changes := _copy_dict(consequences.get("travel_changes", {}))
	if not _copy_array(travel_changes.get("set_next_archetypes", [])).is_empty():
		return true
	if not _copy_array(travel_changes.get("add_next_archetypes", [])).is_empty():
		return true
	return false


static func _travel_target_ids(run_state: RunState) -> Array:
	var result: Array = []
	for source in [
		run_state.current_environment.get("next_archetypes", []),
		run_state.current_environment.get("travel_hooks", []),
		run_state.unlocked_travel,
	]:
		for target_id in _string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result


static func _environment_has_shopkeeper(environment: Dictionary, library: ContentLibrary) -> bool:
	if not _copy_array(environment.get("item_offers", [])).is_empty():
		return true
	if str(environment.get("kind", "")) != "shop":
		return false
	var archetype := _environment_archetype(library, str(environment.get("archetype_id", "")))
	return not _string_array(archetype.get("item_pool", [])).is_empty()


static func _environment_archetype(library: ContentLibrary, archetype_id: String) -> Dictionary:
	if library == null or archetype_id.is_empty():
		return {}
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


static func _item_sale_price(item_definition: Dictionary) -> int:
	if item_definition.has("sale_price"):
		return maxi(0, int(item_definition.get("sale_price", 0)))
	var price_min := int(item_definition.get("price_min", 0))
	var price_max := int(item_definition.get("price_max", price_min))
	return maxi(0, int(round(float(price_min + price_max) * 0.25)))


static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value as Array:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result
