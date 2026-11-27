extends "res://tests/ending_solvers/ending_solver/player_run_solver.gd"

const RoutePolicy := preload("res://tests/ending_solvers/gold_card_solver/gold_route_policy.gd")
const BlackjackPolicy := preload("res://tests/ending_solvers/gold_card_solver/gold_blackjack_policy.gd")
const RouteProgression := preload("res://tests/ending_solvers/ending_solver/route_progression.gd")
const RESERVE_RECOVERY := "reserve_recovery"

var route := RoutePolicy.new()
var progression := RouteProgression.new()
var stake_before_rail_tap := -1
var wager_rail_tap_disabled := false


func observe() -> Dictionary:
	var view := super.observe()
	var game: Dictionary = view.get("game", {})
	if game.get("game_id") != "blackjack" or bool(game.get("boss_duel_active", false)):
		return view
	var canvas := app.get("game_surface_canvas") as Control
	var surface: Dictionary = canvas.realtime_surface_state()
	var projection: Dictionary = surface.get("ritual_projection", {})
	# The ordinary Blackjack HUD displays this phase in its Ritual label.
	if projection.has("phase_id"):
		game["blackjack_presentation"] = projection["phase_id"]
	if game.get("phase") == "betting" and game.has("selected_stake") and stake_before_rail_tap >= 0:
		wager_rail_tap_disabled = int(game["selected_stake"]) <= stake_before_rail_tap
		stake_before_rail_tap = -1
	if wager_rail_tap_disabled:
		game["wager_rail_tap_disabled"] = true
	return view


func _configure_progression(id: String) -> void:
	progression.configure(_target_ending(), id)
	if id == RESERVE_RECOVERY:
		active_policy = "baseline"


func _ending_command(view: Dictionary) -> String:
	var archetype := str(view.get("environment", {}).get("archetype_id", ""))
	if archetype.begins_with("grand_casino"):
		var next := progression.decide_gold(view, route.decide(view))
		if not next.is_empty():
			return next
		_maybe_switch_to_reserve(view)
		return BlackjackPolicy.decide(view, _play_policy(view))
	var interruption := BlackjackPolicy.decide(view, active_policy)
	if not interruption.is_empty():
		return interruption
	return opening.decide(view)


func _play_policy(view: Dictionary) -> String:
	if selected_route == RESERVE_RECOVERY and active_policy == "risk_aware" \
			and view.get("gold_progress", {}).get("tier") == "gold":
		return RESERVE_RECOVERY
	return active_policy


func _maybe_switch_to_reserve(view: Dictionary) -> void:
	if selected_route != RESERVE_RECOVERY or active_policy != "baseline":
		return
	var game: Dictionary = view.get("game", {})
	var progress: Dictionary = view.get("gold_progress", {})
	if game.get("game_id") != "blackjack" or game.get("phase") != "betting" \
			or bool(game.get("boss_duel_active", false)) or bool(progress.get("awaiting_settlement", false)):
		return
	if int(progress.get("consecutive_losses", 0)) >= 2 and int(progress.get("segment_net", 0)) < 0:
		active_policy = "risk_aware"
		route_signature.append("gold_policy:reserve_after_drawdown")


func _record_ending_input(command: String, view: Dictionary) -> void:
	if command.begins_with("click_action blackjack_wager_place_gesture "):
		stake_before_rail_tap = int(view.get("game", {}).get("selected_stake", -1))
	route.record_input(command, view)
	progression.record_input(command, view)


func _ending_room_recovered() -> void:
	route.recheck_after_room_recovery()


func _witness(view: Dictionary) -> Dictionary:
	var witness := super._witness(view)
	if selected_route == RESERVE_RECOVERY:
		witness["gold_play_policy"] = _play_policy(view)
	var game: Dictionary = view.get("game", {})
	for field in ["blackjack_presentation", "wager_rail_tap_disabled"]:
		if game.has(field):
			witness[field] = game[field]
	return witness


func _ending_stop_reason(view: Dictionary) -> String:
	if bool(view.get("game", {}).get("boss_duel_active", false)):
		return "the showdown superseded Gold Players Card eligibility"
	return route.blocked_reason


func _max_actions() -> int:
	return 900


func _max_iterations() -> int:
	return 4000


func _target_key() -> String:
	return "players_card"


func _target_ending() -> String:
	return "gold_card"
