extends RefCounted

# Verification-only adapter for table-game probes that need to assert live
# consequences through the same sealed Foundation host used by production.

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")


static func resolve(game: GameModule, action_id: String, stake: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	if game == null or run_state == null:
		return {"ok": false, "error_code": "invalid_fixture"}
	run_state.current_environment = environment
	var host := _new_production_host()
	if host == null:
		return {"ok": false, "error_code": "invalid_host"}
	host.set("current_game", game)
	host.set("game_module_cache", {game.get_id(): game})
	host.set("run_state", run_state)
	host.set("selected_stake", stake)
	var result: Dictionary = host.call("_sealed_action_host_resolve_intent", action_id, stake)
	host.free()
	return result


static func _new_production_host() -> Control:
	var host: Control = FoundationMainScript.new()
	for stage_index in [0, 4, 10, 12]:
		if not bool(host.call("_ensure_run_ui_stage_scripts", stage_index)):
			host.free()
			return null
	return host
