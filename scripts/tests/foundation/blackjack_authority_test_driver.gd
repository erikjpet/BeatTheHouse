extends RefCounted

# Verification-only adapter for legacy probes that need to assert live Blackjack
# consequences. Result-only callers should continue using the detached public
# compatibility API; this adapter reaches the same Foundation-owned authority
# boundary as production without adding a module-side write bypass.

const BlackjackActionAuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")


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
	var result: Dictionary = host.call("_blackjack_host_resolve_intent", action_id, stake)
	host.free()
	return result


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
