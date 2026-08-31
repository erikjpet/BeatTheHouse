extends RefCounted

# Verification-only adapter for legacy probes that need to assert live Blackjack
# consequences. Result-only callers should continue using the detached public
# compatibility API; this adapter reaches the same Foundation-owned authority
# boundary as production without adding a module-side write bypass.

const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const TUTORIAL_PEEK_REPRIEVE_INITIAL_RNG_STATE := 1
const TUTORIAL_SAFE_PEEK_FLOW_INITIAL_RNG_STATE := 3


static func resolve(game: GameModule, action_id: String, stake: int, run_state: RunState, environment: Dictionary, _rng: RngStream, ui_state: Dictionary = {}) -> Dictionary:
	if game == null or run_state == null:
		return {"ok": false, "error_code": "invalid_fixture"}
	run_state.current_environment = environment
	_seed_session(game, run_state, environment, ui_state)
	var host: Control = FoundationMainScript.new()
	host.set("current_game", game)
	host.set("game_module_cache", {"blackjack": game})
	host.set("run_state", run_state)
	host.set("selected_stake", stake)
	var result: Dictionary = host.call("_sealed_action_host_resolve_intent", action_id, stake)
	host.free()
	return result


static func pin_tutorial_peek_reprieve_rng(run_state: RunState) -> void:
	if run_state == null:
		return
	run_state.rng_seed = TUTORIAL_PEEK_REPRIEVE_INITIAL_RNG_STATE
	run_state.rng_state = TUTORIAL_PEEK_REPRIEVE_INITIAL_RNG_STATE


static func pin_tutorial_safe_peek_flow_rng(run_state: RunState) -> void:
	if run_state == null:
		return
	run_state.rng_seed = TUTORIAL_SAFE_PEEK_FLOW_INITIAL_RNG_STATE
	run_state.rng_state = TUTORIAL_SAFE_PEEK_FLOW_INITIAL_RNG_STATE


static func surface_intent(game: GameModule, surface_action: String, stake: int, run_state: RunState, environment: Dictionary, index: int = 0, confirm_requested: bool = false, surface_time_msec: int = -1) -> Dictionary:
	if game == null or run_state == null:
		return {"handled": false, "error_code": "invalid_fixture"}
	run_state.current_environment = environment
	var host: Control = FoundationMainScript.new()
	host.set("current_game", game)
	host.set("game_module_cache", {"blackjack": game})
	host.set("run_state", run_state)
	host.set("selected_stake", stake)
	var command: Dictionary = host.call("_sealed_action_host_surface_intent", surface_action, index, confirm_requested, surface_time_msec)
	host.free()
	return command


static func resolve_surface_command(game: GameModule, command: Dictionary, _stake: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	if game == null or run_state == null:
		return {"ok": false, "error_code": "invalid_fixture"}
	var action_id := str(command.get("action_id", ""))
	var delivery_value: Variant = command.get("_sealed_action_host_delivery", null)
	if action_id.is_empty() or typeof(delivery_value) != TYPE_DICTIONARY:
		return {"ok": false, "error_code": "invalid_intent", "message": "The surface command did not carry a sealed Blackjack action."}
	var delivery: Dictionary = delivery_value
	var command_stake := int(delivery.get("stake", -1))
	var explicit_stake := int(command.get("set_stake", command_stake))
	if delivery.is_empty() \
			or str(delivery.get("action_id", "")) != action_id \
			or command_stake < 0 \
			or explicit_stake != command_stake:
		return {"ok": false, "error_code": "receipt_content_conflict", "message": "The surface command did not match its sealed Blackjack delivery."}
	run_state.current_environment = environment
	var host: Control = FoundationMainScript.new()
	host.set("current_game", game)
	host.set("game_module_cache", {"blackjack": game})
	host.set("run_state", run_state)
	host.set("selected_stake", command_stake)
	var result: Dictionary = host.call("_sealed_action_host_resolve_intent", action_id, command_stake, delivery)
	host.free()
	return result


static func advance_terminal_presentation(game: GameModule, stake: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	if game == null or run_state == null:
		return {"ok": false, "error_code": "invalid_fixture"}
	run_state.current_environment = environment
	var session := _canonical_session(game, run_state, environment)
	if session.is_empty() or not bool(game.call("_has_dealt_hand", session)):
		return {"ok": true, "terminal_cleared": true, "surface_time_msec": 0}
	var surface_time_msec := _terminal_presentation_end_msec(game, session)
	var host: Control = FoundationMainScript.new()
	host.set("current_game", game)
	host.set("game_module_cache", {"blackjack": game})
	host.set("run_state", run_state)
	host.set("selected_stake", stake)
	if not bool(host.call("_sealed_action_host_needs_auto_tick", surface_time_msec)):
		host.free()
		return {"ok": false, "error_code": "terminal_not_ready", "surface_time_msec": surface_time_msec, "session": session}
	var command: Dictionary = host.call("_sealed_action_host_auto_intent", surface_time_msec)
	if command.is_empty() or not bool(command.get("handled", false)):
		host.free()
		return {"ok": false, "error_code": "invalid_intent", "surface_time_msec": surface_time_msec, "command": command}
	var result: Dictionary = {"ok": true}
	var action_id := str(command.get("action_id", ""))
	if not action_id.is_empty():
		var delivery_value: Variant = command.get("_sealed_action_host_delivery", null)
		if typeof(delivery_value) != TYPE_DICTIONARY:
			host.free()
			return {"ok": false, "error_code": "invalid_intent", "surface_time_msec": surface_time_msec, "command": command}
		var delivery: Dictionary = delivery_value
		var command_stake := int(delivery.get("stake", -1))
		var explicit_stake := int(command.get("set_stake", command_stake))
		if delivery.is_empty() \
				or str(delivery.get("action_id", "")) != action_id \
				or command_stake < 0 \
				or explicit_stake != command_stake:
			host.free()
			return {"ok": false, "error_code": "receipt_content_conflict", "surface_time_msec": surface_time_msec, "command": command}
		result = host.call("_sealed_action_host_resolve_intent", action_id, command_stake, delivery)
	host.free()
	var post_session := _canonical_session(game, run_state, environment)
	var terminal_cleared := post_session.is_empty() or not bool(game.call("_has_dealt_hand", post_session))
	return {
		"ok": bool(result.get("ok", false)) and terminal_cleared,
		"terminal_cleared": terminal_cleared,
		"surface_time_msec": surface_time_msec,
		"command": command,
		"result": result,
		"session": post_session,
	}


static func _canonical_session(game: GameModule, run_state: RunState, environment: Dictionary) -> Dictionary:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table_value: Variant = game_states.get(game.get_id(), null)
	if typeof(table_value) != TYPE_DICTIONARY:
		return {}
	var table: Dictionary = table_value
	var binding := "%s:%s:%s" % [game.get_id(), str(environment.get("id", "unknown")), str(environment.get("archetype_id", "unknown"))]
	var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}), binding, run_state.blackjack_authority_checkpoint_fingerprint())
	if ledger.is_empty() or typeof(ledger.get("session", null)) != TYPE_DICTIONARY:
		return {}
	return (ledger.get("session", {}) as Dictionary).duplicate(true)


static func _terminal_presentation_end_msec(game: GameModule, session: Dictionary) -> int:
	var threshold := maxi(1, int(session.get("surface_time_msec", 0)))
	threshold = maxi(threshold, int(session.get("surface_presentation_time_msec", 0)))
	var deal_started_msec := int(session.get("deal_started_msec", 0))
	var deal_events: Array = session.get("deal_animation_events", []) if typeof(session.get("deal_animation_events", [])) == TYPE_ARRAY else []
	if deal_started_msec > 0 and not deal_events.is_empty():
		threshold = maxi(threshold, deal_started_msec + int(game.call("_deal_animation_duration_msec", deal_events)))
	var challenge_value: Variant = session.get("count_challenge", null)
	if typeof(challenge_value) == TYPE_DICTIONARY:
		var icons_value: Variant = (challenge_value as Dictionary).get("icons", null)
		if typeof(icons_value) == TYPE_ARRAY:
			for icon_value in icons_value as Array:
				if typeof(icon_value) == TYPE_DICTIONARY:
					var icon: Dictionary = icon_value
					threshold = maxi(threshold, int(icon.get("spawn_msec", 0)) + int(icon.get("duration_msec", 0)) + 1)
	return threshold


static func _seed_session(game: GameModule, run_state: RunState, environment: Dictionary, ui_state: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = (game_states.get("blackjack", {}) as Dictionary).duplicate(true) if typeof(game_states.get("blackjack", {})) == TYPE_DICTIONARY else {}
	if table.is_empty():
		table = game.call("_table_state_preview", run_state, environment)
	var binding := "blackjack:%s:%s" % [str(environment.get("id", "unknown")), str(environment.get("archetype_id", "unknown"))]
	var checkpoint := run_state.blackjack_authority_checkpoint_fingerprint()
	var ledger := BlackjackActionAuthorityScript.validate_persisted_ledger(table.get(BlackjackActionAuthorityScript.LEDGER_KEY, {}), binding, checkpoint)
	if ledger.is_empty():
		ledger = BlackjackActionAuthorityScript.default_ledger(binding, checkpoint)
	if not (ledger.get("pending_delivery", {}) as Dictionary).is_empty():
		return
	table[BlackjackActionAuthorityScript.LEDGER_KEY] = BlackjackActionAuthorityScript.stage_session(ledger, ui_state)
	game.call("_update_environment_table", environment, table)
	run_state.current_environment = environment
