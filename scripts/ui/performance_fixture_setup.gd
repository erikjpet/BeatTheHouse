class_name PerformanceFixtureSetup
extends RefCounted

# Diagnostic-only setup for gated surfaces that cannot be measured honestly
# from an unaffiliated fresh RunState. This grants no product access: callers
# mutate only their disposable performance fixture, then use normal game APIs.

const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")


static func install_actor_present_crew_draw_poker(app: Node) -> Dictionary:
	if app == null:
		return {"ok": false, "error": "missing_app"}
	var run_state: RunState = app.get("run_state") as RunState
	var game: GameModule = app.get("current_game") as GameModule
	if run_state == null or game == null or game.get_id() != "crew_draw_poker":
		return {"ok": false, "error": "missing_crew_runtime"}
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = states.get("crew_draw_poker", {}) if typeof(states.get("crew_draw_poker", {})) == TYPE_DICTIONARY else {}
	var members: Array = table.get("members", []) if typeof(table.get("members", [])) == TYPE_ARRAY else []
	if members.size() < 2:
		return {"ok": false, "error": "missing_table_actors", "member_count": members.size()}
	var witness := str(members[0])
	var required_trust := CrewStateModelScript.rank_threshold("associate")
	run_state.crew_add_trust(witness, required_trust - run_state.crew_trust(witness), "perf06_actor_present_fixture")
	run_state.current_environment["resident_member_ids"] = members.duplicate()
	var presence: Array = []
	for member_value in members:
		var member_id := str(member_value)
		presence.append({"member_id": member_id, "rank": run_state.crew_rank(member_id), "line": "Performance fixture table actor."})
	run_state.current_environment["crew_presence"] = presence
	app.call("_refresh")
	var legal_ids: Array = []
	for action_value in game.legal_actions(run_state, run_state.current_environment):
		if typeof(action_value) == TYPE_DICTIONARY:
			legal_ids.append(str((action_value as Dictionary).get("id", "")))
	var surface: Dictionary = app.call("current_game_view_snapshot")
	var rendered_members: Array = surface.get("members", []) if typeof(surface.get("members", [])) == TYPE_ARRAY else []
	return {
		"ok": run_state.crew_rank(witness) == "associate" and legal_ids.has("deal") and rendered_members.size() >= 2,
		"witness": witness,
		"witness_rank": run_state.crew_rank(witness),
		"member_ids": members.duplicate(),
		"rendered_member_count": rendered_members.size(),
		"legal_action_ids": legal_ids,
	}


static func crew_draw_poker_progressed(environment: Dictionary) -> bool:
	var states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = states.get("crew_draw_poker", {}) if typeof(states.get("crew_draw_poker", {})) == TYPE_DICTIONARY else {}
	return str(table.get("phase", "idle")) != "idle" \
		and (int(table.get("hand_number", 0)) > 0 or int(table.get("action_ordinal", 0)) > 0)
